


%% Plot units separated by whisker stim duration. Contra vs ipsi, combine for left vs right hemisphere recording
% clear all
% 
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\StimSEs', 'Select source SEs');

clear all
animalID = {'VC030109','VC030112', 'VC030402','VC030209','VC030206', 'VC030401', 'VC030208', 'VC030407'};
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
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\firstcyc',[strjoin(animalIds, '_') '_NP\AllUnits',FRbin], [num2str(ops.statAlpha) 'nonparametric']);
end



% plot Rasters
PlotSignificantRasterUnitsSigperStimDur(dataFileTb, ops);


%% Just make figures
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
ops.wM1winadd = 0.05; 
ops.binWidth =0.05;
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
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\firstcyc',[strjoin(animalIds, '_') '_NP\AllUnits',FRbin], [num2str(ops.statAlpha) ' UniveralWindow trialBased' ]);
else
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\firstcyc',[strjoin(animalIds, '_') '_NP\AllUnits',FRbin], [num2str(ops.statAlpha) 'nonparametric']);
end


if exist(fullfile(ops.savePath, "allVars.mat"), 'file')

    MakeFigures(fullfile(ops.savePath, "allVars.mat"), ops.binWidth);
   
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

function x = findDurationFirstCyc(stimType)
    freq = str2num(stimType(5:6));
    cycs = str2num(stimType(10));
    x = 1/freq;
end


function meanFR = SignifyFR(meanFR, allpvals, sigUnits,statAlpha, column)
    if allpvals
        meanFR(~sigUnits,:) = [];
    else
        sigUnits = cell2mat(cellfun(@(x) x< statAlpha, meanFR(:,column), 'UniformOutput',false));
        meanFR(~sigUnits,:) = [];
    end
            
end

function PlotSignificantRasterUnitsSigperStimDur(dataFileTb, ops)
    defPenetrationDepth = ops.defPenetrationDepth;
    trials{1} = ops.trials{1};
    trials{2} = ops.trials{2}; 
    statAlpha = ops.statAlpha;
    binSize = ops.binSize;
    tWins = ops.tWins;
    inputrecSites = ops.recSites;
    savePath = ops.savePath;
    universalWindow = ops.universalWindow;
   
    animalID = dataFileTb.MouseName;
    
    
    
    recSites = dataFileTb.recSite;
    readPaths= dataFileTb.sePath;
    uGenotypes = unique(dataFileTb.Genotype);
    genotypes = dataFileTb.Genotype;
    

    bins = tWins(1):binSize:tWins(2);

    %
    for genotype = 1:numel(uGenotypes)
        for recSite = 1:numel(inputrecSites)
            
            recSitePaths = cell2mat(cellfun(@(x) sum(ismember(x, inputrecSites{recSite}))==2, recSites, 'UniformOutput',false));
            finalrecSites(recSite) = any(cell2mat(cellfun(@(x) sum(ismember(x, inputrecSites{recSite}))==2, recSites, 'UniformOutput',false)));
            recReadPaths = readPaths(recSitePaths & strcmp(uGenotypes(genotype), genotypes));
            if ~universalWindow
                if sum(ismember(inputrecSites{recSite}, 'M1'))==2
                    winAdd = ops.wM1winadd;
                elseif sum(ismember(inputrecSites{recSite}, 'S1'))==2
                    winAdd = 0.00;
                else
                     winAdd = 0.05;
                end
            else             
                     winAdd = 0.05;
            end
            
            
            if ~isempty(recReadPaths)
                
                
                close all;
                
                allSpikeTimes = cell(1,12);
                bodysidefinal=cell(1,12);
                adcFinal = cell(1,12);

                for sessNum = 1:numel(recReadPaths)
                    
                    load(recReadPaths{sessNum});
                    sessRecSite = cell2mat(se.userData.sessionInfo.recSite);
                    
                   
                
                    fprintf('%s\n\n', recReadPaths{sessNum});
                    tRef = se.GetReferenceTime();
                    check = diff(tRef);
                
                    if any(check<0)
                        disp('tRefs are not monotonically increasing');
                    end                  
                    
                    
                    behavData = se.GetTable('behavValue');                   
                    responses = behavData.response;
                    abortTrials = find(cell2mat(responses) == 3);        
                    se = BS.Preprocess.removeTrials(abortTrials,se);
                    behavData = se.GetTable('behavValue');
                    
                    
                
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
                    
                    % get spikeTimes                     
                    spikeAll= se.SliceEventTimes('spikeTime', tWins, 'Fill', 'bleed');
                    spikeAll = spikeAll(trialInd,:);
                    spikeAll(1,:) = [];
                    spikeAll = table2cell(spikeAll);
                    spikeAll = cellfun(@(x) x', spikeAll, 'UniformOutput',false);   
                    
                    
                   
                   
                     
                   
                    
    
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
                    
                   

                    sessInfoTable = se.userData.sessionInfo;

                    if ismember('penetrationDepth', sessInfoTable.Properties.VariableNames)
                        penetrationDepth = sessInfoTable.penetrationDepth;
                    else
                        penetrationDepth = defPenetrationDepth;
                    end

                    % for all the stimDurs
                   for stimDur = 1:numel(ufreq)

                        if numel(ufreq)<4
                            
                            pstimDur = stimDur +1;
                        else
                           
                            pstimDur = stimDur;
                        end
                             
    
                        
                        
    %                     freq = str2num(uStimTypes{stimDur}(5:6));
    %                     cycs = str2num(uStimTypes{stimDur}(10));
    %                     windowSize{stimDur} = 1/freq * cycs;
                        %get FR for both trialType and current stimDue
    %                     windowSize{stimDur} = max(50/1000,str2num(stimDurs{stimDur})/1000); %in s 
    %                     windowSize{stimDur} = 50/1000;
                        try 
                            windowSize{stimDur} = 1/str2double(ufreq{stimDur})+winAdd; %in s 
                        catch
                            windowSize{stimDur} = findDuration(ufreq{stimDur})+winAdd; %in s 
                        end
                        

                        binsWin{stimDur} = find(bins>= -windowSize{stimDur} & bins<= windowSize{stimDur});
                        plotLims{stimDur} = [-windowSize{stimDur}, windowSize{stimDur}];
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
    
    
                        
    
                        pvalL = [];
                        pvalR = [];
                        unitDepth = [];
                        spikeTimes = {};
                        pvalstimDur =[];
                        sigUnitNum = 1;


                        for unitNum = 1: size(preMeanFRL{stimDur},2)
                            
%                             [H{stimDur}(unitNum), pvalL(unitNum)] = ttest(preMeanFRL{stimDur}(:,unitNum), postMeanFRL{stimDur}(:,unitNum), ...
%                                 'tail', 'both', 'Alpha', statAlpha);
%                              [H{stimDur}(unitNum), pvalR(unitNum)] = ttest(preMeanFRR{stimDur}(:,unitNum), postMeanFRR{stimDur}(:,unitNum), ...
%                                 'tail', 'both', 'Alpha', statAlpha);
                           
                            [pvalL(unitNum)] = signrank(preMeanFRL{stimDur}(:,unitNum), postMeanFRL{stimDur}(:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);
                             [pvalR(unitNum)] = signrank(preMeanFRR{stimDur}(:,unitNum), postMeanFRR{stimDur}(:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);

%                             if pvalL(unitNum)<statAlpha || pvalR(unitNum)<statAlpha
                                
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
                                
                                C = abs(postSpikesContra - preSpikesContra);
                                I = abs(postSpikesIpsi - preSpikesIpsi);
                                
%                                 if C <= height(uSpikesContra) && I <= height(uSpikesIpsi)
%                                 if C >10 || I >10
                                    

                                    Cbias = (C-I)/(C+I);
                                    
                                    unitDepth(unitNum) = unitChanDepth(unitNum);
                                    
                                    Cbiastable{pstimDur}{genotype}{recSite}{sessNum}(unitNum,:) = {Cbias, ...
                                        penetrationDepth-unitDepth(unitNum), min(pvalL(unitNum), pvalR(unitNum))};
                                    
%                                     sigUnitNum = sigUnitNum+1;
%                                 end
%                             end
                            
                        end
                        try
                            if exist( 'Cbiastable','var') && sigUnitNum>1
                                sessCBiasNum{pstimDur}{genotype}{recSite}(1,sessNum) = numel(find(cell2mat(Cbiastable{pstimDur}{genotype}{recSite}{sessNum}(:,1))>0));
                                sessCBiasNum{pstimDur}{genotype}{recSite}(2,sessNum) = numel(find(cell2mat(Cbiastable{pstimDur}{genotype}{recSite}{sessNum}(:,1))<0));
                                sessCBiasNum{pstimDur}{genotype}{recSite}(3,sessNum) = numel(find(cell2mat(Cbiastable{pstimDur}{genotype}{recSite}{sessNum}(:,1))==0));
                            else
                                sessCBiasNum{pstimDur}{genotype}{recSite}(1,sessNum) = 0;
                                sessCBiasNum{pstimDur}{genotype}{recSite}(2,sessNum) = 0;
                                sessCBiasNum{pstimDur}{genotype}{recSite}(3,sessNum) = 0;
                            end
                        catch
                            keyboard;
                        end
    
                        
                   end
                   
                 
                       
                        
                end
    
    
            else
                continue;
            end
            
        
        end
    
    end
    
    
    finalrecSites = inputrecSites(finalrecSites);
    if ~exist(savePath, 'dir')
        mkdir(savePath);
    end
    
    save([savePath '\cbias.mat'], "Cbiastable", '-v7.3'); 
    save([savePath '\sesscbiasnum.mat'], "sessCBiasNum", '-v7.3'); 
    clearvars -except sessCBiasNum Cbiastable finalrecSites uGenotypes dataFileTb savePath ufreq ops
    save([savePath '\allVars.mat'])
    
    close all   
    
    MakeFigures([savePath '\allVars.mat'], ops.binWidth);
    
end

function MakeFigures(allVars, binWidth)
    load(allVars);
    close all   
    
    for stimDur =1:numel(ufreq)
        g1 = figure(3*stimDur-2);clf;
        
        g2 = figure(3*stimDur-1);clf;
        g3 = figure(3*stimDur); clf;

        maxunits = 0;
        for genotype = numel(Cbiastable{stimDur}):-1:1 
            
            for recsite =1:numel(finalrecSites)
                getCbiasTable = Cbiastable{stimDur}{genotype}{recsite};
                zeroSess = cellfun(@isempty, getCbiasTable);
                getCbiasTable = getCbiasTable(~zeroSess);
                getCbiasTable = cellfun(@cell2mat, getCbiasTable, 'UniformOutput', false);
                getCbiasTable = cell2mat(getCbiasTable');

                getSessbiasNum = sessCBiasNum{stimDur}{genotype}{recsite};
                getSessbiasNum = getSessbiasNum(:,~zeroSess);
                contrasess = getSessbiasNum(1,:)>getSessbiasNum(2,:);
                ipsisess = getSessbiasNum(1,:)<getSessbiasNum(2,:);
                colorsStock = {[0 0 1], [1 0 0], [0 0 0], [0.5 0.5 0.5]};
                bins = -1:binWidth:1;
                color1 = [0 0 1];
                color2 = [1 0 0];
                ipsicolors1 = repmat(color1, [floor(numel(bins)/2),1]);
                contracolors1 = repmat(color2, [floor(numel(bins)/2),1]);
                mycolors = [ipsicolors1; [0 0 0]; contracolors1];

                
                if strcmp(uGenotypes{genotype},'KO')  
           
                    figure(3*stimDur-2);
                    hold on
                    s1 = swarmchart(getSessbiasNum(1,contrasess)', getSessbiasNum(2,contrasess)',20, 'markeredgecolor', colorsStock{2},...
                        'XJitterWidth',0.5, 'YJitterWidth', 0.5);
                    s2 = swarmchart(getSessbiasNum(1,ipsisess)', getSessbiasNum(2,ipsisess)',20, 'markeredgecolor', colorsStock{1}, ...
                        'XJitterWidth',0.5, 'YJitterWidth', 0.5);
                    s3 = swarmchart(getSessbiasNum(1,~ipsisess & ~contrasess)', getSessbiasNum(2,~ipsisess & ~contrasess)',20, 'markeredgecolor', colorsStock{3}, ...
                        'XJitterWidth',0.5, 'YJitterWidth', 0.5);        
                    hold off

                    figure(3*stimDur-1);
                    subplot(2,1,2);       
                    h2 = histogram(getCbiasTable(:,1), bins, 'facecolor', 'r');            
                    title(uGenotypes{genotype})
                    xlabel('(C-I)/(C+I)');
                    ylabel('#of units');

                    figure(3*stimDur);
                    subplot(2,1,2);
                    h1 = histogram(getCbiasTable(:,1), bins, 'facecolor', 'r', 'Normalization','probability');                       
                    title(uGenotypes{genotype})
                    xlabel('(C-I)/(C+I)');
                    ylabel('probability');
                    
                else
                    
                    figure(3*stimDur-2);                    
                    s4 = swarmchart(getSessbiasNum(1,contrasess)', getSessbiasNum(2,contrasess)'+0.2,20, 'markeredgecolor', colorsStock{4},...
                        'XJitterWidth',0.5, 'YJitterWidth', 0.5);                    

                    figure(3*stimDur-1);
                    subplot(2,1,1);
                    h1 = histogram(getCbiasTable(:,1), bins, 'facecolor', [0.8 0.8 0.8]);                       
                    title(uGenotypes{genotype})
                    xlabel('(C-I)/(C+I)');
                    ylabel('#of units');

                    figure(3*stimDur);
                    subplot(2,1,1);
                    h1 = histogram(getCbiasTable(:,1), bins, 'facecolor', [0.8 0.8 0.8], 'Normalization','probability');                       
                    title(uGenotypes{genotype})
                    xlabel('(C-I)/(C+I)');
                    ylabel('probability');
                end
                
    
                %inputrecSites
            end
            if max(getSessbiasNum,[],"all")> maxunits
                maxunits = max(getSessbiasNum,[],"all");
            end
        end
        figure(3*stimDur-1);   
        sgtitle([finalrecSites{recsite} ' ' ufreq{stimDur} ' counts']);

        figure(3*stimDur);
        sgtitle([finalrecSites{recsite} ' ' ufreq{stimDur} ' probability']);

        figure(3*stimDur-2);
        hold on
        plot(-1:maxunits+1,-1:maxunits+1, 'k-.')
        legend([s1,s2,s3,s4], {'KOcontra', 'KOIpsi','KOequal','WT'});
        xlabel('Number of contra units in a session');
        ylabel('Number of ipsi units in a session');
        xlim([-1,maxunits+1])
        ylim([-1,maxunits+1])
        title([finalrecSites{recsite} ' ' ufreq{stimDur}]);
        hold off
        savefig(g1,fullfile(savePath,  [finalrecSites{recsite} ' ' ufreq{stimDur} ' ms duration significant units sessPlot.fig']));
        saveas(g1,fullfile(savePath,  [finalrecSites{recsite} ' ' ufreq{stimDur} ' ms duration significant units sessPlot.png']));
        savefig(g2,fullfile(savePath,  [finalrecSites{recsite} ' ' ufreq{stimDur} ' ms duration significant units histogram.fig']));
        saveas(g2,fullfile(savePath,  [finalrecSites{recsite} ' ' ufreq{stimDur} ' ms duration significant units histogram.png']));
        savefig(g3,fullfile(savePath,  [finalrecSites{recsite} ' ' ufreq{stimDur} ' ms duration significant units histogram_probability.fig']));
        saveas(g3,fullfile(savePath,  [finalrecSites{recsite} ' ' ufreq{stimDur} ' ms duration significant units histogram_probability.png']));
    end

end

