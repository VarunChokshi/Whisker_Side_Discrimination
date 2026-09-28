"""
fig3_tables_nwb.py
==================
Accumulation stage for the Figure 3 / S3 / S4 pipeline, reading NWB.

Reads every NWB in a region folder once and writes the accumulated tables that
the figure ports consume, mirroring GetComposite / GetFRData / AddMeanFRData but
in a single tidy, both-language artifact:

  * one row per (session, frequency, unit) with the session/unit metadata, the
    per-window pvalBoth / pvalContra / pvalIpsi / cbias, and the per-unit mean
    contra/ipsi firing-rate traces with their across-trial 95% confidence bands.

Outputs (into --out-dir):
  fig3_tables_<region>.mat   scalar columns (struct of arrays) + trace matrices
                             (contraMean/ipsiMean/contra/ipsi CI lo/hi, nRows x nBins)
                             + frTime (1 x nBins). Readable by scipy and MATLAB.
  fig3_unit_table_<region>.csv   the scalar columns only, for inspection / diffing.

Row i of the CSV and of every trace matrix in the .mat correspond to the same
(session, frequency, unit).

Run:
  python fig3_tables_nwb.py --region-dir <folder of NWBs> --region S1 --out-dir <folder>

Deps: pynwb, numpy, scipy
"""
from __future__ import annotations

import argparse
import csv
from pathlib import Path

import numpy as np
from scipy import stats
from scipy.io import savemat

import fig3_analysis_nwb as core

# Scalar (non-window) columns, in order.
META_COLUMNS = ["animal", "genotype", "session", "recSite", "region", "freq", "unit",
                "depthRaw", "depthNorm", "ksLabel", "nContraTrials", "nIpsiTrials"]
# Per-window statistic columns are META + <stat>_<window> for these stats.
WINDOW_STATS = ["pvalBoth", "pvalContra", "pvalIpsi", "cbias"]


def traceMeanCI(traceMatrix, alpha=0.05):
    """Across-trial mean and two-sided (1-alpha) t CI for a (nTrials, nBins) matrix,
    matching MMath.MeanStats. Returns (mean, ciLower, ciUpper), each length nBins."""
    data = np.asarray(traceMatrix, dtype=float)
    if data.ndim == 1:
        data = data[None, :]
    nTrials = data.shape[0]
    mean = data.mean(axis=0)
    if nTrials < 2:
        return mean, mean.copy(), mean.copy()
    sd = data.std(axis=0, ddof=1)
    se = sd / np.sqrt(nTrials)
    tCrit = stats.t.ppf(1.0 - alpha / 2.0, nTrials - 1)
    return mean, mean - tCrit * se, mean + tCrit * se


def buildRegionTable(regionDir, region):
    """Read every NWB in regionDir and return the tidy table as a dict of columns
    plus the aligned trace matrices."""
    records = core.loadRegion(regionDir)
    nRows = len(records)
    nBins = len(core.BINS)

    # scalar columns
    columns = {name: [] for name in META_COLUMNS}
    for windowName in core.WINDOW_NAMES:
        for stat in WINDOW_STATS:
            columns[f"{stat}_{windowName}"] = []

    # trace matrices (nRows x nBins)
    contraMean = np.zeros((nRows, nBins))
    ipsiMean = np.zeros((nRows, nBins))
    contraCILo = np.zeros((nRows, nBins))
    contraCIHi = np.zeros((nRows, nBins))
    ipsiCILo = np.zeros((nRows, nBins))
    ipsiCIHi = np.zeros((nRows, nBins))

    for rowInd, record in enumerate(records):
        columns["animal"].append(record["animal"])
        columns["genotype"].append(record["genotype"])
        columns["session"].append(record["session"])
        columns["recSite"].append(record["recSite"])
        columns["region"].append(region)
        columns["freq"].append(record["freq"])
        columns["unit"].append(int(record["unit"]) + 1)          # 1-based unit id
        columns["depthRaw"].append(float(record["depthRaw"]))
        columns["depthNorm"].append(float(record["depthNorm"]))
        columns["ksLabel"].append(record["ksLabel"])
        columns["nContraTrials"].append(int(len(record["spikesContra"])))
        columns["nIpsiTrials"].append(int(len(record["spikesIpsi"])))
        for windowName in core.WINDOW_NAMES:
            windowStats = record["perWindow"][windowName]
            columns[f"pvalBoth_{windowName}"].append(float(windowStats["pvalBoth"]))
            columns[f"pvalContra_{windowName}"].append(float(windowStats["pvalContra"]))
            columns[f"pvalIpsi_{windowName}"].append(float(windowStats["pvalIpsi"]))
            columns[f"cbias_{windowName}"].append(float(windowStats["cbias"]))

        cMean, cLo, cHi = traceMeanCI(record["frContra"])
        iMean, iLo, iHi = traceMeanCI(record["frIpsi"])
        contraMean[rowInd] = cMean
        contraCILo[rowInd] = cLo
        contraCIHi[rowInd] = cHi
        ipsiMean[rowInd] = iMean
        ipsiCILo[rowInd] = iLo
        ipsiCIHi[rowInd] = iHi

    traces = dict(frTime=core.BINS.astype(float), contraMean=contraMean, ipsiMean=ipsiMean,
                  contraCILo=contraCILo, contraCIHi=contraCIHi,
                  ipsiCILo=ipsiCILo, ipsiCIHi=ipsiCIHi)
    return columns, traces, nRows


def writeCsv(columns, nRows, csvPath):
    """Write the scalar columns as a CSV (one row per (session, freq, unit))."""
    header = list(columns.keys())
    with open(csvPath, "w", newline="") as handle:
        writer = csv.writer(handle)
        writer.writerow(header)
        for rowInd in range(nRows):
            writer.writerow([columns[name][rowInd] for name in header])


def writeMat(columns, traces, matPath):
    """Write the tidy table (scalar columns + trace matrices + frTime) as a .mat
    that both scipy and MATLAB read. String columns become cell arrays of char."""
    matDict = {}
    for name, values in columns.items():
        if values and isinstance(values[0], str):
            matDict[name] = np.array(values, dtype=object)
        else:
            matDict[name] = np.asarray(values)
    matDict.update(traces)
    savemat(str(matPath), {"fig3Table": matDict}, do_compression=True)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Accumulate Figure 3 tables from NWB.")
    parser.add_argument("--region-dir", required=True, help="folder of ephys NWB files")
    parser.add_argument("--region", required=True, help="region label, e.g. S1 or M1")
    parser.add_argument("--out-dir", required=True,
                        help="folder to write the tables into (must be under NWBData)")
    parser.add_argument("--force", action="store_true",
                        help="allow writing outside an NWBData folder (off by default)")
    args = parser.parse_args(argv)

    if "nwbdata" not in str(args.out_dir).lower() and not args.force:
        parser.error(f"refusing to write to '{args.out_dir}' (not under an NWBData folder). "
                     f"Use e.g. ...\\NWBData\\Data\\Tables, or pass --force to override.")

    outDir = Path(args.out_dir)
    outDir.mkdir(parents=True, exist_ok=True)

    print(f"accumulating {args.region} tables from {args.region_dir}")
    columns, traces, nRows = buildRegionTable(args.region_dir, args.region)
    csvPath = outDir / f"fig3_unit_table_{args.region}.csv"
    matPath = outDir / f"fig3_tables_{args.region}.mat"
    writeCsv(columns, nRows, csvPath)
    writeMat(columns, traces, matPath)
    print(f"wrote {nRows} rows -> {csvPath.name}, {matPath.name}")


if __name__ == "__main__":
    main()
