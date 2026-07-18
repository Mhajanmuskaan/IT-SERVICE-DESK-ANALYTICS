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


def prepare_summary(grouped):
    summary = grouped.agg(
        total_incidents=("number", "nunique"),
        sla_met=("made_sla", "sum"),
        sla_compliance_rate=("made_sla", "mean"),
        median_resolution_hours=("resolution_hours", "median"),
        average_resolution_hours=("resolution_hours", "mean"),
        median_reassignments=("reassignment_count", "median"),
        reassignment_rate=("was_reassigned", "mean"),
    ).reset_index()

    summary["sla_breached"] = (
        summary["total_incidents"] - summary["sla_met"]
    )

    summary["sla_compliance_rate"] *= 100
    summary["reassignment_rate"] *= 100

    return summary


def main():
    print("=" * 78)
    print("SLA AND REASSIGNMENT DEEP-DIVE")
    print("=" * 78)

    OUTPUT_DIRECTORY.mkdir(parents=True, exist_ok=True)

    incidents = pd.read_csv(
        INPUT_FILE,
        parse_dates=DATE_COLUMNS,
        low_memory=False,
    )

    print("\n1. SLA PERFORMANCE BY PRIORITY AND REASSIGNMENT")

    priority_reassignment = prepare_summary(
        incidents.groupby(
            [
                "priority_level",
                "priority",
                "was_reassigned",
            ],
            dropna=False,
        )
    ).sort_values(
        [
            "priority_level",
            "was_reassigned",
        ]
    )

    print(
        priority_reassignment
        .round(2)
        .to_string(index=False)
    )

    print("\n2. PERFORMANCE BY REASSIGNMENT COUNT")

    reassignment_count_summary = prepare_summary(
        incidents.groupby(
            "reassignment_count",
            dropna=False,
        )
    ).sort_values("reassignment_count")

    print(
        reassignment_count_summary
        .round(2)
        .to_string(index=False)
    )

    category_summary = prepare_summary(
        incidents.groupby(
            "category",
            dropna=False,
        )
    )

    category_reliable = (
        category_summary[
            category_summary["total_incidents"] >= 200
        ]
        .sort_values(
            [
                "sla_compliance_rate",
                "total_incidents",
            ],
            ascending=[True, False],
        )
    )

    print("\n3. LOWEST SLA CATEGORIES WITH AT LEAST 200 INCIDENTS")
    print(
        category_reliable.head(15)
        .round(2)
        .to_string(index=False)
    )

    group_summary = prepare_summary(
        incidents.groupby(
            "assignment_group",
            dropna=False,
        )
    )

    group_reliable = (
        group_summary[
            group_summary["total_incidents"] >= 200
        ]
        .sort_values(
            [
                "sla_compliance_rate",
                "total_incidents",
            ],
            ascending=[True, False],
        )
    )

    print("\n4. LOWEST SLA GROUPS WITH AT LEAST 200 INCIDENTS")
    print(
        group_reliable.head(15)
        .round(2)
        .to_string(index=False)
    )

    print("\n5. RESOLUTION-TIMESTAMP AVAILABILITY BY SLA STATUS")

    resolution_availability = (
        incidents.assign(
            has_resolution_timestamp=incidents[
                "resolved_at"
            ].notna()
        )
        .groupby(
            [
                "sla_status",
                "has_resolution_timestamp",
            ]
        )
        .size()
        .reset_index(name="total_incidents")
    )

    print(
        resolution_availability.to_string(index=False)
    )

    print("\n6. DATA-COVERAGE CHECK")

    monthly_coverage = (
        incidents.groupby("opened_month_start")
        .agg(
            total_incidents=("number", "nunique"),
        )
        .reset_index()
    )

    monthly_coverage["percentage_of_dataset"] = (
        monthly_coverage["total_incidents"]
        / len(incidents)
        * 100
    )

    print(
        monthly_coverage.round({
            "percentage_of_dataset": 2
        }).to_string(index=False)
    )

    core_period_count = incidents[
        incidents["opened_at"].between(
            "2016-02-29",
            "2016-05-31 23:59:59",
        )
    ].shape[0]

    print(
        "\nIncidents opened from February through May 2016:",
        f"{core_period_count:,}",
    )

    print(
        "Percentage of dataset in core period:",
        f"{core_period_count / len(incidents) * 100:.2f}%",
    )

    priority_reassignment.to_csv(
        OUTPUT_DIRECTORY
        / "priority_reassignment_analysis.csv",
        index=False,
    )

    reassignment_count_summary.to_csv(
        OUTPUT_DIRECTORY
        / "reassignment_count_analysis.csv",
        index=False,
    )

    category_reliable.to_csv(
        OUTPUT_DIRECTORY
        / "category_sla_hotspots.csv",
        index=False,
    )

    group_reliable.to_csv(
        OUTPUT_DIRECTORY
        / "assignment_group_sla_hotspots.csv",
        index=False,
    )

    monthly_coverage.to_csv(
        OUTPUT_DIRECTORY
        / "monthly_data_coverage.csv",
        index=False,
    )

    print("\nDeep-dive tables exported successfully.")


if __name__ == "__main__":
    main()