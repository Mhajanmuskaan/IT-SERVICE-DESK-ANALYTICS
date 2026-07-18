/*
IT Service Desk Analytics
Creates the curated PostgreSQL star schema.

The staging schema is preserved.
Only the analytics schema is rebuilt.
*/

BEGIN;

CREATE SCHEMA IF NOT EXISTS analytics;

DROP TABLE IF EXISTS analytics.fact_incidents CASCADE;
DROP TABLE IF EXISTS analytics.dim_date CASCADE;
DROP TABLE IF EXISTS analytics.dim_category CASCADE;
DROP TABLE IF EXISTS analytics.dim_assignment_group CASCADE;
DROP TABLE IF EXISTS analytics.dim_priority CASCADE;


-- =========================================================
-- DATE DIMENSION
-- =========================================================

CREATE TABLE analytics.dim_date (
    date_key INTEGER PRIMARY KEY,
    full_date DATE NOT NULL UNIQUE,
    year_number SMALLINT NOT NULL,
    quarter_number SMALLINT NOT NULL,
    month_number SMALLINT NOT NULL,
    month_name VARCHAR(15) NOT NULL,
    day_number SMALLINT NOT NULL,
    day_name VARCHAR(15) NOT NULL,
    is_weekend BOOLEAN NOT NULL
);

INSERT INTO analytics.dim_date (
    date_key,
    full_date,
    year_number,
    quarter_number,
    month_number,
    month_name,
    day_number,
    day_name,
    is_weekend
)
SELECT
    TO_CHAR(calendar_date, 'YYYYMMDD')::INTEGER,
    calendar_date,
    EXTRACT(YEAR FROM calendar_date)::SMALLINT,
    EXTRACT(QUARTER FROM calendar_date)::SMALLINT,
    EXTRACT(MONTH FROM calendar_date)::SMALLINT,
    TRIM(TO_CHAR(calendar_date, 'Month')),
    EXTRACT(DAY FROM calendar_date)::SMALLINT,
    TRIM(TO_CHAR(calendar_date, 'Day')),
    EXTRACT(ISODOW FROM calendar_date) IN (6, 7)
FROM generate_series(
    (
        SELECT MIN(opened_at)::DATE
        FROM staging.incidents_analytical
    ),
    (
        SELECT MAX(opened_at)::DATE
        FROM staging.incidents_analytical
    ),
    INTERVAL '1 day'
) AS dates(calendar_date);


-- =========================================================
-- CATEGORY DIMENSION
-- =========================================================

CREATE TABLE analytics.dim_category (
    category_key INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    category_name VARCHAR(100) NOT NULL UNIQUE
);

INSERT INTO analytics.dim_category (category_name)
SELECT DISTINCT COALESCE(category, 'Unknown')
FROM staging.incidents_analytical
ORDER BY COALESCE(category, 'Unknown');


-- =========================================================
-- ASSIGNMENT-GROUP DIMENSION
-- =========================================================

CREATE TABLE analytics.dim_assignment_group (
    assignment_group_key INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    assignment_group_name VARCHAR(100) NOT NULL UNIQUE
);

INSERT INTO analytics.dim_assignment_group (
    assignment_group_name
)
SELECT DISTINCT COALESCE(assignment_group, 'Unknown')
FROM staging.incidents_analytical
ORDER BY COALESCE(assignment_group, 'Unknown');


-- =========================================================
-- PRIORITY DIMENSION
-- =========================================================

CREATE TABLE analytics.dim_priority (
    priority_key INTEGER GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    priority_name VARCHAR(50) NOT NULL UNIQUE,
    priority_level SMALLINT
);

INSERT INTO analytics.dim_priority (
    priority_name,
    priority_level
)
SELECT DISTINCT
    COALESCE(priority, 'Unknown'),
    priority_level::SMALLINT
FROM staging.incidents_analytical
ORDER BY priority_level::SMALLINT;


-- =========================================================
-- INCIDENT FACT TABLE
-- =========================================================

CREATE TABLE analytics.fact_incidents (
    incident_number VARCHAR(20) PRIMARY KEY,

    opened_date_key INTEGER NOT NULL,
    category_key INTEGER NOT NULL,
    assignment_group_key INTEGER NOT NULL,
    priority_key INTEGER NOT NULL,

    opened_at TIMESTAMP NOT NULL,
    resolved_at TIMESTAMP,
    closed_at TIMESTAMP NOT NULL,

    contact_type VARCHAR(50),
    impact_level SMALLINT,
    urgency_level SMALLINT,

    made_sla BOOLEAN NOT NULL,
    sla_status VARCHAR(20) NOT NULL,

    reassignment_count INTEGER NOT NULL,
    reopen_count INTEGER NOT NULL,
    modification_count INTEGER NOT NULL,
    event_count INTEGER NOT NULL,

    resolution_hours NUMERIC(14, 4),
    closure_hours NUMERIC(14, 4),

    was_reassigned BOOLEAN NOT NULL,
    was_reopened BOOLEAN NOT NULL,
    knowledge_used BOOLEAN NOT NULL,

    opened_hour SMALLINT NOT NULL,
    opened_on_weekend BOOLEAN NOT NULL,
    resolution_time_band VARCHAR(30),

    CONSTRAINT fk_incident_date
        FOREIGN KEY (opened_date_key)
        REFERENCES analytics.dim_date(date_key),

    CONSTRAINT fk_incident_category
        FOREIGN KEY (category_key)
        REFERENCES analytics.dim_category(category_key),

    CONSTRAINT fk_incident_assignment_group
        FOREIGN KEY (assignment_group_key)
        REFERENCES analytics.dim_assignment_group(
            assignment_group_key
        ),

    CONSTRAINT fk_incident_priority
        FOREIGN KEY (priority_key)
        REFERENCES analytics.dim_priority(priority_key),

    CONSTRAINT chk_resolution_hours
        CHECK (
            resolution_hours IS NULL
            OR resolution_hours >= 0
        ),

    CONSTRAINT chk_closure_hours
        CHECK (closure_hours >= 0),

    CONSTRAINT chk_reassignment_count
        CHECK (reassignment_count >= 0),

    CONSTRAINT chk_reopen_count
        CHECK (reopen_count >= 0),

    CONSTRAINT chk_opened_hour
        CHECK (opened_hour BETWEEN 0 AND 23)
);


-- =========================================================
-- LOAD FACT TABLE
-- =========================================================

INSERT INTO analytics.fact_incidents (
    incident_number,
    opened_date_key,
    category_key,
    assignment_group_key,
    priority_key,
    opened_at,
    resolved_at,
    closed_at,
    contact_type,
    impact_level,
    urgency_level,
    made_sla,
    sla_status,
    reassignment_count,
    reopen_count,
    modification_count,
    event_count,
    resolution_hours,
    closure_hours,
    was_reassigned,
    was_reopened,
    knowledge_used,
    opened_hour,
    opened_on_weekend,
    resolution_time_band
)
SELECT
    source.number,
    TO_CHAR(source.opened_at, 'YYYYMMDD')::INTEGER,
    category.category_key,
    assignment_group.assignment_group_key,
    priority.priority_key,
    source.opened_at,
    source.resolved_at,
    source.closed_at,
    source.contact_type,
    source.impact_level::SMALLINT,
    source.urgency_level::SMALLINT,
    source.made_sla,
    source.sla_status,
    source.reassignment_count::INTEGER,
    source.reopen_count::INTEGER,
    source.sys_mod_count::INTEGER,
    source.event_count::INTEGER,
    source.resolution_hours::NUMERIC(14, 4),
    source.closure_hours::NUMERIC(14, 4),
    source.was_reassigned,
    source.was_reopened,
    source.knowledge,
    source.opened_hour::SMALLINT,
    source.opened_on_weekend,
    source.resolution_time_band
FROM staging.incidents_analytical AS source
JOIN analytics.dim_category AS category
    ON category.category_name =
       COALESCE(source.category, 'Unknown')
JOIN analytics.dim_assignment_group AS assignment_group
    ON assignment_group.assignment_group_name =
       COALESCE(source.assignment_group, 'Unknown')
JOIN analytics.dim_priority AS priority
    ON priority.priority_name =
       COALESCE(source.priority, 'Unknown');


-- =========================================================
-- PERFORMANCE INDEXES
-- =========================================================

CREATE INDEX idx_fact_incidents_date
    ON analytics.fact_incidents(opened_date_key);

CREATE INDEX idx_fact_incidents_category
    ON analytics.fact_incidents(category_key);

CREATE INDEX idx_fact_incidents_assignment_group
    ON analytics.fact_incidents(assignment_group_key);

CREATE INDEX idx_fact_incidents_priority
    ON analytics.fact_incidents(priority_key);

CREATE INDEX idx_fact_incidents_sla
    ON analytics.fact_incidents(made_sla);

CREATE INDEX idx_fact_incidents_reassignment
    ON analytics.fact_incidents(reassignment_count);


-- =========================================================
-- VALIDATION
-- =========================================================

DO $$
DECLARE
    fact_count INTEGER;
    unique_count INTEGER;
BEGIN
    SELECT
        COUNT(*),
        COUNT(DISTINCT incident_number)
    INTO fact_count, unique_count
    FROM analytics.fact_incidents;

    IF fact_count <> 24918 THEN
        RAISE EXCEPTION
            'Expected 24918 fact rows, found %',
            fact_count;
    END IF;

    IF unique_count <> 24918 THEN
        RAISE EXCEPTION
            'Incident identifiers are not unique';
    END IF;
END $$;

COMMIT;


SELECT
    COUNT(*) AS fact_rows,
    COUNT(DISTINCT incident_number) AS unique_incidents,
    SUM(CASE WHEN made_sla THEN 1 ELSE 0 END) AS sla_met,
    SUM(CASE WHEN NOT made_sla THEN 1 ELSE 0 END) AS sla_breached
FROM analytics.fact_incidents;