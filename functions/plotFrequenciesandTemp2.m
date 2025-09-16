function plotFrequenciesandTemp2(sParam, n, m, time, freq, tempdata, channels, channels2, timelimit)

F = sParam(1).Frequencies;
[index, ~] = find(F == freq);
[amp1, phase1] = getData(sParam, 1, 1);

amp1 = amp1(index,:);
phase1 = phase1(index,:);

[amp2, phase2] = getData(sParam, 2, 2);

amp2 = amp2(index,:);
phase2 = phase2(index,:);
%% Temperature
templimit = [-5 40];

% 시간을 duration으로 변환 (엑셀 기준 하루=1)

% datetime 조합
% datetime_values = datetime(tempdata(:,2), 'InputFormat','yyyy-MM-dd a h:mm:ss','Locale','ko_KR' ); 
datetime_values = datetime(string(tempdata(:,1)) + " " + string(tempdata(:,2)), 'InputFormat','yyyy/MM/dd HH:mm:ss' ); 

% 첫 16개의 데이터 선택
datetime_subset = datetime_values(:);
datetime_subset = datetime_subset -min(datetime_subset);

% 플로팅할 채널 선택 (CH01~CH16)
channel_names = sprintfc('CH%02d', channels);

% 숫자 데이터 변환 (table2array 사용)
channel_data = str2double(tempdata(:, 3:18));
% yyaxis right
% for i = 1:length(channels)
%     plot(hours(datetime_subset), channel_data(:,i), "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color','b'); hold on;
% end
% ylabel('Temperature, C');


%% Plot_port1

figure("Color",[1,1,1], "Position",[150 250 1400 380]);
subplot(1,2,1)
plot(hours(time), amp1, "LineWidth",1); hold on;
xlabel('Time, hours');
ylabel('Reflection Coefficient, dB');
ylim([-50 0]);
%xlim(timelimit);
yyaxis right
% plot(temptime, temp, "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color','b');
for i = 1:length(channels)
    plot(hours(datetime_subset), channel_data(:,channels(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color','#16B8F1'); hold on;
end
for i = 1:length(channels2)
    plot(hours(datetime_subset), channel_data(:,channels2(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color', 'r'); hold on;
end

ylabel('Temperature, C');
ylim(templimit)
yticks(-10:5:50);
% ycolor('#16B8F1');
title("Reflection Coefficient - Amplitude")
% xlim([0 5])
% xlim([0 hours(time(end))+1])

% xlim([hours(1.5) hours(6)]);
% xlim([0 hours(time(end))]);
xticks(0:2:hours(time(end)));
grid
legend(cellstr(string(freq./1e9) + " GHz"), Location="bestoutside"); hold on;
% legend(['Ambient Temp', 'Sample Temp'], Location="bestoutside");

subplot(1,2,2)
plot(hours(time), phase1, "LineWidth",1); hold on;
xlabel('Time, hours');
ylabel('Phase, degree');
ylim([-350 190]);
yticks(-180:30:180);
%xlim(timelimit);
yyaxis right
% plot(temptime, temp, "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color','b', 'DisplayName',['Ambient Temp', 'Sample Temp']);
for i = 1:length(channels)
    plot(hours(datetime_subset), channel_data(:,channels(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color','#16B8F1'); hold on;
end
for i = 1:length(channels2)
    plot(hours(datetime_subset), channel_data(:,channels2(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color', 'r'); hold on;
end

title("Reflection Coefficient - Phase")
ylabel('Temperature, C');
ylim(templimit);
yticks(-10:5:50);
% ycolor('#16B8F1');

% xlim([0 5])
% xlim([0 hours(time(end))+1])

% xlim([hours(1.5) hours(6)]);
% xlim([0 hours(time(end))]);
xticks(0:2:hours(time(end)));
grid
legend(cellstr(string(freq./1e9) + " GHz"), Location="bestoutside");

%% Plot_port2

figure("Color",[1,1,1], "Position",[150 250 1400 380]);
subplot(1,2,1)
plot(hours(time), amp2, "LineWidth",1); hold on;
xlabel('Time, hours');
ylabel('Reflection Coefficient, dB');
ylim([-50 0]);
%xlim(timelimit);
yyaxis right
% plot(temptime, temp, "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color','b');
for i = 1:length(channels)
    plot(hours(datetime_subset), channel_data(:,channels(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color','#16B8F1'); hold on;
end
for i = 1:length(channels2)
    plot(hours(datetime_subset), channel_data(:,channels2(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color', 'r'); hold on;
end

ylabel('Temperature, C');
ylim(templimit)
yticks(-10:5:50);
% ycolor('#16B8F1');
title("Reflection Coefficient - Amplitude")
% xlim([0 5])
% xlim([0 hours(time(end))+1])

% xlim([hours(1.5) hours(6)]);
% xlim([0 hours(time(end))]);
xticks(0:2:hours(time(end)));
grid
legend(cellstr(string(freq./1e9) + " GHz"), Location="bestoutside"); hold on;
% legend(['Ambient Temp', 'Sample Temp'], Location="bestoutside");

subplot(1,2,2)
plot(hours(time), phase2, "LineWidth",1); hold on;
xlabel('Time, hours');
ylabel('Phase, degree');
ylim([-350 190]);
yticks(-180:30:180);
%xlim(timelimit);
yyaxis right
% plot(temptime, temp, "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color','b', 'DisplayName',['Ambient Temp', 'Sample Temp']);
for i = 1:length(channels)
    plot(hours(datetime_subset), channel_data(:,channels(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color','#16B8F1'); hold on;
end
for i = 1:length(channels2)
    plot(hours(datetime_subset), channel_data(:,channels2(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color', 'r'); hold on;
end

title("Reflection Coefficient - Phase")
ylabel('Temperature, C');
ylim(templimit);
yticks(-10:5:50);
% ycolor('#16B8F1');

% xlim([0 5])
% xlim([0 hours(time(end))+1])

% xlim([hours(1.5) hours(6)]);
% xlim([0 hours(time(end))]);
xticks(0:2:hours(time(end)));
grid
legend(cellstr(string(freq./1e9) + " GHz"), Location="bestoutside");


%% output

T = table(hours(datetime_subset), channel_data(:,channels), channel_data(:,channels2), 'VariableNames', {'time_temperature', 'temperature', 'temperature_amb'});
writetable(T, 'Temperature.csv');   % 기본이 쉼표 구분\
A = table(transpose(hours(time)), transpose(amp1(1,:)), transpose(phase1(1,:)), transpose(amp1(2,:)), transpose(phase1(2,:)),...
    transpose(amp1(3,:)), transpose(phase1(3,:)), transpose(amp1(4,:)), transpose(phase1(4,:)),...
    transpose(amp1(5,:)), transpose(phase1(5,:)),...
    'VariableNames', {'time_Sparam', 'Amplitude 23.5 GHz [-dB]', 'Phase 23.5 GHz [deg]', 'Amplitude 24 GHz [-dB]', 'Phase 24 GHz [deg]',...
    'Amplitude 24.2 GHz [-dB]', 'Phase 24.2 GHz [deg]', 'Amplitude 24.4 GHz [-dB]', 'Phase 24.4 GHz [deg]', 'Amplitude 25 GHz [-dB]', 'Phase 25 GHz [deg]'});
A2= table(transpose(hours(time)), transpose(amp2(1,:)), transpose(phase2(1,:)), transpose(amp2(2,:)), transpose(phase2(2,:)),...
    transpose(amp2(3,:)), transpose(phase2(3,:)), transpose(amp2(4,:)), transpose(phase2(4,:)),...
    transpose(amp2(5,:)), transpose(phase2(5,:)),...
    'VariableNames', {'time_Sparam', 'Amplitude 23.5 GHz [-dB]', 'Phase 23.5 GHz [deg]', 'Amplitude 24 GHz [-dB]', 'Phase 24 GHz [deg]',...
    'Amplitude 24.2 GHz [-dB]', 'Phase 24.2 GHz [deg]', 'Amplitude 24.4 GHz [-dB]', 'Phase 24.4 GHz [deg]', 'Amplitude 25 GHz [-dB]', 'Phase 25 GHz [deg]'});
writetable(A, 'Sparam_port1.csv');
writetable(A2, 'Sparam_port2.csv');

