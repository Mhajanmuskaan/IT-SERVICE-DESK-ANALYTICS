# Data Cleaning and Preparation Report

## 1. Dataset Overview

The project uses the UCI Incident Management Process Enriched Event Log dataset. The data originated from an anonymized ServiceNow incident-management system.

The raw dataset contains:

- 141,712 lifecycle event records
- 24,918 unique incidents
- 36 original columns
- Records opened between February 29, 2016 and February 16, 2017

Each incident can appear multiple times because a new record is captured whenever the incident is updated.

## 2. Raw Data Preservation

The original dataset is stored in `data/raw` and is never overwritten.

All cleaning and feature-engineering operations are performed programmatically. Processed datasets are exported separately to `data/processed`.

## 3. Missing-Value Treatment

The source dataset uses `?` to represent unknown information. These values were converted to null values during import.

Missing values were not automatically filled because doing so could introduce false information.

Particularly sparse fields include:

- `caused_by`
- `vendor`
- `cmdb_ci`
- `rfc`
- `problem_id`

These fields are preserved in the processed event data but will not be used as primary dashboard dimensions unless supported by sufficient records.

A total of 1,556 incidents do not contain a resolution timestamp. Their resolution duration remains null rather than being estimated. Closure duration remains available for all incidents.

## 4. Duplicate and Event-Record Treatment

The raw dataset contains zero exact duplicate rows.

Repeated incident numbers are expected because the dataset is an event log. These records were not deleted.

Two processed datasets were created:

1. `incident_events_clean.csv` — retains all 141,712 lifecycle records.
2. `incidents_analytical.csv` — contains the latest available record for each of the 24,918 unique incidents.

The latest incident record was selected using the modification count and system-update timestamp.

## 5. Date Processing

The following columns were converted into datetime values:

- `opened_at`
- `sys_created_at`
- `sys_updated_at`
- `resolved_at`
- `closed_at`

All available date values were parsed successfully.

Validation confirmed:

- Zero incidents resolved before opening
- Zero incidents closed before opening
- Zero incidents closed before resolution
- Zero negative resolution durations
- Zero negative closure durations

## 6. Engineered Features

The incident-level analytical dataset includes:

- Numeric priority, impact and urgency levels
- Resolution hours and days
- Closure hours and days
- SLA status
- Reassignment indicator
- Reopening indicator
- Event count per incident
- Opened year, month, weekday and hour
- Weekend indicator
- Resolution-time band

These features were created to support SQL analysis and Power BI reporting.

## 7. Outlier Treatment

The resolution-time distribution is strongly right-skewed.

- Median resolution time: 22.1 hours
- Mean resolution time: 178.2 hours
- Maximum resolution time: 8,070.2 hours

Long-duration incidents were not automatically removed. They may represent genuine long-running incidents and will be investigated during exploratory analysis.

Median resolution time will be reported alongside the mean to prevent extreme values from creating a misleading summary.

## 8. Dataset Limitations

- All incidents eventually reached the `Closed` state, so the dataset cannot measure a current active backlog.
- Category, group, caller and resolver names are anonymized.
- SLA compliance is represented by the supplied `made_sla` field; the original contractual SLA thresholds are not provided.
- Missing resolution timestamps limit resolution-time analysis to incidents with valid values.
- The dataset covers approximately one year and should not be presented as current operational performance.
- Findings show associations, not confirmed causes.

## 9. Validation Result

The final analytical dataset contains exactly one row for each of the 24,918 incidents, with no duplicate incident identifiers or invalid negative lifecycle durations.