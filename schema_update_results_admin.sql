-- Run once on existing databases: adds admin audit column expected by approval workflow.
ALTER TABLE `results`
  ADD COLUMN `admin_id` int(11) DEFAULT NULL AFTER `approval_date`,
  ADD KEY `results_admin_id` (`admin_id`),
  ADD CONSTRAINT `results_ibfk_admin` FOREIGN KEY (`admin_id`) REFERENCES `users` (`user_id`) ON DELETE SET NULL;
