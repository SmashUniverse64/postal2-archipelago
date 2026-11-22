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


if __name__ == "__main__":
    unittest.main()
