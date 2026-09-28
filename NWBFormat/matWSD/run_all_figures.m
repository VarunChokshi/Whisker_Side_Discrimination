%% RUN_ALL_FIGURES  Regenerate every manuscript figure the NWB pipeline reproduces.
%
% A SCRIPT (not a function) so you can run it section by section with Ctrl+Enter
% (Run Section) and step through the pipeline. Run the Configuration section first,
% then any later section in order.
%
% Calls each ported plotting function in turn. All outputs are written under
% NWBData\Figures\..., and every file is named by its manuscript figure and panel
% plus what it shows, e.g. 'Fig3D - Mean spike rate contra vs ipsi (window 150 ms).pdf'.
%
%   fig1_behav_nwb      Fig1D correct/miss, FigS1A amplitude, FigS1B/C left/right
%   fig1_learning_nwb   FigS1D learning rate (needs SessionInfo.xlsx)
%   fig2_optoinhib_nwb  Fig2B delta-correct, Fig2C delta-miss, FigS2B/C/D
%   fig3_tables_nwb     accumulation tables (fig3_tables_S1.mat / .csv)
%   fig3_panels_nwb     Fig3C heatmap, Fig3D mean rate, Fig3E laterality, Fig3F percent contra
%   figS3S4_nwb         FigS3A/B per-frequency heatmaps, FigS4B layer preference + bilateral fraction
%   fig4/5/6/7 + figS6  single-unit ROC, population LDA, wM1 panels, and histology
%
% Requires matnwb on the path.

%% Configuration  (edit BASE and matnwbPath; run this section first)
% BASE is the DATA root (holds Data\ and where Figures\ / Tables\ are written).
BASE = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\NWBData';

% Put this folder's scripts (and matnwb) on the path. mfilename resolves the folder
% this script lives in, so it works wherever matWSD\code is placed.
addpath(fileparts(mfilename('fullpath')));
matnwbPath = 'C:\Users\VarunChokshi\Documents\GitHub\matnwb';
if exist(matnwbPath, 'dir')
    addpath(genpath(matnwbPath));
end

% --- input data folders ---
dataDir     = fullfile(BASE, 'Data');
expertDir   = fullfile(dataDir, 'behavior', 'expert');
learningDir = fullfile(dataDir, 'behavior', 'learning');
optoDir     = fullfile(dataDir, 'behavior', 'opto');
s1EphysDir  = fullfile(dataDir, 'ephys', 'S1');
m1EphysDir  = fullfile(dataDir, 'ephys', 'M1');
tablesDir   = fullfile(dataDir, 'Tables');

% The learning panel needs the per-animal training-window spreadsheet (the ONLY
% non-NWB input). Point this at your LearningSessInfo\SessionInfo.xlsx.
sessInfoXlsx = fullfile(learningDir, 'SessionInfo.xlsx');

% --- output figure folders (MATLAB pipeline -> NWBData\Figures\Matlab\...) ---
figuresDir = fullfile(BASE, 'Figures', 'Matlab');
fig1Dir    = fullfile(figuresDir, 'Fig1_FigS1');
fig2Dir    = fullfile(figuresDir, 'Fig2');
figs2Dir   = fullfile(figuresDir, 'FigS2');
fig3Dir    = fullfile(figuresDir, 'Fig3');
figS3S4Dir = fullfile(figuresDir, 'FigS3_FigS4');
fig4Dir    = fullfile(figuresDir, 'Fig4');
fig5Dir    = fullfile(figuresDir, 'Fig5');
fig6Dir    = fullfile(figuresDir, 'Fig6');
fig7Dir    = fullfile(figuresDir, 'Fig7');
figS6Dir   = fullfile(figuresDir, 'FigS6');
rocTablesDir = fullfile(tablesDir, 'ROC');
ldaTablesDir = fullfile(tablesDir, 'LDA');
histologyTablesDir = fullfile(tablesDir, 'Histology');
for folder = {fig1Dir, fig2Dir, figs2Dir, fig3Dir, figS3S4Dir, fig4Dir, fig5Dir, fig6Dir, fig7Dir, figS6Dir, tablesDir, rocTablesDir, ldaTablesDir, histologyTablesDir}
    if ~exist(folder{1}, 'dir')
        mkdir(folder{1});
    end
end

% Paths to the accumulated tables (defined here so the ephys sections below can run
% on their own once the tables have been built once).
tablesMat   = fullfile(tablesDir, 'fig3_tables_S1.mat');
tablesMatM1 = fullfile(tablesDir, 'fig3_tables_M1.mat');
fprintf('Configured. BASE = %s\n', BASE);

%% Figure 1 / S1  -- behavioral performance (Fig1D correct/miss + FigS1A/B/C)
fig1_behav_nwb(expertDir, fig1Dir);

%% Figure S1D  -- learning rate (needs SessionInfo.xlsx; skipped if missing)
if isfile(sessInfoXlsx)
    fig1_learning_nwb(learningDir, sessInfoXlsx, fig1Dir);
else
    warning('SessionInfo.xlsx not found at %s - skipping FigS1D (learning).', sessInfoXlsx);
end

%% Figure 2 / S2  -- optogenetic inhibition (Fig2B/C + FigS2B/C/D)
fig2_optoinhib_nwb(optoDir, fig2Dir, figs2Dir);

%% Accumulate the Fig3 tables (once; reads the S1 ephys NWBs -> fig3_tables_S1.mat/.csv)
fig3_tables_nwb(s1EphysDir, 'S1', tablesDir);

%% Figure 3 panels  (Fig3C heatmap, Fig3D mean rate, Fig3E laterality, Fig3F percent contra)
fig3_panels_nwb(tablesMat, fig3Dir);

%% Figure S3 / S4 panels  (FigS3A/B per-freq heatmaps, FigS4A Histology, FigS4B layer preference + bilateral fraction)
if ~exist(fullfile(histologyTablesDir, 'figS4a_histology_S1.mat'), 'file')
    figS4a_histology_tables_nwb([], histologyTablesDir);
end
figS3S4_nwb(tablesMat, figS3S4Dir);

%% Figure 4 / S5 -- S1 Single-Unit ROC / Body-Side Selectivity (Fig4A, 4B, 4C, FigS5)
if ~exist(fullfile(rocTablesDir, 'fig4_roc_tables_S1_50ms.mat'), 'file') || ...
   ~exist(fullfile(rocTablesDir, 'fig4_roc_tables_S1_5ms.mat'), 'file')
    fig4_roc_tables_nwb([], rocTablesDir);
end
fig4_roc_nwb(rocTablesDir, fig4Dir);

%% Figure 5 -- wS1 Population LDA Decoding (Fig5A, Fig5B)
if ~exist(fullfile(ldaTablesDir, 'fig5_lda_tables_S1.mat'), 'file')
    fig5_lda_tables_nwb([], ldaTablesDir);
end
fig5_lda_nwb(ldaTablesDir, fig5Dir);

%% wM1 Ephys Table Accumulation (M1)
if ~exist(tablesMatM1, 'file')
    fig3_tables_nwb(m1EphysDir, 'M1', tablesDir);
end

%% Figure 6 / S8 -- wM1 Ephys & Single-Unit ROC (Fig6A, 6B, 6C, 6D_E, 6F, FigS8)
if ~exist(fullfile(rocTablesDir, 'fig6_roc_tables_M1_50ms.mat'), 'file') || ...
   ~exist(fullfile(rocTablesDir, 'fig6_roc_tables_M1_5ms.mat'), 'file')
    fig6_roc_tables_nwb([], rocTablesDir);
end
fig6_panels_nwb(tablesMatM1, fig6Dir);
fig6_roc_nwb(rocTablesDir, fig6Dir);

%% Figure 7 -- wM1 Population LDA Decoding (Fig7A, Fig7B)
if ~exist(fullfile(ldaTablesDir, 'fig7_lda_tables_M1.mat'), 'file')
    fig7_lda_tables_nwb([], ldaTablesDir);
end
fig7_lda_nwb(ldaTablesDir, fig7Dir);

%% Figure S6 -- wM1 Histology, Depth Laterality & S1 vs M1 Selectivity Onset (FigS6B, FigS6C, FigS6D)
if ~exist(fullfile(histologyTablesDir, 'figS6b_histology_M1.mat'), 'file')
    figS6b_histology_tables_nwb([], histologyTablesDir);
end
figS6_nwb(tablesMatM1, rocTablesDir, figS6Dir, [], histologyTablesDir);

%% Done
fprintf('All figures written under %s\n', figuresDir);


