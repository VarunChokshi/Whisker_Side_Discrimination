# pyWSD-MSE — MSessionExplorer-format Python figure pipeline

Python reproduction of the Whisker Side Discrimination paper figures, as a parallel
to the MATLAB pipeline in `../MATLAB/code`. Where the MATLAB scripts read
`MSessionExplorer` (`se`) objects and MATLAB result tables directly, this pipeline
**plots the same MATLAB-computed numbers** after they've been flattened to a
Python-readable form.

## Why a two-step (MATLAB → Python) design

Python (`scipy`) cannot read MATLAB `se` objects, MATLAB `table` objects, **or**
MATLAB `string` arrays — all load as opaque blobs. So every figure has a small
MATLAB **export** step that flattens the panel-ready results into a plain `-v7`
struct (numeric arrays + `cellstr` text only — never `table`, `string`,
`categorical`, or class objects). The Python scripts then read those structs and
draw the figures. The heavy analysis stays in MATLAB; Python only plots (and does
light, identical stats), which guarantees the figures match.

```
python/
├── matlab_export/          run these in MATLAB ONCE to make the exports
│   ├── export_all.m        driver (edit mainDir, run section by section)
│   ├── export_fig1.m       AllVars     -> fig1_behav_* structs             (Fig1/S1)
│   ├── export_fig2.m       InhibitionAllVars -> fig2_opto_* structs         (Fig2/S2)
│   ├── export_lda.m        LDA tables  -> LDA_point_*/LDA_boot_* structs   (Fig5, Fig7)
│   ├── export_roc.m        Unit_AUC    -> auc_hist_*/roc_5ms_* structs     (Fig4)
│   └── export_fig3.m       per-unit tables -> fig3_tables_<S1|M1>.mat     (Fig3, Fig6)
├── code/                   the Python figure scripts
│   ├── mseio.py            shared loader (load_struct, cellstr, col, mround)
│   ├── fig1_behav.py       Fig1/S1 behavior (correct/miss/amplitude, WT vs KO)
│   ├── fig2_optoinhib.py   Fig2/S2 opto inhibition (delta correct/miss, amplitude)
│   ├── fig3_ephys.py       Fig3 (wS1) / Fig6 (wM1) ephys panels (reuses pyWSD plotters)
│   ├── fig3_panels_nwb.py, fig3_analysis_nwb.py   validated pyWSD ephys plotters (shared)
│   ├── fig4_roc.py         Fig4 S1 ROC   (AUC hists, %-sig over time + bootstrap, onset)
│   ├── fig5_lda.py         Fig5 wS1 LDA  (make_lda_figures — shared with Fig7)
│   ├── fig7_lda_motor.py   Fig7 wM1 LDA
│   └── run_all_figures.ipynb   run every ported figure
└── README.md
```

## Requirements

Python 3.9+ with `numpy`, `scipy`, `matplotlib` (`pip install numpy scipy matplotlib`).
MATLAB (with the original result tables on disk) for the one-time export step.

## Run it

1. **Export (MATLAB, once):** open `matlab_export/export_all.m`, set `mainDir` to your
   `SingleUnitAnalysis` folder, run each section. It writes flattened structs under
   `SingleUnitAnalysis/PyExports/<recSite>/<analysis>/<bin>msBin/`.
2. **Figures (Python):** open `code/run_all_figures.ipynb`, set `EXPORTS` (the
   `PyExports` root) and `FIGROOT` (where figures go) in the config cell, run the
   cells. Each script can also be run standalone, e.g.
   `python fig5_lda.py --export-dir <...>/S1/LDA/50msBin --out-dir <...>/Fig5`.

Output filenames match the MATLAB originals (e.g.
`LDA_histogram_S1_WT_20Hz_50msBin_-50to50ms_3respMin.pdf`,
`AUC_histogram_S1_WT_20Hz_50msBin_-50to150ms_1000nBoot_150pvalueMin.pdf`).

## Status

| Figure | Panels | Status |
|--------|--------|--------|
| Fig4 (S1 ROC) | AUC histograms (Fig4A) | **done** (percentages/N match exactly) |
| Fig4 (S1 ROC) | % significant over time (point + bootstrap) | **done** (point lines match; CI bands are a fresh seeded resample) |
| Fig4 (S1 ROC) | selectivity onset (Fig4D) + KS stats | **done** (CDFs match; KS p 0.997 vs 0.999) |
| Fig5 (wS1 LDA) | histogram + bootstrap CI | **done** (matches originals to 4 dp) |
| Fig7 (wM1 LDA) | histogram + bootstrap CI | **done** |
| Fig1 / S1 (behavior) | correct / miss / amplitude, WT vs KO | **done** (matches current AllVars; some on-disk refs predate it) |
| Fig2 / S2 (opto inhibition) | delta correct/miss, amplitude | **done** (all stats match exactly) |
| Fig3 / S3 (wS1 ephys) | heatmap, mean FR, laterality, % contra | **done** (reuses pyWSD plotters; responsive 115/130 match; peaks within ~5%) |
| Fig6 / S8 (wM1 ephys) | heatmap, mean FR | **done** via export_fig3(region='M1') |

A note on colors/filenames: some kept reference outputs predate the current MATLAB
scripts (e.g. black vs red/blue significant units, a `3_respMin` vs `3respMin`
suffix); the ports follow the **current** scripts.

*(Auto-drafted for the public release — edit freely.)*
