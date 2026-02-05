%% compare to no manipulation
% Multilevel_bootstrap
% resample mice with replacement
% resample session with replacement
% resample trials with replacement 
% 
clear all
close all
trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
trials{2} = {'Stim_Som_Left', 'Stim_Som_Left_Opto', 'Stim_Som_Right', 'Stim_Som_Right_Opto'}; 
inhSitesAll = {'Left S1', 'Right S1','NA'};
[readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\SEs', 'Select source SEs');
clearvars -except readPaths seDir seNames animalID trials inhSitesAll;
readPathParts = cellfun(@(x) strsplit(x, '\'), readPaths, 'UniformOutput', false);
animal = cellfun(@(x) strsplit(x{end}, ' '), readPathParts, 'UniformOutput', false);
AnimalIDs = cellfun(@(x) x{1}, animal, 'UniformOutput', false);
animalID = unique(AnimalIDs);
% get all the trialNums for each trialType for each session and mouse

pathParts = strsplit(seDir, '\');
figureFolder = fullfile(pathParts{1:end-2}, 'Figures');


savePath=(fullfile(figureFolder,'Inhibition'));
if ~exist(savePath, 'dir')
    mkdir(savePath);
end

photoInhAll = table();

for animalNum =1:size(animalID,1)
     ani = animalID{animalNum}; 
     
    sessNum =[1,1,1];
    for i = find(ismember(AnimalIDs, ani))'        
        load(readPaths{i});
        behavData = se.GetTable('behavValue');

        trialMap = se.userData.sessionInfo.trialMap;
        if ~isempty(trialMap{1})
            trialSplit = strsplit(trialMap{1},':');
            if any(strcmpi(trialSplit{2}, 'end'''))
                trialInd = [str2double(trialSplit{1}) : se.numEpochs];
            else
                trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}(1:end-1))];
            end
            se = BS.Preprocess.keepTrials(trialInd,se);
        
            
        end
        
        behavData = se.GetTable('behavValue');
        
        
        %Remove aborted trials due to pre stim no licktime licks
        responses = behavData.response;
        abortTrials = find(cell2mat(responses) == 3); 
        behavData(abortTrials,:) = [];
        
        % separate missed trials vs all trials
        responses = behavData.result;
        missTrials = isnan(responses);
        missData = behavData(missTrials,:);
        behavData(missTrials, :) =[];
        
        % Find inhibition sites
        inhSite = find(ismember(inhSitesAll, behavData.inhSite{1}));

        
        
        trialTypes = unique(behavData.trialType);
        
        if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
            trialTypes = trials{2};
        else
            trialTypes = trials{1};
        end


        for trialType = 1:numel(trialTypes)
            trialTypeInd = strcmp(trialTypes{trialType}, behavData.trialType);
            fracResult{animalNum, inhSite}{sessNum(inhSite)}(trialType) = mean(behavData.result(trialTypeInd));
            
            missFrac{animalNum,inhSite}{sessNum(inhSite)}(trialType) = numel(find(strcmp(trialTypes{trialType}, missData.trialType)))/...
                (height(missData.trialType) + height(behavData.trialType));
            allTrialTypes{animalNum, inhSite}{sessNum(inhSite)} = trialTypes;
        end 
        
              
             
        photoInhAll= [photoInhAll; behavData];

        sessNum(inhSite) = sessNum(inhSite)+1;
        
       
    end
end


inhSites = unique(photoInhAll.inhSite); 

Genotypes = unique(photoInhAll.Genotype); 

trialTypes= unique(photoInhAll.trialType); % left, left_opto, right, right_opto


Inhibitions = unique(photoInhAll.isInhibition);
        
if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
    trialTypes = trials{2};
else
    trialTypes = trials{1};
end 

trialSeq1 = [1,2,3,4];
trialSeq2 = [3,4,1,2];


nboot = 10000; % number for bootstrapping
fracCorrect = cell(length(Genotypes),length(inhSites), nboot);
delta_mouse = cell(length(Genotypes),length(inhSites), nboot);
delta_session =cell(length(Genotypes),length(inhSites), nboot);
delta_prob = cell(nboot);
tic

for g = 1:length(Genotypes)
    
    Genotype = Genotypes{g};
    for e = 1:length(Inhibitions) 
        
        manipulation = Inhibitions(e);
        
        u = photoInhAll((photoInhAll.isInhibition == manipulation)& strcmp(photoInhAll.Genotype, Genotype), :);
        
        mouseNames = unique(u.mouseName);
        if isempty(mouseNames)
            continue;
        end
        rng(7);
%             rng(test(t)); % control random number generation
       parfor n = 1:nboot
           
            resampled_mice = randsample(mouseNames, length(mouseNames), true); 
            for mouse = 1:length(resampled_mice) 
                
                m = u(strcmp(u.mouseName, resampled_mice{mouse}), :);
                
                dateData = cellfun(@(x) datestr(x, 'yyyymmdd'), m.sessDate, 'UniformOutput',false);
                sessions = unique(dateData);
                m.sessDate = dateData;
                % resample session
                
                for session = 1:height(sessions)
                    
                    v = m(strcmp(sessions(randi(height(sessions)),:), m.sessDate), :);  
    
                    inhSite = unique(v.inhSite);
    
                    % Trials with stimuli
                    if (any(ismember(inhSite{:}, 'L')) && manipulation ==1) | (any(ismember(inhSite{:}, 'R')) && manipulation ==0)
                        trialSeq = trialSeq2;
                        
                    else
                        trialSeq = trialSeq1;
                    end

                   for trialType=1:numel(trialTypes)
                       
                        trialInds = find(strcmp(trialTypes{trialSeq(trialType)}, v.trialType));
                        if (any(ismember(inhSite{:}, 'L')) && manipulation ==1) | (any(ismember(inhSite{:}, 'R')) && manipulation ==0)
                            disp(resampled_mice{mouse})
                            disp(sessions{randi(height(sessions)),:})
                            disp(inhSite{:})
                            disp(trialType)
                            disp(trialTypes{trialSeq(trialType)})
                            
                        end
                        
                        % resample trials
                        
                        resampled_trialInds = randsample(trialInds, length(trialInds), true); 
                        fracCorrect{g,e,n}{mouse}{session}(trialType) = mean(v.result(resampled_trialInds)); % lick probability of each trial type                  
                        
                    end
    
                    delta_session{g,e,n}{mouse}(session,1:2) = [fracCorrect{g,e,n}{mouse}{session}(2)- fracCorrect{g,e,n}{mouse}{session}(1),...
                        fracCorrect{g,e,n}{mouse}{session}(4)-fracCorrect{g,e,n}{mouse}{session}(3)]; % leftOpto-left, RightOpto-Right
                   
                   
%                     clear fracCorrect v trialInds
                end
                
                delta_mouse{g,e,n}(mouse,1:2) = mean(delta_session{g,e,n}{mouse},1); % average across sessions
%                 clear delta_session
            end
            delta_prob{n}(1:2) = mean(delta_mouse{g,e,n},1); % average across mice
%             clear delta_mouse
        end
        
        photoInh_bootstrapped{(g-1)*length(Inhibitions)+e,1} = Genotype;
        photoInh_bootstrapped{(g-1)*length(Inhibitions)+e,2} = manipulation;
        photoInh_bootstrapped{(g-1)*length(Inhibitions)+e,3} = cell2mat(delta_prob);
%         clear delta_prob
    end
end
toc



 % plot correct fraction
KOIDs = {'VC030204'};
WTIDs = {'VC030105','VC030107'};
alpha = 0.05;
clearvars meanStats SEM ts ciStats
for rows = 1:height(photoInh_bootstrapped)
    meanStats{rows} = mean(photoInh_bootstrapped{rows,3},1);
    SEM(1:2) = std(photoInh_bootstrapped{rows,3},0,1)/sqrt(height(photoInh_bootstrapped{rows,3})); 
    ts = tinv([alpha/2 1-alpha/2], height(photoInh_bootstrapped{rows,3})-1);
    ciStats{rows}{1} = meanStats{rows}(1) + ts*SEM(1);
    ciStats{rows}{2} = meanStats{rows}(2) + ts*SEM(2);
end
photoInh_bootstrapped(:,4) = meanStats';
photoInh_bootstrapped(:,5) = ciStats';
photoInhBootstrapped = table();
vars = {'Genotype', 'IsInhibition', 'FracCorrect', 'Mean', 'CI'};
photoInhBootstrapped = cell2table(photoInh_bootstrapped,'VariableNames', vars);


    
colors_tt = {[0.5 0.5 0.5] [1 0 1]; [0 1 1] [0.5 0.5 0.5]}; 
close all;
g2 = figure(100);clf
for g=1:numel(Genotypes)
    subplot(1,2,numel(Genotypes)-g+1)
    hold on
    for e =0:numel(Inhibitions)-1
        delta_bootstrapped_g = photoInh_bootstrapped{2*g-1+e:2*g,3};
        sorted_delta = sort(delta_bootstrapped_g,1);   
        y1 = mean(sorted_delta,1); 
        y2 = sorted_delta(nboot*0.025,1:2); 
        y3 = sorted_delta(nboot*0.975,1:2); 
        x = [2*e+1, 2*e+2];
        errorbar(x,y1,(y1-y2),(y3-y1),'o','Color',colors_tt{g,e+1},...
        'MarkerSize',6,'MarkerFaceColor',colors_tt{g,e+1}, 'MarkerEdgeColor',colors_tt{g,e+1});    
    
    end
    hold off
    set(gca, 'box','off','TickDir','out');
        ylim([-1 0.6]);
    yline(0, '--k');
    ylabel('\Deltaperformance with inhibition')
    xtickangle(45);
    xlim([0,5]);
    xticks([1 2 3 4])
    xticklabels({'Control Contra', 'Control Ipsi', 'Opto Contra', 'Opto Ipsi'})
    title(Genotypes{g});
    savefig(g2,fullfile(savePath,'Bootstrapping KO vs WT optoInhibition.fig'));
end

g2=figure(200);clf
for g=1:numel(Genotypes)
    subplot(1,2,numel(Genotypes)-g+1)
    hold on
    for e =0:numel(inhSites)-1
        delta_bootstrapped_g = photoInh_bootstrapped{2*g-1+e:2*g,3};
        sorted_delta = sort(delta_bootstrapped_g,1);   
        y1 = mean(sorted_delta,1); 
        y2 = sorted_delta(nboot*0.025,1:2); 
        y3 = sorted_delta(nboot*0.975,1:2); 
        x = [2*e+1, 2*e+2];
        
        x2 = repmat(x,[height(delta_bootstrapped_g),1]);
        y = sorted_delta;
        
        swarmchart(x2,y,0.5,'o','markerfacecolor', colors_tt{g,e+1}, 'MarkerEdgeColor', 'none');
        errorbar(x,y1,(y1-y2),(y3-y1),'o','Color','black',...
        'MarkerSize',6,'MarkerFaceColor','black', 'MarkerEdgeColor','black');   
    
    end
    hold off
    set(gca, 'box','off','TickDir','out');
    ylim([-0.6 0.4]);
    ylabel('\Deltaperformance with inhibition')
    yline(0, '--k');
    xtickangle(45);
    xlim([0,5]);
    xticks([1 2 3 4]);
    xticklabels({'Control Contra', 'Control Ipsi', 'Opto Contra', 'Opto Ipsi'})
    title(Genotypes{g});
    savefig(g2,fullfile(savePath,  ['Bootstrapping KO vs WT optoInhibition_scatter.fig']));

end

%Plot fracCorrect
for animalNum = 1:size(fracResult,2)
   
    for inhSite = 1:size(fracResult,2)
        g = figure(); clf;
        color = {[1 0 0], [0 1 0], [0 0 1]};
        hold on

        h = subplot(1,2,1);
        hold(h, 'on');
        for sessNum =1:size(fracResult{animalNum, inhSite},2)        
            
            plot([1:4], fracResult{animalNum, inhSite}{sessNum},'.', 'MarkerSize',15)
            line([1:4], fracResult{animalNum, inhSite}{sessNum})     
            
        end
        xlim([0,5]);
        ylim([0.2,1.0]);
        yline(0.5, '--k');
        ylabel('Fraction correct')
        xticks([1 2 3 4])
        xticklabels({'Left', 'Left+Opto','Right', 'Right+Opto'})
        title('CorrectFrac');
        hold(h, 'off');
        

        h = subplot(1,2,2);        
        hold(h, 'on');   
    
        for sessNum =1:size(fracResult{animalNum, inhSite},2)
            plot([1:4], missFrac{animalNum,inhSite}{sessNum},'.', 'MarkerSize',15)
            line([1:4], missFrac{animalNum,inhSite}{sessNum})
            
            
        %     saveas(g,[figureFolder '\intanSEbehav.png']);
        end
        xlim([0,5]);
        ylim([0.0,1.0]);       
        xticks([1 2 3 4])
        xticklabels({'Left', 'Left Opto','Right', 'Right Opto'})
        title('MissFrac');
        hold(h, 'off');

        sgtitle([animalID{animalNum} ' ' inhSitesAll{inhSite}]);
        savefig(g,fullfile(savePath,  [[animalID{animalNum} ' ' inhSitesAll{inhSite}] ' FracCorrect.fig']));
        hold off;
        

    end
    
end