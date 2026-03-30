-- Run once on existing result_archiving_db (before or after backup).
-- Adds CA/Exam columns and course max caps; backfills from total score.

USE `result_archiving_db`;

ALTER TABLE `courses`
  ADD COLUMN `max_ca` tinyint(3) UNSIGNED NOT NULL DEFAULT 30 COMMENT 'Max CA (sum with max_exam = 100)' AFTER `coordinator_id`,
  ADD COLUMN `max_exam` tinyint(3) UNSIGNED NOT NULL DEFAULT 70 AFTER `max_ca`;

ALTER TABLE `results`
  ADD COLUMN `ca_score` tinyint(3) UNSIGNED NOT NULL DEFAULT 0 AFTER `registration_id`,
  ADD COLUMN `exam_score` tinyint(3) UNSIGNED NOT NULL DEFAULT 0 AFTER `ca_score`;

-- Approximate split from existing total (30/70 weighting)
UPDATE `results`
SET
  `ca_score` = LEAST(ROUND(`score` * 0.30), 30),
  `exam_score` = `score` - LEAST(ROUND(`score` * 0.30), 30)
WHERE `ca_score` = 0 AND `exam_score` = 0;
