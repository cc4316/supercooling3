function plot_temp_events_gt(expDir, varargin)
% plot_temp_events_gt  Temp.csv 위에 저장된 온도 이벤트(GT) 표시
%
% 사용법
%   plot_temp_events_gt(expDir)                  % 기본 Param='S11'
%   plot_temp_events_gt(expDir, 'Param','S22')   % S22 기준 채널 구성
%
% 옵션(Name-Value)
%   'Param'      : 'S11'|'S22' (기본 'S11') — 채널 구성 CSV의 P1/P2 선택
%   'Pattern'    : 온도 파일 패턴(기본 'Temp.csv')
%   'ShowDeriv'  : 하단에 dT/dt도 함께 표시 (기본 true)
%   'SaveFig'    : 그림 저장 여부 (기본 false)
%   'OutDir'     : 저장 폴더 (기본 expDir)
%   'UseManual'  : true면 *_manual.csv 사용, false면 기본 CSV, []이면 자동(기본 [] → _manual이 있으면 우선)
%   'EventsFile' : 이벤트 CSV 경로 직접 지정(우선순위 최상)
%
% 비고
% - evaluate_transition_alignment 실행 시 각 실험 폴더에 생성된
%   'TempChannelSelection.csv'와 'temp_events_<Param>.csv'를 사용해
%   GT 이벤트 시각을 그대로 표시합니다(재검출 아님).

ip = inputParser;
ip.addParameter('Param','S11', @(s)ischar(s)||isstring(s));
ip.addParameter('Pattern','Temp.csv', @(s)ischar(s)||isstring(s));
ip.addParameter('ShowDeriv', true, @(x)islogical(x)&&isscalar(x));
ip.addParameter('SaveFig', false, @(x)islogical(x)&&isscalar(x));
ip.addParameter('OutDir','', @(s)ischar(s)||isstring(s));
ip.addParameter('UseManual', [], @(x) isempty(x) || (islogical(x)&&isscalar(x)) );
ip.addParameter('EventsFile','', @(s)ischar(s)||isstring(s));
ip.parse(varargin{:});
opt = ip.Results;

if nargin < 1 || isempty(expDir) || exist(expDir,'dir') ~= 7
    error('plot_temp_events_gt:BadDir','유효한 실험 폴더를 지정하세요.');
end

% 1) Temp 로드
Tt = load_temp_csv_basic(expDir, 'Pattern', opt.Pattern);
if isempty(Tt.Time)
    error('plot_temp_events_gt:NoTemp','온도 데이터를 찾을 수 없습니다: %s', fullfile(expDir, char(opt.Pattern)));
end

% 2) 채널 구성 로드 및 선택 집계(Tsel)
cfgCsv = fullfile(expDir, 'TempChannelSelection.csv');
if exist(cfgCsv,'file') ~= 2
    warning('채널 구성 CSV가 없어 기본(1..min(8,N))으로 표시합니다: %s', cfgCsv);
    idxT = 1:min(8, size(Tt.Values,2));
else
    try
        idxT = resolve_temp_channels_port(Tt.Labels, cfgCsv, string(opt.Param));
    catch ME
        warning('채널 구성 해석 실패(%s). 기본 채널 사용: %s', ME.message, cfgCsv);
        idxT = 1:min(8, size(Tt.Values,2));
    end
end
vals = Tt.Values(:, idxT);
Tsel = mean(vals,2,'omitnan');

% 3) GT 이벤트 CSV 로드 (수동/자동 우선순위 적용)
tag = regexprep(char(string(opt.Param)),'[^A-Za-z0-9]','');
evPathAuto = fullfile(expDir, sprintf('temp_events_%s.csv', tag));
evPathManual = fullfile(expDir, sprintf('temp_events_%s_manual.csv', tag));
evPath = '';
if strlength(opt.EventsFile) > 0
    evPath = char(opt.EventsFile);
elseif ~isempty(opt.UseManual)
    evPath = char(tern(opt.UseManual, evPathManual, evPathAuto));
else
    evPath = char(tern(exist(evPathManual,'file')==2, evPathManual, evPathAuto));
end
Tev = table();
if exist(evPath,'file') == 2
    Tev = readtable(evPath, 'VariableNamingRule','preserve');
else
    warning('온도 이벤트 CSV를 찾지 못했습니다: %s', evPath);
end

% 4) 파생량(dT/dt) — 특정 채널 기준 (S11→Ch1, S22→Ch2)
showDer = opt.ShowDeriv;
dt_s = seconds(Tt.Time - Tt.Time(1));
% 대상 채널 절대 컬럼 찾기
targetChanNum = 1; if upper(string(opt.Param)) == "S22", targetChanNum = 2; end
colAbs = NaN;
try
    labsAll = string(Tt.Labels);
    hit = find(lower(labsAll) == lower(sprintf('Ch%d', targetChanNum)), 1, 'first');
    if ~isempty(hit), colAbs = hit; end
catch
end
% 폴백: 선택 집합 중 첫 번째
if ~isfinite(colAbs) || colAbs < 1 || colAbs > size(Tt.Values,2)
    if ~isempty(idxT)
        colAbs = idxT(1);
    else
        colAbs = 1;
    end
end
chanName = sprintf('Ch%d', targetChanNum);
try
    labsAll = string(Tt.Labels);
    if colAbs >= 1 && colAbs <= numel(labsAll) && strlength(labsAll(colAbs))>0
        chanName = char(labsAll(colAbs));
    end
catch
end
Ychan = Tt.Values(:, colAbs);
dT_dt = zeros(size(Ychan));
if numel(Ychan) >= 3
    dT_dt(2:end-1) = (Ychan(3:end) - Ychan(1:end-2)) ./ (dt_s(3:end) - dt_s(1:end-2));
    dT_dt(1) = (Ychan(2)-Ychan(1)) / max(dt_s(2)-dt_s(1), eps);
    dT_dt(end) = (Ychan(end)-Ychan(end-1)) / max(dt_s(end)-dt_s(end-1), eps);
end

% 5) 플롯
if showDer
    f = figure('Name', sprintf('Temp + Events (GT) — %s', char(opt.Param)));
    tlo = tiledlayout(2,1,'TileSpacing','compact','Padding','compact');
else
    f = figure('Name', sprintf('Temp + Events (GT) — %s', char(opt.Param)));
    tlo = tiledlayout(1,1,'TileSpacing','compact','Padding','compact');
end
title(tlo, sprintf('%s — %s', expDir, sprintf('Param=%s', char(opt.Param))));

% 상단: 선택 집계 온도 + GT 이벤트
ax1 = nexttile; hold(ax1,'on'); grid(ax1,'on');
% 채널별로 색/범례를 구분하여 표시
labsSel = strings(1,size(vals,2));
try
    labsAll = string(Tt.Labels);
    labsSel = labsAll(idxT);
catch
    for ii=1:size(vals,2), labsSel(ii) = sprintf('Ch%d', idxT(ii)); end
end
cr = get(ax1,'ColorOrder');
for c = 1:size(vals,2)
    co = cr(mod(c-1,size(cr,1))+1,:);
    plot(ax1, Tt.Time, vals(:,c), '-', 'Color', co, 'LineWidth', 1.0, 'DisplayName', labsSel(c));
end
% 선택 집계 평균(Tsel)은 두껍고 진한 색으로 별도 표시
plot(ax1, Tt.Time, Tsel, '-', 'Color', [0 0 0], 'LineWidth', 1.6, 'DisplayName','Tsel (mean)');
% GT 이벤트: 수직선 + Ch1/Ch2 위치에만 마커 표시
if ~isempty(Tev)
    try
        t_ev = Tev.t; if ~isdatetime(t_ev), t_ev = datetime(string(t_ev)); end
        xline(ax1, t_ev, ':', 'Color',[0.85 0 0], 'HandleVisibility','off');
        % 채널 1,2의 절대 컬럼 찾기
        colCh1 = []; colCh2 = [];
        try
            labsAll2 = string(Tt.Labels);
            h1 = find(lower(labsAll2)=="ch1",1,'first'); if ~isempty(h1), colCh1 = h1; end
            h2 = find(lower(labsAll2)=="ch2",1,'first'); if ~isempty(h2), colCh2 = h2; end
        catch
        end
        if isempty(colCh1), if size(Tt.Values,2)>=1, colCh1 = 1; end, end
        if isempty(colCh2), if size(Tt.Values,2)>=2, colCh2 = 2; end, end
        % idxT에서 해당 컬럼의 색상을 찾기(없으면 기본색 사용)
        getColor = @(col,def) ( ...
            (~isempty(col) && any(idxT==col)) * cr(mod(find(idxT==col,1,'first')-1,size(cr,1))+1,:) + ...
            (~(~isempty(col) && any(idxT==col))) * def );
        co1 = getColor(colCh1, [0 0.4470 0.7410]);
        co2 = getColor(colCh2, [0.8500 0.3250 0.0980]);
        if ~isempty(colCh1)
            y1 = interp1(Tt.Time, Tt.Values(:,colCh1), t_ev, 'linear','extrap');
            scatter(ax1, t_ev, y1, 24, co1, 'filled', 'MarkerEdgeColor','k', 'DisplayName','GT@Ch1');
        end
        if ~isempty(colCh2)
            y2 = interp1(Tt.Time, Tt.Values(:,colCh2), t_ev, 'linear','extrap');
            scatter(ax1, t_ev, y2, 24, co2, 'filled', 'MarkerEdgeColor','k', 'DisplayName','GT@Ch2');
        end
    catch
        % CSV 파싱 실패해도 본체 플롯은 유지
    end
end
ylabel(ax1, 'Temp (°C)'); legend(ax1,'Location','bestoutside');

% 하단: dT/dt + GT
if showDer
    ax2 = nexttile; hold(ax2,'on'); grid(ax2,'on');
    plot(ax2, Tt.Time, dT_dt, 'k-', 'DisplayName', sprintf('dT/dt (%s)', chanName));
    if ~isempty(Tev)
        try
            t_ev = Tev.t; if ~isdatetime(t_ev), t_ev = datetime(string(t_ev)); end
            xline(ax2, t_ev, ':r', 'HandleVisibility','off');
            scatter(ax2, t_ev, interp1(Tt.Time, dT_dt, t_ev, 'linear','extrap'), 16, 'r', 'filled', 'DisplayName','GT events');
        catch
        end
    end
    ylabel(ax2, 'dT/dt (°C/s)'); xlabel(ax2, 'Time'); legend(ax2,'Location','best');
end

function y = tern(c,a,b)
    if c, y = a; else, y = b; end
end

% 저장 옵션
if opt.SaveFig
    outDir = char(opt.OutDir);
    if isempty(outDir), outDir = expDir; end
    if exist(outDir,'dir') ~= 7, mkdir(outDir); end
    base = fullfile(outDir, sprintf('temp_events_gt_%s', lower(char(opt.Param))));
    try, savefig(f, [base '.fig']); catch, end
    try, saveas(f, [base '.png']); catch, end
end

end
