"""
Fig4 — S1 single-unit ROC / body-side selectivity.

Python port of Fig4_Robo3_ROC_plot.m. Plots the ORIGINAL MATLAB-computed ROC
results (flattened to -v7 structs by export_roc.m); it does not re-run the ROC
bootstraps. The sections that produce kept manuscript panels are ported:

  auc_histograms()        Fig4A   AUC_histogram_S1_<geno>_...
  percent_sig_over_time() Fig4    PercentageSigUnit_S1_...            (5 ms, point)
  percent_sig_bootstrap() Fig4    PercentageSigUnit_S1_...bootstrapped (5 ms, unit-resample CI + WT-KO diff)
  selectivity_onset()     Fig4D   SigOnset_S1_... + StatisticsSelectivityOnset.txt

Significance is decided in MATLAB (Bonferroni CI on the 1000 bootstrap AUCs
excludes 0.5); this module receives per-unit mean AUC + is_sig and only
bins / lightly aggregates. The bootstrap CI band resamples units (like the
original, which used no seed, so its bands are not byte-reproducible either);
`percent_sig_bootstrap` seeds numpy for stable re-runs. The exploratory sections
of the MATLAB script (AUC-bootstrap-CI, the 'do not use' onset, and the
S1-vs-Motor onset) are omitted — they have no kept manuscript output.
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

from mseio import load_struct, col, ensure_dir

RED  = (1.0, 0.0, 0.0)   # contra-preferring, significant
BLUE = (0.0, 0.0, 1.0)   # ipsi-preferring, significant
GENOS = ["WT", "KO"]
FONT = {"fontname": "Arial", "fontsize": 8}


def auc_histograms(export_dir, out_dir, site="S1"):
    """Fig4A: per-genotype AUC distribution histograms for the first 3 of 4 50ms bins."""
    export_dir, out_dir = Path(export_dir), ensure_dir(out_dir)
    edges = np.arange(0, 1.0 + 1e-9, 0.05)
    for geno in GENOS:
        d = load_struct(export_dir / f"auc_hist_{geno}.mat")
        auc_mean = np.atleast_2d(np.asarray(d["auc_mean"], float))
        is_sig = np.atleast_2d(np.asarray(d["is_sig"], float)).astype(bool)
        N = int(d["N"])
        tw = col(d["timeWindow"]); bin_s = float(d["binSec"])
        n_plot = 3  # binNum-1 = plot bins 1..3 (-50to0, 0to50, 50to100)

        fig, axes = plt.subplots(1, n_plot, figsize=(4.5, 1.65))
        axes = np.atleast_1d(axes)
        for b in range(n_plot):
            ax = axes[b]
            m = auc_mean[:, b]
            sig = is_sig[:, b]
            con, ipsi = m > 0.5, m < 0.5
            pct_con = round(float(np.sum(sig & con)) / N * 100, 1)
            pct_ipsi = round(float(np.sum(sig & ipsi)) / N * 100, 1)
            # counts normalized to fraction of all units (MATLAB: Values/length(AUC_mean))
            all_c = np.histogram(m, bins=edges)[0] / N
            con_c = np.histogram(m[sig & con], bins=edges)[0] / N
            ipsi_c = np.histogram(m[sig & ipsi], bins=edges)[0] / N
            ax.bar(edges[:-1], all_c, width=0.05, align="edge", color="white", edgecolor="k", linewidth=0.5)
            ax.bar(edges[:-1], ipsi_c, width=0.05, align="edge", color=BLUE, alpha=0.6, edgecolor="k", linewidth=0.5)
            ax.bar(edges[:-1], con_c, width=0.05, align="edge", color=RED, alpha=0.6, edgecolor="k", linewidth=0.5)
            ax.set_ylim(0, 0.6 if b == 0 else 0.45)
            ax.set_xticks(np.arange(0, 1.01, 0.1))
            ax.set_xticklabels(["0", "", "", "", "", "0.5", "", "", "", "", "1"], rotation=0)
            ax.set_yticks(np.arange(0, 0.61, 0.2))
            ax.tick_params(direction="out"); ax.spines[["top", "right"]].set_visible(False)
            for lbl in ax.get_xticklabels() + ax.get_yticklabels():
                lbl.set_fontname("Arial"); lbl.set_fontsize(8)
            ax.text(0.7, 0.3, f"{pct_con}%", color=RED, **FONT)
            ax.text(0.075, 0.3, f"{pct_ipsi}%", color=BLUE, **FONT)
            if b == 0:
                ax.set_ylabel("Fraction of units", **FONT)
            t0 = int(round(1000 * (tw[0] + b * bin_s)))
            t1 = int(round(1000 * (tw[0] + (b + 1) * bin_s)))
            ax.set_title(f"{t0} ~ {t1} ms", fontweight="normal", **FONT)
        fig.tight_layout()
        stem = out_dir / f"AUC_histogram_{site}_{geno}_20Hz_50msBin_-50to150ms_1000nBoot_150pvalueMin"
        fig.savefig(f"{stem}.pdf", dpi=1200, bbox_inches="tight")
        fig.savefig(f"{stem}.png", dpi=300, bbox_inches="tight")
        plt.close(fig)
    print(f"Fig4A AUC histograms ({site}) written -> {out_dir}")


def main(argv=None):
    ap = argparse.ArgumentParser(description="Fig4 S1 ROC panels from flattened ROC exports.")
    ap.add_argument("--export-dir", required=True, help="PyExports root (…/PyExports) OR the S1 folder holding ROC/50msBin and ROC/5msBin")
    ap.add_argument("--out-dir", required=True)
    a = ap.parse_args(argv)
    roc50 = Path(a.export_dir) / "S1" / "ROC" / "50msBin"
    roc5  = Path(a.export_dir) / "S1" / "ROC" / "5msBin"
    auc_histograms(roc50, a.out_dir, site="S1")
    percent_sig_over_time(roc5, a.out_dir, site="S1")
    percent_sig_bootstrap(roc5, a.out_dir, site="S1")
    selectivity_onset(roc5, a.out_dir, site="S1")


if __name__ == "__main__":
    raise SystemExit(main())


# --------------------------------------------------------------------------
# Fig4 — significance over time (5 ms bins) and selectivity onset.
# All three build on the per-unit 5 ms arrays exported by export_roc (roc_5ms_*).
# --------------------------------------------------------------------------

def _load_5ms(export_dir, geno):
    d = load_struct(Path(export_dir) / f"roc_5ms_{geno}.mat")
    auc = np.atleast_2d(np.asarray(d["auc_mean"], float))
    sig = np.atleast_2d(np.asarray(d["is_sig"], float)).astype(bool)
    return auc, sig, int(d["N"]), col(d["timeMs"])


def _pct_con_ipsi(auc, sig, rows=None):
    """Per-bin percent of units significant & contra/ipsi-preferring (MATLAB rounds to 0.1)."""
    if rows is not None:
        auc, sig = auc[rows], sig[rows]
    N = auc.shape[0]
    con = np.round((sig & (auc > 0.5)).sum(0) / N * 100, 1)
    ipsi = np.round((sig & (auc < 0.5)).sum(0) / N * 100, 1)
    return con, ipsi


def percent_sig_over_time(export_dir, out_dir, site="S1"):
    """Fig4: proportion of units with significant side selectivity over time (5 ms)."""
    out_dir = ensure_dir(out_dir)
    fig, ax = plt.subplots(figsize=(1.875, 1.42))
    for g, geno in enumerate(GENOS):
        auc, sig, N, t = _load_5ms(export_dir, geno)
        con, ipsi = _pct_con_ipsi(auc, sig)
        ls = "-" if g == 0 else "--"
        ax.plot(t, con / 100, color=RED, ls=ls, lw=1)
        ax.plot(t, ipsi / 100, color=BLUE, ls=ls, lw=1)
    ax.set_xticks(np.arange(-50, 151, 50)); ax.set_xlim(-10, 100); ax.set_ylim(-0.02, 0.4)
    ax.tick_params(direction="out"); ax.spines[["top", "right"]].set_visible(False)
    for lbl in ax.get_xticklabels() + ax.get_yticklabels():
        lbl.set_fontname("Arial"); lbl.set_fontsize(8)
    ax.set_xlabel("Time from stimulus onset (ms)", **FONT)
    ax.set_ylabel("Proportion of units", **FONT)
    fig.tight_layout()
    stem = out_dir / f"PercentageSigUnit_{site}_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin"
    fig.savefig(f"{stem}.pdf", dpi=300, bbox_inches="tight")
    fig.savefig(f"{stem}.png", dpi=300, bbox_inches="tight")
    plt.close(fig)
    print(f"Fig4 percent-significant-over-time ({site}) -> {out_dir}")


def _boot_pct(auc, sig, nboot, rng):
    """Bootstrap units (resample N with replacement); return con/ipsi %% per boot per bin."""
    N = auc.shape[0]
    con_b = np.empty((nboot, auc.shape[1])); ipsi_b = np.empty((nboot, auc.shape[1]))
    for k in range(nboot):
        idx = rng.integers(0, N, N)
        c, i = _pct_con_ipsi(auc[idx], sig[idx])
        con_b[k], ipsi_b[k] = c, i
    return con_b, ipsi_b


def percent_sig_bootstrap(export_dir, out_dir, site="S1", nboot=1000, seed=0):
    """Fig4: % significant over time with bootstrap 95% CI + WT-KO difference (2x2)."""
    out_dir = ensure_dir(out_dir)
    rng = np.random.default_rng(seed)
    dat = {}
    for geno in GENOS:
        auc, sig, N, t = _load_5ms(export_dir, geno)
        con, ipsi = _pct_con_ipsi(auc, sig)
        cb, ib = _boot_pct(auc, sig, nboot, rng)
        dat[geno] = dict(con=con, ipsi=ipsi, cb=cb, ib=ib, t=t)

    fig, axes = plt.subplots(2, 2, figsize=(4, 3.2))
    for g, geno in enumerate(GENOS):
        ax = axes[g, 0]
        D = dat[geno]; t = D["t"]
        for series, color, boot in [("con", RED, D["cb"]), ("ipsi", BLUE, D["ib"])]:
            lo, hi = np.percentile(boot, [2.5, 97.5], axis=0)
            ax.plot(t, D[series] / 100, color=color, lw=1)
            ax.fill_between(t, lo / 100, hi / 100, color=color, alpha=0.3, lw=0)
        ax.set_xticks(np.arange(-50, 151, 50)); ax.set_xlim(-10, 100); ax.set_ylim(-0.02, 0.4)
        ax.tick_params(direction="out"); ax.spines[["top", "right"]].set_visible(False)
        ax.set_xlabel("Time from stimulus onset (ms)", **FONT)
        ax.set_ylabel("Fraction of units", **FONT)

    # WT - KO difference (contra, ipsi) with CI, top-right
    axd = axes[0, 1]; t = dat["WT"]["t"]
    for series, color in [("con", RED), ("ipsi", BLUE)]:
        diff = (dat["WT"][series] - dat["KO"][series]) / 100
        boot_key = "cb" if series == "con" else "ib"
        diff_boot = dat["WT"][boot_key] - dat["KO"][boot_key]
        lo, hi = np.percentile(diff_boot, [2.5, 97.5], axis=0)
        axd.plot(t, diff, color=color, lw=1)
        axd.fill_between(t, lo / 100, hi / 100, color=color, alpha=0.3, lw=0)
    axd.axhline(0, ls="--", color="k")
    axd.set_yticks(np.arange(-0.3, 0.31, 0.15)); axd.set_xticks(np.arange(-50, 151, 50))
    axd.set_xlim(-10, 100); axd.set_ylim(-0.3, 0.3)
    axd.tick_params(direction="out"); axd.spines[["top", "right"]].set_visible(False)
    axd.set_xlabel("Time from stimulus onset (ms)", **FONT)
    axd.set_ylabel("Fraction of units", **FONT)
    axes[1, 1].axis("off")  # 4th quadrant unused (matches original)
    for ax in axes.ravel():
        for lbl in ax.get_xticklabels() + ax.get_yticklabels():
            lbl.set_fontname("Arial"); lbl.set_fontsize(8)
    fig.tight_layout()
    stem = out_dir / f"PercentageSigUnit_{site}_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin"
    fig.savefig(f"{stem}bootstrapped.pdf", dpi=300, bbox_inches="tight")
    fig.savefig(f"{stem}bootstrapped.png", dpi=300, bbox_inches="tight")
    plt.close(fig)
    print(f"Fig4 percent-significant bootstrap ({site}, seed={seed}) -> {out_dir}")


def _ecdf_step(ax, data, **kw):
    x = np.sort(np.asarray(data, float))
    n = x.size
    if n == 0:
        return
    y = np.arange(1, n + 1) / n
    ax.step(np.concatenate([[x[0]], x]), np.concatenate([[0.0], y]), where="post", **kw)


def selectivity_onset(export_dir, out_dir, site="S1", consec=3):
    """Fig4D: onset of significant side selectivity (>=3 consecutive 5 ms bins), CDF + KS tests."""
    from scipy.stats import ks_2samp
    out_dir = ensure_dir(out_dir)
    # analysis window [0,150] ms -> bins 11..40 (1-indexed) -> python cols 10..40
    b0, b1 = 10, 40
    onsets = {}   # geno -> dict(con=[...], ipsi=[...], n_con, n_ipsi, n_sig)
    fig, ax = plt.subplots(figsize=(2.25, 1.48))
    for g, geno in enumerate(GENOS):
        auc, sig, N, t = _load_5ms(export_dir, geno)
        sw = sig[:, b0:b1]           # N x 30
        aw = auc[:, b0:b1]
        con_on, ipsi_on = [], []
        n_sig = 0
        for u in range(N):
            s = sw[u].astype(int)
            three = (s[:-2] + s[1:-1] + s[2:]) == consec   # length 28; index j -> bins j,j+1,j+2
            hits = np.flatnonzero(three)
            if hits.size == 0:
                continue
            n_sig += 1
            j = hits[0]
            onset_ms = j * 5.0
            pref = aw[u, j:j + 3].mean()
            if pref > 0.5:
                con_on.append(onset_ms)
            elif pref < 0.5:
                ipsi_on.append(onset_ms)
        onsets[geno] = dict(con=np.array(con_on), ipsi=np.array(ipsi_on), n_sig=n_sig)
        lw = 0.5 if g == 0 else 1.0
        ls = "-" if g == 0 else "--"
        _ecdf_step(ax, con_on, color=RED, ls=ls, lw=lw)
        if len(ipsi_on):
            _ecdf_step(ax, ipsi_on, color=BLUE, ls=ls, lw=lw)
        else:
            ax.axhline(0, color=BLUE, ls=ls, lw=lw)
    ax.set_xlim(0, 40); ax.set_ylim(-0.05, 1); ax.set_yticks(np.arange(0, 1.01, 0.2))
    ax.tick_params(direction="out"); ax.spines[["top", "right"]].set_visible(False)
    for lbl in ax.get_xticklabels() + ax.get_yticklabels():
        lbl.set_fontname("Arial"); lbl.set_fontsize(8)
    ax.set_xlabel("Onset of significant side selectivity (ms)", **FONT)
    ax.set_ylabel("Proportion of units", **FONT)
    fig.tight_layout()
    stem = out_dir / f"SigOnset_{site}_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin"
    fig.savefig(f"{stem}.pdf", dpi=300, bbox_inches="tight")
    fig.savefig(f"{stem}.png", dpi=300, bbox_inches="tight")
    plt.close(fig)

    # KS tests (two-sided). NB: the original .txt held only the first line because a
    # MATLAB typo ('unequaledit(') errored after it; we compute and write all three.
    WTc, KOc, KOi = onsets["WT"]["con"], onsets["KO"]["con"], onsets["KO"]["ipsi"]
    with open(out_dir / "StatisticsSelectivityOnset.txt", "w") as fid:
        fid.write(f"Contra two-sided ks test WT != KO pval: {ks_2samp(WTc, KOc, method='asymp').pvalue:g}\n")
        fid.write(f"KO two-sided ks test contra != ipsi pval: {ks_2samp(KOc, KOi, method='asymp').pvalue:g}\n")
        fid.write(f"two-sided ks test WT contra != KO ipsi pval: {ks_2samp(WTc, KOi, method='asymp').pvalue:g}\n")
    print(f"Fig4 selectivity onset ({site}) -> {out_dir}  "
          f"[WT con/ipsi sig: {onsets['WT']['n_sig']}; KO: {onsets['KO']['n_sig']}]")
