classdef SE
    methods(Static)
        % Trying to adapt from SL.SE for Bodyside project. 
        function [seArray, filePaths] = LoadSession(varargin)
            % Load session files as MSessionExplorer
            
            % Handle user inputs
            p = inputParser();
            p.addOptional('filePaths', '', @(x) ischar(x) || iscellstr(x) || isempty(x));
            p.addParameter('Enrich', false, @islogical);
            p.addParameter('UserFunc', @(x) x, @(x) isa(x, 'function_handle'));
            p.parse(varargin{:});
            filePaths = p.Results.filePaths;
            isEnrich = p.Results.Enrich;
            userFunc = p.Results.UserFunc;
            
            if isempty(filePaths)
                filePaths = MBrowse.Files();
            else
                filePaths = cellstr(filePaths);
            end
            if isempty(filePaths)
                seArray = [];
                return;
            end
            
            % Preallocation
            seArray(numel(filePaths),1) = MSessionExplorer();
            
            for i = 1 : numel(filePaths)
                [~, fileName, fileExt] = fileparts(filePaths{i});
                disp(['SESSION ' num2str(i) ' - ' fileName]);
                
                if strcmpi(fileExt, '.mat')
                    % MSessionExplorer MAT file
                    load(filePaths{i});
                    
                elseif strcmpi(fileExt, '.txt')
                    % Construct MSessionExplorer object
                    se = MSessionExplorer();
                    
                    % Import SatellitesViewer data
                    bctData.file_path = filePaths{i};
                    bctData.txt = Satellites.ReadTxt(filePaths{i});
                    BS.Preprocess.SessionInfo2SE(bctData, se);
                    BS.Preprocess.Bcontrol2SE(bctData, se);
                end
                
                if isEnrich
                    BS.SE.EnrichAll(se);
                end
                userFunc(se);
                seArray(i) = se;
            end
        end
        
        function xlsTb = AddXlsInfo2SE(seArray, xlsTb)
            % Add metadata found in Excel spreadsheet to userData of SE objects
            
            xlsTb.session_id = cellfun(@(x,y) [x ' ' datestr(y, 'yyyy-mm-dd')], ...
                xlsTb.animal_id, num2cell(xlsTb.date), 'Uni', false);
            
            isRead = [];
            for i = 1 : numel(seArray)
                sId = SL.SE.GetID(seArray(i));
                isHit = strcmp(sId, xlsTb.session_id);
                if ~any(isHit)
                    warning('No entry matches with %s in the spreadsheet.', sId);
                    continue;
                elseif sum(isHit) > 1
                    error('More than one entries match with %s in the spreadsheet.', sId);
                end
                isHit = find(isHit, 1);
                seArray(i).userData.xlsInfo = table2struct(xlsTb(isHit,:));
                isRead(end+1) = isHit;
            end
            xlsTb = xlsTb(isRead,:);
        end
        
        % se utilities
        function [sessionId, animalId] = GetID(varargin)
            % Extract session ID and animal ID, e.g. 'MX210602 2021-06-18', 'MX210602'
            % 
            %   [sessionId, animalId] = SL.SE.GetID(seFileName)
            %   [sessionId, animalId] = SL.SE.GetID(se)
            %   [sessionId, animalId] = SL.SE.GetID(se.userData.sessionInfo)
            %   [sessionId, animalId] = SL.SE.GetID(animalId, sessionDatetime)
            %   [sessionId, animalId] = SL.SE.GetID(animalId, sessionDatetime, subId)
            
            switch numel(varargin)
                case 1
                    var = varargin{1};
                    if isa(var, 'MSessionExplorer')
                        s = var.userData.sessionInfo;
                    elseif isstruct(var)
                        s = var;
                    elseif ischar(var)
                        nameParts = strsplit(var, {' ', '.'});
                        animalId = nameParts{1};
                        sessionId = strjoin(nameParts(1:2), ' ');
                        return
                    else
                        error('The input data type is incorrect');
                    end
                case 2
                    s.animalId = varargin{1};
                    s.sessionDatetime = varargin{2};
                case 3
                    s.animalId = varargin{1};
                    s.sessionDatetime = varargin{2};
                    s.subId = varargin{3};
                otherwise
                    error('Unexpected number of input arguments.');
            end
            
            if ~ischar(s.sessionDatetime)
                s.sessionDatetime = datestr(s.sessionDatetime, 'yyyy-mm-dd');
            end
            if ~isfield(s, 'subId')
                s.subId = '';
            end
            animalId = s.animalId;
            sessionId = [s.animalId ' ' s.sessionDatetime ' ' s.subId];
            sessionId = strtrim(sessionId);
        end
        
        function tb = GetSessionInfoTable(seArray)
            % Summarize key session info in a table
            tb = table();
            for k = numel(seArray) : -1 : 1
                ud = seArray(k).userData;
                tb.animalId{k} = ud.sessionInfo.animalId;
                tb.sessionDatetime(k) = datetime(ud.sessionInfo.sessionDatetime);
                tb.numTrials(k) = seArray(k).numEpochs;
                if isfield(ud, 'spikeInfo')
                    tb.numUnits(k) = numel(ud.spikeInfo.unit_channel_ind);
                else
                    tb.numUnits(k) = NaN;
                end
            end
            tb.sessionDatetime.Format = 'yyyy-MM-dd HH:mm:ss';
        end
        
  
        % Enrich se (i.e. add derived data from existing data)
        function EnrichAll(se)
            warning('off', 'backtrace');
            fprintf('Enrich %s\n\n', SL.SE.GetID(se));
            SL.SE.Corrections(se);
            SL.SE.EnrichBehavTables(se);            
            warning('on', 'backtrace');
        end
        
        function Corrections(se)
            % Correct known errors in data
            
            sessionId = BS.SE.GetID(se);
            [bt, bv] = se.GetTable('behavTime', 'behavValue');
            
            if iscell(bt.opto)
                % MX180202; MX180501 2018-05-01
                warning('%s: some trials contain two opto trigger. Discard the second values (in ITI).', sessionId)
                bt.opto = cellfun(@(x) x(1), bt.opto);
                bv.opto = cellfun(@(x) x(1), bv.opto);
            end
            
            if any(regexp(sessionId, '^MX1802')) && ~all(isnan(bv.opto))
                % All MX1802 sessions
                warning('%s: remove opto trigger data since no opto was actually applied.', sessionId);
                bt.opto(:) = NaN;
                bv.opto(:) = NaN;
            end
            
            if any(~isnan(bt.opto)) && all(isnan(bv.opto))
                % MX1804, MX180803-4. Fixed since 2018/8/8.
                warning('%s: fill missing opto trigger types in value table.', sessionId);
                bv.opto(bt.opto <= bt.cue) = 0;
                bv.opto(bt.opto > bt.cue & bt.opto <= bt.water) = 1;
                bv.opto(bt.opto > bt.water) = 2;
            end
            
            for n = 1 : se.numEpochs
                indRm = bt.posIndex{n} > bt.water(n);
                if any(indRm)
                    % MX180601 since 2018-07-22. MX180803 208-08-17. Fixed since 2018/9/6.
                    warning('%s: remove posIndex events due to user commands after water delivery in epoch %d', ...
                        sessionId, n);
                    bt.posIndex{n}(indRm) = [];
                    bv.posIndex{n}(indRm) = [];
                end
            end
            
            se.SetTable('behavTime', bt);
            se.SetTable('behavValue', bv);
        end
        
        function EnrichStimBehavTables(se)
            % Add data derived from behavTime and behavValue table
            
            sessionId = SL.SE.GetID(se);
            [bt, bv] = se.GetTable('behavTime', 'behavValue');
            
            % Cue offsets
            bt.cueOff = bt.cue + bv.cue/1000;
            
            % water consumption seciton commented because this was made for
            % stim sessions
%             % Water related
%             bt.waterOff = bt.water + bv.water/1000;
%             
%             bt.waterTrig = NaN(size(bt.water));
%             bv.waterDelay = NaN(size(bt.water));
%             bt.endConsump = NaN(size(bt.water));

            % add stim Duration for each trial
            leftStimType = bv.leftStimtype;
            leftStimType = bv.leftStimtype;

            for n = 1 : se.numEpochs
                
                % Cache variables
                tEndDr = bt.posIndex{n}(end);
                tLick = bt.lickOn{n};
                
                % Time of reward triggering lick and delay of water delivery
                idx = find(tLick >= tEndDr + 0.08, 1);
                if ~isempty(idx)
                    bt.waterTrig(n) = tLick(idx);
                    bv.waterDelay(n) =  (bt.water(n) - tLick(idx)) * 1000;
                end
                
                % Last consumatory lick
                idx = find(tLick > bt.waterOff(n) & diff([tLick; Inf]) > 1, 1);
                if ~isempty(idx)
                    bt.endConsump(n) = tLick(idx);
                end
            end
            
            % Create categorical sequence ID
            % MX180804 2018-08-30: last trial has extra posIndex
            seqId = cell(se.numEpochs, 1);
            for n = 1 : se.numEpochs
                if isnan(bv.posIndex{n})
                    % MX180602 2018-07-03: trial 267
                    % MX180701 2018-08-29: trial 159; MX180701 2018-09-10: trial 108
                    % MX181002 2018-09-15: trial 1
                    % MX181101 2019-01-26: trial 252
                    warning('%s: trial %d might be aborted as there is no sequence info.', sessionId, n);
                    seqId{n} = 'none';
                else
                    seqId{n} = arrayfun(@int2str, bv.posIndex{n})';
                end
            end
            bv.seqId = SL.Param.CategorizeSeqId(seqId);
            
            se.SetTable('behavTime', bt);
            se.SetTable('behavValue', bv);
        end
        
  
        function EnrichOpto(se)
            % Add data derived from opto channels
            
            % Add default values
            colNames = {'optoDur1', 'optoDur2', 'optoFreq1', 'optoFreq2', 'optoMod1', 'optoMod2'};
            colDefaults = NaN(se.numEpochs, numel(colNames));
            se.SetColumn('behavValue', colNames, colDefaults);
            
            % Get data
            if ~ismember('adc', se.tableNames)
                return;
            end
            [bv, adc] = se.GetTable('behavValue', 'adc');
            
            % 
            if ismember('opto1', adc.Properties.VariableNames)
                [bv.optoDur1, bv.optoFreq1, bv.optoMod1] = ...
                    cellfun(@(t,s) SL.Opto.AnalyzeWaveform(t,s,SL.Param.vOptoAdcThreshold), ...
                    adc.time, adc.opto1);
                
                bv.optoDur1 = round(bv.optoDur1, 2);
                bv.optoFreq1 = round(bv.optoFreq1);
                bv.optoMod1 = MMath.Bound(bv.optoMod1 / SL.Param.vOptoAdcPerMod / 5, [2.^-(0:5), 0]);
            end
            
            if ismember('opto2', adc.Properties.VariableNames)
                [bv.optoDur2, bv.optoFreq2, bv.optoMod2] = ...
                    cellfun(@(t,s) SL.Opto.AnalyzeWaveform(t,s,SL.Param.vOptoAdcThreshold), ...
                    adc.time, adc.opto2);
                
                bv.optoDur2 = round(bv.optoDur2, 2);
                bv.optoFreq2 = round(bv.optoFreq2);
                bv.optoMod2 = MMath.Bound(bv.optoMod2 / SL.Param.vOptoAdcPerMod / 5, [2.^-(0:5), 0]);
            end
            
            se.SetTable('behavValue', bv);
            
            %{
            figure(123); clf
            ind = 1:5;
            MPlot.PlotTraceLadder(adc.time(ind), adc.opto1(ind), ind, 'Scalar', 1, 'Color', 'r'); hold on
            MPlot.PlotTraceLadder(adc.time(ind), adc.opto2(ind), ind, 'Scalar', 1, 'Color', 'b');
            xlim([0 3])
            %}
        end
        
        function AddSpikeRateTable(se, ops)
            
            % Vectorize spike times
            seSpk = se.Duplicate({'spikeTime'}, false);
            seSpk.SliceSession(0, 'absolute');
            
            % Clean ISI violated spikes
            spk = seSpk.GetTable('spikeTime');
            
            
            % Add time lag
            for i = 1 : width(spk)
                if isa(spk.(i), 'double')
                    spk.(i) = spk.(i) + ops.spkLagInSec(1);
                    continue
                end
                spk.(i){1} = spk.(i){1} + ops.spkLagInSec(1);
            end
            seSpk.SetTable('spikeTime', spk);
            
            % Binning
            tEdges = 0 : ops.spkBinSize : se.userData.spikeInfo.recording_time;
            r = seSpk.ResampleEventTimes('spikeTime', tEdges, 'Normalization', 'countdensity');
            
            % Smoothing
            for i = 2 : width(r)
                r.(i){1} = MNeuro.Filter1(r.(i){1}, 1/ops.spkBinSize, 'gaussian', ops.spkKerSize);
            end
            seSpk.SetTable('spikeRate', r, 'timeSeries', 0);
            seSpk.RemoveTable('spikeTime');
            
            % Reslice
            tRef = se.GetReferenceTime('spikeTime');
            seSpk.SliceSession(tRef, 'absolute');
            r = seSpk.GetTable('spikeRate');
            se.SetTable('spikeRate', r, 'timeSeries', tRef);
        end
        
        function AddZscoreRateTable(se)

            seSpk = se.Duplicate();
            seSpk.SliceSession(0, 'absolute');
            
            % Clean ISI violated spikes
            spikeRates = seSpk.GetTable('spikeRate');


            tRef = se.GetReferenceTime;
            seSpk.SliceSession(0, 'absolute');
            
            
            variableNames = spikeRates.Properties.VariableNames;

            spikeRates = table2cell(spikeRates);
            zRates = spikeRates(2:end);
            totalMean = cellfun(@mean, zRates, 'UniformOutput', false);
            totalSD = cellfun(@std, zRates, 'UniformOutput', false);
            zRates = cellfun(@(x,y,z) (x-y)/z, zRates, totalMean, totalSD, 'UniformOutput', false);
            zRates = [spikeRates(1), zRates];
            zRates = cell2table(zRates, 'VariableNames', variableNames);
            seSpk.SetTable('zRate', zRates, 'timeSeries', 0);
            seSpk.SliceSession(tRef, 'absolute');
            zRates = seSpk.GetTable('zRate');
            
            se.SetTable('zRate', zRates, 'timeSeries', tRef);
            
        end

    
        
        function seTb = SplitConditions(se, ops)
            % Split an SE into a table of SEs by conditions in the behavValue table
            % Trials with NaN condition will be excluded except for opto
            
            % Find groups
            if isempty(ops.conditionVars)
                % Initialize table with a dummy grouping variable
                dummyCond = ones(se.numEpochs, 1);
                T = table(dummyCond);
            else
                % Get and modify variables from behavValue table
                bv = se.GetTable('behavValue');
                bv.opto(isnan(bv.opto)) = -1;
                bv.seqId = SL.Param.CategorizeSeqId(bv.seqId);
                se.SetTable('behavValue', bv);
                T = bv(:,ops.conditionVars);
            end
            [condId, seTb] = findgroups(T);
            
            % Split SE by conditions
            for i = 1 : max(condId)
                % Remove non-member
                seCopy = se.Duplicate();
                seCopy.RemoveEpochs(condId ~= i);
                
                % Add to table
                seTb.animalId{i} = seCopy.userData.sessionInfo.animalId;
                seTb.sessionId{i} = SL.SE.GetID(seCopy);
                seTb.se(i) = seCopy;
                seTb.numTrial(i) = seCopy.numEpochs;
            end
        end
        
        function condTb = CombineConditions(condTb, seTb, varargin)
            % Combine the same conditions across rows of an (usually concatenated) seTb
            
            p = inputParser;
            p.addParameter('UniformOutput', false);
            p.parse(varargin{:});
            isUni = p.Results.UniformOutput;
            
            % Take out condition columns in seTb
            isCond = ismember(seTb.Properties.VariableNames, condTb.Properties.VariableNames);
            seCond = seTb(:,isCond);
            seTb = seTb(:,~isCond);
            
            % Process each row of condTb
            nCond = width(condTb);
            for i = 1 : height(condTb)
                % Find the same condition across sessions
                isCond = true(height(seTb),1);
                for j = 1 : nCond
                    isCond = isCond & ismember(seCond.(j), condTb.(j)(i));
                end
                if ~any(isCond)
                    continue;
                end
                
                % Concatenate data
                for j = 1 : width(seTb)
                    vn = seTb.Properties.VariableNames{j};
                    col = seTb.(vn);
                    if iscell(col)
                        s2 = cellfun(@(x) size(x,2), col);
                        isCatable = numel(unique(s2)) == 1;
                        if ~iscellstr(col) && isCatable
                            condTb.(vn){i} = cat(1, col{isCond});
                            continue
                        end
                    end
                    condTb.(vn){i} = col(isCond);
                end
            end
            
            % Remove empty conditions
            condTb(cellfun(@isempty, condTb.(nCond+1)), :) = [];
            
            % Denest
            if ~isUni
                return;
            end
            for j = nCond+1 : width(condTb)
                try
                    condTb.(j) = cat(1, condTb.(j){:});
                catch
                    warning('Column %s cannot be denested', condTb.Properties.VariableNames{j});
                end
            end
        end
        
        function seTb = SetStimRespArrays(seTb, ops)
            % Set stim and resp matrices for each se in seTb
            for k = 1 : height(seTb)
                se = seTb.se(k);
                [stim, t] = SL.SE.GetStimArray(se, ops);
                resp = SL.SE.GetRespArray(se, ops);
                seTb.time{k} = t;
                seTb.stim{k} = stim;
                seTb.resp{k} = resp;
            end
        end
        
      
        
        function [resp, t] = GetRespArray(se, ops)
            % Resample spike rates to form a time-by-unit-by-trial matrix
            
            % Parameters
            tEdges = ops.rsWin(1) : ops.rsBinSize : ops.rsWin(2);
            rsArgs = {'Method', 'nearest', 'Extrap', 'nearest'};
            
            % Resample spikeRate data
            respTb = se.ResampleTimeSeries('spikeRate', tEdges, rsArgs{:});
            
            % Convert table to matrix
            resp = cell(1, width(respTb));
            for i = 1 : width(respTb)
                resp{i} = double(cat(3, respTb.(i){:})); % cat trials along 3rd dim
            end
            t = resp{1};
            resp = cat(2, resp{2:end}); % cat units along 2nd dim
            
            % Averaging and combining dimensions
            if ops.dimAverage
                t = mean(t, ops.dimAverage);
                resp = mean(resp, ops.dimAverage, 'omitnan');
                t = MMath.SqueezeDims(t, ops.dimAverage);
                resp = MMath.SqueezeDims(resp, ops.dimAverage);
            end
            if ops.dimCombine
                t = MMath.CombineDims(t, ops.dimCombine);
                resp = MMath.CombineDims(resp, ops.dimCombine);
            end
        end
        
        function seTb = SetMeanArrays(seTb, var4mean)
            % Average stim, resp and projection matrices across trials
            % The size of a mean matrix is time-by-var-by-5(mean,sd,ciLow,ciHigh,rNaN)
            % where rNaN indicates the fraction of missing observation
            if nargin < 2
                var4mean = {'time', 'stim', 'resp', 'reg', 'pca'};
            end
            tbVars = seTb.Properties.VariableNames;
            for i = 1 : height(seTb)
                N = sum(seTb.numMatched{i});
                for j = 1 : numel(var4mean)
                    vn = var4mean{j};
                    if ~ismember(vn, tbVars) || ~isnumeric(seTb.(vn){i})
                        continue;
                    end
                    seTb.(vn){i} = compute(seTb.(vn){i}, N);
                end
                seTb.time{i} = seTb.time{i}(:,1,1);
            end
            function M = compute(X, nTrial)
                nTime = size(X,1) / nTrial;
                nVar = size(X,2);
                X = reshape(X, [nTime nTrial nVar]);
                X = permute(X, [1 3 2]);
                [m, sd, ~, ci] = MMath.MeanStats(X, 3, 'IsOutlierArgs', {'median'}, ...
                    'NBoot', 2000, 'Alpha', 0.01, 'Options', statset('UseParallel', true));
                rNaN = mean(isnan(X), 3);
                M = cat(3, m, sd, ci, rNaN);
            end
        end
        
        function seArray = PartitionTrials(se, k)
            % Randomly split trials into partitions
            %   k is the number of fold as in KFold crossvalidation
            %   se can be an array and the partition populates the second dimension
            
            if numel(se) == 1
                % Partition
                c = cvpartition(se.numEpochs, 'Kfold', k);
                for i = k : -1 : 1
                    seArray(i) = se.Duplicate();
                    seArray(i).RemoveEpochs(~c.test(i));
                end
            else
                % Recursively process each se
                for i = numel(se) : -1 : 1
                    seArray(i,:) = SL.SE.PartitionTrials(se(i), k);
                end
            end
        end
    end
end

