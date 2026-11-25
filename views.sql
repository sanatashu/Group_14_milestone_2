SET search_path TO pt_studio_group_14;

DROP VIEW IF EXISTS v_session_brief;
DROP VIEW IF EXISTS v_client_progress;


-- view 1: v_session_brief (for Sara)
-- one row per client, including clients with no session yet.

CREATE VIEW v_session_brief AS
SELECT
    c.client_id,
    c.client_name,
    cp.program_name,
    cp.program_type,
    ii.goal_notes,
    ii.health_notes,
    ii.assessment_notes,
    ii.coaching_notes,
    ls.session_date AS last_session_date,
    ls.attendance_type AS last_session_mode,
    ls.presession_notes AS last_presession_notes,
    ls.postsession_notes AS last_postsession_notes,
    CASE WHEN ls.session_id IS NULL THEN NULL
         ELSE ch.exercises_changed END AS exercises_changed,
    ch.changes AS exercise_changes
FROM client c

-- current program
LEFT JOIN LATERAL (
    SELECT p.program_name, p.program_type
    FROM program_status ps
    JOIN program p ON p.program_id = ps.program_id
    WHERE ps.client_id = c.client_id
      AND ps.status = 'In-progress'
    ORDER BY ps.enrollment_date DESC NULLS LAST, ps.program_id DESC
    LIMIT 1
) cp ON TRUE

-- latest intake
LEFT JOIN LATERAL (
    SELECT i.goal_notes, i.health_notes, i.assessment_notes, i.coaching_notes
    FROM intake_info i
    WHERE i.client_id = c.client_id
    ORDER BY i.intake_date DESC NULLS LAST, i.intake_id DESC
    LIMIT 1
) ii ON TRUE

-- last session that actually happened
LEFT JOIN LATERAL (
    SELECT ws.session_id, ws.session_date, ws.attendance_type,
           ws.presession_notes, ws.postsession_notes
    FROM workout_session ws
    WHERE ws.client_id = c.client_id
      AND ws.status = 'attended'
    ORDER BY ws.session_date DESC, ws.session_id DESC
    LIMIT 1
) ls ON TRUE

-- exercises changed in that session (anything that wasn't completed as planned)
LEFT JOIN LATERAL (
    SELECT
        COUNT(*) FILTER (WHERE sep.status <> 'completed') AS exercises_changed,
        string_agg(
            sep.exercise_name || ' (' || sep.status ||
            CASE WHEN sep.substituted_for IS NOT NULL
                 THEN ' for ' || sep.substituted_for ELSE '' END || ')',
            '; ' ORDER BY sep.exercise_order
        ) FILTER (WHERE sep.status <> 'completed') AS changes
    FROM session_exercise_performed sep
    WHERE sep.session_id = ls.session_id
) ch ON TRUE;

-- sample 1
SELECT client_name, program_name, last_session_date, last_session_mode, exercises_changed
FROM v_session_brief
ORDER BY last_session_date DESC NULLS LAST, client_name;

-- sample 2
SELECT client_name, health_notes, exercise_changes, last_postsession_notes
FROM v_session_brief
WHERE exercises_changed > 0
ORDER BY last_session_date DESC;


-- view 2: v_client_progress (for the client app)
-- every row carries client_id. the app must filter on it (see the Decisions Log)
-- no names, contact details, or notes of any kind are exposed
-- the WHERE at the bottom decides which rows each login sees:
--   * a client login sees only its own client's rows (client.login_name = current_user)
--   * the schema owner and g14_trainer (Sara) see every client
--   * any other login sees nothing
-- current_user is the login running the query, even inside a view.
-- security_barrier makes PostgreSQL apply this WHERE before any condition
-- the user adds, so a user's own WHERE can't peek at other clients' rows.

CREATE VIEW v_client_progress WITH (security_barrier = true) AS
SELECT p.*
FROM (

-- body and fitness measurements from checkins
SELECT e.client_id,
       'measurement'::text AS record_type,
       e.checkin_date AS record_date,
       e.week_number,
       mm.metric_name,
       mm.side,
       NULL::integer AS set_number,
       mm.measurement AS value,
       mm.unit,
       NULL::integer AS reps,
       mm.is_relative,
       NULL::text AS set_status
FROM progress_checkin_entry e
JOIN progress_checkin_entry_metric_measured mm ON mm.checkin_id = e.checkin_id
UNION ALL

-- strength results from check-ins and pr pages
SELECT e.client_id, 'strength_result', e.checkin_date, e.week_number,
       sr.metric_name, sr.side, NULL, sr.weight_lbs, 'lbs', sr.reps, FALSE, NULL
FROM progress_checkin_entry e
JOIN progress_checkin_entry_metric_set_rep sr ON sr.checkin_id = e.checkin_id
UNION ALL

-- every set logged in the client's own sessions
SELECT ws.client_id, 'workout_set', ws.session_date, NULL,
       s.exercise_name, 'n/a', s.set_count, s.weight_lbs,
       CASE WHEN s.weight_lbs IS NULL THEN NULL ELSE 'lbs' END,
       s.reps, FALSE, s.set_status
FROM workout_session ws
JOIN session_exercise_performed_set s ON s.session_id = ws.session_id
UNION ALL

-- cardio work in the client's own sessions
SELECT ws.client_id, 'cardio', ws.session_date, NULL,
       t.exercise_name, 'n/a', NULL, t.duration_seconds, 's', NULL, FALSE, NULL
FROM workout_session ws
JOIN session_exercise_performed_timed t ON t.session_id = ws.session_id

) p
WHERE
    p.client_id IN (SELECT c.client_id FROM client c WHERE c.login_name = current_user)
    OR pg_has_role((SELECT nspowner FROM pg_namespace WHERE nspname = 'pt_studio_group_14'), 'USAGE')
    OR EXISTS (SELECT 1 FROM pg_roles r
               WHERE r.rolname = 'g14_trainer' AND pg_has_role(r.oid, 'USAGE'));

-- sample 1
SELECT record_date, metric_name, value, unit
FROM v_client_progress
WHERE client_id = 2 AND record_type = 'measurement'
ORDER BY record_date NULLS FIRST, metric_name;

-- sample 2
SELECT record_type, metric_name, set_number, value, unit, reps
FROM v_client_progress
WHERE client_id = 2 AND record_date = DATE '2025-10-19'
ORDER BY metric_name, set_number;
