-- ============================================================================
--  Clean Energy Campaign  -  MySQL / MariaDB schema
--  Works with XAMPP (MariaDB 10.4+) and MySQL 5.7+ / 8.x
--
--  HOW TO IMPORT (XAMPP):
--    1. Start Apache + MySQL in the XAMPP Control Panel
--    2. Open http://localhost/phpmyadmin
--    3. Click the "Import" tab -> choose this file -> click "Import"
--  That's it: it creates the `clean_energy` database and every table below.
--  Safe to run again: existing tables and data are left untouched.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS `clean_energy`
  CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE `clean_energy`;

-- ---------------------------------------------------------------- accounts --
CREATE TABLE IF NOT EXISTS `users` (
  `id`            INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`          VARCHAR(100)  NOT NULL,
  `email`         VARCHAR(190)  NOT NULL,
  `password_hash` VARCHAR(255)  NOT NULL,              -- bcrypt hash, never the real password
  `role`          ENUM('user','admin') NOT NULL DEFAULT 'user',
  `created_at`    DATETIME      NOT NULL DEFAULT CURRENT_TIMESTAMP,   -- stored in UTC
  `last_login`    DATETIME      NULL,
  `login_count`   INT UNSIGNED  NOT NULL DEFAULT 0,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_users_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- Login sessions live in MySQL (not in files under htdocs), so they can't be read over HTTP.
CREATE TABLE IF NOT EXISTS `sessions` (
  `id`         VARCHAR(128) NOT NULL,
  `data`       MEDIUMTEXT   NOT NULL,
  `life`       INT UNSIGNED NOT NULL DEFAULT 28800,     -- seconds a session survives without use
  `expires_at` DATETIME     NOT NULL,
  PRIMARY KEY (`id`),
  KEY `idx_sessions_expires` (`expires_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- 6-digit "forgot password" codes (stored hashed, expire after 10 minutes)
CREATE TABLE IF NOT EXISTS `password_resets` (
  `user_id`    INT UNSIGNED NOT NULL,
  `code_hash`  VARCHAR(255) NOT NULL,
  `expires_at` DATETIME     NOT NULL,
  `tries`      TINYINT UNSIGNED NOT NULL DEFAULT 0,
  PRIMARY KEY (`user_id`),
  CONSTRAINT `fk_reset_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ------------------------------------------------ user <-> admin inbox / chat --
CREATE TABLE IF NOT EXISTS `messages` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `user_id`    INT UNSIGNED NOT NULL,                   -- the conversation belongs to this user
  `sender`     ENUM('user','admin') NOT NULL,
  `body`       VARCHAR(1000) NOT NULL,
  `is_read`    TINYINT(1) NOT NULL DEFAULT 0,           -- user message read by an admin?
  `seen`       TINYINT(1) NOT NULL DEFAULT 0,           -- admin reply seen by the user?
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_messages_user` (`user_id`,`created_at`),
  CONSTRAINT `fk_messages_user` FOREIGN KEY (`user_id`) REFERENCES `users` (`id`) ON DELETE CASCADE
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- -------------------------------------------------------- website form data --
CREATE TABLE IF NOT EXISTS `petition_signatures` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`       VARCHAR(100) NOT NULL,
  `email`      VARCHAR(190) NOT NULL,
  `anonymous`  TINYINT(1)   NOT NULL DEFAULT 0,
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_petition_email` (`email`)               -- one signature per email
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `pledges` (                   -- pledges only: no payment details are ever stored
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `method`     VARCHAR(30)  NOT NULL,
  `wallet`     VARCHAR(40)  NOT NULL DEFAULT '',
  `amount`     DECIMAL(12,2) NOT NULL,
  `name`       VARCHAR(100) NOT NULL DEFAULT '',
  `anonymous`  TINYINT(1)   NOT NULL DEFAULT 0,
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `fundraiser_ideas` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`       VARCHAR(100) NOT NULL,
  `email`      VARCHAR(190) NOT NULL,
  `kind`       VARCHAR(40)  NOT NULL DEFAULT '',
  `idea`       VARCHAR(2000) NOT NULL DEFAULT '',
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `volunteers` (
  `id`              INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`            VARCHAR(100) NOT NULL,
  `email`           VARCHAR(190) NOT NULL,
  `role`            VARCHAR(60)  NOT NULL DEFAULT '',
  `organization`    VARCHAR(120) NOT NULL DEFAULT '',
  `activities`      VARCHAR(600) NOT NULL DEFAULT '',   -- comma separated
  `time_commitment` VARCHAR(60)  NOT NULL DEFAULT '',
  `message`         VARCHAR(2000) NOT NULL DEFAULT '',
  `created_at`      DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `role_interest` (             -- "Work for Us" job interest
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`       VARCHAR(100) NOT NULL,
  `email`      VARCHAR(190) NOT NULL,
  `role`       VARCHAR(80)  NOT NULL,
  `message`    VARCHAR(2000) NOT NULL DEFAULT '',
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `contact_messages` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`       VARCHAR(100) NOT NULL,
  `email`      VARCHAR(190) NOT NULL,
  `topic`      VARCHAR(60)  NOT NULL DEFAULT '',
  `message`    VARCHAR(3000) NOT NULL,
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `partner_applications` (
  `id`             INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `organization`   VARCHAR(150) NOT NULL,
  `partner_type`   VARCHAR(60)  NOT NULL,
  `contact_person` VARCHAR(100) NOT NULL,
  `position`       VARCHAR(100) NOT NULL DEFAULT '',
  `email`          VARCHAR(190) NOT NULL,
  `phone`          VARCHAR(40)  NOT NULL DEFAULT '',
  `city`           VARCHAR(100) NOT NULL,
  `ways`           VARCHAR(400) NOT NULL DEFAULT '',   -- comma separated
  `message`        VARCHAR(3000) NOT NULL,
  `created_at`     DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

CREATE TABLE IF NOT EXISTS `supporters` (
  `id`         INT UNSIGNED NOT NULL AUTO_INCREMENT,
  `name`       VARCHAR(100) NOT NULL,
  `email`      VARCHAR(190) NOT NULL,
  `role`       VARCHAR(60)  NOT NULL DEFAULT '',
  `level`      VARCHAR(20)  NOT NULL DEFAULT 'Supporter',
  `created_at` DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  UNIQUE KEY `uq_supporters_email` (`email`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;

-- ---------------------------------------------------------- abuse protection --
-- counts recent attempts (logins, forms, AI questions) so one visitor can't flood the site
CREATE TABLE IF NOT EXISTS `rate_limits` (
  `id`         BIGINT UNSIGNED NOT NULL AUTO_INCREMENT,
  `bucket`     VARCHAR(30) NOT NULL,
  `ident`      VARCHAR(100) NOT NULL,
  `created_at` DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
  PRIMARY KEY (`id`),
  KEY `idx_rate` (`bucket`,`ident`,`created_at`)
) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
