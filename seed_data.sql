SET search_path TO pt_studio_group_14;

INSERT INTO trainer (trainer_id, name) VALUES
    (1, 'Sara');

INSERT INTO client (client_id, client_name, email, phone_number) VALUES
    (1, 'Alex M.', 'alex.m@email.com', '555-0192'),
    (2, 'Jordan T.', NULL, '555-0144'),
    (3, 'Maya L.', 'maya.l@email.com', NULL),
    (4, 'Sam R.', NULL, NULL),
    (5, 'Casey P.', NULL, NULL);

INSERT INTO intake_info (intake_id, client_id, intake_date, age_at_intake, goal_notes, health_notes, assessment_notes, coaching_notes) VALUES
    (1, 1, NULL, 28, 'Increase bench/deadlift, build mass.', 'Lower back tight >90% 1RM.', 'Squat depth solid, bench setup good.', 'Tech-savvy & competitive.'),
    (2, 2, NULL, 42, 'Lose 20 lbs, build energy.', 'Mild R knee ache on deep stairs.', NULL, 'Needs encouraging check-ins.'),
    (3, 3, NULL, 34, 'Rebuild L quad & knee stability.', 'L ACL repair 7 mos ago. Stiff >30m walk.', 'CAUTION with lateral moves!', NULL);

INSERT INTO exercise (name) VALUES
    -- Alex
    ('Back Squat'), ('Bench Press'), ('Barbell Row'), ('Overhead Press'), ('Romanian Deadlift'), ('Deadlift'), ('Incline Press'),
    -- Jordan
    ('Goblet Squat'), ('Dumbbell Row'), ('Push-up'), ('Plank'), ('Incline Treadmill Walk'), ('Step-up'), ('Cable Pulldown'),
    -- Maya
    ('Spanish Squat'), ('Step-Down'), ('Glute Bridge'), ('Hamstring Curl'),
    -- Session logs
    ('KB Goblet Squat'), ('DB Goblet Squat'), ('Dumbbell RDL'), ('Forward Lunge'), ('TRX Assisted Squat'), ('DB Standing OHP'), ('Seated Cable Row');

INSERT INTO program (program_id, program_name, program_category, program_type, program_notes) VALUES
    (1, '12-Week Heavy Strength Build', 'Strength & Conditioning', 'Advanced', 'Custom periodized plan tailored to competitive strength goals.'),
    (2, '8-Week Body Recomp & Toning', 'Weight Loss & Wellness', 'Beginner', 'Focus on body weight and waist/hip circumference reduction.'),
    (3, '4-Week L Knee Stability Phase 1', 'Post-Injury Rehab', 'Rehab', 'Red pen: If knee swelling occurs post-session, reduce box height immediately!');

INSERT INTO program_phase (program_id, phase_index, phase_name, start_week, end_week, phase_exercise_notes) VALUES
    (1, 1, 'Base & Volume', 1,  4, NULL),
    (1, 2, 'Heavy Strength', 5,  8, '5x5 main lifts. Target DL 375 lbs by Wk 8.'),
    (1, 3, 'Peak & PR',  9, 12, 'Wk 9 deload; Wks 10-12 singles/triples.'),
    (2, 1, 'Full Body Circuit', 1,  4, NULL),
    (2, 2, 'Progressive Conditioning', 5,  8, 'Increase DB weights. Weekly Tue weight check.'),
    (3, 1, NULL, 1,  4, NULL);


INSERT INTO program_phase_exercise (program_id, phase_index, exercise_name, note) VALUES
    -- Alex, Phase 1
    (1, 1, 'Back Squat', NULL),
    (1, 1, 'Bench Press',  NULL),
    (1, 1, 'Barbell Row',  NULL),
    (1, 1, 'Overhead Press', NULL),
    (1, 1, 'Romanian Deadlift', NULL),
    (1, 1, 'Deadlift',  NULL),
    (1, 1, 'Incline Press', NULL),
	--Alex, Phase 2
	(1, 2, 'Deadlift',  NULL), -- Interpreted from "5x5 main lifts"
    -- Jordan, Phase 1
    (2, 1, 'Goblet Squat', NULL),
    (2, 1, 'Dumbbell Row', NULL),
    (2, 1, 'Push-up', NULL),
    (2, 1, 'Plank', NULL),
    (2, 1, 'Incline Treadmill Walk', NULL),
    -- Jordan, Phase 2
    (2, 2, 'Step-up',        'Added in Phase 2.'),
    (2, 2, 'Cable Pulldown', 'Added in Phase 2.'),
    -- Maya, Phase 1
    (3, 1, 'Spanish Squat',  'Hold.'),
    (3, 1, 'Step-Down',      'Off 4" box.'),
    (3, 1, 'Glute Bridge',   'With band.'),
    (3, 1, 'Hamstring Curl', NULL);

-- Training days (multi-valued)
INSERT INTO program_phase_exercise_day (program_id, phase_index, exercise_name, day_of_week) VALUES
    (1, 1, 'Back Squat', 'Mon'),
    (1, 1, 'Bench Press', 'Mon'),
    (1, 1, 'Barbell Row', 'Mon'),
    (1, 1, 'Overhead Press', 'Wed'),
    (1, 1, 'Romanian Deadlift', 'Wed'),
    (1, 1, 'Deadlift', 'Fri'),
    (1, 1, 'Incline Press', 'Fri'),
    (2, 1, 'Goblet Squat', 'Tue'), (2, 1, 'Goblet Squat','Thu'),
    (2, 1, 'Dumbbell Row', 'Tue'), (2, 1, 'Dumbbell Row',  'Thu'),
    (2, 1, 'Push-up', 'Tue'), (2, 1, 'Push-up', 'Thu'),
    (2, 1, 'Plank', 'Tue'), (2, 1, 'Plank', 'Thu'),
    (2, 1, 'Incline Treadmill Walk', 'Tue'), (2, 1, 'Incline Treadmill Walk', 'Thu');

-- Set/rep prescriptions
INSERT INTO program_phase_exercise_set_rep (program_id, phase_index, exercise_name, set_count, rep_min, rep_max, per_side) VALUES
    (1, 1, 'Back Squat',        4,  8,  8, FALSE),
    (1, 1, 'Bench Press',       4,  8,  8, FALSE),
    (1, 1, 'Barbell Row',       4,  8,  8, FALSE),
    (1, 1, 'Overhead Press',    4,  8,  8, FALSE),
    (1, 1, 'Romanian Deadlift', 3, 10, 10, FALSE),
    (1, 1, 'Deadlift',          3,  5,  5, FALSE),
    (1, 1, 'Incline Press',     3,  8,  8, FALSE),
	(1, 2, 'Deadlift',          3,  5,  5, FALSE), -- Interpreted from "5x5 main lifts"
    (2, 1, 'Goblet Squat',      3, 10, 10, FALSE),
    (2, 1, 'Dumbbell Row',      3, 12, 12, FALSE),
    (2, 1, 'Push-up',           3,  8, 10, FALSE),
    (3, 1, 'Step-Down',         3, 10, 10, TRUE),
    (3, 1, 'Glute Bridge',      3, 15, 15, FALSE),
    (3, 1, 'Hamstring Curl',    3, 12, 12, FALSE);


-- Timed exercises (seconds)
INSERT INTO program_phase_exercise_timed (program_id, phase_index, exercise_name, set_count, duration_seconds) VALUES
    (2, 1, 'Plank',3, 30),
    (2, 1, 'Incline Treadmill Walk', NULL, 600),   -- 10 mins
    (3, 1, 'Spanish Squat', 3, 45);


INSERT INTO program_status (client_id, program_id, enrollment_date, status, current_phase, weekly_in_person_sessions, weekly_online_sessions) VALUES
    (1, 1, NULL, 'In-progress', NULL, 3, 0),
    (2, 2, NULL, 'In-progress', NULL, 2, 0),
    (3, 3, NULL, 'In-progress', NULL, 2, 1);

-----------------------------
-- WORKOUT LOGS
-----------------------------
INSERT INTO workout_session(session_id, client_id, session_date, start_time, end_time, attendance_type, status, program_id, phase_index, trainer_id, presession_notes, postsession_notes) VALUES
    (1, 1, '2025-10-16', '16:00', NULL, 'in-person', 'attended', 1, NULL, 1, 'Lower back tight from moving furniture over weekend. Skipping heavy back squats!', 'Great energy. Back didn''t bother him on deadlifts with belt. Stoked about 375x3!'),
    (2, 4, '2025-10-18', NULL,    NULL, 'online',    'attended', NULL, NULL, 1, 'Logged from client email/text report.', 'Red Pen Note: Texted Sam for RDL hip hinge video before next week. Keep at 30 lbs until form checked.'),
    (3, 2, '2025-10-19', '10:00', NULL, 'in-person', 'attended', 2, NULL, 1, 'R knee aching during lunge warmup.', 'Felt accomplished despite knee tweak. Reminded her to ice knee tonight!');


INSERT INTO session_exercise_performed (session_id, exercise_name, exercise_order, status, substituted_for, planned_sets, planned_reps, notes) VALUES
    -- Alex
    (1, 'KB Goblet Squat',    1, 'substituted', 'Back Squat',    NULL, NULL, 'Subbed for heavy back squats (lower back tight).'),
    (1, 'Deadlift',           2, 'completed',   NULL,            NULL, NULL, NULL),
    (1, 'Bench Press',        3, 'completed',   NULL,            NULL, NULL, NULL),
    (1, 'Barbell Row',        4, 'completed',   NULL,            NULL, NULL, NULL),
    -- Sam
    (2, 'DB Goblet Squat',    1, 'completed',   NULL,            NULL, NULL, 'smooth'),
    (2, 'Push-up',            2, 'completed',   NULL,            NULL, NULL, 'last 2 reps hard'),
    (2, 'Dumbbell RDL',       3, 'completed',   NULL,            NULL, NULL, NULL),
    -- Jordan
    (3, 'Forward Lunge',      1, 'scratched',   NULL,            3,    10,   'SCRATCHED: R knee aching.'),
    (3, 'TRX Assisted Squat', 2, 'substituted', 'Forward Lunge', NULL, NULL, 'zero pain'),
    (3, 'DB Standing OHP',    3, 'completed',   NULL,            NULL, NULL, NULL),
    (3, 'Seated Cable Row',   4, 'completed',   NULL,            NULL, NULL, NULL),
    (3, 'Incline Treadmill Walk', 5, 'completed', NULL,          NULL, NULL, NULL);

-- One row per set.
INSERT INTO session_exercise_performed_set (session_id, exercise_name, set_count, reps, weight_lbs, note) VALUES
    -- Alex
    (1, 'KB Goblet Squat', 1, 10,  53, NULL),
    (1, 'KB Goblet Squat', 2, 10,  53, NULL),
    (1, 'KB Goblet Squat', 3, 10,  53, NULL),
    (1, 'Deadlift',        1,  5, 135, NULL),
    (1, 'Deadlift',        2,  5, 225, NULL),
    (1, 'Deadlift',        3,  3, 315, NULL),
    (1, 'Deadlift',        4,  5, 365, NULL),
    (1, 'Deadlift',        5,  3, 375, 'PR!'),
    (1, 'Bench Press',     1,  8, 135, NULL),
    (1, 'Bench Press',     2,  5, 185, NULL),
    (1, 'Bench Press',     3,  5, 225, NULL),
    (1, 'Bench Press',     4,  5, 225, NULL),
    (1, 'Barbell Row',     1,  8, 135, NULL),
    (1, 'Barbell Row',     2,  8, 185, NULL),
    (1, 'Barbell Row',     3,  8, 185, NULL),
    -- Sam
    (2, 'DB Goblet Squat', 1, 10,  40, NULL),
    (2, 'DB Goblet Squat', 2, 10,  40, NULL),
    (2, 'DB Goblet Squat', 3, 10,  40, NULL),
    (2, 'Push-up',         1, 12, NULL, NULL),
    (2, 'Push-up',         2, 12, NULL, NULL),
    (2, 'Push-up',         3, 12, NULL, NULL),
    (2, 'Dumbbell RDL',    1, 10,  30, NULL),
    (2, 'Dumbbell RDL',    2, 10,  30, NULL),
    (2, 'Dumbbell RDL',    3, 10,  30, 'Slight hamstring pull on set 3, stopped.'),
    -- Jordan
    (3, 'TRX Assisted Squat', 1, 12, NULL, NULL),
    (3, 'TRX Assisted Squat', 2, 12, NULL, NULL),
    (3, 'TRX Assisted Squat', 3, 12, NULL, NULL),
    (3, 'DB Standing OHP',    1, 10,   12, NULL),
    (3, 'DB Standing OHP',    2, 10,   12, NULL),
    (3, 'DB Standing OHP',    3, 10,   12, NULL),
    (3, 'Seated Cable Row',   1, 12,   50, NULL),
    (3, 'Seated Cable Row',   2, 12,   50, NULL),
    (3, 'Seated Cable Row',   3, 12,   50, NULL);

INSERT INTO session_exercise_performed_timed (session_id, exercise_name, duration_seconds, speed_mph, incline_pct) VALUES
    (3, 'Incline Treadmill Walk', 720, 3.2, 4.0);   -- 12 mins, 3.2 mph, 4% incline

-----------------------------
-- PROGRESS CHECK IN ENTRIES
-----------------------------
INSERT INTO progress_checkin_entry
    (checkin_id, client_id, checkin_date, checkin_type, intake_id, week_number, notes) VALUES
    -- Intake baselines
    (1, 1, NULL, 'baseline', 1, NULL, 'Baseline assessment at intake.'),  
    (2, 2, NULL, 'baseline', 2, NULL, 'Baseline assessment at intake.'),
    (3, 3, NULL, 'baseline', 3, NULL, 'Baseline assessment at intake.'),
    -- Jordan: Progress Tracker
    (4, 2, '2025-11-03', 'progress', NULL, 1, NULL), -- Does the Check-in Header need to be inserted as part of the data as well? or is marking something as 'progress' ok?
    (5, 2, '2025-11-17', 'progress', NULL, 3, NULL),
    (6, 2, '2025-12-15', 'progress', NULL, 6, 'Down 8 lbs and 1.5 inches off waist & hips in 6 weeks! Jordan was glowing seeing scale & looser jeans. Needs visual proof to stay on track.'),
    -- Alex: PR Record Page
    (7,  1, '2025-08-14', 'pr', NULL, NULL, NULL),
    (8,  1, '2025-09-10', 'pr', NULL, NULL, NULL),
    (9,  1, '2025-10-16', 'pr', NULL, NULL, NULL),
    (10, 1, '2025-10-30', 'pr', NULL, NULL, 'DL form clean, hips didn''t shoot up early. Huge milestone. Alex kept asking if we can graph this on a line chart!'),
    -- Casey: Tennis Conditioning Metrics
    (11, 5, NULL, 'baseline', NULL, NULL, 'Tennis Conditioning Metrics: baseline (date not recorded).'),
    (12, 5, '2025-11-02', 'assessment', NULL, NULL, 'Tennis Conditioning Metrics. Casey reported: ''My serve feels faster and shoulder isn''t sore after 3 sets.'' Thrilled about court results!');


-- Metric parent rows
INSERT INTO progress_checkin_entry_metric (checkin_id, metric_name, side, load_lbs, note) VALUES
    (1,  'Deadlift',                         'n/a', NULL, 'Baseline Deadlift; reps not recorded.'),
    (2,  'Body Weight',                      'n/a', NULL, NULL),
    (2,  'Waist',                            'n/a', NULL, NULL),
    (2,  'Hips',                             'n/a', NULL, NULL),
    (3,  'Single-Leg Balance',               'L', NULL, 'Weak L.'),
    (3,  'Single-Leg Balance',               'R', NULL, NULL),
    (3,  'Knee Extension',                   'L', NULL, NULL),
    (3,  'Knee Flexion',                     'L', NULL, 'full'),
    (4,  'Body Weight',                      'n/a', NULL, NULL),
    (4,  'Waist',                            'n/a', NULL, NULL),
    (4,  'Hips',                             'n/a', NULL, NULL),
    (5,  'Body Weight',                      'n/a', NULL, NULL),
    (5,  'Waist',                            'n/a', NULL, NULL),
    (5,  'Hips',                             'n/a', NULL, NULL),
    (6,  'Body Weight',                      'n/a', NULL, NULL),
    (6,  'Waist',                            'n/a', NULL, NULL),
    (6,  'Hips',                             'n/a', NULL, NULL),
    (7,  'Deadlift',                         'n/a', NULL, NULL),
    (8,  'Bench Press',                      'n/a', NULL, NULL),
    (9,  'Deadlift',                         'n/a', NULL, NULL),
    (10, 'Deadlift',                         'n/a', NULL, 'NEW PR!'), -- new PR note on the specifc metric
    (10, 'Bench Press',                      'n/a', NULL, NULL),
    (11, 'Rotational Med-Ball Throw', 'n/a', 12, 'Baseline.'),  
    (12, 'Rotational Med-Ball Throw', 'n/a', 12, '+22% power'),
    (12, 'Single-Leg Balance',               'L', NULL, 'Up from ~20s.'),
    (12, 'Single-Leg Balance',               'R', NULL, 'Up from ~20s.'),
    (12, 'Shoulder Mobility (overhead reach)', 'R', NULL, NULL);  


-- Strength results
INSERT INTO progress_checkin_entry_metric_set_rep (checkin_id, metric_name, side, weight_lbs, reps) VALUES
    (1,  'Deadlift',    'n/a', 360, NULL),
    (7,  'Deadlift',    'n/a', 365, 1),
    (8,  'Bench Press', 'n/a', 225, 3),
    (9,  'Deadlift',    'n/a', 375, 3),
    (10, 'Deadlift',    'n/a', 385, 1), -- this is the new pr record
    (10, 'Bench Press', 'n/a', 225, 5);


-- Measurements
INSERT INTO progress_checkin_entry_metric_measured (checkin_id, metric_name, side, measurement, unit, is_relative) VALUES
    (2,  'Body Weight', 'n/a', 192,  'lbs', FALSE),
    (2,  'Waist',       'n/a', 36,   'in',  FALSE),
    (2,  'Hips',        'n/a', 41,   'in',  FALSE),
    (3,  'Single-Leg Balance', 'L', 12, 's',   FALSE),
    (3,  'Single-Leg Balance', 'R', 40, 's',   FALSE),
    (3,  'Knee Extension',     'L', -2, 'deg', FALSE),
    (4,  'Body Weight', 'n/a', 192,  'lbs', FALSE),
    (4,  'Waist',       'n/a', 36,   'in',  FALSE),
    (4,  'Hips',        'n/a', 41,   'in',  FALSE),
    (5,  'Body Weight', 'n/a', 189,  'lbs', FALSE),
    (5,  'Waist',       'n/a', 35.5, 'in',  FALSE),
    (5,  'Hips',        'n/a', 40.5, 'in',  FALSE),
    (6,  'Body Weight', 'n/a', 184,  'lbs', FALSE),
    (6,  'Waist',       'n/a', 34.5, 'in',  FALSE),
    (6,  'Hips',        'n/a', 39.5, 'in',  FALSE),
    (11, 'Rotational Med-Ball Throw', 'n/a', 18, 'ft', FALSE),
    (12, 'Rotational Med-Ball Throw', 'n/a', 22, 'ft', FALSE),
    (12, 'Single-Leg Balance', 'L', 42, 's', FALSE),
    (12, 'Single-Leg Balance', 'R', 45, 's', FALSE),
    (12, 'Shoulder Mobility (overhead reach)', 'R', 10, 'deg', TRUE);

