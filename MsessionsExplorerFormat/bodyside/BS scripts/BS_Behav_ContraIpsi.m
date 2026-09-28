%% opto inhibition effect
% 
clear all
animalID = {'VC030213','VC030115'};
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

% Plot individual sessions as different colors. 
% clear all
close all
% animalID = {'VC030209', 'VC030112', 'VC030113'};
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

            
            se = BS.Preprocess.keepTrials(trialInd,se);

            
            
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
                   (numel(find(strcmp(trialTypes{trialType}, missData.trialType))) + numel(find(strcmp(trialTypes{trialType}, behavData.trialType))));
                allTrialTypes{inhibitionSide,animalNum,sessNum} = trialTypes;
            end   
            
            
            sessDate{inhibitionSide,animalNum,sessNum} = char(se.userData.sessionInfo.seshDate{1});
            sessNum = sessNum+1;
            
           
        end
     end
end
    


pathParts = strsplit(dataFileTb.sePath{1}, '\');
figureFolder = fullfile(pathParts{1:end-2}, 'Figures\IndividualSessFrac');
if ~exist(figureFolder, 'dir')
    mkdir(figureFolder);
end
fracResult = permute(fracResult,[2,1,3,4]);
missFrac = permute(missFrac,[2,1,3,4]);
sessDate = permute(sessDate,[2,1,3]);
 % plot correct fraction
KOIDs = {'VC030204'};
WTIDs = {'VC030105'};

close all;
for animalNum = 1:size(fracResult,1)
     g = figure(); clf;
        color = {[1 0 0], [0 1 0], [0 0 1]};
        hold on
    for inhibitionSide =1:size(fracResult,2)
        if isempty(fracResult{animalNum, inhibitionSide})
            continue;
        end
        if sum(ismember(uInhSites{inhibitionSide}, 'Left')) ==4
            color = {'b','r'};
            plotOrder = [3,4,1,2];
        else
            color = {'r','b'};
            plotOrder = [1,2,3,4];
        end
        h = subplot(1,size(fracResult,2),inhibitionSide)
        hold(h, 'on');
        clearvars f;
        legnedI = 0;
        for sessNum =1:size(fracResult,3)  
            
            if ~isempty([fracResult{animalNum,inhibitionSide,sessNum,plotOrder}])
                f(sessNum) = plot([1:4], [fracResult{animalNum,inhibitionSide,sessNum,plotOrder}],'.', 'MarkerSize',15);
                line([1:4], [fracResult{animalNum,inhibitionSide,sessNum,plotOrder}]);    
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
        xticklabels({'Contra Stim only', 'Contra Stim + Opto','Ipsi Stim only', 'Ipsi Stim + Opto'})
        title([uInhSites{inhibitionSide} ' inhibition']);
        hold(h, 'off');
        

        
    
    end
    sgtitle([uniAnimalId{animalNum}])
    hold off;
    %savFig with pos = get(figure(5), 'Position')
    set(g, 'position', [1 41 1920 1083])
    savefig(g,fullfile(figureFolder,  [uniAnimalId{animalNum} ' inhibition.fig']));
    
    exportgraphics(g, fullfile(figureFolder,  [uniAnimalId{animalNum} ' inhibitionContraIpsi.png']));
    

    %plot missFrac
    g = figure(); clf;
        color = {[1 0 0], [0 1 0], [0 0 1]};
        hold on
    for inhibitionSide =1:size(fracResult,2)
        if isempty(missFrac{animalNum, inhibitionSide})
            continue;
        end
        if sum(ismember(uInhSites{inhibitionSide}, 'Left')) ==4
            color = {'b','r'};
            plotOrder = [3,4,1,2];
        else
            color = {'r','b'};
            plotOrder = [1,2,3,4];
        end
        h = subplot(1,size(missFrac,2),inhibitionSide)
        hold(h, 'on');
        clearvars f;
        legnedI = 0;
        for sessNum =1:size(missFrac,3)  
            
            if ~isempty([missFrac{animalNum,inhibitionSide,sessNum,plotOrder}])
                f(sessNum) = plot([1:4], [missFrac{animalNum,inhibitionSide,sessNum,plotOrder}],'.', 'MarkerSize',15);
                line([1:4], [missFrac{animalNum,inhibitionSide,sessNum,plotOrder}]);    
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
        xticklabels({'Contra Stim only', 'Contra Stim + Opto','Ipsi Stim only', 'Ipsi Stim + Opto'})
        title([uInhSites{inhibitionSide} ' inhibition_missfrac']);
        hold(h, 'off');
        

        
    
    end
    sgtitle([uniAnimalId{animalNum}])
    hold off;
    %savFig with pos = get(figure(5), 'Position')
    set(g, 'position', [1 41 1920 1083])
    savefig(g,fullfile(figureFolder,  [uniAnimalId{animalNum} ' inhibition_missfrac.fig']));
    
    exportgraphics(g, fullfile(figureFolder,  [uniAnimalId{animalNum} ' inhibitionContraIpsi_missfrac.png']));



end

%% Plot indivdual datapoints as gray and mean as red for leftStims and blue for rightStims
% 
% clear all
close all
clear meanPerf ciPerf se sd
% animalID = {'VC030109', 'VC030110', 'VC030207'};
clearvars -except dataFileTb
trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
trials{2} = {'Stim_Som_Left', 'Stim_Som_Left_Opto', 'Stim_Som_Right', 'Stim_Som_Right_Opto'}; 
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\behavSEs', 'Select source SEs');
% clearvars -except readPaths seDir seNames animalID trials;
% readPathParts = cellfun(@(x) strsplit(x, '\'), readPaths, 'UniformOutput', false);
% animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
animalID = dataFileTb.MouseName;
uAnimalId = unique(animalID);
uInhSites = unique(dataFileTb.inhSite);
inhSites = dataFileTb.inhSite;
readPaths= dataFileTb.sePath;


% get all the trialNums for each trialType for each session and mouse
% uniAnimalId = uAnimalId([2,3,5],1);
uniAnimalId = uAnimalId;
fracResult ={};
missFrac = {};
for inhibitionSide = 1:numel(uInhSites)
    inh = uInhSites(inhibitionSide);
    for animalNum =1:numel(uniAnimalId)
         ani = uniAnimalId{animalNum}; 
         sessNum =1;
        
         for i = find(ismember(dataFileTb.MouseName, ani) & ismember(dataFileTb.inhSite,inh))' 
             load(readPaths{i});
            
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
            se = BS.Preprocess.keepTrials(trialInd,se);
            
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
                fracResult{inhibitionSide}{animalNum}{sessNum,trialType} = mean(behavData.result(trialTypeInd));
                
               missFrac{inhibitionSide}{animalNum}{sessNum,trialType} = numel(find(strcmp(trialTypes{trialType}, missData.trialType)))/...
                   (numel(find(strcmp(trialTypes{trialType}, missData.trialType))) + numel(find(strcmp(trialTypes{trialType}, behavData.trialType))));

                allTrialTypes{inhibitionSide}{animalNum}{sessNum} = trialTypes;
            end   
            tt = fracResult{inhibitionSide}{animalNum};
            tt = permute(tt,[3,4,1,2]);
            sessDate{inhibitionSide,animalNum,sessNum} = char(se.userData.sessionInfo.seshDate{1});
            sessNum = sessNum+1;
            
           
         end
         
         [meanPerf{inhibitionSide, animalNum}, ~, ~, ciPerf{inhibitionSide, animalNum}] ...
             = MMath.MeanStats(cell2mat(fracResult{inhibitionSide}{animalNum}), 1);
         [meanMiss{inhibitionSide, animalNum}, ~, ~, ciMiss{inhibitionSide, animalNum}] ...
             = MMath.MeanStats(cell2mat(missFrac{inhibitionSide}{animalNum}), 1);
     end
end
    
  t = meanPerf{inhibitionSide, animalNum};
  a = permute(t,[3,4,1,2]);
% permute 
% meanPerf = cellfun(@(x) permute(x, [3,4,1,2]), meanPerf, 'UniformOutput', false);
% ciPerf = cellfun(@(x) permute(x, [3,4,1,2]), ciPerf, 'UniformOutput', false);
% meanMiss = cellfun(@(x) permute(x, [3,4,1,2]), meanMiss, 'UniformOutput', false);
% ciMiss = cellfun(@(x) permute(x, [3,4,1,2]), ciMiss, 'UniformOutput', false);

pathParts = strsplit(dataFileTb.sePath{1}, '\');
figureFolder = fullfile(pathParts{1:end-2}, 'Figures\IndividualSessFrac_RedGray');
if ~exist(figureFolder, 'dir')
    mkdir(figureFolder);
end
% fracResult = permute(fracResult,[2,1,3,4]);
% missFrac = permute(missFrac,[2,1,3,4]);
sessDate = permute(sessDate,[2,1,3]);
meanMiss = permute(meanMiss,[2,1]);
meanPerf = permute(meanPerf,[2,1]);
% ciPerf = permute(ciPerf,[2,1]);

 % plot correct fraction

%
close all;
for animalNum = 1:size(fracResult{1},2)
     g = figure(); clf;
        color = {[1 0 0], [0.5 0.5 0.5], [0 0 1]};
        hold on
    for inhibitionSide =1:size(fracResult,2)
        if isempty(fracResult{inhibitionSide}{animalNum})
            continue;
        end
        if sum(ismember(uInhSites{inhibitionSide}, 'Left')) ==4
            color = {[1 0 0], [0.5 0.5 0.5], [0 0 1]}; 
            plotOrder = [3,4,1,2];
        else
            color = {[1 0 0], [0.5 0.5 0.5], [0 0 1]};
            plotOrder = [1,2,3,4];
        end
        h = subplot(1,size(fracResult,2),inhibitionSide);
        hold(h, 'on');
        clearvars f;
        set(gca,'FontSize',18);
        for sessNum =1:size(fracResult{inhibitionSide}{animalNum},1)        
            if ~isempty([fracResult{inhibitionSide}{animalNum}{sessNum,plotOrder}])
%                 f(sessNum) = plot([1:4], [fracResult{animalNum,inhibitionSide,sessNum,:}],'.', 'MarkerSize',15, 'Color', 'gray');
                
                line([1:2], [fracResult{inhibitionSide}{animalNum}{sessNum,plotOrder(1:2)}], 'color', color{2});
                line([3:4], [fracResult{inhibitionSide}{animalNum}{sessNum,plotOrder(3:4)}], 'color', color{2});
                
                
            end
            
        end
%        errorbar([1:2], meanPerf{animalNum,inhibitionSide}(1:2), ciPerf{animalNum,inhibitionSide}(1,1:2) - meanPerf{animalNum,inhibitionSide}(1:2), ...
%             ciPerf{animalNum,inhibitionSide}(2,1:2) - meanPerf{animalNum,inhibitionSide}(1:2), '.', 'color', color{1});
%        errorbar([3:4], meanPerf{animalNum,inhibitionSide}(3:4), ciPerf{animalNum,inhibitionSide}(1,3:4) - meanPerf{animalNum,inhibitionSide}(3:4), ...
%             ciPerf{animalNum,inhibitionSide}(2,3:4) - meanPerf{animalNum,inhibitionSide}(3:4), '.', 'color', color{3});
        f(1) = line([1:2], [meanPerf{animalNum,inhibitionSide}(plotOrder(1:2))], 'color', color{1}, 'lineWidth', 2);
        f(2) = line([3:4], [meanPerf{animalNum,inhibitionSide}(plotOrder(3:4))], 'color', color{3}, 'lineWidth', 2);
        xlim([0,6]);
        ylim([0,1.0]);
        xticks([1 2 3 4])
        
        try
            legend(f, {'Contra Stim trials', 'Ipsi Stim trials'}, 'Location', 'northeast')
        catch
            keyboard;
        end
        xticklabels({'Contra Stim only', 'Contra Stim + Opto','Ipsi Stim only', 'Ipsi Stim + Opto'})
        
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
    
    exportgraphics(g, fullfile(figureFolder,  [uniAnimalId{animalNum} ' inhibition_mean_contraIpsi.png']));

    % plot miss frac

      g = figure(); clf;
        color = {[1 0 0], [0.5 0.5 0.5], [0 0 1]};
        hold on
    for inhibitionSide =1:size(missFrac,2)
        if isempty(missFrac{inhibitionSide}{animalNum})
            continue;
        end
        if sum(ismember(uInhSites{inhibitionSide}, 'Left')) ==4
            color = {[1 0 0], [0.5 0.5 0.5], [0 0 1]}; 
            plotOrder = [3,4,1,2];
        else
            color = {[1 0 0], [0.5 0.5 0.5], [0 0 1]};
            plotOrder = [1,2,3,4];
        end
        h = subplot(1,size(missFrac,2),inhibitionSide)
        hold(h, 'on');
        clearvars f;
        set(gca,'FontSize',18);
        for sessNum =1:size(missFrac{inhibitionSide}{animalNum},1)        
            if ~isempty([missFrac{inhibitionSide}{animalNum}{sessNum,plotOrder}])
%                 f(sessNum) = plot([1:4], [fracResult{animalNum,inhibitionSide,sessNum,:}],'.', 'MarkerSize',15, 'Color', 'gray');
                
                line([1:2], [missFrac{inhibitionSide}{animalNum}{sessNum,plotOrder(1:2)}], 'color', color{2});
                line([3:4], [missFrac{inhibitionSide}{animalNum}{sessNum,plotOrder(3:4)}], 'color', color{2});
                
                
            end
            
        end
%        errorbar([1:2], meanPerf{animalNum,inhibitionSide}(1:2), ciPerf{animalNum,inhibitionSide}(1,1:2) - meanPerf{animalNum,inhibitionSide}(1:2), ...
%             ciPerf{animalNum,inhibitionSide}(2,1:2) - meanPerf{animalNum,inhibitionSide}(1:2), '.', 'color', color{1});
%        errorbar([3:4], meanPerf{animalNum,inhibitionSide}(3:4), ciPerf{animalNum,inhibitionSide}(1,3:4) - meanPerf{animalNum,inhibitionSide}(3:4), ...
%             ciPerf{animalNum,inhibitionSide}(2,3:4) - meanPerf{animalNum,inhibitionSide}(3:4), '.', 'color', color{3});
        f(1) = line([1:2], [meanMiss{animalNum,inhibitionSide}(plotOrder(1:2))], 'color', color{1}, 'lineWidth', 2);
        f(2) = line([3:4], [meanMiss{animalNum,inhibitionSide}(plotOrder(3:4))], 'color', color{3}, 'lineWidth', 2);
        xlim([0,6]);
        ylim([0,1.0]);
        xticks([1 2 3 4])
        
        try
            legend(f, {'Contra Stim trials', 'Ipsi Stim trials'}, 'Location', 'northeast')
        catch
            keyboard;
        end
        xticklabels({'Contra Stim only', 'Contra Stim + Opto','Ipsi Stim only', 'Ipsi Stim + Opto'})
        
        ylabel('Performance (fraction correct)')
        title([uInhSites{inhibitionSide} ' inhibition miss']);
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
    savefig(g,fullfile(figureFolder,  [uniAnimalId{animalNum} ' inhibition_miss.fig']));
    
    exportgraphics(g, fullfile(figureFolder,  [uniAnimalId{animalNum} ' inhibition_mean_contraIpsi_miss.png']));
end

%% compare to no manipulation for misses and fraction correct
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
clearvars -except readPaths dataFileTb readPathParts seDir seNames animalID trials inhSitesAll;

animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
AnimalIDs = cellfun(@(x) x{1}, animal, 'UniformOutput', false);
animalID = unique(AnimalIDs);
% get all the trialNums for each trialType for each session and mouse

pathParts = strsplit(seDir, '\');
figureFolder = fullfile(pathParts{1:end-2}, 'Figures');


savePath=(fullfile(figureFolder,'Inhibition', 'ContraIpsi'));
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
        se = BS.Preprocess.keepTrials(trialInd,se);
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



        
if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
    trialTypes = trials{2};
else
    trialTypes = trials{1};
end 

nboot = 10000; % number for bootstrapping
fracMiss = cell(length(Genotypes),length(inhSites), nboot);
fracCorrect = cell(length(Genotypes),length(inhSites), nboot);
delta_mouse = cell(length(Genotypes),length(inhSites), nboot);
delta_session =cell(length(Genotypes),length(inhSites), nboot);
delta_prob = cell(nboot,1);
delta_mouse_miss = cell(length(Genotypes),length(inhSites), nboot);
delta_session_miss =cell(length(Genotypes),length(inhSites), nboot);
delta_prob_miss = cell(nboot,1);
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
                        behavData = v(resampled_trialInds,:);
                        responses = behavData.result;
                        missTrials = isnan(responses);
                        missData = behavData(missTrials,:);
                        behavData(missTrials, :) =[];
                        fracCorrect{g,e,n}{mouse}{session}(trialType) = mean(behavData.result); % lick probability of each trial type 
                        fracMiss{g,e,n}{mouse}{session}(trialType) = numel(find(strcmp(trialTypes{trialType}, missData.trialType)))/...
                            (numel(find(strcmp(trialTypes{trialType}, missData.trialType))) + numel(find(strcmp(trialTypes{trialType}, behavData.trialType))));
                                      
                        
                    end
                    delta_session{g,e,n}{mouse}(session,1:2) = [fracCorrect{g,e,n}{mouse}{session}(2)- fracCorrect{g,e,n}{mouse}{session}(1),...
                        fracCorrect{g,e,n}{mouse}{session}(4)-fracCorrect{g,e,n}{mouse}{session}(3)]; % leftOpto-left, RightOpto-Right
                    delta_session_miss{g,e,n}{mouse}(session,1:2) = [fracMiss{g,e,n}{mouse}{session}(2)- fracMiss{g,e,n}{mouse}{session}(1),...
                        fracMiss{g,e,n}{mouse}{session}(4)-fracMiss{g,e,n}{mouse}{session}(3)]; % leftOpto-left, RightOpto-Right
                   
                   
%                     clear fracCorrect v trialInds
                end
                
                delta_mouse{g,e,n}(mouse,1:2) = mean(delta_session{g,e,n}{mouse},1); % average across sessions
                delta_mouse_miss{g,e,n}(mouse,1:2) = mean(delta_session_miss{g,e,n}{mouse},1); % average across sessions
%                 clear delta_session
            end
            delta_prob{n}(1:2) = mean(delta_mouse{g,e,n},1); % average across mice
            delta_prob_miss{n}(1:2) = mean(delta_mouse_miss{g,e,n},1); % average across mice
%             clear delta_mouse
        end
        
        photoInh_bootstrapped{(g-1)*length(inhSites)+e,1} = Genotype;
        photoInh_bootstrapped{(g-1)*length(inhSites)+e,2} = inhSite;
        photoInh_bootstrapped{(g-1)*length(inhSites)+e,3} = cell2mat(delta_prob);
        photoInh_bootstrapped_miss{(g-1)*length(inhSites)+e,1} = Genotype;
        photoInh_bootstrapped_miss{(g-1)*length(inhSites)+e,2} = inhSite;
        photoInh_bootstrapped_miss{(g-1)*length(inhSites)+e,3} = cell2mat(delta_prob_miss);
%         clear delta_prob
    end
end
toc



% plot correct fraction
KOIDs = {'VC030207', 'VC030208', 'VC030209'};
WTIDs = {'VC030109','VC030110', 'VC030112'};
alpha = 0.05;
clearvars meanStats SEM ts ciStats

for rows = 1:height(photoInh_bootstrapped)
    meanStats{rows} = mean(photoInh_bootstrapped{rows,3},1);
    meanStats_miss{rows} = mean(photoInh_bootstrapped_miss{rows,3},1);
    % what is n samples in SEM calc = height(photoInh_bootstrapped{rows,3})?
    try
        SEM(1:2) = std(photoInh_bootstrapped{rows,3},0,1)/sqrt(height(photoInh_bootstrapped{rows,3}));         
        ts = tinv([alpha/2 1-alpha/2], height(photoInh_bootstrapped{rows,3})-1);        
        ciStats{rows}{1} = meanStats{rows}(1) + ts*SEM(1);
        ciStats{rows}{2} = meanStats{rows}(2) + ts*SEM(2);
       
    catch
        ciStats{rows}{1} =0;
        ciStats{rows}{2} = 0;
         
    end

    try
        SEM_miss(1:2) = std(photoInh_bootstrapped_miss{rows,3},0,1)/sqrt(height(photoInh_bootstrapped{rows,3}));
        ts_miss = tinv([alpha/2 1-alpha/2], height(photoInh_bootstrapped_miss{rows,3})-1);
        ciStats_miss{rows}{1} = meanStats_miss{rows}(1) + ts_miss*SEM_miss(1);
        ciStats_miss{rows}{2} = meanStats_miss{rows}(2) + ts_miss*SEM_miss(2);
    catch
        ciStats_miss{rows}{1} = 0;
        ciStats_miss{rows}{2} = 0; 
    end

end
photoInh_bootstrapped(:,4) = meanStats';
photoInh_bootstrapped(:,5) = ciStats';
photoInh_bootstrapped_miss(:,4) = meanStats_miss';
photoInh_bootstrapped_miss(:,5) = ciStats_miss';
photoInhBootstrapped = table();
vars = {'Genotype', 'InhSite', 'FracCorrect', 'Mean', 'CI'};
photoInhBootstrapped = cell2table(photoInh_bootstrapped,'VariableNames', vars);
photoInhBootstrapped_miss = table();
photoInhBootstrapped_miss = cell2table(photoInh_bootstrapped_miss,'VariableNames', vars);



% colors_tt = {[0.5 0.5 0.5] [1 0 1];[0 1 1] [0.5 0.5 0.5]}; 
% colors_tt = {[0 1 1] [1 0 1]; [0 1 1] [1 0 1]}; 
colors_tt = {[1 0 0] [0 0 1]}; 
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
            
            if sum(ismember(inhSites{e+1}, 'Left')) ==4
                plotOrder = [2,1];
            else
                plotOrder = [1,2];
            end
            n =0;
            for stimNum = plotOrder
                n = n+1;
                errorbar(x(n),y1(stimNum),(y1(stimNum)-y2(stimNum)),(y3(stimNum)-y1(stimNum)),'o','Color',colors_tt{n} ,...
                    'MarkerSize',6,'MarkerFaceColor',colors_tt{n}, 'MarkerEdgeColor',colors_tt{n});   
            end
            
        end
    
    end
    hold off
    set(gca, 'box','off','TickDir','out');
        ylim([-1 0.5]);
    yline(0, '--k');
    ylabel('\DeltaFrac Correct with inhibition')
%     xtickangle(45);
    xlim([0,5]);
    xticks([1 2 3 4])
    xticklabels({'Contra', 'Ipsi', 'Contra', 'Ipsi'})
    title(Genotypes{g});
    savefig(g1,fullfile(savePath,[animalID{1} 'Bootstrapping KO vs WT optoInhibition.fig']));
    exportgraphics(g1,fullfile(savePath, [animalID{1} 'Bootstrapping KO vs WT optoInhibition.png']));
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
        
        
        if sum(ismember(inhSites{e+1}, 'Left')) ==4
            plotOrder = [2,1];
        else
            plotOrder = [1,2];
        end
        n =0;
        for stimNum = plotOrder
            n = n+1;
            swarmchart(x2(:,n),y(:,stimNum),0.5,'o','markerfacecolor', colors_tt{n}, 'MarkerEdgeColor', 'none');
            errorbar(x(n),y1(stimNum),(y1(stimNum)-y2(stimNum)),(y3(stimNum)-y1(stimNum)),'o','Color','black',...
                'MarkerSize',6,'MarkerFaceColor', 'black', 'MarkerEdgeColor','black');  
        end
       
        
    
    end
    hold off
    set(gca, 'box','off','TickDir','out');
    ylim([-1 0.5]);
    ylabel('\DeltaFrac Correct with inhibition')
    yline(0, '--k');
%     xtickangle(45);
    xlim([0,5]);
    xticks([1 2 3 4]);
    xticklabels({'Contra', 'Ipsi', 'Contra', 'Ipsi'})
    title(Genotypes{g});
    savefig(g2,fullfile(savePath, [animalID{1} ' Bootstrapping KO vs WT optoInhibition swarm.fig']));
    exportgraphics(g2,fullfile(savePath, [animalID{1} 'Bootstrapping KO vs WT optoInhibition swarm.png']));
end

g1 = figure(300);clf
for g=1:numel(Genotypes)
    subplot(1,2,numel(Genotypes)-g+1)
    hold on
    for e =0:numel(inhSites)-1
        delta_bootstrapped_g = photoInh_bootstrapped_miss{2*g-1+e:2*g,3};
       
        sorted_delta = sort(delta_bootstrapped_g,1);   
         if ~isempty(sorted_delta)
            y1 = mean(sorted_delta,1); 
            y2 = sorted_delta(nboot*0.025,1:2); 
            y3 = sorted_delta(nboot*0.975,1:2); 
            x = [2*e+1, 2*e+2];
            
            if sum(ismember(inhSites{e+1}, 'Left')) ==4
                plotOrder = [2,1];
            else
                plotOrder = [1,2];
            end
            n =0;
            for stimNum = plotOrder
                n = n+1;
                errorbar(x(n),y1(stimNum),(y1(stimNum)-y2(stimNum)),(y3(stimNum)-y1(stimNum)),'o','Color',colors_tt{n} ,...
                    'MarkerSize',6,'MarkerFaceColor',colors_tt{n}, 'MarkerEdgeColor',colors_tt{n});   
            end
            
        end
    
    end
    hold off
    set(gca, 'box','off','TickDir','out');
        ylim([-1 0.5]);
    yline(0, '--k');
    ylabel('\DeltaMiss fraction with inhibition')
%     xtickangle(45);
    xlim([0,5]);
    xticks([1 2 3 4])
    xticklabels({'Contra', 'Ipsi', 'Contra', 'Ipsi'})
    title(Genotypes{g});
    savefig(g1,fullfile(savePath,[animalID{1} 'Bootstrapping KO vs WT optoInhibition_miss.fig']));
    exportgraphics(g1,fullfile(savePath, [animalID{1} 'Bootstrapping KO vs WT optoInhibition_miss.png']));
end

g2=figure(400);clf
for g=1:numel(Genotypes)
    subplot(1,2,numel(Genotypes)-g+1)
    hold on
    
    for e =0:numel(inhSites)-1
        delta_bootstrapped_g = photoInh_bootstrapped_miss{2*g-1+e:2*g,3};
        sorted_delta = sort(delta_bootstrapped_g,1);   
        y1 = mean(sorted_delta,1); 
        y2 = sorted_delta(nboot*0.025,1:2); 
        y3 = sorted_delta(nboot*0.975,1:2); 
        x = [2*e+1, 2*e+2];
        
        x2 = repmat(x,[height(delta_bootstrapped_g),1]);
        y = sorted_delta;
        
        
        if sum(ismember(inhSites{e+1}, 'Left')) ==4
            plotOrder = [2,1];
        else
            plotOrder = [1,2];
        end
        n =0;
        for stimNum = plotOrder
            n = n+1;
            swarmchart(x2(:,n),y(:,stimNum),0.5,'o','markerfacecolor', colors_tt{n}, 'MarkerEdgeColor', 'none');
            errorbar(x(n),y1(stimNum),(y1(stimNum)-y2(stimNum)),(y3(stimNum)-y1(stimNum)),'o','Color','black',...
                'MarkerSize',6,'MarkerFaceColor', 'black', 'MarkerEdgeColor','black');  
        end
       
        
    
    end
    hold off
    set(gca, 'box','off','TickDir','out');
    ylim([-1 0.5]);
    ylabel('\DeltaMiss fraction with inhibition')
    yline(0, '--k');
%     xtickangle(45);
    xlim([0,5]);
    xticks([1 2 3 4]);
    xticklabels({'Contra', 'Ipsi', 'Contra', 'Ipsi'})
    title(Genotypes{g});
    savefig(g2,fullfile(savePath, [animalID{1} ' Bootstrapping KO vs WT optoInhibition swarm_miss.fig']));
    exportgraphics(g2,fullfile(savePath, [animalID{1} 'Bootstrapping KO vs WT optoInhibition swarm_miss.png']));
end
%% compare to no manipulation for fraction correct only
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
clearvars -except readPaths readPathParts seDir seNames animalID trials inhSitesAll;

animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
AnimalIDs = cellfun(@(x) x{1}, animal, 'UniformOutput', false);
animalID = unique(AnimalIDs);
% get all the trialNums for each trialType for each session and mouse

pathParts = strsplit(seDir, '\');
figureFolder = fullfile(pathParts{1:end-2}, 'Figures');


savePath=(fullfile(figureFolder,'Inhibition', 'ContraIpsi'));
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
KOIDs = {'VC030207', 'VC030208', 'VC030209'};
WTIDs = {'VC030109','VC030110', 'VC030112'};
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




% colors_tt = {[0.5 0.5 0.5] [1 0 1];[0 1 1] [0.5 0.5 0.5]}; 
% colors_tt = {[0 1 1] [1 0 1]; [0 1 1] [1 0 1]}; 
colors_tt = {[1 0 0] [0 0 1]}; 
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
            
            if sum(ismember(inhSites{e+1}, 'Left')) ==4
                plotOrder = [2,1];
            else
                plotOrder = [1,2];
            end
            n =0;
            for stimNum = plotOrder
                n = n+1;
                errorbar(x(n),y1(stimNum),(y1(stimNum)-y2(stimNum)),(y3(stimNum)-y1(stimNum)),'o','Color',colors_tt{n} ,...
                    'MarkerSize',6,'MarkerFaceColor',colors_tt{n}, 'MarkerEdgeColor',colors_tt{n});   
            end
            
        end
    
    end
    hold off
    set(gca, 'box','off','TickDir','out');
        ylim([-1 0.5]);
    yline(0, '--k');
    ylabel('\Deltaperformance with inhibition')
%     xtickangle(45);
    xlim([0,5]);
    xticks([1 2 3 4])
    xticklabels({'Contra', 'Ipsi', 'Contra', 'Ipsi'})
    title(Genotypes{g});
    savefig(g1,fullfile(savePath,[animalID{1} ' Cohort4 Bootstrapping KO vs WT optoInhibition.fig']));
    exportgraphics(g1,fullfile(savePath, [animalID{1} ' Cohort4 Bootstrapping KO vs WT optoInhibition.png']));
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
        
        
        if sum(ismember(inhSites{e+1}, 'Left')) ==4
            plotOrder = [2,1];
        else
            plotOrder = [1,2];
        end
        n =0;
        for stimNum = plotOrder
            n = n+1;
            swarmchart(x2(:,n),y(:,stimNum),0.5,'o','markerfacecolor', colors_tt{n}, 'MarkerEdgeColor', 'none');
            errorbar(x(n),y1(stimNum),(y1(stimNum)-y2(stimNum)),(y3(stimNum)-y1(stimNum)),'o','Color','black',...
                'MarkerSize',6,'MarkerFaceColor', 'black', 'MarkerEdgeColor','black');  
        end
       
        
    
    end
    hold off
    set(gca, 'box','off','TickDir','out');
    ylim([-1 0.5]);
    ylabel('\Deltaperformance with inhibition')
    yline(0, '--k');
%     xtickangle(45);
    xlim([0,5]);
    xticks([1 2 3 4]);
    xticklabels({'Contra', 'Ipsi', 'Contra', 'Ipsi'})
    title(Genotypes{g});
    savefig(g2,fullfile(savePath, [animalID{1} ' Cohort4 Bootstrapping KO vs WT optoInhibition swarm.fig']));
    exportgraphics(g2,fullfile(savePath, [animalID{1} ' Cohort4 Bootstrapping KO vs WT optoInhibition swarm.png']));
end



%% 
clear all
animalID = {};
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
        case 'NoOptoSess'            
            behavDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            seNames = cellfun(@(x) endsWith(x,'se.mat'),behavDirInfo.name);            
            behavDirInfo(~seNames,:) = [];
            animalNames = cellfun(@(x) strsplit(x, ' '), behavDirInfo.name, 'UniformOutput', false);
            animalNames = cellfun(@(x) x{1}, animalNames, 'UniformOutput',false);
            if ~isempty(animalID)
                behavDirInfo(~ismember(animalNames, animalID),:) = [];
            end

           
        case 'SessInfoNoOpto'
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

%% compare to no manipulation for misses and fraction correct
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
clearvars -except readPaths dataFileTb readPathParts seDir seNames animalID trials inhSitesAll;

animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
AnimalIDs = cellfun(@(x) x{1}, animal, 'UniformOutput', false);
animalID = unique(AnimalIDs);
% get all the trialNums for each trialType for each session and mouse

pathParts = strsplit(seDir, '\');
figureFolder = fullfile(pathParts{1:end-2}, 'Figures');


savePath=(fullfile(figureFolder,'Inhibition', 'ContraIpsi'));
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



        
if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
    trialTypes = trials{2};
else
    trialTypes = trials{1};
end 

nboot = 10000; % number for bootstrapping
fracMiss = cell(length(Genotypes),length(inhSites), nboot);
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
                        behavData = v(resampled_trialInds,:);
                        responses = behavData.result;
                        missTrials = isnan(responses);
                        missData = behavData(missTrials,:);
                        behavData(missTrials, :) =[];
                        fracCorrect{g,e,n}{mouse}{session}(trialType) = mean(behavData.result(resampled_trialInds)); % lick probability of each trial type 
                        fracMiss{g,e,n}{mouse}{session}(trialType) = numel(find(strcmp(trialTypes{trialType}, missData.trialType)))/...
                            (numel(find(strcmp(trialTypes{trialType}, missData.trialType))) + numel(find(strcmp(trialTypes{trialType}, behavData.trialType))));
                                      
                        
                    end
                    delta_session{g,e,n}{mouse}(session,1:2) = [fracCorrect{g,e,n}{mouse}{session}(2)- fracCorrect{g,e,n}{mouse}{session}(1),...
                        fracCorrect{g,e,n}{mouse}{session}(4)-fracCorrect{g,e,n}{mouse}{session}(3)]; % leftOpto-left, RightOpto-Right
                    delta_session_miss{g,e,n}{mouse}(session,1:2) = [fracMiss{g,e,n}{mouse}{session}(2)- fracMiss{g,e,n}{mouse}{session}(1),...
                        fracMiss{g,e,n}{mouse}{session}(4)-fracMiss{g,e,n}{mouse}{session}(3)]; % leftOpto-left, RightOpto-Right
                   
                   
%                     clear fracCorrect v trialInds
                end
                
                delta_mouse{g,e,n}(mouse,1:2) = mean(delta_session{g,e,n}{mouse},1); % average across sessions
                delta_mouse_miss{g,e,n}(mouse,1:2) = mean(delta_session_miss{g,e,n}{mouse},1); % average across sessions
%                 clear delta_session
            end
            delta_prob{n}(1:2) = mean(delta_mouse{g,e,n},1); % average across mice
            delta_prob_miss{n}(1:2) = mean(delta_mouse{g,e,n},1); % average across mice
%             clear delta_mouse
        end
        
        photoInh_bootstrapped{(g-1)*length(inhSites)+e,1} = Genotype;
        photoInh_bootstrapped{(g-1)*length(inhSites)+e,2} = inhSite;
        photoInh_bootstrapped{(g-1)*length(inhSites)+e,3} = cell2mat(delta_prob);
        photoInh_bootstrapped_miss{(g-1)*length(inhSites)+e,1} = Genotype;
        photoInh_bootstrapped_miss{(g-1)*length(inhSites)+e,2} = inhSite;
        photoInh_bootstrapped_miss{(g-1)*length(inhSites)+e,3} = cell2mat(delta_prob_miss);
%         clear delta_prob
    end
end
toc



 % plot correct fraction
KOIDs = {'VC030207', 'VC030208', 'VC030209'};
WTIDs = {'VC030109','VC030110', 'VC030112'};
alpha = 0.05;
clearvars meanStats SEM ts ciStats

for rows = 1:height(photoInh_bootstrapped)
    meanStats{rows} = mean(photoInh_bootstrapped{rows,3},1);
    meanStats_miss{rows} = mean(photoInh_bootstrapped_miss{rows,3},1);
    try
        SEM(1:2) = std(photoInh_bootstrapped{rows,3},0,1)/sqrt(height(photoInh_bootstrapped{rows,3}));         
        ts = tinv([alpha/2 1-alpha/2], height(photoInh_bootstrapped{rows,3})-1);        
        ciStats{rows}{1} = meanStats{rows}(1) + ts*SEM(1);
        ciStats{rows}{2} = meanStats{rows}(2) + ts*SEM(2);
       
    catch
        ciStats{rows}{1} =0;
        ciStats{rows}{2} = 0;
         
    end

    try
        SEM_miss(1:2) = std(photoInh_bootstrapped_miss{rows,3},0,1)/sqrt(height(photoInh_bootstrapped{rows,3}));
        ts_miss = tinv([alpha/2 1-alpha/2], height(photoInh_bootstrapped_miss{rows,3})-1);
        ciStats_miss{rows}{1} = meanStats_miss{rows}(1) + ts_miss*SEM_miss(1);
        ciStats_miss{rows}{2} = meanStats_miss{rows}(2) + ts_miss*SEM_miss(2);
    catch
        ciStats_miss{rows}{1} = 0;
        ciStats_miss{rows}{2} = 0; 
    end

end
photoInh_bootstrapped(:,4) = meanStats';
photoInh_bootstrapped(:,5) = ciStats';
photoInh_bootstrapped_miss(:,4) = meanStats_miss';
photoInh_bootstrapped_miss(:,5) = ciStats_miss';
photoInhBootstrapped = table();
vars = {'Genotype', 'InhSite', 'FracCorrect', 'Mean', 'CI'};
photoInhBootstrapped = cell2table(photoInh_bootstrapped,'VariableNames', vars);
photoInhBootstrapped_miss = table();
photoInhBootstrapped_miss = cell2table(photoInh_bootstrapped_miss,'VariableNames', vars);



% colors_tt = {[0.5 0.5 0.5] [1 0 1];[0 1 1] [0.5 0.5 0.5]}; 
% colors_tt = {[0 1 1] [1 0 1]; [0 1 1] [1 0 1]}; 
colors_tt = {[1 0 0] [0 0 1]}; 
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
            
            if sum(ismember(inhSites{e+1}, 'Left')) ==4
                plotOrder = [2,1];
            else
                plotOrder = [1,2];
            end
            n =0;
            for stimNum = plotOrder
                n = n+1;
                errorbar(x(n),y1(stimNum),(y1(stimNum)-y2(stimNum)),(y3(stimNum)-y1(stimNum)),'o','Color',colors_tt{n} ,...
                    'MarkerSize',6,'MarkerFaceColor',colors_tt{n}, 'MarkerEdgeColor',colors_tt{n});   
            end
            
        end
    
    end
    hold off
    set(gca, 'box','off','TickDir','out');
        ylim([-1 0.5]);
    yline(0, '--k');
    ylabel('\DeltaFrac Correct with inhibition')
%     xtickangle(45);
    xlim([0,5]);
    xticks([1 2 3 4])
    xticklabels({'Contra', 'Ipsi', 'Contra', 'Ipsi'})
    title(Genotypes{g});
    savefig(g1,fullfile(savePath,[animalID{1} 'Bootstrapping KO vs WT optoInhibition.fig']));
    exportgraphics(g1,fullfile(savePath, [animalID{1} 'Bootstrapping KO vs WT optoInhibition.png']));
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
        
        
        if sum(ismember(inhSites{e+1}, 'Left')) ==4
            plotOrder = [2,1];
        else
            plotOrder = [1,2];
        end
        n =0;
        for stimNum = plotOrder
            n = n+1;
            swarmchart(x2(:,n),y(:,stimNum),0.5,'o','markerfacecolor', colors_tt{n}, 'MarkerEdgeColor', 'none');
            errorbar(x(n),y1(stimNum),(y1(stimNum)-y2(stimNum)),(y3(stimNum)-y1(stimNum)),'o','Color','black',...
                'MarkerSize',6,'MarkerFaceColor', 'black', 'MarkerEdgeColor','black');  
        end
       
        
    
    end
    hold off
    set(gca, 'box','off','TickDir','out');
    ylim([-1 0.5]);
    ylabel('\DeltaFrac Correct with inhibition')
    yline(0, '--k');
%     xtickangle(45);
    xlim([0,5]);
    xticks([1 2 3 4]);
    xticklabels({'Contra', 'Ipsi', 'Contra', 'Ipsi'})
    title(Genotypes{g});
    savefig(g2,fullfile(savePath, [animalID{1} ' Bootstrapping KO vs WT optoInhibition swarm.fig']));
    exportgraphics(g2,fullfile(savePath, [animalID{1} 'Bootstrapping KO vs WT optoInhibition swarm.png']));
end

g1 = figure(300);clf
for g=1:numel(Genotypes)
    subplot(1,2,numel(Genotypes)-g+1)
    hold on
    for e =0:numel(inhSites)-1
        delta_bootstrapped_g = photoInh_bootstrapped_miss{2*g-1+e:2*g,3};
       
        sorted_delta = sort(delta_bootstrapped_g,1);   
         if ~isempty(sorted_delta)
            y1 = mean(sorted_delta,1); 
            y2 = sorted_delta(nboot*0.025,1:2); 
            y3 = sorted_delta(nboot*0.975,1:2); 
            x = [2*e+1, 2*e+2];
            
            if sum(ismember(inhSites{e+1}, 'Left')) ==4
                plotOrder = [2,1];
            else
                plotOrder = [1,2];
            end
            n =0;
            for stimNum = plotOrder
                n = n+1;
                errorbar(x(n),y1(stimNum),(y1(stimNum)-y2(stimNum)),(y3(stimNum)-y1(stimNum)),'o','Color',colors_tt{n} ,...
                    'MarkerSize',6,'MarkerFaceColor',colors_tt{n}, 'MarkerEdgeColor',colors_tt{n});   
            end
            
        end
    
    end
    hold off
    set(gca, 'box','off','TickDir','out');
        ylim([-1 0.5]);
    yline(0, '--k');
    ylabel('\DeltaMiss fraction with inhibition')
%     xtickangle(45);
    xlim([0,5]);
    xticks([1 2 3 4])
    xticklabels({'Contra', 'Ipsi', 'Contra', 'Ipsi'})
    title(Genotypes{g});
    savefig(g1,fullfile(savePath,[animalID{1} 'Bootstrapping KO vs WT optoInhibition_miss.fig']));
    exportgraphics(g1,fullfile(savePath, [animalID{1} 'Bootstrapping KO vs WT optoInhibition_miss.png']));
end

g2=figure(400);clf
for g=1:numel(Genotypes)
    subplot(1,2,numel(Genotypes)-g+1)
    hold on
    
    for e =0:numel(inhSites)-1
        delta_bootstrapped_g = photoInh_bootstrapped_miss{2*g-1+e:2*g,3};
        sorted_delta = sort(delta_bootstrapped_g,1);   
        y1 = mean(sorted_delta,1); 
        y2 = sorted_delta(nboot*0.025,1:2); 
        y3 = sorted_delta(nboot*0.975,1:2); 
        x = [2*e+1, 2*e+2];
        
        x2 = repmat(x,[height(delta_bootstrapped_g),1]);
        y = sorted_delta;
        
        
        if sum(ismember(inhSites{e+1}, 'Left')) ==4
            plotOrder = [2,1];
        else
            plotOrder = [1,2];
        end
        n =0;
        for stimNum = plotOrder
            n = n+1;
            swarmchart(x2(:,n),y(:,stimNum),0.5,'o','markerfacecolor', colors_tt{n}, 'MarkerEdgeColor', 'none');
            errorbar(x(n),y1(stimNum),(y1(stimNum)-y2(stimNum)),(y3(stimNum)-y1(stimNum)),'o','Color','black',...
                'MarkerSize',6,'MarkerFaceColor', 'black', 'MarkerEdgeColor','black');  
        end
       
        
    
    end
    hold off
    set(gca, 'box','off','TickDir','out');
    ylim([-1 0.5]);
    ylabel('\DeltaMiss fraction with inhibition')
    yline(0, '--k');
%     xtickangle(45);
    xlim([0,5]);
    xticks([1 2 3 4]);
    xticklabels({'Contra', 'Ipsi', 'Contra', 'Ipsi'})
    title(Genotypes{g});
    savefig(g2,fullfile(savePath, [animalID{1} ' Bootstrapping KO vs WT optoInhibition swarm_miss.fig']));
    exportgraphics(g2,fullfile(savePath, [animalID{1} 'Bootstrapping KO vs WT optoInhibition swarm_miss.png']));
end
%% compare misses for genotypes
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

animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
AnimalIDs = cellfun(@(x) x{1}, animal, 'UniformOutput', false);
animalID = unique(AnimalIDs);
% get all the trialNums for each trialType for each session and mouse

pathParts = strsplit(seDir, '\');
figureFolder = fullfile(pathParts{1:end-2}, 'Figures');


savePath=(fullfile(figureFolder,'Inhibition', 'ContraIpsi'));
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
        
              
             
        photoInhAll= [photoInhAll; behavData];
        
        sessNum= sessNum+1;
        
       
    end
end




Genotypes = unique(photoInhAll.Genotype); 

trialTypes= unique(photoInhAll.trialType); % left, left_opto, right, right_opto
leftStimWT = unique(photoInhAll(ismember(photoInhAll.Genotype,{'WT'}),'leftStimType'));
leftStimKO = unique(photoInhAll(ismember(photoInhAll.Genotype,{'KO'}),'leftStimType'));
rightStimWT = unique(photoInhAll(ismember(photoInhAll.Genotype,{'WT'}),'rightStimType'));
rightStimKO = unique(photoInhAll(ismember(photoInhAll.Genotype,{'KO'}),'rightStimType'));
        
if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
    trialTypes = trials{2};
else
    trialTypes = trials{1};
end 

nboot = 10000; % number for bootstrapping
fracMiss = cell(length(Genotypes), nboot);
miss_mouse = cell(length(Genotypes), nboot);
miss_session =cell(length(Genotypes), nboot);
miss_prob = cell(nboot);
tic

for g = 1:length(Genotypes)
    
    Genotype = Genotypes{g};
   
        
    u = photoInhAll(strcmp(photoInhAll.Genotype, Genotype), :);
        
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
                    behavData = v(resampled_trialInds,:);
                    responses = behavData.result;
                    missTrials = isnan(responses);
                    missData = behavData(missTrials,:);
                    behavData(missTrials, :) =[];
                    fracMiss{g,n}{mouse}{session}(trialType) = numel(find(strcmp(trialTypes{trialType}, missData.trialType)))/...
                        (numel(find(strcmp(trialTypes{trialType}, missData.trialType))) + numel(find(strcmp(trialTypes{trialType}, behavData.trialType))));
                                  
                    
                end

                miss_session{g,n}{mouse}(session,1:2) = [fracMiss{g,n}{mouse}{session}(1),...
                    fracMiss{g,n}{mouse}{session}(3)]; % left, Right
               
               
%                     clear fracCorrect v trialInds
            end
            
            miss_mouse{g,n}(mouse,1:2) = mean(miss_session{g,n}{mouse},1); % average across sessions
%                 clear delta_session
        end
        miss_prob{n}(1:2) = mean(miss_mouse{g,n},1); % average across mice
%             clear delta_mouse
    end
    
    photoInh_bootstrapped{(g),1} = Genotype;    
    photoInh_bootstrapped{(g),3} = cell2mat(miss_prob);
%         clear delta_prob
    
end
toc



% plot miss fraction
KOIDs = {'VC030207', 'VC030208', 'VC030209'};
WTIDs = {'VC030109','VC030110', 'VC030112'};
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


%

% colors_tt = {[0.5 0.5 0.5] [1 0 1];[0 1 1] [0.5 0.5 0.5]}; 
% colors_tt = {[0 1 1] [1 0 1]; [0 1 1] [1 0 1]}; 
colors_tt = {[1 0 0] [0 0 1]}; 
close all;
g1 = figure(100);clf
for g=1:numel(Genotypes)
    subplot(1,numel(Genotypes),g)
    hold on
    
    delta_bootstrapped_g = photoInh_bootstrapped{g,3};
   
    sorted_delta = sort(delta_bootstrapped_g,1);   
     if ~isempty(sorted_delta)
        y1 = mean(sorted_delta,1); 
        y2 = sorted_delta(nboot*0.025,1:2); 
        y3 = sorted_delta(nboot*0.975,1:2); 
        x = [1, 2];
        
        
        plotOrder = [1,2];
        
        n =0;
        for stimNum = plotOrder
            n = n+1;
            errorbar(x(n),y1(stimNum),(y1(stimNum)-y2(stimNum)),(y3(stimNum)-y1(stimNum)),'o','Color',colors_tt{n} ,...
                'MarkerSize',6,'MarkerFaceColor',colors_tt{n}, 'MarkerEdgeColor',colors_tt{n});   
        end
        
    end
    
    
    hold off
    set(gca, 'box','off','TickDir','out');
    ylim([0 0.5]);
%     yline(0, '--k');
    ylabel('Miss fraction without inhibition')
%     xtickangle(45);
    xlim([0,3]);
    xticks([1 2])
    xticklabels({'Left stim', 'Right Stim'})
    title(Genotypes{g});
    savefig(g1,fullfile(savePath,'All animals Bootstrapping KO vs WT optoInhibition_miss.fig'));
    exportgraphics(g1,fullfile(savePath, 'All animals Bootstrapping KO vs WT optoInhibition_miss.png'));
end

g2=figure(200);clf
for g=1:numel(Genotypes)
    subplot(1,2,numel(Genotypes)-g+1)
    hold on
    
    
    delta_bootstrapped_g = photoInh_bootstrapped{g,3};
    sorted_delta = sort(delta_bootstrapped_g,1);   
    y1 = mean(sorted_delta,1); 
    y2 = sorted_delta(nboot*0.025,1:2); 
    y3 = sorted_delta(nboot*0.975,1:2); 
    x = [1, 2];
    
    x2 = repmat(x,[height(delta_bootstrapped_g),1]);
    y = sorted_delta;
    
    
    
    plotOrder = [1,2];
    
    n =0;
    for stimNum = plotOrder
        n = n+1;
        swarmchart(x2(:,n),y(:,stimNum),0.5,'o','markerfacecolor', colors_tt{n}, 'MarkerEdgeColor', 'none');
        errorbar(x(n),y1(stimNum),(y1(stimNum)-y2(stimNum)),(y3(stimNum)-y1(stimNum)),'o','Color','black',...
            'MarkerSize',6,'MarkerFaceColor', 'black', 'MarkerEdgeColor','black');  
    end
   
        
    
    
    hold off
    set(gca, 'box','off','TickDir','out');
    ylim([0 0.5]);
    ylabel('Miss fraction without inhibition')
%     yline(0, '--k');
%     xtickangle(45);
    xlim([0,3]);
    xticks([1 2])
    xticklabels({'Left stim', 'Right Stim'})
    title(Genotypes{g});
    savefig(g2,fullfile(savePath, ['All animals Bootstrapping KO vs WT optoInhibition swarm_miss.fig']));
    exportgraphics(g2,fullfile(savePath, ['All animals Bootstrapping KO vs WT optoInhibition swarm_miss.png']));
end
%% compare stim amplitudes for genotypes
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

% take all the sessions with Freq20 and Cyc3 or dur0p150.
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


animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
AnimalIDs = cellfun(@(x) x{1}, animal, 'UniformOutput', false);
animalID = unique(AnimalIDs);
% get all the trialNums for each trialType for each session and mouse

pathParts = strsplit(seDir, '\');
figureFolder = fullfile(pathParts{1:end-2}, 'Figures');


savePath=(fullfile(figureFolder,'Inhibition', 'ContraIpsi'));
if ~exist(savePath, 'dir')
    mkdir(savePath);
end
%

leftStimGrade =[];
rightStimGrade = [];
genotype = [];


for animalNum =1:size(animalID,1)
     ani = animalID{animalNum}; 
     
    sessNum =1;
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
%         behavData(missTrials, :) =[];
        
        % Find inhibition sites
        inhSite = find(ismember(inhSitesAll, behavData.inhSite{1}));

        
        
        trialTypes = unique(behavData.trialType);
        
        if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
            trialTypes = trials{2};
        else
            trialTypes = trials{1};
        end


     
        leftStim = behavData.leftStimType{end-10};           
        rightStim = behavData.rightStimType{end-10};
        if any(ismember(stimTypes, rightStim)) && any(ismember(stimTypes, leftStim))
            leftStimGrade{animalNum}{sessNum}= stimGrades(ismember(stimTypes, leftStim));
            rightStimGrade{animalNum}{sessNum} = stimGrades(ismember(stimTypes, rightStim));
        elseif any(ismember(stimTypes2, rightStim)) && any(ismember(stimTypes2, leftStim))
            leftStimGrade{animalNum}{sessNum} = stimGrades2(ismember(stimTypes2, leftStim));
            rightStimGrade{animalNum}{sessNum} = stimGrades2(ismember(stimTypes2, rightStim));
        else
            leftStimGrade{animalNum}{sessNum} = 0;
            rightStimGrade{animalNum}{sessNum} = 0;
        end
        
        
  
        genotype{animalNum}= behavData.Genotype{end};
        
        
              
             
        
        
        sessNum = sessNum+1;
        
       
    end
    
     genotype{animalNum}= behavData.Genotype{end};
end




% rightStimGrade = cellfun(@transpose, rightStimGrade, 'UniformOutput', false);
rightStimGrade = cellfun(@cell2mat, rightStimGrade, 'UniformOutput', false);
% leftStimGrade = cellfun(@transpose, leftStimGrade, 'UniformOutput', false);
leftStimGrade = cellfun(@cell2mat, leftStimGrade, 'UniformOutput', false);
% 



WTLeft = cell2mat(leftStimGrade(ismember(genotype, 'WT')));
WTRight = cell2mat(rightStimGrade(ismember(genotype, 'WT')));
KOLeft = cell2mat(leftStimGrade(ismember(genotype, 'KO')));
KORight = cell2mat(rightStimGrade(ismember(genotype, 'KO')));

g = figure();clf;
hold on
k = subplot(1,2,1)
hold(k, 'on')
swarmchart(ones(numel(WTLeft))*1, WTLeft, 'o', 'markeredgecolor', [1 0 0], 'markerfacecolor', 'none');
swarmchart(ones(numel(WTRight))*2, WTRight, 'o', 'markeredgecolor', [0 0 1], 'markerfacecolor', 'none');
ylim([0,1.1]);
ylabel('amplitude (fraction of max)');
xticks([1,2])
xticklabels({'Left Stim', 'Right Stim'})
title('WT')
hold(k, 'off')
k = subplot(1,2,2)
hold(k, 'on')
swarmchart(ones(numel(KOLeft))*1, KOLeft, 'o', 'markeredgecolor', [1 0 0], 'markerfacecolor', 'none');
swarmchart(ones(numel(KORight))*2, KORight, 'o', 'markeredgecolor', [0 0 1], 'markerfacecolor', 'none');
ylim([0,1.1]);
ylabel('amplitude (fraction of max)');
xticks([1,2])
xticklabels({'Left Stim', 'Right Stim'})
title('KO')
hold(k, 'off')
savefig(g,fullfile(savePath,'All animals Bootstrapping KO vs WT optoInhibition_amplitude.fig'));
exportgraphics(g,fullfile(savePath, 'All animals Bootstrapping KO vs WT optoInhibition_amplitude.png'));

%% compare to no manipulation all animals 
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
clearvars -except readPaths readPathParts seDir seNames animalID trials inhSitesAll dataFileTb;

animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
AnimalIDs = cellfun(@(x) x{1}, animal, 'UniformOutput', false);
animalID = unique(AnimalIDs);
% get all the trialNums for each trialType for each session and mouse

pathParts = strsplit(seDir, '\');
figureFolder = fullfile(pathParts{1:end-2}, 'Figures');


savePath=(fullfile(figureFolder,'Inhibition', 'ContraIpsi'));
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
KOIDs = {'VC030207', 'VC030208', 'VC030209'};
WTIDs = {'VC030109','VC030110', 'VC030112'};
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




% colors_tt = {[0.5 0.5 0.5] [1 0 1];[0 1 1] [0.5 0.5 0.5]}; 
% colors_tt = {[0 1 1] [1 0 1]; [0 1 1] [1 0 1]}; 
colors_tt = {[1 0 0] [0 0 1]}; 
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
            
            if sum(ismember(inhSites{e+1}, 'Left')) ==4
                plotOrder = [2,1];
            else
                plotOrder = [1,2];
            end
            n =0;
            for stimNum = plotOrder
                n = n+1;
                errorbar(x(n),y1(stimNum),(y1(stimNum)-y2(stimNum)),(y3(stimNum)-y1(stimNum)),'o','Color',colors_tt{n} ,...
                    'MarkerSize',6,'MarkerFaceColor',colors_tt{n}, 'MarkerEdgeColor',colors_tt{n});   
            end
            
        end
    
    end
    hold off
    set(gca, 'box','off','TickDir','out');
        ylim([-1 0.5]);
    yline(0, '--k');
    ylabel('\Deltaperformance with inhibition')
%     xtickangle(45);
    xlim([0,5]);
    xticks([1 2 3 4])
    xticklabels({'Contra', 'Ipsi', 'Contra', 'Ipsi'})
    title(Genotypes{g});
    savefig(g1,fullfile(savePath,'All animals Bootstrapping KO vs WT optoInhibition contra Ipsi.fig'));
    exportgraphics(g1,fullfile(savePath, 'All animals Bootstrapping KO vs WT optoInhibition contra Ipsi.png'));
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
        
        
        if sum(ismember(inhSites{e+1}, 'Left')) ==4
            plotOrder = [2,1];
        else
            plotOrder = [1,2];
        end
        n =0;
        for stimNum = plotOrder
            n = n+1;
            swarmchart(x2(:,n),y(:,stimNum),0.5,'o','markerfacecolor', colors_tt{n}, 'MarkerEdgeColor', 'none');
            errorbar(x(n),y1(stimNum),(y1(stimNum)-y2(stimNum)),(y3(stimNum)-y1(stimNum)),'o','Color','black',...
                'MarkerSize',6,'MarkerFaceColor', 'black', 'MarkerEdgeColor','black');  
        end
       
        
    
    end
    hold off
    set(gca, 'box','off','TickDir','out');
    ylim([-1 0.5]);
    ylabel('\Deltaperformance with inhibition')
    yline(0, '--k');
%     xtickangle(45);
    xlim([0,5]);
    xticks([1 2 3 4]);
    xticklabels({'Contra', 'Ipsi', 'Contra', 'Ipsi'})
    title(Genotypes{g});
    savefig(g2,fullfile(savePath, 'All animals Bootstrapping KO vs WT optoInhibition swarm contra Ipsi.fig'));
    exportgraphics(g2,fullfile(savePath, 'All animals Bootstrapping KO vs WT optoInhibition swarm contra Ipsi.png'));
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