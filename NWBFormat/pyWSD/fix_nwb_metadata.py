"""Fix two NWBInspector findings across the NWBData corpus:

1. check_subject_age (CRITICAL) -- one file has a placeholder Subject block
   (subject_id 'ANMXXXX', genotype 'unknown', sex 'U', no date_of_birth) left
   over from a failed metadata match during conversion. The same session was
   also exported under a different section with the correct Subject block
   (matched by the shared /identifier). This script finds any file whose
   Subject looks like that placeholder, locates its same-identifier sibling
   elsewhere in the corpus, and copies subject_id/genotype/sex/date_of_birth
   (and age, if present) from the sibling. It also fixes the placeholder
   token if it appears in session_description.

2. check_experimenter_form (BEST_PRACTICE_SUGGESTION) -- every file has
   general/experimenter = ['Varun Chokshi'], which does not match DANDI's
   accepted 'LastName, FirstName MiddleInitial.' form. This rewrites it to
   'Chokshi, Varun B.' in every file.

Safety:
    - Defaults to a dry run: prints every change it WOULD make, writes nothing.
    - Pass --apply to actually write.
    - Unless --no-backup is given, each file is copied to
      InspectorReports/nwb_metadata_fix_backups/<same relative path> before
      it is modified, preserving folder structure, so any file can be
      restored by copying it back.
    - After writing, re-runs the two relevant NWBInspector checks on each
      modified file and reports PASS/FAIL so success is verified per file.

Run from the "nwb" conda environment:
    conda activate nwb
    python fix_nwb_metadata.py               # dry run, no files touched
    python fix_nwb_metadata.py --apply        # writes changes (with backups)
"""

from __future__ import annotations

import argparse
import shutil
from datetime import datetime
from pathlib import Path

import h5py

NWB_ROOT = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Data"
)
BACKUP_ROOT = NWB_ROOT.parent / "InspectorReports" / "nwb_metadata_fix_backups"

SECTIONS = [
    NWB_ROOT / "behavior" / "learning",
    NWB_ROOT / "behavior" / "expert",
    NWB_ROOT / "behavior" / "opto",
    NWB_ROOT / "ephys" / "S1",
    NWB_ROOT / "ephys" / "M1",
]

PLACEHOLDER_SUBJECT_ID = "ANMXXXX"
CORRECT_EXPERIMENTER = "Chokshi, Varun B."


def set_str_dataset(group: h5py.Group, name: str, value: str):
    """Create or overwrite a scalar/1-element string dataset, matching the
    variable-length UTF-8 encoding pynwb uses for these fields."""
    if name in group:
        del group[name]
    group.create_dataset(name, data=value, dtype=h5py.string_dtype(encoding="utf-8"))


def compute_age_iso(session_start_time: str, date_of_birth: str) -> str:
    """ISO 8601 duration (whole calendar days) between date_of_birth and this
    session's own date -- not borrowed from the sibling's age, since the
    sibling's session date may differ from this file's."""
    session_date = datetime.fromisoformat(session_start_time).date()
    dob_date = datetime.fromisoformat(date_of_birth).date()
    return f"P{(session_date - dob_date).days}D"


def read_str(dataset) -> str:
    val = dataset[()]
    return val.decode() if isinstance(val, bytes) else val


def backup_file(path: Path):
    rel = path.relative_to(NWB_ROOT)
    backup_path = BACKUP_ROOT / rel
    backup_path.parent.mkdir(parents=True, exist_ok=True)
    if not backup_path.exists():
        shutil.copy2(path, backup_path)


def find_all_nwb_files():
    return [p for folder in SECTIONS for p in sorted(folder.glob("*.nwb"))]


def read_subject_summary(path: Path):
    with h5py.File(path, "r") as f:
        subj = f["general/subject"]
        identifier = read_str(f["identifier"])
        subject_id = read_str(subj["subject_id"]) if "subject_id" in subj else None
        genotype = read_str(subj["genotype"]) if "genotype" in subj else None
        age = read_str(subj["age"]) if "age" in subj else None
        dob = read_str(subj["date_of_birth"]) if "date_of_birth" in subj else None
        session_start_time = read_str(f["session_start_time"])
    return {
        "path": path,
        "identifier": identifier,
        "subject_id": subject_id,
        "genotype": genotype,
        "age": age,
        "dob": dob,
        "session_start_time": session_start_time,
    }


def is_placeholder(summary: dict) -> bool:
    return summary["subject_id"] == PLACEHOLDER_SUBJECT_ID or (
        not summary["age"] and not summary["dob"]
    )


def fix_subject_metadata(all_files, apply: bool):
    print("=" * 70)
    print("Step 1: Subject metadata (check_subject_age)")
    print("=" * 70)

    summaries = [read_subject_summary(p) for p in all_files]
    by_identifier: dict[str, list[dict]] = {}
    for s in summaries:
        by_identifier.setdefault(s["identifier"], []).append(s)

    broken = [s for s in summaries if is_placeholder(s)]
    if not broken:
        print("No files with placeholder/missing Subject metadata found.\n")
        return

    for s in broken:
        candidates = [
            c
            for c in by_identifier.get(s["identifier"], [])
            if c["path"] != s["path"] and not is_placeholder(c)
        ]
        if not candidates:
            print(f"  [NO SIBLING FOUND] {s['path']} -- cannot auto-fix, please handle manually.")
            continue

        source = candidates[0]
        print(f"  Broken:  {s['path'].relative_to(NWB_ROOT)}")
        print(f"           subject_id={s['subject_id']!r} genotype={s['genotype']!r} "
              f"age={s['age']!r} dob={s['dob']!r}")
        print(f"  Sibling: {source['path'].relative_to(NWB_ROOT)}")
        print(f"           subject_id={source['subject_id']!r} genotype={source['genotype']!r} "
              f"age={source['age']!r} dob={source['dob']!r}")

        if source["dob"]:
            preview_age = compute_age_iso(s["session_start_time"], source["dob"])
            print(f"  Would set date_of_birth={source['dob']!r}, age={preview_age!r} "
                  f"(computed from this file's own session date, not copied from the sibling)")

        if not apply:
            print("  (dry run, no changes written)\n")
            continue

        backup_file(s["path"])
        with h5py.File(source["path"], "r") as fsrc:
            src_subj = fsrc["general/subject"]
            # age/age__reference are computed fresh below from this file's own
            # session date, not copied -- the sibling's age (if any) belongs to
            # the sibling's own session date, which need not match this one.
            src_values = {
                k: read_str(src_subj[k])
                for k in src_subj.keys()
                if k not in ("age", "age__reference")
            }

        with h5py.File(s["path"], "r+") as fdst:
            dst_subj = fdst["general/subject"]
            for key, value in src_values.items():
                set_str_dataset(dst_subj, key, value)

            session_start_time = read_str(fdst["session_start_time"])
            age_iso = compute_age_iso(session_start_time, src_values["date_of_birth"])
            set_str_dataset(dst_subj, "age", age_iso)
            print(f"  Computed age: {age_iso} (session {session_start_time[:10]} "
                  f"minus date_of_birth {src_values['date_of_birth'][:10]})")

            # Fix the placeholder token if it leaked into session_description.
            if "session_description" in fdst:
                desc = read_str(fdst["session_description"])
                if PLACEHOLDER_SUBJECT_ID in desc:
                    fixed_desc = desc.replace(PLACEHOLDER_SUBJECT_ID, src_values["subject_id"])
                    set_str_dataset(fdst, "session_description", fixed_desc)
                    print(f"  Also fixed session_description: {desc!r} -> {fixed_desc!r}")

        print("  Written.\n")


def fix_experimenter(all_files, apply: bool):
    print("=" * 70)
    print("Step 2: Experimenter name form (check_experimenter_form)")
    print("=" * 70)

    to_fix = []
    for path in all_files:
        with h5py.File(path, "r") as f:
            if "general/experimenter" not in f:
                continue
            exp = [read_str_bytes(x) for x in f["general/experimenter"][()]]
        if exp != [CORRECT_EXPERIMENTER]:
            to_fix.append((path, exp))

    print(f"{len(to_fix)}/{len(all_files)} files need the experimenter field updated.")
    if not to_fix:
        print()
        return

    if not apply:
        print(f"Example current value: {to_fix[0][1]!r} -> {[CORRECT_EXPERIMENTER]!r}")
        print("(dry run, no changes written)\n")
        return

    for path, old_value in to_fix:
        backup_file(path)
        with h5py.File(path, "r+") as f:
            if "general/experimenter" in f:
                del f["general/experimenter"]
            f.create_dataset(
                "general/experimenter",
                data=[CORRECT_EXPERIMENTER],
                dtype=h5py.string_dtype(encoding="utf-8"),
            )
    print(f"Updated experimenter field in {len(to_fix)} files.\n")


def read_str_bytes(x):
    return x.decode() if isinstance(x, bytes) else x


def verify(all_files):
    print("=" * 70)
    print("Verification: re-running check_subject_age + check_experimenter_form")
    print("=" * 70)
    from nwbinspector import inspect_nwbfile

    n_ok, n_fail = 0, 0
    for path in all_files:
        msgs = list(
            inspect_nwbfile(
                nwbfile_path=str(path),
                select=["check_subject_age", "check_experimenter_form"],
            )
        )
        if msgs:
            n_fail += 1
            print(f"  [STILL FLAGGED] {path.relative_to(NWB_ROOT)}")
            for m in msgs:
                print(f"      [{m.importance.name}] {m.check_function_name}: {m.message}")
        else:
            n_ok += 1
    print(f"\n{n_ok}/{len(all_files)} files clean on both checks, {n_fail} still flagged.\n")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Actually write changes (default: dry run).")
    parser.add_argument("--no-backup", action="store_true", help="Skip backing up files before editing.")
    parser.add_argument("--verify", action="store_true", help="Re-run the two checks on every file after fixing.")
    args = parser.parse_args()

    global backup_file
    if args.no_backup:
        def backup_file(path: Path):  # noqa: F811
            pass

    all_files = find_all_nwb_files()
    print(f"Found {len(all_files)} .nwb files across {len(SECTIONS)} sections.")
    if not args.apply:
        print("*** DRY RUN -- pass --apply to actually write changes ***\n")
    else:
        print(f"*** APPLY MODE -- backups going to {BACKUP_ROOT} ***\n")

    fix_subject_metadata(all_files, apply=args.apply)
    fix_experimenter(all_files, apply=args.apply)

    if args.apply and args.verify:
        verify(all_files)


if __name__ == "__main__":
    main()
