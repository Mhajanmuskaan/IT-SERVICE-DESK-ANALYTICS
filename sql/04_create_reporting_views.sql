/*
IT Service Desk Analytics
Reusable reporting and validation views
*/


-- =========================================================
-- DETAILED INCIDENT REPORTING VIEW
-- =========================================================

CREATE OR REPLACE VIEW analytics.vw_incident_details AS

SELECT
    incident.incident_number,

    date.full_date AS opened_date,
    date.year_number AS opened_year,
    date.quarter_number AS opened_quarter,
    date.month_number AS opened_month_number,
    date.month_name AS opened_month_name,
    date.day_name AS opened_day_name,
    date.is_weekend,

    category.category_name,
    assignment_group.assignment_group_name,

    priority.priority_name,
    priority.priority_level,

    incident.opened_at,
    incident.resolved_at,
    incident.closed_at,
    incident.opened_hour,

    incident.contact_type,
    incident.impact_level,
    incident.urgency_level,

    incident.made_sla,
    incident.sla_status,

    incident.reassignment_count,
    incident.reopen_count,
    incident.modification_count,
    incident.event_count,

    incident.resolution_hours,
    incident.closure_hours,
    incident.resolution_time_band,

    incident.was_reassigned,
    incident.was_reopened,
    incident.knowledge_used

FROM analytics.fact_incidents AS incident

JOIN analytics.dim_date AS date
    ON incident.opened_date_key = date.date_key

JOIN analytics.dim_category AS category
    ON incident.category_key = category.category_key

JOIN analytics.dim_assignment_group AS assignment_group
    ON incident.assignment_group_key =
       assignment_group.assignment_group_key

JOIN analytics.dim_priority AS priority
    ON incident.priority_key = priority.priority_key;


-- =========================================================
-- HEADLINE KPI VIEW
-- =========================================================

CREATE OR REPLACE VIEW analytics.vw_kpi_summary AS

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

    SUM(
        CASE WHEN was_reassigned THEN 1 ELSE 0 END
    ) AS reassigned_incidents,

    ROUND(
        100.0 * AVG(
            CASE
                WHEN was_reassigned THEN 1.0
                ELSE 0.0
            END
        ),
        2
    ) AS reassignment_percentage,

    SUM(
        CASE WHEN was_reopened THEN 1 ELSE 0 END
    ) AS reopened_incidents

FROM analytics.fact_incidents;


-- =========================================================
-- MONTHLY PERFORMANCE VIEW
-- =========================================================

CREATE OR REPLACE VIEW analytics.vw_monthly_performance AS

SELECT
    date.year_number,
    date.month_number,
    date.month_name,

    MAKE_DATE(
        date.year_number,
        date.month_number,
        1
    ) AS month_start,

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
JOIN analytics.dim_date AS date
    ON incident.opened_date_key = date.date_key

GROUP BY
    date.year_number,
    date.month_number,
    date.month_name;


-- =========================================================
-- CATEGORY PERFORMANCE VIEW
-- =========================================================

CREATE OR REPLACE VIEW analytics.vw_category_performance AS

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

GROUP BY category.category_name;