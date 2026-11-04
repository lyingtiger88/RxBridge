CREATE EXTENSION IF NOT EXISTS pgcrypto;
CREATE TABLE IF NOT EXISTS app_users (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), username TEXT UNIQUE NOT NULL,
 password_hash TEXT NOT NULL, role TEXT NOT NULL CHECK(role IN ('admin','doctor','patient','pharmacist','insurer','laboratory')),
 display_name TEXT NOT NULL, active BOOLEAN NOT NULL DEFAULT TRUE, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS demo_patients (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), display_code TEXT UNIQUE NOT NULL,
 display_name TEXT NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS demo_lab_orders (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), patient_id UUID NOT NULL REFERENCES demo_patients(id),
 test_name TEXT NOT NULL, scheduled_at TIMESTAMPTZ NOT NULL,
 status TEXT NOT NULL DEFAULT 'pending' CHECK(status IN ('pending','reported','cancelled'))
);

CREATE TABLE IF NOT EXISTS demo_lab_results (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), order_id UUID NOT NULL REFERENCES demo_lab_orders(id),
 result_text TEXT NOT NULL, units TEXT, detailed_report TEXT NOT NULL DEFAULT '',
 reported_by UUID NOT NULL REFERENCES app_users(id), reported_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS demo_glucose_schedules (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), patient_id UUID NOT NULL REFERENCES demo_patients(id),
 times_local TEXT[] NOT NULL, timezone TEXT NOT NULL DEFAULT 'Asia/Tehran',
 set_by UUID NOT NULL REFERENCES app_users(id), created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE TABLE IF NOT EXISTS demo_prescriptions (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), patient_id UUID NOT NULL REFERENCES demo_patients(id),
 doctor_id UUID NOT NULL REFERENCES app_users(id), status TEXT NOT NULL DEFAULT 'draft',
 created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
\nCREATE TABLE IF NOT EXISTS demo_glucose_readings (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), patient_id UUID NOT NULL REFERENCES demo_patients(id),
 value_mg_dl INTEGER NOT NULL CHECK(value_mg_dl BETWEEN 1 AND 1000),
 measured_at TIMESTAMPTZ NOT NULL, context TEXT NOT NULL,
 created_by UUID NOT NULL REFERENCES app_users(id)
);
CREATE TABLE IF NOT EXISTS demo_consent_events (
 id UUID PRIMARY KEY DEFAULT gen_random_uuid(), patient_id UUID NOT NULL,
 actor_user_id UUID NOT NULL REFERENCES app_users(id), scope TEXT NOT NULL,
 granted BOOLEAN NOT NULL, created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_glucose_patient_time ON demo_glucose_readings(patient_id, measured_at DESC);
