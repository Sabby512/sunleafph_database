-- ============================================================================
--  Clean Energy Campaign  -  PostgreSQL schema
--  Works with PostgreSQL 12+ (Neon, Supabase, Vercel Postgres, local Postgres)
--
--  HOW TO IMPORT:
--    Neon / Supabase : open the SQL Editor, paste this whole file, click Run.
--    psql            : psql "<your connection string>" -f clean_energy_postgres.sql
--
--  There is no CREATE DATABASE here: Postgres hosts give you a database already
--  (Neon's default is "neondb"). Put that name in the DB_DATABASE variable.
--  Safe to run again: existing tables and data are left untouched.
--
--  Notes on the conversion from MySQL:
--   * Times are TIMESTAMP (no time zone) holding UTC, same as the MySQL version.
--   * The 0/1 flag columns stay SMALLINT (not BOOLEAN) so the PHP code that does
--     "is_read = 0" and "seen = 1" keeps working.
--   * `pledges.account_email` (the old upgrade_pledge_account.sql) is built in.
-- ============================================================================

-- ---------------------------------------------------------------- accounts --
CREATE TABLE IF NOT EXISTS users (
  id            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name          VARCHAR(100) NOT NULL,
  email         VARCHAR(190) NOT NULL,
  password_hash VARCHAR(255) NOT NULL,                          -- bcrypt hash, never the real password
  role          VARCHAR(10)  NOT NULL DEFAULT 'user' CHECK (role IN ('user','admin')),
  created_at    TIMESTAMP(0) NOT NULL DEFAULT (NOW() AT TIME ZONE 'UTC'),   -- stored in UTC
  last_login    TIMESTAMP(0) NULL,
  login_count   INTEGER      NOT NULL DEFAULT 0 CHECK (login_count >= 0),
  CONSTRAINT uq_users_email UNIQUE (email)
);

-- Login sessions live in the database (serverless hosts have no persistent disk).
CREATE TABLE IF NOT EXISTS sessions (
  id         VARCHAR(128) PRIMARY KEY,
  data       TEXT         NOT NULL,
  life       INTEGER      NOT NULL DEFAULT 28800,                -- seconds a session survives without use
  expires_at TIMESTAMP(0) NOT NULL
);
CREATE INDEX IF NOT EXISTS idx_sessions_expires ON sessions (expires_at);

-- 6-digit "forgot password" codes (stored hashed, expire after 10 minutes)
CREATE TABLE IF NOT EXISTS password_resets (
  user_id    INTEGER      PRIMARY KEY REFERENCES users (id) ON DELETE CASCADE,
  code_hash  VARCHAR(255) NOT NULL,
  expires_at TIMESTAMP(0) NOT NULL,
  tries      SMALLINT     NOT NULL DEFAULT 0
);

-- ------------------------------------------------ user <-> admin inbox / chat --
CREATE TABLE IF NOT EXISTS messages (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  user_id    INTEGER       NOT NULL REFERENCES users (id) ON DELETE CASCADE,   -- the conversation belongs to this user
  sender     VARCHAR(10)   NOT NULL CHECK (sender IN ('user','admin')),
  body       VARCHAR(1000) NOT NULL,
  is_read    SMALLINT      NOT NULL DEFAULT 0 CHECK (is_read IN (0,1)),        -- user message read by an admin?
  seen       SMALLINT      NOT NULL DEFAULT 0 CHECK (seen IN (0,1)),           -- admin reply seen by the user?
  created_at TIMESTAMP(0)  NOT NULL DEFAULT (NOW() AT TIME ZONE 'UTC')
);
CREATE INDEX IF NOT EXISTS idx_messages_user ON messages (user_id, created_at);

-- -------------------------------------------------------- website form data --
CREATE TABLE IF NOT EXISTS petition_signatures (
  id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  email      VARCHAR(190) NOT NULL,
  anonymous  SMALLINT     NOT NULL DEFAULT 0 CHECK (anonymous IN (0,1)),
  created_at TIMESTAMP(0) NOT NULL DEFAULT (NOW() AT TIME ZONE 'UTC'),
  CONSTRAINT uq_petition_email UNIQUE (email)                    -- one signature per email
);

-- pledges only: no payment details are ever stored
CREATE TABLE IF NOT EXISTS pledges (
  id            INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  method        VARCHAR(30)   NOT NULL,
  wallet        VARCHAR(40)   NOT NULL DEFAULT '',
  amount        NUMERIC(12,2) NOT NULL,
  name          VARCHAR(100)  NOT NULL DEFAULT '',
  anonymous     SMALLINT      NOT NULL DEFAULT 0 CHECK (anonymous IN (0,1)),
  created_at    TIMESTAMP(0)  NOT NULL DEFAULT (NOW() AT TIME ZONE 'UTC'),
  account_email VARCHAR(190)  NULL                               -- which logged-in account made the pledge
);

CREATE TABLE IF NOT EXISTS fundraiser_ideas (
  id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR(100)  NOT NULL,
  email      VARCHAR(190)  NOT NULL,
  kind       VARCHAR(40)   NOT NULL DEFAULT '',
  idea       VARCHAR(2000) NOT NULL DEFAULT '',
  created_at TIMESTAMP(0)  NOT NULL DEFAULT (NOW() AT TIME ZONE 'UTC')
);

CREATE TABLE IF NOT EXISTS volunteers (
  id              INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name            VARCHAR(100)  NOT NULL,
  email           VARCHAR(190)  NOT NULL,
  role            VARCHAR(60)   NOT NULL DEFAULT '',
  organization    VARCHAR(120)  NOT NULL DEFAULT '',
  activities      VARCHAR(600)  NOT NULL DEFAULT '',             -- comma separated
  time_commitment VARCHAR(60)   NOT NULL DEFAULT '',
  message         VARCHAR(2000) NOT NULL DEFAULT '',
  created_at      TIMESTAMP(0)  NOT NULL DEFAULT (NOW() AT TIME ZONE 'UTC')
);

-- "Work for Us" job interest
CREATE TABLE IF NOT EXISTS role_interest (
  id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR(100)  NOT NULL,
  email      VARCHAR(190)  NOT NULL,
  role       VARCHAR(80)   NOT NULL,
  message    VARCHAR(2000) NOT NULL DEFAULT '',
  created_at TIMESTAMP(0)  NOT NULL DEFAULT (NOW() AT TIME ZONE 'UTC')
);

CREATE TABLE IF NOT EXISTS contact_messages (
  id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR(100)  NOT NULL,
  email      VARCHAR(190)  NOT NULL,
  topic      VARCHAR(60)   NOT NULL DEFAULT '',
  message    VARCHAR(3000) NOT NULL,
  created_at TIMESTAMP(0)  NOT NULL DEFAULT (NOW() AT TIME ZONE 'UTC')
);

CREATE TABLE IF NOT EXISTS partner_applications (
  id             INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  organization   VARCHAR(150)  NOT NULL,
  partner_type   VARCHAR(60)   NOT NULL,
  contact_person VARCHAR(100)  NOT NULL,
  position       VARCHAR(100)  NOT NULL DEFAULT '',
  email          VARCHAR(190)  NOT NULL,
  phone          VARCHAR(40)   NOT NULL DEFAULT '',
  city           VARCHAR(100)  NOT NULL,
  ways           VARCHAR(400)  NOT NULL DEFAULT '',              -- comma separated
  message        VARCHAR(3000) NOT NULL,
  created_at     TIMESTAMP(0)  NOT NULL DEFAULT (NOW() AT TIME ZONE 'UTC')
);

CREATE TABLE IF NOT EXISTS supporters (
  id         INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  name       VARCHAR(100) NOT NULL,
  email      VARCHAR(190) NOT NULL,
  role       VARCHAR(60)  NOT NULL DEFAULT '',
  level      VARCHAR(20)  NOT NULL DEFAULT 'Supporter',
  created_at TIMESTAMP(0) NOT NULL DEFAULT (NOW() AT TIME ZONE 'UTC'),
  CONSTRAINT uq_supporters_email UNIQUE (email)
);

-- ---------------------------------------------------------- abuse protection --
-- counts recent attempts (logins, forms, AI questions) so one visitor can't flood the site
CREATE TABLE IF NOT EXISTS rate_limits (
  id         BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
  bucket     VARCHAR(30)  NOT NULL,
  ident      VARCHAR(100) NOT NULL,
  created_at TIMESTAMP(0) NOT NULL DEFAULT (NOW() AT TIME ZONE 'UTC')
);
CREATE INDEX IF NOT EXISTS idx_rate ON rate_limits (bucket, ident, created_at);
