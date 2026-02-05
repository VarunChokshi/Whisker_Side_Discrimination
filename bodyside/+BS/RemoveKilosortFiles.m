%% Program to remove temp_wh.dat and .imec file from KilosortStim folder
ksDir = 'D:\DATA\PreprocessingWorkspace\VC0301\Kilosortstim';
rootInfo = MUtil.Dir2Table(ksDir);
rootInfo(~rootInfo.isdir,:) = [];
rootInfo(1:2,:) = [];
groupDirs = cellfun(@fullfile, rootInfo.folder, rootInfo.name, 'Uni', false);

selectedIdx = listdlg('PromptString', 'Select sessions to proceed: ', ...
    'ListSize', [300 400], ...
    'ListString', groupDirs);

for i = selectedIdx
    sessName = rootInfo.name{i};
    
    %remove temp_wh.dat
    tempFilePath = fullfile(rootInfo.folder{i}, sessName, 'temp_wh.dat');
    if isfile(tempFilePath)
        delete(tempFilePath);
    end

    %remove extra imecFile
    imecFilePath = fullfile(rootInfo.folder{i}, sessName, 'catGT_output', ['catgt_' sessName '_g0'], [sessName '_g0_imec0'], [sessName '_g0_tcat.imec0.ap.bin']);
    splitFile = strsplit(imecFilePath, '\');
    cd(fullfile(splitFile{1:end-1}))
    if isfile(imecFilePath)
        delete(imecFilePath);
    end
end

cd('D:\DATA')