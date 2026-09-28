


%% Plot units separated by whisker stim duration. Contra vs ipsi, combine for left vs right hemisphere recording . combine plotsession_maps
% It also has LFPs
% Stims are taken as only the first deflection of all frequencies 
% clear all
% 
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\StimSEs', 'Select source SEs');

clear all
animalID = {'VC030107','VC030109','VC030112','VC030114', 'VC030115', 'VC030209','VC030206',  'VC030208',   'VC030401', 'VC030402', 'VC030211', 'VC030213'};
% animalID = {'VC030211'};
% animalID = {'VC030401'};
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
ops.numcyc = 3;
ops.constantWindow = 0.3; 
ops.windows = [0.025,0.04, 0.05, 0.075,0.1,0.15,0.2,0.3];
ops.WindowNames = {'25', '40', '50' '75', '100', '150', '200', '300'};
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
ops.cyc = 3;
ops.binWidth = 0.05; % this is for histograms. 
% FRlims = [-0.15 0.15];
ops.tWins = [-0.31, 0.31];
animalIds = unique(dataFileTb.animalId);
ops.folderSigma = [strrep(['StatAlpha ' num2str(0.005)], '.', '_') ' numcyc=' num2str(ops.numcyc)];
% windowSize = 0.15; %in seconds 

% ops.stimDurs = {'150','100','050','020','010','005'}; %in ms

% ops.stimDurs = {'150'}; %in ms
ops.universalWindow =1;
if ops.universalWindow
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\allWins_cyc3',[strjoin(animalIds, '_') '_NP\AllUnitswS1',FRbin]);
else
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\firstcyc',[strjoin(animalIds, '_') '_NP\AllUnitswS1',FRbin], [num2str(0.005) ' numcyc=' num2str(ops.numcyc) 'paired selective']);
end


%% load metadata variables
load(fullfile(ops.savePath, "allVars.mat"),'metadataTable');

% load FRdata variables
load(fullfile(ops.savePath, "FRdataVars.mat"),'FRdataTable');


%% Merge for YT

FRdataTable.pvalMin = metadataTable.pvalBoth;
FRdataTable.pvalContra = metadataTable.pvalContra;
FRdataTable.pvalIpsi = metadataTable.pvalIpsi;
FRdataTable.genotype = metadataTable.genotype;

save('S1DataTable.mat', "FRdataTable", '-v7.3');

%% load spikeData variables
load(fullfile(ops.savePath, "allVars.mat"),'spikedataTable');

%% Make variables for raster FR rate, etc
GetComposite(dataFileTb, ops);

%% Make variables for raster FR rate, etc
GetFRData(dataFileTb, ops);


%% Add meanFR data
AddMeanFRData(ops, FRdataTable);

%%  Load MeanFRTable
load(fullfile(ops.savePath, "meanFRTable.mat"),'meanFRTable');


 %% Calculate sig units for each GT and then do binomial test. 
 ops.binWidth = 0.0025;
 IpsiresponsiveLatencies(ops, metadataTable, meanFRTable );

%% plot Rasters
MakeFigures(fullfile(ops.savePath, fileName));


 %% Plot indivdual rasters and FRs

 MakeIndUnitFigures(fullfile(ops.savePath,fileName), 'E:\oconnorlab Dropbox\oconnorlab Team Folder\users\Varun\SfnPresentations\BarrelsPosterAttempt2023');


%% Plot FR or FRdata across all mice in a genotype

for win = 1:numel(ops.WindowNames)
    window = ops.WindowNames{win};
    PlotAvgTracesFR(dataFileTb, ops, metadataTable, FRdataTable, window);
end

 %% Plot Cbiastable
ops.binWidth = 0.25;
ops.plotAlpha = 0.01;
MakeCbiasFigures(ops, ops.binWidth, ops.savePath, metadataTable);


%% PLot Depth vs Cbias histogram. 
% Take depths of every 20um bin size and plot cBias histogram
%  L1, 128 ± 1 μm; L2, 269 ± 2 μm; L3, 418 ± 3 μm; L4, 588 ± 3 μm; L5A, 708 ± 4 μm; L5B, 890 ± 5 μm; L6, 1154 ± 7 μm.
% Lefort et al Neuron 2009
ops.binWidth = 0.25;
ops.plotAlpha = 0.01;
CBiasDepthHisto(ops, metadataTable);
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

function outputTable = SignifyTable(inputTable,pvalTable, ops)
    
    for ani = 1:numel(pvalTable)
        anipvalTable = pvalTable{ani};

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

function GetComposite(dataFileTb, ops)


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
    
    uniAnimalId = unique(dataFileTb.MouseName);
    
    variableNames = {'genotype', 'pvalBoth', 'pvalContra', 'pvalIpsi', 'UnitDepth', 'adc', 'cbias', 'bodysideTask'};
    
    readPaths= dataFileTb.sePath;
    uGenotypes = unique(dataFileTb.Genotype);
    genotypes = dataFileTb.Genotype;
    sessDates = dataFileTb.sessionDatetime;
    subIds = dataFileTb.subId;
    
    bins = tWins(1):binSize:tWins(2);
    dataTable = cell(numel(uniAnimalId), numel(variableNames));
    metadataTable = cell2table(dataTable, 'RowNames', uniAnimalId, 'VariableNames', variableNames);
    spikedataTable = cell2table(cell(numel(uniAnimalId), 1), 'RowNames', uniAnimalId, 'VariableNames', {'spikeTimes'});
    keyboard;
    parfor animal = 1:numel(uniAnimalId)
        animalId = uniAnimalId{animal};
        dataTable = cell(1, numel(variableNames));
        animalTable = cell2table(dataTable, 'RowNames', {animalId}, 'VariableNames', variableNames);
        spikeAnimalTable = cell2table(cell(1,1), 'RowNames', {animalId}, 'VariableNames', {'spikeTimes'});
        

        animalReadPaths = readPaths(strcmp(uniAnimalId(animal), animalID));
        sessIDs = [datestr(sessDates(strcmp(uniAnimalId(animal), animalID)), 'yymmdd') [subIds{strcmp(uniAnimalId(animal), animalID)}]'];
         % Convert the character array to a cell array
        sessArray = cell(size(sessIDs, 1), 1);
        for i = 1:size(sessIDs, 1)
            sessArray{i} = sessIDs(i, :);
        end

        defaultWinTable = cell(numel(sessArray), numel(ops.windows));
        defaultWinTable = cell2table(defaultWinTable, "RowNames", sessArray, 'VariableNames', ops.WindowNames);
        
        animalTable.genotype(animalId) = unique(dataFileTb.Genotype(strcmp(uniAnimalId(animal), animalID)));
        for var = 2:numel(variableNames)
            varName = variableNames{var};
            
            animalTable.(varName){animalId} = defaultWinTable;
           

        end

        spikeAnimalTable.('spikeTimes'){animalId} = defaultWinTable;
       
        % (sessIDs, animalReadPaths, ops, sessArray, animalTable, animalID)
        close all
        tic
        for sessNum = 1:numel(sessArray)
%
            se =loadsess(animalReadPaths{sessNum});
            %
            sessRecSite = cell2mat(se.userData.sessionInfo.recSite);
            sessName = sessArray{sessNum};           
                
            fprintf('%s\n\n', animalReadPaths{sessNum});
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

                
            

            % convert frAll to z-score
            
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
                [~, chanPos] = ismember(channelInds, chanMap);
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
            charString = ['Cyc' num2str(ops.cyc)];
            % Define the size of the cell array
            numRows = numel(ufreq);
            numCols = 1;
            
            % Create the char cell array
            charCellArray = repmat({charString}, numRows, numCols);
            ufreq = cellfun(@(x) [x charCellArray{1}], ufreq, 'UniformOutput', false);
            
            
            unitNums = size(spikeAll,2);
           

            unitNumArray = cell(unitNums,1);
            for unitNum = 1: unitNums
                unitNumArray{unitNum} = ['Unit' num2str(unitNum)];
            end

            stimArray = cellfun(@(x) [x 'hz'], ufreq, 'UniformOutput', false);
            
                    
            defualtStimTable = cell(unitNums, numel(ufreq));
            defualtStimTable = cell2table(defualtStimTable, "RowNames", unitNumArray, 'VariableNames', stimArray);
            
            for  var = 2:numel(variableNames)
                varName1 = variableNames{var};
                for var2 = 1:numel(ops.windows)
                    varName2 = ops.WindowNames{var2};                    
                    animalTable.(varName1){animalId}.(varName2){sessName} = defualtStimTable;
                end
            end
            

            for var2 = 1:numel(ops.windows)
                    varName2 = ops.WindowNames{var2};
                    spikeAnimalTable.('spikeTimes'){animalId}.(varName2){sessName} = defualtStimTable;
                   
            end

            adc = cell(1,numel(ufreq));
                
            sessInfoTable = se.userData.sessionInfo;

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
                    bodyside7 =7;
                else
                    bodyside7 =8;
                    pstimDur = stimDur;
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
                
                for window = 1:numel(ops.windows)
                    windowSize = ops.windows(window);
                    binsWin = find(bins>= -windowSize & bins<= windowSize);
                    plotLims = [-windowSize, windowSize];
                    temp = binsWin;
                    try
                        frAllwin = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                    catch                            
                        errorTrials = find(cell2mat(cellfun(@(x) numel(x)< temp(end), frAll(:,1), 'UniformOutput',false)));
                        behavData(errorTrials,:) =[];
                        frAll(errorTrials,:)=[];
                        spikeAll(errorTrials,:)=[];
                        frAllwin = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                    end

                    leftStimTypes = behavData.leftStimType;
                    rightStimTypes = behavData.rightStimType;

                   
                    
                    trials2keepL= find(strcmp(trials{1}{1}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(freqStart:freqStart+5),ufreq{stimDur}), ...
                            leftStimTypes, 'UniformOutput',false)));
                    trials2keepR = find(strcmp(trials{1}{2}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(freqStart:freqStart+5),ufreq{stimDur}), ...
                            rightStimTypes, 'UniformOutput',false)));
                    
                    


                    FRLeft  = frAllwin (trials2keepL ,2:end);
                    FRRight  = frAllwin (trials2keepR ,2:end);
                    FRtime  = frAllwin (trials2keepR ,1);
                    
                    %get p-value based on windowsize = stim duration                        
                    preWindow  = 1:(round(numel(FRLeft {1})/2));
                    postWindow  =  preWindow(end)+1: numel(FRLeft {1}); 
                    temp1 = preWindow ;
                    temp2 = postWindow ;

                    preMeanFRL  = cell2mat(cellfun(@(x) mean(x(temp1)), FRLeft , 'UniformOutput', false));
                    postMeanFRL  = cell2mat(cellfun(@(x) mean(x(temp2)), FRLeft , 'UniformOutput', false));
                    preMeanFRR  = cell2mat(cellfun(@(x) mean(x(temp1)), FRRight , 'UniformOutput', false));
                    postMeanFRR  = cell2mat(cellfun(@(x) mean(x(temp2)), FRRight , 'UniformOutput', false));
                    
                    % get spikeTimes for FRlims
                    FRlims  = [tWins(1) tWins(2)];               
                    spikeLeft = spikeAll(trials2keepL ,1:end);
                    spikeRight = spikeAll(trials2keepR ,1:end);          
                    binsWin  = find(bins>= FRlims (1) & bins<= FRlims (2));
                    temp = binsWin (1:end-1);
%                     
%                     frAllplot  = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
%                     FRLeft  = frAllplot (trials2keepL ,2:end);
%                     FRRight  = frAllplot (trials2keepR ,2:end);
%                     FRtime  = frAllplot (:,1);        
% 

                 

                    adcLeft = adcAllLeft(trials2keepL);
                    idcs = min(cell2mat(cellfun(@(x) numel(x), adcLeft, 'UniformOutput',false)));
                    adcLeft = cell2mat(cellfun(@(x) x(1:idcs), adcAllLeft(trials2keepL), 'UniformOutput', false));
                    adcTime =  cell2mat(cellfun(@(x) x(1:idcs), adcAllTime(trials2keepL), 'UniformOutput', false));
                    adc{1,1} = mean(adcTime, 1) ;
                    adc{2,1} = mean(adcLeft, 1) ;
                   

%                             maxAdc{genotype}{recSite}(sessNum,stimDur) = max(adc (2,:));
                    
                    if sum(ismember('Left', sessRecSite))==4
                        stims = {trials2keepL , trials2keepR };
                    else
                        stims = {trials2keepR , trials2keepL };
                    end
                   
                    win = ops.WindowNames{window};

                    try
                        for unitNum = 1: size(preMeanFRL ,2)   
                            
                            unitDepth = unitChanDepth(unitNum);

                            
                            [pvalL] = signrank(preMeanFRL (:,unitNum), postMeanFRL (:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);
                            [pvalR] = signrank(preMeanFRR (:,unitNum), postMeanFRR (:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);
                 
%                             meanFRtime =  mean(cell2mat(FRtime),1);
                        
                            if sum(ismember(sessRecSite, 'Left'))==4
                                uSpikesIpsi = spikeLeft(:,unitNum);
                                uSpikesContra = spikeRight(:,unitNum);
                                pValIpsi = pvalL;
                                pValContra = pvalR;
%                                 [uFRI, ~ ,~, ciFRI] =  MMath.MeanStats(cell2mat(FRLeft(:,unitNum)),1);
%                                 uFRC = mean(cell2mat(FRRight(:,unitNum)),1);
                            else
                                uSpikesIpsi = spikeRight(:,unitNum);
                                uSpikesContra = spikeLeft(:,unitNum);
                                pValIpsi = pvalR;
                                pValContra = pvalL;
%                                 [uFRI, ~ ,~, ciFRI] = MMath.MeanStats(cell2mat(FRRight(:,unitNum)),1);
%                                 uFRC = mean(cell2mat(FRLeft(:,unitNum)),1);
                            end
                            
                            preSpikesContra = sum(cell2mat(cellfun(@(x) numel(find(x>plotLims (1) & x<=0)), ...
                                uSpikesContra, 'UniformOutput', false)));
                            postSpikesContra = sum(cell2mat(cellfun(@(x) numel(find(x>0 & x<=plotLims (2))), ...
                                uSpikesContra, 'UniformOutput', false)));
                            preSpikesIpsi = sum(cell2mat(cellfun(@(x) numel(find(x>plotLims (1) & x<=0)), ...
                                uSpikesIpsi, 'UniformOutput', false)));
                            postSpikesIpsi = sum(cell2mat(cellfun(@(x) numel(find(x>0 & x<=plotLims (2))), ...
                                uSpikesIpsi, 'UniformOutput', false)));
                            pvalstimDur = min(pvalL, pvalR);   
                            
                            
%                             if  pValIpsi < 0.05 && window ==7
%                                 
%                                 disp(['sessNum = ' num2str(sessNum) ' UnitNum= ' num2str(unitNum) ' Window= ' ops.WindowNames{window} ...
%                                     ' pvalIpsi= ' num2str(pValIpsi) ' freq = ' ufreq{pstimDur}]);
%                                 g = figure(1);clf
%                                 hold on
%                                 yyaxis left;
%                                 for i = 1:height(uSpikesIpsi)                                
%                                     MPlot.PlotPointAsLine(uSpikesIpsi{i}*1000, (i+1)*ones(numel(uSpikesIpsi{i}),1) ,1, 'orientation', 'vertical', ...
%                                         'linestyle', '-','color','b', 'linewidth', 1, 'Marker', 'none');
%                                 end                                
%                                 yLimits = ylim;
%                                 ylim([0,yLimits(2)]);
%                                 
%                                 MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--', ...
%                                 'color',[0 0 0], 'linewidth', 1);
%                                 ylabel('Trials')
% 
%                                 
%                                 yyaxis right;
%                                 plot(meanFRtime*1000, uFRI, 'LineStyle', '-', 'color', 'r');
%                                 MPlot.ErrorShade(meanFRtime*1000, uFRI, ciFRI(2,:), ...
%                                             ciFRI(1,:), 'color','r', 'Alpha', 0.3, 'IsRelative', false); 
%                                 ylabel('FR hz')
%                                 xlim([-ops.windows(window) ops.windows(window)]*1000);
%                                 
%                              
% 
% 
%                                 hold off
%                                 title(['sessNum = ' num2str(sessNum) ' UnitNum= ' num2str(unitNum) ' Window= ' ops.WindowNames{window} ...
%                                     ' pvalIpsi= ' num2str(pValIpsi) ' freq = ' ufreq{pstimDur}]);
%                                 saveTemp = fullfile(savePath, animalId);
%                                 if ~isfolder(saveTemp)
%                                     mkdir(saveTemp);
%                                 end
%                                 saveas(g, fullfile(saveTemp, ['sessNum = ' num2str(sessNum) ' UnitNum= ' num2str(unitNum) ' Window= ' ops.WindowNames{window} ...
%                                     ' pvalIpsi= ' num2str(pValIpsi) ' freq = ' ufreq{pstimDur} '.png']));
% 
%                                
%                             end


                            C = abs(postSpikesContra - preSpikesContra);
                            I = abs(postSpikesIpsi - preSpikesIpsi);
                           
                            Cbias = (C-I)/(C+I);
    
                            spikeTimes = {uSpikesContra, uSpikesIpsi};
                       
                           
                            unitDepth = (penetrationDepth-unitDepth)/corticalDepth;
                            
                            
                            animalTable.pvalBoth{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = pvalstimDur;
                            animalTable.bodysideTask{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = bodyside7;
                            animalTable.pvalIpsi{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = pValIpsi;
                            animalTable.pvalContra{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = pValContra;
                            spikeAnimalTable.spikeTimes{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = spikeTimes;
                           
                            animalTable.UnitDepth{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = unitDepth;
                            animalTable.adc{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = adc;
                            animalTable.cbias{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} =Cbias;
    
    
                        end                
                    catch
                        keyboard;
                    end
                  
                end 
           end

           
          
           % go to next session of the same recording site and
           % genotype
                
        end
    
       %
       toc
      
        metadataTable(animal,:) = animalTable;
       
        spikedataTable(animal,:) = spikeAnimalTable;    
       
    end
    
                      

%     clearvars -except ops allSpikeTimes maxAdc pvals plotAlpha ufreq uGenotypes inputrecSites adcFinal savePath plotLims genotype recSite recSites genotypes
% 
    keyboard;
    if ~exist(savePath, 'dir')
        mkdir(savePath);
    end

    save([savePath '\allVars.mat'], 'metadataTable', 'ops', 'dataFileTb', 'spikedataTable', '-v7.3');    
        

end

function GetFRData(dataFileTb, ops)


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
    
    uniAnimalId = unique(dataFileTb.MouseName);
    
    
    readPaths= dataFileTb.sePath;
    uGenotypes = unique(dataFileTb.Genotype);
    genotypes = dataFileTb.Genotype;
    sessDates = dataFileTb.sessionDatetime;
    subIds = dataFileTb.subId;
    bins = tWins(1):binSize:tWins(2);
    FRdataTable = cell2table(cell(numel(uniAnimalId), 1), 'RowNames', uniAnimalId, 'VariableNames', {'meanFR'});
    
    
   
    parfor animal = 1:numel(uniAnimalId)
        animalId = uniAnimalId{animal};
        FRAnimalTable = cell2table(cell(1,1), 'RowNames', {animalId}, 'VariableNames', {'meanFR'});
        
        animalReadPaths = readPaths(strcmp(uniAnimalId(animal), animalID));
        sessIDs = [datestr(sessDates(strcmp(uniAnimalId(animal), animalID)), 'yymmdd') [subIds{strcmp(uniAnimalId(animal), animalID)}]'];
         % Convert the character array to a cell array
        sessArray = cell(size(sessIDs, 1), 1);
        for i = 1:size(sessIDs, 1)
            sessArray{i} = sessIDs(i, :);
        end

        defaultWinTable = cell(numel(sessArray), numel(ops.windows));
        defaultWinTable = cell2table(defaultWinTable, "RowNames", sessArray, 'VariableNames', ops.WindowNames);
        
        
        FRAnimalTable.('meanFR'){animalId} = defaultWinTable;
       
        % (sessIDs, animalReadPaths, ops, sessArray, animalTable, animalID)
        tic
        for sessNum = 1:numel(sessArray)

            se =loadsess(animalReadPaths{sessNum});
            
            sessRecSite = cell2mat(se.userData.sessionInfo.recSite);
            sessName = sessArray{sessNum};           
                
            fprintf('%s\n\n', animalReadPaths{sessNum});
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

               
            
            stimTypes = leftStimTypes;
            uStimTypes = unique(stimTypes);
            ufreq = unique(cellfun(@(x) x(5:6),uStimTypes, 'UniformOutput', false)); % for gettign just the unique frequencies irrespective of the cycles
            if isempty(str2num(ufreq{1}))
                ufreq = unique(cellfun(@(x) x(17:18),uStimTypes, 'UniformOutput', false)); % for gettign just the unique frequencies irrespective of the cycles
                freqStart = 17;
            else
                freqStart =5;
            end
            charString = ['Cyc' num2str(ops.cyc)];
            % Define the size of the cell array
            numRows = numel(ufreq);
            numCols = 1;
            
            % Create the char cell array
            charCellArray = repmat({charString}, numRows, numCols);
            ufreq = cellfun(@(x) [x charCellArray{1}], ufreq, 'UniformOutput', false);



            unitNums = size(frAll,2)-1;
           

            unitNumArray = cell(unitNums,1);
            for unitNum = 1: unitNums
                unitNumArray{unitNum} = ['Unit' num2str(unitNum)];
            end

            stimArray = cellfun(@(x) [x 'hz'], ufreq, 'UniformOutput', false);
            
                    
            defualtStimTable = cell(unitNums, numel(ufreq));
            defualtStimTable = cell2table(defualtStimTable, "RowNames", unitNumArray, 'VariableNames', stimArray);
            
            for var2 = 1:numel(ops.windows)
                    varName2 = ops.WindowNames{var2};                  
                    FRAnimalTable.('meanFR'){animalId}{sessNum, varName2}{1} = defualtStimTable;
                    
            end

                
                   
            sessInfoTable = se.userData.sessionInfo;

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

                
                
                try
                    unitChanDepth = se.userData.spikeInfo.quality_metrics.depth;
                catch
                    
                    chanDepth = 0:20:1260; %(in um)
                    channelInds = se.userData.spikeInfo.unit_channel_ind;
                    chanMap = se.userData.sessionInfo.channel_map.chanMap;
                    [~, chanPos] = ismember(channelInds,chanMap);
                    unitChanDepth= chanDepth(chanPos);
                    
                end
                
                for window = 1:numel(ops.windows)
                    windowSize = ops.windows(window);
                    binsWin = find(bins>= -windowSize & bins<= windowSize);
                    plotLims = [-windowSize, windowSize];
                    temp = binsWin;
                    try
                        frAllwin = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                    catch                            
                        errorTrials = find(cell2mat(cellfun(@(x) numel(x)< temp(end), frAll(:,1), 'UniformOutput',false)));
                        behavData(errorTrials,:) =[];
                        frAll(errorTrials,:)=[];
                        frAllwin = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                    end

                    leftStimTypes = behavData.leftStimType;
                    rightStimTypes = behavData.rightStimType;

                   
                    
                   trials2keepL= find(strcmp(trials{1}{1}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(freqStart:freqStart+5),ufreq{stimDur}), ...
                            leftStimTypes, 'UniformOutput',false)));
                    trials2keepR = find(strcmp(trials{1}{2}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(freqStart:freqStart+5),ufreq{stimDur}), ...
                            rightStimTypes, 'UniformOutput',false)));
                    
                    


                    FRLeft  = frAllwin (trials2keepL ,2:end);
                    FRRight  = frAllwin (trials2keepR ,2:end);
                    FRtime  = frAllwin (trials2keepR ,1);
                    
                    %get p-value based on windowsize = stim duration                        
                    preWindow  = 1:(round(numel(FRLeft {1})/2));
                    postWindow  =  preWindow (end)+1: numel(FRLeft {1}); 
                    temp1 = preWindow ;
                    temp2 = postWindow ;

                    preMeanFRL  = cell2mat(cellfun(@(x) mean(x(temp1)), FRLeft , 'UniformOutput', false));
                    postMeanFRL  = cell2mat(cellfun(@(x) mean(x(temp2)), FRLeft , 'UniformOutput', false));
                    preMeanFRR  = cell2mat(cellfun(@(x) mean(x(temp1)), FRRight , 'UniformOutput', false));
                    postMeanFRR  = cell2mat(cellfun(@(x) mean(x(temp2)), FRRight , 'UniformOutput', false));
                    
                    % get spikeTimes for FRlims
                    FRlims  = [tWins(1) tWins(2)];               
                        
                    binsWin  = find(bins>= FRlims (1) & bins<= FRlims (2));
                    temp = binsWin(1:end-1);
                    
                    frAllplot  = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                    FRLeft  = frAllplot (trials2keepL ,2:end);
                    FRRight  = frAllplot (trials2keepR ,2:end);
                    FRtime  = frAllplot (:,1);        
                    
                   

                    
                    if sum(ismember('Left', sessRecSite))==4
                        stims = {trials2keepL , trials2keepR };
                    else
                        stims = {trials2keepR , trials2keepL };
                    end
                   
                    win = ops.WindowNames{window};

                    try
                        for unitNum = 1: size(preMeanFRL ,2)   
                            
                            unitDepth = unitChanDepth(unitNum);

                            
                            [pvalL] = signrank(preMeanFRL (:,unitNum), postMeanFRL (:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);
                            [pvalR] = signrank(preMeanFRR (:,unitNum), postMeanFRR (:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);
                 
                            
                        
                           meanFRtime =  mean(cell2mat(FRtime),1);
                        
                            if sum(ismember(sessRecSite, 'Left'))==4

                                uFRI = cell2mat(FRLeft(:,unitNum));
                                uFRC = cell2mat(FRRight(:,unitNum));


%                               
                            else

                                uFRI = cell2mat(FRRight(:,unitNum));
                                uFRC = cell2mat(FRLeft(:,unitNum));
%                                
                            end
                            
                          
                            meanFR = {meanFRtime, uFRC, uFRI};
                      
                          
                            
                            
                           
                            FRAnimalTable.('meanFR'){animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = meanFR;
                            
    
    
    
                        end                
                    catch
                        keyboard;
                    end
                  
                end 
           end

           
          
           % go to next session of the same recording site and
           % genotype
                
        end
    
       %
       toc
      
      FRdataTable(animal,:) = FRAnimalTable;   
       
    end
    
                      

%     clearvars -except ops allSpikeTimes maxAdc pvals plotAlpha ufreq uGenotypes inputrecSites adcFinal savePath plotLims genotype recSite recSites genotypes
% 
    keyboard;
    if ~exist(savePath, 'dir')
        mkdir(savePath);
    end

    save([savePath '\FRdataVars.mat'], 'ops', 'dataFileTb', 'FRdataTable', '-v7.3');    
        

end


function AddMeanFRData(ops, FRdataTable)
    keyboard;
    rowNames = FRdataTable.Properties.RowNames;
    variableNames = FRdataTable.Properties.VariableNames;
    meanFRTable= cell2table(cell(numel(rowNames), numel(variableNames)), 'RowNames', rowNames, 'VariableNames', variableNames);
    parfor animal = 1 : height(FRdataTable)
        
        animalFR = FRdataTable.meanFR{animal};
        meanFRTable{animal, 1}{1} = cell2table(cell(height(animalFR), 1), 'RowNames', ...
            animalFR.Properties.RowNames, 'VariableNames', animalFR.Properties.VariableNames(end));
        tic;
        for sessNum = 1: height(animalFR)
            sessFR = animalFR.('300'){sessNum};
            stimNames = sessFR.Properties.VariableNames;
            meanFRTable{animal, 1}{1}{sessNum,1}{1} = cell2table(cell(height(sessFR), width(sessFR)), 'RowNames', ...
                sessFR.Properties.RowNames, 'VariableNames', sessFR.Properties.VariableNames);

            for stim =1:width(sessFR)
                
                stimFR = sessFR.(stimNames{stim});

                
                time = cellfun(@(x) x(1), stimFR, 'UniformOutput', false);
                [contraMean, ~, ~, contraCI] = cellfun(@(x) MMath.MeanStats(x{2},1), stimFR, 'UniformOutput', false);
                [ipsiMean, ~, ~, ipsiCI] = cellfun(@(x) MMath.MeanStats(x{2},1), stimFR, 'UniformOutput', false);

                meanFRTable{animal, 1}{1}{sessNum,1}{1}.(stimNames{stim})= cellfun(@(a,b,c,d,e) ...
                    cell2table({a, {b}, c, {d},e}, 'VariableNames', {'Time', 'ContraMean', 'ContraCI', 'IpsiMean', 'IpsiCI'}), ...
                    time, contraMean, contraCI, ipsiMean, ipsiCI, 'UniformOutput', false);
            end
        end
        toc;
    end

    save(fullfile(ops.savePath, 'MeanFRTable.mat'), 'meanFRTable', '-v7.3');            
end

function IpsiresponsiveLatencies(ops, metadataTable, meanFRTable )
    keyboard;
    close all   
    ops.plotAlpha = 0.001;
    windowNames = ops.WindowNames;
    uGenotypes = unique(metadataTable.genotype);
    ipsi = cell(1,numel(windowNames));
    contra = cell(1,numel(windowNames));
    for window = 1:numel(windowNames)
        tic;
        ipsi{window} = cell(1,numel(uGenotypes));
        contra{window}  = cell(1,numel(uGenotypes));
        for genotype = 1: numel(uGenotypes)
            mouseNames = metadataTable.Properties.RowNames(strcmp(metadataTable.genotype, uGenotypes{genotype}));
          
            for mouse = 1:numel(mouseNames)
             
                pvalIpsi = metadataTable.pvalIpsi{mouseNames{mouse}};
                FRMouse = meanFRTable.meanFR{mouseNames{mouse}};
                pvalContra = metadataTable.pvalContra{mouseNames{mouse}};
                pvalAny = metadataTable.pvalBoth{mouseNames{mouse}};
                windowNames = pvalIpsi.Properties.VariableNames;
    %                 sessNames = pvalIpsi.Properties.RowNames;
               
                ipsiTemp = cell2mat(cellfun(@(x) cell2mat(table2cell(x)), pvalIpsi.(windowNames{window}), 'UniformOutput', false));
                
                contraTemp = cell2mat(cellfun(@(x) cell2mat(table2cell(x)), pvalContra.(windowNames{window}), 'UniformOutput', false));
                anyTemp = cell2mat(cellfun(@(x) cell2mat(table2cell(x)), pvalAny.(windowNames{window}), 'UniformOutput', false));
                FRWindow =  cellfun(@(x) table2cell(x), FRMouse.('300'), 'UniformOutput', false);
                FRWindow = vertcat(FRWindow{:}); 
                if size(anyTemp,2) >3
                    anyTemp = anyTemp(:,1:3);
                    ipsiTemp = ipsiTemp(:,1:3);
                    contraTemp = contraTemp(:,1:3);                  
                    FRWindow = FRWindow(:, 1:3);
                    pvalStim = 1:3;
                    
                else
                    pvalStim = 2;
                end

                         
                % finrst get pvals for units that are significant
                % in either stim sides
                sigUnits = anyTemp < ops.plotAlpha;
                sumlogic = sum(sigUnits,2);
                sigUnits = sumlogic>0;
                
                
                % find ipsi units that are significant in any freq
                
                ipsiTemp = ipsiTemp(sigUnits,:);
                contraTemp = contraTemp(sigUnits,:);
                FRWindow = FRWindow(sigUnits, :);


                sigUnits = ipsiTemp < ops.plotAlpha;
                sumlogic = sum(sigUnits,2);
                sigUnits = sumlogic>0;
                
                ipsiTemp = ipsiTemp(sigUnits,:);


                ipsiFR = FRWindow(sigUnits,:);

                sigUnits = contraTemp < ops.plotAlpha;
                sumlogic = sum(sigUnits,2);
                sigUnits = sumlogic>0;

                contraFR = FRWindow(sigUnits,:); 
                
                contra{window}{genotype}(end+1:end+height(contraFR), pvalStim) = contraFR;
                ipsi{window}{genotype}(end+1:end+height(ipsiFR), pvalStim) = ipsiFR;
                

            end

           
        end
        toc;
    end

    % plot for each window and genotype
    stimNames = pvalIpsi.(windowNames{window}){1}.Properties.VariableNames;
    stimNames = stimNames(1:3);
    for window =1: numel(windowNames)
        close all
        g = figure(1);clf;
        g.WindowState='maximized';
        
      
        for geno = 1: numel(ipsi{window})
            for stim = 1:width(ipsi{window}{geno})

                
                ipsicells = vertcat(ipsi{window}{geno}(:,stim));
                emptyCells = cell2mat(cellfun(@(x) isempty(x), ipsicells, 'UniformOutput', false));
                ipsicells(emptyCells) = [];

                ipsicells = cellfun(@(x) table2cell(x), ipsicells, 'UniformOutput', false);
                ipsicells = vertcat(ipsicells{:});    

                contracells = vertcat(contra{window}{geno}(:,stim));
                emptyCells = cell2mat(cellfun(@(x) isempty(x), contracells, 'UniformOutput', false));
                contracells(emptyCells) = [];
                contracells = cellfun(@(x) table2cell(x), contracells, 'UniformOutput', false);
                contracells = vertcat(contracells{:});   
               
                        
                
                
      
                ipsilatency= [];
                
                gg = figure(100*stim); clf;
                gg.WindowState = 'Maximized';
                rowNums = ceil(height(ipsicells)/ 15);
                for unitNum =1:height(ipsicells)

                    bins = ipsicells{unitNum,1};                
                    
                    baseline = find(bins>=-ops.windows(window) & bins<=0);
                    postWindow = find(bins>0 & bins<=ops.windows(window)); 
                    if isempty(postWindow)
                        continue;
                    end

                    winTime = find(bins>=-ops.windows(window) & bins<=ops.windows(window)); 
                    try
                        ipsiFRpost = ipsicells{unitNum,4}(postWindow);
                    catch
                        continue;
                    end
                    ipsiFRtimepost = ipsicells{unitNum,1}(postWindow);
                    ipsiFRpre = mean(ipsicells{unitNum,4}(baseline));
                    if max(ipsiFRpost)-ipsiFRpre >= ipsiFRpre- min(ipsiFRpost)
                        maxResp= max(ipsiFRpost);
                    else
                        maxResp= min(ipsiFRpost);
                    end

                    ipsifrCrossBin = find(ipsiFRpost==maxResp, 1);


%                     ipsifrCrossBin = find(ipsiFRpost< min(ipsicells{unitNum,5}(:,baseline),[], 'All')| ipsiFRpost> max(ipsicells{unitNum,5}(:,baseline),[], 'All'),1);
%                     ipsifrCrossBin = find(ipsiFRpost< mean(ipsicells{unitNum,5}(1,baseline))| ipsiFRpost> mean(ipsicells{unitNum,5}(2,baseline)),1);
                    if ~isempty(ipsifrCrossBin)
                        ipsilatency(unitNum) = ipsiFRtimepost(ipsifrCrossBin);
                    else
                        ipsilatency(unitNum) = nan;
                    end

                    h2 = subplot(rowNums, 15, unitNum);
                    hold (h2,'on');
                    plot(ipsicells{unitNum,1}(winTime), ipsicells{unitNum,4}(winTime), 'color', 'k');
                    MPlot.ErrorShade(ipsicells{unitNum,1}(winTime), ipsicells{unitNum,4}(winTime),ipsicells{unitNum,5}(2,winTime), ...
                                ipsicells{unitNum,5}(1,winTime), 'color','b', 'Alpha', 0.3, 'IsRelative', false); 
                    yLimits = ylim();
                    MPlot.PlotPointAsLine(ipsilatency(unitNum),yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '-', ...
                            'color',[1 0.5 0.5], 'linewidth', 1);
                    MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--', ...
                            'color',[0.5 0.5 0.5], 'linewidth', 1);
                    hold (h2,'off');
                
                end
                sgtitle([stimNames{stim} ' ' uGenotypes{geno} ' IpsiResponsesLatencies']);
                savefig(gg, fullfile(ops.savePath, windowNames{window}, [stimNames{stim} ' ' uGenotypes{geno} ' IpsiResponsesLatencies.fig']));
                saveas(gg, fullfile(ops.savePath, windowNames{window},[stimNames{stim} ' ' uGenotypes{geno} ' IpsiaResponsesLatencies.png']));


                gg = figure(100*stim+ 1); clf;
                gg.WindowState = 'Maximized';
                rowNums = ceil(height(contracells)/ 15);

                contralatency= [];
                contralatency2= [];
                for unitNum =1:height(contracells)
                    bins = contracells{unitNum,1};                
                    
                    baseline = find(bins>-ops.windows(window) & bins<=0);
                    postWindow = find(bins>0 & bins<ops.windows(window)); 
                    if isempty(postWindow)
                        continue;
                    end

                    try
                        contraFRpost = contracells{unitNum,4}(postWindow);
                    catch
                        continue;
                    end
                    contraFRtimepost = contracells{unitNum,1}(postWindow);

                    contraFRpre = mean(contracells{unitNum,4}(baseline));
                    
                    if max(contraFRpost)-contraFRpre >= contraFRpre- min(contraFRpost)
                        maxResp= max(contraFRpost);
                    else
                        maxResp= min(contraFRpost);
                    end

                    contrafrCrossBin = find(contraFRpost==maxResp, 1);
%                     contrafrCrossBin = find((contraFRpost< min(contracells{unitNum,5}(:,baseline),[],'All'))| ...
%                         (contraFRpost> max(contracells{unitNum,5}(:,baseline),[],'All')),1);
%                     contrafrCrossBin = find(contraFRpost< mean(contracells{unitNum,5}(1,baseline))| contraFRpost> mean(contracells{unitNum,5}(2,baseline)),1);
                    if ~isempty(contrafrCrossBin)
                        contralatency(unitNum) = contraFRtimepost(contrafrCrossBin);
                    else
                        contralatency(unitNum) = nan;
                    end

                    h2 = subplot(rowNums, 15, unitNum);
                    hold (h2,'on');
                    plot(contracells{unitNum,1}(winTime), contracells{unitNum,4}(winTime), 'color', 'k');
                    MPlot.ErrorShade(contracells{unitNum,1}(winTime), contracells{unitNum,4}(winTime),contracells{unitNum,5}(2,winTime), ...
                                contracells{unitNum,5}(1,winTime), 'color','r', 'Alpha', 0.3, 'IsRelative', false); 
                    yLimits = ylim();
                   MPlot.PlotPointAsLine(contralatency(unitNum),yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '-', ...
                            'color',[0.5 0.5 1], 'linewidth', 1);
                    MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--', ...
                            'color',[0.5 0.5 0.5], 'linewidth', 1);
                    hold (h2,'off');
                end
                sgtitle([stimNames{stim} ' ' uGenotypes{geno} ' ContraResponsesLatencies']);
                savefig(gg, fullfile(ops.savePath, windowNames{window}, [stimNames{stim} ' ' uGenotypes{geno} ' ContraResponsesLatencies.fig']));
                saveas(gg, fullfile(ops.savePath, windowNames{window},[stimNames{stim} ' ' uGenotypes{geno} ' ContraResponsesLatencies.png']));



                contralatency(isnan(contralatency)) = [];
                ipsilatency(isnan(ipsilatency)) = [];
    
                contracolors = {[0.7 0 0]; [1 0 0]};
                ipsicolors = {[0 0 0.7]; [0 0 1]};
                c = figure(1);
                
                h1 = subplot(3,1,stim);
                hold(h1, 'on')
                edges = [0:ops.binWidth:ops.windows(window)]*1000;
                [counts, ~] = histcounts(contralatency*1000, edges);
                % Calculate cumulative sum of counts and then divide by the total number of observations
                cumulativeCounts = cumsum(counts);
                cumulativeProbabilities = cumulativeCounts / length(contralatency);
                stairs(edges(1:end-1), cumulativeProbabilities, 'LineWidth', 3, 'color', contracolors{geno});

                [counts, ~] = histcounts(ipsilatency*1000, edges);
                % Calculate cumulative sum of counts and then divide by the total number of observations
                cumulativeCounts = cumsum(counts);
                cumulativeProbabilities = cumulativeCounts / length(ipsilatency);
                stairs(edges(1:end-1), cumulativeProbabilities, 'LineWidth', 3, 'color', ipsicolors{geno});
                
                if geno==2
                    title(stimNames{stim})
                    legend({'KO Contra', 'KO Ipsi', 'WT Contra', 'WT Ipsi'}, 'Location', 'Northwest')
                    xlabel('Time(ms)')
                    ylabel('CDF of responsive units')
                    
                end
                
               
        
            end
        end
        
        savefig(g, fullfile(ops.savePath, windowNames{window}, [' ContraIpsiresponsiveLatenciesCDFs.fig']));
        saveas(g, fullfile(ops.savePath, windowNames{window},[' ContraIpsiresponsiveLatenciesCDFs.png']));
    


    end



               
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

function MakeCbiasFigures(ops, binWidth, figureRoot, metadataTable)
    close all   
    
    % just signify according to allpvals
    

    cbiasTable = metadataTable.cbias;
    pvalTable = metadataTable.pvalBoth;
    animalIds = unique(metadataTable.Properties.RowNames);
    genotypes = metadataTable.genotype;
    uGenotype = unique(genotypes);
    windows = ops.WindowNames;
    stimNames ={'10hz', '20hz', '40hz'};
    for win = 1: numel(ops.windows)

        savePath = fullfile(ops.savePath, ops.WindowNames{win});

        if ~isfolder(savePath)
            mkdir(savePath);
        end

        cbiasFinal = cell(2,3);
        sessCbiasFinal = cell(2,3);
        for geno = 1:numel(uGenotype)
            animals= find(ismember(genotypes, uGenotype(geno)));
            CbiasGeno = cbiasTable(animals);
            pvalGeno = pvalTable(animals);
            
            for ani = 1: numel(CbiasGeno) 
                aniGeno = CbiasGeno{ani};
                anipval = pvalGeno{ani};
                for sessNum = 1: height(aniGeno)
                    pvalsess = cell2mat(table2cell(anipval.(ops.WindowNames{win}){sessNum}));
                    cbiasSess = aniGeno.(ops.WindowNames{win}){sessNum};
                    if width(pvalsess) >3

                        pvalsess = pvalsess(:,1:3);
                        pstimDur = 1:3;
                        cbiasSess = cbiasSess(:,1:3);
                    else
                        pstimDur =2;
                    end
                    sumlogics = sum(pvalsess < ops.plotAlpha,2);
                    sigUnits = find(sumlogics>0);
                    cbiasSess = cell2mat(table2cell(cbiasSess(sigUnits,:)));
                    if ~isempty(cbiasSess)
                       for stim = 1:width(cbiasSess)
                            indx = numel(cbiasFinal{geno,pstimDur(stim)});
                            cbiasFinal{geno,pstimDur(stim)}(indx+1:indx+height(cbiasSess)) = cbiasSess(:,stim);
                            sessCbiasFinal{geno, pstimDur(stim)}(end+1,1:2) = [numel(find(cbiasSess(:,stim)>0)),  numel(find(cbiasSess(:,stim)<=0))];
                            
                       end
                            
                
                    end
                        
                end

            end
        end
        


        % Plot using these cbiasFinal and sessbiasfinals using figure 3
        % plotting scheme
        bins = -1:binWidth:1;
        colorStock = {[0 0 0 ]; [0.6 0.6 0.6]};
        close all
        maxunits =0;
        for stim = 1:width(cbiasFinal)
            g(3*stim-2) = figure(3*stim-2); clf;
            set( g(3*stim-2), 'Units', 'inch', 'Position', [1 1 3.5 3.5])
            g(3*stim-1) = figure(3*stim-1); clf;
            set( g(3*stim-1), 'Units', 'inch', 'Position', [1 1 3.5 5])
            g(3*stim) = figure(3*stim); clf;
            set( g(3*stim), 'Units', 'inch', 'Position', [1 1 3.5 5])
                        
            
         

            for geno= height(cbiasFinal):-1:1
                genoNum = height(cbiasFinal)-geno;
                figure(3*stim-2);           
                hold on
                s(geno) = swarmchart(sessCbiasFinal{geno,stim}(:,1)+0.3-0.2*geno, sessCbiasFinal{geno,stim}(:,2)+ 0.3-0.2*geno...
                    ,20,'marker', 'x', 'markeredgecolor', colorStock{geno}, 'YJitterWidth', 0.5, 'LineWidth',1.5);
                hold off



                figure(3*stim-1);
                hh2 = subplot(2,1,genoNum+1);       
                h2 = histogram(cbiasFinal{geno,stim}, bins, 'facecolor', colorStock{geno}); 
                set(hh2,  'fontsize', 14);
                hh2.LineWidth = 2;
                xticks(-1:0.25:1)
                title(uGenotype{geno})
                xlabel('(C-I)/(C+I)');
                ylabel('#of units');

                figure(3*stim);
                hh1 = subplot(2,1,genoNum+1);
                h1 = histogram(cbiasFinal{geno,stim}, bins, 'facecolor', colorStock{geno}, 'Normalization','probability');                       
                title(uGenotype{geno})
                xticks(-1:0.25:1)
                set(hh1,  'fontsize', 14);
                hh1.LineWidth = 2;
                xlabel('(C-I)/(C+I)');
                ylabel('probability');

                if max(sessCbiasFinal{geno,stim},[],"all")> maxunits
                    maxunits = max(sessCbiasFinal{geno,stim},[],"all");
                end
            end
            figure(3*stim);
            sgtitle([ stimNames{stim}]);

            figure(3*stim-1);
            sgtitle([ stimNames{stim}]);
    
            figure(3*stim-2);
%             maxunits = min(8, maxunits);
            hold on
            
            plot(-1:maxunits+1,-1:maxunits+1, 'k-.')
            legend(s, {'KO','WT'}, 'Fontsize', 14);
            xlabel('Contra units in a session', 'Fontsize', 14);
            ylabel('Ipsi units in a session', 'Fontsize', 14);
%             xticks(0:2:8);
%             xticklabels([])
%             yticks(0:2:8);
%             yticklabels([])
            xlim([-1,(maxunits+1)])
            ylim([-1,maxunits+1])
            title(stimNames{stim});
            hold off


            savefig(figure(3*stim-2), fullfile(savePath, ['Stim ' stimNames{stim} 'SessPlot.fig']));
            saveas(figure(3*stim-2), fullfile(savePath, ['Stim ' stimNames{stim} 'SessPlot.png']));
            savefig(figure(3*stim-1), fullfile(savePath, ['Stim ' stimNames{stim} 'Histogram units.fig']));
            saveas(figure(3*stim-1), fullfile(savePath, ['Stim ' stimNames{stim} 'Histogram units.png']));
            savefig(figure(3*stim), fullfile(savePath, ['Stim ' stimNames{stim} 'Histogram probability.fig']));
            saveas(figure(3*stim), fullfile(savePath, ['Stim ' stimNames{stim} 'Histogram probability.png']));


        end




    end



        
end

function CBiasDepthHisto(ops, metadataTable)
    
    close all   
     % L1, 128 ± 1 μm; L2, 269 ± 2 μm; L3, 418 ± 3 μm; L4, 588 ± 3 μm; L5A, 708 ± 4 μm; L5B, 890 ± 5 μm; L6, 1154 ± 7 μm.
    % just signify according to allpvals
    depthTable = metadataTable.UnitDepth;
    cbiasTable = metadataTable.cbias;
    pvalTable = metadataTable.pvalBoth;
    animalIds = unique(metadataTable.Properties.RowNames);
    genotypes = metadataTable.genotype;
    uGenotype = unique(genotypes);
    windows = ops.WindowNames;
    stimNames ={'10hz', '20hz', '40hz'};
    
    for win = 1: numel(ops.windows)

        savePath = fullfile(ops.savePath, ops.WindowNames{win});

        if ~isfolder(savePath)
            mkdir(savePath);
        end

        cbiasFinal = cell(2,3);
        depthFinal = cell(2,3);
        for geno = 1:numel(uGenotype)
            animals= find(ismember(genotypes, uGenotype(geno)));
            CbiasGeno = cbiasTable(animals);
            pvalGeno = pvalTable(animals);
            depthGeno = depthTable(animals);

            for ani = 1: numel(CbiasGeno) 
                aniGeno = CbiasGeno{ani};
                anipval = pvalGeno{ani};
                aniDepth = depthGeno{ani};
                for sessNum = 1: height(aniGeno)
                    pvalsess = cell2mat(table2cell(anipval.(ops.WindowNames{win}){sessNum}));
                    cbiasSess = aniGeno.(ops.WindowNames{win}){sessNum};
                    depthSess = aniDepth.(ops.WindowNames{win}){sessNum};
                    if width(pvalsess) >3

                        pvalsess = pvalsess(:,1:3);
                        pstimDur = 1:3;
                        cbiasSess = cbiasSess(:,1:3);
                    else
                        pstimDur =2;
                    end
                    sumlogics = sum(pvalsess < ops.plotAlpha,2);
                    sigUnits = find(sumlogics>0);
                    cbiasSess = cell2mat(table2cell(cbiasSess(sigUnits,:)));
                    depthSess = cell2mat(table2cell(depthSess(sigUnits,:)));
                    if ~isempty(cbiasSess)
                       for stim = 1:width(cbiasSess)
                            indx = numel(cbiasFinal{geno,pstimDur(stim)});
                            cbiasFinal{geno,pstimDur(stim)}(indx+1:indx+height(cbiasSess)) = cbiasSess(:,stim);
                            depthFinal{geno,pstimDur(stim)}(indx+1:indx+height(depthSess)) = depthSess(:,stim);
                            
                       end
                            
                
                    end
                        
                end

            end
        end
        

    %  L1, 128 ± 1 μm; L2, 269 ± 2 μm; L3, 418 ± 3 μm; L4, 588 ± 3 μm; L5A, 708 ± 4 μm; L5B, 890 ± 5 μm; L6, 1154 ± 7 μm.

        
       for stim =1:numel(stimNames)
            g = figure(stim); clf;
            g.WindowState = 'Maximized';
            hold on
            for genotype =1:height(depthFinal)
                ax = subplot(1, height(depthFinal),genotype);
               
                data = [cbiasFinal{genotype,stim}', depthFinal{genotype,stim}'];
    
%                 lowerBounds = [(max(data(:,2))-min(data(:,2)))/2,max(data(:,2))];
%                 upperBounds = [min(data(:,2)),(max(data(:,2))-min(data(:,2)))/2];
                lowerBounds = [418/1154,588/1154,max(data(:,2))];
                upperBounds = [min(data(:,2)),418/1154,588/1154];

                binEdgesY = upperBounds + (lowerBounds-upperBounds)/2
%                 binEdgesX = -1:binWidth:1;
                lowerBounds = [-1,-0.33,0.33];
                upperBounds =[-0.33,0.33,1];
                binEdgesX = upperBounds + (lowerBounds-upperBounds)/2
                
                hist3(data, ...
                    {binEdgesX,binEdgesY}, 'CdataMode','auto');
                

                 
             
              
                set(gca, 'FontSize', 24);
               

                title([uGenotype{genotype} ' ' stimNames{stim}], 'FontSize', 36);
                yticks(binEdgesY)
                yticklabels({'Superficial', 'L4', 'Deep'});
                ylim([min(data(:,2)),max(data(:,2))]);
                zlim([0,80]);
                zticks([0:10:80]);
                if genotype ==1
                  
                    
                    ylabel('Cortical layers','VerticalAlignment','baseline', 'FontSize', 36);
                    zlabel('Number of Units', 'FontSize', 36);
                end
                xlabel('Contra Bias','VerticalAlignment','baseline',  'FontSize', 36);
          
                h = colorbar;               
                tt = get(h, 'Position');
                set(h, 'Position', [tt(1)+0.05, tt(2)+0.1, tt(3), tt(4)-0.2]); % Adjust the position and size as needed
             


                
            end
            
            hold off
            savefig(g,fullfile(savePath,  [stimNames{stim} ' depth cbias histogram.fig']));
            saveas(g,fullfile(savePath,  [stimNames{stim} ' depth cbias histogram.png']));
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

function PlotAvgTracesFR(dataFileTb, ops, metadataTable, FRdataTable, window)
    genotypes = metadataTable.genotype;
    
    uGenotypes = unique(genotypes);
    close all;

   
   
    
    czData = cell(1,3);
    izData = cell(1,3); 
    colors = {[100/255 0 0];  [0 0 100/255]; [1 0 0] ; [0 0 1]};
    g = figure(1); clf;
    g.WindowState = 'Maximized';

    for stim = 1:3
        if ~iscell(czData{stim})
            czData{stim} = cell(1,2);
            izData{stim} = cell(1,2);
        end
        for geno = 1:numel(uGenotypes)
            czData{stim}{geno} = [];
            izData{stim}{geno} = [];
            mouseNames = find(strcmp(uGenotypes(geno), genotypes));
            for ani = 1:numel(mouseNames)

                animalZ = FRdataTable{mouseNames(ani), 'meanFR'}{1}.(window);
%                     pvalIpsi = metadataTable{mouseNames(ani), 'pvalIpsi'}{1}.(window);
%                     pvalContra = metadataTable{mouseNames(ani), 'pvalContra'}{1}.(window);
                pvalAny = metadataTable{mouseNames(ani), 'pvalBoth'}{1}.(window);
                
                if stim > width(pvalAny{1})
                    continue;
                end
                for sessNum = 1:height(animalZ)

                    if width(pvalAny{sessNum})>3

                        pvalTemp = cell2mat(table2cell(pvalAny{sessNum}(:,1:3)));
                        pstimDur = stim;
                    else
                        pvalTemp = cell2mat(table2cell(pvalAny{sessNum}));
                        pstimDur = stim+1;
                    end
                    pvalTemp = pvalTemp< ops.plotAlpha;
                    sumLogics = sum(pvalTemp,2);
                    sigUnits = sumLogics>0;
                    
                    temp = table2cell(animalZ{sessNum}(:,stim));
                    temp = vertcat(temp{:});
                    time = temp{1,1};

                    

                  

                    cTemp = cell2mat(temp(sigUnits,2));
                    iTemp = cell2mat(temp(sigUnits,3));
                    if ~iscell(czData{pstimDur})
                        czData{pstimDur} = cell(1,2);
                        izData{pstimDur} = cell(1,2);
                    end
                    startc = height(czData{pstimDur}{geno});
                    starti = height(izData{pstimDur}{geno});
                    czData{pstimDur}{geno}(startc+1:startc+height(cTemp),:) = cTemp;
                    izData{pstimDur}{geno}(starti+1:starti+height(iTemp),:) = iTemp;
                end


            end
       
            [meanContra, ~, ~, ciContra] = MMath.MeanStats(czData{stim}{geno},1);
            [meanIpsi, ~, ~, ciIpsi] = MMath.MeanStats(izData{stim}{geno},1);
            if strcmp('KO', uGenotypes{geno})
                h =subplot(3,4,stim*4);  
                hold(h,'on')
                plot(time, meanContra, 'color', colors{geno*2-1}, 'LineWidth', 1);
                plot(time, meanIpsi, 'color', colors{geno*2}, 'LineWidth', 1);
                MPlot.ErrorShade(time, meanContra, ciContra(2,:), ...
                                ciContra(1,:), 'color',colors{geno*2-1}, 'Alpha', 0.3, 'IsRelative', false); 
                MPlot.ErrorShade(time, meanIpsi, ciIpsi(2,:), ...
                                ciIpsi(1,:), 'color',colors{geno*2}, 'Alpha', 0.3, 'IsRelative', false); 
%                 ylim([0, 10]);       
                yLimits = get(gca,'YLim');
                MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
                xlabel('epoch time (s)');
                ylabel('FR hz');  
                title([uGenotypes{geno} ' Contra vs Ipsi']);
                legend({'Contra', 'Ipsi'});
                
                hold(h, 'off');
            else
                h =subplot(3,4,stim*4-3);  
                hold(h,'on')
                plot(time, meanContra, 'color', colors{geno*2-1}, 'LineWidth', 1);
                plot(time, meanIpsi, 'color', colors{geno*2}, 'LineWidth', 1);
                MPlot.ErrorShade(time, meanContra, ciContra(2,:), ...
                                ciContra(1,:), 'color',colors{geno*2-1}, 'Alpha', 0.3, 'IsRelative', false); 
                MPlot.ErrorShade(time, meanIpsi, ciIpsi(2,:), ...
                                ciIpsi(1,:), 'color',colors{geno*2}, 'Alpha', 0.3, 'IsRelative', false); 
%                 ylim([0, 10]);       
                yLimits = get(gca,'YLim');
                MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
                xlabel('epoch time (s)');
                
                ylabel('FR hz');  
                title([uGenotypes{geno} ' Contra vs Ipsi']);
                legend({'Contra', 'Ipsi'});
                
                hold(h, 'off');

            end

            h =subplot(3,4,stim*4-2);  
            hold(h,'on')
            k(geno)=plot(time, meanContra, 'color', colors{geno*2-1}, 'LineWidth', 1);
           
            MPlot.ErrorShade(time, meanContra, ciContra(2,:), ...
                            ciContra(1,:), 'color',colors{geno*2-1}, 'Alpha', 0.3, 'IsRelative', false); 
           
            if strcmp('WT', uGenotypes{geno})    
%                 ylim([0, 10]);
                yLimits = get(gca,'YLim');
                MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
                xlabel('epoch time (s)');
                ylabel('FR hz');  
               
                title(['Contra KO vs WT']);
                legend(k, {'KO', 'WT'});
                
            end
            hold(h, 'off');

            h =subplot(3,4,stim*4-1);  
            hold(h,'on')
            l(geno)=plot(time, meanIpsi, 'color', colors{geno*2}, 'LineWidth', 1);
           
            MPlot.ErrorShade(time, meanIpsi, ciIpsi(2,:), ...
                            ciIpsi(1,:), 'color', colors{geno*2}, 'Alpha', 0.3, 'IsRelative', false); 
           
            if strcmp('WT', uGenotypes{geno})    
%                 ylim([0, 10]);
                yLimits = get(gca,'YLim');
                MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
                xlabel('epoch time (s)');
                
                ylabel('FR hz');  
                title(['Ipsi KO vs WT']);
                legend(l, {'KO', 'WT'});
                
            end
            hold(h, 'off');
        end




    end

    savefig(g,fullfile(ops.savePath, ['Average FR figures window ' window ' ms.fig']));
    saveas(g, fullfile(ops.savePath, ['Average FR figures window ' window ' ms.png']));
  
   
end



