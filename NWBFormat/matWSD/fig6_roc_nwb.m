function fig6_roc_nwb(tablesDir, outDir)
% FIG6_ROC_NWB  Plot Figure 6 Single-Unit ROC & Body-Side Selectivity Analysis (M1)
%
%   fig6_roc_nwb()
%   fig6_roc_nwb(tablesDir, outDir)
%
% Generates:
%   - Fig 6C: AUC distribution 50ms histograms (WT n=128, KO n=148) with dark gray bars & black text
%   - Fig 6D_E: Bootstrapped 5ms selectivity time courses (WT, KO, WT - KO)
%   - Fig 6F: Onset of significant side selectivity CDF (0 ~ 80 ms) & KS tests
%   - Fig S8: 50ms permutation & bootstrapping test (3x3 grid)

    if nargin < 1 || isempty(tablesDir)
        tablesDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Data\Tables\ROC');
    end

    if nargin < 2 || isempty(outDir)
        outDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Figures\Matlab\Fig6');
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    table50msFile = fullfile(tablesDir, 'fig6_roc_tables_M1_50ms.mat');
    table5msFile  = fullfile(tablesDir, 'fig6_roc_tables_M1_5ms.mat');

    if ~exist(table50msFile, 'file') || ~exist(table5msFile, 'file')
        error('M1 ROC tables missing in %s. Run fig6_roc_tables_nwb first.', tablesDir);
    end

    fprintf('Loading M1 ROC tables from %s...\n', tablesDir);
    data50ms = load(table50msFile);
    data5ms  = load(table5msFile);

    rocTable50ms = data50ms.rocTable50ms;
    rocTable5ms  = data5ms.rocTable5ms;

    % 1. Fig 6C: 50-ms AUC Distribution Histograms (Dark gray significant bars, matching original PNG)
    fprintf('Plotting Figure 6C: 50ms AUC Distribution Histograms...\n');
    local_plot_fig6c(rocTable50ms, outDir);

    % 2. Fig 6D_E: 5-ms Bootstrapped Selectivity Time Courses (matching original PDF)
    fprintf('Plotting Figure 6D_E: 5ms Bootstrapped Selectivity Time Courses...\n');
    local_plot_fig6de(rocTable5ms, outDir);

    % 3. Fig 6F: Time Course of Selectivity Onset CDF & KS tests (matching original PDF)
    fprintf('Plotting Figure 6F: Selectivity Onset Latency CDF...\n');
    local_plot_fig6f(rocTable5ms, outDir);

    % 4. Fig S8: 50-ms Permutation and Bootstrapping Test (3x3 grid)
    fprintf('Plotting Figure S8: 50ms Bootstrapping CI...\n');
    local_plot_figs8(rocTable50ms, outDir);

    fprintf('Figure 6 Single-Unit ROC plots completed successfully in: %s\n', outDir);
end

% ========================================================================= %
%  Panel 6C: 50-ms AUC distribution histograms (Dark gray bars, black text)
% ========================================================================= %
function local_plot_fig6c(rocTable50ms, outDir)
    genotypes = {'WT', 'KO'};
    binEdges = 0 : 0.05 : 1;
    timeLabels = {'-50 ~ 0 ms', '0 ~ 50 ms', '50 ~ 100 ms'};

    for g = 1:numel(genotypes)
        geno = genotypes{g};
        units = rocTable50ms.(geno);
        N = numel(units);

        gg = figure('Units', 'inches', 'Position', [1, 1, 5.2, 2.0], ...
            'Color', 'w', 'PaperPositionMode', 'auto');

        for b = 1:3
            ax = subplot(1, 3, b);

            aucMeans = arrayfun(@(u) u.AUC_mean(b), units);
            isSig    = arrayfun(@(u) u.isSignificant(b), units);
            isCon    = arrayfun(@(u) u.isConPref(b), units);
            isIpsi   = arrayfun(@(u) u.isIpsiPref(b), units);

            % Significant contra and ipsi units
            sigCon  = isSig & isCon;
            sigIpsi = isSig & isIpsi;

            % Normalization counts
            hAllCounts  = histcounts(aucMeans, binEdges) / N;
            hConCounts  = histcounts(aucMeans(sigCon), binEdges) / N;
            hIpsiCounts = histcounts(aucMeans(sigIpsi), binEdges) / N;

            % Plot all units: white with black edge
            histogram('BinEdges', binEdges, 'BinCounts', hAllCounts, ...
                'FaceColor', 'w', 'EdgeColor', 'k', 'LineWidth', 0.5);
            hold on;

            % Plot significant contra units: red face with black edge
            histogram('BinEdges', binEdges, 'BinCounts', hConCounts, ...
                'FaceColor', [1, 0, 0], 'FaceAlpha', 0.6, 'EdgeColor', 'k', 'LineWidth', 0.5);

            % Plot significant ipsi units: blue face with black edge
            histogram('BinEdges', binEdges, 'BinCounts', hIpsiCounts, ...
                'FaceColor', [0, 0, 1], 'FaceAlpha', 0.6, 'EdgeColor', 'k', 'LineWidth', 0.5);

            conPct = round(sum(sigCon) / N * 100, 1);
            ipsiPct = round(sum(sigIpsi) / N * 100, 1);

            if conPct == 0 || mod(conPct, 1) == 0
                conPctStr = sprintf('%d%%', round(conPct));
            else
                conPctStr = sprintf('%0.1f%%', conPct);
            end

            if ipsiPct == 0 || mod(ipsiPct, 1) == 0
                ipsiPctStr = sprintf('%d%%', round(ipsiPct));
            else
                ipsiPctStr = sprintf('%0.1f%%', ipsiPct);
            end

            % Formatting
            set(ax, 'Box', 'off', 'TickDir', 'out', 'FontName', 'Arial', 'FontSize', 8, ...
                'LineWidth', 0.5, 'XLim', [0, 1], 'XTick', [0, 0.5, 1], 'XTickLabel', {'0', '0.5', '1'}, ...
                'YLim', [0, 0.6], 'YTick', 0 : 0.2 : 0.6);

            % Percentage text labels: Red for contra, Blue for ipsi
            text(0.75, 0.30, conPctStr, 'FontSize', 8, 'FontName', 'Arial', ...
                'Color', [1, 0, 0], 'HorizontalAlignment', 'center');
            text(0.12, 0.30, ipsiPctStr, 'FontSize', 8, 'FontName', 'Arial', ...
                'Color', [0, 0, 1], 'HorizontalAlignment', 'center');

            ylabel('Proportion of units', 'FontSize', 8, 'FontName', 'Arial');
            xlabel('AUC', 'FontSize', 8, 'FontName', 'Arial');
            title(timeLabels{b}, 'FontWeight', 'bold', 'FontSize', 8, 'FontName', 'Arial');
        end

        sgtitle(sprintf('%s n= %d units', geno, N), 'FontSize', 9, 'FontName', 'Arial', 'FontWeight', 'normal');

        baseName = sprintf('AUC_histogram_Motor_%s_20Hz_50msBin_-50to150ms_1000nBoot_150pvalueMin', geno);
        local_export_fig(gg, fullfile(outDir, [baseName '.pdf']));
        local_export_fig(gg, fullfile(outDir, [baseName '.png']));
        local_export_fig(gg, fullfile(outDir, sprintf('Fig6C - AUC distribution 50ms (%s).pdf', geno)));
        local_export_fig(gg, fullfile(outDir, sprintf('Fig6C - AUC distribution 50ms (%s).png', geno)));
        close(gg);
    end
end

% ========================================================================= %
%  Panel 6D_E: Bootstrapped 5-ms Selectivity Time Courses (Matching PDF)
% ========================================================================= %
function local_plot_fig6de(rocTable5ms, outDir)
    genotypes = {'WT', 'KO'};
    time = (rocTable5ms.binCenters) * 1000; % in ms
    ttColors = {'r', 'b'};

    sigPctCon = cell(1, 2);
    sigPctIpsi = cell(1, 2);
    bootConMean = cell(1, 2);
    bootIpsiMean = cell(1, 2);
    ciCon = cell(1, 2);
    ciIpsi = cell(1, 2);

    for g = 1:numel(genotypes)
        geno = genotypes{g};
        units = rocTable5ms.(geno);
        N = numel(units);

        bootConMat = zeros(1000, 40);
        bootIpsiMat = zeros(1000, 40);

        % Real proportions
        sigPctCon{g} = zeros(1, 40);
        sigPctIpsi{g} = zeros(1, 40);
        for b = 1:40
            cCount = sum(arrayfun(@(u) u.isSignificant(b) && u.isConPref(b), units));
            iCount = sum(arrayfun(@(u) u.isSignificant(b) && u.isIpsiPref(b), units));
            sigPctCon{g}(b) = round(cCount / N * 100, 1);
            sigPctIpsi{g}(b) = round(iCount / N * 100, 1);
        end

        % Precomputed bootstrap resampling
        rng(42);
        for boot = 1:1000
            sampleIdx = randi(N, 1, N);
            for b = 1:40
                cCount = 0;
                iCount = 0;
                for idx = 1:N
                    u = units(sampleIdx(idx));
                    if u.isSignificant(b) && u.isConPref(b)
                        cCount = cCount + 1;
                    elseif u.isSignificant(b) && u.isIpsiPref(b)
                        iCount = iCount + 1;
                    end
                end
                bootConMat(boot, b) = round(cCount / N * 100, 1);
                bootIpsiMat(boot, b) = round(iCount / N * 100, 1);
            end
        end

        bootConMean{g} = mean(bootConMat, 1);
        bootIpsiMean{g} = mean(bootIpsiMat, 1);
        ciCon{g} = [prctile(bootConMat, 2.5, 1); prctile(bootConMat, 97.5, 1)];
        ciIpsi{g} = [prctile(bootIpsiMat, 2.5, 1); prctile(bootIpsiMat, 97.5, 1)];
    end

    % 3-Panel Figure: WT (2,2,1), KO (2,2,3), Diff (2,2,2)
    gg = figure('Units', 'inches', 'Position', [1, 1, 3.2, 4.2], ...
        'Color', 'w', 'PaperPositionMode', 'auto');

    for g = 1:2
        spIdx = (g - 1) * 2 + 1;
        subplot(2, 2, spIdx);

        yline(0, '-', 'Color', 'k', 'LineWidth', 1.0);
        hold on;

        % Error shading with Alpha 0.3
        local_plot_ci_band(time, bootConMean{g} / 100, ciCon{g}(1, :) / 100, ciCon{g}(2, :) / 100, [1, 0, 0], 0.3);
        local_plot_ci_band(time, bootIpsiMean{g} / 100, ciIpsi{g}(1, :) / 100, ciIpsi{g}(2, :) / 100, [0, 0, 1], 0.3);

        % Mean lines
        plot(time, sigPctCon{g} / 100, 'Color', ttColors{1}, 'LineWidth', 1.0);
        plot(time, sigPctIpsi{g} / 100, 'Color', ttColors{2}, 'LineWidth', 1.0);

        set(gca, 'Box', 'off', 'TickDir', 'out', 'FontName', 'Arial', 'FontSize', 8, ...
            'LineWidth', 1.0, 'XLim', [-10, 100], 'XTick', [0, 50, 100], ...
            'YLim', [-0.02, 0.20], 'YTick', 0 : 0.05 : 0.20);
        xlabel('Time from stimulus onset (ms)', 'FontSize', 8, 'FontName', 'Arial');
        ylabel('Fraction of units', 'FontSize', 8, 'FontName', 'Arial');
    end

    % Subplot (2, 2, 2): Difference WT - KO
    subplot(2, 2, 2);
    yline(0, '-', 'Color', 'k', 'LineWidth', 1.0);
    hold on;

    diffCon = (sigPctCon{1} - sigPctCon{2}) / 100;
    diffIpsi = (sigPctIpsi{1} - sigPctIpsi{2}) / 100;

    ciDiffCon = [(ciCon{1}(1, :) - ciCon{2}(2, :)) / 100; (ciCon{1}(2, :) - ciCon{2}(1, :)) / 100];
    ciDiffIpsi = [(ciIpsi{1}(1, :) - ciIpsi{2}(2, :)) / 100; (ciIpsi{1}(2, :) - ciIpsi{2}(1, :)) / 100];

    local_plot_ci_band(time, (bootConMean{1} - bootConMean{2}) / 100, ciDiffCon(1, :), ciDiffCon(2, :), [1, 0, 0], 0.3);
    local_plot_ci_band(time, (bootIpsiMean{1} - bootIpsiMean{2}) / 100, ciDiffIpsi(1, :), ciDiffIpsi(2, :), [0, 0, 1], 0.3);

    plot(time, diffCon, 'Color', ttColors{1}, 'LineWidth', 1.0);
    plot(time, diffIpsi, 'Color', ttColors{2}, 'LineWidth', 1.0);

    set(gca, 'Box', 'off', 'TickDir', 'out', 'FontName', 'Arial', 'FontSize', 8, ...
        'LineWidth', 1.0, 'XLim', [-10, 100], 'XTick', [0, 50, 100], ...
        'YLim', [-0.15, 0.15], 'YTick', -0.15 : 0.075 : 0.15);
    xlabel('Time from stimulus onset (ms)', 'FontSize', 8, 'FontName', 'Arial');
    ylabel('Fraction of units', 'FontSize', 8, 'FontName', 'Arial');

    baseName = 'PercentageSigUnit_Motor_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMinbootstrapped';
    local_export_fig(gg, fullfile(outDir, [baseName '.pdf']));
    local_export_fig(gg, fullfile(outDir, [baseName '.png']));
    local_export_fig(gg, fullfile(outDir, 'Fig6D_E - Percentage selective units 5ms bootstrapped.pdf'));
    local_export_fig(gg, fullfile(outDir, 'Fig6D_E - Percentage selective units 5ms bootstrapped.png'));
    close(gg);
end

% ========================================================================= %
%  Panel 6F: Onset of Significant Side Selectivity CDF (Matching Original)
% ========================================================================= %
function local_plot_fig6f(rocTable5ms, outDir)
    genotypes = {'WT', 'KO'};
    ttColors = {'r', 'b'};
    genoLines = {'-', '--'};

    statData = struct();
    statData.isConPref = cell(1, 2);
    statData.isIpsiPref = cell(1, 2);

    gg = figure('Units', 'inches', 'Position', [1, 1, 2.0, 1.8], ...
        'Color', 'w', 'PaperPositionMode', 'auto');

    for g = 1:2
        geno = genotypes{g};
        units = rocTable5ms.(geno);
        N = numel(units);
        alpha_Bonferroni = 0.05 / N;

        binStart = 11; % t = 0 ms
        binEnd = 40;   % t = 150 ms

        sig_onset = nan(1, N);
        isConPref = false(1, N);
        isIpsiPref = false(1, N);

        for u = 1:N
            isSigBin = false(1, 30);
            for b = binStart:binEnd
                upCI = prctile(units(u).AUC_boots(b, :), (1 - alpha_Bonferroni/2)*100);
                lowCI = prctile(units(u).AUC_boots(b, :), (alpha_Bonferroni/2)*100);
                isSigBin(b - binStart + 1) = (0.5 - upCI)*(0.5 - lowCI) > 0;
            end

            % Find first 3 consecutive significant bins
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

        statData.isConPref{g} = sig_onset(isConPref);
        statData.isIpsiPref{g} = sig_onset(isIpsiPref);

        lineWidth = 0.5;
        if g == 2
            lineWidth = 1.0;
        end

        % Plot empirical CDFs
        if any(isConPref)
            hCon = cdfplot(sig_onset(isConPref));
            hold on;
            set(hCon, 'Color', ttColors{1}, 'LineStyle', genoLines{g}, 'LineWidth', lineWidth);
        end

        if any(isIpsiPref)
            hIpsi = cdfplot(sig_onset(isIpsiPref));
            hold on;
            set(hIpsi, 'Color', ttColors{2}, 'LineStyle', genoLines{g}, 'LineWidth', lineWidth);
        else
            hLine = yline(0, 'Color', ttColors{2}, 'LineStyle', genoLines{g}, 'LineWidth', lineWidth);
            hold on;
        end
    end

    grid off;
    set(gca, 'Box', 'off', 'TickDir', 'out', 'FontName', 'Arial', 'FontSize', 8, ...
        'LineWidth', 1.0, 'XLim', [0, 80], 'XTick', 0 : 20 : 80, 'YLim', [0, 1], 'YTick', 0 : 0.2 : 1.0);
    title('');
    xlabel('Onset of significant side selectivity (ms)', 'FontSize', 8, 'FontName', 'Arial');
    ylabel('Proportion of units', 'FontSize', 8, 'FontName', 'Arial');

    % Calculate and export KS statistics
    statFile = fullfile(outDir, 'StatisticsSelectivityOnset.txt');
    fid = fopen(statFile, 'w');

    WTc = statData.isConPref{1};
    WTi = statData.isIpsiPref{1};
    KOc = statData.isConPref{2};
    KOi = statData.isIpsiPref{2};

    [~, pvalContra] = kstest2(WTc, KOc, 'Tail', 'unequal');
    fprintf(fid, 'Contra two-sided ks test WT != KO pval: %0.5f\n', pvalContra);

    [~, pvalKO] = kstest2(KOc, KOi, 'Tail', 'larger');
    fprintf(fid, 'KO one-sided ks test contra < ipsi pval: %0.5f\n', pvalKO);

    [~, pvalWTKO] = kstest2(WTc, KOi, 'Tail', 'larger');
    fprintf(fid, 'one-sided ks test WT contra < KO ipsi pval: %0.7f\n', pvalWTKO);

    fclose(fid);

    baseName = 'SigOnset_Motor_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin';
    local_export_fig(gg, fullfile(outDir, [baseName '.pdf']));
    local_export_fig(gg, fullfile(outDir, [baseName '.png']));
    local_export_fig(gg, fullfile(outDir, 'Fig6F - Time course of selectivity onset CDF.pdf'));
    local_export_fig(gg, fullfile(outDir, 'Fig6F - Time course of selectivity onset CDF.png'));
    close(gg);
end

% ========================================================================= %
%  Panel S8: 50-ms Bin Bootstrapping Confidence Intervals (3x3 Grid)
% ========================================================================= %
function local_plot_figs8(rocTable50ms, outDir)
    genotypes = {'WT', 'KO'};
    binNames = {'-50 ~ 0 ms', '0 ~ 50 ms', '50 ~ 100 ms'};
    stimNames = {'Ipsi', 'Contra'};
    purple = [0.5, 0, 0.5];

    sigConOver = zeros(2, 3);
    sigIpsiOver = zeros(2, 3);
    sigConBoot = cell(1, 2);
    sigIpsiBoot = cell(1, 2);

    for g = 1:2
        geno = genotypes{g};
        units = rocTable50ms.(geno);
        N = numel(units);

        sigConBoot{g} = zeros(1000, 3);
        sigIpsiBoot{g} = zeros(1000, 3);

        for b = 1:3
            conCount = sum(arrayfun(@(u) u.isSignificant(b) && u.isConPref(b), units));
            ipsiCount = sum(arrayfun(@(u) u.isSignificant(b) && u.isIpsiPref(b), units));
            sigConOver(g, b) = round(conCount / N * 100, 1);
            sigIpsiOver(g, b) = round(ipsiCount / N * 100, 1);
        end

        rng(42);
        for boot = 1:1000
            sampleIdx = randi(N, 1, N);
            for b = 1:3
                cC = 0;
                iC = 0;
                for idx = 1:N
                    u = units(sampleIdx(idx));
                    if u.isSignificant(b) && u.isConPref(b)
                        cC = cC + 1;
                    elseif u.isSignificant(b) && u.isIpsiPref(b)
                        iC = iC + 1;
                    end
                end
                sigConBoot{g}(boot, b) = round(cC / N * 100, 1);
                sigIpsiBoot{g}(boot, b) = round(iC / N * 100, 1);
            end
        end
    end

    statFile = fullfile(outDir, 'Statistics_permutationtest.txt');
    fid = fopen(statFile, 'w');

    gg = figure('Units', 'inches', 'Position', [1, 1, 4.0, 4.0], ...
        'Color', 'w', 'PaperPositionMode', 'auto');

    % Rows 1 & 2: WT and KO
    for g = 1:2
        geno = genotypes{g};
        for b = 1:3
            spIdx = (g - 1) * 3 + b;
            subplot(3, 3, spIdx);

            for stim = 1:2
                if stim == 1
                    meanVal = sigIpsiOver(g, b);
                    bootVals = sort(sigIpsiBoot{g}(:, b));
                    sName = 'Ipsi';
                else
                    meanVal = sigConOver(g, b);
                    bootVals = sort(sigConBoot{g}(:, b));
                    sName = 'Contra';
                end
                low95 = bootVals(25);
                up95 = bootVals(975);

                errorbar(stim, meanVal, meanVal - low95, up95 - meanVal, 'o', ...
                    'Color', purple, 'MarkerFaceColor', purple, 'MarkerSize', 4, ...
                    'CapSize', 4, 'LineWidth', 0.8);
                hold on;

                fprintf(fid, 'For Motor %s %s %s: real CI is %0.1f to %0.1f\n', ...
                    geno, sName, binNames{b}, low95, up95);
            end

            yline(0, '--', 'Color', [0.5, 0.5, 0.5], 'LineWidth', 0.5);
            set(gca, 'Box', 'off', 'TickDir', 'out', 'FontName', 'Arial', 'FontSize', 8, ...
                'LineWidth', 0.8, 'XLim', [0.5, 2.5], 'XTick', [1, 2], 'XTickLabel', stimNames, ...
                'YLim', [-5, 30], 'YTick', 0 : 10 : 30);

            if b == 1
                ylabel('Percent units', 'FontSize', 8, 'FontName', 'Arial');
            else
                ylabel('');
            end
            if g == 1
                title(binNames{b}, 'FontSize', 8, 'FontName', 'Arial', 'FontWeight', 'normal');
            end
        end
    end

    % Row 3: WT - KO difference
    for b = 1:3
        subplot(3, 3, 6 + b);

        for stim = 1:2
            if stim == 1
                meanVal = sigIpsiOver(1, b) - sigIpsiOver(2, b);
                bootVals = sort(sigIpsiBoot{1}(:, b) - sigIpsiBoot{2}(:, b));
                sName = 'Ipsi';
            else
                meanVal = sigConOver(1, b) - sigConOver(2, b);
                bootVals = sort(sigConBoot{1}(:, b) - sigConBoot{2}(:, b));
                sName = 'Contra';
            end
            low95 = bootVals(25);
            up95 = bootVals(975);

            errorbar(stim, meanVal, meanVal - low95, up95 - meanVal, 'o', ...
                'Color', purple, 'MarkerFaceColor', purple, 'MarkerSize', 4, ...
                'CapSize', 4, 'LineWidth', 0.8);
            hold on;

            fprintf(fid, 'For Motor WT-KO %s %s: real CI is %0.1f to %0.1f\n', ...
                sName, binNames{b}, low95, up95);
        end

        yline(0, '--', 'Color', [0.5, 0.5, 0.5], 'LineWidth', 0.5);
        set(gca, 'Box', 'off', 'TickDir', 'out', 'FontName', 'Arial', 'FontSize', 8, ...
            'LineWidth', 0.8, 'XLim', [0.5, 2.5], 'XTick', [1, 2], 'XTickLabel', stimNames, ...
            'YLim', [-30, 30], 'YTick', -30 : 15 : 30);

        if b == 1
            ylabel('\Delta Percent units', 'FontSize', 8, 'FontName', 'Arial');
        else
            ylabel('');
        end
    end

    fclose(fid);

    baseName = 'ROC_permutation_Motor_KO_20Hz_50msBin_-50to150ms_3respMin';
    local_export_fig(gg, fullfile(outDir, [baseName '.pdf']));
    local_export_fig(gg, fullfile(outDir, [baseName '.png']));
    local_export_fig(gg, fullfile(outDir, 'FigS8 - ROC permutation test 50ms.pdf'));
    local_export_fig(gg, fullfile(outDir, 'FigS8 - ROC permutation test 50ms.png'));
    close(gg);
end

% ========================================================================= %
%  Helper: plot mean curve with CI shading
% ========================================================================= %
function local_plot_ci_band(time, ~, ciLow, ciHigh, shadeColor, alphaVal)
    fill([time, fliplr(time)], [ciHigh, fliplr(ciLow)], shadeColor, ...
        'EdgeColor', 'none', 'FaceAlpha', alphaVal);
    hold on;
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
