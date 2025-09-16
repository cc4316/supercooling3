function paths = export_sparam_events_per_experiment(varargin)
% export_sparam_events_per_experiment  evaluate_transition_alignment 상세(MAT)에서
% 실험별 s-파라 이벤트를 CSV로 내보냅니다.
%
% 출력 CSV (각 실험 폴더):
%   - sparam_events_S11.csv
%   - sparam_events_S22.csv
% 컬럼: freq_col, type(mag|phase), t_abs(datetime), t_rel_s(double), idx(int)

ip = inputParser;
ip.addParameter('DetailMat', fullfile(pwd,'expdata','transition_eval_details.mat'));
ip.parse(varargin{:});
matPath = char(ip.Results.DetailMat);

assert(exist(matPath,'file')==2, 'detail MAT가 없습니다: %s', matPath);
S = load(matPath);
if isfield(S,'detail')
    D = S.detail;
elseif isfield(S,'D_all')
    D = S.D_all;
else
    error('detail/D_all 변수를 찾지 못했습니다: %s', matPath);
end

baseExp = fullfile(pwd,'expdata');
paths = {};

for i = 1:numel(D)
    try
        di = D(i);
        expName = char(di.exp);
        param = char(di.param);
        Et = di.temp; Es = di.sparam;
        expDir = fullfile(baseExp, expName);
        if exist(expDir,'dir')~=7, warning('폴더 없음: %s', expDir); continue; end
        % 시간축 및 절대시각 구성
        if isfield(Es,'time_s') && ~isempty(Es.time_s)
            t_rel = Es.time_s(:);
        elseif isfield(Es,'time') && ~isempty(Es.time)
            t_rel = Es.time(:);
        else
            warning('time_s/time 없음: %s / %s', expName, param); continue;
        end
        if ~isempty(Et) && isfield(Et,'t') && ~isempty(Et.t)
            t0 = Et.t(1);
            if isduration(t0)
                t0 = datetime(0,0,0) + t0;
            end
            if isnat(t0)
                t0 = datetime('now');
            end
        else
            t0 = datetime('now');
        end
        t_abs = t0 + seconds(t_rel);
        % 이벤트 인덱스(주파수 열별 cell)
        idxMag = {}; idxPh = {};
        if isfield(Es,'idx_mag') && ~isempty(Es.idx_mag), idxMag = Es.idx_mag; end
        if isfield(Es,'idx_phase') && ~isempty(Es.idx_phase), idxPh = Es.idx_phase; end
        nCol = max(numel(idxMag), numel(idxPh)); if nCol==0, nCol = size(t_rel,2); end
        % long-form rows
        rows = {};
        for c = 1:nCol
            % |S|
            if c <= numel(idxMag) && ~isempty(idxMag{c})
                for k = 1:numel(idxMag{c})
                    j = idxMag{c}(k);
                    if j>=1 && j<=numel(t_abs)
                        rows(end+1,1) = { { c, 'mag', datestr(t_abs(j),'yyyy-mm-dd HH:MM:SS.FFF'), t_rel(j), j } }; %#ok<AGROW>
                    end
                end
            end
            % ∠
            if c <= numel(idxPh) && ~isempty(idxPh{c})
                for k = 1:numel(idxPh{c})
                    j = idxPh{c}(k);
                    if j>=1 && j<=numel(t_abs)
                        rows(end+1,1) = { { c, 'phase', datestr(t_abs(j),'yyyy-mm-dd HH:MM:SS.FFF'), t_rel(j), j } }; %#ok<AGROW>
                    end
                end
            end
        end
        if isempty(rows)
            T = cell2table(cell(0,5), 'VariableNames', {'freq_col','type','t_abs','t_rel_s','idx'});
        else
            T = cell2table(vertcat(rows{:}), 'VariableNames', {'freq_col','type','t_abs','t_rel_s','idx'});
        end
        % 저장
        outCsv = fullfile(expDir, sprintf('sparam_events_%s.csv', lower(param)));
        try, writetable(T, outCsv); catch, end
        paths{end+1,1} = outCsv; %#ok<AGROW>
    catch ME
        warning('내보내기 실패(%d): %s', i, ME.message);
    end
end

end
