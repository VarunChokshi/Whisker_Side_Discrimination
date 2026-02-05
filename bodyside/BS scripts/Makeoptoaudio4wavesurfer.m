% 500-ms 20hz sine with 50-ms ramps
duration = 0.5;
constStart = .05;
constEnd = .45;

t = 1/Fs:1/Fs:duration;
y = zeros(size(t));
y(constStart*Fs+1:constEnd*Fs)=1;
y(t<=constStart)=t(t<=constStart)/constStart;
y(t>constEnd)=1-(t(t>constEnd)-constEnd)/(duration-constEnd);

y1=arrayfun(@(x) (sin(2*pi*20*x-pi/2)+1)/2, t);
y2=arrayfun(@(x, x1) conv(x,x1), y,y1);
figure;plot(t,y2)

audiowrite('500ms20hzSinPulse_w_50msRamp.wav',y2,Fs)


% 800-ms hold with 250-ms ramps
duration = 0.8;
constStart = 0;
constEnd = .55;

t = 1/Fs:1/Fs:duration;
y = zeros(size(t));
y(constStart*Fs+1:constEnd*Fs)=1;
y(t<=constStart)=t(t<=constStart)/constStart;
y(t>constEnd)=1-(t(t>constEnd)-constEnd)/(duration-constEnd);


figure;plot(t,y)

audiowrite('800msHoldPulse_w_250msRampDown.wav',y,Fs)

% 800-ms 40hz sine with 100-ms ramps
duration = 0.8;
constStart = 0;
constEnd = 0.7;

t = 1/Fs:1/Fs:duration;
y = zeros(size(t));
y(constStart*Fs+1:constEnd*Fs)=1;
y(t<=constStart)=t(t<=constStart)/constStart;
y(t>constEnd)=1-(t(t>constEnd)-constEnd)/(duration-constEnd);

y1=arrayfun(@(x) (sin(2*pi*40*x-pi/2)+1)/2, t);
y2=arrayfun(@(x, x1) conv(x,x1), y,y1);
figure;plot(t,y2)

audiowrite('800ms40hzSinPulse_w_100msRamp.wav',y2,Fs)

% 2900-ms 40hz sine with 200-ms ramps
Fs = 44100;
duration = 2.9;
constStart = 0;
constEnd = 2.7;

t = 1/Fs:1/Fs:duration;
y = zeros(size(t));
y(constStart*Fs+1:constEnd*Fs)=1;
y(t<=constStart)=t(t<=constStart)/constStart;
y(t>constEnd)=1-(t(t>constEnd)-constEnd)/(duration-constEnd);

y1=arrayfun(@(x) (sin(2*pi*40*x-pi/2)+1)/2, t);
y2=arrayfun(@(x, x1) conv(x,x1), y,y1);
figure;plot(t,y2)

audiowrite('2900ms40hzSinPulse_w_200msRamp.wav',y2,Fs)
