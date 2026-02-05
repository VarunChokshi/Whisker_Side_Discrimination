%% Figues combined
clear all
close all
global windowSize statAlpha meanFR seFR pValue unitNums;
[readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\IntanSEs', 'Select source SEs');
sigma = 0.0025;
FRlims = [-0.5 0.5];
trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
trials{2} = {'Stim_Som_Left', 'Stim_Som_Right', 'Stim_Som_Left_Opto', 'Stim_Som_Right_Opto'}; 

for sessNum = 1:size(readPaths,1)
    clearvars -except sessNum readPaths seDir seNames sigma trials;
    seParts = strsplit(seNames{sessNum}, ' ');
    rootParts = strsplit(seDir, '\');
    rootPath = fullfile(rootParts{1:end-2});
    savePath = fullfile(rootPath,'Figures\Cohort2\CGs', seNames{sessNum});
    
    savePath1 = fullfile(rootPath,'Figures\Cohort2\correctvsmissed', seNames{sessNum});
    savePath2 = fullfile(rootPath,'Figures\Cohort2\correctvsincorrect', seNames{sessNum});
    savePath3 = fullfile(rootPath,'Figures\Cohort2\leftvsright', seNames{sessNum});
    savePath4 = fullfile(rootPath,'Figures\Cohort2\waveforms', seNames{sessNum});
    savePath5 = fullfile(rootPath,'Figures\Cohort2\amplitudes', seNames{sessNum});
    savePath6 = fullfile(rootPath,'Figures\Cohort2\Opto', seNames{sessNum});
    savePathFinal = fullfile(rootPath,'Figures\Cohort2\combined', seNames{sessNum});
    
    if ~exist('savePathFinal', 'Dir')
        mkdir(savePathFinal)
    end
    
    if ~exist('savePath', 'Dir')
        mkdir(savePath)
    end

    if ~exist('savePath1', 'Dir')
        mkdir(savePath1)
    end

    if ~exist('savePath2', 'Dir')
        mkdir(savePath2)
    end

    if ~exist('savePath3', 'Dir')
        mkdir(savePath3)
    end

    if ~exist('savePath4', 'Dir')
        mkdir(savePath4)
    end
    if ~exist('savePath5', 'Dir')
        mkdir(savePath5)
    end

    if ~exist('savePath6', 'Dir')
        mkdir(savePath6)
    end


    load(readPaths{sessNum});
    fprintf('%s\n\n', readPaths{sessNum});
    tRef = se.GetReferenceTime();
    check = diff(tRef);

    if any(check<0)
        disp('tRefs are not monotonically increasing');
    end

    trialMap = se.userData.sessionInfo.trialMap;

    if ~isempty(trialMap{1})
        trialSplit = strsplit(trialMap{1},':');
        if any(strcmp(trialSplit{2}(1:end-1), 'end'))
            trialInd = [str2double(trialSplit{1}) : se.numEpochs];
        else
            trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}(1:end-1))];
        end
        allTrials = 1:se.numEpochs;
        removeTrials = find(~ismember(allTrials, trialInd));
        se = BS.Preprocess.removeTrials(removeTrials,se);
    end
    
    
    behavData = se.GetTable('behavValue');
    stimRight = behavData.rightStimType{end};
    stimLeft= behavData.leftStimType{end};
    
    
    responses = behavData.response;
    abortTrials = find(cell2mat(responses) == 3);        
    se = BS.Preprocess.removeTrials(abortTrials,se);
    behavData = se.GetTable('behavValue');
    
    

    responses = behavData.result;
    missTrials = find(isnan(responses));
    keepTrials = find(~isnan(responses));
    seMiss =  BS.Preprocess.removeTrials(keepTrials,se);
    se = BS.Preprocess.removeTrials(missTrials,se);
    
    behavData = se.GetTable('behavValue');
    missData = seMiss.GetTable('behavValue');
   
    
    trialTypes = unique(behavData.trialType);

    
    if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
        trialTypes = trials{2};
        stims = {'Left Stim', 'Right Stim', 'Left Stim + Opto', 'Right Stim + Opto'};
    else
        trialTypes = trials{1};
         stims = {'Left Stim', 'Right Stim'};
    end
    
    recSite = se.userData.sessionInfo.recSite{1};
    behavTime = se.GetTable('behavTime');

    for trialType = 1:numel(trialTypes)
        trialTypeIndCorrect = find(strcmp(trialTypes{trialType}, behavData.trialType) & behavData.result);
        
        trialTypeIndInCorrect = find(strcmp(trialTypes{trialType}, behavData.trialType) & ~(behavData.result));
        missInd = find(strcmp(trialTypes{trialType}, missData.trialType));
        
        seCorrect = BS.Preprocess.keepTrials(trialTypeIndCorrect, se);
        seMissTemp = BS.Preprocess.keepTrials(missInd, seMiss);
        seIncorrect = BS.Preprocess.keepTrials(trialTypeIndInCorrect, se);
       

        if any(ismember(trialTypes{trialType}, 'L'))
            stimOnset{trialType} = max(cell2mat(behavTime.leftOnset));
            stimOffset{trialType} = max(cell2mat(behavTime.leftOffset));
        else
            stimOnset{trialType} = max(cell2mat(behavTime.rightOnset));
            stimOffset{trialType} = max(cell2mat(behavTime.rightOffset));
        end
        seS(1:3, trialType) = {seCorrect, seMissTemp, seIncorrect};
        

    end   
    
   spikeTimes = se.GetTable('spikeTime');
    
    %get datPath
    %get Kilosost path
    ksDir = se.userData.sessionInfo.ksDir;                                               
 %   these include dat_path, dtype, n_channels_dat, sample_rate ...
    fid = fopen(fullfile(ksDir, 'params.py'));
    while ~feof(fid)
        try
            l = fgetl(fid);
            eval([l ';']);
        catch
            %warning('''%s'' cannot be evaluated.', l);
        end
    end
    fclose(fid);
%     datPath =fullfile(ksDir,"amplifier.dat");
    datPath = dat_path;
    mdat = memmapfile(datPath, 'Format', dtype);
    nSample = numel(mdat.Data) / n_channels_dat;
    mdat = memmapfile(datPath, 'Format', {dtype, [n_channels_dat nSample], 'v'});
    %get spike times for dupSE for each unit and then get waveform +-1.5s.   
    voltage = mdat.Data.v;
    sample_rate = 30000;
       


    
    for unitNum =1:size(spikeTimes,2)
        clearvars unitSpikes unitspikes2;
        
        for sei = 1:size(seS,1)
            
            for result = 1:size(seS,2)
                seDup = seS{sei, result}.Duplicate();
                
                spikeTimes = seDup.GetTable('spikeTime');
                ind = 1:height(spikeTimes);
                bins{sei, result} = -0.5:0.0025:2.5;
                spikes = seDup.ResampleEventTimes('spikeTime', bins{sei, result}, 'Normalization', 'countdensity');
                
                spikes.(unitNum) = cellfun(@(x) MNeuro.Filter1(x, 1/0.0025, 'gaussian', sigma), spikes.(unitNum), 'UniformOutput', false);
                
                
                unitSpikes = spikes(ind,unitNum+1);           
                unitSpikes = table2cell(unitSpikes);
                for trialNum = 1:height(unitSpikes)
                    if size(unitSpikes{trialNum}, 1)>1
                        unitSpikes{trialNum} = unitSpikes{trialNum}';
                    end
                end
                unitSpikes = cell2mat(unitSpikes);
                try
                    [meanFR{sei, result} , sdFR{sei, result} , seFR{sei, result} , ciFR{sei, result} ] = MMath.MeanStats(unitSpikes, 1);    
                catch
                    maxFR{sei, result} = 0;
                    continue;
                    
                end
                maxFR{sei, result} = max(meanFR{sei, result})+1;
            end

           
            
            
        end        
       
     
        clearvars unitSpikes;
        close all
        g(1) =figure(1);clf;
        gp(1) = uipanel('Parent', g(1), 'BackgroundColor', 'white', 'Position', [0 0 1 1]);
        hold on
        color = {'g','k'};
        for result = 1:2
            h(result) = subplot(1,2,result,'Parent', gp(1));
            hold(h(result), 'on');
            for sei = 1:2
                plot(bins{sei,result}(1:size(meanFR{sei, result},2)),meanFR{sei, result}, color{sei}, 'LineWidth', 1);
                MPlot.ErrorShade(bins{1}(1:size(meanFR{sei, result},2)), meanFR{sei, result}, ...
                        ciFR{sei, result}(2,:),ciFR{sei, result}(1,:), 'color',color{sei}, 'Alpha', 0.3, 'IsRelative', false);
            end

            xlim([-0.5,0.5]);    
            
            ylim([0,max(cell2mat(maxFR), [], 'all')]); 
            yLimits = get(gca,'YLim');

            MPlot.Blocks([stimOnset{result} stimOffset{result}], [max(cell2mat(maxFR), [], 'all')*0.98,max(cell2mat(maxFR), [], 'all')], ...
                            color{2}, 'FaceAlpha', 0.6);       
            xlabel('epoch time (s)');
            ylabel('FR');  
            title(stims{result});
            box off  
            hold(h(result), 'off');
            
            
        end        
        annotation(gp(1),'textbox', [0.19, 0.79, 0.1, 0.1], 'String', ['left stim'], 'LineStyle','none');
        annotation(gp(1),'textbox', [0.635, 0.79, 0.1, 0.1], 'String', ['right stim'], 'LineStyle','none');
        annotation(gp(1),'textbox', [0.8, 0.77, 0.1, 0.1], 'String', ['recSite = ' recSite], 'LineStyle','none');
        sgtitle(gp(1),['correct vs missed UnitNum#' num2str(unitNum)]);
        hold off    
        saveas(g(1),fullfile(savePath1, ['UnitNum#' num2str(unitNum) '.png']));
    
        

        
        g(2) =figure();clf;
        gp(2) = uipanel('Parent', g(2), 'BackgroundColor', 'white', 'Position', [0 0 1 1]);
        hold on
        color = {'g','k','r'};
        for result = 1:2
            h(result) = subplot(1,2,result,'Parent', gp(2));
            hold(h(result), 'on');
            for sei = [1,3]
                
                plot(bins{sei,result}(1:size(meanFR{sei, result},2)),meanFR{sei, result}, color{sei}, 'LineWidth', 1);
                if ~isempty(meanFR{sei, result})
                    MPlot.ErrorShade(bins{sei,result}(1:size(meanFR{sei, result},2)), meanFR{sei, result}, ...
                            ciFR{sei, result}(2,:),ciFR{sei, result}(1,:), 'color',color{sei}, 'Alpha', 0.3, 'IsRelative', false);
                else
                    continue;
                end
            end

            xlim([-0.5,0.5]);    
            
            ylim([0,max(cell2mat(maxFR), [], 'all')]); 
            yLimits = get(gca,'YLim');
            MPlot.Blocks([stimOnset{result} stimOffset{result}], [max(cell2mat(maxFR), [], 'all')*0.98,max(cell2mat(maxFR), [], 'all')], ...
                            color{2}, 'FaceAlpha', 0.6);       
            xlabel('epoch time (s)');
            ylabel('FR');  
            title(stims{result});
            box off  
            hold(h(result), 'off');
            
            
        end        
        annotation(gp(2),'textbox', [0.19, 0.79, 0.1, 0.1], 'String', ['left stim'], 'LineStyle','none');
        annotation(gp(2),'textbox', [0.635, 0.79, 0.1, 0.1], 'String', ['right stim'], 'LineStyle','none');
        annotation(gp(2),'textbox', [0.8, 0.77, 0.1, 0.1], 'String', ['recSite = ' recSite], 'LineStyle','none');
       
        sgtitle(gp(2),['correct vs incorrect UnitNum#' num2str(unitNum)]);
        hold off    
        set(gcf, 'color','none');
        saveas(g(2),fullfile(savePath2, ['UnitNum#' num2str(unitNum) '.png']));
    

        resultTypes = {'correct', 'NoLick', 'Incorrect'};
           % blue is right and red is left
        
        g(3) =figure(3);clf;
        gp(3) = uipanel('Parent', g(3), 'BackgroundColor', 'white', 'Position', [0 0 1 1]);
        hold on
        color = {'r','b'};
        for sei = 1:3
            h(sei) = subplot(1,3,sei, 'Parent', gp(3));
            hold(h(sei), 'on');
            for result = 1:2
                
                plot(bins{sei}(1:size(meanFR{sei, result},2)),meanFR{sei, result}, color{result}, 'LineWidth', 1);
                if ~isempty(meanFR{sei, result})
                    MPlot.ErrorShade(bins{1}(1:size(meanFR{sei, result},2)), meanFR{sei, result}, ...
                            ciFR{sei, result}(2,:),ciFR{sei, result}(1,:), 'color',color{result}, 'Alpha', 0.3, 'IsRelative', false);
                end
            end

            xlim([-0.5,0.5]);    
            
            ylim([0,max(cell2mat(maxFR), [], 'all')]); 
            yLimits = get(gca,'YLim');
            MPlot.Blocks([stimOnset{1} stimOffset{1}], [max(cell2mat(maxFR), [], 'all')*0.98,max(cell2mat(maxFR), [], 'all')], ...
                            color{1}, 'FaceAlpha', 0.6);    
            MPlot.Blocks([stimOnset{2} stimOffset{2}], [max(cell2mat(maxFR), [], 'all')*0.95,max(cell2mat(maxFR), [], 'all')*0.97], ...
                            color{2}, 'FaceAlpha', 0.6); 
            xlabel('epoch time (s)');
            ylabel('FR');  
            title(resultTypes{sei});
            box off  
            hold(h(sei), 'off');
            
            
        end        

        annotation(gp(3),'textbox', [0.18, 0.875, 0.1, 0.1], 'String', ['left stim'], 'LineStyle','none');
        annotation(gp(3),'textbox', [0.18, 0.84, 0.1, 0.1], 'String', ['right stim'], 'LineStyle','none');
        annotation(gp(3),'textbox', [0.8, 0.77, 0.1, 0.1], 'String', ['recSite = ' recSite], 'LineStyle','none');
        annotation(gp(3),'textbox', [0.5,0.75,0.1,0.1],'String',['right vs left' newline 'UnitNum# ' num2str(unitNum)],...
            'LineStyle','none', 'FontSize', 12);
        hold off    
        saveas(g(3),fullfile(savePath3, ['UnitNum#' num2str(unitNum) '.png']));
    
        if size(seS,2) >2
            g(5) =figure(5);clf;
            gp(5) = uipanel('Parent', g(5), 'BackgroundColor', 'white', 'Position', [0 0 1 1]);
            color = {'r','b', [0.5 0.5 0.5]};
            hold on
            
            for result = 1:size(seS,2)
                for rows = 1:size(seS,1)
                    seNumEpochs(rows) = seS{rows,result}.numEpochs;
                    
                end
               seExist = find(seNumEpochs);
               seMerged{result} = Merge(seS{seExist,result});
               seDup = seMerged{result}.Duplicate();
                    
               spikeTimes2 = seDup.GetTable('spikeTime');
               ind2 = 1:height(spikeTimes2);
               bins2{result} = -0.5:0.0025:2.5;
               spikes2 = seDup.ResampleEventTimes('spikeTime', bins2{result}, 'Normalization', 'countdensity');
                
               spikes2.(unitNum) = cellfun(@(x) MNeuro.Filter1(x, 1/0.0025, 'gaussian', sigma), spikes2.(unitNum), 'UniformOutput', false);
                
                
               unitSpikes2 = spikes2(ind2,unitNum+1);           
               unitSpikes2 = table2cell(unitSpikes2);
               for trialNum = 1:height(unitSpikes2)
                   if size(unitSpikes2{trialNum}, 1)>1
                       unitSpikes2{trialNum} = unitSpikes2{trialNum}';
                   end
               end
               unitSpikes2 = cell2mat(unitSpikes2);
               try
                   [meanFR2{result} , sdFR2{result} , seFR2{result} , ciFR2{result} ] = MMath.MeanStats(unitSpikes2, 1);    
               catch
                   maxFR2{result} = 0;
                   continue;
                    
               end
               maxFR2{result} = max(meanFR2{result})+1;
        
            end
    
    
    
            for sei = 1:2
                h(sei) = subplot(1,2,sei, 'Parent', gp(5));
                hold(h(sei), 'on');
               
                plot(bins2{sei}(1:size(meanFR2{sei},2)), meanFR2{sei}, color{sei}, 'LineWidth', 1);
                plot(bins2{sei+2}(1:size(meanFR2{sei+2},2)), meanFR2{sei+2}, 'color', color{3}, 'LineWidth', 1);

                if ~isempty(meanFR2{sei})
                    MPlot.ErrorShade(bins2{1}(1:size(meanFR2{sei},2)), meanFR2{sei}, ...
                            ciFR2{sei}(2,:),ciFR2{sei}(1,:), 'color',color{sei}, 'Alpha', 0.3, 'IsRelative', false);
                end

                if ~isempty(meanFR2{sei+2})
                    MPlot.ErrorShade(bins2{1}(1:size(meanFR2{sei},2)), meanFR2{sei+2}, ...
                            ciFR2{sei+2}(2,:),ciFR2{sei+2}(1,:), 'color',color{3}, 'Alpha', 0.3, 'IsRelative', false);
                end
                xlim([-0.5,0.5]);    
                
                ylim([0,max(cell2mat(maxFR2), [], 'all')]); 
                yLimits = get(gca,'YLim');
                MPlot.Blocks([stimOnset{sei} stimOffset{sei}], [max(cell2mat(maxFR2), [], 'all')*0.98,max(cell2mat(maxFR2), [], 'all')], ...
                                color{sei}, 'FaceAlpha', 0.6);    
                MPlot.Blocks([stimOnset{sei} stimOffset{sei}], [max(cell2mat(maxFR2), [], 'all')*0.95,max(cell2mat(maxFR2), [], 'all')*0.97], ...
                                color{3}, 'FaceAlpha', 0.6); 
                xlabel('epoch time (s)');
                ylabel('FR');  
                title(stims{sei});
                box off  
                hold(h(sei), 'off');
                
                
            end        
    
            annotation(gp(5),'textbox', [0.31, 0.885, 0.1, 0.1], 'String', [stims{1}], 'LineStyle','none');
            annotation(gp(5),'textbox', [0.31, 0.825, 0.1, 0.1], 'String', [stims{1} ' + Opto'], 'LineStyle','none');
            annotation(gp(5),'textbox', [0.75, 0.885, 0.1, 0.1], 'String', [stims{2}], 'LineStyle','none');
            annotation(gp(5),'textbox', [0.75, 0.825, 0.1, 0.1], 'String', [stims{2} ' + Opto'], 'LineStyle','none');
            annotation(gp(5),'textbox', [0.8, 0.77, 0.1, 0.1], 'String', ['recSite = ' recSite], 'LineStyle','none');
            annotation(gp(5),'textbox', [0.4,0.9,0.1,0.1],'String',['Opto' 'UnitNum# ' num2str(unitNum)],...
                'LineStyle','none', 'FontSize', 12);
            hold off    
            saveas(g(5),fullfile(savePath6, ['UnitNum#' num2str(unitNum) '.png']));
        end

        % add ACG and QC
        
    
        SR = 30000;
        dupSE = se.Duplicate();
        dupSE.SliceSession(0,'absolute');
        bin_size = 0.0005; %in seconds
    
        binsize = bin_size * SR; %in samples
    
        window_size = 0.1;%in seconds
    
        winsize_bins = floor(window_size / bin_size);
        
        edges = 0:1:(floor(winsize_bins / 2));
    
        spikeTimes = dupSE.GetTable('spikeTime');
    
        try
            uSpike_times = cell2mat(spikeTimes{1, unitNum}); %in seconds
        catch
           uSpike_times = spikeTimes{1, unitNum}; %in seconds
        end

        uSpike_samples = uSpike_times * SR;  %in samples

        shift = 1;

        mask = true(size(uSpike_samples, 1), 1);

        acg{unitNum} = zeros(1, floor(winsize_bins/2));

        while any(mask(1:end-shift))

            spike_diff = uSpike_samples((1+shift):end) - uSpike_samples(1:end-shift);

            spike_diff_b = floor(spike_diff / binsize);

            mask(spike_diff_b >= floor(winsize_bins / 2)) = false;
            
            m = mask(1:end-shift);

            d = spike_diff_b(m);

            [N, ~] = histcounts(d, edges);

            acg{unitNum} = acg{unitNum} + N;

            shift = shift + 1;

        end
        
%             % Approximate average firing rate as median value of binned
%             % firing rates, using 1s bins
%             
%             edges = 0:0.1:max(uSpike_times);
%             FRs = histcounts(uSpike_times', edges);
%             FRs = FRs/0.1;
%             F = max(FRs);
        tauR = 0.002;
        tauC = 0.001;
        p{unitNum} = sum(acg{unitNum}(1:tauR/bin_size)) / numel(uSpike_times);
        F = numel(uSpike_times) / max(uSpike_times);
        
        
        
        FA{unitNum} = MNeuro.ClusterContamination(p{unitNum}, F, tauR, tauC);
        ISI_VR = p{unitNum};
        
        sym = fliplr(acg{unitNum});
        acg{unitNum} = [sym acg{unitNum}]; 
        unit = ['Unit Num ' num2str(unitNum)];
%         acg = se.userData.spikeInfo.acg;
        
        
        %plot acg{unitNum}
        g(4) = figure(4);clf
        
        gp(4) = uipanel('Parent', g(4), 'BackgroundColor', 'white', 'Position', [0 0 1 1]);
        h = subplot(1,3,1,'Parent', gp(4));
        hold(h, 'on');
        y = [acg{unitNum}(1:numel(acg{unitNum})/2) 0 acg{unitNum}(numel(acg{unitNum})/2+1:end)];
        binsw = -window_size/2:bin_size:window_size/2;
        b = bar(binsw*1000, y);
        b.FaceColor = 'blue';
        b.FaceColor = 'flat';
        recolor_violation = (numel(y)+1)/2-(tauR/bin_size):(numel(y)+1)/2+(tauR/bin_size);            
        b.CData(recolor_violation,:) = repmat([1 0 0],numel(recolor_violation),1);
        xlabel(['ISI(ms) binsize' num2str(bin_size*1000)], 'fontsize', 14);
        ylabel('# of spikes', 'fontsize', 14);
        annotation(gp(4),'textbox', [0.2 0.7 0.3 0.3], 'string', ['FPrate = ' ...
            num2str(se.userData.spikeInfo.FA{unitNum}) newline 'ISIV = ' num2str(se.userData.spikeInfo.ISI_VR{unitNum}*100) '%'],...
             'LineStyle','none');
        box off
        saveas(b,fullfile(savePath, ['Unit' num2str(unitNum) '-acg'  '.png']));
        hold(h,'off');
        
        
        % Map raw data to memory


        
        unitChannelInd = se.userData.spikeInfo.unit_channel_ind(unitNum); 
        chanMap = se.userData.sessionInfo.channel_map; 
        chanMap = chanMap.chanMap;
        unitChannel = find(ismember(chanMap, unitChannelInd));    
%         gg = figure(111);clf;
%         hold on;
%         plot(voltage(unitChannelInd,:));
%         plot(uSpike_samples, ones(1,size(uSpike_samples,1))*2500, '.')                            
        
      
      
       
        seWV = se.userData.spikeInfo.unit_mean_waveform(:,unitNum);
        x = 1:size(seWV,1);
        time = x/SR*1000; %in ms
        win = {};
        win = [-size(seWV,1)/2+1:1:size(seWV,1)/2] + uSpike_samples;
        unitVoltage = voltage(unitChannelInd,:);
        rowDist = mat2cell(win, ones(size(win,1),1), [size(win,2)]);
        waveforms={};
        for spikeloop = 1:size(win,1)
            try
                waveforms{spikeloop} = unitVoltage(rowDist{spikeloop});
            catch
                waveforms{spikeloop} = unitVoltage(uint64(rowDist{spikeloop}));
                
            end
        end
        waveforms = waveforms';
        waveforms = cell2mat(waveforms);
   
        
        waveNos = size(win,1);
        i = randi(waveNos,[1, min(waveNos,200)]);
        meanWaves = mean(waveforms,1);

%         %calculate SNR from William Olson code
%         noise = mad(unitVoltage, 1); % noise is median absolute deviation of entire trace
%             
%          
%             
%         peak2peak = max(meanWaves) - min(meanWaves); % find peak2peak amplitude of mean waveform
%         SNR = peak2peak / noise;
        SNR = se.userData.spikeInfo.SNR{unitNum};
        h(2) = subplot(1,3,2,'Parent', gp(4));
        hold (h(2), 'on');
        wv =plot(time,waveforms(i,:), 'color', [0.5 0.5 0.5]);
        for wvs = 1:length(wv)
            wv(wvs).Color = [wv(wvs).Color 0.2];
        end
%         wv = patchline(time,waveforms(i,:), 'edgecolor', [0.5 0.5 0.5], 'edgealpha', 0.5);
        plot(time, meanWaves, 'Color', [0 0 0]);
        try
         ylim([(min(meanWaves)-600) (max(meanWaves)+600)]);
        catch 
            keyboard;
        end
        xlabel('time (ms)');
        ylabel('Voltage(uV)');
         annotation(gp(4),'textbox', [0.6 0.6 0.3 0.3], 'string', ['SNR  = ' ...
            num2str(SNR)],...
             'LineStyle','none');
        box off
        hold (h(2),'off');
        saveas(h(2), fullfile(savePath4, ['unitJitter UnitNum ' num2str(unitNum) '.png']));
        
       

        % Make amplitude plots using spike times
        medianWave = median(waveforms(:,1:20),2);
        minWaves = min(waveforms,[],2);
        maxWaves = max(waveforms,[],2);
        waveAmplitudes =[];
        waveAmplitudes = [abs(minWaves-medianWave), abs(maxWaves-medianWave)];
        waveAmplitudes = max(waveAmplitudes,[],2);
        
        h(3) = subplot(1,3,3, 'Parent', gp(4));
        plot(uSpike_times, waveAmplitudes, '.', 'MarkerSize', 5, 'MarkerFaceColor','b');
        ylim([min(waveAmplitudes)-1000, max(waveAmplitudes)+10]);
        xlabel('time (s)');
        ylabel('Voltage(uV)');
        
        title(h(3), 'Amplitude across session');
        saveas(h(3), fullfile(savePath5, ['Template amplitude UnitNum ' num2str(unitNum) '.png']));
       
       
        gMain = figure(100); clf
        nPanels = numel(gp);
        for idx = 1:nPanels
            gSub(idx) = copyobj(gp(idx),gMain);
            set(gSub(idx), 'Position', [0,(idx-1)/nPanels, 1, 1/nPanels]);
        end
        set(gMain, 'Position', [100 80 1200 800])
        annotation(gSub(idx),'textbox', [0.45 0.7 0.3 0.3], 'string', ['UnitNum#' num2str(unitNum) ' quality check'],...
             'LineStyle','none', 'color', 'red', 'Fontsize', 14);
            
        saveas(gMain, fullfile(savePathFinal, ['Plots Unit# ' num2str(unitNum) '.png']));


        
        
    end

    
end

%% Plot Left vs right trials for each of the three conditions. 
% WT-contra-C2, KO-contra-C2 and KO-ipsi-C2

clear all
close all
[readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\IntanSEs', 'Select source SEs');
seNameParts = cellfun(@(x) strsplit(x), seNames, 'UniformOutput', false);
rootParts = strsplit(seDir, '\');
rootPath = fullfile(rootParts{1:end-2});
savePath = fullfile(rootPath,'Figures\Cohort2\deltaLine');
trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
trials{2} = {'Stim_Som_Left', 'Stim_Som_Right', 'Stim_Som_Left_Opto', 'Stim_Som_Right_Opto'}; 

if ~exist('savePath', 'Dir')
    mkdir(savePath)
end

global windowSize statAlpha meanFR seFR pValue unitNums;
windowSize = 0.03; %in seconds 
preWindow = [-windowSize-0.01,-0.01];
postWindow = [0,windowSize]; 
plotcolors = {[1 0 0], [0 0 1], [0 1 0], [0 1 1], [0.8 0.2 0.2], [1 0 1]};
statAlpha = 0.05;
recSite= cell(size(readPaths,1),1);
animalID =  cell(size(readPaths,1),1);
sessDate = cell(size(readPaths,1),1);

for sessNum = 1:size(readPaths,1)
    
    load(readPaths{sessNum});
%     seArray{sessNum} = se;
    recSite{sessNum} = se.userData.sessionInfo.recSite;
    animalID{sessNum} =  se.userData.sessionInfo.MouseName;
    sessDate{sessNum} = se.userData.sessionInfo.seshDate;

    
    fprintf('%s\n\n', readPaths{sessNum});
    tRef = se.GetReferenceTime();
    check = diff(tRef);

    if any(check<0)
        disp('tRefs are not monotonically increasing');
    end

    trialMap = se.userData.sessionInfo.trialMap;

    if ~isempty(trialMap{1})
        trialSplit = strsplit(trialMap{1},':');
        if any(strcmp(trialSplit{2}(1:end-1), 'end'))
            trialInd = [str2double(trialSplit{1}) : se.numEpochs];
        else
            trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}(1:end-1))];
        end
        allTrials = 1:se.numEpochs;
        removeTrials = find(~ismember(allTrials, trialInd));
        se = BS.Preprocess.removeTrials(removeTrials,se);
    end
    
    
    behavData = se.GetTable('behavValue');
    stimRight = behavData.rightStimType{end};
    stimLeft= behavData.leftStimType{end};
    
    
    responses = behavData.response;
    abortTrials = find(cell2mat(responses) == 3);        
    se = BS.Preprocess.removeTrials(abortTrials,se);
    behavData = se.GetTable('behavValue');
    
    

    responses = behavData.result;
    missTrials = find(isnan(responses));
    keepTrials = find(~isnan(responses));
    seMiss =  BS.Preprocess.removeTrials(keepTrials,se);
    se = BS.Preprocess.removeTrials(missTrials,se);
    
    behavData = se.GetTable('behavValue');
    missData = seMiss.GetTable('behavValue');
   
    
    trialTypes = unique(behavData.trialType);

    
    if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
        trialTypes = trials{2};
        stims = {'Left Stim', 'Right Stim', 'Left Stim + Opto', 'Right Stim + Opto'};
    else
        trialTypes = trials{1};
         stims = {'Left Stim', 'Right Stim'};
    end
    
    behavTime = se.GetTable('behavTime');

    for trialType = 1:numel(trialTypes)
        trialTypeIndCorrect = find(strcmp(trialTypes{trialType}, behavData.trialType) & behavData.result);
        
        trialTypeIndInCorrect = find(strcmp(trialTypes{trialType}, behavData.trialType) & ~(behavData.result));
        missInd = find(strcmp(trialTypes{trialType}, missData.trialType));
        
        seCorrect = BS.Preprocess.keepTrials(trialTypeIndCorrect, se);
        seMissTemp = BS.Preprocess.keepTrials(missInd, seMiss);
        seIncorrect = BS.Preprocess.keepTrials(trialTypeIndInCorrect, se);
       

        if any(ismember(trialTypes{trialType}, 'L'))
            stimOnset{trialType} = max(cell2mat(behavTime.leftOnset));
            stimOffset{trialType} = max(cell2mat(behavTime.leftOffset));
        else
            stimOnset{trialType} = max(cell2mat(behavTime.rightOnset));
            stimOffset{trialType} = max(cell2mat(behavTime.rightOffset));
        end
        seS(1:3, trialType) = {seCorrect, seMissTemp, seIncorrect};
        

    end   
    
    spikeTimes = se.GetTable('spikeTime');

    
    for unitNum = 1:size(spikeTimes,2)  
        unitNums(sessNum) = size(spikeTimes,2);
        for sei = 1:3            
            for result = 1:2
                seDup = seS{sei, result}.Duplicate();
                
                spikeTimes = seDup.GetTable('spikeTime');
                ind = 1:height(spikeTimes);
%                 bins{sei, result} = meanWindow(1):0.0025:meanWindow(1);
                preSpikes = seDup.ResampleEventTimes('spikeTime', preWindow);
                postSpikes = seDup.ResampleEventTimes('spikeTime', postWindow);
                 
                preUnitSpikes = preSpikes(ind,unitNum+1); 
                preUnitSpikes = cell2mat(table2cell(preUnitSpikes));
                postUnitSpikes = postSpikes(ind,unitNum+1); 
                postUnitSpikes = cell2mat(table2cell(postUnitSpikes));
                dUnitSpikes{result} = (postUnitSpikes - preUnitSpikes)/windowSize;
                
                [meanFR(sessNum,unitNum,sei, result) , sdFR{sessNum, unitNum,sei, result} , ...
                    seFR{sessNum, unitNum,sei, result} , ciFR{sessNum,unitNum,sei, result} ] = MMath.MeanStats(dUnitSpikes{result}, 1);    
                 if ~isempty(dUnitSpikes{1}) & ~isempty(dUnitSpikes{1})
                    [H, pValue(sessNum,unitNum,sei,result)] = ttest2(dUnitSpikes{result}, zeros(size(dUnitSpikes{result},1),1), 'tail', 'both', 'Alpha', statAlpha);
                else
                    pValue(sessNum,unitNum,sei, result) = 1;
                end
            end
           
        end 
    end
end



stims = {'Left', 'Right'};
% wtSess = find(cell2mat(cellfun(@(x) ismember(x, 'left wS1'), recSite, 'UniformOutput', false)));
% wtUnitNums = unitNums(wtSess);
% wtMeanFR = meanFR(wtSess, :,:,:);
% wtSeFR = seFR(wtSess, :,:,:);
% wtP = pValue(wtSess, :,:);
% 
% contraSess = find(cell2mat(cellfun(@(x) ismember(x, 'contra S1'), recSite, 'UniformOutput', false)));
% contraUnitNums = unitNums(contraSess);
% contraMeanFR = meanFR(contraSess, :,:,:);
% contraSeFR = seFR(contraSess, :,:,:);
% contraP = pValue(contraSess, :,:);
% 
% ipsiSess = find(cell2mat(cellfun(@(x) ismember(x, 'ipsi S1'), recSite, 'UniformOutput', false)));
% ipsiUnitNums = unitNums(ipsiSess);
% ipsiMeanFR = meanFR(ipsiSess, :,:,:);
% ipsiSeFR = seFR(ipsiSess, :,:,:);
% ipsiP = pValue(ipsiSess, :,:);

plotType = {'Correct trials', 'No Lick', 'Incorrect trials'};
recType = {'WT units', 'KO Left Contra units', 'KO Left Ipsi units', 'KO Right Contra'};
recSiteTypes = {'Left wS1', 'Left Contra S1', 'Left Ipsi S1', 'Right Contra S1',};
% sessNumArray ={wtSess, contraSess, ipsiSess};
% meanFRArray = {wtMeanFR,contraMeanFR, ipsiMeanFR};
% seFRArray{wtSeFR, contraSeFR, ipsiSeFR};
% pArray{}

%%
close all
for figNums= 1:width(recType)
    [g(figNums), gp(figNums)] = plotLinePlotcomparisons(recSite, recSiteTypes{figNums}, plotType, ...
        plotcolors, 0);    
end   

gMain = figure(100); clf
nPanels = numel(gp);
set(gMain, 'Position', [0 0 1200 1000])
for idx = 1:nPanels
    gSub(idx) = copyobj(gp(nPanels+1-idx),gMain);
    sgtitle(gSub(idx), '')
    set(gSub(idx), 'Position', [0,(idx-1)/nPanels, 1, 1/nPanels])
    set(gSub(idx), 'Title', recType{nPanels+1-idx}, 'FontWeight', 'bold', 'FontSize',18, 'TitlePosition', 'Centertop');
    set(gSub(idx), 'BorderType', 'none')    
end 
annotation(gSub(2),'textarrow', [0.07,0.2],[ 0.9, 1], 'string', ['Window size for FR is ' num2str(windowSize*1000) ' ms'],...
     'Headstyle', 'none','LineStyle','none', 'color', 'red', 'Fontsize', 14, 'TextRotation', 90);
savefig(gMain,fullfile(savePath, ['Lineplots_LeftvsRight_Allsessions_Allcolors_window ' num2str(windowSize*1000) ' ms.fig']));
saveas(gMain, fullfile(savePath, ['Lineplots_LeftvsRight_Allsessions_Allcolors_window ' num2str(windowSize*1000) ' ms.png']));


for figNums= 1:width(recType)
    [g(figNums), gp(figNums)] = plotLinePlotcomparisons(recSite,  recSiteTypes{figNums}, plotType, ...
         plotcolors, statAlpha);    
end     
gMain = figure(101); clf
nPanels = numel(gp);
set(gMain, 'Position', [0 0 1200 1000])
for idx = 1:nPanels
    gSub(idx) = copyobj(gp(nPanels+1-idx),gMain);
    sgtitle(gSub(idx), '')
    set(gSub(idx), 'Position', [0,(idx-1)/nPanels, 1, 1/nPanels])
    set(gSub(idx), 'Title', recType{nPanels+1-idx}, 'FontWeight', 'bold', 'FontSize',18, 'TitlePosition', 'Centertop');
    set(gSub(idx), 'BorderType', 'none')    
end  
annotation(gSub(2),'textarrow', [0.07,0.2],[ 0.9, 1], 'string', ['Window size for FR is ' num2str(windowSize*1000) ' ms'],...
     'Headstyle', 'none','LineStyle','none', 'color', 'red', 'Fontsize', 14, 'TextRotation', 90);
savefig(gMain,fullfile(savePath, ['Lineplots_LeftvsRight_Allsessions_Sigcolors_window ' num2str(windowSize*1000) ' ms.fig']));
saveas(gMain, fullfile(savePath, ['Lineplots_LeftvsRight_Allsessions_Sigcolors_window ' num2str(windowSize*1000) ' ms.png']));


%% plot all units of same recording site together
clear all

[readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\IntanSEs', 'Select source SEs');
sigma = 0.005;
FRlims = [-0.5 0.5];
recSiteTypes = {'Left wS1', 'Left Contra S1', 'Left Ipsi S1', 'Right Contra S1',};
plotType = {'WT units', 'KO Left Contra units', 'KO Left Ipsi units', 'KO Right Contra'};
trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
trials{2} = {'Stim_Som_Left', 'Stim_Som_Right', 'Stim_Som_Left_Opto', 'Stim_Som_Right_Opto'}; 
%%
folderSigma = '0_005';
close all

f(1) = figure();clf

f(2) = figure(); clf

f(3) = figure();clf

f(4) = figure();clf
rootParts = strsplit(seDir, '\');
rootPath = fullfile(rootParts{1:end-2});
savePath = fullfile(rootPath,'Figures\Cohort2\AllUnits', folderSigma);
  
if ~exist('savePath', 'Dir')
    mkdir(savePath)
end

figureSerial=[1,1,1,1];
for sessNum = 1:size(readPaths,1)    
    seParts = strsplit(seNames{sessNum}, ' ');
    
  
    
    load(readPaths{sessNum});
%     seArray{sessNum} = se;
    recSite{sessNum} = se.userData.sessionInfo.recSite;
    animalID{sessNum} =  se.userData.sessionInfo.MouseName;
    sessDate{sessNum} = se.userData.sessionInfo.seshDate;
    
    figureNum = (find(ismember(recSiteTypes, se.userData.sessionInfo.recSite{1}))); 
    figure(f(figureNum));
    tRef = se.GetReferenceTime();
    check = diff(tRef);

    fprintf('%s\n\n', readPaths{sessNum});
    tRef = se.GetReferenceTime();
    check = diff(tRef);

    if any(check<0)
        disp('tRefs are not monotonically increasing');
    end
    try

        trialMap = se.userData.sessionInfo.trialMap;
    catch
        trialMap{1} = [];
    end

        if ~isempty(trialMap{1})
            trialSplit = strsplit(trialMap{1},':');
            if any(strcmp(trialSplit{2}(1:end-1), 'end'))
                trialInd = [str2double(trialSplit{1}) : se.numEpochs];
            else
                trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}(1:end-1))];
            end
            allTrials = 1:se.numEpochs;
            removeTrials = find(~ismember(allTrials, trialInd));
            se = BS.Preprocess.removeTrials(removeTrials,se);
         end
    
       

    
    
    behavData = se.GetTable('behavValue');
    stimRight = behavData.rightStimType{end};
    stimLeft= behavData.leftStimType{end};
    
    
    responses = behavData.response;
    abortTrials = find(cell2mat(responses) == 3);        
    se = BS.Preprocess.removeTrials(abortTrials,se);
    behavData = se.GetTable('behavValue');
    
    

    responses = behavData.response;

    missTrials = find(~cell2mat(responses));
    keepTrials = find(cell2mat(responses));
    seMiss =  BS.Preprocess.removeTrials(keepTrials,se);
    se = BS.Preprocess.removeTrials(missTrials,se);
    
    behavData = se.GetTable('behavValue');
    missData = seMiss.GetTable('behavValue');
   
    
    trialTypes = unique(behavData.trialType);

    if any(cell2mat(cellfun(@(x) any(ismember(x,'C')), trialTypes, 'UniformOutput',false)))
        stims = {'Left Stim', 'Right Stim'};
    else

        if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
            trialTypes = trials{2};
            stims = {'Left Stim', 'Right Stim', 'Left Stim + Opto', 'Right Stim + Opto'};
        else
            trialTypes = trials{1};
             stims = {'Left Stim', 'Right Stim'};
        end
    end
    
    behavTime = se.GetTable('behavTime');

    for trialType = 1:numel(trialTypes)
        trialTypeIndCorrect = find(strcmp(trialTypes{trialType}, behavData.trialType) & behavData.result);
        
        trialTypeIndInCorrect = find(strcmp(trialTypes{trialType}, behavData.trialType) & ~(behavData.result));
        missInd = find(strcmp(trialTypes{trialType}, missData.trialType));
        
        seCorrect = BS.Preprocess.keepTrials(trialTypeIndCorrect, se);
        seMissTemp = BS.Preprocess.keepTrials(missInd, seMiss);
        seIncorrect = BS.Preprocess.keepTrials(trialTypeIndInCorrect, se);
       

        if any(ismember(trialTypes{trialType}, 'L'))
            stimOnset{trialType} = max(cell2mat(behavTime.leftOnset));
            stimOffset{trialType} = max(cell2mat(behavTime.leftOffset));
        else
            stimOnset{trialType} = max(cell2mat(behavTime.rightOnset));
            stimOffset{trialType} = max(cell2mat(behavTime.rightOffset));
        end
        seS(1:3, trialType) = {seCorrect, seMissTemp, seIncorrect};
        

    end   
    
    spikeTimes = se.GetTable('spikeTime');
    channelInds = se.userData.spikeInfo.unit_channel_ind;  
    chanDepth = 20:20:1280; %(in um)
    chanMap = se.userData.spikeInfo.channel_map;         
    for unitNum =1:size(spikeTimes,2)
        clearvars unitSpikes;
        
        sei =1;
        unitChannelId = channelInds(unitNum);
        unitDepth = chanDepth(chanMap(unitChannelId));

        
        for result = 1:2
            seDup = seS{sei, result}.Duplicate();
            
            spikeTimes = seDup.GetTable('spikeTime');
            ind = 1:height(spikeTimes);
            bins{sei, result} = -0.5:0.0025:2.5;
            spikes = seDup.ResampleEventTimes('spikeTime', bins{sei, result}, 'Normalization', 'countdensity');
            for i = 1 : width(spikes)
                    spikes.(i) = cellfun(@(x) MNeuro.Filter1(x, 1/0.0025, 'gaussian', sigma), spikes.(i), 'UniformOutput', false);
            end
            
            unitSpikes = spikes(ind,unitNum+1);           
            unitSpikes = table2cell(unitSpikes);

            for i = 1:size(unitSpikes,1)
                if size(unitSpikes{i}, 1)>1
                    unitSpikes{i} = unitSpikes{i}';
                end
            end
            
            unitSpikes = cell2mat(unitSpikes);
            
            try
                [meanFR{sei, result} , sdFR{sei, result} , seFR{sei, result} , ciFR{sei, result} ] = MMath.MeanStats(unitSpikes, 1);    
            catch
                maxFR{sei, result} = 0;
                continue;
                
            end
            maxFR{sei, result} = max(meanFR{sei, result})+1;
        end         
        
        
        
    end    
          
             
end
 % plot all units now
        color = {'r','b'};
        
        h = subplot(9,10,figureSerial(figureNum), 'Parent', f(figureNum));
        hold(h, 'on');
        for result = 1:2
            
            plot(bins{sei}(1:size(meanFR{sei, result},2)),meanFR{sei, result}, color{result}, 'LineWidth', 1);
            
            if ~isempty(meanFR{sei, result})
                
                MPlot.ErrorShade(bins{1}(1:size(meanFR{sei, result},2)), meanFR{sei, result}, ...
                        ciFR{sei, result}(2,:),ciFR{sei, result}(1,:), 'color',color{result}, 'Alpha', 0.3, 'IsRelative', false);
                
            end
        end

          
       
        ylim([0,max(cell2mat(maxFR), [], 'all')]); 
        yLimits = get(gca,'YLim');
        MPlot.Blocks([stimOnset{1} stimOffset{1}], [max(cell2mat(maxFR), [], 'all')*0.98,max(cell2mat(maxFR), [], 'all')], ...
                        color{1}, 'FaceAlpha', 0.6);    
        MPlot.Blocks([stimOnset{2} stimOffset{2}], [max(cell2mat(maxFR), [], 'all')*0.95,max(cell2mat(maxFR), [], 'all')*0.97], ...
                        color{2}, 'FaceAlpha', 0.6); 
        xlabel('epoch time (s)');
        ylabel('FR');  
        xlim(FRlims);

        try
        if unitNum == 1
            dateNum = sessDate{sessNum};           

            title([char(animalID{sessNum}) ' ' datestr(dateNum{1}) ' UnitNum#' num2str(unitNum) newline 'Depth ' num2str(unitDepth) ' \mum']);
        else
            title(['UnitNum#' num2str(unitNum) newline 'Depth ' num2str(unitDepth) ' \mum']);
        end
        catch
            keyboard
        end
        box off  

        hold(h, 'off');
        
        figureSerial(figureNum) =  figureSerial(figureNum) +1;



for i =1:size(plotType,2)
    figure(f(i));
    
    hAxes   = findobj(allchild(f(i)), 'flat', 'Type', 'axes');
    plotNums = numel(hAxes);
    a = get(f(i), 'position');    
    set(f(i), 'position', a + [-a(1) -a(2) 10*plotNums 10*plotNums])
    sgtitle(plotType{i});
    savefig(f(i),fullfile(savePath,  [plotType{i} ' units.fig']));
%     MPlot.SavePNG(f(i), fullfile(savePath,  [plotType{i} ' units.pdf']));
    exportgraphics(f(i), fullfile(savePath,  [plotType{i} ' units.png']));
end

%% plot all units for opto Trials
clear all

[readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\IntanSEs', 'Select source SEs');
sigma = 0.005;
FRlims = [-0.5 0.5];
recSiteTypes = {'Left wS1', 'Left Contra S1', 'Left Ipsi S1', 'Right Contra S1',};
plotType = {'WT units', 'KO Left Contra units', 'KO Left Ipsi units', 'KO Right Contra'};
trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
trials{2} = {'Stim_Som_Left', 'Stim_Som_Right', 'Stim_Som_Left_Opto', 'Stim_Som_Right_Opto'}; 
%%
folderSigma = '0_005';
close all

f(1) = figure();clf

f(2) = figure(); clf

f(3) = figure();clf

f(4) = figure();clf

f(5) = figure();clf

f(6) = figure(); clf

f(7) = figure();clf

f(8) = figure();clf
rootParts = strsplit(seDir, '\');
rootPath = fullfile(rootParts{1:end-2});
savePath = fullfile(rootPath,'Figures\Cohort2\AllUnits', folderSigma);
  
if ~exist('savePath', 'Dir')
    mkdir(savePath)
end

figureSerial=[1,1,1,1,1,1,1,1];
for sessNum = 2:size(readPaths,1)    
    seParts = strsplit(seNames{sessNum}, ' ');
    
   
    
    load(readPaths{sessNum});
%     seArray{sessNum} = se;
    recSite{sessNum} = se.userData.sessionInfo.recSite;
    animalID{sessNum} =  se.userData.sessionInfo.MouseName;
    sessDate{sessNum} = se.userData.sessionInfo.seshDate;
    inhSite{sessNum} = se.userData.sessionInfo.inhSite;
    
    if strcmp(inhSite{sessNum}, 'NA')
        continue;
    end
    
    figureNum = (find(ismember(recSiteTypes, se.userData.sessionInfo.recSite{1}))); 
    figure(f(figureNum));
    tRef = se.GetReferenceTime();
    check = diff(tRef);

    fprintf('%s\n\n', readPaths{sessNum});
    tRef = se.GetReferenceTime();
    check = diff(tRef);

    if any(check<0)
        disp('tRefs are not monotonically increasing');
    end

    trialMap = se.userData.sessionInfo.trialMap;

    if ~isempty(trialMap{1})
        trialSplit = strsplit(trialMap{1},':');
        if any(strcmp(trialSplit{2}(1:end-1), 'end'))
            trialInd = [str2double(trialSplit{1}) : se.numEpochs];
        else
            trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}(1:end-1))];
        end
        allTrials = 1:se.numEpochs;
        removeTrials = find(~ismember(allTrials, trialInd));
        se = BS.Preprocess.removeTrials(removeTrials,se);
    end
    
    
    behavData = se.GetTable('behavValue');
    stimRight = behavData.rightStimType{end};
    stimLeft= behavData.leftStimType{end};
    
    
    responses = behavData.response;
    abortTrials = find(cell2mat(responses) == 3);        
    se = BS.Preprocess.removeTrials(abortTrials,se);
    behavData = se.GetTable('behavValue');
    
    

    responses = behavData.result;
    
    
    behavData = se.GetTable('behavValue');
    
   
    
    trialTypes = unique(behavData.trialType);

    
    if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
        trialTypes = trials{2};
        stims = {'Left Stim', 'Right Stim', 'Left Stim + Opto', 'Right Stim + Opto'};
    else
        trialTypes = trials{1};
         stims = {'Left Stim', 'Right Stim'};
    end
    
    behavTime = se.GetTable('behavTime');

    for trialType = 1:numel(trialTypes)
        trialTypeInd = find(strcmp(trialTypes{trialType}, behavData.trialType));
        
       
        
        seTrial = BS.Preprocess.keepTrials(trialTypeInd, se);
       
       

        if any(ismember(trialTypes{trialType}, 'L'))
            stimOnset{trialType} = max(cell2mat(behavTime.leftOnset));
            stimOffset{trialType} = max(cell2mat(behavTime.leftOffset));
        else
            stimOnset{trialType} = max(cell2mat(behavTime.rightOnset));
            stimOffset{trialType} = max(cell2mat(behavTime.rightOffset));
        end
        seS(trialType) = {seTrial};
        

    end   
    
    spikeTimes = se.GetTable('spikeTime');

    
    for unitNum =1:size(spikeTimes,2)
        clearvars unitSpikes;
        
        
        
            
        for trialType = 1:size(seS,2)
            seDup = seS{trialType}.Duplicate();
            
            spikeTimes = seDup.GetTable('spikeTime');
            ind = 1:height(spikeTimes);
            bins{trialType} = -0.5:0.0025:2.5;
            spikes = seDup.ResampleEventTimes('spikeTime', bins{trialType}, 'Normalization', 'countdensity');
            for i = 1 : width(spikes)
                    spikes.(i) = cellfun(@(x) MNeuro.Filter1(x, 1/0.0025, 'gaussian', sigma), spikes.(i), 'UniformOutput', false);
            end
            
            unitSpikes = spikes(ind,unitNum+1);           
            unitSpikes = table2cell(unitSpikes);
            for i = 1:size(unitSpikes,1)
                if size(unitSpikes{i}, 1)>1
                    unitSpikes{i} = unitSpikes{i}';
                end
            end
            unitSpikes = cell2mat(unitSpikes);
            try
                [meanFR{trialType} , sdFR{trialType} , seFR{trialType} , ciFR{trialType} ] = MMath.MeanStats(unitSpikes, 1);    
            catch
                maxFR{trialType} = 0;
                continue;
                
            end
            maxFR{trialType} = max(meanFR{trialType})+1;
        end         
        
        
        
        color = {'r','b', [0.5 0.5 0.5]};
        
        
        for result = 1:2
            figureAdd = (result-1)*4;
            
            figure(f(figureNum+figureAdd));
            h = subplot(5,10,figureSerial(figureNum+figureAdd), 'Parent', f(figureNum+figureAdd));
            hold(h, 'on');
            plot(bins{result}(1:size(meanFR{result},2)),meanFR{result}, color{result}, 'LineWidth', 1);
            
            if ~isempty(meanFR{result})
                
                MPlot.ErrorShade(bins{1}(1:size(meanFR{result},2)), meanFR{result}, ...
                        ciFR{result}(2,:),ciFR{result}(1,:), 'color',color{result}, 'Alpha', 0.3, 'IsRelative', false);
                
            end

            plot(bins{result+2}(1:size(meanFR{result+2},2)),meanFR{result+2}, 'color', color{3}, 'LineWidth', 1);
            
            if ~isempty(meanFR{result+2})
                
                MPlot.ErrorShade(bins{1}(1:size(meanFR{result+2},2)), meanFR{result+2}, ...
                        ciFR{result+2}(2,:),ciFR{result+2}(1,:), 'color',color{3}, 'Alpha', 0.3, 'IsRelative', false);
                
            end

             ylim([0,max(cell2mat(maxFR), [], 'all')]); 
            yLimits = get(gca,'YLim');
            MPlot.Blocks([stimOnset{1} stimOffset{1}], [max(cell2mat(maxFR), [], 'all')*0.98,max(cell2mat(maxFR), [], 'all')], ...
                            color{1}, 'FaceAlpha', 0.6);    
            MPlot.Blocks([stimOnset{2} stimOffset{2}], [max(cell2mat(maxFR), [], 'all')*0.95,max(cell2mat(maxFR), [], 'all')*0.97], ...
                            color{3}, 'FaceAlpha', 0.6); 
            xlabel('epoch time (s)');
            ylabel('FR');  
            xlim(FRlims);
            try
                if unitNum == 1
                    dateNum = sessDate{sessNum};           
        
                    title([char(animalID{sessNum}) ' ' datestr(dateNum{1}) ' UnitNum#' num2str(unitNum)]);
                else
                    title(['UnitNum#' num2str(unitNum)]);
                end
            catch
                keyboard
            end
            box off  
            hold(h, 'off');
        end

          
        
       
        
        figureSerial(figureNum) =  figureSerial(figureNum) +1;
        figureSerial(figureNum + 4) =  figureSerial(figureNum + 4) +1;
    end    
          
             
end

for i =1:size(plotType,2)*2
    
    if ismember(f(i), 5:8)
        result =2;
        plotTypeNum = i-4;
    else
        result =1;
        plotTypeNum = i;
    end
    figure(f(plotTypeNum));
    hAxes   = findobj(allchild(f(i)), 'flat', 'Type', 'axes');
    plotNums = numel(hAxes);
    a = get(f(i), 'position');    
    set(f(i), 'position', a + [-a(1) -a(2) 10*plotNums 10*plotNums])
    sgtitle(plotType{plotTypeNum});
    savefig(f(i),fullfile(savePath,  [plotType{plotTypeNum} ' ' stims{result} ' units_opto.fig']));
%     MPlot.SavePNG(f(i), fullfile(savePath,  [plotType{i} ' units.pdf']));
    exportgraphics(f(i), fullfile(savePath,  [plotType{plotTypeNum} ' ' stims{result} ' units_opto.png']));
end

%% plot raster for comparisions 
clear all
close all
[readPaths, seDir, seNames] = MBrowse.Files('G:\VC03_RoboKO\VC0301\IntanSEs', 'Select source SEs');
sigma = 0.0025;
FRlims = [-0.5 0.5];
trials{1} = {'Stim_Som_Left', 'Stim_Som_Right'};
trials{2} = {'Stim_Som_Left', 'Stim_Som_Right', 'Stim_Som_Left_Opto', 'Stim_Som_Right_Opto'}; 

for sessNum = 3:size(readPaths,1)
    clearvars -except sessNum readPaths seDir seNames sigma trials FRlims;
    seParts = strsplit(seNames{sessNum}, ' ');
    rootParts = strsplit(seDir, '\');
    rootPath = fullfile(rootParts{1:end-2});    
    savePath1 = fullfile(rootPath,'Figures\Cohort2\Raster\correctvsmissed', seNames{sessNum});
    savePath2 = fullfile(rootPath,'Figures\Cohort2\Raster\correctvsincorrect', seNames{sessNum});
    savePath3 = fullfile(rootPath,'Figures\Cohort2\Raster\leftvsright', seNames{sessNum});
    savePath4 = fullfile(rootPath,'Figures\Cohort2\Raster\Opto', seNames{sessNum});
    savePathFinal = fullfile(rootPath,'Figures\Cohort2\Raster\combined', seNames{sessNum});
    
    if ~exist('savePathFinal', 'Dir')
        mkdir(savePathFinal)
    end
   

    if ~exist('savePath1', 'Dir')
        mkdir(savePath1)
    end

    if ~exist('savePath2', 'Dir')
        mkdir(savePath2)
    end

    if ~exist('savePath3', 'Dir')
        mkdir(savePath3)
    end

    if ~exist('savePath4', 'Dir')
        mkdir(savePath4)
    end


    load(readPaths{sessNum});
    fprintf('%s\n\n', readPaths{sessNum});
    tRef = se.GetReferenceTime();
    check = diff(tRef);

    if any(check<0)
        disp('tRefs are not monotonically increasing');
    end

    trialMap = se.userData.sessionInfo.trialMap;

    if ~isempty(trialMap{1})
        trialSplit = strsplit(trialMap{1},':');
        if any(strcmp(trialSplit{2}(1:end-1), 'end'))
            trialInd = [str2double(trialSplit{1}) : se.numEpochs];
        else
            trialInd = [str2double(trialSplit{1}) : str2double(trialSplit{2}(1:end-1))];
        end
        allTrials = 1:se.numEpochs;
        removeTrials = find(~ismember(allTrials, trialInd));
        se = BS.Preprocess.removeTrials(removeTrials,se);
    end
    
    
    behavData = se.GetTable('behavValue');
    stimRight = behavData.rightStimType{end};
    stimLeft= behavData.leftStimType{end};
    
    
    responses = behavData.response;
    abortTrials = find(cell2mat(responses) == 3);        
    se = BS.Preprocess.removeTrials(abortTrials,se);
    behavData = se.GetTable('behavValue');
    
    

    responses = behavData.result;
    missTrials = find(isnan(responses));
    keepTrials = find(~isnan(responses));
    seMiss =  BS.Preprocess.removeTrials(keepTrials,se);
    se = BS.Preprocess.removeTrials(missTrials,se);
    
    behavData = se.GetTable('behavValue');
    missData = seMiss.GetTable('behavValue');
   
    
    trialTypes = unique(behavData.trialType);

    
    if any(cell2mat(cellfun(@(x) any(ismember(x,'p')), trialTypes, 'UniformOutput',false)))
        trialTypes = trials{2};
        stims = {'Left Stim', 'Right Stim', 'Left Stim + Opto', 'Right Stim + Opto'};
    else
        trialTypes = trials{1};
         stims = {'Left Stim', 'Right Stim'};
    end
    
    recSite = se.userData.sessionInfo.recSite{1};
    behavTime = se.GetTable('behavTime');

    for trialType = 1:numel(trialTypes)
        trialTypeIndCorrect = find(strcmp(trialTypes{trialType}, behavData.trialType) & behavData.result);
        
        trialTypeIndInCorrect = find(strcmp(trialTypes{trialType}, behavData.trialType) & ~(behavData.result));
        missInd = find(strcmp(trialTypes{trialType}, missData.trialType));
        
        seCorrect = BS.Preprocess.keepTrials(trialTypeIndCorrect, se);
        seMissTemp = BS.Preprocess.keepTrials(missInd, seMiss);
        seIncorrect = BS.Preprocess.keepTrials(trialTypeIndInCorrect, se);
       

        if any(ismember(trialTypes{trialType}, 'L'))
            stimOnset{trialType} = max(cell2mat(behavTime.leftOnset));
            stimOffset{trialType} = max(cell2mat(behavTime.leftOffset));
        else
            stimOnset{trialType} = max(cell2mat(behavTime.rightOnset));
            stimOffset{trialType} = max(cell2mat(behavTime.rightOffset));
        end
        seS(1:3, trialType) = {seCorrect, seMissTemp, seIncorrect};
        

    end   
    
   spikeTimes = se.GetTable('spikeTime');


    
    for unitNum =1:size(spikeTimes,2)
        clearvars spikes unitspikes2 unitspikes;
        
        for sei = 1:size(seS,1)
            
            for result = 1:size(seS,2)
                seDup = seS{sei, result}.Duplicate();
                
                spikeTimes = seDup.GetTable('spikeTime');
                ind = 1:height(spikeTimes);
                bins{sei, result} = FRlims(1):0.0025:FRlims(2);
                if seDup.numEpochs >0
                    spikeTimes= seDup.SliceEventTimes('spikeTime', FRlims, 'Fill', 'Bleed');
                
                
%                 spikes.(unitNum) = cellfun(@(x) MNeuro.Filter1(x, 1/0.0025, 'gaussian', sigma), spikes.(unitNum), 'UniformOutput', false);
                
                
                    unitSpikes = spikeTimes(ind,unitNum);           
                    unitSpikes = table2cell(unitSpikes);
                    for trialNum = 1:height(unitSpikes)
                        if size(unitSpikes{trialNum}, 1)>1
                            unitSpikes{trialNum} = unitSpikes{trialNum}';
                        end
                    end
    
                    spikes{sei,result} = unitSpikes;
                else
                    spikes{sei,result} ={};
                end

             
            end

           
            
            
        end        
       
     
        clearvars unitSpikes;
        close all
        g(1) =figure(1);clf;
        gp(1) = uipanel('Parent', g(1), 'BackgroundColor', 'white', 'Position', [0 0 1 1]);
        hold on
        color = {[0 1 0], [0 0 0]};
        for result = 1:2
            h(result) = subplot(1,2,result,'Parent', gp(1));
            hold(h(result), 'on');
            yPos = [0];
            for sei = 1:2
                yPos = [1:height(spikes{sei,result})] + [yPos(end)];
                MPlot.PlotRaster(spikes{sei,result}, yPos, 'color', color{sei})              
                
            end
            
            xlim(FRlims);                
            yLimits = get(gca,'YLim');
            ylim([0, se.numEpochs]);
            yLimits = get(gca,'YLim');

            MPlot.Blocks([stimOnset{result} stimOffset{result}], [yLimits], ...
                            color{2}, 'FaceAlpha', 0.2);       
            xlabel('epoch time (s)');
            ylabel('Trial Nums');  
            title(stims{result});
            box off  
            hold(h(result), 'off');
            
            
        end        
        annotation(gp(1),'textbox', [0.19, 0.79, 0.1, 0.1], 'String', ['left stim'], 'LineStyle','none');
        annotation(gp(1),'textbox', [0.635, 0.79, 0.1, 0.1], 'String', ['right stim'], 'LineStyle','none');
        annotation(gp(1),'textbox', [0.8, 0.77, 0.1, 0.1], 'String', ['recSite = ' recSite], 'LineStyle','none');
        sgtitle(gp(1),['correct vs missed UnitNum#' num2str(unitNum)]);
        hold off    
        saveas(g(1),fullfile(savePath1, ['UnitNum#' num2str(unitNum) '.png']));
    
        

        
        g(2) =figure();clf;
        gp(2) = uipanel('Parent', g(2), 'BackgroundColor', 'white', 'Position', [0 0 1 1]);
        hold on
        color = {'g','k','r'};
        for result = 1:2
            h(result) = subplot(1,2,result,'Parent', gp(2));
            hold(h(result), 'on');
            yPos = 0;
            for sei = [1,3]
                yPos = [1:height(spikes{sei,result})] + [yPos(end)];
                MPlot.PlotRaster(spikes{sei,result}, yPos, 'color', color{sei})              
                
            end
            
            xlim(FRlims);    
            
            yLimits = get(gca,'YLim');
            ylim([0, se.numEpochs]);
            yLimits = get(gca,'YLim');

            MPlot.Blocks([stimOnset{result} stimOffset{result}], [yLimits], ...
                            color{2}, 'FaceAlpha', 0.2);       
            xlabel('epoch time (s)');
            ylabel('Trial Nums');  
            title(stims{result});
            box off  
            hold(h(result), 'off');
            
            
        end        
        annotation(gp(2),'textbox', [0.19, 0.79, 0.1, 0.1], 'String', ['left stim'], 'LineStyle','none');
        annotation(gp(2),'textbox', [0.635, 0.79, 0.1, 0.1], 'String', ['right stim'], 'LineStyle','none');
        annotation(gp(2),'textbox', [0.8, 0.77, 0.1, 0.1], 'String', ['recSite = ' recSite], 'LineStyle','none');
       
        sgtitle(gp(2),['correct vs incorrect UnitNum#' num2str(unitNum)]);
        hold off    
        set(gcf, 'color','none');
        saveas(g(2),fullfile(savePath2, ['UnitNum#' num2str(unitNum) '.png']));
    

        resultTypes = {'correct', 'NoLick', 'Incorrect'};
           % blue is right and red is left
        
        g(3) =figure(3);clf;
        gp(3) = uipanel('Parent', g(3), 'BackgroundColor', 'white', 'Position', [0 0 1 1]);
        hold on
        color = {'r','b'};
        for sei = 1:3
            h(sei) = subplot(1,3,sei, 'Parent', gp(3));
            hold(h(sei), 'on');
            yPos = [0];
            for result = 1:2
                
                yPos = [1:height(spikes{sei,result})] + [yPos(end)];
                MPlot.PlotRaster(spikes{sei,result}, yPos, 'color', color{result}) 
            end

            xlim([-0.5,0.5]);    
            
            yLimits = get(gca,'YLim');
            ylim([0, se.numEpochs]);
            yLimits = get(gca,'YLim');
            MPlot.Blocks([stimOnset{1} stimOffset{1}], [yLimits(2)*0.98, yLimits(2)], ...
                            color{1}, 'FaceAlpha', 0.6);    
            MPlot.Blocks([stimOnset{2} stimOffset{2}], [yLimits(2)*0.95,yLimits(2)*0.97], ...
                            color{2}, 'FaceAlpha', 0.6); 
            xlabel('epoch time (s)');
            ylabel('Trial Nums');  
            title(resultTypes{sei});
            box off  
            hold(h(sei), 'off');
            
            
        end        
        
        annotation(gp(3),'textbox', [0.18, 0.875, 0.1, 0.1], 'String', ['left stim'], 'LineStyle','none');
        annotation(gp(3),'textbox', [0.18, 0.84, 0.1, 0.1], 'String', ['right stim'], 'LineStyle','none');
        annotation(gp(3),'textbox', [0.8, 0.77, 0.1, 0.1], 'String', ['recSite = ' recSite], 'LineStyle','none');
        annotation(gp(3),'textbox', [0.5,0.75,0.1,0.1],'String',['right vs left' newline 'UnitNum# ' num2str(unitNum)],...
            'LineStyle','none', 'FontSize', 12);
        hold off    
        saveas(g(3),fullfile(savePath3, ['UnitNum#' num2str(unitNum) '.png']));
    
        if size(seS,2) >2
            g(4) =figure(4);clf;
            gp(4) = uipanel('Parent', g(4), 'BackgroundColor', 'white', 'Position', [0 0 1 1]);
            color = {'r','b', [0.5 0.5 0.5]};
            hold on
            
            for result = 1:size(seS,2)
                for rows = 1:size(seS,1)
                    seNumEpochs(rows) = seS{rows,result}.numEpochs;
                    
                end
               seExist = find(seNumEpochs);
               seMerged{result} = Merge(seS{seExist,result});
               seDup = seMerged{result}.Duplicate();
                    
             
               
              if seDup.numEpochs >0 
                  spikeTimes2 = seDup.SliceEventTimes('spikeTime', FRlims);
                  ind2 = 1:height(spikeTimes2);  
                    
                    
                   unitSpikes2 = spikeTimes2(ind2,unitNum);           
                   unitSpikes2 = table2cell(unitSpikes2);
                   for trialNum = 1:height(unitSpikes2)
                       if size(unitSpikes2{trialNum}, 1)>1
                           unitSpikes2{trialNum} = unitSpikes2{trialNum}';
                       end
                   end
                   spikes2{result} = unitSpikes2;
              else
                  spikes2{result} = {};
              end
               
        
            end
    
    
            
            for sei = 1:2
                h(sei) = subplot(1,2,sei, 'Parent', gp(4));
                hold(h(sei), 'on');
               
                yPos =[0];


                yPos = [1:height(spikes2{sei})] + [yPos(end)];
                MPlot.PlotRaster(spikes2{sei}, yPos, 'color', color{sei});
                yPos = [1:height(spikes2{sei+2})] + [yPos(end)];
                MPlot.PlotRaster(spikes2{sei+2}, yPos, 'color', color{3});

                xlim([-0.5,0.5]);  
                yLimits = get(gca,'YLim');
                ylim([0, se.numEpochs]);
                yLimits = get(gca,'YLim');
                MPlot.Blocks([stimOnset{sei} stimOffset{sei}], [yLimits(2)*0.98, yLimits(2)], ...
                                color{sei}, 'FaceAlpha', 0.6);    
                MPlot.Blocks([stimOnset{sei} stimOffset{sei}], [yLimits(2)*0.95, yLimits(2)*0.97], ...
                                color{3}, 'FaceAlpha', 0.6); 
                xlabel('epoch time (s)');
                ylabel('Trial Nums');  
                title(stims{sei});
                box off  
                hold(h(sei), 'off');
                
                
            end        
    
            annotation(gp(4),'textbox', [0.31, 0.885, 0.1, 0.1], 'String', [stims{1}], 'LineStyle','none');
            annotation(gp(4),'textbox', [0.31, 0.825, 0.1, 0.1], 'String', [stims{1} ' + Opto'], 'LineStyle','none');
            annotation(gp(4),'textbox', [0.75, 0.885, 0.1, 0.1], 'String', [stims{2}], 'LineStyle','none');
            annotation(gp(4),'textbox', [0.75, 0.825, 0.1, 0.1], 'String', [stims{2} ' + Opto'], 'LineStyle','none');
            annotation(gp(4),'textbox', [0.8, 0.77, 0.1, 0.1], 'String', ['recSite = ' recSite], 'LineStyle','none');
            annotation(gp(4),'textbox', [0.4,0.9,0.1,0.1],'String',['Opto' 'UnitNum# ' num2str(unitNum)],...
                'LineStyle','none', 'FontSize', 12);
            hold off    
            saveas(g(4),fullfile(savePath4, ['UnitNum#' num2str(unitNum) '.png']));
        end
       
       
        gMain = figure(100); clf
        nPanels = numel(gp);
        for idx = 1:nPanels
            gSub(idx) = copyobj(gp(idx),gMain);
            set(gSub(idx), 'Position', [0,(idx-1)/nPanels, 1, 1/nPanels]);
        end
        set(gMain, 'Position', [100 80 1200 800])
        annotation(gSub(idx),'textbox', [0.45 0.7 0.3 0.3], 'string', ['UnitNum#' num2str(unitNum) ' quality check'],...
             'LineStyle','none', 'color', 'red', 'Fontsize', 14);
            
        saveas(gMain, fullfile(savePathFinal, ['Plots Unit# ' num2str(unitNum) '.png']));


        
        
    end

    
end

%% plot helper functions
function [f, gp] = plotLinePlotcomparisons(recSite, recSiteType, plotType, plotcolors, sigma)
    
    global windowSize statAlpha meanFR seFR pValue unitNums;
    seS = find(cell2mat(cellfun(@(x) ismember(x, recSiteType), recSite, 'UniformOutput', false)));
    sessUnitNums = unitNums(seS);
    sessMeanFR = meanFR(seS, :,:,:);
    sessSeFR = seFR(seS, :,:,:);
    p = pValue(seS, :,:,:);
    f = figure(); clf
    gp = uipanel('Parent', f, 'BackgroundColor', 'white', 'Position', [0 0 1 1]);
    hold on
    for sei = 1:3 
        h(sei) = subplot(1,3,sei, 'Parent', gp);
        hold(h(sei), 'on');
        
        for sessNum = 1: numel(seS)
            for unitNum = 1: sessUnitNums(sessNum)  
                if sigma ~=0 
                    
                    if p(sessNum,unitNum,sei,1) <sigma | p(sessNum,unitNum,sei,2) <sigma
                        c = plotcolors{sessNum};
                        linewidth = 2;
                        alpha = 0.6;
                    else
                        c = [17 17 17]/255;
                        linewidth = 1;
                        alpha = 0.2;
                    end
                else
                    c = plotcolors{sessNum};
                        linewidth = 2;
                        alpha = 0.3;
                end
                
                s = scatter([1,2], permute(sessMeanFR(sessNum,unitNum,sei,1:2), [4 1 2 3]), 20 ,'o', ...
                     'MarkerEdgeColor', c,'MarkerFaceColor', c , 'MarkerFaceAlpha', alpha);
                seFRunit = permute(sessSeFR(sessNum,unitNum,sei,1:2),[4 1 2 3]);
                err = cell2mat(cellfun(@transpose, seFRunit, 'UniformOutput', false));
    %             errNeg = err(:,1); this was for confidence interval
    %             errPos = err(:,2);
                
              
    %             e = errorbar([1,2],permute(meanFR(sessNum,unitNum,sessNum,1:2),[4 1 2 3]), ...
    %                 errNeg, errPos, 'color', plotcolors{sessNum}); %this was
    %                 for confidence interval
                 e = errorbar([1,2],permute(sessMeanFR(sessNum,unitNum,sei,1:2),[4 1 2 3]),  ...
                    err, 'color', c,'LineWidth', linewidth);
                 set([e.Bar, e.Line], 'ColorType', 'truecoloralpha', 'ColorData', [e.Line.ColorData(1:3); 255*alpha])
            end
            
    %         ylim([-60,100])
        end
        title(h(sei), plotType{sei})
        xlim([0,3]);
        xticks([1,2]);
        ylabel('\DeltaFR(hz)');
        box off
        xticklabels({'Left', 'Right'})
        hold(h(sei), 'off');
    end    
    box off
    hold off; 
end

