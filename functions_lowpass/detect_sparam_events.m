function E = detect_sparam_events(time_s, s_complex, varargin)
% detect_sparam_events  |S|, ∠S의 변화율 이벤트(피크) 검출
% 사용법
%   E = detect_sparam_events(t, s)
%   E = detect_sparam_events(t, s, 'PhaseUnit','deg','EventThreshK',20,...)
%
% 입력
%   time_s    : 초 단위 시간 [N x 1]
%   s_complex : 복소 S(t) [N x M] (여러 주파수 열 가능)
%
% 옵션(Name-Value)
%   'PhaseUnit'      : 'deg'|'rad' (기본 'deg' — combine_sparam_lowpass 플롯 단위와 일치)
%   'DerivSmooth'    : 변화율에 저역통과 적용 (기본 false)
%   'DerivCutoffHz'  : 변화율 저역통과 차단(Hz, 기본 fs*0.75*Cutoff/기본치 — 미지정시 자동)
%   'DerivFilterMode': 'centered'|'causal' (기본 'causal')
%   'DerivFilterOrder': 정수 차수 (기본 4)
%   'EventMagThresh' : |d|S||/dt 임계(dB/s), 스칼라 또는 열별
%   'EventPhaseThresh': |d∠|/dt 임계(phaseUnit/s), 스칼라 또는 열별
%   'EventThreshK'   : 자동 임계 배수 K (기본 20 → K*MAD)
%   'EventScope'     : 'local'|'global' (기본 'local')
%   'EventLocalSpanSec': 로컬 임계 과거 창(초, 기본 1800)
%   'EventMinSepSec' : 이벤트 최소 간격(초, 기본 5*median(dt))
%   'Polarity'       : 'both'|'pos'|'neg' (기본 'both')
%
% 출력 구조체 E 필드
%   - idx_mag, t_mag, thr_mag_used
%   - idx_phase, t_phase, thr_phase_used
%   - dmag_dt, dph_dt, time_s (반환용)
%   - opts (사용 파라미터 스냅샷)

ip = inputParser;
ip.addParameter('PhaseUnit', 'deg');
ip.addParameter('DerivSmooth', false, @(x)islogical(x)&&isscalar(x));
ip.addParameter('DerivCutoffHz', NaN, @isscalar);
ip.addParameter('DerivFilterMode', 'causal');
ip.addParameter('DerivFilterOrder', 4, @(x)isfinite(x)&&x==round(x)&&x>0);
ip.addParameter('EventMagThresh', NaN, @isscalar);
ip.addParameter('EventPhaseThresh', NaN, @isscalar);
ip.addParameter('EventThreshK', 20, @(x)isfinite(x)&&x>0);
ip.addParameter('EventScope', 'local');
ip.addParameter('EventLocalSpanSec', 1800, @(x)isfinite(x)&&x>0);
ip.addParameter('EventMinSepSec', NaN, @isscalar);
ip.addParameter('Polarity','both');
ip.parse(varargin{:});
opt = ip.Results;

time_s = time_s(:);
if size(s_complex,1) ~= numel(time_s)
    error('detect_sparam_events:DimMismatch','time과 s 길이가 다릅니다.');
end

% 샘플링 주기/주파수
if numel(time_s) < 3
    error('detect_sparam_events:TooFew','샘플이 너무 적습니다.');
end
dt = median(diff(time_s));
if ~isfinite(dt) || dt <= 0
    error('detect_sparam_events:BadTime','time_s 간격이 유효하지 않습니다.');
end
fs = 1/dt;

% 기본 변화율 필터 컷오프 보정(미지정 시)
if isnan(opt.DerivCutoffHz)
    opt.DerivCutoffHz = min(0.75*(fs/2), 1.5*(1/ max(10*dt, dt))); % 느슨한 기본값
end
if isnan(opt.EventMinSepSec)
    opt.EventMinSepSec = 5*dt;
end

% 크기/위상 시리즈 준비
mag_db = 20*log10(abs(s_complex));
ph = unwrap(angle(s_complex));
if strcmpi(opt.PhaseUnit,'deg')
    ph = rad2deg(ph);
end

% 시간 기반 도함수
dmag_dt = i_derivative(time_s, mag_db);
dph_dt  = i_derivative(time_s, ph);

% 변화율 평활(Optional)
if opt.DerivSmooth
    Wn = opt.DerivCutoffHz/(fs/2);
    Wn = max(1e-6, min(Wn, 0.99));
    [bd,ad] = butter(opt.DerivFilterOrder, Wn, 'low');
    switch lower(opt.DerivFilterMode)
        case 'centered'
            dmag_dt = filtfilt(bd,ad,dmag_dt);
            dph_dt  = filtfilt(bd,ad,dph_dt);
        otherwise
            dmag_dt = filter(bd,ad,dmag_dt);
            dph_dt  = filter(bd,ad,dph_dt);
    end
end

% 임계 계산 (열별)
nC = size(dmag_dt,2);
thr_mag = zeros(1,nC);
thr_ph  = zeros(1,nC);

for c = 1:nC
    if ~isnan(opt.EventMagThresh)
        thr_mag(c) = opt.EventMagThresh;
    else
        thr_mag(c) = opt.EventThreshK * i_mad(abs(dmag_dt(:,c)));
    end
    if ~isnan(opt.EventPhaseThresh)
        thr_ph(c) = opt.EventPhaseThresh;
    else
        thr_ph(c) = opt.EventThreshK * i_mad(abs(dph_dt(:,c)));
    end
end

% 피크 검출 (로컬/글로벌 임계)
minDist = max(1, round(opt.EventMinSepSec/dt));
idx_mag = cell(1,nC); idx_ph = cell(1,nC);
for c = 1:nC
    y1 = select_polarity(dmag_dt(:,c), opt.Polarity);
    y2 = select_polarity(dph_dt(:,c),  opt.Polarity);
    [~, locs1] = findpeaks(abs(y1), 'MinPeakDistance', minDist);
    [~, locs2] = findpeaks(abs(y2), 'MinPeakDistance', minDist);
    if strcmpi(opt.EventScope,'local')
        keep = false(size(locs1));
        for k = 1:numel(locs1)
            tcur = time_s(locs1(k));
            idxW = time_s >= max(time_s(1), tcur - opt.EventLocalSpanSec) & time_s <= tcur;
            base = i_mad(abs(y1(idxW)));
            keep(k) = abs(y1(locs1(k))) >= opt.EventThreshK * base;
        end
        locs1 = locs1(keep);
        keep = false(size(locs2));
        for k = 1:numel(locs2)
            tcur = time_s(locs2(k));
            idxW = time_s >= max(time_s(1), tcur - opt.EventLocalSpanSec) & time_s <= tcur;
            base = i_mad(abs(y2(idxW)));
            keep(k) = abs(y2(locs2(k))) >= opt.EventThreshK * base;
        end
        locs2 = locs2(keep);
    else
        locs1 = locs1(abs(y1(locs1)) >= thr_mag(c));
        locs2 = locs2(abs(y2(locs2)) >= thr_ph(c));
    end
    idx_mag{c} = locs1(:)';
    idx_ph{c}  = locs2(:)';
end

E = struct();
E.idx_mag = idx_mag;
E.idx_phase = idx_ph;
E.t_mag = cellfun(@(ix) time_s(ix), idx_mag, 'UniformOutput', false);
E.t_phase = cellfun(@(ix) time_s(ix), idx_ph,  'UniformOutput', false);
E.thr_mag_used = thr_mag;
E.thr_phase_used = thr_ph;
E.dmag_dt = dmag_dt;
E.dph_dt = dph_dt;
E.time_s = time_s(:);
E.opts = opt;

end

function y = select_polarity(x, pol)
    switch lower(string(pol))
        case "pos", y = max(0,x);
        case "neg", y = min(0,x);
        otherwise,   y = x;
    end
end

function d = i_derivative(t, y)
    % 비균일 t에서도 중앙차분 근사
    t = t(:);
    n = numel(t);
    if isvector(y), y = y(:); end
    d = zeros(size(y));
    for c = 1:size(y,2)
        yc = y(:,c);
        dy = zeros(n,1);
        if n >= 3
            dtm = diff(t);
            dy(2:n-1) = (yc(3:n) - yc(1:n-2)) ./ (t(3:n) - t(1:n-2));
            dy(1) = (yc(2)-yc(1)) / (t(2)-t(1));
            dy(n) = (yc(n)-yc(n-1)) / (t(n)-t(n-1));
        else
            dy(:) = 0;
        end
        d(:,c) = dy;
    end
end

function m = i_mad(x)
    x = x(:);
    med = median(x(~isnan(x)));
    m = median(abs(x - med));
    if ~isfinite(m) || m == 0
        m = std(x, 'omitnan')/1.4826;
    end
    if ~isfinite(m) || m == 0
        m = eps;
    end
end

