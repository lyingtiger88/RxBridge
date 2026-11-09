CREATE TABLE IF NOT EXISTS app_notifications (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  recipient_user_id UUID NOT NULL REFERENCES app_users(id) ON DELETE CASCADE,
  actor_user_id UUID REFERENCES app_users(id) ON DELETE SET NULL,
  event_type TEXT NOT NULL,
  title TEXT NOT NULL,
  body TEXT NOT NULL DEFAULT '',
  entity_type TEXT NOT NULL,
  entity_id UUID NOT NULL,
  read_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_app_notifications_inbox
  ON app_notifications(recipient_user_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_app_notifications_unread
  ON app_notifications(recipient_user_id, created_at DESC)
  WHERE read_at IS NULL;
