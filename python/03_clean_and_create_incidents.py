from pathlib import Path

import pandas as pd


PROJECT_ROOT = Path(__file__).resolve().parents[1]

RAW_FILE = (
    PROJECT_ROOT
    / "data"
    / "raw"
    / "incident_event_log_raw.csv"
)

PROCESSED_DIRECTORY = PROJECT_ROOT / "data" / "processed"

EVENTS_OUTPUT = (
    PROCESSED_DIRECTORY
    / "incident_events_clean.csv"
)

INCIDENTS_OUTPUT = (
    PROCESSED_DIRECTORY
    / "incidents_analytical.csv"
)

DATE_COLUMNS = [
    "opened_at",
    "sys_created_at",
    "sys_updated_at",
    "resolved_at",
    "closed_at",
]


def extract_numeric_level(series):
    return pd.to_numeric(
        series.str.extract(r"^(\d+)")[0],
        errors="coerce",
    ).astype("Int64")


def main():
    print("=" * 70)
    print("CLEANING AND FEATURE ENGINEERING")
    print("=" * 70)

    PROCESSED_DIRECTORY.mkdir(parents=True, exist_ok=True)

    events = pd.read_csv(
        RAW_FILE,
        na_values=["?"],
        keep_default_na=True,
        low_memory=False,
    )

    print(f"\nRaw event rows: {len(events):,}")
    print(f"Raw columns: {events.shape[1]}")

    # Remove accidental spaces from column names and text values.
    events.columns = events.columns.str.strip()

    text_columns = events.select_dtypes(include=["object", "str"]).columns

    for column in text_columns:
        events[column] = events[column].str.strip()

    # Convert lifecycle timestamps.
    for column in DATE_COLUMNS:
        events[column] = pd.to_datetime(
            events[column],
            format="mixed",
            dayfirst=True,
            errors="coerce",
        )

    # Count lifecycle records belonging to each incident.
    event_counts = (
        events.groupby("number")
        .size()
        .rename("event_count")
    )

    # Sort chronologically and retain the final record per incident.
    events = events.sort_values(
        by=["number", "sys_mod_count", "sys_updated_at"],
        na_position="first",
    )

    incidents = (
        events.drop_duplicates(
            subset="number",
            keep="last",
        )
        .copy()
    )

    incidents = incidents.merge(
        event_counts,
        left_on="number",
        right_index=True,
        how="left",
        validate="one_to_one",
    )

    # Extract numeric levels while retaining the original labels.
    incidents["priority_level"] = extract_numeric_level(
        incidents["priority"]
    )

    incidents["impact_level"] = extract_numeric_level(
        incidents["impact"]
    )

    incidents["urgency_level"] = extract_numeric_level(
        incidents["urgency"]
    )

    # Create lifecycle duration measures.
    incidents["resolution_hours"] = (
        incidents["resolved_at"] - incidents["opened_at"]
    ).dt.total_seconds() / 3600

    incidents["closure_hours"] = (
        incidents["closed_at"] - incidents["opened_at"]
    ).dt.total_seconds() / 3600

    incidents["resolution_days"] = (
        incidents["resolution_hours"] / 24
    )

    incidents["closure_days"] = (
        incidents["closure_hours"] / 24
    )

    # Create operational flags.
    incidents["sla_status"] = incidents["made_sla"].map({
        True: "Met SLA",
        False: "Breached SLA",
    })

    incidents["was_reassigned"] = (
        incidents["reassignment_count"] > 0
    )

    incidents["was_reopened"] = (
        incidents["reopen_count"] > 0
    )

    # Create time-related dimensions.
    incidents["opened_date"] = incidents["opened_at"].dt.date
    incidents["opened_year"] = incidents["opened_at"].dt.year
    incidents["opened_month_number"] = incidents["opened_at"].dt.month
    incidents["opened_month_name"] = incidents["opened_at"].dt.month_name()
    incidents["opened_month_start"] = (
        incidents["opened_at"]
        .dt.to_period("M")
        .dt.to_timestamp()
    )
    incidents["opened_day_name"] = incidents["opened_at"].dt.day_name()
    incidents["opened_hour"] = incidents["opened_at"].dt.hour

    incidents["opened_on_weekend"] = (
        incidents["opened_at"].dt.dayofweek >= 5
    )

    # Create understandable resolution-time groups.
    incidents["resolution_time_band"] = pd.cut(
        incidents["resolution_hours"],
        bins=[
            float("-inf"),
            1,
            8,
            24,
            72,
            168,
            float("inf"),
        ],
        labels=[
            "Under 1 hour",
            "1–8 hours",
            "8–24 hours",
            "1–3 days",
            "3–7 days",
            "Over 7 days",
        ],
    )

    # Validation checks.
    if len(incidents) != events["number"].nunique():
        raise ValueError(
            "Incident snapshot does not contain exactly one row per incident."
        )

    if incidents["number"].duplicated().any():
        raise ValueError(
            "Duplicate incident numbers remain in the analytical dataset."
        )

    if (incidents["resolution_hours"].dropna() < 0).any():
        raise ValueError(
            "Negative resolution durations were found."
        )

    if (incidents["closure_hours"].dropna() < 0).any():
        raise ValueError(
            "Negative closure durations were found."
        )

    # Export the lifecycle-level and incident-level datasets.
    events.to_csv(
        EVENTS_OUTPUT,
        index=False,
        date_format="%Y-%m-%d %H:%M:%S",
    )

    incidents.to_csv(
        INCIDENTS_OUTPUT,
        index=False,
        date_format="%Y-%m-%d %H:%M:%S",
    )

    print("\nOUTPUT VALIDATION")
    print(f"Clean event rows: {len(events):,}")
    print(f"Analytical incident rows: {len(incidents):,}")
    print(f"Unique incidents: {incidents['number'].nunique():,}")
    print(f"Duplicate incidents: {incidents['number'].duplicated().sum():,}")
    print(f"Analytical columns: {incidents.shape[1]}")
    print(
        "Missing resolution hours:",
        f"{incidents['resolution_hours'].isna().sum():,}",
    )
    print(
        "SLA met:",
        f"{(incidents['sla_status'] == 'Met SLA').sum():,}",
    )
    print(
        "SLA breached:",
        f"{(incidents['sla_status'] == 'Breached SLA').sum():,}",
    )

    print(f"\nSaved: {EVENTS_OUTPUT}")
    print(f"Saved: {INCIDENTS_OUTPUT}")
    print("\nCleaning completed successfully.")


if __name__ == "__main__":
    main()