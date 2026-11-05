-- 1. Create a schema for this lab (only runs once)
CREATE SCHEMA IF NOT EXISTS group14project;

-- 2. Tell PostgreSQL to use this schema by default
SET search_path TO group14project;

-- 3. Safety header: drop old tables if they exist
DROP TABLE IF EXISTS progress_checkin_entry_metric_measured CASCADE;
DROP TABLE IF EXISTS progress_checkin_entry_metric_timed CASCADE;
DROP TABLE IF EXISTS progress_checkin_entry_metric_set_rep CASCADE;
DROP TABLE IF EXISTS progress_checkin_entry_metric CASCADE;
DROP TABLE IF EXISTS progress_checkin_entry CASCADE;
DROP TABLE IF EXISTS session_exercise_performed_timed CASCADE;
DROP TABLE IF EXISTS session_exercise_performed_set_rep CASCADE;
DROP TABLE IF EXISTS session_exercise_performed CASCADE;
DROP TABLE IF EXISTS workout_session CASCADE;
DROP TABLE IF EXISTS session_plan CASCADE;
DROP TABLE IF EXISTS program_phase_exercise_timed CASCADE;
DROP TABLE IF EXISTS program_phase_exercise_set_rep CASCADE;
DROP TABLE IF EXISTS program_phase_exercise CASCADE;
DROP TABLE IF EXISTS exercise CASCADE;
DROP TABLE IF EXISTS program_status CASCADE;
DROP TABLE IF EXISTS program_phase CASCADE;
DROP TABLE IF EXISTS program CASCADE;
DROP TABLE IF EXISTS intake_info CASCADE;
DROP TABLE IF EXISTS trainer CASCADE;
DROP TABLE IF EXISTS client CASCADE;

-- 4. Create your tables in this schema

-- Core entities
CREATE TABLE client (
    client_id         INTEGER PRIMARY KEY,
    client_name       VARCHAR(50) NOT NULL,
    email             VARCHAR(100) UNIQUE NOT NULL,
    birthday          DATE,
    sex               VARCHAR(20), -- not just male or female because intersex people exist
    phone_number      VARCHAR(20),
    payment_method    VARCHAR(30),
    payment_standing  VARCHAR(20) NOT NULL DEFAULT 'pending'
                      CHECK (payment_standing IN ('good', 'late', 'pending'))
);

CREATE TABLE trainer (
    trainer_id           INTEGER PRIMARY KEY,
    name                 VARCHAR(50),
    phone                VARCHAR(20),
    email                VARCHAR(100) UNIQUE,
    years_of_experience  INTEGER CHECK (years_of_experience >= 0),
    certifications       VARCHAR(200)
);

CREATE TABLE intake_info (
    client_id     INTEGER REFERENCES client(client_id),
    intake_date   TIMESTAMP,
    goal_notes    TEXT,
    health_notes  TEXT,
    PRIMARY KEY (client_id, intake_date)
);

CREATE TABLE program (
    program_id        INTEGER PRIMARY KEY,
    program_name      VARCHAR(60) NOT NULL,
    program_category  VARCHAR(60),
    program_type      VARCHAR(30)
                      CHECK (program_type IN ('Beginner', 'Intermediate', 'Advanced', 'Rehab')),
    session_pricing   NUMERIC(8,2) CHECK (session_pricing >= 0),
    program_notes     TEXT
);

CREATE TABLE program_phase (
    program_id            INTEGER REFERENCES program(program_id),
    phase_index           INTEGER CHECK (phase_index >= 1),
    estimated_weeks       INTEGER CHECK (estimated_weeks > 0),
    phase_exercise_notes  TEXT,
    PRIMARY KEY (program_id, phase_index)
);

CREATE TABLE program_status (
    client_id                  INTEGER REFERENCES client(client_id),
    program_id                 INTEGER REFERENCES program(program_id),
    enrollment                 TIMESTAMP NOT NULL,
    status                     VARCHAR(20) NOT NULL DEFAULT 'In-progress'
                               CHECK (status IN ('In-progress', 'Completed', 'Dropped')),
    current_phase              INTEGER,
	weekly_in_person_sessions  INTEGER CHECK (weekly_in_person_sessions >= 0),
	weekly_online_sessions     INTEGER CHECK (weekly_online_sessions >= 0),
	PRIMARY KEY (client_id, program_id),
	FOREIGN KEY (program_id, current_phase)
	    REFERENCES program_phase(program_id, phase_index),
	CONSTRAINT chk_weekly_sessions_max
	    CHECK (weekly_in_person_sessions + weekly_online_sessions <= 7)
);

CREATE TABLE exercise (
    name  VARCHAR(50) PRIMARY KEY
);

-- Program phase exercises
CREATE TABLE program_phase_exercise (
    program_id     INTEGER,
    phase_index    INTEGER,
    exercise_name  VARCHAR(50) REFERENCES exercise(name),
    day            VARCHAR(10)
                   CHECK (LOWER(day) IN ('mon', 'tue', 'wed', 'thu', 'fri', 'sat', 'sun')),
    PRIMARY KEY (program_id, phase_index, exercise_name),
    FOREIGN KEY (program_id, phase_index)
        REFERENCES program_phase(program_id, phase_index)
);

CREATE TABLE program_phase_exercise_set_rep (
    program_id     INTEGER,
    phase_index    INTEGER,
    exercise_name  VARCHAR(50),
    set_count      INTEGER NOT NULL CHECK (set_count > 0),
    rep            INTEGER NOT NULL CHECK (rep > 0),
    PRIMARY KEY (program_id, phase_index, exercise_name),
    FOREIGN KEY (program_id, phase_index, exercise_name)
        REFERENCES program_phase_exercise(program_id, phase_index, exercise_name)
);

CREATE TABLE program_phase_exercise_timed (
    program_id        INTEGER,
    phase_index       INTEGER,
    exercise_name     VARCHAR(50),
    duration_minutes  INTEGER NOT NULL CHECK (duration_minutes > 0),
    note              TEXT,
    PRIMARY KEY (program_id, phase_index, exercise_name),
    FOREIGN KEY (program_id, phase_index, exercise_name)
        REFERENCES program_phase_exercise(program_id, phase_index, exercise_name)
);

-- Scheduling and sessions
CREATE TABLE session_plan (
    client_id  INTEGER REFERENCES client(client_id),
    plan_date  TIMESTAMP,
    status     VARCHAR(20) NOT NULL DEFAULT 'booked'
               CHECK (status IN ('booked', 'attended', 'missed', 'cancelled')),
    attendence_type       VARCHAR(20) NOT NULL
               CHECK (attendence_type IN ('in-person', 'online')),
    PRIMARY KEY (client_id, plan_date)
);

CREATE TABLE workout_session (
    client_id           INTEGER,
    session_date        DATE,
    attended            BOOLEAN NOT NULL DEFAULT TRUE,
    start_time          TIME,
    end_time            TIME,
    current_program_id  INTEGER REFERENCES program(program_id),
    phase_index         INTEGER,
    intake_date         TIMESTAMP,
    trainer_id          INTEGER REFERENCES trainer(trainer_id),
    presession_notes    TEXT,
    postsession_notes   TEXT,
    PRIMARY KEY (client_id, session_date),
    FOREIGN KEY (client_id, session_date) REFERENCES session_plan(client_id, plan_date),
	FOREIGN KEY (current_program_id, phase_index) REFERENCES program_phase(program_id, phase_index),
    FOREIGN KEY (client_id, intake_date) REFERENCES intake_info(client_id, intake_date),
    CONSTRAINT chk_ws_end_after_start CHECK (end_time > start_time)
);

CREATE TABLE session_exercise_performed (
    client_id      INTEGER,
    session_date   TIMESTAMP,
    exercise_name  VARCHAR(50) REFERENCES exercise(name),
    notes          TEXT,
    PRIMARY KEY (client_id, session_date, exercise_name),
    FOREIGN KEY (client_id, session_date)
        REFERENCES workout_session(client_id, session_date)
);

CREATE TABLE session_exercise_performed_set_rep (
    client_id      INTEGER,
    session_date   TIMESTAMP,
    exercise_name  VARCHAR(50),
    set_count      INTEGER NOT NULL CHECK (set_count > 0),
    rep            INTEGER NOT NULL CHECK (rep > 0),
    PRIMARY KEY (client_id, session_date, exercise_name),
    FOREIGN KEY (client_id, session_date, exercise_name)
        REFERENCES session_exercise_performed(client_id, session_date, exercise_name)
);

CREATE TABLE session_exercise_performed_timed (
    client_id         INTEGER,
    session_date      TIMESTAMP,
    exercise_name     VARCHAR(50),
    duration_minutes  INTEGER NOT NULL CHECK (duration_minutes > 0),
    note              VARCHAR(200),
    PRIMARY KEY (client_id, session_date, exercise_name),
    FOREIGN KEY (client_id, session_date, exercise_name)
        REFERENCES session_exercise_performed(client_id, session_date, exercise_name)
);

-- Progress check-ins
CREATE TABLE progress_checkin_entry (
    client_id     INTEGER REFERENCES client(client_id),
    checkin_date  TIMESTAMP,
    notes         TEXT,
    PRIMARY KEY (client_id, checkin_date)
);

CREATE TABLE progress_checkin_entry_metric (
    client_id     INTEGER,
    checkin_date  TIMESTAMP,
    metric_name   VARCHAR(50),
    PRIMARY KEY (client_id, checkin_date, metric_name),
    FOREIGN KEY (client_id, checkin_date)
        REFERENCES progress_checkin_entry(client_id, checkin_date)
);

CREATE TABLE progress_checkin_entry_metric_set_rep (
    client_id     INTEGER,
    checkin_date  TIMESTAMP,
    metric_name   VARCHAR(50),
    set_count     INTEGER NOT NULL CHECK (set_count > 0),
    rep           INTEGER NOT NULL CHECK (rep > 0),
    PRIMARY KEY (client_id, checkin_date, metric_name),
    FOREIGN KEY (client_id, checkin_date, metric_name)
        REFERENCES progress_checkin_entry_metric(client_id, checkin_date, metric_name)
);

CREATE TABLE progress_checkin_entry_metric_timed (
    client_id         INTEGER,
    checkin_date      TIMESTAMP,
    metric_name       VARCHAR(50),
    duration_minutes  INTEGER NOT NULL CHECK (duration_minutes > 0),
    note              VARCHAR(200),
    PRIMARY KEY (client_id, checkin_date, metric_name),
    FOREIGN KEY (client_id, checkin_date, metric_name)
        REFERENCES progress_checkin_entry_metric(client_id, checkin_date, metric_name)
);

CREATE TABLE progress_checkin_entry_metric_measured (
    client_id     INTEGER,
    checkin_date  TIMESTAMP,
    metric_name   VARCHAR(50),
    measurement   NUMERIC(8,2) NOT NULL CHECK (measurement > 0),
    unit          VARCHAR(20) NOT NULL,
    PRIMARY KEY (client_id, checkin_date, metric_name),
    FOREIGN KEY (client_id, checkin_date, metric_name)
        REFERENCES progress_checkin_entry_metric(client_id, checkin_date, metric_name)
);
