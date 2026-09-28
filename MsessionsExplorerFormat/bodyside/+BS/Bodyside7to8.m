% convert duration to cycs for VC030206

clear all
animalID = {'VC030107'};
% Choose a group folder
rootDir = 'G:\VC03_RoboKO';
rootInfo = MUtil.Dir2Table(rootDir);
rootInfo(~rootInfo.isdir,:) = [];
rootInfo(1:2,:) = [];
groupDirs = cellfun(@fullfile, rootInfo.folder, rootInfo.name, 'Uni', false);

selectedIdx = listdlg('PromptString', 'Select sessions to proceed: ', ...
    'ListSize', [300 400], ...
    'ListString', groupDirs);

if ~isempty(selectedIdx)
    groupDir = groupDirs{selectedIdx};
else
    groupDir = MBrowse.Folder(rootDir, 'Select the group folder');
end

if ~groupDir
    return;
end

clear groupDirs selectedIdx


% Find content of the group folder and pertinent subforders
groupDirInfo = MUtil.Dir2Table(groupDir);
behavDirInfo = [];


for i = 1 : height(groupDirInfo)
    switch groupDirInfo.name{i}
        case 'StimSEs_2_5msFR'            
            behavDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            seNames = cellfun(@(x) endsWith(x,'enriched.mat'),behavDirInfo.name);            
            behavDirInfo(~seNames,:) = [];
            animalNames = cellfun(@(x) strsplit(x, ' '), behavDirInfo.name, 'UniformOutput', false);
            animalNames = cellfun(@(x) x{1}, animalNames, 'UniformOutput',false);
            behavDirInfo(~ismember(animalNames, animalID),:) = [];

           
        case 'StimInfo'
            sessInfoDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}, '*.csv'));               
            animalNames= cellfun(@(x) strsplit(x, '_'), sessInfoDirInfo.name, 'UniformOutput', false);
            animalNames = cellfun(@(x) x{1}, animalNames, 'UniformOutput',false);
            sessInfoDirInfo(~ismember(animalNames, animalID),:) = [];
        
    end
end




% Find all data files for each session
dataFileTb = table();

for i = height(behavDirInfo) : -1 : 1
    % Parse the file name of SatellitesViewer log to get session identifiers
    behavNameParts = strsplit(behavDirInfo.name{i}, {' ', '.'});
    animalId = behavNameParts{1};
    if ~ismember(animalId, animalID)
        continue
    end
    sessionDatetime = datetime(behavNameParts{2}(1:end-1), ...
        'Format', 'yyyy-MM-dd');
    subId = behavNameParts{2}(end);
    
    
    dataFileTb.animalId{i} = animalId;
    dataFileTb.sessionDatetime(i) = sessionDatetime;
    dataFileTb.subId{i} = subId;
    
    % Add bControl log file path
    dataFileTb.sePath{i} = fullfile(behavDirInfo.folder{i}, behavDirInfo.name{i});
    
    % Add sessInfo to data Table
    dataFileTb.sessInfoPaths{i} = [];
    if ~isempty(sessInfoDirInfo)
        queryStr = ['^' animalId '.+'];
        isHit = ~cellfun(@isempty, regexpi(sessInfoDirInfo.name, queryStr));
        if any(isHit)
            dataFileTb.sessInfoPaths{i} = fullfile(sessInfoDirInfo.folder{isHit}, sessInfoDirInfo.name{isHit});
        end            
    end
    
    seshInfoTb = readtable(dataFileTb.sessInfoPaths{i}); 
    seshInfoTb.seshDate = arrayfun(@(x) datetime(x, 'InputFormat','yyMMdd', ...
        'Format', 'yyyy-MM-dd'), string(seshInfoTb.seshDate), 'UniformOutput', false); 
    
    ind = ismember(cellfun(@datenum, seshInfoTb.seshDate), datenum(dataFileTb.sessionDatetime(i))) & subId == cell2mat(seshInfoTb.subId);
    seshInfoTb = seshInfoTb(ind,:);     
    dataFileTb(i,seshInfoTb.Properties.VariableNames) = seshInfoTb;
end



    
% Select sessions for final output
dataFileTb.isSelected = false(height(dataFileTb), 1);

sessionFullName = cellfun(@(x,y,z) strtrim([x ' ' datestr(y, 'yyyy-mm-dd') ' ' z]), ...
    dataFileTb.animalId, ...
    num2cell(dataFileTb.sessionDatetime), ...
    dataFileTb.subId, ...
    'Uni', false);

selectedInd = listdlg('PromptString', 'Select sessions to proceed: ', ...
    'SelectionMode', 'multi', ...
    'ListSize', [300 400], ...
    'ListString', sessionFullName);

dataFileTb.isSelected(selectedInd) = true;
dataFileTb(~dataFileTb.isSelected,:) =[];

%%
for sessNum = 1:height(dataFileTb)
    load(dataFileTb.sePath{sessNum});
    
    behavData = se.GetTable('behavValue');
    % find half cycs to remove
    leftStimType = behavData.leftStimType;
    halfDursL = cell2mat(cellfun(@(x) str2num(x(end-2:end))<50, leftStimType, 'UniformOutput', false));
    rightStimType = behavData.rightStimType;
    halfDursR = cell2mat(cellfun(@(x) str2num(x(end-2:end))<50, rightStimType, 'UniformOutput', false));
    remTrials= halfDursR | halfDursL;
    trialRemove = find(remTrials);
    se.RemoveEpochs(trialRemove);

    behavData = se.GetTable('behavValue');
    leftStimType = behavData.leftStimType;
    rightStimType = behavData.leftStimType;
    uStimTypes = unique(leftStimType);
    newStimTypes = [{'Freq20Cyc1SineAmp1p000'};{'Freq20Cyc2SineAmp1p000'};{'Freq20Cyc3SineAmp1p000'}];
    for stimType =1: numel(uStimTypes)
        stimTypeTrialsL = cell2mat(cellfun(@(x) strcmp(uStimTypes{stimType}, x),leftStimType, 'UniformOutput',false));
        behavData.leftStimType(stimTypeTrialsL) = repmat(newStimTypes(stimType), [numel(find(stimTypeTrialsL)),1]);

        stimTypeTrialsR = cell2mat(cellfun(@(x) strcmp(uStimTypes{stimType}, x),rightStimType, 'UniformOutput',false));
        behavData.rightStimType(stimTypeTrialsR) = repmat(newStimTypes(stimType), [numel(find(stimTypeTrialsR)),1]);
    end
        
    se.RemoveTable('behavValue');
%     behavData(205:end,:) = [];
    se.SetTable('behavValue',behavData, 'eventValues');
    se.userData.sessionInfo.APStim{1} = dataFileTb.APStim{sessNum};
    save(dataFileTb.sePath{sessNum}, 'se', '-v7.3');   
end