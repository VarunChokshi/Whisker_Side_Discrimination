function figS6b_histology_tables_nwb(dataDir, tablesDir)
% FIGS6B_HISTOLOGY_TABLES_NWB  Extracts and stages wM1 probe entry stereotaxic coordinates for Figure S6B.
%
%   figS6b_histology_tables_nwb()
%   figS6b_histology_tables_nwb(dataDir, tablesDir)
%
% Outputs:
%   - 'NWBData/Data/Tables/Histology/figS6b_histology_M1.mat'
%   - 'NWBData/Data/Tables/Histology/figS6b_histology_M1.json'
%
% Extracts the stereotaxic coordinates of 4-shank probe entry points for WT and KO mice
% relative to Bregma (0, 0) mm, along with the dorsal skull stepped grid coordinates.

    if nargin < 1 || isempty(dataDir)
        dataDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'SeData\EphysPassiveStimSEs\Histology');
    end

    if nargin < 2 || isempty(tablesDir)
        tablesDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Data\Tables\Histology');
    end

    if ~exist(tablesDir, 'dir')
        mkdir(tablesDir);
    end

    targetMat = fullfile(tablesDir, 'figS6b_histology_M1.mat');
    targetJson = fullfile(tablesDir, 'figS6b_histology_M1.json');

    figM1 = fullfile(dataDir, 'wM1 penetrations_WT vs KO.fig');

    if exist(figM1, 'file')
        fprintf('Extracting M1 histology coordinates from source .fig file...\n');
        
        hM1 = openfig(figM1, 'invisible');
        linesM1 = findobj(hM1, 'Type', 'Line');

        % KO lines: Color [1 0 0], Marker '*'
        koIdx = find(arrayfun(@(l) isequal(l.Color, [1, 0, 0]) && strcmp(l.Marker, '*'), linesM1));
        koRaw = zeros(length(koIdx), 3);
        for i = 1:length(koIdx)
            koRaw(i,:) = [linesM1(koIdx(i)).XData, linesM1(koIdx(i)).YData, linesM1(koIdx(i)).ZData];
        end

        % WT + Bregma lines: Color [1 1 1], Marker '*'
        wtIdx = find(arrayfun(@(l) isequal(l.Color, [1, 1, 1]) && strcmp(l.Marker, '*'), linesM1));
        wtRaw = zeros(length(wtIdx), 3);
        for i = 1:length(wtIdx)
            wtRaw(i,:) = [linesM1(wtIdx(i)).XData, linesM1(wtIdx(i)).YData, linesM1(wtIdx(i)).ZData];
        end
        close(hM1);

        % Separate WT penetrations from Bregma (540, 570, 0)
        isBregma = (wtRaw(:, 1) == 540 & wtRaw(:, 2) == 570);
        wt_pts = wtRaw(~isBregma, :);

        % Convert Allen CCF 10-um voxels to stereotaxic mm relative to Bregma:
        % Bregma in CCF is at X = 540, Y = 570.
        % AP (mm): anterior is positive -> -(X - 540) * 0.010
        % ML (mm): lateral is positive -> (Y - 570) * 0.010
        wt_ap = -(wt_pts(:, 1) - 540) * 0.010;
        wt_ml = (wt_pts(:, 2) - 570) * 0.010;

        ko_ap = -(koRaw(:, 1) - 540) * 0.010;
        ko_ml = (koRaw(:, 2) - 570) * 0.010;

        % Stepped dorsal skull grid lines: [ap, ml_min, ml_max]
        grid_lines = [
            0.0, -3.0, 3.0;
            0.5, -3.0, 3.0;
            1.0, -2.5, 2.5;
            1.5, -2.0, 2.0;
            2.0, -1.5, 1.5;
            2.5, -1.5, 1.5;
            3.0, -1.0, 1.0;
            3.5, -0.5, 0.5;
            4.0, -0.5, 0.5
        ];

        % Save MAT
        save(targetMat, 'wt_ap', 'wt_ml', 'ko_ap', 'ko_ml', 'grid_lines');

        % Save JSON for Python
        m1Struct = struct();
        m1Struct.wt_ap = wt_ap;
        m1Struct.wt_ml = wt_ml;
        m1Struct.ko_ap = ko_ap;
        m1Struct.ko_ml = ko_ml;
        m1Struct.grid_lines = grid_lines;

        fid = fopen(targetJson, 'w');
        fwrite(fid, jsonencode(m1Struct));
        fclose(fid);

        fprintf('Extracted and saved:\n');
        fprintf('  WT probe shank points: %d\n', length(wt_ap));
        fprintf('  KO probe shank points: %d\n', length(ko_ap));
        fprintf('  Grid lines: %d\n', size(grid_lines, 1));
        fprintf('  Saved to: %s\n', tablesDir);
    else
        if exist(targetMat, 'file') && exist(targetJson, 'file')
            fprintf('Source .fig file not found, but pre-staged files exist in: %s\n', tablesDir);
        else
            error('figS6b_histology_tables_nwb:missingFiles', ...
                'Source figure not found and target files do not exist.');
        end
    end
end

