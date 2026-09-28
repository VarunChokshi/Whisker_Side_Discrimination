function PlotSession(sePaths, saveFig)

    for sess = 1:numel(sePaths)
        load(sePaths{sess});
        sePathSplit = strsplit(sePaths{sess}, {'\', ' '}); 
        
        if ~exist('saveFig', 'dir')
            mkdir(saveFig);
        end
        behav = se.GetTable('behavValue');
        stimTypes = {'Right', 'Left'};   
        trialTypes = behav.trialType;    
        stimSplit = cellfun(@(x) strsplit(x, '_'), trialTypes, 'UniformOutput', false);
        response = behav.response;
        rightTrials = cellfun(@(x) any(ismember(x,'Right')), stimSplit, 'UniformOutput',false);
        leftTrials = cellfun(@(x) any(ismember(x,'Left')), stimSplit, 'UniformOutput',false);
        leftTrialNums = find(cell2mat(leftTrials));
    
        rightTrialNums = find(cell2mat(rightTrials));
    
        leftResponse = response(cell2mat(leftTrials));
    
        rightResponse = response(cell2mat(rightTrials));
    
        for i = 1: height(rightResponse)
            if rightResponse{i} == 1
                rightColor{i} ='g';
            elseif rightResponse{i} == 2
                rightColor{i} = 'r';
            else 
                rightColor{i} = 'k';
            end
        end
    
        for i = 1: height(leftResponse)
            if leftResponse{i} == 1
                leftColor{i} ='r';
            elseif leftResponse{i} == 2
                leftColor{i} = 'g';
            else 
                leftColor{i} = 'k';
            end
        end
        
        if height(leftResponse) + height(rightResponse) ~= height(response);
            disp('NOTE: left + right is not = total trials');
        end
        columns = behav.Properties.VariableNames;
        
        % red-incorrect green-correct black-miss
        g = figure(sess);clf;
        hold on;
        leftY = ones(1,height(leftTrialNums))*0.1;
        for kk =1:height(leftTrialNums)
            plot(leftTrialNums(kk), leftY(kk), '.', 'color',leftColor{kk});
        end
        rightY = ones(1,height(rightTrialNums))*0.2;
        for kk =1:height(rightTrialNums)
            plot(rightTrialNums(kk), rightY(kk), '.', 'color',rightColor{kk});
        end
        ylim([0,0.3])
        yticks([0.1,0.2])
        yticklabels({'Left', 'Right'})
        sgtitle([sePathSplit{5} ' ' sePathSplit{6}]);
        hold off
        saveas(g,[saveFig '\' sePathSplit{5} ' ' sePathSplit{6} ' sessFig.png']);
    
    end
end

