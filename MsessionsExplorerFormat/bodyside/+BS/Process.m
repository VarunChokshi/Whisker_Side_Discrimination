classdef Process
    
    methods(Static)
        function summary_firstHit = GetFirstHitInfo(se)
            % Input         
            %           MSessionExplorer
            % Output
            %           Get the trial number of first hit trial in each block after block switch 
            %           Determine if mice sucessfully switch (first hit) before the transition cue 

            isTblock = ismember(se.GetColumn('behavValue', 'blockType'), 'Whisker');
            isVblock = ismember(se.GetColumn('behavValue', 'blockType'), 'Visual');
            istHit = se.GetColumn('behavValue', 'TTT'); 
            isvHit = se.GetColumn('behavValue', 'VVV'); 
            isChange = ismember(se.GetColumn('behavValue', 'blockType'), 'Change') ;
            isTblock = double(isTblock);
            isVblock = double(isVblock);

            % Assign block type to the cahnge trials  
            for t = 2: length(isTblock)
                if isChange(t) == 1 && isTblock(t-1) ==1
                    isTblock(t) = 1;
                elseif isChange(t) == 1 && isVblock(t-1) ==1
                    isVblock(t) = 1;
                end 
            end
            % Find first and last trial of blocks
            [tBlock_start_trial,~] = find(diff([0;isTblock])== 1); 
            [vBlock_start_trial,~] = find(diff([0;isVblock])== 1);
            if isTblock(end) == 1
                [tBlock_end_trial,~] = find(diff([isTblock;0])== -1); 
                [vBlock_end_trial,~] = find(diff([isVblock])== -1);
            else
                [tBlock_end_trial,~] = find(diff([isTblock])== -1); 
                [vBlock_end_trial,~] = find(diff([isVblock;0])== -1);
            end

            trialNum = cell2mat(se.GetColumn('behavValue', 'bct_trialNum')); % trial number from bcontrol data
            for tbn = 1:length(tBlock_start_trial)
                if tBlock_start_trial(tbn) > 1 % remove the first block
                    if ~isempty(find(istHit(tBlock_start_trial(tbn):tBlock_end_trial(tbn)),1)) % Mice switched before the end of the block
                        first_tHit_idx = tBlock_start_trial(tbn) + find(istHit(tBlock_start_trial(tbn):tBlock_end_trial(tbn)),1) -1; % first TTT
                        trialNum_first_tHit(tbn) = {trialNum(first_tHit_idx) - trialNum(tBlock_start_trial(tbn)) + 1}; % trial number after block switch 
                        change_idx = tBlock_start_trial(tbn) + find(isChange(tBlock_start_trial(tbn):tBlock_end_trial(tbn)),1) -1; % transition cue           
                        if ~isempty(change_idx)
                            is_tHit_before_cue(tbn) = {first_tHit_idx < change_idx};
                        else
                            is_tHit_before_cue(tbn) = {NaN};
                        end
                    else % Mice didn't switch before the end of the block
                        trialNum_first_tHit(tbn) = {NaN};
                        is_tHit_before_cue(tbn) = {NaN};
                    end
                else
                    trialNum_first_tHit(tbn) = {NaN};
                    is_tHit_before_cue(tbn) = {NaN};
                end
            end
            for vbn = 1:length(vBlock_start_trial)
                if vBlock_start_trial(vbn) > 1 % remove the first block
                    if ~isempty(find(isvHit(vBlock_start_trial(vbn):vBlock_end_trial(vbn)),1)) % Mice switched before the end of the block
                        first_vHit_idx = vBlock_start_trial(vbn) + find(isvHit(vBlock_start_trial(vbn):vBlock_end_trial(vbn)),1) -1; % first VVV
                        trialNum_first_vHit(vbn) = {trialNum(first_vHit_idx) - trialNum(vBlock_start_trial(vbn)) + 1}; % trial number after block switch 
                        change_idx = vBlock_start_trial(vbn) + find(isChange(vBlock_start_trial(vbn):vBlock_end_trial(vbn)),1) -1; % transition cue           
                        if ~isempty(change_idx) % transition cue
                            is_vHit_before_cue(vbn) = {first_vHit_idx < change_idx}; % the first hit is before the transtion cue
                        else % no transition cue
                            is_vHit_before_cue(vbn) = {NaN};
                        end
                    else % Mice didn't switch before the end of the block
                        trialNum_first_vHit(vbn) = {NaN};
                        is_vHit_before_cue(vbn) = {NaN};
                    end
                else
                    trialNum_first_vHit(vbn) = {NaN};
                    is_vHit_before_cue(vbn) = {NaN};
                end
            end

            summary_firstHit.trialNum_tHit = trialNum_first_tHit;
            summary_firstHit.beforeCue_tHit = is_tHit_before_cue;
            summary_firstHit.trialNum_vHit = trialNum_first_vHit;
            summary_firstHit.beforeCue_vHit = is_vHit_before_cue;
        end
        
        
        function [isGoodPerf, behavPerformance] = GetBehavPerf(se)
            % Threshold for performance
            hitThreshold = 0.35;
            blockThreshold = 0.55;
            overallThreshold = 0.60;

            % Load trial type index
            trialTypes = {'TTT', 'TTV', 'TTN', 'TVT', 'TVV', 'TVN',...
                  'VTT', 'VTV', 'VTN', 'VVT', 'VVV', 'VVN'};
            ttInd = se.GetColumn('behavValue', trialTypes);

            ttInd_sum = sum(ttInd);
            tBlock_total = sum(ttInd_sum(1:6),2);
            vBlock_total = sum(ttInd_sum(7:end),2);

            tBlock_Hit = ttInd_sum(1)/tBlock_total;
            tBlock_CR = ttInd_sum(6)/tBlock_total;
            tBlock_Miss = ttInd_sum(3)/tBlock_total;
            tBlock_FA = (ttInd_sum(2)+ttInd_sum(4)+ttInd_sum(5))/tBlock_total;
            tHitRate =  ttInd_sum(1)/sum(ttInd_sum(1:3));
            tBlock_perf = (ttInd_sum(1)+ttInd_sum(6))/tBlock_total;
            
            vBlock_Hit = ttInd_sum(11)/vBlock_total;
            vBlock_CR = ttInd_sum(9)/vBlock_total;
            vBlock_Miss = ttInd_sum(12)/vBlock_total;
            vBlock_FA = (ttInd_sum(7)+ttInd_sum(8)+ttInd_sum(10))/vBlock_total;
            vHitRate =  ttInd_sum(11)/sum(ttInd_sum(10:12));
            vBlock_perf = (ttInd_sum(11)+ttInd_sum(9))/vBlock_total;
            
            overall_perf = (ttInd_sum(1)+ ttInd_sum(6)+ ttInd_sum(11)+ ttInd_sum(9))/(tBlock_total+vBlock_total);
            
            tBlock_TVT = ttInd_sum(4)/tBlock_total; % compulsive licking
            tBlock_TVV = ttInd_sum(5)/tBlock_total; % rule error
            tBlock_TTV = ttInd_sum(2)/tBlock_total;
 
            vBlock_VTV = ttInd_sum(8)/vBlock_total; % compulsive licking
            vBlock_VTT = ttInd_sum(7)/vBlock_total; % rule error
            vBlock_VVT = ttInd_sum(10)/vBlock_total; 

            behavPerformance = {tBlock_Hit tBlock_CR tBlock_Miss tBlock_FA ...
                vBlock_Hit vBlock_CR vBlock_Miss vBlock_FA ...
                tBlock_TVT tBlock_TVV tBlock_TTV vBlock_VTV vBlock_VTT vBlock_VVT...
                tHitRate, vHitRate, tBlock_perf, vBlock_perf, overall_perf};
            
            % Convert to a table
            VarNames = {'tBlock_Hit', 'tBlock_CR', 'tBlock_Miss', 'tBlock_FA',...
                         'vBlock_Hit', 'vBlock_CR', 'vBlock_Miss', 'vBlock_FA',...
                         'tBlock_TVT', 'tBlock_TVV', 'tBlock_TTV', 'vBlock_VTV', 'vBlock_VTT', 'vBlock_VVT'...
                         'tHitRate', 'vHitRate', 'tBlock_perf', 'vBlock_perf', 'overall_perf'};
            behavPerformance = cell2table(behavPerformance,'VariableNames', VarNames);
            
            % Performance control
            isPassed(1) = tHitRate >= hitThreshold;
            isPassed(2) = vHitRate >= hitThreshold;
            isPassed(3) = tBlock_perf >= blockThreshold;
            isPassed(4) = vBlock_perf >= blockThreshold;
            isPassed(5) = overall_perf >= overallThreshold;
            
            isGoodPerf = sum(isPassed) == length(isPassed);
        end
        
        function [isEarlyTrans, isLateTrans, isNotTrans, isBeforeCue, isAfterCue] = GetTransitionInfo(se)
            % Load trial type index
            trialTypes = {'TTT', 'TTV', 'TTN', 'TVT', 'TVV', 'TVN',...
                  'VTT', 'VTV', 'VTN', 'VVT', 'VVV', 'VVN'};
            ttInd = se.GetColumn('behavValue', trialTypes);
            isChange = ismember(se.GetColumn('behavValue', 'blockType'), 'Change') ;
            isTblock = sum(ttInd(:,1:6),2);
            isVblock = sum(ttInd(:,7:12),2);

            % Assign block type to the cahnge trials  
            for t = 2: length(isTblock)
                if isChange(t) == 1 && isTblock(t-1) ==1
                    isTblock(t) = 1;
                elseif isChange(t) == 1 && isVblock(t-1) ==1
                    isVblock(t) = 1;
                end 
            end
            % Find first and last trial of blocks
            [tBlock_start_trial,~] = find(diff([0;isTblock])== 1); 
            [vBlock_start_trial,~] = find(diff([0;isVblock])== 1);
            if isTblock(end) == 1
                [tBlock_end_trial,~] = find(diff([isTblock;0])== -1); 
                [vBlock_end_trial,~] = find(diff([isVblock])== -1);
            else
                [tBlock_end_trial,~] = find(diff([isTblock])== -1); 
                [vBlock_end_trial,~] = find(diff([isVblock;0])== -1);
            end
            
            % Create index for early transition, late transition, not transition (all after the first hit for that session)
            % by getting the first FA(rule error) trial and the first hit trial for each block
            % Create index for transition cue
            isEarlyTrans = repmat(0,length(isTblock),1);
            isLateTrans = repmat(0,length(isTblock),1);
            isNotTrans = repmat(0,length(isTblock),1);
            isBeforeCue = repmat(0,length(isTblock),1);
            isAfterCue = repmat(0,length(isTblock),1);
            
            for tbn = 1:length(tBlock_start_trial)
                first_TTT = find(ttInd(tBlock_start_trial(tbn):tBlock_end_trial(tbn),1),1)+tBlock_start_trial(tbn)-1;
                first_TVV = find(ttInd(tBlock_start_trial(tbn):tBlock_end_trial(tbn),5),1)+tBlock_start_trial(tbn)-1;
                % not transitions
                if ~isempty(first_TTT)
                    isNotTrans(first_TTT:tBlock_end_trial(tbn)) = 1;
                end
                % transitions (early vs. late)
                if tBlock_start_trial(tbn) > 1 % first block
                    if ~isempty(first_TTT) && ~isempty(first_TVV)
                        if first_TVV<first_TTT % rule FA before Hit
                            isEarlyTrans(tBlock_start_trial(tbn):first_TVV) = 1; % The first TVV is included. 
                            isLateTrans(first_TVV+1:first_TTT-1) = 1; % The first TVV and the first TTT are not included.
                        else % rule FA after Hit
                            isEarlyTrans(tBlock_start_trial(tbn):first_TTT) = 1; 
                        end  
%                     elseif ~isempty(first_TTT) && isempty(first_TVV) 
%                         isEarlyTrans(tBlock_start_trial(tbn):first_TTT) = 1; 
%                     elseif isempty(first_TTT) && ~isempty(first_TVV) 
%                         isEarlyTrans(tBlock_start_trial(tbn):first_TVV) = 1;
%                         isLateTrans(first_TVV+1:tBlock_end_trial(tbn)) = 1; 
%                     else
%                         isEarlyTrans(tBlock_start_trial(tbn):tBlock_end_trial(tbn)) = 1;
                    end    
                end
                % transition cue
                cue = find(isChange(tBlock_start_trial(tbn):tBlock_end_trial(tbn)),1)+tBlock_start_trial(tbn)-1; % transition cue
                if ~isempty(cue)
                    isBeforeCue(tBlock_start_trial(tbn):cue-1) = 1; 
                    isAfterCue(cue+1:tBlock_end_trial(tbn)) = 1;
                end
            end
            
            for vbn = 1:length(vBlock_start_trial)
                first_VVV = find(ttInd(vBlock_start_trial(vbn):vBlock_end_trial(vbn),11),1)+vBlock_start_trial(vbn)-1;
                first_VTT = find(ttInd(vBlock_start_trial(vbn):vBlock_end_trial(vbn),7),1)+vBlock_start_trial(vbn)-1;
                % not transitions
                if ~isempty(first_VVV)
                    isNotTrans(first_VVV:vBlock_end_trial(vbn)) = 1;
                end
                % transitions (early vs. late)
                if vBlock_start_trial(vbn) > 1 % first block
                    if ~isempty(first_VVV) && ~isempty(first_VTT)
                        if first_VTT<first_VVV % rule FA before Hit
                            isEarlyTrans(vBlock_start_trial(vbn):first_VTT) = 1; % The first VTT is included. 
                            isLateTrans(first_VTT+1:first_VVV-1) = 1; % The first VTT and the first VVV are not included.
                        else % rule FA after Hit
                            isEarlyTrans(vBlock_start_trial(vbn):first_VVV) = 1; 
                        end  
%                     elseif ~isempty(first_VVV) && isempty(first_VTT) 
%                         isEarlyTrans(vBlock_start_trial(vbn):first_VVV) = 1; 
%                     elseif isempty(first_VVV) && ~isempty(first_VTT) 
%                         isEarlyTrans(vBlock_start_trial(vbn):first_VTT) = 1;
%                         isLateTrans(first_VTT+1:vBlock_end_trial(vbn)) = 1; 
%                     else
%                         isEarlyTrans(vBlock_start_trial(vbn):vBlock_end_trial(vbn)) = 1;
                    end    
                end
                % transition cue
                cue = find(isChange(vBlock_start_trial(vbn):vBlock_end_trial(vbn)),1)+vBlock_start_trial(vbn)-1; % transition cue
                if ~isempty(cue)
                    isBeforeCue(vBlock_start_trial(vbn):cue-1) = 1; 
                    isAfterCue(cue+1:vBlock_end_trial(vbn)) = 1;
                end
            end      
        end
    end
end
