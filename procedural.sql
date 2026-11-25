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