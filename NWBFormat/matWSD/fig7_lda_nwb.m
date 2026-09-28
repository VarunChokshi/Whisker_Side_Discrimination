function fig7_lda_nwb(ldaTablesDir, outDir)
% FIG7_LDA_NWB  Generate Figure 7 (wM1 LDA decoding) panels and statistical exports.
%
%   fig7_lda_nwb()
%   fig7_lda_nwb(ldaTablesDir, outDir)
%
% Inputs:
%   ldaTablesDir  Folder containing fig7_lda_tables_M1.mat
%                 (default: ...\NWBData\Data\Tables\LDA)
%   outDir        Output folder for figures (default: ...\NWBData\Figures\Matlab\Fig7)
%
% Generates:
%   - Panel 7A: Session-wise classification accuracy histograms (WT and KO)
%   - Panel 7B: Multilevel bootstrapped population stimulus discriminability (95% CI)
%   - Fig7 Composite: Full figure matching manuscript FinalFig7.png
%   - Standalone figures: LDA_histogram_Motor_WT/KO_..., LDA_bootstrapping_Motor_KO_...
%   - Statistical text files: LDA median values.txt, LDA bootstrapping CI values.txt

    if nargin < 1 || isempty(ldaTablesDir)
        ldaTablesDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData', 'Data', 'Tables', 'LDA');
    end

    if nargin < 2 || isempty(outDir)
        outDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData', 'Figures', 'Matlab', 'Fig7');
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    matFile = fullfile(ldaTablesDir, 'fig7_lda_tables_M1.mat');
    if ~exist(matFile, 'file')
        error('M1 LDA tables not found at: %s. Run fig7_lda_tables_nwb() first.', matFile);
    end

    fprintf('Loading M1 LDA tables from: %s\n', matFile);
    loaded = load(matFile);
    ldaData = loaded.ldaTablesM1;

    fprintf('Plotting Figure 7A (Session-wise accuracy histograms)...\n');
    local_plot_fig7a(ldaData, outDir);

    fprintf('Plotting Figure 7B (Bootstrapped accuracy with 95%% CI)...\n');
    local_plot_fig7b(ldaData, outDir);

    fprintf('Plotting Figure 7 Composite (Manuscript layout)...\n');
    local_plot_fig7_composite(ldaData, outDir);

    fprintf('Figure 7 plots and statistical summaries completed in: %s\n', outDir);
end

% ========================================================================= %
%  Panel 7A: Session-wise Accuracy Histograms (WT & KO)
% ========================================================================= %
function local_plot_fig7a(ldaData, outDir)
    genotypes = {'WT', 'KO'};
    shuffleNames = {'true', 'shuffled'};
    shuffleColors = {[0.5, 0, 0.5], [0.5, 0.5, 0.5]};
    binEdges = 0 : 0.025 : 1;

    medianTxtPath = fullfile(outDir, 'LDA median values.txt');
    fidMedian = fopen(medianTxtPath, 'w');

    for g = 1:numel(genotypes)
        geno = genotypes{g};

        figHandle = figure('Units', 'inches', 'Position', [1, 1, 3.2, 1.65], ...
            'Color', 'w', 'PaperPositionMode', 'auto', 'Visible', 'off');

        lastN = 0;
        for b = 1:2
            subplot(1, 2, b);
            ax = gca;
            hold(ax, 'on');

            xline(ax, 0.5, '--', 'LineWidth', 1, 'Color', 'k');

            sessData = ldaData.bins(b).(geno);
            caTrue = sessData.LDA_true;
            caShuff = sessData.LDA_shuffle;
            lastN = numel(caTrue);

            for shuffleIdx = 1:2
                if shuffleIdx == 1
                    ca = caTrue;
                    lWidth = 1.0;
                else
                    ca = caShuff;
                    lWidth = 0.5;
                end

                colorVal = shuffleColors{shuffleIdx};
                hHist = histogram(ax, ca, binEdges, ...
                    'FaceColor', colorVal, 'FaceAlpha', 0.6, ...
                    'EdgeColor', colorVal, 'LineWidth', lWidth);

                % Compute median and find closest bin center
                caMedian = median(ca, 'omitnan');
                binCenters = (hHist.BinEdges(1:end-1) + hHist.BinEdges(2:end)) / 2;
                [~, centerIdx] = min(abs(caMedian - binCenters));

                startTime = ldaData.bins(b).startTime;
                endTime = ldaData.bins(b).endTime;
                if fidMedian ~= -1
                    fprintf(fidMedian, 'For Motor %s %d ~ %d ms: %s median is %g\n', ...
                        geno, startTime, endTime, shuffleNames{shuffleIdx}, caMedian);
                end

                % Triangle marker for median
                plot(ax, binCenters(centerIdx), 7, 'v', ...
                    'LineWidth', 1, 'MarkerSize', 3.5, ...
                    'Color', colorVal, 'MarkerFaceColor', 'none');

                % Legend in first subplot
                if b == 1
                    text(ax, 0.65, (7.5 - 1.0 * shuffleIdx), shuffleNames{shuffleIdx}, ...
                        'Color', colorVal, 'FontSize', 8, 'FontName', 'Arial');
                end
            end

            set(ax, 'Box', 'off', 'TickDir', 'out', 'FontSize', 8, 'FontName', 'Arial', ...
                'LineWidth', 0.75, 'XLim', [0, 1], 'XTick', 0 : 0.25 : 1, ...
                'YLim', [0, 8], 'YTick', 0 : 2 : 8);

            if b == 1
                ylabel(ax, 'Number of sessions', 'FontSize', 8, 'FontName', 'Arial');
            end
            title(ax, ldaData.bins(b).timeLabel, 'FontSize', 8, 'FontName', 'Arial', 'FontWeight', 'normal');
        end

        sgtitle(sprintf('Motor %s n= %d sessions', geno, lastN), ...
            'FontSize', 8, 'FontName', 'Arial', 'FontWeight', 'normal');

        baseName = sprintf('LDA_histogram_Motor_%s_20Hz_100msBin_-100to100ms_3respMin', geno);
        local_export_fig(figHandle, fullfile(outDir, [baseName '.pdf']));
        local_export_fig(figHandle, fullfile(outDir, [baseName '.png']));
        local_export_fig(figHandle, fullfile(outDir, sprintf('Fig7A - Session-wise stimulus discriminability (%s).pdf', geno)));
        local_export_fig(figHandle, fullfile(outDir, sprintf('Fig7A - Session-wise stimulus discriminability (%s).png', geno)));
        close(figHandle);
    end

    if fidMedian ~= -1
        fclose(fidMedian);
    end
end

% ========================================================================= %
%  Panel 7B: Bootstrapped Population Accuracy (95% CI)
% ========================================================================= %
function local_plot_fig7b(ldaData, outDir)
    genotypes = {'WT', 'KO'};
    shuffleNames = {'true', 'shuffled'};
    shuffleColors = {[0.5, 0, 0.5], [0.5, 0.5, 0.5]};
    nBoot = 100;

    ciTxtPath = fullfile(outDir, 'LDA bootstrapping CI values.txt');
    fidCI = fopen(ciTxtPath, 'w');

    figHandle = figure('Units', 'inches', 'Position', [1, 1, 3.2, 1.9], ...
        'Color', 'w', 'PaperPositionMode', 'auto', 'Visible', 'off');

    for b = 1:2
        subplot(1, 2, b);
        ax = gca;
        hold(ax, 'on');

        yline(ax, 0.5, '--', 'LineWidth', 1, 'Color', 'k');

        for g = 1:numel(genotypes)
            geno = genotypes{g};

            for shuffleIdx = 1:2
                if shuffleIdx == 1
                    rawBoot = ldaData.bins(b).(geno).boot_true;
                else
                    rawBoot = ldaData.bins(b).(geno).boot_shuffle;
                end

                sortedAcc = sort(rawBoot);
                accMean = mean(sortedAcc);
                up95CI = sortedAcc(round(0.975 * nBoot));
                low95CI = sortedAcc(round(0.025 * nBoot));

                xPos = g + shuffleIdx * 0.2 - 0.3;
                colorVal = shuffleColors{shuffleIdx};

                errorbar(ax, xPos, accMean, (accMean - low95CI), (up95CI - accMean), 'o', ...
                    'Color', colorVal, 'MarkerEdgeColor', colorVal, ...
                    'MarkerFaceColor', colorVal, 'MarkerSize', 5, ...
                    'CapSize', 4, 'LineWidth', 0.75);

                startTime = ldaData.bins(b).startTime;
                endTime = ldaData.bins(b).endTime;
                if fidCI ~= -1
                    fprintf(fidCI, 'For Motor %s %d ~ %d ms: %s CI is %g to %g\n', ...
                        geno, startTime, endTime, shuffleNames{shuffleIdx}, low95CI, up95CI);
                end

                if b == 1 && g == 1
                    text(ax, 1.5, (0.80 - 0.05 * shuffleIdx), shuffleNames{shuffleIdx}, ...
                        'Color', colorVal, 'FontSize', 8, 'FontName', 'Arial');
                end
            end
        end

        set(ax, 'Box', 'off', 'TickDir', 'out', 'FontSize', 8, 'FontName', 'Arial', ...
            'LineWidth', 0.75, 'XLim', [0.5, 2.5], 'XTick', 1:2, 'XTickLabel', genotypes, ...
            'YLim', [0.3, 1.0], 'YTick', 0.4 : 0.2 : 1.0);

        ylabel(ax, 'Classification accuracy', 'FontSize', 8, 'FontName', 'Arial');
        title(ax, ldaData.bins(b).timeLabel, 'FontSize', 8, 'FontName', 'Arial', 'FontWeight', 'normal');
    end

    if fidCI ~= -1
        fclose(fidCI);
    end

    baseName = 'LDA_bootstrapping_Motor_KO_20Hz_100msBin_-100to100ms_3respMin';
    local_export_fig(figHandle, fullfile(outDir, [baseName '.pdf']));
    local_export_fig(figHandle, fullfile(outDir, [baseName '.png']));
    local_export_fig(figHandle, fullfile(outDir, 'Fig7B - Bootstrapped population stimulus discriminability.pdf'));
    local_export_fig(figHandle, fullfile(outDir, 'Fig7B - Bootstrapped population stimulus discriminability.png'));
    close(figHandle);
end

% ========================================================================= %
%  Composite Figure 7 (Manuscript Layout matching FinalFig7.png)
% ========================================================================= %
function local_plot_fig7_composite(ldaData, outDir)
    genotypes = {'WT', 'KO'};
    shuffleNames = {'true', 'shuffled'};
    shuffleColors = {[0.5, 0, 0.5], [0.5, 0.5, 0.5]};
    binEdges = 0 : 0.025 : 1;
    nBoot = 100;

    figComp = figure('Units', 'inches', 'Position', [1, 1, 3.6, 7.0], ...
        'Color', 'w', 'PaperPositionMode', 'auto', 'Visible', 'off');

    colX = [0.18, 0.60];
    rowY = [0.73, 0.41, 0.09];
    w = 0.34;
    h = 0.19;

    % Top: Panel A (WT, 2 subplots)
    for b = 1:2
        ax = axes('Position', [colX(b), rowY(1), w, h]);
        hold(ax, 'on');
        xline(ax, 0.5, '--', 'LineWidth', 0.75, 'Color', 'k');

        caTrue = ldaData.bins(b).WT.LDA_true;
        caShuff = ldaData.bins(b).WT.LDA_shuffle;

        for sIdx = 1:2
            if sIdx == 1
                ca = caTrue;
                lWidth = 1.0;
            else
                ca = caShuff;
                lWidth = 0.5;
            end
            colorVal = shuffleColors{sIdx};
            hHist = histogram(ax, ca, binEdges, ...
                'FaceColor', colorVal, 'FaceAlpha', 0.6, ...
                'EdgeColor', colorVal, 'LineWidth', lWidth);

            caMedian = median(ca, 'omitnan');
            binCenters = (hHist.BinEdges(1:end-1) + hHist.BinEdges(2:end)) / 2;
            [~, centerIdx] = min(abs(caMedian - binCenters));
            plot(ax, binCenters(centerIdx), 7, 'v', ...
                'LineWidth', 1, 'MarkerSize', 3.5, 'Color', colorVal);

            if b == 1
                text(ax, 0.65, (7.5 - 1.0 * sIdx), shuffleNames{sIdx}, ...
                    'Color', colorVal, 'FontSize', 8, 'FontName', 'Arial');
            end
        end

        set(ax, 'Box', 'off', 'TickDir', 'out', 'FontSize', 8, 'FontName', 'Arial', ...
            'LineWidth', 0.75, 'XLim', [0, 1], 'XTick', 0 : 0.25 : 1, 'XTickLabel', {'0', '0.25', '0.5', '0.75', '1'}, ...
            'XTickLabelRotation', 45, 'YLim', [0, 8], 'YTick', 0 : 2 : 8);

        if b == 1
            ylabel(ax, 'Number of sessions', 'FontSize', 8, 'FontName', 'Arial');
        end
        title(ax, ldaData.bins(b).timeLabel, 'FontSize', 8, 'FontName', 'Arial', 'FontWeight', 'normal');
    end

    % Middle: Panel A (KO, 2 subplots)
    for b = 1:2
        ax = axes('Position', [colX(b), rowY(2), w, h]);
        hold(ax, 'on');
        xline(ax, 0.5, '--', 'LineWidth', 0.75, 'Color', 'k');

        caTrue = ldaData.bins(b).KO.LDA_true;
        caShuff = ldaData.bins(b).KO.LDA_shuffle;

        for sIdx = 1:2
            if sIdx == 1
                ca = caTrue;
                lWidth = 1.0;
            else
                ca = caShuff;
                lWidth = 0.5;
            end
            colorVal = shuffleColors{sIdx};
            hHist = histogram(ax, ca, binEdges, ...
                'FaceColor', colorVal, 'FaceAlpha', 0.6, ...
                'EdgeColor', colorVal, 'LineWidth', lWidth);

            caMedian = median(ca, 'omitnan');
            binCenters = (hHist.BinEdges(1:end-1) + hHist.BinEdges(2:end)) / 2;
            [~, centerIdx] = min(abs(caMedian - binCenters));
            plot(ax, binCenters(centerIdx), 7, 'v', ...
                'LineWidth', 1, 'MarkerSize', 3.5, 'Color', colorVal);

            if b == 1
                text(ax, 0.65, (7.5 - 1.0 * sIdx), shuffleNames{sIdx}, ...
                    'Color', colorVal, 'FontSize', 8, 'FontName', 'Arial');
            end
        end

        set(ax, 'Box', 'off', 'TickDir', 'out', 'FontSize', 8, 'FontName', 'Arial', ...
            'LineWidth', 0.75, 'XLim', [0, 1], 'XTick', 0 : 0.25 : 1, 'XTickLabel', {'0', '0.25', '0.5', '0.75', '1'}, ...
            'XTickLabelRotation', 45, 'YLim', [0, 8], 'YTick', 0 : 2 : 8);

        if b == 1
            ylabel(ax, 'Number of sessions', 'FontSize', 8, 'FontName', 'Arial');
        end
        title(ax, ldaData.bins(b).timeLabel, 'FontSize', 8, 'FontName', 'Arial', 'FontWeight', 'normal');
    end

    % Bottom: Panel B (Bootstrapped population stimulus-discriminability)
    for b = 1:2
        ax = axes('Position', [colX(b), rowY(3), w, h]);
        hold(ax, 'on');
        yline(ax, 0.5, '--', 'LineWidth', 0.75, 'Color', 'k');

        for g = 1:numel(genotypes)
            geno = genotypes{g};
            for sIdx = 1:2
                if sIdx == 1
                    rawBoot = ldaData.bins(b).(geno).boot_true;
                else
                    rawBoot = ldaData.bins(b).(geno).boot_shuffle;
                end
                sortedAcc = sort(rawBoot);
                accMean = mean(sortedAcc);
                up95CI = sortedAcc(round(0.975 * nBoot));
                low95CI = sortedAcc(round(0.025 * nBoot));

                xPos = g + sIdx * 0.2 - 0.3;
                colorVal = shuffleColors{sIdx};

                errorbar(ax, xPos, accMean, (accMean - low95CI), (up95CI - accMean), 'o', ...
                    'Color', colorVal, 'MarkerEdgeColor', colorVal, ...
                    'MarkerFaceColor', colorVal, 'MarkerSize', 5, ...
                    'CapSize', 4, 'LineWidth', 0.75);

                if b == 1 && g == 1
                    text(ax, 1.4, (0.80 - 0.05 * sIdx), shuffleNames{sIdx}, ...
                        'Color', colorVal, 'FontSize', 8, 'FontName', 'Arial');
                end
            end
        end

        set(ax, 'Box', 'off', 'TickDir', 'out', 'FontSize', 8, 'FontName', 'Arial', ...
            'LineWidth', 0.75, 'XLim', [0.5, 2.5], 'XTick', 1:2, 'XTickLabel', genotypes, ...
            'YLim', [0.3, 1.0], 'YTick', 0.4 : 0.2 : 1.0);

        ylabel(ax, 'Classification accuracy', 'FontSize', 8, 'FontName', 'Arial');
        title(ax, ldaData.bins(b).timeLabel, 'FontSize', 8, 'FontName', 'Arial', 'FontWeight', 'normal');
    end

    % Add row titles and shared xlabel for histograms
    wtN = numel(ldaData.bins(1).WT.LDA_true);
    koN = numel(ldaData.bins(2).KO.LDA_true);

    annotation(figComp, 'textbox', [0.15, 0.95, 0.70, 0.04], ...
        'String', sprintf('WT n= %d sessions', wtN), ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
        'FontSize', 9, 'FontName', 'Arial', 'FontWeight', 'normal', 'Color', [0.4, 0.4, 0.4]);

    annotation(figComp, 'textbox', [0.15, 0.63, 0.70, 0.04], ...
        'String', sprintf('KO n= %d sessions', koN), ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
        'FontSize', 9, 'FontName', 'Arial', 'FontWeight', 'normal', 'Color', 'k');

    annotation(figComp, 'textbox', [0.15, 0.33, 0.70, 0.04], ...
        'String', 'Classification accuracy', ...
        'EdgeColor', 'none', 'HorizontalAlignment', 'center', ...
        'FontSize', 8, 'FontName', 'Arial');

    local_export_fig(figComp, fullfile(outDir, 'Fig7 - Whisker-side stimulus discriminability in wM1.pdf'));
    local_export_fig(figComp, fullfile(outDir, 'Fig7 - Whisker-side stimulus discriminability in wM1.png'));
    close(figComp);
end

% ========================================================================= %
%  Helper: Safe export
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
