function fig4_roc_nwb(rocTableDir, outDir)
% FIG4_ROC_NWB  Plotting pipeline for Figure 4 & Figure S5 (wS1 Single-Unit ROC Analysis).
%
%   fig4_roc_nwb(rocTableDir, outDir)
%
% Generates all panels for Figure 4 and Figure S5 from the staged ROC AUC tables:
%   Fig 4A: 50-ms AUC distribution histograms (WT and KO)
%   Fig 4B/C: Percentage of significant units over time (5-ms bins, bootstrapped)
%   Fig 4D: Onset of significant side selectivity cumulative distribution (CDF) & KS-tests
%   Fig S5: 50-ms bin bootstrapping confidence intervals & permutation tests (3x3 grid)
%
% Inputs:
%   rocTableDir  Folder containing fig4_roc_tables_S1_50ms.mat and
%                fig4_roc_tables_S1_5ms.mat (default: ...\NWBData\Data\Tables\ROC)
%   outDir       Output folder for figures (default: ...\NWBData\Figures\Matlab\Fig4)

    if nargin < 1 || isempty(rocTableDir)
        rocTableDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Data\Tables\ROC');
    end

    if nargin < 2 || isempty(outDir)
        outDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Figures\Matlab\Fig4');
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % --- Load staged ROC tables ---
    file50ms = fullfile(rocTableDir, 'fig4_roc_tables_S1_50ms.mat');
    file5ms = fullfile(rocTableDir, 'fig4_roc_tables_S1_5ms.mat');

    if ~exist(file50ms, 'file') || ~exist(file5ms, 'file')
        error('fig4_roc_nwb:missingTables', ...
            'ROC tables not found in %s. Please run fig4_roc_tables_nwb first.', rocTableDir);
    end

    fprintf('Loading 50-ms ROC table: %s\n', file50ms);
    data50 = load(file50ms);
    rocTable50ms = data50.rocTable50ms;

    fprintf('Loading 5-ms ROC table: %s\n', file5ms);
    data5 = load(file5ms);
    rocTable5ms = data5.rocTable5ms;

    % --- Generate Figure Panels ---
    fprintf('Plotting Figure 4A (50-ms AUC distribution histograms)...\n');
    local_plot_fig4a(rocTable50ms, outDir);

    fprintf('Plotting Figure 4B/C (5-ms selectivity time course with bootstrap CIs)...\n');
    local_plot_fig4b_c(rocTable5ms, outDir);

    fprintf('Plotting Figure 4D (Selectivity onset latency CDF and KS tests)...\n');
    local_plot_fig4d(rocTable5ms, outDir);

    fprintf('Plotting Figure S5 (50-ms permutation and bootstrap tests, 3x3)...\n');
    local_plot_figs5(rocTable50ms, outDir);

    fprintf('Figure 4 and Figure S5 plots completed successfully in: %s\n', outDir);
end

% ========================================================================= %
%  Panel 4A: 50-ms AUC Distribution Histograms (WT & KO)
% ========================================================================= %
function local_plot_fig4a(rocTable50ms, outDir)
    genotypes = {'WT', 'KO'};
    binEdges = 0 : 0.05 : 1;
    timeWindow = [-0.05, 0.15];
    binSize = 0.05;

    for g = 1:numel(genotypes)
        geno = genotypes{g};
        units = rocTable50ms.(geno);
        nUnits = numel(units);

        gg = figure('Units', 'inches', 'Position', [1, 1, 4.5, 1.65], 'Visible', 'off');
        clf(gg);

        for b = 1:3
            aucMean = arrayfun(@(u) u.AUC_mean(b), units);
            isSig = arrayfun(@(u) u.isSignificant(b), units);
            isCon = arrayfun(@(u) u.isConPref(b), units);
            isIpsi = arrayfun(@(u) u.isIpsiPref(b), units);

            sigPercentCon = round(sum(isSig & isCon) / nUnits * 100, 1);
            sigPercentIpsi = round(sum(isSig & isIpsi) / nUnits * 100, 1);

            ax = subplot(1, 3, b);
            hold on;

            % Compute normalized histograms (BinCounts / length(AUC_mean))
            countsAll = histcounts(aucMean, binEdges) / nUnits;
            countsCon = histcounts(aucMean(isSig & isCon), binEdges) / nUnits;
            countsIpsi = histcounts(aucMean(isSig & isIpsi), binEdges) / nUnits;

            % All units: white face with crisp black edge
            histogram('BinEdges', binEdges, 'BinCounts', countsAll, ...
                'FaceColor', 'white', 'EdgeColor', 'k', 'LineWidth', 0.5);

            % Contra units: red face (alpha 0.6) with black edge
            histogram('BinEdges', binEdges, 'BinCounts', countsCon, ...
                'FaceColor', [1, 0, 0], 'FaceAlpha', 0.6, 'EdgeColor', 'k', 'LineWidth', 0.5);

            % Ipsi units: blue face (alpha 0.6) with black edge
            histogram('BinEdges', binEdges, 'BinCounts', countsIpsi, ...
                'FaceColor', [0, 0, 1], 'FaceAlpha', 0.6, 'EdgeColor', 'k', 'LineWidth', 0.5);

            hold off;

            if b == 1
                ylim([0, 0.6]);
            else
                ylim([0, 0.45]);
            end

            xlim([0, 1]);
            xticks(0 : 0.1 : 1);
            xticklabels({0, [], [], [], [], 0.5, [], [], [], [], 1});
            yticks(0 : 0.2 : 0.6);
            set(gca, 'Box', 'off', 'TickDir', 'out', 'FontName', 'Arial', 'FontSize', 8, 'LineWidth', 1);

            text(0.7, 0.3, [num2str(sigPercentCon), '%'], ...
                'FontSize', 8, 'FontName', 'Arial', 'Color', [1, 0, 0]);
            text(0.075, 0.3, [num2str(sigPercentIpsi), '%'], ...
                'FontSize', 8, 'FontName', 'Arial', 'Color', [0, 0, 1]);

            ax.XTickLabelRotation = 0;
            if b == 1
                ylabel('Fraction of units', 'FontName', 'Arial', 'FontSize', 8);
            end

            startTime = round(1000 * (timeWindow(1) + (b - 1) * binSize));
            endTime = round(1000 * (timeWindow(1) + b * binSize));
            title([num2str(startTime) ' ~ ' num2str(endTime) ' ms'], ...
                'FontSize', 8, 'FontName', 'Arial', 'FontWeight', 'normal');
        end

        exportgraphics(gg, fullfile(outDir, ['AUC_histogram_S1_' geno '_20Hz_50msBin_-50to150ms_1000nBoot_150pvalueMin.pdf']), 'Resolution', 300);
        exportgraphics(gg, fullfile(outDir, ['Fig4A - AUC distribution 50ms (' geno ').png']), 'Resolution', 300);
        exportgraphics(gg, fullfile(outDir, ['Fig4A - AUC distribution 50ms (' geno ').pdf']), 'Resolution', 300);
        close(gg);
    end
end

% ========================================================================= %
%  Panel 4B/C: Percentage of significant units over time (5-ms bin, bootstrapped)
% ========================================================================= %
function local_plot_fig4b_c(rocTable5ms, outDir)
    genotypes = {'WT', 'KO'};
    nBoot = 1000;
    binSize = 0.005;
    timeWindow = [-0.05, 0.15];
    binNum = round((timeWindow(2) - timeWindow(1)) / binSize);
    time = (timeWindow(1) + binSize : binSize : timeWindow(2)) * 1000; % in ms

    shadeColor{1} = {[1, 0, 0], [0, 0, 1]};
    shadeColor{2} = {[1, 0, 0], [0, 0, 1]};

    sigPercentCon = cell(1, 2);
    sigPercentIpsi = cell(1, 2);
    sigPercentConBoot = cell(1, 2);
    sigPercentIpsiBoot = cell(1, 2);

    gg = figure('Units', 'inches', 'Position', [1, 1, 4, 3.2], 'Visible', 'off');
    clf(gg);

    for g = 1:2
        units = rocTable5ms.(genotypes{g});
        nUnits = numel(units);
        genotypeColors = shadeColor{g};

        % Unit indicator matrix (nUnits x binNum)
        isConSig = zeros(nUnits, binNum);
        isIpsiSig = zeros(nUnits, binNum);
        for u = 1:nUnits
            isConSig(u, :) = units(u).isSignificant & units(u).isConPref;
            isIpsiSig(u, :) = units(u).isSignificant & units(u).isIpsiPref;
        end

        sigPercentCon{g} = round(sum(isConSig, 1) / nUnits * 100, 1);
        sigPercentIpsi{g} = round(sum(isIpsiSig, 1) / nUnits * 100, 1);

        % Bootstrap over units
        rng(42 + g);
        idx = randi(nUnits, [nUnits, nBoot]);
        contraBoot = zeros(nBoot, binNum);
        ipsiBoot = zeros(nBoot, binNum);
        for b = 1:nBoot
            contraBoot(b, :) = round(sum(isConSig(idx(:, b), :), 1) / nUnits * 100, 1);
            ipsiBoot(b, :) = round(sum(isIpsiSig(idx(:, b), :), 1) / nUnits * 100, 1);
        end
        sigPercentConBoot{g} = contraBoot;
        sigPercentIpsiBoot{g} = ipsiBoot;

        ciContra(1, :) = prctile(contraBoot, 2.5, 1);
        ciContra(2, :) = prctile(contraBoot, 97.5, 1);
        ciIpsi(1, :) = prctile(ipsiBoot, 2.5, 1);
        ciIpsi(2, :) = prctile(ipsiBoot, 97.5, 1);

        % Subplot: WT top-left (1), KO bottom-left (3)
        subplot(2, 2, (g - 1) * 2 + 1);
        hold on;
        plot(time, sigPercentCon{g} / 100, 'Color', genotypeColors{1}, 'LineWidth', 1);
        plot(time, sigPercentIpsi{g} / 100, 'Color', genotypeColors{2}, 'LineWidth', 1);
        local_error_shade(time, mean(contraBoot, 1) / 100, ciContra(2, :) / 100, ...
            ciContra(1, :) / 100, genotypeColors{1}, 0.3);
        local_error_shade(time, mean(ipsiBoot, 1) / 100, ciIpsi(2, :) / 100, ...
            ciIpsi(1, :) / 100, genotypeColors{2}, 0.3);

        set(gca, 'Box', 'off', 'TickDir', 'out', 'LineWidth', 1, 'FontSize', 8, 'FontName', 'Arial');
        xlim([-10, 100]);
        ylim([-0.02, 0.4]);
        xlabel('Time from stimulus onset (ms)', 'FontSize', 8, 'FontName', 'Arial');
        ylabel('Fraction of units', 'FontSize', 8, 'FontName', 'Arial');
        xticks(-50 : 50 : 150);
    end

    % Subplot (2, 2, 2): Delta WT - KO for Contra & Ipsi
    diffPercentContra = sigPercentCon{1} - sigPercentCon{2};
    diffPercentContraBoot = sigPercentConBoot{1} - sigPercentConBoot{2};
    ciDiffContra(1, :) = prctile(diffPercentContraBoot, 2.5, 1);
    ciDiffContra(2, :) = prctile(diffPercentContraBoot, 97.5, 1);

    diffPercentIpsi = sigPercentIpsi{1} - sigPercentIpsi{2};
    diffPercentIpsiBoot = sigPercentIpsiBoot{1} - sigPercentIpsiBoot{2};
    ciDiffIpsi(1, :) = prctile(diffPercentIpsiBoot, 2.5, 1);
    ciDiffIpsi(2, :) = prctile(diffPercentIpsiBoot, 97.5, 1);

    subplot(2, 2, 2);
    hold on;
    plot(time, diffPercentContra / 100, 'Color', [1, 0, 0], 'LineWidth', 1);
    local_error_shade(time, mean(diffPercentContraBoot, 1) / 100, ciDiffContra(2, :) / 100, ...
        ciDiffContra(1, :) / 100, [1, 0, 0], 0.3);

    plot(time, diffPercentIpsi / 100, 'Color', [0, 0, 1], 'LineWidth', 1);
    local_error_shade(time, mean(diffPercentIpsiBoot, 1) / 100, ciDiffIpsi(2, :) / 100, ...
        ciDiffIpsi(1, :) / 100, [0, 0, 1], 0.3);

    yline(0, '--', 'Color', 'k');
    set(gca, 'Box', 'off', 'TickDir', 'out', 'LineWidth', 1, 'FontSize', 8, 'FontName', 'Arial');
    xlim([-10, 100]);
    ylim([-0.3, 0.3]);
    yticks(-0.3 : 0.15 : 0.3);
    xlabel('Time from stimulus onset (ms)', 'FontSize', 8, 'FontName', 'Arial');
    ylabel('Fraction of units', 'FontSize', 8, 'FontName', 'Arial');
    xticks(-50 : 50 : 150);

    exportgraphics(gg, fullfile(outDir, 'PercentageSigUnit_S1_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMinbootstrapped.pdf'), 'Resolution', 300);
    exportgraphics(gg, fullfile(outDir, 'Fig4B_C - Percentage selective units 5ms bootstrapped.png'), 'Resolution', 300);
    exportgraphics(gg, fullfile(outDir, 'Fig4B_C - Percentage selective units 5ms bootstrapped.pdf'), 'Resolution', 300);
    close(gg);
end

% ========================================================================= %
%  Panel 4D: Onset of Significant Side Selectivity CDF
% ========================================================================= %
function local_plot_fig4d(rocTable5ms, outDir)
    genotypes = {'WT', 'KO'};
    ttColors = {'r', 'b'};
    genoLines = {'-', '--'};
    bin = 0.005;
    timeWindow = [-0.05, 0.15];
    binStart = round((0 - timeWindow(1)) / bin) + 1; % bin 11 (0 ms)
    binEnd = round((0.15 - timeWindow(1)) / bin);   % bin 40 (150 ms)
    significantBins = 3;

    gg = figure('Units', 'inches', 'Position', [1, 1, 2.25, 1.48], 'Visible', 'off');
    clf(gg);
    h2 = gobjects(2, 2);

    statData = struct();

    for g = 1:2
        units = rocTable5ms.(genotypes{g});
        nUnits = numel(units);

        sigOnset = nan(1, nUnits);
        isConPref = false(1, nUnits);
        isIpsiPref = false(1, nUnits);
        isSignificant = false(1, nUnits);

        for u = 1:nUnits
            sigBins = units(u).isSignificant(binStart:binEnd);
            sigRow = sigBins(:)';
            sigRow1 = sigRow;
            sigRow2 = [sigRow(2:end), false];
            sigRow3 = [sigRow(3:end), false, false];
            sigMatrix = [sigRow1; sigRow2; sigRow3];
            threeConsec = (sum(sigMatrix, 1) == significantBins);
            onsetIdx = find(threeConsec, 1);
            isSignificant(u) = ~isempty(onsetIdx);

            if ~isempty(onsetIdx)
                sigOnset(u) = (onsetIdx - 1) * bin * 1000; % in ms
                globalOnset = onsetIdx + binStart - 1;
                meanAuc = mean(units(u).AUC_mean(globalOnset : min(globalOnset + 2, numel(units(u).AUC_mean))));
                isConPref(u) = meanAuc > 0.5;
                isIpsiPref(u) = meanAuc < 0.5;
            end
        end

        statData.isConPref{g} = sigOnset(isConPref);
        statData.isIpsiPref{g} = sigOnset(isIpsiPref);

        h2(g, 1) = cdfplot(sigOnset(isConPref));
        hold on;

        if sum(isIpsiPref) == 0
            h2(g, 2) = yline(0);
        else
            h2(g, 2) = cdfplot(sigOnset(isIpsiPref));
        end

        if g == 1
            lineWidth = 0.5;
        else
            lineWidth = 1;
        end

        set(h2(g, 1), 'Color', ttColors{1}, 'LineStyle', genoLines{g}, 'LineWidth', lineWidth);
        set(h2(g, 2), 'Color', ttColors{2}, 'LineStyle', genoLines{g}, 'LineWidth', lineWidth);
    end

    grid off;
    set(gca, 'Box', 'off', 'TickDir', 'out', 'LineWidth', 1, 'FontName', 'Arial', 'FontSize', 8);
    xlim([0, 40]);
    ylim([-0.05, 1]);
    yticks(0 : 0.2 : 1);
    xlabel('Onset of significant side selectivity (ms)', 'FontName', 'Arial', 'FontSize', 8);
    ylabel('Proportion of units', 'FontName', 'Arial', 'FontSize', 8);
    title('');

    % Statistical tests (Kolmogorov-Smirnov)
    WTc = statData.isConPref{1};
    KOc = statData.isConPref{2};
    KOi = statData.isIpsiPref{2};

    [~, pvalWcKc] = kstest2(WTc, KOc);
    [~, pvalKcKi] = kstest2(KOc, KOi);
    [~, pvalWcKi] = kstest2(WTc, KOi);

    statFile = fullfile(outDir, 'StatisticsSelectivityOnset.txt');
    fid = fopen(statFile, 'w');
    fprintf(fid, 'Contra two-sided ks test WT != KO pval: %g\n', pvalWcKc);
    fprintf(fid, 'KO two-sided ks test contra !=< ipsi pval: %g\n', pvalKcKi);
    fprintf(fid, 'two-sided ks test WT contra != KO ipsi pval: %g\n', pvalWcKi);
    fclose(fid);
    fprintf('Wrote KS statistics -> %s\n', statFile);

    exportgraphics(gg, fullfile(outDir, 'SigOnset_S1_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin.pdf'), 'Resolution', 300);
    exportgraphics(gg, fullfile(outDir, 'Fig4D - Time course of selectivity onset CDF.png'), 'Resolution', 300);
    exportgraphics(gg, fullfile(outDir, 'Fig4D - Time course of selectivity onset CDF.pdf'), 'Resolution', 300);
    close(gg);
end

% ========================================================================= %
%  Panel S5: Distribution of AUC for each 50ms bin bootstrapping (3x3 grid)
% ========================================================================= %
function local_plot_figs5(rocTable50ms, outDir)
    genotypes = {'WT', 'KO'};
    bin = 0.05;
    timeWindow = [-0.05, 0.15];
    binNum = round((timeWindow(2) - timeWindow(1)) / bin);
    nBootTest = 1000;
    shuffleColors = {[0.5, 0, 0.5], [0.5, 0.5, 0.5]};
    stimNames = {'Ipsi', 'Contra'};
    yMax = 65;

    sigPercentConOver = zeros(2, binNum - 1);
    sigPercentIpsiOver = zeros(2, binNum - 1);
    sigPercentCon = cell(1, 2);
    sigPercentIpsi = cell(1, 2);

    isConSig = cell(1, 2);
    isIpsiSig = cell(1, 2);
    N = cell(1, 2);
    for g = 1:2
        units = rocTable50ms.(genotypes{g});
        N{g} = numel(units);
        isConSig{g} = zeros(N{g}, binNum - 1);
        isIpsiSig{g} = zeros(N{g}, binNum - 1);
        for u = 1:N{g}
            for b = 1:binNum - 1
                isConSig{g}(u, b) = units(u).isSignificant(b) & units(u).isConPref(b);
                isIpsiSig{g}(u, b) = units(u).isSignificant(b) & units(u).isIpsiPref(b);
            end
        end
        sigPercentConOver(g, :) = round(sum(isConSig{g}, 1) / N{g} * 100, 1);
        sigPercentIpsiOver(g, :) = round(sum(isIpsiSig{g}, 1) / N{g} * 100, 1);
    end

    rng('default');
    sigPercentCon = cell(1, 2);
    sigPercentIpsi = cell(1, 2);
    sigPercentCon{1} = zeros(nBootTest, binNum - 1);
    sigPercentCon{2} = zeros(nBootTest, binNum - 1);
    sigPercentIpsi{1} = zeros(nBootTest, binNum - 1);
    sigPercentIpsi{2} = zeros(nBootTest, binNum - 1);

    for boot = 1:nBootTest
        for b = 1:binNum - 1
            for g = 1:2
                idx = randi(N{g}, [1, N{g}]);
                sigPercentCon{g}(boot, b) = round(sum(isConSig{g}(idx, b)) / N{g} * 100, 1);
                sigPercentIpsi{g}(boot, b) = round(sum(isIpsiSig{g}(idx, b)) / N{g} * 100, 1);
            end
        end
    end

    statFile = fullfile(outDir, 'Statistics_permutationtest.txt');
    fileID = fopen(statFile, 'w');

    gg = figure('Units', 'inches', 'Position', [1, 1, 5, 4.5], 'Visible', 'off');
    clf(gg);

    % Rows 1 & 2: WT and KO
    for b = 1 : binNum - 1
        timeStart = (b - 1) * bin + timeWindow(1);
        timeEnd = b * bin + timeWindow(1);

        for g = 1:2
            genotype = genotypes{g};
            sigVals{1, 2} = sigPercentConOver(g, b);
            sigVals{2, 2} = sigPercentCon{g}(:, b);
            sigVals{1, 1} = sigPercentIpsiOver(g, b);
            sigVals{2, 1} = sigPercentIpsi{g}(:, b);

            subplot(3, binNum - 1, (binNum - 1) * (g - 1) + b);
            hold on;

            for stim = 1:2
                accuracy = sort(sigVals{2, stim});
                accuracyMean = sigVals{1, stim};
                accuracyUp95 = accuracy(round(0.975 * nBootTest));
                accuracyLow95 = accuracy(round(0.025 * nBootTest));

                errorbar(stim, accuracyMean, (accuracyMean - accuracyLow95), (accuracyUp95 - accuracyMean), 'o', ...
                    'Color', shuffleColors{1}, 'MarkerEdgeColor', shuffleColors{1}, ...
                    'MarkerFaceColor', shuffleColors{1}, 'MarkerSize', 4, 'CapSize', 6, 'LineWidth', 0.5);

                startTimeMs = round(1000 * timeStart);
                endTimeMs = round(1000 * timeEnd);
                fprintf(fileID, 'For S1 %s %s %d ~ %d ms: real CI is %g to %g\n', ...
                    genotype, stimNames{stim}, startTimeMs, endTimeMs, accuracyLow95, accuracyUp95);
            end

            set(gca, 'Box', 'off', 'TickDir', 'out', 'FontSize', 8, 'FontName', 'Arial', 'LineWidth', 1);
            xlim([0.5, 2.5]);
            ylim([-5, yMax]);
            xticks(1:2);
            xticklabels(stimNames);
            ylabel('Percent units', 'FontSize', 8, 'FontName', 'Arial');
            yline(0, '--', 'LineWidth', 1);
            title([num2str(timeStart * 1000) ' ~ ' num2str(timeEnd * 1000) ' ms'], 'FontSize', 8, 'FontName', 'Arial');
        end
    end

    % Row 3: Difference WT - KO
    stimOver = {sigPercentIpsiOver, sigPercentConOver};
    for b = 1 : binNum - 1
        timeStart = (b - 1) * bin + timeWindow(1);
        timeEnd = b * bin + timeWindow(1);

        sigVals{1, 2} = sigPercentCon{1}(:, b) - sigPercentCon{2}(:, b);
        sigVals{1, 1} = sigPercentIpsi{1}(:, b) - sigPercentIpsi{2}(:, b);

        subplot(3, binNum - 1, (binNum - 1) * 2 + b);
        hold on;

        for stim = 1:2
            accuracy = sort(sigVals{1, stim});
            overallDiff = stimOver{stim}(1, b) - stimOver{stim}(2, b);
            accuracyMean = mean(accuracy);
            accuracyUp95 = accuracy(round(0.975 * nBootTest));
            accuracyLow95 = accuracy(round(0.025 * nBootTest));

            errorbar(stim, overallDiff, (accuracyMean - accuracyLow95), (accuracyUp95 - accuracyMean), 'o', ...
                'Color', shuffleColors{1}, 'MarkerEdgeColor', shuffleColors{1}, ...
                'MarkerFaceColor', shuffleColors{1}, 'MarkerSize', 4, 'CapSize', 6, 'LineWidth', 0.5);

            startTimeMs = round(1000 * timeStart);
            endTimeMs = round(1000 * timeEnd);
            fprintf(fileID, 'For S1 WT-KO %s %d ~ %d ms: real CI is %g to %g\n', ...
                stimNames{stim}, startTimeMs, endTimeMs, accuracyLow95, accuracyUp95);
        end

        set(gca, 'Box', 'off', 'TickDir', 'out', 'FontSize', 8, 'FontName', 'Arial', 'LineWidth', 1);
        xlim([0.5, 2.5]);
        ylim([-30, yMax]);
        xticks(1:2);
        xticklabels(stimNames);
        ylabel('\Delta Percent units', 'FontSize', 8, 'FontName', 'Arial');
        yline(0, '--', 'LineWidth', 1);
        title([num2str(timeStart * 1000) ' ~ ' num2str(timeEnd * 1000) ' ms'], 'FontSize', 8, 'FontName', 'Arial');
    end

    fclose(fileID);
    fprintf('Wrote permutation test statistics -> %s\n', statFile);

    local_export_fig(gg, fullfile(outDir, 'ROC_permutation_S1_KO_20Hz_50msBin_-50to150ms_3respMin.pdf'));
    local_export_fig(gg, fullfile(outDir, 'FigS5 - ROC permutation test 50ms.png'));
    local_export_fig(gg, fullfile(outDir, 'FigS5 - ROC permutation test 50ms.pdf'));
    close(gg);
end

function local_export_fig(figHandle, filePath)
    try
        exportgraphics(figHandle, filePath, 'Resolution', 300);
    catch ME
        warning('Could not export to %s: %s', filePath, ME.message);
    end
end

% ========================================================================= %
%  Helper: Shaded Error Region
% ========================================================================= %
function local_error_shade(x, yMean, yUpper, yLower, colorVal, alphaVal)
    valid = ~isnan(x) & ~isnan(yUpper) & ~isnan(yLower);
    xv = x(valid);
    yU = yUpper(valid);
    yL = yLower(valid);
    xPatch = [xv(:)', fliplr(xv(:)')];
    yPatch = [yU(:)', fliplr(yL(:)')];
    fill(xPatch, yPatch, colorVal, 'FaceAlpha', alphaVal, 'EdgeColor', 'none');
end
