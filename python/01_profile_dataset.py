from pathlib import Path

import pandas as pd


# Build paths relative to the project folder
PROJECT_ROOT = Path(__file__).resolve().parents[1]
RAW_FILE = PROJECT_ROOT / "data" / "raw" / "incident_event_log_raw.csv"


def main():
    print("=" * 70)
    print("IT SERVICE DESK DATASET — INITIAL PROFILING")
    print("=" * 70)

    if not RAW_FILE.exists():
        raise FileNotFoundError(f"Dataset not found: {RAW_FILE}")

    # The UCI dataset uses '?' to represent unknown values.
    df = pd.read_csv(
        RAW_FILE,
        na_values=["?"],
        keep_default_na=True,
        low_memory=False
    )

    print("\n1. DATASET DIMENSIONS")
    print(f"Rows: {df.shape[0]:,}")
    print(f"Columns: {df.shape[1]}")

    print("\n2. COLUMN NAMES")
    for position, column in enumerate(df.columns, start=1):
        print(f"{position:>2}. {column}")

    print("\n3. FIRST FIVE ROWS")
    print(df.head().to_string())

    print("\n4. DATA TYPES")
    print(df.dtypes.to_string())

    print("\n5. MISSING VALUES")
    missing_count = df.isna().sum()
    missing_percentage = (missing_count / len(df) * 100).round(2)

    missing_summary = pd.DataFrame({
        "Missing Count": missing_count,
        "Missing Percentage": missing_percentage
    }).sort_values("Missing Count", ascending=False)

    print(missing_summary.to_string())

    print("\n6. EXACT DUPLICATE ROWS")
    print(f"Duplicate rows: {df.duplicated().sum():,}")

    print("\n7. UNIQUE VALUES PER COLUMN")
    print(df.nunique(dropna=False).sort_values().to_string())

    if "number" in df.columns:
        print("\n8. INCIDENT IDENTIFIERS")
        print(f"Unique incidents: {df['number'].nunique():,}")
        print(f"Repeated event records: {len(df) - df['number'].nunique():,}")

    print("\n9. NUMERIC SUMMARY")
    print(df.describe(include="number").transpose().to_string())

    print("\nProfiling completed successfully.")


if __name__ == "__main__":
    main()