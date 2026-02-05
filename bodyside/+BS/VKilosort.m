classdef VKilosort
    %MKilosort Summary of this class goes here
    %   Detailed explanation goes here
    
    properties(Constant)
        chanMapH3 = [ ... % from tip to base or anatomically basal to apical
            27, 25, 23, 20, 22, 31, 29, 18, ...
            30, 32, 15, 21, 19, 24, 26, 28, ...
            02, 04, 05, 07, 09, 11, 13, 17, ...
            16, 14, 12, 10, 08, 06, 03, 01, ...
            64, 62, 59, 57, 55, 53, 51, 47, ...
            50, 52, 54, 56, 58, 60, 61, 63, ...
            37, 39, 41, 46, 44, 33, 35, 48, ...
            36, 34, 49, 43, 45, 42, 40, 38 ];
        
        chanMapH3p = [ ... % from tip to base or anatomically basal to apical
            64:-1:1];
        
        chanMapH2 = [ ... % Shank A to B, from tip to base or anatomically basal to apical, 
            64, 62, 59, 57, 55, 53, 51, 47, ...
            50, 52, 54, 56, 58, 60, 61, 63, ...
            37, 39, 41, 46, 44, 33, 35, 48, ...
            36, 34, 49, 43, 45, 42, 40, 38, ...
            27, 25, 23, 20, 22, 31, 29, 18, ...
            30, 32, 15, 21, 19, 24, 26, 28, ...
            02, 04, 05, 07, 09, 11, 13, 17, ...
            16, 14, 12, 10, 08, 06, 03, 01 ];
        
        chanMapP64 = [ ... % Shank A to D, from tip to base or anatomically basal to apical
            37, 39, 41, 46, 44, 33, 43, 35, 45, 48, 42, 36, 40, 34, 38, 49, ... % Shank A
            64, 62, 59, 57, 55, 53, 56, 51, 58, 47, 60, 50, 61, 52, 63, 54, ... % Shank B
            02, 04, 05, 07, 09, 11, 10, 13, 08, 17, 06, 16, 03, 14, 01, 12, ... % Shank C
            27, 25, 23, 20, 22, 31, 21, 29, 19, 18, 24, 30, 26, 32, 28, 15];    % Shank D
        
        chanMapTetrode32 = [ 25:32, 1:8, 24:-1:9 ];
    end
    
    methods(Static)
        function varargout = Sort(varargin)
            % Run spike sorting on a binary file. Results will be saved in the folder of .dat file.
            % Auto merge is disabled and no intermediate data is saved. 
            % 
            %   MKilosort.Sort()
            %   MKilosort.Sort(datFilePath)
            %   MKilosort.Sort(..., 'ChannelMapFunc', [])
            %   MKilosort.Sort(..., 'ConfigFunc', [])
            %   MKilosort.Sort(..., 'AutoMerge', false)
            %   MKilosort.Sort(..., 'GPU', true)
            %   rez = MKilosort.Sort(...)
            % 
            % Inputs
            %   datFilePath         A binary file of extracellular recording data. If not specified, a file
            %                       selection window will be prompted. 
            %   
            %   If either one of 'ChannelMapFunc' or 'ConfigFunc' is not provided, a dialog box will allow you 
            %   to choose a probe type for the preset configuration and channel map. 
            %   
            %   'ChannelMapFunc'    A function handle that takes the folder path of the .dat file as input 
            %                       and saves a chanMap.mat file to that folder. Examples can be found in the 
            %                       methods of this class (e.g. @MKilosort.SaveChanMapH3, modified from 
            %                       createChannelMapFile.m in the configFiles folder of Kilosort repository). 
            %   'ConfigFunc'        A function handle that takes the path of the .dat file as input and 
            %                       returns a structure of options. Examples can be found in the methods of this 
            %                       class (e.g. @MKilosort.Config64, modified from StandardConfig_MOVEME.m in 
            %                       the configFiles folder of Kilosort repository).
            %   'AutoMerge'         True or false (default).
            %   'GPU'               Force Kilosort to use (true, default) or not to use (false) GPU. Note that 
            %                       this option always overwrite ops.GPU. 
            % Output
            %   rez                 The raw clustering results that Kilosort outputs. 
            
            % Parse inputs
            p = inputParser();
            p.addOptional('datFilePath', [], @(x) ischar(x) || isempty(x));
            p.addParameter('ChannelMapFunc', [], @(x) isa(x, 'function_handle'));
            p.addParameter('ConfigFunc', [], @(x) isa(x, 'function_handle'));
            p.addParameter('AutoMerge', false, @islogical);
            p.addParameter('GPU', true, @islogical);
            p.addParameter('probeNames', [], @ischar);
            p.parse(varargin{:});
            datFilePath = p.Results.datFilePath;
            fChanMap = p.Results.ChannelMapFunc;
            fConfig = p.Results.ConfigFunc;
            isMerge = p.Results.AutoMerge;
            isGPU = p.Results.GPU;
            probeNames = p.Results.probeNames;
            % Find .dat file
            if nargin < 1
                datFilePath = MBrowse.File([], 'Select a Kilosort .dat file', '*.dat');
            end
            if isempty(datFilePath)
                return;
            end
            ksDir = fileparts(datFilePath);
            if isempty(ksDir)
                ksDir = pwd;
            end
            
            configNames = [{'H3'}, {'H3p'}, {'H2'}, {'P64'}, {'Tetrode32'}];            
            selected = find(ismember(configNames, {probeNames}));
            
                
                
            if ~selected
                chanMapNames = properties(MKilosort);
                probeNames = cellfun(@(x) x(8:end), chanMapNames, 'Uni', false);
                selected = listdlg( ...
                    'PromptString', 'Select a preset configuration', ...
                    'SelectionMode', 'single', ...
                    'ListString', probeNames);
                if isempty(selected)
                    return;
                end
            end
            
            if ~isempty(configNames{selected})
                  
                ops.ksDir = ksDir;
                ops.GPU = isGPU;
                ops.datFilePath = datFilePath;
                % Initialize GPU (will erase any existing GPU arrays)
                if ops.GPU
                    gpuDevice(1);
                end
                
                switch configNames{selected}
                    case 'H3'
                        fChanMap = @VKilosort.SaveChanMapH3;
                        fConfig = @VKilosort.Config64;
                        VKilosort.Kilosort2_5(ops,fChanMap,fConfig);
                    case 'H3p'
                        fChanMap = @VKilosort.SaveChanMapH3p;
                        fConfig = @VKilosort.Config64;
                        VKilosort.Kilosort2_5(ops,fChanMap,fConfig);
                    case 'H2'
                        fChanMap = @VKilosort.SaveChanMapH2;
                        fConfig = @VKilosort.Config64;
                        VKilosort.Kilosort2_5(ops,fChanMap,fConfig);
                    case 'P64'
                        fChanMap = @VKilosort.SaveChanMapP64;
                        fConfig = @VKilosort.Config64;
                        VKilosort.Kilosort2_5(ops,fChanMap,fConfig);
                    case 'Tetrode32'
                        fChanMap = @VKilosort.SaveChanMapTetrode32;
                        fConfig = @VKilosort.TT32ChanConfig;
                        VKilosort.Kilosort2_0(ops,fChanMap,fConfig);
                end
            end
            
            % Choose a preset configuration and channel map functions
            if (isempty(fChanMap) || isempty(fConfig)) && isempty(probeNames)
                chanMapNames = properties(MKilosort);
                probeNames = cellfun(@(x) x(8:end), chanMapNames, 'Uni', false);
                selected = listdlg( ...
                    'PromptString', 'Select a preset configuration', ...
                    'SelectionMode', 'single', ...
                    'ListString', probeNames);
                if isempty(selected)
                    return;
                end

                  % Generate chanMap.mat file
                fChanMap(ksDir);
                
                % Get configuration structure
                ops = fConfig(datFilePath);
                ops.GPU = isGPU;
                                

                %For kilosort 1 to kilosort 3
                ops.trange      = [0 Inf]; % TIME RANGE IN SECONDS TO PROCESS
                ops.sig        = 20;  % spatial smoothness constant for registration
                ops.nblocks    = 4; % blocks for registration. 0 turns it off, 1 does rigid registration. Replaces "datashift" option. 
                ops.sigmaMask        = 20;
                ops.ksDir = ksDir;
                ops.datFilePath = datFilePath;
                % Initialize GPU (will erase any existing GPU arrays)
                if ops.GPU
                    gpuDevice(1);
                end
                
                switch probeNames{selected}
                    case 'H3'
                        fChanMap = @VKilosort.SaveChanMapH3;
                        fConfig = @VKilosort.Config64;
                        VKilosort.Kilosort2_5(ops,fChanMap,fConfig);
                    case 'H3p'
                        fChanMap = @VKilosort.SaveChanMapH3p;
                        fConfig = @VKilosort.Config64;
                        VKilosort.Kilosort2_5(ops,fChanMap,fConfig);
                    case 'H2'
                        fChanMap = @VKilosort.SaveChanMapH2;
                        fConfig = @VKilosort.Config64;
                        VKilosort.Kilosort2_5(ops,fChanMap,fConfig);
                    case 'P64'
                        fChanMap = @VKilosort.SaveChanMapP64;
                        fConfig = @VKilosort.Config64;
                        VKilosort.Kilosort2_5(ops,fChanMap,fConfig);
                    case 'Tetrode32'
                        fChanMap = @VKilosort.SaveChanMapTetrode32;
                        fConfig = @VKilosort.Config32;
                        VKilosort.Kilosort2_5(ops,fChanMap,fConfig);
                end
            end
        end
        function Kilosort2_0(ops,fChanMap,fConfig)
            % Preprocess data and extract spikes for initialization
            % Generate chanMap.mat file
            fChanMap(ops.ksDir);
            
            % Get configuration structure
            ops = fConfig(ops);
            
            
            %For kilosort 1 to kilosort 3
            ops.trange      = [0 Inf]; % TIME RANGE IN SECONDS TO PROCESS
            ops.sig        = 20;  % spatial smoothness constant for registration
            ops.nblocks    = 4; % blocks for registration. 0 turns it off, 1 does rigid registration. Replaces "datashift" option. 
            ops.sigmaMask        = 20;
%             VKilosort.ResetGPU();
            % preprocess data to create temp_wh.dat
            rez = preprocessDataSub(ops);
            
            % time-reordering as a function of drift
            rez = clusterSingleBatches(rez);
            
            % saving here is a good idea, because the rest can be resumed after loading rez
            save(fullfile(ops.ksDir, 'rez.mat'), 'rez', '-v7.3');
            
            % main tracking and template matching algorithm
            rez = learnAndSolve8b(rez);
            
            % final merges
            rez = find_merges(rez, 1);
            
            % final splits by SVD
            rez = splitAllClusters(rez, 1);
            
            % final splits by amplitudes
            rez = splitAllClusters(rez, 0);
            
            % decide on cutoff
            rez = set_cutoff(rez);
            
            fprintf('found %d good units \n', sum(rez.good>0))
            
            % write to Phy
            fprintf('Saving results to Phy  \n')
            rezToPhy(rez, ops.ksDir);
            
            %% if you want to save the results to a Matlab file...
            
            % discard features in final rez file (too slow to save)
            rez.cProj = [];
            rez.cProjPC = [];
            
            % save final results as rez2
            fprintf('Saving final results in rez2  \n')
            fname = fullfile(ops.ksDir, 'rez2.mat');
            save(fname, 'rez', '-v7.3');
            
            % delete temp_wh
            delete(ops.fproc);
        end

        function Kilosort2_5(ops,fChanMap,fConfi)

            % Generate chanMap.mat file
            ops.fChanMap(ops.ksDir);
            
            % Get configuration structure
            ops = ops.fConfig(ops.datFilePath);
            VKilosort.ResetGPU();

            
            %For kilosort 1 to kilosort 3
            ops.trange      = [0 Inf]; % TIME RANGE IN SECONDS TO PROCESS
            ops.sig        = 20;  % spatial smoothness constant for registration
            ops.nblocks    = 4; % blocks for registration. 0 turns it off, 1 does rigid registration. Replaces "datashift" option. 
            ops.sigmaMask        = 20;
        %             [rez, DATA, uproj] = preprocessData(ops);
            rez = preprocessDataSub(ops);
            rez                = datashift2(rez, 1);
            % ORDER OF BATCHES IS NOW RANDOM, controlled by random number generator
            iseed = 1;
            keyboard;
            % main tracking and template matching algorithm
            rez = learnAndSolve8b(rez, iseed);

            % OPTIONAL: remove double-counted spikes - solves issue in which individual spikes are assigned to multiple templates.
            % See issue 29: https://github.com/MouseLand/Kilosort/issues/29
            rez = remove_ks2_duplicate_spikes(rez);

            rez                = find_merges(rez, 1);
           % final splits by SVD
            rez = splitAllClusters(rez, 1);

            % decide on cutoff
            rez = set_cutoff(rez);
            % eliminate widely spread waveforms (likely noise)
            rez.good = get_good_units(rez);

            fprintf('found %d good units \n', sum(rez.good>0))

            % write to Phy
            fprintf('Saving results to Phy  \n')
            rezToPhy(rez, ksDir);
            
            %% if you want to save the results to a Matlab file...

            % discard features in final rez file (too slow to save)
            rez.cProj = [];
            rez.cProjPC = [];

            % final time sorting of spikes, for apps that use st3 directly
            [~, isort]   = sortrows(rez.st3);
            rez.st3      = rez.st3(isort, :);

            % Ensure all GPU arrays are transferred to CPU side before saving to .mat
            rez_fields = fieldnames(rez);
            for i = 1:numel(rez_fields)
                field_name = rez_fields{i};
                if(isa(rez.(field_name), 'gpuArray'))
                    rez.(field_name) = gather(rez.(field_name));
                end
            end

            % save final results as rez2
            fprintf('Saving final results in rez2  \n')
            fname = fullfile(ksDir, 'rez2.mat');
            save(fname, 'rez', '-v7.3');

           
            
            
%             % remove temporary file
%             delete(ops.fproc);
            ResetGPU(); % to free memory space!
            
           
        end
        
        function result = ImportResults(ksDir)
            % Import and process results after sorting and reviewing in TemplateGUI. 
            % (~4300 spikes/second if running on SSD and >10 times slower if on HDD)
            % 
            %   result = MKilosort.ImportResults()
            %   result = MKilosort.ImportResults(ksDir)
            % 
            % Input
            %   ksDir                         The folder which saves Kilosort and Phy outputs. If not provided, 
            %                                 a folder selection window will be prompted. 
            % Outputs
            %   result                        A structure with the following fields.
            %     spike_times                   A [1,nUnit] cell array of [nSpk,1] spike times.
            %     spike_template_ids            A [1,nUnit] cell array of [nSpk,1] spike template IDs.
            %     spike_template_amplitudes     A [1,nUnit] cell array of [nSpk,1] spike template amplitudes.
            %     spike_waveforms               A [1,nUnit] cell array of [nSpk,time] spike waveform extracted from
            %                                   the primary channel of each unit. Scaled by 0.195 microvolt. 
            %     info                          Metadata with the following fields. 
            %       recording_time                The duration of recording in second. 
            %       sample_rate                   Recording sampling rate. 
            %       templates                     A [nTemp,time,nChan] array of all templates used in spike sorting. 
            %       unit_mean_template            A [time,nChan,nUnit] array of mean templates. 
            %       unit_mean_waveform            A [time,nUnit] array of mean waveform. 
            %       unit_channel_ind              Indices of primary channel (after mapping) for each unit. 
            %       channel_map                   Indices that reorders recording channels. 
            % 
            
            if nargin < 1
                ksDir = MBrowse.Folder([], 'Select the Kilosort folder');
                if ~ksDir
                    result = [];
                    return;
                end
            end
            
            disp('Import and process outputs from Kilosort and TemplateGUI');
            
            % Get parameters from params.py by running lines in MATLAB
            %   these include dat_path, dtype, n_channels_dat, sample_rate ...
            fid = fopen(fullfile(ksDir, 'params.py'));
            while ~feof(fid)
                try
                    l = fgetl(fid);
                    eval([l ';']);
                catch
                    %warning('''%s'' cannot be evaluated.', l);
                end
            end
            fclose(fid);
            
            % Map raw data to memory
            datPath = fullfile(ksDir,"amplifier.dat");
            mdat = memmapfile(datPath, 'Format', dtype);
            nSample = numel(mdat.Data) / n_channels_dat;
            mdat = memmapfile(datPath, 'Format', {dtype, [n_channels_dat nSample], 'v'});
            
            % Load Kilosort and TemplateGUI outputs
            chanMap = readNPY(fullfile(ksDir, 'channel_map.npy')) + 1;          % channel map
            spkTimeInd = readNPY(fullfile(ksDir, 'spike_times.npy'));           % sample indices of all spikes
            spkClusterIDs = readNPY(fullfile(ksDir, 'spike_clusters.npy'));     % cluster ID of all spikes
            spkTemplateIDs = readNPY(fullfile(ksDir, 'spike_templates.npy'));   % template ID of all spikes
            spkAmplitudes = readNPY(fullfile(ksDir, 'amplitudes.npy'));         % template amplitude of all spikes
            templates = readNPY(fullfile(ksDir, 'templates.npy'));              % [nTemp, time, chan]
%             qualityTable = struct2table(tdfread(fullfile(ksDir, 'cluster_KSLabel.tsv')));    % contains ID of good clusters
            try 
                qualityTable =  struct2table(tdfread(fullfile(ksDir, 'cluster_info.tsv')));  
                isGoodCluster = ismember(qualityTable.group, 'good');
            catch
                qualityTable = struct2table(tdfread(fullfile(ksDir, 'cluster_KSLabel.tsv')));    % contains ID of good clusters
                isGoodCluster = ismember(qualityTable.KSLabel, 'good');
            end

            % Find IDs of good clusters
             if isNP
                isGoodCluster = sum(ismember(qualityTable.group, 'good'),2)>3 & qualityTable.isi_viol<0.15 & qualityTable.amplitude_cutoff<0.1; 
             else
                 isGoodCluster = sum(ismember(qualityTable.group, 'good'),2)>3 & qualityTable.isi_viol<0.15 & qualityTable.amplitude_cutoff<0.55; 
            end
                
              
            goodClusterIDs = qualityTable.cluster_id(isGoodCluster(:,1))';
            
            % Prepare parameters for waveform extraction
            %   1) Phy uses bandpass between 500Hz and 14.25kHz(.475*sample_rate) to visulize waveform; 
            %      here uses 300Hz highpass to be consistent with Kilosort configuration
            %   2) 82 samples per waveform is consistent with Kilosort template size
            %   3) Consistent with Phy, using samples 3 times of the filter order as margins when filtering
            D = designfilt('highpassiir', ...
                'PassbandFrequency', 300, ...
                'StopbandFrequency', 250, ...
                'StopbandAttenuation', 60, ...
                'PassbandRipple', 0.1, ...
                'SampleRate', sample_rate, ...
                'DesignMethod', 'ellip'); % order of this filter is 8
            nHalfW = 41;
            nMarg = filtord(D) * 3;
            nSide = nHalfW + nMarg;
            
            % Loop through good clusters
            for k = numel(goodClusterIDs) : -1 : 1
                fprintf('Process unit #%i\n', numel(goodClusterIDs)-k+1);
                
                % Get sample indices and template IDs of the current cluster
                isUnit = spkClusterIDs == goodClusterIDs(k);
                stInd = spkTimeInd(isUnit);
                tpID = spkTemplateIDs(isUnit);
                tpAmp = spkAmplitudes(isUnit);
                
                % Compute mean template
                tps = arrayfun(@(i,a) templates(i+1,:,:) * a, tpID, tpAmp, 'Uni', false);
                tps = cat(1, tps{:});
                meanTp = squeeze(mean(tps,1));
                
                % Determine the primary channel
                tpPower = sum(meanTp.^2);
                [~, chanIdx] = max(tpPower);
                
                % Collect raw spike waveforms
                %   when a waveform is at the edge of recording, we pad the waveform to the required length 
                %   by replicating the last value
                rawChanIdx = chanMap(chanIdx);
                W = zeros(nSide*2, numel(stInd));
                for i = 1 : numel(stInd)
                    idxStart = stInd(i) - nSide + 1;
                    idxEnd = stInd(i) + nSide;
                    if idxStart < 1
                        idxStart = 1;
                        w = mdat.Data.v(rawChanIdx, idxStart : idxEnd);
                        wPad = repmat(w(1), 1, nSide*2-numel(w));
                        W(:,i) = [wPad w];
                    elseif idxEnd > nSample
                        idxEnd = nSample;
                        w = mdat.Data.v(rawChanIdx, idxStart : idxEnd);
                        wPad = repmat(w(end), 1, nSide*2-numel(w));
                        W(:,i) = [w wPad];
                    else
                        W(:,i) = mdat.Data.v(rawChanIdx, idxStart : idxEnd);
                    end
                end
                
                % Highpass-filter waveforms
                W = single(filtfilt(D, W));
                W = W(nMarg+1:end-nMarg, :);
                
                % Scale back to original unit in Intan
                W = W * 0.195; % 0.195 is the resolution of Intan. previoely used for scaling up to integers.
                
                % Save reuslts
                uChanInd(k) = chanIdx;
                uSpkTimes{k} = double(stInd) / sample_rate;
                uSpkTemplateID{k} = tpID;
                uSpkTemplateAmp{k} = tpAmp;
                uMeanTemplates(:,:,k) = meanTp;
                uWaveforms{k} = W';
                uMeanWaveform(:,k) = mean(W,2);
            end
            [uChanInd, sortInd] = sort(uChanInd);
            
            % Output data
            result.spike_times = uSpkTimes(sortInd);
            result.spike_template_ids = uSpkTemplateID(sortInd);
            result.spike_template_amplitudes = uSpkTemplateAmp(sortInd);
            result.spike_waveforms = uWaveforms(sortInd);
            result.info.recording_time = nSample / sample_rate;
            result.info.sample_rate = sample_rate;
            result.info.templates = templates;
            result.info.unit_mean_template = uMeanTemplates(:,:,sortInd);
            result.info.unit_mean_waveform = uMeanWaveform(:,sortInd);
            result.info.unit_channel_ind = uChanInd; 
            result.info.channel_map = chanMap;
        end
        
        function ops = Config64(ops)
            % This configuration works with H3, H2, and P-64chan when running on GPU with 3GB+ memory
            
%             ksDir = fileparts(datFilePath);
            ksDir = ops.ksDir;
            ops.GPU                 = 1; % whether to run this code on an Nvidia GPU (much faster, mexGPUall first)
             
            ops.datatype            = 'dat';  % binary ('dat', 'bin') or 'openEphys'
            ops.fbinary             = ops.datFilePath; % will be created for 'openEphys'
            ops.fproc               = fullfile(ksDir, 'temp_wh.dat'); % residual from RAM of preprocessed data
            ops.root                = ksDir; % 'openEphys' only: where raw files ar
%             
            ops.fs                  = 30000;        % sampling rate		(omit if already in chanMap file)
            ops.NchanTOT            = 64;           % total number of channels (omit if already in chanMap file)
            ops.Nchan               = 64;           % number of active channels (omit if already in chanMap file)
%             ops.Nfilt               = 128;  % number of clusters to use (2-4 times more than Nchan, should be a multiple of 32)
            
            % minimum firing rate on a "good" channel (0 to skip)
            ops.minFR = 1/50; 
            % splitting a cluster at the end requires at least this much isolation for each sub-cluster (max = 1)
            ops.AUCsplit = 0.9; 
            % options for channel whitening
            ops.whitening           = 'full'; % type of whitening (default 'full', for 'noSpikes' set options for spike detection below)
            ops.nSkipCov            = 1; % compute whitening matrix from every N-th batch (1)
            ops.whiteningRange      = 32; % how many channels to whiten together (Inf for whole probe whitening, should be fine if Nchan<=32)
            
            % define the channel map as a filename (string) or simply an array
            ops.chanMap             = fullfile(ksDir, 'chanMap.mat'); % make this file using createChannelMapFile.m
            % ops.chanMap = 1:ops.Nchan; % treated as linear probe if a chanMap file
            
            % other options for controlling the model and optimization
            ops.fshigh              = 300;   % frequency for high pass filtering
            % ops.fslow               = 6000;   % frequency for low pass filtering (optional)
            ops.ntbuff              = 64;    % samples of symmetrical buffer for whitening and spike detection
            
            ops.NT                  = 32*1024 + ops.ntbuff;% this is the batch size (try decreasing if out of memory)
            % for GPU should be multiple of 32 + ntbuff		(originally 128*1024+ ops.ntbuff)
            
            % the following options can improve/deteriorate results.
            % when multiple values are provided for an option, the first two are beginning and ending anneal values,
            % the third is the value used in the final pass.
            ops.Th                  = [10 4];    % threshold for detecting spikes on template-filtered data ([6 12 12])
            ops.lam                 = 10;    % large means amplitudes are forced around the mean ([10 30 30])
            ops.momentum            = [20 400];  % start with high momentum and anneal (1./[20 1000])
            ops.reorder         = 1;       % whether to reorder batches for drift correction.             
            ops.nskip           = 25;  % how many batches to skip for determining spike PCs

            
            % spatial constant in um for computing residual variance of spike
            ops.sigmaMask = 30; 
            % threshold crossings for pre-clustering (in PCA projection space)
            ops.ThPre = 8; 

            % options for initializing spikes from data
            
            ops.spkTh               = -4;      % spike threshold in standard deviations (4)
            ops.nfilt_factor        = 4; % max number of clusters per good channel (even temporary ones)
            ops.scaleproc           = 200;   % int16 scaling of whitened data
            ops.nPCs                = 3; % how many PCs to project the spikes into
            ops.useRAM              = 0; % not yet available

            
        end
        
        function ops = Config32(ops)
            % This configuration works with 32-channel probes or tetrodes
            
%             ksDir = fileparts(datFilePath);
            ksDir = ops.ksDir;
            
            ops.GPU                 = 1; % whether to run this code on an Nvidia GPU (much faster, mexGPUall first)
            ops.parfor              = 0; % whether to use parfor to accelerate some parts of the algorithm
            ops.verbose             = 1; % whether to print command line progress
            ops.showfigures         = 1; % whether to plot figures during optimization
            
            ops.datatype            = 'dat';  % binary ('dat', 'bin') or 'openEphys'
            ops.fbinary             = ops.datFilePath; % will be created for 'openEphys'
            ops.fproc               = fullfile(ksDir, 'temp_wh.dat'); % residual from RAM of preprocessed data
            ops.root                = ksDir; % 'openEphys' only: where raw files ar
            
            % ops.fs                  = 30000;        % sampling rate		(omit if already in chanMap file)
            % ops.NchanTOT            = 32;           % total number of channels (omit if already in chanMap file)
            % ops.Nchan               = 32;           % number of active channels (omit if already in chanMap file)
            ops.Nfilt               = 64;  % number of clusters to use (2-4 times more than Nchan, should be a multiple of 32)
            ops.nNeighPC            = 12; % visualization only (Phy): number of channnels to mask the PCs, leave empty to skip (12)
            ops.nNeigh              = 16; % visualization only (Phy): number of neighboring templates to retain projections of (16)
            
            % options for channel whitening
            ops.whitening           = 'full'; % type of whitening (default 'full', for 'noSpikes' set options for spike detection below)
            ops.nSkipCov            = 1; % compute whitening matrix from every N-th batch (1)
            ops.whiteningRange      = 32; % how many channels to whiten together (Inf for whole probe whitening, should be fine if Nchan<=32)
            
            % define the channel map as a filename (string) or simply an array
            ops.chanMap             = fullfile(ksDir, 'chanMap.mat'); % make this file using createChannelMapFile.m
            ops.criterionNoiseChannels = 0.2; % fraction of "noise" templates allowed to span all channel groups (see createChannelMapFile for more info).
            % ops.chanMap = 1:ops.Nchan; % treated as linear probe if a chanMap file
            
            % other options for controlling the model and optimization
            ops.Nrank               = 3;    % matrix rank of spike template model (3)
            ops.nfullpasses         = 6;    % number of complete passes through data during optimization (6)
            ops.maxFR               = 20000;  % maximum number of spikes to extract per batch (20000)
            ops.fshigh              = 300;   % frequency for high pass filtering
            % ops.fslow               = 6000;   % frequency for low pass filtering (optional)
            ops.ntbuff              = 64;    % samples of symmetrical buffer for whitening and spike detection
            ops.scaleproc           = 200;   % int16 scaling of whitened data
            ops.NT                  = 64*1024*2 + ops.ntbuff;% this is the batch size (try decreasing if out of memory)
            % for GPU should be multiple of 32 + ntbuff		(originally 128*1024+ ops.ntbuff)
            
            % the following options can improve/deteriorate results.
            % when multiple values are provided for an option, the first two are beginning and ending anneal values,
            % the third is the value used in the final pass.
            ops.Th                  = [4 10 10];    % threshold for detecting spikes on template-filtered data ([6 12 12])
            ops.lam                 = [5 20 20];    % large means amplitudes are forced around the mean ([10 30 30])
            ops.nannealpasses       = 4;            % should be less than nfullpasses (4)
            ops.momentum            = 1./[20 400];  % start with high momentum and anneal (1./[20 1000])
            ops.shuffle_clusters    = 1;            % allow merges and splits during optimization (1)
            ops.mergeT              = .1;           % upper threshold for merging (.1)
            ops.splitT              = .1;           % lower threshold for splitting (.1)
            
            % options for initializing spikes from data
            ops.initialize          = 'fromData';    %'fromData' or 'no'
            ops.spkTh               = -4;      % spike threshold in standard deviations (4)
            ops.loc_range           = [3 1];   % ranges to detect peaks; plus/minus in time and channel ([3 1])
            ops.long_range          = [30 6];  % ranges to detect isolated peaks ([30 6])
            ops.maskMaxChannels     = 5;       % how many channels to mask up/down ([5])
            ops.crit                = .65;     % upper criterion for discarding spike repeates (0.65)
            ops.nFiltMax            = 10000;   % maximum "unique" spikes to consider (10000)
            
            % load predefined principal components (visualization only (Phy): used for features)
            dd                      = load('PCspikes2.mat'); % you might want to recompute this from your own data
            ops.wPCA                = dd.Wi(:,1:7);   % PCs
            
            % options for posthoc merges (under construction)
            ops.fracse              = 0.1; % binning step along discriminant axis for posthoc merges (in units of sd)
            ops.epu                 = Inf;
            
            ops.ForceMaxRAMforDat   = 20e9; % maximum RAM the algorithm will try to use; on Windows it will autodetect.
            
        end
        
        function ops = TT32ChanConfig(ops)
            ksDir = ops.ksDir;
            % ops.chanMap             = 'C:\CODE\GitHub\jawpro\JawProMatlab\chanMap.mat';
            % % ops.chanMap = 1:ops.Nchan; % treated as linear probe if no chanMap file
            % 
            % % sample rate
            ops.fs = 30000;
            % 
            % % frequency for high pass filtering (150)
            ops.fshigh = 300;
            ops.CAR = false;
            % 
            % % minimum firing rate on a "good" channel (0 to skip)
            ops.minfr_goodchannels = 0;
            % 
            % % threshold on projections (like in Kilosort1, can be different for last pass like [10 4])
            ops.Th = [9 2];
            % 
            % % how important is the amplitude penalty (like in Kilosort1, 0 means not used, 10 is average, 50 is a lot)
            ops.lam = 5;
            % 
            % % splitting a cluster at the end requires at least this much isolation for each sub-cluster (max = 1)
            ops.AUCsplit = 0.9;
            % 
            % % minimum spike rate (Hz), if a cluster falls below this for too long it gets removed
            ops.minFR = 0;
            % 
            % % number of samples to average over (annealed from first to second value)
            ops.momentum = [30 500];
            % 
            % % spatial constant in um for computing residual variance of spike
            ops.sigmaMask = 30;
            % 
            % % threshold crossings for pre-clustering (in PCA projection space)
            ops.ThPre = 8;
            ops.ksDir = ksDir;
            %Add chanMap
            ops.chanMap             = fullfile(ksDir, 'chanMap.mat'); % make this file using createChannelMapFile.m

            % danger, changing these settings can lead to fatal errors
            % options for determining PCs
            ops.spkTh           = -6;      % spike threshold in standard deviations (-6)
            ops.reorder         = 1;       % whether to reorder batches for drift correction. 
            ops.nskip           = 25;  % how many batches to skip for determining spike PCs
            
            ops.GPU                 = 1; % has to be 1, no CPU version yet, sorry
            % ops.Nfilt               = 1024; % max number of clusters
            ops.nfilt_factor        = 4; % max number of clusters per good channel (even temporary ones)
            ops.ntbuff              = 64;    % samples of symmetrical buffer for whitening and spike detection
            ops.NT                  = 64*1024+ ops.ntbuff; % must be multiple of 32 + ntbuff. This is the batch size (try decreasing if out of memory). 
            ops.whiteningRange      = 32; % number of channels to use for whitening each channel
            ops.nSkipCov            = 25; % compute whitening matrix from every N-th batch
            ops.scaleproc           = 200;   % int16 scaling of whitened data
            ops.nPCs                = 3; % how many PCs to project the spikes into
            ops.useRAM              = 0; % not yet available
            ops.trange = [0 Inf]; % time range to sort
            
            ops.fproc       = fullfile(ksDir, 'temp_wh.dat'); % proc file on a fast SSD

            %
            ops.GPU                 = 1; % whether to run this code on an Nvidia GPU (much faster, mexGPUall first)
            % % ops.parfor              = 0; % whether to use parfor to accelerate some parts of the algorithm
            % % ops.verbose             = 1; % whether to print command line progress
            ops.showfigures         = 1; % whether to plot figures during optimization
            % % 
            % % ops.datatype            = 'dat';  % binary ('dat', 'bin') or 'openEphys'
            ops.fbinary             = ops.datFilePath; % will be created for 'openEphys'
            % % ops.fproc               = fullfile(ksDir, 'temp_wh.dat'); % residual from RAM of preprocessed data
            % % ops.root                = ksDir; % 'openEphys' only: where raw files ar
            % 
            ops.NchanTOT            = 32;           % total number of channels (omit if already in chanMap file)
            % ops.Nchan               = 28;           % number of active channels (omit if already in chanMap file)
            % ops.Nfilt               = 56;  % number of clusters to use (2-4 times more than Nchan, should be a multiple of 32)
            % % ops.nNeighPC            = 12; % visualization only (Phy): number of channnels to mask the PCs, leave empty to skip (12)
            % % ops.nNeigh              = 16; % visualization only (Phy): number of neighboring templates to retain projections of (16)
            % 
            % % options for channel whitening
            % ops.whitening           = 'full'; % type of whitening (default 'full', for 'noSpikes' set options for spike detection below)
            % ops.nSkipCov            = 1; % compute whitening matrix from every N-th batch (1)
            % ops.whiteningRange      = Inf; % how many channels to whiten together (Inf for whole probe whitening, should be fine if Nchan<=32)
            % 
            % % define the channel map as a filename (string) or simply an array
            % ops.criterionNoiseChannels = 0.2; % fraction of "noise" templates allowed to span all channel groups (see createChannelMapFile for more info).
            % % ops.chanMap = 1:ops.Nchan; % treated as linear probe if a chanMap file
            % 
            % % other options for controlling the model and optimization
            % ops.Nrank               = 3;    % matrix rank of spike template model (3)
            % ops.nfullpasses         = 3;    % number of complete passes through data during optimization (6)
            % ops.maxFR               = 20000;  % maximum number of spikes to extract per batch (20000)
            % ops.fshigh              = 300;   % frequency for high pass filtering
            ops.fslow               = 6000;   % frequency for low pass filtering (optional)
            % ops.ntbuff              = 64;    % samples of symmetrical buffer for whitening and spike detection
            % ops.scaleproc           = 200;   % int16 scaling of whitened data
            % ops.NT                  = 32*1024 + ops.ntbuff;% this is the batch size (try decreasing if out of memory)
            % % for GPU should be multiple of 32 + ntbuff		(originally 128*1024+ ops.ntbuff)
            % 
            % % the following options can improve/deteriorate results.
            % % when multiple values are provided for an option, the first two are beginning and ending anneal values,
            % % the third is the value used in the final pass.
            % ops.Th                  = [4 4 4];    % threshold for detecting spikes on template-filtered data ([6 12 12])
            % ops.lam                 = 1;    % large means amplitudes are forced around the mean ([10 30 30])
            % ops.nannealpasses       = 2;            % should be less than nfullpasses (4)
            % % ops.momentum            = 1./[20 400];  % start with high momentum and anneal (1./[20 1000])
            % % ops.shuffle_clusters    = 1;            % allow merges and splits during optimization (1)
            % ops.mergeT              = .1;           % upper threshold for merging (.1)
            % ops.splitT              = .1;           % lower threshold for splitting (.1)
            % 
            % % options for initializing spikes from data
            % ops.initialize          = 'fromData';    %'fromData' or 'no'
            % ops.spkTh               = -4;      % spike threshold in standard deviations (4), positive va
            % ops.loc_range           = [3 2];   % ranges to detect peaks; plus/minus in time and channel ([3 1])
            % ops.long_range          = [30 4];  % ranges to detect isolated peaks ([30 6])
            % ops.maskMaxChannels     = 5;       % how many channels to mask up/down ([5])
            % ops.crit                = .65;     % upper criterion for discarding spike repeates (0.65)
            % ops.nFiltMax            = 10000;   % maximum "unique" spikes to consider (10000)
        end
         % Helper function
        function ResetGPU()
            if isGPU
                reset(parallel.gpu.GPUDevice.current);
            end
        end

        function SaveChanMapH3(ksDir)
            % Create a channel map file
            
            % here I know a priori what order my channels are in.  So I just manually
            % make a list of channel indices (and give
            % an index to dead channels too). chanMap(1) is the row in the raw binary
            % file for the first channel. chanMap(1:2) = [33 34] in my case, which happen to
            % be dead channels.
            chanMap = VKilosort.chanMapH3;
            chanMap0ind = chanMap - 1;
            % chanMap order in 'F:\O'Connor lab data (other than
            % Intan)\electrophysiology\Silicon Probe\correspondence of probe
            % channels.xls' plus one (so that the chanNum will not have zero)
            Nchannels = size(VKilosort.chanMapH3,2);
            % the first thing Kilosort does is reorder the data with data = data(chanMap, :).
            % Now we declare which channels are "connected" in this normal ordering,
            % meaning not dead or used for non-ephys data
            connected = true(Nchannels, 1);
            % connected(1:2) = 0;
            
            % now we define the horizontal (x) and vertical (y) coordinates of these
            % 34 channels. For dead or nonephys channels the values won't matter. Again
            % I will take this information from the specifications of the probe. These
            % are in um here, but the absolute scaling doesn't really matter in the
            % algorithm.
            xcoords = zeros(1,64);
            ycoords = (0:(Nchannels-1))*20;
            
            % Often, multi-shank probes or tetrodes will be organized into groups of
            % channels that cannot possibly share spikes with the rest of the probe. This helps
            % the algorithm discard noisy templates shared across groups. In
            % this case, we set kcoords to indicate which group the channel belongs to.
            % In our case all channels are on the same shank in a single group so we
            % assign them all to group 1.
            kcoords   = ones(Nchannels,1); % grouping of channels (i.e. tetrode groups)

            
            % at this point in Kilosort we do data = data(connected, :), ycoords =
            % ycoords(connected), xcoords = xcoords(connected) and kcoords =
            % kcoords(connected) and no more channel map information is needed (in particular
            % no "adjacency graphs" like in KlustaKwik).
            % Now we can save our channel map for the eMouse.
            
            % would be good to also save the sampling frequency here
            fs = 30000;
            
            save(fullfile(ksDir, 'chanMap.mat'), 'chanMap', 'connected', 'xcoords', 'ycoords', 'kcoords', 'fs')
        end

        function SaveChanMapH3p(ksDir)
            % Create a channel map file
            
            % here I know a priori what order my channels are in.  So I just manually
            % make a list of channel indices (and give
            % an index to dead channels too). chanMap(1) is the row in the raw binary
            % file for the first channel. chanMap(1:2) = [33 34] in my case, which happen to
            % be dead channels.
            chanMap = VKilosort.chanMapH3p;
            chanMap0ind = chanMap - 1;
            % chanMap order in 'F:\O'Connor lab data (other than
            % Intan)\electrophysiology\Silicon Probe\correspondence of probe
            % channels.xls' plus one (so that the chanNum will not have zero)
            Nchannels = size(VKilosort.chanMapH3p,2);
            % the first thing Kilosort does is reorder the data with data = data(chanMap, :).
            % Now we declare which channels are "connected" in this normal ordering,
            % meaning not dead or used for non-ephys data
            connected = true(Nchannels, 1);
            % connected(1:2) = 0;
            
            % now we define the horizontal (x) and vertical (y) coordinates of these
            % 34 channels. For dead or nonephys channels the values won't matter. Again
            % I will take this information from the specifications of the probe. These
            % are in um here, but the absolute scaling doesn't really matter in the
            % algorithm.
            xcoords = zeros(1,64);
            ycoords = (0:(Nchannels-1))*20;
            
            % Often, multi-shank probes or tetrodes will be organized into groups of
            % channels that cannot possibly share spikes with the rest of the probe. This helps
            % the algorithm discard noisy templates shared across groups. In
            % this case, we set kcoords to indicate which group the channel belongs to.
            % In our case all channels are on the same shank in a single group so we
            % assign them all to group 1.
            kcoords   = ones(Nchannels,1); % grouping of channels (i.e. tetrode groups)

            
            % at this point in Kilosort we do data = data(connected, :), ycoords =
            % ycoords(connected), xcoords = xcoords(connected) and kcoords =
            % kcoords(connected) and no more channel map information is needed (in particular
            % no "adjacency graphs" like in KlustaKwik).
            % Now we can save our channel map for the eMouse.
            
            % would be good to also save the sampling frequency here
            fs = 30000;
            
            save(fullfile(ksDir, 'chanMap.mat'), 'chanMap', 'connected', 'xcoords', 'ycoords', 'kcoords', 'fs')
        end
        
        function SaveChanMapH2(ksDir)
            % Create a channel map file
            
            chanMap = MKilosort.chanMapH2;  % channel order
            connected = true(1, 64);    % dead channels are set to false
            
            % Probe geometry
            xcoords = [zeros(1,32), zeros(1,32)+250];
            ycoords = [(0:31)*25, (0:31)*25];
            
            % Channel grouping
            kcoords = [ones(1,32), ones(1,32)*2];
            
            fs = 30000;                 % sampling frequency
            
            save(fullfile(ksDir, 'chanMap.mat'), 'chanMap', 'connected', 'xcoords', 'ycoords', 'kcoords', 'fs')
        end
        
        function SaveChanMapP64(ksDir)
            % Create a channel map file
            
            chanMap = VKilosort.chanMapP64; % channel order
            connected = true(1, 64);    % dead channels are set to false
            
            % Probe geometry
            xshank = repmat([22.5 0], 1, 8);
            xcoords = [xshank, xshank+250, xshank+500, xshank+750];
            ycoords = repmat((0:15)*12.5, 1, 4);
            
            % Channel grouping
            kcoords = [ones(1,16), ones(1,16)*2, ones(1,16)*3, ones(1,16)*4];
            
            fs = 30000;                 % sampling frequency
            
            save(fullfile(ksDir, 'chanMap.mat'), 'chanMap', 'connected', 'xcoords', 'ycoords', 'kcoords', 'fs')
        end
        
        function SaveChanMapTetrode32(ksDir)
            % Create a channel map file
            
            chanMap = VKilosort.chanMapTetrode32; % channel order
            connected = true(1, 32);    % dead channels are set to false
            
            % Probe geometry
            xcoords = zeros(1,32);
            ycoords = ((0:31) + repelem(0:7, 4))*10;
            
            % Channel grouping
            kcoords = repelem(1:8, 4);
            
            fs = 30000;                 % sampling frequency
            
            save(fullfile(ksDir, 'chanMap.mat'), 'chanMap', 'connected', 'xcoords', 'ycoords', 'kcoords', 'fs')
        end
    end
end

