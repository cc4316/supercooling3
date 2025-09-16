function out = detect_events_relative_extreme(t, d, opts)
% detect_events_relative_extreme  최근 창 내 최대/최소의 n배 초과 변화 이벤트
% 입력
%   t   : 시간 [Nt x 1]
%   d   : 도함수 [Nt x Nc]
%   opts:
%     .WindowSec   : 과거 창 길이(초, 기본 1800)
%     .Multiple    : 배수 n (기본 1.5)
%     .Polarity    : 'both'|'up'|'down' (기본 'both')
%     .MinSepSec   : 최소 간격(초, 기본 5*median(diff(t)))
%
% 출력
%   out.idx{c}     : 이벤트 인덱스

    if nargin < 3, opts = struct(); end
    if ~isfield(opts,'WindowSec'), opts.WindowSec = 1800; end
    if ~isfield(opts,'Multiple'), opts.Multiple = 1.5; end
    if ~isfield(opts,'Polarity'), opts.Polarity = 'both'; end
    if ~isfield(opts,'MinSepSec') || ~isfinite(opts.MinSepSec)
        dt = median(diff(t)); opts.MinSepSec = 5*dt; 
    end

    [Nt, Nc] = size(d);
    out.idx = cell(1,Nc);
    for c = 1:Nc
        y = d(:,c);
        ev = false(Nt,1);
        for i = 2:Nt
            t0 = t(i) - opts.WindowSec;
            win = find(t >= t0 & t < t(i));
            if isempty(win), continue; end
            ymax = max(y(win), [], 'omitnan');
            ymin = min(y(win), [], 'omitnan');

            cond_up = false; cond_dn = false;
            if ymax > 0
                cond_up = y(i) >= opts.Multiple * ymax;
            end
            if ymin < 0
                cond_dn = y(i) <= opts.Multiple * ymin; % ymin은 음수 → 더 작아지면 이벤트
            end
            switch lower(opts.Polarity)
                case 'up',   ev(i) = cond_up;
                case 'down', ev(i) = cond_dn;
                otherwise,   ev(i) = cond_up | cond_dn;
            end
        end
        % 최소 간격 적용
        idx = find(ev);
        if ~isempty(idx)
            kept = idx(1);
            for k = 2:numel(idx)
                if t(idx(k)) - t(kept(end)) >= opts.MinSepSec
                    kept(end+1) = idx(k);
                end
            end
            idx = kept;
        end
        out.idx{c} = idx;
    end
end

