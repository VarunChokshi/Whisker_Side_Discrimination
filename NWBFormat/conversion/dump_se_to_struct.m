function outPath = dump_se_to_struct(sePath, outDir)
% DUMP_SE_TO_STRUCT  Flatten an MSessionExplorer (se) .mat into a Python-friendly struct.
%
%   outPath = dump_se_to_struct(sePath)
%   outPath = dump_se_to_struct(sePath, outDir)
%
% Writes "<name>_struct.mat" containing a single variable `se_struct`, saved as
% -v7 so Python's scipy.io.loadmat can read it. `se_struct` has fields:
%
%   numEpochs   scalar (number of trials/epochs)
%   sourceFile  char (path of the source se file)
%   tables      struct with one field per se table:
%                 .<tableName>.data     struct array, one element per epoch/trial
%                 .<tableName>.type     'eventValues' | 'eventTimes' | 'timeSeries'
%                 .<tableName>.refTime  per-epoch reference time (numeric row) or []
%   userData    se.userData, with MATLAB tables converted to structs and
%               datetimes converted to strings (so scipy can read them)
%
% This is READ-ONLY with respect to the source se; it only writes the new file.
%
% NOTE: intended for BEHAVIOR sessions (small). Ephys se files have very large
% userData (spike templates etc.) that exceed the -v7 2 GB limit; those use a
% separate, selective dump. See the conversion README.
%
% Requires the MSessionExplorer class to be on the MATLAB path.

    % --- resolve the source file (prompt if not given) ---
    if nargin < 1 || isempty(sePath)
        [fileName, folderPath] = uigetfile('*.mat', 'Select an se .mat file to dump');
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

    % --- flatten scalar session fields ---
    se_struct = struct();
    se_struct.numEpochs = se.numEpochs;
    se_struct.sourceFile = sePath;
    se_struct.tables = struct();

    % --- flatten each se table to a struct array plus its type and reference time ---
    tableNames = se.tableNames;
    for tableInd = 1:numel(tableNames)
        tableName = tableNames{tableInd};
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
        tableEntry.refTime = refTime(:)';
        se_struct.tables.(tableName) = tableEntry;
    end

    % --- flatten userData (tables -> structs, datetimes -> strings) ---
    se_struct.userData = local_sanitize(se.userData);

    % --- save as -v7 so scipy can read it ---
    outPath = fullfile(outDir, [baseName '_struct.mat']);
    save(outPath, 'se_struct', '-v7');
    fprintf('Wrote %s  (%d trials, tables: %s)\n', outPath, se.numEpochs, strjoin(tableNames(:)', ', '));
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

% ======================================================================
function value = local_sanitize(value)
    % Recursively make a value scipy-readable:
    %   tables    -> structs
    %   datetimes -> 'yyyy-MM-dd HH:mm:ss' strings
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
