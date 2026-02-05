


%% Plot units separated by whisker stim duration. Contra vs ipsi, combine for left vs right hemisphere recording 
% Stims are taken as only the first deflection of all frequencies
% clear all
% 
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\StimSEs', 'Select source SEs');

clear all
animalID = { 'VC030211'};
% animalID = {'VC030407'};
% Choose a group folder
rootDir = 'L:\VC03_RoboKO';
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


%% universalWindow

clearvars -except dataFileTb groupDir
ops.trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
ops.trials{2} = {'Stim_Som_Left', 'Stim_Som_Left_Opto', 'Stim_Som_Right', 'Stim_Som_Right_Opto'}; 
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\behavSEs', 'Select source SEs');
% clearvars -except readPaths seDir seNames animalID trials;
% readPathParts = cellfun(@(x) strsplit(x, '\'), readPaths, 'UniformOutput', false);
% animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);


% Plot using FRrate in ses
ops.constantWindow = 0.05;
ops.wM1winadd = 0.05; 
FRbin = '2_5';
ops.recSites = {'S1', 'M1'};
ops.defPenetrationDepth = 1300;
% ops.PlotSigma = 0.001;
ops.statAlpha = 0.05;
ops.plotAlpha = ops.statAlpha;
if ops.plotAlpha <0.99
    ops.allpvals = 1;
else
    ops.allpvals = 0;
end
ops.binSize = 0.0025;
% FRlims = [-0.15 0.15];
ops.tWins = [-1.5, 1.5];
animalIds = unique(dataFileTb.animalId);
ops.folderSigma = [strrep(['StatAlpha ' num2str(ops.statAlpha)], '.', '_') ' wM1windadd=' num2str(ops.wM1winadd)];


ops.universalWindow =1;
if ops.universalWindow
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\constantWin',[strjoin(animalIds, '_') '_NP\AllUnits',FRbin], [num2str(ops.statAlpha) ' ConstantWindow = ' num2str(ops.constantWindow)]);
else
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\constantWin',[strjoin(animalIds, '_') '_NP\AllUnits',FRbin], num2str(ops.statAlpha));
end

if ~exist('ops.savePath', 'dir')
    mkdir(ops.savePath);
end

% plot FRs 
% PlotSignificantFRUnitsSigperStimDur(dataFileTb, ops);

% plot Rasters
PlotSignificantRasterUnitsSigperStimDur(dataFileTb, ops);

%% Region specific window (wM1~250ms)

clearvars -except dataFileTb groupDir
ops.trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
ops.trials{2} = {'Stim_Som_Left', 'Stim_Som_Left_Opto', 'Stim_Som_Right', 'Stim_Som_Right_Opto'}; 
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\behavSEs', 'Select source SEs');
% clearvars -except readPaths seDir seNames animalID trials;
% readPathParts = cellfun(@(x) strsplit(x, '\'), readPaths, 'UniformOutput', false);
% animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
% ops.adcPlot = load('G:\VC03_RoboKO\VC0301\Figures\MeetingUpdate230124\adcPlot.mat');
% ops.adcPlot = ops.adcPlot.adcPlot;
% Plot using FRrate in ses

ops.redo =0;
ops.wM1winadd = 0.05; 
FRbin = '2_5';
ops.recSites = {'S1', 'M1'};
ops.defPenetrationDepth = 1300;
% ops.PlotSigma = 0.001;
ops.statAlpha = 0.005;
ops.plotAlpha = ops.statAlpha;
if ops.plotAlpha <0.99
    ops.allpvals = 1;
else
    ops.allpvals = 0;
end
ops.binSize = 0.0025;
% FRlims = [-0.15 0.15];
ops.tWins = [-1.5, 1.5];
animalIds = unique(dataFileTb.animalId);
ops.folderSigma = [strrep(['StatAlpha ' num2str(ops.statAlpha)], '.', '_') ' wM1windadd=' num2str(ops.wM1winadd)];
% windowSize = 0.15; %in seconds 

% ops.stimDurs = {'150','100','050','020','010','005'}; %in ms

% ops.stimDurs = {'150'}; %in ms
ops.universalWindow =0;
if ops.universalWindow
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\firstcyc',[strjoin(animalIds, '_') '_NP\AllUnits',FRbin], [num2str(ops.statAlpha) ' wM1windadd=' num2str(ops.wM1winadd) ' UniveralWindow' ]);
else
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\firstcyc',[strjoin(animalIds, '_') '_NP\AllUnits',FRbin], [num2str(ops.statAlpha) ' wM1windadd=' num2str(ops.wM1winadd) 'paired']);
end


% plot FRs 
% PlotSignificantFRUnitsSigperStimDur(dataFileTb, ops);

% plot Rasters
PlotSignificantRasterUnitsSigperStimDur(dataFileTb, ops);




%% Region specific window (wM1~250ms)

clearvars -except dataFileTb groupDir
ops.trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
ops.trials{2} = {'Stim_Som_Left', 'Stim_Som_Left_Opto', 'Stim_Som_Right', 'Stim_Som_Right_Opto'}; 
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\behavSEs', 'Select source SEs');
% clearvars -except readPaths seDir seNames animalID trials;
% readPathParts = cellfun(@(x) strsplit(x, '\'), readPaths, 'UniformOutput', false);
% animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
% ops.adcPlot = load('G:\VC03_RoboKO\VC0301\Figures\MeetingUpdate230124\adcPlot.mat');
% ops.adcPlot = ops.adcPlot.adcPlot;
% Plot using FRrate in ses

ops.redo =1;
ops.wM1winadd = 0.05; 
FRbin = '2_5';
ops.recSites = {'S1', 'M1'};
ops.defPenetrationDepth = 1300;
% ops.PlotSigma = 0.001;
ops.statAlpha = 0.005;
ops.plotAlpha = ops.statAlpha;
if ops.plotAlpha <0.99
    ops.allpvals = 1;
else
    ops.allpvals = 0;
end

ops.binSize = 0.0025;
% FRlims = [-0.15 0.15];
ops.tWins = [-1.5, 1.5];
animalIds = unique(dataFileTb.animalId);
ops.folderSigma = [strrep(['StatAlpha ' num2str(ops.statAlpha)], '.', '_') ' wM1windadd=' num2str(ops.wM1winadd)];
% windowSize = 0.15; %in seconds 

% ops.stimDurs = {'150','100','050','020','010','005'}; %in ms

% ops.stimDurs = {'150'}; %in ms
ops.universalWindow =0;
if ops.universalWindow
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\firstcyc',[strjoin(animalIds, '_') '_NP\AllUnits',FRbin], [num2str(ops.statAlpha) ' UniveralWindow' ]);
else
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\firstcyc',[strjoin(animalIds, '_') '_NP\AllUnits',FRbin], num2str(ops.statAlpha));
end


% plot FRs 
% PlotSignificantFRUnitsSigperStimDur(dataFileTb, ops);



if exist(fullfile(ops.savePath, "allVars.mat"), 'file')

    MakeFigures(fullfile(ops.savePath, "allVars.mat"));
else
    PlotSignificantRasterUnitsSigperStimDur(dataFileTb, ops);
    
end

  
    
%% Helper function

function x = findDuration(stimType)
    secs = str2num(stimType(end-2:end));
    if secs
        x = secs/1000;
    else
        x = 1;
    end
end


function x = findDurationFromCyc(stimType)
    freq = str2num(stimType(5:6));
    cycs = str2num(stimType(10));
    x = 1/freq * cycs;
end


function meanFR = SignifyFR(meanFR, allpvals, sigUnits,statAlpha, column,bodyside7, stimDur)
    if allpvals
        if ~isempty(bodyside7) && stimDur~=2
            sigUnits(bodyside7) =[];
            meanFR(~sigUnits,:) = [];
        else
            meanFR(~sigUnits,:) = [];
        end

    else
        sigUnits = cell2mat(cellfun(@(x) x< statAlpha, meanFR(:,column), 'UniformOutput',false));
        meanFR(~sigUnits,:) = [];
    end
            
end

function PlotSignificantFRUnitsSigperStimDur(dataFileTb, ops)
    defPenetrationDepth = ops.defPenetrationDepth;
    trials{1} = ops.trials{1};
    trials{2} = ops.trials{2}; 
    statAlpha = ops.statAlpha;
    plotAlpha = ops.plotAlpha;
    binSize = ops.binSize;
    tWins = ops.tWins;
    allpvals = ops.allpvals;
    savePath = ops.savePath;
    universalWindow = ops.universalWindow;
    
    animalID = dataFileTb.MouseName;
    uniAnimalId = unique(animalID);
    uRecSites = unique(dataFileTb.recSite);
    recSites = dataFileTb.recSite;
    readPaths= dataFileTb.sePath;
    uGenotypes = unique(dataFileTb.Genotype);
    genotypes = dataFileTb.Genotype;
    
    
    bins = tWins(1):binSize:tWins(2);
    
    %
    for genotype = 1:numel(uGenotypes)
        for recSite = 1:numel(uRecSites)
            recReadPaths = readPaths(strcmp(uRecSites(recSite), recSites) & strcmp(uGenotypes(genotype), genotypes));
            if ~universalWindow
                if sum(ismember(uRecSites{recSite}, 'M1'))==2
                    winAdd = ops.wM1winadd;
                elseif sum(ismember(uRecSites{recSite}, 'S1'))==2
                    winAdd = 0.05;
                else
                     winAdd = 0.005;
                end
            else             
                     winAdd = 0.05;
            end
            
            
            if ~isempty(recReadPaths)
                
                
                close all;
                
                allMeanFR = cell(1,12);
                
                adcFinal = cell(1,12);
                for sessNum = 1:numel(recReadPaths)
                    load(recReadPaths{sessNum})
                    meanFR = cell(1,12);
                    adcAll = cell(1,12);
                    
                
                    fprintf('%s\n\n', recReadPaths{sessNum});
                    tRef = se.GetReferenceTime();
                    check = diff(tRef);
                
                    if any(check<0)
                        disp('tRefs are not monotonically increasing');
                    end
                    
                
                       
                                               
                    behavData = se.GetTable('behavValue');                   
                    % remove skipped trials
                    responses = behavData.response;
                    abortTrials = find(cell2mat(responses) == 3);        
                    se = BS.Preprocess.removeTrials(abortTrials,se);
                    behavData = se.GetTable('behavValue');
                    
                    
                    % remove not miss error trials
                    responses = behavData.response;            
                    keepTrials = find(cell2mat(responses));                
                    se = BS.Preprocess.removeTrials(keepTrials,se);
    
                    try            
                        trialMap = se.userData.sessionInfo.APStim;
                    catch
                        trialMap{1} = [];
                    end
    
                    if ~isempty(trialMap{1})
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
                        
    %                     allTrials = 1:se.numEpochs;
    %                     removeTrials = find(~ismember(allTrials, trialInd));
    %                     se = BS.Preprocess.removeTrials(removeTrials,se);
                     end
        
                    %get different stim types
                    leftStimTypes = se.GetColumn('behavValue', 'leftStimType');
                    rightStimTypes =  se.GetColumn('behavValue', 'rightStimType');
                    
                    leftStimTypes = leftStimTypes(trialInd); 
                    
                    rightStimTypes = rightStimTypes(trialInd); 
    
                    %get left and right stim types
                    behavData = se.GetTable('behavValue');
                    behavData = behavData(trialInd,:); 
                    behavData(1,:) = [];
                    leftStimTypes(1,:) = [];                
                    rightStimTypes(1,:) = [];
                    
                    
    
                    % slice firing rate with tWins
                    frAll= se.SliceTimeSeries('spikeRate', tWins, 'Fill', 'bleed');
                    frAll = frAll(trialInd,:);
                    frAll(1,:) = [];
                    frAll = table2cell(frAll);
                    frAll = cellfun(@(x) x', frAll, 'UniformOutput',false);                
                    FRAllTime = frAll(:,1);
                    
    
                    % get adcAll
                    
                    adcAll = se.SliceTimeSeries('adc', tWins, 'Fill', 'bleed');
                    adcAll = adcAll(trialInd,:);
                    adcAll(1,:) = [];
                    adcAllLeft = adcAll.leftStim;
                    adcAllRight = adcAll.rightStim;  
                    adcAllTime = adcAll.time;
                    
                    adcAllLeft = cellfun(@transpose, adcAllLeft,'UniformOutput', false);
                    adcAllRight = cellfun(@transpose, adcAllRight,'UniformOutput', false);             
                    adcAllTime = cellfun(@transpose, adcAllTime,'UniformOutput', false);    
                   
                     
                   
                    
    
                    try
                        unitChanDepth = se.userData.spikeInfo.quality_metrics.depth;
                    catch
                        chanDepth = 0:20:1260; %(in um)
                        channelInds = se.userData.spikeInfo.unit_channel_ind;
                        unitChanDepth= chanDepth(channelInds);
                
                    end
                    
                    
                    stimTypes = leftStimTypes;
                    uStimTypes = unique(stimTypes);              
                    
                    adc = cell(1,numel(uStimTypes));
                    pvals =cell(1,numel(uStimTypes));
                    % parfor all the stimDurs
                    
                    sessInfoTable = se.userData.sessionInfo;
                    if ismember('penetrationDepth', sessInfoTable.Properties.VariableNames)
                        penetrationDepth = sessInfoTable.penetrationDepth;
                    else
                        penetrationDepth = defPenetrationDepth;
                    end
    
                   parfor stimDur = 1:numel(uStimTypes)
        
    
                        trials2keepL{stimDur} = find(strcmp(trials{1}{1}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x,uStimTypes{stimDur}), ...
                            leftStimTypes, 'UniformOutput',false)));
                        trials2keepR{stimDur} = find(strcmp(trials{1}{2}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x,uStimTypes{stimDur}), ...
                            rightStimTypes, 'UniformOutput',false)));
                        % Get window size of stim duration
                        try
                            windowSize{stimDur} = findDurationFromCyc(uStimTypes{stimDur})+winAdd; %in s 
                        catch
                            windowSize{stimDur} = findDuration(uStimTypes{stimDur})+winAdd; %in s 
                        end
    
    %                     FRlims{stimDur} = [(-windowSize{stimDur}), (windowSize{stimDur})];
    
                        
                        binsWin{stimDur} = find(bins>= -windowSize{stimDur} & bins<= windowSize{stimDur});
                        plotLims{stimDur} = [-windowSize{stimDur}, windowSize{stimDur}];
                        temp = binsWin{stimDur};
                        frAllwin{stimDur} = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                        FRLeft{stimDur} = frAllwin{stimDur}(trials2keepL{stimDur},2:end);
                        FRRight{stimDur} = frAllwin{stimDur}(trials2keepR{stimDur},2:end);
                        FRtime{stimDur} = frAllwin{stimDur}(trials2keepR{stimDur},1);
                        
                        %get p-value based on windowsize = stim duration
                        
                        preWindow{stimDur} = 1:(round(numel(FRLeft{stimDur}{1})/2));
                        postWindow{stimDur} =  preWindow{stimDur}(end)+1: numel(FRLeft{stimDur}{1}); 
                        temp1 = preWindow{stimDur};
                        temp2 = postWindow{stimDur};
                        preMeanFRL{stimDur} = cell2mat(cellfun(@(x) mean(x(temp1)), FRLeft{stimDur}, 'UniformOutput', false));
                        postMeanFRL{stimDur} = cell2mat(cellfun(@(x) mean(x(temp2)), FRLeft{stimDur}, 'UniformOutput', false));
                 
                        preMeanFRR{stimDur} = cell2mat(cellfun(@(x) mean(x(temp1)), FRRight{stimDur}, 'UniformOutput', false));
                        postMeanFRR{stimDur} = cell2mat(cellfun(@(x) mean(x(temp2)), FRRight{stimDur}, 'UniformOutput', false));
                        
                        % get frAll for FRlims  --> seems redundant
                        FRlims{stimDur} = [tWins(1), tWins(2)];
                        binsWin{stimDur} = find(bins>= FRlims{stimDur}(1) & bins<= FRlims{stimDur}(2));
                        temp = binsWin{stimDur}(1:end-1);
                        frAllplot{stimDur} = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                        FRLeft{stimDur} = frAllplot{stimDur}(trials2keepL{stimDur},2:end);
                        FRRight{stimDur} = frAllplot{stimDur}(trials2keepR{stimDur},2:end);
                        FRtime{stimDur} = frAllplot{stimDur}(:,1);            
                        
                        %Get adcAll
                        temp0 = adcAllTime(trials2keepL{stimDur});
                        idcs = min(cell2mat(cellfun(@(x) numel(x), temp0, 'UniformOutput',false)));
                        temp0 = cell2mat(cellfun(@(x) x(1:idcs), temp0, 'UniformOutput', false));
                        adc{stimDur}{1,1} = MMath.MeanStats(temp0,1);
    
                        temp0 = adcAllLeft(trials2keepL{stimDur});
                        idcs = min(cell2mat(cellfun(@(x) numel(x), temp0, 'UniformOutput',false)));
                        temp0 = cell2mat(cellfun(@(x) x(1:idcs), temp0, 'UniformOutput', false));
                        adc{stimDur}{2,1} = double(MMath.MeanStats(temp0,1));                    
                        
                        adcWin = find(adcAllTime{1}>= FRlims{stimDur}(1) & adcAllTime{1}<= FRlims{stimDur}(2));
                        if size(adcWin,2) > numel(adc{stimDur}{2,1})
                            adcWin = adcWin(1:numel(adc{stimDur}{2,1}));
                        end
                        
                        temp = adc{stimDur};
                        adc{stimDur} = cell2mat(cellfun(@(x) x(adcWin), temp, 'UniformOutput',   false));          
                        maxAdc(sessNum,stimDur) = max(adc{stimDur}(2,:));
    
                        pvalL{stimDur} = [];
                        pvalR{stimDur} = [];
                        unitDepth{stimDur} = [];
                        
    
                        for unitNum = 1: size(preMeanFRL{stimDur},2)
                            [H{stimDur}(unitNum), pvalL{stimDur}(unitNum)] = ttest2(preMeanFRL{stimDur}(:,unitNum), postMeanFRL{stimDur}(:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);
                             [H{stimDur}(unitNum), pvalR{stimDur}(unitNum)] = ttest2(preMeanFRR{stimDur}(:,unitNum), postMeanFRR{stimDur}(:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);
                            
                 
                            unitDepth{stimDur}(unitNum) = unitChanDepth(unitNum);
    
                            meanFR{stimDur}{unitNum,1} =  MMath.MeanStats(cell2mat(FRtime{stimDur}), 1);
    
    %                         [meanFR{stimDur}{unitNum,2}, SD{stimDur}{unitNum,1}, SE{stimDur}{unitNum,1},...
    %                             meanFR{stimDur}{unitNum,3}]= MMath.MeanStats(cell2mat(FRLeft{stimDur}(:,unitNum)), 1);
    
                            [meanFR{stimDur}{unitNum,2}, ~, ~,...
                                meanFR{stimDur}{unitNum,3}]= MMath.MeanStats(cell2mat(FRLeft{stimDur}(:,unitNum)), 1);
    
    % 
    %                         [meanFR{stimDur}{unitNum,4}, SD{stimDur}{unitNum,3}, SE{stimDur}{unitNum,1},...
    %                             meanFR{stimDur}{unitNum,5}] = MMath.MeanStats(cell2mat(FRRight{stimDur}(:,unitNum)), 1);
    
                            [meanFR{stimDur}{unitNum,4}, ~, ~,...
                                meanFR{stimDur}{unitNum,5}] = MMath.MeanStats(cell2mat(FRRight{stimDur}(:,unitNum)), 1);
    
    
                            meanFR{stimDur}{unitNum,6} = penetrationDepth-unitDepth{stimDur}(unitNum);
    
                            meanFR{stimDur}{unitNum,7} = min(pvalL{stimDur}(unitNum), pvalR{stimDur}(unitNum));
                            pvals{stimDur}(unitNum) = min(pvalL{stimDur}(unitNum), pvalR{stimDur}(unitNum));
    
                        end
                        adcFinal{stimDur}(end+1:end+size(adc{stimDur},1),1:size(adc{stimDur},2)) = adc{stimDur};
                        allMeanFR{stimDur}(end+1:end+size(meanFR{stimDur},1),:) = meanFR{stimDur};         
                        
                   end
                   
                 
                       
                        
                end
    
    
            else
                continue;
            end
            
            % plot allMeanFR for all the stimDur
            [maxadcfig rows] = max(maxAdc(1,:));
             if maxadcfig <0.1
                fM = 10e4;
    %                 fM = 1;
            else
                fM =1;
                
            end
            
    %         maxadcfig = maxadcfig*fM; 
            close all
            if sum(ismember(uRecSites{recSite}, 'Left'))==4
                color = {'b', 'r'};
    
            else
                color = {'r', 'b'}
            end
            for allpvals =0:ops.allpvals
                    meanFR ={};
                    sigUnits= {};  
                    
                    
                    if allpvals
                        pvals = cell2mat(cellfun(@(x) x', pvals, 'UniformOutput', false));
                        pvalsLogic = pvals<plotAlpha;
                        pvalSum = sum(pvalsLogic,2);
                        sigUnits = pvalSum>0;
                    end
            % 
            
                    parfor stimDur = 1:numel(uStimTypes)
                       
                        g{stimDur} = figure('Name', [uGenotypes{genotype} ' ' uRecSites{recSite} ' ' uStimTypes{stimDur} ' ms'],'NumberTitle','off'); clf;
                        g{stimDur}.WindowState = 'maximized';
                        meanFR{stimDur} = allMeanFR{stimDur};
                        
                        meanFR{stimDur} = SignifyFR(meanFR{stimDur}, allpvals, sigUnits, plotAlpha, 7);
            
                        
                        meanFR{stimDur} = sortrows(meanFR{stimDur},6);
                    
                        % adc and maxAadc
                        plotRows = max(3,ceil(height(meanFR{stimDur})/10));
                        for unitNum = 1:size(meanFR{stimDur},1)
                            
                            
                        
                            
                            %sort each meanFR cell by depth
                           
                            h = subplot(plotRows,10,unitNum, 'Parent', g{stimDur});
                                  
                            hold(h, 'on');
                            
                                
                            plot(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 2}, ...
                                color{1}, 'LineWidth', 1);
                            plot(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 4}, ...
                                color{2}, 'LineWidth', 1);
                                
                            if ~isempty(meanFR{stimDur}{unitNum, 2})
                                
                                MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 2}, meanFR{stimDur}{unitNum, 3}(2,:), ...
                                    meanFR{stimDur}{unitNum, 3}(1,:), 'color',color{1}, 'Alpha', 0.3, 'IsRelative', false);                        
                                
                            end
            
                            if ~isempty(meanFR{stimDur}{unitNum, 4})
                                
                                MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 4}, meanFR{stimDur}{unitNum, 5}(2,:), ...
                                    meanFR{stimDur}{unitNum, 5}(1,:), 'color',color{2}, 'Alpha', 0.3, 'IsRelative', false);
                                                        
                            end
                        
                            yLimits = get(gca,'YLim');
                                
                            %continue here
                           plot(adcFinal{stimDur}(1,:), (adcFinal{stimDur}(2,:)*fM) +  yLimits(2), ...
                                'k', 'lineWidth', 1);
                            yLimits = get(gca,'YLim');
                            MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
            %                 xlabel('epoch time (s)');
            %                 ylabel('FR');  
                            yLimits = get(gca,'YLim');
                            ylim([0, yLimits(2)]);
                            xlim(plotLims{stimDur});
                           
                            title([num2str(meanFR{stimDur}{unitNum,6}) ' \mum']);
                    
                            box off  
                            outerpos = get(h,'OuterPosition');
                            ti = get(h,'TightInset');
                            left = outerpos(1) + ti(1);
                            bottom = outerpos(2) + ti(2);
                            ax_width = outerpos(3) - ti(1) - ti(3);
                            ax_height = outerpos(4) - ti(2) - ti(4)-0.01;
                            set(h,'Position',[left bottom ax_width ax_height], 'fontsize', 10);     
                            hold(h, 'off');
                            
            
                        end
            %             title([uGenotypes{genotype} ' ' uRecSites{recSite} ' ' stimDurs{stimDur} ' ms'])
                        hold off
                        
                        savePath2 = [savePath ' allpvals =  ' num2str(allpvals)];
                       
                        if ~exist('savePath2', 'dir')
                            mkdir(savePath2);
                        end
    
                       
            
                        savefig(g{stimDur},fullfile(savePath2,  [uGenotypes{genotype} ' ' uRecSites{recSite} ' ' uStimTypes{stimDur} ' ms duration significant units.fig']));
                    end
            
                   
            end    
        
        end
    
    end

end

function PlotSignificantRasterUnitsSigperStimDur(dataFileTb, ops)
    defPenetrationDepth = ops.defPenetrationDepth;
    trials{1} = ops.trials{1};
    trials{2} = ops.trials{2}; 
    statAlpha = ops.statAlpha;
    plotAlpha = ops.plotAlpha;
    binSize = ops.binSize;
    tWins = ops.tWins;
    allpvals = ops.allpvals;
    inputrecSites = ops.recSites;
    savePath = ops.savePath;
    universalWindow = ops.universalWindow;
    redo = ops.redo;
    animalID = dataFileTb.MouseName;
    uniAnimalId = unique(animalID);
    uRecSites = unique(dataFileTb.recSite);
    
    
    
    recSites = dataFileTb.recSite;
    readPaths= dataFileTb.sePath;
    uGenotypes = unique(dataFileTb.Genotype);
    genotypes = dataFileTb.Genotype;
    

    bins = tWins(1):binSize:tWins(2);

    %
    for genotype = 1:numel(uGenotypes)
        for recSite = 1:numel(inputrecSites)
            
            recSitePaths = cell2mat(cellfun(@(x) sum(ismember(x, inputrecSites{recSite}))==2, recSites, 'UniformOutput',false));
            recReadPaths = readPaths(recSitePaths & strcmp(uGenotypes(genotype), genotypes));
            if ~universalWindow
                if sum(ismember(inputrecSites{recSite}, 'M1'))==2
                    winAdd = ops.wM1winadd;
                elseif sum(ismember(inputrecSites{recSite}, 'S1'))==2
                    winAdd = 0.0;
                else
                     winAdd = 0.05;
                end
            else             
                     winAdd = 0.00;
            end
            
            if ~exist([savePath '\allVars' uGenotypes{genotype} inputrecSites{recSite} '.mat'], 'file') || redo
                
                if ~isempty(recReadPaths)
                    
                    
                    close all;
                    
                    allSpikeTimes = cell(1,12);
                    pvals = cell(1,12);
                    adcFinal = cell(1,12);
                    bodysidefinal=cell(1,12);
                    for sessNum = 1:numel(recReadPaths)
    
    %                     if sessNum ==2
    %                         keyboard;
    %                     end
                        load(recReadPaths{sessNum});
                        sessRecSite = cell2mat(se.userData.sessionInfo.recSite);
                        meanFR = cell(1,6);
                        adcAll = cell(1,6);
                        
                    
                        fprintf('%s\n\n', recReadPaths{sessNum});
                        tRef = se.GetReferenceTime();
                        check = diff(tRef);
                    
                        if any(check<0)
                            disp('tRefs are not monotonically increasing');
                        end                  
                        
                        % remove skipped trials  
                        behavData = se.GetTable('behavValue');                   
                        responses = behavData.response;
                        abortTrials = find(cell2mat(responses) == 3);        
                        se = BS.Preprocess.removeTrials(abortTrials,se);
                        behavData = se.GetTable('behavValue');
                        
                        
                        % remove not miss error trials
                        responses = behavData.response;           
                        keepTrials = find(cell2mat(responses));                    
                        se = BS.Preprocess.removeTrials(keepTrials,se);
                        
                        
    
                         try            
                            trialMap = se.userData.sessionInfo.APStim;
                        catch
                            trialMap{1} = [];
                        end
        
                        if ~isempty(trialMap{1})
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
                            
        %                     allTrials = 1:se.numEpochs;
        %                     removeTrials = find(~ismember(allTrials, trialInd));
        %                     se = BS.Preprocess.removeTrials(removeTrials,se);
                         end
    
                        %get different stim types                    
                        leftStimTypes = se.GetColumn('behavValue', 'leftStimType');
                        rightStimTypes =  se.GetColumn('behavValue', 'rightStimType');
                        
                        leftStimTypes = leftStimTypes(trialInd); 
                        
                        rightStimTypes = rightStimTypes(trialInd); 
        
                        %get left and right stim types
                        behavData = se.GetTable('behavValue');
                        behavData = behavData(trialInd,:); 
                        behavData(1,:) = [];
                        leftStimTypes(1,:) = [];                
                        rightStimTypes(1,:) = [];
                    
        
        
                        % slice firing rate with tWins
                        frAll= se.SliceTimeSeries('spikeRate', tWins, 'Fill', 'bleed');
                        frAll = frAll(trialInd,:);
                        frAll(1,:) = [];
                        frAll = table2cell(frAll);
                        frAll = cellfun(@(x) x', frAll, 'UniformOutput',false);              
                        
                        
                        % get spikeTimes                     
                        spikeAll= se.SliceEventTimes('spikeTime', tWins, 'Fill', 'bleed');
                        spikeAll = spikeAll(trialInd,:);
                        spikeAll(1,:) = [];
                        spikeAll = table2cell(spikeAll);
                        spikeAll = cellfun(@(x) x', spikeAll, 'UniformOutput',false);   
                        
                        % get adcAll
                        adcAll = se.SliceTimeSeries('adc', tWins, 'Fill', 'bleed');
                        adcAll = adcAll(trialInd,:);
                        adcAll(1,:) = [];
                        adcAllLeft = adcAll.leftStim;
                        adcAllTime = adcAll.time;
                        
                        adcAllLeft = cellfun(@transpose, adcAllLeft,'UniformOutput', false);
                        adcAllTime = cellfun(@transpose, adcAllTime,'UniformOutput', false);    
                       
                         
                       
                        
        
                        try
                            unitChanDepth = se.userData.spikeInfo.quality_metrics.depth;
                        catch
                            chanDepth = 0:20:1260; %(in um)
                            channelInds = se.userData.spikeInfo.unit_channel_ind;
                            unitChanDepth= chanDepth(channelInds);
                    
                        end
                        
                        stimTypes = leftStimTypes;
                        uStimTypes = unique(stimTypes);
                        ufreq = unique(cellfun(@(x) x(5:6),uStimTypes, 'UniformOutput', false)); % for gettign just the unique frequencies irrespective of the cycles
                        
                        
                        adc = cell(1,numel(ufreq));
                        
    
                        sessInfoTable = se.userData.sessionInfo;
    
                        if ismember('penetrationDepth', sessInfoTable.Properties.VariableNames)
                            penetrationDepth = sessInfoTable.penetrationDepth;
                        else
                            penetrationDepth = defPenetrationDepth;
                        end
                        
                        % for all the stimDurs
                       for stimDur = 1:numel(ufreq)
                            
                             if numel(ufreq)<3
                                
                                pstimDur = stimDur +1;
                                bodyside7 =1;
                            else
                                bodyside7 =0;
                                pstimDur = stimDur;
                             end     
        
                          
                            
        %                     freq = str2num(uStimTypes{stimDur}(5:6));
        %                     cycs = str2num(uStimTypes{stimDur}(10));
        %                     windowSize{stimDur} = 1/freq * cycs;
                            %get FR for both trialType and current stimDue
        %                     windowSize{stimDur} = max(50/1000,str2num(stimDurs{stimDur})/1000); %in s 
        %                     windowSize{stimDur} = 50/1000;
                            if ~universalWindow
                                try 
                                    windowSize{stimDur} = 1/str2double(ufreq{stimDur})+winAdd; %in s 
                                catch
                                    windowSize{stimDur} = findDuration(uStimTypes{stimDur})+winAdd; %in s 
                                end
                            else
                                windowSize{stimDur} = ops.constantWindow;
                            end
                            
    
                            binsWin{stimDur} = find(bins>= -windowSize{stimDur} & bins<= windowSize{stimDur});
                            plotLims{stimDur} = [-windowSize{stimDur}, windowSize{stimDur}]
                            temp = binsWin{stimDur};
                            try
                                frAllwin{stimDur} = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                            catch                            
                                errorTrials = find(cell2mat(cellfun(@(x) numel(x)< temp(end), frAll(:,1), 'UniformOutput',false)));
                                behavData(errorTrials,:) =[];
                                frAll(errorTrials,:)=[];
                                spikeAll(errorTrials,:)=[];
                                frAllwin{stimDur} = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                            end
    
                            leftStimTypes = behavData.leftStimType;
                            rightStimTypes = behavData.rightStimType;
    
                           
                            
                           trials2keepL{stimDur} = find(strcmp(trials{1}{1}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(5:6),ufreq{stimDur}), ...
                                leftStimTypes, 'UniformOutput',false)));
                            trials2keepR{stimDur} = find(strcmp(trials{1}{2}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(5:6),ufreq{stimDur}), ...
                                rightStimTypes, 'UniformOutput',false)));
                            
                            FRLeft{stimDur} = frAllwin{stimDur}(trials2keepL{stimDur},2:end);
                            FRRight{stimDur} = frAllwin{stimDur}(trials2keepR{stimDur},2:end);
                           
                            
                            %get p-value based on windowsize = stim duration
                            
                            preWindow{stimDur} = 1:(round(numel(FRLeft{stimDur}{1})/2));
                            postWindow{stimDur} =  preWindow{stimDur}(end)+1: numel(FRLeft{stimDur}{1}); 
                            temp1 = preWindow{stimDur};
                            temp2 = postWindow{stimDur};
        
                            preMeanFRL{stimDur} = cell2mat(cellfun(@(x) mean(x(temp1)), FRLeft{stimDur}, 'UniformOutput', false));
                            postMeanFRL{stimDur} = cell2mat(cellfun(@(x) mean(x(temp2)), FRLeft{stimDur}, 'UniformOutput', false));
                            preMeanFRR{stimDur} = cell2mat(cellfun(@(x) mean(x(temp1)), FRRight{stimDur}, 'UniformOutput', false));
                            postMeanFRR{stimDur} = cell2mat(cellfun(@(x) mean(x(temp2)), FRRight{stimDur}, 'UniformOutput', false));
                            
                            % get spikeTimes for FRlims
                            FRlims{stimDur} = [tWins(1) tWins(2)];               
                            spikeLeft = spikeAll(trials2keepL{stimDur},1:end);
                            spikeRight = spikeAll(trials2keepR{stimDur},1:end);          
                            
        
        
                            %Get adcAll
                            temp0 = adcAllTime(trials2keepL{stimDur});
                            idcs = min(cell2mat(cellfun(@(x) numel(x), temp0, 'UniformOutput',false)));
                            temp0 = cell2mat(cellfun(@(x) x(1:idcs), temp0, 'UniformOutput', false));
                            adc{stimDur}{1,1} = MMath.MeanStats(temp0,1);
        
                            temp0 = adcAllLeft(trials2keepL{stimDur});
                            idcs = min(cell2mat(cellfun(@(x) numel(x), temp0, 'UniformOutput',false)));
                            temp0 = cell2mat(cellfun(@(x) x(1:idcs), temp0, 'UniformOutput', false));
                            adc{stimDur}{2,1} = double(MMath.MeanStats(temp0,1));                    
                            
                            adcWin = find(adcAllTime{1}>= FRlims{stimDur}(1) & adcAllTime{1}<= FRlims{stimDur}(2));
        
                            if size(adcWin,2) > numel(adc{stimDur}{2,1})
                                adcWin = adcWin(1:numel(adc{stimDur}{2,1}));
                            end
    
                            temp = adc{stimDur};
                            adc{stimDur} = cell2mat(cellfun(@(x) x(adcWin), temp, 'UniformOutput',   false));          
                            maxAdc(sessNum,stimDur) = max(adc{stimDur}(2,:));
        
                            pvalL = [];
                            pvalR = [];
                            unitDepth = [];
                            spikeTimes = {};
                            pvalstimDur =[];
                            bodysides = [];
                            parfor unitNum = 1: size(preMeanFRL{stimDur},2)
                               
    %                             [H{stimDur}(unitNum), pvalL(unitNum)] = ttest(preMeanFRL{stimDur}(:,unitNum), postMeanFRL{stimDur}(:,unitNum), ...
    %                                 'tail', 'both', 'Alpha', statAlpha);
    %                              [H{stimDur}(unitNum), pvalR(unitNum)] = ttest(preMeanFRR{stimDur}(:,unitNum), postMeanFRR{stimDur}(:,unitNum), ...
    %                                 'tail', 'both', 'Alpha', statAlpha);
                               
                                [pvalL(unitNum)] = signrank(preMeanFRL{stimDur}(:,unitNum), postMeanFRL{stimDur}(:,unitNum), ...
                                    'tail', 'both', 'Alpha', statAlpha);
                                [pvalR(unitNum)] = signrank(preMeanFRR{stimDur}(:,unitNum), postMeanFRR{stimDur}(:,unitNum), ...
                                    'tail', 'both', 'Alpha', statAlpha);
                     
                                unitDepth(unitNum) = unitChanDepth(unitNum);
                               if sum(ismember(sessRecSite, 'Left'))==4
                                    uSpikesIpsi = spikeLeft(:,unitNum);
                                    uSpikesContra = spikeRight(:,unitNum);
                                else
                                    uSpikesIpsi = spikeRight(:,unitNum);
                                    uSpikesContra = spikeLeft(:,unitNum);
                                end
                                
                                 preSpikesContra = sum(cell2mat(cellfun(@(x) numel(find(x>plotLims{stimDur}(1) & x<=0)), ...
                                    uSpikesContra, 'UniformOutput', false)));
                                postSpikesContra = sum(cell2mat(cellfun(@(x) numel(find(x>0 & x<=plotLims{stimDur}(2))), ...
                                    uSpikesContra, 'UniformOutput', false)));
                                preSpikesIpsi = sum(cell2mat(cellfun(@(x) numel(find(x>plotLims{stimDur}(1) & x<=0)), ...
                                    uSpikesIpsi, 'UniformOutput', false)));
                                postSpikesIpsi = sum(cell2mat(cellfun(@(x) numel(find(x>0 & x<=plotLims{stimDur}(2))), ...
                                    uSpikesIpsi, 'UniformOutput', false)));
                                pvalstimDur(unitNum) = min(pvalL(unitNum), pvalR(unitNum));   
                                
                                C = abs(postSpikesContra - preSpikesContra);
                                I = abs(postSpikesIpsi - preSpikesIpsi);
    
                                Cbias = (C-I)/(C+I);
                                spikeTimes(unitNum,:) = {uSpikesIpsi, uSpikesContra,...
                                        penetrationDepth-unitDepth(unitNum), min(pvalL(unitNum), pvalR(unitNum)), Cbias};
                                bodysides(unitNum) = bodyside7;
                            end
                            
                            pvals{pstimDur}(end+1:end+numel(pvalstimDur)) = pvalstimDur';
                            bodysidefinal{pstimDur}(end+1:end+numel(bodysides)) = bodysides;
                            
    %                         if bodyside7
    %                             pvals{1}(end+1:end+numel(pvalstimDur)) = ones(1,numel(pvalstimDur));
    %                             pvals{3}(end+1:end+numel(pvalstimDur)) = ones(1,numel(pvalstimDur));
    %                             pvals{4}(end+1:end+numel(pvalstimDur)) = ones(1,numel(pvalstimDur));
    %                             
    %                         end
                            adcFinal{pstimDur}(end+1:end+size(adc{stimDur},1),1:size(adc{stimDur},2)) = adc{stimDur};
                            allSpikeTimes{pstimDur}(end+1:end+size(spikeTimes,1),:) = spikeTimes;  
        
                            
                       end
    
                       
                      
                     
                           
                            
                    end
        
        
                else
                    continue;
                end
    
    
    %             clearvars -except ops allSpikeTimes maxAdc pvals plotAlpha ufreq uGenotypes inputrecSites adcFinal savePath plotLims genotype recSite recSites genotypes
    % 
                if ~exist(savePath, 'dir')
                    mkdir(savePath);
                end
                save([savePath '\allVars' uGenotypes{genotype} inputrecSites{recSite} '.mat']);
    
                
            end
            load([savePath '\allVars' uGenotypes{genotype} inputrecSites{recSite} '.mat']);
            % plot allMeanFR for all the stimDur
            [maxadcfig rows] = max(maxAdc(1,:));
             if maxadcfig <0.1
                fM = 10e4;
%                 fM = 1;
            else
                fM =1;
                
            end
            
            maxadcfig = maxadcfig*fM; 
            close all

            % done for left as the first one and right as the second
            % spikeTimes
            color = {'b', 'r'};
        
            
            

            for allpvals = 0:ops.allpvals
                spikeTimes ={};
                sigUnits = {};
                
                if allpvals
                    
                   
                    sessions7 = find(bodysidefinal{2}==1);

                    sessions8 = find(bodysidefinal{2}==0);
                    if ~isempty(sessions7)
                        
                        pvalsfake{1,1}(sessions7) = zeros(size(sessions7));
                        pvalsfake{1,1}(sessions8) = pvals{1,1};
                        pvalsfake{1,3}(sessions7) = zeros(size(sessions7));
                        pvalsfake{1,3}(sessions8) = pvals{1,3};
                        pvalsfake{1,4}(sessions7) = zeros(size(sessions7));
                        pvalsfake{1,4}(sessions8) = pvals{1,4};
                        pvalsfake{1,2} = pvals{1,2};
                        pvals = pvalsfake;
                    end
                    
                    % need to get the 20hz only sessions out.  
                    pvals = cellfun(@(x) x', pvals, 'UniformOutput', false);
                    

                    pvals2 = cell2mat(pvals);
                    pvalsLogic = pvals2<plotAlpha;
                    pvalsLogic = pvalsLogic(:,1:3);
                    pvalSum = sum(pvalsLogic,2);
                    sigUnits = pvalSum>0;
                    
                else
                    sessions7 =[];
                end
                
                parfor stimDur = 1:numel(ufreq)
                   % creat uifigure
                    g{stimDur} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz'],'NumberTitle','off'); clf;
%                     g{stimDur} = uifigure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz'], 'Scrollable','on'); 
%                     g{stimDur}.WindowState = 'maximized';
                    
                    % Create a uipanel as the container with scrollbars
%                     tabGroup{stimDur} = uitabgroup(g{stimDur});
                    spikeTimes{stimDur} = allSpikeTimes{stimDur};
                    
                    spikeTimes{stimDur} = SignifyFR(spikeTimes{stimDur}, allpvals, sigUnits, plotAlpha, 4, sessions7, stimDur);
    
                    
                    spikeTimes{stimDur} = sortrows(spikeTimes{stimDur},3);
                    
                    % Set the number of subplots and rows
                    % Define the number of panels and their rows/columns
%                     panelRows = 10;
%                     panelCols = 10;
%                     numPanels = ceil(height(spikeTimes{stimDur})/(panelRows*panelCols));  % You can adjust this as needed

                    % Define the number of subplots in each panel
%                     numSubplotsPerPanel = 100;
                    % adc and maxAadc
                    plotRows = max(3,ceil(height(spikeTimes{stimDur})/10));

                    % Loop to create subplots in sections
%                     for panelIndex = 1:numPanels
                        % Create a smaller uipanel within the container for each section
%                         sectionPanel{stimDur} = uipanel(container{stimDur}, 'Title', 'section', ...
%                             'Position', [0 1-hh/numSubplots 1 1/numSubplots], 'BorderType', 'none', 'AutoResizeChildren', 'off');
                         % Create a new tab for each panel
%                         tab{stimDur} = uitab(tabGroup{stimDur}, 'Title', ['Panel ', num2str(panelIndex)]);

                        % Create a uipanel within the tab
%                         panel = uipanel(tab{stimDur}, 'Position', [0 0 1 1], 'BorderType', 'none', 'AutoResizeChildren', 'off');
%                         panel.Scrollable = 'on';
% 
%                          % Calculate the number of subplots in the current panel
%                         numSubplotsInPanel = min(numSubplotsPerPanel, panelRows * panelCols);
    
                        % Create subplots within each section
%                         for j = 0:numRows-1
                        for unitNum =1:height(spikeTimes{stimDur})
%                             unitNum = j*numCols + 1;
%                             h = subplot(numRows, numCols, unitNum, 'Parent', panel);
%                             hold on
%                             parentFigure = get(h, 'Parent');
%                             if parentFigure == sectionPanel{stimDur}
%                                 disp('The parent of the subplot is the sectionPanel.');
%                             end
%                             
                            %sort each meanFR cell by depth
                           
                            h = subplot(plotRows,10,unitNum, 'Parent', g{stimDur});
                                  
                            hold(h, 'on');
                            % plot left trials
                            for i = 1: height(spikeTimes{stimDur}{unitNum,1})
                                MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,1}{i}, i*ones(numel(spikeTimes{stimDur}{unitNum,1}{i}),1) ,1, 'orientation', 'vertical', ...
                                    'linestyle', '-','color', color{1}, 'linewidth', 1);
                            end

%                             parentFigure = get(gg, 'Parent');
%                             if parentFigure == h
%                                 disp('The parent of the reater is the subplot h.');
%                             end
                            totalTrials = height(spikeTimes{stimDur}{unitNum,2})+ height(spikeTimes{stimDur}{unitNum,1});
                            xLimits = get(gca,'XLim');
                            MPlot.PlotPointAsLine(0,i+1,xLimits(2), 'orientation', 'horizontal', 'linestyle', '--', ...
                                'color',[0 0 0], 'linewidth', 1);
                            % plot right trials
                            for i = 1+height(spikeTimes{stimDur}{unitNum,1}): totalTrials
                                rInd = i  -height(spikeTimes{stimDur}{unitNum,1});
                                MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,2}{rInd}, (i+1)*ones(numel(spikeTimes{stimDur}{unitNum,2}{rInd}),1) ,1, 'orientation', 'vertical', ...
                                    'linestyle', '-','color', color{2}, 'linewidth', 1);
                            end
                                
                            
                                
            %                 ylim([0, height(spikeTimes{stimDur}{unitNum,1}) + height(spikeTimes{stimDur}{unitNum,2})])
                        
                            yLimits = get(gca,'YLim');
                                
                            
                            plot(adcFinal{stimDur}(1,:), (adcFinal{stimDur}(2,:)*fM) +  totalTrials+5+1, ...
                                'k', 'lineWidth', 1);
                            
                            yLimits = get(gca,'YLim');
                            MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--', ...
                                'color',[0.5 0.5 0.5], 'linewidth', 1);
        %                     xlabel('epoch time (s)');
        %                     ylabel('Trials');  
                            yLimits = get(gca,'YLim');
                            ylim([0, yLimits(2)])
                            xlim(plotLims{stimDur});
                            
                            title({[num2str(spikeTimes{stimDur}{unitNum,3}) ' \mum']},{['Cbias = '  num2str(spikeTimes{stimDur}{unitNum,5})]});
                    
                            box off  
                            outerpos = get(h,'OuterPosition');
                            ti = get(h,'TightInset');
                            left = outerpos(1) + ti(1);
                            bottom = outerpos(2) + ti(2);
                            ax_width = outerpos(3) - ti(1) - ti(3);
                            ax_height = outerpos(4) - ti(2) - ti(4)-0.01;
                            set(h,'Position',[left bottom ax_width ax_height], 'fontsize', 10);
                            
                            hold(h, 'off');
                        
                
        
                        end
%                     end
    %                 title([uGenotypes{genotype} ' ' uRecSites{recSite} ' ' stimDurs{stimDur} ' ms'])
                    hold off

                    savePath2 = [savePath ' allpvals =  ' num2str(allpvals)];

                    if ~exist(savePath2, 'dir')
                        mkdir(savePath2);
                    end

                   
                
                    savefig(g{stimDur},fullfile(savePath2,  [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz significant units_rasters.fig']));
                    saveas(g{stimDur},fullfile(savePath2,  [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz significant units_rasters.png']));
                end
        
               
            end
        
        end
    
    end

end

% function MakeFigures(allVars)
%     % plot allMeanFR for all the stimDur
%     load(allVars);
%     
%     keyboard;
%     [maxadcfig rows] = max(maxAdc(1,:));
%      if maxadcfig <0.1
%         fM = 10e4;
% %                 fM = 1;
%     else
%         fM =1;
%         
%     end
%     
%     maxadcfig = maxadcfig*fM; 
%     close all
% 
%     % done for left as the first one and right as the second
%     % spikeTimes
%     color = {'b', 'r'};
% 
%     
%     
% 
%     for allpvals = 0:ops.allpvals
%         spikeTimes ={};
%         sigUnits = {};
%         
%         if allpvals
%             pvals = cell2mat(cellfun(@(x) x, pvals, 'UniformOutput', false));
%             pvalsLogic = pvals<plotAlpha;
%             pvalsLogic = pvalsLogic(:,1:3);
%             pvalSum = sum(pvalsLogic,2);
%             sigUnits = pvalSum>0;
% 
%             keyboard;
%         end
%         
%         parfor stimDur = 1:numel(ufreq)
%            % creat uifigure
%             g{stimDur} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz'],'NumberTitle','off'); clf;
% %                     g{stimDur} = uifigure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz'], 'Scrollable','on'); 
% %                     g{stimDur}.WindowState = 'maximized';
%             
%             % Create a uipanel as the container with scrollbars
% %                     tabGroup{stimDur} = uitabgroup(g{stimDur});
%             spikeTimes{stimDur} = allSpikeTimes{stimDur};
%             
%             spikeTimes{stimDur} = SignifyFR(spikeTimes{stimDur}, allpvals, sigUnits, plotAlpha, 4);
% 
%             
%             spikeTimes{stimDur} = sortrows(spikeTimes{stimDur},3);
%             
%             % Set the number of subplots and rows
%             % Define the number of panels and their rows/columns
% %                     panelRows = 10;
% %                     panelCols = 10;
% %                     numPanels = ceil(height(spikeTimes{stimDur})/(panelRows*panelCols));  % You can adjust this as needed
% 
%             % Define the number of subplots in each panel
% %                     numSubplotsPerPanel = 100;
%             % adc and maxAadc
%             plotRows = max(3,ceil(height(spikeTimes{stimDur})/10));
% 
%             % Loop to create subplots in sections
% %                     for panelIndex = 1:numPanels
%                 % Create a smaller uipanel within the container for each section
% %                         sectionPanel{stimDur} = uipanel(container{stimDur}, 'Title', 'section', ...
% %                             'Position', [0 1-hh/numSubplots 1 1/numSubplots], 'BorderType', 'none', 'AutoResizeChildren', 'off');
%                  % Create a new tab for each panel
% %                         tab{stimDur} = uitab(tabGroup{stimDur}, 'Title', ['Panel ', num2str(panelIndex)]);
% 
%                 % Create a uipanel within the tab
% %                         panel = uipanel(tab{stimDur}, 'Position', [0 0 1 1], 'BorderType', 'none', 'AutoResizeChildren', 'off');
% %                         panel.Scrollable = 'on';
% % 
% %                          % Calculate the number of subplots in the current panel
% %                         numSubplotsInPanel = min(numSubplotsPerPanel, panelRows * panelCols);
% 
%                 % Create subplots within each section
% %                         for j = 0:numRows-1
%                 for unitNum =1:height(spikeTimes{stimDur})
% %                             unitNum = j*numCols + 1;
% %                             h = subplot(numRows, numCols, unitNum, 'Parent', panel);
% %                             hold on
% %                             parentFigure = get(h, 'Parent');
% %                             if parentFigure == sectionPanel{stimDur}
% %                                 disp('The parent of the subplot is the sectionPanel.');
% %                             end
% %                             
%                     %sort each meanFR cell by depth
%                    
%                     h = subplot(plotRows,10,unitNum, 'Parent', g{stimDur});
%                           
%                     hold(h, 'on');
%                     % plot left trials
%                     for i = 1: height(spikeTimes{stimDur}{unitNum,1})
%                         MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,1}{i}, i*ones(numel(spikeTimes{stimDur}{unitNum,1}{i}),1) ,1, 'orientation', 'vertical', ...
%                             'linestyle', '-','color', color{1}, 'linewidth', 1);
%                     end
% 
% %                             parentFigure = get(gg, 'Parent');
% %                             if parentFigure == h
% %                                 disp('The parent of the reater is the subplot h.');
% %                             end
%                     totalTrials = height(spikeTimes{stimDur}{unitNum,2})+ height(spikeTimes{stimDur}{unitNum,1});
%                     xLimits = get(gca,'XLim');
%                     MPlot.PlotPointAsLine(0,i+1,xLimits(2), 'orientation', 'horizontal', 'linestyle', '--', ...
%                         'color',[0 0 0], 'linewidth', 1);
%                     % plot right trials
%                     for i = 1+height(spikeTimes{stimDur}{unitNum,1}): totalTrials
%                         rInd = i  -height(spikeTimes{stimDur}{unitNum,1});
%                         MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,2}{rInd}, (i+1)*ones(numel(spikeTimes{stimDur}{unitNum,2}{rInd}),1) ,1, 'orientation', 'vertical', ...
%                             'linestyle', '-','color', color{2}, 'linewidth', 1);
%                     end
%                         
%                     
%                         
%     %                 ylim([0, height(spikeTimes{stimDur}{unitNum,1}) + height(spikeTimes{stimDur}{unitNum,2})])
%                 
%                     yLimits = get(gca,'YLim');
%                         
%                     
%                     plot(adcFinal{stimDur}(1,:), (adcFinal{stimDur}(2,:)*fM) +  totalTrials+5+1, ...
%                         'k', 'lineWidth', 1);
%                     
%                     yLimits = get(gca,'YLim');
%                     MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--', ...
%                         'color',[0.5 0.5 0.5], 'linewidth', 1);
% %                     xlabel('epoch time (s)');
% %                     ylabel('Trials');  
%                     yLimits = get(gca,'YLim');
%                     ylim([0, yLimits(2)])
%                     xlim(plotLims{stimDur});
%                     
%                     title({[num2str(spikeTimes{stimDur}{unitNum,3}) ' \mum']},{['Cbias = '  num2str(spikeTimes{stimDur}{unitNum,5})]});
%             
%                     box off  
%                     outerpos = get(h,'OuterPosition');
%                     ti = get(h,'TightInset');
%                     left = outerpos(1) + ti(1);
%                     bottom = outerpos(2) + ti(2);
%                     ax_width = outerpos(3) - ti(1) - ti(3);
%                     ax_height = outerpos(4) - ti(2) - ti(4)-0.01;
%                     set(h,'Position',[left bottom ax_width ax_height], 'fontsize', 10);
%                     
%                     hold(h, 'off');
%                 
%         
% 
%                 end
% %                     end
% %                 title([uGenotypes{genotype} ' ' uRecSites{recSite} ' ' stimDurs{stimDur} ' ms'])
%             hold off
% 
%             savePath2 = [savePath ' allpvals =  ' num2str(allpvals)];
% 
%             if ~exist(savePath2, 'dir')
%                 mkdir(savePath2);
%             end
% 
%            
%         
%             savefig(g{stimDur},fullfile(savePath2,  [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz significant units_rasters.fig']));
%         end
% 
%        
%     end
% end

