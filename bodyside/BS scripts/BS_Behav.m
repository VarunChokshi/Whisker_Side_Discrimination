%% Find files based on SatellitesViewer files
clear all
% WT animals
% animalID = {'VC030105', 'VC030106', 'VC030107', 'VC030108', 'VC030109', 'VC030110', 'VC030112', 'VC030113', 'VC030114', 'VC030115'};

% KO animals
animalID = { 'VC030213', 'VC030115'};% Choose a group folder

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
        case 'Bcontrol'
            behavAnimalsInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            if ~isempty(animalID)
                behavAnimalsInfo(~ismember(behavAnimalsInfo.name, animalID),:) = [];
            end
            behavDirInfo = [];
            for j = 1:height(behavAnimalsInfo)
                
                behavDirInfo = [behavDirInfo; MBrowse.Dir2Table(fullfile(behavAnimalsInfo.folder{j}, ...
                    behavAnimalsInfo.name{j}, '*.mat'))];

            end
        case 'SessInfoNoOpto'
            sessInfoDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}, '*.csv'));   
            
            animalNames= cellfun(@(x) strsplit(x, '_'), sessInfoDirInfo.name, 'UniformOutput', false);
            animalNames = cellfun(@(x) x{1}, animalNames, 'UniformOutput',false);
            sessInfoDirInfo(~ismember(animalNames, animalID),:) = [];
        
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

    % Add sessInfo to data Table
    dataFileTb.sessInfoPaths{i} = [];
    if ~isempty(sessInfoDirInfo)
        queryStr = ['^' animalId '.+'];
        isHit = ~cellfun(@isempty, regexpi(sessInfoDirInfo.name, queryStr));
        if any(isHit)
            dataFileTb.sessInfoPaths{i} = fullfile(sessInfoDirInfo.folder{isHit}, sessInfoDirInfo.name{isHit});
        end            
    end
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


BcontDir = [groupDir, '\Bcontrol'];
seDir = [groupDir, '\behavSEs'];


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
    
    if ~isempty(dataFileTb.sessInfoPaths{i})
        seshInfoTb = readtable(dataFileTb.sessInfoPaths{i}); 
        seshInfoTb.seshDate = arrayfun(@(x) datetime(x, 'InputFormat','yyMMdd', ...
            'Format', 'yyyy-MM-dd'), string(seshInfoTb.seshDate), 'UniformOutput', false); 
        
        ind = ismember(cellfun(@datenum, seshInfoTb.seshDate), datenum(dataFileTb.sessionDatetime(i))) & subId == cell2mat(seshInfoTb.subId);
        seshInfoTb = seshInfoTb(ind,:);     
        seshInfo = seshInfoTb; 
        se.userData.sessionInfo = seshInfo;
    end

    
 
    % Add Bcontrol data    
    bct_data = BS.bodyside_switchArray(dataFileTb.behavPath{i}, dataFileTb.sessionDatetime(i));        
    
      

     % Load Bcontrol data amd creat a trial type map     
    disp('Processing Bcontrol data');
    if ~isempty(dataFileTb.sessInfoPaths{i})
        if ~isempty(seshInfo.inhSite)
            if any(ismember(seshInfo.inhSite{:}, seshInfo.Injection{:}))
                
                BS.Preprocess.BCT2SE(bct_data, se, 0, seshInfo.inhSite, seshInfo.Genotype,1);   
            else
                BS.Preprocess.BCT2SE(bct_data, se, 0, seshInfo.inhSite, seshInfo.Genotype, 0);
            end
        else
            BS.Preprocess.BCT2SE(bct_data, se, 0);   
        end
    else
        BS.Preprocess.BCT2SE(bct_data, se, 0);
    end
    fprintf('\n');

      % Save SE
    disp('Saving SE to disk');    
    
    save(sePath, 'se', '-v7.3');   
   
    fprintf('\n');
   
end


clear i sessionId


%% plot session using se w/o  need to 
clear all

sePaths = MBrowse.Files(['G:\VC03_RoboKO\VC0301\behavSEs'], 'Select se folder');

for sess = 1:numel(sePaths)
    load(sePaths{sess});
    sePathSplit = strsplit(sePaths{sess}, {'\', ' '}); 
    saveFig = fullfile(sePathSplit{1:3}, '\Figures\SessFigs\NoOptoFinalBehavSEs');
    if ~exist('saveFig', 'dir')
        mkdir(saveFig);
    end
    behav = se.GetTable('behavValue');
    stimTypes = {'Right', 'Left'};   
    trialTypes = behav.trialType;    
    stimSplit = cellfun(@(x) strsplit(x, '_'), trialTypes, 'UniformOutput', false);
    response = behav.response;
    rightTrials = cellfun(@(x) any(ismember(x,'Right')), stimSplit, 'UniformOutput',false);
    leftTrials = cellfun(@(x) any(ismember(x,'Left')), stimSplit, 'UniformOutput',false);
    leftTrialNums = find(cell2mat(leftTrials));

    rightTrialNums = find(cell2mat(rightTrials));

    leftResponse = response(cell2mat(leftTrials));

    rightResponse = response(cell2mat(rightTrials));

    for i = 1: height(rightResponse)
        if rightResponse{i} == 1
            rightColor{i} ='g';
        elseif rightResponse{i} == 2
            rightColor{i} = 'r';
        else 
            rightColor{i} = 'k';
        end
    end

    for i = 1: height(leftResponse)
        if leftResponse{i} == 1
            leftColor{i} ='r';
        elseif leftResponse{i} == 2
            leftColor{i} = 'g';
        else 
            leftColor{i} = 'k';
        end
    end
    
    if height(leftResponse) + height(rightResponse) ~= height(response);
        disp('NOTE: left + right is not = total trials');
    end
    columns = behav.Properties.VariableNames;
    
    % red-incorrect green-correct black-miss
    g = figure(sess);clf;
    hold on;
    leftY = ones(1,height(leftTrialNums))*0.1;
    for kk =1:height(leftTrialNums)
        plot(leftTrialNums(kk), leftY(kk), '.', 'color',leftColor{kk});
    end
    rightY = ones(1,height(rightTrialNums))*0.2;
    for kk =1:height(rightTrialNums)
        plot(rightTrialNums(kk), rightY(kk), '.', 'color',rightColor{kk});
    end
    ylim([0,2])
    yticks([0.1,0.2])
    yticklabels({'Left', 'Right'})
    sgtitle([sePathSplit{5} ' ' sePathSplit{6}]);
    hold off
    saveas(g,[saveFig '\' sePathSplit{5} ' ' sePathSplit{6} ' sessFig.png']);

end

%% Merge b sessions to a! 
clear all
masterPaths = MBrowse.Files([], 'Select master files', {'.mat'});
masterTb = table();

for i = length(masterPaths) : -1 : 1
    disp(masterPaths{i});
    masterObj = matfile(masterPaths{i}, 'Writable',true);
    [~, masterName] = fileparts(masterPaths{i});
    varList = who('-file', masterPaths{i});
    
    masterTb.masterObj{i} = masterObj;
    masterTb.masterName{i} = masterName;
    masterTb.hasBehav(i) = ismember('bct_data', varList);
    masterTb.hasIntan(i) = ismember('intan_data', varList);
    masterTb.hasSpike(i) = ismember('spike_data', varList);    
end

disp(masterTb);

bct_data1 = masterTb.masterObj{1}.bct_data;
bct_data2 = masterTb.masterObj{2}.bct_data;
bct_data1.trialType = [bct_data1.trialType; bct_data2.trialType]; 
bct_data1.trialResponse = [bct_data1.trialResponse; bct_data2.trialResponse]; 
bct_data1.leftStimType = [bct_data1.leftStimType; bct_data2.leftStimType];
bct_data1.rightStimType = [bct_data1.rightStimType; bct_data2.rightStimType];
bct_data1.blockType = [bct_data1.blockType; bct_data2.blockType];
tt = ones(size(bct_data1.blockType,1),1);
bct_data1.trialNums = mat2cell((1:size(bct_data1.blockType,1))', [ones(size(bct_data1.blockType,1),1)'], [1]);
masterTb.masterObj{1}.bct_data = bct_data1;

%remove masterfile
clear all
masterPaths = MBrowse.Files([], 'Select master files', {'.mat'});
delete(masterPaths{1});


%% overall perf graphs 
clear all
animalID = {'VC030103', 'VC030104','VC030105', 'VC030106', 'VC030107', 'VC030108', 'VC030109'...
    'VC030110', 'VC030201', 'VC030202', 'VC030203', 'VC030204', 'VC030206','VC030207', 'VC030208', 'VC030209', 'VC030112'};

%find Ses with the animal ID
seFolder = MBrowse.Folder([], 'Select se folder');
seFolderInfo = MUtil.Dir2Table(seFolder);
seFolderInfo(1:2,:) = [];
AnimalIDs = cellfun(@(x) strsplit(x), seFolderInfo.name, 'UniformOutput', false);

seFolderInfo.AnimalID = cellfun(@(x) x{1}, AnimalIDs, 'UniformOutput', false);




stimTypes =  {'SineAmp1p000Freq40Cyc40', 'SineAmp1p000Freq20Cyc40','SineAmp1p000Freq40Cyc3',...
            'SineAmp0p925Freq40Cyc3',...
            'SineAmp0p875Freq40Cyc3','SineAmp0p8375Freq40Cyc3',...
            'SineAmp0p750Freq40Cyc3','SineAmp0p700Freq40Cyc3',...
            'SineAmp0p675Freq40Cyc3','SineAmp0p625Freq40Cyc3',...
            'SineAmp0p550Freq40Cyc3','SineAmp0p500Freq40Cyc3','SineAmp0p375Freq40Cyc3',...
            'SineAmp0p300Freq40Cyc3','SineAmp0p250Freq40Cyc3','SineAmp0p200Freq40Cyc3',...
            'SineAmp0p150Freq40Cyc3','SineAmp0p100Freq40Cyc3','SineAmp0p50Freq40Cyc3',...
            'SineAmp0p25Freq40Cyc3','SineAmp1p000Freq20Cyc3', 'SineAmp0p925Freq20Cyc3',...
            'SineAmp0p875Freq20Cyc3','SineAmp0p8375Freq20Cyc3',...
            'SineAmp0p750Freq20Cyc3','SineAmp0p700Freq20Cyc3',...
            'SineAmp0p675Freq20Cyc3','SineAmp0p625Freq20Cyc3',...
            'SineAmp0p550Freq20Cyc3','SineAmp0p500Freq20Cyc3','SineAmp0p375Freq20Cyc3',...
            'SineAmp0p300Freq20Cyc3','SineAmp0p250Freq20Cyc3','SineAmp0p200Freq20Cyc3',...
            'SineAmp0p150Freq20Cyc3','SineAmp0p100Freq20Cyc3','SineAmp0p50Freq20Cyc3',...
            'SineAmp0p25Freq20Cyc3','SineAmp1p000Freq20Cyc1', 'SineAmp0p925Freq20Cyc1',...
            'SineAmp0p875Freq20Cyc1','SineAmp0p8375Freq20Cyc1',...
            'SineAmp0p750Freq20Cyc1','SineAmp0p700Freq20Cyc1',...
            'SineAmp0p675Freq20Cyc1','SineAmp0p625Freq20Cyc1',...
            'SineAmp0p550Freq20Cyc1','SineAmp0p500Freq20Cyc1','SineAmp0p375Freq20Cyc1',...
            'SineAmp0p300Freq20Cyc1','SineAmp0p250Freq20Cyc1','SineAmp0p200Freq20Cyc1',...
            'SineAmp0p150Freq20Cyc1','SineAmp0p100Freq20Cyc1','SineAmp0p50Freq20Cyc1',...
            'SineAmp0p25Freq20Cyc1'};
stimGrades = [1:numel(stimTypes)];
stimTypes2 =  {'SineAmp1p000Freq40Dur1p000', 'SineAmp1p000Freq20Dur1p000','SineAmp1p000Freq40Dur0p150',...
            'SineAmp0p925Freq40Dur0p150',...
            'SineAmp0p875Freq40Dur0p150','SineAmp0p8375Freq40Dur0p150',...
            'SineAmp0p750Freq40Dur0p150','SineAmp0p700Freq40Dur0p150',...
            'SineAmp0p675Freq40Dur0p150','SineAmp0p625Freq40Dur0p150',...
            'SineAmp0p550Freq40Dur0p150','SineAmp0p500Freq40Dur0p150','SineAmp0p375Freq40Dur0p150',...
            'SineAmp0p300Freq40Dur0p150','SineAmp0p250Freq40Dur0p150','SineAmp0p200Freq40Dur0p150',...
            'SineAmp0p150Freq40Dur0p150','SineAmp0p100Freq40Dur0p100','SineAmp0p50Freq40Dur0p150',...
            'SineAmp0p25Freq40Dur0p150','SineAmp1p000Freq20Dur0p150', 'SineAmp0p925Freq20Dur0p150',...
            'SineAmp0p875Freq20Dur0p150','SineAmp0p8375Freq20Dur0p150',...
            'SineAmp0p750Freq20Dur0p150','SineAmp0p700Freq20Dur0p150',...
            'SineAmp0p675Freq20Dur0p150','SineAmp0p625Freq20Dur0p150',...
            'SineAmp0p550Freq20Dur0p150','SineAmp0p500Freq20Dur0p150','SineAmp0p375Freq20Dur0p150',...
            'SineAmp0p300Freq20Dur0p150','SineAmp0p250Freq20Dur0p150','SineAmp0p200Freq20Dur0p150',...
            'SineAmp0p150Freq20Dur0p150','SineAmp0p100Freq20Dur0p150','SineAmp0p50Freq20Dur0p150',...
            'SineAmp0p25Freq20Dur0p150'};
stimGrades2 = [1:numel(stimTypes2)];



for animalnos = 1:size(animalID,2)
    animal = animalID{animalnos};     
    sessNum=1;

    for i = find(ismember(seFolderInfo.AnimalID, animal))'
        load(fullfile(seFolderInfo.folder{i}, seFolderInfo.name{i}));
        behavData = se.GetTable('behavValue');
        stimRight = behavData.rightStimType{end};
        stimLeft = behavData.leftStimType{end};
        if any(ismember(stimTypes, stimRight)) && any(ismember(stimTypes, stimLeft))

            responses = cell2mat(behavData.response);
            % remove abort trials
            abortTrials = find(responses ==3);
            behavData(abortTrials,:) = [];

           
            %separate miss trials
            responses = cell2mat(behavData.response);
            missTrials = find(responses==0);
            
            missData = behavData(missTrials, :);
            behavData(missTrials,:) = [];

             %remove catch trials
            result = behavData.result;
            catchTrials = find(isnan(result));
            behavData(catchTrials,:) = [];
            responses = cell2mat(behavData.response);

            result = behavData.result;
            correctTrials = find(result);
            try
                incorrectTrials = find(~result);
            catch
                keyboard;
            end
            missTrials = find(~cell2mat(missData.response));
            correctFrac{animalnos}(sessNum) = height(correctTrials)/(height(correctTrials)+height(incorrectTrials));
            incorrectFrac{animalnos}(sessNum) = height(incorrectTrials)/(height(correctTrials)+height(incorrectTrials));

          
            missFrac{animalnos}(sessNum) = height(missTrials)/(height(missTrials)+height(correctTrials)+height(incorrectTrials));
            
            rightGrade{animalnos}(sessNum) = find(ismember(stimTypes, stimRight));
        
            leftGrade{animalnos}(sessNum) = find(ismember(stimTypes, stimLeft));
            sessNum = sessNum +1;
        elseif any(ismember(stimTypes2, stimRight)) && any(ismember(stimTypes2, stimLeft))
             responses = cell2mat(behavData.response);
            % remove abort trials
            abortTrials = find(responses ==3);
            behavData(abortTrials,:) = [];
           
            %separate miss trials
            responses = cell2mat(behavData.response);
            missTrials = find(responses==0);
            
            missData = behavData(missTrials, :);
            behavData(missTrials,:) = [];

            %remove catch trials
            result = behavData.result;
            catchTrials = find(isnan(result));
            behavData(catchTrials,:) = [];
            responses = cell2mat(behavData.response);
                        
            
            result = behavData.result;
            correctTrials = find(result);
            try
                incorrectTrials = find(~result);
            catch
                keyboard;
            end
    
            missTrials = find(~cell2mat(missData.response));
            correctFrac{animalnos}(sessNum) = height(correctTrials)/(height(correctTrials)+height(incorrectTrials));
            incorrectFrac{animalnos}(sessNum) = height(incorrectTrials)/(height(correctTrials)+height(incorrectTrials));

          
            missFrac{animalnos}(sessNum) = height(missTrials)/( height(missTrials)+height(correctTrials)+height(incorrectTrials));
            
            rightGrade{animalnos}(sessNum) = find(ismember(stimTypes2, stimRight));
        
            leftGrade{animalnos}(sessNum) = find(ismember(stimTypes2, stimLeft));
            sessNum = sessNum +1;
        else
            continue
            
        end
    end
    
      
end

pathParts = strsplit(seFolder, '\');
figureFolder = fullfile(pathParts{1:end-1}, 'Figures');
if ~exist(figureFolder, 'dir')
    mkdir(figureFolder);
end

close all
for i = 1:size(animalID,2)
    g=figure(i);clf
    hold on
%     yyaxis left
    plot(0:size(correctFrac{i},2)-1,0.7*ones(1,size(correctFrac{i},2)), '-.', 'LineWidth', 2)
    plot(correctFrac{i}, '-', 'color', [0 1 0], 'LineWidth', 4);      
    plot(missFrac{i}, '-', 'color', [0 0 0], 'lineWidth', 1)
    ylim([0,1]);
    ylabel('Fraction of trials')

%     yyaxis right
%     plot(rightGrade{i}/numel(stimTypes), '-', 'color', [0 0 1], 'lineWidth', 2);
%     plot(leftGrade{i}/numel(stimTypes), '-', 'color', [0.5 0 1], 'lineWidth', 2)    
    sgtitle(animalID{i})
%     ylim([0,1]);
    xlim([0,size(correctFrac{i},2)])
    xlabel('Session numbers')
%     ylabel('Stim difficulty')
%     ax = gca;
%     ax.YAxis(1).Color = 'k';
%     ax.YAxis(2).Color = 'b';

    hold off
    saveas(g,[figureFolder '\' animalID{i} '_perf.png']);
end


for i = 1:size(animalID,2)
    g=figure(i+size(animalID,2));clf
    hold on
    yyaxis left
    plot(0:size(correctFrac{i},2)-1,0.7*ones(1,size(correctFrac{i},2)), '-.', 'LineWidth', 2)
    plot(correctFrac{i}, '-', 'color', [0 1 0], 'LineWidth', 4);      
%     plot(missFrac{i}, '-', 'color', [0 0 0], 'lineWidth', 1)
    ylim([0,1]);
    ylabel('Fraction of trials')

    yyaxis right
    plot(rightGrade{i}/numel(stimTypes), '-', 'color', [0 0 1], 'lineWidth', 2);
    plot(leftGrade{i}/numel(stimTypes), '-', 'color', [1 0 0], 'lineWidth', 2)    
    sgtitle(animalID{i})
    ylim([0,1]);
    xlim([0,size(correctFrac{i},2)])
    xlabel('Session numbers')
    ylabel('Stim difficulty')
    ax = gca;
    ax.YAxis(1).Color = 'k';
    ax.YAxis(2).Color = [0.91 0.41 0.17];

    hold off
    saveas(g,[figureFolder '\' animalID{i} '_stim.png']);
end


%%
%% overall perf graphs for all animals
clear all
WTAnis = { 'VC030109', 'VC030110', 'VC030112'}
KOAnis = {'VC030207','VC030208', 'VC030209'};
genotypes = {'WT', 'KO'};
animalID = [WTAnis, KOAnis];


% Specify different stim nomenclatures
stimTypes =  {'SineAmp1p000Freq40Cyc40', 'SineAmp1p000Freq20Cyc40','SineAmp1p000Freq40Cyc3',...
            'SineAmp0p925Freq40Cyc3',...
            'SineAmp0p875Freq40Cyc3','SineAmp0p8375Freq40Cyc3',...
            'SineAmp0p750Freq40Cyc3','SineAmp0p700Freq40Cyc3',...
            'SineAmp0p675Freq40Cyc3','SineAmp0p625Freq40Cyc3',...
            'SineAmp0p550Freq40Cyc3','SineAmp0p500Freq40Cyc3','SineAmp0p375Freq40Cyc3',...
            'SineAmp0p300Freq40Cyc3','SineAmp0p250Freq40Cyc3','SineAmp0p200Freq40Cyc3',...
            'SineAmp0p150Freq40Cyc3','SineAmp0p100Freq40Cyc3','SineAmp0p50Freq40Cyc3',...
            'SineAmp0p25Freq40Cyc3','SineAmp1p000Freq20Cyc3', 'SineAmp0p925Freq20Cyc3',...
            'SineAmp0p875Freq20Cyc3','SineAmp0p8375Freq20Cyc3',...
            'SineAmp0p750Freq20Cyc3','SineAmp0p700Freq20Cyc3',...
            'SineAmp0p675Freq20Cyc3','SineAmp0p625Freq20Cyc3',...
            'SineAmp0p550Freq20Cyc3','SineAmp0p500Freq20Cyc3','SineAmp0p375Freq20Cyc3',...
            'SineAmp0p300Freq20Cyc3','SineAmp0p250Freq20Cyc3','SineAmp0p200Freq20Cyc3',...
            'SineAmp0p150Freq20Cyc3','SineAmp0p100Freq20Cyc3','SineAmp0p50Freq20Cyc3',...
            'SineAmp0p25Freq20Cyc3','SineAmp1p000Freq20Cyc1', 'SineAmp0p925Freq20Cyc1',...
            'SineAmp0p875Freq20Cyc1','SineAmp0p8375Freq20Cyc1',...
            'SineAmp0p750Freq20Cyc1','SineAmp0p700Freq20Cyc1',...
            'SineAmp0p675Freq20Cyc1','SineAmp0p625Freq20Cyc1',...
            'SineAmp0p550Freq20Cyc1','SineAmp0p500Freq20Cyc1','SineAmp0p375Freq20Cyc1',...
            'SineAmp0p300Freq20Cyc1','SineAmp0p250Freq20Cyc1','SineAmp0p200Freq20Cyc1',...
            'SineAmp0p150Freq20Cyc1','SineAmp0p100Freq20Cyc1','SineAmp0p050Freq20Cyc1',...
            'SineAmp0p025Freq20Cyc1'};
stimGrades = [1:numel(stimTypes)];
stimTypes2 =  {'SineAmp1p000Freq40Dur1p000', 'SineAmp1p000Freq20Dur1p000',...
            'SineAmp0p800Freq20Dur1p000', 'SineAmp0p700Freq20Dur1p000','SineAmp1p000Freq40Dur0p150',...
            'SineAmp0p925Freq40Dur0p150',...
            'SineAmp0p875Freq40Dur0p150','SineAmp0p8375Freq40Dur0p150','SineAmp0p800Freq40Dur0p150',...
            'SineAmp0p750Freq40Dur0p150','SineAmp0p700Freq40Dur0p150',...
            'SineAmp0p675Freq40Dur0p150','SineAmp0p625Freq40Dur0p150',...
            'SineAmp0p550Freq40Dur0p150','SineAmp0p500Freq40Dur0p150','SineAmp0p375Freq40Dur0p150',...
            'SineAmp0p300Freq40Dur0p150','SineAmp0p250Freq40Dur0p150','SineAmp0p200Freq40Dur0p150',...
            'SineAmp0p150Freq40Dur0p150','SineAmp0p100Freq40Dur0p150','SineAmp0p050Freq40Dur0p150',...
            'SineAmp0p025Freq40Dur0p150','SineAmp1p000Freq20Dur0p150', 'SineAmp0p925Freq20Dur0p150',...
            'SineAmp0p875Freq20Dur0p150','SineAmp0p8375Freq20Dur0p150','SineAmp0p800Freq20Dur0p150',...
            'SineAmp0p750Freq20Dur0p150','SineAmp0p700Freq20Dur0p150',...
            'SineAmp0p675Freq20Dur0p150','SineAmp0p625Freq20Dur0p150',...
            'SineAmp0p550Freq20Dur0p150','SineAmp0p500Freq20Dur0p150','SineAmp0p375Freq20Dur0p150',...
            'SineAmp0p300Freq20Dur0p150','SineAmp0p250Freq20Dur0p150','SineAmp0p200Freq20Dur0p150',...
            'SineAmp0p150Freq20Dur0p150','SineAmp0p100Freq20Dur0p150','SineAmp0p050Freq20Dur0p150',...
            'SineAmp0p025Freq20Dur0p150', 'SineAmp1p000Freq40Dur0p050', 'SineAmp0p925Freq40Dur0p050',...
            'SineAmp0p875Freq40Dur0p050','SineAmp0p8375Freq40Dur0p050','SineAmp0p800Freq40Dur0p050',...
            'SineAmp0p750Freq40Dur0p050','SineAmp0p700Freq40Dur0p050',...
            'SineAmp0p675Freq40Dur0p050','SineAmp0p625Freq40Dur0p050',...
            'SineAmp0p550Freq40Dur0p050','SineAmp0p500Freq40Dur0p050','SineAmp0p375Freq40Dur0p050',...
            'SineAmp0p300Freq40Dur0p050','SineAmp0p250Freq40Dur0p050','SineAmp0p200Freq40Dur0p050',...
            'SineAmp0p150Freq40Dur0p050','SineAmp0p100Freq40Dur0p050','SineAmp0p50Freq40Dur0p050',...
            'SineAmp0p25Freq40Dur0p050','SineAmp1p000Freq20Dur0p050', 'SineAmp0p925Freq20Dur0p050',...
            'SineAmp0p875Freq20Dur0p050','SineAmp0p8375Freq20Dur0p050','SineAmp0p800Freq20Dur0p050',...
            'SineAmp0p750Freq20Dur0p050','SineAmp0p700Freq20Dur0p050',...
            'SineAmp0p675Freq20Dur0p050','SineAmp0p625Freq20Dur0p050',...
            'SineAmp0p550Freq20Dur0p050','SineAmp0p500Freq20Dur0p050','SineAmp0p375Freq20Dur0p050',...
            'SineAmp0p300Freq20Dur0p050','SineAmp0p250Freq20Dur0p050','SineAmp0p200Freq20Dur0p050',...
            'SineAmp0p150Freq20Dur0p050','SineAmp0p100Freq20Dur0p050','SineAmp0p50Freq20Dur0p050',...
            'SineAmp0p25Freq20Dur0p050'};
stimGrades2 = [1:numel(stimTypes2)];




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
        case 'FinalBehavSEs'            
            behavDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            seNames = cellfun(@(x) endsWith(x,'se.mat'),behavDirInfo.name);            
            behavDirInfo(~seNames,:) = [];
            animalNames = cellfun(@(x) strsplit(x, ' '), behavDirInfo.name, 'UniformOutput', false);
            animalNames = cellfun(@(x) x{1}, animalNames, 'UniformOutput',false);
            behavDirInfo(~ismember(animalNames, animalID),:) = [];

    end
end





%% Find all data files for each session
dataFileTb = table();
% for i =3
temp = {};
for i = 1:height(behavDirInfo)
% for i =3
    % Parse the file name of SatellitesViewer log to get session identifiers
    behavNameParts = strsplit(behavDirInfo.name{i}, {' ', '.'});
    animalId = behavNameParts(1);
%     if ~ismember(animalId, animalID)
%         continue
%     end
    
    sessionDatetime = datetime(behavNameParts{2}(1:end), ...
        'Format', 'yyyy-MM-dd');
    subId = behavNameParts{3};

    rowItem = table();
    rowItem.animalID = animalId;
    rowItem.sessionDatetime = sessionDatetime;
    rowItem.subId = subId;
%     dataFileTb.animalId{i} = animalId;
%     dataFileTb.sessionDatetime(i) = sessionDatetime;
%     dataFileTb.subId{i} = subId;
    
    % Add bControl log file path
    rowItem.sePath = fullfile(behavDirInfo.folder{i}, behavDirInfo.name{i});
%     dataFileTb.sePath{i} = fullfile(behavDirInfo.folder{i}, behavDirInfo.name{i});
    
    % Calculate performance for each se
    se{i} =load(rowItem.sePath);    

  



    [rowItem.correctFrac, rowItem.incorrectFrac, rowItem.missFrac,...
        rowItem.leftStim, rowItem.rightStim, rowItem.sideAssist, rowItem.leftStimProb, rowItem.isSessInfo] = BS.getPerfOverall(se{i}.se);
    if any(ismember(stimTypes, rowItem.rightStim)) && any(ismember(stimTypes, rowItem.leftStim))
        rowItem.leftGrade = find(ismember(stimTypes, rowItem.leftStim))/numel(stimGrades);
        rowItem.rightGrade = find(ismember(stimTypes, rowItem.rightStim))/numel(stimGrades);
    elseif any(ismember(stimTypes2, rowItem.rightStim)) && any(ismember(stimTypes2, rowItem.leftStim))
        rowItem.leftGrade = find(ismember(stimTypes2, rowItem.leftStim))/numel(stimGrades2);
        rowItem.rightGrade = find(ismember(stimTypes2, rowItem.rightStim))/numel(stimGrades2);
    else
         rowItem.leftGrade = 0;
         rowItem.rightGrade = 0;
    end
    dataFileTb(i,:) = rowItem;
    temp{i} = rowItem.Properties.VariableNames;
end

    dataFileTb.Properties.VariableNames =  temp{1};

remRows = dataFileTb.sideAssist | ~(dataFileTb.leftStimProb == 0.5);
dataFileTb(remRows, :) = [];

      
%% make a vector of performance across sessions across training on cols and animalID on rows
% Find the max number of sessions for each animal.

WTAnis = { 'VC030109', 'VC030110', 'VC030112'}
KOAnis = {'VC030207','VC030208', 'VC030209'};

savePath = fullfile(rootDir, 'VC0301', 'Figures', 'FinalBehav');
if ~exist('savePath', 'dir')
    mkdir(savePath)
end

sessNum = [];
for i =1: numel(WTAnis)
    sessNum(1,i) = sum(ismember(dataFileTb.animalID, WTAnis(i)));
end


[maxSessWT idx] = max(sessNum(1,:))



for i =1: numel(KOAnis)
    sessNum(2,i) = sum(ismember(dataFileTb.animalID, KOAnis(i)));
end
[maxSessKO idx] = max(sessNum(2,:));

WTcorrectFrac =[];
WTmissFrac = [];
KOcorrectFrac =[];
KOmissFrac =[];
for WTi = 1: numel(WTAnis)
    aniID = WTAnis{WTi};
    animalTable = dataFileTb(ismember(dataFileTb.animalID, aniID),:);
    animalTable = sortrows(animalTable, 'sessionDatetime');
    WTcorrectFrac(WTi,1:numel(animalTable.correctFrac)) = animalTable.correctFrac';
    WTmissFrac(WTi,1:numel(animalTable.missFrac)) = animalTable.missFrac';
    if numel(animalTable.correctFrac) < maxSessWT
        WTcorrectFrac(WTi, numel(animalTable.correctFrac)+1:maxSessWT) = nan;
        WTmissFrac(WTi,numel(animalTable.correctFrac)+1:maxSessWT) = nan;
    end
    
end
    
for KOi = 1: numel(KOAnis)
    aniID = KOAnis{KOi};
    animalTable = dataFileTb(ismember(dataFileTb.animalID, aniID),:);
    animalTable = sortrows(animalTable, 'sessionDatetime');
    KOcorrectFrac(KOi,1:numel(animalTable.correctFrac)) = animalTable.correctFrac';
    KOmissFrac(KOi,1:numel(animalTable.missFrac)) = animalTable.missFrac';
    if numel(animalTable.correctFrac) < maxSessKO
        KOcorrectFrac(KOi, numel(animalTable.correctFrac)+1:maxSessKO) = nan;
        KOmissFrac(KOi,numel(animalTable.correctFrac)+1:maxSessKO) = nan;
    end
    
end    



[WTmeanCorrect, WTsdCorrect, WTseCorrect, WTciCorrect] = MMath.MeanStats(WTcorrectFrac,1);
[KOmeanCorrect, KOsdCorrect, KOseCorrect, KOciCorrect] = MMath.MeanStats(KOcorrectFrac,1); 

[WTmeanMiss, WTsdMiss, WTseMiss, WTciMiss] = MMath.MeanStats(WTmissFrac,1);
[KOmeanMiss, KOsdMiss, KOseMiss, KOciMiss] = MMath.MeanStats(KOmissFrac,1); 


plotSess = floor(median(sessNum, 'all'));
clear f
g = figure(1);clf
g.WindowState = 'Maximized';  
hold on
f(1) = errorbar(1:numel(WTmeanCorrect), WTmeanCorrect,WTseCorrect,  'color','k');
f(2) = errorbar(1:numel(KOmeanCorrect), KOmeanCorrect,KOseCorrect,  'color','r');
xLimits =  get(gca,'xlim');
MPlot.PlotPointAsLine(xLimits(2)/2, 0.7, xLimits(2), 'linestyle', '--', 'color', [0.5 0.5 0.5], 'Orientation', 'horizontal')
ylim([0 1]);
% xlim([1 plotSess]);
legend(f, {'WT', 'KO'}, 'location', 'east');
xlabel('sessions -->');
ylabel('Performance  (mean +/- std err)');
set(gca, 'Fontsize', 18)
title('Fraction of trials with correct response', 'fontsize', 24)
hold off
savefig(g, fullfile(savePath, 'PerfAcrossSessionCorrect.fig'));
exportgraphics(g, fullfile(savePath, 'PerfAcrossSessionCorrect.png'));

g = figure(2);clf
g.WindowState = 'Maximized';  
hold on
f(1) = errorbar(1:numel(WTmeanMiss), WTmeanMiss,WTseMiss,  'color','k', 'linestyle', '--');
f(2) = errorbar(1:numel(KOmeanMiss), KOmeanMiss,KOseMiss,  'color','r', 'linestyle', '--');
ylim([0 1]);
% xlim([1 plotSess]);
legend(f, {'WT', 'KO'}, 'location', 'east');
xlabel('sessions -->');
ylabel('Performance  (mean +/- std err)');
set(gca, 'Fontsize', 18)
title('Fraction of trials missed', 'fontsize', 24)
hold off
savefig(g, fullfile(savePath, 'PerfAcrossSessionMiss.fig'));
exportgraphics(g, fullfile(savePath, 'PerfAcrossSessionMiss.png'));

g = figure(3);clf
g.WindowState = 'Maximized';  
hold on
f(1) = errorbar(1:numel(WTmeanCorrect), WTmeanCorrect,WTseCorrect,  'color','k');
f(2) = errorbar(1:numel(KOmeanCorrect), KOmeanCorrect,KOseCorrect,  'color','r');
xLimits =  get(gca,'xlim');
MPlot.PlotPointAsLine(xLimits(2)/2, 0.7, xLimits(2), 'linestyle', '--', 'color', [0.5 0.5 0.5], 'Orientation', 'horizontal')
ylim([0 1]);
xlim([1 plotSess]);
legend(f, {'WT', 'KO'}, 'location', 'east');
xlabel('sessions -->');
ylabel('Performance  (mean +/- std err)');
set(gca, 'Fontsize', 18)
title('Fraction of trials with correct response', 'fontsize', 24)
hold off
savefig(g, fullfile(savePath, 'PerfAcrossSessionCorrectMedianSess.fig'));
exportgraphics(g, fullfile(savePath, 'PerfAcrossSessionCorrectMedianSess.png'));

g = figure(4);clf
g.WindowState = 'Maximized';  
hold on
f(1) = errorbar(1:numel(WTmeanMiss), WTmeanMiss,WTseMiss,  'color','k', 'linestyle', '--');
f(2) = errorbar(1:numel(KOmeanMiss), KOmeanMiss,KOseMiss,  'color','r', 'linestyle', '--');
ylim([0 1]);
xlim([1 plotSess]);
legend(f, {'WT', 'KO'}, 'location', 'east');
xlabel('sessions -->');
ylabel('Performance  (mean +/- std err)');
set(gca, 'Fontsize', 18)
title('Fraction of trials missed', 'fontsize', 24)
hold off
savefig(g, fullfile(savePath, 'PerfAcrossSessionMissMedianSess.fig'));
exportgraphics(g, fullfile(savePath, 'PerfAcrossSessionMissMedianSess.png'));

%% Plot these as WT vs KO? 
%% Plot last 5 sessions of each animal with all stim types

for lastNSess = [10]
    WTcorrectFrac ={};
    WTmissFrac = {};
    WTAmp = {};
    KOcorrectFrac ={};
    KOmissFrac ={};
    KOAmp = {};
    
    
    for WTi = 1: numel(WTAnis)
        aniID = WTAnis{WTi};
        animalTable = dataFileTb(ismember(dataFileTb.animalID, aniID),:);
        animalTable = sortrows(animalTable, 'sessionDatetime');
        WTcorrectFrac{WTi} = animalTable.correctFrac';
        WTAmp{WTi} = min(animalTable.leftGrade', animalTable.rightGrade');
        
        WTmissFrac{WTi} = animalTable.missFrac';
    %     if numel(animalTable.correctFrac) < maxSessWT
    %         WTcorrectFrac(WTi, numel(animalTable.correctFrac)+1:maxSessWT) = nan;
    %         WTmissFrac(WTi,numel(animalTable.correctFrac)+1:maxSessWT) = nan;
    %         WTAmp(WTi, numel(animalTable.correctFrac)+1:maxSessWT) = nan;
    %     end
        
    end
        
    for KOi = 1: numel(KOAnis)
        aniID = KOAnis{KOi};
        animalTable = dataFileTb(ismember(dataFileTb.animalID, aniID),:);
        animalTable = sortrows(animalTable, 'sessionDatetime');
        KOcorrectFrac{KOi} = animalTable.correctFrac';
        KOAmp{KOi} = min(animalTable.leftGrade', animalTable.rightGrade');
        KOmissFrac{KOi} = animalTable.missFrac';
    %     if numel(animalTable.correctFrac) < maxSessKO
    %         KOcorrectFrac(KOi, numel(animalTable.correctFrac)+1:maxSessKO) = nan;
    %         KOmissFrac(KOi,numel(animalTable.correctFrac)+1:maxSessKO) = nan;
    %         KOAmp(KOi, numel(animalTable.correctFrac)+1:maxSessKO) = nan;
    %     end
        
    end    
    
    
    WTPerfs = cell2mat(cellfun(@(x) x(end-lastNSess:end),WTcorrectFrac, 'UniformOutput', false));
    KOPerfs = cell2mat(cellfun(@(x) x(end-lastNSess:end),KOcorrectFrac, 'UniformOutput', false));
    WTPerfsAmp = cell2mat(cellfun(@(x) x(end-lastNSess:end),WTAmp, 'UniformOutput', false));
    KOPerfsAmp = cell2mat(cellfun(@(x) x(end-lastNSess:end),KOAmp, 'UniformOutput', false));
    
    
    
    
    [WTmean, WTsd, WTse, WTci] = MMath.MeanStats(WTPerfs,2, 'Alpha', 0.05);
    [KOmean, KOsd, KOse, KOci] = MMath.MeanStats(KOPerfs,2, 'Alpha', 0.05); 
    
    [WTmeanAmps, WTsdAmps, WTseAmps, WTciAmps] = MMath.MeanStats(WTPerfs,2, 'Alpha', 0.05);
    [KOmeanAmps, KOsdAmps, KOseAmps, KOciAmps] = MMath.MeanStats(KOPerfsAmp,2, 'Alpha', 0.05); 
    
    [H, pval] = ttest2(KOPerfs, WTPerfs, 'tail', 'both', 'Alpha', 0.05);
    
    
    g = figure(5); clf;
    g.WindowState = 'Maximized';
    hold on 
    rng(11)  % For reproducibility
    x1 = normrnd(WTmean,sqrt(var(WTPerfs)),[50,1]);
    nr = normplot(x1);
    nr(1).Color = 'blue';
    nr(2).Color = 'blue'
    nr(3).Color = 'blue'
    wt = normplot(WTPerfs);
    wt(1).Color = 'black';
    wt(2).Color = 'black'
    wt(3).Color = 'black'
    hold off
    savefig(g, fullfile(savePath, 'NormalityCheckWTs.fig'));
    exportgraphics(g, fullfile(savePath, 'NormalityCheckWTs.png'));
    
    
    
    g = figure(6); clf;
    g.WindowState = 'Maximized';
    hold on 
    rng(11)  % For reproducibility
    x1 = normrnd(KOmean,sqrt(var(KOPerfs)),[50,1]);
    nr = normplot(x1);
    nr(1).Color = 'blue';
    nr(2).Color = 'blue'
    nr(3).Color = 'blue'
    ko = normplot(KOPerfs);
    ko(1).Color = 'red';
    ko(2).Color = 'red'
    ko(3).Color = 'red'
    hold off
    savefig(g, fullfile(savePath, 'NormalityCheckKOs.fig'));
    exportgraphics(g, fullfile(savePath, 'NormalityCheckKOs.png'));
    
    g = figure(7); clf;
    g.WindowState = 'Maximized';
    hold on
    swarmchart(ones(numel(WTPerfs),1), WTPerfs,  'o','markerfacecolor', 'none' , 'MarkerEdgeColor', [0.5 0.5 0.5])
    swarmchart(2*ones(numel(KOPerfs),1), KOPerfs, 'o','markerfacecolor', 'none' , 'MarkerEdgeColor', 'r')
    % plot(1.1, mean(WTPerfs), '.', 'color', 'k', 'MarkerSize',30 )
    % plot(2.1, mean(KOPerfs), '.', 'color', 'r', 'MarkerSize',30 )
    errorbar(1.1, WTmean, WTsd,  '.', 'color', 'k', 'MarkerSize',30 );
    errorbar(2.1, KOmean, KOsd, '.', 'color', 'r', 'MarkerSize',30 );
    ylim([0.2,1.1]);
    ylabel('Performance (mean +/- std dev)')
    
    xlim([0,3])
    xticks([1,2])
    xticklabels({'WT', 'KO'})
    dim = [.5 .6 .3 .3];
    annotation('textbox',dim, 'String',['p-value = ' num2str(pval)], 'FitBoxToText','on')
    ax = gca;
    
    set(gca, 'FontSize', 18)
    title('Fraction of trials with correct response', 'FontSize', 24)
    hold off
    savefig(g, fullfile(savePath, ['Last ' num2str(lastNSess) ' sessiondaysEachanimalPerfComparisonOnly.fig']));
    exportgraphics(g, fullfile(savePath, ['Last ' num2str(lastNSess) ' sessiondaysEachanimalPerfComparison.png']));
    
    

end




%% take all the sessions with Freq20 and Cyc3 or dur0p150.
% Then make the same plot as above

% Specify different stim nomenclatures
stimTypes =  {'SineAmp1p000Freq20Cyc3', 'SineAmp0p925Freq20Cyc3',...
            'SineAmp0p875Freq20Cyc3','SineAmp0p8375Freq20Cyc3','SineAmp0p800Freq20Dur0p150',...
            'SineAmp0p750Freq20Cyc3','SineAmp0p700Freq20Cyc3',...
            'SineAmp0p675Freq20Cyc3','SineAmp0p625Freq20Cyc3',...
            'SineAmp0p550Freq20Cyc3','SineAmp0p500Freq20Cyc3','SineAmp0p375Freq20Cyc3',...
            'SineAmp0p300Freq20Cyc3','SineAmp0p250Freq20Cyc3','SineAmp0p200Freq20Cyc3',...
            'SineAmp0p150Freq20Cyc3','SineAmp0p100Freq20Cyc3','SineAmp0p050Freq20Cyc3',...
            'SineAmp0p025Freq20Cyc3'};
stimGrades = [1, 0.925,0.875, 0.8375, 0.8, 0.75, 0.7, 0.675, 0.627, 0.550, 0.500, 0.375, 0.3, 0.25,0.2, 0.15,0.1,0.05, 0.025];
stimTypes2 =  {'SineAmp1p000Freq20Dur0p150', 'SineAmp0p925Freq20Dur0p150',...
            'SineAmp0p875Freq20Dur0p150','SineAmp0p8375Freq20Dur0p150','SineAmp0p800Freq20Dur0p150',...
            'SineAmp0p750Freq20Dur0p150','SineAmp0p700Freq20Dur0p150',...
            'SineAmp0p675Freq20Dur0p150','SineAmp0p625Freq20Dur0p150',...
            'SineAmp0p550Freq20Dur0p150','SineAmp0p500Freq20Dur0p150','SineAmp0p375Freq20Dur0p150',...
            'SineAmp0p300Freq20Dur0p150','SineAmp0p250Freq20Dur0p150','SineAmp0p200Freq20Dur0p150',...
            'SineAmp0p150Freq20Dur0p150','SineAmp0p100Freq20Dur0p150','SineAmp0p050Freq20Dur0p150',...
            'SineAmp0p025Freq20Dur0p150'};
stimGrades2 = [1, 0.925,0.875, 0.8375, 0.8, 0.75, 0.7, 0.675, 0.627, 0.550, 0.500, 0.375, 0.3, 0.25,0.2, 0.15,0.1,0.05, 0.025];


%%
%% take all the sessions with Freq40 and Cyc3 or dur0p150.
% Then make the same plot as above

% Specify different stim nomenclatures
stimTypes =  {'SineAmp1p000Freq40Cyc3', 'SineAmp0p925Freq40Cyc3',...
            'SineAmp0p875Freq40Cyc3','SineAmp0p8375Freq40Cyc3','SineAmp0p800Freq40Cyc3',...
            'SineAmp0p750Freq40Cyc3','SineAmp0p700Freq40Cyc3',...
            'SineAmp0p675Freq40Cyc3','SineAmp0p625Freq40Cyc3',...
            'SineAmp0p550Freq40Cyc3','SineAmp0p500Freq40Cyc3','SineAmp0p375Freq40Cyc3',...
            'SineAmp0p300Freq40Cyc3','SineAmp0p250Freq40Cyc3','SineAmp0p200Freq40Cyc3',...
            'SineAmp0p150Freq40Cyc3','SineAmp0p100Freq40Cyc3','SineAmp0p050Freq40Cyc3',...
            'SineAmp0p025Freq40Cyc3'};
stimGrades = [1, 0.925,0.875, 0.8375, 0.8, 0.75, 0.7, 0.675, 0.627, 0.550, 0.500, 0.375, 0.3, 0.25,0.2, 0.15,0.1,0.05, 0.025];
stimTypes2 =  {'SineAmp1p000Freq40Dur0p150', 'SineAmp0p925Freq40Dur0p150',...
            'SineAmp0p875Freq40Dur0p150','SineAmp0p8375Freq40Dur0p150','SineAmp0p800Freq20Dur0p150',...
            'SineAmp0p750Freq40Dur0p150','SineAmp0p700Freq40Dur0p150',...
            'SineAmp0p675Freq40Dur0p150','SineAmp0p625Freq40Dur0p150',...
            'SineAmp0p550Freq40Dur0p150','SineAmp0p500Freq40Dur0p150','SineAmp0p375Freq40Dur0p150',...
            'SineAmp0p300Freq40Dur0p150','SineAmp0p250Freq40Dur0p150','SineAmp0p200Freq40Dur0p150',...
            'SineAmp0p150Freq40Dur0p150','SineAmp0p100Freq40Dur0p150','SineAmp0p050Freq40Dur0p150',...
            'SineAmp0p025Freq40Dur0p150'};
stimGrades2 = [1, 0.925,0.875, 0.8375, 0.8, 0.75, 0.7, 0.675, 0.627, 0.550, 0.500, 0.375, 0.3, 0.25,0.2, 0.15,0.1,0.05, 0.025];

%% Find all data files for each session
specdataFileTb = table();
% for i =3
temp = {};
parfor i = 1:height(behavDirInfo)
    % Parse the file name of SatellitesViewer log to get session identifiers
    behavNameParts = strsplit(behavDirInfo.name{i}, {' ', '.'});
    animalId = behavNameParts(1);
    if ~ismember(animalId, animalID)
        continue
    end
    
    sessionDatetime = datetime(behavNameParts{2}(1:end), ...
        'Format', 'yyyy-MM-dd');
    subId = behavNameParts{3};

    rowItem = table();
    rowItem.animalID = animalId;
    rowItem.sessionDatetime = sessionDatetime;
    rowItem.subId = subId;
%     dataFileTb.animalId{i} = animalId;
%     dataFileTb.sessionDatetime(i) = sessionDatetime;
%     dataFileTb.subId{i} = subId;
    
    % Add bControl log file path
    rowItem.sePath = fullfile(behavDirInfo.folder{i}, behavDirInfo.name{i});
%     dataFileTb.sePath{i} = fullfile(behavDirInfo.folder{i}, behavDirInfo.name{i});
    
    % Calculate performance for each se
    se{i} =load(rowItem.sePath);    

  



    [rowItem.correctFrac, rowItem.incorrectFrac, rowItem.missFrac,...
        rowItem.leftStim, rowItem.rightStim, rowItem.sideAssist, rowItem.leftStimProb, rowItem.isSessInfo] = BS.getPerfOverall(se{i}.se);
    if any(ismember(stimTypes, rowItem.rightStim)) && any(ismember(stimTypes, rowItem.leftStim))
        rowItem.leftGrade = stimGrades(ismember(stimTypes, rowItem.leftStim));
        rowItem.rightGrade = stimGrades(ismember(stimTypes, rowItem.rightStim));
    elseif any(ismember(stimTypes2, rowItem.rightStim)) && any(ismember(stimTypes2, rowItem.leftStim))
        rowItem.leftGrade = stimGrades2(ismember(stimTypes2, rowItem.leftStim));
        rowItem.rightGrade = stimGrades2(ismember(stimTypes2, rowItem.rightStim));
    else
         rowItem.leftGrade = 0;
         rowItem.rightGrade = 0;
    end
    specdataFileTb(i,:) = rowItem; 
    temp{i} = rowItem.Properties.VariableNames;
end

    specdataFileTb.Properties.VariableNames =  temp{1};
    remRows = specdataFileTb.leftGrade ==0 |  specdataFileTb.rightGrade ==0 | specdataFileTb.sideAssist | ~(specdataFileTb.leftStimProb == 0.5);
    specdataFileTb(remRows,:) = [];
%% make a vector of performance across sessions across training on cols and animalID on rows
% Find the max number of sessions for each animal.

WTAnis = {'VC030109', 'VC030110', 'VC030112'};
KOAnis = { 'VC030207', 'VC030208', 'VC030209'};

savePath = fullfile(rootDir, 'VC0301', 'Figures', 'FinalBehav');
if ~exist('savePath', 'dir')
    mkdir(savePath)
end

sessNum = [];
for i =1: numel(WTAnis)
    sessNum(1,i) = sum(ismember(specdataFileTb.animalID, WTAnis(i)));
end


[maxSessWT idx] = max(sessNum(1,:))



for i =1: numel(KOAnis)
    sessNum(2,i) = sum(ismember(specdataFileTb.animalID, KOAnis(i)));
end
[maxSessKO idx] = max(sessNum(2,:));

WTcorrectFrac =[];
WTmissFrac = [];
WTAmp = [];
KOcorrectFrac =[];
KOmissFrac =[];
KOAmp = [];


for WTi = 1: numel(WTAnis)
    aniID = WTAnis{WTi};
    animalTable = specdataFileTb(ismember(specdataFileTb.animalID, aniID),:);
    animalTable = sortrows(animalTable, 'sessionDatetime');
    WTcorrectFrac(WTi,1:numel(animalTable.correctFrac)) = animalTable.correctFrac';
    WTAmp(WTi,1:numel(animalTable.leftGrade)) = min(animalTable.leftGrade', animalTable.rightGrade');
    
    WTmissFrac(WTi,1:numel(animalTable.missFrac)) = animalTable.missFrac';
    if numel(animalTable.correctFrac) < maxSessWT
        WTcorrectFrac(WTi, numel(animalTable.correctFrac)+1:maxSessWT) = nan;
        WTmissFrac(WTi,numel(animalTable.correctFrac)+1:maxSessWT) = nan;
        WTAmp(WTi, numel(animalTable.correctFrac)+1:maxSessWT) = nan;
    end
    
end
    
for KOi = 1: numel(KOAnis)
    aniID = KOAnis{KOi};
    animalTable = specdataFileTb(ismember(specdataFileTb.animalID, aniID),:);
    animalTable = sortrows(animalTable, 'sessionDatetime');
    KOcorrectFrac(KOi,1:numel(animalTable.correctFrac)) = animalTable.correctFrac';
    KOAmp(KOi,1:numel(animalTable.leftGrade)) = min(animalTable.leftGrade', animalTable.rightGrade');
    KOmissFrac(KOi,1:numel(animalTable.missFrac)) = animalTable.missFrac';
    if numel(animalTable.correctFrac) < maxSessKO
        KOcorrectFrac(KOi, numel(animalTable.correctFrac)+1:maxSessKO) = nan;
        KOmissFrac(KOi,numel(animalTable.correctFrac)+1:maxSessKO) = nan;
        KOAmp(KOi, numel(animalTable.correctFrac)+1:maxSessKO) = nan;
    end
    
end    

[WTmeanAmp, WTsdAmp, WTseAmp, WTciAmp] = MMath.MeanStats(WTAmp,1);
[KOmeanAmp, KOsdAmp, KOseAmp, KOciAmp] = MMath.MeanStats(KOAmp,1);


[WTmeanCorrect, WTsdCorrect, WTseCorrect, WTciCorrect] = MMath.MeanStats(WTcorrectFrac,1);
[KOmeanCorrect, KOsdCorrect, KOseCorrect, KOciCorrect] = MMath.MeanStats(KOcorrectFrac,1); 

[WTmeanMiss, WTsdMiss, WTseMiss, WTciMiss] = MMath.MeanStats(WTmissFrac,1);
[KOmeanMiss, KOsdMiss, KOseMiss, KOciMiss] = MMath.MeanStats(KOmissFrac,1); 


plotSess = floor(median(sessNum, 'all'));
g = figure(1);clf
g.WindowState = 'Maximized';  
hold on
yyaxis left
f(1) = errorbar(1:numel(WTmeanCorrect), WTmeanCorrect,WTseCorrect,  'color','k', 'linestyle', '-');
f(2) = errorbar(1:numel(KOmeanCorrect), KOmeanCorrect,KOseCorrect,  'color','b', 'linestyle', '-');
xLimits =  get(gca,'xlim');
MPlot.PlotPointAsLine(xLimits(2)/2, 0.7, xLimits(2), 'linestyle', '--', 'color', [0.5 0.5 0.5], 'Orientation', 'horizontal')
ylim([0 1]);
% legend(f, {'WT', 'KO'}, 'location', 'east');
ylabel('Performance  (mean +/- std err)');
set(gca, 'Fontsize', 18)
yyaxis right
f(3) = errorbar(1:numel(WTmeanAmp), WTmeanAmp, WTseAmp,  'color','k', 'linestyle', '--');
f(4) = errorbar(1:numel(KOmeanAmp), KOmeanAmp, KOseAmp,  'color', [0.8500 0.3250 0.0980], 'linestyle', '--');
ylim([0.4 1]);
legend(f, {'WT correct', 'KO correct', 'WT Amp', 'KO Amp'}, 'location', 'southeast');
ylabel('Amplitude of stimulation');
set(gca, 'Fontsize', 18)
xlabel('sessions -->');
% xlim([1 plotSess]);
title('Fraction of trials with correct response', 'fontsize', 24)
hold off
savefig(g, fullfile(savePath, 'PerfAcrossSessionCorrectWith40FreqAmps.fig'));
exportgraphics(g, fullfile(savePath, 'PerfAcrossSessionCorrectWith40FreqAmps.png'));

g = figure(2);clf
g.WindowState = 'Maximized';  
hold on
yyaxis left
f(1) = errorbar(1:numel(WTmeanCorrect), WTmeanCorrect,WTseCorrect,  'color','k', 'linestyle', '-');
f(2) = errorbar(1:numel(KOmeanCorrect), KOmeanCorrect,KOseCorrect,  'color','b', 'linestyle', '-');
xLimits =  get(gca,'xlim');
MPlot.PlotPointAsLine(xLimits(2)/2, 0.7, xLimits(2), 'linestyle', '--', 'color', [0.5 0.5 0.5], 'Orientation', 'horizontal')
ylim([0 1]);
% legend(f, {'WT', 'KO'}, 'location', 'east');
ylabel('Performance  (mean +/- std err)');
set(gca, 'Fontsize', 18)

yyaxis right
% f(3) = errorbar(1:numel(WTmeanAmp), WTmeanAmp, WTseAmp,  'color','k', 'linestyle', '--');
% f(4) = errorbar(1:numel(KOmeanAmp), KOmeanAmp, KOseAmp,  'color', [0.8500 0.3250 0.0980], 'linestyle', '--');
ylim([0.4 1]);

legend(f, {'WT correct', 'KO correct'}, 'location', 'southeast');
ylabel('Amplitude of stimulation');
ax = gca;
ax.YAxis(1).Color = 'b';
ax.YAxis(2).Color = [0.8500 0.3250 0.0980];
set(gca, 'Fontsize', 18)
xlabel('sessions -->');
% xlim([1 plotSess]);
title('Fraction of trials with correct response', 'fontsize', 24)
hold off
savefig(g, fullfile(savePath, 'PerfAcrossSessionCorrectWithout40FreqAmps.fig'));
exportgraphics(g, fullfile(savePath, 'PerfAcrossSessionCorrectWithout40FreqAmps.png'));




g = figure(3);clf
g.WindowState = 'Maximized';  
hold on
yyaxis left
f(1) = errorbar(1:numel(WTmeanCorrect), WTmeanCorrect,WTseCorrect,  'color','k', 'linestyle', '-');
f(2) = errorbar(1:numel(KOmeanCorrect), KOmeanCorrect,KOseCorrect,  'color','b', 'linestyle', '-');
xLimits =  get(gca,'xlim');
MPlot.PlotPointAsLine(xLimits(2)/2, 0.7, xLimits(2), 'linestyle', '--', 'color', [0.5 0.5 0.5], 'Orientation', 'horizontal')
ylim([0 1]);
% legend(f, {'WT', 'KO'}, 'location', 'east');
ylabel('Performance  (mean +/- std err)');
set(gca, 'Fontsize', 18)
yyaxis right
f(3) = errorbar(1:numel(WTmeanAmp), WTmeanAmp, WTseAmp,  'color','k', 'linestyle', '--');
f(4) = errorbar(1:numel(KOmeanAmp), KOmeanAmp, KOseAmp,  'color', [0.8500 0.3250 0.0980], 'linestyle', '--');
ylim([0.4 1]);
legend(f, {'WT correct', 'KO correct', 'WT Amp', 'KO Amp'}, 'location', 'southeast');
ylabel('Amplitude of stimulation');
set(gca, 'Fontsize', 18)
xlabel('sessions -->');
xlim([1 plotSess]);
title('Fraction of trials with correct response', 'fontsize', 24)
hold off
savefig(g, fullfile(savePath, 'PerfAcrossSessionCorrectWith40FreqAmpsmedian.fig'));
exportgraphics(g, fullfile(savePath, 'PerfAcrossSessionCorrectWith40FreqAmpsmedian.png'));

g = figure(4);clf
g.WindowState = 'Maximized';  
hold on
yyaxis left
f(1) = errorbar(1:numel(WTmeanCorrect), WTmeanCorrect,WTseCorrect,  'color','k', 'linestyle', '-');
f(2) = errorbar(1:numel(KOmeanCorrect), KOmeanCorrect,KOseCorrect,  'color','b', 'linestyle', '-');
xLimits =  get(gca,'xlim');
MPlot.PlotPointAsLine(xLimits(2)/2, 0.7, xLimits(2), 'linestyle', '--', 'color', [0.5 0.5 0.5], 'Orientation', 'horizontal')
ylim([0 1]);
% legend(f, {'WT', 'KO'}, 'location', 'east');
ylabel('Performance  (mean +/- std err)');
set(gca, 'Fontsize', 18)

yyaxis right
% f(3) = errorbar(1:numel(WTmeanAmp), WTmeanAmp, WTseAmp,  'color','k', 'linestyle', '--');
% f(4) = errorbar(1:numel(KOmeanAmp), KOmeanAmp, KOseAmp,  'color', [0.8500 0.3250 0.0980], 'linestyle', '--');
ylim([0.4 1]);

legend(f, {'WT correct', 'KO correct'}, 'location', 'southeast');
ylabel('Amplitude of stimulation');
ax = gca;
ax.YAxis(1).Color = 'b';
ax.YAxis(2).Color = [0.8500 0.3250 0.0980];
set(gca, 'Fontsize', 18)
xlabel('sessions -->');
xlim([1 plotSess]);
title('Fraction of trials with correct response', 'fontsize', 24)
hold off
savefig(g, fullfile(savePath, 'PerfAcrossSessionCorrectWithout40FreqAmpsmedian.fig'));
exportgraphics(g, fullfile(savePath, 'PerfAcrossSessionCorrectWithout40FreqAmpsmedian.png'));


%% Plot last 5 sessions of each animal with 20freq
for lastNSess = [10:18]
    WTcorrectFrac ={};
    WTmissFrac = {};
    WTAmp = {};
    KOcorrectFrac ={};
    KOmissFrac ={};
    KOAmp = {};
    
    
    for WTi = 1: numel(WTAnis)
        aniID = WTAnis{WTi};
        animalTable = specdataFileTb(ismember(specdataFileTb.animalID, aniID),:);
        animalTable = sortrows(animalTable, 'sessionDatetime');
        WTcorrectFrac{WTi} = animalTable.correctFrac';
        WTAmp{WTi} = min(animalTable.leftGrade', animalTable.rightGrade');
        
        WTmissFrac{WTi} = animalTable.missFrac';
    %     if numel(animalTable.correctFrac) < maxSessWT
    %         WTcorrectFrac(WTi, numel(animalTable.correctFrac)+1:maxSessWT) = nan;
    %         WTmissFrac(WTi,numel(animalTable.correctFrac)+1:maxSessWT) = nan;
    %         WTAmp(WTi, numel(animalTable.correctFrac)+1:maxSessWT) = nan;
    %     end
        
    end
        
    for KOi = 1: numel(KOAnis)
        aniID = KOAnis{KOi};
        animalTable = specdataFileTb(ismember(specdataFileTb.animalID, aniID),:);
        animalTable = sortrows(animalTable, 'sessionDatetime');
        KOcorrectFrac{KOi} = animalTable.correctFrac';
        KOAmp{KOi} = min(animalTable.leftGrade', animalTable.rightGrade');
        KOmissFrac{KOi} = animalTable.missFrac';
    %     if numel(animalTable.correctFrac) < maxSessKO
    %         KOcorrectFrac(KOi, numel(animalTable.correctFrac)+1:maxSessKO) = nan;
    %         KOmissFrac(KOi,numel(animalTable.correctFrac)+1:maxSessKO) = nan;
    %         KOAmp(KOi, numel(animalTable.correctFrac)+1:maxSessKO) = nan;
    %     end
        
    end    
    
    
    WTPerfs = cell2mat(cellfun(@(x) x(end -lastNSess:end),WTcorrectFrac, 'UniformOutput', false));
    KOPerfs = cell2mat(cellfun(@(x) x(end -lastNSess:end),KOcorrectFrac, 'UniformOutput', false));
    WTPerfsAmp = cell2mat(cellfun(@(x) x(end -lastNSess:end),WTAmp, 'UniformOutput', false));
    KOPerfsAmp = cell2mat(cellfun(@(x) x(end -lastNSess:end),KOAmp, 'UniformOutput', false));
    
    
    
    
    [WTmean, WTsd, WTse, WTci] = MMath.MeanStats(WTPerfs,2, 'Alpha', 0.05);
    [KOmean, KOsd, KOse, KOci] = MMath.MeanStats(KOPerfs,2, 'Alpha', 0.05); 
    
    [WTmeanAmps, WTsdAmps, WTseAmps, WTciAmps] = MMath.MeanStats(WTPerfs,2, 'Alpha', 0.05);
    [KOmeanAmps, KOsdAmps, KOseAmps, KOciAmps] = MMath.MeanStats(KOPerfsAmp,2, 'Alpha', 0.05); 
    
    g = figure(5); clf;
    g.WindowState = 'Maximized';
    hold on 
    rng(11)  % For reproducibility
    x1 = normrnd(WTmean,sqrt(var(WTPerfs)),[50,1]);
    nr = normplot(x1);
    nr(1).Color = 'blue';
    nr(2).Color = 'blue'
    nr(3).Color = 'blue'
    wt = normplot(WTPerfs);
    wt(1).Color = 'black';
    wt(2).Color = 'black'
    wt(3).Color = 'black'
    hold off
    savefig(g, fullfile(savePath, 'NormalityCheckWTsOnly40Freq.fig'));
    exportgraphics(g, fullfile(savePath, 'NormalityCheckWTsOnly40Freq.png'));
    
    
    
    g = figure(6); clf;
    g.WindowState = 'Maximized';
    hold on 
    rng(11)  % For reproducibility
    x1 = normrnd(KOmean,sqrt(var(KOPerfs)),[50,1]);
    nr = normplot(x1);
    nr(1).Color = 'blue';
    nr(2).Color = 'blue'
    nr(3).Color = 'blue'
    ko = normplot(KOPerfs);
    ko(1).Color = 'red';
    ko(2).Color = 'red'
    ko(3).Color = 'red'
    hold off
    savefig(g, fullfile(savePath, 'NormalityCheckKOsOnly40Freq.fig'));
    exportgraphics(g, fullfile(savePath, 'NormalityCheckKOsOnly40Freq.png'));
    
    [H, pval1] = ttest2(KOPerfs, WTPerfs, 'tail', 'both', 'Alpha', 0.05);
    
    [H, pval2] = ttest2(KOPerfsAmp, WTPerfsAmp, 'tail', 'both', 'Alpha', 0.05)
    
    g = figure(7); clf;
    g.WindowState = 'Maximized';
    hold on
    swarmchart(ones(numel(WTPerfs),1), WTPerfs,  'o','markerfacecolor', 'none' , 'MarkerEdgeColor', [0.5 0.5 0.5])
    swarmchart(2*ones(numel(KOPerfs),1), KOPerfs, 'o','markerfacecolor', 'none' , 'MarkerEdgeColor', 'r')
    % plot(1.1, mean(WTPerfs), '.', 'color', 'k', 'MarkerSize',30 )
    % plot(2.1, mean(KOPerfs), '.', 'color', 'r', 'MarkerSize',30 )
    yyaxis left
    errorbar(1.1, WTmean, WTsd, '.', 'color', 'k', 'MarkerSize',30 );
    errorbar(2.1, KOmean, KOsd, '.', 'color', 'r', 'MarkerSize',30 );
    ylim([0.2,1.1]);
    ylabel('Performance (mean +/- StdDev)')
    yyaxis right
    xlim([0,5])
    ylim([0.2,1.1]);
    xticks([1,2,3,4])
    xticklabels({'WT Perf', 'KO Perf', 'WT Amp', 'KO Amp'})
    ylabel('Amplitude of stimulation')
    ax = gca;
    ax.YAxis(1).Color = 'r';
    ax.YAxis(2).Color = 'b';
    set(gca, 'FontSize', 18);
    dim = [.35 .6 .3 .3];
    annotation('textbox',dim, 'String',['p-value = ' num2str(pval1)], 'FitBoxToText','on')
    
    title('Fraction of trials with correct response', 'FontSize', 24)
    hold off
    savefig(g, fullfile(savePath, ['Last ' num2str(lastNSess) ' sessiondaysEachanimalPerfComparisonOnly40Freq.fig']));
    exportgraphics(g, fullfile(savePath, ['Last ' num2str(lastNSess) ' sessiondaysEachanimalPerfComparisonOnly40Freq.png']));
    
    
    
    g = figure(8); clf;
    g.WindowState = 'Maximized';
    hold on
    swarmchart(ones(numel(WTPerfs),1), WTPerfs,  'o','markerfacecolor', 'none' , 'MarkerEdgeColor', [0.5 0.5 0.5])
    swarmchart(2*ones(numel(KOPerfs),1), KOPerfs, 'o','markerfacecolor', 'none' , 'MarkerEdgeColor', 'r')
    
    % plot(1.1, mean(WTPerfs), '.', 'color', 'k', 'MarkerSize',30 )
    % plot(2.1, mean(KOPerfs), '.', 'color', 'r', 'MarkerSize',30 )
    yyaxis left
    errorbar(1.1, WTmean, WTsd, '.', 'color', 'k', 'MarkerSize',30 );
    errorbar(2.1, KOmean, KOsd, '.', 'color', 'r', 'MarkerSize',30 );
    ylim([0.2,1.1]);
    ylabel('Performance (mean +/- StdDev)')
    yyaxis right
    swarmchart(3*ones(numel(WTPerfsAmp),1), WTPerfsAmp, 'o','markerfacecolor', 'none' , 'MarkerEdgeColor', [0.5 0.5 0.5])
    swarmchart(4*ones(numel(KOPerfsAmp),1), KOPerfsAmp, 'o','markerfacecolor', 'none' , 'MarkerEdgeColor', 'b')
    errorbar(3.1, WTmeanAmps, WTsdAmps, '.', 'color', 'k', 'MarkerSize',30 );
    errorbar(4.1, KOmeanAmps, KOsdAmps, '.', 'color', 'b', 'MarkerSize',30 );
    ax = gca;
    ax.YAxis(1).Color = 'r';
    ax.YAxis(2).Color = 'b';
    dim = [.35 .6 .3 .3];
    annotation('textbox',dim, 'String',['p-value = ' num2str(pval1)], 'FitBoxToText','on')
    dim = [.7 .6 .3 .3];
    annotation('textbox',dim, 'String',['p-value = ' num2str(pval2)], 'FitBoxToText','on')
    
    xlim([0,5])
    ylim([0.2,1.1]);
    xticks([1,2,3,4])
    xticklabels({'WT Perf', 'KO Perf', 'WT Amp', 'KO Amp'})
    ylabel('Amplitude of stimulation')
    set(gca, 'FontSize', 18)
    title('Fraction of trials with correct response', 'FontSize', 24)
    hold off
    savefig(g, fullfile(savePath, ['Last ' num2str(lastNSess) ' sessiondaysEachanimalPerfComparisonOnly40FreqWithAmp.fig']));
    exportgraphics(g, fullfile(savePath, ['Last ' num2str(lastNSess) ' sessiondaysEachanimalPerfComparisonOnly40FreqWithAmp.png']));
end






%% opto inhibition effect
% 
clear all
animalID = {'VC030109', 'VC030110','VC030207'};
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
        case 'behavSEs'            
            behavDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            seNames = cellfun(@(x) endsWith(x,'se.mat'),behavDirInfo.name);            
            behavDirInfo(~seNames,:) = [];
            animalNames = cellfun(@(x) strsplit(x, ' '), behavDirInfo.name, 'UniformOutput', false);
            animalNames = cellfun(@(x) x{1}, animalNames, 'UniformOutput',false);
            behavDirInfo(~ismember(animalNames, animalID),:) = [];

           
        case 'SessInfo'
            sessInfoDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}, '*.csv'));               
            animalNames= cellfun(@(x) strsplit(x, '_'), sessInfoDirInfo.name, 'UniformOutput', false);
            animalNames = cellfun(@(x) x{1}, animalNames, 'UniformOutput',false);
            sessInfoDirInfo(~ismember(animalNames, animalID),:) = [];
        
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

%% Plot individual sessions as different colors. 
% 
% clear all
close all
% animalID = {'VC030109', 'VC030110', 'VC030207'};
clearvars -except dataFileTb
trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
trials{2} = {'Stim_Som_Left', 'Stim_Som_Left_Opto', 'Stim_Som_Right', 'Stim_Som_Right_Opto'}; 
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\behavSEs', 'Select source SEs');
% clearvars -except readPaths seDir seNames animalID trials;
% readPathParts = cellfun(@(x) strsplit(x, '\'), readPaths, 'UniformOutput', false);
% animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
animalID = dataFileTb.MouseName;
uniAnimalId = unique(animalID);
uInhSites = unique(dataFileTb.inhSite);
inhSites = dataFileTb.inhSite;
readPaths= dataFileTb.sePath;
% get all the trialNums for each trialType for each session and mouse

for inhibitionSide = 1:numel(uInhSites)
    inh = uInhSites(inhibitionSide);
    for animalNum =1:numel(uniAnimalId)
         ani = uniAnimalId{animalNum}; 
         sessNum =1;
     
         for i = find(ismember(dataFileTb.MouseName, ani) & ismember(dataFileTb.inhSite,inh))' 
             load(readPaths{i});

             trialMap = se.userData.sessionInfo.trialMap;
             if ~isempty(trialMap{1})
                trialSplit = strsplit(trialMap{1},':');
                if any(strcmp(trialSplit{2}(1:end-1), 'end'))
                    trialInd = [str2double(trialSplit{1}) : se.numEpochs];
                else
                    trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}(1:end-1))];
                end
                se = BS.Preprocess.keepTrials(trialInd,se);
            
                
            end
            
            
            behavData = se.GetTable('behavValue');
            stimRight{inhibitionSide,animalNum,sessNum} = behavData.rightStimType{end};
            stimLeft{inhibitionSide,animalNum,sessNum} = behavData.leftStimType{end};
            
            
            responses = behavData.response;
            abortTrials = find(cell2mat(responses) == 3);        
            
            behavData(abortTrials,:) = [];
            
            responses = behavData.result;
            missTrials = isnan(responses);
            missData = behavData(missTrials,:);
            behavData(missTrials, :) =[];
            
            
            trialTypes = unique(behavData.trialType);
            
            if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
                trialTypes = trials{2};
            else
                trialTypes = trials{1};
            end
            for trialType = 1:numel(trialTypes)
                trialTypeInd = strcmp(trialTypes{trialType}, behavData.trialType);
                fracResult{inhibitionSide,animalNum,sessNum,trialType} = mean(behavData.result(trialTypeInd));
                
                missFrac{inhibitionSide,animalNum,sessNum,trialType} = numel(find(strcmp(trialTypes{trialType}, missData.trialType)))/...
                    (height(missData.trialType) + height(behavData.trialType));
                allTrialTypes{inhibitionSide,animalNum,sessNum} = trialTypes;
            end   
            
            
            sessDate{inhibitionSide,animalNum,sessNum} = char(se.userData.sessionInfo.seshDate{1});
            sessNum = sessNum+1;
            
           
        end
     end
end
    


pathParts = strsplit(dataFileTb.sePath{1}, '\');
figureFolder = fullfile(pathParts{1:end-2}, 'Figures\Cohort4');
if ~exist(figureFolder, 'dir')
    mkdir(figureFolder);
end
fracResult = permute(fracResult,[2,1,3,4]);
sessDate = permute(sessDate,[2,1,3]);
 % plot correct fraction
KOIDs = {'VC030204'};
WTIDs = {'VC030105'};

close all;
for animalNum = 1:size(fracResult,1)
     g = figure(animalNum); clf;
        color = {[1 0 0], [0 1 0], [0 0 1]};
        hold on
    for inhibitionSide =1:size(fracResult,2)
        if isempty(fracResult{animalNum, inhibitionSide})
            continue;
        end
       
        h = subplot(1,size(fracResult,2),inhibitionSide)
        hold(h, 'on');
        clearvars f;
        legnedI = 0;
        for sessNum =1:size(fracResult,3)        
            if ~isempty([fracResult{animalNum,inhibitionSide,sessNum,:}])
                f(sessNum) = plot([1:4], [fracResult{animalNum,inhibitionSide,sessNum,:}],'.', 'MarkerSize',15);
                line([1:4], [fracResult{animalNum,inhibitionSide,sessNum,:}]);    
                legnedI = legnedI+1;
            end
            
        end
        xlim([0,5]);
        ylim([0,1.0]);
        xticks([1 2 3 4])
        
        try
            legend(f, sessDate{animalNum,inhibitionSide,1:legnedI})
        catch
            keyboard;
        end
        xticklabels({'Left Stim only', 'Left Stim + Opto','Right Stim only', 'Right Stim + Opto'})
        title([uInhSites{inhibitionSide} ' inhibition']);
        hold(h, 'off');
        
%         h = subplot(1,size(fracResult,2),inhibitionSide);
%         hold(h, 'on');
%         
%     
%         for sessNum =1:size(fracResult{inhibitionSide}{animalNum},2)
%             f(sessNum) = plot([1:4], missFrac{inhibitionSide}{animalNum}{sessNum},'.', 'MarkerSize',15)
%             line([1:4], missFrac{inhibitionSide}{animalNum}{sessNum})
%             
%             
%         %     saveas(g,[figureFolder '\intanSEbehav.png']);
%         end
%         xlim([0,5]);
%         ylim([0.0,1.0]);
%         xticks([1 2 3 4]);
%         legend(f, sessDate{inhibitionSide}{animalNum})
%         xticklabels({'Left Stim only', 'Left Stim + Opto','Right Stim only', 'Right Stim + Opto'})
%         title('MissFrac');
%         hold(h, 'off');
%     
        
    
    end
    sgtitle([uniAnimalId{animalNum}])
    hold off;
    %savFig with pos = get(figure(5), 'Position')
    set(g, 'position', [1 41 1920 1083])
    savefig(g,fullfile(figureFolder,  [uniAnimalId{animalNum} ' inhibition.fig']));
    
    exportgraphics(g, fullfile(figureFolder,  [uniAnimalId{animalNum} ' inhibition.png']));
end

%% Plot indivdual datapoints as gray and mean as red for leftStims and blue for rightStims
% 
% clear all
close all
% animalID = {'VC030109', 'VC030110', 'VC030207'};
clearvars -except dataFileTb
trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
trials{2} = {'Stim_Som_Left', 'Stim_Som_Left_Opto', 'Stim_Som_Right', 'Stim_Som_Right_Opto'}; 
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\behavSEs', 'Select source SEs');
% clearvars -except readPaths seDir seNames animalID trials;
% readPathParts = cellfun(@(x) strsplit(x, '\'), readPaths, 'UniformOutput', false);
% animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
animalID = dataFileTb.MouseName;
uniAnimalId = unique(animalID);
uInhSites = unique(dataFileTb.inhSite);
inhSites = dataFileTb.inhSite;
readPaths= dataFileTb.sePath;
% get all the trialNums for each trialType for each session and mouse

for inhibitionSide = 1:numel(uInhSites)
    inh = uInhSites(inhibitionSide);
    for animalNum =1:numel(uniAnimalId)
         ani = uniAnimalId{animalNum}; 
         sessNum =1;
     
         for i = find(ismember(dataFileTb.MouseName, ani) & ismember(dataFileTb.inhSite,inh))' 
             load(readPaths{i});

             trialMap = se.userData.sessionInfo.trialMap;
             if ~isempty(trialMap{1})
                trialSplit = strsplit(trialMap{1},':');
                if any(strcmp(trialSplit{2}(1:end-1), 'end'))
                    trialInd = [str2double(trialSplit{1}) : se.numEpochs];
                else
                    trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}(1:end-1))];
                end
                se = BS.Preprocess.keepTrials(trialInd,se);
            
                
            end
            
            
            behavData = se.GetTable('behavValue');
            stimRight{inhibitionSide,animalNum,sessNum} = behavData.rightStimType{end};
            stimLeft{inhibitionSide,animalNum,sessNum} = behavData.leftStimType{end};
            
            
            responses = behavData.response;
            abortTrials = find(cell2mat(responses) == 3);        
            
            behavData(abortTrials,:) = [];
            
            responses = behavData.result;
            missTrials = isnan(responses);
            missData = behavData(missTrials,:);
            behavData(missTrials, :) =[];
            
            
            trialTypes = unique(behavData.trialType);
            
            if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
                trialTypes = trials{2};
            else
                trialTypes = trials{1};
            end
            for trialType = 1:numel(trialTypes)
                trialTypeInd = strcmp(trialTypes{trialType}, behavData.trialType);
                fracResult{inhibitionSide,animalNum,sessNum,trialType} = mean(behavData.result(trialTypeInd));
                
                missFrac{inhibitionSide,animalNum,sessNum,trialType} = numel(find(strcmp(trialTypes{trialType}, missData.trialType)))/...
                    (height(missData.trialType) + height(behavData.trialType));
                allTrialTypes{inhibitionSide,animalNum,sessNum} = trialTypes;
            end   
            
            
            sessDate{inhibitionSide,animalNum,sessNum} = char(se.userData.sessionInfo.seshDate{1});
            sessNum = sessNum+1;
            
           
         end
         [meanPerf{inhibitionSide, animalNum}, sd, se, ciPerf{inhibitionSide, animalNum}] ...
             = MMath.MeanStats(cell2mat(fracResult(inhibitionSide, animalNum,:,:)), 3);
     end
end
    
 t = ciPerf{inhibitionSide, animalNum};
 a = permute(t,[3,4,1,2])
% permute 
meanPerf = cellfun(@(x) permute(x, [3,4,1,2]), meanPerf, 'UniformOutput', false);
ciPerf = cellfun(@(x) permute(x, [3,4,1,2]), ciPerf, 'UniformOutput', false);

pathParts = strsplit(dataFileTb.sePath{1}, '\');
figureFolder = fullfile(pathParts{1:end-2}, 'Figures\Cohort4');
if ~exist(figureFolder, 'dir')
    mkdir(figureFolder);
end
fracResult = permute(fracResult,[2,1,3,4]);
sessDate = permute(sessDate,[2,1,3]);
meanPerf = permute(meanPerf,[2,1]);
ciPerf = permute(ciPerf,[2,1]);

 % plot correct fraction
KOIDs = {'VC030204'};
WTIDs = {'VC030105'};
%
close all;
for animalNum = 1:size(fracResult,1)
     g = figure(animalNum); clf;
        color = {[1 0 0], [0.5 0.5 0.5], [0 0 1]};
        hold on
    for inhibitionSide =1:size(fracResult,2)
        if isempty(fracResult{animalNum, inhibitionSide})
            continue;
        end
       
        h = subplot(1,size(fracResult,2),inhibitionSide)
        hold(h, 'on');
        clearvars f;
        set(gca,'FontSize',18)
        for sessNum =1:size(fracResult,3)        
            if ~isempty([fracResult{animalNum,inhibitionSide,sessNum,:}])
%                 f(sessNum) = plot([1:4], [fracResult{animalNum,inhibitionSide,sessNum,:}],'.', 'MarkerSize',15, 'Color', 'gray');
                
                line([1:2], [fracResult{animalNum,inhibitionSide,sessNum,1:2}], 'color', color{2});
                line([3:4], [fracResult{animalNum,inhibitionSide,sessNum,3:4}], 'color', color{2});
                
                
            end
            
        end
%        errorbar([1:2], meanPerf{animalNum,inhibitionSide}(1:2), ciPerf{animalNum,inhibitionSide}(1,1:2) - meanPerf{animalNum,inhibitionSide}(1:2), ...
%             ciPerf{animalNum,inhibitionSide}(2,1:2) - meanPerf{animalNum,inhibitionSide}(1:2), '.', 'color', color{1});
%        errorbar([3:4], meanPerf{animalNum,inhibitionSide}(3:4), ciPerf{animalNum,inhibitionSide}(1,3:4) - meanPerf{animalNum,inhibitionSide}(3:4), ...
%             ciPerf{animalNum,inhibitionSide}(2,3:4) - meanPerf{animalNum,inhibitionSide}(3:4), '.', 'color', color{3});
        f(1) = line([1:2], [meanPerf{animalNum,inhibitionSide}(1:2)], 'color', color{1}, 'lineWidth', 2);
        f(2) = line([3:4], [meanPerf{animalNum,inhibitionSide}(3:4)], 'color', color{3}, 'lineWidth', 2);
        xlim([0,6]);
        ylim([0,1.0]);
        xticks([1 2 3 4])
        
        try
            legend(f, {'Left Stim trials', 'Right Stim trials'}, 'Location', 'northeast')
        catch
            keyboard;
        end
        xticklabels({'Left Stim only', 'Left Stim + Opto','Right Stim only', 'Right Stim + Opto'})
        
        ylabel('Performance (fraction correct)')
        title([uInhSites{inhibitionSide} ' inhibition']);
        hold(h, 'off');
        
%         h = subplot(1,size(fracResult,2),inhibitionSide);
%         hold(h, 'on');
%         
%     
%         for sessNum =1:size(fracResult{inhibitionSide}{animalNum},2)
%             f(sessNum) = plot([1:4], missFrac{inhibitionSide}{animalNum}{sessNum},'.', 'MarkerSize',15)
%             line([1:4], missFrac{inhibitionSide}{animalNum}{sessNum})
%             
%             
%         %     saveas(g,[figureFolder '\intanSEbehav.png']);
%         end
%         xlim([0,5]);
%         ylim([0.0,1.0]);
%         xticks([1 2 3 4]);
%         legend(f, sessDate{inhibitionSide}{animalNum})
%         xticklabels({'Left Stim only', 'Left Stim + Opto','Right Stim only', 'Right Stim + Opto'})
%         title('MissFrac');
%         hold(h, 'off');
%     
        
    
    end
    sgtitle([uniAnimalId{animalNum}])
    hold off;
    %savFig with pos = get(figure(5), 'Position')
    set(g, 'position', [1 41 1920 1083])
    savefig(g,fullfile(figureFolder,  [uniAnimalId{animalNum} ' inhibition.fig']));
    
    exportgraphics(g, fullfile(figureFolder,  [uniAnimalId{animalNum} ' inhibition_mean.png']));
end

%% compare to no manipulation
% Multilevel_bootstrap
% resample mice with replacement
% resample session with replacement
% resample trials with replacement 
% 
clear all
close all
trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
trials{2} = {'Stim_Som_Left', 'Stim_Som_Left_Opto', 'Stim_Som_Right', 'Stim_Som_Right_Opto'}; 
inhSitesAll = {'Left S1', 'Right S1','NA'};
[readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\SEs', 'Select source SEs');
clearvars -except readPaths seDir seNames animalID trials inhSitesAll;
readPathParts = cellfun(@(x) strsplit(x, '\'), readPaths, 'UniformOutput', false);
animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
AnimalIDs = cellfun(@(x) x{1}, animal, 'UniformOutput', false);
animalID = unique(AnimalIDs);
% get all the trialNums for each trialType for each session and mouse

pathParts = strsplit(seDir, '\');
figureFolder = fullfile(pathParts{1:end-2}, 'Figures');


savePath=(fullfile(figureFolder,'Inhibition'));
if ~exist(savePath, 'dir')
    mkdir(savePath);
end

photoInhAll = table();

for animalNum =1:size(animalID,1)
     ani = animalID{animalNum}; 
     
    sessNum =[1,1,1];
    for i = find(ismember(AnimalIDs, ani))'        
        load(readPaths{i});
        behavData = se.GetTable('behavValue');

        trialMap = se.userData.sessionInfo.trialMap;
        if ~isempty(trialMap{1})
            trialSplit = strsplit(trialMap{1},':');
            if any(strcmpi(trialSplit{2}, 'end'''))
                trialInd = [str2double(trialSplit{1}) : se.numEpochs];
            else
                trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}(1:end-1))];
            end
            se = BS.Preprocess.keepTrials(trialInd,se);
        
            
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
        behavData(missTrials, :) =[];
        
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
            
            missFrac{animalNum,inhSite}{sessNum(inhSite)}(trialType) = numel(find(strcmp(trialTypes{trialType}, missData.trialType)))/...
                (height(missData.trialType) + height(behavData.trialType));
            allTrialTypes{animalNum, inhSite}{sessNum(inhSite)} = trialTypes;
        end 
        
              
             
        photoInhAll= [photoInhAll; behavData];

        sessNum(inhSite) = sessNum(inhSite)+1;
        
       
    end
end


inhSites = unique(photoInhAll.inhSite); 

Genotypes = unique(photoInhAll.Genotype); 

trialTypes= unique(photoInhAll.trialType); % left, left_opto, right, right_opto



        
if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
    trialTypes = trials{2};
else
    trialTypes = trials{1};
end 

nboot = 10000; % number for bootstrapping
fracCorrect = cell(length(Genotypes),length(inhSites), nboot);
delta_mouse = cell(length(Genotypes),length(inhSites), nboot);
delta_session =cell(length(Genotypes),length(inhSites), nboot);
delta_prob = cell(nboot);
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
        rng(7);
%             rng(test(t)); % control random number generation
       parfor n = 1:nboot
           
            resampled_mice = randsample(mouseNames, length(mouseNames), true); 
            for mouse = 1:length(resampled_mice) 
                
                m = u(strcmp(u.mouseName, resampled_mice{mouse}), :);
                
                dateData = cellfun(@(x) datestr(x, 'yyyymmdd'), m.sessDate, 'UniformOutput',false);
                sessions = unique(dateData);
                m.sessDate = dateData;
                % resample session
                
                for session = 1:height(sessions)
                    
                    v = m(strcmp(sessions(randi(height(sessions)),:), m.sessDate), :);  
    
                    
    
                    % Trials with stimuli
                    
                   for trialType=1:numel(trialTypes)
                       
                        trialInds = find(strcmp(trialTypes{trialType}, v.trialType));
                            
                        
                        % resample trials
                        
                        resampled_trialInds = randsample(trialInds, length(trialInds), true); 
                        fracCorrect{g,e,n}{mouse}{session}(trialType) = mean(v.result(resampled_trialInds)); % lick probability of each trial type                  
                        
                    end
    
                    delta_session{g,e,n}{mouse}(session,1:2) = [fracCorrect{g,e,n}{mouse}{session}(2)- fracCorrect{g,e,n}{mouse}{session}(1),...
                        fracCorrect{g,e,n}{mouse}{session}(4)-fracCorrect{g,e,n}{mouse}{session}(3)]; % leftOpto-left, RightOpto-Right
                   
                   
%                     clear fracCorrect v trialInds
                end
                
                delta_mouse{g,e,n}(mouse,1:2) = mean(delta_session{g,e,n}{mouse},1); % average across sessions
%                 clear delta_session
            end
            delta_prob{n}(1:2) = mean(delta_mouse{g,e,n},1); % average across mice
%             clear delta_mouse
        end
        
        photoInh_bootstrapped{(g-1)*length(inhSites)+e,1} = Genotype;
        photoInh_bootstrapped{(g-1)*length(inhSites)+e,2} = inhSite;
        photoInh_bootstrapped{(g-1)*length(inhSites)+e,3} = cell2mat(delta_prob);
%         clear delta_prob
    end
end
toc



 % plot correct fraction
KOIDs = {'VC030207'};
WTIDs = {'VC030109','VC030110'};
alpha = 0.05;
clearvars meanStats SEM ts ciStats
for rows = 1:height(photoInh_bootstrapped)
    meanStats{rows} = mean(photoInh_bootstrapped{rows,3},1);
    try
        SEM(1:2) = std(photoInh_bootstrapped{rows,3},0,1)/sqrt(height(photoInh_bootstrapped{rows,3})); 
        ts = tinv([alpha/2 1-alpha/2], height(photoInh_bootstrapped{rows,3})-1);
        ciStats{rows}{1} = meanStats{rows}(1) + ts*SEM(1);
        ciStats{rows}{2} = meanStats{rows}(2) + ts*SEM(2);
    catch
        ciStats{rows}{1} =0;
        ciStats{rows}{2} = 0;
    end
    
end
photoInh_bootstrapped(:,4) = meanStats';
photoInh_bootstrapped(:,5) = ciStats';
photoInhBootstrapped = table();
vars = {'Genotype', 'InhSite', 'FracCorrect', 'Mean', 'CI'};
photoInhBootstrapped = cell2table(photoInh_bootstrapped,'VariableNames', vars);


% colors_tt = { [0 1 1] [0.5 0.5 0.5]}; 

% colors_tt = {[0.5 0.5 0.5] [1 0 1]}; 
colors_tt = {[0 1 1] [1 0 1]; [0 1 1] [1 0 1]}; 
close all;
g1 = figure(100);clf
for g=1:numel(Genotypes)
    subplot(1,2,numel(Genotypes)-g+1)
    hold on
    for e =0:numel(inhSites)-1
        delta_bootstrapped_g = photoInh_bootstrapped{2*g-1+e:2*g,3};
       
        sorted_delta = sort(delta_bootstrapped_g,1);   
         if ~isempty(sorted_delta)
            y1 = mean(sorted_delta,1); 
            y2 = sorted_delta(nboot*0.025,1:2); 
            y3 = sorted_delta(nboot*0.975,1:2); 
            x = [2*e+1, 2*e+2];
            errorbar(x,y1,(y1-y2),(y3-y1),'o','Color',colors_tt{g,e+1},...
            'MarkerSize',6,'MarkerFaceColor',colors_tt{g,e+1}, 'MarkerEdgeColor',colors_tt{g,e+1});    
        end
    
    end
    hold off
    set(gca, 'box','off','TickDir','out');
        ylim([-1 0.5]);
    yline(0, '--k');
    ylabel('\Deltaperformance with inhibition')
    xtickangle(45);
    xlim([0,5]);
    xticks([1 2 3 4])
    xticklabels({'Opto_L Stim_L', 'Opto_L Stim_R', 'Opto_R Stim_L', 'Opto_R Stim_R'})
    title(Genotypes{g});
    savefig(g1,fullfile(savePath,[animalID{1} ' Cohort3 Bootstrapping KO vs WT optoInhibition.fig']));
    exportgraphics(g1,fullfile(savePath, [animalID{1} ' Cohort3 Bootstrapping KO vs WT optoInhibition.png']));
end

g2=figure(200);clf
for g=1:numel(Genotypes)
    subplot(1,2,numel(Genotypes)-g+1)
    hold on
    for e =0:numel(inhSites)-1
        delta_bootstrapped_g = photoInh_bootstrapped{2*g-1+e:2*g,3};
        sorted_delta = sort(delta_bootstrapped_g,1);   
        y1 = mean(sorted_delta,1); 
        y2 = sorted_delta(nboot*0.025,1:2); 
        y3 = sorted_delta(nboot*0.975,1:2); 
        x = [2*e+1, 2*e+2];
        
        x2 = repmat(x,[height(delta_bootstrapped_g),1]);
        y = sorted_delta;
        
        swarmchart(x2,y,0.5,'o','markerfacecolor', colors_tt{g,e+1}, 'MarkerEdgeColor', 'none');
        errorbar(x,y1,(y1-y2),(y3-y1),'o','Color','black',...
        'MarkerSize',6,'MarkerFaceColor','black', 'MarkerEdgeColor','black');   
    
    end
    hold off
    set(gca, 'box','off','TickDir','out');
    ylim([-1 0.5]);
    ylabel('\Deltaperformance with inhibition')
    yline(0, '--k');
    xtickangle(45);
    xlim([0,5]);
    xticks([1 2 3 4]);
    xticklabels({'Opto_L Stim_L', 'Opto_L Stim_R', 'Opto_R Stim_L', 'Opto_R Stim_R'})
    title(Genotypes{g});
    savefig(g2,fullfile(savePath, [animalID{1} ' Cohort3 Bootstrapping KO vs WT optoInhibition swarm.fig']));
    exportgraphics(g2,fullfile(savePath, [animalID{1} ' Cohort3 Bootstrapping KO vs WT optoInhibition swarm.png']));
end

%% Helper Functions

function [correctFrac, incorrectFrac, missFrac, leftStim, rightStim, sideAssist, leftStimProb, isSessInfo] = getPerfOverall(se)
    behavData = se.GetTable('behavValue');
    stimRight = behavData.rightStimType{end};
    stimLeft = behavData.leftStimType{end};
    
    responses = cell2mat(behavData.response);
    % remove abort trials
    abortTrials = responses ==3;
    behavData(abortTrials,:) = [];

   
    %separate miss trials
    responses = cell2mat(behavData.response);
    missTrials = find(responses==0);
    
    missData = behavData(missTrials, :);
    behavData(missTrials,:) = [];

     %remove catch trials
    result = behavData.result;
    catchTrials = isnan(result);
    behavData(catchTrials,:) = [];

    result = behavData.result;
    correctTrials = find(result);
    try
        incorrectTrials = find(~result);
    catch
        keyboard;
    end 
    missTrials = find(~cell2mat(missData.response));
    correctFrac = height(correctTrials)/(height(correctTrials)+height(incorrectTrials));
    incorrectFrac = height(incorrectTrials)/(height(correctTrials)+height(incorrectTrials));

  
    missFrac = height(missTrials)/(height(missTrials)+height(correctTrials)+height(incorrectTrials));
    
    rightStim = cellstr(stimRight);

    leftStim = cellstr(stimLeft);
    
    sideAssist =  ~strcmp(se.userData.bctData.TrialTypeSection_SideAssist, 'No');
        
    leftStimProb = se.userData.bctData.TrialTypeSection_LeftTrialProb;
    if size(fields(se.userData),1) <2
        isSessInfo = 0;
    elseif isempty(se.userData.sessionInfo)
        isSessInfo =0;
    else
        isSessInfo =1;
    end

end