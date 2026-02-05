%% Find files based on SatellitesViewer files
clear all

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
intanDirInfo = [];
hsvDirInfo = [];
camDirInfo = [];

for i = 1 : height(groupDirInfo)
    switch groupDirInfo.name{i}
        case 'Bcontrol'
            behavAnimalsInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            behavAnimalsInfo(1:2,:) = [];
            behavDirInfo = [];
            for j = 1:height(behavAnimalsInfo)
                behavDirInfo = [behavDirInfo; MBrowse.Dir2Table(fullfile(behavAnimalsInfo.folder{j}, ...
                    behavAnimalsInfo.name{j}, '*.mat'))];
            end
        case 'Intan'
            intanAnimalsInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            intanAnimalsInfo(1:2,:) = [];       
            intanDirInfo = [];
            for j = 1:height(intanAnimalsInfo)
                temp = MBrowse.Dir2Table(fullfile(intanAnimalsInfo.folder{j}, intanAnimalsInfo.name{j}));
                temp(1:2,:) = [];
                intanDirInfo = [intanDirInfo; temp];
            end
            
            
        case 'SessInfo'
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
    sessionDatetime = datetime([behavNameParts{4}(1:end-1)], ...
        'InputFormat','yyMMdd', ...
        'Format', 'yyyy-MM-dd');
    subId = behavNameParts{4}(end);
    
    
    dataFileTb.animalId{i} = animalId;
    dataFileTb.sessionDatetime(i) = sessionDatetime;
    dataFileTb.subId{i} = subId;
    
    % Add bControl log file path
    dataFileTb.behavPath{i} = fullfile(behavDirInfo.folder{i}, behavDirInfo.name{i});
    
    % Find Intan files
    dataFileTb.intanPaths{i} = [];
    if ~isempty(intanDirInfo)
        if subId == 'a'
            queryStr = ['^' animalId '.+' datestr(sessionDatetime, 'yymmdd') '$'];
            

        elseif subId == 'b'
            queryStr = ['^' animalId '.+' datestr(sessionDatetime, 'yymmdd') '_2$'];            
        end
        isHit = ~cellfun(@isempty, regexpi(intanDirInfo.name, queryStr));
        if any(isHit)
            fileInfo = MBrowse.Dir2Table(fullfile(intanDirInfo.folder{isHit}, intanDirInfo.name{isHit}, '*.rhd'));
            if ~isempty(fileInfo)
                fileInfo = sortrows(fileInfo, 'datenum');
                dataFileTb.intanPaths{i} = cellfun(@(x,y) fullfile(x,y), fileInfo.folder, fileInfo.name, 'Uni', false);
            end
        end
    end
    
    % Add sessionInfo file
    dataFileTb.sessInfoPaths{i} = [];
    if ~isempty(sessInfoDirInfo)
        queryStr = ['^' animalId '.+'];
        isHit = ~cellfun(@isempty, regexpi(sessInfoDirInfo.name, queryStr));
        if any(isHit)
            dataFileTb.sessInfoPaths{i} = fullfile(sessInfoDirInfo.folder{isHit}, sessInfoDirInfo.name{isHit});
        end            
    end
end

clear satNameParts animalId sessionDatetime subId queryStr isHit fileInfo i


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
mainDir = MBrowse.Folder('C:\DATA', 'Select a preprocessing workspace');
isKilosort = 1;
isMclust =0;



BcontDir = [groupDir, '\Bcontrol'];
seDir = [groupDir, '\SEs'];
masterDir = [groupDir, '\MasterFiles'];

if ~exist(masterDir, 'dir')
    mkdir(masterDir);
end
if ~exist(seDir, 'dir')
    mkdir(seDir);
end


% Loop through selected sessions
for i = find(dataFileTb.isSelected)'
    
    % Get a session identifier
    sessionId = [ ...
        dataFileTb.animalId{i} ' ' ...
        datestr(dataFileTb.sessionDatetime(i), 'yyyy-mm-dd') ' ' ...
        dataFileTb.subId{i} ...
        ];
    sessionId = strtrim(sessionId);
    disp(['Start processing data for ' sessionId]);
    subId = dataFileTb.subId{i};
    % Derive file and folder path
    masterPath = fullfile(masterDir, [sessionId ' master.mat']);
    
    if isKilosort
        ksDir = fullfile(mainDir,'Kilosort', sessionId);
        datPath = fullfile(ksDir, 'amplifier.dat');
        npyPath = fullfile(ksDir, 'spike_times.npy');
        csvPath = fullfile(ksDir, 'cluster_group.tsv');
        if ~exist(ksDir)
        mkdir(ksDir);
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
    if isempty(whos(masterObj, 'intan_data'))

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
    if exist('datPath', 'var') ==1
        if exist(datPath, 'file') && ~exist(npyPath, 'file')
            try
                addpath(genpath('C:\Users\VarunChokshi\Documents\GitHub\OldKilosortVersions\Kilosort-2.5'));
                rmpath(genpath('C:\Users\VarunChokshi\Documents\GitHub\OldKilosortVersions\Kilosort-2.0')); 
                VKilosort.Sort(datPath, 'probeNames', seshInfo.probeNames{:});
%                 VKilosort.Sort(datPath, 'probeNames', 'H3');
            catch
                keyboard;
            end
        end
    
        
    % Add Kilosort and TemplateGUI outputs
        if isempty(whos(masterObj, 'spike_data')) && exist(csvPath, 'file')
            spikeData = VKilosort.ImportResults(ksDir);
            masterObj.spike_data = spikeData;         
            seshInfo.channel_map = load([ksDir,'\chanMap.mat']);         
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
    
    masterObj.seshInfo = seshInfo;
    
    if isempty(whos(masterObj, 'seshInfo'))
        seshInfo.unit_channel_id = spikeData.info.unit_channel_ind; %Indices of primary channel (after mapping) for each unit.
        seshInfo.unit_position = (seshInfo.unit_channel_id - 1)*20; % unit positions  
        masterObj.seshInfo = seshInfo;
    end

    % Add Bcontrol data
    if isempty(whos(masterObj, 'bct_data')) 
        bct_data = BS.bodyside_switchArray(dataFileTb.behavPath{i}, dataFileTb.sessionDatetime(i));
        masterObj.bct_data = bct_data;
    end
   


end

clear i sessionId

%% Merge b sessions to a! 
clear all
masterPaths = MBrowse.Files([], 'Select master files', {'.mat'});
masterTb = table();

for i = length(masterPaths) : -1 : 1
    disp(masterPaths{i});
    masterObj = matfile(masterPaths{i}, 'Writable',true);
    [~, masterName] = fileparts(masterPaths{i});
    varList = who('-file', masterPaths{i});
    
    masterTb.masterObj{i} = masterObj;
    masterTb.masterName{i} = masterName;
    masterTb.hasBehav(i) = ismember('bct_data', varList);
    masterTb.hasIntan(i) = ismember('intan_data', varList);
    masterTb.hasSpike(i) = ismember('spike_data', varList);    
end

disp(masterTb);

bct_data1 = masterTb.masterObj{1}.bct_data;
bct_data2 = masterTb.masterObj{2}.bct_data;
bct_data1.trialType = [bct_data1.trialType; bct_data2.trialType]; 
bct_data1.trialResponse = [bct_data1.trialResponse; bct_data2.trialResponse]; 
bct_data1.leftStimType = [bct_data1.leftStimType; bct_data2.leftStimType];
bct_data1.rightStimType = [bct_data1.rightStimType; bct_data2.rightStimType];
bct_data1.blockType = [bct_data1.blockType; bct_data2.blockType];
tt = ones(size(bct_data1.blockType,1),1);
bct_data1.trialNums = mat2cell((1:size(bct_data1.blockType,1))', [ones(size(bct_data1.blockType,1),1)'], [1]);
masterTb.masterObj{1}.bct_data = bct_data1;

%remove masterfile
clear all
masterPaths = MBrowse.Files([], 'Select master files', {'.mat'});
delete(masterPaths{1});

%% Add kilosort manual curated spike data
% phy template-gui params.py, clustering filter : group != 'noise' && KSLabel != 'mua'

ksMainDir = MBrowse.Folder('C:\DATA', 'Select a preprocessing workspace');

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
%                 end
                
%             end
            seshInfo.ksDir = ksDir;
            spikeData = BS.VKilosort.ImportResults(ksDir);
            masterObj.spike_data = spikeData; 
            masterObj.seshInfo = seshInfo;
        end

    end
    prompt = 'If you want to add more enter 1: ';
    n = input(prompt);
end

%% Add seshInfo again
% phy template-gui params.py, clustering filter : group != 'noise' && KSLabel != 'mua'

sessMainDir = MBrowse.Folder('G:\VC03_RoboKO\VC0301', 'Select a preprocessing workspace');
sessInfoDirInfo = MBrowse.Dir2Table(fullfile(sessMainDir, '*.csv'));  
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
        sessDate = datetime(masterPathParts{2}, 'InputFormat', 'yyyy-MM-dd', 'Format', 'yyyy-MM-dd') ;
        subId = masterPathParts{3};
        if  any(ismember(animalIDs, seshInfo.MouseName)) ||  any(ismember(animalIDs, animalName))
            seshInfoNo = find(ismember(animalIDs, animalName));
            sessInfoPath = fullfile(sessInfoDirInfo.folder{seshInfoNo}, sessInfoDirInfo.name{seshInfoNo})
              % Creat session Information 
            seshInfoTb = readtable(sessInfoPath);    
            seshInfoTb.seshDate = arrayfun(@(x) datetime(x, 'InputFormat','yyMMdd', ...
            'Format', 'yyyy-MM-dd'), string(seshInfoTb.seshDate), 'UniformOutput', false); 
            
            ind = cell2mat(cellfun(@(x) eq(x,sessDate), seshInfoTb.seshDate, 'UniformOutput', false)) & subId == cell2mat(seshInfoTb.subId);
            seshInfoTb = seshInfoTb(ind,:);     
            seshInfo = seshInfoTb; 
            masterObj.seshInfo = seshInfo;            
        end

    end
    prompt = 'If you want to add more enter 1: ';
    n = input(prompt);
end


%% Display changes
 for i =1:numel(masterPaths)
        masterObj = matfile(masterPaths{i}, 'Writable', true);
        masterPaths{i}
        varList = who('-file', masterPaths{i})
        seshInfo = masterObj.seshInfo;
        seshInfo.ksDir

       
end
