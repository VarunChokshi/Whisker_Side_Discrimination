function figS4a_histology_nwb(tablesDir, outDir)
% FIGS4A_HISTOLOGY_NWB  Figure S4A manuscript panel: 3D reconstructed wS1 unit CCF locations (WT and KO).
%
%   figS4a_histology_nwb()
%   figS4a_histology_nwb(tablesDir, outDir)
%
% Produces:
%   - 'FigS4A - Whisker preference in wS1.pdf' and '.png' (2-panel stacked)
%   - 'FigS4A - Whisker preference in wS1 (WT).pdf' and '.png'
%   - 'FigS4A - Whisker preference in wS1 (KO).pdf' and '.png'
%
% Styling strictly matches FinalFigS4.png Panel A.

    if nargin < 1 || isempty(tablesDir)
        tablesDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Data\Tables\Histology');
    end

    if nargin < 2 || isempty(outDir)
        outDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Figures\Matlab\FigS3_FigS4');
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    tableMat = fullfile(tablesDir, 'figS4a_histology_S1.mat');
    if ~exist(tableMat, 'file')
        error('figS4a_histology_nwb:tableNotFound', ...
            'Histology table not found: %s. Run figS4a_histology_tables_nwb first.', tableMat);
    end

    data = load(tableMat);
    wireframe = data.wireframe;
    wtContra = data.wtContra;
    wtIpsi = data.wtIpsi;
    wtBoth = data.wtBoth;
    koContra = data.koContra;
    koIpsi = data.koIpsi;
    koBoth = data.koBoth;

    % ===================================================================== %
    %  Composite 2-Panel Figure S4A (WT top, KO bottom)
    % ===================================================================== %
    figComp = figure('Color', 'w', 'Position', [100, 100, 360, 520], 'visible', 'off');

    % --- Panel 1: WT ---
    axWT = axes('Parent', figComp, 'Position', [0.06, 0.53, 0.88, 0.40]);
    local_plot_s1_panel(axWT, wireframe, wtContra, wtIpsi, wtBoth, 'WT');

    % --- Panel 2: KO ---
    axKO = axes('Parent', figComp, 'Position', [0.06, 0.06, 0.88, 0.40]);
    local_plot_s1_panel(axKO, wireframe, koContra, koIpsi, koBoth, 'KO');

    % Add title above
    annotation(figComp, 'textbox', [0.04, 0.94, 0.92, 0.05], ...
        'String', 'Whisker preference in wS1', 'EdgeColor', 'none', ...
        'FontName', 'Arial', 'FontSize', 10, 'FontWeight', 'bold', 'FontAngle', 'italic');

    local_export_fig(figComp, fullfile(outDir, 'FigS4A - Whisker preference in wS1.pdf'));
    local_export_fig(figComp, fullfile(outDir, 'FigS4A - Whisker preference in wS1.png'));
    close(figComp);

    % ===================================================================== %
    %  Individual Panel: WT
    % ===================================================================== %
    figWT = figure('Color', 'w', 'Position', [100, 100, 360, 290], 'visible', 'off');
    axSingleWT = axes('Parent', figWT, 'Position', [0.06, 0.10, 0.88, 0.80]);
    local_plot_s1_panel(axSingleWT, wireframe, wtContra, wtIpsi, wtBoth, 'WT');
    local_export_fig(figWT, fullfile(outDir, 'FigS4A - Whisker preference in wS1 (WT).pdf'));
    local_export_fig(figWT, fullfile(outDir, 'FigS4A - Whisker preference in wS1 (WT).png'));
    close(figWT);

    % ===================================================================== %
    %  Individual Panel: KO
    % ===================================================================== %
    figKO = figure('Color', 'w', 'Position', [100, 100, 360, 290], 'visible', 'off');
    axSingleKO = axes('Parent', figKO, 'Position', [0.06, 0.10, 0.88, 0.80]);
    local_plot_s1_panel(axSingleKO, wireframe, koContra, koIpsi, koBoth, 'KO');
    local_export_fig(figKO, fullfile(outDir, 'FigS4A - Whisker preference in wS1 (KO).pdf'));
    local_export_fig(figKO, fullfile(outDir, 'FigS4A - Whisker preference in wS1 (KO).png'));
    close(figKO);

    fprintf('FigS4A histology panels completed successfully in: %s\n', outDir);
end

% ========================================================================= %
%  Helper: plot single S1 panel
% ========================================================================= %
function local_plot_s1_panel(ax, wireframe, contraPts, ipsiPts, bothPts, genotype)
    hold(ax, 'on');

    % Fill black background rectangle
    fill(ax, [-15, 510, 510, -15], [-15, -15, 470, 470], 'k', 'EdgeColor', 'none');

    % 1. Brain mesh wireframe (coronal projection: x = 570 - Y, y = Z)
    xWire = 570.0 - wireframe(:, 2);
    yWire = wireframe(:, 3);
    bad = (xWire < -15 | xWire > 510 | yWire < -15 | yWire > 470);
    xWire(bad) = NaN;
    yWire(bad) = NaN;
    plot(ax, xWire, yWire, 'Color', [0.6, 0.6, 0.6, 0.35], 'LineWidth', 0.5);

    % 2. Units plotted as filled dots
    % Contralateral: red [1, 0, 0]
    scatter(ax, 570.0 - contraPts(:, 2), contraPts(:, 3), 16, [1, 0, 0], 'filled');
    % Ipsilateral: blue [0, 0, 1]
    scatter(ax, 570.0 - ipsiPts(:, 2), ipsiPts(:, 3), 16, [0, 0, 1], 'filled');
    % Bilateral: white [1, 1, 1]
    scatter(ax, 570.0 - bothPts(:, 2), bothPts(:, 3), 16, [1, 1, 1], 'filled');

    % 3. Bregma midline asterisk at (0, 0)
    plot(ax, 0, 0, 'r*', 'MarkerSize', 10, 'LineWidth', 1.5);

    % 4. Axis limits and properties
    xlim(ax, [-15, 510]);
    ylim(ax, [-15, 470]);
    set(ax, 'YDir', 'reverse');
    axis(ax, 'equal');
    axis(ax, 'off');

    % 5. Annotations
    if strcmp(genotype, 'WT')
        % Labels outside black box
        text(ax, -10, -35, 'Frontal view', 'Color', 'k', ...
            'FontSize', 8.5, 'FontName', 'Arial', 'Clipping', 'off');
        text(ax, 250, -35, 'WT', 'Color', [0.5, 0.5, 0.5], ...
            'FontSize', 9.5, 'FontName', 'Arial', 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', 'Clipping', 'off');
        text(ax, 490, -35, 'Preference:', 'Color', 'k', ...
            'FontSize', 8.5, 'FontName', 'Arial', ...
            'HorizontalAlignment', 'right', 'Clipping', 'off');

        % Preference legend inside black box (top right)
        text(ax, 490, 30, 'Contra', 'Color', [1, 0, 0], ...
            'FontSize', 8, 'FontName', 'Arial', 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
        text(ax, 490, 55, 'Ipsi', 'Color', [0, 0, 1], ...
            'FontSize', 8, 'FontName', 'Arial', 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
        text(ax, 490, 80, 'Bilateral', 'Color', [1, 1, 1], ...
            'FontSize', 8, 'FontName', 'Arial', 'FontWeight', 'bold', 'HorizontalAlignment', 'right');
    else
        % KO Label outside black box
        text(ax, 250, -35, 'KO', 'Color', 'k', ...
            'FontSize', 9.5, 'FontName', 'Arial', 'FontWeight', 'bold', ...
            'HorizontalAlignment', 'center', 'Clipping', 'off');

        % Coordinate arrows: Dorsal & Lateral
        quiver(ax, 370, 150, 0, -50, 0, 'Color', 'w', 'LineWidth', 1.2, 'MaxHeadSize', 0.8);
        quiver(ax, 370, 150, 50, 0, 0, 'Color', 'w', 'LineWidth', 1.2, 'MaxHeadSize', 0.8);
        text(ax, 370, 90, 'Dorsal', 'Color', 'w', ...
            'FontSize', 8, 'FontName', 'Arial', 'HorizontalAlignment', 'center');
        text(ax, 425, 175, 'Lateral', 'Color', 'w', ...
            'FontSize', 8, 'FontName', 'Arial', 'HorizontalAlignment', 'center');

        % Scale bar: 0.5 mm = 50 CCF voxels
        plot(ax, [370, 420], [440, 440], 'w-', 'LineWidth', 2.0);
        text(ax, 395, 460, '0.5 mm', 'Color', 'w', ...
            'FontSize', 8, 'FontName', 'Arial', 'HorizontalAlignment', 'center');
    end
end

% ========================================================================= %
%  Helper: safe export
% ========================================================================= %
function local_export_fig(figHandle, targetPath)
    try
        exportgraphics(figHandle, targetPath, 'Resolution', 300);
    catch ME
        if contains(ME.message, 'Permission denied', 'IgnoreCase', true)
            [p, n, e] = fileparts(targetPath);
            altPath = fullfile(p, [n '_new' e]);
            exportgraphics(figHandle, altPath, 'Resolution', 300);
        else
            rethrow(ME);
        end
    end
end
