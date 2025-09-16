function varargout = combine_sparam_lowpass(varargin)
% combine_sparam_lowpass  sparam 파트 파일(…part001~004)을 병합하고 저역통과 필터 적용
%
% 사용법
%   [time_s, s11, s11_lp] = combine_sparam_lowpass(dataDir, 'CutoffHz', 1, 'Save', true, 'Plot', true)
%
% 입력
%   dataDir   : 'sparam_data_part001.mat' 들이 있는 폴더 경로
%               (생략 또는 빈 값이면 폴더 선택 창이 뜹니다)
%
% 옵션 (Name-Value)
%   'CutoffHz': 저역통과 목표 차단 주파수(Hz, 기본 0.005 Hz). IIR(기본 Elliptic)
%               필터의 차단 주파수입니다.
%   'Freq'    : 추출할 기준 주파수 값 또는 벡터(기본 24:0.1:24.5, 'FreqUnit'에 따름)
%   'FreqUnit': 'GHz' 또는 'Hz' (기본 'GHz')
%   'PhaseUnit': 'deg' 또는 'rad' (기본 'deg')
%   'PhasePlotUnit': 플롯용 위상 단위 'deg'|'rad' (기본 'deg')
%   'UseTime' : 'auto'|'timestamps'|'elapsed' (기본 'auto')
%   'PlotTemp': 온도 시계열을 1행에 함께 표시 (기본 true)
%   'TempDir' : 온도 CSV가 있는 폴더(기본 dataDir의 상위 폴더)
%   'TempPattern': 온도 CSV 파일명 (기본 'Temp.csv' 고정)
%   'TempChanConfig': 채널 선택 CSV 경로(없으면 생성; 기본 TempDir/TempChannelSelection.csv)
%   'SaveFig' : 플롯을 파일로 저장 (기본 true, fig 형식)
%   'FigFormats': 저장 형식 셀배열 (예: {'fig','png'})
%   'Param'   : 'S11' | 'S22' | 'both' (기본 'both')
%   'Save'    : 결과를 dataDir 아래 'sparam_combined_filtered_<param>[,_bandstop].mat'로 저장 (기본 true)
%   'Plot'    : 원신호/필터 신호 간단 플롯 (기본 true)
%   'FilterMode': 'centered'| 'causal' (기본 'causal')
%   'FilterOrder': IIR 필터 차수(정수, 기본 4)
%   'FilterDesign': 'elliptic' | 'butter' | 'bessel' | 'notch' (기본 'elliptic')
%   'EllipRp_dB': Elliptic 통과대역 리플(dB, 기본 1)
%   'EllipRs_dB': Elliptic 저지대역 감쇠(dB, 기본 40)
%   'NotchQ'    : Notch(Q) 지정(기본 NaN → BandstopHz로 3 dB 대역폭 결정)
%   'FilterType': 'lowpass' | 'bandstop' (기본 'lowpass'). 미지정 시 콘솔에서 선택(1/2).
%   'BandstopHz': 밴드저지 구간 [f1 f2] Hz (FilterType='bandstop'일 때 필수, 미지정 시 콘솔 입력). 최근 입력값을 기억하여 기본값으로 제안.
%   'RunWavelet': 처리 후 wavelet 스펙트로그램도 자동 생성 (기본 true)
%   'WaveletAskWindow': wavelet 창 선택 대화(기본 false=전체 구간)
%   'WaveletSaveFig': wavelet 도식 저장 (기본 SaveFig와 동일)
%   'WaveletFigFormats': wavelet 저장 형식(기본 FigFormats와 동일)
%   'WaveletUseFiltered': wavelet에서 필터 신호 사용 여부 (기본 false=원신호 사용)
%   'PlotFilterResponse': 사용된 디지털 필터 응답도 별도 Figure로 플롯 (기본 true)
%   'SaveFilterFig': 필터 응답 Figure 저장 (기본 SaveFig와 동일)
%   'DerivSmooth': 순간변화율에도 저역통과 적용 (기본 false)
%   'DerivCutoffHz': 변화율 저역통과 차단(Hz, 기본 CutoffHz*1.5)
%   'DerivFilterMode': 'centered'|'causal' (기본 'causal')
%   'DerivFilterOrder': Butterworth 차수(정수, 기본 FilterOrder)
%   'ShowEvents': 순간변화율 이벤트 마커 표시 (기본 true)
%   'EventMagThresh': |d|S||/dt 임계값(dB/s, 비우면 자동 추정)
%   'EventPhaseThresh': |d∠|/dt 임계값(rad/s, 비우면 자동 추정)
%   'EventMinSepSec': 이벤트 최소 간격(초, 기본 5*dt)
%   'EventThreshK': 자동 임계 배수 K (기본 7 → K*MAD)
%   'EventScope': 'global'|'local' (기본 'local')
%   'EventLocalSpanSec': 로컬 임계 계산 시 과거 창 길이(초, 기본 1800=30분)
%
% 출력
%   time_s : 초 단위 시간 벡터(모든 파트 병합, 시작 기준 0 s)
%   s11    : 병합된 S11 원신호 (복소/실수 지원). sparam .mat 구조일 경우
%            지정 주파수(들)에서의 S11 시계열 [Nt x NfSel] (복소).
%   s11_lp : 저역통과(Butterworth) 필터 적용 신호
%
% 비고
% - part001~004 형식의 .mat 파일을 자동 탐색/자연 정렬합니다.
% - .mat 내부 변수명은 가급적 'time'/'s11'을 탐색하며, 대소문자/변형명을 넓게 매칭합니다.
% - S11이 복소일 경우 실/허수 각각에 동일 필터를 적용합니다.
% - 추가 전처리(중복 timestamp 제거, 정렬) 포함.
% - 최근 입력값(필터 유형/차단주파수/밴드저지 대역)을 폴더별로 기억하여 기본값으로 제안합니다.
%
% 예시
%   dataDir = fullfile('expdata', '2025-09-05 - patch pork2', 'sParam');
%   combine_sparam_lowpass(dataDir, 'CutoffHz', 0.5, 'Freq', [9.61 24], 'FreqUnit', 'GHz');

% helper 경로 추가(functions_lowpass) — 최상단에서 추가하여 초기 호출에서도 사용 가능
thisDir = fileparts(mfilename('fullpath'));
helperDir = fullfile(thisDir, 'functions_lowpass');
if exist(helperDir, 'dir') == 7 && isempty(strfind(path, helperDir)) %#ok<STREMP>
    addpath(helperDir);
end

% 첫 인자에서 dataDir 추론 (존재하는 폴더일 때만), 나머지는 Name-Value
dataDir = [];
argStart = 1;
if nargin >= 1 && (ischar(varargin{1}) || isstring(varargin{1}))
    cand = char(varargin{1});
    if exist(cand, 'dir') == 7
        dataDir = cand;
        argStart = 2;
    end
end

% 폴더 선택(입력 생략 시): expdata 아래 후보 목록에서 선택
if isempty(dataDir)
    baseExp = fullfile(thisDir, 'expdata');
    if exist(baseExp, 'dir') ~= 7
        baseExp = fullfile(pwd, 'expdata');
    end
    if exist(baseExp, 'dir') ~= 7
        error('combine_sparam_lowpass:NoExpdataDir','expdata 폴더를 찾을 수 없습니다.');
    end
    dataDir = local_select_expdata_dir(baseExp);
end

% 옵션 파싱
p = inputParser;
addParameter(p, 'CutoffHz', 0.005, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'Save', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Plot', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'Freq', 24:0.1:24.5, @(x) isnumeric(x) && isvector(x) && all(x > 0));
addParameter(p, 'FreqUnit', 'GHz', @(s) ischar(s) || isstring(s));
addParameter(p, 'PhaseUnit', 'deg', @(s) ischar(s) || isstring(s));
addParameter(p, 'PhasePlotUnit', 'deg', @(s) ischar(s) || isstring(s));
addParameter(p, 'UseTime', 'auto', @(s) ischar(s) || isstring(s));
addParameter(p, 'PlotTemp', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'TempDir', '', @(s) ischar(s) || isstring(s));
addParameter(p, 'TempPattern', 'Temp.csv', @(s) ischar(s) || isstring(s));
addParameter(p, 'TempChanConfig', '', @(s) ischar(s) || isstring(s));
addParameter(p, 'SaveFig', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'FigFormats', {'fig'}, @(c) iscell(c) || isstring(c));
addParameter(p, 'Param', 'both', @(s) ischar(s) || isstring(s));
addParameter(p, 'FilterMode', 'causal', @(s) ischar(s) || isstring(s));
addParameter(p, 'FilterOrder', 4, @(x) isnumeric(x) && isscalar(x) && x == round(x) && x > 0);
addParameter(p, 'FilterDesign', 'elliptic', @(s) ischar(s) || isstring(s));
addParameter(p, 'EllipRp_dB', 1, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'EllipRs_dB', 40, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'NotchQ', NaN, @(x) isnumeric(x) && isscalar(x) && (isnan(x) || x > 0));
addParameter(p, 'FilterType', 'lowpass', @(s) ischar(s) || isstring(s));
addParameter(p, 'BandstopHz', [NaN NaN], @(x) isnumeric(x) && (isscalar(x) || numel(x)==2));
addParameter(p, 'RunWavelet', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'WaveletAskWindow', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'WaveletSaveFig', NaN, @(x) (islogical(x) && isscalar(x)) || (isnan(x) && isscalar(x)));
addParameter(p, 'WaveletFigFormats', [], @(c) iscell(c) || isstring(c));
addParameter(p, 'WaveletUseFiltered', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'PlotFilterResponse', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'SaveFilterFig', NaN, @(x) (islogical(x) && isscalar(x)) || (isnan(x) && isscalar(x)));
addParameter(p, 'DerivSmooth', false, @(x) islogical(x) && isscalar(x));
addParameter(p, 'DerivCutoffHz', NaN, @(x) isnumeric(x) && isscalar(x) && (isnan(x) || x > 0));
addParameter(p, 'DerivFilterMode', 'causal', @(s) ischar(s) || isstring(s));
addParameter(p, 'DerivFilterOrder', NaN, @(x) isnumeric(x) && isscalar(x) && (isnan(x) || (x == round(x) && x > 0)));
addParameter(p, 'ShowEvents', true, @(x) islogical(x) && isscalar(x));
addParameter(p, 'EventMagThresh', NaN, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'EventPhaseThresh', NaN, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'EventMinSepSec', NaN, @(x) isnumeric(x) && isscalar(x) && (isnan(x) || x >= 0));
addParameter(p, 'EventThreshK', 20, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'EventScope', 'local', @(s) ischar(s) || isstring(s));
addParameter(p, 'EventLocalSpanSec', 1800, @(x) isnumeric(x) && isscalar(x) && x > 0);
% Relative-extreme event options
addParameter(p, 'RelWindowSec', 1800, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'RelMultiple', 1.5, @(x) isnumeric(x) && isscalar(x) && x > 0);
addParameter(p, 'EventPolarity', 'both', @(s) ischar(s) || isstring(s));
parse(p, varargin{argStart:end});
cutoffHz = p.Results.CutoffHz;
doSave   = p.Results.Save;
doPlot   = p.Results.Plot;
freqVal  = p.Results.Freq;
freqUnit = lower(string(p.Results.FreqUnit));
phaseUnit= lower(string(p.Results.PhaseUnit));
phasePlotUnit = lower(string(p.Results.PhasePlotUnit));
useTime  = lower(string(p.Results.UseTime));
plotTemp = p.Results.PlotTemp;
tempDirIn= string(p.Results.TempDir);
tempPattern = string(p.Results.TempPattern);
tempChanCfg = string(p.Results.TempChanConfig);
saveFig  = p.Results.SaveFig;
figFormats = cellstr(p.Results.FigFormats);
paramSel = upper(string(p.Results.Param));
filterMode = lower(string(p.Results.FilterMode));
filtOrder  = p.Results.FilterOrder;
derivSmooth = p.Results.DerivSmooth;
filterType = lower(string(p.Results.FilterType));
bandstopHz = p.Results.BandstopHz;
filterDesign = lower(string(p.Results.FilterDesign));
ellipRp = p.Results.EllipRp_dB;
ellipRs = p.Results.EllipRs_dB;
notchQ  = p.Results.NotchQ;
runWavelet = p.Results.RunWavelet;
waveAskWin = p.Results.WaveletAskWindow;
waveSaveFigOpt = p.Results.WaveletSaveFig;
waveFigFormatsOpt = p.Results.WaveletFigFormats;
waveUseFiltered = p.Results.WaveletUseFiltered;
plotFilterResp = p.Results.PlotFilterResponse;
saveFilterFigOpt = p.Results.SaveFilterFig;
derivCutoffHz = p.Results.DerivCutoffHz;
derivMode  = lower(string(p.Results.DerivFilterMode));
derivOrder = p.Results.DerivFilterOrder;
showEvents = p.Results.ShowEvents;
eventMagThresh = p.Results.EventMagThresh;
eventPhaseThresh = p.Results.EventPhaseThresh;
eventMinSepSec = p.Results.EventMinSepSec;
eventK = p.Results.EventThreshK;
eventScope = lower(string(p.Results.EventScope));
eventLocalSpan = p.Results.EventLocalSpanSec;
relWindowSec = p.Results.RelWindowSec;
relMultiple = p.Results.RelMultiple;
eventPolarity = lower(string(p.Results.EventPolarity));
if ~(paramSel == "S11" || paramSel == "S22" || paramSel == "BOTH")
    error('combine_sparam_lowpass:BadParam', 'Param은 S11, S22 또는 both만 지원합니다.');
end
if ~(filterMode == "centered" || filterMode == "causal")
    error('combine_sparam_lowpass:BadFilterMode', 'FilterMode는 centered 또는 causal만 지원합니다.');
end
if ~(filterType == "lowpass" || filterType == "bandstop")
    error('combine_sparam_lowpass:BadFilterType', 'FilterType은 lowpass 또는 bandstop만 지원합니다.');
end
if ~(filterDesign == "elliptic" || filterDesign == "butter" || filterDesign == "bessel" || filterDesign == "notch")
    error('combine_sparam_lowpass:BadFilterDesign', 'FilterDesign은 elliptic|butter|bessel|notch 중 하나여야 합니다.');
end

% 필터 유형/대역 제공 여부 확인
providedFilterType = false; providedBandstop = false;
if numel(varargin) >= argStart
    nvScan = varargin(argStart:end);
    for kk = 1:2:numel(nvScan)
        if kk <= numel(nvScan) && (ischar(nvScan{kk}) || isstring(nvScan{kk}))
            key = lower(string(nvScan{kk}));
            if key == "filtertype", providedFilterType = true; end
            if key == "bandstophz", providedBandstop = true; end
        end
    end
end
if ~(derivMode == "centered" || derivMode == "causal")
    error('combine_sparam_lowpass:BadDerivFilterMode', 'DerivFilterMode는 centered 또는 causal만 지원합니다.');
end
if isnan(derivCutoffHz)
    derivCutoffHz = cutoffHz * 1.5;
end
if isnan(derivOrder)
    derivOrder = filtOrder;
end

% 사용자 입력 프롬프트 (명시 NV 없을 때)
% 1) 필터 유형 선택
% 최근 입력값 로드(폴더별 저장)
prefs = struct('lastFilterType', '', 'lastCutoffHz', NaN, 'lastBandstopHz', [NaN NaN]);
try
    prefs = local_load_prefs(dataDir, prefs);
catch, end

if ~providedFilterType
    try
        fprintf('필터 유형 선택:\n');
        fprintf('  1) lowpass (저역통과)\n');
        fprintf('  2) bandstop (밴드저지)\n');
        defNum = 1;
        if isfield(prefs,'lastFilterType') && strcmpi(char(prefs.lastFilterType), 'bandstop')
            defNum = 2;
        end
        resp = input(sprintf('번호 입력 (1/2) [Enter=%d]: ', defNum), 's');
        r = strtrim(resp);
        if strcmp(r,'2')
            filterType = "bandstop";
        elseif strcmp(r,'1')
            filterType = "lowpass";
        elseif isempty(r)
            % Enter 입력은 표시된 기본 번호를 그대로 선택
            if defNum == 2
                filterType = "bandstop";
            else
                filterType = "lowpass";
            end
        else
            % 알 수 없는 입력일 때도 기본 번호를 선택
            if defNum == 2
                defName = 'bandstop';
                filterType = "bandstop";
            else
                defName = 'lowpass';
                filterType = "lowpass";
            end
            fprintf('입력을 해석하지 못해 기본값(%d=%s)을 사용합니다.\n', defNum, defName);
        end
        try, prefs.lastFilterType = char(filterType); catch, end
    catch
        % 입력 실패 시 기존 기본값 유지
    end
end

% 2) 각 유형별 추가 파라미터 프롬프트
cutoffProvided = false; bandstopProvided = false;
if numel(varargin) >= argStart
    nv = varargin(argStart:end);
    for ii = 1:2:numel(nv)
        if ii <= numel(nv) && ischar(nv{ii})
            if strcmpi(nv{ii}, 'CutoffHz'), cutoffProvided = true; end
            if strcmpi(nv{ii}, 'BandstopHz'), bandstopProvided = true; end
        end
    end
else
    nv = {};
end
if filterType == "lowpass" && ~cutoffProvided
    try
        % 기본값: 최근 사용값 -> 현재 기본값 순
        defCut = cutoffHz;
        if isfield(prefs,'lastCutoffHz') && isfinite(prefs.lastCutoffHz) && prefs.lastCutoffHz > 0
            defCut = prefs.lastCutoffHz;
        end
        prompt = sprintf('저역통과 차단주파수(Hz) 입력 [Enter=기본 %.6g]: ', defCut);
        resp = input(prompt, 's');
        resp = strtrim(resp);
        if isempty(resp)
            cutoffHz = defCut;
        else
            v = str2double(resp);
            if isfinite(v) && v > 0
                cutoffHz = v;
            else
                fprintf('유효하지 않은 값입니다. 기본값 %.6g Hz를 사용합니다.\n', cutoffHz);
            end
        end
        try, prefs.lastCutoffHz = cutoffHz; catch, end
    catch
        % 프롬프트 실패 시 기본값 유지
    end
elseif filterType == "bandstop" && ~bandstopProvided
    try
        % 기본값: 최근 사용 구간
        if isfield(prefs,'lastBandstopHz') && numel(prefs.lastBandstopHz) == 2 && all(isfinite(prefs.lastBandstopHz))
            prompt = sprintf('밴드저지 구간 입력 (Hz) [f1 f2, Enter=기본 %.6g %.6g]: ', prefs.lastBandstopHz(1), prefs.lastBandstopHz(2));
        else
            prompt = '밴드저지 구간 입력 (Hz) [f1 f2, 예: 0.01 0.05]: ';
        end
        resp = input(prompt, 's');
        resp = strtrim(resp);
        if isempty(resp)
            % Enter: 최근 값이 있으면 채택
            if isfield(prefs,'lastBandstopHz') && numel(prefs.lastBandstopHz)==2 && all(isfinite(prefs.lastBandstopHz))
                bandstopHz = prefs.lastBandstopHz;
            else
                fprintf('입력이 없어 기본/명시값을 사용합니다.\n');
            end
        else
            vals = sscanf(resp, '%f');
            if numel(vals) >= 2
                f1 = vals(1); f2 = vals(2);
                if isfinite(f1) && isfinite(f2) && f1 > 0 && f2 > 0 && f1 < f2
                    bandstopHz = [f1 f2];
                else
                    fprintf('유효하지 않은 구간입니다. 형식: 0<f1<f2. 입력을 무시합니다.\n');
                end
            else
                fprintf('입력이 없어 기본/명시값을 사용합니다.\n');
            end
        end
        if numel(bandstopHz) == 2 && all(isfinite(bandstopHz)) && bandstopHz(1) > 0 && bandstopHz(2) > 0 && bandstopHz(1) < bandstopHz(2)
            try, prefs.lastBandstopHz = bandstopHz; catch, end
        end
    catch
        % 입력 실패 시 그대로 둠
    end
end

% 프롬프트 후, 최근값 저장 시도 (NV로 전달된 값도 반영)
try
    prefs.lastFilterType = char(filterType);
    if filterType == "lowpass"
        if isfinite(cutoffHz) && cutoffHz > 0
            prefs.lastCutoffHz = cutoffHz;
        end
    elseif filterType == "bandstop"
        if numel(bandstopHz) == 2 && all(isfinite(bandstopHz)) && bandstopHz(1) > 0 && bandstopHz(2) > 0 && bandstopHz(1) < bandstopHz(2)
            prefs.lastBandstopHz = bandstopHz;
        end
    end
    local_save_prefs(dataDir, prefs);
catch
end

% Param='both'이면 각각 호출하여 별도 Figure를 생성하고 종료
if paramSel == "BOTH"
    % 원래 전달된 Name-Value 목록 복원
    nv = {};
    if numel(varargin) >= argStart
        nv = varargin(argStart:end);
    end
    % CutoffHz가 인자로 없었다면, 위에서 확정된 cutoffHz를 전달해 중복 프롬프트 방지 (lowpass일 때만 의미)
    hasCut = false;
    for ii = 1:2:numel(nv)
        if ii <= numel(nv) && ischar(nv{ii}) && strcmpi(nv{ii}, 'CutoffHz')
            hasCut = true; break;
        end
    end
    if ~hasCut && filterType == "lowpass"
        nv = [nv, {'CutoffHz', cutoffHz}]; %#ok<AGROW>
    end
    % FilterType/BandstopHz 전파: bandstop일 때 두 번째 호출에서 재프롬프트 방지
    hasFT = false; hasBS = false;
    for ii = 1:2:numel(nv)
        if ii <= numel(nv) && ischar(nv{ii})
            if strcmpi(nv{ii}, 'FilterType'), hasFT = true; end
            if strcmpi(nv{ii}, 'BandstopHz'), hasBS = true; end
        end
    end
    if ~hasFT
        nv = [nv, {'FilterType', char(filterType)}]; %#ok<AGROW>
    end
    if filterType == "bandstop" && ~hasBS
        if numel(bandstopHz) == 2 && all(isfinite(bandstopHz)) && bandstopHz(1) > 0 && bandstopHz(2) > 0 && bandstopHz(1) < bandstopHz(2)
            nv = [nv, {'BandstopHz', bandstopHz}]; %#ok<AGROW>
        else
            % 안전상 빈 값은 넣지 않음: 두 번째 호출에서 다시 프롬프트되겠지만, 사용자가 첫 호출에서 입력했다면 bandstopHz는 유효할 것
        end
    end
    % 실행 순서: S11, S22 (출력 요청 시 S11을 반환)
    nvS11 = local_set_param_nv(nv, 'S11');
    nvS22 = local_set_param_nv(nv, 'S22');
    % Temp 채널 설정 CSV를 포트별로 분리 저장/사용
    try
        % 기준 디렉터리 결정 → 단일 공통 파일 사용
        cfgBaseDir = "";
        if exist('tempChanCfg','var') && strlength(tempChanCfg) > 0
            cfgBaseDir = string(fileparts(char(tempChanCfg)));
        elseif exist('tempDirIn','var') && strlength(tempDirIn) > 0
            cfgBaseDir = tempDirIn;
        else
            cfgBaseDir = string(fileparts(dataDir));
        end
        cfgCommon = string(fullfile(char(cfgBaseDir), 'TempChannelSelection.csv'));
        nvS11 = local_set_nv(nvS11, 'TempChanConfig', char(cfgCommon));
        nvS22 = local_set_nv(nvS22, 'TempChanConfig', char(cfgCommon));
    catch
        % 실패 시 무시하고 기본 동작
    end
    if nargout > 0
        warning('combine_sparam_lowpass:BothNoMultiOut', 'Param="both"에서는 출력 인자를 S11 결과로만 반환합니다.');
        if ~isempty(dataDir) && exist(dataDir,'dir') == 7
            [varargout{1:nargout}] = combine_sparam_lowpass(dataDir, nvS11{:});
        else
            [varargout{1:nargout}] = combine_sparam_lowpass(nvS11{:});
        end
    else
        if ~isempty(dataDir) && exist(dataDir,'dir') == 7
            combine_sparam_lowpass(dataDir, nvS11{:});
        else
            combine_sparam_lowpass(nvS11{:});
        end
    end
    if ~isempty(dataDir) && exist(dataDir,'dir') == 7
        combine_sparam_lowpass(dataDir, nvS22{:});
    else
        combine_sparam_lowpass(nvS22{:});
    end
    return;
end

% helper 경로 추가(functions_lowpass)
thisDir = fileparts(mfilename('fullpath'));
helperDir = fullfile(thisDir, 'functions_lowpass');
if exist(helperDir, 'dir') == 7 && isempty(strfind(path, helperDir)) %#ok<STREMP>
    addpath(helperDir);
end

if freqUnit == "ghz"
    freqHz = freqVal(:).' * 1e9;
elseif freqUnit == "hz"
    freqHz = freqVal(:).';
else
    error('combine_sparam_lowpass:BadFreqUnit', 'FreqUnit은 Hz 또는 GHz만 지원합니다.');
end

% 파일 검색 (part001~). 없으면 sparam_data.mat 폴백
files = dir(fullfile(dataDir, 'sparam_data_part*.mat'));
if isempty(files)
    fallback = dir(fullfile(dataDir, 'sparam_data.mat'));
    if isempty(fallback)
        error('combine_sparam_lowpass:NoFiles', '폴더에 sparam_data_part*.mat 또는 sparam_data.mat 파일이 없습니다: %s', dataDir);
    else
        files = fallback; % 단일 파일 처리
    end
end

% 자연 정렬: part 숫자 기준 (단일 파일은 그대로)
if numel(files) > 1
    partNums = arrayfun(@(f) local_get_part_num(f.name), files);
    [~, order] = sort(partNums);
    files = files(order);
end

% 병합 컨테이너
all_t = [];
all_s = [];
elapsed_offset = 0; % TimeElapsed 기반일 때 누적 오프셋(sec)
all_dt = datetime.empty(0,1);
selFreqHz = [];

% 각 파트 로드/추출/병합
for k = 1:numel(files)
    fpath = fullfile(files(k).folder, files(k).name);
    S = load(fpath);

    % sparam 형식 우선 시도
    [ok_sparam, t_k, s_k, elapsed_used, dt_k, selHz_k] = local_extract_from_sparam(S, freqHz, phaseUnit, useTime, paramSel);
    if ~ok_sparam
        % 일반 time/s11 탐색 백업 경로
        [t_k, s_k] = local_extract_time_s11(S);
    else
        % TimeElapsed 기반을 사용했다면 누적 오프셋 부여
        if strcmp(elapsed_used, 'elapsed+offset')
            t_k = t_k + elapsed_offset;
            elapsed_offset = max(t_k);
        end
        if isempty(selFreqHz) && ~isempty(selHz_k)
            selFreqHz = selHz_k(:).';
            if numel(selFreqHz) < numel(freqHz)
                warning('combine_sparam_lowpass:FreqCollapse', ...
                    '요청한 주파수 %d개가 최근접 매칭으로 %d개로 축소되었습니다. (데이터 그리드 해상도 때문) 더 많은 곡선을 원하면 주파수 범위를 넓히거나 간격을 키우거나, 주파수 보간(interp) 옵션 추가를 요청하세요.', ...
                    numel(freqHz), numel(selFreqHz));
            end
        end
    end
    if isempty(t_k) || isempty(s_k)
        topFields = strjoin(fieldnames(S), ', ');
        error('combine_sparam_lowpass:MissingVars', '필드에서 time/s11을 찾지 못했습니다: %s (상위 변수: %s)', fpath, topFields);
    end

    % 길이/형상 정규화 및 검사 (다주파수 열 지원)
    t_k = t_k(:);
    if isvector(s_k)
        if numel(s_k) ~= numel(t_k)
            error('combine_sparam_lowpass:LengthMismatch', '시간(%d)과 S11(%d) 길이가 다릅니다 (%s)', numel(t_k), numel(s_k), fpath);
        end
        s_k = s_k(:);
    else
        % 행열 치환 검사: 행이 시간축이 되도록 정규화
        if size(s_k,1) == numel(t_k)
            % ok
        elseif size(s_k,2) == numel(t_k)
            s_k = s_k.'; % 전치하여 [Nt x Nf]
        else
            error('combine_sparam_lowpass:LengthMismatch', '시간(%d)과 S11 행/열(%dx%d) 불일치 (%s)', numel(t_k), size(s_k,1), size(s_k,2), fpath);
        end
    end

    % 선택 주파수 정렬(파트 간 컬럼 일치화)
    if ~isempty(selFreqHz) && exist('selHz_k','var') && ~isempty(selHz_k) && size(s_k,2) > 1
        % 현재 파트 선택 주파수를 기준 주파수 순서(selFreqHz)에 맞게 재정렬
        map = zeros(1, numel(selFreqHz));
        for jj = 1:numel(selFreqHz)
            [~, map(jj)] = min(abs(selHz_k(:).' - selFreqHz(jj)));
        end
        s_k = s_k(:, map);
    end

    all_t = [all_t; t_k]; %#ok<AGROW>
    % all_s 초기화 또는 열수 확인 후 결합
    if isempty(all_s)
        all_s = s_k;
    else
        % 열 수 불일치 시 NaN 패딩
        nc = size(all_s,2);
        nk = size(s_k,2);
        if nk < nc
            s_k(:, end+1:nc) = NaN;
        elseif nk > nc
            all_s(:, end+1:nk) = NaN;
        end
        all_s = [all_s; s_k]; %#ok<AGROW>
    end
    if exist('dt_k','var') && ~isempty(dt_k)
        all_dt = [all_dt; dt_k(:)]; %#ok<AGROW>
    else
        % 자리맞춤: 길이만큼 NaT 추가
        all_dt = [all_dt; NaT(numel(t_k),1)]; %#ok<AGROW>
    end
end

% 시간 단위 정규화: 초 단위 double 벡터로 통일
time_s = local_to_seconds(all_t);

% 시간 기준 정렬 및 중복 제거
[time_s, idxSort] = sort(time_s(:), 'ascend');
s11 = all_s(idxSort, :);
all_dt = all_dt(idxSort);

% 완전 중복 타임스탬프 제거(첫 항목 유지)
[time_s, idxUniq] = unique(time_s, 'stable');
s11 = s11(idxUniq, :);
all_dt = all_dt(idxUniq);

% 시작을 0 s로 정렬
time_s = time_s - time_s(1);

% 가능하면 datetime 타임스탬프 구성 (timestamps 사용 시)
has_dt = any(~isnat(all_dt));
if has_dt
    time_dt = all_dt; %#ok<NASGU>
else
    time_dt = NaT(size(time_s)); %#ok<NASGU>
end

% 샘플링 주파수 추정
if numel(time_s) < 3
    error('combine_sparam_lowpass:TooFewSamples', '샘플이 너무 적습니다. 최소 3개 필요.');
end
dt = median(diff(time_s));
if ~isfinite(dt) || dt <= 0
    error('combine_sparam_lowpass:BadTime', '시간 간격을 추정할 수 없습니다.');
end
fs = 1/dt;

% IIR 필터 설계/적용 (Signal Processing Toolbox) — 기본 Elliptic
switch filterType
    case "lowpass"
        Wn = cutoffHz / (fs/2);
        if ~isfinite(Wn) || Wn <= 0
            error('combine_sparam_lowpass:BadCutoff','CutoffHz가 유효하지 않습니다.');
        end
        if Wn >= 1
            warning('combine_sparam_lowpass:CutoffTooHigh','Cutoff가 Nyquist를 초과/접근합니다. 0.99로 제한합니다.');
            Wn = min(Wn, 0.99);
        end
        switch filterDesign
            case "elliptic"
                [b,a] = ellip(filtOrder, ellipRp, ellipRs, Wn, 'low');
            case "butter"
                [b,a] = butter(filtOrder, Wn, 'low');
            case "bessel"
                % Analog Bessel proto → bilinear transform (prewarped cutoff)
                wc = 2*fs*tan(pi*Wn);
                [ba, aa] = besself(double(filtOrder), double(wc));
                [b, a] = bilinear(ba, aa, fs);
            case "notch"
                % Notch는 bandstop 의미 없으므로 lowpass 요청 시 오류
                error('combine_sparam_lowpass:BadDesignForLowpass','FilterDesign=notch는 FilterType=bandstop에서만 사용하세요.');
        end
    case "bandstop"
        if isscalar(bandstopHz)
            error('combine_sparam_lowpass:BandstopPair', 'BandstopHz는 [f1 f2] 두 값(Hz)이어야 합니다.');
        end
        if numel(bandstopHz) ~= 2
            error('combine_sparam_lowpass:BandstopSize', 'BandstopHz 크기는 2여야 합니다.');
        end
        f1 = min(bandstopHz(:)); f2 = max(bandstopHz(:));
        if ~isfinite(f1) || ~isfinite(f2) || f1 <= 0 || f2 <= 0 || f1 >= f2
            error('combine_sparam_lowpass:BandstopInvalid', 'BandstopHz=[f1 f2]는 0<f1<f2 이어야 합니다.');
        end
        switch filterDesign
            case {"elliptic","butter"}
                Wn = [f1 f2] / (fs/2);
                if Wn(2) >= 1
                    warning('combine_sparam_lowpass:BandstopTooHigh','Bandstop 상한이 Nyquist를 초과/접근합니다. 0.99로 제한합니다.');
                    Wn(2) = min(Wn(2), 0.99);
                end
                if Wn(1) <= 0
                    warning('combine_sparam_lowpass:BandstopTooLow','Bandstop 하한이 0 또는 음수입니다. 0.001로 올립니다.');
                    Wn(1) = max(Wn(1), 0.001);
                end
                if ~(Wn(1) < Wn(2))
                    error('combine_sparam_lowpass:BandstopNormalizedInvalid','정규화된 대역이 올바르지 않습니다.');
                end
                if filterDesign == "elliptic"
                    [b,a] = ellip(filtOrder, ellipRp, ellipRs, Wn, 'stop');
                else
                    [b,a] = butter(filtOrder, Wn, 'stop');
                end
            case "bessel"
                % Analog Bessel LP proto -> bandstop transform -> bilinear
                % Prewarp edges to analog rad/s
                Om1 = 2*fs*tan(pi*f1/fs);
                Om2 = 2*fs*tan(pi*f2/fs);
                wo = sqrt(Om1*Om2);
                bw = Om2 - Om1;
                [ba, aa] = besself(double(filtOrder), 1); % normalized
                [bbs, abs_] = lp2bs(ba, aa, wo, bw);
                [b, a] = bilinear(bbs, abs_, fs);
            case "notch"
                % Design single biquad notch
                f0 = (f1 + f2)/2;
                W0 = f0 / (fs/2);
                if ~isnan(notchQ) && notchQ > 0
                    BW = W0 / notchQ;
                else
                    BW = (f2 - f1) / (fs/2);
                end
                if W0 <= 0 || W0 >= 1 || BW <= 0
                    error('combine_sparam_lowpass:NotchBadParams','Notch 파라미터가 유효하지 않습니다. W0=%.6g, BW=%.6g', W0, BW);
                end
                [b, a] = iirnotch(W0, BW);
        end
end
switch filterMode
    case "centered"
        % zero-phase (filtfilt)
        s11_filt = filtfilt(b, a, real(s11)) + 1i*filtfilt(b, a, imag(s11));
    case "causal"
        % 한 방향 인과 필터
        s11_filt = filter(b, a, real(s11)) + 1i*filter(b, a, imag(s11));
end
% 기존 출력/저장 호환을 위해 이름 유지
s11_lp = s11_filt;

% 저장 옵션
if doSave
    paramSuffix = lower(char(paramSel));
    % 결합/필터 결과 MAT은 실험 폴더의 results 아래에 저장
    try
        [parentDir, baseName] = fileparts(dataDir);
        if strcmpi(baseName, 'sParam')
            expBase = parentDir;
        else
            expBase = dataDir;
        end
        outDir = fullfile(expBase, 'results');
        if exist(outDir,'dir') ~= 7, mkdir(outDir); end
    catch
        outDir = dataDir;
    end
    if filterType == "bandstop"
        outPath = fullfile(outDir, sprintf('sparam_combined_filtered_%s_bandstop.mat', paramSuffix));
    else
        outPath = fullfile(outDir, sprintf('sparam_combined_filtered_%s.mat', paramSuffix));
    end
    cutoffHz_used = cutoffHz; %#ok<NASGU>
    fs_est = fs;           %#ok<NASGU>
    filtOrder_used = filtOrder; %#ok<NASGU>
    time = time_s;         %#ok<NASGU>
    freqHz_used = selFreqHz; %#ok<NASGU>
    param_used = char(paramSel); %#ok<NASGU>
    filterMode_used = char(filterMode); %#ok<NASGU>
    filterType_used = char(filterType); %#ok<NASGU>
    bandstopHz_used = bandstopHz; %#ok<NASGU>
    derivSmooth_used = logical(derivSmooth); %#ok<NASGU>
    derivCutoffHz_used = derivCutoffHz; %#ok<NASGU>
    derivOrder_used = derivOrder; %#ok<NASGU>
    derivFilterMode_used = char(derivMode); %#ok<NASGU>
    % 이벤트 임계(열별) 변수는 플롯 단계에서 계산되므로, 기본값을 미리 생성
    events_mag_thresh_used = []; %#ok<NASGU>
    events_phase_thresh_used = []; %#ok<NASGU>
    % 이벤트 임계(열별) 저장
    try %#ok<TRYNC>
        events_mag_thresh_used = eventMagThreshVec; %#ok<NASGU>
        events_phase_thresh_used = eventPhaseThreshVec; %#ok<NASGU>
    end
    % 파생량도 저장
    % time_dt가 존재하면 함께 저장 (datetime 타임스탬프)
    try %#ok<TRYNC>
        time_dt_exists = exist('time_dt','var') == 1; %#ok<NASGU>
    end
    if exist('time_dt','var') ~= 1
        time_dt = NaT(size(time)); %#ok<NASGU>
    end
    filterDesign_used = char(filterDesign); %#ok<NASGU>
    ellip_Rp_dB_used = ellipRp; %#ok<NASGU>
    ellip_Rs_dB_used = ellipRs; %#ok<NASGU>
    notchQ_used = notchQ; %#ok<NASGU>
    save(outPath, 'time', 'time_dt', 's11', 's11_lp', 'cutoffHz_used', 'fs_est', 'filtOrder_used', 'freqHz_used', 'param_used', 'filterMode_used', 'filterType_used', 'filterDesign_used', 'ellip_Rp_dB_used', 'ellip_Rs_dB_used', 'notchQ_used', 'bandstopHz_used', 'derivSmooth_used', 'derivCutoffHz_used', 'derivOrder_used', 'derivFilterMode_used', 'events_mag_thresh_used', 'events_phase_thresh_used');
end

% 플롯 옵션
if doPlot
    % 온도 로드 (옵션)
    Ttemp = [];
    if plotTemp
        if strlength(tempDirIn) == 0
            tempDir = string(fileparts(dataDir));
        else
            tempDir = tempDirIn;
        end
        try
            fprintf('온도 데이터 탐색: %s (파일: %s)\n', char(tempDir), char(tempPattern));
            Ttemp = local_load_temperature(tempDir, tempPattern);
        catch ME
            warning('온도 데이터 로드 실패: %s', ME.message);
        end
        % 최종 확인: 없으면 플롯 생략(오직 상위 폴더만 사용)
        hasTemp = false;
        if isstruct(Ttemp)
            hasTemp = isfield(Ttemp,'Time') && ~isempty(Ttemp.Time) && ...
                      isfield(Ttemp,'Values') && ~isempty(Ttemp.Values);
        end
        if ~hasTemp
            fprintf('온도 데이터를 찾지 못했습니다(폴더: %s, 파일: %s). 온도 플롯을 생략합니다.\n', char(tempDir), char(tempPattern));
            Ttemp = [];
        end
    end

    % x축: 타임스탬프 우선, 없으면 초 단위
    use_dt_axis = has_dt && all(~isnat(all_dt));
    if use_dt_axis
        x_sparam = all_dt;
        xlab = 'Time';
    else
        x_sparam = time_s;
        xlab = 'Time (s)';
    end

    % 공통: 새로운 Figure 생성 후 3x2 레이아웃 구성 (온도 없으면 2x2)
    try
        parentDir = fileparts(dataDir);
        [~, usedFolderName] = fileparts(parentDir);
    catch
        usedFolderName = dataDir;
    end
    figName = sprintf('%s combined + lowpass — %s', char(paramSel), usedFolderName);
    f = figure('Name', figName);
    ax = gobjects(0);
    if ~isempty(Ttemp)
        tlo = tiledlayout(3,2,'TileSpacing','compact','Padding','compact');
        title(tlo, figName);
        % 온도 데이터 준비: 채널 설정 CSV가 있으면 불러오고, 없으면 물어봐서 생성
        try
            if strlength(tempChanCfg) == 0
                % 기본 경로: 실제 사용된 TempDir/TempChannelSelection.csv (단일 파일, 포트별 컬럼)
                cfgDir = string(tempDir);
                tempChanCfg = string(fullfile(char(cfgDir), 'TempChannelSelection.csv'));
            end
            % paramSel: S11/S22에 따라 해당 포트 컬럼을 사용
            idxT = resolve_temp_channels_port(Ttemp.Labels, tempChanCfg, char(paramSel));
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
        % Row1 Col1
        nexttile;
        if ~isempty(Ttemp.Time)
            if use_dt_axis
                ax(end+1) = gca; %#ok<AGROW>
                plot(Ttemp.Time, Vplot, 'LineWidth', 1.0);
            else
                ax(end+1) = gca; %#ok<AGROW>
                plot(seconds(Ttemp.Time - Ttemp.Time(1)), Vplot, 'LineWidth', 1.0);
            end
            grid on; ylabel('Temp'); legend(labsPlot, 'Location','best');
        end
        % Row1 Col2 (동일 온도 재표시)
        nexttile;
        if ~isempty(Ttemp.Time)
            if use_dt_axis
                ax(end+1) = gca; %#ok<AGROW>
                plot(Ttemp.Time, Vplot, 'LineWidth', 1.0);
            else
                ax(end+1) = gca; %#ok<AGROW>
                plot(seconds(Ttemp.Time - Ttemp.Time(1)), Vplot, 'LineWidth', 1.0);
            end
            grid on; ylabel('Temp'); legend(labsPlot, 'Location','best');
        end
    else
        tlo = tiledlayout(2,2,'TileSpacing','compact','Padding','compact');
        title(tlo, figName);
    end

    % 크기/위상 및 순간변화율 준비
    mag_raw = 20*log10(abs(s11));
    mag_lp  = 20*log10(abs(s11_lp));
    ph_raw_rad  = unwrap(angle(s11));
    ph_lp_rad   = unwrap(angle(s11_lp));
    if phasePlotUnit == "deg"
        ph_raw = rad2deg(ph_raw_rad);
        ph_lp  = rad2deg(ph_lp_rad);
    else
        ph_raw = ph_raw_rad;
        ph_lp  = ph_lp_rad;
    end
    % 비균일 샘플 간격에도 정확하도록 시간벡터 기반 도함수 사용
    dmag_dt = local_derivative(time_s, mag_lp);
    dph_dt  = local_derivative(time_s, ph_lp); % 플롯 단위와 일치(기본 deg)
    if derivSmooth
        Wn_d = derivCutoffHz / (fs/2);
        if ~isfinite(Wn_d) || Wn_d <= 0
            warning('combine_sparam_lowpass:BadDerivCutoff','DerivCutoffHz가 유효하지 않아 미분 평활을 건너뜁니다.');
        else
            if Wn_d >= 1
                warning('combine_sparam_lowpass:DerivCutoffTooHigh','DerivCutoff가 Nyquist를 초과/접근합니다. 0.99로 제한합니다.');
                Wn_d = min(Wn_d, 0.99);
            end
            [bd, ad] = butter(derivOrder, Wn_d, 'low');
            switch derivMode
                case "centered"
                    dmag_dt = filtfilt(bd, ad, dmag_dt);
                    dph_dt  = filtfilt(bd, ad, dph_dt);
                case "causal"
                    dmag_dt = filter(bd, ad, dmag_dt);
                    dph_dt  = filter(bd, ad, dph_dt);
            end
        end
    end

    % 이벤트 임계값 자동 추정(비어있을 때): robust MAD 기반
    % 열별 임계값 계산 또는 적용
    ncols = size(dmag_dt,2);
    if isnan(eventMagThresh)
        eventMagThreshVec = zeros(1,ncols);
        for c = 1:ncols
            eventMagThreshVec(c) = eventK * local_mad(abs(dmag_dt(:,c)));
        end
    else
        if isscalar(eventMagThresh)
            eventMagThreshVec = repmat(eventMagThresh, 1, ncols);
        elseif numel(eventMagThresh) == ncols
            eventMagThreshVec = reshape(eventMagThresh, 1, []);
        else
            warning('combine_sparam_lowpass:EventMagThreshSize','EventMagThresh 크기가 주파수 수와 다릅니다. 스칼라로 간주합니다.');
            eventMagThreshVec = repmat(eventMagThresh(1), 1, ncols);
        end
    end
    if isnan(eventPhaseThresh)
        eventPhaseThreshVec = zeros(1,ncols);
        for c = 1:ncols
            eventPhaseThreshVec(c) = eventK * local_mad(abs(dph_dt(:,c)));
        end
    else
        if isscalar(eventPhaseThresh)
            eventPhaseThreshVec = repmat(eventPhaseThresh, 1, ncols);
        elseif numel(eventPhaseThresh) == ncols
            eventPhaseThreshVec = reshape(eventPhaseThresh, 1, []);
        else
            warning('combine_sparam_lowpass:EventPhaseThreshSize','EventPhaseThresh 크기가 주파수 수와 다릅니다. 스칼라로 간주합니다.');
            eventPhaseThreshVec = repmat(eventPhaseThresh(1), 1, ncols);
        end
    end
    if isnan(eventMinSepSec)
        eventMinSepSec = 5 * dt;
    end

    % Row2 Col1: Magnitude
    nexttile;
    ax(end+1) = gca; %#ok<AGROW>
    hold on;
    ncols = size(mag_raw,2);
    for c = 1:ncols
        if c == 1
            plot(x_sparam, mag_raw(:,c), '-', 'Color', [0.6 0.6 0.6], 'DisplayName','raw');
        else
            plot(x_sparam, mag_raw(:,c), '-', 'Color', [0.6 0.6 0.6], 'HandleVisibility','off');
        end
    end
    cr = get(gca,'ColorOrder');
    for c = 1:ncols
        co = cr(mod(c-1,size(cr,1))+1,:);
        if filterType == "bandstop"
            tag = 'bs';
        else
            tag = 'lp';
        end
        if ~isempty(selFreqHz)
            dn = sprintf('%s @ %.2f GHz', tag, selFreqHz(c)/1e9);
        else
            dn = sprintf('%s #%d', tag, c);
        end
        plot(x_sparam, mag_lp(:,c), '-', 'Color', co, 'LineWidth', 1.6, 'DisplayName', dn);
    end
    grid on; ylabel(sprintf('|%s| (dB)', char(paramSel))); legend('show','Location','bestoutside');

    % Row2 Col2: Phase
    nexttile;
    ax(end+1) = gca; %#ok<AGROW>
    hold on;
    ncols = size(s11,2);
    for c = 1:ncols
        yraw = ph_raw(:,c);
        if c == 1
            plot(x_sparam, yraw, '-', 'Color', [0.6 0.6 0.6], 'DisplayName','raw ∠');
        else
            plot(x_sparam, yraw, '-', 'Color', [0.6 0.6 0.6], 'HandleVisibility','off');
        end
    end
    cr = get(gca,'ColorOrder');
    for c = 1:ncols
        co = cr(mod(c-1,size(cr,1))+1,:);
        ylp = ph_lp(:,c);
        if filterType == "bandstop"
            tag = 'bs';
        else
            tag = 'lp';
        end
        if ~isempty(selFreqHz)
            dn = sprintf('%s ∠ @ %.2f GHz', tag, selFreqHz(c)/1e9);
        else
            dn = sprintf('%s ∠ #%d', tag, c);
        end
        plot(x_sparam, ylp, '-', 'Color', co, 'LineWidth', 1.6, 'DisplayName', dn);
    end
    if phasePlotUnit == "deg"
        ylabPhase = 'Phase (deg)';
    else
        ylabPhase = 'Phase (rad)';
    end
    grid on; ylabel(ylabPhase); legend('show','Location','bestoutside');

    % Row3 Col1: d|S|/dt
    if ~isempty(Ttemp)
        nexttile;
    else
        % 온도 없으면 Row1 생략으로 인해 여기서는 2x2만 존재 -> 다음은 새 줄 시작
        nexttile;
    end
    ax(end+1) = gca; %#ok<AGROW>
    hold on;
    cr = get(gca,'ColorOrder');
    for c = 1:size(dmag_dt,2)
        co = cr(mod(c-1,size(cr,1))+1,:);
        if ~isempty(selFreqHz)
            dn = sprintf('d|%s|/dt @ %.2f GHz', char(paramSel), selFreqHz(c)/1e9);
        else
            dn = sprintf('d|%s|/dt #%d', char(paramSel), c);
        end
        plot(x_sparam, dmag_dt(:,c), '-', 'Color', co, 'LineWidth', 1.4, 'DisplayName', dn);

        % 이벤트 마커 표시 (peaks + relative)
        if showEvents
            yabs = abs(dmag_dt(:,c));
            minDist = max(1, round(eventMinSepSec/dt));
            % 후보 피크 탐색(높이 제한 없이) 후, 로컬/글로벌 임계로 필터링
            [~, locs] = findpeaks(yabs, 'MinPeakDistance', minDist);
            if ~isempty(locs)
                keep = false(size(locs));
                for kk = 1:numel(locs)
                    if eventScope == "local"
                        tcur = time_s(locs(kk));
                        idxWin = time_s >= max(time_s(1), tcur - eventLocalSpan) & time_s <= tcur;
                        if nnz(idxWin) < 10
                            thr = eventK * local_mad(yabs); % fallback
                        else
                            thr = eventK * local_mad(yabs(idxWin));
                        end
                    else
                        thr = eventMagThreshVec(c);
                    end
                    keep(kk) = yabs(locs(kk)) >= thr;
                end
                locs = locs(keep);
                if ~isempty(locs)
                    xev = x_sparam(locs);
                    yev = dmag_dt(locs, c);
                    plot(xev, yev, 'v', 'Color', co, 'MarkerFaceColor', co, 'HandleVisibility','off');
                    % 글로벌 모드만 기준선 표시
                    if c == 1 && eventScope == "global"
                        yl = ylim;
                        plot(x_sparam, repmat(eventMagThreshVec(c), size(x_sparam)), ':', 'Color', [0.5 0.5 0.5], 'HandleVisibility','off');
                        ylim(yl);
                    end
                end
            end
            % relative-extreme(최근창 최대/최소 n배) 표시: 흰색 내부 원형 마커
            try
                evRel = detect_events_relative_extreme(time_s, dmag_dt(:,c), struct('WindowSec', double(relWindowSec), 'Multiple', double(relMultiple), 'Polarity', char(eventPolarity), 'MinSepSec', double(eventMinSepSec)));
                idxRel = evRel.idx{1};
                if ~isempty(idxRel)
                    plot(x_sparam(idxRel), dmag_dt(idxRel, c), 'o', 'Color', co, 'MarkerFaceColor', 'w', 'HandleVisibility','off');
                end
            catch
            end
        end
    end
    grid on; ylabel('d|S|/dt (dB/s)'); legend('show','Location','bestoutside');

    % Row3 Col2: dPhase/dt
    if ~isempty(Ttemp)
        nexttile;
    else
        nexttile;
    end
    ax(end+1) = gca; %#ok<AGROW>
    hold on;
    cr = get(gca,'ColorOrder');
    for c = 1:size(dph_dt,2)
        co = cr(mod(c-1,size(cr,1))+1,:);
        if ~isempty(selFreqHz)
            dn = sprintf('d∠/dt @ %.2f GHz', selFreqHz(c)/1e9);
        else
            dn = sprintf('d∠/dt #%d', c);
        end
        plot(x_sparam, dph_dt(:,c), '-', 'Color', co, 'LineWidth', 1.4, 'DisplayName', dn);

        % 이벤트 마커 표시 (peaks + relative)
        if showEvents
            yabs = abs(dph_dt(:,c));
            minDist = max(1, round(eventMinSepSec/dt));
            [~, locs] = findpeaks(yabs, 'MinPeakDistance', minDist);
            if ~isempty(locs)
                keep = false(size(locs));
                for kk = 1:numel(locs)
                    if eventScope == "local"
                        tcur = time_s(locs(kk));
                        idxWin = time_s >= max(time_s(1), tcur - eventLocalSpan) & time_s <= tcur;
                        if nnz(idxWin) < 10
                            thr = eventK * local_mad(yabs);
                        else
                            thr = eventK * local_mad(yabs(idxWin));
                        end
                    else
                        thr = eventPhaseThreshVec(c);
                    end
                    keep(kk) = yabs(locs(kk)) >= thr;
                end
                locs = locs(keep);
                if ~isempty(locs)
                    xev = x_sparam(locs);
                    yev = dph_dt(locs, c);
                    plot(xev, yev, '^', 'Color', co, 'MarkerFaceColor', co, 'HandleVisibility','off');
                    if c == 1 && eventScope == "global"
                        yl = ylim;
                        plot(x_sparam, repmat(eventPhaseThreshVec(c), size(x_sparam)), ':', 'Color', [0.5 0.5 0.5], 'HandleVisibility','off');
                        ylim(yl);
                    end
                end
            end
            % relative-extreme 표시
            try
                evRel = detect_events_relative_extreme(time_s, dph_dt(:,c), struct('WindowSec', double(relWindowSec), 'Multiple', double(relMultiple), 'Polarity', char(eventPolarity), 'MinSepSec', double(eventMinSepSec)));
                idxRel = evRel.idx{1};
                if ~isempty(idxRel)
                    plot(x_sparam(idxRel), dph_dt(idxRel, c), 'o', 'Color', co, 'MarkerFaceColor', 'w', 'HandleVisibility','off');
                end
            catch
            end
        end
    end
    if phasePlotUnit == "deg"
        ylabDeriv = 'd∠/dt (deg/s)';
    else
        ylabDeriv = 'd∠/dt (rad/s)';
    end
    grid on; xlabel(xlab); ylabel(ylabDeriv); legend('show','Location','bestoutside');

    if numel(ax) >= 2, linkaxes(ax, 'x'); end
    % 타이틀에 Cutoff/이벤트 정보 추가
    try
        if exist('eventMagThreshVec','var') && exist('eventPhaseThreshVec','var')
            thrMag = median(eventMagThreshVec, 'omitnan');
            thrPh  = median(eventPhaseThreshVec, 'omitnan');
        else
            thrMag = NaN; thrPh = NaN;
        end
        if exist('eventMinSepSec','var')
            minSepVal = eventMinSepSec;
        else
            minSepVal = NaN;
        end
        if phasePlotUnit == "deg"
            unitPh = 'deg/s';
        else
            unitPh = 'rad/s';
        end
        if filterType == "bandstop"
            ttlExtra = sprintf(' | Stop=[%.6g %.6g] Hz | Events: |dS|thr=%.3g dB/s, d∠thr=%.3g %s, minSep=%.3gs', double(bandstopHz(1)), double(bandstopHz(2)), thrMag, thrPh, unitPh, minSepVal);
        else
            ttlExtra = sprintf(' | Cutoff=%.6g Hz | Events: |dS|thr=%.3g dB/s, d∠thr=%.3g %s, minSep=%.3gs', cutoffHz, thrMag, thrPh, unitPh, minSepVal);
        end
        title(tlo, [figName ttlExtra]);
    catch
        % ignore
    end

    % 도식 저장 옵션
    if saveFig
        % 결과 도식은 실험 폴더의 results 디렉터리에 저장
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
        paramSuffix = lower(char(paramSel));
        base = fullfile(outFigDir, sprintf('sparam_combined_filtered_%s', paramSuffix));
        for iFmt = 1:numel(figFormats)
            fmt = lower(figFormats{iFmt});
            switch fmt
                case 'fig'
                    savefig(f, [base '.fig']);
                case 'png'
                    saveas(f, [base '.png']);
                case 'jpg'
                    saveas(f, [base '.jpg']);
                case {'pdf'}
                    saveas(f, [base '.pdf']);
                otherwise
                    warning('지원하지 않는 Fig 형식: %s', fmt);
            end
        end
    end
    % doPlot 블록 종료
end

% 출력 인자 정리: 호출자가 출력 받지 않으면 아무 것도 반환하지 않음
if nargout >= 1
    varargout{1} = time_s;
end
    if nargout >= 2
        varargout{2} = s11;
    end
    if nargout >= 3
    varargout{3} = s11_lp;
end

% 필터 주파수 응답 Figure (원 요청: 별도 창으로 표시하고 파라미터를 제목에 기재)
try
    if plotFilterResp
        nfft = 4096;
        [H, Fresp] = freqz(b, a, nfft, fs);
        f1u = NaN; f2u = NaN;
        if exist('Wn','var')
            if numel(Wn) == 1
                f1u = Wn * (fs/2);
            elseif numel(Wn) == 2
                f1u = Wn(1) * (fs/2);
                f2u = Wn(2) * (fs/2);
            end
        end
        figTitle = '';
        % 디자인명 및 파라미터 문자열
        switch filterDesign
            case "elliptic"
                designName = 'Elliptic';
                descrip = sprintf('Rp=%.3g dB, Rs=%.3g dB', ellipRp, ellipRs);
            case "butter"
                designName = 'Butterworth';
                descrip = '';
            case "bessel"
                designName = 'Bessel';
                descrip = '';
            case "notch"
                designName = 'Biquad'; % iirnotch biquad
                descrip = '';
            otherwise
                designName = char(filterDesign);
                descrip = '';
        end
        if filterType == "bandstop"
            if filterDesign == "notch"
                try
                    f0u = (double(bandstopHz(1))+double(bandstopHz(2)))/2;
                    BWu = abs(double(bandstopHz(2))-double(bandstopHz(1)));
                    if ~isnan(notchQ) && notchQ>0
                        qstr = sprintf('Q=%.3g', notchQ);
                    else
                        qstr = sprintf('Q~%.3g', f0u/max(BWu,eps));
                    end
                    figTitle = sprintf('Notch | %s | f0=%.6g Hz, BW=%.6g Hz | %s | Mode=%s', designName, f0u, BWu, qstr, char(filterMode));
                catch
                    figTitle = sprintf('Notch | %s | Mode=%s', designName, char(filterMode));
                end
            else
                if isfinite(f1u) && isfinite(f2u)
                    figTitle = sprintf('%s bandstop | N=%d | %s | Stop=[%.6g %.6g] Hz | Mode=%s', designName, filtOrder, descrip, f1u, f2u, char(filterMode));
                else
                    figTitle = sprintf('%s bandstop | N=%d | %s | Stop=[%.6g %.6g] Hz | Mode=%s', designName, filtOrder, descrip, double(bandstopHz(1)), double(bandstopHz(2)), char(filterMode));
                end
            end
        else
            if isfinite(f1u)
                figTitle = sprintf('%s lowpass | N=%d | %s | Cutoff=%.6g Hz | Mode=%s', designName, filtOrder, descrip, f1u, char(filterMode));
            else
                figTitle = sprintf('%s lowpass | N=%d | %s | Cutoff=%.6g Hz | Mode=%s', designName, filtOrder, descrip, cutoffHz, char(filterMode));
            end
        end

        fFR = figure('Name', ['Filter Response — ' char(paramSel)]);
        tloFR = tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
        title(tloFR, sprintf('%s — %s', figTitle, char(paramSel)));
        % Magnitude (dB)
        nexttile; grid on; hold on;
        plot(Fresp, 20*log10(abs(H)), 'LineWidth', 1.5);
        if filterType == "bandstop"
            if isfinite(f1u), xline(f1u, 'r--'); end
            if isfinite(f2u), xline(f2u, 'r--'); end
        else
            if isfinite(f1u), xline(f1u, 'r--'); end
        end
        xlabel('Frequency (Hz)'); ylabel('|H| (dB)');
        % Phase (deg)
        nexttile; grid on; hold on;
        ph = unwrap(angle(H));
        plot(Fresp, rad2deg(ph), 'LineWidth', 1.2);
        if filterType == "bandstop"
            if isfinite(f1u), xline(f1u, 'r--'); end
            if isfinite(f2u), xline(f2u, 'r--'); end
        else
            if isfinite(f1u), xline(f1u, 'r--'); end
        end
        xlabel('Frequency (Hz)'); ylabel('Phase (deg)');

        % 저장 옵션
        if isnan(saveFilterFigOpt)
            saveFR = saveFig;
        else
            saveFR = saveFilterFigOpt;
        end
        if saveFR
            % 필터 응답 도식도 실험 폴더의 results 폴더에 저장
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
            baseFR = fullfile(outFigDir, sprintf('filter_response_%s_%s', lower(char(paramSel)), char(filterType)));
            for iFmt = 1:numel(figFormats)
                fmt = lower(figFormats{iFmt});
                switch fmt
                    case 'fig'
                        savefig(fFR, [baseFR '.fig']);
                    case 'png'
                        saveas(fFR, [baseFR '.png']);
                    case 'jpg'
                        saveas(fFR, [baseFR '.jpg']);
                    case {'pdf'}
                        saveas(fFR, [baseFR '.pdf']);
                    otherwise
                        % ignore
                end
            end
        end
    end
catch
end
% 후속: wavelet 스펙트로그램 자동 생성 (Param='both'의 경우 상위 분기에서 재귀 호출되므로 여기서는 개별 포트일 때만 실행됨)
try
    if runWavelet && exist('outPath','var') == 1 && doSave
        % wavelet 저장/형식 기본값 보정
        if isnan(waveSaveFigOpt)
            waveSaveFig = saveFig;
        else
            waveSaveFig = waveSaveFigOpt;
        end
        if isempty(waveFigFormatsOpt)
            waveFigFormats = figFormats;
        else
            waveFigFormats = cellstr(waveFigFormatsOpt);
        end
        % wavelet 호출: 결합 파일 경로를 명시 전달하여 올바른 파일을 사용
        try
            waveArgs = { 'Param', char(paramSel), ...
                         'CombinedMatPath', outPath, ...
                         'UseFiltered', logical(waveUseFiltered), ...
                         'FreqSelect', freqVal, ...
                         'AskWindow', logical(waveAskWin), ...
                         'SaveFig', logical(waveSaveFig), ...
                         'FigFormats', waveFigFormats, ...
                         'PlotTemp', logical(plotTemp) };
            wavelet_sparam_window(dataDir, waveArgs{:});
        catch MEw
            warning('combine_sparam_lowpass:WaveletFailed', 'wavelet_sparam_window 실행 실패: %s', MEw.message);
        end
    end
catch
end

end % end of combine_sparam_lowpass

function nv2 = local_set_param_nv(nvIn, val)
    nv2 = nvIn;
    found = false;
    for jj = 1:2:numel(nv2)
        if ischar(nv2{jj}) && strcmpi(nv2{jj}, 'Param')
            nv2{jj+1} = val; found = true; break;
        end
    end
    % Param 키가 없으면 추가하여 재귀 호출 시 기본값('both')로 돌아가는 것을 방지
    if ~found
        nv2 = [nv2, {'Param', val}];
    end
end

function nv2 = local_set_nv(nvIn, key, val)
    % Name-Value 목록에서 key를 val로 설정(존재하면 교체, 없으면 추가)
    nv2 = nvIn;
    found = false;
    for jj = 1:2:numel(nv2)
        if ischar(nv2{jj}) && strcmpi(nv2{jj}, key)
            nv2{jj+1} = val; found = true; break;
        end
    end
    if ~found
        nv2 = [nv2, {key, val}];
    end
end

function prefs = local_load_prefs(dataDir, defaults)
% 폴더별 최근 입력값을 저장/로드하는 헬퍼
% defaults: 기본 구조체 (필드 누락 시 채움)
    prefs = defaults;
    try
        prefPath = fullfile(dataDir, 'combine_sparam_prefs.mat');
        if exist(prefPath, 'file') == 2
            S = load(prefPath);
            if isfield(S, 'prefs') && isstruct(S.prefs)
                fn = fieldnames(defaults);
                for k = 1:numel(fn)
                    f = fn{k};
                    if isfield(S.prefs, f)
                        prefs.(f) = S.prefs.(f);
                    end
                end
            end
        end
    catch
        % ignore
    end
end

function local_save_prefs(dataDir, prefs)
    try
        prefPath = fullfile(dataDir, 'combine_sparam_prefs.mat');
        save(prefPath, 'prefs');
    catch
        % ignore
    end
end
