%% Script to make Figure1
%%


%%
clear all
animalID = {};

% Choose a group folder

projectDir = 'E:/oconnorlab Dropbox/oconnorlab Team Folder/manuscripts/bodyside_S1';
rootDir = fullfile(projectDir, 'SeData');
figureRoot = fullfile(projectDir, 'Fig1');
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
        case 'NoOptoSess'            
            behavDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            seNames = cellfun(@(x) endsWith(x,'se.mat'),behavDirInfo.name);            
            behavDirInfo(~seNames,:) = [];
            animalNames = cellfun(@(x) strsplit(x, ' '), behavDirInfo.name, 'UniformOutput', false);
            animalNames = cellfun(@(x) x{1}, animalNames, 'UniformOutput',false);
            if ~isempty(animalID)
                behavDirInfo(~ismember(animalNames, animalID),:) = [];
            end

           
        case 'SessInfoNoOpto'
            sessInfoDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}, '*.csv'));               
            animalNames= cellfun(@(x) strsplit(x, '_'), sessInfoDirInfo.name, 'UniformOutput', false);
            animalNames = cellfun(@(x) x{1}, animalNames, 'UniformOutput',false);
            if ~isempty(animalID)
                sessInfoDirInfo(~ismember(animalNames, animalID),:) = [];
            end
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
    try
        dataFileTb(i,seshInfoTb.Properties.VariableNames) = seshInfoTb;
    catch
        sessRem = [sessRem; i];
        continue;
    end
end


dataFileTb(sessRem,:) =[];
    
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

dataFileTb(~dataFileTb.isSelected, :) = [];
% clear sessionFullName selectedInd
% get performances in datafileTb
for i =1:height(dataFileTb)
    load(dataFileTb.sePath{i})
    perf = struct2table(getPerfOverall(se));
    dataFileTb(i,perf.Properties.VariableNames) = perf;
end

%% only keep mice with bodyside 6
correctTask = zeros(height(dataFileTb), 1);
for sess = 1:height(dataFileTb)
    taskName = dataFileTb{sess, 'taskName'};
    if strcmp(taskName, 'bodyside6')
        correctTask(sess) = 1;
    end
end
        

dataFileTb(~correctTask, :)=[];




%% Plot fraction bootstrapped for each mouse for WT and KO with Left Stim and Right stim for non opto Trials
% Multilevel_bootstrap
% resample mice with replacement
% resample session with replacement
% resample trials with replacement 
% 
% clear all
close all
trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
trials{2} = {'Stim_Som_Left', 'Stim_Som_Left_Opto', 'Stim_Som_Right', 'Stim_Som_Right_Opto'}; 

try 
    readPaths = dataFileTb.sePath;
catch
end

readPathParts = cellfun(@(x) strsplit(x, '\'), readPaths, 'UniformOutput', false);
seDir = fullfile(readPathParts{1}{1:end-2});
seNames = cellfun(@(x) x(end), readPathParts, 'UniformOutput',false);
clearvars -except readPaths dataFileTb readPathParts seDir seNames animalID trials figureRoot;

animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
AnimalIDs = cellfun(@(x) x{1}, animal, 'UniformOutput', false);
animalID = unique(AnimalIDs);

pathParts = strsplit(seDir, '\');

savePath = (fullfile(figureRoot,'No inhibition'));
if ~exist(savePath, 'dir')
    mkdir(savePath);
end

photoInhAll = table();

% Accumulate session data per mouse (no optogenetic inhibition in this experiment)
for animalNum = 1:size(animalID,1)
    ani = animalID{animalNum}; 
    sessNum = 1;
    for i = find(ismember(AnimalIDs, ani))'        
        load(readPaths{i});

        trialMap = se.userData.sessionInfo.trialMap;
        if ~isempty(trialMap{1})
            % trialMap can hold multiple start:stop ranges, e.g. '1:240:260:end'
            % keeps trials 1-240 AND 260-end. Walk the colon-separated tokens two at
            % a time so every range is kept.
            trialSplit = strsplit(trialMap{1}, ':');
            nPairs = floor(numel(trialSplit) / 2);
            rangeCells = cell(1, nPairs);
            for pairInd = 1:nPairs
                startTrial = str2double(regexprep(trialSplit{2*pairInd - 1}, '\D', ''));
                stopToken = regexprep(trialSplit{2*pairInd}, '''', '');
                if strcmpi(strtrim(stopToken), 'end')
                    stopTrial = se.numEpochs;
                else
                    stopTrial = str2double(regexprep(stopToken, '\D', ''));
                end
                rangeCells{pairInd} = startTrial:stopTrial;
            end
            trialInd = [rangeCells{:}];
            se = BS.Preprocess.keepTrials(trialInd, se);
        end
        
        behavData = se.GetTable('behavValue');
        behavData.mouseName = upper(behavData.mouseName);
        
        % Remove aborted trials due to pre-stim no-lick-time licks
        responses = behavData.response;
        abortTrials = find(cell2mat(responses) == 3); 
        behavData(abortTrials,:) = [];
        
        % Identify missed trials vs scored trials
        responses = behavData.result;
        missTrials = isnan(responses);
        missData = behavData(missTrials,:);
        
        trialTypes = unique(behavData.trialType);
        if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
            trialTypes = trials{2};
        else
            trialTypes = trials{1};
        end

        for trialType = 1:numel(trialTypes)
            trialTypeInd = strcmp(trialTypes{trialType}, behavData.trialType);
            fracResult{animalNum}{sessNum}(trialType) = mean(behavData.result(trialTypeInd));
            missFrac{animalNum}{sessNum}(trialType) = numel(find(strcmp(trialTypes{trialType}, missData.trialType))) / ...
                (numel(find(strcmp(trialTypes{trialType}, missData.trialType))) + numel(find(strcmp(trialTypes{trialType}, behavData.trialType))));
            allTrialTypes{animalNum}{sessNum} = trialTypes;
        end 

        % Ensure Genotype and standard metadata columns exist in behavData
        if ~ismember('Genotype', behavData.Properties.VariableNames)
            if exist('dataFileTb', 'var') && ismember('Genotype', dataFileTb.Properties.VariableNames) && ~isempty(dataFileTb.Genotype{i})
                behavData.Genotype = repmat(dataFileTb.Genotype(i), height(behavData), 1);
            elseif startsWith(ani, 'VC0301')
                behavData.Genotype = repmat({'WT'}, height(behavData), 1);
            else
                behavData.Genotype = repmat({'KO'}, height(behavData), 1);
            end
        end
        
        if ~ismember('inhSite', behavData.Properties.VariableNames)
            behavData.inhSite = repmat({'NA'}, height(behavData), 1);
        end
        
        if ~ismember('isInhibition', behavData.Properties.VariableNames)
            behavData.isInhibition = zeros(height(behavData), 1);
        end

        % Align columns with photoInhAll to ensure vertcat compatibility
        if ~isempty(photoInhAll)
            missingColumns = setdiff(photoInhAll.Properties.VariableNames, behavData.Properties.VariableNames);
            for colInd = 1:numel(missingColumns)
                targetCol = missingColumns{colInd};
                if iscell(photoInhAll.(targetCol))
                    behavData.(targetCol) = repmat({''}, height(behavData), 1);
                else
                    behavData.(targetCol) = nan(height(behavData), 1);
                end
            end
            extraColumns = setdiff(behavData.Properties.VariableNames, photoInhAll.Properties.VariableNames);
            if ~isempty(extraColumns)
                behavData(:, extraColumns) = [];
            end
            behavData = behavData(:, photoInhAll.Properties.VariableNames);
        end

        photoInhAll = [photoInhAll; behavData];
        sessNum = sessNum + 1;
    end
end

Genotypes = unique(photoInhAll.Genotype); 
trialTypes = unique(photoInhAll.trialType);
mice = unique(photoInhAll.mouseName);
        
if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
    % Remove opto trials if any exist
    trialTypes = photoInhAll.trialType;
    optoTrials = find(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)));
    photoInhAll(optoTrials, :) = [];
    Genotypes = unique(photoInhAll.Genotype); 
    trialTypes = unique(photoInhAll.trialType);
    mice = unique(photoInhAll.mouseName);    
else
    trialTypes = trials{1};
end 

%% Multilevel bootstrap per genotype (no inhibition site loop)
nboot = 1000;
trialTypeFields = {'leftStimType', 'rightStimType'};

tic
for g = 1:length(Genotypes)
    Genotype = Genotypes{g};
    u = photoInhAll(strcmp(photoInhAll.Genotype, Genotype), :);
    
    mouseNames = unique(u.mouseName);
    if isempty(mouseNames)
        continue;
    end
        
        overallMeanPerf  = cell(length(mouseNames) , 1);
        overallMeanMiss  = cell(length(mouseNames) , 1);
        overallOmeanPerf = nan(length(mouseNames) , 1);
        overallOmeanMiss = nan(length(mouseNames) , 1);
        for mouse = 1:length(mouseNames) 
            m = u(strcmp(u.mouseName, mouseNames{mouse}), :);
            dateData = cellfun(@(x) datestr(x, 'yyyymmdd'), m.sessDate, 'UniformOutput',false);
            sessions = unique(dateData);
            m.sessDate = dateData;
            
            behavData = m;
    
            responses = behavData.result;
            missTrials = isnan(responses);
            missData = behavData(missTrials,:);
            behavData(missTrials, :) =[];
            overallOmeanPerf(mouse,1) = mean(behavData.result); % lick probability of each trial type 
            overallOmeanMiss(mouse,1) = height(missData)/(height(missData) + height(behavData)); 

            for trialType=1:numel(trialTypes)           
                            
                        % get trialtype indices so that performance can be calculated for that trialType      
                        trialInds = find(strcmp(trialTypes{trialType}, m.trialType));
                        if isempty(trialInds)
                            tTypes = {'Stim_Som_Left_NoCue', 'Stim_Som_Right_NoCue'};
                            trialInds = find(strcmp(tTypes{trialType}, m.trialType));
                        else
                            tTypes = trialTypes;
                        end                 
                        
    %                     if isempty(trialInds)
    %                         tTypes = {'Stim_Som_Left_NoCue', 'Stim_Som_Right_NoCue'};
    %                         trialInds = find(strcmp(tTypes{trialType}, v.trialType));
    %                     else
    %                         tTypes = trialTypes;
    %                     end                 
                        
                        behavData = m(trialInds,:);
    
                        responses = behavData.result;
                        missTrials = isnan(responses);
                        missData = behavData(missTrials,:);
                        behavData(missTrials, :) =[];
                        overallMeanPerf{mouse,1}(1,trialType) = mean(behavData.result); % lick probability of each trial type 
                        overallMeanMiss{mouse,1}(1,trialType) = height(missData)/(height(missData) + height(behavData)); 
            end
            

            


            % here we have all the sessions and trials from one mouse. 
            
            rng(7);
            
            overallPerf = nan(nboot,1);
            overallMiss = nan(nboot,1);
            trialPerf = cell(nboot,1); 
            trialMiss = cell(nboot,1); 
            trialAmp = cell(nboot,1); 
            parfor n = 1:nboot 
                sess_overallPerf = nan(numel(sessions),1);
                sess_overallMiss = nan(numel(sessions),1);
                sess_trialPerf = cell(numel(sessions),1); 
                sess_trialMiss = cell(numel(sessions),1); 
                sess_trialAmp = cell(numel(sessions),1); 
                randSessions = randi(height(sessions), 1, height(sessions));
                for sessNum =1:numel(randSessions)
                    s = m(strcmp(sessions(randSessions(sessNum)), m.sessDate), :); 

                    % Now we will select trials on random with repalcemetn from all the sessions. 
                    % So total trial nums will be trialSessA + trial SessB +....
                    randTrials = randi(height(s), 1, height(s)); 
                    
                    v = s(randTrials,:); 
                    responses = v.result;
                    vmissTrials = isnan(responses);
                    vmissData = v(vmissTrials,:);
                    behavData = v(~vmissTrials,:);
                    sess_overallPerf(sessNum,1) = mean(behavData.result);
                    sess_overallMiss(sessNum,1) = height(vmissData)/height(v);                            
                    
                    
                    
                    % Now we need to calculate 3 terms for performance. Overall
                    % Perf, Perf for left stim and Perf for right Stims
                    % Same thing for miss Data
    
                    for trialType=1:numel(trialTypes)           
                            
                        % get trialtype indices so that performance can be calculated for that trialType      
                        trialInds = find(strcmp(trialTypes{trialType}, v.trialType));
                        if isempty(trialInds)
                            tTypes = {'Stim_Som_Left_NoCue', 'Stim_Som_Right_NoCue'};
                            trialInds = find(strcmp(tTypes{trialType}, v.trialType));
                        else
                            tTypes = trialTypes;
                        end                 
                        
                        behavData = v(trialInds,:);
                        responses = behavData.result;
                        missTrials = isnan(responses);
                        missData = behavData(missTrials,:);
                        behavData(missTrials, :) =[];
                        sess_trialPerf{sessNum,1}(1,trialType) = mean(behavData.result); % lick probability of each trial type 
                        sess_trialMiss{sessNum,1}(1,trialType) = height(missData)/(height(missData) + height(behavData)); 
                        
                        % need to figure out how to get all the amplitudes. 
                        
                        stimType = table2cell(behavData(:,trialTypeFields{trialType}));
                        
                        if sum(ismember(stimType{1}, 'Cyc'))>2
                            sess_trialAmp{sessNum,1}(1,trialType) = mean(cell2mat(cellfun(@(x) bodyside5Stims(x), stimType, 'UniformOutput', false)));                        
                        else
                           sess_trialAmp{sessNum,1}(1,trialType) = mean(cell2mat(cellfun(@(x) bodyside6Stims(x), stimType, 'UniformOutput', false))); 
                        end
                       
                    end

                    
                
                end
                overallPerf(n,1) = mean(sess_overallPerf,1);
                overallMiss(n,1) = mean(sess_overallMiss,1);
                trialPerf{n,1} = mean(cell2mat(sess_trialPerf),1);
                trialMiss{n,1} = mean(cell2mat(sess_trialMiss),1);
                trialAmp{n,1} = mean(cell2mat(sess_trialAmp),1);
            end
            
            fracCorrect_mouse{mouse} = [overallPerf, cell2mat(trialPerf), cell2mat(trialAmp)]; 
            fracMiss_mouse{mouse} = [overallMiss, cell2mat(trialMiss), cell2mat(trialAmp)];
          
        end

        % Store per-genotype tables (no inhibition site in this experiment)
        photoInh_bootstrapped{g,1} = Genotype;
        photoInh_bootstrapped{g,2} = 'None';
        photoInh_bootstrapped{g,3} = fracCorrect_mouse;        
        photoInh_bootstrapped_miss{g,1} = Genotype;
        photoInh_bootstrapped_miss{g,2} = 'None';
        photoInh_bootstrapped_miss{g,3} = fracMiss_mouse;  

        photoInh{g,1} = Genotype;
        photoInh{g,2} = 'None';
        photoInh{g,3} = overallOmeanPerf;     
        photoInh{g,4} = cell2mat(overallMeanPerf);        
        photoInh_miss{g,1} = Genotype;
        photoInh_miss{g,2} = 'None';
        photoInh_miss{g,3} = overallOmeanMiss;     
        photoInh_miss{g,4} = cell2mat(overallMeanMiss); 

        clearvars fracCorrect_mouse fracMiss_mouse
end
toc




%% Calculate mean per genotpye and trialType for all animals
confidencelevel = 0.95;
alpha = 1- confidencelevel;
clearvars meanStats SEM ts ciStats ciStats_miss ts_miss SEM_miss meanstats_miss

for genotype = 1:height(photoInh_bootstrapped)
    for mouse = 1:numel(photoInh_bootstrapped{genotype,3})
        for field = 1:width(photoInh_bootstrapped{genotype,3}{mouse})
           fieldData = photoInh_bootstrapped{genotype,3}{mouse}(:,field);
           % normality Anderson-Darling test
           h = adtest(fieldData, 'Alpha', alpha);           
            % Display the test result
            if h
                disp(['The data does not follow a normal distribution for genotype = '  photoInh_bootstrapped{genotype,1} ...
                    ' mouse: ' num2str(mouse) ' field: ' num2str(field)]);
            else
                disp(['The data follows a normal distribution for genotype = '  photoInh_bootstrapped{genotype,1} ...
                    ' mouse: ' num2str(mouse) ' field: ' num2str(field)]);
            end
            
           photoInh_bootstrapped{genotype,3 + 3*field -2}(mouse) = mean(photoInh_bootstrapped{genotype,3}{mouse}(:,field));
           photoInh_bootstrapped_miss{genotype,3 + 3*field -2}(mouse) = mean(photoInh_bootstrapped_miss{genotype,3}{mouse}(:,field));
            
           sortedField = sort(photoInh_bootstrapped{genotype,3}{mouse}(:,field),1);
           photoInh_bootstrapped{genotype,3 + 3*field -1}(1:3, mouse) = [mean(photoInh_bootstrapped{genotype,3}{mouse}(:,field)), ...
               sortedField(round(nboot*0.025)),  sortedField(round(nboot*0.975))];
            
           sortedField_miss = sort(photoInh_bootstrapped_miss{genotype,3}{mouse}(:,field),1);
           photoInh_bootstrapped_miss{genotype,3 + 3*field -1}(1:3, mouse) = [mean(photoInh_bootstrapped_miss{genotype,3}{mouse}(:,field)), ...
               sortedField_miss(round(nboot*0.025)),  sortedField_miss(round(nboot*0.975))];


            SEM = std(photoInh_bootstrapped{genotype,3}{mouse}(:,field))/sqrt(height(photoInh_bootstrapped{genotype,3}{mouse}));         
            ts = tinv([alpha/2 1-alpha/2], numel(photoInh_bootstrapped{genotype,3}{mouse}(:,field))-1);        
            photoInh_bootstrapped{genotype,3 + 3*field}(1:2,mouse) = ts*SEM;
    
    
            SEM = std(photoInh_bootstrapped_miss{genotype,3}{mouse}(:,field))/sqrt(numel(photoInh_bootstrapped_miss{genotype,3}{mouse}(:,field)));         
            ts = tinv([alpha/2 1-alpha/2], numel(photoInh_bootstrapped_miss{genotype,3}{mouse}(:,field))-1);        
            photoInh_bootstrapped_miss{genotype,3 + 3*field }(1:2,mouse) = ts*SEM;
        end
    end
    
end
            

vars = {'Genotype', 'InhSite', 'AllData', 'MeanStats_overall','CIstats_overall','CIstats2_overall',  'Meanstats_left','CI_left', 'CI2_Left', 'Meanstats_right', 'CI_right','CI2_Right', 'Amp_left', 'CIAmp_left','CIAmp2_left', 'Amp_Right','CIAmp_right', 'CIAmp2_right'};
photoInhBootstrapped = cell2table(flip(photoInh_bootstrapped),'VariableNames', vars);

% vars_miss = {'Genotype', 'InhSite', 'AllData', 'MeanStats_overall','CIstats_overall', 'Meanstats_left','CI_left', 'Meanstats_right', 'CI_right', 'Amp_left', 'Amp_Right'};
photoInhBootstrapped_miss = cell2table(flip(photoInh_bootstrapped_miss),'VariableNames', vars);


vars = {'Genotype', 'InhSite', 'MeanOverall', 'MeanEachTrialType'};
photoInhTable = cell2table(flip(photoInh),'VariableNames', vars);

% vars_miss = {'Genotype', 'InhSite', 'AllData', 'MeanStats_overall','CIstats_overall', 'Meanstats_left','CI_left', 'Meanstats_right', 'CI_right', 'Amp_left', 'Amp_Right'};
photoInhTable_miss = cell2table(flip(photoInh_miss),'VariableNames', vars);




%% save the two tables

save(fullfile(figureRoot, 'AllVars_nboot1000_260903.mat'), 'photoInhTable', 'photoInhTable_miss', 'photoInhBootstrapped_miss', 'photoInhBootstrapped', 'figureRoot', 'dataFileTb');



%% load processed data
clear all
figureRoot = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\Fig1';
load(fullfile(figureRoot, 'AllVars_nboot1000_260903.mat'))
figureRoot = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\Fig1_v2';

%% plot figures for overall perf
plotTypes = {'stats_overall', '_left', '_right'};
ylabels = {'Correct fraction excl. misses', 'Correct fraction excl. misses', 'Correct fraction excl. misses', 'Amplitude (% of maximum)','Amplitude (% of maximum)'};
colors_tt = {[1 0 0] [0 0 1]}; 
close all; 
fileID = fopen(fullfile(figureRoot, 'Fig1behavMeanvals.txt'), 'w');
uGenotypes = photoInhTable.Genotype;
alpha = 0.8;
start_x =20;
% mouseNums{1} = [3:6,8:11];
% mouseNums{2} = [3:4,6:10];
mouseNums{1} = [1:10];
mouseNums{2} = [1:8];

% plot correct fraction
genotypecolors{1} = {[0.5 0.5 0.5]; [1 0 0]; [0 0 1]};
genotypecolors{2} = {[0 0 0]; [1 0 0]; [0 0 1]};
for field = 1:numel(plotTypes)
    g1 = figure(field);clf
    set(g1, 'Units', 'centimeters', 'Position', [50, 50, 33, 38]/10);
    for g=1: height(photoInhBootstrapped)
        colors = genotypecolors{g};
        h = subplot(1,1,1);
        hold on 
    
        mouseNum = numel(mouseNums{g});
        x = ((start_x  +(g-1)*250)  + 15*[1:mouseNum]);
        if any(ismember(field, [4,5]))
    
        else            
            ci = photoInhBootstrapped{g,['CI' plotTypes{field}]}{1,1}(:,mouseNums{g});            
            hh =errorbar(x,ci(1,:),ci(1,:) - ci(2,:), ci(3,:)- ci(1,:),'o',...
                'MarkerSize',10, 'Color', colors{field}, 'MarkerEdgeColor', colors{field}, 'LineWidth', 1, 'CapSize', 0);  
            set(hh, 'Marker', 'none')
            
            set([hh.Bar, hh.Line], 'ColorType', 'truecoloralpha', 'ColorData', [hh.Line.ColorData(1:3); 255*alpha]);
    
            if field ==1
                meanField = photoInhTable{g,'MeanOverall'}{1}(mouseNums{g});
                scatter(x,meanField,10,'o',  'Color', colors{field}, 'MarkerEdgeColor', colors{field}, 'LineWidth', 1, 'MarkerFaceAlpha', alpha, 'MarkerEdgeAlpha', alpha);
                errorbar(x(end) + 25, mean(meanField), std(meanField), 'both', '.', 'MarkerSize',15, ...
                    'LineWidth', 1, 'Color', [0.5 0 0.5],'CapSize',0);
                animalMean{g} = meanField;
                fprintf(fileID, ['For genotype: ' uGenotypes{g} ' ' plotTypes{field} ' Mean: ' num2str(mean(meanField)) ' SD: ' num2str(std(meanField)) '\n']);
            else
                meanField = photoInhTable{g,'MeanEachTrialType'}{1}(mouseNums{g},field-1);
                scatter(x,meanField,10,'o', 'Color', colors{field}, 'MarkerEdgeColor', colors{field}, 'LineWidth', 1, 'MarkerFaceAlpha', alpha, 'MarkerEdgeAlpha', alpha);
                 errorbar(x(end) + 25, mean(meanField), std(meanField), 'both', '.', 'MarkerSize',15, ...
                    'LineWidth', 1, 'Color', [0 0 0],'CapSize',0);
                 
    %             set(h3, 'MarkerFaceColor', [colors{field} 0.5], 'MarkerEdgeColor', [colors{field} 0.5])
                animalMean{g} = meanField;

                fprintf(fileID, ['For genotype: ' uGenotypes{g} ' ' plotTypes{field} ' Mean: ' num2str(mean(meanField)) ' SD: ' num2str(std(meanField)) '\n']);
            end
        end
            
               
           
    end
   

    
    pval = ranksum(animalMean{1}, animalMean{2});
    fprintf(fileID, ['For plotType: Correct fraction ' plotTypes{field} ' Mann Whitney U pval: ' num2str(pval)  '\n']);
    

    hold off
    set(gca, 'box','off','TickDir','out', 'fontsize', 8, 'FontName', 'Arial');
    if any(ismember(field, [4,5]))
        ylim([0 110])
        yticks(0:10:100)
    else
        ylim([0.4 1]);
        yticks([0,0.1:0.2:0.9,1])
        yline(0.7, '--k', 'color', [112, 41, 99]/255, 'LineWidth', 1);
    end
    ylabel(ylabels{field}, 'fontsize', 8, 'FontName', 'Arial')
%     xtickangle(45);
    xlim([0,max(x)+40]);
    xticks([(start_x  + 75), (start_x  + 325)])
    xticklabels({'WT', 'KO'})
     
    h.LineWidth = 1;
%     title(plotTypes{field});
    savefig(g1,fullfile(figureRoot,['CorrectFraction ' plotTypes{field} ' No inihibtion KO vs WT Correct fraction.fig']));
    exportgraphics(g1,fullfile(figureRoot, ['CorrectFraction ' plotTypes{field} ' No inihibtion KO vs WT Correct fraction.png']));
    exportgraphics(g1,fullfile(figureRoot, ['CorrectFraction ' plotTypes{field} ' No inihibtion KO vs WT Correct fraction.pdf']), 'Resolution', 300);
end

fclose(fileID);


% plot figures for Miss
plotTypes = {'stats_overall', '_left', '_right'};
ylabels = {'Miss fraction', 'Miss fraction', 'Miss fraction', 'Amplitude (% of maximum)','Amplitude (% of maximum)'};
colors_tt = {[1 0 0] [0 0 1]}; 
close all; 
fileID = fopen(fullfile(figureRoot, 'Fig1behavMeanvals.txt'), 'a');
uGenotypes = photoInhTable.Genotype;
alpha = 0.8;
start_x =20;
% mouseNums{1} = [3:6,8:11];
% mouseNums{2} = [3:4,6:10];
% mouseNums{1} = [1:9];
% mouseNums{2} = [1:7];

% plot miss fraction
genotypecolors{1} = {[0.5 0.5 0.5]; [1 0 0]; [0 0 1]};
genotypecolors{2} = {[0 0 0]; [1 0 0]; [0 0 1]};
for field = 1:numel(plotTypes)
    g1 = figure(field);clf
    set(g1, 'Units', 'centimeters', 'Position', [50, 50, 33, 38]/10);
    for g=1: height(photoInhBootstrapped_miss)
        colors = genotypecolors{g};
        h = subplot(1,1,1);
        hold on 
    
        mouseNum = numel(mouseNums{g});
        x = ((start_x  +(g-1)*250)  + 15*[1:mouseNum]);
        if any(ismember(field, [4,5]))
    
        else            
            ci = photoInhBootstrapped_miss{g,['CI' plotTypes{field}]}{1,1}(:,mouseNums{g});            
            hh =errorbar(x,ci(1,:),ci(1,:) - ci(2,:), ci(3,:)- ci(1,:),'o',...
                'MarkerSize',10, 'Color', colors{field}, 'MarkerEdgeColor', colors{field}, 'LineWidth', 1, 'CapSize', 0);  
            set(hh, 'Marker', 'none')
            
            set([hh.Bar, hh.Line], 'ColorType', 'truecoloralpha', 'ColorData', [hh.Line.ColorData(1:3); 255*alpha]);
    
            if field ==1
                meanField = photoInhTable_miss{g,'MeanOverall'}{1}(mouseNums{g});
                scatter(x,meanField,10,'o',  'Color', colors{field}, 'MarkerEdgeColor', colors{field},...
                    'LineWidth', 1, 'MarkerFaceAlpha', alpha, 'MarkerEdgeAlpha', alpha);
                errorbar(x(end) + 25, mean(meanField), std(meanField), 'both', '.', 'MarkerSize',15, ...
                    'LineWidth', 1, 'Color', [0.5 0 0.5],'CapSize',0);
                animalMean{g}=meanField;
                fprintf(fileID, ['For genotype: ' uGenotypes{g} ' ' plotTypes{field} ' Mean: ' num2str(mean(meanField)) ' SD: ' num2str(std(meanField)) '\n']);
            else
                meanField = photoInhTable_miss{g,'MeanEachTrialType'}{1}(mouseNums{g},field-1);
                scatter(x,meanField, 10,'o', 'Color', colors{field}, 'MarkerEdgeColor', colors{field}, 'LineWidth', 1, 'MarkerFaceAlpha', alpha, 'MarkerEdgeAlpha', alpha);
                errorbar(x(end) + 25, mean(meanField), std(meanField), 'both', '.', 'MarkerSize',15, ...
                    'LineWidth', 1, 'Color', [0 0 0],'CapSize',0);
                animalMean{g}=meanField;
                fprintf(fileID, ['For genotype: ' uGenotypes{g} ' ' plotTypes{field} ' Mean: ' num2str(mean(meanField)) ' SD: ' num2str(std(meanField)) '\n']);
            end
        end
            
               
           
    end


    pval = ranksum(animalMean{1}, animalMean{2});
    fprintf(fileID, ['For plotType: Miss fraction ' plotTypes{field} ' Mann Whitney U pval: ' num2str(pval)  '\n']);
    

    hold off
    set(gca, 'box','off','TickDir','out', 'fontsize', 8, 'FontName', 'Arial');
    if any(ismember(field, [4,5]))
        ylim([0 110])
        yticks(0:10:100)
    else
        ylim([0 0.5]);
        yticks([0,0.1:0.2:0.9,1])
        yline(0.7, '--k', 'color', [112, 41, 99]/255, 'LineWidth', 1);
    end
    ylabel(ylabels{field}, 'fontsize', 8, 'FontName', 'Arial')
%     xtickangle(45);
    xlim([0,max(x)+40]);
    xticks([(start_x  + 75), (start_x  + 325)])
    xticklabels({'WT', 'KO'})
     
    h.LineWidth = 1;
%     title(plotTypes{field});
    savefig(g1,fullfile(figureRoot,['MissFraction ' plotTypes{field} ' No inihibtion KO vs WT Correct fraction.fig']));
    exportgraphics(g1,fullfile(figureRoot, ['MissFraction ' plotTypes{field} ' No inihibtion KO vs WT Correct fraction.png']));
    exportgraphics(g1,fullfile(figureRoot, ['MissFraction ' plotTypes{field} ' No inihibtion KO vs WT Correct fraction.pdf']), 'Resolution', 1200);

    
end

fclose(fileID);


% plot figures for Amplitudes
plotTypes = {'Left Stim trials', 'Right Stim trials'};
ylabels = {'Correct fraction', 'Correct fraction', 'Correct fraction', 'Amplitude (% of maximum)','Amplitude (% of maximum)'};
colors_tt = {[1 0 0] [0 0 1]}; 
close all; 
alpha = 1;
fileID = fopen(fullfile(figureRoot, 'Fig1behavMeanvals.txt'), 'a');
start_x =20;
mouseNums{1} = [1:9];
mouseNums{2} = [1:7];
% plot correct fraction
genotypecolors{1} = {[0.5 0.5 0.5]; [1 0 0]; [0 0 1]};
genotypecolors{2} = {[0.5 0.5 0.5]; [1 0 0]; [0 0 1]};
for field = 4:5
    g1 = figure(field-3);clf
    set(g1, 'Units', 'centimeters', 'Position', [50, 50, 33, 38]/10);
    for g=1: height(photoInhBootstrapped)
        colors = genotypecolors{g};
        h = subplot(1,1,1);
        hold on 
    %     mouseNum = numel(photoInhBootstrapped{g,3+3*field-2}{1,1});
        mouseNum = numel(mouseNums{g});
        x = ((start_x  +(g-1)*250)  + 15*[1:mouseNum]);
        if any(ismember(field, [4,5]))
            y = photoInhBootstrapped{g,3+3*field-2}{1,1}(:,mouseNums{g})/10;
            scatter(x,y,10, 'o',  'Color', colors{field-2}, 'MarkerEdgeColor', colors{field-2},...
                'MarkerFaceAlpha', alpha, 'MarkerEdgeAlpha', alpha);
            
            animalMean{g}=y;
            errorbar(x(end) + 25, mean(y), std(y), '.', 'MarkerSize',15, ...
                    'LineWidth', 1, 'Color', [0 0 0],'CapSize',0);
            fprintf(fileID, ['For genotype: ' uGenotypes{g} ' ' plotTypes{field-3} ' amplitudes Mean: ' num2str(mean(y)) ' SD: ' num2str(std(y)) '\n']);
        else            
            
        end
            
               
           
    end
    hold off
    
    pval = ranksum(animalMean{1}, animalMean{2});
    fprintf(fileID, ['For plotType: Amplitude ' plotTypes{field-3} ' Mann Whitney U pval: ' num2str(pval)  '\n']);
    

    set(gca, 'box','off','TickDir','out', 'fontsize', 8,'fontname', 'Arial');
    if any(ismember(field, [4,5]))
        ylim([0 110])
        yticks(0:20:100)
    else
        ylim([0 0.5]);
%         yline(0.7, '--k', 'color', [112, 41, 99]/255, 'LineWidth', 3);
    end
    ylabel(ylabels{field},'fontname', 'Arial',  'fontsize', 8)
%     xtickangle(45);
    xlim([0,max(x)+40]);
    xticks([(start_x  + 75), (start_x  + 325)])
    xticklabels({'WT', 'KO'})
%     h.XAxis.FontWeight = 'Bold';    
    h.LineWidth = 1;
%     title(plotTypes{field});
    savefig(g1,fullfile(figureRoot,['Amplitude ' plotTypes{field-3} ' No inihibtion KO vs WT Amplitudes.fig']));
    exportgraphics(g1,fullfile(figureRoot, ['Amplitude ' plotTypes{field-3} ' No inihibtion KO vs WT Amplitudes.png']));
    exportgraphics(g1,fullfile(figureRoot, ['Amplitude ' plotTypes{field-3} ' No inihibtion KO vs WT Amplitudes.pdf']), 'Resolution', 1200);
end
fclose(fileID);

%% Plot task structure
g = figure(1); clf;
set(g, 'Units', 'centimeters', 'Position', [50, 50, 70,40]/10);
hold on;
linWidths = 1;
timeStart = -0.1;
Fs= 1000000;
% Auditory cue
duration = 3;
constStart = 0;
constEnd = 0.1;
t = ((1/Fs)):1/Fs:duration;
y = zeros(size(t));
y((constStart)*Fs+1:(constEnd)*Fs)=2;
tNew = [timeStart:1/Fs:-1/Fs, t, t(end)+1/Fs:1/Fs:duration+0.5];
yNew = [zeros(1,numel(timeStart:1/Fs:-1/Fs)), y, zeros(1,numel(t(end)+1/Fs:1/Fs:duration+0.5))]+3;
plot(tNew,yNew, 'LineWidth', linWidths, 'color', 'k')

% whisker stimulus
duration = 3;
constStart = 1;
constEnd = 1.15;
freq = 20;
t = ((1/Fs)):1/Fs:duration;
y = zeros(size(t));
y((constStart)*Fs+1:(constEnd)*Fs)=1;
y(t<=(constStart))= 0;
y(t>constEnd)=0;

y1=arrayfun(@(x) (sin(2*pi*freq*x-pi/2)+1)/2, t);
y2=arrayfun(@(x, x1) conv(x,x1), y,y1);

tNew = [timeStart:1/Fs:-1/Fs, t, t(end)+1/Fs:1/Fs:duration+0.5];
yNew = [zeros(1,numel(timeStart:1/Fs:-1/Fs)), y2, zeros(1,numel(t(end)+1/Fs:1/Fs:duration+0.5))]+6;
plot(tNew,yNew, 'LineWidth', linWidths, 'color', [131 60 12]/255)


ylim([0 7])
xlim([-0.5, duration+0.5])
% Remove the y-axis by setting the YColor to 'none'
ax = gca;  % Get current axes
ax.YColor = 'none';
xticks(0:3)
xticklabels({'0.0', '1.0', [],'3.0'})
set(gca, 'YColor', 'none', 'Fontsize', 8, 'Fontname', 'Arial', 'LineWidth', 1, 'TickDir', 'out');
% Set the axes position to occupy the whole figure [left, bottom, width, height]
set(ax, 'Position', [0.01 0.12 0.98 0.88]);
exportgraphics(g, fullfile(figureRoot, [' TaskStructure.tiff']), 'Resolution', 1200);
exportgraphics(g, fullfile(figureRoot, [' TaskStructure.pdf']), 'Resolution', 1200);


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
