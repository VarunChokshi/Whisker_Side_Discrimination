function figS4a_histology_tables_nwb(dataDir, tablesDir)
% FIGS4A_HISTOLOGY_TABLES_NWB  Extracts and stages wS1 CCF histology coordinates for Figure S4A.
%
%   figS4a_histology_tables_nwb()
%   figS4a_histology_tables_nwb(dataDir, tablesDir)
%
% Outputs:
%   - 'NWBData/Data/Tables/Histology/figS4a_histology_S1.mat'
%   - 'NWBData/Data/Tables/Histology/figS4a_histology_S1.json'
%
% Extracts the Allen mouse brain wireframe coordinates, Bregma midline coordinate,
% and wS1 unit 3D coordinates partitioned by preference (Contra, Ipsi, Bilateral)
% for both WT and KO mice.

    if nargin < 1 || isempty(dataDir)
        dataDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'SeData\EphysPassiveStimSEs\Figures\Bodyside8\allWins\AllUnitswS12_5\150');
    end

    if nargin < 2 || isempty(tablesDir)
        tablesDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Data\Tables\Histology');
    end

    if ~exist(tablesDir, 'dir')
        mkdir(tablesDir);
    end

    targetMat = fullfile(tablesDir, 'figS4a_histology_S1.mat');
    targetJson = fullfile(tablesDir, 'figS4a_histology_S1.json');

    figWT = fullfile(dataDir, 'allpvals = 1  genotype WT HistoplotCbias.fig');
    figKO = fullfile(dataDir, 'allpvals = 1  genotype KO HistoplotCbias.fig');

    if exist(figWT, 'file') && exist(figKO, 'file')
        fprintf('Extracting S1 histology coordinates from source .fig files...\n');
        
        % Process WT
        hWT = openfig(figWT, 'invisible');
        linesWT = findobj(hWT, 'Type', 'Line');
        wtContra = [];
        wtIpsi = [];
        wtBoth = [];
        wireframe = [];
        for i = 1:length(linesWT)
            l = linesWT(i);
            c = round(l.Color * 100) / 100;
            m = l.Marker;
            pts = [l.XData(:), l.YData(:), l.ZData(:)];
            if isequal(c, [1, 0, 0]) && strcmp(m, '.')
                wtContra = [wtContra; pts];
            elseif isequal(c, [0, 0, 1]) && strcmp(m, '.')
                wtIpsi = [wtIpsi; pts];
            elseif isequal(c, [1, 1, 1]) && strcmp(m, '.')
                wtBoth = [wtBoth; pts];
            elseif isequal(c, [0.7, 0.7, 0.7])
                wireframe = pts;
            end
        end
        close(hWT);

        % Process KO
        hKO = openfig(figKO, 'invisible');
        linesKO = findobj(hKO, 'Type', 'Line');
        koContra = [];
        koIpsi = [];
        koBoth = [];
        for i = 1:length(linesKO)
            l = linesKO(i);
            c = round(l.Color * 100) / 100;
            m = l.Marker;
            pts = [l.XData(:), l.YData(:), l.ZData(:)];
            if isequal(c, [1, 0, 0]) && strcmp(m, '.')
                koContra = [koContra; pts];
            elseif isequal(c, [0, 0, 1]) && strcmp(m, '.')
                koIpsi = [koIpsi; pts];
            elseif isequal(c, [1, 1, 1]) && strcmp(m, '.')
                koBoth = [koBoth; pts];
            end
        end
        close(hKO);

        bregma = [540, 570, 0];

        % Save MAT
        save(targetMat, 'wireframe', 'bregma', ...
            'wtContra', 'wtIpsi', 'wtBoth', ...
            'koContra', 'koIpsi', 'koBoth');

        % Save JSON for Python pipeline
        s1Struct = struct();
        s1Struct.bregma = bregma;
        s1Struct.wt_contra = wtContra;
        s1Struct.wt_ipsi = wtIpsi;
        s1Struct.wt_both = wtBoth;
        s1Struct.ko_contra = koContra;
        s1Struct.ko_ipsi = koIpsi;
        s1Struct.ko_both = koBoth;
        s1Struct.wireframe = wireframe;

        fid = fopen(targetJson, 'w');
        fwrite(fid, jsonencode(s1Struct));
        fclose(fid);

        fprintf('Extracted and saved:\n');
        fprintf('  WT: Contra=%d, Ipsi=%d, Both=%d (Total=%d)\n', ...
            size(wtContra, 1), size(wtIpsi, 1), size(wtBoth, 1), ...
            size(wtContra, 1) + size(wtIpsi, 1) + size(wtBoth, 1));
        fprintf('  KO: Contra=%d, Ipsi=%d, Both=%d (Total=%d)\n', ...
            size(koContra, 1), size(koIpsi, 1), size(koBoth, 1), ...
            size(koContra, 1) + size(koIpsi, 1) + size(koBoth, 1));
        fprintf('  Wireframe points: %d\n', size(wireframe, 1));
        fprintf('  Saved to: %s\n', tablesDir);
    else
        if exist(targetMat, 'file') && exist(targetJson, 'file')
            fprintf('Source .fig files not found, but pre-staged files exist in: %s\n', tablesDir);
        else
            error('figS4a_histology_tables_nwb:missingFiles', ...
                'Source figures not found and target files do not exist.');
        end
    end
end

