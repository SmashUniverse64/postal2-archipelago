"""In-logic tracker for the Postal 2 client.

Mirrors worlds.postal2 set_rules so the CommonClient can list checks that
are reachable with the items you currently hold, without Universal Tracker.
"""

from __future__ import annotations

from .data import (
    DAYS,
    MAPS,
    TOKEN_UNIQUE_TO_MAP,
    errand_item_name,
    errand_item_names_for_day,
    errands_for_day,
    world_locations,
)

_LOC_META: dict[str, dict] | None = None


def _meta() -> dict[str, dict]:
    global _LOC_META
    if _LOC_META is None:
        _LOC_META = {loc["name"]: loc for loc in world_locations(True, True, True)}
    return _LOC_META


def collected_item_names(ctx) -> set[str]:
    names: set[str] = set()
    lookup = getattr(ctx, "item_names", None)
    if lookup is None:
        return names
    for net_item in getattr(ctx, "items_received", ()):
        item_id = int(getattr(net_item, "item", 0) or 0)
        try:
            name = lookup.lookup_in_game(item_id)
        except Exception:
            name = ""
        if name:
            names.add(name)
    return names


def day_open(items: set[str], day: int, start_day: int = 0) -> bool:
    if day == start_day:
        return True
    needed = errand_item_names_for_day(day)
    if not needed:
        return False
    return any(name in items for name in needed)


def dad_reachable(items: set[str], start_day: int = 0) -> bool:
    return day_open(items, 2, start_day) and "Errand - Piss on Dad" in items


def location_in_logic(name: str, items: set[str], map_days=None, start_day: int = 0) -> bool:
    meta = _meta().get(name)
    unique = meta["unique"] if meta else ""
    day = int(meta["day"]) if meta else 0
    mk = ""
    if meta:
        mk = meta.get("map") or TOKEN_UNIQUE_TO_MAP.get(unique, "")
    if map_days and unique.startswith("Enter_"):
        mk = unique[6:]
        if mk in map_days:
            day = int(map_days[mk])
        else:
            vis = [int(map_days[m["key"]]) for m in MAPS
                   if m.get("visit") == mk and m["key"] in map_days]
            if vis:
                day = min(vis)
    elif map_days and mk and unique.startswith("SC_"):
        day = int(map_days.get(mk, day))
    if not day_open(items, day, start_day):
        return False
    need = errand_item_name(unique) if unique else ""
    if need and need not in items:
        return False
    if unique in ("PickupLaundry", "BreweryRestore") and not dad_reachable(items, start_day):
        return False
    if unique == "FridayHome" or name == "Home - End of the Week":
        for friday in errands_for_day(4, for_sleep=False):
            if not location_in_logic(friday, items, map_days, start_day):
                return False
    return True


def in_logic_rows(ctx) -> list[tuple[int, str]]:
    items = collected_item_names(ctx)
    slot = getattr(ctx, "slot_data", None) or {}
    map_days = slot.get("map_days") or {}
    start_day = int(slot.get("start_day", 0) or 0)
    if start_day < 0 or start_day > 4:
        start_day = 0
    rows: list[tuple[int, str]] = []
    lookup = getattr(ctx, "location_names", None)
    if lookup is None:
        return rows
    for loc_id in getattr(ctx, "missing_locations", ()):
        try:
            name = lookup.lookup_in_game(int(loc_id))
        except Exception:
            continue
        if not name or not location_in_logic(name, items, map_days, start_day):
            continue
        meta = _meta().get(name)
        day = int(meta["day"]) if meta else 0
        rows.append((day, name))
    rows.sort(key=lambda r: (r[0], r[1].lower()))
    return rows


def tracker_summary(ctx) -> tuple[int, int]:
    rows = in_logic_rows(ctx)
    missing = len(getattr(ctx, "missing_locations", ()) or ())
    return len(rows), missing
