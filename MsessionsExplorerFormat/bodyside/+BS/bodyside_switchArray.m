%% YT 03/19
    % Simplified versions of  EFcross3_switchArray.m

classdef bodyside_switchArray < handle
    
    properties
        mouseName = '';
        sessionDate = '';
        trialNums        
        trialType
        trialResponse
        leftStimType
        rightStimType
        blockType
        allData
        sessName
        stimType
        stimAmps
    end
    
    methods (Access = public)
        function obj = bodyside_switchArray(x, sesDate)
            %
            % function obj = EFcross3Array(x, session_name)
            %
            % Input argument 'x' is either Solo file name string or
            % a structure from loaded Solo file.

            if nargin == 0
                return
            end
            
            if ischar(x)
                x = load(x);
            end
            
            obj.mouseName = x.saved.SavingSection_MouseName;
            obj.sessionDate = sesDate;
            obj.trialNums = x.saved_history.AnalysisSection_NumTrials; %done trials not started trials
            
%             blockType = x.saved.TrialTypeSection_previous_block_types; % started trials
%             blockType = transpose(blockType);
%             blockType(end, :) = []; % changed to done trials: remove the unfinished last trial
%             obj.blockType = blockType; 
            
            trialType = x.saved.TrialTypeSection_previous_trial_types; % started trials
            trialType = transpose(trialType); 
            trialType(end,:) = []; % changed to done trials: remove the unfinished last trial
            obj.trialType = trialType;
            
            %find response history variables
            behavFieldNames = fieldnames(x.saved);

            
            querystr = '\w*(_response_history)';
            isHit = cellfun(@(x) regexpi(x, querystr), behavFieldNames,...
                'UniformOutput', false);            
            ind = find(cell2mat(cellfun(@(x) ~isempty(x), isHit, 'UniformOutput', false)));
            responsehistory = behavFieldNames{ind};
            splitResponse = strsplit(responsehistory, '_');
            obj.sessName = splitResponse{1}(1:end-3);
            obj.allData = x.saved;
            obj.trialResponse = x.saved.(responsehistory); % done trials 
            
             if strcmp(splitResponse{1}, 'bodyside8obj')
                 obj.leftStimType = cellfun(@(x,y) [x y], x.saved.TrialTypeSection_finalStimTypes(1:end-1)', x.saved_history.TrialTypeSection_StimAmp, ...
                     'UniformOutput', false);
                 obj.rightStimType = cellfun(@(x,y) [x y], x.saved.TrialTypeSection_finalStimTypes(1:end-1)', x.saved_history.TrialTypeSection_StimAmp, ...
                     'UniformOutput', false);            
                 
             else
                 try
                   obj.leftStimType = x.saved_history.TrialTypeSection_LeftStimType;
                catch
                    
                    for trialNums = 1:height(x.saved_history.TrialTypeSection_RightStimAmp)
                        obj.leftStimType{trialNums} = [x.saved_history.TrialTypeSection_LeftStimAmp{trialNums} x.saved_history.TrialTypeSection_LeftStimFreq{trialNums} ...
                            x.saved_history.TrialTypeSection_LeftStimDur{trialNums}];
                    end
                end
    
                try
                    obj.rightStimType = x.saved_history.TrialTypeSection_RightStimType; % done trials
                catch
                    
                    for trialNums = 1:height(x.saved_history.TrialTypeSection_RightStimAmp)
                        obj.rightStimType{trialNums} = [x.saved_history.TrialTypeSection_RightStimAmp{trialNums} x.saved_history.TrialTypeSection_RightStimFreq{trialNums} ...
                            x.saved_history.TrialTypeSection_RightStimDur{trialNums}];
                    end
                    
                end
             end
               
            %n_trials = length(x.saved_history.ScoringSection_LastTrialEvents);  
        end
    end
end

        