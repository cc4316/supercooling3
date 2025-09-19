function [results, detail] = evaluate_transition_alignment(varargin)
% evaluate_transition_alignment  온도/스파라 과냉각 이벤트 정합(≤5s, sparam이 뒤) 평가
%
% 사용법
%   results = evaluate_transition_alignment()                 % 기본 실험 목록/파라미터
%   results = evaluate_transition_alignment('Exps', exps, ...) % 실험 폴더 지정
%
% 옵션(Name-Value)
%   'Exps'         : expdata 하위 상대 경로 셀/문자배열
%   'FreqGHz'      : 분석 주파수(들) [기본 24]
%   'Param'        : 'S11'|'S22' (기본 'S11')
%   'FilterType'   : 'lowpass'|'bandstop' (기본 'lowpass')
%   'CutoffHz'     : 저역통과 차단 Hz (기본 0.05)
%   'BandstopHz'   : [f1 f2] Hz (FilterType='bandstop'일 때)
%   'FilterOrder'  : IIR 차수 (기본 4)
%   'FilterDesign' : 'elliptic'|'butter'|'bessel'|'notch' (기본 'elliptic')
%   'FilterMode'   : 'causal'|'centered' (기본 'causal')
%   'EventK'       : sparam 이벤트 임계 K (기본 20)
%   'TempK'        : 온도 이벤트 임계 K (기본 12)
%   'AlignWindow'  : 정합 허용 [0 5]초 (기본 [0 5])
%   'Save'         : 결과 CSV/MAT 저장 (기본 true)
%   'UseManualTempEvents' : Temp 이벤트를 CSV(수동 교정본)에서 읽어 사용 (기본 false)
%   'ManualTempEventsFile': 수동 이벤트 CSV 경로(기본 '' → 폴더 내 자동 탐색)
%
% 출력
%   results : table 요약 및 부가 정보 구조체 포함 (results.info)

addpath('functions');
addpath('functions_lowpass');

ip = inputParser;
ip.addParameter('Exps', load_default_experiments(), @(c)iscell(c)||isstring(c));
ip.addParameter('FreqGHz', 24, @(x)isnumeric(x)&&isvector(x));
ip.addParameter('Param', 'S11');
ip.addParameter('FilterType', 'lowpass');
ip.addParameter('CutoffHz', 0.05, @isscalar);
ip.addParameter('BandstopHz', [NaN NaN]);
ip.addParameter('FilterOrder', 4, @isscalar);
ip.addParameter('FilterDesign', 'elliptic');
ip.addParameter('FilterMode', 'causal');
ip.addParameter('EventK', 20, @isscalar);
ip.addParameter('TempK', 12, @isscalar);
ip.addParameter('AlignWindow', [0 5], @(x)isnumeric(x)&&numel(x)==2);
ip.addParameter('Save', true, @(x)islogical(x)&&isscalar(x));
ip.addParameter('WriteTempEvents', false, @(x)islogical(x)&&isscalar(x));
ip.addParameter('UseManualTempEvents', true, @(x)islogical(x)&&isscalar(x));
ip.addParameter('ManualTempEventsFile', '', @(s)ischar(s)||isstring(s));
ip.parse(varargin{:});
opt = ip.Results;

baseExp = fullfile(pwd,'expdata');
exps = cellstr(opt.Exps);

rows = {};
detail = struct('exp',{},'param',{},'freqGHz',{},'temp',{},'sparam',{});

for ei = 1:numel(exps)
    expDir = fullfile(baseExp, exps{ei});
    if exist(expDir,'dir') ~= 7
        warning('경고: 폴더 없음 → 건너뜀: %s', expDir);
        continue;
    end
    % sParam 폴더 추정
    spDir = expDir;
    if exist(fullfile(expDir,'sParam'),'dir') == 7
        spDir = fullfile(expDir,'sParam');
    end

    % 0) sparam 캐시 준비(없으면 생성)
    try
        hasPart = ~isempty(dir(fullfile(spDir, 'sparam_data_part*.mat')));
        hasSingle = exist(fullfile(spDir, 'sparam_data.mat'),'file') == 2;
        if ~(hasPart || hasSingle)
            fprintf('캐시 없음 → cachespara 실행: %s\n', spDir);
            cachespara(spDir);
        end
    catch ME
        warning('cachespara 실패(%s): %s', exps{ei}, ME.message);
    end

    % 1) sparam 결합/필터 파일 생성(저장)
    try
        args = {'Param', opt.Param, 'Freq', opt.FreqGHz, 'FreqUnit','GHz', ...
                'Save', true, 'Plot', false, 'SaveFig', false, ...
                'PlotFilterResponse', false, 'SaveFilterFig', false, ...
                'RunWavelet', false, 'FilterMode', opt.FilterMode, ...
                'FilterOrder', opt.FilterOrder, 'FilterDesign', opt.FilterDesign, 'FilterType', opt.FilterType};
        % 완전 비대화 모드로 고정
        args = [args, {'Interactive', false}];
        if strcmpi(opt.FilterType,'lowpass')
            args = [args, {'CutoffHz', opt.CutoffHz}];
        else
            args = [args, {'BandstopHz', opt.BandstopHz}];
        end
        combine_sparam_lowpass(spDir, args{:});
        % 혹시 열려있는(숨김 포함) figure가 있다면 강제로 정리
        try, close all force; catch, end
    catch ME
        warning('combine_sparam_lowpass 실패(%s): %s', exps{ei}, ME.message);
        continue;
    end

    % 저장된 결합 파일 로드 (results 우선, 없으면 sParam 폴백)
    try
        suffix = lower(opt.Param);
        resDir = fullfile(fileparts(spDir), 'results');
        cand = strings(0,1);
        if strcmpi(opt.FilterType,'bandstop')
            cand(end+1) = string(fullfile(resDir, sprintf('sparam_combined_filtered_%s_bandstop.mat', suffix)));
            cand(end+1) = string(fullfile(spDir,  sprintf('sparam_combined_filtered_%s_bandstop.mat', suffix)));
        else
            cand(end+1) = string(fullfile(resDir, sprintf('sparam_combined_filtered_%s.mat', suffix)));
            cand(end+1) = string(fullfile(spDir,  sprintf('sparam_combined_filtered_%s.mat', suffix)));
        end
        cpath = '';
        for ci = 1:numel(cand)
            if exist(cand(ci),'file') == 2
                cpath = char(cand(ci)); break;
            end
        end
        if isempty(cpath)
            error('evaluate_transition_alignment:NoCombinedFile', '결합 파일을 찾지 못했습니다 (results/sParam).');
        end
        S = load(cpath);
    catch ME
        warning(ME.identifier, '%s', ME.message); %#ok<CTPCT>
        continue;
    end

    % 2) 온도 로드 + 채널 선택(csv) → 포트별 매핑
    try
        Tt = load_temp_csv_basic(expDir, 'Pattern','Temp.csv');
        cfgCsv = fullfile(expDir, 'TempChannelSelection.csv');
        % 자동 기본 채널 구성: 파일 없으면 1:min(8,N)로 라벨 저장(양 포트 공통)
        if exist(cfgCsv,'file') ~= 2
            nL = numel(Tt.Labels);
            defIdx = 1:min(8, nL);
            labs = string(Tt.Labels(defIdx))';
            Tcfg = table(); Tcfg.Label_P1 = labs; Tcfg.Label_P2 = labs;
            try, writetable(Tcfg, cfgCsv); catch, end
        end
        ptag = opt.Param; % 'S11'|'S22'
        idxT = resolve_temp_channels_port(Tt.Labels, cfgCsv, ptag);
    catch ME
        warning('온도/채널 로드 실패(%s): %s', exps{ei}, ME.message);
        continue;
    end

    % 3) 이벤트 (온도) — 수동 CSV만 사용 (자동 검출 비활성)
    try
        Et = i_load_manual_temp_events(expDir, ptag, Tt.Time, Tt.Values, idxT, string(opt.ManualTempEventsFile));
    catch ME
        error('evaluate_transition_alignment:ManualEventsRequired','수동 Temp 이벤트 CSV가 필요합니다: %s', ME.message);
    end
    if isempty(Et.idx)
        warning('온도 이벤트 없음(%s): 수동 CSV 내용을 확인하세요', exps{ei});
    end

    % 3-1) 온도 이벤트 CSV 저장 (자동 검출이 없으므로 비활성)
    try
        if false && opt.WriteTempEvents
            write_temp_events_csv(expDir, Et, 'Param', opt.Param);
        end
    catch
    end

    % 4) 이벤트 검출 (sparam) — 저장된 필터 신호 사용
    time_s = S.time(:);
    % 변수명 호환: 기본은 s11/s11_lp로 저장하나, 환경에 따라 s22_lp 등일 수 있음
    if isfield(S, 's11_lp')
        s_lp = S.s11_lp;
    elseif isfield(S, 's22_lp')
        s_lp = S.s22_lp;
    elseif isfield(S, 's_lp')
        s_lp = S.s_lp;
    else
        error('evaluate_transition_alignment:NoFilteredSignal','필터 신호를 찾을 수 없습니다 (s11_lp/s22_lp).');
    end
    Es = detect_sparam_events(time_s, s_lp, 'PhaseUnit','deg', ...
                              'EventThreshK', opt.EventK, 'EventScope','local', 'EventLocalSpanSec', 1800, ...
                              'EventMinSepSec', 5*median(diff(time_s)));

    % 5) 정합(온도 기준 이후 0..5s 내 sparam 존재 여부)
    t0 = min([Tt.Time(~isnat(Tt.Time)); Tt.Time(1)]);
    % sparam 절대시간(필수)
    if isfield(S,'time_dt') && any(~isnat(S.time_dt))
        Ts_abs = S.time_dt;
    else
        error('evaluate_transition_alignment:MissingSparamDateTime', 'S.time_dt가 비어 있습니다. s-파라미터 절대시간(time\_dt)이 필요합니다.');
    end

    % sparam 이벤트(크기/위상) 각각에 대해 매칭
    all_freqs = S.freqHz_used(:)';
    if isempty(all_freqs)
        all_freqs = opt.FreqGHz(:)'.*1e9; % 폴백
    end
    % sparam 전체 이벤트 시간(절대) 목록 (FP율 산출용)
    all_mag_abs = datetime.empty(0,1); all_ph_abs = datetime.empty(0,1);
    for c = 1:size(s_lp,2)
        t_s_mag = Ts_abs(Es.idx_mag{c});
        t_s_ph  = Ts_abs(Es.idx_phase{c});
        all_mag_abs = [all_mag_abs; t_s_mag(:)]; %#ok<AGROW>
        all_ph_abs  = [all_ph_abs;  t_s_ph(:)];  %#ok<AGROW>
        % 온도 이벤트마다 최근접 sparam(이후) 찾기
        for k = 1:numel(Et.idx)
            tT = Et.t(k);
            dmag = seconds(t_s_mag - tT);
            dmag = dmag(dmag >= opt.AlignWindow(1) & dmag <= opt.AlignWindow(2));
            dph  = seconds(t_s_ph  - tT);
            dph  = dph(dph  >= opt.AlignWindow(1) & dph  <= opt.AlignWindow(2));
            hitMag = ~isempty(dmag);
            hitPh  = ~isempty(dph);
            rows(end+1,1) = { { exps{ei}, char(opt.Param), all_freqs(c)/1e9, ...
                datestr(tT,'yyyy-mm-dd HH:MM:SS.FFF'), ...
                tern(hitMag, min(dmag), NaN), tern(hitPh, min(dph), NaN), ...
                hitMag || hitPh, numel(Es.idx_mag{c}), numel(Es.idx_phase{c}) } }; %#ok<AGROW>
        end
    end

    % FP율: 온도 이벤트 이후 0..5s 윈도우에 포함되지 않는 sparam 이벤트를 FP로 집계
    if ~isempty(Et.t)
        % 각 sparam 이벤트에 대해 temp 이벤트와의 (sparam - temp) 시간차의 최소값 계산
        d_all_mag = seconds(all_mag_abs - reshape(Et.t(:)', 1, []));
        d_all_ph  = seconds(all_ph_abs  - reshape(Et.t(:)', 1, []));
        % 온도보다 먼저 발생하거나 5초 초과는 FP로 간주
        is_fp_mag = true(size(all_mag_abs));
        is_fp_ph  = true(size(all_ph_abs));
        for r = 1:numel(all_mag_abs)
            if any(d_all_mag(r,:) >= opt.AlignWindow(1) & d_all_mag(r,:) <= opt.AlignWindow(2))
                is_fp_mag(r) = false;
            end
        end
        for r = 1:numel(all_ph_abs)
            if any(d_all_ph(r,:) >= opt.AlignWindow(1) & d_all_ph(r,:) <= opt.AlignWindow(2))
                is_fp_ph(r) = false;
            end
        end
        % 시간 길이로 정규화(분당)
        durMin = minutes(max(Ts_abs) - min(Ts_abs));
        if ~isfinite(durMin) || durMin <= 0, durMin = minutes(seconds(max(time_s) - min(time_s))); end
        if ~isfinite(durMin) || durMin <= 0, durMin = 1; end
        fp_mag_per_min = nnz(is_fp_mag) / durMin;
        fp_ph_per_min  = nnz(is_fp_ph)  / durMin;
    else
        fp_mag_per_min = NaN; fp_ph_per_min = NaN;
    end
    % per-exp summary 행 추가 (NaN 컬럼들은 이후 요약 단계에서 계산하거나 별도 CSV 저장 가능)

    % 상세 보관
    detail(end+1).exp = exps{ei}; %#ok<AGROW>
    detail(end).param = opt.Param;
    detail(end).freqGHz = all_freqs/1e9;
    detail(end).temp = Et;
    detail(end).sparam = Es;
end

% 테이블 정리
if isempty(rows)
    results = table();
else
    A = vertcat(rows{:});
    results = cell2table(A, 'VariableNames', {'exp','param','freq_GHz','t_temp','delta_mag_s','delta_phase_s','success','n_mag_events','n_phase_events'});
end

% 메트릭 요약
if ~isempty(results)
    successRate_detailed = mean(results.success);
    % 이벤트(온도) 기준 성공률: (exp,param,t_temp) 그룹별 any(hit)
    try
        tt = results.t_temp; if ~isdatetime(tt), tt = datetime(string(tt)); end
        [G, ~, ~, ~] = findgroups(results.exp, results.param, tt);
        hit_any = splitapply(@(x) any(x>0), double(results.success), G);
        successRate_event = mean(hit_any);
        % 이벤트 요약 CSV도 저장
        try
            [G2, expU, paramU, tU] = findgroups(results.exp, results.param, tt);
            hit_any2 = splitapply(@(x) any(x>0), double(results.success), G2);
            S_ev = table(expU, paramU, tU, hit_any2, 'VariableNames', {'exp','param','t_temp','hit_any'});
            outCsvE = fullfile(baseExp,'transition_event_level_summary.csv');
            try, writetable(S_ev, outCsvE); catch, end
        catch
        end
    catch
        successRate_event = successRate_detailed;
        hit_any = results.success; %#ok<NASGU>
    end
    % 조건 문자열 구성
    try
        freqStr = strtrim(num2str(opt.FreqGHz));
    catch
        freqStr = '';
    end
    try
        if strcmpi(opt.FilterType,'bandstop') && numel(opt.BandstopHz) >= 2
            fparamStr = sprintf('Stop=[%g %g] Hz', opt.BandstopHz(1), opt.BandstopHz(2));
        else
            fparamStr = sprintf('Cutoff=%.6g Hz', opt.CutoffHz);
        end
    catch
        fparamStr = '';
    end
    % 2줄(조건) + 1줄(결과)
    fprintf('요약 조건: Param=%s | FreqGHz=%s\n', char(opt.Param), freqStr);
    fprintf('요약 조건: Filter=%s/%s N=%d | Mode=%s | %s | EventK=%d | AlignWindow=[%g %g] s\n', ...
        char(opt.FilterType), char(opt.FilterDesign), opt.FilterOrder, char(opt.FilterMode), fparamStr, ...
        opt.EventK, opt.AlignWindow(1), opt.AlignWindow(2));
    % 오탐(총 개수) 계산(detail 기반)
    fp_mag = NaN; fp_ph = NaN;
    try
        [fp_mag, fp_ph] = local_compute_fp_count(detail, opt.AlignWindow);
    catch
    end
    fprintf('요약 결과: 성공률=%.1f%% (이벤트, %d/%d) | 성공률(세부)=%.1f%% (%d/%d) | FP(|S|)=%g | FP(∠)=%g\n', ...
        100*successRate_event, nnz(hit_any), numel(hit_any), 100*successRate_detailed, nnz(results.success), height(results), fp_mag, fp_ph);
end

% 저장
if opt.Save
    outCsv = fullfile(baseExp, 'transition_eval_results.csv');
    try, writetable(results, outCsv); catch, end
    outMat = fullfile(baseExp, 'transition_eval_details.mat');
    info = opt; %#ok<NASGU>
    try, save(outMat, 'results','detail','info'); catch, end
end

% 부가 정보는 MAT 저장(info) 또는 두 번째 출력(detail)로 제공

end

function y = tern(c,a,b)
    if c, y = a; else, y = b; end
end

function [fp_mag, fp_ph] = local_compute_fp_count(detail, win)
fp_mag = NaN; fp_ph = NaN;
try
    cntFPm = []; cntFPp = [];
    for i = 1:numel(detail)
        Et = detail(i).temp; Es = detail(i).sparam;
        if isempty(Et) || isempty(Es), continue; end
        if isempty(Et.t), continue; end
        t_s = Es.time_s(:);
        for c = 1:numel(Es.idx_mag)
            dm = Es.idx_mag{c}; tMag = t_s(dm);
            good = false(size(tMag));
            for k = 1:numel(Et.idx)
                dt = tMag - (Et.t(k) - Et.t(1));
                good = good | (dt >= win(1) & dt <= win(2));
            end
            cntFPm(end+1) = sum(~good); %#ok<AGROW>
        end
        for c = 1:numel(Es.idx_phase)
            dp = Es.idx_phase{c}; tPh = t_s(dp);
            good = false(size(tPh));
            for k = 1:numel(Et.idx)
                dt = tPh - (Et.t(k) - Et.t(1));
                good = good | (dt >= win(1) & dt <= win(2));
            end
            cntFPp(end+1) = sum(~good); %#ok<AGROW>
        end
    end
    fp_mag = sum(cntFPm);
    fp_ph  = sum(cntFPp);
catch
end
end

function Et = i_load_manual_temp_events(expDir, ptag, time_dt, values, idxT, manualPath)
% 수동 편집된 온도 이벤트 CSV를 로드하여 Et 구조체로 변환
% 우선순위: 명시 경로 → 폴더 내 temp_events_<Param>_manual.csv → temp_events_<Param>.csv
    if strlength(manualPath) > 0
        evPath = char(manualPath);
    else
        tag = regexprep(char(ptag),'[^A-Za-z0-9]','');
        evManual = fullfile(expDir, sprintf('temp_events_%s_manual.csv', tag));
        evDefault= fullfile(expDir, sprintf('temp_events_%s.csv', tag));
        if exist(evManual,'file') == 2
            evPath = evManual;
        else
            evPath = evDefault;
        end
    end
    if exist(evPath,'file') ~= 2
        error('수동 이벤트 파일을 찾지 못했습니다: %s', evPath);
    end
    T = readtable(evPath, 'VariableNamingRule','preserve');
    if ~ismember('t', T.Properties.VariableNames)
        error('CSV에 t 컬럼이 없습니다: %s', evPath);
    end
    t = T.t;
    if ~isdatetime(t)
        t = datetime(string(t));
    end
    % 각 이벤트를 Temp 시계열의 최근접 인덱스에 정렬
    [~, idx] = min(abs(time_dt(:) - reshape(t(:).',1,[])), [], 1);
    idx = idx(:)';
    % 선택 채널 평균 및 dT/dt 계산(검증/보조용)
    vals = values(:, idxT);
    Tsel = mean(vals,2,'omitnan');
    time_s = seconds(time_dt - time_dt(1));
    dT_dt = zeros(size(Tsel));
    if numel(Tsel) >= 3
        dT_dt(2:end-1) = (Tsel(3:end) - Tsel(1:end-2)) ./ (time_s(3:end) - time_s(1:end-2));
        dT_dt(1) = (Tsel(2)-Tsel(1)) / max(time_s(2)-time_s(1), eps);
        dT_dt(end) = (Tsel(end)-Tsel(end-1)) / max(time_s(end)-time_s(end-1), eps);
    end
    Et = struct('Tsel', Tsel, 'dT_dt', dT_dt, 'idx', idx, 't', time_dt(idx), 'thr_used', NaN, 'opts', struct());
end
