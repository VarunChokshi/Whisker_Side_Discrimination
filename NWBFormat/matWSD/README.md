# matWSD — MATLAB figure pipeline (NWB)

Regenerates the Whisker Side Discrimination manuscript figures from the NWB dataset
using MATLAB. The figures read NWB via [**matnwb**](https://github.com/NeurodataWithoutBorders/matnwb),
the standard NeurodataWithoutBorders MATLAB API. This is the MATLAB counterpart of
[`../pyWSD/`](../pyWSD/README.md); both produce matching figures.

## What's in here

```
matWSD/
├── run_all_figures.m       driver script (run it section-by-section)
├── fig1_behav_nwb.m        Fig 1D / S1A-C   behavioral performance
├── fig1_learning_nwb.m     Fig S1D          learning rate  (needs SessionInfo.xlsx)
├── fig2_optoinhib_nwb.m    Fig 2B/C, S2B-D  optogenetic inhibition
├── fig3_analysis_nwb.m     per-unit analysis core (called by fig3_tables)
├── fig3_tables_nwb.m       accumulation stage -> fig3_tables_S1.mat / .csv
├── fig3_panels_nwb.m       Fig 3C/D/E/F     wS1 ephys panels
├── figS3S4_nwb.m           Fig S3A/B, S4A/B per-frequency heatmaps + layer preference
├── fig4_roc_nwb.m + _tables    Fig 4 / S5   S1 single-unit ROC
├── fig5_lda_nwb.m + _tables    Fig 5        wS1 population LDA
├── fig6_panels_nwb.m, fig6_roc_nwb.m + _tables   Fig 6 / S8   wM1 ephys & ROC
├── fig7_lda_nwb.m + _tables    Fig 7        wM1 population LDA
├── figS6_nwb.m + figS6b_histology*         Fig S6   wM1 depth laterality
├── figS4a_histology*                       Fig S4A histology tables/panel
├── readBehaviorNWB.m       shared behavior-NWB reader used by the behavior ports
└── figures/                committed snapshot of the figures this pipeline produces
```

## Requirements

- **MATLAB** (developed on R2023+; earlier recent versions should work).
- **matnwb** on the MATLAB path, with the core classes generated once (see below).
- The scripts are otherwise self-contained — no lab packages are needed to make
  figures from NWB (the `MSessionExplorer` / `ManyFunctions` packages are only needed
  for the one-time `../conversion/` step, not here).

## One-time setup: install matnwb

```
git clone https://github.com/NeurodataWithoutBorders/matnwb "C:\Users\<you>\Documents\GitHub\matnwb"
```

Then, once per matnwb install / MATLAB version:

```matlab
addpath(genpath('C:\Users\<you>\Documents\GitHub\matnwb'))
cd('C:\Users\<you>\Documents\GitHub\matnwb')
generateCore()      % builds the +types classes matnwb uses to read NWB
```

`run_all_figures.m` will add matnwb to the path for you if you point `matnwbPath` at
your install, but `generateCore()` must have been run once beforehand.

## Run it

1. Open `run_all_figures.m` in MATLAB. It is a **script** with `%%` sections so you
   can step through the pipeline with **Run Section** (Ctrl+Enter).
2. In the **Configuration** section (run it first), edit two paths:
   - `BASE` — the `NWBData` data root, e.g.
     `E:\...\manuscripts\bodyside_S1\NWBData`
   - `matnwbPath` — where you cloned matnwb.
   The script self-locates its own folder (`mfilename`), so the figure functions are
   put on the path automatically wherever you place `matWSD`.
3. Run the later sections in order. Each writes its panels under
   `NWBData\Figures\Matlab\Fig...\`, named by manuscript figure and panel, e.g.
   `Fig3D - Mean spike rate contra vs ipsi (window 150 ms).pdf`.

To reproduce a single figure, run just its section (the Configuration section first).
The `fig3` / `fig4` / `fig6` sections build small accumulation tables under
`NWBData\Data\Tables\` on first run and reuse them afterwards.

### Learning panel (Fig S1D)

`fig1_learning_nwb` additionally needs the per-animal training-window spreadsheet
`SessionInfo.xlsx` (the only non-NWB input). Point `sessInfoXlsx` in the Configuration
section at your copy; the section is skipped with a warning if the file is absent.

## Calling one function directly

Each function takes explicit input/output folders, e.g.:

```matlab
fig1_behav_nwb( ...
  fullfile(BASE,'Data','behavior','expert'), ...
  fullfile(BASE,'Figures','Matlab','Fig1_FigS1'));

fig3_panels_nwb( ...
  fullfile(BASE,'Data','Tables','fig3_tables_S1.mat'), ...
  fullfile(BASE,'Figures','Matlab','Fig3'));
```

## Troubleshooting

If a run throws a matnwb API error on the first read, it is almost always because
`generateCore()` has not been run for this matnwb/MATLAB version — run it and retry.

*(This README was auto-drafted for the public release — edit freely.)*
