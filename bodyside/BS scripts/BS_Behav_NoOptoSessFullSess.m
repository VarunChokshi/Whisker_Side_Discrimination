clear all
animalID = {'VC030105', 'VC030106', 'VC030107', 'VC030108', 'VC030109', 'VC030110', 'VC030112', 'VC030113', 'VC030114', 'VC030115'};% Choose a group folder
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
        case 'behavSEs'            
            behavDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            seNames = cellfun(@(x) endsWith(x,'se.mat'),behavDirInfo.name);            
            behavDirInfo(~seNames,:) = [];
            animalNames = cellfun(@(x) strsplit(x, ' '), behavDirInfo.name, 'UniformOutput', false);
            animalNames = cellfun(@(x) x{1}, animalNames, 'UniformOutput',false);
            behavDirInfo(~ismember(animalNames, animalID),:) = [];          
%       
        
    end
end




% Find all data files for each session
dataFileTb = table();
sessRem =[];
for i = height(behavDirInfo) : -1 : 1
    % Parse the file name of SatellitesViewer log to get session identifiers
    behavNameParts = strsplit(behavDirInfo.name{i}, {' ', '.'});
    animalId = behavNameParts{1};
    if ~ismember(animalId, animalID)
        continue
    end
    sessionDatetime = datetime(behavNameParts{2}, ...
        'Format', 'yyyy-MM-dd');
    subId = behavNameParts{3};
    
    
    dataFileTb.animalId{i} = animalId;
    dataFileTb.sessionDatetime(i) = sessionDatetime;
    dataFileTb.subId{i} = subId;
    
    % Add bControl log file path
    dataFileTb.sePath{i} = fullfile(behavDirInfo.folder{i}, behavDirInfo.name{i});
   
end


% dataFileTb(sessRem,:) =[];
    
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
% %% Plot all sessions
% 
% saveFig = fullfile('G:\VC03_RoboKO\VC0301\Figures\SessFigs\NoOptoFinalBehavSEs');
% BS.PlotSession(dataFileTb.sePath, saveFig);
% 
% %% Update SessInfos
% BS.ReUpdateSessInfo(dataFileTb);
% 

% Add stim as 3 columns freq, duration, amp, masking flash, PreStimNoLickTime, fracCorrect, fracMiss
% for i =1:1
for i =1:height(dataFileTb)
    load(dataFileTb.sePath{i})
    perf = struct2table(getPerfOverall(se));
    dataFileTb(i,perf.Properties.VariableNames) = perf;
end
% remove opto Sessions
isOpto = find(dataFileTb.isOpto);
dataFileTb(isOpto,:) = [];

%remove trials with non-full amplitudes
isnonFull = find(dataFileTb.stimRightAmp<1000 | dataFileTb.stimLeftAmp<1000| ...
    dataFileTb.stimRightDur~=150 | dataFileTb.stimLeftDur~=150 | dataFileTb.stimRightFreq~=20 | dataFileTb.stimLeftFreq~=20 ...
    | dataFileTb.sideAssist | dataFileTb.leftStimProb~=0.5| dataFileTb.PSNLT>0.2);
dataFileTb(isnonFull,:) = [];

WTdataFileTb = dataFileTb;


% For KO mice
animalID = {'VC030203', 'VC030204', 'VC030206', 'VC030207', 'VC030208', 'VC030209', 'VC030211', 'VC030213'};% Choose a group folder
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
        case 'behavSEs'            
            behavDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            seNames = cellfun(@(x) endsWith(x,'se.mat'),behavDirInfo.name);            
            behavDirInfo(~seNames,:) = [];
            animalNames = cellfun(@(x) strsplit(x, ' '), behavDirInfo.name, 'UniformOutput', false);
            animalNames = cellfun(@(x) x{1}, animalNames, 'UniformOutput',false);
            behavDirInfo(~ismember(animalNames, animalID),:) = [];          
%       
        
    end
end




% Find all data files for each session
dataFileTb = table();
sessRem =[];
for i = height(behavDirInfo) : -1 : 1
    % Parse the file name of SatellitesViewer log to get session identifiers
    behavNameParts = strsplit(behavDirInfo.name{i}, {' ', '.'});
    animalId = behavNameParts{1};
    if ~ismember(animalId, animalID)
        continue
    end
    sessionDatetime = datetime(behavNameParts{2}, ...
        'Format', 'yyyy-MM-dd');
    subId = behavNameParts{3};
    
    
    dataFileTb.animalId{i} = animalId;
    dataFileTb.sessionDatetime(i) = sessionDatetime;
    dataFileTb.subId{i} = subId;
    
    % Add bControl log file path
    dataFileTb.sePath{i} = fullfile(behavDirInfo.folder{i}, behavDirInfo.name{i});
    

end


% dataFileTb(sessRem,:) =[];
    
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


 % Add stim as 3 columns freq, duration, amp, masking flash, PreStimNoLickTime, fracCorrect, fracMiss
% for i =1:1
for i =1:height(dataFileTb)
    load(dataFileTb.sePath{i})
    perf = struct2table(getPerfOverall(se));
    dataFileTb(i,perf.Properties.VariableNames) = perf;
end
% remove opto Sessions
isOpto = find(dataFileTb.isOpto);
dataFileTb(isOpto,:) = [];

%remove trials with non-full amplitudes
isnonFull = find(dataFileTb.stimRightAmp<1000 | dataFileTb.stimLeftAmp<1000| ...
    dataFileTb.stimRightDur~=150 | dataFileTb.stimLeftDur~=150 | dataFileTb.stimRightFreq~=20 | dataFileTb.stimLeftFreq~=20 ...
    | dataFileTb.sideAssist | dataFileTb.leftStimProb~=0.5 | dataFileTb.PSNLT>0.2);
dataFileTb(isnonFull,:) = [];

KOdataFielTb = dataFileTb;

dataFileTb = [dataFileTb; WTdataFileTb];

%% 
%% compare perfgenotypes
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
readPaths = dataFileTb.sePath;
readPathParts = cellfun(@(x) strsplit(x, '\'), readPaths, 'UniformOutput', false);
seDir = fullfile(readPathParts{1}{1:end-2});
seNames = cellfun(@(x) x(end), readPathParts, 'UniformOutput',false);
clearvars -except readPaths dataFileTb readPathParts seDir seNames animalID trials inhSitesAll;
WTanimalID = {'VC030105', 'VC030106', 'VC030107', 'VC030108', 'VC030109', 'VC030110', 'VC030112', 'VC030113', 'VC030114', 'VC030115'};% Choose a group folder
KOanimalID = {'VC030203', 'VC030204', 'VC030206', 'VC030207', 'VC030208', 'VC030209', 'VC030211', 'VC030213'};% Choose a group folder

animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
AnimalIDs = cellfun(@(x) x{1}, animal, 'UniformOutput', false);
animalID = unique(AnimalIDs);
% get all the trialNums for each trialType for each session and mouse

pathParts = strsplit(seDir, '\');
figureFolder = fullfile(pathParts{1:end-2}, 'Figures');


savePath= 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\Fig2';
if ~exist(savePath, 'dir')
    mkdir(savePath);
end
%
photoInhAll = table();

for animalNum =1:size(animalID,1)
     ani = animalID{animalNum}; 
     
    sessNum =1;
    for i = find(ismember(AnimalIDs, ani))'        
        load(readPaths{i});
        
        behavData = se.GetTable('behavValue');
        
        trialInd = 50:300;
        se = BS.Preprocess.keepTrials(trialInd, se);

        %Remove aborted trials due to pre stim no licktime licks
        responses = behavData.response;
        abortTrials = find(cell2mat(responses) == 3); 
        behavData(abortTrials,:) = [];
        
        % separate missed trials vs all trials
        responses = behavData.result;
        missTrials = isnan(responses);
        missData = behavData(missTrials,:);
%         behavData(missTrials, :) =[];        

        
        
        trialTypes = unique(behavData.trialType);
        
        if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
            trialTypes = trials{2};
        else
            trialTypes = trials{1};
        end
    

        for trialType = 1:numel(trialTypes)
            trialTypeInd = strcmp(trialTypes{trialType}, behavData.trialType);
            fracResult{animalNum}{sessNum}(trialType) = mean(behavData.result(trialTypeInd));
            
            missFrac{animalNum}{sessNum}(trialType) =numel(find(strcmp(trialTypes{trialType}, missData.trialType)))/...
                   (numel(find(strcmp(trialTypes{trialType}, missData.trialType))) + numel(find(strcmp(trialTypes{trialType}, behavData.trialType))));
            allTrialTypes{animalNum}{sessNum} = trialTypes;
        end 
        if ~ismember('Genotype', fieldnames(behavData))
            if ismember(behavData.mouseName{1}, WTanimalID)
                geno = {'WT'};
            else
                geno = {'KO'};
            end
            behavData.Genotype = repmat(geno, height(behavData), 1);
        end

        if ismember('inhSite', fieldnames(behavData))
            behavData.inhSite = [];
        end
        
        if ~isempty(photoInhAll)
            % reorder the varibles of behavData to match photoInhAll      
            behavData = behavData(:, photoInhAll.Properties.VariableNames);    
        end

        %concatenate the behavDatas
        photoInhAll= [photoInhAll; behavData];
        
        sessNum= sessNum+1;
        
       
    end

end


%% Remove _NoCue from TrialTypes

trialTypes= photoInhAll.trialType;
parfor i =1:height(trialTypes)
    if sum(ismember(trialTypes{i}, '_NoCue'))>8
        trialTypes{i} = trialTypes{i}(1:end-6);
%         disp(num2str(sum(ismember(trialTypes{i}, '_NoCue'))));
%         disp(trialTypes{i});
    else
        disp(num2str(sum(ismember(trialTypes{i}, '_NoCue'))));
        disp(trialTypes{i});
    end
end



Genotypes = unique(photoInhAll.Genotype); 

trialTypes= unique(photoInhAll.trialType); % left, left_opto, right, right_opto


mice = unique(photoInhAll.mouseName);
        
if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
    trialTypes = trials{2};
else
    trialTypes = trials{1};
end 

%
nboot = 1000; % number for bootstrapping

% 
% delta_mouse = cell(length(mice),1);
% delta_mouse_miss = cell(length(mice),1);

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

    % average across sessions
    photoInh_bootstrapped{g,1} = Genotype;
    photoInh_bootstrapped{g,2} = {};
    photoInh_bootstrapped{g,3} = fracCorrect_mouse;        
    photoInh_bootstrapped_miss{g,1} = Genotype;
    photoInh_bootstrapped_miss{g,2} = {};
    photoInh_bootstrapped_miss{g,3} = fracMiss_mouse;  

    photoInh{g,1} = Genotype;
    photoInh{g,2} = {};
    photoInh{g,3} = overallOmeanPerf;     
    photoInh{g,4} = cell2mat(overallMeanPerf);        
    photoInh_miss{g,1} = Genotype;
    photoInh_miss{g,2} = {};
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
figureRoot = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\FigS2';
save(fullfile(figureRoot, 'NooptoFullamp_nboot1000.mat'), 'photoInhTable', 'photoInhTable_miss', 'photoInhBootstrapped_miss', 'photoInhBootstrapped', 'figureRoot', 'dataFileTb');



%% load processed data
clear all
figureRoot = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\FigS2';
load(fullfile(figureRoot, 'AllVars_nboot10000.mat'))


%% plot figures for overall perf
plotTypes = {'Overall', 'Left Stim trials', 'Right Stim trials', 'Amplitude-left', 'Amplitude-right'};
ylabels = {'Correct fraction', 'Correct fraction', 'Correct fraction', 'Amplitude (% of maximum)','Amplitude (% of maximum)'};
colors_tt = {[1 0 0] [0 0 1]}; 
close all; 
g1 = figure(100);clf
g1.WindowState= 'Maximized';
start_x =20;
% plot correct fraction

colors = {[0 0 1], [128 0 128]/255, [1 0 0],  [255 0 255]/255};
for field = 1:numel(plotTypes)
    
    for g=1: height(photoInhBootstrapped)
    if g ==1
        color = [128 128 128]/255;
    else
        color = [1 0 0];
    end
    subplot(1,numel(plotTypes),field)
    hold on 
    mouseNum = numel(photoInhBootstrapped{g,3+3*field-2}{1,1});
    x = ((start_x  +(g-1)*250)  + 15*[1:mouseNum]);
    if any(ismember(field, [4,5]))
        y = photoInhBootstrapped{g,3+3*field-2}{1,1}/10;
        plot(x,y,'.', 'MarkerSize',25, 'Color', color, 'MarkerEdgeColor', color);
    else            
        ci = photoInhBootstrapped{g,3+3*field-1}{1,1};            
        hh =errorbar(x,ci(1,:),ci(1,:) - ci(2,:), ci(3,:)- ci(1,:),'o',...
            'MarkerSize',6, 'Color', color, 'MarkerEdgeColor', color, 'LineWidth', 1.5);  
        set(hh, 'Marker', 'none')
        if field ==1
            meanField = photoInhTable{g,3 + 0}{1};
            plot(x,meanField,'x', 'MarkerSize', 10, 'Color', color, 'MarkerEdgeColor', color);
        else
            meanField = photoInhTable{g,3+1}{1}(:,field-1);
            plot(x,meanField,'x', 'MarkerSize', 10, 'Color', color, 'MarkerEdgeColor', color);
        end
    end
        
               
           
    end
    hold off
    set(gca, 'box','off','TickDir','out');
    if any(ismember(field, [4,5]))
        ylim([0 110])
        yticks(0:10:100)
    else
        ylim([0 1]);
        yline(0.7, '--k');
    end
    ylabel(ylabels{field})
%     xtickangle(45);
    xlim([0,500]);
    xticks([(start_x  + 75), (start_x  + 325)])
    xticklabels({'WT', 'KO'})
    title(plotTypes{field});
    
end
savefig(g1,fullfile(figureRoot,['No inihibtion Bootstrapping KO vs WT Correct fraction.fig']));
exportgraphics(g1,fullfile(figureRoot, ['No inihibtion fraction Bootstrapping KO vs WT Correct fraction.png']));

%% plot figures for overall perf miss trials
plotTypes = {'Overall', 'Left Stim trials', 'Right Stim trials', 'Amplitude-left', 'Amplitude-right'};
ylabels = {'Miss fraction', 'Miss fraction', 'Miss fraction', 'Amplitude (% of maximum)','Amplitude (% of maximum)'};
colors_tt = {[1 0 0] [0 0 1]}; 
close all; 
g1 = figure(100);clf
g1.WindowState= 'Maximized';
start_x =20;
% plot correct fraction

colors = {[0 0 1], [128 0 128]/255, [1 0 0],  [255 0 255]/255};
for field = 1:numel(plotTypes)
    
    for g=1: height(photoInhBootstrapped_miss)
    if g ==1
        color = [128 128 128]/255;
    else
        color = [1 0 0];
    end
    subplot(1,numel(plotTypes),field)
    hold on 
    mouseNum = numel(photoInhBootstrapped_miss{g,3+3*field-2}{1,1});
    x = ((start_x  +(g-1)*250)  + 15*[1:mouseNum]);
    if any(ismember(field, [4,5]))
        y = photoInhBootstrapped_miss{g,3+3*field-2}{1,1}/10;
        plot(x,y,'.', 'MarkerSize', 25, 'Color', color, 'MarkerEdgeColor', color);
    else            
        ci = photoInhBootstrapped_miss{g,3+3*field-1}{1,1};            
        hh =errorbar(x,ci(1,:),ci(1,:) - ci(2,:), ci(3,:)- ci(1,:),'o',...
            'MarkerSize',6, 'Color', color, 'MarkerEdgeColor', color, 'LineWidth', 1.5);  
        set(hh, 'Marker', 'none');
        if field ==1
            meanField = photoInhTable_miss{g,3 + 0}{1};
            plot(x,meanField,'x', 'MarkerSize', 10, 'Color', color, 'MarkerEdgeColor', color);
        else
            meanField = photoInhTable_miss{g,3+1}{1}(:,field-1);
            plot(x,meanField,'x', 'MarkerSize', 10, 'Color', color, 'MarkerEdgeColor', color);
        end
    end
        
               
           
    end
    hold off
    set(gca, 'box','off','TickDir','out');
    if any(ismember(field, [4,5]))
        ylim([0 110])
        yticks(0:10:100)
    else
        ylim([0 1]);
        
    end
    ylabel(ylabels{field})
%     xtickangle(45);
    xlim([0,500]);
    xticks([(start_x  + 75), (start_x  + 325)])
    xticklabels({'WT', 'KO'})
    title(plotTypes{field});
    
end
savefig(g1,fullfile(figureRoot,['No inihibtion Bootstrapping KO vs WT miss.fig']));
exportgraphics(g1,fullfile(figureRoot, ['No inihibtion fraction Bootstrapping KO vs WT miss.png']));


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

function [amp, freq, dur]= bodyside6Stims(stim)

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