# Bodyside → NWB: behavioral pipeline (learning + expert)

The behavior half of the project. Two figure sets, both built the same way:

```
  se .mat  ──(MATLAB)──►  *_struct.mat  ──(Python)──►  *.nwb  ──(Python or MATLAB)──►  figure panels
           dump_se_to_struct        convert_bodyside_behavior.py          fig1_*_nwb
```

- **Learning set** — all curated training sessions → the Fig1 *learning* plot
  (number of sessions per mouse to reach expert, WT vs KO).
- **Expert set** — expert (no-opto) sessions → the Fig1 / Fig S1 *performance* panels
  (correct fraction, miss fraction, stimulus amplitude, WT vs KO).

Why the se→struct→NWB detour: an `se` is a custom MATLAB class whose `userData` holds
MATLAB `table`s and `datetime`s Python can't read. The MATLAB step flattens each `se`
to a plain struct (`se_struct`, `-v7`); the Python step reads that and writes NWB. No
`matlab.engine` needed.

Everything below uses full paths under the project root
`E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1` (shortened to
`…\bodyside_S1` here for readability — use the full path when running).

---

## Prerequisites

**MATLAB** — `MSessionExplorer` on the path (for the dump), and **matnwb** (for the
MATLAB figure ports):
```matlab
addpath(genpath('C:\Users\VarunChokshi\Documents\GitHub\lab1\packages\ManyFunctions'))  % MSessionExplorer
addpath('…\bodyside_S1\NWBData\Conversion')                                              % dump_* functions
addpath('…\bodyside_S1\NWBData\FinalCodes')                                              % figure ports + readBehaviorNWB
addpath(genpath('C:\Users\VarunChokshi\Documents\GitHub\matnwb'))                        % matnwb
% one time per matnwb install / MATLAB version:
cd('C:\Users\VarunChokshi\Documents\GitHub\matnwb'); generateCore(); cd('…\bodyside_S1')
```

**Python** (the `nwb` conda env):
```bash
pip install pynwb nwbinspector scipy numpy python-dateutil pandas matplotlib openpyxl
```
(`pandas`/`matplotlib`/`openpyxl` are only needed by the figure ports; the converter
itself needs just `pynwb scipy numpy python-dateutil`.)

---

## Step 1 — dump se → struct (MATLAB)

Dump each set into its own struct folder. `dump_behavior_folder` matches `*se.mat`
only (skips `*se enriched.mat`) and keeps going if one file fails.

```matlab
% LEARNING — dump from learningSEs (the folder Fig1_BS_Behav.m reads). NOT behavSEs:
% behavSEs is a broader collection whose session set does not match the manuscript.
dump_behavior_folder('…\bodyside_S1\SeData\VC0301\learningSEs', ...
                     '…\bodyside_S1\NWBData\Conversion\behav_struct');

% EXPERT — dump from NoOptoSess:
dump_behavior_folder('…\bodyside_S1\SeData\VC0301\NoOptoSess', ...
                     '…\bodyside_S1\NWBData\Conversion\behav_struct_expert');
```
Dumping is single-threaded — don't run other commands in that MATLAB until it prints
`Done: N/N dumped`, or you'll interrupt it.

---

## Step 2 — convert struct → NWB (Python, `nwb` env)

```bash
# LEARNING
python -u "…\bodyside_S1\NWBData\Conversion\convert_bodyside_behavior.py" ^
  --in-dir  "…\bodyside_S1\NWBData\Conversion\behav_struct" ^
  --out-dir "…\bodyside_S1\NWBData\Data\behavior\learning" ^
  --animal-info "…\bodyside_S1\SeData\VC0301\SessInfoNoOpto" --no-inspect

# EXPERT
python -u "…\bodyside_S1\NWBData\Conversion\convert_bodyside_behavior.py" ^
  --in-dir  "…\bodyside_S1\NWBData\Conversion\behav_struct_expert" ^
  --out-dir "…\bodyside_S1\NWBData\Data\behavior\expert" ^
  --animal-info "…\bodyside_S1\SeData\VC0301\SessInfoNoOpto" --no-inspect
```
Each session becomes e.g. `VC030109_2022-12-29_a.nwb`. `--no-inspect` skips the (slow)
`nwbinspector` pass; drop it to validate. `--animal-info` fills per-animal DOB/sex for
early learning sessions whose `se` has an empty `sessionInfo` (without it those files
still convert but the Subject lacks DOB — an `nwbinspector` CRITICAL).

---

## Step 3 — reproduce the figures (Python and MATLAB give the same result)

### Learning plot — `fig1_learning_nwb`

```bash
python "…\bodyside_S1\NWBData\FinalCodes\fig1_learning_nwb.py" ^
  --nwb-dir  "…\bodyside_S1\NWBData\Data\behavior\learning" ^
  --sessinfo "…\bodyside_S1\SeData\VC0301\LearningSessInfo\SessionInfo.xlsx" ^
  --out-dir  "…\bodyside_S1\NWBData\Figures\Fig1_python"
```
```matlab
fig1_learning_nwb('…\bodyside_S1\NWBData\Data\behavior\learning', ...
    '…\bodyside_S1\SeData\VC0301\LearningSessInfo\SessionInfo.xlsx', ...
    '…\bodyside_S1\NWBData\Figures\Fig1_matlab');
```
Expected (both ports, matching the current `.mat` pipeline): **WT n=10, per-mouse
`[66 35 10 45 9 8 39 22 14 39]`, mean 28.7; KO n=8, `[40 27 46 15 13 40 17 42]`, mean
30.0; ttest p≈0.869, ranksum p≈0.446.** (MATLAB run ~7 min over ~1150 files.)

### Expert performance panels — `fig1_behav_nwb`

```bash
python "…\bodyside_S1\NWBData\FinalCodes\fig1_behav_nwb.py" ^
  --nwb-dir "…\bodyside_S1\NWBData\Data\behavior\expert" ^
  --out-dir "…\bodyside_S1\NWBData\Figures\Fig1_python_expert"
```
```matlab
fig1_behav_nwb('…\bodyside_S1\NWBData\Data\behavior\expert', ...
    '…\bodyside_S1\NWBData\Figures\Fig1_matlab_expert');
```
Writes 8 panels — correct fraction and miss fraction (× overall / left / right) and
stimulus amplitude (left / right) — plus `Fig1behavMeanvals.txt` (per-genotype
means/SDs and Mann-Whitney p-values). Add `--include-all` (Python) /
`includeAll=true` (MATLAB) to keep the pilot animals in.

Determinism: the correct/miss means, SDs and p-values are exact per-mouse pooled
statistics — Python and MATLAB agree to the last digit. The amplitude point and all
error bars come from a multilevel bootstrap (nboot=1000); MATLAB uses `rng(7)` and
matches the original figure to ~0.02, Python uses NumPy's RNG and lands within ~0.5.

---

## Cohort & data notes (important)

**Learning cohort.** Only the 18 animals with a training window in
`LearningSessInfo\SessionInfo.xlsx` count — **10 WT** (VC030105–115) and **8 KO**
(VC030203–213). Four animals have no window (VC030103, VC030104, VC030201, VC030202)
and drop out. A session counts only if it is inside the window, not opto, side-assist
off, and `leftStimProb` ∉ {0, 1}.

> The old `Fig1\LearningBehavStats.txt` (WT mean 32.7 / KO 33.6) predates an edit to
> `SessionInfo.xlsx` made **the day after** those stats were saved (Oct 2025). The
> current code on the current data — `.mat` pipeline **and** NWB port alike — gives
> WT 28.7 / KO 30.0. The code never changed; the training windows did.

**Expert cohort.** The same **10 WT + 8 KO**. The four pilot animals
(VC030103/104/201/202) are excluded by ID in `fig1_behav_nwb`
(`EXCLUDE_ANIMALS`); their `se`/NWB may or may not be in the folders, but the ports
never let them into the analysis. Only bodyside6 sessions are used; opto trials are
dropped; left/right panels use the cue trial types (`Stim_Som_Left/Right`), with the
`_NoCue` types as a per-session fallback; the *overall* panel includes NoCue trials.

**Two expert sessions needed attention:**
- `VC030115 2023-12-21` — no `SessInfoNoOpto` row at all → its `se.sessionInfo` is
  empty → the ports drop it (they skip any session with an empty `seshDate`). Correct
  to exclude.
- `VC030213 2023-12-18` — the `SessInfoNoOpto` row had a **date typo** (`241218`
  instead of `231218`), so at `se`-build time it failed to match and its
  `sessionInfo` came out empty. Fixing the CSV alone is **not** enough: the `se`
  stores its own `sessionInfo`, so the fix must be rebuilt into the `se` (repopulate
  `se.userData.sessionInfo` from the corrected CSV — seshDate 2023-12-18, trialMap
  `50:350'`), then re-dump + re-convert. Once that's done the session is included.

**trialMap format.** `sessionInfo.trialMap` selects which trials to keep, as
colon-separated `start:stop` pairs; `end` means the last trial, a trailing `'` is
ignored. Multiple pairs = multiple ranges kept (a union): `"50:350'"` → keep 50–350;
`"1:end'"` → keep all; `"1:240:260:end'"` → keep 1–240 **and** 260–end. (The original
`fig1_behav.m` parser mis-read that last form as `1:24`; the NWB ports read it as the
two intended ranges, so their VC030204 numbers — and thus the KO aggregate — differ
slightly from the published figure. WT is unaffected. To keep the `.mat` pipeline
consistent, fix its trialMap parser too, or just use the NWB port going forward.)

---

## What's in each NWB file

- **Session**: description, start time (US/Eastern; nominal for behavior-only), lab,
  institution, experimenter, task description.
- **Subject**: `subject_id`, `species`, `sex`, `genotype` (WT/KO), `date_of_birth`
  when available. Genotype comes from `behavValue.Genotype` when present, else the
  ID convention `VC0301x = WT`, `VC0302x = KO`.
- **Trials** (`nwb.trials`): one row per Bcontrol trial — `trialType`, `response`
  (0 miss / 1 lickR / 2 lickL / 3 abort), `result` (1 correct / 0 incorrect / NaN
  miss), `leftStimType`, `rightStimType`, `blockType`, `bct_trialNum`, `inhSite`,
  `Genotype`, `isInhibition` (whichever are present). Trials are stored in original
  order and untrimmed, so `trialMap` indices apply directly.
- **`processing['metadata']['session_info']`** (one-row table): `seshType`/`taskName`,
  `trialMap`, `seshDate`, `recSite`, `inhSite`, `Manipulation`, `probeNames`,
  `Injection`, plus the Bcontrol task params the learning plot filters on
  (`sideAssist`, `leftTrialProb`, `maskingFlash`, `preStimNoLickTime`).

Behavior-only sessions have no acquisition clock, so NWB trial `start_time`/`stop_time`
are the trial index in seconds. The figures use only counts/fractions, not times.

Read one back:
```python
from pynwb import NWBHDF5IO
with NWBHDF5IO("VC030109_2023-01-05_a.nwb", "r") as io:
    df = io.read().trials.to_dataframe()
```
