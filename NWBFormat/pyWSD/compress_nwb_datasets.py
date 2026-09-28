"""Enable gzip compression on the large uncompressed datasets NWBInspector's
check_small_dataset_compression flags across the NWBData corpus -- mainly the
ecephys firing_rate trace and piezo_stim trace in the ephys files (e.g.
~181 MB uncompressed out of a ~236 MB ephys file), a genuine DANDI
storage/bandwidth win, unlike the cosmetic metadata suggestions.

This uses NWBInspector's own thresholds (50 MB - 20 GB, uncompressed) to find
candidate datasets in each file, so what it touches matches exactly what the
inspector reports. For each candidate: read the full array + every HDF5
attribute, delete the dataset, recreate it at the same path with chunking and
gzip compression, write the data back, and reattach the attributes. This
changes only the on-disk storage layout -- the array values, shape, and dtype
are unchanged, so it is invisible to pynwb/NWBInspector above the HDF5 layer.

Safety:
    - Defaults to a dry run: lists candidate datasets and their sizes, writes
      nothing.
    - Pass --apply to actually write.
    - Unless --no-backup, each file is copied to
      InspectorReports/nwb_compression_backups/<relative path> before being
      modified -- this can be tens of GB, make sure there's room.
    - After writing, every recompressed dataset is read back and compared
      element-wise (np.array_equal, exact -- gzip is lossless) against the
      backup copy. If anything doesn't match, the original is restored from
      backup immediately and the file is reported as FAILED.
    - Reports total on-disk size before/after per file and overall.

Run from the "nwb" conda environment:
    conda activate nwb
    python compress_nwb_datasets.py                     # dry run, no files touched
    python compress_nwb_datasets.py --apply              # writes changes (with backups)
    python compress_nwb_datasets.py --apply --level 6    # stronger (slower) compression
"""

from __future__ import annotations

import argparse
import shutil
from pathlib import Path

import h5py
import numpy as np

NWB_ROOT = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Data"
)
BACKUP_ROOT = NWB_ROOT.parent / "InspectorReports" / "nwb_compression_backups"

SECTIONS = [
    NWB_ROOT / "behavior" / "learning",
    NWB_ROOT / "behavior" / "expert",
    NWB_ROOT / "behavior" / "opto",
    NWB_ROOT / "ephys" / "S1",
    NWB_ROOT / "ephys" / "M1",
]

# Matches nwbinspector.checks._nwb_containers.check_small_dataset_compression defaults.
MB_LOWER_BOUND = 50.0
GB_UPPER_BOUND = 20.0


def find_all_nwb_files():
    return [p for folder in SECTIONS for p in sorted(folder.glob("*.nwb"))]


def backup_file(path: Path):
    rel = path.relative_to(NWB_ROOT)
    backup_path = BACKUP_ROOT / rel
    backup_path.parent.mkdir(parents=True, exist_ok=True)
    if not backup_path.exists():
        shutil.copy2(path, backup_path)


def find_candidates(path: Path):
    """Return [(dataset_path, size_bytes)] for uncompressed datasets in the
    size window NWBInspector flags."""
    candidates = []

    def visit(name, obj):
        if not isinstance(obj, h5py.Dataset) or obj.compression is not None:
            return
        size_bytes = obj.size * obj.dtype.itemsize
        if MB_LOWER_BOUND * 1e6 < size_bytes < GB_UPPER_BOUND * 1e9:
            candidates.append((name, size_bytes))

    with h5py.File(path, "r") as f:
        f.visititems(visit)
    return candidates


def recompress_dataset(f: h5py.File, dataset_path: str, level: int):
    dataset = f[dataset_path]
    data = dataset[()]
    attrs = dict(dataset.attrs)
    dtype = dataset.dtype

    del f[dataset_path]
    new_dataset = f.create_dataset(
        dataset_path, data=data, dtype=dtype, chunks=True, compression="gzip", compression_opts=level
    )
    for key, value in attrs.items():
        new_dataset.attrs[key] = value


def verify_dataset(current_path: Path, backup_path: Path, dataset_path: str) -> bool:
    with h5py.File(current_path, "r") as fcur, h5py.File(backup_path, "r") as fbak:
        return np.array_equal(fcur[dataset_path][()], fbak[dataset_path][()])


def storage_size(path: Path) -> int:
    return path.stat().st_size


def process_file(path: Path, apply: bool, level: int, totals: dict):
    candidates = find_candidates(path)
    if not candidates:
        return

    before_size = storage_size(path)
    totals["before"] += before_size
    print(f"{path.relative_to(NWB_ROOT)}  ({before_size / 1e6:.1f} MB)")
    for name, size_bytes in candidates:
        print(f"    {name}: {size_bytes / 1e6:.1f} MB, uncompressed")

    if not apply:
        totals["after"] += before_size  # unchanged in dry run
        return

    backup_file(path)
    backup_path = BACKUP_ROOT / path.relative_to(NWB_ROOT)

    with h5py.File(path, "r+") as f:
        for name, _ in candidates:
            recompress_dataset(f, name, level)

    ok = all(verify_dataset(path, backup_path, name) for name, _ in candidates)
    after_size = storage_size(path)

    if not ok:
        print("    [VERIFICATION FAILED] restoring original file from backup.")
        shutil.copy2(backup_path, path)
        totals["after"] += before_size
        totals["failed"] += 1
        return

    totals["after"] += after_size
    saved_pct = 100 * (1 - after_size / before_size) if before_size else 0
    print(f"    Verified OK. {before_size / 1e6:.1f} MB -> {after_size / 1e6:.1f} MB "
          f"({saved_pct:.0f}% smaller)")


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Actually write changes (default: dry run).")
    parser.add_argument("--no-backup", action="store_true", help="Skip backing up files before editing.")
    parser.add_argument("--level", type=int, default=4, help="gzip compression level 1-9 (default 4).")
    args = parser.parse_args()

    global backup_file
    if args.no_backup:
        def backup_file(path: Path):  # noqa: F811
            pass

    all_files = find_all_nwb_files()
    print(f"Scanning {len(all_files)} .nwb files for datasets between "
          f"{MB_LOWER_BOUND:.0f} MB and {GB_UPPER_BOUND:.0f} GB with no compression.")
    if not args.apply:
        print("*** DRY RUN -- pass --apply to actually write changes ***\n")
    else:
        print(f"*** APPLY MODE -- gzip level {args.level}, backups going to {BACKUP_ROOT} ***\n")

    totals = {"before": 0, "after": 0, "failed": 0}
    for path in all_files:
        process_file(path, apply=args.apply, level=args.level, totals=totals)

    print("\n=== Summary ===")
    print(f"Total size before: {totals['before'] / 1e9:.2f} GB")
    print(f"Total size after:  {totals['after'] / 1e9:.2f} GB")
    if args.apply and totals["failed"]:
        print(f"{totals['failed']} file(s) failed verification and were restored from backup.")


if __name__ == "__main__":
    main()
