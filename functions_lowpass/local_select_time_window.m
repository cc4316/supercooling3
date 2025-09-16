function [t0, t1] = local_select_time_window(time_s, T0, WinSec, T1)
% 콘솔에서 시작/끝 시간 선택.
% - time_s: 전체 시간 벡터(초)
% - T0, WinSec, T1: 초기 제안값(있으면 기본값으로 표시)

tmin = time_s(1);
tmax = time_s(end);
dur  = tmax - tmin;

% 초기값 구성
if ~isnan(T1)
    t0_def = max(tmin, T0);
    t1_def = min(tmax, T1);
elseif ~isempty(WinSec)
    t0_def = max(tmin, T0);
    t1_def = min(tmax, t0_def + WinSec);
else
    t0_def = tmin;
    t1_def = tmax;
end

fprintf('\n[Time Window Select]\n');
fprintf('  Range: [%.3f, %.3f] s  (duration: %.3f s)\n', tmin, tmax, dur);
fprintf('  Default: t0=%.3f, t1=%.3f (Win=%.3f s)\n', t0_def, t1_def, t1_def - t0_def);
fprintf('입력 형식:\n');
fprintf('  [Enter] 기본값 사용\n');
fprintf('  1) t0,t1 (예: 100,160)\n');
fprintf('  2) t0+win (예: 100+60)\n');

t0 = t0_def; t1 = t1_def;
in = input('선택 입력: ', 's');
if isempty(in)
    return;
end

% 앞에 붙은 프롬프트 기호(>>, >)나 공백 제거
in = regexprep(in, '^[>\s]+', '');
in = strtrim(in);

% 메뉴 번호 처리
if strcmp(in, '1')
    s2 = input('t0,t1 입력 (예: 100,160): ', 's');
    s2 = strtrim(s2);
    tok = split(s2, {',',' '});
    tok = tok(~cellfun(@isempty, tok));
    if numel(tok) >= 2
        t0i = str2double(tok{1});
        t1i = str2double(tok{2});
        if isfinite(t0i) && isfinite(t1i)
            t0 = max(tmin, min(t0i, t1i));
            t1 = min(tmax, max(t0i, t1i));
            return;
        end
    end
    fprintf('입력을 해석하지 못해 기본값을 사용합니다.\n');
    return;
elseif strcmp(in, '2')
    s2 = input('t0+win 입력 (예: 100+60 또는 "100 60"): ', 's');
    s2 = strtrim(s2);
    if contains(s2, '+')
        tok = split(s2, '+');
        if numel(tok) == 2
            t0i = str2double(tok{1}); wini = str2double(tok{2});
            if isfinite(t0i) && isfinite(wini) && wini >= 0
                t0 = max(tmin, t0i);
                t1 = min(tmax, t0 + wini);
                return;
            end
        end
    else
        tok = split(s2, {' ',','}); tok = tok(~cellfun(@isempty,tok));
        if numel(tok) >= 2
            t0i = str2double(tok{1}); wini = str2double(tok{2});
            if isfinite(t0i) && isfinite(wini) && wini >= 0
                t0 = max(tmin, t0i);
                t1 = min(tmax, t0 + wini);
                return;
            end
        end
    end
    fprintf('입력을 해석하지 못해 기본값을 사용합니다.\n');
    return;
end
% 직접 형식: t0+win, 또는 "t0 t1"/"t0,t1"
if contains(in, '+')
    tok = split(in, '+');
    if numel(tok) == 2
        t0i = str2double(tok{1});
        wini = str2double(tok{2});
        if isfinite(t0i) && isfinite(wini) && wini >= 0
            t0 = max(tmin, t0i);
            t1 = min(tmax, t0 + wini);
            return;
        end
    end
else
    tok = split(in, {',',' '}); tok = tok(~cellfun(@isempty,tok));
    if numel(tok) >= 2
        t0i = str2double(tok{1}); t1i = str2double(tok{2});
        if isfinite(t0i) && isfinite(t1i)
            t0 = max(tmin, min(t0i, t1i));
            t1 = min(tmax, max(t0i, t1i));
            return;
        end
    end
end

fprintf('입력을 해석하지 못해 기본값을 사용합니다.\n');
end
