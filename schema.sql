DROP SCHEMA IF EXISTS pt_studio_group_14 CASCADE;
CREATE SCHEMA pt_studio_group_14;
SET search_path TO pt_studio_group_14;


-- Core entities
CREATE TABLE client (
    client_id         INTEGER PRIMARY KEY,
    client_name       VARCHAR(50) NOT NULL,
    email             VARCHAR(100) UNIQUE,
    sex               VARCHAR(20),
    phone_number      VARCHAR(20),
	CONSTRAINT check_client_email      CHECK (email LIKE '%@%'),
	CONSTRAINT check_client_sex     CHECK (sex IN ('male','female','non-binary','undisclosed')),
	CONSTRAINT check_client_phone_number      CHECK (phone_number ~ '^[0-9 ()-]{7,}$')
);

CREATE TABLE trainer (
    trainer_id           INTEGER PRIMARY KEY,
    name                 VARCHAR(50) NOT NULL,
    phone                VARCHAR(20),
    email                VARCHAR(100) UNIQUE,
    years_of_experience  INTEGER CHECK (years_of_experience >= 0),
    certifications       VARCHAR(200),
	CONSTRAINT check_trainer_email      CHECK (email LIKE '%@%'),
	CONSTRAINT check_trainer_phone_number      CHECK (phone ~ '^[0-9 ()-]{7,}$')
);

CREATE TABLE intake_info (
	intake_id	  INTEGER PRIMARY KEY, 
    client_id     INTEGER NOT NULL REFERENCES client(client_id) ON DELETE RESTRICT,
    intake_date   DATE, 
	age_at_intake INTEGER CHECK (age_at_intake between 1 and 120), 
    goal_notes    TEXT,
    health_notes  TEXT,
	assessment_notes TEXT,
	coaching_notes TEXT,
    UNIQUE (client_id, intake_date)
);

CREATE TABLE program (
    program_id        INTEGER PRIMARY KEY,
    program_name      VARCHAR(60) NOT NULL,
    program_category  VARCHAR(60),
    program_type      VARCHAR(30) CHECK (program_type IN ('Beginner', 'Intermediate', 'Advanced', 'Rehab')),
    session_pricing   NUMERIC(8,2) CHECK (session_pricing >= 0),
    program_notes     TEXT
);

CREATE TABLE program_phase (
    program_id            INTEGER REFERENCES program(program_id) ON DELETE CASCADE,
    phase_index           INTEGER CHECK (phase_index >= 1),
	phase_name			  VARCHAR(60),
    start_week 			  INTEGER NOT NULL CHECK (start_week >= 1),
	end_week			  INTEGER NOT NULL,
    phase_exercise_notes  TEXT,
    PRIMARY KEY (program_id, phase_index),
	CONSTRAINT check_phase_week_order CHECK (end_week >= start_week)
);

CREATE TABLE program_status (
    client_id                  INTEGER REFERENCES client(client_id) ON DELETE RESTRICT, 
    program_id                 INTEGER REFERENCES program(program_id) ON DELETE RESTRICT,
    enrollment_date            DATE,
    status                     VARCHAR(20) NOT NULL DEFAULT 'In-progress' CHECK (status IN ('In-progress', 'Completed', 'Dropped')),
    current_phase              INTEGER,
	weekly_in_person_sessions  INTEGER CHECK (weekly_in_person_sessions >= 0),
	weekly_online_sessions     INTEGER CHECK (weekly_online_sessions >= 0),
	PRIMARY KEY (client_id, program_id),
	FOREIGN KEY (program_id, current_phase)
	    REFERENCES program_phase(program_id, phase_index) ON DELETE RESTRICT,
	CONSTRAINT chk_weekly_sessions_max
	    CHECK (weekly_in_person_sessions + weekly_online_sessions <= 7)
);

CREATE TABLE exercise (
    name  VARCHAR(50) PRIMARY KEY
);

CREATE TABLE program_phase_exercise (
    program_id     INTEGER,
    phase_index    INTEGER,
    exercise_name  VARCHAR(50) REFERENCES exercise(name) ON DELETE RESTRICT ON UPDATE CASCADE,
	note		   TEXT, 
    PRIMARY KEY (program_id, phase_index, exercise_name),
    FOREIGN KEY (program_id, phase_index)
        REFERENCES program_phase(program_id, phase_index) ON DELETE CASCADE
);

CREATE TABLE program_phase_exercise_day (
    program_id     INTEGER,
    phase_index    INTEGER,
    exercise_name  VARCHAR(50),
    day_of_week    VARCHAR(3) CHECK (day_of_week IN ('Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun')),
    PRIMARY KEY (program_id, phase_index, exercise_name, day_of_week),
    FOREIGN KEY (program_id, phase_index, exercise_name)
        REFERENCES program_phase_exercise(program_id, phase_index, exercise_name) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE program_phase_exercise_set_rep (
    program_id     INTEGER,
    phase_index    INTEGER,
    exercise_name  VARCHAR(50),
    set_count      INTEGER NOT NULL CHECK (set_count > 0),
    rep_min        INTEGER NOT NULL CHECK (rep_min > 0),
    rep_max        INTEGER NOT NULL,
    per_side       BOOLEAN NOT NULL DEFAULT FALSE,
    PRIMARY KEY (program_id, phase_index, exercise_name),
    FOREIGN KEY (program_id, phase_index, exercise_name)
        REFERENCES program_phase_exercise(program_id, phase_index, exercise_name) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_rep_range CHECK (rep_max >= rep_min)
);

CREATE TABLE program_phase_exercise_timed (
    program_id        INTEGER,
    phase_index       INTEGER,
    exercise_name     VARCHAR(50),
    set_count         INTEGER CHECK (set_count > 0),
    duration_seconds  INTEGER NOT NULL CHECK (duration_seconds > 0),
    PRIMARY KEY (program_id, phase_index, exercise_name),
    FOREIGN KEY (program_id, phase_index, exercise_name)
        REFERENCES program_phase_exercise(program_id, phase_index, exercise_name)
        ON DELETE CASCADE ON UPDATE CASCADE
);


CREATE TABLE workout_session (
    session_id          INTEGER     PRIMARY KEY,               
    client_id           INTEGER     NOT NULL REFERENCES client(client_id) ON DELETE RESTRICT,
    session_date        DATE        NOT NULL,
    start_time          TIME,
    end_time            TIME,
    attendance_type     VARCHAR(20) NOT NULL CHECK (attendance_type IN ('in-person', 'online')),
    status              VARCHAR(20) NOT NULL DEFAULT 'booked' CHECK (status IN ('booked', 'attended', 'missed', 'cancelled')),
    program_id          INTEGER,
    phase_index         INTEGER,
    trainer_id          INTEGER     NOT NULL REFERENCES trainer(trainer_id) ON DELETE RESTRICT,
    presession_notes    TEXT,
    postsession_notes   TEXT,
    UNIQUE (client_id, session_date),                          
    FOREIGN KEY (client_id, program_id) 
        REFERENCES program_status(client_id, program_id) ON DELETE RESTRICT,
    FOREIGN KEY (program_id, phase_index)
        REFERENCES program_phase(program_id, phase_index) ON DELETE RESTRICT,
    CONSTRAINT chk_ws_phase_needs_program CHECK (phase_index IS NULL OR program_id IS NOT NULL),
    CONSTRAINT chk_ws_end_after_start     CHECK (end_time > start_time)
);

CREATE TABLE session_exercise_performed (
	session_id	   INTEGER REFERENCES workout_session(session_id) on DELETE CASCADE,
    exercise_name  VARCHAR(50) REFERENCES exercise(name) ON DELETE RESTRICT ON UPDATE CASCADE,
	exercise_order INTEGER NOT NULL CHECK (exercise_order >= 1),
	status			VARCHAR(20) NOT NULL DEFAULT 'completed' CHECK (status IN ('completed', 'substituted', 'scratched')),
	substituted_for VARCHAR(50) REFERENCES exercise(name) ON DELETE RESTRICT ON UPDATE CASCADE,
	planned_sets 	INTEGER	CHECK (planned_sets > 0),
	planned_reps	INTEGER CHECK (planned_reps > 0),
    notes          TEXT,
    PRIMARY KEY (session_id, exercise_name),
	UNIQUE (session_id, exercise_order),
	CONSTRAINT check_sub_not_self CHECK (substituted_for != exercise_name),
	CONSTRAINT check_sub_filled_when_status_is_substituted CHECK ((status ='substituted') = (substituted_for IS NOT NULL))
);

CREATE TABLE session_exercise_performed_set (
	session_id	   INTEGER,
    exercise_name  VARCHAR(50),
    set_count      INTEGER NOT NULL CHECK (set_count >= 1),
    reps           INTEGER NOT NULL CHECK (reps > 0),
	weight_lbs	   NUMERIC(5,2) CHECK (weight_lbs > 0),
	note		   TEXT, -- comment on set
    PRIMARY KEY (session_id, exercise_name, set_count),
    FOREIGN KEY (session_id, exercise_name)
        REFERENCES session_exercise_performed(session_id, exercise_name) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE session_exercise_performed_timed (
    session_id        INTEGER,
    exercise_name     VARCHAR(50),
    duration_seconds  INTEGER      NOT NULL CHECK (duration_seconds > 0),
    speed_mph         NUMERIC(4,1) CHECK (speed_mph > 0 AND speed_mph <= 20),
    incline_pct       NUMERIC(4,1) CHECK (incline_pct BETWEEN 0 AND 30),
    distance_miles    NUMERIC(5,2) CHECK (distance_miles > 0),
    PRIMARY KEY (session_id, exercise_name),
    FOREIGN KEY (session_id, exercise_name)
        REFERENCES session_exercise_performed(session_id, exercise_name) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE progress_checkin_entry (
    checkin_id    INTEGER     PRIMARY KEY, 
    client_id     INTEGER     NOT NULL REFERENCES client(client_id) ON DELETE RESTRICT,
    checkin_date  DATE,                                         
    checkin_type  VARCHAR(20) NOT NULL CHECK (checkin_type IN ('baseline', 'progress', 'pr', 'assessment')), 
    intake_id     INTEGER     REFERENCES intake_info(intake_id) ON DELETE RESTRICT,  
    week_number   INTEGER    CHECK (week_number >= 1),
    notes         TEXT,
    UNIQUE (client_id, checkin_date)
);

CREATE TABLE progress_checkin_entry_metric (
    checkin_id   INTEGER     REFERENCES progress_checkin_entry(checkin_id) ON DELETE CASCADE,
    metric_name  VARCHAR(60), 
    side         VARCHAR(3)  NOT NULL DEFAULT 'n/a' CHECK (side IN ('L', 'R', 'n/a')), 
    load_lbs	 NUMERIC(5, 2) CHECK (load_lbs > 0),
	note         TEXT, 
    PRIMARY KEY (checkin_id, metric_name, side)
);


CREATE TABLE progress_checkin_entry_metric_set_rep (
    checkin_id   INTEGER,
    metric_name  VARCHAR(60),
    side         VARCHAR(3) NOT NULL DEFAULT 'n/a' CHECK (side IN ('L', 'R', 'n/a')), 
    weight_lbs   NUMERIC(5,2) NOT NULL CHECK (weight_lbs > 0),  
    reps         INTEGER     CHECK (reps > 0),
    PRIMARY KEY (checkin_id, metric_name, side),
    FOREIGN KEY (checkin_id, metric_name, side)
        REFERENCES progress_checkin_entry_metric(checkin_id, metric_name, side) ON DELETE CASCADE ON UPDATE CASCADE
);


CREATE TABLE progress_checkin_entry_metric_measured (
    checkin_id   INTEGER,
    metric_name  VARCHAR(60),
    side         VARCHAR(3), 
    measurement  NUMERIC(8,2) NOT NULL,
    unit         VARCHAR(10)  NOT NULL CHECK (unit IN ('lbs', 'in', 'ft', 'deg', 's')),  
    is_relative  BOOLEAN      NOT NULL DEFAULT FALSE,
    PRIMARY KEY (checkin_id, metric_name, side),
    FOREIGN KEY (checkin_id, metric_name, side)
        REFERENCES progress_checkin_entry_metric(checkin_id, metric_name, side) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_measurement_sign 
        CHECK (measurement > 0 OR unit = 'deg' OR is_relative)
);
