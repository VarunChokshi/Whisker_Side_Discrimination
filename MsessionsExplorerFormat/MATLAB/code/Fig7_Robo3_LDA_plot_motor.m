% Data directory
% Robo3 > S1 > LDA > 50msBin > LDA_20Hz_50msBin_-50to0.mat
%                            > LDA_20Hz_50msBin_0to50.mat
%                            > LDA_100nBoot_20Hz_50msBin_-50to0.mat
%                            > LDA_100nBoot_20Hz_50msBin_0to50.mat
% Robo3 > Motor > LDA > 100msBin > LDA_20Hz_100msBin_-100to0.mat
%                                > LDA_20Hz_100msBin_0to100.mat
%                                > LDA_100nBoot_20Hz_100msBin_-100to0.mat
%                                > LDA_100nBoot_20Hz_100msBin_0to100.mat

%% Histogram of true and shuffled classification accuracy
clear all
close all
% Setting
mainDir = 'G:\VC03_RoboKO\EphysPassiveStimSEs\SingleUnitAnalysis'; % path to the Robo3 project folder
saveFigPath = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\Fig7';

recSiteDir = 'Motor';
bin = 0.1; % sec, S1: 0.05, Motor: 0.1
timeWindow = [-0.1, 0.1]; % sec, S1: [-0.05 0.05], Motor: [-0.1, 0.1]
binNum = (timeWindow(2) - timeWindow(1))/bin;
genotypes = {'WT' 'KO'};
shuffle_names = {'true' 'shuffled'};
shuffle_colors = {[0.5 0 0.5] [0.5 0.5 0.5]};
fileID = fopen(fullfile(saveFigPath,  ['LDA median values.txt']), 'w'); % Replace 'yourfile.txt' with your filename


for g = 1:size(genotypes,2)
    genotype = genotypes{g};
    gg =figure('Units', 'inches', 'Position',[1 1 3 1.5]);
    for b=1:binNum
        subplot(1,2,b)
        % Load data
        TimeStart = (b-1)*bin + timeWindow(1);
        TimeEnd = b*bin + timeWindow(1);
        accuracyPath = fullfile(mainDir, recSiteDir, 'LDA', [num2str(bin*1000) 'msBin'],['LDA_20Hz_' num2str(bin*1000) 'msBin_' num2str(TimeStart*1000) 'to' num2str(TimeEnd*1000) '.mat']);
        load(accuracyPath)
        isGenotype = cell2mat(cellfun(@(x) strcmp(x,genotype), LDA_table{:,2},'UniformOutput', false));
        isRespSession = LDA_table{:, 4} > 3;% The number of responsive unit is larger than respMin = 3. 
        xline(0.5,'--', 'LineWidth', 1, 'Color', 'k');hold on;
        
        for shuffle=1:2 
            ca = LDA_table{isGenotype & isRespSession, 4+shuffle}; % column 5: no shuffling, column 6: shuffling 
            if shuffle ==1
                lineWidth = 1;
            else
                lineWidth = 0.5;
            end
            h = histogram(ca,0:0.025:1,'FaceColor',shuffle_colors{shuffle},'FaceAlpha',0.6, 'LineWidth', lineWidth, 'EdgeColor', shuffle_colors{shuffle});hold on;
            % label median
            caMedian = median(ca,'omitnan');
            binCenters = (h.BinEdges(1:end-1) + h.BinEdges(2:end))/2; % Find bin centers
            [~, index] = min(abs(caMedian - binCenters));
            startTime = round(1000*(timeWindow(1) + (b-1)*bin)); 
            endTime =  round(1000*(timeWindow(1) + b*bin));
            fprintf(fileID, ['For ' recSiteDir ' ' genotype ' ' num2str(startTime) ' ~ ' ...
                num2str(endTime) ' ms: ' shuffle_names{shuffle} ' median is ' num2str(caMedian) '\n']); % Add median values to txt
            plot(binCenters(index),7,...
                 'v', 'LineWidth', 1, 'MarkerSize', 3,  'Color', shuffle_colors{shuffle});
           
            if b == 1
                text(0.65,(7.5-1*shuffle), shuffle_names{shuffle},'Color',shuffle_colors{shuffle}, 'FontSize', 8, 'FontName', 'Arial')
            end
            
        end
        ylim([0 8]);
        set(gca,'box','off','TickDir','out', 'XTick',0:0.25:1, 'YTick',0:2:8, 'FontSize', 8, 'FontName', 'Arial', 'LineWidth', 1)
%         if strcmp(genotype, 'KO')
%             xlabel('Classification accuracy', 'FontSize', 8, 'FontName', 'Arial')
%         end
%         
        if b==1
            ylabel('Number of sessions', 'FontSize', 8, 'FontName', 'Arial')
        end 
        
        title([num2str(startTime) ' ~ ' num2str(endTime) ' ms'], 'FontSize', 8, 'FontName', 'Arial');
    end
    sgtitle([recSiteDir ' ' genotype ' n= ' num2str(length(ca)) ' sessions'], 'FontSize', 8, 'FontName', 'Arial')
    histFigPath = fullfile(saveFigPath,...
        ['LDA_histogram_' recSiteDir '_' genotype '_20Hz_' num2str(1000*bin) 'msBin_' ...
        num2str(1000*timeWindow(1)) 'to' num2str(1000*timeWindow(2)) 'ms_3respMin']);
    exportgraphics(gg, [histFigPath '.pdf'],'Resolution', 1200);
    
    % Save fig
%     histFigPath = fullfile(mainDir, recSiteDir, 'LDA', [num2str(bin*1000) 'msBin'],...
%         ['LDA_histogram_' recSiteDir '_' genotype '_20Hz_' num2str(1000*bin) 'msBin_' num2str(1000*timeWindow(1)) 'to' num2str(1000*timeWindow(2)) 'ms_3respMin.pdf']);
%     print(histFigPath,'-dpdf','-painters','-loose');
end
fclose(fileID);
%% Plot 95% CI of bootstrapped and shuffled accuracy 
% Setting
% close all
mainDir = 'G:\VC03_RoboKO\EphysPassiveStimSEs\SingleUnitAnalysis'; % path to the Robo3 project folder
saveFigPath = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\Fig7';
recSiteDir = 'Motor';
bin = 0.1; % sec, S1: 0.05, Motor: 0.1
timeWindow = [-0.1, 0.1]; % sec, S1: [-0.05 0.05], Motor: [-0.1, 0.1]
binNum = (timeWindow(2) - timeWindow(1))/bin;
nBoot = 100;
genotypes = {'WT' 'KO'};
shuffle_names = {'true' 'shuffled'};
shuffle_colors = {[0.5 0 0.5] [0.5 0.5 0.5]};
fileID = fopen(fullfile(saveFigPath,  ['LDA bootstrapping CI values.txt']), 'w'); % Replace 'yourfile.txt' with your filename


gg =figure('Units', 'inches', 'Position',[1 1 3 1.75 ]);
for b= 1:binNum 
    TimeStart = (b-1)*bin + timeWindow(1);
    TimeEnd = b*bin + timeWindow(1);
    accuracyPath = fullfile(mainDir,recSiteDir, 'LDA',[num2str(bin*1000) 'msBin'], ['LDA_100nBoot_20Hz_' num2str(bin*1000) 'msBin_' num2str(TimeStart*1000) 'to' num2str(TimeEnd*1000) '.mat']);
    load(accuracyPath)
    subplot(1,2,b)
    for g = 1:length(genotypes) % 1: WT; 2: KO
        genotype = genotypes{g};
        for shuffle = 1:length(shuffle_names) % 1: no shuffling; 2: shuffling
            accuracy = sort(ca_table{g,1+shuffle});
            accuracy_mean = mean(accuracy);
            accuracy_up95CI = accuracy(round(0.975*nBoot));
            accuracy_low95CI = accuracy(round(0.025*nBoot));
            dataAccuracy(b,g,shuffle,1) =  accuracy_up95CI;
            dataAccuracy(b,g,shuffle,2) =  accuracy_low95CI;
            errorbar(g+shuffle*0.2-0.3,accuracy_mean,(accuracy_mean-accuracy_low95CI),(accuracy_up95CI-accuracy_mean),'o',...
                'Color', shuffle_colors{shuffle},'MarkerEdgeColor', shuffle_colors{shuffle},...
                'MarkerFaceColor',shuffle_colors{shuffle},'MarkerSize', 5,'CapSize', 4, 'LineWidth', 0.5); hold on;
            startTime = round(1000*TimeStart); 
            endTime =  round(1000*TimeEnd);
            fprintf(fileID, ['For ' recSiteDir ' ' genotype ' ' num2str(startTime) ' ~ ' ...
                num2str(endTime) ' ms: ' shuffle_names{shuffle} ' CI is ' ...
                num2str(accuracy_low95CI) ' to '  num2str(accuracy_up95CI) '\n']); % Add median values to txt
            % legend
            if b==1 && g==1
                text(1.5,(0.8-0.05*shuffle),shuffle_names{shuffle},'Color',shuffle_colors{shuffle}, 'FontSize', 8, 'FontName', 'Arial')
            end
        end
        set(gca,'box','off','TickDir','out', 'FontSize', 8, 'FontName', 'Arial', 'LineWidth', 1)
        xlim([0.5 2.5]);ylim([0.3 1]); 
        xticks(1:2);xticklabels(genotypes);
        ylabel('Classification accuracy', 'FontSize', 8, 'FontName', 'Arial');
        yline(0.5,'--', 'LineWidth', 1);
        title([num2str(TimeStart*1000) ' ~ ' num2str(TimeEnd*1000) ' ms'], 'FontSize', 8, 'FontName', 'Arial');
    end
end

histFigPath = fullfile(saveFigPath,...
        ['LDA_bootstrapping_' recSiteDir '_' genotype '_20Hz_' num2str(1000*bin) 'msBin_' ...
        num2str(1000*timeWindow(1)) 'to' num2str(1000*timeWindow(2)) 'ms_3respMin']);
exportgraphics(gg, [histFigPath '.pdf'],'Resolution', 1200);

% sgtitle(recSiteDir)
fclose(fileID);
% Save figure
% caFigPath = fullfile(mainDir,recSiteDir,'LDA',['LDA_100nBoot_20Hz_' num2str(bin*1000) 'msBin.pdf']);
% print(caFigPath,'-dpdf','-painters','-loose');


