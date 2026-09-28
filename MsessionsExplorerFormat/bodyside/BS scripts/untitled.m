clear all
close all
[readPaths, seDir, seNames] = MBrowse.Files([], 'Select source SEs');
sigma = 0.025;

for sessNum = 1:size(readPaths,1)
    clearvars -except sessNum readPaths seDir seNames sigma;
    seParts = strsplit(seNames{sessNum}, ' ');
    rootParts = strsplit(seDir, '\');
    rootPath = fullfile(rootParts{1:end-2});
    savePath = fullfile(rootPath,'Figures', seNames{sessNum});
    if ~exist('savePath', 'Dir')
        mkdir(savePath)
    end

    load(readPaths{sessNum});
    fprintf('%s\n\n', readPaths{sessNum});
    tRef = se.GetReferenceTime();
    check = diff(tRef);

    if any(check<0)
        disp('tRefs are not monotonically increasing');
    end
    seRight = getTrials(se, {'RRN', 'RRC','RLN', 'RLC', 'RNN', 'RNC'});
    seLeft = getTrials(se, {'LRN', 'LRC','LLN', 'LLC', 'LNN', 'LNC'});
    seRightCorrect = getTrials(se, {'RRN', 'RRC'});
    seLeftCorrect = getTrials(se, {'LLN','LLC'});

    seRightIncorrect = getTrials(se, {'RLN', 'RLC'});
    seLeftIncorrect = getTrials(se, {'LRN', 'LRC'});

    seRightNoLick = getTrials(se, {'RNN', 'RNC'});
    seLeftNoLick = getTrials(se, {'LNN', 'LNC'});
    
    rightSpikes = seRight.GetTable('spikeTime');
    rightstimTimes = cell2mat(seRight.GetColumn('behavTime', {'rightOnset', 'rightOffset'}));
    leftstimTimes = cell2mat(seLeft.GetColumn('behavTime', {'leftOnset', 'leftOffset'}));
    stimOnset = {leftstimTimes, rightstimTimes};
    seSRight = {seRightCorrect, seRightIncorrect, seRightNoLick};
    seSLeft = {seLeftCorrect, seLeftIncorrect, seLeftNoLick};
    recSite = seRight.userData.sessionInfo.recSite;
    seS = {seRightCorrect, seRightIncorrect, seRightNoLick;seLeftCorrect, seLeftIncorrect, seLeftNoLick};
    stims = {'Left Stim', 'Right Stim'};
    
    
    for unitNum =2:size(rightSpikes,2)
        clearvars unitSpikes;
        close all
        g =figure(unitNum);clf;
        hold on
        color = {'g','r','k'};
        for sei = 1:2
            h(sei) = subplot(1,2,sei);
            hold(h(sei), 'on');
            for result = 1:3
                seDup = seS{sei, result}.Duplicate();
                
                spikeTimes = seDup.GetTable('spikeTime');
                ind = 1:height(spikeTimes);
                bins{sei, result} = -0.5:0.0025:2.5;
                spikes = seDup.ResampleEventTimes('spikeTime', bins{sei, result}, 'Normalization', 'countdensity');
                for i = 1 : width(spikes)
                        spikes.(i) = cellfun(@(x) MNeuro.Filter1(x, 1/0.0025, 'gaussian', sigma), spikes.(i), 'UniformOutput', false);
                end
                
                unitSpikes = spikes(ind,unitNum);           
                unitSpikes = table2cell(unitSpikes);
                for i = 1:height(unitSpikes)
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
                maxFR{sei, result} = max(ciFR{sei, result}(2,:))+1;
                
                        
            
                plot(bins{sei}(1:size(meanFR{sei, result},2)),meanFR{sei, result}, color{result}, 'LineWidth', 1);
                MPlot.ErrorShade(bins{1}(1:size(meanFR{sei, result},2)), meanFR{sei, result}, ...
                        ciFR{sei, result}(2,:),ciFR{sei, result}(1,:), 'color',color{result}, 'Alpha', 0.3, 'IsRelative', false);
            end

            xlim([-0.5,2.5]);    
            
            ylim([0,max(cell2mat(maxFR), [], 'all')]); 
            yLimits = get(gca,'YLim');
            MPlot.Blocks(stimOnset{sei}(end-5,:), [max(cell2mat(maxFR), [], 'all')*0.98,max(cell2mat(maxFR), [], 'all')], ...
                            color{3}, 'FaceAlpha', 0.6);       
            xlabel('epoch time (s)');
            ylabel('FR');  
            title(stims{sei});
            box off  
            hold(h(sei), 'off');
            
            
        end        
        hold off    
        annotation('textbox', [0.7, 0.8, 0.1, 0.1], 'String', ['recSite = ' recSite])
        saveas(g,fullfile(savePath, ['UnitNum#' num2str(unitNum) '.png']));
    end
end











%Plot all Right Correct trials
function seIn = getTrials(se, input)
    seIn = se.Duplicate();    
    trialsToKeep = seIn.GetColumn('behavValue', input);
    keepTrials = find(~sum(trialsToKeep, 2));
    seIn.RemoveEpochs(keepTrials);
end

