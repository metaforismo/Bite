-- V2 wave: hydration/caffeine, activity status, cycle, strength sessions,
-- bio-age cache, journal tags. All tables are user-scoped via firebase_uid.

CREATE TABLE IF NOT EXISTS drinks (
  id TEXT PRIMARY KEY,
  firebase_uid TEXT NOT NULL REFERENCES users(firebase_uid),
  kind TEXT NOT NULL,
  volume_ml REAL,
  caffeine_mg REAL,
  label TEXT,
  timestamp INTEGER NOT NULL,
  day_start INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_drinks_uid_day ON drinks (firebase_uid, day_start);

CREATE TABLE IF NOT EXISTS activity_status (
  id TEXT PRIMARY KEY,
  firebase_uid TEXT NOT NULL REFERENCES users(firebase_uid),
  kind TEXT NOT NULL,
  started_at INTEGER NOT NULL,
  note TEXT,
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_activity_status_uid_started ON activity_status (firebase_uid, started_at DESC);

CREATE TABLE IF NOT EXISTS cycle_entries (
  id TEXT PRIMARY KEY,
  firebase_uid TEXT NOT NULL REFERENCES users(firebase_uid),
  date INTEGER NOT NULL,
  flow_level INTEGER NOT NULL,
  symptoms_json TEXT NOT NULL DEFAULT '[]',
  source TEXT NOT NULL DEFAULT 'manual'
);
CREATE INDEX IF NOT EXISTS idx_cycle_entries_uid_date ON cycle_entries (firebase_uid, date);

CREATE TABLE IF NOT EXISTS strength_sessions (
  id TEXT PRIMARY KEY,
  firebase_uid TEXT NOT NULL REFERENCES users(firebase_uid),
  workout_artifact_id TEXT,
  title TEXT NOT NULL,
  started_at INTEGER NOT NULL,
  completed_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_strength_sessions_uid_started ON strength_sessions (firebase_uid, started_at DESC);

CREATE TABLE IF NOT EXISTS strength_sets (
  id TEXT PRIMARY KEY,
  firebase_uid TEXT NOT NULL REFERENCES users(firebase_uid),
  session_id TEXT NOT NULL REFERENCES strength_sessions(id),
  exercise_name TEXT NOT NULL,
  set_index INTEGER NOT NULL,
  weight_lb REAL NOT NULL DEFAULT 0,
  reps INTEGER NOT NULL DEFAULT 0,
  completed_at INTEGER
);
CREATE INDEX IF NOT EXISTS idx_strength_sets_session ON strength_sets (session_id);

CREATE TABLE IF NOT EXISTS bio_age_snapshots (
  id TEXT PRIMARY KEY,
  firebase_uid TEXT NOT NULL REFERENCES users(firebase_uid),
  computed_at INTEGER NOT NULL,
  chronological_age INTEGER NOT NULL,
  biological_age REAL NOT NULL,
  confidence REAL NOT NULL,
  breakdown_json TEXT NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_bio_age_snapshots_uid_computed ON bio_age_snapshots (firebase_uid, computed_at DESC);

CREATE TABLE IF NOT EXISTS journal_tags (
  id TEXT PRIMARY KEY,
  firebase_uid TEXT NOT NULL REFERENCES users(firebase_uid),
  entry_ref_id TEXT NOT NULL,
  entry_kind TEXT NOT NULL,
  tag TEXT NOT NULL,
  category TEXT NOT NULL,
  source TEXT NOT NULL DEFAULT 'auto',
  created_at INTEGER NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_journal_tags_uid_tag ON journal_tags (firebase_uid, tag);
CREATE INDEX IF NOT EXISTS idx_journal_tags_uid_entry ON journal_tags (firebase_uid, entry_ref_id);
