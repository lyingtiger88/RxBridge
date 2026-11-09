CREATE INDEX IF NOT EXISTS idx_pharmacy_reservations_expiry
  ON pharmacy_reservations(expires_at)
  WHERE status='held';

CREATE OR REPLACE FUNCTION expire_pharmacy_reservations(p_limit INTEGER DEFAULT 500)
RETURNS INTEGER
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public, pg_temp
AS $$
DECLARE
  affected INTEGER;
BEGIN
  WITH expired AS (
    SELECT id FROM pharmacy_reservations
    WHERE status='held' AND expires_at <= now()
    ORDER BY expires_at
    LIMIT LEAST(GREATEST(p_limit, 1), 5000)
    FOR UPDATE SKIP LOCKED
  )
  UPDATE pharmacy_reservations r
  SET status='expired'
  FROM expired
  WHERE r.id=expired.id;
  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$;

REVOKE ALL ON FUNCTION expire_pharmacy_reservations(INTEGER) FROM PUBLIC;
