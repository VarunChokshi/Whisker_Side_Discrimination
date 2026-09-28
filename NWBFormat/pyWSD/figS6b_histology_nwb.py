#!/usr/bin/env python3
"""
figS6b_histology_nwb.py

Figure S6B manuscript panel: Dorsal stereotaxic view of probe entry points in wM1.
Generates:
  - 'FigS6B - Dorsal view of probe entry points in wM1.pdf' and '.png'

Styling strictly matches FinalFigS6.png Panel B and 'wM1 penetrations.pdf'.
"""

import argparse
import json
from pathlib import Path
import sys
import matplotlib.pyplot as plt
import numpy as np
import scipy.io as sio

DEFAULT_TABLES_DIR = (
    Path(__file__).resolve().parent.parent / "Data" / "Tables" / "Histology"
)
DEFAULT_OUT_DIR = (
    Path(__file__).resolve().parent.parent / "Figures" / "Python" / "FigS6"
)


def load_m1_data(tables_dir: Path):
    json_path = tables_dir / "figS6b_histology_M1.json"
    mat_path = tables_dir / "figS6b_histology_M1.mat"

    if json_path.exists():
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        wt_ap = np.array(data["wt_ap"], dtype=float).flatten()
        wt_ml = np.array(data["wt_ml"], dtype=float).flatten()
        ko_ap = np.array(data["ko_ap"], dtype=float).flatten()
        ko_ml = np.array(data["ko_ml"], dtype=float).flatten()
        grid_lines = np.array(data["grid_lines"], dtype=float)
    elif mat_path.exists():
        mat = sio.loadmat(str(mat_path))
        wt_ap = np.array(mat["wt_ap"], dtype=float).flatten()
        wt_ml = np.array(mat["wt_ml"], dtype=float).flatten()
        ko_ap = np.array(mat["ko_ap"], dtype=float).flatten()
        ko_ml = np.array(mat["ko_ml"], dtype=float).flatten()
        grid_lines = np.array(mat["grid_lines"], dtype=float)
    else:
        raise FileNotFoundError(
            f"Neither {json_path} nor {mat_path} found. Run figS6b_histology_tables_nwb first."
        )

    return wt_ap, wt_ml, ko_ap, ko_ml, grid_lines


def plot_m1_penetrations(ax, wt_ap, wt_ml, ko_ap, ko_ml, grid_lines):
    ax.set_facecolor("white")

    # 1. Horizontal stepped grid lines (grey)
    grid_color = "#999999"
    for row in grid_lines:
        ap, ml_min, ml_max = row
        ax.plot([ml_min, ml_max], [ap, ap], color=grid_color, linewidth=1.0, zorder=1)

    # 2. Vertical stepped grid lines (symmetrical across ML = 0)
    vlines = [
        (0.0, 0.0, 4.2),  # midline
        (0.5, 0.0, 4.0),
        (1.0, 0.0, 3.0),
        (1.5, 0.0, 2.5),
        (2.0, 0.0, 2.0),
        (2.5, 0.0, 1.0),
        (3.0, 0.0, 0.5),
    ]
    for ml, ap_min, ap_max in vlines:
        if ml == 0:
            ax.plot([0, 0], [ap_min, ap_max], color=grid_color, linewidth=1.0, zorder=1)
        else:
            ax.plot([ml, ml], [ap_min, ap_max], color=grid_color, linewidth=1.0, zorder=1)
            ax.plot([-ml, -ml], [ap_min, ap_max], color=grid_color, linewidth=1.0, zorder=1)

    # 3. Main axes with arrows
    # Midline anterior arrow
    ax.annotate(
        "",
        xy=(0, 4.5),
        xytext=(0, 0),
        arrowprops=dict(
            arrowstyle="->",
            color="black",
            lw=1.2,
            mutation_scale=12,
        ),
        zorder=2,
    )
    # Bregma coronal double-ended arrow
    ax.annotate(
        "",
        xy=(-3.8, 0),
        xytext=(3.8, 0),
        arrowprops=dict(
            arrowstyle="<->",
            color="black",
            lw=1.2,
            mutation_scale=12,
        ),
        zorder=2,
    )

    # 4. Tick marks at -1 and 1 on Bregma coronal line
    tick_len = 0.15
    ax.plot([-1, -1], [0, -tick_len], color="black", lw=1.0, zorder=2)
    ax.plot([1, 1], [0, -tick_len], color="black", lw=1.0, zorder=2)

    # 5. Bregma point and label
    ax.scatter([0], [0], color="red", s=25, zorder=5)
    ax.text(
        0,
        -0.32,
        "Bregma",
        color="red",
        fontsize=8.5,
        ha="center",
        va="top",
        fontname="Arial",
    )
    ax.text(
        -1,
        -0.32,
        "-1",
        color="black",
        fontsize=8.5,
        ha="center",
        va="top",
        fontname="Arial",
    )
    ax.text(
        1,
        -0.32,
        "1",
        color="black",
        fontsize=8.5,
        ha="center",
        va="top",
        fontname="Arial",
    )
    ax.text(
        0,
        -0.85,
        "Distance from Bregma (mm)",
        color="black",
        fontsize=9,
        ha="center",
        va="top",
        fontname="Arial",
    )

    # 6. WT and KO dots
    ax.scatter(
        wt_ml,
        wt_ap,
        color="#808080",
        s=16,
        alpha=0.9,
        zorder=3,
        label="WT",
    )
    ax.scatter(
        ko_ml,
        ko_ap,
        color="black",
        s=16,
        alpha=0.9,
        zorder=4,
        label="KO",
    )

    # 7. Legend
    ax.text(
        2.6,
        3.2,
        "WT",
        color="#808080",
        fontsize=9.5,
        fontname="Arial",
        fontweight="bold",
    )
    ax.text(
        2.6,
        2.7,
        "KO",
        color="black",
        fontsize=9.5,
        fontname="Arial",
        fontweight="bold",
    )

    # 8. Title
    ax.set_title(
        "Dorsal view of probe entry points in wM1",
        fontname="Arial",
        style="italic",
        fontsize=9.5,
        pad=10,
    )

    ax.set_xlim(-4.3, 4.3)
    ax.set_ylim(-1.2, 4.8)
    ax.set_aspect("equal")
    ax.axis("off")


def generate_figS6b(tables_dir: Path, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    wt_ap, wt_ml, ko_ap, ko_ml, grid_lines = load_m1_data(tables_dir)

    fig, ax = plt.subplots(figsize=(4.5, 4.5), dpi=300, facecolor="white")
    plt.subplots_adjust(left=0.08, right=0.92, top=0.90, bottom=0.08)

    plot_m1_penetrations(ax, wt_ap, wt_ml, ko_ap, ko_ml, grid_lines)

    pdf_path = out_dir / "FigS6B - Dorsal view of probe entry points in wM1.pdf"
    png_path = out_dir / "FigS6B - Dorsal view of probe entry points in wM1.png"
    plt.savefig(pdf_path)
    plt.savefig(png_path)
    plt.close()

    print(f"Generated Figure S6B histology panel in: {out_dir}")


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Generate Figure S6B histology panel."
    )
    parser.add_argument(
        "--tables-dir",
        type=Path,
        default=DEFAULT_TABLES_DIR,
        help="Directory containing staged histology tables.",
    )
    parser.add_argument(
        "--out-dir",
        type=Path,
        default=DEFAULT_OUT_DIR,
        help="Output directory for generated figures.",
    )
    args = parser.parse_args(argv)
    generate_figS6b(args.tables_dir, args.out_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())

