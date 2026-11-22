"""Postal 2 Archipelago client: CommonClient GUI + TCP bridge to the mutator."""

from __future__ import annotations

import asyncio
import logging
import time
import zlib
from typing import Optional

from NetUtils import ClientStatus, NetworkItem
from Utils import async_start

from .data import (
    DAYS,
    FILLER_NAMES,
    GAME_NAME,
    item_name_to_grant,
    location_name_to_id,
    location_unique_to_name,
)
from .tracker import in_logic_rows, tracker_summary

logger = logging.getLogger("Client")

GAME_TCP_HOST = "127.0.0.1"
GAME_TCP_PORT = 23981

LOCATION_ALIASES = {
    "getmilk": "GetMilk",
    "milkpickup": "GetMilk",
    "homecrackcola": "COLA_SUBURBS-3_01",
}

UNIQUE_TO_NAME = location_unique_to_name()
UNIQUE_UPPER_TO_NAME = {k.upper(): v for k, v in UNIQUE_TO_NAME.items()}
NAME_TO_UNIQUE = {v: k for k, v in UNIQUE_TO_NAME.items()}
NAME_TO_ID = location_name_to_id()
ITEM_GRANT = item_name_to_grant()
CHECKED_LINE_CAP = 720


def canonical_unique(name: str) -> str:
    key = name.strip()
    return LOCATION_ALIASES.get(key.lower(), key)


def is_valid_check_unique(unique: str) -> bool:
    if not unique or len(unique) < 2 or len(unique) > 80:
        return False
    return not any(ch in unique for ch in '=()," \t')


def one_line(text: str, fallback: str) -> str:
    """Collapse a Death Link cause to a single short ASCII-safe line."""
    cause = " ".join((text or "").replace("\x00", " ").split())
    if not cause:
        cause = fallback
    if len(cause) > 180:
        cause = cause[:180].rstrip()
    return cause or fallback


def cash_face_value(item_name: str) -> int:
    """Face value for cash filler names like $5, $20, $100."""
    raw = (item_name or "").strip()
    if not raw.startswith("$"):
        return 0
    digits = "".join(ch for ch in raw[1:] if ch.isdigit())
    if not digits:
        return 0
    try:
        return int(digits)
    except ValueError:
        return 0


def vendor_price(unique: str, flags: int, seed: str, item_name: str = "") -> int:
    """Stable per-slot price. Cash uses face value; other items use class bands."""
    face = cash_face_value(item_name)
    if face > 0:
        return face
    h = zlib.crc32((unique + "|" + seed).encode("utf-8", errors="replace")) & 0x7FFFFFFF
    high = (h >> 16) & 1
    n = h & 0xFFFF
    if flags & 0b001:  # progression
        if high:
            return 260 + (n % 191)  # $260–$450
        return 150 + (n % 91)  # $150–$240
    if flags & 0b100:  # trap
        if high:
            return 28 + (n % 33)  # $28–$60
        return 8 + (n % 18)  # $8–$25
    if flags & 0b010:  # useful
        if high:
            return 85 + (n % 66)  # $85–$150
        return 35 + (n % 46)  # $35–$80
    if high:
        return 25 + (n % 36)  # filler $25–$60
    return 5 + (n % 16)  # filler $5–$20


class Postal2Context:
    """Filled in after CommonContext import so generate does not load CommonClient."""


def _build_context_class():
    from CommonClient import ClientCommandProcessor, CommonContext

    class Postal2CommandProcessor(ClientCommandProcessor):
        def _cmd_game(self) -> bool:
            """Show whether Postal 2 is connected to this client."""
            ctx: Postal2ContextImpl = self.ctx  # type: ignore[assignment]
            if ctx.game_writer is not None:
                self.output("Postal 2 mutator is connected (TCP 23981).")
            else:
                self.output("Waiting for Postal 2. Start Postal 2 with the Archipelago mutator.")
            return True

        def _cmd_tracker(self, cmd: str = "") -> bool:
            """List unchecked locations currently in logic. Optional: monday..friday or count."""
            ctx: Postal2ContextImpl = self.ctx  # type: ignore[assignment]
            if not ctx.slot:
                self.output("Connect to Archipelago first.")
                return True
            rows = in_logic_rows(ctx)
            missing = len(ctx.missing_locations or ())
            filt = (cmd or "").strip().lower()
            day_names = tuple(d.lower() for d in DAYS)
            if filt in day_names:
                di = day_names.index(filt)
                rows = [r for r in rows if r[0] == di]
            self.output(f"{len(rows)} in logic, {missing} remaining.")
            if filt in ("count", "summary"):
                return True
            if not filt and len(rows) > 80:
                counts = [0] * 5
                for day, _name in rows:
                    if 0 <= day < 5:
                        counts[day] += 1
                for i, day_name in enumerate(DAYS):
                    self.output(f"  {day_name}: {counts[i]}")
                self.output("Use /tracker monday (or tuesday..) to list that day.")
                return True
            last_day = -1
            for day, name in rows:
                if day != last_day:
                    self.output(f"-- {DAYS[day] if 0 <= day < len(DAYS) else 'Other'} --")
                    last_day = day
                self.output(f"  {name}")
            if not rows:
                self.output("Nothing in logic. Find more errand items or Time Warp keys.")
            return True

        def _cmd_inlogic(self, cmd: str = "") -> bool:
            """Alias for /tracker."""
            return self._cmd_tracker(cmd)

    class Postal2ContextImpl(CommonContext):
        command_processor = Postal2CommandProcessor
        game = GAME_NAME
        items_handling = 0b111
        want_slot_data = True
        tags = {"AP"}

        def __init__(self, server_address: Optional[str], password: Optional[str]) -> None:
            super().__init__(server_address, password)
            self.game_writer: Optional[asyncio.StreamWriter] = None
            self.game_port = GAME_TCP_PORT
            self.ap_seed = ""
            self._seed_changed = False
            self._granted_count = 0
            self._check_queue: list[str] = []
            self._ap_ready = False
            self.slot_data: dict = {}
            self._tracker_in_logic = -1
            self._tcp_state_sent = False
            self._last_catchup = 0.0
            self._vendor_hints: dict[str, tuple[int, int, str]] = {}
            self._game_tcp_seen = False
            self._last_game_drop = 0.0
            self._logged_catchup = False

        def make_gui(self):
            ui_class = super().make_gui()
            ui_class.base_title = "Archipelago Postal 2 Client"
            return ui_class

        async def server_auth(self, password_requested: bool = False):
            if password_requested and not self.password:
                await super().server_auth(password_requested)
            await self.get_username()
            await self.send_connect()

        async def send_game(self, line: str, quiet: bool = True) -> None:
            if not quiet:
                logger.info("-> game: %s", line)
            if self.game_writer is None:
                return
            try:
                self.game_writer.write((line + "\n").encode("ascii", errors="replace"))
                await self.game_writer.drain()
            except (ConnectionResetError, BrokenPipeError, OSError):
                self.game_writer = None

        def _server_socket_up(self) -> bool:
            sock = getattr(self.server, "socket", None) if self.server else None
            if sock is None:
                return False
            return not getattr(sock, "closed", False)

        def on_package(self, cmd: str, args: dict) -> None:
            if cmd == "RoomInfo":
                self._ap_ready = False
                self._logged_catchup = False
                seed = str(args.get("seed_name") or "")
                if self.ap_seed and self.ap_seed != seed:
                    self._seed_changed = True
                self.ap_seed = seed
            elif cmd == "Connected":
                self.slot_data = args.get("slot_data") or {}
                self._ap_ready = True
                async_start(self._on_connected(), name="postal2-connected")
            elif cmd in ("ConnectionRefused", "InvalidSlot", "InvalidGame"):
                self._ap_ready = False
            elif cmd == "ReceivedItems":
                async_start(self._on_received_items(args), name="postal2-items")
            elif cmd == "LocationInfo":
                async_start(self._on_location_info(args), name="postal2-hints")
            elif cmd == "PrintJSON":
                async_start(self._on_print_json(args), name="postal2-print")

        async def _on_connected(self) -> None:
            await self.update_death_link(bool((self.slot_data or {}).get("death_link")))
            if self._seed_changed:
                self._check_queue.clear()
                self._granted_count = 0
                self._vendor_hints.clear()
                await self.send_game("SEEDRESET " + (self.ap_seed or "new"))
                self._seed_changed = False
            else:
                await self.send_game("SEED " + (self.ap_seed or "same"))
            await self._send_options()
            queued = self._check_queue
            self._check_queue = []
            for unique in queued:
                await self.on_check(unique)
            if self.locations_checked:
                await self.check_locations(self.locations_checked)
            await self._push_world_state()
            await self._push_vendor_hints()
            await self._push_tracker()
            if self.game_writer is not None:
                self._tcp_state_sent = True
                logger.info("Pushed seed to Postal 2 (game already on TCP)")
            else:
                logger.info("Postal 2 is not on TCP yet; will dump when it connects")

        async def _on_received_items(self, args: dict) -> None:
            index = int(args.get("index", 0))
            if index == 0:
                # Full list dump (connect / reconnect). Never replay traps;
                # Drop Gun would toss weapons already in the save.
                await self._grant_from(0, resync=True)
                self._granted_count = len(self.items_received)
                await self._push_tracker()
                return
            await self._grant_from(self._granted_count, resync=False)
            self._granted_count = len(self.items_received)
            await self._push_tracker()

        async def _send_options(self) -> None:
            slot = self.slot_data or {}
            start_day = int(slot.get("start_day", 0) or 0)
            if start_day < 0:
                start_day = 0
            if start_day > 4:
                start_day = 4
            await self.send_game("OPTION STARTDAY " + str(start_day))
            await self.send_game("OPTION CLINIC 1")
            await self.send_game("OPTION WEAPONS " + ("1" if slot.get("shuffle_weapons", True) else "0"))
            await self.send_game("OPTION VENDING " + ("1" if slot.get("vending_sanity", True) else "0"))
            await self.send_game("OPTION CRACKOLA " + ("1" if slot.get("crackola_sanity", True) else "0"))
            await self.send_game("OPTION ATM " + ("1" if slot.get("atm_sanity", True) else "0"))
            counts = slot.get("vending_counts") or {}
            vending_on = bool(slot.get("vending_sanity", True))
            for key in ("GREENBELT1", "RWSBLOCK", "EASTMALL", "SUBURBS-4"):
                n = counts.get(key, 3 if vending_on else 0)
                if isinstance(n, (list, tuple)):
                    n = n[0] if n else 0
                await self.send_game("OPTION VBUY_" + key + " " + str(int(n)))
            starter = slot.get("monday_starter") or ""
            if starter:
                await self.send_game("STARTER " + str(starter))
            days = slot.get("map_days") or {}
            for key, day in days.items():
                await self.send_game("MAPDAY " + str(key) + " " + str(int(day)))
            await self.send_game("OPTION GLOW " + ("1" if slot.get("token_glow", True) else "0"))
            await self.send_game("OPTION BEEP " + ("1" if slot.get("token_heartbeat", True) else "0"))
            await self.send_game("OPTION DURABILITY " + ("1" if slot.get("melee_durability", False) else "0"))
            await self.send_game("OPTION PISSREALISM " + ("1" if slot.get("piss_realism", False) else "0"))
            regen = int(slot.get("piss_regen", 120) or 120)
            if regen < 30:
                regen = 30
            if regen > 180:
                regen = 180
            await self.send_game("OPTION PISSREGEN " + str(regen))
            await self.send_game("OPTION LOOTSANITY " + ("1" if slot.get("lootsanity", False) else "0"))
            await self.send_game("OPTION DEATHLINK " + ("1" if slot.get("death_link") else "0"))

        async def _send_scrounge(self) -> None:
            from .catalog import SCROUNGE_CATALOG
            from .data import (
                BLOCKED_SCROUNGE_UNIQUES,
                UNPLAYABLE_MAPS,
                is_blocked_scrounge,
            )
            from .hint_names import EXTRA_SCROUNGE_CATALOG

            by_u = {e["unique"]: e for e in SCROUNGE_CATALOG}
            by_u.update({e["unique"]: e for e in EXTRA_SCROUNGE_CATALOG})
            enabled = (self.slot_data or {}).get("scrounge") or []
            await self.send_game("SCROUNGECLEAR")
            for unique in enabled:
                e = by_u.get(unique)
                if not e:
                    continue
                if e.get("map") in UNPLAYABLE_MAPS or unique in BLOCKED_SCROUNGE_UNIQUES:
                    continue
                if e.get("cls") == "CrackColaPickup":
                    continue
                if is_blocked_scrounge(e["map"], e["cls"], e["x"], e["y"], e["z"]):
                    continue
                await self.send_game(
                    "SCROUNGE "
                    + e["unique"]
                    + " "
                    + e["cls"]
                    + " "
                    + e["map"]
                    + " "
                    + str(int(round(e["x"])))
                    + " "
                    + str(int(round(e["y"])))
                    + " "
                    + str(int(round(e["z"])))
                )
            await self.send_game("GREYCLEAR")
            for unique in (self.slot_data or {}).get("filler_tokens") or []:
                await self.send_game("GREY " + str(unique))
            await self.send_game("GREYEND")

        async def _send_checked(self) -> None:
            """Push AP-collected locations so the mutator can despawn those tokens."""
            line = ""
            for loc_id in list(self.locations_checked or ()):
                try:
                    name = self.location_names.lookup_in_game(int(loc_id))
                except Exception:
                    continue
                unique = NAME_TO_UNIQUE.get(name)
                if not unique:
                    continue
                if line and len("CHECKED ") + len(line) + 1 + len(unique) > CHECKED_LINE_CAP:
                    await self.send_game("CHECKED " + line, quiet=True)
                    line = unique
                elif line:
                    line = line + "|" + unique
                else:
                    line = unique
            if line:
                await self.send_game("CHECKED " + line, quiet=True)

        async def _push_world_state(self) -> None:
            """CHECKED first so a truncated SCROUNGE dump cannot drop collected uniques."""
            await self._send_checked()
            await self._send_scrounge()
            await self.send_game("CHECKEDEND", quiet=True)

        async def _push_tracker(self) -> None:
            if not self.slot:
                return
            n, missing = tracker_summary(self)
            if n != self._tracker_in_logic:
                logger.debug("Tracker: %s in logic, %s remaining", n, missing)
            self._tracker_in_logic = n
            await self.send_game("TRACKER " + str(n) + " " + str(missing))

        def _vendor_hint_line(self, unique: str, flags: int, price: int, name: str) -> str:
            clean = str(name).replace("\r", " ").replace("\n", " ").strip()
            return "VENDORHINT " + unique + " " + str(flags) + " " + str(price) + " " + clean

        async def _flush_vendor_hints(self) -> None:
            for unique, (flags, price, name) in self._vendor_hints.items():
                await self.send_game(self._vendor_hint_line(unique, flags, price, name))

        async def _push_vendor_hints(self) -> None:
            """Replay cached shop names on attach, then scout any that are still missing."""
            if not (self.slot_data or {}).get("vending_sanity", True):
                self._vendor_hints.clear()
                return
            await self._flush_vendor_hints()
            await self._scout_vendors()

        async def _scout_vendors(self) -> None:
            if not (self.slot_data or {}).get("vending_sanity", True):
                return
            ids = []
            known = set(self.missing_locations or ()) | set(self.locations_checked or ())
            for loc_id in known:
                try:
                    name = self.location_names.lookup_in_game(int(loc_id))
                except Exception:
                    continue
                unique = NAME_TO_UNIQUE.get(name)
                if unique and unique.startswith("VBUY_"):
                    ids.append(int(loc_id))
            if ids:
                await self.send_msgs([{"cmd": "LocationScouts", "locations": ids}])

        async def _on_location_info(self, args: dict) -> None:
            for ni in args.get("locations", []):
                if isinstance(ni, dict):
                    loc_id = int(ni.get("location", 0))
                    item_id = int(ni.get("item", 0))
                    player = int(ni.get("player", 0))
                else:
                    loc_id = int(getattr(ni, "location", 0))
                    item_id = int(getattr(ni, "item", 0))
                    player = int(getattr(ni, "player", 0))
                loc_name = self.location_names.lookup_in_game(loc_id)
                try:
                    item_name = self.item_names.lookup_in_slot(item_id, player)
                except Exception:
                    item_name = self.item_names.lookup_in_game(item_id)
                unique = NAME_TO_UNIQUE.get(loc_name)
                if unique and item_name:
                    if isinstance(ni, dict):
                        flags = int(ni.get("flags", 0) or 0)
                    else:
                        flags = int(getattr(ni, "flags", 0) or 0)
                    price = vendor_price(unique, flags, self.ap_seed or "", str(item_name))
                    clean = str(item_name).replace("\r", " ").replace("\n", " ").strip()
                    self._vendor_hints[unique] = (int(flags), int(price), clean)
                    await self.send_game(self._vendor_hint_line(unique, flags, price, clean))

        async def _grant_from(self, start: int, resync: bool) -> None:
            for i, net_item in enumerate(self.items_received[start:], start=start):
                await self.grant_item(net_item, i, resync=resync)

        async def grant_item(self, net_item: NetworkItem, index: int, resync: bool = False) -> None:
            name = self.item_names.lookup_in_game(net_item.item)
            grant = ITEM_GRANT.get(name, "")
            flags = int(getattr(net_item, "flags", 0) or 0)
            trap = bool(flags & 0b100)
            if not resync:
                logger.debug("AP item %s grant=%s", name, grant)
            if grant.startswith("DAY:") or grant.startswith("AREA:") or grant.startswith("ERRAND:") or grant.startswith("WARP:"):
                await self.send_game(f"UNLOCK {grant}")
                return
            if grant.startswith("TRAP:"):
                if resync:
                    return
                await self.send_game(f"MSG Trap: {name}")
                await self.send_game(f"TRAP {grant.split(':', 1)[1]} {index}")
                return
            if trap:
                if resync:
                    return
                await self.send_game(f"TRAP {name} {index}")
                return
            cls, amount = grant, "0"
            if ":" in grant:
                cls, amount = grant.split(":", 1)
            filler = name in FILLER_NAMES or grant.startswith("Inventory.MoneyInv")
            if filler:
                await self.send_game(f"FILLER {cls} {amount} {index}")
            elif cls:
                await self.send_game(f"UNLOCK {cls}")

        async def _on_print_json(self, args: dict) -> None:
            if args.get("type") != "ItemSend":
                return
            receiving = int(args.get("receiving") or 0)
            raw = args.get("item")
            if raw is None:
                return
            if isinstance(raw, dict):
                finder = int(raw.get("player") or 0)
                item_id = int(raw.get("item") or 0)
            else:
                finder = int(getattr(raw, "player", 0) or 0)
                item_id = int(getattr(raw, "item", 0) or 0)
            if finder != self.slot or receiving == self.slot or receiving <= 0:
                return
            try:
                item_name = self.item_names.lookup_in_slot(item_id, receiving)
            except Exception:
                item_name = self.item_names.lookup_in_game(item_id)
            dest = self.player_names.get(receiving) or ("Player " + str(receiving))
            if item_name:
                await self.send_game("MSG Sent " + str(item_name) + " to " + str(dest))

        async def on_check(self, unique: str) -> None:
            unique = canonical_unique(unique)
            if not is_valid_check_unique(unique):
                logger.debug("CHECK ignored garbage unique %r", unique)
                return
            ap_name = UNIQUE_TO_NAME.get(unique) or UNIQUE_UPPER_TO_NAME.get(unique.upper())
            if ap_name is None:
                logger.info("CHECK %s (not in AP location table)", unique)
                await self.send_game(f"SENT {unique}")
                return
            loc_id = NAME_TO_ID[ap_name]
            self.locations_checked.add(loc_id)
            if not self._ap_ready or not self._server_socket_up():
                if unique not in self._check_queue and len(self._check_queue) < 800:
                    self._check_queue.append(unique)
                return
            if self.missing_locations:
                await self.check_locations({loc_id})
            elif self.slot:
                await self.send_msgs([{"cmd": "LocationChecks", "locations": [loc_id]}])
            await self._push_tracker()

        async def handle_game_line(self, line: str) -> None:
            line = line.strip()
            if not line:
                return
            if " " in line:
                cmd, arg = line.split(" ", 1)
            else:
                cmd, arg = line, ""
            cmd = cmd.upper()
            if cmd == "HELLO":
                await self.send_game("WELCOME")
                if self.slot and not self._tcp_state_sent:
                    await self.send_game("SEED " + (self.ap_seed or "same"))
                    await self._send_options()
                    await self._push_world_state()
                    await self._push_vendor_hints()
                    await self._push_tracker()
                    self._tcp_state_sent = True
            elif cmd == "CHECK":
                unique = canonical_unique(arg)
                if not is_valid_check_unique(unique):
                    logger.debug("CHECK ignored garbage unique %r", unique)
                    return
                if not self._ap_ready:
                    self._check_queue.append(unique)
                    return
                await self.on_check(unique)
            elif cmd == "CONNECT":
                await self.on_game_connect(arg)
            elif cmd == "DISCONNECT":
                logger.info("Game asked to disconnect from Archipelago")
                await self.disconnect()
            elif cmd == "GOAL":
                await self.send_msgs([{"cmd": "StatusUpdate", "status": ClientStatus.CLIENT_GOAL}])
                await self.send_game("MSG Friday complete — goal sent.")
            elif cmd in ("RESYNC", "CATCHUP"):
                if not self.slot:
                    if cmd == "RESYNC":
                        await self.send_game("MSG Connect the Postal 2 Client to Archipelago first.")
                    return
                now = time.time()
                if now - self._last_catchup < 1.5:
                    return
                self._last_catchup = now
                # Map travel already dumps on TCP accept. CATCHUP after that is
                # noise: log once per AP session, skip the extra dump.
                if cmd == "CATCHUP" and self._tcp_state_sent:
                    if not self._logged_catchup:
                        logger.info(
                            "Game requested AP catch-up (%s items)",
                            len(self.items_received or ()),
                        )
                        self._logged_catchup = True
                    else:
                        logger.debug("CATCHUP ignored (already pushed this connection)")
                    return
                logger.info("Game requested AP catch-up (%s items)", len(self.items_received or ()))
                self._logged_catchup = True
                await self.send_game("SEED " + (self.ap_seed or "same"))
                await self._send_options()
                await self._push_world_state()
                await self._push_vendor_hints()
                await self._grant_from(0, resync=True)
                await self._push_tracker()
                if cmd == "RESYNC":
                    await self.send_game("MSG AP items reapplied from the multiworld.")
            elif cmd == "DIED":
                if "DeathLink" not in self.tags or not self._server_socket_up():
                    return
                await self.send_death(one_line(arg, "The Dude died."))
            else:
                logger.debug("unknown game command: %s", line)

        def on_deathlink(self, data: dict) -> None:
            super().on_deathlink(data)
            cause = one_line(str(data.get("cause") or ""), "Death Link")
            async_start(self.send_game("DEATHLINK " + cause), name="postal2-deathlink")

        async def on_game_connect(self, arg: str) -> None:
            parts = arg.split(" ", 2)
            if not parts or not parts[0].strip():
                await self.send_game("MSG Use the Postal 2 Client window to connect, or: CONNECT host:port slot")
                return
            address = parts[0].strip()
            slot = parts[1].strip() if len(parts) > 1 and parts[1].strip() else (self.auth or "")
            password = parts[2] if len(parts) > 2 else ""
            if self.slot and self.server and self.server.socket and not self.server.socket.closed:
                await self.send_game(
                    "MSG Already connected as "
                    + (self.auth or "player")
                    + ". Use the client to change rooms."
                )
                return
            self.auth = slot or self.auth
            if password:
                self.password = password
            logger.info("Game requested connect %s as %s", address, self.auth)
            await self.connect(address)

        async def game_tcp_loop(self) -> None:
            server = await asyncio.start_server(self._game_client, GAME_TCP_HOST, self.game_port)
            logger.info("Postal 2 TCP listening on %s:%s", GAME_TCP_HOST, self.game_port)
            async with server:
                await server.serve_forever()

        async def _game_client(
            self, reader: asyncio.StreamReader, writer: asyncio.StreamWriter
        ) -> None:
            addr = writer.get_extra_info("peername")
            now = time.time()
            quick = self._game_tcp_seen and now - self._last_game_drop < 8.0
            if quick:
                logger.debug("Postal 2 connected from %s", addr)
            else:
                logger.info("Postal 2 connected")
            self._game_tcp_seen = True
            old = self.game_writer
            self.game_writer = writer
            if old is not None and old is not writer:
                try:
                    old.close()
                except Exception:
                    pass
            self._tcp_state_sent = False
            await self.send_game("WELCOME")
            if self.slot:
                await self.send_game("SEED " + (self.ap_seed or "same"))
                await self._send_options()
                await self._push_world_state()
                await self._push_vendor_hints()
                await self._grant_from(0, resync=True)
                await self._push_tracker()
                self._tcp_state_sent = True
            try:
                while True:
                    raw = await reader.readline()
                    if not raw:
                        break
                    line = raw.decode("ascii", errors="replace").replace("\r", "").rstrip("\n")
                    await self.handle_game_line(line)
            except (ConnectionResetError, BrokenPipeError):
                pass
            finally:
                if self.game_writer is writer:
                    self.game_writer = None
                try:
                    writer.close()
                    await writer.wait_closed()
                except Exception:
                    pass
                self._last_game_drop = time.time()
                logger.debug("Postal 2 disconnected (waiting for reconnect).")

    return Postal2ContextImpl


def launch(*args: str) -> None:
    import asyncio
    import sys

    import colorama
    from CommonClient import get_base_parser, gui_enabled, handle_url_arg, server_loop

    parser = get_base_parser(description="Postal 2 Archipelago Client")
    parser.add_argument("--name", default=None, help="Slot name to connect as.")
    parser.add_argument("url", nargs="?", help="Archipelago connection url")
    parser.add_argument("--game-port", type=int, default=GAME_TCP_PORT)
    parsed = parser.parse_args(args)
    parsed = handle_url_arg(parsed, parser=parser)

    ctx_cls = _build_context_class()

    async def main() -> None:
        ctx = ctx_cls(parsed.connect, parsed.password)
        ctx.game_port = parsed.game_port
        if parsed.name:
            ctx.auth = parsed.name
        ctx.server_task = asyncio.create_task(server_loop(ctx), name="server loop")
        ctx.game_task = asyncio.create_task(ctx.game_tcp_loop(), name="game tcp")
        if gui_enabled:
            ctx.run_gui()
        ctx.run_cli()
        await ctx.exit_event.wait()
        await ctx.shutdown()

    colorama.just_fix_windows_console()
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
    colorama.deinit()
    sys.exit(0)


if __name__ == "__main__":
    import sys
    launch(*sys.argv[1:])
