function freqs_hz = local_freqs_to_hz(freqs)
% 주파수 단위 추정 후 Hz로 변환
% 휴리스틱: 값의 크기를 기반으로 추정
% - >1e7  => Hz
% - >1e4  => MHz
% - 기타  => GHz
mx = max(freqs);
if mx > 1e7
    freqs_hz = double(freqs);
elseif mx > 1e4
    freqs_hz = double(freqs) * 1e6; % MHz
else
    freqs_hz = double(freqs) * 1e9; % GHz
end
end

