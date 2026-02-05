%% This script is for analyzing through just stims under anesthesia for ROBOKO project
% Bcontrol + intan data

%Get data into se first
clear all

% Choose a group folder
rootDir = 'L:\VC03_RoboKO';
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
intanDirInfo = [];

for i = 1 : height(groupDirInfo)
    switch groupDirInfo.name{i}
        case 'Bcontrolstim'
            behavAnimalsInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            behavAnimalsInfo(1:2,:) = [];
            behavDirInfo = [];
            for j = 1:height(behavAnimalsInfo)
                behavDirInfo = [behavDirInfo; MBrowse.Dir2Table(fullfile(behavAnimalsInfo.folder{j}, ...
                    behavAnimalsInfo.name{j}, '*.mat'))];
            end       
         case 'Intanstim'
            intanAnimalsInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            intanAnimalsInfo(1:2,:) = [];       
            intanDirInfo = [];
            for j = 1:height(intanAnimalsInfo)
                temp = MBrowse.Dir2Table(fullfile(intanAnimalsInfo.folder{j}, intanAnimalsInfo.name{j}));
                temp(1:2,:) = [];
                intanDirInfo = [intanDirInfo; temp];
            end
        case 'SGL_Data'
            NPAnimalsInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            NPAnimalsInfo(1:2,:) = [];       
            NPDirInfo = [];
            for j = 1:height(NPAnimalsInfo)
                temp = MBrowse.Dir2Table(fullfile(NPAnimalsInfo.folder{j}, NPAnimalsInfo.name{j}));
                temp(1:2,:) = [];
                NPDirInfo = [NPDirInfo; temp];
            end
                
        case 'StimInfo'
            sessInfoDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}, '*.csv'));   
        
    end
end


% Find all data files for each session
dataFileTb = table();

for i = height(behavDirInfo) : -1 : 1
    % Parse the file name of SatellitesViewer log to get session identifiers
    behavNameParts = strsplit(behavDirInfo.name{i}, {'_', '.'});
    animalId = behavNameParts{3};
    sessType = behavNameParts{2};
    sessionDatetime = datetime([behavNameParts{end-1}(1:end-1)], ...
        'InputFormat','yyMMdd', ...
        'Format', 'yyyy-MM-dd');
    subId = behavNameParts{end-1}(end);
    
    
    dataFileTb.animalId{i} = animalId;
    dataFileTb.sessionDatetime(i) = sessionDatetime;
    dataFileTb.subId{i} = subId;
    
    % Add bControl log file path
    dataFileTb.behavPath{i} = fullfile(behavDirInfo.folder{i}, behavDirInfo.name{i});
    
    % Add sessInfo to data Table
    dataFileTb.sessInfoPaths{i} = [];
    if ~isempty(sessInfoDirInfo)
        queryStr = ['^' animalId '.+'];
        isHit = ~cellfun(@isempty, regexpi(sessInfoDirInfo.name, queryStr));
        if any(isHit)
            dataFileTb.sessInfoPaths{i} = fullfile(sessInfoDirInfo.folder{isHit}, sessInfoDirInfo.name{isHit});
            
            % Creat session Information 
            seshInfoTb = readtable(dataFileTb.sessInfoPaths{i});    
            seshInfoTb.seshDate = arrayfun(@(x) datetime(x, 'InputFormat','yyMMdd', ...
                'Format', 'yyyy-MM-dd'), string(seshInfoTb.seshDate), 'UniformOutput', false); 
            
            ind = ismember(cellfun(@datenum, seshInfoTb.seshDate), datenum(dataFileTb.sessionDatetime(i))) & subId == cell2mat(seshInfoTb.subId);

            seshInfoTb = seshInfoTb(ind,:);     
            seshInfo = seshInfoTb; 
            if any(ind) && any(ismember(seshInfoTb.probeNames{1}, 'NP'))
                dataFileTb.isNP{i} = 1;
                dataFileTb.isKilosort{i} = 1;
                dataFileTb.isMclust{i} = 0;
            elseif any(ind)
                dataFileTb.isNP{i} = 0;
                dataFileTb.isKilosort{i} = 1;
                dataFileTb.isMclust{i} = 0;
            else
                dataFileTb.isNP{i} = 0;
                dataFileTb.isKilosort{i} = 0;
                dataFileTb.isMclust{i} = 0;
            end

        end            
    end



    % Find Intan files
    dataFileTb.intanPaths{i} = [];
    if ~isempty(intanDirInfo) && ~dataFileTb.isNP{i}
       
        queryStr = ['^' animalId '.+' datestr(sessionDatetime, 'yymmdd') subId '$'];     

        
            
        
        isHit = ~cellfun(@isempty, regexpi(intanDirInfo.name, queryStr));
        if any(isHit)
            fileInfo = MBrowse.Dir2Table(fullfile(intanDirInfo.folder{isHit}, intanDirInfo.name{isHit}, '*.rhd'));
            if ~isempty(fileInfo)
                fileInfo = sortrows(fileInfo, 'datenum');
                dataFileTb.intanPaths{i} = cellfun(@(x,y) fullfile(x,y), fileInfo.folder, fileInfo.name, 'Uni', false);
            end
        end
    end


     % Find SGLX files
    dataFileTb.NPPaths{i} = [];
    if ~isempty(NPDirInfo)
        queryStr = ['^' animalId '.+' datestr(sessionDatetime, 'yymmdd') '+' subId '.*$'];    
        
        
        isHit = ~cellfun(@isempty, regexpi(NPDirInfo.name, queryStr));
        if any(isHit)
            
            fileInfo = MBrowse.Dir2Table(fullfile(NPDirInfo.folder{isHit}, NPDirInfo.name{isHit}, '*.bin'));
            if ~isempty(fileInfo)
                   
                fileInfo = sortrows(fileInfo, 'datenum');
                dataFileTb.NPPaths{i} = cellfun(@(x,y) fullfile(x,y), fileInfo.folder, fileInfo.name, 'Uni', false);
            end
        end
    end


   
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

clear sessionFullName selectedInd

%% Process data and add them to one master file

% Specify the preprocessing workspace

mainDir = MBrowse.Folder('L:\VC03_RoboKO\VC0301', 'Select a preprocessing workspace');


BcontDir = [groupDir, '\Bcontrolstim'];
seDir = [groupDir, '\StimSEs'];
masterDir = [groupDir, '\StimMasterFiles'];

if ~exist(masterDir, 'dir')
    mkdir(masterDir);
end

if ~exist(seDir, 'dir')
    mkdir(seDir);
end


% Loop through selected sessions
for i = find(dataFileTb.isSelected)'
% for i = 16:20
    close all
    isKilosort = dataFileTb.isKilosort{i};
    isNP = dataFileTb.isNP{i};
    isMclust = dataFileTb.isMclust{i};
    % Get a session identifier
    KsessionId = [ ...
        dataFileTb.animalId{i} '_' ...
        datestr(dataFileTb.sessionDatetime(i), 'yyyy-mm-dd') ...
        dataFileTb.subId{i} ...
        ];
    sessionId = [ ...
        dataFileTb.animalId{i} '_' ...
        datestr(dataFileTb.sessionDatetime(i), 'yyyy-mm-dd') ...
        dataFileTb.subId{i} ...
        ];
    mastersessionId = [ ...
        dataFileTb.animalId{i} ' ' ...
        datestr(dataFileTb.sessionDatetime(i), 'yyyy-mm-dd') ...
        dataFileTb.subId{i} ...
        ];
    sessionId = strtrim(sessionId);
    disp(['Start processing data for ' sessionId]);
    subId = dataFileTb.subId{i};
    % Derive file and folder path
    masterPath = fullfile(masterDir, [mastersessionId ' master.mat']);
    
    if isKilosort && ~isNP
        ksDir = fullfile(mainDir,'Kilosortstim', KsessionId);
        datPath = fullfile(ksDir, 'amplifier.dat');
        npyPath = fullfile(ksDir, 'spike_times.npy');
        csvPath = fullfile(ksDir, 'cluster_group.tsv');
        if ~exist(ksDir)
            mkdir(ksDir);
        end
    elseif isKilosort && isNP
        KSsessionId = [dataFileTb.animalId{i} '_' datestr(dataFileTb.sessionDatetime(i), 'yymmdd') subId];
        ksDir = fullfile(mainDir, 'Kilosortstim',KSsessionId,...
        'catGT_output',['catgt_' KSsessionId '_g0'],[KSsessionId '_g0_imec0'],'imec0_ks2');
        
%         datPath = fullfile(ksDir, 'amplifier.dat');
%         npyPath = fullfile(ksDir, 'spike_times.npy');
        csvPath = fullfile(ksDir, 'cluster_group.tsv');
        if ~exist(ksDir)
            disp(['Cannot find the kilosrt folder for sglxData_' sessionId])
            continue;
        end
    elseif isMclust
        mcDir = fullfile(mainDir, [sessionId ' mclust']);
    end
        
    % Initialize master file
    masterObj = matfile(masterPath, 'Writable', true);
    
    % Creat session Information 
    seshInfoTb = readtable(dataFileTb.sessInfoPaths{i});    
    seshInfoTb.seshDate = arrayfun(@(x) datetime(x, 'InputFormat','yyMMdd', ...
        'Format', 'yyyy-MM-dd'), string(seshInfoTb.seshDate), 'UniformOutput', false); 
    
    ind = ismember(cellfun(@datenum, seshInfoTb.seshDate), datenum(dataFileTb.sessionDatetime(i))) & subId == cell2mat(seshInfoTb.subId);
    seshInfoTb = seshInfoTb(ind,:);     
    seshInfo = seshInfoTb; 
    
     % Add Intan data
    if isempty(whos(masterObj, 'intan_data')) && ~isNP

        if isKilosort 
            intanOps = SL.Preprocess.GetIntanOptions(ksDir);
            intanData = MIntan.ReadRhdFiles(dataFileTb.intanPaths{i}, intanOps);            
            intanData.adc_data = MMath.Decimate(intanData.adc_data, 30);
            intanData.adc_time = downsample(intanData.adc_time, 30);
            masterObj.intan_data = intanData;
        
        elseif isMclust    
            mex -setup:'C:\Program Files\MATLAB\R2018b\bin\win64\mexopts\msvcpp2013.xml' C++
            mkdir(mcDir);
            cd(mcDir);
            t = dataFileTb.sessionDatetime(i);
            t.Format = 'yyMMdd';
            sourceIntan = fullfile(groupDir, ['Intan\' dataFileTb.animalId{i} '_' char(t)]);
            copyfile(sourceIntan, mcDir);            
            

            % Preprare ops for CatSessions
            intanOps = NeNRR.VMClust.GetOptions();
            
            % amplifier
            intanOps(1).isReturn = 1;
            intanOps(1).downsampleFactor = 30;
            intanOps(1).keptChannels = [];
            intanOps(1).binFilePath = fullfile(mcDir, 'bin.dat');
            intanOps(1).mcDirFilePath = mcDir;

            % Read RHD files
            intanData = NeNRR.VMClust.CatSession(mcDir, intanOps, minIEI);
            toc
            
            %downsample adc table
            intanData.adc_data = MMath.Decimate(intanData.adc_data, 30);
            intanData.adc_time = downsample(intanData.adc_time, 30);
            
            
            masterObj.intan_data = intanData;
            

        end
    

    end
    
    % Run Kilosort
    if exist('datPath', 'var') ==1 || isNP
        if exist('datPath', 'var') && ~exist(npyPath, 'file')
            try
                addpath(genpath('C:\Users\VarunChokshi\Documents\GitHub\OldKilosortVersions\Kilosort-2.5'));
                rmpath(genpath('C:\Users\VarunChokshi\Documents\GitHub\OldKilosortVersions\Kilosort-2.0')); 
                rmpath(genpath('C:\Users\VarunChokshi\Documents\GitHub\OldKilosortVersions\Kilosort-1.0')); 
                VKilosort.Sort(datPath, 'probeNames', seshInfo.probeNames{:});
            catch
                keyboard;
            end
        end
    
        
    % Add Kilosort and TemplateGUI outputs
        if isempty(whos(masterObj, 'spike_data')) && exist(csvPath, 'file') && ~isNP
            spikeData = VKilosort.ImportResults(ksDir, isNP);
            masterObj.spike_data = spikeData;         
            seshInfo.channel_map = load([ksDir,'\chanMap.mat']);   
        elseif isempty(whos(masterObj, 'spike_data')) && exist(csvPath, 'file') && isNP
            spikeData = VKilosort.ImportResults(ksDir, isNP);
            masterObj.spike_data = spikeData;         
            seshInfo.chanmap = load(fullfile(fileparts(ksDir),[KSsessionId '_g0_tcat.imec0.ap_chanMap.mat']));
        end
    end
  
    fighandles = findall(0,'type', 'Figure');
    if ~isempty(fighandles)
        saveas(fighandles(1), fullfile(ksDir,'Spatial components.png'));
        saveas(fighandles(2), fullfile(ksDir,'Drift map.png'));
        saveas(fighandles(3), fullfile(ksDir,'Estimated drift traces.png'));
        close all
    end

  % Add session Information
    
%     masterObj.seshInfo = seshInfo;
    
    if isempty(whos(masterObj, 'seshInfo')) & ~isNP
        seshInfo.unit_channel_id = spikeData.info.unit_channel_ind; %Indices of primary channel (after mapping) for each unit.
        seshInfo.unit_position = (seshInfo.unit_channel_id - 1)*20; % unit positions  
        seshInfo.ksDir = ksDir;
        masterObj.seshInfo = seshInfo;
    elseif isempty(whos(masterObj, 'seshInfo')) & isNP
        seshInfo.channel_map{1} = seshInfo.chanmap.chanMap;
        seshInfo.unit_channel_id{1} = seshInfo.chanmap.chanMap0ind; %Indices of primary channel (after mapping) for each unit.
        seshInfo.unit_position{1} ={seshInfo.chanmap.xcoords,  seshInfo.chanmap.ycoords, seshInfo.chanmap.kcoords}; % unit positions  
        seshInfo.ksDir = ksDir;
        masterObj.seshInfo = seshInfo;
    end

    % Add Bcontrol data
    if isempty(whos(masterObj, 'bct_data')) 
        bct_data = BS.bodyside_switchArray(dataFileTb.behavPath{i}, dataFileTb.sessionDatetime(i));
        masterObj.bct_data = bct_data;
    end
   
    
    if isNP
        % Add Dig_in
        ksDirParts = strsplit(ksDir,'\');
        NIDAQDir = fullfile(ksDirParts{1:end-2}); 
        imecDir = fullfile(ksDirParts{1:end-1});
        nidaqBin = dir( fullfile(NIDAQDir,'*bin') );
        
       %Identify XD_8_0 and XD_8_1 files and add that to nidaqData.digin;
        % Add ADC data
        % take from sgl data and use the DemoReadSGLXData to extract the
        % analog channels. 

       

        % Ask user for binary file        
        [path,binName,ext] = fileparts(dataFileTb.NPPaths{i});
        binName = [binName ext];
        % Parse the corresponding metafile
        meta = NeNRR.ReadSGLXData.ReadMeta(binName, path);
        
        % Get first one second of data

%         nSamp = floor(1.0 * NeNRR.ReadSGLXData.SampRate(meta));
        sampleRate = NeNRR.ReadSGLXData.SampRate(meta);
        nChan = str2double(meta.nSavedChans);
        nFileSamp = str2double(meta.fileSizeBytes) / (2 * nChan);
        dataArray = NeNRR.ReadSGLXData.ReadBin(0, nFileSamp, meta, binName, path);
        
        dataType = 'A';         %set to 'A' for analog, 'D' for digital data 
      
           
        nidaq_data.info.sample_rate = sampleRate;
        nidaq_data.info.adc_sample_rate = sampleRate/10;

        nidaq_data.adc_data= NeNRR.ReadSGLXData.GetSGLXChannel(dataArray, dataType, meta); %d ataArray has all the didaq data but needs to be gain corrected
        nidaq_data.adc_data = nidaq_data.adc_data';
        nidaq_data.adc_data = nidaq_data.adc_data(:,1:end-1); % Take only analog channels given last one is always digital channel

        
        nidaq_data.adc_time = 0: 1/sampleRate: nFileSamp/sampleRate;
        nidaq_data.adc_time = nidaq_data.adc_time';
        nidaq_data.adc_time = nidaq_data.adc_time(1:end-1);


        nidaq_data.adc_data = MMath.Decimate(nidaq_data.adc_data, 10);
        nidaq_data.adc_time = downsample(nidaq_data.adc_time, 10);
        
        
        dataType = 'D';
        nidaq_data.dig_in_data(:,2) = NeNRR.ReadSGLXData.GetSGLXChannel(dataArray, dataType, meta, 'dw', 1, 'digitalLine', 0); %pulse sync signal
        nidaq_data.dig_in_data(:,1) = NeNRR.ReadSGLXData.GetSGLXChannel(dataArray, dataType, meta, 'dw', 1, 'digitalLine', 1); % delimiterData   
        
        % get parsed time points for nidaq pulse
        cd(NIDAQDir)
        nidaqPulsePath = dir('*XD_8_0_500.txt'); 
        fileID = fopen(fullfile(nidaqPulsePath.folder,nidaqPulsePath.name));
        pulseSyncNI = fscanf(fileID, '%f');
        nidaq_data.info.pulseNidaqECE = pulseSyncNI;

        % get parsed time points for nidaq trial delims
        nidaqPulsePath = dir('*XD_8_1_0.txt'); 
        fileID = fopen(fullfile(nidaqPulsePath.folder,nidaqPulsePath.name));
        trialDelimsECE = fscanf(fileID, '%f');

        trialDelimsECE = [0; trialDelimsECE];
        temp = flip(trialDelimsECE);
        differ = diff(temp);
        trialDelimPos = abs(differ)>3;
        ttt = temp(~trialDelimPos);
        trialDelimsECE = flip(temp);
        trialDelimsECE(ismember(trialDelimsECE,ttt)) = nan;
        nidaq_data.info.trialDelimsECE = trialDelimsECE;

        

        
%         figure(11); clf
%         hold on
%         plot(trialDelimsECE, ones(numel(trialDelimsECE),1), '.', 'Color','r');
%         plot(ttt, ones(numel(ttt),1), '.', 'Color','b')       
%         
%         plot(trialDelimsECE, 1.1* ones(numel(trialDelimsECE),1), '.', 'Color','g');

%         ylim([-10,10])


        % here may be I can add LFP data or intan_data downsampled?
        cd(imecDir);
        imecPulsePath = dir('*SY_384_6_500.txt'); 
        fileID = fopen(fullfile(imecPulsePath.folder,imecPulsePath.name));
        pulseSyncImec = fscanf(fileID, '%f');
        nidaq_data.info.pulseImecECE = pulseSyncImec;       

        % get imec meta data
        binNameImec = dir('*.bin');
        metaImec = NeNRR.ReadSGLXData.ReadMeta(binNameImec.name, binNameImec.folder);

        %subtract 500s from spikeTimes if appVersion =='20201103' and
        %imDatBs_fw == '2.0.169'

        if strcmp(metaImec.appVersion,'20201103') && strcmp(metaImec.imDatBs_fw,  '2.0.169')
            spikeData.spike_times = cellfun(@(x) x-0.5, spikeData.spike_times, 'UniformOutput', false);
            masterObj.spike_data = spikeData; 
            disp('Shifted spikeTimes by 0.5 secs');
        end

        nidaq_data.info.pulseImecECE = pulseSyncImec;
        
        g = figure(1);clf
        hold on
        x =0:1/sampleRate:nFileSamp/sampleRate;
        k(1) = plot(x(1:end-1), nidaq_data.dig_in_data(:,2), 'Color','k');
        k(2) = plot(pulseSyncNI, ones(numel(pulseSyncNI),1), '.', 'Color','r');
        k(3) = plot(pulseSyncImec, ones(numel(pulseSyncImec),1), '.', 'Color','b');
        legend(k, {'nidaq raw', 'pulsesyncNiECE', 'pulsesyncImecECE'});
        hold off
        savefig(g, fullfile(ksDir, 'pulseSyncFig.fig'));
        
        masterObj.nidaq_data = nidaq_data;
        clear nidaq_data
    end
end

fclose('all');
clear i sessionId

%% Add kilosort manual curated spike data
% phy template-gui params.py, clustering filter : group != 'noise' && KSLabel != 'mua'

ksMainDir = MBrowse.Folder('L:\VC03_RoboKO\VC0301', 'Select kiosortStim folder');

n =1;
while n==1
    masterPaths = MBrowse.Files([],'Select master files', {'.mat'});
    for i =1:numel(masterPaths)
        masterObj = matfile(masterPaths{i}, 'Writable', true);
        varList = who('-file', masterPaths{i});

        if  ismember('intan_data', varList)
            intanData = masterObj.intan_data;
            seshInfo = masterObj.seshInfo;

%             try
%                 ksDir = intanData.info.ops(1).ksDirFilePath;
%             catch
%                 try
%                     tt = strsplit(intanData.info.ops(2).binFilePath, '\');
%                     ksDir = fullfile(tt{1:end-1});
%                 catch
                    
                    masterPathParts =  strsplit(masterPaths{i}, '\');
                    folderName = masterPathParts{end}(1:end-11);
                    ksDir = fullfile(ksMainDir, folderName);
                    folderName2 = strrep(folderName, ' ', '_');
                    ksDir2 =fullfile(ksMainDir, folderName2);
%                 end
                
%             end
            seshInfo = masterObj.seshInfo;  
            probeName = seshInfo.probeNames{1};
            isNP = sum(ismember(probeName,'NP'))>1;
            try
                spikeData = VKilosort.ImportResults(ksDir, isNP);
                seshInfo.ksDir = ksDir;
            catch
                spikeData = VKilosort.ImportResults(ksDir2, isNP);
                seshInfo.ksDir = ksDir2;
            end
            masterObj.spike_data = spikeData; 
            masterObj.seshInfo = seshInfo;
        end

    end
    prompt = 'If you want to add more enter 1: ';
    n = input(prompt);
end

%% Add seshInfo again
% phy template-gui params.py, clustering filter : group != 'noise' && KSLabel != 'mua'
clear all
sessMainDir = MBrowse.Folder('H:\VC03_RoboKO\VC0301', 'Select a preprocessing workspace');
sessInfoDirInfo = MBrowse.Dir2Table(fullfile(sessMainDir,'StimInfo', '*.csv'));  
animalIDs = cellfun(@(x) strsplit(x,'_'), sessInfoDirInfo.name, 'UniformOutput', false);
animalIDs = cellfun(@(x) x{1}, animalIDs, 'UniformOutput', false);


n =1;
while n==1
    masterPaths = MBrowse.Files([],'Select master files', {'.mat'});
    for i =1:numel(masterPaths)
        masterObj = matfile(masterPaths{i}, 'Writable', true);
        varList = who('-file', masterPaths{i});
        seshInfo = masterObj.seshInfo;
        masterPathParts =  strsplit(masterPaths{i}, '\');
        masterPathParts = strsplit(masterPathParts{end}, ' ');
        animalName = masterPathParts{1};
        sessDate = datetime(masterPathParts{2}(1:end-1), 'InputFormat', 'yyyy-MM-dd', 'Format', 'yyyy-MM-dd') ;
        subId = masterPathParts{2}(end);
        if  any(ismember(animalIDs, seshInfo.MouseName)) ||  any(ismember(animalIDs, animalName))
            % Creat session Information 
            sessInfoPath = sessInfoDirInfo(ismember(animalIDs, seshInfo.MouseName),:);
            seshInfoTb = readtable(fullfile(sessInfoPath.folder{1}, sessInfoPath.name{1}));    
            seshInfoTb.seshDate = arrayfun(@(x) datetime(x, 'InputFormat','yyMMdd', ...
                'Format', 'yyyy-MM-dd'), string(seshInfoTb.seshDate), 'UniformOutput', false); 
            
            ind = ismember(cellfun(@datenum, seshInfoTb.seshDate), datenum(sessDate)) & subId == cell2mat(seshInfoTb.subId);
            seshInfoTb = seshInfoTb(ind,:);     
            varNames = seshInfoTb.Properties.VariableNames;
            %get sessInfoTb variablenames

            seshInfo(1,varNames) = seshInfoTb(1,varNames); 
            
            masterObj.seshInfo = seshInfo;
            
        end

    end
    prompt = 'If you want to add more enter 1: ';
    n = input(prompt);
end

%% replace _ by ' ' in materfilename
clear
sessMainDir = MBrowse.Folder('H:\VC03_RoboKO\VC0301', 'Select a preprocessing workspace');
masterPaths = MBrowse.Files([],'Select master files', {'.mat'});
for i =1:numel(masterPaths)

    oldFilePath = masterPaths{i};
    filePathSplit = strsplit(oldFilePath, '\');
    newFilePathname = strrep(filePathSplit{end}, '_',' ');
    newFilePath = fullfile(filePathSplit{1:end-1}, newFilePathname)
%     masterObj_old = matfile(masterPaths{i}, 'Writable', true);
%     newFilePath = strrep(oldFilePath, '_',' ');
% 
%     masterObj = matfile(newFilePath, 'Writable', true);
%     masterObj = masterObj_old;
    movefile(oldFilePath, newFilePath)    
%     delete(oldFilePath);
end


%% add LFP data to intan data amplifier for selected neuropixel sessions
clear all
sessMainDir = MBrowse.Folder('H:\VC03_RoboKO\VC0301', 'Select a preprocessing workspace');
sessInfoDirInfo = MBrowse.Dir2Table(fullfile(sessMainDir,'StimInfo', '*.csv'));  
animalIDs = cellfun(@(x) strsplit(x,'_'), sessInfoDirInfo.name, 'UniformOutput', false);
animalIDs = cellfun(@(x) x{1}, animalIDs, 'UniformOutput', false);


n =1;
while n==1
    masterPaths = MBrowse.Files([],'Select master files', {'.mat'});
    for i =1:numel(masterPaths)
        masterObj = matfile(masterPaths{i}, 'Writable', true);
        varList = who('-file', masterPaths{i});
        seshInfo = masterObj.seshInfo;
        ksDir = seshInfo.ksDir;
        ksDirPathParts =  strsplit(ksDir, '\');   
        imecDir = fullfile(ksDirPathParts{1:end-1});
        binFile = dir([imecDir, '\*.bin']);
        metaFile = dir([imecDir, '\*.meta']);
        metaImec = NeNRR.ReadSGLXData.ReadMeta(binFile.name, binFile.folder);
        nChan = str2double(metaImec.nSavedChans);
        nSamp = str2double(metaImec.fileSizeBytes) / (2 * nChan)
        ninImec = NeNRR.ReadSGLXData.ReadBin(0, nSamp, metaImec, binFile.name, binFile.folder);


        masterPathParts = strsplit(masterPathParts{end}, ' ');
        animalName = masterPathParts{1};
        sessDate = datetime(masterPathParts{2}(1:end-1), 'InputFormat', 'yyyy-MM-dd', 'Format', 'yyyy-MM-dd') ;
        subId = masterPathParts{2}(end);
        if  any(ismember(animalIDs, seshInfo.MouseName)) ||  any(ismember(animalIDs, animalName))
            % Creat session Information 
            sessInfoPath = sessInfoDirInfo(ismember(animalIDs, seshInfo.MouseName),:);
            seshInfoTb = readtable(fullfile(sessInfoPath.folder{1}, sessInfoPath.name{1}));    
            seshInfoTb.seshDate = arrayfun(@(x) datetime(x, 'InputFormat','yyMMdd', ...
                'Format', 'yyyy-MM-dd'), string(seshInfoTb.seshDate), 'UniformOutput', false); 
            
            ind = ismember(cellfun(@datenum, seshInfoTb.seshDate), datenum(sessDate)) & subId == cell2mat(seshInfoTb.subId);
            seshInfoTb = seshInfoTb(ind,:);     
            varNames = seshInfoTb.Properties.VariableNames;
            %get sessInfoTb variablenames

            seshInfo(1,varNames) = seshInfoTb(1,varNames); 
            
            masterObj.seshInfo = seshInfo;
            
        end

    end
    prompt = 'If you want to add more enter 1: ';
    n = input(prompt);
end

