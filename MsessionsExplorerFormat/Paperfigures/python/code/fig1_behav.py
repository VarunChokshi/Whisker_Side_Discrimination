"""
Fig1 / S1 — expert behavioral performance (WT vs KO, no optogenetic inhibition).

Python port of the plotting sections of fig1_behav.m. Plots the ORIGINAL
MATLAB-computed per-mouse means and multilevel-bootstrap CIs (flattened from
AllVars_nboot1000_260903.mat by export_fig1.m); it does not re-run the bootstrap.

Panels (each a WT-vs-KO per-mouse scatter with bootstrap CIs + genotype mean+/-SD):
  correct fraction : overall / left-stim / right-stim   -> CorrectFraction ...
  miss fraction    : overall / left-stim / right-stim   -> MissFraction ...
  amplitude        : left-stim / right-stim             -> Amplitude ...
plus Fig1behavMeanvals.txt (per-genotype Mean/SD and WT-vs-KO Mann-Whitney U).
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
from scipy.stats import mannwhitneyu

from mseio import load_struct, cellstr, ensure_dir

GENOS = ["WT", "KO"]
GRAY, BLACK, RED, BLUE, PURPLE = (0.5, 0.5, 0.5), (0, 0, 0), (1, 0, 0), (0, 0, 1), (0.5, 0.0, 0.5)
YLINE = (112 / 255, 41 / 255, 99 / 255)
START_X, DX, GAP, SUMMARY_OFF = 20, 15, 250, 25
FIGSIZE = (3.3 / 2.54, 3.8 / 2.54)   # 33 x 38 mm
FONT = {"fontname": "Arial", "fontsize": 8}
ALPHA = 0.8
SCAT_S = 9        # per-mouse scatter size
SUMM_MS = 6       # genotype summary marker size


def _xpos(g, n):
    return (START_X + g * GAP) + DX * np.arange(1, n + 1)


def _style(ax, x, ylabel, kind):
    # NB: set ticks BEFORE limits — out-of-range ticks otherwise auto-expand the limits.
    ax.set_xticks([START_X + 75, START_X + 325]); ax.set_xticklabels(["WT", "KO"])
    if kind == "amp":
        ax.set_yticks(np.arange(0, 101, 20)); ax.set_ylim(0, 110)
    else:
        ax.set_yticks([0, 0.1, 0.3, 0.5, 0.7, 0.9, 1])
        ax.set_ylim(0.4, 1) if kind == "correct" else ax.set_ylim(0, 0.5)
        ax.axhline(0.7, ls="--", color=YLINE, lw=1)
    ax.set_xlim(0, x.max() + 60)
    ax.tick_params(direction="out"); ax.spines[["top", "right"]].set_visible(False)
    for lbl in ax.get_xticklabels() + ax.get_yticklabels():
        lbl.set_fontname("Arial"); lbl.set_fontsize(8)
    ax.set_ylabel(ylabel, **FONT)


def _draw_fraction(ax, dat, mouse_nums, kind, field_key, field_colors, ylabel, fid=None, txt_label=None):
    """Draw one correct/miss panel into ax. field_key in {'overall','left','right'}."""
    means = {}
    for g, geno in enumerate(GENOS):
        d = dat[geno]; sel = mouse_nums[g]; n = len(sel)
        x = _xpos(g, n); color = field_colors[g]
        suff = "" if kind == "correct" else "_miss"
        ci = d[f"ci_{field_key}{suff}"][:, sel]           # 3 x n : mean, lo, hi
        ax.errorbar(x, ci[0], yerr=[ci[0] - ci[1], ci[2] - ci[0]], fmt="none",
                    ecolor=color, elinewidth=0.8, capsize=0, alpha=ALPHA)
        if field_key == "overall":
            m = d[f"mean_overall{suff}"][sel]
        else:
            m = d[f"mean_tt{suff}"][sel, 0 if field_key == "left" else 1]
        ax.scatter(x, m, s=SCAT_S, facecolors="none", edgecolors=color, linewidths=0.8, alpha=ALPHA)
        sc = PURPLE if field_key == "overall" else BLACK
        ax.errorbar(x[-1] + SUMMARY_OFF, m.mean(), yerr=m.std(ddof=1), fmt="o", ms=SUMM_MS,
                    color=sc, mec=sc, mfc=sc, elinewidth=0.8, capsize=0)
        means[geno] = m
        if fid is not None:
            fid.write(f"For genotype: {geno} {txt_label[field_key]} Mean: {m.mean():g} SD: {m.std(ddof=1):g}\n")
    if fid is not None:
        p = mannwhitneyu(means["WT"], means["KO"], alternative="two-sided").pvalue
        fid.write(f"For plotType: {txt_label['title']} {txt_label[field_key]} Mann Whitney U pval: {p:g}\n")
    _style(ax, _xpos(1, len(mouse_nums[1])), ylabel, kind)
    return means


def _draw_amp(ax, dat, mouse_nums, side, field_color, ylabel, fid=None):
    """Draw one amplitude panel into ax. side in {'left','right'}."""
    means = {}
    for g, geno in enumerate(GENOS):
        d = dat[geno]; sel = mouse_nums[g]; n = len(sel)
        x = _xpos(g, n)
        y = d[f"amp_{side}"][sel] / 10.0
        ax.scatter(x, y, s=SCAT_S, facecolors="none", edgecolors=field_color, linewidths=0.8)
        ax.errorbar(x[-1] + SUMMARY_OFF, y.mean(), yerr=y.std(ddof=1), fmt="o", ms=SUMM_MS,
                    color=BLACK, mec=BLACK, mfc=BLACK, elinewidth=0.8, capsize=0)
        means[geno] = y
        label = "Left Stim trials" if side == "left" else "Right Stim trials"
        if fid is not None:
            fid.write(f"For genotype: {geno} {label} amplitudes Mean: {y.mean():g} SD: {y.std(ddof=1):g}\n")
    if fid is not None:
        label = "Left Stim trials" if side == "left" else "Right Stim trials"
        p = mannwhitneyu(means["WT"], means["KO"], alternative="two-sided").pvalue
        fid.write(f"For plotType: Amplitude {label} Mann Whitney U pval: {p:g}\n")
    _style(ax, _xpos(1, len(mouse_nums[1])), ylabel, "amp")
    return means


def make_fig1(export_dir, out_dir):
    export_dir, out_dir = Path(export_dir), ensure_dir(out_dir)
    dat = {g: load_struct(export_dir / f"fig1_behav_{g}.mat") for g in GENOS}
    for g in GENOS:  # genotype field may load as array
        dat[g]["genotype"] = str(cellstr(dat[g]["genotype"])[0])

    mn_frac = [np.arange(10), np.arange(8)]   # correct/miss: WT 1:10, KO 1:8
    mn_amp = [np.arange(9), np.arange(7)]      # amplitude:    WT 1:9,  KO 1:7
    lbl_c = {"overall": "stats_overall", "left": "_left", "right": "_right", "title": "Correct fraction"}
    lbl_m = {"overall": "stats_overall", "left": "_left", "right": "_right", "title": "Miss fraction"}
    colors = {"overall": (GRAY, BLACK), "left": (RED, RED), "right": (BLUE, BLUE)}

    txt = out_dir / "Fig1behavMeanvals.txt"
    with open(txt, "w") as fid:
        # correct fraction (overall/left/right)
        for fk in ["overall", "left", "right"]:
            fig, ax = plt.subplots(figsize=FIGSIZE)
            _draw_fraction(ax, dat, mn_frac, "correct", fk, colors[fk],
                           "Correct fraction excl. misses", fid=fid, txt_label=lbl_c)
            fig.tight_layout()
            name = {"overall": "stats_overall", "left": "_left", "right": "_right"}[fk]
            _save(fig, out_dir, f"CorrectFraction {name} No inihibtion KO vs WT Correct fraction")
        # miss fraction
        for fk in ["overall", "left", "right"]:
            fig, ax = plt.subplots(figsize=FIGSIZE)
            _draw_fraction(ax, dat, mn_frac, "miss", fk, colors[fk], "Miss fraction", fid=fid, txt_label=lbl_m)
            fig.tight_layout()
            name = {"overall": "stats_overall", "left": "_left", "right": "_right"}[fk]
            _save(fig, out_dir, f"MissFraction {name} No inihibtion KO vs WT Correct fraction")
        # amplitude (left/right)
        for side, fc in [("left", RED), ("right", BLUE)]:
            fig, ax = plt.subplots(figsize=FIGSIZE)
            _draw_amp(ax, dat, mn_amp, side, fc, "Amplitude (% of maximum)", fid=fid)
            fig.tight_layout()
            label = "Left Stim trials" if side == "left" else "Right Stim trials"
            _save(fig, out_dir, f"Amplitude {label} No inihibtion KO vs WT Amplitudes")
    print(f"Fig1 behavior -> {out_dir}")


def make_fig1_panel(export_dir, out_dir):
    """One presentation-friendly figure: all Fig1/S1 behaviour metrics as a 3x3 grid
    of panels (correct overall/left/right, miss overall/left/right, amplitude left/right)."""
    export_dir, out_dir = Path(export_dir), ensure_dir(out_dir)
    dat = {g: load_struct(export_dir / f"fig1_behav_{g}.mat") for g in GENOS}
    for g in GENOS:
        dat[g]["genotype"] = str(cellstr(dat[g]["genotype"])[0])
    mn_frac = [np.arange(10), np.arange(8)]
    mn_amp = [np.arange(9), np.arange(7)]
    colors = {"overall": (GRAY, BLACK), "left": (RED, RED), "right": (BLUE, BLUE)}

    fig, axes = plt.subplots(3, 3, figsize=(9.5, 8.0), constrained_layout=True)
    titles = [["Correct — overall", "Correct — left stim", "Correct — right stim"],
              ["Miss — overall", "Miss — left stim", "Miss — right stim"],
              ["Amplitude — left stim", "Amplitude — right stim", ""]]
    for ci, fk in enumerate(["overall", "left", "right"]):
        _draw_fraction(axes[0, ci], dat, mn_frac, "correct", fk, colors[fk], "Correct fraction")
        _draw_fraction(axes[1, ci], dat, mn_frac, "miss", fk, colors[fk], "Miss fraction")
    _draw_amp(axes[2, 0], dat, mn_amp, "left", RED, "Amplitude (% max)")
    _draw_amp(axes[2, 1], dat, mn_amp, "right", BLUE, "Amplitude (% max)")
    axes[2, 2].axis("off")
    for r in range(3):
        for c in range(3):
            if titles[r][c]:
                axes[r, c].set_title(titles[r][c], **FONT)
    fig.suptitle("Fig1 / S1 — behaviour (WT vs KO, no inhibition)", fontsize=11, fontname="Arial")
    stem = out_dir / "Fig1 - behaviour panels"
    fig.savefig(f"{stem}.pdf", dpi=300, bbox_inches="tight")
    fig.savefig(f"{stem}.png", dpi=200, bbox_inches="tight")
    plt.close(fig)
    print(f"Fig1 panel -> {stem}.png")


def _save(fig, out_dir, stem):
    fig.savefig(str(Path(out_dir) / f"{stem}.pdf"), dpi=300, bbox_inches="tight")
    fig.savefig(str(Path(out_dir) / f"{stem}.png"), dpi=300, bbox_inches="tight")
    plt.close(fig)


def main(argv=None):
    ap = argparse.ArgumentParser(description="Fig1/S1 behavior panels from flattened AllVars.")
    ap.add_argument("--export-dir", required=True, help="folder with fig1_behav_{WT,KO}.mat")
    ap.add_argument("--out-dir", required=True)
    a = ap.parse_args(argv)
    make_fig1(a.export_dir, a.out_dir)


if __name__ == "__main__":
    raise SystemExit(main())
