# IT Service Desk Analytics Project

## Project Overview

This project analyzes IT service desk incident data to evaluate SLA performance, resolution efficiency, reassignment patterns, incident trends, and operational bottlenecks.

The project follows an end-to-end analytics workflow using **Python, PostgreSQL, SQL, and Power BI**, transforming raw incident-event data into an incident-level analytical model and interactive business dashboard.

---

## Business Objective

The objective of this project was to answer key operational questions such as:

- How many incidents are being created and resolved?
- What percentage of incidents meet SLA requirements?
- Which priorities have the highest SLA breach rates?
- How long does it typically take to resolve incidents?
- Which assignment groups handle the highest incident volumes?
- How frequently are incidents reassigned or reopened?
- How does incident volume change over time?
- Where are the biggest opportunities to improve service desk performance?

---

## Tools & Technologies

- **Python**
- **Pandas**
- **PostgreSQL**
- **SQL**
- **Power BI**
- **DAX**
- **Data Modeling**
- **Git & GitHub**

---

## Dataset

The original dataset contained:

- **141,712 incident event records**
- **36 columns**
- **24,918 unique incidents**

Because multiple rows could represent different events for the same incident, the raw event-level dataset was transformed into an incident-level analytical dataset for reporting.

---

## Data Preparation

Python and Pandas were used to:

- Load and inspect the raw incident-event dataset
- Validate data types and missing values
- Convert date and time columns into usable datetime formats
- Identify unique incidents
- Consolidate multiple event records into incident-level records
- Calculate resolution and closure durations
- Derive SLA status
- Identify reopened incidents
- Identify reassigned incidents
- Prepare cleaned data for PostgreSQL and Power BI reporting

---

## PostgreSQL Data Model

The cleaned data was loaded into PostgreSQL and organized into staging and analytics layers.

### Staging Layer

- `staging.incident_events`
- `staging.incidents_analytical`

The analytical incident table contains one record per incident and is used as the basis for downstream reporting.

### Analytics Layer

A dimensional model was created containing:

- `dim_date`
- `dim_category`
- `dim_assignment_group`
- `dim_priority`
- `fact_incidents`

This structure supports efficient reporting and follows a **star schema** approach for Power BI.

---

## Key Performance Indicators

The analysis produced the following major KPIs:

| KPI | Result |
|---|---:|
| Total Incidents | 24,918 |
| SLA Met | 15,803 |
| SLA Breached | 9,115 |
| SLA Compliance Rate | 63.42% |
| Median Resolution Time | 22.10 hours |
| Average Resolution Time | 178.17 hours |
| Median Closure Time | 145.87 hours |
| Reassigned Incidents | 11,369 |
| Reassignment Rate | 45.63% |
| Reopened Incidents | 275 |
| Reopen Rate | 1.10% |

---

## SLA Analysis

SLA performance was analyzed by incident priority to identify which types of incidents were most likely to breach service-level targets.

Priority-level SLA compliance included:

- **Priority 1:** 1.85%
- **Priority 2:** 0.49%
- **Priority 3:** 64.54%
- **Priority 4:** 84.11%

The results show significantly weaker SLA performance for high-priority incidents compared with lower-priority incidents.

---

## Power BI Dashboard

A four-page interactive Power BI dashboard was developed to present service desk performance to business and operational stakeholders.

### 1. Executive Overview

Provides a high-level view of:

- Total incidents
- SLA compliance
- SLA breaches
- Resolution performance
- Reassignment rate
- Incident distribution

### 2. SLA & Priority Analysis

Analyzes:

- SLA compliance by priority
- SLA breaches
- Incident distribution by priority
- High-priority service performance

### 3. Resolution & Assignment Group Analysis

Focuses on:

- Resolution time
- Assignment group performance
- Incident volume by assignment group
- Reassignment patterns
- Operational bottlenecks

### 4. Incident Trend Analysis

Tracks:

- Incident volume over time
- Changes in incident activity
- Resolution trends
- Service desk workload patterns

---

## Power BI Dashboard Screenshots

### Executive Overview

![Executive Overview](dashboard_screenshots/executive_overview.png)

### SLA & Priority Analysis

![SLA Priority Analysis](dashboard_screenshots/sla_priority_analysis.png)

### Resolution & Assignment Group Analysis

![Resolution Assignment Group Analysis](dashboard_screenshots/resolution_assignment_group_analysis.png)

### Incident Trend Analysis

![Incident Trend Analysis](dashboard_screenshots/incident_trend_analysis.png)

---

## Key Business Insights

- Overall SLA compliance was **63.42%**, with **9,115 incidents breaching SLA targets**.
- High-priority incidents showed substantially lower SLA compliance than lower-priority incidents.
- Median resolution time was **22.10 hours**, while the much higher average of **178.17 hours** indicates the presence of long-running incidents and outliers.
- **45.63% of incidents were reassigned**, suggesting opportunities to improve initial routing and assignment accuracy.
- Only **1.10% of incidents were reopened**, indicating relatively low repeat issue rates after resolution.
- Assignment-group and incident-trend analysis can help identify workload concentration and operational bottlenecks.

---

## Business Recommendations

Based on the analysis:

- Investigate the causes of low SLA compliance for Priority 1 and Priority 2 incidents.
- Improve initial incident routing to reduce unnecessary reassignment.
- Monitor long-running incidents separately from normal resolution metrics.
- Review assignment groups with consistently high incident volumes or resolution times.
- Use median resolution time alongside average resolution time to avoid distorted performance reporting caused by outliers.
- Establish recurring SLA and workload reporting to identify service deterioration early.

---

## Project Workflow

The overall analytics workflow followed:

1. Raw incident-event data collection
2. Data cleaning and validation using Python
3. Incident-level transformation
4. PostgreSQL staging layer
5. Dimensional data modeling
6. SQL analysis and KPI validation
7. Power BI data model creation
8. DAX measure development
9. Interactive dashboard development
10. Business insight and recommendation generation

---

## Repository Structure

```text
IT-Service-Desk-Analytics/
│
├── data/
│   └── Raw and processed datasets
│
├── python/
│   └── Data cleaning and analysis scripts
│
├── sql/
│   └── PostgreSQL schema and analysis queries
│
├── outputs/
│   └── Analytical outputs and KPI results
│
├── powerBI/
│   └── Power BI dashboard file
│
├── dashboard_screenshots/
│   ├── executive_overview.png
│   ├── sla_priority_analysis.png
│   ├── resolution_assignment_group_analysis.png
│   └── incident_trend_analysis.png
│
└── README.md