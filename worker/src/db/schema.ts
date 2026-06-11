import { sqliteTable, text, integer, real, primaryKey } from "drizzle-orm/sqlite-core";

/**
 * Bite D1 schema.
 *
 * Conventions:
 * - `firebase_uid` is the source of truth for user identity (verified by the
 *   Firebase JWT middleware) and appears on every user-scoped table.
 * - All ids are server-generated UUIDs (text), except `request_log` which uses
 *   an autoincrement integer for high-throughput append-only logging.
 * - Timestamps are stored as Unix epoch milliseconds (integer) for simple
 *   sorting and JSON serialization.
 * - Free-form structured data is stored as JSON text in `*JSON` columns.
 */

// ---------------------------------------------------------------------------
// users
// ---------------------------------------------------------------------------
export const users = sqliteTable("users", {
  firebaseUid: text("firebase_uid").primaryKey(),
  email: text("email"),
  displayName: text("display_name"),
  createdAt: integer("created_at", { mode: "number" }).notNull(),
  // Optional profile fields. The iOS app is the canonical source for these —
  // the worker uses them as context for tools (`getProfile`).
  // Stored as a JSON blob to avoid an avalanche of nullable columns.
  profileJSON: text("profile_json"),
  profileUpdatedAt: integer("profile_updated_at", { mode: "number" }),
});

// ---------------------------------------------------------------------------
// threads
// ---------------------------------------------------------------------------
export const threads = sqliteTable("threads", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  title: text("title").notNull(),
  pinned: integer("pinned", { mode: "boolean" }).notNull().default(false),
  lastMessageAt: integer("last_message_at", { mode: "number" }).notNull(),
  createdAt: integer("created_at", { mode: "number" }).notNull(),
});

// ---------------------------------------------------------------------------
// messages
// ---------------------------------------------------------------------------
export const messages = sqliteTable("messages", {
  id: text("id").primaryKey(),
  threadId: text("thread_id")
    .notNull()
    .references(() => threads.id),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  // role: 'user' | 'assistant' | 'system' | 'tool'
  role: text("role").notNull(),
  text: text("text").notNull(),
  createdAt: integer("created_at", { mode: "number" }).notNull(),
});

// ---------------------------------------------------------------------------
// artifacts
// ---------------------------------------------------------------------------
export const artifacts = sqliteTable("artifacts", {
  id: text("id").primaryKey(),
  messageId: text("message_id")
    .notNull()
    .references(() => messages.id),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  type: text("type").notNull(),
  payloadJSON: text("payload_json").notNull(),
  version: integer("version").notNull().default(1),
  createdAt: integer("created_at", { mode: "number" }).notNull(),
});

// ---------------------------------------------------------------------------
// memories
// ---------------------------------------------------------------------------
export const memories = sqliteTable("memories", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  category: text("category").notNull(),
  text: text("text").notNull(),
  createdAt: integer("created_at", { mode: "number" }).notNull(),
  updatedAt: integer("updated_at", { mode: "number" }).notNull(),
});

// ---------------------------------------------------------------------------
// plans
// ---------------------------------------------------------------------------
export const plans = sqliteTable("plans", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  title: text("title").notNull(),
  goal: text("goal").notNull(),
  weeks: integer("weeks").notNull(),
  payloadJSON: text("payload_json").notNull(),
  createdAt: integer("created_at", { mode: "number" }).notNull(),
});

// ---------------------------------------------------------------------------
// workouts
// ---------------------------------------------------------------------------
export const workouts = sqliteTable("workouts", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  planId: text("plan_id").references(() => plans.id),
  title: text("title").notNull(),
  scheduledAt: integer("scheduled_at", { mode: "number" }).notNull(),
  completedAt: integer("completed_at", { mode: "number" }),
  payloadJSON: text("payload_json").notNull(),
});

// ---------------------------------------------------------------------------
// lab_reports
// ---------------------------------------------------------------------------
export const labReports = sqliteTable("lab_reports", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  fileId: text("file_id"),
  title: text("title").notNull(),
  takenAt: integer("taken_at", { mode: "number" }).notNull(),
  sourceUrl: text("source_url"),
  confidence: real("confidence"),
  // Pipeline status: 'pending' | 'extracting' | 'parsing' | 'ready' | 'failed'
  status: text("status").notNull().default("pending"),
  errorMessage: text("error_message"),
  createdAt: integer("created_at", { mode: "number" }).notNull().default(0),
});

// ---------------------------------------------------------------------------
// biomarkers
// ---------------------------------------------------------------------------
export const biomarkers = sqliteTable("biomarkers", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  labReportId: text("lab_report_id")
    .notNull()
    .references(() => labReports.id),
  name: text("name").notNull(),
  // Optional human-readable group: 'Lipids' | 'Inflammation' | 'Metabolic' | ...
  category: text("category"),
  value: real("value").notNull(),
  unit: text("unit").notNull(),
  refLow: real("ref_low"),
  refHigh: real("ref_high"),
  status: text("status"),
  takenAt: integer("taken_at", { mode: "number" }).notNull(),
});

// ---------------------------------------------------------------------------
// check_ins
// ---------------------------------------------------------------------------
export const checkIns = sqliteTable("check_ins", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  prompt: text("prompt").notNull(),
  cadence: text("cadence").notNull(),
  nextFireAt: integer("next_fire_at", { mode: "number" }).notNull(),
});

// ---------------------------------------------------------------------------
// schedules
// ---------------------------------------------------------------------------
export const schedules = sqliteTable("schedules", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  kind: text("kind").notNull(),
  payloadJSON: text("payload_json").notNull(),
  nextFireAt: integer("next_fire_at", { mode: "number" }).notNull(),
});

// ---------------------------------------------------------------------------
// files
// ---------------------------------------------------------------------------
export const files = sqliteTable("files", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  r2Key: text("r2_key").notNull(),
  mimeType: text("mime_type").notNull(),
  sizeBytes: integer("size_bytes").notNull(),
  uploadedAt: integer("uploaded_at", { mode: "number" }).notNull(),
});

// ---------------------------------------------------------------------------
// food_entries
// ---------------------------------------------------------------------------
export const foodEntries = sqliteTable("food_entries", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  // Source thread/message that produced this entry, when applicable.
  threadId: text("thread_id"),
  messageId: text("message_id"),
  // Free-form user text describing the meal (e.g. "two eggs + toast").
  text: text("text").notNull(),
  // LLM-extracted dish name ("Avocado toast w/ eggs").
  dishName: text("dish_name"),
  // Macros — kcal as integer, grams as real.
  kcal: integer("kcal"),
  protein: real("protein"),
  carbs: real("carbs"),
  fat: real("fat"),
  fiber: real("fiber"),
  // Categorical labels used by the food_cart artifact.
  mealLabel: text("meal_label"), // 'breakfast' | 'lunch' | 'dinner' | 'snack'
  badge: text("badge"), // short tag, e.g. "high-protein"
  whyItsGood: text("why_its_good"),
  portionLabel: text("portion_label"),
  photoFileId: text("photo_file_id"),
  correctionText: text("correction_text"),
  // Day truncation for fast range queries — UTC midnight ms of the entry day.
  dayStart: integer("day_start", { mode: "number" }).notNull(),
  createdAt: integer("created_at", { mode: "number" }).notNull(),
});

// ---------------------------------------------------------------------------
// drinks (V2 — hydration + caffeine)
// ---------------------------------------------------------------------------
export const drinks = sqliteTable("drinks", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  // 'water' | 'caffeine'
  kind: text("kind").notNull(),
  volumeMl: real("volume_ml"),
  caffeineMg: real("caffeine_mg"),
  label: text("label"),
  timestamp: integer("timestamp", { mode: "number" }).notNull(),
  dayStart: integer("day_start", { mode: "number" }).notNull(),
});

// ---------------------------------------------------------------------------
// activity_status (V2 — Active / Sick / Injured / On Break, append-only)
// ---------------------------------------------------------------------------
export const activityStatus = sqliteTable("activity_status", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  // 'active' | 'sick' | 'injured' | 'on_break'
  kind: text("kind").notNull(),
  startedAt: integer("started_at", { mode: "number" }).notNull(),
  note: text("note"),
  createdAt: integer("created_at", { mode: "number" }).notNull(),
});

// ---------------------------------------------------------------------------
// cycle_entries (V2 — menstrual cycle tracking)
// ---------------------------------------------------------------------------
export const cycleEntries = sqliteTable("cycle_entries", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  // UTC midnight ms of the entry day; one (uid, date, source) combination.
  date: integer("date", { mode: "number" }).notNull(),
  // 0 none / 1 light / 2 medium / 3 heavy
  flowLevel: integer("flow_level").notNull(),
  symptomsJSON: text("symptoms_json").notNull().default("[]"),
  // 'manual' | 'healthkit'
  source: text("source").notNull().default("manual"),
});

// ---------------------------------------------------------------------------
// strength_sessions + strength_sets (V2 — workout tracker)
// ---------------------------------------------------------------------------
export const strengthSessions = sqliteTable("strength_sessions", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  workoutArtifactId: text("workout_artifact_id"),
  title: text("title").notNull(),
  startedAt: integer("started_at", { mode: "number" }).notNull(),
  completedAt: integer("completed_at", { mode: "number" }),
});

export const strengthSets = sqliteTable("strength_sets", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  sessionId: text("session_id")
    .notNull()
    .references(() => strengthSessions.id),
  exerciseName: text("exercise_name").notNull(),
  setIndex: integer("set_index").notNull(),
  weightLb: real("weight_lb").notNull().default(0),
  reps: integer("reps").notNull().default(0),
  completedAt: integer("completed_at", { mode: "number" }),
});

// ---------------------------------------------------------------------------
// bio_age_snapshots (V2 — Biological Age cache)
// ---------------------------------------------------------------------------
export const bioAgeSnapshots = sqliteTable("bio_age_snapshots", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  computedAt: integer("computed_at", { mode: "number" }).notNull(),
  chronologicalAge: integer("chronological_age").notNull(),
  biologicalAge: real("biological_age").notNull(),
  confidence: real("confidence").notNull(),
  breakdownJSON: text("breakdown_json").notNull(),
});

// ---------------------------------------------------------------------------
// journal_tags (V2 — habit-impact correlation source data)
// ---------------------------------------------------------------------------
export const journalTags = sqliteTable("journal_tags", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  entryRefId: text("entry_ref_id").notNull(),
  // 'food' | 'weight' | 'manual'
  entryKind: text("entry_kind").notNull(),
  tag: text("tag").notNull(),
  // 'lifestyle' | 'medical' | 'health_status' | 'supplements'
  category: text("category").notNull(),
  // 'auto' | 'manual'
  source: text("source").notNull().default("auto"),
  createdAt: integer("created_at", { mode: "number" }).notNull(),
});

// ---------------------------------------------------------------------------
// weight_entries
// ---------------------------------------------------------------------------
export const weightEntries = sqliteTable("weight_entries", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  weightKg: real("weight_kg").notNull(),
  recordedAt: integer("recorded_at", { mode: "number" }).notNull(),
  createdAt: integer("created_at", { mode: "number" }).notNull(),
});

// ---------------------------------------------------------------------------
// tool_calls
// ---------------------------------------------------------------------------
export const toolCalls = sqliteTable("tool_calls", {
  id: text("id").primaryKey(),
  firebaseUid: text("firebase_uid")
    .notNull()
    .references(() => users.firebaseUid),
  threadId: text("thread_id").references(() => threads.id),
  tool: text("tool").notNull(),
  argsJSON: text("args_json").notNull(),
  resultJSON: text("result_json").notNull(),
  latencyMs: integer("latency_ms").notNull(),
  createdAt: integer("created_at", { mode: "number" }).notNull(),
});

// ---------------------------------------------------------------------------
// request_log
// ---------------------------------------------------------------------------
export const requestLog = sqliteTable("request_log", {
  id: integer("id").primaryKey({ autoIncrement: true }),
  firebaseUid: text("firebase_uid"),
  path: text("path").notNull(),
  method: text("method").notNull(),
  status: integer("status").notNull(),
  latencyMs: integer("latency_ms").notNull(),
  createdAt: integer("created_at", { mode: "number" }).notNull(),
});

// Type exports for application use.
export type User = typeof users.$inferSelect;
export type NewUser = typeof users.$inferInsert;
export type Thread = typeof threads.$inferSelect;
export type NewThread = typeof threads.$inferInsert;
export type Message = typeof messages.$inferSelect;
export type NewMessage = typeof messages.$inferInsert;
export type Artifact = typeof artifacts.$inferSelect;
export type Memory = typeof memories.$inferSelect;
export type Plan = typeof plans.$inferSelect;
export type Workout = typeof workouts.$inferSelect;
export type Biomarker = typeof biomarkers.$inferSelect;
export type LabReport = typeof labReports.$inferSelect;
export type CheckIn = typeof checkIns.$inferSelect;
export type Schedule = typeof schedules.$inferSelect;
export type FileRow = typeof files.$inferSelect;
export type ToolCall = typeof toolCalls.$inferSelect;
export type RequestLog = typeof requestLog.$inferSelect;
export type FoodEntry = typeof foodEntries.$inferSelect;
export type NewFoodEntry = typeof foodEntries.$inferInsert;
export type Drink = typeof drinks.$inferSelect;
export type NewDrink = typeof drinks.$inferInsert;
export type ActivityStatus = typeof activityStatus.$inferSelect;
export type NewActivityStatus = typeof activityStatus.$inferInsert;
export type CycleEntry = typeof cycleEntries.$inferSelect;
export type NewCycleEntry = typeof cycleEntries.$inferInsert;
export type StrengthSession = typeof strengthSessions.$inferSelect;
export type NewStrengthSession = typeof strengthSessions.$inferInsert;
export type StrengthSet = typeof strengthSets.$inferSelect;
export type NewStrengthSet = typeof strengthSets.$inferInsert;
export type BioAgeSnapshot = typeof bioAgeSnapshots.$inferSelect;
export type NewBioAgeSnapshot = typeof bioAgeSnapshots.$inferInsert;
export type JournalTag = typeof journalTags.$inferSelect;
export type NewJournalTag = typeof journalTags.$inferInsert;

// Convenience export of all tables in one object so query code can do:
//   import * as schema from "./db/schema";
//   drizzle(env.DB, { schema });
export const tables = {
  users,
  threads,
  messages,
  artifacts,
  memories,
  plans,
  workouts,
  biomarkers,
  labReports,
  checkIns,
  schedules,
  files,
  toolCalls,
  requestLog,
  foodEntries,
  drinks,
  activityStatus,
  cycleEntries,
  strengthSessions,
  strengthSets,
  bioAgeSnapshots,
  journalTags,
};

// Allowed message roles. Kept here so application code can reference them
// without re-declaring the union.
export const MESSAGE_ROLES = ["user", "assistant", "system", "tool"] as const;
export type MessageRole = (typeof MESSAGE_ROLES)[number];
