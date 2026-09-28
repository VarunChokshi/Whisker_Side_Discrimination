% load se

load('I:\VC03_RoboKO\VC0301\StimSEs_2_5msFR\VC030407 2023-09-07a se.mat');
% plot first 10 trials worth of stims and spike data and amplifuer data
se.SliceSession(0, 'absolute');

% get channels for each spike
qualMetrics = se.userData.spikeInfo.quality_metrics;
spikeData = se.GetTable('spikeTime');
adcData = se.GetTable('adc');
lfpData = se.GetTable('LFP');
limit = 60000;
timeLimit = 60000/1000;

chanMap = se.userData.sessionInfo.channel_map.chanMap;



for i = 1:numel(spikeData)
    figure(i);clf;
    channelID = qualMetrics.ch(i)+1;
    lfpind = find(chanMap == channelID);
    lfpChan= lfpData{1,lfpind+1}{1}(1:limit);
    lfpTime = lfpData{1,1}{1}(1:limit);
    plot(lfpTime, lfpChan);
    adcRight = adcData.rightStim;
    adcLeft = adcData.leftStim;
    adcTime = adcData.time;
    hold on 
    plot(adcTime{1}(1:limit), adcRight{1}(1:limit)*200000+300);
    plot(adcTime{1}(1:limit), adcLeft{1}(1:limit)*200000+300);
    plot(spikeData{1,i}{1}, 200*ones(size(spikeData{1,i}{1})), '.');
    xlim([lfpTime(1) lfpTime(end)])
end