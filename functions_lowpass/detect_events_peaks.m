function out = detect_events_peaks(t, d, opts)
% detect_events_peaks  기존 피크 기반 이벤트 검출(구조화)
% 입력
%   t   : 시간 벡터 [Nt x 1]
%   d   : 도함수 값 행렬 [Nt x Nc]
%   opts: struct
%     .Scope          : 'global'|'local' (기본 'local')
%     .K              : 스케일 계수 K (기본 25)
%     .MinSepSec      : 최소 간격(초) (기본 5*median(diff(t)))
%     .LocalSpanSec   : 로컬 임계 계산 창(초, 기본 1800)
%     .ThreshOverride : 스칼라/벡터 임계 강제(선택)
%
% 출력
%   out.idx{c}        : 이벤트 인덱스 벡터
%   out.thresh(c)     : (global일 때) 임계값 저장, local일 때 NaN

    if nargin < 3, opts = struct(); end
    if ~isfield(opts,'Scope'), opts.Scope = 'local'; end
    if ~isfield(opts,'K'), opts.K = 25; end
    if ~isfield(opts,'LocalSpanSec'), opts.LocalSpanSec = 1800; end
    if ~isfield(opts,'MinSepSec') || ~isfinite(opts.MinSepSec)
        dt = median(diff(t)); opts.MinSepSec = 5*dt; 
    end

    [Nt, Nc] = size(d);
    out.idx = cell(1,Nc);
    out.thresh = NaN(1,Nc);
    minDist = max(1, round(opts.MinSepSec/median(diff(t))));

    for c = 1:Nc
        y = d(:,c);
        yabs = abs(y);
        % 임계 결정
        if isfield(opts,'ThreshOverride') && ~isempty(opts.ThreshOverride)
            if isscalar(opts.ThreshOverride)
                thr = opts.ThreshOverride;
            elseif numel(opts.ThreshOverride) >= c
                thr = opts.ThreshOverride(c);
            else
                thr = opts.K * local_mad(yabs);
            end
            modeLocal = false;
        else
            if strcmpi(opts.Scope,'global')
                thr = opts.K * local_mad(yabs);
                modeLocal = false;
            else
                thr = NaN; modeLocal = true;
            end
        end
        out.thresh(c) = thr;

        % 피크 후보
        [~, locs] = findpeaks(yabs, 'MinPeakDistance', minDist);
        if isempty(locs), out.idx{c} = []; continue; end

        keep = false(size(locs));
        if modeLocal
            for k = 1:numel(locs)
                tcur = t(locs(k));
                win = t >= max(t(1), tcur - opts.LocalSpanSec) & t <= tcur;
                if nnz(win) < 10
                    thrLoc = opts.K * local_mad(yabs);
                else
                    thrLoc = opts.K * local_mad(yabs(win));
                end
                keep(k) = yabs(locs(k)) >= thrLoc;
            end
        else
            keep = yabs(locs) >= thr;
        end
        out.idx{c} = locs(keep);
    end
end

function m = local_mad(x)
    x = x(:);
    med = median(x, 'omitnan');
    m = median(abs(x - med), 'omitnan');
end

