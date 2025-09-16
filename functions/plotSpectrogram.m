function plotSpectrogram(sParam, N, M, time)

freq1 = [21.5 26.5];
freq2 = [23 25];


xT1 = 22:26;
xT2 = 23:0.5:25;


cameraAng = [135 45];

z = [-25 0];

f = sParam(1).Frequencies;
[A, P] = getData(sParam,N,M);
[T, F] = meshgrid(time,f./1e9);
T = hours(T);

f = figure("Color",[1,1,1], "Position",[150 600 1400 380]);
subplot(1,2,1);
surface(F,T,A, 'EdgeColor','none', "FaceColor","flat")
colormap jet; colorbar
xlim(freq1); zlim(z); clim(z); 
xticks(xT1); yticks((0:5:100)); zticks(-25:5:0);
set(gca,"View",cameraAng)
if cameraAng(1) >90
    set(gca,"XDir","reverse");
end
title("Reflection Amplitude"); xlabel("Frequency, GHz"); ylabel("Time, hours"); zlabel('Reflection Coefficient, dB');
grid

subplot(1,2,2);
surface(F,T,P, 'EdgeColor','none', "FaceColor","flat")
colormap jet; colorbar("Limits",[-180 180],"Ticks",-180:60:180); 
xlim(freq1); zlim([-180 180]), clim([-180 180]); ylim([0 max(T,[],'all')])
xticks(xT1); yticks(0:5:100);
title("Reflection Coefficient - Phase"); xlabel("Frequency, GHz"); ylabel("Time, hours"); zlabel('Angle, degree');


%% ================
f = figure("Color",[1,1,1], "Position",[150 600 1400 380]);
subplot(1,2,1);
surface(F,T,A, 'EdgeColor','none', "FaceColor","flat")
colormap jet; 
xlim(freq2); zlim(z); clim(z); %ylim([0 8]);
xticks(xT2); yticks((0:5:100)); zticks(-25:5:0);
set(gca,"View",cameraAng)
if cameraAng(1) >90
    set(gca,"XDir","reverse");
end
title("Reflection Coefficient - Amplitude"); xlabel("Frequency, GHz"); ylabel("Time, hours"); zlabel('Reflection Coefficient, dB');
grid on;
c = colorbar; 
 c.Label.String = "Reflection Coefficient [dB]";

subplot(1,2,2);
surface(F,T,P, 'EdgeColor','none', "FaceColor","flat")
colormap jet; c = colorbar("Limits",[-180 180],"Ticks",-180:60:180);  c.Label.String = "Phase [degree]";
xlim(freq2); zlim([-180 180]), clim([-180 180]); ylim([0 max(T,[],'all')]) %ylim([0 8])%
xticks(xT2); yticks(0:5:100);
title("Reflection Phase"); xlabel("Frequency, GHz"); ylabel("Time, hours"); zlabel('Angle, degree');
end

