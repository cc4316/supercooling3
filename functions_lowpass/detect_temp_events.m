function E = detect_temp_events(time_dt, values, varargin)
% detect_temp_events  온도 시계열에서 과냉각→결정화 이벤트(+dT/dt 급등) 검출
% 사용법
%   E = detect_temp_events(time_dt, values)
%   E = detect_temp_events(time_dt, values, 'Channels', 9:12, 'Mode','mean', ...)
%
% 입력
%   time_dt : datetime 벡터 [N x 1]
%   values  : 온도 행렬 [N x C]
%
% 옵션(Name-Value)
%   'Channels'        : 사용할 채널 인덱스(벡터) (기본 1:min(8,C))
%   'Mode'            : 'mean'|'median'|'best' (기본 'mean')
%   'SmoothSec'       : 이동평균 평활(초), 0이면 생략 (기본 0)
%   'DerivSmoothSec'  : dT/dt 이동평균 평활(초, 기본 0)
%   'EventThreshK'    : K*MAD 임계 K (기본 12)
%   'EventMinSepSec'  : 최소 이벤트 간격(초, 기본 30)
%   'EventScope'      : 'local'|'global' (기본 'local')
%   'EventLocalSpanSec': 로컬 기준 과거 창(초, 기본 3600)
%
% 반환 구조체 E 필드
%   - Tsel         : 선택/집계된 온도 [N x 1]
%   - dT_dt        : 변화율 [N x 1] (°C/s)
%   - idx, t       : 이벤트 인덱스/시간(datetime)
%   - thr_used     : 임계값(절대값)
%   - opts         : 사용 파라미터 스냅샷

ip = inputParser;
ip.addParameter('Channels', [], @(x)isnumeric(x)&&isvector(x));
ip.addParameter('Mode', 'mean');
ip.addParameter('SmoothSec', 0, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
ip.addParameter('DerivSmoothSec', 0, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
ip.addParameter('EventThreshK', 12, @(x)isfinite(x)&&x>0);
ip.addParameter('EventMinSepSec', 30, @(x)isfinite(x)&&x>=0);
ip.addParameter('EventScope', 'local');
ip.addParameter('EventLocalSpanSec', 3600, @(x)isfinite(x)&&x>0);
ip.parse(varargin{:});
opt = ip.Results;

if isduration(time_dt)
    % 허용: duration → datetime 보정
    t0 = datetime(0,0,0) + time_dt;
    time_dt = t0;
end
time_dt = time_dt(:);
if numel(time_dt) ~= size(values,1)
    error('detect_temp_events:DimMismatch','시간/값 길이 불일치');
end
N = numel(time_dt);
if isempty(opt.Channels)
    opt.Channels = 1:min(8, size(values,2));
end
chs = unique(round(opt.Channels));
chs = chs(chs>=1 & chs<=size(values,2));
vals = values(:, chs);

% 집계: mean/median
switch lower(string(opt.Mode))
    case "median", Tsel = median(vals,2,'omitnan');
    otherwise,     Tsel = mean(vals,2,'omitnan');
end

% 이동평균 평활(초)
if opt.SmoothSec > 0 && N > 3
    Tsel = movmean(Tsel, i_win(time_dt, opt.SmoothSec), 'omitnan');
end

% dT/dt (datetime → 초)
time_s = seconds(time_dt - time_dt(1));
dT_dt = i_derivative(time_s, Tsel);

if opt.DerivSmoothSec > 0
    dT_dt = movmean(dT_dt, i_win(time_dt, opt.DerivSmoothSec), 'omitnan');
end

% 임계 계산: +dT/dt 급등(양의 방향 우선)
absd = abs(dT_dt);
if strcmpi(opt.EventScope,'local')
    % 후속 판정 시 로컬 MAD 적용
    baseThr = opt.EventThreshK * i_mad(absd);
else
    baseThr = opt.EventThreshK * i_mad(absd);
end

% 피크 후보: 양수 변화율만 대상으로 함
y = max(0, dT_dt);
dt_med = median(diff(time_s));
minDist = max(1, round(opt.EventMinSepSec / max(dt_med, eps)));
[~, locs] = findpeaks(y, 'MinPeakDistance', minDist);
if isempty(locs)
    idx = []; t = datetime.empty(0,1);
else
    if strcmpi(opt.EventScope,'local')
        keep = false(size(locs));
        for k = 1:numel(locs)
            tcur = time_s(locs(k));
            idxW = time_s >= max(time_s(1), tcur - opt.EventLocalSpanSec) & time_s <= tcur;
            thr = opt.EventThreshK * i_mad(absd(idxW));
            keep(k) = y(locs(k)) >= thr;
        end
        locs = locs(keep);
    else
        locs = locs(y(locs) >= baseThr);
    end
    idx = locs(:)';
    t = time_dt(idx);
end

E = struct();
E.Tsel = Tsel;
E.dT_dt = dT_dt;
E.idx = idx;
E.t = t;
E.thr_used = baseThr;
E.opts = opt;

end

function w = i_win(tdt, sec)
    t = seconds(tdt - tdt(1));
    dt = median(diff(t));
    w = max(1, round(sec / max(dt, eps)));
end

function d = i_derivative(t, y)
    t = t(:); y = y(:);
    n = numel(t);
    d = zeros(n,1);
    if n >= 3
        d(2:n-1) = (y(3:n) - y(1:n-2)) ./ (t(3:n) - t(1:n-2));
        d(1)     = (y(2)-y(1)) / (t(2)-t(1));
        d(n)     = (y(n)-y(n-1)) / (t(n)-t(n-1));
    end
end

function m = i_mad(x)
    x = x(:);
    med = median(x(~isnan(x)));
    m = median(abs(x - med));
    if ~isfinite(m) || m == 0
        m = std(x,'omitnan')/1.4826;
    end
    if ~isfinite(m) || m == 0
        m = eps;
    end
end

