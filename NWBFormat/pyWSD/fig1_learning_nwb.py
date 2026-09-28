"""
fig1_learning_nwb.py
====================
Reproduce the Fig1 LEARNING plot (number of training sessions per mouse, WT vs KO)
from the behavior *learning* NWB files — the NWB port of the learning section of
Fig1_BS_Behav.m.

Logic (mirrors Fig1_BS_Behav.m):
  * read each session's animal, genotype, date, taskName, sideAssist, leftStimProb,
    and whether it had opto trials, from the NWB;
  * an animal's training window comes from LearningSessInfo\\SessionInfo.xlsx
    (Training start date .. End date, yymmdd). Animals not listed there are dropped
    (so VC030103/104/201/202 fall out, leaving 10 WT + 8 KO);
  * keep a session iff: within the training window, NOT an opto session, side-assist
    OFF, and leftStimProb is neither 0 nor 1;
  * count kept sessions per mouse; plot mean +/- SEM for WT vs KO; Welch t-test + rank-sum.

isOpto matches getPerfOverall: a session counts as opto only when taskName == 'bodyside6'
AND at least one trial's trialType contains 'Opto'. (Non-bodyside6 sessions are kept.)

Usage
-----
    python fig1_learning_nwb.py \
        --nwb-dir   "...\\NWBData\\Data\\behavior\\learning" \
        --sessinfo  "...\\SeData\\VC0301\\LearningSessInfo\\SessionInfo.xlsx" \
        --out-dir   "...\\Fig1"

Deps: pynwb, pandas, numpy, scipy, matplotlib, openpyxl
"""
from __future__ import annotations

import argparse
import re
from datetime import datetime
from pathlib import Path

import numpy as np


# --------------------------------------------------------------------------- #
#  Training windows from SessionInfo.xlsx
# --------------------------------------------------------------------------- #
def normColName(name):
    """Normalise a column name for loose matching (drop whitespace, lower-case)."""
    return re.sub(r"\s+", "", str(name)).lower()


def parseYymmdd(value):
    """Parse a yymmdd value (int/float/str) to a date; None if blank/invalid."""
    if value is None:
        return None
    text = str(value).strip()
    if not text or text.lower() == "nan":
        return None
    text = text.split(".")[0]        # drop any '.0' from a float
    text = re.sub(r"\D", "", text)   # keep digits only
    if len(text) < 5:
        return None
    text = text.zfill(6)[:6]
    try:
        return datetime.strptime(text, "%y%m%d").date()
    except ValueError:
        return None


def loadTrainingWindows(xlsxPath):
    """Return {ANIMAL_ID: (startDate, endDate)} from SessionInfo.xlsx.
    Column names are matched loosely (they contain spaces / newlines)."""
    import pandas as pd

    sessInfoTable = pd.read_excel(xlsxPath)
    colByNorm = {normColName(c): c for c in sessInfoTable.columns}

    def findColumn(*candidates):
        # Exact normalised match first, then a substring match.
        for candidate in candidates:
            if candidate in colByNorm:
                return colByNorm[candidate]
        for normalised, original in colByNorm.items():
            if any(candidate in normalised for candidate in candidates):
                return original
        return None

    animalCol = findColumn("animalid")
    startCol = findColumn("trainingstartdate", "trainingstart")
    endCol = findColumn("enddate")
    if not (animalCol and startCol and endCol):
        raise ValueError(f"Could not find Animal ID / Training start / End date "
                         f"columns in {xlsxPath}; found {list(sessInfoTable.columns)}")

    # One (start, end) window per listed animal.
    trainingWindows = {}
    for _, row in sessInfoTable.iterrows():
        animalId = str(row[animalCol]).strip().upper()
        if not animalId or animalId.lower() == "nan":
            continue
        trainingWindows[animalId] = (parseYymmdd(row[startCol]), parseYymmdd(row[endCol]))
    return trainingWindows


# --------------------------------------------------------------------------- #
#  Per-session record from one NWB
# --------------------------------------------------------------------------- #
def readSessionInfo(nwb):
    """Return the one-row session_info as a plain dict (or {})."""
    if "metadata" not in nwb.processing:
        return {}
    if "session_info" not in nwb.processing["metadata"].data_interfaces:
        return {}
    infoTable = nwb.processing["metadata"]["session_info"]
    sessInfo = {}
    for columnName in infoTable.colnames:
        try:
            sessInfo[columnName] = infoTable[columnName].data[0]
        except Exception:
            pass
    return sessInfo


def toText(value):
    """Decode NWB byte strings and normalise None to ''."""
    if isinstance(value, bytes):
        return value.decode("utf-8", "replace")
    if value is None:
        return ""
    return str(value)


def readSessionRecord(nwbPath):
    """Read the fields the learning filter needs out of one NWB file."""
    from pynwb import NWBHDF5IO

    with NWBHDF5IO(str(nwbPath), "r") as io:
        nwb = io.read()
        animal = toText(nwb.subject.subject_id).upper()
        genotype = toText(nwb.subject.genotype).upper()
        sessionDate = nwb.session_start_time.date()
        sessInfo = readSessionInfo(nwb)
        taskName = toText(sessInfo.get("taskName")) or toText(sessInfo.get("seshType"))
        sideAssist = toText(sessInfo.get("sideAssist", "0")).strip() in ("1", "1.0", "true", "True")
        try:
            leftProb = float(toText(sessInfo.get("leftTrialProb", "0.5")))
        except ValueError:
            leftProb = 0.5
        # opto flag: any trial's trialType contains 'Opto'.
        hasOpto = False
        try:
            trialType = nwb.trials["trialType"].data[:]
            hasOpto = any("Opto" in toText(x) for x in trialType)
        except Exception:
            pass
    # A session is only "opto" for bodyside6 (matches getPerfOverall).
    isOpto = (taskName == "bodyside6") and hasOpto
    return dict(animal=animal, genotype=genotype, date=sessionDate, task=taskName,
                sideAssist=sideAssist, leftProb=leftProb, isOpto=isOpto)


# --------------------------------------------------------------------------- #
#  Collect + filter
# --------------------------------------------------------------------------- #
def collectRecords(nwbDir, trainingWindows, verbose=True):
    """Read every NWB in nwbDir and tag each with the keep/drop decision."""
    nwbFiles = sorted(Path(nwbDir).glob("*.nwb"))
    records = []
    for nwbFile in nwbFiles:
        try:
            record = readSessionRecord(nwbFile)
        except Exception as err:
            print(f"  ERROR reading {nwbFile.name}: {type(err).__name__}: {err}")
            continue
        # Is the session date inside this animal's training window?
        window = trainingWindows.get(record["animal"])
        inWindow = False
        if window and window[0] and window[1]:
            inWindow = window[0] <= record["date"] <= window[1]
        record["in_window"] = inWindow
        record["has_window"] = window is not None
        # Keep iff listed, in-window, not opto, side-assist off, leftProb not 0 or 1.
        record["keep"] = (record["has_window"] and inWindow and (not record["isOpto"])
                          and (not record["sideAssist"]) and record["leftProb"] not in (0.0, 1.0))
        records.append(record)
    if verbose:
        print(f"read {len(records)} NWB files; {sum(x['keep'] for x in records)} pass all filters")
    return records


def isWildType(animal):
    """WT vs KO from the ID convention: the 6th character is '1' for WT."""
    return len(animal) >= 6 and animal[5] == "1"


def countPerMouse(records):
    """Per-mouse kept-session counts, split into WT and KO arrays."""
    keptRecords = [r for r in records if r["keep"]]
    animalIds = sorted({r["animal"] for r in keptRecords})
    sessionCounts = {animal: sum(1 for r in keptRecords if r["animal"] == animal) for animal in animalIds}
    wtCounts = np.array([sessionCounts[a] for a in animalIds if isWildType(a)], dtype=float)
    koCounts = np.array([sessionCounts[a] for a in animalIds if not isWildType(a)], dtype=float)
    return sessionCounts, wtCounts, koCounts


# --------------------------------------------------------------------------- #
#  Plot
# --------------------------------------------------------------------------- #
def plotLearning(wtCounts, koCounts, outDir, save=True):
    """Plot WT-vs-KO mean +/- SEM sessions-to-expert and write the stats file."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from scipy import stats

    outDir = Path(outDir)
    outDir.mkdir(parents=True, exist_ok=True)

    def sem(counts):
        # Standard error of the mean (sample SD / sqrt(n)); 0 for a single mouse.
        if len(counts) > 1:
            return np.std(counts, ddof=1) / np.sqrt(len(counts))
        return 0.0

    # Two mean +/- SEM markers (WT grey, KO black), 33 x 38 mm axes.
    fig, ax = plt.subplots(figsize=(3.3 / 2.54, 3.8 / 2.54))
    ax.errorbar(1, np.mean(wtCounts), sem(wtCounts), fmt=".", markersize=20,
                color=[0.5, 0.5, 0.5], capsize=0, linewidth=2)
    ax.errorbar(2, np.mean(koCounts), sem(koCounts), fmt=".", markersize=20,
                color=[0, 0, 0], capsize=0, linewidth=2)
    ax.set_xlim(0, 3)
    ax.set_xticks([1, 2])
    ax.set_xticklabels(["WT", "KO"])
    ax.set_ylabel("Number of sessions", fontname="Arial", fontsize=8)
    ax.set_ylim(0, 40)
    ax.tick_params(labelsize=8)
    for tickLabel in ax.get_xticklabels() + ax.get_yticklabels():
        tickLabel.set_fontname("Arial")

    # Stats: Welch t-test (MATLAB ttest2 'unequal') and rank-sum (Mann-Whitney U).
    tTest = stats.ttest_ind(wtCounts, koCounts, equal_var=False)
    try:
        rankSum = stats.mannwhitneyu(wtCounts, koCounts, alternative="two-sided")
        rankSumP = rankSum.pvalue
    except ValueError:
        rankSumP = float("nan")

    if save:
        fig.savefig(outDir / "FigS1D - Learning rate.pdf", dpi=300, bbox_inches="tight")
        fig.savefig(outDir / "FigS1D - Learning rate.png", dpi=300, bbox_inches="tight")
        with open(outDir / "FigS1D - Learning rate stats.txt", "w") as statsFile:
            statsFile.write(f"WT n={len(wtCounts)} sessions per mouse: {wtCounts.tolist()}\n")
            statsFile.write(f"KO n={len(koCounts)} sessions per mouse: {koCounts.tolist()}\n")
            statsFile.write(f"WT mean={np.mean(wtCounts):.4g} SEM={sem(wtCounts):.4g}\n")
            statsFile.write(f"KO mean={np.mean(koCounts):.4g} SEM={sem(koCounts):.4g}\n")
            statsFile.write(f"Welch t-test (ttest2 'unequal'): t={tTest.statistic:.4g}, p={tTest.pvalue:.4g}\n")
            statsFile.write(f"Rank-sum (Mann-Whitney U): p={rankSumP:.4g}\n")
    plt.close(fig)
    return dict(wt_mean=float(np.mean(wtCounts)), ko_mean=float(np.mean(koCounts)),
                wt_n=len(wtCounts), ko_n=len(koCounts),
                ttest_p=float(tTest.pvalue), ranksum_p=float(rankSumP))


# --------------------------------------------------------------------------- #
def main(argv=None):
    parser = argparse.ArgumentParser(description="Fig1 learning plot from NWB")
    parser.add_argument("--nwb-dir", required=True, help="folder of behavior learning .nwb files")
    parser.add_argument("--sessinfo", required=True, help="LearningSessInfo SessionInfo.xlsx")
    parser.add_argument("--out-dir", required=True, help="output folder (e.g. ...\\Fig1)")
    args = parser.parse_args(argv)

    # Load windows, read + filter sessions, count per mouse, then plot + write stats.
    trainingWindows = loadTrainingWindows(args.sessinfo)
    print(f"training windows for {len(trainingWindows)} animals")
    records = collectRecords(args.nwb_dir, trainingWindows)
    sessionCounts, wtCounts, koCounts = countPerMouse(records)
    print(f"WT mice (n={len(wtCounts)}): counts={wtCounts.tolist()}")
    print(f"KO mice (n={len(koCounts)}): counts={koCounts.tolist()}")
    summary = plotLearning(wtCounts, koCounts, args.out_dir)
    print("summary:", summary)
    print(f"wrote FigS1D - Learning rate .pdf / .png / stats.txt to {args.out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
