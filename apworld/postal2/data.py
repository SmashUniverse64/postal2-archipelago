"""Shared Postal 2 Archipelago data (APWorld + Postal 2 Client)."""

import math
from collections import defaultdict

from .catalog import SCROUNGE_CATALOG
from .hint_names import EXTRA_SCROUNGE_CATALOG, apply_hint_names

GAME_NAME = "Postal 2"
BASE_ID = 232000

DAYS = ("Monday", "Tuesday", "Wednesday", "Thursday", "Friday")

# Next-day progression items. Monday needs Tuesday to sleep, and so on.
# Friday has no Saturday gate — finishing Friday errands is the goal.
DAY_GATES = ("Tuesday", "Wednesday", "Thursday", "Friday")

# YAML Max Tokens Per Map. Each playable map rolls TOKEN_CAP_MIN through the
# YAML maximum, then keeps at most as many spaced piles as the map has.
TOKEN_CAP_MIN = 6
TOKEN_CAP_MAX = 15
TOKEN_CAP_DEFAULT = 12

# Weekday campaign maps. key must match APGameInfo.MapKey() (caps map name,
# NGT- prefix stripped). pickups > 0 means the map can host world AP tokens
# (catalog scrounge, including former named-cache piles). The per-map count is rolled at generate
# time from TOKEN_CAP_MIN through the YAML max (default 12).
# In-game geography (not the .fuk filename):
#   suburbs-3 = Dude's trailer (start of each day)
#   suburbs-1 = Main Street (Lucky Ganesh)
#   Greenbelt1 = Greenbelt / bank plaza
#   Highlands = Trainyard Area (in-game title)
#   suburbs-2 = Ghetto (in-game title)
#   Industry = Clinic Area (in-game title); Industry2 = Industrial Area
# day = earliest weekday the player can enter (0=Mon). Hunts never assign a
# map before this (telepads + day groups + campaign gates):
#   Mon: Home, Main Street, Ghetto, Greenbelt, Estates, Office Complex,
#        Police, Sewers, Clinic Area, Industrial Area
#        (Tora physically open; hunt biased later)
#   Tue: Library, Library Interior, East/West Mall, Trainyard
#   Wed: Forest, Brewery, Church hunts (map is visitable Tuesday for confession;
#        cemetery gate is Wednesday, so scrounge waits)
# Clinic/Industrial stay physically open Monday; MAPS[].day 2 only delays hunts.
#   Thu: Napalm Factory, Napalm Factory Exterior, Meat World, Suburbs East
#   Fri: Compound, Parcel Center, Junkyard
MAPS = [
    # intro.fuk is the unplayable opening. Keep the row so leftover SC_INTRO_
    # catalog IDs stay put; pickups 0 and world_locations drop its checks.
    {"key": "INTRO", "name": "Intro", "day": 0, "pickups": 0, "visit": None, "enter": False},
    {"key": "GREENBELT1", "name": "Greenbelt", "day": 0, "pickups": 12, "visit": "GREENBELT"},
    {"key": "GREENBELT2", "name": "Napalm Factory Exterior", "day": 3, "pickups": 12, "visit": "GREENBELT"},
    {"key": "ESTATES", "name": "Estates", "day": 0, "pickups": 12},
    {"key": "RWSBLOCK", "name": "Office Complex", "day": 0, "pickups": 12},
    {"key": "HIGHLANDS", "name": "Trainyard Area", "day": 1, "pickups": 12},
    {"key": "POLICE", "name": "Police Station", "day": 0, "pickups": 12},
    {"key": "INDUSTRY", "name": "Clinic Area", "day": 2, "pickups": 12, "visit": "INDUSTRY"},
    {"key": "INDUSTRY2", "name": "Industrial Area", "day": 2, "pickups": 12, "visit": "INDUSTRY"},
    {"key": "UNDERHUB", "name": "Sewer", "day": 0, "pickups": 12},
    {"key": "TORABORA", "name": "Tora Bora", "day": 0, "pickups": 12},
    {"key": "LIBRARY1", "name": "Library", "day": 1, "pickups": 12, "visit": "LIBRARY"},
    {"key": "LIBRARY2", "name": "Library Interior", "day": 1, "pickups": 12, "visit": "LIBRARY"},
    {"key": "EASTMALL", "name": "East Mall", "day": 1, "pickups": 12},
    {"key": "WESTMALL", "name": "West Mall", "day": 1, "pickups": 12},
    {"key": "CHURCH", "name": "Church", "day": 2, "pickups": 12},
    {"key": "FOREST", "name": "Forest", "day": 2, "pickups": 12},
    {"key": "BREWERY", "name": "Brewery", "day": 2, "pickups": 12},
    {"key": "NAPALM", "name": "Napalm Factory", "day": 3, "pickups": 12},
    {"key": "SUBURBS-1", "name": "Main Street", "day": 0, "pickups": 12},
    {"key": "SUBURBS-2", "name": "Ghetto", "day": 0, "pickups": 12},
    {"key": "SUBURBS-3", "name": "Home", "day": 0, "pickups": 12},
    {"key": "SUBURBS-4", "name": "Suburbs East", "day": 3, "pickups": 12},
    {"key": "SLAUGHTERHOUSE", "name": "Meat World", "day": 3, "pickups": 12},
    {"key": "COMPOUND", "name": "Compound", "day": 4, "pickups": 12},
    {"key": "PARCELCENTER", "name": "Parcel Center", "day": 4, "pickups": 12},
    {"key": "JUNKYARD", "name": "Junkyard", "day": 4, "pickups": 12},
]


# ATF/fast-food machines. VUSE = open menu. Each machine can sell up to
# VENDOR_BUY_SLOTS_MAX unique AP parcels (VBUY_MAP_01 … _05). YAML
# vending_slots is the per-seed maximum; generate rolls 0..that per machine.
VENDOR_CAPS = {
    "GREENBELT1": 1,
    "RWSBLOCK": 1,
    "EASTMALL": 1,
    "SUBURBS-4": 1,
}
VENDOR_BUY_SLOTS_MAX = 5
VENDOR_BUY_SLOTS_DEFAULT = 3
VENDOR_BUY_SLOTS = VENDOR_BUY_SLOTS_MAX

# Kickable ATMs
ATM_CAPS = {
    "SUBURBS-3": 1,
    "SUBURBS-1": 1,
    "SUBURBS-2": 1,
    "GREENBELT1": 1,
    "EASTMALL": 2,
    "WESTMALL": 1,
}

# Kickable / buyable Crackola machines. Caps are per map, not per cabinet:
# machines spawn in pairs and share one check. EASTMALL stays 2 in this table
# so COLA_EASTMALL_02 keeps its location ID; that unique is retired below and
# the mutator ColaCap is 1 so both cabinets send COLA_EASTMALL_01.
COLA_CAPS = {
    "GREENBELT1": 1,
    "RWSBLOCK": 1,
    "POLICE": 1,
    "EASTMALL": 2,
    "WESTMALL": 1,
    "SUBURBS-3": 1,
    "PARCELCENTER": 1,
}


def _map_by_key(key: str) -> dict:
    for m in MAPS:
        if m["key"] == key:
            return m
    raise KeyError(key)


def _map_locations():
    locs = []
    seen_visits = set()
    for m in MAPS:
        # Always emit Enter_INTRO here so later location IDs do not shift.
        # world_locations drops it from the seed.
        locs.append({
            "unique": f"Enter_{m['key']}",
            "name": f"Enter {m['name']}",
            "day": m["day"],
        })
        visit = m.get("visit")
        if visit and visit not in seen_visits:
            seen_visits.add(visit)
            visit_name = m["name"]
            if visit == "GREENBELT":
                visit_name = "Greenbelt"
            elif visit == "INDUSTRY":
                visit_name = "Industrial"
            elif visit == "LIBRARY":
                visit_name = "Library"
            if visit != m["key"]:
                locs.append({
                    "unique": f"Enter_{visit}",
                    "name": f"Enter {visit_name} District",
                    "day": m["day"],
                })
    for e in SCROUNGE_CATALOG:
        m = _map_by_key(e["map"])
        locs.append({
            "unique": e["unique"],
            "name": e["name"],
            "day": m["day"],
            "kind": "scrounge",
            "map": e["map"],
        })
    for key, cap in VENDOR_CAPS.items():
        m = _map_by_key(key)
        for i in range(1, cap + 1):
            locs.append({
                "unique": f"VUSE_{key}_{i:02d}",
                "name": f"{m['name']} - Use Vending Machine {i:02d}",
                "day": m["day"],
                "option": "vending",
            })
        # Slots 1-3 stay in this original table position so COLA/ATM IDs
        # do not shift. Extra slots 4-5 are appended after ATM below.
        for machine in range(1, cap + 1):
            for slot in range(1, VENDOR_BUY_SLOTS_DEFAULT + 1):
                i = _vbuy_index(machine, slot)
                locs.append({
                    "unique": f"VBUY_{key}_{i:02d}",
                    "name": f"{m['name']} - Vending Item {i:02d}",
                    "day": m["day"],
                    "option": "vending",
                })
    for key, cap in COLA_CAPS.items():
        m = _map_by_key(key)
        for i in range(1, cap + 1):
            locs.append({
                "unique": f"COLA_{key}_{i:02d}",
                "name": f"{m['name']} - Crackola Machine {i:02d}",
                "day": m["day"],
                "option": "crackola",
            })
    for key, cap in ATM_CAPS.items():
        m = _map_by_key(key)
        for i in range(1, cap + 1):
            locs.append({
                "unique": f"ATM_{key}_{i}",
                "name": f"ATM - {m['name']}" + (f" {i}" if cap > 1 else ""),
                "day": m["day"],
                "option": "atm",
            })
    # Extra vending buy slots 4-5 (appended so earlier location IDs stay put).
    for key, cap in VENDOR_CAPS.items():
        m = _map_by_key(key)
        for machine in range(1, cap + 1):
            for slot in range(VENDOR_BUY_SLOTS_DEFAULT + 1, VENDOR_BUY_SLOTS_MAX + 1):
                i = _vbuy_index(machine, slot)
                locs.append({
                    "unique": f"VBUY_{key}_{i:02d}",
                    "name": f"{m['name']} - Vending Item {i:02d}",
                    "day": m["day"],
                    "option": "vending",
                })
    return locs


def _extra_scrounge_locations():
    """Former named-cache piles as SC_ checks, appended so earlier IDs stay put."""
    locs = []
    for e in EXTRA_SCROUNGE_CATALOG:
        mk = e["map"]
        if mk == "INTRO":
            continue
        m = _map_by_key(mk)
        locs.append({
            "unique": e["unique"],
            "name": e["name"],
            "day": m["day"],
            "kind": "scrounge",
            "map": mk,
        })
    return locs


def _vbuy_index(machine: int, slot: int) -> int:
    return (machine - 1) * VENDOR_BUY_SLOTS_MAX + slot


def parse_vbuy_unique(unique: str):
    """Return (map_key, slot_number) for VBUY_GREENBELT1_01, or None."""
    if not unique.startswith("VBUY_"):
        return None
    rest = unique[5:]
    if len(rest) < 4 or rest[-3] != "_":
        return None
    try:
        slot = int(rest[-2:])
    except ValueError:
        return None
    return rest[:-3], slot


def vbuy_slot_enabled(unique: str, vending_counts) -> bool:
    parsed = parse_vbuy_unique(unique)
    if parsed is None or vending_counts is None:
        return True
    key, slot = parsed
    local = ((slot - 1) % VENDOR_BUY_SLOTS_MAX) + 1
    machine = (slot - 1) // VENDOR_BUY_SLOTS_MAX
    n = vending_counts.get(key, 0)
    if isinstance(n, (list, tuple)):
        n = n[machine] if machine < len(n) else 0
    return 1 <= local <= int(n)


def choose_vending_counts(rng, max_slots: int) -> dict:
    """Per-map AP parcel counts. Each listed machine rolls 0..max_slots."""
    max_slots = max(0, min(int(max_slots), VENDOR_BUY_SLOTS_MAX))
    counts = {}
    for key in VENDOR_CAPS:
        counts[key] = rng.randint(0, max_slots) if max_slots else 0
    return counts


# unique: string the UnrealScript mutator sends with CHECK
# name: Archipelago location name
# day: 0=Monday .. 4=Friday (region / vanilla map-open day)
LOCATIONS = [
    # --- 19 errands ---
    {"unique": "GetPaycheck", "name": "Office Complex - Pick Up Paycheck", "day": 0},
    {"unique": "CashPaycheck", "name": "Bank - Cash Paycheck", "day": 0},
    {"unique": "GetMilk", "name": "Lucky Ganesh - Get Milk", "day": 0},
    {"unique": "VisitPriest", "name": "Church - Confess Sins", "day": 1},
    {"unique": "GetSignatures", "name": "Paradise - Petition Signatures", "day": 0},  # any-day; Monday region so it is in logic from the start
    {"unique": "ReturnBook", "name": "Library - Return Book", "day": 1},
    {"unique": "GetGary", "name": "East Mall - Gary Coleman's Autograph", "day": 1},
    {"unique": "VisitDad", "name": "Cemetery - Piss on Dad", "day": 2},
    {"unique": "Vote", "name": "Cock Asian - Vote", "day": 2},
    {"unique": "GetTree", "name": "Forest - Get Xmas Tree", "day": 2},
    {"unique": "PickupLaundry", "name": "Money Shot Laundromat - Pickup Laundry", "day": 2},
    {"unique": "GetNapalm", "name": "Napalm Factory - Get Napalm Launcher", "day": 3},
    {"unique": "GetKrotchy", "name": "West Mall - Get Krotchy Doll", "day": 3},
    {"unique": "GetSteaks", "name": "Meat World - Get Steaks", "day": 3},
    {"unique": "PayTicket", "name": "Police Station - Pay Ticket", "day": 3},
    {"unique": "GetAlternator", "name": "Junkyard - Get Alternator", "day": 4},
    {"unique": "PickupPackage", "name": "Parcel Center - Pick Up Package", "day": 4},
    {"unique": "GivePresent", "name": "Compound - Uncle Dave's Birthday", "day": 4},
    {"unique": "VisitClinic", "name": "Clinic - Gonorrhea Medicine", "day": 4},
    {"unique": "FridayHome", "name": "Home - End of the Week", "day": 4},
    # --- unique weapon stashes ---
    {"unique": "HomeShovel", "name": "Home - Shed Shovel", "day": 0},
    {"unique": "MainStreetRocket", "name": "Main Street - Dog Pit Rocket Launcher", "day": 0},
    {"unique": "MainStreetRifle", "name": "Greenbelt - Hunting Rifle on Rocky Slide", "day": 0},
    {"unique": "MainStreetDynamite", "name": "Greenbelt - Bank Roof Dynamite", "day": 0},
    {"unique": "IndustrialShotgun", "name": "Clinic Area - Warehouse Rooftop Shotgun", "day": 0},
    {"unique": "GreenbeltGL", "name": "Greenbelt 2 - Grenade Launcher Ledge", "day": 0},
    {"unique": "GreenbeltRifle", "name": "Greenbelt 2 - Hunting Rifle in Bushes", "day": 0},
    {"unique": "ToraMachete", "name": "Tora Bora - Machete", "day": 0},
    {"unique": "ToraWMD", "name": "Tora Bora - WMD Crate", "day": 0},
    {"unique": "ToraNuke", "name": "Tora Bora - Mini-Nuke Crate", "day": 0},
    {"unique": "ToraRifle", "name": "Tora Bora - Hunting Rifle Canyon", "day": 0},
    {"unique": "ToraCowHead", "name": "Tora Bora - Cow Head in Living Quarters", "day": 0},
    {"unique": "TrainyardBeta", "name": "Trainyard Area - Beta Shotgun Roof", "day": 1},
    {"unique": "MeatSawedOff", "name": "Meat World - Sawed-Off in Crate", "day": 3},
    {"unique": "MeatCowHead", "name": "Meat World - Cow Head in Waste Drain", "day": 3},
    {"unique": "CemeterySawedOff", "name": "Cemetery - Sawed-Off Under Bridge", "day": 2},
    {"unique": "CemeteryScythe", "name": "Cemetery - Scythe at Toxic Dump", "day": 2},
    {"unique": "EstatesScythe", "name": "Estates - Asylum Scythe", "day": 0},
    {"unique": "WestMallSawedOff", "name": "West Mall - Pet Store Vent Sawed-Off", "day": 1},
    {"unique": "ParcelRifle", "name": "Parcel Center - Sniper behind Building", "day": 4},
    {"unique": "ParcelRocket", "name": "Parcel Center - Rocket in Maze", "day": 4},
    {"unique": "NapalmRocket", "name": "Napalm Exterior - Rocket on AC Unit", "day": 3},
    {"unique": "NapalmFlame", "name": "Napalm Exterior - Flamethrower in Toilet", "day": 3},
    {"unique": "ClinicRocket", "name": "Clinic Area - Clinic Billboard Rocket", "day": 0},
    {"unique": "RWSRocket", "name": "Office Complex - Rocket in Mike J's Office", "day": 0},
    {"unique": "PoliceArmory", "name": "Police Station - Armory Rack", "day": 0},
    {"unique": "ForestSawedOff", "name": "Forest - Canyon Sawed-Off", "day": 2},
    {"unique": "ForestRifle", "name": "Forest - Rocky Passage Rifle", "day": 2},
    {"unique": "SuburbsChainsaw", "name": "Suburbs East - Bookcase Chainsaw", "day": 0},
    {"unique": "SuburbsSawedOff", "name": "Ghetto - Secret House Sawed-Off", "day": 0},
    {"unique": "EastMallATFBox", "name": "East Mall - ATF-R-US Electric Box", "day": 1},
    {"unique": "TrainyardSawedOff", "name": "Trainyard Area - Sawed-Off", "day": 1},
    {"unique": "TrainyardRifle", "name": "Trainyard Area - Hunting Rifle", "day": 1},
    {"unique": "TrainyardRocket", "name": "Trainyard Area - Rocket Launcher", "day": 1},
    {"unique": "TrainyardChainsaw", "name": "Trainyard Area - Chainsaw", "day": 1},
    {"unique": "GhettoRifle", "name": "Ghetto - Hunting Rifle", "day": 0},
    {"unique": "GhettoShotgun", "name": "Ghetto - Shotgun", "day": 0},
    {"unique": "SuburbsEastSawedOff", "name": "Suburbs East - Sawed-Off", "day": 0},
    {"unique": "HomeChainsaw", "name": "Home - Chainsaw", "day": 0},
    {"unique": "CompoundChainsaw", "name": "Compound - Chainsaw", "day": 4},
    {"unique": "SewerFlame", "name": "Sewer - Flamethrower", "day": 0},
    {"unique": "SewerShotgun", "name": "Sewer - Shotgun", "day": 0},
    {"unique": "LibrarySledge", "name": "Library Interior - Sledgehammer", "day": 1},
    {"unique": "JunkyardSledge", "name": "Junkyard - Sledgehammer", "day": 4},
    {"unique": "ClinicFlame", "name": "Clinic Area - Flamethrower", "day": 0},
    {"unique": "ClinicDynamite", "name": "Clinic Area - Dynamite", "day": 0},
    {"unique": "IndustrialDynamite", "name": "Industrial Area - Dynamite", "day": 0},
    {"unique": "EstatesFlame", "name": "Estates - Flamethrower", "day": 0},
    {"unique": "ForestFlame", "name": "Forest - Flamethrower", "day": 2},
    {"unique": "ChurchRocket", "name": "Church - Rocket Launcher", "day": 2},
    {"unique": "GreenbeltShotgun", "name": "Greenbelt - Shotgun", "day": 0},
    {"unique": "Greenbelt2Chainsaw", "name": "Greenbelt 2 - Chainsaw", "day": 0},
    {"unique": "RWSShotgun", "name": "Office Complex - Shotgun", "day": 0},
    # --- unique items ---
    {"unique": "PoliceCopUniform", "name": "Police Station - Cop Uniform Locker", "day": 0},
    {"unique": "PoliceRadar", "name": "Police Station - Bass Sniffer", "day": 0},
    {"unique": "ToraRadar", "name": "Tora Bora - Bass Sniffer", "day": 0},
    {"unique": "EstatesPiranha", "name": "Estates - Piranha Plug-in", "day": 0},
    {"unique": "TrainyardLargemouth", "name": "Trainyard Area - Largemouth Plug-in", "day": 1},
    {"unique": "GhettoChompy", "name": "Trainyard Area - Chompy Game Cartridge", "day": 1},
    {"unique": "SewerSiC", "name": "Sewer - Waterfall SiC Armor", "day": 0},
    {"unique": "SewerPipe", "name": "Sewer - Waterfall Health Pipe", "day": 0},
    {"unique": "SewerWardrobe", "name": "Sewer - Random Wardrobe", "day": 0},
    {"unique": "GaneshPipe", "name": "Lucky Ganesh - Vent-A-Cure Health Pipe", "day": 0},
    {"unique": "EastMallP3", "name": "East Mall - POSTAL III Box", "day": 1},
    {"unique": "BreweryGimp", "name": "Brewery - Gain Gimp Suit", "day": 2},
    {"unique": "BreweryRestore", "name": "Brewery - Restore Loadout", "day": 2},
    # --- set pieces (retired from the seed; IDs kept so later locations do not shift) ---
    {"unique": "BankBookcase", "name": "Bank - Vault Bookcase Exit", "day": 0},
    {"unique": "HomeChamp", "name": "Home - Champ", "day": 0},
    {"unique": "BankOrchestra", "name": "Bank - Orchestra / Terrorist Attack", "day": 0},
    # --- shops (retired from the seed; IDs kept so later locations do not shift) ---
    {"unique": "EastMallATFBuy", "name": "East Mall - ATF-R-US Purchase", "day": 1},
    {"unique": "MainStreetCats", "name": "Main Street - Cash 4 Cats", "day": 0},
    {"unique": "TrainyardApparel", "name": "Trainyard Area - Apocalypse Apparel", "day": 0},
    {"unique": "EastMallBooks", "name": "East Mall - Book Store", "day": 1},
    # --- named catnip / hides ---
    {"unique": "HomeCatnip", "name": "Home - Roof Catnip", "day": 0},
    {"unique": "GaneshCatnip", "name": "Main Street - Lucky Ganesh Rear Catnip", "day": 0},
    {"unique": "GhettoCatnip", "name": "Trainyard Area - Sign Catnip", "day": 1},
    {"unique": "IndustrialCatnip", "name": "Clinic Area - Roof Catnip", "day": 0},
    {"unique": "ToraCatnip", "name": "Tora Bora - Catnip in Water", "day": 0},
    {"unique": "WestMallShelfCatnip", "name": "West Mall - Shelf Catnip", "day": 1},
    {"unique": "WestMallDoghouseCatnip", "name": "West Mall - Doghouse Catnip", "day": 1},
    {"unique": "SewerPizza", "name": "Sewer - Pizza by the Pipe", "day": 0},
] + _map_locations() + _extra_scrounge_locations()

ERRAND_UNLOCKS = [
    {"unique": "GetPaycheck", "name": "Errand - Pick Up Paycheck", "day": 0},
    {"unique": "CashPaycheck", "name": "Errand - Cash Paycheck", "day": 0},
    {"unique": "GetMilk", "name": "Errand - Get Milk", "day": 0},
    {"unique": "VisitPriest", "name": "Errand - Confess Sins", "day": 1},
    {"unique": "GetSignatures", "name": "Errand - Petition"},  # any day; not a Tuesday key
    {"unique": "ReturnBook", "name": "Errand - Return Book", "day": 1},
    {"unique": "GetGary", "name": "Errand - Gary Autograph", "day": 1},
    {"unique": "VisitDad", "name": "Errand - Piss on Dad", "day": 2},
    {"unique": "Vote", "name": "Errand - Vote", "day": 2},
    {"unique": "GetTree", "name": "Errand - Get Xmas Tree", "day": 2},
    {"unique": "GetNapalm", "name": "Errand - Get Napalm", "day": 3},
    {"unique": "GetKrotchy", "name": "Errand - Get Krotchy", "day": 3},
    {"unique": "GetSteaks", "name": "Errand - Get Steaks", "day": 3},
    {"unique": "PayTicket", "name": "Errand - Pay Ticket", "day": 3},
    {"unique": "GetAlternator", "name": "Errand - Get Alternator", "day": 4},
    {"unique": "PickupPackage", "name": "Errand - Pick Up Package", "day": 4},
    {"unique": "GivePresent", "name": "Errand - Uncle Dave", "day": 4},
    {"unique": "VisitClinic", "name": "Errand - Clinic", "day": 4},
]

MONDAY_STARTER_ERRANDS = (
    "Errand - Pick Up Paycheck",
    "Errand - Cash Paycheck",
    "Errand - Get Milk",
)

# One of these is precollected for the YAML starting weekday. Petition is
# any-day and is not a day key, so it is never a starter.
STARTER_ERRANDS_BY_DAY = {
    0: MONDAY_STARTER_ERRANDS,
    1: (
        "Errand - Confess Sins",
        "Errand - Return Book",
        "Errand - Gary Autograph",
    ),
    2: (
        "Errand - Piss on Dad",
        "Errand - Vote",
        "Errand - Get Xmas Tree",
    ),
    3: (
        "Errand - Get Napalm",
        "Errand - Get Krotchy",
        "Errand - Get Steaks",
        "Errand - Pay Ticket",
    ),
    4: (
        "Errand - Get Alternator",
        "Errand - Pick Up Package",
        "Errand - Uncle Dave",
        "Errand - Clinic",
    ),
}

# Guns/melee that Random Weapon can hand you at the start of the week.
STARTING_WEAPONS = (
    "Shovel",
    "Pistol",
    "Shotgun",
    "Sawed-Off Shotgun",
    "Beta Shotgun",
    "Machine Gun",
    "Hunting Rifle",
    "Rocket Launcher",
    "Napalm Launcher",
    "Grenade Launcher",
    "Flamethrower",
    "Machete",
    "Scythe",
    "Chainsaw",
    "Cow Head",
    "Dynamite",
    "Grenades",
    "Molotovs",
    "Scissors",
    "Gas Can",
    "Sledgehammer",
    "Machine Pistol",
    "Submachine Gun",
    "Taser",
    "Baton",
    "Baseball Bat",
    "Hedge Clippers",
    "Dusters",
    "Bali",
    "Krotchy Grenade",
    "Box Launcher",
    "Cat Launcher",
)

# grant: UnrealScript inventory class, optional :amount, TRAP:Name, DAY:, AREA:, or ERRAND:
ITEMS = [
    {
        "name": e["name"],
        "count": 1,
        "classification": "progression",
        "grant": f"ERRAND:{e['unique']}",
    }
    for e in ERRAND_UNLOCKS
] + [
    {"name": "Tora Bora Access", "count": 0, "classification": "progression", "grant": "AREA:ToraBora"},
    {"name": "Cop Uniform", "count": 1, "classification": "progression", "grant": "Inventory.CopClothesInv"},
    {"name": "Bass Sniffer", "count": 1, "classification": "useful", "grant": "Inventory.RadarInv"},
    {"name": "Piranha Plug-in", "count": 1, "classification": "useful", "grant": "Inventory.GunRadarPlugInv"},
    {"name": "Largemouth Plug-in", "count": 1, "classification": "useful", "grant": "Inventory.CopRadarPlugInv"},
    {"name": "Chompy Cartridge", "count": 1, "classification": "useful", "grant": "Inventory.RadarTargetInv"},
    {"name": "Shovel", "count": 1, "classification": "useful", "grant": "Inventory.ShovelWeapon"},
    {"name": "Pistol", "count": 1, "classification": "useful", "grant": "Inventory.PistolWeapon"},
    {"name": "Shotgun", "count": 1, "classification": "useful", "grant": "Inventory.ShotGunWeapon"},
    {"name": "Sawed-Off Shotgun", "count": 1, "classification": "useful", "grant": "AWPStuff.SawnOffWeapon"},
    {"name": "Beta Shotgun", "count": 1, "classification": "useful", "grant": "EDStuff.BetaShotgunWeapon"},
    {"name": "Machine Gun", "count": 1, "classification": "useful", "grant": "Inventory.MachineGunWeapon"},
    {"name": "Hunting Rifle", "count": 1, "classification": "useful", "grant": "Inventory.RifleWeapon"},
    {"name": "Rocket Launcher", "count": 1, "classification": "useful", "grant": "Inventory.LauncherWeapon"},
    {"name": "Napalm Launcher", "count": 1, "classification": "useful", "grant": "Inventory.NapalmWeapon"},
    {"name": "Grenade Launcher", "count": 1, "classification": "useful", "grant": "EDStuff.GrenadeLauncherWeapon"},
    {"name": "Flamethrower", "count": 1, "classification": "useful", "grant": "AWPStuff.FlameWeapon"},
    {"name": "WMD", "count": 1, "classification": "useful", "grant": "Inventory.PlagueWeapon"},
    {"name": "Mini-Nuke", "count": 1, "classification": "useful", "grant": "AWPStuff.NukeWeapon"},
    {"name": "Machete", "count": 1, "classification": "useful", "grant": "AWInventory.MacheteWeapon"},
    {"name": "Scythe", "count": 1, "classification": "useful", "grant": "AWInventory.ScytheWeapon"},
    {"name": "Chainsaw", "count": 1, "classification": "useful", "grant": "AWPStuff.ChainsawWeapon"},
    {"name": "Cow Head", "count": 1, "classification": "useful", "grant": "Inventory.CowHeadWeapon"},
    {"name": "Dynamite", "count": 1, "classification": "useful", "grant": "EDStuff.DynamiteWeapon"},
    {"name": "Grenades", "count": 1, "classification": "useful", "grant": "Inventory.GrenadeWeapon"},
    {"name": "Molotovs", "count": 1, "classification": "useful", "grant": "Inventory.MolotovWeapon"},
    {"name": "Scissors", "count": 1, "classification": "useful", "grant": "Inventory.ScissorsWeapon"},
    {"name": "Gas Can", "count": 1, "classification": "useful", "grant": "Inventory.GasCanWeapon"},
    {"name": "Sledgehammer", "count": 1, "classification": "useful", "grant": "AWInventory.SledgeWeapon"},
    {"name": "Machine Pistol", "count": 1, "classification": "useful", "grant": "EDStuff.GSelectWeapon"},
    {"name": "Submachine Gun", "count": 1, "classification": "useful", "grant": "EDStuff.MP5Weapon"},
    {"name": "Taser", "count": 1, "classification": "useful", "grant": "Inventory.ShockerWeapon"},
    {"name": "Baton", "count": 1, "classification": "useful", "grant": "Inventory.BatonWeapon"},
    {"name": "Baseball Bat", "count": 1, "classification": "useful", "grant": "AWPStuff.BaseballBatWeapon"},
    {"name": "Hedge Clippers", "count": 1, "classification": "useful", "grant": "EDStuff.ShearsWeapon"},
    {"name": "SiC Armor", "count": 1, "classification": "useful", "grant": "Inventory.BodyArmorInv"},
    {"name": "Body Armor", "count": 2, "classification": "useful", "grant": "Inventory.BodyArmorInv"},
    {"name": "Health Pipe", "count": 10, "classification": "filler", "grant": "Inventory.CrackInv:1"},
    {"name": "Donut", "count": 8, "classification": "filler", "grant": "Inventory.DonutInv:1"},
    {"name": "Pizza", "count": 8, "classification": "filler", "grant": "Inventory.PizzaInv:1"},
    {"name": "Fast Food", "count": 8, "classification": "filler", "grant": "Inventory.FastFoodInv:1"},
    {"name": "Catnip", "count": 6, "classification": "filler", "grant": "Inventory.CatnipInv:1"},
    {"name": "Medkit", "count": 10, "classification": "filler", "grant": "Inventory.MedKitInv:1"},
    {"name": "$5", "count": 6, "classification": "filler", "grant": "Inventory.MoneyInv:5"},
    {"name": "$20", "count": 4, "classification": "filler", "grant": "Inventory.MoneyInv:20"},
    {"name": "$100", "count": 2, "classification": "filler", "grant": "Inventory.MoneyInv:100"},
    {"name": "Spare Ammo", "count": 12, "classification": "filler", "grant": "OWNEDAMMO:40"},  # amount unused; game grants 30% MaxAmmo or +30 melee dur
    {"name": "Weapon Repair Kit", "count": 8, "classification": "filler", "grant": "Archipelago.APRepairInv:1"},
    {"name": "Cat Rain Trap", "count": 2, "classification": "trap", "grant": "TRAP:CatRain"},
    {"name": "Wanted Trap", "count": 2, "classification": "trap", "grant": "TRAP:Wanted"},
    {"name": "Drop Gun Trap", "count": 2, "classification": "trap", "grant": "TRAP:DropGun"},
    {"name": "Protestor Trap", "count": 2, "classification": "trap", "grant": "TRAP:Protestors"},
    {"name": "Piss Trap", "count": 2, "classification": "trap", "grant": "TRAP:Piss"},
    {"name": "Gimp Trap", "count": 2, "classification": "trap", "grant": "TRAP:Gimp"},
    {"name": "Warp Point - Greenbelt", "count": 1, "classification": "progression", "grant": "WARP:GREENBELT1"},
    {"name": "Warp Point - Napalm Factory Exterior", "count": 1, "classification": "progression", "grant": "WARP:GREENBELT2"},
    {"name": "Warp Point - Main Street", "count": 1, "classification": "progression", "grant": "WARP:SUBURBS-1"},
    {"name": "Warp Point - Trainyard", "count": 1, "classification": "progression", "grant": "WARP:HIGHLANDS"},
    {"name": "Warp Point - Office Complex", "count": 1, "classification": "progression", "grant": "WARP:RWSBLOCK"},
    {"name": "Warp Point - Ghetto", "count": 1, "classification": "progression", "grant": "WARP:SUBURBS-2"},
    {"name": "Warp Point - East Suburbs", "count": 1, "classification": "progression", "grant": "WARP:SUBURBS-4"},
    {"name": "Warp Point - Tora Bora", "count": 1, "classification": "progression", "grant": "WARP:TORABORA"},
    {"name": "Hint Flare", "count": 10, "classification": "filler", "grant": "Archipelago.APHintFlareInv:1"},
    {"name": "Suicide Bomber Trap", "count": 2, "classification": "trap", "grant": "TRAP:SuicideBomber"},
    {"name": "Dusters", "count": 1, "classification": "useful", "grant": "AWPStuff.DustersWeapon"},
    {"name": "Bali", "count": 1, "classification": "useful", "grant": "EDStuff.BaliWeapon"},
    {"name": "Water Bottle", "count": 8, "classification": "filler", "grant": "Archipelago.APWaterBottleInv:1"},
    {"name": "Krotchy Grenade", "count": 1, "classification": "useful", "grant": "Inventory.MrDKNadeWeapon"},
    {"name": "Box Launcher", "count": 1, "classification": "useful", "grant": "Inventory.BoxLauncherWeapon"},
    {"name": "Cat Launcher", "count": 1, "classification": "useful", "grant": "AWPStuff.CatLauncherWeapon"},
]

ERRAND_UNIQUES = [
    "GetPaycheck", "CashPaycheck", "GetMilk", "VisitPriest", "GetSignatures",
    "ReturnBook", "GetGary", "VisitDad", "Vote", "GetTree", "PickupLaundry",
    "GetNapalm", "GetKrotchy", "GetSteaks", "PayTicket", "GetAlternator",
    "PickupPackage", "GivePresent", "VisitClinic",
]

# Story maps that are one-way until Time Warp 6-9 and 0 unlock after you leave them.
# Hunt day is still pinned to the weekday they open. Checks are not filler-only;
# you can warp back for leftover tokens.
ONE_SHOT_MAPS = ("LIBRARY1", "LIBRARY2", "BREWERY", "NAPALM", "PARCELCENTER")
ONE_SHOT_NAMED = (
    "NapalmRocket",
    "NapalmFlame",
    "LibrarySledge",
)
ONE_SHOT_KEEP_ANY = (
    "ReturnBook",
    "GetNapalm",
    "BreweryGimp",
    "BreweryRestore",
)


def is_oneshot_filler_location(unique: str) -> bool:
    return False


# Errands that do not block sleeping (none — vanilla to-do list is required)
SLEEP_SKIP_UNIQUES = set()

# Calendar weekday each errand belongs to (0=Mon). Placement uses the seed's
# shuffled day_order: leftover starting-day errands sit later in that order,
# and later days keep lookbehind plus same-day.
# Errand tools (paycheck, book, clipboard, citation, gift) are bundled with
# the matching Errand - * item, not shuffled on their own.
ITEM_EARLIEST_DAY = {
    e["name"]: e["day"] for e in ERRAND_UNLOCKS if e.get("day") is not None
}


def errand_item_name(unique: str) -> str:
    for e in ERRAND_UNLOCKS:
        if e["unique"] == unique:
            return e["name"]
    return ""


def errand_unique_from_item(name: str) -> str:
    for e in ERRAND_UNLOCKS:
        if e["name"] == name:
            return e["unique"]
    return ""


def errand_item_names_for_day(day: int) -> list:
    return [e["name"] for e in ERRAND_UNLOCKS if e.get("day") == day]

TORA_UNIQUES = (
    "Enter_TORABORA",
    "ToraMachete", "ToraWMD", "ToraNuke", "ToraRifle", "ToraCowHead",
    "ToraRadar", "ToraCatnip",
)

FILLER_NAMES = {
    "$5", "$20", "$100", "Medkit", "Spare Ammo", "Catnip",
    "Health Pipe", "Donut", "Pizza", "Fast Food",
    "Weapon Repair Kit", "Hint Flare", "Water Bottle",
}

# Extra filler (token leftovers, trap replacements) is weighted, not all $20.
FILLER_WEIGHTS = (
    ("Spare Ammo", 4),
    ("Medkit", 3),
    ("Health Pipe", 3),
    ("Donut", 2),
    ("Pizza", 2),
    ("Fast Food", 2),
    ("Catnip", 2),
    ("$5", 3),
    ("$20", 2),
    ("$100", 1),
    ("Weapon Repair Kit", 2),
    ("Hint Flare", 3),
    ("Water Bottle", 2),
)


def _enabled(loc: dict) -> bool:
    return True


def location_name_to_id():
    return {loc["name"]: BASE_ID + i for i, loc in enumerate(LOCATIONS, start=1)}


def location_unique_to_name():
    return {loc["unique"]: loc["name"] for loc in LOCATIONS}


def item_name_to_id():
    return {item["name"]: BASE_ID + 1000 + i for i, item in enumerate(ITEMS, start=1)}


def item_name_to_grant():
    return {item["name"]: item["grant"] for item in ITEMS}


def enabled_locations():
    return [loc for loc in LOCATIONS if _enabled(loc)]


def world_locations(
    vending: bool = True,
    crackola: bool = True,
    atm: bool = True,
    scrounge_uniques=None,
    vending_counts=None,
):
    out = []
    for loc in LOCATIONS:
        if loc["unique"] == "Enter_INTRO" or loc.get("map") in UNPLAYABLE_MAPS:
            continue
        if loc["unique"].startswith("SC_INTRO_"):
            continue
        if loc["unique"] in BLOCKED_SCROUNGE_UNIQUES:
            continue
        if "CrackColaPickup" in loc["unique"]:
            continue
        if loc["unique"] in RETIRED_LOCATIONS:
            continue
        opt = loc.get("option")
        if opt == "vending" and not vending:
            continue
        if opt == "crackola" and not crackola:
            continue
        if opt == "atm" and not atm:
            continue
        if loc.get("kind") == "scrounge" and scrounge_uniques is not None:
            if loc["unique"] not in scrounge_uniques:
                continue
        if vending_counts is not None and loc["unique"].startswith("VBUY_"):
            if not vbuy_slot_enabled(loc["unique"], vending_counts):
                continue
        out.append(loc)
    return out


# intro.fuk is the unplayable opening cinematic. No enter check, no tokens.
UNPLAYABLE_MAPS = frozenset({"INTRO"})

# Shop / event locations and former named-cache uniques. Stay in LOCATIONS so
# later IDs do not shift; world_locations drops them from new seeds.
RETIRED_NAMED_CACHE_UNIQUES = frozenset({
    "HomeShovel", "HomeChainsaw", "HomeCatnip", "HomeChamp",
    "MainStreetRocket", "GaneshCatnip",
    "MainStreetRifle", "MainStreetDynamite", "GreenbeltShotgun",
    "GreenbeltRifle", "GreenbeltGL", "Greenbelt2Chainsaw",
    "RWSRocket", "RWSShotgun",
    "IndustrialShotgun", "ClinicRocket", "ClinicFlame", "ClinicDynamite",
    "IndustrialCatnip", "IndustrialDynamite",
    "TrainyardBeta", "TrainyardRifle", "TrainyardRocket", "TrainyardChainsaw",
    "TrainyardSawedOff", "TrainyardLargemouth", "GhettoChompy", "GhettoCatnip",
    "SuburbsSawedOff", "GhettoRifle", "GhettoShotgun",
    "SuburbsChainsaw", "SuburbsEastSawedOff",
    "PoliceArmory", "PoliceCopUniform", "PoliceRadar",
    "EastMallATFBox",
    "WestMallSawedOff", "WestMallShelfCatnip", "WestMallDoghouseCatnip",
    "CemeterySawedOff", "CemeteryScythe", "ChurchRocket",
    "ForestRifle", "ForestSawedOff", "ForestFlame",
    "NapalmRocket", "NapalmFlame",
    "ParcelRocket", "ParcelRifle",
    "MeatCowHead", "MeatSawedOff",
    "CompoundChainsaw", "JunkyardSledge", "LibrarySledge",
    "EstatesScythe", "EstatesPiranha", "EstatesFlame",
    "SewerSiC", "SewerPipe", "SewerWardrobe", "SewerFlame", "SewerShotgun",
    "SewerPizza",
    "ToraMachete", "ToraWMD", "ToraNuke", "ToraRifle", "ToraCowHead",
    "ToraCatnip", "ToraRadar",
})

RETIRED_LOCATIONS = frozenset({
    "GaneshPipe",
    "EastMallP3",
    "BankBookcase",
    "BankOrchestra",
    "EastMallATFBuy",
    "MainStreetCats",
    "TrainyardApparel",
    "EastMallBooks",
    "Enter_GREENBELT",
    "Enter_LIBRARY",
    "COLA_EASTMALL_02",
}) | RETIRED_NAMED_CACHE_UNIQUES

# Overlay place-names onto live catalog/ATM/Crackola/extra SC_ uniques.
# Retired named-cache rows keep their hardcoded names so extra piles can
# take the user-authored HINT_LABELS without colliding in location_name_to_id.
apply_hint_names(LOCATIONS, skip_uniques=RETIRED_LOCATIONS)
_live_names = {
    loc["name"] for loc in LOCATIONS if loc["unique"] not in RETIRED_LOCATIONS
}
for _loc in LOCATIONS:
    if _loc["unique"] in RETIRED_LOCATIONS and _loc["name"] in _live_names:
        _loc["name"] = f"{_loc['name']} ({_loc['unique']})"
del _live_names, _loc

_seen_loc_names = {}
for _loc in LOCATIONS:
    _n = _loc["name"]
    _u = _loc["unique"]
    if _n in _seen_loc_names:
        raise RuntimeError(
            f"duplicate location name {_n!r} ({_seen_loc_names[_n]} and {_u})"
        )
    _seen_loc_names[_n] = _u
del _seen_loc_names, _loc, _n, _u

# Current-catalog uniques that must never be chosen. Coords below are the
# durable identity if the catalog is regenerated (suffix numbers can shift).
BLOCKED_SCROUNGE_UNIQUES = frozenset({
    "SC_SUBURBS-3_MedKitPickup_15",  # Home, past a load zone
    "SC_SUBURBS-3_KevlarPickup_06",  # Home, past a load zone
    "SC_SUBURBS-3_GrenadePickup_13",  # Home, same load-zone pocket as Kevlar 6
    "SC_SUBURBS-3_GrenadePickup_14",  # Home, past a load zone
    "SC_SUBURBS-3_PistolPickup_08",  # Home, same load-zone pocket as Kevlar 6
    "SC_SUBURBS-3_PistolPickup_09",  # Home, same load-zone pocket as Kevlar 6
    "SC_SUBURBS-2_GrenadePickup_08",  # Ghetto, sky pile (Z=0)
    "SC_SUBURBS-2_GrenadePickup_09",
    "SC_SUBURBS-2_GrenadePickup_10",
    "SC_SUBURBS-2_ShotgunAmmoPickup_09",  # Ghetto, sky (Z=0)
    "SC_SUBURBS-2_GSelectAmmoPickup_04",  # Ghetto, derailed train bridge (cheat-only)
    "SC_SUBURBS-2_CatnipPickup_03",
    "SC_SUBURBS-2_CrackPickup_02",
    "SC_SUBURBS-2_LauncherAmmoPickup_02",
    "SC_SUBURBS-2_GaryHeadPickup_01",
    "SC_GREENBELT1_DonutPickup_01",
    "SC_GREENBELT1_MedKitPickup_12",
    "SC_GREENBELT1_NewspaperPickup_01",
    "SC_GREENBELT1_MoneyPickup_07",
    "SC_GREENBELT1_PistolPickup_01",
    "SC_GREENBELT1_RadarPickup_02",
    "SC_GREENBELT2_AxePickup_01",
    "SC_GREENBELT2_SledgePickup_02",
    "SC_GREENBELT2_MedKitPickup_06",
    "SC_HIGHLANDS_CrackPickup_01",
    "SC_HIGHLANDS_GaryHeadPickup_01",
    "SC_HIGHLANDS_PistolPickup_01",
    "SC_HIGHLANDS_ShotGunPickup_01",
    "SC_HIGHLANDS_GasCanPickup_03",  # Trainyard, unreachable in normal play
    "SC_HIGHLANDS_SledgePickup_02",  # Trainyard, unreachable in normal play
    "SC_SLAUGHTERHOUSE_CatnipPickup_01",
    "SC_SLAUGHTERHOUSE_FastFoodPickup_01",
    "SC_SLAUGHTERHOUSE_FastFoodPickup_02",
    "SC_SUBURBS-4_GaryHeadPickup_01",
    "SC_TORABORA_GaryHeadPickup_01",
    "SC_TORABORA_MedKitPickup_01",
    "SC_TORABORA_ShovelPickup_01",
    "ToraWMD",  # named plague crate at Z=0
    "SC_UNDERHUB_MedKitPickup_05",
    "SC_UNDERHUB_MedKitPickup_06",
    # Crackola cans are xPatch leftovers; they do not spawn as world piles.
    "SC_ESTATES_CrackColaPickup_01",
    "SC_ESTATES_CrackColaPickup_02",
    "SC_ESTATES_CrackColaPickup_03",
    "SC_POLICE_CrackColaPickup_01",
    "SC_BREWERY_CrackColaPickup_01",
    "SC_POLICE_CatnipPickup_01",  # Police Station, inside a cardboard box
    # Office Complex unbreakable box (MP5 Ammo 3 cluster).
    "SC_RWSBLOCK_MP5AmmoPickup_01",
    "SC_RWSBLOCK_MP5AmmoPickup_02",
    "SC_RWSBLOCK_MP5AmmoPickup_03",
    "SC_RWSBLOCK_MP5AmmoPickup_04",
    "SC_RWSBLOCK_MP5AmmoPickup_05",
    "SC_RWSBLOCK_GSelectAmmoPickup_01",
    "SC_RWSBLOCK_GSelectAmmoPickup_02",
    "SC_RWSBLOCK_GSelectAmmoPickup_03",
    "SC_RWSBLOCK_GSelectAmmoPickup_04",
    "SC_RWSBLOCK_GSelectAmmoPickup_05",
    "SC_RWSBLOCK_BoxLauncherPickup_01",
    # Editor pass: outside the map, past a load zone, or clipped out of reach.
    "SC_SUBURBS-2_RadarTargetPickup_02",
    "SC_GREENBELT1_MedKitPickup_02",
    "SC_GREENBELT1_MedKitPickup_04",
    "SC_GREENBELT1_MedKitPickup_05",
    "SC_GREENBELT1_MedKitPickup_06",
    "SC_SUBURBS-3_RadarPickup_03",
    "SC_SUBURBS-3_MedKitPickup_14",
    "SC_RWSBLOCK_GSelectAmmoPickup_06",
    "SC_HIGHLANDS_RadarPickup_03",
    "SC_HIGHLANDS_MoneyPickup_28",
    "SC_HIGHLANDS_CatnipPickup_04",
    "SC_HIGHLANDS_ChainsawPickup_01",
    "SC_HIGHLANDS_CopRadarPlugPickup_02",
    "SC_HIGHLANDS_DogTreatBoxPickup_02",
    "SC_HIGHLANDS_FastFoodPickup_01",
    "SC_HIGHLANDS_FastFoodPickup_02",
    "SC_HIGHLANDS_FastFoodPickup_03",
    "SC_HIGHLANDS_FastFoodPickup_04",
    "SC_HIGHLANDS_GasCanPickup_04",
    "SC_HIGHLANDS_GunRadarPlugPickup_01",
    "SC_HIGHLANDS_KevlarPickup_03",
    "SC_HIGHLANDS_ScissorsPickup_01",
    "SC_INDUSTRY_BodyArmorPickup_01",
    "SC_INDUSTRY_GrenadePickup_06",
    "SC_INDUSTRY_GrenadePickup_07",
    "SC_INDUSTRY_LauncherAmmoPickup_08",
    "SC_INDUSTRY_ScissorsPickup_03",
    "SC_INDUSTRY2_CatnipPickup_02",
    "SC_INDUSTRY2_CatnipPickup_03",
    "SC_INDUSTRY2_MedKitPickup_01",
    "SC_INDUSTRY2_MedKitPickup_02",
    "SC_SUBURBS-4_CrackPickup_04",
    "SC_SUBURBS-4_PistolPickup_03",
    "SC_SUBURBS-4_PistolPickup_04",
    "SC_SUBURBS-4_PistolPickup_05",
    "SC_SUBURBS-4_ScissorsPickup_03",
    "SC_TORABORA_CatnipPickup_01",
    "SC_TORABORA_CrackPickup_02",
    "SC_TORABORA_PlagueAmmoPickup_01",
})

# Unreachable catalog piles. Keep in sync with scan_pickups.BLOCKED_SPOTS.
BLOCKED_SCROUNGE_SPOTS = (
    ("RWSBLOCK", "GSelectAmmoPickup", -4261.4, -4188.6, -150.1, 120.0),
    ("RWSBLOCK", "PistolPickup", -8315.0, -2401.7, -768.2, 120.0),
    # Office Complex unbreakable box around MP5 Ammo 3. Radius 80 covers MP5 1–5,
    # Glock Ammo 1–5, and BoxLauncher; next catalog pile is ~756 UU away.
    ("RWSBLOCK", "MP5AmmoPickup", -7576.1, 1960.2, -386.5, 80.0),
    ("RWSBLOCK", "GSelectAmmoPickup", -7576.1, 1960.2, -386.5, 80.0),
    ("RWSBLOCK", "BoxLauncherPickup", -7576.1, 1960.2, -386.5, 80.0),
    # Home Medkit 15: past a load zone. Radius 32 leaves Medkit 14, blocked below.
    ("SUBURBS-3", "MedKitPickup", 5874.6, -2717.8, -4782.0, 32.0),
    # Home Medkit 14: same load zone, 43 UU from Medkit 15.
    ("SUBURBS-3", "MedKitPickup", 5835.8, -2698.2, -4782.0, 20.0),
    ("SUBURBS-3", "KevlarPickup", 10668.0, -12391.0, -6154.0, 80.0),
    # Grenade 13 is ~29 UU from 14; radius 40 covers both. Next grenade is thousands away.
    ("SUBURBS-3", "GrenadePickup", 10622.0, -12459.0, -6159.0, 40.0),
    # Home Pistol 8/9: same load-zone pocket as Kevlar 6. Radius 40 covers both.
    ("SUBURBS-3", "PistolPickup", 10765.0, -12290.0, -6166.0, 40.0),
    ("SUBURBS-2", "GrenadePickup", -5228.1, -5115.0, 0.0, 50.0),
    ("SUBURBS-2", "ShotgunAmmoPickup", 2400.6, 2401.3, 0.0, 50.0),
    # Ghetto Glock Ammo 4: derailed train bridge, cheat-only. Radius 20 so
    # MP5 Ammo 3 (~28 UU away) stays.
    ("SUBURBS-2", "GSelectAmmoPickup", -3536.9, -2018.9, -4662.2, 20.0),
    ("SUBURBS-2", "CatnipPickup", -5263.0, -5122.0, 0.0, 40.0),
    ("SUBURBS-2", "CrackPickup", -5238.3, -5109.0, 0.0, 40.0),
    ("SUBURBS-2", "LauncherAmmoPickup", -5210.0, -5108.0, 0.0, 40.0),
    ("SUBURBS-2", "GaryHeadPickup", -11570.0, -5094.0, 0.0, 40.0),
    ("GREENBELT1", "DonutPickup", -238.0, -1226.0, 0.0, 40.0),
    ("GREENBELT1", "MedKitPickup", -210.0, -1225.0, 0.0, 40.0),
    ("GREENBELT1", "NewspaperPickup", -248.0, -1225.0, 0.0, 40.0),
    ("GREENBELT1", "MoneyPickup", -2514.0, -1069.7, 0.0, 40.0),
    ("GREENBELT1", "PistolPickup", -3071.0, -1171.0, 0.0, 40.0),
    ("GREENBELT1", "RadarPickup", -3215.0, -1202.0, 0.0, 40.0),
    ("GREENBELT2", "AxePickup", 3144.0, -1185.8, 0.0, 40.0),
    ("GREENBELT2", "SledgePickup", 3143.9, -1186.8, 0.0, 40.0),
    ("GREENBELT2", "MedKitPickup", 1056.0, -1311.0, 0.0, 40.0),
    ("HIGHLANDS", "CrackPickup", -11403.3, -989.1, 0.0, 40.0),
    ("HIGHLANDS", "GaryHeadPickup", -6972.0, -654.0, 0.0, 40.0),
    ("HIGHLANDS", "PistolPickup", -5541.4, -1011.7, 0.0, 40.0),
    ("HIGHLANDS", "ShotGunPickup", -5526.3, -969.7, 0.0, 40.0),
    # Trainyard Gas Can 3 and 4: unreachable, 45 UU apart.
    ("HIGHLANDS", "GasCanPickup", 1646.0, -10207.0, -1004.0, 20.0),
    ("HIGHLANDS", "GasCanPickup", 1683.0, -10182.0, -1004.0, 20.0),
    ("HIGHLANDS", "SledgePickup", 1687.0, -9783.7, -972.0, 40.0),
    ("SLAUGHTERHOUSE", "CatnipPickup", -3342.0, -5186.0, 0.0, 40.0),
    ("SLAUGHTERHOUSE", "FastFoodPickup", -1494.0, -5074.8, 0.0, 50.0),
    ("SUBURBS-4", "GaryHeadPickup", -4960.0, -5191.0, 0.0, 40.0),
    ("TORABORA", "GaryHeadPickup", 3227.0, 340.0, 0.0, 40.0),
    ("TORABORA", "MedKitPickup", -19328.0, -1910.0, 0.0, 40.0),
    ("TORABORA", "ShovelPickup", -1142.0, -568.0, -5.0, 40.0),
    ("TORABORA", "PlaguePickup", -3867.0, -564.2, 0.0, 40.0),
    ("UNDERHUB", "MedKitPickup", -2218.0, -398.0, 0.0, 50.0),
    ("ESTATES", "CrackColaPickup", -5754.0, -514.0, 0.0, 40.0),
    ("POLICE", "CrackColaPickup", -4616.3, -10559.0, -5209.0, 40.0),
    # Police Station Catnip 1: inside a cardboard box. Tight so Catnip 2 stays.
    ("POLICE", "CatnipPickup", -5415.0, -13112.0, -5018.0, 40.0),
    ("BREWERY", "CrackColaPickup", -1819.3, -204.0, 0.0, 40.0),
    # Editor pass: outside the map, past a load zone, or clipped out of reach.
    # Tight radii are the piles that sit near a check that stays.
    ("SUBURBS-2", "RadarTargetPickup", -248.0, -7408.0, -5438.0, 40.0),
    ("GREENBELT1", "MedKitPickup", -3665.0, -994.0, -1403.0, 40.0),
    ("GREENBELT1", "MedKitPickup", -3579.0, -1057.0, -1403.0, 40.0),
    ("GREENBELT1", "MedKitPickup", -3577.5, -1013.9, -1403.0, 40.0),
    ("GREENBELT1", "MedKitPickup", -2904.0, 444.0, -966.0, 40.0),
    ("SUBURBS-3", "RadarPickup", 3840.0, -12416.0, -4480.0, 40.0),
    ("RWSBLOCK", "GSelectAmmoPickup", 1210.2, 3919.5, -955.3, 40.0),
    ("HIGHLANDS", "RadarPickup", 1647.0, -9705.0, -1030.0, 40.0),
    ("HIGHLANDS", "MoneyPickup", 2076.0, -9496.0, -848.0, 40.0),
    ("HIGHLANDS", "CatnipPickup", 1621.0, -9729.0, -1030.0, 40.0),
    ("HIGHLANDS", "ChainsawPickup", 1612.2, -10141.5, -1023.0, 40.0),
    ("HIGHLANDS", "CopRadarPlugPickup", 2000.0, -9509.0, -850.0, 40.0),
    ("HIGHLANDS", "DogTreatBoxPickup", 1627.0, -9753.0, -1009.0, 40.0),
    ("HIGHLANDS", "FastFoodPickup", 1846.0, -9715.0, -1017.0, 40.0),
    ("HIGHLANDS", "FastFoodPickup", 1871.2, -9679.4, -1017.0, 40.0),
    ("HIGHLANDS", "FastFoodPickup", 1880.5, -9716.9, -1024.8, 40.0),
    ("HIGHLANDS", "FastFoodPickup", 1920.8, -9687.4, -1017.0, 40.0),
    ("HIGHLANDS", "GunRadarPlugPickup", 1955.0, -9511.0, -850.0, 40.0),
    ("HIGHLANDS", "KevlarPickup", 1741.0, -10306.0, -825.0, 40.0),
    ("HIGHLANDS", "ScissorsPickup", 2429.0, -9608.0, -1027.0, 40.0),
    ("INDUSTRY", "BodyArmorPickup", 2979.0, -2222.0, -818.0, 40.0),
    ("INDUSTRY", "GrenadePickup", 5867.6, -1141.0, -1415.3, 40.0),
    ("INDUSTRY", "GrenadePickup", 5907.6, -1166.0, -1417.8, 40.0),
    ("INDUSTRY", "LauncherAmmoPickup", 5854.0, -1106.0, -1404.0, 40.0),
    ("INDUSTRY", "ScissorsPickup", 5847.1, -1188.0, -1424.0, 40.0),
    # Industrial catnip 2 is 36 UU from catnip 1, which stays.
    ("INDUSTRY2", "CatnipPickup", 798.7, -9753.3, -832.0, 20.0),
    ("INDUSTRY2", "CatnipPickup", 800.0, -9744.0, -832.0, 20.0),
    ("INDUSTRY2", "MedKitPickup", 2726.7, -6136.3, -962.0, 40.0),
    ("INDUSTRY2", "MedKitPickup", 2761.2, -6108.6, -962.0, 40.0),
    ("SUBURBS-4", "CrackPickup", -1760.0, -10917.0, -5398.0, 40.0),
    ("SUBURBS-4", "PistolPickup", -2123.5, -10168.0, -5403.8, 40.0),
    ("SUBURBS-4", "PistolPickup", -2123.5, -10115.0, -5403.8, 40.0),
    ("SUBURBS-4", "PistolPickup", -2121.5, -10294.0, -5403.8, 40.0),
    ("SUBURBS-4", "ScissorsPickup", -1327.0, -9874.0, -5411.0, 40.0),
    ("TORABORA", "CatnipPickup", 688.0, -12204.0, -2108.0, 40.0),
    ("TORABORA", "CrackPickup", 708.0, -12252.0, -2108.0, 40.0),
    ("TORABORA", "PlagueAmmoPickup", 728.0, -1472.0, -84.0, 40.0),
)


def _dist3(a, b) -> float:
    return math.sqrt((a[0] - b[0]) ** 2 + (a[1] - b[1]) ** 2 + (a[2] - b[2]) ** 2)


def is_blocked_scrounge(map_key, cls, x, y, z):
    for m, c, bx, by, bz, r in BLOCKED_SCROUNGE_SPOTS:
        if m != map_key or c != cls:
            continue
        if _dist3((x, y, z), (bx, by, bz)) <= r:
            return True
    return False


BLOCKED_SCROUNGE_UNIQUES = BLOCKED_SCROUNGE_UNIQUES | frozenset(
    e["unique"] for e in EXTRA_SCROUNGE_CATALOG
    if e.get("cls") == "CrackColaPickup"
    or is_blocked_scrounge(e["map"], e["cls"], e["x"], e["y"], e["z"])
)


TOKEN_UNIQUE_TO_MAP = {}
for _e in SCROUNGE_CATALOG:
    TOKEN_UNIQUE_TO_MAP[_e["unique"]] = _e["map"]
for _e in EXTRA_SCROUNGE_CATALOG:
    TOKEN_UNIQUE_TO_MAP[_e["unique"]] = _e["map"]

# Earliest weekday a map can be entered (0=Monday). Tora Bora is physically
# open from Monday; hunt day is assigned separately and biased later.
def map_min_day(key: str) -> int:
    for m in MAPS:
        if m["key"] == key:
            return int(m.get("day") or 0)
    return 0


def _weighted_choice(rng, items, weights):
    total = float(sum(weights))
    x = rng.random() * total
    acc = 0.0
    pick = items[-1]
    for item, w in zip(items, weights):
        acc += w
        if x <= acc:
            pick = item
            break
    return pick


def choose_day_order(rng, start_day: int = 0) -> list:
    """Permutation of Mon–Fri with the YAML starting weekday first."""
    if start_day < 0 or start_day > 4:
        start_day = 0
    rest = [d for d in range(5) if d != start_day]
    rng.shuffle(rest)
    return [start_day] + rest


def normalize_day_order(day_order, start_day: int = 0) -> list:
    order = [int(d) for d in (day_order or [])]
    if len(order) == 5 and sorted(order) == [0, 1, 2, 3, 4]:
        return order
    if start_day < 0 or start_day > 4:
        start_day = 0
    return [start_day] + [d for d in range(5) if d != start_day]


def errand_item_flow_ok(item_day: int, loc_day: int, day_order) -> bool:
    """Where an errand item may sit along the seed's shuffled weekday order.

    Remaining starting-day errands go later in that order so the starting
    weekday's checks hold the next day's errands, not leftover chores from
    the same calendar day. Later days keep lookbehind plus same-day, so a
    Monday start can progress Monday → Thursday → Tuesday → Friday →
    Wednesday instead of always Monday then Tuesday.
    """
    order = normalize_day_order(day_order)
    flow = {d: i for i, d in enumerate(order)}
    item_i = flow.get(int(item_day), int(item_day))
    loc_i = flow.get(int(loc_day), int(loc_day))
    if item_i <= 0:
        return loc_i >= 1
    return item_i - 1 <= loc_i <= item_i


def choose_map_days(rng, start_day: int = 0, day_order=None) -> dict:
    """Assign each playable map to exactly one weekday.

    One-shot maps (Library, burning library, Brewery, Napalm, Parcel Center)
    always hunt on the calendar day they open. Other maps follow `day_order`
    (start day, then a random permutation). A map never hunts before
    MAPS[].day, so Monday-last seeds do not dump Napalm or Parcel Center
    onto Monday. The starting weekday gets 2-4 leftover maps it can enter.
    Intermediate flow days randomly take some of the maps they can enter.
    Remainders go to the last flow day that can actually enter the map.
    """
    if start_day < 0 or start_day > 4:
        start_day = 0
    if day_order:
        order = [int(d) for d in day_order]
    else:
        order = choose_day_order(rng, start_day)
    if len(order) != 5 or sorted(order) != [0, 1, 2, 3, 4]:
        order = choose_day_order(rng, start_day)

    maps = [m["key"] for m in MAPS if m["key"] not in UNPLAYABLE_MAPS]
    assigned = {}
    remaining = list(maps)

    for k in ONE_SHOT_MAPS:
        if k in remaining:
            assigned[k] = map_min_day(k)
            remaining.remove(k)

    if "TORABORA" in remaining:
        assigned["TORABORA"] = _weighted_choice(rng, order, [1, 2, 4, 7, 7])
        remaining.remove("TORABORA")

    def take(day, n):
        pool = [k for k in remaining if map_min_day(k) <= day]
        rng.shuffle(pool)
        n = max(0, min(int(n), len(pool)))
        for k in pool[:n]:
            assigned[k] = day
            remaining.remove(k)

    start = order[0]
    start_pool = [k for k in remaining if map_min_day(k) <= start]
    if start_pool:
        hi = min(4, len(start_pool))
        lo = min(2, hi)
        take(start, rng.randint(lo, hi))

    for d in order[1:-1]:
        pool = [k for k in remaining if map_min_day(k) <= d]
        if pool:
            take(d, rng.randint(0, len(pool)))

    last = order[-1]
    for k in list(remaining):
        eligible = [d for d in order if map_min_day(k) <= d]
        if last in eligible:
            d = last
        elif eligible:
            d = eligible[-1]
        else:
            d = map_min_day(k)
        assigned[k] = d
        remaining.remove(k)
    return assigned


# Piles that stay in the catalog, but only when this map's hunt day can
# actually reach them. 0=Monday ... 4=Friday. A closed day is skipped at
# choose time so another pile on that map fills the token cap.
# West Mall employees-only (Toyz backrooms and the loading dock where the
# Krotchy doll sits): the entrance blockers are up Tuesday and Wednesday,
# and that doorway is only clear on Thursday for Get Krotchy.
# West Mall secret upper platform (Shears, Grenade Launcher): the climb is
# only reasonable on Friday, so those two stay out of earlier hunt days.
# Napalm Factory Exterior, inside the factory gate: Friday the factory is
# gone and the gate is locked. Thursday, before Get Napalm, it is open.
HUNT_CLOSED_DAYS = {
    "SC_WESTMALL_AxePickup_01": frozenset({1, 2, 4}),
    "SC_WESTMALL_CrackPickup_01": frozenset({1, 2, 4}),
    "SC_WESTMALL_GSelectPickup_01": frozenset({1, 2, 4}),
    "SC_WESTMALL_GrenadePickup_01": frozenset({1, 2, 4}),
    "SC_WESTMALL_KevlarPickup_01": frozenset({1, 2, 4}),
    "SC_WESTMALL_MachineGunPickup_01": frozenset({1, 2, 4}),
    "SC_WESTMALL_MachinegunAmmoPickup_01": frozenset({1, 2, 4}),
    "SC_WESTMALL_MachinegunAmmoPickup_02": frozenset({1, 2, 4}),
    "SC_WESTMALL_MedKitPickup_01": frozenset({1, 2, 4}),
    "SC_WESTMALL_MedKitPickup_02": frozenset({1, 2, 4}),
    "SC_WESTMALL_MedKitPickup_03": frozenset({1, 2, 4}),
    "SC_WESTMALL_MP5Pickup_01": frozenset({1, 2, 4}),
    "SC_WESTMALL_MrDKNadePickup_01": frozenset({1, 2, 4}),
    "SC_WESTMALL_MrDKNadePickup_02": frozenset({1, 2, 4}),
    "SC_WESTMALL_MrDKNadePickup_03": frozenset({1, 2, 4}),
    "SC_WESTMALL_MrDKNadePickup_04": frozenset({1, 2, 4}),
    "SC_WESTMALL_MrDKNadePickup_05": frozenset({1, 2, 4}),
    "SC_WESTMALL_PistolAmmoPickup_01": frozenset({1, 2, 4}),
    "SC_WESTMALL_PistolAmmoPickup_02": frozenset({1, 2, 4}),
    "SC_WESTMALL_ScythePickup_01": frozenset({1, 2, 4}),
    "SC_WESTMALL_GrenadeLauncherPickup_01": frozenset({0, 1, 2, 3}),
    "SC_WESTMALL_ShearsPickup_01": frozenset({0, 1, 2, 3}),
    "SC_GREENBELT2_BaseballBatPickup_01": frozenset({4}),
    "SC_GREENBELT2_DynamitePickup_04": frozenset({4}),
    "SC_GREENBELT2_DynamitePickup_05": frozenset({4}),
    "SC_GREENBELT2_DynamitePickup_06": frozenset({4}),
}


def pile_open_on_hunt_day(unique: str, day) -> bool:
    closed = HUNT_CLOSED_DAYS.get(unique)
    if not closed or day is None:
        return True
    return int(day) not in closed


def choose_scrounge(rng, cap_by_map=None, spacing=320.0, max_tokens=None, lootsanity=False, hunt_days=None):
    """Pick a random number of world tokens per map from the scrounge catalog.

    Each playable map rolls TOKEN_CAP_MIN through `max_tokens` (YAML maximum,
    default 12), then keeps at most as many 320-UU-spaced piles as exist there.
    Lootsanity takes every eligible pile (blocked / Crackola leftovers still
    skipped) and ignores the YAML cap and spacing.
    `hunt_days` is map key to weekday. Piles in HUNT_CLOSED_DAYS are left out
    when that map hunts on a day the gate is shut, and a reachable pile is
    picked instead.
    """
    if max_tokens is None:
        max_tokens = TOKEN_CAP_DEFAULT
    max_tokens = max(TOKEN_CAP_MIN, min(int(max_tokens), TOKEN_CAP_MAX))
    if lootsanity:
        spacing = 0.0
    by_map: dict[str, list] = defaultdict(list)
    for e in SCROUNGE_CATALOG:
        by_map[e["map"]].append(dict(e))
    for e in EXTRA_SCROUNGE_CATALOG:
        by_map[e["map"]].append(dict(e))
    chosen = []
    for m in MAPS:
        if m["key"] in UNPLAYABLE_MAPS:
            continue
        if m.get("pickups", 0) <= 0:
            continue
        cap = (cap_by_map or {}).get(m["key"], max_tokens)
        if lootsanity:
            cap = 100000
        if cap <= 0:
            continue
        spots = list(by_map.get(m["key"], []))
        rng.shuffle(spots)
        taken = []
        blocked = []
        for s in spots:
            if len(taken) >= cap:
                break
            pos = (s["x"], s["y"], s["z"])
            if s.get("unique") in BLOCKED_SCROUNGE_UNIQUES:
                continue
            if hunt_days is not None and not pile_open_on_hunt_day(
                s.get("unique"), hunt_days.get(s["map"])
            ):
                continue
            if s.get("cls") == "CrackColaPickup":
                continue
            if is_blocked_scrounge(s["map"], s["cls"], s["x"], s["y"], s["z"]):
                continue
            if spacing > 0 and any(_dist3(pos, b) < spacing for b in blocked):
                continue
            taken.append(s)
            blocked.append(pos)
        if not taken:
            continue
        if lootsanity:
            chosen.extend(taken)
            continue
        lo = min(TOKEN_CAP_MIN, len(taken))
        n = rng.randint(lo, len(taken))
        chosen.extend(taken[:n])
    return chosen


def locations_for_day(day: int):
    return [
        loc["name"]
        for loc in enabled_locations()
        if loc["day"] == day
    ]


def errands_for_day(day: int, for_sleep: bool = False):
    names = []
    for loc in LOCATIONS:
        if loc["day"] != day:
            continue
        if loc["unique"] not in ERRAND_UNIQUES:
            continue
        if loc.get("option"):
            continue
        if for_sleep and loc["unique"] in SLEEP_SKIP_UNIQUES:
            continue
        names.append(loc["name"])
    return names


def gated_errands():
    return []


def map_pickup_caps():
    return {m["key"]: m["pickups"] for m in MAPS}
