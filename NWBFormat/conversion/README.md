# conversion — `se` → NWB

How the NWB dataset was built from the lab's `MSessionExplorer` (`se`) recordings.
This is **provenance**: it documents how the released NWB files were produced. Most
users reproducing manuscript figures do **not** need to run anything here — they can
download the finished NWB set from DANDI *(add link)* and go straight to
[`../matWSD/`](../matWSD/README.md) or [`../pyWSD/`](../pyWSD/README.md).

Conversion is a two-step, two-language process for each data type: a **MATLAB dump**
flattens the `se` object to a plain, `-v7` `.mat` struct (`scipy`-readable), then a
**Python converter** writes the NWB file from that struct.

| Data type | 1. MATLAB dump (`se` → struct) | 2. Python convert (struct → NWB) |
|-----------|--------------------------------|----------------------------------|
| Behavior  | `dump_se_to_struct.m`, `dump_behavior_folder.m` | `convert_bodyside_behavior.py` |
| Ephys     | `dump_ephys_se_to_struct.m`, `dump_ephys_folder.m` | `convert_ephys_to_nwb.py` |

`getPerfOverall.m` is a helper used during the behavior dump.
`README_behavior_conversion.md` has the detailed behavior-conversion notes.

## Requirements

- **Step 1 (MATLAB dump):** the lab `MSessionExplorer` class and the `ManyFunctions`
  package on the MATLAB path (from the `bodyside` project). These are what read the
  original `se` objects; they are **not** needed for anything downstream.
- **Step 2 (Python convert):** `pynwb`, `numpy`, `scipy` (`pip install pynwb numpy scipy`).

## Outline

1. Point the `dump_*_folder.m` script at a folder of `se` recordings and run it in
   MATLAB; it writes one `*_struct.mat` per session.
2. Point the matching `convert_*.py` at those `_struct.mat` files; it writes the NWB
   files into the `NWBData\Data\...` layout the figure pipelines expect.

The scripts here are copies of the working conversion code kept under
`NWBData\Conversion` on the development machine, included in the repository for
provenance and reproducibility.

*(This README was auto-drafted for the public release — edit freely.)*
