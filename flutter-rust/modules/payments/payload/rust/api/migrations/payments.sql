-- Payments module. Renamed to the next free migration number by apply.py.

-- One row per (user, entitlement). `expires_at` NULL = never expires.
-- "Active" is NOT stored: it is computed from expires_at when read, so an
-- expiry takes effect even if its webhook is late or lost.
CREATE TABLE entitlements (
  uid        TEXT NOT NULL,                       -- Firebase uid (= the RevenueCat app user id)
  name       TEXT NOT NULL,                       -- e.g. 'pro'
  expires_at INTEGER,                             -- seconds since epoch, UTC
  product    TEXT,
  store      TEXT,
  updated_at INTEGER NOT NULL DEFAULT (unixepoch()),
  PRIMARY KEY (uid, name)
);

-- When we last asked RevenueCat about this user (throttles the refresh route).
CREATE TABLE customers (
  uid       TEXT PRIMARY KEY,
  synced_at INTEGER NOT NULL
);
