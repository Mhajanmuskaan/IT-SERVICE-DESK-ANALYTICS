# Exploratory Data Analysis Findings

## 1. Executive Summary

The analysis covers 24,918 unique IT service incidents extracted from an anonymized ServiceNow event log.

Overall performance included:

- 63.42% SLA compliance
- 22.10-hour median resolution time
- 178.17-hour average resolution time
- 45.63% reassignment rate
- 1.10% reopening rate

The substantial difference between median and average resolution time indicates a strongly right-skewed distribution. Median resolution time is therefore the more representative measure of typical performance.

## 2. SLA Performance

Of the 24,918 incidents:

- 15,803 met SLA
- 9,115 breached SLA

SLA compliance differed substantially by priority:

| Priority | Incidents | SLA compliance |
|---|---:|---:|
| Critical | 270 | 1.85% |
| High | 408 | 0.49% |
| Moderate | 23,466 | 64.54% |
| Low | 774 | 84.11% |

Critical and high-priority incidents had extremely low SLA compliance. However, the dataset does not provide the underlying SLA targets, so the analysis cannot determine whether breaches resulted from unrealistic targets, incident complexity, routing problems or another operational factor.

## 3. Reassignment Analysis

A total of 11,369 incidents were reassigned at least once, representing 45.63% of all incidents.

| Reassignments | Incidents | SLA compliance | Median resolution |
|---:|---:|---:|---:|
| 0 | 13,549 | 78.39% | 0.68 hours |
| 1 | 6,238 | 57.07% | 42.05 hours |
| 2 | 2,283 | 39.86% | 102.97 hours |
| 3 | 1,234 | 32.90% | 146.10 hours |
| 4 | 695 | 25.18% | 186.10 hours |

Higher reassignment counts are associated with lower SLA compliance and longer resolution times.

This relationship should not be interpreted as proof that reassignment causes delay. More complex incidents may naturally require both additional support groups and more resolution time.

The relationship also differs within some priority groups, reinforcing the need to avoid a causal claim.

## 4. Category Performance

Among categories with at least 200 incidents:

- Category 45 had 25.91% SLA compliance and a median resolution time of 147.73 hours.
- Category 34 had 33.53% SLA compliance and a median resolution time of 404.72 hours.
- Category 40 had 38.99% SLA compliance and a 75.00% reassignment rate.
- Category 23 had an 87.02% reassignment rate across 1,063 incidents.
- Category 46 generated 2,432 incidents but achieved only 48.44% SLA compliance.

These categories represent potential operational-review areas. Because category names are anonymized, the analysis cannot identify the underlying technical issue.

## 5. Assignment-Group Performance

Among groups with at least 200 incidents:

- Group 10 had 25.07% SLA compliance and a median resolution time of 402.37 hours.
- Group 66 had 30.32% SLA compliance and a median resolution time of 207.77 hours.
- Group 72 had 36.78% SLA compliance and an 80.93% reassignment rate.
- Group 25 handled 1,243 incidents but achieved only 42.80% SLA compliance.
- Group 70 handled 9,444 incidents and achieved 83.84% SLA compliance.

These comparisons identify performance differences but do not account for differences in incident complexity or group responsibility.

## 6. Missing Assignment Groups

A total of 2,157 incidents had no final assignment-group value.

These incidents had:

- 48.63% SLA compliance
- 50.52-hour median resolution time
- 83.03% reassignment rate

This pattern may reflect incomplete routing information or incidents transferred between groups. It should be investigated as a potential data-quality and workflow issue.

## 7. Long-Running Incidents

- 5,360 incidents took longer than seven days to resolve.
- 1,149 incidents took longer than 30 days.
- 335 incidents took longer than 90 days.

Long-duration records were retained because no lifecycle errors were found. They may represent valid complex incidents rather than data-entry mistakes.

## 8. Data-Coverage Limitation

Approximately 98.90% of incidents were opened between February 29 and May 31, 2016.

Although some incident records extend into February 2017, later months contain very small incident volumes. Monthly comparisons after May 2016 should therefore not be presented as representative operating trends.

## 9. Preliminary Recommendations

1. Review the routing and ownership process for categories with high reassignment rates.
2. Investigate SLA definitions and escalation workflows for critical and high-priority incidents.
3. Examine the workload and incident mix of Groups 10, 66, 72 and 25.
4. Investigate missing assignment-group values as a possible workflow or data-governance problem.
5. Track median and percentile-based resolution measures instead of relying only on averages.
6. Separate incident-complexity effects from reassignment effects before introducing routing changes.

## 10. Interpretation Limitations

The analysis identifies associations, not confirmed causes. The dataset does not provide descriptive category names, business context, staffing levels, contractual SLA thresholds or incident-complexity measures.