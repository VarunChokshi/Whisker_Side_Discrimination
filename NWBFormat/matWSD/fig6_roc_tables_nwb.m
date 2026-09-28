function fig6_roc_tables_nwb(precomputedDir, outDir, mode, nwbDir)
% FIG6_ROC_TABLES_NWB  Stage or calculate single-unit ROC (AUC) tables for Figure 6 & S8.
%
%   fig6_roc_tables_nwb()
%   fig6_roc_tables_nwb(precomputedDir, outDir)
%   fig6_roc_tables_nwb(precomputedDir, outDir, mode, nwbDir)
%
% Modes:
%   'stage'     (default if precomputed archives exist) Unpacks and formats
%               precomputed 1000-bootstrap AUC tables into clean standard -v7 structs.
%   'recompute' Recomputes 1,000-bootstrap ROC AUC directly from .nwb ephys files.
%
% Inputs:
%   precomputedDir  folder containing 50msBin and 5msBin subfolders with
%                   Unit_AUC_20Hz_*_1000nBoot_150pvalueMin.mat
%   outDir          output folder (default: ...\NWBData\Data\Tables\ROC)
%   mode            'stage' or 'recompute'
%   nwbDir          folder containing M1 .nwb files

    if nargin < 1 || isempty(precomputedDir)
        precomputedDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'SeData\EphysPassiveStimSEs\SingleUnitAnalysis\Motor\ROC');
    end

    if nargin < 2 || isempty(outDir)
        outDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Data\Tables\ROC');
    end

    if nargin < 4 || isempty(nwbDir)
        nwbDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Data\ephys\M1');
    end

    file50ms = fullfile(precomputedDir, '50msBin', ...
        'Unit_AUC_20Hz_50msBin_-50to150ms_1000nBoot_150pvalueMin.mat');

    if nargin < 3 || isempty(mode)
        if exist(file50ms, 'file')
            mode = 'stage';
        else
            mode = 'recompute';
        end
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    switch lower(mode)
        case 'stage'
            local_stage_tables(precomputedDir, outDir);
        case 'recompute'
            local_recompute_from_nwb(nwbDir, outDir);
        otherwise
            error('Unknown mode: %s. Use ''stage'' or ''recompute''.', mode);
    end
end

% ========================================================================= %
%  Mode A: Stage precomputed tables into clean structs
% ========================================================================= %
function local_stage_tables(precomputedDir, outDir)
    % 50-ms bin data
    file50ms = fullfile(precomputedDir, '50msBin', ...
        'Unit_AUC_20Hz_50msBin_-50to150ms_1000nBoot_150pvalueMin.mat');
    if exist(file50ms, 'file')
        fprintf('Loading 50-ms ROC AUC table: %s\n', file50ms);
        loaded50 = load(file50ms);
        rocTable50ms = local_convert_auc_table(loaded50.AUC_table, 0.05, [-0.05, 0.15]);
        outMat50 = fullfile(outDir, 'fig6_roc_tables_M1_50ms.mat');
        save(outMat50, 'rocTable50ms', '-v7');
        fprintf('Wrote 50-ms ROC table -> %s (WT n=%d, KO n=%d)\n', ...
            outMat50, numel(rocTable50ms.WT), numel(rocTable50ms.KO));
    else
        warning('50-ms ROC file not found at: %s', file50ms);
    end

    % 5-ms bin data
    file5ms = fullfile(precomputedDir, '5msBin', ...
        'Unit_AUC_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin.mat');
    if exist(file5ms, 'file')
        fprintf('Loading 5-ms ROC AUC table: %s\n', file5ms);
        loaded5 = load(file5ms);
        rocTable5ms = local_convert_auc_table(loaded5.AUC_table, 0.005, [-0.05, 0.15]);
        outMat5 = fullfile(outDir, 'fig6_roc_tables_M1_5ms.mat');
        save(outMat5, 'rocTable5ms', '-v7');
        fprintf('Wrote 5-ms ROC table -> %s (WT n=%d, KO n=%d)\n', ...
            outMat5, numel(rocTable5ms.WT), numel(rocTable5ms.KO));
    else
        warning('5-ms ROC file not found at: %s', file5ms);
    end

    % Also export responsive units CSV for M1
    if exist('rocTable50ms', 'var')
        local_export_resp_csv(rocTable50ms, outDir);
    end

    fprintf('M1 ROC tables successfully staged to %s\n', outDir);
end

% ========================================================================= %
%  Mode B: Direct NWB recomputation
% ========================================================================= %
function local_recompute_from_nwb(nwbDir, outDir)
    % Recomputes ROC directly from NWB files using python engine
    pyScript = fullfile(fileparts(mfilename('fullpath')), 'fig6_roc_tables_nwb.py');
    csvFile = fullfile(outDir, 'responsive_units_M1.csv');
    cmd = sprintf('python "%s" --nwb-dir "%s" --resp-csv "%s" --out-dir "%s"', ...
        pyScript, nwbDir, csvFile, outDir);
    fprintf('Running direct NWB ROC calculation engine:\n%s\n', cmd);
    system(cmd);
end

% ========================================================================= %
%  Helper: unpack nested AUC_table into clean structs by genotype
% ========================================================================= %
function outStruct = local_convert_auc_table(aucTable, binSize, timeWindow)
    genotypes = {'WT', 'KO'};
    alphaVal = 0.05;
    nBoot = 1000;
    binNum = round((timeWindow(2) - timeWindow(1)) / binSize);
    time = (timeWindow(1) + binSize : binSize : timeWindow(2)) - binSize / 2;

    outStruct = struct();
    outStruct.binSize = binSize;
    outStruct.timeWindow = timeWindow;
    outStruct.binCenters = time;
    outStruct.nBins = binNum;

    for g = 1:numel(genotypes)
        geno = genotypes{g};
        isGeno = strcmp(aucTable.genotype, geno);
        subTable = aucTable(isGeno, :);

        % Pre-count responsive units across sessions to avoid dynamic array growth
        totalResponsiveUnits = 0;
        for rowInd = 1:height(subTable)
            sessUnits = subTable.AUC{rowInd};
            for uInd = 1:numel(sessUnits)
                if iscell(sessUnits{uInd})
                    totalResponsiveUnits = totalResponsiveUnits + 1;
                end
            end
        end

        unitList = cell(1, totalResponsiveUnits);
        mouseList = cell(1, totalResponsiveUnits);
        sessionList = cell(1, totalResponsiveUnits);
        unitIndexList = zeros(1, totalResponsiveUnits);

        currIdx = 0;
        for rowInd = 1:height(subTable)
            mName = subTable.mouseName{rowInd};
            sName = subTable.sessionName{rowInd};
            sessUnits = subTable.AUC{rowInd};
            for uInd = 1:numel(sessUnits)
                uData = sessUnits{uInd};
                if iscell(uData)
                    currIdx = currIdx + 1;
                    unitList{currIdx} = uData;
                    mouseList{currIdx} = mName;
                    sessionList{currIdx} = sName;
                    unitIndexList(currIdx) = uInd;
                end
            end
        end

        nUnits = totalResponsiveUnits;
        alphaBonferroni = alphaVal / nUnits;
        idxUp = ceil((1 - alphaBonferroni / 2) * nBoot);
        idxLow = ceil((alphaBonferroni / 2) * nBoot);

        unitRecords = struct(...
            'mouseName', cell(1, nUnits), ...
            'sessionName', cell(1, nUnits), ...
            'unitIndex', cell(1, nUnits), ...
            'genotype', cell(1, nUnits), ...
            'AUC_mean', cell(1, nUnits), ...
            'AUC_upCI', cell(1, nUnits), ...
            'AUC_lowCI', cell(1, nUnits), ...
            'isSignificant', cell(1, nUnits), ...
            'isConPref', cell(1, nUnits), ...
            'isIpsiPref', cell(1, nUnits), ...
            'AUC_boots', cell(1, nUnits));

        for u = 1:nUnits
            uData = unitList{u};
            aucMean = zeros(1, binNum);
            aucUp = zeros(1, binNum);
            aucLow = zeros(1, binNum);
            aucBoots = zeros(binNum, nBoot);

            for b = 1:binNum
                bData = uData{b, 1};
                aucBoots(b, :) = bData(:)';
                aucMean(b) = mean(bData);
                aucUp(b) = bData(idxUp);
                aucLow(b) = bData(idxLow);
            end

            isSig = (0.5 - aucUp) .* (0.5 - aucLow) > 0;
            isCon = aucMean > 0.5;
            isIpsi = aucMean < 0.5;

            unitRecords(u).mouseName = mouseList{u};
            unitRecords(u).sessionName = sessionList{u};
            unitRecords(u).unitIndex = unitIndexList(u);
            unitRecords(u).genotype = geno;
            unitRecords(u).AUC_mean = aucMean;
            unitRecords(u).AUC_upCI = aucUp;
            unitRecords(u).AUC_lowCI = aucLow;
            unitRecords(u).isSignificant = isSig;
            unitRecords(u).isConPref = isCon;
            unitRecords(u).isIpsiPref = isIpsi;
            unitRecords(u).AUC_boots = aucBoots;
        end

        outStruct.(geno) = unitRecords;
        outStruct.([geno '_alphaBonferroni']) = alphaBonferroni;
        outStruct.([geno '_nUnits']) = nUnits;
    end
end

% ========================================================================= %
%  Helper: export responsive units CSV
% ========================================================================= %
function local_export_resp_csv(rocTable50ms, outDir)
    csvPath = fullfile(outDir, 'responsive_units_M1.csv');
    fid = fopen(csvPath, 'w');
    if fid == -1
        return;
    end
    fprintf(fid, 'mouseName,sessionName,unitIndex,genotype\n');
    genotypes = {'WT', 'KO'};
    for g = 1:numel(genotypes)
        units = rocTable50ms.(genotypes{g});
        for u = 1:numel(units)
            fprintf(fid, '%s,%s,%d,%s\n', ...
                units(u).mouseName, units(u).sessionName, units(u).unitIndex, units(u).genotype);
        end
    end
    fclose(fid);
    fprintf('Wrote responsive units CSV -> %s\n', csvPath);
end
