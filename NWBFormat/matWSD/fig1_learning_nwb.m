function fig1_learning_nwb(nwbDir, sessInfoXlsx, outDir)
% FIG1_LEARNING_NWB  Reproduce the Fig1 LEARNING plot from behavioral NWB files.
%
%   fig1_learning_nwb(nwbDir, sessInfoXlsx, outDir)
%
% NWB port (matnwb) of the learning section of Fig1_BS_Behav.m: number of
% training sessions per mouse, WT vs KO.
%
% Inputs
%   nwbDir        folder of behavior/learning *.nwb files
%   sessInfoXlsx  LearningSessInfo\SessionInfo.xlsx (per-animal training window)
%   outDir        output folder (writes Learning.pdf/.png/_stats.txt)
%
% A session is counted iff: its animal has a training window in the spreadsheet,
% the session date is within that window, it is NOT an opto session, side-assist
% is off, and leftStimProb is neither 0 nor 1. (Mirrors Fig1_BS_Behav.m.)
%
% Requires matnwb on the path and readBehaviorNWB.m in the same folder.
% Runtime: ~9 min for the full ~1150-session learning set (nwbRead is ~0.4 s/file).

    % --- arguments / output folder ---
    if nargin < 3 || isempty(outDir)
        outDir = pwd;
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % --- per-animal training windows from the spreadsheet ---
    trainingWindows = local_training_windows(sessInfoXlsx);
    fprintf('training windows for %d animals\n', trainingWindows.Count);

    % --- read every NWB and decide keep/drop (preallocate, trim to what was read) ---
    nwbFiles = dir(fullfile(nwbDir, '*.nwb'));
    nFiles = numel(nwbFiles);
    animalIds = cell(nFiles, 1);
    keepFlags = false(nFiles, 1);
    nRead = 0;
    for fileInd = 1:nFiles
        nwbPath = fullfile(nwbFiles(fileInd).folder, nwbFiles(fileInd).name);
        try
            session = readBehaviorNWB(nwbPath);
        catch readErr
            fprintf(2, 'ERROR reading %s: %s\n', nwbFiles(fileInd).name, readErr.message);
            continue
        end
        nRead = nRead + 1;

        % Is the session date inside this animal's training window?
        inWindow = false;
        if isKey(trainingWindows, session.animal)
            window = trainingWindows(session.animal);
            inWindow = ~isnat(window(1)) && ~isnat(window(2)) && ...
                       session.sessionDate >= window(1) && session.sessionDate <= window(2);
        end

        % Keep iff listed, in-window, not opto, side-assist off, leftProb not 0 or 1.
        keep = isKey(trainingWindows, session.animal) && inWindow && ~session.isOpto && ...
               ~session.sideAssist && session.leftProb ~= 0 && session.leftProb ~= 1;

        animalIds{nRead} = session.animal;
        keepFlags(nRead) = keep;
    end
    animalIds = animalIds(1:nRead);
    keepFlags = keepFlags(1:nRead);
    fprintf('read %d NWB files; %d pass all filters\n', nRead, sum(keepFlags));

    % --- count kept sessions per mouse ---
    keptAnimalIds = animalIds(keepFlags);
    uniqueAnimals = unique(keptAnimalIds);
    sessionCounts = zeros(numel(uniqueAnimals), 1);
    for animalNum = 1:numel(uniqueAnimals)
        sessionCounts(animalNum) = sum(strcmp(keptAnimalIds, uniqueAnimals{animalNum}));
    end
    % WT vs KO from the ID convention (6th character is '1' for WT).
    isWildType = cellfun(@(x) numel(x) >= 6 && x(6) == '1', uniqueAnimals);
    WTNumSess = sessionCounts(isWildType);
    KONumSess = sessionCounts(~isWildType);

    fprintf('WT n=%d: %s\n', numel(WTNumSess), mat2str(WTNumSess'));
    fprintf('KO n=%d: %s\n', numel(KONumSess), mat2str(KONumSess'));

    % --- plot (identical style to Fig1_BS_Behav.m) ---
    figHandle = figure(1);
    clf
    set(figHandle, 'Units', 'centimeters', 'Position', [50, 50, 33, 38] / 10);
    hold on
    errorbar(1, mean(WTNumSess), std(WTNumSess) / sqrt(numel(WTNumSess)), '.', ...
        'MarkerSize', 20, 'LineWidth', 2, 'Color', [0.5 0.5 0.5], 'CapSize', 0);
    errorbar(2, mean(KONumSess), std(KONumSess) / sqrt(numel(KONumSess)), '.', ...
        'MarkerSize', 20, 'LineWidth', 2, 'Color', [0 0 0], 'CapSize', 0);
    xlim([0, 3]);
    xticks([1, 2]);
    xticklabels({'WT', 'KO'});
    ylabel('Number of sessions');
    ylim([0, 40]);
    set(gca, 'FontName', 'Arial', 'FontSize', 8);
    exportgraphics(figHandle, fullfile(outDir, 'FigS1D - Learning rate.pdf'), 'Resolution', 300);
    exportgraphics(figHandle, fullfile(outDir, 'FigS1D - Learning rate.png'), 'Resolution', 300);

    % --- stats (same tests as the original) ---
    [~, pTtest] = ttest2(WTNumSess, KONumSess, 'Vartype', 'unequal');
    pRankSum = ranksum(WTNumSess, KONumSess, 'tail', 'both');
    statsFileId = fopen(fullfile(outDir, 'FigS1D - Learning rate stats.txt'), 'w');
    fprintf(statsFileId, 'WT n=%d, per-mouse counts: %s\n', numel(WTNumSess), mat2str(WTNumSess'));
    fprintf(statsFileId, 'KO n=%d, per-mouse counts: %s\n', numel(KONumSess), mat2str(KONumSess'));
    fprintf(statsFileId, 'WT mean=%.4g SEM=%.4g\n', mean(WTNumSess), std(WTNumSess) / sqrt(numel(WTNumSess)));
    fprintf(statsFileId, 'KO mean=%.4g SEM=%.4g\n', mean(KONumSess), std(KONumSess) / sqrt(numel(KONumSess)));
    fprintf(statsFileId, 'ttest2 (Vartype unequal) p=%.4g\n', pTtest);
    fprintf(statsFileId, 'ranksum p=%.4g\n', pRankSum);
    fclose(statsFileId);

    fprintf('WT mean=%.3g, KO mean=%.3g | ttest2 p=%.3g, ranksum p=%.3g\n', ...
        mean(WTNumSess), mean(KONumSess), pTtest, pRankSum);
    fprintf('Wrote FigS1D - Learning rate .pdf / .png / stats.txt to %s\n', outDir);
end

% ===================================================================== %
function trainingWindows = local_training_windows(xlsxPath)
    % Return a containers.Map: ANIMAL_ID -> [startDatetime endDatetime].
    warnState = warning('off', 'MATLAB:table:ModifiedAndSavedVarnames');
    sessInfoTable = readtable(xlsxPath);
    warning(warnState);

    % Match the Animal ID / Training start / End date columns loosely by name.
    varNames = sessInfoTable.Properties.VariableNames;
    normNames = cellfun(@(x) lower(regexprep(x, '[^a-zA-Z0-9]', '')), varNames, 'UniformOutput', false);
    animalCol = find(contains(normNames, 'animalid'), 1);
    startCol = find(contains(normNames, 'trainingstart'), 1);
    endCol = find(contains(normNames, 'enddate'), 1);
    assert(~isempty(animalCol) && ~isempty(startCol) && ~isempty(endCol), ...
        'Could not find Animal ID / Training start / End date columns in %s', xlsxPath);

    % One (start, end) window per listed animal.
    trainingWindows = containers.Map('KeyType', 'char', 'ValueType', 'any');
    for rowInd = 1:height(sessInfoTable)
        animalId = upper(strtrim(char(string(sessInfoTable{rowInd, animalCol}))));
        if isempty(animalId) || strcmpi(animalId, 'NaN')
            continue
        end
        trainingWindows(animalId) = [local_yymmdd(sessInfoTable{rowInd, startCol}), ...
                                     local_yymmdd(sessInfoTable{rowInd, endCol})];
    end
end

function dateOut = local_yymmdd(value)
    % Parse a yymmdd cell/char/numeric value to a datetime (NaT if blank/invalid).
    if iscell(value)
        value = value{1};
    end
    if ischar(value) || isstring(value)
        value = str2double(regexprep(char(string(value)), '\D', ''));
    end
    if isempty(value) || isnan(value)
        dateOut = NaT;
        return
    end
    dateStr = sprintf('%06d', round(value));
    try
        dateOut = datetime(dateStr, 'InputFormat', 'yyMMdd');
    catch
        dateOut = NaT;
    end
end
