function figS3S4_nwb(s1Source, outDir, varargin)
% FIGS3S4_NWB  Figure S3 / S4 supplement panels (passive-stim S1 ephys), reading NWB.
%
%   figS3S4_nwb(fig3_tables_S1Mat, outDir)        % read the saved accumulation .mat
%   figS3S4_nwb(s1Dir, outDir)                     % read the S1 NWB folder directly
%   figS3S4_nwb(..., 'force')                      % allow an outDir outside NWBData
%
% FigS3: frHeatmapsEachFreq  -> per-frequency (10/20/40 Hz) contra/ipsi FR heatmaps.
% FigS4: cBiasDepthHistoLine  -> contra-bias vs cortical-depth layer band, per genotype.
%
% Mirror of figS3S4_nwb.py. Self-contained (local helpers), needs matnwb only when
% reading NWBs directly. The atlas-based histology panels (PlotHistoCBias /
% PlotHistoResponsiveness) are not reproducible from NWB alone and are omitted.

    ops = panelOps();
    forceWrite = ~isempty(varargin) && isequal(varargin{1}, 'force');
    if ~contains(lower(outDir), 'nwbdata') && ~forceWrite
        error('figS3S4_nwb:outsideNWBData', ...
            ['Refusing to write to ''%s'' (not under an NWBData folder). ', ...
             'Use e.g. ...\\NWBData\\Figures\\FigS3S4, or pass a ''force'' argument.'], outDir);
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % --- records: from the saved accumulation .mat, or the NWB folder ---
    [~, ~, sourceExt] = fileparts(s1Source);
    if strcmpi(sourceExt, '.mat')
        fprintf('loading records from saved tables %s\n', s1Source);
        records = loadFlatTable(s1Source);
    else
        fprintf('loading S1 records from %s\n', s1Source);
        records = fig3_analysis_nwb(s1Source);
    end
    unitTable = buildUnitTable(records, ops);
    fprintf('built %d unit rows (%d responsive)\n', numel(unitTable), sum([unitTable.responsive]));

    fprintf('FigS3: per-frequency FR heatmaps\n');
    frHeatmapsEachFreq(unitTable, outDir, ops);

    % FigS4A: 3D reconstructed wS1 unit CCF locations
    histologyDir = fullfile(fileparts(s1Source), 'Histology');
    if ~exist(histologyDir, 'dir')
        histologyDir = fullfile(fileparts(fileparts(s1Source)), 'Tables', 'Histology');
    end
    if exist(fullfile(histologyDir, 'figS4a_histology_S1.mat'), 'file')
        fprintf('FigS4A: 3D wS1 histology CCF locations\n');
        figS4a_histology_nwb(histologyDir, outDir);
    end

    fprintf('FigS4B: contra-bias vs depth by layer\n');
    cBiasDepthHistoLine(unitTable, outDir, ops);
    fprintf('FigS4: bilateral fraction L4 vs other\n');
    bilateralFractionL4vsOther(unitTable, outDir, ops);
    fprintf('done -> %s\n', outDir);
end

% ===================================================================== %
%  ops
% ===================================================================== %
function ops = panelOps()
    ops.plotAlpha = 0.01;
    ops.sigWindow = '150';
    ops.stimSlots = {'10', '20', '40'};
    ops.sigFreq = '20';
    ops.cbiasFirstCycleWindow = {'100', '50', '25'};
    ops.plotxLims = [-0.05, 0.05];
    ops.cbiasContra = 0.33;
    ops.cbiasIpsi = -0.33;
    % FigS4 layer boundaries on normalised depth (Minamisawa et al. 2018 / 1154 um).
    ops.LTwoThree = 418 / 1154;
    ops.LFour = 588 / 1154;
    ops.depthAdjust = 50 / 1154;
    ops.lateralityThird = 1 / 3;
end

% ===================================================================== %
%  FigS3: per-frequency FR heatmaps
% ===================================================================== %
function frHeatmapsEachFreq(unitTable, outDir, ops)
    genotypes = unique({unitTable.genotype});
    frTime = unitTable(1).frTime;

    for genoInd = 1:numel(genotypes)
        geno = genotypes{genoInd};

        % per responsive unit: cross-frequency peak, respId, cbias, per-freq traces
        nRows = numel(unitTable);
        unitPeak = zeros(1, nRows);
        unitResp = zeros(1, nRows);
        unitCbias = zeros(1, nRows);
        unitSlotContra = cell(1, nRows);
        unitSlotIpsi = cell(1, nRows);
        kept = 0;
        for rowInd = 1:numel(unitTable)
            row = unitTable(rowInd);
            if ~strcmp(row.genotype, geno) || ~row.responsive
                continue
            end
            peak = 0;
            contraByFreq = struct();
            ipsiByFreq = struct();
            for slotInd = 1:numel(ops.stimSlots)
                freq = ops.stimSlots{slotInd};
                if isfield(row.slots, ['f' freq])
                    peak = max([peak, max(row.slots.(['f' freq]).meanContra), ...
                        max(row.slots.(['f' freq]).meanIpsi)]);
                    contraByFreq.(['f' freq]) = row.slots.(['f' freq]).meanContra;
                    ipsiByFreq.(['f' freq]) = row.slots.(['f' freq]).meanIpsi;
                end
            end
            if peak <= 0
                continue
            end
            if isfield(row.slots, 'f20')
                cbias = row.slots.f20.cbias150;
            else
                slotFields = fieldnames(row.slots);
                cbias = row.slots.(slotFields{1}).cbias150;
            end
            if cbias >= ops.cbiasContra
                respId = 1;
            elseif cbias < ops.cbiasIpsi
                respId = -1;
            else
                respId = 0;
            end
            kept = kept + 1;
            unitPeak(kept) = peak;
            unitResp(kept) = respId;
            unitCbias(kept) = cbias;
            unitSlotContra{kept} = contraByFreq;
            unitSlotIpsi{kept} = ipsiByFreq;
        end
        if kept == 0
            continue
        end
        unitPeak = unitPeak(1:kept);
        unitResp = unitResp(1:kept);
        unitCbias = unitCbias(1:kept);
        unitSlotContra = unitSlotContra(1:kept);
        unitSlotIpsi = unitSlotIpsi(1:kept);

        for slotInd = 1:numel(ops.stimSlots)
            freq = ops.stimSlots{slotInd};
            haveFreq = cellfun(@(s) isfield(s, ['f' freq]), unitSlotContra);
            sel = find(haveFreq);
            if isempty(sel)
                continue
            end
            % sort selected units by respId desc, cbias desc
            [~, order] = sortrows([unitResp(sel)', unitCbias(sel)'], [-1 -2]);
            sel = sel(order);
            contraMat = zeros(numel(sel), numel(frTime));
            ipsiMat = zeros(numel(sel), numel(frTime));
            respIds = zeros(numel(sel), 1);
            for k = 1:numel(sel)
                u = sel(k);
                contraMat(k, :) = unitSlotContra{u}.(['f' freq]) / unitPeak(u);
                ipsiMat(k, :) = unitSlotIpsi{u}.(['f' freq]) / unitPeak(u);
                respIds(k) = unitResp(u);
            end
            if strcmp(geno, 'WT')
                panelLetter = 'A';       % FigS3A = WT
            else
                panelLetter = 'B';       % FigS3B = KO
            end
            renderFRHeatmap(contraMat, ipsiMat, respIds, frTime, geno, ops, outDir, ...
                ['FigS3' panelLetter ' - Stim ' freq 'hz FR heatmap ' geno]);
        end
    end
end

% ===================================================================== %
%  FigS4B: contra-bias vs cortical depth, by layer band
% ===================================================================== %
function cBiasDepthHistoLine(unitTable, outDir, ops)
    genotypes = unique({unitTable.genotype});
    layerNames = {'Sup', 'L4', 'Deep'};
    responseNames = {'ipsilateral', 'bilateral', 'contralateral'};
    genoColors = containers.Map({'WT', 'KO'}, {[0 0 0], [0.7 0.7 0.7]});

    % per (genotype, layer): rows over animals of [%ipsi %bilateral %contra]
    dist = cell(numel(genotypes), 3);

    for genoInd = 1:numel(genotypes)
        geno = genotypes{genoInd};
        animals = unique({unitTable(strcmp({unitTable.genotype}, geno)).animal});
        % preallocate each layer's per-animal distribution; trim unused tail below
        layerDist = zeros(numel(animals), 3, 3);   % animal x layer x category
        layerFilled = zeros(1, 3);
        for aniInd = 1:numel(animals)
            layerCounts = zeros(3, 3);   % rows = layer, cols = ipsi/bilateral/contra
            for rowInd = 1:numel(unitTable)
                row = unitTable(rowInd);
                if ~strcmp(row.genotype, geno) || ~strcmp(row.animal, animals{aniInd}) || ~row.responsive
                    continue
                end
                if ~isfield(row.slots, 'f20')
                    continue
                end
                cbias = row.slots.f20.cbias150;
                if isnan(cbias)
                    continue
                end
                depth = row.depthNorm - ops.depthAdjust;
                layer = layerBand(depth, ops);
                category = lateralityCategory(cbias, ops);
                layerCounts(layer, category) = layerCounts(layer, category) + 1;
            end
            for layer = 1:3
                total = sum(layerCounts(layer, :));
                if total == 0
                    continue
                end
                layerFilled(layer) = layerFilled(layer) + 1;
                layerDist(layerFilled(layer), layer, :) = 100 * layerCounts(layer, :) / total;
            end
        end
        for layer = 1:3
            dist{genoInd, layer} = squeeze(layerDist(1:layerFilled(layer), layer, :));
            if layerFilled(layer) == 1
                dist{genoInd, layer} = reshape(dist{genoInd, layer}, 1, 3);
            end
        end
    end

    % ---- statistics ----
    statLines = cell(1, 3 * (3 + numel(genotypes)));   % upper bound; trimmed below
    statCount = 0;
    for layer = 1:3
        for response = 1:3
            if numel(genotypes) == 2
                a = dist{1, layer};
                b = dist{2, layer};
                if ~isempty(a) && ~isempty(b)
                    p = ranksum(a(:, response), b(:, response));
                    statCount = statCount + 1;
                    statLines{statCount} = sprintf('%s Mann-Whitney across genotypes (%s): p = %.4f', ...
                        layerNames{layer}, responseNames{response}, p);
                end
            end
        end
        for genoInd = 1:numel(genotypes)
            data = dist{genoInd, layer};
            if size(data, 1) >= 2 && size(data, 2) == 3
                pFried = friedman(data, 1, 'off');
                statCount = statCount + 1;
                statLines{statCount} = sprintf('%s %s Friedman p = %.4f', ...
                    genotypes{genoInd}, layerNames{layer}, pFried);
            end
        end
    end
    statLines = statLines(1:statCount);
    fid = fopen(fullfile(outDir, 'FigS4B - Layer preference distribution stats.txt'), 'w');
    fprintf(fid, '%s\n', statLines{:});
    fclose(fid);

    % ---- figure: 3 stacked subplots (Sup / L4 / Deep) ----
    xPositions = [-1 0 1];
    figureHandle = figure('Units', 'inches', 'Position', [1 1 1.35 3], 'Visible', 'off');
    for layer = 1:3
        axisHandle = subplot(3, 1, layer, 'Parent', figureHandle);
        hold(axisHandle, 'on');
        for genoInd = 1:numel(genotypes)
            data = dist{genoInd, layer};
            if isempty(data)
                continue
            end
            meanVals = mean(data, 1);
            stdVals = std(data, 1, 1);
            if genoColors.isKey(genotypes{genoInd})
                color = genoColors(genotypes{genoInd});
            else
                color = [0.3 0.3 0.3];
            end
            errorbar(axisHandle, xPositions + (genoInd - 1) * 0.05, meanVals, stdVals, ...
                'Color', color, 'LineWidth', 1);
        end
        xlim(axisHandle, [-1.2 1.2]);
        ylim(axisHandle, [-20 120]);
        set(axisHandle, 'FontSize', 8, 'FontName', 'Arial', 'LineWidth', 1, 'TickDir', 'out', 'XTick', xPositions);
        if layer < 3
            set(axisHandle, 'XTickLabel', []);
        else
            set(axisHandle, 'XTickLabel', {'ipsi', 'bilat', 'contra'});
        end
        hold(axisHandle, 'off');
    end
    savefig(figureHandle, fullfile(outDir, 'FigS4B - Layer preference distribution.fig'));
    exportgraphics(figureHandle, fullfile(outDir, 'FigS4B - Layer preference distribution.pdf'), 'Resolution', 300);
    close(figureHandle);
end

function category = lateralityCategory(cbias, ops)
    if cbias < -ops.lateralityThird
        category = 1;        % ipsi
    elseif cbias > ops.lateralityThird
        category = 3;        % contra
    else
        category = 2;        % bilateral
    end
end

function layer = layerBand(depth, ops)
    if depth <= ops.LTwoThree
        layer = 1;           % superficial
    elseif depth <= ops.LFour
        layer = 2;           % L4
    else
        layer = 3;           % deep
    end
end

% ===================================================================== %
%  FigS4: bilateral fraction L4 vs other layers (paired within mouse)
% ===================================================================== %
function bilateralFractionL4vsOther(unitTable, outDir, ops)
    genotypes = unique({unitTable.genotype});
    genoColors = containers.Map({'WT', 'KO'}, {[0 0 0], [0.7 0.7 0.7]});

    % per genotype: rows over mice of [% bilateral in other, % bilateral in L4]
    perMouse = cell(numel(genotypes), 1);
    for genoInd = 1:numel(genotypes)
        geno = genotypes{genoInd};
        animals = unique({unitTable(strcmp({unitTable.genotype}, geno)).animal});
        mouseVals = zeros(numel(animals), 2);
        kept = 0;
        for aniInd = 1:numel(animals)
            otherBilat = 0;
            otherTotal = 0;
            l4Bilat = 0;
            l4Total = 0;
            for rowInd = 1:numel(unitTable)
                row = unitTable(rowInd);
                if ~strcmp(row.genotype, geno) || ~strcmp(row.animal, animals{aniInd}) || ~row.responsive
                    continue
                end
                if ~isfield(row.slots, 'f20')
                    continue
                end
                cbias = row.slots.f20.cbias150;
                if isnan(cbias)
                    continue
                end
                depth = row.depthNorm - ops.depthAdjust;
                isBilat = lateralityCategory(cbias, ops) == 2;
                if layerBand(depth, ops) == 2
                    l4Total = l4Total + 1;
                    l4Bilat = l4Bilat + isBilat;
                else
                    otherTotal = otherTotal + 1;
                    otherBilat = otherBilat + isBilat;
                end
            end
            if l4Total >= 1 && otherTotal >= 1
                kept = kept + 1;
                mouseVals(kept, :) = [100 * otherBilat / otherTotal, 100 * l4Bilat / l4Total];
            end
        end
        perMouse{genoInd} = mouseVals(1:kept, :);
    end

    % ---- stats ----
    statLines = cell(1, 4 + numel(genotypes) * 4);   % upper bound; trimmed below
    statLines(1:3) = {'Percent bilateral units (|cbias| < 0.33), 20hz, 150 ms window', ...
        'Layers: L4 vs (superficial + deep). Paired within mouse.', ''};
    statCount = 3;
    for genoInd = 1:numel(genotypes)
        data = perMouse{genoInd};
        statCount = statCount + 1;
        statLines{statCount} = sprintf('Genotype %s, n = %d mice', genotypes{genoInd}, size(data, 1));
        if size(data, 1) > 1
            statCount = statCount + 1;
            statLines{statCount} = sprintf('  mean +/- SEM: other = %.1f +/- %.1f, L4 = %.1f +/- %.1f', ...
                mean(data(:, 1)), std(data(:, 1)) / sqrt(size(data, 1)), ...
                mean(data(:, 2)), std(data(:, 2)) / sqrt(size(data, 1)));
            p2 = signrank(data(:, 2), data(:, 1));
            p1 = signrank(data(:, 2), data(:, 1), 'tail', 'left');
            statCount = statCount + 1;
            statLines{statCount} = sprintf('  Wilcoxon L4 vs other two-sided p = %.4f', p2);
            statCount = statCount + 1;
            statLines{statCount} = sprintf('  Wilcoxon L4 < other one-sided p = %.4f', p1);
        else
            statCount = statCount + 1;
            statLines{statCount} = '  Not enough mice for a paired test';
        end
    end
    if numel(genotypes) == 2 && ~isempty(perMouse{1}) && ~isempty(perMouse{2})
        diff1 = perMouse{1}(:, 2) - perMouse{1}(:, 1);
        diff2 = perMouse{2}(:, 2) - perMouse{2}(:, 1);
        pGeno = ranksum(diff1, diff2);
        statCount = statCount + 1;
        statLines{statCount} = sprintf('Mann-Whitney on (L4 - other) across genotypes: p = %.4f', pGeno);
    end
    statLines = statLines(1:statCount);
    fid = fopen(fullfile(outDir, 'FigS4B - Bilateral fraction L4 vs other stats.txt'), 'w');
    fprintf(fid, '%s\n', statLines{:});
    fclose(fid);

    % ---- plot ----
    figureHandle = figure('Units', 'inches', 'Position', [1 1 1.35 1.5], 'Visible', 'off');
    axisHandle = axes(figureHandle);
    hold(axisHandle, 'on');
    xBase = [1 2];
    for genoInd = 1:numel(genotypes)
        data = perMouse{genoInd};
        if isempty(data)
            continue
        end
        if genoColors.isKey(genotypes{genoInd})
            color = genoColors(genotypes{genoInd});
        else
            color = [0.3 0.3 0.3];
        end
        x = xBase + (genoInd - 1) * 0.05;
        meanBilat = mean(data, 1);
        if size(data, 1) > 1
            semBilat = std(data, [], 1) / sqrt(size(data, 1));
        else
            semBilat = [0 0];
        end
        errorbar(axisHandle, x, meanBilat, semBilat, 'o-', 'Color', color, 'LineWidth', 1, ...
            'MarkerSize', 3, 'MarkerFaceColor', color, 'CapSize', 3);
    end
    set(axisHandle, 'FontSize', 8, 'FontName', 'Arial', 'LineWidth', 1, 'TickDir', 'out', ...
        'XTick', xBase, 'XTickLabel', {'Sup/Deep', 'L4'}, 'XTickLabelRotation', 45);
    xlim(axisHandle, [0.5 2.5]);
    ylim(axisHandle, [0 100]);
    ylabel(axisHandle, '% bilateral units');
    hold(axisHandle, 'off');
    savefig(figureHandle, fullfile(outDir, 'FigS4B - Bilateral fraction L4 vs other.fig'));
    exportgraphics(figureHandle, fullfile(outDir, 'FigS4B - Bilateral fraction L4 vs other.pdf'), 'Resolution', 300);
    close(figureHandle);
end

% ===================================================================== %
%  shared heatmap renderer (matches fig3_panels_nwb / figS3S4_nwb.py)
% ===================================================================== %
function renderFRHeatmap(contraMat, ipsiMat, respIds, frTime, geno, ops, outDir, stem)
    nUnits = size(contraMat, 1);
    yTicks = 20:20:nUnits;
    numColors = 256;
    rampDown = 1 - linspace(0, 1, numColors)';
    contraColormap = [ones(numColors, 1), rampDown, rampDown];   % white -> red
    ipsiColormap = [rampDown, rampDown, ones(numColors, 1)];     % white -> blue
    respColormap = [0 0 1; 1 1 1; 1 0 0];

    figureHandle = figure('Units', 'inches', 'Position', [1 1 1.6 2], 'Visible', 'off');

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

    axisResp = subplot(1, 21, 21, 'Parent', figureHandle);
    imagesc(axisResp, respIds(:) + 1);
    colormap(axisResp, respColormap);
    set(axisResp, 'Units', 'inches', 'Position', [1.45 0.2 0.05 1.75], ...
        'FontSize', 8, 'FontName', 'Arial', 'XTick', [], 'YTick', [], 'TickDir', 'out', 'LineWidth', 1);

    savefig(figureHandle, fullfile(outDir, [stem '.fig']));
    exportgraphics(figureHandle, fullfile(outDir, [stem '.pdf']), 'Resolution', 1200);
    close(figureHandle);
end

% ===================================================================== %
%  saved-table loader + unit-table builder (mirror of fig3_panels_nwb.m)
% ===================================================================== %
function records = loadFlatTable(matPath)
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

function unitTable = buildUnitTable(records, ops)
    unitTable = struct([]);
    if isempty(records)
        return
    end
    sessions = {records.session};
    units = [records.unit];
    keys = strcat(sessions, '#', arrayfun(@(x) num2str(x), units, 'UniformOutput', false));
    uniqueKeys = unique(keys, 'stable');
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
