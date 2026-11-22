#!/usr/bin/env python3
"""Scan Postal 2 .fuk maps and write postal2/catalog.py (scrounge-eligible piles)."""

from __future__ import annotations

import json
import struct
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parent
MAPS_DIR = Path(r"E:\SteamLibrary\steamapps\common\POSTAL2Editor\Maps")
OUT_PY = ROOT / "postal2" / "catalog.py"

MAP_FILES = {
    "INTRO": "intro.fuk",
    "GREENBELT1": "Greenbelt1.fuk",
    "GREENBELT2": "Greenbelt2.fuk",
    "ESTATES": "Estates.fuk",
    "RWSBLOCK": "rwsblock.fuk",
    "HIGHLANDS": "Highlands.fuk",
    "POLICE": "police.fuk",
    "INDUSTRY": "Industry.fuk",
    "INDUSTRY2": "Industry2.fuk",
    "UNDERHUB": "underhub.fuk",
    "TORABORA": "ToraBora.fuk",
    "LIBRARY1": "library1.fuk",
    "LIBRARY2": "library2.fuk",
    "EASTMALL": "EastMall.fuk",
    "WESTMALL": "WestMall.fuk",
    "CHURCH": "Church.fuk",
    "FOREST": "forest.fuk",
    "BREWERY": "Brewery.fuk",
    "NAPALM": "Napalm.fuk",
    "SUBURBS-1": "suburbs-1.fuk",
    "SUBURBS-2": "suburbs-2.fuk",
    "SUBURBS-3": "suburbs-3.fuk",
    "SUBURBS-4": "suburbs-4.fuk",
    "SLAUGHTERHOUSE": "slaughterhouse.fuk",
    "COMPOUND": "Compound.fuk",
    "PARCELCENTER": "parcelcenter.fuk",
    "JUNKYARD": "Junkyard.fuk",
}

MAP_NAMES = {
    "INTRO": "Intro",
    "GREENBELT1": "Greenbelt",
    "GREENBELT2": "Greenbelt 2",
    "ESTATES": "Estates",
    "RWSBLOCK": "Office Complex",
    "HIGHLANDS": "Trainyard Area",
    "POLICE": "Police Station",
    "INDUSTRY": "Clinic Area",
    "INDUSTRY2": "Industrial Area",
    "UNDERHUB": "Sewer",
    "TORABORA": "Tora Bora",
    "LIBRARY1": "Library",
    "LIBRARY2": "Library Interior",
    "EASTMALL": "East Mall",
    "WESTMALL": "West Mall",
    "CHURCH": "Church",
    "FOREST": "Forest",
    "BREWERY": "Brewery",
    "NAPALM": "Napalm Factory",
    "SUBURBS-1": "Main Street",
    "SUBURBS-2": "Ghetto",
    "SUBURBS-3": "Home",
    "SUBURBS-4": "Suburbs East",
    "SLAUGHTERHOUSE": "Meat World",
    "COMPOUND": "Compound",
    "PARCELCENTER": "Parcel Center",
    "JUNKYARD": "Junkyard",
}

SKIP_CLASSES = {
    "PaycheckPickup", "MilkPickup", "LibraryBookPickup", "ClipboardPickup",
    "CitationPickup", "GiftPickup", "TreePickup", "ParcelPickup",
    "AlternatorPickup", "SteakPickup", "KrotchyPickup", "NapalmPickupErrand",
    "PillsPickup", "GaryBookPickup", "CatPickup", "PickupCash",
    "CrackColaPickup",
}

# Former named-cache (map, class) piles. Keep them out of SCROUNGE_CATALOG
# so a regen does not insert rows in the middle and shift location IDs.
# Those piles are extra SC_ rows from NAMED_STASH_POS (hint_names.extra_scrounge_catalog).
NAMED_MAP_CLASS = {
    ("SUBURBS-3", "ShovelPickup"), ("INTRO", "ShovelPickup"),
    ("SUBURBS-1", "LauncherPickup"), ("PARCELCENTER", "LauncherPickup"),
    ("NAPALM", "LauncherPickup"), ("INDUSTRY", "LauncherPickup"),
    ("RWSBLOCK", "LauncherPickup"), ("HIGHLANDS", "LauncherPickup"),
    ("CHURCH", "LauncherPickup"),
    ("GREENBELT1", "RiflePickup"), ("GREENBELT2", "RiflePickup"),
    ("TORABORA", "RiflePickup"), ("PARCELCENTER", "RiflePickup"),
    ("FOREST", "RiflePickup"), ("HIGHLANDS", "RiflePickup"),
    ("SUBURBS-2", "RiflePickup"),
    ("GREENBELT1", "DynamitePickup"), ("INDUSTRY", "DynamitePickup"),
    ("INDUSTRY2", "DynamitePickup"),
    ("INDUSTRY", "ShotGunPickup"), ("SUBURBS-2", "ShotGunPickup"),
    ("GREENBELT1", "ShotGunPickup"), ("RWSBLOCK", "ShotGunPickup"),
    ("UNDERHUB", "ShotGunPickup"),
    ("GREENBELT2", "GrenadeLauncherPickup"),
    ("TORABORA", "MachetePickup"), ("TORABORA", "PlaguePickup"),
    ("TORABORA", "NukePickup"), ("TORABORA", "CowHeadPickup"),
    ("SLAUGHTERHOUSE", "CowHeadPickup"),
    ("HIGHLANDS", "BetaShotgunPickup"),
    ("SLAUGHTERHOUSE", "SawnOffPickup"), ("CHURCH", "SawnOffPickup"),
    ("WESTMALL", "SawnOffPickup"), ("FOREST", "SawnOffPickup"),
    ("SUBURBS-2", "SawnOffPickup"), ("HIGHLANDS", "SawnOffPickup"),
    ("SUBURBS-4", "SawnOffPickup"),
    ("CHURCH", "ScythePickup"), ("ESTATES", "ScythePickup"),
    ("NAPALM", "FlamePickup"), ("UNDERHUB", "FlamePickup"),
    ("INDUSTRY", "FlamePickup"), ("ESTATES", "FlamePickup"),
    ("FOREST", "FlamePickup"),
    ("SUBURBS-4", "ChainsawPickup"), ("SUBURBS-3", "ChainsawPickup"),
    ("HIGHLANDS", "ChainsawPickup"), ("COMPOUND", "ChainsawPickup"),
    ("GREENBELT2", "ChainsawPickup"),
    ("LIBRARY2", "SledgePickup"), ("JUNKYARD", "SledgePickup"),
    ("POLICE", "CopClothesPickup"), ("POLICE", "RadarPickup"),
    ("TORABORA", "RadarPickup"), ("ESTATES", "GunRadarPlugPickup"),
    ("HIGHLANDS", "CopRadarPlugPickup"), ("HIGHLANDS", "RadarTargetPickup"),
    ("UNDERHUB", "BodyArmorPickup"), ("UNDERHUB", "CrackPickup"),
    ("UNDERHUB", "ClothesPickup"), ("BREWERY", "GimpClothesPickup"),
    ("SUBURBS-3", "CatnipPickup"), ("INTRO", "CatnipPickup"),
    ("SUBURBS-1", "CatnipPickup"), ("HIGHLANDS", "CatnipPickup"),
    ("INDUSTRY", "CatnipPickup"), ("TORABORA", "CatnipPickup"),
    ("WESTMALL", "CatnipPickup"),
    ("UNDERHUB", "PizzaPickup"), ("UNDERHUB", "FastFoodPickup"),
    ("SUBURBS-3", "DogTreatPickup"), ("SUBURBS-3", "DogTreatBoxPickup"),
    ("POLICE", "MachineGunPickup"), ("EASTMALL", "MP5Pickup"),
}

# Unreachable piles (inside unbreakable geometry). (map, class, x, y, z, radius)
BLOCKED_SPOTS = [
    # Office Complex: pistol mag inside a cardboard box that cannot be moved or broken
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
]


def is_blocked_spot(map_key, cls, x, y, z):
    for m, c, bx, by, bz, r in BLOCKED_SPOTS:
        if m != map_key or c != cls:
            continue
        dx, dy, dz = x - bx, y - by, z - bz
        if dx * dx + dy * dy + dz * dz <= r * r:
            return True
    return False

CLASS_LABEL = {
    "ShotGunPickup": "Shotgun",
    "SawnOffPickup": "Sawed-Off",
    "BetaShotgunPickup": "Beta Shotgun",
    "PistolPickup": "Pistol",
    "GSelectPickup": "Glock",
    "MP5Pickup": "MP5",
    "MachineGunPickup": "Machine Gun",
    "RiflePickup": "Hunting Rifle",
    "LauncherPickup": "Rocket Launcher",
    "GrenadePickup": "Grenades",
    "GrenadeLauncherPickup": "Grenade Launcher",
    "GasCanPickup": "Gas Can",
    "ChainsawPickup": "Chainsaw",
    "MolotovPickup": "Molotovs",
    "DynamitePickup": "Dynamite",
    "NapalmPickup": "Napalm",
    "FlamePickup": "Flamethrower",
    "CowHeadPickup": "Cow Head",
    "SledgePickup": "Sledgehammer",
    "ScythePickup": "Scythe",
    "MachetePickup": "Machete",
    "AxePickup": "Axe",
    "BaliPickup": "Bali",
    "ShearsPickup": "Shears",
    "ScissorsPickup": "Scissors",
    "BaseballBatPickup": "Baseball Bat",
    "DustersPickup": "Dusters",
    "MedKitPickup": "Medkit",
    "FastFoodPickup": "Fast Food",
    "DonutPickup": "Donut",
    "PizzaPickup": "Pizza",
    "MoneyPickup": "Cash",
    "CrackPickup": "Health Pipe",
    "CatnipPickup": "Catnip",
    "KevlarPickup": "Kevlar",
    "BodyArmorPickup": "Body Armor",
    "PistolAmmoPickup": "Pistol Ammo",
    "ShotgunAmmoPickup": "Shotgun Ammo",
    "SawnOffAmmoPickup": "Sawed-Off Ammo",
    "MachinegunAmmoPickup": "Machine Gun Ammo",
    "RifleAmmoPickup": "Rifle Ammo",
    "LauncherAmmoPickup": "Rockets",
    "GSelectAmmoPickup": "Glock Ammo",
    "MP5AmmoPickup": "MP5 Ammo",
    "NapalmAmmoPickup": "Napalm Ammo",
    "RadarPickup": "Bass Sniffer",
    "CopClothesPickup": "Cop Uniform",
}


def compact(data: bytes, off: int) -> tuple[int, int]:
    b = data[off]
    off += 1
    neg = bool(b & 0x80)
    v = b & 0x3F
    if b & 0x40:
        shift = 6
        while True:
            b = data[off]
            off += 1
            v |= (b & 0x7F) << shift
            shift += 7
            if not (b & 0x80):
                break
    return (-v if neg else v), off


def parse_names(data: bytes, no: int, nc: int) -> list[str]:
    off = no
    names = []
    for _ in range(nc):
        ln, off = compact(data, off)
        if ln < 0:
            ln = -ln
        raw = data[off : off + ln]
        off += ln + 4
        names.append(raw.split(b"\x00")[0].decode("latin1", "replace"))
    return names


def xyz_from_serial(blob: bytes) -> tuple[float, float, float] | None:
    trips = []
    for j in range(0, max(0, len(blob) - 11)):
        x, y, z = struct.unpack_from("<fff", blob, j)
        if 80 < abs(x) < 250000 and 80 < abs(y) < 250000 and abs(z) < 80000:
            trips.append((round(x, 1), round(y, 1), round(z, 1)))
    return trips[-1] if trips else None


def dump_map(path: Path) -> list[tuple[str, str, tuple[float, float, float]]]:
    data = path.read_bytes()
    magic, ver, lic = struct.unpack_from("<IHH", data, 0)
    if magic != 0x9E2A83C1:
        raise ValueError(path)
    flags, nc, no, ec, eo, ic, io = struct.unpack_from("<IIIIIII", data, 8)
    names = parse_names(data, no, nc)
    off = io
    imps = []
    for _ in range(ic):
        _pkg, off = compact(data, off)
        _cls, off = compact(data, off)
        _outer = struct.unpack_from("<i", data, off)[0]
        off += 4
        oname, off = compact(data, off)
        imps.append(names[oname] if 0 <= oname < len(names) else str(oname))
    off = eo
    out = []
    for _ in range(ec):
        cls, off = compact(data, off)
        _sup, off = compact(data, off)
        _outer = struct.unpack_from("<i", data, off)[0]
        off += 4
        ni, off = compact(data, off)
        _flags = struct.unpack_from("<I", data, off)[0]
        off += 4
        size, off = compact(data, off)
        serial, off = compact(data, off)
        cname = "None"
        if cls < 0:
            ii = -cls - 1
            if 0 <= ii < len(imps):
                cname = imps[ii]
        if "Pickup" not in cname or size < 16:
            continue
        loc = xyz_from_serial(data[serial : serial + size])
        if loc:
            out.append((cname, names[ni] if ni < len(names) else "", loc))
    return out


def main() -> None:
    catalog = []
    named_pos = []
    for key, fname in MAP_FILES.items():
        path = MAPS_DIR / fname
        if not path.exists():
            print("missing", fname)
            continue
        hits = dump_map(path)
        eligible = []
        for cname, _n, loc in hits:
            if cname in SKIP_CLASSES:
                continue
            if (key, cname) in NAMED_MAP_CLASS:
                named_pos.append({"map": key, "cls": cname, "x": loc[0], "y": loc[1], "z": loc[2]})
                continue
            if is_blocked_spot(key, cname, loc[0], loc[1], loc[2]):
                continue
            eligible.append((cname, loc))
        eligible.sort(key=lambda t: (t[0], t[1][0], t[1][1], t[1][2]))
        counts: dict[str, int] = defaultdict(int)
        totals: dict[str, int] = defaultdict(int)
        for cname, _loc in eligible:
            totals[cname] += 1
        for cname, loc in eligible:
            counts[cname] += 1
            n = counts[cname]
            label = CLASS_LABEL.get(cname, cname.replace("Pickup", ""))
            if totals[cname] > 1:
                disp = f"{MAP_NAMES[key]} - {label} {n}"
            else:
                disp = f"{MAP_NAMES[key]} - {label}"
            # Generic numbered names; postal2/hint_names.py overlays place
            # descriptions onto these uniques after catalog regen.
            unique = f"SC_{key}_{cname}_{n:02d}"
            catalog.append({
                "unique": unique,
                "name": disp,
                "map": key,
                "cls": cname,
                "x": loc[0],
                "y": loc[1],
                "z": loc[2],
            })
        print(f"{key:16} scanned {len(hits):3}  scrounge {len(eligible):3}  named {len(hits)-len(eligible)-sum(1 for c,_,__ in hits if c in SKIP_CLASSES):3}")
    OUT_PY.write_text(
        '"""Auto-generated scrounge catalog. Re-run scan_pickups.py after map edits."""\n\n'
        "SCROUNGE_CATALOG = " + json.dumps(catalog, indent=2) + "\n\n"
        "NAMED_STASH_POS = " + json.dumps(named_pos, indent=2) + "\n",
        encoding="utf-8",
    )
    print("wrote", OUT_PY, "entries", len(catalog), "named-stash refs", len(named_pos))


if __name__ == "__main__":
    main()
