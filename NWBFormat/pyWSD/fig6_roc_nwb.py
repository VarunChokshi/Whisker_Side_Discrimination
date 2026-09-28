"""Figure 6 manuscript panels 6C-F and Figure S8 (M1 Single-Unit ROC).

Generates:
  - Fig 6C: AUC distribution 50ms histograms (WT n=128, KO n=148) with dark gray bars & black text
  - Fig 6D_E: Bootstrapped 5ms selectivity time courses (WT, KO, WT - KO)
  - Fig 6F: Onset of significant side selectivity CDF (0 ~ 80 ms) & KS tests
  - Fig S8: 50ms permutation & bootstrapping test (3x3 grid)
"""

from __future__ import annotations

import argparse
from pathlib import Path
import sys

import matplotlib.pyplot as plt
import numpy as np
from scipy import io as spio
from scipy import stats


DEFAULT_ROC_TABLES = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Data\Tables\ROC"
)
DEFAULT_OUT_DIR = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Figures\Python\Fig6"
)


def load_roc_tables(tables_dir: Path):
    path_50ms = tables_dir / "fig6_roc_tables_M1_50ms.mat"
    path_5ms = tables_dir / "fig6_roc_tables_M1_5ms.mat"

    if not path_50ms.exists() or not path_5ms.exists():
        raise FileNotFoundError(f"Missing M1 ROC tables in {tables_dir}. Run fig6_roc_tables_nwb first.")

    mat_50ms = spio.loadmat(str(path_50ms), simplify_cells=True)["rocTable50ms"]
    mat_5ms = spio.loadmat(str(path_5ms), simplify_cells=True)["rocTable5ms"]
    return mat_50ms, mat_5ms


def plot_fig6c(roc_50ms, out_dir: Path):
    """Figure 6C: AUC distribution 50-ms histograms (Dark gray significant bars, black text)."""
    bin_edges = np.arange(0, 1.05, 0.05)
    bin_centers = (bin_edges[:-1] + bin_edges[1:]) / 2.0
    time_labels = ["-50 ~ 0 ms", "0 ~ 50 ms", "50 ~ 100 ms"]

    for geno in ("WT", "KO"):
        units = roc_50ms[geno]
        n_units = len(units)

        fig, axes = plt.subplots(1, 3, figsize=(5.2, 2.0), dpi=300)

        for b in range(3):
            ax = axes[b]
            auc_means = np.array([u["AUC_mean"][b] for u in units])
            is_sig = np.array([bool(u["isSignificant"][b]) for u in units])
            is_con = np.array([bool(u["isConPref"][b]) for u in units])
            is_ipsi = np.array([bool(u["isIpsiPref"][b]) for u in units])

            sig_con = is_sig & is_con
            sig_ipsi = is_sig & is_ipsi

            counts_all, _ = np.histogram(auc_means, bins=bin_edges)
            counts_con, _ = np.histogram(auc_means[sig_con], bins=bin_edges)
            counts_ipsi, _ = np.histogram(auc_means[sig_ipsi], bins=bin_edges)

            norm_all = counts_all / float(n_units)
            norm_con = counts_con / float(n_units)
            norm_ipsi = counts_ipsi / float(n_units)

            # All units: white bars with black edge
            ax.bar(bin_centers, norm_all, width=0.05, color="white", edgecolor="black", linewidth=0.5)
            # Significant contra units: red bars (alpha 0.6) with black edge
            if np.any(norm_con > 0):
                ax.bar(bin_centers, norm_con, width=0.05, color=(1.0, 0.0, 0.0, 0.6), edgecolor="black", linewidth=0.5)
            # Significant ipsi units: blue bars (alpha 0.6) with black edge
            if np.any(norm_ipsi > 0):
                ax.bar(bin_centers, norm_ipsi, width=0.05, color=(0.0, 0.0, 1.0, 0.6), edgecolor="black", linewidth=0.5)

            con_pct = round(float(np.sum(sig_con)) / n_units * 100.0, 1)
            ipsi_pct = round(float(np.sum(sig_ipsi)) / n_units * 100.0, 1)

            con_str = f"{int(round(con_pct))}%" if con_pct == 0 or con_pct.is_integer() else f"{con_pct:.1f}%"
            ipsi_str = f"{int(round(ipsi_pct))}%" if ipsi_pct == 0 or ipsi_pct.is_integer() else f"{ipsi_pct:.1f}%"

            ax.text(0.75, 0.30, con_str, fontsize=8, fontname="Arial",
                    color="red", ha="center")
            ax.text(0.12, 0.30, ipsi_str, fontsize=8, fontname="Arial",
                    color="blue", ha="center")

            ax.set_xlim(0, 1)
            ax.set_xticks([0, 0.5, 1])
            ax.set_xticklabels(["0", "0.5", "1"])
            ax.set_ylim(0, 0.6)
            ax.set_yticks(np.arange(0, 0.7, 0.2))
            ax.set_ylabel("Proportion of units", fontsize=8, fontname="Arial")
            ax.set_xlabel("AUC", fontsize=8, fontname="Arial")
            ax.set_title(time_labels[b], fontsize=8, fontname="Arial", fontweight="bold")
            ax.tick_params(labelsize=8, direction="out", length=3, width=0.5)
            for sp in ("top", "right"):
                ax.spines[sp].set_visible(False)
            for sp in ax.spines.values():
                sp.set_linewidth(0.5)

        fig.suptitle(f"{geno} n= {n_units} units", fontsize=9, fontname="Arial", y=1.02)
        fig.tight_layout(pad=0.4)

        base_name = f"AUC_histogram_Motor_{geno}_20Hz_50msBin_-50to150ms_1000nBoot_150pvalueMin"
        fig.savefig(out_dir / f"{base_name}.pdf", bbox_inches="tight", pad_inches=0.08)
        fig.savefig(out_dir / f"{base_name}.png", dpi=300, bbox_inches="tight", pad_inches=0.08)
        fig.savefig(out_dir / f"Fig6C - AUC distribution 50ms ({geno}).pdf", bbox_inches="tight", pad_inches=0.08)
        fig.savefig(out_dir / f"Fig6C - AUC distribution 50ms ({geno}).png", dpi=300, bbox_inches="tight", pad_inches=0.08)
        plt.close(fig)


def plot_fig6de(roc_5ms, out_dir: Path):
    """Figure 6D_E: 3-panel bootstrapped 5-ms selectivity time courses matching original PDF."""
    time_ms = np.asarray(roc_5ms["binCenters"], dtype=float) * 1000.0

    sig_pct_con = {}
    sig_pct_ipsi = {}
    boot_con_mean = {}
    boot_ipsi_mean = {}
    ci_con = {}
    ci_ipsi = {}

    for geno in ("WT", "KO"):
        units = roc_5ms[geno]
        n_units = len(units)

        boot_con_mat = np.zeros((1000, 40))
        boot_ipsi_mat = np.zeros((1000, 40))

        # Real percentages
        c_pct = np.zeros(40)
        i_pct = np.zeros(40)
        for b in range(40):
            c_cnt = sum(1 for u in units if u["isSignificant"][b] and u["isConPref"][b])
            i_cnt = sum(1 for u in units if u["isSignificant"][b] and u["isIpsiPref"][b])
            c_pct[b] = round(c_cnt / float(n_units) * 100.0, 1)
            i_pct[b] = round(i_cnt / float(n_units) * 100.0, 1)

        sig_pct_con[geno] = c_pct
        sig_pct_ipsi[geno] = i_pct

        # Bootstrap resampling
        rng = np.random.default_rng(42)
        for boot in range(1000):
            sample_idx = rng.integers(0, n_units, size=n_units)
            for b in range(40):
                c_cnt = 0
                i_cnt = 0
                for idx in sample_idx:
                    u = units[idx]
                    if u["isSignificant"][b] and u["isConPref"][b]:
                        c_cnt += 1
                    elif u["isSignificant"][b] and u["isIpsiPref"][b]:
                        i_cnt += 1
                boot_con_mat[boot, b] = round(c_cnt / float(n_units) * 100.0, 1)
                boot_ipsi_mat[boot, b] = round(i_cnt / float(n_units) * 100.0, 1)

        boot_con_mean[geno] = np.mean(boot_con_mat, axis=0)
        boot_ipsi_mean[geno] = np.mean(boot_ipsi_mat, axis=0)
        ci_con[geno] = np.percentile(boot_con_mat, [2.5, 97.5], axis=0)
        ci_ipsi[geno] = np.percentile(boot_ipsi_mat, [2.5, 97.5], axis=0)

    # 3-Panel Plot: WT (2,2,1), KO (2,2,3), Diff (2,2,2)
    fig, axes = plt.subplots(2, 2, figsize=(3.2, 4.2), dpi=300)

    # Subplot (2, 2, 1): WT
    ax_wt = axes[0, 0]
    ax_wt.axhline(0, color="black", linestyle="-", linewidth=1.0)
    ax_wt.fill_between(time_ms, ci_con["WT"][0] / 100.0, ci_con["WT"][1] / 100.0,
                       color="red", alpha=0.35, edgecolor="none")
    ax_wt.fill_between(time_ms, ci_ipsi["WT"][0] / 100.0, ci_ipsi["WT"][1] / 100.0,
                       color="blue", alpha=0.35, edgecolor="none")
    ax_wt.plot(time_ms, sig_pct_con["WT"] / 100.0, color="red", linewidth=1.0)
    ax_wt.plot(time_ms, sig_pct_ipsi["WT"] / 100.0, color="blue", linewidth=1.0)
    ax_wt.set_xlim(-10, 100)
    ax_wt.set_xticks([0, 50, 100])
    ax_wt.set_ylim(-0.02, 0.20)
    ax_wt.set_yticks(np.arange(0, 0.25, 0.05))
    ax_wt.set_ylabel("Fraction of units", fontsize=8, fontname="Arial")
    ax_wt.set_xlabel("Time from stimulus onset (ms)", fontsize=8, fontname="Arial")
    ax_wt.tick_params(labelsize=8, direction="out", length=3, width=0.5)
    for sp in ("top", "right"):
        ax_wt.spines[sp].set_visible(False)

    # Subplot (2, 2, 3): KO
    ax_ko = axes[1, 0]
    ax_ko.axhline(0, color="black", linestyle="-", linewidth=1.0)
    ax_ko.fill_between(time_ms, ci_con["KO"][0] / 100.0, ci_con["KO"][1] / 100.0,
                       color="red", alpha=0.35, edgecolor="none")
    ax_ko.fill_between(time_ms, ci_ipsi["KO"][0] / 100.0, ci_ipsi["KO"][1] / 100.0,
                       color="blue", alpha=0.35, edgecolor="none")
    ax_ko.plot(time_ms, sig_pct_con["KO"] / 100.0, color="red", linewidth=1.0)
    ax_ko.plot(time_ms, sig_pct_ipsi["KO"] / 100.0, color="blue", linewidth=1.0)
    ax_ko.set_xlim(-10, 100)
    ax_ko.set_xticks([0, 50, 100])
    ax_ko.set_ylim(-0.02, 0.20)
    ax_ko.set_yticks(np.arange(0, 0.25, 0.05))
    ax_ko.set_ylabel("Fraction of units", fontsize=8, fontname="Arial")
    ax_ko.set_xlabel("Time from stimulus onset (ms)", fontsize=8, fontname="Arial")
    ax_ko.tick_params(labelsize=8, direction="out", length=3, width=0.5)
    for sp in ("top", "right"):
        ax_ko.spines[sp].set_visible(False)

    # Subplot (2, 2, 2): Difference WT - KO
    ax_diff = axes[0, 1]
    ax_diff.axhline(0, color="black", linestyle="-", linewidth=1.0)
    diff_con = (sig_pct_con["WT"] - sig_pct_con["KO"]) / 100.0
    diff_ipsi = (sig_pct_ipsi["WT"] - sig_pct_ipsi["KO"]) / 100.0
    ci_diff_con = np.array([(ci_con["WT"][0] - ci_con["KO"][1]) / 100.0, (ci_con["WT"][1] - ci_con["KO"][0]) / 100.0])
    ci_diff_ipsi = np.array([(ci_ipsi["WT"][0] - ci_ipsi["KO"][1]) / 100.0, (ci_ipsi["WT"][1] - ci_ipsi["KO"][0]) / 100.0])

    ax_diff.fill_between(time_ms, ci_diff_con[0], ci_diff_con[1],
                         color="red", alpha=0.35, edgecolor="none")
    ax_diff.fill_between(time_ms, ci_diff_ipsi[0], ci_diff_ipsi[1],
                         color="blue", alpha=0.35, edgecolor="none")
    ax_diff.plot(time_ms, diff_con, color="red", linewidth=1.0)
    ax_diff.plot(time_ms, diff_ipsi, color="blue", linewidth=1.0)
    ax_diff.set_xlim(-10, 100)
    ax_diff.set_xticks([0, 50, 100])
    ax_diff.set_ylim(-0.15, 0.15)
    ax_diff.set_yticks(np.arange(-0.15, 0.16, 0.075))
    ax_diff.set_ylabel("Fraction of units", fontsize=8, fontname="Arial")
    ax_diff.set_xlabel("Time from stimulus onset (ms)", fontsize=8, fontname="Arial")
    ax_diff.tick_params(labelsize=8, direction="out", length=3, width=0.5)
    for sp in ("top", "right"):
        ax_diff.spines[sp].set_visible(False)

    # Subplot (2, 2, 4): Blank
    axes[1, 1].axis("off")

    fig.tight_layout(pad=0.4)
    base_name = "PercentageSigUnit_Motor_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMinbootstrapped"
    fig.savefig(out_dir / f"{base_name}.pdf", bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_dir / f"{base_name}.png", dpi=300, bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_dir / "Fig6D_E - Percentage selective units 5ms bootstrapped.pdf", bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_dir / "Fig6D_E - Percentage selective units 5ms bootstrapped.png", dpi=300, bbox_inches="tight", pad_inches=0.08)
    plt.close(fig)


def plot_fig6f(roc_5ms, out_dir: Path):
    """Figure 6F: Selectivity onset CDF matching attached original PDF exactly."""
    stat_data = {}
    fig, ax = plt.subplots(figsize=(2.0, 1.8), dpi=300)

    for g_idx, geno in enumerate(("WT", "KO")):
        units = roc_5ms[geno]
        n_units = len(units)
        alpha_bonf = 0.05 / n_units

        bin_start = 10 # 0-indexed: corresponds to MATLAB 11 (t=0 ms)
        bin_end = 40   # t=150 ms

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

            # Find first 3 consecutive significant bins
            mat = np.vstack([is_sig_bin, np.append(is_sig_bin[1:], False), np.append(is_sig_bin[2:], [False, False])])
            three_bins = np.sum(mat, axis=0) == 3
            first_idx = np.where(three_bins)[0]

            if len(first_idx) > 0:
                first_bin = first_idx[0]
                onset_ms = first_bin * 5 # (sig_onset_bin - 1) * 5
                new_bin = first_bin + bin_start
                m_val = float(np.mean(auc_boots[new_bin : new_bin + 3, :]))
                sig_onsets.append(onset_ms)
                is_con_list.append(m_val > 0.5)
                is_ipsi_list.append(m_val < 0.5)

        sig_onsets = np.array(sig_onsets)
        is_con_arr = np.array(is_con_list)
        is_ipsi_arr = np.array(is_ipsi_list)

        wt_c = sig_onsets[is_con_arr]
        wt_i = sig_onsets[is_ipsi_arr]
        stat_data[f"{geno}_con"] = wt_c
        stat_data[f"{geno}_ipsi"] = wt_i

        line_style = "-" if geno == "WT" else "--"
        line_width = 0.5 if geno == "WT" else 1.0

        if len(wt_c) > 0:
            x_sorted = np.sort(wt_c)
            y = np.arange(1, len(x_sorted) + 1) / float(len(x_sorted))
            ax.step(np.concatenate(([0], x_sorted)), np.concatenate(([0], y)),
                    where="post", color="red", linestyle=line_style, linewidth=line_width)

        if len(wt_i) > 0:
            x_sorted = np.sort(wt_i)
            y = np.arange(1, len(x_sorted) + 1) / float(len(x_sorted))
            ax.step(np.concatenate(([0], x_sorted)), np.concatenate(([0], y)),
                    where="post", color="blue", linestyle=line_style, linewidth=line_width)
        else:
            ax.axhline(0, color="blue", linestyle=line_style, linewidth=line_width)

    ax.set_xlim(0, 80)
    ax.set_xticks(np.arange(0, 81, 20))
    ax.set_ylim(0, 1.0)
    ax.set_yticks(np.arange(0, 1.1, 0.2))
    ax.set_xlabel("Onset of significant side selectivity (ms)", fontsize=8, fontname="Arial")
    ax.set_ylabel("Proportion of units", fontsize=8, fontname="Arial")
    ax.tick_params(labelsize=8, direction="out", length=3, width=0.5)
    for sp in ("top", "right"):
        ax.spines[sp].set_visible(False)
    for sp in ax.spines.values():
        sp.set_linewidth(0.5)

    fig.tight_layout(pad=0.3)

    # Compute Kolmogorov-Smirnov statistics
    stat_file = out_dir / "StatisticsSelectivityOnset.txt"
    wt_c = stat_data["WT_con"]
    wt_i = stat_data["WT_ipsi"]
    ko_c = stat_data["KO_con"]
    ko_i = stat_data["KO_ipsi"]

    res_con = stats.ks_2samp(wt_c, ko_c, alternative="two-sided")
    res_ko = stats.ks_2samp(ko_c, ko_i, alternative="greater")
    res_wt_ko = stats.ks_2samp(wt_c, ko_i, alternative="greater")

    with open(stat_file, "w", encoding="utf-8") as f:
        f.write(f"Contra two-sided ks test WT != KO pval: {res_con.pvalue:.5f}\n")
        f.write(f"KO one-sided ks test contra < ipsi pval: {res_ko.pvalue:.5f}\n")
        f.write(f"one-sided ks test WT contra < KO ipsi pval: {res_wt_ko.pvalue:.7f}\n")

    base_name = "SigOnset_Motor_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin"
    fig.savefig(out_dir / f"{base_name}.pdf", bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_dir / f"{base_name}.png", dpi=300, bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_dir / "Fig6F - Time course of selectivity onset CDF.pdf", bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_dir / "Fig6F - Time course of selectivity onset CDF.png", dpi=300, bbox_inches="tight", pad_inches=0.08)
    plt.close(fig)


def plot_figs8(roc_50ms, out_dir: Path):
    """Figure S8: 50-ms bin bootstrapping confidence intervals (3x3 grid)."""
    bin_names = ["-50 ~ 0 ms", "0 ~ 50 ms", "50 ~ 100 ms"]
    stim_names = ["Ipsi", "Contra"]
    purple = (0.5, 0.0, 0.5)

    sig_con_over = np.zeros((2, 3))
    sig_ipsi_over = np.zeros((2, 3))
    sig_con_boot = {}
    sig_ipsi_boot = {}

    for g_idx, geno in enumerate(("WT", "KO")):
        units = roc_50ms[geno]
        n_units = len(units)

        boot_con_mat = np.zeros((1000, 3))
        boot_ipsi_mat = np.zeros((1000, 3))

        for b in range(3):
            c_cnt = sum(1 for u in units if u["isSignificant"][b] and u["isConPref"][b])
            i_cnt = sum(1 for u in units if u["isSignificant"][b] and u["isIpsiPref"][b])
            sig_con_over[g_idx, b] = round(c_cnt / float(n_units) * 100.0, 1)
            sig_ipsi_over[g_idx, b] = round(i_cnt / float(n_units) * 100.0, 1)

        rng = np.random.default_rng(42)
        for boot in range(1000):
            sample_idx = rng.integers(0, n_units, size=n_units)
            for b in range(3):
                cC = 0
                iC = 0
                for idx in sample_idx:
                    u = units[idx]
                    if u["isSignificant"][b] and u["isConPref"][b]:
                        cC += 1
                    elif u["isSignificant"][b] and u["isIpsiPref"][b]:
                        iC += 1
                boot_con_mat[boot, b] = round(cC / float(n_units) * 100.0, 1)
                boot_ipsi_mat[boot, b] = round(iC / float(n_units) * 100.0, 1)

        sig_con_boot[geno] = boot_con_mat
        sig_ipsi_boot[geno] = boot_ipsi_mat

    fig, axes = plt.subplots(3, 3, figsize=(4.0, 4.0), dpi=300)
    stat_lines = []

    # Rows 1 & 2: WT and KO
    for g_idx, geno in enumerate(("WT", "KO")):
        for b in range(3):
            ax = axes[g_idx, b]
            for s_idx in range(2):
                stim_x = s_idx + 1
                if s_idx == 0:
                    mean_val = sig_ipsi_over[g_idx, b]
                    boot_vals = np.sort(sig_ipsi_boot[geno][:, b])
                    s_name = "Ipsi"
                else:
                    mean_val = sig_con_over[g_idx, b]
                    boot_vals = np.sort(sig_con_boot[geno][:, b])
                    s_name = "Contra"

                low_95 = boot_vals[24]
                up_95 = boot_vals[974]

                ax.errorbar(stim_x, mean_val, yerr=[[mean_val - low_95], [up_95 - mean_val]],
                            fmt="o", color=purple, markerfacecolor=purple, markersize=4,
                            capsize=3, elinewidth=0.8)

                stat_lines.append(f"For Motor {geno} {s_name} {bin_names[b]}: real CI is {low_95:.1f} to {up_95:.1f}\n")

            ax.axhline(0, color=(0.5, 0.5, 0.5), linestyle="--", linewidth=0.5)
            ax.set_xlim(0.5, 2.5)
            ax.set_xticks([1, 2])
            ax.set_xticklabels(stim_names)
            ax.set_ylim(-5, 30)
            ax.set_yticks(np.arange(0, 31, 10))
            ax.tick_params(labelsize=8, direction="out", length=3, width=0.5)
            for sp in ("top", "right"):
                ax.spines[sp].set_visible(False)
            for sp in ax.spines.values():
                sp.set_linewidth(0.5)

            if b == 0:
                ax.set_ylabel("Percent units", fontsize=8, fontname="Arial")
            if g_idx == 0:
                ax.set_title(bin_names[b], fontsize=8, fontname="Arial", fontweight="normal")

    # Row 3: Difference WT - KO
    for b in range(3):
        ax = axes[2, b]
        for s_idx in range(2):
            stim_x = s_idx + 1
            if s_idx == 0:
                mean_val = sig_ipsi_over[0, b] - sig_ipsi_over[1, b]
                boot_vals = np.sort(sig_ipsi_boot["WT"][:, b] - sig_ipsi_boot["KO"][:, b])
                s_name = "Ipsi"
            else:
                mean_val = sig_con_over[0, b] - sig_con_over[1, b]
                boot_vals = np.sort(sig_con_boot["WT"][:, b] - sig_con_boot["KO"][:, b])
                s_name = "Contra"

            low_95 = boot_vals[24]
            up_95 = boot_vals[974]

            ax.errorbar(stim_x, mean_val, yerr=[[mean_val - low_95], [up_95 - mean_val]],
                        fmt="o", color=purple, markerfacecolor=purple, markersize=4,
                        capsize=3, elinewidth=0.8)

            stat_lines.append(f"For Motor WT-KO {s_name} {bin_names[b]}: real CI is {low_95:.1f} to {up_95:.1f}\n")

        ax.axhline(0, color=(0.5, 0.5, 0.5), linestyle="--", linewidth=0.5)
        ax.set_xlim(0.5, 2.5)
        ax.set_xticks([1, 2])
        ax.set_xticklabels(stim_names)
        ax.set_ylim(-30, 30)
        ax.set_yticks(np.arange(-30, 31, 15))
        ax.tick_params(labelsize=8, direction="out", length=3, width=0.5)
        for sp in ("top", "right"):
            ax.spines[sp].set_visible(False)
        for sp in ax.spines.values():
            sp.set_linewidth(0.5)

        if b == 0:
            ax.set_ylabel(r"$\Delta$ Percent units", fontsize=8, fontname="Arial")

    with open(out_dir / "Statistics_permutationtest.txt", "w", encoding="utf-8") as f:
        f.writelines(stat_lines)

    fig.tight_layout(pad=0.4)
    base_name = "ROC_permutation_Motor_KO_20Hz_50msBin_-50to150ms_3respMin"
    fig.savefig(out_dir / f"{base_name}.pdf", bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_dir / f"{base_name}.png", dpi=300, bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_dir / "FigS8 - ROC permutation test 50ms.pdf", bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_dir / "FigS8 - ROC permutation test 50ms.png", dpi=300, bbox_inches="tight", pad_inches=0.08)
    plt.close(fig)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Plot Figure 6 Single-Unit ROC panels.")
    parser.add_argument("--tables-dir", type=Path, default=DEFAULT_ROC_TABLES,
                        help=f"Path to staged M1 ROC tables (default: {DEFAULT_ROC_TABLES})")
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR,
                        help=f"Output figures directory (default: {DEFAULT_OUT_DIR})")
    args = parser.parse_args(argv)

    args.out_dir.mkdir(parents=True, exist_ok=True)

    print(f"Loading M1 ROC tables from: {args.tables_dir}")
    roc_50ms, roc_5ms = load_roc_tables(args.tables_dir)

    print("Plotting Figure 6C (50ms AUC Distribution Histograms)...")
    plot_fig6c(roc_50ms, args.out_dir)

    print("Plotting Figure 6D_E (5ms Bootstrapped Selectivity Time Courses)...")
    plot_fig6de(roc_5ms, args.out_dir)

    print("Plotting Figure 6F (Selectivity Onset Latency CDF & KS tests)...")
    plot_fig6f(roc_5ms, args.out_dir)

    print("Plotting Figure S8 (50ms Bootstrapping CI)...")
    plot_figs8(roc_50ms, args.out_dir)

    print(f"Figure 6 ROC plots completed successfully in: {args.out_dir}")


if __name__ == "__main__":
    main(sys.argv[1:])
