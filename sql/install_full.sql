-- CRE Result Archiving System — full schema + seed data
-- Semesters: First / Second. Run in phpMyAdmin or: mysql -u root < install_full.sql
-- Admin login unchanged: admin@cre.edu (existing password hash from project)

SET NAMES utf8mb4;
SET FOREIGN_KEY_CHECKS = 0;

DROP DATABASE IF EXISTS `result_archiving_db`;
CREATE DATABASE `result_archiving_db` CHARACTER SET utf8mb4 COLLATE utf8mb4_general_ci;
USE `result_archiving_db`;

-- ---------- Tables ----------
CREATE TABLE `users` (
  `user_id` int(11) NOT NULL AUTO_INCREMENT,
  `email` varchar(100) NOT NULL,
  `password_hash` varchar(255) NOT NULL,
  `role` enum('student','lecturer','admin') NOT NULL,
  `first_name` varchar(50) NOT NULL,
  `last_name` varchar(50) NOT NULL,
  `created_at` timestamp NOT NULL DEFAULT current_timestamp(),
  PRIMARY KEY (`user_id`),
  UNIQUE KEY `email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `student_credentials` (
  `master_id` int(11) NOT NULL AUTO_INCREMENT,
  `reg_number` varchar(15) NOT NULL,
  `full_name` varchar(100) NOT NULL,
  `current_level` enum('100','200','300','400','500') NOT NULL,
  `entry_year` year(4) NOT NULL,
  `is_registered` tinyint(1) DEFAULT 0,
  PRIMARY KEY (`master_id`),
  UNIQUE KEY `reg_number` (`reg_number`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `lecturer_credentials` (
  `master_id` int(11) NOT NULL AUTO_INCREMENT,
  `staff_id` varchar(15) NOT NULL,
  `full_name` varchar(100) NOT NULL,
  `is_registered` tinyint(1) DEFAULT 0,
  `user_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`master_id`),
  UNIQUE KEY `staff_id` (`staff_id`),
  UNIQUE KEY `user_id` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `student_profiles` (
  `student_id` int(11) NOT NULL,
  `master_record_id` int(11) NOT NULL,
  `department` varchar(50) NOT NULL DEFAULT 'Computer and Robotics Education',
  PRIMARY KEY (`student_id`),
  UNIQUE KEY `master_record_id` (`master_record_id`),
  CONSTRAINT `student_profiles_ibfk_1` FOREIGN KEY (`student_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `student_profiles_ibfk_2` FOREIGN KEY (`master_record_id`) REFERENCES `student_credentials` (`master_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `lecturer_profiles` (
  `lecturer_id` int(11) NOT NULL,
  `master_record_id` int(11) NOT NULL,
  `office_location` varchar(100) DEFAULT NULL,
  `qualification` varchar(50) DEFAULT NULL,
  PRIMARY KEY (`lecturer_id`),
  UNIQUE KEY `master_record_id` (`master_record_id`),
  CONSTRAINT `lecturer_profiles_ibfk_1` FOREIGN KEY (`lecturer_id`) REFERENCES `users` (`user_id`) ON DELETE CASCADE,
  CONSTRAINT `lecturer_profiles_ibfk_2` FOREIGN KEY (`master_record_id`) REFERENCES `lecturer_credentials` (`master_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `courses` (
  `course_id` int(11) NOT NULL AUTO_INCREMENT,
  `course_code` varchar(10) NOT NULL,
  `title` varchar(100) NOT NULL,
  `unit` tinyint(4) NOT NULL,
  `coordinator_id` int(11) DEFAULT NULL,
  `max_ca` tinyint(3) UNSIGNED NOT NULL DEFAULT 30 COMMENT 'Max CA mark (sum with max_exam should be 100)',
  `max_exam` tinyint(3) UNSIGNED NOT NULL DEFAULT 70 COMMENT 'Max exam mark',
  PRIMARY KEY (`course_id`),
  UNIQUE KEY `course_code` (`course_code`),
  KEY `coordinator_id` (`coordinator_id`),
  CONSTRAINT `courses_ibfk_1` FOREIGN KEY (`coordinator_id`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `registrations` (
  `reg_id` int(11) NOT NULL AUTO_INCREMENT,
  `student_id` int(11) NOT NULL,
  `course_id` int(11) NOT NULL,
  `session` varchar(10) NOT NULL,
  `semester` enum('First','Second') NOT NULL,
  `is_locked` tinyint(1) DEFAULT 1,
  PRIMARY KEY (`reg_id`),
  UNIQUE KEY `unique_registration` (`student_id`,`course_id`,`session`,`semester`),
  KEY `course_id` (`course_id`),
  CONSTRAINT `registrations_ibfk_1` FOREIGN KEY (`student_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `registrations_ibfk_2` FOREIGN KEY (`course_id`) REFERENCES `courses` (`course_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `results` (
  `result_id` int(11) NOT NULL AUTO_INCREMENT,
  `registration_id` int(11) NOT NULL,
  `ca_score` tinyint(3) UNSIGNED NOT NULL DEFAULT 0,
  `exam_score` tinyint(3) UNSIGNED NOT NULL DEFAULT 0,
  `score` tinyint(4) NOT NULL COMMENT 'Total = CA + Exam (0-100)',
  `grade` varchar(2) NOT NULL,
  `uploaded_by` int(11) NOT NULL,
  `status` enum('pending','approved','rejected') NOT NULL DEFAULT 'pending',
  `approval_date` timestamp NULL DEFAULT NULL,
  `admin_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`result_id`),
  UNIQUE KEY `registration_id` (`registration_id`),
  KEY `uploaded_by` (`uploaded_by`),
  KEY `admin_id` (`admin_id`),
  CONSTRAINT `results_ibfk_1` FOREIGN KEY (`registration_id`) REFERENCES `registrations` (`reg_id`),
  CONSTRAINT `results_ibfk_2` FOREIGN KEY (`uploaded_by`) REFERENCES `users` (`user_id`),
  CONSTRAINT `results_ibfk_3` FOREIGN KEY (`admin_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `payment_details` (
  `detail_id` int(11) NOT NULL AUTO_INCREMENT,
  `bank_name` varchar(100) NOT NULL,
  `account_name` varchar(100) NOT NULL,
  `account_number` varchar(20) NOT NULL,
  `fee` decimal(10,2) NOT NULL,
  `is_active` tinyint(1) DEFAULT 1,
  PRIMARY KEY (`detail_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

CREATE TABLE `transcript_requests` (
  `request_id` int(11) NOT NULL AUTO_INCREMENT,
  `student_id` int(11) NOT NULL,
  `request_date` timestamp NOT NULL DEFAULT current_timestamp(),
  `payment_receipt_url` varchar(255) DEFAULT NULL,
  `status` enum('pending_payment','pending_admin_approval','approved','rejected') NOT NULL DEFAULT 'pending_payment',
  `admin_id` int(11) DEFAULT NULL,
  PRIMARY KEY (`request_id`),
  KEY `student_id` (`student_id`),
  KEY `admin_id` (`admin_id`),
  CONSTRAINT `transcript_requests_ibfk_1` FOREIGN KEY (`student_id`) REFERENCES `users` (`user_id`),
  CONSTRAINT `transcript_requests_ibfk_2` FOREIGN KEY (`admin_id`) REFERENCES `users` (`user_id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_general_ci;

ALTER TABLE `lecturer_credentials`
  ADD CONSTRAINT `lecturer_credentials_ibfk_1` FOREIGN KEY (`user_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL;

-- ---------- Seed: passwords ----------
-- Admin: original project hash (password unchanged from your dump).
-- All demo lecturers & students: password DemoPass2025!

-- ---------- Users ----------
INSERT INTO `users` (`user_id`, `email`, `password_hash`, `role`, `first_name`, `last_name`) VALUES
(1, 'admin@cre.edu', '$2y$10$Eta19CnuFsXCybAXL07yieT7pPNshsSelXJsk/vGYvfOsZSDJ8fim', 'admin', 'System', 'Admin'),
(2, 'lecturer1@cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'lecturer', 'Ada', 'Okoro'),
(3, 'lecturer2@cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'lecturer', 'Emeka', 'Nwosu'),
(4, 'lecturer3@cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'lecturer', 'Fatima', 'Ibrahim'),
(5, 'lecturer4@cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'lecturer', 'Tunde', 'Adeyemi'),
(6, 'lecturer5@cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'lecturer', 'Ngozi', 'Eze'),
(7, 'student01@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Chidi', 'Okafor'),
(8, 'student02@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Amina', 'Bello'),
(9, 'student03@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Kelechi', 'Madu'),
(10, 'student04@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Yusuf', 'Garba'),
(11, 'student05@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Ifeoma', 'Ani'),
(12, 'student06@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Sule', 'Danjuma'),
(13, 'student07@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Blessing', 'Etim'),
(14, 'student08@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Hassan', 'Musa'),
(15, 'student09@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Nkechi', 'Obi'),
(16, 'student10@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Ibrahim', 'Lawal'),
(17, 'student11@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Chioma', 'Ude'),
(18, 'student12@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Peter', 'James'),
(19, 'student13@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Ruth', 'Bassey'),
(20, 'student14@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Samuel', 'John'),
(21, 'student15@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Grace', 'Effiong'),
(22, 'student16@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Uche', 'Nnamdi'),
(23, 'student17@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Zainab', 'Aliyu'),
(24, 'student18@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Victor', 'Ade'),
(25, 'student19@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Esther', 'George'),
(26, 'student20@student.cre.edu', '$2y$10$bIgv4V3wWpZgkm1zrkEgKeFHF3acMzBSc5KRagCZiDZkDDLzlAe9e', 'student', 'Daniel', 'Paul');

-- Lecturer master + profiles
INSERT INTO `lecturer_credentials` (`master_id`, `staff_id`, `full_name`, `is_registered`, `user_id`) VALUES
(1, 'LECT001', 'Ada Okoro', 1, 2),
(2, 'LECT002', 'Emeka Nwosu', 1, 3),
(3, 'LECT003', 'Fatima Ibrahim', 1, 4),
(4, 'LECT004', 'Tunde Adeyemi', 1, 5),
(5, 'LECT005', 'Ngozi Eze', 1, 6);

INSERT INTO `lecturer_profiles` (`lecturer_id`, `master_record_id`, `office_location`, `qualification`) VALUES
(2, 1, 'Block A Room 12', 'PhD Education'),
(3, 2, 'Block A Room 14', 'M.Ed'),
(4, 3, 'Block B Room 3', 'PhD Robotics'),
(5, 4, 'Block B Room 5', 'M.Sc'),
(6, 5, 'Block C Room 1', 'PhD');

-- Student master + profiles (reg numbers CRE/2024/001 .. 020)
INSERT INTO `student_credentials` (`master_id`, `reg_number`, `full_name`, `current_level`, `entry_year`, `is_registered`) VALUES
(1, 'CRE/2024/001', 'Chidi Okafor', '200', 2024, 1),
(2, 'CRE/2024/002', 'Amina Bello', '200', 2024, 1),
(3, 'CRE/2024/003', 'Kelechi Madu', '200', 2024, 1),
(4, 'CRE/2024/004', 'Yusuf Garba', '200', 2024, 1),
(5, 'CRE/2024/005', 'Ifeoma Ani', '200', 2024, 1),
(6, 'CRE/2024/006', 'Sule Danjuma', '200', 2024, 1),
(7, 'CRE/2024/007', 'Blessing Etim', '200', 2024, 1),
(8, 'CRE/2024/008', 'Hassan Musa', '200', 2024, 1),
(9, 'CRE/2024/009', 'Nkechi Obi', '200', 2024, 1),
(10, 'CRE/2024/010', 'Ibrahim Lawal', '200', 2024, 1),
(11, 'CRE/2024/011', 'Chioma Ude', '200', 2024, 1),
(12, 'CRE/2024/012', 'Peter James', '200', 2024, 1),
(13, 'CRE/2024/013', 'Ruth Bassey', '200', 2024, 1),
(14, 'CRE/2024/014', 'Samuel John', '200', 2024, 1),
(15, 'CRE/2024/015', 'Grace Effiong', '200', 2024, 1),
(16, 'CRE/2024/016', 'Uche Nnamdi', '200', 2024, 1),
(17, 'CRE/2024/017', 'Zainab Aliyu', '200', 2024, 1),
(18, 'CRE/2024/018', 'Victor Ade', '200', 2024, 1),
(19, 'CRE/2024/019', 'Esther George', '200', 2024, 1),
(20, 'CRE/2024/020', 'Daniel Paul', '200', 2024, 1);

INSERT INTO `student_profiles` (`student_id`, `master_record_id`) VALUES
(7, 1), (8, 2), (9, 3), (10, 4), (11, 5), (12, 6), (13, 7), (14, 8), (15, 9), (16, 10),
(17, 11), (18, 12), (19, 13), (20, 14), (21, 15), (22, 16), (23, 17), (24, 18), (25, 19), (26, 20);

-- Courses (each coordinated by one of the five lecturers)
INSERT INTO `courses` (`course_id`, `course_code`, `title`, `unit`, `coordinator_id`, `max_ca`, `max_exam`) VALUES
(1, 'CRE101', 'Introduction to CRE', 3, 2, 30, 70),
(2, 'CRE102', 'Educational Technology', 2, 3, 30, 70),
(3, 'CRE201', 'Robotics Fundamentals', 3, 4, 40, 60),
(4, 'CRE202', 'Digital Literacy', 2, 5, 30, 70),
(5, 'CRE301', 'Advanced Robotics', 3, 6, 30, 70),
(6, 'CRE302', 'Curriculum Design', 2, 2, 30, 70),
(7, 'CRE401', 'Project Seminar', 3, 3, 30, 70),
(8, 'CRE402', 'Teaching Practice', 2, 4, 30, 70);

INSERT INTO `payment_details` (`detail_id`, `bank_name`, `account_name`, `account_number`, `fee`, `is_active`) VALUES
(1, 'First National Bank', 'CRE School Fees Account', '1234567890', 5000.00, 1);

-- Registrations: 20 students × courses (1,2) First; same 20 × (5,6) Second; session 2024/2025
INSERT INTO `registrations` (`student_id`, `course_id`, `session`, `semester`) VALUES
(7,1,'2024/2025','First'),(7,2,'2024/2025','First'),(8,1,'2024/2025','First'),(8,2,'2024/2025','First'),(9,1,'2024/2025','First'),(9,2,'2024/2025','First'),(10,1,'2024/2025','First'),(10,2,'2024/2025','First'),(11,1,'2024/2025','First'),(11,2,'2024/2025','First'),(12,1,'2024/2025','First'),(12,2,'2024/2025','First'),(13,1,'2024/2025','First'),(13,2,'2024/2025','First'),(14,1,'2024/2025','First'),(14,2,'2024/2025','First'),(15,1,'2024/2025','First'),(15,2,'2024/2025','First'),(16,1,'2024/2025','First'),(16,2,'2024/2025','First'),(17,1,'2024/2025','First'),(17,2,'2024/2025','First'),(18,1,'2024/2025','First'),(18,2,'2024/2025','First'),(19,1,'2024/2025','First'),(19,2,'2024/2025','First'),(20,1,'2024/2025','First'),(20,2,'2024/2025','First'),(21,1,'2024/2025','First'),(21,2,'2024/2025','First'),(22,1,'2024/2025','First'),(22,2,'2024/2025','First'),(23,1,'2024/2025','First'),(23,2,'2024/2025','First'),(24,1,'2024/2025','First'),(24,2,'2024/2025','First'),(25,1,'2024/2025','First'),(25,2,'2024/2025','First'),(26,1,'2024/2025','First'),(26,2,'2024/2025','First'),
(7,5,'2024/2025','Second'),(7,6,'2024/2025','Second'),(8,5,'2024/2025','Second'),(8,6,'2024/2025','Second'),(9,5,'2024/2025','Second'),(9,6,'2024/2025','Second'),(10,5,'2024/2025','Second'),(10,6,'2024/2025','Second'),(11,5,'2024/2025','Second'),(11,6,'2024/2025','Second'),(12,5,'2024/2025','Second'),(12,6,'2024/2025','Second'),(13,5,'2024/2025','Second'),(13,6,'2024/2025','Second'),(14,5,'2024/2025','Second'),(14,6,'2024/2025','Second'),(15,5,'2024/2025','Second'),(15,6,'2024/2025','Second'),(16,5,'2024/2025','Second'),(16,6,'2024/2025','Second'),(17,5,'2024/2025','Second'),(17,6,'2024/2025','Second'),(18,5,'2024/2025','Second'),(18,6,'2024/2025','Second'),(19,5,'2024/2025','Second'),(19,6,'2024/2025','Second'),(20,5,'2024/2025','Second'),(20,6,'2024/2025','Second'),(21,5,'2024/2025','Second'),(21,6,'2024/2025','Second'),(22,5,'2024/2025','Second'),(22,6,'2024/2025','Second'),(23,5,'2024/2025','Second'),(23,6,'2024/2025','Second'),(24,5,'2024/2025','Second'),(24,6,'2024/2025','Second'),(25,5,'2024/2025','Second'),(25,6,'2024/2025','Second'),(26,5,'2024/2025','Second'),(26,6,'2024/2025','Second');

-- Results (ca_score + exam_score = score; grades unchanged)
INSERT INTO `results` (`registration_id`, `ca_score`, `exam_score`, `score`, `grade`, `uploaded_by`, `status`, `approval_date`, `admin_id`) VALUES
(1,22,50,72,'A',2,'approved',NOW(),1),(2,20,48,68,'B',3,'approved',NOW(),1),(3,17,38,55,'C',2,'approved',NOW(),1),(4,14,34,48,'D',3,'approved',NOW(),1),(5,23,52,75,'A',2,'approved',NOW(),1),(6,25,57,82,'A',3,'approved',NOW(),1),(7,18,43,61,'B',2,'approved',NOW(),1),(8,17,41,58,'C',3,'approved',NOW(),1),(9,21,49,70,'A',2,'approved',NOW(),1),(10,20,46,66,'B',3,'approved',NOW(),1),(11,16,36,52,'C',2,'approved',NOW(),1),(12,13,31,44,'F',3,'approved',NOW(),1),(13,23,54,77,'A',2,'approved',NOW(),1),(14,19,44,63,'B',3,'approved',NOW(),1),(15,18,41,59,'C',2,'approved',NOW(),1),(16,21,50,71,'A',3,'approved',NOW(),1),(17,20,47,67,'B',2,'approved',NOW(),1),(18,16,38,54,'C',3,'approved',NOW(),1),(19,15,34,49,'D',2,'approved',NOW(),1),(20,22,51,73,'A',3,'approved',NOW(),1),
(21,20,46,66,'B',2,'pending',NULL,NULL),(22,20,47,67,'B',3,'pending',NULL,NULL),(23,20,48,68,'B',2,'pending',NULL,NULL),(24,21,48,69,'B',3,'pending',NULL,NULL),(25,21,49,70,'A',2,'pending',NULL,NULL),(26,21,50,71,'A',3,'pending',NULL,NULL),(27,22,50,72,'A',2,'pending',NULL,NULL),(28,22,51,73,'A',3,'pending',NULL,NULL),(29,22,52,74,'A',2,'pending',NULL,NULL),(30,18,42,60,'B',3,'pending',NULL,NULL),
(41,20,46,66,'B',6,'approved',NOW(),1),(42,20,47,67,'B',2,'approved',NOW(),1),(43,20,48,68,'B',6,'approved',NOW(),1),(44,21,48,69,'B',2,'approved',NOW(),1),(45,21,49,70,'A',6,'approved',NOW(),1),(46,21,50,71,'A',2,'approved',NOW(),1),(47,22,50,72,'A',6,'approved',NOW(),1),(48,22,51,73,'A',2,'approved',NOW(),1),(49,22,52,74,'A',6,'approved',NOW(),1),(50,23,52,75,'A',2,'approved',NOW(),1),(51,23,53,76,'A',6,'approved',NOW(),1),(52,23,54,77,'A',2,'approved',NOW(),1),(53,23,55,78,'A',6,'approved',NOW(),1),(54,24,55,79,'A',2,'approved',NOW(),1),(55,24,56,80,'A',6,'approved',NOW(),1);

SET FOREIGN_KEY_CHECKS = 1;
