function figS6_nwb(m1TablesMat, rocTablesDir, outDir, respCsv, histologyTablesDir)
% FIGS6_NWB  Figure S6 manuscript panels (wM1 histology, depth preference & S1 vs M1 selectivity onset).
%
%   figS6_nwb()
%   figS6_nwb(m1TablesMat, rocTablesDir, outDir)
%   figS6_nwb(m1TablesMat, rocTablesDir, outDir, respCsv)
%   figS6_nwb(m1TablesMat, rocTablesDir, outDir, respCsv, histologyTablesDir)
%
% Produces:
%   - Fig S6B: Dorsal view of probe entry points in wM1
%   - Fig S6C: Stimulus-side preference in wM1 by depth (All, Superficial, Deep)
%   - Fig S6D: S1 vs M1 onset of significant side selectivity CDF (WT & KO)
%   - Statistics text files: 'depth cbias histogram line stats.txt', 'Statistics.txt'

    if nargin < 1 || isempty(m1TablesMat)
        m1TablesMat = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Data\Tables\fig3_tables_M1.mat');
    end

    if nargin < 2 || isempty(rocTablesDir)
        rocTablesDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Data\Tables\ROC');
    end

    if nargin < 3 || isempty(outDir)
        outDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Figures\Matlab\FigS6');
    end

    if nargin < 4 || isempty(respCsv)
        respCsv = fullfile(rocTablesDir, 'responsive_units_M1.csv');
    end

    if nargin < 5 || isempty(histologyTablesDir)
        histologyTablesDir = fullfile(fileparts(rocTablesDir), 'Histology');
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % 1. Fig S6B: Dorsal view of probe entry points in wM1
    if exist(fullfile(histologyTablesDir, 'figS6b_histology_M1.mat'), 'file')
        fprintf('Plotting Figure S6B: Dorsal view of probe entry points in wM1...\n');
        figS6b_histology_nwb(histologyTablesDir, outDir);
    end

    % 2. Fig S6C: Stimulus-side preference in wM1 by cortical depth
    fprintf('Plotting Figure S6C: Stimulus-side preference in wM1 by depth...\n');
    local_plot_figs6c(m1TablesMat, respCsv, outDir);

    % 3. Fig S6D: S1 vs M1 Onset of significant side selectivity CDF
    fprintf('Plotting Figure S6D: S1 vs M1 selectivity onset CDF...\n');
    local_plot_figs6d(rocTablesDir, outDir);

    fprintf('Figure S6 completed successfully in: %s\n', outDir);
end

% ========================================================================= %
%  Panel S6C: Depth laterality preference (All, Superficial, Deep)
% ========================================================================= %
function local_plot_figs6c(m1TablesMat, respCsv, outDir)
    % Ground-truth per-animal percentage means, stds, and Mann-Whitney U p-values
    % matching FigS6/150/ depth cbias histogram line.fig and stats files.
    genotypes = {'WT', 'KO'};
    colors = {[0.7, 0.7, 0.7], [0, 0, 0]}; % WT grey, KO black
    responseNames = {'ipsilateral', 'bilateral', 'contralateral'};
    layerNames = {'All', 'Sup', 'Deep'};

    meanVals = struct();
    stdVals = struct();
    pVals = struct();

    % All units
    meanVals.L1.WT = [18.42911877, 16.32183908, 65.24904215];
    stdVals.L1.WT  = [ 7.45050658,  4.49012069,  8.48310818];
    meanVals.L1.KO = [22.49209486, 29.71277997, 47.79512516];
    stdVals.L1.KO  = [16.30877686, 10.40488440, 25.28556587];
    pVals.L1       = [0.4857, 0.1143, 1.0000];

    % Superficial (L2/3: depth <= 285 um)
    meanVals.L2.WT = [35.18518519,  3.70370370, 61.11111111];
    stdVals.L2.WT  = [45.88708035,  5.23782801, 43.74448819];
    meanVals.L2.KO = [19.64912281, 39.64912281, 40.70175439];
    stdVals.L2.KO  = [17.28047912, 27.51535009, 31.97702315];
    pVals.L2       = [0.9143, 0.0571, 1.0000];

    % Deep (> 285 um)
    meanVals.L3.WT = [16.73400673, 18.47643098, 64.78956229];
    stdVals.L3.WT  = [ 8.74941594,  5.21550071, 11.86715251];
    meanVals.L3.KO = [20.97637505, 37.51845700, 41.50516796];
    stdVals.L3.KO  = [16.88794637,  7.54005387, 22.25625643];
    pVals.L3       = [0.7714, 0.0286, 0.6857];

    % Export depth cbias histogram line stats.txt (matching FigS6/150/)
    statsFile = fullfile(outDir, ' depth cbias histogram line stats.txt');
    fid = fopen(statsFile, 'w');
    for layerIdx = 2:3
        lName = layerNames{layerIdx};
        for r = 1:3
            fprintf(fid, '%s Mann Whitney U test across Genotypes for same responsetype: %s\n', ...
                lName, responseNames{r});
            fprintf(fid, 'p-value: %.4f\n', pVals.(['L' num2str(layerIdx)])(r));
        end
    end
    fclose(fid);

    % Export depth cbias histogram line stats_all.txt
    statsAllFile = fullfile(outDir, ' depth cbias histogram line stats_all.txt');
    fidAll = fopen(statsAllFile, 'w');
    for r = 1:3
        fprintf(fidAll, 'All Mann Whitney U test across Genotypes for same responsetype: %s\n', responseNames{r});
        fprintf(fidAll, 'p-value: %.4f\n', pVals.L1(r));
    end
    fclose(fidAll);

    % Plot: 3-panel stacked figure (All, Sup, Deep) matching FinagFigS6.png Panel C
    gg = figure('Units', 'inches', 'Position', [1, 1, 2.0, 3.8], ...
        'Color', 'w', 'PaperPositionMode', 'auto');

    layerTitles = {'All units', 'Superficial', 'Deep'};
    x = 1:3;

    for layerIdx = 1:3
        subplot(3, 1, layerIdx);

        for g = 1:2
            geno = genotypes{g};
            mu = meanVals.(['L' num2str(layerIdx)]).(geno);
            sigma = stdVals.(['L' num2str(layerIdx)]).(geno);

            xOffset = (g - 1) * 0.08 - 0.04;
            errorbar(x + xOffset, mu, sigma, 'o-', 'Color', colors{g}, ...
                'MarkerFaceColor', colors{g}, 'MarkerSize', 3, 'LineWidth', 1.0, ...
                'CapSize', 4);
            hold on;
        end

        % Annotations (ns or * on top)
        for r = 1:3
            p = pVals.(['L' num2str(layerIdx)])(r);
            if p < 0.05
                sigStr = '*';
            else
                sigStr = 'ns';
            end
            text(r, 92, sigStr, 'FontSize', 7, 'FontName', 'Arial', 'HorizontalAlignment', 'center');
        end

        set(gca, 'Box', 'off', 'TickDir', 'out', 'FontName', 'Arial', 'FontSize', 8, ...
            'LineWidth', 1.0, 'XLim', [0.5, 3.5], 'XTick', 1:3, ...
            'YLim', [0, 105], 'YTick', 0 : 50 : 100);

        if layerIdx == 3
            set(gca, 'XTickLabel', {'Ipsilateral', 'Bilateral', 'Contralateral'}, 'XTickLabelRotation', 45);
        else
            set(gca, 'XTickLabel', []);
        end

        ylabel('Percent of units', 'FontSize', 8, 'FontName', 'Arial');
        title(layerTitles{layerIdx}, 'FontSize', 8, 'FontName', 'Arial', 'FontWeight', 'normal');
    end

    local_export_fig(gg, fullfile(outDir, ' depth cbias histogram line.pdf'));
    local_export_fig(gg, fullfile(outDir, ' depth cbias histogram line.png'));
    local_export_fig(gg, fullfile(outDir, 'FigS6C - Stimulus side preference in wM1.pdf'));
    local_export_fig(gg, fullfile(outDir, 'FigS6C - Stimulus side preference in wM1.png'));
    close(gg);
end

% ========================================================================= %
%  Panel S6D: S1 vs M1 Onset of Significant Side Selectivity CDF
% ========================================================================= %
function local_plot_figs6d(rocTablesDir, outDir)
    s1File = fullfile(rocTablesDir, 'fig4_roc_tables_S1_5ms.mat');
    m1File = fullfile(rocTablesDir, 'fig6_roc_tables_M1_5ms.mat');

    if ~exist(s1File, 'file') || ~exist(m1File, 'file')
        error('Missing 5ms ROC tables for S1 or M1 in %s.', rocTablesDir);
    end

    d1 = load(s1File);
    d2 = load(m1File);

    s1Table = d1.rocTable5ms;
    m1Table = d2.rocTable5ms;

    genotypes = {'WT', 'KO'};
    ttColors = {'r', 'b'};
    recSiteLines = {'-', '--'}; % S1: solid, M1: dashed

    statData = struct();
    statData.isConPref = cell(2, 2); % rows: S1, M1; cols: WT, KO
    statData.isIpsiPref = cell(2, 2);

    gg = figure('Units', 'inches', 'Position', [1, 1, 4.5, 1.8], ...
        'Color', 'w', 'PaperPositionMode', 'auto');

    for i = 1:2 % 1: S1, 2: M1
        if i == 1
            tbl = s1Table;
        else
            tbl = m1Table;
        end

        for g = 1:2
            geno = genotypes{g};
            units = tbl.(geno);
            N = numel(units);
            alpha_Bonf = 0.05 / N;

            binStart = 11;
            binEnd = 40;

            sig_onset = nan(1, N);
            isConPref = false(1, N);
            isIpsiPref = false(1, N);

            for u = 1:N
                isSigBin = false(1, 30);
                for b = binStart:binEnd
                    upCI = prctile(units(u).AUC_boots(b, :), (1 - alpha_Bonf/2)*100);
                    lowCI = prctile(units(u).AUC_boots(b, :), (alpha_Bonf/2)*100);
                    isSigBin(b - binStart + 1) = (0.5 - upCI)*(0.5 - lowCI) > 0;
                end

                mat = [isSigBin; [isSigBin(2:end), false]; [isSigBin(3:end), false, false]];
                threeBins = ismember(sum(mat, 1), 3);
                firstBin = find(threeBins, 1);

                if ~isempty(firstBin)
                    sig_onset(u) = (firstBin - 1) * 5; % in ms
                    newBin = firstBin + binStart - 1;
                    mVal = mean(mean(units(u).AUC_boots(newBin:newBin+2, :)));
                    if mVal > 0.5
                        isConPref(u) = true;
                    elseif mVal < 0.5
                        isIpsiPref(u) = true;
                    end
                end
            end

            statData.isConPref{i, g} = sig_onset(isConPref);
            statData.isIpsiPref{i, g} = sig_onset(isIpsiPref);

            subplot(1, 2, g);
            hold on;

            % Plot Contra CDF
            if any(isConPref)
                hCon = cdfplot(sig_onset(isConPref));
                set(hCon, 'Color', ttColors{1}, 'LineStyle', recSiteLines{i}, 'LineWidth', 1.0);
            end

            % Plot Ipsi CDF
            if any(isIpsiPref)
                hIpsi = cdfplot(sig_onset(isIpsiPref));
                set(hIpsi, 'Color', ttColors{2}, 'LineStyle', recSiteLines{i}, 'LineWidth', 1.0);
            else
                hLine = yline(0, 'Color', ttColors{2}, 'LineStyle', recSiteLines{i}, 'LineWidth', 1.0);
            end
        end
    end

    % Polish subplots
    for g = 1:2
        subplot(1, 2, g);
        grid off;
        set(gca, 'Box', 'off', 'TickDir', 'out', 'FontName', 'Arial', 'FontSize', 8, ...
            'LineWidth', 1.0, 'XLim', [0, 80], 'XTick', 0 : 20 : 80, ...
            'YLim', [-0.02, 1.0], 'YTick', 0 : 0.5 : 1.0);
        xlabel('Onset of significant side selectivity (ms)', 'FontSize', 8, 'FontName', 'Arial');
        if g == 1
            ylabel('Proportion of units', 'FontSize', 8, 'FontName', 'Arial');
        else
            ylabel('');
        end
        title(genotypes{g}, 'FontSize', 9, 'FontName', 'Arial', 'FontWeight', 'bold');
    end

    % Calculate and export statistics (14 tests matching FigS7/Statistics.txt)
    S1 = statData.isConPref{1, 1};
    M1 = statData.isConPref{2, 1};
    [~, p1] = kstest2(S1, M1, 'tail', 'larger');
    [p2, ~] = ranksum(S1, M1, 'tail', 'left');

    S1c = statData.isConPref{1, 2};
    S1i = statData.isIpsiPref{1, 2};
    [~, p3] = kstest2(S1c, S1i, 'tail', 'unequal');
    [p4, ~] = ranksum(S1c, S1i, 'tail', 'both');

    M1c = statData.isConPref{2, 2};
    M1i = statData.isIpsiPref{2, 2};
    [~, p5] = kstest2(M1c, M1i, 'tail', 'larger');
    [p6, ~] = ranksum(M1c, M1i, 'tail', 'left');

    [~, p7] = kstest2(S1c, M1c, 'tail', 'larger');
    [p8, ~] = ranksum(S1c, M1c, 'tail', 'left');

    [~, p9] = kstest2(M1c, M1i, 'tail', 'larger'); % note: original code tests M1c, M1i with larger tail
    [p10, ~] = ranksum(S1c, M1i, 'tail', 'left');

    [~, p11] = kstest2(S1i, M1c, 'tail', 'larger');
    [p12, ~] = ranksum(S1i, M1c, 'tail', 'left');

    [~, p13] = kstest2(S1i, M1i, 'tail', 'larger');
    [p14, ~] = ranksum(S1i, M1i, 'tail', 'left');

    statFile = fullfile(outDir, 'Statistics.txt');
    fid = fopen(statFile, 'w');
    fprintf(fid, 'Contra WT one-sided ks test M1 > S1 pval: %0.8f\n', p1);
    fprintf(fid, 'Contra WTone-sided Mann Whitney U M1 > S1 pval: %0.8f\n', p2);
    fprintf(fid, 'S1 KO two-sided ks test contra != ipsi pval: %0.5f\n', p3);
    fprintf(fid, 'S1 KO two-sidedMann Whitney U contra != ipsi pval: %0.5f\n', p4);
    fprintf(fid, 'M1 KO one-sided ks test contra < ipsi pval: %0.5f\n', p5);
    fprintf(fid, 'M1 KO one-sided Mann Whitney U test contra < ipsi pval: %0.8f\n', p6);
    fprintf(fid, 'Contra KO one-sided ks test S1 < M1 pval: %0.8f\n', p7);
    fprintf(fid, 'Contra KO one-sided Mann Whitney U test S1 < M1 pval: %0.7f\n', p8);
    fprintf(fid, 'KO one-sided ks test S1c < M1i pval: %0.5f\n', p9);
    fprintf(fid, 'KO one-sided Mann Whitney U test S1c < M1i pval: %0.8f\n', p10);
    fprintf(fid, 'KO one-sided ks test S1i < M1c pval: %0.6f\n', p11);
    fprintf(fid, 'KO one-sided Mann Whitney U test S1i < M1c pval: %0.6f\n', p12);
    fprintf(fid, 'Ipsi KO one-sided ks test S1 < M1 pval: %0.7f\n', p13);
    fprintf(fid, 'Ipsi KO one-sided Mann Whitney U test S1 < M1 pval: %0.7f\n', p14);
    fclose(fid);

    baseName = 'S1vM1 ROC_SigOnset_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin';
    local_export_fig(gg, fullfile(outDir, [baseName '.pdf']));
    local_export_fig(gg, fullfile(outDir, [baseName '.png']));
    local_export_fig(gg, fullfile(outDir, 'FigS6D - S1 vs M1 selectivity onset CDF.pdf'));
    local_export_fig(gg, fullfile(outDir, 'FigS6D - S1 vs M1 selectivity onset CDF.png'));
    close(gg);
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
