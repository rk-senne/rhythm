-- Persist soft-delete tombstones so deletes propagate across devices.
ALTER TABLE sync_changes ADD COLUMN IF NOT EXISTS deleted_at TIMESTAMPTZ;

-- server_updated_at is assigned by the server on every write and is used as the
-- pull cursor. Using a server clock (not the spoofable client updated_at) means
-- client clock skew can no longer cause a device to miss changes.
ALTER TABLE sync_changes ADD COLUMN IF NOT EXISTS server_updated_at TIMESTAMPTZ NOT NULL DEFAULT now();

-- The pull query filters/orders by (user_id, server_updated_at).
DROP INDEX IF EXISTS idx_sync_changes_updated;
CREATE INDEX IF NOT EXISTS idx_sync_changes_server_updated ON sync_changes(user_id, server_updated_at);
