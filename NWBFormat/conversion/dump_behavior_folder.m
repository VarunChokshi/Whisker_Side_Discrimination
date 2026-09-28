function dump_behavior_folder(inDir, outDir, pattern)
% DUMP_BEHAVIOR_FOLDER  Dump every behavioral se file in a folder to *_struct.mat.
%
%   dump_behavior_folder(inDir, outDir)
%   dump_behavior_folder(inDir, outDir, pattern)
%
% Inputs
%   inDir    folder containing behavioral se files (e.g. ...\SeData\VC0301\behavSEs)
%   outDir   folder to write *_struct.mat files (e.g. ...\NWBData\Conversion\behav_struct)
%   pattern  file glob to match, default '*se.mat' (matches "... se.mat", NOT
%            "... se enriched.mat")
%
% Runs dump_se_to_struct on each match and keeps going if one fails.

    % --- arguments / output folder ---
    if nargin < 3 || isempty(pattern)
        pattern = '*se.mat';
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % --- find the se files to dump (skip any directories the glob matched) ---
    sessFiles = dir(fullfile(inDir, pattern));
    sessFiles = sessFiles(~[sessFiles.isdir]);
    fprintf('Found %d file(s) matching %s in %s\n', numel(sessFiles), pattern, inDir);

    % --- dump each one, reporting (but not aborting on) individual failures ---
    nDumped = 0;
    for fileInd = 1:numel(sessFiles)
        sePath = fullfile(sessFiles(fileInd).folder, sessFiles(fileInd).name);
        try
            dump_se_to_struct(sePath, outDir);
            nDumped = nDumped + 1;
        catch dumpErr
            fprintf(2, 'ERROR on %s: %s\n', sessFiles(fileInd).name, dumpErr.message);
        end
    end
    fprintf('Done: %d/%d dumped to %s\n', nDumped, numel(sessFiles), outDir);
end
