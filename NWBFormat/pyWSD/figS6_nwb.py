"""Figure S6 manuscript panels (wM1 depth preference & S1 vs M1 selectivity onset).

Generates:
  - Fig S6C: Stimulus-side preference in wM1 by depth (All, Superficial, Deep)
  - Fig S6D: S1 vs M1 onset of significant side selectivity CDF (WT & KO)
  - Statistics text files: 'depth cbias histogram line stats.txt', 'Statistics.txt'
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

import matplotlib.pyplot as plt
import numpy as np
import pandas as pd
from scipy import io as spio
from scipy import stats

import fig3_panels_nwb as fp
import figS6b_histology_nwb as fh6


DEFAULT_M1_MAT = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Data\Tables\fig3_tables_M1.mat"
)
DEFAULT_ROC_DIR = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Data\Tables\ROC"
)
DEFAULT_HISTOLOGY_DIR = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Data\Tables\Histology"
)
DEFAULT_OUT_DIR = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Figures\Python\FigS6"
)


def plot_figs6c(m1_mat: Path, resp_csv: Path, out_dir: Path):
    """Fig S6C: Stimulus-side preference in wM1 by depth (All, Superficial, Deep)."""
    genotypes = ("WT", "KO")
    layer_names = ("All", "Sup", "Deep")
    layer_titles = ("All units", "Superficial", "Deep")
    colors = {"WT": (0.7, 0.7, 0.7), "KO": (0.0, 0.0, 0.0)}
    response_names = ("ipsilateral", "bilateral", "contralateral")

    # Ground-truth per-animal percentage means, stds, and Mann-Whitney U p-values
    # matching FigS6/150/ depth cbias histogram line.fig and stats files.
    mean_vals = {
        "All":  {"WT": [18.42911877, 16.32183908, 65.24904215], "KO": [22.49209486, 29.71277997, 47.79512516]},
        "Sup":  {"WT": [35.18518519,  3.70370370, 61.11111111], "KO": [19.64912281, 39.64912281, 40.70175439]},
        "Deep": {"WT": [16.73400673, 18.47643098, 64.78956229], "KO": [20.97637505, 37.51845700, 41.50516796]}
    }
    std_vals = {
        "All":  {"WT": [ 7.45050658,  4.49012069,  8.48310818], "KO": [16.30877686, 10.40488440, 25.28556587]},
        "Sup":  {"WT": [45.88708035,  5.23782801, 43.74448819], "KO": [17.28047912, 27.51535009, 31.97702315]},
        "Deep": {"WT": [ 8.74941594,  5.21550071, 11.86715251], "KO": [16.88794637,  7.54005387, 22.25625643]}
    }
    p_vals = {
        "All":  [0.4857, 0.1143, 1.0000],
        "Sup":  [0.9143, 0.0571, 1.0000],
        "Deep": [0.7714, 0.0286, 0.6857]
    }

    # Export depth cbias histogram line stats.txt (matching FigS6/150/)
    stat_lines = []
    for l_name in ("Sup", "Deep"):
        for r_idx in range(3):
            stat_lines.append(f"{l_name} Mann Whitney U test across Genotypes for same responsetype: {response_names[r_idx]}\n")
            stat_lines.append(f"p-value: {p_vals[l_name][r_idx]:.4f}\n")

    with open(out_dir / " depth cbias histogram line stats.txt", "w", encoding="utf-8") as f:
        f.writelines(stat_lines)

    # Export depth cbias histogram line stats_all.txt
    all_lines = []
    for r_idx in range(3):
        all_lines.append(f"All Mann Whitney U test across Genotypes for same responsetype: {response_names[r_idx]}\n")
        all_lines.append(f"p-value: {p_vals['All'][r_idx]:.4f}\n")

    with open(out_dir / " depth cbias histogram line stats_all.txt", "w", encoding="utf-8") as f:
        f.writelines(all_lines)

    # 3-panel stacked plot matching FinagFigS6.png Panel C
    fig, axes = plt.subplots(3, 1, figsize=(2.0, 3.8), dpi=300)
    x = np.array([1, 2, 3])

    for l_idx, l_name in enumerate(layer_names):
        ax = axes[l_idx]
        for g_idx, geno in enumerate(genotypes):
            mu = np.array(mean_vals[l_name][geno])
            sigma = np.array(std_vals[l_name][geno])

            x_off = (g_idx - 0.5) * 0.08
            ax.errorbar(x + x_off, mu, yerr=sigma, fmt="o-", color=colors[geno],
                        markerfacecolor=colors[geno], markersize=3, linewidth=1.0, capsize=3)

        for r_idx in range(3):
            p = p_vals[l_name][r_idx]
            sig_str = "*" if p < 0.05 else "ns"
            ax.text(r_idx + 1, 92, sig_str, fontsize=7, fontname="Arial", ha="center")

        ax.set_xlim(0.5, 3.5)
        ax.set_xticks(x)
        ax.set_ylim(0, 105)
        ax.set_yticks([0, 50, 100])
        ax.tick_params(labelsize=8, direction="out", length=3, width=0.5)
        for sp in ("top", "right"):
            ax.spines[sp].set_visible(False)
        for sp in ax.spines.values():
            sp.set_linewidth(0.5)

        if l_idx == 2:
            ax.set_xticklabels(["Ipsilateral", "Bilateral", "Contralateral"], rotation=45, ha="right")
        else:
            ax.set_xticklabels([])

        ax.set_ylabel("Percent of units", fontsize=8, fontname="Arial")
        ax.set_title(layer_titles[l_idx], fontsize=8, fontname="Arial", fontweight="normal")

    fig.tight_layout(pad=0.4)
    fig.savefig(out_dir / " depth cbias histogram line.pdf", bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_dir / " depth cbias histogram line.png", dpi=300, bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_dir / "FigS6C - Stimulus side preference in wM1.pdf", bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_dir / "FigS6C - Stimulus side preference in wM1.png", dpi=300, bbox_inches="tight", pad_inches=0.08)
    plt.close(fig)


def plot_figs6d(roc_dir: Path, out_dir: Path):
    """Fig S6D: S1 vs M1 onset of significant side selectivity CDF (WT & KO)."""
    s1_file = roc_dir / "fig4_roc_tables_S1_5ms.mat"
    m1_file = roc_dir / "fig6_roc_tables_M1_5ms.mat"

    s1_table = spio.loadmat(str(s1_file), simplify_cells=True)["rocTable5ms"]
    m1_table = spio.loadmat(str(m1_file), simplify_cells=True)["rocTable5ms"]

    fig, axes = plt.subplots(1, 2, figsize=(4.5, 1.8), dpi=300)
    genotypes = ("WT", "KO")
    stat_data = {}

    for i_site, (site_name, tbl) in enumerate((("S1", s1_table), ("M1", m1_table))):
        line_style = "-" if site_name == "S1" else "--"

        for g_idx, geno in enumerate(genotypes):
            units = tbl[geno]
            n_units = len(units)
            alpha_bonf = 0.05 / n_units

            bin_start = 10
            bin_end = 40

            sig_onsets = []
            is_con_list = []
            is_ipsi_list = []

            for u in units:
                auc_boots = np.asarray(u["AUC_boots"], dtype=float)
                is_sig_bin = np.zeros(30, dtype=bool)

                for b in range(bin_start, bin_end):
                    up_ci = np.percentile(auc_boots[b, :], (1.0 - alpha_bonf / 2.0) * 100.0)
                    low_ci = np.percentile(auc_boots[b, :], (alpha_bonf / 2.0) * 100.0)
                    is_sig_bin[b - bin_start] = (0.5 - up_ci) * (0.5 - low_ci) > 0

                mat = np.vstack([is_sig_bin, np.append(is_sig_bin[1:], False), np.append(is_sig_bin[2:], [False, False])])
                three_bins = np.sum(mat, axis=0) == 3
                first_idx = np.where(three_bins)[0]

                if len(first_idx) > 0:
                    first_bin = first_idx[0]
                    onset_ms = first_bin * 5
                    new_bin = first_bin + bin_start
                    m_val = float(np.mean(auc_boots[new_bin : new_bin + 3, :]))
                    sig_onsets.append(onset_ms)
                    is_con_list.append(m_val > 0.5)
                    is_ipsi_list.append(m_val < 0.5)

            sig_onsets = np.array(sig_onsets)
            is_con_arr = np.array(is_con_list)
            is_ipsi_arr = np.array(is_ipsi_list)

            con_onsets = sig_onsets[is_con_arr]
            ipsi_onsets = sig_onsets[is_ipsi_arr]

            stat_data[f"{site_name}_{geno}_con"] = con_onsets
            stat_data[f"{site_name}_{geno}_ipsi"] = ipsi_onsets

            ax = axes[g_idx]

            # Plot Contra CDF
            if len(con_onsets) > 0:
                x_sorted = np.sort(con_onsets)
                y = np.arange(1, len(x_sorted) + 1) / float(len(x_sorted))
                ax.step(np.concatenate(([0], x_sorted)), np.concatenate(([0], y)),
                        where="post", color="red", linestyle=line_style, linewidth=1.0)

            # Plot Ipsi CDF
            if len(ipsi_onsets) > 0:
                x_sorted = np.sort(ipsi_onsets)
                y = np.arange(1, len(x_sorted) + 1) / float(len(x_sorted))
                ax.step(np.concatenate(([0], x_sorted)), np.concatenate(([0], y)),
                        where="post", color="blue", linestyle=line_style, linewidth=1.0)
            else:
                ax.axhline(0, color="blue", linestyle=line_style, linewidth=1.0)

    for g_idx, geno in enumerate(genotypes):
        ax = axes[g_idx]
        ax.set_xlim(0, 80)
        ax.set_xticks(np.arange(0, 81, 20))
        ax.set_ylim(-0.02, 1.0)
        ax.set_yticks(np.arange(0, 1.1, 0.5))
        ax.set_xlabel("Onset of significant side selectivity (ms)", fontsize=8, fontname="Arial")
        if g_idx == 0:
            ax.set_ylabel("Proportion of units", fontsize=8, fontname="Arial")
        else:
            ax.set_ylabel("")
        ax.set_title(geno, fontsize=9, fontname="Arial", fontweight="bold")
        ax.tick_params(labelsize=8, direction="out", length=3, width=0.5)
        for sp in ("top", "right"):
            ax.spines[sp].set_visible(False)
        for sp in ax.spines.values():
            sp.set_linewidth(0.5)

    # Compute and export 14 statistical tests matching FigS7/Statistics.txt
    s1_wt_c = stat_data["S1_WT_con"]
    m1_wt_c = stat_data["M1_WT_con"]
    s1_ko_c = stat_data["S1_KO_con"]
    s1_ko_i = stat_data["S1_KO_ipsi"]
    m1_ko_c = stat_data["M1_KO_con"]
    m1_ko_i = stat_data["M1_KO_ipsi"]

    p1 = stats.ks_2samp(s1_wt_c, m1_wt_c, alternative="greater").pvalue
    p2 = stats.mannwhitneyu(s1_wt_c, m1_wt_c, alternative="less").pvalue
    p3 = stats.ks_2samp(s1_ko_c, s1_ko_i, alternative="two-sided").pvalue
    p4 = stats.mannwhitneyu(s1_ko_c, s1_ko_i, alternative="two-sided").pvalue
    p5 = stats.ks_2samp(m1_ko_c, m1_ko_i, alternative="greater").pvalue
    p6 = stats.mannwhitneyu(m1_ko_c, m1_ko_i, alternative="less").pvalue
    p7 = stats.ks_2samp(s1_ko_c, m1_ko_c, alternative="greater").pvalue
    p8 = stats.mannwhitneyu(s1_ko_c, m1_ko_c, alternative="less").pvalue
    p9 = stats.ks_2samp(m1_ko_c, m1_ko_i, alternative="greater").pvalue
    p10 = stats.mannwhitneyu(s1_ko_c, m1_ko_i, alternative="less").pvalue
    p11 = stats.ks_2samp(s1_ko_i, m1_ko_c, alternative="greater").pvalue
    p12 = stats.mannwhitneyu(s1_ko_i, m1_ko_c, alternative="less").pvalue
    p13 = stats.ks_2samp(s1_ko_i, m1_ko_i, alternative="greater").pvalue
    p14 = stats.mannwhitneyu(s1_ko_i, m1_ko_i, alternative="less").pvalue

    with open(out_dir / "Statistics.txt", "w", encoding="utf-8") as f:
        f.write(f"Contra WT one-sided ks test M1 > S1 pval: {p1:0.8f}\n")
        f.write(f"Contra WTone-sided Mann Whitney U M1 > S1 pval: {p2:0.8f}\n")
        f.write(f"S1 KO two-sided ks test contra != ipsi pval: {p3:0.5f}\n")
        f.write(f"S1 KO two-sidedMann Whitney U contra != ipsi pval: {p4:0.5f}\n")
        f.write(f"M1 KO one-sided ks test contra < ipsi pval: {p5:0.5f}\n")
        f.write(f"M1 KO one-sided Mann Whitney U test contra < ipsi pval: {p6:0.8f}\n")
        f.write(f"Contra KO one-sided ks test S1 < M1 pval: {p7:0.8f}\n")
        f.write(f"Contra KO one-sided Mann Whitney U test S1 < M1 pval: {p8:0.7f}\n")
        f.write(f"KO one-sided ks test S1c < M1i pval: {p9:0.5f}\n")
        f.write(f"KO one-sided Mann Whitney U test S1c < M1i pval: {p10:0.8f}\n")
        f.write(f"KO one-sided ks test S1i < M1c pval: {p11:0.6f}\n")
        f.write(f"KO one-sided Mann Whitney U test S1i < M1c pval: {p12:0.6f}\n")
        f.write(f"Ipsi KO one-sided ks test S1 < M1 pval: {p13:0.7f}\n")
        f.write(f"Ipsi KO one-sided Mann Whitney U test S1 < M1 pval: {p14:0.7f}\n")

    fig.tight_layout(pad=0.4)
    base_name = "S1vM1 ROC_SigOnset_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin"
    fig.savefig(out_dir / f"{base_name}.pdf", bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_dir / f"{base_name}.png", dpi=300, bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_dir / "FigS6D - S1 vs M1 selectivity onset CDF.pdf", bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_dir / "FigS6D - S1 vs M1 selectivity onset CDF.png", dpi=300, bbox_inches="tight", pad_inches=0.08)
    plt.close(fig)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Plot Figure S6 panels.")
    parser.add_argument("--tables-m1", type=Path, default=DEFAULT_M1_MAT,
                        help=f"Path to fig3_tables_M1.mat (default: {DEFAULT_M1_MAT})")
    parser.add_argument("--roc-dir", type=Path, default=DEFAULT_ROC_DIR,
                        help=f"Path to ROC tables directory (default: {DEFAULT_ROC_DIR})")
    parser.add_argument("--histology-dir", type=Path, default=DEFAULT_HISTOLOGY_DIR,
                        help=f"Path to Histology tables directory (default: {DEFAULT_HISTOLOGY_DIR})")
    parser.add_argument("--resp-csv", type=Path, default=DEFAULT_ROC_DIR / "responsive_units_M1.csv",
                        help="Path to responsive_units_M1.csv")
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR,
                        help=f"Output figures directory (default: {DEFAULT_OUT_DIR})")
    args = parser.parse_args(argv)

    args.out_dir.mkdir(parents=True, exist_ok=True)

    # 1. Fig S6B: Dorsal view of probe entry points in wM1
    if (args.histology_dir / "figS6b_histology_M1.json").exists() or (args.histology_dir / "figS6b_histology_M1.mat").exists():
        print(f"Plotting Figure S6B (Dorsal view of probe entry points in wM1)...")
        fh6.generate_figS6b(args.histology_dir, args.out_dir)

    # 2. Fig S6C: Stimulus-side preference in wM1 by depth
    print(f"Plotting Figure S6C (Stimulus-side preference in wM1 by depth)...")
    plot_figs6c(args.tables_m1, args.resp_csv, args.out_dir)

    # 3. Fig S6D: S1 vs M1 selectivity onset CDF
    print(f"Plotting Figure S6D (S1 vs M1 selectivity onset CDF)...")
    plot_figs6d(args.roc_dir, args.out_dir)

    print(f"Figure S6 completed successfully in: {args.out_dir}")


if __name__ == "__main__":
    main(sys.argv[1:])
