


%% Plot units separated by whisker stim duration. Contra vs ipsi, combine for left vs right hemisphere recording . combine plotsession_maps
% It also has LFPs
% Stims are taken as only the first deflection of all frequencies 
% clear all
% 
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\StimSEs', 'Select source SEs');

clear all
animalID = {'VC030107','VC030109','VC030112','VC030114', 'VC030115', 'VC030209','VC030206',  'VC030208',   'VC030401', 'VC030402', 'VC030211', 'VC030213'};
% animalID = {'VC030211'};
% animalID = {'VC030401'};
% Choose a group folder
rootDir = 'G:\VC03_RoboKO';
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
        case 'StimSEs_2_5msFR'          
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

%% load each session and update histology and penetration depth
parfor i = 1:height(dataFileTb)    
    se{i} = loadsess(dataFileTb.sePath{i});    
    se{i}.userData.sessionInfo.penetrationDepth = dataFileTb.penetrationDepth(i);
    se{i}.userData.sessionInfo.histology = dataFileTb.histology(i);
    se{i}.userData.sessionInfo.corticaldepth = dataFileTb.CorticalDepth(i);
    savesess(dataFileTb.sePath{i},se{i});
end

%% Add channel coords where kcoords are the shank #
% Computing spike rate


% load histology_wM1
histTable = readtable('G:\VC03_RoboKO\EphysPassiveStimSEs\Histology\Histology_wS1_final.csv');


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
    if isempty(sessNum)
        continue;
    end
    animalName = histTable.AnimalName{sessNum};
    searchFolder = fullfile('G:\VC03_RoboKO\EphysPassiveStimSEs\Histology', animalName);
    folderNames = dir(searchFolder);
   
    for ii = 1: height(folderNames)
        if sum(ismember(folderNames(ii).name,'wS1_'))>=4
            save_folder = fullfile(searchFolder, folderNames(ii).name, 'Processed');
        end
    end


    object_save_name_suffix = [histTable.ProbeSuffix{sessNum} '_' histTable.SessDate{sessNum}];
    
    probeFilePath = fullfile(save_folder, ['probe_points' object_save_name_suffix '.mat']);
    probeFile = fullfile(save_folder, ['probe_points' object_save_name_suffix]);

    
  %

    % load probe points
    if isfile(probeFilePath)
        % load se    
        se{i} = loadsess(dataFileTb.sePath{i}); 
        %
        
%         if ~ismember({'zRate'}, se{i}.tot.Properties.RowNames)
%             BS.SE.AddZscoreRateTable(se{i});
%         end
%         
        try
            se{i}.userData.spikeInfo.chanMap = se{i}.userData.sessionInfo.chanmap;
        catch
            se{i}.userData.spikeInfo.chanMap = se{i}.userData.sessionInfo.channel_map;
        end

        ycoords = se{i}.userData.spikeInfo.chanMap.ycoords;
        if size(ycoords,2)>1
            ycoords = ycoords';
        end
        xcoords = se{i}.userData.spikeInfo.chanMap.xcoords;
        if size(xcoords,2)>1
            xcoords = xcoords';
        end
        kcoords = se{i}.userData.spikeInfo.chanMap.kcoords;
        if size(kcoords,2)>1
            kcoords = kcoords';
        end

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

        for selected_probe = probes(1)
            
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
        

         % focus on wireframe plot
        figure(fwireframe);
        
       
        % plot brain entry point
%         plot3(m(1), m(3), m(2), 'r*','linewidth',1)

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
            if probeLocations{i}(point,2)>0
                % find the annotation, name, and acronym of the current ROI pixel
                ann = av(probeLocations{i}(point,1)/10,probeLocations{i}(point,2)/10,probeLocations{i}(point,3)/10);
                name = st.safe_name{ann};
                acr = st.acronym{ann};
        
                roi_annotation_curr{point,1} = ann;
                roi_annotation_curr{point,2} = name;
                roi_annotation_curr{point,3} = acr;
            end
    
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
%             plot3(m(1)+p(1)*(unit_ycoord), m(3)+p(3)*(unit_ycoord), m(2)+p(2)*(unit_ycoord), ...
%             'w.', 'LineWidth', 1);
             plot3(bregma(1) - unitEucl(1), bregma(3) + unitEucl(3),bregma(2) + unitEucl(2), ...
            'r.', 'LineWidth', 1);
%             
            

        end


        se{i}.userData.spikeInfo.unitHitsoTable = unitRoiTable{i};
        savesess(dataFileTb.sePath{i},se{i});
    end
end



%% Region specific window (wM1~250ms)

clearvars -except dataFileTb groupDir
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
ops.statAlpha = 0.005;
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
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\allWins',[strjoin(animalIds, '_') '_NP\AllUnitswS1',FRbin]);
else
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\firstcyc',[strjoin(animalIds, '_') '_NP\AllUnitswS1',FRbin], [num2str(0.005) ' numcyc=' num2str(ops.numcyc) 'paired selective']);
end


%% load metadata variables
load(fullfile(ops.savePath, "allVars.mat"),'metadataTable');

% load FRdata variables
load(fullfile(ops.savePath, "FRdataVars.mat"),'FRdataTable');


%% Merge for YT

FRdataTable.pvalMin = metadataTable.pvalBoth;
FRdataTable.pvalContra = metadataTable.pvalContra;
FRdataTable.pvalIpsi = metadataTable.pvalIpsi;
FRdataTable.genotype = metadataTable.genotype;

save('S1DataTable.mat', "FRdataTable", '-v7.3');

%% load spikeData variables
load(fullfile(ops.savePath, "allVars.mat"),'spikedataTable');

%% Make variables for raster FR rate, etc
GetComposite(dataFileTb, ops);

%% Make variables for raster FR rate, etc
GetFRData(dataFileTb, ops);


%% Add meanFR data
AddMeanFRData(ops, FRdataTable);

%%  Load MeanFRTable
load(fullfile(ops.savePath, "meanFRTable.mat"),'meanFRTable');


 %% Calculate sig units for each GT and then do binomial test. 
 ops.binWidth = 0.0025;
 IpsiresponsiveLatencies(ops, metadataTable, meanFRTable );

%% plot Rasters
MakeFigures(fullfile(ops.savePath, fileName));


 %% Plot indivdual rasters and FRs

 MakeIndUnitFigures(fullfile(ops.savePath,fileName), 'E:\oconnorlab Dropbox\oconnorlab Team Folder\users\Varun\SfnPresentations\BarrelsPosterAttempt2023');


%% Plot FR or FRdata across all mice in a genotype
ops.plotAlpha = 0.01;
for win = 5 % just plotting 100ms
    window = ops.WindowNames{win};
    PlotAvgTracesFR(dataFileTb, ops, metadataTable, FRdataTable, window);
end
%% Plot FR or FRdata across all mice in a genotype only plot WT contra vs ipse and KO contra v ipsi
ops.plotAlpha = 0.01;
maxFR = 35;
ops.plotxLims = [-0.05, 0.05];
ops.savePath = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\Fig3';
for win = 3 % just plotting 100ms
    window = ops.WindowNames{win};
    PlotAvgTracesFRFinal(dataFileTb, ops, metadataTable, FRdataTable, window, maxFR);
end

 %% Plot Cbiastable
ops.binWidth = 0.25;
ops.plotAlpha = 0.01;
minUnits =1;
MakeCbiasFigures(ops, ops.binWidth, ops.savePath, metadataTable, minUnits);

%% Plot cbiasTables but for resp units in 20hz and 150ms. Cbias calculated from 1 cycle window. 
ops.binWidth = 0.25;
ops.plotAlpha = 0.01;
minUnits =1;
ops.savePath = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\Fig3';
MakeCbiasFiguresFinal(ops, ops.binWidth, ops.savePath, metadataTable, minUnits);


%% PLot Depth vs Cbias histogram. 
% Take depths of every 20um bin size and plot cBias histogram
%  L1, 128 ± 1 μm; L2, 269 ± 2 μm; L3, 418 ± 3 μm; L4, 588 ± 3 μm; L5A, 708 ± 4 μm; L5B, 890 ± 5 μm; L6, 1154 ± 7 μm.
% Lefort et al Neuron 2009
ops.binWidth = 0.25;
ops.plotAlpha = 0.01;
CBiasDepthHisto(ops, metadataTable);
% Minamisawa et al Cell rep 2018
     % The upper boundaries of L2/3, L4, L5A, L5B, L6 were as follows: 0.081 ± 0.019, 0.279 ± 0.028, 0.440 ± 0.039, 0.538 ± 0.032, 0.651 ± 0.026 in S1

%% PLot Depth vs Cbias histogram -- line plot. 

ops.plotAlpha = 0.01;

ops.parts =3;
CBiasDepthHistoBar(ops, metadataTable);

%% PLot Depth vs Cbias histogram. 

ops.plotAlpha = 0.01;

ops.parts =3;
nboot = 1000;
LTwoThree = 468/1154;
LFour = 638/1154;
CBiasDepthHistoLine3(ops, metadataTable, nboot, LTwoThree, LFour);


%% PLot Depth vs Cbias histogram. 

ops.plotAlpha = 0.01;

ops.parts =3;
nboot=10;
LTwoThree = 418/1154;
LFour = 588/1154;
CBiasDepthHistoLinefinal(ops, metadataTable, nboot, LTwoThree, LFour);

%% PLot histo
ops.plotAlpha = 0.01;
minUnits =1;
for win = 1:numel(ops.WindowNames) % just plotting 100ms
    window = ops.WindowNames{win};
    PlotHistoResponsiveness(metadataTable,ops.plotAlpha, ops.savePath, window, minUnits);

end


%%
genotype = {'Genotype1'; 'Genotype1'; 'Genotype1'; 'Genotype2'; 'Genotype2'; 'Genotype2'};
responseType = {'Ipsilateral'; 'Bilateral'; 'Contralateral'; 'Ipsilateral'; 'Bilateral'; 'Contralateral'};
percentage = [25; 50; 25; 20; 60; 20];

% Convert categorical data to factors
genotype = categorical(genotype);
responseType = categorical(responseType);

% Create a table
dataTable = table(genotype, responseType, percentage);
%% PLot histo vs CBias
ops.plotAlpha = 0.01;
minUnits =1;

% for win = 1:numel(ops.WindowNames) % just plotting 100ms
for win = 3
    window = ops.WindowNames{win};
    PlotHistoCBias(metadataTable,ops.plotAlpha, ops.savePath, window, minUnits);
end


%% PLot FR heatmaps Fig2C
withLabels =1;
ops.plotAlpha = 0.01;
window = [ops.WindowNames(8), ops.WindowNames(6),ops.WindowNames(4)];
ops.plotxLims = [-0.05, 0.05];
FRHeatmapsEachFreq(ops, metadataTable, meanFRTable, ops.plotAlpha, window, withLabels);

%% PLot FR heatmaps Fig2C for all freq
% significant only determined by 20hz response in 150 ms window
withLabels =1;
ops.plotAlpha = 0.01;
window = ops.WindowNames{6};
ops.plotxLims = [-0.05, 0.05];
FRHeatmapsAllFreq(ops, metadataTable, meanFRTable, ops.plotAlpha, window, withLabels);      

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

function outputTable = SignifyTable(inputTable,pvalTable, ops)
    
    for ani = 1:numel(pvalTable)
        anipvalTable = pvalTable{ani};

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

function [unitLayer, layer_index] = assignLayer(depth)
    % Minamisawa et al Cell rep 2018
    % The upper boundaries of L2/3, L4, L5A, L5B, L6 were as follows: 0.081 ± 0.019, 0.279 ± 0.028, 0.440 ± 0.039, 0.538 ± 0.032, 0.651 ± 0.026 in S1
    allLayers = {'L1', 'L2/3', 'L4', 'L5A', 'L5B', 'L6'};
    ranges = [-1.5, 0.081, 0.279, 0.440, 0.538, 0.651, 1.5];
    layer_index = find(depth<=ranges,1)-1;    
    unitLayer = allLayers{layer_index};    
    
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
    
    variableNames = {'genotype', 'pvalBoth', 'pvalContra', 'pvalIpsi', 'UnitDepth', 'adc', 'cbias', 'bodysideTask', 'HistoTable'};
    
    readPaths= dataFileTb.sePath;
    uGenotypes = unique(dataFileTb.Genotype);
    genotypes = dataFileTb.Genotype;
    sessDates = dataFileTb.sessionDatetime;
    subIds = dataFileTb.subId;
    
    bins = tWins(1):binSize:tWins(2);
    dataTable = cell(numel(uniAnimalId), numel(variableNames));
    metadataTable = cell2table(dataTable, 'RowNames', uniAnimalId, 'VariableNames', variableNames);
    spikedataTable = cell2table(cell(numel(uniAnimalId), 1), 'RowNames', uniAnimalId, 'VariableNames', {'spikeTimes'});
    
    for animal = 1:numel(uniAnimalId)
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
        close all
        tic
        for sessNum = 1:numel(sessArray)
%
            se =loadsess(animalReadPaths{sessNum});
            %
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
            if isempty(str2num(ufreq{1}))
                ufreq = unique(cellfun(@(x) x(17:18),uStimTypes, 'UniformOutput', false)); % for gettign just the unique frequencies irrespective of the cycles
                freqStart = 17;
            else
                freqStart =5;
            end

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
                
            sessInfoTable = se.userData.sessionInfo;

            if ismember('penetrationDepth', sessInfoTable.Properties.VariableNames)
%                         penetrationDepth = sessInfoTable.penetrationDepth;
                penetrationDepth = sessInfoTable.histology;
                corticalDepth = sessInfoTable.corticaldepth;
            else
                penetrationDepth = defPenetrationDepth;
                corticalDepth = 1280;
            end
                    
            
            % for all the stimDurs
            for stimDur = 1:numel(ufreq)

                
                if numel(ufreq)<3
                    
                    pstimDur = stimDur +1;
                    bodyside7 =7;
                else
                    bodyside7 =8;
                    pstimDur = stimDur;
                end     

                try
                    unitChanDepth = se.userData.spikeInfo.quality_metrics.depth;
                catch
                    
                    chanDepth = 0:20:1260; %(in um)
                    channelInds = se.userData.spikeInfo.unit_channel_ind;
                    chanMap = se.userData.sessionInfo.channel_map.chanMap;
                    [~, chanPos] = ismember(channelInds,chanMap);
                    unitChanDepth= chanDepth(chanPos);
                    
                end
                
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
                        frAllwin = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                    end

                    leftStimTypes = behavData.leftStimType;
                    rightStimTypes = behavData.rightStimType;

                   
                    
                    trials2keepL= find(strcmp(trials{1}{1}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(freqStart:freqStart+1),ufreq{stimDur}), ...
                            leftStimTypes, 'UniformOutput',false)));
                    trials2keepR = find(strcmp(trials{1}{2}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(freqStart:freqStart+1),ufreq{stimDur}), ...
                            rightStimTypes, 'UniformOutput',false)));
                    
                    


                    FRLeft  = frAllwin (trials2keepL ,2:end);
                    FRRight  = frAllwin (trials2keepR ,2:end);
                    FRtime  = frAllwin (trials2keepR ,1);
                    
                    %get p-value based on windowsize = stim duration                        
                    preWindow  = 1:(round(numel(FRLeft {1})/2));
                    postWindow  =  preWindow(end)+1: numel(FRLeft {1}); 
                    temp1 = preWindow ;
                    temp2 = postWindow ;

                    preMeanFRL  = cell2mat(cellfun(@(x) mean(x(temp1)), FRLeft , 'UniformOutput', false));
                    postMeanFRL  = cell2mat(cellfun(@(x) mean(x(temp2)), FRLeft , 'UniformOutput', false));
                    preMeanFRR  = cell2mat(cellfun(@(x) mean(x(temp1)), FRRight , 'UniformOutput', false));
                    postMeanFRR  = cell2mat(cellfun(@(x) mean(x(temp2)), FRRight , 'UniformOutput', false));
                    
                    % get spikeTimes for FRlims
                    FRlims  = [tWins(1) tWins(2)];               
                    spikeLeft = spikeAll(trials2keepL ,1:end);
                    spikeRight = spikeAll(trials2keepR ,1:end);          
                    binsWin  = find(bins>= FRlims (1) & bins<= FRlims (2));
                    temp = binsWin (1:end-1);
%                     
%                     frAllplot  = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
%                     FRLeft  = frAllplot (trials2keepL ,2:end);
%                     FRRight  = frAllplot (trials2keepR ,2:end);
%                     FRtime  = frAllplot (:,1);        
% 

                 

                    adcLeft = adcAllLeft(trials2keepL);
                    idcs = min(cell2mat(cellfun(@(x) numel(x), adcLeft, 'UniformOutput',false)));
                    adcLeft = cell2mat(cellfun(@(x) x(1:idcs), adcAllLeft(trials2keepL), 'UniformOutput', false));
                    adcTime =  cell2mat(cellfun(@(x) x(1:idcs), adcAllTime(trials2keepL), 'UniformOutput', false));
                    adc{1,1} = mean(adcTime, 1) ;
                    adc{2,1} = mean(adcLeft, 1) ;
                   

%                             maxAdc{genotype}{recSite}(sessNum,stimDur) = max(adc (2,:));
                    
                    if sum(ismember('Left', sessRecSite))==4
                        stims = {trials2keepL , trials2keepR };
                    else
                        stims = {trials2keepR , trials2keepL };
                    end
                   
                    win = ops.WindowNames{window};

                    try
                        for unitNum = 1: size(preMeanFRL ,2)   
                            
                            unitDepth = unitChanDepth(unitNum);

                            
                            [pvalL] = signrank(preMeanFRL (:,unitNum), postMeanFRL (:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);
                            [pvalR] = signrank(preMeanFRR (:,unitNum), postMeanFRR (:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);
                 
%                             meanFRtime =  mean(cell2mat(FRtime),1);
                        
                            if sum(ismember(sessRecSite, 'Left'))==4
                                uSpikesIpsi = spikeLeft(:,unitNum);
                                uSpikesContra = spikeRight(:,unitNum);
                                pValIpsi = pvalL;
                                pValContra = pvalR;
%                                 [uFRI, ~ ,~, ciFRI] =  MMath.MeanStats(cell2mat(FRLeft(:,unitNum)),1);
%                                 uFRC = mean(cell2mat(FRRight(:,unitNum)),1);
                            else
                                uSpikesIpsi = spikeRight(:,unitNum);
                                uSpikesContra = spikeLeft(:,unitNum);
                                pValIpsi = pvalR;
                                pValContra = pvalL;
%                                 [uFRI, ~ ,~, ciFRI] = MMath.MeanStats(cell2mat(FRRight(:,unitNum)),1);
%                                 uFRC = mean(cell2mat(FRLeft(:,unitNum)),1);
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
                            
                            
%                             if  pValIpsi < 0.05 && window ==7
%                                 
%                                 disp(['sessNum = ' num2str(sessNum) ' UnitNum= ' num2str(unitNum) ' Window= ' ops.WindowNames{window} ...
%                                     ' pvalIpsi= ' num2str(pValIpsi) ' freq = ' ufreq{pstimDur}]);
%                                 g = figure(1);clf
%                                 hold on
%                                 yyaxis left;
%                                 for i = 1:height(uSpikesIpsi)                                
%                                     MPlot.PlotPointAsLine(uSpikesIpsi{i}*1000, (i+1)*ones(numel(uSpikesIpsi{i}),1) ,1, 'orientation', 'vertical', ...
%                                         'linestyle', '-','color','b', 'linewidth', 1, 'Marker', 'none');
%                                 end                                
%                                 yLimits = ylim;
%                                 ylim([0,yLimits(2)]);
%                                 
%                                 MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--', ...
%                                 'color',[0 0 0], 'linewidth', 1);
%                                 ylabel('Trials')
% 
%                                 
%                                 yyaxis right;
%                                 plot(meanFRtime*1000, uFRI, 'LineStyle', '-', 'color', 'r');
%                                 MPlot.ErrorShade(meanFRtime*1000, uFRI, ciFRI(2,:), ...
%                                             ciFRI(1,:), 'color','r', 'Alpha', 0.3, 'IsRelative', false); 
%                                 ylabel('FR hz')
%                                 xlim([-ops.windows(window) ops.windows(window)]*1000);
%                                 
%                              
% 
% 
%                                 hold off
%                                 title(['sessNum = ' num2str(sessNum) ' UnitNum= ' num2str(unitNum) ' Window= ' ops.WindowNames{window} ...
%                                     ' pvalIpsi= ' num2str(pValIpsi) ' freq = ' ufreq{pstimDur}]);
%                                 saveTemp = fullfile(savePath, animalId);
%                                 if ~isfolder(saveTemp)
%                                     mkdir(saveTemp);
%                                 end
%                                 saveas(g, fullfile(saveTemp, ['sessNum = ' num2str(sessNum) ' UnitNum= ' num2str(unitNum) ' Window= ' ops.WindowNames{window} ...
%                                     ' pvalIpsi= ' num2str(pValIpsi) ' freq = ' ufreq{pstimDur} '.png']));
% 
%                                
%                             end


                            C = abs(postSpikesContra - preSpikesContra);
                            I = abs(postSpikesIpsi - preSpikesIpsi);
                           
                            Cbias = (C-I)/(C+I);
    
                            spikeTimes = {uSpikesContra, uSpikesIpsi};
                       
                           
                            unitDepth = (penetrationDepth-unitDepth)/corticalDepth;
                            
                           
                            
                            animalTable.pvalBoth{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = pvalstimDur;
                            animalTable.bodysideTask{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = bodyside7;
                            animalTable.pvalIpsi{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = pValIpsi;
                            animalTable.pvalContra{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = pValContra;
                            spikeAnimalTable.spikeTimes{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = spikeTimes;
                           
                            animalTable.UnitDepth{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = unitDepth;
                            
                            if any(ismember(fieldnames(se.userData.spikeInfo), 'unitHitsoTable'))
                                unitHistoTable = se.userData.spikeInfo.unitHitsoTable(unitNum,:);    
                                unitHistoTable.unitDepth = unitDepth;
                                animalTable.HistoTable{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = unitHistoTable;
                            else
                                animalTable.HistoTable{animalId}.(win){sessName}.(stimArray{stimDur}){unitNumArray(unitNum)} = {};
                            end
                            
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

    save([savePath '\allVars.mat'], 'metadataTable', 'ops', 'dataFileTb', 'spikedataTable', '-v7.3');    
        

end

function PlotHistoUnitsHelper(fwireframe, allHisto, bregma, marker, colorgen)
    atlas_resolution = 0.010; % mm
    
    for unitNum = 1:height(allHisto)
        % find shank form kcoord and then find the ycoord on that
        % channel on that shank
        
      try
        ap = allHisto{unitNum}.('AP_location');
      catch
          ap = allHisto{unitNum}.('Var3');
      end
      try
          dv = allHisto{unitNum}.('DV_location');
      catch
          dv = allHisto{unitNum}.('Var4');
      end
      try
          ml = -abs(allHisto{unitNum}.('ML_location'));

      catch
          ml = -abs(allHisto{unitNum}.('Var5'));
      end

        unitEucl = [ap dv ml]/atlas_resolution;
        
        figure(fwireframe)
        hold on
        plot3(bregma(1) - unitEucl(1), bregma(3) + unitEucl(3),bregma(2) + unitEucl(2), ...
        'Marker', marker, 'color' , colorgen, 'MarkerSize', 15);           

    end
end


function PlotHistoResponsiveness(metadataTable,plotAlpha, savePath, window, minUnits)
    
    histoInfoFinal = metadataTable.HistoTable;    
    pvals = metadataTable.pvalBoth;
    pvalsIpsi = metadataTable.pvalIpsi;
    pvalsContra = metadataTable.pvalContra;

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
            
        
        
        
        uGenotypes = unique(metadataTable.genotype);

%         markers = {'x', 'o'};
        for genotype = numel(uGenotypes):-1:1 
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
            
            histoInfoGeno = histoInfoFinal(ismember(metadataTable.genotype, uGenotypes(genotype)));
            histoInfoGeno = cellfun(@(x) x.(window), histoInfoGeno, 'UniformOutput', false);

            pvalsGeno = pvals(ismember(metadataTable.genotype, uGenotypes(genotype)));
            pvalsGeno = cellfun(@(x) x.(window), pvalsGeno, 'UniformOutput', false);
           
            ipsiPvalsGeno = pvalsIpsi(ismember(metadataTable.genotype, uGenotypes(genotype)));
            ipsiPvalsGeno = cellfun(@(x) x.(window), ipsiPvalsGeno, 'UniformOutput', false);

            contraPvalsGeno = pvalsContra(ismember(metadataTable.genotype, uGenotypes(genotype)));
            contraPvalsGeno = cellfun(@(x) x.(window), contraPvalsGeno, 'UniformOutput', false);
            
            for animal = 1:height(pvalsGeno)
                for sess = 1:height(pvalsGeno{animal})
                    pvalSess = pvalsGeno{animal}{sess};
                    ipsipvalSess = ipsiPvalsGeno{animal}{sess};
                    contrapvalSess = contraPvalsGeno{animal}{sess};
                    histoInfoSess = histoInfoGeno{animal}{sess}(:,1);
                    if ~isempty(histoInfoSess{1,1}{1})
                        histoInfoSess = table2array(histoInfoSess);
                        
                        if width(pvalSess) >3
                            pvalSess = cell2mat(table2array(pvalSess(:,1:3)));
                            ipsipvalSess = cell2mat(table2array(ipsipvalSess(:,1:3)));
                            contrapvalSess = cell2mat(table2array(contrapvalSess(:,1:3)));
                        else
                            pvalSess = cell2mat(table2array(pvalSess));
                            ipsipvalSess = cell2mat(table2array(ipsipvalSess));
                            contrapvalSess = cell2mat(table2array(contrapvalSess));
                        end
                        
                        %%%%% Find the session is contra or ipsi by # of responsive units to contra >ipsi %%%%%%%%
                        % find the minimum of the pval in any stim.
                        ipsipvalSess = min(ipsipvalSess,[],2);

                        
                        contrapvalSess = min(contrapvalSess,[],2);
    
                        % calculate num contra units and num ipsiUnits
                        contraUnits = find(contrapvalSess<ops.plotAlpha & ipsipvalSess>=ops.plotAlpha);
                        contraNum = numel(contraUnits);
                        ipsiUnits = find(ipsipvalSess<ops.plotAlpha & contrapvalSess>=ops.plotAlpha);
                        ipsiNum = numel(ipsiUnits);
                        bothUnits = find(ipsipvalSess<ops.plotAlpha & contrapvalSess<ops.plotAlpha);
                        bothNum = numel(bothUnits);
                    
                    if (contraNum + ipsiNum + bothNum)< minUnits 
                        continue;
                    end
                    [~,I] = max([contraNum, ipsiNum, bothNum]);
                    sessColor = {'r', 'b', 'w'};

                    allHistoIpsi = histoInfoSess(ipsiUnits);
                    allHistoContra = histoInfoSess(contraUnits);
                    allHistoBoth = histoInfoSess(bothUnits);
                
                    PlotHistoUnitsHelper(fwireframe, allHistoIpsi, bregma,'.', 'b');
                    PlotHistoUnitsHelper(fwireframe, allHistoContra, bregma, '.', 'r');
                    PlotHistoUnitsHelper(fwireframe, allHistoBoth, bregma, '.', 'w');
                    

                    % need to plot the penetration depth for that session
                    % location for that session

                end


                    
                    
                    



                      
               end

           end
           
                

            
            [AZ,EL] = view;
            view([0,0]);
            

            saveFolder= fullfile(ops.savePath,window,'BrainviewAngles', uGenotypes{genotype});
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




            savefig(fwireframe, fullfile(ops.savePath, window,['allpvals = ' num2str(allpvals) '  genotype ' uGenotypes{genotype} ' Histoplot.fig']));
            
        end

        
        
        
        
       


      



               
    end
end

function PlotHistoCBias(metadataTable,plotAlpha, savePath, window, minUnits)
    
    histoInfoFinal = metadataTable.HistoTable;    
    pvals = metadataTable.pvalBoth;
    pvalsIpsi = metadataTable.pvalIpsi;
    pvalsContra = metadataTable.pvalContra;
    cBias = metadataTable.cbias;
    
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
            
        
        
        
        uGenotypes = unique(metadataTable.genotype);
        close all
%         markers = {'x', 'o'};
        for genotype = numel(uGenotypes):-1:1 
            
        
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
            
            histoInfoGeno = histoInfoFinal(ismember(metadataTable.genotype, uGenotypes(genotype)));
            histoInfoGeno = cellfun(@(x) x.(window), histoInfoGeno, 'UniformOutput', false);

            pvalsGeno = pvals(ismember(metadataTable.genotype, uGenotypes(genotype)));
            pvalsGeno = cellfun(@(x) x.(window), pvalsGeno, 'UniformOutput', false);

            cbiasGeno = cBias(ismember(metadataTable.genotype, uGenotypes(genotype)));
            cbiasGeno = cellfun(@(x) x.(window), cbiasGeno, 'UniformOutput', false);
           
            ipsiPvalsGeno = pvalsIpsi(ismember(metadataTable.genotype, uGenotypes(genotype)));
            ipsiPvalsGeno = cellfun(@(x) x.(window), ipsiPvalsGeno, 'UniformOutput', false);

            contraPvalsGeno = pvalsContra(ismember(metadataTable.genotype, uGenotypes(genotype)));
            contraPvalsGeno = cellfun(@(x) x.(window), contraPvalsGeno, 'UniformOutput', false);
            
            for animal = 1:height(pvalsGeno)
                for sess = 1:height(pvalsGeno{animal})
                    pvalSess = pvalsGeno{animal}{sess};
                    cbiasSess = cbiasGeno{animal}{sess};
                    ipsipvalSess = ipsiPvalsGeno{animal}{sess};
                    contrapvalSess = contraPvalsGeno{animal}{sess};
                    histoInfoSess = histoInfoGeno{animal}{sess}(:,1);
                    if ~isempty(histoInfoSess{1,1}{1})
                        histoInfoSess = table2array(histoInfoSess);
                        
                        if width(pvalSess) >3
                            pvalSess = cell2mat(table2array(pvalSess(:,1:3)));
                            ipsipvalSess = cell2mat(table2array(ipsipvalSess(:,1:3)));
                            contrapvalSess = cell2mat(table2array(contrapvalSess(:,1:3)));
                            cbiasSess = cell2mat(table2array(cbiasSess(:,2)));
                        else
                            pvalSess = cell2mat(table2array(pvalSess));
                            ipsipvalSess = cell2mat(table2array(ipsipvalSess));
                            contrapvalSess = cell2mat(table2array(contrapvalSess));
                            cbiasSess = cell2mat(table2array(cbiasSess));
                        end
                        
                        %%%%% Find the session is contra or ipsi by # of responsive units to contra >ipsi %%%%%%%%
                        % find the minimum of the pval in any stim.
                        ipsipvalSess = min(ipsipvalSess,[],2);
                        pvalSess = min(pvalSess,[],2);
                        
                        contrapvalSess = min(contrapvalSess,[],2);
    
                        % calculate num contra units and num ipsiUnits
                        contraUnits = find(pvalSess<ops.plotAlpha & cbiasSess>0);
                        contraNum = numel(contraUnits);
                        ipsiUnits = find(pvalSess<ops.plotAlpha & cbiasSess<0);
                        ipsiNum = numel(ipsiUnits);
                        bothUnits =  find(pvalSess<ops.plotAlpha & cbiasSess==0);
                        bothNum = numel(bothUnits);
                    
                        if (contraNum + ipsiNum + bothNum)< minUnits 
                            continue;
                        end
                        [~,I] = max([contraNum, ipsiNum, bothNum]);
                        sessColor = {'r', 'b', 'w'};
                        
                        allHistoIpsi = histoInfoSess(ipsiUnits);
                        allHistoContra = histoInfoSess(contraUnits);
                        allHistoBoth = histoInfoSess(bothUnits);
                    
                        PlotHistoUnitsHelper(fwireframe, allHistoIpsi, bregma,'.', 'b');
                        PlotHistoUnitsHelper(fwireframe, allHistoContra, bregma, '.', 'r');
                        PlotHistoUnitsHelper(fwireframe, allHistoBoth, bregma, '.', 'w');
                        
    
                        % need to plot the penetration depth for that session
                        % location for that session

                    end


                    
                    
                    



                      
               end

           end
           
                

            
            [AZ,EL] = view;
            view([0,0]);
            

            saveFolder= fullfile(ops.savePath,window,'BrainviewAnglesCBias', uGenotypes{genotype});
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




            savefig(fwireframe, fullfile(ops.savePath, window,['allpvals = ' num2str(allpvals) '  genotype ' uGenotypes{genotype} ' HistoplotCbias.fig']));
            
        end

        
        
        
        
       


      



               
    end
end


function GetFRData(dataFileTb, ops)


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
    bins = tWins(1):binSize:tWins(2);
    FRdataTable = cell2table(cell(numel(uniAnimalId), 1), 'RowNames', uniAnimalId, 'VariableNames', {'meanFR'});
    
    
   
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
            frAll= se.SliceTimeSeries('spikeRate', tWins, 'Fill', 'bleed');
            frAll = frAll(trialInd,:);
            frAll(1,:) = [];
            frAll = table2cell(frAll);
            frAll = cellfun(@(x) x', frAll, 'UniformOutput',false);         

               
            
            stimTypes = leftStimTypes;
            uStimTypes = unique(stimTypes);
            ufreq = unique(cellfun(@(x) x(5:6),uStimTypes, 'UniformOutput', false)); % for gettign just the unique frequencies irrespective of the cycles
            if isempty(str2num(ufreq{1}))
                ufreq = unique(cellfun(@(x) x(17:18),uStimTypes, 'UniformOutput', false)); % for gettign just the unique frequencies irrespective of the cycles
                freqStart = 17;
            else
                freqStart =5;
            end

            unitNums = size(frAll,2)-1;
           

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

                
                   
            sessInfoTable = se.userData.sessionInfo;

            if ismember('penetrationDepth', sessInfoTable.Properties.VariableNames)
%                         penetrationDepth = sessInfoTable.penetrationDepth;
                penetrationDepth = sessInfoTable.histology;
                corticalDepth = sessInfoTable.corticaldepth;
            else
                penetrationDepth = defPenetrationDepth;
                corticalDepth = 1280;
            end
                    
            
            % for all the stimDurs
            for stimDur = 1:numel(ufreq)

                
                
                try
                    unitChanDepth = se.userData.spikeInfo.quality_metrics.depth;
                catch
                    
                    chanDepth = 0:20:1260; %(in um)
                    channelInds = se.userData.spikeInfo.unit_channel_ind;
                    chanMap = se.userData.sessionInfo.channel_map.chanMap;
                    [~, chanPos] = ismember(channelInds,chanMap);
                    unitChanDepth= chanDepth(chanPos);
                    
                end
                
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
                        frAllwin = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                    end

                    leftStimTypes = behavData.leftStimType;
                    rightStimTypes = behavData.rightStimType;

                   
                    
                    trials2keepL= find(strcmp(trials{1}{1}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(freqStart:freqStart+1),ufreq{stimDur}), ...
                            leftStimTypes, 'UniformOutput',false)));
                    trials2keepR = find(strcmp(trials{1}{2}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(freqStart:freqStart+1),ufreq{stimDur}), ...
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
                    FRlims  = [tWins(1) tWins(2)];               
                        
                    binsWin  = find(bins>= FRlims (1) & bins<= FRlims (2));
                    temp = binsWin(1:end-1);
                    
                    frAllplot  = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                    FRLeft  = frAllplot (trials2keepL ,2:end);
                    FRRight  = frAllplot (trials2keepR ,2:end);
                    FRtime  = frAllplot (:,1);        
                    
                   

                    
                    if sum(ismember('Left', sessRecSite))==4
                        stims = {trials2keepL , trials2keepR };
                    else
                        stims = {trials2keepR , trials2keepL };
                    end
                   
                    win = ops.WindowNames{window};

                    try
                        for unitNum = 1: size(preMeanFRL ,2)   
                            
                            unitDepth = unitChanDepth(unitNum);

                            
                            [pvalL] = signrank(preMeanFRL (:,unitNum), postMeanFRL (:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);
                            [pvalR] = signrank(preMeanFRR (:,unitNum), postMeanFRR (:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);
                 
                            
                        
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
    
       %
       toc
      
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
    
    rowNames = FRdataTable.Properties.RowNames;
    variableNames = FRdataTable.Properties.VariableNames;
    meanFRTable= cell2table(cell(numel(rowNames), numel(variableNames)), 'RowNames', rowNames, 'VariableNames', variableNames);
    parfor animal = 1 : height(FRdataTable)
        
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

function IpsiresponsiveLatencies(ops, metadataTable, meanFRTable )
    keyboard;
    close all   
    ops.plotAlpha = 0.001;
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
                
                ipsiTemp = ipsiTemp(sigUnits,:);


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
                emptyCells = cell2mat(cellfun(@(x) isempty(x), ipsicells, 'UniformOutput', false));
                ipsicells(emptyCells) = [];

                ipsicells = cellfun(@(x) table2cell(x), ipsicells, 'UniformOutput', false);
                ipsicells = vertcat(ipsicells{:});    

                contracells = vertcat(contra{window}{geno}(:,stim));
                emptyCells = cell2mat(cellfun(@(x) isempty(x), contracells, 'UniformOutput', false));
                contracells(emptyCells) = [];
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

function MakeFigures(allVars)
    % plot allMeanFR for all the stimDur
    
    load(allVars, 'allSpikeTimes', 'maxAdc', 'ops', 'bodysidefinal','ufreq','uGenotypes', 'inputrecSites', 'adcFinal', 'plotLims', 'pvals', 'allMeanFR');
    
    
    for genotype = 1: numel(allSpikeTimes)
            
            for recSite =1:numel(allSpikeTimes{genotype})
                maxAdcgenotype = maxAdc{genotype}{recSite};
                [maxadcfig rows] = max(maxAdcgenotype(1,:));
                 if maxadcfig <0.1
                    fM = 10e4;
            %                 fM = 1;
                else
                    fM =1;
                    
                end
                
                maxadcfig = maxadcfig*fM; 
                close all
            
                % done for left as the first one and right as the second
                % spikeTimes
                color = {'b', 'r'};
            
                
                
            
                for allpvals = 0:ops.allpvals
                    spikeTimes ={};
                    sigUnits = {};
                    
                    if allpvals
                        
                       
                        sessions7 = find(bodysidefinal{genotype}{recSite}{2}==1);
            
                        sessions8 = find(bodysidefinal{genotype}{recSite}{2}==0);
                        clearvars pvalsfake
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
                        
                        % need to get the 20hz only sessions out.  
                        pvals{genotype}{recSite} = cellfun(@(x) x', pvals{genotype}{recSite}, 'UniformOutput', false); 
                        try
                            pvals2 = cell2mat(pvals{genotype}{recSite});
                        catch
                            keyboard;
                        end
                        pvalsLogic = pvals2<ops.plotAlpha;
                        pvalsLogic = pvalsLogic(:,1:3);
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
                                MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,1}{i}*1000, i*ones(numel(spikeTimes{stimDur}{unitNum,1}{i}),1) ,1, 'orientation', 'vertical', ...
                                    'linestyle', '-','color', color{1}, 'linewidth', 1);
                            end
                            totalTrials = height(spikeTimes{stimDur}{unitNum,2})+ height(spikeTimes{stimDur}{unitNum,1});
                            xLimits = get(gca,'XLim');
                            MPlot.PlotPointAsLine(0,i+1,xLimits(2), 'orientation', 'horizontal', 'linestyle', '--', ...
                                'color',[0 0 0], 'linewidth', 1);
                            % plot right trials
                            for i = 1+height(spikeTimes{stimDur}{unitNum,1}): totalTrials
                                rInd = i  -height(spikeTimes{stimDur}{unitNum,1});
                                MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,2}{rInd}*1000, (i+1)*ones(numel(spikeTimes{stimDur}{unitNum,2}{rInd}),1) ,1, 'orientation', 'vertical', ...
                                    'linestyle', '-','color', color{2}, 'linewidth', 1);
                            end                         
                        
                            adcChan = adcFinal{genotype}{recSite}{stimDur}(2,:);
                            
                            if max(adcChan) <0.1
                                fM = 10e4;
                        %                 fM = 1;
                            else
                                fM =10;
                            end
                                

                            yLimits = get(gca,'YLim');                    
                            plot(adcFinal{genotype}{recSite}{stimDur}(1,:)*1000, (adcFinal{genotype}{recSite}{stimDur}(2,:)*fM) +  totalTrials+5+1, ...
                                'k', 'lineWidth', 1);                            
                            yLimits = get(gca,'YLim');
                            MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--', ...
                                'color',[0.5 0.5 0.5], 'linewidth', 1);
        %                     xlabel('epoch time (s)');
        %                     ylabel('Trials');  
                            yLimits = get(gca,'YLim');
                            ylim([0, yLimits(2)])
                            xlim(plotLims{stimDur}*1000); 
                            CbiasVal = round(spikeTimes{stimDur}{unitNum,5} * 10) / 10;
                            title({[num2str(spikeTimes{stimDur}{unitNum,3}) ' \mum']},{['Cbias = '  num2str(CbiasVal)]});                    
                            box off  
                            outerpos = get(h,'OuterPosition');
                            ti = get(h,'TightInset');
                            left = outerpos(1) + ti(1);
                            bottom = outerpos(2) + ti(2);
                            ax_width = outerpos(3) - ti(1) - ti(3);
                            ax_height = outerpos(4) - ti(2) - ti(4)-0.025;
                            set(h,'Position',[left bottom ax_width ax_height], 'fontsize', 10);                            
                            hold(h, 'off');
                        
                            % plot FR subplots here

                           figure(gg{stimDur});  
                            %sort each meanFR cell by depth                           
                            hh = subplot(plotRows,15,unitNum, 'Parent', gg{stimDur});                                  
                            hold(hh, 'on');                               
                            plot(meanFR{stimDur}{unitNum,1}*1000, meanFR{stimDur}{unitNum, 2}, ...
                                color{1}, 'LineWidth', 1);
                            plot(meanFR{stimDur}{unitNum,1}*1000, meanFR{stimDur}{unitNum, 3}, ...
                                color{2}, 'LineWidth', 1);                                
                            if ~isempty(meanFR{stimDur}{unitNum, 2})                                
                                MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}*1000, meanFR{stimDur}{unitNum, 2}, meanFR{stimDur}{unitNum, 4}(2,:), ...
                                    meanFR{stimDur}{unitNum, 4}(1,:), 'color',color{1}, 'Alpha', 0.3, 'IsRelative', false);                                        
                            end            
                            if ~isempty(meanFR{stimDur}{unitNum, 4})                                
                                MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}*1000, meanFR{stimDur}{unitNum, 3}, meanFR{stimDur}{unitNum, 5}(2,:), ...
                                    meanFR{stimDur}{unitNum, 5}(1,:), 'color',color{2}, 'Alpha', 0.3, 'IsRelative', false);                                                        
                            end                        
                            yLimits = get(gca,'YLim');        

                            adcChan = adcFinal{genotype}{recSite}{stimDur}(2,:);
                            
                            if max(adcChan) <0.1
                                fM = 10e4;
                        %                 fM = 1;
                            else
                                fM =10;
                                
                            end

                            plot(adcFinal{genotype}{recSite}{stimDur}(1,:)*1000, (adcFinal{genotype}{recSite}{stimDur}(2,:)*fM) +  yLimits(2), ...
                                'k', 'lineWidth', 1);
                            yLimits = get(gca,'YLim');
                            MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
            %                 xlabel('epoch time (s)');
            %                 ylabel('FR');  
                            yLimits = get(gca,'YLim');
                            ylim([0, yLimits(2)]);
                            xlim(plotLims{stimDur}*1000);                  
                            try
                                [unitLayer, layerIndex] = assignLayer(meanFR{stimDur}{unitNum,6});
                            catch
                                unitLayer = [num2str(meanFR{stimDur}{unitNum,6}) ' um'];
                                
                            end
                            title(unitLayer,{[' Cbias = '  num2str(CbiasVal)]});                    
                            box off  
                            outerpos = get(hh,'OuterPosition');
                            ti = get(hh,'TightInset');
                            left = outerpos(1) + ti(1);
                            bottom = outerpos(2) + ti(2);
                            ax_width = outerpos(3) - ti(1) - ti(3);
                            ax_height = outerpos(4) - ti(2) - ti(4)-0.025;
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

function MakeIndUnitFigures(allVars, figureRoot)
    % plot allMeanFR for all the stimDur
    
    load(allVars, 'allSpikeTimes', 'maxAdc', 'ops', 'bodysidefinal','ufreq','uGenotypes', 'inputrecSites', 'adcFinal', 'plotLims', 'pvals', 'allMeanFR');
    genotypeColors{2} = {'b', 'r'};
    genotypeColors{1} = {[6 6 192]/255; [212 0 0]/255};

    
    for genotype = 1: numel(allSpikeTimes)
            
            for recSite =1:numel(allSpikeTimes{genotype})
                maxAdcgenotype = maxAdc{genotype}{recSite};
                [maxadcfig rows] = max(maxAdcgenotype(1,:));
                 if maxadcfig <0.1
                    fM = 10e4;
            %                 fM = 1;
                else
                    fM =1;
                    
                end
                
                maxadcfig = maxadcfig*fM; 
                close all
            
                % done for left as the first one and right as the second
                % spikeTimes
                
                color = genotypeColors{genotype};
                
                
            
                for allpvals = 0:ops.allpvals-1
                    spikeTimes ={};
                    sigUnits = {};
                    
                    if allpvals
                        
                       
                        sessions7 = find(bodysidefinal{genotype}{recSite}{2}==1);
            
                        sessions8 = find(bodysidefinal{genotype}{recSite}{2}==0);
                        clearvars pvalsfake
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
                        
                        % need to get the 20hz only sessions out.  
                        pvals{genotype}{recSite} = cellfun(@(x) x', pvals{genotype}{recSite}, 'UniformOutput', false); 
                        try
                            pvals2 = cell2mat(pvals{genotype}{recSite});
                        catch
                            keyboard;
                        end
                        pvalsLogic = pvals2<ops.plotAlpha;
                        pvalsLogic = pvalsLogic(:,1:3);
                        pvalSum = sum(pvalsLogic,2);
                        sigUnits = pvalSum>0;
                        
                    else
                        sessions7 =[];
                    end
                    
                    for stimDur = 1:min(numel(ufreq), 3)
                      
                       
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
                        
%                         for unitNum =1:1
                        for unitNum =1:height(spikeTimes{stimDur})
                            close all
                            g{unitNum} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz spikeRaster'],'NumberTitle','off'); clf;
                            set(g{unitNum}, 'Units', 'inch', 'Position', [1 1 1 2.5]);
                            g{unitNum}.Visible = 'Off';
                            gg{unitNum} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' ufreq{stimDur} ' hz FR'],'NumberTitle','off'); clf;
                            set(gg{unitNum}, 'Units', 'inch', 'Position', [1 1 1 2.5]);
                            gg{unitNum}.Visible = 'Off';
                            figure(g{unitNum});         
                            %sort each meanFR cell by depth                   
                            h = subplot(1,1,1, 'Parent', g{unitNum});                                  
                            hold(h, 'on');
                            % plot left trials
                            for i = 1: height(spikeTimes{stimDur}{unitNum,1})
                                MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,1}{i}*1000, i*ones(numel(spikeTimes{stimDur}{unitNum,1}{i}),1) ,1, 'orientation', 'vertical', ...
                                    'linestyle', '-','color', color{1}, 'linewidth', 1.5);
                            end
                            totalTrials = height(spikeTimes{stimDur}{unitNum,2})+ height(spikeTimes{stimDur}{unitNum,1});
                            xLimits = get(gca,'XLim');
                            MPlot.PlotPointAsLine(0,i+1,xLimits(2), 'orientation', 'horizontal', 'linestyle', '--', ...
                                'color',[0 0 0], 'linewidth', 1);
                            % plot right trials
                            for i = 1+height(spikeTimes{stimDur}{unitNum,1}): totalTrials
                                rInd = i  -height(spikeTimes{stimDur}{unitNum,1});
                                MPlot.PlotPointAsLine(spikeTimes{stimDur}{unitNum,2}{rInd}*1000, (i+1)*ones(numel(spikeTimes{stimDur}{unitNum,2}{rInd}),1) ,1, 'orientation', 'vertical', ...
                                    'linestyle', '-','color', color{2}, 'linewidth', 1.5);
                            end                         
                        
                            adcChan = adcFinal{genotype}{recSite}{stimDur}(2,:);
                            adcTime = adcFinal{genotype}{recSite}{stimDur}(1,:);
                            wrongADC = find(adcTime==0);
                            adcTime(wrongADC) = [];
                            adcChan(wrongADC) =[];


                            if max(adcChan) <0.1
                                fM = 10e4;
                        %                 fM = 1;
                            else
                                fM =10;
                            end
                                

                            yLimits = get(gca,'YLim');     
                            
                            plot(adcTime*1000, (adcChan*fM) +  totalTrials+5+1, ...
                                'k', 'lineWidth', 1);                            
                            yLimits = get(gca,'YLim');
                            MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--', ...
                                'color',[0.5 0.5 0.5], 'linewidth', 1);
        %                     xlabel('epoch time (s)');
        %                     ylabel('Trials');  
                            yLimits = get(gca,'YLim');
                            ylim([0, yLimits(2)])
                            xlim(plotLims{stimDur}*1000); 
                            CbiasVal = round(spikeTimes{stimDur}{unitNum,5} * 10) / 10;
%                             title({[num2str(spikeTimes{stimDur}{unitNum,3}) ' \mum']},{['Cbias = '  num2str(CbiasVal)]});                    
                            box off  
                            
                            set(h,'fontsize', 12);                            
                            hold(h, 'off');
                        
                            % plot FR subplots here

                           figure(gg{unitNum});  
                            %sort each meanFR cell by depth                           
                            hh = subplot(1,1,1, 'Parent', gg{unitNum});                                  
                            hold(hh, 'on');    
                            
                            plot(meanFR{stimDur}{unitNum,1}*1000, meanFR{stimDur}{unitNum, 2}, ...
                                'color', color{1}, 'LineWidth', 1);
                            plot(meanFR{stimDur}{unitNum,1}*1000, meanFR{stimDur}{unitNum, 3}, ...
                                'color',color{2}, 'LineWidth', 1);                                
                            if ~isempty(meanFR{stimDur}{unitNum, 2})                                
                                MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}*1000, meanFR{stimDur}{unitNum, 2}, meanFR{stimDur}{unitNum, 4}(2,:), ...
                                    meanFR{stimDur}{unitNum, 4}(1,:), 'color',color{1}, 'Alpha', 0.3, 'IsRelative', false);                                        
                            end            
                            if ~isempty(meanFR{stimDur}{unitNum, 4})                                
                                MPlot.ErrorShade(meanFR{stimDur}{unitNum,1}*1000, meanFR{stimDur}{unitNum, 3}, meanFR{stimDur}{unitNum, 5}(2,:), ...
                                    meanFR{stimDur}{unitNum, 5}(1,:), 'color',color{2}, 'Alpha', 0.3, 'IsRelative', false);                                                        
                            end                        
                            yLimits = get(gca,'YLim');        

                            
                          
                           plot(adcTime*1000, (adcChan*fM) +  yLimits(2), ...
                                'k', 'lineWidth', 1);   
                            yLimits = get(gca,'YLim');
                            MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
            %                 xlabel('epoch time (s)');
            %                 ylabel('FR');  
                            yLimits = get(gca,'YLim');
                            ylim([0, yLimits(2)]);
                            xlim(plotLims{stimDur}*1000);                             

%                             title({[num2str(meanFR{stimDur}{unitNum,6}) ' \mum']},{['Cbias = '  num2str(CbiasVal)]});                    
                            box off  
                            
                            set(hh, 'fontsize', 12);     
                            hold(hh, 'off');

                            savePath2 = fullfile(figureRoot, [ ' allpvals =  ' num2str(allpvals)], [uGenotypes{genotype} ' ' ufreq{stimDur}], 'Rasters');
                            savePath3 = fullfile(figureRoot, [' allpvals =  ' num2str(allpvals)], [uGenotypes{genotype} ' ' ufreq{stimDur}], 'FRs');

                            if ~isfolder(savePath2)
                                mkdir(savePath2);
                            end

                            if ~isfolder(savePath3)
                                mkdir(savePath3);
                            end
                
                           
                            
                            savefig(g{unitNum}, fullfile(savePath2,  ['UnitNum- ' num2str(unitNum) ' Depth- ' num2str(meanFR{stimDur}{unitNum,6}) ' um.fig']));
                            saveas(g{unitNum},fullfile(savePath2,  ['UnitNum- ' num2str(unitNum) ' Depth- ' num2str(meanFR{stimDur}{unitNum,6}) ' um.png']));
                            savefig(gg{unitNum},fullfile(savePath3,  ['UnitNum- ' num2str(unitNum) ' Depth- ' num2str(meanFR{stimDur}{unitNum,6}) ' um.fig']));
                            saveas(gg{unitNum},fullfile(savePath3,  ['UnitNum- ' num2str(unitNum) ' Depth- ' num2str(meanFR{stimDur}{unitNum,6}) ' um.png']));
        
                        end                        
            
                      
                    end
            
                end
        
        end
    end
end

function MakeCbiasFigures(ops, binWidth, figureRoot, metadataTable, minUnits)
    close all   
    
  % Take responsive units from 20hz and 150ms window. 
  % For those units calculate cbias in the window of their first cycle for
  % each 
    
    
   
    cBiasTable = metadataTable.cbias;
    pvalTable = metadataTable.pvalBoth;
    animalIds = unique(metadataTable.Properties.RowNames);
    genotypes = metadataTable.genotype;
    uGenotype = unique(genotypes);
    windows = ops.WindowNames;
    stimNames ={'10hz', '20hz', '40hz'};


    cBiasWin = [5 3 1];
    win = 6;

    savePath = fullfile(ops.savePath, ' CbiasFinal20hz150ms');

    if ~isfolder(savePath)
        mkdir(savePath);
    end

    cbiasFinal = cell(2,3);
    sessCbiasFinal = cell(2,3);
    for geno = 1:numel(uGenotype)
        animals= find(ismember(genotypes, uGenotype(geno)));
        CbiasGeno = cBiasTable(animals);
        pvalGeno = pvalTable(animals);
        
        for ani = 1: numel(CbiasGeno) 
            aniGeno = CbiasGeno{ani};
            anipval = pvalGeno{ani};
            for sessNum = 1: height(aniGeno)
                pvalsess = cell2mat(table2cell(anipval.(ops.WindowNames{win}){sessNum}));

                
                
                 cbiasSess = [];
                if width(pvalsess) >3

                    pvalsess = pvalsess(:,2);
                    pstimDur = 1:3;
                    
                    for stim = 1:numel(pstimDur)
                       stimWindowCbiases = cell2mat(table2cell(aniGeno.(ops.WindowNames{cBiasWin(pstimDur(stim))}){sessNum}));
                        cbiasSess(:,stim) = stimWindowCbiases(:,stim);
                    end
                    
                else

                    pstimDur =2;

                    for stim = 1:numel(pstimDur)
                        stimWindowCbiases = cell2mat(table2cell(aniGeno.(ops.WindowNames{cBiasWin(pstimDur(stim))}){sessNum}));
                        cbiasSess(:,stim) = stimWindowCbiases(:,stim);
                    end

                end
                sumlogics = sum(pvalsess < ops.plotAlpha,2);
                sigUnits = find(sumlogics>0);
                cbiasSess = cbiasSess(sigUnits,:);
                if ~isempty(cbiasSess)
                   for stim = 1:width(cbiasSess)
                        indx = numel(cbiasFinal{geno,pstimDur(stim)});
                        cbiasFinal{geno,pstimDur(stim)}(indx+1:indx+height(cbiasSess)) = cbiasSess(:,stim);
                        if numel(find(cbiasSess(:,stim)>0))+  numel(find(cbiasSess(:,stim)<=0)) > minUnits
                            sessCbiasFinal{geno, pstimDur(stim)}(end+1,1:2) = [numel(find(cbiasSess(:,stim)>0)),  numel(find(cbiasSess(:,stim)<=0))];
                        end
                        
                   end
                        
            
                end
                    
            end

        end
    end
    


    % Plot using these cbiasFinal and sessbiasfinals using figure 3
    % plotting scheme
    bins = -1:binWidth:1;
    colorStock = {[0 0 0]; [0.6 0.6 0.6]};
    close all
    maxunits =0;
    
    for stim = 1:width(cbiasFinal)
        g(4*stim-3) = figure(4*stim-3); clf;
        set( g(4*stim-3), 'Units', 'inch', 'Position', [1 1 3.5 3.5])
        g(4*stim-2) = figure(4*stim-2); clf;
        set( g(4*stim-2), 'Units', 'inch', 'Position', [1 1 3.5 3.5])
        g(4*stim-1) = figure(4*stim-1); clf;
        set( g(4*stim-1), 'Units', 'inch', 'Position', [1 1 3.5 5])
        g(4*stim) = figure(4*stim); clf;
        set( g(4*stim), 'Units', 'inch', 'Position', [1 1 3.5 5])
                    
        
     

        for geno= height(cbiasFinal):-1:1
            genoNum = height(cbiasFinal)-geno;
            

            percentContra = sessCbiasFinal{geno,stim}(:,1)./(sessCbiasFinal{geno,stim}(:,2)+sessCbiasFinal{geno,stim}(:,1))*100;
            figure(4*stim-3);           
            hold on
            subplot(2,1,genoNum+1)
            histogram(percentContra,0:10:100,   'facecolor', colorStock{geno});
            title(uGenotype{geno})
            ylabel('Number of columns')
            if geno ==1
                xlabel('Percent of Contra Units')
            end
            hold off
            

            hold off
            
            figure(4*stim-2);           
            hold on
            s(geno) = swarmchart(sessCbiasFinal{geno,stim}(:,1)+0.3-0.2*geno, sessCbiasFinal{geno,stim}(:,2)+ 0.3-0.2*geno...
                ,20,'marker', 'x', 'markeredgecolor', colorStock{geno}, 'YJitterWidth', 0.5, 'LineWidth',1.5);
          

            figure(4*stim-1);
            hh2 = subplot(2,1,genoNum+1);       
            h2 = histogram(cbiasFinal{geno,stim}, bins, 'facecolor', colorStock{geno}); 
            set(hh2,  'fontsize', 14);
            hh2.LineWidth = 2;
            xticks(-1:0.25:1)
            title(uGenotype{geno})
            xlabel('Cbias');
            ylabel('#of units');

            figure(4*stim);
            hh1 = subplot(2,1,genoNum+1);
            h1 = histogram(cbiasFinal{geno,stim}, bins, 'facecolor', colorStock{geno}, 'Normalization','probability');                       
            title(uGenotype{geno})
            xticks(-1:0.25:1)
            set(hh1,  'fontsize', 14);
            hh1.LineWidth = 2;
            xlabel('Cbias');
            ylabel('probability');

            if max(sessCbiasFinal{geno,stim},[],"all")> maxunits
                maxunits = max(sessCbiasFinal{geno,stim},[],"all");
            end
        end
        figure(4*stim);
        sgtitle([ stimNames{stim}]);

        figure(4*stim-3);
        sgtitle([ stimNames{stim}]);

        figure(4*stim-1);
        sgtitle([ stimNames{stim}]);

        figure(4*stim-2);
%             maxunits = min(8, maxunits);
        hold on
        
        plot(-1:maxunits+1,-1:maxunits+1, 'k-.')
        legend(s, {'KO','WT'}, 'Fontsize', 14);
        xlabel('Contra units in a session', 'Fontsize', 14);
        ylabel('Ipsi units in a session', 'Fontsize', 14);
%             xticks(0:2:8);
%             xticklabels([])
%             yticks(0:2:8);
%             yticklabels([])
        xlim([-1,min(maxunits+1,10)])
        ylim([-1,min(maxunits+1,10)])
        title(stimNames{stim});
        hold off

        savefig(figure(4*stim-3), fullfile(savePath, ['Stim ' stimNames{stim} 'Histogram sessPlot contraPercent.fig']));
        saveas(figure(4*stim-3), fullfile(savePath, ['Stim ' stimNames{stim} 'Histogram sessPlot contraPercent.png']));
        savefig(figure(4*stim-2), fullfile(savePath, ['Stim ' stimNames{stim} 'SessPlot.fig']));
        saveas(figure(4*stim-2), fullfile(savePath, ['Stim ' stimNames{stim} 'SessPlot.png']));
        savefig(figure(4*stim-1), fullfile(savePath, ['Stim ' stimNames{stim} 'Histogram units.fig']));
        saveas(figure(4*stim-1), fullfile(savePath, ['Stim ' stimNames{stim} 'Histogram units.png']));
        savefig(figure(4*stim), fullfile(savePath, ['Stim ' stimNames{stim} 'Histogram probability.fig']));
        saveas(figure(4*stim), fullfile(savePath, ['Stim ' stimNames{stim} 'Histogram probability.png']));


    end




    



        
end

function MakeCbiasFiguresFinal(ops, binWidth, figureRoot, metadataTable, minUnits)
    close all   
    
  % Take responsive units from 20hz and 150ms window. 
  % For those units calculate cbias in the window of their first cycle for
  % each 
    
    
   
    cBiasTable = metadataTable.cbias;
    pvalTable = metadataTable.pvalBoth;
    animalIds = unique(metadataTable.Properties.RowNames);
    genotypes = metadataTable.genotype;
    uGenotype = unique(genotypes);
    windows = ops.WindowNames;
    stimNames ={'10hz', '20hz', '40hz'};


    cBiasWin = [5 3 1];
    win = 6;

    savePath = fullfile(ops.savePath, ' CbiasFinal20hz150ms');

    if ~isfolder(savePath)
        mkdir(savePath);
    end

    cbiasFinal = cell(2,3);
    sessCbiasFinal = cell(2,3);
    for geno = 1:numel(uGenotype)
        animals= find(ismember(genotypes, uGenotype(geno)));
        CbiasGeno = cBiasTable(animals);
        pvalGeno = pvalTable(animals);
        
        for ani = 1: numel(CbiasGeno) 
            aniGeno = CbiasGeno{ani};
            anipval = pvalGeno{ani};
            for sessNum = 1: height(aniGeno)
                pvalsess = cell2mat(table2cell(anipval.(ops.WindowNames{win}){sessNum}));

                
                
                 cbiasSess = [];
                if width(pvalsess) >3

                    pvalsess = pvalsess(:,2);
                    pstimDur = 1:3;
                    
                    for stim = 1:numel(pstimDur)
                       stimWindowCbiases = cell2mat(table2cell(aniGeno.(ops.WindowNames{cBiasWin(pstimDur(stim))}){sessNum}));
                        cbiasSess(:,stim) = stimWindowCbiases(:,stim);
                    end
                    
                else

                    pstimDur =2;

                    for stim = 1:numel(pstimDur)
                        stimWindowCbiases = cell2mat(table2cell(aniGeno.(ops.WindowNames{cBiasWin(pstimDur(stim))}){sessNum}));
                        cbiasSess(:,stim) = stimWindowCbiases(:,stim);
                    end

                end
                sumlogics = sum(pvalsess < ops.plotAlpha,2);
                sigUnits = find(sumlogics>0);
                cbiasSess = cbiasSess(sigUnits,:);
                if ~isempty(cbiasSess)
                   for stim = 1:width(cbiasSess)
                        indx = numel(cbiasFinal{geno,pstimDur(stim)});
                        cbiasFinal{geno,pstimDur(stim)}(indx+1:indx+height(cbiasSess)) = cbiasSess(:,stim);
                        if numel(find(cbiasSess(:,stim)>0))+  numel(find(cbiasSess(:,stim)<=0)) > minUnits
                            sessCbiasFinal{geno, pstimDur(stim)}(end+1,1:2) = [numel(find(cbiasSess(:,stim)>0)),  numel(find(cbiasSess(:,stim)<0))];
                        end
                        
                   end
                        
            
                end
                    
            end

        end
    end
    

    
    % Plot using these cbiasFinal and sessbiasfinals using figure 3
    % plotting scheme
    bins = -1:binWidth:1;
    colorStock = {[0 0 0]; [0.6 0.6 0.6]};
    close all
    maxunits =0;
    % plot laterality index plots
    g(1) = figure('Units', 'inches', 'Position', [1, 1, 4, 2]); clf; % plot laterality index dist

    g(2) = figure('Units', 'inches', 'Position', [1, 1, 3.25, 2]); clf; % plot percent contra units
    for stim = 1:width(cbiasFinal)            

        for geno= height(cbiasFinal):-1:1
            genoNum = height(cbiasFinal)-geno;
            
            percentContra = sessCbiasFinal{geno,stim}(:,1)./(sessCbiasFinal{geno,stim}(:,2)+sessCbiasFinal{geno,stim}(:,1))*100;
            figure(g(2));           
            hold on
            subplot(2,3,genoNum*3+stim)
            
            histogram(percentContra,0:10:100,   'facecolor', colorStock{geno});
%             title(uGenotype{geno})
            ylim([0 10])
            set(gca,  'fontsize', 6, 'LineWidth', 1, 'FontName', 'Arial', 'XTickLabelRotation', 0, 'TickDir', 'out');
            if geno ==1 && stim==2
                xlabel('Percent of Contra Units', 'FontSize', 8, 'FontName', 'Arial')
            end
            hold off
            

          

            figure(g(1));           
            hold on
            subplot(2,3,genoNum*3+stim)       
            h2 = histogram(cbiasFinal{geno,stim}, bins, 'facecolor', colorStock{geno}, 'Normalization','probability'); 
            set(gca,  'fontsize', 6, 'LineWidth', 1, 'FontName', 'Arial', 'XTickLabelRotation', 0, 'TickDir', 'out');
            ylim([0 0.6])
            xticks(-1:0.25:1)
            xticklabels({'-1', '', '-0.5', '', '0', '', '0.5', '', '1'})
            
%             title(uGenotype{geno})
            if strcmp(uGenotype{geno}, 'KO')
                xlabel('Laterality index', 'FontSize', 8, 'FontName', 'Arial');
            end
%             ylabel('#of units');
            hold off

            if max(sessCbiasFinal{geno,stim},[],"all")> maxunits
                maxunits = max(sessCbiasFinal{geno,stim},[],"all");
            end
        end
    

      


    end

    savefig(g(2), fullfile(savePath, ['Histogram sessPlot contraPercent.fig']));
    exportgraphics(g(2), fullfile(savePath, ['Histogram sessPlot contraPercent.tiff']), 'Resolution', 1200);        
    savefig(g(1), fullfile(savePath, ['Histogram probability.fig']));
    exportgraphics(g(1), fullfile(savePath, ['Histogram probability.tiff']), 'Resolution', 1200);


    



        
end


function CBiasDepthHisto(ops, metadataTable)
    
    close all   
     % L1, 128 ± 1 μm; L2, 269 ± 2 μm; L3, 418 ± 3 μm; L4, 588 ± 3 μm; L5A, 708 ± 4 μm; L5B, 890 ± 5 μm; L6, 1154 ± 7 μm.
    % just signify according to allpvals
    depthTable = metadataTable.UnitDepth;
    cbiasTable = metadataTable.cbias;
    pvalTable = metadataTable.pvalBoth;
    animalIds = unique(metadataTable.Properties.RowNames);
    genotypes = metadataTable.genotype;
    uGenotype = unique(genotypes);
    windows = ops.WindowNames;
    stimNames ={'10hz', '20hz', '40hz'};
    
    for win = 1: numel(ops.windows)

        savePath = fullfile(ops.savePath, ops.WindowNames{win});

        if ~isfolder(savePath)
            mkdir(savePath);
        end

        cbiasFinal = cell(2,3);
        depthFinal = cell(2,3);
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

                        pvalsess = pvalsess(:,1:3);
                        pstimDur = 1:3;
                        cbiasSess = cbiasSess(:,1:3);
                    else
                        pstimDur =2;
                    end
                    sumlogics = sum(pvalsess < ops.plotAlpha,2);
                    sigUnits = find(sumlogics>0);
                    cbiasSess = cell2mat(table2cell(cbiasSess(sigUnits,:)));
                    depthSess = cell2mat(table2cell(depthSess(sigUnits,:)));
                    if ~isempty(cbiasSess)
                       for stim = 1:width(cbiasSess)
                            indx = numel(cbiasFinal{geno,pstimDur(stim)});
                            cbiasFinal{geno,pstimDur(stim)}(indx+1:indx+height(cbiasSess)) = cbiasSess(:,stim);
                            depthFinal{geno,pstimDur(stim)}(indx+1:indx+height(depthSess)) = depthSess(:,stim);
                            
                       end
                            
                
                    end
                        
                end

            end
        end
        

    %  L1, 128 ± 1 μm; L2, 269 ± 2 μm; L3, 418 ± 3 μm; L4, 588 ± 3 μm; L5A, 708 ± 4 μm; L5B, 890 ± 5 μm; L6, 1154 ± 7 μm.

        
       for stim =1:numel(stimNames)
            g = figure(stim); clf;
            g.WindowState = 'Maximized';
            hold on
            for genotype =1:height(depthFinal)
                ax = subplot(1, height(depthFinal),genotype);
               
                data = [cbiasFinal{genotype,stim}', depthFinal{genotype,stim}'];
    
%                 lowerBounds = [(max(data(:,2))-min(data(:,2)))/2,max(data(:,2))];
%                 upperBounds = [min(data(:,2)),(max(data(:,2))-min(data(:,2)))/2];
                lowerBounds = [418/1154,588/1154,max(data(:,2))];
                upperBounds = [min(data(:,2)),418/1154,588/1154];

                binEdgesY = upperBounds + (lowerBounds-upperBounds)/2
%                 binEdgesX = -1:binWidth:1;
                lowerBounds = [-1,-0.33,0.33];
                upperBounds =[-0.33,0.33,1];
                binEdgesX = upperBounds + (lowerBounds-upperBounds)/2
                
                hist3(data, ...
                    {binEdgesX,binEdgesY}, 'CdataMode','auto');
                

                 
             
              
                set(gca, 'FontSize', 24);
               

                title([uGenotype{genotype} ' ' stimNames{stim}], 'FontSize', 36);
                yticks(binEdgesY)
                yticklabels({'Superficial', 'L4', 'Deep'});
                ylim([min(data(:,2)),max(data(:,2))]);
                zlim([0,80]);
                zticks([0:10:80]);
                if genotype ==1
                  
                    
                    ylabel('Cortical layers','VerticalAlignment','baseline', 'FontSize', 36);
                    zlabel('Number of Units', 'FontSize', 36);
                end
                xlabel('Contra Bias','VerticalAlignment','baseline',  'FontSize', 36);
          
                h = colorbar;               
                tt = get(h, 'Position');
                set(h, 'Position', [tt(1)+0.05, tt(2)+0.1, tt(3), tt(4)-0.2]); % Adjust the position and size as needed
             


                
            end
            
            hold off
            savefig(g,fullfile(savePath,  [stimNames{stim} ' depth cbias histogram.fig']));
            saveas(g,fullfile(savePath,  [stimNames{stim} ' depth cbias histogram.png']));
       end


    end                
                   
        
end

function MakeLFPs(allVars, normalized, multi)
    % plot allMeanFR for all the stimDur
    
    load(allVars, 'LFPFinal', 'maxAdc', 'ops', 'bodysidefinal','ufreq','uGenotypes', 'inputrecSites', 'adcFinal', 'plotLims', 'sessInfoFinal', 'Cbiastable');
    load('G:\VC03_RoboKO\EphysPassiveStimSEs\chanMap.mat', 'chanMap');
    

    Cbiastable2 = {};
    sessCBiasNum = {};
    allpvals = 1;
    savePath = fullfile(ops.savePath, ['allPvals = ' num2str(allpvals)]);

   

    for genotype = numel(Cbiastable):-1:1 
        
        for recSite =1:numel(Cbiastable{genotype})
            for sessNum =1:numel(Cbiastable{genotype}{recSite})
                if isempty(Cbiastable{genotype}{recSite}{sessNum})
                    continue;
                end
                sigUnits = {};
                try
                    cbiasSess = cellfun(@(x) cell2mat(x), Cbiastable{genotype}{recSite}{sessNum}, 'UniformOutput',false);
                catch
                    keyboard;
                end
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
                        contraU = numel(find(Cbiastable2{stimDur}{genotype}{recSite}{sessNum}(:,1)>0));
                        ipsiU = numel(find(Cbiastable2{stimDur}{genotype}{recSite}{sessNum}(:,1)<0));
                        zeroU = numel(find(Cbiastable2{stimDur}{genotype}{recSite}{sessNum}(:,1)==0));
                        if contraU > (ipsiU+ zeroU)
                            sessType{genotype}{recSite}{sessNum} = 'Contra';
                        elseif ipsiU > (contraU + zeroU)
                            sessType{genotype}{recSite}{sessNum} = 'Ipsi';
                        else
                            sessType{genotype}{recSite}{sessNum} = 'Both';
                        end
                    else
                        sessType{genotype}{recSite}{sessNum} = 'NA';
                    end

                end


            end
        end
    end

    

    for genotype = 1:numel(LFPFinal)

        for recSite = 1: numel(LFPFinal{genotype})
            contraSess = find(cell2mat(cellfun(@(x) strcmp(x,'Contra'), sessType{genotype}{recSite}, 'UniformOutput', false)));
            newTicks = 1280:-20:0;
            newTickLabels = cellstr(num2str(newTicks'));
            for sessNum = contraSess
                %plot contra sess such that depending on the side of
                %recordingm plot the contra stim on teh left column and
                %ipsi stim on the right column
                % Note: here LFPfinal are already as ipsi and contra. first
                % column is time, 2nd is ipsi and 3rd is contra
                
                LFPSess = LFPFinal{genotype}{recSite}{sessNum};
                
                sessInfo = sessInfoFinal{genotype}{recSite}{sessNum};
                if ~isempty(LFPSess)
                    if height(LFPSess) <4
                        stimDurs = {'20'};
                    else
                        stimDurs = {'10','20','40','80'};
                    end
                    close all;
                    windowSize ={};
                    plotLims ={};
                    
                   parfor stimDur = 1:numel(stimDurs)
                        windowSize{stimDur} = max(findDurationLFP(stimDurs{stimDur})/2, 0.025); %in s                
                        plotLims{stimDur} = [-windowSize{stimDur}/2, windowSize{stimDur}];
                        g{stimDur} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' stimDurs{stimDur} 'hz stim LFP ' ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1})],'NumberTitle','off'); clf;
                        g{stimDur}.WindowState = 'Maximized';
                        ind = (1:size(LFPSess{stimDur,2},1))*multi;
                        subplot(1,2,1, 'Parent', g{stimDur})
                        

                        
                        MPlot.PlotTraceLadder(LFPSess{stimDur,1}, LFPSess{stimDur,2}(chanMap), ind, 'Color', 'k');
                        xlim(plotLims{stimDur});
                        ylim([-10 70]*multi);                                              
                        set(gca, 'YTick', ind, 'YTickLabel', newTickLabels);
                        title('ipsi stim')
                        subplot(1,2,2, 'Parent', g{stimDur})
                        
                        if numel(LFPSess{stimDur,1}) ~= numel(LFPSess{stimDur,3}{1})
                            lastInds = min(numel(LFPSess{stimDur,1}), numel(LFPSess{stimDur,3}{1}));                            
                            tempContra = cellfun(@(x) x(1:lastInds), LFPSess{stimDur,3} , 'UniformOutput', false);                            
                            MPlot.PlotTraceLadder(LFPSess{stimDur,1}(1:lastInds), tempContra(chanMap), ind, 'Color', 'k');    
                        else
                            MPlot.PlotTraceLadder(LFPSess{stimDur,1}, LFPSess{stimDur,3}(chanMap), ind, 'Color', 'k');                            
                        end                    
                        xlim(plotLims{stimDur});
                        ylim([-10 70]*multi);
                        set(gca, 'YTick', ind, 'YTickLabel', newTickLabels);
                        title('contra stim')
                        set(g{stimDur}, 'Position', [3044,42,233,1074]);
                        sgtitle(['Contra sess ' stimDurs{stimDur} ' hz'])
                        if ~isfolder([ops.savePath normalized '\LFPs'])
                            mkdir([ops.savePath normalized '\LFPs']);
                        end
                        saveas(g{stimDur}, fullfile([ops.savePath normalized], 'LFPs', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' '  ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1}) ' ' stimDurs{stimDur} 'hz stim LFP_contrasess.fig']));
                        saveas(g{stimDur}, fullfile([ops.savePath normalized], 'LFPs', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' '  ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1}) ' ' stimDurs{stimDur} 'hz stim LFP_contrasess.png']));

                    end

                end


            end 

            ipsiSess = find(cell2mat(cellfun(@(x) strcmp(x,'Ipsi'), sessType{genotype}{recSite}, 'UniformOutput', false)));
            for sessNum = ipsiSess
                %plot contra sess such that depending on the side of
                %recordingm plot the contra stim on teh left column and
                %ipsi stim on the right column
                % Note: here LFPfinal are already as ipsi and contra. first
                % column is time, 2nd is ipsi and 3rd is contra
                
                LFPSess = LFPFinal{genotype}{recSite}{sessNum};
                
                sessInfo = sessInfoFinal{genotype}{recSite}{sessNum};
                if ~isempty(LFPSess)
                    if height(LFPSess) <4
                        stimDurs = {'20'};
                    else
                        stimDurs = {'10','20','40','80'};
                    end
                    close all;
                    windowSize ={};
                    plotLims ={};
                    parfor stimDur = 1:numel(stimDurs)
                        windowSize{stimDur} = max(findDurationLFP(stimDurs{stimDur})/2, 0.025); %in s                
                        plotLims{stimDur} = [-windowSize{stimDur}/2, windowSize{stimDur}];
                        g{stimDur} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' stimDurs{stimDur} 'hz stim LFP ' ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1})],'NumberTitle','off'); clf;
                        g{stimDur}.WindowState = 'Maximized';
                        ind = (1:size(LFPSess{stimDur,2},1))*multi;
                        subplot(1,2,1, 'Parent', g{stimDur})
                        MPlot.PlotTraceLadder(LFPSess{stimDur,1}, LFPSess{stimDur,2}(chanMap), ind, 'Color', 'k');
                        xlim(plotLims{stimDur});
                        ylim([-10 70]*multi);
                        set(gca, 'YTick', ind, 'YTickLabel', newTickLabels);
                        title('ipsi stim')
                        subplot(1,2,2, 'Parent', g{stimDur})
                         if numel(LFPSess{stimDur,1}) ~= numel(LFPSess{stimDur,3}{1})
                            lastInds = min(numel(LFPSess{stimDur,1}), numel(LFPSess{stimDur,3}{1}));                            
                            tempContra = cellfun(@(x) x(1:lastInds), LFPSess{stimDur,3} , 'UniformOutput', false);                            
                            MPlot.PlotTraceLadder(LFPSess{stimDur,1}(1:lastInds), tempContra(chanMap), ind, 'Color', 'k');    
                        else
                            MPlot.PlotTraceLadder(LFPSess{stimDur,1}, LFPSess{stimDur,3}(chanMap), ind, 'Color', 'k');                            
                        end   
                        xlim(plotLims{stimDur});
                        ylim([-10 70]*multi);
                        set(gca, 'YTick', ind, 'YTickLabel', newTickLabels);
                        title('contra stim')
                        sgtitle(['Ipsi sess ' stimDurs{stimDur} ' hz'])
                        set(g{stimDur}, 'Position', [3044,42,233,1074]);
                        if ~isfolder([ops.savePath normalized '\LFPs'])
                            mkdir([ops.savePath normalized '\LFPs']);
                        end
                        saveas(g{stimDur}, fullfile([ops.savePath normalized], 'LFPs', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' '  ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1}) ' ' stimDurs{stimDur} 'hz stim LFP_ipsisess.fig']));
                        saveas(g{stimDur}, fullfile([ops.savePath normalized], 'LFPs', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' '  ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1}) ' ' stimDurs{stimDur} 'hz stim LFP_ipsisess.png']));

                    end

                end


            end 

            bothSess = find(cell2mat(cellfun(@(x) strcmp(x,'Both'), sessType{genotype}{recSite}, 'UniformOutput', false)));
            for sessNum = bothSess
                %plot contra sess such that depending on the side of
                %recordingm plot the contra stim on teh left column and
                %ipsi stim on the right column
                % Note: here LFPfinal are already as ipsi and contra. first
                % column is time, 2nd is ipsi and 3rd is contra
                
                LFPSess = LFPFinal{genotype}{recSite}{sessNum};
                
                sessInfo = sessInfoFinal{genotype}{recSite}{sessNum};
                if ~isempty(LFPSess)
                    if height(LFPSess) <4
                        stimDurs = {'20'};
                    else
                        stimDurs = {'10','20','40','80'};
                    end
                    close all;
                    windowSize ={};
                    plotLims ={};
                    parfor stimDur = 1:numel(stimDurs)
                        windowSize{stimDur} = max(findDurationLFP(stimDurs{stimDur})/2, 0.025); %in s                
                        plotLims{stimDur} = [-windowSize{stimDur}/2, windowSize{stimDur}];
                        g{stimDur} = figure('Name', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' ' stimDurs{stimDur} 'hz stim LFP ' ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1})],'NumberTitle','off'); clf;
                        g{stimDur}.WindowState = 'Maximized';
                        ind = (1:size(LFPSess{stimDur,2},1))*multi;
                        subplot(1,2,1, 'Parent', g{stimDur})
                        MPlot.PlotTraceLadder(LFPSess{stimDur,1}, LFPSess{stimDur,2}(chanMap), ind, 'Color', 'k');
                        xlim([-0.01 plotLims{stimDur}(2)]);
                        ylim([-10 70]*multi);
                        set(gca, 'YTick', ind, 'YTickLabel', newTickLabels);
                        title('ipsi stim')
                        subplot(1,2,2, 'Parent', g{stimDur})
                         if numel(LFPSess{stimDur,1}) ~= numel(LFPSess{stimDur,3}{1})
                            lastInds = min(numel(LFPSess{stimDur,1}), numel(LFPSess{stimDur,3}{1}));                            
                            tempContra = cellfun(@(x) x(1:lastInds), LFPSess{stimDur,3} , 'UniformOutput', false);                            
                            MPlot.PlotTraceLadder(LFPSess{stimDur,1}(1:lastInds), tempContra(chanMap), ind, 'Color', 'k');    
                        else
                            MPlot.PlotTraceLadder(LFPSess{stimDur,1}, LFPSess{stimDur,3}(chanMap), ind, 'Color', 'k');                            
                        end   
                        xlim([-0.01 plotLims{stimDur}(2)]);
%                         xlim([-5,30]/1000);
                        ylim([-10 70]*multi);
                        set(gca, 'YTick', ind, 'YTickLabel', newTickLabels);
                        title('contra stim')
                        sgtitle(['Both sess ' stimDurs{stimDur} ' hz'])
                        set(g{stimDur}, 'Position', [3044,42,233,1074]);
                        if ~isfolder([ops.savePath normalized '\LFPs'])
                            mkdir([ops.savePath normalized '\LFPs']);
                        end
                        saveas(g{stimDur}, fullfile([ops.savePath normalized], 'LFPs', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' '  ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1}) ' ' stimDurs{stimDur} 'hz stim LFP_bothsess.fig']));
                        saveas(g{stimDur}, fullfile([ops.savePath normalized], 'LFPs', [uGenotypes{genotype} ' ' inputrecSites{recSite} ' '  ...
                            sessInfo.MouseName{1}   ' ' datestr(sessInfo.seshDate{1}) ' ' stimDurs{stimDur} 'hz stim LFP_bothsess.png']));

                    end

                end


            end 


        end
    end



end

function PlotAvgTracesFR(dataFileTb, ops, metadataTable, FRdataTable, window)
    genotypes = metadataTable.genotype;
    
    uGenotypes = unique(genotypes);
    close all;

   
   
    
    czData = cell(1,3);
    izData = cell(1,3); 
    colors = {[100/255 0 0];  [0 0 100/255]; [1 0 0] ; [0 0 1]};
    g = figure(1); clf;
    g.WindowState = 'Maximized';

    for stim = 1:3
        if ~iscell(czData{stim})
            czData{stim} = cell(1,2);
            izData{stim} = cell(1,2);
        end
        for geno = 1:numel(uGenotypes)
            czData{stim}{geno} = [];
            izData{stim}{geno} = [];
            mouseNames = find(strcmp(uGenotypes(geno), genotypes));
            for ani = 1:numel(mouseNames)

                animalZ = FRdataTable{mouseNames(ani), 'meanFR'}{1}.(window);
%                     pvalIpsi = metadataTable{mouseNames(ani), 'pvalIpsi'}{1}.(window);
%                     pvalContra = metadataTable{mouseNames(ani), 'pvalContra'}{1}.(window);
                pvalAny = metadataTable{mouseNames(ani), 'pvalBoth'}{1}.(window);
                
                if stim > width(pvalAny{1})
                    continue;
                end
                for sessNum = 1:height(animalZ)

                    if width(pvalAny{sessNum})>3

                        pvalTemp = cell2mat(table2cell(pvalAny{sessNum}(:,1:3)));
                        pstimDur = stim;
                    else
                        pvalTemp = cell2mat(table2cell(pvalAny{sessNum}));
                        pstimDur = stim+1;
                    end
                    pvalTemp = pvalTemp< ops.plotAlpha;
                    sumLogics = sum(pvalTemp,2);
                    sigUnits = sumLogics>0;
                    
                    temp = table2cell(animalZ{sessNum}(:,stim));
                    temp = vertcat(temp{:});
                    time = temp{1,1};

                    

                  

                    cTemp = cell2mat(temp(sigUnits,2));
                    iTemp = cell2mat(temp(sigUnits,3));
                    if ~iscell(czData{pstimDur})
                        czData{pstimDur} = cell(1,2);
                        izData{pstimDur} = cell(1,2);
                    end
                    startc = height(czData{pstimDur}{geno});
                    starti = height(izData{pstimDur}{geno});
                    czData{pstimDur}{geno}(startc+1:startc+height(cTemp),:) = cTemp;
                    izData{pstimDur}{geno}(starti+1:starti+height(iTemp),:) = iTemp;
                end


            end
       
            [meanContra, ~, ~, ciContra] = MMath.MeanStats(czData{stim}{geno},1);
            [meanIpsi, ~, ~, ciIpsi] = MMath.MeanStats(izData{stim}{geno},1);
            if strcmp('KO', uGenotypes{geno})
                h =subplot(3,4,stim*4);  
                hold(h,'on')
                plot(time, meanContra, 'color', colors{geno*2-1}, 'LineWidth', 1);
                plot(time, meanIpsi, 'color', colors{geno*2}, 'LineWidth', 1);
                MPlot.ErrorShade(time, meanContra, ciContra(2,:), ...
                                ciContra(1,:), 'color',colors{geno*2-1}, 'Alpha', 0.3, 'IsRelative', false); 
                MPlot.ErrorShade(time, meanIpsi, ciIpsi(2,:), ...
                                ciIpsi(1,:), 'color',colors{geno*2}, 'Alpha', 0.3, 'IsRelative', false); 
%                 ylim([0, 10]);       
                yLimits = get(gca,'YLim');
                MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
                xlabel('epoch time (s)');
                ylabel('FR hz');  
                title([uGenotypes{geno} ' Contra vs Ipsi']);
                legend({'Contra', 'Ipsi'});
                
                hold(h, 'off');
            else
                h =subplot(3,4,stim*4-3);  
                hold(h,'on')
                plot(time, meanContra, 'color', colors{geno*2-1}, 'LineWidth', 1);
                plot(time, meanIpsi, 'color', colors{geno*2}, 'LineWidth', 1);
                MPlot.ErrorShade(time, meanContra, ciContra(2,:), ...
                                ciContra(1,:), 'color',colors{geno*2-1}, 'Alpha', 0.3, 'IsRelative', false); 
                MPlot.ErrorShade(time, meanIpsi, ciIpsi(2,:), ...
                                ciIpsi(1,:), 'color',colors{geno*2}, 'Alpha', 0.3, 'IsRelative', false); 
%                 ylim([0, 10]);       
                yLimits = get(gca,'YLim');
                MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
                xlabel('epoch time (s)');
                
                ylabel('FR hz');  
                title([uGenotypes{geno} ' Contra vs Ipsi']);
                legend({'Contra', 'Ipsi'});
                
                hold(h, 'off');

            end

            h =subplot(3,4,stim*4-2);  
            hold(h,'on')
            k(geno)=plot(time, meanContra, 'color', colors{geno*2-1}, 'LineWidth', 1);
           
            MPlot.ErrorShade(time, meanContra, ciContra(2,:), ...
                            ciContra(1,:), 'color',colors{geno*2-1}, 'Alpha', 0.3, 'IsRelative', false); 
           
            if strcmp('WT', uGenotypes{geno})    
%                 ylim([0, 10]);
                yLimits = get(gca,'YLim');
                MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
                xlabel('epoch time (s)');
                ylabel('FR hz');  
               
                title(['Contra KO vs WT']);
                legend(k, {'KO', 'WT'});
                
            end
            hold(h, 'off');

            h =subplot(3,4,stim*4-1);  
            hold(h,'on')
            l(geno)=plot(time, meanIpsi, 'color', colors{geno*2}, 'LineWidth', 1);
           
            MPlot.ErrorShade(time, meanIpsi, ciIpsi(2,:), ...
                            ciIpsi(1,:), 'color', colors{geno*2}, 'Alpha', 0.3, 'IsRelative', false); 
           
            if strcmp('WT', uGenotypes{geno})    
%                 ylim([0, 10]);
                yLimits = get(gca,'YLim');
                MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
                xlabel('epoch time (s)');
                
                ylabel('FR hz');  
                title(['Ipsi KO vs WT']);
                legend(l, {'KO', 'WT'});
                
            end
            hold(h, 'off');
        end




    end

    savefig(g,fullfile(ops.savePath, ['Average FR figures window ' window ' ms.fig']));
    saveas(g, fullfile(ops.savePath, ['Average FR figures window ' window ' ms.png']));
  
   
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
    set(g, 'Units', 'inches', 'Position', [1,1,3,2.25]);
    stimNames = {'10 Hz', '20 Hz', '30 Hz'};
    
    for stim = 1:3
        if ~iscell(czData{stim})
            czData{stim} = cell(1,2);
            izData{stim} = cell(1,2);
        end
        for geno = 1:numel(uGenotypes)
            czData{stim}{geno} = [];
            izData{stim}{geno} = [];
            mouseNames = find(strcmp(uGenotypes(geno), genotypes));
            for ani = 1:numel(mouseNames)

                animalZ = FRdataTable{mouseNames(ani), 'meanFR'}{1}.(window);
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
                    
                    temp = table2cell(animalZ{sessNum}(:,stim));
                    temp = vertcat(temp{:});
                    time = temp{1,1};

                    

                  

                    cTemp = cell2mat(temp(sigUnits,2));
                    iTemp = cell2mat(temp(sigUnits,3));
                    if ~iscell(czData{pstimDur})
                        czData{pstimDur} = cell(1,2);
                        izData{pstimDur} = cell(1,2);
                    end
                    startc = height(czData{pstimDur}{geno});
                    starti = height(izData{pstimDur}{geno});
                    czData{pstimDur}{geno}(startc+1:startc+height(cTemp),:) = cTemp;
                    izData{pstimDur}{geno}(starti+1:starti+height(iTemp),:) = iTemp;
                end


            end
            
            [meanContra, ~, ~, ciContra] = MMath.MeanStats(czData{stim}{geno},1);
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
                MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
                
%                 xlabel('Time from stim onset(s)');
%                 
%                 ylabel({'Mean spiking rate','(hz)'});  
%                 title([uGenotypes{geno} ' Contra vs Ipsi'], 'FontSize', 36);
%                 if stim ==1
%                     legend({'Contra', 'Ipsi'});
%                 end

                h.LineWidth = 1;
                h.XTick = [ops.plotxLims(1):0.05:ops.plotxLims(2)];
                h.XTickLabel = arrayfun(@(x) num2str(x), h.XTick, 'UniformOutput', false);
                h.TickLength = [0.05 0.05];

                set(gca, 'FontSize', 6, 'FontName', 'Arial');
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
                MPlot.PlotPointAsLine(0,yLimits(2)/2,yLimits(2), 'orientation', 'vertical', 'linestyle', '--','color',[0.5 0.5 0.5], 'linewidth', 1);
%                 xlabel('Time from stim onset(s)');
                
%                 ylabel({'Mean spiking rate','(hz)'});  

%                 title([uGenotypes{geno} ' Contra vs Ipsi'], 'FontSize', 36);
%                 if stim ==1
%                     legend({'Contra', 'Ipsi'});
%                 end
%                 
                h.LineWidth = 1;
                h.XTick = [ops.plotxLims(1):0.05:ops.plotxLims(2)];
                h.XTickLabel = arrayfun(@(x) num2str(x), h.XTick, 'UniformOutput', false);
                h.TickLength = [0.05 0.05];

                set(gca, 'FontSize', 6, 'FontName', 'Arial');
                hold(h, 'off');

            end



           
        end




    end

    fclose(fileID);

    savefig(g,fullfile(ops.savePath, ['Average FR figures window ' window ' ms.fig']));
    exportgraphics(g, fullfile(ops.savePath, ['Average FR figures window ' window ' ms.tiff']), 'Resolution', 1200);
  
   
end


function CBiasDepthHistoBar(ops, metadataTable, binWidth)
    
     close all   
     % L1, 128 ± 1 μm; L2, 269 ± 2 μm; L3, 418 ± 3 μm; L4, 588 ± 3 μm; L5A, 708 ± 4 μm; L5B, 890 ± 5 μm; L6, 1154 ± 7 μm.
    % just signify according to allpvals
    
    depthTable = metadataTable.UnitDepth;   
    cbiasTable = metadataTable.cbias;
    pvalTable = metadataTable.pvalBoth;
    animalIds = unique(metadataTable.Properties.RowNames);
    genotypes = metadataTable.genotype;
    uGenotype = unique(genotypes);
    windows = ops.WindowNames;
    stimNames ={'10hz', '20hz', '40hz'};
    
    for win = 1: numel(ops.windows)

        savePath = fullfile(ops.savePath, ops.WindowNames{win});

        if ~isfolder(savePath)
            mkdir(savePath);
        end

        cbiasFinal = cell(2,3);
        depthFinal = cell(2,3);
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

                        pvalsess = pvalsess(:,1:3);
                        pstimDur = 1:3;
                        cbiasSess = cbiasSess(:,1:3);
                    else
                        pstimDur =2;
                    end
                    sumlogics = sum(pvalsess < ops.plotAlpha,2);
                    sigUnits = find(sumlogics>0);
                    cbiasSess = cell2mat(table2cell(cbiasSess(sigUnits,:)));
                    depthSess = cell2mat(table2cell(depthSess(sigUnits,:)));
                    if ~isempty(cbiasSess)
                       for stim = 1:width(cbiasSess)
                            indx = numel(cbiasFinal{geno,pstimDur(stim)});
                            cbiasFinal{geno,pstimDur(stim)}(indx+1:indx+height(cbiasSess)) = cbiasSess(:,stim);
                            depthFinal{geno,pstimDur(stim)}(indx+1:indx+height(depthSess)) = depthSess(:,stim);
                            
                       end
                            
                
                    end
                        
                end

            end
        end
        
    %  L1, 128 ± 1 μm; L2, 269 ± 2 μm; L3, 418 ± 3 μm; L4, 588 ± 3 μm; L5A, 708 ± 4 μm; L5B, 890 ± 5 μm; L6, 1154 ± 7 μm.

        
       for stim =1:numel(stimNames)
            g = figure(stim); clf;
            g.WindowState = 'Maximized';
            hold on
            for genotype =1:height(depthFinal)
                
               
                  
                   
                data = [cbiasFinal{genotype,stim}', depthFinal{genotype,stim}'];
    
                lowerBounds = [418/1154,588/1154,max(data(:,2))];
                upperBounds = [min(data(:,2)),418/1154,588/1154];
                binEdgesY = upperBounds + (lowerBounds-upperBounds)/2
    

                binsX =-1:2/ops.parts:1;
                lowerBounds = binsX(1:end-1);
                upperBounds = binsX(2:end);
                binEdgesX = upperBounds + (lowerBounds-upperBounds)/2;
               
                
                H = hist3(data, ...
                    {binEdgesX,binEdgesY}, 'CdataMode','auto');
            
                HSup = H(:,1)'/sum(H(:,1));
                HL4 = H(:,2)'/sum(H(:,2));
                HDeep = H(:,3)'/sum(H(:,3));
    
                [X, Y ] = meshgrid(binEdgesX, [1/6,1/2, 5/6]);
                Z = [HSup; HL4; HDeep]*100;
                
                    
                    
                               
                
                % Number of bars to plot
                [numRows, numCols] = size(Z);
                
                % Bar width
                barWidthX = 2/ops.parts;
                barWidthY = 0.3;
                
                
                ax = subplot(1, height(depthFinal),height(depthFinal)+1-genotype);
                % Hold on to plot multiple bars
                hold (ax, 'on');
                
                % Define a colormap (e.g., jet, hot, cool, parula, etc.)
                colormap(jet);
                cmap = colormap; % Store the colormap
                colorRange = linspace(0, 100, size(cmap, 1)); % Range of Z values for the colormap
                barcolor = [0.7 0.7 0.7];
                
                % Generate bars manually
                for i = 1:numRows
                    for j = 1:numCols
                        % Calculate color index
                        [~, colorIndex] = min(abs(colorRange - Z(i, j)));
                
                        % Coordinates for the corners of each bar
                        xCoords = [X(i, j)-barWidthX/2, X(i, j)+barWidthX/2, X(i, j)+barWidthX/2, X(i, j)-barWidthX/2];
                        yCoords = [Y(i, j)-barWidthY/2, Y(i, j)-barWidthY/2, Y(i, j)+barWidthY/2, Y(i, j)+barWidthY/2];
                        zCoords = zeros(1, 4);  % Bottom of the bar
                        zTop = [Z(i, j), Z(i, j), Z(i, j), Z(i, j)];  % Top of the bar
                
                        % Plot the bottom of the bar
                        fill3(xCoords, yCoords, zCoords, 'b');
                
                        % Plot the four sides of the bar
                        fill3([xCoords(1), xCoords(2), xCoords(2), xCoords(1)], [yCoords(1), yCoords(2), yCoords(2), yCoords(1)], [zCoords(1), zCoords(2), zTop(2), zTop(1)], barcolor);
                        fill3([xCoords(2), xCoords(3), xCoords(3), xCoords(2)], [yCoords(2), yCoords(3), yCoords(3), yCoords(2)], [zCoords(2), zCoords(3), zTop(3), zTop(2)], barcolor);
                        fill3([xCoords(3), xCoords(4), xCoords(4), xCoords(3)], [yCoords(3), yCoords(4), yCoords(4), yCoords(3)], [zCoords(3), zCoords(4), zTop(4), zTop(3)], barcolor);
                        fill3([xCoords(4), xCoords(1), xCoords(1), xCoords(4)], [yCoords(4), yCoords(1), yCoords(1), yCoords(4)], [zCoords(4), zCoords(1), zTop(1), zTop(4)], barcolor);
                
                        % Plot the top of the bar
                        fill3(xCoords, yCoords, zTop, cmap(colorIndex, :));
                    end
                end
                
                     
             
              
                set(gca, 'FontSize', 24);
               

                title([uGenotype{genotype} ' ' stimNames{stim}], 'FontSize', 36);
                yticks([1/6,1/2, 5/6])
                yticklabels({'Superficial', 'L4',  'Deep'});
                xticks(binsX)
%                 xticklabels({'-1', '-0.33', '0.33' , '1'});
                ylim([0,1]);
                zlim([0,100]);
                zticks([0:20:100]);
                if genotype ==1
                   
                    h = colorbar;               
                    % Set the color bar limits
                    h.Limits = [0, 1];  % Ensure color bar covers 0 to 1
                    
                    % Set the ticks on the color bar
                    h.Ticks = linspace(0, 1, 11);  % Create 11 ticks from 0 to 1
                    
                    % Set the tick labels based on your desired range (0 to 100)
                    h.TickLabels = linspace(0, 100, 11);
    
                    tt = get(h, 'Position');
                    set(h, 'Position', [tt(1)+0.05, tt(2)+0.1, tt(3), tt(4)-0.2]); % Adjust the position and size as needed
%                     ylabel('Cortical layers','VerticalAlignment','baseline', 'FontSize', 36);
                    
                end
%                 zlabel('Percent of units', 'FontSize', 36);
%                 xlabel('Contra Bias','VerticalAlignment','baseline',  'FontSize', 36);
                
                % Set the view angle
                az = -45; % azimuth
                el = 30; % elevation
                view(az, el);
                 % Release hold

                 grid on
                hold (ax, 'off');   
                               
                
             


                
            end
            
            hold off
            savefig(g,fullfile(savePath,  [stimNames{stim} ' depth cbias histogram.fig']));
            saveas(g,fullfile(savePath,  [stimNames{stim} ' depth cbias histogram.png']));
       end


    end                
          




        
end


function CBiasDepthHistoLine(ops, metadataTable,nboot, LTwoThree, LFour)
    
     close all   
     % L1, 128 ± 1 μm; L2, 269 ± 2 μm; L3, 418 ± 3 μm; L4, 588 ± 3 μm; L5A, 708 ± 4 μm; L5B, 890 ± 5 μm; L6, 1154 ± 7 μm.
    % just signify according to allpvals
    
    depthTable = metadataTable.UnitDepth;   
    cbiasTable = metadataTable.cbias;
    pvalTable = metadataTable.pvalBoth;
    animalIds = unique(metadataTable.Properties.RowNames);
    genotypes = metadataTable.genotype;
    uGenotype = unique(genotypes);
    windows = ops.WindowNames;
    stimNames ={'10hz', '20hz', '40hz'};
    
    ylim2 = [100, 100, 100, 100,100, 100, 100, 100 ];
    colors = {[1 0 0 ], [0.5 0.5 0.5]};
%     for win = 1: numel(ops.windows)
    for win = 6
        savePath = fullfile(ops.savePath, ops.WindowNames{win});
    %         savePath = fullfile(ops.savePath, 'Percent Units depth movie');
    
        if ~isfolder(savePath)
            mkdir(savePath);
        end
    
        cbiasFinalreal = cell(2,3);
        depthFinalreal = cell(2,3);
        rng(7);

     
        % get real mean data
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

                        pvalsess = pvalsess(:,1:3);
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
                            unitDepth = cell2mat(table2cell(depthSess(:,stim)));

%                             unitDepth = cell2mat(cellfun(@(x) x.unitDepth, table2cell(depthSess(:,stim)), 'UniformOutput', false));
                            
                            depthFinalreal{geno,pstimDur(stim)}{ani}(indx+1:indx+numel(unitDepth)) = unitDepth; 

                       end
                            
                
                    end
                        
                end

            end
        
          
        end
    


        %calculate real data means
        for stim =1:numel(stimNames)
           
            for genotype =1:height(depthFinalreal)
               HSupReal{genotype, stim} = [];
               HFourReal{genotype, stim} = [];
               HDeepReal{genotype, stim} = [];
               
               
               for ani = 1: numel(depthFinalreal{genotype, stim})
                    data = [cbiasFinalreal{genotype,stim}{ani}', depthFinalreal{genotype,stim}{ani}'];
                    if isempty(data)
                        continue;
                    end
                    data(find(isnan(data(:,1))),:)=[];
                    
                    lowerBounds = [LTwoThree, LFour, max(max(data(:,2)),1)];
                    upperBounds = [min(min(data(:,2)),0), LTwoThree, LFour];
                    
                    binEdgesY = upperBounds + (lowerBounds-upperBounds)/2;
    
                    binsX =-1:2/ops.parts:1;
                    lowerBounds = binsX(1:end-1);
                    upperBounds = binsX(2:end);
                    binEdgesX = upperBounds + (lowerBounds-upperBounds)/2;
                   
                    
                    H = hist3(data, ...
                        {binEdgesX,binEdgesY}, 'CdataMode','auto');
                
%                     HSupReal{genotype, stim}(ani, :) = [0, H(:,1)'/sum(H(:,1)), 0]*100;
%                     HDeepReal{genotype, stim}(ani, :) = [0, H(:,2)'/sum(H(:,2)), 0]*100;

                    HSupReal{genotype, stim}(ani, :) = H(1,:)/sum(H(1,:))*100;
                    HFourReal{genotype, stim}(ani, :) = H(2,:)/sum(H(2,:))*100;
                    HDeepReal{genotype, stim}(ani, :) = H(3,:)/sum(H(3,:))*100;
                   
                    

               end
    
            
                   
            end
        end
           
      
        for stim =1:numel(stimNames)
           
            for genotype =1:height(depthFinalreal)
               
               
               genData = [];
               for ani = 1: numel(depthFinalreal{genotype, stim})
                    data = [cbiasFinalreal{genotype,stim}{ani}', depthFinalreal{genotype,stim}{ani}'];
                    if isempty(data)
                        continue;
                    end
                    data(find(isnan(data(:,1))),:)=[];
                    genData = [genData; data];
                    lowerBounds = [LTwoThree, LFour,max(max(data(:,2)), 1)];
                    upperBounds = [min(min(data(:,2)),0),LTwoThree, LFour];
                    
                    binEdgesY = upperBounds + (lowerBounds-upperBounds)/2;
        
    
                    binsX =-1:2/ops.parts:1;
                    lowerBounds = binsX(1:end-1);
                    upperBounds = binsX(2:end);
                    binEdgesX = upperBounds + (lowerBounds-upperBounds)/2;
                   
                    
                    

                    numUnits = height(data);
                    
                    
                   
                    
                  
               end

               
                dataSup = genData(genData(:,2)<=LTwoThree & genData(:,2)>=min(genData(:,2)),:);
                numUnitsS = height(dataSup);

                dataFour = genData(genData(:,2)<=LFour & genData(:,2)>LTwoThree,:);
                numUnitsF = height(dataFour);
                
                dataDeep = genData(genData(:,2)>LFour & genData(:,2)<=max(max(genData(:,2)),1500),:);
                numUnitsD = height(dataDeep);

                HSup{genotype, stim} = [];
                HFour{genotype, stim} = [];
                HDeep{genotype, stim} =[];
                rng(7);
               
                for boot = 1:nboot
                        
                        unitsTotake = datasample(1:numUnitsS, numUnitsS, 'Replace', true);                        
                        dataBootS = dataSup(unitsTotake,:);

                        unitsTotake = datasample(1:numUnitsF, numUnitsF, 'Replace', true);                        
                        dataBootF = dataFour(unitsTotake,:);

                        unitsTotake = datasample(1:numUnitsD, numUnitsD, 'Replace', true);                        
                        dataBootD = dataDeep(unitsTotake,:);
                        
                        binsX =-1:2/ops.parts:1;
                        lowerBounds = binsX(1:end-1);
                        upperBounds = binsX(2:end);
                        binEdgesX = upperBounds + (lowerBounds-upperBounds)/2;
                       
                        
                        sup = hist(dataBootS(:,1), ...
                            binEdgesX);

                        HSup{genotype, stim}(boot, :) = sup/sum(sup)*100;

                        four = hist(dataBootF(:,1), ...
                            binEdgesX);
                       
                        HFour{genotype, stim}(boot, :) = four/sum(four)*100;
                        
                        deep = hist(dataBootD(:,1), ...
                            binEdgesX);
                       
                        HDeep{genotype, stim}(boot, :) = deep/sum(deep)*100;
 
                       
                    end
          
            end
        end
           
        

        g = figure(win); clf;
        g.WindowState = 'Maximized';
        hold on
        for stim =1:numel(stimNames)
           
            for genotype =1:height(depthFinalreal)
              
                x = -1:2/(ops.parts-1):1;
                ciSup = CalcCI(HSup{genotype, stim}, 0.95);
%                 Sup = permute(HSup(genotype, stim, :,:)*100, [3,4,1,2]);
%                 [meanSup, ~,~, ciSup] = MMath.MeanStats( cell2mat(HSup{genotype, stim}'),1);

                % remove animals with nans
                HSupReal{genotype, stim}(isnan(HSupReal{genotype, stim}(:,2)),:)=[];
                
                % remove animals with no units i.e. sum <<100
                HSupReal{genotype, stim}(sum(HSupReal{genotype, stim},2)<90,:) =[];

%                 meanSup = mean(HSupReal{genotype, stim},1);
                meanSup = mean(HSup{genotype, stim},1);
%                 stdSup = std(HSupReal{genotype, stim},1);
                
                ciFour = CalcCI(HFour{genotype, stim}, 0.95);
%                 Four = permute(HFour(genotype, stim, :,:)*100, [3,4,1,2]);
%                 [meanFour, ~,~, ciFour] = MMath.MeanStats( cell2mat(HFour{genotype, stim}'),1);
                HFourReal{genotype, stim}(isnan(HFourReal{genotype, stim}(:,2)),:)=[];
%                 meanFour = mean(HFourReal{genotype, stim},1);
                meanFour = mean(HFour{genotype, stim},1);
%                 stdFour = std(HFourReal{genotype, stim},1);



%                 Deep = permute(HDeep(genotype, stim, :,:)*100, [3,4,1,2]);
                ciDeep = CalcCI(HDeep{genotype, stim}, 0.95);
%                 [meanDeep, ~,~, ciDeep] = MMath.MeanStats( cell2mat(HDeep{genotype, stim}'),1);
                HDeepReal{genotype, stim}(isnan(HDeepReal{genotype, stim}(:,2)),:)=[];
                meanDeep = mean(HDeep{genotype, stim},1);
%                 meanDeep = mean(HDeepReal{genotype, stim},1);
%                 stdDeep = std(HDeepReal{genotype, stim},1);

                
                ax1 = subplot(3, numel(stimNames),stim);
                % Hold on to plot multiple bars
                
                hold(ax1, 'on');
                plot(x, meanSup, 'LineStyle', '-', 'Color', colors{genotype}, 'LineWidth', 2);

                MPlot.ErrorShade(x, meanSup, ciSup(2,:), ...
                    ciSup(1,:), 'IsRelative', false, 'color', colors{genotype}, 'Alpha', 0.3);
                if genotype ==2        
                    set(gca, 'FontSize', 24);
                    xlim([-1.2,1.2]);        
                    ylim([0,ylim2(win)]);     
                    title(stimNames{stim});    
%                     legend({'KO', 'WT'});
                end
                hold(ax1, 'off');

                ax2 = subplot(3, numel(stimNames),stim + numel(stimNames));
                hold(ax2, 'on');
                plot(x, meanFour, 'LineStyle', '-', 'Color', colors{genotype}, 'LineWidth', 2);

                MPlot.ErrorShade(x, meanFour, ciFour(2,:), ...
                    ciFour(1,:), 'IsRelative', false, 'color', colors{genotype}, 'Alpha', 0.3);
                if genotype ==2        
                    set(gca, 'FontSize', 24);
                    xlim([-1.2,1.2]);        
                    ylim([0,ylim2(win)]);
%                     title('Deep');    
%                     legend({'KO', 'WT'});
                 end
                hold(ax2, 'off');  

                ax3 = subplot(3, numel(stimNames),stim + 2*numel(stimNames));
                hold(ax3, 'on');
                plot(x, meanDeep, 'LineStyle', '-', 'Color', colors{genotype}, 'LineWidth', 2);

                MPlot.ErrorShade(x, meanDeep, ciDeep(2,:), ...
                    ciDeep(1,:), 'IsRelative', false, 'color', colors{genotype}, 'Alpha', 0.3);
                if genotype ==2        
                    set(gca, 'FontSize', 24);
                    xlim([-1.2,1.2]);        
                    ylim([0,ylim2(win)]);
%                     title('Deep');    
%                     legend({'KO', 'WT'});
                 end
                hold(ax3, 'off');             
                
            end
            
       end
        sgtitle(ops.WindowNames{win})
        hold off
        
        savefig(g,fullfile(savePath,  [' depth cbias histogram line.fig']));
        saveas(g,fullfile(savePath,  [' depth cbias histogram line.png']));

    end                
          




        
end

function CBiasDepthHistoLine2(ops, metadataTable,nboot, LTwoThree, LFour)
      close all   
     % L1, 128 ± 1 μm; L2, 269 ± 2 μm; L3, 418 ± 3 μm; L4, 588 ± 3 μm; L5A, 708 ± 4 μm; L5B, 890 ± 5 μm; L6, 1154 ± 7 μm.
    % just signify according to allpvals
    
    depthTable = metadataTable.UnitDepth;   
    cbiasTable = metadataTable.cbias;
    pvalTable = metadataTable.pvalBoth;
    animalIds = unique(metadataTable.Properties.RowNames);
    genotypes = metadataTable.genotype;
    uGenotype = unique(genotypes);
    windows = ops.WindowNames;
    stimNames ={'10hz', '20hz', '40hz'};
    
    ylim2 = [100, 100, 100, 100,100, 100, 100, 100 ];
    colors = {[1 0 0 ], [0.5 0.5 0.5]};
%     for win = 1: numel(ops.windows)
    for win = 6
        savePath = fullfile(ops.savePath, ops.WindowNames{win});
    %         savePath = fullfile(ops.savePath, 'Percent Units depth movie');
    
        if ~isfolder(savePath)
            mkdir(savePath);
        end
    
        cbiasFinalreal = cell(2,3);
        depthFinalreal = cell(2,3);
        rng(7);

     
        % get real mean data
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

                        pvalsess = pvalsess(:,1:3);
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
                            unitDepth = cell2mat(table2cell(depthSess(:,stim)));

%                             unitDepth = cell2mat(cellfun(@(x) x.unitDepth, table2cell(depthSess(:,stim)), 'UniformOutput', false));
                            
                            depthFinalreal{geno,pstimDur(stim)}{ani}(indx+1:indx+numel(unitDepth)) = unitDepth; 

                       end
                            
                
                    end
                        
                end

            end
        
          
        end
    


        %calculate real data means
        for stim =1:numel(stimNames)
           
            for genotype =1:height(depthFinalreal)
               HSupReal{genotype, stim} = [];
               HFourReal{genotype, stim} = [];
               HDeepReal{genotype, stim} = [];
               
               
               for ani = 1: numel(depthFinalreal{genotype, stim})
                    data = [cbiasFinalreal{genotype,stim}{ani}', depthFinalreal{genotype,stim}{ani}'];
                    if isempty(data)
                        continue;
                    end
                    data(find(isnan(data(:,1))),:)=[];
                    
                    lowerBounds = [LTwoThree, LFour, max(max(data(:,2)),1)];
                    upperBounds = [min(min(data(:,2)),0), LTwoThree, LFour];
                    
                    binEdgesY = upperBounds + (lowerBounds-upperBounds)/2;
    
                    binsX =-1:2/ops.parts:1;
                    lowerBounds = binsX(1:end-1);
                    upperBounds = binsX(2:end);
                    binEdgesX = upperBounds + (lowerBounds-upperBounds)/2;
                   
                    
                    H = hist3(data, ...
                        {binEdgesX,binEdgesY}, 'CdataMode','auto');
                
%                     HSupReal{genotype, stim}(ani, :) = [0, H(:,1)'/sum(H(:,1)), 0]*100;
%                     HDeepReal{genotype, stim}(ani, :) = [0, H(:,2)'/sum(H(:,2)), 0]*100;
                    
                    HSupReal{genotype, stim}(ani, :) = H(:,1)/sum(H(:,1))*100;
                    HFourReal{genotype, stim}(ani, :) = H(:,2)/sum(H(:,2))*100;
                    HDeepReal{genotype, stim}(ani, :) = H(:,3)/sum(H(:,3))*100;
                   
                    

               end
    
            end
        end
           
      
        for stim =1:numel(stimNames)
           
            for genotype =1:height(depthFinalreal)
               
               
               genData = [];
               for ani = 1: numel(depthFinalreal{genotype, stim})
                    data = [cbiasFinalreal{genotype,stim}{ani}', depthFinalreal{genotype,stim}{ani}'];
                    if isempty(data)
                        continue;
                    end
                    data(find(isnan(data(:,1))),:)=[];
                    genData = [genData; data];
                    lowerBounds = [LTwoThree, LFour,max(max(data(:,2)), 1)];
                    upperBounds = [min(min(data(:,2)),0),LTwoThree, LFour];
                    
                    binEdgesY = upperBounds + (lowerBounds-upperBounds)/2;
        
    
                    binsX =-1:2/ops.parts:1;
                    lowerBounds = binsX(1:end-1);
                    upperBounds = binsX(2:end);
                    binEdgesX = upperBounds + (lowerBounds-upperBounds)/2;
                   
                    numUnits = height(data);
                    
               end

              
                HSup{genotype, stim} = [];
                HFour{genotype, stim} = [];
                HDeep{genotype, stim} =[];
                rng(7);
               
                for boot = 1:nboot
                    numUnits = height(genData);
                    unitsTotake = datasample(1:numUnits, numUnits, 'Replace', true);                        
                    dataBoot = genData(unitsTotake,:);

                    lowerBounds = [LTwoThree, LFour,max(max(dataBoot(:,2)),1)];
                    upperBounds = [min(min(dataBoot(:,2)),0),LTwoThree, LFour];
                    
                    binEdgesY = upperBounds + (lowerBounds-upperBounds)/2;
        
    
                    binsX =-1:2/ops.parts:1;
                    lowerBounds = binsX(1:end-1);
                    upperBounds = binsX(2:end);
                    binEdgesX = upperBounds + (lowerBounds-upperBounds)/2;
                   
                    
                    H = hist3(dataBoot, ...
                        {binEdgesX,binEdgesY}, 'CdataMode','auto');
                
                    HSup{genotype, stim}(boot, :) = H(:,1)'/sum(H(:,1))*100;
                    HFour{genotype, stim}(boot, :) = H(:,2)'/sum(H(:,2))*100;
                    HDeep{genotype, stim}(boot, :) = H(:,3)'/sum(H(:,3))*100;
                       
                end
          
            end
        end
           
        

        g = figure(win); clf;
        g.WindowState = 'Maximized';
        hold on
        for stim =1:numel(stimNames)
           
            for genotype =1:height(depthFinalreal)
              
                x = -1:2/(ops.parts-1):1;
                % remove animals with nans
                HSup{genotype, stim}(isnan(HSup{genotype, stim}(:,2)),:)=[];
                ciSup = CalcCI(HSup{genotype, stim}, 0.95);

%                 Sup = permute(HSup(genotype, stim, :,:)*100, [3,4,1,2]);
%                 [meanSup, ~,~, ciSup] = MMath.MeanStats( cell2mat(HSup{genotype, stim}'),1);

                
                
                % remove animals with no units i.e. sum <<100
                HSupReal{genotype, stim}(sum(HSupReal{genotype, stim},2)<90,:) =[];
                
%                 meanSup = mean(HSupReal{genotype, stim},1);
                meanSup = mean(HSup{genotype, stim},1);
%                 stdSup = std(HSupReal{genotype, stim},1);
                
                ciFour = CalcCI(HFour{genotype, stim}, 0.95);
%                 Four = permute(HFour(genotype, stim, :,:)*100, [3,4,1,2]);
%                 [meanFour, ~,~, ciFour] = MMath.MeanStats( cell2mat(HFour{genotype, stim}'),1);

                HFourReal{genotype, stim}(isnan(HFourReal{genotype, stim}(:,2)),:)=[];
%                 meanFour = mean(HFourReal{genotype, stim},1);
                meanFour = mean(HFour{genotype, stim},1);
%                 stdFour = std(HFourReal{genotype, stim},1);



%                 Deep = permute(HDeep(genotype, stim, :,:)*100, [3,4,1,2]);
                ciDeep = CalcCI(HDeep{genotype, stim}, 0.95);
%                 [meanDeep, ~,~, ciDeep] = MMath.MeanStats( cell2mat(HDeep{genotype, stim}'),1);
                HDeepReal{genotype, stim}(isnan(HDeepReal{genotype, stim}(:,2)),:)=[];
                meanDeep = mean(HDeep{genotype, stim},1);
%                 meanDeep = mean(HDeepReal{genotype, stim},1);
%                 stdDeep = std(HDeepReal{genotype, stim},1);

                
                ax1 = subplot(3, numel(stimNames),stim);
                % Hold on to plot multiple bars
                
                hold(ax1, 'on');
                plot(x, meanSup, 'LineStyle', '-', 'Color', colors{genotype}, 'LineWidth', 2);

                MPlot.ErrorShade(x, meanSup, ciSup(2,:), ...
                    ciSup(1,:), 'IsRelative', false, 'color', colors{genotype}, 'Alpha', 0.3);
                if genotype ==2        
                    set(gca, 'FontSize', 24);
                    xlim([-1.2,1.2]);        
                    ylim([0,ylim2(win)]);     
                    title(stimNames{stim});    
%                     legend({'KO', 'WT'});
                end
                hold(ax1, 'off');

                ax2 = subplot(3, numel(stimNames),stim + numel(stimNames));
                hold(ax2, 'on');
                plot(x, meanFour, 'LineStyle', '-', 'Color', colors{genotype}, 'LineWidth', 2);

                MPlot.ErrorShade(x, meanFour, ciFour(2,:), ...
                    ciFour(1,:), 'IsRelative', false, 'color', colors{genotype}, 'Alpha', 0.3);
                if genotype ==2        
                    set(gca, 'FontSize', 24);
                    xlim([-1.2,1.2]);        
                    ylim([0,ylim2(win)]);
%                     title('Deep');    
%                     legend({'KO', 'WT'});
                 end
                hold(ax2, 'off');  

                ax3 = subplot(3, numel(stimNames),stim + 2*numel(stimNames));
                hold(ax3, 'on');
                plot(x, meanDeep, 'LineStyle', '-', 'Color', colors{genotype}, 'LineWidth', 2);

                MPlot.ErrorShade(x, meanDeep, ciDeep(2,:), ...
                    ciDeep(1,:), 'IsRelative', false, 'color', colors{genotype}, 'Alpha', 0.3);
                if genotype ==2        
                    set(gca, 'FontSize', 24);
                    xlim([-1.2,1.2]);        
                    ylim([0,ylim2(win)]);
%                     title('Deep');    
%                     legend({'KO', 'WT'});
                 end
                hold(ax3, 'off');             
                
            end
            
       end
        sgtitle(ops.WindowNames{win})
        hold off
        
        savefig(g,fullfile(savePath,  [' depth cbias histogram line.fig']));
        saveas(g,fullfile(savePath,  [' depth cbias histogram line.png']));

    end                
          



        
end

function CBiasDepthHistoLine3(ops, metadataTable,nboot, LTwoThree, LFour)
    
    close all   
    % L1, 128 ± 1 μm; L2, 269 ± 2 μm; L3, 418 ± 3 μm; L4, 588 ± 3 μm; L5A, 708 ± 4 μm; L5B, 890 ± 5 μm; L6, 1154 ± 7 μm.
    % just signify according to allpvals
    
    depthTable = metadataTable.UnitDepth;   
    cbiasTable = metadataTable.cbias;
    pvalTable = metadataTable.pvalBoth;
    animalIds = unique(metadataTable.Properties.RowNames);
    genotypes = metadataTable.genotype;
    uGenotype = unique(genotypes);
    windows = ops.WindowNames;
    stimNames ={'10hz', '20hz', '40hz'};
    
    ylim2 = [100, 100, 100, 100, 100, 100, 100, 100 ];
    colors = {[1 0 0 ], [0.5 0.5 0.5]};
%     for win = 1: numel(ops.windows)
    for win = 6
        savePath = fullfile(ops.savePath, ops.WindowNames{win});
    %         savePath = fullfile(ops.savePath, 'Percent Units depth movie');
    
        if ~isfolder(savePath)
            mkdir(savePath);
        end
        


        cbiasFinal = cell(2,3);
        depthFinal = cell(2,3);
        rng(2);
        
        % calculate bootstrapped data
        for boot =1:nboot
            for geno = 1:numel(uGenotype)
                    
                animals= find(ismember(genotypes, uGenotype(geno)));
                CbiasGeno = cbiasTable(animals);
                pvalGeno = pvalTable(animals);
                depthGeno = depthTable(animals);

                
                nums = height(CbiasGeno);
                aniToTake = datasample(1:nums, nums, 'Replace', true);
                
                CbiasGeno = CbiasGeno(aniToTake);
                pvalGeno = pvalGeno(aniToTake);
                depthGeno = depthGeno(aniToTake);
                
             
                for ani = 1: numel(CbiasGeno) 
                    aniGeno = CbiasGeno{ani};
                    anipval = pvalGeno{ani};
                    aniDepth = depthGeno{ani};

                    nums = height(aniGeno);
                    sessToTake = datasample(1:nums, nums, 'Replace', true);
                    
                    aniGeno = aniGeno(sessToTake,:);
                    anipval = anipval(sessToTake,:);
                    aniDepth = aniDepth(sessToTake,:);
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
                            
                        nums = height(pvalsess);
                        unitsToTake = datasample(1:nums, nums, 'Replace', true);
                        
                        cbiasSess = cbiasSess(unitsToTake,:);
                        pvalsess = pvalsess(unitsToTake,:);
                        depthSess = depthSess(unitsToTake,:);

                        sumlogics = sum(pvalsess < ops.plotAlpha,2);
                        sigUnits = find(sumlogics>0);
                        cbiasSess = cell2mat(table2cell(cbiasSess(sigUnits,:)));
                        depthSess = depthSess(sigUnits,:);
                        
                        if ~isempty(cbiasSess)
                           for stim = 1:width(cbiasSess)
                                indx = numel(cbiasFinal{geno,pstimDur(stim)});
                                cbiasFinal{geno,pstimDur(stim)}(indx+1:indx+height(cbiasSess)) = cbiasSess(:,stim);
                                unitDepth = cell2mat(table2cell(depthSess(:,stim)));

                                depthFinal{geno,pstimDur(stim)}(indx+1:indx+numel(unitDepth)) = unitDepth; 
    
                           end
                                
                    
                        end
                            
                    end
    
                end
            
              
            end
            
            for stim =1:numel(stimNames)
           
                for genotype =1:height(depthFinal)
                 
                   
                    data = [cbiasFinal{genotype,stim}', depthFinal{genotype,stim}'];
                     if isempty(data)
                        continue;
                    end
                    data(find(isnan(data(:,1))),:)=[];
                  
              
                    lowerBounds = [LTwoThree, LFour,max(max(data(:,2)), 1)];
                    upperBounds = [min(min(data(:,2)),0),LTwoThree, LFour];
                    
                    binEdgesY = upperBounds + (lowerBounds-upperBounds)/2;
        
    
                    binsX =-1:2/ops.parts:1;
                    lowerBounds = binsX(1:end-1);
                    upperBounds = binsX(2:end);
                    binEdgesX = upperBounds + (lowerBounds-upperBounds)/2;
                   
                    
                    H = hist3(data, ...
                        {binEdgesX,binEdgesY}, 'CdataMode','auto');
                
                    HSup{genotype, stim}(boot, :) = H(:,1)'/sum(H(:,1))*100;
                    HFour{genotype, stim}(boot, :) = H(:,2)'/sum(H(:,2))*100;
                    HDeep{genotype, stim}(boot, :) = H(:,3)'/sum(H(:,3))*100;
                      
                end
            end
       
        
        end
        

        % get real mean data
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
                            unitDepth = cell2mat(table2cell(depthSess(:,stim)));

%                             unitDepth = cell2mat(cellfun(@(x) x.unitDepth, table2cell(depthSess(:,stim)), 'UniformOutput', false));
                            
                            depthFinalreal{geno,pstimDur(stim)}{ani}(indx+1:indx+numel(unitDepth)) = unitDepth; 

                       end
                            
                
                    end
                        
                end

            end
        
          
        end
    


        %calculate real data means
        for stim =1:numel(stimNames)
           
            for genotype =1:height(depthFinalreal)
               HSupReal{genotype, stim} = [];
               HFourReal{genotype, stim} = [];
               HDeepReal{genotype, stim} = [];
               
               
               for ani = 1: numel(depthFinalreal{genotype, stim})
                    data = [cbiasFinalreal{genotype,stim}{ani}', depthFinalreal{genotype,stim}{ani}'];
                    if isempty(data)
                        continue;
                    end
                    data(find(isnan(data(:,1))),:)=[];
                    
                    lowerBounds = [LTwoThree, LFour, max(max(data(:,2)),1)];
                    upperBounds = [min(min(data(:,2)),0), LTwoThree, LFour];
                    
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
                    HFourReal{genotype, stim}(ani, :) = H(:,2)'/sum(H(:,2))*100;
                    HDeepReal{genotype, stim}(ani, :) = H(:,3)'/sum(H(:,3))*100;
                   
                    

               end
    
            
                   
            end
        end
           
        
        g = figure(win); clf;
        g.WindowState = 'Maximized';
        hold on
        for stim =1:numel(stimNames)
           
            for genotype =1:height(depthFinal)
              
               x = -1:2/(ops.parts-1):1;
                ciSup = CalcCI(HSup{genotype, stim}, 0.95);
                meanSup = mean(HSup{genotype, stim},1);
%                 [meanSup, ~,~, ciSup] = MMath.MeanStats(HSup{genotype, stim},1);

                % remove animals with nans
                HSupReal{genotype, stim}(isnan(HSupReal{genotype, stim}(:,2)),:)=[];
                
                % remove animals with no units i.e. sum <<100
                HSupReal{genotype, stim}(sum(HSupReal{genotype, stim},2)<90,:) =[];
% 
%                 meanSup = mean(HSupReal{genotype, stim},1);
%                 stdSup = std(HSupReal{genotype, stim},1);
                

%                 Four = permute(HFour(genotype, stim, :,:)*100, [3,4,1,2]);
                ciFour = CalcCI(HFour{genotype, stim}, 0.95);
%                 [meanFour, ~,~, ciFour] = MMath.MeanStats( cell2mat(HFour{genotype, stim}'),1);
                HFourReal{genotype, stim}(isnan(HFourReal{genotype, stim}(:,2)),:)=[];
                meanFour = mean(HFourReal{genotype, stim},1);
                stdFour = std(HFourReal{genotype, stim},1);

%                 Deep = permute(HDeep(genotype, stim, :,:)*100, [3,4,1,2]);
                ciDeep = CalcCI(HDeep{genotype, stim}, 0.95);
%                 [meanDeep, ~,~, ciDeep] = MMath.MeanStats( cell2mat(HDeep{genotype, stim}'),1);
                HDeepReal{genotype, stim}(isnan(HDeepReal{genotype, stim}(:,2)),:)=[];
                meanDeep = mean(HDeepReal{genotype, stim},1);
                stdDeep = std(HDeepReal{genotype, stim},1);

                
                ax1 = subplot(3, numel(stimNames),stim);
                % Hold on to plot multiple bars
                
                hold(ax1, 'on');
%                 plot([-1,  binEdgesX, 1], meanSup, 'LineStyle', '-', 'Color', colors{genotype}, 'LineWidth', 2);
% 
%                 MPlot.ErrorShade([-1,  binEdgesX, 1], meanSup, stdSup, 'IsRelative', true, 'color', colors{genotype}, 'Alpha', 0.3);
% 
                plot(x, meanSup, 'LineStyle', '-', 'Color', colors{genotype}, 'LineWidth', 2);

                MPlot.ErrorShade(x, meanSup, ciSup(2,:)-meanSup, meanSup-ciSup(1,:), 'IsRelative', true, 'color', colors{genotype}, 'Alpha', 0.3);
            
                if genotype ==2        
                    set(gca, 'FontSize', 24);
                    xlim([-1.2,1.2]);        
                    ylim([0,ylim2(win)]);     
                    title(stimNames{stim});    
%                     legend({'KO', 'WT'});
                end
                hold(ax1, 'off');

                ax2 = subplot(3, numel(stimNames),stim + numel(stimNames));
                hold(ax2, 'on');
%                 plot([-1,  binEdgesX, 1], meanDeep, 'LineStyle', '-', 'Color', colors{genotype}, 'LineWidth', 2);
% 
%                 MPlot.ErrorShade([-1,  binEdgesX, 1], meanDeep, stdDeep, 'IsRelative', true, 'color', colors{genotype}, 'Alpha', 0.3);
%                 
                plot(x, meanFour, 'LineStyle', '-', 'Color', colors{genotype}, 'LineWidth', 2);

                MPlot.ErrorShade(x, meanFour, ciFour(2,:), ciFour(1,:), 'IsRelative', true, 'color', colors{genotype}, 'Alpha', 0.3);
            
                if genotype ==2        
                    set(gca, 'FontSize', 24);
                    xlim([-1.2,1.2]);        
                    ylim([0,ylim2(win)]);
%                     title('Deep');    
%                     legend({'KO', 'WT'});
                 end
                hold(ax2, 'off');  

                ax3 = subplot(3, numel(stimNames),stim + 2*numel(stimNames));
                hold(ax3, 'on');
%                 plot([-1,  binEdgesX, 1], meanDeep, 'LineStyle', '-', 'Color', colors{genotype}, 'LineWidth', 2);
% 
%                 MPlot.ErrorShade([-1,  binEdgesX, 1], meanDeep, stdDeep, 'IsRelative', true, 'color', colors{genotype}, 'Alpha', 0.3);
%                 
                plot(x, meanDeep, 'LineStyle', '-', 'Color', colors{genotype}, 'LineWidth', 2);

                MPlot.ErrorShade(x, meanDeep, ciDeep(2,:), ciDeep(1,:), 'IsRelative', true, 'color', colors{genotype}, 'Alpha', 0.3);
            
                if genotype ==2        
                    set(gca, 'FontSize', 24);
                    xlim([-1.2,1.2]);        
                    ylim([0,ylim2(win)]);
%                     title('Deep');    
%                     legend({'KO', 'WT'});
                 end
                hold(ax3, 'off');             
                
            end
            
       end
       sgtitle(ops.WindowNames{win})
        hold off
        savefig(g,fullfile(savePath,  [' depth cbias histogram line.fig']));
        saveas(g,fullfile(savePath,  [' depth cbias histogram line.png']));

    end                
          




        
end

function CBiasDepthHistoLinefinal(ops, metadataTable,nboot, LTwoThree, LFour)
        % just average and std histogram over each animal's distribution
     close all   
     % L1, 128 ± 1 μm; L2, 269 ± 2 μm; L3, 418 ± 3 μm; L4, 588 ± 3 μm; L5A, 708 ± 4 μm; L5B, 890 ± 5 μm; L6, 1154 ± 7 μm.
    % just signify according to allpvals
   
    depthTable = metadataTable.UnitDepth;   
    cbiasTable = metadataTable.cbias;
    pvalTable = metadataTable.pvalBoth;
    animalIds = unique(metadataTable.Properties.RowNames);
    genotypes = metadataTable.genotype;
    uGenotype = unique(genotypes);
    windows = ops.WindowNames;
    stimNames ={'10hz', '20hz', '40hz'};
    
    ylim2 = [100, 100, 100, 100, 100, 100, 100, 100];
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
                            
                            unitDepth = cell2mat(table2cell(depthSess(:,stim))) - 50/1154;
                            
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
               HFourReal{genotype, stim} = [];
               genData = [];
                
               for ani = 1: numel(depthFinalreal{genotype, stim})
                    if isempty(cbiasFinalreal{genotype,stim}{ani})
                        continue;
                    end
                    data = [cbiasFinalreal{genotype,stim}{ani}', depthFinalreal{genotype,stim}{ani}'];
                    
                    data(isnan(data(:,1)),:)=[];
                    genData = [genData; data];
                    
                    lowerBounds = [LTwoThree, LFour,max(max(data(:,2)), 1)];
                    upperBounds = [min(min(data(:,2)),0),LTwoThree, LFour];
                    
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
                    HFourReal{genotype, stim}(ani, :) = H(:,2)'/sum(H(:,2))*100;
                    HDeepReal{genotype, stim}(ani, :) = H(:,3)'/sum(H(:,3))*100;

               end

               
                dataSup = genData(genData(:,2)<=LTwoThree & genData(:,2)>=min(min(genData(:,2)),0),:);
                numUnitsS = height(dataSup);
    
                dataLfour = genData(genData(:,2)<=LFour & genData(:,2)>LTwoThree,:);
                numUnitsF = height(dataLfour);
                
                dataDeep = genData(genData(:,2)>LFour & genData(:,2)<=max(max(genData(:,2)),1),:);
                numUnitsD = height(dataDeep);

                HSup{genotype, stim} = [];
                HFour{genotype, stim} =[];
                HDeep{genotype, stim} =[];
                rng(7);
                for boot = 1:nboot
                        
                    unitsTotake = datasample(1:numUnitsS, numUnitsS, 'Replace', true);                        
                    dataBootS = dataSup(unitsTotake,:);

                    unitsTotake = datasample(1:numUnitsF, numUnitsF, 'Replace', true);                        
                    dataBootF = dataLfour(unitsTotake,:);

            
                    unitsTotake = datasample(1:numUnitsD, numUnitsD, 'Replace', true);                        
                    dataBootD = dataDeep(unitsTotake,:);
                    
                    binsX =-1:2/ops.parts:1;
                    lowerBounds = binsX(1:end-1);
                    upperBounds = binsX(2:end);
                    binEdgesX = upperBounds + (lowerBounds-upperBounds)/2;
                   
                    
                    sup = hist(dataBootS(:,1), ...
                        binEdgesX);
                    HSup{genotype, stim}(boot, :) = [0, sup/sum(sup), 0]*100;
                    lfour = hist(dataBootF(:,1), ...
                        binEdgesX);
                    HFour{genotype, stim}(boot, :) = [0, lfour/sum(lfour), 0]*100;

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
                    HFourReal{genotype, stim}(isnan(HFourReal{genotype, stim}(:,2)),:)=[];
                    
                    % remove animals with no units i.e. sum <<100
                    HFourReal{genotype, stim}(sum(HFourReal{genotype, stim},2)<90,:) =[];
    
                  
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

        H = {HSupReal, HFourReal, HDeepReal};
        layers = {'Sup', 'L4', 'Deep'};
        for layer = 1:numel(H)
            Hlayer = H{layer};
           for stim = 2
                responseType = {};
                genotypes = {};
                percentageArray = [];
                currentPercentages = [];
                for genotype =1:height(depthFinal)
                    % for each genotype get the 

                    

                    mouseNums = height(Hlayer{genotype, stim});
                    repeatedGenos = repmat(uGenotype(genotype), mouseNums*numel(responseArray), 1);
                    genotypes(end+1:end+height(repeatedGenos),1) = repeatedGenos;
                            
                    repeatedRTypes = repmat(responseArray, mouseNums, 1);
                    rTypes  = repeatedRTypes(:);
                    responseType(end+1:end+height(rTypes),1) = rTypes;
                    
                    percentVals = Hlayer{genotype, stim}(:);
                    percentageArray(end+1:end+height(percentVals),1) = percentVals;
                    
                    %Statistics across response type for each genotype
                    currentPercentages = Hlayer{genotype, stim};
    
                    % Friedman Test
                    [p, tbl, stats] = kruskalwallis(currentPercentages, responseArray);
                    fprintf(fileID, [layers{layer} ' MouseNums: ' num2str(mouseNums) ' for Genotype: ' uGenotype{genotype} '\n']);

                    fprintf(fileID, [layers{layer} ' kruskal-wallis test across responseTypes for Genotype: ' uGenotype{genotype} '\n']);
                    fprintf(fileID, 'kruskal p-value: %.4f\n', p);

                    results = multcompare(stats, 'CType', 'dunn-sidak');
                    for response = 1:numel(responseArray)
                        group1 = responseArray{results(response, 1)};
                        group2 = responseArray{results(response, 2)};
                        pValue = results(response, 6);
                        fprintf(fileID, 'Comparison between %s and %s: p = %.4f\n', group1, group2, pValue);
                    end
                end



            end
        end
        

      
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
                    
    
                    % Friedman Test
                    [p, tbl, stats] = kruskalwallis(percentageArray, uGenotype);
                    
                    fprintf(fileID, [layers{layer} ' kruskal-wallis test across Genotypes for same responsetype: ' responseArray{response} '\n']);
                    fprintf(fileID, 'kruskal p-value: %.4f\n', p);
                  
                    
                end



            end
        end

        % Close the file
        fclose(fileID);
        close all;
        
        g = figure(win); clf;
        set(g, 'Units', 'inches', 'Position', [1,1,5,3]);
        hold on
        for stim =1:numel(stimNames)
           
            for genotype =1:height(depthFinal)
               
               x = -1:2/(ops.parts-1):1;


                meanSup = mean(HSupReal{genotype, stim},1);
                stdSup = std(HSupReal{genotype, stim},1);

          
                meanFour = mean(HFourReal{genotype, stim},1);
                stdFour = std(HFourReal{genotype, stim},1);

              
                meanDeep = mean(HDeepReal{genotype, stim},1);
                stdDeep = std(HDeepReal{genotype, stim},1);

                
                ax1 = subplot(3, numel(stimNames),stim);
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
                       
%                         scatter(xplot, 110*ones(1,numel(xplot)), 15, 'k', '*');
                    end
                    
                    set(gca, 'FontSize', 6, 'Linewidth', 1, 'xticklabels', [], 'TickDir', 'out');
                    ax1.XTick = x;
                    xlim([-1.2,1.2]);        
                    ylim([0-20,ylim2(win)+20]);     
%                     title(stimNames{stim});    
%                     legend({'KO', 'WT'});
                end
                hold(ax1, 'off');

                ax2 = subplot(3, numel(stimNames),stim + numel(stimNames));
                hold(ax2, 'on');

                try
                    errorbar(x+(genotype-1)*0.05, meanFour, stdFour, 'color', colors{genotype}, 'LineWidth', 1);
                catch
                end

                if genotype ==2        
                     HFourstat = [];
              
                    for parts = 1: ops.parts
                        HFourstat(parts)= ranksum(HFourReal{1,stim}(:,parts),HFourReal{2,stim}(:,parts));                
                    end
                    xplot = x(HFourstat < 0.05);    
                    
                    if ~isempty(xplot)
                       
%                         scatter(xplot, 110*ones(1,numel(xplot)), 15, 'k', '*');
                    end

                    set(gca, 'FontSize', 6, 'Linewidth', 1, 'xticklabels', [], 'TickDir', 'out');
                    ax2.XTick = x;
                    xlim([-1.2,1.2]);        
                    ylim([0-20,ylim2(win)+20]);
%                     title('Deep');    
%                     legend({'KO', 'WT'});
                end
                hold(ax2, 'off');    

                ax3 = subplot(3, numel(stimNames),stim + 2*numel(stimNames));
                hold(ax3, 'on');

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
                       
%                         scatter(xplot, 110*ones(1,numel(xplot)), 15, 'k', '*');
                    end

                    set(gca, 'FontSize', 6, 'Linewidth', 1, 'TickDir', 'out');
                    
                    ax3.XTick = x;
                    ax3.XTickLabel = {'Ipsilateral', 'Bilateral', 'Contralateral'};
                    ax3.XTickLabelRotation =45;
                    xlim([-1.2,1.2]);   

                    ylim([0-20,ylim2(win)+20]);
%                     title('Deep');    
%                     legend({'KO', 'WT'});
                end
                hold(ax3, 'off');             
                
            end
            
       
             

                
        end
%         sgtitle(ops.WindowNames{win} )
        hold off
        savefig(g,fullfile(savePath,  [' depth cbias histogram line.fig']));
        saveas(g,fullfile(savePath,  [' depth cbias histogram line.png']));

    end                
          




        
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
                    cBiasSess = cBiasSess(sigUnits,:);
                    pvalIpsiSess = pvalIpsiSess(sigUnits,:);
                    pvalContraSess = pvalContraSess(sigUnits,:);


                    responsiveIdentity = zeros(height(cBiasSess), 1);
                    contraOnlyUnits = find(pvalContraSess<ops.plotAlpha & pvalIpsiSess>ops.plotAlpha);
                    ipsiOnlyUnits = find(pvalContraSess>ops.plotAlpha & pvalIpsiSess<ops.plotAlpha);
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
            respIDs = respIDs + 1;
        
            cmapResp = [[0 0 1]; [1 1 1]; [1 0 0]];
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
%        maxFR = 100;

      
            % plot data
           g = figure(genotype); clf;
           set(g, 'Units', 'inches', 'Position', [1, 1, 1.6, 2]);
           s(1) = subplot(1,21, 1:10, 'Parent', g);
           imagesc(FRAll.Time{1}, 1:height(FRContra), FRContra);
           
           line([0, 0], [1, height(FRContra)], 'Color', 'k', 'LineStyle', '--', 'Linewidth', 1); % Stimulus onset
           yTicks = 20:20:max(height(FRContra)) ;
           xlim(ops.plotxLims)
            set(s(1), 'Units', 'inches', 'Position', [0.24, 0.2, 0.45, 1.75], 'FontSize', 6, 'FontName', 'Arial', ...
                'Ytick', yTicks, 'TickDir', 'out',  'LineWidth', 1);            
            s(1).YTickLabel{1} = '';
           % Create custom colormap: black to red
            numColors = 256; % Number of colors in the colormap
            customColormap = [ones(numColors, 1), 1-linspace(0, 1, numColors)', 1-linspace(0, 1, numColors)'];        
    
            % Apply the custom colormap
            colormap(gca, customColormap);
            if strcmp(uGenotypes{genotype}, 'WT')
                
                h(1) = colorbar;
                caxis([0 maxFR]);
                set(h(1), 'Units', 'inches', 'Position', [0.12, 1.55, 0.08, 0.4]);
                h(1).Color = [0 0 0];
                h(1).LineWidth = 0.5;
                h(1).TickLabels(2) = {''};
            end
    
            
    
            
            
           s(2)= subplot(1,21, 11:20, 'Parent', g);       
           imagesc(FRAll.Time{1}, 1:height(FRIpsi), FRIpsi);
           line([0, 0], [1, height(FRContra)], 'Color', 'k', 'LineStyle', '--', 'Linewidth', 1); % Stimulus onset
           xlim(ops.plotxLims)
           set(s(2), 'Units', 'inches', 'Position', [0.95, 0.2, 0.45, 1.75], 'FontSize', 6, 'FontName', 'Arial', 'Ytick', yTicks, 'TickDir', 'out', ...
                    'YTickLabel', [], 'LineWidth', 1);
            s(2).YTickLabel{1} = '';
    
            % Create custom colormap: black to red
            numColors = 256; % Number of colors in the colormap
            customColormap = [1-linspace(0, 1, numColors)', 1-linspace(0, 1, numColors)', ones(numColors, 1)];
    
            % Apply the custom colormap
            colormap(gca, customColormap);
            if strcmp(uGenotypes{genotype}, 'WT')
                h(2) = colorbar;
                caxis([0 maxFR]);
                set(h(2), 'Units', 'inches', 'Position', [0.83, 1.55, 0.08, 0.4]);
                h(2).Color = [0 0 0];
                h(2).LineWidth = 0.5;
                h(2).TickLabels(2) = {''};
            end
          
    
           s(3)= subplot(1,21, 21, 'Parent', g);       
           imagesc(respIDs);
           colormap(s(3), cmapResp); 
            set(s(3), 'Units', 'inches', 'Position', [1.45, 0.2, 0.05, 1.75], 'FontSize', 6, 'FontName', 'Arial', 'Xtick', [], 'Ytick', [], 'TickDir', 'out', ...
                    'YTickLabel', [], 'LineWidth', 1);
            
          if withLabels
            exportgraphics(g, fullfile(ops.savePath, ['Stim ' uFreq{stim} ' Average FR heatmap labels ' uGenotypes{genotype} '.tiff']), 'Resolution', 1200);
          else

            savefig(g,fullfile(ops.savePath, ['Stim ' uFreq{stim} ' Average FR heatmap ' uGenotypes{genotype} '.fig']));
            exportgraphics(g, fullfile(ops.savePath, ['Stim ' uFreq{stim} ' Average FR heatmap ' uGenotypes{genotype} '.tiff']), 'Resolution', 1200);
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

                cBiasSess = cBiasSess(sigUnits,:);
                pvalIpsiSess = pvalIpsiSess(sigUnits,:);
                pvalContraSess = pvalContraSess(sigUnits,:);
                responsiveIdentity = zeros(height(cBiasSess), 1);
                contraOnlyUnits = find(pvalContraSess<ops.plotAlpha & pvalIpsiSess>ops.plotAlpha);
                ipsiOnlyUnits = find(pvalContraSess>ops.plotAlpha & pvalIpsiSess<ops.plotAlpha);
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
                disp([uGenotypes{genotype} ': contra till: ' num2str(respBounds(1)) ' Ipsi from: ' num2str(respBounds(2)) ]); 
            else
                disp([uGenotypes{genotype} ': contra till: ' num2str(respBounds(1)) ' Ipsi from: ' num2str(ipsibounds(1)) ]); 
            end

       elseif strcmp(uGenotypes{genotype}, 'WT')
            if isempty(ipsibounds)
%                 disp([uGenotypes{genotype} ': contra till: ' num2str(respBounds(1)) ' Bilat from: ' num2str(respBounds(1)+1) ]); 
                disp([uGenotypes{genotype} ': contra till: ' num2str(respBounds(1)) ' Bilat from: ' num2str(respBounds(2)) ]); 
            else
                disp([uGenotypes{genotype} ': contra till: ' num2str(respBounds(1)) ' Ipsi from: ' num2str(respBounds(1)+1) ]); 
            end
       end

       maxFR = max([FRContra; FRIpsi], [], 'All');
%        maxFR = 100;

   
  
       % plot data
       g = figure(genotype); clf;
       set(g, 'Units', 'inches', 'Position', [1, 1, 1.6, 2]);
       s(1) = subplot(1,21, 1:10, 'Parent', g);
       imagesc(FRAll.Time{1}, 1:height(FRContra), FRContra);
       
       line([0, 0], [1, height(FRContra)], 'Color', 'k', 'LineStyle', '--', 'Linewidth', 1); % Stimulus onset
       yTicks = 20:20:max(height(FRContra)) ;
       xlim(ops.plotxLims)
        set(s(1), 'Units', 'inches', 'Position', [0.24, 0.2, 0.45, 1.75], 'FontSize', 6, 'FontName', 'Arial', ...
            'Ytick', yTicks, 'TickDir', 'out',  'LineWidth', 1);            
        s(1).YTickLabel{1} = '';
       % Create custom colormap: black to red
        numColors = 256; % Number of colors in the colormap
        customColormap = [ones(numColors, 1), 1-linspace(0, 1, numColors)', 1-linspace(0, 1, numColors)'];        

        % Apply the custom colormap
        colormap(gca, customColormap);
        if strcmp(uGenotypes{genotype}, 'WT')
            
            h(1) = colorbar;
            caxis([0 maxFR]);
            set(h(1), 'Units', 'inches', 'Position', [0.12, 1.55, 0.08, 0.4]);
            h(1).Color = [0 0 0];
            h(1).LineWidth = 0.5;
            h(1).TickLabels(2) = {''};
        end

        

        
        
       s(2)= subplot(1,21, 11:20, 'Parent', g);       
       imagesc(FRAll.Time{1}, 1:height(FRIpsi), FRIpsi);
       line([0, 0], [1, height(FRContra)], 'Color', 'k', 'LineStyle', '--', 'Linewidth', 1); % Stimulus onset
       xlim(ops.plotxLims)
       set(s(2), 'Units', 'inches', 'Position', [0.95, 0.2, 0.45, 1.75], 'FontSize', 6, 'FontName', 'Arial', 'Ytick', yTicks, 'TickDir', 'out', ...
                'YTickLabel', [], 'LineWidth', 1);
        s(2).YTickLabel{1} = '';

        % Create custom colormap: black to red
        numColors = 256; % Number of colors in the colormap
        customColormap = [1-linspace(0, 1, numColors)', 1-linspace(0, 1, numColors)', ones(numColors, 1)];

        % Apply the custom colormap
        colormap(gca, customColormap);
        if strcmp(uGenotypes{genotype}, 'WT')
            h(2) = colorbar;
            caxis([0 maxFR]);
            set(h(2), 'Units', 'inches', 'Position', [0.83, 1.55, 0.08, 0.4]);
            h(2).Color = [0 0 0];
            h(2).LineWidth = 0.5;
            h(2).TickLabels(2) = {''};
        end
      

       s(3)= subplot(1,21, 21, 'Parent', g);       
       imagesc(respIDs);
       colormap(s(3), cmapResp); 
        set(s(3), 'Units', 'inches', 'Position', [1.45, 0.2, 0.05, 1.75], 'FontSize', 6, 'FontName', 'Arial', 'Xtick', [], 'Ytick', [], 'TickDir', 'out', ...
                'YTickLabel', [], 'LineWidth', 1);
        
      if withLabels
        exportgraphics(g, fullfile(ops.savePath, ['All freq Average FR heatmap labels ' uGenotypes{genotype} '.tiff']), 'Resolution', '1200');
      else

        savefig(g,fullfile(ops.savePath, ['All freq Average FR heatmap ' uGenotypes{genotype} '.fig']));
        exportgraphics(g, fullfile(ops.savePath, ['All freq Average FR heatmap ' uGenotypes{genotype} '.tiff']), 'Resolution', '1200');
      end
        


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