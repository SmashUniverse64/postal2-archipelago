"""Run with python apworld/test_hint_names.py.

Load the data-only modules without requiring an installed Archipelago runtime.
"""

import importlib
from pathlib import Path
import sys
import types
import unittest


PACKAGE = "_postal2_hint_tests"
package = types.ModuleType(PACKAGE)
package.__path__ = [str(Path(__file__).parent / "postal2")]
sys.modules[PACKAGE] = package
hints = importlib.import_module(f"{PACKAGE}.hint_names")
data = importlib.import_module(f"{PACKAGE}.data")


class HintNameTests(unittest.TestCase):
    def test_place_extraction(self):
        cases = {
            "More Glock Ammo Secret Passage Shelf Left": "Secret Passage Shelf Left",
            "Even More Molotovs Northeast Hill": "Northeast Hill",
            "The Last Machine Gun Ammo North Yard": "North Yard",
            "Thirty-Third Cash Bank Vault Left Shelf": "Bank Vault Left Shelf",
            "Dog Treat Box Cache Room before Tora Bora": "Cache Room before Tora Bora",
            "Another Dog Treat Clinic Roof": "Clinic Roof",
            "Gary Autobiography Restroom Lot": "Restroom Lot",
            "Radar Plugin behind Police Parking Dumpster": "Police Parking Dumpster",
            "More Krotchy Grenades West Parking": "West Parking",
            "Shotgun Between Bookshelves": "Bookshelves",
            "Pistol Before Collapse": "Before Collapse",
        }
        for hint, place in cases.items():
            with self.subTest(hint=hint):
                self.assertEqual(hints._place_from_hint(hint), place)

    def test_all_eligible_piles_have_distinct_names(self):
        piles = [e for e in data.world_locations() if e.get("kind") == "scrounge"]
        self.assertTrue(piles)
        names = []
        for entry in piles:
            with self.subTest(unique=entry["unique"]):
                self.assertIn(entry["unique"], hints.HINT_BY_UNIQUE)
                self.assertEqual(entry["name"], hints.HINT_BY_UNIQUE[entry["unique"]])
            names.append(entry["name"])
        self.assertEqual(len(names), len(set(names)))
        self.assertEqual(len(data.LOCATIONS), len(data.location_name_to_id()))

    def test_authored_labels_resolve(self):
        self.assertEqual(hints.unmatched_hints(), [])
        keys = [(mk, label) for mk, label, _ in hints.HINT_LABELS]
        self.assertEqual(len(keys), len(set(keys)))

    def test_original_pickup_and_map_are_preserved(self):
        expected = {
            "SC_GREENBELT1_DynamitePickup_01": "Greenbelt - Dynamite Bank Secret Passage Shelf Left 1",
            "SC_GREENBELT1_ShotGunPickup_03": "Greenbelt - Shotgun Bank Interior between Soda Fridges",
            "SC_ESTATES_MachinegunAmmoPickup_02": "Estates - Machine Gun Ammo Cop House Bedroom Footlocker",
            "SC_LIBRARY2_SledgePickup_01": "Burning Library - Sledgehammer Dog Pit",
            "COLA_EASTMALL_01": "East Mall - Crackola Machines on the Lower Level",
            "COLA_EASTMALL_02": "East Mall - Crackola Machines near Glock Table",
        }
        for unique, name in expected.items():
            with self.subTest(unique=unique):
                self.assertEqual(hints.HINT_BY_UNIQUE[unique], name)

    def test_hunt_day_gates(self):
        import random

        gated = data.HUNT_CLOSED_DAYS
        self.assertTrue(gated)
        for unique in gated:
            self.assertNotIn(unique, data.BLOCKED_SCROUNGE_UNIQUES)
            self.assertIn(unique, hints.HINT_BY_UNIQUE)

        def chosen(day_west, day_nap, loot=False, seed=0):
            days = {m["key"]: 0 for m in data.MAPS}
            days["WESTMALL"] = day_west
            days["GREENBELT2"] = day_nap
            rows = data.choose_scrounge(
                random.Random(seed),
                max_tokens=15,
                lootsanity=loot,
                hunt_days=days,
            )
            return {e["unique"] for e in rows}

        def expect(rows, day_west, day_nap):
            for unique, closed in gated.items():
                day = day_west if unique.startswith("SC_WESTMALL_") else day_nap
                if day in closed:
                    self.assertNotIn(unique, rows)
                else:
                    self.assertIn(unique, rows)

        expect(chosen(2, 4, loot=True), 2, 4)
        expect(chosen(3, 3, loot=True), 3, 3)
        expect(chosen(4, 3, loot=True), 4, 3)

        for seed in range(12):
            rolled = chosen(1, 4, loot=False, seed=seed)
            for unique, closed in gated.items():
                day = 1 if unique.startswith("SC_WESTMALL_") else 4
                if day in closed:
                    self.assertNotIn(unique, rolled)

    def test_machine_filler_counts_as_grey(self):
        tokens = {"SC_HOME_Medkit_01"}
        for unique in (
            "ATM_EASTMALL_2",
            "COLA_EASTMALL_02",
            "VUSE_EASTMALL_01",
            "VBUY_EASTMALL_03",
        ):
            self.assertTrue(data.is_machine_check(unique))
            self.assertTrue(data.counts_as_grey_check(unique, tokens))
        self.assertFalse(data.is_machine_check("SC_HOME_Medkit_01"))
        self.assertFalse(data.is_machine_check(""))
        self.assertTrue(data.counts_as_grey_check("SC_HOME_Medkit_01", tokens))
        self.assertFalse(data.counts_as_grey_check("SC_OTHER", tokens))
        self.assertTrue(data.counts_as_grey_check("SC_OTHER", None))
        self.assertTrue(data.counts_as_grey_check("SC_OTHER", set()))
        self.assertFalse(data.counts_as_grey_check("", tokens))

    def test_trap_selection_keeps_old_switch(self):
        all_traps = set(data.TRAP_NAMES)
        self.assertEqual(data.coerce_trap_selection(True), all_traps)
        self.assertEqual(data.coerce_trap_selection("yes"), all_traps)
        self.assertEqual(data.coerce_trap_selection(False), set())
        self.assertEqual(data.coerce_trap_selection("off"), set())
        self.assertEqual(
            data.coerce_trap_selection(["Piss Trap", "Gimp Trap"]),
            {"Piss Trap", "Gimp Trap"},
        )
        self.assertEqual(len(all_traps), 7)


if __name__ == "__main__":
    unittest.main()
