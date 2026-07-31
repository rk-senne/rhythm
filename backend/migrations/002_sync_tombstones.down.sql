DROP INDEX IF EXISTS idx_sync_changes_server_updated;
CREATE INDEX IF NOT EXISTS idx_sync_changes_updated ON sync_changes(user_id, updated_at);
ALTER TABLE sync_changes DROP COLUMN IF EXISTS server_updated_at;
ALTER TABLE sync_changes DROP COLUMN IF EXISTS deleted_at;
