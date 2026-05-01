-- Migration 0002: add food_entries table; expand lab_reports + biomarkers
-- with extra columns the agent pipeline needs.
--
-- Apply via:
--   wrangler d1 migrations apply bite_db --local
--   wrangler d1 migrations apply bite_db --remote

-- ---------------------------------------------------------------------------
-- users: profile blob + last update timestamp
-- ---------------------------------------------------------------------------
ALTER TABLE `users` ADD COLUMN `profile_json` text;
ALTER TABLE `users` ADD COLUMN `profile_updated_at` integer;

-- ---------------------------------------------------------------------------
-- lab_reports: pipeline status + creation timestamp
-- ---------------------------------------------------------------------------
ALTER TABLE `lab_reports` ADD COLUMN `status` text NOT NULL DEFAULT 'pending';
ALTER TABLE `lab_reports` ADD COLUMN `error_message` text;
ALTER TABLE `lab_reports` ADD COLUMN `created_at` integer NOT NULL DEFAULT 0;

CREATE INDEX `lab_reports_status_idx` ON `lab_reports` (`status`);

-- ---------------------------------------------------------------------------
-- biomarkers: optional category column ("Lipids", "Inflammation", ...)
-- ---------------------------------------------------------------------------
ALTER TABLE `biomarkers` ADD COLUMN `category` text;

CREATE INDEX `biomarkers_category_idx` ON `biomarkers` (`category`);

-- ---------------------------------------------------------------------------
-- food_entries
-- ---------------------------------------------------------------------------
CREATE TABLE `food_entries` (
  `id` text PRIMARY KEY NOT NULL,
  `firebase_uid` text NOT NULL,
  `thread_id` text,
  `message_id` text,
  `text` text NOT NULL,
  `dish_name` text,
  `kcal` integer,
  `protein` real,
  `carbs` real,
  `fat` real,
  `fiber` real,
  `meal_label` text,
  `badge` text,
  `why_its_good` text,
  `portion_label` text,
  `photo_file_id` text,
  `correction_text` text,
  `day_start` integer NOT NULL,
  `created_at` integer NOT NULL,
  FOREIGN KEY (`firebase_uid`) REFERENCES `users`(`firebase_uid`) ON UPDATE no action ON DELETE no action
);

CREATE INDEX `food_entries_firebase_uid_idx` ON `food_entries` (`firebase_uid`);
CREATE INDEX `food_entries_day_start_idx` ON `food_entries` (`day_start`);
CREATE INDEX `food_entries_thread_id_idx` ON `food_entries` (`thread_id`);
CREATE INDEX `food_entries_created_at_idx` ON `food_entries` (`created_at`);
