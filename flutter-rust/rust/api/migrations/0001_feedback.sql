-- Applied with: wrangler d1 migrations apply DB --local   (or --remote)
-- One migration per schema change. Never edit an applied migration — add a new one.

CREATE TABLE feedback (
  id          TEXT PRIMARY KEY DEFAULT (lower(hex(randomblob(16)))),
  uid         TEXT NOT NULL,                       -- Firebase uid, from the verified token
  category    TEXT NOT NULL CHECK (category IN ('bug', 'idea', 'praise', 'other')),
  body        TEXT NOT NULL,
  route       TEXT NOT NULL,
  app_version TEXT NOT NULL,
  platform    TEXT NOT NULL,
  created_at  INTEGER NOT NULL DEFAULT (unixepoch())  -- seconds since epoch, UTC
);

-- D1 bills by rows READ. Every query needs an index that matches its WHERE /
-- ORDER BY, or it scans (and bills) the whole table.
CREATE INDEX feedback_uid_created ON feedback (uid, created_at DESC);
CREATE INDEX feedback_created ON feedback (created_at DESC);
