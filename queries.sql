SET search_path TO pt_studio_group_14;

-- Q1.1 Last Time: "What did Alex do last time?"
SELECT
    c.client_name,
    ws.session_date,
    sep.exercise_name,
    sep.status,
    s.set_count as set_num,
    s.reps,
    s.weight_lbs,
    s.note
    FROM workout_session ws
    JOIN client c ON c.client_id = ws.client_id
    JOIN session_exercise_performed sep ON sep.session_id = ws.session_id
    LEFT JOIN session_exercise_performed_set s
        ON  s.session_id = sep.session_id
        AND s.exercise_name = sep.exercise_name
	WHERE c.client_name = 'Alex M.'
	AND ws.session_date = ( SELECT MAX(ws2.session_date)
							FROM workout_session ws2
						    WHERE ws2.client_id = ws.client_id
							AND ws2.status = 'attended');

-- Q1.2 Program Progress: "How much of each program is done?"
SELECT
    c.client_name,
    p.program_name,
    p.duration_weeks * (p.planned_in_person_sessions + p.planned_online_sessions) AS planned_sessions,
    COUNT(ws.session_id) AS sessions_logged,
    ROUND(100.0 * COUNT(ws.session_id) / (p.duration_weeks * (p.planned_in_person_sessions + p.planned_online_sessions)), 1) AS percent_complete
	FROM program_status ps
	JOIN client c ON c.client_id = ps.client_id
	JOIN program p ON p.program_id = ps.program_id
	LEFT JOIN workout_session ws
	    ON  ws.client_id  = ps.client_id
	    AND ws.program_id = ps.program_id
	    AND ws.status     = 'attended'
	GROUP BY c.client_name, p.program_name, p.duration_weeks,
	         p.planned_in_person_sessions, p.planned_online_sessions
	ORDER BY percent_complete DESC, c.client_name;


-- Q1.3 Training Volume: "How hard was each session?"
-- Decision on bodyweight: set with no load still counts toward sets and reps but adds 0 lbs to total vol
SELECT
    c.client_name,
    ws.session_date,
    COUNT(s.set_count) FILTER (WHERE s.set_status = 'completed') AS completed_sets,
    COALESCE(SUM(s.reps), 0) AS total_reps,
    COALESCE(SUM(s.reps * COALESCE(s.weight_lbs, 0)), 0) AS total_volume_lbs
	FROM workout_session ws
	JOIN client c ON c.client_id = ws.client_id
	LEFT JOIN session_exercise_performed_set s ON s.session_id = ws.session_id
	WHERE ws.status = 'attended'
	GROUP BY ws.session_id, c.client_name, ws.session_date
	ORDER BY ws.session_date, c.client_name;


-- Q1.4 Jordan's Trend: "Show Jordan she's getting results."
SELECT
    c.client_name,
    e.checkin_date,
    m.metric_name,
    mm.measurement,
    mm.unit,
    mm.measurement - FIRST_VALUE(mm.measurement) OVER (PARTITION BY m.metric_name, m.side ORDER BY e.checkin_date) AS change_since_first
	FROM progress_checkin_entry e
	JOIN client c ON c.client_id = e.client_id
	JOIN progress_checkin_entry_metric m ON m.checkin_id = e.checkin_id
	JOIN progress_checkin_entry_metric_measured mm
	    ON  mm.checkin_id  = m.checkin_id
	    AND mm.metric_name = m.metric_name
	    AND mm.side        = m.side
	WHERE c.client_name = 'Jordan T.' AND e.checkin_date IS NOT NULL
	ORDER BY e.checkin_date, m.metric_name;


-- Q1.5 Goal Tracker: "How far away am I?"
-- We don't have a formal "goals" table so we must construct a temporary one. 
-- goals are found from free text in intake_info.goal_notes and program_phase.phase_exercise_notes
-- goals are entered by hand

WITH goals (client_name, metric_name, target_value, target_change, goal_source) AS (
    VALUES
        ('Alex M.',   'Deadlift',    375,  NULL, 'Phase 2 note: target DL 375 lbs by Wk 8'),
        ('Alex M.',   'Deadlift',    385,  NULL, 'Phase 3 note: test DL PR 385+ lbs'),
        ('Jordan T.', 'Body Weight', NULL, -20,  'Intake goal: lose 20 lbs')
),
metric_values AS (
    SELECT
        e.client_id,
        m.metric_name,
        e.checkin_date,
        e.checkin_type,
        COALESCE(sr.weight_lbs, mm.measurement) AS value
    FROM progress_checkin_entry e
    JOIN progress_checkin_entry_metric m ON m.checkin_id = e.checkin_id
    LEFT JOIN progress_checkin_entry_metric_set_rep sr
        ON  sr.checkin_id  = m.checkin_id
        AND sr.metric_name = m.metric_name
        AND sr.side        = m.side
    LEFT JOIN progress_checkin_entry_metric_measured mm
        ON  mm.checkin_id  = m.checkin_id
        AND mm.metric_name = m.metric_name
        AND mm.side        = m.side
),
starting AS (
    SELECT client_id, metric_name, value AS start_value
    FROM metric_values
    WHERE checkin_type = 'baseline'
),
latest AS (
    SELECT DISTINCT ON (client_id, metric_name) client_id, metric_name, checkin_date AS latest_date, value AS latest_value
    FROM metric_values
    WHERE checkin_date IS NOT NULL
    ORDER BY client_id, metric_name, checkin_date DESC
)

SELECT
    g.client_name,
    g.metric_name,
    g.goal_source,
    COALESCE(g.target_value, st.start_value + g.target_change) AS target_value,
    st.start_value,
    l.latest_value,
    l.latest_date,
    ROUND(100.0 * (l.latest_value - st.start_value) / (COALESCE(g.target_value, st.start_value + g.target_change) - st.start_value), 1) AS pct_of_the_way
	FROM goals g
	JOIN client c ON c.client_name = g.client_name
	JOIN starting st
	    ON  st.client_id   = c.client_id
	    AND st.metric_name = g.metric_name
	JOIN latest l
	    ON  l.client_id   = c.client_id
	    AND l.metric_name = g.metric_name
	ORDER BY g.client_name, target_value;


-- Q1.6 Changed Exercises: "Which clients keep having to change their workout?"
SELECT
    c.client_name,
    sep.exercise_name,
    sep.status AS change_type,
    sep.substituted_for,
    COUNT(*) AS times_changed
	FROM client c
	JOIN workout_session ws ON ws.client_id = c.client_id
	JOIN session_exercise_performed sep ON sep.session_id = ws.session_id
	WHERE ws.status = 'attended' AND sep.status NOT IN ('completed', 'planned')
	GROUP BY c.client_name, sep.exercise_name, sep.status, sep.substituted_for
	HAVING COUNT(*) >= 1
	ORDER BY times_changed DESC, c.client_name, sep.exercise_name;

