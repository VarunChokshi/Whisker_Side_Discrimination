"""
Fig2 / S2 — optogenetic inhibition of wS1 during the task (WT vs KO).

Python port of the plotting sections of Fig2_behav_optoInhibition.m. Plots the
ORIGINAL MATLAB-computed per-mouse inhibition EFFECT (delta = opto - control) and
its multilevel-bootstrap CIs (flattened from InhibitionAllVars by export_fig2.m);
it does not re-run the bootstrap.

Per genotype (WT, KO):
  <geno> Inihibtion Bootstrapping Correct fraction.pdf   delta correct (Fig2B)
  <geno> Inihibtion Bootstrapping Miss fraction.pdf      delta miss    (Fig2C)
  <geno> Inihibtion Amplitudes.pdf                       whisker amplitude
Contra-stim points are red, ipsi-stim blue; the two inhibition sites use '.'/'x'.
Also writes the two delta-stats txt files (binomial sign test + between-genotype).
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
from scipy.stats import binom, mannwhitneyu

from mseio import load_struct, cellstr, ensure_dir

RED, BLUE, GRAY = (1, 0, 0), (0, 0, 1), (0.5, 0.5, 0.5)
GENOS = ["WT", "KO"]
MARKERS = [".", "x"]; MSIZE = [10, 5]
START_X, DX, SITE_OFF, IPSI_OFF = 20, 15, 75, 200
FIGSIZE = (1.6, 1.5)
FONT = {"fontname": "Arial", "fontsize": 8}


def _xs(nm):
    x1 = np.array([START_X + DX * (m + 1) + SITE_OFF / 2 for m in range(nm)])
    x2 = x1 + IPSI_OFF
    return x1, x2


def _delta_panel(ax, cm, cc, im, ic, ylim, yticks):
    nm = cm.shape[1]
    for m in range(nm):
        for site in range(2):
            # contra (red)
            xc = START_X + DX * (m + 1) + site * SITE_OFF
            ci = cc[site, :, m]
            ax.errorbar(xc, ci[0], yerr=[[ci[0] - ci[1]], [ci[2] - ci[0]]], fmt="none",
                        ecolor=RED, elinewidth=1, capsize=0)
            ax.plot(xc, cm[site, m], marker=MARKERS[site], color=RED, ms=MSIZE[site], mew=1, ls="none")
            # ipsi (blue)
            xi = START_X + IPSI_OFF + DX * (m + 1) + site * SITE_OFF
            c2 = ic[site, :, m]
            ax.errorbar(xi, c2[0], yerr=[[c2[0] - c2[1]], [c2[2] - c2[0]]], fmt="none",
                        ecolor=BLUE, elinewidth=1, capsize=0)
            ax.plot(xi, im[site, m], marker=MARKERS[site], color=BLUE, ms=MSIZE[site], mew=1, ls="none")
    x1, x2 = _xs(nm)
    ax.set_yticks(yticks); ax.set_ylim(*ylim)
    ax.axhline(0, ls="--", color=GRAY, lw=1)
    ax.set_xticks([x1.mean(), x2.mean()]); ax.set_xticklabels(["Contra stim", "Ipsi stim"])
    ax.set_xlim(0, x2.max() + 70)
    _finish(ax)


def _amp_panel(ax, ampc, ampi):
    nm = ampc.shape[1]
    for m in range(nm):
        for site in range(2):
            xc = START_X + DX * (m + 1) + site * SITE_OFF
            ax.plot(xc, ampc[site, m], marker=MARKERS[site], color=RED, ms=MSIZE[site], mew=1, ls="none")
            xi = START_X + IPSI_OFF + DX * (m + 1) + site * SITE_OFF
            ax.plot(xi, ampi[site, m], marker=MARKERS[site], color=BLUE, ms=MSIZE[site], mew=1, ls="none")
    x1, x2 = _xs(nm)
    ax.set_yticks(np.arange(0, 101, 25)); ax.set_ylim(0, 110)
    ax.set_xticks([x1.mean(), x2.mean()]); ax.set_xticklabels(["Contra stim", "Ipsi stim"])
    ax.set_xlim(0, x2.max() + 70)
    _finish(ax)


def _finish(ax):
    ax.tick_params(direction="out"); ax.spines[["top", "right"]].set_visible(False)
    for lbl in ax.get_xticklabels() + ax.get_yticklabels():
        lbl.set_fontname("Arial"); lbl.set_fontsize(8)


def _save(fig, out_dir, stem):
    fig.tight_layout()
    fig.savefig(str(Path(out_dir) / f"{stem}.pdf"), dpi=300, bbox_inches="tight")
    fig.savefig(str(Path(out_dir) / f"{stem}.png"), dpi=300, bbox_inches="tight")
    plt.close(fig)


def _binom_line(vals, direction):
    """successes = #(vals<0) if 'neg' else #(vals>0); pval = 1-binocdf(s-1,n,.5), binopdf(s,n,.5).
    Sign convention differs by panel: correct -> contra '<0', ipsi '>0'; miss -> both '>0'."""
    n = vals.size
    s = int(np.sum(vals < 0)) if direction == "neg" else int(np.sum(vals > 0))
    return binom.sf(s - 1, n, 0.5), binom.pmf(s, n, 0.5)


def _delta_stats(dat, kind, out_dir, fname, title):
    """kind in {'correct','miss'}: binomial sign tests + between-genotype comparison."""
    contra = {}; ipsi = {}
    for g in GENOS:
        d = dat[g]
        # stats use Meanstats_dleft/dright (bootstrap-mean delta), not the marker MeanData diff
        contra[g] = d[f"{kind}_contra_stat"].ravel()   # 2 sites x nMouse -> flat
        ipsi[g] = d[f"{kind}_ipsi_stat"].ravel()
    contra_dir = "neg" if kind == "correct" else "pos"   # inhibition lowers correct, raises miss
    ipsi_dir = "pos"
    with open(Path(out_dir) / fname, "w") as fid:
        fid.write("Pvals using binomial tests:\n")
        for g in GENOS:
            cdf_c, pdf_c = _binom_line(contra[g], contra_dir)
            fid.write(f"For genotype {g} using binocdf contra is {cdf_c:g} using binopdf contra is {pdf_c:g}\n")
            cdf_i, pdf_i = _binom_line(ipsi[g], ipsi_dir)
            fid.write(f"For genotype {g} using binocdf ipsi is {cdf_i:g} using binopdf ipsi is {pdf_i:g}\n")
        # Between-genotype: the original gates ttest2/ranksum on an Anderson-Darling
        # normality test; for the published data that gate selected ranksum (Mann-Whitney U).
        pc = mannwhitneyu(contra["WT"], contra["KO"], alternative="two-sided").pvalue
        pi = mannwhitneyu(ipsi["WT"], ipsi["KO"], alternative="two-sided").pvalue
        fid.write(f"Between genotypes contra effect comparison using Mann Whitney U is {pc:g}\n")
        fid.write(f"Between genotypes ipsi effect comparison using Mann Whitney U is {pi:g}\n")


def make_fig2(export_dir, out_dir):
    export_dir, out_dir = Path(export_dir), ensure_dir(out_dir)
    dat = {g: load_struct(export_dir / f"fig2_opto_{g}.mat") for g in GENOS}
    for g in GENOS:
        d = dat[g]
        fig, ax = plt.subplots(figsize=FIGSIZE)
        _delta_panel(ax, d["correct_contra_mean"], d["correct_contra_ci"],
                     d["correct_ipsi_mean"], d["correct_ipsi_ci"], (-0.75, 0.35), np.arange(-0.6, 0.31, 0.2))
        _save(fig, out_dir, f"{g} Inihibtion Bootstrapping Correct fraction")

        fig, ax = plt.subplots(figsize=FIGSIZE)
        _delta_panel(ax, d["miss_contra_mean"], d["miss_contra_ci"],
                     d["miss_ipsi_mean"], d["miss_ipsi_ci"], (-0.2, 0.6), np.arange(-0.2, 0.61, 0.2))
        _save(fig, out_dir, f"{g} Inihibtion Bootstrapping Miss fraction")

        fig, ax = plt.subplots(figsize=FIGSIZE)
        _amp_panel(ax, d["amp_contra"], d["amp_ipsi"])
        _save(fig, out_dir, f"{g} Inihibtion Amplitudes")

    _delta_stats(dat, "correct", out_dir, "Fig2 OptoInhibition Stats delta correct fraction.txt", "correct")
    _delta_stats(dat, "miss", out_dir, "Fig2 OptoInhibition Stats delta miss fraction.txt", "miss")
    print(f"Fig2 opto inhibition -> {out_dir}")


def main(argv=None):
    ap = argparse.ArgumentParser(description="Fig2 opto-inhibition panels from flattened InhibitionAllVars.")
    ap.add_argument("--export-dir", required=True, help="folder with fig2_opto_{WT,KO}.mat")
    ap.add_argument("--out-dir", required=True)
    a = ap.parse_args(argv)
    make_fig2(a.export_dir, a.out_dir)


if __name__ == "__main__":
    raise SystemExit(main())
