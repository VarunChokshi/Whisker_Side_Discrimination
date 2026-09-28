% get folder to conver to png
figureFolder = MBrowse.Folder('K:\VC01_PursuitLicking\VC0105_DbhCre\Kilosort', 'Folder that has figures to be converted to png');

% check if all the figures in the folder to be converted
ifAll = false;

if ifAll
    figures = MBrowse.Dir2Table(figureFolder);
    figNames = cellfun(@(x) endsWith(x,'.fig'), figures.name);        
    
    figures(~figNames,:) = [];
else
    figures = MBrowse.Dir2Table(figureFolder);
    figures(1:2,:) = [];
    figNames = cellfun(@(x) endsWith(x,'.fig'), figures.name);
    files = figures(figNames,:);
    convertfig(files);
    figures(figNames,:) = [];
    figures(~figures.isdir, :) =[];
    
    % Select sessions for final output
    isSelected = false(height(figures), 1);
    
    fileNames =figures.name;
    
    selectedInd = listdlg('PromptString', 'Select figures to proceed: ', ...
        'SelectionMode', 'multi', ...
        'ListSize', [300 400], ...
        'ListString', fileNames);
    
    figures = figures(selectedInd, :); 

  for ii = 1:height(figures)

        figures2 = MBrowse.Dir2Table(fullfile(figures.folder{ii}, figures.name{ii}));
        figNames = cellfun(@(x) endsWith(x,'.fig'), figures2.name);    
        figures2 = figures2(figNames,:);
        convertfig(figures2);
    end

end


%% helper 
function convertfig(figures)
    for i = 1: height(figures)
        fileName = fullfile(figures.folder{i}, figures.name{i});
        close all;
        g = openfig(fileName);
        g.WindowState = 'Maximized';
        t = get(g, 'Position');
        fileNameRaw = erase(fileName, '.fig');
        saveas(g, [fileNameRaw '.png']);
    end
end
