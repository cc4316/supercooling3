function ts = local_to_seconds(t)
% 다양한 시간 표현을 초 단위 double로 변환
if isdatetime(t)
    ts = seconds(t - t(1));
elseif isa(t, 'duration')
    ts = seconds(t - t(1));
else
    t = t(:);
    % 만약 시작이 0이 아니라면 0 기준 이동
    ts = double(t);
    if ~any(isnan(ts))
        ts = ts - ts(1);
    end
end
end

