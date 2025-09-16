function plotFrequenciesandTemp(sParam,n,m, sParamDateTime, freq, tempDateTime, tempData, channels, channels2, timelimit)


F = sParam(1).Frequencies;
[index, ~] = find(F == freq);
[amp, phase] = getData(sParam, n, m);

amp = amp(index,:);
phase = phase(index,:);

%% Temperature
templimit = [-5 40];
% dateVec = datetime(tempdata.Date, 'InputFormat', 'yyyy/MM/dd');
% 
% % 시간을 duration으로 변환 (엑셀 기준 하루=1)
% timeVec = duration(tempdata.Time);  % 시간 단위로 변환

% datetime 조합
% datetime_values = dateVec + timeVec;
% datetime_values = datetime(tempdata(:,1), 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
% 첫 16개의 데이터 선택
% datetime_subset = datetime_values(:);
% datetime_subset = datetime_subset -min(datetime_subset);

% 플로팅할 채널 선택 (CH01~CH16)
channel_names = sprintfc('CH%02d', channels);

% 숫자 데이터 변환 (table2array 사용)
% channel_data = str2double(tempdata(:, 2:17));
% yyaxis right
% for i = 1:length(channels)
%     plot(hours(datetime_subset), channel_data(:,i), "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color','b'); hold on;
% end
% ylabel('Temperature, C');


%% Plot
figName = sprintf('S_{%d%d}', n, m); 
figH = 380;        % 창 높이
gap  = 70;         % 창 간격
figure('Name', figName, 'NumberTitle','off', "Color",[1,1,1], "Position",[150 , 600 - (n-1)*(figH+gap) , 1400 , figH]);
subplot(1,2,1)
%plot(hours(time), amp, "LineWidth",1); hold on;
plot(sParamDateTime, amp, 'LineWidth',1);
xlabel('Time, hours');
ylabel('Reflection Coefficient, dB');
ylim([-30 0]);
%xlim(timelimit);
yyaxis right
% plot(temptime, temp, "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color','b');
for i = 1:length(channels)
    % plot(hours(datetime_subset), channel_data(:,channels(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color','#16B8F1'); hold on;
    if n == i
        plot(tempDateTime, tempData(:,channels(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'o', 'Color','#16B8F1','MarkerIndices', 1:150:numel(tempDateTime)); hold on;
    else
        % plot(tempDateTime, tempData(:,channels(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'x', 'Color','#16B8F1','MarkerIndices', 1:150:numel(tempDateTime)); hold on;
    end
end
for i = 1:length(channels2)
    % plot(hours(datetime_subset), channel_data(:,channels2(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color', 'r'); hold on;
    if n == i
        plot(tempDateTime, tempData(:,channels2(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'o', 'Color', 'r','MarkerIndices', 1:150:numel(tempDateTime)); hold on;
    else
        % plot(tempDateTime, tempData(:,channels2(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'x', 'Color', 'r','MarkerIndices', 1:150:numel(tempDateTime)); hold on;
    end
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
% xticks(0:2:hours(time(end)));
ax = gca;                                          % 현재 축
ax.XAxis.TickLabelFormat = 'HH:mm';                % 시:분

grid
legend(cellstr(string(freq./1e9) + " GHz"), Location="bestoutside"); hold on;
% legend(['Ambient Temp', 'Sample Temp'], Location="bestoutside");

subplot(1,2,2)
%plot(hours(time), phase, "LineWidth",1); hold on;
plot(sParamDateTime, phase, 'LineWidth',1);
xlabel('Time, hours');
ylabel('Phase, degree');
ylim([-350 190]);
yticks(-180:30:180);
%xlim(timelimit);
yyaxis right
% plot(temptime, temp, "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color','b', 'DisplayName',['Ambient Temp', 'Sample Temp']);
for i = 1:length(channels)
    % plot(hours(datetime_subset), channel_data(:,channels(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color','#16B8F1'); hold on;
    if n == i
        plot(tempDateTime, tempData(:,channels(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'o', 'Color','#16B8F1','MarkerIndices', 1:150:numel(tempDateTime)); hold on;
    else
        % plot(tempDateTime, tempData(:,channels(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'x', 'Color','#16B8F1','MarkerIndices', 1:150:numel(tempDateTime)); hold on;
    end
end
for i = 1:length(channels2)
    % plot(hours(datetime_subset), channel_data(:,channels2(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'none', 'Color', 'r'); hold on;
    if n == i
        plot(tempDateTime, tempData(:,channels2(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'o', 'Color', 'r','MarkerIndices', 1:150:numel(tempDateTime)); hold on;
    else
        % plot(tempDateTime, tempData(:,channels2(i)), "LineWidth",1,'lineStyle', '--', 'Marker', 'x', 'Color', 'r','MarkerIndices', 1:150:numel(tempDateTime)); hold on;
    end
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
% xticks(0:2:hours(time(end)));
ax = gca;                                          % 현재 축
ax.XAxis.TickLabelFormat = 'HH:mm';                % 시:분

grid
legend(cellstr(string(freq./1e9) + " GHz"), Location="bestoutside");

