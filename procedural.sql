SET search_path TO pt_studio_group_14;

-- ---------------------------------------------------------------------
-- 4A. Trigger: log every change to the workout sets
-- ---------------------------------------------------------------------

-- Re-runnable: drop and rebuild. 
DROP TRIGGER IF EXISTS trg_log_workout_set_change ON session_exercise_performed_set;
DROP TABLE IF EXISTS workout_set_change_log;

-- One row per change to session_exercise_performed_set.
CREATE TABLE workout_set_change_log (
    log_id          INTEGER     GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    action          VARCHAR(6)  NOT NULL CHECK (action IN ('INSERT', 'UPDATE', 'DELETE')),
    changed_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    changed_by      TEXT        NOT NULL DEFAULT current_user,       
    -- which row: the session_exercise_performed_set's primary key
    session_id      INTEGER     NOT NULL,
    exercise_name   VARCHAR(50) NOT NULL,
    set_count       INTEGER     NOT NULL,
    -- the values that change
    old_reps        INTEGER,
    new_reps        INTEGER,
    old_weight_lbs  NUMERIC(5,2),
    new_weight_lbs  NUMERIC(5,2),
    old_set_status  VARCHAR(10),
    new_set_status  VARCHAR(10)
);

-- The trigger function.
CREATE OR REPLACE FUNCTION fn_log_workout_set_change()
RETURNS TRIGGER
LANGUAGE plpgsql
SET search_path = pt_studio_group_14
AS $$
BEGIN
    IF TG_OP = 'INSERT' THEN
        INSERT INTO workout_set_change_log
            (action, changed_by, session_id, exercise_name, set_count,
             new_reps, new_weight_lbs, new_set_status)
        VALUES
            (TG_OP, current_user, NEW.session_id, NEW.exercise_name, NEW.set_count,
             NEW.reps, NEW.weight_lbs, NEW.set_status);

    ELSIF TG_OP = 'UPDATE' THEN
        -- An UPDATE that changes nothing (SET reps = reps) is not a change: skip it.
        IF OLD IS NOT DISTINCT FROM NEW THEN
            RETURN NULL;
        END IF;
        -- Which row: the key after the change (it differs only if an exercise
        -- rename cascades here; see Known Issues).
        INSERT INTO workout_set_change_log
            (action, changed_by, session_id, exercise_name, set_count,
             old_reps, new_reps, old_weight_lbs, new_weight_lbs,
             old_set_status, new_set_status)
        VALUES
            (TG_OP, current_user, NEW.session_id, NEW.exercise_name, NEW.set_count,
             OLD.reps, NEW.reps, OLD.weight_lbs, NEW.weight_lbs,
             OLD.set_status, NEW.set_status);

    ELSIF TG_OP = 'DELETE' THEN
        INSERT INTO workout_set_change_log
            (action, changed_by, session_id, exercise_name, set_count,
             old_reps, old_weight_lbs, old_set_status)
        VALUES
            (TG_OP, current_user, OLD.session_id, OLD.exercise_name, OLD.set_count,
             OLD.reps, OLD.weight_lbs, OLD.set_status);
    END IF;

    RETURN NULL;
END;
$$;

CREATE TRIGGER trg_log_workout_set_change
AFTER INSERT OR UPDATE OR DELETE ON session_exercise_performed_set
FOR EACH ROW
EXECUTE FUNCTION fn_log_workout_set_change();


-- ---------------------------------------------------------------------
-- 4A tests: one INSERT, one UPDATE and one DELETE.
-- ---------------------------------------------------------------------

-- UPDATE: correct Alex's Deadlift set 3 (3 reps -> 4)...
UPDATE session_exercise_performed_set
SET reps = 4
WHERE session_id = 1 AND exercise_name = 'Deadlift' AND set_count = 3;
-- Expected: UPDATE 1 (log row 1)

-- ...undo
UPDATE session_exercise_performed_set
SET reps = 3
WHERE session_id = 1 AND exercise_name = 'Deadlift' AND set_count = 3;
-- Expected: UPDATE 1 (log row 2)

-- INSERT: add a test set 6 to Alex's Deadlift...
INSERT INTO session_exercise_performed_set (session_id, exercise_name, set_count, reps, weight_lbs)
VALUES (1, 'Deadlift', 6, 1, 385);
-- Expected: INSERT 0 1 (log row 3)

-- DELETE: ...undo INSERT
DELETE FROM session_exercise_performed_set
WHERE session_id = 1 AND exercise_name = 'Deadlift' AND set_count = 6;
-- Expected: DELETE 1 (log row 4)

-- The log
SELECT log_id, action, changed_by = current_user AS by_me,
       session_id, exercise_name, set_count,
       old_reps, new_reps, old_weight_lbs, new_weight_lbs,
       old_set_status, new_set_status
FROM workout_set_change_log
ORDER BY log_id;
-- Expected: 4 rows, all session 1 Deadlift, by_me = t (the login running this script):
--   1 UPDATE  set 3  reps 3 -> 4  weight 315.00 -> 315.00  completed -> completed
--   2 UPDATE  set 3  reps 4 -> 3  weight 315.00 -> 315.00  completed -> completed
--   3 INSERT  set 6  new reps 1, new weight 385.00, new status completed (old_* NULL)
--   4 DELETE  set 6  old reps 1, old weight 385.00, old status completed (new_* NULL)


-- ---------------------------------------------------------------------
-- 4B. Stored function: plan the next session
-- ---------------------------------------------------------------------


CREATE OR REPLACE FUNCTION fn_plan_next_session(
    p_client_id       INTEGER,
    p_session_date    DATE,
    p_start_time      TIME,
    p_attendance_type VARCHAR
)
RETURNS INTEGER
LANGUAGE plpgsql
SET search_path = pt_studio_group_14
AS $$
DECLARE
    v_last    workout_session%ROWTYPE;
    v_new_id  INTEGER;
BEGIN
    IF p_session_date IS NULL THEN
        RAISE EXCEPTION 'A session date is required';
    END IF;

    IF NOT EXISTS (SELECT 1 FROM client WHERE client_id = p_client_id) THEN
        RAISE EXCEPTION 'Client % does not exist', p_client_id;
    END IF;

    -- Last session
    SELECT * INTO v_last
    FROM workout_session
    WHERE client_id = p_client_id
      AND status = 'attended'
    ORDER BY session_date DESC, session_id DESC
    LIMIT 1;

    IF NOT FOUND THEN
        RAISE EXCEPTION 'Client % has no previous session to plan from', p_client_id;
    END IF;

    IF p_session_date <= v_last.session_date THEN
        RAISE EXCEPTION 'The new session date % must be after the last session (%)',
            p_session_date, v_last.session_date;
    END IF;

    IF EXISTS (SELECT 1 FROM workout_session
               WHERE client_id = p_client_id AND session_date = p_session_date) THEN
        RAISE EXCEPTION 'Client % already has a session on %', p_client_id, p_session_date;
    END IF;

    -- Next id
    PERFORM pg_advisory_xact_lock(14);
    SELECT COALESCE(MAX(session_id), 0) + 1 INTO v_new_id FROM workout_session;

    -- New session
    INSERT INTO workout_session
        (session_id, client_id, session_date, start_time, attendance_type, status,
         program_id, phase_index, trainer_id, presession_notes)
    VALUES
        (v_new_id, p_client_id, p_session_date, p_start_time, p_attendance_type, 'booked',
         v_last.program_id, NULL, v_last.trainer_id,
         'Planned from the ' || to_char(v_last.session_date, 'YYYY-MM-DD') || ' session.');

    -- Copy exercises
    INSERT INTO session_exercise_performed
        (session_id, exercise_name, exercise_order, status, planned_sets, planned_reps)
    SELECT v_new_id,
           sep.exercise_name,
           ROW_NUMBER() OVER (ORDER BY sep.exercise_order),
           'planned',
           COALESCE(st.sets_done, sep.planned_sets),
           CASE WHEN st.sets_done IS NOT NULL THEN ROUND(st.avg_reps)::INTEGER
                ELSE sep.planned_reps END
    FROM session_exercise_performed sep
    LEFT JOIN (
        SELECT exercise_name, COUNT(*) AS sets_done, AVG(reps) AS avg_reps
        FROM session_exercise_performed_set
        WHERE session_id = v_last.session_id
        GROUP BY exercise_name
    ) st ON st.exercise_name = sep.exercise_name
    WHERE sep.session_id = v_last.session_id
      AND sep.status <> 'scratched';

    -- Copy cardio
    INSERT INTO session_exercise_performed_timed
        (session_id, exercise_name, duration_seconds, speed_mph, incline_pct, distance_miles)
    SELECT v_new_id, t.exercise_name, t.duration_seconds, t.speed_mph, t.incline_pct, t.distance_miles
    FROM session_exercise_performed_timed t
    JOIN session_exercise_performed sep
      ON sep.session_id = t.session_id AND sep.exercise_name = t.exercise_name
    WHERE t.session_id = v_last.session_id
      AND sep.status <> 'scratched';

    RETURN v_new_id;
END;
$$;


-- ---------------------------------------------------------------------
-- 4B. tests
-- ---------------------------------------------------------------------


-- Re runnable cleanup
DELETE FROM workout_session
WHERE status = 'booked' AND presession_notes LIKE 'Planned from the %';

-- Test 1: Alex
SELECT fn_plan_next_session(1, DATE '2025-10-23', TIME '16:00', 'in-person') AS new_session_id;
-- Expected: 4

-- Test 2: Jordan
SELECT fn_plan_next_session(2, DATE '2025-10-23', TIME '10:00', 'in-person') AS new_session_id;
-- Expected: 5

-- New sessions
SELECT c.client_name, ws.session_id, ws.session_date, ws.start_time, ws.attendance_type,
       ws.status AS session_status, ws.program_id, ws.presession_notes,
       sep.exercise_order, sep.exercise_name, sep.status AS exercise_status,
       sep.planned_sets, sep.planned_reps,
       t.duration_seconds, t.speed_mph, t.incline_pct
FROM workout_session ws
JOIN client c ON c.client_id = ws.client_id
JOIN session_exercise_performed sep ON sep.session_id = ws.session_id
LEFT JOIN session_exercise_performed_timed t
       ON t.session_id = sep.session_id AND t.exercise_name = sep.exercise_name
WHERE ws.status = 'booked'
ORDER BY ws.session_id, sep.exercise_order;
-- Expected:
-- Statuses: booked, planned
-- 4 Alex M.   2025-10-23 16:00 in-person program 1  1 KB Goblet Squat 3x10
-- 4 Alex M.   2025-10-23 16:00 in-person program 1  2 Deadlift 5x4
-- 4 Alex M.   2025-10-23 16:00 in-person program 1  3 Bench Press 4x6
-- 4 Alex M.   2025-10-23 16:00 in-person program 1  4 Barbell Row 3x8
-- 5 Jordan T. 2025-10-23 10:00 in-person program 2  1 TRX Assisted Squat 3x12
-- 5 Jordan T. 2025-10-23 10:00 in-person program 2  2 DB Standing OHP 3x10
-- 5 Jordan T. 2025-10-23 10:00 in-person program 2  3 Seated Cable Row 3x12
-- 5 Jordan T. 2025-10-23 10:00 in-person program 2  4 Incline Treadmill Walk NULLxNULL 720 s 3.2 mph 4.0%
-- Notes: "Planned from the 2025-10-16 session." (Alex), "...2025-10-19 session." (Jordan)

-- Test 3: no history
DO $$
BEGIN
    PERFORM fn_plan_next_session(3, DATE '2025-10-23', TIME '09:00', 'in-person');
EXCEPTION WHEN raise_exception THEN
    RAISE NOTICE 'Caught: %', SQLERRM;
END $$;
-- Expected: Caught: Client 3 has no previous session to plan from

SELECT COUNT(*) AS maya_sessions FROM workout_session WHERE client_id = 3;
-- Expected: 0

-- Test 4: reports unchanged
SELECT client_name, last_session_date, exercises_changed
FROM v_session_brief
WHERE client_id IN (1, 2)
ORDER BY client_id;
-- Expected: Alex M. 2025-10-16 1
-- Expected: Jordan T. 2025-10-19 2

SELECT status, COUNT(*) AS sessions FROM workout_session GROUP BY status ORDER BY status;
-- Expected: attended 3, booked 2