"""
convert_bodyside_behavior.py
============================
Convert bodyside *behavior-only* MSessionExplorer (se) sessions to NWB.

Pipeline (you run both steps in order):

  1) MATLAB:  dump_se_to_struct.m  -- turns each `... se.mat` into a Python-friendly
              `... se_struct.mat` (variable name `se_struct`), saved as -v7.
  2) Python:  this script          -- reads those `*_struct.mat` files and writes .nwb.

Why a separate dump step: the se object is a custom MATLAB class, and its userData
holds MATLAB `table` objects and `datetime`s that scipy cannot read. dump_se_to_struct.m
flattens everything to plain structs / strings / numeric arrays first.

This script is deliberately self-contained: the only third-party deps are
    pynwb, nwbinspector, scipy, numpy
(no matlab.engine, no oconnor_lab_to_nwb install required). It follows the same
NWB conventions as the lab's oconnor-lab-to-nwb converter.

Behavior-only sessions have NO acquisition clock (no timeseries, no reference
times), so NWB trial start/stop times are NOMINAL (trial index, in seconds).
Nothing in the behavior figures uses these times; they exist only because NWB
requires monotonically increasing trial times.

Usage
-----
    # convert every *_struct.mat in a folder
    python convert_bodyside_behavior.py --in-dir  "E:\\...\\NWBData\\Conversion\\behav_struct" \
                                        --out-dir "E:\\...\\NWBData\\Data\\behavior"

    # or a single file
    python convert_bodyside_behavior.py --in-file "E:\\...\\VC030109 2023-01-05 a se_struct.mat" \
                                        --out-dir "E:\\...\\NWBData\\Data\\behavior"
"""

from __future__ import annotations

import argparse
import os
import re
import sys
from datetime import datetime, time
from pathlib import Path

import numpy as np
import scipy.io as spio
from dateutil import tz

from pynwb import NWBFile, NWBHDF5IO
from pynwb.file import Subject


# --------------------------------------------------------------------------- #
#  Configuration you may want to edit
# --------------------------------------------------------------------------- #
LAB = "O'Connor lab"
INSTITUTION = "Johns Hopkins University"
EXPERIMENTER = ["Varun Chokshi"]
SPECIES = "Mus musculus"
TIMEZONE = "US/Eastern"
BEHAVIOR_TASK = "whisker-based body-side (left/right) discrimination task"

# response code -> human meaning (documented on the trials column, values kept raw)
RESPONSE_CODES = "0 = miss/no lick, 1 = lick right, 2 = lick left, 3 = abort"
RESULT_CODES = "1 = correct, 0 = incorrect, NaN = no lick / not scored"


# --------------------------------------------------------------------------- #
#  Robust .mat loading (normalises scipy's mat_struct/ndarray output)
# --------------------------------------------------------------------------- #
def loadMat(path):
    """Load a -v7 .mat, converting mat_struct -> dict and struct-arrays -> list."""
    def structToDict(matStruct):
        asDict = {}
        for fieldName in matStruct._fieldnames:
            asDict[fieldName] = normValue(getattr(matStruct, fieldName))
        return asDict

    def normValue(value):
        # Recurse into mat_structs and object arrays; leave plain values alone.
        if isinstance(value, spio.matlab.mat_struct):
            return structToDict(value)
        if isinstance(value, np.ndarray) and value.dtype == object:
            return [normValue(x) for x in value]
        return value

    loaded = spio.loadmat(path, struct_as_record=False, squeeze_me=True)
    return {key: normValue(value) for key, value in loaded.items() if not key.startswith("__")}


def tableRows(tableEntry):
    """Return the list-of-dicts rows for a table entry from se_struct.

    dump_se_to_struct.m stores each table as struct with fields
    {data, type, refTime}.  `data` is a struct array -> list of dicts, but a
    1-row table squeezes to a single dict, so normalise to a list here.
    """
    rows = tableEntry["data"]
    if isinstance(rows, dict):
        return [rows]
    return list(rows)


# --------------------------------------------------------------------------- #
#  Value coercion for trial-table cells
# --------------------------------------------------------------------------- #
def unwrapScalar(value):
    """Unwrap a 1-element ndarray/list to its scalar; leave others as-is."""
    if isinstance(value, np.ndarray):
        if value.size == 1:
            return value.reshape(-1)[0]
        return value
    if isinstance(value, (list, tuple)) and len(value) == 1:
        return value[0]
    return value


def coerceCell(value):
    """Coerce one behavValue field to a value NWB can store in a column."""
    value = unwrapScalar(value)
    if value is None:
        return np.nan
    if isinstance(value, (bytes, bytearray)):
        return value.decode("utf-8", "replace")
    if isinstance(value, str):
        return value
    if isinstance(value, np.ndarray):
        if value.size == 0:
            return np.nan
        return np.array2string(value, threshold=64)
    if isinstance(value, (list, tuple)):
        return str(value)
    # numeric / logical scalar
    try:
        return float(value)
    except (TypeError, ValueError):
        return str(value)


def asText(value, default=""):
    """Coerce a value to text, mapping None / NaN to the default."""
    value = unwrapScalar(value)
    if isinstance(value, (bytes, bytearray)):
        return value.decode("utf-8", "replace")
    if isinstance(value, str):
        return value
    if value is None:
        return default
    if isinstance(value, float) and np.isnan(value):
        return default
    return str(value)


def bctTaskParams(userData):
    """Pull the session-level Bcontrol task params that Fig1 (getPerfOverall)
    uses to filter sessions, from userData.bctData."""
    bctData = userData.get("bctData", {}) if isinstance(userData, dict) else {}
    if not isinstance(bctData, dict):
        return {}
    params = {}
    # The first bctData key encodes the task name (e.g. 'bodyside6obj_...').
    bctKeys = list(bctData.keys())
    if bctKeys:
        params["taskName"] = bctKeys[0][:9]
    # Side-assist is stored as text ('No' -> off).
    sideAssist = asText(bctData.get("TrialTypeSection_SideAssist"))
    if sideAssist:
        params["sideAssist"] = "0" if sideAssist == "No" else "1"
    # The remaining task params are carried through as text when present.
    for srcKey, dstKey in [
        ("TrialTypeSection_LeftTrialProb", "leftTrialProb"),
        ("TrialTypeSection_MaskingFlash", "maskingFlash"),
        ("TrialTypeSection_PreStimNoLickTime", "preStimNoLickTime"),
        ("TrialTypeSection_CatchTrialProb", "catchTrialProb"),
        ("TrialTypeSection_OptoProb", "optoProb"),
    ]:
        if srcKey in bctData:
            text = asText(bctData.get(srcKey))
            if text:
                params[dstKey] = text
    return params


# --------------------------------------------------------------------------- #
#  Metadata derivation (robust; sessionInfo used only if present)
# --------------------------------------------------------------------------- #
def genotypeFromAnimal(animalId):
    """Bodyside convention: VC0301x = WT, VC0302x = KO (6th char of the ID)."""
    if len(animalId) >= 6:
        sixthChar = animalId[5]
        if sixthChar == "1":
            return "WT"
        if sixthChar == "2":
            return "KO"
    return "unknown"


def sessionDateFromStem(stem):
    """Pull an ISO date (YYYY-MM-DD) out of the file stem if present."""
    match = re.search(r"(\d{4})-(\d{2})-(\d{2})", stem)
    if match:
        return datetime(int(match[1]), int(match[2]), int(match[3]))
    return None


def loadAnimalInfo(path):
    """Build {ANIMAL_ID: {DoB, Sex, Genotype}} from the SessInfoNoOpto CSVs
    (a folder of *_sessioninfo.csv) or a single CSV. Used to fill subject
    metadata for learning sessions whose se has an empty sessionInfo."""
    import csv
    import glob

    animalInfo = {}
    if not path:
        return animalInfo
    # Accept either a folder of CSVs or a single CSV path.
    if os.path.isdir(path):
        csvPaths = sorted(glob.glob(os.path.join(path, "*.csv")))
    elif str(path).lower().endswith(".csv"):
        csvPaths = [path]
    else:
        csvPaths = []
    # First occurrence of each animal wins.
    for csvPath in csvPaths:
        try:
            with open(csvPath, newline="", encoding="utf-8-sig") as csvFile:
                for row in csv.DictReader(csvFile):
                    animalId = (row.get("MouseName") or "").strip().upper()
                    if animalId and animalId not in animalInfo:
                        animalInfo[animalId] = {
                            "DoB": (row.get("DoB") or "").strip(),
                            "Sex": (row.get("Sex") or "").strip(),
                            "Genotype": (row.get("Genotype") or "").strip(),
                        }
        except Exception as err:
            print(f"  (could not read animal info {os.path.basename(csvPath)}: {err})")
    return animalInfo


def deriveMetadata(seStruct, stem, animalInfo=None):
    """Derive subject / session metadata from the behavValue table, sessionInfo,
    the animal-info CSVs, and the file stem (in that order of preference)."""
    tzInfo = tz.gettz(TIMEZONE)
    behavRows = tableRows(seStruct["tables"]["behavValue"])
    firstRow = behavRows[0] if behavRows else {}
    sessInfo = seStruct.get("userData", {})
    if isinstance(sessInfo, dict):
        sessInfo = sessInfo.get("sessionInfo", {}) or {}
    if not isinstance(sessInfo, dict):
        sessInfo = {}

    animalId = asText(firstRow.get("mouseName")) or stem.split()[0]
    animalRow = (animalInfo or {}).get(animalId.upper(), {}) if animalId else {}

    # --- session start time -------------------------------------------------
    startDt = None
    seshDate = asText(sessInfo.get("seshDate"))               # yymmdd (if present)
    seshTime = asText(sessInfo.get("session_start_time"))     # hhmmss (if present)
    if seshDate and seshTime:
        try:
            startDt = datetime.strptime(seshDate[:6] + " " + seshTime, "%y%m%d %H%M%S")
        except ValueError:
            startDt = None
    if startDt is None:
        stemDate = sessionDateFromStem(stem)
        startDt = datetime.combine(stemDate.date(), time(0, 0)) if stemDate else datetime(1900, 1, 1)
    startDt = startDt.replace(tzinfo=tzInfo)

    # --- genotype (behavValue > sessionInfo > animal-info CSV > ID convention)
    genotype = (asText(firstRow.get("Genotype")) or asText(sessInfo.get("Genotype"))
                or asText(animalRow.get("Genotype")) or genotypeFromAnimal(animalId))

    # --- sex (sessionInfo > animal-info CSV) --------------------------------
    sexRaw = asText(sessInfo.get("Sex") or sessInfo.get("sex") or animalRow.get("Sex")).lower()
    sex = {"male": "M", "female": "F", "m": "M", "f": "F"}.get(sexRaw, "U")

    # --- date of birth (sessionInfo > animal-info CSV) ----------------------
    dob = None
    dobRaw = asText(sessInfo.get("DoB")) or asText(animalRow.get("DoB"))
    if dobRaw:
        try:
            dob = datetime.strptime(dobRaw[:6], "%y%m%d").replace(tzinfo=tzInfo)
        except ValueError:
            dob = None

    # --- opto / inhibition note --------------------------------------------
    inhSite = asText(firstRow.get("inhSite"))
    isInh = unwrapScalar(firstRow.get("isInhibition"))
    isInh = bool(isInh) if not (isinstance(isInh, float) and np.isnan(isInh)) else False

    expDesc = f"Behavior-only session of the {BEHAVIOR_TASK}."
    if isInh and inhSite:
        expDesc += f" Optogenetic inhibition of {inhSite} on a subset of trials."

    return dict(
        animal_id=animalId,
        session_start_time=startDt,
        genotype=genotype,
        sex=sex,
        date_of_birth=dob,
        experiment_description=expDesc,
        session_info=sessInfo,
    )


# --------------------------------------------------------------------------- #
#  Trials
# --------------------------------------------------------------------------- #
# Fields carried per-trial that are actually constant per session (skip as
# trial columns -- they live in session/subject metadata instead).
SKIP_TRIAL_FIELDS = {"mouseName", "sessDate"}

COLUMN_DOC = {
    "bct_trialNum": "Bcontrol trial number",
    "trialType": "Bcontrol trial type (e.g. Stim_Som_Right / Stim_Som_Left [_Opto/_NoCue])",
    "response": f"Animal response code: {RESPONSE_CODES}",
    "result": f"Trial outcome: {RESULT_CODES}",
    "leftStimType": "Left piezo stimulus descriptor string",
    "rightStimType": "Right piezo stimulus descriptor string",
    "blockType": "Block type (e.g. 2piezos)",
    "inhSite": "Optogenetic inhibition site (opto sessions only)",
    "Genotype": "Animal genotype (WT/KO)",
    "isInhibition": "1 if the session included optogenetic inhibition trials",
}


def addBehaviorTrials(nwbFile, behavRows):
    """Add one NWB trial per behavValue row. Nominal (index) times."""
    # Determine the column order from the first row, preserving se field order.
    fields = [fieldName for fieldName in behavRows[0].keys() if fieldName not in SKIP_TRIAL_FIELDS]

    # Declare each trial column once, with its documentation string.
    for fieldName in fields:
        nwbFile.add_trial_column(name=fieldName, description=COLUMN_DOC.get(fieldName, f"behavValue field '{fieldName}'"))

    # One trial per row; start/stop times are the trial index (nominal).
    for trialInd, row in enumerate(behavRows):
        trialKwargs = {fieldName: coerceCell(row.get(fieldName)) for fieldName in fields}
        nwbFile.add_trial(start_time=float(trialInd), stop_time=float(trialInd + 1), **trialKwargs)

    return fields


# Session-level metadata carried in userData.sessionInfo (mirrors the
# SessInfoNoOpto CSV columns). Stored so figure code can reproduce trial
# selection (`trialMap`) and task/site filtering (`seshType`, etc.).
SESSION_INFO_FIELDS = [
    "MouseName", "subId", "seshDate", "seshType", "recSite", "inhSite",
    "Manipulation", "probeNames", "trialMap", "Injection", "Genotype", "Sex", "DoB",
]

SESSION_INFO_DOC = {
    "seshType": "task name (e.g. bodyside6); Fig1 keeps only bodyside6 sessions",
    "trialMap": "trial-selection range applied before analysis, e.g. '50:350' or '20:end' "
                "(1-based, inclusive; 'end' = last trial)",
    "recSite": "recording site (NA for behavior-only)",
    "inhSite": "optogenetic inhibition site (NA for no-opto sessions)",
    "Manipulation": "experimental manipulation label",
    "probeNames": "probe names (NA for behavior-only)",
    "Injection": "injection label",
    "subId": "sub-session id (e.g. 'a')",
    "seshDate": "session date, yymmdd",
    # derived from bctData (Fig1 getPerfOverall session filters)
    "taskName": "Bcontrol task name (e.g. bodyside6); Fig1 keeps only bodyside6",
    "sideAssist": "1 if side-assist was on (Fig1 learning excludes these sessions)",
    "leftTrialProb": "left-trial probability; Fig1 learning excludes 0 or 1",
    "maskingFlash": "masking-flash setting",
    "preStimNoLickTime": "pre-stim no-lick time (s)",
    "catchTrialProb": "catch-trial probability",
    "optoProb": "opto probability",
}


def storeSessionInfo(nwbFile, userData):
    """Store session-level metadata as a 1-row DynamicTable in a 'metadata'
    processing module (natively readable by pynwb and matnwb). Combines
    sessionInfo (CSV) fields with the bctData task params Fig1 filters on."""
    from pynwb.core import DynamicTable

    sessInfo = userData.get("sessionInfo", {}) if isinstance(userData, dict) else {}
    if not isinstance(sessInfo, dict):
        sessInfo = {}

    # Carry through the sessionInfo fields that are present.
    presentFields = {}
    for key in SESSION_INFO_FIELDS:
        if key in sessInfo:
            presentFields[key] = asText(sessInfo.get(key))

    # Add the bctData task params; prefer sessionInfo.seshType for the task name.
    bctParams = bctTaskParams(userData)
    taskName = presentFields.get("seshType") or bctParams.get("taskName")
    if taskName:
        presentFields["taskName"] = taskName
    for key, value in bctParams.items():
        if key != "taskName":
            presentFields[key] = value

    if not presentFields:
        return None

    # Build the one-row table and attach it to the 'metadata' processing module.
    infoTable = DynamicTable(
        name="session_info",
        description="Session-level metadata from se.userData.sessionInfo "
                    "(bodyside SessInfoNoOpto columns).",
    )
    for key in presentFields:
        infoTable.add_column(name=key, description=SESSION_INFO_DOC.get(key, key))
    infoTable.add_row(**presentFields)

    if "metadata" in nwbFile.processing:
        procModule = nwbFile.processing["metadata"]
    else:
        procModule = nwbFile.create_processing_module(
            name="metadata", description="session-level task/animal metadata")
    procModule.add(infoTable)
    return presentFields


# --------------------------------------------------------------------------- #
#  Per-file conversion
# --------------------------------------------------------------------------- #
def sessionIdFromStem(stem):
    # 'VC030109 2023-01-05 a se' -> 'VC030109_2023-01-05_a'
    cleaned = re.sub(r"\s+se(_struct)?$", "", stem).strip()
    return re.sub(r"\s+", "_", cleaned)


def convertFile(structPath, outDir, verbose=True, animalInfo=None):
    """Convert one *_struct.mat behavior file to a single .nwb file."""
    structPath = Path(structPath)
    outDir = Path(outDir)
    outDir.mkdir(parents=True, exist_ok=True)

    # Load the dumped struct and confirm it is a behavior session.
    seStruct = loadMat(structPath)
    if "se_struct" in seStruct:
        seStruct = seStruct["se_struct"]
    if "tables" not in seStruct or "behavValue" not in seStruct["tables"]:
        raise ValueError(f"{structPath.name}: no 'behavValue' table found "
                         f"(is this a behavior session dumped by dump_se_to_struct.m?)")

    stem = structPath.stem
    sessionId = sessionIdFromStem(stem)
    meta = deriveMetadata(seStruct, stem, animalInfo)

    if verbose:
        # Surface sessionInfo keys so we can enrich metadata later if useful.
        sessInfo = meta["session_info"]
        print(f"  sessionInfo fields: {sorted(sessInfo.keys()) if sessInfo else '(none)'}")

    # Build the NWBFile shell.
    nwbFile = NWBFile(
        session_description=f"{meta['animal_id']} {sessionId}",
        identifier=sessionId,
        session_start_time=meta["session_start_time"],
        experiment_description=meta["experiment_description"],
        lab=LAB,
        institution=INSTITUTION,
        experimenter=EXPERIMENTER,
        keywords=["somatosensory", "whisker", "decision-making", "behavior", "mouse"],
        session_id=sessionId,
    )

    # Attach the subject (date_of_birth only when we could resolve one).
    subjectKwargs = dict(
        subject_id=meta["animal_id"],
        species=SPECIES,
        sex=meta["sex"],
        genotype=meta["genotype"],
        description="no additional description",
    )
    if meta["date_of_birth"] is not None:
        subjectKwargs["date_of_birth"] = meta["date_of_birth"]
    nwbFile.subject = Subject(**subjectKwargs)

    # Add the trials table and the session_info metadata table.
    behavRows = tableRows(seStruct["tables"]["behavValue"])
    fields = addBehaviorTrials(nwbFile, behavRows)

    storedFields = storeSessionInfo(nwbFile, seStruct.get("userData", {}))
    if verbose and storedFields:
        trialMap = storedFields.get("trialMap", "(none)")
        print(f"  session_info stored: taskName={storedFields.get('taskName')}, "
              f"trialMap={trialMap}, sideAssist={storedFields.get('sideAssist')}, "
              f"leftTrialProb={storedFields.get('leftTrialProb')}")

    # Write the NWB file.
    outPath = outDir / f"{sessionId}.nwb"
    with NWBHDF5IO(outPath, "w") as io:
        io.write(nwbFile)

    if verbose:
        print(f"  wrote {outPath.name}: {len(behavRows)} trials, columns {fields}")
    return outPath


def inspectFile(nwbPath):
    """Run nwbinspector; print any best-practice violations."""
    try:
        from nwbinspector import inspect_nwbfile, Importance
        from nwbinspector.inspector_tools import format_messages
    except Exception:  # pragma: no cover - optional
        try:
            from nwbinspector import inspect_nwb as inspect_nwbfile, Importance
            from nwbinspector.inspector_tools import format_messages
        except Exception:
            print("  (nwbinspector not available; skipping validation)")
            return
    try:
        messages = list(inspect_nwbfile(nwbfile_path=str(nwbPath),
                                        importance_threshold=Importance.BEST_PRACTICE_VIOLATION))
    except TypeError:
        messages = list(inspect_nwbfile(str(nwbPath)))
    if not messages:
        print("  nwbinspector: no violations")
    else:
        print("\n".join(format_messages(messages, levels=["importance", "file_path"])))


# --------------------------------------------------------------------------- #
#  CLI
# --------------------------------------------------------------------------- #
def main(argv=None):
    parser = argparse.ArgumentParser(description="Convert bodyside behavior se_struct .mat -> NWB")
    parser.add_argument("--in-dir", help="folder of *_struct.mat behavior files")
    parser.add_argument("--in-file", help="a single *_struct.mat behavior file")
    parser.add_argument("--out-dir", required=True, help="output folder for .nwb files")
    parser.add_argument("--animal-info", help="SessInfoNoOpto folder (or a CSV) providing "
                        "per-animal DOB/sex/genotype; fills metadata for learning sessions "
                        "whose se has an empty sessionInfo")
    parser.add_argument("--no-inspect", action="store_true", help="skip nwbinspector")
    args = parser.parse_args(argv)

    animalInfo = loadAnimalInfo(args.animal_info)
    if args.animal_info:
        print(f"Loaded animal info for {len(animalInfo)} animals from {args.animal_info}")

    # Resolve the list of struct files to convert.
    if args.in_file:
        structFiles = [Path(args.in_file)]
    elif args.in_dir:
        structFiles = sorted(p for p in Path(args.in_dir).glob("*.mat") if "struct" in p.stem)
        if not structFiles:
            structFiles = sorted(Path(args.in_dir).glob("*.mat"))
    else:
        parser.error("provide --in-file or --in-dir")

    # Convert each file, keeping going through the batch on individual errors.
    print(f"Converting {len(structFiles)} file(s) -> {args.out_dir}")
    nOk = 0
    for structFile in structFiles:
        print(f"[{structFile.name}]")
        try:
            outPath = convertFile(structFile, args.out_dir, animalInfo=animalInfo)
            if not args.no_inspect:
                inspectFile(outPath)
            nOk += 1
        except Exception as err:
            print(f"  ERROR: {type(err).__name__}: {err}")
    print(f"\nDone: {nOk}/{len(structFiles)} converted.")
    return 0 if nOk == len(structFiles) else 1


if __name__ == "__main__":
    sys.exit(main())
