%% Script to make Figure2
%% 
clear all
animalID = {};
% Choose a group folder
rootDir = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\SeData';
figureRoot = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\Fig2';
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
        case 'finalBehavSEs'            
            behavDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            seNames = cellfun(@(x) endsWith(x,'se.mat'),behavDirInfo.name);            
            behavDirInfo(~seNames,:) = [];
            animalNames = cellfun(@(x) strsplit(x, ' '), behavDirInfo.name, 'UniformOutput', false);
            animalNames = cellfun(@(x) x{1}, animalNames, 'UniformOutput',false);
            if ~isempty(animalID)
                behavDirInfo(~ismember(animalNames, animalID),:) = [];
            end

           
        case 'SessInfo'
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
%% get performances in datafileTb
for i =1:height(dataFileTb)
    load(dataFileTb.sePath{i})
    perf = struct2table(getPerfOverall(se));
    dataFileTb(i,perf.Properties.VariableNames) = perf;
end

% remove opto Sessions
isOpto = find(dataFileTb.isOpto);
dataFileTb(~isOpto,:) = [];
%% Bootstrapped for each mouse for WT and KO with Left Stim and Right stim for non opto Trials
% Multilevel_bootstrap
% resample mice with replacement
% resample session with replacement
% resample trials with replacement 
% 
% clear all
close all
trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
trials{2} = {'Stim_Som_Left', 'Stim_Som_Left_Opto', 'Stim_Som_Right', 'Stim_Som_Right_Opto'}; 
inhSitesAll = {'Left S1', 'Right S1','NA'};
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\SEs', 'Select source SEs');
try 
    readPaths = dataFileTb.sePath;
catch
end

readPathParts = cellfun(@(x) strsplit(x, '\'), readPaths, 'UniformOutput', false);
seDir = fullfile(readPathParts{1}{1:end-2});
seNames = cellfun(@(x) x(end), readPathParts, 'UniformOutput',false);
clearvars -except readPaths dataFileTb readPathParts seDir seNames animalID trials inhSitesAll figureRoot;

animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
AnimalIDs = cellfun(@(x) x{1}, animal, 'UniformOutput', false);
animalID = unique(AnimalIDs);
% get all the trialNums for each trialType for each session and mouse

pathParts = strsplit(seDir, '\');



savePath=(fullfile(figureRoot,'No inhibition'));
if ~exist(savePath, 'dir')
    mkdir(savePath);
end
%
photoInhAll = table();

for animalNum =1:size(animalID,1)
     ani = animalID{animalNum}; 
     
    sessNum =[1,1,1];
    for i = find(ismember(AnimalIDs, ani))'        
        load(readPaths{i});
        behavData = se.GetTable('behavValue');
        trialMap = se.userData.sessionInfo.trialMap;
        trialSplit = strsplit(trialMap{1},':');
        if numel(trialSplit)<3
            if any(strcmp(trialSplit{end}(1:end-1), 'end'))
                trialInd = [str2double(trialSplit{1}) : se.numEpochs];
            else
                trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{end}(1:end-1))];
            end
        else
            if any(strcmp(trialSplit{end}(1:end-1), 'end'))
                trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}), str2double(trialSplit{3}): se.numEpochs];
            else
                trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}), str2double(trialSplit{3}) : str2double(trialSplit{end}(1:end-1))];
            end
        end
        
        behavData = se.GetTable('behavValue');
        
        
        %Remove aborted trials due to pre stim no licktime licks
        responses = behavData.response;
        abortTrials = find(cell2mat(responses) == 3); 
        behavData(abortTrials,:) = [];
        
        % separate missed trials vs all trials
        responses = behavData.result;
        missTrials = isnan(responses);
        missData = behavData(missTrials,:);
%         behavData(missTrials, :) =[];
        
        % Find inhibition sites
        inhSite = find(ismember(inhSitesAll, behavData.inhSite{1}));

        
        
        trialTypes = unique(behavData.trialType);
        
        if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
            trialTypes = trials{2};
        else
            trialTypes = trials{1};
        end


        for trialType = 1:numel(trialTypes)
            trialTypeInd = strcmp(trialTypes{trialType}, behavData.trialType);
            fracResult{animalNum, inhSite}{sessNum(inhSite)}(trialType) = mean(behavData.result(trialTypeInd));
            
            missFrac{animalNum,inhSite}{sessNum(inhSite)}(trialType) =numel(find(strcmp(trialTypes{trialType}, missData.trialType)))/...
                   (numel(find(strcmp(trialTypes{trialType}, missData.trialType))) + numel(find(strcmp(trialTypes{trialType}, behavData.trialType))));
            allTrialTypes{animalNum, inhSite}{sessNum(inhSite)} = trialTypes;
        end 
        
              
             
        photoInhAll= [photoInhAll; behavData];
        
        sessNum(inhSite) = sessNum(inhSite)+1;
        
       
    end
end


inhSites = unique(photoInhAll.inhSite); 

Genotypes = unique(photoInhAll.Genotype); 

trialTypes= unique(photoInhAll.trialType); % left, left_opto, right, right_opto
inhSites = unique(photoInhAll.inhSite);

mice = unique(photoInhAll.mouseName);
        
if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
    trialTypes = trials{2};
else
    trialTypes = trials{1};
end 

%%
nboot = 10000; % number for bootstrapping
clearvars photoInh_bootstrapped photoInh_bootstrapped_miss photoInh photoInh_miss
% 
% delta_mouse = cell(length(mice),1);
% delta_mouse_miss = cell(length(mice),1);

trialTypeFields = {'leftStimType', 'leftStimType', 'rightStimType', 'rightStimType'};

tic

for g = 1:length(Genotypes)
    
    Genotype = Genotypes{g};
    for e = 1:length(inhSites) 
        
        inhSite = inhSites{e};
        
        u = photoInhAll(strcmp(photoInhAll.inhSite, inhSite)& strcmp(photoInhAll.Genotype, Genotype), :);
        
        mouseNames = unique(u.mouseName);
        if isempty(mouseNames)
            continue;
        end
        
        

        overallOmeanPerf = cell(length(mouseNames) , 1);
        overallOmeanMiss = cell(length(mouseNames) , 1);
        overallMeanPerf = cell(length(mouseNames) , 1);
        overallMeanMiss = cell(length(mouseNames) , 1);
        for mouse = 1:length(mouseNames) 
            m = u(strcmp(u.mouseName, mouseNames{mouse}), :);             
            dateData = cellfun(@(x) datestr(x, 'yyyymmdd'), m.sessDate, 'UniformOutput',false);
            sessions = unique(dateData);
            m.sessDate = dateData;
            
            for trialType=1:numel(trialTypes)           
                            
                        % get trialtype indices so that performance can be calculated for that trialType      
                        trialInds = find(strcmp(trialTypes{trialType},m.trialType));
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
                        overallOmeanPerf{mouse,1}(1,trialType) = mean(behavData.result); % lick probability of each trial type 
                        overallOmeanMiss{mouse,1}(1,trialType) = height(missData)/(height(missData) + height(behavData)); 
            end
                        

            sess_overallMeanPerf = nan(numel(sessions), numel(trialTypes));
            sess_overallMeanMiss = nan(numel(sessions), numel(trialTypes));
            
            for sessNum = 1: numel(sessions)
                s = m(strcmp(sessions(sessNum), m.sessDate),:);

                for trialType=1:numel(trialTypes)           
                                
                    % get trialtype indices so that performance can be calculated for that trialType      
                    trialInds = find(strcmp(trialTypes{trialType},s.trialType));
    %                     if isempty(trialInds)
    %                         tTypes = {'Stim_Som_Left_NoCue', 'Stim_Som_Right_NoCue'};
    %                         trialInds = find(strcmp(tTypes{trialType}, v.trialType));
    %                     else
    %                         tTypes = trialTypes;
    %                     end                 
                    
                    behavData = s(trialInds,:);
    
                    responses = behavData.result;
                    missTrials = isnan(responses);
                    missData = behavData(missTrials,:);
                    behavData(missTrials, :) =[];
                    sess_overallMeanPerf(sessNum, trialType) = mean(behavData.result); % lick probability of each trial type 
                    sess_overallMeanMiss(sessNum, trialType) = height(missData)/(height(missData) + height(behavData)); 
                                      
                   
                end
            end
            overallMeanPerf{mouse,1} = sess_overallMeanPerf;
            overallMeanMiss{mouse,1} = sess_overallMeanMiss;
            % here we have all the sessions and trials from one mouse. 
            
            rng(7);
            
            trialPerf = cell(nboot,1); 
            trialMiss = cell(nboot,1); 
            trialAmp = cell(nboot,1);  
            rawTrialPerf= cell(nboot,1); 
            rawTrialMiss= cell(nboot,1); 
            rawTrialAmp= cell(nboot,1);
            parfor n = 1:nboot 
               
                sess_trialPerf = cell(numel(sessions),1); 
                sess_trialMiss = cell(numel(sessions),1); 
                sess_trialAmp = cell(numel(sessions),1); 
                
                deltaTrialPerf = cell(numel(sessions),1); 
                deltaTrialMiss = cell(numel(sessions),1); 
                deltaTrialAmp = cell(numel(sessions),1); 
                randSessions = randi(height(sessions), 1, height(sessions));

                for sessNum = 1:numel(randSessions)
                    s = m(strcmp(sessions(randSessions(sessNum)), m.sessDate), :); 
                 
                    % Now we will select trials on random with repalcemetn from all the sessions. 
                    % So total trial nums will be trialSessA + trial SessB +....
                    randTrials = randi(height(s), 1, height(s)); 
                    v = s(randTrials,:);       
                    
                    % Now we need to calculate 3 terms for performance. Overall
                    % Perf, Perf for left stim and Perf for right Stims
                    % Same thing for miss Data
    
                    for trialType=1:numel(trialTypes)           
                            
                        % get trialtype indices so that performance can be calculated for that trialType      
                        trialInds = find(strcmp(trialTypes{trialType},v.trialType));
    %                     if isempty(trialInds)
    %                         tTypes = {'Stim_Som_Left_NoCue', 'Stim_Som_Right_NoCue'};
    %                         trialInds = find(strcmp(tTypes{trialType}, v.trialType));
    %                     else
    %                         tTypes = trialTypes;
    %                     end                 
                        
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
                     
    
                    deltaTrialPerf{sessNum,1}(1,1) = (sess_trialPerf{sessNum}(1,2) - sess_trialPerf{sessNum}(1,1)); % left_opto - left_noOpto
                    deltaTrialPerf{sessNum,1}(1,2) = sess_trialPerf{sessNum}(1,4) - sess_trialPerf{sessNum}(1,3); % right_opto - right_noOpto
                    deltaTrialMiss{sessNum,1}(1,1) = sess_trialMiss{sessNum}(1,2) - sess_trialMiss{sessNum}(1,1); % left_opto - left_noOpto
                    deltaTrialMiss{sessNum,1}(1,2) = sess_trialMiss{sessNum}(1,4) - sess_trialMiss{sessNum}(1,3); % right_opto - right_noOpto
                    
                    deltaTrialAmp{sessNum,1}(1,1) = sess_trialAmp{sessNum}(1,1); % left_noOpto
                    deltaTrialAmp{sessNum,1}(1,2) = sess_trialAmp{sessNum}(1,3); % right_noOpto              
                end
                rawTrialPerf{n,1} = mean(cell2mat(sess_trialPerf),1);
                
                rawTrialMiss{n,1} = mean(cell2mat(sess_trialMiss),1);          
                
                rawTrialAmp{n,1} = mean(cell2mat(sess_trialAmp),1); % left_noOpto
                
                trialPerf{n,1} = mean(cell2mat(deltaTrialPerf),1);
                
                trialMiss{n,1} = mean(cell2mat(deltaTrialMiss),1);          
                
                trialAmp{n,1} = mean(cell2mat(deltaTrialAmp),1); % left_noOpto
                
  
            end
            
            fracCorrect_mouse{mouse} = [cell2mat(rawTrialPerf), cell2mat(trialPerf), cell2mat(trialAmp)]; 
            fracMiss_mouse{mouse} = [cell2mat(rawTrialMiss), cell2mat(trialMiss), cell2mat(trialAmp)];
          
        end

        % average across sessions
        % average across sessions
        photoInh_bootstrapped{(g-1)*length(inhSites)+e,1} = Genotype;
        photoInh_bootstrapped{(g-1)*length(inhSites)+e,2} = inhSite;        
        photoInh_bootstrapped{(g-1)*length(inhSites)+e,3} = fracCorrect_mouse;        
        photoInh_bootstrapped_miss{(g-1)*length(inhSites)+e,1} = Genotype;
        photoInh_bootstrapped_miss{(g-1)*length(inhSites)+e,2} = inhSite;        
        photoInh_bootstrapped_miss{(g-1)*length(inhSites)+e,3} = fracMiss_mouse;  

        photoInh{(g-1)*length(inhSites)+e,1} = Genotype;
        photoInh{(g-1)*length(inhSites)+e,2} = inhSite;
        photoInh{(g-1)*length(inhSites)+e,3} = cell2mat(overallOmeanPerf);
        photoInh{(g-1)*length(inhSites)+e,4} = overallMeanPerf;
               
        photoInh_miss{(g-1)*length(inhSites)+e,1} = Genotype;
        photoInh_miss{(g-1)*length(inhSites)+e,2} = inhSite;
        photoInh_miss{(g-1)*length(inhSites)+e,3} =  cell2mat(overallOmeanMiss);
        photoInh_miss{(g-1)*length(inhSites)+e,4} =  overallMeanMiss;
          

        clearvars fracCorrect_mouse fracMiss_mouse

    end
end
toc




%% Calculate mean per genotpye and trialType for all animals


confidencelevel = 0.95;
alpha = 1-confidencelevel;
clearvars meanStats SEM ts ciStats ciStats_miss ts_miss SEM_miss meanstats_miss photoInhBootstrapped photoInhBootstrapped_miss
allDataField = 3;
for genotype = 1:height(photoInh_bootstrapped)
    for mouse = 1:numel(photoInh_bootstrapped{genotype,allDataField})
        for field = 1:width(photoInh_bootstrapped{genotype,allDataField}{mouse})

           fieldData = photoInh_bootstrapped{genotype,allDataField}{mouse}(:,field);
           if mod(genotype, 2) == 0
               side = 'Right';
           else
               side = 'Left';
           end
           
           

           % normality Anderson-Darling test
           h = adtest(fieldData, 'Alpha', alpha);           
            % Display the test result
            if h
                disp(['The data does not follow a normal distribution for genotype = '  photoInh_bootstrapped{genotype,1} ...
                    ' inhibition side: ' side ' mouse: ' num2str(mouse) ' field: ' num2str(field)]);
            else
                disp(['The data follows a normal distribution for genotype = '  photoInh_bootstrapped{genotype,1} ...
                    ' inhibition side: ' side ' mouse: ' num2str(mouse) ' field: ' num2str(field)]);
            end
            
           photoInh_bootstrapped{genotype,allDataField + 2*field -1}(mouse) = mean(photoInh_bootstrapped{genotype,allDataField}{mouse}(:,field));
           photoInh_bootstrapped_miss{genotype,allDataField + 2*field -1}(mouse) = mean(photoInh_bootstrapped_miss{genotype,allDataField}{mouse}(:,field));
            
           sortedField = sort(photoInh_bootstrapped{genotype,allDataField}{mouse}(:,field),1);
           photoInh_bootstrapped{genotype,allDataField + 2*field}(1:3, mouse) = [mean(photoInh_bootstrapped{genotype,allDataField}{mouse}(:,field)), ...
               sortedField(round(nboot*0.025)),  sortedField(round(nboot*0.975))];
            
           sortedField_miss = sort(photoInh_bootstrapped_miss{genotype,allDataField}{mouse}(:,field),1);
           photoInh_bootstrapped_miss{genotype,allDataField + 2*field}(1:3, mouse) = [mean(photoInh_bootstrapped_miss{genotype,allDataField}{mouse}(:,field)), ...
               sortedField_miss(round(nboot*0.025)),  sortedField_miss(round(nboot*0.975))];

        end
    end
    
end
            

vars = {'Genotype', 'InhSite', 'AllData', 'Meanstats_left','CI_left', 'Meanstats_leftopto','CI_leftopto', 'Meanstats_right', 'CI_right', 'Meanstats_rightopto', 'CI_rightopto', 'Meanstats_dleft','CI_dleft' , 'Meanstats_dright', 'CI_dright', 'Amp_left', 'CIAmp_left','Amp_Right','CIAmp_right'};
photoInhBootstrapped = cell2table(flip(photoInh_bootstrapped),'VariableNames', vars);

% vars_miss = {'Genotype', 'InhSite', 'AllData', 'MeanStats_overall','CIstats_overall', 'Meanstats_left','CI_left', 'Meanstats_right', 'CI_right', 'Amp_left', 'Amp_Right'};
photoInhBootstrapped_miss = cell2table(flip(photoInh_bootstrapped_miss),'VariableNames', vars);


%%
%% Calculate mean per genotpye and trialType for all animals for non bootstrapped data
confidencelevel = 0.95;
alpha = 1-confidencelevel;
clearvars meanStats SEM ts ciStats ciStats_miss ts_miss SEM_miss meanstats_miss photoInhTable photoInhTable_miss
allDataField = 4;
for genotype = 1:height(photoInh)
    sign = sum(ismember('Left', photoInh{genotype,2}))>3;
    
    for mouse = 1:numel(photoInh{genotype,allDataField})

        for field = 1:width(photoInh{genotype,allDataField}{mouse})

           fieldData = photoInh{genotype,allDataField}{mouse}(:,field);
           if mod(genotype, 2) == 0
               side = 'Right';
           else
               side = 'Left';
           end
            
           % normality Anderson-Darling test
           h = adtest(fieldData, 'Alpha', alpha);           
            % Display the test result
            if h
                disp(['The data does not follow a normal distribution for genotype = '  photoInh{genotype,1} ...
                    ' inhibition side: ' side ' mouse: ' num2str(mouse) ' field: ' num2str(field)]);
            else
                disp(['The data follows a normal distribution for genotype = '  photoInh{genotype,1} ...
                    ' inhibition side: ' side ' mouse: ' num2str(mouse) ' field: ' num2str(field)]);
            end
           
           photoInh{genotype,allDataField + field}(1:2,mouse) =[mean(fieldData), std(fieldData)/sqrt(height(fieldData))];
           photoInh_miss{genotype,allDataField + field}(1:2,mouse) =[mean(fieldData), std(fieldData)/sqrt(height(fieldData))];          
           
        end

        % add p-value fields for non-delta values and add delta all data values
        for field = [1,3]
            % correct fraction
            optoData = photoInh{genotype,allDataField}{mouse}(:,field+1);
            nonoptoData = photoInh{genotype,allDataField}{mouse}(:,field);
            [photoInh{genotype,allDataField+width(photoInh{genotype,allDataField}{mouse})+(field+1)/2}(1,mouse),...
                photoInh{genotype,allDataField+width(photoInh{genotype,allDataField}{mouse})+(field+1)/2}(2,mouse)] = ...
                signrank(optoData, nonoptoData, 'Method', 'approximate');
            photoInh{genotype,allDataField+width(photoInh{genotype,allDataField}{mouse})+3}{mouse,1}(:,(field+1)/2) = optoData-nonoptoData;
            % miss
            optoData = photoInh_miss{genotype,allDataField}{mouse}(:,field+1);
            nonoptoData = photoInh_miss{genotype,allDataField}{mouse}(:,field);
            [photoInh_miss{genotype,allDataField+width(photoInh_miss{genotype,allDataField}{mouse})+(field+1)/2}(1,mouse),...
                photoInh_miss{genotype,allDataField+width(photoInh_miss{genotype,allDataField}{mouse})+(field+1)/2}(2,mouse)] = ...
                signrank(optoData, nonoptoData, 'Method', 'approximate');
            photoInh_miss{genotype,allDataField+width(photoInh_miss{genotype,allDataField}{mouse})+3}{mouse,1}(:,(field+1)/2) = optoData-nonoptoData;

        end
        
        for field =[1,2]
            %correct fraction
            fieldData= photoInh{genotype,allDataField+width(photoInh{genotype,allDataField}{mouse})+3}{mouse,1}(:,field);
            photoInh{genotype,allDataField+width(photoInh{genotype,allDataField}{mouse})+3+field}(1,mouse) = ...
                mean(fieldData);
            photoInh{genotype,allDataField+width(photoInh{genotype,allDataField}{mouse})+3+field}(2,mouse) = ...
                std(fieldData)/sqrt(numel(fieldData));
            if (field==1 && sign) || (field==2 && ~sign)
                successes = numel(fieldData>0); 
            else
                successes = numel(fieldData<0); 
            end

            p0 = 0.5;
            [ci, p] = binofit(successes,numel(fieldData));
            photoInh{genotype,allDataField+width(photoInh{genotype,allDataField}{mouse})+3+field}(3,mouse) = ...
               ~(p0 >= ci(1) && p0 <= ci(2));

            % miss
            fieldData= photoInh_miss{genotype,allDataField+width(photoInh_miss{genotype,allDataField}{mouse})+3}{mouse,1}(:,field);
            photoInh_miss{genotype,allDataField+width(photoInh_miss{genotype,allDataField}{mouse})+3+field}(1,mouse) = ...
                mean(fieldData);
            photoInh_miss{genotype,allDataField+width(photoInh_miss{genotype,allDataField}{mouse})+3+field}(2,mouse) = ...
                std(fieldData)/sqrt(numel(fieldData));
            if (field==1 && sign) || (field==2 && ~sign)
                successes = numel(fieldData>0); 
            else
                successes = numel(fieldData<0); 
            end

            
            [ci, p] = binofit(successes,numel(fieldData));
            photoInh_miss{genotype,allDataField+width(photoInh_miss{genotype,allDataField}{mouse})+3+field}(3,mouse) = ...
               ~(p0 >= ci(1) && p0 <= ci(2));
        end
        %
        


    end
    
end
            

vars = {'Genotype', 'InhSite','MeanData', 'AllData', 'Meanstats_left', 'Meanstats_leftopto', 'Meanstats_right', 'Meanstats_rightopto', 'pVal-Left', 'pVal-Right', ...
    'AllDeltaData', 'Meanstats_dleft','Meanstats_dright'};
photoInhTable = cell2table(flip(photoInh),'VariableNames', vars);

% vars_miss = {'Genotype', 'InhSite', 'AllData', 'MeanStats_overall','CIstats_overall', 'Meanstats_left','CI_left', 'Meanstats_right', 'CI_right', 'Amp_left', 'Amp_Right'};
photoInhTable_miss = cell2table(flip(photoInh_miss),'VariableNames', vars);
%%
% save the two tables

save(fullfile(figureRoot, 'InhibitionAllVars_nboot10000_240124.mat'), 'photoInhTable_miss', 'photoInhTable', 'photoInhBootstrapped_miss', 'photoInhBootstrapped', 'figureRoot', 'dataFileTb');


%% load processed data
clear all
figureRoot = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\Fig2';
load(fullfile(figureRoot, 'InhibitionAllVars_nboot10000_240124.mat'))
figureRoot = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\Fig2';

%% p-value calcualtion correct delta 

fileID = fopen( fullfile(figureRoot, ['Fig2 OptoInhibition Stats delta correct fraction.txt']), 'w');
clearvars ci_c ci_i pval_c pval_i H_contra H_ipsi sucesses_ipsi sucesses_contra pval_cpdf pval_ipdf
ugenotypes = unique(photoInhTable.Genotype, 'stable');
inhSites = unique(photoInhTable.InhSite, 'stable');
fieldc = [1,2];
fieldi = [2,1];
mean_contra = cell(numel(ugenotypes),1);
mean_ipsi = cell(numel(ugenotypes),1);
p0 = 0.5;
fprintf(fileID, 'Pvals using binomial tests:\n');
for g = 1: numel(ugenotypes)
    genotype = ugenotypes{g};
    fieldTable = photoInhTable(strcmp(photoInhTable.Genotype, genotype), :);
    contra = [];
    ipsi = [];
    for inhSite = 1:numel(inhSites)
        contra =  [contra, fieldTable{inhSite,11+fieldc(inhSite)}{1,1}(1,:)];
        ipsi =  [ipsi, fieldTable{inhSite,11+fieldi(inhSite)}{1,1}(1,:)];
    end
    mean_contra{g,1} = contra;
    sucesses_contra{g} = numel(find(contra<0));
    [pval_c{g}, ci_c{g}] = binofit(sucesses_contra{g},numel(contra));    
    pval_cpdf{g} = binopdf(sucesses_contra{g},numel(contra), 0.5); % using binopdf
    pval_ccdf{g} = 1-binocdf(sucesses_contra{g}-1,numel(contra), 0.5); % using binocdf
    H_contra{g}=  ~(p0 >= ci_c{g}(1) && p0 <= ci_c{g}(2));
    fprintf(fileID, ['For genotype ' genotype ' using binocdf contra is ' num2str(pval_ccdf{g}) ...
        ' using binopdf contra is ' num2str(pval_cpdf{g}) '\n']);

    mean_ipsi{g,1} = ipsi;
    sucesses_ipsi{g} = numel(find(ipsi>0));
    [pval_i{g}, ci_i{g}] = binofit(sucesses_ipsi{g},numel(ipsi));    
    pval_ipdf{g} = binopdf(sucesses_ipsi{g},numel(ipsi), 0.5);  
    pval_icdf{g} = 1-binocdf(sucesses_ipsi{g}-1,numel(ipsi), 0.5); % using binocdf
    fprintf(fileID, ['For genotype ' genotype ' using binocdf ipsi is ' num2str(pval_icdf{g}) ...
        ' using binopdf ipsi is ' num2str(pval_ipdf{g}) '\n']);
    H_ipsi{g}=  ~(p0 >= ci_i{g}(1) && p0 <= ci_i{g}(2));

    
end

% test for normality
pop1 = adtest(mean_contra{1});
pop2 = adtest(mean_contra{2});
pop3 = adtest(mean_ipsi{1});
pop4 = adtest(mean_ipsi{2});

if all([pop1, pop2,pop3, pop4])
    % Compare Miss rate between the two genotypes.
    [H,P] = ttest2(mean_contra{1}, mean_contra{2});
    fprintf(fileID, ['Between genotypes contra effect comparison using ttest2 is ' num2str(P) '\n']);
    
    % Compare Miss rate between the two genotypes.
    [H,P] = ttest2(mean_ipsi{1}, mean_ipsi{2});
    
    fprintf(fileID, ['Between genotypes ipsi effect comparison using ttest2 is ' num2str(P) '\n']);
else
    [P,H] = ranksum(mean_contra{1}, mean_contra{2});
    fprintf(fileID, ['Between genotypes contra effect comparison using Mann Whitney U is ' num2str(P) '\n']);
    
    % Compare Miss rate between the two genotypes.
    [P,H] = ranksum(mean_ipsi{1}, mean_ipsi{2});
    
    fprintf(fileID, ['Between genotypes ipsi effect comparison using Mann Whitney U is ' num2str(P) '\n']);
end

 
fclose(fileID);

%% p-value calcualtion miss delta 

fileID = fopen( fullfile(figureRoot, ['Fig2 OptoInhibition Stats delta miss fraction.txt']), 'w');
clearvars ci_c ci_i pval_c pval_i H_contra H_ipsi sucesses_ipsi sucesses_contra pval_cpdf pval_ipdf
ugenotypes = unique(photoInhTable_miss.Genotype, 'stable');
inhSites = unique(photoInhTable_miss.InhSite, 'stable');
fieldc = [1,2];
fieldi = [2,1];
mean_contra = cell(numel(ugenotypes),1);
mean_ipsi = cell(numel(ugenotypes),1);
p0 = 0.5;
fprintf(fileID, 'Pvals using binomial tests:\n');
for g = 1: numel(ugenotypes)
    genotype = ugenotypes{g};
    fieldTable = photoInhTable_miss(strcmp(photoInhTable_miss.Genotype, genotype), :);
    contra = [];
    ipsi = [];
    for inhSite = 1:numel(inhSites)
        contra =  [contra, fieldTable{inhSite,11+fieldc(inhSite)}{1,1}(1,:)];
        ipsi =  [ipsi, fieldTable{inhSite,11+fieldi(inhSite)}{1,1}(1,:)];
    end
    mean_contra{g,1} = contra;
    sucesses_contra{g} = numel(find(contra>0));
    [pval_c{g}, ci_c{g}] = binofit(sucesses_contra{g},numel(contra));    
    pval_cpdf{g} = binopdf(sucesses_contra{g},numel(contra), 0.5); % using binopdf
    pval_ccdf{g} = 1-binocdf(sucesses_contra{g}-1,numel(contra), 0.5); % using binocdf
    H_contra{g}=  ~(p0 >= ci_c{g}(1) && p0 <= ci_c{g}(2));
    fprintf(fileID, ['For genotype ' genotype ' using binocdf contra is ' num2str(pval_ccdf{g}) ...
        ' using binopdf contra is ' num2str(pval_cpdf{g}) '\n']);

    mean_ipsi{g,1} = ipsi;
    sucesses_ipsi{g} = numel(find(ipsi>0));
    [pval_i{g}, ci_i{g}] = binofit(sucesses_ipsi{g},numel(ipsi));    
    pval_ipdf{g} = binopdf(sucesses_ipsi{g},numel(ipsi), 0.5);  
    pval_icdf{g} = 1-binocdf(sucesses_ipsi{g}-1,numel(ipsi), 0.5); % using binocdf
    fprintf(fileID, ['For genotype ' genotype ' using binocdf ipsi is ' num2str(pval_icdf{g}) ...
        ' using binopdf ipsi is ' num2str(pval_ipdf{g}) '\n']);
    H_ipsi{g}=  ~(p0 >= ci_i{g}(1) && p0 <= ci_i{g}(2));


end



% test for normality
pop1 = adtest(mean_contra{1});
pop2 = adtest(mean_contra{2});
pop3 = adtest(mean_ipsi{1});
pop4 = adtest(mean_ipsi{2});

if all([pop1, pop2,pop3, pop4])
    % Compare Miss rate between the two genotypes.
    [H,P] = ttest2(mean_contra{1}, mean_contra{2});
    fprintf(fileID, ['Between genotypes contra effect comparison using ttest2 is ' num2str(P) '\n']);
    
    % Compare Miss rate between the two genotypes.
    [H,P] = ttest2(mean_ipsi{1}, mean_ipsi{2});
    
    fprintf(fileID, ['Between genotypes ipsi effect comparison using ttest2 is ' num2str(P) '\n']);
else
    [P,H] = ranksum(mean_contra{1}, mean_contra{2});
    fprintf(fileID, ['Between genotypes contra effect comparison using Mann Whitney U is ' num2str(P) '\n']);
    
    % Compare Miss rate between the two genotypes.
    [P,H] = ranksum(mean_ipsi{1}, mean_ipsi{2});
    
    fprintf(fileID, ['Between genotypes ipsi effect comparison using Mann Whitney U is ' num2str(P) '\n']);
end
fclose(fileID);

%% plot figures for overall perf --> mousewise combining hemispheres

fontSizeVal = 8;
lineWidthVal = 1;
widthVal = 1.6;
heightVal = 1.5;
markerSizeVal = 10;
markers = {'.', 'x'};
markersizes = [markerSizeVal,markerSizeVal-5];

clearvars ymean
plotTypes = {'Contralateral stims', 'Ipsilateral stims'};
% plotTypes = {'Amplitude-contra', 'Amplitude-ipsi'};
allDataField = 3;
meanallDataField = 3;
close all; 



% plot correct fraction
ugenotypes = unique(photoInhBootstrapped.Genotype, 'stable');
inhSites = unique(photoInhBootstrapped.InhSite, 'stable');
mousecolors = distinguishable_colors(4,{'w', 'k'});
genotypecolors{1} = {[1 0 0]; [0 0 1]};
genotypecolors{2} = {[1 0 0]; [0 0 1]};


for g= 1: numel(ugenotypes)
    genotype = ugenotypes{g};
    g1 = figure(g);clf
    set(g1, 'Units', 'inches', 'Position', [1 1 widthVal heightVal]);
    colors = genotypecolors{g};
%     g1.WindowState= 'Maximized';
    fieldTable = photoInhBootstrapped(strcmp(photoInhBootstrapped.Genotype, genotype), :);
    meanfieldTable = photoInhTable(strcmp(photoInhTable.Genotype, genotype), :);
    mouseNum = numel(fieldTable{1, allDataField});
    x1 = [];
    x2 = [];
    for mouse = 1: mouseNum
        
            field1 = [1,2,3,4]; % for Right S1 inh, contra ipsi amp-contra amp-ipsi
            field2 = [2,1,4,3];  % For leftS1, contra ipsi amp-contra amp-ipsi
            subplotNum =1:numel(plotTypes); 
            
            meanfield1 = [1,2,3,4];
            meanfield2 = [3,4,1,2];

            
            inhSite = [1,2];
            disp('Plotting contra')
            h1 = subplot(1,1,1);
            hold(h1, 'on')
            start_x =20;
            x = ((start_x  +(2-1)*300*0)  + 15*(mouse) + (inhSite-1)*75);
            x1(mouse) = median(x);
            ymean(1)= meanfieldTable{1,meanallDataField}{1,1}(mouse,meanfield1(2)) - meanfieldTable{1,meanallDataField}{1,1}(mouse,meanfield1(1));
            ymean(2)= meanfieldTable{2,meanallDataField}{1,1}(mouse,meanfield2(2)) - meanfieldTable{2,meanallDataField}{1,1}(mouse,meanfield2(1));
            ci(:,1) = fieldTable{1,allDataField+8+2*field1(1)}{1,1}(:,mouse);
            ci(:,2) = fieldTable{2,allDataField+8+2*field2(1)}{1,1}(:,mouse);
%             plot(h1,x,ci(1,:), '--', 'color', [170 170 170]/255, 'lineWidth', 1);
%             plot(x,ymean, '--', 'color', [170 170 170]/255, 'lineWidth', 1);
            for i =1:2
                
               
                hh = errorbar(x(i),ci(1,i),ci(1,i) - ci(2,i), ci(3,i)- ci(1,i),'o',...
                        'MarkerSize',6, 'MarkerEdgeColor',  colors{1}, 'color',  colors{1}, 'LineWidth', lineWidthVal, 'CapSize', 0); 
                 plot(x(i)',ymean(i), 'Marker',markers{i}, 'color', colors{1}, 'MarkerSize', markersizes(i), 'LineWidth',lineWidthVal);
                set(hh, 'Marker', 'none');
            end
            
            
            disp('Plotting ipsi')
%             h2 = subplot(1,numel(plotTypes),subplotNum(2));
%             hold(h2, 'on')

            x = ((start_x  +(2-1)*200)  + 15*(mouse) + (inhSite-1)*75);
            x2(mouse) = median(x);
            ymean(1)= meanfieldTable{1,meanallDataField}{1,1}(mouse,meanfield1(4)) - meanfieldTable{1,meanallDataField}{1,1}(mouse,meanfield1(3));
            ymean(2)= meanfieldTable{2,meanallDataField}{1,1}(mouse,meanfield2(4)) - meanfieldTable{2,meanallDataField}{1,1}(mouse,meanfield2(3));
            ci(:,1) = fieldTable{1,allDataField+8+2*field1(2)}{1,1}(:,mouse);
            ci(:,2) = fieldTable{2,allDataField+8+2*field2(2)}{1,1}(:,mouse);
%             plot(h2,x,ci(1,:), '--', 'color',[170 170 170]/255, 'lineWidth', 1);
%             plot(x,ymean, '--', 'color', [170 170 170]/255, 'lineWidth', 1);

            for i =1:2
                
                hh = errorbar(x(i),ci(1,i),ci(1,i) - ci(2,i), ci(3,i)- ci(1,i),'o',...
                        'MarkerSize',6, 'MarkerEdgeColor',  colors{2}, 'color',  colors{2}, 'LineWidth', lineWidthVal, 'CapSize', 0); 
                set(hh, 'Marker', 'none');
                plot(x(i)',ymean(i), 'Marker', markers{i}, 'MarkerSize',markersizes(i), 'color', colors{2}, 'LineWidth',lineWidthVal);
            end
          
            
       
    end

    hold off
    
    
    
    set(h1, 'box','off','TickDir','out', 'fontsize',fontSizeVal, 'FontName','Arial', 'XTickLabelRotation', 0, 'TickDir', 'out');
    ylim(h1,[-0.75 0.35]);
    yline(h1,0, '--', 'color', [0.5 0.5 0.5], 'LineWidth', lineWidthVal);
    yticks(h1, -0.6:0.2:0.3);

    xlim(h1, [0,max(x2)+70]);
    xticks(h1,[mean(x1), mean(x2)])
    xticklabels(h1,{'Contra stim', 'Ipsi stim'})
        
    h1.LineWidth = lineWidthVal;
  
    savefig(g1,fullfile(figureRoot,[genotype ' Inihibtion Correct fraction.fig']));
    exportgraphics(g1,fullfile(figureRoot, [genotype ' Inihibtion Bootstrapping Correct fraction.tiff']), 'Resolution', 1200);
    exportgraphics(g1,fullfile(figureRoot, [genotype ' Inihibtion Bootstrapping Correct fraction.pdf']), 'Resolution', 1200);
end



%% plot figures for overall perf --> mousewise combining hemispheres -->miss
clearvars ymean
plotTypes = {'Contralateral stims', 'Ipsilateral stims'};
% plotTypes = {'Amplitude-contra', 'Amplitude-ipsi'};
allDataField = 3;
meanallDataField = 3;
close all; 


hold on
% plot correct fraction
ugenotypes = unique(photoInhBootstrapped.Genotype, 'stable');
inhSites = unique(photoInhBootstrapped.InhSite, 'stable');
mousecolors = distinguishable_colors(4,{'w', 'k'});
genotypecolors{1} = {[1 0 0]; [0 0 1]};
genotypecolors{2} = {[1 0 0]; [0 0 1]};

markers = {'.', 'x'};
markersizes = [markerSizeVal,markerSizeVal-5];
for g= 1: numel(ugenotypes)
    genotype = ugenotypes{g};
    g1 = figure(g);clf
    set(g1, 'Units', 'inches', 'Position',  [1 1 widthVal heightVal]);
    colors = genotypecolors{g};
%     g1.WindowState= 'Maximized';
    fieldTable = photoInhBootstrapped_miss(strcmp(photoInhBootstrapped_miss.Genotype, genotype), :);
    meanfieldTable = photoInhTable_miss(strcmp(photoInhTable.Genotype, genotype), :);
    mouseNum = numel(fieldTable{1, allDataField});
    x1 = [];
    x2 = [];
    for mouse = 1: mouseNum
        
            field1 = [1,2,3,4]; % for Right S1 inh, contra ipsi amp-contra amp-ipsi
            field2 = [2,1,4,3];  % For leftS1, contra ipsi amp-contra amp-ipsi
            subplotNum =1:numel(plotTypes); 
            
            meanfield1 = [1,2,3,4];
            meanfield2 = [3,4,1,2];

            
            inhSite = [1,2];
            disp('Plotting contra')
            h1 = subplot(1,1,1);
            hold(h1, 'on')
            start_x =20;
            x = ((start_x  +(2-1)*300*0)  + 15*(mouse) + (inhSite-1)*75);
            x1(mouse) = median(x);
            ymean(1)= meanfieldTable{1,meanallDataField}{1,1}(mouse,meanfield1(2)) - meanfieldTable{1,meanallDataField}{1,1}(mouse,meanfield1(1));
            ymean(2)= meanfieldTable{2,meanallDataField}{1,1}(mouse,meanfield2(2)) - meanfieldTable{2,meanallDataField}{1,1}(mouse,meanfield2(1));
            ci(:,1) = fieldTable{1,allDataField+8+2*field1(1)}{1,1}(:,mouse);
            ci(:,2) = fieldTable{2,allDataField+8+2*field2(1)}{1,1}(:,mouse);
%             plot(h1,x,ci(1,:), '--', 'color', [170 170 170]/255, 'lineWidth', 1);
%             plot(x,ymean, '--', 'color', [170 170 170]/255, 'lineWidth', 1);
            for i =1:2
                
               
                hh = errorbar(x(i),ci(1,i),ci(1,i) - ci(2,i), ci(3,i)- ci(1,i),'o',...
                        'MarkerSize',6, 'MarkerEdgeColor',  colors{1}, 'color',  colors{1}, 'LineWidth',lineWidthVal, 'CapSize', 0); 
                 plot(x(i)',ymean(i), 'Marker',markers{i}, 'color', colors{1}, 'MarkerSize', markersizes(i), 'LineWidth',lineWidthVal);
                set(hh, 'Marker', 'none');
            end
            
            
            disp('Plotting ipsi')
%             h2 = subplot(1,numel(plotTypes),subplotNum(2));
%             hold(h2, 'on')

            x = ((start_x  +(2-1)*200)  + 15*(mouse) + (inhSite-1)*75);
            x2(mouse) = median(x);
            ymean(1)= meanfieldTable{1,meanallDataField}{1,1}(mouse,meanfield1(4)) - meanfieldTable{1,meanallDataField}{1,1}(mouse,meanfield1(3));
            ymean(2)= meanfieldTable{2,meanallDataField}{1,1}(mouse,meanfield2(4)) - meanfieldTable{2,meanallDataField}{1,1}(mouse,meanfield2(3));
            ci(:,1) = fieldTable{1,allDataField+8+2*field1(2)}{1,1}(:,mouse);
            ci(:,2) = fieldTable{2,allDataField+8+2*field2(2)}{1,1}(:,mouse);
%             plot(h2,x,ci(1,:), '--', 'color',[170 170 170]/255, 'lineWidth', 1);
%             plot(x,ymean, '--', 'color', [170 170 170]/255, 'lineWidth', 1);

            for i =1:2
                
                hh = errorbar(x(i),ci(1,i),ci(1,i) - ci(2,i), ci(3,i)- ci(1,i),'o',...
                        'MarkerSize',6, 'MarkerEdgeColor',  colors{2}, 'color',  colors{2}, 'LineWidth', lineWidthVal, 'CapSize', 0); 
                set(hh, 'Marker', 'none');
                plot(x(i)',ymean(i), 'Marker', markers{i}, 'MarkerSize',markersizes(i), 'color', colors{2}, 'LineWidth',lineWidthVal);
            end
          
            
       
    end

    hold off
    
    
    
    set(h1, 'box','off','TickDir','out', 'fontsize',fontSizeVal, 'FontName','Arial', 'XTickLabelRotation', 0, 'TickDir', 'out');
    ylim(h1,[-0.2 0.6]);
    yline(h1,0, '--', 'color', [0.5 0.5 0.5], 'LineWidth', lineWidthVal);
    yticks(h1, -0.2:0.2:0.6);

    xlim(h1, [0,max(x2)+70]);
    xticks(h1,[mean(x1), mean(x2)])
    xticklabels(h1,{'Contra stim', 'Ipsi stim'})
        
    h1.LineWidth = lineWidthVal;
  
    savefig(g1,fullfile(figureRoot,[genotype ' Inihibtion Miss fraction.fig']));
    exportgraphics(g1,fullfile(figureRoot, [genotype ' Inihibtion Bootstrapping Miss fraction.tiff']), 'Resolution', 1200);
    exportgraphics(g1,fullfile(figureRoot, [genotype ' Inihibtion Bootstrapping Miss fraction.pdf']), 'Resolution', 1200);
end


%% plot figures for overall perf --> mousewise combining hemispheres --> amplitudes
plotTypes = {'Contralateral stims', 'Ipsilateral stims'};
% plotTypes = {'Amplitude-contra', 'Amplitude-ipsi'};
allDataField = 3;
meanallDataField = 3;
close all; 

% plot correct fraction
ugenotypes = unique(photoInhBootstrapped.Genotype, 'stable');
inhSites = unique(photoInhBootstrapped.InhSite, 'stable');
mousecolors = distinguishable_colors(4,{'w', 'k'});
genotypecolors{1} = {[1 0 0]; [0 0 1]};
genotypecolors{2} = {[1 0 0]; [0 0 1]};
markers = {'.', 'x'};
markersizes = [markerSizeVal,markerSizeVal-5];
genoComparison = cell(2,2);
for g= 1: numel(ugenotypes)
    genotype = ugenotypes{g};     
    g1 = figure(g);clf
    set(g1, 'Units', 'inches', 'Position',  [1 1 widthVal heightVal]);
    hold on
    fieldTable = photoInhBootstrapped(strcmp(photoInhBootstrapped.Genotype, genotype), :);
    meanfieldTable = photoInhTable(strcmp(photoInhTable.Genotype, genotype), :);
    mouseNum = numel(fieldTable{1, allDataField});
    colors = genotypecolors{g};
    
    for mouse = 1: mouseNum
        
            field1 = [3,4]; % for Right S1 inh, contra ipsi amp-contra amp-ipsi
            field2 = [4,3];  % For leftS1, contra ipsi amp-contra amp-ipsi
            subplotNum =1:numel(plotTypes); 
            
            

            
            inhSite = [1,2];
             
            start_x = 20;
            x = ((start_x  +(g-1)*300)  + 15*(mouse) + (inhSite-1)*75);

            disp('Plotting contra-amp')
            h1 = subplot(1,1,1);    
            hold(h1, 'on')
            x = ((start_x  +(2-1)*150*0)  + 15*(mouse) + (inhSite-1)*75);
            x1(mouse) = median(x);
            y(1) = fieldTable{1,allDataField+8+2*field1(1)}{1,1}(1,mouse)/10;  
            y(2) = fieldTable{2,allDataField+8+2*field2(1)}{1,1}(1,mouse)/10;  
            for i =1:2
                plot(h1,x(i),y(i),'Marker', markers{i}, 'MarkerSize', markersizes(i), 'MarkerEdgeColor', colors{1}, 'color',  colors{i}, 'LineWidth',lineWidthVal);
            end
            genoComparison{g,1} = [genoComparison{g,1}, y];
   
           
            disp('Plotting ipsi-amp')
%             h2 = subplot(1,numel(plotTypes),subplotNum(4));    
%             hold(h2, 'on')
            x = ((start_x  +(2-1)*200)  + 15*(mouse) + (inhSite-1)*75);
            x2(mouse) = median(x);
            y(1) = fieldTable{1,allDataField+8+2*field1(2)}{1,1}(1,mouse)/10;  
            y(2) = fieldTable{2,allDataField+8+2*field2(2)}{1,1}(1,mouse)/10;  
            for i =1:2
                plot(h1,x(i),y(i), 'Marker', markers{i}, 'MarkerSize', markersizes(i), 'MarkerEdgeColor', colors{2}, 'color',  colors{i}, 'LineWidth',lineWidthVal);
            end
            genoComparison{g,2} = [genoComparison{g,2}, y];
            
       
    end
    hold off  
    
    
    set(h1, 'box','off','TickDir','out', 'FontName', 'Arial' ,'fontsize', fontSizeVal, 'LineWidth', lineWidthVal);
    ylim(h1,[0 110]);
    yticks(h1, 0:25:100)
    ylabel(h1,'Amplitude (% of max.)', 'fontsize',8, 'FontName', 'Arial')
    %     xtickangle(45);
    xlim(h1, [0,max(x2)+70]);
    xticks(h1,[mean(x1), mean(x2)])
    xticklabels(h1,{'Contra stim', 'Ipsi stim'})
        
    h1.LineWidth = lineWidthVal;
  
    savefig(g1,fullfile(figureRoot,[genotype ' Inihibtion Amplitudes.fig']));
    exportgraphics(g1,fullfile(figureRoot, [genotype ' Inihibtion Amplitudes.tiff']), 'Resolution', 300);
    exportgraphics(g1,fullfile(figureRoot, [genotype ' Inihibtion Amplitudes.pdf']), 'Resolution', 300);
end
%%
fileID = fopen(fullfile(figureRoot, 'OptobehavMeanAmplitudedatavalues.txt'), 'w');
pop1 = adtest(genoComparison{1,1});
pop2 = adtest(genoComparison{1,2});
pop3 = adtest(genoComparison{2,1});
pop4 = adtest(genoComparison{2,2});
stimNames = {'Contra', 'Ipsi'};
for g = 1: numel(ugenotypes)
    for stim = 1:numel(stimNames)
        fprintf(fileID, ['For genotype: ' ugenotypes{g} ' ' stimNames{stim} ' mean: ' num2str( mean(genoComparison{g,stim})) ' sd: '  num2str( std(genoComparison{g, stim})) '\n']);
    end
end

[P(1), H(1)] = ranksum(genoComparison{1,1}, genoComparison{2,1});
[P(2), H(2)] = ranksum(genoComparison{1,2}, genoComparison{2,2});
fprintf(fileID, ['Between genotype Mann whitney U test comparison for contra p-value  ' num2str( P(1)) '\n']);  
fprintf(fileID, ['Between genotype Mann whitney U test comparison for ipsi p-value  ' num2str( P(2)) '\n']);


fclose(fileID);



%% Plot raw inhibition values
figureRoot = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\FigS2';
close all
uGenotypes = unique(photoInhTable.Genotype, 'Stable');
genotypecolors{1} = {[1 0 0]; [0 0 1]};
genotypecolors{2} = {[1 0 0]; [0 0 1]};
fileID = fopen(fullfile(figureRoot, 'OptobehavMeanCorerctdatavalues.txt'), 'w');
genoComparison = {};
% Contra stim
for geno = 1: numel(uGenotypes)
    genotype= uGenotypes{geno};
    genoData = photoInhTable(strcmp(photoInhTable.Genotype, genotype), :);
    inhSites = unique(genoData.InhSite, 'Stable');
    colors = genotypecolors{geno};
    contraData = [];
    ipsiData = [];
    for inh = 1:numel(inhSites)
        inhSite = inhSites{inh};
        if strcmp(inhSite, 'Right S1')
            field = [1, 2, 3, 4];
        else
             field = [3, 4, 1, 2];
        end
        
        inhData = genoData(strcmp(genoData.InhSite, inhSite), :);
        
        meanData = inhData.MeanData;
        contraData = [contraData; meanData{1}(:,field(1:2))];
        ipsiData = [ipsiData; meanData{1}(:,field(3:4))];
    end
    genoComparison{geno,1} = contraData;
    genoComparison{geno,2} = ipsiData;
    g = figure('Units', 'inches', 'Position', [1 1 3,2]);
    subplot(1,2,1);
    hold on
    plot([0.75, 1.25], contraData, '-', 'Color', [colors{1} 0.3], 'LineWidth',1);
    plot([0.75, 1.25], mean(contraData,1), '-', 'Color', [colors{1} 1], 'LineWidth',1);
    yline(0.5, '--', 'LineWidth', 1, 'Color', [0 0 0]);
    hold off
    xlim([0.5,1.5])
    ylim([0 1])
    xticks([0.75 1.25]);
    xticklabels({'Stim' 'Stim + opto'})
    yticks([0,0.1:0.2:0.9, 1])
    set(gca, 'FontName', 'Arial', 'FontSize', 8, 'TickDir', 'out', 'LineWidth', 1);
    ylabel(['Correct Fraction'], 'FontName', 'Arial', 'FontSize', 8);
    title('Contra stim', 'FontName', 'Arial', 'FontSize', 8, 'FontWeight','normal', 'Color', colors{1})
    fprintf(fileID, ['For genotype: ' genotype ' Mean contra is ' num2str( mean(contraData,1)) ' std: ' num2str(std(contraData)) '\n']);

    subplot(1,2,2);
    hold on
    plot([0.75, 1.25], ipsiData, '-', 'Color', [colors{2} 0.3], 'LineWidth',1);
    plot([0.75, 1.25], mean(ipsiData,1), '-', 'Color', [colors{2} 1], 'LineWidth',1);
    yline(0.7, '--', 'LineWidth', 1, 'Color', [0 0 0]);
    hold off
    xlim([0.5,1.5])
    yticks([0,0.1:0.2:0.9, 1])
    ylim([0 1])
    xticks([0.75 1.25]);
    xticklabels({'Stim' 'Stim + opto'})
    set(gca, 'FontName', 'Arial', 'FontSize', 8, 'TickDir', 'out', 'LineWidth', 1);
    title('Ipsi stim', 'FontName', 'Arial', 'FontSize', 8, 'FontWeight','normal', 'Color', colors{2})    
    fprintf(fileID, ['For genotype: ' genotype ' Mean ipsi is ' num2str( mean(ipsiData,1)) ' std: ' num2str(std(ipsiData)) '\n']);    
    
    savefig(g, fullfile(figureRoot, [genotype ' Mean performance.fig']));
    exportgraphics(g, fullfile(figureRoot, [genotype ' Mean performance.tiff']), 'Resolution', 1200);
    exportgraphics(g, fullfile(figureRoot, [genotype ' Mean performance.pdf']), 'Resolution', 1200);

end

[H(1), P(1)] = ttest2(genoComparison{1,1}(:,2), genoComparison{2,1}(:,2));
[H(2), P(2)] = ttest2(genoComparison{1,2}(:,2), genoComparison{2,2}(:,2));
fprintf(fileID, ['Between genotype comparison for contra p-value for after effect is ' num2str( P(1)) '\n']);  
fprintf(fileID, ['Between genotype comparison for ipsi p-value for after effect is ' num2str( P(2)) '\n']);

[H(1), P(1)] = ttest2(genoComparison{1,1}(:,1), genoComparison{2,1}(:,1));
[H(2), P(2)] = ttest2(genoComparison{1,2}(:,1), genoComparison{2,2}(:,1));
fprintf(fileID, ['Between genotype comparison for contra p-value for baseline is ' num2str( P(1)) '\n']);  
fprintf(fileID, ['Between genotype comparison for ipsi p-value for baseline is ' num2str( P(2)) '\n']);

% compare within the genotype paired t-test
% for WT
g = 1;
[H(1), P(1)] = ttest(genoComparison{g,1}(:,1), genoComparison{g,1}(:,2));
[H(2), P(2)] = ttest(genoComparison{g,2}(:,1), genoComparison{g,2}(:,2));
fprintf(fileID, ['For genotype ' uGenotypes{g} ' paired ttest comparison for contra p-value for after effect is ' num2str( P(1)) '\n']);  
fprintf(fileID, ['For genotype ' uGenotypes{g} ' paired ttest comparison for ipsi p-value for after effect is ' num2str( P(2)) '\n']);

% For KO
g = 2;
[H(1), P(1)] = ttest(genoComparison{g,1}(:,1), genoComparison{g,1}(:,2));
[H(2), P(2)] = ttest(genoComparison{g,2}(:,1), genoComparison{g,2}(:,2));
fprintf(fileID, ['For genotype ' uGenotypes{g} ' paired ttest comparison for contra p-value for after effect is ' num2str( P(1)) '\n']);  
fprintf(fileID, ['For genotype ' uGenotypes{g} ' paired ttest comparison for ipsi p-value for after effect is ' num2str( P(2)) '\n']);

fclose(fileID);


%% Plot raw inhibition values
figureRoot = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\FigS2';
close all
uGenotypes = unique(photoInhTable_miss.Genotype, 'Stable');
genotypecolors{1} = {[1 0 0]; [0 0 1]};
genotypecolors{2} = {[1 0 0]; [0 0 1]};
fileID = fopen(fullfile(figureRoot, 'OptobehavMeanMissdatavalues.txt'), 'w');
genoComparison= {};
% Contra stim
for geno = 1: numel(uGenotypes)
    genotype= uGenotypes{geno};
    genoData = photoInhTable_miss(strcmp(photoInhTable_miss.Genotype, genotype), :);
    inhSites = unique(genoData.InhSite, 'Stable');
    colors = genotypecolors{geno};
    contraData = [];
    ipsiData = [];
    for inh = 1:numel(inhSites)
        inhSite = inhSites{inh};
        if strcmp(inhSite, 'Right S1')
            field = [1, 2, 3, 4];
        else
             field = [3, 4, 1, 2];
        end
        
        inhData = genoData(strcmp(genoData.InhSite, inhSite), :);
        
        meanData = inhData.MeanData;
        contraData = [contraData; meanData{1}(:,field(1:2))];
        ipsiData = [ipsiData; meanData{1}(:,field(3:4))];
    end
    genoComparison{geno,1} = contraData;
    genoComparison{geno,2} = ipsiData;
    g = figure('Units', 'inches', 'Position', [1 1 3,2]);
    subplot(1,2,1);
    hold on
    plot([0.75, 1.25], contraData, '-', 'Color', [colors{1} 0.3], 'LineWidth',1);
    plot([0.75, 1.25], mean(contraData,1), '-', 'Color', [colors{1} 1], 'LineWidth',1);
    hold off
    xlim([0.5,1.5])
    ylim([0 0.5])
    xticks([0.75 1.25]);
    xticklabels({'Stim' 'Stim + opto'})
    yticks([0,0.1:0.2:0.9, 1])
    set(gca, 'FontName', 'Arial', 'FontSize', 8, 'TickDir', 'out', 'LineWidth', 1);
    ylabel(['Miss fraction Fraction'], 'FontName', 'Arial', 'FontSize', 8);
    title('Contra stim', 'FontName', 'Arial', 'FontSize', 8, 'FontWeight','normal', 'Color', colors{1})
    fprintf(fileID, ['For genotype: ' genotype ' Mean contra is ' num2str( mean(contraData,1)) '\n']);

    subplot(1,2,2);
    hold on
    plot([0.75, 1.25], ipsiData, '-', 'Color', [colors{2} 0.3], 'LineWidth',1);
    plot([0.75, 1.25], mean(ipsiData,1), '-', 'Color', [colors{2} 1], 'LineWidth',1);
    yline(0.7, '--', 'LineWidth', 1, 'Color', [0 0 0]);
    hold off
    xlim([0.5,1.5])
    yticks([0,0.1:0.2:0.9, 1])
    ylim([0 0.5])
    xticks([0.75 1.25]);
    xticklabels({'Stim' 'Stim + opto'})
    set(gca, 'FontName', 'Arial', 'FontSize', 8, 'TickDir', 'out', 'LineWidth', 1);
    title('Ipsi stim', 'FontName', 'Arial', 'FontSize', 8, 'FontWeight','normal', 'Color', colors{2})    
    fprintf(fileID, ['For genotype: ' genotype ' Mean ipsi is ' num2str( mean(ipsiData,1)) '\n']);    
    
    savefig(g, fullfile(figureRoot, [genotype ' Mean performance.fig']));
    exportgraphics(g, fullfile(figureRoot, [genotype ' Mean Miss performance.tiff']), 'Resolution', 1200);
    exportgraphics(g, fullfile(figureRoot, [genotype ' Mean Miss performance.pdf']), 'Resolution', 1200);

end
[H(1), P(1)] = ttest2(genoComparison{1,1}(:,2), genoComparison{2,1}(:,2));
[H(2), P(2)] = ttest2(genoComparison{1,2}(:,2), genoComparison{2,2}(:,2));
fprintf(fileID, ['For contra p-value for after effect is ' num2str( P(1)) '\n']);  
fprintf(fileID, ['For ipsi p-value for after effect is ' num2str( P(2)) '\n']);

% compare within the genotype paired t-test
% for WT
g = 1;
[H(1), P(1)] = ttest(genoComparison{g,1}(:,1), genoComparison{g,1}(:,2));
[H(2), P(2)] = ttest(genoComparison{g,2}(:,1), genoComparison{g,2}(:,2));
fprintf(fileID, ['For genotype ' uGenotypes{g} ' paired ttest comparison for contra p-value for after effect is ' num2str( P(1)) '\n']);  
fprintf(fileID, ['For genotype ' uGenotypes{g} ' paired ttest comparison for ipsi p-value for after effect is ' num2str( P(2)) '\n']);

% For KO
g = 2;
[H(1), P(1)] = ttest(genoComparison{g,1}(:,1), genoComparison{g,1}(:,2));
[H(2), P(2)] = ttest(genoComparison{g,2}(:,1), genoComparison{g,2}(:,2));
fprintf(fileID, ['For genotype ' uGenotypes{g} ' paired ttest comparison for contra p-value for after effect is ' num2str( P(1)) '\n']);  
fprintf(fileID, ['For genotype ' uGenotypes{g} ' paired ttest comparison for ipsi p-value for after effect is ' num2str( P(2)) '\n']);

fclose(fileID);

%% Plot task structure
g = figure(1); clf;
set(g, 'Units', 'centimeters', 'Position', [50, 50, 70,40]/10);
hold on;
linWidths = 1;
timeStart = -0.1;

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


% masking flash 20 hz
duration = 3;
constStart = 0.1;
constEnd = 2.8;
freq = 20;


t = ((1/Fs)):1/Fs:duration;
y = zeros(size(t));
y((constStart)*Fs+1:(constEnd)*Fs)=2;
y(t<=(constStart))= 0;
y(t>constEnd)=1-(t(t>constEnd)-constEnd)/(duration-constEnd);

y1=arrayfun(@(x) (sin(2*pi*freq*x-pi/2)+1)/2, t);
y2=arrayfun(@(x, x1) conv(x,x1), y,y1);

tNew = [timeStart:1/Fs:-1/Fs, t, t(end)+1/Fs:1/Fs:duration+0.5];
yNew = [zeros(1,numel(timeStart:1/Fs:-1/Fs)), y2, zeros(1,numel(t(end)+1/Fs:1/Fs:duration+0.5))]+9;
plot(tNew,yNew, 'LineWidth', linWidths, 'color', [0 176 240]/255)


%  optoStim 20 hz

duration = 3;
constStart = 0.8;
constEnd = 2.8;
freq = 20;


t = ((1/Fs)):1/Fs:duration;
y = zeros(size(t));
y((constStart)*Fs+1:(constEnd)*Fs)=1;
y(t<=(constStart))= 0;
y(t>constEnd)=1-(t(t>constEnd)-constEnd)/(duration-constEnd);

y1=arrayfun(@(x) (sin(2*pi*freq*x-pi/2)+1)/2, t);
y2=arrayfun(@(x, x1) conv(x,x1), y,y1);

tNew = [timeStart:1/Fs:-1/Fs, t, t(end)+1/Fs:1/Fs:duration+0.5];
yNew = [zeros(1,numel(timeStart:1/Fs:-1/Fs)), y2, zeros(1,numel(t(end)+1/Fs:1/Fs:duration+0.5))]+12;
plot(tNew,yNew, 'LineWidth', linWidths, 'color', [0 176 240]/255)
ylim([0 13])
xlim([-0.5, duration+0.5])
% Remove the y-axis by setting the YColor to 'none'
ax = gca;  % Get current axes
ax.YColor = 'none';
xticks(0:3)
xticklabels({'0.0', '1.0', [],'3.0'})
set(gca, 'YColor', 'none', 'Fontsize', 8, 'Fontname', 'Arial', 'LineWidth', 1, 'TickDir', 'out');
% Set the axes position to occupy the whole figure [left, bottom, width, height]
set(ax, 'Position', [0.01 0.12 0.98 0.88]);
exportgraphics(g, fullfile(figureRoot, [genotype ' TaskStructure.tiff']), 'Resolution', 1200);
exportgraphics(g, fullfile(figureRoot, [genotype ' TaskStructure.pdf']), 'Resolution', 1200);




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

function pop1 = CheckNormality(data)
    [pop1] = adtest(data);
end

