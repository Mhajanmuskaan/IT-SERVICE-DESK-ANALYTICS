/*
IT Service Desk Analytics
Headline KPI, priority and SLA analysis
*/


-- =========================================================
-- QUESTION 1:
-- What are the overall service-desk performance KPIs?
-- =========================================================

SELECT
    COUNT(*) AS total_incidents,

    SUM(
        CASE WHEN made_sla THEN 1 ELSE 0 END
    ) AS sla_met,

    SUM(
        CASE WHEN NOT made_sla THEN 1 ELSE 0 END
    ) AS sla_breached,

    ROUND(
        100.0 * AVG(
            CASE WHEN made_sla THEN 1.0 ELSE 0.0 END
        ),
        2
    ) AS sla_compliance_percentage,

    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY resolution_hours)::NUMERIC,
        2
    ) AS median_resolution_hours,

    ROUND(
        AVG(resolution_hours),
        2
    ) AS average_resolution_hours,

    ROUND(
        PERCENTILE_CONT(0.5)
        WITHIN GROUP (ORDER BY closure_hours)::NUMERIC,
        2
    ) AS median_closure_hours,

    SUM(
        CASE WHEN was_reassigned THEN 1 ELSE 0 END
    ) AS reassigned_incidents,

    ROUND(
        100.0 * AVG(
            CASE WHEN was_reassigned THEN 1.0 ELSE 0.0 END
        ),
        2
    ) AS reassignment_percentage,

    SUM(
        CASE WHEN was_reopened THEN 1 ELSE 0 END
    ) AS reopened_incidents,

    ROUND(
        100.0 * AVG(
            CASE WHEN was_reopened THEN 1.0 ELSE 0.0 END
        ),
        2
    ) AS reopen_percentage

FROM analytics.fact_incidents;


-- =========================================================
-- QUESTION 2:
-- How does performance differ by priority?
-- =========================================================

SELECT
    priority.priority_level,
    priority.priority_name,

    COUNT(*) AS total_incidents,

    SUM(
        CASE WHEN incident.made_sla THEN 1 ELSE 0 END
    ) AS sla_met,

    COUNT(*) - SUM(
        CASE WHEN incident.made_sla THEN 1 ELSE 0 END
    ) AS sla_breached,

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
JOIN analytics.dim_priority AS priority
    ON incident.priority_key = priority.priority_key

GROUP BY
    priority.priority_level,
    priority.priority_name

ORDER BY
    priority.priority_level;


-- =========================================================
-- QUESTION 3:
-- How does reassignment count relate to SLA and resolution?
-- Only groups with at least 10 incidents are shown.
-- =========================================================

WITH reassignment_performance AS (
    SELECT
        reassignment_count,
        COUNT(*) AS total_incidents,

        SUM(
            CASE WHEN made_sla THEN 1 ELSE 0 END
        ) AS sla_met,

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

    GROUP BY reassignment_count
)

SELECT
    reassignment_count,
    total_incidents,
    sla_met,
    total_incidents - sla_met AS sla_breached,
    sla_compliance_percentage,
    median_resolution_hours,
    average_resolution_hours

FROM reassignment_performance

WHERE total_incidents >= 10

ORDER BY reassignment_count;


-- =========================================================
-- QUESTION 4:
-- Which high-volume categories have the weakest SLA results?
-- Minimum sample: 200 incidents.
-- =========================================================

WITH category_performance AS (
    SELECT
        category.category_name,
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
            100.0 * AVG(
                CASE
                    WHEN incident.was_reassigned THEN 1.0
                    ELSE 0.0
                END
            ),
            2
        ) AS reassignment_percentage

    FROM analytics.fact_incidents AS incident
    JOIN analytics.dim_category AS category
        ON incident.category_key = category.category_key

    GROUP BY category.category_name

    HAVING COUNT(*) >= 200
)

SELECT
    RANK() OVER (
        ORDER BY sla_compliance_percentage
    ) AS sla_performance_rank,

    category_name,
    total_incidents,
    sla_compliance_percentage,
    median_resolution_hours,
    reassignment_percentage

FROM category_performance

ORDER BY
    sla_performance_rank,
    total_incidents DESC;


-- =========================================================
-- QUESTION 5:
-- Which high-volume assignment groups need review?
-- Minimum sample: 200 incidents.
-- =========================================================

WITH group_performance AS (
    SELECT
        assignment_group.assignment_group_name,
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
            100.0 * AVG(
                CASE
                    WHEN incident.was_reassigned THEN 1.0
                    ELSE 0.0
                END
            ),
            2
        ) AS reassignment_percentage

    FROM analytics.fact_incidents AS incident
    JOIN analytics.dim_assignment_group AS assignment_group
        ON incident.assignment_group_key =
           assignment_group.assignment_group_key

    GROUP BY assignment_group.assignment_group_name

    HAVING COUNT(*) >= 200
)

SELECT
    RANK() OVER (
        ORDER BY sla_compliance_percentage
    ) AS sla_performance_rank,

    assignment_group_name,
    total_incidents,
    sla_compliance_percentage,
    median_resolution_hours,
    reassignment_percentage

FROM group_performance

ORDER BY
    sla_performance_rank,
    total_incidents DESC;