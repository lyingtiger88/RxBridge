import os
import unittest
import sys
from pathlib import Path
from uuid import uuid4

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))

if os.environ.get("RXBRIDGE_INTEGRATION_TESTS") != "1":
    raise unittest.SkipTest("Integration tests run only in the PostgreSQL CI job")

from fastapi.testclient import TestClient
from app import main


class PharmacyReservationApiTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.client = TestClient(main.app)

    def setUp(self):
        self.patient_id = uuid4()
        self.pharmacist_id = uuid4()
        self.pharmacy_id = uuid4()
        self.inventory_id = uuid4()
        self.patient_name = f"ci_patient_{self.patient_id.hex}"
        self.pharmacist_name = f"ci_pharmacist_{self.pharmacist_id.hex}"
        with main.connect() as conn:
            conn.execute(
                "INSERT INTO app_users(id,username,password_hash,role,display_name) VALUES (%s,%s,'x','patient','CI patient')",
                (self.patient_id, self.patient_name),
            )
            conn.execute(
                "INSERT INTO app_users(id,username,password_hash,role,display_name) VALUES (%s,%s,'x','pharmacist','CI pharmacist')",
                (self.pharmacist_id, self.pharmacist_name),
            )
            conn.execute("""
                INSERT INTO pharmacy_profiles
                  (id,user_id,pharmacy_name,address,latitude,longitude,verification_status,is_published)
                VALUES (%s,%s,'CI Pharmacy','CI Test Address',35.7,51.4,'verified',TRUE)
            """, (self.pharmacy_id, self.pharmacist_id))
            conn.execute("""
                INSERT INTO pharmacy_inventory
                  (id,pharmacy_id,medicine_name,dosage_form,strength,package_label,
                   unit_price,stock_quantity,is_active)
                VALUES (%s,%s,'Test Medicine','tablet','500 mg','box 10',120000,5,TRUE)
            """, (self.inventory_id, self.pharmacy_id))

    def tearDown(self):
        main.app.dependency_overrides.clear()
        with main.connect() as conn:
            conn.execute("DELETE FROM pharmacy_reservations WHERE pharmacy_id=%s", (self.pharmacy_id,))
            conn.execute("DELETE FROM pharmacy_profiles WHERE id=%s", (self.pharmacy_id,))
            conn.execute("DELETE FROM app_users WHERE id IN (%s,%s)", (self.patient_id, self.pharmacist_id))

    def authenticate(self, role):
        user_id = self.patient_id if role == "patient" else self.pharmacist_id
        user = {
            "id": user_id, "username": "ci", "role": role,
            "display_name": "CI", "active": True,
        }
        main.app.dependency_overrides[main.current_user] = lambda: user

    def reservation_body(self, key, quantity=1):
        return {
            "idempotency_key": str(key),
            "items": [{
                "medicine_name": "Test Medicine",
                "dosage_form": "tablet",
                "strength": "500 mg",
                "package_label": "box 10",
                "quantity": quantity,
            }],
        }

    def reserve(self, key, quantity=1):
        self.authenticate("patient")
        return self.client.post(
            f"/v1/pharmacies/{self.pharmacy_id}/reservations",
            json=self.reservation_body(key, quantity),
        )

    def test_active_hold_prevents_overselling_and_is_reflected_in_search(self):
        first = self.reserve(uuid4(), 4)
        self.assertEqual(first.status_code, 201, first.text)
        self.assertEqual(first.json()["status"], "held")
        self.authenticate("patient")
        search = self.client.post("/v1/pharmacies/search", json={
            "latitude": 35.7, "longitude": 51.4, "radius_km": 5,
            "items": [{
                "medicine_name": "Test Medicine", "dosage_form": "tablet",
                "strength": "500 mg", "package_label": "box 10", "quantity": 2,
            }],
        })
        self.assertEqual(search.status_code, 200, search.text)
        self.assertEqual(search.json()["results"][0]["missing_items"][0]["available_quantity"], 1)
        second = self.reserve(uuid4(), 2)
        self.assertEqual(second.status_code, 409, second.text)

    def test_idempotency_returns_same_reservation_and_rejects_payload_reuse(self):
        key = uuid4()
        first = self.reserve(key, 2)
        again = self.reserve(key, 2)
        changed = self.reserve(key, 3)
        self.assertEqual(first.status_code, 201, first.text)
        self.assertEqual(again.status_code, 200, again.text)
        self.assertEqual(first.json()["id"], again.json()["id"])
        self.assertEqual(changed.status_code, 409)

    def test_confirmation_deducts_inventory(self):
        response = self.reserve(uuid4(), 3)
        self.assertEqual(response.status_code, 201, response.text)
        self.authenticate("pharmacist")
        confirmed = self.client.post(
            f"/v1/pharmacies/reservations/{response.json()['id']}/confirm"
        )
        self.assertEqual(confirmed.status_code, 200, confirmed.text)
        self.assertEqual(confirmed.json()["status"], "confirmed")
        with main.connect() as conn:
            stock = conn.execute(
                "SELECT stock_quantity FROM pharmacy_inventory WHERE id=%s",
                (self.inventory_id,),
            ).fetchone()["stock_quantity"]
        self.assertEqual(stock, 2)

    def test_cancellation_releases_the_hold(self):
        first = self.reserve(uuid4(), 5)
        self.assertEqual(first.status_code, 201, first.text)
        self.authenticate("patient")
        cancelled = self.client.post(
            f"/v1/pharmacies/reservations/{first.json()['id']}/cancel"
        )
        self.assertEqual(cancelled.status_code, 200, cancelled.text)
        self.assertEqual(cancelled.json()["status"], "cancelled")
        second = self.reserve(uuid4(), 5)
        self.assertEqual(second.status_code, 201, second.text)


if __name__ == "__main__":
    unittest.main()
