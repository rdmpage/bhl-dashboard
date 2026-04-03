#!/usr/bin/env python3
"""
Import BHL TSV data files into SQLite using schema.sql.
Only files whose base name (without extension) matches a table in the schema are imported.
"""

import csv
import re
import sqlite3
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).parent
SCHEMA_FILE = SCRIPT_DIR / "schema.sql"
DATA_DIR = SCRIPT_DIR / "data"
DB_FILE = DATA_DIR / "bhl.sqlite"


def table_names_from_schema(schema_sql: str) -> set[str]:
    """Extract table names from CREATE TABLE statements."""
    return {
        m.group(1).lower()
        for m in re.finditer(r"CREATE\s+TABLE\s+[`\"]?(\w+)[`\"]?", schema_sql, re.IGNORECASE)
    }


def find_tsv_files(data_dir: Path, tables: set[str]) -> dict[str, Path]:
    """Return {table_name: path} for TSV files whose stem matches a table name."""
    matches = {}
    for f in sorted(data_dir.iterdir()):
        if f.suffix.lower() in (".tsv", ".txt") and f.stem.lower() in tables:
            matches[f.stem.lower()] = f
    return matches


def import_tsv(conn: sqlite3.Connection, table: str, path: Path) -> int:
    """Import a TSV file into the named table. Returns row count inserted."""
    with path.open(encoding="utf-8", errors="replace") as fh:
        reader = csv.DictReader(fh, delimiter="\t")
        if reader.fieldnames is None:
            print(f"  WARNING: {path.name} appears empty, skipping.")
            return 0

        cols = ", ".join(f"`{c}`" for c in reader.fieldnames)
        placeholders = ", ".join("?" for _ in reader.fieldnames)
        sql = f"INSERT OR IGNORE INTO {table} ({cols}) VALUES ({placeholders})"

        count = 0
        batch = []
        BATCH_SIZE = 10_000

        for row in reader:
            batch.append(tuple(row.get(c) for c in reader.fieldnames))
            if len(batch) >= BATCH_SIZE:
                conn.executemany(sql, batch)
                count += len(batch)
                batch = []
                print(f"\r  {table}: {count:,} rows", end="", flush=True)

        if batch:
            conn.executemany(sql, batch)
            count += len(batch)

    return count


def main():
    if not SCHEMA_FILE.exists():
        sys.exit(f"ERROR: schema.sql not found at {SCHEMA_FILE}")
    if not DATA_DIR.exists():
        sys.exit(f"ERROR: data directory not found at {DATA_DIR}")

    schema_sql = SCHEMA_FILE.read_text()
    tables = table_names_from_schema(schema_sql)
    print(f"Tables in schema: {', '.join(sorted(tables))}")

    tsv_files = find_tsv_files(DATA_DIR, tables)
    if not tsv_files:
        sys.exit("ERROR: No matching TSV/TXT files found in data/. Has data.zip been extracted?")

    print(f"Matched files: {', '.join(sorted(tsv_files))}")
    missing = tables - set(tsv_files)
    if missing:
        print(f"WARNING: No file found for tables: {', '.join(sorted(missing))}")

    if DB_FILE.exists():
        print(f"\nRemoving existing database: {DB_FILE}")
        DB_FILE.unlink()

    print(f"Creating database: {DB_FILE}\n")
    conn = sqlite3.connect(DB_FILE)
    conn.executescript("PRAGMA journal_mode=WAL; PRAGMA synchronous=NORMAL;")

    # Apply schema (tables + indexes)
    conn.executescript(schema_sql)
    conn.commit()

    for table, path in sorted(tsv_files.items()):
        print(f"Importing {path.name} -> {table}")
        count = import_tsv(conn, table, path)
        conn.commit()
        print(f"\r  {table}: {count:,} rows  done")

    conn.close()
    size_mb = DB_FILE.stat().st_size / 1_048_576
    print(f"\nDone. {DB_FILE} ({size_mb:.1f} MB)")


if __name__ == "__main__":
    main()
