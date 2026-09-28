"""
convert_ephys_to_nwb.py
=======================
Convert bodyside *passive-stim ephys* sessions (S1 or M1) to NWB.

Pipeline (run both steps in order):

  1) MATLAB:  dump_ephys_se_to_struct.m -- turns each "... se enriched.mat" into a
              Python-friendly "... se enriched_struct.mat" (variable `se_struct`, -v7),
              keeping spikeTime / spikeRate / adc / behavValue / behavTime and a trimmed
              spikeInfo (depth, channel, mean waveform), dropping the multi-GB templates.
  2) Python:  this script -- reads those *_struct.mat files and writes .nwb.

Each session becomes one NWB file with:
  * Units          -- per-unit spike_times (shifted into absolute session time by each
                      trial's referenceTime), obs_intervals, waveform_mean, and per-unit
                      columns depth / channel / quality metrics (KSLabel, group, snr,
                      firing_rate, isi_violation, n_spikes, peak_channel, cluster_id).
  * electrodes     -- from sessionInfo.chanmap (Neuropixels channel map; rel_x/rel_y),
                      electrode group location = recSite (e.g. 'Left wS1').
  * trials         -- trialType, response, result, left/rightStimType, bct_trialNum,
                      blockType, stimOnset and the behavTime event onsets; start/stop from
                      referenceTime + the adc window.
  * stimulus       -- the adc piezo command (leftStim / rightStim) as a stimulus series.
  * firing rate    -- the precomputed 2.5 ms spikeRate (units x time) as an ecephys
                      processing TimeSeries, so the figure port can use the exact FR the
                      original did (rather than re-deriving it).
  * session_info   -- recSite, APStim (trial range), penetration/cortical depth, probe,
                      sample rate, region (S1/M1).

Deps: pynwb, scipy, numpy, python-dateutil (nwbinspector optional).

Usage
-----
    python convert_ephys_to_nwb.py \
        --in-dir  "...\\NWBData\\Conversion\\ephys_struct_S1" \
        --out-dir "...\\NWBData\\Data\\ephys\\S1"      # region inferred from recSite
"""
from __future__ import annotations

import argparse
import re
import sys
from datetime import datetime
from pathlib import Path

import numpy as np
import scipy.io as spio
from dateutil import tz

from pynwb import NWBFile, NWBHDF5IO, TimeSeries
from pynwb.file import Subject

# Keep only spikes/stim within +/- this many seconds of each trial's stim onset. The last
# epoch's time series bleeds to the end of the recording in MSessionExplorer; the figures
# only ever use +/- 0.31 s, so this drops the inter-trial bleed while keeping full trials.
CLIP_SECONDS = 5.0
# The firing rate is stored per trial as a post-stim slice (0..~7 s, stim-relative). Keep
# the whole slice (capped to drop the last epoch's long bleed) so consecutive trials tile
# the recording continuously -- a trial's PRE-stim firing rate comes from the previous
# trial's tail, exactly as the original SliceTimeSeries(...,'bleed') fills it.
FR_MAX_SECONDS = 12.0

LAB = "O'Connor lab"
INSTITUTION = "Johns Hopkins University"
EXPERIMENTER = ["Varun Chokshi"]
SPECIES = "Mus musculus"
TIMEZONE = "US/Eastern"
STIM_TASK = "passive whisker stimulation during silicon-probe recording"

# Per-unit quality-metric fields to carry onto the Units table (name in se -> NWB column).
UNIT_METRIC_COLUMNS = {
    "depth": "depth",
    "peak_channel": "peak_channel",
    "firing_rate": "firing_rate",
    "snr": "snr",
    "isi_viol": "isi_violation",
    "n_spikes": "n_spikes",
    "presence_ratio": "presence_ratio",
    "amplitude": "amplitude",
    "cluster_id": "cluster_id",
}


# --------------------------------------------------------------------------- #
#  .mat loading (normalises scipy's mat_struct / object arrays)
# --------------------------------------------------------------------------- #
def loadMat(path):
    """Load a -v7 .mat, converting mat_struct -> dict and object arrays -> list."""
    def structToDict(matStruct):
        return {name: normValue(getattr(matStruct, name)) for name in matStruct._fieldnames}

    def normValue(value):
        if isinstance(value, spio.matlab.mat_struct):
            return structToDict(value)
        if isinstance(value, np.ndarray) and value.dtype == object:
            return [normValue(x) for x in value]
        return value

    loaded = spio.loadmat(path, struct_as_record=False, squeeze_me=True)
    return {key: normValue(value) for key, value in loaded.items() if not key.startswith("__")}


def tableRows(seStruct, name):
    """Return a table's per-trial rows as a list of dicts (a 1-row table squeezes to one
    dict, so normalise to a list)."""
    rows = seStruct["tables"][name]["data"]
    if isinstance(rows, dict):
        return [rows]
    return list(rows)


# --------------------------------------------------------------------------- #
#  value coercion
# --------------------------------------------------------------------------- #
def asText(value, default=""):
    """Coerce a value to text, mapping None / NaN to the default."""
    if isinstance(value, (bytes, bytearray)):
        return value.decode("utf-8", "replace")
    if isinstance(value, str):
        return value
    if value is None:
        return default
    if isinstance(value, float) and np.isnan(value):
        return default
    if isinstance(value, np.ndarray) and value.size == 1:
        return asText(value.reshape(-1)[0], default)
    return str(value)


def asFloat(value, default=np.nan):
    """Coerce a scalar-ish value to float."""
    try:
        arr = np.atleast_1d(value)
        if arr.size == 0:
            return default
        return float(arr.reshape(-1)[0])
    except (TypeError, ValueError):
        return default


def spikeArray(value):
    """One trial's spike times for one unit -> a 1-D float array with NaNs dropped
    (the dump stores an empty/absent trial as a scalar NaN, a single spike as a scalar)."""
    arr = np.atleast_1d(np.asarray(value, dtype=float))
    return arr[~np.isnan(arr)]


def clipSpikes(rel):
    """Keep stim-relative spike times within +/- CLIP_SECONDS (drops inter-trial bleed)."""
    return rel[np.abs(rel) <= CLIP_SECONDS]


def firstNumber(text, default=np.nan):
    match = re.search(r"-?\d+(?:\.\d+)?", str(text))
    if match:
        return float(match.group())
    return default


# --------------------------------------------------------------------------- #
#  session metadata
# --------------------------------------------------------------------------- #
def sessionInfoDict(seStruct):
    info = seStruct.get("userData", {}).get("sessionInfo", {})
    if isinstance(info, list):
        info = info[0] if info else {}
    return info if isinstance(info, dict) else {}


def spikeInfoDict(seStruct):
    info = seStruct.get("userData", {}).get("spikeInfo", {})
    if isinstance(info, list):
        info = info[0] if info else {}
    return info if isinstance(info, dict) else {}


def regionFromRecSite(recSite, override=None):
    """'S1' or 'M1' from the recSite string (e.g. 'Left wS1' -> S1), or the override."""
    if override:
        return override
    text = recSite.lower()
    if "m1" in text:
        return "M1"
    return "S1"


def sessionStartTime(sessInfo, stem):
    """Parse the session date; fall back to the date in the file stem, else 1900-01-01."""
    tzInfo = tz.gettz(TIMEZONE)
    seshDate = asText(sessInfo.get("seshDate"))
    for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):
        try:
            return datetime.strptime(seshDate[:19] if " " in seshDate else seshDate[:10], fmt).replace(tzinfo=tzInfo)
        except ValueError:
            continue
    match = re.search(r"(\d{4})-(\d{2})-(\d{2})", stem)
    if match:
        return datetime(int(match[1]), int(match[2]), int(match[3])).replace(tzinfo=tzInfo)
    return datetime(1900, 1, 1, tzinfo=tzInfo)


def sessionId(stem):
    """'VC030107 2022-11-16a se enriched' -> 'VC030107_2022-11-16a'."""
    cleaned = re.sub(r"\s+se(\s+enriched)?(_struct)?$", "", stem).strip()
    return re.sub(r"\s+", "_", cleaned)


# --------------------------------------------------------------------------- #
#  trials
# --------------------------------------------------------------------------- #
TRIAL_TEXT_FIELDS = ["trialType", "leftStimType", "rightStimType", "blockType"]
TRIAL_NUM_FIELDS = {"response": "response", "result": "result", "bct_trialNum": "bct_trialNum"}
BEHAV_EVENT_FIELDS = ["stimOnset", "rightOnset", "rightOffset", "leftOnset", "leftOffset",
                      "rLickOnset", "lLickOnset", "firstLick", "optoOnset", "optoOffset"]


def addTrials(nwbFile, behavRows, behavTimeRows, referenceTime, adcRows):
    """One NWB trial per behavValue row. start/stop bracket the adc window around each
    trial's referenceTime; stim/behav event onsets are stored relative to stim (=0)."""
    for field in TRIAL_TEXT_FIELDS:
        nwbFile.add_trial_column(name=field, description=f"behavValue field '{field}'")
    for column in TRIAL_NUM_FIELDS.values():
        nwbFile.add_trial_column(name=column, description=f"behavValue field '{column}'")
    for field in BEHAV_EVENT_FIELDS:
        nwbFile.add_trial_column(name=field, description=f"behavTime '{field}' (s, relative to stim onset)")
    nwbFile.add_trial_column(name="reference_time", description="absolute time of the trial's stim-onset reference (s)")

    nTrials = len(behavRows)
    for trialInd in range(nTrials):
        row = behavRows[trialInd]
        eventRow = behavTimeRows[trialInd] if trialInd < len(behavTimeRows) else {}
        adcTime = np.atleast_1d(np.asarray(adcRows[trialInd]["time"], dtype=float))
        reference = float(referenceTime[trialInd])
        startTime = reference + float(adcTime[0])
        stopTime = reference + float(adcTime[-1])

        kwargs = {field: asText(row.get(field)) for field in TRIAL_TEXT_FIELDS}
        for srcName, column in TRIAL_NUM_FIELDS.items():
            kwargs[column] = asFloat(row.get(srcName))
        for field in BEHAV_EVENT_FIELDS:
            kwargs[field] = asFloat(eventRow.get(field)) if eventRow else np.nan
        kwargs["reference_time"] = reference
        nwbFile.add_trial(start_time=startTime, stop_time=stopTime, **kwargs)


# --------------------------------------------------------------------------- #
#  electrodes
# --------------------------------------------------------------------------- #
def findChannelMap(sessInfo, spikeInfo):
    """Return (channelNumbers, xcoords, ycoords, connected) from whichever field holds the
    channel-map struct -- 'chanmap' for Neuropixels sessions, 'channel_map' for the H3
    probe -- falling back to spikeInfo.channel_map (channel numbers, no positions)."""
    for key in ("chanmap", "channel_map"):
        chanMapInfo = sessInfo.get(key)
        if isinstance(chanMapInfo, list):
            chanMapInfo = chanMapInfo[0] if chanMapInfo else None
        if isinstance(chanMapInfo, dict) and "chanMap" in chanMapInfo:
            channels = np.atleast_1d(np.asarray(chanMapInfo.get("chanMap", []), dtype=float))
            if channels.size:
                return (channels.astype(int),
                        np.atleast_1d(np.asarray(chanMapInfo.get("xcoords", []), dtype=float)),
                        np.atleast_1d(np.asarray(chanMapInfo.get("ycoords", []), dtype=float)),
                        np.atleast_1d(np.asarray(chanMapInfo.get("connected", []), dtype=float)))
    # Fallback: a plain channel-number list with unknown positions.
    channels = np.atleast_1d(np.asarray(spikeInfo.get("channel_map", []), dtype=float))
    if channels.size:
        return channels.astype(int), np.array([]), np.array([]), np.array([])
    return np.array([], dtype=int), np.array([]), np.array([]), np.array([])


def addElectrodes(nwbFile, sessInfo, spikeInfo, recSite, probeName):
    """Add the probe's channel map as electrodes; return {channel_number: electrode_row},
    or {} when no channel map is available (units then carry no electrode link)."""
    channelNumbers, xCoords, yCoords, connected = findChannelMap(sessInfo, spikeInfo)
    if channelNumbers.size == 0:
        return {}

    device = nwbFile.create_device(name="probe", description=f"silicon probe {probeName}")
    electrodeGroup = nwbFile.create_electrode_group(
        name="probe_shank", description=f"{probeName} recording {recSite}", device=device, location=recSite)

    # Declare the custom columns only now (with rows to follow), so their dtype resolves.
    nwbFile.add_electrode_column(name="channel_number", description="probe channel number (chanMap)")
    nwbFile.add_electrode_column(name="is_connected", description="whether the channel was connected/used")

    channelToRow = {}
    for row, channelNumber in enumerate(channelNumbers):
        relX = float(xCoords[row]) if row < len(xCoords) else np.nan
        relY = float(yCoords[row]) if row < len(yCoords) else np.nan
        nwbFile.add_electrode(
            x=np.nan, y=np.nan, z=np.nan, imp=np.nan, location=recSite, filtering="unknown",
            group=electrodeGroup, rel_x=relX, rel_y=relY,
            channel_number=int(channelNumber),
            is_connected=bool(connected[row]) if row < len(connected) else True)
        channelToRow[int(channelNumber)] = row
    return channelToRow


# --------------------------------------------------------------------------- #
#  units
# --------------------------------------------------------------------------- #
def addUnits(nwbFile, seStruct, referenceTime, channelToRow):
    """Add one Unit per column of the spikeTime table: spike times shifted into absolute
    session time, per-trial obs_intervals, waveform_mean, and quality-metric columns."""
    spikeRows = tableRows(seStruct, "spikeTime")
    unitNames = [k for k in spikeRows[0].keys()]
    nTrials = len(spikeRows)

    spikeInfo = spikeInfoDict(seStruct)
    qualityMetrics = spikeInfo.get("quality_metrics", [])
    if isinstance(qualityMetrics, dict):
        qualityMetrics = [qualityMetrics]
    unitChannel = np.atleast_1d(np.asarray(spikeInfo.get("unit_channel_ind", []), dtype=float)).astype(int)
    meanWaveform = np.atleast_2d(np.asarray(spikeInfo.get("unit_mean_waveform", []), dtype=float))  # (samples, units)

    # Link units to electrodes only if EVERY unit's channel is in the map (a units column
    # must be present for all rows or none).
    unitChannels = [int(unitChannel[i]) if i < len(unitChannel) else -1 for i in range(len(unitNames))]
    includeElectrodes = bool(channelToRow) and all(ch in channelToRow for ch in unitChannels)

    # Per-trial observation windows (spikes only exist within trials; clip the bleed).
    obsIntervals = []
    for trialInd in range(nTrials):
        trialSpikes = [clipSpikes(spikeArray(spikeRows[trialInd][u])) for u in unitNames]
        allRel = np.concatenate([s for s in trialSpikes if s.size]) if any(s.size for s in trialSpikes) else np.array([0.0])
        obsIntervals.append([float(referenceTime[trialInd] + allRel.min() - 0.001),
                             float(referenceTime[trialInd] + allRel.max() + 0.001)])

    # Declare the custom unit columns.
    nwbFile.add_unit_column(name="unit_name", description="spikeTime table column name")
    nwbFile.add_unit_column(name="unit_channel", description="peak channel index (unit_channel_ind)")
    nwbFile.add_unit_column(name="ks_label", description="Kilosort label (good/mua)")
    nwbFile.add_unit_column(name="quality_group", description="curated quality group")
    for column in UNIT_METRIC_COLUMNS.values():
        nwbFile.add_unit_column(name=column, description=f"quality metric '{column}'")

    for unitInd, unitName in enumerate(unitNames):
        # Concatenate this unit's spikes across trials into absolute session time.
        allSpikes = []
        for trialInd in range(nTrials):
            rel = clipSpikes(spikeArray(spikeRows[trialInd][unitName]))
            if rel.size:
                allSpikes.append(rel + float(referenceTime[trialInd]))
        spikeTimes = np.sort(np.concatenate(allSpikes)) if allSpikes else np.array([], dtype=float)

        metricRow = qualityMetrics[unitInd] if unitInd < len(qualityMetrics) else {}
        channel = int(unitChannel[unitInd]) if unitInd < len(unitChannel) else -1

        kwargs = dict(
            spike_times=spikeTimes,
            obs_intervals=obsIntervals,
            unit_name=unitName,
            unit_channel=channel,
            ks_label=asText(metricRow.get("KSLabel")).strip(),
            quality_group=asText(metricRow.get("group")).strip(),
        )
        for srcName, column in UNIT_METRIC_COLUMNS.items():
            kwargs[column] = asFloat(metricRow.get(srcName))
        # Per-unit mean waveform (samples,) if available.
        if meanWaveform.ndim == 2 and unitInd < meanWaveform.shape[1]:
            kwargs["waveform_mean"] = meanWaveform[:, unitInd].astype(float)
        # Link to the electrode row for the unit's channel (consistently across all units).
        if includeElectrodes:
            kwargs["electrodes"] = [channelToRow[channel]]
        nwbFile.add_unit(**kwargs)


# --------------------------------------------------------------------------- #
#  firing rate + stimulus time series
# --------------------------------------------------------------------------- #
def addFiringRate(nwbFile, seStruct, referenceTime):
    """Store the precomputed 2.5 ms spikeRate as one ecephys TimeSeries: data (samples x
    units), timestamps in absolute session time. spikeRate.time is stim-relative (stim at
    0), so absolute time = referenceTime + rateTime; the tail is kept (capped) so trials
    tile the recording and a trial's pre-stim FR comes from the previous trial."""
    rateRows = tableRows(seStruct, "spikeRate")
    unitNames = [k for k in rateRows[0].keys() if k != "time"]
    nTrials = len(rateRows)

    dataBlocks = []
    timestampBlocks = []
    for trialInd in range(nTrials):
        rateTime = np.atleast_1d(np.asarray(rateRows[trialInd]["time"], dtype=float))
        # Keep the trial's full post-stim slice, dropping only the last epoch's long bleed.
        keep = rateTime <= FR_MAX_SECONDS
        if not keep.any():
            continue
        timestamps = float(referenceTime[trialInd]) + rateTime[keep]
        unitColumns = [np.atleast_1d(np.asarray(rateRows[trialInd][u], dtype=float))[keep] for u in unitNames]
        dataBlocks.append(np.column_stack(unitColumns))
        timestampBlocks.append(timestamps)

    data = np.concatenate(dataBlocks, axis=0)
    timestamps = np.concatenate(timestampBlocks)
    order = np.argsort(timestamps)

    firingRate = TimeSeries(
        name="firing_rate",
        data=data[order],
        timestamps=timestamps[order],
        unit="Hz",
        description="precomputed 2.5 ms firing rate per unit (columns follow the Units table order); "
                    "from se.spikeRate, timestamps in absolute session time",
    )
    module = nwbFile.create_processing_module(name="ecephys", description="processed ecephys data")
    module.add(firingRate)


def addStimulus(nwbFile, adcRows, referenceTime):
    """Store the adc piezo command (leftStim, rightStim) as a stimulus TimeSeries, in
    absolute session time (adc.time is stim-relative, so absolute = referenceTime + time)."""
    dataBlocks = []
    timestampBlocks = []
    for trialInd in range(len(adcRows)):
        adcTime = np.atleast_1d(np.asarray(adcRows[trialInd]["time"], dtype=float))
        leftStim = np.atleast_1d(np.asarray(adcRows[trialInd].get("leftStim", []), dtype=float))
        rightStim = np.atleast_1d(np.asarray(adcRows[trialInd].get("rightStim", []), dtype=float))
        nSamples = len(adcTime)
        if len(leftStim) != nSamples or len(rightStim) != nSamples:
            continue
        # Drop the inter-trial bleed (keep +/- CLIP_SECONDS around stim).
        keep = np.abs(adcTime) <= CLIP_SECONDS
        if not keep.any():
            continue
        dataBlocks.append(np.column_stack([leftStim[keep], rightStim[keep]]))
        timestampBlocks.append(float(referenceTime[trialInd]) + adcTime[keep])

    if not dataBlocks:
        return
    data = np.concatenate(dataBlocks, axis=0)
    timestamps = np.concatenate(timestampBlocks)
    order = np.argsort(timestamps)
    stimSeries = TimeSeries(
        name="piezo_stim",
        data=data[order],
        timestamps=timestamps[order],
        unit="V",
        description="piezo command voltage, columns [leftStim, rightStim], absolute session time",
    )
    nwbFile.add_stimulus(stimSeries)


# --------------------------------------------------------------------------- #
#  session_info metadata table
# --------------------------------------------------------------------------- #
SESSION_INFO_FIELDS = ["recSite", "seshType", "APStim", "DVStim", "inhSite", "Manipulation",
                       "probeNames", "penetrationDepth", "histology", "corticaldepth"]


def storeSessionInfo(nwbFile, sessInfo, spikeInfo, region):
    """One-row session_info DynamicTable with the fields the figure port filters on."""
    from pynwb.core import DynamicTable

    present = {}
    for field in SESSION_INFO_FIELDS:
        if field in sessInfo:
            present[field] = asText(sessInfo.get(field))
    present["region"] = region
    present["sample_rate"] = asText(spikeInfo.get("sample_rate"))

    infoTable = DynamicTable(name="session_info", description="session-level ephys metadata from se.userData")
    for field in present:
        infoTable.add_column(name=field, description=field)
    infoTable.add_row(**present)

    if "metadata" in nwbFile.processing:
        module = nwbFile.processing["metadata"]
    else:
        module = nwbFile.create_processing_module(name="metadata", description="session-level task/probe metadata")
    module.add(infoTable)


# --------------------------------------------------------------------------- #
#  per-file conversion
# --------------------------------------------------------------------------- #
def convertFile(structPath, outDir, regionOverride=None, verbose=True):
    structPath = Path(structPath)
    outDir = Path(outDir)
    outDir.mkdir(parents=True, exist_ok=True)

    loaded = loadMat(structPath)
    seStruct = loaded.get("se_struct", loaded)
    for required in ("tables", "referenceTime"):
        if required not in seStruct:
            raise ValueError(f"{structPath.name}: missing '{required}' (dumped by dump_ephys_se_to_struct.m?)")

    sessInfo = sessionInfoDict(seStruct)
    spikeInfo = spikeInfoDict(seStruct)
    referenceTime = np.atleast_1d(np.asarray(seStruct["referenceTime"], dtype=float))
    recSite = asText(sessInfo.get("recSite"))
    region = regionFromRecSite(recSite, regionOverride)
    probeName = asText(sessInfo.get("probeNames"), "probe")

    stem = structPath.stem
    identifier = sessionId(stem)
    behavRows = tableRows(seStruct, "behavValue")
    animalId = asText(sessInfo.get("MouseName")) or asText(behavRows[0].get("mouseName")) or identifier.split("_")[0]

    # NWBFile shell + subject.
    nwbFile = NWBFile(
        session_description=f"{animalId} {identifier} ({region} passive stim)",
        identifier=identifier,
        session_start_time=sessionStartTime(sessInfo, stem),
        experiment_description=f"{STIM_TASK}; recording site {recSite}",
        lab=LAB, institution=INSTITUTION, experimenter=EXPERIMENTER,
        keywords=["somatosensory", "whisker", "electrophysiology", "Neuropixels", region],
        session_id=identifier,
    )
    sexRaw = asText(sessInfo.get("Sex")).lower()
    subjectKwargs = dict(
        subject_id=animalId, species=SPECIES,
        sex={"male": "M", "female": "F", "m": "M", "f": "F"}.get(sexRaw, "U"),
        genotype=asText(sessInfo.get("Genotype")) or "unknown",
        description="no additional description",
    )
    # Date of birth (yymmdd) when the session carries one, so age is defined.
    dobRaw = re.sub(r"\D", "", asText(sessInfo.get("DoB")))
    if len(dobRaw) >= 6:
        try:
            subjectKwargs["date_of_birth"] = datetime.strptime(dobRaw[:6], "%y%m%d").replace(tzinfo=tz.gettz(TIMEZONE))
        except ValueError:
            pass
    nwbFile.subject = Subject(**subjectKwargs)

    # Electrodes -> trials -> units -> firing rate -> stimulus -> session_info.
    channelToRow = addElectrodes(nwbFile, sessInfo, spikeInfo, recSite, probeName)
    behavTimeRows = tableRows(seStruct, "behavTime") if "behavTime" in seStruct["tables"] else []
    adcRows = tableRows(seStruct, "adc")
    addTrials(nwbFile, behavRows, behavTimeRows, referenceTime, adcRows)
    addUnits(nwbFile, seStruct, referenceTime, channelToRow)
    if "spikeRate" in seStruct["tables"]:
        addFiringRate(nwbFile, seStruct, referenceTime)
    addStimulus(nwbFile, adcRows, referenceTime)
    storeSessionInfo(nwbFile, sessInfo, spikeInfo, region)

    outPath = outDir / f"{identifier}.nwb"
    with NWBHDF5IO(outPath, "w") as io:
        io.write(nwbFile)
    if verbose:
        print(f"  wrote {outPath.name}: {len(nwbFile.units)} units, {len(behavRows)} trials, region {region}")
    return outPath


def main(argv=None):
    parser = argparse.ArgumentParser(description="Convert bodyside ephys se_struct .mat -> NWB")
    parser.add_argument("--in-dir", help="folder of *_struct.mat ephys files")
    parser.add_argument("--in-file", help="a single *_struct.mat ephys file")
    parser.add_argument("--out-dir", required=True, help="output folder for .nwb files")
    parser.add_argument("--region", choices=["S1", "M1"], help="override the region (else inferred from recSite)")
    args = parser.parse_args(argv)

    if args.in_file:
        structFiles = [Path(args.in_file)]
    elif args.in_dir:
        structFiles = sorted(p for p in Path(args.in_dir).glob("*.mat") if "struct" in p.stem)
    else:
        parser.error("provide --in-file or --in-dir")

    print(f"Converting {len(structFiles)} ephys file(s) -> {args.out_dir}")
    nOk = 0
    for structFile in structFiles:
        print(f"[{structFile.name}]")
        try:
            convertFile(structFile, args.out_dir, regionOverride=args.region)
            nOk += 1
        except Exception as err:
            print(f"  ERROR: {type(err).__name__}: {err}")
    print(f"\nDone: {nOk}/{len(structFiles)} converted.")
    return 0 if nOk == len(structFiles) else 1


if __name__ == "__main__":
    sys.exit(main())
