close all;
sig = sparam_data.data.S11_dB;
figure;
hold on


sig10 = sig(10, :);
plot(sig10);

filtered_sig10 = lowpass(sig10, 1e-45, 100);
plot(filtered_sig10);
legend;