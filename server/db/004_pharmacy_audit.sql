CREATE TABLE IF NOT EXISTS pharmacy_audit_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  pharmacy_id UUID NOT NULL REFERENCES pharmacy_profiles(id) ON DELETE RESTRICT,
  actor_user_id UUID REFERENCES app_users(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL,
  target_id UUID,
  payload JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_pharmacy_audit_timeline
  ON pharmacy_audit_events(pharmacy_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_pharmacy_audit_actor
  ON pharmacy_audit_events(actor_user_id, created_at DESC);
