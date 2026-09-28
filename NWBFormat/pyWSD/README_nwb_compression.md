# NWB dataset compression (`compress_nwb_datasets.py`)

Enables gzip compression on the large uncompressed datasets that NWBInspector's
`check_small_dataset_compression` flags across the NWBData corpus — mainly the
`ecephys` `firing_rate` trace and the `piezo_stim` trace in the ephys files
(e.g. ~181 MB uncompressed out of a ~236 MB ephys file). This is a genuine
DANDI storage/bandwidth win, unlike the cosmetic metadata suggestions — it
doesn't affect anything DANDI requires for upload, but smaller files mean
faster upload/download and lower storage cost for anyone pulling the dataset.

## What compression actually does

This operates purely at the HDF5 storage layer — it does not change any
values, shapes, or the NWB schema.

- **Chunking + gzip.** HDF5 datasets are normally stored as one contiguous,
  uncompressed block. To compress a dataset, HDF5 first splits it into
  fixed-size **chunks**, then runs gzip on each chunk when writing, reversing
  it automatically on read. You can't just flip a "compression" flag on an
  existing dataset — the script deletes the dataset and recreates it with
  chunking + gzip, then writes the same data back into the new layout.
- **Why it works well here.** Gzip removes redundancy — repeated byte
  patterns, small value-to-value deltas, long runs of similar numbers. A
  firing-rate trace or a piezo stimulus trace is a smooth, slowly-varying
  signal, so it compresses well (often 2-4x). Spike times or already
  noise-like data compress much less.
- **It's lossless.** Every value that comes back out is bit-for-bit identical
  to what went in. The script's verification step does an exact
  `np.array_equal` against a pre-edit backup, not an approximate comparison —
  if even one value differed after decompression, it restores from backup and
  reports that file as failed rather than trust it.
- **Costs:**
  - *Write time, once*: gzip has to compress every chunk as the script
    writes it. Seconds per file at the default level, but it adds up across
    ~150+ ephys files in one run.
  - *Read time, every time after*: matnwb/pynwb decompresses each chunk on
    read. For arrays this size it's unnoticeable to a user.
  - *Compression level (`--level`, 1-9)*: higher = smaller file, slower to
    write. Does **not** meaningfully change read speed. Default is 4, a
    reasonable balance; 9 buys a little more space for real extra write time.
  - *Disk space during the run*: every touched file is backed up before
    being rewritten, so you temporarily need roughly double the space of
    whatever gets modified, until the backups are cleaned up.

## How to run it

```
conda activate nwb
cd "E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\FinalCodes"

python compress_nwb_datasets.py                     # dry run: lists candidate datasets + sizes, writes nothing
python compress_nwb_datasets.py --apply              # writes changes (with backups), can take a while
python compress_nwb_datasets.py --apply --level 6    # stronger (slower) compression
python compress_nwb_datasets.py --apply --no-backup  # skip backups (not recommended)
```

Always dry-run first and look at the printed candidate list before applying.

- Scans all 5 sections (`behavior/learning`, `behavior/expert`, `behavior/opto`,
  `ephys/S1`, `ephys/M1`) using NWBInspector's own thresholds (50 MB-20 GB,
  uncompressed), so it touches exactly what the inspector would flag — nothing
  is hardcoded to specific dataset names.
- Backups go to `InspectorReports\nwb_compression_backups\`, mirroring the
  original folder structure, so any file can be restored by copying it back.
- Prints per-file candidate datasets and sizes, then (in apply mode) the
  before/after size and verification result for each file, and a total
  before/after size summary at the end.
- If verification fails for a file, that file is automatically restored from
  its backup and reported as failed — it is never left in a half-written state.

## Related scripts in this folder

- `check_nwb_files.py` — runs NWBInspector (`--config dandi`) over all 5
  sections and writes a pass/fail report per section.
- `fix_nwb_metadata.py` — fixes the CRITICAL `check_subject_age` finding and
  the `check_experimenter_form` suggestion (experimenter name format). Run
  this before compression, not after — order doesn't matter functionally, but
  it's cleaner to fix metadata first and compress once at the end.
