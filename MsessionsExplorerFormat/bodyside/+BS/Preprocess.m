classdef Preprocess
    % Modify Many's preprocessing pipeline_YT 022819
    
    methods(Static)
        % Data files to master file
        function intanOps = GetIntanOptions(ksDir)
            
            % customized options for preprocessing Intan Data
            intanOps = MIntan.GetOptions(); % Initialize options
            intanOps(2) = intanOps(1); % Replace aux with another amplifier processing
            intanOps(1).downsampleFactor = 30; % The default Intan sampling rate is 30k Hz and 1000Hz is more than enough for any LFP/EEG analysis 
            intanOps(3).downsampleFactor = 30; % ADC signal: 1000Hz should be enough

            % options for Kilosort
            % 1) Intan amplifier data was acquired with 16-bit resolution but was converted to double precision
            %    numbers. The resulting quantization is 0.195. Kilosort expects 16-bit signed integer. Thus, 
            %    we use the following function to scale amplifier data up to integer values and then cast
            %    them to int16. 
            intanOps(2).signalFunc = @(x) int16(x / 0.195);
            intanOps(2).isReturn = false; % 2) No need to return original amplifier data
            intanOps(2).binFilePath = [ksDir,'\binary_data.dat']; % 3) Specify the path of binary file
        end
        
        function sInfoYT = GetSessionInfo(MouseName, seshDate, recSite, Genotype, Sex, Manipulation, inhSite, seshType, DoB, behvTask)
            sInfo.MouseName = MouseName;
            sInfo.seshDate = seshDate;
            sInfo.recSite = recSite;
            sInfo.Genotype = Genotype;
            sInfo.Sex = Sex;
            sInfo.Manipulation = Manipulation;
            sInfo.inhSite = inhSite;
            sInfo.seshType = seshType;
            sInfo.DoB = DoB;
            sInfo.behvTask = behvTask;
            
        end
       
        function ADC2SE(intanData, se, isNP)
        
            adc_data = intanData.adc_data;
            
            % Separate channels into different cells
            adcSize = size(intanData.adc_data);
            adcData = mat2cell(intanData.adc_data, adcSize(1), ones(1,adcSize(2)));

            adcData = cellfun(@(x) x*10^-4, adcData, 'UniformOutput',false);
            
            % Derive sampling frequency
            adcFs = 1 / diff(intanData.adc_time(1:2));
            if ~isNP
            % Find channel names
                adcChanName = {'rightStim', 'visStim', 'lLick', 'rLick', 'opto','vTube', 'hTube', 'leftStim'}; % Eric's data has 8 channels.
            else
                adcChanName = {'rightStim', 'leftStim', 'lLick', 'rLick', 'opto','vTube', 'hTube', 'visStim'}; % Eric's data has 8 channels.

            end
            adcChanName = adcChanName(1:adcSize(2));

            % Import adc time
            adcTime = intanData.adc_time;
            
            % Import trialStartTime
            trialStartTime = se.userData.intanInfo.trialStartTime;
            
            % Make table
            [tb, preTb] = MSessionExplorer.MakeTimeSeriesTable(adcTime, adcData, ...
                'DelimiterTimes', trialStartTime,...
                'variableNames', adcChanName);

            % Save to SE
            se.userData.preTaskData.adc = preTb;
            se.SetTable('adc', tb, 'timeSeries');
        end        
        
        function LFP2SE(intanData, se, sortingMethod)

            % Separate channels into different cells
            ampSize = size(intanData.amplifier_data);
            amplifierData = mat2cell(intanData.amplifier_data, ampSize(1), ones(1,ampSize(2)));

            % Derive sampling frequency
            ampFs = 1 / diff(intanData.amplifier_time(1:2));
            
            switch sortingMethod
                case 'ks'
                    % Find channel names
                    chanMap = se.userData.sessionInfo.channel_map.chanMap;
                    chanMap = num2cell(chanMap);
                    chanMap = cellfun(@(x) strcat('channel_', num2str(x)), chanMap, 'UniformOutput', false);
                    chanMap = chanMap(1:ampSize(2));

                    % Import amplifier time
                    amplifierTime = intanData.amplifier_time;

                    % Import trialStartTime
                    trialStartTime = se.userData.intanInfo.trialStartTime;

                    % Make table
                    [tb, preTb] = MSessionExplorer.MakeTimeSeriesTable(...
                        amplifierTime,...
                        amplifierData,...
                        'DelimiterTimes', trialStartTime,...
                        'variableNames', chanMap);
                case 'mclust'
                     % Import amplifier time
                    amplifierTime = intanData.amplifier_time;

                    % Import trialStartTime
                    trialStartTime = se.userData.intanInfo.trialStartTime;

                    % Make table
                    [tb, preTb] = MSessionExplorer.MakeTimeSeriesTable(...
                        amplifierTime,...
                        amplifierData,...
                        'DelimiterTimes', trialStartTime);
            end
            
            % Save to SE
            se.userData.preTaskData.LFP = preTb;
            se.SetTable('LFP', tb, 'timeSeries');
        end    
        
        function Spike2SE(spikeData, se)
            
            % Import trialStartTime
            trialStartTime = se.userData.intanInfo.trialStartTime;
            
            % Creat unit names
            unit_names = num2cell(1:size(spikeData.spike_times, 2));
            unit_names = cellfun(@(x) strcat('unit_', num2str(x)), unit_names, 'UniformOutput', false);
            unit_names = unit_names(1:size(spikeData.spike_times, 2));

            % Make table
            [tb, preTb] = MSessionExplorer.MakeEventTimesTable(...
                spikeData.spike_times, ...
                'delimiterTimes', trialStartTime,...
                'variableNames', unit_names);
            % Save to SE 
            se.userData.spikeInfo = spikeData.info;
            se.userData.spikeInfo.spike_waveforms = spikeData.spike_waveforms;
            se.userData.spikeInfo.spike_template_ids = spikeData.spike_template_ids;
            se.userData.spikeInfo.spike_template_amplitudes = spikeData.spike_template_amplitudes;
            se.userData.preTaskData.spikeTime = preTb;
            se.SetTable('spikeTime', tb, 'eventTimes');

        end        
        
        function BCT2SE(bctData, se, intan, varargin)
            % Align bct trial numbers with intan trial numbers
            % Make bev table and save to se
            % bctNums vs. intanNums

            % Bcontrol and Intan data can not be aligned simply by trial
            % number. Need some corrections. (Bcontrol may start from 0 or
            % 1).
            % See TrialArray.m 
            %Edited YT_CM's code to accomodate BS trials 11/09/21
            
            % Import trial numbers from Bcontrol data
            bctNums = bctData.trialNums;
            % quick fix for sessions with catch trials
            % Repeated trial number for catch trials in Bcontrol
            bctNums = num2cell(0:(length(bctNums)-1)).'; 
            
            if numel(varargin)>2
                inhSite = varargin{1};
                genotype = varargin{2};
                manipulation = varargin{3};
            elseif numel(varargin)>0
                inhSite = varargin{1};
                genotype = varargin{2};
            end
             
            
            if intan
                intNums = transpose(se.userData.intanInfo.trialNums);
                
                
    
                % Convert Trial response from double to cell
                bctTrialResponse = num2cell(bctData.trialResponse);
    
                
                % Align bctNums and intNums by trimming front and back trials
                if intNums(1) > bctNums{1}
                    frontDiff = abs(intNums(1) - bctNums{1});
                    bctNums = bctNums(frontDiff:end);
                    bctBlockType = bctData.blockType(frontDiff:end);
                    bctTrialType = bctData.trialType(frontDiff:end);
                    bctTrialResponse = bctTrialResponse(frontDiff:end);
                    bctLeftStimType = bctData.leftStimType(frontDiff:end);
                    bctRightStimType = bctData.rightStimType(frontDiff:end);
                elseif intNums(1) < bctNums{1} 
                    frontDiff = abs(intNums(1) - bctNums{1});
                    bctBlockType = bctData.blockType;
                    bctTrialType = bctData.trialType;
                    bctTrialResponse = bctTrialResponse;
                    bctLeftStimType = bctData.leftStimType;
                    bctRightStimType = bctData.rightStimType;
                    se.RemoveEpochs(1:frontDiff);
                    intNums = intNums(1:frontDiff);
                else
                    bctBlockType = bctData.blockType;
                    bctTrialType = bctData.trialType;
                    bctTrialResponse = bctTrialResponse;
                    bctLeftStimType = bctData.leftStimType;
                    bctRightStimType = bctData.rightStimType;
                end 
    
                
                if intNums(end) > bctNums{end}  
                    backDiff = abs(intNums(end)-bctNums{end});
                    se.RemoveEpochs(length(intNums)-backDiff+2:length(intNums));
                    intNums = intNums(1:end-backDiff+1);
                elseif intNums(end) < bctNums{end}
                    backDiff = abs(intNums(end)-bctNums{end});
                    bctNums = bctNums(1:end-backDiff-1);
                    bctBlockType = bctBlockType(1:end-backDiff-1);
                    bctTrialType = bctTrialType(1:end-backDiff-1);
                    bctTrialResponse = bctTrialResponse(1:end-backDiff-1);
                    bctLeftStimType = bctLeftStimType(1:end-backDiff-1);
                    bctRightStimType = bctRightStimType(1:end-backDiff-1);
                end     
    
    
                if size(intNums) == size(bctNums)
                    disp('Intan and Bcont trials are correctly aligned')
                else
                    error('Intan and Bcont trials are not aligned')
                end
                % update intNums and trialStartTime
                se.userData.intanInfo.trialNums = intNums;
                se.userData.intanInfo.trialStartTime = se.userData.intanInfo.trialStartTime(1:end-backDiff+1);
            else
                 % Convert Trial response from double to cell
                bctTrialResponse = num2cell(bctData.trialResponse);
                bctBlockType = bctData.blockType;
                bctTrialType = bctData.trialType;
                bctTrialResponse = bctTrialResponse;
                bctLeftStimType = bctData.leftStimType;
                bctRightStimType = bctData.rightStimType;
            end
           
            %add mousename and session date
            mouseName= repelem({bctData.mouseName}, height(bctNums))';
            sessDate = repelem({bctData.sessionDate}, height(bctNums))';

            % Create a table for behavior values
            if ~exist('inhSite', 'var')
                varNames_bct = {'mouseName','sessDate', 'bct_trialNum', 'blockType', 'trialType', 'response', 'leftStimType', 'rightStimType'};
                try
                    bevTable_bct = table(mouseName, sessDate,  bctNums, bctBlockType, bctTrialType, bctTrialResponse, bctLeftStimType, bctRightStimType,...
                        'VariableNames',varNames_bct);
                catch
                    
                    varNames_bct = {'mouseName','sessDate','bct_trialNum', 'trialType', 'response', 'leftStimType', 'rightStimType'};
                    try
                        bevTable_bct = table(mouseName(1:height(bctNums)), sessDate(1:height(bctNums)), bctNums(1:height(bctNums)), bctTrialType(1:height(bctNums)), ...
                            bctTrialResponse(1:height(bctNums)), bctLeftStimType(1:height(bctNums))', bctRightStimType(1:height(bctNums))',...
                            'VariableNames',varNames_bct);
                    catch
                        
                        bevTable_bct = table(mouseName(1:height(bctNums)), sessDate(1:height(bctNums)), bctNums(1:height(bctNums)), bctTrialType(1:height(bctNums)), ...
                            bctTrialResponse(1:height(bctNums)), bctLeftStimType(1:height(bctNums)), bctRightStimType(1:height(bctNums)),...
                            'VariableNames',varNames_bct);
                    end
                end
            else
                inhSites = repelem(inhSite, height(bctNums))';
                genotypes = repelem(genotype, height(bctNums))';
                manipulations = repelem(manipulation, height(bctNums))';
                varNames_bct = {'mouseName','sessDate','inhSite', 'Genotype', 'isInhibition', 'bct_trialNum', 'blockType', 'trialType', 'response', 'leftStimType', 'rightStimType'};
                try
                    bevTable_bct = table(mouseName, sessDate, inhSites, genotypes, manipulations, bctNums, bctBlockType, bctTrialType, bctTrialResponse, bctLeftStimType, bctRightStimType,...
                        'VariableNames',varNames_bct);
                catch
                    
                    varNames_bct = {'mouseName','sessDate','inhSite', 'Genotype', 'isInhibition', 'bct_trialNum', 'trialType', 'response', 'leftStimType', 'rightStimType'};
                    try
                        bevTable_bct = table(mouseName(1:height(bctNums)), sessDate(1:height(bctNums)), inhSites(1:height(bctNums)), ...
                            genotypes(1:height(bctNums)),manipulations(1:height(bctNums)),bctNums(1:height(bctNums)), bctTrialType(1:height(bctNums)), ...
                            bctTrialResponse(1:height(bctNums)), bctLeftStimType(1:height(bctNums))', bctRightStimType(1:height(bctNums))',...
                            'VariableNames',varNames_bct);
                    catch
                        try
                            bevTable_bct = table(mouseName(1:height(bctNums)), sessDate(1:height(bctNums)), inhSites(1:height(bctNums)), ...
                            genotypes(1:height(bctNums)),manipulations(1:height(bctNums)),bctNums(1:height(bctNums)), bctTrialType(1:height(bctNums)), ...
                            bctTrialResponse(1:height(bctNums)), bctLeftStimType(1:height(bctNums)), bctRightStimType(1:height(bctNums)),...
                            'VariableNames',varNames_bct);
                        catch
                           try 
                                bevTable_bct = table(mouseName(1:height(bctNums)), sessDate(1:height(bctNums)), inhSites(1:height(bctNums)), ...
                                    genotypes(1:height(bctNums)), bctNums(1:height(bctNums)), bctTrialType(1:height(bctNums)), ...
                                    bctTrialResponse(1:height(bctNums)), bctLeftStimType(1:height(bctNums)), bctRightStimType(1:height(bctNums)),...
                                    'VariableNames',varNames_bct);
                           catch
                               bevTable_bct = table(mouseName(1:height(bctNums)), sessDate(1:height(bctNums)), inhSites(1:height(bctNums)), ...
                                    genotypes(1:height(bctNums)), bctNums(1:height(bctNums)), bctTrialType(1:height(bctNums)), ...
                                    bctTrialResponse(1:height(bctNums)), bctLeftStimType(1:height(bctNums)), bctRightStimType(1:height(bctNums)),...
                                    'VariableNames',varNames_bct);
                           end
                       end
                    end
                end
            end

            
            
            % Creat a trial type map
            % regular contigency: Rstim-lick Right, Lstim-lick Left
            
            result = nan(height(bevTable_bct.trialType),1);
            for trialNums =1:height(bevTable_bct.trialType)
                bevTable_bct.blockType{trialNums}= '2piezos';
            end
            RRCind = ismember(bevTable_bct.blockType, '2piezos') & ismember(bevTable_bct.trialType, 'Stim_Som_Right_Opto') & ...
                ismember(cell2mat(bevTable_bct.response), [1]) ;
            result(RRCind) = 1;
            RLCind = ismember(bevTable_bct.blockType, '2piezos') & ismember(bevTable_bct.trialType, 'Stim_Som_Right_Opto') & ...
                ismember(cell2mat(bevTable_bct.response), [2]) ;
            result(RLCind) = 0;

%             RNCind = ismember(bevTable_bct.blockType, '2piezos') & ismember(bevTable_bct.trialType, 'Stim_Som_Right_Opto') & ...
%                 ismember(cell2mat(bevTable_bct.response), [0]) ;
            

            LRCind = ismember(bevTable_bct.blockType, '2piezos') & ismember(bevTable_bct.trialType, 'Stim_Som_Left_Opto') & ...
                ismember(cell2mat(bevTable_bct.response), [1]) ;
            result(LRCind) = 0;

            LLCind = ismember(bevTable_bct.blockType, '2piezos') & ismember(bevTable_bct.trialType, 'Stim_Som_Left_Opto') & ...
                ismember(cell2mat(bevTable_bct.response), [2]) ;
            result(LLCind) = 1;
%             LNCind = ismember(bevTable_bct.blockType, '2piezos') & ismember(bevTable_bct.trialType, 'Stim_Som_Left_Opto') & ...
%                 ismember(cell2mat(bevTable_bct.response), [0]) ;   

            RRNind = ismember(bevTable_bct.blockType, '2piezos') & (ismember(bevTable_bct.trialType, 'Stim_Som_Right_NoCue') | ismember(bevTable_bct.trialType, 'Stim_Som_Right'))...
                & ismember(cell2mat(bevTable_bct.response), [1]) ;
            result(RRNind) = 1;
            RLNind = ismember(bevTable_bct.blockType, '2piezos') & (ismember(bevTable_bct.trialType, 'Stim_Som_Right_NoCue') | ismember(bevTable_bct.trialType, 'Stim_Som_Right')) & ...
                ismember(cell2mat(bevTable_bct.response), [2]) ;
            result(RLNind) = 0;
%             RNNind = ismember(bevTable_bct.blockType, '2piezos') & (ismember(bevTable_bct.trialType, 'Stim_Som_Right_NoCue') | ismember(bevTable_bct.trialType, 'Stim_Som_Right')) & ...
%                 ismember(cell2mat(bevTable_bct.response), [0]) ;

            LRNind = ismember(bevTable_bct.blockType, '2piezos') & (ismember(bevTable_bct.trialType, 'Stim_Som_Left_NoCue') | ismember(bevTable_bct.trialType, 'Stim_Som_Left')) & ...
                ismember(cell2mat(bevTable_bct.response), [1]) ;
            result(LRNind) = 0;
            LLNind = ismember(bevTable_bct.blockType, '2piezos') & (ismember(bevTable_bct.trialType, 'Stim_Som_Left_NoCue') | ismember(bevTable_bct.trialType, 'Stim_Som_Left')) & ...
                ismember(cell2mat(bevTable_bct.response), [2]) ;
            result(LLNind) = 1;

%             LNNind = ismember(bevTable_bct.blockType, '2piezos') & (ismember(bevTable_bct.trialType, 'Stim_Som_Left_NoCue') | ismember(bevTable_bct.trialType, 'Stim_Som_Left')) & ...
%                 ismember(cell2mat(bevTable_bct.response), [0]) ;
            
            
           

            varNames_ttmap = {'result'};

            ttMap = table(result, ...
                    'VariableNames',varNames_ttmap); % all results combined to 1 and 0s. Nan means no lick
                
            % Merge bct table with ttMap
            bevTable = [bevTable_bct, ttMap];
            se.userData.bctData = bctData.allData;
            % Save to SE
            se.SetTable('behavValue', bevTable, 'eventValues');
        end
        
        function GetEventTimes(se, isNP)
            % Find event times for leftStim, rightStim, optoStim, lickOnset
            % Import data 

            
            adcSig = se.GetTable('adc'); % parssed trials
            time = adcSig.time;
            leftStim = adcSig.leftStim;
            rightStim = adcSig.rightStim;
            lLick = adcSig.lLick;
            rLick = adcSig.rLick;
            opto = adcSig.opto;
            
            if isNP && strcmp(se.userData.sessionInfo.seshType, 'bodyside8') 
                factorM = 0.012;  % factorM =0.1 for bodyside 7, this is for VC030206 and VC030107,8
            elseif isNP
                factorM = 0.1;
            else
                factorM = 2 * 10^-6;
            end
            
            % Get left stim onsets and offsets in each trials
            for k = 1 : length(leftStim)
                leftInTrial = leftStim{k};
                timeInTrial = time{k};
                
                leftOnsetInds{k,1} = find(leftInTrial > factorM, 1);
                % the first one that crosses the threshold of left stimulus
                leftOffsetInds{k,1} = find(leftInTrial > factorM, 1, 'last');
                % the last one that crosses the threshold of left stimulus
                
%                 figure(1);clf;
%                 plot(timeInTrial,leftInTrial);

                if isempty(leftOnsetInds{k,1}) == 1
                    leftOnsetTimes{k,1} = NaN;
                    leftOffsetTimes{k,1} = NaN;
                else
                    leftOnsetTimes{k,1} = timeInTrial(leftOnsetInds{k,1});
                    leftOffsetTimes{k,1} = timeInTrial(leftOffsetInds{k,1});
                end
            end 
            
            
            % Get som onsets and offsets in each trials
            for k = 1 : length(rightStim)
                rightInTrial = rightStim{k};
                timeInTrial = time{k};
                rightOnsetInds{k,1} = find(rightInTrial > factorM, 1);
                rightOffsetInds{k,1} = find(rightInTrial > factorM, 1, 'last');

                if isempty(rightOnsetInds{k,1}) == 1
                    rightOnsetTimes{k,1} = NaN;
                    rightOffsetTimes{k,1} = NaN;
                else
                    rightOnsetTimes{k,1} = timeInTrial(rightOnsetInds{k,1});
                    rightOffsetTimes{k,1} = timeInTrial(rightOffsetInds{k,1});
                end
            end  
            
            
            % Get stimulus onset
            stimOnsetTimes = {};
            for k = 1 : length(rightOnsetTimes)
                if isequaln(rightOnsetTimes{k,1},NaN) == 0 && isequaln(leftOnsetTimes{k,1}, NaN) == 1  % isequaln treats NaN values as equal,but isequal doesn't
                    stimOnsetTimes{k, 1} = rightOnsetTimes{k,1};
                elseif isequaln(rightOnsetTimes{k,1}, NaN) == 1 && isequaln(leftOnsetTimes{k,1}, NaN) == 0
                    stimOnsetTimes{k, 1} = leftOnsetTimes{k,1};
                else
                    stimOnsetTimes{k, 1} = NaN;
                end
            end
            stimOnsetTimes = cell2mat(stimOnsetTimes); % AlignTime function only takes a numeric vactor not a cell array 
            
            % Get right lick onsets and offsets in each trials
            for k = 1 : length(rLick)
                rLickInTrial = rLick{k};
                timeInTrial = time{k};
                rLickThresh = find(rLickInTrial > 0.25);   
                if isempty(rLickThresh) == 1
                    rLickOnsetTimes{k,1} = NaN;
                    rLickOffsetTimes{k,1} = NaN;
                else
                    rLdiff = diff(rLickThresh);
                    rLickOnsetInds = [rLickThresh(1); rLickThresh(find(rLdiff > 80)+1)];
                    rLickOffsetInds = [rLickThresh(find(rLdiff > 80)); rLickThresh(end)];
                    rLickOnsetTimes{k,1} = timeInTrial(rLickOnsetInds);                 
                    rLickOffsetTimes{k,1} = timeInTrial(rLickOffsetInds);
                end
            end  
            
            % Get left lick onsets and offsets in each trials
            for k = 1 : length(lLick)
                lLickInTrial = lLick{k};
                timeInTrial = time{k};
                lLickThresh = find(lLickInTrial > 0.25);
                if isempty(lLickThresh) == 1
                    lLickOnsetTimes{k,1} = NaN;
                    lLickOffsetTimes{k,1} = NaN;
                else
                    lLdiff = diff(lLickThresh);
                    lLickOnsetInds = [lLickThresh(1); lLickThresh(find(lLdiff > 80)+1)];
                    lLickOffsetInds = [lLickThresh(find(lLdiff > 80)); lLickThresh(end)];
                    lLickOnsetTimes{k,1} = timeInTrial(lLickOnsetInds);                 
                    lLickOffsetTimes{k,1} = timeInTrial(lLickOffsetInds);
                end 
            end 
            
            % Get first lick 
            % Select trials based on B-control response 
            % 1) Select correct lick ports
            % 2) Do not select licks after response window 
            %    (0 ~ 2 sec from stimulus onsets)
            % If licks are after response window, response will be 0.

            
            % Load B-control repsonse
            lickResponse = se.GetColumn('behavValue', 'response');
            firstLickTimes = {};
            
            for k = 1 : length(lickResponse)
                if lickResponse{k} == 1 && ~isequaln(rLickOnsetTimes{k}(1), NaN)
                    firstLickInd = find(rLickOnsetTimes{k} > stimOnsetTimes(k), 1); 
                    if ~isempty(firstLickInd) 
                        firstLickTimes{k, 1} = rLickOnsetTimes{k}(firstLickInd);
                    else 
                        firstLickTimes{k, 1} = NaN;
                    end
                elseif lickResponse{k} == 2 && ~isequaln(lLickOnsetTimes{k}(1), NaN) 
                    firstLickInd = find(lLickOnsetTimes{k} > stimOnsetTimes(k), 1); 
                    if ~isempty(firstLickInd) 
                        firstLickTimes{k, 1} = lLickOnsetTimes{k}(firstLickInd);
                    else 
                        firstLickTimes{k, 1} = NaN;
                    end
                else 
                    firstLickTimes{k, 1} = NaN;
                end
            end
            
            firstLickTimes = cell2mat(firstLickTimes); % AlignTime function only takes a numeric vactor not a cell array 
            
            
            % Get opto onsets and offsets 
            for k = 1 : length(opto)
                optoInTrial = opto{k};
                timeInTrial = time{k};
                optoOnsetInds{k,1} = find(optoInTrial > 0.02, 1); % it was 0.1 before 8/9/21
                optoOffsetInds{k,1} = find(optoInTrial > 0.02, 1, 'last');
                
                if isempty(optoOnsetInds{k,1}) == 1
                    optoOnsetTimes{k,1} = NaN;
                    optoOffsetTimes{k,1} = NaN;
                else
                    optoOnsetTimes{k,1} = round(timeInTrial(optoOnsetInds{k,1}),2);
                    optoOffsetTimes{k,1} = round(timeInTrial(optoOffsetInds{k,1}),2);
                end
            end 
            
            % Create behavTime table
            varNames = {'rightOnset', 'rightOffset', 'leftOnset', 'leftOffset', 'stimOnset',...
                'rLickOnset', 'rLickOffset', 'lLickOnset', 'lLickOffset', 'firstLick','optoOnset', 'optoOffset'};
            behavTime = table(rightOnsetTimes, rightOffsetTimes, leftOnsetTimes, leftOffsetTimes,stimOnsetTimes,...
                rLickOnsetTimes, rLickOffsetTimes, lLickOnsetTimes, lLickOffsetTimes, firstLickTimes, optoOnsetTimes, optoOffsetTimes,...
                'VariableNames',varNames);

            % Add behavTime to se
            se.SetTable('behavTime', behavTime, 'eventTimes');
        end
        
        function TrialQC(se)

            %Quality control of trials
            
            % Remove trials without stimOnset (NaN) due to pre-stim licking
            % within 0.2s before stimulus onset
            stimOnset = se.GetColumn('behavTime', 'stimOnset');
            NaN = isnan(stimOnset);
            se.RemoveEpochs(NaN);
            
            % Remove the last 20 trials (adjust it if drifting happens)
            trialNum = se.GetColumn('behavValue', 'bct_trialNum');
            se.RemoveEpochs(length(trialNum)-20:length(trialNum));
            
        end 
        
        function se = removeTrials(trialInd,seIn)
            se = seIn.Duplicate();
            trialNums = 1:se.numEpochs;
            removeTrials = ismember(trialNums, trialInd);
            se.RemoveEpochs(trialInd);

        end

         function se = keepTrials(trialInd,seIn)
            se = seIn.Duplicate();
            trialNums = 1:se.numEpochs;
            removeTrials = find(~ismember(trialNums, trialInd));
            se.RemoveEpochs(removeTrials);

        end

        function seIn = getTrials(se, input)
            seIn = se.Duplicate();    
            trialsToKeep = seIn.GetColumn('behavValue', input);
            keepTrials = find(~sum(trialsToKeep, 2));
            seIn.RemoveEpochs(keepTrials);
        end
    end
end



