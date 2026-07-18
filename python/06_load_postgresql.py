from getpass import getpass
from pathlib import Path

import pandas as pd
from sqlalchemy import URL, create_engine, text


PROJECT_ROOT = Path(__file__).resolve().parents[1]

EVENTS_FILE = (
    PROJECT_ROOT
    / "data"
    / "processed"
    / "incident_events_clean.csv"
)

INCIDENTS_FILE = (
    PROJECT_ROOT
    / "data"
    / "processed"
    / "incidents_analytical.csv"
)

DATABASE_NAME = "it_service_desk_analytics"

EVENT_DATE_COLUMNS = [
    "opened_at",
    "sys_created_at",
    "sys_updated_at",
    "resolved_at",
    "closed_at",
]

INCIDENT_DATE_COLUMNS = EVENT_DATE_COLUMNS + [
    "opened_date",
    "opened_month_start",
]


def main():
    print("=" * 70)
    print("LOAD PROCESSED DATA INTO POSTGRESQL")
    print("=" * 70)

    password = getpass("\nEnter PostgreSQL password: ")

    connection_url = URL.create(
        drivername="postgresql+psycopg",
        username="postgres",
        password=password,
        host="localhost",
        port=5432,
        database=DATABASE_NAME,
    )

    engine = create_engine(connection_url)

    with engine.begin() as connection:
        database = connection.execute(
            text("SELECT current_database();")
        ).scalar_one()

        connection.execute(
            text("CREATE SCHEMA IF NOT EXISTS staging;")
        )

    print(f"\nConnected to: {database}")
    print("Created or verified schema: staging")

    print("\nReading lifecycle-event dataset...")

    events = pd.read_csv(
        EVENTS_FILE,
        parse_dates=EVENT_DATE_COLUMNS,
        low_memory=False,
    )

    print(f"Event rows ready: {len(events):,}")

    print("\nLoading staging.incident_events...")

    events.to_sql(
        name="incident_events",
        con=engine,
        schema="staging",
        if_exists="replace",
        index=False,
        chunksize=1000,
        method="multi",
    )

    print("Lifecycle events loaded.")

    print("\nReading incident-level dataset...")

    incidents = pd.read_csv(
        INCIDENTS_FILE,
        parse_dates=INCIDENT_DATE_COLUMNS,
        low_memory=False,
    )

    print(f"Incident rows ready: {len(incidents):,}")

    print("\nLoading staging.incidents_analytical...")

    incidents.to_sql(
        name="incidents_analytical",
        con=engine,
        schema="staging",
        if_exists="replace",
        index=False,
        chunksize=1000,
        method="multi",
    )

    print("Incident-level data loaded.")

    with engine.connect() as connection:
        event_count = connection.execute(
            text(
                "SELECT COUNT(*) "
                "FROM staging.incident_events;"
            )
        ).scalar_one()

        incident_count = connection.execute(
            text(
                "SELECT COUNT(*) "
                "FROM staging.incidents_analytical;"
            )
        ).scalar_one()

        unique_incidents = connection.execute(
            text(
                "SELECT COUNT(DISTINCT number) "
                "FROM staging.incidents_analytical;"
            )
        ).scalar_one()

    print("\nDATABASE VALIDATION")
    print(f"Event-table rows: {event_count:,}")
    print(f"Incident-table rows: {incident_count:,}")
    print(f"Unique incidents: {unique_incidents:,}")

    if event_count != 141_712:
        raise ValueError("Event-table row count is incorrect.")

    if incident_count != 24_918:
        raise ValueError("Incident-table row count is incorrect.")

    if unique_incidents != 24_918:
        raise ValueError("Incident identifiers are not unique.")

    engine.dispose()

    print("\nPostgreSQL load completed successfully.")


if __name__ == "__main__":
    main()