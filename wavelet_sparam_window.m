function wavelet_sparam_window(dataDir, varargin)
% wavelet_sparam_window  크기/위상 신호에 대해 CWT(웨이블릿) 스펙트로그램을 표시
%
% 사용법
%   wavelet_sparam_window(dataDir, 'FreqSelect', 24, 'T0', 0, 'WinSec', 120)
%   wavelet_sparam_window([], 'FreqSelect', 24.2, 'UseIdx', [])  % expdata 목록에서 선택
%
% 필수/선택 입력
%   dataDir     : sparam_combined_filtered(_s11|_s22|_*_bandstop).mat 이 위치한 sParam 폴더 경로
%                 (빈 값/생략 시 expdata 하위 후보 목록에서 선택)
%
% 옵션 (Name-Value)
%   'FreqSelect': 분석할 주파수 선택. GHz(스칼라) 또는 열 인덱스(정수).
%                 GHz를 주면 저장된 freqHz_used에서 최근접 열을 사용합니다. (기본: 24)
%   'Param'    : 'S11' | 'S22' | 'both' (기본 'S11'). 'both'이면 두 포트를 연속 플롯합니다.
%   'T0'       : 분석 시작 시간(초). (기본 0)
%   'WinSec'   : 윈도우 길이(초). 비우면 끝까지. (기본 [])
%   'UseFiltered': true면 s11_lp 사용(기본 true), false면 원신호 s11 사용
%   'VoicesPerOctave': CWT 해상도(기본 12)
%   'SaveFig'  : 그림 저장 여부(기본 true)
%   'FigFormats': 저장 형식(기본 {'fig'})
%   'PlotTemp' : 1행에 온도 시계열 표시 (기본 true)
%   'TempDir'  : 온도 CSV 폴더(기본 dataDir의 상위 폴더)
%   'TempPattern': 온도 CSV 패턴 (기본 'Temp*.csv')
%   'AskWindow': 시작/끝 시간을 콘솔에서 선택 (기본 true)
%   'T1'       : 끝 시간(초). 지정하면 WinSec보다 우선.
%   'CWTdBSpan': CWT 컬러 스케일 상단 기준 dB 스팬(기본 40 → [max-40, max])
%
% 출력 없음(도표만 생성). 필요한 경우 반환형으로 확장 가능합니다.
%
% 비고
% - 먼저 combine_sparam_lowpass를 실행해 sparam_combined_filtered.mat을 생성하세요.
% - Wavelet Toolbox 필요(cwt 함수). 없으면 오류를 표시합니다.

% 의존 함수 경로 추가
thisDir = fileparts(mfilename('fullpath'));
helperDir = fullfile(thisDir, 'functions_lowpass');
if exist(helperDir, 'dir') == 7 && isempty(strfind(path, helperDir)) %#ok<STREMP>
    addpath(helperDir);
end

% 폴더 선택
if ~exist('dataDir','var') || isempty(dataDir)
    baseExp = fullfile(thisDir, 'expdata');
    if exist(baseExp, 'dir') ~= 7, baseExp = fullfile(pwd, 'expdata'); end
    if exist(baseExp, 'dir') ~= 7
        error('wavelet_sparam_window:NoExpdataDir','expdata 폴더를 찾을 수 없습니다.');
    end
    dataDir = local_select_expdata_dir(baseExp);
end

% 옵션 파싱
p = inputParser;
addParameter(p, 'FreqSelect', 24, @(x) (isnumeric(x) && isvector(x) && ~isempty(x)) || ischar(x) || isstring(x));
addParameter(p, 'T0', 0, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'WinSec', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x) && x>0));
addParameter(p, 'UseFiltered', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Param', 'S11', @(s) ischar(s) || isstring(s));
addParameter(p, 'VoicesPerOctave', 12, @(x) isnumeric(x) && isscalar(x) && x>0);
addParameter(p, 'SaveFig', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'FigFormats', {'fig'}, @(c) iscell(c) || isstring(c));
addParameter(p, 'PlotTemp', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'TempDir', '', @(s) ischar(s) || isstring(s));
addParameter(p, 'TempPattern', 'Temp.csv', @(s) ischar(s) || isstring(s));
addParameter(p, 'TempChanConfig', '', @(s) ischar(s) || isstring(s));
addParameter(p, 'AskWindow', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'T1', NaN, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'CWTdBSpan', 40, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'CombinedMatPath', '', @(s) ischar(s) || isstring(s));
parse(p, varargin{:});
fqSel    = p.Results.FreqSelect;
T0       = p.Results.T0;
WinSec   = p.Results.WinSec;
T1       = p.Results.T1;
useLp    = p.Results.UseFiltered;
paramSel = upper(string(p.Results.Param));
vpo      = p.Results.VoicesPerOctave;
doSave   = p.Results.SaveFig;
figFormats = cellstr(p.Results.FigFormats);
plotTemp = p.Results.PlotTemp;
tempDirIn= string(p.Results.TempDir);
tempPattern = string(p.Results.TempPattern);
tempChanCfgIn = string(p.Results.TempChanConfig);
askWindow = p.Results.AskWindow;
cwtSpan  = p.Results.CWTdBSpan;
matPathIn = string(p.Results.CombinedMatPath);

% 사용자가 Param을 명시하지 않았고(S11이 기본), S11/S22 파일이 모두 있으면 자동으로 BOTH 처리
paramProvided = false;
for k = 1:2:numel(varargin)
    if k <= numel(varargin) && (ischar(varargin{k}) || isstring(varargin{k}))
        if strcmpi(char(varargin{k}), 'Param')
            paramProvided = true; break;
        end
    end
end
if ~paramProvided && ~(paramSel == "BOTH")
    p11 = local_find_combined_file(char(dataDir), 'S11');
    p22 = local_find_combined_file(char(dataDir), 'S22');
    if ~isempty(p11) && ~isempty(p22)
        fprintf('Wavelet: S11/S22 파일이 모두 있어 Param=BOTH로 자동 전환합니다.\n');
        paramSel = "BOTH";
    end
end

% Param='both'이면 동일 창 선택으로 S11,S22를 연속 플롯
if paramSel == "BOTH"
    % 입력 NV 추출
    nv = varargin;
    % 창 선택용 time 벡터 확보(S11 우선)
    matS11 = local_find_combined_file(dataDir, 'S11');
    matS22 = local_find_combined_file(dataDir, 'S22');
    if isempty(matS11) && isempty(matS22)
        error('wavelet_sparam_window:NoCombinedFile', 'S11/S22 결합 파일을 찾지 못했습니다. 먼저 combine_sparam_lowpass를 실행하세요.');
    end
    matWin = matS11; if isempty(matWin), matWin = matS22; end
    S0 = load(matWin);
    if ~isfield(S0, 'time') || isempty(S0.time)
        error('wavelet_sparam_window:BadFile', 'time 변수가 없습니다: %s', matWin);
    end
    time0 = S0.time(:);
    % 주파수 선택 프롬프트: 사용자가 FreqSelect를 명시하지 않았으면 물어봄
    userProvidedFq = false;
    for k = 1:2:numel(nv)
        if k <= numel(nv) && (ischar(nv{k}) || isstring(nv{k}))
            if strcmpi(char(nv{k}), 'FreqSelect')
                userProvidedFq = true; break;
            end
        end
    end
    if ~userProvidedFq
        fhz0 = [];
        try
            if isfield(S0, 'freqHz_used') && ~isempty(S0.freqHz_used)
                fhz0 = S0.freqHz_used(:).';
            end
        catch
        end
        try
            if ~isempty(fhz0)
                fminG = min(fhz0)/1e9; fmaxG = max(fhz0)/1e9; nF = numel(fhz0);
                fprintf('표시할 주파수 선택 (기본: all). 사용 가능: %d개 [%.6g .. %.6g] GHz\n', nF, fminG, fmaxG);
                s = input('입력 예: all | 24 | 24,24.2 | 24:0.1:24.5  → ', 's');
            else
                nF = size(S0.s11,2);
                fprintf('표시할 주파수 선택 (기본: all). 사용 가능 열 수: %d\n', nF);
                s = input('입력 예: all | 1 | 1,3,5 | 1:5  → ', 's');
            end
            s = strtrim(s);
            if isempty(s) || strcmpi(s,'all')
                nv = i_set_nv(nv, 'FreqSelect', 'all');
            else
                vv = []; ok = false;
                if any(s == ':') || any(s == ',')
                    vv = str2num(s); %#ok<ST2NM>
                    ok = isnumeric(vv) && ~isempty(vv);
                else
                    w = regexp(s, '[,\s]+', 'split');
                    w = w(~cellfun(@isempty,w));
                    vv = str2double(w);
                    ok = all(isfinite(vv));
                end
                if ok
                    nv = i_set_nv(nv, 'FreqSelect', vv);
                else
                    fprintf('입력을 해석하지 못해 기본(all)로 표시합니다.\n');
                    nv = i_set_nv(nv, 'FreqSelect', 'all');
                end
            end
        catch
            % 실패 시 기본(all)
            nv = i_set_nv(nv, 'FreqSelect', 'all');
        end
    end
    % 창 결정(AskWindow 기준)
    if askWindow
        [t0_sel, t1_sel] = local_select_time_window(time0, T0, WinSec, T1);
    else
        if ~isnan(T1)
            t0_sel = max(0, T0);
            t1_sel = max(t0_sel, T1);
        elseif isempty(WinSec)
            t0_sel = max(0, T0);
            t1_sel = time0(end);
        else
            t0_sel = max(0, T0);
            t1_sel = t0_sel + WinSec;
        end
    end
    % 공통 NV 구성: 창 고정, 재프롬프트 방지
    nv = i_set_nv(nv, 'AskWindow', false);
    nv = i_set_nv(nv, 'T0', t0_sel);
    nv = i_set_nv(nv, 'T1', t1_sel);
    % S11 플롯(있을 때)
    if ~isempty(matS11)
        nvS11 = i_set_nv(nv, 'Param', 'S11');
        nvS11 = i_set_nv(nvS11, 'CombinedMatPath', matS11);
        wavelet_sparam_window(dataDir, nvS11{:});
    else
        warning('wavelet_sparam_window:MissingS11','S11 파일을 찾지 못했습니다. S22만 플롯합니다.');
    end
    % S22 플롯(있을 때)
    if ~isempty(matS22)
        nvS22 = i_set_nv(nv, 'Param', 'S22');
        nvS22 = i_set_nv(nvS22, 'CombinedMatPath', matS22);
        wavelet_sparam_window(dataDir, nvS22{:});
    else
        warning('wavelet_sparam_window:MissingS22','S22 파일을 찾지 못했습니다. S11만 플롯합니다.');
    end
    return;
end

% 파일 로드(없으면 안내) — 다양한 파일명 지원
if strlength(matPathIn) > 0
    matPath = char(matPathIn);
    if exist(matPath, 'file') ~= 2
        error('wavelet_sparam_window:NoCombinedFile', '지정된 파일이 존재하지 않습니다: %s', matPath);
    end
else
    matPath = local_find_combined_file(dataDir, char(paramSel));
end
if isempty(matPath)
    % 후보를 나열해 안내
    d = dir(fullfile(dataDir, 'sparam_combined_filtered*.mat'));
    list = strjoin({d.name}, ', ');
    error('wavelet_sparam_window:NoCombinedFile', '결합 파일을 찾지 못했습니다. dataDir=%s, candidates=[%s]\n먼저 combine_sparam_lowpass를 실행하세요.', dataDir, list);
end
fprintf('Wavelet: loading combined file => %s\n', matPath);
S = load(matPath);
if ~isfield(S, 'time') || (~isfield(S, 's11') && ~isfield(S, 's11_lp'))
    error('wavelet_sparam_window:BadFile', '필요 변수(time, s11/s11_lp)가 없습니다: %s', matPath);
end
time_s = S.time(:);
X_raw = S.s11;
hasLP = isfield(S, 's11_lp');
if hasLP, X_lp = S.s11_lp; else, X_lp = []; end
% CWT 입력 선택
if useLp && hasLP, X = X_lp; else, X = X_raw; end
if size(X_raw,1) ~= numel(time_s)
    error('wavelet_sparam_window:SizeMismatch', 'time과 데이터 길이가 다릅니다.');
end

% 주파수 축 정보 보유 시 전역 라벨용으로 확보
fhz = [];
if isfield(S, 'freqHz_used') && ~isempty(S.freqHz_used)
    try, fhz = S.freqHz_used(:).'; catch, fhz = []; end
end

% FreqSelect 사용자 제공 여부 확인(단일 호출 경로)
userProvidedFq_local = false;
for k = 1:2:numel(varargin)
    if k <= numel(varargin) && (ischar(varargin{k}) || isstring(varargin{k}))
        if strcmpi(char(varargin{k}), 'FreqSelect')
            userProvidedFq_local = true; break;
        end
    end
end
if ~userProvidedFq_local
    fhz_local = [];
    try
        if isfield(S, 'freqHz_used') && ~isempty(S.freqHz_used)
            fhz_local = S.freqHz_used(:).';
        end
    catch
    end
    try
        if ~isempty(fhz_local)
            fminG = min(fhz_local)/1e9; fmaxG = max(fhz_local)/1e9; nF = numel(fhz_local);
            fprintf('표시할 주파수 선택 (기본: all). 사용 가능: %d개 [%.6g .. %.6g] GHz\n', nF, fminG, fmaxG);
            s_in = input('입력 예: all | 24 | 24,24.2 | 24:0.1:24.5  → ', 's');
        else
            nF = size(X,2);
            fprintf('표시할 주파수 선택 (기본: all). 사용 가능 열 수: %d\n', nF);
            s_in = input('입력 예: all | 1 | 1,3,5 | 1:5  → ', 's');
        end
        s_in = strtrim(s_in);
        if isempty(s_in)
            fqSel = 'all';
        elseif strcmpi(s_in,'all')
            fqSel = 'all';
        else
            vv = []; ok = false;
            if any(s_in == ':') || any(s_in == ',')
                vv = str2num(s_in); %#ok<ST2NM>
                ok = isnumeric(vv) && ~isempty(vv);
            else
                w = regexp(s_in, '[,\s]+', 'split');
                w = w(~cellfun(@isempty,w));
                vv = str2double(w);
                ok = all(isfinite(vv));
            end
            if ok
                fqSel = vv;
            else
                fprintf('입력을 해석하지 못해 기본(all)로 표시합니다.\n');
                fqSel = 'all';
            end
        end
    catch
        fqSel = 'all';
    end
end

% 주파수 열 선택(단일 또는 복수)
idxCols = 1;
if ischar(fqSel) || isstring(fqSel)
    if strcmpi(char(fqSel), 'all')
        idxCols = 1:size(X,2);
    else
        error('wavelet_sparam_window:BadFreqSelect', 'FreqSelect는 숫자(스칼라/벡터) 또는 ''all''이어야 합니다.');
    end
else
    if isfield(S, 'freqHz_used') && ~isempty(S.freqHz_used)
        fhz = S.freqHz_used(:).';
        % 숫자 벡터를 GHz로 해석하여 최근접 인덱스 선택
        targetHz = fqSel(:).' * 1e9;
        idxCols = zeros(1, numel(targetHz));
        for k = 1:numel(targetHz)
            [~, idxCols(k)] = min(abs(fhz - targetHz(k)));
        end
        idxCols = unique(idxCols, 'stable');
    else
        % 인덱스 벡터로 해석
        idxCols = unique(round(fqSel(:).'), 'stable');
        idxCols = idxCols(idxCols>=1 & idxCols<=size(X,2));
        if isempty(idxCols), idxCols = 1; end
    end
end
idxColMain = idxCols(1);
% 주파수 라벨(범례용) 준비
freqLabels = strings(1, numel(idxCols));
if exist('fhz','var') && ~isempty(fhz)
    for ii = 1:numel(idxCols)
        try
            freqLabels(ii) = sprintf('%.2f GHz', fhz(idxCols(ii))/1e9);
        catch
            freqLabels(ii) = sprintf('#%d', idxCols(ii));
        end
    end
elseif isnumeric(fqSel) && ~isempty(fqSel)
    % 사용자가 GHz로 직접 지정한 경우에 대비(대략 기준: > 1 → GHz)
    if all(fqSel(:) > 1)
        for ii = 1:numel(idxCols)
            v = fqSel(min(ii, numel(fqSel)));
            freqLabels(ii) = sprintf('%.2f GHz', v);
        end
    else
        for ii = 1:numel(idxCols)
            freqLabels(ii) = sprintf('#%d', idxCols(ii));
        end
    end
else
    for ii = 1:numel(idxCols)
        freqLabels(ii) = sprintf('#%d', idxCols(ii));
    end
end

% 윈도우 선택 (기본: 전체 시간의 20% 지점부터 시작)
% 사용자가 T0를 명시하지 않은 경우에만 기본 적용
userProvidedT0 = false;
for k = 1:2:numel(varargin)
    if k <= numel(varargin) && (ischar(varargin{k}) || isstring(varargin{k}))
        if strcmpi(char(varargin{k}), 'T0')
            userProvidedT0 = true; break;
        end
    end
end
durTotal = time_s(end) - time_s(1);
T0_default = max(0, 0.2 * durTotal);
T0_eff = T0;
if ~userProvidedT0
    T0_eff = T0_default;
end

if askWindow
    [t0, t1] = local_select_time_window(time_s, T0_eff, WinSec, T1);
else
    if ~isnan(T1)
        t0 = max(0, T0_eff);
        t1 = max(t0, T1);
        t1 = min(t1, time_s(end));
    elseif isempty(WinSec)
        t0 = max(0, T0_eff);
        t1 = time_s(end);
    else
        t0 = max(0, T0_eff);
        t1 = min(time_s(end), t0 + WinSec);
    end
end
idxWin = find(time_s >= t0 & time_s <= t1);
if numel(idxWin) < 16
    error('wavelet_sparam_window:TooShort', '선택된 윈도우 구간이 너무 짧습니다. 샘플 수=%d', numel(idxWin));
end

twin = time_s(idxWin);
xcol = X(idxWin, idxColMain);
mag  = 20*log10(abs(xcol));
ph   = unwrap(angle(xcol));

% 샘플링 레이트
dt = median(diff(twin));
if ~isfinite(dt) || dt <= 0, error('wavelet_sparam_window:BadTime', '시간 간격 추정 실패'); end
fs = 1/dt;

% Wavelet Toolbox 체크
if exist('cwt', 'file') ~= 2
    error('wavelet_sparam_window:NoCWT', 'Wavelet Toolbox의 cwt 함수가 필요합니다.');
end

% CWT 계산(윈도우 구간)
[wt_mag, f_mag] = cwt(mag, fs, 'VoicesPerOctave', vpo);
[wt_ph,  f_ph]  = cwt(ph,  fs, 'VoicesPerOctave', vpo);

% 전체 신호(선택 열) 타임시리즈 준비 (윈도우 강조 표시용)
mag_full_raw = 20*log10(abs(X_raw(:, idxCols)));
ph_full_raw  = unwrap(angle(X_raw(:, idxCols)));
if hasLP
    mag_full_lp = 20*log10(abs(X_lp(:, idxCols)));
    ph_full_lp  = unwrap(angle(X_lp(:, idxCols)));
else
    mag_full_lp = [];
    ph_full_lp  = [];
end

% 절대 시간축(datetime) 동기화 여부 판단
hasSparamDT = isfield(S, 'time_dt') && ~isempty(S.time_dt) && any(~isnat(S.time_dt));
if hasSparamDT
    xSparamFull = S.time_dt(:);
    % 윈도우 경계도 datetime으로 변환
    dt0 = xSparamFull(1) + seconds(t0);
    dt1 = xSparamFull(1) + seconds(t1);
    % 플로팅/링크용 수치형 축으로 변환
    xSparamPlot = datenum(xSparamFull);
    dt0_num = datenum(dt0); dt1_num = datenum(dt1);
    % 전체 구간 X축 범위(전체가 보이도록 설정)
    xlim_full = [datenum(xSparamFull(1)) datenum(xSparamFull(end))];
else
    xSparamFull = time_s; % 초 단위
    dt0 = t0; dt1 = t1;   % 초 단위 경계
    xSparamPlot = xSparamFull;
    dt0_num = dt0; dt1_num = dt1;
    % 전체 구간 X축 범위(전체가 보이도록 설정)
    xlim_full = [time_s(1) time_s(end)];
end

% 온도 로드 (옵션)
Ttemp = [];
if plotTemp
    if strlength(tempDirIn) == 0
        tempDir = string(fileparts(dataDir));
    else
        tempDir = tempDirIn;
    end
    try
        Ttemp = local_load_temperature(tempDir, tempPattern);
    catch ME
        warning('온도 데이터 로드 실패: %s', ME.message);
        Ttemp = [];
    end
end

% 플롯: 3x2 (온도 1행) 또는 2x2 (온도 없음)
% Param 표기를 위해 저장된 파일의 param_used를 우선 사용(없으면 입력값)
paramFromFile = '';
try
    if isfield(S, 'param_used') && ~isempty(S.param_used)
        paramFromFile = upper(string(S.param_used));
    end
catch
end
if strlength(paramFromFile) == 0
    paramFromFile = upper(string(paramSel));
end
if numel(idxCols) == 1
    figName = sprintf('Wavelet %s | Freq idx %d', char(paramFromFile), idxColMain);
else
    figName = sprintf('Wavelet %s | Freq idx %d (+%d)', char(paramFromFile), idxColMain, numel(idxCols)-1);
end
f = figure('Name', figName);
if ~isempty(Ttemp)
    tlo = tiledlayout(3,2,'TileSpacing','compact','Padding','compact');
else
    tlo = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
end
try
    [~, mp] = fileparts(matPath);
catch
    mp = matPath;
end
% 타이틀: 시간 윈도우 표시는 제외하고, Wavelet 설정 + Param을 명시
title(tlo, sprintf('CWT (VPO=%d, Param=%s) — %s', vpo, char(paramFromFile), mp));

% 1행: 온도 (최대 8채널)
axLink = gobjects(0); % 1행(온도)과 2행(시계열) x축 링크용 축 핸들 수집
if ~isempty(Ttemp) && ~isempty(Ttemp.Time)
    % 온도축을 sparam 축과 동일 축 타입으로 맞춤
    if hasSparamDT
        % 전체를 datenum으로 통일
        if isdatetime(Ttemp.Time)
            xTemp = datenum(Ttemp.Time);
        else
            % 숫자 시간(초)을 datenum(일)로 매핑
            xTemp = datenum(xSparamFull(1)) + (Ttemp.Time(:) - Ttemp.Time(1))/86400;
        end
        xTempLabel = 'Time';
    else
        % 숫자 초 단위로 통일
        if isdatetime(Ttemp.Time)
            xTemp = seconds(Ttemp.Time - Ttemp.Time(1));
        else
            xTemp = Ttemp.Time;
        end
        xTempLabel = 'Time (s)';
    end
    % 채널 선택 구성 불러오기(결합/온도 공용 설정)
    try
        if strlength(tempChanCfgIn) == 0
            cfgPath = string(fullfile(char(tempDir), 'TempChannelSelection.csv'));
        else
            cfgPath = tempChanCfgIn;
        end
        % paramFromFile(S11/S22)에 해당하는 채널을 선택
        idxT = resolve_temp_channels_port(Ttemp.Labels, cfgPath, char(paramFromFile));
    catch ME
        warning('온도 채널 설정 해석 실패: %s. 기본 1:8 사용.', ME.message);
        ncolsT = size(Ttemp.Values,2);
        idxT = 1:min(8, max(0,ncolsT));
    end
    Vplot = Ttemp.Values(:, idxT);
    if iscell(Ttemp.Labels)
        labsPlot = Ttemp.Labels(idxT);
    else
        labsPlot = cellstr(Ttemp.Labels(idxT));
    end

    % 좌측 온도
    nexttile; hold on; grid on;
    % 윈도우 강조 패치 (x축 타입에 맞춰)
    try
        yL = [min(Vplot,[],'all','omitnan') max(Vplot,[],'all','omitnan')];
        if all(isfinite(yL)) && yL(2) > yL(1)
            if hasSparamDT
                xPatch = [dt0_num dt1_num dt1_num dt0_num];
            else
                xPatch = [t0 t1 t1 t0];
            end
            patch(xPatch, [yL(1) yL(1) yL(2) yL(2)], [0.96 0.96 0.86], 'FaceAlpha', 0.35, 'EdgeColor', 'none');
        end
    catch
    end
    plot(xTemp, Vplot, 'LineWidth', 1.0);
    if hasSparamDT, try, datetick('x','keeplimits'); end, end
    try, uistack(findobj(gca,'Type','line'),'top'); end
    ylabel('Temp'); xlabel(xTempLabel); legend(labsPlot, 'Location','best'); title('Temperature');
    axLink(end+1) = gca; %#ok<AGROW>

    % 우측 온도(동일 표시, 비교/확대용)
    nexttile; hold on; grid on;
    % 윈도우 강조 패치 (동일 설정)
    try
        yL = [min(Vplot,[],'all','omitnan') max(Vplot,[],'all','omitnan')];
        if all(isfinite(yL)) && yL(2) > yL(1)
            if hasSparamDT
                xPatch = [dt0_num dt1_num dt1_num dt0_num];
            else
                xPatch = [t0 t1 t1 t0];
            end
            patch(xPatch, [yL(1) yL(1) yL(2) yL(2)], [0.96 0.96 0.86], 'FaceAlpha', 0.35, 'EdgeColor', 'none');
        end
    catch
    end
    plot(xTemp, Vplot, 'LineWidth', 1.0);
    if hasSparamDT, try, datetick('x','keeplimits'); end, end
    try, uistack(findobj(gca,'Type','line'),'top'); end
    ylabel('Temp'); xlabel(xTempLabel); legend(labsPlot, 'Location','best'); title('Temperature');
    axLink(end+1) = gca; %#ok<AGROW>
end

% 상단 왼쪽: Magnitude 시계열 (raw + filtered) + 윈도우 강조
nexttile; hold on; grid on;
% 강조영역을 먼저 그려 배경 처리
yL = [min(mag_full_raw,[],'omitnan') max(mag_full_raw,[],'omitnan')];
if hasLP
    yL = [min([yL(1) min(mag_full_lp,[],'omitnan')],[],'omitnan'), max([yL(2) max(mag_full_lp,[],'omitnan')],[],'omitnan')];
end
if all(isfinite(yL)) && yL(2) > yL(1)
    if hasSparamDT
        xPatch = [dt0_num dt1_num dt1_num dt0_num];
    else
        xPatch = [t0 t1 t1 t0];
    end
    patch(xPatch, [yL(1) yL(1) yL(2) yL(2)], [0.85 0.92 1.0], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
end
% 여러 주파수(열) 지원: raw는 회색, filtered는 색상 반복으로 표시
cr = get(gca,'ColorOrder');
for c = 1:size(mag_full_raw,2)
    if c == 1
        plot(xSparamPlot, mag_full_raw(:,c), '-', 'Color', [0.3 0.3 0.3], 'DisplayName','raw');
    else
        plot(xSparamPlot, mag_full_raw(:,c), '-', 'Color', [0.3 0.3 0.3], 'HandleVisibility','off');
    end
end
if hasLP
    for c = 1:size(mag_full_lp,2)
        co = cr(mod(c-1,size(cr,1))+1,:);
        dn = sprintf('filtered @ %s', freqLabels(c));
        plot(xSparamPlot, mag_full_lp(:,c), '-', 'Color', co, 'LineWidth', 1.2, 'DisplayName', dn);
    end
end
uistack(findobj(gca,'Type','line'),'top'); % 라인을 앞으로
yline_dummy = []; %#ok<NASGU>
xline(dt0_num, ':', 'Color', [0 0.3 0.8]); xline(dt1_num, ':', 'Color', [0 0.3 0.8]);
ylabel('|S| (dB)'); if hasSparamDT, xlabel('Time'); else, xlabel('Time (s)'); end
title('Magnitude vs Time (raw + filtered)'); legend('Location','best');
if hasSparamDT, try, datetick('x','keeplimits'); end, end
axLink(end+1) = gca; %#ok<AGROW>

% 상단 오른쪽: Phase 시계열 (raw + filtered) + 윈도우 강조
nexttile; hold on; grid on;
yL = [min(ph_full_raw,[],'omitnan') max(ph_full_raw,[],'omitnan')];
if hasLP
    yL = [min([yL(1) min(ph_full_lp,[],'omitnan')],[],'omitnan'), max([yL(2) max(ph_full_lp,[],'omitnan')],[],'omitnan')];
end
if all(isfinite(yL)) && yL(2) > yL(1)
    if hasSparamDT
        xPatch = [dt0_num dt1_num dt1_num dt0_num];
    else
        xPatch = [t0 t1 t1 t0];
    end
    % 위상 플롯은 deg 단위이므로 패치 y 한계를 deg로 변환
    yLdeg = rad2deg(yL);
    patch(xPatch, [yLdeg(1) yLdeg(1) yLdeg(2) yLdeg(2)], [0.95 0.9 1.0], 'FaceAlpha', 0.3, 'EdgeColor', 'none');
end
% 위상은 deg로 표시
for c = 1:size(ph_full_raw,2)
    if c == 1
        plot(xSparamPlot, rad2deg(ph_full_raw(:,c)), '-', 'Color', [0.3 0.3 0.3], 'DisplayName','raw ∠');
    else
        plot(xSparamPlot, rad2deg(ph_full_raw(:,c)), '-', 'Color', [0.3 0.3 0.3], 'HandleVisibility','off');
    end
end
if hasLP
    cr = get(gca,'ColorOrder');
    for c = 1:size(ph_full_lp,2)
        co = cr(mod(c-1,size(cr,1))+1,:);
        dn = sprintf('filtered ∠ @ %s', freqLabels(c));
        plot(xSparamPlot, rad2deg(ph_full_lp(:,c)), '-', 'Color', co, 'LineWidth', 1.2, 'DisplayName', dn);
    end
end
uistack(findobj(gca,'Type','line'),'top');
xline(dt0_num, ':', 'Color', [0.5 0 0.8]); xline(dt1_num, ':', 'Color', [0.5 0 0.8]);
ylabel('Phase (deg)'); if hasSparamDT, xlabel('Time'); else, xlabel('Time (s)'); end
title('Phase vs Time (raw + filtered)'); legend('Location','best');
if hasSparamDT, try, datetick('x','keeplimits'); end, end
axLink(end+1) = gca; %#ok<AGROW>

% 1행(온도)과 2행(시계열) x축 링크
if numel(axLink) >= 2
    try, linkaxes(axLink, 'x'); end
end

% 하단 왼쪽: Magnitude scalogram (윈도우 구간) — Level(dB)
axSc = gobjects(0); % 하단 스칼로그램 축 핸들 수집(좌/우 동일 틱 적용용)
nexttile;
epsdB = 1e-12;
lev_mag_db = 20*log10(abs(wt_mag) + epsdB);
% X축: datetime 우선, 아니면 초 단위
if hasSparamDT
    twin_dt = xSparamFull(idxWin);
    x_surf = datenum(twin_dt);
    surf(x_surf, f_mag, lev_mag_db, 'EdgeColor','none'); axis tight; view(0,90);
    datetick('x','keeplimits');
else
    surf(twin, f_mag, lev_mag_db, 'EdgeColor','none'); axis tight; view(0,90);
end
set(gca,'YScale','log');
axSc(end+1) = gca; %#ok<AGROW>
% 더 촘촘한 로그 ytick 적용
try
    yt = local_logticks(min(f_mag), max(f_mag));
    yticks(yt);
    ytickformat('%.3g');
catch, end
if hasSparamDT
    xlabel('Time');
else
    xlabel('Time (s)');
end
ylabel('Freq (Hz)');
% CWT 기준 주파수 안내(선택 집합의 첫 번째)
if exist('fhz','var') && ~isempty(fhz)
    cwtTag = sprintf(' @ %.2f GHz', fhz(idxColMain)/1e9);
else
    cwtTag = sprintf(' @ idx %d', idxColMain);
end
title(['|S| CWT (Level dB)' cwtTag]);
cb=colorbar; ylabel(cb,'Level (dB)');
% 컬러 스케일 [max-span, max]
if isfinite(cwtSpan) && cwtSpan > 0
    mx = max(lev_mag_db(:), [], 'omitnan');
    if isfinite(mx)
        caxis([mx - cwtSpan, mx]);
    end
end
if hasSparamDT
    xline(dt0_num, ':', 'Color', [0 0 0]); xline(dt1_num, ':', 'Color', [0 0 0]);
else
    xline(t0, ':', 'Color', [0 0 0]); xline(t1, ':', 'Color', [0 0 0]);
end

% 하단 오른쪽: Phase scalogram (윈도우 구간) — Level(dB)
nexttile;
lev_ph_db  = 20*log10(abs(wt_ph)  + epsdB);
if hasSparamDT
    twin_dt = xSparamFull(idxWin);
    x_surf = datenum(twin_dt);
    surf(x_surf, f_ph, lev_ph_db, 'EdgeColor','none'); axis tight; view(0,90);
else
    surf(twin, f_ph, lev_ph_db, 'EdgeColor','none'); axis tight; view(0,90);
end
set(gca,'YScale','log');
axSc(end+1) = gca; %#ok<AGROW>
try
    yt = local_logticks(min(f_ph), max(f_ph));
    yticks(yt);
    ytickformat('%.3g');
catch, end
if hasSparamDT
    xlabel('Time');
else
    xlabel('Time (s)');
end
ylabel('Freq (Hz)'); title(['Phase CWT (Level dB)' cwtTag]); cb=colorbar; ylabel(cb,'Level (dB)');
if isfinite(cwtSpan) && cwtSpan > 0
    mx = max(lev_ph_db(:), [], 'omitnan');
    if isfinite(mx)
        caxis([mx - cwtSpan, mx]);
    end
end
if hasSparamDT
    xline(dt0_num, ':', 'Color', [0 0 0]); xline(dt1_num, ':', 'Color', [0 0 0]);
else
    xline(t0, ':', 'Color', [0 0 0]); xline(t1, ':', 'Color', [0 0 0]);
end

% 하단 스칼로그램 좌/우 x축 틱 통일 (datetime 기반일 때)
if hasSparamDT && numel(axSc) == 2
    try
        linkaxes(axSc, 'x');
        set(axSc, 'XLim', xlim_full);
        % 좌측 축을 기준으로 틱/라벨 복제
        datetick(axSc(1), 'x', 'keeplimits');
        xt = get(axSc(1), 'XTick');
        xtl = get(axSc(1), 'XTickLabel');
        set(axSc(2), 'XTick', xt, 'XTickLabel', xtl);
    catch
    end
end

% 전체(온도/시계열/스칼로그램) X축 링크 및 틱 포맷 통일 (datetime)
try
    axs_all = [axLink(:); axSc(:)]; axs_all = axs_all(isgraphics(axs_all));
    if numel(axs_all) >= 2
        linkaxes(axs_all, 'x');
        set(axs_all, 'XLim', xlim_full);
        if hasSparamDT
            for kk = 1:numel(axs_all)
                try, datetick(axs_all(kk), 'x', 'keeplimits'); end
            end
        end
    end
catch
end

% 저장
if doSave
    % 저장 파일명에 Param/다중 주파수 여부 구분
    % 이미지 저장은 상위 results 폴더로
    try
        [parentDir, baseName] = fileparts(dataDir);
        if strcmpi(baseName, 'sParam')
            expBase = parentDir;
        else
            expBase = dataDir;
        end
        outFigDir = fullfile(expBase, 'results');
        if exist(outFigDir, 'dir') ~= 7, mkdir(outFigDir); end
    catch
        outFigDir = dataDir;
    end
    if numel(idxCols) == 1
        base = fullfile(outFigDir, sprintf('wavelet_%s_%d', lower(char(paramFromFile)), idxColMain));
    else
        base = fullfile(outFigDir, sprintf('wavelet_%s_multi', lower(char(paramFromFile))));
    end
    for iFmt = 1:numel(figFormats)
        fmt = lower(figFormats{iFmt});
        switch fmt
            case 'fig', savefig(f, [base '.fig']);
            case 'png', saveas(f, [base '.png']);
            case 'jpg', saveas(f, [base '.jpg']);
            case 'pdf', saveas(f, [base '.pdf']);
        end
    end
end

% 데이터 커서(데이터팁)에서 x축을 타임스탬프로 표시
try
    dcm = datacursormode(f);
    set(dcm, 'UpdateFcn', @(obj, evt) i_dcmtip(evt, hasSparamDT));
catch
end

end

% 로컬: 결합 파일 경로 탐색
function matPath = local_find_combined_file(dataDir, paramSel)
% 우선순위: param 지정된 파일 → 동일 param의 bandstop → 단일 공용 파일 → 기타 매칭 중 첫 번째
names = {};
ps = upper(string(paramSel));
if ps == "S11"
    names{end+1} = 'sparam_combined_filtered_s11.mat';
    names{end+1} = 'sparam_combined_filtered_s11_bandstop.mat';
elseif ps == "S22"
    names{end+1} = 'sparam_combined_filtered_s22.mat';
    names{end+1} = 'sparam_combined_filtered_s22_bandstop.mat';
else
    % 알 수 없는 지정 → 공용부터
end
names{end+1} = 'sparam_combined_filtered.mat';

% 존재 확인(results 우선)
searchDirs = {};
try
    [parentDir, baseName] = fileparts(dataDir);
    if strcmpi(baseName, 'sParam')
        expBase = parentDir;
    else
        expBase = dataDir;
    end
    searchDirs{end+1} = fullfile(expBase, 'results');
catch
end
searchDirs{end+1} = dataDir;
for sd = 1:numel(searchDirs)
    for i = 1:numel(names)
        cand = fullfile(searchDirs{sd}, names{i});
        if exist(cand, 'file') == 2
            matPath = cand; return;
        end
    end
end
% 패턴 검색: 가장 최근 파일 선택
% 패턴 검색: results → dataDir
d = dir(fullfile(searchDirs{1}, 'sparam_combined_filtered_*.mat'));
if ~isempty(d)
    [~, idx] = max([d.datenum]);
    matPath = fullfile(d(idx).folder, d(idx).name);
    return;
end
% fallback to dataDir pattern
d = dir(fullfile(dataDir, 'sparam_combined_filtered_*.mat'));
if ~isempty(d)
    [~, idx] = max([d.datenum]);
    matPath = fullfile(d(idx).folder, d(idx).name);
    return;
end
    matPath = '';
end

% 로컬: Name-Value 설정/추가
function nv2 = i_set_nv(nvIn, key, val)
nv2 = nvIn;
found = false;
for jj = 1:2:numel(nv2)
    if ischar(nv2{jj}) || isstring(nv2{jj})
        if strcmpi(char(nv2{jj}), key)
            nv2{jj+1} = val; found = true; break;
        end
    end
end
if ~found
    nv2 = [nv2, {key, val}];
end
end

% 로컬: 데이터팁 표시 포맷터 (x축을 타임스탬프/초로 깔끔하게)
function out = i_dcmtip(evt, hasDT)
pos = evt.Position;
out = {};
% 표적 객체가 스칼로그램(Surface/Image)인지 판정
isSurf = isa(evt.Target, 'matlab.graphics.chart.primitive.Surface') || isa(evt.Target, 'matlab.graphics.primitive.Image');
if isSurf
    % 3행: 타임스탬프로 포맷
    if hasDT
        try
            dt = datetime(pos(1), 'ConvertFrom','datenum');
            dt.Format = 'yyyy-MM-dd HH:mm:ss.SSS';
            out{end+1} = ['Time: ' char(dt)]; %#ok<AGROW>
        catch
            out{end+1} = sprintf('Time: %.6g', pos(1)); %#ok<AGROW>
        end
    else
        out{end+1} = sprintf('Time (s): %.6g', pos(1)); %#ok<AGROW>
    end
    if numel(pos) >= 2
        out{end+1} = sprintf('Freq (Hz): %.6g', pos(2)); %#ok<AGROW>
    end
    if numel(pos) >= 3
        out{end+1} = sprintf('Level (dB): %.6g', pos(3)); %#ok<AGROW>
    end
else
    % 1·2행: 기본 스타일 유사(숫자 그대로)
    out{end+1} = sprintf('X: %.6g', pos(1)); %#ok<AGROW>
    if numel(pos) >= 2
        out{end+1} = sprintf('Y: %.6g', pos(2)); %#ok<AGROW>
    end
end
end
