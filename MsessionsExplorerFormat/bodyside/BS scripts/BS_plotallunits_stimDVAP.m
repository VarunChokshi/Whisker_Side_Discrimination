%% plot all units of same recording site for stim trials
clear all

[readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\stimSEs', 'Select source SEs');
sigma = 0.005;
FRlims = [-0.25 0.25];
recSiteTypes = {'Left wS1', 'Right wS1', 'Left wM1', 'Right wM1'};
plotType = {'WT Left wS1', 'WT Right wS1', 'KO Left wS1', 'KO Right wS1', 'WT Left wM1', 'WT Right wM1', 'KO Left wM1', 'KO Right wM1'};
trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
trials{2} = {'Stim_Som_Left', 'Stim_Som_Right', 'Stim_Som_Left_Opto', 'Stim_Som_Right_Opto'}; 
%
folderSigma = '0_005';
bins = -0.5:0.0025:2.5;
windowSize = 0.15; %in seconds 
preWindow = [-windowSize-0.01,-0.01];
postWindow = [0,windowSize]; 
plotcolors = {[1 0 0], [0 0 1], [0 1 0], [0 1 1], [0.8 0.2 0.2], [1 0 1]};

close all


rootParts = strsplit(seDir, '\');
rootPath = fullfile(rootParts{1:end-2});
savePath = fullfile(rootPath,'Figures\StimSess\AllUnits', folderSigma);
  
if ~exist('savePath', 'Dir')
    mkdir(savePath)
end

figureSerial = ones(numel(plotType),1);

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
    

    APMap = se.userData.sessionInfo.APStim;
    DVMap = se.userData.sessionInfo.DVStim;
    
   
       

    
    
    
    
    behavData = se.GetTable('behavValue');
    responses = behavData.response;
    abortTrials = find(cell2mat(responses) == 3);        
    se = BS.Preprocess.removeTrials(abortTrials,se);
    behavData = se.GetTable('behavValue');
    
    
    %only keep miss trials in se
    responses = behavData.response;
    trialTypes = unique(behavData.trialType);
    missTrials = find(~cell2mat(responses));
    keepTrials = find(cell2mat(responses));
    se =  BS.Preprocess.removeTrials(keepTrials,se);
    
    
    behavData = se.GetTable('behavValue');
    
    % divide se by AP vs DV trialmap
    trialDivide = {APMap{1}, DVMap{1}};
    trialMap = find(~strcmp(trialDivide, 'NA')); 
    
    for trialType = 1:numel(trialDivide)
        if strcmp(trialDivide{trialType}, 'NA')
            trialDir{trialType} = nan;
            continue;
        else
            trialSplit = strsplit(trialDivide{trialType},':');
            if strcmp(trialSplit{2}(1:end-1), {'end'})
                
                trialDir{trialType} = str2num(trialSplit{1}): se.numEpochs;
            else
                trialDir{trialType} = str2num(trialSplit{1}): str2num(trialSplit{2});
            end
        end
    end
    
    seAP = BS.Preprocess.keepTrials(trialDir{1}, se);
    seDV = BS.Preprocess.keepTrials(trialDir{2},se);
            
    
    
    
  
    

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
    
    APTime = seAP.GetTable('behavTime');
    DVTime = seDV.GetTable('behavTime');
    
    APData = seAP.GetTable('behavValue');
    DVData = seDV.GetTable('behavValue');

    for trialType = 1:numel(trialTypes)
        
        
        trialIndAP = find(strcmp(trialTypes{trialType}, APData.trialType));
        trialIndDV = find(strcmp(trialTypes{trialType}, DVData.trialType));

        seS(1,trialType) = BS.Preprocess.keepTrials(trialIndAP, seAP);
        seS(2,trialType) = BS.Preprocess.keepTrials(trialIndDV, seDV);
        
     end   
    
    spikeTimes = se.GetTable('spikeTime');
    channelInds = se.userData.spikeInfo.unit_channel_ind;  
    chanDepth = 20:20:1280; %(in um)
    chanMap = se.userData.spikeInfo.channel_map;   
    for sei =0:height(seS)-1
            
        tempFigureserial = figureSerial;    
        for result = 1:2
            figureSerial = tempFigureserial;
            seDup = seS(sei+1, result).Duplicate();
            if seDup.numEpochs==0
                continue;
            end
            behavTime = seDup.GetTable('behavTime');
            spikeTimes = seDup.GetTable('spikeTime');
            ind = 1:height(spikeTimes);
            bins{sei+1, result} = -0.5:0.0025:2.5;
            spikes = seDup.ResampleEventTimes('spikeTime', bins{sei+1, result}, 'Normalization', 'countdensity');
            for i = 1 : width(spikes)
                    spikes.(i) = cellfun(@(x) MNeuro.Filter1(x, 1/0.0025, 'gaussian', sigma), spikes.(i), 'UniformOutput', false);
            end

            for unitNum =1:size(spikeTimes,2)
                clearvars unitSpikes;
                unitChannelId = channelInds(unitNum);
                unitDepth = chanDepth(chanMap(unitChannelId));

        
                unitSpikes = spikes(ind,unitNum+1);           
                unitSpikes = table2cell(unitSpikes);

                for i = 1:size(unitSpikes,1)
                    if size(unitSpikes{i}, 1)>1
                        unitSpikes{i} = unitSpikes{i}';
                    end
                end

                unitSpikes = cell2mat(unitSpikes);

                try
                    [meanFR{figureNum+4*(sei)}{figureSerial(figureNum+4*(sei)), result}, sdFR{figureNum+4*(sei)}{figureSerial(figureNum+4*(sei)), result}, ...
                         seFR{figureNum+4*(sei)}{figureSerial(figureNum+4*(sei)), result}, ciFR{figureNum+4*(sei)}{figureSerial(figureNum+4*(sei)), result}]...
                         = MMath.MeanStats(unitSpikes, 1);    

                catch
                    maxFR{figureNum+4*(sei)}{figureSerial(figureNum+4*(sei)),result} = 0;
                    meanFR{figureNum+4*(sei)}{figureSerial(figureNum+4*(sei)), result+1} = unitDepth;
                    ciFR{figureNum+4*(sei)}{figureSerial(figureNum+4*(sei)), result+1} = unitDepth;

                    figureSerial(figureNum+4*(sei)) =  figureSerial(figureNum+4*(sei)) +1;
                    continue;

                end
                if any(ismember(trialTypes{trialType}, 'L'))
                    stimOnset{figureNum+4*(sei)}{figureSerial(figureNum+4*(sei)), result} = max(cell2mat(behavTime.leftOnset));
                    stimOffset{figureNum+4*(sei)}{figureSerial(figureNum+4*(sei)), result} = max(cell2mat(behavTime.leftOffset));
                else
                    stimOnset{figureNum+4*(sei)}{figureSerial(figureNum+4*(sei)), result} = max(cell2mat(behavTime.rightOnset));
                    stimOffset{figureNum+4*(sei)}{figureSerial(figureNum+4*(sei)), result} = max(cell2mat(behavTime.rightOffset));
                end
                maxFR{figureNum+4*(sei)}{figureSerial(figureNum+4*(sei)), result} = max(meanFR{figureNum+4*(sei)}{figureSerial(figureNum+4*(sei)), result})+1;
                meanFR{figureNum+4*(sei)}{figureSerial(figureNum), 3} = unitDepth;
                ciFR{figureNum+4*(sei)}{figureSerial(figureNum), 3} = unitDepth;
                figureSerial(figureNum+4*(sei)) =  figureSerial(figureNum+4*(sei)) +1;
            end         
           
        end            
        
    end              
             
end


% sort each meanFR cell by depth


meanFR = cellfun(@(x) sortrows(x,3), meanFR, 'UniformOutput', false);
ciFR = cellfun(@(x) sortrows(x,3), ciFR, 'UniformOutput', false);
bins = -0.5:0.0025:2.5;

close all
for figNums = 1:size(plotType,2)
    for sei =0
        f(figNums+4*sei) = figure();clf

        % plot all units now
        plotRows = ceil(height(meanFR{figNums+4*sei})/10);
        for unitNum = 1:height(meanFR{figNums+4*sei})
            color = {'r','b'};

            h = subplot(plotRows,10,unitNum, 'Parent', f(figNums+4*sei));
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
