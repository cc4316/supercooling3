function T = compute_precision_recall(varargin)
% compute_precision_recall  detail(MAT) 기반 Precision/Recall 요약
%
% 사용법
%   T = compute_precision_recall();
%
% 출력
%   T: table [per param] with precision_mag/precision_phase and recall_any

ip = inputParser;
ip.addParameter('DetailMat', fullfile(pwd,'expdata','transition_eval_details.mat'), @(s)ischar(s)||isstring(s));
ip.addParameter('AlignWindow', [0 5], @(x)isnumeric(x)&&numel(x)==2);
ip.parse(varargin{:});
opt = ip.Results;

assert(exist(opt.DetailMat,'file')==2, 'detail MAT 없음: %s', opt.DetailMat);
S = load(opt.DetailMat);
assert(isfield(S,'detail'), 'detail 구조가 없습니다.');
dlist = S.detail;

% 집계 컨테이너
params = {};
tp_mag = []; fp_mag = []; tp_ph = []; fp_ph = []; ev_tot = [];

for i = 1:numel(dlist)
    di = dlist(i);
    if ~isfield(di,'param') || ~isfield(di,'temp') || ~isfield(di,'sparam'), continue; end
    p = char(di.param);
    Et = di.temp; Es = di.sparam;
    % 온도 이벤트 시간들
    tT = Et.t; if isempty(tT), continue; end
    % sparam 시간축(초)
    if isfield(Es,'time_s') && ~isempty(Es.time_s)
        tS = Es.time_s(:);
    elseif isfield(Es,'time') && ~isempty(Es.time)
        tS = Es.time(:);
    else
        continue;
    end
    % sparam 이벤트 시간들(초)
    magTimes = [];
    phTimes  = [];
    if isfield(Es,'idx_mag') && ~isempty(Es.idx_mag)
        for c = 1:numel(Es.idx_mag)
            magTimes = [magTimes; tS(Es.idx_mag{c})]; %#ok<AGROW>
        end
    end
    if isfield(Es,'idx_phase') && ~isempty(Es.idx_phase)
        for c = 1:numel(Es.idx_phase)
            phTimes = [phTimes; tS(Es.idx_phase{c})]; %#ok<AGROW>
        end
    end
    % 매칭 판단: (sparam - temp) in [win]
    win = opt.AlignWindow;
    % mag
    tp_m = 0; fp_m = 0;
    for k = 1:numel(magTimes)
        ds = magTimes(k) - seconds(tT - tT(1)); % 상대 기준
        if any(ds >= win(1) & ds <= win(2))
            tp_m = tp_m + 1;
        else
            fp_m = fp_m + 1;
        end
    end
    % phase
    tp_p = 0; fp_p = 0;
    for k = 1:numel(phTimes)
        ds = phTimes(k) - seconds(tT - tT(1));
        if any(ds >= win(1) & ds <= win(2))
            tp_p = tp_p + 1;
        else
            fp_p = fp_p + 1;
        end
    end
    % append per param accumulators
    j = find(strcmp(params,p),1);
    if isempty(j)
        params{end+1} = p; %#ok<AGROW>
        tp_mag(end+1) = tp_m; %#ok<AGROW>
        fp_mag(end+1) = fp_m; %#ok<AGROW>
        tp_ph(end+1)  = tp_p; %#ok<AGROW>
        fp_ph(end+1)  = fp_p; %#ok<AGROW>
        ev_tot(end+1) = numel(tT); %#ok<AGROW>
    else
        tp_mag(j) = tp_mag(j) + tp_m;
        fp_mag(j) = fp_mag(j) + fp_m;
        tp_ph(j)  = tp_ph(j)  + tp_p;
        fp_ph(j)  = fp_ph(j)  + fp_p;
        ev_tot(j) = ev_tot(j) + numel(tT);
    end
end

% precision, recall(any from event-level)
prec_mag = tp_mag ./ max(1, tp_mag + fp_mag);
prec_ph  = tp_ph  ./ max(1, tp_ph  + fp_ph);
% recall(any): compute from event-level summary if available
rec_any = NaN(size(prec_mag));
try
    E = readtable(fullfile(pwd,'expdata','transition_event_level_summary.csv'));
    for i = 1:numel(params)
        m = strcmp(string(E.param), string(params{i}));
        if any(m)
            rec_any(i) = mean(E.hit_any(m));
        end
    end
catch
end

T = table(string(params)', prec_mag', prec_ph', rec_any', tp_mag', fp_mag', tp_ph', fp_ph', ev_tot', ...
    'VariableNames', {'param','precision_mag','precision_phase','recall_any','tp_mag','fp_mag','tp_phase','fp_phase','n_events'});

outCsv = fullfile(pwd,'expdata','precision_recall_summary.csv');
try, writetable(T, outCsv); catch, end
fprintf('Precision/Recall 저장: %s\n', outCsv);

end

