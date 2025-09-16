function outPath = generate_alignment_report(varargin)
% generate_alignment_report  정합 평가/스윕 요약 리포트(Markdown) 생성
% 사용법
%   outPath = generate_alignment_report();
%   outPath = generate_alignment_report('Results', R, 'Summary', S, 'Detail', D);

ip = inputParser;
ip.addParameter('Results', [], @(x) istable(x) || isempty(x));
ip.addParameter('Summary', [], @(x) istable(x) || isempty(x));
ip.addParameter('Detail',  [], @(x) isstruct(x) || isempty(x));
ip.addParameter('EventSummary', [], @(x) istable(x) || isempty(x));
ip.addParameter('Freq', [], @(x) isnumeric(x) && isvector(x));
ip.addParameter('FreqUnit', 'GHz', @(s) ischar(s) || isstring(s));
ip.parse(varargin{:});
R = ip.Results.Results; S = ip.Results.Summary; D = ip.Results.Detail; E = ip.Results.EventSummary; F = ip.Results.Freq; FU = ip.Results.FreqUnit;

% 입력이 없으면 파일에서 로드 시도
baseExp = fullfile(pwd,'expdata');
if isempty(R)
    try, R = readtable(fullfile(baseExp,'transition_eval_results.csv')); catch, R = table(); end
end
if isempty(S)
    try, S = readtable(fullfile(baseExp,'alignment_sweep_summary.csv')); catch, S = table(); end
end
% 이벤트 요약(E): 없으면 파일→계산 순으로 시도
if isempty(E)
    try
        E = readtable(fullfile(baseExp,'transition_event_level_summary.csv'));
    catch
        try
            if exist('compute_event_level_summary','file') == 2
                E = compute_event_level_summary();
            else
                E = table();
            end
        catch
            E = table();
        end
    end
end
% 이벤트 요약(E): 없으면 파일→계산 순으로 시도
if isempty(E)
    try
        E = readtable(fullfile(baseExp,'transition_event_level_summary.csv'));
    catch
        try
            if exist('compute_event_level_summary','file') == 2
                E = compute_event_level_summary();
            else
                E = table();
            end
        catch
            E = table();
        end
    end
end

% 리포트 폴더 준비
repDir = fullfile(pwd,'reports');
if exist(repDir,'dir') ~= 7, mkdir(repDir); end

% 간단 도표 저장 (Δt 히스토그램)
figs = {};
try
    if ~isempty(R)
        f1 = figure('Visible','off');
        tiledlayout(1,2,'Padding','compact','TileSpacing','compact');
        nexttile; histogram(R.delta_mag_s, 30); grid on; xlabel('Δt_mag (s)'); ylabel('count'); title('|S| Δt'); xline(5,'r--');
        nexttile; histogram(R.delta_phase_s, 30); grid on; xlabel('Δt_phase (s)'); title('∠ Δt'); xline(5,'r--');
        p1 = fullfile(repDir,'delta_hist.png'); saveas(f1,p1); close(f1); figs{end+1} = p1; %#ok<AGROW>
    end
catch
end

% 추천 설정 1행
bestLine = '';
try
    if ~isempty(S) && any(strcmpi(S.Properties.VariableNames,'score'))
        [~, idx] = max(S.score);
        Tbest = S(idx,:);
        % 안전한 문자열 변환
        pstr = char(string(Tbest.Param));
        tstr = char(string(Tbest.FilterType));
        dstr = char(string(Tbest.FilterDesign));
        mstr = char(string(Tbest.FilterMode));
        bestLine = sprintf('Param=%s, FilterType=%s, CutoffHz=%s, BandstopHz=%s, Order=%s, Design=%s, Mode=%s, EventK=%s, success=%.3f, FP(|S|)/min=%.3f, FP(∠)/min=%.3f', ...
            pstr, tstr, num2str(Tbest.CutoffHz), i_vec(Tbest.BandstopHz), ...
            num2str(Tbest.FilterOrder), dstr, mstr, num2str(Tbest.EventK), Tbest.success_rate, Tbest.fp_mag_per_min, Tbest.fp_phase_per_min);
    end
catch
end

% Markdown 본문
md = {};
md{end+1} = '# Transition Alignment Report';
md{end+1} = ''; %#ok<AGROW>
md{end+1} = sprintf('- Generated: %s', datestr(now,'yyyy-mm-dd HH:MM:SS'));
md{end+1} = sprintf('- Base folder: %s', baseExp);
md{end+1} = '';
%% Methods
md{end+1} = '## Methods';
md{end+1} = '- GT(온도 이벤트): S11→Ch1, S22→Ch2; dT/dt≥0.1°C/s 스냅(±5s), MinSep=30s.';
md{end+1} = '- S-파라: s2p 캐시→결합, Bessel 저역통과(causal), 컷오프/차수 스윕.';
md{end+1} = '- 이벤트 정합: 온도 이후 0..5 s 윈도우 내 |S| 또는 ∠ 이벤트 존재 여부.';
md{end+1} = '- 성공률(표준): 온도 이벤트×주파수 단위. 이벤트 기준(any)도 별도 요약.';
md{end+1} = '';
if ~isempty(bestLine)
    md{end+1} = '## Recommended Settings';
    md{end+1} = ['- ' bestLine];
    md{end+1} = '';
end
if ~isempty(R)
    md{end+1} = '## Evaluation Summary';
    try
        succ = mean(R.success);
        % 성공률(세부): per-(event×freq) 기준
        succ_detailed = mean(R.success);
        % 성공률(이벤트): event 기준(any) — 파일/계산 우선 사용
        succ_event = NaN;
        try
            E2 = readtable(fullfile(baseExp,'transition_event_level_summary.csv'));
            succ_event = mean(E2.hit_any);
        catch
            try
                tt = R.t_temp; if ~isdatetime(tt), tt = datetime(string(tt)); end
                [G, ~, ~, ~] = findgroups(R.exp, R.param, tt);
                hit_any = splitapply(@(x) any(x>0), double(R.success), G);
                succ_event = mean(hit_any);
            catch
            end
        end
        % FP/min 계산(가능 시 detail 사용)
        fp_mag = NaN; fp_ph = NaN;
        try
            fp = evalin('base','which'); %#ok<VUNUS>
        catch
        end
        try
            % 재계산 경량판: exp별 time_s 범위와 FP 카운트 추정은 평가 단계에서 수행됨
            % 여기서는 파일이 있으면 표를 참고하고, 없으면 생략
        catch
        end
        if ~isnan(succ_event)
            md{end+1} = sprintf('- Success rate: %.1f%% (event), %.1f%% (detailed)', 100*succ_event, 100*succ_detailed);
        else
            md{end+1} = sprintf('- Success rate (detailed): %.1f%% (%d/%d)', 100*succ_detailed, nnz(R.success), height(R));
        end
        md{end+1} = sprintf('- Mean Δt (|S|): %.3f s', mean(R.delta_mag_s,'omitnan'));
        md{end+1} = sprintf('- Mean Δt (∠): %.3f s', mean(R.delta_phase_s,'omitnan'));
    catch
    end
    md{end+1} = '';
end
if ~isempty(figs)
    md{end+1} = '## Figures';
    for i = 1:numel(figs)
        rel = strrep(figs{i}, [repDir filesep], '');
        md{end+1} = sprintf('![%s](%s)', rel, rel);
    end
    md{end+1} = '';
end
if ~isempty(S)
    % Search space summary
    try
        md{end+1} = '## Search Space';
        cu = unique(S.CutoffHz); md{end+1} = sprintf('- CutoffHz: [%g .. %g] Hz (%d values)', min(cu), max(cu), numel(cu));
        ou = unique(S.FilterOrder); md{end+1} = sprintf('- FilterOrder: %s', i_listnum(ou));
        md{end+1} = sprintf('- FilterDesign: %s', i_liststr(unique(string(S.FilterDesign))));
        md{end+1} = sprintf('- FilterMode: %s', i_liststr(unique(string(S.FilterMode))));
        md{end+1} = sprintf('- EventK: %s', i_listnum(unique(S.EventK)));
        if any(strcmpi(S.Properties.VariableNames,'TempK'))
            md{end+1} = sprintf('- TempK: %s', i_listnum(unique(S.TempK)));
        end
        md{end+1} = '';
    catch
    end
    md{end+1} = '## Top 5 Configurations (by score)';
    try
        [~, order] = sort(S.score, 'descend');
        k = min(5, numel(order));
        for j = 1:k
            irow = order(j);
            if any(strcmpi(S.Properties.VariableNames,'TempK'))
                % FP 표기: count가 있으면 count, 없으면 per_min
                hasCnt = all(ismember({'fp_mag_count','fp_phase_count'}, S.Properties.VariableNames));
                if hasCnt
                    md{end+1} = sprintf('%d) Param=%s | Type=%s | Cutoff=%s | Order=%s | Mode=%s | K=%s/%s | success=%.3f | FP(|S|)=%.3f | FP(∠)=%.3f | score=%.3f', ...
                        j, string(S.Param(irow)), string(S.FilterType(irow)), num2str(S.CutoffHz(irow)), num2str(S.FilterOrder(irow)), string(S.FilterMode(irow)), num2str(S.EventK(irow)), num2str(S.TempK(irow)), S.success_rate(irow), S.fp_mag_count(irow), S.fp_phase_count(irow), S.score(irow));
                else
                    md{end+1} = sprintf('%d) Param=%s | Type=%s | Cutoff=%s | Order=%s | Mode=%s | K=%s/%s | success=%.3f | FP(|S|)/min=%.3f | FP(∠)/min=%.3f | score=%.3f', ...
                        j, string(S.Param(irow)), string(S.FilterType(irow)), num2str(S.CutoffHz(irow)), num2str(S.FilterOrder(irow)), string(S.FilterMode(irow)), num2str(S.EventK(irow)), num2str(S.TempK(irow)), S.success_rate(irow), S.fp_mag_per_min(irow), S.fp_phase_per_min(irow), S.score(irow));
                end
            else
                % success_rate = event 기준, success_rate_detailed = 세부
                hasDet = any(strcmpi(S.Properties.VariableNames,'success_rate_detailed'));
                hasCnt = all(ismember({'fp_mag_count','fp_phase_count'}, S.Properties.VariableNames));
                if hasDet && hasCnt
                    md{end+1} = sprintf('%d) Param=%s | Type=%s | Cutoff=%s | Order=%s | Mode=%s | K=%s | success(ev)=%.3f | success(det)=%.3f | FP(|S|)=%.3f | FP(∠)=%.3f | score=%.3f', ...
                        j, string(S.Param(irow)), string(S.FilterType(irow)), num2str(S.CutoffHz(irow)), num2str(S.FilterOrder(irow)), string(S.FilterMode(irow)), num2str(S.EventK(irow)), S.success_rate(irow), S.success_rate_detailed(irow), S.fp_mag_count(irow), S.fp_phase_count(irow), S.score(irow));
                elseif hasDet
                    md{end+1} = sprintf('%d) Param=%s | Type=%s | Cutoff=%s | Order=%s | Mode=%s | K=%s | success(ev)=%.3f | success(det)=%.3f | FP(|S|)/min=%.3f | FP(∠)/min=%.3f | score=%.3f', ...
                        j, string(S.Param(irow)), string(S.FilterType(irow)), num2str(S.CutoffHz(irow)), num2str(S.FilterOrder(irow)), string(S.FilterMode(irow)), num2str(S.EventK(irow)), S.success_rate(irow), S.success_rate_detailed(irow), S.fp_mag_per_min(irow), S.fp_phase_per_min(irow), S.score(irow));
                elseif hasCnt
                    md{end+1} = sprintf('%d) Param=%s | Type=%s | Cutoff=%s | Order=%s | Mode=%s | K=%s | success=%.3f | FP(|S|)=%.3f | FP(∠)=%.3f | score=%.3f', ...
                        j, string(S.Param(irow)), string(S.FilterType(irow)), num2str(S.CutoffHz(irow)), num2str(S.FilterOrder(irow)), string(S.FilterMode(irow)), num2str(S.EventK(irow)), S.success_rate(irow), S.fp_mag_count(irow), S.fp_phase_count(irow), S.score(irow));
                else
                    md{end+1} = sprintf('%d) Param=%s | Type=%s | Cutoff=%s | Order=%s | Mode=%s | K=%s | success=%.3f | FP(|S|)/min=%.3f | FP(∠)/min=%.3f | score=%.3f', ...
                        j, string(S.Param(irow)), string(S.FilterType(irow)), num2str(S.CutoffHz(irow)), num2str(S.FilterOrder(irow)), string(S.FilterMode(irow)), num2str(S.EventK(irow)), S.success_rate(irow), S.fp_mag_per_min(irow), S.fp_phase_per_min(irow), S.score(irow));
                end
            end
        end
        md{end+1} = '';
    catch
    end
end

% 저장

% 이벤트 레벨 요약 섹션 추가
if ~isempty(E)
    md{end+1} = '## Event-Level Summary';
    try
        tot = height(E);
        anyRate = mean(E.hit_any);
        magRate = mean(E.hit_mag);
        phRate  = mean(E.hit_phase);
        md{end+1} = sprintf('- Events: %d', tot);
        md{end+1} = sprintf('- Success(any): %.1f%%%% (%d/%d)', 100*anyRate, nnz(E.hit_any), tot);
        md{end+1} = sprintf('- Success(|S|): %.1f%%%% (%d/%d)', 100*magRate, nnz(E.hit_mag), tot);
        md{end+1} = sprintf('- Success(∠): %.1f%%%% (%d/%d)', 100*phRate, nnz(E.hit_phase), tot);
        ps = unique(string(E.param));
        for i = 1:numel(ps)
            m = string(E.param) == ps(i);
            if any(m)
                md{end+1} = sprintf('  - %s: any=%.1f%%%% (%d/%d), |S|=%.1f%%%%, ∠=%.1f%%%%', ps(i), ...
                    100*mean(E.hit_any(m)), nnz(E.hit_any(m)), nnz(m), 100*mean(E.hit_mag(m)), 100*mean(E.hit_phase(m)));
            end
        end
        md{end+1} = '';
    catch
    end
end
% Selected settings per port
if ~isempty(S)
    md{end+1} = '## Selected Settings (Per Port)';
    try
        ports = unique(string(S.Param));
        for j = 1:numel(ports)
            p = ports(j);
            Sm = S(string(S.Param)==p,:);
            if isempty(Sm), continue; end
            [~,ix] = max(Sm.score);
            Tbest = Sm(ix,:);
            if any(strcmpi(S.Properties.VariableNames,'TempK'))
                md{end+1} = sprintf('- %s: Type=%s | Cutoff=%.3g Hz | Order=%s | Mode=%s | K=%s/%s | success=%.3f | FP(|S|)/min=%.3f | FP(∠)/min=%.3f', ...
                    string(Tbest.Param), string(Tbest.FilterType), Tbest.CutoffHz, num2str(Tbest.FilterOrder), string(Tbest.FilterMode), num2str(Tbest.EventK), num2str(Tbest.TempK), Tbest.success_rate, Tbest.fp_mag_per_min, Tbest.fp_phase_per_min);
            else
                if any(strcmpi(S.Properties.VariableNames,'success_rate_detailed'))
                    md{end+1} = sprintf('- %s: Type=%s | Cutoff=%.3g Hz | Order=%s | Mode=%s | K=%s | success(ev)=%.3f | success(det)=%.3f | FP(|S|)/min=%.3f | FP(∠)/min=%.3f', ...
                        string(Tbest.Param), string(Tbest.FilterType), Tbest.CutoffHz, num2str(Tbest.FilterOrder), string(Tbest.FilterMode), num2str(Tbest.EventK), Tbest.success_rate, Tbest.success_rate_detailed, Tbest.fp_mag_per_min, Tbest.fp_phase_per_min);
                else
                    md{end+1} = sprintf('- %s: Type=%s | Cutoff=%.3g Hz | Order=%s | Mode=%s | K=%s | success=%.3f | FP(|S|)/min=%.3f | FP(∠)/min=%.3f', ...
                        string(Tbest.Param), string(Tbest.FilterType), Tbest.CutoffHz, num2str(Tbest.FilterOrder), string(Tbest.FilterMode), num2str(Tbest.EventK), Tbest.success_rate, Tbest.fp_mag_per_min, Tbest.fp_phase_per_min);
                end
            end
        end
        md{end+1} = '';
    catch
    end
end

% 최상 설정 저장(JSON/MAT): 전체 1행 + 포트별 최상
try
    if ~isempty(S) && any(strcmpi(S.Properties.VariableNames,'score'))
        best = struct();
        best.generated_at = datestr(now,'yyyy-mm-dd HH:MM:SS');
        best.base_folder = baseExp;
        % overall best
        [~, idxBest] = max(S.score);
        best.overall = i_row_to_struct(S(idxBest,:));
        % per-port best
        best.per_port = struct([]);
        try
            ports = unique(string(S.Param));
            pp = struct([]);
            for j = 1:numel(ports)
                p = ports(j);
                Sm = S(string(S.Param)==p,:);
                if isempty(Sm), continue; end
                [~,ix] = max(Sm.score);
                pj = i_row_to_struct(Sm(ix,:));
                pj.Param = char(p);
                pp(end+1) = pj; %#ok<AGROW>
            end
            best.per_port = pp;
        catch
        end
        % save files
        outJson = fullfile(baseExp, 'best_settings.json');
        outMat  = fullfile(baseExp, 'best_settings.mat');
        try
            txt = jsonencode(best, 'PrettyPrint', true);
            fid = fopen(outJson,'w'); if fid>0, fwrite(fid, txt, 'char'); fclose(fid); end
        catch
        end
        try
            save(outMat, 'best');
        catch
        end
    end
catch
end

% 추천 설정으로 최종 플롯 이미지 생성(없으면 생성)
try
    if ~isempty(S)
        % 실험 목록 결정: 결과 테이블 우선, 없으면 expdata 하위 폴더 스캔
        expsList = strings(0,1);
        try
            if ~isempty(R) && any(strcmpi(R.Properties.VariableNames,'exp'))
                expsList = unique(string(R.exp));
            else
                d = dir(baseExp);
                for ii = 1:numel(d)
                    if d(ii).isdir && d(ii).name(1) ~= '.'
                        expsList(end+1,1) = string(d(ii).name); %#ok<AGROW>
                    end
                end
            end
        catch
        end

        ports = unique(string(S.Param));
        for j = 1:numel(ports)
            p = ports(j);
            Sm = S(string(S.Param) == p, :);
            if isempty(Sm), continue; end
            [~, ix] = max(Sm.score);
            Tbest = Sm(ix, :);
            for kk = 1:numel(expsList)
                expDir = fullfile(baseExp, char(expsList(kk)));
                if exist(expDir,'dir') ~= 7, continue; end
                spDir = expDir;
                if exist(fullfile(expDir,'sParam'),'dir') == 7
                    spDir = fullfile(expDir,'sParam');
                end
                try
                    args = {'Param', char(p), 'Save', true, 'Plot', true, 'SaveFig', true, 'FigFormats', {'fig','png'}, ...
                            'PlotFilterResponse', false, 'SaveFilterFig', false, 'RunWavelet', false, ...
                            'FilterMode', char(Tbest.FilterMode), 'FilterOrder', Tbest.FilterOrder, ...
                            'FilterDesign', char(Tbest.FilterDesign), 'FilterType', char(Tbest.FilterType)};
                    if ~isempty(F)
                        args = [args, {'Freq', F, 'FreqUnit', char(FU)}];
                    end
                    if strcmpi(char(Tbest.FilterType), 'bandstop')
                        bs = Tbest.BandstopHz;
                        if iscell(bs), bs = bs{1}; end
                        args = [args, {'BandstopHz', bs}];
                    else
                        args = [args, {'CutoffHz', Tbest.CutoffHz}];
                    end
                    combine_sparam_lowpass(spDir, args{:});
                catch
                end
            end
        end
    end
catch
end
% 이벤트 레벨 요약 섹션 추가
if ~isempty(E)
    md{end+1} = '## Event-Level Summary';
    try
        tot = height(E); anyRate = mean(E.hit_any); magRate = mean(E.hit_mag); phRate = mean(E.hit_phase);
        md{end+1} = sprintf('- Events: %d', tot);
        md{end+1} = sprintf('- Success(any): %.1f%%%% (%d/%d)', 100*anyRate, nnz(E.hit_any), tot);
        md{end+1} = sprintf('- Success(|S|): %.1f%%%% (%d/%d)', 100*magRate, nnz(E.hit_mag), tot);
        md{end+1} = sprintf('- Success(∠): %.1f%%%% (%d/%d)', 100*phRate, nnz(E.hit_phase), tot);
        ps = unique(string(E.param));
        for i = 1:numel(ps)
            m = string(E.param) == ps(i);
            if any(m)
                md{end+1} = sprintf('  - %s: any=%.1f%%%% (%d/%d), |S|=%.1f%%%%, ∠=%.1f%%%%', ps(i), 100*mean(E.hit_any(m)), nnz(E.hit_any(m)), nnz(m), 100*mean(E.hit_mag(m)), 100*mean(E.hit_phase(m)));
            end
        end
        md{end+1} = '';
    catch; end
end
% Precision/Recall (from sparam events)
try
    P = readtable(fullfile(baseExp,'precision_recall_summary.csv'));
catch
    try, P = compute_precision_recall(); catch, P = table(); end
end
if ~isempty(P)
    md{end+1} = '## Precision / Recall';
    try
        for i = 1:height(P)
            md{end+1} = sprintf('- %s: precision(|S|)=%.3f, precision(∠)=%.3f, recall(any)=%.3f', string(P.param(i)), P.precision_mag(i), P.precision_phase(i), P.recall_any(i));
        end
        md{end+1} = '';
    catch
    end
end

% Result plots (final settings)
try
    md{end+1} = '## Result Plots (Final Settings)';
    exps = dir(fullfile(baseExp,'*'));
    listed = 0;
    for k=1:numel(exps)
        if ~exps(k).isdir, continue; end
        dn = exps(k).name;
        if dn(1)=='.', continue; end
        rd = fullfile(exps(k).folder, dn, 'results');
        if exist(rd,'dir') ~= 7
            rd = fullfile(exps(k).folder, dn, 'sParam');
            relBase = fullfile('..','expdata', dn, 'sParam');
        else
            relBase = fullfile('..','expdata', dn, 'results');
        end
        f1 = fullfile(rd, 'sparam_combined_filtered_s11.png');
        f2 = fullfile(rd, 'sparam_combined_filtered_s22.png');
        rel1 = fullfile(relBase, 'sparam_combined_filtered_s11.png');
        rel2 = fullfile(relBase, 'sparam_combined_filtered_s22.png');
        if exist(f1,'file')==2 || exist(f2,'file')==2
            md{end+1} = sprintf('- %s:', dn);
            if exist(f1,'file')==2, md{end+1} = sprintf('<img src="%s" width="100%%" /><br>', rel1); end
            if exist(f2,'file')==2, md{end+1} = sprintf('<img src="%s" width="100%%" /><br>', rel2); end
            md{end+1} = '';
            listed = listed + 1;
        end
    end
    if listed==0, md{end+1} = '- (no plot files found)'; md{end+1} = ''; end
catch
end
outPath = fullfile(repDir,'transition_alignment_report.md');
fid = fopen(outPath,'w');
for i = 1:numel(md), fprintf(fid,'%s\n', md{i}); end
fclose(fid);
fprintf('리포트 저장: %s\n', outPath);

end

function s = i_vec(v)
try
    if iscell(v), v = v{1}; end
    if ischar(v) || isstring(v)
        s = char(v);
    else
        v = v(:)';
        s = sprintf('[%g %g]', v);
    end
catch
    s = '';
end
end

function st = i_row_to_struct(Trow)
% i_row_to_struct  1행 table을 struct로 변환(셀/문자/수치 안전 변환)
try
    st = struct();
    vn = Trow.Properties.VariableNames;
    for i = 1:numel(vn)
        val = Trow.(vn{i});
        if istable(val); val = table2struct(val); end
        if iscell(val) && numel(val)==1, val = val{1}; end
        if isstring(val) && isscalar(val), val = char(val); end
        if isdatetime(val) && isscalar(val)
            try, val = datestr(val,'yyyy-mm-dd HH:MM:SS'); catch, end
        end
        if isduration(val) && isscalar(val)
            try, val = seconds(val); catch, end
        end
        if istimetable(val)
            val = timetable2table(val);
        end
        if istable(val)
            try, val = table2struct(val); catch, end
        end
        if iscategorical(val)
            val = char(string(val));
        end
        if isscalar(val)
            st.(vn{i}) = val;
        else
            try
                st.(vn{i}) = val;
            catch
                try, st.(vn{i}) = char(string(val)); catch, st.(vn{i}) = val; end
            end
        end
    end
catch
    st = struct();
end
end
