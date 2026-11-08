SET search_path TO pt_studio_group_14;

-- PART A:

-- Workout & Exercise History
SELECT
    c.client_name,
    ws.session_date,
    ws.attendance_type,
    ws.status AS session_status,
    sep.exercise_order,
    sep.exercise_name,
    sep.status AS exercise_status,
    sep.substituted_for,
    sep.planned_sets,
    sep.planned_reps,
    COUNT(s.set_count) OVER (PARTITION BY sep.session_id, sep.exercise_name) AS actual_sets,
    s.set_count AS set_number,
    s.reps AS actual_reps,
    s.weight_lbs,
    s.note AS set_note,
    t.duration_seconds,
    t.speed_mph,
    t.incline_pct,
    t.distance_miles,
    sep.notes AS exercise_notes,
    ws.presession_notes,
    ws.postsession_notes
	FROM workout_session ws
	JOIN client c
	    ON c.client_id = ws.client_id
	JOIN session_exercise_performed sep
	    ON sep.session_id = ws.session_id
	LEFT JOIN session_exercise_performed_set s
	    ON  s.session_id = sep.session_id
	    AND s.exercise_name = sep.exercise_name
	LEFT JOIN session_exercise_performed_timed t
	    ON  t.session_id = sep.session_id
	    AND t.exercise_name = sep.exercise_name
	ORDER BY c.client_name, ws.session_date, sep.exercise_order, s.set_count;


-- Program Schedule & Phase Timeline
SELECT
    c.client_name,
    p.program_name,
    p.program_type,
    ps.status,
    ps.enrollment_date,
    ps.weekly_in_person_sessions,
    ps.weekly_online_sessions,
    pp.phase_index,
    COALESCE(pp.phase_name, '(unnamed phase)') AS phase_name,
    pp.start_week,
    pp.end_week,
    (pp.end_week - pp.start_week + 1) AS weeks_in_phase,
    (pp.phase_index = ps.current_phase) AS is_current_phase,
    pp.phase_exercise_notes
	FROM program_status ps
	JOIN client c 
		ON c.client_id  = ps.client_id
	JOIN program p 
		ON p.program_id = ps.program_id
	JOIN program_phase pp 
		ON pp.program_id = ps.program_id
	WHERE ps.status = 'In-progress'
	ORDER BY c.client_name, pp.phase_index;


-- Progress Trend History
SELECT
    c.client_name,
    e.checkin_date,
    e.checkin_type,
    e.week_number,
    m.metric_name,
    m.side,
    mm.measurement,
    mm.unit,
    mm.is_relative,
    sr.weight_lbs AS strength_weight_lbs,
    sr.reps AS strength_reps,
    m.load_lbs,
    m.note AS metric_note,
    e.notes AS checkin_notes
	FROM progress_checkin_entry e
	JOIN client c
	    ON c.client_id = e.client_id
	JOIN progress_checkin_entry_metric m
	    ON m.checkin_id = e.checkin_id
	LEFT JOIN progress_checkin_entry_metric_measured mm
	    ON  mm.checkin_id  = m.checkin_id
	    AND mm.metric_name = m.metric_name
	    AND mm.side        = m.side
	LEFT JOIN progress_checkin_entry_metric_set_rep sr
	    ON  sr.checkin_id  = m.checkin_id
	    AND sr.metric_name = m.metric_name
	    AND sr.side        = m.side
	ORDER BY c.client_name, e.checkin_date NULLS FIRST, e.checkin_id, m.metric_name, m.side;


-- PART B: DATA INTEGRITY GUARDRAIL PROOFS (negative tests)
-- Uncomment and run one at a time


-- Test 1a: Duplicate candidate key. Alex already has a session on 2025-10-16.
-- Expected Error: duplicate key value violates unique constraint "workout_session_client_id_session_date_key"

-- INSERT INTO workout_session
-- (session_id, client_id, session_date, attendance_type, trainer_id)
-- VALUES (99, 1, '2025-10-16', 'in-person', 1);



-- Test 1b: Duplicate candidate key on email.
-- Expected Error: duplicate key value violates unique constraint "client_email_key"

-- INSERT INTO client (client_id, client_name, email)
-- VALUES (99, 'Dup Client', 'alex.m@email.com');



-- Test 2a: Unapproved status value.
-- Expected Error: new row for relation "workout_session" violates check constraint "workout_session_status_check"

-- INSERT INTO workout_session
-- (session_id, client_id, session_date, attendance_type, status, trainer_id)
-- VALUES (99, 1, '2025-12-01', 'in-person', 'no-show', 1);



-- Test 2b: Business rule: more than 7 weekly sessions.
-- Expected Error: new row for relation "program_status" violates check constraint "chk_weekly_sessions_max"

-- INSERT INTO program_status
-- (client_id, program_id, status, weekly_in_person_sessions, weekly_online_sessions)
-- VALUES (4, 1, 'In-progress', 5, 5);



-- Test 2c: A "substituted" exercise with no substituted_for.
-- Expected Error: new row for relation "session_exercise_performed" violates check constraint "check_sub_filled_when_status_is_substituted"

-- INSERT INTO session_exercise_performed
-- (session_id, exercise_name, exercise_order, status, substituted_for)
-- VALUES (1, 'Incline Press', 9, 'substituted', NULL);



-- Test 3a: Orphaned child record. Session 999 doesn't exist.
-- Expected Error: insert or update on table "session_exercise_performed" violates foreign key constraint "session_exercise_performed_session_id_fkey"

-- INSERT INTO session_exercise_performed
-- (session_id, exercise_name, exercise_order)
-- VALUES (999, 'Deadlift', 1);



-- Test 3b: Session for a client who isn't enrolled in the program. Casey (5)is not enrolled in program 1.
-- Expected Error: insert or update on table "workout_session" violates foreign key constraint "workout_session_client_id_program_id_fkey"

-- INSERT INTO workout_session
-- (session_id, client_id, session_date, attendance_type, program_id, trainer_id)
-- VALUES (99, 5, '2025-12-02', 'in-person', 1, 1);
