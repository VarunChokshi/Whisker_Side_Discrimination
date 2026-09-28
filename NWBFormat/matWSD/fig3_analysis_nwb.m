function records = fig3_analysis_nwb(nwbDir)
% FIG3_ANALYSIS_NWB  Analysis core for Figure 3 (passive-stim S1/M1 ephys), reading NWB.
%
%   records = fig3_analysis_nwb(nwbDir)
%
% Reproduces the per-unit quantities that GetComposite / GetFRData / AddMeanFRData
% compute from the se, reading them instead from the converted NWB files: per unit,
% per stimulus frequency, the stim-aligned spike rasters and firing-rate traces for
% contralateral and ipsilateral trials, plus per analysis-window p-values (pre- vs
% post-stim Wilcoxon signed-rank), the contra-bias index, and the unit's normalised
% cortical depth.
%
% This is the MATLAB mirror of fig3_analysis_nwb.py and returns the same records so
% that fig3_panels_nwb.m reproduces identical figures. Requires matnwb on the path.
%
% Output: a struct array, one element per (session, frequency, unit), with fields
%   animal genotype recSite region session freq unit depthRaw depthNorm ksLabel
%   frTime frContra frIpsi spikesContra spikesIpsi perWindow
% where perWindow is a struct keyed by window name ('25'..'300') each holding
%   pvalContra pvalIpsi pvalBoth cbias.

    % --- read every NWB in the folder and concatenate the per-unit records ---
    nwbFiles = dir(fullfile(nwbDir, '*.nwb'));
    sessionRecordCells = cell(1, numel(nwbFiles));
    for fileInd = 1:numel(nwbFiles)
        nwbPath = fullfile(nwbFiles(fileInd).folder, nwbFiles(fileInd).name);
        try
            session = readSessionEphys(nwbPath);
            sessRecords = unitRecords(session);
        catch readErr
            fprintf(2, '  ERROR %s: %s\n', nwbFiles(fileInd).name, readErr.message);
            continue
        end
        sessionRecordCells{fileInd} = sessRecords;
        fprintf('  %s: %d unit-freq records (%s %s)\n', nwbFiles(fileInd).name, ...
            numel(sessRecords), session.genotype, session.recSite);
    end
    records = [sessionRecordCells{:}];
    fprintf('loaded %d unit-freq records from %d sessions\n', numel(records), numel(nwbFiles));
end

% ===================================================================== %
%  analysis constants (shared with the Python core)
% ===================================================================== %
function ops = analysisOps()
    ops.tWins = [-0.31, 0.31];
    ops.binSize = 0.0025;
    ops.bins = ops.tWins(1) : ops.binSize : ops.tWins(2);
    ops.windows = [0.025, 0.04, 0.05, 0.075, 0.1, 0.15, 0.2, 0.3];
    ops.windowNames = {'25', '40', '50', '75', '100', '150', '200', '300'};
    ops.defPenetrationDepth = 1300;
    ops.defCorticalDepth = 1280;
end

% ===================================================================== %
%  read one session from NWB
% ===================================================================== %
function session = readSessionEphys(nwbPath)
    warnState = warning('off', 'NWB:Read:AttemptReadWithVersionMismatch');
    restoreWarning = onCleanup(@() warning(warnState));
    nwb = nwbRead(nwbPath, 'ignorecache');

    % --- subject metadata ---
    session.animal = upper(strtrim(local_char(local_scalar(nwb.general_subject.subject_id))));
    session.genotype = upper(strtrim(local_char(local_scalar(nwb.general_subject.genotype))));
    [~, baseName] = fileparts(nwbPath);
    session.session = baseName;

    % --- trials table ---
    trials = nwb.intervals_trials;
    session.response = local_double(local_col(trials, 'response'));
    session.trialType = local_cellstr(local_col(trials, 'trialType'));
    session.leftStimType = local_cellstr(local_col(trials, 'leftStimType'));
    session.rightStimType = local_cellstr(local_col(trials, 'rightStimType'));
    session.referenceTime = local_double(local_col(trials, 'reference_time'));

    % --- units: per-unit spike trains, depth, KS label ---
    units = nwb.units;
    nUnits = numel(local_scalar(units.id.data));
    spikeTrains = cell(nUnits, 1);
    for unitInd = 1:nUnits
        row = units.getRow(unitInd, 'columns', {'spike_times'});
        spikeTrains{unitInd} = row.spike_times{1}(:);
    end
    session.spikeTrains = spikeTrains;
    session.unitDepth = local_double(local_vec(units, 'depth'));
    session.ksLabel = local_cellstr(local_vec(units, 'ks_label'));

    % --- firing rate (ecephys/firing_rate): orient so rows are time samples ---
    ecephys = nwb.processing.get('ecephys');
    firingRate = ecephys.nwbdatainterface.get('firing_rate');
    frTime = local_scalar(firingRate.timestamps);
    frData = local_orient(local_scalar(firingRate.data), numel(frTime));
    session.frTime = frTime(:);
    session.frData = frData;

    % --- stimulus (piezo_stim): orient so rows are time samples ---
    stimSeries = nwb.stimulus_presentation.get('piezo_stim');
    stimTime = local_scalar(stimSeries.timestamps);
    stimData = local_orient(local_scalar(stimSeries.data), numel(stimTime));
    session.stimTime = stimTime(:);
    session.stimData = stimData;

    % --- session_info fields ---
    sessInfo = local_session_info(nwb);
    session.recSite = local_sifield(sessInfo, 'recSite');
    session.region = local_sifield(sessInfo, 'region');
    session.apStim = local_sifield(sessInfo, 'APStim');
    ops = analysisOps();
    session.penetrationDepth = local_parse_number(local_sifield(sessInfo, 'histology'), ops.defPenetrationDepth);
    session.corticalDepth = local_parse_number(local_sifield(sessInfo, 'corticaldepth'), ops.defCorticalDepth);
end

% ===================================================================== %
%  trial selection + per-trial reconstruction
% ===================================================================== %
function trialInds = selectTrials(session)
    % No-lick trials (response == 0), within the APStim range, first dropped.
    keep = find(session.response == 0);
    ranges = parseApStimRanges(session.apStim, numel(keep));
    if ~isempty(ranges)
        mask = false(numel(keep), 1);
        for rangeInd = 1:size(ranges, 1)
            startInd = ranges(rangeInd, 1);
            stopInd = ranges(rangeInd, 2);
            if stopInd >= startInd
                mask(startInd:stopInd) = true;
            end
        end
        keep = keep(mask);
    end
    if numel(keep) >= 1
        trialInds = keep(2:end);   % drop the first remaining trial
    else
        trialInds = keep;
    end
end

function ranges = parseApStimRanges(apStim, nTrials)
    % Parse an APStim string ('1:end'', '50:350'', '1:240:260:end'') to 1-based
    % inclusive ranges, or [] to keep all trials.
    ranges = [];
    text = strtrim(apStim);
    if isempty(text) || strcmpi(text, 'nan') || ~contains(text, ':')
        return
    end
    parts = strsplit(text, ':');
    for partInd = 1:numel(parts)
        parts{partInd} = strtrim(strrep(parts{partInd}, '''', ''));
    end
    pairStarts = 1:2:(numel(parts) - 1);
    ranges = zeros(numel(pairStarts), 2);
    for pairIdx = 1:numel(pairStarts)
        pairInd = pairStarts(pairIdx);
        startDigits = regexprep(parts{pairInd}, '\D', '');
        if isempty(startDigits)
            startVal = 1;
        else
            startVal = str2double(startDigits);
        end
        stopToken = parts{pairInd + 1};
        if strcmpi(stopToken, 'end') || isempty(stopToken)
            stopVal = nTrials;
        else
            stopDigits = regexprep(stopToken, '\D', '');
            if isempty(stopDigits)
                stopVal = nTrials;
            else
                stopVal = str2double(stopDigits);
            end
        end
        ranges(pairIdx, :) = [max(1, startVal), min(stopVal, nTrials)];
    end
end

function aligned = trialSpikeTrain(spikeTimes, reference, tWins)
    % Stim-aligned spikes of one unit within one trial's window.
    lo = reference + tWins(1);
    hi = reference + tWins(2);
    inWindow = spikeTimes(spikeTimes >= lo & spikeTimes <= hi);
    aligned = inWindow - reference;
end

function resampled = trialFiringRate(frData, frTime, reference, bins, binSize)
    % Per-unit firing rate for one trial, resampled onto the fixed bins grid.
    lo = reference + bins(1) - binSize;
    hi = reference + bins(end) + binSize;
    loInd = find(frTime >= lo, 1, 'first');
    hiInd = find(frTime <= hi, 1, 'last');
    nUnits = size(frData, 2);
    resampled = zeros(numel(bins), nUnits);
    if isempty(loInd) || isempty(hiInd) || (hiInd - loInd) < 1
        return
    end
    stimAligned = frTime(loInd:hiInd) - reference;
    block = frData(loInd:hiInd, :);
    % Clamp query points into range so edge values are held constant, matching
    % numpy.interp (which does not extrapolate) rather than linear extrapolation.
    binsClamped = min(max(bins(:), stimAligned(1)), stimAligned(end));
    for unitInd = 1:nUnits
        resampled(:, unitInd) = interp1(stimAligned, block(:, unitInd), binsClamped, 'linear');
    end
end

% ===================================================================== %
%  frequency parsing
% ===================================================================== %
function [freqs, freqStart] = uniqueFrequencies(leftStimTypes)
    % Unique stimulus frequencies and the 1-based char offset they start at.
    uniqueTypes = unique(leftStimTypes);
    freqs = unique(cellfun(@(x) x(5:6), uniqueTypes, 'UniformOutput', false));
    if all(~isnan(str2double(freqs)))
        freqStart = 5;
        return
    end
    freqs = unique(cellfun(@(x) x(17:18), uniqueTypes, 'UniformOutput', false));
    freqStart = 17;
end

function freq = freqOf(stimType, freqStart)
    freq = stimType(freqStart:freqStart + 1);
end

% ===================================================================== %
%  per-session unit records
% ===================================================================== %
function records = unitRecords(session)
    ops = analysisOps();
    bins = ops.bins;
    records = struct([]);

    trialInds = selectTrials(session);
    if isempty(trialInds)
        return
    end

    reference = session.referenceTime(trialInds);
    trialType = session.trialType(trialInds);
    leftStimTypes = session.leftStimType(trialInds);
    rightStimTypes = session.rightStimType(trialInds);
    nUnits = numel(session.spikeTrains);
    nTrials = numel(trialInds);

    % Per-trial reconstruction (stim-aligned): spikes per unit, and FR on bins.
    perTrialSpikes = cell(nTrials, nUnits);
    perTrialFr = cell(nTrials, 1);
    for trialInd = 1:nTrials
        for unitInd = 1:nUnits
            perTrialSpikes{trialInd, unitInd} = ...
                trialSpikeTrain(session.spikeTrains{unitInd}, reference(trialInd), ops.tWins);
        end
        perTrialFr{trialInd} = trialFiringRate(session.frData, session.frTime, ...
            reference(trialInd), bins, ops.binSize);
    end

    % Contra / ipsi assignment from the recording site.
    leftIsIpsi = sum(ismember('Left', session.recSite)) == 4;

    [frequencies, freqStart] = uniqueFrequencies(leftStimTypes);
    penetration = session.penetrationDepth;
    cortical = session.corticalDepth;
    if cortical == 0
        cortical = ops.defCorticalDepth;
    end

    % Preallocate the record list to the maximum (units x frequencies) it can hold.
    recordCells = cell(1, nUnits * numel(frequencies));
    recordCount = 0;

    for freqInd = 1:numel(frequencies)
        freq = frequencies{freqInd};
        leftTrials = find(strcmp(trialType, 'Stim_Som_Left') & ...
            cellfun(@(x) strcmp(freqOf(x, freqStart), freq), leftStimTypes));
        rightTrials = find(strcmp(trialType, 'Stim_Som_Right') & ...
            cellfun(@(x) strcmp(freqOf(x, freqStart), freq), rightStimTypes));
        if isempty(leftTrials) || isempty(rightTrials)
            continue
        end

        % FR matrices (trials x bins) per unit for each side.
        frLeft = local_stack(perTrialFr, leftTrials);    % (nLeft, nBins, nUnits)
        frRight = local_stack(perTrialFr, rightTrials);  % (nRight, nBins, nUnits)

        for unitInd = 1:nUnits
            depthNorm = (penetration - session.unitDepth(unitInd)) / cortical;
            frLeftUnit = squeeze(frLeft(:, :, unitInd));
            frRightUnit = squeeze(frRight(:, :, unitInd));
            if size(frLeftUnit, 2) == 1 && isscalar(leftTrials)
                frLeftUnit = frLeftUnit(:)';
            end
            if size(frRightUnit, 2) == 1 && isscalar(rightTrials)
                frRightUnit = frRightUnit(:)';
            end

            if leftIsIpsi
                frIpsi = frLeftUnit;
                frContra = frRightUnit;
                ipsiTrials = leftTrials;
                contraTrials = rightTrials;
            else
                frIpsi = frRightUnit;
                frContra = frLeftUnit;
                ipsiTrials = rightTrials;
                contraTrials = leftTrials;
            end
            spikesContra = perTrialSpikes(contraTrials, unitInd);
            spikesIpsi = perTrialSpikes(ipsiTrials, unitInd);

            perWindow = struct();
            for windowInd = 1:numel(ops.windows)
                windowName = ops.windowNames{windowInd};
                perWindow.(['w' windowName]) = windowStats(frLeftUnit, frRightUnit, ...
                    spikesContra, spikesIpsi, ops.windows(windowInd), leftIsIpsi, bins);
            end

            record = struct();
            record.animal = session.animal;
            record.genotype = session.genotype;
            record.recSite = session.recSite;
            record.region = session.region;
            record.session = session.session;
            record.freq = freq;
            record.unit = unitInd;
            record.depthRaw = session.unitDepth(unitInd);
            record.depthNorm = depthNorm;
            record.ksLabel = strtrim(session.ksLabel{unitInd});
            record.frTime = bins(:)';
            record.frContra = frContra;
            record.frIpsi = frIpsi;
            record.spikesContra = {spikesContra};
            record.spikesIpsi = {spikesIpsi};
            record.perWindow = perWindow;

            recordCount = recordCount + 1;
            recordCells{recordCount} = record;
        end
    end
    records = [recordCells{1:recordCount}];
end

function stats = windowStats(frLeftUnit, frRightUnit, spikesContra, spikesIpsi, window, leftIsIpsi, bins)
    % Per-window p-values (pre vs post FR, both sides), cbias (contra/ipsi spike-count
    % change), and pvalBoth = min(pvalL, pvalR).
    inWindow = find(bins >= -window & bins <= window);
    frLeftWin = frLeftUnit(:, inWindow);
    frRightWin = frRightUnit(:, inWindow);
    half = round(size(frLeftWin, 2) / 2);
    preL = mean(frLeftWin(:, 1:half), 2);
    postL = mean(frLeftWin(:, half + 1:end), 2);
    preR = mean(frRightWin(:, 1:half), 2);
    postR = mean(frRightWin(:, half + 1:end), 2);
    pvalL = signrankP(preL, postL);
    pvalR = signrankP(preR, postR);

    contraPre = local_count_spikes(spikesContra, -window, 0);
    contraPost = local_count_spikes(spikesContra, 0, window);
    ipsiPre = local_count_spikes(spikesIpsi, -window, 0);
    ipsiPost = local_count_spikes(spikesIpsi, 0, window);
    contraChange = abs(contraPost - contraPre);
    ipsiChange = abs(ipsiPost - ipsiPre);
    denom = contraChange + ipsiChange;
    if denom == 0
        cbias = NaN;
    else
        cbias = (contraChange - ipsiChange) / denom;
    end

    if leftIsIpsi
        pvalIpsi = pvalL;
        pvalContra = pvalR;
    else
        pvalIpsi = pvalR;
        pvalContra = pvalL;
    end
    stats.pvalContra = pvalContra;
    stats.pvalIpsi = pvalIpsi;
    stats.pvalBoth = min(pvalL, pvalR);
    stats.cbias = cbias;
end

function pval = signrankP(preValues, postValues)
    % Two-sided Wilcoxon signed-rank p-value (returns 1 when there is no difference).
    diff = postValues - preValues;
    if isempty(diff) || all(abs(diff) < eps)
        pval = 1.0;
        return
    end
    try
        pval = signrank(preValues, postValues, 'tail', 'both');
    catch
        pval = 1.0;
    end
end

% ===================================================================== %
%  matnwb reading helpers
% ===================================================================== %
function value = local_scalar(dataField)
    if isa(dataField, 'types.untyped.DataStub')
        value = dataField.load();
    else
        value = dataField;
    end
end

function matrix = local_orient(matrix, nTime)
    % Orient a 2-D dataset so that rows index time (matnwb reads pynwb 2-D data
    % with the dimension order reversed).
    if size(matrix, 1) ~= nTime && size(matrix, 2) == nTime
        matrix = matrix';
    end
end

function columnData = local_col(trials, name)
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

function columnData = local_vec(dynTable, name)
    % Load a custom DynamicTable column (e.g. a Units column).
    if ~isempty(dynTable.vectordata) && dynTable.vectordata.isKey(name)
        columnData = local_scalar(dynTable.vectordata.get(name).data);
    else
        columnData = [];
    end
end

function charOut = local_char(value)
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

function strings = local_cellstr(columnData)
    if isempty(columnData)
        strings = {};
    elseif ischar(columnData)
        strings = cellstr(columnData);
    elseif isstring(columnData)
        strings = cellstr(columnData);
    elseif iscell(columnData)
        strings = columnData(:);
    else
        strings = cellstr(string(columnData));
    end
    strings = strings(:);
end

function values = local_double(columnData)
    if iscell(columnData)
        values = cellfun(@double, columnData);
    else
        values = double(columnData);
    end
    values = values(:);
end

function sessInfo = local_session_info(nwb)
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
    val = '';
    if isempty(sessInfo) || isempty(sessInfo.vectordata) || ~sessInfo.vectordata.isKey(name)
        return
    end
    fieldValue = local_scalar(sessInfo.vectordata.get(name).data);
    val = local_char(fieldValue);
end

function value = local_parse_number(text, defaultValue)
    match = regexp(text, '-?\d+(\.\d+)?', 'match', 'once');
    if isempty(match)
        value = defaultValue;
    else
        value = str2double(match);
    end
end

function stacked = local_stack(perTrialFr, trialList)
    % Stack a subset of per-trial FR matrices into (nTrials, nBins, nUnits).
    nSel = numel(trialList);
    [nBins, nUnits] = size(perTrialFr{trialList(1)});
    stacked = zeros(nSel, nBins, nUnits);
    for selInd = 1:nSel
        stacked(selInd, :, :) = perTrialFr{trialList(selInd)};
    end
end

function total = local_count_spikes(spikeCells, lo, hi)
    % Total spike count across trials with lo < t <= hi.
    total = 0;
    for cellInd = 1:numel(spikeCells)
        spikes = spikeCells{cellInd};
        total = total + sum(spikes > lo & spikes <= hi);
    end
end
