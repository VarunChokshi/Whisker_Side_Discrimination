"""Figure 6 panels 6A & 6B (passive-stim wM1 ephys).

Plots:
  - Fig 6A: Normalized spiking rate heatmaps for responsive units (WT n=128, KO n=148)
  - Fig 6B: Population mean spiking rate across 10 Hz, 20 Hz, and 40 Hz for WT and KO
  - Exports: Peak values pop mean FR.txt
"""

from __future__ import annotations

import argparse
from collections import defaultdict
from pathlib import Path
import sys

import matplotlib.colors as mcolors
import matplotlib.pyplot as plt
import numpy as np
import pandas as pd

import fig3_panels_nwb as fp


DEFAULT_M1_MAT = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Data\Tables\fig3_tables_M1.mat"
)
DEFAULT_RESP_CSV = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Data\Tables\ROC\responsive_units_M1.csv"
)
DEFAULT_OUT_DIR = Path(
    r"E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData\Figures\Python\Fig6"
)

STIM_SLOTS = ["10", "20", "40"]
STIM_NAMES = ["10 Hz", "20 Hz", "40 Hz"]
PLOT_XLIMS = (-0.05, 0.10)
MAX_FR = 16.0
CBIAS_CONTRA = 0.33
CBIAS_IPSI = -0.33


def build_m1_unit_table(records, resp_csv: Path) -> list[dict]:
    """Builds unit table for M1 with exact responsive matching to responsive_units_M1.csv."""
    df_resp = pd.read_csv(resp_csv)
    resp_set = set()
    for _, r in df_resp.iterrows():
        m = str(r["mouseName"])
        s = str(r["sessionName"])
        date_str = f"20{s[:2]}-{s[2:4]}-{s[4:]}"
        full_sess = f"{m}_{date_str}"
        u_idx = int(r["unitIndex"])
        resp_set.add((full_sess, u_idx))

    by_unit = defaultdict(dict)
    for r in records:
        # In records, 'unit' is 0-indexed integer; CSV is 1-indexed
        by_unit[(r["session"], r["unit"] + 1)][r["freq"]] = r

    unit_table = []
    for (session, unit_1based), freq_records in by_unit.items():
        first_rec = list(freq_records.values())[0]
        geno = first_rec["genotype"]
        is_resp = (session, unit_1based) in resp_set

        slots = {}
        for freq in STIM_SLOTS:
            source = freq_records.get(freq)
            if source is not None:
                slots[freq] = {
                    "meanContra": source["frContra"].mean(axis=0),
                    "meanIpsi": source["frIpsi"].mean(axis=0),
                    "cbias150": source["perWindow"].get("150", {}).get("cbias", 0.0),
                }

        unit_table.append({
            "session": session,
            "unit": unit_1based,
            "animal": first_rec["animal"],
            "genotype": geno,
            "recSite": first_rec["recSite"],
            "depthRaw": first_rec["depthRaw"],
            "depthNorm": first_rec["depthNorm"],
            "responsive": is_resp,
            "slots": slots,
            "frTime": first_rec["frTime"],
        })

    return unit_table


def plot_fig6a(unit_table: list[dict], out_dir: Path):
    """Figure 6A: Normalized FR heatmaps for WT and KO."""
    fr_time_ms = unit_table[0]["frTime"] * 1000.0

    cmap_contra = mcolors.LinearSegmentedColormap.from_list("white_red", ["white", "red"], N=256)
    cmap_ipsi = mcolors.LinearSegmentedColormap.from_list("white_blue", ["white", "blue"], N=256)
    cmap_resp = mcolors.ListedColormap(["blue", "white", "red"])

    for geno in ("WT", "KO"):
        matching_units = [u for u in unit_table if u["genotype"] == geno and u["responsive"]]
        n_units = len(matching_units)
        if n_units == 0:
            continue

        contra_rows = []
        ipsi_rows = []
        cbias_list = []
        resp_list = []

        for u in matching_units:
            slots = u["slots"]
            if not slots:
                continue
            con_sum = sum(s["meanContra"] for s in slots.values()) / len(slots)
            ip_sum = sum(s["meanIpsi"] for s in slots.values()) / len(slots)
            cb = np.mean([s["cbias150"] for s in slots.values()])

            if cb >= CBIAS_CONTRA:
                resp_id = 1
            elif cb < CBIAS_IPSI:
                resp_id = -1
            else:
                resp_id = 0

            contra_rows.append(con_sum)
            ipsi_rows.append(ip_sum)
            cbias_list.append(cb)
            resp_list.append(resp_id)

        # Sort: contra preference, neutral, ipsi preference; then descending cbias
        sort_order = np.lexsort((-np.array(cbias_list), -np.array(resp_list)))
        contra_mat = np.array(contra_rows)[sort_order]
        ipsi_mat = np.array(ipsi_rows)[sort_order]
        sorted_resp = np.array(resp_list)[sort_order]

        # Peak normalization per unit
        peaks = np.maximum(np.max(contra_mat, axis=1), np.max(ipsi_mat, axis=1))
        peaks[peaks == 0] = 1.0
        contra_mat = contra_mat / peaks[:, None]
        ipsi_mat = ipsi_mat / peaks[:, None]

        fig, (ax_con, ax_ip, ax_bar) = plt.subplots(1, 3, figsize=(1.8, 2.3), dpi=300,
                                                     gridspec_kw={"width_ratios": [10, 10, 1], "wspace": 0.15})

        # Contra
        ax_con.pcolormesh(fr_time_ms, np.arange(n_units), contra_mat,
                          cmap=cmap_contra, vmin=0, vmax=1, shading="auto")
        ax_con.axvline(0, color="black", linestyle="--", linewidth=0.8)
        ax_con.set_xlim(-50, 100)
        ax_con.set_xticks([0, 100])
        ax_con.set_ylim(0, n_units)
        ax_con.invert_yaxis()
        ax_con.set_xlabel("Time (ms)", fontsize=8, fontname="Arial")
        ax_con.set_ylabel("Responsive unit #", fontsize=8, fontname="Arial")
        ax_con.set_title("Contra", color="red", fontsize=8, fontname="Arial")
        ax_con.tick_params(labelsize=8, direction="out", length=3, width=0.5)

        # Ipsi
        ax_ip.pcolormesh(fr_time_ms, np.arange(n_units), ipsi_mat,
                         cmap=cmap_ipsi, vmin=0, vmax=1, shading="auto")
        ax_ip.axvline(0, color="black", linestyle="--", linewidth=0.8)
        ax_ip.set_xlim(-50, 100)
        ax_ip.set_xticks([0, 100])
        ax_ip.set_ylim(0, n_units)
        ax_ip.invert_yaxis()
        ax_ip.set_yticks([])
        ax_ip.set_xlabel("Time (ms)", fontsize=8, fontname="Arial")
        ax_ip.set_title("Ipsi", color="blue", fontsize=8, fontname="Arial")
        ax_ip.tick_params(labelsize=8, direction="out", length=3, width=0.5)

        # Preference Bar
        bar_data = sorted_resp[:, None]
        ax_bar.imshow(bar_data, cmap=cmap_resp, vmin=-1, vmax=1, aspect="auto")
        ax_bar.set_xticks([])
        ax_bar.set_yticks([])

        fig.subplots_adjust(left=0.18, right=0.92, bottom=0.18, top=0.88)
        out_base = out_dir / f"All freq Average FR heatmap labels {geno}"
        out_alt = out_dir / f"Fig6A - Normalized FR heatmap ({geno})"
        fig.savefig(out_base.with_suffix(".svg"), bbox_inches="tight", pad_inches=0.08)
        fig.savefig(out_alt.with_suffix(".png"), dpi=300, bbox_inches="tight", pad_inches=0.08)
        fig.savefig(out_alt.with_suffix(".pdf"), bbox_inches="tight", pad_inches=0.08)
        plt.close(fig)


def plot_fig6b(unit_table: list[dict], out_dir: Path):
    """Figure 6B: Population mean spiking rate traces across frequencies & export peak values."""
    fr_time_ms = unit_table[0]["frTime"] * 1000.0

    fig, axes = plt.subplots(2, 3, figsize=(4.4, 3.2), dpi=300)

    peak_lines = []

    for g_idx, geno in enumerate(("WT", "KO")):
        matching_units = [u for u in unit_table if u["genotype"] == geno and u["responsive"]]

        for s_idx, freq in enumerate(STIM_SLOTS):
            ax = axes[g_idx, s_idx]
            con_traces = []
            ip_traces = []

            for u in matching_units:
                if freq in u["slots"]:
                    con_traces.append(u["slots"][freq]["meanContra"])
                    ip_traces.append(u["slots"][freq]["meanIpsi"])

            if len(con_traces) > 0:
                con_mat = np.array(con_traces)
                mu_con = np.mean(con_mat, axis=0)
                sem_con = np.std(con_mat, axis=0) / np.sqrt(len(con_mat))
                ax.fill_between(fr_time_ms, mu_con - 1.96 * sem_con, mu_con + 1.96 * sem_con,
                                color="red", alpha=0.3, edgecolor="none")
                ax.plot(fr_time_ms, mu_con, color="red", linewidth=1.0)
                max_con = float(np.max(mu_con))
            else:
                max_con = 0.0

            if len(ip_traces) > 0:
                ip_mat = np.array(ip_traces)
                mu_ip = np.mean(ip_mat, axis=0)
                sem_ip = np.std(ip_mat, axis=0) / np.sqrt(len(ip_mat))
                ax.fill_between(fr_time_ms, mu_ip - 1.96 * sem_ip, mu_ip + 1.96 * sem_ip,
                                color="blue", alpha=0.3, edgecolor="none")
                ax.plot(fr_time_ms, mu_ip, color="blue", linewidth=1.0)
                max_ip = float(np.max(mu_ip))
            else:
                max_ip = 0.0

            peak_lines.append(f"{geno}: {STIM_NAMES[s_idx]} Peak for Contra: {max_con:.4f}and Peak for Ipsi: {max_ip:.4f}\n")

            # Gray dashed line at stimulus onset
            ax.axvline(0, color=(0.5, 0.5, 0.5), linestyle="--", linewidth=1.0)

            ax.set_xlim(-50, 100)
            ax.set_xticks([-50, 0, 50, 100])
            ax.set_ylim(0, MAX_FR)
            ax.set_yticks(np.arange(0, 16, 5))
            ax.tick_params(labelsize=8, direction="out", length=3, width=0.5)
            for sp in ("top", "right"):
                ax.spines[sp].set_visible(False)
            for sp in ax.spines.values():
                sp.set_linewidth(0.5)

            if g_idx == 0:
                ax.set_title(STIM_NAMES[s_idx], fontsize=8, fontname="Arial", fontweight="normal")
            if s_idx == 0:
                ax.set_ylabel("Mean spiking rate (Hz)", fontsize=8, fontname="Arial")
            else:
                ax.set_ylabel("")
            if g_idx == 1:
                ax.set_xlabel("Time from stimulus onset (ms)", fontsize=8, fontname="Arial")
            else:
                ax.set_xlabel("")

    # Export Peak values pop mean FR.txt
    peak_file = out_dir / "Peak values pop mean FR.txt"
    with open(peak_file, "w", encoding="utf-8") as f:
        f.writelines(peak_lines)

    fig.tight_layout(pad=0.5)
    out_base = out_dir / "Average FR figures window 150 ms"
    out_alt = out_dir / "Fig6B - Population mean spiking rate (10_20_40Hz)"
    fig.savefig(out_base.with_suffix(".pdf"), bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_alt.with_suffix(".png"), dpi=300, bbox_inches="tight", pad_inches=0.08)
    fig.savefig(out_alt.with_suffix(".pdf"), bbox_inches="tight", pad_inches=0.08)
    plt.close(fig)


def main(argv=None):
    parser = argparse.ArgumentParser(description="Plot Figure 6A and 6B (wM1 ephys).")
    parser.add_argument("--tables", type=Path, default=DEFAULT_M1_MAT,
                        help=f"Path to fig3_tables_M1.mat (default: {DEFAULT_M1_MAT})")
    parser.add_argument("--resp-csv", type=Path, default=DEFAULT_RESP_CSV,
                        help=f"Path to responsive_units_M1.csv (default: {DEFAULT_RESP_CSV})")
    parser.add_argument("--out-dir", type=Path, default=DEFAULT_OUT_DIR,
                        help=f"Output figures directory (default: {DEFAULT_OUT_DIR})")
    args = parser.parse_args(argv)

    args.out_dir.mkdir(parents=True, exist_ok=True)

    if not args.tables.exists():
        raise FileNotFoundError(f"M1 tables not found: {args.tables}. Run fig3_tables_nwb first.")
    if not args.resp_csv.exists():
        raise FileNotFoundError(f"Responsive units CSV not found: {args.resp_csv}. Run fig6_roc_tables_nwb first.")

    print(f"Loading M1 records from: {args.tables}")
    records = fp.loadFlatTable(args.tables)

    unit_table = build_m1_unit_table(records, args.resp_csv)
    n_resp_wt = sum(1 for u in unit_table if u["genotype"] == "WT" and u["responsive"])
    n_resp_ko = sum(1 for u in unit_table if u["genotype"] == "KO" and u["responsive"])
    print(f"Built {len(unit_table)} unit rows (WT responsive={n_resp_wt}, KO responsive={n_resp_ko})")

    print("Plotting Figure 6A (Normalized FR heatmaps)...")
    plot_fig6a(unit_table, args.out_dir)

    print("Plotting Figure 6B (Population mean spiking rate traces)...")
    plot_fig6b(unit_table, args.out_dir)

    print(f"Figure 6A and 6B plots completed successfully in: {args.out_dir}")


if __name__ == "__main__":
    main(sys.argv[1:])
