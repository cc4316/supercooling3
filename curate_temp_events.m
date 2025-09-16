function outPath = curate_temp_events(expDir, varargin)
% curate_temp_events  기존 온도 이벤트(GT) CSV를 일괄 보정/정리하고 저장
%
% 사용법
%   outPath = curate_temp_events(expDir, 'Param','S11', 'SnapWindowSec',5, 'MinSepSec',30, ...)
%
% 옵션(Name-Value)
%   'Param'        : 'S11'|'S22' (기본 'S11')
%   'InFile'       : 입력 CSV 경로(기본: temp_events_<Param>.csv)
%   'OutFile'      : 출력 CSV 경로(기본: temp_events_<Param>_manual.csv)
%   'SnapWindowSec': 각 이벤트를 ±윈도우 내 dT/dt 지역최대치로 스냅 (기본 5, 0이면 비활성)
%   'MinSepSec'    : 최소 간격 미만 이벤트는 앞 이벤트만 유지 (기본 30, 0이면 비활성)
%   'ShiftSec'     : 모든 이벤트 시각을 일정 시간만큼 가감 (기본 0)
%   'KeepRange'    : 시간 범위 [t0 t1] (datetime/문자) 내 이벤트만 보존 (기본 [])
%   'RemoveIdx'    : 제거할 event_idx 리스트 (기본 [])
%   'AddTimes'     : 추가할 이벤트 시각(datetime 배열/문자 cell) (기본 [])
%
% 비고
% - Temp.csv + TempChannelSelection.csv를 읽어 선택 채널 평균(Tsel)과 dT/dt를 계산하여
%   스냅 및 간격 판단을 수행합니다.

ip = inputParser;
ip.addParameter('Param','S11', @(s)ischar(s)||isstring(s));
ip.addParameter('InFile','', @(s)ischar(s)||isstring(s));
ip.addParameter('OutFile','', @(s)ischar(s)||isstring(s));
ip.addParameter('SnapWindowSec', 5, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
ip.addParameter('MinSepSec', 30, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
ip.addParameter('ShiftSec', 0, @(x)isnumeric(x)&&isscalar(x));
ip.addParameter('KeepRange', [], @(x) isempty(x) || isdatetime(x) || isstring(x) || iscell(x));
ip.addParameter('RemoveIdx', [], @(x)isnumeric(x));
ip.addParameter('AddTimes', [], @(x) isempty(x) || isdatetime(x) || isstring(x) || iscell(x));
ip.addParameter('Channels', [], @(x) isempty(x) || (isnumeric(x)&&isvector(x)));
% 원본 이벤트가 없을 때 자동 생성 옵션(Temp에서 검출)
ip.addParameter('GenerateIfMissing', true, @(x)islogical(x)&&isscalar(x));
ip.addParameter('EventK', 12, @(x)isnumeric(x)&&isscalar(x)&&x>0);
ip.addParameter('EventMinSepSec', 30, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
ip.addParameter('EventScope', 'local', @(s)ischar(s)||isstring(s));
ip.addParameter('EventLocalSpanSec', 3600, @(x)isnumeric(x)&&isscalar(x)&&x>0);
% 파생 유도: dT/dt 임계 기반으로 수동 이벤트를 재구성하고 싶을 때 사용 (NaN이면 비활성)
ip.addParameter('DerivThresh', NaN, @(x)isnumeric(x)&&isscalar(x));
ip.parse(varargin{:});
opt = ip.Results;

if nargin < 1 || isempty(expDir) || exist(expDir,'dir') ~= 7
    error('curate_temp_events:BadDir','유효한 실험 폴더를 지정하세요.');
end

% Temp/채널 구성 로드 → Tsel, dT/dt 계산
Tt = load_temp_csv_basic(expDir, 'Pattern','Temp.csv');
cfgCsv = fullfile(expDir, 'TempChannelSelection.csv');
if ~isempty(opt.Channels)
    idxT = unique(round(opt.Channels(:)'));
    idxT = idxT(idxT>=1 & idxT<=size(Tt.Values,2));
    if isempty(idxT)
        error('curate_temp_events:BadChannels','Channels가 유효하지 않습니다.');
    end
else
    idxT = resolve_temp_channels_port(Tt.Labels, cfgCsv, string(opt.Param));
end
vals = Tt.Values(:, idxT);
Tsel = mean(vals,2,'omitnan');
time_dt = Tt.Time(:);
time_s = seconds(time_dt - time_dt(1));
dT_dt = zeros(size(Tsel));
if numel(Tsel) >= 3
    dT_dt(2:end-1) = (Tsel(3:end) - Tsel(1:end-2)) ./ (time_s(3:end) - time_s(1:end-2));
    dT_dt(1) = (Tsel(2)-Tsel(1)) / max(time_s(2)-time_s(1), eps);
    dT_dt(end) = (Tsel(end)-Tsel(end-1)) / max(time_s(end)-time_s(end-1), eps);
end

% 파일 경로 준비 (이제 Tt/idxT 준비됨)
tag = regexprep(char(string(opt.Param)),'[^A-Za-z0-9]','');
inPath  = char(opt.InFile); if isempty(inPath),  inPath  = fullfile(expDir, sprintf('temp_events_%s.csv', tag)); end
outPath = char(opt.OutFile); if isempty(outPath), outPath = fullfile(expDir, sprintf('temp_events_%s_manual.csv', tag)); end
tt = datetime.empty(0,1);
% 1) DerivThresh가 주어졌으면 파생기준으로 이벤트 구성(입력 CSV 무시)
if isfinite(opt.DerivThresh)
    mask = isfinite(dT_dt) & (dT_dt >= opt.DerivThresh);
    tt = time_dt(mask);
else
    % 2) 기존 이벤트 로드 (필요 시 자동 생성)
    if exist(inPath,'file') ~= 2
        if opt.GenerateIfMissing
            fprintf('입력 CSV 없음 → 자동 생성: %s\n', inPath);
            Et0 = detect_temp_events(Tt.Time, Tt.Values, 'Channels', idxT, ...
                'EventThreshK', opt.EventK, 'EventMinSepSec', opt.EventMinSepSec, ...
                'EventScope', opt.EventScope, 'EventLocalSpanSec', opt.EventLocalSpanSec);
            write_temp_events_csv(expDir, Et0, 'Param', opt.Param);
        else
            error('입력 CSV를 찾지 못했습니다: %s', inPath);
        end
    end
    Tin = readtable(inPath, 'VariableNamingRule','preserve');
    tt = Tin.t; if ~isdatetime(tt), tt = datetime(string(tt)); end
end

% 추가 이벤트
if ~isempty(opt.AddTimes)
    addt = opt.AddTimes;
    if isstring(addt) || iscell(addt)
        addt = datetime(string(addt));
    end
    tt = [tt; addt(:)];
end

% 시간 이동
if opt.ShiftSec ~= 0
    tt = tt + seconds(opt.ShiftSec);
end

% 범위 필터
if ~isempty(opt.KeepRange)
    if isstring(opt.KeepRange) || iscell(opt.KeepRange)
        kr = datetime(string(opt.KeepRange));
    else
        kr = opt.KeepRange;
    end
    if numel(kr) ~= 2, error('KeepRange는 [t0 t1] 두 값이어야 합니다.'); end
    mask = (tt >= kr(1) & tt <= kr(2));
    tt = tt(mask);
end

% 제거 인덱스 적용(원본 event_idx 기준이 아니라 시각 기반 재구성)
% → 우선 시각 기준으로 정렬/중복 제거 후, RemoveIdx는 처리하지 않고,
%   필요 시 사용자는 InFile에서 직접 인덱스를 확인하여 시각으로 지정 권장.

% 스냅: ±윈도우 내 dT/dt 지역최대
if opt.SnapWindowSec > 0 && ~isempty(tt)
    tnum = datenum(time_dt);
    for k = 1:numel(tt)
        % 대상 구간 인덱스
        win = seconds(opt.SnapWindowSec);
        mask = abs(seconds(time_dt - tt(k))) <= win;
        if nnz(mask) >= 3
            ys = dT_dt(mask);
            [~,loc] = max(ys); % 최대치 인덱스(양의 피크 우선)
            idxLocal = find(mask);
            newIdx = idxLocal(1) + loc - 1;
            tt(k) = time_dt(newIdx);
        else
            % 근접 최근접 시각으로 정렬
            [~,j] = min(abs(time_dt - tt(k)));
            tt(k) = time_dt(j);
        end
    end
end

% 최소 간격 적용(오름차순 정렬 후 인접 비교)
tt = sort(tt);
if opt.MinSepSec > 0 && numel(tt) > 1
    keep = true(size(tt));
    last = tt(1);
    for k = 2:numel(tt)
        if seconds(tt(k) - last) < opt.MinSepSec
            keep(k) = false; % 뒤 이벤트 제거
        else
            last = tt(k);
        end
    end
    tt = tt(keep);
end

% 최종 테이블 구성: 최근접 인덱스/샘플값
[~, idx] = min(abs(time_dt(:) - reshape(tt(:).',1,[])), [], 1);
idx = idx(:);
Tout = table((1:numel(idx)).', idx, tt(:), dT_dt(idx), Tsel(idx), ...
    'VariableNames', {'event_idx','row_idx','t','dT_dt','Tsel'});

% 백업: 기존 파일 보존
try
    if ~strcmpi(inPath, outPath)
        % nothing
    else
        copyfile(inPath, [inPath '.bak']);
    end
catch
end

writetable(Tout, outPath);
fprintf('온도 이벤트 보정 저장: %s (N=%d)\n', outPath, height(Tout));

end
