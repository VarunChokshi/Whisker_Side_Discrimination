"""
Fig5 — Whisker-side stimulus discriminability in wS1 (population LDA decoding).

Python port of Fig5_Robo3_LDA_plot.m. Plots the ORIGINAL MATLAB-computed LDA
accuracies (flattened to -v7 structs by the MATLAB export step); it does not
re-run the LDA. Reproduces:
  - LDA_histogram_<site>_<geno>_20Hz_<bin>msBin_..._3respMin.pdf/png   (true vs shuffle)
  - LDA_bootstrapping_<site>_<geno>_..._3respMin.pdf/png               (95% CI)
  - "LDA median values.txt", "LDA bootstrapping CI values.txt"

The same logic serves Fig7 (wM1); fig7_lda_motor.py calls make_lda_figures()
with the Motor parameters.
"""
from __future__ import annotations
from pathlib import Path
import argparse
import numpy as np
import matplotlib
matplotlib.use("Agg")
import logging
logging.getLogger("matplotlib.font_manager").setLevel(logging.ERROR)
import matplotlib.pyplot as plt

from mseio import load_struct, cellstr, col, ensure_dir, mround

PURPLE = (0.5, 0.0, 0.5)   # "true"
GRAY   = (0.5, 0.5, 0.5)   # "shuffled"
GENOS  = ["WT", "KO"]
SHUF   = ["true", "shuffled"]
RESP_MIN = 3               # keep sessions with N_respUnit > 3
FONT = {"fontname": "Arial", "fontsize": 8}


def _win_tokens(time_window, bin_s):
    """List of (win_str, startMs, endMs) subplot windows tiling time_window at bin_s."""
    n = int(round((time_window[1] - time_window[0]) / bin_s))
    out = []
    for b in range(n):
        t0 = b * bin_s + time_window[0]
        t1 = (b + 1) * bin_s + time_window[0]
        out.append((f"{int(round(t0*1000))}to{int(round(t1*1000))}",
                    int(round(t0*1000)), int(round(t1*1000))))
    return out


def make_lda_figures(export_dir, out_dir, site, bin_s, time_window, legend_x=0.62):
    export_dir, out_dir = Path(export_dir), ensure_dir(out_dir)
    binMs = int(round(bin_s * 1000))
    wins = _win_tokens(time_window, bin_s)
    tag = f"20Hz_{binMs}msBin_{int(round(time_window[0]*1000))}to{int(round(time_window[1]*1000))}ms_3respMin"
    edges = np.arange(0, 1.0 + 1e-9, 0.025)
    centers = (edges[:-1] + edges[1:]) / 2

    # ---------- Panel 1: histograms of true & shuffled accuracy (one fig per genotype) ----------
    with open(out_dir / "LDA median values.txt", "w") as fid:
        for geno in GENOS:
            fig, axes = plt.subplots(1, len(wins), figsize=(3, 1.5))
            axes = np.atleast_1d(axes)
            n_geno = 0
            for bi, (w, t0, t1) in enumerate(wins):
                ax = axes[bi]
                p = load_struct(export_dir / f"LDA_point_{w}.mat")
                g = cellstr(p["genotype"])
                nresp = col(p["N_respUnit"])
                keep = (g == geno) & (nresp > RESP_MIN)
                n_geno = int(keep.sum())
                ax.axvline(0.5, ls="--", lw=1, color="k")
                for si, sh in enumerate(SHUF):
                    ca = col(p["LDA_true"] if si == 0 else p["LDA_shuffle"])[keep]
                    color = PURPLE if si == 0 else GRAY
                    lw = 1 if si == 0 else 0.5
                    ax.hist(ca, bins=edges, color=color, alpha=0.6, lw=lw, edgecolor=color)
                    med = np.nanmedian(ca)
                    ci = int(np.argmin(np.abs(med - centers)))
                    ax.plot(centers[ci], 7, "v", lw=1, ms=3, color=color)
                    fid.write(f"For {site} {geno} {t0} ~ {t1} ms: {sh} median is {med:g}\n")
                    if bi == 0:
                        ax.text(legend_x, 7.5 - (si + 1), sh, color=color, **FONT)
                ax.set_ylim(0, 8)
                ax.set_xticks(np.arange(0, 1.01, 0.25))
                ax.set_yticks(np.arange(0, 8.1, 2))
                ax.tick_params(direction="out"); ax.spines[["top", "right"]].set_visible(False)
                for lbl in ax.get_xticklabels() + ax.get_yticklabels():
                    lbl.set_fontname("Arial"); lbl.set_fontsize(8)
                if bi == 0:
                    ax.set_ylabel("Number of sessions", **FONT)
                ax.set_title(f"{t0} ~ {t1} ms", **FONT)
            fig.suptitle(f"{site} {geno} n= {n_geno} sessions", **FONT)
            fig.tight_layout()
            stem = out_dir / f"LDA_histogram_{site}_{geno}_{tag}"
            fig.savefig(f"{stem}.pdf", dpi=1200, bbox_inches="tight")
            fig.savefig(f"{stem}.png", dpi=300, bbox_inches="tight")
            plt.close(fig)

    # ---------- Panel 2: bootstrapped 95% CI (single fig, both genotypes) ----------
    nBoot = 100
    fig, axes = plt.subplots(1, len(wins), figsize=(3, 1.75))
    axes = np.atleast_1d(axes)
    with open(out_dir / "LDA bootstrapping CI values.txt", "w") as fid:
        for bi, (w, t0, t1) in enumerate(wins):
            ax = axes[bi]
            b = load_struct(export_dir / f"LDA_boot_{w}.mat")
            bg = cellstr(b["genotype"])
            true_mat, shuf_mat = np.asarray(b["true"], float), np.asarray(b["shuffle"], float)
            for gi, geno in enumerate(GENOS):
                row = int(np.where(bg == geno)[0][0])
                for si, sh in enumerate(SHUF):
                    acc = np.sort((true_mat if si == 0 else shuf_mat)[row])
                    m = acc.mean()
                    up = acc[mround(0.975 * nBoot) - 1]   # MATLAB 1-indexed, half-away rounding
                    lo = acc[mround(0.025 * nBoot) - 1]
                    color = PURPLE if si == 0 else GRAY
                    x = (gi + 1) + (si + 1) * 0.2 - 0.3
                    ax.errorbar(x, m, yerr=[[m - lo], [up - m]], fmt="o", color=color,
                                mec=color, mfc=color, ms=5, capsize=4, lw=0.5)
                    fid.write(f"For {site} {geno} {t0} ~ {t1} ms: {sh} CI is {lo:g} to {up:g}\n")
                    if bi == 0 and gi == 0:
                        ax.text(1.5, 0.8 - 0.05 * (si + 1), sh, color=color, **FONT)
            ax.axhline(0.5, ls="--", lw=1)
            ax.set_xlim(0.5, 2.5); ax.set_ylim(0.3, 1)
            ax.set_xticks([1, 2]); ax.set_xticklabels(GENOS)
            ax.tick_params(direction="out"); ax.spines[["top", "right"]].set_visible(False)
            for lbl in ax.get_xticklabels() + ax.get_yticklabels():
                lbl.set_fontname("Arial"); lbl.set_fontsize(8)
            ax.set_ylabel("Classification accuracy", **FONT)
            ax.set_title(f"{t0} ~ {t1} ms", **FONT)
    fig.tight_layout()
    stem = out_dir / f"LDA_bootstrapping_{site}_{GENOS[-1]}_{tag}"
    fig.savefig(f"{stem}.pdf", dpi=1200, bbox_inches="tight")
    fig.savefig(f"{stem}.png", dpi=300, bbox_inches="tight")
    plt.close(fig)
    print(f"LDA figures ({site}) written -> {out_dir}")


def main(argv=None):
    ap = argparse.ArgumentParser(description="Fig5 wS1 LDA decoding from flattened LDA exports.")
    ap.add_argument("--export-dir", required=True, help="folder with LDA_point_*/LDA_boot_* .mat")
    ap.add_argument("--out-dir", required=True)
    a = ap.parse_args(argv)
    make_lda_figures(a.export_dir, a.out_dir, site="S1", bin_s=0.05, time_window=(-0.05, 0.05))


if __name__ == "__main__":
    raise SystemExit(main())
