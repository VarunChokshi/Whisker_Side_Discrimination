"""
Fig7 — Whisker-side stimulus discriminability in wM1 (population LDA decoding).

Python port of Fig7_Robo3_LDA_plot_motor.m. Identical to Fig5 except it reads the
Motor (wM1) LDA exports with a 100 ms bin over [-100, 100] ms. Reuses
fig5_lda.make_lda_figures (plots the original MATLAB-computed accuracies).
"""
from __future__ import annotations
import argparse
from fig5_lda import make_lda_figures


def main(argv=None):
    ap = argparse.ArgumentParser(description="Fig7 wM1 LDA decoding from flattened LDA exports.")
    ap.add_argument("--export-dir", required=True, help="folder with Motor LDA_point_*/LDA_boot_* .mat")
    ap.add_argument("--out-dir", required=True)
    a = ap.parse_args(argv)
    make_lda_figures(a.export_dir, a.out_dir, site="Motor", bin_s=0.1,
                     time_window=(-0.1, 0.1), legend_x=0.65)


if __name__ == "__main__":
    raise SystemExit(main())
