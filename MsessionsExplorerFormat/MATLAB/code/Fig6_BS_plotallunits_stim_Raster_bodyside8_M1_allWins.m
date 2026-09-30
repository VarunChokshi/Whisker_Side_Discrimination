


%% Plot units separated by whisker stim duration. Contra vs ipsi, combine for left vs right hemisphere recording . combine plotsession_maps
% It also has LFPs
% Stims are taken as only the first deflection of all frequencies 
% clear all
% 
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\StimSEs', 'Select source SEs');

clear all
animalID = {'VC030209', 'VC030208','VC030113', 'VC030211', 'VC030114', 'VC030115', 'VC030213'};
% animalID = {'VC030208'};
% Choose a group folder
rootDir = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\SeData';
rootInfo = MUtil.Dir2Table(rootDir);
rootInfo(~rootInfo.isdir,:) = [];
rootInfo(1:2,:) = [];
groupDirs = cellfun(@fullfile, rootInfo.folder, rootInfo.name, 'Uni', false);

selectedIdx = listdlg('PromptString', 'Select sessions to proceed: ', ...
    'ListSize', [300 400], ...
    'ListString', groupDirs);

if ~isempty(selectedIdx)
    groupDir = groupDirs{selectedIdx};
else
    groupDir = MBrowse.Folder(rootDir, 'Select the group folder');
end

if ~groupDir
    return;
end

clear groupDirs selectedIdx


% Find content of the group folder and pertinent subforders
groupDirInfo = MUtil.Dir2Table(groupDir);
behavDirInfo = [];


for i = 1 : height(groupDirInfo)
    switch groupDirInfo.name{i}
        case 'StimSEs_wM1'          
            behavDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}));
            seNames = cellfun(@(x) endsWith(x,'enriched.mat'),behavDirInfo.name);            
            behavDirInfo(~seNames,:) = [];
            animalNames = cellfun(@(x) strsplit(x, ' '), behavDirInfo.name, 'UniformOutput', false);
            animalNames = cellfun(@(x) x{1}, animalNames, 'UniformOutput',false);
            behavDirInfo(~ismember(animalNames, animalID),:) = [];

           
        case 'StimInfo'
            sessInfoDirInfo = MBrowse.Dir2Table(fullfile(groupDirInfo.folder{i}, groupDirInfo.name{i}, '*.csv'));               
            animalNames= cellfun(@(x) strsplit(x, '_'), sessInfoDirInfo.name, 'UniformOutput', false);
            animalNames = cellfun(@(x) x{1}, animalNames, 'UniformOutput',false);
            sessInfoDirInfo(~ismember(animalNames, animalID),:) = [];
        
    end
end




% Find all data files for each session
dataFileTb = table();

for i = height(behavDirInfo) : -1 : 1
    % Parse the file name of SatellitesViewer log to get session identifiers
    behavNameParts = strsplit(behavDirInfo.name{i}, {' ', '.'});
    animalId = behavNameParts{1};
    if ~ismember(animalId, animalID)
        continue
    end
    sessionDatetime = datetime(behavNameParts{2}(1:end-1), ...
        'Format', 'yyyy-MM-dd');
    subId = behavNameParts{2}(end);
    
    
    dataFileTb.animalId{i} = animalId;
    dataFileTb.sessionDatetime(i) = sessionDatetime;
    dataFileTb.subId{i} = subId;
    
    % Add bControl log file path
    dataFileTb.sePath{i} = fullfile(behavDirInfo.folder{i}, behavDirInfo.name{i});
    
    % Add sessInfo to data Table
    dataFileTb.sessInfoPaths{i} = [];
    if ~isempty(sessInfoDirInfo)
        queryStr = ['^' animalId '.+'];
        isHit = ~cellfun(@isempty, regexpi(sessInfoDirInfo.name, queryStr));
        if any(isHit)
            dataFileTb.sessInfoPaths{i} = fullfile(sessInfoDirInfo.folder{isHit}, sessInfoDirInfo.name{isHit});
        end            
    end
    
    seshInfoTb = readtable(dataFileTb.sessInfoPaths{i}); 
    seshInfoTb.seshDate = arrayfun(@(x) datetime(x, 'InputFormat','yyMMdd', ...
        'Format', 'yyyy-MM-dd'), string(seshInfoTb.seshDate), 'UniformOutput', false); 
    
    ind = ismember(cellfun(@datenum, seshInfoTb.seshDate), datenum(dataFileTb.sessionDatetime(i))) & subId == cell2mat(seshInfoTb.subId);
    seshInfoTb = seshInfoTb(ind,:);     
    dataFileTb(i,seshInfoTb.Properties.VariableNames) = seshInfoTb;
end



    
% Select sessions for final output
dataFileTb.isSelected = false(height(dataFileTb), 1);

sessionFullName = cellfun(@(x,y,z) strtrim([x ' ' datestr(y, 'yyyy-mm-dd') ' ' z]), ...
    dataFileTb.animalId, ...
    num2cell(dataFileTb.sessionDatetime), ...
    dataFileTb.subId, ...
    'Uni', false);

selectedInd = listdlg('PromptString', 'Select sessions to proceed: ', ...
    'SelectionMode', 'multi', ...
    'ListSize', [300 400], ...
    'ListString', sessionFullName);

dataFileTb.isSelected(selectedInd) = true;
dataFileTb(~dataFileTb.isSelected,:) =[];

%%
% load histology_wM1
histTable = readtable('G:\VC03_RoboKO\EphysPassiveStimSEs\Histology\Histology_wM1.csv');





parfor i = 1:height(dataFileTb)
    animalName = dataFileTb.animalId{i};
    sessID = [datestr(dataFileTb.sessionDatetime(i), 'yymmdd') dataFileTb.subId{i}];
    sessNum = find(ismember(histTable.AnimalName,animalName) & ismember(histTable.SessDate,sessID));
    save_folder = fullfile('G:\VC03_RoboKO\EphysPassiveStimSEs\Histology', animalName, 'wM1_16x\Processed');
    % find animal and session in the histology table
    
    object_save_name_suffix = ['NP24_' histTable.ProbeSuffix{sessNum}];
    probeDistFilePath = fullfile(save_folder, [object_save_name_suffix '_ProbeDist.mat']);

       % load probe points
    if isfile(probeDistFilePath)
       % load se    
        se{i} = loadsess(dataFileTb.sePath{i}); 
        
       
        
        BT = load(probeDistFilePath);
        BT = BT.BT;
        shankDepth{i} = [];
        for probeNums = 1:4
            alldepths = [BT{probeNums}.upperBorder];
            shankDepth{i}(probeNums) = alldepths(end);
            
        end

        se{i}.userData.sessionInfo.histology = shankDepth{i};

        savesess(dataFileTb.sePath{i},se{i});

    end

end




%% Add channel coords where kcoords are the shank #
% Computing spike rate


% load histology_wM1
histTable = readtable(fullfile(groupDir, 'Histology\Histology_wM1.csv'));


% directory of reference atlas files
annotation_volume_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\annotation_volume_10um_by_index.npy';
structure_tree_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\structure_tree_safe_2017.csv';
template_volume_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\template_volume_10um.npy';

probes_to_analyze = 'all';  % [1 2]
% distance queried for confidence metric -- in um
probe_radius = 200; 

% overlay the distance between parent regions in gray (this takes a while)
show_parent_category = false; 

% plot this far or to the bottom of the brain, whichever is shorter -- in mm
distance_past_tip_to_plot = 0.0;

% plane used to view when points were clicked ('coronal' -- most common, 'sagittal', 'transverse')
plane = 'coronal';

% probe insertion direction 'down' (i.e. from the dorsal surface, downward -- most common!) 
% or 'up' (from a ventral surface, upward)
probe_insertion_direction = 'down';

% set scaling e.g. based on lining up the ephys with the atlas
% set to *false* to get scaling automatically from the clicked points
scaling_factor = false;

% show a table of regions that the probe goes through, in the console
show_region_table = false;
      
% black brain?
black_brain = true;



% GET AND PLOT PROBE VECTOR IN ATLAS SPACE

% load the reference brain annotations
if ~exist('av','var') || ~exist('st','var')
    disp('loading reference atlas...')
    av = readNPY(annotation_volume_location);
    st = loadStructureTree(structure_tree_location);
end

% select the plane for the viewer
if strcmp(plane,'coronal')
    av_plot = av;
elseif strcmp(plane,'sagittal')
    av_plot = permute(av,[3 2 1]);
elseif strcmp(plane,'transverse')
    av_plot = permute(av,[2 3 1]);
end


    
    % convert error radius into mm
error_length = round(probe_radius / 10);
    



close all

fwireframe = [];


% create a new figure with wireframe
fwireframe = plotBrainGrid([], [], fwireframe, black_brain);
fwireframe.WindowState='Maximized';
hold on; 
fwireframe.InvertHardcopy = 'off';
bregma = allenCCFbregma(); % bregma position in reference data space
atlas_resolution = 0.010; % mm
bregma_res = bregma*atlas_resolution;


figure(fwireframe);
plot3(bregma(1),bregma(3),bregma(2), '*', 'color',[1 0 0],'markers',5);


probeLocationsEucl = {};
for i = 1:height(dataFileTb)    
    animalName = dataFileTb.animalId{i};
    sessID = [datestr(dataFileTb.sessionDatetime(i), 'yymmdd') dataFileTb.subId{i}];
    sessNum = find(ismember(histTable.AnimalName,animalName) & ismember(histTable.SessDate,sessID));
    save_folder = fullfile('G:\VC03_RoboKO\EphysPassiveStimSEs\Histology', animalName, 'wM1_16x\Processed');
    % find animal and session in the histology table

    object_save_name_suffix = ['NP24_' histTable.ProbeSuffix{sessNum}];
    probeFilePath = fullfile(save_folder, ['probe_points' object_save_name_suffix '.mat']);
    probeFile = fullfile(save_folder, ['probe_points' object_save_name_suffix]);

    
  %

    % load probe points
    if isfile(probeFilePath)
        % load se    
        se{i} = loadsess(dataFileTb.sePath{i}); 
        %
        
        if ~ismember({'zRate'}, se{i}.tot.Properties.RowNames)
            BS.SE.AddZscoreRateTable(se{i});
        end
        
        se{i}.userData.spikeInfo.chanMap = se{i}.userData.sessionInfo.chanmap;

        ycoords = se{i}.userData.spikeInfo.chanMap.ycoords;
        xcoords = se{i}.userData.spikeInfo.chanMap.xcoords;
        kcoords = se{i}.userData.spikeInfo.chanMap.kcoords;

        probePoints = load(probeFile);
        ProbeColors = .75*[1.3 1.3 1.3; 1 .75 0;  .3 1 1; .4 .6 .2; 1 .35 .65; .7 .7 .9; .65 .4 .25; .7 .95 .3; .7 0 0; .6 0 .7; 1 .6 0]; 
        % order of colors: {'white','gold','turquoise','fern','bubble gum','overcast sky','rawhide', 'green apple','purple','orange','red'};
                
       
        % determine which probes to analyze
        if strcmp(probes_to_analyze,'all')
            probes = 1:size(probePoints.pointList.pointList,1);
        else
            probes = probes_to_analyze;
        end 
        roi_table{i} = {};

        for selected_probe = probes
            
            % get the probe points for the currently analyzed probe 
            if strcmp(plane,'coronal')
                curr_probePoints = probePoints.pointList.pointList{selected_probe,1}(:, [3 2 1]);
            elseif strcmp(plane,'sagittal')
                curr_probePoints = probePoints.pointList.pointList{selected_probe,1}(:, [1 2 3]);
            elseif strcmp(plane,'transverse')
                curr_probePoints = probePoints.pointList.pointList{selected_probe,1}(:, [1 3 2]);
            end
            
            
            probe_lengths = histTable.PenetrationDepth(sessNum)/1000;
    
            % get user-defined probe length from experiment
            if length(probe_lengths) > 1
                probe_length = probe_lengths(selected_probe);
            else
                probe_length = probe_lengths;
            end
            
            % get the scaling-factor method to use
            if scaling_factor
                use_tip_to_get_reference_probe_length = false;
                reference_probe_length = probe_length * scaling_factor;
                disp(['probe scaling of ' num2str(scaling_factor) ' determined by user input']);    
            else
                use_tip_to_get_reference_probe_length = true;
                disp(['getting probe scaling from histology data...']);
            end
            
            % get line of best fit through points
            % m is the mean value of each dimension; p is the eigenvector for largest eigenvalue
            [m,p,s] = best_fit_line(curr_probePoints(:,1), curr_probePoints(:,2), curr_probePoints(:,3));
            if isnan(m(1))
                disp(['no points found for probe ' num2str(selected_probe)])
                continue
            end
            
            % ensure proper orientation: want 0 at the top of the brain and positive distance goes down into the brain
            if p(2)<0
                p = -p;
            end
            
            % determine "origin" at top of brain -- step upwards along tract direction until tip of brain / past cortex
            ann = 10;
            out_of_brain = false;
            while ~(ann==1 && out_of_brain) % && distance_stepped > .5*active_probe_length)
                m = m-p; % step 10um, backwards up the track
                ann = av(round(m(1)),round(m(2)),round(m(3))); %until hitting the top
                if strcmp(st.safe_name(ann), 'root')
                    % make sure this isn't just a 'root' area within the brain
                    m_further_up = m - p*20; % is there more brain 200 microns up along the track?
                    ann_further_up = av(round(max(1,m_further_up(1))),round(max(1,m_further_up(2))),round(max(1,m_further_up(3))));
                    if strcmp(st.safe_name(ann_further_up), 'root')
                        out_of_brain = true;
                    end
                end
            end
            
        
        
        if use_tip_to_get_reference_probe_length
            % find length of probe in reference atlas space
            if strcmp(probe_insertion_direction, 'down')
                [depth, tip_index] = max(curr_probePoints(:,2));
            elseif strcmp(probe_insertion_direction, 'up')
                [depth, tip_index] = min(curr_probePoints(:,2));    
            end
            reference_probe_length_tip = sqrt(sum((curr_probePoints(tip_index,:) - m).^2)); 
            
            % and the corresponding scaling factor
            shrinkage_factor = (reference_probe_length_tip / 100) / probe_length;
            
            % display the scaling
            disp(['probe length of ' num2str(reference_probe_length_tip/100) ' mm in reference atlas space compared to a reported ' num2str(probe_length) ' mm']);
            disp(['probe scaling of ' num2str(shrinkage_factor)]); disp(' ');
            
            % plot line the length of the probe in reference space
            probe_length_histo = round(reference_probe_length_tip);
            
        % if scaling_factor is user-defined as some number, use it to plot the length of the probe
        else 
            probe_length_histo = round(reference_probe_length * 100); 
        end
        se{i}.userData.histology.probeEntry(selected_probe,:) = m;
        se{i}.userData.histology.probeEigen(selected_probe,:) = p;
        se{i}.userData.histology.probeDepth(selected_probe,:) = probe_length_histo*10; % in um

        
        % find the percent of the probe occupied by electrodes
        % find ycoords on the current kcoords(shank)
        activeYcoords = ycoords(ismember(kcoords, selected_probe));

        active_probe_length = max(activeYcoords)- min(activeYcoords);
        percent_of_tract_with_active_sites = min([active_probe_length / (probe_length*100), 1.0]);
        
        active_site_start = probe_length_histo- min(activeYcoords)/10;

        active_probe_position = round([active_site_start  active_site_start-active_probe_length/10]);
        



        % x,y,z are n x 1 column vectors of the three coordinates
        % of a set of n points in three dimensions. The best line,
        % in the minimum mean square orthogonal distance sense,
        % will pass through m and have direction cosines in p, so
        % it can be expressed parametrically as x = m(1) + p(1)*t,
        % y = m(2) + p(2)*t, and z = m(3)+p(3)*t, where t is the
        % distance along the line from the mean point at m.
        % s returns with the minimum mean square orthogonal
        % distance to the line.
        % RAS - March 14, 2005

        t = probe_length_histo-activeYcoords/10;
        probeLocations{i}(:,1:3) = [round(m(1)+p(1)*(t)), round(m(2)+p(2)*(t)), round(m(3)+p(3)*(t))]*10;

        ap = -(probeLocations{i}(:,1)/10-bregma(1))*atlas_resolution;
        dv = (probeLocations{i}(:,2)/10-bregma(2))*atlas_resolution;
        ml = (probeLocations{i}(:,3)/10-bregma(3))*atlas_resolution;
        

        probeLocationsEucl{i}(:, 1:3) = [ap, dv, ml];
        roi_location_curr = probeLocationsEucl{i}(:, 1:3);

        % initialize array of region annotations
        roi_annotation_curr = cell(size(probeLocations{i},1),3);    
        
        % loop through every point to get ROI locations and region annotations
        for point = 1:size(probeLocations{i},1)
    
            % find the annotation, name, and acronym of the current ROI pixel
            ann = av(probeLocations{i}(point,1)/10,probeLocations{i}(point,2)/10,probeLocations{i}(point,3)/10);
            name = st.safe_name{ann};
            acr = st.acronym{ann};
    
            roi_annotation_curr{point,1} = ann;
            roi_annotation_curr{point,2} = name;
            roi_annotation_curr{point,3} = acr;
    
        end
    
        % save results in cell array
        if length(probes) > 1
            roi_annotation{selected_probe} = roi_annotation_curr;
            roi_location{selected_probe} = roi_location_curr;
        else
            roi_annotation = roi_annotation_curr;
            roi_location = roi_location_curr;
        end
     
        % display results in a table
        disp(['Clicked points for object ' num2str(selected_probe)])
        roi_table{i}{selected_probe}= table(roi_annotation_curr(:,2),roi_annotation_curr(:,3), ...
                            roi_location_curr(:,1),roi_location_curr(:,2),roi_location_curr(:,3), roi_annotation_curr(:,1), ...
             'VariableNames', {'name', 'acronym', 'AP_location', 'DV_location', 'ML_location', 'avIndex'});

        
        

         % plot line the length of the active probe sites in reference space
%         plot3(m(1)+p(1)*[active_probe_position(1) active_probe_position(2)], m(3)+p(3)*[active_probe_position(1) active_probe_position(2)], m(2)+p(2)*[active_probe_position(1) active_probe_position(2)], ...
%             'Color', ProbeColors(selected_probe,:), 'LineWidth', 1);
%         % plot line the length of the entire probe in reference space
%         plot3(m(1)+p(1)*[1 probe_length_histo], m(3)+p(3)*[1 probe_length_histo], m(2)+p(2)*[1 probe_length_histo], ...
%             'Color', ProbeColors(selected_probe,:), 'LineWidth', 1, 'LineStyle',':');

       
        
        end

        se{i}.userData.spikeInfo.channelHistoMap = roi_table{i};
        
       unitChannels= se{i}.userData.spikeInfo.unit_channel_ind;
       probeLocations = {};

       % find significant units only

        unitRoiTable{i} = table();
        for unitNum = 1:numel(unitChannels)

            % find shank form kcoord and then find the ycoord on that
            % channel on that shank
            unitChannel = unitChannels(unitNum);
            shankNum = kcoords(unitChannel);
            shankYcoords= ycoords(ismember(kcoords, kcoords(unitChannel)));   
            shankXcoords= xcoords(ismember(kcoords, kcoords(unitChannel)));
            roiTableRow = find(shankYcoords== ycoords(unitChannel) & shankXcoords== xcoords(unitChannel));
            unitRoiTable{i}(unitNum,:) = roi_table{i}{kcoords(unitChannel)}(roiTableRow, :);
            
            ap = roi_table{i}{kcoords(unitChannel)}{roiTableRow, 'AP_location'};
            dv = roi_table{i}{kcoords(unitChannel)}{roiTableRow, 'DV_location'};
            ml = roi_table{i}{kcoords(unitChannel)}{roiTableRow, 'ML_location'};
            unitEucl = [ap dv ml]/atlas_resolution;
            
           m = se{i}.userData.histology.probeEntry(shankNum,:);
           p = se{i}.userData.histology.probeEigen(shankNum,:);    

           depth = se{i}.userData.histology.probeDepth(shankNum,:);
           probe_length_histo = depth/10;


            unit_ycoord = probe_length_histo-shankYcoords(roiTableRow)/10;
    
            active_probe_position = round([active_site_start  active_site_start-active_probe_length/10]);

            
            figure(fwireframe)
            hold on

            plot3(bregma(1) - unitEucl(1), bregma(3) + unitEucl(3),bregma(2) + unitEucl(2), ...
                'w.', 'LineWidth', 1);
            
%             
            

        end


    end
end



%% Region specific window (wM1~250ms)

% clearvars -except dataFileTb groupDir
ops.trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
ops.trials{2} = {'Stim_Som_Left', 'Stim_Som_Left_Opto', 'Stim_Som_Right', 'Stim_Som_Right_Opto'}; 
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\behavSEs', 'Select source SEs');
% clearvars -except readPaths seDir seNames animalID trials;
% readPathParts = cellfun(@(x) strsplit(x, '\'), readPaths, 'UniformOutput', false);
% animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
% ops.adcPlot = load('G:\VC03_RoboKO\VC0301\Figures\MeetingUpdate230124\adcPlot.mat');
% ops.adcPlot = ops.adcPlot.adcPlot;
% Plot using FRrate in ses

ops.redo =0;
ops.numcyc = 3;
ops.constantWindow = 0.3; 
ops.windows = [0.025,0.04, 0.05, 0.075,0.1,0.15,0.2,0.3];
ops.WindowNames = {'25', '40', '50' '75', '100', '150', '200', '300'};
FRbin = '2_5';
ops.recSites = {'S1', 'M1'};
ops.defPenetrationDepth = 1300;
% ops.PlotSigma = 0.001;
ops.statAlpha = 0.01;
ops.plotAlpha = ops.statAlpha;
if ops.plotAlpha <0.99
    ops.allpvals = 1;
else
    ops.allpvals = 0;
end

ops.binSize = 0.0025;

ops.binWidth = 0.05; % this is for histograms. 
% FRlims = [-0.15 0.15];
ops.tWins = [-0.31, 0.31];
animalIds = unique(dataFileTb.animalId);
ops.folderSigma = [strrep(['StatAlpha ' num2str(0.005)], '.', '_') ' numcyc=' num2str(ops.numcyc)];
% windowSize = 0.15; %in seconds 

% ops.stimDurs = {'150','100','050','020','010','005'}; %in ms

% ops.stimDurs = {'150'}; %in ms
ops.universalWindow =1;
if ops.universalWindow
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\allWins',['AllUnitswM1',FRbin]);
else
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\firstcyc',[strjoin(animalIds, '_') '_NP\AllUnitswM1',FRbin], [num2str(0.005) ' numcyc=' num2str(ops.numcyc) 'paired selective']);
end


%% load Zdata variables
load(fullfile(ops.savePath, "ZdataVars.mat"),'ZdataTable');

%% load metadata variables
load(fullfile(ops.savePath, "allVars.mat"),'metadataTable');

% load FRdata variables
load(fullfile(ops.savePath, "FRdataVars.mat"),'FRdataTable');

%% Make variables for raster FR rate, etc
GetComposite(dataFileTb, ops);
 
%% Make variables for raster FR rate, etc
GetFRData(dataFileTb, ops);

%% Add meanFR data
AddMeanFRData(ops, FRdataTable);


%%  Load MeanFRTable
load(fullfile(ops.savePath, "meanFRTable.mat"),'meanFRTable');

%% Make variables for raster FR rate, etc
GetZData(dataFileTb, ops);
%% plot Rasters
 MakeFigures(dataFileTb, ops, finalTable, ops.plotAlpha);

 %%  
 MakeFiguresNoannotation(dataFileTb, ops, finalTable, ops.plotAlpha, ops.savePath);

 %% Calculate sig units for each GT and then do binomial test.
 ops.plotAlpha = 0.01;
 BinomialIpsiResponsive(dataFileTb, ops, metadataTable, ops.plotAlpha, ops.savePath);

  %% Calculate sig units for each GT and then do binomial test. 
 ops.binWidth = 0.0025;
 IpsiresponsiveLatencies(ops, metadataTable, meanFRTable );

 %% Plot Cbiastable
MakeCbiasFigures(fullfile(ops.savePath, "allVars.mat"), ops.binWidth, ops.plotAlpha);

%% PLot histo
PlotHisto(fullfile(ops.savePath, "allVars.mat"),ops.plotAlpha, ops.savePath, ops.binWidth);


%% Plot FR or zdata across all mice in a genotype

 
%    for win = 1:numel(ops.WindowNames)-1
%        window = ops.WindowNames{win};
%         PlotAvgTracesZ(dataFileTb, ops, metadataTable, ZdataTable, window);
%    end

%% Plot FR or FRdata across all mice in a genotype

 
   for win = 1:numel(ops.WindowNames)
       window = ops.WindowNames{win};
        PlotAvgTracesFR(dataFileTb, ops, metadataTable, FRdataTable, window);
   end


%% Plot FR or FRdata across all mice in a genotype only plot WT contra vs ipse and KO contra v ipsi
ops.savePath = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\Fig6';
ops.plotAlpha = 0.01;
maxFR = 17;
ops.plotxLims= [-0.05 0.1];
for win = 6 % just plotting 100ms
    window = ops.WindowNames{win};
    PlotAvgTracesFRFinal(dataFileTb, ops, metadataTable, FRdataTable, window, maxFR);
end



%% PLot Depth vs Cbias histogram. 

ops.plotAlpha = 0.01;

ops.parts =3;
nboot=10;
LTwoThree = 285;
tipAdjust = 200;
ops.savePath = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\FigS6';
CBiasDepthHistoLinefinal(ops, metadataTable, nboot, LTwoThree, tipAdjust);

%% PLot Depth vs Cbias histogra for all depths combined

ops.plotAlpha = 0.01;

ops.parts =3;
nboot=10;
LTwoThree = 285;
tipAdjust = 200;
ops.savePath = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\FigS6';
CbiasComparison_AllDepths(ops, metadataTable, nboot, LTwoThree, tipAdjust);

      
%% PLot Depth vs Cbias histogram. 

ops.plotAlpha = 0.01;
ops.parts =4;
CBiasDepthHistoLineForVideo(ops, metadataTable);


%% PLot FR heatmaps each freq
withLabels =1;
ops.plotAlpha = 0.01;
window = [ops.WindowNames(8), ops.WindowNames(6),ops.WindowNames(4)];
ops.plotxLims = [-0.05, 0.05];
FRHeatmapsEachFreq(ops, metadataTable, meanFRTable, ops.plotAlpha, window, withLabels);

%% PLot FR heatmaps all freq Fig6A
withLabels =1;
ops.plotAlpha = 0.01;
window = ops.WindowNames{6};
ops.plotxLims = [-0.05, 0.10];
ops.savePath = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\Fig6';
FRHeatmapsAllFreq(ops, metadataTable, meanFRTable, ops.plotAlpha, window, withLabels);
      
%% PLot Raw FR heatmaps all freq Fig6A Supplemental may be 
withLabels =1;
ops.plotAlpha = 0.01;
window = ops.WindowNames{6};
ops.plotxLims = [-0.05, 0.10];
ops.savePath = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\FigS6';
RawFRHeatmapsAllFreq(ops, metadataTable, meanFRTable, ops.plotAlpha, window, withLabels);
      




%% plot all probe entry for shanks with responsive units as per 20Hz anf 150 ms window
% Fig S5B
% load histology_wM1
histTable = readtable(fullfile(groupDir,'Histology\Histology_wM1 - KO.csv'));

frameColor = [0.5 0.5 0.5];
frameColorAlpha = 1;
frameLineWidth = 1;

animalNames = unique(histTable.AnimalName);
bregma = allenCCFbregma(); % bregma position in reference data space
atlas_resolution = 0.010; % mm

%Probe with lines


% file location of probe points
% processed_images_folder = folder_processed_images;

% directory of reference atlas files
annotation_volume_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\annotation_volume_10um_by_index.npy';
structure_tree_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\structure_tree_safe_2017.csv';
template_volume_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\template_volume_10um.npy';

% name of the saved probe points
% probe_save_name_suffix = 'electrode_track_1';
%get all probe files here. 
% allprobes = dir(fullfile(processed_images_folder, 'probe_points*'));

% probe_save_name_suffix = 'NP24_230827a';

% either set to 'all' or a list of indices from the clicked probes in this file, e.g. [2,3]
probes_to_analyze = 'all';  % [1 2]

% --------------
% key parameters
% --------------


% from the bottom tip, how much of the probe contained recording sites -- in mm
active_probe_length = 2.4;

% distance queried for confidence metric -- in um
probe_radius = 200; 

% overlay the distance between parent regions in gray (this takes a while)
show_parent_category = false; 

% plot this far or to the bottom of the brain, whichever is shorter -- in mm
distance_past_tip_to_plot = 0.0;

% set scaling e.g. based on lining up the ephys with the atlas
% set to *false* to get scaling automatically from the clicked points
scaling_factor = false;


% ---------------------
% additional parameters
% ---------------------
% plane used to view when points were clicked ('coronal' -- most common, 'sagittal', 'transverse')
plane = 'coronal';

% probe insertion direction 'down' (i.e. from the dorsal surface, downward -- most common!) 
% or 'up' (from a ventral surface, upward)
probe_insertion_direction = 'down';
 % scale active_probe_length appropriately
    active_probe_length = active_probe_length*100;
    
% show a table of regions that the probe goes through, in the console
show_region_table = true;
      
% black brain?
black_brain = true;


close all

fwireframe = [];


% GET AND PLOT PROBE VECTOR IN ATLAS SPACE

% load the reference brain annotations
if ~exist('av','var') || ~exist('st','var')
    disp('loading reference atlas...')
    av = readNPY(annotation_volume_location);
    st = loadStructureTree(structure_tree_location);
end

% select the plane for the viewer
if strcmp(plane,'coronal')
    av_plot = av;
elseif strcmp(plane,'sagittal')
    av_plot = permute(av,[3 2 1]);
elseif strcmp(plane,'transverse')
    av_plot = permute(av,[2 3 1]);
end


    
    % convert error radius into mm
error_length = round(probe_radius / 10);
    
    
    
    % PLOT EACH PROBE -- FIRST FIND ITS TRAJECTORY IN REFERENCE SPACE

% create a new figure with wireframe
fwireframe = plotBrainGrid([], [], fwireframe, black_brain, frameColor, colorAlpha, lineWidth);


[AZ,EL] = view;
view([90,90]);
fwireframe.Color = [1 1 1];


hold on; 
fwireframe.Units = 'inches';
fwireframe.Position = [1 1 4.64 5];


fwireframe.InvertHardcopy = 'off';
bregma_res = bregma*atlas_resolution;
    
plot3(bregma(1),bregma(3),bregma(2), '.', 'color',[1 0 0],'markersize',15);
animalNames = dataFileTb.MouseName;
sessNames = dataFileTb.seshDate;
subIDs = dataFileTb.subId;
sessNames = cellfun(@(x,y) [datestr(x, 'yymmdd') y], sessNames, subIDs, 'UniformOutput', false);

for sessNum = 1:height(histTable)
        
    animalName = histTable.AnimalName{sessNum};
    sessName = histTable.SessDate{sessNum};
    save_folder = fullfile(groupDir, 'Histology', animalName, 'wM1_16x\Processed');
    object_save_name_suffix = ['NP24_' histTable.ProbeSuffix{sessNum}];
    
    % find kcoords for units with significant units. p<ops.plotAlpha
    pvals = metadataTable{animalName, 'pvalBoth'}{1};
    pvals = pvals{sessName, ops.WindowNames{6}}{1};  % 150 ms window
    pvals = cell2mat(table2cell(pvals(:, '20hz')));
    responsiveUnits = pvals<ops.plotAlpha;
    % get kcoords for all units 
    % load se
    if ~any(responsiveUnits)
        continue;
    end

    sessPos = find(ismember(sessNames, sessName));
    %
    load(dataFileTb.sePath{sessPos})
    %
    unitChans = se.userData.spikeInfo.unit_channel_ind;
    unitChans(~responsiveUnits) =[];
    kcoords = se.userData.spikeInfo.chanMap.kcoords;
    kcoords = unique(kcoords(unitChans));
    
    % name of the saved object points
%     object_save_name_suffix = probe_save_name_suffix;


     % load probe points
    probePoints = load(fullfile(save_folder, ['probe_points' object_save_name_suffix]));
    ProbeColors = .75*[1.3 1.3 1.3; 1 .75 0;  .3 1 1; .4 .6 .2; 1 .35 .65; .7 .7 .9; .65 .4 .25; .7 .95 .3; .7 0 0; .6 0 .7; 1 .6 0]; 
    % order of colors: {'white','gold','turquoise','fern','bubble gum','overcast sky','rawhide', 'green apple','purple','orange','red'};
    
    
   
    % determine which probes to analyze
    if strcmp(probes_to_analyze,'all')
        probes = 1:size(probePoints.pointList.pointList,1);
    else
        probes = probes_to_analyze;
    end 

    for ii = 1:numel(kcoords)
        selected_probe = kcoords(ii);
        
        % get the probe points for the currently analyzed probe 
        if strcmp(plane,'coronal')
            curr_probePoints = probePoints.pointList.pointList{selected_probe,1}(:, [3 2 1]);
        elseif strcmp(plane,'sagittal')
            curr_probePoints = probePoints.pointList.pointList{selected_probe,1}(:, [1 2 3]);
        elseif strcmp(plane,'transverse')
            curr_probePoints = probePoints.pointList.pointList{selected_probe,1}(:, [1 3 2]);
        end
        
        
        probe_lengths = histTable.PenetrationDepth(sessNum)/1000;

        % get user-defined probe length from experiment
        if length(probe_lengths) > 1
            probe_length = probe_lengths(selected_probe);
        else
            probe_length = probe_lengths;
        end
        
        % get the scaling-factor method to use
        if scaling_factor
            use_tip_to_get_reference_probe_length = false;
            reference_probe_length = probe_length * scaling_factor;
            disp(['probe scaling of ' num2str(scaling_factor) ' determined by user input']);    
        else
            use_tip_to_get_reference_probe_length = true;
            disp(['getting probe scaling from histology data...']);
        end
        
        % get line of best fit through points
        % m is the mean value of each dimension; p is the eigenvector for largest eigenvalue
        [m,p,s] = best_fit_line(curr_probePoints(:,1), curr_probePoints(:,2), curr_probePoints(:,3));
        if isnan(m(1))
            disp(['no points found for probe ' num2str(selected_probe)])
            continue
        end
        
        % ensure proper orientation: want 0 at the top of the brain and positive distance goes down into the brain
        if p(2)<0
            p = -p;
        end
        
        % determine "origin" at top of brain -- step upwards along tract direction until tip of brain / past cortex
        ann = 10;
        out_of_brain = false;
        while ~(ann==1 && out_of_brain) % && distance_stepped > .5*active_probe_length)
            m = m-p; % step 10um, backwards up the track
            ann = av(round(m(1)),round(m(2)),round(m(3))); %until hitting the top
            if strcmp(st.safe_name(ann), 'root')
                % make sure this isn't just a 'root' area within the brain
                m_further_up = m - p*20; % is there more brain 200 microns up along the track?
                ann_further_up = av(round(max(1,m_further_up(1))),round(max(1,m_further_up(2))),round(max(1,m_further_up(3))));
                if strcmp(st.safe_name(ann_further_up), 'root')
                    out_of_brain = true;
                end
            end
        end
        
        % focus on wireframe plot
        figure(fwireframe);
        
        % plot probe points
%         hp = plot3(curr_probePoints(:,1), curr_probePoints(:,3), curr_probePoints(:,2), '.','linewidth',2, 'color',[ProbeColors(selected_probe,:) .2],'markers',10);
        
        % plot brain entry point
        plot3(m(1), m(3), m(2), 'k.','linewidth',1, 'MarkerSize', 15)
        
    end
end

% plot all sessions together on one reference

% load histology_wM1
histTable =readtable(fullfile(groupDir,'Histology\Histology_wM1 - WT.csv'));


animalNames = unique(histTable.AnimalName);
bregma = allenCCFbregma(); % bregma position in reference data space
atlas_resolution = 0.010; % mm

%Probe with lines


% file location of probe points
% processed_images_folder = folder_processed_images;

% directory of reference atlas files
annotation_volume_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\annotation_volume_10um_by_index.npy';
structure_tree_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\structure_tree_safe_2017.csv';
template_volume_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\template_volume_10um.npy';

% name of the saved probe points
% probe_save_name_suffix = 'electrode_track_1';
%get all probe files here. 
% allprobes = dir(fullfile(processed_images_folder, 'probe_points*'));

% probe_save_name_suffix = 'NP24_230827a';

% either set to 'all' or a list of indices from the clicked probes in this file, e.g. [2,3]
probes_to_analyze = 'all';  % [1 2]

% --------------
% key parameters
% --------------


% from the bottom tip, how much of the probe contained recording sites -- in mm
active_probe_length = 2.4;

% distance queried for confidence metric -- in um
probe_radius = 200; 

% overlay the distance between parent regions in gray (this takes a while)
show_parent_category = false; 

% plot this far or to the bottom of the brain, whichever is shorter -- in mm
distance_past_tip_to_plot = 0.0;

% set scaling e.g. based on lining up the ephys with the atlas
% set to *false* to get scaling automatically from the clicked points
scaling_factor = false;


% ---------------------
% additional parameters
% ---------------------
% plane used to view when points were clicked ('coronal' -- most common, 'sagittal', 'transverse')
plane = 'coronal';

% probe insertion direction 'down' (i.e. from the dorsal surface, downward -- most common!) 
% or 'up' (from a ventral surface, upward)
probe_insertion_direction = 'down';
 % scale active_probe_length appropriately
    active_probe_length = active_probe_length*100;
    
% show a table of regions that the probe goes through, in the console
show_region_table = true;
      
% black brain?
black_brain = true;


% close all
% 
% fwireframe = [];


% GET AND PLOT PROBE VECTOR IN ATLAS SPACE

% load the reference brain annotations
if ~exist('av','var') || ~exist('st','var')
    disp('loading reference atlas...')
    av = readNPY(annotation_volume_location);
    st = loadStructureTree(structure_tree_location);
end

% select the plane for the viewer
if strcmp(plane,'coronal')
    av_plot = av;
elseif strcmp(plane,'sagittal')
    av_plot = permute(av,[3 2 1]);
elseif strcmp(plane,'transverse')
    av_plot = permute(av,[2 3 1]);
end


    
    % convert error radius into mm
error_length = round(probe_radius / 10);
    
    
    
    % PLOT EACH PROBE -- FIRST FIND ITS TRAJECTORY IN REFERENCE SPACE
    
% % create a new figure with wireframe
% fwireframe = plotBrainGrid([], [], fwireframe, black_brain);
% hold on; 
% fwireframe.InvertHardcopy = 'off';
% bregma_res = bregma*atlas_resolution;
%     
% plot3(bregma(1),bregma(3),bregma(2), '*', 'color',[1 1 1],'markers',5);

for sessNum = 1:height(histTable)
        
    animalName = histTable.AnimalName{sessNum};
    sessName = histTable.SessDate{sessNum};
    save_folder = fullfile(groupDir, 'Histology', animalName, 'wM1_16x\Processed');
    object_save_name_suffix = ['NP24_' histTable.ProbeSuffix{sessNum}];
    
    % find kcoords for units with significant units. p<ops.plotAlpha
    pvals = metadataTable{animalName, 'pvalBoth'}{1};
    pvals = pvals{sessName, ops.WindowNames{6}}{1};  % 150 ms window
    pvals = cell2mat(table2cell(pvals(:, '20hz')));
    responsiveUnits = pvals<ops.plotAlpha;
    % get kcoords for all units 
    % load se
    if ~any(responsiveUnits)
        continue;
    end

    sessPos = find(ismember(sessNames, sessName));
    %
    load(dataFileTb.sePath{sessPos})
    %
    unitChans = se.userData.spikeInfo.unit_channel_ind;
    unitChans(~responsiveUnits) =[];
    kcoords = se.userData.spikeInfo.chanMap.kcoords;
    kcoords = unique(kcoords(unitChans));
    
    % name of the saved object points
%     object_save_name_suffix = probe_save_name_suffix;


     % load probe points
    probePoints = load(fullfile(save_folder, ['probe_points' object_save_name_suffix]));
    ProbeColors = .75*[1.3 1.3 1.3; 1 .75 0;  .3 1 1; .4 .6 .2; 1 .35 .65; .7 .7 .9; .65 .4 .25; .7 .95 .3; .7 0 0; .6 0 .7; 1 .6 0]; 
    % order of colors: {'white','gold','turquoise','fern','bubble gum','overcast sky','rawhide', 'green apple','purple','orange','red'};
    
    
   
    % determine which probes to analyze
    if strcmp(probes_to_analyze,'all')
        probes = 1:size(probePoints.pointList.pointList,1);
    else
        probes = probes_to_analyze;
    end 

    for ii = 1:numel(kcoords)
        selected_probe = kcoords(ii);
        
        
        % get the probe points for the currently analyzed probe 
        if strcmp(plane,'coronal')
            curr_probePoints = probePoints.pointList.pointList{selected_probe,1}(:, [3 2 1]);
        elseif strcmp(plane,'sagittal')
            curr_probePoints = probePoints.pointList.pointList{selected_probe,1}(:, [1 2 3]);
        elseif strcmp(plane,'transverse')
            curr_probePoints = probePoints.pointList.pointList{selected_probe,1}(:, [1 3 2]);
        end
        
        
        probe_lengths = histTable.PenetrationDepth(sessNum)/1000;

        % get user-defined probe length from experiment
        if length(probe_lengths) > 1
            probe_length = probe_lengths(selected_probe);
        else
            probe_length = probe_lengths;
        end
        
        % get the scaling-factor method to use
        if scaling_factor
            use_tip_to_get_reference_probe_length = false;
            reference_probe_length = probe_length * scaling_factor;
            disp(['probe scaling of ' num2str(scaling_factor) ' determined by user input']);    
        else
            use_tip_to_get_reference_probe_length = true;
            disp(['getting probe scaling from histology data...']);
        end
        
        % get line of best fit through points
        % m is the mean value of each dimension; p is the eigenvector for largest eigenvalue
        [m,p,s] = best_fit_line(curr_probePoints(:,1), curr_probePoints(:,2), curr_probePoints(:,3));
        if isnan(m(1))
            disp(['no points found for probe ' num2str(selected_probe)])
            continue
        end
        
        % ensure proper orientation: want 0 at the top of the brain and positive distance goes down into the brain
        if p(2)<0
            p = -p;
        end
        
        % determine "origin" at top of brain -- step upwards along tract direction until tip of brain / past cortex
        ann = 10;
        out_of_brain = false;
        while ~(ann==1 && out_of_brain) % && distance_stepped > .5*active_probe_length)
            m = m-p; % step 10um, backwards up the track
            ann = av(round(m(1)),round(m(2)),round(m(3))); %until hitting the top
            if strcmp(st.safe_name(ann), 'root')
                % make sure this isn't just a 'root' area within the brain
                m_further_up = m - p*20; % is there more brain 200 microns up along the track?
                ann_further_up = av(round(max(1,m_further_up(1))),round(max(1,m_further_up(2))),round(max(1,m_further_up(3))));
                if strcmp(st.safe_name(ann_further_up), 'root')
                    out_of_brain = true;
                end
            end
        end
        
        % focus on wireframe plot
        figure(fwireframe);
        
        % plot probe points
%         hp = plot3(curr_probePoints(:,1), curr_probePoints(:,3), curr_probePoints(:,2), '.','linewidth',2, 'color',[ProbeColors(selected_probe,:) .2],'markers',10);
        
        % plot brain entry point
        plot3(m(1), m(3), m(2), '.','color', [125 125 125]/255,'linewidth',1, 'MarkerSize', 15)
        
    end
end

exportgraphics(fwireframe, fullfile('E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\FigS5\wM1 Penetrations_blank.pdf'), 'Resolution', 1200);
            



%% Helper function
function se = loadsess(sePath)
    load(sePath);
end

function savesess(sePath, se)
    save(sePath, 'se', '-v7.3');  
end

function x = findDuration(stimType)
    
    secs = str2num(stimType(end-2:end));
    if secs
        x = secs/1000;
    else
        x = 1;
    end
end

function x = findDurationLFP(stimType)
    
    secs = str2num(stimType(end-1:end));
    if secs
        x = 1/secs;
    else
        x = 1;
    end
end

function x = findDurationFromCyc(stimType)
    freq = str2num(stimType(5:6));
    cycs = str2num(stimType(10));
    x = 1/freq * cycs;
end

function PlotHistoUnitsHelper(fwireframe, allHisto, bregma, marker, colorgen)
    atlas_resolution = 0.010; % mm
    
    for unitNum = 1:height(allHisto)
        % find shank form kcoord and then find the ycoord on that
        % channel on that shank
      try
        ap = allHisto{unitNum, 'AP_location'};
      catch
          ap = allHisto{unitNum, 'Var3'};
      end
      try
          dv = allHisto{unitNum, 'DV_location'};
      catch
          dv = allHisto{unitNum, 'Var4'};
      end
      try
          ml = -abs(allHisto{unitNum, 'ML_location'});

      catch
          ml = -abs(allHisto{unitNum, 'Var5'});
      end

        unitEucl = [ap dv ml]/atlas_resolution;
        
        figure(fwireframe)
        hold on
        plot3(bregma(1) - unitEucl(1), bregma(3) + unitEucl(3),bregma(2) + unitEucl(2), ...
        'Marker', marker, 'color' , colorgen, 'MarkerSize', 15);           

    end
end

function meanFR = SignifyFR(meanFR, allpvals, sigUnits,statAlpha, column,bodyside7, stimDur)
    if allpvals
        if ~isempty(bodyside7) && stimDur~=2
            sigUnits(bodyside7) =[];
            meanFR(~sigUnits,:) = [];
        else
            meanFR(~sigUnits,:) = [];
        end

    else
        sigUnits = cell2mat(cellfun(@(x) x< statAlpha, meanFR(:,column), 'UniformOutput',false));
        meanFR(~sigUnits,:) = [];
    end
            
end

function GetComposite(dataFileTb, ops)
    defPenetrationDepth = ops.defPenetrationDepth;
    trials{1} = ops.trials{1};
    trials{2} = ops.trials{2}; 
    statAlpha = ops.statAlpha;
    plotAlpha = ops.plotAlpha;
    binSize = ops.binSize;
    tWins = ops.tWins;
    inputrecSites = ops.recSites;
    savePath = ops.savePath;
    universalWindow = ops.universalWindow;
    redo = ops.redo;
    animalID = dataFileTb.MouseName;
    
    uniAnimalId = unique(dataFileTb.MouseName);
    
    variableNames = {'genotype', 'pvalBoth', 'pvalContra', 'pvalIpsi', 'HistoTable', 'adc', 'cbias'};
    
    readPaths= dataFileTb.sePath;
    uGenotypes = unique(dataFileTb.Genotype);
    genotypes = dataFileTb.Genotype;
    sessDates = dataFileTb.sessionDatetime;
    subIds = dataFileTb.subId;
    histology = dataFileTb.histology;
    bins = tWins(1):binSize:tWins(2);
    dataTable = cell(numel(uniAnimalId), numel(variableNames));
    metadataTable = cell2table(dataTable, 'RowNames', uniAnimalId, 'VariableNames', variableNames);
 
    spikedataTable = cell2table(cell(numel(uniAnimalId), 1), 'RowNames', uniAnimalId, 'VariableNames', {'spikeTimes'});
    
    parfor animal = 1:numel(uniAnimalId)
        animalId = uniAnimalId{animal};
        dataTable = cell(1, numel(variableNames));
        animalTable = cell2table(dataTable, 'RowNames', {animalId}, 'VariableNames', variableNames);
        spikeAnimalTable = cell2table(cell(1,1), 'RowNames', {animalId}, 'VariableNames', {'spikeTimes'});
       
        animalReadPaths = readPaths(strcmp(uniAnimalId(animal), animalID));
        sessIDs = [datestr(sessDates(strcmp(uniAnimalId(animal), animalID)), 'yymmdd') [subIds{strcmp(uniAnimalId(animal), animalID)}]'];
         % Convert the character array to a cell array
        sessArray = cell(size(sessIDs, 1), 1);
        for i = 1:size(sessIDs, 1)
            sessArray{i} = sessIDs(i, :);
        end

        defaultWinTable = cell(numel(sessArray), numel(ops.windows));
        defaultWinTable = cell2table(defaultWinTable, "RowNames", sessArray, 'VariableNames', ops.WindowNames);
        
        animalTable.genotype(animalId) = unique(dataFileTb.Genotype(strcmp(uniAnimalId(animal), animalID)));
        for var = 2:numel(variableNames)
            varName = variableNames{var};
            
            animalTable.(varName){animalId} = defaultWinTable;
           

        end

        spikeAnimalTable.('spikeTimes'){animalId} = defaultWinTable;
       
        % (sessIDs, animalReadPaths, ops, sessArray, animalTable, animalID)
        tic
        for sessNum = 1:numel(sessArray)

            se =loadsess(animalReadPaths{sessNum});
            
            sessRecSite = cell2mat(se.userData.sessionInfo.recSite);
            sessName = sessArray{sessNum};           
                
            fprintf('%s\n\n', animalReadPaths{sessNum});
            tRef = se.GetReferenceTime();
            check = diff(tRef);
        
            if any(check<0)
                disp('tRefs are not monotonically increasing');
            end                  
            
            % remove skipped trials  
            behavData = se.GetTable('behavValue');                   
            responses = behavData.response;
            abortTrials = find(cell2mat(responses) == 3);        
            se = BS.Preprocess.removeTrials(abortTrials,se);
            behavData = se.GetTable('behavValue');
            
            
            % remove not miss error trials
            responses = behavData.response;           
            keepTrials = find(cell2mat(responses));                    
            se = BS.Preprocess.removeTrials(keepTrials,se);
            
            

             try            
                trialMap = se.userData.sessionInfo.APStim;
            catch
                trialMap{1} = [];
            end

            if ~isempty(trialMap{1})
                trialSplit = strsplit(trialMap{1},':');
                if numel(trialSplit)<3
                    if any(strcmp(trialSplit{end}(1:end-1), 'end'))
                        trialInd = [str2double(trialSplit{1}) : se.numEpochs];
                    else
                        trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{end}(1:end-1))];
                    end
                else
                    if any(strcmp(trialSplit{end}(1:end-1), 'end'))
                        trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}), str2double(trialSplit{3}): se.numEpochs];
                    else
                        trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}), str2double(trialSplit{3}) : str2double(trialSplit{end}(1:end-1))];
                    end
                end
                

             end

            %get different stim types                    
            leftStimTypes = se.GetColumn('behavValue', 'leftStimType');
            rightStimTypes =  se.GetColumn('behavValue', 'rightStimType');
            
            leftStimTypes = leftStimTypes(trialInd); 
            
            rightStimTypes = rightStimTypes(trialInd); 

            %get left and right stim types
            behavData = se.GetTable('behavValue');
            behavData = behavData(trialInd,:); 
            behavData(1,:) = [];
            leftStimTypes(1,:) = [];                
            rightStimTypes(1,:) = [];
        

            
            % slice firing rate with tWins
            frAll= se.SliceTimeSeries('spikeRate', tWins, 'Fill', 'bleed');
            frAll = frAll(trialInd,:);
            frAll(1,:) = [];
            frAll = table2cell(frAll);
            frAll = cellfun(@(x) x', frAll, 'UniformOutput',false);         

             % slice firing rate with tWins
            zAll= se.SliceTimeSeries('zRate', tWins, 'Fill', 'bleed');
            zAll = zAll(trialInd,:);
            zAll(1,:) = [];
            zAll = table2cell(zAll);
            zAll = cellfun(@(x) x', zAll, 'UniformOutput',false);           
            

            % convert frAll to z-score
            
            % get spikeTimes                     
            spikeAll= se.SliceEventTimes('spikeTime', tWins, 'Fill', 'bleed');
            spikeAll = spikeAll(trialInd,:);
            spikeAll(1,:) = [];
            spikeAll = table2cell(spikeAll);
            spikeAll = cellfun(@(x) x', spikeAll, 'UniformOutput',false);   
            
            % get adcAll
            adcAll = se.SliceTimeSeries('adc', tWins, 'Fill', 'bleed');
            adcAll = adcAll(trialInd,:);
            adcAll(1,:) = [];
            adcAllLeft = adcAll.leftStim;
            adcAllTime = adcAll.time;
            
            adcAllLeft = cellfun(@transpose, adcAllLeft,'UniformOutput', false);
            adcAllTime = cellfun(@transpose, adcAllTime,'UniformOutput', false);    
           
             
            

            try
                unitChanDepth = se.userData.spikeInfo.quality_metrics.depth;
            catch
                
                chanDepth = 0:20:1260; %(in um)
                channelInds = se.userData.spikeInfo.unit_channel_ind;
                chanMap = se.userData.sessionInfo.channel_map.chanMap;
                [~, chanPos] = ismember(channelInds, chanMap);
                unitChanDepth= chanDepth(chanPos);
                
            end
            
            stimTypes = leftStimTypes;
            uStimTypes = unique(stimTypes);
            ufreq = unique(cellfun(@(x) x(5:6),uStimTypes, 'UniformOutput', false)); % for gettign just the unique frequencies irrespective of the cycles
            
            unitNums = size(spikeAll,2);
           

            
                
            
            unitNumArray = cell(unitNums,1);
            for unitNum = 1: unitNums
                unitNumArray{unitNum} = ['Unit' num2str(unitNum)];
            end

            stimArray = cellfun(@(x) [x 'hz'], ufreq, 'UniformOutput', false);
            defualtStimTable = cell(unitNums, numel(ufreq));
            defualtStimTable = cell2table(defualtStimTable, "RowNames", unitNumArray, 'VariableNames', stimArray);
            
            for  var = 2:numel(variableNames)
                varName1 = variableNames{var};
                for var2 = 1:numel(ops.windows)
                    varName2 = ops.WindowNames{var2};                    
                    animalTable.(varName1){animalId}.(varName2){sessName} = defualtStimTable;
                end
            end
            

            for var2 = 1:numel(ops.windows)
                    varName2 = ops.WindowNames{var2};
                    spikeAnimalTable.('spikeTimes'){animalId}.(varName2){sessName} = defualtStimTable;
                    
                    
            end
            adc = cell(1,numel(ufreq));
                
                   
                    
            penetrationDepth = se.userData.sessionInfo.histology; 


            % for all the stimDurs
           for stimDur = 1:numel(ufreq)

                pvalL = [];
                pvalR = [];
                unitDepth = [];
                spikeTimes = {};
                pvalstimDur =[];                       
                meanFR = {};
                cbiases = {};
                pValIpsi = [];
                pValContra = [];
                unitHistoTable = table();
                kcoords = se.userData.spikeInfo.chanMap.kcoords;   
                unitChannels= se.userData.spikeInfo.unit_channel_ind;
                adc = {};
                for window = 1:numel(ops.windows)
                    windowSize = ops.windows(window);
                    binsWin = find(bins>= -windowSize & bins<= windowSize);
                    plotLims = [-windowSize, windowSize];
                    temp = binsWin;
                    try
                        frAllwin = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                    catch                            
                        errorTrials = find(cell2mat(cellfun(@(x) numel(x)< temp(end), frAll(:,1), 'UniformOutput',false)));
                        behavData(errorTrials,:) =[];
                        frAll(errorTrials,:)=[];
                        spikeAll(errorTrials,:)=[];
                        zAll(errorTrials,:)=[];
                        frAllwin = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                    end

                    leftStimTypes = behavData.leftStimType;
                    rightStimTypes = behavData.rightStimType;

                   
                    
                    trials2keepL = find(strcmp(trials{1}{1}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(5:6),ufreq{stimDur}), ...
                        leftStimTypes, 'UniformOutput',false)));
                    trials2keepR  = find(strcmp(trials{1}{2}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(5:6),ufreq{stimDur}), ...
                        rightStimTypes, 'UniformOutput',false)));
                    
                    FRLeft  = frAllwin (trials2keepL ,2:end);
                    FRRight  = frAllwin (trials2keepR ,2:end);
                    FRtime  = frAllwin (trials2keepR ,1);
                    
                    %get p-value based on windowsize = stim duration                        
                    preWindow  = 1:(round(numel(FRLeft {1})/2));
                    postWindow  =  preWindow (end)+1: numel(FRLeft {1}); 
                    temp1 = preWindow ;
                    temp2 = postWindow ;

                    preMeanFRL  = cell2mat(cellfun(@(x) mean(x(temp1)), FRLeft , 'UniformOutput', false));
                    postMeanFRL  = cell2mat(cellfun(@(x) mean(x(temp2)), FRLeft , 'UniformOutput', false));
                    preMeanFRR  = cell2mat(cellfun(@(x) mean(x(temp1)), FRRight , 'UniformOutput', false));
                    postMeanFRR  = cell2mat(cellfun(@(x) mean(x(temp2)), FRRight , 'UniformOutput', false));
                    
                    % get spikeTimes for FRlims
                    spikeLeft = spikeAll(trials2keepL ,1:end);
                    spikeRight = spikeAll(trials2keepR ,1:end);                

                    adcLeft = adcAllLeft(trials2keepL);
                    idcs = min(cell2mat(cellfun(@(x) numel(x), adcLeft, 'UniformOutput',false)));
                    adcLeft = cell2mat(cellfun(@(x) x(1:idcs), adcAllLeft(trials2keepL), 'UniformOutput', false));
                    adcTime =  cell2mat(cellfun(@(x) x(1:idcs), adcAllTime(trials2keepL), 'UniformOutput', false));
                    adc{1,1} = mean(adcTime, 1) ;
                    adc{2,1} = mean(adcLeft, 1) ;
                   
                    
                    if sum(ismember('Left', sessRecSite))==4
                        stims = {trials2keepL , trials2keepR };
                    else
                        stims = {trials2keepR , trials2keepL };
                    end
                   
                    win = ops.WindowNames{window};
                    try
                        for unitNum = 1: size(preMeanFRL ,2)   
                            
                            unitChannel = unitChannels(unitNum);
                            shankNum = kcoords(unitChannel);
                            [pvalL] = signrank(preMeanFRL (:,unitNum), postMeanFRL (:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);
                            [pvalR] = signrank(preMeanFRR (:,unitNum), postMeanFRR (:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);
                 
                            unitDepth = unitChanDepth(unitNum);
          
%                             meanFRtime =  cell2mat(FRtime);
%                             meanztime =  cell2mat(ztime);
                        
                            if sum(ismember(sessRecSite, 'Left'))==4
                                uSpikesIpsi = spikeLeft(:,unitNum);
                                uSpikesContra = spikeRight(:,unitNum);
                                pValIpsi = pvalL;
                                pValContra = pvalR;
                                
                            else
                                uSpikesIpsi = spikeRight(:,unitNum);
                                uSpikesContra = spikeLeft(:,unitNum);                                
                                pValIpsi = pvalR;
                                pValContra = pvalL;
                               
                            end
                            
                            preSpikesContra = sum(cell2mat(cellfun(@(x) numel(find(x>plotLims (1) & x<=0)), ...
                                uSpikesContra, 'UniformOutput', false)));
                            postSpikesContra = sum(cell2mat(cellfun(@(x) numel(find(x>0 & x<=plotLims (2))), ...
                                uSpikesContra, 'UniformOutput', false)));
                            preSpikesIpsi = sum(cell2mat(cellfun(@(x) numel(find(x>plotLims (1) & x<=0)), ...
                                uSpikesIpsi, 'UniformOutput', false)));
                            postSpikesIpsi = sum(cell2mat(cellfun(@(x) numel(find(x>0 & x<=plotLims (2))), ...
                                uSpikesIpsi, 'UniformOutput', false)));
                            pvalstimDur = min(pvalL, pvalR);   
                            
                            C = abs(postSpikesContra - preSpikesContra);
                            I = abs(postSpikesIpsi - preSpikesIpsi);
                           
                            Cbias = (C-I)/(C+I);
    
                            spikeTimes = {uSpikesIpsi, uSpikesContra};
%                           
                          
                            unitHistoTable = se.userData.spikeInfo.unitHitsoTable(unitNum,:);    
                            unitHistoTable.unitDepth = penetrationDepth(shankNum)-unitDepth;
                            
                            
                            animalTable.pvalBoth{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = pvalstimDur;
                            animalTable.pvalIpsi{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = pValIpsi;
                            animalTable.pvalContra{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = pValContra;
                            spikeAnimalTable.spikeTimes{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = spikeTimes;
                           
                            animalTable.HistoTable{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = unitHistoTable;
                            animalTable.adc{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = adc;
                            animalTable.cbias{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} =Cbias;
    
    
                        end                
                    
                    catch
                        keyboard;
                    end
                  
                end 
           end

           
          
           % go to next session of the same recording site and
           % genotype
                
        end
    
       %
       toc
      
        metadataTable(animal,:) = animalTable;
     
        spikedataTable(animal,:) = spikeAnimalTable;    
       
    end
    
                      

%     clearvars -except ops allSpikeTimes maxAdc pvals plotAlpha ufreq uGenotypes inputrecSites adcFinal savePath plotLims genotype recSite recSites genotypes
% 
    keyboard;
    if ~exist(savePath, 'dir')
        mkdir(savePath);
    end

    save([savePath '\allVars.mat'], 'metadataTable', 'ops', 'dataFileTb','spikedataTable', '-v7.3');    
        

end

function GetFRData(dataFileTb, ops)
    defPenetrationDepth = ops.defPenetrationDepth;
    trials{1} = ops.trials{1};
    trials{2} = ops.trials{2}; 
    statAlpha = ops.statAlpha;
    plotAlpha = ops.plotAlpha
    binSize = ops.binSize;
    tWins = ops.tWins;
    inputrecSites = ops.recSites;
    savePath = ops.savePath;
    universalWindow = ops.universalWindow;
    redo = ops.redo;
    animalID = dataFileTb.MouseName;
    
    uniAnimalId = unique(dataFileTb.MouseName);    
    
    readPaths= dataFileTb.sePath;
    uGenotypes = unique(dataFileTb.Genotype);
    genotypes = dataFileTb.Genotype;
    sessDates = dataFileTb.sessionDatetime;
    subIds = dataFileTb.subId;
    histology = dataFileTb.histology;
    bins = tWins(1):binSize:tWins(2);
    FRdataTable= cell2table(cell(numel(uniAnimalId), 1), 'RowNames', uniAnimalId, 'VariableNames', {'meanFR'});
    
    parfor animal = 1:numel(uniAnimalId)
        animalId = uniAnimalId{animal};
        
        FRAnimalTable = cell2table(cell(1,1), 'RowNames', {animalId}, 'VariableNames', {'meanFR'});

        animalReadPaths = readPaths(strcmp(uniAnimalId(animal), animalID));
        sessIDs = [datestr(sessDates(strcmp(uniAnimalId(animal), animalID)), 'yymmdd') [subIds{strcmp(uniAnimalId(animal), animalID)}]'];
         % Convert the character array to a cell array
        sessArray = cell(size(sessIDs, 1), 1);
        for i = 1:size(sessIDs, 1)
            sessArray{i} = sessIDs(i, :);
        end

        defaultWinTable = cell(numel(sessArray), numel(ops.windows));
        defaultWinTable = cell2table(defaultWinTable, "RowNames", sessArray, 'VariableNames', ops.WindowNames);
        
       

        FRAnimalTable.('meanFR'){animalId} = defaultWinTable;
        % (sessIDs, animalReadPaths, ops, sessArray, animalTable, animalID)
        tic
       
        
        for sessNum = 1:numel(sessArray)
            
            se =loadsess(animalReadPaths{sessNum});
            
            sessRecSite = cell2mat(se.userData.sessionInfo.recSite);
            sessName = sessArray{sessNum};           
                
            fprintf('%s\n\n', animalReadPaths{sessNum});
            tRef = se.GetReferenceTime();
            check = diff(tRef);
        
            if any(check<0)
                disp('tRefs are not monotonically increasing');
            end                  
            
            % remove skipped trials  
            behavData = se.GetTable('behavValue');                   
            responses = behavData.response;
            abortTrials = find(cell2mat(responses) == 3);        
            se = BS.Preprocess.removeTrials(abortTrials,se);
            behavData = se.GetTable('behavValue');
            
            
            % remove not miss error trials
            responses = behavData.response;           
            keepTrials = find(cell2mat(responses));                    
            se = BS.Preprocess.removeTrials(keepTrials,se);
            
            

             try            
                trialMap = se.userData.sessionInfo.APStim;
            catch
                trialMap{1} = [];
            end

            if ~isempty(trialMap{1})
                trialSplit = strsplit(trialMap{1},':');
                if numel(trialSplit)<3
                    if any(strcmp(trialSplit{end}(1:end-1), 'end'))
                        trialInd = [str2double(trialSplit{1}) : se.numEpochs];
                    else
                        trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{end}(1:end-1))];
                    end
                else
                    if any(strcmp(trialSplit{end}(1:end-1), 'end'))
                        trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}), str2double(trialSplit{3}): se.numEpochs];
                    else
                        trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}), str2double(trialSplit{3}) : str2double(trialSplit{end}(1:end-1))];
                    end
                end
                

             end

            %get different stim types                    
            leftStimTypes = se.GetColumn('behavValue', 'leftStimType');
            rightStimTypes =  se.GetColumn('behavValue', 'rightStimType');
            
            leftStimTypes = leftStimTypes(trialInd); 
            
            rightStimTypes = rightStimTypes(trialInd); 

            %get left and right stim types
            behavData = se.GetTable('behavValue');
            behavData = behavData(trialInd,:); 
            behavData(1,:) = [];
            leftStimTypes(1,:) = [];                
            rightStimTypes(1,:) = [];
        

            
       
             % slice firing rate with tWins
            FRAll= se.SliceTimeSeries('spikeRate', tWins, 'Fill', 'bleed');
            FRAll = FRAll(trialInd,:);
            FRAll(1,:) = [];
            FRAll = table2cell(FRAll);
            FRAll = cellfun(@(x) x', FRAll, 'UniformOutput',false);           
            

            % convert frAll to z-score
            
        
            

            
            stimTypes = leftStimTypes;
            uStimTypes = unique(stimTypes);
            ufreq = unique(cellfun(@(x) x(5:6),uStimTypes, 'UniformOutput', false)); % for gettign just the unique frequencies irrespective of the cycles
            
            unitNums = size(FRAll,2)-1;
           

            
                
            
            unitNumArray = cell(unitNums,1);
            for unitNum = 1: unitNums
                unitNumArray{unitNum} = ['Unit' num2str(unitNum)];
            end

            stimArray = cellfun(@(x) [x 'hz'], ufreq, 'UniformOutput', false);
            defualtStimTable = cell(unitNums, numel(ufreq));
            defualtStimTable = cell2table(defualtStimTable, "RowNames", unitNumArray, 'VariableNames', stimArray);
            
       

            for var2 = 1:numel(ops.windows)
                    varName2 = ops.WindowNames{var2};                  
                    FRAnimalTable.('meanFR'){animalId}{sessNum, varName2}{1} = defualtStimTable;
                    
            end
          

            
            % for all the stimDurs
           for stimDur = 1:numel(ufreq)
                     
                for window =1:numel(ops.windows)
                    windowSize = ops.windows(window);
                    
                    

                    
                    leftStimTypes = behavData.leftStimType;
                    rightStimTypes = behavData.rightStimType;

                   
                    
                    trials2keepL = find(strcmp(trials{1}{1}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(5:6),ufreq{stimDur}), ...
                        leftStimTypes, 'UniformOutput',false)));
                    trials2keepR  = find(strcmp(trials{1}{2}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(5:6),ufreq{stimDur}), ...
                        rightStimTypes, 'UniformOutput',false)));
                    
                    idcs = min(cell2mat(cellfun(@(x) numel(x), FRAll(:,1), 'UniformOutput',false)));
                    FRAll = cellfun(@(x) x(1:idcs), FRAll, 'UniformOutput', false);
                        
                   
                    FRLeft  = FRAll (trials2keepL ,2:end);
                    FRRight  = FRAll (trials2keepR ,2:end);
                    FRtime  = FRAll (:,1);        

                    win = ops.WindowNames{window};
                    try
                        for unitNum = 1: size(FRLeft ,2)   
                         
                            meanFRtime =  mean(cell2mat(FRtime),1);
                        
                            if sum(ismember(sessRecSite, 'Left'))==4

                                uFRI = cell2mat(FRLeft(:,unitNum));
                                uFRC = cell2mat(FRRight(:,unitNum));


%                               
                            else

                                uFRI = cell2mat(FRRight(:,unitNum));
                                uFRC = cell2mat(FRLeft(:,unitNum));
%                                
                            end
                            
                          
                            meanFR = {meanFRtime, uFRC, uFRI};
                      
                          
                            
                            
                           
                            FRAnimalTable.('meanFR'){animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = meanFR;
                            
    
                        end                
                    catch
                        keyboard;
                    end
                  
                end 
           end

           
          
           % go to next session of the same recording site and
           % genotype
                
        end
    
      
        toc
        

%          if ~exist(savePath, 'dir')
%                 mkdir(savePath);
%         end
%         
%         save([savePath '\ZdataVars' animalID '.mat'], 'ops', 'dataFileTb', 'zAnimalTable', '-v7.3');    
        
        FRdataTable(animal,:) = FRAnimalTable;
        
       
    end
    
                      

%     clearvars -except ops allSpikeTimes maxAdc pvals plotAlpha ufreq uGenotypes inputrecSites adcFinal savePath plotLims genotype recSite recSites genotypes
% 
    keyboard;
    if ~exist(savePath, 'dir')
        mkdir(savePath);
    end

    save([savePath '\FRdataVars.mat'], 'ops', 'dataFileTb', 'FRdataTable', '-v7.3');    
        

end

function AddMeanFRData(ops, FRdataTable)
    keyboard;
    rowNames = FRdataTable.Properties.RowNames;
    variableNames = FRdataTable.Properties.VariableNames;
    meanFRTable= cell2table(cell(numel(rowNames), numel(variableNames)), 'RowNames', rowNames, 'VariableNames', variableNames);
    for animal = 1 : height(FRdataTable)
        
        animalFR = FRdataTable.meanFR{animal};
        meanFRTable{animal, 1}{1} = cell2table(cell(height(animalFR), 1), 'RowNames', ...
            animalFR.Properties.RowNames, 'VariableNames', animalFR.Properties.VariableNames(end));
        tic;
        for sessNum = 1: height(animalFR)
            sessFR = animalFR.('300'){sessNum};
            stimNames = sessFR.Properties.VariableNames;
            meanFRTable{animal, 1}{1}{sessNum,1}{1} = cell2table(cell(height(sessFR), width(sessFR)), 'RowNames', ...
                sessFR.Properties.RowNames, 'VariableNames', sessFR.Properties.VariableNames);

            for stim =1:width(sessFR)
                
                stimFR = sessFR.(stimNames{stim});

                time = cellfun(@(x) x(1), stimFR, 'UniformOutput', false);
                [contraMean, ~, ~, contraCI] = cellfun(@(x) MMath.MeanStats(x{2},1), stimFR, 'UniformOutput', false);
                [ipsiMean, ~, ~, ipsiCI] = cellfun(@(x) MMath.MeanStats(x{3},1), stimFR, 'UniformOutput', false);

                meanFRTable{animal, 1}{1}{sessNum,1}{1}.(stimNames{stim})= cellfun(@(a,b,c,d,e) ...
                    cell2table({a, {b}, c, {d},e}, 'VariableNames', {'Time', 'ContraMean', 'ContraCI', 'IpsiMean', 'IpsiCI'}), ...
                    time, contraMean, contraCI, ipsiMean, ipsiCI, 'UniformOutput', false);
            end
        end
        toc;
    end
    save(fullfile(ops.savePath, 'MeanFRTable.mat'), 'meanFRTable', '-v7.3');
     
                
end

function GetZData(dataFileTb, ops)
    defPenetrationDepth = ops.defPenetrationDepth;
    trials{1} = ops.trials{1};
    trials{2} = ops.trials{2}; 
    statAlpha = ops.statAlpha;
    plotAlpha = ops.plotAlpha;
    binSize = ops.binSize;
    tWins = ops.tWins;
    inputrecSites = ops.recSites;
    savePath = ops.savePath;
    universalWindow = ops.universalWindow;
    redo = ops.redo;
    animalID = dataFileTb.MouseName;
    
    uniAnimalId = unique(dataFileTb.MouseName);    
    
    readPaths= dataFileTb.sePath;
    uGenotypes = unique(dataFileTb.Genotype);
    genotypes = dataFileTb.Genotype;
    sessDates = dataFileTb.sessionDatetime;
    subIds = dataFileTb.subId;
    histology = dataFileTb.histology;
    bins = tWins(1):binSize:tWins(2);
    ZdataTable= cell2table(cell(numel(uniAnimalId), 1), 'RowNames', uniAnimalId, 'VariableNames', {'meanZ'});
    
    parfor animal = 1:numel(uniAnimalId)
        animalId = uniAnimalId{animal};
        
        zAnimalTable = cell2table(cell(1,1), 'RowNames', {animalId}, 'VariableNames', {'meanZ'});

        animalReadPaths = readPaths(strcmp(uniAnimalId(animal), animalID));
        sessIDs = [datestr(sessDates(strcmp(uniAnimalId(animal), animalID)), 'yymmdd') [subIds{strcmp(uniAnimalId(animal), animalID)}]'];
         % Convert the character array to a cell array
        sessArray = cell(size(sessIDs, 1), 1);
        for i = 1:size(sessIDs, 1)
            sessArray{i} = sessIDs(i, :);
        end

        defaultWinTable = cell(numel(sessArray), numel(ops.windows));
        defaultWinTable = cell2table(defaultWinTable, "RowNames", sessArray, 'VariableNames', ops.WindowNames);
        
       

        zAnimalTable.('meanZ'){animalId} = defaultWinTable;
        % (sessIDs, animalReadPaths, ops, sessArray, animalTable, animalID)
        tic
       
        
        for sessNum = 1:numel(sessArray)
            
            se =loadsess(animalReadPaths{sessNum});
            
            sessRecSite = cell2mat(se.userData.sessionInfo.recSite);
            sessName = sessArray{sessNum};           
                
            fprintf('%s\n\n', animalReadPaths{sessNum});
            tRef = se.GetReferenceTime();
            check = diff(tRef);
        
            if any(check<0)
                disp('tRefs are not monotonically increasing');
            end                  
            
            % remove skipped trials  
            behavData = se.GetTable('behavValue');                   
            responses = behavData.response;
            abortTrials = find(cell2mat(responses) == 3);        
            se = BS.Preprocess.removeTrials(abortTrials,se);
            behavData = se.GetTable('behavValue');
            
            
            % remove not miss error trials
            responses = behavData.response;           
            keepTrials = find(cell2mat(responses));                    
            se = BS.Preprocess.removeTrials(keepTrials,se);
            
            

             try            
                trialMap = se.userData.sessionInfo.APStim;
            catch
                trialMap{1} = [];
            end

            if ~isempty(trialMap{1})
                trialSplit = strsplit(trialMap{1},':');
                if numel(trialSplit)<3
                    if any(strcmp(trialSplit{end}(1:end-1), 'end'))
                        trialInd = [str2double(trialSplit{1}) : se.numEpochs];
                    else
                        trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{end}(1:end-1))];
                    end
                else
                    if any(strcmp(trialSplit{end}(1:end-1), 'end'))
                        trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}), str2double(trialSplit{3}): se.numEpochs];
                    else
                        trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}), str2double(trialSplit{3}) : str2double(trialSplit{end}(1:end-1))];
                    end
                end
                

             end

            %get different stim types                    
            leftStimTypes = se.GetColumn('behavValue', 'leftStimType');
            rightStimTypes =  se.GetColumn('behavValue', 'rightStimType');
            
            leftStimTypes = leftStimTypes(trialInd); 
            
            rightStimTypes = rightStimTypes(trialInd); 

            %get left and right stim types
            behavData = se.GetTable('behavValue');
            behavData = behavData(trialInd,:); 
            behavData(1,:) = [];
            leftStimTypes(1,:) = [];                
            rightStimTypes(1,:) = [];
        

            
       
             % slice firing rate with tWins
            zAll= se.SliceTimeSeries('zRate', tWins, 'Fill', 'bleed');
            zAll = zAll(trialInd,:);
            zAll(1,:) = [];
            zAll = table2cell(zAll);
            zAll = cellfun(@(x) x', zAll, 'UniformOutput',false);           
            

            % convert frAll to z-score
            
        
            

            
            stimTypes = leftStimTypes;
            uStimTypes = unique(stimTypes);
            ufreq = unique(cellfun(@(x) x(5:6),uStimTypes, 'UniformOutput', false)); % for gettign just the unique frequencies irrespective of the cycles
            
            unitNums = size(zAll,2)-1;
           

            
                
            
            unitNumArray = cell(unitNums,1);
            for unitNum = 1: unitNums
                unitNumArray{unitNum} = ['Unit' num2str(unitNum)];
            end

            stimArray = cellfun(@(x) [x 'hz'], ufreq, 'UniformOutput', false);
            defualtStimTable = cell(unitNums, numel(ufreq));
            defualtStimTable = cell2table(defualtStimTable, "RowNames", unitNumArray, 'VariableNames', stimArray);
            
       

            for var2 = 1:numel(ops.windows)
                    varName2 = ops.WindowNames{var2};                  
                    zAnimalTable.('meanZ'){animalId}{sessNum, varName2}{1} = defualtStimTable;
                    
            end
          


            % for all the stimDurs
           for stimDur = 1:numel(ufreq)
                     
      
                
                for window = 1:numel(ops.windows)
                    windowSize = ops.windows(window);
                    binsWin = find(bins>= -windowSize & bins<= windowSize);
                  
                    temp = binsWin;
                    try
                        zAllwin = cellfun(@(x) x(temp), zAll,'UniformOutput',false);
                    catch                            
                        errorTrials = find(cell2mat(cellfun(@(x) numel(x)< temp(end), zAll(:,1), 'UniformOutput',false)));
                        behavData(errorTrials,:) =[];                       
                        zAll(errorTrials,:)=[];
                        zAllwin = cellfun(@(x) x(temp), zAll,'UniformOutput',false);
                    end
                    leftStimTypes = behavData.leftStimType;
                    rightStimTypes = behavData.rightStimType;

                   
                    
                    trials2keepL = find(strcmp(trials{1}{1}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(5:6),ufreq{stimDur}), ...
                        leftStimTypes, 'UniformOutput',false)));
                    trials2keepR  = find(strcmp(trials{1}{2}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(5:6),ufreq{stimDur}), ...
                        rightStimTypes, 'UniformOutput',false)));
                    

                    zAllplot  = cellfun(@(x) x(temp), zAll,'UniformOutput',false);
                    zLeft  = zAllplot (trials2keepL ,2:end);
                    zRight  = zAllplot (trials2keepR ,2:end);
                    ztime  = zAllplot (:,1);        

                    win = ops.WindowNames{window};
                    try
                        for unitNum = 1: size(zLeft ,2)   
                         
                            meanztime =  mean(cell2mat(ztime),1);
                        
                            if sum(ismember(sessRecSite, 'Left'))==4

                                uZI = cell2mat(zLeft(:,unitNum));
                                uZC = cell2mat(zRight(:,unitNum));


%                               
                            else

                                uZI = cell2mat(zRight(:,unitNum));
                                uZC = cell2mat(zLeft(:,unitNum));
%                                
                            end
                            
                          
                            meanZ = {meanztime, uZC, uZI};
                      
                          
                            
                            
                           
                            zAnimalTable.('meanZ'){animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = meanZ;
                            
    
                        end                
                    catch
                        keyboard;
                    end
                  
                end 
           end

           
          
           % go to next session of the same recording site and
           % genotype
                
        end
    
      
        toc
        

%          if ~exist(savePath, 'dir')
%                 mkdir(savePath);
%         end
%         
%         save([savePath '\ZdataVars' animalID '.mat'], 'ops', 'dataFileTb', 'zAnimalTable', '-v7.3');    
        
        ZdataTable(animal,:) = zAnimalTable;
        
       
    end
    
                      

%     clearvars -except ops allSpikeTimes maxAdc pvals plotAlpha ufreq uGenotypes inputrecSites adcFinal savePath plotLims genotype recSite recSites genotypes
% 
    keyboard;
    if ~exist(savePath, 'dir')
        mkdir(savePath);
    end

    save([savePath '\ZdataVars.mat'], 'ops', 'dataFileTb', 'ZdataTable', '-v7.3');    
        

end

function BinomialIpsiResponsive(dataFileTb, ops, metadataTable, plotAlpha, savePath)
    
    close all   
    ops.plotAlpha = plotAlpha;
    ops.savePath = savePath;

    % pvals is pvalmin, pvalcontra,pvalipsi
    % just signify according to allpvals
          
 

         % get ugenotypes
    uGenotypes = unique(metadataTable.genotype);
    
    for genotype = 1: numel(uGenotypes)
        mouseNames = metadataTable.Properties.RowNames(strcmp(metadataTable.genotype, uGenotypes{genotype}));
        ipsiTable{1,genotype} = cell(numel(mouseNames),numel(metadataTable.pvalIpsi{mouseNames{1}}.Properties.VariableNames));
        contraTable{1,genotype} = cell(numel(mouseNames),numel(metadataTable.pvalContra{mouseNames{1}}.Properties.VariableNames));
        anyTable{1,genotype} = cell(numel(mouseNames),numel(metadataTable.pvalContra{mouseNames{1}}.Properties.VariableNames));
        for mouse = 1:numel(mouseNames)
         
            pvalIpsi = metadataTable.pvalIpsi{mouseNames{mouse}};
            pvalContra = metadataTable.pvalContra{mouseNames{mouse}};
            pvalAny = metadataTable.pvalBoth{mouseNames{mouse}};
            windowNames = pvalIpsi.Properties.VariableNames;
%                 sessNames = pvalIpsi.Properties.RowNames;
            for window = 1:numel(windowNames)
                ipsiTemp = cell2mat(cellfun(@(x) cell2mat(table2cell(x)), pvalIpsi.(windowNames{window}), 'UniformOutput', false));
                contraTemp = cell2mat(cellfun(@(x) cell2mat(table2cell(x)), pvalContra.(windowNames{window}), 'UniformOutput', false));
                anyTemp = cell2mat(cellfun(@(x) cell2mat(table2cell(x)), pvalAny.(windowNames{window}), 'UniformOutput', false));
                if size(anyTemp,2) >3
                       anyTemp = anyTemp(:,1:3);
                       ipsiTemp = ipsiTemp(:,1:3);
                       contraTemp = contraTemp(:,1:3);                  

                end

                for allpvals = 0:ops.allpvals 

                    if allpvals               
                        % finrst get pvals for units that are significant
                        % in either stim sides
                        sigUnits = anyTemp < ops.plotAlpha;
                        sumlogic = sum(sigUnits,2);
                        sigUnits = sumlogic>0;
                        
                        
                        % find ipsi units that are significant in any freq
                        anyTemp = anyTemp(sigUnits,:);
                        anyTable{1,genotype}{mouse,window}(4) = height(anyTemp);
                        ipsiTemp = ipsiTemp(sigUnits,:);
                        
                        sigUnits = ipsiTemp < ops.plotAlpha;
                        sumlogic = sum(sigUnits,2);
                        sigUnits = sumlogic>0;

                        ipsiTable{1,genotype}{mouse,window}(4) = height(ipsiTemp(sigUnits,:));

                        sigUnits = contraTemp < ops.plotAlpha;
                        sumlogic = sum(sigUnits,2);
                        sigUnits = sumlogic>0;

                        contraTable{1,genotype}{mouse,window}(4) = height(contraTemp(sigUnits,:));
                        


                        
                        
                    else
                        
                        sigunits = anyTemp < ops.plotAlpha;

                        ipsiTempsig = {};
                        contraTempsig = {};

                        for stim = 1:3
                            
                            ipsiTempsig{stim} = ipsiTemp(sigunits(:,stim),stim);
                            contraTempsig{stim} = contraTemp(sigunits(:,stim), stim);
                            
                            anyTable{1,genotype}{mouse,window}(stim) = numel(anyTemp(sigunits(:,stim),stim));                               
                        end    
                        
                        sigUnitsC = cellfun(@(x) x < ops.plotAlpha, contraTempsig, 'Uni', false);
                        sigUnitsI = cellfun(@(x) x < ops.plotAlpha, ipsiTempsig, 'Uni', false);

                        for stim = 1:3
                            ipsiTable{1,genotype}{mouse,window}(stim) = numel(ipsiTempsig{stim}(sigUnitsI{stim}));
                            contraTable{1,genotype}{mouse,window}(stim) = numel(contraTempsig{stim}(sigUnitsC{stim}));
                                                     
                        end   
                       
                    end
                end
            end

           
        end
    end

    % plot figures now
    close all

    g{1} = figure(1); clf;
    g{1}.WindowState = 'Maximized';

    g{2} = figure(2); clf;
    g{2}.WindowState = 'Maximized';

    g{3} = figure(3); clf;
    g{3}.WindowState = 'Maximized';

    g{4} = figure(4); clf;
    g{4}.WindowState = 'Maximized';

    g{5} = figure(5); clf;
    g{5}.WindowState = 'Maximized';

    plotType = {'Ipsi significant units', 'Total significant units', 'Contra significant units',...
        'Fraction of units ipsilateral stim', 'Fraction of units contralateral stim'};
    stimTypes = {'10hz', '20hz', '40hz', 'any freq'};
    windows = cell2mat(cellfun(@(x) str2num(x), ops.WindowNames, 'Uni', false));
    ufreq = [10,20,40,20];
    
    ylabels = {'Mean unit#/animal', 'Mean unit#/animal','Mean unit#/animal', 'Mean fraction/animal', 'Mean fraction/animal'};
    colors = {'r', 'k'};
        % now for each genotype and window make a cell array with different 
        mean ={};
        data = {};
        ci = {};
    for genotype = 1: numel(uGenotypes)
        for window = 1:numel(ops.WindowNames)
            data{1,window}  = cell2mat(ipsiTable{genotype}(:,window));
            data{3,window} = cell2mat(contraTable{genotype}(:,window));
            data{2,window} = cell2mat(anyTable{genotype}(:,window)); 
            data{4,window} = cell2mat(ipsiTable{genotype}(:,window))./cell2mat(anyTable{genotype}(:,window));
            data{4,window}(isnan(data{4})) = 0;
            data{5,window} = cell2mat(contraTable{genotype}(:,window))./cell2mat(anyTable{genotype}(:,window));
            data{5,window}(isnan(data{5})) = 0;
            for plotNum = 1 : numel(plotType)
                
                
                for stim = 1:width(data{plotNum})
                    try
                    [mean{plotNum}{stim,window}, ~, ~, ci{plotNum}{stim, window}] = MMath.MeanStats(data{plotNum,window}(:,stim), 1);
                    catch
                        mean{plotNum}{stim,window} = 0;
                        ci{plotNum}{stim, window} = [0;0];
                    end
                end
            end    
        end

        for plotNum = 1 : numel(plotType)
            
            
            for stim = 1:height(mean{plotNum})
                figure(g{plotNum})
                h =subplot(height(mean{plotNum}),1, stim , 'parent', g{plotNum});
                hold(h, 'on')
                plot(windows + (2*genotype-3), cell2mat(mean{plotNum}(stim,:)), '-o', 'Color', ...
                    colors{genotype}, 'linewidth', 2);
                for window = 1:numel(windows)
                    
                    plot(windows(window) + (2*genotype-3), data{plotNum, window}(:,stim), 'x', 'Color', ...
                        colors{genotype}, 'MarkerSize', 10);
                end
                cistim = cell2mat(ci{plotNum}(stim,:));
                errorbar(windows + (2*genotype-3), cell2mat(mean{plotNum}(stim,:)), cell2mat(mean{plotNum}(stim,:))-cistim(1,:),...
                    cistim(2,:)-cell2mat(mean{plotNum}(stim,:)),  'Color',  colors{genotype}, 'linewidth', 2);
                xlim([0,320])
                xticks([0, windows])
                xticklabels(['0', ops.WindowNames]);
                ylabel(ylabels{plotNum});
                title(stimTypes{stim});
                if stim ==height(mean{plotNum})
                    xlabel('Window (ms)');
                end

                ylims = ylim;
                if genotype == numel(uGenotypes)
                    MPlot.Blocks([0,1000/ufreq(stim)*3], [0,ylims(2)],[0 0.8 1.0], 'FaceAlpha', 0.3);
                    ylim([0,ylims(2)]);
                end
                if ismember(plotNum, [4,5])
                    ylim([0,1])
                end
                hold(h, 'off')

                
            end
            sgtitle(plotType{plotNum})
           
        end


    end 

    
    for plotNum = 1:numel(plotType)
        savefig(g{plotNum}, fullfile(ops.savePath, ['Response vs window length ' plotType{plotNum} '.fig']));
        saveas(g{plotNum}, fullfile(ops.savePath, ['Response vs window length ' plotType{plotNum} '.png']));
    end

end

function IpsiresponsiveLatencies(ops, metadataTable, meanFRTable )
    keyboard;
    close all   
    ops.plotAlpha = 0.005;
    windowNames = ops.WindowNames;
    uGenotypes = unique(metadataTable.genotype);
    ipsi = cell(1,numel(windowNames));
    contra = cell(1,numel(windowNames));
    for window = 1:numel(windowNames)
        tic;
        ipsi{window} = cell(1,numel(uGenotypes));
        contra{window}  = cell(1,numel(uGenotypes));
        for genotype = 1: numel(uGenotypes)
            mouseNames = metadataTable.Properties.RowNames(strcmp(metadataTable.genotype, uGenotypes{genotype}));
          
            for mouse = 1:numel(mouseNames)
             
                pvalIpsi = metadataTable.pvalIpsi{mouseNames{mouse}};
                FRMouse = meanFRTable.meanFR{mouseNames{mouse}};
                pvalContra = metadataTable.pvalContra{mouseNames{mouse}};
                pvalAny = metadataTable.pvalBoth{mouseNames{mouse}};
                windowNames = pvalIpsi.Properties.VariableNames;
    %                 sessNames = pvalIpsi.Properties.RowNames;
               
                ipsiTemp = cell2mat(cellfun(@(x) cell2mat(table2cell(x)), pvalIpsi.(windowNames{window}), 'UniformOutput', false));
                
                contraTemp = cell2mat(cellfun(@(x) cell2mat(table2cell(x)), pvalContra.(windowNames{window}), 'UniformOutput', false));
                anyTemp = cell2mat(cellfun(@(x) cell2mat(table2cell(x)), pvalAny.(windowNames{window}), 'UniformOutput', false));
                FRWindow =  cellfun(@(x) table2cell(x), FRMouse.('300'), 'UniformOutput', false);
                FRWindow = vertcat(FRWindow{:}); 
                if size(anyTemp,2) >3
                    anyTemp = anyTemp(:,1:3);
                    ipsiTemp = ipsiTemp(:,1:3);
                    contraTemp = contraTemp(:,1:3);                  
                    FRWindow = FRWindow(:, 1:3);
                    pvalStim = 1:3;
                    
                else
                    pvalStim = 2;
                end

                         
                % finrst get pvals for units that are significant
                % in either stim sides
                sigUnits = anyTemp < ops.plotAlpha;
                sumlogic = sum(sigUnits,2);
                sigUnits = sumlogic>0;
                
                
                % find ipsi units that are significant in any freq
                
                ipsiTemp = ipsiTemp(sigUnits,:);
                contraTemp = contraTemp(sigUnits,:);
                FRWindow = FRWindow(sigUnits, :);


                sigUnits = ipsiTemp < ops.plotAlpha;
                sumlogic = sum(sigUnits,2);
                sigUnits = sumlogic>0;

                ipsiFR = FRWindow(sigUnits,:);

                sigUnits = contraTemp < ops.plotAlpha;
                sumlogic = sum(sigUnits,2);
                sigUnits = sumlogic>0;

                contraFR = FRWindow(sigUnits,:); 
                
                contra{window}{genotype}(end+1:end+height(contraFR), pvalStim) = contraFR;
                ipsi{window}{genotype}(end+1:end+height(ipsiFR), pvalStim) = ipsiFR;
                

            end

           
        end
        toc;
    end

    % plot for each window and genotype
    stimNames = pvalIpsi.(windowNames{window}){1}.Properties.VariableNames;
    stimNames = stimNames(1:3);
    for window =1: numel(windowNames)
        close all
        g = figure(1);clf;
        g.WindowState='maximized';
        
      
        for geno = 1: numel(ipsi{window})
            for stim = 1:width(ipsi{window}{geno})

                
                ipsicells = vertcat(ipsi{window}{geno}(:,stim));
                ipsicells = cellfun(@(x) table2cell(x), ipsicells, 'UniformOutput', false);
                ipsicells = vertcat(ipsicells{:});    

                contracells = vertcat(contra{window}{geno}(:,stim));
                contracells = cellfun(@(x) table2cell(x), contracells, 'UniformOutput', false);
                contracells = vertcat(contracells{:});   
               
                        
                
                
      
                ipsilatency= [];
                
                gg = figure(100*stim); clf;
                gg.WindowState = 'Maximized';
                rowNums = ceil(height(ipsicells)/ 15);
                for unitNum =1:height(ipsicells)

                    bins = ipsicells{unitNum,1};                
                    
                    baseline = find(bins>=-ops.windows(window) & bins<=0);
                    postWindow = find(bins>0 & bins<=ops.windows(window)); 
                    if isempty(postWindow)
                        continue;
                    end

                    winTime = find(bins>=-ops.windows(window) & bins<=ops.windows(window)); 
                    try
                        ipsiFRpost = ipsicells{unitNum,4}(postWindow);
                    catch
                        continue;
                    end
                    ipsiFRtimepost = ipsicells{unitNum,1}(postWindow);
                    ipsiFRpre = mean(ipsicells{unitNum,4}(baseline));
                    if max(ipsiFRpost)-ipsiFRpre >= ipsiFRpre- min(ipsiFRpost)
                        maxResp= max(ipsiFRpost);
                    else
                        maxResp= min(ipsiFRpost);
                    end

                    ipsifrCrossBin = find(ipsiFRpost==maxResp, 1);


%                     ipsifrCrossBin = find(ipsiFRpost< min(ipsicells{unitNum,5}(:,baseline),[], 'All')| ipsiFRpost> max(ipsicells{unitNum,5}(:,baseline),[], 'All'),1);
%                     ipsifrCrossBin = find(ipsiFRpost< mean(ipsicells{unitNum,5}(1,baseline))| ipsiFRpost> mean(ipsicells{unitNum,5}(2,baseline)),1);
                    if ~isempty(ipsifrCrossBin)
                        ipsilatency(unitNum) = ipsiFRtimepost(ipsifrCrossBin);
                    else
                        ipsilatency(unitNum) = nan;
                    end

                    h2 = subplot(rowNums, 15, unitNum);
                    hold (h2,'on');
                    plot(ipsicells{unitNum,1}(winTime), ipsicells{unitNum,4}(winTime), 'color', 'k');
                    MPlot.ErrorShade(ipsicells{unitNum,1}(winTime), ipsicells{unitNum,4}(winTime),ipsicells{unitNum,5}(2,winTime), ...
                                ipsicells{unitNum,5}(1,winTime), 'color','b', 'Alpha', 0.3, 'IsRelative', false); 
                    yLimits = ylim();
                    MPlot.PlotPointAsLine(ipsilatency(unitNum),yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '-', ...
                            'color',[1 0.5 0.5], 'linewidth', 1);
                    MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--', ...
                            'color',[0.5 0.5 0.5], 'linewidth', 1);
                    hold (h2,'off');
                
                end
                sgtitle([stimNames{stim} ' ' uGenotypes{geno} ' IpsiResponsesLatencies']);
                savefig(gg, fullfile(ops.savePath, windowNames{window}, [stimNames{stim} ' ' uGenotypes{geno} ' IpsiResponsesLatencies.fig']));
                saveas(gg, fullfile(ops.savePath, windowNames{window},[stimNames{stim} ' ' uGenotypes{geno} ' IpsiaResponsesLatencies.png']));


                gg = figure(100*stim+ 1); clf;
                gg.WindowState = 'Maximized';
                rowNums = ceil(height(contracells)/ 15);

                contralatency= [];
                contralatency2= [];
                for unitNum =1:height(contracells)
                    bins = contracells{unitNum,1};                
                    
                    baseline = find(bins>-ops.windows(window) & bins<=0);
                    postWindow = find(bins>0 & bins<ops.windows(window)); 
                    if isempty(postWindow)
                        continue;
                    end

                    try
                        contraFRpost = contracells{unitNum,4}(postWindow);
                    catch
                        continue;
                    end
                    contraFRtimepost = contracells{unitNum,1}(postWindow);

                    contraFRpre = mean(contracells{unitNum,4}(baseline));
                    
                    if max(contraFRpost)-contraFRpre >= contraFRpre- min(contraFRpost)
                        maxResp= max(contraFRpost);
                    else
                        maxResp= min(contraFRpost);
                    end

                    contrafrCrossBin = find(contraFRpost==maxResp, 1);
%                     contrafrCrossBin = find((contraFRpost< min(contracells{unitNum,5}(:,baseline),[],'All'))| ...
%                         (contraFRpost> max(contracells{unitNum,5}(:,baseline),[],'All')),1);
%                     contrafrCrossBin = find(contraFRpost< mean(contracells{unitNum,5}(1,baseline))| contraFRpost> mean(contracells{unitNum,5}(2,baseline)),1);
                    if ~isempty(contrafrCrossBin)
                        contralatency(unitNum) = contraFRtimepost(contrafrCrossBin);
                    else
                        contralatency(unitNum) = nan;
                    end

                    h2 = subplot(rowNums, 15, unitNum);
                    hold (h2,'on');
                    plot(contracells{unitNum,1}(winTime), contracells{unitNum,4}(winTime), 'color', 'k');
                    MPlot.ErrorShade(contracells{unitNum,1}(winTime), contracells{unitNum,4}(winTime),contracells{unitNum,5}(2,winTime), ...
                                contracells{unitNum,5}(1,winTime), 'color','r', 'Alpha', 0.3, 'IsRelative', false); 
                    yLimits = ylim();
                   MPlot.PlotPointAsLine(contralatency(unitNum),yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '-', ...
                            'color',[0.5 0.5 1], 'linewidth', 1);
                    MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--', ...
                            'color',[0.5 0.5 0.5], 'linewidth', 1);
                    hold (h2,'off');
                end
                sgtitle([stimNames{stim} ' ' uGenotypes{geno} ' ContraResponsesLatencies']);
                savefig(gg, fullfile(ops.savePath, windowNames{window}, [stimNames{stim} ' ' uGenotypes{geno} ' ContraResponsesLatencies.fig']));
                saveas(gg, fullfile(ops.savePath, windowNames{window},[stimNames{stim} ' ' uGenotypes{geno} ' ContraResponsesLatencies.png']));



                contralatency(isnan(contralatency)) = [];
                ipsilatency(isnan(ipsilatency)) = [];
    
                contracolors = {[0.7 0 0]; [1 0 0]};
                ipsicolors = {[0 0 0.7]; [0 0 1]};
                c = figure(1);
                
                h1 = subplot(3,1,stim);
                hold(h1, 'on')
                edges = [0:ops.binWidth:ops.windows(window)]*1000;
                [counts, ~] = histcounts(contralatency*1000, edges);
                % Calculate cumulative sum of counts and then divide by the total number of observations
                cumulativeCounts = cumsum(counts);
                cumulativeProbabilities = cumulativeCounts / length(contralatency);
                stairs(edges(1:end-1), cumulativeProbabilities, 'LineWidth', 3, 'color', contracolors{geno});

                [counts, ~] = histcounts(ipsilatency*1000, edges);
                % Calculate cumulative sum of counts and then divide by the total number of observations
                cumulativeCounts = cumsum(counts);
                cumulativeProbabilities = cumulativeCounts / length(ipsilatency);
                stairs(edges(1:end-1), cumulativeProbabilities, 'LineWidth', 3, 'color', ipsicolors{geno});
                
                if geno==2
                    title(stimNames{stim})
                    legend({'KO Contra', 'KO Ipsi', 'WT Contra', 'WT Ipsi'}, 'Location', 'Northwest')
                    xlabel('Time(ms)')
                    ylabel('CDF of responsive units')
                    
                end
                
               
        
            end
        end
        
        savefig(g, fullfile(ops.savePath, windowNames{window}, [' ContraIpsiresponsiveLatenciesCDFs.fig']));
        saveas(g, fullfile(ops.savePath, windowNames{window},[' ContraIpsiresponsiveLatenciesCDFs.png']));
    


    end



               
end

function PlotHisto(allVars,plotAlpha, savePath, binWidth)
    load(allVars, 'ops', 'ufreq', 'uGenotypes',  'pvals',  'histoInfoFinal');
    close all   
    ops.plotAlpha = plotAlpha;
    ops.savePath = savePath;
    % pvals is pvalmin, pvalcontra,pvalipsi
    % just signify according to allpvals
    for allpvals = 1   
        % load histology_wM1
%         histTable = readtable('G:\VC03_RoboKO\EphysPassiveStimSEs\Histology\Histology_wM1.csv');
        
        
        % directory of reference atlas files
        annotation_volume_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\annotation_volume_10um_by_index.npy';
        structure_tree_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\structure_tree_safe_2017.csv';
        template_volume_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\template_volume_10um.npy';
        
        probes_to_analyze = 'all';  % [1 2]
        % distance queried for confidence metric -- in um
        probe_radius = 200; 
        
        % overlay the distance between parent regions in gray (this takes a while)
        show_parent_category = false; 
        
        % plot this far or to the bottom of the brain, whichever is shorter -- in mm
        distance_past_tip_to_plot = 0.0;
        
        % plane used to view when points were clicked ('coronal' -- most common, 'sagittal', 'transverse')
        plane = 'coronal';
        
        % probe insertion direction 'down' (i.e. from the dorsal surface, downward -- most common!) 
        % or 'up' (from a ventral surface, upward)
        probe_insertion_direction = 'down';
        
        % set scaling e.g. based on lining up the ephys with the atlas
        % set to *false* to get scaling automatically from the clicked points
        scaling_factor = false;
        
        % show a table of regions that the probe goes through, in the console
        show_region_table = false;
              
        % black brain?
        black_brain = true;
        
        
        
        % GET AND PLOT PROBE VECTOR IN ATLAS SPACE
        
        % load the reference brain annotations
        if ~exist('av','var') || ~exist('st','var')
            disp('loading reference atlas...')
            av = readNPY(annotation_volume_location);
            st = loadStructureTree(structure_tree_location);
        end
        
        % select the plane for the viewer
        if strcmp(plane,'coronal')
            av_plot = av;
        elseif strcmp(plane,'sagittal')
            av_plot = permute(av,[3 2 1]);
        elseif strcmp(plane,'transverse')
            av_plot = permute(av,[2 3 1]);
        end
        
        
            
        % convert error radius into mm
        error_length = round(probe_radius / 10);
            
        
        
        
       

%         markers = {'x', 'o'};
        for genotype = numel(pvals):-1:1 
            close all
        
            fwireframe = [];
            
            
            % create a new figure with wireframe
            fwireframe = plotBrainGrid([], [], fwireframe, black_brain);
            fwireframe.WindowState='Maximized';
            hold on; 
            fwireframe.InvertHardcopy = 'off';
            bregma = allenCCFbregma(); % bregma position in reference data space
            atlas_resolution = 0.010; % mm
            bregma_res = bregma*atlas_resolution;
            
            
            figure(fwireframe);
            plot3(bregma(1),bregma(3),bregma(2), '*', 'color',[1 0 0],'markers',5);
            

            for recSite =numel(pvals{genotype}):numel(pvals{genotype})
                if ~isempty(pvals{genotype}{recSite})
                    allHisto= histoInfoFinal{genotype}{recSite};

                    pvalAll = pvals{genotype}{recSite};
                    emptypval = cellfun(@isempty, pvalAll);
                    pvalAll(emptypval) =[];
%                     allHisto(emptypval) =[];

                    if allpvals
                        
                        pvalSess = cell2mat(cellfun(@(x) x(:,1), pvalAll, 'UniformOutput',false));
                        if size(pvalSess,2) >3
                           pvalSess = pvalSess(:,1:3);
                        end
                        
                        sigUnits = pvalSess < ops.plotAlpha;
                        sumlogic = sum(sigUnits,2);
                        sigUnits = sumlogic>0;

                        
                        % find ipsi units that are significant in any freq
                        pvalAll = cellfun(@(x) x(sigUnits, :), pvalAll, 'UniformOutput',false);
                        allHisto = cellfun(@(x) x(sigUnits, :), allHisto, 'UniformOutput',false);
                        if size(pvalAll,2) >3
                           pvalAll = pvalAll(:,1:3);
                        end



                        
                        pvalIpsiSess = cell2mat(cellfun(@(x) x(:,3), pvalAll, 'UniformOutput',false));
                        pvalContraSess = cell2mat(cellfun(@(x) x(:,2), pvalAll, 'UniformOutput',false));
                        

                        sigUnitsIpsi = pvalIpsiSess < ops.plotAlpha;
                        sumlogic = sum(sigUnitsIpsi,2);
                        sigUnitsIpsi = sumlogic>0;

                        sigUnitsContra = pvalContraSess < ops.plotAlpha;
                        sumlogic = sum(sigUnitsContra,2);
                        sigUnitsContra = sumlogic>0;

                        sigIpsiOnly = sigUnitsIpsi & ~sigUnitsContra;
                        sigContraOnly = sigUnitsContra & ~sigUnitsIpsi;
                        sigBoth = sigUnitsContra & sigUnitsIpsi;

                        allHisto = allHisto{1};
                        allHistoIpsi = allHisto(sigIpsiOnly,:);
                        allHistoContra = allHisto(sigContraOnly,:);
                        allHistoBoth = allHisto(sigBoth,:);

                        PlotHistoUnitsHelper(fwireframe, allHistoIpsi, bregma,'.', 'b');
                        PlotHistoUnitsHelper(fwireframe, allHistoContra, bregma, '.', 'r');
                        PlotHistoUnitsHelper(fwireframe, allHistoBoth, bregma, '.', 'w');
                        


                    else
                        sigUnits = cellfun(@(x) x(:,1)<ops.plotAlpha, pvalAll, 'UniformOutput', false);
                        pvalAll = cellfun(@(x,y) x(y,:), pvalAll, sigUnits, 'UniformOutput', false);
                        allHisto = cellfun(@(x,y) x(y,:), allHisto, sigUnits, 'UniformOutput', false);
                        
                    end
                end
                
               
                
                
                
                
                

            end 


            
            [AZ,EL] = view;
            view([0,0]);
            

            saveFolder= fullfile(ops.savePath,'BrainviewAngles', uGenotypes{genotype});
            if ~isfolder(saveFolder)
                mkdir(saveFolder);
            end

            file_pattern = fullfile(saveFolder, '*');
            delete(file_pattern);
            azAngles = 0:-1:-90;
            axis tight;
            set(gca, 'Position', [-0.4, -0.4, 1.8,1.8]);
            parfor azAngle = 1:numel(azAngles)     
                view([azAngles(azAngle),0]);
                print(fwireframe, fullfile(saveFolder, [num2str(azAngle) '.png']), '-dpng', '-r300');
            end

            % make an .avi
            png_files = dir(fullfile(saveFolder, '*.png'));
            numbers = cell2mat(cellfun(@(x) sscanf(x, '%d.png'), {png_files.name}, 'UniformOutput', false));
           [B,inds] = sort(numbers);
           png_files = png_files(inds);

            videoPath = fullfile(saveFolder, [uGenotypes{genotype} '.mp4']);
            if isfile(videoPath)
                delete(videoPath)
            end

            % Create a VideoWriter object
            output_video = VideoWriter(videoPath, 'MPEG-4');
            output_video.FrameRate = 60; % Set frame rate to 60 fps
            
            % Open the video file for writing
            open(output_video);
          
            % Loop through each PNG file and add it to the video
            for azAngle = 1:numel(png_files)
                % Read the PNG image
                image_filename = fullfile(saveFolder, png_files(azAngle).name);
                img = imread(image_filename);
                
                % Write the image to the video
                writeVideo(output_video, img);
            end

            for azAngle = numel(png_files):-1:1
                % Read the PNG image
                image_filename = fullfile(saveFolder, png_files(azAngle).name);
                img = imread(image_filename);
                
                % Write the image to the video
                writeVideo(output_video, img);
            end
            
            % Close the video file
            close(output_video);




            savefig(fwireframe, fullfile(ops.savePath, ['allpvals = ' num2str(allpvals) '  genotype ' uGenotypes{genotype} ' Histoplot.fig']));
            
        end

        
        
        
        
       


      



               
    end
end

function MakeFigures(allVars, plotAlpha)
    % plot allMeanFR for all the stimDur
    
    load(allVars, 'allSpikeTimes', 'maxAdc', 'ops', 'bodysidefinal','ufreq','uGenotypes', 'inputrecSites', 'adcFinal', 'plotLims', 'pvals', 'allMeanFR');
    ops.plotAlpha = plotAlpha;
    pvalsBackup = pvals;

    for genotype = 1: numel(allSpikeTimes)
            
        for recSite =1:numel(allSpikeTimes{genotype})
            maxAdcgenotype = maxAdc{genotype}{recSite};
            if isempty(maxAdcgenotype)
                continue;
            end
            [maxadcfig rows] = max(maxAdcgenotype(1,:));
             if maxadcfig <0.1
                fM = 10e4;
        %                 fM = 1;
            else
                fM =10;
                
            end
            
            maxadcfig = maxadcfig*fM; 
            close all
        
            % done for left as the first one and right as the second
            % spikeTimes
            color = {'b', 'r'};
            
            
            
        
            for allpvals = 0:ops.allpvals
                spikeTimes ={};
                sigUnits = {};
                pvals = pvalsBackup;
                if allpvals
                    
                   
                    sessions7 = find(bodysidefinal{genotype}{recSite}{2}==1);
        
                    sessions8 = find(bodysidefinal{genotype}{recSite}{2}==0);
                    if ~isempty(sessions7)
                        
                        pvalsfake{1,1}(sessions7) = ones(size(sessions7));
                        pvalsfake{1,1}(sessions8) = pvals{genotype}{recSite}{1,1};
                        pvalsfake{1,3}(sessions7) = ones(size(sessions7));
                        pvalsfake{1,3}(sessions8) = pvals{genotype}{recSite}{1,3};
                        pvalsfake{1,4}(sessions7) = ones(size(sessions7));
                        pvalsfake{1,4}(sessions8) = pvals{genotype}{recSite}{1,4};
                        pvalsfake{1,2} = pvals{genotype}{recSite}{1,2};
                        pvals{genotype}{recSite} = pvalsfake;
                    end
                    
                    % need to get the 20hz only sessions out               
                    empty = cell2mat(cellfun(@(x) isempty(x), pvals{genotype}{recSite}, 'UniformOutput', false));
                    
                    pvals{genotype}{recSite}(empty) = [];
                    pvals{genotype}{recSite} = cellfun(@(x) x(:,1), pvals{genotype}{recSite}, 'UniformOutput', false);         
                    
                    pvals2 = cell2mat(pvals{genotype}{recSite});
                    pvalsLogic = pvals2<ops.plotAlpha;
                    pvalsLogiwwc = pvalsLogic(:,1:3);
                    pvalSum = sum(pvalsLogic,2);
                    sigUnits = pvalSum>0;
                    
                else
                    sessions7 =[];
                end
                
                for stimDur = 1:numel(ufreq)
                   % creat uifigure
                    g{stimDur} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz spikeRaster'],'NumberTitle','off'); clf;
                    g{stimDur}.WindowState = 'Maximized';

                    gg{stimDur} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz FR'],'NumberTitle','off'); clf;
                    gg{stimDur}.WindowState = 'Maximized';
                    
                    % spikeTimes
                    spikeTimes{stimDur} = allSpikeTimes{genotype}{recSite}{stimDur};                        
                    spikeTimes{stimDur} = SignifyFR(spikeTimes{stimDur}, allpvals, sigUnits, ops.plotAlpha, 4, sessions7, stimDur);               
                    spikeTimes{stimDur} = sortrows(spikeTimes{stimDur},3);

                    % FR plots
                    meanFR{stimDur} = allMeanFR{genotype}{recSite}{stimDur};                        
                    meanFR{stimDur} = SignifyFR(meanFR{stimDur}, allpvals, sigUnits, ops.plotAlpha, 7, sessions7, stimDur);               
                    meanFR{stimDur} = sortrows(meanFR{stimDur},6);
                    


                    % Set the number of subplots and rows                        
                    plotRows = max(3,ceil(height(spikeTimes{stimDur})/15));
                    

                    for unitNum =1:height(spikeTimes{stimDur})
    
                        figure(g{stimDur});         
                        %sort each meanFR cell by depth                   
                        h = subplot(plotRows,15,unitNum, 'Parent', g{stimDur});                                  
                        hold(h, 'on');
                        % plot left trials
                        for i = 1: height(spikeTimes{stimDur}{unitNum,1})
                            MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,1}{i}, i*ones(numel(spikeTimes{stimDur}{unitNum,1}{i}),1) ,1, 'orientation', 'vertical', ...
                                'linestyle', '-','color', color{1}, 'linewidth', 1);
                        end
                        totalTrials = height(spikeTimes{stimDur}{unitNum,2})+ height(spikeTimes{stimDur}{unitNum,1});
                        xLimits = get(gca,'XLim');
                        MPlot.PlotPointAsLine(0,i+1,xLimits(2), 'orientation', 'horizontal', 'linestyle', '--', ...
                            'color',[0 0 0], 'linewidth', 1);
                        % plot right trials
                        for i = 1+height(spikeTimes{stimDur}{unitNum,1}): totalTrials
                            rInd = i  -height(spikeTimes{stimDur}{unitNum,1});
                            MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,2}{rInd}, (i+1)*ones(numel(spikeTimes{stimDur}{unitNum,2}{rInd}),1) ,1, 'orientation', 'vertical', ...
                                'linestyle', '-','color', color{2}, 'linewidth', 1);
                        end                         
                    
                        yLimits = get(gca,'YLim');                    
                        plot(adcFinal{genotype}{recSite}{stimDur}(1,:), (adcFinal{genotype}{recSite}{stimDur}(2,:)*fM) +  totalTrials+5+1, ...
                            'k', 'lineWidth', 1);                            
                        yLimits = get(gca,'YLim');
                        MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--', ...
                            'color',[0.5 0.5 0.5], 'linewidth', 1);
    %                     xlabel('epoch time (s)');
    %                     ylabel('Trials');  
                        yLimits = get(gca,'YLim');
                        ylim([0, yLimits(2)])
                        xlim(plotLims{stimDur});                            
                        title({[num2str(spikeTimes{stimDur}{unitNum,3}) ' \mum']},{['Cbias = '  num2str(spikeTimes{stimDur}{unitNum,5})]});                    
                        box off  
                        outerpos = get(h,'OuterPosition');
                        ti = get(h,'TightInset');
                        left = outerpos(1) + ti(1);
                        bottom = outerpos(2) + ti(2);
                        ax_width = outerpos(3) - ti(1) - ti(3);
                        ax_height = outerpos(4) - ti(2) - ti(4)-0.01;
                        set(h,'Position',[left bottom ax_width ax_height], 'fontsize', 10);                            
                        hold(h, 'off');
                    
                        % plot FR subplots here

                       figure(gg{stimDur});  
                        %sort each meanFR cell by depth                           
                        hh = subplot(plotRows,15,unitNum, 'Parent', gg{stimDur});                                  
                        hold(hh, 'on');                               
                        plot(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 2}, ...
                            color{1}, 'LineWidth', 1);
                        plot(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 3}, ...
                            color{2}, 'LineWidth', 1);                                
                        if ~isempty(meanFR{stimDur}{unitNum, 2})                                
                            MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 2}, meanFR{stimDur}{unitNum, 4}(2,:), ...
                                meanFR{stimDur}{unitNum, 4}(1,:), 'color',color{1}, 'Alpha', 0.3, 'IsRelative', false);                                        
                        end            
                        if ~isempty(meanFR{stimDur}{unitNum, 4})                                
                            MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 3}, meanFR{stimDur}{unitNum, 5}(2,:), ...
                                meanFR{stimDur}{unitNum, 5}(1,:), 'color',color{2}, 'Alpha', 0.3, 'IsRelative', false);                                                        
                        end                        
                        yLimits = get(gca,'YLim');                      
                        plot(adcFinal{genotype}{recSite}{stimDur}(1,:), (adcFinal{genotype}{recSite}{stimDur}(2,:)*fM) +  yLimits(2), ...
                            'k', 'lineWidth', 1);
                        yLimits = get(gca,'YLim');
                        MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
        %                 xlabel('epoch time (s)');
        %                 ylabel('FR');  
                        yLimits = get(gca,'YLim');
                        ylim([0, yLimits(2)]);
                        xlim(plotLims{stimDur}); 
                        title({[num2str(spikeTimes{stimDur}{unitNum,3}) ' \mum']},{['Cbias = '  num2str(spikeTimes{stimDur}{unitNum,5})]});                    

                        title({[num2str(meanFR{stimDur}{unitNum,6}) ' \mum']},{['Cbias = '  num2str(meanFR{stimDur}{unitNum,8})]});                    
                        box off  
                        outerpos = get(hh,'OuterPosition');
                        ti = get(hh,'TightInset');
                        left = outerpos(1) + ti(1);
                        bottom = outerpos(2) + ti(2);
                        ax_width = outerpos(3) - ti(1) - ti(3);
                        ax_height = outerpos(4) - ti(2) - ti(4)-0.01;
                        set(hh,'Position',[left bottom ax_width ax_height], 'fontsize', 10);     
                        hold(hh, 'off');

            
    
                    end                        
        
                    savePath2 = [ops.savePath ' allpvals =  ' num2str(allpvals)];
        
                    if ~exist(savePath2, 'dir')
                        mkdir(savePath2);
                    end
        
                   
                
                    savefig(g{stimDur},fullfile(savePath2,  [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz significant units_rasters.fig']));
                    saveas(g{stimDur},fullfile(savePath2,  [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz significant units_rasters.png']));
                    savefig(gg{stimDur},fullfile(savePath2,  [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz significant units_FRs.fig']));
                    saveas(gg{stimDur},fullfile(savePath2,  [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz significant units_FRs.png']));
                end
        
            end
    
        end
    end
end

function PlotAvgTracesFRFinal(dataFileTb, ops, metadataTable, FRdataTable, window, maxFR)
    genotypes = metadataTable.genotype;
    
    uGenotypes = unique(genotypes);
    close all;

   
    
    czData = cell(1,3);
    izData = cell(1,3); 
%     colors = {[100/255 0 0];  [0 0 100/255]; [1 0 0] ; [0 0 1]};
    colors = {[1 0 0] ; [0 0 1]; [1 0 0] ; [0 0 1]};
    

   fileID = fopen(fullfile(ops.savePath,  ['Peak values pop mean FR.txt']), 'w'); % Replace 'yourfile.txt' with your filename

    g = figure(1); clf;
    set(g, 'Units', 'inches', 'Position', [1,1,3,3]);
    stimNames = {'10 Hz', '20 Hz', '40 Hz'};
    
    for stim = 1:3
        if ~iscell(czData{stim})
            czData{stim} = cell(1,2);
            izData{stim} = cell(1,2);
        end
        for geno = 1:numel(uGenotypes)
           
            mouseNames = find(strcmp(uGenotypes(geno), genotypes));
            for ani = 1:numel(mouseNames)

                animalZ = FRdataTable{mouseNames(ani), 'meanFR'}{1}.('300');
%                     pvalIpsi = metadataTable{mouseNames(ani), 'pvalIpsi'}{1}.(window);
%                     pvalContra = metadataTable{mouseNames(ani), 'pvalContra'}{1}.(window);
                pvalAny = metadataTable{mouseNames(ani), 'pvalBoth'}{1}.(window);
                
                if stim > width(pvalAny{1})
                    continue;
                end
                for sessNum = 1:height(animalZ)

                    if width(pvalAny{sessNum})>3

                        pvalTemp = cell2mat(table2cell(pvalAny{sessNum}(:,"20hz")));
                        pstimDur = stim;
                    else
                        pvalTemp = cell2mat(table2cell(pvalAny{sessNum}));
                        pstimDur = stim+1;
                    end
                    pvalTemp = pvalTemp< ops.plotAlpha;
                    sumLogics = sum(pvalTemp,2);
                    sigUnits = sumLogics>0;
                    
                    sessFR = table2cell(animalZ{sessNum}(:,stim));
                    sessFR = vertcat(sessFR{:});
                    time = sessFR{1,1};
                    sessFR(:,2:3) = cellfun(@(x) mean(x,1), sessFR(:,2:3), 'UniformOutput', false);
                    
                    
                  

                    contraFR = cell2mat(sessFR(sigUnits,2));
                    ipsiFR = cell2mat(sessFR(sigUnits,3));
                    if ~iscell(czData{pstimDur})
                        czData{pstimDur} = cell(1,2);
                        izData{pstimDur} = cell(1,2);
                    end
                    startc = height(czData{pstimDur}{geno});
                    starti = height(izData{pstimDur}{geno});
                    czData{pstimDur}{geno}(startc+1:startc+height(contraFR),:) = contraFR;
                    izData{pstimDur}{geno}(starti+1:starti+height(ipsiFR),:) = ipsiFR;
                end


            end
            
            [meanContra, ~, ~, ciContra] = MMath.MeanStats(czData{stim}{geno},1);
            sampleRate = 0.0025;
            startind = find(time>0,1);
            endind = find(time<0.05, 1, 'last');
            


            statContra{stim}{geno} = mean(czData{stim}{geno}(:,startind:endind), 2);
            statIpsi{stim}{geno} = mean(izData{stim}{geno}(:,startind:endind), 2);

            [meanIpsi, ~, ~, ciIpsi] = MMath.MeanStats(izData{stim}{geno},1);
            if strcmp('KO', uGenotypes{geno})
                h =subplot(2,3,stim+3);  
                hold(h,'on')
                fprintf(fileID, [ 'KO: ' stimNames{stim} ' Peak for Contra: ' num2str(max(meanContra))...
                    'and Peak for Ipsi: ' num2str(max(meanIpsi))  '\n']);
                plot(time, meanContra, 'color', colors{geno*2-1}, 'LineWidth', 1);
                plot(time, meanIpsi, 'color', colors{geno*2}, 'LineWidth', 1);
                MPlot.ErrorShade(time, meanContra, ciContra(2,:), ...
                                ciContra(1,:), 'color',colors{geno*2-1}, 'Alpha', 0.3, 'IsRelative', false); 
                MPlot.ErrorShade(time, meanIpsi, ciIpsi(2,:), ...
                                ciIpsi(1,:), 'color',colors{geno*2}, 'Alpha', 0.3, 'IsRelative', false); 
                ylim([0, maxFR]);    
                xlim(ops.plotxLims)
                yLimits = get(gca,'YLim');
                MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', ...
                    'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
                
%                 xlabel('Time from stim onset(s)');
%                 
%                 ylabel({'Mean spiking rate','(hz)'});  
%                 title([uGenotypes{geno} ' Contra vs Ipsi'], 'FontSize', 36);
%                 if stim ==1
%                     legend({'Contra', 'Ipsi'});
%                 end

                h.LineWidth = 1;
                h.XTick = [ops.plotxLims(1):0.05:ops.plotxLims(2)];
                h.XTickLabel = arrayfun(@(x) num2str(x*1000), h.XTick, 'UniformOutput', false);
                h.TickLength = [0.05 0.05];
                h.XTickLabelRotation = 0;
                set(gca, 'FontSize', 8, 'FontName', 'Arial', 'TickDir', 'out');
                hold(h, 'off');
            else
                h =subplot(2,3,stim);  
                hold(h,'on')
                plot(time, meanContra, 'color', colors{geno*2-1}, 'LineWidth', 1);
                plot(time, meanIpsi, 'color', colors{geno*2}, 'LineWidth', 1);
                fprintf(fileID, [ 'WT: ' stimNames{stim} ' Peak for Contra: ' num2str(max(meanContra))...
                    'and Peak for Ipsi: ' num2str(max(meanIpsi))  '\n']);
                MPlot.ErrorShade(time, meanContra, ciContra(2,:), ...
                                ciContra(1,:), 'color',colors{geno*2-1}, 'Alpha', 0.3, 'IsRelative', false); 
                MPlot.ErrorShade(time, meanIpsi, ciIpsi(2,:), ...
                                ciIpsi(1,:), 'color',colors{geno*2}, 'Alpha', 0.3, 'IsRelative', false); 
                ylim([0, maxFR]);
                xlim(ops.plotxLims)
                yLimits = get(gca,'YLim');
                MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical',...
                    'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
              
                h.LineWidth = 1;
                h.XTick = [ops.plotxLims(1):0.05:ops.plotxLims(2)];
               
                h.XTickLabel = arrayfun(@(x) num2str(x*1000), h.XTick, 'UniformOutput', false);
                h.TickLength = [0.05 0.05];
                h.XTickLabelRotation = 0;
                set(gca, 'FontSize', 8, 'FontName', 'Arial', 'TickDir', 'out');
                hold(h, 'off');

            end



           
        end




    end
    

    
%     for geno = 1:numel(uGenotypes)
%         for stim = 1:3
    
    for geno = 1:numel(uGenotypes)
    
        pop1 = statContra{1}{geno};
        pop2 = statContra{2}{geno};
        pop3 = statContra{3}{geno};
    
        norm1 = adtest(pop1);
        norm2 = adtest(pop3);
        if norm1 && norm2
            [H pval] = ttest(pop3-pop1, 0, 'tail','right');
        end
        fprintf(fileID, [ uGenotypes{geno} ' 40Hz - 10 Hz ttest paired pvalue for contra ' num2str(pval)  '\n']);
    
    
        pop1 = statIpsi{1}{geno};
        pop2 = statIpsi{2}{geno};
        pop3 = statIpsi{3}{geno};
    
        norm1 = adtest(pop1);
        norm2 = adtest(pop3);
        if norm1 && norm2
            [H pval] = ttest(pop3-pop1, 0, 'tail','right');
        end
        fprintf(fileID, [ uGenotypes{geno} ' 40Hz - 10 Hz ttest paired pvalue for ipsi ' num2str(pval)  '\n']);
    end

   % KO Ipsi vs contra
   for geno = 1: numel(uGenotypes)
       for stim = 1:3
            pop2 = statContra{stim}{geno};
            pop1 = statIpsi{stim}{geno};
            
        
            norm1 = adtest(pop1);
            norm2 = adtest(pop2);
            if strcmp(uGenotypes{geno}, 'WT')
                [H pval] = ttest(pop2-pop1, 0, 'tail','right');
                fprintf(fileID, [ uGenotypes{geno} ' ' stimNames{stim} ' ipsi vs contra ttest paired pvalue ' num2str(pval)  '\n']);
            else
                [H pval] = ttest(pop2-pop1, 0, 'tail','both');
                fprintf(fileID, [ uGenotypes{geno} ' ' stimNames{stim} ' ipsi vs contra ttest paired pvalue ' num2str(pval)  '\n']);
            end
            
       end
   end




    fclose(fileID);

    savefig(g,fullfile(ops.savePath, ['Average FR figures window ' window ' ms.fig']));
    exportgraphics(g, fullfile(ops.savePath, ['Average FR figures window ' window ' ms.pdf']), 'Resolution', 1200);
  
   
end

function MakeFiguresNoannotation(allVars, plotAlpha, savePath)
    % plot allMeanFR for all the stimDur
    
    load(allVars, 'allSpikeTimes', 'maxAdc', 'ops', 'bodysidefinal','ufreq','uGenotypes', 'inputrecSites', 'adcFinal', 'plotLims', 'pvals', 'allMeanFR');
    ops.plotAlpha = plotAlpha;
    ops.savePath = savePath;
    pvalsBackup = pvals;

    for genotype = 1: numel(allSpikeTimes)
            
        for recSite =1:numel(allSpikeTimes{genotype})
            maxAdcgenotype = maxAdc{genotype}{recSite};
            if isempty(maxAdcgenotype)
                continue;
            end
            [maxadcfig rows] = max(maxAdcgenotype(1,:));
             if maxadcfig <0.1
                fM = 10e4;
        %                 fM = 1;
            else
                fM =10;
                
            end
            
            maxadcfig = maxadcfig*fM; 
            close all
        
            % done for left as the first one and right as the second
            % spikeTimes
            color = {'b', 'r'};
            
            
            
        
            for allpvals = 0:ops.allpvals
                spikeTimes ={};
                sigUnits = {};
                pvals = pvalsBackup;
                if allpvals
                    
                   
                    sessions7 = find(bodysidefinal{genotype}{recSite}{2}==1);
        
                    sessions8 = find(bodysidefinal{genotype}{recSite}{2}==0);
                    if ~isempty(sessions7)
                        
                        pvalsfake{1,1}(sessions7) = ones(size(sessions7));
                        pvalsfake{1,1}(sessions8) = pvals{genotype}{recSite}{1,1};
                        pvalsfake{1,3}(sessions7) = ones(size(sessions7));
                        pvalsfake{1,3}(sessions8) = pvals{genotype}{recSite}{1,3};
                        pvalsfake{1,4}(sessions7) = ones(size(sessions7));
                        pvalsfake{1,4}(sessions8) = pvals{genotype}{recSite}{1,4};
                        pvalsfake{1,2} = pvals{genotype}{recSite}{1,2};
                        pvals{genotype}{recSite} = pvalsfake;
                    end
                    
                    % need to get the 20hz only sessions out               
                    empty = cell2mat(cellfun(@(x) isempty(x), pvals{genotype}{recSite}, 'UniformOutput', false));
                    
                    pvals{genotype}{recSite}(empty) = [];
                    pvals{genotype}{recSite} = cellfun(@(x) x(:,1), pvals{genotype}{recSite}, 'UniformOutput', false);         
                    
                    pvals2 = cell2mat(pvals{genotype}{recSite});
                    pvalsLogic = pvals2<ops.plotAlpha;
                    pvalsLogiwwc = pvalsLogic(:,1:3);
                    pvalSum = sum(pvalsLogic,2);
                    sigUnits = pvalSum>0;
                    
                else
                    sessions7 =[];
                end
                
                for stimDur = 1:numel(ufreq)
                   % creat uifigure
                    g{stimDur} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz spikeRaster'],'NumberTitle','off'); clf;
                    g{stimDur}.WindowState = 'Maximized';

                    gg{stimDur} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz FR'],'NumberTitle','off'); clf;
                    gg{stimDur}.WindowState = 'Maximized';
                    
                    % spikeTimes
                    spikeTimes{stimDur} = allSpikeTimes{genotype}{recSite}{stimDur};                        
                    spikeTimes{stimDur} = SignifyFR(spikeTimes{stimDur}, allpvals, sigUnits, ops.plotAlpha, 4, sessions7, stimDur);               
                    spikeTimes{stimDur} = sortrows(spikeTimes{stimDur},3);

                    % FR plots
                    meanFR{stimDur} = allMeanFR{genotype}{recSite}{stimDur};                        
                    meanFR{stimDur} = SignifyFR(meanFR{stimDur}, allpvals, sigUnits, ops.plotAlpha, 7, sessions7, stimDur);               
                    meanFR{stimDur} = sortrows(meanFR{stimDur},6);
                    


                    % Set the number of subplots and rows                        
                    plotRows = max(3,ceil(height(spikeTimes{stimDur})/15));
                    

                    for unitNum =1:height(spikeTimes{stimDur})
    
                        figure(g{stimDur});         
                        %sort each meanFR cell by depth                   
                        h = subplot(plotRows,15,unitNum, 'Parent', g{stimDur});                                  
                        hold(h, 'on');
                        % plot left trials
                        for i = 1: height(spikeTimes{stimDur}{unitNum,1})
                            MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,1}{i}, i*ones(numel(spikeTimes{stimDur}{unitNum,1}{i}),1) ,1, 'orientation', 'vertical', ...
                                'linestyle', '-','color', color{1}, 'linewidth', 1);
                        end
                        totalTrials = height(spikeTimes{stimDur}{unitNum,2})+ height(spikeTimes{stimDur}{unitNum,1});
                        xLimits = get(gca,'XLim');
                        MPlot.PlotPointAsLine(0,i+1,xLimits(2), 'orientation', 'horizontal', 'linestyle', '--', ...
                            'color',[0 0 0], 'linewidth', 1);
                        % plot right trials
                        for i = 1+height(spikeTimes{stimDur}{unitNum,1}): totalTrials
                            rInd = i  -height(spikeTimes{stimDur}{unitNum,1});
                            MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,2}{rInd}, (i+1)*ones(numel(spikeTimes{stimDur}{unitNum,2}{rInd}),1) ,1, 'orientation', 'vertical', ...
                                'linestyle', '-','color', color{2}, 'linewidth', 1);
                        end                         
                    
                        yLimits = get(gca,'YLim');                    
                        plot(adcFinal{genotype}{recSite}{stimDur}(1,:), (adcFinal{genotype}{recSite}{stimDur}(2,:)*fM) +  totalTrials+5+1, ...
                            'k', 'lineWidth', 1);                            
                        yLimits = get(gca,'YLim');
                        MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--', ...
                            'color',[0.5 0.5 0.5], 'linewidth', 1);
    %                     xlabel('epoch time (s)');
    %                     ylabel('Trials');  
                        yLimits = get(gca,'YLim');
                        ylim([0, yLimits(2)])
                        xlim(plotLims{stimDur});                            
%                         title({[num2str(spikeTimes{stimDur}{unitNum,3}) ' \mum']},{['Cbias = '  num2str(spikeTimes{stimDur}{unitNum,5})]});                    
                        box off  
                        outerpos = get(h,'OuterPosition');
                        ti = get(h,'TightInset');
                        left = outerpos(1) + ti(1);
                        bottom = outerpos(2) + ti(2);
                        ax_width = outerpos(3) - ti(1) - ti(3);
                        ax_height = outerpos(4) - ti(2) - ti(4)-0.01;
                        set(h,'Position',[left bottom ax_width ax_height], 'fontsize', 10);                            
                        hold(h, 'off');
                    
                        % plot FR subplots here

                       figure(gg{stimDur});  
                        %sort each meanFR cell by depth                           
                        hh = subplot(plotRows,15,unitNum, 'Parent', gg{stimDur});                                  
                        hold(hh, 'on');                               
                        plot(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 2}, ...
                            color{1}, 'LineWidth', 1);
                        plot(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 3}, ...
                            color{2}, 'LineWidth', 1);                                
                        if ~isempty(meanFR{stimDur}{unitNum, 2})                                
                            MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 2}, meanFR{stimDur}{unitNum, 4}(2,:), ...
                                meanFR{stimDur}{unitNum, 4}(1,:), 'color',color{1}, 'Alpha', 0.3, 'IsRelative', false);                                        
                        end            
                        if ~isempty(meanFR{stimDur}{unitNum, 4})                                
                            MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}, meanFR{stimDur}{unitNum, 3}, meanFR{stimDur}{unitNum, 5}(2,:), ...
                                meanFR{stimDur}{unitNum, 5}(1,:), 'color',color{2}, 'Alpha', 0.3, 'IsRelative', false);                                                        
                        end                        
                        yLimits = get(gca,'YLim');                      
                        plot(adcFinal{genotype}{recSite}{stimDur}(1,:), (adcFinal{genotype}{recSite}{stimDur}(2,:)*fM) +  yLimits(2), ...
                            'k', 'lineWidth', 1);
                        yLimits = get(gca,'YLim');
                        MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
        %                 xlabel('epoch time (s)');
        %                 ylabel('FR');  
                        yLimits = get(gca,'YLim');
                        ylim([0, yLimits(2)]);
                        xlim(plotLims{stimDur}); 

%                         title({[num2str(meanFR{stimDur}{unitNum,6}) ' \mum']},{['Cbias = '  num2str(meanFR{stimDur}{unitNum,8})]});                    
                        box off  
                        outerpos = get(hh,'OuterPosition');
                        ti = get(hh,'TightInset');
                        left = outerpos(1) + ti(1);
                        bottom = outerpos(2) + ti(2);
                        ax_width = outerpos(3) - ti(1) - ti(3);
                        ax_height = outerpos(4) - ti(2) - ti(4)-0.01;
                        set(hh,'Position',[left bottom ax_width ax_height], 'fontsize', 10);     
                        hold(hh, 'off');

            
    
                    end                        
        
                    savePath2 = [ops.savePath ' allpvals =  ' num2str(allpvals)];
                    
                    if ~exist(savePath2, 'dir')
                        mkdir(savePath2);
                    end
        
                   
                
                    savefig(g{stimDur},fullfile(savePath2,  [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz significant units_rasters.fig']));
                    saveas(g{stimDur},fullfile(savePath2,  [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz significant units_rasters.png']));
                    savefig(gg{stimDur},fullfile(savePath2,  [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz significant units_FRs.fig']));
                    saveas(gg{stimDur},fullfile(savePath2,  [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz significant units_FRs.png']));
                end
        
            end
    
        end
    end
end

function MakeCbiasFigures(allVars, binWidth, plotAlpha)
    load(allVars, 'Cbiastable', 'ops', 'bodysidefinal','ufreq','uGenotypes', 'inputrecSites',  'pvals');
    close all   
    
    % just signify according to allpvals
    ops.plotAlpha = plotAlpha;
    for allpvals = 0:ops.allpvals  
        Cbiastable2 = {};
        sessCBiasNum = {};
        savePath = fullfile(ops.savePath, ['allPvals = ' num2str(allpvals)]);

       

        for genotype = numel(Cbiastable):-1:1 
            
            for recSite =1:numel(Cbiastable{genotype})
                if ~isempty(Cbiastable{genotype}{recSite})
                    for sessNum =1:numel(Cbiastable{genotype}{recSite})
                              
                        sigUnits = {};
                        if isempty(Cbiastable{genotype}{recSite}{sessNum})
                            continue;
                        end
                        cbiasSess = cellfun(@(x) cell2mat(x), Cbiastable{genotype}{recSite}{sessNum}, 'UniformOutput',false);
                        
                        
                         if allpvals && numel(cbiasSess) >3 
                            pvalSess = cell2mat(cellfun(@(x) x(:,3), cbiasSess, 'UniformOutput',false));
                            if size(pvalSess,2) >3
                               pvalSess = pvalSess(:,1:3);
                            end
                            sigUnits = pvalSess < ops.plotAlpha;
                            sumlogic = sum(sigUnits,2);
                            sigUnits = sumlogic>0;
                            cbiasSess = cellfun(@(x) x(sigUnits, :), cbiasSess, 'UniformOutput',false);
                         else
                            if numel(cbiasSess)>3
                                sigUnits = cellfun(@(x) x(:,3)<ops.plotAlpha, cbiasSess, 'UniformOutput',false);                        
                                cbiasSess = cellfun(@(x,y) x(y, :), cbiasSess, sigUnits,'UniformOutput',false);        
                            else
                                sigUnits = cbiasSess{2}(:,3)<ops.plotAlpha;
                                cbiasSess{2} = cbiasSess{2}(sigUnits,:);
                            end
    
                         end
    
                         Cbiastable3{genotype}{recSite}{sessNum} = cbiasSess;
    
    
                        for stimDur =1:numel(Cbiastable{genotype}{recSite}{sessNum})
    
                            Cbiastable2{stimDur}{genotype}{recSite}{sessNum} = Cbiastable3{genotype}{recSite}{sessNum}{stimDur};
    
                            if ~isempty(Cbiastable2{stimDur}{genotype}{recSite}{sessNum})
                                sessCBiasNum{stimDur}{genotype}{recSite}(1,sessNum) = numel(find(Cbiastable2{stimDur}{genotype}{recSite}{sessNum}(:,1)>0));
                                sessCBiasNum{stimDur}{genotype}{recSite}(2,sessNum) = numel(find(Cbiastable2{stimDur}{genotype}{recSite}{sessNum}(:,1)<0));
                                sessCBiasNum{stimDur}{genotype}{recSite}(3,sessNum) = numel(find(Cbiastable2{stimDur}{genotype}{recSite}{sessNum}(:,1)==0));
                            else
                                sessCBiasNum{stimDur}{genotype}{recSite}(1,sessNum) = 0;
                                sessCBiasNum{stimDur}{genotype}{recSite}(2,sessNum) = 0;
                                sessCBiasNum{stimDur}{genotype}{recSite}(3,sessNum) = 0;
                            end
                        end
    
    
                    end
                end
                end
        end
    
                    






                    
                   
        for stimDur =1:numel(ufreq)
            g1 = figure(3*stimDur-2);clf;
            
            g2 = figure(3*stimDur-1);clf;
            g3 = figure(3*stimDur); clf;
    
            maxunits = 0;
            for genotype = numel(Cbiastable2{stimDur}):-1:1 
                
                for recSite =1:numel(Cbiastable2{stimDur}{genotype})
                    getCbiasTable = Cbiastable2{stimDur}{genotype}{recSite};
                    if isempty(getCbiasTable)
                        continue;
                    end
                    try
                        zeroSess = cellfun(@isempty, getCbiasTable);
                    catch
                        keyboard;
                    end
                    getCbiasTable = getCbiasTable(~zeroSess);
                    
%                     getCbiasTable = cellfun(@cell2mat, getCbiasTable', 'UniformOutput', false);
                    getCbiasTable = cell2mat(getCbiasTable');
    
                    getSessbiasNum = sessCBiasNum{stimDur}{genotype}{recSite};
                    getSessbiasNum = getSessbiasNum(:,~zeroSess);
                    contrasess = getSessbiasNum(1,:)>getSessbiasNum(2,:);
                    ipsisess = getSessbiasNum(1,:)<getSessbiasNum(2,:);
                    colorsStock = {[0 0 1], [1 0 0], [0 0 0], [0.5 0.5 0.5]};
                    bins = -1:binWidth:1;
                    color1 = [0 0 1];
                    color2 = [1 0 0];
                    ipsicolors1 = repmat(color1, [floor(numel(bins)/2),1]);
                    contracolors1 = repmat(color2, [floor(numel(bins)/2),1]);
                    mycolors = [ipsicolors1; [0 0 0]; contracolors1];
    
                    
                    if strcmp(uGenotypes{genotype},'KO')  
               
                        figure(3*stimDur-2);
                        hold on
                        s1 = swarmchart(getSessbiasNum(1,contrasess)', getSessbiasNum(2,contrasess)',20, 'markeredgecolor', colorsStock{2},...
                            'XJitterWidth',0.5, 'YJitterWidth', 0.5);
                        s2 = swarmchart(getSessbiasNum(1,ipsisess)', getSessbiasNum(2,ipsisess)',20, 'markeredgecolor', colorsStock{1}, ...
                            'XJitterWidth',0.5, 'YJitterWidth', 0.5);
                        s3 = swarmchart(getSessbiasNum(1,~ipsisess & ~contrasess)', getSessbiasNum(2,~ipsisess & ~contrasess)',20, 'markeredgecolor', colorsStock{3}, ...
                            'XJitterWidth',0.5, 'YJitterWidth', 0.5);        
                        hold off
    
                        figure(3*stimDur-1);
                        subplot(2,1,2);       
                        h2 = histogram(getCbiasTable(:,1), bins, 'facecolor', 'r');            
                        title(uGenotypes{genotype})
                        xlabel('(C-I)/(C+I)');
                        ylabel('#of units');
    
                        figure(3*stimDur);
                        subplot(2,1,2);
                        h1 = histogram(getCbiasTable(:,1), bins, 'facecolor', 'r', 'Normalization','probability');                       
                        title(uGenotypes{genotype})
                        xlabel('(C-I)/(C+I)');
                        ylabel('probability');
                        
                    else
                        
                        figure(3*stimDur-2);                    
                        s4 = swarmchart(getSessbiasNum(1,contrasess)', getSessbiasNum(2,contrasess)'+0.2,20, 'markeredgecolor', colorsStock{4},...
                            'XJitterWidth',0.5, 'YJitterWidth', 0.5);                    
    
                        figure(3*stimDur-1);
                        subplot(2,1,1);
                        h1 = histogram(getCbiasTable(:,1), bins, 'facecolor', [0.8 0.8 0.8]);                       
                        title(uGenotypes{genotype})
                        xlabel('(C-I)/(C+I)');
                        ylabel('#of units');
    
                        figure(3*stimDur);
                        subplot(2,1,1);
                        h1 = histogram(getCbiasTable(:,1), bins, 'facecolor', [0.8 0.8 0.8], 'Normalization','probability');                       
                        title(uGenotypes{genotype})
                        xlabel('(C-I)/(C+I)');
                        ylabel('probability');
                    end
                    
        
                    %inputrecSites
                end
                if max(getSessbiasNum,[],"all")> maxunits
                    maxunits = max(getSessbiasNum,[],"all");
                end
            end
            figure(3*stimDur-1);   
            sgtitle([inputrecSites{recSite} ' ' ufreq{stimDur} ' counts']);
    
            figure(3*stimDur);
            sgtitle([inputrecSites{recSite} ' ' ufreq{stimDur} ' probability']);
    
            figure(3*stimDur-2);
            hold on
            plot(-1:maxunits+1,-1:maxunits+1, 'k-.')
            legend([s1,s2,s3,s4], {'KOcontra', 'KOIpsi','KOequal','WT'});
            xlabel('Number of contra units in a session');
            ylabel('Number of ipsi units in a session');
            xlim([-1,maxunits+1])
            ylim([-1,maxunits+1])
            title([inputrecSites{recSite} ' ' ufreq{stimDur}]);
            hold off

            if ~isfolder(savePath)
                mkdir(savePath);
            end
            savefig(g1,fullfile(savePath,  [inputrecSites{recSite} ' ' ufreq{stimDur} ' ms duration significant units sessPlot.fig']));
            saveas(g1,fullfile(savePath,  [inputrecSites{recSite} ' ' ufreq{stimDur} ' ms duration significant units sessPlot.png']));
            savefig(g2,fullfile(savePath,  [inputrecSites{recSite} ' ' ufreq{stimDur} ' ms duration significant units histogram.fig']));
            saveas(g2,fullfile(savePath,  [inputrecSites{recSite} ' ' ufreq{stimDur} ' ms duration significant units histogram.png']));
            savefig(g3,fullfile(savePath,  [inputrecSites{recSite} ' ' ufreq{stimDur} ' ms duration significant units histogram_probability.fig']));
            saveas(g3,fullfile(savePath,  [inputrecSites{recSite} ' ' ufreq{stimDur} ' ms duration significant units histogram_probability.png']));
        end


    end



        
end

function CBiasDepthHistoLinefinal(ops, metadataTable,nboot, LTwoThree, tipAdjust)
        % just average and std histogram over each animal's distribution
     close all   
     % L1, 128 ± 1 μm; L2, 269 ± 2 μm; L3, 418 ± 3 μm; L4, 588 ± 3 μm; L5A, 708 ± 4 μm; L5B, 890 ± 5 μm; L6, 1154 ± 7 μm.
    % just signify according to allpvals
    
    depthTable = metadataTable.HistoTable;   
    cbiasTable = metadataTable.cbias;
    pvalTable = metadataTable.pvalBoth;
    animalIds = unique(metadataTable.Properties.RowNames);
    genotypes = metadataTable.genotype;
    uGenotype = unique(genotypes);
    windows = ops.WindowNames;
    stimNames ={'10hz', '20hz', '40hz'};
    
    ylim2 = [100, 100, 100, 100, 100, 100,100, 100];
    colors = {[0 0 0 ], [0.7 0.7 0.7]};
%     for win = 1: numel(ops.windows)
%     for win = 5: numel(ops.windows)

    for win = 6
        savePath = fullfile(ops.savePath, ops.WindowNames{win});
    %         savePath = fullfile(ops.savePath, 'Percent Units depth movie');
    
        if ~isfolder(savePath)
            mkdir(savePath);
        end
    
        cbiasFinal = cell(2,3);
        depthFinal = cell(2,3);
        rng(7);
        cbiasFinalreal = cell(2,3);
        depthFinalreal = cell(2,3);
        for geno = 1:numel(uGenotype)
                
            animals= find(ismember(genotypes, uGenotype(geno)));
            CbiasGeno = cbiasTable(animals);
            pvalGeno = pvalTable(animals);
            depthGeno = depthTable(animals);
            
           
            for ani = 1: numel(CbiasGeno) 
                aniGeno = CbiasGeno{ani};
                anipval = pvalGeno{ani};
                aniDepth = depthGeno{ani};
                
                for sessNum = 1: height(aniGeno)
                    pvalsess = cell2mat(table2cell(anipval.(ops.WindowNames{win}){sessNum}));
                    cbiasSess = aniGeno.(ops.WindowNames{win}){sessNum};
                    depthSess = aniDepth.(ops.WindowNames{win}){sessNum};
                    if width(pvalsess) >3

                        pvalsess = pvalsess(:,2);
                        pstimDur = 1:3;
                        cbiasSess = cbiasSess(:,1:3);
                        depthSess = depthSess(:,1:3);
                    else
                        pstimDur =2;
                    end
                        
                    
                    sumlogics = sum(pvalsess < ops.plotAlpha,2);
                    sigUnits = find(sumlogics>0);
                    cbiasSess = cell2mat(table2cell(cbiasSess(sigUnits,:)));
                    depthSess = depthSess(sigUnits,:);
                    
                  
                    if ~isempty(cbiasSess)
                       for stim = 1:width(cbiasSess)
                           if ~iscell(cbiasFinalreal{geno,pstimDur(stim)})
                                cbiasFinalreal{geno,pstimDur(stim)} = cell(numel(CbiasGeno),1);
                                depthFinalreal{geno,pstimDur(stim)} = cell(numel(CbiasGeno),1);
                           end
                            indx = numel(cbiasFinalreal{geno,pstimDur(stim)}{ani});
                            cbiasFinalreal{geno,pstimDur(stim)}{ani}(indx+1:indx+height(cbiasSess)) = cbiasSess(:,stim);
                            
                            unitDepth = cell2mat(cellfun(@(x) (x.unitDepth-tipAdjust), table2cell(depthSess(:,stim)), 'UniformOutput', false));
                            
                            depthFinalreal{geno,pstimDur(stim)}{ani}(indx+1:indx+numel(unitDepth)) = unitDepth; 

                       end
                            
                
                    end
                        
                end

            end
        
          
            end
    

        for stim =1:numel(stimNames)
           
            for genotype =1:height(depthFinalreal)
               HSupReal{genotype, stim} = [];
               HDeepReal{genotype, stim} = [];
               
               genData = [];
               for ani = 1: numel(depthFinalreal{genotype, stim})
                    data = [cbiasFinalreal{genotype,stim}{ani}', depthFinalreal{genotype,stim}{ani}'];
                    
                    data(isnan(data(:,1)),:)=[];
                    genData = [genData; data];
                    lowerBounds = [LTwoThree,max(max(data(:,2)), 1800)];
                    upperBounds = [min(min(data(:,2)),0),LTwoThree];
                    
                    binEdgesY = upperBounds + (lowerBounds-upperBounds)/2;
                    
    
                    binsX =-1:2/ops.parts:1;
                    lowerBounds = binsX(1:end-1);
                    upperBounds = binsX(2:end);
                    binEdgesX = upperBounds + (lowerBounds-upperBounds)/2;
                    
                    
                    H = hist3(data, ...
                        {binEdgesX,binEdgesY}, 'CdataMode','auto');
                
%                     HSupReal{genotype, stim}(ani, :) = [0, H(:,1)'/sum(H(:,1)), 0]*100;
%                     HDeepReal{genotype, stim}(ani, :) = [0, H(:,2)'/sum(H(:,2)), 0]*100;

                    HSupReal{genotype, stim}(ani, :) = H(:,1)'/sum(H(:,1))*100;
                    HDeepReal{genotype, stim}(ani, :) = H(:,2)'/sum(H(:,2))*100;

                    
                    
                    

               end

               
                dataSup = genData(genData(:,2)<=LTwoThree & genData(:,2)>=min(min(genData(:,2)),0),:);
                numUnitsS = height(dataSup);
                
                dataDeep = genData(genData(:,2)>=LTwoThree & genData(:,2)<=max(max(genData(:,2)),1500),:);
                numUnitsD = height(dataDeep);
               HSup{genotype, stim} = [];
               HDeep{genotype, stim} =[];
               rng(7);
                for boot = 1:nboot
                        
                        unitsTotake = datasample(1:numUnitsS, numUnitsS, 'Replace', true);                        
                        dataBootS = dataSup(unitsTotake,:);

                        unitsTotake = datasample(1:numUnitsD, numUnitsD, 'Replace', true);                        
                        dataBootD = dataDeep(unitsTotake,:);
                        
                        binsX =-1:2/ops.parts:1;
                        lowerBounds = binsX(1:end-1);
                        upperBounds = binsX(2:end);
                        binEdgesX = upperBounds + (lowerBounds-upperBounds)/2;
                       
                        
                        sup = hist(dataBootS(:,1), ...
                            binEdgesX);
                        HSup{genotype, stim}(boot, :) = [0, sup/sum(sup), 0]*100;
                        deep = hist(dataBootD(:,1), ...
                            binEdgesX);
                       
                        HDeep{genotype, stim}(boot, :) = [0, deep/sum(deep), 0]*100;
 
                       
                    end
          
            end
        end


          for stim =1:numel(stimNames)
                
                for genotype =1:height(depthFinal)
                   
                    % remove animals with nans
                    HSupReal{genotype, stim}(isnan(HSupReal{genotype, stim}(:,2)),:)=[];
                    
                    % remove animals with no units i.e. sum <<100
                    HSupReal{genotype, stim}(sum(HSupReal{genotype, stim},2)<90,:) =[];
                    
    
                    % remove animals with nans
                    HDeepReal{genotype, stim}(isnan(HDeepReal{genotype, stim}(:,2)),:)=[];
    
                     % remove animals with no units i.e. sum <<100
                    HDeepReal{genotype, stim}(sum(HDeepReal{genotype, stim},2)<90,:) =[];
    
                end
            end

        % Prepare data for ANOVA
        responseArray = {'ipsilateral', 'bilateral', 'contralateral'};
        close all;
        % Open the file in write mode (this cleans the file)
        fileID = fopen(fullfile(savePath,  [' depth cbias histogram line stats.txt']), 'w'); % Replace 'yourfile.txt' with your filename

        H = {HSupReal, HDeepReal};
        layers = {'Sup', 'Deep'};
        
        for layer = 1:numel(H)
            Hlayer = H{layer};
           for stim = 2
                
                for response =1:numel(responseArray)
                    % for each genotype get the 
                    genotypes = {};
                    percentageArray = [];
                    for genotype = 1:height(depthFinalreal)

                        mouseNums = height(Hlayer{genotype, stim});
                        repeatedGenos = repmat(uGenotype(genotype), mouseNums, 1);
                        genotypes(end+1:end+height(repeatedGenos),1) = repeatedGenos;
    
                    
                    
                        percentVals = Hlayer{genotype, stim}(:,response);
                        percentageArray(1:height(percentVals),genotype) = percentVals;
                    end

                    %Statistics across genotype for same responseType 
                    
    
                      % Mann whitney Test
                    [p, h, stats] = ranksum(percentageArray(:,1), percentageArray(:,2));
                    
                    fprintf(fileID, [layers{layer} ' Mann Whitney U test across Genotypes for same responsetype: ' responseArray{response} '\n']);
                    fprintf(fileID, 'p-value: %.4f\n', p);
                  
                    
                end



            end
        end

        % Close the file
        fclose(fileID);
        close all;
           
        
        g = figure(win); clf;
        set(g, 'Units', 'inches', 'Position', [1,1,1,2]);
        
        hold on
        for stim =2
           
            for genotype =1:height(depthFinal)
               
               x = -1:2/(ops.parts-1):1;

                HSupReal{genotype, stim}(isnan(HSupReal{genotype, stim}(:,2)),:)=[];

                meanSup = mean(HSupReal{genotype, stim},1);
                stdSup = std(HSupReal{genotype, stim},1);


                ciDeep = CalcCI(HDeep{genotype, stim}, 0.95);

                HDeepReal{genotype, stim}(isnan(HDeepReal{genotype, stim}(:,2)),:)=[];
                meanDeep = mean(HDeepReal{genotype, stim},1);
                stdDeep = std(HDeepReal{genotype, stim},1);

                
                ax1 = subplot(2, 1,1);
                % Hold on to plot multiple bars
                
                hold(ax1, 'on');

                try
                    errorbar(x+(genotype-1)*0.05, meanSup, stdSup, 'color', colors{genotype},'LineWidth', 1);
                catch
                end
                if genotype ==2   
                    HSupstat = [];
                
                    for parts = 1: ops.parts
                        HSupstat(parts)= ranksum(HSupReal{1,stim}(:,parts),HSupReal{2,stim}(:,parts));                
                    end

                   
                    xplot = x(HSupstat < 0.05);    
                    
                    if ~isempty(xplot)
                       
                        scatter(xplot, 100*ones(1,numel(xplot)), 70, 'k', '*');
                    end
                    set(gca, 'FontName', 'Arial','FontSize', 8, 'Linewidth', 1, 'xticklabels', [], 'TickDir', 'out', ...
                        'Position', [0.2,0.65, 0.75, 0.3]);
                    ax1.XTick = x;
                    
                    xlim([-1.2,1.2]);        
                    ylim([0-10,ylim2(win)+10]);     
%                     title(stimNames{stim});    
%                     legend({'KO', 'WT'});
                end
                hold(ax1, 'off');

                ax2 = subplot(2, 1,2);
                hold(ax2, 'on');

                try
                    errorbar(x+(genotype-1)*0.05, meanDeep, stdDeep, 'color', colors{genotype}, 'LineWidth', 1);
                catch
                end
                if genotype ==2  
                    HDeepstat = [];
              
                    for parts = 1: ops.parts
                        HDeepstat(parts)= ranksum(HDeepReal{1,stim}(:,parts),HDeepReal{2,stim}(:,parts));                
                    end
                    xplot = x(HDeepstat < 0.05);    
                    
                    if ~isempty(xplot)
                       
                        scatter(xplot, 100*ones(1,numel(xplot)), 70, 'k', '*');
                    end
                    set(gca, 'FontName', 'Arial', 'FontSize', 8, 'Linewidth', 1, 'TickDir', 'out', ...
                        'Position', [0.2,0.3, 0.75, 0.3]);
                    xlim([-1.2,1.2]);        
                    ylim([0-10,ylim2(win)+10]);

                    ax2.XTick = x;
                    ax2.XTickLabel = {'Ipsilateral', 'Bilateral', 'Contralateral'};
                    ax2.XTickLabelRotation =45;
                    xlim([-1.2,1.2]); 
%                     title('Deep');    
%                     legend({'KO', 'WT'});
                end
                hold(ax2, 'off');             
                
            end
            
        end
        hold off

        savefig(g,fullfile(savePath,  [' depth cbias histogram line.fig']));
        exportgraphics(g,fullfile(savePath,  [' depth cbias histogram line.pdf']), 'Resolution', 1200);

    end                
          




        
end

function CbiasComparison_AllDepths(ops, metadataTable,nboot, LTwoThree, tipAdjust)
        % just average and std histogram over each animal's distribution
     close all   
    % just signify according to allpvals
    
    depthTable = metadataTable.HistoTable;   
    cbiasTable = metadataTable.cbias;
    pvalTable = metadataTable.pvalBoth;
    animalIds = unique(metadataTable.Properties.RowNames);
    genotypes = metadataTable.genotype;
    uGenotype = unique(genotypes);
    windows = ops.WindowNames;
    stimNames ={'10hz', '20hz', '40hz'};
    
    ylim2 = [100, 100, 100, 100, 100, 100,100, 100];
    colors = {[0 0 0 ], [0.7 0.7 0.7]};
%     for win = 1: numel(ops.windows)
%     for win = 5: numel(ops.windows)

 for win = 6
        savePath = fullfile(ops.savePath, ops.WindowNames{win});
    %         savePath = fullfile(ops.savePath, 'Percent Units depth movie');
    
        if ~isfolder(savePath)
            mkdir(savePath);
        end
    
        cbiasFinal = cell(2,3);
        depthFinal = cell(2,3);
        rng(7);
        cbiasFinalreal = cell(2,3);
        depthFinalreal = cell(2,3);
        for geno = 1:numel(uGenotype)
                
            animals= find(ismember(genotypes, uGenotype(geno)));
            CbiasGeno = cbiasTable(animals);
            pvalGeno = pvalTable(animals);
            depthGeno = depthTable(animals);
            
           
            for ani = 1: numel(CbiasGeno) 
                aniGeno = CbiasGeno{ani};
                anipval = pvalGeno{ani};
                aniDepth = depthGeno{ani};
                
                for sessNum = 1: height(aniGeno)
                    pvalsess = cell2mat(table2cell(anipval.(ops.WindowNames{win}){sessNum}));
                    cbiasSess = aniGeno.(ops.WindowNames{win}){sessNum};
                    depthSess = aniDepth.(ops.WindowNames{win}){sessNum};
                    if width(pvalsess) >3

                        pvalsess = pvalsess(:,2);
                        pstimDur = 1:3;
                        cbiasSess = cbiasSess(:,1:3);
                        depthSess = depthSess(:,1:3);
                    else
                        pstimDur =2;
                    end
                        
                    
                    sumlogics = sum(pvalsess < ops.plotAlpha,2);
                    sigUnits = find(sumlogics>0);
                    cbiasSess = cell2mat(table2cell(cbiasSess(sigUnits,:)));
                    depthSess = depthSess(sigUnits,:);
                    
                  
                    if ~isempty(cbiasSess)
                       for stim = 1:width(cbiasSess)
                           if ~iscell(cbiasFinalreal{geno,pstimDur(stim)})
                                cbiasFinalreal{geno,pstimDur(stim)} = cell(numel(CbiasGeno),1);
                                depthFinalreal{geno,pstimDur(stim)} = cell(numel(CbiasGeno),1);
                           end
                            indx = numel(cbiasFinalreal{geno,pstimDur(stim)}{ani});
                            cbiasFinalreal{geno,pstimDur(stim)}{ani}(indx+1:indx+height(cbiasSess)) = cbiasSess(:,stim);
                            
                            unitDepth = cell2mat(cellfun(@(x) (x.unitDepth-tipAdjust), table2cell(depthSess(:,stim)), 'UniformOutput', false));
                            
                            depthFinalreal{geno,pstimDur(stim)}{ani}(indx+1:indx+numel(unitDepth)) = unitDepth; 

                       end
                            
                
                    end
                        
                end

            end
        
          
            end
    

        for stim =1:numel(stimNames)
           
            for genotype =1:height(depthFinalreal)
               HSupReal{genotype, stim} = [];
               HDeepReal{genotype, stim} = [];
               
               for ani = 1: numel(depthFinalreal{genotype, stim})
                    data = [cbiasFinalreal{genotype,stim}{ani}'];
                    
                    data(isnan(data(:,1)),:)=[];
                   
                    
        
    
                    binsX =-1:2/ops.parts:1;
                    lowerBounds = binsX(1:end-1);
                    upperBounds = binsX(2:end);
                    binEdgesX = upperBounds + (lowerBounds-upperBounds)/2;
                    bins = [-1:2/3:1];
                    
                    
                    H = histogram(data, 'binedges', bins);
                    H = H.Values;


                    HReal{genotype, stim}(ani, :) = H/sum(H)*100;

                    
                    
                    

               end

               
               
          
            end
        end

        
          

        % Prepare data for ANOVA
        responseArray = {'ipsilateral', 'bilateral', 'contralateral'};
        close all;
        % Open the file in write mode (this cleans the file)
        fileID = fopen(fullfile(savePath,  [' depth cbias histogram line stats_all.txt']), 'w'); % Replace 'yourfile.txt' with your filename

        H = {HReal};
        layers = {'All'};
        

      
        for layer = 1:numel(H)
            Hlayer = H{layer};
           for stim = 2
                
                for response =1:numel(responseArray)
                    % for each genotype get the 
                    genotypes = {};
                    percentageArray = [];
                    for genotype = 1:height(depthFinalreal)

                        mouseNums = height(Hlayer{genotype, stim});
                        repeatedGenos = repmat(uGenotype(genotype), mouseNums, 1);
                        genotypes(end+1:end+height(repeatedGenos),1) = repeatedGenos;
    
                    
                    
                        percentVals = Hlayer{genotype, stim}(:,response);
                        percentageArray(1:height(percentVals),genotype) = percentVals;
                    end

                    %Statistics across genotype for same responseType 
                    
    
                    % Mann whitney Test
                    [p, h, stats] = ranksum(percentageArray(:,1), percentageArray(:,2));
                    
                    fprintf(fileID, [layers{layer} ' Mann Whitney U test across Genotypes for same responsetype: ' responseArray{response} '\n']);
                    fprintf(fileID, 'p-value: %.4f\n', p);
                  
                    
                end



            end
        end

        % Close the file
        fclose(fileID);
        close all;
           
        
        g = figure(win); clf;
        set(g, 'Units', 'inches', 'Position', [1,1,1,2]);
        
        hold on
        for stim =2
           
            for genotype =1:height(depthFinal)
               
               x = -1:2/(ops.parts-1):1;


                meanSup = mean(HReal{genotype, stim},1);
                stdSup = std(HReal{genotype, stim},1);

                ax1 = subplot(2, 1,1);
                % Hold on to plot multiple bars
                
                hold(ax1, 'on');

                try
                    errorbar(x+(genotype-1)*0.05, meanSup, stdSup, 'color', colors{genotype},'LineWidth', 1);
                catch
                end
                if genotype ==2   
                    HSupstat = [];
                
                    for parts = 1: ops.parts
                        HSupstat(parts)= ranksum(HReal{1,stim}(:,parts),HReal{2,stim}(:,parts));                
                    end

                   
                    xplot = x(HSupstat < 0.05);    
                    
                    if ~isempty(xplot)
                       
                        scatter(xplot, 100*ones(1,numel(xplot)), 70, 'k', '*');
                    end
                    set(gca, 'FontName', 'Arial','FontSize', 8, 'Linewidth', 1, 'xticklabels', [], 'TickDir', 'out');
%                     ax1.XTick = x;
                    
                    xlim([-1.2,1.2]);        
                    ylim([0-10,ylim2(win)+10]);     
%                     title(stimNames{stim});    
%                     legend({'KO', 'WT'});
                end
                hold(ax1, 'off');
                
            end
            
        end

        hold off

        savefig(g,fullfile(savePath,  [' depth cbias histogram line_all.fig']));
        exportgraphics(g,fullfile(savePath,  [' depth cbias histogram line_all.pdf']), 'Resolution', 300);

    end                
          




        
end


function ci = CalcCI(data,confidenceLevel)

    % Calculate sample mean
    
    % replace nan by zeros
%     data(isnan(data(:,2)), :) = [];
    data(isnan(data)) = 0;
    
    sampleMean = mean(data,1);
    
    % Calculate sample standard deviation
    sampleStd = std(data,1);
    
    % Sample size
    n = height(data);
    
 
  
    % Calculate the t-critical value for 95% confidence interval
    alpha = 1 - confidenceLevel;
    tValue = tinv(1 - alpha/2, n - 1);
    
    % Calculate the standard error of the mean
    sem = sampleStd / sqrt(n);
    
    % Calculate the margin of error
    marginOfError = tValue * sem;
    
    % Calculate the confidence interval
    ciLower = sampleMean - marginOfError;
    ciUpper = sampleMean + marginOfError;
    ci = [ciLower; ciUpper];

end


function FRHeatmapsEachFreq(ops, metadataTable, meanFRTable, plotAlpha, window, withLabels)
% plot heatmaps of contra responsive to ipsi responsive sorted by cbias
    genotypes = metadataTable.genotype;
    cBias = metadataTable.cbias;
    pvals = metadataTable.pvalBoth;
    pvalContra = metadataTable.pvalContra;
    pvalIpsi = metadataTable.pvalIpsi;

    uGenotypes = unique(genotypes);
    close all;
    variableNames = {'Time', 'ContraMean', 'ContraCI', 'IpsiMean', 'IpsiCI', 'CBias', 'RespID', 'MaxFR'};
   bins = -0.05:0.001:0.05;
   % get genotype sessions.
   uFreq = {'10hz', '20hz', '40hz'};
   
   ops.plotAlpha = plotAlpha;
   for stim =1:3
       for genotype = 1:numel(uGenotypes)
           
           
           cBiasGeno = cBias(strcmp(metadataTable.genotype, uGenotypes{genotype}),:);
           pvalGeno = pvals(strcmp(metadataTable.genotype, uGenotypes{genotype}),:);
           pvalContraGeno = pvalContra(strcmp(metadataTable.genotype, uGenotypes{genotype}),:);
           pvalIpsiGeno = pvalIpsi(strcmp(metadataTable.genotype, uGenotypes{genotype}),:);
           FRGeno = meanFRTable.meanFR(strcmp(metadataTable.genotype, uGenotypes{genotype}),:);
           
           FRAll = table('Size', [0, length(variableNames)], 'VariableTypes', repmat("cell", 1, length(variableNames)), 'VariableNames', variableNames);
           % collect all the unit FRs that are significant in any.
           for animal = 1:height(pvalGeno)
               
               pvalAni = pvalGeno{animal}.(window{2});
               pvalContraAni = pvalContraGeno{animal}.(window{2});
               pvalIpsiAni = pvalIpsiGeno{animal}.(window{2});
               cBiasAni = cBiasGeno{animal}.(window{2});
               FRAni = FRGeno{animal}.('300');
               
               for session = 1:height(pvalAni)
                   pvalSess = pvalAni{session};
                   pvalIpsiSess = pvalIpsiAni{session};
                   pvalContraSess = pvalContraAni{session};
                   cBiasSess = cBiasAni{session};
                   FRSess = FRAni{session};
                    
                    if width(pvalSess) >3
                        
                        pvalSess = cell2mat(table2array(pvalSess(:,"20hz"))); 
                        pvalIpsiSess = cell2mat(table2array(pvalIpsiSess(:,"20hz")));  
                        pvalContraSess = cell2mat(table2array(pvalContraSess(:,"20hz")));
                        cBiasSess = table2array(cBiasSess(:,"20hz"));
                        FRSess = table2array(FRSess(:,1:3));
                        
                        maxFR = {};
                        for unitNum = 1:height(FRSess)
                            temp = FRSess(unitNum, :);
                            temp = vertcat(temp{:});
                    
                            %Find maxFR across all stims. 
                            maxFR{unitNum,1} = max(cell2mat([temp.ContraMean; temp.IpsiMean]), [], 'All');
                        end
                        
                        FRSess = FRSess(:,stim);            
                        FRSess = vertcat(FRSess{:});
                        FRSess.MaxFR = maxFR;

                    elseif width(pvalSess) <3 && stim==2

                        pvalSess = cell2mat(table2array(pvalSess));

                        pvalIpsiSess = cell2mat(table2array(pvalIpsiSess));  
                        pvalContraSess = cell2mat(table2array(pvalContraSess));

                        cBiasSess = table2array(cBiasSess);
                        FRSess = table2array(FRSess);

                        maxFR = {};
                        for unitNum = 1:height(FRSess)
                            temp = FRSess(unitNum, :);
                            temp = vertcat(temp{:});
                    
                            % Find maxFR across all stims. 
                            maxFR{unitNum,1} = max(cell2mat([temp.ContraMean; temp.IpsiMean]), [], 'All');
                        end

                        FRSess = vertcat(FRSess{:});   
                        FRSess.MaxFR = maxFR;

                    else
                        continue;
                        
                    end
                            
                    %%%%% Find the session is contra or ipsi by # of responsive units to contra >ipsi %%%%%%%%
                    % find the minimum of the pval in any stim.
%                     pvalSess = min(pvalSess,[],2);
                            
                            
                    
                    sumlogics = sum(pvalSess < ops.plotAlpha,2);
                    sigUnits = find(sumlogics>0);
                    FRSess = FRSess(sigUnits,:);
                    cBiasSess =cBiasSess(sigUnits,:);
                    cBiasMat =  cell2mat(cBiasSess)
                    pvalIpsiSess = pvalIpsiSess(sigUnits,:);
                    pvalContraSess = pvalContraSess(sigUnits,:);
                    responsiveIdentity = zeros(height(cBiasSess), 1);
%                 contraOnlyUnits = find(pvalContraSess<ops.plotAlpha & pvalIpsiSess>ops.plotAlpha);
%                 ipsiOnlyUnits = find(pvalContraSess>ops.plotAlpha & pvalIpsiSess<ops.plotAlpha);
%                 responsiveIdentity(contraOnlyUnits,1) = ones(height(contraOnlyUnits), 1);
%                 responsiveIdentity(ipsiOnlyUnits,1) = ones(height(ipsiOnlyUnits), 1)*-1;

                    contraOnlyUnits = find(cBiasMat>=0.33);
                    ipsiOnlyUnits = find(cBiasMat<-0.33);
                    responsiveIdentity(contraOnlyUnits,1) = ones(height(contraOnlyUnits), 1);
                    responsiveIdentity(ipsiOnlyUnits,1) = ones(height(ipsiOnlyUnits), 1)*-1;
                    
                    FRSess.CBias = cBiasSess;
                    FRSess.RespID = num2cell(responsiveIdentity);
                    
                    FRAll = vertcat(FRAll, FRSess);
                    
                end
           end
          

            % plot heatmaps using imagesc
        
       FRAll = sortrows(FRAll, {'RespID', 'CBias'}, 'descend');
        
       try
           FRContra = cell2mat(FRAll.ContraMean);
       catch
           
           FRTime = FRAll.Time;
           incompleteUnits = find(diff(cell2mat(cellfun(@numel, FRTime, 'UniformOutput', false)))<0)+1;
           FRAll(incompleteUnits, :) = [];
           FRContra= cell2mat(FRAll.ContraMean);
       end
       FRIpsi= cell2mat(FRAll.IpsiMean);

       % normalize FRs
       
        for unitNum = 1: height(FRContra)
            maxFRInd = FRAll.MaxFR{unitNum};
            FRContra(unitNum, :) = FRContra(unitNum, :)/maxFRInd;
            FRIpsi(unitNum, :) = FRIpsi(unitNum, :)/maxFRInd;
        end

       respIDs = cell2mat(FRAll.RespID);
       diffs = diff(respIDs);
       ipsibounds = find(diffs==-2);
       respBounds = find(diffs==-1);
       if strcmp(uGenotypes{genotype}, 'KO')
          
            if isempty(ipsibounds)
                disp([uGenotypes{genotype} ' Stim-' uFreq{stim} ': contra till: ' num2str(respBounds(1)) ' Ipsi from: ' num2str(respBounds(2)) ]); 
            else
                disp([uGenotypes{genotype} ' Stim-' uFreq{stim} ': contra till: ' num2str(respBounds(1)) ' Ipsi from: ' num2str(ipsibounds(1)) ]); 
            end

       elseif strcmp(uGenotypes{genotype}, 'WT')
           
            if isempty(ipsibounds)
                disp([uGenotypes{genotype} ' Stim-' uFreq{stim} ': contra till: ' num2str(respBounds(1)) ' Bilat from: ' num2str(respBounds(1)+1) ]); 
            else
                try
                    disp([uGenotypes{genotype} ' Stim-' uFreq{stim} ': contra till: ' num2str(respBounds(1)) ' Ipsi from: ' num2str(respBounds(1)+1) ]); 
                catch
                    keyboard;
                end
                end
       end

       maxFR = max([FRContra; FRIpsi], [], 'All');

       maxFR = 1;

      
        % plot data
       g = figure(genotype); clf;
       set(g, 'Units', 'inches', 'Position', [1, 1, 1.75, 2]);
       s = subplot(1,2, 1, 'Parent', g);
       imagesc(FRAll.Time{1}, 1:height(FRContra), FRContra);
       
       line([0, 0], [1, height(FRContra)], 'Color', 'k', 'LineStyle', '--', 'Linewidth', 2); % Stimulus onset
       
       xlim(ops.plotxLims)

       % Create custom colormap: black to red
        numColors = 256; % Number of colors in the colormap
        customColormap = [ones(numColors, 1), 1-linspace(0, 1, numColors)', 1-linspace(0, 1, numColors)'];        

        % Apply the custom colormap
        colormap(gca, customColormap);
        
        caxis([0 maxFR]);
        yTicks = 20:20:max(height(FRContra)) ;

        
        
        if withLabels
            % WITH LABELS
            set(s, 'Units', 'inches', 'Position', [0.24, 0.25, 0.4, 1.7], 'FontSize', 6, 'FontName', 'Arial', ...
                'Ytick', yTicks, 'TickDir', 'out',  'LineWidth', 1);            
%             s.YTickLabel{1} = '';
            if stim==1
                h = colorbar;
                set(h, 'Units', 'inches', 'Position', [0.12, 1.55, 0.08, 0.4]);
                h.Color = [0 0 0];
                h.LineWidth = 0.5;
                h.TickLabels(2) = {''};
    %             h.Ticks(2) = [];
            end
        else
            % Without labels
            set(gca, 'Units', 'inches', 'Position', [0, 0.1, 0.7, 3], 'FontSize', 10, 'Ytick', yTicks, 'TickDir', 'out', 'YTickLabel', [], 'XTickLabel', [], 'LineWidth', 1);            
           
            set(h, 'Units', 'inches', 'Position', [1.31, 4.5, 0.1, 1]);
%             h.Color = [1 1 1];
            h.LineWidth = 1;
%             h.TickLabels = [];
        end
        

       s= subplot(1,2, 2, 'Parent', g);       
       imagesc(FRAll.Time{1}, 1:height(FRIpsi), FRIpsi);
       line([0, 0], [1, height(FRContra)], 'Color', 'k', 'LineStyle', '--', 'Linewidth', 2); % Stimulus onset
       xlim(ops.plotxLims)

        % Create custom colormap: black to red
        numColors = 256; % Number of colors in the colormap
        customColormap = [1-linspace(0, 1, numColors)', 1-linspace(0, 1, numColors)', ones(numColors, 1)];

        % Apply the custom colormap
        colormap(gca, customColormap);
        
        caxis([0 maxFR]);

      
        if withLabels
            % With Labels
            set(s, 'Units', 'inches', 'Position', [0.885, 0.25, 0.4, 1.7], 'FontSize', 6, 'FontName', 'Arial', 'Ytick', yTicks, 'TickDir', 'out', ...
                'YTickLabel', [], 'LineWidth', 1);
%             s.YTickLabel{1} = '';
            if stim==1
                h = colorbar;
                set(h, 'Units', 'inches', 'Position', [0.76, 1.55,  0.08, 0.4]);            
                h.Color = [0 0 0];
                h.LineWidth = 0.5;
                h.TickLabels(2) = {''};
    %             h.Ticks(2) = [];
            end

        else
             % Without labels
             h = colorbar;
            set(gca, 'Units', 'inches', 'Position', [1.58, 0.1, 1.3, 5.5], 'FontSize', 6, 'Ytick', yTicks, 'TickDir', 'out', 'YTickLabel', [], 'XTickLabel', [], 'LineWidth', 1);
%             s.XColor=[1 1 1];
%             s.YColor=[1 1 1];

%             set(h, 'Units', 'inches', 'Position', [2.89, 4.5, 0.1, 1]);            
%             h.Color = [1 1 1];
%             h.LineWidth = 1;
%             h.TickLabels = [];
        end
        
            
          if withLabels
            exportgraphics(g, fullfile(ops.savePath, ['Stim ' uFreq{stim} ' Average FR heatmap labels ' uGenotypes{genotype} '.png']));
          else

            savefig(g,fullfile(ops.savePath, ['Stim ' uFreq{stim} ' Average FR heatmap ' uGenotypes{genotype} '.fig']));
            exportgraphics(g, fullfile(ops.savePath, ['Stim ' uFreq{stim} ' Average FR heatmap ' uGenotypes{genotype} '.png']));
          end
            

    
       end
        
   end
  
   

end

function FRHeatmapsAllFreq(ops, metadataTable, meanFRTable, plotAlpha, window, withLabels)
% plot heatmaps of contra responsive to ipsi responsive sorted by cbias
    genotypes = metadataTable.genotype;
    cBias = metadataTable.cbias;
    pvals = metadataTable.pvalBoth;
    pvalContra = metadataTable.pvalContra;
    pvalIpsi = metadataTable.pvalIpsi;

    uGenotypes = unique(genotypes);
    close all;
    variableNames = {'Time', 'ContraMean', 'ContraCI', 'IpsiMean', 'IpsiCI', 'CBias', 'RespID'};
   bins = -0.05:0.001:0.05;
   % get genotype sessions.
   uFreq = {'10hz', '20hz', '40hz'};
   xlimWin = str2num(window)/1000;
   ops.plotAlpha = plotAlpha;
   
   for genotype = 1:numel(uGenotypes)
       
       
       cBiasGeno = cBias(strcmp(metadataTable.genotype, uGenotypes{genotype}),:);
       pvalGeno = pvals(strcmp(metadataTable.genotype, uGenotypes{genotype}),:);
       pvalContraGeno = pvalContra(strcmp(metadataTable.genotype, uGenotypes{genotype}),:);
       pvalIpsiGeno = pvalIpsi(strcmp(metadataTable.genotype, uGenotypes{genotype}),:);
       FRGeno = meanFRTable.meanFR(strcmp(metadataTable.genotype, uGenotypes{genotype}),:);
       
       FRAll = table('Size', [0, length(variableNames)], 'VariableTypes', repmat("cell", 1, length(variableNames)), 'VariableNames', variableNames);
       % collect all the unit FRs that are significant in any.
       for animal = 1:height(pvalGeno)
           


           pvalAni = pvalGeno{animal}.(window);
           pvalContraAni = pvalContraGeno{animal}.(window);
           pvalIpsiAni = pvalIpsiGeno{animal}.(window);
           cBiasAni = cBiasGeno{animal}.(window);
           FRAni = FRGeno{animal}.('300');
           for session = 1:height(pvalAni)
               pvalSess = pvalAni{session};
               pvalIpsiSess = pvalIpsiAni{session};
               pvalContraSess = pvalContraAni{session};
               cBiasSess = cBiasAni{session};
               FRSess = FRAni{session};
                
                if width(pvalSess) >3
                    
                    pvalSess = cell2mat(table2array(pvalSess(:,"20hz"))); 
                    pvalIpsiSess = cell2mat(table2array(pvalIpsiSess(:,"20hz")));  
                    pvalContraSess = cell2mat(table2array(pvalContraSess(:,"20hz")));
                    cBiasSess = table2array(cBiasSess(:,"20hz"));
                    FRSess = table2array(FRSess(:,1:3));
                    for unitNum = 1:height(FRSess)
                        temp = FRSess(unitNum, :);
                        temp = vertcat(temp{:});
                        FRSess{unitNum, 4} = FRSess{unitNum,3};
                        
                        FRSess{unitNum,4}.ContraMean = {mean(cell2mat(temp.ContraMean), 1)};
                        FRSess{unitNum,4}.IpsiMean = {mean(cell2mat(temp.IpsiMean), 1)};

                        FRSess{unitNum,4}.ContraCI = {[]};
                        FRSess{unitNum,4}.IpsiCI = {[]};
                        


                    end
                    FRSess = FRSess(:,4);
                    FRSess = vertcat(FRSess{:});
                    
                elseif width(pvalSess) <3
                    
                    pvalSess = cell2mat(table2array(pvalSess)); 
                    pvalIpsiSess = cell2mat(table2array(pvalIpsiSess));  
                    pvalContraSess = cell2mat(table2array(pvalContraSess));
                    cBiasSess = table2array(cBiasSess);
                    FRSess = table2array(FRSess);
                    FRSess = vertcat(FRSess{:});   
                    
                else
                    continue;
                    
                end
                        
                %%%%% Find the session is contra or ipsi by # of responsive units to contra >ipsi %%%%%%%%
                % find the minimum of the pval in any stim.
%                 pvalSess = min(pvalSess,[],2);
                        
                        
                
                sumlogics = sum(pvalSess < ops.plotAlpha,2);
                sigUnits = find(sumlogics>0);

                cBiasSess =cBiasSess(sigUnits,:);
                cBiasMat =  cell2mat(cBiasSess)
                pvalIpsiSess = pvalIpsiSess(sigUnits,:);
                pvalContraSess = pvalContraSess(sigUnits,:);
                responsiveIdentity = zeros(height(cBiasSess), 1);
%                 contraOnlyUnits = find(pvalContraSess<ops.plotAlpha & pvalIpsiSess>ops.plotAlpha);
%                 ipsiOnlyUnits = find(pvalContraSess>ops.plotAlpha & pvalIpsiSess<ops.plotAlpha);
%                 responsiveIdentity(contraOnlyUnits,1) = ones(height(contraOnlyUnits), 1);
%                 responsiveIdentity(ipsiOnlyUnits,1) = ones(height(ipsiOnlyUnits), 1)*-1;

                contraOnlyUnits = find(cBiasMat>=0.33);
                ipsiOnlyUnits = find(cBiasMat<-0.33);
                responsiveIdentity(contraOnlyUnits,1) = ones(height(contraOnlyUnits), 1);
                responsiveIdentity(ipsiOnlyUnits,1) = ones(height(ipsiOnlyUnits), 1)*-1;

                FRSess = FRSess(sigUnits,:);
                FRSess.CBias = cBiasSess;
                FRSess.RespID = num2cell(responsiveIdentity);
                try
                FRAll = vertcat(FRAll, FRSess);
                catch
                    keyboard;
                end
                
            end
       end
      
       % plot heatmaps using imagesc

       FRAll = sortrows(FRAll, {'RespID', 'CBias'}, 'descend');
        
       try
           FRContra= cell2mat(FRAll.ContraMean);
       catch
           
           FRTime = FRAll.Time;
           incompleteUnits = find(diff(cell2mat(cellfun(@numel, FRTime, 'UniformOutput', false)))<0)+1;
           FRAll(incompleteUnits, :) = [];
           FRContra= cell2mat(FRAll.ContraMean);
       end
       FRIpsi= cell2mat(FRAll.IpsiMean);

       % normalize FRs
       
        for unitNum = 1: height(FRContra)
            maxFRInd = max([FRContra(unitNum,:), FRIpsi(unitNum, :)], [],'All');
            FRContra(unitNum, :) = FRContra(unitNum, :)/maxFRInd;
            FRIpsi(unitNum, :) = FRIpsi(unitNum, :)/maxFRInd;
        end

       respIDs = cell2mat(FRAll.RespID);
       respIDs = respIDs + 1;
        
       cmapResp = [[0 0 1]; [1 1 1]; [1 0 0]];

       diffs = diff(respIDs);
       ipsibounds = find(diffs==-2);
        respBounds = find(diffs==-1);
       if strcmp(uGenotypes{genotype}, 'KO')
          
            if isempty(ipsibounds)
                disp([uGenotypes{genotype} ': contra till: ' num2str(respBounds(1)) ' Ipsi from: ' num2str(respBounds(2)+1) ]); 
            else
                disp([uGenotypes{genotype} ': contra till: ' num2str(respBounds(1)) ' Ipsi from: ' num2str(ipsibounds(1)+1) ]); 
            end

       elseif strcmp(uGenotypes{genotype}, 'WT')
            if isempty(ipsibounds)
                if numel(respBounds) ==1
                    disp([uGenotypes{genotype} ': contra till: ' num2str(respBounds(1)) ' Bilat from: ' num2str(respBounds(1)+1) ]);
                else
                    disp([uGenotypes{genotype} ': contra till: ' num2str(respBounds(1)) ' Ipsi from: ' num2str(respBounds(2)+1) ]); 
                end
            else
                disp([uGenotypes{genotype} ': contra till: ' num2str(respBounds(1)) ' Ipsi from: ' num2str(respBounds(1)+1) ]); 
            end
       end

       maxFR = max([FRContra; FRIpsi], [], 'All');
%        maxFR = 100;

      
       
       
        % plot data
       g = figure(genotype); clf;
       set(g, 'Units', 'inches', 'Position', [1, 1, 1.6, 2.75]);
       s(1) = subplot(1,21, 1:10, 'Parent', g);
       imagesc(FRAll.Time{1}, 1:height(FRContra), FRContra);
       
       line([0, 0], [1, height(FRContra)], 'Color', 'k', 'LineStyle', '--', 'Linewidth', 1); % Stimulus onset
       yTicks = 20:20:max(height(FRContra)) ;
       xlim(ops.plotxLims)
        set(s(1), 'Units', 'inches', 'Position', [0.24, 0.2, 0.45, 2.45], 'FontSize', 8, 'FontName', 'Arial', ...
            'Ytick', yTicks, 'TickDir', 'out',  'LineWidth', 1);            
        s(1).YTickLabel{1} = ''; 
        

       % Create custom colormap: black to red
        numColors = 256; % Number of colors in the colormap
        customColormap = [ones(numColors, 1), 1-linspace(0, 1, numColors)', 1-linspace(0, 1, numColors)'];        
        
        % Apply the custom colormap
        colormap(gca, customColormap);
        caxis([0 maxFR]);
        if strcmp(uGenotypes{genotype}, 'WT')
            h(1) = colorbar;
            
            set(h(1), 'Units', 'inches', 'Position', [0.12, 2.25, 0.08, 0.4]);
            h(1).Color = [0 0 0];
            h(1).LineWidth = 0.5;
            h(1).TickLabels(2) = {''};
        end

        s(1).XTickLabel{4} = '100';

        
        
       s(2)= subplot(1,21, 11:20, 'Parent', g);       
       imagesc(FRAll.Time{1}, 1:height(FRIpsi), FRIpsi);
       line([0, 0], [1, height(FRContra)], 'Color', 'k', 'LineStyle', '--', 'Linewidth', 1); % Stimulus onset
       xlim(ops.plotxLims)
       set(s(2), 'Units', 'inches', 'Position', [0.95, 0.2, 0.45, 2.45], 'FontSize', 8, 'FontName', 'Arial', 'Ytick', yTicks, 'TickDir', 'out', ...
                'YTickLabel', [], 'LineWidth', 1);
        s(2).YTickLabel{1} = '';
        s(2).XTickLabel = {'', '0', '', '100'};

        % Create custom colormap: black to red
        numColors = 256; % Number of colors in the colormap
        customColormap = [1-linspace(0, 1, numColors)', 1-linspace(0, 1, numColors)', ones(numColors, 1)];
        
        % Apply the custom colormap
        colormap(gca, customColormap);
        caxis([0 maxFR]);
        if strcmp(uGenotypes{genotype}, 'WT')
            h(2) = colorbar;
            
            set(h(2), 'Units', 'inches', 'Position', [0.83, 2.25, 0.08, 0.4]);
            h(2).Color = [0 0 0];
            h(2).LineWidth = 0.5;
            h(2).TickLabels(2) = {''};
        end
      

       s(3)= subplot(1,21, 21, 'Parent', g);       
       imagesc(respIDs);
       colormap(s(3), cmapResp); 
        set(s(3), 'Units', 'inches', 'Position', [1.45, 0.2, 0.05, 2.45], 'FontSize', 8, 'FontName', 'Arial', 'Xtick', [], 'Ytick', [], 'TickDir', 'out', ...
                'YTickLabel', [], 'LineWidth', 1);

      if withLabels
        set(g, 'Renderer', 'Painters');  
        print(g, fullfile(ops.savePath, ['All freq Average FR heatmap labels ' uGenotypes{genotype}]),  '-dsvg', '-r300');
      else
        
        savefig(g,fullfile(ops.savePath, ['All freq Average FR heatmap ' uGenotypes{genotype} '.fig']));
        exportgraphics(g, fullfile(ops.savePath, ['All freq Average FR heatmap ' uGenotypes{genotype} '.tiff']), 'Resolution', '300');
      end
        
    

   end
        
   
  
   

end


function RawFRHeatmapsAllFreq(ops, metadataTable, meanFRTable, plotAlpha, window, withLabels)
% plot heatmaps of contra responsive to ipsi responsive sorted by cbias
    genotypes = metadataTable.genotype;
    cBias = metadataTable.cbias;
    pvals = metadataTable.pvalBoth;
    pvalContra = metadataTable.pvalContra;
    pvalIpsi = metadataTable.pvalIpsi;

    uGenotypes = unique(genotypes);
    close all;
    variableNames = {'Time', 'ContraMean', 'ContraCI', 'IpsiMean', 'IpsiCI', 'CBias', 'RespID'};
   bins = -0.05:0.001:0.05;
   % get genotype sessions.
   uFreq = {'10hz', '20hz', '40hz'};
   xlimWin = str2num(window)/1000;
   ops.plotAlpha = plotAlpha;
   
   for genotype = 1:numel(uGenotypes)
       
       
       cBiasGeno = cBias(strcmp(metadataTable.genotype, uGenotypes{genotype}),:);
       pvalGeno = pvals(strcmp(metadataTable.genotype, uGenotypes{genotype}),:);
       pvalContraGeno = pvalContra(strcmp(metadataTable.genotype, uGenotypes{genotype}),:);
       pvalIpsiGeno = pvalIpsi(strcmp(metadataTable.genotype, uGenotypes{genotype}),:);
       FRGeno = meanFRTable.meanFR(strcmp(metadataTable.genotype, uGenotypes{genotype}),:);
       
       FRAll = table('Size', [0, length(variableNames)], 'VariableTypes', repmat("cell", 1, length(variableNames)), 'VariableNames', variableNames);
       % collect all the unit FRs that are significant in any.
       for animal = 1:height(pvalGeno)
           


           pvalAni = pvalGeno{animal}.(window);
           pvalContraAni = pvalContraGeno{animal}.(window);
           pvalIpsiAni = pvalIpsiGeno{animal}.(window);
           cBiasAni = cBiasGeno{animal}.(window);
           FRAni = FRGeno{animal}.('300');
           for session = 1:height(pvalAni)
               pvalSess = pvalAni{session};
               pvalIpsiSess = pvalIpsiAni{session};
               pvalContraSess = pvalContraAni{session};
               cBiasSess = cBiasAni{session};
               FRSess = FRAni{session};
                
                if width(pvalSess) >3
                    
                    pvalSess = cell2mat(table2array(pvalSess(:,"20hz"))); 
                    pvalIpsiSess = cell2mat(table2array(pvalIpsiSess(:,"20hz")));  
                    pvalContraSess = cell2mat(table2array(pvalContraSess(:,"20hz")));
                    cBiasSess = table2array(cBiasSess(:,"20hz"));
                    FRSess = table2array(FRSess(:,1:3));
                    for unitNum = 1:height(FRSess)
                        temp = FRSess(unitNum, :);
                        temp = vertcat(temp{:});
                        FRSess{unitNum, 4} = FRSess{unitNum,3};
                        
                        FRSess{unitNum,4}.ContraMean = {mean(cell2mat(temp.ContraMean), 1)};
                        FRSess{unitNum,4}.IpsiMean = {mean(cell2mat(temp.IpsiMean), 1)};

                        FRSess{unitNum,4}.ContraCI = {[]};
                        FRSess{unitNum,4}.IpsiCI = {[]};
                        


                    end
                    FRSess = FRSess(:,4);
                    FRSess = vertcat(FRSess{:});
                    
                elseif width(pvalSess) <3
                    
                    pvalSess = cell2mat(table2array(pvalSess)); 
                    pvalIpsiSess = cell2mat(table2array(pvalIpsiSess));  
                    pvalContraSess = cell2mat(table2array(pvalContraSess));
                    cBiasSess = table2array(cBiasSess);
                    FRSess = table2array(FRSess);
                    FRSess = vertcat(FRSess{:});   
                    
                else
                    continue;
                    
                end
                        
                %%%%% Find the session is contra or ipsi by # of responsive units to contra >ipsi %%%%%%%%
                % find the minimum of the pval in any stim.
%                 pvalSess = min(pvalSess,[],2);
                        
                        
                
                sumlogics = sum(pvalSess < ops.plotAlpha,2);
                sigUnits = find(sumlogics>0);

                cBiasSess =cBiasSess(sigUnits,:);
                cBiasMat =  cell2mat(cBiasSess)
                pvalIpsiSess = pvalIpsiSess(sigUnits,:);
                pvalContraSess = pvalContraSess(sigUnits,:);
                responsiveIdentity = zeros(height(cBiasSess), 1);
%                 contraOnlyUnits = find(pvalContraSess<ops.plotAlpha & pvalIpsiSess>ops.plotAlpha);
%                 ipsiOnlyUnits = find(pvalContraSess>ops.plotAlpha & pvalIpsiSess<ops.plotAlpha);
%                 responsiveIdentity(contraOnlyUnits,1) = ones(height(contraOnlyUnits), 1);
%                 responsiveIdentity(ipsiOnlyUnits,1) = ones(height(ipsiOnlyUnits), 1)*-1;

                contraOnlyUnits = find(cBiasMat>=0.33);
                ipsiOnlyUnits = find(cBiasMat<-0.33);
                responsiveIdentity(contraOnlyUnits,1) = ones(height(contraOnlyUnits), 1);
                responsiveIdentity(ipsiOnlyUnits,1) = ones(height(ipsiOnlyUnits), 1)*-1;

                FRSess = FRSess(sigUnits,:);
                FRSess.CBias = cBiasSess;
                FRSess.RespID = num2cell(responsiveIdentity);
                try
                FRAll = vertcat(FRAll, FRSess);
                catch
                    keyboard;
                end
                
            end
       end
      
       % plot heatmaps using imagesc

       FRAll = sortrows(FRAll, {'RespID', 'CBias'}, 'descend');
        
       try
           FRContra= cell2mat(FRAll.ContraMean);
       catch
           
           FRTime = FRAll.Time;
           incompleteUnits = find(diff(cell2mat(cellfun(@numel, FRTime, 'UniformOutput', false)))<0)+1;
           FRAll(incompleteUnits, :) = [];
           FRContra= cell2mat(FRAll.ContraMean);
       end
       FRIpsi= cell2mat(FRAll.IpsiMean);

       % normalize FRs
       
%         for unitNum = 1: height(FRContra)
%             maxFRInd = max([FRContra(unitNum,:), FRIpsi(unitNum, :)], [],'All');
%             FRContra(unitNum, :) = FRContra(unitNum, :)/maxFRInd;
%             FRIpsi(unitNum, :) = FRIpsi(unitNum, :)/maxFRInd;
%         end

       respIDs = cell2mat(FRAll.RespID);
       respIDs = respIDs + 1;
        
       cmapResp = [[0 0 1]; [1 1 1]; [1 0 0]];

       diffs = diff(respIDs);
       ipsibounds = find(diffs==-2);
        respBounds = find(diffs==-1);
       if strcmp(uGenotypes{genotype}, 'KO')
          
            if isempty(ipsibounds)
                disp([uGenotypes{genotype} ': contra till: ' num2str(respBounds(1)) ' Ipsi from: ' num2str(respBounds(2)+1) ]); 
            else
                disp([uGenotypes{genotype} ': contra till: ' num2str(respBounds(1)) ' Ipsi from: ' num2str(ipsibounds(1)+1) ]); 
            end

       elseif strcmp(uGenotypes{genotype}, 'WT')
            if isempty(ipsibounds)
                if numel(respBounds) ==1
                    disp([uGenotypes{genotype} ': contra till: ' num2str(respBounds(1)) ' Bilat from: ' num2str(respBounds(1)+1) ]);
                else
                    disp([uGenotypes{genotype} ': contra till: ' num2str(respBounds(1)) ' Ipsi from: ' num2str(respBounds(2)+1) ]); 
                end
            else
                disp([uGenotypes{genotype} ': contra till: ' num2str(respBounds(1)) ' Ipsi from: ' num2str(respBounds(1)+1) ]); 
            end
       end

       maxFR = max([FRContra; FRIpsi], [], 'All');
       maxFR = 15;
%        maxFR = 100;

      
       
       
        % plot data
       g = figure(genotype); clf;
       set(g, 'Units', 'inches', 'Position', [1, 1, 1.6, 2.75]);
       s(1) = subplot(1,21, 1:10, 'Parent', g);
       imagesc(FRAll.Time{1}, 1:height(FRContra), FRContra);
       
       line([0, 0], [1, height(FRContra)], 'Color', 'k', 'LineStyle', '--', 'Linewidth', 1); % Stimulus onset
       yTicks = 20:20:max(height(FRContra)) ;
       xlim(ops.plotxLims)
        set(s(1), 'Units', 'inches', 'Position', [0.24, 0.2, 0.45, 2.45], 'FontSize', 8, 'FontName', 'Arial', ...
            'Ytick', yTicks, 'TickDir', 'out',  'LineWidth', 1);            
        s(1).YTickLabel{1} = ''; 
        

       % Create custom colormap: black to red
        numColors = 256; % Number of colors in the colormap
        customColormap = [ones(numColors, 1), 1-linspace(0, 1, numColors)', 1-linspace(0, 1, numColors)'];        

        % Apply the custom colormap
        colormap(gca, customColormap);
%         if strcmp(uGenotypes{genotype}, 'WT')
            h(1) = colorbar;
            caxis([0 maxFR]);
            set(h(1), 'Units', 'inches', 'Position', [0.12, 2.25, 0.08, 0.4]);
            h(1).Color = [0 0 0];
            h(1).LineWidth = 0.5;
            h(1).TickLabels(2) = {''};
%         end

        s(1).XTickLabel{4} = '100';

        
        
       s(2)= subplot(1,21, 11:20, 'Parent', g);       
       imagesc(FRAll.Time{1}, 1:height(FRIpsi), FRIpsi);
       line([0, 0], [1, height(FRContra)], 'Color', 'k', 'LineStyle', '--', 'Linewidth', 1); % Stimulus onset
       xlim(ops.plotxLims)
       set(s(2), 'Units', 'inches', 'Position', [0.95, 0.2, 0.45, 2.45], 'FontSize', 8, 'FontName', 'Arial', 'Ytick', yTicks, 'TickDir', 'out', ...
                'YTickLabel', [], 'LineWidth', 1);
        s(2).YTickLabel{1} = '';
        s(2).XTickLabel = {'', '0', '', '100'};

        % Create custom colormap: black to red
        numColors = 256; % Number of colors in the colormap
        customColormap = [1-linspace(0, 1, numColors)', 1-linspace(0, 1, numColors)', ones(numColors, 1)];

        % Apply the custom colormap
        colormap(gca, customColormap);
%         if strcmp(uGenotypes{genotype}, 'WT')
            h(2) = colorbar;
            caxis([0 maxFR]);
            set(h(2), 'Units', 'inches', 'Position', [0.83, 2.25, 0.08, 0.4]);
            h(2).Color = [0 0 0];
            h(2).LineWidth = 0.5;
            h(2).TickLabels(2) = {''};
%         end
      

       s(3)= subplot(1,21, 21, 'Parent', g);       
       imagesc(respIDs);
       colormap(s(3), cmapResp); 
        set(s(3), 'Units', 'inches', 'Position', [1.45, 0.2, 0.05, 2.45], 'FontSize', 8, 'FontName', 'Arial', 'Xtick', [], 'Ytick', [], 'TickDir', 'out', ...
                'YTickLabel', [], 'LineWidth', 1);

      if withLabels
        set(g, 'Renderer', 'Painters');  
        print(g, fullfile(ops.savePath, ['All freq Average FR heatmap labels ' uGenotypes{genotype}]),  '-dsvg', '-r300');
      else
        
        savefig(g,fullfile(ops.savePath, ['All freq Average FR heatmap ' uGenotypes{genotype} '.fig']));
        exportgraphics(g, fullfile(ops.savePath, ['All freq Average FR heatmap ' uGenotypes{genotype} '.tiff']), 'Resolution', '300');
      end
        
    

   end
        
   
  
   

end

