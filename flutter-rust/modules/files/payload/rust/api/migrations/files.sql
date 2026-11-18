-- Files module. Renamed to the next free migration number by apply.py.
-- The row is the source of truth for ownership; the R2 object (same id as
-- its key) holds only the bytes.

CREATE TABLE files (
  id           TEXT PRIMARY KEY,                    -- 32 hex chars, also the R2 object key
  uid          TEXT NOT NULL,                       -- Firebase uid, from the verified token
  name         TEXT NOT NULL,                       -- cleaned display name
  content_type TEXT NOT NULL CHECK (content_type IN
    ('image/png', 'image/jpeg', 'image/gif', 'image/webp', 'application/pdf')),
  size         INTEGER NOT NULL CHECK (size > 0),
  created_at   INTEGER NOT NULL DEFAULT (unixepoch())
);

-- Serves the list query, the per-user quota count, and the account-deletion lookup.
CREATE INDEX files_uid_created ON files (uid, created_at DESC, id DESC);
