PRAGMA foreign_keys = OFF;
BEGIN TRANSACTION;

CREATE TABLE users (
  user_id INTEGER PRIMARY KEY AUTOINCREMENT,
  email TEXT NOT NULL UNIQUE,
  password_hash TEXT NOT NULL,
  role TEXT NOT NULL CHECK (role IN ('student','lecturer','admin')),
  first_name TEXT NOT NULL,
  last_name TEXT NOT NULL,
  created_at TEXT NOT NULL DEFAULT (datetime('now'))
);

CREATE TABLE student_credentials (
  master_id INTEGER PRIMARY KEY AUTOINCREMENT,
  reg_number TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  current_level TEXT NOT NULL CHECK (current_level IN ('100','200','300','400','500')),
  entry_year INTEGER NOT NULL,
  is_registered INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE lecturer_credentials (
  master_id INTEGER PRIMARY KEY AUTOINCREMENT,
  staff_id TEXT NOT NULL UNIQUE,
  full_name TEXT NOT NULL,
  is_registered INTEGER NOT NULL DEFAULT 0,
  user_id INTEGER UNIQUE REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE student_profiles (
  student_id INTEGER PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
  master_record_id INTEGER NOT NULL UNIQUE REFERENCES student_credentials(master_id),
  department TEXT NOT NULL DEFAULT 'Computer and Robotics Education'
);

CREATE TABLE lecturer_profiles (
  lecturer_id INTEGER PRIMARY KEY REFERENCES users(user_id) ON DELETE CASCADE,
  master_record_id INTEGER NOT NULL UNIQUE REFERENCES lecturer_credentials(master_id),
  office_location TEXT,
  qualification TEXT
);

CREATE TABLE courses (
  course_id INTEGER PRIMARY KEY AUTOINCREMENT,
  course_code TEXT NOT NULL UNIQUE,
  title TEXT NOT NULL,
  unit INTEGER NOT NULL,
  coordinator_id INTEGER REFERENCES users(user_id),
  max_ca INTEGER NOT NULL DEFAULT 30,
  max_exam INTEGER NOT NULL DEFAULT 70
);

CREATE TABLE registrations (
  reg_id INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id INTEGER NOT NULL REFERENCES users(user_id),
  course_id INTEGER NOT NULL REFERENCES courses(course_id),
  session TEXT NOT NULL,
  semester TEXT NOT NULL CHECK (semester IN ('First','Second')),
  is_locked INTEGER NOT NULL DEFAULT 1,
  UNIQUE (student_id, course_id, session, semester)
);

CREATE TABLE results (
  result_id INTEGER PRIMARY KEY AUTOINCREMENT,
  registration_id INTEGER NOT NULL UNIQUE REFERENCES registrations(reg_id),
  ca_score INTEGER NOT NULL DEFAULT 0,
  exam_score INTEGER NOT NULL DEFAULT 0,
  score INTEGER NOT NULL,
  grade TEXT NOT NULL,
  uploaded_by INTEGER NOT NULL REFERENCES users(user_id),
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending','approved','rejected')),
  approval_date TEXT,
  admin_id INTEGER REFERENCES users(user_id) ON DELETE SET NULL
);

CREATE TABLE payment_details (
  detail_id INTEGER PRIMARY KEY AUTOINCREMENT,
  bank_name TEXT NOT NULL,
  account_name TEXT NOT NULL,
  account_number TEXT NOT NULL,
  fee REAL NOT NULL,
  is_active INTEGER NOT NULL DEFAULT 1
);

CREATE TABLE transcript_requests (
  request_id INTEGER PRIMARY KEY AUTOINCREMENT,
  student_id INTEGER NOT NULL REFERENCES users(user_id),
  request_date TEXT NOT NULL DEFAULT (datetime('now')),
  payment_receipt_url TEXT,
  status TEXT NOT NULL DEFAULT 'pending_payment' CHECK (status IN ('pending_payment','pending_admin_approval','approved','rejected')),
  admin_id INTEGER REFERENCES users(user_id)
);

COMMIT;
BEGIN TRANSACTION;

-- Demo password for all seeded accounts: Password123 (bcryptjs $2a$)
INSERT INTO users (user_id, email, password_hash, role, first_name, last_name) VALUES
(1, 'admin@cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'admin', 'System', 'Admin'),
(2, 'lecturer1@cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'lecturer', 'Ada', 'Okoro'),
(3, 'lecturer2@cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'lecturer', 'Emeka', 'Nwosu'),
(4, 'lecturer3@cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'lecturer', 'Fatima', 'Ibrahim'),
(5, 'lecturer4@cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'lecturer', 'Tunde', 'Adeyemi'),
(6, 'lecturer5@cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'lecturer', 'Ngozi', 'Eze'),
(7, 'student01@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Chidi', 'Okafor'),
(8, 'student02@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Amina', 'Bello'),
(9, 'student03@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Kelechi', 'Madu'),
(10, 'student04@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Yusuf', 'Garba'),
(11, 'student05@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Ifeoma', 'Ani'),
(12, 'student06@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Sule', 'Danjuma'),
(13, 'student07@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Blessing', 'Etim'),
(14, 'student08@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Hassan', 'Musa'),
(15, 'student09@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Nkechi', 'Obi'),
(16, 'student10@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Ibrahim', 'Lawal'),
(17, 'student11@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Chioma', 'Ude'),
(18, 'student12@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Peter', 'James'),
(19, 'student13@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Ruth', 'Bassey'),
(20, 'student14@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Samuel', 'John'),
(21, 'student15@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Grace', 'Effiong'),
(22, 'student16@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Uche', 'Nnamdi'),
(23, 'student17@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Zainab', 'Aliyu'),
(24, 'student18@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Victor', 'Ade'),
(25, 'student19@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Esther', 'George'),
(26, 'student20@student.cre.edu', '$2a$10$lHGQmizzMFACYbVhi1vysuXd1Q56nIEAMBcO4IKC8YehDJxWD4TDe', 'student', 'Daniel', 'Paul');
INSERT INTO lecturer_credentials (master_id, staff_id, full_name, is_registered, user_id) VALUES
(1, 'LECT001', 'Ada Okoro', 1, 2),
(2, 'LECT002', 'Emeka Nwosu', 1, 3),
(3, 'LECT003', 'Fatima Ibrahim', 1, 4),
(4, 'LECT004', 'Tunde Adeyemi', 1, 5),
(5, 'LECT005', 'Ngozi Eze', 1, 6);
INSERT INTO lecturer_profiles (lecturer_id, master_record_id, office_location, qualification) VALUES
(2, 1, 'Block A Room 12', 'PhD Education'),
(3, 2, 'Block A Room 14', 'M.Ed'),
(4, 3, 'Block B Room 3', 'PhD Robotics'),
(5, 4, 'Block B Room 5', 'M.Sc'),
(6, 5, 'Block C Room 1', 'PhD');
INSERT INTO student_credentials (master_id, reg_number, full_name, current_level, entry_year, is_registered) VALUES
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
INSERT INTO student_profiles (student_id, master_record_id) VALUES
(7, 1), (8, 2), (9, 3), (10, 4), (11, 5), (12, 6), (13, 7), (14, 8), (15, 9), (16, 10),
(17, 11), (18, 12), (19, 13), (20, 14), (21, 15), (22, 16), (23, 17), (24, 18), (25, 19), (26, 20);
INSERT INTO courses (course_id, course_code, title, unit, coordinator_id, max_ca, max_exam) VALUES
(1, 'CRE101', 'Introduction to CRE', 3, 2, 30, 70),
(2, 'CRE102', 'Educational Technology', 2, 3, 30, 70),
(3, 'CRE201', 'Robotics Fundamentals', 3, 4, 40, 60),
(4, 'CRE202', 'Digital Literacy', 2, 5, 30, 70),
(5, 'CRE301', 'Advanced Robotics', 3, 6, 30, 70),
(6, 'CRE302', 'Curriculum Design', 2, 2, 30, 70),
(7, 'CRE401', 'Project Seminar', 3, 3, 30, 70),
(8, 'CRE402', 'Teaching Practice', 2, 4, 30, 70);
INSERT INTO payment_details (detail_id, bank_name, account_name, account_number, fee, is_active) VALUES
(1, 'First National Bank', 'CRE School Fees Account', '1234567890', 5000.00, 1);
INSERT INTO registrations (student_id, course_id, session, semester) VALUES
(7,1,'2024/2025','First'),(7,2,'2024/2025','First'),(8,1,'2024/2025','First'),(8,2,'2024/2025','First'),(9,1,'2024/2025','First'),(9,2,'2024/2025','First'),(10,1,'2024/2025','First'),(10,2,'2024/2025','First'),(11,1,'2024/2025','First'),(11,2,'2024/2025','First'),(12,1,'2024/2025','First'),(12,2,'2024/2025','First'),(13,1,'2024/2025','First'),(13,2,'2024/2025','First'),(14,1,'2024/2025','First'),(14,2,'2024/2025','First'),(15,1,'2024/2025','First'),(15,2,'2024/2025','First'),(16,1,'2024/2025','First'),(16,2,'2024/2025','First'),(17,1,'2024/2025','First'),(17,2,'2024/2025','First'),(18,1,'2024/2025','First'),(18,2,'2024/2025','First'),(19,1,'2024/2025','First'),(19,2,'2024/2025','First'),(20,1,'2024/2025','First'),(20,2,'2024/2025','First'),(21,1,'2024/2025','First'),(21,2,'2024/2025','First'),(22,1,'2024/2025','First'),(22,2,'2024/2025','First'),(23,1,'2024/2025','First'),(23,2,'2024/2025','First'),(24,1,'2024/2025','First'),(24,2,'2024/2025','First'),(25,1,'2024/2025','First'),(25,2,'2024/2025','First'),(26,1,'2024/2025','First'),(26,2,'2024/2025','First'),
(7,5,'2024/2025','Second'),(7,6,'2024/2025','Second'),(8,5,'2024/2025','Second'),(8,6,'2024/2025','Second'),(9,5,'2024/2025','Second'),(9,6,'2024/2025','Second'),(10,5,'2024/2025','Second'),(10,6,'2024/2025','Second'),(11,5,'2024/2025','Second'),(11,6,'2024/2025','Second'),(12,5,'2024/2025','Second'),(12,6,'2024/2025','Second'),(13,5,'2024/2025','Second'),(13,6,'2024/2025','Second'),(14,5,'2024/2025','Second'),(14,6,'2024/2025','Second'),(15,5,'2024/2025','Second'),(15,6,'2024/2025','Second'),(16,5,'2024/2025','Second'),(16,6,'2024/2025','Second'),(17,5,'2024/2025','Second'),(17,6,'2024/2025','Second'),(18,5,'2024/2025','Second'),(18,6,'2024/2025','Second'),(19,5,'2024/2025','Second'),(19,6,'2024/2025','Second'),(20,5,'2024/2025','Second'),(20,6,'2024/2025','Second'),(21,5,'2024/2025','Second'),(21,6,'2024/2025','Second'),(22,5,'2024/2025','Second'),(22,6,'2024/2025','Second'),(23,5,'2024/2025','Second'),(23,6,'2024/2025','Second'),(24,5,'2024/2025','Second'),(24,6,'2024/2025','Second'),(25,5,'2024/2025','Second'),(25,6,'2024/2025','Second'),(26,5,'2024/2025','Second'),(26,6,'2024/2025','Second');
INSERT INTO results (registration_id, ca_score, exam_score, score, grade, uploaded_by, status, approval_date, admin_id) VALUES
(1,22,50,72,'A',2,'approved',datetime('now'),1),(2,20,48,68,'B',3,'approved',datetime('now'),1),(3,17,38,55,'C',2,'approved',datetime('now'),1),(4,14,34,48,'D',3,'approved',datetime('now'),1),(5,23,52,75,'A',2,'approved',datetime('now'),1),(6,25,57,82,'A',3,'approved',datetime('now'),1),(7,18,43,61,'B',2,'approved',datetime('now'),1),(8,17,41,58,'C',3,'approved',datetime('now'),1),(9,21,49,70,'A',2,'approved',datetime('now'),1),(10,20,46,66,'B',3,'approved',datetime('now'),1),(11,16,36,52,'C',2,'approved',datetime('now'),1),(12,13,31,44,'F',3,'approved',datetime('now'),1),(13,23,54,77,'A',2,'approved',datetime('now'),1),(14,19,44,63,'B',3,'approved',datetime('now'),1),(15,18,41,59,'C',2,'approved',datetime('now'),1),(16,21,50,71,'A',3,'approved',datetime('now'),1),(17,20,47,67,'B',2,'approved',datetime('now'),1),(18,16,38,54,'C',3,'approved',datetime('now'),1),(19,15,34,49,'D',2,'approved',datetime('now'),1),(20,22,51,73,'A',3,'approved',datetime('now'),1),
(21,20,46,66,'B',2,'pending',NULL,NULL),(22,20,47,67,'B',3,'pending',NULL,NULL),(23,20,48,68,'B',2,'pending',NULL,NULL),(24,21,48,69,'B',3,'pending',NULL,NULL),(25,21,49,70,'A',2,'pending',NULL,NULL),(26,21,50,71,'A',3,'pending',NULL,NULL),(27,22,50,72,'A',2,'pending',NULL,NULL),(28,22,51,73,'A',3,'pending',NULL,NULL),(29,22,52,74,'A',2,'pending',NULL,NULL),(30,18,42,60,'B',3,'pending',NULL,NULL),
(41,20,46,66,'B',6,'approved',datetime('now'),1),(42,20,47,67,'B',2,'approved',datetime('now'),1),(43,20,48,68,'B',6,'approved',datetime('now'),1),(44,21,48,69,'B',2,'approved',datetime('now'),1),(45,21,49,70,'A',6,'approved',datetime('now'),1),(46,21,50,71,'A',2,'approved',datetime('now'),1),(47,22,50,72,'A',6,'approved',datetime('now'),1),(48,22,51,73,'A',2,'approved',datetime('now'),1),(49,22,52,74,'A',6,'approved',datetime('now'),1),(50,23,52,75,'A',2,'approved',datetime('now'),1),(51,23,53,76,'A',6,'approved',datetime('now'),1),(52,23,54,77,'A',2,'approved',datetime('now'),1),(53,23,55,78,'A',6,'approved',datetime('now'),1),(54,24,55,79,'A',2,'approved',datetime('now'),1),(55,24,56,80,'A',6,'approved',datetime('now'),1);
COMMIT;
PRAGMA foreign_keys = ON;
