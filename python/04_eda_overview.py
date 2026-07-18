from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]

INPUT_FILE = (
    PROJECT_ROOT
    / "data"
    / "processed"
    / "incidents_analytical.csv"
)

OUTPUT_DIRECTORY = (
    PROJECT_ROOT
    / "outputs"
    / "sql_outputs"
)

DATE_COLUMNS = [
    "opened_at",
    "resolved_at",
    "closed_at",
    "opened_month_start",
]


def percentage(series):
    return round(series.mean() * 100, 2)


def main():
    print("=" * 75)
    print("IT SERVICE DESK — EXPLORATORY ANALYSIS OVERVIEW")
    print("=" * 75)

    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)

    incidents = pd.read_csv(
        INPUT_FILE,
        parse_dates=DATE_COLUMNS,
        low_memory=False,
    )

    total_incidents = len(incidents)
    sla_met = incidents["made_sla"].sum()
    sla_breached = total_incidents - sla_met

    print("\n1. HEADLINE KPIs")
    print(f"Total incidents: {total_incidents:,}")
    print(f"SLA met: {sla_met:,}")
    print(f"SLA breached: {sla_breached:,}")
    print(f"SLA compliance rate: {sla_met / total_incidents * 100:.2f}%")
    print(
        "Median resolution time:",
        f"{incidents['resolution_hours'].median():,.2f} hours",
    )
    print(
        "Average resolution time:",
        f"{incidents['resolution_hours'].mean():,.2f} hours",
    )
    print(
        "Median closure time:",
        f"{incidents['closure_hours'].median():,.2f} hours",
    )
    print(
        "Incidents reassigned:",
        f"{incidents['was_reassigned'].sum():,}",
    )
    print(
        "Reassignment rate:",
        f"{percentage(incidents['was_reassigned']):.2f}%",
    )
    print(
        "Incidents reopened:",
        f"{incidents['was_reopened'].sum():,}",
    )
    print(
        "Reopen rate:",
        f"{percentage(incidents['was_reopened']):.2f}%",
    )

    monthly_summary = (
        incidents.groupby(
            "opened_month_start",
            dropna=False,
        )
        .agg(
            total_incidents=("number", "nunique"),
            sla_met=("made_sla", "sum"),
            sla_compliance_rate=("made_sla", "mean"),
            median_resolution_hours=("resolution_hours", "median"),
            average_resolution_hours=("resolution_hours", "mean"),
            reassigned_incidents=("was_reassigned", "sum"),
            reassignment_rate=("was_reassigned", "mean"),
        )
        .reset_index()
    )

    monthly_summary["sla_breached"] = (
        monthly_summary["total_incidents"]
        - monthly_summary["sla_met"]
    )

    monthly_summary["sla_compliance_rate"] *= 100
    monthly_summary["reassignment_rate"] *= 100

    print("\n2. MONTHLY PERFORMANCE")
    print(
        monthly_summary.round(2).to_string(index=False)
    )

    priority_summary = (
        incidents.groupby(
            ["priority_level", "priority"],
            dropna=False,
        )
        .agg(
            total_incidents=("number", "nunique"),
            sla_compliance_rate=("made_sla", "mean"),
            median_resolution_hours=("resolution_hours", "median"),
            average_resolution_hours=("resolution_hours", "mean"),
            reassignment_rate=("was_reassigned", "mean"),
        )
        .reset_index()
        .sort_values("priority_level")
    )

    priority_summary["sla_compliance_rate"] *= 100
    priority_summary["reassignment_rate"] *= 100

    print("\n3. PERFORMANCE BY PRIORITY")
    print(
        priority_summary.round(2).to_string(index=False)
    )

    reassignment_summary = (
        incidents.groupby("was_reassigned")
        .agg(
            total_incidents=("number", "nunique"),
            sla_compliance_rate=("made_sla", "mean"),
            median_resolution_hours=("resolution_hours", "median"),
            average_resolution_hours=("resolution_hours", "mean"),
            median_closure_hours=("closure_hours", "median"),
        )
        .reset_index()
    )

    reassignment_summary["sla_compliance_rate"] *= 100

    print("\n4. REASSIGNED VERSUS NON-REASSIGNED INCIDENTS")
    print(
        reassignment_summary.round(2).to_string(index=False)
    )

    category_summary = (
        incidents.groupby(
            "category",
            dropna=False,
        )
        .agg(
            total_incidents=("number", "nunique"),
            sla_compliance_rate=("made_sla", "mean"),
            median_resolution_hours=("resolution_hours", "median"),
            reassignment_rate=("was_reassigned", "mean"),
        )
        .reset_index()
    )

    category_summary["sla_compliance_rate"] *= 100
    category_summary["reassignment_rate"] *= 100

    category_summary = category_summary.sort_values(
        "total_incidents",
        ascending=False,
    )

    print("\n5. TOP 15 CATEGORIES BY INCIDENT VOLUME")
    print(
        category_summary.head(15).round(2).to_string(index=False)
    )

    assignment_group_summary = (
        incidents.groupby(
            "assignment_group",
            dropna=False,
        )
        .agg(
            total_incidents=("number", "nunique"),
            sla_compliance_rate=("made_sla", "mean"),
            median_resolution_hours=("resolution_hours", "median"),
            reassignment_rate=("was_reassigned", "mean"),
        )
        .reset_index()
    )

    assignment_group_summary["sla_compliance_rate"] *= 100
    assignment_group_summary["reassignment_rate"] *= 100

    assignment_group_summary = assignment_group_summary.sort_values(
        "total_incidents",
        ascending=False,
    )

    print("\n6. TOP 15 ASSIGNMENT GROUPS BY INCIDENT VOLUME")
    print(
        assignment_group_summary.head(15)
        .round(2)
        .to_string(index=False)
    )

    print("\n7. LONG-RUNNING INCIDENTS")
    print(
        "Resolved after more than 7 days:",
        f"{(incidents['resolution_hours'] > 168).sum():,}",
    )
    print(
        "Resolved after more than 30 days:",
        f"{(incidents['resolution_hours'] > 720).sum():,}",
    )
    print(
        "Resolved after more than 90 days:",
        f"{(incidents['resolution_hours'] > 2160).sum():,}",
    )

    monthly_summary.to_csv(
        OUTPUT_DIRECTORY / "monthly_performance.csv",
        index=False,
    )

    priority_summary.to_csv(
        OUTPUT_DIRECTORY / "priority_performance.csv",
        index=False,
    )

    reassignment_summary.to_csv(
        OUTPUT_DIRECTORY / "reassignment_performance.csv",
        index=False,
    )

    category_summary.to_csv(
        OUTPUT_DIRECTORY / "category_performance.csv",
        index=False,
    )

    assignment_group_summary.to_csv(
        OUTPUT_DIRECTORY / "assignment_group_performance.csv",
        index=False,
    )

    print("\nAnalysis tables exported successfully.")


if __name__ == "__main__":
    main()
    