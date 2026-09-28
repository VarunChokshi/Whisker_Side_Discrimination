function ldaTablesS1 = fig5_lda_tables_nwb(precomputedDir, outDir)
% FIG5_LDA_TABLES_NWB  Stage S1 Linear Discriminant Analysis (LDA) tables for Figure 5.
%
%   fig5_lda_tables_nwb()
%   fig5_lda_tables_nwb(precomputedDir, outDir)
%
% Inputs:
%   precomputedDir  Folder containing S1 50msBin LDA MAT files
%                   (default: ...\SingleUnitAnalysis\S1\LDA\50msBin)
%   outDir          Folder to write staged tables (default: ...\NWBData\Data\Tables\LDA)
%
% Output:
%   ldaTablesS1     Structured dataset containing session-wise classification
%                   accuracies and 100-bootstrap distributions for WT and KO across bins.

    if nargin < 1 || isempty(precomputedDir)
        precomputedDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'SeData', 'EphysPassiveStimSEs', 'SingleUnitAnalysis', 'S1', 'LDA', '50msBin');
    end

    if nargin < 2 || isempty(outDir)
        outDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData', 'Data', 'Tables', 'LDA');
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    fprintf('Staging Figure 5 (S1) LDA tables from: %s\n', precomputedDir);

    % Basic settings for S1 LDA analysis
    binSize = 0.05;
    timeWindow = [-0.05, 0.05];
    binStartTimes = [-50, 0];
    binEndTimes = [0, 50];
    timeLabels = {'-50 ~ 0 ms', '0 ~ 50 ms'};
    genotypes = {'WT', 'KO'};
    respMin = 3;

    ldaTablesS1 = struct();
    ldaTablesS1.region = 'S1';
    ldaTablesS1.binSize = binSize;
    ldaTablesS1.timeWindow = timeWindow;
    ldaTablesS1.binStartTimes = binStartTimes;
    ldaTablesS1.binEndTimes = binEndTimes;
    ldaTablesS1.timeLabels = timeLabels;
    ldaTablesS1.respMin = respMin;

    for b = 1:2
        startTime = binStartTimes(b);
        endTime = binEndTimes(b);

        % Load session-wise classification accuracy
        sessFile = fullfile(precomputedDir, ...
            sprintf('LDA_20Hz_%dmsBin_%dto%d.mat', round(binSize * 1000), startTime, endTime));
        if ~exist(sessFile, 'file')
            error('Session-wise LDA file not found: %s', sessFile);
        end
        sessData = load(sessFile);
        rawTable = sessData.LDA_table;

        % Load 100-bootstrap accuracy distributions
        bootFile = fullfile(precomputedDir, ...
            sprintf('LDA_100nBoot_20Hz_%dmsBin_%dto%d.mat', round(binSize * 1000), startTime, endTime));
        if ~exist(bootFile, 'file')
            error('Bootstrapped LDA file not found: %s', bootFile);
        end
        bootData = load(bootFile);
        bootRawTable = bootData.ca_table;

        ldaTablesS1.bins(b).timeLabel = timeLabels{b};
        ldaTablesS1.bins(b).startTime = startTime;
        ldaTablesS1.bins(b).endTime = endTime;

        for g = 1:numel(genotypes)
            geno = genotypes{g};

            % Filter session-wise units for genotype with responsive unit threshold
            isGeno = strcmp(rawTable.genotype, geno);
            isResp = rawTable.N_respUnit > respMin;
            validRows = isGeno & isResp;

            subRaw = rawTable(validRows, :);

            ldaTablesS1.bins(b).(geno).mouseName = subRaw.mouseName;
            ldaTablesS1.bins(b).(geno).sessionName = subRaw.sessionName;
            ldaTablesS1.bins(b).(geno).N_respUnit = subRaw.N_respUnit;
            ldaTablesS1.bins(b).(geno).LDA_true = subRaw.LDA_true;
            ldaTablesS1.bins(b).(geno).LDA_shuffle = subRaw.LDA_shuffle;

            % Extract bootstrap distributions
            isBootGeno = strcmp(bootRawTable.genotype, geno);
            bootTrue = bootRawTable{isBootGeno, 'true'};
            bootShuffle = bootRawTable{isBootGeno, 'shuffle'};

            if iscell(bootTrue)
                bootTrue = bootTrue{1};
            end
            if iscell(bootShuffle)
                bootShuffle = bootShuffle{1};
            end

            ldaTablesS1.bins(b).(geno).boot_true = bootTrue(:)';
            ldaTablesS1.bins(b).(geno).boot_shuffle = bootShuffle(:)';
        end
    end

    % Save structured MAT file (-v7 for cross-platform compatibility)
    outMat = fullfile(outDir, 'fig5_lda_tables_S1.mat');
    save(outMat, 'ldaTablesS1', '-v7');
    fprintf('Saved S1 LDA tables MAT -> %s\n', outMat);

    % Save JSON file for Python interoperability
    outJson = fullfile(outDir, 'fig5_lda_tables_S1.json');
    jsonText = jsonencode(ldaTablesS1);
    fid = fopen(outJson, 'w');
    if fid ~= -1
        fwrite(fid, jsonText, 'char');
        fclose(fid);
        fprintf('Saved S1 LDA tables JSON -> %s\n', outJson);
    end
end

