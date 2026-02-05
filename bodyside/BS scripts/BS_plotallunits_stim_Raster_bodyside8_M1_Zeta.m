


%% Plot units separated by whisker stim duration. Contra vs ipsi, combine for left vs right hemisphere recording . combine plotsession_maps
% It also has LFPs
% Stims are taken as only the first deflection of all frequencies 
% clear all
% 
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\StimSEs', 'Select source SEs');

clear all
animalID = {'VC030209', 'VC030208','VC030113', 'VC030211', 'VC030114', 'VC030115', 'VC030213'};
% animalID = {'VC030213'};
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
        case 'StimSEs_wM1'          
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

ops.redo =0;
ops.numcyc = 3;
ops.constantWindow = 0.3; 
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

ops.binWidth = 0.05; % this is for histograms. 
% FRlims = [-0.15 0.15];
ops.tWins = [-1.5, 1.5];
animalIds = unique(dataFileTb.animalId);
ops.folderSigma = [strrep(['StatAlpha ' num2str(0.005)], '.', '_') ' numcyc=' num2str(ops.numcyc)];
% windowSize = 0.15; %in seconds 

% ops.stimDurs = {'150','100','050','020','010','005'}; %in ms

% ops.stimDurs = {'150'}; %in ms
ops.universalWindow =1;
if ops.universalWindow
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\firstcyc',[strjoin(animalIds, '_') '_NP\AllUnitswM1',FRbin], ['zeta test UniveralWindow selective' ]);
else
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\firstcyc',[strjoin(animalIds, '_') '_NP\AllUnitswM1',FRbin], ['zeta test paired selective']);
end




%% Make variables for raster FR rate, etc
Getcompositevars(dataFileTb, ops);


%% plot Rasters
MakeFigures(fullfile(ops.savePath, "allVars.mat"), ops.plotAlpha);
 

 %%  
 MakeFiguresNoannotation(fullfile(ops.savePath, "allVars.mat"), ops.plotAlpha,ops.savePath);


%% Calculate sig units for each GT and then do binomial test. 
BinomialIpsiResponsive(fullfile(ops.savePath, "allVars.mat"), ops.plotAlpha,ops.savePath);


%% Plot Cbiastable
MakeCbiasFigures(fullfile(ops.savePath, "allVars.mat"), ops.binWidth, ops.plotAlpha);


%% Plot LFPs intan

%  ops.savePath = [ops.savePath ' Normalized'];
normalized = '';
multiplier = 100;
MakeLFPs(fullfile(ops.savePath, "allVars.mat"), normalized, multiplier);
    
%% Helper function

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

function [dblZetaP_pb,vecLatencies_pb,sZETA_pb,sRate_pb] = ZetaTest(spikeTimes, stimOnsetTimes, stimOffsetTimes, savePath)
    matEventTimes = cat(2,stimOnsetTimes,stimOffsetTimes);
    dblZetaP_pb = cell(width(spikeTimes),1);
    vecLatencies_pb = cell(width(spikeTimes),1);
    sZETA_pb = cell(width(spikeTimes),1);
    sRate_pb = cell(width(spikeTimes),1);
    
    dblUseMaxDur = median(diff(stimOnsetTimes)); %median of trial-to-trial durations
    intResampNum = 50; %50 random resamplings should give us a good enough idea if this cell is responsive. If it's close to 0.05, we should increase this #.
    pintPlot = 3;%what do we want to plot?(0=nothing, 1=inst. rate only, 2=traces only, 3=raster plot as well, 4=adds latencies in raster plot)
    intLatencyPeaks = 4; %how many latencies do we want? 1=ZETA, 2=-ZETA, 3=peak, 4=first crossing of peak half-height
    vecRestrictRange = [0 0.4];%do we want to restrict the peak detection to for example the time during stimulus? Then put [0 1] here.
    boolDirectQuantile = false;%if true; uses the empirical null distribution rather than the Gumbel approximation. Note that in this case the accuracy of your p-value is limited by the # of resamplings
    dblBaselineDuration = 0.5;
    dblBaselineDurationMs = dblBaselineDuration*1000;
    matEventTimesWithPrecedingBaseline = matEventTimes - dblBaselineDuration;
    close all
    parfor unitNum = 1:width(spikeTimes)
        
        if iscell(spikeTimes{1,unitNum})
            %then run ZETA with the new times
            [dblZetaP_pb{unitNum},vecLatencies_pb{unitNum},sZETA_pb{unitNum},sRate_pb{unitNum}] = ...
                getZeta(cell2mat(spikeTimes{1,unitNum}),matEventTimesWithPrecedingBaseline,dblUseMaxDur,intResampNum,pintPlot,intLatencyPeaks,vecRestrictRange,boolDirectQuantile);
    
            
            drawnow;hFig = gcf;
            for intPlot=1:numel(hFig.Children)
                %adjust x-ticks
                if contains(hFig.Children(intPlot).XLabel.String,'Time ')
                    set(hFig.Children(intPlot),'xticklabel',cellfun(@(x) num2str(str2double(x)-dblBaselineDuration),get(hFig.Children(intPlot),'xticklabel'),'UniformOutput',false));
                end
                %adjust timings in title
                strTitle = hFig.Children(intPlot).Title.String;
                [vecStart,vecStop]=regexp(strTitle,'[=].*?[m][s]');
                for intEntry=1:numel(vecStart)
                    strOldNumber=hFig.Children(intPlot).Title.String((vecStart(intEntry)+1):(vecStop(intEntry)-2));
                    strTitle = strrep(strTitle,strcat('=',strOldNumber,'ms'),strcat('=',num2str(str2double(strOldNumber)-dblBaselineDurationMs),'ms'));
                end
                hFig.Children(intPlot).Title.String = strTitle;
            end
            
            %here we adjust the times in the variables that getZeta returns
            vecLatencies_pb{unitNum} = vecLatencies_pb{unitNum} - dblBaselineDuration;
            sZETA_pb{unitNum}.vecSpikeT = sZETA_pb{unitNum}.vecSpikeT - dblBaselineDuration;
            sRate_pb{unitNum}.vecT = sRate_pb{unitNum}.vecT - dblBaselineDuration;
            sRate_pb{unitNum}.dblPeakTime = sRate_pb{unitNum}.dblPeakTime - dblBaselineDuration;
            sRate_pb{unitNum}.dblOnset = sRate_pb{unitNum}.dblOnset - dblBaselineDuration;
    
         
            savefig(hFig, fullfile(savePath, ['UnitNum ' num2str(unitNum) '.fig']));
            saveas(hFig, fullfile(savePath, ['UnitNum ' num2str(unitNum) '.png']));
        end
    end

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


function Getcompositevars(dataFileTb, ops)
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

                    
                    seBackup = se.Duplicate();

                    % work on zeta test to get if a unit is significant
                    se.RemoveEpochs(~ismember(1:se.numEpochs, trialInd));

                    % find trials with 80hz freq
                    behavTime = se.GetTable('behavTime');
                    eightyHzOnset = nan(height(behavTime),1);
                    eightyHzOffset = nan(height(behavTime),1);
                    
                    
                    stimTypes = se.GetColumn('behavValue', 'leftStimType');
                    eightyHzTrials = cell2mat(cellfun(@(x) any(ismember(x,'8')), stimTypes, 'UniformOutput', false));
                    eightyHzOnset(eightyHzTrials)  = behavTime.stimOnset(eightyHzTrials);
                    behavTime.eightyHzOnset = eightyHzOnset;
                    stimOffset = nan(height(behavTime),1);
                    parfor trialNums = 1:height(behavTime)
                        stimOffset(trialNums)= max(cell2mat(behavTime{trialNums,1:4}));
                    end
                    eightyHzOffset(eightyHzTrials)  = stimOffset(eightyHzTrials);
                    behavTime.eightyHzOffset = eightyHzOffset;

                    se.RemoveTable('behavTime');
                    se.SetTable('behavTime', behavTime, 'eventTimes');
                    se.SetReferenceTime(se.GetReferenceTime);
                    
                    se.SliceSession(0, 'absolute');
                    
                    spikeTimes = se.GetTable('spikeTime');
                   

                    recordingHemisphere= se.userData.sessionInfo.recSite{1};
                    
                    % find trials with simtr freq =80
                    behavTime = se.GetTable('behavTime');
                    eightyHzOnsets = cell2mat(behavTime.eightyHzOnset);
                    eightyHzOffsets = cell2mat(behavTime.eightyHzOffset);

                    if sum(ismember(recordingHemisphere, 'Left'))>3
                        contraStimOnsets = cell2mat(se.GetColumn('behavTime', 'rightOnset'));
                        contraStimOnsets = sort(contraStimOnsets, 'ascend');
                        contraStimOnsets(ismember(contraStimOnsets, eightyHzOnsets))=[];
                        
                        ipsiStimOnsets = cell2mat(se.GetColumn('behavTime', 'leftOnset'));
                        ipsiStimOnsets = sort(ipsiStimOnsets, 'ascend');
                        ipsiStimOnsets(ismember(ipsiStimOnsets, eightyHzOnsets))=[];

                        contraStimOffsets = cell2mat(se.GetColumn('behavTime', 'rightOffset'));
                        contraStimOffsets = sort(contraStimOffsets, 'ascend');
                        contraStimOffsets(ismember(contraStimOffsets, eightyHzOffsets))=[];

                        ipsiStimOffsets = cell2mat(se.GetColumn('behavTime', 'leftOffset'));
                        ipsiStimOffsets = sort(ipsiStimOffsets, 'ascend');
                        ipsiStimOffsets(ismember(ipsiStimOffsets, eightyHzOffsets))=[];
                    else
                        %remove contraStimOnsets same as 80Hzonsets and
                        %same for offsets. 

                        contraStimOnsets = cell2mat(se.GetColumn('behavTime', 'leftOnset'));
                        contraStimOnsets = sort(contraStimOnsets, 'ascend');
                        contraStimOnsets(ismember(contraStimOnsets, eightyHzOnsets))=[];
                        
                        ipsiStimOnsets = cell2mat(se.GetColumn('behavTime', 'rightOnset'));
                        ipsiStimOnsets = sort(ipsiStimOnsets, 'ascend');
                        ipsiStimOnsets(ismember(ipsiStimOnsets, eightyHzOnsets))=[];

                        contraStimOffsets = cell2mat(se.GetColumn('behavTime', 'leftOffset'));
                        contraStimOffsets = sort(contraStimOffsets, 'ascend');
                        contraStimOffsets(ismember(contraStimOffsets, eightyHzOffsets))=[];

                        ipsiStimOffsets = cell2mat(se.GetColumn('behavTime', 'rightOffset'));
                        ipsiStimOffsets = sort(ipsiStimOffsets, 'ascend');
                        ipsiStimOffsets(ismember(ipsiStimOffsets, eightyHzOffsets))=[];
                    end

                    saveFigAdd = fullfile(savePath, 'ZetaStatFigs', [se.userData.sessionInfo.MouseName{1} ' '  ...
                            datestr(se.userData.sessionInfo.seshDate{1}, 'yyyymmdd') se.userData.sessionInfo.subId{1}],'Contra');
                    
                    if ~isfolder(saveFigAdd) || ops.redo
                        mkdir(saveFigAdd);
                    

                        [cdblZetaP_pb,cvecLatencies_pb,csZETA_pb,csRate_pb] = ZetaTest(spikeTimes,contraStimOnsets, contraStimOffsets,saveFigAdd);
                        save(fullfile(saveFigAdd, 'cZetaStats.mat'), 'cdblZetaP_pb','cvecLatencies_pb','csZETA_pb','csRate_pb');
                    else
                        load(fullfile(saveFigAdd, 'cZetaStats.mat'), 'cdblZetaP_pb','cvecLatencies_pb','csZETA_pb','csRate_pb');
                    end
                    saveFigAdd = fullfile(savePath, 'ZetaStatFigs', [se.userData.sessionInfo.MouseName{1} ' '  ...
                                datestr(se.userData.sessionInfo.seshDate{1}, 'yyyymmdd') se.userData.sessionInfo.subId{1}],'Ipsi');
                    if ~isfolder(saveFigAdd) || ops.redo
                        mkdir(saveFigAdd);                    
                        [idblZetaP_pb,ivecLatencies_pb,isZETA_pb,isRate_pb] = ZetaTest(spikeTimes,ipsiStimOnsets, ipsiStimOffsets,saveFigAdd);
                        save(fullfile(saveFigAdd, 'iZetaStats.mat'), 'idblZetaP_pb','ivecLatencies_pb','isZETA_pb','isRate_pb');
                    else
                        load(fullfile(saveFigAdd, 'iZetaStats.mat'), 'idblZetaP_pb','ivecLatencies_pb','isZETA_pb','isRate_pb');
                    end


                  
                    cdblZetaP_pb = cell2mat(cdblZetaP_pb);
                    idblZetaP_pb = cell2mat(idblZetaP_pb);

                    allSigUnitNums = find(min(cdblZetaP_pb, idblZetaP_pb)<ops.statAlpha);
                    contraSigUniNums = find(cdblZetaP_pb<ops.statAlpha);
                    ipsiSigUniNums = find(idblZetaP_pb<ops.statAlpha);
                    if ~isempty(allSigUnitNums)
                    

                    
    
    
                        
                        se = seBackup.Duplicate();
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
                            chanMap = se.userData.sessionInfo.channel_map.chanMap;
                            [~, chanPos] = ismember(channelInds,chanMap);
                            unitChanDepth= chanDepth(chanPos);
                            
                        end
                        
                        stimTypes = leftStimTypes;
                        uStimTypes = unique(stimTypes);
                        ufreq = unique(cellfun(@(x) x(5:6),uStimTypes, 'UniformOutput', false)); % for gettign just the unique frequencies irrespective of the cycles
                        
                        
                        adc = cell(1,numel(ufreq));
                      
    
                        sessInfoTable = se.userData.sessionInfo;
                        sessInfoFinal{genotype}{recSite}{sessNum} =  se.userData.sessionInfo;
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
        
                          
                            
    
                         
                            windowSize{stimDur} = ops.constantWindow;
                          
                            
    
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
                            
    
                            pvalL = [];
                            pvalR = [];
                            unitDepth = [];
                            spikeTimes = {};
                            pvalstimDur =[];
                            bodysides = [];
                            meanFR = {};
                            cbiases = {};
                            pValIpsi = [];
                            pValContra = [];
                            zValIpsi = [];
                            zValContra = [];
                            statL ={};
                            statR = {};
                            
                            parfor ii = 1: numel(allSigUnitNums)
                                unitNum = allSigUnitNums(ii);
                                
                               
                                [pvalL(ii),~, statL{ii}] = signrank(preMeanFRL{stimDur}(:,unitNum), postMeanFRL{stimDur}(:,unitNum), ...
                                    'tail', 'both', 'Alpha', statAlpha, 'method', 'approximate');
                                [pvalR(ii),~, statR{ii}] = signrank(preMeanFRR{stimDur}(:,unitNum), postMeanFRR{stimDur}(:,unitNum), ...
                                    'tail', 'both', 'Alpha', statAlpha, 'method', 'approximate');
                     
                                unitDepth(ii) = unitChanDepth(unitNum);
                                meanFRtime =  MMath.MeanStats(cell2mat(FRtime{stimDur}), 1);
                            
                                if sum(ismember(sessRecSite, 'Left'))==4
                                    uSpikesIpsi = spikeLeft(:,unitNum);
                                    uSpikesContra = spikeRight(:,unitNum);
                                    [meanFRI, ~, ~,...
                                    ciFRI]= MMath.MeanStats(cell2mat(FRLeft{stimDur}(:,unitNum)), 1);
    
                                    pValIpsi(ii) = pvalL(ii);
                                    pValContra(ii) = pvalR(ii);
                                    zValIpsi(ii) = idblZetaP_pb(unitNum);
                                    zValContra(ii) = cdblZetaP_pb(unitNum);
                                    
    
                                    [meanFRC, ~, ~,...
                                    ciFRC]= MMath.MeanStats(cell2mat(FRRight{stimDur}(:,unitNum)), 1);
                                else
                                    uSpikesIpsi = spikeRight(:,unitNum);
                                    uSpikesContra = spikeLeft(:,unitNum);

                                    [meanFRI, ~, ~,...
                                    ciFRI]= MMath.MeanStats(cell2mat(FRRight{stimDur}(:,unitNum)), 1);

                                    pValIpsi(ii) = pvalR(ii);
                                    pValContra(ii) = pvalL(ii);
                                    zValIpsi(ii) = idblZetaP_pb(unitNum);
                                    zValContra(ii) = cdblZetaP_pb(unitNum);
    
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
                                pvalstimDur(ii) = min(pvalL(ii), pvalR(ii));   
                                C = abs(postSpikesContra - preSpikesContra);
                                I = abs(postSpikesIpsi - preSpikesIpsi);
    
                                Cbias = (C-I)/(C+I);
    %                             cbiases(unitNum,:) = Cbias;
                                spikeTimes(ii,:) = {uSpikesIpsi, uSpikesContra,...
                                        penetrationDepth-unitDepth(ii),min(zValIpsi(ii), zValContra(ii)), Cbias};
                                meanFR(ii,:) = {meanFRtime, meanFRI, meanFRC, ciFRI, ciFRC, ...
                                        penetrationDepth-unitDepth(ii), min(zValIpsi(ii), zValContra(ii)), Cbias};
                                bodysides(ii) = bodyside7;
                                cbiases(ii,:) = {Cbias, ...
                                            penetrationDepth-unitDepth(ii), min(zValIpsi(ii), zValContra(ii))};
                            end
                            
                            
                            % make final variables to plot containing all data
                            pvalsTemp = [pvalstimDur', pValContra', pValIpsi', zValContra', zValIpsi'];
                            pvals{genotype}{recSite}{pstimDur}(end+1:end+numel(pvalstimDur),:) = pvalsTemp;                      
                            bodysidefinal{genotype}{recSite}{pstimDur}(end+1:end+numel(bodysides)) = bodysides;
                            Cbiastable{genotype}{recSite}{sessNum}{pstimDur} = cbiases;
                            adcFinal{genotype}{recSite}{pstimDur}(end+1:end+size(adc{stimDur},1),1:size(adc{stimDur},2)) = adc{stimDur};
                            allSpikeTimes{genotype}{recSite}{pstimDur}(end+1:end+size(spikeTimes,1),:) = spikeTimes;  
                            allMeanFR{genotype}{recSite}{pstimDur}(end+1:end+size(meanFR,1),:) = meanFR;                        
                       end             
                  
                   % go to next session of the same recording site and
                   % genotype

                    end
                        
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

    save([savePath '\allVars.mat']);    

%   
        
        

end

function BinomialIpsiResponsive(allVars,plotAlpha, savePath)
    load(allVars, 'ops', 'ufreq', 'uGenotypes',  'pvals');
    close all   
    ops.plotAlpha = plotAlpha;
    ops.savePath = savePath;
    % pvals is pvalmin, pvalcontra,pvalipsi
    % just signify according to allpvals
    for allpvals = 0:0         
        fid = fopen(fullfile( ops.savePath,['allPvals = ' num2str(allpvals) ' IpsiResponseBinomial.txt']), 'w');
        saveVar = fullfile( ops.savePath,['allPvals = ' num2str(allpvals) ' IpsiResponseBinomial.mat']);
        contraUnits = cell(1,2);
        ipsiUnits = cell(1,2);
        variableNames = {'ipsiUnitNum', 'TotalSigUnits', 'BinomalTest'};
        ipsiFrac =cell(2,1);        
        for genotype = numel(pvals):-1:1 
           

            for recSite =numel(pvals{genotype}):numel(pvals{genotype})
                if ~isempty(pvals{genotype}{recSite})
                    pvalAll = pvals{genotype}{recSite};
                    emptypval = cellfun(@isempty, pvalAll);
                    pvalAll(emptypval) =[];
                    if allpvals
                        
                        pvalSess = cell2mat(cellfun(@(x) x(:,1), pvalAll, 'UniformOutput',false));
                        if size(pvalSess,2) >3
                           pvalSess = pvalSess(:,1:3);
                        end
                        sigUnits = pvalSess < ops.plotAlpha;
                        sumlogic = sum(sigUnits,2);
                        sigUnits = sumlogic>0;


                        pvalAll = cellfun(@(x) x(sigUnits, :), pvalAll, 'UniformOutput',false);
                        ipsiUnits{genotype} = cellfun(@(x) x(x(:,3)<ops.plotAlpha,:), pvalAll, 'UniformOutput', false);
                        contraUnits{genotype} = cellfun(@(x) x(x(:,2)<ops.plotAlpha,:), pvalAll, 'UniformOutput', false);
                        totalUnits = cellfun(@(x) height(x), pvalAll, 'UniformOutput', false);
                       
                        ipsiFrac{genotype,1} = cellfun(@(x) height(x),  ipsiUnits{genotype},  'Uni', false);
                        ipsiFrac{genotype,2} = totalUnits; 
                        
                    else
%                         sigUnits = cellfun(@(x) min(x(:,1)<ops.plotAlpha, pvalAll, 'UniformOutput', false);
%                         pvalAll = cellfun(@(x,y) x(y,:), pvalAll, sigUnits, 'UniformOutput', false);
                        
                        ipsiUnits{genotype} = cellfun(@(x) x(x(:,5)<ops.plotAlpha,:), pvalAll, 'UniformOutput', false);
                        contraUnits{genotype} = cellfun(@(x) x(x(:,4)<ops.plotAlpha,:), pvalAll, 'UniformOutput', false);
                        totalUnits = cellfun(@(x) height(x), pvalAll, 'UniformOutput', false);

                       
                        ipsiFrac{genotype,1} = cellfun(@(x) height(x),  ipsiUnits{genotype}, 'Uni', false);
                        ipsiFrac{genotype,2} = totalUnits; 
                    end
                end
            end 
            
            
            
            
        end

        fprintf(fid, 'Binomial probability for following the frequencies:\n ');
        for stim=1:numel(ufreq)
            ipsiFrac{1,3}{stim}=1- binocdf(ipsiFrac{1,1}{stim} - 1, ipsiFrac{1,2}{stim}, ipsiFrac{2,1}{stim}/ ipsiFrac{2,2}{stim});
            fprintf(fid, [ufreq{stim} ' hz: %.10f\n'], ipsiFrac{1,3}{stim});
            fprintf(fid, 'Unit number for KO ipsi: %d KO total: %d WT ipsi: %d WT total: %d\n', ...
                ipsiFrac{1,1}{stim}, ipsiFrac{1,2}{stim}, ipsiFrac{2,1}{stim}, ipsiFrac{2,2}{stim});
        end
        fclose(fid);  
        
        ipsiFracTable = cell2table(ipsiFrac, "VariableNames",variableNames, 'RowNames', uGenotypes);
        save(saveVar, 'ipsiFracTable');            
    end
end

function MakeFigures(allVars, plotAlpha)
    % plot allMeanFR for all the stimDur
    
    load(allVars, 'allSpikeTimes', 'maxAdc', 'ops', 'bodysidefinal','ufreq','uGenotypes', 'inputrecSites', 'adcFinal', 'plotLims', 'pvals', 'allMeanFR');
    ops.plotAlpha = plotAlpha;
    pvalsBackup = pvals;

    for genotype = 1: numel(allSpikeTimes)
            
        for recSite =1:numel(allSpikeTimes{genotype})
            maxAdcgenotype = maxAdc{genotype}{recSite};
            if isempty(maxAdcgenotype)
                continue;
            end
            [maxadcfig rows] = max(maxAdcgenotype(1,:));
             if maxadcfig <0.1
                fM = 10e4;
        %                 fM = 1;
            else
                fM =10;
                
            end
            
            maxadcfig = maxadcfig*fM; 
            close all
        
            % done for left as the first one and right as the second
            % spikeTimes
            color = {'b', 'r'};
            
            
            
        
            for allpvals = 0:ops.allpvals
                spikeTimes ={};
                sigUnits = {};
                pvals = pvalsBackup;
                if allpvals
                    
                   
                    sessions7 = find(bodysidefinal{genotype}{recSite}{2}==1);
        
                    sessions8 = find(bodysidefinal{genotype}{recSite}{2}==0);
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
                    
                    % need to get the 20hz only sessions out               
                    empty = cell2mat(cellfun(@(x) isempty(x), pvals{genotype}{recSite}, 'UniformOutput', false));
                    
                    pvals{genotype}{recSite}(empty) = [];
                    pvals{genotype}{recSite} = cellfun(@(x) x(:,1), pvals{genotype}{recSite}, 'UniformOutput', false);         
                    
                    pvals2 = cell2mat(pvals{genotype}{recSite});
                    pvalsLogic = pvals2<ops.plotAlpha;
                    pvalsLogiwwc = pvalsLogic(:,1:3);
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
                            MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,1}{i}, i*ones(numel(spikeTimes{stimDur}{unitNum,1}{i}),1) ,1, 'orientation', 'vertical', ...
                                'linestyle', '-','color', color{1}, 'linewidth', 1);
                        end
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
                    
                        yLimits = get(gca,'YLim');                    
                        plot(adcFinal{genotype}{recSite}{stimDur}(1,:), (adcFinal{genotype}{recSite}{stimDur}(2,:)*fM) +  totalTrials+5+1, ...
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
                    
                        % plot FR subplots here

                       figure(gg{stimDur});  
                        %sort each meanFR cell by depth                           
                        hh = subplot(plotRows,15,unitNum, 'Parent', gg{stimDur});                                  
                        hold(hh, 'on');                               
                        plot(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 2}, ...
                            color{1}, 'LineWidth', 1);
                        plot(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 3}, ...
                            color{2}, 'LineWidth', 1);                                
                        if ~isempty(meanFR{stimDur}{unitNum, 2})                                
                            MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 2}, meanFR{stimDur}{unitNum, 4}(2,:), ...
                                meanFR{stimDur}{unitNum, 4}(1,:), 'color',color{1}, 'Alpha', 0.3, 'IsRelative', false);                                        
                        end            
                        if ~isempty(meanFR{stimDur}{unitNum, 4})                                
                            MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 3}, meanFR{stimDur}{unitNum, 5}(2,:), ...
                                meanFR{stimDur}{unitNum, 5}(1,:), 'color',color{2}, 'Alpha', 0.3, 'IsRelative', false);                                                        
                        end                        
                        yLimits = get(gca,'YLim');                      
                        plot(adcFinal{genotype}{recSite}{stimDur}(1,:), (adcFinal{genotype}{recSite}{stimDur}(2,:)*fM) +  yLimits(2), ...
                            'k', 'lineWidth', 1);
                        yLimits = get(gca,'YLim');
                        MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
        %                 xlabel('epoch time (s)');
        %                 ylabel('FR');  
                        yLimits = get(gca,'YLim');
                        ylim([0, yLimits(2)]);
                        xlim(plotLims{stimDur}); 
                        title({[num2str(spikeTimes{stimDur}{unitNum,3}) ' \mum']},{['Cbias = '  num2str(spikeTimes{stimDur}{unitNum,5})]});                    

                        title({[num2str(meanFR{stimDur}{unitNum,6}) ' \mum']},{['Cbias = '  num2str(meanFR{stimDur}{unitNum,8})]});                    
                        box off  
                        outerpos = get(hh,'OuterPosition');
                        ti = get(hh,'TightInset');
                        left = outerpos(1) + ti(1);
                        bottom = outerpos(2) + ti(2);
                        ax_width = outerpos(3) - ti(1) - ti(3);
                        ax_height = outerpos(4) - ti(2) - ti(4)-0.01;
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

function MakeFiguresNoannotation(allVars, plotAlpha, savePath)
    % plot allMeanFR for all the stimDur
    
    load(allVars, 'allSpikeTimes', 'maxAdc', 'ops', 'bodysidefinal','ufreq','uGenotypes', 'inputrecSites', 'adcFinal', 'plotLims', 'pvals', 'allMeanFR');
    ops.plotAlpha = plotAlpha;
    ops.savePath = savePath;
    pvalsBackup = pvals;

    for genotype = 1: numel(allSpikeTimes)
            
        for recSite =1:numel(allSpikeTimes{genotype})
            maxAdcgenotype = maxAdc{genotype}{recSite};
            if isempty(maxAdcgenotype)
                continue;
            end
            [maxadcfig rows] = max(maxAdcgenotype(1,:));
             if maxadcfig <0.1
%                 fM = 10e4;
                        fM = 10;
            else
                fM =10;
                
            end
            
            maxadcfig = maxadcfig*fM; 
            close all
        
            % done for left as the first one and right as the second
            % spikeTimes
            color = {'b', 'r'};
            
            
            
        
            for allpvals = 0:0
                spikeTimes ={};
                sigUnits = {};
                pvals = pvalsBackup;
                if allpvals
                    
                   
                    sessions7 = find(bodysidefinal{genotype}{recSite}{2}==1);
        
                    sessions8 = find(bodysidefinal{genotype}{recSite}{2}==0);
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
                    
                    % need to get the 20hz only sessions out               
                    empty = cell2mat(cellfun(@(x) isempty(x), pvals{genotype}{recSite}, 'UniformOutput', false));
                    
                    pvals{genotype}{recSite}(empty) = [];
                    pvals{genotype}{recSite} = cellfun(@(x) x(:,1), pvals{genotype}{recSite}, 'UniformOutput', false);         
                    
                    pvals2 = cell2mat(pvals{genotype}{recSite});
                    pvalsLogic = pvals2<ops.plotAlpha;
                    pvalsLogiwwc = pvalsLogic(:,1:3);
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
                            MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,1}{i}, i*ones(numel(spikeTimes{stimDur}{unitNum,1}{i}),1) ,1, 'orientation', 'vertical', ...
                                'linestyle', '-','color', color{1}, 'linewidth', 1);
                        end
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
                    
                        yLimits = get(gca,'YLim');                    
                        plot(adcFinal{genotype}{recSite}{stimDur}(1,:), (adcFinal{genotype}{recSite}{stimDur}(2,:)*fM) +  totalTrials+5+1, ...
                            'k', 'lineWidth', 1);                            
                        yLimits = get(gca,'YLim');
                        MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--', ...
                            'color',[0.5 0.5 0.5], 'linewidth', 1);
    %                     xlabel('epoch time (s)');
    %                     ylabel('Trials');  
                        yLimits = get(gca,'YLim');
                        ylim([0, yLimits(2)])
                        xlim(plotLims{stimDur});                            
%                         title({[num2str(spikeTimes{stimDur}{unitNum,3}) ' \mum']},{['Cbias = '  num2str(spikeTimes{stimDur}{unitNum,5})]});                    
                        box off  
                        outerpos = get(h,'OuterPosition');
                        ti = get(h,'TightInset');
                        left = outerpos(1) + ti(1);
                        bottom = outerpos(2) + ti(2);
                        ax_width = outerpos(3) - ti(1) - ti(3);
                        ax_height = outerpos(4) - ti(2) - ti(4)-0.01;
                        set(h,'Position',[left bottom ax_width ax_height], 'fontsize', 10);                            
                        hold(h, 'off');
                    
                        % plot FR subplots here

                       figure(gg{stimDur});  
                        %sort each meanFR cell by depth                           
                        hh = subplot(plotRows,15,unitNum, 'Parent', gg{stimDur});                                  
                        hold(hh, 'on');                               
                        plot(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 2}, ...
                            color{1}, 'LineWidth', 1);
                        plot(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 3}, ...
                            color{2}, 'LineWidth', 1);                                
                        if ~isempty(meanFR{stimDur}{unitNum, 2})                                
                            MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 2}, meanFR{stimDur}{unitNum, 4}(2,:), ...
                                meanFR{stimDur}{unitNum, 4}(1,:), 'color',color{1}, 'Alpha', 0.3, 'IsRelative', false);                                        
                        end            
                        if ~isempty(meanFR{stimDur}{unitNum, 4})                                
                            MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 3}, meanFR{stimDur}{unitNum, 5}(2,:), ...
                                meanFR{stimDur}{unitNum, 5}(1,:), 'color',color{2}, 'Alpha', 0.3, 'IsRelative', false);                                                        
                        end                        
                        yLimits = get(gca,'YLim');                      
                        plot(adcFinal{genotype}{recSite}{stimDur}(1,:), (adcFinal{genotype}{recSite}{stimDur}(2,:)*fM) +  yLimits(2), ...
                            'k', 'lineWidth', 1);
                        yLimits = get(gca,'YLim');
                        MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
        %                 xlabel('epoch time (s)');
        %                 ylabel('FR');  
                        yLimits = get(gca,'YLim');
                        ylim([0, yLimits(2)]);
                        xlim(plotLims{stimDur}); 

%                         title({[num2str(meanFR{stimDur}{unitNum,6}) ' \mum']},{['Cbias = '  num2str(meanFR{stimDur}{unitNum,8})]});                    
                        box off  
                        outerpos = get(hh,'OuterPosition');
                        ti = get(hh,'TightInset');
                        left = outerpos(1) + ti(1);
                        bottom = outerpos(2) + ti(2);
                        ax_width = outerpos(3) - ti(1) - ti(3);
                        ax_height = outerpos(4) - ti(2) - ti(4)-0.01;
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



function MakeCbiasFigures(allVars, binWidth, plotAlpha)
    load(allVars, 'Cbiastable', 'ops', 'bodysidefinal','ufreq','uGenotypes', 'inputrecSites',  'pvals');
    close all   
    
    % just signify according to allpvals
    ops.plotAlpha = plotAlpha;
    for allpvals = 0:ops.allpvals  
        Cbiastable2 = {};
        sessCBiasNum = {};
        savePath = fullfile(ops.savePath, ['allPvals = ' num2str(allpvals)]);

       

        for genotype = numel(Cbiastable):-1:1 
            
            for recSite =1:numel(Cbiastable{genotype})
                if ~isempty(Cbiastable{genotype}{recSite})
                    for sessNum =1:numel(Cbiastable{genotype}{recSite})
                              
                        sigUnits = {};
                        if isempty(Cbiastable{genotype}{recSite}{sessNum})
                            continue;
                        end
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
        end
    
                    






                    
                   
        for stimDur =1:numel(ufreq)
            g1 = figure(3*stimDur-2);clf;
            
            g2 = figure(3*stimDur-1);clf;
            g3 = figure(3*stimDur); clf;
    
            maxunits = 0;
            for genotype = numel(Cbiastable2{stimDur}):-1:1 
                
                for recSite =1:numel(Cbiastable2{stimDur}{genotype})
                    getCbiasTable = Cbiastable2{stimDur}{genotype}{recSite};
                    if isempty(getCbiasTable)
                        continue;
                    end
                    try
                        zeroSess = cellfun(@isempty, getCbiasTable);
                    catch
                        keyboard;
                    end
                    getCbiasTable = getCbiasTable(~zeroSess);
                    
%                     getCbiasTable = cellfun(@cell2mat, getCbiasTable', 'UniformOutput', false);
                    getCbiasTable = cell2mat(getCbiasTable');
    
                    getSessbiasNum = sessCBiasNum{stimDur}{genotype}{recSite};
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
            sgtitle([inputrecSites{recSite} ' ' ufreq{stimDur} ' counts']);
    
            figure(3*stimDur);
            sgtitle([inputrecSites{recSite} ' ' ufreq{stimDur} ' probability']);
    
            figure(3*stimDur-2);
            hold on
            plot(-1:maxunits+1,-1:maxunits+1, 'k-.')
            legend([s1,s2,s3,s4], {'KOcontra', 'KOIpsi','KOequal','WT'});
            xlabel('Number of contra units in a session');
            ylabel('Number of ipsi units in a session');
            xlim([-1,maxunits+1])
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
                        windowSize{stimDur} = findDurationLFP(stimDurs{stimDur})*2; %in s                
                        plotLims{stimDur} = [-windowSize{stimDur}, windowSize{stimDur}];
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
                        windowSize{stimDur} = findDurationLFP(stimDurs{stimDur})*2; %in s              
                        plotLims{stimDur} = [-windowSize{stimDur}, windowSize{stimDur}]
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
                        windowSize{stimDur} = findDurationLFP(stimDurs{stimDur})*2; %in s                         
                        plotLims{stimDur} = [-windowSize{stimDur}, windowSize{stimDur}]
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

