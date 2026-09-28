#!/usr/bin/env python3
"""
figS4a_histology_nwb.py

Figure S4A manuscript panel: 3D reconstructed wS1 unit CCF locations (WT and KO).
Generates:
  - 'FigS4A - Whisker preference in wS1.pdf' and '.png' (2-panel stacked)
  - 'FigS4A - Whisker preference in wS1 (WT).pdf' and '.png'
  - 'FigS4A - Whisker preference in wS1 (KO).pdf' and '.png'

Styling strictly matches FinalFigS4.png Panel A.
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
    Path(__file__).resolve().parent.parent / "Figures" / "Python" / "FigS3_FigS4"
)


def load_s1_data(tables_dir: Path):
    json_path = tables_dir / "figS4a_histology_S1.json"
    mat_path = tables_dir / "figS4a_histology_S1.mat"

    if json_path.exists():
        with open(json_path, "r", encoding="utf-8") as f:
            data = json.load(f)
        raw_wire = data["wireframe"]
        wire = [[np.nan if v is None else v for v in row] for row in raw_wire]
        wireframe = np.array(wire, dtype=float)
        wt_contra = np.array(data["wt_contra"], dtype=float)
        wt_ipsi = np.array(data["wt_ipsi"], dtype=float)
        wt_both = np.array(data["wt_both"], dtype=float)
        ko_contra = np.array(data["ko_contra"], dtype=float)
        ko_ipsi = np.array(data["ko_ipsi"], dtype=float)
        ko_both = np.array(data["ko_both"], dtype=float)
    elif mat_path.exists():
        mat = sio.loadmat(str(mat_path))
        wireframe = np.array(mat["wireframe"], dtype=float)
        wt_contra = np.array(mat["wtContra"], dtype=float)
        wt_ipsi = np.array(mat["wtIpsi"], dtype=float)
        wt_both = np.array(mat["wtBoth"], dtype=float)
        ko_contra = np.array(mat["koContra"], dtype=float)
        ko_ipsi = np.array(mat["koIpsi"], dtype=float)
        ko_both = np.array(mat["koBoth"], dtype=float)
    else:
        raise FileNotFoundError(
            f"Neither {json_path} nor {mat_path} found. Run figS4a_histology_tables_nwb first."
        )

    return wireframe, wt_contra, wt_ipsi, wt_both, ko_contra, ko_ipsi, ko_both


def plot_s1_panel(
    ax,
    wireframe,
    contra_pts,
    ipsi_pts,
    both_pts,
    genotype: str,
):
    ax.set_facecolor("black")
    ax.patch.set_facecolor("black")
    ax.patch.set_visible(True)

    # Fill panel rectangle background
    ax.fill([-15, 510, 510, -15], [-15, -15, 470, 470], color="black", zorder=0)

    # 1. Wireframe mesh lines (coronal projection: x_proj = 570 - Y, y_proj = Z)
    x_wire = 570.0 - wireframe[:, 1]
    y_wire = wireframe[:, 2]
    ax.plot(x_wire, y_wire, color="#999999", linewidth=0.5, alpha=0.5, zorder=1)

    # 2. Units plotted as filled circles
    # Contralateral: red
    ax.scatter(
        570.0 - contra_pts[:, 1],
        contra_pts[:, 2],
        color="red",
        s=16,
        edgecolors="none",
        zorder=3,
    )
    # Ipsilateral: blue
    ax.scatter(
        570.0 - ipsi_pts[:, 1],
        ipsi_pts[:, 2],
        color="blue",
        s=16,
        edgecolors="none",
        zorder=3,
    )
    # Bilateral: white
    ax.scatter(
        570.0 - both_pts[:, 1],
        both_pts[:, 2],
        color="white",
        s=16,
        edgecolors="none",
        zorder=3,
    )

    # 3. Bregma midline asterisk at [0, 0] (570 - 570, 0)
    ax.scatter(
        [0],
        [0],
        color="red",
        marker="*",
        s=60,
        linewidths=1.2,
        zorder=4,
    )

    # 4. Limits and aspect
    ax.set_xlim(-15, 510)
    ax.set_ylim(470, -15)  # Inverted so dorsal surface is at top
    ax.set_aspect("equal")
    ax.axis("off")

    # 5. Overlays and annotations
    if genotype == "WT":
        # Text above panel
        ax.text(
            -10,
            -35,
            "Frontal view",
            color="black",
            fontsize=8.5,
            fontname="Arial",
            ha="left",
            va="bottom",
        )
        ax.text(
            250,
            -35,
            "WT",
            color="#808080",
            fontsize=9.5,
            fontname="Arial",
            fontweight="bold",
            ha="center",
            va="bottom",
        )
        ax.text(
            490,
            -35,
            "Preference:",
            color="black",
            fontsize=8.5,
            fontname="Arial",
            ha="right",
            va="bottom",
        )

        # Legend inside black box (top right)
        ax.text(
            490,
            35,
            "Contra",
            color="red",
            fontsize=8,
            fontname="Arial",
            fontweight="bold",
            ha="right",
        )
        ax.text(
            490,
            60,
            "Ipsi",
            color="blue",
            fontsize=8,
            fontname="Arial",
            fontweight="bold",
            ha="right",
        )
        ax.text(
            490,
            85,
            "Bilateral",
            color="white",
            fontsize=8,
            fontname="Arial",
            fontweight="bold",
            ha="right",
        )
    else:
        # KO text above panel
        ax.text(
            250,
            -35,
            "KO",
            color="black",
            fontsize=9.5,
            fontname="Arial",
            fontweight="bold",
            ha="center",
            va="bottom",
        )

        # Coordinate arrows: Dorsal (up) & Lateral (right)
        # In projected coordinates: up is decreasing y_proj, right is increasing x_proj
        # Arrow base at (370, 140)
        ax.annotate(
            "",
            xy=(370, 85),
            xytext=(370, 140),
            arrowprops=dict(
                arrowstyle="->",
                color="white",
                lw=1.2,
                mutation_scale=10,
            ),
            zorder=5,
        )
        ax.text(
            370,
            75,
            "Dorsal",
            color="white",
            fontsize=7.5,
            fontname="Arial",
            ha="center",
            va="bottom",
        )

        ax.annotate(
            "",
            xy=(425, 140),
            xytext=(370, 140),
            arrowprops=dict(
                arrowstyle="->",
                color="white",
                lw=1.2,
                mutation_scale=10,
            ),
            zorder=5,
        )
        ax.text(
            398,
            160,
            "Lateral",
            color="white",
            fontsize=7.5,
            fontname="Arial",
            ha="center",
            va="top",
        )

        # Scale bar: 0.5 mm = 50 voxels at 10 um
        scale_x0 = 380
        scale_len = 50
        scale_y = 430
        ax.plot(
            [scale_x0, scale_x0 + scale_len],
            [scale_y, scale_y],
            color="white",
            lw=2.0,
            zorder=5,
        )
        ax.text(
            scale_x0 + scale_len / 2.0,
            scale_y + 20,
            "0.5 mm",
            color="white",
            fontsize=7.5,
            fontname="Arial",
            ha="center",
            va="top",
        )


def generate_figS4a(tables_dir: Path, out_dir: Path):
    out_dir.mkdir(parents=True, exist_ok=True)
    (
        wireframe,
        wt_contra,
        wt_ipsi,
        wt_both,
        ko_contra,
        ko_ipsi,
        ko_both,
    ) = load_s1_data(tables_dir)

    # 1. Composite 2-panel figure
    fig, (ax_wt, ax_ko) = plt.subplots(
        2, 1, figsize=(3.8, 5.5), dpi=300, facecolor="white"
    )
    plt.subplots_adjust(
        left=0.08, right=0.92, top=0.91, bottom=0.04, hspace=0.35
    )

    plot_s1_panel(ax_wt, wireframe, wt_contra, wt_ipsi, wt_both, "WT")
    plot_s1_panel(ax_ko, wireframe, ko_contra, ko_ipsi, ko_both, "KO")

    fig.suptitle(
        "Whisker preference in wS1",
        fontsize=10.5,
        fontname="Arial",
        fontweight="bold",
        fontstyle="italic",
        y=0.97,
    )

    comp_pdf = out_dir / "FigS4A - Whisker preference in wS1.pdf"
    comp_png = out_dir / "FigS4A - Whisker preference in wS1.png"
    plt.savefig(comp_pdf)
    plt.savefig(comp_png)
    plt.close()

    # 2. Individual WT figure
    fig_wt, ax_single_wt = plt.subplots(
        figsize=(3.8, 3.0), dpi=300, facecolor="white"
    )
    plt.subplots_adjust(left=0.08, right=0.92, top=0.88, bottom=0.05)
    plot_s1_panel(ax_single_wt, wireframe, wt_contra, wt_ipsi, wt_both, "WT")
    plt.savefig(out_dir / "FigS4A - Whisker preference in wS1 (WT).pdf")
    plt.savefig(out_dir / "FigS4A - Whisker preference in wS1 (WT).png")
    plt.close()

    # 3. Individual KO figure
    fig_ko, ax_single_ko = plt.subplots(
        figsize=(3.8, 3.0), dpi=300, facecolor="white"
    )
    plt.subplots_adjust(left=0.08, right=0.92, top=0.88, bottom=0.05)
    plot_s1_panel(ax_single_ko, wireframe, ko_contra, ko_ipsi, ko_both, "KO")
    plt.savefig(out_dir / "FigS4A - Whisker preference in wS1 (KO).pdf")
    plt.savefig(out_dir / "FigS4A - Whisker preference in wS1 (KO).png")
    plt.close()

    print(f"Generated Figure S4A histology panels in: {out_dir}")


def main(argv=None):
    parser = argparse.ArgumentParser(
        description="Generate Figure S4A histology panels."
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
    generate_figS4a(args.tables_dir, args.out_dir)
    return 0


if __name__ == "__main__":
    sys.exit(main())
