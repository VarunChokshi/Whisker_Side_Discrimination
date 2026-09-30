%% Find files based on SatellitesViewer files
clear all
% WT animals
% animalID = {'VC030105', 'VC030106', 'VC030107', 'VC030108', 'VC030109', 'VC030110', 'VC030112', 'VC030113', 'VC030114', 'VC030115'};

% KO animals
animalID = { };% Choose a group folder

% Choose a group folder
rootDir = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\SeData\VC0301';
rootInfo = MUtil.Dir2Table(rootDir);
rootInfo(~rootInfo.isdir,:) = [];
rootInfo(1:2,:) = [];

clear groupDirs selectedIdx


% Find content of the group folder and pertinent subforders
groupDirInfo = MUtil.Dir2Table(rootDir);
behavDirInfo = [];


for i = 1 : height(groupDirInfo)
    switch groupDirInfo.name{i}
        case 'LearningBcontrol'
            behavAnimalsInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            if ~isempty(animalID)
                behavAnimalsInfo(~ismember(behavAnimalsInfo.name, animalID),:) = [];
            end
            behavDirInfo = [];
            for j = 1:height(behavAnimalsInfo)
                
                behavDirInfo = [behavDirInfo; MBrowse.Dir2Table(fullfile(behavAnimalsInfo.folder{j}, ...
                    behavAnimalsInfo.name{j}, '*.mat'))];

            end       
    end
end




% Find all data files for each session
dataFileTb = table();
i=0;
for jj = height(behavDirInfo) : -1 : 1
    % Parse the file name of SatellitesViewer log to get session identifiers
    
    behavNameParts = strsplit(behavDirInfo.name{jj}, {'_', '.'});
    if numel(behavNameParts)<4
        continue;
    end
    
    animalId = behavNameParts{3};
    if ~isempty(animalID) && ~ismember(animalId, animalID)
        continue
    end

    i = i+1;
    sessType = behavNameParts{2};
    sessionDatetime = datetime([behavNameParts{4}(1:end-1)], ...
        'InputFormat','yyMMdd', ...
        'Format', 'yyyy-MM-dd');
    subId = behavNameParts{4}(end);
    
    
    dataFileTb.animalId{i} = animalId;
    dataFileTb.sessionDatetime(i) = sessionDatetime;
    dataFileTb.subId{i} = subId;
    
    % Add bControl log file path
    dataFileTb.behavPath{i} = fullfile(behavDirInfo.folder{jj}, behavDirInfo.name{jj});

  
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

clear sessionFullName selectedInd


%% Process data and add them to one master file


seDir = [rootDir, '\learningSEs'];


if ~exist(seDir, 'dir')
    mkdir(seDir);
end


% Loop through selected sessions
for i = find(dataFileTb.isSelected)'
    
    
    % Get a session identifier
    sessionId = [ ...
        dataFileTb.animalId{i} ' ' ...
        datestr(dataFileTb.sessionDatetime(i), 'yyyy-mm-dd') ' ' ...
        dataFileTb.subId{i} ...
        ];
    sessionId = strtrim(sessionId);
    disp(['Start processing data for ' sessionId]);
    subId = dataFileTb.subId{i};  
    sePath = fullfile(seDir, [sessionId  ' se.mat']);
% 
% 
%     if exist(sePath, 'file')
%         continue;
%     end
%     
    
    %Make SE
    se = MSessionExplorer(); 
    %  Add session info

     % Creat session Information 
    
 
    % Add Bcontrol data    
    bct_data = BS.bodyside_switchArray(dataFileTb.behavPath{i}, dataFileTb.sessionDatetime(i));        
    
      

     % Load Bcontrol data amd creat a trial type map     
    disp('Processing Bcontrol data');
    
    BS.Preprocess.BCT2SE(bct_data, se, 0);
    
    fprintf('\n');

      % Save SE
    disp('Saving SE to disk');    
    
    save(sePath, 'se', '-v7.3');   
   
    fprintf('\n');
   
end


clear i sessionId

%% Get all the sessions in dataFile
clear all
animalID = {};
% Choose a group folder
rootDir = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\SeData\VC0301';
figureRoot = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\Fig1';
rootInfo = MUtil.Dir2Table(rootDir);
rootInfo(~rootInfo.isdir,:) = [];
rootInfo(1:2,:) = [];


% Find content of the group folder and pertinent subforders
groupDirInfo = MUtil.Dir2Table(rootDir);
behavDirInfo = [];


for i = 1 : height(groupDirInfo)
    switch groupDirInfo.name{i}
        case 'learningSEs'            
            behavDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            seNames = cellfun(@(x) endsWith(x,'se.mat'),behavDirInfo.name);            
            behavDirInfo(~seNames,:) = [];
            animalNames = cellfun(@(x) strsplit(x, ' '), behavDirInfo.name, 'UniformOutput', false);
            animalNames = cellfun(@(x) x{1}, animalNames, 'UniformOutput',false);
            if ~isempty(animalID)
                behavDirInfo(~ismember(animalNames, animalID),:) = [];
            end

           
        case 'LearningSessInfo'
            sessInfoDirInfo = MBrowse.Dir2Table(fullfile(rootDir, groupDirInfo.name{i}, '*.xlsx'));               
            
    end
end




% Find all data files for each session
dataFileTb = table();
sessRem =[];
for i = height(behavDirInfo) : -1 : 1
    % Parse the file name of SatellitesViewer log to get session identifiers
    behavNameParts = strsplit(behavDirInfo.name{i}, {' ', '.'});
    animalId = behavNameParts{1};
%     if ~ismember(animalId, animalID)
%         continue
%     end
    sessionDatetime = datetime(behavNameParts{2}, ...
        'Format', 'yyyy-MM-dd');
    subId = behavNameParts{3};
    
    
    dataFileTb.animalId{i} = animalId;
    dataFileTb.sessionDatetime(i) = sessionDatetime;
    dataFileTb.subId{i} = subId;
    
    % Add bControl log file path
    dataFileTb.sePath{i} = fullfile(behavDirInfo.folder{i}, behavDirInfo.name{i});
    
    % Add sessInfo to data Table
    dataFileTb.sessInfoPaths{i} = [];
    if ~isempty(sessInfoDirInfo)
      
        dataFileTb.sessInfoPaths{i} = fullfile(sessInfoDirInfo.folder{1}, sessInfoDirInfo.name{1});
                  
    end
    
    seshInfoTb = readtable(dataFileTb.sessInfoPaths{i}); 
    aniSeshInforTb = seshInfoTb(ismember(seshInfoTb.AnimalID, {animalId}), :);
   

    % Zero-pad to 6 characters and parse with two-digit year
    s = compose('%06d', aniSeshInforTb.TrainingStartDate);  % e.g., 90105 -> '090105'
    dt = datetime(s, 'InputFormat','yyMMdd', ...
                    ... % adjust pivot as needed
                     'Format','yyyy-MM-dd');



    dataFileTb.TrainingStartDate(i) = dt;
    s = compose('%06d', aniSeshInforTb.EndDate);  % e.g., 90105 -> '090105'
    dt = datetime(s, 'InputFormat','yyMMdd', ...
                ... % adjust pivot as needed
                 'Format','yyyy-MM-dd');
    dataFileTb.TrainingEndDate(i) = dt;
    
    
    
end




%% get performances in datafileTb
for i =1:height(dataFileTb)
    load(dataFileTb.sePath{i})
    perf = struct2table(getPerfOverall(se));
    dataFileTb(i,perf.Properties.VariableNames) = perf;
end

%% remove opto Sessions
isOpto = find(dataFileTb.isOpto);
dataFileTb(isOpto,:) = [];
%% remove sessions not within the training dates

validMask = ~ismissing(dataFileTb.sessionDatetime) & ~ismissing(dataFileTb.TrainingStartDate) & ~ismissing(dataFileTb.TrainingEndDate) & ...
            dataFileTb.sessionDatetime >= dataFileTb.TrainingStartDate & dataFileTb.sessionDatetime <= dataFileTb.TrainingEndDate;
find(~validMask)

invalidTable = dataFileTb(find(~validMask),:);
% Filter table (remove invalid entries)
dataFileTb = dataFileTb(validMask, :);

%% remove sessions when SA was on or LeftStimProb~=0.5
invalidMask = dataFileTb.sideAssist | dataFileTb.leftStimProb == 0 | dataFileTb.leftStimProb == 1;
find(invalidMask)
dataFileTb(invalidMask, :) = [];


%% calculate number of sessions for each mouse
uAnimalId = unique(dataFileTb.animalId);
numSesses = zeros(numel(uAnimalId),1);
for ani = 1:numel(uAnimalId)

    aniTb = dataFileTb(ismember(dataFileTb.animalId, uAnimalId(ani)), :);
    numSesses(ani) = height(aniTb);
end

WTMice = cellfun(@(x) strcmp(x(6), '1'), uAnimalId);
WTNumSess = numSesses(WTMice);
KONumSess = numSesses(~WTMice);


g1 = figure(1);clf
set(g1, 'Units', 'centimeters', 'Position', [50, 50, 33, 38]/10);
hold on;
errorbar(1, mean(WTNumSess), std(WTNumSess)/sqrt(numel(WTNumSess)), '.', 'MarkerSize',20, ...
                    'LineWidth', 1, 'Color', [0.5 0.5 0.5],'CapSize',0, 'LineWidth', 2);
errorbar(2, mean(KONumSess), std(KONumSess)/sqrt(numel(KONumSess)), '.', 'MarkerSize',20, ...
                    'LineWidth', 1, 'Color', [0 0 0],'CapSize',0, 'LineWidth', 2);
xlim([0,3])
xticks([1,2])
xticklabels({'WT', 'KO'})
ylabel('Number of sessions')
ylim([0,40])
set(gca, 'FontName', 'Arial', 'Fontsize', 8)
exportgraphics(g1, fullfile(figureRoot, 'Learning.pdf'), 'Resolution', 300);
exportgraphics(g1, fullfile(figureRoot, 'Learning.png'), 'Resolution', 300);

[h,pT]        = ttest2(WTNumSess, KONumSess, 'Vartype', 'unequal');
[pRS,~,stats] = ranksum(WTNumSess, KONumSess, 'tail', 'both');

% --- write statistics to Learning.txt ---
fid = fopen(fullfile(figureRoot, 'Learning.txt'), 'w');
fprintf(fid, 'Learning Num sessions to reach expert level:\n');
fprintf(fid, 'ttest unequal variance, p = %.4f\n', pT);
fprintf(fid, 'ranksum wilcoxon mann-whitney u test\n');
fprintf(fid, 'p = %.4f\n\n', pRS);
fprintf(fid, 'WT mean = %.3f Std Error = %.3f\n', mean(WTNumSess), std(WTNumSess)/sqrt(numel(WTNumSess)));
fprintf(fid, 'KO mean = %.3f Std Error = %.3f\n\n', mean(KONumSess), std(KONumSess)/sqrt(numel(KONumSess)));
fprintf(fid, 'WT n = %d, per-mouse counts: %s\n', numel(WTNumSess), mat2str(WTNumSess'));
fprintf(fid, 'KO n = %d, per-mouse counts: %s\n', numel(KONumSess), mat2str(KONumSess'));
fclose(fid);

%% Helper functions






function perf = getPerfOverall(se)
    % perf = [correctFrac, incorrectFrac, missFrac, leftStimAmp, leftDur, leftStimFreq,  ...
    % rightStimFreq, rightStimAmp, rightStimDur, sideAssist, leftStimProb, maskingFlash, PSNLT]
    behavData = se.GetTable('behavValue');
    stimRight = behavData.rightStimType{end};
    stimLeft = behavData.leftStimType{end};
    
    responses = cell2mat(behavData.response);
    % remove abort trials
    abortTrials = responses ==3;
    behavData(abortTrials,:) = [];

   
    
    
    
     %remove catch trials
    result = behavData.result;
    responses = cell2mat(behavData.response);
    catchTrials = isnan(result) & responses~=0;
    behavData(catchTrials,:) = [];

    % remove optoTrials
    tt = fieldnames(se.userData.bctData);
    perf.taskName = tt{1}(1:9);

    if strcmp(perf.taskName, 'bodyside6')
        trialType = behavData.trialType;
        isOpto = cell2mat(cellfun(@(x) sum(ismember(x,'Opto'))>=4, trialType, 'UniformOutput', false));
        if ~isempty(find(isOpto))
            perf.isOpto =1; 
        else
            perf.isOpto =0;
        end
        behavData(isOpto,:) = [];
    end
    
    %separate miss trials
    responses = cell2mat(behavData.response);
    missTrials = find(responses==0);
    
    missData = behavData(missTrials, :);
    behavData(missTrials,:) = [];

    result = behavData.result;
    
    
    correctTrials = find(result);
    try
        incorrectTrials = find(~result);
    catch
        keyboard;
    end 

    missTrials = find(~cell2mat(missData.response));
    
    perf.correctFrac = height(correctTrials)/(height(correctTrials)+height(incorrectTrials));
    perf.incorrectFrac = height(incorrectTrials)/(height(correctTrials)+height(incorrectTrials));
    
  
    perf.missFrac = height(missTrials)/(height(missTrials)+height(correctTrials)+height(incorrectTrials));
    
    perf.rightStim = cellstr(stimRight);

    if sum(ismember(stimRight, 'Cyc'))>2
        [perf.stimRightAmp, perf.stimRightFreq, perf.stimRightDur] = bodyside5Stims(stimRight);
        [perf.stimLeftAmp, perf.stimLeftFreq, perf.stimLeftDur]  = bodyside5Stims(stimLeft);
    else
        [perf.stimRightAmp, perf.stimRightFreq, perf.stimRightDur] = bodyside6Stims(stimRight);
        [perf.stimLeftAmp, perf.stimLeftFreq, perf.stimLeftDur] = bodyside6Stims(stimLeft);
    end
    perf.leftStim = cellstr(stimLeft);

    
    perf.sideAssist =  ~strcmp(se.userData.bctData.TrialTypeSection_SideAssist, 'No');
    
   
    if isfield(se.userData.bctData, 'TrialTypeSection_MaskingFlash')
        perf.maskingFlash = se.userData.bctData.TrialTypeSection_MaskingFlash;
    else
        perf.maskingFlash = 0;
    end

    if isfield(se.userData.bctData, 'TrialTypeSection_PreStimNoLickTime')
        perf.PSNLT = se.userData.bctData.TrialTypeSection_PreStimNoLickTime;
    else
        perf.PSNLT = 0.01;
    end
    perf.leftStimProb = se.userData.bctData.TrialTypeSection_LeftTrialProb;
    


end

function [amp, freq, dur] = bodyside5Stims(stim)

    qPos = find(ismember(stim, 'q'));
    freq = str2num(stim(qPos+1:qPos+2));

    dur = str2num(stim(end))*1000/freq; % ms
    
    mpos = find(ismember(stim, 'm'));
    amp = str2num(stim(mpos+4:mpos+6));
    if amp==0
        amp = 1000;
    end

end

function [amp, freq, dur] = bodyside6Stims(stim)

    qPos = find(ismember(stim, 'q'));
    freq = str2num(stim(qPos+1:qPos+2));

    dur = str2num(stim(end-2:end));    
    if dur == 0
        dur = 1000; %ms
    end

    mpos = find(ismember(stim, 'm'));
    amp = str2num(stim(mpos+4:mpos+6));
    if amp==0
        amp = 1000;
    end

end


