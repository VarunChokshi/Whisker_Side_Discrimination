


%% Plot units separated by whisker stim duration. Contra vs ipsi, combine for left vs right hemisphere recording . combine plotsession_maps
% It also has LFPs
% Stims are taken as only the first deflection of all frequencies 
% clear all
% 
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\StimSEs', 'Select source SEs');

% clear all
animalID = {'VC030107','VC030109','VC030112','VC030114', 'VC030115', 'VC030209','VC030206',  'VC030208',   'VC030401', 'VC030402', 'VC030211', 'VC030213'};
% animalID = {'VC030211'};
% animalID = {'VC030407'};
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

%% load each session and update histology and penetration depth
parfor i = 1:height(dataFileTb)    
    se{i} = loadsess(dataFileTb.sePath{i});    
    se{i}.userData.sessionInfo.penetrationDepth = dataFileTb.penetrationDepth(i);
    se{i}.userData.sessionInfo.histology = dataFileTb.histology(i);
    se{i}.userData.sessionInfo.corticaldepth = dataFileTb.CorticalDepth(i);
    savesess(dataFileTb.sePath{i},se{i});
end




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
ops.wM1winadd = 0.25; 
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

ops.binWidth = 0.05; % this is for histograms. 
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


% normalized = 'normalized';
normalized = '';
if strcmp(normalized, 'normalized')

    fileName = 'allVars_normalized.mat';
else
    fileName = 'allVars.mat';
end
%% Make variables for raster FR rate, etc
Getcompositevars(dataFileTb, ops, normalized,fileName);

%% plot Rasters
MakeFigures(fullfile(ops.savePath, fileName));


 %% Plot indivdual rasters and FRs

 MakeIndUnitFigures(fullfile(ops.savePath,fileName), 'E:\oconnorlab Dropbox\oconnorlab Team Folder\users\Varun\SfnPresentations\BarrelsPosterAttempt2023');

 %% Plot Cbiastable

MakeCbiasFigures(fullfile(ops.savePath, fileName), ops.binWidth, ops.savePath);


%% PLot Depth vs Cbias histogram. 
% Take depths of every 20um bin size and plot cBias histogram
%  L1, 128 ± 1 μm; L2, 269 ± 2 μm; L3, 418 ± 3 μm; L4, 588 ± 3 μm; L5A, 708 ± 4 μm; L5B, 890 ± 5 μm; L6, 1154 ± 7 μm.
% Lefort et al Neuron 2009
ops.binWidth = 0.25;
CBiasDepthHisto(fullfile(ops.savePath, fileName), ops.binWidth, ops.savePath);
% Minamisawa et al Cell rep 2018
     % The upper boundaries of L2/3, L4, L5A, L5B, L6 were as follows: 0.081 ± 0.019, 0.279 ± 0.028, 0.440 ± 0.039, 0.538 ± 0.032, 0.651 ± 0.026 in S1

 %% Plot LFPs intan

%  ops.savePath = [ops.savePath ' Normalized'];

multiplier = 100;
MakeLFPs(fullfile(ops.savePath, fileName), normalized, multiplier);
    
%% Helper function

function se = loadsess(sePath)
    load(sePath);
end

function savesess(sePath, se)
    save(sePath, 'se', '-v7.3');  
end

function x = findDuration(stimType)
    
    secs = str2num(stimType(end-2:end));
    if secs
        x = secs/1000;
    else
        x = 1;
    end
end

function x = findDurationLFP(stimType)
    
    secs = str2num(stimType(end-1:end));
    if secs
        x = 1/secs;
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

function [unitLayer, layer_index] = assignLayer(depth)
    % Minamisawa et al Cell rep 2018
    % The upper boundaries of L2/3, L4, L5A, L5B, L6 were as follows: 0.081 ± 0.019, 0.279 ± 0.028, 0.440 ± 0.039, 0.538 ± 0.032, 0.651 ± 0.026 in S1
    allLayers = {'L1', 'L2/3', 'L4', 'L5A', 'L5B', 'L6'};
    ranges = [-1.5, 0.081, 0.279, 0.440, 0.538, 0.651, 1.5];
    layer_index = find(depth<=ranges,1)-1;    
    unitLayer = allLayers{layer_index};    
    
end

function Getcompositevars(dataFileTb, ops, normalized, fileName)
    defPenetrationDepth = ops.defPenetrationDepth;
    trials{1} = ops.trials{1};
    trials{2} = ops.trials{2}; 
    statAlpha = ops.statAlpha;
    plotAlpha = ops.plotAlpha;
    binSize = ops.binSize;
    tWins = ops.tWins;
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
            
%             if ~exist([savePath '\allVars' uGenotypes{genotype} inputrecSites{recSite} '.mat'], 'file') || redo
                
            if ~isempty(recReadPaths)
                
                
                close all; 

                allSpikeTimes{genotype}{recSite} = cell(1,12);
                pvals{genotype}{recSite} = cell(1,12);
                adcFinal{genotype}{recSite} = cell(1,12);
                bodysidefinal{genotype}{recSite}=cell(1,12);
                Cbiastable{genotype}{recSite} = cell(1,12);
                allMeanFR{genotype}{recSite} = cell(1,12);
                LFPFinal{genotype}{recSite} = cell(1,numel(recReadPaths));
                sessInfoFinal{genotype}{recSite} = cell(1,numel(recReadPaths));
                for sessNum = 1:numel(recReadPaths)


                    load(recReadPaths{sessNum});
                    sessRecSite = cell2mat(se.userData.sessionInfo.recSite);
                    
                    
                    
                    
                
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
                   
                     % get LFPAll
                     LFPData = 1;
                     try
                        LFPAll = se.SliceTimeSeries('LFP', tWins, 'Fill', 'bleed');
                        
                        tWin_baseline = [tWins(1) 0];
                        sampleRate = 1/diff(LFPAll.time{1,1}(1:2));

                        
                        LFPAll = LFPAll(trialInd,:);
                        LFPAll(1,:) = [];
                        LFPAllTime = LFPAll.time;
                        LFPAll(:,1) = []; 
                        LFPAll = table2cell(LFPAll);
                        LFPAll = cellfun(@(x) x', LFPAll, 'UniformOutput', false);

                        LFP_baseline = se.SliceTimeSeries('LFP', tWin_baseline, 'Fill', 'bleed');
                        LFP_baseline = LFP_baseline(trialInd,:);
                        LFP_baseline(1,:) = [];
                        LFP_baseline(:,1) = []; 
                        LFP_baseline = table2cell(LFP_baseline);
                        LFP_baseline = cellfun(@(x) x', LFP_baseline, 'UniformOutput', false);
                       
                        if strcmp(normalized, 'normalized') 

                            LFP_normalized =[];                           
                            for channel=1:64
                                LFP_baseline_mean(channel) = mean(cell2mat(LFP_baseline(:,channel)),'all');
                                LFP_baseline_std(channel) = std(cell2mat(LFP_baseline(:,channel)), 0,'all');
                                new_LFP_normalized = cellfun(@(x) (x-LFP_baseline_mean(channel))./LFP_baseline_std(channel), LFPAll(:,channel) ,'UniformOutput',false);
                                LFP_normalized = [LFP_normalized new_LFP_normalized];
                            end
                        else
                            LFP_normalized = LFPAll;
                        end
                        

                        % filter LFP between 0.1hz and 100 hz
                        bandpass_freq = [0.1 100]; % in Hz
                        Wn = bandpass_freq/(sampleRate/2);
                        [b,a] = butter(3,Wn, 'bandpass');
                        
                        LFP2 = cellfun(@(x) double(x), LFP_normalized, 'UniformOutput', false);
                        LFP_filtered = cellfun(@(x) filtfilt(b,a, x), LFP2, 'UniformOutput', false);

                     catch
                         LFPData = 0;
                     end
                    
                   
                    
    
                    try
                        unitChanDepth = se.userData.spikeInfo.quality_metrics.depth;
                    catch
                        
                        chanDepth = 0:20:1260; %(in um)
                        channelInds = se.userData.spikeInfo.unit_channel_ind;
                        chanMap = se.userData.sessionInfo.channel_map.chanMap;
                        [~, chanPos] = ismember(channelInds,chanMap);
                        unitChanDepth= chanDepth(chanPos);
                        
                    end
                    
                    stimTypes = leftStimTypes;
                    uStimTypes = unique(stimTypes);
                    ufreq = unique(cellfun(@(x) x(5:6),uStimTypes, 'UniformOutput', false)); % for gettign just the unique frequencies irrespective of the cycles
                    if isempty(str2num(ufreq{1}))
                        ufreq = unique(cellfun(@(x) x(17:18),uStimTypes, 'UniformOutput', false)); % for gettign just the unique frequencies irrespective of the cycles
                        freqStart = 17;
                    else
                        freqStart =5;
                    end
                    
                    adc = cell(1,numel(ufreq));
                    lfp = cell(1,numel(ufreq));

                    sessInfoTable = se.userData.sessionInfo;
                    sessInfoFinal{genotype}{recSite}{sessNum} =  se.userData.sessionInfo;
                    if ismember('penetrationDepth', sessInfoTable.Properties.VariableNames)
%                         penetrationDepth = sessInfoTable.penetrationDepth;
                        penetrationDepth = sessInfoTable.histology;
                        corticalDepth = sessInfoTable.corticaldepth;
                    else
                        penetrationDepth = defPenetrationDepth;
                        corticalDepth = 1280;
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

                       
                        
                        trials2keepL{stimDur} = find(strcmp(trials{1}{1}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(freqStart:freqStart+1),ufreq{stimDur}), ...
                            leftStimTypes, 'UniformOutput',false)));
                        trials2keepR{stimDur} = find(strcmp(trials{1}{2}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(freqStart:freqStart+1),ufreq{stimDur}), ...
                            rightStimTypes, 'UniformOutput',false)));
                        
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
                        
                        % get spikeTimes for FRlims
                        FRlims{stimDur} = [tWins(1) tWins(2)];               
                        spikeLeft = spikeAll(trials2keepL{stimDur},1:end);
                        spikeRight = spikeAll(trials2keepR{stimDur},1:end);          
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
                        maxAdc{genotype}{recSite}(sessNum,stimDur) = max(adc{stimDur}(2,:));
                        
                        if sum(ismember('Left', sessRecSite))==4
                            stims = {trials2keepL{stimDur}, trials2keepR{stimDur}};
                        else
                            stims = {trials2keepR{stimDur}, trials2keepL{stimDur}};
                        end

                        if LFPData
                            %Get LFPAll for each stimDur for ipsi
                            try
                                temp0 = LFPAllTime(stims{1});
                            catch
                                keyboard;
                            end
                            idcs = min(cell2mat(cellfun(@(x) numel(x), temp0, 'UniformOutput',false)));
                            temp0 =cellfun(@(x) x', temp0, 'UniformOutput',false);
                            temp0 = cell2mat(cellfun(@(x) x(1:idcs), temp0, 'UniformOutput', false));
                            LFPFinal{genotype}{recSite}{sessNum}{stimDur,1} = MMath.MeanStats(temp0,1);                        
                            
                            temp0 = LFP_filtered(stims{1},:);
                            idcs = min(cell2mat(cellfun(@(x) numel(x), temp0, 'UniformOutput',false)), [],'All');
%                             temp0 =cellfun(@(x) x', temp0, 'UniformOutput',false);
                            temp0 = cellfun(@(x) x(1:idcs), temp0, 'UniformOutput', false);
                            
                            temp1 = LFP_filtered(stims{2},:);
                            idcs = min(cell2mat(cellfun(@(x) numel(x), temp1, 'UniformOutput',false)), [],'All');
%                             temp1 =cellfun(@(x) x', temp1, 'UniformOutput',false);
                            temp1 = cellfun(@(x) x(1:idcs), temp1, 'UniformOutput', false);
    
                            
                            clearvars ipsiLFP contraLFP;
                            parfor chan = 1: width(temp0)
                                
                                ipsiLFP{chan} = MMath.MeanStats(cell2mat(temp0(:,chan)),1);
                                contraLFP{chan} = MMath.MeanStats(cell2mat(temp1(:,chan)),1);
                            end
    
                            LFPFinal{genotype}{recSite}{sessNum}{stimDur,2} = ipsiLFP';
                            LFPFinal{genotype}{recSite}{sessNum}{stimDur,3} = contraLFP';
                        end

                        pvalL = [];
                        pvalR = [];
                        unitDepth = [];
                        spikeTimes = {};
                        pvalstimDur =[];
                        bodysides = [];
                        meanFR = {};
                        cbiases = {};
                        
                        
                        
                        
                        parfor unitNum = 1: size(preMeanFRL{stimDur},2)                           

                           
                            [pvalL(unitNum)] = signrank(preMeanFRL{stimDur}(:,unitNum), postMeanFRL{stimDur}(:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);
                            [pvalR(unitNum)] = signrank(preMeanFRR{stimDur}(:,unitNum), postMeanFRR{stimDur}(:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);
                 
                            unitDepth(unitNum) = unitChanDepth(unitNum);
                            meanFRtime =  MMath.MeanStats(cell2mat(FRtime{stimDur}), 1);
                        
                            if sum(ismember(sessRecSite, 'Left'))==4
                                uSpikesIpsi = spikeLeft(:,unitNum);
                                uSpikesContra = spikeRight(:,unitNum);
                                [meanFRI, ~, ~,...
                                ciFRI]= MMath.MeanStats(cell2mat(FRLeft{stimDur}(:,unitNum)), 1);
                                [meanFRC, ~, ~,...
                                ciFRC]= MMath.MeanStats(cell2mat(FRRight{stimDur}(:,unitNum)), 1);
                            else
                                uSpikesIpsi = spikeRight(:,unitNum);
                                uSpikesContra = spikeLeft(:,unitNum);
                                [meanFRI, ~, ~,...
                                ciFRI]= MMath.MeanStats(cell2mat(FRRight{stimDur}(:,unitNum)), 1);
                                [meanFRC, ~, ~,...
                                ciFRC]= MMath.MeanStats(cell2mat(FRLeft{stimDur}(:,unitNum)), 1);
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
%                             cbiases(unitNum,:) = Cbias;
                            spikeTimes(unitNum,:) = {uSpikesIpsi, uSpikesContra,...
                                    (penetrationDepth-unitDepth(unitNum))/corticalDepth, min(pvalL(unitNum), pvalR(unitNum)), Cbias};
                            meanFR(unitNum,:) = {meanFRtime, meanFRI, meanFRC, ciFRI, ciFRC, ...
                                    (penetrationDepth-unitDepth(unitNum))/corticalDepth, min(pvalL(unitNum), pvalR(unitNum)), Cbias};
                            bodysides(unitNum) = bodyside7;
                            cbiases(unitNum,:) = {Cbias, ...
                                        (penetrationDepth-unitDepth(unitNum))/corticalDepth, min(pvalL(unitNum), pvalR(unitNum))};
                        end
                        
                        % make final variables to plot containing all data
                        pvals{genotype}{recSite}{pstimDur}(end+1:end+numel(pvalstimDur)) = pvalstimDur';
                        bodysidefinal{genotype}{recSite}{pstimDur}(end+1:end+numel(bodysides)) = bodysides;
                        Cbiastable{genotype}{recSite}{sessNum}{pstimDur} = cbiases;
                        adcFinal{genotype}{recSite}{pstimDur}(end+1:end+size(adc{stimDur},1),1:size(adc{stimDur},2)) = adc{stimDur};
                        allSpikeTimes{genotype}{recSite}{pstimDur}(end+1:end+size(spikeTimes,1),:) = spikeTimes;  
                        allMeanFR{genotype}{recSite}{pstimDur}(end+1:end+size(meanFR,1),:) = meanFR;                        
                   end             
                  
                   % go to next session of the same recording site and
                   % genotype
                        
                end
    
    
            else
                continue;
            end
        end
    end
    


%     clearvars -except ops allSpikeTimes maxAdc pvals plotAlpha ufreq uGenotypes inputrecSites adcFinal savePath plotLims genotype recSite recSites genotypes
% 
    if ~exist(savePath, 'dir')
        mkdir(savePath);
    end
    
    save([savePath '\' fileName]);    

%   
        
        

end

function MakeFigures(allVars)
    % plot allMeanFR for all the stimDur
    
    load(allVars, 'allSpikeTimes', 'maxAdc', 'ops', 'bodysidefinal','ufreq','uGenotypes', 'inputrecSites', 'adcFinal', 'plotLims', 'pvals', 'allMeanFR');
    
    
    for genotype = 1: numel(allSpikeTimes)
            
            for recSite =1:numel(allSpikeTimes{genotype})
                maxAdcgenotype = maxAdc{genotype}{recSite};
                [maxadcfig rows] = max(maxAdcgenotype(1,:));
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
                        
                       
                        sessions7 = find(bodysidefinal{genotype}{recSite}{2}==1);
            
                        sessions8 = find(bodysidefinal{genotype}{recSite}{2}==0);
                        clearvars pvalsfake
                        if ~isempty(sessions7)
                            
                            pvalsfake{1,1}(sessions7) = ones(size(sessions7));
                            pvalsfake{1,1}(sessions8) = pvals{genotype}{recSite}{1,1};
                            pvalsfake{1,3}(sessions7) = ones(size(sessions7));
                            pvalsfake{1,3}(sessions8) = pvals{genotype}{recSite}{1,3};
                            pvalsfake{1,4}(sessions7) = ones(size(sessions7));
                            pvalsfake{1,4}(sessions8) = pvals{genotype}{recSite}{1,4};
                            pvalsfake{1,2} = pvals{genotype}{recSite}{1,2};
                            pvals{genotype}{recSite} = pvalsfake;
                        end
                        
                        % need to get the 20hz only sessions out.  
                        pvals{genotype}{recSite} = cellfun(@(x) x', pvals{genotype}{recSite}, 'UniformOutput', false); 
                        try
                            pvals2 = cell2mat(pvals{genotype}{recSite});
                        catch
                            keyboard;
                        end
                        pvalsLogic = pvals2<ops.plotAlpha;
                        pvalsLogic = pvalsLogic(:,1:3);
                        pvalSum = sum(pvalsLogic,2);
                        sigUnits = pvalSum>0;
                        
                    else
                        sessions7 =[];
                    end
                    
                    for stimDur = 1:numel(ufreq)
                       % creat uifigure
                        g{stimDur} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz spikeRaster'],'NumberTitle','off'); clf;
                        g{stimDur}.WindowState = 'Maximized';

                        gg{stimDur} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz FR'],'NumberTitle','off'); clf;
                        gg{stimDur}.WindowState = 'Maximized';
                        
                        % spikeTimes
                        spikeTimes{stimDur} = allSpikeTimes{genotype}{recSite}{stimDur};                        
                        spikeTimes{stimDur} = SignifyFR(spikeTimes{stimDur}, allpvals, sigUnits, ops.plotAlpha, 4, sessions7, stimDur);               
                        spikeTimes{stimDur} = sortrows(spikeTimes{stimDur},3);

                        % FR plots
                        meanFR{stimDur} = allMeanFR{genotype}{recSite}{stimDur};                        
                        meanFR{stimDur} = SignifyFR(meanFR{stimDur}, allpvals, sigUnits, ops.plotAlpha, 7, sessions7, stimDur);               
                        meanFR{stimDur} = sortrows(meanFR{stimDur},6);

                        % Set the number of subplots and rows                        
                        plotRows = max(3,ceil(height(spikeTimes{stimDur})/15));
                        

                        for unitNum =1:height(spikeTimes{stimDur})
        
                            figure(g{stimDur});         
                            %sort each meanFR cell by depth                   
                            h = subplot(plotRows,15,unitNum, 'Parent', g{stimDur});                                  
                            hold(h, 'on');
                            % plot left trials
                            for i = 1: height(spikeTimes{stimDur}{unitNum,1})
                                MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,1}{i}*1000, i*ones(numel(spikeTimes{stimDur}{unitNum,1}{i}),1) ,1, 'orientation', 'vertical', ...
                                    'linestyle', '-','color', color{1}, 'linewidth', 1);
                            end
                            totalTrials = height(spikeTimes{stimDur}{unitNum,2})+ height(spikeTimes{stimDur}{unitNum,1});
                            xLimits = get(gca,'XLim');
                            MPlot.PlotPointAsLine(0,i+1,xLimits(2), 'orientation', 'horizontal', 'linestyle', '--', ...
                                'color',[0 0 0], 'linewidth', 1);
                            % plot right trials
                            for i = 1+height(spikeTimes{stimDur}{unitNum,1}): totalTrials
                                rInd = i  -height(spikeTimes{stimDur}{unitNum,1});
                                MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,2}{rInd}*1000, (i+1)*ones(numel(spikeTimes{stimDur}{unitNum,2}{rInd}),1) ,1, 'orientation', 'vertical', ...
                                    'linestyle', '-','color', color{2}, 'linewidth', 1);
                            end                         
                        
                            adcChan = adcFinal{genotype}{recSite}{stimDur}(2,:);
                            
                            if max(adcChan) <0.1
                                fM = 10e4;
                        %                 fM = 1;
                            else
                                fM =10;
                            end
                                

                            yLimits = get(gca,'YLim');                    
                            plot(adcFinal{genotype}{recSite}{stimDur}(1,:)*1000, (adcFinal{genotype}{recSite}{stimDur}(2,:)*fM) +  totalTrials+5+1, ...
                                'k', 'lineWidth', 1);                            
                            yLimits = get(gca,'YLim');
                            MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--', ...
                                'color',[0.5 0.5 0.5], 'linewidth', 1);
        %                     xlabel('epoch time (s)');
        %                     ylabel('Trials');  
                            yLimits = get(gca,'YLim');
                            ylim([0, yLimits(2)])
                            xlim(plotLims{stimDur}*1000); 
                            CbiasVal = round(spikeTimes{stimDur}{unitNum,5} * 10) / 10;
                            title({[num2str(spikeTimes{stimDur}{unitNum,3}) ' \mum']},{['Cbias = '  num2str(CbiasVal)]});                    
                            box off  
                            outerpos = get(h,'OuterPosition');
                            ti = get(h,'TightInset');
                            left = outerpos(1) + ti(1);
                            bottom = outerpos(2) + ti(2);
                            ax_width = outerpos(3) - ti(1) - ti(3);
                            ax_height = outerpos(4) - ti(2) - ti(4)-0.025;
                            set(h,'Position',[left bottom ax_width ax_height], 'fontsize', 10);                            
                            hold(h, 'off');
                        
                            % plot FR subplots here

                           figure(gg{stimDur});  
                            %sort each meanFR cell by depth                           
                            hh = subplot(plotRows,15,unitNum, 'Parent', gg{stimDur});                                  
                            hold(hh, 'on');                               
                            plot(meanFR{stimDur}{unitNum,1}*1000, meanFR{stimDur}{unitNum, 2}, ...
                                color{1}, 'LineWidth', 1);
                            plot(meanFR{stimDur}{unitNum,1}*1000, meanFR{stimDur}{unitNum, 3}, ...
                                color{2}, 'LineWidth', 1);                                
                            if ~isempty(meanFR{stimDur}{unitNum, 2})                                
                                MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}*1000, meanFR{stimDur}{unitNum, 2}, meanFR{stimDur}{unitNum, 4}(2,:), ...
                                    meanFR{stimDur}{unitNum, 4}(1,:), 'color',color{1}, 'Alpha', 0.3, 'IsRelative', false);                                        
                            end            
                            if ~isempty(meanFR{stimDur}{unitNum, 4})                                
                                MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}*1000, meanFR{stimDur}{unitNum, 3}, meanFR{stimDur}{unitNum, 5}(2,:), ...
                                    meanFR{stimDur}{unitNum, 5}(1,:), 'color',color{2}, 'Alpha', 0.3, 'IsRelative', false);                                                        
                            end                        
                            yLimits = get(gca,'YLim');        

                            adcChan = adcFinal{genotype}{recSite}{stimDur}(2,:);
                            
                            if max(adcChan) <0.1
                                fM = 10e4;
                        %                 fM = 1;
                            else
                                fM =10;
                                
                            end

                            plot(adcFinal{genotype}{recSite}{stimDur}(1,:)*1000, (adcFinal{genotype}{recSite}{stimDur}(2,:)*fM) +  yLimits(2), ...
                                'k', 'lineWidth', 1);
                            yLimits = get(gca,'YLim');
                            MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
            %                 xlabel('epoch time (s)');
            %                 ylabel('FR');  
                            yLimits = get(gca,'YLim');
                            ylim([0, yLimits(2)]);
                            xlim(plotLims{stimDur}*1000);                  
                            try
                                [unitLayer, layerIndex] = assignLayer(meanFR{stimDur}{unitNum,6});
                            catch
                                unitLayer = [num2str(meanFR{stimDur}{unitNum,6}) ' um'];
                                
                            end
                            title(unitLayer,{[' Cbias = '  num2str(CbiasVal)]});                    
                            box off  
                            outerpos = get(hh,'OuterPosition');
                            ti = get(hh,'TightInset');
                            left = outerpos(1) + ti(1);
                            bottom = outerpos(2) + ti(2);
                            ax_width = outerpos(3) - ti(1) - ti(3);
                            ax_height = outerpos(4) - ti(2) - ti(4)-0.025;
                            set(hh,'Position',[left bottom ax_width ax_height], 'fontsize', 10);     
                            hold(hh, 'off');

                
        
                        end                        
            
                        savePath2 = [ops.savePath ' allpvals =  ' num2str(allpvals)];
            
                        if ~exist(savePath2, 'dir')
                            mkdir(savePath2);
                        end
            
                       
                    
                        savefig(g{stimDur},fullfile(savePath2,  [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz significant units_rasters.fig']));
                        saveas(g{stimDur},fullfile(savePath2,  [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz significant units_rasters.png']));
                        savefig(gg{stimDur},fullfile(savePath2,  [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz significant units_FRs.fig']));
                        saveas(gg{stimDur},fullfile(savePath2,  [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz significant units_FRs.png']));
                    end
            
                end
        
        end
    end
end

function MakeIndUnitFigures(allVars, figureRoot)
    % plot allMeanFR for all the stimDur
    
    load(allVars, 'allSpikeTimes', 'maxAdc', 'ops', 'bodysidefinal','ufreq','uGenotypes', 'inputrecSites', 'adcFinal', 'plotLims', 'pvals', 'allMeanFR');
    genotypeColors{2} = {'b', 'r'};
    genotypeColors{1} = {[6 6 192]/255; [212 0 0]/255};

    
    for genotype = 1: numel(allSpikeTimes)
            
            for recSite =1:numel(allSpikeTimes{genotype})
                maxAdcgenotype = maxAdc{genotype}{recSite};
                [maxadcfig rows] = max(maxAdcgenotype(1,:));
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
                
                color = genotypeColors{genotype};
                
                
            
                for allpvals = 0:ops.allpvals-1
                    spikeTimes ={};
                    sigUnits = {};
                    
                    if allpvals
                        
                       
                        sessions7 = find(bodysidefinal{genotype}{recSite}{2}==1);
            
                        sessions8 = find(bodysidefinal{genotype}{recSite}{2}==0);
                        clearvars pvalsfake
                        if ~isempty(sessions7)
                            
                            pvalsfake{1,1}(sessions7) = ones(size(sessions7));
                            pvalsfake{1,1}(sessions8) = pvals{genotype}{recSite}{1,1};
                            pvalsfake{1,3}(sessions7) = ones(size(sessions7));
                            pvalsfake{1,3}(sessions8) = pvals{genotype}{recSite}{1,3};
                            pvalsfake{1,4}(sessions7) = ones(size(sessions7));
                            pvalsfake{1,4}(sessions8) = pvals{genotype}{recSite}{1,4};
                            pvalsfake{1,2} = pvals{genotype}{recSite}{1,2};
                            pvals{genotype}{recSite} = pvalsfake;
                        end
                        
                        % need to get the 20hz only sessions out.  
                        pvals{genotype}{recSite} = cellfun(@(x) x', pvals{genotype}{recSite}, 'UniformOutput', false); 
                        try
                            pvals2 = cell2mat(pvals{genotype}{recSite});
                        catch
                            keyboard;
                        end
                        pvalsLogic = pvals2<ops.plotAlpha;
                        pvalsLogic = pvalsLogic(:,1:3);
                        pvalSum = sum(pvalsLogic,2);
                        sigUnits = pvalSum>0;
                        
                    else
                        sessions7 =[];
                    end
                    
                    for stimDur = 1:min(numel(ufreq), 3)
                      
                       
                        % spikeTimes
                        spikeTimes{stimDur} = allSpikeTimes{genotype}{recSite}{stimDur};                        
                        spikeTimes{stimDur} = SignifyFR(spikeTimes{stimDur}, allpvals, sigUnits, ops.plotAlpha, 4, sessions7, stimDur);               
                        spikeTimes{stimDur} = sortrows(spikeTimes{stimDur},3);

                        % FR plots
                        meanFR{stimDur} = allMeanFR{genotype}{recSite}{stimDur};                        
                        meanFR{stimDur} = SignifyFR(meanFR{stimDur}, allpvals, sigUnits, ops.plotAlpha, 7, sessions7, stimDur);               
                        meanFR{stimDur} = sortrows(meanFR{stimDur},6);

                        % Set the number of subplots and rows                        
                        plotRows = max(3,ceil(height(spikeTimes{stimDur})/15));
                        
%                         for unitNum =1:1
                        for unitNum =1:height(spikeTimes{stimDur})
                            close all
                            g{unitNum} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz spikeRaster'],'NumberTitle','off'); clf;
                            set(g{unitNum}, 'Units', 'inch', 'Position', [1 1 1 2.5]);
                            g{unitNum}.Visible = 'Off';
                            gg{unitNum} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz FR'],'NumberTitle','off'); clf;
                            set(gg{unitNum}, 'Units', 'inch', 'Position', [1 1 1 2.5]);
                            gg{unitNum}.Visible = 'Off';
                            figure(g{unitNum});         
                            %sort each meanFR cell by depth                   
                            h = subplot(1,1,1, 'Parent', g{unitNum});                                  
                            hold(h, 'on');
                            % plot left trials
                            for i = 1: height(spikeTimes{stimDur}{unitNum,1})
                                MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,1}{i}*1000, i*ones(numel(spikeTimes{stimDur}{unitNum,1}{i}),1) ,1, 'orientation', 'vertical', ...
                                    'linestyle', '-','color', color{1}, 'linewidth', 1.5);
                            end
                            totalTrials = height(spikeTimes{stimDur}{unitNum,2})+ height(spikeTimes{stimDur}{unitNum,1});
                            xLimits = get(gca,'XLim');
                            MPlot.PlotPointAsLine(0,i+1,xLimits(2), 'orientation', 'horizontal', 'linestyle', '--', ...
                                'color',[0 0 0], 'linewidth', 1);
                            % plot right trials
                            for i = 1+height(spikeTimes{stimDur}{unitNum,1}): totalTrials
                                rInd = i  -height(spikeTimes{stimDur}{unitNum,1});
                                MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,2}{rInd}*1000, (i+1)*ones(numel(spikeTimes{stimDur}{unitNum,2}{rInd}),1) ,1, 'orientation', 'vertical', ...
                                    'linestyle', '-','color', color{2}, 'linewidth', 1.5);
                            end                         
                        
                            adcChan = adcFinal{genotype}{recSite}{stimDur}(2,:);
                            adcTime = adcFinal{genotype}{recSite}{stimDur}(1,:);
                            wrongADC = find(adcTime==0);
                            adcTime(wrongADC) = [];
                            adcChan(wrongADC) =[];


                            if max(adcChan) <0.1
                                fM = 10e4;
                        %                 fM = 1;
                            else
                                fM =10;
                            end
                                

                            yLimits = get(gca,'YLim');     
                            
                            plot(adcTime*1000, (adcChan*fM) +  totalTrials+5+1, ...
                                'k', 'lineWidth', 1);                            
                            yLimits = get(gca,'YLim');
                            MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--', ...
                                'color',[0.5 0.5 0.5], 'linewidth', 1);
        %                     xlabel('epoch time (s)');
        %                     ylabel('Trials');  
                            yLimits = get(gca,'YLim');
                            ylim([0, yLimits(2)])
                            xlim(plotLims{stimDur}*1000); 
                            CbiasVal = round(spikeTimes{stimDur}{unitNum,5} * 10) / 10;
%                             title({[num2str(spikeTimes{stimDur}{unitNum,3}) ' \mum']},{['Cbias = '  num2str(CbiasVal)]});                    
                            box off  
                            
                            set(h,'fontsize', 12);                            
                            hold(h, 'off');
                        
                            % plot FR subplots here

                           figure(gg{unitNum});  
                            %sort each meanFR cell by depth                           
                            hh = subplot(1,1,1, 'Parent', gg{unitNum});                                  
                            hold(hh, 'on');    
                            
                            plot(meanFR{stimDur}{unitNum,1}*1000, meanFR{stimDur}{unitNum, 2}, ...
                                'color', color{1}, 'LineWidth', 1);
                            plot(meanFR{stimDur}{unitNum,1}*1000, meanFR{stimDur}{unitNum, 3}, ...
                                'color',color{2}, 'LineWidth', 1);                                
                            if ~isempty(meanFR{stimDur}{unitNum, 2})                                
                                MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}*1000, meanFR{stimDur}{unitNum, 2}, meanFR{stimDur}{unitNum, 4}(2,:), ...
                                    meanFR{stimDur}{unitNum, 4}(1,:), 'color',color{1}, 'Alpha', 0.3, 'IsRelative', false);                                        
                            end            
                            if ~isempty(meanFR{stimDur}{unitNum, 4})                                
                                MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}*1000, meanFR{stimDur}{unitNum, 3}, meanFR{stimDur}{unitNum, 5}(2,:), ...
                                    meanFR{stimDur}{unitNum, 5}(1,:), 'color',color{2}, 'Alpha', 0.3, 'IsRelative', false);                                                        
                            end                        
                            yLimits = get(gca,'YLim');        

                            
                          
                           plot(adcTime*1000, (adcChan*fM) +  yLimits(2), ...
                                'k', 'lineWidth', 1);   
                            yLimits = get(gca,'YLim');
                            MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
            %                 xlabel('epoch time (s)');
            %                 ylabel('FR');  
                            yLimits = get(gca,'YLim');
                            ylim([0, yLimits(2)]);
                            xlim(plotLims{stimDur}*1000);                             

%                             title({[num2str(meanFR{stimDur}{unitNum,6}) ' \mum']},{['Cbias = '  num2str(CbiasVal)]});                    
                            box off  
                            
                            set(hh, 'fontsize', 12);     
                            hold(hh, 'off');

                            savePath2 = fullfile(figureRoot, [ ' allpvals =  ' num2str(allpvals)], [uGenotypes{genotype} ' ' ufreq{stimDur}], 'Rasters');
                            savePath3 = fullfile(figureRoot, [' allpvals =  ' num2str(allpvals)], [uGenotypes{genotype} ' ' ufreq{stimDur}], 'FRs');

                            if ~isfolder(savePath2)
                                mkdir(savePath2);
                            end

                            if ~isfolder(savePath3)
                                mkdir(savePath3);
                            end
                
                           
                            
                            savefig(g{unitNum}, fullfile(savePath2,  ['UnitNum- ' num2str(unitNum) ' Depth- ' num2str(meanFR{stimDur}{unitNum,6}) ' um.fig']));
                            saveas(g{unitNum},fullfile(savePath2,  ['UnitNum- ' num2str(unitNum) ' Depth- ' num2str(meanFR{stimDur}{unitNum,6}) ' um.png']));
                            savefig(gg{unitNum},fullfile(savePath3,  ['UnitNum- ' num2str(unitNum) ' Depth- ' num2str(meanFR{stimDur}{unitNum,6}) ' um.fig']));
                            saveas(gg{unitNum},fullfile(savePath3,  ['UnitNum- ' num2str(unitNum) ' Depth- ' num2str(meanFR{stimDur}{unitNum,6}) ' um.png']));
        
                        end                        
            
                      
                    end
            
                end
        
        end
    end
end

function MakeCbiasFigures(allVars, binWidth, figureRoot)
    load(allVars, 'Cbiastable', 'ops', 'bodysidefinal','ufreq','uGenotypes', 'inputrecSites',  'pvals');
    close all   
    
    % just signify according to allpvals
    
    for allpvals = 0:ops.allpvals  
        Cbiastable2 = {};
        sessCBiasNum = {};
        savePath = fullfile(figureRoot, ['allPvals = ' num2str(allpvals)]);

       

        for genotype = numel(Cbiastable):-1:1 
            
            for recSite =1:numel(Cbiastable{genotype})
                for sessNum =1:numel(Cbiastable{genotype}{recSite})
                    if isempty(Cbiastable{genotype}{recSite}{sessNum})
                        continue;
                    end              
                    sigUnits = {};
                    cbiasSess = cellfun(@(x) cell2mat(x), Cbiastable{genotype}{recSite}{sessNum}, 'UniformOutput',false);
                     if allpvals && numel(cbiasSess) >3 
                        pvalSess = cell2mat(cellfun(@(x) x(:,3), cbiasSess, 'UniformOutput',false));
                        if size(pvalSess,2) >3
                           pvalSess = pvalSess(:,1:3);
                        end
                        sigUnits = pvalSess < ops.plotAlpha;
                        sumlogic = sum(sigUnits,2);
                        sigUnits = sumlogic>0;
                        cbiasSess = cellfun(@(x) x(sigUnits, :), cbiasSess, 'UniformOutput',false);
                     else
                        if numel(cbiasSess)>3
                            sigUnits = cellfun(@(x) x(:,3)<ops.plotAlpha, cbiasSess, 'UniformOutput',false);                        
                            cbiasSess = cellfun(@(x,y) x(y, :), cbiasSess, sigUnits,'UniformOutput',false);        
                        else
                            sigUnits = cbiasSess{2}(:,3)<ops.plotAlpha;
                            cbiasSess{2} = cbiasSess{2}(sigUnits,:);
                        end

                     end

                     Cbiastable3{genotype}{recSite}{sessNum} = cbiasSess;


                    for stimDur =1:numel(Cbiastable{genotype}{recSite}{sessNum})

                        Cbiastable2{stimDur}{genotype}{recSite}{sessNum} = Cbiastable3{genotype}{recSite}{sessNum}{stimDur};

                        if ~isempty(Cbiastable2{stimDur}{genotype}{recSite}{sessNum})
                            sessCBiasNum{stimDur}{genotype}{recSite}(1,sessNum) = numel(find(Cbiastable2{stimDur}{genotype}{recSite}{sessNum}(:,1)>0));
                            sessCBiasNum{stimDur}{genotype}{recSite}(2,sessNum) = numel(find(Cbiastable2{stimDur}{genotype}{recSite}{sessNum}(:,1)<0));
                            sessCBiasNum{stimDur}{genotype}{recSite}(3,sessNum) = numel(find(Cbiastable2{stimDur}{genotype}{recSite}{sessNum}(:,1)==0));
                        else
                            sessCBiasNum{stimDur}{genotype}{recSite}(1,sessNum) = 0;
                            sessCBiasNum{stimDur}{genotype}{recSite}(2,sessNum) = 0;
                            sessCBiasNum{stimDur}{genotype}{recSite}(3,sessNum) = 0;
                        end
                    end


                end
            end
        end
    
                    






                    
                   
        for stimDur =1:numel(ufreq)
            g1 = figure(3*stimDur-2);clf;
            set(g1, 'Units', 'inch', 'Position', [1 1 3.5 3.5])
            g2 = figure(3*stimDur-1);clf;
            set(g2, 'Units', 'inch', 'Position', [1 1 3.5 5])
            g3 = figure(3*stimDur); clf;
            set(g3, 'Units', 'inch', 'Position', [1 1 3.5 5])
    
            maxunits = 0;
            for genotype = numel(Cbiastable2{stimDur}):-1:1 
                
                for recSite =1:numel(Cbiastable2{stimDur}{genotype})
                    getCbiasTable = Cbiastable2{stimDur}{genotype}{recSite};
                    zeroSess = cellfun(@isempty, getCbiasTable);
                    getCbiasTable = getCbiasTable(~zeroSess);
                    
%                     getCbiasTable = cellfun(@cell2mat, getCbiasTable', 'UniformOutput', false);
                    getCbiasTable = cell2mat(getCbiasTable');
    
                    getSessbiasNum = sessCBiasNum{stimDur}{genotype}{recSite};
                    getSessbiasNum = getSessbiasNum(:,~zeroSess);
                    
                    % find if all three are zeros
                    getSessbiasNum(:,sum(getSessbiasNum(1:2,:),1) ==0) = [];
%                     if stimDur ==3 && allpvals ==1
%                         keyboard;
%                     end
                    
                    contrasess = getSessbiasNum(1,:)>getSessbiasNum(2,:);
                    ipsisess = getSessbiasNum(1,:)<getSessbiasNum(2,:);
                    colorsStock = {[1 0 1], [1 0 0], [0 0 0], [0.5 0.5 0.5]};
                    bins = -1:binWidth:1;
                    color1 = [0 0 1];
                    color2 = [1 0 0];
                    ipsicolors1 = repmat(color1, [floor(numel(bins)/2),1]);
                    contracolors1 = repmat(color2, [floor(numel(bins)/2),1]);
                    mycolors = [ipsicolors1; [0 0 0]; contracolors1];
    
                    
                    if strcmp(uGenotypes{genotype},'KO')  
               
                        figure(3*stimDur-2);
                        h = subplot(1,1,1);
                        hold on
                        s1 = swarmchart(getSessbiasNum(1,contrasess)', getSessbiasNum(2,contrasess)',20,'marker', 'x', 'markeredgecolor', colorsStock{3},...
                            'YJitterWidth', 0.5, 'LineWidth',1.5);
                        swarmchart(getSessbiasNum(1,ipsisess)', getSessbiasNum(2,ipsisess)',20,'marker', 'x', 'markeredgecolor', colorsStock{3}, ...
                            'XJitterWidth',0.5, 'LineWidth',1.5);
                        swarmchart(getSessbiasNum(1,~ipsisess & ~contrasess)', getSessbiasNum(2,~ipsisess & ~contrasess)',20,'marker', 'x', 'markeredgecolor', colorsStock{3}, ...
                            'XJitterWidth',0.5, 'LineWidth',1.5);   
                        set(h, 'FontSize', 14)                          
                        h.LineWidth = 2;
                        hold off
    
                        figure(3*stimDur-1);
                        hh2 = subplot(2,1,2);       
                        h2 = histogram(getCbiasTable(:,1), bins, 'facecolor', 'k'); 
                        set(hh2,  'fontsize', 14);
                        hh2.LineWidth = 2;
                        xticks(-1:0.25:1)
                        title(uGenotypes{genotype})
                        xlabel('(C-I)/(C+I)');
                        ylabel('#of units');
    
                        figure(3*stimDur);
                        hh1 = subplot(2,1,2);
                        h1 = histogram(getCbiasTable(:,1), bins, 'facecolor', 'k', 'Normalization','probability');                       
                        title(uGenotypes{genotype})
                        xticks(-1:0.25:1)
                        set(hh1,  'fontsize', 14);
                        hh1.LineWidth = 2;
                        xlabel('(C-I)/(C+I)');
                        ylabel('probability');
                        
                    else
                        
                        figure(3*stimDur-2);    
                        hold on
                        h = subplot(1,1,1);
                        s4 = swarmchart(getSessbiasNum(1,contrasess)', getSessbiasNum(2,contrasess)'+0.2,20,'marker', 'x', 'markeredgecolor', colorsStock{4},...
                            'YJitterWidth', 0.5, 'LineWidth',1.5);                    
                         swarmchart(getSessbiasNum(1,ipsisess)'+0.2, getSessbiasNum(2,ipsisess)',20,'marker', 'x', 'markeredgecolor', colorsStock{4}, ...
                            'XJitterWidth',0.5, 'LineWidth',1.5);
                        swarmchart(getSessbiasNum(1,~ipsisess & ~contrasess)'+0.2, getSessbiasNum(2,~ipsisess & ~contrasess)'+0.2,20,'marker', 'x', 'markeredgecolor', colorsStock{4}, ...
                            'XJitterWidth',0.5, 'LineWidth',1.5);    
                       set(h, 'FontSize', 14)
                       
                        
                        
                        
                        hold off


                        figure(3*stimDur-1);
                        hh1=subplot(2,1,1);
                        h1 = histogram(getCbiasTable(:,1), bins, 'facecolor', [0.4 0.4 0.4]);                       
                        title(uGenotypes{genotype})
                        set(hh1,  'fontsize', 14);
                        xticks(-1:0.25:1)
                        hh1.LineWidth = 2;
                        ylabel('#of units');
    
                        figure(3*stimDur);
                        hh2=subplot(2,1,1);
                        h1 = histogram(getCbiasTable(:,1), bins, 'facecolor', [0.4 0.4 0.4], 'Normalization','probability');                       
                        title(uGenotypes{genotype})
                        set(hh2,  'fontsize', 14);
                        xticks(-1:0.25:1)
                        hh2.LineWidth = 2;
                        ylabel('probability');
                    end
                    
        
                    %inputrecSites
                end
                if max(getSessbiasNum,[],"all")> maxunits
                    maxunits = max(getSessbiasNum,[],"all");
                end
            end
%             figure(3*stimDur-1);   
%             sgtitle([inputrecSites{recSite} ' ' ufreq{stimDur} ' counts']);
%     
%             figure(3*stimDur);
%             sgtitle([inputrecSites{recSite} ' ' ufreq{stimDur} ' probability']);
    
            figure(3*stimDur-2);
            maxunits = min(8, maxunits);
            hold on
            
            plot(-1:maxunits+1,-1:maxunits+1, 'k-.')
            legend([s1,s4], {'KO','WT'}, 'Fontsize', 14);
            xlabel('Contra units in a session', 'Fontsize', 14);
            ylabel('Ipsi units in a session', 'Fontsize', 14);
            xticks(0:2:8);
%             xticklabels([])
            yticks(0:2:8);
%             yticklabels([])
            xlim([-1,(maxunits+1)])
            ylim([-1,maxunits+1])
            title([inputrecSites{recSite} ' ' ufreq{stimDur}]);
            hold off

            if ~isfolder(savePath)
                mkdir(savePath);
            end
            savefig(g1,fullfile(savePath,  [inputrecSites{recSite} ' ' ufreq{stimDur} ' ms duration significant units sessPlot.fig']));
            saveas(g1,fullfile(savePath,  [inputrecSites{recSite} ' ' ufreq{stimDur} ' ms duration significant units sessPlot.png']));
            savefig(g2,fullfile(savePath,  [inputrecSites{recSite} ' ' ufreq{stimDur} ' ms duration significant units histogram.fig']));
            saveas(g2,fullfile(savePath,  [inputrecSites{recSite} ' ' ufreq{stimDur} ' ms duration significant units histogram.png']));
            savefig(g3,fullfile(savePath,  [inputrecSites{recSite} ' ' ufreq{stimDur} ' ms duration significant units histogram_probability.fig']));
            saveas(g3,fullfile(savePath,  [inputrecSites{recSite} ' ' ufreq{stimDur} ' ms duration significant units histogram_probability.png']));
        end


    end



        
end

function CBiasDepthHisto(allVars, binWidth, figureRoot)
    load(allVars, 'Cbiastable', 'ops', 'bodysidefinal','ufreq','uGenotypes', 'inputrecSites',  'pvals');
    close all   
     % L1, 128 ± 1 μm; L2, 269 ± 2 μm; L3, 418 ± 3 μm; L4, 588 ± 3 μm; L5A, 708 ± 4 μm; L5B, 890 ± 5 μm; L6, 1154 ± 7 μm.
    % just signify according to allpvals
    
    for allpvals = 0:ops.allpvals  
        Cbiastable2 = {};
        sessCBiasNum = {};
        
        savePath = fullfile(figureRoot, ['allPvals = ' num2str(allpvals)]);

       
        depth = cell(numel(uGenotypes),1);
        cBiasFinal = cell(numel(uGenotypes),1);
        for genotype = numel(Cbiastable):-1:1 
            
            for recSite =1:numel(Cbiastable{genotype})
                depth{genotype,recSite} = cell(numel(ufreq),1);
                for sessNum =1:numel(Cbiastable{genotype}{recSite})
                    if isempty(Cbiastable{genotype}{recSite}{sessNum})
                        continue;
                    end              
                    sigUnits = {};
                    cbiasSess = cellfun(@(x) cell2mat(x), Cbiastable{genotype}{recSite}{sessNum}, 'UniformOutput',false);
                     if allpvals && numel(cbiasSess) >3 
                        pvalSess = cell2mat(cellfun(@(x) x(:,3), cbiasSess, 'UniformOutput',false));
                        if size(pvalSess,2) >3
                           pvalSess = pvalSess(:,1:3);
                        end
                        sigUnits = pvalSess < ops.plotAlpha;
                        sumlogic = sum(sigUnits,2);
                        sigUnits = sumlogic>0;
                        cbiasSess = cellfun(@(x) x(sigUnits, :), cbiasSess, 'UniformOutput',false);
                     else
                        if numel(cbiasSess)>3
                            sigUnits = cellfun(@(x) x(:,3)<ops.plotAlpha, cbiasSess, 'UniformOutput',false);                        
                            cbiasSess = cellfun(@(x,y) x(y, :), cbiasSess, sigUnits,'UniformOutput',false);        
                        else
                            sigUnits = cbiasSess{2}(:,3)<ops.plotAlpha;
                            cbiasSess{2} = cbiasSess{2}(sigUnits,:);
                        end

                     end

                     Cbiastable3{genotype}{recSite}{sessNum} = cbiasSess;
                    
                    
                    for stimDur =1:numel(Cbiastable{genotype}{recSite}{sessNum})

                        Cbiastable2{stimDur}{genotype}{recSite}{sessNum} = Cbiastable3{genotype}{recSite}{sessNum}{stimDur};
                        if ~isempty(Cbiastable2{stimDur}{genotype}{recSite}{sessNum})
                            
                            depth{genotype,recSite}{stimDur} =  [depth{genotype,recSite}{stimDur};...
                                Cbiastable2{stimDur}{genotype}{recSite}{sessNum}(:,1:2)];
%                             cBiasFinal{genotype,recSite}(end+1:end+height(Cbiastable2{stimDur}{genotype}{recSite}{sessNum}),stimDur) ...
%                                 = Cbiastable2{stimDur}{genotype}{recSite}{sessNum}(:,1);
                        end
                        
                    end


                end
            end
        end
    %  L1, 128 ± 1 μm; L2, 269 ± 2 μm; L3, 418 ± 3 μm; L4, 588 ± 3 μm; L5A, 708 ± 4 μm; L5B, 890 ± 5 μm; L6, 1154 ± 7 μm.

        
       for stimDur =1:numel(ufreq)
            g = figure(stimDur); clf;
            hold on
            for genotype =1:height(depth)
                ax = subplot(1, height(depth),genotype);
                data = depth{genotype}{stimDur};
    
%                 binEdgesY = min(data(:,2)):200:max(data(:,2));
                lowerBounds = [128/1154,418/1154,588/1154,708/1154,890/1154,max(data(:,2))];
                upperBounds = [min(data(:,2)),128/1154,418/1154,588/1154,708/1154,890/1154];
                binEdgesY = upperBounds + (lowerBounds-upperBounds)/2

                binEdgesX = -1:binWidth:1;
    
                hist3(data, ...
                    {binEdgesX,binEdgesY})
                title([uGenotypes{genotype} ' ' ufreq{stimDur} 'hz']);
                yticks(binEdgesY)
                yticklabels({'L1', 'L2/3', 'L4', 'L5A', 'L5B', 'L6'});
                ylim([min(data(:,2))-0.1,max(data(:,2))+0.1]);
                if genotype ==1
                    xlabel('Contra Bias','VerticalAlignment','baseline');
                    
                    ylabel('Cortical layers','VerticalAlignment','baseline');
                    zlabel('Number of Units');
                end
            end
            
            hold off
            savefig(g,fullfile(savePath,  ['pvals =' num2str(allpvals) ' ' inputrecSites{1} ' ' ufreq{stimDur} ' hz depth cbias histogram.fig']));
            saveas(g,fullfile(savePath,  ['pvals =' num2str(allpvals) ' ' inputrecSites{1} ' ' ufreq{stimDur} ' hz depth cbias histogram.png']));
       end



                    
                   
       
    end



        
end

function MakeLFPs(allVars, normalized, multi)
    % plot allMeanFR for all the stimDur
    
    load(allVars, 'LFPFinal', 'maxAdc', 'ops', 'bodysidefinal','ufreq','uGenotypes', 'inputrecSites', 'adcFinal', 'plotLims', 'sessInfoFinal', 'Cbiastable');
    load('G:\VC03_RoboKO\EphysPassiveStimSEs\chanMap.mat', 'chanMap');
    

    Cbiastable2 = {};
    sessCBiasNum = {};
    allpvals = 1;
    savePath = fullfile(ops.savePath, ['allPvals = ' num2str(allpvals)]);

   

    for genotype = numel(Cbiastable):-1:1 
        
        for recSite =1:numel(Cbiastable{genotype})
            for sessNum =1:numel(Cbiastable{genotype}{recSite})
                if isempty(Cbiastable{genotype}{recSite}{sessNum})
                    continue;
                end
                sigUnits = {};
                try
                    cbiasSess = cellfun(@(x) cell2mat(x), Cbiastable{genotype}{recSite}{sessNum}, 'UniformOutput',false);
                catch
                    keyboard;
                end
                 if allpvals && numel(cbiasSess) >3 
                    pvalSess = cell2mat(cellfun(@(x) x(:,3), cbiasSess, 'UniformOutput',false));
                    if size(pvalSess,2) >3
                       pvalSess = pvalSess(:,1:3);
                    end
                    sigUnits = pvalSess < ops.plotAlpha;
                    sumlogic = sum(sigUnits,2);
                    sigUnits = sumlogic>0;
                    cbiasSess = cellfun(@(x) x(sigUnits, :), cbiasSess, 'UniformOutput',false);
                 else
                    if numel(cbiasSess)>3
                        sigUnits = cellfun(@(x) x(:,3)<ops.plotAlpha, cbiasSess, 'UniformOutput',false);                        
                        cbiasSess = cellfun(@(x,y) x(y, :), cbiasSess, sigUnits,'UniformOutput',false);        
                    else
                        sigUnits = cbiasSess{2}(:,3)<ops.plotAlpha;
                        cbiasSess{2} = cbiasSess{2}(sigUnits,:);
                    end
                 end

                 Cbiastable3{genotype}{recSite}{sessNum} = cbiasSess;


                for stimDur =1:numel(Cbiastable{genotype}{recSite}{sessNum})

                    Cbiastable2{stimDur}{genotype}{recSite}{sessNum} = Cbiastable3{genotype}{recSite}{sessNum}{stimDur};

                    if ~isempty(Cbiastable2{stimDur}{genotype}{recSite}{sessNum})
                        contraU = numel(find(Cbiastable2{stimDur}{genotype}{recSite}{sessNum}(:,1)>0));
                        ipsiU = numel(find(Cbiastable2{stimDur}{genotype}{recSite}{sessNum}(:,1)<0));
                        zeroU = numel(find(Cbiastable2{stimDur}{genotype}{recSite}{sessNum}(:,1)==0));
                        if contraU > (ipsiU+ zeroU)
                            sessType{genotype}{recSite}{sessNum} = 'Contra';
                        elseif ipsiU > (contraU + zeroU)
                            sessType{genotype}{recSite}{sessNum} = 'Ipsi';
                        else
                            sessType{genotype}{recSite}{sessNum} = 'Both';
                        end
                    else
                        sessType{genotype}{recSite}{sessNum} = 'NA';
                    end

                end


            end
        end
    end

    

    for genotype = 1:numel(LFPFinal)

        for recSite = 1: numel(LFPFinal{genotype})
            contraSess = find(cell2mat(cellfun(@(x) strcmp(x,'Contra'), sessType{genotype}{recSite}, 'UniformOutput', false)));
            newTicks = 1280:-20:0;
            newTickLabels = cellstr(num2str(newTicks'));
            for sessNum = contraSess
                %plot contra sess such that depending on the side of
                %recordingm plot the contra stim on teh left column and
                %ipsi stim on the right column
                % Note: here LFPfinal are already as ipsi and contra. first
                % column is time, 2nd is ipsi and 3rd is contra
                
                LFPSess = LFPFinal{genotype}{recSite}{sessNum};
                
                sessInfo = sessInfoFinal{genotype}{recSite}{sessNum};
                if ~isempty(LFPSess)
                    if height(LFPSess) <4
                        stimDurs = {'20'};
                    else
                        stimDurs = {'10','20','40','80'};
                    end
                    close all;
                    windowSize ={};
                    plotLims ={};
                    
                   parfor stimDur = 1:numel(stimDurs)
                        windowSize{stimDur} = max(findDurationLFP(stimDurs{stimDur})/2, 0.025); %in s                
                        plotLims{stimDur} = [-windowSize{stimDur}/2, windowSize{stimDur}];
                        g{stimDur} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' stimDurs{stimDur} 'hz stim LFP ' ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1})],'NumberTitle','off'); clf;
                        g{stimDur}.WindowState = 'Maximized';
                        ind = (1:size(LFPSess{stimDur,2},1))*multi;
                        subplot(1,2,1, 'Parent', g{stimDur})
                        

                        
                        MPlot.PlotTraceLadder(LFPSess{stimDur,1}, LFPSess{stimDur,2}(chanMap), ind, 'Color', 'k');
                        xlim(plotLims{stimDur});
                        ylim([-10 70]*multi);                                              
                        set(gca, 'YTick', ind, 'YTickLabel', newTickLabels);
                        title('ipsi stim')
                        subplot(1,2,2, 'Parent', g{stimDur})
                        
                        if numel(LFPSess{stimDur,1}) ~= numel(LFPSess{stimDur,3}{1})
                            lastInds = min(numel(LFPSess{stimDur,1}), numel(LFPSess{stimDur,3}{1}));                            
                            tempContra = cellfun(@(x) x(1:lastInds), LFPSess{stimDur,3} , 'UniformOutput', false);                            
                            MPlot.PlotTraceLadder(LFPSess{stimDur,1}(1:lastInds), tempContra(chanMap), ind, 'Color', 'k');    
                        else
                            MPlot.PlotTraceLadder(LFPSess{stimDur,1}, LFPSess{stimDur,3}(chanMap), ind, 'Color', 'k');                            
                        end                    
                        xlim(plotLims{stimDur});
                        ylim([-10 70]*multi);
                        set(gca, 'YTick', ind, 'YTickLabel', newTickLabels);
                        title('contra stim')
                        set(g{stimDur}, 'Position', [3044,42,233,1074]);
                        sgtitle(['Contra sess ' stimDurs{stimDur} ' hz'])
                        if ~isfolder([ops.savePath normalized '\LFPs'])
                            mkdir([ops.savePath normalized '\LFPs']);
                        end
                        saveas(g{stimDur}, fullfile([ops.savePath normalized], 'LFPs', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' '  ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1}) ' ' stimDurs{stimDur} 'hz stim LFP_contrasess.fig']));
                        saveas(g{stimDur}, fullfile([ops.savePath normalized], 'LFPs', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' '  ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1}) ' ' stimDurs{stimDur} 'hz stim LFP_contrasess.png']));

                    end

                end


            end 

            ipsiSess = find(cell2mat(cellfun(@(x) strcmp(x,'Ipsi'), sessType{genotype}{recSite}, 'UniformOutput', false)));
            for sessNum = ipsiSess
                %plot contra sess such that depending on the side of
                %recordingm plot the contra stim on teh left column and
                %ipsi stim on the right column
                % Note: here LFPfinal are already as ipsi and contra. first
                % column is time, 2nd is ipsi and 3rd is contra
                
                LFPSess = LFPFinal{genotype}{recSite}{sessNum};
                
                sessInfo = sessInfoFinal{genotype}{recSite}{sessNum};
                if ~isempty(LFPSess)
                    if height(LFPSess) <4
                        stimDurs = {'20'};
                    else
                        stimDurs = {'10','20','40','80'};
                    end
                    close all;
                    windowSize ={};
                    plotLims ={};
                    parfor stimDur = 1:numel(stimDurs)
                        windowSize{stimDur} = max(findDurationLFP(stimDurs{stimDur})/2, 0.025); %in s                
                        plotLims{stimDur} = [-windowSize{stimDur}/2, windowSize{stimDur}];
                        g{stimDur} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' stimDurs{stimDur} 'hz stim LFP ' ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1})],'NumberTitle','off'); clf;
                        g{stimDur}.WindowState = 'Maximized';
                        ind = (1:size(LFPSess{stimDur,2},1))*multi;
                        subplot(1,2,1, 'Parent', g{stimDur})
                        MPlot.PlotTraceLadder(LFPSess{stimDur,1}, LFPSess{stimDur,2}(chanMap), ind, 'Color', 'k');
                        xlim(plotLims{stimDur});
                        ylim([-10 70]*multi);
                        set(gca, 'YTick', ind, 'YTickLabel', newTickLabels);
                        title('ipsi stim')
                        subplot(1,2,2, 'Parent', g{stimDur})
                         if numel(LFPSess{stimDur,1}) ~= numel(LFPSess{stimDur,3}{1})
                            lastInds = min(numel(LFPSess{stimDur,1}), numel(LFPSess{stimDur,3}{1}));                            
                            tempContra = cellfun(@(x) x(1:lastInds), LFPSess{stimDur,3} , 'UniformOutput', false);                            
                            MPlot.PlotTraceLadder(LFPSess{stimDur,1}(1:lastInds), tempContra(chanMap), ind, 'Color', 'k');    
                        else
                            MPlot.PlotTraceLadder(LFPSess{stimDur,1}, LFPSess{stimDur,3}(chanMap), ind, 'Color', 'k');                            
                        end   
                        xlim(plotLims{stimDur});
                        ylim([-10 70]*multi);
                        set(gca, 'YTick', ind, 'YTickLabel', newTickLabels);
                        title('contra stim')
                        sgtitle(['Ipsi sess ' stimDurs{stimDur} ' hz'])
                        set(g{stimDur}, 'Position', [3044,42,233,1074]);
                        if ~isfolder([ops.savePath normalized '\LFPs'])
                            mkdir([ops.savePath normalized '\LFPs']);
                        end
                        saveas(g{stimDur}, fullfile([ops.savePath normalized], 'LFPs', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' '  ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1}) ' ' stimDurs{stimDur} 'hz stim LFP_ipsisess.fig']));
                        saveas(g{stimDur}, fullfile([ops.savePath normalized], 'LFPs', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' '  ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1}) ' ' stimDurs{stimDur} 'hz stim LFP_ipsisess.png']));

                    end

                end


            end 

            bothSess = find(cell2mat(cellfun(@(x) strcmp(x,'Both'), sessType{genotype}{recSite}, 'UniformOutput', false)));
            for sessNum = bothSess
                %plot contra sess such that depending on the side of
                %recordingm plot the contra stim on teh left column and
                %ipsi stim on the right column
                % Note: here LFPfinal are already as ipsi and contra. first
                % column is time, 2nd is ipsi and 3rd is contra
                
                LFPSess = LFPFinal{genotype}{recSite}{sessNum};
                
                sessInfo = sessInfoFinal{genotype}{recSite}{sessNum};
                if ~isempty(LFPSess)
                    if height(LFPSess) <4
                        stimDurs = {'20'};
                    else
                        stimDurs = {'10','20','40','80'};
                    end
                    close all;
                    windowSize ={};
                    plotLims ={};
                    parfor stimDur = 1:numel(stimDurs)
                        windowSize{stimDur} = max(findDurationLFP(stimDurs{stimDur})/2, 0.025); %in s                
                        plotLims{stimDur} = [-windowSize{stimDur}/2, windowSize{stimDur}];
                        g{stimDur} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' stimDurs{stimDur} 'hz stim LFP ' ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1})],'NumberTitle','off'); clf;
                        g{stimDur}.WindowState = 'Maximized';
                        ind = (1:size(LFPSess{stimDur,2},1))*multi;
                        subplot(1,2,1, 'Parent', g{stimDur})
                        MPlot.PlotTraceLadder(LFPSess{stimDur,1}, LFPSess{stimDur,2}(chanMap), ind, 'Color', 'k');
                        xlim([-0.01 plotLims{stimDur}(2)]);
                        ylim([-10 70]*multi);
                        set(gca, 'YTick', ind, 'YTickLabel', newTickLabels);
                        title('ipsi stim')
                        subplot(1,2,2, 'Parent', g{stimDur})
                         if numel(LFPSess{stimDur,1}) ~= numel(LFPSess{stimDur,3}{1})
                            lastInds = min(numel(LFPSess{stimDur,1}), numel(LFPSess{stimDur,3}{1}));                            
                            tempContra = cellfun(@(x) x(1:lastInds), LFPSess{stimDur,3} , 'UniformOutput', false);                            
                            MPlot.PlotTraceLadder(LFPSess{stimDur,1}(1:lastInds), tempContra(chanMap), ind, 'Color', 'k');    
                        else
                            MPlot.PlotTraceLadder(LFPSess{stimDur,1}, LFPSess{stimDur,3}(chanMap), ind, 'Color', 'k');                            
                        end   
                        xlim([-0.01 plotLims{stimDur}(2)]);
%                         xlim([-5,30]/1000);
                        ylim([-10 70]*multi);
                        set(gca, 'YTick', ind, 'YTickLabel', newTickLabels);
                        title('contra stim')
                        sgtitle(['Both sess ' stimDurs{stimDur} ' hz'])
                        set(g{stimDur}, 'Position', [3044,42,233,1074]);
                        if ~isfolder([ops.savePath normalized '\LFPs'])
                            mkdir([ops.savePath normalized '\LFPs']);
                        end
                        saveas(g{stimDur}, fullfile([ops.savePath normalized], 'LFPs', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' '  ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1}) ' ' stimDurs{stimDur} 'hz stim LFP_bothsess.fig']));
                        saveas(g{stimDur}, fullfile([ops.savePath normalized], 'LFPs', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' '  ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1}) ' ' stimDurs{stimDur} 'hz stim LFP_bothsess.png']));

                    end

                end


            end 


        end
    end



end
