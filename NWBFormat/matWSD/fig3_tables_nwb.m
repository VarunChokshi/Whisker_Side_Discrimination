function fig3_tables_nwb(regionDir, region, outDir, varargin)
% FIG3_TABLES_NWB  Accumulation stage for the Figure 3 / S3 / S4 pipeline (reads NWB).
%
%   fig3_tables_nwb(regionDir, region, outDir)
%   fig3_tables_nwb(regionDir, region, outDir, 'force')   % allow outDir outside NWBData
%
% Reads every NWB in regionDir once and writes the accumulated tables the figure
% ports consume, mirroring GetComposite / GetFRData / AddMeanFRData in a single
% tidy, both-language artifact: one row per (session, frequency, unit) with the
% session/unit metadata, the per-window pvalBoth / pvalContra / pvalIpsi / cbias,
% and the per-unit mean contra/ipsi firing-rate traces with across-trial 95% CIs.
%
% Outputs (into outDir), identical in schema to fig3_tables_nwb.py:
%   fig3_tables_<region>.mat        struct 'fig3Table' with the scalar columns
%                                   (arrays / cellstr) + trace matrices
%                                   (contraMean/ipsiMean/contra|ipsi CI lo/hi,
%                                   nRows x nBins) + frTime (1 x nBins).
%   fig3_unit_table_<region>.csv    the scalar columns only, for inspection.
%
% Row i of the CSV and of every trace matrix correspond to the same (session,
% frequency, unit). Requires matnwb on the path.

    windowNames = {'25', '40', '50', '75', '100', '150', '200', '300'};

    % Safeguard: write only under an NWBData folder unless 'force' is passed.
    forceWrite = ~isempty(varargin) && isequal(varargin{1}, 'force');
    if ~contains(lower(outDir), 'nwbdata') && ~forceWrite
        error('fig3_tables_nwb:outsideNWBData', ...
            ['Refusing to write to ''%s'' (not under an NWBData folder). ', ...
             'Use e.g. ...\\NWBData\\Data\\Tables, or call with a fourth ''force'' argument.'], outDir);
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % --- read records ---
    fprintf('accumulating %s tables from %s\n', region, regionDir);
    records = fig3_analysis_nwb(regionDir);
    nRows = numel(records);
    nBins = numel(records(1).frTime);

    % --- preallocate scalar columns ---
    animal = cell(nRows, 1);
    genotype = cell(nRows, 1);
    session = cell(nRows, 1);
    recSite = cell(nRows, 1);
    regionCol = repmat({region}, nRows, 1);
    freq = cell(nRows, 1);
    unit = zeros(nRows, 1);
    depthRaw = zeros(nRows, 1);
    depthNorm = zeros(nRows, 1);
    ksLabel = cell(nRows, 1);
    nContraTrials = zeros(nRows, 1);
    nIpsiTrials = zeros(nRows, 1);
    pvalBoth = zeros(nRows, numel(windowNames));
    pvalContra = zeros(nRows, numel(windowNames));
    pvalIpsi = zeros(nRows, numel(windowNames));
    cbias = zeros(nRows, numel(windowNames));

    % --- preallocate trace matrices ---
    contraMean = zeros(nRows, nBins);
    ipsiMean = zeros(nRows, nBins);
    contraCILo = zeros(nRows, nBins);
    contraCIHi = zeros(nRows, nBins);
    ipsiCILo = zeros(nRows, nBins);
    ipsiCIHi = zeros(nRows, nBins);

    % --- fill row by row ---
    for rowInd = 1:nRows
        record = records(rowInd);
        animal{rowInd} = record.animal;
        genotype{rowInd} = record.genotype;
        session{rowInd} = record.session;
        recSite{rowInd} = record.recSite;
        freq{rowInd} = record.freq;
        unit(rowInd) = record.unit;                 % already 1-based
        depthRaw(rowInd) = record.depthRaw;
        depthNorm(rowInd) = record.depthNorm;
        ksLabel{rowInd} = record.ksLabel;
        nContraTrials(rowInd) = numel(record.spikesContra{1});
        nIpsiTrials(rowInd) = numel(record.spikesIpsi{1});
        for windowInd = 1:numel(windowNames)
            windowStats = record.perWindow.(['w' windowNames{windowInd}]);
            pvalBoth(rowInd, windowInd) = windowStats.pvalBoth;
            pvalContra(rowInd, windowInd) = windowStats.pvalContra;
            pvalIpsi(rowInd, windowInd) = windowStats.pvalIpsi;
            cbias(rowInd, windowInd) = windowStats.cbias;
        end
        [cMean, cLo, cHi] = traceMeanCI(record.frContra);
        [iMean, iLo, iHi] = traceMeanCI(record.frIpsi);
        contraMean(rowInd, :) = cMean;
        contraCILo(rowInd, :) = cLo;
        contraCIHi(rowInd, :) = cHi;
        ipsiMean(rowInd, :) = iMean;
        ipsiCILo(rowInd, :) = iLo;
        ipsiCIHi(rowInd, :) = iHi;
    end

    % --- assemble the fig3Table struct (scalar columns + per-window + traces) ---
    fig3Table = struct();
    fig3Table.animal = animal;
    fig3Table.genotype = genotype;
    fig3Table.session = session;
    fig3Table.recSite = recSite;
    fig3Table.region = regionCol;
    fig3Table.freq = freq;
    fig3Table.unit = unit;
    fig3Table.depthRaw = depthRaw;
    fig3Table.depthNorm = depthNorm;
    fig3Table.ksLabel = ksLabel;
    fig3Table.nContraTrials = nContraTrials;
    fig3Table.nIpsiTrials = nIpsiTrials;
    for windowInd = 1:numel(windowNames)
        windowName = windowNames{windowInd};
        fig3Table.(['pvalBoth_' windowName]) = pvalBoth(:, windowInd);
        fig3Table.(['pvalContra_' windowName]) = pvalContra(:, windowInd);
        fig3Table.(['pvalIpsi_' windowName]) = pvalIpsi(:, windowInd);
        fig3Table.(['cbias_' windowName]) = cbias(:, windowInd);
    end
    fig3Table.frTime = records(1).frTime;
    fig3Table.contraMean = contraMean;
    fig3Table.ipsiMean = ipsiMean;
    fig3Table.contraCILo = contraCILo;
    fig3Table.contraCIHi = contraCIHi;
    fig3Table.ipsiCILo = ipsiCILo;
    fig3Table.ipsiCIHi = ipsiCIHi;

    % --- save .mat (-v7 so scipy.io.loadmat can read it) ---
    matPath = fullfile(outDir, ['fig3_tables_' region '.mat']);
    save(matPath, 'fig3Table', '-v7');

    % --- write the scalar columns as CSV (same column order as the Python port) ---
    csvTable = table(animal, genotype, session, recSite, regionCol, freq, unit, ...
        depthRaw, depthNorm, ksLabel, nContraTrials, nIpsiTrials, ...
        'VariableNames', {'animal', 'genotype', 'session', 'recSite', 'region', 'freq', ...
        'unit', 'depthRaw', 'depthNorm', 'ksLabel', 'nContraTrials', 'nIpsiTrials'});
    for windowInd = 1:numel(windowNames)
        windowName = windowNames{windowInd};
        csvTable.(['pvalBoth_' windowName]) = pvalBoth(:, windowInd);
        csvTable.(['pvalContra_' windowName]) = pvalContra(:, windowInd);
        csvTable.(['pvalIpsi_' windowName]) = pvalIpsi(:, windowInd);
        csvTable.(['cbias_' windowName]) = cbias(:, windowInd);
    end
    csvPath = fullfile(outDir, ['fig3_unit_table_' region '.csv']);
    writetable(csvTable, csvPath);

    fprintf('wrote %d rows -> %s, %s\n', nRows, ...
        ['fig3_unit_table_' region '.csv'], ['fig3_tables_' region '.mat']);
end

% ===================================================================== %
function [meanVals, ciLower, ciUpper] = traceMeanCI(traceMatrix, alpha)
    % Across-trial mean and two-sided (1-alpha) t CI for a (nTrials, nBins) matrix,
    % matching MMath.MeanStats.
    if nargin < 2
        alpha = 0.05;
    end
    nTrials = size(traceMatrix, 1);
    meanVals = mean(traceMatrix, 1);
    if nTrials < 2
        ciLower = meanVals;
        ciUpper = meanVals;
        return
    end
    sd = std(traceMatrix, 0, 1);
    se = sd ./ sqrt(nTrials);
    tCrit = tinv(1 - alpha / 2, nTrials - 1);
    ciLower = meanVals - tCrit .* se;
    ciUpper = meanVals + tCrit .* se;
end
