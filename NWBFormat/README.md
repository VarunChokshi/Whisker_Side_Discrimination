# NWB format — Whisker Side Discrimination

This folder holds the **NWB version** of the Whisker Side Discrimination project:
the code that converts the lab's `MSessionExplorer` (`se`) recordings to
[NWB](https://www.nwb.org/), and the code that regenerates every manuscript figure
directly from the NWB dataset. Everything is provided in **both MATLAB and Python**
so the figures can be reproduced in either environment.

The processed data itself is **not** stored here (the NWB files are large). It is
released separately on DANDI — *(add DANDI dataset link here)*. This folder contains
only code, the figure snapshots produced by that code, and documentation.

## Layout

```
NWBFormat/
├── README.md              this file
├── conversion/            se  -> NWB   (MATLAB dump + Python converter — how the NWB set was built)
├── matWSD/                NWB -> manuscript figures, MATLAB pipeline  (code + figures/ + README)
└── pyWSD/                 NWB -> manuscript figures, Python pipeline  (code + figures/ + README)
```

`matWSD/` and `pyWSD/` are the two self-contained figure pipelines. Each reads the
NWB dataset and reproduces the published figures; each has its own README with
step-by-step run instructions. The `conversion/` folder is shared provenance: it
documents how the NWB files were generated from the raw lab `se` objects, and most
users reproducing figures will not need to run it.

## Where the data lives

The pipelines read the NWB dataset from a local `NWBData/` root. On the machine this
was developed on that is:

```
E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData
```

with this internal layout (edit the path near the top of each run script to match
wherever you place the downloaded data):

```
NWBData/
├── Data/
│   ├── behavior/{expert,learning,opto}/*.nwb
│   └── ephys/{S1,M1}/*.nwb
├── Data/Tables/          intermediate accumulation tables (built by the pipeline)
└── Figures/{Matlab,Python}/...   figure outputs written by each pipeline
```

The copies of the figures under `matWSD/figures/` and `pyWSD/figures/` are snapshots
committed to the repository so the results are viewable on GitHub without downloading
the data or running anything.

## Figure ↔ script map

Each panel is ported to **both** languages (a `*_nwb.py` in `pyWSD/` and a `*_nwb.m`
in `matWSD/`), reading NWB and reproducing the published figure.

| Script (`.py` / `.m`)   | Manuscript panels |
|-------------------------|-------------------|
| `fig1_behav_nwb`        | Fig 1D (correct / miss), Fig S1A (amplitude), Fig S1B/C (correct / miss, left / right) |
| `fig1_learning_nwb`     | Fig S1D (learning rate) — needs `SessionInfo.xlsx` |
| `fig2_optoinhib_nwb`    | Fig 2B (Δcorrect), Fig 2C (Δmiss), Fig S2B/C (raw performance), Fig S2D (amplitude) |
| `fig3_tables_nwb`       | accumulation stage → `fig3_tables_S1.mat` / `.csv` (read by the Fig 3 / S3 / S4 panels) |
| `fig3_analysis_nwb`     | per-(session, frequency, unit) analysis core used by the accumulation stage |
| `fig3_panels_nwb`       | Fig 3C (FR heatmap), Fig 3D (mean spike rate), Fig 3E (laterality index), Fig 3F (percent contra) |
| `figS3S4_nwb`           | Fig S3A/B (per-frequency heatmaps), Fig S4A/B (histology / layer preference + bilateral fraction) |
| `fig4_roc_nwb` (+ `_tables`) | Fig 4 / Fig S5 — S1 single-unit ROC / body-side selectivity |
| `fig5_lda_nwb` (+ `_tables`) | Fig 5 — wS1 population LDA decoding |
| `fig6_panels_nwb`, `fig6_roc_nwb` (+ `_tables`) | Fig 6 / Fig S8 — wM1 ephys & single-unit ROC |
| `fig7_lda_nwb` (+ `_tables`) | Fig 7 — wM1 population LDA decoding |
| `figS6_nwb` (+ `figS6b_histology`) | Fig S6 — wM1 depth laterality & S1-vs-M1 selectivity onset |
| `readBehaviorNWB.m`     | shared behavior-NWB reader used by the MATLAB behavior ports |

Every output file is named by its manuscript figure and panel plus what it shows,
e.g. `Fig3D - Mean spike rate contra vs ipsi (window 150 ms).pdf`.

## Getting started

1. Download the NWB dataset from DANDI *(link above)* and note its `NWBData/` path.
2. Pick a language and open its folder:
   - MATLAB → [`matWSD/README.md`](matWSD/README.md)
   - Python → [`pyWSD/README.md`](pyWSD/README.md)
3. Edit the data-root path near the top of that pipeline's run script and run it.

Both pipelines call the same analysis logic and produce matching figures.

## Notes on reproducibility

Panels built from anatomical reconstructions (Allen CCF atlas + SHARP-Track
histology) depend on histology inputs and are handled by the `figS4a_histology*` /
`figS6b_histology*` scripts; the raw brain-surface renderings that require the atlas
are provided as the original manuscript images rather than regenerated here. See each
pipeline's README for the current status of these panels.

*(This README was auto-drafted for the public release — edit freely.)*
