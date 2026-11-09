import math
import os
import unittest
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

os.environ.setdefault("JWT_SECRET", "ci-test-secret-with-at-least-32-characters")
os.environ.setdefault("DATABASE_URL", "postgresql://unused:unused@127.0.0.1:1/unused")

from app.main import PrescriptionSearchItem, _distance_km, _norm


class PharmacyMatchingTests(unittest.TestCase):
    def test_distance_is_zero_for_same_point(self):
        self.assertEqual(_distance_km(49.0, 8.4, 49.0, 8.4), 0.0)

    def test_one_degree_latitude_is_about_111_km(self):
        self.assertTrue(110.5 < _distance_km(0, 0, 1, 0) < 111.5)

    def test_distance_is_symmetric(self):
        self.assertAlmostEqual(_distance_km(35.7, 51.4, 36.3, 59.6),
                               _distance_km(36.3, 59.6, 35.7, 51.4), places=9)

    def test_normalization_ignores_case_and_repeated_spaces(self):
        self.assertEqual(_norm("  Acetaminophen   500 MG "), "acetaminophen 500 mg")

    def test_prescription_quantity_must_be_positive(self):
        with self.assertRaises(ValueError):
            PrescriptionSearchItem(medicine_name="Test", dosage_form="tablet", quantity=0)

    def test_coordinates_are_validated(self):
        from app.main import PharmacySearchRequest
        with self.assertRaises(ValueError):
            PharmacySearchRequest(latitude=100, longitude=0, items=[
                {"medicine_name": "Test", "dosage_form": "tablet", "quantity": 1}
            ])


if __name__ == "__main__":
    unittest.main()
