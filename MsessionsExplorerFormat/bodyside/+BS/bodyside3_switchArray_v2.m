%% YT 03/19
    % Simplified versions of  EFcross3_switchArray.m

classdef bodyside3_switchArray_v2 < handle
    
    properties
        mouseName = '';
        sessionDate = '';
        trialNums        
        trialType
        trialResponse
        leftStimType
        rightStimType
        blockType
 
    end
    
    methods (Access = public)
        function obj = EFcross3_switchArray_v2(x, sesDate)
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
            
            blockType = x.saved.TrialTypeSection_previous_block_types; % started trials
            blockType = transpose(blockType);
            blockType(end, :) = []; % changed to done trials: remove the unfinished last trial
            obj.blockType = blockType; 
            
            trialType = x.saved.TrialTypeSection_previous_trial_types; % started trials
            trialType = transpose(trialType); 
            trialType(end,:) = []; % changed to done trials: remove the unfinished last trial
            obj.trialType = trialType;
            
            %find response history variables
            behavFieldNames = fieldnames(x.saved);
            querystr = '\w*(_response_history)';
            isHit = cellfun(@(x) regexpi(x, querystr), behavFieldNames,...
                'UniformOutput', false);
            ind = find(~isnan(cell2num(isHit)));
            responsehistory = behavFieldNames{ind};
           
            obj.trialResponse = x.saved.(responsehistory); % done trials
            obj.leftStimType = x.saved_history.TrialTypeSection_LeftStimType; % done trials
            obj.rightStimType = x.saved_history.TrialTypeSection_RightStimType; % done trials
            
            %n_trials = length(x.saved_history.ScoringSection_LastTrialEvents);  
        end
    end
end

        