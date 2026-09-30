# Whisker Side Discrimination — Robo3cKO bilateral somatosensory maps

Code and reproducible figure pipelines for:

> **Neural and behavioral adaptation to bilateral maps in primary somatosensory cortex**
> Varun B. Chokshi, Yi‑Ting Chang, Daniel M. Ra, Reha S. Erzurumlu, Daniel H. O'Connor
> Solomon H. Snyder Department of Neuroscience, Johns Hopkins University; Dept. of Anatomy & Neurobiology, University of Maryland School of Medicine.

This repository contains everything needed to reproduce the analyses and manuscript figures, provided in **two parallel forms** so the work is usable both inside the O'Connor‑lab MATLAB ecosystem and as a standalone, standards‑based release.

---

## Background — what the study is about

In normal (wild‑type, WT) mice, primary whisker somatosensory cortex (**wS1**) represents only the **contralateral** whiskers. This is because whisker projections cross the midline completely as they ascend from the brainstem to the thalamus, producing a somatotopic map of one side of the face in each hemisphere.

In **Robo3 conditional knockout (Robo3cKO)** mice, this axonal crossover is disrupted. wS1 instead contains **bilateral whisker maps** — individual layer‑4 barrels can be driven by an ipsilateral *or* a contralateral whisker — even though the overall map size is unchanged.

The central question: **can the brain build accurate sensorimotor representations despite this fundamental rewiring of its sensory input?** The study answers this with a behavioral task, causal optogenetic manipulation, and electrophysiology at two stages of the whisker sensorimotor pathway (wS1 and whisker primary motor cortex, **wM1**).

### The whisker side discrimination (WSD) task

Head‑fixed mice were trained to report **which side of the face** a single C2 whisker was deflected on (left vs. right) by licking one of two lick ports. On each trial an auditory cue preceded a brief **20 Hz, 150 ms sinusoidal** C2 deflection on the left or right (~50% each); mice reported the side during a response window beginning 0.2 s after stimulus onset. Stimulus amplitudes were titrated to a 70–75% correct criterion.

### Key findings

- **Behavior is intact.** Robo3cKO mice discriminate whisker side as well as WT littermates — no difference in correct fraction, miss rate, stimulus amplitude, or learning rate (Fig 1, S1).
- **Contralateral wS1 activity is required.** Unilateral optogenetic inhibition of wS1 degrades performance specifically on trials with a whisker stimulus *contralateral* to the silenced hemisphere, in both genotypes — the ectopic ipsilateral responses in Robo3cKO wS1 are not sufficient (Fig 2, S2).
- **Ipsilateral and contralateral responses are segregated in wS1.** Single‑unit recordings show Robo3cKO wS1 neurons are individually selective for one side (strongly contra *or* strongly ipsi), organized into columns; WT neurons are uniformly contra‑preferring (Fig 3, S3, S4).
- **Whisker side is decodable from wS1** at the single‑neuron (ROC) and population (LDA) level in both genotypes (Fig 4, Fig 5, S5).
- **Downstream (wM1) responses are largely normal.** In whisker primary motor cortex, Robo3cKO responses are mostly contralateral, like WT — the ectopic ipsilateral inputs present in wS1 have been filtered out along the sensorimotor stream (Fig 6, Fig 7, S6, S8).

Together the results show the brain can adapt to a dramatic alteration of tactile input to construct accurate sensorimotor representations, in part by keeping ipsilateral and contralateral information segregated in wS1 and suppressing the ectopic signals downstream.

---

## Two data representations

The same recordings are provided in two data structures. Both describe identical experiments; they differ in format and intended audience.

### 1. O'Connor‑lab `MSessionExplorer` (`se`) — the native lab structure

`MSessionExplorer` (**`se`**) is the O'Connor lab's session‑level container for accumulating and preprocessing synchronized neural and behavioral data. A single `se` object holds, per recording session, aligned trial tables, behavioral time series (lick times, whisker/stimulus signals, task epochs), and spike data, together with the toolkit methods used to slice, resample, and epoch them. It is the structure the analyses were originally written against.

In this repository the `se` side lives under **`MsessionsExplorerFormat/`**:

- **`bodyside/`** — the `+BS` package and `BS scripts` that build and preprocess the `se` objects for this project (session assembly, spike/behavior integration, quality control), plus the `ZETA-master` dependency.
- **`Paperfigures/MATLAB/code/`** — the original manuscript figure scripts (`fig1_behav.m` … `fig7_…`) that read `se` objects directly and produce the published figures.
- **`Paperfigures/python/`** — a Python port of the figure pipeline. Because `se`, MATLAB `table`, and `string` objects are opaque to Python, each figure has a small MATLAB **export step** (`matlab_export/export_*.m`) that flattens the panel‑ready results to plain `-v7` structs, which the Python scripts (`code/*.py`, driven by `run_all_figures.ipynb`) then plot. The heavy analysis stays in MATLAB; Python re‑plots the identical numbers.

> Building `se` objects requires the O'Connor‑lab `MSessionExplorer` / `ManyFunctions` toolkit and the raw session data, which are not distributed here.

### 2. NWB — the standardized, shareable format

[Neurodata Without Borders (**NWB**)](https://www.nwb.org/) is a community standard for neurophysiology data. The project's `se` recordings were converted to NWB so the dataset and analyses can be reproduced without any lab‑specific software, and released on **DANDI** *(add dataset link)*.

The NWB side lives under **`NWBFormat/`**:

- **`conversion/`** — the `se → NWB` converter (shared provenance; documents how the NWB files were built).
- **`matWSD/`** — NWB → manuscript figures, **MATLAB** pipeline (one `*_nwb.m` per figure, plus `run_all_figures.m`).
- **`pyWSD/`** — NWB → manuscript figures, **Python** pipeline (one `*_nwb.py` per figure, plus `run_all_figures.ipynb`).

Both NWB pipelines call the same analysis logic in their respective language and regenerate every panel directly from the NWB dataset. Each has its own README with run instructions; see [`NWBFormat/README.md`](NWBFormat/README.md).

---

## Repository layout

```
Whisker_Side_Discrimination/
├── MsessionsExplorerFormat/          native O'Connor-lab (se) pipeline
│   ├── bodyside/                        se accumulation & preprocessing (+BS package, BS scripts, ZETA)
│   └── Paperfigures/
│       ├── MATLAB/code/                 original figure scripts that read se directly
│       └── python/                      Python port
│           ├── code/                    fig*_.py + run_all_figures.ipynb (plots exported results)
│           └── matlab_export/           export_*.m — flatten se results to -v7 structs
│
└── NWBFormat/                         standardized NWB pipeline (released on DANDI)
    ├── conversion/                      se -> NWB
    ├── matWSD/                          NWB -> figures (MATLAB)
    └── pyWSD/                           NWB -> figures (Python)
```

The two top‑level folders are independent: `MsessionsExplorerFormat/` reproduces the figures from the native lab structure, `NWBFormat/` reproduces the same figures from the shareable NWB dataset.

---

## Analyses performed

Every analysis below is implemented in the figure pipelines above (MATLAB and Python; native‑`se` and NWB versions).

| Analysis | What it measures | Manuscript figures |
|----------|------------------|--------------------|
| **Behavioral performance** | Correct fraction (excl. misses), miss fraction, whisker stimulus amplitude, learning rate; WT vs. KO, overall and per stimulus side. Multilevel (hierarchical) bootstrap CIs; Mann‑Whitney U between genotypes. | Fig 1D, S1 |
| **Optogenetic inhibition** | Change in performance (Δcorrect, Δmiss = opto − control) on contra‑ vs. ipsi‑stim trials under unilateral wS1 silencing; hierarchical bootstrap CIs, binomial sign tests, between‑genotype comparison. | Fig 2, S2 |
| **Single‑unit responses (ephys)** | Normalized firing‑rate heatmaps, population mean spike rate (contra vs. ipsi; paired t‑tests), **laterality index** distributions, and per‑penetration percent contra‑preferring units. wS1 and wM1. | Fig 3, Fig 6, S3, S4, S6 |
| **Single‑neuron side decoding (ROC)** | Trial‑by‑trial discrimination of left vs. right C2 whisker from each unit (AUC), in 50 ms and 5 ms windows; fraction of significantly selective units over time; onset latency of significant selectivity (Kolmogorov‑Smirnov tests). | Fig 4, Fig 6, S5, S8 |
| **Population side decoding (LDA)** | Linear‑discriminant classification of whisker side from simultaneously recorded populations; session‑wise and bootstrapped accuracy vs. shuffled controls (50 ms bins in wS1, 100 ms in wM1). | Fig 5, Fig 7 |
| **Imaging & anatomy** | Intrinsic‑signal imaging of single‑whisker responses; histological reconstruction of probe tracks / layer assignment (Allen CCF + SHARP‑Track). | Fig 1B, S4A, S6B |

Output files are named by their manuscript figure and panel, e.g. `Fig3D - Mean spike rate contra vs ipsi (window 150 ms).pdf`.

---

## Reproducing the figures

Pick the representation and language you want; each pipeline has its own README with the exact run steps and the data‑root path to edit.

- **From NWB (recommended for external users):** download the dataset from DANDI, then follow [`NWBFormat/matWSD/README.md`](NWBFormat/matWSD/README.md) (MATLAB) or [`NWBFormat/pyWSD/README.md`](NWBFormat/pyWSD/README.md) (Python).
- **From native `se` (lab / internal):** run the MATLAB scripts in `MsessionsExplorerFormat/Paperfigures/MATLAB/code/`, or the Python port via `MsessionsExplorerFormat/Paperfigures/python/` after running the `matlab_export/` step. See [`MsessionsExplorerFormat/Paperfigures/python/README.md`](MsessionsExplorerFormat/Paperfigures/python/README.md).

---

## Data availability

The processed recordings are **not** stored in this repository (the NWB files are large). They are released on **DANDI** — *(add dataset DOI / link here)*. Snapshot copies of the generated figures are committed under each pipeline's `figures/` folder so the results are viewable without downloading the data.

## Citation

If you use this code or data, please cite Chokshi, Chang, Ra, Erzurumlu & O'Connor, *Neural and behavioral adaptation to bilateral maps in primary somatosensory cortex* — *(add journal / DOI / preprint link when available)*.

## Contact

Daniel H. O'Connor — dan.oconnor@jhmi.edu
