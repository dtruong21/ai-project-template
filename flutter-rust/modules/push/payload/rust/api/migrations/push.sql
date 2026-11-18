-- Push module. Renamed to the next free migration number by apply.py.
-- One row per device. The token is the key, so a device that signs in as a
-- different user is re-assigned to them instead of notifying the old user.

CREATE TABLE push_tokens (
  token      TEXT PRIMARY KEY,
  uid        TEXT NOT NULL,                       -- Firebase uid, from the verified token
  platform   TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'macos', 'windows', 'web')),
  created_at INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at INTEGER NOT NULL DEFAULT (unixepoch())
);

-- Serves "tokens for this user", the per-user cap, and account deletion.
CREATE INDEX push_tokens_uid_updated ON push_tokens (uid, updated_at DESC, token DESC);
