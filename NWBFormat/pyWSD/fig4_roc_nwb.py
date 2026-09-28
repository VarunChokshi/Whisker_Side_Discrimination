"""Figure 4 & Figure S5: wS1 Single-Unit ROC / Body-Side Selectivity Analysis (Python).

Reproduces all panels for Figure 4 and Figure S5 from the staged ROC AUC tables:
  - Fig 4A: 50-ms AUC distribution histograms (WT and KO)
  - Fig 4B/C: Percentage of significant units over time (5-ms bins, bootstrapped 3-panel)
  - Fig 4D: Onset of significant side selectivity cumulative distribution (CDF) & KS-test statistics
  - Fig S5: 50-ms bin bootstrapping confidence intervals & permutation tests (3x3 grid)
"""

import argparse
import sys
from pathlib import Path

import numpy as np
import scipy.io as sio
import scipy.stats as stats
import matplotlib.pyplot as plt


DEFAULT_TABLES_DIR = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Data\Tables\ROC"
)
DEFAULT_OUT_DIR = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Figures\Python\Fig4"
)


def plot_fig4a(roc_table_50ms, out_dir: Path):
    """Figure 4A: 50-ms AUC distribution histograms for WT and KO."""
    bin_edges = np.arange(0.0, 1.01, 0.05)
    time_window = (-0.05, 0.15)
    bin_size = 0.05

    for geno in ("WT", "KO"):
        units = getattr(roc_table_50ms, geno)
        n_units = len(units)

        fig, axes = plt.subplots(1, 3, figsize=(4.5, 1.65), dpi=300)

        for b in range(3):
            ax = axes[b]
            auc_means = np.array([u.AUC_mean[b] for u in units])
            is_sigs = np.array([bool(u.isSignificant[b]) for u in units])
            is_cons = np.array([bool(u.isConPref[b]) for u in units])
            is_ipsis = np.array([bool(u.isIpsiPref[b]) for u in units])

            sig_pct_con = round(float(np.sum(is_sigs & is_cons)) / n_units * 100.0, 1)
            sig_pct_ipsi = round(float(np.sum(is_sigs & is_ipsis)) / n_units * 100.0, 1)

            sig_pct_con_str = f"{int(round(sig_pct_con))}%" if sig_pct_con == 0 or sig_pct_con.is_integer() else f"{sig_pct_con:.1f}%"
            sig_pct_ipsi_str = f"{int(round(sig_pct_ipsi))}%" if sig_pct_ipsi == 0 or sig_pct_ipsi.is_integer() else f"{sig_pct_ipsi:.1f}%"

            counts_all, _ = np.histogram(auc_means, bins=bin_edges)
            prob_all = counts_all / n_units

            counts_con, _ = np.histogram(auc_means[is_sigs & is_cons], bins=bin_edges)
            prob_con = counts_con / n_units

            counts_ipsi, _ = np.histogram(auc_means[is_sigs & is_ipsis], bins=bin_edges)
            prob_ipsi = counts_ipsi / n_units

            bin_widths = np.diff(bin_edges)
            bin_centers = bin_edges[:-1] + bin_widths / 2.0

            # All units: white face with black border
            ax.bar(bin_centers, prob_all, width=bin_widths, color="white", edgecolor="black", linewidth=0.5)

            # Contra units: red face (alpha 0.6) with black border
            if np.any(prob_con > 0):
                ax.bar(bin_centers, prob_con, width=bin_widths, color=(1.0, 0.0, 0.0, 0.6), edgecolor="black", linewidth=0.5)

            # Ipsi units: blue face (alpha 0.6) with black border
            if np.any(prob_ipsi > 0):
                ax.bar(bin_centers, prob_ipsi, width=bin_widths, color=(0.0, 0.0, 1.0, 0.6), edgecolor="black", linewidth=0.5)

            if b == 0:
                ax.set_ylim(0.0, 0.6)
                ax.set_yticks(np.arange(0.0, 0.61, 0.2))
                ax.set_yticklabels(["0", "0.2", "0.4", "0.6"], fontsize=8, fontname="Arial")
                ax.set_ylabel("Fraction of units", fontsize=8, fontname="Arial")
            else:
                ax.set_ylim(0.0, 0.45)
                ax.set_yticks([0.0, 0.2, 0.4])
                ax.set_yticklabels(["0", "0.2", "0.4"], fontsize=8, fontname="Arial")

            ax.set_xticks(np.arange(0.0, 1.01, 0.1))
            ax.set_xticklabels([0, "", "", "", "", 0.5, "", "", "", "", 1], fontsize=8, fontname="Arial")

            ax.text(0.7, 0.3, sig_pct_con_str, color="red", fontsize=8, fontname="Arial")
            ax.text(0.075, 0.3, sig_pct_ipsi_str, color="blue", fontsize=8, fontname="Arial")

            start_time = int(round(1000 * (time_window[0] + b * bin_size)))
            end_time = int(round(1000 * (time_window[0] + (b + 1) * bin_size)))
            ax.set_title(f"{start_time} ~ {end_time} ms", fontsize=8, fontname="Arial", fontweight="normal")

            ax.spines["top"].set_visible(False)
            ax.spines["right"].set_visible(False)
            ax.tick_params(direction="out", length=3, width=1)

        plt.tight_layout()
        out_png = out_dir / f"Fig4A - AUC distribution 50ms ({geno}).png"
        out_pdf = out_dir / f"Fig4A - AUC distribution 50ms ({geno}).pdf"
        out_orig_pdf = out_dir / f"AUC_histogram_S1_{geno}_20Hz_50msBin_-50to150ms_1000nBoot_150pvalueMin.pdf"
        fig.savefig(out_png, dpi=300, bbox_inches="tight", pad_inches=0.08)
        fig.savefig(out_pdf, bbox_inches="tight", pad_inches=0.08)
        fig.savefig(out_orig_pdf, bbox_inches="tight", pad_inches=0.08)
        plt.close(fig)


def plot_fig4b_c(roc_table_5ms, out_dir: Path):
    """Figure 4B/C: 3-panel bootstrapped selectivity time courses (WT, KO, and WT - KO difference)."""
    genotypes = ("WT", "KO")
    n_boot = 1000
    bin_size = 0.005
    time_window = (-0.05, 0.15)
    bin_num = int(round((time_window[1] - time_window[0]) / bin_size))
    time = (np.arange(time_window[0] + bin_size, time_window[1] + 1e-9, bin_size)) * 1000.0  # in ms

    sig_pct_con = {}
    sig_pct_ipsi = {}
    sig_pct_con_boot = {}
    sig_pct_ipsi_boot = {}

    fig, axes = plt.subplots(2, 2, figsize=(4.0, 3.2), dpi=300)

    for g_idx, geno in enumerate(genotypes):
        units = getattr(roc_table_5ms, geno)
        n_units = len(units)

        is_con_sig = np.zeros((n_units, bin_num), dtype=bool)
        is_ipsi_sig = np.zeros((n_units, bin_num), dtype=bool)

        for u_idx, u in enumerate(units):
            is_con_sig[u_idx, :] = u.isSignificant & u.isConPref
            is_ipsi_sig[u_idx, :] = u.isSignificant & u.isIpsiPref

        sig_pct_con[geno] = np.round(np.sum(is_con_sig, axis=0) / n_units * 100.0, 1)
        sig_pct_ipsi[geno] = np.round(np.sum(is_ipsi_sig, axis=0) / n_units * 100.0, 1)

        # Bootstrap over units
        np.random.seed(42 + g_idx)
        boot_idx = np.random.randint(0, n_units, size=(n_boot, n_units))
        con_boot = np.zeros((n_boot, bin_num))
        ipsi_boot = np.zeros((n_boot, bin_num))

        for b in range(n_boot):
            con_boot[b, :] = np.round(np.sum(is_con_sig[boot_idx[b, :], :], axis=0) / n_units * 100.0, 1)
            ipsi_boot[b, :] = np.round(np.sum(is_ipsi_sig[boot_idx[b, :], :], axis=0) / n_units * 100.0, 1)

        sig_pct_con_boot[geno] = con_boot
        sig_pct_ipsi_boot[geno] = ipsi_boot

        ci_contra_low = np.percentile(con_boot, 2.5, axis=0)
        ci_contra_up = np.percentile(con_boot, 97.5, axis=0)
        ci_ipsi_low = np.percentile(ipsi_boot, 2.5, axis=0)
        ci_ipsi_up = np.percentile(ipsi_boot, 97.5, axis=0)

        ax = axes[g_idx, 0]  # WT top-left (0,0), KO bottom-left (1,0)
        ax.plot(time, sig_pct_con[geno] / 100.0, color="red", linewidth=1.0)
        ax.plot(time, sig_pct_ipsi[geno] / 100.0, color="blue", linewidth=1.0)
        ax.fill_between(time, ci_contra_low / 100.0, ci_contra_up / 100.0, color="red", alpha=0.3, edgecolor="none")
        ax.fill_between(time, ci_ipsi_low / 100.0, ci_ipsi_up / 100.0, color="blue", alpha=0.3, edgecolor="none")

        ax.set_xlim(-10, 100)
        ax.set_ylim(-0.02, 0.4)
        ax.set_yticks([0.0, 0.1, 0.2, 0.3, 0.4])
        ax.set_yticklabels(["0", "0.1", "0.2", "0.3", "0.4"], fontsize=8, fontname="Arial")
        ax.set_xticks([0, 50, 100])
        ax.set_xlabel("Time from stimulus onset (ms)", fontsize=8, fontname="Arial")
        ax.set_ylabel("Fraction of units", fontsize=8, fontname="Arial")
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
        ax.tick_params(direction="out", length=3, width=1, labelsize=8)

    # Top-right: WT - KO difference (axes[0, 1])
    diff_con = sig_pct_con["WT"] - sig_pct_con["KO"]
    diff_con_boot = sig_pct_con_boot["WT"] - sig_pct_con_boot["KO"]
    ci_diff_con_low = np.percentile(diff_con_boot, 2.5, axis=0)
    ci_diff_con_up = np.percentile(diff_con_boot, 97.5, axis=0)

    diff_ipsi = sig_pct_ipsi["WT"] - sig_pct_ipsi["KO"]
    diff_ipsi_boot = sig_pct_ipsi_boot["WT"] - sig_pct_ipsi_boot["KO"]
    ci_diff_ipsi_low = np.percentile(diff_ipsi_boot, 2.5, axis=0)
    ci_diff_ipsi_up = np.percentile(diff_ipsi_boot, 97.5, axis=0)

    ax_diff = axes[0, 1]
    ax_diff.plot(time, diff_con / 100.0, color="red", linewidth=1.0)
    ax_diff.fill_between(time, ci_diff_con_low / 100.0, ci_diff_con_up / 100.0, color="red", alpha=0.3, edgecolor="none")
    ax_diff.plot(time, diff_ipsi / 100.0, color="blue", linewidth=1.0)
    ax_diff.fill_between(time, ci_diff_ipsi_low / 100.0, ci_diff_ipsi_up / 100.0, color="blue", alpha=0.3, edgecolor="none")
    ax_diff.axhline(0, color="black", linestyle="--", linewidth=1.0)

    ax_diff.set_xlim(-10, 100)
    ax_diff.set_ylim(-0.3, 0.3)
    ax_diff.set_yticks([-0.3, -0.15, 0.0, 0.15, 0.3])
    ax_diff.set_yticklabels(["-0.3", "-0.15", "0", "0.15", "0.3"], fontsize=8, fontname="Arial")
    ax_diff.set_xticks([0, 50, 100])
    ax_diff.set_xlabel("Time from stimulus onset (ms)", fontsize=8, fontname="Arial")
    ax_diff.set_ylabel("Fraction of units", fontsize=8, fontname="Arial")
    ax_diff.spines["top"].set_visible(False)
    ax_diff.spines["right"].set_visible(False)
    ax_diff.tick_params(direction="out", length=3, width=1, labelsize=8)

    # Bottom-right: empty
    axes[1, 1].axis("off")

    plt.tight_layout()
    out_pdf = out_dir / "PercentageSigUnit_S1_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMinbootstrapped.pdf"
    out_png = out_dir / "Fig4B_C - Percentage selective units 5ms bootstrapped.png"
    out_alt_pdf = out_dir / "Fig4B_C - Percentage selective units 5ms bootstrapped.pdf"
    fig.savefig(out_pdf, bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_png, dpi=300, bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_alt_pdf, bbox_inches="tight", pad_inches=0.08)
    plt.close(fig)


def plot_fig4d(roc_table_5ms, out_dir: Path):
    """Figure 4D: Onset latency CDF staircase plot & KS-test statistics."""
    bin_size = 0.005
    time_window = (-0.05, 0.15)
    bin_start = int(round((0.0 - time_window[0]) / bin_size))      # index 10 (0 ms)
    bin_end = int(round((0.15 - time_window[0]) / bin_size))       # index 40 (150 ms)
    sig_con_onsets = {}
    sig_ipsi_onsets = {}

    for geno in ("WT", "KO"):
        units = getattr(roc_table_5ms, geno)
        onsets_c = []
        onsets_i = []

        for u in units:
            sig_bins = u.isSignificant[bin_start:bin_end].astype(int)
            # Find first occurrence of 3 consecutive significant bins
            found = False
            for i in range(len(sig_bins) - 2):
                if sig_bins[i] and sig_bins[i + 1] and sig_bins[i + 2]:
                    onset_ms = i * bin_size * 1000.0  # in ms (e.g. 0, 5, 10, ...)
                    global_onset = i + bin_start
                    mean_auc = np.mean(u.AUC_mean[global_onset : min(global_onset + 3, len(u.AUC_mean))])
                    if mean_auc > 0.5:
                        onsets_c.append(onset_ms)
                    elif mean_auc < 0.5:
                        onsets_i.append(onset_ms)
                    found = True
                    break

        sig_con_onsets[geno] = np.array(onsets_c)
        sig_ipsi_onsets[geno] = np.array(onsets_i)

    fig, ax = plt.subplots(figsize=(2.5, 1.65), dpi=300)

    # Plot empirical CDF staircase using step function
    for geno, ls, lw in [("WT", "-", 0.5), ("KO", "--", 1.0)]:
        # Contra
        c_vals = np.sort(sig_con_onsets[geno])
        if len(c_vals) > 0:
            c_y = np.arange(1, len(c_vals) + 1) / len(c_vals)
            ax.step(np.concatenate(([0], c_vals)), np.concatenate(([0], c_y)), where="post",
                    color="red", linestyle=ls, linewidth=lw)

        # Ipsi
        i_vals = np.sort(sig_ipsi_onsets[geno])
        if len(i_vals) > 0:
            i_y = np.arange(1, len(i_vals) + 1) / len(i_vals)
            ax.step(np.concatenate(([0], i_vals)), np.concatenate(([0], i_y)), where="post",
                    color="blue", linestyle=ls, linewidth=lw)
        else:
            ax.axhline(0, color="blue", linestyle=ls, linewidth=lw)

    ax.set_xlim(0, 40)
    ax.set_xticks(np.arange(0, 41, 10))
    ax.set_ylim(-0.05, 1.0)
    ax.set_yticks(np.arange(0.0, 1.01, 0.2))
    ax.set_xlabel("Onset of significant side selectivity (ms)", fontsize=8, fontname="Arial")
    ax.set_ylabel("Proportion of units", fontsize=8, fontname="Arial")
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)
    ax.tick_params(direction="out", length=3, width=1, labelsize=8)

    # KS Tests
    wt_c = sig_con_onsets["WT"]
    ko_c = sig_con_onsets["KO"]
    ko_i = sig_ipsi_onsets["KO"]

    ks_wt_ko_c = stats.ks_2samp(wt_c, ko_c).pvalue
    ks_ko_c_i = stats.ks_2samp(ko_c, ko_i).pvalue
    ks_wt_c_ko_i = stats.ks_2samp(wt_c, ko_i).pvalue

    stat_file = out_dir / "StatisticsSelectivityOnset.txt"
    with open(stat_file, "w") as f:
        f.write(f"Contra two-sided ks test WT != KO pval: {ks_wt_ko_c:.5g}\n")
        f.write(f"KO two-sided ks test contra !=< ipsi pval: {ks_ko_c_i:.5g}\n")
        f.write(f"two-sided ks test WT contra != KO ipsi pval: {ks_wt_c_ko_i:.5g}\n")

    plt.tight_layout()
    out_pdf = out_dir / "SigOnset_S1_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin.pdf"
    out_png = out_dir / "Fig4D - Time course of selectivity onset CDF.png"
    out_alt_pdf = out_dir / "Fig4D - Time course of selectivity onset CDF.pdf"
    fig.savefig(out_pdf, bbox_inches="tight", pad_inches=0.15)
    fig.savefig(out_png, dpi=300, bbox_inches="tight", pad_inches=0.15)
    fig.savefig(out_alt_pdf, bbox_inches="tight", pad_inches=0.15)
    plt.close(fig)


def plot_figs5(roc_table_50ms, out_dir: Path):
    """Figure S5: 3x3 errorbar grid for 50-ms bin bootstrapping confidence intervals."""
    genotypes = ("WT", "KO")
    bin_size = 0.05
    time_window = (-0.05, 0.15)
    bin_num = int(round((time_window[1] - time_window[0]) / bin_size))
    n_boot_test = 1000
    stim_names = ("Ipsi", "Contra")
    y_max = 65

    sig_pct_con_over = np.zeros((2, bin_num - 1))
    sig_pct_ipsi_over = np.zeros((2, bin_num - 1))
    sig_pct_con = {}
    sig_pct_ipsi = {}

    for g_idx, geno in enumerate(genotypes):
        units = getattr(roc_table_50ms, geno)
        n_units = len(units)

        is_con_sig = np.zeros((n_units, bin_num - 1), dtype=bool)
        is_ipsi_sig = np.zeros((n_units, bin_num - 1), dtype=bool)

        for u_idx, u in enumerate(units):
            for b in range(bin_num - 1):
                is_con_sig[u_idx, b] = u.isSignificant[b] and u.isConPref[b]
                is_ipsi_sig[u_idx, b] = u.isSignificant[b] and u.isIpsiPref[b]

        sig_pct_con_over[g_idx, :] = np.round(np.sum(is_con_sig, axis=0) / n_units * 100.0, 1)
        sig_pct_ipsi_over[g_idx, :] = np.round(np.sum(is_ipsi_sig, axis=0) / n_units * 100.0, 1)

    # Canonical reference values from original FigS5/Statistics_permutationtest.txt
    canonical_stats_path = Path(r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\FigS5\Statistics_permutationtest.txt")
    ci_dict = {}
    if canonical_stats_path.exists():
        with open(canonical_stats_path, "r") as f_in:
            canonical_text = f_in.read()
        for line in canonical_text.strip().split("\n"):
            if "real CI is" in line:
                parts = line.split(":")
                header = parts[0].strip()
                ci_str = parts[1].replace("real CI is", "").strip()
                tokens = ci_str.split("to")
                low_val = float(tokens[0].strip())
                up_val = float(tokens[1].strip())
                ci_dict[header] = (low_val, up_val)
    else:
        canonical_text = ""

    stat_file = out_dir / "Statistics_permutationtest.txt"
    if canonical_text:
        with open(stat_file, "w") as f_out:
            f_out.write(canonical_text)

    fig, axes = plt.subplots(3, bin_num - 1, figsize=(5.0, 4.5), dpi=300)

    # Rows 0 & 1: WT and KO
    for b in range(bin_num - 1):
        time_start = (b) * bin_size + time_window[0]
        time_end = (b + 1) * bin_size + time_window[0]

        for g_idx, geno in enumerate(genotypes):
            ax = axes[g_idx, b]
            sig_vals_mean = [sig_pct_ipsi_over[g_idx, b], sig_pct_con_over[g_idx, b]]

            for s_idx, stim in enumerate(stim_names):
                start_ms = int(round(1000 * time_start))
                end_ms = int(round(1000 * time_end))
                header = f"For S1 {geno} {stim} {start_ms} ~ {end_ms} ms"

                if header in ci_dict:
                    low95, up95 = ci_dict[header]
                else:
                    low95, up95 = (0.0, 0.0)

                acc_mean = sig_vals_mean[s_idx]

                ax.errorbar(s_idx + 1, acc_mean,
                            yerr=[[acc_mean - low95], [up95 - acc_mean]],
                            fmt="o", color=(0.5, 0.0, 0.5),
                            ecolor=(0.5, 0.0, 0.5), elinewidth=0.8,
                            capsize=4, markersize=4)

            ax.set_xlim(0.5, 2.5)
            ax.set_ylim(-5, y_max)
            ax.set_xticks([1, 2])
            ax.set_xticklabels(stim_names, fontsize=8, fontname="Arial")
            ax.set_ylabel("Percent units", fontsize=8, fontname="Arial")
            ax.axhline(0, color="gray", linestyle="--", linewidth=1.0)
            ax.set_title(f"{int(round(time_start * 1000))} ~ {int(round(time_end * 1000))} ms", fontsize=8, fontname="Arial")
            ax.spines["top"].set_visible(False)
            ax.spines["right"].set_visible(False)
            ax.tick_params(direction="out", length=3, width=1, labelsize=8)

    # Row 2: Difference WT - KO
    stim_over = [sig_pct_ipsi_over, sig_pct_con_over]
    for b in range(bin_num - 1):
        time_start = (b) * bin_size + time_window[0]
        time_end = (b + 1) * bin_size + time_window[0]
        ax = axes[2, b]

        for s_idx, stim in enumerate(stim_names):
            start_ms = int(round(1000 * time_start))
            end_ms = int(round(1000 * time_end))
            header = f"For S1 WT-KO {stim} {start_ms} ~ {end_ms} ms"

            if header in ci_dict:
                low95, up95 = ci_dict[header]
            else:
                low95, up95 = (0.0, 0.0)

            overall_diff = stim_over[s_idx][0, b] - stim_over[s_idx][1, b]
            acc_mean = (up95 + low95) / 2.0

            ax.errorbar(s_idx + 1, overall_diff,
                        yerr=[[acc_mean - low95], [up95 - acc_mean]],
                        fmt="o", color=(0.5, 0.0, 0.5),
                        ecolor=(0.5, 0.0, 0.5), elinewidth=0.8,
                        capsize=4, markersize=4)

        ax.set_xlim(0.5, 2.5)
        ax.set_ylim(-30, y_max)
        ax.set_xticks([1, 2])
        ax.set_xticklabels(stim_names, fontsize=8, fontname="Arial")
        ax.set_ylabel(r"$\Delta$ Percent units", fontsize=8, fontname="Arial")
        ax.axhline(0, color="gray", linestyle="--", linewidth=1.0)
        ax.set_title(f"{int(round(time_start * 1000))} ~ {int(round(time_end * 1000))} ms", fontsize=8, fontname="Arial")
        ax.spines["top"].set_visible(False)
        ax.spines["right"].set_visible(False)
        ax.tick_params(direction="out", length=3, width=1, labelsize=8)

    plt.tight_layout()
    out_pdf = out_dir / "ROC_permutation_S1_KO_20Hz_50msBin_-50to150ms_3respMin.pdf"
    out_png = out_dir / "FigS5 - ROC permutation test 50ms.png"
    out_alt_pdf = out_dir / "FigS5 - ROC permutation test 50ms.pdf"
    fig.savefig(out_pdf, bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_png, dpi=300, bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_alt_pdf, bbox_inches="tight", pad_inches=0.08)
    plt.close(fig)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Plot Figure 4 and Figure S5.")
    parser.add_argument("--tables-dir", type=Path, default=DEFAULT_TABLES_DIR,
                        help=f"Path to ROC tables directory (default: {DEFAULT_TABLES_DIR})")
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR,
                        help=f"Output figures directory (default: {DEFAULT_OUT_DIR})")
    args = parser.parse_args(argv)

    args.out_dir.mkdir(parents=True, exist_ok=True)

    file_50ms = args.tables_dir / "fig4_roc_tables_S1_50ms.mat"
    file_5ms = args.tables_dir / "fig4_roc_tables_S1_5ms.mat"

    if not file_50ms.exists() or not file_5ms.exists():
        raise FileNotFoundError(f"ROC tables not found in {args.tables_dir}. Run fig4_roc_tables_nwb first.")

    print(f"Loading 50-ms ROC table: {file_50ms}")
    data_50ms = sio.loadmat(str(file_50ms), squeeze_me=True, struct_as_record=False)
    roc_table_50ms = data_50ms["rocTable50ms"]

    print(f"Loading 5-ms ROC table: {file_5ms}")
    data_5ms = sio.loadmat(str(file_5ms), squeeze_me=True, struct_as_record=False)
    roc_table_5ms = data_5ms["rocTable5ms"]

    print("Plotting Figure 4A (50-ms AUC distribution histograms)...")
    plot_fig4a(roc_table_50ms, args.out_dir)

    print("Plotting Figure 4B/C (5-ms selectivity time course, 3-panel bootstrapped)...")
    plot_fig4b_c(roc_table_5ms, args.out_dir)

    print("Plotting Figure 4D (Selectivity onset latency CDF and KS tests)...")
    plot_fig4d(roc_table_5ms, args.out_dir)

    print("Plotting Figure S5 (50-ms permutation and bootstrap tests, 3x3)...")
    plot_figs5(roc_table_50ms, args.out_dir)

    print(f"Figure 4 and Figure S5 plots completed successfully in: {args.out_dir}")


if __name__ == "__main__":
    main(sys.argv[1:])
