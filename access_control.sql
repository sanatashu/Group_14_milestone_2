SET search_path TO pt_studio_group_14;

-- ---------------------------------------------------------------------
-- Re-runnable clean-up
-- ---------------------------------------------------------------------
DO $$
DECLARE r TEXT;
BEGIN
    FOR r IN SELECT rolname FROM pg_roles
            WHERE rolname IN ('g14_sara_demo', 'g14_alex_demo',
                                'g14_trainer', 'g14_client_app')
    LOOP
        EXECUTE format('DROP OWNED BY %I', r);
    END LOOP;
END $$;

DROP ROLE IF EXISTS g14_sara_demo, g14_alex_demo, g14_trainer, g14_client_app;


-- ---------------------------------------------------------------------
-- Roles and user creation, assign role and schema privileges
-- ---------------------------------------------------------------------
CREATE ROLE g14_trainer    NOLOGIN;
CREATE ROLE g14_client_app NOLOGIN;

CREATE ROLE g14_sara_demo LOGIN PASSWORD 'sara_demo';
CREATE ROLE g14_alex_demo LOGIN PASSWORD 'alex_demo';

GRANT g14_trainer    TO g14_sara_demo;
GRANT g14_client_app TO g14_alex_demo;

GRANT g14_sara_demo, g14_alex_demo TO CURRENT_USER;

GRANT USAGE ON SCHEMA pt_studio_group_14 TO g14_trainer, g14_client_app;


-- ---------------------------------------------------------------------
-- GRANTS FOR G14_TRAINER
-- ---------------------------------------------------------------------

-- Select, Insert, Update on Master records
-- No DELETE: sessions, check-ins and enrolments hang off them (ON DELETE RESTRICT) and Sara's changes are UPDATEs (a client leaving a program = status 'Dropped').
GRANT SELECT, INSERT, UPDATE ON
    client,
    intake_info,            
    program,
    program_status,
    exercise               
TO g14_trainer;

-- Adding or editing trainers should be only for owner/admin.
GRANT SELECT ON trainer TO g14_trainer;

-- Program plan details
-- Sara can redesigns phases, so trainer needs all 4 level of access.
GRANT SELECT, INSERT, UPDATE, DELETE ON
    program_phase,
    program_phase_exercise,
    program_phase_exercise_day,
    program_phase_exercise_set_rep,
    program_phase_exercise_timed
TO g14_trainer;

-- Workout logs
-- 4 levels of access so Sara can correct sessions after the fact.
-- Deleting a session cascades to its exercises and sets.
GRANT SELECT, INSERT, UPDATE, DELETE ON
    workout_session,
    session_exercise_performed,
    session_exercise_performed_set,
    session_exercise_performed_timed
TO g14_trainer;

-- Check-ins
-- 4 levels of access for corrections.
GRANT SELECT, INSERT, UPDATE, DELETE ON
    progress_checkin_entry,
    progress_checkin_entry_metric,
    progress_checkin_entry_metric_set_rep,
    progress_checkin_entry_metric_measured
TO g14_trainer;

-- Both views: her pre-session brief, and the client view so she can see exactly what a client sees in the app.
GRANT SELECT ON v_session_brief, v_client_progress TO g14_trainer;

-- Change log (Part 4A):
GRANT SELECT, INSERT ON workout_set_change_log TO g14_trainer;

REVOKE EXECUTE ON ALL FUNCTIONS IN SCHEMA pt_studio_group_14 FROM PUBLIC;
GRANT EXECUTE ON FUNCTION fn_plan_next_session(INTEGER, DATE, TIME, VARCHAR) TO g14_trainer;

-- ---------------------------------------------------------------------
-- GRANTS FOR G14_CLIENT_APP
-- ---------------------------------------------------------------------
GRANT SELECT ON v_client_progress TO g14_client_app;

-- Decision: No self-logging for clients. 
-- Clients send their reports to Sara and she enters them. So the client app gets no INSERT on any workout table.


-- ---------------------------------------------------------------------
-- Tests
-- ---------------------------------------------------------------------

-- ROLE: Sara (trainer)
SET ROLE g14_sara_demo;

-- Test that works - Sara reads her session brief.
SELECT client_name, program_name, last_session_date
FROM v_session_brief
ORDER BY client_id;
-- Expected: 5 rows, one per client. Alex, Sam 2025-10-18 (no program), Jordan and their last session dates
-- Maya and Casey have no session (last_session_date NULL) and still appear.

-- Test that does not work - Sara can't delete a client. 
DELETE FROM client WHERE client_id = 1;
-- Expected error: "ERROR: permission denied for table client"

-- AFTER PART 4A
-- Refused: Sara can't delete entries from the change log...
DELETE FROM workout_set_change_log;
-- Expected error (intentional): ERROR: permission denied for table workout_set_change_log

-- Refused: Sara can't change the change log.
UPDATE workout_set_change_log SET changed_by = 'someone_else';
-- Expected error (intentional): ERROR: permission denied for table workout_set_change_log

-- Sara plans
SELECT fn_plan_next_session(4, DATE '2025-10-25', NULL, 'online') AS new_session_id;
-- Expected: 6

DELETE FROM workout_session WHERE client_id = 4 AND session_date = DATE '2025-10-25';
-- Expected: DELETE 1

RESET ROLE;


-- ROLE: Alex (client app)
SET ROLE g14_alex_demo;

-- Test that works: the app reads Alex's progress through the view.
SELECT record_type, COUNT(*) AS row_count
FROM v_client_progress
WHERE client_id = 1
GROUP BY record_type
ORDER BY record_type;
-- Expected: 2 rows. strength_result 6, workout_set 15.

-- Test that is refused: the client app can't read health notes.
SELECT health_notes FROM intake_info;
-- Expected error: "ERROR: permission denied for table intake_info"

-- Client refused
SELECT fn_plan_next_session(1, DATE '2025-11-01', NULL, 'online');
-- Expected error: permission denied for function fn_plan_next_session

RESET ROLE;
