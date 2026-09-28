function outPath = dump_ephys_se_to_struct(sePath, outDir)
% DUMP_EPHYS_SE_TO_STRUCT  Flatten an enriched ephys se into a Python-friendly struct.
%
%   outPath = dump_ephys_se_to_struct(sePath)
%   outPath = dump_ephys_se_to_struct(sePath, outDir)
%
% The ephys "... se enriched.mat" files carry spike times, per-unit firing rate,
% the stimulus/analog channels, trial info, and per-unit metadata, PLUS very large
% spike templates and per-spike waveforms in userData.spikeInfo. Those templates blow
% past the -v7 2 GB limit and are not used by Figure 3, so this dump SELECTIVELY keeps
% only what the figures need and drops the heavy fields, then writes "<name>_struct.mat"
% (variable `se_struct`, -v7) that scipy.io.loadmat can read.
%
% `se_struct` fields:
%   numEpochs      scalar (number of trials)
%   sourceFile     char (path of the source se file)
%   referenceTime  per-trial reference time (row, absolute session seconds)
%   tables         struct with one field per kept table (spikeTime, spikeRate, adc,
%                  behavValue, behavTime): each .<name>.data / .type / .refTime
%   userData       pruned: sessionInfo, intanInfo, and a trimmed spikeInfo
%                  (recording_time, sample_rate, quality_metrics, unit_channel_ind,
%                  channel_map, unit_mean_waveform, unitHitsoTable) -- NO templates,
%                  unit_mean_template, spike_waveforms, spike_template_ids/amplitudes.
%
% READ-ONLY with respect to the source se. Requires the MSessionExplorer class.

    % --- resolve the source file (prompt if not given) ---
    if nargin < 1 || isempty(sePath)
        [fileName, folderPath] = uigetfile('*.mat', 'Select an enriched ephys se .mat file');
        if isequal(fileName, 0)
            disp('Cancelled.');
            return
        end
        sePath = fullfile(folderPath, fileName);
    end
    [seDir, baseName] = fileparts(sePath);
    if nargin < 2 || isempty(outDir)
        outDir = seDir;
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % --- load the se object ---
    loaded = load(sePath);
    se = local_find_se(loaded);
    assert(~isempty(se), 'No MSessionExplorer object found in %s', sePath);

    % --- scalar session fields ---
    se_struct = struct();
    se_struct.numEpochs = se.numEpochs;
    se_struct.sourceFile = sePath;
    % Per-trial reference time (absolute session seconds); used to place spikes/trials.
    se_struct.referenceTime = reshape(se.GetReferenceTime(), 1, []);
    se_struct.tables = struct();

    % --- flatten only the tables Figure 3 needs ---
    keepTables = {'spikeTime', 'spikeRate', 'adc', 'behavValue', 'behavTime'};
    allTableNames = se.tableNames;
    for keepInd = 1:numel(keepTables)
        tableName = keepTables{keepInd};
        if ~ismember(tableName, allTableNames)
            continue
        end
        tableInd = find(strcmp(allTableNames, tableName), 1);
        sanitizedTable = local_sanitize_table(se.GetTable(tableName));
        tableEntry = struct();
        tableEntry.data = table2struct(sanitizedTable);
        if se.isEventTimesTable(tableInd)
            tableEntry.type = 'eventTimes';
        elseif se.isEventValuesTable(tableInd)
            tableEntry.type = 'eventValues';
        elseif se.isTimesSeriesTable(tableInd)
            tableEntry.type = 'timeSeries';
        else
            tableEntry.type = 'unknown';
        end
        try
            refTime = se.GetReferenceTime(tableName);
        catch
            refTime = [];
        end
        tableEntry.refTime = reshape(refTime, 1, []);
        se_struct.tables.(tableName) = tableEntry;
    end

    % --- prune userData (drop the huge spike templates / waveforms) ---
    se_struct.userData = local_prune_userdata(se.userData);

    % --- save as -v7 so scipy can read it ---
    outPath = fullfile(outDir, [baseName '_struct.mat']);
    save(outPath, 'se_struct', '-v7');
    fprintf('Wrote %s  (%d trials, tables: %s)\n', outPath, se.numEpochs, ...
        strjoin(fieldnames(se_struct.tables)', ', '));
end

% ======================================================================
function userDataOut = local_prune_userdata(userData)
    % Keep only the userData blocks Figure 3 needs; drop bctData / preTaskData and the
    % heavy spikeInfo fields.
    userDataOut = struct();
    if isfield(userData, 'sessionInfo')
        userDataOut.sessionInfo = local_sanitize(userData.sessionInfo);
    end
    if isfield(userData, 'intanInfo')
        userDataOut.intanInfo = local_sanitize(userData.intanInfo);
    end
    if isfield(userData, 'spikeInfo')
        userDataOut.spikeInfo = local_prune_spikeinfo(userData.spikeInfo);
    end
end

function spikeInfoOut = local_prune_spikeinfo(spikeInfo)
    % Keep the per-unit metadata (depth via quality_metrics, channel index, channel map,
    % mean waveform, optional histology) and drop the large per-spike/template arrays.
    keepFields = {'recording_time', 'sample_rate', 'quality_metrics', ...
        'unit_channel_ind', 'channel_map', 'unit_mean_waveform', 'unitHitsoTable'};
    spikeInfoOut = struct();
    for fieldInd = 1:numel(keepFields)
        name = keepFields{fieldInd};
        if isfield(spikeInfo, name)
            spikeInfoOut.(name) = local_sanitize(spikeInfo.(name));
        end
    end
end

% ======================================================================
function tableData = local_sanitize_table(tableData)
    % Convert datetime table variables (and datetimes nested in cells) to text.
    varNames = tableData.Properties.VariableNames;
    for varInd = 1:numel(varNames)
        columnData = tableData.(varNames{varInd});
        if isdatetime(columnData)
            columnData.Format = 'yyyy-MM-dd HH:mm:ss';
            tableData.(varNames{varInd}) = cellstr(string(columnData));
        elseif iscell(columnData)
            for cellInd = 1:numel(columnData)
                if isdatetime(columnData{cellInd})
                    dtValue = columnData{cellInd};
                    dtValue.Format = 'yyyy-MM-dd HH:mm:ss';
                    columnData{cellInd} = char(string(dtValue));
                end
            end
            tableData.(varNames{varInd}) = columnData;
        end
    end
end

function value = local_sanitize(value)
    % Recursively make a value scipy-readable: tables -> structs, datetimes -> strings.
    if istable(value)
        value = table2struct(local_sanitize_table(value));
        return
    end
    if isdatetime(value)
        if isscalar(value)
            value.Format = 'yyyy-MM-dd HH:mm:ss';
            value = char(string(value));
        else
            value.Format = 'yyyy-MM-dd HH:mm:ss';
            value = cellstr(string(value));
        end
        return
    end
    if isstruct(value)
        fieldNames = fieldnames(value);
        for elemInd = 1:numel(value)
            for fieldInd = 1:numel(fieldNames)
                value(elemInd).(fieldNames{fieldInd}) = local_sanitize(value(elemInd).(fieldNames{fieldInd}));
            end
        end
        return
    end
    if iscell(value)
        for cellInd = 1:numel(value)
            value{cellInd} = local_sanitize(value{cellInd});
        end
        return
    end
    % numeric / char / logical: leave as-is
end

% ======================================================================
function se = local_find_se(loaded)
    % Find the MSessionExplorer object among the loaded .mat variables.
    se = [];
    if isfield(loaded, 'se') && isa(loaded.se, 'MSessionExplorer')
        se = loaded.se;
        return
    end
    fieldNames = fieldnames(loaded);
    for fieldInd = 1:numel(fieldNames)
        fieldValue = loaded.(fieldNames{fieldInd});
        if isa(fieldValue, 'MSessionExplorer')
            se = fieldValue(1);
            return
        end
    end
end
