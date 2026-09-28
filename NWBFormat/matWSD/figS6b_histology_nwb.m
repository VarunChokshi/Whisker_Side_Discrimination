function figS6b_histology_nwb(tablesDir, outDir)
% FIGS6B_HISTOLOGY_NWB  Figure S6B manuscript panel: Dorsal view of probe entry points in wM1.
%
%   figS6b_histology_nwb()
%   figS6b_histology_nwb(tablesDir, outDir)
%
% Produces:
%   - 'FigS6B - Dorsal view of probe entry points in wM1.pdf' and '.png'
%
% Styling strictly matches FinalFigS6.png Panel B and 'wM1 penetrations.pdf'.

    if nargin < 1 || isempty(tablesDir)
        tablesDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Data\Tables\Histology');
    end

    if nargin < 2 || isempty(outDir)
        outDir = fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1', ...
            'NWBData\Figures\Matlab\FigS6');
    end

    if ~exist(outDir, 'dir')
        mkdir(outDir);
    end

    tableMat = fullfile(tablesDir, 'figS6b_histology_M1.mat');
    if ~exist(tableMat, 'file')
        error('figS6b_histology_nwb:tableNotFound', ...
            'Histology table not found: %s. Run figS6b_histology_tables_nwb first.', tableMat);
    end

    data = load(tableMat);
    wt_ap = data.wt_ap;
    wt_ml = data.wt_ml;
    ko_ap = data.ko_ap;
    ko_ml = data.ko_ml;
    grid_lines = data.grid_lines;

    fig = figure('Color', 'w', 'Position', [100, 100, 420, 420], 'visible', 'off');
    ax = axes('Parent', fig, 'Position', [0.08, 0.08, 0.84, 0.84]);
    hold(ax, 'on');

    % 1. Plot horizontal stepped grid lines (grey)
    % grid_lines: [ap, ml_min, ml_max]
    gridColor = [0.65, 0.65, 0.65];
    for i = 1:size(grid_lines, 1)
        ap = grid_lines(i, 1);
        ml_min = grid_lines(i, 2);
        ml_max = grid_lines(i, 3);
        plot(ax, [ml_min, ml_max], [ap, ap], 'Color', gridColor, 'LineWidth', 1.0);
    end

    % 2. Plot vertical stepped grid lines (symmetrical across ML = 0)
    vlines = [
        0.0, 0.0, 4.2;  % midline
        0.5, 0.0, 4.0;
        1.0, 0.0, 3.0;
        1.5, 0.0, 2.5;
        2.0, 0.0, 2.0;
        2.5, 0.0, 1.0;
        3.0, 0.0, 0.5
    ];
    for i = 1:size(vlines, 1)
        ml = vlines(i, 1);
        ap_min = vlines(i, 2);
        ap_max = vlines(i, 3);
        if ml == 0
            plot(ax, [0, 0], [ap_min, ap_max], 'Color', gridColor, 'LineWidth', 1.0);
        else
            plot(ax, [ml, ml], [ap_min, ap_max], 'Color', gridColor, 'LineWidth', 1.0);
            plot(ax, [-ml, -ml], [ap_min, ap_max], 'Color', gridColor, 'LineWidth', 1.0);
        end
    end

    % 3. Main axes with arrows
    % Midline anterior arrow (AP axis pointing anteriorly)
    quiver(ax, 0, 0, 0, 4.5, 0, 'Color', 'k', 'LineWidth', 1.3, 'MaxHeadSize', 0.4);
    % Bregma horizontal line (AP = 0) with arrows at both ends
    plot(ax, [-3.8, 3.8], [0, 0], 'k-', 'LineWidth', 1.3);
    % Left arrowhead
    patch(ax, [-3.8, -3.5, -3.5], [0, 0.08, -0.08], 'k', 'EdgeColor', 'k');
    % Right arrowhead
    patch(ax, [3.8, 3.5, 3.5], [0, 0.08, -0.08], 'k', 'EdgeColor', 'k');

    % 4. Tick marks at -1 and +1 mm on Bregma horizontal line
    tickLen = 0.15;
    plot(ax, [-1, -1], [0, -tickLen], 'k-', 'LineWidth', 1.0);
    plot(ax, [1, 1], [0, -tickLen], 'k-', 'LineWidth', 1.0);

    % 5. Bregma point and label
    plot(ax, 0, 0, 'ro', 'MarkerFaceColor', 'r', 'MarkerSize', 6);
    text(ax, 0, -0.32, 'Bregma', 'Color', 'r', 'FontSize', 8.5, 'FontName', 'Arial', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
    text(ax, -1, -0.32, '-1', 'Color', 'k', 'FontSize', 8.5, 'FontName', 'Arial', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
    text(ax, 1, -0.32, '1', 'Color', 'k', 'FontSize', 8.5, 'FontName', 'Arial', ...
        'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');
    text(ax, 0, -0.85, 'Distance from Bregma (mm)', 'Color', 'k', 'FontSize', 9, ...
        'FontName', 'Arial', 'HorizontalAlignment', 'center', 'VerticalAlignment', 'top');

    % 6. WT and KO dots
    % WT: grey dots [0.5, 0.5, 0.5]
    plot(ax, wt_ml, wt_ap, 'o', 'MarkerEdgeColor', 'none', ...
        'MarkerFaceColor', [0.5, 0.5, 0.5], 'MarkerSize', 4.5);
    % KO: black dots [0, 0, 0]
    plot(ax, ko_ml, ko_ap, 'o', 'MarkerEdgeColor', 'none', ...
        'MarkerFaceColor', [0, 0, 0], 'MarkerSize', 4.5);

    % 7. Legend
    text(ax, 2.6, 3.2, 'WT', 'Color', [0.5, 0.5, 0.5], 'FontSize', 9.5, ...
        'FontName', 'Arial', 'FontWeight', 'bold');
    text(ax, 2.6, 2.7, 'KO', 'Color', 'k', 'FontSize', 9.5, ...
        'FontName', 'Arial', 'FontWeight', 'bold');

    % 8. Title
    title(ax, 'Dorsal view of probe entry points in wM1', 'FontName', 'Arial', ...
        'FontAngle', 'italic', 'FontSize', 10, 'FontWeight', 'normal');

    xlim(ax, [-4.3, 4.3]);
    ylim(ax, [-1.2, 4.8]);
    axis(ax, 'equal');
    axis(ax, 'off');

    local_export_fig(fig, fullfile(outDir, 'FigS6B - Dorsal view of probe entry points in wM1.pdf'));
    local_export_fig(fig, fullfile(outDir, 'FigS6B - Dorsal view of probe entry points in wM1.png'));
    close(fig);

    fprintf('FigS6B histology panel completed successfully in: %s\n', outDir);
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

