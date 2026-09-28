"""
fig2_optoinhib_nwb.py
=====================
NWB port of Fig2_behav_optoInhibition.m -- the optogenetic S1-inhibition experiment
(Figure 2 + Figure S2). For each mouse and each inhibition site (Left S1 / Right S1),
it measures how silencing S1 during the stimulus changes behavior, expressed as the
opto - non-opto difference (delta) in correct fraction and miss fraction, plus the
raw stimulus amplitude, then refolds Left-S1 / Right-S1 into contralateral / ipsilateral.

Data: the opto behavior NWB files (dumped from finalBehavSEs). Each session carries the
four trial types Stim_Som_Left, Stim_Som_Left_Opto, Stim_Som_Right, Stim_Som_Right_Opto
and a per-trial inhSite ('Left S1' / 'Right S1').

Logic mirrored from Fig2_behav_optoInhibition.m:
  * drop aborted trials (response == 3); keep opto and miss trials; trialMap is NOT
    applied (the original computes it but never uses it);
  * per mouse x inhSite, pool all trials for the DIRECT per-trial-type correct/miss
    fractions (the plotted points), and compute the per-session delta means (used for
    the binomial stats);
  * multilevel bootstrap (resample sessions -> trials, nboot=10000, seed reset per
    mouse) of the delta correct / delta miss and the raw non-opto amplitude, for the
    error-bar CIs and the amplitude points;
  * refold by inhibition site: Right-S1 inhibition -> Left stim is contralateral,
    Right stim ipsilateral; Left-S1 inhibition -> Right contra, Left ipsi.

Outputs (per genotype WT / KO):
  * '<geno> Inihibtion Bootstrapping Correct fraction' (delta correct, contra vs ipsi)
  * '<geno> Inihibtion Bootstrapping Miss fraction'    (delta miss)
  * '<geno> Inihibtion Amplitudes'                     (non-opto amplitude, contra/ipsi)
  * FigS2 raw-performance panels: '<geno> Mean performance' (correct) and Miss
Stats text files:
  * 'Fig2 OptoInhibition Stats delta correct fraction.txt'
  * 'Fig2 OptoInhibition Stats delta miss fraction.txt'
  * 'OptobehavMeanAmplitudedatavalues.txt'
  * 'OptobehavMeanCorerctdatavalues.txt' / 'OptobehavMeanMissdatavalues.txt' (FigS2)

Determinism: the binomial p-values in the delta stats files come from the per-session
delta MEANS (no bootstrap) -> reproduced exactly. The error-bar CIs and amplitude
points come from the bootstrap; with NumPy's RNG they differ slightly from the MATLAB
run (the original used parfor, so its CIs are not bit-reproducible either).

Usage
-----
    python fig2_optoinhib_nwb.py \
        --nwb-dir  "...\\NWBData\\Data\\behavior\\opto" \
        --fig2-dir "...\\Fig2" \
        --figs2-dir "...\\FigS2"

Deps: pynwb, pandas, numpy, scipy, matplotlib
"""
from __future__ import annotations

import argparse
import re
from pathlib import Path

import numpy as np

# The four opto trial types, in the order the analysis indexes them:
# 0 = Left (non-opto), 1 = Left+Opto, 2 = Right (non-opto), 3 = Right+Opto.
TRIAL_TYPES_OPTO = ["Stim_Som_Left", "Stim_Som_Left_Opto", "Stim_Som_Right", "Stim_Som_Right_Opto"]
# Which stim-descriptor column gives the amplitude for each of the four trial types.
STIM_FIELD_FOR_TRIAL_TYPE = ["leftStimType", "leftStimType", "rightStimType", "rightStimType"]

NBOOT = 10000
BOOTSTRAP_SEED = 7   # reset per mouse, matching rng(7) inside the mouse loop of the original

# The two inhibition sites, in the fieldTable row order the original relies on.
INH_SITES = ["Right S1", "Left S1"]
# Genotypes, WT first (matches unique(...,'stable') in the original plotting order).
GENOTYPES = ["WT", "KO"]

# Contra / ipsi stimulus side for each inhibition site (S1 drives the opposite side).
CONTRA_SIDE = {"Right S1": "left", "Left S1": "right"}
IPSI_SIDE = {"Right S1": "right", "Left S1": "left"}

CONTRA_COLOR = [1, 0, 0]   # red
IPSI_COLOR = [0, 0, 1]     # blue
# Marker per inhibition-site source: '.' for Right S1, 'x' for Left S1.
SITE_MARKER = {"Right S1": ".", "Left S1": "x"}


# --------------------------------------------------------------------------- #
#  small helpers
# --------------------------------------------------------------------------- #
def toText(value):
    """Decode NWB byte strings and normalise None to ''."""
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


def stimAmp(stim):
    """Stimulus amplitude from a stim string (mirrors bodyside6Stims/bodyside5Stims):
    the digits after the 'm' marker, with 0 coded as 1000; NaN if there is no marker.
    The bodyside5 vs bodyside6 branch does not change the amplitude, so one parse serves
    both."""
    stimStr = toText(stim)
    mInd = stimStr.find("m")
    if mInd < 0:
        return np.nan
    amp = firstNumber(stimStr[mInd + 4: mInd + 7], default=0.0)
    if amp == 0:
        amp = 1000.0
    return amp


def readSessionInfo(nwb):
    """Return the one-row session_info table as a {column: value} dict, or {}."""
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


def fmtNum(value):
    """MATLAB num2str-like formatting (~5 significant digits) for the stats files.
    A vector (e.g. a [non-opto, opto] mean pair) is rendered space-separated, like
    num2str of a row vector."""
    values = np.atleast_1d(np.asarray(value, dtype=float))
    if values.size == 1:
        return f"{float(values[0]):.5g}"
    return "  ".join(f"{v:.5g}" for v in values)


# --------------------------------------------------------------------------- #
#  read one opto NWB session
# --------------------------------------------------------------------------- #
def readOptoSession(nwbPath):
    """Read one opto NWB session, drop aborted trials, and return the per-trial arrays
    plus animal / genotype / inhSite. trialMap is intentionally NOT applied (the
    original parses it but never uses it), and opto and miss trials are kept."""
    from pynwb import NWBHDF5IO

    with NWBHDF5IO(str(nwbPath), "r") as io:
        nwb = io.read()
        animal = toText(nwb.subject.subject_id).upper()
        genotype = toText(nwb.subject.genotype).upper()
        trialsDf = nwb.trials.to_dataframe()
        sessInfo = readSessionInfo(nwb)

    # Typed per-trial arrays.
    trialType = np.array([toText(x) for x in trialsDf["trialType"].to_numpy()], dtype=object)
    result = np.array([float(x) if x is not None and str(x) != "" else np.nan
                       for x in trialsDf["result"].to_numpy()], dtype=float)
    response = np.array([firstNumber(x, default=np.nan) for x in trialsDf["response"].to_numpy()], dtype=float)
    leftStimType = np.array([toText(x) for x in trialsDf["leftStimType"].to_numpy()], dtype=object)
    rightStimType = np.array([toText(x) for x in trialsDf["rightStimType"].to_numpy()], dtype=object)

    # Inhibition site: take it from the per-trial inhSite column (the original uses the
    # first trial's inhSite); fall back to session_info if the column is absent.
    if "inhSite" in trialsDf.columns and len(trialsDf):
        inhSite = toText(trialsDf["inhSite"].to_numpy()[0]).strip()
    else:
        inhSite = toText(sessInfo.get("inhSite")).strip()

    # Drop aborted trials (response == 3).
    notAbort = response != 3
    trialType = trialType[notAbort]
    result = result[notAbort]
    leftStimType = leftStimType[notAbort]
    rightStimType = rightStimType[notAbort]

    # Per-trial amplitude for the left and right stimulus descriptors.
    ampLeftPerTrial = np.array([stimAmp(s) for s in leftStimType], dtype=float)
    ampRightPerTrial = np.array([stimAmp(s) for s in rightStimType], dtype=float)

    # Boolean mask per trial type (0..3), precomputed for the bootstrap.
    trialTypeMasks = [np.array([t == name for t in trialType], dtype=bool) for name in TRIAL_TYPES_OPTO]

    return dict(animal=animal, genotype=genotype, inhSite=inhSite, result=result,
                trialTypeMasks=trialTypeMasks, ampLeftPerTrial=ampLeftPerTrial,
                ampRightPerTrial=ampRightPerTrial)


def loadSessions(nwbDir, verbose=True):
    """Read every opto NWB and group sessions by (genotype, inhSite, animal)."""
    nwbFiles = sorted(Path(nwbDir).glob("*.nwb"))
    grouped = {geno: {site: {} for site in INH_SITES} for geno in GENOTYPES}
    nKept = 0
    for nwbFile in nwbFiles:
        try:
            session = readOptoSession(nwbFile)
        except Exception as err:
            print(f"  ERROR reading {nwbFile.name}: {type(err).__name__}: {err}")
            continue
        # Keep only the two S1 inhibition sites and the two genotypes we plot.
        if session["inhSite"] not in INH_SITES:
            continue
        if session["genotype"] not in GENOTYPES:
            continue
        grouped[session["genotype"]][session["inhSite"]].setdefault(session["animal"], []).append(session)
        nKept += 1
    if verbose:
        print(f"loaded {nKept} opto sessions")
        for geno in GENOTYPES:
            for site in INH_SITES:
                mice = sorted(grouped[geno][site].keys())
                print(f"  {geno} {site}: {len(mice)} mice {mice}")
    return grouped


# --------------------------------------------------------------------------- #
#  per-trial-type metrics on a set of trials
# --------------------------------------------------------------------------- #
def trialTypeCorrect(result, mask):
    """Correct fraction = mean result over the non-miss trials of this trial type."""
    typeResult = result[mask]
    nonMiss = ~np.isnan(typeResult)
    if nonMiss.any():
        return float(np.mean(typeResult[nonMiss]))
    return np.nan


def trialTypeMiss(result, mask):
    """Miss fraction = fraction of this trial type's trials with a NaN result."""
    typeResult = result[mask]
    if len(typeResult):
        return float(np.mean(np.isnan(typeResult)))
    return np.nan


def trialTypeAmp(result, mask, ampPerTrial):
    """Mean stimulus amplitude over the non-miss trials of this trial type."""
    keep = mask & ~np.isnan(result)
    if keep.any():
        return float(np.mean(ampPerTrial[keep]))
    return np.nan


# --------------------------------------------------------------------------- #
#  per (genotype, inhSite, mouse) statistics
# --------------------------------------------------------------------------- #
def pooledTrialTypeMetrics(sessions):
    """Pool all of a mouse's trials (for one inhSite) and return the per-trial-type
    correct and miss fractions [Left, Left_Opto, Right, Right_Opto]."""
    result = np.concatenate([s["result"] for s in sessions])
    masks = [np.concatenate([s["trialTypeMasks"][tt] for s in sessions]) for tt in range(4)]
    pooledPerf = np.array([trialTypeCorrect(result, masks[tt]) for tt in range(4)])
    pooledMiss = np.array([trialTypeMiss(result, masks[tt]) for tt in range(4)])
    return pooledPerf, pooledMiss


def perSessionDeltaMeans(sessions):
    """Mean over sessions of the per-session opto-minus-nonopto delta, for correct and
    miss fraction. Returns (deltaPerf[left,right], deltaMiss[left,right])."""
    sessDeltaPerf = np.full((len(sessions), 2), np.nan)
    sessDeltaMiss = np.full((len(sessions), 2), np.nan)
    for sessInd, session in enumerate(sessions):
        result = session["result"]
        masks = session["trialTypeMasks"]
        perf = [trialTypeCorrect(result, masks[tt]) for tt in range(4)]
        miss = [trialTypeMiss(result, masks[tt]) for tt in range(4)]
        # delta = opto - non-opto, for the left pair (1,0) and the right pair (3,2).
        sessDeltaPerf[sessInd] = [perf[1] - perf[0], perf[3] - perf[2]]
        sessDeltaMiss[sessInd] = [miss[1] - miss[0], miss[3] - miss[2]]
    return np.mean(sessDeltaPerf, axis=0), np.mean(sessDeltaMiss, axis=0)


def bootstrapMouse(sessions, rng, nboot=NBOOT):
    """Multilevel bootstrap for one mouse+inhSite. Returns per-resample arrays for the
    delta correct (left,right), delta miss (left,right), and non-opto amplitude
    (left,right), each shaped (nboot,)."""
    nSessions = len(sessions)
    bootDeltaPerf = np.full((nboot, 2), np.nan)
    bootDeltaMiss = np.full((nboot, 2), np.nan)
    bootAmp = np.full((nboot, 2), np.nan)

    for bootNum in range(nboot):
        # Resample sessions with replacement.
        randSessions = rng.integers(0, nSessions, nSessions)
        sessDeltaPerf = np.full((nSessions, 2), np.nan)
        sessDeltaMiss = np.full((nSessions, 2), np.nan)
        sessAmp = np.full((nSessions, 2), np.nan)
        for slot, sessIdx in enumerate(randSessions):
            session = sessions[sessIdx]
            result = session["result"]
            nTrials = len(result)
            # Resample trials with replacement within the drawn session.
            randTrials = rng.integers(0, nTrials, nTrials)
            resResampled = result[randTrials]
            masksResampled = [session["trialTypeMasks"][tt][randTrials] for tt in range(4)]
            ampLeft = session["ampLeftPerTrial"][randTrials]
            ampRight = session["ampRightPerTrial"][randTrials]
            # Per-trial-type correct fraction and miss fraction on the resample.
            perf = [trialTypeCorrect(resResampled, masksResampled[tt]) for tt in range(4)]
            miss = [trialTypeMiss(resResampled, masksResampled[tt]) for tt in range(4)]
            sessDeltaPerf[slot] = [perf[1] - perf[0], perf[3] - perf[2]]
            sessDeltaMiss[slot] = [miss[1] - miss[0], miss[3] - miss[2]]
            # Non-opto stim amplitude for the left (tt 0) and right (tt 2) trial types.
            sessAmp[slot] = [trialTypeAmp(resResampled, masksResampled[0], ampLeft),
                             trialTypeAmp(resResampled, masksResampled[2], ampRight)]
        # Average across the resampled sessions for this resample.
        bootDeltaPerf[bootNum] = np.mean(sessDeltaPerf, axis=0)
        bootDeltaMiss[bootNum] = np.mean(sessDeltaMiss, axis=0)
        bootAmp[bootNum] = np.mean(sessAmp, axis=0)
    return bootDeltaPerf, bootDeltaMiss, bootAmp


def percentileCI(samples):
    """(mean, lo2.5, hi97.5) percentile CI of the bootstrap draws."""
    sortedSamples = np.sort(np.asarray(samples, dtype=float))
    lo = sortedSamples[int(round(NBOOT * 0.025))]
    hi = sortedSamples[int(round(NBOOT * 0.975))]
    return float(np.mean(samples)), float(lo), float(hi)


def computeGroupStats(sessions, rng):
    """All per-(mouse, inhSite) quantities the figures and stats need, keyed by
    'left'/'right' stimulus side."""
    pooledPerf, pooledMiss = pooledTrialTypeMetrics(sessions)
    perSessDeltaPerf, perSessDeltaMiss = perSessionDeltaMeans(sessions)
    bootDeltaPerf, bootDeltaMiss, bootAmp = bootstrapMouse(sessions, rng)

    # Direct pooled opto-minus-nonopto deltas (the plotted marker values).
    pooledDeltaPerf = {"left": pooledPerf[1] - pooledPerf[0], "right": pooledPerf[3] - pooledPerf[2]}
    pooledDeltaMiss = {"left": pooledMiss[1] - pooledMiss[0], "right": pooledMiss[3] - pooledMiss[2]}
    return dict(
        pooledPerf=pooledPerf,   # [Left, Left_Opto, Right, Right_Opto]
        pooledMiss=pooledMiss,
        pooledDeltaPerf=pooledDeltaPerf,
        pooledDeltaMiss=pooledDeltaMiss,
        perSessDeltaPerf={"left": perSessDeltaPerf[0], "right": perSessDeltaPerf[1]},
        perSessDeltaMiss={"left": perSessDeltaMiss[0], "right": perSessDeltaMiss[1]},
        ciDeltaPerf={"left": percentileCI(bootDeltaPerf[:, 0]), "right": percentileCI(bootDeltaPerf[:, 1])},
        ciDeltaMiss={"left": percentileCI(bootDeltaMiss[:, 0]), "right": percentileCI(bootDeltaMiss[:, 1])},
        ampMean={"left": float(np.mean(bootAmp[:, 0])), "right": float(np.mean(bootAmp[:, 1]))},
    )


def buildResults(grouped):
    """Compute every group's statistics. Returns results[genotype][inhSite][animal]."""
    # The per-mouse bootstrap (nboot iterations) is the slow part; print one line per
    # mouse so progress is visible.
    print(f"Bootstrapping per mouse ({NBOOT} iterations each) ...", flush=True)
    results = {geno: {site: {} for site in INH_SITES} for geno in GENOTYPES}
    for geno in GENOTYPES:
        for site in INH_SITES:
            for animal in sorted(grouped[geno][site].keys()):
                sessions = grouped[geno][site][animal]
                print(f"  {geno} / {site} / {animal} ({len(sessions)} sessions) ...", flush=True)
                # Reset the RNG per mouse to mirror rng(7) inside the original's loop.
                rng = np.random.default_rng(BOOTSTRAP_SEED)
                results[geno][site][animal] = computeGroupStats(sessions, rng)
    return results


# --------------------------------------------------------------------------- #
#  contra / ipsi refold helpers
# --------------------------------------------------------------------------- #
def miceOfGenotype(results, geno):
    """Sorted animals that have data for BOTH inhibition sites in this genotype."""
    both = set(results[geno]["Right S1"].keys()) & set(results[geno]["Left S1"].keys())
    return sorted(both)


# --------------------------------------------------------------------------- #
#  delta panels (correct / miss): contra vs ipsi, per genotype
# --------------------------------------------------------------------------- #
def plotDeltaPanel(results, geno, metric, outBase, yLimits, yTicks):
    """One WT-or-KO delta panel: per mouse, the contra and ipsi opto-minus-nonopto
    effect from both inhibition sites, with the pooled-direct delta as the marker and
    the bootstrap CI as the error bar. metric is 'perf' or 'miss'."""
    import matplotlib.pyplot as plt

    pooledKey = "pooledDeltaPerf" if metric == "perf" else "pooledDeltaMiss"
    ciKey = "ciDeltaPerf" if metric == "perf" else "ciDeltaMiss"

    fig, ax = plt.subplots(figsize=(1.6, 1.5))
    startX = 20
    contraXCenters = []
    ipsiXCenters = []
    mice = miceOfGenotype(results, geno)
    for mouseInd, animal in enumerate(mice):
        mousePosition = 15 * (mouseInd + 1)
        # Contra and ipsi clusters are 200 units apart; the two sites sit 75 apart.
        contraX = {"Right S1": startX + mousePosition, "Left S1": startX + mousePosition + 75}
        ipsiX = {"Right S1": startX + 200 + mousePosition, "Left S1": startX + 200 + mousePosition + 75}
        contraXCenters.append(np.median(list(contraX.values())))
        ipsiXCenters.append(np.median(list(ipsiX.values())))
        for site in INH_SITES:
            group = results[geno][site][animal]
            # Contra effect (red) and ipsi effect (blue) for this inhibition site.
            for clusterX, side, color in ((contraX, CONTRA_SIDE[site], CONTRA_COLOR),
                                          (ipsiX, IPSI_SIDE[site], IPSI_COLOR)):
                ciMean, ciLo, ciHi = group[ciKey][side]
                ax.errorbar(clusterX[site], ciMean, yerr=[[ciMean - ciLo], [ciHi - ciMean]],
                            fmt="none", ecolor=color, linewidth=1, capsize=0)
                ax.plot(clusterX[site], group[pooledKey][side], marker=SITE_MARKER[site],
                        color=color, markersize=10 if site == "Right S1" else 5, linewidth=1)

    # Axis cosmetics: zero reference line, contra/ipsi ticks, Arial fonts.
    ax.axhline(0, ls="--", color=[0.5, 0.5, 0.5], linewidth=1)
    ax.set_ylim(*yLimits)
    ax.set_yticks(yTicks)
    allRightX = max(ipsiXCenters) if ipsiXCenters else 300
    ax.set_xlim(0, allRightX + 70)
    ax.set_xticks([np.mean(contraXCenters), np.mean(ipsiXCenters)])
    ax.set_xticklabels(["Contra stim", "Ipsi stim"])
    ax.tick_params(labelsize=8, direction="out")
    for tickLabel in ax.get_xticklabels() + ax.get_yticklabels():
        tickLabel.set_fontname("Arial")
    ax.spines[["top", "right"]].set_visible(False)
    fig.savefig(f"{outBase}.pdf", dpi=1200, bbox_inches="tight")
    fig.savefig(f"{outBase}.png", dpi=300, bbox_inches="tight")
    plt.close(fig)


def plotAmplitudePanel(results, geno, outBase):
    """Per-genotype non-opto amplitude panel (contra vs ipsi), bootstrap-mean points
    only. Returns the contra and ipsi amplitude value lists for the stats file."""
    import matplotlib.pyplot as plt

    fig, ax = plt.subplots(figsize=(1.6, 1.5))
    startX = 20
    contraXCenters = []
    ipsiXCenters = []
    contraAmps = []
    ipsiAmps = []
    mice = miceOfGenotype(results, geno)
    for mouseInd, animal in enumerate(mice):
        mousePosition = 15 * (mouseInd + 1)
        contraX = {"Right S1": startX + mousePosition, "Left S1": startX + mousePosition + 75}
        ipsiX = {"Right S1": startX + 200 + mousePosition, "Left S1": startX + 200 + mousePosition + 75}
        contraXCenters.append(np.median(list(contraX.values())))
        ipsiXCenters.append(np.median(list(ipsiX.values())))
        for site in INH_SITES:
            group = results[geno][site][animal]
            contraAmp = group["ampMean"][CONTRA_SIDE[site]] / 10.0
            ipsiAmp = group["ampMean"][IPSI_SIDE[site]] / 10.0
            ax.plot(contraX[site], contraAmp, marker=SITE_MARKER[site], color=CONTRA_COLOR,
                    markersize=10 if site == "Right S1" else 5, linewidth=1)
            ax.plot(ipsiX[site], ipsiAmp, marker=SITE_MARKER[site], color=IPSI_COLOR,
                    markersize=10 if site == "Right S1" else 5, linewidth=1)
            contraAmps.append(contraAmp)
            ipsiAmps.append(ipsiAmp)

    ax.set_ylim(0, 110)
    ax.set_yticks(range(0, 101, 25))
    ax.set_ylabel("Amplitude (% of max.)", fontsize=8, fontname="Arial")
    allRightX = max(ipsiXCenters) if ipsiXCenters else 300
    ax.set_xlim(0, allRightX + 70)
    ax.set_xticks([np.mean(contraXCenters), np.mean(ipsiXCenters)])
    ax.set_xticklabels(["Contra stim", "Ipsi stim"])
    ax.tick_params(labelsize=8, direction="out")
    for tickLabel in ax.get_xticklabels() + ax.get_yticklabels():
        tickLabel.set_fontname("Arial")
    ax.spines[["top", "right"]].set_visible(False)
    fig.savefig(f"{outBase}.pdf", dpi=300, bbox_inches="tight")
    fig.savefig(f"{outBase}.png", dpi=300, bbox_inches="tight")
    plt.close(fig)
    return contraAmps, ipsiAmps


# --------------------------------------------------------------------------- #
#  FigS2 raw-performance panels (Stim vs Stim+opto), per genotype
# --------------------------------------------------------------------------- #
def rawContraIpsiPairs(results, geno, metric):
    """Per-mouse [non-opto, opto] pairs for the contra and ipsi stimulus, stacked over
    both inhibition sites. metric is 'perf' or 'miss'. Returns (contra, ipsi) arrays
    shaped (nMice*2, 2)."""
    pooledKey = "pooledPerf" if metric == "perf" else "pooledMiss"
    # Column pairs into pooled[Left, Left_Opto, Right, Right_Opto] for each side.
    sidePair = {"left": (0, 1), "right": (2, 3)}
    contra = []
    ipsi = []
    for site in INH_SITES:
        for animal in sorted(results[geno][site].keys()):
            pooled = results[geno][site][animal][pooledKey]
            contraCols = sidePair[CONTRA_SIDE[site]]
            ipsiCols = sidePair[IPSI_SIDE[site]]
            contra.append([pooled[contraCols[0]], pooled[contraCols[1]]])
            ipsi.append([pooled[ipsiCols[0]], pooled[ipsiCols[1]]])
    return np.array(contra), np.array(ipsi)


def plotRawPanel(results, geno, metric, outBase, yLimits, contraYLine, ipsiYLine):
    """FigS2 raw-performance figure: two subplots (contra | ipsi), each a per-mouse
    line from Stim to Stim+opto plus the group mean line. Returns (contra, ipsi)."""
    import matplotlib.pyplot as plt

    contra, ipsi = rawContraIpsiPairs(results, geno, metric)
    fig, (axContra, axIpsi) = plt.subplots(1, 2, figsize=(3, 2))
    for ax, data, color, yLine, title in ((axContra, contra, CONTRA_COLOR, contraYLine, "Contra stim"),
                                          (axIpsi, ipsi, IPSI_COLOR, ipsiYLine, "Ipsi stim")):
        # One faint line per mouse, then the bold mean line.
        for row in data:
            ax.plot([0.75, 1.25], row, "-", color=color + [0.3], linewidth=1)
        ax.plot([0.75, 1.25], np.mean(data, axis=0), "-", color=color + [1.0], linewidth=1)
        if yLine is not None:
            ax.axhline(yLine, ls="--", color=[0, 0, 0], linewidth=1)
        ax.set_xlim(0.5, 1.5)
        ax.set_ylim(*yLimits)
        ax.set_xticks([0.75, 1.25])
        ax.set_xticklabels(["Stim", "Stim + opto"])
        ax.set_title(title, fontsize=8, fontname="Arial", color=color)
        ax.tick_params(labelsize=8, direction="out")
        for tickLabel in ax.get_xticklabels() + ax.get_yticklabels():
            tickLabel.set_fontname("Arial")
        ax.spines[["top", "right"]].set_visible(False)
    label = "Correct Fraction" if metric == "perf" else "Miss fraction Fraction"
    axContra.set_ylabel(label, fontsize=8, fontname="Arial")
    fig.savefig(f"{outBase}.pdf", dpi=1200, bbox_inches="tight")
    fig.savefig(f"{outBase}.png", dpi=1200, bbox_inches="tight")
    plt.close(fig)
    return contra, ipsi


# --------------------------------------------------------------------------- #
#  stats files
# --------------------------------------------------------------------------- #
def deltaMeansByGenotype(results, metric, side_of):
    """Concatenate the per-mouse per-session delta MEANS for one folded side across
    both inhibition sites, per genotype. side_of maps an inhSite -> 'left'/'right'."""
    perSessKey = "perSessDeltaPerf" if metric == "perf" else "perSessDeltaMiss"
    byGeno = {}
    for geno in GENOTYPES:
        values = []
        for site in INH_SITES:
            for animal in sorted(results[geno][site].keys()):
                values.append(results[geno][site][animal][perSessKey][side_of[site]])
        byGeno[geno] = np.array(values, dtype=float)
    return byGeno


def andersonRejectsNormal(values):
    """True if the Anderson-Darling test rejects normality at 5% (mirrors adtest h=1)."""
    from scipy import stats

    values = np.asarray(values, dtype=float)
    if len(values) < 4 or np.allclose(values, values[0]):
        return False
    result = stats.anderson(values, dist="norm")
    # critical_values[2] is the 5% level in scipy's ordering [15,10,5,2.5,1]%.
    return bool(result.statistic > result.critical_values[2])


def writeDeltaStatsFile(outPath, results, metric):
    """Reproduce 'Fig2 OptoInhibition Stats delta {correct|miss} fraction.txt': per
    genotype, binomial tests on the per-mouse contra/ipsi delta means, then a
    between-genotype comparison (ttest2 if all four groups look normal, else ranksum)."""
    from scipy import stats

    contraByGeno = deltaMeansByGenotype(results, metric, CONTRA_SIDE)
    ipsiByGeno = deltaMeansByGenotype(results, metric, IPSI_SIDE)

    with open(outPath, "w") as statsFile:
        statsFile.write("Pvals using binomial tests:\n")
        for geno in GENOTYPES:
            contra = contraByGeno[geno]
            ipsi = ipsiByGeno[geno]
            # Contra success = impaired (perf delta < 0) or more misses (miss delta > 0).
            contraSuccesses = int(np.sum(contra < 0)) if metric == "perf" else int(np.sum(contra > 0))
            ipsiSuccesses = int(np.sum(ipsi > 0))
            contraBinoCdf = float(stats.binom.sf(contraSuccesses - 1, len(contra), 0.5))
            contraBinoPdf = float(stats.binom.pmf(contraSuccesses, len(contra), 0.5))
            ipsiBinoCdf = float(stats.binom.sf(ipsiSuccesses - 1, len(ipsi), 0.5))
            ipsiBinoPdf = float(stats.binom.pmf(ipsiSuccesses, len(ipsi), 0.5))
            statsFile.write(f"For genotype {geno} using binocdf contra is {fmtNum(contraBinoCdf)} "
                            f"using binopdf contra is {fmtNum(contraBinoPdf)}\n")
            statsFile.write(f"For genotype {geno} using binocdf ipsi is {fmtNum(ipsiBinoCdf)} "
                            f"using binopdf ipsi is {fmtNum(ipsiBinoPdf)}\n")

        # Between-genotype comparison: adtest on all four groups decides the test.
        allNonNormal = all(andersonRejectsNormal(x) for x in
                           (contraByGeno["WT"], contraByGeno["KO"], ipsiByGeno["WT"], ipsiByGeno["KO"]))
        if allNonNormal:
            contraP = float(stats.ttest_ind(contraByGeno["WT"], contraByGeno["KO"]).pvalue)
            ipsiP = float(stats.ttest_ind(ipsiByGeno["WT"], ipsiByGeno["KO"]).pvalue)
            testName = "ttest2"
        else:
            contraP = float(stats.mannwhitneyu(contraByGeno["WT"], contraByGeno["KO"], alternative="two-sided").pvalue)
            ipsiP = float(stats.mannwhitneyu(ipsiByGeno["WT"], ipsiByGeno["KO"], alternative="two-sided").pvalue)
            testName = "Mann Whitney U"
        statsFile.write(f"Between genotypes contra effect comparison using {testName} is {fmtNum(contraP)}\n")
        statsFile.write(f"Between genotypes ipsi effect comparison using {testName} is {fmtNum(ipsiP)}\n")


def writeAmplitudeStatsFile(outPath, ampByGeno):
    """Reproduce 'OptobehavMeanAmplitudedatavalues.txt': per-genotype contra/ipsi
    amplitude mean & SD, then a between-genotype rank-sum for each."""
    from scipy import stats

    with open(outPath, "w") as statsFile:
        for geno in GENOTYPES:
            for stimName, values in (("Contra", ampByGeno[geno]["contra"]), ("Ipsi", ampByGeno[geno]["ipsi"])):
                values = np.asarray(values, dtype=float)
                statsFile.write(f"For genotype: {geno} {stimName} mean: {fmtNum(np.mean(values))} "
                                f"sd: {fmtNum(np.std(values, ddof=1))}\n")
        contraP = float(stats.mannwhitneyu(ampByGeno["WT"]["contra"], ampByGeno["KO"]["contra"],
                                           alternative="two-sided").pvalue)
        ipsiP = float(stats.mannwhitneyu(ampByGeno["WT"]["ipsi"], ampByGeno["KO"]["ipsi"],
                                         alternative="two-sided").pvalue)
        statsFile.write(f"Between genotype Mann whitney U test comparison for contra p-value  {fmtNum(contraP)}\n")
        statsFile.write(f"Between genotype Mann whitney U test comparison for ipsi p-value  {fmtNum(ipsiP)}\n")


def writeRawStatsFile(outPath, rawByGeno, metric):
    """Reproduce the FigS2 raw-performance stats files: per-genotype contra/ipsi means,
    between-genotype ttest2 on the after-effect (opto) and baseline columns, and a
    within-genotype paired ttest (Stim vs Stim+opto)."""
    from scipy import stats

    with open(outPath, "w") as statsFile:
        for geno in GENOTYPES:
            contra = rawByGeno[geno]["contra"]
            ipsi = rawByGeno[geno]["ipsi"]
            if metric == "perf":
                statsFile.write(f"For genotype: {geno} Mean contra is {fmtNum(np.mean(contra, axis=0))} "
                                f"std: {fmtNum(np.std(contra, axis=0, ddof=1))}\n")
                statsFile.write(f"For genotype: {geno} Mean ipsi is {fmtNum(np.mean(ipsi, axis=0))} "
                                f"std: {fmtNum(np.std(ipsi, axis=0, ddof=1))}\n")
            else:
                statsFile.write(f"For genotype: {geno} Mean contra is {fmtNum(np.mean(contra, axis=0))}\n")
                statsFile.write(f"For genotype: {geno} Mean ipsi is {fmtNum(np.mean(ipsi, axis=0))}\n")

        # Between-genotype ttest2 on the opto (after-effect) column, and on baseline.
        # The correct-fraction file prefixes these lines differently from the miss file.
        afterPrefix = "Between genotype comparison for" if metric == "perf" else "For"
        contraAfter = float(stats.ttest_ind(rawByGeno["WT"]["contra"][:, 1], rawByGeno["KO"]["contra"][:, 1]).pvalue)
        ipsiAfter = float(stats.ttest_ind(rawByGeno["WT"]["ipsi"][:, 1], rawByGeno["KO"]["ipsi"][:, 1]).pvalue)
        statsFile.write(f"{afterPrefix} contra p-value for after effect is {fmtNum(contraAfter)}\n")
        statsFile.write(f"{afterPrefix} ipsi p-value for after effect is {fmtNum(ipsiAfter)}\n")
        if metric == "perf":
            contraBase = float(stats.ttest_ind(rawByGeno["WT"]["contra"][:, 0], rawByGeno["KO"]["contra"][:, 0]).pvalue)
            ipsiBase = float(stats.ttest_ind(rawByGeno["WT"]["ipsi"][:, 0], rawByGeno["KO"]["ipsi"][:, 0]).pvalue)
            statsFile.write(f"Between genotype comparison for contra p-value for baseline is {fmtNum(contraBase)}\n")
            statsFile.write(f"Between genotype comparison for ipsi p-value for baseline is {fmtNum(ipsiBase)}\n")

        # Within-genotype paired ttest (Stim vs Stim+opto), per genotype.
        for geno in GENOTYPES:
            contra = rawByGeno[geno]["contra"]
            ipsi = rawByGeno[geno]["ipsi"]
            contraPaired = float(stats.ttest_rel(contra[:, 0], contra[:, 1]).pvalue)
            ipsiPaired = float(stats.ttest_rel(ipsi[:, 0], ipsi[:, 1]).pvalue)
            statsFile.write(f"For genotype {geno} paired ttest comparison for contra p-value "
                            f"for after effect is {fmtNum(contraPaired)}\n")
            statsFile.write(f"For genotype {geno} paired ttest comparison for ipsi p-value "
                            f"for after effect is {fmtNum(ipsiPaired)}\n")


# --------------------------------------------------------------------------- #
def main(argv=None):
    parser = argparse.ArgumentParser(description="Fig2 opto-inhibition panels from NWB")
    parser.add_argument("--nwb-dir", required=True, help="folder of behavior/opto .nwb files")
    parser.add_argument("--fig2-dir", required=True, help="output folder for the Fig2 panels")
    parser.add_argument("--figs2-dir", required=True, help="output folder for the FigS2 raw panels")
    args = parser.parse_args(argv)

    import matplotlib
    matplotlib.use("Agg")

    fig2Dir = Path(args.fig2_dir)
    figs2Dir = Path(args.figs2_dir)
    fig2Dir.mkdir(parents=True, exist_ok=True)
    figs2Dir.mkdir(parents=True, exist_ok=True)

    # Load, group, and compute every mouse's statistics.
    grouped = loadSessions(args.nwb_dir)
    results = buildResults(grouped)

    ampByGeno = {}
    rawPerfByGeno = {}
    rawMissByGeno = {}
    for geno in GENOTYPES:
        # Fig 2B (delta correct), Fig 2C (delta miss), Fig S2D (amplitude).
        plotDeltaPanel(results, geno, "perf",
                       str(fig2Dir / f"Fig2B - Delta correct fraction {geno}"),
                       (-0.75, 0.35), [-0.6, -0.4, -0.2, 0.0, 0.2])
        plotDeltaPanel(results, geno, "miss",
                       str(fig2Dir / f"Fig2C - Delta miss fraction {geno}"),
                       (-0.2, 0.6), [-0.2, 0.0, 0.2, 0.4, 0.6])
        contraAmps, ipsiAmps = plotAmplitudePanel(
            results, geno, str(fig2Dir / f"FigS2D - Stimulus amplitude {geno}"))
        ampByGeno[geno] = {"contra": contraAmps, "ipsi": ipsiAmps}

        # Fig S2B (WT) / S2C (KO) raw-performance panels; raw miss is a supporting panel.
        perfLetter = "B" if geno == "WT" else "C"
        contraPerf, ipsiPerf = plotRawPanel(results, geno, "perf",
                                            str(figs2Dir / f"FigS2{perfLetter} - Mean performance {geno}"),
                                            (0, 1), 0.5, 0.7)
        contraMiss, ipsiMiss = plotRawPanel(results, geno, "miss",
                                            str(figs2Dir / f"FigS2 - Mean miss performance {geno}"),
                                            (0, 0.5), None, 0.7)
        rawPerfByGeno[geno] = {"contra": contraPerf, "ipsi": ipsiPerf}
        rawMissByGeno[geno] = {"contra": contraMiss, "ipsi": ipsiMiss}

    # Stats files.
    writeDeltaStatsFile(fig2Dir / "Fig2B - Delta correct fraction stats.txt", results, "perf")
    writeDeltaStatsFile(fig2Dir / "Fig2C - Delta miss fraction stats.txt", results, "miss")
    writeAmplitudeStatsFile(fig2Dir / "FigS2D - Stimulus amplitude values.txt", ampByGeno)
    writeRawStatsFile(figs2Dir / "FigS2BC - Mean performance values.txt", rawPerfByGeno, "perf")
    writeRawStatsFile(figs2Dir / "FigS2 - Mean miss performance values.txt", rawMissByGeno, "miss")

    print(f"wrote Fig2 panels + stats to {fig2Dir}")
    print(f"wrote FigS2 raw panels + stats to {figs2Dir}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
