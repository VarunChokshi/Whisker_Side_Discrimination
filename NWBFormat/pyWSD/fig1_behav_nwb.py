"""
fig1_behav_nwb.py
=================
NWB port of fig1_behav.m -- the EXPERT (NoOptoSess) behavioral-performance panels
for Figure 1 / Figure S1: correct fraction, miss fraction, and stimulus amplitude,
WT vs KO, per mouse, for overall / left-stim / right-stim trials.

Pipeline mirrored from fig1_behav.m:
  * read each expert session's trials + session_info from NWB;
  * apply the session's trialMap (e.g. "50:350'" -> keep trials 50..350; "1:end'"
    -> keep from 1 to the last trial) BEFORE any other processing;
  * drop aborted trials (response == 3); keep only bodyside6 sessions;
  * per mouse, pool trials across sessions for the DIRECT means (the plotted points
    and the values written to Fig1D - behavior mean values.txt), and run a multilevel bootstrap
    (resample sessions -> resample trials, nboot=1000) for the error-bar CIs and the
    stimulus-amplitude point.

Metrics (result: 1=correct, 0=incorrect, NaN=miss/no-lick):
  * correct fraction  = mean(result) over non-miss trials
  * miss fraction     = n_miss / n_total
  * amplitude (% max) = mean stimulus amplitude parsed from left/rightStimType, /10

Determinism note: correct- and miss-fraction means/SDs and the Mann-Whitney p-values
are DIRECT per-mouse means -> reproduced exactly (matches the MATLAB .m and the MATLAB
NWB port). The amplitude point and all error bars come from the bootstrap; with NumPy's
RNG they differ slightly from MATLAB's rng(7) run (the MATLAB port reproduces those
exactly). Seeded here (np.random.default_rng(7)) for run-to-run reproducibility.

Usage
-----
    python fig1_behav_nwb.py \
        --nwb-dir "...\\NWBData\\Data\\behavior\\expert" \
        --out-dir "...\\NWBData\\Figures\\Fig1_python"

Deps: pynwb, pandas, numpy, scipy, matplotlib
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

import numpy as np

# Trial-type names for the no-opto expert set: index 0 = Left, 1 = Right. The cue
# types are used first; the NoCue types are a per-session fallback (see sideMask).
TRIAL_TYPES_LEFT_RIGHT = ["Stim_Som_Left", "Stim_Som_Right"]
TRIAL_TYPES_LEFT_RIGHT_NOCUE = ["Stim_Som_Left_NoCue", "Stim_Som_Right_NoCue"]

# Number of bootstrap resamples per mouse (matches nboot in fig1_behav.m).
NBOOT = 1000

# How many mice each panel plots, hard-coded in fig1_behav.m (in sorted-ID order):
# the correct/miss panels use all 10 WT + 8 KO; the amplitude panels drop the last
# mouse of each genotype (9 WT + 7 KO).
MICE_PER_PANEL_CORRECT = {"WT": 10, "KO": 8}
MICE_PER_PANEL_AMP = {"WT": 9, "KO": 7}

# Pilot animals excluded from the manuscript expert cohort (the same four dropped
# from the learning analysis for lacking a training window). fig1_behav.m excludes
# them upstream via the session-selection dialog; we exclude them by ID so the cohort
# matches (10 WT + 8 KO). Pass --include-all to keep every animal.
EXCLUDE_ANIMALS = {"VC030103", "VC030104", "VC030201", "VC030202"}


def sideMask(trialType, side):
    """Boolean mask for one side's trials, mirroring fig1_behav.m: use the cue type
    (Stim_Som_Left/Right); fall back to the NoCue type only if there are no cue
    trials in this set of trial-type labels."""
    isCue = (trialType == TRIAL_TYPES_LEFT_RIGHT[side])
    if isCue.any():
        return isCue
    return (trialType == TRIAL_TYPES_LEFT_RIGHT_NOCUE[side])


# --------------------------------------------------------------------------- #
#  small helpers
# --------------------------------------------------------------------------- #
def toText(value):
    """Decode NWB byte strings and normalise None to '' so string ops never fail."""
    if isinstance(value, bytes):
        return value.decode("utf-8", "replace")
    if value is None:
        return ""
    return str(value)


def firstNumber(text, default=0.0):
    """Return the first signed number found in a string, or the default if none."""
    match = re.search(r"-?\d+(?:\.\d+)?", str(text))
    if match:
        return float(match.group())
    return default


def bodyside6Amp(stim):
    """Amplitude from a bodyside6 stim string (mirrors bodyside6Stims in fig1_behav.m):
    the 3 characters after the 'm' marker give the amplitude, and 0 codes for 1000."""
    stimStr = toText(stim)
    mInd = stimStr.find("m")
    if mInd < 0:
        return np.nan
    # MATLAB reads stim(mpos+4:mpos+6) (1-based) -> Python slice [mInd+4:mInd+7].
    amp = firstNumber(stimStr[mInd + 4: mInd + 7], default=0.0)
    if amp == 0:
        amp = 1000.0
    return amp


def bodyside5Amp(stim):
    """Amplitude for a bodyside5 (Cyc) stim string (used only when 'Cyc' is present)."""
    stimStr = toText(stim)
    mInd = stimStr.find("m")
    if mInd < 0:
        return np.nan
    amp = firstNumber(stimStr[mInd + 4: mInd + 7], default=0.0)
    if amp == 0:
        amp = 1000.0
    return amp


def stimAmp(stim):
    """Pick the bodyside5 vs bodyside6 amplitude parser the same way fig1_behav.m does
    (bodyside5 only when the stim string is a 'Cyc' waveform)."""
    stimStr = toText(stim)
    if stimStr.count("Cyc") > 2:
        return bodyside5Amp(stimStr)
    return bodyside6Amp(stimStr)


def parseTrialMap(trialMap, nTotal):
    """Parse a trialMap string to a list of (start, stop) 1-based inclusive ranges,
    or None to keep all trials. Colon-separated values are read as consecutive
    start:stop pairs, so a multi-range map like "1:240:260:end'" keeps trials 1-240
    AND 260-end (a single "50:350'" -> [(50,350)]; "1:end'" -> [(1,n)]). 'end' (with
    any trailing quote stripped) means the last trial."""
    text = toText(trialMap).strip()
    if not text or text.lower() == "nan" or ":" not in text:
        return None
    # Split into colon-separated tokens and strip whitespace / trailing quotes.
    parts = [part.strip().rstrip("'").strip() for part in text.split(":")]
    ranges = []
    # Walk the tokens two at a time as (start, stop) pairs.
    for pairInd in range(0, len(parts) - 1, 2):
        startDigits = re.sub(r"\D", "", parts[pairInd])
        startTrial = int(startDigits) if startDigits else 1
        stopToken = parts[pairInd + 1]
        if stopToken.lower() == "end" or stopToken == "":
            stopTrial = nTotal
        else:
            stopDigits = re.sub(r"\D", "", stopToken)
            stopTrial = int(stopDigits) if stopDigits else nTotal
        ranges.append((max(1, startTrial), min(stopTrial, nTotal)))
    return ranges or None


# --------------------------------------------------------------------------- #
#  read one expert NWB session -> arrays
# --------------------------------------------------------------------------- #
def readSessionInfo(nwb):
    """Return the one-row session_info table as a {column: value} dict, or {} if the
    file has no metadata/session_info table."""
    if "metadata" not in nwb.processing:
        return {}
    if "session_info" not in nwb.processing["metadata"].data_interfaces:
        return {}
    infoTable = nwb.processing["metadata"]["session_info"]
    sessInfo = {}
    for column in infoTable.colnames:
        try:
            sessInfo[column] = infoTable[column].data[0]
        except Exception:
            pass
    return sessInfo


def readExpertSession(nwbPath):
    """Read one expert NWB file and return a dict of the trimmed per-trial arrays
    (after trialMap, abort-removal and opto-removal) plus session metadata."""
    from pynwb import NWBHDF5IO

    # Read subject, trials table and session_info out of the NWB file.
    with NWBHDF5IO(str(nwbPath), "r") as io:
        nwb = io.read()
        animal = toText(nwb.subject.subject_id).upper()
        genotype = toText(nwb.subject.genotype).upper()
        trialsDf = nwb.trials.to_dataframe()
        sessInfo = readSessionInfo(nwb)

    # Pull the metadata fields the analysis filters on.
    task = toText(sessInfo.get("taskName")) or toText(sessInfo.get("seshType"))
    trialMap = toText(sessInfo.get("trialMap"))
    inhSite = toText(sessInfo.get("inhSite"))
    seshDate = toText(sessInfo.get("seshDate")).strip()   # empty => the se's CSV date-match failed

    # Convert the trials-table columns into typed NumPy arrays.
    nTotal = len(trialsDf)
    trialType = np.array([toText(x) for x in trialsDf["trialType"].to_numpy()], dtype=object)
    result = np.array([float(x) if x is not None and str(x) != "" else np.nan
                       for x in trialsDf["result"].to_numpy()], dtype=float)
    response = np.array([firstNumber(x, default=np.nan) for x in trialsDf["response"].to_numpy()], dtype=float)
    leftStimType = np.array([toText(x) for x in trialsDf["leftStimType"].to_numpy()], dtype=object)
    rightStimType = np.array([toText(x) for x in trialsDf["rightStimType"].to_numpy()], dtype=object)

    # Apply trialMap on the FULL (original) trial ordering, keeping the union of ranges.
    ranges = parseTrialMap(trialMap, nTotal)
    if ranges is not None:
        keepMask = np.zeros(nTotal, dtype=bool)
        for startTrial, stopTrial in ranges:
            if stopTrial >= startTrial:
                keepMask[startTrial - 1:stopTrial] = True
        trialType = trialType[keepMask]
        result = result[keepMask]
        response = response[keepMask]
        leftStimType = leftStimType[keepMask]
        rightStimType = rightStimType[keepMask]

    # Drop aborted trials (response == 3).
    notAbort = response != 3
    trialType = trialType[notAbort]
    result = result[notAbort]
    leftStimType = leftStimType[notAbort]
    rightStimType = rightStimType[notAbort]

    # Drop opto trials (fig1_behav.m removes any trialType containing 'Opto').
    notOpto = np.array(["Opto" not in toText(t) for t in trialType], dtype=bool)
    trialType = trialType[notOpto]
    result = result[notOpto]
    leftStimType = leftStimType[notOpto]
    rightStimType = rightStimType[notOpto]

    # Per-trial stimulus amplitude for each side (used only on that side's trials).
    ampLeft = np.array([stimAmp(s) for s in leftStimType], dtype=float)
    ampRight = np.array([stimAmp(s) for s in rightStimType], dtype=float)

    return dict(animal=animal, genotype=genotype, task=task, inhSite=inhSite,
                seshDate=seshDate, nTotal=nTotal, result=result, trialType=trialType,
                ampLeft=ampLeft, ampRight=ampRight)


# --------------------------------------------------------------------------- #
#  load + group by mouse (bodyside6 only)
# --------------------------------------------------------------------------- #
def loadSessions(nwbDir, verbose=True, includeAll=False):
    """Read every *.nwb in nwbDir, keep the bodyside6 expert sessions that pass the
    cohort filters, and group them into {animal: [session, ...]}."""
    sessFiles = sorted(Path(nwbDir).glob("*.nwb"))
    sessionsByMouse = {}
    genotypeByMouse = {}
    nKept = 0
    for nwbFile in sessFiles:
        try:
            session = readExpertSession(nwbFile)
        except Exception as err:
            print(f"  ERROR reading {nwbFile.name}: {type(err).__name__}: {err}")
            continue
        # Keep only bodyside6 sessions that still have trials.
        if session["task"] != "bodyside6":
            continue
        if len(session["result"]) == 0:
            continue
        # Drop sessions whose SessInfoNoOpto row failed to date-match (empty seshDate);
        # fig1_behav.m drops those the same way.
        if not session["seshDate"]:
            continue
        # Drop the pilot cohort unless includeAll was requested.
        if not includeAll and session["animal"] in EXCLUDE_ANIMALS:
            continue
        sessionsByMouse.setdefault(session["animal"], []).append(session)
        genotypeByMouse[session["animal"]] = session["genotype"]
        nKept += 1
    if verbose:
        excludedNote = "" if includeAll else f" (excluded pilot cohort {sorted(EXCLUDE_ANIMALS)})"
        print(f"loaded {nKept} bodyside6 expert sessions across {len(sessionsByMouse)} mice" + excludedNote)
    return sessionsByMouse, genotypeByMouse


# --------------------------------------------------------------------------- #
#  direct pooled metrics + bootstrap CIs
# --------------------------------------------------------------------------- #
def fracCorrect(result):
    """Correct fraction = mean over non-miss trials (NaN if there are none)."""
    notMiss = ~np.isnan(result)
    if notMiss.any():
        return float(np.mean(result[notMiss]))
    return np.nan


def fracMiss(result):
    """Miss fraction = fraction of trials with a NaN result (NaN if empty)."""
    if len(result):
        return float(np.mean(np.isnan(result)))
    return np.nan


def directMetrics(sessions):
    """Pooled-across-sessions per-mouse direct means (the plotted points / txt values).
    Overall uses all (non-opto) trials; left/right use the cue type (NoCue fallback),
    decided at the mouse level over the pooled trials -- mirrors fig1_behav.m."""
    result = np.concatenate([s["result"] for s in sessions])
    trialType = np.concatenate([s["trialType"] for s in sessions])
    isLeft = sideMask(trialType, 0)
    isRight = sideMask(trialType, 1)
    # Order within each triple is [overall, left, right].
    correct = [fracCorrect(result), fracCorrect(result[isLeft]), fracCorrect(result[isRight])]
    miss = [fracMiss(result), fracMiss(result[isLeft]), fracMiss(result[isRight])]
    return correct, miss


def bootstrapMouse(sessions, rng, nboot=NBOOT):
    """Multilevel bootstrap (resample sessions, then trials within each). Returns a
    dict mapping each field to its (nboot,) array of per-resample means, for
    overall/left/right performance & miss and left/right amplitude."""
    nSessions = len(sessions)
    fields = ["overallPerf", "overallMiss", "leftPerf", "rightPerf",
              "leftMiss", "rightMiss", "leftAmp", "rightAmp"]
    bootSamples = {field: np.full(nboot, np.nan) for field in fields}

    for bootNum in range(nboot):
        # Resample sessions with replacement, then trials within each drawn session.
        randSessions = rng.integers(0, nSessions, nSessions)
        sessionVals = {field: [] for field in fields}
        for sessIdx in randSessions:
            session = sessions[sessIdx]
            nTrials = len(session["result"])
            randTrials = rng.integers(0, nTrials, nTrials)
            result = session["result"][randTrials]
            trialType = session["trialType"][randTrials]
            ampLeft = session["ampLeft"][randTrials]
            ampRight = session["ampRight"][randTrials]
            # Overall performance / miss across all resampled trials in this session.
            sessionVals["overallPerf"].append(fracCorrect(result))
            sessionVals["overallMiss"].append(fracMiss(result))
            # Per-side performance / miss / amplitude on that side's trials.
            for side, sideIdx, ampSide in (("left", 0, ampLeft), ("right", 1, ampRight)):
                sideTrials = sideMask(trialType, sideIdx)
                sideResult = result[sideTrials]
                sessionVals[f"{side}Perf"].append(fracCorrect(sideResult))
                sessionVals[f"{side}Miss"].append(fracMiss(sideResult))
                ampTrials = sideTrials & ~np.isnan(result)
                sessionVals[f"{side}Amp"].append(float(np.mean(ampSide[ampTrials])) if ampTrials.any() else np.nan)
        # Average across the resampled sessions to get this resample's per-field value.
        for field in fields:
            bootSamples[field][bootNum] = np.nanmean(sessionVals[field]) if len(sessionVals[field]) else np.nan
    return bootSamples


def ciFromBoot(samples):
    """(mean, lo2.5, hi97.5) percentile CI, mirroring the sort/round in fig1_behav.m."""
    samples = np.asarray(samples, dtype=float)
    sortedSamples = np.sort(samples)
    lo = sortedSamples[int(round(NBOOT * 0.025))]
    hi = sortedSamples[int(round(NBOOT * 0.975))]
    return float(np.mean(samples)), float(lo), float(hi)


# --------------------------------------------------------------------------- #
#  build per-genotype results
# --------------------------------------------------------------------------- #
def buildResults(sessionsByMouse, genotypeByMouse, seed=7):
    """For each mouse (sorted by ID) compute the direct means and the bootstrap CIs /
    amplitude point. One RNG is seeded once and shared across mice, matching the
    original single-stream bootstrap."""
    rng = np.random.default_rng(seed)
    animals = sorted(sessionsByMouse.keys())
    results = {}
    for animal in animals:
        sessions = sessionsByMouse[animal]
        correct, miss = directMetrics(sessions)
        bootSamples = bootstrapMouse(sessions, rng)
        results[animal] = dict(
            genotype=genotypeByMouse[animal],
            correct=correct,
            miss=miss,
            amp=[float(np.mean(bootSamples["leftAmp"])), float(np.mean(bootSamples["rightAmp"]))],
            ciCorrect=[ciFromBoot(bootSamples["overallPerf"]),
                       ciFromBoot(bootSamples["leftPerf"]),
                       ciFromBoot(bootSamples["rightPerf"])],
            ciMiss=[ciFromBoot(bootSamples["overallMiss"]),
                    ciFromBoot(bootSamples["leftMiss"]),
                    ciFromBoot(bootSamples["rightMiss"])],
        )
    return results, animals


def miceOfGenotype(animals, results, genotype):
    """Animals of one genotype, preserving the sorted-ID order of `animals`."""
    return [animal for animal in animals if results[animal]["genotype"] == genotype]


# --------------------------------------------------------------------------- #
#  plotting + stats file
# --------------------------------------------------------------------------- #
def makeFigures(results, animals, outDir):
    """Write the 8 panels (correct/miss x overall/left/right, amplitude left/right)
    and the Fig1D - behavior mean values.txt stats file."""
    import matplotlib
    matplotlib.use("Agg")
    import matplotlib.pyplot as plt
    from scipy import stats

    outDir = Path(outDir)
    outDir.mkdir(parents=True, exist_ok=True)
    statsFile = open(outDir / "Fig1D - behavior mean values.txt", "w")

    # Split the animals into the two genotype groups (keeping sorted-ID order).
    wtMice = miceOfGenotype(animals, results, "WT")
    koMice = miceOfGenotype(animals, results, "KO")
    miceByGenotype = {"WT": wtMice, "KO": koMice}
    genotypeColors = {"WT": [0.5, 0.5, 0.5], "KO": [0, 0, 0]}
    START_X, STEP = 20, 15

    def panel(plotKind, field, fileName, yLabel, yLimits, yLine=None):
        """Draw one panel matching fig1_behav.m: 3.3 x 3.8 cm, exact colors
        (gray/black for overall, red/blue for left/right stim), alpha=0.8,
        and genotype mean +/- SD summary marker."""
        fig, ax = plt.subplots(figsize=(3.3 / 2.54, 3.8 / 2.54))
        animalValsByGenotype = {}
        for genotypeInd, genotype in enumerate(("WT", "KO")):
            # Select this genotype's mice for this panel (amplitude uses fewer mice).
            micePerPanel = (MICE_PER_PANEL_AMP if plotKind == "amp" else MICE_PER_PANEL_CORRECT)[genotype]
            selMice = miceByGenotype[genotype][:micePerPanel]
            xPositions = (START_X + genotypeInd * 250) + STEP * np.arange(1, len(selMice) + 1)
            
            # Determine color and alpha matching fig1_behav.m
            if plotKind == "amp":
                alphaVal = 1.0
                plotColor = [1.0, 0.0, 0.0] if field == 0 else [0.0, 0.0, 1.0]
            else:
                alphaVal = 0.8
                if field == 0:
                    plotColor = [0.5, 0.5, 0.5] if genotype == "WT" else [0.0, 0.0, 0.0]
                elif field == 1:
                    plotColor = [1.0, 0.0, 0.0]
                else:
                    plotColor = [0.0, 0.0, 1.0]

            if plotKind == "amp":
                # Amplitude: plot the bootstrap-mean amplitude (as % of max) per mouse.
                animalVals = np.array([results[a]["amp"][field] / 10.0 for a in selMice])
                ax.scatter(xPositions, animalVals, s=10, facecolors="none",
                           edgecolors=plotColor, linewidths=1, alpha=alphaVal)
            else:
                # Correct/miss: plot the direct mean with the bootstrap CI as error bars.
                metricKey = plotKind
                ciKey = "ciCorrect" if plotKind == "correct" else "ciMiss"
                ci = np.array([results[a][ciKey][field] for a in selMice])   # (n,3): mean, lo, hi
                animalVals = np.array([results[a][metricKey][field] for a in selMice])
                ax.errorbar(xPositions, ci[:, 0], yerr=[ci[:, 0] - ci[:, 1], ci[:, 2] - ci[:, 0]],
                            fmt="none", ecolor=plotColor, linewidth=1, capsize=0, alpha=alphaVal)
                ax.scatter(xPositions, animalVals, s=10, facecolors="none",
                           edgecolors=plotColor, linewidths=1, alpha=alphaVal)

            # Genotype mean +/- SD marker just to the right of the cluster.
            markerColor = [0.5, 0, 0.5] if (plotKind != "amp" and field == 0) else [0, 0, 0]
            ax.errorbar(xPositions[-1] + 25, np.mean(animalVals), np.std(animalVals, ddof=1),
                        fmt=".", markersize=12, color=markerColor, linewidth=1, capsize=0)
            animalValsByGenotype[genotype] = animalVals
            # Record this genotype's mean / SD in the stats file.
            statsFile.write(f"For genotype: {genotype} {panelSubtypeLabel(plotKind, field)} "
                            f"Mean: {fmtSig5(np.mean(animalVals))} SD: {fmtSig5(np.std(animalVals, ddof=1))}\n")
        # WT-vs-KO Mann-Whitney U test on the per-mouse values.
        pValue = stats.mannwhitneyu(animalValsByGenotype["WT"], animalValsByGenotype["KO"],
                                    alternative="two-sided").pvalue
        panelLabel = {"correct": "Correct fraction", "miss": "Miss fraction", "amp": "Amplitude"}[plotKind]
        statsFile.write(f"For plotType: {panelLabel} {panelSubtypeLabel(plotKind, field)} "
                        f"Mann Whitney U pval: {fmtSig5(pValue)}\n")

        # Axis cosmetics (limits, reference line, WT/KO ticks, Arial fonts).
        ax.set_ylim(*yLimits)
        if plotKind in ("correct", "miss"):
            ax.set_yticks(np.arange(yLimits[0], yLimits[1] + 0.01, 0.2))
        elif plotKind == "amp":
            ax.set_yticks(np.arange(0, 101, 20))

        if yLine is not None:
            ax.axhline(yLine, ls="--", color=[112 / 255, 41 / 255, 99 / 255], linewidth=1)
        ax.set_ylabel(yLabel, fontsize=8, fontname="Arial")
        allX = np.concatenate([
            (START_X + genotypeInd * 250) + STEP * np.arange(
                1, len(miceByGenotype[genotype][:(MICE_PER_PANEL_AMP if plotKind == "amp"
                                                  else MICE_PER_PANEL_CORRECT)[genotype]]) + 1)
            for genotypeInd, genotype in enumerate(("WT", "KO"))])
        ax.set_xlim(0, allX.max() + 40)
        ax.set_xticks([START_X + 75, START_X + 325])
        ax.set_xticklabels(["WT", "KO"])
        ax.tick_params(labelsize=8, direction="out")
        for tickLabel in ax.get_xticklabels() + ax.get_yticklabels():
            tickLabel.set_fontname("Arial")
        ax.spines[["top", "right"]].set_visible(False)
        fig.savefig(outDir / (fileName + ".pdf"), dpi=300, bbox_inches="tight")
        fig.savefig(outDir / (fileName + ".png"), dpi=300, bbox_inches="tight")
        plt.close(fig)

    # Correct fraction: overall (Fig 1D), left / right (Fig S1B).
    correctNames = ["Fig1D - Fraction correct",
                    "FigS1B - Fraction correct (left)", "FigS1B - Fraction correct (right)"]
    for field in range(3):
        panel("correct", field, correctNames[field], "Correct fraction excl. misses", (0.4, 1.0), yLine=0.7)
    # Miss fraction: overall (Fig 1D), left / right (Fig S1C).
    missNames = ["Fig1D - Fraction miss",
                 "FigS1C - Fraction miss (left)", "FigS1C - Fraction miss (right)"]
    for field in range(3):
        panel("miss", field, missNames[field], "Miss fraction", (0.0, 0.5))
    # Amplitude: left, right (Fig S1A).
    ampNames = ["FigS1A - Mean stimulus amplitude (left)", "FigS1A - Mean stimulus amplitude (right)"]
    for field in range(2):
        panel("amp", field, ampNames[field], "Amplitude (% of maximum)", (0.0, 110.0))

    statsFile.close()


def panelSubtypeLabel(plotKind, field):
    """Label for the panel's subtype, as written into the stats file."""
    if plotKind == "amp":
        return ["Left Stim trials", "Right Stim trials"][field]
    return ["stats_overall", "_left", "_right"][field]


def fmtSig5(value):
    """MATLAB num2str-ish formatting: 5 significant digits."""
    return f"{value:.5g}"


# --------------------------------------------------------------------------- #
def main(argv=None):
    parser = argparse.ArgumentParser(description="Fig1 expert-performance panels from NWB")
    parser.add_argument("--nwb-dir", required=True, help="folder of behavior/expert .nwb files")
    parser.add_argument("--out-dir", required=True, help="output folder")
    parser.add_argument("--include-all", action="store_true",
                        help="keep every animal (default excludes the 4 pilot animals)")
    args = parser.parse_args(argv)

    # Load sessions, compute per-mouse results, then draw the panels + stats file.
    sessionsByMouse, genotypeByMouse = loadSessions(args.nwb_dir, includeAll=args.include_all)
    results, animals = buildResults(sessionsByMouse, genotypeByMouse)
    wtMice = miceOfGenotype(animals, results, "WT")
    koMice = miceOfGenotype(animals, results, "KO")
    print(f"WT mice ({len(wtMice)}): {wtMice}")
    print(f"KO mice ({len(koMice)}): {koMice}")
    makeFigures(results, animals, args.out_dir)
    print(f"wrote 8 panels + Fig1D - behavior mean values.txt to {args.out_dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
