function fig6_panels_nwb(m1Source, outDir, respCsv)
% FIG6_PANELS_NWB  Figure 6 manuscript panels 6A & 6B (passive-stim wM1 ephys).
%
%   fig6_panels_nwb()
%   fig6_panels_nwb(m1Source, outDir)
%   fig6_panels_nwb(m1Source, outDir, respCsv)
%
% Produces:
%   - Fig 6A: Normalized spiking rate heatmaps for responsive units (WT n=128, KO n=148)
%   - Fig 6B: Population mean spiking rate across 10 Hz, 20 Hz, and 40 Hz for WT and KO
%   - Peak values pop mean FR.txt: Peak firing rates and stats

    if nargin < 1 || isempty(m1Source)
        m1Source = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Data\Tables\fig3_tables_M1.mat');
    end

    if nargin < 2 || isempty(outDir)
        outDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Figures\Matlab\Fig6');
    end

    if nargin < 3 || isempty(respCsv)
        respCsv = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Data\Tables\ROC\responsive_units_M1.csv');
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    ops = local_panel_ops();

    % Load accumulated M1 records
    fprintf('Loading M1 records from %s\n', m1Source);
    records = local_load_flat_table(m1Source);

    % Build unit table and annotate with canonical responsive units list
    unitTable = local_build_unit_table(records, respCsv, ops);
    nRespWT = sum(arrayfun(@(u) strcmp(u.genotype, 'WT') && u.responsive, unitTable));
    nRespKO = sum(arrayfun(@(u) strcmp(u.genotype, 'KO') && u.responsive, unitTable));
    fprintf('Built %d unit rows (WT responsive=%d, KO responsive=%d)\n', ...
        numel(unitTable), nRespWT, nRespKO);

    % 1. Fig 6A: Normalized FR heatmaps
    fprintf('Plotting Figure 6A: Normalized FR heatmaps...\n');
    local_plot_fig6a(unitTable, outDir, ops);

    % 2. Fig 6B: Population mean spiking rate traces & export Peak values pop mean FR.txt
    fprintf('Plotting Figure 6B: Population mean spiking rate traces...\n');
    local_plot_fig6b(unitTable, outDir, ops);

    fprintf('Figure 6A and 6B completed successfully in: %s\n', outDir);
end

% ========================================================================= %
%  Ops configuration
% ========================================================================= %
function ops = local_panel_ops()
    ops.stimSlots = {'10', '20', '40'};
    ops.stimNames = {'10 Hz', '20 Hz', '40 Hz'};
    ops.sigFreq = '20';
    ops.cbiasFirstCycleWindow = {'100', '50', '25'};
    ops.plotxLims = [-0.05, 0.10];
    ops.maxFR = 16.0;
    ops.cbiasContra = 0.33;
    ops.cbiasIpsi = -0.33;
end

% ========================================================================= %
%  Load flat table
% ========================================================================= %
function records = local_load_flat_table(matPath)
    windowNames = {'25', '40', '50', '75', '100', '150', '200', '300'};
    loaded = load(matPath, 'fig3Table');
    tbl = loaded.fig3Table;
    nRows = numel(tbl.session);
    frTime = reshape(tbl.frTime, 1, []);

    recordCells = cell(1, nRows);
    for rowInd = 1:nRows
        perWindow = struct();
        for windowInd = 1:numel(windowNames)
            windowName = windowNames{windowInd};
            perWindow.(['w' windowName]) = struct( ...
                'pvalBoth', tbl.(['pvalBoth_' windowName])(rowInd), ...
                'pvalContra', tbl.(['pvalContra_' windowName])(rowInd), ...
                'pvalIpsi', tbl.(['pvalIpsi_' windowName])(rowInd), ...
                'cbias', tbl.(['cbias_' windowName])(rowInd));
        end
        record = struct();
        record.animal = tbl.animal{rowInd};
        record.genotype = tbl.genotype{rowInd};
        record.recSite = tbl.recSite{rowInd};
        record.region = tbl.region{rowInd};
        record.session = tbl.session{rowInd};
        record.freq = tbl.freq{rowInd};
        record.unit = tbl.unit(rowInd);
        record.depthRaw = tbl.depthRaw(rowInd);
        record.depthNorm = tbl.depthNorm(rowInd);
        record.ksLabel = tbl.ksLabel{rowInd};
        record.frTime = frTime;
        record.frContra = struct('mean', tbl.contraMean(rowInd, :));
        record.frIpsi = struct('mean', tbl.ipsiMean(rowInd, :));
        record.perWindow = perWindow;
        recordCells{rowInd} = record;
    end
    records = [recordCells{:}];
end

% ========================================================================= %
%  Build unit table from flat records
% ========================================================================= %
function unitTable = local_build_unit_table(records, respCsv, ops)
    unitTable = struct([]);
    if isempty(records)
        return;
    end

    % Parse responsive units CSV if available
    respLookup = containers.Map('KeyType', 'char', 'ValueType', 'logical');
    if exist(respCsv, 'file')
        respData = readtable(respCsv);
        for i = 1:height(respData)
            m = respData.mouseName{i};
            s = respData.sessionName{i};
            uIdx = respData.unitIndex(i); % 1-based matching tbl.unit
            dateStr = ['20' s(1:2) '-' s(3:4) '-' s(5:end)];
            fullSess = [m '_' dateStr];
            key = [fullSess '#' num2str(uIdx)];
            respLookup(key) = true;
        end
    end

    sessions = {records.session};
    units = [records.unit];
    keys = strcat(sessions, '#', arrayfun(@(x) num2str(x), units, 'UniformOutput', false));
    uniqueKeys = unique(keys, 'stable');

    totalUnits = numel(uniqueKeys);
    unitTable = struct(...
        'session', cell(1, totalUnits), ...
        'unit', cell(1, totalUnits), ...
        'animal', cell(1, totalUnits), ...
        'genotype', cell(1, totalUnits), ...
        'recSite', cell(1, totalUnits), ...
        'depthRaw', cell(1, totalUnits), ...
        'depthNorm', cell(1, totalUnits), ...
        'responsive', cell(1, totalUnits), ...
        'slots', cell(1, totalUnits), ...
        'frTime', cell(1, totalUnits));

    for k = 1:totalUnits
        key = uniqueKeys{k};
        matchIndices = find(strcmp(keys, key));
        firstRec = records(matchIndices(1));

        isResp = false;
        if isKey(respLookup, key)
            isResp = true;
        end

        slotsStruct = struct();
        for m = 1:numel(matchIndices)
            rec = records(matchIndices(m));
            fStr = num2str(rec.freq);
            slotEntry = struct();
            slotEntry.meanContra = rec.frContra.mean;
            slotEntry.meanIpsi = rec.frIpsi.mean;

            if isfield(rec.perWindow, 'w150')
                slotEntry.cbias150 = rec.perWindow.w150.cbias;
            else
                slotEntry.cbias150 = 0;
            end

            slotsStruct.(['f' fStr]) = slotEntry;
        end

        unitTable(k).session = firstRec.session;
        unitTable(k).unit = firstRec.unit;
        unitTable(k).animal = firstRec.animal;
        unitTable(k).genotype = firstRec.genotype;
        unitTable(k).recSite = firstRec.recSite;
        unitTable(k).depthRaw = firstRec.depthRaw;
        unitTable(k).depthNorm = firstRec.depthNorm;
        unitTable(k).responsive = isResp;
        unitTable(k).slots = slotsStruct;
        unitTable(k).frTime = firstRec.frTime;
    end
end

% ========================================================================= %
%  Panel 6A: Normalized FR Heatmaps
% ========================================================================= %
function local_plot_fig6a(unitTable, outDir, ops)
    genotypes = {'WT', 'KO'};
    frTime = unitTable(1).frTime;

    numColors = 256;
    rampDown = 1 - linspace(0, 1, numColors)';
    contraColormap = [ones(numColors, 1), rampDown, rampDown];
    ipsiColormap = [rampDown, rampDown, ones(numColors, 1)];
    respColormap = [0, 0, 1; 1, 1, 1; 1, 0, 0];

    for g = 1:numel(genotypes)
        geno = genotypes{g};
        matchingUnits = unitTable(arrayfun(@(u) strcmp(u.genotype, geno) && u.responsive, unitTable));
        nUnits = numel(matchingUnits);

        if nUnits == 0
            continue;
        end

        contraRows = cell(1, nUnits);
        ipsiRows = cell(1, nUnits);
        cbiasList = zeros(1, nUnits);
        respList = zeros(1, nUnits);

        for u = 1:nUnits
            row = matchingUnits(u);
            [meanCon, meanIp, cb] = local_average_slots(row, ops);
            contraRows{u} = meanCon;
            ipsiRows{u} = meanIp;
            cbiasList(u) = cb;

            if cb >= ops.cbiasContra
                respList(u) = 1;
            elseif cb < ops.cbiasIpsi
                respList(u) = -1;
            else
                respList(u) = 0;
            end
        end

        % Sort: contra-preferring first, then neutral, then ipsi-preferring; descending cbias
        [~, sortOrder] = sortrows([respList(:), cbiasList(:)], [-1, -2]);

        contraMat = cell2mat(contraRows(sortOrder)');
        ipsiMat = cell2mat(ipsiRows(sortOrder)');
        sortedResp = respList(sortOrder);

        % Normalize per-unit by peak firing rate
        for u = 1:nUnits
            pk = max([contraMat(u, :), ipsiMat(u, :)]);
            if pk > 0
                contraMat(u, :) = contraMat(u, :) / pk;
                ipsiMat(u, :) = ipsiMat(u, :) / pk;
            end
        end

        gg = figure('Units', 'inches', 'Position', [1, 1, 1.8, 2.3], ...
            'Color', 'w', 'PaperPositionMode', 'auto');

        % Subplot: Contra (red)
        axContra = axes('Units', 'normalized', 'Position', [0.15, 0.15, 0.35, 0.72]);
        imagesc(axContra, frTime * 1000, 1:nUnits, contraMat, [0, 1]);
        colormap(axContra, contraColormap);
        hold on;
        xline(0, '--k', 'LineWidth', 0.8);
        set(axContra, 'Box', 'off', 'TickDir', 'out', 'FontName', 'Arial', 'FontSize', 8, ...
            'XLim', ops.plotxLims * 1000, 'XTick', [0, 100], 'YLim', [0.5, nUnits + 0.5]);
        xlabel('Time (ms)', 'FontSize', 8, 'FontName', 'Arial');
        ylabel('Responsive unit #', 'FontSize', 8, 'FontName', 'Arial');
        title('Contra', 'Color', 'r', 'FontSize', 8, 'FontName', 'Arial');

        % Subplot: Ipsi (blue)
        axIpsi = axes('Units', 'normalized', 'Position', [0.55, 0.15, 0.35, 0.72]);
        imagesc(axIpsi, frTime * 1000, 1:nUnits, ipsiMat, [0, 1]);
        colormap(axIpsi, ipsiColormap);
        hold on;
        xline(0, '--k', 'LineWidth', 0.8);
        set(axIpsi, 'Box', 'off', 'TickDir', 'out', 'FontName', 'Arial', 'FontSize', 8, ...
            'XLim', ops.plotxLims * 1000, 'XTick', [0, 100], 'YLim', [0.5, nUnits + 0.5], ...
            'YTickLabel', []);
        xlabel('Time (ms)', 'FontSize', 8, 'FontName', 'Arial');
        title('Ipsi', 'Color', 'b', 'FontSize', 8, 'FontName', 'Arial');

        % Subplot: Preference Bar
        axBar = axes('Units', 'normalized', 'Position', [0.93, 0.15, 0.04, 0.72]);
        imagesc(axBar, sortedResp(:) + 1);
        colormap(axBar, respColormap);
        set(axBar, 'Box', 'on', 'XTick', [], 'YTick', []);

        local_export_fig(gg, fullfile(outDir, ['All freq Average FR heatmap labels ' geno '.svg']));
        local_export_fig(gg, fullfile(outDir, ['Fig6A - Normalized FR heatmap (' geno ').png']));
        local_export_fig(gg, fullfile(outDir, ['Fig6A - Normalized FR heatmap (' geno ').pdf']));
        close(gg);
    end
end

% ========================================================================= %
%  Panel 6B: Population Mean Spiking Rate & Stats Export
% ========================================================================= %
function local_plot_fig6b(unitTable, outDir, ops)
    genotypes = {'WT', 'KO'};
    stimSlots = ops.stimSlots;
    frTime = unitTable(1).frTime * 1000; % in ms

    gg = figure('Units', 'inches', 'Position', [1, 1, 4.4, 3.2], ...
        'Color', 'w', 'PaperPositionMode', 'auto');

    peakStatsFile = fullfile(outDir, 'Peak values pop mean FR.txt');
    fid = fopen(peakStatsFile, 'w');

    for g = 1:numel(genotypes)
        geno = genotypes{g};
        matchingUnits = unitTable(arrayfun(@(u) strcmp(u.genotype, geno) && u.responsive, unitTable));
        nUnits = numel(matchingUnits);

        for s = 1:numel(stimSlots)
            slotKey = ['f' stimSlots{s}];
            spIdx = (g - 1) * 3 + s;
            subplot(2, 3, spIdx);

            contraTraces = [];
            ipsiTraces = [];

            for u = 1:nUnits
                if isfield(matchingUnits(u).slots, slotKey)
                    entry = matchingUnits(u).slots.(slotKey);
                    contraTraces = [contraTraces; entry.meanContra]; %#ok<AGROW>
                    ipsiTraces = [ipsiTraces; entry.meanIpsi]; %#ok<AGROW>
                end
            end

            if ~isempty(contraTraces)
                meanCon = mean(contraTraces, 1);
                local_plot_ci_band(frTime, contraTraces, [1, 0, 0], [1, 0, 0], 0.3);
                hold on;
            else
                meanCon = zeros(size(frTime));
            end

            if ~isempty(ipsiTraces)
                meanIp = mean(ipsiTraces, 1);
                local_plot_ci_band(frTime, ipsiTraces, [0, 0, 1], [0, 0, 1], 0.3);
                hold on;
            else
                meanIp = zeros(size(frTime));
            end

            % Export peak values
            fprintf(fid, '%s: %s Peak for Contra: %0.4fand Peak for Ipsi: %0.4f\n', ...
                geno, ops.stimNames{s}, max(meanCon), max(meanIp));

            % Gray dashed line at t=0
            line([0, 0], [0, ops.maxFR], 'LineStyle', '--', 'Color', [0.5, 0.5, 0.5], 'LineWidth', 1.0);

            set(gca, 'Box', 'off', 'TickDir', 'out', 'FontName', 'Arial', 'FontSize', 8, ...
                'XLim', [-50, 100], 'XTick', [-50, 0, 50, 100], 'YLim', [0, ops.maxFR], ...
                'YTick', 0 : 5 : 15, 'LineWidth', 1.0);

            if g == 1
                title(ops.stimNames{s}, 'FontSize', 8, 'FontName', 'Arial', 'FontWeight', 'normal');
            end
            if s == 1
                ylabel('Mean spiking rate (Hz)', 'FontSize', 8, 'FontName', 'Arial');
            else
                ylabel('');
            end
            if g == 2
                xlabel('Time from stimulus onset (ms)', 'FontSize', 8, 'FontName', 'Arial');
            else
                xlabel('');
            end
        end
    end

    fclose(fid);

    local_export_fig(gg, fullfile(outDir, 'Average FR figures window 150 ms.pdf'));
    local_export_fig(gg, fullfile(outDir, 'Fig6B - Population mean spiking rate (10_20_40Hz).png'));
    local_export_fig(gg, fullfile(outDir, 'Fig6B - Population mean spiking rate (10_20_40Hz).pdf'));
    close(gg);
end

% ========================================================================= %
%  Helper: average slots
% ========================================================================= %
function [meanContra, meanIpsi, cbias] = local_average_slots(row, ops)
    slots = row.slots;
    fields = fieldnames(slots);
    conSum = [];
    ipSum = [];
    cbList = [];

    for f = 1:numel(fields)
        entry = slots.(fields{f});
        if isempty(conSum)
            conSum = entry.meanContra;
            ipSum = entry.meanIpsi;
        else
            conSum = conSum + entry.meanContra;
            ipSum = ipSum + entry.meanIpsi;
        end
        cbList(end + 1) = entry.cbias150; %#ok<AGROW>
    end

    meanContra = conSum / numel(fields);
    meanIpsi = ipSum / numel(fields);
    cbias = mean(cbList);
end

% ========================================================================= %
%  Helper: plot mean curve with across-unit SEM / CI shading
% ========================================================================= %
function local_plot_ci_band(time, traceMat, lineColor, shadeColor, alphaVal)
    mu = mean(traceMat, 1);
    sem = std(traceMat, 0, 1) / sqrt(size(traceMat, 1));
    ciLow = mu - 1.96 * sem;
    ciHigh = mu + 1.96 * sem;

    fill([time, fliplr(time)], [ciHigh, fliplr(ciLow)], shadeColor, ...
        'EdgeColor', 'none', 'FaceAlpha', alphaVal);
    hold on;
    plot(time, mu, 'Color', lineColor, 'LineWidth', 1.0);
end

% ========================================================================= %
%  Helper: safe export
% ========================================================================= %
function local_export_fig(figHandle, targetPath)
    try
        exportgraphics(figHandle, targetPath, 'Resolution', 300);
    catch ME
        if contains(ME.message, 'Permission denied', 'IgnoreCase', true)
            [p, n, e] = fileparts(targetPath);
            altPath = fullfile(p, [n '_new' e]);
            exportgraphics(figHandle, altPath, 'Resolution', 300);
        else
            rethrow(ME);
        end
    end
end
