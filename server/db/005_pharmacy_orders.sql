CREATE TABLE IF NOT EXISTS pharmacy_orders (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  reservation_id UUID NOT NULL UNIQUE REFERENCES pharmacy_reservations(id) ON DELETE RESTRICT,
  pharmacy_id UUID NOT NULL REFERENCES pharmacy_profiles(id) ON DELETE RESTRICT,
  patient_user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE RESTRICT,
  status TEXT NOT NULL DEFAULT 'submitted'
    CHECK (status IN ('submitted','accepted','preparing','ready','dispensed','cancelled')),
  patient_note TEXT NOT NULL DEFAULT '',
  pharmacy_note TEXT NOT NULL DEFAULT '',
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  accepted_at TIMESTAMPTZ,
  preparing_at TIMESTAMPTZ,
  ready_at TIMESTAMPTZ,
  dispensed_at TIMESTAMPTZ,
  cancelled_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pharmacy_orders_patient
  ON pharmacy_orders(patient_user_id, submitted_at DESC);
CREATE INDEX IF NOT EXISTS idx_pharmacy_orders_pharmacy
  ON pharmacy_orders(pharmacy_id, status, submitted_at DESC);
