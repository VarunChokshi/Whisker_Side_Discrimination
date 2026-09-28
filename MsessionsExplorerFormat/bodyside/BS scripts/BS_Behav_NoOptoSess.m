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

%% Plot all sessions

saveFig = fullfile('G:\VC03_RoboKO\VC0301\Figures\SessFigs\NoOptoFinalBehavSEs');
BS.PlotSession(dataFileTb.sePath, saveFig);

%% Update SessInfos
BS.ReUpdateSessInfo(dataFileTb);


%% Add stim as 3 columns freq, duration, amp, masking flash, PreStimNoLickTime, fracCorrect, fracMiss
% for i =1:1
for i =1:height(dataFileTb)
    load(dataFileTb.sePath{i})
    perf = struct2table(getPerfOverall(se));
    dataFileTb(i,perf.Properties.VariableNames) = perf;
end
%% 
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


savePath=(fullfile(figureFolder,'NoInhibitionAllAnimalsBodyside6', 'ContraIpsi'));
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
        tt = fieldnames(se.userData.bctData);
%          if ~strcmp(tt{1}(1:9), 'bodyside6')
%             continue;
%          end


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


%Remove _NoCue from TrialTypes

trialTypes= photoInhAll.trialType;
parfor i =1:height(trialTypes)
    if sum(ismember(trialTypes{i}, '_NoCue'))>8
        trialTypes{i} = trialTypes{i}(1:end-6);
%         disp(num2str(sum(ismember(trialTypes{i}, '_NoCue'))));
%         disp(trialTypes{i});
    else
        disp(num2str(sum(ismember(trialTypes{i}, '_NoCue'))));
        disp(trialTypes{i});
    end
end

photoInhAll.trialType = trialTypes;
Genotypes = unique(photoInhAll.Genotype); 

trialTypes= unique(photoInhAll.trialType); % left, left_opto, right, right_opto

if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
    % find optoTrialtypes and remove those sessions
    trialsrem = find(cell2mat(cellfun(@(x) any(ismember(x,'p')), photoInhAll.trialType, 'UniformOutput',false)));
    photoInhAll(trialsrem,:) = [];
    trialTypes= unique(photoInhAll.trialType); % left, left_opto, right, right_opto
end 
leftStimWT = unique(photoInhAll(ismember(photoInhAll.Genotype,{'WT'}),'leftStimType'));
leftStimKO = unique(photoInhAll(ismember(photoInhAll.Genotype,{'KO'}),'leftStimType'));
rightStimWT = unique(photoInhAll(ismember(photoInhAll.Genotype,{'WT'}),'rightStimType'));
rightStimKO = unique(photoInhAll(ismember(photoInhAll.Genotype,{'KO'}),'rightStimType'));

if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
    % find optoTrialtypes and remove those sessions

    trials = find(cell2mat(cellfun(@(x) any(ismember(x,'p')), photoInhAll.trialType, 'UniformOutput',false)));
    photoInhAll(trials,:) = [];


else
    trialTypes = trials{1};
end 

nboot = 10000; % number for bootstrapping
fracMiss = cell(length(Genotypes), nboot);
fracCorrect = cell(length(Genotypes), nboot);
miss_mouse = cell(length(Genotypes), nboot);
miss_session =cell(length(Genotypes), nboot);
miss_prob = cell(nboot);

correct_mouse = cell(length(Genotypes), nboot);
correct_session =cell(length(Genotypes), nboot);
correct_prob = cell(nboot);
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
                    trialInds = find(strcmp(trialTypes{trialType}, behavData.trialType));
                    fracCorrect{g,n}{mouse}{session}(trialType) = mean(behavData.result(trialInds)); % lick probability of each trial type              
                    
                end

                miss_session{g,n}{mouse}(session,1:2) = [fracMiss{g,n}{mouse}{session}(1),...
                    fracMiss{g,n}{mouse}{session}(2)]; % left, Right
                correct_session{g,n}{mouse}(session,1:2) = [fracCorrect{g,n}{mouse}{session}(1),...
                    fracCorrect{g,n}{mouse}{session}(2)]; % left, Right
               
%                     clear fracCorrect v trialInds
            end
            
            miss_mouse{g,n}(mouse,1:2) = mean(miss_session{g,n}{mouse},1); % average across sessions
            correct_mouse{g,n}(mouse,1:2) = mean(correct_session{g,n}{mouse},1); % average across sessions
%                 clear delta_session
        end
        miss_prob{n}(1:2) = mean(miss_mouse{g,n},1); % average across mice
        correct_prob{n}(1:2) = mean(correct_mouse{g,n},1); % average across mice
%             clear delta_mouse
    end
    
    photoInh_bootstrapped{(g),1} = Genotype;  
    photoInh_bootstrapped{(g),2} = cell2mat(correct_prob);
    photoInh_bootstrapped{(g),5} = cell2mat(miss_prob);
%         clear delta_prob
    
end
toc



% plot miss fraction
KOIDs = {'VC030207', 'VC030208', 'VC030209'};
WTIDs = {'VC030109','VC030110', 'VC030112'};
alpha = 0.05;
clearvars meanStats SEM ts ciStats
for factor=[2,5]
    for rows = 1:height(photoInh_bootstrapped)
        meanStats{rows} = mean(photoInh_bootstrapped{rows,factor},1);
        try
            SEM(1:2) = std(photoInh_bootstrapped{rows,factor},0,1)/sqrt(height(photoInh_bootstrapped{rows,factor})); 
            ts = tinv([alpha/2 1-alpha/2], height(photoInh_bootstrapped{rows,factor})-1);
            ciStats{rows}{1} = meanStats{rows}(1) + ts*SEM(1);
            ciStats{rows}{2} = meanStats{rows}(2) + ts*SEM(2);
        catch
            ciStats{rows}{1} =0;
            ciStats{rows}{2} = 0;
        end
        
    end

photoInh_bootstrapped(:,factor+1) = meanStats';
photoInh_bootstrapped(:,factor+2) = ciStats';
end
photoInhBootstrapped = table();
vars = {'Genotype', 'FracCorrect', 'Mean_correct', 'CI_correct', 'FracMiss', 'Mean_miss', 'CI_miss',};
photoInhBootstrapped = cell2table(photoInh_bootstrapped,'VariableNames', vars);


%%

% colors_tt = {[0.5 0.5 0.5] [1 0 1];[0 1 1] [0.5 0.5 0.5]}; 
% colors_tt = {[0 1 1] [1 0 1]; [0 1 1] [1 0 1]}; 
colors_tt = {[1 0 0] [0 0 1]}; 
close all;
for factor =[2,5]
    if factor==2
        filename = ['All animals Bootstrapping KO vs WT optoInhibition swarm_correct'];
        yname = 'Correct ';
        ylims = [0 1];
    elseif factor==5
        filename = ['All animals Bootstrapping KO vs WT optoInhibition swarm_miss'];
        yname = 'Miss ';
        ylims = [0 0.5];
    end
    g1 = figure(100+factor);clf
    for g=1:numel(Genotypes)
        subplot(1,numel(Genotypes),g)
        hold on
        
        delta_bootstrapped_g = photoInh_bootstrapped{g,factor};
       
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
        ylim(ylims);
    %     yline(0, '--k');
        ylabel([yname 'Fraction without inhibition'])
    %     xtickangle(45);
        xlim([0,3]);
        xticks([1 2])
        xticklabels({'Left stim', 'Right Stim'})
        title(Genotypes{g});
        savefig(g1,fullfile(savePath,[filename '.fig']));
        exportgraphics(g1,fullfile(savePath, [filename '.png']));
    end
    
    g2=figure(200+factor);clf
    for g=1:numel(Genotypes)
        subplot(1,2,numel(Genotypes)-g+1)
        hold on
        
        
        delta_bootstrapped_g = photoInh_bootstrapped{g,factor};
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
        ylim(ylims);
        ylabel([yname 'Fraction without inhibition'])
    %     yline(0, '--k');
    %     xtickangle(45);
        xlim([0,3]);
        xticks([1 2])
        xticklabels({'Left stim', 'Right Stim'})
        title(Genotypes{g});
        savefig(g2,fullfile(savePath, [filename '.fig']));
        exportgraphics(g2,fullfile(savePath, [filename '.png']));
    end
end

%% Helper functions


function perf = getPerfOverall(se)
    % perf = [correctFrac, incorrectFrac, missFrac, leftStimAmp, leftDur, leftStimFreq,  ...
    % rightStimFreq, rightStimAmp, rightStimDur, sideAssist, leftStimProb, maskingFlash, PSNLT]
    behavData = se.GetTable('behavValue');
    stimRight = behavData.rightStimType{end};
    stimLeft = behavData.leftStimType{end};
    
    responses = cell2mat(behavData.response);
    % remove abort trials
    abortTrials = responses ==3;
    behavData(abortTrials,:) = [];

   
    
    
    
     %remove catch trials
    result = behavData.result;
    responses = cell2mat(behavData.response);
    catchTrials = isnan(result) & responses~=0;
    behavData(catchTrials,:) = [];

    % remove optoTrials
    tt = fieldnames(se.userData.bctData);
    perf.taskName = tt{1}(1:9);

    if strcmp(perf.taskName, 'bodyside6')
        trialType = behavData.trialType;
        isOpto = cell2mat(cellfun(@(x) sum(ismember(x,'Opto'))>=4, trialType, 'UniformOutput', false));
        behavData(isOpto,:) = [];
    end
    
    %separate miss trials
    responses = cell2mat(behavData.response);
    missTrials = find(responses==0);
    
    missData = behavData(missTrials, :);
    behavData(missTrials,:) = [];

    result = behavData.result;
    
    
    correctTrials = find(result);
    try
        incorrectTrials = find(~result);
    catch
        keyboard;
    end 

    missTrials = find(~cell2mat(missData.response));

    perf.correctFrac = height(correctTrials)/(height(correctTrials)+height(incorrectTrials));
    perf.incorrectFrac = height(incorrectTrials)/(height(correctTrials)+height(incorrectTrials));
    
  
    perf.missFrac = height(missTrials)/(height(missTrials)+height(correctTrials)+height(incorrectTrials));
    
    perf.rightStim = cellstr(stimRight);

    if sum(ismember(stimRight, 'Cyc'))>2
        [perf.stimRightFreq, perf.stimRightDur, perf.stimRightAmp] = bodyside5Stims(stimRight);
        [perf.stimLeftFreq, perf.stimLeftDur, perf.stimLeftAmp] = bodyside5Stims(stimLeft);
    else
        [perf.stimRightFreq, perf.stimRightDur, perf.stimRightAmp] = bodyside6Stims(stimRight);
        [perf.stimLeftFreq, perf.stimLeftDur, perf.stimLeftAmp] = bodyside6Stims(stimLeft);
    end
    perf.leftStim = cellstr(stimLeft);

    
    perf.sideAssist =  ~strcmp(se.userData.bctData.TrialTypeSection_SideAssist, 'No');
    
   
    if isfield(se.userData.bctData, 'TrialTypeSection_MaskingFlash')
        perf.maskingFlash = se.userData.bctData.TrialTypeSection_MaskingFlash;
    else
        perf.maskingFlash = 0;
    end

    if isfield(se.userData.bctData, 'TrialTypeSection_PreStimNoLickTime')
        perf.PSNLT = se.userData.bctData.TrialTypeSection_PreStimNoLickTime;
    else
        perf.PSNLT = 0.01;
    end
    perf.leftStimProb = se.userData.bctData.TrialTypeSection_LeftTrialProb;
    


end

function [freq, dur, amp] = bodyside5Stims(stim)

    qPos = find(ismember(stim, 'q'));
    freq = str2num(stim(qPos+1:qPos+2));

    dur = str2num(stim(end))*1000/freq; % ms
    
    mpos = find(ismember(stim, 'm'));
    amp = str2num(stim(mpos+4:mpos+6));
    if amp==0
        amp = 1000;
    end

end

function [freq, dur, amp] = bodyside6Stims(stim)

    qPos = find(ismember(stim, 'q'));
    freq = str2num(stim(qPos+1:qPos+2));

    dur = str2num(stim(end-2:end));    
    if dur == 0
        dur = 1000; %ms
    end

    mpos = find(ismember(stim, 'm'));
    amp = str2num(stim(mpos+4:mpos+6));
    if amp==0
        amp = 1000;
    end

end