"""
figS3S4_nwb.py
==============
Figure S3 / S4 supplement panels for the passive-stim S1 ephys, reading NWB.

Builds on the accumulated fig3 tables (fig3_tables_<region>.mat) and the shared
helpers in fig3_panels_nwb:

  FigS3
    * frHeatmapsEachFreq  -> per-frequency (10/20/40 Hz) contra/ipsi FR heatmaps,
                             each unit normalised by its cross-frequency peak and
                             sorted by responsive identity then contra-bias.

  FigS4 (added below)
    * cBiasDepthHistoLine -> contra-bias vs normalised cortical depth, per layer band.
    * bilateralFractionL4 -> bilateral-unit fraction in L4 vs other layers.
    * plotHistoCBias      -> contra-bias index histograms.

Run:
  python figS3S4_nwb.py --tables <fig3_tables_S1.mat> --out-dir <NWBData\\Figures\\FigS3S4>

Deps: pynwb, numpy, scipy, matplotlib
"""
from __future__ import annotations

import argparse
from pathlib import Path

import numpy as np

import fig3_panels_nwb as fp

STIM_SLOTS = fp.STIM_SLOTS          # ['10','20','40']
CBIAS_CONTRA = fp.CBIAS_CONTRA
CBIAS_IPSI = fp.CBIAS_IPSI


# --------------------------------------------------------------------------- #
#  FigS3: per-frequency FR heatmaps
# --------------------------------------------------------------------------- #
def frHeatmapsEachFreq(unitTable, outDir):
    """Per-frequency contra/ipsi FR heatmaps: one figure per (frequency, genotype).
    Each unit is normalised by its peak across ALL frequencies (so the three panels
    share one scale per unit) and rows are sorted by responsive identity then
    contra-bias, matching the original FRHeatmapsEachFreq."""
    genotypes = fp.genotypesIn(unitTable)
    frTime = unitTable[0]["frTime"] if unitTable else None

    for geno in genotypes:
        # per responsive unit: cross-frequency peak, respId, cbias, and per-freq traces
        units = []
        for row in unitTable:
            if row["genotype"] != geno or not row["responsive"]:
                continue
            slots = row["slots"]
            if not slots:
                continue
            peak = 0.0
            for freq in STIM_SLOTS:
                if freq in slots:
                    peak = max(peak, float(np.max(slots[freq]["meanContra"])),
                               float(np.max(slots[freq]["meanIpsi"])))
            cbiasSlot = slots["20"] if "20" in slots else next(iter(slots.values()))
            cbias = cbiasSlot["cbias150"]
            respId = 1 if cbias >= CBIAS_CONTRA else (-1 if cbias < CBIAS_IPSI else 0)
            units.append(dict(slots=slots, peak=peak, cbias=cbias, respId=respId))

        if not units:
            continue

        for freq in STIM_SLOTS:
            rows = [u for u in units if freq in u["slots"] and u["peak"] > 0]
            if not rows:
                continue
            rows.sort(key=lambda u: (u["respId"], u["cbias"]), reverse=True)
            contraMat = np.stack([u["slots"][freq]["meanContra"] / u["peak"] for u in rows], axis=0)
            ipsiMat = np.stack([u["slots"][freq]["meanIpsi"] / u["peak"] for u in rows], axis=0)
            respIdsPlus1 = np.asarray([u["respId"] + 1 for u in rows], dtype=float)
            panelLetter = "A" if geno == "WT" else "B"     # FigS3A = WT, FigS3B = KO
            fp.renderFRHeatmap(contraMat, ipsiMat, respIdsPlus1, frTime, geno, outDir,
                               f"FigS3{panelLetter} - Stim {freq}hz FR heatmap {geno}")


# --------------------------------------------------------------------------- #
#  FigS4: contra-bias vs cortical depth, by layer band (CBiasDepthHistoLinefinal)
# --------------------------------------------------------------------------- #
# Layer boundaries on normalised depth (Minamisawa et al. 2018 fractions of 1154 um).
L_TWO_THREE = 418.0 / 1154.0
L_FOUR = 588.0 / 1154.0
DEPTH_ADJUST = 50.0 / 1154.0
LATERALITY_THIRD = 1.0 / 3.0        # ipsi < -1/3 <= bilateral <= 1/3 < contra
GENO_COLORS = {"WT": (0.0, 0.0, 0.0), "KO": (0.7, 0.7, 0.7)}
RESPONSE_NAMES = ["ipsilateral", "bilateral", "contralateral"]


def _lateralityCategory(cbias):
    """0 = ipsi, 1 = bilateral, 2 = contra (thirds thresholds), matching the original bins."""
    if cbias < -LATERALITY_THIRD:
        return 0
    if cbias > LATERALITY_THIRD:
        return 2
    return 1


def _layerBand(depth):
    """0 = superficial (<=L2/3), 1 = L4, 2 = deep (>L4)."""
    if depth <= L_TWO_THREE:
        return 0
    if depth <= L_FOUR:
        return 1
    return 2


def cBiasDepthHistoLine(unitTable, outDir):
    """FigS4B: laterality-category (ipsi/bilateral/contra) distribution per cortical
    layer band (superficial / L4 / deep), averaged across animals, one line per
    genotype. Responsive units use the 20 Hz / 150 ms window; contra-bias and depth
    are read at that window. Writes the figure and the cross/within-genotype stats."""
    import matplotlib.pyplot as plt
    from scipy import stats

    genotypes = fp.genotypesIn(unitTable)
    # per (genotype, layer): list over animals of [%ipsi, %bilateral, %contra]
    perAnimal = {geno: {layer: [] for layer in range(3)} for geno in genotypes}

    animals = sorted(set((row["genotype"], row["animal"]) for row in unitTable))
    for geno, animal in animals:
        # gather this animal's responsive units: (layerBand, lateralityCategory)
        layerCounts = {layer: [0, 0, 0] for layer in range(3)}
        for row in unitTable:
            if row["genotype"] != geno or row["animal"] != animal or not row["responsive"]:
                continue
            if "20" not in row["slots"]:
                continue
            cbias = row["slots"]["20"]["cbias150"]
            if np.isnan(cbias):
                continue
            depth = row["depthNorm"] - DEPTH_ADJUST
            layerCounts[_layerBand(depth)][_lateralityCategory(cbias)] += 1
        for layer in range(3):
            total = sum(layerCounts[layer])
            if total == 0:
                continue
            perAnimal[geno][layer].append([100.0 * c / total for c in layerCounts[layer]])

    # convert to arrays (animals x 3 categories) per genotype/layer
    dist = {geno: {layer: np.asarray(perAnimal[geno][layer], dtype=float) for layer in range(3)}
            for geno in genotypes}

    # ---- statistics ----
    outDir = Path(outDir)
    outDir.mkdir(parents=True, exist_ok=True)
    layerNames = ["Sup", "L4", "Deep"]
    statLines = []
    for layer in range(3):
        for response in range(3):
            if len(genotypes) == 2:
                a = dist[genotypes[0]][layer]
                b = dist[genotypes[1]][layer]
                if a.size and b.size:
                    try:
                        p = stats.mannwhitneyu(a[:, response], b[:, response], alternative="two-sided").pvalue
                    except ValueError:
                        p = np.nan
                    statLines.append(f"{layerNames[layer]} Mann-Whitney across genotypes "
                                     f"({RESPONSE_NAMES[response]}): p = {p:.4f}")
        for geno in genotypes:
            data = dist[geno][layer]
            if data.shape[0] >= 2 and data.shape[1] == 3:
                try:
                    pFried = stats.friedmanchisquare(data[:, 0], data[:, 1], data[:, 2]).pvalue
                except ValueError:
                    pFried = np.nan
                statLines.append(f"{geno} {layerNames[layer]} Friedman p = {pFried:.4f}")
    (outDir / "FigS4B - Layer preference distribution stats.txt").write_text("\n".join(statLines) + "\n")

    # ---- figure: 3 stacked subplots (Sup / L4 / Deep) ----
    xPositions = np.array([-1.0, 0.0, 1.0])
    figure, axes = plt.subplots(3, 1, figsize=(1.35, 3), squeeze=False)
    for layer in range(3):
        axis = axes[layer][0]
        for genoInd, geno in enumerate(genotypes):
            data = dist[geno][layer]
            if data.size == 0:
                continue
            meanVals = data.mean(axis=0)
            stdVals = data.std(axis=0, ddof=0)
            color = GENO_COLORS.get(geno, (0.3, 0.3, 0.3))
            axis.errorbar(xPositions + genoInd * 0.05, meanVals, stdVals, color=color, linewidth=1)
        axis.set_xlim(-1.2, 1.2)
        axis.set_ylim(-20, 120)
        axis.set_xticks(xPositions)
        axis.set_xticklabels([] if layer < 2 else ["ipsi", "bilat", "contra"], fontsize=8)
        axis.tick_params(direction="out", labelsize=8)

    figure.tight_layout()
    figure.savefig(outDir / "FigS4B - Layer preference distribution.pdf", dpi=300)
    figure.savefig(outDir / "FigS4B - Layer preference distribution.png", dpi=200)
    plt.close(figure)
    return statLines


def bilateralFractionL4vsOther(unitTable, outDir):
    """FigS4: per-mouse percentage of bilateral units (|cbias| < 1/3) in L4 vs the
    other layers (superficial + deep combined), at 20 Hz, paired within mouse.
    Writes the paired-stats file and a mean +/- SEM plot per genotype."""
    import matplotlib.pyplot as plt
    from scipy import stats

    genotypes = fp.genotypesIn(unitTable)
    colors = {"WT": (0.0, 0.0, 0.0), "KO": (0.7, 0.7, 0.7)}

    # per genotype: list over mice of [% bilateral in other, % bilateral in L4]
    perMouse = {geno: [] for geno in genotypes}
    mouseIds = {geno: [] for geno in genotypes}
    for geno in genotypes:
        animals = sorted(set(row["animal"] for row in unitTable if row["genotype"] == geno))
        for animal in animals:
            otherBilat, otherTotal, l4Bilat, l4Total = 0, 0, 0, 0
            for row in unitTable:
                if row["genotype"] != geno or row["animal"] != animal or not row["responsive"]:
                    continue
                if "20" not in row["slots"]:
                    continue
                cbias = row["slots"]["20"]["cbias150"]
                if np.isnan(cbias):
                    continue
                depth = row["depthNorm"] - DEPTH_ADJUST
                isBilat = _lateralityCategory(cbias) == 1
                if _layerBand(depth) == 1:                       # L4
                    l4Total += 1
                    l4Bilat += int(isBilat)
                else:                                            # superficial or deep
                    otherTotal += 1
                    otherBilat += int(isBilat)
            if l4Total >= 1 and otherTotal >= 1:                 # paired requirement (minUnits=1)
                perMouse[geno].append([100.0 * otherBilat / otherTotal, 100.0 * l4Bilat / l4Total])
                mouseIds[geno].append(animal)

    # ---- stats ----
    outDir = Path(outDir)
    outDir.mkdir(parents=True, exist_ok=True)
    statLines = ["Percent bilateral units (|cbias| < 0.33), 20hz, 150 ms window",
                 "Layers: L4 vs (superficial + deep). Paired within mouse.\n"]
    for geno in genotypes:
        data = np.asarray(perMouse[geno], dtype=float)
        statLines.append(f"Genotype {geno}, n = {data.shape[0]} mice")
        if data.shape[0] > 1:
            statLines.append(f"  mean +/- SEM: other = {data[:, 0].mean():.1f} +/- "
                             f"{data[:, 0].std(ddof=1) / np.sqrt(len(data)):.1f}, "
                             f"L4 = {data[:, 1].mean():.1f} +/- "
                             f"{data[:, 1].std(ddof=1) / np.sqrt(len(data)):.1f}")
            try:
                p2 = stats.wilcoxon(data[:, 1], data[:, 0]).pvalue
                p1 = stats.wilcoxon(data[:, 1], data[:, 0], alternative="less").pvalue
                statLines.append(f"  Wilcoxon L4 vs other two-sided p = {p2:.4f}")
                statLines.append(f"  Wilcoxon L4 < other one-sided p = {p1:.4f}")
            except ValueError:
                statLines.append("  Wilcoxon not computable")
        else:
            statLines.append("  Not enough mice for a paired test")
    if len(genotypes) == 2 and perMouse[genotypes[0]] and perMouse[genotypes[1]]:
        d1 = np.asarray(perMouse[genotypes[0]])
        d2 = np.asarray(perMouse[genotypes[1]])
        diff1 = d1[:, 1] - d1[:, 0]
        diff2 = d2[:, 1] - d2[:, 0]
        try:
            pGeno = stats.mannwhitneyu(diff1, diff2, alternative="two-sided").pvalue
            statLines.append(f"\nMann-Whitney on (L4 - other) across genotypes: p = {pGeno:.4f}")
        except ValueError:
            pass
    (outDir / "FigS4B - Bilateral fraction L4 vs other stats.txt").write_text("\n".join(statLines) + "\n")

    # ---- plot ----
    figure, axis = plt.subplots(figsize=(1.35, 1.5))
    xBase = np.array([1.0, 2.0])
    for genoInd, geno in enumerate(genotypes):
        data = np.asarray(perMouse[geno], dtype=float)
        if data.size == 0:
            continue
        color = colors.get(geno, (0.3, 0.3, 0.3))
        x = xBase + genoInd * 0.05
        mean = data.mean(axis=0)
        sem = data.std(axis=0, ddof=1) / np.sqrt(len(data)) if len(data) > 1 else np.zeros(2)
        axis.errorbar(x, mean, sem, fmt="o-", color=color, linewidth=1, markersize=3,
                      markerfacecolor=color, capsize=3)
    axis.set_xticks(xBase)
    axis.set_xticklabels(["Sup/Deep", "L4"], rotation=45, fontsize=8)
    axis.set_xlim(0.5, 2.5)
    axis.set_ylim(0, 100)
    axis.set_ylabel("% bilateral units", fontsize=8)
    axis.tick_params(direction="out", labelsize=8)
    figure.tight_layout()
    figure.savefig(outDir / "FigS4B - Bilateral fraction L4 vs other.pdf", dpi=300)
    figure.savefig(outDir / "FigS4B - Bilateral fraction L4 vs other.png", dpi=200)
    plt.close(figure)


# --------------------------------------------------------------------------- #
#  main
# --------------------------------------------------------------------------- #
def loadUnitTable(args):
    if args.tables:
        print(f"loading records from saved tables {args.tables}")
        records = fp.loadFlatTable(args.tables)
    else:
        import fig3_analysis_nwb as core
        print(f"loading S1 records from {args.s1_dir}")
        records = core.loadRegion(args.s1_dir)
    return fp.buildUnitTable(records)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Build Figure S3/S4 supplements from NWB.")
    source = parser.add_mutually_exclusive_group(required=True)
    source.add_argument("--tables", help="saved fig3_tables_S1.mat")
    source.add_argument("--s1-dir", help="folder of S1 ephys NWB files")
    parser.add_argument("--histology-dir", help="folder containing figS4a_histology_S1 table")
    parser.add_argument("--out-dir", required=True, help="folder to write panels into (under NWBData)")
    parser.add_argument("--force", action="store_true", help="allow writing outside NWBData")
    args = parser.parse_args(argv)

    if "nwbdata" not in str(args.out_dir).lower() and not args.force:
        parser.error(f"refusing to write to '{args.out_dir}' (not under an NWBData folder). "
                     f"Use e.g. ...\\NWBData\\Figures\\FigS3, or pass --force to override.")

    unitTable = loadUnitTable(args)
    nResponsive = sum(1 for row in unitTable if row["responsive"])
    print(f"built {len(unitTable)} unit rows ({nResponsive} responsive)")

    print("FigS3: per-frequency FR heatmaps")
    frHeatmapsEachFreq(unitTable, args.out_dir)

    # FigS4A: 3D reconstructed wS1 unit CCF locations
    if args.histology_dir:
        histo_dir = Path(args.histology_dir)
    elif args.tables:
        histo_dir = Path(args.tables).parent / "Histology"
    else:
        histo_dir = Path(args.out_dir).parent.parent / "Data" / "Tables" / "Histology"

    if (histo_dir / "figS4a_histology_S1.json").exists() or (histo_dir / "figS4a_histology_S1.mat").exists():
        import figS4a_histology_nwb as fh4
        print("FigS4A: 3D wS1 histology CCF locations")
        fh4.generate_figS4a(histo_dir, Path(args.out_dir))

    print("FigS4B: contra-bias vs depth by layer")
    cBiasDepthHistoLine(unitTable, args.out_dir)
    print("FigS4: bilateral fraction L4 vs other")
    bilateralFractionL4vsOther(unitTable, args.out_dir)
    print(f"done -> {args.out_dir}")


if __name__ == "__main__":
    import sys
    main(sys.argv[1:])
