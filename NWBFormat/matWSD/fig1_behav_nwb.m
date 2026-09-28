function fig1_behav_nwb(nwbDir, outDir, includeAll)
% FIG1_BEHAV_NWB  Expert-performance panels (Fig1 / FigS1) from behavioral NWB.
%
%   fig1_behav_nwb(nwbDir, outDir)
%   fig1_behav_nwb(nwbDir, outDir, includeAll)   % includeAll=true keeps every animal
%
% NWB port of fig1_behav.m: for the expert (NoOptoSess) sessions, produce the
% WT-vs-KO panels for correct fraction, miss fraction, and stimulus amplitude,
% for overall / left-stim / right-stim trials, per mouse.
%
% Logic mirrored from fig1_behav.m:
%   * apply each session's trialMap as a union of colon-separated start:stop ranges
%     (so "1:240:260:end'" keeps trials 1-240 AND 260-end);
%   * drop aborts (response==3); drop opto trials (trialType contains 'Opto');
%   * keep bodyside6; drop sessions whose seshDate is empty (their SessInfoNoOpto
%     row failed to date-match, as fig1_behav.m drops them); exclude the four pilot
%     animals VC030103/104/201/202 (the manuscript cohort is 10 WT + 8 KO);
%   * overall uses all (non-opto) trials; left/right use the cue type
%     (Stim_Som_Left/Right), NoCue only as a fallback when a session has no cue;
%   * per mouse: DIRECT pooled means (plotted points + Fig1behavMeanvals.txt) and a
%     multilevel bootstrap (resample sessions -> trials, nboot=1000, rng(7)) for the
%     error-bar CIs and the amplitude point.
%
% Correct/miss means, SDs and Mann-Whitney p-values reproduce the manuscript
% exactly; amplitude + error bars come from the bootstrap (rng(7); the original
% used parfor, so those match closely but not bit-for-bit).
%
% Requires matnwb on the path (nwbRead + generated core types).

    % --- arguments / output folder ---
    if nargin < 2 || isempty(outDir)
        outDir = pwd;
    end
    if nargin < 3 || isempty(includeAll)
        includeAll = false;
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    nboot = 1000;
    excludeAnimals = {'VC030103', 'VC030104', 'VC030201', 'VC030202'};   % pilot cohort

    % --- load every expert NWB, keep the cohort's bodyside6 sessions, group by mouse ---
    sessFiles = dir(fullfile(nwbDir, '*.nwb'));
    nSessFiles = numel(sessFiles);
    keptSessions = cell(nSessFiles, 1);
    nKept = 0;
    for fileInd = 1:nSessFiles
        try
            [session, taskName] = local_read_session(fullfile(sessFiles(fileInd).folder, sessFiles(fileInd).name));
        catch readErr
            fprintf(2, 'ERROR reading %s: %s\n', sessFiles(fileInd).name, readErr.message);
            continue
        end
        % Keep only bodyside6 sessions that still have trials.
        if ~strcmp(taskName, 'bodyside6') || isempty(session.result)
            continue
        end
        % Drop sessions whose CSV date-match failed (empty seshDate).
        if isempty(session.seshDate)
            continue
        end
        % Drop the pilot cohort unless includeAll was requested.
        if ~includeAll && any(strcmp(session.animal, excludeAnimals))
            continue
        end
        nKept = nKept + 1;
        keptSessions{nKept} = session;
    end
    keptSessions = keptSessions(1:nKept);

    % Concatenate the kept sessions into one struct array (all share the same fields).
    if isempty(keptSessions)
        sessions = struct('animal', {}, 'genotype', {}, 'seshDate', {}, 'result', {}, ...
            'trialType', {}, 'isLeft', {}, 'isRight', {}, 'ampLeft', {}, 'ampRight', {});
    else
        sessions = [keptSessions{:}];
    end
    animalIDs = unique({sessions.animal});
    fprintf('loaded %d bodyside6 expert sessions across %d mice\n', numel(sessions), numel(animalIDs));

    % --- per-mouse direct metrics + bootstrap (one RNG stream, seeded once) ---
    rng(7);
    results = repmat(struct('animal', '', 'genotype', '', 'correct', [], ...
        'ciCorrect', [], 'miss', [], 'ciMiss', [], 'amp', []), 1, numel(animalIDs));
    for animalNum = 1:numel(animalIDs)
        mouseSessions = sessions(strcmp({sessions.animal}, animalIDs{animalNum}));
        [correct, miss] = local_direct(mouseSessions);
        [ciCorrect, ciMiss, ampLeftRight] = local_boot(mouseSessions, nboot);
        results(animalNum).animal = animalIDs{animalNum};
        results(animalNum).genotype = mouseSessions(1).genotype;
        results(animalNum).correct = correct;
        results(animalNum).ciCorrect = ciCorrect;
        results(animalNum).miss = miss;
        results(animalNum).ciMiss = ciMiss;
        results(animalNum).amp = ampLeftRight;
    end

    % Split into genotype groups (KO is everything that is not WT).
    wt = results(strcmp({results.genotype}, 'WT'));
    ko = results(~strcmp({results.genotype}, 'WT'));
    fprintf('WT mice (%d): %s\n', numel(wt), strjoin({wt.animal}, ', '));
    fprintf('KO mice (%d): %s\n', numel(ko), strjoin({ko.animal}, ', '));

    % --- plot the 8 panels and write the stats file ---
    statsFileId = fopen(fullfile(outDir, 'Fig1D - behavior mean values.txt'), 'w');
    plotTypes = {'stats_overall', '_left', '_right'};
    % Correct fraction: overall (Fig 1D), left / right (Fig S1B).
    correctNames = {'Fig1D - Fraction correct', ...
        'FigS1B - Fraction correct (left)', 'FigS1B - Fraction correct (right)'};
    for field = 1:3
        local_panel(statsFileId, wt, ko, 10, 8, 'correct', field, plotTypes{field}, ...
            'Correct fraction excl. misses', [0.4 1], 0.7, ...
            fullfile(outDir, correctNames{field}));
    end
    % Miss fraction: overall (Fig 1D), left / right (Fig S1C).
    missNames = {'Fig1D - Fraction miss', ...
        'FigS1C - Fraction miss (left)', 'FigS1C - Fraction miss (right)'};
    for field = 1:3
        local_panel(statsFileId, wt, ko, 10, 8, 'miss', field, plotTypes{field}, ...
            'Miss fraction', [0 0.5], [], ...
            fullfile(outDir, missNames{field}));
    end
    % Amplitude: left, right (Fig S1A; 9 WT + 7 KO, matching the published panels).
    ampPlotTypes = {'Left Stim trials', 'Right Stim trials'};
    ampNames = {'FigS1A - Mean stimulus amplitude (left)', 'FigS1A - Mean stimulus amplitude (right)'};
    for field = 1:2
        local_panel(statsFileId, wt, ko, 9, 7, 'amp', field, ampPlotTypes{field}, ...
            'Amplitude (% of maximum)', [0 110], [], ...
            fullfile(outDir, ampNames{field}));
    end
    fclose(statsFileId);
    fprintf('Wrote 8 panels + Fig1D - behavior mean values.txt to %s\n', outDir);
end

% ===================================================================== %
function local_panel(statsFileId, wt, ko, nWT, nKO, plotKind, field, plotType, yLabel, yLimits, yLineValue, outBase)
    % One WT-vs-KO panel matching the exact styling and sizing of fig1_behav.m:
    % 3.3 x 3.8 cm figure, per-mouse scatter circles with alpha transparency,
    % bootstrap error bars with matching alpha, purple/black genotype mean +/- SD,
    % and Mann-Whitney U stats output.
    figHandle = figure('Visible', 'off');
    clf
    set(figHandle, 'Units', 'centimeters', 'Position', [50, 50, 33, 38] / 10);
    subplot(1, 1, 1);
    hold on

    startX = 20;
    step = 15;
    
    % Styling parameters matching fig1_behav.m
    if strcmp(plotKind, 'amp')
        alphaVal = 1.0;
        ampColors = {[1 0 0], [0 0 1]};
    else
        alphaVal = 0.8;
        genotypeColors{1} = {[0.5 0.5 0.5], [1 0 0], [0 0 1]};   % WT: gray (overall), red (left), blue (right)
        genotypeColors{2} = {[0 0 0], [1 0 0], [0 0 1]};         % KO: black (overall), red (left), blue (right)
    end

    genotypeGroups = {wt(1:min(nWT, numel(wt))), ko(1:min(nKO, numel(ko)))};
    animalMeans = cell(1, 2);
    lastX = 0;

    for groupNum = 1:2
        % Determine color for this genotype and field
        if strcmp(plotKind, 'amp')
            plotColor = ampColors{field};
        else
            plotColor = genotypeColors{groupNum}{field};
        end

        % X positions for this genotype's mice (WT on the left, KO shifted right)
        group = genotypeGroups{groupNum};
        nMice = numel(group);
        x = (startX + (groupNum - 1) * 250) + step * (1:nMice);
        lastX = max(lastX, max(x));

        if strcmp(plotKind, 'amp')
            % Amplitude: per-mouse bootstrap-mean amplitude as % of maximum
            animalVals = arrayfun(@(r) r.amp(field) / 10, group);
            scatter(x, animalVals, 10, 'o', 'Color', plotColor, 'MarkerEdgeColor', plotColor, ...
                'LineWidth', 1, 'MarkerFaceAlpha', alphaVal, 'MarkerEdgeAlpha', alphaVal);
            errorbar(x(end) + 25, mean(animalVals), std(animalVals), '.', 'MarkerSize', 15, ...
                'LineWidth', 1, 'Color', [0 0 0], 'CapSize', 0);
        else
            % Correct/miss: per-mouse direct mean, with bootstrap CI as error bars
            if strcmp(plotKind, 'correct')
                confInt = arrayfun(@(r) r.ciCorrect(field, :), group, 'Uni', false);
                animalVals = arrayfun(@(r) r.correct(field), group);
            else
                confInt = arrayfun(@(r) r.ciMiss(field, :), group, 'Uni', false);
                animalVals = arrayfun(@(r) r.miss(field), group);
            end
            confInt = cell2mat(confInt(:));

            % Error bar with transparency and no marker
            hh = errorbar(x, confInt(:, 1)', confInt(:, 1)' - confInt(:, 2)', confInt(:, 3)' - confInt(:, 1)', ...
                'o', 'MarkerSize', 10, 'Color', plotColor, 'MarkerEdgeColor', plotColor, ...
                'LineWidth', 1, 'CapSize', 0);
            set(hh, 'Marker', 'none');
            set([hh.Bar, hh.Line], 'ColorType', 'truecoloralpha', ...
                'ColorData', [hh.Line.ColorData(1:3); uint8(255 * alphaVal)]);

            % Individual animal scatter circle with alpha
            scatter(x, animalVals, 10, 'o', 'Color', plotColor, 'MarkerEdgeColor', plotColor, ...
                'LineWidth', 1, 'MarkerFaceAlpha', alphaVal, 'MarkerEdgeAlpha', alphaVal);

            % Overall panel uses purple summary marker [0.5 0 0.5]; left/right use black
            if field == 1
                summaryColor = [0.5 0 0.5];
            else
                summaryColor = [0 0 0];
            end
            errorbar(x(end) + 25, mean(animalVals), std(animalVals), 'both', '.', 'MarkerSize', 15, ...
                'LineWidth', 1, 'Color', summaryColor, 'CapSize', 0);
        end

        animalMeans{groupNum} = animalVals;
        % Record this genotype's mean / SD for this panel
        fprintf(statsFileId, 'For genotype: %s %s Mean: %s SD: %s\n', ...
            group(1).genotype, plotType, num2str(mean(animalVals)), num2str(std(animalVals)));
    end

    % WT-vs-KO rank-sum (Mann-Whitney U) p-value on the per-mouse values
    fprintf(statsFileId, 'For plotType: %s %s Mann Whitney U pval: %s\n', ...
        local_label(plotKind), plotType, num2str(ranksum(animalMeans{1}, animalMeans{2})));
    hold off

    % Axis cosmetics matching fig1_behav.m
    ax = gca;
    ax.LineWidth = 1;
    set(ax, 'box', 'off', 'TickDir', 'out', 'FontSize', 8, 'FontName', 'Arial');
    ylim(yLimits);
    if strcmp(plotKind, 'correct')
        yticks([0, 0.1:0.2:0.9, 1]);
    elseif strcmp(plotKind, 'miss')
        yticks([0, 0.1:0.2:0.9, 1]);
    elseif strcmp(plotKind, 'amp')
        yticks(0:20:100);
    end

    if ~isempty(yLineValue)
        yline(yLineValue, '--k', 'Color', [112 41 99] / 255, 'LineWidth', 1);
    end
    ylabel(yLabel, 'FontSize', 8, 'FontName', 'Arial');
    xlim([0, lastX + 40]);
    xticks([startX + 75, startX + 325]);
    xticklabels({'WT', 'KO'});

    exportgraphics(figHandle, [outBase '.png']);
    exportgraphics(figHandle, [outBase '.pdf'], 'Resolution', 300);
    close(figHandle);
end

function labelStr = local_label(plotKind)
    % Human-readable plot-kind label for the stats file.
    switch plotKind
        case 'correct'
            labelStr = 'Correct fraction';
        case 'miss'
            labelStr = 'Miss fraction';
        case 'amp'
            labelStr = 'Amplitude';
    end
end

% ===================================================================== %
function [correct, miss] = local_direct(mouseSessions)
    % Direct pooled per-mouse metrics: pool all trials, then compute the
    % [overall, left, right] correct and miss fractions.
    result = cat(1, mouseSessions.result);
    trialType = cat(1, mouseSessions.trialType);
    isLeft = local_sidemask(trialType, 'Stim_Som_Left', 'Stim_Som_Left_NoCue');
    isRight = local_sidemask(trialType, 'Stim_Som_Right', 'Stim_Som_Right_NoCue');
    correct = [local_frac_correct(result), local_frac_correct(result(isLeft)), local_frac_correct(result(isRight))];
    miss = [local_frac_miss(result), local_frac_miss(result(isLeft)), local_frac_miss(result(isRight))];
end

function [ciCorrect, ciMiss, ampLeftRight] = local_boot(mouseSessions, nboot)
    % Multilevel bootstrap: for each of nboot resamples, resample sessions with
    % replacement and then trials within each drawn session, and average across the
    % resampled sessions. Returns the [overall; left; right] CI rows for correct and
    % miss, and the [left, right] mean amplitude point.
    nSessions = numel(mouseSessions);

    % Preallocate the per-resample bootstrap draws for each quantity.
    bootOverallPerf = nan(nboot, 1);
    bootOverallMiss = nan(nboot, 1);
    bootLeftPerf = nan(nboot, 1);
    bootRightPerf = nan(nboot, 1);
    bootLeftMiss = nan(nboot, 1);
    bootRightMiss = nan(nboot, 1);
    bootLeftAmp = nan(nboot, 1);
    bootRightAmp = nan(nboot, 1);

    for bootNum = 1:nboot
        % Resample sessions with replacement.
        randSessions = randi(nSessions, 1, nSessions);
        sessOverallPerf = nan(nSessions, 1);
        sessOverallMiss = nan(nSessions, 1);
        sessLeftPerf = nan(nSessions, 1);
        sessRightPerf = nan(nSessions, 1);
        sessLeftMiss = nan(nSessions, 1);
        sessRightMiss = nan(nSessions, 1);
        sessLeftAmp = nan(nSessions, 1);
        sessRightAmp = nan(nSessions, 1);

        for sessIdx = 1:nSessions
            % Resample trials with replacement within the drawn session.
            session = mouseSessions(randSessions(sessIdx));
            nTrials = numel(session.result);
            randTrials = randi(nTrials, 1, nTrials);
            result = session.result(randTrials);
            isLeft = session.isLeft(randTrials);
            isRight = session.isRight(randTrials);
            ampLeft = session.ampLeft(randTrials);
            ampRight = session.ampRight(randTrials);

            % Overall and per-side performance / miss / amplitude for this session.
            sessOverallPerf(sessIdx) = local_frac_correct(result);
            sessOverallMiss(sessIdx) = local_frac_miss(result);
            sessLeftPerf(sessIdx) = local_frac_correct(result(isLeft));
            sessRightPerf(sessIdx) = local_frac_correct(result(isRight));
            sessLeftMiss(sessIdx) = local_frac_miss(result(isLeft));
            sessRightMiss(sessIdx) = local_frac_miss(result(isRight));
            sessLeftAmp(sessIdx) = local_mean_or_nan(ampLeft(isLeft & ~isnan(result)));
            sessRightAmp(sessIdx) = local_mean_or_nan(ampRight(isRight & ~isnan(result)));
        end

        % Average across the resampled sessions for this resample.
        bootOverallPerf(bootNum) = mean(sessOverallPerf, 'omitnan');
        bootOverallMiss(bootNum) = mean(sessOverallMiss, 'omitnan');
        bootLeftPerf(bootNum) = mean(sessLeftPerf, 'omitnan');
        bootRightPerf(bootNum) = mean(sessRightPerf, 'omitnan');
        bootLeftMiss(bootNum) = mean(sessLeftMiss, 'omitnan');
        bootRightMiss(bootNum) = mean(sessRightMiss, 'omitnan');
        bootLeftAmp(bootNum) = mean(sessLeftAmp, 'omitnan');
        bootRightAmp(bootNum) = mean(sessRightAmp, 'omitnan');
    end

    % Assemble the [overall; left; right] CI rows and the [left, right] amplitude point.
    ciCorrect = [local_ci(bootOverallPerf); local_ci(bootLeftPerf); local_ci(bootRightPerf)];
    ciMiss = [local_ci(bootOverallMiss); local_ci(bootLeftMiss); local_ci(bootRightMiss)];
    ampLeftRight = [mean(bootLeftAmp), mean(bootRightAmp)];
end

function mask = local_sidemask(trialType, cueType, noCueType)
    % Use the cue trial type; fall back to the NoCue type only if no cue trials exist.
    mask = strcmp(trialType, cueType);
    if ~any(mask)
        mask = strcmp(trialType, noCueType);
    end
    mask = mask(:);
end

function ci = local_ci(samples)
    % Percentile CI: [mean, 2.5th percentile, 97.5th percentile] of the bootstrap draws.
    sortedSamples = sort(samples);
    nSamples = numel(samples);
    ci = [mean(samples), sortedSamples(round(nSamples * 0.025)), sortedSamples(round(nSamples * 0.975))];
end

function value = local_frac_correct(result)
    % Correct fraction = mean over the non-miss (non-NaN) trials.
    notMiss = ~isnan(result);
    if any(notMiss)
        value = mean(result(notMiss));
    else
        value = NaN;
    end
end

function value = local_frac_miss(result)
    % Miss fraction = fraction of trials with a NaN result.
    if ~isempty(result)
        value = mean(isnan(result));
    else
        value = NaN;
    end
end

function value = local_mean_or_nan(values)
    % Mean of the values, or NaN when there are none.
    if isempty(values)
        value = NaN;
    else
        value = mean(values);
    end
end

% ===================================================================== %
function [session, taskName] = local_read_session(nwbPath)
    % Read one expert NWB file and return the trimmed per-trial arrays (after
    % trialMap, abort-removal and opto-removal) plus the session metadata. taskName
    % is returned separately so the caller can filter without storing it.

    % Silence the matnwb version-mismatch warning for this read; restore the warning
    % state when the function returns. restoreWarning must stay in scope for the
    % onCleanup callback to fire, so it is intentionally assigned but not referenced.
    warnState = warning('off', 'NWB:Read:AttemptReadWithVersionMismatch');
    restoreWarning = onCleanup(@() warning(warnState));
    nwb = nwbRead(nwbPath);

    % Subject identity and genotype.
    animal = upper(strtrim(local_char(local_scalar(nwb.general_subject.subject_id))));
    genotype = upper(strtrim(local_char(local_scalar(nwb.general_subject.genotype))));

    % Pull the trials-table columns the analysis needs.
    trials = nwb.intervals_trials;
    trialType = local_cellstr(local_col(trials, 'trialType'));
    result = local_double(local_col(trials, 'result'));
    response = local_double(local_col(trials, 'response'));
    leftStimType = local_cellstr(local_col(trials, 'leftStimType'));
    rightStimType = local_cellstr(local_col(trials, 'rightStimType'));

    % Session metadata (task name, session date, trialMap string).
    sessInfo = local_session_info(nwb);
    taskName = local_sifield(sessInfo, 'taskName');
    if isempty(taskName)
        taskName = local_sifield(sessInfo, 'seshType');
    end
    seshDate = strtrim(local_sifield(sessInfo, 'seshDate'));
    trialMapStr = local_sifield(sessInfo, 'trialMap');

    % Apply the trialMap on the full trial ordering, keeping the union of ranges.
    nTrials = numel(trialType);
    trialRanges = local_parse_trialmap(trialMapStr, nTrials);
    if ~isempty(trialRanges)
        keepMask = false(nTrials, 1);
        for rangeInd = 1:size(trialRanges, 1)
            if trialRanges(rangeInd, 2) >= trialRanges(rangeInd, 1)
                keepMask(trialRanges(rangeInd, 1):trialRanges(rangeInd, 2)) = true;
            end
        end
        trialType = trialType(keepMask);
        result = result(keepMask);
        response = response(keepMask);
        leftStimType = leftStimType(keepMask);
        rightStimType = rightStimType(keepMask);
    end

    % Drop aborted trials (response == 3).
    notAbort = response ~= 3;
    trialType = trialType(notAbort);
    result = result(notAbort);
    leftStimType = leftStimType(notAbort);
    rightStimType = rightStimType(notAbort);

    % Drop opto trials (any trialType containing 'Opto').
    notOpto = ~contains(trialType, 'Opto');
    trialType = trialType(notOpto);
    result = result(notOpto);
    leftStimType = leftStimType(notOpto);
    rightStimType = rightStimType(notOpto);

    % Assemble the session struct. Field order must match the empty template used in
    % the main loop so the struct array concatenates cleanly.
    session.animal = animal;
    session.genotype = genotype;
    session.seshDate = seshDate;
    session.result = result(:);
    session.trialType = trialType(:);
    % Precompute per-session cue/NoCue side masks once (used repeatedly by the bootstrap).
    session.isLeft = local_sidemask(trialType, 'Stim_Som_Left', 'Stim_Som_Left_NoCue');
    session.isRight = local_sidemask(trialType, 'Stim_Som_Right', 'Stim_Som_Right_NoCue');
    ampLeft = cellfun(@local_amp, leftStimType);
    session.ampLeft = ampLeft(:);
    ampRight = cellfun(@local_amp, rightStimType);
    session.ampRight = ampRight(:);
end

function ranges = local_parse_trialmap(trialMapStr, nTrials)
    % Read colon-separated values as consecutive start:stop pairs, so a multi-range
    % map like "1:240:260:end'" keeps 1-240 AND 260-end. Returns a Kx2 range matrix
    % (empty when there is no usable map). 'end' means the last trial; trailing
    % quotes are ignored.
    ranges = [];
    trialMapStr = strtrim(local_char(trialMapStr));
    if isempty(trialMapStr) || strcmpi(trialMapStr, 'nan') || ~contains(trialMapStr, ':')
        return
    end

    % Split into tokens and strip whitespace / quotes.
    parts = strsplit(trialMapStr, ':');
    parts = cellfun(@(p) strtrim(regexprep(p, '''', '')), parts, 'UniformOutput', false);

    % Preallocate one row per (start, stop) pair, then fill.
    nPairs = floor(numel(parts) / 2);
    ranges = nan(nPairs, 2);
    pairCount = 0;
    for partInd = 1:2:numel(parts) - 1
        startTrial = str2double(regexprep(parts{partInd}, '\D', ''));
        if isnan(startTrial)
            startTrial = 1;
        end
        stopToken = parts{partInd + 1};
        if strcmpi(stopToken, 'end') || isempty(stopToken)
            stopTrial = nTrials;
        else
            stopTrial = str2double(regexprep(stopToken, '\D', ''));
            if isnan(stopTrial)
                stopTrial = nTrials;
            end
        end
        pairCount = pairCount + 1;
        ranges(pairCount, :) = [max(1, startTrial), min(stopTrial, nTrials)];
    end
    ranges = ranges(1:pairCount, :);
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
% matnwb access helpers
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
