%% Select and check master files
clear all
masterPaths = MBrowse.Files([], 'Select master files', {'.mat'});
masterTb = table();
manipulation =0;
for i = length(masterPaths) : -1 : 1
    disp(masterPaths{i});
    masterObj = matfile(masterPaths{i});
    [~, masterName] = fileparts(masterPaths{i});
    varList = who('-file', masterPaths{i});
    
    masterTb.masterObj{i} = masterObj;
    masterTb.masterName{i} = masterName;
    masterTb.hasBehav(i) = ismember('bct_data', varList);
    masterTb.hasIntan(i) = ismember('intan_data', varList);
    masterTb.hasNiDaq(i) = ismember('nidaq_data', varList);
    masterTb.hasSpike(i) = ismember('spike_data', varList);    
end

disp(masterTb);


%% Construct MSessionExplorers

% Choose to create new SEs or to update existing ones 
answer = questdlg('What to do?', 'MSessionExplorer', ...
	'Create', 'Update', 'Cancel', 'Cancel');

switch answer
    case 'Create'
        seDir = MBrowse.Folder([], 'Select a directory to save SEs');
        sePaths = cell(size(masterPaths));
    case 'Update'
        sePaths = MBrowse.Files([], 'Select SEs to update');
        seDir = fileparts(sePaths{1});        
    otherwise
        return;
end


% Loop through master files
seArray = cell(size(masterPaths));


for i = 1 : numel(masterPaths)
    
    masterObj = masterTb.masterObj{i};
    fprintf('%s\n\n', masterTb.masterName{i});    
  
    
    % Construct SE
    if exist(sePaths{i}, 'file')
        load(sePaths{i});        
    else        
        se = MSessionExplorer();      
    end
    

    % Add sessionInfo to se
    se.userData.sessionInfo = masterObj.seshInfo;
    seshInfo = masterObj.seshInfo;
    % Creat session Information 
    % Load Intan data

    if masterTb.hasNiDaq(i)
        fprintf('Loading intan data\n');
        intanData = masterObj.nidaq_data;
        intanData.amplifier_data =[];
        sampleRate = intanData.info.sample_rate;
    elseif masterTb.hasIntan(i)
        fprintf('Loading intan data\n');
        intanData = masterObj.intan_data;
        sampleRate = intanData.info.frequency_parameters.amplifier_sample_rate;
    end

    if masterTb.hasIntan(i) || masterTb.hasNiDaq(i)
        
        %Add sessionInfo
%         se.userData.sessionInfo.channel_map = load([se.userData.sessionInfo.ksDir,'\chanMap.mat']);         
        
        % Process delimiter (Dig channel)
        disp('Process delimiter');
        delimiterData = BS.BitCode.ComputeBitCode(intanData.dig_in_data(:,1), sampleRate); %Should use intanData.info to provide sample rate (30000Hz)
        se.userData.intanInfo.trialStartTime = delimiterData.HexDecOnsetTime;
        se.userData.intanInfo.trialNums = delimiterData.trialNums;
        fprintf('\n');    

        

        % Process ADC signals
        if ~isempty(intanData.adc_data) && ~ismember('adc', se.tableNames)
            disp('Processing ADC signals');
            BS.Preprocess.ADC2SE(intanData,se, masterTb.hasNiDaq(i));
            fprintf('\n');
        end
    
        % Process LFP signals
        if ~isempty(intanData.amplifier_data) && ~ismember('LFP', se.tableNames)
            disp('Processing LFP signals');
            BS.Preprocess.LFP2SE(intanData, se, 'ks');
            fprintf('\n');
        end
    end

    % Load and process spike data
    if masterTb.hasSpike(i) && ~ismember('spikeTime', se.tableNames)
        disp('Loading spike data');
        spikeData = masterObj.spike_data;
        disp('Processing spike data');
        BS.Preprocess.Spike2SE(spikeData, se);
        fprintf('\n');
    end
    
    % Load Bcontrol data amd creat a trial type map     
    disp('Processing Bcontrol data');
     if ~isempty('seshInfo.inhSite')
        
         BS.Preprocess.BCT2SE(masterObj.bct_data, se, masterTb.hasIntan(i) || masterTb.hasNiDaq(i), seshInfo.inhSite, seshInfo.Genotype,manipulation); 
     else
         BS.Preprocess.BCT2SE(masterObj.bct_data, se, masterTb.hasIntan(i) || masterTb.hasNiDaq(i));
     end

    fprintf('\n');   
    
    % Get event times
    if masterTb.hasIntan(i) || masterTb.hasNiDaq(i)
        if ~ismember('behavTime', se.tableNames)
            disp('Processing event times');
            BS.Preprocess.GetEventTimes(se, masterTb.hasNiDaq(i));
            fprintf('\n');
        end
    
        % Set reference time
        try
            se.SetReferenceTime(se.userData.intanInfo.trialStartTime);
        catch
            
            se.RemoveEpochs(numel(se.userData.intanInfo.trialStartTime)+1:se.numEpochs)
            se.SetReferenceTime(se.userData.intanInfo.trialStartTime);
        end
        % Quality control of trials (remove trials with pre-stim licking and the
        % last 20 trials)
        bctInfo=  fieldnames(se.userData.bctData);
        if ~any(cell2mat(regexpi(bctInfo,'bodyside7*')))

            BS.Preprocess.TrialQC(se);
            se.AlignTime('stimOnset', 'behavTime'); 
        else
           
            stimOnsets = se.GetColumn( 'behavTime', 'stimOnset');
            se.RemoveEpochs(find(isnan(stimOnsets)));
            se.AlignTime('stimOnset', 'behavTime'); 
           

        end

    
        
    end

    

    
    % Save SE
    disp('Saving SE to disk');
    seArray{i} = se;
    sePaths{i} = fullfile(seDir, [strrep(masterTb.masterName{i}, 'master', 'se') '.mat']);
    save(sePaths{i}, 'se', '-v7.3');   
   
    fprintf('\n');
end

%% Just update Sessions Explorer

% Choose to create new SEs or to update existing ones 
answer = questdlg('What to do?', 'MSessionExplorer', ...
	'Create', 'Update', 'Cancel', 'Cancel');

switch answer
    case 'Create'
        seDir = MBrowse.Folder([], 'Select a directory to save SEs');
        sePaths = cell(size(masterPaths));
    case 'Update'
        sePaths = MBrowse.Files([], 'Select SEs to update');
        seDir = fileparts(sePaths{1});        
    otherwise
        return;
end


% Loop through master files
seArray = cell(size(masterPaths));


for i = 1 : numel(masterPaths)
    
    masterObj = masterTb.masterObj{i};
    fprintf('%s\n\n', masterTb.masterName{i});    
  
    
    % Construct SE
    if exist(sePaths{i}, 'file')
        load(sePaths{i});        
    else        
        se = MSessionExplorer();      
    end
    

    % Add sessionInfo to se
    se.userData.sessionInfo = masterObj.seshInfo;
    % Creat session Information 

   
    
    
    % Save SE
    disp('Saving SE to disk');
    seArray{i} = se;
    sePaths{i} = fullfile(seDir, [strrep(masterTb.masterName{i}, 'master', 'se') '.mat']);
    save(sePaths{i}, 'se', '-v7.3');   
   
    fprintf('\n');
end

%% Enrich SEs

% Add trial duration types


clear all
% Computing spike rate
ops.isSpkRate = true;
ops.spkLagInSec = 0;
ops.spkBinSize = 0.0025;
ops.spkKerSize = 0.005;
% Choose raw SEs
[readPaths, seDir, seNames] = MBrowse.Files([], 'Select source SEs');

% Determine save paths
%   0 - save to the same folder as the raw se
%   1 - replace existing enriched se files in Analysis folder
saveOpt = 0;

savePaths = cell(size(readPaths));
for i = 1 : numel(readPaths)
    seNameRaw = erase(seNames{i}, ' enriched');
    switch saveOpt
        case 0
            savePaths{i} = fullfile(seDir, [seNameRaw ' enriched.mat']);
        case 1
            seSearch = MBrowse.Dir2Table(fullfile(SL.Param.GetAnalysisRoot, '**', [seNames{i} ' enriched.mat']));
            if height(seSearch) == 0
                error('No existing file found');
            elseif height(seSearch) > 1
                error('Found multiple existing files');
            end
            savePaths{i} = fullfile(seSearch.folder{1}, seSearch.name{1});
    end
end

% Processing
for i = 1 : numel(readPaths)
    load(readPaths{i});
    try
        BS.SE.AddSpikeRateTable(se,ops);
    catch
        keyboard;
        se.RemoveEpochs();
        BS.SE.AddSpikeRateTable(se,ops);
    end
    save(savePaths{i}, 'se', '-v7.3');
end