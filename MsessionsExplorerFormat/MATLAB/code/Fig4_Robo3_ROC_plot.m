% Data directory
% Robo3 > S1 > ROC > 5msBin > Unit_AUC_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin.mat
%                  > 50msBin > Unit_AUC_20Hz_50msBin_-50to150ms_1000nBoot_150pvalueMin.mat
% Robo3 > Motor > ROC > 5msBin > Unit_AUC_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin.mat
%                     > 50msBin > Unit_AUC_20Hz_50msBin_-50to150ms_1000nBoot_150pvalueMin.mat                 

%% Setting
mainDir = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\SeData\EphysPassiveStimSEs\SingleUnitAnalysis'; % path to the Robo3 project folder
recSiteDir = 'S1';
analysisDir = 'ROC';
saveFigPath = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\Fig4';
% bin = 0.05; % sec
% timeWindow = [-0.1, 0.1]; 
% time = timeWindow(1)+bin:bin:timeWindow(2);
% time_bw = [time, fliplr(time)];
% smoothWindow = 1; % smooth window of Gaussian filter 
% plotWindow = [-0.05 0.15];
% binNum = (timeWindow(2) - timeWindow(1))/bin;
% frq = '20'; % Hz
tt_colors = {'r' 'b'}; % controlateral, ipsilateral
% nBoot_fr=100; % number of resampling for calculatingmean firing rate
% nBoot_AUC = 1000; % AUC
% pvalueMin_Window = '150'; % ex: '50': -50~0 vs 0~50 ms
% pvalueMin_alpha = 0.01; % significance level for responsive units
% save_path = fullfile(mainDir, recSiteDir, analysisDir, [num2str(bin*1000) 'msBin'],['unit_plot_' num2str(bin*1000) 'msBin']);
genotypes = {'WT' 'KO'};
geno_lines = {'-' '--'};
% recSites = {'S1' 'Motor'};
% recSite_lines = {'-' '--'};
alpha = 0.05;

% 
% % for analysis of significant side selectivity
% analysisWindow = [0 0.15];
% binStart =round((analysisWindow(1)-timeWindow(1))/bin)+1;
% binEnd = round((analysisWindow(2)-timeWindow(1))/bin);
% significant_bins = 3;
% switch recSiteDir
%     case 'S1'
%         recSite_sides = {'Left wS1' 'Right wS1'};
%     case 'Motor'
%         recSite_sides = {'Left wM1' 'Right wM1'};
% end

%% Distribution of AUC for each 50ms bin
% Histogram (normalization: probability)
% Units showing significant side selectivity are labeld in black.  
close all
% Setting
% mainDir = 'E:\Robo3'; % path to the Robo3 project folder
recSiteDir = 'S1';
genotypes = {'WT' 'KO'};
bin = 0.05; % sec
timeWindow = [-0.05, 0.15]; % sec
binNum = (timeWindow(2) - timeWindow(1))/bin;
alpha = 0.05;
nBoot_AUC = 1000;
% Load data
load(fullfile(mainDir, recSiteDir, 'ROC', '50msBin', 'Unit_AUC_20Hz_50msBin_-50to150ms_1000nBoot_150pvalueMin.mat'))

for g = 1:size(genotypes,2)
    genotype = genotypes{g};
    isGenotype = cell2mat(cellfun(@(x) strcmp(x,genotype), AUC_table{:,2},'UniformOutput', false));
    AUC_genotype = AUC_table{isGenotype, 4};
    AUC_sessions = [];
    % concatenation across sessions
    for session=1:size(AUC_genotype,1)
        AUC_session = AUC_genotype{session};
        AUC_sessions = [AUC_sessions AUC_session];
    end
    isResp = cell2mat(cellfun(@(x) iscell(x), AUC_sessions,'UniformOutput', false)); % Find responsive units
    AUC_resp = AUC_sessions(isResp);
    gg = figure('Units', 'inches', 'Position',[1 1 4.5 1.65]);
     
    N = size(AUC_resp,2);
    alpha_Bonferroni = alpha/N; % Bonferroni correction
   
    for b=1:binNum-1
        AUC_mean = cellfun(@(x) mean(x{b,1}), AUC_resp,'UniformOutput', false);
        AUC_upCI = cellfun(@(x) x{b,1}(ceil((1-alpha_Bonferroni/2)*nBoot_AUC)), AUC_resp,'UniformOutput', false);
        AUC_lowCI = cellfun(@(x) x{b,1}(ceil((alpha_Bonferroni/2)*nBoot_AUC)), AUC_resp,'UniformOutput', false);
        isSignificant = cell2mat(cellfun(@(x,y) (0.5-x)*(0.5-y)>0, AUC_upCI, AUC_lowCI,'UniformOutput', false));
        isConPref = cell2mat(AUC_mean) > 0.5;
        isIpsiPref = cell2mat(AUC_mean) < 0.5;
        sig_percent_con = round(sum(isSignificant & isConPref)/length(isSignificant)*100,1);
        sig_percent_ipsi = round(sum(isSignificant & isIpsiPref)/length(isSignificant)*100,1);
        con_sig_ratio = round(sig_percent_con/(sig_percent_con + sig_percent_ipsi),2);
%         sig_percent = round(sum(isSignificant)/length(isSignificant)*100,1);
        ax = subplot(1,3,b);
        h_all = histogram(cell2mat(AUC_mean),[0:0.05:1], 'FaceColor','white');hold on;
        h_sig_contra = histogram(cell2mat(AUC_mean(isSignificant & isConPref)),[0:0.05:1], 'FaceColor',[1 0 0], 'FaceAlpha',0.6); 
        h_sig_ipsi = histogram(cell2mat(AUC_mean(isSignificant & isIpsiPref)),[0:0.05:1], 'FaceColor',[0 0 1], 'FaceAlpha',0.6);hold off; 
        h_all_normalization = h_all.Values/length(AUC_mean);
        h_sig_contra_normalization = h_sig_contra.Values/length(AUC_mean);
        h_sig_ipsi_normalization = h_sig_ipsi.Values/length(AUC_mean);
        h_all_prb = histogram('BinEdges',[0:0.05:1], 'BinCounts',h_all_normalization,'FaceColor','white');hold on;
        h_sig_contra_prb = histogram('BinEdges',[0:0.05:1], 'BinCounts',h_sig_contra_normalization,'FaceColor',[1 0 0], 'FaceAlpha',0.6);
        h_sig_ipsi_prb = histogram('BinEdges',[0:0.05:1], 'BinCounts',h_sig_ipsi_normalization,'FaceColor',[0 0 1], 'FaceAlpha',0.6);hold off; 
        max_count = max([h_all_prb.Values h_sig_contra_prb.Values h_sig_ipsi_prb.Values]);
        min_count = min([h_all_prb.Values h_sig_contra_prb.Values h_sig_ipsi_prb.Values]);
        ylim_max = round(max_count+ 0.1*(max_count - min_count),2);
        %     ylim([0 ylim_max]);
        if b ==1
            ylim([0 0.6]);
        else
            ylim([0 0.45]);
        end
%         if strcmp(genotype, 'KO')
%             xlabel('AUC', 'FontName', 'Arial', 'FontSize', 8)
%         end
        xticks([0:0.1:1])
        xticklabels({0 [] [] [] [] 0.5 [] [] [] [] 1})
        %     yticks([0:0.05:ylim_max])
        yticks(0:0.2:0.6)
        set(gca, 'box','off','TickDir','out', 'FontName', 'Arial', 'FontSize', 8, 'LineWidth', 1)
        text(0.7,0.3,[num2str(sig_percent_con), '%'], 'FontSize', 8, 'FontName', 'Arial', 'Color', [1 0 0])
        text(0.075,0.3,[num2str(sig_percent_ipsi), '%'], 'FontSize', 8, 'FontName', 'Arial', 'Color', [0 0 1])

        ax.XTickLabelRotation=0;
        if bin ==1
            ylabel('Fraction of units', 'FontName', 'Arial', 'FontSize', 8)
        end
        startTime = round(1000*(timeWindow(1) + (b-1)*bin)); 
        endTime =  round(1000*(timeWindow(1) + b*bin));
        title([num2str(startTime) ' ~ ' num2str(endTime) ' ms'], 'FontSize', 8, 'FontName', 'Arial', 'FontWeight', 'normal');
    end
%     sgtitle([genotype ' n= ' num2str(N) ' units'], 'FontSize', 8, 'FontName', 'Arial')
    
        % Save fig
    histFigPath = fullfile(saveFigPath,...
        ['AUC_histogram_' recSiteDir '_' genotype '_20Hz_50msBin_-50to150ms_1000nBoot_150pvalueMin']);
    exportgraphics(gg, [histFigPath '.pdf'],'Resolution', 1200);

    % Save fig
%     histFigPath = fullfile(mainDir, recSiteDir, 'ROC',...
%         ['AUC_histogram_' recSiteDir '_' genotype '_20Hz_50msBin_-50to150ms_1000nBoot_150pvalueMin.pdf']);
%     print(histFigPath,'-dpdf','-painters','-loose');
end

%% Distribution of AUC for each 50ms bin bootstrapping confidence interval
% Histogram (normalization: probability)
% Units showing significant side selectivity are labeld in black.  
close all
saveFigPath = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\FigS5';
% Setting
% mainDir = 'E:\Robo3'; % path to the Robo3 project folder
recSiteDir = 'S1';
genotypes = {'WT' 'KO'};
bin = 0.05; % sec
timeWindow = [-0.05, 0.15]; % sec
binNum = (timeWindow(2) - timeWindow(1))/bin;
alpha = 0.05;
nBoot_AUC = 1000;
nboot_test = 1000;
shuffle_names = {'real' 'mixed'};
shuffle_colors = {[0.5 0 0.5] [0.5 0.5 0.5]};
stimNames = {'Ipsi', 'Contra'};
ymax = 65;
% Load data
load(fullfile(mainDir, recSiteDir, 'ROC', '50msBin', 'Unit_AUC_20Hz_50msBin_-50to150ms_1000nBoot_150pvalueMin.mat'))

sig_percent_con_over = [];
sig_percent_ipsi_over = [];

for g = 1:size(genotypes,2)
    genotype = genotypes{g};
    isGenotype = cell2mat(cellfun(@(x) strcmp(x,genotype), AUC_table{:,2},'UniformOutput', false));
    AUC_genotype = AUC_table{isGenotype, 4};
    AUC_sessions = [];
    % concatenation across sessions
    for session=1:size(AUC_genotype,1)
        AUC_session = AUC_genotype{session};
        AUC_sessions = [AUC_sessions AUC_session];
    end
    isResp = cell2mat(cellfun(@(x) iscell(x), AUC_sessions,'UniformOutput', false)); % Find responsive units
    AUC_resp{g} = AUC_sessions(isResp);

    for b=1:binNum-1
        AUC_mean = cellfun(@(x) mean(x{b,1}), AUC_resp{g},'UniformOutput', false);
        AUC_upCI = cellfun(@(x) x{b,1}(ceil((1-alpha_Bonferroni/2)*nBoot_AUC)), AUC_resp{g},'UniformOutput', false);
        AUC_lowCI = cellfun(@(x) x{b,1}(ceil((alpha_Bonferroni/2)*nBoot_AUC)), AUC_resp{g},'UniformOutput', false);
        isSignificant = cell2mat(cellfun(@(x,y) (0.5-x)*(0.5-y)>0, AUC_upCI, AUC_lowCI,'UniformOutput', false));
        isConPref = cell2mat(AUC_mean) > 0.5;
        isIpsiPref = cell2mat(AUC_mean) < 0.5;
        sig_percent_con_over(g,b) = round(sum(isSignificant & isConPref)/length(isSignificant)*100,1);
        sig_percent_ipsi_over(g,b) = round(sum(isSignificant & isIpsiPref)/length(isSignificant)*100,1);
    end

end

 

sig_percent_ipsi = {};
sig_percent_con = {};
sig_percent_con_mixed = {};
sig_percent_ipsi_mixed = {};
allAUC = [AUC_resp{1}, AUC_resp{2}];

for boot =1:nboot_test
    
    for b=1:binNum-1
    
        
        
        
        
        
        
       N = {};


        for g = 1:numel(genotypes)
            % get for real geno
            genoAUC = AUC_resp{g};        
            N{g} = size(genoAUC,2);
            alpha_Bonferroni = alpha/N{g}; % Bonferroni correction
            genoAUC = datasample(genoAUC, N{g});
            AUC_mean = cellfun(@(x) mean(x{b,1}), genoAUC,'UniformOutput', false);
            AUC_upCI = cellfun(@(x) x{b,1}(ceil((1-alpha_Bonferroni/2)*nBoot_AUC)), genoAUC,'UniformOutput', false);
            AUC_lowCI = cellfun(@(x) x{b,1}(ceil((alpha_Bonferroni/2)*nBoot_AUC)), genoAUC,'UniformOutput', false);
            isSignificant = cell2mat(cellfun(@(x,y) (0.5-x)*(0.5-y)>0, AUC_upCI, AUC_lowCI,'UniformOutput', false));
            isConPref = cell2mat(AUC_mean) > 0.5;
            isIpsiPref = cell2mat(AUC_mean) < 0.5;
            sig_percent_con{g}(boot,b) = round(sum(isSignificant & isConPref)/length(isSignificant)*100,1);
            sig_percent_ipsi{g}(boot,b) = round(sum(isSignificant & isIpsiPref)/length(isSignificant)*100,1);
            
        end

        % get for normal Comnbined
        
        
%         N = size(allAUC,2);
%         alpha_Bonferroni = alpha/N; % Bonferroni correction


    
    end
end

fileID = fopen(fullfile(saveFigPath, ['Statistics_permutationtest.txt']), 'w');

% gg =figure('Units', 'inches', 'Position',[1 1 3 1.75 ]);
gg = figure(1); clf;
for b= 1:binNum-1 
    TimeStart = (b-1)*bin + timeWindow(1);
    TimeEnd = b*bin + timeWindow(1);
    
    
    for g = 1:length(genotypes) % 1: WT; 2: KO
        genotype = genotypes{g};
        sigVals{1,2} = sig_percent_con_over(g,b);
        sigVals{2,2} = sig_percent_con{g}(:,b);  

        sigVals{1,1} = sig_percent_ipsi_over(g,b);
        sigVals{2,1} = sig_percent_ipsi{g}(:,b);
        
        
        
        
        for stim =1:width(sigVals) % contra, ipsi
            
            for shuffle = 2 % 1: no shuffling; 2: shuffling

                accuracy = sort(sigVals{2, stim});
                accuracy_mean = sigVals{1, stim};
                accuracy_up95CI = accuracy(round(0.975*nboot_test));
                accuracy_low95CI = accuracy(round(0.025*nboot_test));
                subplot(3,binNum-1 ,(binNum-1 )*(g-1) + b)
                errorbar(stim,accuracy_mean,(accuracy_mean-accuracy_low95CI),(accuracy_up95CI-accuracy_mean),'o',...
                    'Color', shuffle_colors{1},'MarkerEdgeColor', shuffle_colors{1},...
                    'MarkerFaceColor',shuffle_colors{1},'MarkerSize', 4,'CapSize', 6, 'LineWidth', 0.5); hold on;

                startTime = round(1000*TimeStart); 
                endTime =  round(1000*TimeEnd);
                fprintf(fileID, ['For ' recSiteDir ' ' genotype ' ' stimNames{stim} ' ' num2str(startTime) ' ~ ' ...
                    num2str(endTime) ' ms: ' shuffle_names{1} ' CI is ' ...
                    num2str(accuracy_low95CI) ' to '  num2str(accuracy_up95CI) '\n']); % Add median values to txt
                % legend
%                 if b==1 && g==1
%                     text(1.5,(ymax-5*1),shuffle_names{1},'Color',shuffle_colors{1}, 'FontSize', 8, 'FontName', 'Arial')
%                 end
            end
            set(gca,'box','off','TickDir','out', 'FontSize', 8, 'FontName', 'Arial', 'LineWidth', 1)
            xlim([0.5 2.5]);ylim([-5 ymax]); 
            xticks(1:2);xticklabels(stimNames);
            ylabel('Percent units', 'FontSize', 8, 'FontName', 'Arial');
            yline(0,'--', 'LineWidth', 1);
            title([num2str(TimeStart*1000) ' ~ ' num2str(TimeEnd*1000) ' ms'], 'FontSize', 8, 'FontName', 'Arial');
        end
    end
end

stim_Over = {sig_percent_ipsi_over, sig_percent_con_over};

for b = 1:binNum-1
    TimeStart = (b-1)*bin + timeWindow(1);
    TimeEnd = b*bin + timeWindow(1);
    sigVals{1,2} = sig_percent_con{1}(:,b) -  sig_percent_con{2}(:,b);
    
    sigVals{1,1} = sig_percent_ipsi{1}(:,b) - sig_percent_ipsi{2}(:,b);

    for stim =1:width(sigVals) % contra, ipsi
        
        for shuffle = 1 % 1: no shuffling; 2: shuffling

            accuracy = sort(sigVals{shuffle, stim});
          
       
            overal_diff = stim_Over{stim}(1,b) - stim_Over{stim}(2,b);
            accuracy_mean = mean(accuracy);
            accuracy_up95CI = accuracy(round(0.975*nboot_test));
            accuracy_low95CI = accuracy(round(0.025*nboot_test));
            
            
            subplot(3,binNum-1 ,(binNum-1 )*(3-1) + b)
            errorbar(stim,overal_diff,(accuracy_mean-accuracy_low95CI),(accuracy_up95CI-accuracy_mean),'o',...
                'Color', shuffle_colors{shuffle},'MarkerEdgeColor', shuffle_colors{shuffle},...
                'MarkerFaceColor',shuffle_colors{shuffle},'MarkerSize', 4,'CapSize', 6, 'LineWidth', 0.5); hold on;

            startTime = round(1000*TimeStart); 
            endTime =  round(1000*TimeEnd);
            fprintf(fileID, ['For ' recSiteDir ' WT-KO ' stimNames{stim} ' ' num2str(startTime) ' ~ ' ...
                num2str(endTime) ' ms: ' shuffle_names{shuffle} ' CI is ' ...
                num2str(accuracy_low95CI) ' to '  num2str(accuracy_up95CI) '\n']); % Add median values to txt
            % legend
            if b==1 && g==1
                text(1.5,(ymax-5*shuffle),shuffle_names{shuffle},'Color',shuffle_colors{shuffle}, 'FontSize', 8, 'FontName', 'Arial')
            end
        end

        set(gca,'box','off','TickDir','out', 'FontSize', 8, 'FontName', 'Arial', 'LineWidth', 1)
        xlim([0.5 2.5]);ylim([-30 ymax]); 
        xticks(1:2);xticklabels(stimNames);
        ylabel('\Delta Percent units', 'FontSize', 8, 'FontName', 'Arial');
        yline(0,'--', 'LineWidth', 1);
        title([num2str(TimeStart*1000) ' ~ ' num2str(TimeEnd*1000) ' ms'], 'FontSize', 8, 'FontName', 'Arial');
    end

end


fclose(fileID);
histFigPath = fullfile(saveFigPath,...
        ['ROC_permutation_' recSiteDir '_' genotype '_20Hz_' num2str(1000*bin) 'msBin_' ...
        num2str(1000*timeWindow(1)) 'to' num2str(1000*timeWindow(2)) 'ms_3respMin']);
exportgraphics(gg, [histFigPath '.pdf'],'Resolution', 300);

%% Distribution of AUC for each 50ms bin permutation test - 2 250304
% Histogram (normalization: probability)
% Units showing significant side selectivity are labeld in black.  
close all
% Setting
% mainDir = 'E:\Robo3'; % path to the Robo3 project folder
recSiteDir = 'S1';
genotypes = {'WT' 'KO'};
bin = 0.05; % sec
timeWindow = [-0.05, 0.15]; % sec
binNum = (timeWindow(2) - timeWindow(1))/bin;
alpha = 0.05;
nBoot_AUC = 1000;
nboot_test = 1000;
shuffle_names = {'real' 'mixed'};
shuffle_colors = {[0.5 0 0.5] [0.5 0.5 0.5]};
stimNames = {'Ipsi', 'Contra'};
ymax = 65;
% Load data
load(fullfile(mainDir, recSiteDir, 'ROC', '50msBin', 'Unit_AUC_20Hz_50msBin_-50to150ms_1000nBoot_150pvalueMin.mat'))

sig_percent_con_over = [];
sig_percent_ipsi_over = [];

for g = 1:size(genotypes,2)
    genotype = genotypes{g};
    isGenotype = cell2mat(cellfun(@(x) strcmp(x,genotype), AUC_table{:,2},'UniformOutput', false));
    AUC_genotype = AUC_table{isGenotype, 4};
    AUC_sessions = [];
    % concatenation across sessions
    for session=1:size(AUC_genotype,1)
        AUC_session = AUC_genotype{session};
        AUC_sessions = [AUC_sessions AUC_session];
    end
    isResp = cell2mat(cellfun(@(x) iscell(x), AUC_sessions,'UniformOutput', false)); % Find responsive units
    AUC_resp{g} = AUC_sessions(isResp);

    for b=1:binNum-1
        AUC_mean = cellfun(@(x) mean(x{b,1}), AUC_resp{g},'UniformOutput', false);
        AUC_upCI = cellfun(@(x) x{b,1}(ceil((1-alpha_Bonferroni/2)*nBoot_AUC)), AUC_resp{g},'UniformOutput', false);
        AUC_lowCI = cellfun(@(x) x{b,1}(ceil((alpha_Bonferroni/2)*nBoot_AUC)), AUC_resp{g},'UniformOutput', false);
        isSignificant = cell2mat(cellfun(@(x,y) (0.5-x)*(0.5-y)>0, AUC_upCI, AUC_lowCI,'UniformOutput', false));
        isConPref = cell2mat(AUC_mean) > 0.5;
        isIpsiPref = cell2mat(AUC_mean) < 0.5;
        sig_percent_con_over(g,b) = round(sum(isSignificant & isConPref)/length(isSignificant)*100,1);
        sig_percent_ipsi_over(g,b) = round(sum(isSignificant & isIpsiPref)/length(isSignificant)*100,1);
    end

end

 

sig_percent_ipsi = {};
sig_percent_con = {};
sig_percent_con_mixed = {};
sig_percent_ipsi_mixed = {};
allAUC = [AUC_resp{1}, AUC_resp{2}];

for boot =1:nboot_test
    
    for b=1:binNum-1
    
        
        
        
        
        
        
       N = {};


        for g = 1:numel(genotypes)
            % get for real geno
            genoAUC = AUC_resp{g};        
            N{g} = size(genoAUC,2);
            alpha_Bonferroni = alpha/N{g}; % Bonferroni correction
            genoAUC = datasample(genoAUC, N{g});
            AUC_mean = cellfun(@(x) mean(x{b,1}), genoAUC,'UniformOutput', false);
            AUC_upCI = cellfun(@(x) x{b,1}(ceil((1-alpha_Bonferroni/2)*nBoot_AUC)), genoAUC,'UniformOutput', false);
            AUC_lowCI = cellfun(@(x) x{b,1}(ceil((alpha_Bonferroni/2)*nBoot_AUC)), genoAUC,'UniformOutput', false);
            isSignificant = cell2mat(cellfun(@(x,y) (0.5-x)*(0.5-y)>0, AUC_upCI, AUC_lowCI,'UniformOutput', false));
            isConPref = cell2mat(AUC_mean) > 0.5;
            isIpsiPref = cell2mat(AUC_mean) < 0.5;
            sig_percent_con{g}(boot,b) = round(sum(isSignificant & isConPref)/length(isSignificant)*100,1);
            sig_percent_ipsi{g}(boot,b) = round(sum(isSignificant & isIpsiPref)/length(isSignificant)*100,1);
            
        end

        % get for normal Comnbined
        
        
%         N = size(allAUC,2);
%         alpha_Bonferroni = alpha/N; % Bonferroni correction


        [mixedAUC{1}, idx] = datasample(allAUC, N{1}, 'Replace', false);
        mixedAUC{2} = allAUC(~ismember(1:numel(allAUC), idx));
        
         for g = 1:numel(genotypes)
            alpha_Bonferroni = alpha/N{g};
            AUC_mean = cellfun(@(x) mean(x{b,1}), mixedAUC{g},'UniformOutput', false);
            AUC_upCI = cellfun(@(x) x{b,1}(ceil((1-alpha_Bonferroni/2)*nBoot_AUC)), mixedAUC{g},'UniformOutput', false);
            AUC_lowCI = cellfun(@(x) x{b,1}(ceil((alpha_Bonferroni/2)*nBoot_AUC)), mixedAUC{g},'UniformOutput', false);
            isSignificant = cell2mat(cellfun(@(x,y) (0.5-x)*(0.5-y)>0, AUC_upCI, AUC_lowCI,'UniformOutput', false));
            isConPref = cell2mat(AUC_mean) > 0.5;
            isIpsiPref = cell2mat(AUC_mean) < 0.5;
            sig_percent_con_mixed{g}(boot,b) = round(sum(isSignificant & isConPref)/length(isSignificant)*100,1);
            sig_percent_ipsi_mixed{g}(boot,b) = round(sum(isSignificant & isIpsiPref)/length(isSignificant)*100,1);
            
        end
    
    end
end

fileID = fopen(fullfile(saveFigPath, ['Statistics_permutationtest_2.txt']), 'w');

% gg =figure('Units', 'inches', 'Position',[1 1 3 1.75 ]);
gg = figure(1); clf;
for b= 1:binNum-1 
    TimeStart = (b-1)*bin + timeWindow(1);
    TimeEnd = b*bin + timeWindow(1);
    
    
    for g = 1:length(genotypes) % 1: WT; 2: KO
        genotype = genotypes{g};
        sigVals{1,2} = sig_percent_con_over(g,b);
        sigVals{2,2} = sig_percent_con{g}(:,b);  

        sigVals{1,1} = sig_percent_ipsi_over(g,b);
        sigVals{2,1} = sig_percent_ipsi{g}(:,b);
        
        
        
        
        for stim =1:width(sigVals) % contra, ipsi
            
            for shuffle = 2 % 1: no shuffling; 2: shuffling

                accuracy = sort(sigVals{2, stim});
                accuracy_mean = sigVals{1, stim};
                accuracy_up95CI = accuracy(round(0.975*nboot_test));
                accuracy_low95CI = accuracy(round(0.025*nboot_test));
                subplot(3,binNum-1 ,(binNum-1 )*(g-1) + b)
                errorbar(stim,accuracy_mean,(accuracy_mean-accuracy_low95CI),(accuracy_up95CI-accuracy_mean),'o',...
                    'Color', shuffle_colors{1},'MarkerEdgeColor', shuffle_colors{1},...
                    'MarkerFaceColor',shuffle_colors{1},'MarkerSize', 4,'CapSize', 6, 'LineWidth', 0.5); hold on;

                startTime = round(1000*TimeStart); 
                endTime =  round(1000*TimeEnd);
                fprintf(fileID, ['For ' recSiteDir ' ' genotype ' ' stimNames{stim} ' ' num2str(startTime) ' ~ ' ...
                    num2str(endTime) ' ms: ' shuffle_names{1} ' CI is ' ...
                    num2str(accuracy_low95CI) ' to '  num2str(accuracy_up95CI) '\n']); % Add median values to txt
                % legend
%                 if b==1 && g==1
%                     text(1.5,(ymax-5*1),shuffle_names{1},'Color',shuffle_colors{1}, 'FontSize', 8, 'FontName', 'Arial')
%                 end
            end
            set(gca,'box','off','TickDir','out', 'FontSize', 8, 'FontName', 'Arial', 'LineWidth', 1)
            xlim([0.5 2.5]);ylim([-5 ymax]); 
            xticks(1:2);xticklabels(stimNames);
            ylabel('Percent units', 'FontSize', 8, 'FontName', 'Arial');
            yline(0,'--', 'LineWidth', 1);
            title([num2str(TimeStart*1000) ' ~ ' num2str(TimeEnd*1000) ' ms'], 'FontSize', 8, 'FontName', 'Arial');
        end
    end
end

stim_Over = {sig_percent_ipsi_over, sig_percent_con_over};

for b = 1:binNum-1
    TimeStart = (b-1)*bin + timeWindow(1);
    TimeEnd = b*bin + timeWindow(1);
    sigVals{1,2} = sig_percent_con{1}(:,b) -  sig_percent_con{2}(:,b);
    
    sigVals{1,1} = sig_percent_ipsi{1}(:,b) - sig_percent_ipsi{2}(:,b);

    for stim =1:width(sigVals) % contra, ipsi
        
        for shuffle = 1 % 1: no shuffling; 2: shuffling

            accuracy = sort(sigVals{shuffle, stim});
          
       
            overal_diff = stim_Over{stim}(1,b) - stim_Over{stim}(2,b);
            accuracy_mean = mean(accuracy);
            accuracy_up95CI = accuracy(round(0.975*nboot_test));
            accuracy_low95CI = accuracy(round(0.025*nboot_test));
            
            
            subplot(3,binNum-1 ,(binNum-1 )*(3-1) + b)
            errorbar(stim,overal_diff,(accuracy_mean-accuracy_low95CI),(accuracy_up95CI-accuracy_mean),'o',...
                'Color', shuffle_colors{shuffle},'MarkerEdgeColor', shuffle_colors{shuffle},...
                'MarkerFaceColor',shuffle_colors{shuffle},'MarkerSize', 4,'CapSize', 6, 'LineWidth', 0.5); hold on;

            startTime = round(1000*TimeStart); 
            endTime =  round(1000*TimeEnd);
            fprintf(fileID, ['For ' recSiteDir ' ' genotype ' ' stimNames{stim} ' ' num2str(startTime) ' ~ ' ...
                num2str(endTime) ' ms: ' shuffle_names{shuffle} ' CI is ' ...
                num2str(accuracy_low95CI) ' to '  num2str(accuracy_up95CI) '\n']); % Add median values to txt
            % legend
            if b==1 && g==1
                text(1.5,(ymax-5*shuffle),shuffle_names{shuffle},'Color',shuffle_colors{shuffle}, 'FontSize', 8, 'FontName', 'Arial')
            end
        end
%         pvalue = mean(abs(stim_Over{stim}(1,b) - stim_Over{stim}(2,b))<= abs(sigVals{2, stim}));
%         fprintf(fileID, ['For ' recSiteDir ' WT-KO ' stimNames{stim} ' ' num2str(startTime) ' ~ ' ...
%                 num2str(endTime) ' ms Permutation WT - KO p-value: ' num2str(pvalue)  '\n']);

        set(gca,'box','off','TickDir','out', 'FontSize', 8, 'FontName', 'Arial', 'LineWidth', 1)
        xlim([0.5 2.5]);ylim([-12 ymax]); 
        xticks(1:2);xticklabels(stimNames);
        ylabel('\Delta Percent units', 'FontSize', 8, 'FontName', 'Arial');
        yline(0,'--', 'LineWidth', 1);
        title([num2str(TimeStart*1000) ' ~ ' num2str(TimeEnd*1000) ' ms'], 'FontSize', 8, 'FontName', 'Arial');
    end

end


histFigPath = fullfile(saveFigPath,...
        ['ROC_permutation_' recSiteDir '_' genotype '_20Hz_' num2str(1000*bin) 'msBin_' ...
        num2str(1000*timeWindow(1)) 'to' num2str(1000*timeWindow(2)) 'ms_3respMin']);
exportgraphics(gg, [histFigPath 'statisticalOnly.pdf'],'Resolution', 300);



%% Percentage of significant units over time (5ms bin)
close all
% Setting
% mainDir = 'E:\Robo3'; % path to the Robo3 project folder
recSiteDir = 'S1';
genotypes = {'WT' 'KO'};
bin = 0.005; % sec
timeWindow = [-0.05, 0.15]; % sec
binNum = (timeWindow(2) - timeWindow(1))/bin;
alpha = 0.05;
nBoot_AUC = 1000;
% Figure setting
tt_colors = {'r' 'b'}; % controlateral in red, ipsilateral in blue 
geno_lines = {'-' '--'}; % WT: -, KO: --
time = timeWindow(1)+bin:bin:timeWindow(2);
% Load data
load(fullfile(mainDir, recSiteDir, 'ROC', '5msBin', 'Unit_AUC_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin.mat'))

gg = figure('Units', 'inches', 'Position',[1 1 1.875 1.42]);

for g = 1:size(genotypes,2)
    genotype = genotypes{g};
    isGenotype = cell2mat(cellfun(@(x) strcmp(x,genotype), AUC_table{:,2},'UniformOutput', false));
    AUC_genotype = AUC_table{isGenotype, 4};
    AUC_sessions = [];
    % concatenation across sessions
    for session=1:size(AUC_genotype,1)
        AUC_session = AUC_genotype{session};
        AUC_sessions = [AUC_sessions AUC_session];
    end
    isResp = cell2mat(cellfun(@(x) iscell(x), AUC_sessions,'UniformOutput', false)); % Find responsive units
    AUC_resp = AUC_sessions(isResp);
    N = size(AUC_resp,2);
    alpha_Bonferroni = alpha/N; % Bonferroni correction
   
    for b=1:binNum
        AUC_mean = cellfun(@(x) mean(x{b,1}), AUC_resp,'UniformOutput', false);
        AUC_upCI = cellfun(@(x) x{b,1}(ceil((1-alpha_Bonferroni/2)*nBoot_AUC)), AUC_resp,'UniformOutput', false);
        AUC_lowCI = cellfun(@(x) x{b,1}(ceil((alpha_Bonferroni/2)*nBoot_AUC)), AUC_resp,'UniformOutput', false);
        isSignificant = cell2mat(cellfun(@(x,y) (0.5-x)*(0.5-y)>0, AUC_upCI, AUC_lowCI,'UniformOutput', false));
        isConPref = cell2mat(AUC_mean) > 0.5;
        isIpsiPref = cell2mat(AUC_mean) < 0.5;
        sig_percent_con(b) = round(sum(isSignificant & isConPref)/length(isSignificant)*100,1);
        sig_percent_ipsi(b) = round(sum(isSignificant & isIpsiPref)/length(isSignificant)*100,1);
        con_sig_ratio(b) = round(sig_percent_con/(sig_percent_con + sig_percent_ipsi),2);
        sig_percent(b) = round(sum(isSignificant)/length(isSignificant)*100,1);
    end
    plot(time*1000, sig_percent_con/100, 'Color', tt_colors{1}, 'LineStyle', geno_lines{g}, 'LineWidth', 1); hold on;
    plot(time*1000, sig_percent_ipsi/100, 'Color', tt_colors{2}, 'LineStyle', geno_lines{g}, 'LineWidth', 1);   
    set(gca, 'box','off','TickDir','out', 'LineWidth',1, 'FontSize', 8, 'FontName', 'Arial')
    xlim([-10 100]);
    ylim([-0.02 0.4]);
    xlabel('Time from stimulus onset (ms)', 'FontSize', 8, 'FontName', 'Arial')
    ylabel('Proportion of units', 'FontSize', 8, 'FontName', 'Arial')
    xticks(-50:50:150)
%     text(-0.45, 60-15*g, [genotype ' n= ' num2str(N)])
%     title(recSiteDir, 'FontSize', 6, 'FontName', 'Arial')
end
% legend('WT contra', 'WT ipsi', 'KO contra', 'KO ipsi','Box', 'off' , 'FontSize', 6, 'FontName', 'Arial')
% Save fig
FigPath = fullfile(saveFigPath,...
    ['PercentageSigUnit_' recSiteDir '_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin']);
exportgraphics(gg, [FigPath '.pdf'],'Resolution', 300);
% Save fig
% FigPath = fullfile(mainDir, recSiteDir,...
% ['PercentageSigUnit_' recSiteDir '_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin.pdf']);
% print(FigPath,'-dpdf','-painters','-loose');

%% Percentage of significant units over time (5ms bin) bootstrap 1000 times
close all
% Setting
% mainDir = 'E:\Robo3'; % path to the Robo3 project folder
recSiteDir = 'S1';
genotypes = {'WT' 'KO'};
nboot = 1000;
bin = 0.005; % sec
timeWindow = [-0.05, 0.15]; % sec
binNum = (timeWindow(2) - timeWindow(1))/bin;
alpha = 0.05;
nBoot_AUC = 1000;
% Figure setting
tt_colors = {'r' 'b'}; % controlateral in red, ipsilateral in blue 

shadeColor{2} = {[255 0 0]/255; [0 0 255]/255};
shadeColor{1} = {[255 0 0]/255; [0 0 255]/255};
diffColor = [0.5 0 0.5];
geno_lines = {'-' '--'}; % WT: -, KO: --
time = timeWindow(1)+bin:bin:timeWindow(2);
% Load data
load(fullfile(mainDir, recSiteDir, 'ROC', '5msBin', 'Unit_AUC_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin.mat'))
sig_percent_con_boot = cell(1,2);
sig_percent_ipsi_boot = cell(1,2);
sig_percent_con = cell(1,2);
sig_percent_ipsi = cell(1,2);
gg = figure('Units', 'inches', 'Position',[1 1 4 3.2]);

for g = 1:size(genotypes,2)
    genotype = genotypes{g};
    genotypeColors = shadeColor{g};
    isGenotype = cell2mat(cellfun(@(x) strcmp(x,genotype), AUC_table{:,2},'UniformOutput', false));
    AUC_genotype = AUC_table{isGenotype, 4};
    AUC_sessions = [];
    % concatenation across sessions
    for session=1:size(AUC_genotype,1)
        AUC_session = AUC_genotype{session};
        AUC_sessions = [AUC_sessions AUC_session];
    end
    isResp = cell2mat(cellfun(@(x) iscell(x), AUC_sessions,'UniformOutput', false)); % Find responsive units
    AUC_resp = AUC_sessions(isResp);
    N = size(AUC_resp,2);
    alpha_Bonferroni = alpha/N; % Bonferroni correction
 
    diff_percent = [];
    for b=1:binNum
        AUC_mean = cellfun(@(x) mean(x{b,1}), AUC_resp,'UniformOutput', false);
        AUC_upCI = cellfun(@(x) x{b,1}(ceil((1-alpha_Bonferroni/2)*nBoot_AUC)), AUC_resp,'UniformOutput', false);
        AUC_lowCI = cellfun(@(x) x{b,1}(ceil((alpha_Bonferroni/2)*nBoot_AUC)), AUC_resp,'UniformOutput', false);
        isSignificant = cell2mat(cellfun(@(x,y) (0.5-x)*(0.5-y)>0, AUC_upCI, AUC_lowCI,'UniformOutput', false));
        isConPref = cell2mat(AUC_mean) > 0.5;
        isIpsiPref = cell2mat(AUC_mean) < 0.5;
        sig_percent_con{g}(b) = round(sum(isSignificant & isConPref)/length(isSignificant)*100,1);
        sig_percent_ipsi{g}(b) = round(sum(isSignificant & isIpsiPref)/length(isSignificant)*100,1);
%         diff_percent(g,b) = sig_percent_con(b) - sig_percent_ipsi(b);
    end
    subplot(2,2,(g-1)*2 + 1);
%     statData.contraProp = sig_percent_con/100;
%     statData.ipsiProp = sig_percent_ipsi/100;
    plot(time*1000, sig_percent_con{g}/100, 'Color', genotypeColors{1},  'LineWidth', 1); hold on;
    plot(time*1000, sig_percent_ipsi{g}/100, 'Color', genotypeColors{2},  'LineWidth', 1);  

  

    
    contraBoot = nan(nboot,binNum);
    ipsiBoot = nan(nboot,binNum);
    diff_percent_boot = nan(nboot,binNum);
    parfor boot = 1:nboot
        bootAUC_resp = datasample(AUC_resp, N, 'Replace', true);
        for b=1:binNum
            AUC_mean = cellfun(@(x) mean(x{b,1}), bootAUC_resp,'UniformOutput', false);
            AUC_upCI = cellfun(@(x) x{b,1}(ceil((1-alpha_Bonferroni/2)*nBoot_AUC)), bootAUC_resp,'UniformOutput', false);
            AUC_lowCI = cellfun(@(x) x{b,1}(ceil((alpha_Bonferroni/2)*nBoot_AUC)), bootAUC_resp,'UniformOutput', false);
            isSignificant = cell2mat(cellfun(@(x,y) (0.5-x)*(0.5-y)>0, AUC_upCI, AUC_lowCI,'UniformOutput', false));
            isConPref = cell2mat(AUC_mean) > 0.5;
            isIpsiPref = cell2mat(AUC_mean) < 0.5;
            contraBoot(boot,b) = round(sum(isSignificant & isConPref)/length(isSignificant)*100,1);
            ipsiBoot(boot,b) = round(sum(isSignificant & isIpsiPref)/length(isSignificant)*100,1);
%             diff_percent(boot,b) = sig_percent_con(boot,b) - sig_percent_ipsi(boot,b);
           
        end
    end
    sig_percent_con_boot{g} = contraBoot;
    sig_percent_ipsi_boot{g} = ipsiBoot;

    
    ciContra(1,:) = prctile(sig_percent_con_boot{g}, 2.5, 1);  % 2.5th percentile (lower bound)
    ciContra(2,:) = prctile(sig_percent_con_boot{g}, 97.5, 1); % 97.5th percentile (upper bound)
    ciIpsi(1,:) = prctile(sig_percent_ipsi_boot{g}, 2.5, 1);  % 2.5th percentile (lower bound)
    ciIpsi(2,:) = prctile(sig_percent_ipsi_boot{g}, 97.5, 1); % 97.5th percentile (upper bound)
    MPlot.ErrorShade(time*1000, mean(sig_percent_con_boot{g},1)/100, ciContra(2,:)/100, ...
                    ciContra(1,:)/100, 'color', genotypeColors{1}, 'Alpha', 0.3, 'IsRelative', false); 
    MPlot.ErrorShade(time*1000, mean(sig_percent_ipsi_boot{g},1)/100, ciIpsi(2,:)/100, ...
                    ciIpsi(1,:)/100, 'color',genotypeColors{2}, 'Alpha', 0.3, 'IsRelative', false); 
    set(gca, 'box','off','TickDir','out', 'LineWidth',1, 'FontSize', 8, 'FontName', 'Arial')
    
    xlim([-10 100]);
    ylim([-0.02 0.4]);
    xlabel('Time from stimulus onset (ms)', 'FontSize', 8, 'FontName', 'Arial')
    ylabel('Fraction of units', 'FontSize', 8, 'FontName', 'Arial')
    xticks(-50:50:150);

   
%     text(-0.45, 60-15*g, [genotype ' n= ' num2str(N)])
%     title(recSiteDir, 'FontSize', 6, 'FontName', 'Arial')
end



% get delta WT - KO for contra
diff_percent_contra = sig_percent_con{1}- sig_percent_con{2}; % WT - KO
diff_percent_contra_boot = sig_percent_con_boot{1} - sig_percent_con_boot{2};
ciDiffContra(1,:) = prctile(diff_percent_contra_boot, 2.5, 1);  % 2.5th percentile (lower bound)
ciDiffContra(2,:) = prctile(diff_percent_contra_boot, 97.5, 1); % 97.5th percentile (upper bound)  
subplot(2,2,2); hold on;
plot(time*1000, diff_percent_contra/100, 'Color', genotypeColors{1},  'LineWidth', 1);  
MPlot.ErrorShade(time*1000, mean(diff_percent_contra_boot,1)/100, ciDiffContra(2,:)/100, ...
                ciDiffContra(1,:)/100, 'color', genotypeColors{1}, 'Alpha', 0.3, 'IsRelative', false); 
set(gca, 'box','off','TickDir','out', 'LineWidth',1, 'FontSize', 8, 'FontName', 'Arial')

% get delta WT - KO for ipsi
diff_percent_ipsi = sig_percent_ipsi{1}- sig_percent_ipsi{2}; % WT - KO
diff_percent_ipsi_boot = sig_percent_ipsi_boot{1} - sig_percent_ipsi_boot{2};
ciDiffIpsi(1,:) = prctile(diff_percent_ipsi_boot, 2.5, 1);  % 2.5th percentile (lower bound)
ciDiffIpsi(2,:) = prctile(diff_percent_ipsi_boot, 97.5, 1); % 97.5th percentile (upper bound) 
subplot(2,2,2); hold on;
plot(time*1000, diff_percent_ipsi/100, 'Color', genotypeColors{2},  'LineWidth', 1);  
MPlot.ErrorShade(time*1000, mean(diff_percent_ipsi_boot,1)/100, ciDiffIpsi(2,:)/100, ...
                ciDiffIpsi(1,:)/100, 'color', genotypeColors{2}, 'Alpha', 0.3, 'IsRelative', false); 
yline(0, '--', 'Color', 'k')
set(gca, 'box','off','TickDir','out', 'LineWidth',1, 'FontSize', 8, 'FontName', 'Arial')

xlim([-10 100]);
ylim([-0.3 0.3]);
yticks(-0.3:0.15:0.3)
xlabel('Time from stimulus onset (ms)', 'FontSize', 8, 'FontName', 'Arial')
ylabel('Fraction of units', 'FontSize', 8, 'FontName', 'Arial')
xticks(-50:50:150)
% legend('WT contra', 'WT ipsi', 'KO contra', 'KO ipsi','Box', 'off' , 'FontSize', 6, 'FontName', 'Arial')
% Save fig
FigPath = fullfile(saveFigPath,...
    ['PercentageSigUnit_' recSiteDir '_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin']);
exportgraphics(gg, [FigPath 'bootstrapped.pdf'],'Resolution', 300);

%% Onset of significant side selectivity (KO vs WT) do not use
% Significant units: 3 consecutive significant bins (5ms bin)
clear all;
% Setting
mainDir = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\SeData\EphysPassiveStimSEs\SingleUnitAnalysis'; % path to the Robo3 project folder
recSiteDir = 'S1';
genotypes = {'WT' 'KO'};
bin = 0.005; % sec
timeWindow = [-0.05, 0.15]; % sec
binNum = (timeWindow(2) - timeWindow(1))/bin;
alpha = 0.05;
nBoot_AUC = 1000;
% For analysis of significant side selectivity
analysisWindow = [0 0.15];
binStart =round((analysisWindow(1)-timeWindow(1))/bin)+1;
binEnd = round((analysisWindow(2)-timeWindow(1))/bin);
significant_bins = 3;

% Figure setting
tt_colors = {'r' 'b'}; % controlateral in red, ipsilateral in blue 
geno_lines = {'-' '--'}; % WT: -, KO: --
time = timeWindow(1)+bin:bin:timeWindow(2);
% Load data
load(fullfile(mainDir, recSiteDir, 'ROC', '5msBin', 'Unit_AUC_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin.mat'))

figure('Position',[0 0 800 300])
for g = 1:size(genotypes,2)
    genotype = genotypes{g};
    isGenotype = cell2mat(cellfun(@(x) strcmp(x,genotype), AUC_table{:,2},'UniformOutput', false));
    AUC_genotype = AUC_table{isGenotype, 4};
    AUC_sessions = [];
    % concatenation across sessions
    for session=1:size(AUC_genotype,1)
        AUC_session = AUC_genotype{session};
        AUC_sessions = [AUC_sessions AUC_session];
    end
    isResp = cell2mat(cellfun(@(x) iscell(x), AUC_sessions,'UniformOutput', false)); % Find responsive units
    AUC_resp = AUC_sessions(isResp);
    N = size(AUC_resp,2);
    alpha_Bonferroni = alpha/N; % Bonferroni correction
    
    for unit=1:N
        AUC_unit = AUC_resp{unit};
        for b= binStart:binEnd
            AUC_upCI = AUC_unit{b,1}(ceil((1-alpha_Bonferroni/2)*nBoot_AUC));
            AUC_lowCI = AUC_unit{b,1}(ceil((alpha_Bonferroni/2)*nBoot_AUC));
            isSignificant_bin(b-binStart+1) = (0.5-AUC_upCI)*(0.5-AUC_lowCI)>0;
        end
        % If three consecutive time bins are significant, this unit show significant selectivity.
        isSignificant_bin_matrix = [isSignificant_bin; [isSignificant_bin(2:end), 0]; [isSignificant_bin(3:end), 0, 0]];
        isSignificant_three_bins = ismember(sum(isSignificant_bin_matrix,1),significant_bins);
        sig_onset_bin = find(isSignificant_three_bins,1);
        isSignificant(unit) = sum(isSignificant_three_bins)>0 ;
        % Find onset of significant selectivity
        if ~isempty(sig_onset_bin)
            sig_onset(unit) = (sig_onset_bin-1)*bin*1000; % in ms
            new_sig_onset_bin = sig_onset_bin+binStart-1;
            isConPref(unit) = mean(cell2mat(AUC_unit(new_sig_onset_bin:new_sig_onset_bin+2,1)),'all') > 0.5;
            isIpsiPref(unit) = mean(cell2mat(AUC_unit(new_sig_onset_bin:new_sig_onset_bin+2,1)),'all') < 0.5;
%             isNoPref(unit) =  mean(cell2mat(AUC_unit(sig_onset_bin:sig_onset_bin+2,1)),'all') == 0.5;
        else
            sig_onset(unit) = NaN;
            isConPref(unit) = 0;
            isIpsiPref(unit) = 0;
        end
    end
    isConPref = logical(isConPref);
    isIpsiPref = logical(isIpsiPref);
    
    subplot(1,2,1)  % WT vs KO  
    h1(g) = cdfplot(sig_onset); hold on;
    set(h1(g), 'Color', 'k', 'LineStyle', geno_lines{g}, 'Linewidth', 1);
    grid off
    set(gca, 'box','off','TickDir','out')
    xlim(analysisWindow*1000);
    ylim([0 1]);
    xlabel('Onset of significant side selectivity (ms)')
    ylabel('Fraction of neurons')
    text(100, 0.3-0.1*g, [genotype ' ' num2str(sum(isSignificant)) '/' num2str(N)])
    title(recSiteDir)
    
    subplot(1,2,2) % con vs ipsi for WT and KO
    h2(g,1) = cdfplot(sig_onset(isConPref)); hold on;
    if sum(isIpsiPref) == 0
        h2(g,2) = yline(0); hold on;
    else
        h2(g,2) = cdfplot(sig_onset(isIpsiPref)); hold on;
    end
    set(h2(g,1), 'Color', tt_colors{1}, 'LineStyle', geno_lines{g}, 'Linewidth', 0.75);
    set(h2(g,2), 'Color', tt_colors{2}, 'LineStyle', geno_lines{g}, 'Linewidth', 0.75);
    grid off
    set(gca, 'box','off','TickDir','out')
    xlim(analysisWindow*1000);
    ylim([0 1]);
    xlabel('Onset of significant side selectivity (ms)')
    ylabel('Fraction of neurons')
    title(recSiteDir)
    
    legends{(g-1)*2+1} = [genotypes{g} ' con ' num2str(sum(isSignificant & isConPref)) '/' num2str(sum(isSignificant))];
    legends{(g-1)*2+2} = [genotypes{g} ' ipsi ' num2str(sum(isSignificant & isIpsiPref)) '/' num2str(sum(isSignificant))];
end
legend(legends, 'Location', 'southeast', 'Box', 'off')

% % Save fig
% FigPath = fullfile(mainDir, recSiteDir,...
% ['SigOnset_' recSiteDir '_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin.pdf']);
% print(FigPath,'-dpdf','-painters','-loose');


%% Onset of significant side selectivity (KO vs WT) only plot stimulus side separated
% Significant units: 3 consecutive significant bins (5ms bin)
clear all
close all
% Setting
mainDir = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\SeData\EphysPassiveStimSEs\SingleUnitAnalysis'; % path to the Robo3 project folder
recSiteDir = 'S1';
analysisDir = 'ROC';
saveFigPath = 'E:\oconnorlab Dropbox\oconnorlab Team Folder\manuscripts\bodyside_S1\Fig4';
tt_colors = {'r' 'b'}; % controlateral, ipsilateral
genotypes = {'WT' 'KO'};
geno_lines = {'-' '..'};
alpha = 0.05;

recSiteDir = 'S1';
genotypes = {'WT' 'KO'};
bin = 0.005; % sec
timeWindow = [-0.05, 0.15]; % sec
binNum = (timeWindow(2) - timeWindow(1))/bin;
alpha = 0.05;
nBoot_AUC = 1000;
% For analysis of significant side selectivity
analysisWindow = [0 0.15];
binStart =round((analysisWindow(1)-timeWindow(1))/bin)+1;
binEnd = round((analysisWindow(2)-timeWindow(1))/bin);
significant_bins = 3;

% Figure setting
tt_colors = {'r' 'b'}; % controlateral in red, ipsilateral in blue 
geno_lines = {'-' '--'}; % WT: -, KO: --
time = timeWindow(1)+bin:bin:timeWindow(2);
% Load data
load(fullfile(mainDir, recSiteDir, 'ROC', '5msBin', 'Unit_AUC_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin.mat'))

gg = figure('Units' , 'inches', 'Position',[1 1 2.25 1.48]);
for g = 1:size(genotypes,2)
    genotype = genotypes{g};
    isGenotype = cell2mat(cellfun(@(x) strcmp(x,genotype), AUC_table{:,2},'UniformOutput', false));
    AUC_genotype = AUC_table{isGenotype, 4};
    AUC_sessions = [];
    % concatenation across sessions
    for session=1:size(AUC_genotype,1)
        AUC_session = AUC_genotype{session};
        AUC_sessions = [AUC_sessions AUC_session];
    end
    isResp = cell2mat(cellfun(@(x) iscell(x), AUC_sessions,'UniformOutput', false)); % Find responsive units
    AUC_resp = AUC_sessions(isResp);
    N = size(AUC_resp,2);
    alpha_Bonferroni = alpha/N; % Bonferroni correction
    
    for unit=1:N
        AUC_unit = AUC_resp{unit};
        for b= binStart:binEnd
            AUC_upCI = AUC_unit{b,1}(ceil((1-alpha_Bonferroni/2)*nBoot_AUC));
            AUC_lowCI = AUC_unit{b,1}(ceil((alpha_Bonferroni/2)*nBoot_AUC));
            isSignificant_bin(b-binStart+1) = (0.5-AUC_upCI)*(0.5-AUC_lowCI)>0;
        end
        % If three consecutive time bins are significant, this unit show significant selectivity.
        isSignificant_bin_matrix = [isSignificant_bin; [isSignificant_bin(2:end), 0]; [isSignificant_bin(3:end), 0, 0]];
        isSignificant_three_bins = ismember(sum(isSignificant_bin_matrix,1),significant_bins);
        sig_onset_bin = find(isSignificant_three_bins,1);
        isSignificant(unit) = sum(isSignificant_three_bins)>0 ;
        % Find onset of significant selectivity
        if ~isempty(sig_onset_bin)
            sig_onset(unit) = (sig_onset_bin-1)*bin*1000; % in ms
            new_sig_onset_bin = sig_onset_bin+binStart-1;
            isConPref(unit) = mean(cell2mat(AUC_unit(new_sig_onset_bin:new_sig_onset_bin+2,1)),'all') > 0.5;
            isIpsiPref(unit) = mean(cell2mat(AUC_unit(new_sig_onset_bin:new_sig_onset_bin+2,1)),'all') < 0.5;
%             isNoPref(unit) =  mean(cell2mat(AUC_unit(sig_onset_bin:sig_onset_bin+2,1)),'all') == 0.5;
        else
            sig_onset(unit) = NaN;
            isConPref(unit) = 0;
            isIpsiPref(unit) = 0;
        end
    end
    isConPref = logical(isConPref);
    isIpsiPref = logical(isIpsiPref);
    
   
    statData.isConPref{g} = sig_onset(isConPref);
    statData.isIpsiPref{g} = sig_onset(isIpsiPref);
    
    h2(g,1) = cdfplot(sig_onset(isConPref)); hold on;
    if sum(isIpsiPref) == 0
        h2(g,2) = yline(0); hold on;
    else
        h2(g,2) = cdfplot(sig_onset(isIpsiPref)); hold on;
    end
    if g == 1
        linewidth = 0.5;
    else 
        linewidth = 1;
    end
    set(h2(g,1), 'Color', tt_colors{1}, 'LineStyle', geno_lines{g}, 'Linewidth', linewidth);
    set(h2(g,2), 'Color', tt_colors{2}, 'LineStyle', geno_lines{g}, 'Linewidth', linewidth);
    grid off
    set(gca, 'box','off','TickDir','out', 'Linewidth', 1, 'FontName', 'Arial', 'FontSize', 8)
    xlim([0 40]);
    ylim([-0.05 1]);
    yticks(0:0.2:1)
    xlabel('Onset of significant side selectivity (ms)', 'FontName', 'Arial', 'FontSize', 8)
    ylabel('Proportion of units', 'FontName', 'Arial', 'FontSize', 8)
%     title(recSiteDir)
    title('')
    
    legends{(g-1)*2+1} = [genotypes{g} ' con ' num2str(sum(isSignificant & isConPref)) '/' num2str(sum(isSignificant))];
    legends{(g-1)*2+2} = [genotypes{g} ' ipsi ' num2str(sum(isSignificant & isIpsiPref)) '/' num2str(sum(isSignificant))];
end
% legend(legends, 'Location', 'southeast', 'Box', 'off')



% add stats
fid = fopen(fullfile(saveFigPath, 'StatisticsSelectivityOnset.txt'), 'w');
% normality test
WTc = statData.isConPref{1};
WTi = statData.isIpsiPref{1};
KOc = statData.isConPref{2};
KOi = statData.isIpsiPref{2};
[H, pvalWTc] = adtest(WTc); % S1 contra for WT
% [H, pvalWTi] = adtest(WTi); % M1 contra for WT
[H, pvalKOc] = adtest(KOc); % S1 contra for WT
[H, pvalKOi] = adtest(KOi); % M1 contra for WT




% compare contra WT vs KO
[H, pval] = kstest2(WTc, KOc, 'tail', 'unequal')
fprintf(fid, ['Contra two-sided ks test WT != KO pval: ' num2str(pval)  '\n']);

% compare KO contra vs ipsi 
[H, pval] = kstest2(KOc, KOi, 'tail', 'unequaledit(')
fprintf(fid, ['KO two-sided ks test contra !=< ipsi pval: ' num2str(pval)  '\n']);

% compare WT contra vs KO ipsi 
[H, pval] = kstest2(WTc, KOi, 'tail', 'unequal')
fprintf(fid, ['two-sided ks test WT contra != KO ipsi pval: ' num2str(pval)  '\n']);
fclose(fid);



% Save fig
FigPath = fullfile(saveFigPath,...
    ['SigOnset_' recSiteDir '_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin']);
exportgraphics(gg, [FigPath '.pdf'],'Resolution', 300);

% % Save fig
% FigPath = fullfile(mainDir, recSiteDir,...
% ['SigOnset_' recSiteDir '_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin.pdf']);
% print(FigPath,'-dpdf','-painters','-loose');

%% Onset of significant side selectivity (S1 vs Motor)
% Significant units: 3 consecutive significant bins (5ms bin)

% Setting
mainDir = 'E:\Robo3'; % path to the Robo3 project folder
recSites = {'S1' 'Motor'};
genotypes = {'WT' 'KO'};
bin = 0.005; % sec
timeWindow = [-0.05, 0.15]; % sec
binNum = (timeWindow(2) - timeWindow(1))/bin;
alpha = 0.05;
nBoot_AUC = 1000;
% For analysis of significant side selectivity
analysisWindow = [0 0.15];
binStart =round((analysisWindow(1)-timeWindow(1))/bin)+1;
binEnd = round((analysisWindow(2)-timeWindow(1))/bin);
significant_bins = 3;

% Figure setting
tt_colors = {'r' 'b'}; % controlateral in red, ipsilateral in blue 
recSite_lines = {'-' '--'}; % S1: -, Motor: --
time = timeWindow(1)+bin:bin:timeWindow(2);

figure('Position',[0 0 800 600])
for i = 1:size(recSites,2)
    % load data
    load(fullfile(mainDir,recSites{i},'ROC', '5msBin', 'Unit_AUC_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin.mat'))
    for g = 1:size(genotypes,2)
        genotype = genotypes{g};
        isGenotype = cell2mat(cellfun(@(x) strcmp(x,genotype), AUC_table{:,2},'UniformOutput', false));
        AUC_genotype = AUC_table{isGenotype, 4};
        AUC_sessions = [];
        % concatenation across sessions
        for session=1:size(AUC_genotype,1)
            AUC_session = AUC_genotype{session};
            AUC_sessions = [AUC_sessions AUC_session];
        end
        isResp = cell2mat(cellfun(@(x) iscell(x), AUC_sessions,'UniformOutput', false)); % Find responsive units
        AUC_resp = AUC_sessions(isResp);
        N = size(AUC_resp,2);
        alpha_Bonferroni = alpha/N; % Bonferroni correction

        for unit=1:N
            AUC_unit = AUC_resp{unit};
            for b= binStart:binEnd
                AUC_upCI = AUC_unit{b,1}(ceil((1-alpha_Bonferroni/2)*nBoot_AUC));
                AUC_lowCI = AUC_unit{b,1}(ceil((alpha_Bonferroni/2)*nBoot_AUC));
                isSignificant_bin(b-binStart+1) = (0.5-AUC_upCI)*(0.5-AUC_lowCI)>0;
            end
            % If three consecutive time bins are significant, this unit show significant selectivity.
            isSignificant_bin_matrix = [isSignificant_bin; [isSignificant_bin(2:end), 0]; [isSignificant_bin(3:end), 0, 0]];
            isSignificant_three_bins = ismember(sum(isSignificant_bin_matrix,1),significant_bins);
            sig_onset_bin = find(isSignificant_three_bins,1);
            isSignificant(unit) = sum(isSignificant_three_bins)>0 ;
            % Find onset of significant selectivity
            if ~isempty(sig_onset_bin)
                sig_onset(unit) = (sig_onset_bin-1)*bin*1000; % in ms
                new_sig_onset_bin = sig_onset_bin+binStart-1;
                isConPref(unit) = mean(cell2mat(AUC_unit(new_sig_onset_bin:new_sig_onset_bin+2,1)),'all') > 0.5;
                isIpsiPref(unit) = mean(cell2mat(AUC_unit(new_sig_onset_bin:new_sig_onset_bin+2,1)),'all') < 0.5;
    %             isNoPref(unit) =  mean(cell2mat(AUC_unit(sig_onset_bin:sig_onset_bin+2,1)),'all') == 0.5;
            else
                sig_onset(unit) = NaN;
                isConPref(unit) = 0;
                isIpsiPref(unit) = 0;
            end
        end
        isConPref = logical(isConPref);
        isIpsiPref = logical(isIpsiPref);

        subplot(2,2,g) 
        h1(g) = cdfplot(sig_onset); hold on;
        set(h1(g), 'Color', 'k', 'LineStyle', recSite_lines{i});
        grid off
        set(gca, 'box','off','TickDir','out')
        xlim(analysisWindow*1000);
        ylim([0 1]);
        xlabel('Onset of significant side selectivity (ms)')
        ylabel('Fraction of neurons')
        text(100, 0.3-0.1*i, [recSites{i} ' ' num2str(sum(isSignificant)) '/' num2str(N)])
        title(genotype)
        if i == 2
            legend(recSites, 'Location', 'northeast', 'Box', 'off')
        end

        subplot(2,2,2+g) % con vs ipsi 
        h2(g,1) = cdfplot(sig_onset(isConPref)); hold on;
        if sum(isIpsiPref) == 0
            h2(g,2) = yline(0); hold on;
        else
            h2(g,2) = cdfplot(sig_onset(isIpsiPref)); hold on;
        end
        set(h2(g,1), 'Color', tt_colors{1}, 'LineStyle', recSite_lines{i});
        set(h2(g,2), 'Color', tt_colors{2}, 'LineStyle', recSite_lines{i});
        grid off
        set(gca, 'box','off','TickDir','out')
        xlim(analysisWindow*1000);
        ylim([0 1]);
        xlabel('Onset of significant side selectivity (ms)')
        ylabel('Fraction of neurons')
        title(genotype)
        
        text(100, 0.5-0.1*(2*i-1), [recSites{i} ' con ' num2str(sum(isSignificant & isConPref)) '/' num2str(sum(isSignificant))])
        text(100, 0.4-0.1*(2*i-1), [recSites{i} ' ipsi ' num2str(sum(isSignificant & isIpsiPref)) '/' num2str(sum(isSignificant))])
        
        if i == 2
            legend({'S1 con' 'S1 ipsi' 'Motor con' 'Motor ipsi'}, 'Location', 'northeast', 'Box', 'off')
        end
        clearvars isSignificant_bin isSignificant sig_onset isConPref isIpsiPref
    end
    clearvars AUC_table
end
% Save fig
% FigPath = fullfile(mainDir,...
% 'ROC_SigOnset_20Hz_5msBin_-50to150ms_1000nBoot_150pvalueMin');
% print(FigPath,'-dpdf','-painters','-loose');