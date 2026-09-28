
%% Select all stimSEs to be plotted

clear all

[readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\stimSEs', 'Select source SEs');

%% plot all deltaFR units
% plot all units of same recording site together
sigma = 0.005;
statAlpha = 0.99999;
FRlims = [-0.25 0.25];
folderSigma = strrep(['PlotSigma ' num2str(sigma) ' StatAlpha ' num2str(statAlpha)], '.', '_');
binSize = 0.00025;
bins = -0.5:binSize:2.5;
windowSize = 0.15; %in seconds 
plotSignificantUnits(readPaths,seNames, seDir, sigma, statAlpha, folderSigma, bins, windowSize, FRlims);

%% only plot significantly deltaFR units
% plot all units of same recording site together

sigma = 0.005;
statAlpha = 0.05;
FRlims = [-0.25 0.25];
folderSigma = strrep(['PlotSigma ' num2str(sigma) ' StatAlpha ' num2str(statAlpha)], '.', '_');
windowSize = 0.15; %in seconds 
binSize = 0.00025;
bins = -0.5:binSize:2.5;

plotSignificantUnits(readPaths,seNames, seDir, sigma, statAlpha, folderSigma, bins, windowSize, FRlims, binSize);

%% Plot units separated by whisker stim duration. 
% clear all
% 
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\StimSEs', 'Select source SEs');

clear all
animalID = {'VC030107','VC030206', 'VC030108'};
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
        case 'StimSEs'            
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
%
clearvars -except dataFileTb groupDir
trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
trials{2} = {'Stim_Som_Left', 'Stim_Som_Left_Opto', 'Stim_Som_Right', 'Stim_Som_Right_Opto'}; 
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\behavSEs', 'Select source SEs');
% clearvars -except readPaths seDir seNames animalID trials;
% readPathParts = cellfun(@(x) strsplit(x, '\'), readPaths, 'UniformOutput', false);
% animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
animalID = dataFileTb.MouseName;
uniAnimalId = unique(animalID);
uRecSites = unique(dataFileTb.recSite);
recSites = dataFileTb.recSite;
readPaths= dataFileTb.sePath;
uGenotypes = unique(dataFileTb.Genotype);
genotypes = dataFileTb.Genotype;

% Plot using FRrate in ses


statAlpha = 0.05;
binSize = 0.00025;
% FRlims = [-0.15 0.15];
tWins = [-0.5, 1];
bins = tWins(1):binSize:tWins(2);
folderSigma = strrep(['PlotSigma ' num2str(0.002) ' StatAlpha ' num2str(statAlpha)], '.', '_');
% windowSize = 0.15; %in seconds 

stimDurs = {'150','100','050','020','010','005'}; %in ms

savePath = fullfile(groupDir,'Figures\StimSess_0_25msFRlims_windowwinSizePlus0_200s\AllUnits', folderSigma);


if ~exist('savePath', 'Dir')
    mkdir(savePath)
end

%
for genotype = 1:numel(uGenotypes)
    for recSite = 1:numel(uRecSites)
        recReadPaths = readPaths(strcmp(uRecSites(recSite), recSites) & strcmp(uGenotypes(genotype), genotypes));
        if sum(ismember(uRecSites{recSite}, 'M1'))==2
            winAdd = 0.25;
        elseif sum(ismember(uRecSites{recSite}, 'S1'))==2
            winAdd = 0.015;
        else
             winAdd = 0.015;
        end
        if ~isempty(recReadPaths)
            
            
            close all;
            
            allMeanFR = cell(1,6);
            
            adcFinal = cell(1,6);
            for sessNum = 1:numel(recReadPaths)
                load(recReadPaths{sessNum})
                meanFR = cell(1,6);
                adcAll = cell(1,6);
                tRef = se.GetReferenceTime();
                check = diff(tRef);
            
                fprintf('%s\n\n', recReadPaths{sessNum});
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
                
                se = BS.Preprocess.removeTrials(keepTrials,se);
                
    
                %get different stim types
                leftStimTypes = se.GetColumn('behavValue', 'leftStimType');
                rightStimTypes =  se.GetColumn('behavValue', 'rightStimType');
                stimTypes = unique(se.GetColumn('behavValue', 'leftStimType'));
                
                
                behavData = se.GetTable('behavValue');
                behavData(1,:) = [];
                leftStimTypes(1,:) = [];
                rightStimTypes(1,:) = [];




                frAll= se.SliceTimeSeries('spikeRate', tWins, 'Fill', 'bleed');
                frAll(1,:) = [];
                frAll = table2cell(frAll);
                frAll = cellfun(@(x) x', frAll, 'UniformOutput',false);
                FRAllTime = frAll(:,1);
                

                % get adcAll
                
                adcAll = se.SliceTimeSeries('adc', tWins, 'Fill', 'bleed');
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
                
                
        
                adc = cell(1,6);
                % parfor all the stimDurs
               parfor stimDur = 1:numel(stimDurs)

                         

                    trials2keepL{stimDur} = find(strcmp(trials{1}{1}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(end-2:end),stimDurs{stimDur}), ...
                        leftStimTypes, 'UniformOutput',false)));
                    trials2keepR{stimDur} = find(strcmp(trials{1}{2}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(end-2:end),stimDurs{stimDur}), ...
                        rightStimTypes, 'UniformOutput',false)));
                    
                    %get FR for both trialType and current stimDue
%                     windowSize{stimDur} = max(50/1000,str2num(stimDurs{stimDur})/1000); %in s 
%                     windowSize{stimDur} = 50/1000;
                    
                    windowSize{stimDur} =str2num(stimDurs{stimDur})/1000+winAdd; %in s 
                    FRlims{stimDur} = [-windowSize{stimDur}, windowSize{stimDur} + 0.035];

                    binsWin{stimDur} = find(bins>= -windowSize{stimDur} & bins<= windowSize{stimDur});
                    temp = binsWin{stimDur};
                    frAllwin{stimDur} = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                    FRLeft{stimDur} = frAllwin{stimDur}(trials2keepL{stimDur},2:end);
                    FRRight{stimDur} = frAllwin{stimDur}(trials2keepR{stimDur},2:end);
                    FRtime{stimDur} = frAllwin{stimDur}(:,1);
                    
                    %get p-value based on windowsize = stim duration
                    
                    preWindow{stimDur} = 1:(round(numel(FRLeft{stimDur}{1})/2));
                    postWindow{stimDur} =  preWindow{stimDur}(end)+1: numel(FRLeft{stimDur}{1}); 
                    temp1 = preWindow{stimDur};
                    temp2 = postWindow{stimDur};
                    preMeanFRL{stimDur} = cell2mat(cellfun(@(x) mean(x(temp1)), FRLeft{stimDur}, 'UniformOutput', false));
                    postMeanFRL{stimDur} = cell2mat(cellfun(@(x) mean(x(temp2)), FRLeft{stimDur}, 'UniformOutput', false));
             
                    preMeanFRR{stimDur} = cell2mat(cellfun(@(x) mean(x(temp1)), FRRight{stimDur}, 'UniformOutput', false));
                    postMeanFRR{stimDur} = cell2mat(cellfun(@(x) mean(x(temp2)), FRRight{stimDur}, 'UniformOutput', false));
                    
                    % get frAll for FRlims
                    binsWin{stimDur} = find(bins>= FRlims{stimDur}(1) & bins<= FRlims{stimDur}(2));
                    temp = binsWin{stimDur};
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
                        [meanFR{stimDur}{unitNum,2}, SD{stimDur}{unitNum,1}, SE{stimDur}{unitNum,1},...
                            meanFR{stimDur}{unitNum,3}]= MMath.MeanStats(cell2mat(FRLeft{stimDur}(:,unitNum)), 1);
                        [meanFR{stimDur}{unitNum,4}, SD{stimDur}{unitNum,3}, SE{stimDur}{unitNum,1},...
                            meanFR{stimDur}{unitNum,5}] = MMath.MeanStats(cell2mat(FRRight{stimDur}(:,unitNum)), 1);
                        meanFR{stimDur}{unitNum,6} = unitDepth{stimDur}(unitNum);
                        meanFR{stimDur}{unitNum,7} = min(pvalL{stimDur}(unitNum), pvalR{stimDur}(unitNum));

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
         if maxadcfig <1
            fM = 100000;
        else
            fM =1;
            
        end

        maxadcfig = maxadcfig*fM; 
        close all

        parfor stimDur = 1:numel(stimDurs)
           
            g{stimDur} = figure(stimDur); clf;
            g{stimDur}.WindowState = 'maximized';
            meanFR{stimDur} = allMeanFR{stimDur};
            sigUnits{stimDur} = cell2mat(cellfun(@(x) x< statAlpha, meanFR{stimDur}(:,7), 'UniformOutput',false));
            meanFR{stimDur}(~sigUnits{stimDur},:) = [];
            meanFR{stimDur} = sortrows(meanFR{stimDur},6);
            

            % adc and maxAadc
            plotRows = max(3,ceil(height(meanFR{stimDur})/10));
            for unitNum = 1:size(meanFR{stimDur},1)
                
                
            
                color = {'r','b'};
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
                    
    
                plot(adcFinal{stimDur}(1,:), (adcFinal{stimDur}(2,:)*fM) +  yLimits(2), ...
                    'k', 'lineWidth', 1);
                yLimits = get(gca,'YLim');
                MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
                xlabel('epoch time (s)');
                ylabel('FR');  
                yLimits = get(gca,'YLim');
                ylim([0, yLimits(2)])
                xlim(FRlims{stimDur});
               
                title(['Depth ' num2str(meanFR{stimDur}{unitNum,6}) ' \mum']);
        
                box off  
                outerpos = get(h,'OuterPosition');
                ti = get(h,'TightInset');
                left = outerpos(1) + ti(1);
                bottom = outerpos(2) + ti(2);
                ax_width = outerpos(3) - ti(1) - ti(3);
                ax_height = outerpos(4) - ti(2) - ti(4);
                set(h,'Position',[left bottom ax_width ax_height]);        
                hold(h, 'off');
                


            end
            sgtitle([uGenotypes{genotype} ' ' uRecSites{recSite} ' ' stimDurs{stimDur} ' ms'])
            hold off

            
           
            plotRows = max(3,ceil(height(meanFR{stimDur})/10));
            if plotRows
                scaleFactor = 1100/plotRows;
                hAxes   = findobj(allchild(g{stimDur}), 'flat', 'Type', 'axes');
                plotNums = ceil(numel(hAxes)/10);
                a = get(g{stimDur}, 'position');    
                set(g{stimDur}, 'position', [0 0 200*10 scaleFactor*plotNums])
            end
            savefig(g{stimDur},fullfile(savePath,  [uGenotypes{genotype} ' ' uRecSites{recSite} ' ' stimDurs{stimDur} ' ms duration significant units.fig']));
        end

       
        
    
    end

end





%%
sigma = 0.002;
statAlpha = 0.05;
binSize = 0.00025;
FRlims = [-0.05 0.15];
folderSigma = strrep(['PlotSigma ' num2str(sigma) ' StatAlpha ' num2str(statAlpha)], '.', '_');
windowSize = 0.15; %in seconds 
bins = -0.5:binSize:2.5;
plotSignificantUnitsStimDur(readPaths,seNames, seDir, sigma, statAlpha, folderSigma, bins, windowSize, FRlims, binSize)
  
    
%% Helper function
function plotSignificantUnits(readPaths,seNames, seDir, sigma, statAlpha, folderSigma, bins, windowSize, FRlims, binSize)

    recSiteTypes = {'Left wS1', 'Right wS1', 'Left wM1', 'Right wM1'};
    plotType = {'WT Left wS1', 'WT Right wS1', 'KO Left wS1', 'KO Right wS1', 'WT Left wM1', 'WT Right wM1', 'KO Left wM1', 'KO Right wM1'};
    trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
    trials{2} = {'Stim_Som_Left', 'Stim_Som_Right', 'Stim_Som_Left_Opto', 'Stim_Som_Right_Opto'}; 
    %
    
    
    
    preWindow = [-windowSize-0.01,-0.01];
    postWindow = [0,windowSize]; 

    
    
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
    figureSerial = ones(numel(plotType),1);
    for sessNum = 1:size(readPaths,1)    qqqqq
        seParts = strsplit(seNames{sessNum}, ' ');
        
      
        
        load(readPaths{sessNum});
    %     seArray{sessNum} = se;
        recSite{sessNum} = se.userData.sessionInfo.recSite;
        animalID{sessNum} =  se.userData.sessionInfo.MouseName;
        sessDate{sessNum} = se.userData.sessionInfo.seshDate;
        genotype{sessNum} = se.userData.sessionInfo.Genotype;
    
        figureNum = (find(ismember(plotType, [genotype{sessNum}{1} ' ' recSite{sessNum}{1}]))); 
        
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
        
        se = BS.Preprocess.removeTrials(keepTrials,se);
        
        behavData = se.GetTable('behavValue');
       
        
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
            
            missInd = find(strcmp(trialTypes{trialType}, behavData.trialType));
            
            
            seMissTemp = BS.Preprocess.keepTrials(missInd, se);
            

            
            if any(ismember(trialTypes{trialType}, 'L'))
                stimOnset{figureNum}{figureSerial(figureNum), trialType} = max(cell2mat(behavTime.leftOnset));
                stimOffset{figureNum}{figureSerial(figureNum), trialType} = max(cell2mat(behavTime.leftOffset));
            else
                stimOnset{figureNum}{figureSerial(figureNum), trialType} = max(cell2mat(behavTime.rightOnset));
                stimOffset{figureNum}{figureSerial(figureNum), trialType} = max(cell2mat(behavTime.rightOffset));
            end
            seS(trialType) = {seMissTemp};
            
    
        end   
        
        spikeTimes = se.GetTable('spikeTime');
        channelInds = se.userData.spikeInfo.unit_channel_ind;  
        try
            chanDepth = se.userData.spikeInfo.quality_metrics.depth; %(in um)
            unitChanDepth = se.userData.spikeInfo.quality_metrics.depth;
        catch
            chanDepth = 0:20:1260; %(in um)
            channelInds = se.userData.spikeInfo.unit_channel_ind;
            unitChanDepth = chanDepth(channelInds);
    
        end
        chanMap = se.userData.spikeInfo.channel_map; 
        
        for unitNum =1:size(spikeTimes,2)
            clearvars unitSpikes;
            
            sei =1;
            unitChannelId = channelInds(unitNum);
            unitDepth = unitChanDepth(unitNum);
    
            
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
                        spikes.(i) = cellfun(@(x) MNeuro.Filter1(x, 1/binSize, 'gaussian', sigma), spikes.(i), 'UniformOutput', false);
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
    wwwwwwww
    % find cells that has no data and and remove them. 
    MTmean = ~cell2mat(cellfun(@(x) isempty(x), meanFR, 'UniformOutput', false));
    
    meanFR = meanFR(MTmean);
    ciFR = ciFR(MTmean);
    plotType = plotType(MTmean);
    stimOnset = stimOnset(MTmean);
    stimOffset = stimOffset(MTmean);
    
    
    %sort each meanFR cell by depth
    meanFR = cellfun(@(x) sortrows(x,3), meanFR, 'UniformOutput', false);
    ciFR = cellfun(@(x) sortrows(x,3), ciFR, 'UniformOutput', false);
    
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
            MPlot.Blocks([stimOnset{1}{1,1} stimOffset{1}{1,1}], [yLimits(2)*0.98, yLimits(2)], ...
                            color{1}, 'FaceAlpha', 0.6);    
            MPlot.Blocks([stimOnset{1}{1,2} stimOffset{1}{1,2}], [yLimits(2)*0.95,yLimits(2)*0.97], ...
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
end

function plotSignificantUnitsStimDur(readPaths,seNames, seDir, sigma, statAlpha, folderSigma, bins, windowSize, FRlims, binSize)
    
    recSiteTypes = {'Left wS1', 'Right wS1', 'Left wM1', 'Right wM1'};
    plotType = {'WT Left wS1', 'WT Right wS1', 'KO Left wS1', 'KO Right wS1', 'WT Left wM1', 'WT Right wM1', 'KO Left wM1', 'KO Right wM1'};
    trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
    trials{2} = {'Stim_Som_Left', 'Stim_Som_Right', 'Stim_Som_Left_Opto', 'Stim_Som_Right_Opto'}; 
    
    
    
    
    
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
        genotype{sessNum} = se.userData.sessionInfo.Genotype;
    
        figureNum = (find(ismember(plotType, [genotype{sessNum}{1} ' ' recSite{sessNum}{1}]))); 
        
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
        
        se = BS.Preprocess.removeTrials(keepTrials,se);
        
        behavData = se.GetTable('behavValue');
       
        
        trialTypes = unique(behavData.trialType);
        durTypes = unique(behavData.leftStimType);
    
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
        
        
        
         spikeTimes = se.GetTable('spikeTime');
        channelInds = se.userData.spikeInfo.unit_channel_ind;  
        try
            chanDepth = se.userData.spikeInfo.quality_metrics.depth; %(in um)
            unitChanDepth = se.userData.spikeInfo.quality_metrics.depth;
        catch
            chanDepth = 0:20:1260; %(in um)
            channelInds = se.userData.spikeInfo.unit_channel_ind;
            unitChanDepth = chanDepth(channelInds);
    
        end
        chanMap = se.userData.spikeInfo.channel_map; 
        for stimDur = 1: size(durTypes,1)
            
            for trialType = 1:numel(trialTypes)
                if any(ismember(trialTypes{trialType}, 'L'))
                    
                    stimTypes = behavData.leftStimType;
                    
                else
                    stimTypes = behavData.rightStimType;
                    
                end
            
                missInd = find(strcmp(trialTypes{trialType}, behavData.trialType) & strcmp(durTypes(stimDur), stimTypes));
                
                
                seMissTemp = BS.Preprocess.keepTrials(missInd, se);
                
                behavTime = seMissTemp.GetTable('behavTime');
                
                if any(ismember(trialTypes{trialType}, 'L'))
                    stimDuration{figureNum}{stimDur}{trialType} = durTypes(stimDur);
                    adcTemp = seMissTemp.ResampleTimeSeries('adc', bins);
                    adcTemp = adcTemp.leftStim;
                    adcTemp = cellfun(@transpose, adcTemp,'UniformOutput', false);
                    
                    
                else
                    stimDuration{figureNum}{stimDur}{trialType} = durTypes(stimDur);
                    adcTemp = seMissTemp.ResampleTimeSeries('adc', bins);
                    adcTemp = adcTemp.rightStim;
                    adcTemp = cellfun(@transpose, adcTemp,'UniformOutput', false);
                end
                adc{figureNum}{stimDur}{trialType} = MMath.MeanStats(cell2mat(adcTemp),1);
                maxAdc{figureNum}{stimDur}(trialType) = max(adc{figureNum}{stimDur}{trialType});
    
                for unitNum =1:size(spikeTimes,2)
                    clearvars unitSpikes;
                    increment = figureSerial(figureNum) + unitNum -1;
                    
                    unitChannelId = channelInds(unitNum);
                    unitDepth = unitChanDepth(unitNum);
                    
                
                    %post-pre                
                    spikeTimes = seMissTemp.GetTable('spikeTime');
                    ind = 1:height(spikeTimes);
                    preSpikes = seMissTemp.ResampleEventTimes('spikeTime', preWindow);
                    postSpikes = seMissTemp.ResampleEventTimes('spikeTime', postWindow);
                    preUnitSpikes = preSpikes(ind,unitNum+1); 
                    preUnitSpikes = cell2mat(table2cell(preUnitSpikes));
                    postUnitSpikes = postSpikes(ind,unitNum+1); 
                    postUnitSpikes = cell2mat(table2cell(postUnitSpikes));
                    dUnitSpikes = (postUnitSpikes - preUnitSpikes)/windowSize;
                    if ~isempty(dUnitSpikes)
                        [H, pValue] = ttest2(dUnitSpikes, zeros(size(dUnitSpikes,1),1), ...
                            'tail', 'both', 'Alpha', statAlpha);
                    else
                        pValue = 1;
                    end
        
                    spikes = seMissTemp.ResampleEventTimes('spikeTime', bins, 'Normalization', 'countdensity');
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
                        [meanFR{figureNum}{stimDur}{increment, 3*trialType-2}, sdFR{figureNum}{stimDur}{increment, 3*trialType-2}, ...
                             seFR{figureNum}{stimDur}{increment, 3*trialType-2}, ciFR{figureNum}{stimDur}{increment, 3*trialType-2}] = MMath.MeanStats(unitSpikes, 1);    
                        
                    catch
                        maxFR{figureNum}{stimDur}{increment,trialType} = 0;
                        meanFR{figureNum}{stimDur}{increment, trialType+1} = unitDepth;
                        ciFR{figureNum}{stimDur}{increment, trialType+1} = unitDepth;
        
                        
                        continue;
                        
                    end
                    
                    
                    
                    meanFR{figureNum}{stimDur}{increment, 3*trialType-1} = pValue;
                    ciFR{figureNum}{stimDur}{increment, 3*trialType-1} = pValue;
                    meanFR{figureNum}{stimDur}{increment, 3*trialType} = unitDepth;
                    ciFR{figureNum}{stimDur}{increment, 3*trialType} = unitDepth;
                    maxFR{figureNum}{stimDur}{increment,trialType} = max(meanFR{figureNum}{stimDur}{increment,3*trialType-2})+1;
                    
                    
                end
    
                
            end
            
            
        end
        figureSerial(figureNum) =  increment+1;
    end  



    %% find cells that has no data and and remove them. 
    MTmean = ~cell2mat(cellfun(@(x) isempty(x), meanFR, 'UniformOutput', false));
    
    meanFR = meanFR(MTmean);
    ciFR = ciFR(MTmean);
    plotType = plotType(MTmean);
    stimDuration = stimDuration(MTmean);
    adc = adc(MTmean);
    maxAdc = maxAdc(MTmean);
    maxFR = maxFR(MTmean);
    
    
    
    close all
    for figNums = 1:size(plotType,2)
        maxadcfig = max(cell2mat(maxAdc{figNums}));
        if maxadcfig <1
            fM = 100000;
        else
            fM =1;
            
        end
        maxadcfig = max(cell2mat(maxAdc{figNums}))*fM; 
        
        for stimDur = 1:size(durTypes,1)
            f(size(durTypes,1)*figNums-size(durTypes,1)+stimDur) = figure();clf
            % plot all units now
            pGood = cell2mat(meanFR{figNums}{stimDur}(:,2)) < statAlpha | cell2mat(meanFR{figNums}{stimDur}(:,5)) < statAlpha;
             
            meanFR{figNums}{stimDur}(find(~pGood),:) = [];
            ciFR{figNums}{stimDur}(find(~pGood),:) = [];
            meanFR{figNums}{stimDur}=sortrows(meanFR{figNums}{stimDur},3);
            ciFR{figNums}{stimDur}=sortrows(ciFR{figNums}{stimDur},3);
            maxFR{figNums}{stimDur}(find(~pGood),:) = [];
    
            
            plotRows = ceil(height(meanFR{figNums}{stimDur})/10);
            for unitNum = 1:height(meanFR{figNums}{stimDur})
                color = {'r','b'};
                %sort each meanFR cell by depth
               
                h = subplot(plotRows,10,unitNum, 'Parent', f(size(durTypes,1)*figNums-size(durTypes,1)+stimDur));
                hold(h, 'on');
                for trialType = 1:2
                    
                    plot(bins(1:size(meanFR{figNums}{stimDur}{unitNum, 3*trialType-2},2)),meanFR{figNums}{stimDur}{unitNum, 3*trialType-2}, ...
                        color{trialType}, 'LineWidth', 1);
                    
                    if ~isempty(meanFR{figNums}{stimDur}{unitNum, 3*trialType-2})
                        
                        MPlot.ErrorShade(bins(1:size(meanFR{figNums}{stimDur}{unitNum, 3*trialType-2},2)), ...
                            meanFR{figNums}{stimDur}{unitNum, 3*trialType-2}, ciFR{figNums}{stimDur}{unitNum, 3*trialType-2}(2,:), ...
                            ciFR{figNums}{stimDur}{unitNum, 3*trialType-2}(1,:), 'color',color{trialType}, 'Alpha', 0.3, 'IsRelative', false);
                        
                    end
                end
        
                ylim([0,max(cell2mat(maxFR{figNums}{stimDur}) + maxadcfig, [], 'all')]); 
                yLimits = get(gca,'YLim');
    %             stimD = str2num(stimDuration{figNums}{stimDur}{trialType}{1}(end-2:end))/1000;
    %             MPlot.Blocks([0 stimD], [yLimits(2)*0.98, yLimits(2)], ...
    %                             'k', 'FaceAlpha', 0.6);   
                plot(bins(1:size(adc{figNums}{stimDur}{trialType},2)), ...
                    (adc{figNums}{stimDur}{trialType}*fM) - maxadcfig +  yLimits(2), ...
                    'k', 'lineWidth', 1);
             
                xlabel('epoch time (s)');
                ylabel('FR');  
                xlim(FRlims);
               
                title(['Depth ' num2str(meanFR{figNums}{stimDur}{unitNum,3}) ' \mum']);
        
                box off  
                
                hold(h, 'off');
                sgtitle(plotType{figNums})
            end
       end     
    end
    
    
    plotTypeSizes = cellfun(@(x) height(x), meanFR, 'UniformOutput', false);
    maxPlots = max(cell2mat(plotTypeSizes));
    scaleFactor = 1100/ceil(maxPlots/10);
    for i =1:size(plotType,2)
        for stimDur = 1:size(durTypes,1)
            f = figure(size(durTypes,1)*figNums-size(durTypes,1)+stimDur);
            
            hAxes   = findobj(allchild(f), 'flat', 'Type', 'axes');
            plotNums = ceil(numel(hAxes)/10);
            a = get(f, 'position');    
            set(f, 'position', [0 0 200*10 scaleFactor*plotNums])
            sgtitle(plotType{i});
            savefig(f,fullfile(savePath,  [plotType{i} ' ' stimDuration{i}{stimDur}{trialType}{1}(end-2:end) 'ms duration significant units.fig']));
        %     MPlot.SavePNG(f(i), fullfile(savePath,  [plotType{i} ' units.pdf']));
            exportgraphics(f, fullfile(savePath,  [plotType{i} ' ' stimDuration{i}{stimDur}{trialType}{1}(end-2:end) 'ms duration significant units.png']));
        end
    end

end


