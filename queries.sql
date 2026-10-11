-- Clinical Trial Landscape Analysis (AACT database, PostgreSQL)
-- Schema: ctgov

-- Query 1: Trials per year (2016 onward)
SELECT 
    EXTRACT(YEAR FROM start_date) AS trial_year,
    COUNT(*) AS num_trials
FROM ctgov.studies
WHERE start_date >= '2016-01-01'
GROUP BY trial_year
ORDER BY trial_year;

-- Query 2: Phase distribution
SELECT 
    phase,
    COUNT(*) AS num_trials
FROM ctgov.studies
GROUP BY phase
ORDER BY num_trials DESC;

-- Query 3: Top 15 countries for industry-sponsored trials
SELECT 
    c.name AS country,
    COUNT(*) AS num_trials
FROM ctgov.countries c
JOIN ctgov.studies s ON c.nct_id = s.nct_id
WHERE s.source_class = 'INDUSTRY'
GROUP BY c.name
ORDER BY num_trials DESC
LIMIT 15;

-- Query 4: Sponsor class vs. phase
SELECT 
    st.source_class,
    st.phase,
    COUNT(*) AS num_trials
FROM ctgov.studies st
JOIN ctgov.sponsors s ON st.nct_id = s.nct_id
WHERE s.lead_or_collaborator = 'lead'
GROUP BY st.source_class, st.phase
ORDER BY st.source_class, num_trials DESC;

-- Query 5: Top conditions studied (trials starting 2021 onward)
SELECT 
    c.name AS condition_name,
    COUNT(*) AS num_trials
FROM ctgov.conditions c
JOIN ctgov.studies s ON c.nct_id = s.nct_id
WHERE s.start_date >= '2021-01-01'
GROUP BY c.name
ORDER BY num_trials DESC
LIMIT 20;

-- Query 5b: Same as Query 5, with COVID-19 naming variants merged
SELECT 
    CASE 
        WHEN LOWER(c.name) LIKE '%covid%' THEN 'COVID-19 (standardized)'
        ELSE c.name
    END AS condition_name,
    COUNT(*) AS num_trials
FROM ctgov.conditions c
JOIN ctgov.studies s ON c.nct_id = s.nct_id
WHERE s.start_date >= '2021-01-01'
GROUP BY 
    CASE 
        WHEN LOWER(c.name) LIKE '%covid%' THEN 'COVID-19 (standardized)'
        ELSE c.name
    END
ORDER BY num_trials DESC
LIMIT 20;

-- Query 6: Average enrollment by sponsor class and phase
SELECT 
    st.source_class,
    st.phase,
    ROUND(AVG(st.enrollment)) AS avg_enrollment
FROM ctgov.studies st
WHERE st.enrollment IS NOT NULL
GROUP BY st.source_class, st.phase
ORDER BY st.source_class, avg_enrollment DESC;

-- Query 7: Completion vs. termination by phase
SELECT 
    phase,
    overall_status,
    COUNT(*) AS num_trials
FROM ctgov.studies
WHERE overall_status IN ('COMPLETED', 'TERMINATED', 'WITHDRAWN', 'SUSPENDED')
GROUP BY phase, overall_status
ORDER BY phase, num_trials DESC;

-- Query 7b: Reasons Phase 2 trials were terminated
SELECT 
    LOWER(TRIM(why_stopped)) AS reason,
    COUNT(*) AS num_trials
FROM ctgov.studies
WHERE phase = 'PHASE2'
  AND overall_status = 'TERMINATED'
  AND why_stopped IS NOT NULL
GROUP BY LOWER(TRIM(why_stopped))
ORDER BY num_trials DESC
LIMIT 20;

-- Query 8: Top 10 lead sponsors (2020-2025) with year-over-year growth
WITH sponsor_year AS (
    SELECT 
        sp.name AS sponsor,
        EXTRACT(YEAR FROM st.start_date) AS trial_year,
        COUNT(*) AS num_trials
    FROM ctgov.sponsors sp
    JOIN ctgov.studies st ON sp.nct_id = st.nct_id
    WHERE sp.lead_or_collaborator = 'lead'
      AND st.start_date >= '2020-01-01'
      AND st.start_date < '2026-01-01'
    GROUP BY sp.name, EXTRACT(YEAR FROM st.start_date)
),
top_sponsors AS (
    SELECT sponsor
    FROM sponsor_year
    GROUP BY sponsor
    ORDER BY SUM(num_trials) DESC
    LIMIT 10
)
SELECT 
    sy.sponsor,
    sy.trial_year,
    sy.num_trials,
    LAG(sy.num_trials) OVER (PARTITION BY sy.sponsor ORDER BY sy.trial_year) AS prev_year_trials,
    ROUND(
        100.0 * (sy.num_trials - LAG(sy.num_trials) OVER (PARTITION BY sy.sponsor ORDER BY sy.trial_year))
        / NULLIF(LAG(sy.num_trials) OVER (PARTITION BY sy.sponsor ORDER BY sy.trial_year), 0),
        1
    ) AS yoy_growth_pct
FROM sponsor_year sy
JOIN top_sponsors ts ON sy.sponsor = ts.sponsor
ORDER BY sy.sponsor, sy.trial_year;

-- Query 9: Average duration of completed trials by condition (min. 200 trials per condition)
SELECT 
    c.name AS condition_name,
    COUNT(*) AS num_trials,
    ROUND(AVG((s.completion_date - s.start_date) / 30.44), 1) AS avg_duration_months
FROM ctgov.conditions c
JOIN ctgov.studies s ON c.nct_id = s.nct_id
WHERE s.overall_status = 'COMPLETED'
  AND s.start_date IS NOT NULL
  AND s.completion_date IS NOT NULL
  AND s.completion_date > s.start_date
  AND s.start_date >= '2010-01-01'
GROUP BY c.name
HAVING COUNT(*) >= 200
ORDER BY avg_duration_months DESC
LIMIT 20;

-- Query 10 (hero): Termination rate by condition + phase + sponsor class, with duration comparison
WITH finished AS (
    SELECT 
        s.nct_id,
        c.name AS condition_name,
        s.phase,
        s.source_class,
        s.overall_status,
        (s.completion_date - s.start_date) / 30.44 AS duration_months
    FROM ctgov.studies s
    JOIN ctgov.conditions c ON s.nct_id = c.nct_id
    WHERE s.overall_status IN ('COMPLETED', 'TERMINATED')
      AND s.phase IN ('PHASE1', 'PHASE2', 'PHASE3')
      AND s.source_class IN ('INDUSTRY', 'NIH', 'OTHER')
      AND s.start_date >= '2010-01-01'
      AND s.start_date IS NOT NULL
      AND s.completion_date IS NOT NULL
      AND s.completion_date > s.start_date
)
SELECT 
    condition_name,
    phase,
    source_class,
    COUNT(*) AS finished_trials,
    SUM(CASE WHEN overall_status = 'TERMINATED' THEN 1 ELSE 0 END) AS terminated_trials,
    ROUND(100.0 * SUM(CASE WHEN overall_status = 'TERMINATED' THEN 1 ELSE 0 END) / COUNT(*), 1) AS termination_rate_pct,
    ROUND(AVG(CASE WHEN overall_status = 'COMPLETED' THEN duration_months END), 1) AS avg_months_completed,
    ROUND(AVG(CASE WHEN overall_status = 'TERMINATED' THEN duration_months END), 1) AS avg_months_terminated
FROM finished
GROUP BY condition_name, phase, source_class
HAVING COUNT(*) >= 40
ORDER BY termination_rate_pct DESC
LIMIT 20;
