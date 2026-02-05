% ------------------------------------------------------------------------
%          Crop, Rotate, Adjust Contrast, and Downsample Histology
% ------------------------------------------------------------------------


%%  SET FILE AND PARAMETERS

% * remember to run one cell at a time, instead of the whole script at once *
animal_name = 'VC030213';
% directory of histology images
image_folder = 'G:\VC03_RoboKO\EphysPassiveStimSEs\Histology\VC030213\wM1_16x';

% directory to save the processed images -- can be the same as the above image_folder
% results will be put inside a new folder called 'processed' inside of this image_folder
save_folder = image_folder;

% name of images, in order anterior to posterior or vice versa
% once these are downsampled they will be named ['original name' '_processed.tif']
image_file_names = dir([image_folder filesep '*.tif']); % get the contents of the image_folder
image_file_names = natsortfiles({image_file_names.name});
% image_file_names = {'slide no 2_RGB.tif','slide no 3_RGB.tif','slide no 4_RGB.tif'}; % alternatively, list each image in order

% if the images are individual slices (as opposed to images of multiple
% slices, which must be cropped using the cell CROP AND SAVE SLICES)
image_files_are_individual_slices = true;

% use images that are already at reference atlas resolution (here, 10um/pixel)
use_already_downsampled_image = false; 

% pixel size parameters: microns_per_pixel of large images in the image
% folder (if use_already_downsampled_images is set to false);
% microns_per_pixel_after_downsampling should typically be set to 10 to match the atlas
microns_per_pixel = 6.399;


microns_per_pixel_after_downsampling = 10;


% ----------------------
% additional parameters
% ----------------------

% if the images are cropped (image_file_are_individual_slices = false),
% name to save cropped slices as; e.g. the third cropped slice from the 2nd
% image containing many slices will be saved as: save_folder/processed/save_file_name02_003.tif
save_file_name = [animal_name '_'];

% increase gain if for some reason the images are not bright enough
gain = 1; 

% plane to view ('coronal', 'sagittal', 'transverse')
plane = 'coronal';

% size in pixels of reference atlas brain. For coronal slice, this is 800 x 1140
if strcmp(plane,'coronal')
    atlas_reference_size = [800 1140]; 
elseif strcmp(plane,'sagittal')
    atlas_reference_size = [800 1320]; 
elseif strcmp(plane,'transverse')
    atlas_reference_size = [1140 1320];
end






% finds or creates a folder location for processed images -- 
% a folder within save_folder called processed
folder_processed_images = fullfile(save_folder,'Processed');
if ~exist(folder_processed_images)
    mkdir(folder_processed_images)
end


%% LOAD AND PROCESS SLICE PLATE IMAGES

% close all figures
close all
   

% if the images need to be downsampled to 10um pixels (use_already_downsampled_image = false), 
% this will downsample and allow you to adjust contrast of each channel of each image from image_file_names
%
% if the images are already downsampled (use_already_downsampled_image = true), this will allow
% you to adjust the contrast of each channel
%
% Open Histology Viewer figure
try 
    figure(histology_figure);
catch; histology_figure = figure('Name','Histology Viewer'); end
warning('off', 'images:initSize:adjustingMag'); warning('off', 'MATLAB:colon:nonIntegerIndex');

% Function to downsample and adjust histology image
HistologyBrowser(histology_figure, save_folder, image_folder, image_file_names, folder_processed_images, image_files_are_individual_slices, ...
            use_already_downsampled_image, microns_per_pixel, microns_per_pixel_after_downsampling, gain)

  

%% CROP AND SAVE SLICES -- run once the above is done, if image_file_are_individual_slices = false

% close all figures
close all

% run this function if the images from image_file_names have several
% slices, per image (e.g. an image of an entire histology slide)
%
% this function allows you to crop all the slices you would like to 
% process im each image, by drawing rectangles around them in the figure. 
% these will be further processed in the next cell
if ~image_files_are_individual_slices
    histology_figure = figure('Name','Histology Viewer');
    HistologyCropper(histology_figure, save_folder, image_file_names, atlas_reference_size, save_file_name, use_already_downsampled_image)
else
    disp('individually cropped slices already available')
end


%% GO THROUGH TO FLIP HORIZONTAL SLICE ORIENTATION, ROTATE, SHARPEN, and CHANGE ORDER

% close all figures
close all
            
% this takes images from folder_processed_images ([save_folder/processed]),
% and allows you to rotate, flip, sharpen, crop, and switch their order, so they
% are in anterior->posterior or posterior->anterior order, and aesthetically pleasing
% 
% it also pads images smaller than the reference_size and requests that you
% crop images larger than this size
%
% note -- presssing left or right arrow saves the modified image, so be
% sure to do this even after modifying the last slice in the folder
slice_figure = figure('Name','Slice Viewer');
SliceFlipper(slice_figure, folder_processed_images, atlas_reference_size)

%% Navigate_Atlas_Register_Slices
% ------------------------------------------------------------------------
%          Run Allen Atlas Browser
% ------------------------------------------------------------------------


%% ENTER FILE LOCATION AND PROBE-SAVE-NAME


% directory of histology
processed_images_folder = folder_processed_images; 
% processed_images_folder = image_folder; 

% name the saved probe points, to avoid overwriting another set of probes going in the same folder
probe_save_name_suffix = 'corticalDepth'; 

% how far into the brain did you go from the surface, either for each probe or just one number for all -- in mm
probe_lengths = 1.5; 


% directory of reference atlas files
annotation_volume_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\annotation_volume_10um_by_index.npy';
structure_tree_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\structure_tree_safe_2017.csv';
template_volume_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\template_volume_10um.npy';

% plane to view ('coronal', 'sagittal', 'transverse')
plane = 'coronal';


% GET PROBE TRAJECTORY POINTS
close all
% load the reference brain and region annotations
if ~exist('av','var') || ~exist('st','var') || ~exist('tv','var')
    disp('loading reference atlas...')
    av = readNPY(annotation_volume_location);
    st = loadStructureTree(structure_tree_location);
    tv = readNPY(template_volume_location);
end

% select the plane for the viewer
if strcmp(plane,'coronal')
    av_plot = av;
    tv_plot = tv;
elseif strcmp(plane,'sagittal')
    av_plot = permute(av,[3 2 1]);
    tv_plot = permute(tv,[3 2 1]);
elseif strcmp(plane,'transverse')
    av_plot = permute(av,[2 3 1]);
    tv_plot = permute(tv,[2 3 1]);
end

% create Atlas viewer figure
f = figure('Name','Atlas Viewer'); 

% show histology in Slice Viewer
try; figure(slice_figure_browser); title('');
catch; slice_figure_browser = figure('Name','Slice Viewer'); end
reference_size = size(tv_plot);
sliceBrowser(slice_figure_browser, processed_images_folder, f, reference_size);


% % use application in Atlas Transform Viewer
% % use this function if you have a processed_images_folder with appropriately processed .tif histology images
f = AtlasTransformBrowser(f, tv_plot, av_plot, st, slice_figure_browser, processed_images_folder, probe_save_name_suffix, plane);


% use the simpler version, which does not interface with processed slice images
% just run these two lines instead of the previous 5 lines of code
% 
%  save_location = processed_images_folder;
%  f = allenAtlasBrowser(f, tv_plot, av_plot, st, save_location, probe_save_name_suffix, plane);


%%
%% ------------------------------------------------------------------------
%          Display Probe Track.m
% ------------------------------------------------------------------------

%% ENTER PARAMETERS AND FILE LOCATION

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

% show a table of regions that the probe goes through, in the console
show_region_table = true;
      
% black brain?
black_brain = true;


close all




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

% load probe points
probePoints = load(fullfile(processed_images_folder, ['probe_points' probe_save_name_suffix]));
ProbeColors = .75*[1.3 1.3 1.3; 1 .75 0;  .3 1 1; .4 .6 .2; 1 .35 .65; .7 .7 .9; .65 .4 .25; .7 .95 .3; .7 0 0; .6 0 .7; 1 .6 0]; 
% order of colors: {'white','gold','turquoise','fern','bubble gum','overcast sky','rawhide', 'green apple','purple','orange','red'};
fwireframe = [];

% scale active_probe_length appropriately
active_probe_length = active_probe_length*100;

% determine which probes to analyze
if strcmp(probes_to_analyze,'all')
    probes = 1:size(probePoints.pointList.pointList,1);
else
    probes = probes_to_analyze;
end 





% PLOT EACH PROBE -- FIRST FIND ITS TRAJECTORY IN REFERENCE SPACE

% create a new figure with wireframe
fwireframe = plotBrainGrid([], [], fwireframe, black_brain);
hold on; 
fwireframe.InvertHardcopy = 'off';

for selected_probe = probes
    
% get the probe points for the currently analyzed probe 
if strcmp(plane,'coronal')
    curr_probePoints = probePoints.pointList.pointList{selected_probe,1}(:, [3 2 1]);
elseif strcmp(plane,'sagittal')
    curr_probePoints = probePoints.pointList.pointList{selected_probe,1}(:, [1 2 3]);
elseif strcmp(plane,'transverse')
    curr_probePoints = probePoints.pointList.pointList{selected_probe,1}(:, [1 3 2]);
end



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
hp = plot3(curr_probePoints(:,1), curr_probePoints(:,3), curr_probePoints(:,2), '.','linewidth',2, 'color',[ProbeColors(selected_probe,:) .2],'markers',10);

% plot brain entry point
plot3(m(1), m(3), m(2), 'r*','linewidth',1)

% use the deepest clicked point as the tip of the probe, if no scaling provided (scaling_factor = false)
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

% find the percent of the probe occupied by electrodes
percent_of_tract_with_active_sites = min([active_probe_length / (probe_length*100), 1.0]);
active_site_start = probe_length_histo*(1-percent_of_tract_with_active_sites);
active_probe_position = round([active_site_start  probe_length_histo]);

% plot line the length of the active probe sites in reference space
plot3(m(1)+p(1)*[active_probe_position(1) active_probe_position(2)], m(3)+p(3)*[active_probe_position(1) active_probe_position(2)], m(2)+p(2)*[active_probe_position(1) active_probe_position(2)], ...
    'Color', ProbeColors(selected_probe,:), 'LineWidth', 1);
% plot line the length of the entire probe in reference space
plot3(m(1)+p(1)*[1 probe_length_histo], m(3)+p(3)*[1 probe_length_histo], m(2)+p(2)*[1 probe_length_histo], ...
    'Color', ProbeColors(selected_probe,:), 'LineWidth', 1, 'LineStyle',':');


% ----------------------------------------------------------------
% Get and plot brain region labels along the extent of each probe
% ----------------------------------------------------------------

% convert error radius into mm
error_length = round(probe_radius / 10);

% find and regions the probe goes through, confidence in those regions, and plot them
borders_table = plotDistToNearestToTip(m, p, av_plot, st, probe_length_histo, error_length, active_site_start, distance_past_tip_to_plot, show_parent_category, show_region_table, plane); % plots confidence score based on distance to nearest region along probe
BT{selected_probe} = table2struct(borders_table);
title(['Probe ' num2str(selected_probe)],'color',ProbeColors(selected_probe,:))

pause(.05)
end
% Save figures in processed folder for each probe
saveFigName = fullfile(processed_images_folder, [probe_save_name_suffix '_']);
savefig(fwireframe, [saveFigName 'BrainView']);

save([saveFigName 'ProbeDist'],  'BT');

% (Analyze_clicked_Points.m)

% ------------------------------------------------------------------------
%      Analyze non-linear ROIs that were clicked as 'object points'
% ------------------------------------------------------------------------



% ENTER PARAMETERS AND FILE LOCATION 

% file location of object points
save_folder = folder_processed_images;

% directory of reference atlas files
% directory of reference atlas files
annotation_volume_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\annotation_volume_10um_by_index.npy';
structure_tree_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\structure_tree_safe_2017.csv';
template_volume_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\template_volume_10um.npy';



% name of the saved object points
object_save_name_suffix = probe_save_name_suffix;

% either set to 'all' or a list of indices from the clicked objects in this file, e.g. [2,3]
objects_to_analyze = 'all';

% plane used to view when points were clicked ('coronal' -- most common, 'sagittal', 'transverse')
plane = 'coronal';

% brain figure black or white
black_brain = true;

close all

% LOAD THE REFERENCE ANNOTATIONS AND PROBE POINTS

% load the reference brain annotations
if ~exist('av','var') || ~exist('st','var')
    disp('loading reference atlas...')
    av = readNPY(annotation_volume_location);
    st = loadStructureTree(structure_tree_location);
end


% load object points
objectPoints = load(fullfile(save_folder, ['probe_points' object_save_name_suffix]));

% determine which objects to analyze
if strcmp(objects_to_analyze,'all')
    objects = 1:size(objectPoints.pointList.pointList,1);
else
    objects = objects_to_analyze;
end 


% BRING UP THE RELEVANT DATA FOR EACH PROBE POINTS, FOR FURTHER ANALYSIS

% initialize cell array containing info on each clicked point
if length(objects) > 1
    roi_annotation = cell(length(objects),1);
    roi_location = cell(length(objects),1);
end

% generate needed values
bregma = allenCCFbregma(); % bregma position in reference data space
atlas_resolution = 0.010; % mm

% plot brain grid
ProbeColors = [1 1 1; 1 .75 0;  .3 1 1; .4 .6 .2; 1 .35 .65; .7 .7 1; .65 .4 .25; .7 .95 .3; .7 0 0; .6 0 .7; 1 .6 0]; 
% order of colors: {'white','gold','turquoise','fern','bubble gum','overcast sky','rawhide', 'green apple','purple','orange','red'};
fwireframe = plotBrainGrid([], [], [], black_brain); hold on; 
fwireframe.InvertHardcopy = 'off';



for object_num = objects
    
    selected_object = objects(object_num);
        
    % get the object points for the currently analyzed object    
    if strcmp(plane,'coronal')
        curr_objectPoints = objectPoints.pointList.pointList{selected_object,1}(:, [3 2 1]);
    elseif strcmp(plane,'sagittal')
        curr_objectPoints = objectPoints.pointList.pointList{selected_object,1}(:, [1 2 3]);
    elseif strcmp(plane,'transverse')
        curr_objectPoints = objectPoints.pointList.pointList{selected_object,1}(:, [1 3 2]);
    end

    % plot points on the wire frame brain
    figure(fwireframe); hold on
    hp = plot3(curr_objectPoints(:,1), curr_objectPoints(:,3), curr_objectPoints(:,2), '.','linewidth',2, 'color',[ProbeColors(object_num,:) .2],'markers',10);   
    bregma_res = bregma*atlas_resolution;

    plot3(bregma(1),bregma(3),bregma(2), '*', 'color',[1 1 1],'markers',5);
%     plot3(-bregma_res(1),-bregma_res(2),-bregma_res(3), '.', 'color',[1 1 1],'markers',10);

    % use the point's position in the atlas to get the AP, DV, and ML coordinates
    ap = -(curr_objectPoints(:,1)-bregma(1))*atlas_resolution;
    dv = (curr_objectPoints(:,2)-bregma(2))*atlas_resolution;
    ml = (curr_objectPoints(:,3)-bregma(3))*atlas_resolution;
    roi_location_curr = [ap dv ml];
    
    % initialize array of region annotations
    roi_annotation_curr = cell(size(curr_objectPoints,1),3);    
    
    % loop through every point to get ROI locations and region annotations
    for point = 1:size(curr_objectPoints,1)

        % find the annotation, name, and acronym of the current ROI pixel
        ann = av(curr_objectPoints(point,1),curr_objectPoints(point,2),curr_objectPoints(point,3));
        name = st.safe_name{ann};
        acr = st.acronym{ann};

        roi_annotation_curr{point,1} = ann;
        roi_annotation_curr{point,2} = name;
        roi_annotation_curr{point,3} = acr;

    end
    
    % save results in cell array
    if length(objects) > 1
        roi_annotation{object_num} = roi_annotation_curr;
        roi_location{object_num} = roi_location_curr;
    else
        roi_annotation = roi_annotation_curr;
        roi_location = roi_location_curr;
    end
 
    % display results in a table
    disp(['Clicked points for object ' num2str(selected_object)])
    roi_table = table(roi_annotation_curr(:,2),roi_annotation_curr(:,3), ...
                        roi_location_curr(:,1),roi_location_curr(:,2),roi_location_curr(:,3), roi_annotation_curr(:,1), ...
         'VariableNames', {'name', 'acronym', 'AP_location', 'DV_location', 'ML_location', 'avIndex'});
    RoiT{object_num} = table2struct(roi_table);
     disp(roi_table)
    
end


% now, use roi_location and roi_annotation for your further analyses
% Save figures in processed folder for each probe
saveFigName = fullfile(save_folder, [object_save_name_suffix '_']);
savefig(fwireframe, [saveFigName 'BrainView']);

save([saveFigName 'ProbeLocations'],  'RoiT');



%% plot all sessions together on one reference

% load histology_wM1
histTable = readtable('G:\VC03_RoboKO\EphysPassiveStimSEs\Histology\Histology_wM1 - KO.csv');


animalNames = unique(histTable.AnimalName);
bregma = allenCCFbregma(); % bregma position in reference data space
atlas_resolution = 0.010; % mm

%%


% directory of reference atlas files
% directory of reference atlas files
annotation_volume_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\annotation_volume_10um_by_index.npy';
structure_tree_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\structure_tree_safe_2017.csv';
template_volume_location = 'C:\Users\VarunChokshi\Documents\GitHub\CCFAtlas\template_volume_10um.npy';

%
close all

% either set to 'all' or a list of indices from the clicked objects in this file, e.g. [2,3]
objects_to_analyze = 'all';

% plane used to view when points were clicked ('coronal' -- most common, 'sagittal', 'transverse')
plane = 'coronal';

% brain figure black or white
black_brain = true;

fwireframe = plotBrainGrid([], [], [], black_brain); hold on; 
fwireframe.InvertHardcopy = 'off';
          bregma_res = bregma*atlas_resolution;
    
        plot3(bregma(1),bregma(3),bregma(2), '*', 'color',[1 1 1],'markers',5);
    %     plot3(-bregma_res(1),-bregma_res(2),-bregma_res(3), '.', 'color',[1 1 1],'markers',10);

% LOAD THE REFERENCE ANNOTATIONS AND PROBE POINTS

% load the reference brain annotations
if ~exist('av','var') || ~exist('st','var')
    disp('loading reference atlas...')
    av = readNPY(annotation_volume_location);
    st = loadStructureTree(structure_tree_location);
end

for sessNum = 1:height(histTable)
    animalName = histTable.AnimalName{sessNum};
    save_folder = fullfile('G:\VC03_RoboKO\EphysPassiveStimSEs\Histology', animalName, 'wM1_16x\Processed');
    object_save_name_suffix = ['NP24_' histTable.ProbeSuffix{sessNum}];
    

    % name of the saved object points
%     object_save_name_suffix = probe_save_name_suffix;
    
    % load object points
    objectPoints = load(fullfile(save_folder, ['probe_points' object_save_name_suffix]));
    
    % determine which objects to analyze
    if strcmp(objects_to_analyze,'all')
        objects = 1:size(objectPoints.pointList.pointList,1);
    else
        objects = objects_to_analyze;
    end 
    
    
    % BRING UP THE RELEVANT DATA FOR EACH PROBE POINTS, FOR FURTHER ANALYSIS
    
    % initialize cell array containing info on each clicked point
    if length(objects) > 1
        roi_annotation = cell(length(objects),1);
        roi_location = cell(length(objects),1);
    end
    
    % generate needed values
 
    
    % plot brain grid
    ProbeColors = [1 1 1; 1 .75 0;  .3 1 1; .4 .6 .2; 1 .35 .65; .7 .7 1; .65 .4 .25; .7 .95 .3; .7 0 0; .6 0 .7; 1 .6 0]; 
    % order of colors: {'white','gold','turquoise','fern','bubble gum','overcast sky','rawhide', 'green apple','purple','orange','red'};
    
    
    
    for object_num = objects
        
        selected_object = objects(object_num);
            
        % get the object points for the currently analyzed object    
        if strcmp(plane,'coronal')
            curr_objectPoints = objectPoints.pointList.pointList{selected_object,1}(:, [3 2 1]);
        elseif strcmp(plane,'sagittal')
            curr_objectPoints = objectPoints.pointList.pointList{selected_object,1}(:, [1 2 3]);
        elseif strcmp(plane,'transverse')
            curr_objectPoints = objectPoints.pointList.pointList{selected_object,1}(:, [1 3 2]);
        end
    
        % plot points on the wire frame brain
        figure(fwireframe); hold on
%         hp = plot3(curr_objectPoints(:,1), curr_objectPoints(:,3), curr_objectPoints(:,2), '.','linewidth',2, 'color',[ProbeColors(object_num,:) .2],'markers',10);   
        hp = plot3(curr_objectPoints(:,1), curr_objectPoints(:,3), curr_objectPoints(:,2), '.','linewidth',2, 'LineStyle',':');   

    
        % use the point's position in the atlas to get the AP, DV, and ML coordinates
        ap = -(curr_objectPoints(:,1)-bregma(1))*atlas_resolution;
        dv = (curr_objectPoints(:,2)-bregma(2))*atlas_resolution;
        ml = (curr_objectPoints(:,3)-bregma(3))*atlas_resolution;
        roi_location_curr = [ap dv ml];
        
        % initialize array of region annotations
        roi_annotation_curr = cell(size(curr_objectPoints,1),3);    
        
        % loop through every point to get ROI locations and region annotations
        for point = 1:size(curr_objectPoints,1)
    
            % find the annotation, name, and acronym of the current ROI pixel
            ann = av(curr_objectPoints(point,1),curr_objectPoints(point,2),curr_objectPoints(point,3));
            name = st.safe_name{ann};
            acr = st.acronym{ann};
    
            roi_annotation_curr{point,1} = ann;
            roi_annotation_curr{point,2} = name;
            roi_annotation_curr{point,3} = acr;
    
        end
        
        % save results in cell array
        if length(objects) > 1
            roi_annotation{object_num} = roi_annotation_curr;
            roi_location{object_num} = roi_location_curr;
        else
            roi_annotation = roi_annotation_curr;
            roi_location = roi_location_curr;
        end
     
        % display results in a table
        disp(['Clicked points for object ' num2str(selected_object)])
        roi_table = table(roi_annotation_curr(:,2),roi_annotation_curr(:,3), ...
                            roi_location_curr(:,1),roi_location_curr(:,2),roi_location_curr(:,3), roi_annotation_curr(:,1), ...
             'VariableNames', {'name', 'acronym', 'AP_location', 'DV_location', 'ML_location', 'avIndex'});
        RoiT{object_num} = table2struct(roi_table);
         disp(roi_table)
        
    end

        
   end


% % now, use roi_location and roi_annotation for your further analyses
% % Save figures in processed folder for each probe
% saveFigName = fullfile(save_folder, [object_save_name_suffix '_']);
% savefig(fwireframe, [saveFigName 'BrainView']);
% 
% save([saveFigName 'ProbeLocations'],  'RoiT');


%% plot all sessions together on one reference

% load histology_wM1
histTable = readtable('G:\VC03_RoboKO\EphysPassiveStimSEs\Histology\Histology_wS1 - KO.csv');


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
fwireframe = plotBrainGrid([], [], fwireframe, black_brain);
hold on; 
fwireframe.InvertHardcopy = 'off';
bregma_res = bregma*atlas_resolution;
    
plot3(bregma(1),bregma(3),bregma(2), '*', 'color',[1 1 1],'markers',5);

for sessNum = 1:height(histTable)
        
    animalName = histTable.AnimalName{sessNum};
    searchFolder = fullfile('G:\VC03_RoboKO\EphysPassiveStimSEs\Histology', animalName);
    folderNames = dir(searchFolder);
   
    for i = 1: height(folderNames)
        if sum(ismember(folderNames(i).name,'wS1_'))>=4
            save_folder = fullfile(searchFolder, folderNames(i).name, 'Processed');
        end
    end


    object_save_name_suffix = [histTable.ProbeSuffix{sessNum} '_' histTable.SessDate{sessNum}];
    

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
        
        % focus on wireframe plot
        figure(fwireframe);
        
        % plot probe points
%         hp = plot3(curr_probePoints(:,1), curr_probePoints(:,3), curr_probePoints(:,2), '.','linewidth',2, 'color',[ProbeColors(selected_probe,:) .2],'markers',10);
        
        % plot brain entry point
        plot3(m(1), m(3), m(2), 'r*','linewidth',1)
        
        % use the deepest clicked point as the tip of the probe, if no scaling provided (scaling_factor = false)
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
        
        % active Probelength here
        
        if strcmp('H3', histTable.ProbeSuffix{sessNum})
            active_probe_length = 1.28 *100;
        else
            active_probe_length = probe_length*100;
        end
        % find the percent of the probe occupied by electrodes
        percent_of_tract_with_active_sites = min([active_probe_length / (probe_length*100), 1.0]);
        active_site_start = probe_length_histo*(1-percent_of_tract_with_active_sites);
        active_probe_position = round([active_site_start  probe_length_histo]);
        
%         % plot line the length of the active probe sites in reference space
%         plot3(m(1)+p(1)*[active_probe_position(1) active_probe_position(2)], m(3)+p(3)*[active_probe_position(1) active_probe_position(2)], m(2)+p(2)*[active_probe_position(1) active_probe_position(2)], ...
%             'Color', ProbeColors(selected_probe,:), 'LineWidth', 1);
%         % plot line the length of the entire probe in reference space
%         plot3(m(1)+p(1)*[1 probe_length_histo], m(3)+p(3)*[1 probe_length_histo], m(2)+p(2)*[1 probe_length_histo], ...
%             'Color', ProbeColors(selected_probe,:), 'LineWidth', 1, 'LineStyle',':');
        

    end
end

% plot all sessions together on one reference

% load histology_wM1
histTable = readtable('G:\VC03_RoboKO\EphysPassiveStimSEs\Histology\Histology_wS1 - WT.csv');


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
    searchFolder = fullfile('G:\VC03_RoboKO\EphysPassiveStimSEs\Histology', animalName);
    folderNames = dir(searchFolder);
   
    for i = 1: height(folderNames)
        if sum(ismember(folderNames(i).name,'wS1_'))>=4
            save_folder = fullfile(searchFolder, folderNames(i).name, 'Processed');
        end
    end


    object_save_name_suffix = [histTable.ProbeSuffix{sessNum} '_' histTable.SessDate{sessNum}];
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
        
        % focus on wireframe plot
        figure(fwireframe);
        
        % plot probe points
%         hp = plot3(curr_probePoints(:,1), curr_probePoints(:,3), curr_probePoints(:,2), '.','linewidth',2, 'color',[ProbeColors(selected_probe,:) .2],'markers',10);
        
        % plot brain entry point
        plot3(m(1), m(3), m(2), 'w*','linewidth',1)
        
        % use the deepest clicked point as the tip of the probe, if no scaling provided (scaling_factor = false)
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
        
       if strcmp('H3', histTable.ProbeSuffix{sessNum})
            active_probe_length = 1.28 *100;
        else
            active_probe_length = probe_length*100;
        end

        % find the percent of the probe occupied by electrodes
        percent_of_tract_with_active_sites = min([active_probe_length / (probe_length*100), 1.0]);
        active_site_start = probe_length_histo*(1-percent_of_tract_with_active_sites);
        active_probe_position = round([active_site_start  probe_length_histo]);
        
%         % plot line the length of the active probe sites in reference space
%         plot3(m(1)+p(1)*[active_probe_position(1) active_probe_position(2)], m(3)+p(3)*[active_probe_position(1) active_probe_position(2)], m(2)+p(2)*[active_probe_position(1) active_probe_position(2)], ...
%             'Color', ProbeColors(selected_probe,:), 'LineWidth', 1);
%         % plot line the length of the entire probe in reference space
%         plot3(m(1)+p(1)*[1 probe_length_histo], m(3)+p(3)*[1 probe_length_histo], m(2)+p(2)*[1 probe_length_histo], ...
%             'Color', ProbeColors(selected_probe,:), 'LineWidth', 1, 'LineStyle',':');
        

    end
end





