function export_roc(mainDir, recSite, outRoot)
%EXPORT_ROC  Flatten the Fig4 ROC results into python-safe -v7 structs.
%
%   export_roc(mainDir, recSite, outRoot)
%
% The Unit_AUC tables store, per session, a cell of units; each responsive unit
% is a cell of per-time-bin 1x1000 (pre-sorted) bootstrap AUC distributions.
% None of that is scipy-readable. This computes the per-unit derived quantities
% the Fig4 panels need (the ANALYSIS is done here, in MATLAB) and saves plain
% -v7 structs that fig4_roc.py only has to plot / lightly aggregate.
%
%   mainDir : ...\SingleUnitAnalysis  (holds <recSite>\ROC\{50msBin,5msBin}\Unit_AUC_*.mat)
%   recSite : 'S1' (Fig4)   [Motor supported for the analogous wM1 panels]
%   outRoot : export root; files go to <outRoot>\<recSite>\ROC\<bin>\
%
% Produces:
%   50msBin\auc_hist_<geno>.mat : auc_mean, is_sig ([nUnits x 4]); N; nBoot;
%                                 timeWindow ([-0.05 0.15]); binSec (0.05)   -> Fig4A
%   5msBin\roc_5ms_<geno>.mat   : auc_mean, is_sig ([nUnits x 40]); N; nBoot;
%                                 timeMs (40); binSec (0.005); analysisWindow  -> %-sig
%                                 over time, bootstrap, and selectivity onset (Fig4D)
%
% Significance = Bonferroni CI (alpha/N) on the 1000-boot AUC excludes 0.5.

    alpha = 0.05; nBoot = 1000;
    genotypes = {'WT', 'KO'};

    % ---- 50 ms bins (Fig4A AUC histograms) ----
    src50 = fullfile(mainDir, recSite, 'ROC', '50msBin', ...
        'Unit_AUC_20Hz_50msBin_-50to150ms_1000nBoot_150pvalueMin.mat');
    out50 = fullfile(outRoot, recSite, 'ROC', '50msBin');
    export_one(src50, out50, genotypes, alpha, nBoot, 'auc_hist_', ...
               struct('timeWindow', [-0.05 0.15], 'binSec', 0.05));

    % ---- 5 ms bins (percent-significant over time, bootstrap, onset) ----
    src5 = fullfile(mainDir, recSite, 'ROC', '5msBin', ...
        'Unit_AUC_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin.mat');
    out5 = fullfile(outRoot, recSite, 'ROC', '5msBin');
    export_one(src5, out5, genotypes, alpha, nBoot, 'roc_5ms_', ...
               struct('timeWindow', [-0.05 0.15], 'binSec', 0.005, 'analysisWindow', [0 0.15]));
end


function export_one(srcFile, outDir, genotypes, alpha, nBoot, prefix, extra)
    if ~exist(outDir, 'dir'); mkdir(outDir); end
    L = load(srcFile); AUC_table = L.AUC_table;

    for g = 1:numel(genotypes)
        geno = genotypes{g};
        isGeno   = strcmp(AUC_table.genotype, geno);
        AUC_geno = AUC_table.AUC(isGeno);
        AUC_units = {};
        for s = 1:numel(AUC_geno)
            AUC_units = [AUC_units, AUC_geno{s}]; %#ok<AGROW>
        end
        isResp   = cellfun(@iscell, AUC_units);
        AUC_resp = AUC_units(isResp);
        N = numel(AUC_resp);
        alphaB = alpha / N;
        nBins = numel(AUC_resp{1});

        auc_mean = nan(N, nBins); is_sig = false(N, nBins);
        for b = 1:nBins
            for u = 1:N
                d = AUC_resp{u}{b, 1};                 % 1x1000, pre-sorted ascending
                auc_mean(u, b) = mean(d);
                up = d(ceil((1 - alphaB/2) * nBoot));
                lo = d(ceil((alphaB/2)     * nBoot));
                is_sig(u, b) = (0.5 - up) * (0.5 - lo) > 0;
            end
        end

        st = struct('auc_mean', auc_mean, 'is_sig', double(is_sig), 'N', N, 'nBoot', nBoot);
        st.binSec = extra.binSec; st.timeWindow = extra.timeWindow;
        if isfield(extra, 'analysisWindow'); st.analysisWindow = extra.analysisWindow; end
        % time axis in ms for the fine grid (matches MATLAB: tw(1)+bin : bin : tw(2))
        st.timeMs = ((extra.timeWindow(1) + extra.binSec) : extra.binSec : extra.timeWindow(2)) * 1000;
        save(fullfile(outDir, [prefix geno '.mat']), '-struct', 'st', '-v7');
    end
    fprintf('export_roc: wrote %s{WT,KO}.mat to %s\n', prefix, outDir);
end
