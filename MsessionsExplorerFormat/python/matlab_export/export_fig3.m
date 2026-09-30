function export_fig3(tableDir, region, outRoot)
%EXPORT_FIG3  Flatten the MSE per-unit ephys tables into the pyWSD fig3Table schema.
%
%   export_fig3(tableDir, region, outRoot)
%
% Writes a compact fig3_tables_<region>.mat in the same "fig3Table" layout that
% pyWSD's fig3_panels/loadFlatTable reads, so the validated pyWSD ephys plotters
% render the MSE-computed numbers.
%
%   tableDir : ...\Figures\Bodyside8\allWins\AllUnitswS12_5   (Fig3, region 'S1')
%              ...\AllUnitswM12_5                              (Fig6, region 'M1')
%   region   : 'S1' or 'M1';   outRoot -> <outRoot>\ephys\fig3_tables_<region>.mat
%
% MSE nesting (built at script lines 1247/1258): for metadataTable field F in
% {pvalBoth,pvalContra,pvalIpsi,cbias,UnitDepth}:
%     metadataTable.F{animal}.(window){session}.(stim){unit} = scalar
% and FRdataTable.meanFR{animal}.(window){session} is a [nUnits x nStim] table
% whose cells are {time[1xT], contra[trials x T], ipsi[trials x T]}. Stim column
% names (e.g. '20hz') are the frequencies; we key p-values/cbias/depth by the same
% name so units and freqs line up without positional guessing.

    WIN = {'25','40','50','75','100','150','200','300'};
    TRACEWIN = '300';
    mmeta = matfile(fullfile(tableDir, 'allVars.mat'));    MT = mmeta.metadataTable;
    mfr   = matfile(fullfile(tableDir, 'FRdataVars.mat')); FT = mfr.FRdataTable;
    outDir = fullfile(outRoot, 'ephys'); if ~exist(outDir,'dir'); mkdir(outDir); end
    animals = MT.Properties.RowNames;

    R = struct('animal',{{}},'genotype',{{}},'session',{{}},'recSite',{{}}, ...
               'region',{{}},'freq',{{}},'unit',[],'depthRaw',[],'depthNorm',[],'ksLabel',{{}}, ...
               'nContraTrials',[],'nIpsiTrials',[]);
    for wi=1:numel(WIN)
        R.(['pvalBoth_' WIN{wi}])=[]; R.(['pvalContra_' WIN{wi}])=[];
        R.(['pvalIpsi_' WIN{wi}])=[]; R.(['cbias_' WIN{wi}])=[];
    end
    contraMean = {}; ipsiMean = {}; frTime = [];

    for a = 1:numel(animals)
        geno = ''; if ismember('genotype', MT.Properties.VariableNames); geno = char(MT.genotype{a}); end
        pB = colOrEmpty(MT,'pvalBoth',a);   pC = colOrEmpty(MT,'pvalContra',a);
        pI = colOrEmpty(MT,'pvalIpsi',a);   cb = colOrEmpty(MT,'cbias',a);
        dp = colOrEmpty(MT,'UnitDepth',a);   % M1 metadata may lack UnitDepth
        frA = FT.meanFR{a};                         % table rows=sessions x cols=windows
        sessNames = frA.Properties.RowNames;
        for s = 1:numel(sessNames)
            sessFR = frA.(TRACEWIN){s};             % [nUnits x nStim] table
            freqNames = sessFR.Properties.VariableNames;
            nUnits = height(sessFR);
            for fi = 1:numel(freqNames)
                fn = freqNames{fi};
                freqLbl = regexprep(fn, '\D', '');   % '20hz' -> '20'
                col = sessFR.(fn);                    % {nUnits x 1}
                for u = 1:nUnits
                    x = col{u};
                    if isempty(x) || ~iscell(x) || numel(x) < 3; continue; end
                    if isempty(x{2}) || isempty(x{3}); continue; end
                    t = x{1}(:).';  cM = mean(x{2},1);  iM = mean(x{3},1);
                    if isempty(frTime); frTime = t; end
                    nB = numel(frTime);
                    R.animal{end+1,1}=animals{a}; R.genotype{end+1,1}=geno;
                    R.session{end+1,1}=sessNames{s}; R.recSite{end+1,1}=region; R.region{end+1,1}=region;
                    R.freq{end+1,1}=freqLbl; R.unit(end+1,1)=u;
                    R.depthRaw(end+1,1)=scal(dp, TRACEWIN, s, fn, u);
                    R.depthNorm(end+1,1)=scal(dp, TRACEWIN, s, fn, u);
                    R.ksLabel{end+1,1}='good';
                    R.nContraTrials(end+1,1)=size(x{2},1); R.nIpsiTrials(end+1,1)=size(x{3},1);
                    for wi=1:numel(WIN)
                        R.(['pvalBoth_' WIN{wi}])(end+1,1)   = scal(pB, WIN{wi}, s, fn, u);
                        R.(['pvalContra_' WIN{wi}])(end+1,1) = scal(pC, WIN{wi}, s, fn, u);
                        R.(['pvalIpsi_' WIN{wi}])(end+1,1)   = scal(pI, WIN{wi}, s, fn, u);
                        R.(['cbias_' WIN{wi}])(end+1,1)      = scal(cb, WIN{wi}, s, fn, u);
                    end
                    contraMean{end+1,1}=fitBins(cM,nB); ipsiMean{end+1,1}=fitBins(iM,nB);
                end
            end
        end
        fprintf('  animal %s (%s): running rows=%d\n', animals{a}, geno, numel(R.unit));
    end

    fig3Table = R;
    fig3Table.contraMean = cell2mat(contraMean);
    fig3Table.ipsiMean   = cell2mat(ipsiMean);
    fig3Table.frTime     = frTime;
    save(fullfile(outDir, ['fig3_tables_' region '.mat']), 'fig3Table', '-v7');
    fprintf('export_fig3: wrote %d rows to %s\n', numel(R.unit), fullfile(outDir, ['fig3_tables_' region '.mat']));
end

function c = colOrEmpty(T, name, a)
    if ismember(name, T.Properties.VariableNames); c = T.(name){a}; else; c = []; end
end

function v = scal(F, win, s, fn, u)
% F.(win){s}.(fn){u}  -> scalar (robust to missing window/stim/nesting)
    v = NaN;
    try
        if isempty(F) || ~ismember(win, F.Properties.VariableNames); return; end
        sessTab = F.(win){s};
        if ~ismember(fn, sessTab.Properties.VariableNames); return; end
        z = sessTab.(fn);
        if iscell(z); z = z{u}; end
        while iscell(z); if isempty(z); return; end; z = z{1}; end
        if ~isempty(z); v = double(z(1)); end
    catch
    end
end

function y = fitBins(x, n)
    x = x(:).'; if numel(x)>=n; y = x(1:n); else; y = [x, nan(1, n-numel(x))]; end
end
