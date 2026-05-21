from __future__ import annotations

import argparse
import json
import sys
from pathlib import Path

from food_quality import (
    audit_records,
    strip_internal_fields,
    write_json,
    write_suspects_csv,
)


DEFAULT_FILES = {
    "curated": Path("assets/data/foods_cleaned.json"),
    "branded": Path("assets/data/foods_brands_tr.json"),
}
DEFAULT_REPORT_DIR = Path("tools/food_quality_reports")


def _load_records(files: dict[str, Path]) -> list[tuple[str, int, dict]]:
    records: list[tuple[str, int, dict]] = []
    for source, path in files.items():
        payload = json.loads(path.read_text(encoding="utf-8"))
        if not isinstance(payload, list):
            raise ValueError(f"{path} must contain a JSON list")
        for index, item in enumerate(payload):
            if not isinstance(item, dict):
                raise ValueError(f"{path}[{index}] must be a JSON object")
            records.append((source, index, item))
    return records


def _split_by_source(kept: list[dict]) -> dict[str, list[dict]]:
    by_source = {"curated": [], "branded": []}
    for item in kept:
        source = item.get("_source")
        if source not in by_source:
            source = "branded" if item.get("brand") else "curated"
        by_source[source].append(item)
    return by_source


def _write_clean_assets(files: dict[str, Path], kept: list[dict]) -> dict[str, int]:
    by_source = _split_by_source(kept)
    clean_curated = [
        strip_internal_fields(item, include_brand=False)
        for item in by_source["curated"]
    ]
    clean_branded = [
        strip_internal_fields(item, include_brand=True)
        for item in by_source["branded"]
    ]
    write_json(files["curated"], clean_curated)
    write_json(files["branded"], clean_branded)
    return {
        "curated": len(clean_curated),
        "branded": len(clean_branded),
    }


def _write_reports(report_dir: Path, summary: dict, suspects: list[dict]) -> None:
    write_json(report_dir / "food_quality_summary.json", summary)
    write_json(report_dir / "food_quality_suspects.json", suspects)
    write_suspects_csv(report_dir / "food_quality_suspects.csv", suspects)


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Audit and clean FitRehber mobile food asset JSON files."
    )
    parser.add_argument(
        "--write",
        action="store_true",
        help="Write cleaned asset JSON files and report artifacts.",
    )
    parser.add_argument(
        "--report-dir",
        default=str(DEFAULT_REPORT_DIR),
        help="Directory for summary and suspect reports.",
    )
    parser.add_argument(
        "--curated",
        default=str(DEFAULT_FILES["curated"]),
        help="Path to foods_cleaned.json.",
    )
    parser.add_argument(
        "--branded",
        default=str(DEFAULT_FILES["branded"]),
        help="Path to foods_brands_tr.json.",
    )
    args = parser.parse_args()

    files = {
        "curated": Path(args.curated),
        "branded": Path(args.branded),
    }
    records = _load_records(files)
    kept, suspects, summary = audit_records(records)

    summary = {
        **summary,
        "mode": "write" if args.write else "dry-run",
        "files": {source: str(path) for source, path in files.items()},
    }

    print(json.dumps(summary, ensure_ascii=False, indent=2))

    if not args.write:
        print("\n[dry-run] No files were changed. Re-run with --write to apply.")
        return 0

    written_counts = _write_clean_assets(files, kept)
    summary = {
        **summary,
        "written_counts": written_counts,
    }
    _write_reports(Path(args.report_dir), summary, suspects)
    print(f"\n[write] cleaned assets: {written_counts}")
    print(f"[write] reports: {Path(args.report_dir)}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
