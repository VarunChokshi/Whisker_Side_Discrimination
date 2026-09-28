function dump_ephys_folder(inDir, outDir, pattern)
% DUMP_EPHYS_FOLDER  Dump every enriched ephys se in a folder to *_struct.mat.
%
%   dump_ephys_folder(inDir, outDir)
%   dump_ephys_folder(inDir, outDir, pattern)
%
% Inputs
%   inDir    folder of enriched ephys se files (e.g. ...\EphysPassiveStimSEs\StimSEs_2_5msFR)
%   outDir   folder to write *_struct.mat files (e.g. ...\NWBData\Conversion\ephys_struct_S1)
%   pattern  file glob to match, default '*enriched.mat'
%
% Runs dump_ephys_se_to_struct on each match and keeps going if one fails. These files
% are large; expect this to take a while and use significant disk for the struct copies.

    % --- arguments / output folder ---
    if nargin < 3 || isempty(pattern)
        pattern = '*enriched.mat';
    end
    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    % --- find the enriched se files to dump ---
    sessFiles = dir(fullfile(inDir, pattern));
    sessFiles = sessFiles(~[sessFiles.isdir]);
    fprintf('Found %d file(s) matching %s in %s\n', numel(sessFiles), pattern, inDir);

    % --- dump each one, reporting (but not aborting on) individual failures ---
    nDumped = 0;
    for fileInd = 1:numel(sessFiles)
        sePath = fullfile(sessFiles(fileInd).folder, sessFiles(fileInd).name);
        fprintf('[%d/%d] %s\n', fileInd, numel(sessFiles), sessFiles(fileInd).name);
        try
            dump_ephys_se_to_struct(sePath, outDir);
            nDumped = nDumped + 1;
        catch dumpErr
            fprintf(2, 'ERROR on %s: %s\n', sessFiles(fileInd).name, dumpErr.message);
        end
    end
    fprintf('Done: %d/%d dumped to %s\n', nDumped, numel(sessFiles), outDir);
end
