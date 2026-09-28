%% Program to remove temp_wh.dat and .imec file from KilosortStim folder
ksDir = 'D:\DATA\PreprocessingWorkspace\VC0301\Kilosortstim';
rootInfo = MUtil.Dir2Table(ksDir);
rootInfo(~rootInfo.isdir,:) = [];
rootInfo(1:2,:) = [];
groupDirs = cellfun(@fullfile, rootInfo.folder, rootInfo.name, 'Uni', false);

selectedIdx = listdlg('PromptString', 'Select sessions to proceed: ', ...
    'ListSize', [300 400], ...
    'ListString', groupDirs);
tsv2keep = {'cluster_group.tsv', 'cluster_KSLabel.tsv', 'cluster_Amplitude.tsv', 'cluster_ContamPct.tsv'};

for i = selectedIdx
    sessName = rootInfo.name{i};
    
    %remove temp_wh.dat
    alltsv = dir(fullfile(rootInfo.folder{i}, sessName, '*.tsv'));

    for file = 1:height(alltsv)
        if ~ismember(alltsv(file).name, tsv2keep)
            tempFilePath = fullfile(alltsv(file).folder, alltsv(file).name);

            if isfile(tempFilePath)
                delete(tempFilePath);
            end

        end
    end

    metricsFilePath = dir(fullfile(rootInfo.folder{i}, sessName, 'metrics*.csv'));
    for file = 1:height(metricsFilePath)
        
        tempFilePath = fullfile(metricsFilePath(file).folder, metricsFilePath(file).name);

        if isfile(tempFilePath)
            delete(tempFilePath);
        end      
    end
    
    
   
end