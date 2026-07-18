/*
IT Service Desk Analytics
Advanced operational analysis using CTEs and window functions
*/


-- =========================================================
-- QUESTION 1:
-- How did monthly incident volume and performance change?
-- Interpret later months cautiously because volumes are small.
-- =========================================================

SELECT
    date.year_number,
    date.month_number,
    date.month_name,

    COUNT(*) AS total_incidents,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN incident.made_sla THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS sla_compliance_percentage,

    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (
            ORDER BY incident.resolution_hours
        )::NUMERIC,
        2
    ) AS median_resolution_hours,

    ROUND(
        AVG(incident.resolution_hours),
        2
    ) AS average_resolution_hours,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN incident.was_reassigned THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS reassignment_percentage

FROM analytics.fact_incidents AS incident
JOIN analytics.dim_date AS date
    ON incident.opened_date_key = date.date_key

GROUP BY
    date.year_number,
    date.month_number,
    date.month_name

ORDER BY
    date.year_number,
    date.month_number;


-- =========================================================
-- QUESTION 2:
-- What do resolution-time percentiles show?
-- =========================================================

SELECT
    COUNT(resolution_hours) AS incidents_with_resolution_time,

    ROUND(
        PERCENTILE_CONT(0.50)
        WITHIN GROUP (ORDER BY resolution_hours)::NUMERIC,
        2
    ) AS p50_hours,

    ROUND(
        PERCENTILE_CONT(0.75)
        WITHIN GROUP (ORDER BY resolution_hours)::NUMERIC,
        2
    ) AS p75_hours,

    ROUND(
        PERCENTILE_CONT(0.90)
        WITHIN GROUP (ORDER BY resolution_hours)::NUMERIC,
        2
    ) AS p90_hours,

    ROUND(
        PERCENTILE_CONT(0.95)
        WITHIN GROUP (ORDER BY resolution_hours)::NUMERIC,
        2
    ) AS p95_hours,

    ROUND(
        PERCENTILE_CONT(0.99)
        WITHIN GROUP (ORDER BY resolution_hours)::NUMERIC,
        2
    ) AS p99_hours

FROM analytics.fact_incidents

WHERE resolution_hours IS NOT NULL;


-- =========================================================
-- QUESTION 3:
-- What proportion of incidents are long-running?
-- =========================================================

WITH duration_bands AS (
    SELECT
        CASE
            WHEN resolution_hours IS NULL
                THEN 'Missing resolution time'
            WHEN resolution_hours <= 1
                THEN 'Under 1 hour'
            WHEN resolution_hours <= 8
                THEN '1-8 hours'
            WHEN resolution_hours <= 24
                THEN '8-24 hours'
            WHEN resolution_hours <= 72
                THEN '1-3 days'
            WHEN resolution_hours <= 168
                THEN '3-7 days'
            WHEN resolution_hours <= 720
                THEN '7-30 days'
            WHEN resolution_hours <= 2160
                THEN '30-90 days'
            ELSE 'Over 90 days'
        END AS duration_band,

        CASE
            WHEN resolution_hours IS NULL THEN 9
            WHEN resolution_hours <= 1 THEN 1
            WHEN resolution_hours <= 8 THEN 2
            WHEN resolution_hours <= 24 THEN 3
            WHEN resolution_hours <= 72 THEN 4
            WHEN resolution_hours <= 168 THEN 5
            WHEN resolution_hours <= 720 THEN 6
            WHEN resolution_hours <= 2160 THEN 7
            ELSE 8
        END AS band_order

    FROM analytics.fact_incidents
)

SELECT
    duration_band,
    COUNT(*) AS total_incidents,

    ROUND(
        100.0 * COUNT(*) /
        SUM(COUNT(*)) OVER (),
        2
    ) AS percentage_of_incidents

FROM duration_bands

GROUP BY
    duration_band,
    band_order

ORDER BY band_order;


-- =========================================================
-- QUESTION 4:
-- Which categories contribute most incident volume?
-- Includes cumulative volume percentage.
-- =========================================================

WITH category_volume AS (
    SELECT
        category.category_name,
        COUNT(*) AS total_incidents

    FROM analytics.fact_incidents AS incident
    JOIN analytics.dim_category AS category
        ON incident.category_key = category.category_key

    GROUP BY category.category_name
),

ranked_categories AS (
    SELECT
        category_name,
        total_incidents,

        RANK() OVER (
            ORDER BY total_incidents DESC
        ) AS volume_rank,

        ROUND(
            100.0 * total_incidents /
            SUM(total_incidents) OVER (),
            2
        ) AS volume_percentage,

        ROUND(
            100.0 *
            SUM(total_incidents) OVER (
                ORDER BY total_incidents DESC
                ROWS BETWEEN UNBOUNDED PRECEDING
                AND CURRENT ROW
            )
            / SUM(total_incidents) OVER (),
            2
        ) AS cumulative_volume_percentage

    FROM category_volume
)

SELECT
    volume_rank,
    category_name,
    total_incidents,
    volume_percentage,
    cumulative_volume_percentage

FROM ranked_categories

ORDER BY volume_rank;


-- =========================================================
-- QUESTION 5:
-- How do assignment groups compare with the overall SLA rate?
-- Minimum sample: 200 incidents.
-- =========================================================

WITH overall_performance AS (
    SELECT
        100.0 * AVG(
            CASE WHEN made_sla THEN 1.0 ELSE 0.0 END
        ) AS overall_sla_rate

    FROM analytics.fact_incidents
),

group_performance AS (
    SELECT
        assignment_group.assignment_group_name,
        COUNT(*) AS total_incidents,

        100.0 * AVG(
            CASE
                WHEN incident.made_sla THEN 1.0
                ELSE 0.0
            END
        ) AS group_sla_rate,

        PERCENTILE_CONT(0.5)
        WITHIN GROUP (
            ORDER BY incident.resolution_hours
        ) AS median_resolution_hours

    FROM analytics.fact_incidents AS incident
    JOIN analytics.dim_assignment_group AS assignment_group
        ON incident.assignment_group_key =
           assignment_group.assignment_group_key

    GROUP BY assignment_group.assignment_group_name

    HAVING COUNT(*) >= 200
)

SELECT
    assignment_group_name,
    total_incidents,
    ROUND(group_sla_rate, 2) AS sla_compliance_percentage,

    ROUND(
        group_sla_rate - overall.overall_sla_rate,
        2
    ) AS sla_gap_from_overall,

    ROUND(
        median_resolution_hours::NUMERIC,
        2
    ) AS median_resolution_hours,

    CASE
        WHEN group_sla_rate >= overall.overall_sla_rate
            THEN 'Above overall rate'
        ELSE 'Below overall rate'
    END AS performance_status

FROM group_performance
CROSS JOIN overall_performance AS overall

ORDER BY
    sla_gap_from_overall,
    total_incidents DESC;


-- =========================================================
-- QUESTION 6:
-- How does routing stability relate to performance?
-- =========================================================

SELECT
    CASE
        WHEN reassignment_count = 0
            THEN 'No reassignment'
        WHEN reassignment_count = 1
            THEN 'One reassignment'
        WHEN reassignment_count BETWEEN 2 AND 3
            THEN 'Two or three reassignments'
        ELSE 'Four or more reassignments'
    END AS routing_group,

    COUNT(*) AS total_incidents,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN made_sla THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS sla_compliance_percentage,

    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (
            ORDER BY resolution_hours
        )::NUMERIC,
        2
    ) AS median_resolution_hours,

    ROUND(
        AVG(resolution_hours),
        2
    ) AS average_resolution_hours

FROM analytics.fact_incidents

GROUP BY
    CASE
        WHEN reassignment_count = 0
            THEN 'No reassignment'
        WHEN reassignment_count = 1
            THEN 'One reassignment'
        WHEN reassignment_count BETWEEN 2 AND 3
            THEN 'Two or three reassignments'
        ELSE 'Four or more reassignments'
    END

ORDER BY
    MIN(reassignment_count);