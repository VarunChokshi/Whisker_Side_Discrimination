%% overall perf graphs 
clear all
animalID = {'VC030103', 'VC030104','VC030105', 'VC030106', 'VC030201', 'VC030202', 'VC030203', 'VC030204'};

%find Ses with the animal ID
seFolder = MBrowse.Folder([], 'Select se folder');
seFolderInfo = MUtil.Dir2Table(seFolder);
seFolderInfo(1:2,:) = [];
AnimalIDs = cellfun(@(x) strsplit(x), seFolderInfo.name, 'UniformOutput', false);

seFolderInfo.AnimalID = cellfun(@(x) x{1}, AnimalIDs, 'UniformOutput', false);




stimTypes =  {'SineAmp1p000Freq40Cyc40', 'SineAmp1p000Freq20Cyc40','SineAmp1p000Freq40Cyc3',...
            'SineAmp0p925Freq40Cyc3',...
            'SineAmp0p875Freq40Cyc3','SineAmp0p8375Freq40Cyc3',...
            'SineAmp0p750Freq40Cyc3','SineAmp0p700Freq40Cyc3',...
            'SineAmp0p675Freq40Cyc3','SineAmp0p625Freq40Cyc3',...
            'SineAmp0p550Freq40Cyc3','SineAmp0p500Freq40Cyc3','SineAmp0p375Freq40Cyc3',...
            'SineAmp0p300Freq40Cyc3','SineAmp0p250Freq40Cyc3','SineAmp0p200Freq40Cyc3',...
            'SineAmp0p150Freq40Cyc3','SineAmp0p100Freq40Cyc3','SineAmp0p50Freq40Cyc3',...
            'SineAmp0p25Freq40Cyc3','SineAmp1p000Freq20Cyc3', 'SineAmp0p925Freq20Cyc3',...
            'SineAmp0p875Freq20Cyc3','SineAmp0p8375Freq20Cyc3',...
            'SineAmp0p750Freq20Cyc3','SineAmp0p700Freq20Cyc3',...
            'SineAmp0p675Freq20Cyc3','SineAmp0p625Freq20Cyc3',...
            'SineAmp0p550Freq20Cyc3','SineAmp0p500Freq20Cyc3','SineAmp0p375Freq20Cyc3',...
            'SineAmp0p300Freq20Cyc3','SineAmp0p250Freq20Cyc3','SineAmp0p200Freq20Cyc3',...
            'SineAmp0p150Freq20Cyc3','SineAmp0p100Freq20Cyc3','SineAmp0p50Freq20Cyc3',...
            'SineAmp0p25Freq20Cyc3','SineAmp1p000Freq20Cyc1', 'SineAmp0p925Freq20Cyc1',...
            'SineAmp0p875Freq20Cyc1','SineAmp0p8375Freq20Cyc1',...
            'SineAmp0p750Freq20Cyc1','SineAmp0p700Freq20Cyc1',...
            'SineAmp0p675Freq20Cyc1','SineAmp0p625Freq20Cyc1',...
            'SineAmp0p550Freq20Cyc1','SineAmp0p500Freq20Cyc1','SineAmp0p375Freq20Cyc1',...
            'SineAmp0p300Freq20Cyc1','SineAmp0p250Freq20Cyc1','SineAmp0p200Freq20Cyc1',...
            'SineAmp0p150Freq20Cyc1','SineAmp0p100Freq20Cyc1','SineAmp0p50Freq20Cyc1',...
            'SineAmp0p25Freq20Cyc1'};
stimGrades = [1:numel(stimTypes)];
stimTypes2 =  {'SineAmp1p000Freq40Dur1p000', 'SineAmp1p000Freq20Dur1p000','SineAmp1p000Freq40Dur0p150',...
            'SineAmp0p925Freq40Dur0p150',...
            'SineAmp0p875Freq40Dur0p150','SineAmp0p8375Freq40Dur0p150',...
            'SineAmp0p750Freq40Dur0p150','SineAmp0p700Freq40Dur0p150',...
            'SineAmp0p675Freq40Dur0p150','SineAmp0p625Freq40Dur0p150',...
            'SineAmp0p550Freq40Dur0p150','SineAmp0p500Freq40Dur0p150','SineAmp0p375Freq40Dur0p150',...
            'SineAmp0p300Freq40Dur0p150','SineAmp0p250Freq40Dur0p150','SineAmp0p200Freq40Dur0p150',...
            'SineAmp0p150Freq40Dur0p150','SineAmp0p100Freq40Dur0p100','SineAmp0p50Freq40Dur0p150',...
            'SineAmp0p25Freq40Dur0p150','SineAmp1p000Freq20Dur0p150', 'SineAmp0p925Freq20Dur0p150',...
            'SineAmp0p875Freq20Dur0p150','SineAmp0p8375Freq20Dur0p150',...
            'SineAmp0p750Freq20Dur0p150','SineAmp0p700Freq20Dur0p150',...
            'SineAmp0p675Freq20Dur0p150','SineAmp0p625Freq20Dur0p150',...
            'SineAmp0p550Freq20Dur0p150','SineAmp0p500Freq20Dur0p150','SineAmp0p375Freq20Dur0p150',...
            'SineAmp0p300Freq20Dur0p150','SineAmp0p250Freq20Dur0p150','SineAmp0p200Freq20Dur0p150',...
            'SineAmp0p150Freq20Dur0p150','SineAmp0p100Freq20Dur0p150','SineAmp0p50Freq20Dur0p150',...
            'SineAmp0p25Freq20Dur0p150'};
stimGrades2 = [1:numel(stimTypes2)];



for animalnos = 1:size(animalID,2)
    animal = animalID{animalnos};     
    sessNum=1;

    for i = find(ismember(seFolderInfo.AnimalID, animal))'
        load(fullfile(seFolderInfo.folder{i}, seFolderInfo.name{i}));
        behavData = se.GetTable('behavValue');
        stimRight = behavData.rightStimType{end};
        stimLeft = behavData.leftStimType{end};
        if any(ismember(stimTypes, stimRight)) && any(ismember(stimTypes, stimLeft))

            responses = cell2mat(behavData.response);
            % remove abort trials
            abortTrials = find(responses ==3);
            behavData(abortTrials,:) = [];

           
            %separate miss trials
            responses = cell2mat(behavData.response);
            missTrials = find(responses==0);
            
            missData = behavData(missTrials, :);
            behavData(missTrials,:) = [];

             %remove catch trials
            result = behavData.result;
            catchTrials = find(isnan(result));
            behavData(catchTrials,:) = [];
            responses = cell2mat(behavData.response);

            result = behavData.result;
            correctTrials = find(result);
            try
                incorrectTrials = find(~result);
            catch
                keyboard;
            end
            missTrials = find(~cell2mat(missData.response));
            correctFrac{animalnos}(sessNum) = height(correctTrials)/(height(correctTrials)+height(incorrectTrials));
            incorrectFrac{animalnos}(sessNum) = height(incorrectTrials)/(height(correctTrials)+height(incorrectTrials));

          
            missFrac{animalnos}(sessNum) = height(missTrials)/(height(missTrials)+height(correctTrials)+height(incorrectTrials));
            
            rightGrade{animalnos}(sessNum) = find(ismember(stimTypes, stimRight));
        
            leftGrade{animalnos}(sessNum) = find(ismember(stimTypes, stimLeft));
            sessNum = sessNum +1;
        elseif any(ismember(stimTypes2, stimRight)) && any(ismember(stimTypes2, stimLeft))
             responses = cell2mat(behavData.response);
            % remove abort trials
            abortTrials = find(responses ==3);
            behavData(abortTrials,:) = [];
           
            %separate miss trials
            responses = cell2mat(behavData.response);
            missTrials = find(responses==0);
            
            missData = behavData(missTrials, :);
            behavData(missTrials,:) = [];

            %remove catch trials
            result = behavData.result;
            catchTrials = find(isnan(result));
            behavData(catchTrials,:) = [];
            responses = cell2mat(behavData.response);
            
            
            
            result = behavData.result;
            correctTrials = find(result);
            try
                incorrectTrials = find(~result);
            catch
                keyboard;
            end
    
            missTrials = find(~cell2mat(missData.response));
            correctFrac{animalnos}(sessNum) = height(correctTrials)/(height(correctTrials)+height(incorrectTrials));
            incorrectFrac{animalnos}(sessNum) = height(incorrectTrials)/(height(correctTrials)+height(incorrectTrials));

          
            missFrac{animalnos}(sessNum) = height(missTrials)/( height(missTrials)+height(correctTrials)+height(incorrectTrials));
            
            rightGrade{animalnos}(sessNum) = find(ismember(stimTypes2, stimRight));
        
            leftGrade{animalnos}(sessNum) = find(ismember(stimTypes2, stimLeft));
            sessNum = sessNum +1;
        else
            continue
            
        end
    end
    
      
end

pathParts = strsplit(seFolder, '\');
figureFolder = fullfile(pathParts{1:end-1}, 'Figures');
if ~exist(figureFolder, 'dir')
    mkdir(figureFolder);
end

close all
for i = 1:size(animalID,2)
    g=figure(i);clf
    hold on
%     yyaxis left
    plot(0:size(correctFrac{i},2)-1,0.7*ones(1,size(correctFrac{i},2)), '-.', 'LineWidth', 2)
    plot(correctFrac{i}, '-', 'color', [0 1 0], 'LineWidth', 4);      
    plot(missFrac{i}, '-', 'color', [0 0 0], 'lineWidth', 1)
    ylim([0,1]);
    ylabel('Fraction of trials')

%     yyaxis right
%     plot(rightGrade{i}/numel(stimTypes), '-', 'color', [0 0 1], 'lineWidth', 2);
%     plot(leftGrade{i}/numel(stimTypes), '-', 'color', [0.5 0 1], 'lineWidth', 2)    
    sgtitle(animalID{i})
%     ylim([0,1]);
    xlim([0,size(correctFrac{i},2)])
    xlabel('Session numbers')
%     ylabel('Stim difficulty')
%     ax = gca;
%     ax.YAxis(1).Color = 'k';
%     ax.YAxis(2).Color = 'b';

    hold off
    saveas(g,[figureFolder '\' animalID{i} '_perf.png']);
end


for i = 1:size(animalID,2)
    g=figure(i+size(animalID,2));clf
    hold on
    yyaxis left
    plot(0:size(correctFrac{i},2)-1,0.7*ones(1,size(correctFrac{i},2)), '-.', 'LineWidth', 2)
    plot(correctFrac{i}, '-', 'color', [0 1 0], 'LineWidth', 4);      
%     plot(missFrac{i}, '-', 'color', [0 0 0], 'lineWidth', 1)
    ylim([0,1]);
    ylabel('Fraction of trials')

    yyaxis right
    plot(rightGrade{i}/numel(stimTypes), '-', 'color', [0 0 1], 'lineWidth', 2);
    plot(leftGrade{i}/numel(stimTypes), '-', 'color', [1 0 0], 'lineWidth', 2)    
    sgtitle(animalID{i})
    ylim([0,1]);
    xlim([0,size(correctFrac{i},2)])
    xlabel('Session numbers')
    ylabel('Stim difficulty')
    ax = gca;
    ax.YAxis(1).Color = 'k';
    ax.YAxis(2).Color = [0.91 0.41 0.17];

    hold off
    saveas(g,[figureFolder '\' animalID{i} '_stim.png']);
end