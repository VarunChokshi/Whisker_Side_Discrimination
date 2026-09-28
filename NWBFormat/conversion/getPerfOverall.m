function perf = getPerfOverall(se)
    % perf = [correctFrac, incorrectFrac, missFrac, leftStimAmp, leftDur, leftStimFreq,  ...
    % rightStimFreq, rightStimAmp, rightStimDur, sideAssist, leftStimProb, maskingFlash, PSNLT]
    behavData = se.GetTable('behavValue');
    stimRight = behavData.rightStimType{end};
    stimLeft = behavData.leftStimType{end};

    responses = cell2mat(behavData.response);
    % remove abort trials
    abortTrials = responses ==3;
    behavData(abortTrials,:) = [];

     %remove catch trials
    result = behavData.result;
    responses = cell2mat(behavData.response);
    catchTrials = isnan(result) & responses~=0;
    behavData(catchTrials,:) = [];

    % remove optoTrials
    tt = fieldnames(se.userData.bctData);
    perf.taskName = tt{1}(1:9);

    if strcmp(perf.taskName, 'bodyside6')
        trialType = behavData.trialType;
        isOpto = cell2mat(cellfun(@(x) sum(ismember(x,'Opto'))>=4, trialType, 'UniformOutput', false));
        if ~isempty(find(isOpto))
            perf.isOpto =1;
        else
            perf.isOpto =0;
        end
        behavData(isOpto,:) = [];
    end

    %separate miss trials
    responses = cell2mat(behavData.response);
    missTrials = find(responses==0);

    missData = behavData(missTrials, :);
    behavData(missTrials,:) = [];

    result = behavData.result;

    correctTrials = find(result);
    try
        incorrectTrials = find(~result);
    catch
        keyboard;
    end

    missTrials = find(~cell2mat(missData.response));

    perf.correctFrac = height(correctTrials)/(height(correctTrials)+height(incorrectTrials));
    perf.incorrectFrac = height(incorrectTrials)/(height(correctTrials)+height(incorrectTrials));

    perf.missFrac = height(missTrials)/(height(missTrials)+height(correctTrials)+height(incorrectTrials));

    perf.rightStim = cellstr(stimRight);

    if sum(ismember(stimRight, 'Cyc'))>2
        [perf.stimRightAmp, perf.stimRightFreq, perf.stimRightDur] = bodyside5Stims(stimRight);
        [perf.stimLeftAmp, perf.stimLeftFreq, perf.stimLeftDur]  = bodyside5Stims(stimLeft);
    else
        [perf.stimRightAmp, perf.stimRightFreq, perf.stimRightDur] = bodyside6Stims(stimRight);
        [perf.stimLeftAmp, perf.stimLeftFreq, perf.stimLeftDur] = bodyside6Stims(stimLeft);
    end
    perf.leftStim = cellstr(stimLeft);

    perf.sideAssist =  ~strcmp(se.userData.bctData.TrialTypeSection_SideAssist, 'No');

    if isfield(se.userData.bctData, 'TrialTypeSection_MaskingFlash')
        perf.maskingFlash = se.userData.bctData.TrialTypeSection_MaskingFlash;
    else
        perf.maskingFlash = 0;
    end

    if isfield(se.userData.bctData, 'TrialTypeSection_PreStimNoLickTime')
        perf.PSNLT = se.userData.bctData.TrialTypeSection_PreStimNoLickTime;
    else
        perf.PSNLT = 0.01;
    end
    perf.leftStimProb = se.userData.bctData.TrialTypeSection_LeftTrialProb;

end

function [amp, freq, dur] = bodyside5Stims(stim)

    qPos = find(ismember(stim, 'q'));
    freq = str2num(stim(qPos+1:qPos+2));

    dur = str2num(stim(end))*1000/freq; % ms

    mpos = find(ismember(stim, 'm'));
    amp = str2num(stim(mpos+4:mpos+6));
    if amp==0
        amp = 1000;
    end

end

function [amp, freq, dur] = bodyside6Stims(stim)

    qPos = find(ismember(stim, 'q'));
    freq = str2num(stim(qPos+1:qPos+2));

    dur = str2num(stim(end-2:end));
    if dur == 0
        dur = 1000; %ms
    end

    mpos = find(ismember(stim, 'm'));
    amp = str2num(stim(mpos+4:mpos+6));
    if amp==0
        amp = 1000;
    end

end
