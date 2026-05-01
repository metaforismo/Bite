-- Initial migration for Bite worker.
-- Mirrors src/db/schema.ts exactly. Apply via:
--   wrangler d1 migrations apply bite_db --local
--   wrangler d1 migrations apply bite_db --remote

CREATE TABLE `users` (
  `firebase_uid` text PRIMARY KEY NOT NULL,
  `email` text,
  `display_name` text,
  `created_at` integer NOT NULL
);

CREATE TABLE `threads` (
  `id` text PRIMARY KEY NOT NULL,
  `firebase_uid` text NOT NULL,
  `title` text NOT NULL,
  `pinned` integer NOT NULL DEFAULT 0,
  `last_message_at` integer NOT NULL,
  `created_at` integer NOT NULL,
  FOREIGN KEY (`firebase_uid`) REFERENCES `users`(`firebase_uid`) ON UPDATE no action ON DELETE no action
);

CREATE INDEX `threads_firebase_uid_idx` ON `threads` (`firebase_uid`);
CREATE INDEX `threads_last_message_at_idx` ON `threads` (`last_message_at`);

CREATE TABLE `messages` (
  `id` text PRIMARY KEY NOT NULL,
  `thread_id` text NOT NULL,
  `firebase_uid` text NOT NULL,
  `role` text NOT NULL,
  `text` text NOT NULL,
  `created_at` integer NOT NULL,
  FOREIGN KEY (`thread_id`) REFERENCES `threads`(`id`) ON UPDATE no action ON DELETE no action,
  FOREIGN KEY (`firebase_uid`) REFERENCES `users`(`firebase_uid`) ON UPDATE no action ON DELETE no action
);

CREATE INDEX `messages_thread_id_idx` ON `messages` (`thread_id`);
CREATE INDEX `messages_firebase_uid_idx` ON `messages` (`firebase_uid`);
CREATE INDEX `messages_created_at_idx` ON `messages` (`created_at`);

CREATE TABLE `artifacts` (
  `id` text PRIMARY KEY NOT NULL,
  `message_id` text NOT NULL,
  `firebase_uid` text NOT NULL,
  `type` text NOT NULL,
  `payload_json` text NOT NULL,
  `version` integer NOT NULL DEFAULT 1,
  `created_at` integer NOT NULL,
  FOREIGN KEY (`message_id`) REFERENCES `messages`(`id`) ON UPDATE no action ON DELETE no action,
  FOREIGN KEY (`firebase_uid`) REFERENCES `users`(`firebase_uid`) ON UPDATE no action ON DELETE no action
);

CREATE INDEX `artifacts_message_id_idx` ON `artifacts` (`message_id`);
CREATE INDEX `artifacts_firebase_uid_idx` ON `artifacts` (`firebase_uid`);

CREATE TABLE `memories` (
  `id` text PRIMARY KEY NOT NULL,
  `firebase_uid` text NOT NULL,
  `category` text NOT NULL,
  `text` text NOT NULL,
  `created_at` integer NOT NULL,
  `updated_at` integer NOT NULL,
  FOREIGN KEY (`firebase_uid`) REFERENCES `users`(`firebase_uid`) ON UPDATE no action ON DELETE no action
);

CREATE INDEX `memories_firebase_uid_idx` ON `memories` (`firebase_uid`);
CREATE INDEX `memories_category_idx` ON `memories` (`category`);

CREATE TABLE `plans` (
  `id` text PRIMARY KEY NOT NULL,
  `firebase_uid` text NOT NULL,
  `title` text NOT NULL,
  `goal` text NOT NULL,
  `weeks` integer NOT NULL,
  `payload_json` text NOT NULL,
  `created_at` integer NOT NULL,
  FOREIGN KEY (`firebase_uid`) REFERENCES `users`(`firebase_uid`) ON UPDATE no action ON DELETE no action
);

CREATE INDEX `plans_firebase_uid_idx` ON `plans` (`firebase_uid`);

CREATE TABLE `workouts` (
  `id` text PRIMARY KEY NOT NULL,
  `firebase_uid` text NOT NULL,
  `plan_id` text,
  `title` text NOT NULL,
  `scheduled_at` integer NOT NULL,
  `completed_at` integer,
  `payload_json` text NOT NULL,
  FOREIGN KEY (`firebase_uid`) REFERENCES `users`(`firebase_uid`) ON UPDATE no action ON DELETE no action,
  FOREIGN KEY (`plan_id`) REFERENCES `plans`(`id`) ON UPDATE no action ON DELETE no action
);

CREATE INDEX `workouts_firebase_uid_idx` ON `workouts` (`firebase_uid`);
CREATE INDEX `workouts_scheduled_at_idx` ON `workouts` (`scheduled_at`);

CREATE TABLE `lab_reports` (
  `id` text PRIMARY KEY NOT NULL,
  `firebase_uid` text NOT NULL,
  `file_id` text,
  `title` text NOT NULL,
  `taken_at` integer NOT NULL,
  `source_url` text,
  `confidence` real,
  FOREIGN KEY (`firebase_uid`) REFERENCES `users`(`firebase_uid`) ON UPDATE no action ON DELETE no action
);

CREATE INDEX `lab_reports_firebase_uid_idx` ON `lab_reports` (`firebase_uid`);
CREATE INDEX `lab_reports_taken_at_idx` ON `lab_reports` (`taken_at`);

CREATE TABLE `biomarkers` (
  `id` text PRIMARY KEY NOT NULL,
  `firebase_uid` text NOT NULL,
  `lab_report_id` text NOT NULL,
  `name` text NOT NULL,
  `value` real NOT NULL,
  `unit` text NOT NULL,
  `ref_low` real,
  `ref_high` real,
  `status` text,
  `taken_at` integer NOT NULL,
  FOREIGN KEY (`firebase_uid`) REFERENCES `users`(`firebase_uid`) ON UPDATE no action ON DELETE no action,
  FOREIGN KEY (`lab_report_id`) REFERENCES `lab_reports`(`id`) ON UPDATE no action ON DELETE no action
);

CREATE INDEX `biomarkers_firebase_uid_idx` ON `biomarkers` (`firebase_uid`);
CREATE INDEX `biomarkers_lab_report_id_idx` ON `biomarkers` (`lab_report_id`);
CREATE INDEX `biomarkers_name_idx` ON `biomarkers` (`name`);

CREATE TABLE `check_ins` (
  `id` text PRIMARY KEY NOT NULL,
  `firebase_uid` text NOT NULL,
  `prompt` text NOT NULL,
  `cadence` text NOT NULL,
  `next_fire_at` integer NOT NULL,
  FOREIGN KEY (`firebase_uid`) REFERENCES `users`(`firebase_uid`) ON UPDATE no action ON DELETE no action
);

CREATE INDEX `check_ins_firebase_uid_idx` ON `check_ins` (`firebase_uid`);
CREATE INDEX `check_ins_next_fire_at_idx` ON `check_ins` (`next_fire_at`);

CREATE TABLE `schedules` (
  `id` text PRIMARY KEY NOT NULL,
  `firebase_uid` text NOT NULL,
  `kind` text NOT NULL,
  `payload_json` text NOT NULL,
  `next_fire_at` integer NOT NULL,
  FOREIGN KEY (`firebase_uid`) REFERENCES `users`(`firebase_uid`) ON UPDATE no action ON DELETE no action
);

CREATE INDEX `schedules_firebase_uid_idx` ON `schedules` (`firebase_uid`);
CREATE INDEX `schedules_next_fire_at_idx` ON `schedules` (`next_fire_at`);

CREATE TABLE `files` (
  `id` text PRIMARY KEY NOT NULL,
  `firebase_uid` text NOT NULL,
  `r2_key` text NOT NULL,
  `mime_type` text NOT NULL,
  `size_bytes` integer NOT NULL,
  `uploaded_at` integer NOT NULL,
  FOREIGN KEY (`firebase_uid`) REFERENCES `users`(`firebase_uid`) ON UPDATE no action ON DELETE no action
);

CREATE INDEX `files_firebase_uid_idx` ON `files` (`firebase_uid`);

CREATE TABLE `tool_calls` (
  `id` text PRIMARY KEY NOT NULL,
  `firebase_uid` text NOT NULL,
  `thread_id` text,
  `tool` text NOT NULL,
  `args_json` text NOT NULL,
  `result_json` text NOT NULL,
  `latency_ms` integer NOT NULL,
  `created_at` integer NOT NULL,
  FOREIGN KEY (`firebase_uid`) REFERENCES `users`(`firebase_uid`) ON UPDATE no action ON DELETE no action,
  FOREIGN KEY (`thread_id`) REFERENCES `threads`(`id`) ON UPDATE no action ON DELETE no action
);

CREATE INDEX `tool_calls_firebase_uid_idx` ON `tool_calls` (`firebase_uid`);
CREATE INDEX `tool_calls_thread_id_idx` ON `tool_calls` (`thread_id`);
CREATE INDEX `tool_calls_created_at_idx` ON `tool_calls` (`created_at`);

CREATE TABLE `request_log` (
  `id` integer PRIMARY KEY AUTOINCREMENT NOT NULL,
  `firebase_uid` text,
  `path` text NOT NULL,
  `method` text NOT NULL,
  `status` integer NOT NULL,
  `latency_ms` integer NOT NULL,
  `created_at` integer NOT NULL
);

CREATE INDEX `request_log_firebase_uid_idx` ON `request_log` (`firebase_uid`);
CREATE INDEX `request_log_created_at_idx` ON `request_log` (`created_at`);
