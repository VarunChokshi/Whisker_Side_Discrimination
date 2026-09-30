"""
fig3_analysis_nwb.py
====================
Analysis core for Figure 3 (passive-stim S1/M1 ephys), ported to read NWB.

Reproduces the per-unit quantities that GetComposite / GetFRData / AddMeanFRData compute
from the se, reading them instead from the converted NWB files: per unit, per stimulus
frequency, the stim-aligned spike rasters and firing-rate traces for contralateral and
ipsilateral trials, plus per analysis-window p-values (pre- vs post-stim Wilcoxon
signed-rank), the contra-bias index, and the unit's normalised cortical depth.

Trial handling mirrors the original exactly:
  * drop aborted trials (response == 3), then keep only the no-lick trials (response == 0);
  * apply the session's APStim range, then drop the first remaining trial;
  * per frequency, left trials are Stim_Som_Left with a matching left-stim freq, right
    trials Stim_Som_Right with a matching right-stim freq;
  * a 'Left ...' recording site makes left stim ipsilateral and right stim contralateral.

The output is a list of per-(session, frequency, unit) records (see unitRecords); the
figure ports consume these.

Deps: pynwb, numpy, scipy
"""
from __future__ import annotations

import re
from pathlib import Path

import numpy as np

# Analysis constants (ops in the original).
T_WINS = (-0.31, 0.31)
BIN_SIZE = 0.0025
BINS = np.arange(T_WINS[0], T_WINS[1] + BIN_SIZE / 2, BIN_SIZE)   # -0.31 : 0.0025 : 0.31
WINDOWS = [0.025, 0.04, 0.05, 0.075, 0.1, 0.15, 0.2, 0.3]
WINDOW_NAMES = ["25", "40", "50", "75", "100", "150", "200", "300"]
STAT_ALPHA = 0.005
DEFAULT_PENETRATION_DEPTH = 1300.0
DEFAULT_CORTICAL_DEPTH = 1280.0


# --------------------------------------------------------------------------- #
#  helpers
# --------------------------------------------------------------------------- #
def toText(value):
    if isinstance(value, bytes):
        return value.decode("utf-8", "replace")
    return "" if value is None else str(value)


def parseNumber(text, default=np.nan):
    match = re.search(r"-?\d+(?:\.\d+)?", str(text))
    return float(match.group()) if match else default


def parseApStimRanges(apStim, nTrials):
    """Parse an APStim string ('1:end'', '50:350'', '1:240:260:end'') to 1-based inclusive
    ranges (union), or None to keep all trials."""
    text = toText(apStim).strip()
    if not text or text.lower() == "nan" or ":" not in text:
        return None
    parts = [p.strip().rstrip("'").strip() for p in text.split(":")]
    ranges = []
    for pairInd in range(0, len(parts) - 1, 2):
        startDigits = re.sub(r"\D", "", parts[pairInd])
        start = int(startDigits) if startDigits else 1
        stopToken = parts[pairInd + 1]
        if stopToken.lower() == "end" or stopToken == "":
            stop = nTrials
        else:
            stopDigits = re.sub(r"\D", "", stopToken)
            stop = int(stopDigits) if stopDigits else nTrials
        ranges.append((max(1, start), min(stop, nTrials)))
    return ranges or None


def signrankP(preValues, postValues):
    """Two-sided Wilcoxon signed-rank p-value (MATLAB signrank), robust to all-equal
    input (returns 1.0 when there is no difference to test)."""
    from scipy import stats

    pre = np.asarray(preValues, dtype=float)
    post = np.asarray(postValues, dtype=float)
    diff = post - pre
    if len(diff) == 0 or np.allclose(diff, 0.0):
        return 1.0
    try:
        return float(stats.wilcoxon(pre, post, zero_method="wilcox", alternative="two-sided").pvalue)
    except ValueError:
        return 1.0


# --------------------------------------------------------------------------- #
#  read one session from NWB
# --------------------------------------------------------------------------- #
def readSession(nwbPath):
    """Read the trials, units (spike trains + depth), firing-rate series, stimulus and
    session metadata needed for the analysis. Returns a dict of arrays."""
    from pynwb import NWBHDF5IO

    with NWBHDF5IO(str(nwbPath), "r") as io:
        nwb = io.read()
        animal = toText(nwb.subject.subject_id).upper()
        genotype = toText(nwb.subject.genotype).upper()

        trials = nwb.trials.to_dataframe()
        response = trials["response"].to_numpy(dtype=float)
        trialType = np.array([toText(x) for x in trials["trialType"].to_numpy()], dtype=object)
        leftStimType = np.array([toText(x) for x in trials["leftStimType"].to_numpy()], dtype=object)
        rightStimType = np.array([toText(x) for x in trials["rightStimType"].to_numpy()], dtype=object)
        referenceTime = trials["reference_time"].to_numpy(dtype=float)

        units = nwb.units
        spikeTrains = [np.asarray(units["spike_times"][i], dtype=float) for i in range(len(units))]
        unitDepth = np.asarray(units["depth"].data[:], dtype=float)
        ksLabel = np.array([toText(x) for x in units["ks_label"].data[:]], dtype=object)

        firingRate = nwb.processing["ecephys"]["firing_rate"]
        frData = np.asarray(firingRate.data[:], dtype=float)          # (samples, units)
        frTimestamps = np.asarray(firingRate.timestamps[:], dtype=float)

        stimSeries = nwb.get_stimulus("piezo_stim")
        stimData = np.asarray(stimSeries.data[:], dtype=float)         # (samples, [left, right])
        stimTimestamps = np.asarray(stimSeries.timestamps[:], dtype=float)

        info = nwb.processing["metadata"]["session_info"]
        infoRow = {c: info[c].data[0] for c in info.colnames}

    recSite = toText(infoRow.get("recSite"))
    region = toText(infoRow.get("region"))
    apStim = toText(infoRow.get("APStim"))
    penetrationDepth = parseNumber(infoRow.get("histology"), DEFAULT_PENETRATION_DEPTH)
    corticalDepth = parseNumber(infoRow.get("corticaldepth"), DEFAULT_CORTICAL_DEPTH)

    return dict(
        animal=animal, genotype=genotype, recSite=recSite, region=region, apStim=apStim,
        penetrationDepth=penetrationDepth, corticalDepth=corticalDepth,
        session=Path(nwbPath).stem,
        response=response, trialType=trialType, leftStimType=leftStimType,
        rightStimType=rightStimType, referenceTime=referenceTime,
        spikeTrains=spikeTrains, unitDepth=unitDepth, ksLabel=ksLabel,
        frData=frData, frTimestamps=frTimestamps,
        stimData=stimData, stimTimestamps=stimTimestamps,
    )


# --------------------------------------------------------------------------- #
#  trial selection + per-trial reconstruction
# --------------------------------------------------------------------------- #
def selectTrials(session):
    """Return the indices of the analysed trials (no-lick, within APStim, first dropped)
    in original order."""
    keep = np.where(session["response"] == 0)[0]          # drop abort(3) + licked(1,2)
    ranges = parseApStimRanges(session["apStim"], len(keep))
    if ranges is not None:
        mask = np.zeros(len(keep), dtype=bool)
        for start, stop in ranges:
            if stop >= start:
                mask[start - 1:stop] = True
        keep = keep[mask]
    return keep[1:] if len(keep) else keep                # drop the first remaining trial


def trialSpikeTrain(spikeTimes, reference):
    """Stim-aligned spikes of one unit within one trial's window [tWins]."""
    lo, hi = reference + T_WINS[0], reference + T_WINS[1]
    inWindow = spikeTimes[(spikeTimes >= lo) & (spikeTimes <= hi)]
    return inWindow - reference


def trialFiringRate(frData, frTimestamps, reference):
    """Per-unit firing rate for one trial, resampled onto the fixed BINS grid (stim-
    aligned). Returns (nBins, nUnits)."""
    lo, hi = reference + T_WINS[0] - BIN_SIZE, reference + T_WINS[1] + BIN_SIZE
    loInd = np.searchsorted(frTimestamps, lo, side="left")
    hiInd = np.searchsorted(frTimestamps, hi, side="right")
    stimAligned = frTimestamps[loInd:hiInd] - reference
    block = frData[loInd:hiInd, :]
    if len(stimAligned) < 2:
        return np.zeros((len(BINS), frData.shape[1]))
    resampled = np.empty((len(BINS), frData.shape[1]))
    for unitInd in range(frData.shape[1]):
        resampled[:, unitInd] = np.interp(BINS, stimAligned, block[:, unitInd])
    return resampled


# --------------------------------------------------------------------------- #
#  frequency parsing
# --------------------------------------------------------------------------- #
def freqOf(stimType, freqStart):
    return toText(stimType)[freqStart:freqStart + 2]


def uniqueFrequencies(leftStimTypes):
    """Unique stimulus frequencies and the 0-based char offset they start at (5:6 in the
    1-based original, else 17:18)."""
    uniqueTypes = sorted(set(toText(s) for s in leftStimTypes))
    freqs = sorted(set(t[4:6] for t in uniqueTypes))
    if freqs and re.fullmatch(r"\d+", freqs[0]):
        return freqs, 4
    freqs = sorted(set(t[16:18] for t in uniqueTypes))
    return freqs, 16


# --------------------------------------------------------------------------- #
#  per-session unit records
# --------------------------------------------------------------------------- #
def unitRecords(session):
    """Build the per-(frequency, unit) records for one session: contra/ipsi rasters and
    FR traces, plus per-window p-values, cbias and normalised depth."""
    trialInds = selectTrials(session)
    if len(trialInds) == 0:
        return []

    reference = session["referenceTime"][trialInds]
    trialType = session["trialType"][trialInds]
    leftStimTypes = session["leftStimType"][trialInds]
    rightStimTypes = session["rightStimType"][trialInds]
    nUnits = len(session["spikeTrains"])

    # Per-trial reconstruction (stim-aligned): spikes per unit, and the FR on BINS.
    perTrialSpikes = [[trialSpikeTrain(session["spikeTrains"][u], reference[t]) for u in range(nUnits)]
                      for t in range(len(trialInds))]
    perTrialFr = [trialFiringRate(session["frData"], session["frTimestamps"], reference[t])
                  for t in range(len(trialInds))]

    # Contra / ipsi assignment from the recording site.
    leftIsIpsi = sum(ch in session["recSite"] for ch in "Left") == 4

    frequencies, freqStart = uniqueFrequencies(leftStimTypes)
    penetration = session["penetrationDepth"]
    cortical = session["corticalDepth"] if session["corticalDepth"] else DEFAULT_CORTICAL_DEPTH

    records = []
    for freq in frequencies:
        leftTrials = np.array([i for i in range(len(trialInds))
                               if trialType[i] == "Stim_Som_Left" and freqOf(leftStimTypes[i], freqStart) == freq])
        rightTrials = np.array([i for i in range(len(trialInds))
                                if trialType[i] == "Stim_Som_Right" and freqOf(rightStimTypes[i], freqStart) == freq])
        if len(leftTrials) == 0 or len(rightTrials) == 0:
            continue

        # FR matrices (trials x bins) per unit for each side.
        frLeft = np.stack([perTrialFr[t] for t in leftTrials], axis=0)    # (nLeft, nBins, nUnits)
        frRight = np.stack([perTrialFr[t] for t in rightTrials], axis=0)  # (nRight, nBins, nUnits)

        for unitInd in range(nUnits):
            depthNorm = (penetration - session["unitDepth"][unitInd]) / cortical
            # Contra / ipsi FR trace matrices and spike rasters for this unit.
            if leftIsIpsi:
                frIpsi, frContra = frLeft[:, :, unitInd], frRight[:, :, unitInd]
                ipsiTrials, contraTrials = leftTrials, rightTrials
            else:
                frIpsi, frContra = frRight[:, :, unitInd], frLeft[:, :, unitInd]
                ipsiTrials, contraTrials = rightTrials, leftTrials
            spikesContra = [perTrialSpikes[t][unitInd] for t in contraTrials]
            spikesIpsi = [perTrialSpikes[t][unitInd] for t in ipsiTrials]

            perWindow = {}
            for window, windowName in zip(WINDOWS, WINDOW_NAMES):
                perWindow[windowName] = windowStats(
                    frLeft[:, :, unitInd], frRight[:, :, unitInd],
                    spikesContra, spikesIpsi, window, leftIsIpsi)

            records.append(dict(
                animal=session["animal"], session=session["session"], genotype=session["genotype"],
                recSite=session["recSite"], region=session["region"], freq=freq, unit=unitInd,
                depthRaw=float(session["unitDepth"][unitInd]), depthNorm=float(depthNorm),
                ksLabel=toText(session["ksLabel"][unitInd]).strip(),
                frTime=BINS.copy(), frContra=frContra, frIpsi=frIpsi,
                spikesContra=spikesContra, spikesIpsi=spikesIpsi,
                perWindow=perWindow,
            ))
    return records


def windowStats(frLeftUnit, frRightUnit, spikesContra, spikesIpsi, window, leftIsIpsi):
    """Per-window p-values (pre vs post FR, both sides), cbias (contra/ipsi spike-count
    change), and pvalBoth = min(pvalL, pvalR). frLeft/rightUnit are (nTrials, nBins)."""
    inWindow = np.where((BINS >= -window) & (BINS <= window))[0]
    frLeftWin = frLeftUnit[:, inWindow]
    frRightWin = frRightUnit[:, inWindow]
    half = int(round(frLeftWin.shape[1] / 2))
    preL, postL = frLeftWin[:, :half].mean(axis=1), frLeftWin[:, half:].mean(axis=1)
    preR, postR = frRightWin[:, :half].mean(axis=1), frRightWin[:, half:].mean(axis=1)
    pvalL = signrankP(preL, postL)
    pvalR = signrankP(preR, postR)

    # Contra / ipsi spike-count change over +/- window.
    contraPre = sum(np.sum((s > -window) & (s <= 0)) for s in spikesContra)
    contraPost = sum(np.sum((s > 0) & (s <= window)) for s in spikesContra)
    ipsiPre = sum(np.sum((s > -window) & (s <= 0)) for s in spikesIpsi)
    ipsiPost = sum(np.sum((s > 0) & (s <= window)) for s in spikesIpsi)
    contraChange = abs(contraPost - contraPre)
    ipsiChange = abs(ipsiPost - ipsiPre)
    denom = contraChange + ipsiChange
    cbias = (contraChange - ipsiChange) / denom if denom else np.nan

    pvalIpsi, pvalContra = (pvalL, pvalR) if leftIsIpsi else (pvalR, pvalL)
    return dict(pvalContra=pvalContra, pvalIpsi=pvalIpsi, pvalBoth=min(pvalL, pvalR), cbias=cbias)


# --------------------------------------------------------------------------- #
#  load a whole region folder
# --------------------------------------------------------------------------- #
def loadRegion(nwbDir, verbose=True):
    """Read every NWB in a region folder and return the concatenated per-unit records."""
    nwbFiles = sorted(Path(nwbDir).glob("*.nwb"))
    allRecords = []
    for nwbFile in nwbFiles:
        try:
            session = readSession(nwbFile)
            records = unitRecords(session)
        except Exception as err:
            print(f"  ERROR {nwbFile.name}: {type(err).__name__}: {err}")
            continue
        allRecords.extend(records)
        if verbose:
            print(f"  {nwbFile.name}: {len(records)} unit-freq records "
                  f"({session['genotype']} {session['recSite']})")
    if verbose:
        print(f"loaded {len(allRecords)} unit-freq records from {len(nwbFiles)} sessions")
    return allRecords
