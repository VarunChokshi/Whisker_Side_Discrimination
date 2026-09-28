# pyWSD — Python figure pipeline (NWB)

Regenerates the Whisker Side Discrimination manuscript figures from the NWB dataset
using Python. The figures read NWB via [**pynwb**](https://pynwb.readthedocs.io/).
This is the Python counterpart of [`../matWSD/`](../matWSD/README.md); both produce
matching figures.

## What's in here

```
pyWSD/
├── run_all_figures.ipynb   driver notebook (run top to bottom, or cell-by-cell)
├── fig1_behav_nwb.py       Fig 1D / S1A-C   behavioral performance
├── fig1_learning_nwb.py    Fig S1D          learning rate  (needs SessionInfo.xlsx)
├── fig2_optoinhib_nwb.py   Fig 2B/C, S2B-D  optogenetic inhibition
├── fig3_analysis_nwb.py    per-unit analysis core (imported by fig3_tables / fig3_panels)
├── fig3_tables_nwb.py      accumulation stage -> fig3_tables_S1.mat / .csv
├── fig3_panels_nwb.py      Fig 3C/D/E/F     wS1 ephys panels
├── figS3S4_nwb.py          Fig S3A/B, S4A/B per-frequency heatmaps + layer preference
├── fig4_roc_nwb.py + _tables    Fig 4 / S5  S1 single-unit ROC
├── fig5_lda_nwb.py + _tables    Fig 5       wS1 population LDA
├── fig6_panels_nwb.py, fig6_roc_nwb.py + _tables   Fig 6 / S8   wM1 ephys & ROC
├── fig7_lda_nwb.py + _tables    Fig 7       wM1 population LDA
├── figS6_nwb.py + figS6b_histology*         Fig S6   wM1 depth laterality
├── figS4a_histology*                        Fig S4A histology tables/panel
├── check_nwb_files.py, compress_nwb_datasets.py, fix_nwb_metadata.py   dataset utilities
├── README_nwb_compression.md                notes on compress_nwb_datasets.py
└── figures/                committed snapshot of the figures this pipeline produces
```

## Requirements

Python 3.9+ with:

```
pip install pynwb numpy scipy matplotlib pandas
```

(`pynwb` pulls in `h5py` / `hdmf`.) No lab packages are needed to make figures from
NWB — the `MSessionExplorer` / `ManyFunctions` packages are only used for the one-time
`../conversion/` step, not here.

## Run it — notebook

1. Open `run_all_figures.ipynb` (Jupyter / VS Code) **from the `pyWSD` folder** so the
   notebook's working directory is this folder — the config cell puts this folder on
   `sys.path` via `Path.cwd()`, which is how it imports the figure modules.
2. In the **Configuration** cell, set `BASE` to your `NWBData` data root, e.g.
   `Path(r"E:\...\manuscripts\bodyside_S1\NWBData")`.
3. Run top to bottom, or run only the section for the figure you want (run the
   Configuration cell first). Outputs go to `NWBData\Figures\Python\Fig...\`, each named
   by manuscript figure and panel, e.g.
   `Fig3D - Mean spike rate contra vs ipsi (window 150 ms).pdf`.

The `fig3` / `fig4` / `fig6` sections build small accumulation tables under
`NWBData\Data\Tables\` on first run and reuse them afterwards.

## Run it — command line

Every module is also runnable standalone with `argparse`, e.g.:

```bash
python fig1_behav_nwb.py --nwb-dir "E:\...\NWBData\Data\behavior\expert" \
                         --out-dir "E:\...\NWBData\Figures\Python\Fig1_FigS1"

python fig3_panels_nwb.py --tables "E:\...\NWBData\Data\Tables\fig3_tables_S1.mat" \
                          --out-dir "E:\...\NWBData\Figures\Python\Fig3"
```

`fig3_panels_nwb.py` accepts either `--tables` (a saved accumulation `.mat`) or
`--s1-dir` (a folder of S1 ephys NWBs, read directly). By design it refuses an
`--out-dir` that is not under an `NWBData` folder unless you pass `--force`, so a run
can never overwrite the hand-made manuscript figure folders.

### Learning panel (Fig S1D)

`fig1_learning_nwb` additionally needs the per-animal training-window spreadsheet
`SessionInfo.xlsx` (the only non-NWB input). Point `SESSINFO_XLSX` in the config cell
at your copy; the section is skipped if the file is absent.

*(This README was auto-drafted for the public release — edit freely.)*
