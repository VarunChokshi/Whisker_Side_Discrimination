function ldaTablesM1 = fig7_lda_tables_nwb(precomputedDir, outDir)
% FIG7_LDA_TABLES_NWB  Stage M1 Linear Discriminant Analysis (LDA) tables for Figure 7.
%
%   fig7_lda_tables_nwb()
%   fig7_lda_tables_nwb(precomputedDir, outDir)
%
% Inputs:
%   precomputedDir  Folder containing M1 100msBin LDA MAT files
%                   (default: ...\SingleUnitAnalysis\Motor\LDA\100msBin)
%   outDir          Folder to write staged tables (default: ...\NWBData\Data\Tables\LDA)
%
% Output:
%   ldaTablesM1     Structured dataset containing session-wise classification
%                   accuracies and 100-bootstrap distributions for WT and KO across bins.

    if nargin < 1 || isempty(precomputedDir)
        precomputedDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'SeData', 'EphysPassiveStimSEs', 'SingleUnitAnalysis', 'Motor', 'LDA', '100msBin');
    end

    if nargin < 2 || isempty(outDir)
        outDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData', 'Data', 'Tables', 'LDA');
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    fprintf('Staging Figure 7 (M1) LDA tables from: %s\n', precomputedDir);

    % Basic settings for M1 LDA analysis
    binSize = 0.1;
    timeWindow = [-0.1, 0.1];
    binStartTimes = [-100, 0];
    binEndTimes = [0, 100];
    timeLabels = {'-100 ~ 0 ms', '0 ~ 100 ms'};
    genotypes = {'WT', 'KO'};
    respMin = 3;

    ldaTablesM1 = struct();
    ldaTablesM1.region = 'M1';
    ldaTablesM1.binSize = binSize;
    ldaTablesM1.timeWindow = timeWindow;
    ldaTablesM1.binStartTimes = binStartTimes;
    ldaTablesM1.binEndTimes = binEndTimes;
    ldaTablesM1.timeLabels = timeLabels;
    ldaTablesM1.respMin = respMin;

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

        ldaTablesM1.bins(b).timeLabel = timeLabels{b};
        ldaTablesM1.bins(b).startTime = startTime;
        ldaTablesM1.bins(b).endTime = endTime;

        for g = 1:numel(genotypes)
            geno = genotypes{g};

            % Filter session-wise units for genotype with responsive unit threshold
            isGeno = strcmp(rawTable.genotype, geno);
            isResp = rawTable.N_respUnit > respMin;
            validRows = isGeno & isResp;

            subRaw = rawTable(validRows, :);

            ldaTablesM1.bins(b).(geno).mouseName = subRaw.mouseName;
            ldaTablesM1.bins(b).(geno).sessionName = subRaw.sessionName;
            ldaTablesM1.bins(b).(geno).N_respUnit = subRaw.N_respUnit;
            ldaTablesM1.bins(b).(geno).LDA_true = subRaw.LDA_true;
            ldaTablesM1.bins(b).(geno).LDA_shuffle = subRaw.LDA_shuffle;

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

            ldaTablesM1.bins(b).(geno).boot_true = bootTrue(:)';
            ldaTablesM1.bins(b).(geno).boot_shuffle = bootShuffle(:)';
        end
    end

    % Save structured MAT file (-v7 for cross-platform compatibility)
    outMat = fullfile(outDir, 'fig7_lda_tables_M1.mat');
    save(outMat, 'ldaTablesM1', '-v7');
    fprintf('Saved M1 LDA tables MAT -> %s\n', outMat);

    % Save JSON file for Python interoperability
    outJson = fullfile(outDir, 'fig7_lda_tables_M1.json');
    jsonText = jsonencode(ldaTablesM1);
    fid = fopen(outJson, 'w');
    if fid ~= -1
        fwrite(fid, jsonText, 'char');
        fclose(fid);
        fprintf('Saved M1 LDA tables JSON -> %s\n', outJson);
    end
end

