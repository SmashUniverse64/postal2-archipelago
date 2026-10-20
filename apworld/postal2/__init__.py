"""Postal 2 Archipelago world — original Monday-Friday campaign."""

from typing import ClassVar

from BaseClasses import Item, ItemClassification, Location, Region, Tutorial
from worlds.AutoWorld import WebWorld, World
from worlds.generic.Rules import add_item_rule, set_rule

from .data import (
    DAYS,
    GAME_NAME,
    ITEM_EARLIEST_DAY,
    ITEMS,
    MONDAY_STARTER_ERRANDS,
    STARTER_ERRANDS_BY_DAY,
    STARTING_WEAPONS,
    ERRAND_UNIQUES,
    world_locations,
    errand_item_name,
    errand_unique_from_item,
    errand_item_names_for_day,
    errands_for_day,
    item_name_to_id,
    location_name_to_id,
    location_unique_to_name,
    choose_scrounge,
    choose_day_order,
    normalize_day_order,
    errand_item_flow_ok,
    choose_map_days,
    choose_vending_counts,
    FILLER_WEIGHTS,
    TOKEN_UNIQUE_TO_MAP,
    MAPS,
)
from .options import Postal2Options

CLASSIFICATION = {
    "progression": ItemClassification.progression,
    "useful": ItemClassification.useful,
    "filler": ItemClassification.filler,
    "trap": ItemClassification.trap,
}


class Postal2Web(WebWorld):
    theme = "dirt"
    rich_text_options_doc = True
    tutorials = [
        Tutorial(
            "Multiworld Setup Guide",
            "A guide to setting up Postal 2 for Archipelago",
            "English",
            "setup_en.md",
            "setup/en",
            ["Postal 2 AP"],
        )
    ]


class Postal2Item(Item):
    game = GAME_NAME


class Postal2Location(Location):
    game = GAME_NAME


class Postal2World(World):
    """The original POSTAL 2 week. YAML Starting Day picks the weekday you
    load into; Time Warp hops between unlocked days. Goal is all 19 errands
    and returning home."""

    game = GAME_NAME
    web = Postal2Web()
    options_dataclass = Postal2Options
    options: Postal2Options
    topology_present = True

    item_name_to_id = item_name_to_id()
    location_name_to_id = location_name_to_id()

    def generate_early(self) -> None:
        start = int(self.options.starting_day.value)
        if start < 0 or start > 4:
            start = self.random.randint(0, 4)
        self.start_day = start
        self.day_order = choose_day_order(self.random, start)
        self.scrounge_chosen = choose_scrounge(
            self.random,
            max_tokens=int(self.options.max_tokens.value),
            lootsanity=bool(self.options.lootsanity),
        )
        self.scrounge_uniques = {e["unique"] for e in self.scrounge_chosen}
        self.map_days = choose_map_days(
            self.random, start_day=start, day_order=self.day_order
        )
        max_slots = int(self.options.vending_slots.value)
        if not self.options.vending_sanity:
            max_slots = 0
        self.vending_counts = choose_vending_counts(self.random, max_slots)

    def _active_locations(self):
        locs = world_locations(
            vending=bool(self.options.vending_sanity),
            crackola=bool(self.options.crackola_sanity),
            atm=bool(self.options.atm_sanity),
            scrounge_uniques=getattr(self, "scrounge_uniques", None),
            vending_counts=getattr(self, "vending_counts", None),
        )
        md = getattr(self, "map_days", None) or {}
        out = []
        for loc in locs:
            loc = dict(loc)
            mk = loc.get("map") or TOKEN_UNIQUE_TO_MAP.get(loc["unique"], "")
            u = loc["unique"]
            if mk and loc.get("kind") == "scrounge":
                if mk in md:
                    loc["day"] = int(md[mk])
            elif u.startswith("Enter_") and md:
                mk = u[6:]
                if mk in md:
                    loc["day"] = int(md[mk])
                else:
                    vis = [int(md[m["key"]]) for m in MAPS
                           if m.get("visit") == mk and m["key"] in md]
                    if vis:
                        loc["day"] = min(vis)
            out.append(loc)
        return out

    def create_regions(self) -> None:
        menu = Region("Menu", self.player, self.multiworld)
        self.multiworld.regions.append(menu)

        active = self._active_locations()
        day_regions: list[Region] = []
        for i, day_name in enumerate(DAYS):
            region = Region(day_name, self.player, self.multiworld)
            for loc in active:
                if loc["day"] != i:
                    continue
                loc_name = loc["name"]
                loc = Postal2Location(
                    self.player,
                    loc_name,
                    self.location_name_to_id[loc_name],
                    region,
                )
                region.locations.append(loc)
            self.multiworld.regions.append(region)
            day_regions.append(region)

        start_day = int(getattr(self, "start_day", 0) or 0)
        if start_day < 0 or start_day > 4:
            start_day = 0
        menu.connect(day_regions[start_day])
        player = self.player
        for i in range(len(day_regions)):
            if i == start_day:
                continue
            items = tuple(errand_item_names_for_day(i))
            menu.connect(
                day_regions[i],
                f"Time Warp to {DAYS[i]}",
                lambda state, needed=items, p=player: any(state.has(n, p) for n in needed),
            )

        friday = day_regions[-1]
        victory_loc = Postal2Location(self.player, "Finish Friday", None, friday)
        victory_loc.place_locked_item(
            Postal2Item("Victory", ItemClassification.progression, None, self.player)
        )
        friday.locations.append(victory_loc)
        friday_goal = [
            loc["name"] for loc in active if loc["unique"] in ERRAND_UNIQUES
        ] + ["Home - End of the Week"]
        set_rule(
            victory_loc,
            lambda state, required=friday_goal, p=player: all(
                state.can_reach_location(name, p) for name in required
            ),
        )
        self.multiworld.completion_condition[self.player] = (
            lambda state, p=player: state.has("Victory", p)
        )

    def set_rules(self) -> None:
        player = self.player
        active = self._active_locations()
        start_day = int(getattr(self, "start_day", 0) or 0)
        order = normalize_day_order(getattr(self, "day_order", None), start_day)
        for loc in active:
            loc_day = loc["day"]

            def _item_ok(item, loc_day=loc_day, p=player, order=order):
                if item.player != p:
                    return True
                item_day = ITEM_EARLIEST_DAY.get(item.name)
                if item_day is None:
                    return True
                return errand_item_flow_ok(int(item_day), int(loc_day), order)

            add_item_rule(
                self.multiworld.get_location(loc["name"], player),
                _item_ok,
            )
        for loc in active:
            errand_item = errand_item_name(loc["unique"])
            if not errand_item:
                continue
            set_rule(
                self.multiworld.get_location(loc["name"], player),
                lambda state, need=errand_item, p=player: state.has(need, p),
            )
        present = {loc["name"] for loc in active}
        if "Money Shot Laundromat - Pickup Laundry" in present:
            set_rule(
                self.multiworld.get_location("Money Shot Laundromat - Pickup Laundry", player),
                lambda state, p=player: state.can_reach_location("Cemetery - Piss on Dad", p),
            )
        set_rule(
            self.multiworld.get_location("Brewery - Restore Loadout", player),
            lambda state, p=player: state.can_reach_location("Cemetery - Piss on Dad", p),
        )
        if "Home - End of the Week" in present:
            friday_errands = errands_for_day(4, for_sleep=False)
            set_rule(
                self.multiworld.get_location("Home - End of the Week", player),
                lambda state, required=friday_errands, p=player: all(
                    state.can_reach_location(name, p) for name in required
                ),
            )

    def create_item(self, item: str) -> Postal2Item:
        classification = ItemClassification.filler
        for data in ITEMS:
            if data["name"] == item:
                classification = CLASSIFICATION[data["classification"]]
                break
        return Postal2Item(item, classification, self.item_name_to_id[item], self.player)

    def create_items(self) -> None:
        start_day = int(getattr(self, "start_day", 0) or 0)
        if start_day < 0 or start_day > 4:
            start_day = 0
        starters = STARTER_ERRANDS_BY_DAY.get(start_day) or MONDAY_STARTER_ERRANDS
        starter = self.random.choice(list(starters))
        self.monday_starter = errand_unique_from_item(starter)
        self.multiworld.push_precollected(self.create_item(starter))
        skip = {starter}
        if self.options.random_weapon:
            gun = self.random.choice(list(STARTING_WEAPONS))
            self.multiworld.push_precollected(self.create_item(gun))
            skip.add(gun)
        pool: list[Postal2Item] = []
        for data in ITEMS:
            if data["name"] in skip:
                continue
            if data["name"] == "Tora Bora Access":
                continue
            if data["name"] == "Weapon Repair Kit" and not self.options.melee_durability:
                continue
            if data["name"] == "Water Bottle" and not self.options.piss_realism:
                continue
            if not self.options.traps and data["classification"] == "trap":
                continue
            for _ in range(data["count"]):
                pool.append(self.create_item(data["name"]))
        extra = len(self.multiworld.get_unfilled_locations(self.player)) - len(pool)
        if extra < 0:
            # Too many pre-placed items: drop filler from the end of the build list.
            keep: list[Postal2Item] = []
            skip = -extra
            dropped = 0
            for it in reversed(pool):
                if dropped < skip and it.classification == ItemClassification.filler:
                    dropped += 1
                    continue
                keep.append(it)
            pool = list(reversed(keep))
            extra = len(self.multiworld.get_unfilled_locations(self.player)) - len(pool)
        for _ in range(max(0, extra)):
            pool.append(self.create_item(self.get_filler_item_name()))
        self.multiworld.itempool += pool

    def get_filler_item_name(self) -> str:
        weights = FILLER_WEIGHTS
        if not self.options.melee_durability:
            weights = tuple((n, w) for n, w in weights if n != "Weapon Repair Kit")
        if not self.options.piss_realism:
            weights = tuple((n, w) for n, w in weights if n != "Water Bottle")
        total = sum(w for _, w in weights)
        roll = self.random.randrange(total)
        acc = 0
        for name, w in weights:
            acc += w
            if roll < acc:
                return name
        return "Spare Ammo"

    def fill_slot_data(self) -> dict:
        n2u = {v: k for k, v in location_unique_to_name().items()}
        token_u = set(getattr(self, "scrounge_uniques", None) or [])
        grey = []
        prog = ItemClassification.progression
        useful = getattr(ItemClassification, "useful", None)
        for loc in self.multiworld.get_locations(self.player):
            item = loc.item
            if item is None:
                continue
            cls = item.classification
            if useful is not None:
                if (cls & prog) or (cls & useful):
                    continue
            elif cls == prog:
                continue
            u = n2u.get(loc.name)
            if u and (not token_u or u in token_u):
                grey.append(u)
        return {
            "goal": "friday",
            "death_link": bool(self.options.death_link.value),
            "shuffle_weapons": bool(self.options.shuffle_weapons.value),
            "clinic_always": True,
            "random_weapon": bool(self.options.random_weapon.value),
            "traps": bool(self.options.traps.value),
            "vending_sanity": bool(self.options.vending_sanity.value),
            "vending_slots": int(self.options.vending_slots.value),
            "vending_counts": dict(getattr(self, "vending_counts", {})),
            "max_tokens": int(self.options.max_tokens.value),
            "lootsanity": bool(self.options.lootsanity.value),
            "crackola_sanity": bool(self.options.crackola_sanity.value),
            "atm_sanity": bool(self.options.atm_sanity.value),
            "scrounge": [e["unique"] for e in getattr(self, "scrounge_chosen", [])],
            "monday_starter": getattr(self, "monday_starter", "") or "",
            "start_day": int(getattr(self, "start_day", 0) or 0),
            "day_order": list(
                normalize_day_order(
                    getattr(self, "day_order", None),
                    int(getattr(self, "start_day", 0) or 0),
                )
            ),
            "token_glow": bool(self.options.token_glow.value),
            "token_heartbeat": bool(self.options.token_heartbeat.value),
            "melee_durability": bool(self.options.melee_durability.value),
            "piss_realism": bool(self.options.piss_realism.value),
            "piss_regen": int(self.options.piss_regen.value),
            "map_days": dict(getattr(self, "map_days", {})),
            "filler_tokens": grey,
        }


def run_postal2_client(*args: str) -> None:
    from .Client import launch as launch_client
    try:
        from worlds.LauncherComponents import launch
        launch(launch_client, name="Postal 2 Client", args=args)
    except TypeError:
        from worlds.LauncherComponents import launch_subprocess
        launch_subprocess(lambda: launch_client(*args), name="Postal 2 Client")


try:
    from worlds.LauncherComponents import Component, Type, components

    components.append(
        Component(
            "Postal 2 Client",
            func=run_postal2_client,
            game_name="Postal 2",
            component_type=Type.CLIENT,
            supports_uri=True,
            description="Connect Postal 2 to Archipelago. Keep this open while you play.",
        )
    )
except Exception:
    pass
