function export_fig1(allVarsMat, outRoot)
%EXPORT_FIG1  Flatten Fig1/S1 behavior results (AllVars) to python-safe -v7 structs.
%
%   export_fig1(allVarsMat, outRoot)
%
% fig1_behav.m computes per-mouse means and multilevel-bootstrap CIs and saves
% them as MATLAB tables in AllVars_nboot1000_260903.mat. Tables are opaque to
% scipy, so this pulls out the per-genotype arrays the panels need and saves
% plain -v7 structs.
%
%   allVarsMat : path to AllVars_nboot1000_260903.mat
%   outRoot    : export root; files go to <outRoot>\behavior\Fig1\fig1_behav_<geno>.mat
%
% Each fig1_behav_<geno>.mat holds (nMouse = 10 WT / 8 KO):
%   mean_overall [1xN], mean_tt [Nx2] (left,right), amp_left/amp_right [1xN]
%   ci_overall/ci_left/ci_right [3xN] (row1 mean, row2 2.5%, row3 97.5%)
%   ...and the _miss counterparts (mean_overall_miss, mean_tt_miss, ci_*_miss)

    A = load(allVarsMat);
    PT = A.photoInhTable;   PTm = A.photoInhTable_miss;
    PB = A.photoInhBootstrapped;  PBm = A.photoInhBootstrapped_miss;
    outDir = fullfile(outRoot, 'behavior', 'Fig1');
    if ~exist(outDir, 'dir'); mkdir(outDir); end

    for g = 1:height(PT)
        s = struct();
        s.genotype          = PT.Genotype{g};
        s.mean_overall      = PT.MeanOverall{g}(:)';
        s.mean_tt           = PT.MeanEachTrialType{g};        % nMouse x 2 (left,right)
        s.ci_overall        = PB.CIstats_overall{g};          % 3 x nMouse
        s.ci_left           = PB.CI_left{g};
        s.ci_right          = PB.CI_right{g};
        s.amp_left          = PB.Amp_left{g}(:)';
        s.amp_right         = PB.Amp_Right{g}(:)';
        s.mean_overall_miss = PTm.MeanOverall{g}(:)';
        s.mean_tt_miss      = PTm.MeanEachTrialType{g};
        s.ci_overall_miss   = PBm.CIstats_overall{g};
        s.ci_left_miss      = PBm.CI_left{g};
        s.ci_right_miss     = PBm.CI_right{g};
        save(fullfile(outDir, ['fig1_behav_' PT.Genotype{g} '.mat']), '-struct', 's', '-v7');
    end
    fprintf('export_fig1: wrote fig1_behav_{%s}.mat to %s\n', strjoin(PT.Genotype', ','), outDir);
end
