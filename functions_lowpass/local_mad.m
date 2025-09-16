function m = local_mad(x)
% local_mad  통계 툴박스 없이 Median Absolute Deviation 계산 (비스케일)
% m = median(|x - median(x)|)

x = x(:);
x = x(isfinite(x));
if isempty(x)
    m = 0;
    return;
end
mx = median(x);
m = median(abs(x - mx));
end

