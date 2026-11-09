CREATE TABLE IF NOT EXISTS pharmacy_profiles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL UNIQUE REFERENCES app_users(id) ON DELETE CASCADE,
  pharmacy_name TEXT NOT NULL,
  address TEXT NOT NULL,
  phone TEXT,
  latitude DOUBLE PRECISION,
  longitude DOUBLE PRECISION,
  verification_status TEXT NOT NULL DEFAULT 'pending'
    CHECK (verification_status IN ('pending','verified','rejected','suspended')),
  is_published BOOLEAN NOT NULL DEFAULT FALSE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  CHECK ((latitude IS NULL AND longitude IS NULL) OR
         (latitude BETWEEN -90 AND 90 AND longitude BETWEEN -180 AND 180))
);
CREATE INDEX IF NOT EXISTS idx_pharmacy_geo ON pharmacy_profiles(latitude, longitude)
  WHERE is_published = TRUE AND verification_status = 'verified';

CREATE TABLE IF NOT EXISTS pharmacy_inventory (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id UUID NOT NULL REFERENCES pharmacy_profiles(id) ON DELETE CASCADE,
  medicine_name TEXT NOT NULL,
  dosage_form TEXT NOT NULL,
  strength TEXT NOT NULL DEFAULT '',
  package_label TEXT NOT NULL DEFAULT '',
  unit_price BIGINT NOT NULL CHECK (unit_price >= 0),
  stock_quantity INTEGER NOT NULL DEFAULT 0 CHECK (stock_quantity >= 0),
  is_active BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (pharmacy_id, medicine_name, dosage_form, strength, package_label)
);
CREATE INDEX IF NOT EXISTS idx_pharmacy_inventory_lookup
  ON pharmacy_inventory(pharmacy_id, lower(medicine_name), lower(dosage_form), lower(strength))
  WHERE is_active = TRUE;

