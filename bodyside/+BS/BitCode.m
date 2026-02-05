
classdef BitCode
    
    methods(Static)
        
        
        % ComputeBitCode
        % Use bitcode to get trial numbers: Bcontrol sends bitcode to Intan through
        % digSignal channel
        % Reference: cat_session6 and Tongue.Preprocess.ComputeDelimiter
        function result = ComputeBitCode(digSignal, sampleRate)
            
            % Generate timestamps based on sampling rate
            time = (0:numel(digSignal)-1)' / sampleRate;

            % Find potential trial onsets
            trialStarts =zeros(size(digSignal, 1),1);
            ones = find(digSignal(:,1)==1); %Find indices and values of nonzero elements 
            counter=0;
            trialNumHexDec = cell(1,numel(trialStarts(trialStarts==1)));
            HexDecOnsetTime = [];

            for i=1:numel(ones)
                if i == 1
                    tmp = ones(i+1)-ones(i);
                    ind = ones(i);
                else
                    tmp = ones(i) - ones(i-1);
                    ind = ones(i);
                end
                if tmp > 10000  % Inter-trial interval is larger than 1 sec. If tmp is lager than 10000 (~0.33 sec), it may be trial onsets.
                    trialStarts(ind) = 1;
                    counter = counter+1;
                    trialNumHexDec{counter} = digSignal(ind-0.002*sampleRate:ind+0.07*sampleRate, 1);
                    HexDecOnsetTime(counter) = time(ind);
                elseif i == numel(ones)
                    continue
                end
            end 

            % Find potential trial numbers
            trialNums = []; 
             for i=1:numel(trialNumHexDec)
                 trialNums(i) = BS.BitCode.read_bit_codeEF(trialNumHexDec{i}, sampleRate, 0.002, 0.005); % bitTime =0.002, gapTime =0.005
             end
            trialNumHexDec = {trialNumHexDec};

            
            refFrame1 = trialNums(1:2:length(trialNums));
            refFrame2 = trialNums(2:2:length(trialNums));
            trialNums1= diff(refFrame1)-2;
            trialNums2= diff(refFrame2)-2;


            % Remove incorrect trial numbers: Trial numbers should be an increment. 
            if isempty(find(trialNums1(1:10)))
                trialNums(1:numel(trialNums)) = trialNums(1):1:(numel(trialNums)+trialNums(1)-1);
                trialTimesToCorrect = refFrame2;
            elseif isempty(find(trialNums2(1:10)))
                trialNums(1:1:numel(trialNums)) = trialNums(2)-1:1:(numel(trialNums))+(trialNums(2)-1)-1;
                trialTimesToCorrect = refFrame1;
            else
                error('trialNums are non-sensical')
            end
            if trialNums(1) == 0
                trialNums = trialNums+1;
            end
            binTrialNums = dec2bin(trialNums);
            flippedBinTrialNums = fliplr(binTrialNums);
            flippedBinTrialNums = str2num(flippedBinTrialNums);


            zeroNum=9-ceil(log10(flippedBinTrialNums));
            x = ceil(log10(flippedBinTrialNums));
            zeroNum(x == log10(flippedBinTrialNums)) = zeroNum(x == log10(flippedBinTrialNums))+1;

            timeTrialNumber = zeros(size(trialStarts));
            timeWithinTrial = zeros(size(trialStarts));
            startInds = find(trialStarts==1);
            
            for i=1:numel(startInds)
                if i+1 > numel(startInds) %if this is the last trial of the session
                    if ismember(trialNums(i), trialTimesToCorrect)
                        timeTrialNumber(startInds(i)-140*zeroNum(i):end) = trialNums(i);
                        timeWithinTrial(startInds(i)-140*zeroNum(i):end) =...
                            0:1/sampleRate:((numel(timeWithinTrial(startInds(i)-140*zeroNum(i):end-1))/sampleRate));
                    else
                        timeTrialNumber(startInds(i)-140*zeroNum(i):end) = trialNums(i);
                        timeWithinTrial(startInds(i)-140*zeroNum(i):end) =...
                            0:1/sampleRate:((numel(timeWithinTrial(startInds(i)-140*zeroNum(i):end-1))/sampleRate));
                    end
                else 
                    timeTrialNumber(startInds(i)-140*zeroNum(i):startInds(i+1)-1) = trialNums(i);
                    timeWithinTrial(startInds(i)-140*zeroNum(i):startInds(i+1)-1) =...
                        0:1/sampleRate:(numel(timeWithinTrial(startInds(i)-140*zeroNum(i):startInds(i+1)-1))-1)/sampleRate;
                end
            end

            %NOTE: the length of a trial that is determined here will not be identical
            %to the length of the same trial in the B-control data. There is aprox
            %0.7-1.0s that is unaccountend for in the B-control data between
            %consecutive trials that gets lumped in with the previous trial here. This
            %does not affect the stimonset time or the trial start time, just the total
            %trial length.

            % Output: HexDec info and trialNums
            result.HexDecOnsetTime = HexDecOnsetTime;
            result.trialNumHexDec = trialNumHexDec;
            result.trialNums = trialNums;

            end

        function trial_num = read_bit_codeEF(x, sampleRate, bitTime, gapTime)
            % 
            % sampleRate in Hz.
            % bitTime, gapTime, preTime all in seconds
            %
            % updated by EF 12/14
            %

            % x = session.HexDec.trialNumHexDec{1};
            % sampleRate = 20000;
            % bitTime =0.002;
            % gapTime =0.005;

            nbits = 10;

            if length(x) > 0.072*sampleRate % Bit code happens in first 0.072 s now.
                x = x(1:(72/1000*sampleRate));
            end

            timeFromEdgeInS = 0.002;
            plusTimeInS = 0.0035;
            minusTimeInS = 0.0005;

            samplesFromEdge = timeFromEdgeInS*sampleRate;
            minusSamples = minusTimeInS*sampleRate;
            plusSamples = plusTimeInS*sampleRate;

            bitInd = zeros(1,nbits);

            bitInd(1) = 1+samplesFromEdge;
            bitInd(2) = 1+samplesFromEdge + (bitTime+gapTime)*sampleRate;
            bitInd(3) = 1+samplesFromEdge + 2*(bitTime+gapTime)*sampleRate;
            bitInd(4) = 1+samplesFromEdge + 3*(bitTime+gapTime)*sampleRate;
            bitInd(5) = 1+samplesFromEdge + 4*(bitTime+gapTime)*sampleRate;
            bitInd(6) = 1+samplesFromEdge + 5*(bitTime+gapTime)*sampleRate;
            bitInd(7) = 1+samplesFromEdge + 6*(bitTime+gapTime)*sampleRate;
            bitInd(8) = 1+samplesFromEdge + 7*(bitTime+gapTime)*sampleRate;
            bitInd(9) = 1+samplesFromEdge + 8*(bitTime+gapTime)*sampleRate;
            bitInd(10) = 1+samplesFromEdge + 9*(bitTime+gapTime)*sampleRate;

            bitInd = int16(bitInd);

            bitIndWindow = zeros(round(plusSamples)+round(minusSamples)+1,length(bitInd));

            for k=1:length(bitInd)
                bitIndWindow(:,k) = (bitInd(k)-minusSamples):(bitInd(k)+plusSamples);
            end

            bitIndWindow = int16(round(bitIndWindow));
            % figure; plot(x); hold on
            % plot(bitInd, repmat(5,size(bitInd)),'r*')

            trial_num = BS.BitCode.binvec2dec(max(x(bitIndWindow)));
        end

        function out = binvec2dec(vec)
            % BINVEC2DEC Convert binary vector to decimal number.
            %
            %    BINVEC2DEC(B) interprets the binary vector B and returns the
            %    equivalent decimal number.  The least significant bit is 
            %    represented by the first column.
            %
            %    Non-zero values will be mapped to 1, e.g. [1 2 3 0] maps
            %    to [1 1 1 0].
            % 
            %    Note: The binary vector cannot exceed 52 values.
            %
            %    Example:
            %       binvec2dec([1 1 1 0 1]) returns 23
            %
            %    See also DEC2BINVEC, BIN2DEC.
            %

            %    MP 11-11-98
            %    Copyright 1998-2003 The MathWorks, Inc.
            %    $Revision: 1.7.2.4 $  $Date: 2003/08/29 04:40:41 $

            % Error if B is not defined.
            %
            % **** DHO, took from R2007A DAQ Toolbox ****
            %
            if isempty(vec)
               error('daq:binvec2dec:argcheck', 'B must be defined.  Type ''daqhelp binvec2dec'' for more information.');
            end

            % convert vec from unit8 to double YT 03/19
            vec = double(vec);

            % Error if B is not a double.
            if (~isa(vec, 'double') && ~isa(vec, 'logical'))
               error('daq:binvec2dec:argcheck', 'B must be a binvec.');
            end

            % Non-zero values map to 1.
            vec = vec~=0;

            % Convert the binvec [0 0 1 1] to a binary string '1100';
            h = deblank(num2str(fliplr(vec)'))';

            % Convert the binary string to a decimal number.
            out = bin2dec(h);
        end
        
    end
end