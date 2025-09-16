function plotFrequencies(sParam, n, m, time, freq)

time = hours(time);
F = sParam(1).Frequencies;
[index, ~] = find(F == freq);
[amp, phase] = getData(sParam, n, m);

amp = amp(index,:);
phase = phase(index,:);

figure("Color",[1,1,1], "Position",[150 600 1400 380]);
subplot(1,2,1)
    plot(time, amp, "LineWidth",1); hold on;
title("Reflection Coefficient - Amplitude");
xlabel('Time, hours');
ylabel('Reflection Coefficient [dB]');
grid
legend(cellstr(string(freq./1e9) + " GHz"), Location="bestoutside");
ylim([-27 2]); yticks(-25:5:0);

subplot(1,2,2)
plot(time, phase, "LineWidth",1); hold on;
title("Reflection Coefficient - Phase");
xlabel('Time [h]');
ylabel('Phase [degree]');
grid
legend(cellstr(string(freq./1e9) + " GHz"), Location="bestoutside");
ylim([-190 190]);
yticks(-180:30:180);