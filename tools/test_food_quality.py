from __future__ import annotations

import unittest

from food_quality import audit_records, clean_item


class FoodQualityTests(unittest.TestCase):
    def test_numeric_only_name_is_invalid(self):
        decision = clean_item(
            {
                "id": "1",
                "isim": "55",
                "kalori100g": 120,
                "protein100g": 3,
                "karbonhidrat100g": 20,
                "yag100g": 2,
            }
        )

        self.assertEqual(decision.status, "invalid")
        self.assertIn("invalid_name_no_alpha", decision.reasons)

    def test_small_rounding_overflow_is_clamped(self):
        decision = clean_item(
            {
                "id": "oil",
                "isim": "Zeytinyag",
                "kalori100g": 884,
                "protein100g": 0,
                "karbonhidrat100g": 0,
                "yag100g": 101.2,
            }
        )

        self.assertEqual(decision.status, "valid")
        self.assertEqual(decision.item["yag100g"], 100.0)
        self.assertIn("normalized_clamped_yag100g", decision.reasons)

    def test_macro_relation_errors_are_quarantined(self):
        decision = clean_item(
            {
                "id": "bad",
                "isim": "Meyveli urun",
                "kalori100g": 200,
                "protein100g": 2,
                "karbonhidrat100g": 10,
                "yag100g": 5,
                "seker100g": 18,
            }
        )

        self.assertEqual(decision.status, "suspect")
        self.assertIn("suspect_sugar_gt_carb", decision.reasons)

    def test_duplicate_name_brand_keeps_verified_record(self):
        records = [
            (
                "curated",
                0,
                {
                    "id": "verified",
                    "isim": "Ayran",
                    "kalori100g": 40,
                    "protein100g": 2,
                    "karbonhidrat100g": 4,
                    "yag100g": 1,
                    "isVerified": True,
                },
            ),
            (
                "branded",
                0,
                {
                    "id": "branded",
                    "isim": "Ayran",
                    "kalori100g": 41,
                    "protein100g": 2,
                    "karbonhidrat100g": 4,
                    "yag100g": 1,
                    "isVerified": False,
                },
            ),
        ]

        kept, suspects, summary = audit_records(records)

        self.assertEqual(len(kept), 1)
        self.assertEqual(kept[0]["id"], "verified")
        self.assertEqual(len(suspects), 1)
        self.assertEqual(summary["reason_counts"]["suspect_duplicate_name_brand"], 1)


if __name__ == "__main__":
    unittest.main()
