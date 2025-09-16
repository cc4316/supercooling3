function [ok, t_sec, s_t, elapsed_used, t_dt, selHz] = local_extract_from_sparam(S, freqHz, phaseUnit, useTime, paramSel)
% sparam_data.data 구조를 인식하여 시간/주파수 슬라이스의 S11을 추출
ok = false; t_sec = []; s_t = []; elapsed_used = ''; t_dt = []; selHz = [];

% 타겟 탐색 순서:
% 1) 최상위 구조체 안에 .data가 있고 그 내부가 구조체 -> target
% 2) 최상위에 바로 data 구조체가 존재 -> target
% 3) 최상위의 임의 구조체 중에 Frequencies/S11_*를 포함 -> target
fns = fieldnames(S);
target = [];
% 1)
for i = 1:numel(fns)
    val = S.(fns{i});
    if isstruct(val) && isfield(val, 'data') && isstruct(val.data)
        target = val.data; break;
    end
end
% 2)
if isempty(target) && isfield(S, 'data') && isstruct(S.data)
    target = S.data;
end
% 3)
if isempty(target)
    for i = 1:numel(fns)
        val = S.(fns{i});
        if isstruct(val)
            vf = fieldnames(val);
            if any(strcmpi(vf, 'Frequencies')) && any(contains(vf, 'S11_', 'IgnoreCase', true))
                target = val; break;
            end
        end
    end
end
if isempty(target), return; end
if numel(target) > 1, target = target(1); end

% 시간 축 선택을 위해 먼저 후보 생성
[t_sec_ts, ok_ts, dt_ts] = local_try_timestamps(target);
[t_sec_el, ok_el] = local_try_elapsed(target);

% 1) data 내부에 선택 파라미터(복소 또는 [Re Im]/[mag phase])가 직접 존재하는 경우
%    - 1xN 또는 Nx1: 단일 주파수 시계열로 간주
%    - MxN: 주파수×시간 행렬이면 Frequencies로 행 선택
direct_fields = {char(paramSel), upper(char(paramSel)), [upper(char(paramSel)) '_complex']};
for j = 1:numel(direct_fields)
    f = direct_fields{j};
    if isfield(target, f)
        raw = target.(f);
        if isvector(raw)
            s_t = raw(:);
            [t_sec, elapsed_used, ok, t_dt] = local_pick_timevec(useTime, ok_ts, t_sec_ts, dt_ts, ok_el, t_sec_el);
            if ok, return; else, ok = false; s_t = []; end
        elseif ismatrix(raw)
            % 행렬이면 Frequencies 필요
            if isfield(target, 'Frequencies')
                freqs = target.Frequencies(:);
                freqs_hz = local_freqs_to_hz(freqs);
                [~, fi] = min(abs(freqs_hz - freqHz), [], 1);
                fi = fi(:).'; % 요청한 주파수 개수 유지(중복 허용)
                if size(raw,1) == numel(freqs)
                    s_t = raw(fi,:).'; % [Nt x Nreq]
                    selHz = freqs_hz(fi);
                    [t_sec, elapsed_used, ok, t_dt] = local_pick_timevec(useTime, ok_ts, t_sec_ts, dt_ts, ok_el, t_sec_el);
                    if ok, return; else, ok = false; s_t = []; end
                end
            end
        end
    end
end

% 2) dB/phase 쌍이 존재하는 경우
magField = sprintf('%s_dB', upper(char(paramSel)));
phField  = sprintf('%s_phase', upper(char(paramSel)));
if isfield(target, 'Frequencies') && isfield(target, magField) && isfield(target, phField)
    freqs = target.Frequencies(:);
    freqs_hz = local_freqs_to_hz(freqs);
    [~, fi] = min(abs(freqs_hz - freqHz), [], 1);
    fi = fi(:).';
    S_dB = target.(magField); S_ph = target.(phField);
    if size(S_dB,1) == numel(freqs) && isequal(size(S_dB), size(S_ph))
        mag = 10.^(double(S_dB(fi,:))/20); % [Nreq x Nt]
        ph  = double(S_ph(fi,:));          % [Nreq x Nt]
        if startsWith(phaseUnit, 'deg')
            ph = deg2rad(ph);
        end
        s_t = (mag .* exp(1i*ph)).';       % [Nt x Nreq]
        selHz = freqs_hz(fi);
        [t_sec, elapsed_used, ok, t_dt] = local_pick_timevec(useTime, ok_ts, t_sec_ts, dt_ts, ok_el, t_sec_el);
        if ok, return; else, ok = false; s_t = []; end
    end
end

% 시간 축 선택 (백업)
prefer_ts = strcmp(useTime, 'timestamps') || strcmp(useTime, 'auto');
prefer_el = strcmp(useTime, 'elapsed')    || strcmp(useTime, 'auto');

if prefer_ts && isfield(target, 'Timestamps') && ~isempty(target.Timestamps)
    t_sec = posixtime(target.Timestamps(:));
    ok = true; elapsed_used = 'timestamps'; return;
elseif prefer_el && isfield(target, 'TimeElapsed') && ~isempty(target.TimeElapsed)
    t_sec = seconds(target.TimeElapsed(:));
    ok = true; elapsed_used = 'elapsed+offset'; return;
end

% 시간 정보가 없으면 실패 처리
ok = false; t_sec = []; s_t = []; elapsed_used = '';
end
