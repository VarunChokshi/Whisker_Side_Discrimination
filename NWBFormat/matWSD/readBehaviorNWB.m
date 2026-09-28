function session = readBehaviorNWB(nwbPath)
% READBEHAVIORNWB  Read one bodyside behavioral NWB file into a plain struct (matnwb).
%
%   session = readBehaviorNWB(nwbPath)
%
% Output struct fields:
%   animal       char, upper-case animal ID (e.g. 'VC030109')
%   genotype     char, 'WT' / 'KO'
%   sex          char, 'M' / 'F' / 'U'
%   sessionDate  datetime (calendar date, no time-of-day / timezone)
%   taskName     char, e.g. 'bodyside6'
%   trialMap     char, trial-selection range e.g. '1:360' (may be empty)
%   sideAssist   logical
%   leftProb     double (leftStimProb; default 0.5 if absent)
%   isOpto       logical  (taskName=='bodyside6' AND any trialType contains 'Opto')
%   nTrials      double
%   trialType    cellstr, per-trial trial type
%   response     double vector (0=miss,1=lickR,2=lickL,3=abort)
%   result       double vector (1=correct,0=incorrect,NaN=no lick)
%
% This is the reusable NWB-reading foundation for the MATLAB figure ports.
% Requires matnwb on the path (nwbRead + generated types; run generateCore once).

    % 'ignorecache' = read using the generated core types instead of regenerating
    % classes from each file's embedded spec (avoids matnwb class-cache churn when
    % batch-reading many pynwb-written files). The files are NWB 2.9.0 and matnwb may
    % be 2.10.0; the core types we use are identical, so silence the expected
    % version-mismatch warning here and restore the warning state on return.
    % restoreWarning must stay in scope for the onCleanup callback to fire, so it is
    % intentionally assigned but not referenced.
    warnState = warning('off', 'NWB:Read:AttemptReadWithVersionMismatch');
    restoreWarning = onCleanup(@() warning(warnState));
    nwb = nwbRead(nwbPath, 'ignorecache');

    % --- subject / session metadata ---
    session.animal = upper(strtrim(local_char(local_scalar(nwb.general_subject.subject_id))));
    session.genotype = upper(strtrim(local_char(local_scalar(nwb.general_subject.genotype))));
    try
        session.sex = local_char(local_scalar(nwb.general_subject.sex));
    catch
        session.sex = 'U';
    end
    session.sessionDate = local_date(nwb.session_start_time);

    % --- trials table ---
    trials = nwb.intervals_trials;
    session.trialType = local_cellstr(local_col(trials, 'trialType'));
    session.response = local_double(local_col(trials, 'response'));
    session.result = local_double(local_col(trials, 'result'));
    session.nTrials = numel(session.trialType);

    % --- session_info (processing/metadata/session_info) ---
    sessInfo = local_session_info(nwb);
    session.taskName = local_sifield(sessInfo, 'taskName');
    if isempty(session.taskName)
        session.taskName = local_sifield(sessInfo, 'seshType');
    end
    session.trialMap = local_sifield(sessInfo, 'trialMap');

    % Side-assist flag (string '1'/'true' -> logical true).
    sideAssistStr = local_sifield(sessInfo, 'sideAssist');
    session.sideAssist = ~isempty(sideAssistStr) && (strcmp(sideAssistStr, '1') || strcmpi(sideAssistStr, 'true'));

    % Left-trial probability (default 0.5 if absent / unparseable).
    leftProbStr = local_sifield(sessInfo, 'leftTrialProb');
    session.leftProb = str2double(leftProbStr);
    if isempty(leftProbStr) || isnan(session.leftProb)
        session.leftProb = 0.5;
    end

    % --- opto flag (matches getPerfOverall) ---
    hasOpto = ~isempty(session.trialType) && any(contains(string(session.trialType), 'Opto'));
    session.isOpto = strcmp(session.taskName, 'bodyside6') && hasOpto;
end

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

function dateOut = local_date(startTime)
    % Convert the NWB session_start_time to a calendar date (drop time / timezone).
    if isa(startTime, 'types.untyped.DataStub')
        startTime = startTime.load();
    end
    if isdatetime(startTime)
        dateOut = datetime(year(startTime), month(startTime), day(startTime));
    else
        startStr = local_char(startTime);   % e.g. '2024-01-12T00:00:00-05:00'
        dateOut = datetime(startStr(1:10), 'InputFormat', 'yyyy-MM-dd');
    end
end

function columnData = local_col(trials, name)
    % Load a trials column (standard property or custom vectordata column).
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
        strings = {columnData};
    elseif isstring(columnData)
        strings = cellstr(columnData);
    elseif iscell(columnData)
        strings = columnData;
    else
        strings = cellstr(string(columnData));
    end
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
    fieldValue = local_scalar(sessInfo.vectordata.get(name).data);
    val = local_char(fieldValue);
end
