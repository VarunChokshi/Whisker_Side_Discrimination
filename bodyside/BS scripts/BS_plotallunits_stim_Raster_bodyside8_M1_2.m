


%% Plot units separated by whisker stim duration. Contra vs ipsi, combine for left vs right hemisphere recording . combine plotsession_maps
% It also has LFPs
% Stims are taken as only the first deflection of all frequencies 
% clear all
% 
% [readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\StimSEs', 'Select source SEs');

clear all
animalID = {'VC030209', 'VC030208','VC030113', 'VC030211', 'VC030114', 'VC030115', 'VC030213'};
% animalID = {'VC030213'};
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


%% Add channel coords where kcoords are the shank #

% load histology_wM1
histTable = readtable('G:\VC03_RoboKO\EphysPassiveStimSEs\Histology\Histology_wM1.csv');


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


parfor i = 1:height(dataFileTb)    
    animalName = dataFileTb.animalId{i};
    sessID = [datestr(dataFileTb.sessionDatetime(i), 'yymmdd') dataFileTb.subId{i}];
    sessNum = find(ismember(histTable.AnimalName,animalName) & ismember(histTable.SessDate,sessID));
    save_folder = fullfile('G:\VC03_RoboKO\EphysPassiveStimSEs\Histology', animalName, 'wM1_16x\Processed');
    % find animal and session in the histology table

    object_save_name_suffix = ['NP24_' histTable.ProbeSuffix{sessNum}];
    probeFilePath = fullfile(save_folder, ['probe_points' object_save_name_suffix '.mat']);
    probeFile = fullfile(save_folder, ['probe_points' object_save_name_suffix]);

    


    % load probe points
    if isfile(probeFilePath)
       % load se    
        se{i} = loadsess(dataFileTb.sePath{i}); 
        
        
        
      
        
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
%             plot3(m(1)+p(1)*(unit_ycoord), m(3)+p(3)*(unit_ycoord), m(2)+p(2)*(unit_ycoord), ...
%             'w.', 'LineWidth', 1);
             plot3(bregma(1) - unitEucl(1), bregma(3) + unitEucl(3),bregma(2) + unitEucl(2), ...
            'w.', 'LineWidth', 1);
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
ops.tWins = [-1.5, 1.5];
animalIds = unique(dataFileTb.animalId);
ops.folderSigma = [strrep(['StatAlpha ' num2str(0.005)], '.', '_') ' numcyc=' num2str(ops.numcyc)];
% windowSize = 0.15; %in seconds 

% ops.stimDurs = {'150','100','050','020','010','005'}; %in ms

% ops.stimDurs = {'150'}; %in ms
ops.universalWindow =1;
if ops.universalWindow
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\firstcyc',[strjoin(animalIds, '_') '_NP\AllUnitswM1',FRbin], [' UniveralWindow selective ' num2str(ops.constantWindow*1000) 'ms']);
else
    ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\firstcyc',[strjoin(animalIds, '_') '_NP\AllUnitswM1',FRbin], [num2str(0.005) ' numcyc=' num2str(ops.numcyc) 'paired selective']);
end




%% Make variables for raster FR rate, etc
Getcompositevars(dataFileTb, ops);


%% plot Rasters
 MakeFigures(fullfile(ops.savePath, "allVars.mat"), ops.plotAlpha);

 %%  
 MakeFiguresNoannotation(fullfile(ops.savePath, "allVars.mat"), ops.plotAlpha,ops.savePath);
 %% Calculate sig units for each GT and then do binomial test. 
 BinomialIpsiResponsive(fullfile(ops.savePath, "allVars.mat"), ops.plotAlpha,ops.savePath);

%% Calculate sig units for each GT and then do binomial test. 
ops.binWidth = 0.0025;
IpsiresponsiveLatencies(fullfile(ops.savePath, "allVars.mat"), ops.plotAlpha,ops.savePath, ops.binWidth);

 %% Plot Cbiastable
MakeCbiasFigures(fullfile(ops.savePath, "allVars.mat"), ops.binWidth, ops.plotAlpha);


%% PLot histo
PlotHisto(fullfile(ops.savePath, "allVars.mat"),ops.plotAlpha, ops.savePath, ops.binWidth);

%% Plot #of ipsiresponsive with windows
windows = [0.075,0.1,0.15,0.2,0.3];
wCell = cell(1,numel(windows)*2);
stims = {'10 hz', '20 hz', '40 hz'};
ufreq = [10,20,40];
for i = 1:numel(windows)
    ind = 2*i-1;
    wCell{1,ind+1} = [num2str(windows(i)*1000) ' Total'];
    wCell{1,ind} = [num2str(windows(i)*1000) ' Ipsi'];
end

for allpvals =0:1
    VariablesNames = {'KO 10', 'KO 20', 'KO 40', 'WT 10', 'WT 20', 'WT 40'};
    RowNames = wCell;
    ipsiFrac = cell(numel(RowNames), numel(VariablesNames));
%     dataTb = table('VariableNames', VariablesNames, 'RowNames', RowNames);

   

    for i = 1:numel(windows)
        ind = 2*i-1;
        ops.constantWindow = windows(i);
        
        ops.universalWindow =1;
        if ops.universalWindow
            ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\firstcyc',[strjoin(animalIds, '_') '_NP\AllUnitswM1',FRbin], [' UniveralWindow selective ' num2str(ops.constantWindow*1000) 'ms']);
        else
            ops.savePath = fullfile(groupDir,'Figures\Bodyside8\ContraIpsi\firstcyc',[strjoin(animalIds, '_') '_NP\AllUnitswM1',FRbin], [num2str(0.005) ' numcyc=' num2str(ops.numcyc) 'paired selective']);
        end
        saveVar = fullfile( ops.savePath,['allPvals = ' num2str(allpvals) ' IpsiResponseBinomial.mat']);

        load(saveVar);
        if allpvals
            ipsiFrac(ind,1:3) = num2cell(ipsiFracTable{1,"IpsiSigUnits"});
            ipsiFrac(ind,4:6) = num2cell(ipsiFracTable{2,"IpsiSigUnits"});
            ipsiFrac(ind+1,1:3) = ipsiFracTable{1,"TotalSigUnits"}(1);
            ipsiFrac(ind+1,4:6) = ipsiFracTable{2,"TotalSigUnits"}(1);
        else
            ipsiFrac(ind,1:3) = ipsiFracTable{1,"ipsiUnitNum"}(1:3);
            ipsiFrac(ind,4:6) = ipsiFracTable{2,"ipsiUnitNum"}(1:3);
            ipsiFrac(ind+1,1:3) = ipsiFracTable{1,"TotalSigUnits"}(1:3);
            ipsiFrac(ind+1,4:6) = ipsiFracTable{2,"TotalSigUnits"}(1:3);
        end
    end
    dataTb = cell2table(ipsiFrac, 'RowNames', RowNames, 'VariableNames', VariablesNames);

    % plot for each pVals
    g1 = figure(3*(allpvals+1)-2); clf;
    g1.WindowState='Maximized';
    g2 = figure(3*(allpvals+1)-1); clf;
    g2.WindowState='Maximized';
    g3 = figure(3*(allpvals+1)); clf;
    g3.WindowState='Maximized';
    for stim = 1:numel(stims)
        figure(g1)
        h1 = subplot(3,1, stim, 'Parent', g1);
        hold(h1, 'on')
        plot(windows'*1000, [ipsiFrac{[1:2:2*numel(windows)-1],stim}],'-o', 'color', [1 0 0]);
        plot(windows*1000, [ipsiFrac{[1:2:2*numel(windows)-1],stim+3}],'-o', 'color', [0 0 0]); 
        title(stims{stim});
        xlim([0,max(windows)*1000+25])    
        ylims = ylim;
    
        MPlot.Blocks([0,1000/ufreq(stim)*3], [0,ylims(2)],[0 0.8 1.0], 'FaceAlpha', 0.3);
        ylim([0,ylims(2)]);
        xticks(windows*1000)
        legend({'KO',  'WT'})  
        xlabel('Window time (ms)');
        ylabel('# of ipsi units');
        hold(h1, 'off')

        figure(g2)
        h2 = subplot(3,1, stim, 'Parent', g2);
        hold(h2, 'on')
        plot(windows*1000, [ipsiFrac{[2:2:2*numel(windows)],stim}],'-o', 'color', [1 0 0]);
        plot(windows*1000, [ipsiFrac{[2:2:2*numel(windows)],stim+3}],'-o', 'color', [0 0 0]);
        title(stims{stim});
        xlim([0,max(windows)*1000+25])        
        ylims = ylim;
        MPlot.Blocks([0,1000/ufreq(stim)*3], [0,ylims(2)],[0 0.8 1.0], 'FaceAlpha', 0.3);
        ylim([0,ylims(2)]);
        xticks(windows*1000)
        legend({'KO',  'WT'})  
        xlabel('Window time (ms)');
        ylabel('# of total units');
        hold(h2, 'off')   


        figure(g3)
        figure(g3)
        h3 = subplot(3,1, stim, 'Parent', g3);
        hold(h3, 'on')
        plot(windows'*1000, [ipsiFrac{[1:2:2*numel(windows)-1],stim}]./ [ipsiFrac{[2:2:2*numel(windows)],stim}],'-o', 'color', [1 0 0]);
        plot(windows*1000, [ipsiFrac{[1:2:2*numel(windows)-1],stim+3}]./[ipsiFrac{[2:2:2*numel(windows)],stim+3}],'-o', 'color', [0 0 0]); 
        title(stims{stim});
        xlim([0,max(windows)*1000+25])    
        ylims = ylim;
        
        MPlot.Blocks([0,1000/ufreq(stim)*3], [0,ylims(2)],[0 0.8 1.0], 'FaceAlpha', 0.3);
        ylim([0,ylims(2)]);
        xticks(windows*1000)
        legend({'KO',  'WT'})  
        xlabel('Window time (ms)');
        ylabel('Ipsi resp fraction');
        hold(h3, 'off')



    end

    
    savefig(g1, fullfile( ops.savePath,['allPvals = ' num2str(allpvals) ' IpsiUnitnums.fig']));
    savefig(g2, fullfile( ops.savePath,['allPvals = ' num2str(allpvals) ' TotalUnitnums.fig']));
    savefig(g3, fullfile( ops.savePath,['allPvals = ' num2str(allpvals) ' FracIpsi.fig']));
    saveas(g1, fullfile( ops.savePath,['allPvals = ' num2str(allpvals) ' IpsiUnitnums.png']));
    saveas(g2, fullfile( ops.savePath,['allPvals = ' num2str(allpvals) ' TotalUnitnums.png']));
    saveas(g3, fullfile( ops.savePath,['allPvals = ' num2str(allpvals) ' FracIpsi.png']));

end



 %% Plot LFPs intan

%  ops.savePath = [ops.savePath ' Normalized'];
normalized = '';
multiplier = 100;
MakeLFPs(fullfile(ops.savePath, "allVars.mat"), normalized, multiplier);
    
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
       
        ap = allHisto{unitNum, 'AP_location'};
        dv = allHisto{unitNum, 'DV_location'};
        ml = -abs(allHisto{unitNum, 'ML_location'});
        unitEucl = [ap dv ml]/atlas_resolution;
        
        figure(fwireframe)
        hold on
        plot3(bregma(1) - unitEucl(1), bregma(3) + unitEucl(3),bregma(2) + unitEucl(2), ...
        'Marker', marker, 'color' , colorgen, 'MarkerSize', 10);           

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


function Getcompositevars(dataFileTb, ops)
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
    
    uniAnimalId = unique(animalID);
    uRecSites = unique(dataFileTb.recSite);
    
    
    
    recSites = dataFileTb.recSite;
    readPaths= dataFileTb.sePath;
    uGenotypes = unique(dataFileTb.Genotype);
    genotypes = dataFileTb.Genotype;
    

    bins = tWins(1):binSize:tWins(2);

    %
    for genotype = 1:numel(uGenotypes)
        for recSite = 1:numel(inputrecSites)
            
            recSitePaths = cell2mat(cellfun(@(x) sum(ismember(x, inputrecSites{recSite}))==2, recSites, 'UniformOutput',false));
            recReadPaths = readPaths(recSitePaths & strcmp(uGenotypes(genotype), genotypes));
            if ~universalWindow
                numcyc = ops.numcyc;
            else
                uniWin = ops.constantWindow;
            end
            
%             if ~exist([savePath '\allVars' uGenotypes{genotype} inputrecSites{recSite} '.mat'], 'file') || redo
                
            if ~isempty(recReadPaths)
                
                
                close all; 

                allSpikeTimes{genotype}{recSite} = cell(1,12);
                pvals{genotype}{recSite} = cell(1,12);
                adcFinal{genotype}{recSite} = cell(1,12);
                bodysidefinal{genotype}{recSite}=cell(1,12);
                Cbiastable{genotype}{recSite} = cell(1,12);
                allMeanFR{genotype}{recSite} = cell(1,12);
                LFPFinal{genotype}{recSite} = cell(1,numel(recReadPaths));
                sessInfoFinal{genotype}{recSite} = cell(1,numel(recReadPaths));
                histoInfoFinal{genotype}{recSite} =cell(1,4);
                for sessNum = 1:numel(recReadPaths)


                    load(recReadPaths{sessNum});
                    sessRecSite = cell2mat(se.userData.sessionInfo.recSite);
                    
                    
                    
                    
                
                    fprintf('%s\n\n', recReadPaths{sessNum});
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
                   
                     % get LFPAll
                     LFPData = 1;
                     try
                        LFPAll = se.SliceTimeSeries('LFP', tWins, 'Fill', 'bleed');
                        
                        tWin_baseline = [tWins(1) 0];
                        sampleRate = 1/diff(LFPAll.time{1,1}(1:2));

                        
                        LFPAll = LFPAll(trialInd,:);
                        LFPAll(1,:) = [];
                        LFPAllTime = LFPAll.time;
                        LFPAll(:,1) = []; 
                        LFPAll = table2cell(LFPAll);
                        LFPAll = cellfun(@(x) x', LFPAll, 'UniformOutput', false);

                        LFP_baseline = se.SliceTimeSeries('LFP', tWin_baseline, 'Fill', 'bleed');
                        LFP_baseline = LFP_baseline(trialInd,:);
                        LFP_baseline(1,:) = [];
                        LFP_baseline(:,1) = []; 
                        LFP_baseline = table2cell(LFP_baseline);
                        LFP_baseline = cellfun(@(x) x', LFP_baseline, 'UniformOutput', false);
                        
%                         LFP_normalized = LFPAll;

                        LFP_normalized =[];
                       
                        for channel=1:64
                            LFP_baseline_mean(channel) = mean(cell2mat(LFP_baseline(:,channel)),'all');
                            LFP_baseline_std(channel) = std(cell2mat(LFP_baseline(:,channel)), 0,'all');
                            new_LFP_normalized = cellfun(@(x) (x-LFP_baseline_mean(channel))./LFP_baseline_std(channel), LFPAll(:,channel) ,'UniformOutput',false);
                            LFP_normalized = [LFP_normalized new_LFP_normalized];
                        end

                        

                        % filter LFP between 0.1hz and 100 hz
                        bandpass_freq = [0.1 100]; % in Hz
                        Wn = bandpass_freq/(sampleRate/2);
                        [b,a] = butter(3,Wn, 'bandpass');
                        
                        LFP2 = cellfun(@(x) double(x), LFP_normalized, 'UniformOutput', false);
                        LFP_filtered = cellfun(@(x) filtfilt(b,a, x), LFP2, 'UniformOutput', false);

                     catch
                         LFPData = 0;
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
                    
                    stimTypes = leftStimTypes;
                    uStimTypes = unique(stimTypes);
                    ufreq = unique(cellfun(@(x) x(5:6),uStimTypes, 'UniformOutput', false)); % for gettign just the unique frequencies irrespective of the cycles
                    
                    
                    adc = cell(1,numel(ufreq));
                    lfp = cell(1,numel(ufreq));

                    sessInfoTable = se.userData.sessionInfo;
                    sessInfoFinal{genotype}{recSite}{sessNum} =  se.userData.sessionInfo;
                    if ismember('penetrationDepth', sessInfoTable.Properties.VariableNames)
                        penetrationDepth = sessInfoTable.penetrationDepth;
                    else
                        penetrationDepth = defPenetrationDepth;
                    end
                    

                    % for all the stimDurs
                   for stimDur = 1:numel(ufreq)
                        
                         if numel(ufreq)<3
                            
                            pstimDur = stimDur +1;
                            bodyside7 =1;
                        else
                            bodyside7 =0;
                            pstimDur = stimDur;
                         end     
    
                      
                        
    %                     freq = str2num(uStimTypes{stimDur}(5:6));
    %                     cycs = str2num(uStimTypes{stimDur}(10));
    %                     windowSize{stimDur} = 1/freq * cycs;
                        %get FR for both trialType and current stimDue
    %                     windowSize{stimDur} = max(50/1000,str2num(stimDurs{stimDur})/1000); %in s 
    %                     windowSize{stimDur} = 50/1000;
                        if ~universalWindow
                            try 
                                windowSize{stimDur} = 1/str2double(ufreq{stimDur})*numcyc; %in s 
                            catch
                                windowSize{stimDur} = findDuration(uStimTypes{stimDur})*numcyc; %in s 
                            end
                        else
                            windowSize{stimDur} = ops.constantWindow;
                        end
                        

                        binsWin{stimDur} = find(bins>= -windowSize{stimDur} & bins<= windowSize{stimDur});
                        plotLims{stimDur} = [-windowSize{stimDur}, windowSize{stimDur}];
                        temp = binsWin{stimDur};
                        try
                            frAllwin{stimDur} = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                        catch                            
                            errorTrials = find(cell2mat(cellfun(@(x) numel(x)< temp(end), frAll(:,1), 'UniformOutput',false)));
                            behavData(errorTrials,:) =[];
                            frAll(errorTrials,:)=[];
                            spikeAll(errorTrials,:)=[];
                            frAllwin{stimDur} = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                        end

                        leftStimTypes = behavData.leftStimType;
                        rightStimTypes = behavData.rightStimType;

                       
                        
                        trials2keepL{stimDur} = find(strcmp(trials{1}{1}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(5:6),ufreq{stimDur}), ...
                            leftStimTypes, 'UniformOutput',false)));
                        trials2keepR{stimDur} = find(strcmp(trials{1}{2}, behavData.trialType) & cell2mat(cellfun(@(x) strcmp(x(5:6),ufreq{stimDur}), ...
                            rightStimTypes, 'UniformOutput',false)));
                        
                        FRLeft{stimDur} = frAllwin{stimDur}(trials2keepL{stimDur},2:end);
                        FRRight{stimDur} = frAllwin{stimDur}(trials2keepR{stimDur},2:end);
                        FRtime{stimDur} = frAllwin{stimDur}(trials2keepR{stimDur},1);
                        
                        %get p-value based on windowsize = stim duration                        
                        preWindow{stimDur} = 1:(round(numel(FRLeft{stimDur}{1})/2));
                        postWindow{stimDur} =  preWindow{stimDur}(end)+1: numel(FRLeft{stimDur}{1}); 
                        temp1 = preWindow{stimDur};
                        temp2 = postWindow{stimDur};
    
                        preMeanFRL{stimDur} = cell2mat(cellfun(@(x) mean(x(temp1)), FRLeft{stimDur}, 'UniformOutput', false));
                        postMeanFRL{stimDur} = cell2mat(cellfun(@(x) mean(x(temp2)), FRLeft{stimDur}, 'UniformOutput', false));
                        preMeanFRR{stimDur} = cell2mat(cellfun(@(x) mean(x(temp1)), FRRight{stimDur}, 'UniformOutput', false));
                        postMeanFRR{stimDur} = cell2mat(cellfun(@(x) mean(x(temp2)), FRRight{stimDur}, 'UniformOutput', false));
                        
                        % get spikeTimes for FRlims
                        FRlims{stimDur} = [tWins(1) tWins(2)];               
                        spikeLeft = spikeAll(trials2keepL{stimDur},1:end);
                        spikeRight = spikeAll(trials2keepR{stimDur},1:end);          
                        binsWin{stimDur} = find(bins>= FRlims{stimDur}(1) & bins<= FRlims{stimDur}(2));
                        temp = binsWin{stimDur}(1:end-1);
                        frAllplot{stimDur} = cellfun(@(x) x(temp), frAll,'UniformOutput',false);
                        FRLeft{stimDur} = frAllplot{stimDur}(trials2keepL{stimDur},2:end);
                        FRRight{stimDur} = frAllplot{stimDur}(trials2keepR{stimDur},2:end);
                        FRtime{stimDur} = frAllplot{stimDur}(:,1);            
    
    
                        %Get adcAll
                        temp0 = adcAllTime(trials2keepL{stimDur});
                        idcs = min(cell2mat(cellfun(@(x) numel(x), temp0, 'UniformOutput',false)));
                        temp0 = cell2mat(cellfun(@(x) x(1:idcs), temp0, 'UniformOutput', false));
                        adc{stimDur}{1,1} = MMath.MeanStats(temp0,1);
    
                        temp0 = adcAllLeft(trials2keepL{stimDur});
                        idcs = min(cell2mat(cellfun(@(x) numel(x), temp0, 'UniformOutput',false)));
                        temp0 = cell2mat(cellfun(@(x) x(1:idcs), temp0, 'UniformOutput', false));
                        adc{stimDur}{2,1} = double(MMath.MeanStats(temp0,1));                    
                        
                        adcWin = find(adcAllTime{1}>= FRlims{stimDur}(1) & adcAllTime{1}<= FRlims{stimDur}(2));
    
                        if size(adcWin,2) > numel(adc{stimDur}{2,1})
                            adcWin = adcWin(1:numel(adc{stimDur}{2,1}));
                        end

                        temp = adc{stimDur};
                        adc{stimDur} = cell2mat(cellfun(@(x) x(adcWin), temp, 'UniformOutput',   false));          
                        maxAdc{genotype}{recSite}(sessNum,stimDur) = max(adc{stimDur}(2,:));
                        
                        if sum(ismember('Left', sessRecSite))==4
                            stims = {trials2keepL{stimDur}, trials2keepR{stimDur}};
                        else
                            stims = {trials2keepR{stimDur}, trials2keepL{stimDur}};
                        end

                        if LFPData
                            %Get LFPAll for each stimDur for ipsi
                            try
                                temp0 = LFPAllTime(stims{1});
                            catch
                                keyboard;
                            end
                            idcs = min(cell2mat(cellfun(@(x) numel(x), temp0, 'UniformOutput',false)));
                            temp0 =cellfun(@(x) x', temp0, 'UniformOutput',false);
                            temp0 = cell2mat(cellfun(@(x) x(1:idcs), temp0, 'UniformOutput', false));
                            LFPFinal{genotype}{recSite}{sessNum}{stimDur,1} = MMath.MeanStats(temp0,1);                        
                            
                            temp0 = LFP_filtered(stims{1},:);
                            idcs = min(cell2mat(cellfun(@(x) numel(x), temp0, 'UniformOutput',false)), [],'All');
%                             temp0 =cellfun(@(x) x', temp0, 'UniformOutput',false);
                            temp0 = cellfun(@(x) x(1:idcs), temp0, 'UniformOutput', false);
                            
                            temp1 = LFP_filtered(stims{2},:);
                            idcs = min(cell2mat(cellfun(@(x) numel(x), temp1, 'UniformOutput',false)), [],'All');
%                             temp1 =cellfun(@(x) x', temp1, 'UniformOutput',false);
                            temp1 = cellfun(@(x) x(1:idcs), temp1, 'UniformOutput', false);
    
                            
                            clearvars ipsiLFP contraLFP;
                            parfor chan = 1: width(temp0)
                                
                                ipsiLFP{chan} = MMath.MeanStats(cell2mat(temp0(:,chan)),1);
                                contraLFP{chan} = MMath.MeanStats(cell2mat(temp1(:,chan)),1);
                            end
    
                            LFPFinal{genotype}{recSite}{sessNum}{stimDur,2} = ipsiLFP';
                            LFPFinal{genotype}{recSite}{sessNum}{stimDur,3} = contraLFP';
                        end

                        pvalL = [];
                        pvalR = [];
                        unitDepth = [];
                        spikeTimes = {};
                        pvalstimDur =[];
                        bodysides = [];
                        meanFR = {};
                        cbiases = {};
                        pValIpsi = [];
                        pValContra = [];
                        unitHistoTable = table();
                        
                        
                        parfor unitNum = 1: size(preMeanFRL{stimDur},2)                           

                           
                            [pvalL(unitNum)] = signrank(preMeanFRL{stimDur}(:,unitNum), postMeanFRL{stimDur}(:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);
                            [pvalR(unitNum)] = signrank(preMeanFRR{stimDur}(:,unitNum), postMeanFRR{stimDur}(:,unitNum), ...
                                'tail', 'both', 'Alpha', statAlpha);
                 
                            unitDepth(unitNum) = unitChanDepth(unitNum);
                            meanFRtime =  MMath.MeanStats(cell2mat(FRtime{stimDur}), 1);
                        
                            if sum(ismember(sessRecSite, 'Left'))==4
                                uSpikesIpsi = spikeLeft(:,unitNum);
                                uSpikesContra = spikeRight(:,unitNum);
                                [meanFRI, ~, ~,...
                                ciFRI]= MMath.MeanStats(cell2mat(FRLeft{stimDur}(:,unitNum)), 1);

                                pValIpsi(unitNum) = pvalL(unitNum);
                                pValContra(unitNum) = pvalR(unitNum);
                                [meanFRC, ~, ~,...
                                ciFRC]= MMath.MeanStats(cell2mat(FRRight{stimDur}(:,unitNum)), 1);
                            else
                                uSpikesIpsi = spikeRight(:,unitNum);
                                uSpikesContra = spikeLeft(:,unitNum);
                                [meanFRI, ~, ~,...
                                ciFRI]= MMath.MeanStats(cell2mat(FRRight{stimDur}(:,unitNum)), 1);
                                pValIpsi(unitNum) = pvalR(unitNum);
                                pValContra(unitNum) = pvalL(unitNum);

                                [meanFRC, ~, ~,...
                                ciFRC]= MMath.MeanStats(cell2mat(FRLeft{stimDur}(:,unitNum)), 1);
                            end
                            
                            preSpikesContra = sum(cell2mat(cellfun(@(x) numel(find(x>plotLims{stimDur}(1) & x<=0)), ...
                                uSpikesContra, 'UniformOutput', false)));
                            postSpikesContra = sum(cell2mat(cellfun(@(x) numel(find(x>0 & x<=plotLims{stimDur}(2))), ...
                                uSpikesContra, 'UniformOutput', false)));
                            preSpikesIpsi = sum(cell2mat(cellfun(@(x) numel(find(x>plotLims{stimDur}(1) & x<=0)), ...
                                uSpikesIpsi, 'UniformOutput', false)));
                            postSpikesIpsi = sum(cell2mat(cellfun(@(x) numel(find(x>0 & x<=plotLims{stimDur}(2))), ...
                                uSpikesIpsi, 'UniformOutput', false)));
                            pvalstimDur(unitNum) = min(pvalL(unitNum), pvalR(unitNum));   
                            
                            C = abs(postSpikesContra - preSpikesContra);
                            I = abs(postSpikesIpsi - preSpikesIpsi);

                            Cbias = (C-I)/(C+I);
%                             cbiases(unitNum,:) = Cbias;
                            spikeTimes(unitNum,:) = {uSpikesIpsi, uSpikesContra,...
                                    penetrationDepth-unitDepth(unitNum), min(pvalL(unitNum), pvalR(unitNum)), Cbias};
                            meanFR(unitNum,:) = {meanFRtime, meanFRI, meanFRC, ciFRI, ciFRC, ...
                                    penetrationDepth-unitDepth(unitNum), min(pvalL(unitNum), pvalR(unitNum)), Cbias};
                            bodysides(unitNum) = bodyside7;
                            cbiases(unitNum,:) = {Cbias, ...
                                        penetrationDepth-unitDepth(unitNum), min(pvalL(unitNum), pvalR(unitNum))};
                            unitHistoTable(unitNum,:) = se.userData.spikeInfo.unitHitsoTable(unitNum,:);      

                        end
                        

                        VariableNames = se.userData.spikeInfo.unitHitsoTable.Properties.VariableNames;
                        % make final variables to plot containing all data
                        pvalsTemp = [pvalstimDur', pValContra', pValIpsi'];
                        pvals{genotype}{recSite}{pstimDur}(end+1:end+numel(pvalstimDur),:) = pvalsTemp;                      
                        bodysidefinal{genotype}{recSite}{pstimDur}(end+1:end+numel(bodysides)) = bodysides;
                        Cbiastable{genotype}{recSite}{sessNum}{pstimDur} = cbiases;
                        adcFinal{genotype}{recSite}{pstimDur}(end+1:end+size(adc{stimDur},1),1:size(adc{stimDur},2)) = adc{stimDur};
                        allSpikeTimes{genotype}{recSite}{pstimDur}(end+1:end+size(spikeTimes,1),:) = spikeTimes;  
                        allMeanFR{genotype}{recSite}{pstimDur}(end+1:end+size(meanFR,1),:) = meanFR; 
                        histoInfoFinal{genotype}{recSite}{pstimDur}(end+1:end+size(unitHistoTable,1),:) = unitHistoTable; 
                        histoInfoFinal{genotype}{recSite}{pstimDur}.Properties.VariableNames= VariableNames;
                   end  

                  
                   % go to next session of the same recording site and
                   % genotype
                        
                end
    
    
            else
                continue;
            end
        end
    end
    
                      

%     clearvars -except ops allSpikeTimes maxAdc pvals plotAlpha ufreq uGenotypes inputrecSites adcFinal savePath plotLims genotype recSite recSites genotypes
% 

    if ~exist(savePath, 'dir')
        mkdir(savePath);
    end

    save([savePath '\allVars.mat']);    

%   
        
        

end

function BinomialIpsiResponsive(allVars,plotAlpha, savePath)
    load(allVars, 'ops', 'ufreq', 'uGenotypes',  'pvals');
    close all   
    ops.plotAlpha = plotAlpha;
    ops.savePath = savePath;
    % pvals is pvalmin, pvalcontra,pvalipsi
    % just signify according to allpvals
    for allpvals = 0:ops.allpvals          
        fid = fopen(fullfile( ops.savePath,['allPvals = ' num2str(allpvals) ' IpsiResponseBinomial.txt']), 'w');
        saveVar = fullfile( ops.savePath,['allPvals = ' num2str(allpvals) ' IpsiResponseBinomial.mat']);
        contraUnits = cell(1,2);
        ipsiUnits = cell(1,2);
        if allpvals
            variableNames = {'ipsiUnitNum', 'TotalSigUnits', 'BinomalTest', 'IpsiSigUnits', 'allPvalsBinomial'};
        else
            variableNames = {'ipsiUnitNum', 'TotalSigUnits', 'BinomalTest'};
        end
        ipsiFrac =cell(2,1);        
        for genotype = numel(pvals):-1:1 
           

            for recSite =numel(pvals{genotype}):numel(pvals{genotype})
                if ~isempty(pvals{genotype}{recSite})
                    pvalAll = pvals{genotype}{recSite};
                    emptypval = cellfun(@isempty, pvalAll);
                    pvalAll(emptypval) =[];
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
                        
                        pvalSess = cell2mat(cellfun(@(x) x(:,3), pvalAll, 'UniformOutput',false));
                        if size(pvalSess,2) >3
                           pvalSess = pvalSess(:,1:3);
                        end
                        sigUnits = pvalSess < ops.plotAlpha;
                        sumlogic = sum(sigUnits,2);
                        sigUnits = sumlogic>0;
                        pvalAllipsi = cellfun(@(x) x(sigUnits, :), pvalAll, 'UniformOutput',false);
                       
                        ipsiUnits{genotype} = cellfun(@(x) x(x(:,3)<ops.plotAlpha,:), pvalAll, 'UniformOutput', false);
                        contraUnits{genotype} = cellfun(@(x) x(x(:,2)<ops.plotAlpha,:), pvalAll, 'UniformOutput', false);
                        totalUnits = cellfun(@(x) height(x), pvalAll, 'UniformOutput', false);
                       
                        ipsiFrac{genotype,1} = cellfun(@(x) height(x),  ipsiUnits{genotype},  'Uni', false);
                        ipsiFrac{genotype,2} = totalUnits; 
                        ipsiFrac{genotype,4} = height(pvalAllipsi{1}); 
                        
                    else
                        sigUnits = cellfun(@(x) x(:,1)<ops.plotAlpha, pvalAll, 'UniformOutput', false);
                        pvalAll = cellfun(@(x,y) x(y,:), pvalAll, sigUnits, 'UniformOutput', false);
                        
                        ipsiUnits{genotype} = cellfun(@(x) x(x(:,3)<ops.plotAlpha,:), pvalAll, 'UniformOutput', false);
                        contraUnits{genotype} = cellfun(@(x) x(x(:,2)<ops.plotAlpha,:), pvalAll, 'UniformOutput', false);
                        totalUnits = cellfun(@(x) height(x), pvalAll, 'UniformOutput', false);

                       
                        ipsiFrac{genotype,1} = cellfun(@(x) height(x),  ipsiUnits{genotype}, 'Uni', false);
                        ipsiFrac{genotype,2} = totalUnits; 
                    end
                end
            end 
            
            
            
            
        end

        fprintf(fid, 'Binomial probability for following the frequencies:\n ');
        if allpvals
            ipsiFrac{1,5}=1- binocdf(ipsiFrac{1,4} - 1, ipsiFrac{1,2}{1}, ipsiFrac{2,4}/ ipsiFrac{2,2}{1});
            fprintf(fid, 'allpvals=1 p value is: %.10f\n', ipsiFrac{1,5});
            fprintf(fid, 'Unit number for KO ipsi: %d KO total: %d WT ipsi: %d WT total: %d\n', ...
                    ipsiFrac{1,4}, ipsiFrac{1,2}{1}, ipsiFrac{2,4}, ipsiFrac{2,2}{1});
        else
            for stim=1:numel(ufreq)
                ipsiFrac{1,3}{stim}=1- binocdf(ipsiFrac{1,1}{stim} - 1, ipsiFrac{1,2}{stim}, ipsiFrac{2,1}{stim}/ ipsiFrac{2,2}{stim});
                fprintf(fid, [ufreq{stim} ' hz: %.10f\n'], ipsiFrac{1,3}{stim});
                fprintf(fid, 'Unit number for KO ipsi: %d KO total: %d WT ipsi: %d WT total: %d\n', ...
                    ipsiFrac{1,1}{stim}, ipsiFrac{1,2}{stim}, ipsiFrac{2,1}{stim}, ipsiFrac{2,2}{stim});
            end
        end
        

        fclose(fid);  
        
        ipsiFracTable = cell2table(ipsiFrac, "VariableNames",variableNames, 'RowNames', uGenotypes);
        save(saveVar, 'ipsiFracTable');            
    end
end

function IpsiresponsiveLatencies(allVars,plotAlpha, savePath, binWidth)
    load(allVars, 'ops', 'ufreq', 'uGenotypes',  'pvals',  'allMeanFR');
    close all   
    ops.plotAlpha = plotAlpha;
    ops.savePath = savePath;
    % pvals is pvalmin, pvalcontra,pvalipsi
    % just signify according to allpvals
    for allpvals = 0:ops.allpvals          
        fid = fopen(fullfile( ops.savePath,['allPvals = ' num2str(allpvals) ' IpsiResponseBinomial.txt']), 'w');
        saveVar = fullfile( ops.savePath,['allPvals = ' num2str(allpvals) ' IpsiResponseBinomial.mat']);
        contraUnits = cell(1,2);
        ipsiUnits = cell(1,2);
        if allpvals
            variableNames = {'ipsiUnitNum', 'TotalSigUnits', 'BinomalTest', 'IpsiSigUnits', 'allPvalsBinomial'};
        else
            variableNames = {'ipsiUnitNum', 'TotalSigUnits', 'BinomalTest'};
        end
        ipsiFrac =cell(2,1);        
        for genotype = numel(pvals):-1:1 
           

            for recSite =numel(pvals{genotype}):numel(pvals{genotype})
                if ~isempty(pvals{genotype}{recSite})
                    meanFRAll= allMeanFR{genotype}{recSite};

                    pvalAll = pvals{genotype}{recSite};
                    emptypval = cellfun(@isempty, pvalAll);
                    pvalAll(emptypval) =[];
                    meanFRAll(emptypval) =[];

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
                        meanFRAll = cellfun(@(x) x(sigUnits, :), meanFRAll, 'UniformOutput',false);


                        pvalSess = cell2mat(cellfun(@(x) x(:,3), pvalAll, 'UniformOutput',false));
                        if size(pvalSess,2) >3
                           pvalSess = pvalSess(:,1:3);
                        end

                        sigUnits = pvalSess < ops.plotAlpha;
                        sumlogic = sum(sigUnits,2);
                        sigUnits = sumlogic>0;
                        pvalAllipsi = cellfun(@(x) x(sigUnits, :), pvalAll, 'UniformOutput',false);
                        meanFRAll = cellfun(@(x) x(sigUnits, :), meanFRAll, 'UniformOutput',false);

                        
                        
                    else
                        sigUnits = cellfun(@(x) x(:,1)<ops.plotAlpha, pvalAll, 'UniformOutput', false);
                        pvalAll = cellfun(@(x,y) x(y,:), pvalAll, sigUnits, 'UniformOutput', false);
                        meanFRAll = cellfun(@(x,y) x(y,:), meanFRAll, sigUnits, 'UniformOutput', false);
                        
                    end
                end
                
                % latency calulcated as the fisrt time the neuronal firing
                % croses the confidence interval of the baseline
                bins = meanFRAll{1,1}{1,1};
                baseline = find(bins>-ops.constantWindow & bins<=0);
                postWindow = find(bins>0 & bins<=ops.constantWindow);
                ipsiFR = cellfun(@(x) cell2mat(x(:,2)), meanFRAll, 'UniformOutput', false);
                ipsiFRTime = cellfun(@(x) cell2mat(x(:,1)), meanFRAll, 'UniformOutput', false);
                
                ipsiFRconf = cellfun(@(x) x(:,4), meanFRAll, 'UniformOutput', false);
                for stim = 1:numel(ipsiFRconf)
                    latency= [];
                    parfor unitNum =1:height(ipsiFRconf{stim})
                        FRpost = ipsiFR{stim}(unitNum,postWindow);
                        FRTimepost=ipsiFRTime{stim}(unitNum,postWindow);
                        frCrossBin = find(FRpost< min(ipsiFRconf{stim}{unitNum}(:,baseline))| FRpost> max(ipsiFRconf{stim}{unitNum}(:,baseline)),1);
                        if ~isempty(frCrossBin)
                            latency(unitNum) = FRTimepost(frCrossBin);
                        else
                            latency(unitNum) = nan;
                        end
                    end
                    allLatency{genotype}{recSite}{stim} = latency;
                end
                
                
                
                

            end 


            
            
            
            
        end

        
        colors = {'r', 'k'};

        g =figure(1); clf;
        g.WindowState='maximized';
        for stim =1:3
            h1 = subplot(3,1,stim);
            hold(h1, 'on')
            for genotype = 1:numel(allLatency)
                histogram(allLatency{genotype}{2}{stim}*1000, [0:binWidth:ops.constantWindow]*1000,...
                    'Normalization', 'cdf', 'FaceColor',colors{genotype});
            end
            title([ufreq{stim} ' hz'])
            legend(uGenotypes)
            xlabel('Time(ms)')
            ylabel('CDF of IRUs')
            hold(h1,'off')
        end

        g2 = figure(2); clf;
        g2.WindowState='maximized';
        for stim =1:3
            h1 = subplot(3,1,stim);
            hold(h1, 'on')
            for genotype = 1:numel(allLatency)
                histogram(allLatency{genotype}{2}{stim}*1000, [0:binWidth:ops.constantWindow]*1000,...
                    'Normalization', 'count', 'FaceColor',colors{genotype});
            end
            title([ufreq{stim} ' hz'])
            legend(uGenotypes)
            xlabel('Time(ms)')
            ylabel('#of IRUs')
            hold(h1,'off')
        end

        savefig(g, fullfile(ops.savePath, ['allpvals = ' num2str(allpvals) ' IpsiresponsiveLatenciesCDFs.fig']));
        saveas(g, fullfile(ops.savePath, ['allpvals = ' num2str(allpvals) ' IpsiresponsiveLatenciesCDFs.png']));
        savefig(g2, fullfile(ops.savePath, ['allpvals = ' num2str(allpvals) ' IpsiresponsiveLatenciesCounts.fig']));
        saveas(g2, fullfile(ops.savePath, ['allpvals = ' num2str(allpvals) ' IpsiresponsiveLatenciesCounts.png']));


      



               
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
        histTable = readtable('G:\VC03_RoboKO\EphysPassiveStimSEs\Histology\Histology_wM1.csv');
        
        
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

                        PlotHistoUnitsHelper(fwireframe, allHistoIpsi, bregma,'.', 'r');
                        PlotHistoUnitsHelper(fwireframe, allHistoContra, bregma, '.', 'g');
                        PlotHistoUnitsHelper(fwireframe, allHistoBoth, bregma, '.', 'w');
                        


                    else
                        sigUnits = cellfun(@(x) x(:,1)<ops.plotAlpha, pvalAll, 'UniformOutput', false);
                        pvalAll = cellfun(@(x,y) x(y,:), pvalAll, sigUnits, 'UniformOutput', false);
                        allHisto = cellfun(@(x,y) x(y,:), allHisto, sigUnits, 'UniformOutput', false);
                        
                    end
                end
                
               
                
                
                
                
                

            end 


            
            
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
                              
                sigUnits = {};
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
                        windowSize{stimDur} = findDurationLFP(stimDurs{stimDur})*2; %in s                
                        plotLims{stimDur} = [-windowSize{stimDur}, windowSize{stimDur}];
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
                        windowSize{stimDur} = findDurationLFP(stimDurs{stimDur})*2; %in s              
                        plotLims{stimDur} = [-windowSize{stimDur}, windowSize{stimDur}]
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
                        windowSize{stimDur} = findDurationLFP(stimDurs{stimDur})*2; %in s                         
                        plotLims{stimDur} = [-windowSize{stimDur}, windowSize{stimDur}]
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

