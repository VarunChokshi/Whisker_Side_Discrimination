function fig2_optoinhib_nwb(nwbDir, fig2Dir, figs2Dir)
% FIG2_OPTOINHIB_NWB  Optogenetic S1-inhibition panels (Fig2 / FigS2) from NWB.
%
%   fig2_optoinhib_nwb(nwbDir, fig2Dir, figs2Dir)
%
% NWB port of Fig2_behav_optoInhibition.m. For each mouse and inhibition site
% (Left S1 / Right S1) it measures the opto - non-opto change in correct fraction
% and miss fraction plus the raw stimulus amplitude, then refolds Left-S1 / Right-S1
% into contralateral / ipsilateral.
%
% Inputs
%   nwbDir    folder of behavior/opto *.nwb files (dumped from finalBehavSEs)
%   fig2Dir   output folder for the Fig2 delta + amplitude panels and stats
%   figs2Dir  output folder for the FigS2 raw-performance panels and stats
%
% Logic mirrored from Fig2_behav_optoInhibition.m:
%   * drop aborted trials (response==3); keep opto and miss trials; trialMap is NOT
%     applied (the original parses but never uses it);
%   * per mouse x inhSite, pool all trials for the DIRECT per-trial-type fractions
%     (the plotted markers) and the per-session delta means (the binomial stats);
%   * multilevel bootstrap (resample sessions -> trials, nboot=10000, rng(7) reset per
%     mouse) for the error-bar CIs and the amplitude points;
%   * Right-S1 inhibition -> Left stim contralateral, Right ipsilateral; Left-S1 the
%     other way round.
%
% The binomial delta p-values come from the per-session delta means (no bootstrap)
% and reproduce the manuscript exactly; the CIs and amplitude points come from the
% bootstrap (the original used parfor, so those match closely but not bit-for-bit).
%
% Requires matnwb on the path (nwbRead + generated core types) and the Statistics
% Toolbox (binocdf/binopdf/adtest/ranksum/ttest2/ttest).

    % --- constants / output folders ---
    nboot = 10000;
    bootSeed = 7;
    genotypes = {'WT', 'KO'};
    inhSites = {'Right S1', 'Left S1'};   % fieldTable row order the refold relies on
    if ~exist(fig2Dir, 'dir')
        mkdir(fig2Dir);
    end
    if ~exist(figs2Dir, 'dir')
        mkdir(figs2Dir);
    end

    % --- read every opto NWB, keep the valid sessions, concatenate to a struct array ---
    sessFiles = dir(fullfile(nwbDir, '*.nwb'));
    fprintf('Reading %d NWB files from %s ...\n', numel(sessFiles), nwbDir);
    keptSessions = cell(numel(sessFiles), 1);
    nKept = 0;
    for fileInd = 1:numel(sessFiles)
        try
            session = local_read_session(fullfile(sessFiles(fileInd).folder, sessFiles(fileInd).name));
        catch readErr
            fprintf(2, 'ERROR reading %s: %s\n', sessFiles(fileInd).name, readErr.message);
            continue
        end
        % Keep only the two S1 inhibition sites and the two genotypes we plot.
        if ~ismember(session.inhSite, inhSites) || ~ismember(session.genotype, genotypes)
            continue
        end
        nKept = nKept + 1;
        keptSessions{nKept} = session;
        % Periodic progress so a long read does not look stalled.
        if mod(fileInd, 20) == 0
            fprintf('  read %d/%d files\n', fileInd, numel(sessFiles));
        end
    end
    keptSessions = keptSessions(1:nKept);
    if isempty(keptSessions)
        error('No valid opto sessions found in %s', nwbDir);
    end
    sessions = [keptSessions{:}];
    fprintf('loaded %d opto sessions\n', numel(sessions));

    % --- build per (genotype, inhSite, mouse) statistics ---
    % The per-mouse bootstrap (nboot iterations) is the slow part; print one line per
    % mouse so progress is visible.
    fprintf('Bootstrapping per mouse (%d iterations each) ...\n', nboot);
    computeStart = tic;
    groupCells = cell(1, numel(sessions));
    nGroups = 0;
    for genotypeInd = 1:numel(genotypes)
        for siteInd = 1:numel(inhSites)
            genoSiteMask = strcmp({sessions.genotype}, genotypes{genotypeInd}) & ...
                           strcmp({sessions.inhSite}, inhSites{siteInd});
            subSessions = sessions(genoSiteMask);
            animals = unique({subSessions.animal});
            for animalInd = 1:numel(animals)
                mouseSessions = subSessions(strcmp({subSessions.animal}, animals{animalInd}));
                fprintf('  %s / %s / %s (%d sessions) ...\n', genotypes{genotypeInd}, ...
                    inhSites{siteInd}, animals{animalInd}, numel(mouseSessions));
                stats = local_compute_group(mouseSessions, nboot, bootSeed);
                % Assemble the group struct with a fixed field order (so concat works).
                group = struct();
                group.genotype = genotypes{genotypeInd};
                group.inhSite = inhSites{siteInd};
                group.animal = animals{animalInd};
                group.pooledPerf = stats.pooledPerf;
                group.pooledMiss = stats.pooledMiss;
                group.pooledDeltaPerf = stats.pooledDeltaPerf;
                group.pooledDeltaMiss = stats.pooledDeltaMiss;
                group.perSessDeltaPerf = stats.perSessDeltaPerf;
                group.perSessDeltaMiss = stats.perSessDeltaMiss;
                group.ciDeltaPerf = stats.ciDeltaPerf;
                group.ciDeltaMiss = stats.ciDeltaMiss;
                group.ampMean = stats.ampMean;
                nGroups = nGroups + 1;
                groupCells{nGroups} = group;
            end
        end
    end
    groups = [groupCells{1:nGroups}];
    fprintf('Bootstrap done in %.0f s across %d mouse-hemisphere groups\n', toc(computeStart), nGroups);

    % --- plot per genotype and collect the values the stats files need ---
    ampContra = cell(1, 2);
    ampIpsi = cell(1, 2);
    rawPerfContra = cell(1, 2);
    rawPerfIpsi = cell(1, 2);
    rawMissContra = cell(1, 2);
    rawMissIpsi = cell(1, 2);
    for genotypeInd = 1:numel(genotypes)
        genotype = genotypes{genotypeInd};
        mice = local_mice_both(groups, genotype, inhSites);
        fprintf('%s: %d mice with both hemispheres\n', genotype, numel(mice));

        % Fig 2B (delta correct), Fig 2C (delta miss), Fig S2D (amplitude).
        local_plot_delta(groups, genotype, mice, inhSites, 'Perf', ...
            fullfile(fig2Dir, ['Fig2B - Delta correct fraction ' genotype]), ...
            [-0.75 0.35], [-0.6 -0.4 -0.2 0 0.2]);
        local_plot_delta(groups, genotype, mice, inhSites, 'Miss', ...
            fullfile(fig2Dir, ['Fig2C - Delta miss fraction ' genotype]), ...
            [-0.2 0.6], [-0.2 0 0.2 0.4 0.6]);
        [contraAmp, ipsiAmp] = local_plot_amp(groups, genotype, mice, inhSites, ...
            fullfile(fig2Dir, ['FigS2D - Stimulus amplitude ' genotype]));
        ampContra{genotypeInd} = contraAmp;
        ampIpsi{genotypeInd} = ipsiAmp;

        % Fig S2B (WT) / S2C (KO) raw-performance panels; raw miss is a supporting panel.
        if strcmp(genotype, 'WT')
            perfLetter = 'B';
        else
            perfLetter = 'C';
        end
        [contraPerf, ipsiPerf] = local_raw_pairs(groups, genotype, inhSites, 'Perf');
        local_plot_raw(contraPerf, ipsiPerf, 'Correct Fraction', ...
            fullfile(figs2Dir, ['FigS2' perfLetter ' - Mean performance ' genotype]), [0 1], 0.5, 0.7);
        rawPerfContra{genotypeInd} = contraPerf;
        rawPerfIpsi{genotypeInd} = ipsiPerf;
        [contraMiss, ipsiMiss] = local_raw_pairs(groups, genotype, inhSites, 'Miss');
        local_plot_raw(contraMiss, ipsiMiss, 'Miss fraction Fraction', ...
            fullfile(figs2Dir, ['FigS2 - Mean miss performance ' genotype]), [0 0.5], NaN, 0.7);
        rawMissContra{genotypeInd} = contraMiss;
        rawMissIpsi{genotypeInd} = ipsiMiss;
    end

    % --- stats files ---
    local_write_delta_stats(fullfile(fig2Dir, 'Fig2B - Delta correct fraction stats.txt'), ...
        groups, genotypes, inhSites, 'Perf');
    local_write_delta_stats(fullfile(fig2Dir, 'Fig2C - Delta miss fraction stats.txt'), ...
        groups, genotypes, inhSites, 'Miss');
    local_write_amp_stats(fullfile(fig2Dir, 'FigS2D - Stimulus amplitude values.txt'), ...
        genotypes, ampContra, ampIpsi);
    local_write_raw_stats(fullfile(figs2Dir, 'FigS2BC - Mean performance values.txt'), ...
        genotypes, rawPerfContra, rawPerfIpsi, 'Perf');
    local_write_raw_stats(fullfile(figs2Dir, 'FigS2 - Mean miss performance values.txt'), ...
        genotypes, rawMissContra, rawMissIpsi, 'Miss');

    fprintf('Wrote Fig2 panels + stats to %s\n', fig2Dir);
    fprintf('Wrote FigS2 raw panels + stats to %s\n', figs2Dir);
end

% ===================================================================== %
%  per (genotype, inhSite, mouse) statistics
% ===================================================================== %
function stats = local_compute_group(mouseSessions, nboot, bootSeed)
    % Pool all of the mouse's trials for the per-trial-type correct/miss fractions.
    allResult = cat(1, mouseSessions.result);
    allMask = cat(1, mouseSessions.ttMask);
    pooledPerf = zeros(1, 4);
    pooledMiss = zeros(1, 4);
    for tt = 1:4
        pooledPerf(tt) = local_tt_correct(allResult, allMask(:, tt));
        pooledMiss(tt) = local_tt_miss(allResult, allMask(:, tt));
    end
    % Direct pooled opto-minus-nonopto delta (the plotted marker values).
    stats.pooledPerf = pooledPerf;
    stats.pooledMiss = pooledMiss;
    stats.pooledDeltaPerf = [pooledPerf(2) - pooledPerf(1), pooledPerf(4) - pooledPerf(3)];
    stats.pooledDeltaMiss = [pooledMiss(2) - pooledMiss(1), pooledMiss(4) - pooledMiss(3)];

    % Per-session delta means (used by the binomial stats).
    nSessions = numel(mouseSessions);
    sessDeltaPerf = nan(nSessions, 2);
    sessDeltaMiss = nan(nSessions, 2);
    for sessInd = 1:nSessions
        result = mouseSessions(sessInd).result;
        mask = mouseSessions(sessInd).ttMask;
        perf = arrayfun(@(tt) local_tt_correct(result, mask(:, tt)), 1:4);
        miss = arrayfun(@(tt) local_tt_miss(result, mask(:, tt)), 1:4);
        sessDeltaPerf(sessInd, :) = [perf(2) - perf(1), perf(4) - perf(3)];
        sessDeltaMiss(sessInd, :) = [miss(2) - miss(1), miss(4) - miss(3)];
    end
    stats.perSessDeltaPerf = mean(sessDeltaPerf, 1);
    stats.perSessDeltaMiss = mean(sessDeltaMiss, 1);

    % Multilevel bootstrap (rng reset per mouse) of the deltas and the non-opto amplitude.
    rng(bootSeed);
    bootDeltaPerf = nan(nboot, 2);
    bootDeltaMiss = nan(nboot, 2);
    bootAmp = nan(nboot, 2);
    for bootNum = 1:nboot
        randSessions = randi(nSessions, 1, nSessions);
        resampleDeltaPerf = nan(nSessions, 2);
        resampleDeltaMiss = nan(nSessions, 2);
        resampleAmp = nan(nSessions, 2);
        for slot = 1:nSessions
            session = mouseSessions(randSessions(slot));
            nTrials = numel(session.result);
            randTrials = randi(nTrials, 1, nTrials);
            result = session.result(randTrials);
            mask = session.ttMask(randTrials, :);
            ampLeft = session.ampLeft(randTrials);
            ampRight = session.ampRight(randTrials);
            perf1 = local_tt_correct(result, mask(:, 1));
            perf2 = local_tt_correct(result, mask(:, 2));
            perf3 = local_tt_correct(result, mask(:, 3));
            perf4 = local_tt_correct(result, mask(:, 4));
            miss1 = local_tt_miss(result, mask(:, 1));
            miss2 = local_tt_miss(result, mask(:, 2));
            miss3 = local_tt_miss(result, mask(:, 3));
            miss4 = local_tt_miss(result, mask(:, 4));
            resampleDeltaPerf(slot, :) = [perf2 - perf1, perf4 - perf3];
            resampleDeltaMiss(slot, :) = [miss2 - miss1, miss4 - miss3];
            resampleAmp(slot, :) = [local_tt_amp(result, mask(:, 1), ampLeft), ...
                                    local_tt_amp(result, mask(:, 3), ampRight)];
        end
        bootDeltaPerf(bootNum, :) = mean(resampleDeltaPerf, 1);
        bootDeltaMiss(bootNum, :) = mean(resampleDeltaMiss, 1);
        bootAmp(bootNum, :) = mean(resampleAmp, 1);
    end
    % [left; right] CI rows, and the [left, right] mean amplitude point.
    stats.ciDeltaPerf = [local_ci(bootDeltaPerf(:, 1)); local_ci(bootDeltaPerf(:, 2))];
    stats.ciDeltaMiss = [local_ci(bootDeltaMiss(:, 1)); local_ci(bootDeltaMiss(:, 2))];
    stats.ampMean = [mean(bootAmp(:, 1)), mean(bootAmp(:, 2))];
end

function value = local_tt_correct(result, mask)
    % Correct fraction = mean result over the non-miss trials of this trial type.
    nonMiss = mask & ~isnan(result);
    if any(nonMiss)
        value = mean(result(nonMiss));
    else
        value = NaN;
    end
end

function value = local_tt_miss(result, mask)
    % Miss fraction = fraction of this trial type's trials with a NaN result.
    typeResult = result(mask);
    if isempty(typeResult)
        value = NaN;
    else
        value = mean(isnan(typeResult));
    end
end

function value = local_tt_amp(result, mask, ampPerTrial)
    % Mean stimulus amplitude over the non-miss trials of this trial type.
    keep = mask & ~isnan(result);
    if any(keep)
        value = mean(ampPerTrial(keep));
    else
        value = NaN;
    end
end

function ci = local_ci(samples)
    % Percentile CI: [mean, 2.5th percentile, 97.5th percentile] of the bootstrap draws.
    sortedSamples = sort(samples);
    nSamples = numel(samples);
    ci = [mean(samples), sortedSamples(round(nSamples * 0.025)), sortedSamples(round(nSamples * 0.975))];
end

% ===================================================================== %
%  contra / ipsi helpers
% ===================================================================== %
function idx = local_contra_idx(inhSite)
    % Contra stimulus side index into [left, right]: Right-S1 inhibition -> left (1),
    % Left-S1 inhibition -> right (2).
    if strcmp(inhSite, 'Right S1')
        idx = 1;
    else
        idx = 2;
    end
end

function group = local_find_group(groups, genotype, inhSite, animal)
    % Return the group struct for one (genotype, inhSite, animal), or [] if absent.
    match = find(strcmp({groups.genotype}, genotype) & strcmp({groups.inhSite}, inhSite) & ...
                 strcmp({groups.animal}, animal), 1);
    if isempty(match)
        group = [];
    else
        group = groups(match);
    end
end

function mice = local_mice_both(groups, genotype, inhSites)
    % Sorted animals that have data for BOTH inhibition sites in this genotype.
    rightAnimals = {groups(strcmp({groups.genotype}, genotype) & strcmp({groups.inhSite}, inhSites{1})).animal};
    leftAnimals = {groups(strcmp({groups.genotype}, genotype) & strcmp({groups.inhSite}, inhSites{2})).animal};
    mice = sort(intersect(rightAnimals, leftAnimals));
end

% ===================================================================== %
%  delta panels (correct / miss)
% ===================================================================== %
function local_plot_delta(groups, genotype, mice, inhSites, metricName, outBase, yLimits, yTicks)
    % One WT-or-KO delta panel: per mouse, the contra (red) and ipsi (blue) opto effect
    % from both inhibition sites, marker = pooled-direct delta, error bar = bootstrap CI.
    figHandle = figure('Visible', 'off');
    clf
    set(figHandle, 'Units', 'inches', 'Position', [1 1 1.6 1.5]);
    hold on
    startX = 20;
    markers = {'.', 'x'};
    markerSizes = [10, 5];
    pooledField = ['pooledDelta' metricName];
    ciField = ['ciDelta' metricName];
    nMice = numel(mice);
    contraCenters = zeros(1, nMice);
    ipsiCenters = zeros(1, nMice);

    for mouseInd = 1:nMice
        mousePosition = 15 * mouseInd;
        contraXs = startX + mousePosition + [0, 75];
        ipsiXs = startX + 200 + mousePosition + [0, 75];
        contraCenters(mouseInd) = median(contraXs);
        ipsiCenters(mouseInd) = median(ipsiXs);
        for siteInd = 1:numel(inhSites)
            group = local_find_group(groups, genotype, inhSites{siteInd}, mice{mouseInd});
            if isempty(group)
                continue
            end
            contraIdx = local_contra_idx(inhSites{siteInd});
            ipsiIdx = 3 - contraIdx;
            % Contra effect (red) with its bootstrap-CI error bar.
            contraCI = group.(ciField)(contraIdx, :);
            errorbar(contraXs(siteInd), contraCI(1), contraCI(1) - contraCI(2), contraCI(3) - contraCI(1), ...
                'Color', [1 0 0], 'Marker', 'none', 'LineWidth', 1, 'CapSize', 0);
            plot(contraXs(siteInd), group.(pooledField)(contraIdx), 'Marker', markers{siteInd}, ...
                'Color', [1 0 0], 'MarkerSize', markerSizes(siteInd), 'LineWidth', 1);
            % Ipsi effect (blue).
            ipsiCI = group.(ciField)(ipsiIdx, :);
            errorbar(ipsiXs(siteInd), ipsiCI(1), ipsiCI(1) - ipsiCI(2), ipsiCI(3) - ipsiCI(1), ...
                'Color', [0 0 1], 'Marker', 'none', 'LineWidth', 1, 'CapSize', 0);
            plot(ipsiXs(siteInd), group.(pooledField)(ipsiIdx), 'Marker', markers{siteInd}, ...
                'Color', [0 0 1], 'MarkerSize', markerSizes(siteInd), 'LineWidth', 1);
        end
    end
    hold off

    % Axis cosmetics: zero reference line, contra/ipsi ticks, Arial fonts.
    yline(0, '--', 'Color', [0.5 0.5 0.5], 'LineWidth', 1);
    ylim(yLimits);
    yticks(yTicks);
    xlim([0, max(ipsiCenters) + 70]);
    xticks([mean(contraCenters), mean(ipsiCenters)]);
    xticklabels({'Contra stim', 'Ipsi stim'});
    set(gca, 'box', 'off', 'TickDir', 'out', 'FontSize', 8, 'FontName', 'Arial', 'LineWidth', 1);
    exportgraphics(figHandle, [outBase '.png']);
    exportgraphics(figHandle, [outBase '.pdf'], 'Resolution', 1200);
    close(figHandle);
end

function [contraAmps, ipsiAmps] = local_plot_amp(groups, genotype, mice, inhSites, outBase)
    % Per-genotype non-opto amplitude panel (contra vs ipsi), bootstrap-mean points.
    figHandle = figure('Visible', 'off');
    clf
    set(figHandle, 'Units', 'inches', 'Position', [1 1 1.6 1.5]);
    hold on
    startX = 20;
    markers = {'.', 'x'};
    markerSizes = [10, 5];
    nMice = numel(mice);
    contraCenters = zeros(1, nMice);
    ipsiCenters = zeros(1, nMice);
    contraAmps = nan(1, 2 * nMice);
    ipsiAmps = nan(1, 2 * nMice);
    nPoints = 0;

    for mouseInd = 1:nMice
        mousePosition = 15 * mouseInd;
        contraXs = startX + mousePosition + [0, 75];
        ipsiXs = startX + 200 + mousePosition + [0, 75];
        contraCenters(mouseInd) = median(contraXs);
        ipsiCenters(mouseInd) = median(ipsiXs);
        for siteInd = 1:numel(inhSites)
            group = local_find_group(groups, genotype, inhSites{siteInd}, mice{mouseInd});
            if isempty(group)
                continue
            end
            contraIdx = local_contra_idx(inhSites{siteInd});
            ipsiIdx = 3 - contraIdx;
            contraAmp = group.ampMean(contraIdx) / 10;
            ipsiAmp = group.ampMean(ipsiIdx) / 10;
            plot(contraXs(siteInd), contraAmp, 'Marker', markers{siteInd}, 'Color', [1 0 0], ...
                'MarkerSize', markerSizes(siteInd), 'LineWidth', 1);
            plot(ipsiXs(siteInd), ipsiAmp, 'Marker', markers{siteInd}, 'Color', [0 0 1], ...
                'MarkerSize', markerSizes(siteInd), 'LineWidth', 1);
            nPoints = nPoints + 1;
            contraAmps(nPoints) = contraAmp;
            ipsiAmps(nPoints) = ipsiAmp;
        end
    end
    hold off
    contraAmps = contraAmps(1:nPoints);
    ipsiAmps = ipsiAmps(1:nPoints);

    ylim([0 110]);
    yticks(0:25:100);
    ylabel('Amplitude (% of max.)', 'FontSize', 8, 'FontName', 'Arial');
    xlim([0, max(ipsiCenters) + 70]);
    xticks([mean(contraCenters), mean(ipsiCenters)]);
    xticklabels({'Contra stim', 'Ipsi stim'});
    set(gca, 'box', 'off', 'TickDir', 'out', 'FontSize', 8, 'FontName', 'Arial', 'LineWidth', 1);
    exportgraphics(figHandle, [outBase '.png']);
    exportgraphics(figHandle, [outBase '.pdf'], 'Resolution', 300);
    close(figHandle);
end

% ===================================================================== %
%  FigS2 raw-performance panels
% ===================================================================== %
function [contra, ipsi] = local_raw_pairs(groups, genotype, inhSites, metricName)
    % Per-mouse [non-opto, opto] pairs for the contra and ipsi stimulus, stacked over
    % both inhibition sites. Returns (nMice*2 x 2) matrices.
    pooledField = ['pooled' metricName];
    maxRows = numel(groups);
    contra = nan(maxRows, 2);
    ipsi = nan(maxRows, 2);
    nRows = 0;
    for siteInd = 1:numel(inhSites)
        siteMatch = find(strcmp({groups.genotype}, genotype) & strcmp({groups.inhSite}, inhSites{siteInd}));
        [~, order] = sort({groups(siteMatch).animal});
        siteMatch = siteMatch(order);
        contraIdx = local_contra_idx(inhSites{siteInd});
        if contraIdx == 1
            contraCols = [1 2];
            ipsiCols = [3 4];
        else
            contraCols = [3 4];
            ipsiCols = [1 2];
        end
        for k = 1:numel(siteMatch)
            pooled = groups(siteMatch(k)).(pooledField);
            nRows = nRows + 1;
            contra(nRows, :) = pooled(contraCols);
            ipsi(nRows, :) = pooled(ipsiCols);
        end
    end
    contra = contra(1:nRows, :);
    ipsi = ipsi(1:nRows, :);
end

function local_plot_raw(contra, ipsi, yLabelStr, outBase, yLimits, contraYLine, ipsiYLine)
    % FigS2 raw-performance figure: two subplots (contra | ipsi), a per-mouse line from
    % Stim to Stim+opto plus the group mean line.
    figHandle = figure('Visible', 'off');
    clf
    set(figHandle, 'Units', 'inches', 'Position', [1 1 3 2]);
    panelData = {contra, ipsi};
    panelColors = {[1 0 0], [0 0 1]};
    panelTitles = {'Contra stim', 'Ipsi stim'};
    panelYLines = [contraYLine, ipsiYLine];
    for panelInd = 1:2
        ax = subplot(1, 2, panelInd);
        hold(ax, 'on')
        data = panelData{panelInd};
        color = panelColors{panelInd};
        % One faint line per mouse, then the bold mean line.
        for row = 1:size(data, 1)
            plot(ax, [0.75 1.25], data(row, :), '-', 'Color', [color 0.3], 'LineWidth', 1);
        end
        plot(ax, [0.75 1.25], mean(data, 1), '-', 'Color', [color 1], 'LineWidth', 1);
        if ~isnan(panelYLines(panelInd))
            yline(ax, panelYLines(panelInd), '--', 'Color', [0 0 0], 'LineWidth', 1);
        end
        xlim(ax, [0.5 1.5]);
        ylim(ax, yLimits);
        xticks(ax, [0.75 1.25]);
        xticklabels(ax, {'Stim', 'Stim + opto'});
        title(ax, panelTitles{panelInd}, 'FontSize', 8, 'FontName', 'Arial', 'FontWeight', 'normal', 'Color', color);
        set(ax, 'box', 'off', 'TickDir', 'out', 'FontSize', 8, 'FontName', 'Arial', 'LineWidth', 1);
        if panelInd == 1
            ylabel(ax, yLabelStr, 'FontSize', 8, 'FontName', 'Arial');
        end
    end
    exportgraphics(figHandle, [outBase '.png']);
    exportgraphics(figHandle, [outBase '.pdf'], 'Resolution', 1200);
    close(figHandle);
end

% ===================================================================== %
%  stats files
% ===================================================================== %
function [contraByGeno, ipsiByGeno] = local_delta_means(groups, genotypes, inhSites, metricName)
    % Per-genotype vectors of the per-mouse per-session delta means, folded to
    % contra / ipsi across both inhibition sites.
    perSessField = ['perSessDelta' metricName];
    contraByGeno = cell(1, numel(genotypes));
    ipsiByGeno = cell(1, numel(genotypes));
    for genotypeInd = 1:numel(genotypes)
        contraVals = nan(1, numel(groups));
        ipsiVals = nan(1, numel(groups));
        nVals = 0;
        for siteInd = 1:numel(inhSites)
            siteMatch = find(strcmp({groups.genotype}, genotypes{genotypeInd}) & ...
                             strcmp({groups.inhSite}, inhSites{siteInd}));
            [~, order] = sort({groups(siteMatch).animal});
            siteMatch = siteMatch(order);
            contraIdx = local_contra_idx(inhSites{siteInd});
            ipsiIdx = 3 - contraIdx;
            for k = 1:numel(siteMatch)
                nVals = nVals + 1;
                contraVals(nVals) = groups(siteMatch(k)).(perSessField)(contraIdx);
                ipsiVals(nVals) = groups(siteMatch(k)).(perSessField)(ipsiIdx);
            end
        end
        contraByGeno{genotypeInd} = contraVals(1:nVals);
        ipsiByGeno{genotypeInd} = ipsiVals(1:nVals);
    end
end

function local_write_delta_stats(outPath, groups, genotypes, inhSites, metricName)
    % Reproduce 'Fig2 OptoInhibition Stats delta {correct|miss} fraction.txt'.
    [contraByGeno, ipsiByGeno] = local_delta_means(groups, genotypes, inhSites, metricName);
    fid = fopen(outPath, 'w');
    fprintf(fid, 'Pvals using binomial tests:\n');
    for genotypeInd = 1:numel(genotypes)
        contra = contraByGeno{genotypeInd};
        ipsi = ipsiByGeno{genotypeInd};
        % Contra success = impaired (perf delta < 0) or more misses (miss delta > 0).
        if strcmp(metricName, 'Perf')
            contraSuccesses = numel(find(contra < 0));
        else
            contraSuccesses = numel(find(contra > 0));
        end
        ipsiSuccesses = numel(find(ipsi > 0));
        contraBinoCdf = 1 - binocdf(contraSuccesses - 1, numel(contra), 0.5);
        contraBinoPdf = binopdf(contraSuccesses, numel(contra), 0.5);
        ipsiBinoCdf = 1 - binocdf(ipsiSuccesses - 1, numel(ipsi), 0.5);
        ipsiBinoPdf = binopdf(ipsiSuccesses, numel(ipsi), 0.5);
        fprintf(fid, 'For genotype %s using binocdf contra is %s using binopdf contra is %s\n', ...
            genotypes{genotypeInd}, num2str(contraBinoCdf), num2str(contraBinoPdf));
        fprintf(fid, 'For genotype %s using binocdf ipsi is %s using binopdf ipsi is %s\n', ...
            genotypes{genotypeInd}, num2str(ipsiBinoCdf), num2str(ipsiBinoPdf));
    end

    % Between-genotype comparison: adtest on all four groups decides the test.
    normalityRejects = [adtest(contraByGeno{1}), adtest(contraByGeno{2}), ...
                        adtest(ipsiByGeno{1}), adtest(ipsiByGeno{2})];
    if all(normalityRejects)
        [~, contraP] = ttest2(contraByGeno{1}, contraByGeno{2});
        [~, ipsiP] = ttest2(ipsiByGeno{1}, ipsiByGeno{2});
        testName = 'ttest2';
    else
        contraP = ranksum(contraByGeno{1}, contraByGeno{2});
        ipsiP = ranksum(ipsiByGeno{1}, ipsiByGeno{2});
        testName = 'Mann Whitney U';
    end
    fprintf(fid, 'Between genotypes contra effect comparison using %s is %s\n', testName, num2str(contraP));
    fprintf(fid, 'Between genotypes ipsi effect comparison using %s is %s\n', testName, num2str(ipsiP));
    fclose(fid);
end

function local_write_amp_stats(outPath, genotypes, ampContra, ampIpsi)
    % Reproduce 'OptobehavMeanAmplitudedatavalues.txt'.
    fid = fopen(outPath, 'w');
    stimNames = {'Contra', 'Ipsi'};
    for genotypeInd = 1:numel(genotypes)
        stimValues = {ampContra{genotypeInd}, ampIpsi{genotypeInd}};
        for stimInd = 1:2
            fprintf(fid, 'For genotype: %s %s mean: %s sd: %s\n', genotypes{genotypeInd}, ...
                stimNames{stimInd}, num2str(mean(stimValues{stimInd})), num2str(std(stimValues{stimInd})));
        end
    end
    contraP = ranksum(ampContra{1}, ampContra{2});
    ipsiP = ranksum(ampIpsi{1}, ampIpsi{2});
    fprintf(fid, 'Between genotype Mann whitney U test comparison for contra p-value  %s\n', num2str(contraP));
    fprintf(fid, 'Between genotype Mann whitney U test comparison for ipsi p-value  %s\n', num2str(ipsiP));
    fclose(fid);
end

function local_write_raw_stats(outPath, genotypes, contraByGeno, ipsiByGeno, metricName)
    % Reproduce the FigS2 raw-performance stats files (OptobehavMean{Corerct|Miss}...).
    fid = fopen(outPath, 'w');
    for genotypeInd = 1:numel(genotypes)
        contra = contraByGeno{genotypeInd};
        ipsi = ipsiByGeno{genotypeInd};
        if strcmp(metricName, 'Perf')
            fprintf(fid, 'For genotype: %s Mean contra is %s std: %s\n', genotypes{genotypeInd}, ...
                num2str(mean(contra, 1)), num2str(std(contra)));
            fprintf(fid, 'For genotype: %s Mean ipsi is %s std: %s\n', genotypes{genotypeInd}, ...
                num2str(mean(ipsi, 1)), num2str(std(ipsi)));
        else
            fprintf(fid, 'For genotype: %s Mean contra is %s\n', genotypes{genotypeInd}, num2str(mean(contra, 1)));
            fprintf(fid, 'For genotype: %s Mean ipsi is %s\n', genotypes{genotypeInd}, num2str(mean(ipsi, 1)));
        end
    end

    % Between-genotype ttest2 on the opto (after-effect) column (and baseline for perf).
    % The correct-fraction file prefixes these lines differently from the miss file.
    if strcmp(metricName, 'Perf')
        afterPrefix = 'Between genotype comparison for';
    else
        afterPrefix = 'For';
    end
    [~, contraAfter] = ttest2(contraByGeno{1}(:, 2), contraByGeno{2}(:, 2));
    [~, ipsiAfter] = ttest2(ipsiByGeno{1}(:, 2), ipsiByGeno{2}(:, 2));
    fprintf(fid, '%s contra p-value for after effect is %s\n', afterPrefix, num2str(contraAfter));
    fprintf(fid, '%s ipsi p-value for after effect is %s\n', afterPrefix, num2str(ipsiAfter));
    if strcmp(metricName, 'Perf')
        [~, contraBase] = ttest2(contraByGeno{1}(:, 1), contraByGeno{2}(:, 1));
        [~, ipsiBase] = ttest2(ipsiByGeno{1}(:, 1), ipsiByGeno{2}(:, 1));
        fprintf(fid, 'Between genotype comparison for contra p-value for baseline is %s\n', num2str(contraBase));
        fprintf(fid, 'Between genotype comparison for ipsi p-value for baseline is %s\n', num2str(ipsiBase));
    end

    % Within-genotype paired ttest (Stim vs Stim+opto).
    for genotypeInd = 1:numel(genotypes)
        [~, contraPaired] = ttest(contraByGeno{genotypeInd}(:, 1), contraByGeno{genotypeInd}(:, 2));
        [~, ipsiPaired] = ttest(ipsiByGeno{genotypeInd}(:, 1), ipsiByGeno{genotypeInd}(:, 2));
        fprintf(fid, 'For genotype %s paired ttest comparison for contra p-value for after effect is %s\n', ...
            genotypes{genotypeInd}, num2str(contraPaired));
        fprintf(fid, 'For genotype %s paired ttest comparison for ipsi p-value for after effect is %s\n', ...
            genotypes{genotypeInd}, num2str(ipsiPaired));
    end
    fclose(fid);
end

% ===================================================================== %
%  read one opto NWB session
% ===================================================================== %
function session = local_read_session(nwbPath)
    % Read one opto NWB session: drop aborts, keep opto and miss trials, and return the
    % per-trial arrays plus animal / genotype / inhSite. trialMap is not applied.
    % restoreWarning must stay in scope for the onCleanup callback to fire.
    warnState = warning('off', 'NWB:Read:AttemptReadWithVersionMismatch');
    restoreWarning = onCleanup(@() warning(warnState));
    nwb = nwbRead(nwbPath, 'ignorecache');

    session.animal = upper(strtrim(local_char(local_scalar(nwb.general_subject.subject_id))));
    session.genotype = upper(strtrim(local_char(local_scalar(nwb.general_subject.genotype))));

    trials = nwb.intervals_trials;
    trialType = local_cellstr(local_col(trials, 'trialType'));
    result = local_double(local_col(trials, 'result'));
    response = local_double(local_col(trials, 'response'));
    leftStimType = local_cellstr(local_col(trials, 'leftStimType'));
    rightStimType = local_cellstr(local_col(trials, 'rightStimType'));

    % Inhibition site from the first trial's inhSite (constant per session);
    % fall back to session_info if the column is absent.
    inhSiteCol = local_cellstr(local_col(trials, 'inhSite'));
    if ~isempty(inhSiteCol)
        session.inhSite = strtrim(local_char(inhSiteCol{1}));
    else
        session.inhSite = strtrim(local_sifield(local_session_info(nwb), 'inhSite'));
    end

    % Drop aborted trials (response == 3).
    notAbort = response ~= 3;
    trialType = trialType(notAbort);
    result = result(notAbort);
    leftStimType = leftStimType(notAbort);
    rightStimType = rightStimType(notAbort);

    % Boolean mask per trial type (columns 1..4).
    trialTypeNames = {'Stim_Som_Left', 'Stim_Som_Left_Opto', 'Stim_Som_Right', 'Stim_Som_Right_Opto'};
    nTrials = numel(trialType);
    ttMask = false(nTrials, 4);
    for tt = 1:4
        ttMask(:, tt) = strcmp(trialType, trialTypeNames{tt});
    end

    session.result = result(:);
    session.ttMask = ttMask;
    ampLeft = cellfun(@local_amp, leftStimType);
    session.ampLeft = ampLeft(:);
    ampRight = cellfun(@local_amp, rightStimType);
    session.ampRight = ampRight(:);
end

function amp = local_amp(stim)
    % Stimulus amplitude from a stim string: the digits after the 'm' marker, with 0
    % (or no readable value) coded as 1000. NaN when there is no 'm' marker.
    stimStr = local_char(stim);
    mInd = strfind(stimStr, 'm');
    if isempty(mInd)
        amp = NaN;
        return
    end
    mInd = mInd(1);
    ampSegment = stimStr(min(mInd + 4, numel(stimStr) + 1):min(mInd + 6, numel(stimStr)));
    amp = str2double(regexp(ampSegment, '\d+', 'match', 'once'));
    if isnan(amp) || amp == 0
        amp = 1000;
    end
end

% ===================================================================== %
%  matnwb access helpers
% ===================================================================== %
function value = local_scalar(dataField)
    % matnwb stores data lazily as a DataStub; load it into memory when needed.
    if isa(dataField, 'types.untyped.DataStub')
        value = dataField.load();
    else
        value = dataField;
    end
end

function charOut = local_char(value)
    % Coerce a cell / string / char / other value to a plain char row vector.
    if iscell(value)
        if isempty(value)
            charOut = '';
        else
            charOut = char(value{1});
        end
    elseif isstring(value)
        charOut = char(value);
    elseif ischar(value)
        charOut = value;
    else
        charOut = char(string(value));
    end
end

function columnData = local_col(trials, name)
    % A trials column lives either as a direct property or inside the vectordata map.
    if isprop(trials, name) && ~isempty(trials.(name))
        vecData = trials.(name);
    elseif ~isempty(trials.vectordata) && trials.vectordata.isKey(name)
        vecData = trials.vectordata.get(name);
    else
        columnData = [];
        return
    end
    columnData = local_scalar(vecData.data);
end

function strings = local_cellstr(columnData)
    % Coerce a trials column to a column cellstr.
    if isempty(columnData)
        strings = {};
    elseif ischar(columnData)
        strings = cellstr(columnData);
    elseif isstring(columnData)
        strings = cellstr(columnData);
    elseif iscell(columnData)
        strings = columnData;
    else
        strings = cellstr(string(columnData));
    end
    strings = strings(:);
end

function values = local_double(columnData)
    % Coerce a trials column to a column double vector.
    if iscell(columnData)
        values = cellfun(@double, columnData);
    else
        values = double(columnData);
    end
    values = values(:);
end

function sessInfo = local_session_info(nwb)
    % The one-row session_info table lives in processing('metadata'); return [] if absent.
    sessInfo = [];
    try
        if isempty(nwb.processing) || ~nwb.processing.isKey('metadata')
            return
        end
        procModule = nwb.processing.get('metadata');
        if ~isempty(procModule.dynamictable) && procModule.dynamictable.isKey('session_info')
            sessInfo = procModule.dynamictable.get('session_info');
        end
    catch
        % Leave sessInfo empty if the metadata module cannot be read.
    end
end

function val = local_sifield(sessInfo, name)
    % Read one scalar field from the session_info table as char ('' if missing).
    val = '';
    if isempty(sessInfo) || isempty(sessInfo.vectordata) || ~sessInfo.vectordata.isKey(name)
        return
    end
    val = local_char(local_scalar(sessInfo.vectordata.get(name).data));
end
