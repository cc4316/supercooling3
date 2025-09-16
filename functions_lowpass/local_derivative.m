function dYdt = local_derivative(t, Y)
% local_derivative  1차 시간 미분(도함수) 추정
% - t: 시간 벡터 [Nt x 1] (double, seconds)
% - Y: 신호 행렬 [Nt x Ny]
% - dYdt: 동일 크기, 중앙차분(내부), 전진/후진차분(가장자리)

t = t(:);
Nt = numel(t);
if Nt < 2
    dYdt = zeros(size(Y));
    return;
end

% 출력 초기화
dYdt = nan(size(Y));

% 전진 차분 (첫 샘플)
dYdt(1,:) = (Y(2,:) - Y(1,:)) ./ (t(2) - t(1));

% 중앙 차분 (내부)
if Nt > 2
    dt_c = (t(3:Nt) - t(1:Nt-2));
    dYdt(2:Nt-1,:) = (Y(3:Nt,:) - Y(1:Nt-2,:)) ./ dt_c;
end

% 후진 차분 (마지막 샘플)
dYdt(Nt,:) = (Y(Nt,:) - Y(Nt-1,:)) ./ (t(Nt) - t(Nt-1));

end

