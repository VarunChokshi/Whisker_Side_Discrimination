"""Figure 7: wM1 LDA decoding panels and statistical exports (Python).

Generates:
  - Panel 7A: Session-wise classification accuracy histograms (WT & KO)
  - Panel 7B: Bootstrapped population stimulus discriminability (95% CI)
  - Fig 7 Composite: Full layout matching FinalFig7.png
  - Statistical exports: LDA median values.txt, LDA bootstrapping CI values.txt
"""

import argparse
import json
from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np


DEFAULT_TABLES_DIR = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1"
    r"\NWBData\Data\Tables\LDA"
)
DEFAULT_OUT_DIR = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1"
    r"\NWBData\Figures\Python\Fig7"
)


def load_m1_lda_tables(tables_dir: Path) -> dict:
    """Loads M1 LDA tables from JSON or MAT."""
    json_path = tables_dir / "fig7_lda_tables_M1.json"
    if not json_path.exists():
        raise FileNotFoundError(f"M1 LDA tables not found at {json_path}. Run staging first.")

    with open(json_path, "r") as f:
        return json.load(f)


def plot_fig7a(lda_data: dict, out_dir: Path):
    """Panel 7A: Session-wise accuracy histograms for WT and KO."""
    bin_edges = np.arange(0, 1.025, 0.025)
    bin_centers = (bin_edges[:-1] + bin_edges[1:]) / 2.0
    shuffle_names = ["true", "shuffled"]
    shuffle_colors = [(0.5, 0.0, 0.5), (0.5, 0.5, 0.5)]

    median_txt_path = out_dir / "LDA median values.txt"
    median_lines = []

    for geno in ("WT", "KO"):
        fig, axes = plt.subplots(1, 2, figsize=(3.2, 1.65), dpi=300)
        last_n = 0

        for b in range(2):
            ax = axes[b]
            bin_info = lda_data["bins"][b]
            sess_data = bin_info[geno]

            ca_true = np.asarray(sess_data["LDA_true"], dtype=float)
            ca_shuff = np.asarray(sess_data["LDA_shuffle"], dtype=float)
            last_n = len(ca_true)

            ax.axvline(0.5, color="black", linestyle="--", linewidth=1.0)

            for s_idx, ca in enumerate((ca_true, ca_shuff)):
                col = shuffle_colors[s_idx]
                lw = 1.0 if s_idx == 0 else 0.5

                counts, _ = np.histogram(ca, bins=bin_edges)
                ax.bar(bin_centers, counts, width=0.025, color=col, alpha=0.6,
                       edgecolor=col, linewidth=lw)

                ca_med = float(np.nanmedian(ca))
                center_idx = np.argmin(np.abs(ca_med - bin_centers))
                start_t = bin_info["startTime"]
                end_t = bin_info["endTime"]
                median_lines.append(
                    f"For Motor {geno} {start_t} ~ {end_t} ms: {shuffle_names[s_idx]} median is {ca_med:g}\n"
                )

                ax.plot(bin_centers[center_idx], 7.0, marker="v", markersize=3.5,
                        color=col, markerfacecolor="none", markeredgewidth=1.0)

                if b == 0:
                    ax.text(0.65, 7.5 - 1.0 * (s_idx + 1), shuffle_names[s_idx],
                            color=col, fontsize=8, fontname="Arial")

            ax.set_xlim(0, 1)
            ax.set_xticks(np.arange(0, 1.25, 0.25))
            ax.set_ylim(0, 8)
            ax.set_yticks(np.arange(0, 9, 2))
            ax.tick_params(labelsize=8, direction="out", length=3, width=0.75)
            for sp in ("top", "right"):
                ax.spines[sp].set_visible(False)
            for sp in ax.spines.values():
                sp.set_linewidth(0.75)

            if b == 0:
                ax.set_ylabel("Number of sessions", fontsize=8, fontname="Arial")
            ax.set_title(bin_info["timeLabel"], fontsize=8, fontname="Arial")

        fig.suptitle(f"Motor {geno} n= {last_n} sessions", fontsize=8, fontname="Arial", y=1.05)
        fig.tight_layout(pad=0.3)

        base_name = f"LDA_histogram_Motor_{geno}_20Hz_100msBin_-100to100ms_3respMin"
        fig.savefig(out_dir / f"{base_name}.pdf", bbox_inches="tight", pad_inches=0.04)
        fig.savefig(out_dir / f"{base_name}.png", dpi=300, bbox_inches="tight", pad_inches=0.04)
        fig.savefig(out_dir / f"Fig7A - Session-wise stimulus discriminability ({geno}).pdf", bbox_inches="tight", pad_inches=0.04)
        fig.savefig(out_dir / f"Fig7A - Session-wise stimulus discriminability ({geno}).png", dpi=300, bbox_inches="tight", pad_inches=0.04)
        plt.close(fig)

    with open(median_txt_path, "w") as f:
        f.writelines(median_lines)


def plot_fig7b(lda_data: dict, out_dir: Path):
    """Panel 7B: Bootstrapped population accuracy with 95% CI."""
    shuffle_names = ["true", "shuffled"]
    shuffle_colors = [(0.5, 0.0, 0.5), (0.5, 0.5, 0.5)]
    n_boot = 100

    ci_txt_path = out_dir / "LDA bootstrapping CI values.txt"
    ci_lines = []

    fig, axes = plt.subplots(1, 2, figsize=(3.2, 1.9), dpi=300)

    for b in range(2):
        ax = axes[b]
        bin_info = lda_data["bins"][b]
        ax.axhline(0.5, color="black", linestyle="--", linewidth=1.0)

        for g_idx, geno in enumerate(("WT", "KO")):
            g_num = g_idx + 1
            boot_true = np.asarray(bin_info[geno]["boot_true"], dtype=float)
            boot_shuff = np.asarray(bin_info[geno]["boot_shuffle"], dtype=float)

            for s_idx, raw_boot in enumerate((boot_true, boot_shuff)):
                sorted_acc = np.sort(raw_boot)
                acc_mean = float(np.mean(sorted_acc))
                up_95ci = float(sorted_acc[int(np.floor(0.975 * n_boot + 0.5)) - 1])
                low_95ci = float(sorted_acc[int(np.floor(0.025 * n_boot + 0.5)) - 1])

                x_pos = g_num + (s_idx + 1) * 0.2 - 0.3
                col = shuffle_colors[s_idx]

                yerr = [[acc_mean - low_95ci], [up_95ci - acc_mean]]
                ax.errorbar(x_pos, acc_mean, yerr=yerr, fmt="o",
                            color=col, ecolor=col, mec=col, mfc=col,
                            ms=5, capsize=4, elinewidth=0.75, capthick=0.75)

                start_t = bin_info["startTime"]
                end_t = bin_info["endTime"]
                ci_lines.append(
                    f"For Motor {geno} {start_t} ~ {end_t} ms: {shuffle_names[s_idx]} CI is {low_95ci:g} to {up_95ci:g}\n"
                )

                if b == 0 and g_idx == 0:
                    ax.text(1.5, 0.80 - 0.05 * (s_idx + 1), shuffle_names[s_idx],
                            color=col, fontsize=8, fontname="Arial")

        ax.set_xlim(0.5, 2.5)
        ax.set_xticks([1, 2])
        ax.set_xticklabels(["WT", "KO"], fontsize=8, fontname="Arial")
        ax.set_ylim(0.3, 1.0)
        ax.set_yticks(np.arange(0.4, 1.1, 0.2))
        ax.set_ylabel("Classification accuracy", fontsize=8, fontname="Arial")
        ax.set_title(bin_info["timeLabel"], fontsize=8, fontname="Arial")
        ax.tick_params(labelsize=8, direction="out", length=3, width=0.75)
        for sp in ("top", "right"):
            ax.spines[sp].set_visible(False)
        for sp in ax.spines.values():
            sp.set_linewidth(0.75)

    fig.tight_layout(pad=0.3)

    base_name = "LDA_bootstrapping_Motor_KO_20Hz_100msBin_-100to100ms_3respMin"
    fig.savefig(out_dir / f"{base_name}.pdf", bbox_inches="tight", pad_inches=0.04)
    fig.savefig(out_dir / f"{base_name}.png", dpi=300, bbox_inches="tight", pad_inches=0.04)
    fig.savefig(out_dir / "Fig7B - Bootstrapped population stimulus discriminability.pdf", bbox_inches="tight", pad_inches=0.04)
    fig.savefig(out_dir / "Fig7B - Bootstrapped population stimulus discriminability.png", dpi=300, bbox_inches="tight", pad_inches=0.04)
    plt.close(fig)

    with open(ci_txt_path, "w") as f:
        f.writelines(ci_lines)


def plot_fig7_composite(lda_data: dict, out_dir: Path):
    """Composite Figure 7 matching FinalFig7.png layout."""
    bin_edges = np.arange(0, 1.025, 0.025)
    bin_centers = (bin_edges[:-1] + bin_edges[1:]) / 2.0
    shuffle_names = ["true", "shuffled"]
    shuffle_colors = [(0.5, 0.0, 0.5), (0.5, 0.5, 0.5)]
    n_boot = 100

    fig, axes = plt.subplots(3, 2, figsize=(3.6, 7.0), dpi=300)

    # Row 0: WT session-wise
    for b in range(2):
        ax = axes[0, b]
        bin_info = lda_data["bins"][b]
        sess_data = bin_info["WT"]
        ca_true = np.asarray(sess_data["LDA_true"], dtype=float)
        ca_shuff = np.asarray(sess_data["LDA_shuffle"], dtype=float)

        ax.axvline(0.5, color="black", linestyle="--", linewidth=0.75)
        for s_idx, ca in enumerate((ca_true, ca_shuff)):
            col = shuffle_colors[s_idx]
            lw = 1.0 if s_idx == 0 else 0.5
            counts, _ = np.histogram(ca, bins=bin_edges)
            ax.bar(bin_centers, counts, width=0.025, color=col, alpha=0.6,
                   edgecolor=col, linewidth=lw)
            ca_med = float(np.nanmedian(ca))
            center_idx = np.argmin(np.abs(ca_med - bin_centers))
            ax.plot(bin_centers[center_idx], 7.0, marker="v", markersize=3.5,
                    color=col, markerfacecolor="none", markeredgewidth=1.0)
            if b == 0:
                ax.text(0.65, 7.5 - 1.0 * (s_idx + 1), shuffle_names[s_idx],
                        color=col, fontsize=8, fontname="Arial")

        ax.set_xlim(0, 1)
        ax.set_xticks(np.arange(0, 1.25, 0.25))
        ax.set_xticklabels(["0", "0.25", "0.5", "0.75", "1"], rotation=45, fontsize=8, fontname="Arial")
        ax.set_ylim(0, 8)
        ax.set_yticks(np.arange(0, 9, 2))
        ax.tick_params(labelsize=8, direction="out", length=3, width=0.75)
        for sp in ("top", "right"):
            ax.spines[sp].set_visible(False)
        for sp in ax.spines.values():
            sp.set_linewidth(0.75)
        if b == 0:
            ax.set_ylabel("Number of sessions", fontsize=8, fontname="Arial")
        ax.set_title(bin_info["timeLabel"], fontsize=8, fontname="Arial")

    # Row 1: KO session-wise
    for b in range(2):
        ax = axes[1, b]
        bin_info = lda_data["bins"][b]
        sess_data = bin_info["KO"]
        ca_true = np.asarray(sess_data["LDA_true"], dtype=float)
        ca_shuff = np.asarray(sess_data["LDA_shuffle"], dtype=float)

        ax.axvline(0.5, color="black", linestyle="--", linewidth=0.75)
        for s_idx, ca in enumerate((ca_true, ca_shuff)):
            col = shuffle_colors[s_idx]
            lw = 1.0 if s_idx == 0 else 0.5
            counts, _ = np.histogram(ca, bins=bin_edges)
            ax.bar(bin_centers, counts, width=0.025, color=col, alpha=0.6,
                   edgecolor=col, linewidth=lw)
            ca_med = float(np.nanmedian(ca))
            center_idx = np.argmin(np.abs(ca_med - bin_centers))
            ax.plot(bin_centers[center_idx], 7.0, marker="v", markersize=3.5,
                    color=col, markerfacecolor="none", markeredgewidth=1.0)
            if b == 0:
                ax.text(0.65, 7.5 - 1.0 * (s_idx + 1), shuffle_names[s_idx],
                        color=col, fontsize=8, fontname="Arial")

        ax.set_xlim(0, 1)
        ax.set_xticks(np.arange(0, 1.25, 0.25))
        ax.set_xticklabels(["0", "0.25", "0.5", "0.75", "1"], rotation=45, fontsize=8, fontname="Arial")
        ax.set_ylim(0, 8)
        ax.set_yticks(np.arange(0, 9, 2))
        ax.tick_params(labelsize=8, direction="out", length=3, width=0.75)
        for sp in ("top", "right"):
            ax.spines[sp].set_visible(False)
        for sp in ax.spines.values():
            sp.set_linewidth(0.75)
        if b == 0:
            ax.set_ylabel("Number of sessions", fontsize=8, fontname="Arial")
        ax.set_title(bin_info["timeLabel"], fontsize=8, fontname="Arial")

    # Row 2: Bootstrapped population stimulus-discriminability
    for b in range(2):
        ax = axes[2, b]
        bin_info = lda_data["bins"][b]
        ax.axhline(0.5, color="black", linestyle="--", linewidth=0.75)

        for g_idx, geno in enumerate(("WT", "KO")):
            g_num = g_idx + 1
            boot_true = np.asarray(bin_info[geno]["boot_true"], dtype=float)
            boot_shuff = np.asarray(bin_info[geno]["boot_shuffle"], dtype=float)

            for s_idx, raw_boot in enumerate((boot_true, boot_shuff)):
                sorted_acc = np.sort(raw_boot)
                acc_mean = float(np.mean(sorted_acc))
                up_95ci = float(sorted_acc[int(np.floor(0.975 * n_boot + 0.5)) - 1])
                low_95ci = float(sorted_acc[int(np.floor(0.025 * n_boot + 0.5)) - 1])

                x_pos = g_num + (s_idx + 1) * 0.2 - 0.3
                colorVal = shuffle_colors[s_idx]

                yerr = [[acc_mean - low_95ci], [up_95ci - acc_mean]]
                ax.errorbar(x_pos, acc_mean, yerr=yerr, fmt="o",
                            color=colorVal, ecolor=colorVal, mec=colorVal, mfc=colorVal,
                            ms=5, capsize=4, elinewidth=0.75, capthick=0.75)

                if b == 0 and g_idx == 0:
                    ax.text(1.4, 0.80 - 0.05 * (s_idx + 1), shuffle_names[s_idx],
                            color=colorVal, fontsize=8, fontname="Arial")

        ax.set_xlim(0.5, 2.5)
        ax.set_xticks([1, 2])
        ax.set_xticklabels(["WT", "KO"], fontsize=8, fontname="Arial")
        ax.set_ylim(0.3, 1.0)
        ax.set_yticks(np.arange(0.4, 1.1, 0.2))
        ax.set_ylabel("Classification accuracy", fontsize=8, fontname="Arial")
        ax.set_title(bin_info["timeLabel"], fontsize=8, fontname="Arial")
        ax.tick_params(labelsize=8, direction="out", length=3, width=0.75)
        for sp in ("top", "right"):
            ax.spines[sp].set_visible(False)
        for sp in ax.spines.values():
            sp.set_linewidth(0.75)

    fig.subplots_adjust(left=0.18, right=0.94, top=0.92, bottom=0.08, hspace=0.65, wspace=0.35)
    fig.text(0.55, 0.96, f"WT n= {len(lda_data['bins'][0]['WT']['LDA_true'])} sessions",
             ha="center", fontsize=9, fontname="Arial", color="gray")
    fig.text(0.55, 0.64, f"KO n= {len(lda_data['bins'][1]['KO']['LDA_true'])} sessions",
             ha="center", fontsize=9, fontname="Arial", color="black")
    fig.text(0.55, 0.33, "Classification accuracy",
             ha="center", fontsize=8, fontname="Arial")

    fig.savefig(out_dir / "Fig7 - Whisker-side stimulus discriminability in wM1.pdf", bbox_inches="tight", pad_inches=0.04)
    fig.savefig(out_dir / "Fig7 - Whisker-side stimulus discriminability in wM1.png", dpi=300, bbox_inches="tight", pad_inches=0.04)
    plt.close(fig)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Generate Figure 7 panels (Python).")
    parser.add_argument("--tables-dir", type=Path, default=DEFAULT_TABLES_DIR)
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR)
    args = parser.parse_args(argv)

    args.out_dir.mkdir(parents=True, exist_ok=True)
    lda_data = load_m1_lda_tables(args.tables_dir)

    print("Plotting Figure 7A (Session-wise accuracy histograms)...")
    plot_fig7a(lda_data, args.out_dir)

    print("Plotting Figure 7B (Bootstrapped accuracy with 95% CI)...")
    plot_fig7b(lda_data, args.out_dir)

    print("Plotting Figure 7 Composite (Manuscript layout)...")
    plot_fig7_composite(lda_data, args.out_dir)

    print(f"Figure 7 completed successfully in: {args.out_dir}")


if __name__ == "__main__":
    main()
