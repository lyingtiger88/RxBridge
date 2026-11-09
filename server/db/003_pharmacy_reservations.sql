CREATE TABLE IF NOT EXISTS pharmacy_reservations (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id UUID NOT NULL REFERENCES pharmacy_profiles(id) ON DELETE RESTRICT,
  patient_user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE RESTRICT,
  idempotency_key UUID NOT NULL,
  status TEXT NOT NULL DEFAULT 'held'
    CHECK (status IN ('held','confirmed','cancelled','expired')),
  expires_at TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '10 minutes'),
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  confirmed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  UNIQUE (patient_user_id, idempotency_key)
);
CREATE INDEX IF NOT EXISTS idx_pharmacy_reservations_active
  ON pharmacy_reservations(pharmacy_id, expires_at)
  WHERE status='held';

CREATE TABLE IF NOT EXISTS pharmacy_reservation_items (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id UUID NOT NULL REFERENCES pharmacy_reservations(id) ON DELETE CASCADE,
  inventory_id UUID NOT NULL REFERENCES pharmacy_inventory(id) ON DELETE RESTRICT,
  medicine_name TEXT NOT NULL,
  dosage_form TEXT NOT NULL,
  strength TEXT NOT NULL DEFAULT '',
  package_label TEXT NOT NULL DEFAULT '',
  quantity INTEGER NOT NULL CHECK (quantity > 0),
  unit_price BIGINT NOT NULL CHECK (unit_price >= 0),
  line_total BIGINT NOT NULL CHECK (line_total >= 0),
  UNIQUE (reservation_id, inventory_id)
);
CREATE INDEX IF NOT EXISTS idx_reservation_items_inventory
  ON pharmacy_reservation_items(inventory_id);
