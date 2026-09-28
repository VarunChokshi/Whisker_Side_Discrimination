%% plot all units of same recording site together
clear all

[readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\StimSEs', 'Select source SEs');
sigma = 0.005;
FRlims = [-0.1 0.2];
recSiteTypes = {'Left wS1', 'Left Contra S1', 'Left Ipsi S1', 'Right Contra S1',};
plotType = {'WT units', 'KO Left Contra units', 'KO Left Ipsi units', 'KO Right Contra'};
trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
trials{2} = {'Stim_Som_Left', 'Stim_Som_Right', 'Stim_Som_Left_Opto', 'Stim_Som_Right_Opto'}; 
%%
folderSigma = '0_005';
close all
clearvars bins
f(1) = figure();clf

f(2) = figure(); clf

f(3) = figure();clf

f(4) = figure();clf
rootParts = strsplit(seDir, '\');
rootPath = fullfile(rootParts{1:end-2});
savePath = fullfile(rootPath,'Figures\StimSess\AllUnits', folderSigma);
  
if ~exist('savePath', 'Dir')
    mkdir(savePath)
end

figureSerial=[1,1,1,1];
for sessNum = 1:size(readPaths,1)    
    seParts = strsplit(seNames{sessNum}, ' ');
    
  
    
    load(readPaths{sessNum});
%     seArray{sessNum} = se;
    recSite{sessNum} = se.userData.sessionInfo.recSite;
    animalID{sessNum} =  se.userData.sessionInfo.MouseName;
    sessDate{sessNum} = se.userData.sessionInfo.seshDate;
    
    figureNum = (find(ismember(recSiteTypes, se.userData.sessionInfo.recSite{1}))); 
    
    tRef = se.GetReferenceTime();
    check = diff(tRef);

    fprintf('%s\n\n', readPaths{sessNum});
    tRef = se.GetReferenceTime();
    check = diff(tRef);

    if any(check<0)
        disp('tRefs are not monotonically increasing');
    end
    try

        trialMap = se.userData.sessionInfo.trialMap;
    catch
        trialMap{1} = [];
    end
    
    %get total number of units
    if ~isempty(trialMap{1})
        trialSplit = strsplit(trialMap{1},':');
        if any(strcmp(trialSplit{2}(1:end-1), 'end'))
            trialInd = [str2double(trialSplit{1}) : se.numEpochs];
        else
            trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}(1:end-1))];
        end
        allTrials = 1:se.numEpochs;
        removeTrials = find(~ismember(allTrials, trialInd));
        se = BS.Preprocess.removeTrials(removeTrials,se);
     end

       

    
    
    behavData = se.GetTable('behavValue');
    stimRight = behavData.rightStimType{end};
    stimLeft= behavData.leftStimType{end};
    
    
    responses = behavData.response;
    abortTrials = find(cell2mat(responses) == 3);        
    se = BS.Preprocess.removeTrials(abortTrials,se);
    behavData = se.GetTable('behavValue');
    
    

    responses = behavData.response;
    trialTypes = unique(behavData.trialType);
    missTrials = find(~cell2mat(responses));
    keepTrials = find(cell2mat(responses));
    seMiss =  BS.Preprocess.removeTrials(keepTrials,se);
    se = BS.Preprocess.removeTrials(missTrials,se);
    
    behavData = se.GetTable('behavValue');
    missData = seMiss.GetTable('behavValue');
   
    

    if any(cell2mat(cellfun(@(x) any(ismember(x,'C')), trialTypes, 'UniformOutput',false)))
        stims = {'Left Stim', 'Right Stim'};
    else

        if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
            trialTypes = trials{2};
            stims = {'Left Stim', 'Right Stim', 'Left Stim + Opto', 'Right Stim + Opto'};
        else
            trialTypes = trials{1};
             stims = {'Left Stim', 'Right Stim'};
        end
    end
    if se.numEpochs>0
        behavTime = se.GetTable('behavTime');
        
    elseif seMiss.numEpochs>0
        behavTime = seMiss.GetTable('behavTime');
    end

    for trialType = 1:numel(trialTypes)
        
        trialTypeIndCorrect = find(strcmp(trialTypes{trialType}, behavData.trialType) & behavData.result);
        
        trialTypeIndInCorrect = find(strcmp(trialTypes{trialType}, behavData.trialType) & ~(behavData.result));
        missInd = find(strcmp(trialTypes{trialType}, missData.trialType));
        
        seCorrect = BS.Preprocess.keepTrials(trialTypeIndCorrect, se);
        seMissTemp = BS.Preprocess.keepTrials(missInd, seMiss);
        seIncorrect = BS.Preprocess.keepTrials(trialTypeIndInCorrect, se);
       
        
       
        seS(1:3, trialType) = {seCorrect, seMissTemp, seIncorrect};
        

    end   
    
    spikeTimes = se.GetTable('spikeTime');
    channelInds = se.userData.spikeInfo.unit_channel_ind;  
    chanDepth = 20:20:1280; %(in um)
    chanMap = se.userData.spikeInfo.channel_map;         
    for unitNum =1:size(spikeTimes,2)
        clearvars unitSpikes;
        
        sei =2;
        unitChannelId = channelInds(unitNum);
        unitDepth = chanDepth(chanMap(unitChannelId));

        
        for result = 1:2
            seDup = seS{sei, result}.Duplicate();
            
            spikeTimes = seDup.GetTable('spikeTime');
            ind = 1:height(spikeTimes);
            bins{sei, result} = -0.5:0.0025:2.5;
            spikes = seDup.ResampleEventTimes('spikeTime', bins{sei, result}, 'Normalization', 'countdensity');
            for i = 1 : width(spikes)
                    spikes.(i) = cellfun(@(x) MNeuro.Filter1(x, 1/0.0025, 'gaussian', sigma), spikes.(i), 'UniformOutput', false);
            end
            
            unitSpikes = spikes(ind,unitNum+1);           
            unitSpikes = table2cell(unitSpikes);

            for i = 1:size(unitSpikes,1)
                if size(unitSpikes{i}, 1)>1
                    unitSpikes{i} = unitSpikes{i}';
                end
            end
            
            unitSpikes = cell2mat(unitSpikes);
            
            try
                [meanFR{figureNum}{figureSerial(figureNum), result}, sdFR{figureNum}{figureSerial(figureNum), result}, ...
                     seFR{figureNum}{figureSerial(figureNum), result}, ciFR{figureNum}{figureSerial(figureNum), result}] = MMath.MeanStats(unitSpikes, 1);    
                
            catch
                maxFR{figureNum}{figureSerial(figureNum),result} = 0;
                meanFR{figureNum}{figureSerial(figureNum), result+1} = unitDepth;
                ciFR{figureNum}{figureSerial(figureNum), result+1} = unitDepth;

                figureSerial(figureNum) =  figureSerial(figureNum) +1;
                continue;
                
            end
            if any(ismember(trialTypes{trialType}, 'L'))
                stimOnset{figureNum}{figureSerial(figureNum), result} = max(cell2mat(behavTime.leftOnset));
                stimOffset{figureNum}{figureSerial(figureNum), result} = max(cell2mat(behavTime.leftOffset));
            else
                stimOnset{figureNum}{figureSerial(figureNum), result} = max(cell2mat(behavTime.rightOnset));
                stimOffset{figureNum}{figureSerial(figureNum), result} = max(cell2mat(behavTime.rightOffset));
            end
            maxFR{figureSerial(figureNum), result} = max(meanFR{figureNum}{figureSerial(figureNum), result})+1;
        end         
        meanFR{figureNum}{figureSerial(figureNum), result+1} = unitDepth;
        ciFR{figureNum}{figureSerial(figureNum), result+1} = unitDepth;

        figureSerial(figureNum) =  figureSerial(figureNum) +1;
        
    end    
          
             
end
%sort each meanFR cell by depth
meanFR = cellfun(@(x) sortrows(x,3), meanFR, 'UniformOutput', false);
ciFR = cellfun(@(x) sortrows(x,3), ciFR, 'UniformOutput', false);
bins = -0.5:0.0025:2.5;

close all
for figNums = 1:size(plotType,2)
    f(figureNum) = figure();clf
    % plot all units now
    plotRows = ceil(height(meanFR{figNums})/10);
    for unitNum = 1:height(meanFR{figNums})
        color = {'r','b'};
        
        h = subplot(plotRows,10,unitNum, 'Parent', f(figureNum));
        hold(h, 'on');
        for result = 1:2
            
            plot(bins(1:size(meanFR{figNums}{unitNum, result},2)),meanFR{figNums}{unitNum, result}, color{result}, 'LineWidth', 1);
            
            if ~isempty(meanFR{figNums}{unitNum, result})
                
                MPlot.ErrorShade(bins(1:size(meanFR{figNums}{unitNum, result},2)), meanFR{figNums}{unitNum, result}, ...
                        ciFR{figNums}{unitNum, result}(2,:),ciFR{figNums}{unitNum, result}(1,:), 'color',color{result}, 'Alpha', 0.3, 'IsRelative', false);
                
            end
        end

%         ylim([0,max(cell2mat(maxFR{figNums}{:,result}), [], 'all')]); 
        yLimits = get(gca,'YLim');
        MPlot.Blocks([stimOnset{figNums}{unitNum, 1} stimOffset{figNums}{unitNum, 1}], [yLimits(2)*0.98, yLimits(2)], ...
                        color{1}, 'FaceAlpha', 0.6);    
        MPlot.Blocks([stimOnset{figNums}{unitNum, 2} stimOffset{figNums}{unitNum, 2}], [yLimits(2)*0.95,yLimits(2)*0.97], ...
                        color{2}, 'FaceAlpha', 0.6); 
        xlabel('epoch time (s)');
        ylabel('FR');  
        xlim(FRlims);
       
        title(['Depth ' num2str(meanFR{figNums}{unitNum,3}) ' \mum']);

        box off  
        
        hold(h, 'off');
        sgtitle(plotType{figNums})
    end
        
end



for i =1:size(plotType,2)
    f(i) = figure(i);
    
    hAxes   = findobj(allchild(f(i)), 'flat', 'Type', 'axes');
    plotNums = ceil(numel(hAxes)/10);
    a = get(f(i), 'position');    
    set(f(i), 'position', [0 0 200*10 85*plotNums])
    sgtitle(plotType{i});
    savefig(f(i),fullfile(savePath,  [plotType{i} ' units.fig']));
%     MPlot.SavePNG(f(i), fullfile(savePath,  [plotType{i} ' units.pdf']));
    exportgraphics(f(i), fullfile(savePath,  [plotType{i} ' units.png']));
end

%% only plot significantly deltaFR units
%% plot all units of same recording site together
clear all

[readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\IntanSEs', 'Select source SEs');
sigma = 0.005;
FRlims = [-0.5 0.5];
recSiteTypes = {'Left wS1', 'Left Contra S1', 'Left Ipsi S1', 'Right Contra S1',};
plotType = {'WT units', 'KO Left Contra units', 'KO Left Ipsi units', 'KO Right Contra'};
trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
trials{2} = {'Stim_Som_Left', 'Stim_Som_Right', 'Stim_Som_Left_Opto', 'Stim_Som_Right_Opto'}; 
%%  
folderSigma = '0_005';
bins = -0.5:0.0025:2.5;
windowSize = 0.25; %in seconds 
preWindow = [-windowSize-0.01,-0.01];
postWindow = [0,windowSize]; 
plotcolors = {[1 0 0], [0 0 1], [0 1 0], [0 1 1], [0.8 0.2 0.2], [1 0 1]};
statAlpha = 0.05;


close all

f(1) = figure();clf

f(2) = figure(); clf

f(3) = figure();clf

f(4) = figure();clf
rootParts = strsplit(seDir, '\');
rootPath = fullfile(rootParts{1:end-2});
savePath = fullfile(rootPath,'Figures\StimSess\AllUnits', folderSigma);
  
if ~exist('savePath', 'Dir')
    mkdir(savePath)
end

figureSerial=[1,1,1,1];
for sessNum = 1:size(readPaths,1)    
    seParts = strsplit(seNames{sessNum}, ' ');
    
  
    
    load(readPaths{sessNum});
%     seArray{sessNum} = se;
    recSite{sessNum} = se.userData.sessionInfo.recSite;
    animalID{sessNum} =  se.userData.sessionInfo.MouseName;
    sessDate{sessNum} = se.userData.sessionInfo.seshDate;
    
    figureNum = (find(ismember(recSiteTypes, se.userData.sessionInfo.recSite{1}))); 
    
    tRef = se.GetReferenceTime();
    check = diff(tRef);

    fprintf('%s\n\n', readPaths{sessNum});
    tRef = se.GetReferenceTime();
    check = diff(tRef);

    if any(check<0)
        disp('tRefs are not monotonically increasing');
    end
    try

        trialMap = se.userData.sessionInfo.trialMap;
    catch
        trialMap{1} = [];
    end

    if ~isempty(trialMap{1})
        trialSplit = strsplit(trialMap{1},':');
        if any(strcmp(trialSplit{2}(1:end-1), 'end'))
            trialInd = [str2double(trialSplit{1}) : se.numEpochs];
        else
            trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}(1:end-1))];
        end
        allTrials = 1:se.numEpochs;
        removeTrials = find(~ismember(allTrials, trialInd));
        se = BS.Preprocess.removeTrials(removeTrials,se);
     end

       

    
    
    behavData = se.GetTable('behavValue');
    stimRight = behavData.rightStimType{end};
    stimLeft= behavData.leftStimType{end};
    
    
    responses = behavData.response;
    abortTrials = find(cell2mat(responses) == 3);        
    se = BS.Preprocess.removeTrials(abortTrials,se);
    behavData = se.GetTable('behavValue');
    
    

    responses = behavData.response;

    missTrials = find(~cell2mat(responses));
    keepTrials = find(cell2mat(responses));
    seMiss =  BS.Preprocess.removeTrials(keepTrials,se);
    se = BS.Preprocess.removeTrials(missTrials,se);
    
    behavData = se.GetTable('behavValue');
    missData = seMiss.GetTable('behavValue');
   
    
    trialTypes = unique(behavData.trialType);

    if any(cell2mat(cellfun(@(x) any(ismember(x,'C')), trialTypes, 'UniformOutput',false)))
        stims = {'Left Stim', 'Right Stim'};
    else

        if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
            trialTypes = trials{2};
            stims = {'Left Stim', 'Right Stim', 'Left Stim + Opto', 'Right Stim + Opto'};
        else
            trialTypes = trials{1};
             stims = {'Left Stim', 'Right Stim'};
        end
    end
    
    behavTime = se.GetTable('behavTime');

    for trialType = 1:numel(trialTypes)
        trialTypeIndCorrect = find(strcmp(trialTypes{trialType}, behavData.trialType) & behavData.result);
        
        trialTypeIndInCorrect = find(strcmp(trialTypes{trialType}, behavData.trialType) & ~(behavData.result));
        missInd = find(strcmp(trialTypes{trialType}, missData.trialType));
        
        seCorrect = BS.Preprocess.keepTrials(trialTypeIndCorrect, se);
        seMissTemp = BS.Preprocess.keepTrials(missInd, seMiss);
        seIncorrect = BS.Preprocess.keepTrials(trialTypeIndInCorrect, se);
       
        keyboard;
        if any(ismember(trialTypes{trialType}, 'L'))
            stimOnset{figureNum}{figureSerial(figureNum), trialType} = max(cell2mat(behavTime.leftOnset));
            stimOffset{figureNum}{figureSerial(figureNum), trialType} = max(cell2mat(behavTime.leftOffset));
        else
            stimOnset{figureNum}{figureSerial(figureNum), trialType} = max(cell2mat(behavTime.rightOnset));
            stimOffset{figureNum}{figureSerial(figureNum), trialType} = max(cell2mat(behavTime.rightOffset));
        end
        seS(1:3, trialType) = {seCorrect, seMissTemp, seIncorrect};
        

    end   
    
    spikeTimes = se.GetTable('spikeTime');
    channelInds = se.userData.spikeInfo.unit_channel_ind;  
    chanDepth = 20:20:1280; %(in um)
    chanMap = se.userData.spikeInfo.channel_map;         
    for unitNum =1:size(spikeTimes,2)
        clearvars unitSpikes;
        
        sei =2;
        unitChannelId = channelInds(unitNum);
        unitDepth = chanDepth(chanMap(unitChannelId));

        
        for result = 1:2
            seDup = seS{sei, result}.Duplicate();
            
            %post-pre                
            spikeTimes = seDup.GetTable('spikeTime');
            ind = 1:height(spikeTimes);
            preSpikes = seDup.ResampleEventTimes('spikeTime', preWindow);
            postSpikes = seDup.ResampleEventTimes('spikeTime', postWindow);
            preUnitSpikes = preSpikes(ind,unitNum+1); 
            preUnitSpikes = cell2mat(table2cell(preUnitSpikes));
            postUnitSpikes = postSpikes(ind,unitNum+1); 
            postUnitSpikes = cell2mat(table2cell(postUnitSpikes));
            dUnitSpikes{result} = (postUnitSpikes - preUnitSpikes)/windowSize;
            if ~isempty(dUnitSpikes{1}) & ~isempty(dUnitSpikes{1})
                [H, pValue(result)] = ttest2(dUnitSpikes{result}, zeros(size(dUnitSpikes{result},1),1), ...
                    'tail', 'both', 'Alpha', statAlpha);
            else
                pValue(result) = 1;
            end

            spikes = seDup.ResampleEventTimes('spikeTime', bins, 'Normalization', 'countdensity');
            for i = 1 : width(spikes)
                    spikes.(i) = cellfun(@(x) MNeuro.Filter1(x, 1/0.0025, 'gaussian', sigma), spikes.(i), 'UniformOutput', false);
            end
            
            unitSpikes = spikes(ind,unitNum+1);           
            unitSpikes = table2cell(unitSpikes);

            for i = 1:size(unitSpikes,1)
                if size(unitSpikes{i}, 1)>1
                    unitSpikes{i} = unitSpikes{i}';
                end
            end
            
            unitSpikes = cell2mat(unitSpikes);
            
            try
                [meanFR{figureNum}{figureSerial(figureNum), result}, sdFR{figureNum}{figureSerial(figureNum), result}, ...
                     seFR{figureNum}{figureSerial(figureNum), result}, ciFR{figureNum}{figureSerial(figureNum), result}] = MMath.MeanStats(unitSpikes, 1);    
                
            catch
                maxFR{figureNum}{figureSerial(figureNum),result} = 0;
                meanFR{figureNum}{figureSerial(figureNum), result+1} = unitDepth;
                ciFR{figureNum}{figureSerial(figureNum), result+1} = unitDepth;

                figureSerial(figureNum) =  figureSerial(figureNum) +1;
                continue;
                
            end
            maxFR{figureSerial(figureNum), result} = max(meanFR{figureNum}{figureSerial(figureNum), result})+1;
        end    
        if any(pValue < statAlpha)

            meanFR{figureNum}{figureSerial(figureNum), result+1} = unitDepth;
            ciFR{figureNum}{figureSerial(figureNum), result+1} = unitDepth;
    
            figureSerial(figureNum) =  figureSerial(figureNum) +1;
        else
            meanFR{figureNum}(figureSerial(figureNum),:) =[];
            ciFR{figureNum}(figureSerial(figureNum),:) =[];
            maxFR(figureSerial(figureNum), :) =[];          
        end
        
    end    
          
             
end
%sort each meanFR cell by depth
meanFR = cellfun(@(x) sortrows(x,3), meanFR, 'UniformOutput', false);
ciFR = cellfun(@(x) sortrows(x,3), ciFR, 'UniformOutput', false);
bins = -0.5:0.0025:2.5;

close all
for figNums = 1:size(plotType,2)
    f(figureNum) = figure();clf
    % plot all units now
    plotRows = ceil(height(meanFR{figNums})/10);
    for unitNum = 1:height(meanFR{figNums})
        color = {'r','b'};
        
        h = subplot(plotRows,10,unitNum, 'Parent', f(figureNum));
        hold(h, 'on');
        for result = 1:2
            
            plot(bins(1:size(meanFR{figNums}{unitNum, result},2)),meanFR{figNums}{unitNum, result}, color{result}, 'LineWidth', 1);
            
            if ~isempty(meanFR{figNums}{unitNum, result})
                
                MPlot.ErrorShade(bins(1:size(meanFR{figNums}{unitNum, result},2)), meanFR{figNums}{unitNum, result}, ...
                        ciFR{figNums}{unitNum, result}(2,:),ciFR{figNums}{unitNum, result}(1,:), 'color',color{result}, 'Alpha', 0.3, 'IsRelative', false);
                
            end
        end

%         ylim([0,max(cell2mat(maxFR{figNums}{:,result}), [], 'all')]); 
        yLimits = get(gca,'YLim');
        MPlot.Blocks([stimOnset{1} stimOffset{1}], [yLimits(2)*0.98, yLimits(2)], ...
                        color{1}, 'FaceAlpha', 0.6);    
        MPlot.Blocks([stimOnset{2} stimOffset{2}], [yLimits(2)*0.95,yLimits(2)*0.97], ...
                        color{2}, 'FaceAlpha', 0.6); 
        xlabel('epoch time (s)');
        ylabel('FR');  
        xlim(FRlims);
       
        title(['Depth ' num2str(meanFR{figNums}{unitNum,3}) ' \mum']);

        box off  
        
        hold(h, 'off');
        sgtitle(plotType{figNums})
    end
        
end
plotTypeSizes = cellfun(@(x) height(x), meanFR, 'UniformOutput', false);
maxPlots = max(cell2mat(plotTypeSizes));
scaleFactor = 1100/ceil(maxPlots/10);
for i =1:size(plotType,2)
    f(i) = figure(i);
    
    hAxes   = findobj(allchild(f(i)), 'flat', 'Type', 'axes');
    plotNums = ceil(numel(hAxes)/10);
    a = get(f(i), 'position');    
    set(f(i), 'position', [0 0 200*10 scaleFactor*plotNums])
    sgtitle(plotType{i});
    savefig(f(i),fullfile(savePath,  [plotType{i} ' significant units.fig']));
%     MPlot.SavePNG(f(i), fullfile(savePath,  [plotType{i} ' units.pdf']));
    exportgraphics(f(i), fullfile(savePath,  [plotType{i} ' significant units.png']));
end
