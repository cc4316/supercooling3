function [Amp, Phase] = getData(sparam, n, m)
% Extracts the Snm parameters in [dB] [degree] format
num = numel(sparam);  % number of s-parameters


for ii = 1:num                          % for all s-parameters
    S = sparam(ii).Parameters(n,m,:);   % get the Snm from ii s-parameter object
    S = reshape(squeeze(S),[],1);       % formats the matrix
    Amp(:,ii) = 20 * log10(abs(S));     % dB[Snm]
    Phase(:,ii) = angle(S) * (180/pi);  % Phase[Snm]
end