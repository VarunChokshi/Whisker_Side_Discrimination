function export_fig2(allVarsMat, outRoot)
%EXPORT_FIG2  Flatten Fig2 opto-inhibition results to python-safe -v7 structs.
%
%   export_fig2(allVarsMat, outRoot)
%
% Fig2 plots the per-mouse optogenetic-inhibition EFFECT (delta = opto - control)
% on correct/miss fraction and the whisker amplitude, for contra vs ipsi stims,
% pooled over the two inhibition sites (Right S1 / Left S1). The MATLAB tables in
% InhibitionAllVars are opaque to scipy, and the site-dependent column indexing is
% intricate, so this replicates the exact plot-time extraction and saves plain
% -v7 arrays that fig2_optoinhib.py only has to place and draw.
%
%   allVarsMat : path to InhibitionAllVars_nboot10000_240124.mat
%   outRoot    : export root; -> <outRoot>\behavior\Fig2\fig2_opto_<geno>.mat
%
% Each fig2_opto_<geno>.mat holds (dim1 = inhibition site: 1=Right S1, 2=Left S1):
%   correct_contra_mean/ipsi_mean [2 x nMouse]   raw per-mouse delta (marker)
%   correct_contra_ci/ipsi_ci     [2 x 3 x nMouse] bootstrap CI (mean,lo,hi) (errorbar)
%   miss_* (same), amp_contra/amp_ipsi [2 x nMouse]  (CIAmp mean / 10)

    A = load(allVarsMat);
    PB = A.photoInhBootstrapped;  PBm = A.photoInhBootstrapped_miss;
    PT = A.photoInhTable;         PTm = A.photoInhTable_miss;
    outDir = fullfile(outRoot, 'behavior', 'Fig2');
    if ~exist(outDir, 'dir'); mkdir(outDir); end
    genos = unique(PB.Genotype, 'stable');

    for gi = 1:numel(genos)
        geno = genos{gi};
        PBg = PB(strcmp(PB.Genotype, geno), :);   PTg = PT(strcmp(PT.Genotype, geno), :);
        PBmg = PBm(strcmp(PBm.Genotype, geno), :); PTmg = PTm(strcmp(PTm.Genotype, geno), :);
        [ccm, ccc, cim, cic, ccs, cis] = deltaArrays(PBg, PTg);
        [mcm, mcc, mim, mic, mcs, mis] = deltaArrays(PBmg, PTmg);
        nm = size(ccm, 2);
        ampc = nan(2, nm); ampi = nan(2, nm);
        % contra: RightS1 -> left-side amp, LeftS1 -> right-side amp; ipsi swaps
        ampc(1, :) = PBg.CIAmp_left{1}(1, :) / 10;   ampc(2, :) = PBg.CIAmp_right{2}(1, :) / 10;
        ampi(1, :) = PBg.CIAmp_right{1}(1, :) / 10;  ampi(2, :) = PBg.CIAmp_left{2}(1, :) / 10;
        s = struct('genotype', geno, ...
            'correct_contra_mean', ccm, 'correct_contra_ci', ccc, ...
            'correct_ipsi_mean',  cim, 'correct_ipsi_ci',  cic, ...
            'miss_contra_mean', mcm, 'miss_contra_ci', mcc, ...
            'miss_ipsi_mean',   mim, 'miss_ipsi_ci',   mic, ...
            'amp_contra', ampc, 'amp_ipsi', ampi, ...
            'correct_contra_stat', ccs, 'correct_ipsi_stat', cis, ...
            'miss_contra_stat', mcs, 'miss_ipsi_stat', mis);
        save(fullfile(outDir, ['fig2_opto_' geno '.mat']), '-struct', 's', '-v7');
    end
    fprintf('export_fig2: wrote fig2_opto_{%s}.mat to %s\n', strjoin(genos', ','), outDir);
end


function [cm, cc, im, ic, sm, si] = deltaArrays(PBg, PTg)
% Per genotype, build contra/ipsi delta mean [2 x n] and CI [2 x 3 x n].
% MeanData columns: [Lctrl, Lopto, Rctrl, Ropto]; delta = opto - control.
    MD1 = PTg.MeanData{1};  MD2 = PTg.MeanData{2};   % nMouse x 4 (rows: mouse)
    nm = size(MD1, 1);
    dL1 = (MD1(:, 2) - MD1(:, 1))';  dR1 = (MD1(:, 4) - MD1(:, 3))';   % Right S1 site
    dL2 = (MD2(:, 2) - MD2(:, 1))';  dR2 = (MD2(:, 4) - MD2(:, 3))';   % Left  S1 site
    CIdL1 = PBg.CI_dleft{1};  CIdR1 = PBg.CI_dright{1};                % 3 x nMouse
    CIdL2 = PBg.CI_dleft{2};  CIdR2 = PBg.CI_dright{2};
    cm = nan(2, nm); im = nan(2, nm); cc = nan(2, 3, nm); ic = nan(2, 3, nm);
    % contra: site1(Right S1) -> left delta ; site2(Left S1) -> right delta
    cm(1, :) = dL1;  cm(2, :) = dR2;  cc(1, :, :) = CIdL1;  cc(2, :, :) = CIdR2;
    % ipsi:  site1 -> right delta ; site2 -> left delta
    im(1, :) = dR1;  im(2, :) = dL2;  ic(1, :, :) = CIdR1;  ic(2, :, :) = CIdL2;
    % Stat arrays: the between-genotype/binomial tests use Meanstats_dleft/dright
    % (bootstrap-mean delta), NOT the MeanData column difference used for markers.
    msdL1 = PTg.Meanstats_dleft{1}(1, :);  msdR1 = PTg.Meanstats_dright{1}(1, :);   % Right S1
    msdL2 = PTg.Meanstats_dleft{2}(1, :);  msdR2 = PTg.Meanstats_dright{2}(1, :);   % Left  S1
    sm = [msdL1; msdR2];   % contra: site1 -> dleft ; site2 -> dright
    si = [msdR1; msdL2];   % ipsi:   site1 -> dright ; site2 -> dleft
end
