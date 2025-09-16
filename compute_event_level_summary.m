function S = compute_event_level_summary(varargin)
% compute_event_level_summary  주파수별 결과를 이벤트(온도) 단위로 집계
%
% 사용법
%   S = compute_event_level_summary();
%   S = compute_event_level_summary('ResultsCsv', 'expdata/transition_eval_results.csv');
%
% 출력
%   S : event-level table (exp,param,t_temp, n_freq, hit_mag, hit_phase, hit_any,
%                         min_delta_mag_s, min_delta_phase_s)
%       파일로도 저장: expdata/transition_event_level_summary.csv

ip = inputParser;
ip.addParameter('ResultsCsv', fullfile(pwd,'expdata','transition_eval_results.csv'), @(s)ischar(s)||isstring(s));
ip.parse(varargin{:});
resCsv = char(ip.Results.ResultsCsv);

assert(exist(resCsv,'file')==2, '결과 CSV 없음: %s', resCsv);
T = readtable(resCsv, 'VariableNamingRule','preserve');

% 타입 보정
if ~isduration(T.delta_mag_s)
    % numeric seconds expected; keep as double
end
% t_temp 문자열을 datetime으로
tt = T.t_temp;
if ~isdatetime(tt)
    try
        tt = datetime(string(tt));
    catch
        tt = datetime(string(tt), 'InputFormat','yyyy-MM-dd HH:mm:ss.SSS');
    end
end

% 그룹: (exp,param,t_temp)
[G, expU, paramU, tU] = findgroups(T.exp, T.param, tt);
nG = max(G);
hit_mag = false(nG,1);
hit_phase = false(nG,1);
hit_any = false(nG,1);
n_freq = zeros(nG,1);
min_dmag = NaN(nG,1);
min_dph  = NaN(nG,1);

for g = 1:nG
    idx = (G == g);
    dm = T.delta_mag_s(idx);
    dp = T.delta_phase_s(idx);
    hit_mag(g) = any(isfinite(dm));
    hit_phase(g) = any(isfinite(dp));
    hit_any(g) = hit_mag(g) || hit_phase(g);
    n_freq(g) = sum(idx);
    if any(isfinite(dm)), min_dmag(g) = min(dm(isfinite(dm))); end
    if any(isfinite(dp)), min_dph(g)  = min(dp(isfinite(dp))); end
end

S = table(expU, paramU, tU, n_freq, hit_mag, hit_phase, hit_any, min_dmag, min_dph, ...
    'VariableNames', {'exp','param','t_temp','n_freq','hit_mag','hit_phase','hit_any','min_delta_mag_s','min_delta_phase_s'});

% 저장
outCsv = fullfile(pwd,'expdata','transition_event_level_summary.csv');
try, writetable(S, outCsv); catch, end

% 집계 출력
fprintf('Event-level summary (overall)\n');
tot = height(S);
fprintf('- Events: %d\n', tot);
fprintf('- Success_any: %.1f%% (%d/%d)\n', 100*mean(S.hit_any), nnz(S.hit_any), tot);
fprintf('- Success_mag: %.1f%% (%d/%d)\n', 100*mean(S.hit_mag), nnz(S.hit_mag), tot);
fprintf('- Success_phase: %.1f%% (%d/%d)\n', 100*mean(S.hit_phase), nnz(S.hit_phase), tot);

% 파라미터별
try
    ps = categories(categorical(S.param));
catch
    ps = unique(S.param);
end
for i = 1:numel(ps)
    p = ps{i};
    m = strcmp(string(S.param), string(p));
    if ~any(m), continue; end
    fprintf('Param=%s: any=%.1f%% (%d/%d), mag=%.1f%%, phase=%.1f%%\n', p, ...
        100*mean(S.hit_any(m)), nnz(S.hit_any(m)), nnz(m), 100*mean(S.hit_mag(m)), 100*mean(S.hit_phase(m)));
end

fprintf('저장: %s\n', outCsv);

end

