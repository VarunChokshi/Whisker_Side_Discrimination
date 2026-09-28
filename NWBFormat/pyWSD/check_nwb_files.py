"""Run NWBInspector (--config dandi) over each NWB data section and write one
pass/fail .txt report per section.

Sections (5 total):
    1. behavior/learning
    2. behavior/expert
    3. behavior/opto
    4. ephys/S1
    5. ephys/M1

A file "passes" if NWBInspector raises nothing at CRITICAL importance or
above -- CRITICAL, PYNWB_VALIDATION (schema errors), or ERROR (a check that
crashed) -- since that is what actually blocks a DANDI upload.
BEST_PRACTICE_VIOLATION / BEST_PRACTICE_SUGGESTION findings are recorded per
file for reference but do not affect pass/fail.

Run from the "nwb" conda environment (nwbinspector already installed there):
    conda activate nwb
    python check_nwb_files.py
"""

from __future__ import annotations

import datetime as _dt
from collections import defaultdict
from pathlib import Path

from nwbinspector import Importance, inspect_all, load_config

NWB_ROOT = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Data"
)
REPORT_DIR = NWB_ROOT.parent / "InspectorReports"

SECTIONS = [
    ("01_behavior_learning", "Behavior - Learning", NWB_ROOT / "behavior" / "learning"),
    ("02_behavior_expert", "Behavior - Expert", NWB_ROOT / "behavior" / "expert"),
    ("03_behavior_opto", "Behavior - Opto", NWB_ROOT / "behavior" / "opto"),
    ("04_ephys_S1", "Ephys - S1", NWB_ROOT / "ephys" / "S1"),
    ("05_ephys_M1", "Ephys - M1", NWB_ROOT / "ephys" / "M1"),
]

# Anything at or above this importance is treated as a failure.
FAILING_IMPORTANCE = Importance.CRITICAL.value


def inspect_section(section_dir: Path):
    """Run NWBInspector over one folder. Returns (files, messages_by_filename)."""
    files = sorted(section_dir.glob("*.nwb"))
    messages_by_file: dict[str, list] = defaultdict(list)

    if not files:
        return files, messages_by_file

    dandi_config = load_config("dandi")
    messages = list(
        inspect_all(
            path=section_dir,
            config=dandi_config,
            importance_threshold=Importance.BEST_PRACTICE_SUGGESTION,
            progress_bar=True,
        )
    )
    for msg in messages:
        messages_by_file[Path(msg.file_path).name].append(msg)

    return files, messages_by_file


def write_report(report_path: Path, label: str, section_dir: Path, files, messages_by_file):
    total = len(files)

    with open(report_path, "w", encoding="utf-8") as fh:
        fh.write(f"NWBInspector report - {label}\n")
        fh.write(f"Folder: {section_dir}\n")
        fh.write("Config: dandi\n")
        fh.write(f"Generated: {_dt.datetime.now().isoformat(timespec='seconds')}\n")
        fh.write("Pass criterion: no CRITICAL, PYNWB_VALIDATION, or ERROR findings\n\n")

        if total == 0:
            fh.write("No .nwb files found in this folder.\n")
            return

        failed_files = []
        passed_files = []
        for f in files:
            file_messages = messages_by_file.get(f.name, [])
            is_failed = any(m.importance.value >= FAILING_IMPORTANCE for m in file_messages)
            (failed_files if is_failed else passed_files).append(f.name)

        fh.write(f"{len(passed_files)}/{total} files passed\n\n")

        if failed_files:
            fh.write("Failed files:\n")
            for name in failed_files:
                fh.write(f"  - {name}\n")
                for m in messages_by_file[name]:
                    if m.importance.value >= FAILING_IMPORTANCE:
                        fh.write(
                            f"      [{m.importance.name}] {m.check_function_name}: "
                            f"{m.message} (location: {m.location or 'n/a'})\n"
                        )
            fh.write("\n")
        else:
            fh.write("No failures.\n\n")

        non_blocking = {
            name: [m for m in messages_by_file[name] if m.importance.value < FAILING_IMPORTANCE]
            for name in passed_files
            if any(m.importance.value < FAILING_IMPORTANCE for m in messages_by_file.get(name, []))
        }
        if non_blocking:
            fh.write("Non-blocking findings on passed files (informational only):\n")
            for name, msgs in non_blocking.items():
                fh.write(f"  - {name}\n")
                for m in msgs:
                    fh.write(f"      [{m.importance.name}] {m.check_function_name}: {m.message}\n")


def main():
    REPORT_DIR.mkdir(parents=True, exist_ok=True)
    overall = []

    for report_stem, label, section_dir in SECTIONS:
        print(f"\n=== {label} ({section_dir}) ===")
        files, messages_by_file = inspect_section(section_dir)
        report_path = REPORT_DIR / f"{report_stem}.txt"
        write_report(report_path, label, section_dir, files, messages_by_file)

        total = len(files)
        failed = sum(
            1
            for f in files
            if any(m.importance.value >= FAILING_IMPORTANCE for m in messages_by_file.get(f.name, []))
        )
        passed = total - failed
        overall.append((label, passed, total))
        print(f"{passed}/{total} passed -> {report_path}")

    print("\n=== Summary ===")
    for label, passed, total in overall:
        print(f"  {label}: {passed}/{total}")


if __name__ == "__main__":
    main()
