from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_FILE = PROJECT_ROOT / "data" / "raw" / "incident_event_log_raw.csv"

DATE_COLUMNS = [
    "opened_at",
    "sys_created_at",
    "sys_updated_at",
    "resolved_at",
    "closed_at",
]


def print_distribution(df, column, limit=20):
    print(f"\n{column.upper()} DISTRIBUTION")
    print(df[column].value_counts(dropna=False).head(limit).to_string())


def main():
    print("=" * 70)
    print("IT SERVICE DESK DATASET — DATA QUALITY INVESTIGATION")
    print("=" * 70)

    df = pd.read_csv(
        RAW_FILE,
        na_values=["?"],
        keep_default_na=True,
        low_memory=False,
    )

    print(f"\nRaw event records: {len(df):,}")
    print(f"Unique incidents: {df['number'].nunique():,}")

    # Convert timestamp columns into actual datetime values.
    for column in DATE_COLUMNS:
        original_non_null = df[column].notna().sum()

        df[column] = pd.to_datetime(
            df[column],
            format="mixed",
            dayfirst=True,
            errors="coerce",
        )

        parsed_non_null = df[column].notna().sum()
        failed_parsing = original_non_null - parsed_non_null

        print(f"\nDATE CHECK: {column}")
        print(f"Original non-null values: {original_non_null:,}")
        print(f"Successfully parsed: {parsed_non_null:,}")
        print(f"Failed to parse: {failed_parsing:,}")
        print(f"Earliest value: {df[column].min()}")
        print(f"Latest value: {df[column].max()}")

    # Sort lifecycle records and retain the latest available record per incident.
    df = df.sort_values(
        by=["number", "sys_mod_count", "sys_updated_at"],
        na_position="first",
    )

    incidents = df.drop_duplicates(
        subset="number",
        keep="last",
    ).copy()

    print("\n" + "=" * 70)
    print("INCIDENT-LEVEL SNAPSHOT")
    print("=" * 70)

    print(f"\nIncident-level rows: {len(incidents):,}")
    print(f"Unique incident numbers: {incidents['number'].nunique():,}")
    print(f"Duplicate incident numbers: {incidents['number'].duplicated().sum():,}")

    print_distribution(incidents, "incident_state")
    print_distribution(incidents, "priority")
    print_distribution(incidents, "impact")
    print_distribution(incidents, "urgency")
    print_distribution(incidents, "made_sla")
    print_distribution(incidents, "contact_type")
    print_distribution(incidents, "category", limit=15)
    print_distribution(incidents, "assignment_group", limit=15)

    print("\nREASSIGNMENT SUMMARY")
    print(incidents["reassignment_count"].describe().to_string())
    print(
        "Incidents reassigned at least once:",
        f"{(incidents['reassignment_count'] > 0).sum():,}",
    )

    print("\nREOPEN SUMMARY")
    print(incidents["reopen_count"].describe().to_string())
    print(
        "Incidents reopened at least once:",
        f"{(incidents['reopen_count'] > 0).sum():,}",
    )

    # Calculate lifecycle durations.
    incidents["resolution_hours"] = (
        incidents["resolved_at"] - incidents["opened_at"]
    ).dt.total_seconds() / 3600

    incidents["closure_hours"] = (
        incidents["closed_at"] - incidents["opened_at"]
    ).dt.total_seconds() / 3600

    print("\nRESOLUTION-TIME VALIDATION")
    print(
        "Missing resolution duration:",
        f"{incidents['resolution_hours'].isna().sum():,}",
    )
    print(
        "Negative resolution duration:",
        f"{(incidents['resolution_hours'] < 0).sum():,}",
    )
    print(incidents["resolution_hours"].describe().to_string())

    print("\nCLOSURE-TIME VALIDATION")
    print(
        "Missing closure duration:",
        f"{incidents['closure_hours'].isna().sum():,}",
    )
    print(
        "Negative closure duration:",
        f"{(incidents['closure_hours'] < 0).sum():,}",
    )
    print(incidents["closure_hours"].describe().to_string())

    print("\nLIFECYCLE ORDER CHECKS")
    resolved_before_opened = (
        incidents["resolved_at"].notna()
        & (incidents["resolved_at"] < incidents["opened_at"])
    ).sum()

    closed_before_opened = (
        incidents["closed_at"].notna()
        & (incidents["closed_at"] < incidents["opened_at"])
    ).sum()

    closed_before_resolved = (
        incidents["closed_at"].notna()
        & incidents["resolved_at"].notna()
        & (incidents["closed_at"] < incidents["resolved_at"])
    ).sum()

    print(f"Resolved before opened: {resolved_before_opened:,}")
    print(f"Closed before opened: {closed_before_opened:,}")
    print(f"Closed before resolved: {closed_before_resolved:,}")

    print("\nInvestigation completed successfully.")


if __name__ == "__main__":
    main()