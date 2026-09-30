%% EXPORT_ALL  Flatten every MATLAB result table the Python pipeline needs.
%
% Run this ONCE (section by section) in MATLAB to produce the -v7 struct exports
% that the Python figure scripts read. It reads the original ROC/LDA result
% tables and writes flattened, scipy-readable structs under PyExports\.
%
% Put this folder on the MATLAB path first (it holds export_lda.m / export_roc.m):
%   addpath(fileparts(mfilename('fullpath')))

%% Configuration  (edit mainDir; run first)
% mainDir holds <recSite>\{ROC,LDA}\<bin>msBin\ with the Unit_AUC_*/LDA_* tables.
mainDir = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\SeData\EphysPassiveStimSEs\SingleUnitAnalysis';
outRoot = fullfile(mainDir, 'PyExports');
addpath(fileparts(mfilename('fullpath')));
fprintf('exports -> %s\n', outRoot);

%% Fig5 — S1 LDA (50 ms bin, -50..50 ms)
export_lda(mainDir, 'S1', 50, {'-50to0', '0to50'}, outRoot);

%% Fig7 — wM1 (Motor) LDA (100 ms bin, -100..100 ms)
export_lda(mainDir, 'Motor', 100, {'-100to0', '0to100'}, outRoot);

%% Fig4A — S1 ROC AUC histograms
export_roc(mainDir, 'S1', outRoot);

%% Fig1 / S1 — behavior (flatten AllVars)
allVars = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\Fig1\AllVars_nboot1000_260903.mat';
export_fig1(allVars, outRoot);

%% Fig2 / S2 — opto inhibition (flatten InhibitionAllVars)
inhVars = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\Fig2\InhibitionAllVars_nboot10000_240124.mat';
export_fig2(inhVars, outRoot);

%% Fig3 / S3 — wS1 ephys per-unit tables (flatten to fig3_tables_S1.mat)
s1EphysDir = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\SeData\EphysPassiveStimSEs\Figures\Bodyside8\allWins\AllUnitswS12_5';
export_fig3(s1EphysDir, 'S1', outRoot);

%% Fig6 / S8 — wM1 ephys per-unit tables (flatten to fig3_tables_M1.mat)
m1EphysDir = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\SeData\EphysPassiveStimSEs\Figures\Bodyside8\allWins\AllUnitswM12_5';
export_fig3(m1EphysDir, 'M1', outRoot);

%% Done
disp('All exports written.');
