-- One row per user. Created on the first PUT /v1/profile, removed by
-- DELETE /v1/account.

CREATE TABLE profiles (
  uid          TEXT PRIMARY KEY,                      -- Firebase uid, from the verified token
  display_name TEXT NOT NULL,
  created_at   INTEGER NOT NULL DEFAULT (unixepoch()),
  updated_at   INTEGER NOT NULL DEFAULT (unixepoch())
);
