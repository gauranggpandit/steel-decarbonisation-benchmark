"""Build db/steel.duckdb from the raw Global Energy Monitor files.

Run from the steel-benchmark folder:
    python src/load_gist.py
"""
from pathlib import Path
import re

import duckdb
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]
RAW = ROOT / "data" / "raw"
DB = ROOT / "db" / "steel.duckdb"
SQL = ROOT / "sql" / "01_clean_views.sql"

PLANT_FILE = RAW / "Plant-level data - Global Iron and Steel Tracker - September 2026 (V1).xlsx"
OWN_FILE = RAW / "Global-Energy-Ownership-Tracker-November-2026-V1.xlsx"

# raw table name -> (file, sheet)
SOURCES = {
    "raw_plants": (PLANT_FILE, "Plant data"),
    "raw_capacities": (PLANT_FILE, "Plant capacities and status"),
    "raw_production": (PLANT_FILE, "Plant production"),
    "raw_entity_ownership": (OWN_FILE, "Entity Ownership"),
}


def clean(col):
    """Column names to snake_case; year columns 2019 -> y2019."""
    col = str(col).strip().lower()
    if col.isdigit():
        return "y" + col
    return re.sub(r"[^a-z0-9]+", "_", col).strip("_")


def main():
    con = duckdb.connect(str(DB))

    for table, (path, sheet) in SOURCES.items():
        df = pd.read_excel(path, sheet_name=sheet)
        df.columns = [clean(c) for c in df.columns]
        con.register("df_tmp", df)
        con.execute(f"CREATE OR REPLACE TABLE {table} AS SELECT * FROM df_tmp")
        con.unregister("df_tmp")
        print(f"{table}: {len(df):,} rows")

    con.execute(SQL.read_text())
    print("Clean views built.\n")

    print(con.execute("""
        SELECT company, plants,
               ROUND(crude_mtpa, 1) AS crude_mtpa,
               ROUND(100 * eaf_share) AS eaf_share_pct
        FROM company_benchmark
        ORDER BY crude_mtpa DESC
    """).df().to_string(index=False))

    con.close()


if __name__ == "__main__":
    main()