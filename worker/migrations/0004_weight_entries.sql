-- Weight history logged via the Coach addWeightEntry tool.
CREATE TABLE IF NOT EXISTS weight_entries (
  id TEXT PRIMARY KEY,
  firebase_uid TEXT NOT NULL REFERENCES users(firebase_uid),
  weight_kg REAL NOT NULL,
  recorded_at INTEGER NOT NULL,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_weight_entries_uid_recorded
  ON weight_entries (firebase_uid, recorded_at DESC);
