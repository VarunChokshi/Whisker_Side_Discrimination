"""
fig3_panels_nwb.py
==================
Figure 3 manuscript panels (passive-stim S1 ephys), ported to read NWB.

Reproduces the three headline Figure 3 panels that the original
Fig3_BS_plotallunits_stim_Raster_bodyside8_S1_allWins.m builds from the
accumulated tables:

  * plotAvgTracesFRFinal  -> population mean contra/ipsi firing-rate traces,
                             WT (top row) vs KO (bottom row), one column per
                             stimulus frequency (10/20/40 Hz).
  * makeCbiasFiguresFinal -> laterality-index (contra-bias) histograms and the
                             per-session percent-contra-preferring histograms.
  * frHeatmapsAllFreq     -> per-unit contra/ipsi firing-rate heatmaps, sorted
                             by responsive identity then contra-bias.

Responsive units, the significance rule, the per-frequency contra-bias windows
and the statistics all mirror the original exactly (see the notes on each
function). Everything is computed from the per-(session, frequency, unit)
records produced by fig3_analysis_nwb.unitRecords.

Run:
  python fig3_panels_nwb.py --s1-dir <folder of S1 NWBs> --out-dir <figure out>

Deps: pynwb, numpy, scipy, matplotlib
"""
from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path

import numpy as np

import fig3_analysis_nwb as core


# --------------------------------------------------------------------------- #
#  ops (mirrors the original driver block)
# --------------------------------------------------------------------------- #
PLOT_ALPHA = 0.01                       # ops.plotAlpha for the Final panels
SIG_WINDOW = "150"                      # responsive units: 20 Hz, 150 ms window
STIM_SLOTS = ["10", "20", "40"]         # frequency columns used by Figure 3
STIM_NAMES = ["10 Hz", "20 Hz", "40 Hz"]
SIG_FREQ = "20"                         # significance is driven by the 20 Hz response
CBIAS_FIRST_CYCLE_WINDOW = {"10": "100", "20": "50", "40": "25"}  # cBiasWin = [5 3 1]
PLOT_XLIMS = (-0.05, 0.05)              # ops.plotxLims
MAX_FR = 30.0                           # maxFR for the average-trace panels
CBIAS_CONTRA = 0.33                     # contra-preferring threshold
CBIAS_IPSI = -0.33                      # ipsi-preferring threshold
MIN_UNITS = 1                           # a session contributes if it has > minUnits units


# --------------------------------------------------------------------------- #
#  small statistics helpers
# --------------------------------------------------------------------------- #
def meanCI(values, alpha=0.05):
    """Column-wise mean and two-sided (1-alpha) t confidence interval, matching
    MMath.MeanStats: returns (mean, ciLower, ciUpper) each of length nColumns.

    values is (nRows, nColumns). NaNs are ignored per column."""
    from scipy import stats

    data = np.asarray(values, dtype=float)
    if data.ndim == 1:
        data = data[None, :]
    n = np.sum(~np.isnan(data), axis=0)
    mean = np.nanmean(data, axis=0)
    sd = np.nanstd(data, axis=0, ddof=1)
    se = np.divide(sd, np.sqrt(n), out=np.zeros_like(sd), where=n > 0)
    tCrit = np.where(n > 1, stats.t.ppf(1.0 - alpha / 2.0, np.maximum(n - 1, 1)), 0.0)
    ciLower = mean - tCrit * se
    ciUpper = mean + tCrit * se
    return mean, ciLower, ciUpper


def pairedTTest(popA, popB, tail):
    """Paired t-test on (popA - popB); tail is 'right' or 'both'. Returns the
    p-value (nan when there are too few paired samples)."""
    from scipy import stats

    a = np.asarray(popA, dtype=float)
    b = np.asarray(popB, dtype=float)
    nPairs = min(len(a), len(b))
    if nPairs < 2:
        return np.nan
    diff = a[:nPairs] - b[:nPairs]
    tStat, pTwoSided = stats.ttest_1samp(diff, 0.0)
    if tail == "both":
        return float(pTwoSided)
    # right-tailed: mean(diff) > 0
    if tStat > 0:
        return float(pTwoSided / 2.0)
    return float(1.0 - pTwoSided / 2.0)


# --------------------------------------------------------------------------- #
#  build the per-unit table from the analysis records
# --------------------------------------------------------------------------- #
def buildUnitTable(records):
    """Collapse the per-(session, frequency, unit) records into one row per
    (session, unit), attaching the per-frequency traces and contra-bias values
    and the single responsive flag (20 Hz, 150 ms window).

    Each row is a dict with:
      genotype, session, animal, recSite, depthRaw, depthNorm, multiFreq,
      responsive (bool),
      slots: {freq -> dict(meanContra, meanIpsi, frContra, frIpsi,
                            cbias150, cbiasFirstCycle, pvalBoth150)}
      frTime: the shared firing-rate time axis (seconds).
    """
    byUnit = defaultdict(dict)
    for record in records:
        byUnit[(record["session"], record["unit"])][record["freq"]] = record

    unitTable = []
    for (session, unit), freqRecords in byUnit.items():
        presentFreqs = sorted(freqRecords.keys())
        multiFreq = len(presentFreqs) > 3

        # significance frequency: 20 Hz for multi-freq, else the single present freq
        if multiFreq:
            sigFreq = SIG_FREQ
        else:
            sigFreq = presentFreqs[0]
        if sigFreq not in freqRecords:
            continue
        reference = freqRecords[sigFreq]
        responsive = reference["perWindow"][SIG_WINDOW]["pvalBoth"] < PLOT_ALPHA

        # per-slot data (only the 10/20/40 Hz slots used by Figure 3)
        slots = {}
        for freq in STIM_SLOTS:
            source = freqRecords.get(freq) if multiFreq else freqRecords.get(sigFreq)
            if source is None:
                continue
            # for a single-frequency (20 Hz) session, only the 20 Hz slot is filled
            if not multiFreq and freq != "20":
                continue
            cbiasWindow = CBIAS_FIRST_CYCLE_WINDOW[freq]
            slots[freq] = dict(
                meanContra=source["frContra"].mean(axis=0),
                meanIpsi=source["frIpsi"].mean(axis=0),
                frContra=source["frContra"],
                frIpsi=source["frIpsi"],
                cbias150=source["perWindow"][SIG_WINDOW]["cbias"],
                cbiasFirstCycle=source["perWindow"][cbiasWindow]["cbias"],
                pvalBoth150=source["perWindow"][SIG_WINDOW]["pvalBoth"],
            )

        unitTable.append(dict(
            genotype=reference["genotype"], session=session, animal=reference["animal"],
            recSite=reference["recSite"], depthRaw=reference["depthRaw"],
            depthNorm=reference["depthNorm"], multiFreq=multiFreq,
            responsive=bool(responsive), slots=slots, frTime=reference["frTime"],
        ))
    return unitTable


def genotypesIn(unitTable):
    """Unique genotypes present, ordered as MATLAB unique() would (alphabetical)."""
    return sorted(set(row["genotype"] for row in unitTable))


def loadFlatTable(matPath):
    """Load the accumulated fig3_tables_<region>.mat and return records compatible
    with buildUnitTable. Each record carries the per-unit mean contra/ipsi trace
    (as a 1-row matrix so buildUnitTable's mean() recovers it) and the per-window
    statistics, so the panels read the saved accumulation instead of re-reading NWB."""
    from scipy.io import loadmat

    table = loadmat(str(matPath), simplify_cells=True)["fig3Table"]
    frTime = np.asarray(table["frTime"], dtype=float)
    nRows = len(np.atleast_1d(table["session"]))

    def column(name):
        return np.atleast_1d(table[name])

    contraMean = np.atleast_2d(table["contraMean"])
    ipsiMean = np.atleast_2d(table["ipsiMean"])
    records = []
    for rowInd in range(nRows):
        perWindow = {}
        for windowName in core.WINDOW_NAMES:
            perWindow[windowName] = dict(
                pvalBoth=float(column(f"pvalBoth_{windowName}")[rowInd]),
                pvalContra=float(column(f"pvalContra_{windowName}")[rowInd]),
                pvalIpsi=float(column(f"pvalIpsi_{windowName}")[rowInd]),
                cbias=float(column(f"cbias_{windowName}")[rowInd]),
            )
        records.append(dict(
            animal=str(column("animal")[rowInd]), genotype=str(column("genotype")[rowInd]),
            recSite=str(column("recSite")[rowInd]), region=str(column("region")[rowInd]),
            session=str(column("session")[rowInd]),
            freq=str(column("freq")[rowInd]), unit=int(column("unit")[rowInd]) - 1,
            depthRaw=float(column("depthRaw")[rowInd]), depthNorm=float(column("depthNorm")[rowInd]),
            ksLabel=str(column("ksLabel")[rowInd]), frTime=frTime,
            frContra=contraMean[rowInd][None, :], frIpsi=ipsiMean[rowInd][None, :],
            perWindow=perWindow,
        ))
    return records


# --------------------------------------------------------------------------- #
#  Panel 1: population average FR traces (PlotAvgTracesFRFinal)
# --------------------------------------------------------------------------- #
def plotAvgTracesFRFinal(unitTable, outDir):
    """Population mean contra/ipsi FR traces, WT on the top row and KO on the
    bottom, one column per stimulus frequency. Only responsive units contribute.
    Also writes the peak-value / paired-t statistics text file."""
    import matplotlib.pyplot as plt

    genotypes = genotypesIn(unitTable)
    frTime = _sharedTime(unitTable)

    # accumulate contra/ipsi mean traces per (genotype, frequency) over responsive units
    contraTraces = {geno: {freq: [] for freq in STIM_SLOTS} for geno in genotypes}
    ipsiTraces = {geno: {freq: [] for freq in STIM_SLOTS} for geno in genotypes}
    for row in unitTable:
        if not row["responsive"]:
            continue
        for freq in STIM_SLOTS:
            if freq not in row["slots"]:
                continue
            contraTraces[row["genotype"]][freq].append(row["slots"][freq]["meanContra"])
            ipsiTraces[row["genotype"]][freq].append(row["slots"][freq]["meanIpsi"])

    # window used for the peak/paired statistics: 0 .. 0.05 s
    postMask = (frTime > 0) & (frTime < 0.05)

    figure, axes = plt.subplots(2, 3, figsize=(3, 2.25), squeeze=False)
    colorContra = (1.0, 0.0, 0.0)
    colorIpsi = (0.0, 0.0, 1.0)
    statLines = []
    statContra = {geno: {} for geno in genotypes}
    statIpsi = {geno: {} for geno in genotypes}

    for stimInd, freq in enumerate(STIM_SLOTS):
        for geno in genotypes:
            contraStack = _stack(contraTraces[geno][freq], len(frTime))
            ipsiStack = _stack(ipsiTraces[geno][freq], len(frTime))
            meanContra, loContra, hiContra = meanCI(contraStack)
            meanIpsi, loIpsi, hiIpsi = meanCI(ipsiStack)

            statContra[geno][freq] = np.nanmean(contraStack[:, postMask], axis=1)
            statIpsi[geno][freq] = np.nanmean(ipsiStack[:, postMask], axis=1)

            rowInd = 0 if geno == "WT" else 1
            axis = axes[rowInd][stimInd]
            axis.plot(frTime, meanContra, color=colorContra, linewidth=1)
            axis.plot(frTime, meanIpsi, color=colorIpsi, linewidth=1)
            axis.fill_between(frTime, loContra, hiContra, color=colorContra, alpha=0.3, linewidth=0)
            axis.fill_between(frTime, loIpsi, hiIpsi, color=colorIpsi, alpha=0.3, linewidth=0)
            axis.axvline(0, linestyle="--", color=(0.5, 0.5, 0.5), linewidth=1)
            axis.set_ylim(0, MAX_FR)
            axis.set_xlim(PLOT_XLIMS)
            axis.set_xticks(np.arange(PLOT_XLIMS[0], PLOT_XLIMS[1] + 1e-9, 0.05))
            axis.set_xticklabels([str(int(round(x * 1000))) for x in axis.get_xticks()])
            axis.tick_params(labelsize=8)
            statLines.append(f"{geno}: {STIM_NAMES[stimInd]} Peak Contra: "
                             f"{np.nanmax(meanContra):.4g} Peak Ipsi: {np.nanmax(meanIpsi):.4g}")

    # paired statistics (40 Hz - 10 Hz; contra vs ipsi per stim), matching the original
    for geno in genotypes:
        if "10" in statContra[geno] and "40" in statContra[geno]:
            pC = pairedTTest(statContra[geno]["40"], statContra[geno]["10"], "right")
            pI = pairedTTest(statIpsi[geno]["40"], statIpsi[geno]["10"], "right")
            statLines.append(f"{geno} 40Hz-10Hz paired-t (contra) p = {pC:.4g}")
            statLines.append(f"{geno} 40Hz-10Hz paired-t (ipsi) p = {pI:.4g}")
    for geno in genotypes:
        for stimInd, freq in enumerate(STIM_SLOTS):
            if freq not in statContra[geno]:
                continue
            tail = "right" if geno == "WT" else "both"
            pCI = pairedTTest(statContra[geno][freq], statIpsi[geno][freq], tail)
            statLines.append(f"{geno} {STIM_NAMES[stimInd]} ipsi vs contra paired-t p = {pCI:.4g}")

    figure.tight_layout()
    outDir = Path(outDir)
    outDir.mkdir(parents=True, exist_ok=True)
    figure.savefig(outDir / f"Fig3D - Mean spike rate contra vs ipsi (window {SIG_WINDOW} ms).pdf", dpi=1200)
    figure.savefig(outDir / f"Fig3D - Mean spike rate contra vs ipsi (window {SIG_WINDOW} ms).png", dpi=200)
    plt.close(figure)
    (outDir / "Fig3D - Mean spike rate peak values.txt").write_text("\n".join(statLines) + "\n")
    return statLines


# --------------------------------------------------------------------------- #
#  Panel 2: contra-bias / laterality histograms (MakeCbiasFiguresFinal)
# --------------------------------------------------------------------------- #
def makeCbiasFiguresFinal(unitTable, outDir):
    """Laterality-index (contra-bias) histograms and per-session
    percent-contra-preferring histograms. Responsive units come from the 20 Hz /
    150 ms window; the contra-bias itself is read at each frequency's first-cycle
    window (10 Hz -> 100 ms, 20 Hz -> 50 ms, 40 Hz -> 25 ms)."""
    import matplotlib.pyplot as plt

    genotypes = genotypesIn(unitTable)

    # pooled contra-bias values and per-session category counts, per (genotype, frequency)
    cbiasPooled = {geno: {freq: [] for freq in STIM_SLOTS} for geno in genotypes}
    sessionCounts = {geno: {freq: [] for freq in STIM_SLOTS} for geno in genotypes}

    bySession = defaultdict(list)
    for row in unitTable:
        bySession[(row["genotype"], row["session"])].append(row)

    for (geno, _session), rows in bySession.items():
        for freq in STIM_SLOTS:
            values = [row["slots"][freq]["cbiasFirstCycle"] for row in rows
                      if row["responsive"] and freq in row["slots"]]
            values = [v for v in values if not np.isnan(v)]
            if not values:
                continue
            cbiasPooled[geno][freq].extend(values)
            nContra = sum(1 for v in values if v >= CBIAS_CONTRA)
            nBilateral = sum(1 for v in values if CBIAS_IPSI <= v < CBIAS_CONTRA)
            nIpsi = sum(1 for v in values if v < CBIAS_IPSI)
            if (nContra + nBilateral + nIpsi) > MIN_UNITS:
                sessionCounts[geno][freq].append((nContra, nBilateral, nIpsi))

    colorStock = {"WT": (0.0, 0.0, 0.0), "KO": (0.6, 0.6, 0.6)}
    lateralityBins = np.arange(-1.0, 1.0 + 1e-9, 0.25)
    percentBins = np.arange(0.0, 100.0 + 1e-9, 10.0)

    lateralityFig, lateralityAxes = plt.subplots(2, 3, figsize=(4, 2), squeeze=False)
    percentFig, percentAxes = plt.subplots(2, 3, figsize=(3.25, 2), squeeze=False)

    for stimInd, freq in enumerate(STIM_SLOTS):
        for geno in genotypes:
            rowInd = 0 if geno == "WT" else 1
            color = colorStock.get(geno, (0.3, 0.3, 0.3))

            # laterality index distribution (probability normalised)
            axis = lateralityAxes[rowInd][stimInd]
            values = np.asarray(cbiasPooled[geno][freq], dtype=float)
            if values.size:
                weights = np.ones_like(values) / values.size
                axis.hist(values, bins=lateralityBins, weights=weights, color=color)
            axis.set_ylim(0, 0.6)
            axis.set_yticks(np.arange(0, 0.61, 0.2))
            axis.set_xticks(np.arange(-1, 1.01, 0.25))
            axis.set_xticklabels(["-1", "", "-0.5", "", "0", "", "0.5", "", "1"])
            axis.tick_params(labelsize=8)
            if geno == "KO":
                axis.set_xlabel("Laterality index", fontsize=8)

            # per-session percent contra-preferring
            axis = percentAxes[rowInd][stimInd]
            counts = np.asarray(sessionCounts[geno][freq], dtype=float)
            if counts.size:
                totals = counts.sum(axis=1)
                percentContra = 100.0 * counts[:, 0] / totals
                axis.hist(percentContra, bins=percentBins, color=color)
            axis.set_ylim(0, 10)
            axis.tick_params(labelsize=8)
            if geno == "WT" and stimInd == 1:
                axis.set_xlabel("Percent of contralateral preferring units", fontsize=8)

    lateralityFig.tight_layout()
    percentFig.tight_layout()
    outDir = Path(outDir)
    outDir.mkdir(parents=True, exist_ok=True)
    lateralityFig.savefig(outDir / "Fig3E - Laterality index distribution.pdf", dpi=1200)
    lateralityFig.savefig(outDir / "Fig3E - Laterality index distribution.png", dpi=200)
    percentFig.savefig(outDir / "Fig3F - Percent contra-preferring units.pdf", dpi=1200)
    percentFig.savefig(outDir / "Fig3F - Percent contra-preferring units.png", dpi=200)
    plt.close(lateralityFig)
    plt.close(percentFig)


# --------------------------------------------------------------------------- #
#  FR heatmap renderer (shared by Fig3 FRHeatmapsAllFreq and FigS3 FRHeatmapsEachFreq)
# --------------------------------------------------------------------------- #
def renderFRHeatmap(contraMat, ipsiMat, respIdsPlus1, frTime, geno, outDir, stem):
    """Draw one heatmap figure: contra (white->red) | ipsi (white->blue) | identity
    strip (blue/white/red), sorted rows already applied and traces already normalised.
    Colourbars (0..1) are drawn on the WT figure, matching the original layout."""
    import matplotlib.pyplot as plt
    from matplotlib.colors import LinearSegmentedColormap, ListedColormap, Normalize
    from matplotlib.cm import ScalarMappable

    contraCmap = LinearSegmentedColormap.from_list("whiteRed", [(1, 1, 1), (1, 0, 0)], N=256)
    ipsiCmap = LinearSegmentedColormap.from_list("whiteBlue", [(1, 1, 1), (0, 0, 1)], N=256)
    respCmap = ListedColormap([(0, 0, 1), (1, 1, 1), (1, 0, 0)])

    figWidth, figHeight = 1.6, 2.0
    posContra = [0.24 / figWidth, 0.2 / figHeight, 0.45 / figWidth, 1.75 / figHeight]
    posIpsi = [0.95 / figWidth, 0.2 / figHeight, 0.45 / figWidth, 1.75 / figHeight]
    posResp = [1.45 / figWidth, 0.2 / figHeight, 0.05 / figWidth, 1.75 / figHeight]
    posCbarContra = [0.12 / figWidth, 1.55 / figHeight, 0.08 / figWidth, 0.4 / figHeight]
    posCbarIpsi = [0.83 / figWidth, 1.55 / figHeight, 0.08 / figWidth, 0.4 / figHeight]

    outDir = Path(outDir)
    outDir.mkdir(parents=True, exist_ok=True)
    nUnits = contraMat.shape[0]
    extent = [frTime[0], frTime[-1], nUnits, 1]

    figure = plt.figure(figsize=(figWidth, figHeight))
    axisContra = figure.add_axes(posContra)
    axisIpsi = figure.add_axes(posIpsi)
    axisResp = figure.add_axes(posResp)

    for axis, matrix, cmap in ((axisContra, contraMat, contraCmap), (axisIpsi, ipsiMat, ipsiCmap)):
        axis.imshow(matrix, aspect="auto", extent=extent, cmap=cmap, vmin=0, vmax=1,
                    origin="upper", interpolation="nearest")
        axis.axvline(0, color="k", linestyle="--", linewidth=1)
        axis.set_xlim(PLOT_XLIMS)
        axis.set_xticks([PLOT_XLIMS[0], 0, PLOT_XLIMS[1]])
        axis.set_xticklabels(["-50", "0", "50"], fontsize=8)
        axis.set_yticks(np.arange(20, nUnits + 1, 20))
        axis.tick_params(direction="out", labelsize=8)
    axisIpsi.set_yticklabels([])

    axisResp.imshow(np.asarray(respIdsPlus1).reshape(-1, 1), aspect="auto", cmap=respCmap,
                    vmin=0, vmax=2, extent=[0, 1, nUnits, 1], origin="upper", interpolation="nearest")
    axisResp.set_xticks([])
    axisResp.set_yticks([])

    if geno == "WT":
        cbarContra = figure.add_axes(posCbarContra)
        figure.colorbar(ScalarMappable(norm=Normalize(0, 1), cmap=contraCmap), cax=cbarContra, ticks=[0, 1])
        cbarContra.tick_params(labelsize=8)
        cbarIpsi = figure.add_axes(posCbarIpsi)
        figure.colorbar(ScalarMappable(norm=Normalize(0, 1), cmap=ipsiCmap), cax=cbarIpsi, ticks=[0, 1])
        cbarIpsi.tick_params(labelsize=8)

    figure.savefig(outDir / f"{stem}.pdf", dpi=1200)
    figure.savefig(outDir / f"{stem}.png", dpi=200)
    plt.close(figure)


# --------------------------------------------------------------------------- #
#  Panel 3: FR heatmaps (FRHeatmapsAllFreq)
# --------------------------------------------------------------------------- #
def frHeatmapsAllFreq(unitTable, outDir):
    """Per-unit contra/ipsi firing-rate heatmaps (one figure per genotype), sorted by
    responsive identity (contra / bilateral / ipsi) then contra-bias. Each unit's
    traces are normalised by its own combined peak; contra and ipsi traces are averaged
    across the available 10/20/40 Hz slots."""
    genotypes = genotypesIn(unitTable)
    frTime = _sharedTime(unitTable)

    for geno in genotypes:
        rows = []
        for row in unitTable:
            if row["genotype"] != geno or not row["responsive"]:
                continue
            contraSlots = [row["slots"][f]["meanContra"] for f in STIM_SLOTS if f in row["slots"]]
            ipsiSlots = [row["slots"][f]["meanIpsi"] for f in STIM_SLOTS if f in row["slots"]]
            if not contraSlots:
                continue
            meanContra = np.mean(np.stack(contraSlots, axis=0), axis=0)
            meanIpsi = np.mean(np.stack(ipsiSlots, axis=0), axis=0)
            cbiasSlot = row["slots"]["20"] if "20" in row["slots"] else next(iter(row["slots"].values()))
            cbias = cbiasSlot["cbias150"]
            respId = 1 if cbias >= CBIAS_CONTRA else (-1 if cbias < CBIAS_IPSI else 0)
            rows.append(dict(meanContra=meanContra, meanIpsi=meanIpsi, cbias=cbias, respId=respId))

        if not rows:
            continue
        rows.sort(key=lambda r: (r["respId"], r["cbias"]), reverse=True)
        contraMat = np.stack([r["meanContra"] for r in rows], axis=0)
        ipsiMat = np.stack([r["meanIpsi"] for r in rows], axis=0)
        for unitInd in range(contraMat.shape[0]):
            peak = max(np.max(contraMat[unitInd]), np.max(ipsiMat[unitInd]))
            if peak > 0:
                contraMat[unitInd] /= peak
                ipsiMat[unitInd] /= peak
        respIdsPlus1 = np.asarray([r["respId"] + 1 for r in rows], dtype=float)
        renderFRHeatmap(contraMat, ipsiMat, respIdsPlus1, frTime, geno, outDir,
                        f"Fig3C - Normalized FR heatmap {geno}")


# --------------------------------------------------------------------------- #
#  shared helpers
# --------------------------------------------------------------------------- #
def _sharedTime(unitTable):
    return unitTable[0]["frTime"] if unitTable else core.BINS


def _stack(traceList, nBins):
    if not traceList:
        return np.empty((0, nBins))
    return np.stack(traceList, axis=0)


# --------------------------------------------------------------------------- #
#  main
# --------------------------------------------------------------------------- #
def main(argv=None):
    parser = argparse.ArgumentParser(description="Build Figure 3 manuscript panels from NWB.")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--tables", help="saved fig3_tables_S1.mat (accumulation stage output)")
    source.add_argument("--s1-dir", help="folder of S1 ephys NWB files (read directly)")
    parser.add_argument("--out-dir", required=True,
                        help="folder to write the panels into (must be under NWBData)")
    parser.add_argument("--force", action="store_true",
                        help="allow writing outside an NWBData folder (off by default)")
    args = parser.parse_args(argv)

    # Safeguard: the NWB pipeline writes only into NWBData\Figures\..., never the
    # hand-made manuscript figure folders. Refuse an out-dir outside NWBData.
    if "nwbdata" not in str(args.out_dir).lower() and not args.force:
        parser.error(f"refusing to write to '{args.out_dir}' (not under an NWBData folder). "
                     f"Use e.g. ...\\NWBData\\Figures\\Fig3, or pass --force to override.")

    # Prefer the saved accumulation; fall back to reading the NWBs directly.
    if args.tables:
        print(f"loading records from saved tables {args.tables}")
        records = loadFlatTable(args.tables)
    else:
        print(f"loading S1 records from {args.s1_dir}")
        records = core.loadRegion(args.s1_dir)
    unitTable = buildUnitTable(records)
    nResponsive = sum(1 for row in unitTable if row["responsive"])
    print(f"built {len(unitTable)} unit rows ({nResponsive} responsive)")

    print("panel 1: population average FR traces")
    plotAvgTracesFRFinal(unitTable, args.out_dir)
    print("panel 2: contra-bias / laterality histograms")
    makeCbiasFiguresFinal(unitTable, args.out_dir)
    print("panel 3: FR heatmaps")
    frHeatmapsAllFreq(unitTable, args.out_dir)
    print(f"done -> {args.out_dir}")


if __name__ == "__main__":
    main()
