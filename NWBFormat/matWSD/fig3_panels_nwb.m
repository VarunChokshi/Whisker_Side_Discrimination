function fig3_panels_nwb(s1Source, outDir, varargin)
% FIG3_PANELS_NWB  Figure 3 manuscript panels (passive-stim S1 ephys), reading NWB.
%
%   fig3_panels_nwb(s1Dir, outDir)                % read the S1 NWB folder directly
%   fig3_panels_nwb(fig3_tables_S1Mat, outDir)    % read the saved accumulation .mat
%   fig3_panels_nwb(..., 'force')                 % allow an outDir outside NWBData
%
% s1Source is either a folder of S1 NWB files or a fig3_tables_<region>.mat file
% produced by fig3_tables_nwb (preferred: reads the accumulation once).
%
% Builds the three headline Figure 3 panels, mirroring the original
% PlotAvgTracesFRFinal / MakeCbiasFiguresFinal / FRHeatmapsAllFreq:
%   1. population mean contra/ipsi firing-rate traces, WT (top) vs KO (bottom),
%      one column per stimulus frequency (10/20/40 Hz);
%   2. laterality-index (contra-bias) histograms and per-session
%      percent-contra-preferring histograms;
%   3. per-unit contra/ipsi firing-rate heatmaps, sorted by responsive identity
%      then contra-bias.
%
% This is the MATLAB mirror of fig3_panels_nwb.py and is self-contained (local
% meanStats / errorShade helpers, no lab toolbox needed beyond matnwb). Responsive
% units, the significance rule, the per-frequency contra-bias windows and the
% statistics all match the Python port.
%
% Inputs
%   s1Dir   folder of S1 ephys NWB files
%   outDir  folder to write the panels into

    ops = panelOps();

    % Safeguard: the NWB pipeline writes only into NWBData\Figures\..., never the
    % hand-made manuscript figure folders. Refuse an outDir outside NWBData unless
    % the caller passes 'force' as a third argument.
    forceWrite = nargin >= 3 && isequal(varargin{1}, 'force');
    if ~contains(lower(outDir), 'nwbdata') && ~forceWrite
        error('fig3_panels_nwb:outsideNWBData', ...
            ['Refusing to write to ''%s'' (not under an NWBData folder). ', ...
             'Use e.g. ...\\NWBData\\Figures\\Fig3, or call with a third ''force'' argument.'], outDir);
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % --- read records (from the saved accumulation .mat, or the NWB folder) ---
    [~, ~, sourceExt] = fileparts(s1Source);
    if strcmpi(sourceExt, '.mat')
        fprintf('loading records from saved tables %s\n', s1Source);
        records = loadFlatTable(s1Source);
    else
        fprintf('loading S1 records from %s\n', s1Source);
        records = fig3_analysis_nwb(s1Source);
    end
    unitTable = buildUnitTable(records, ops);
    nResponsive = sum([unitTable.responsive]);
    fprintf('built %d unit rows (%d responsive)\n', numel(unitTable), nResponsive);

    % --- the three panels ---
    fprintf('panel 1: population average FR traces\n');
    plotAvgTracesFRFinal(unitTable, outDir, ops);
    fprintf('panel 2: contra-bias / laterality histograms\n');
    makeCbiasFiguresFinal(unitTable, outDir, ops);
    fprintf('panel 3: FR heatmaps\n');
    frHeatmapsAllFreq(unitTable, outDir, ops);
    fprintf('done -> %s\n', outDir);
end

% ===================================================================== %
%  ops (mirrors the original driver block)
% ===================================================================== %
function ops = panelOps()
    ops.plotAlpha = 0.01;
    ops.sigWindow = '150';
    ops.stimSlots = {'10', '20', '40'};
    ops.stimNames = {'10 Hz', '20 Hz', '40 Hz'};
    ops.sigFreq = '20';
    ops.cbiasFirstCycleWindow = {'100', '50', '25'};   % 10 Hz, 20 Hz, 40 Hz
    ops.plotxLims = [-0.05, 0.05];
    ops.maxFR = 30;
    ops.cbiasContra = 0.33;
    ops.cbiasIpsi = -0.33;
    ops.minUnits = 1;
end

% ===================================================================== %
%  build the per-unit table from the analysis records
% ===================================================================== %
function unitTable = buildUnitTable(records, ops)
    % Collapse per-(session, frequency, unit) records into one row per (session,
    % unit), with the per-frequency traces / contra-bias and one responsive flag.
    unitTable = struct([]);
    if isempty(records)
        return
    end

    sessions = {records.session};
    units = [records.unit];
    keys = strcat(sessions, '#', arrayfun(@(x) num2str(x), units, 'UniformOutput', false));
    uniqueKeys = unique(keys, 'stable');

    % Preallocate one row per (session, unit) key; trim the unused tail at the end.
    rowCells = cell(1, numel(uniqueKeys));
    rowCount = 0;

    for keyInd = 1:numel(uniqueKeys)
        memberRecords = records(strcmp(keys, uniqueKeys{keyInd}));
        presentFreqs = {memberRecords.freq};
        multiFreq = numel(unique(presentFreqs)) > 3;

        if multiFreq
            sigFreq = ops.sigFreq;
        else
            uFreqs = unique(presentFreqs);
            sigFreq = uFreqs{1};
        end
        refInd = find(strcmp(presentFreqs, sigFreq), 1);
        if isempty(refInd)
            continue
        end
        reference = memberRecords(refInd);
        responsive = reference.perWindow.(['w' ops.sigWindow]).pvalBoth < ops.plotAlpha;

        % per-slot data (only the 10/20/40 Hz slots used by Figure 3)
        slots = struct();
        for slotInd = 1:numel(ops.stimSlots)
            freq = ops.stimSlots{slotInd};
            if multiFreq
                sourceInd = find(strcmp(presentFreqs, freq), 1);
            elseif strcmp(freq, '20')
                sourceInd = find(strcmp(presentFreqs, sigFreq), 1);
            else
                sourceInd = [];
            end
            if isempty(sourceInd)
                continue
            end
            source = memberRecords(sourceInd);
            cbiasWindow = ops.cbiasFirstCycleWindow{slotInd};
            slot = struct();
            slot.meanContra = mean(source.frContra, 1);
            slot.meanIpsi = mean(source.frIpsi, 1);
            slot.frContra = source.frContra;
            slot.frIpsi = source.frIpsi;
            slot.cbias150 = source.perWindow.(['w' ops.sigWindow]).cbias;
            slot.cbiasFirstCycle = source.perWindow.(['w' cbiasWindow]).cbias;
            slot.pvalBoth150 = source.perWindow.(['w' ops.sigWindow]).pvalBoth;
            slots.(['f' freq]) = slot;
        end

        row = struct();
        row.genotype = reference.genotype;
        row.session = reference.session;
        row.animal = reference.animal;
        row.recSite = reference.recSite;
        row.depthRaw = reference.depthRaw;
        row.depthNorm = reference.depthNorm;
        row.multiFreq = multiFreq;
        row.responsive = logical(responsive);
        row.slots = slots;
        row.frTime = reference.frTime;

        rowCount = rowCount + 1;
        rowCells{rowCount} = row;
    end
    unitTable = [rowCells{1:rowCount}];
end

function genotypes = genotypesIn(unitTable)
    genotypes = unique({unitTable.genotype});
end

function records = loadFlatTable(matPath)
    % Load an accumulated fig3_tables_<region>.mat and return a records struct array
    % compatible with buildUnitTable: each record carries the per-unit mean contra/
    % ipsi trace (as a 1-row matrix so buildUnitTable's mean() recovers it) and the
    % per-window statistics.
    windowNames = {'25', '40', '50', '75', '100', '150', '200', '300'};
    loaded = load(matPath, 'fig3Table');
    table = loaded.fig3Table;
    nRows = numel(table.session);
    frTime = reshape(table.frTime, 1, []);

    recordCells = cell(1, nRows);
    for rowInd = 1:nRows
        perWindow = struct();
        for windowInd = 1:numel(windowNames)
            windowName = windowNames{windowInd};
            perWindow.(['w' windowName]) = struct( ...
                'pvalBoth', table.(['pvalBoth_' windowName])(rowInd), ...
                'pvalContra', table.(['pvalContra_' windowName])(rowInd), ...
                'pvalIpsi', table.(['pvalIpsi_' windowName])(rowInd), ...
                'cbias', table.(['cbias_' windowName])(rowInd));
        end
        record = struct();
        record.animal = table.animal{rowInd};
        record.genotype = table.genotype{rowInd};
        record.recSite = table.recSite{rowInd};
        record.region = table.region{rowInd};
        record.session = table.session{rowInd};
        record.freq = table.freq{rowInd};
        record.unit = table.unit(rowInd);
        record.depthRaw = table.depthRaw(rowInd);
        record.depthNorm = table.depthNorm(rowInd);
        record.ksLabel = table.ksLabel{rowInd};
        record.frTime = frTime;
        record.frContra = table.contraMean(rowInd, :);
        record.frIpsi = table.ipsiMean(rowInd, :);
        record.spikesContra = {{}};
        record.spikesIpsi = {{}};
        record.perWindow = perWindow;
        recordCells{rowInd} = record;
    end
    records = [recordCells{:}];
end

% ===================================================================== %
%  Panel 1: population average FR traces (PlotAvgTracesFRFinal)
% ===================================================================== %
function plotAvgTracesFRFinal(unitTable, outDir, ops)
    genotypes = genotypesIn(unitTable);
    frTime = unitTable(1).frTime;
    nBins = numel(frTime);
    colorContra = [1 0 0];
    colorIpsi = [0 0 1];

    figureHandle = figure('Units', 'inches', 'Position', [1 1 3 2.25], 'Visible', 'off');
    % Upper bound on stat lines: peaks (geno x stim) + 40-10 (2 per geno) + ipsi/contra (geno x stim).
    maxStatLines = numel(genotypes) * numel(ops.stimSlots) * 2 + numel(genotypes) * 2;
    statLines = cell(1, maxStatLines);
    statLineCount = 0;
    postMask = frTime > 0 & frTime < 0.05;
    statContra = struct();
    statIpsi = struct();

    for stimInd = 1:numel(ops.stimSlots)
        freq = ops.stimSlots{stimInd};
        for genoInd = 1:numel(genotypes)
            geno = genotypes{genoInd};
            [contraStack, ipsiStack] = collectTraces(unitTable, geno, freq, nBins);
            [meanContra, loContra, hiContra] = meanStats(contraStack);
            [meanIpsi, loIpsi, hiIpsi] = meanStats(ipsiStack);

            statContra.(['g' geno]).(['f' freq]) = mean(contraStack(:, postMask), 2);
            statIpsi.(['g' geno]).(['f' freq]) = mean(ipsiStack(:, postMask), 2);

            if strcmp(geno, 'KO')
                subplotInd = stimInd + 3;
            else
                subplotInd = stimInd;
            end
            axisHandle = subplot(2, 3, subplotInd, 'Parent', figureHandle);
            hold(axisHandle, 'on');
            plot(axisHandle, frTime, meanContra, 'Color', colorContra, 'LineWidth', 1);
            plot(axisHandle, frTime, meanIpsi, 'Color', colorIpsi, 'LineWidth', 1);
            errorShade(axisHandle, frTime, loContra, hiContra, colorContra);
            errorShade(axisHandle, frTime, loIpsi, hiIpsi, colorIpsi);
            plot(axisHandle, [0 0], [0 ops.maxFR], '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
            ylim(axisHandle, [0 ops.maxFR]);
            xlim(axisHandle, ops.plotxLims);
            set(axisHandle, 'FontSize', 8, 'FontName', 'Arial', ...
                'XTick', ops.plotxLims(1):0.05:ops.plotxLims(2));
            set(axisHandle, 'XTickLabel', arrayfun(@(x) num2str(x * 1000), ...
                get(axisHandle, 'XTick'), 'UniformOutput', false));
            hold(axisHandle, 'off');
            statLineCount = statLineCount + 1;
            statLines{statLineCount} = sprintf('%s: %s Peak Contra: %.4g Peak Ipsi: %.4g', ...
                geno, ops.stimNames{stimInd}, max(meanContra), max(meanIpsi));
        end
    end

    % paired statistics (40 Hz - 10 Hz; contra vs ipsi per stim)
    for genoInd = 1:numel(genotypes)
        geno = genotypes{genoInd};
        if isfield(statContra.(['g' geno]), 'f10') && isfield(statContra.(['g' geno]), 'f40')
            pC = pairedTTest(statContra.(['g' geno]).f40, statContra.(['g' geno]).f10, 'right');
            pI = pairedTTest(statIpsi.(['g' geno]).f40, statIpsi.(['g' geno]).f10, 'right');
            statLineCount = statLineCount + 1;
            statLines{statLineCount} = sprintf('%s 40Hz-10Hz paired-t (contra) p = %.4g', geno, pC);
            statLineCount = statLineCount + 1;
            statLines{statLineCount} = sprintf('%s 40Hz-10Hz paired-t (ipsi) p = %.4g', geno, pI);
        end
    end
    for genoInd = 1:numel(genotypes)
        geno = genotypes{genoInd};
        for stimInd = 1:numel(ops.stimSlots)
            freq = ops.stimSlots{stimInd};
            if ~isfield(statContra.(['g' geno]), ['f' freq])
                continue
            end
            if strcmp(geno, 'WT')
                tail = 'right';
            else
                tail = 'both';
            end
            pCI = pairedTTest(statContra.(['g' geno]).(['f' freq]), ...
                statIpsi.(['g' geno]).(['f' freq]), tail);
            statLineCount = statLineCount + 1;
            statLines{statLineCount} = sprintf('%s %s ipsi vs contra paired-t p = %.4g', ...
                geno, ops.stimNames{stimInd}, pCI);
        end
    end
    statLines = statLines(1:statLineCount);

    savefig(figureHandle, fullfile(outDir, ['Fig3D - Mean spike rate contra vs ipsi (window ' ops.sigWindow ' ms).fig']));
    exportgraphics(figureHandle, fullfile(outDir, ['Fig3D - Mean spike rate contra vs ipsi (window ' ops.sigWindow ' ms).pdf']), ...
        'Resolution', 1200);
    close(figureHandle);
    fid = fopen(fullfile(outDir, 'Fig3D - Mean spike rate peak values.txt'), 'w');
    fprintf(fid, '%s\n', statLines{:});
    fclose(fid);
end

function [contraStack, ipsiStack] = collectTraces(unitTable, geno, freq, nBins)
    % Responsive-unit mean contra/ipsi traces for one genotype and frequency.
    contraStack = zeros(numel(unitTable), nBins);
    ipsiStack = zeros(numel(unitTable), nBins);
    kept = 0;
    for rowInd = 1:numel(unitTable)
        row = unitTable(rowInd);
        if ~strcmp(row.genotype, geno) || ~row.responsive || ~isfield(row.slots, ['f' freq])
            continue
        end
        kept = kept + 1;
        contraStack(kept, :) = row.slots.(['f' freq]).meanContra;
        ipsiStack(kept, :) = row.slots.(['f' freq]).meanIpsi;
    end
    contraStack = contraStack(1:kept, :);
    ipsiStack = ipsiStack(1:kept, :);
end

% ===================================================================== %
%  Panel 2: contra-bias / laterality histograms (MakeCbiasFiguresFinal)
% ===================================================================== %
function makeCbiasFiguresFinal(unitTable, outDir, ops)
    genotypes = genotypesIn(unitTable);
    colorStock = containers.Map({'WT', 'KO'}, {[0 0 0], [0.6 0.6 0.6]});
    lateralityBins = -1:0.25:1;
    percentBins = 0:10:100;

    lateralityFig = figure('Units', 'inches', 'Position', [1 1 4 2], 'Visible', 'off');
    percentFig = figure('Units', 'inches', 'Position', [1 1 3.25 2], 'Visible', 'off');

    for stimInd = 1:numel(ops.stimSlots)
        freq = ops.stimSlots{stimInd};
        for genoInd = 1:numel(genotypes)
            geno = genotypes{genoInd};
            [pooled, sessionCounts] = collectCbias(unitTable, geno, freq, ops);
            if strcmp(geno, 'KO')
                subplotInd = 3 + stimInd;
            else
                subplotInd = stimInd;
            end
            if colorStock.isKey(geno)
                color = colorStock(geno);
            else
                color = [0.3 0.3 0.3];
            end

            % laterality index distribution (probability normalised)
            axisHandle = subplot(2, 3, subplotInd, 'Parent', lateralityFig);
            if ~isempty(pooled)
                histogram(axisHandle, pooled, lateralityBins, ...
                    'FaceColor', color, 'Normalization', 'probability');
            end
            ylim(axisHandle, [0 0.6]);
            yticks(axisHandle, 0:0.2:0.6);
            xticks(axisHandle, -1:0.25:1);
            xticklabels(axisHandle, {'-1', '', '-0.5', '', '0', '', '0.5', '', '1'});
            set(axisHandle, 'FontSize', 8, 'FontName', 'Arial', 'TickDir', 'out');
            if strcmp(geno, 'KO')
                xlabel(axisHandle, 'Laterality index', 'FontSize', 8);
            end

            % per-session percent contra-preferring
            axisHandle = subplot(2, 3, subplotInd, 'Parent', percentFig);
            if ~isempty(sessionCounts)
                totals = sum(sessionCounts, 2);
                percentContra = 100 * sessionCounts(:, 1) ./ totals;
                histogram(axisHandle, percentContra, percentBins, 'FaceColor', color);
            end
            ylim(axisHandle, [0 10]);
            set(axisHandle, 'FontSize', 8, 'FontName', 'Arial', 'TickDir', 'out');
            if strcmp(geno, 'WT') && stimInd == 2
                xlabel(axisHandle, 'Percent of contralateral preferring units', 'FontSize', 8);
            end
        end
    end

    savefig(lateralityFig, fullfile(outDir, 'Fig3E - Laterality index distribution.fig'));
    exportgraphics(lateralityFig, fullfile(outDir, 'Fig3E - Laterality index distribution.pdf'), 'Resolution', 1200);
    savefig(percentFig, fullfile(outDir, 'Fig3F - Percent contra-preferring units.fig'));
    exportgraphics(percentFig, fullfile(outDir, 'Fig3F - Percent contra-preferring units.pdf'), 'Resolution', 1200);
    close(lateralityFig);
    close(percentFig);
end

function [pooled, sessionCounts] = collectCbias(unitTable, geno, freq, ops)
    % Pooled first-cycle contra-bias values and per-session category counts, for
    % responsive units of one genotype at one frequency.
    sessionNames = unique({unitTable(strcmp({unitTable.genotype}, geno)).session});
    pooledCells = cell(1, numel(sessionNames));
    sessionCounts = zeros(numel(sessionNames), 3);
    keptSessions = 0;
    for sessInd = 1:numel(sessionNames)
        values = zeros(1, numel(unitTable));
        kept = 0;
        for rowInd = 1:numel(unitTable)
            row = unitTable(rowInd);
            if ~strcmp(row.genotype, geno) || ~strcmp(row.session, sessionNames{sessInd})
                continue
            end
            if ~row.responsive || ~isfield(row.slots, ['f' freq])
                continue
            end
            value = row.slots.(['f' freq]).cbiasFirstCycle;
            if ~isnan(value)
                kept = kept + 1;
                values(kept) = value;
            end
        end
        values = values(1:kept);
        if isempty(values)
            continue
        end
        pooledCells{sessInd} = values;
        nContra = sum(values >= ops.cbiasContra);
        nBilateral = sum(values >= ops.cbiasIpsi & values < ops.cbiasContra);
        nIpsi = sum(values < ops.cbiasIpsi);
        if (nContra + nBilateral + nIpsi) > ops.minUnits
            keptSessions = keptSessions + 1;
            sessionCounts(keptSessions, :) = [nContra, nBilateral, nIpsi];
        end
    end
    pooled = [pooledCells{:}];
    sessionCounts = sessionCounts(1:keptSessions, :);
end

% ===================================================================== %
%  Panel 3: FR heatmaps (FRHeatmapsAllFreq)
% ===================================================================== %
function frHeatmapsAllFreq(unitTable, outDir, ops)
    genotypes = genotypesIn(unitTable);
    frTime = unitTable(1).frTime;
    respColormap = [0 0 1; 1 1 1; 1 0 0];

    for genoInd = 1:numel(genotypes)
        geno = genotypes{genoInd};
        contraRows = cell(1, numel(unitTable));
        ipsiRows = cell(1, numel(unitTable));
        cbiasList = zeros(1, numel(unitTable));
        respList = zeros(1, numel(unitTable));
        kept = 0;
        for rowInd = 1:numel(unitTable)
            row = unitTable(rowInd);
            if ~strcmp(row.genotype, geno) || ~row.responsive
                continue
            end
            [meanContra, meanIpsi, cbias] = averageSlots(row, ops);
            if isempty(meanContra)
                continue
            end
            if cbias >= ops.cbiasContra
                respId = 1;
            elseif cbias < ops.cbiasIpsi
                respId = -1;
            else
                respId = 0;
            end
            kept = kept + 1;
            contraRows{kept} = meanContra;
            ipsiRows{kept} = meanIpsi;
            cbiasList(kept) = cbias;
            respList(kept) = respId;
        end
        if kept == 0
            continue
        end
        contraRows = contraRows(1:kept);
        ipsiRows = ipsiRows(1:kept);
        cbiasList = cbiasList(1:kept);
        respList = respList(1:kept);

        % sort by respId desc, then cbias desc
        [~, order] = sortrows([respList(:), cbiasList(:)], [-1 -2]);
        contraMat = cell2mat(contraRows(order)');
        ipsiMat = cell2mat(ipsiRows(order)');
        respIds = respList(order);

        % per-unit normalisation by combined contra/ipsi peak
        for unitInd = 1:size(contraMat, 1)
            peak = max([contraMat(unitInd, :), ipsiMat(unitInd, :)]);
            if peak > 0
                contraMat(unitInd, :) = contraMat(unitInd, :) / peak;
                ipsiMat(unitInd, :) = ipsiMat(unitInd, :) / peak;
            end
        end

        nUnits = size(contraMat, 1);
        yTicks = 20:20:nUnits;
        numColors = 256;
        rampDown = 1 - linspace(0, 1, numColors)';
        contraColormap = [ones(numColors, 1), rampDown, rampDown];      % white -> red
        ipsiColormap = [rampDown, rampDown, ones(numColors, 1)];        % white -> blue

        figureHandle = figure('Units', 'inches', 'Position', [1 1 1.6 2], 'Visible', 'off');

        % contra panel (white -> red)
        axisContra = subplot(1, 21, 1:10, 'Parent', figureHandle);
        imagesc(axisContra, frTime, 1:nUnits, contraMat, [0 1]);
        line(axisContra, [0 0], [1 nUnits], 'Color', 'k', 'LineStyle', '--', 'LineWidth', 1);
        xlim(axisContra, ops.plotxLims);
        set(axisContra, 'Units', 'inches', 'Position', [0.24 0.2 0.45 1.75], ...
            'FontSize', 8, 'FontName', 'Arial', 'YTick', yTicks, 'TickDir', 'out', ...
            'XTick', [ops.plotxLims(1) 0 ops.plotxLims(2)], 'XTickLabel', {'-50', '0', '50'}, 'LineWidth', 1);
        colormap(axisContra, contraColormap);
        if strcmp(geno, 'WT')
            cbarContra = colorbar(axisContra);
            set(cbarContra, 'Units', 'inches', 'Position', [0.12 1.55 0.08 0.4], ...
                'Color', [0 0 0], 'LineWidth', 0.5, 'Ticks', [0 1]);
        end

        % ipsi panel (white -> blue)
        axisIpsi = subplot(1, 21, 11:20, 'Parent', figureHandle);
        imagesc(axisIpsi, frTime, 1:nUnits, ipsiMat, [0 1]);
        line(axisIpsi, [0 0], [1 nUnits], 'Color', 'k', 'LineStyle', '--', 'LineWidth', 1);
        xlim(axisIpsi, ops.plotxLims);
        set(axisIpsi, 'Units', 'inches', 'Position', [0.95 0.2 0.45 1.75], ...
            'FontSize', 8, 'FontName', 'Arial', 'YTick', yTicks, 'YTickLabel', [], 'TickDir', 'out', ...
            'XTick', [ops.plotxLims(1) 0 ops.plotxLims(2)], 'XTickLabel', {'-50', '0', '50'}, 'LineWidth', 1);
        colormap(axisIpsi, ipsiColormap);
        if strcmp(geno, 'WT')
            cbarIpsi = colorbar(axisIpsi);
            set(cbarIpsi, 'Units', 'inches', 'Position', [0.83 1.55 0.08 0.4], ...
                'Color', [0 0 0], 'LineWidth', 0.5, 'Ticks', [0 1]);
        end

        % responsive-identity column (blue / white / red)
        axisResp = subplot(1, 21, 21, 'Parent', figureHandle);
        imagesc(axisResp, respIds(:) + 1);
        colormap(axisResp, respColormap);
        set(axisResp, 'Units', 'inches', 'Position', [1.45 0.2 0.05 1.75], ...
            'FontSize', 8, 'FontName', 'Arial', 'XTick', [], 'YTick', [], 'TickDir', 'out', 'LineWidth', 1);

        savefig(figureHandle, fullfile(outDir, ['Fig3C - Normalized FR heatmap ' geno '.fig']));
        exportgraphics(figureHandle, fullfile(outDir, ['Fig3C - Normalized FR heatmap ' geno '.pdf']), 'Resolution', 1200);
        close(figureHandle);
    end
end

function [meanContra, meanIpsi, cbias] = averageSlots(row, ops)
    % Mean contra/ipsi trace averaged across available 10/20/40 Hz slots, and the
    % 20 Hz (150 ms) contra-bias for the responsive identity.
    nBins = numel(row.frTime);
    contraSlots = zeros(numel(ops.stimSlots), nBins);
    ipsiSlots = zeros(numel(ops.stimSlots), nBins);
    kept = 0;
    cbias = NaN;
    firstSlot = '';
    for slotInd = 1:numel(ops.stimSlots)
        freq = ops.stimSlots{slotInd};
        if ~isfield(row.slots, ['f' freq])
            continue
        end
        kept = kept + 1;
        contraSlots(kept, :) = row.slots.(['f' freq]).meanContra;
        ipsiSlots(kept, :) = row.slots.(['f' freq]).meanIpsi;
        if isempty(firstSlot)
            firstSlot = freq;
        end
    end
    if kept == 0
        meanContra = [];
        meanIpsi = [];
        return
    end
    meanContra = mean(contraSlots(1:kept, :), 1);
    meanIpsi = mean(ipsiSlots(1:kept, :), 1);
    if isfield(row.slots, 'f20')
        cbias = row.slots.f20.cbias150;
    else
        cbias = row.slots.(['f' firstSlot]).cbias150;
    end
end

% ===================================================================== %
%  statistics / plotting helpers (self-contained)
% ===================================================================== %
function [meanVals, ciLower, ciUpper] = meanStats(values, alpha)
    % Column-wise mean and two-sided (1-alpha) t confidence interval, matching
    % MMath.MeanStats. values is (nRows, nColumns).
    if nargin < 2
        alpha = 0.05;
    end
    if isempty(values)
        meanVals = [];
        ciLower = [];
        ciUpper = [];
        return
    end
    n = sum(~isnan(values), 1);
    meanVals = mean(values, 1, 'omitnan');
    sd = std(values, 0, 1, 'omitnan');
    se = sd ./ sqrt(max(n, 1));
    tCrit = zeros(size(n));
    valid = n > 1;
    tCrit(valid) = tinv(1 - alpha / 2, n(valid) - 1);
    ciLower = meanVals - tCrit .* se;
    ciUpper = meanVals + tCrit .* se;
end

function pval = pairedTTest(popA, popB, tail)
    % Paired t-test on (popA - popB); tail is 'right' or 'both'.
    nPairs = min(numel(popA), numel(popB));
    if nPairs < 2
        pval = NaN;
        return
    end
    diff = popA(1:nPairs) - popB(1:nPairs);
    [~, pval] = ttest(diff, 0, 'Tail', tail);
end

function errorShade(axisHandle, x, lower, upper, color)
    % Fill the band between lower and upper with a translucent colour.
    x = x(:)';
    lower = lower(:)';
    upper = upper(:)';
    valid = ~isnan(lower) & ~isnan(upper);
    if ~any(valid)
        return
    end
    x = x(valid);
    lower = lower(valid);
    upper = upper(valid);
    patch(axisHandle, [x, fliplr(x)], [upper, fliplr(lower)], color, ...
        'FaceAlpha', 0.3, 'EdgeColor', 'none');
end
