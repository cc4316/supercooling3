function T = load_temp_csv_basic(tempDir, varargin)
% load_temp_csv_basic  Temp.csv를 견고하게 로드하여 시간/값/라벨 반환
% 사용법
%   T = load_temp_csv_basic(tempDir)
%   T = load_temp_csv_basic(tempDir, 'Pattern','Temp.csv')
%
% 반환 구조체 T 필드
%   - Time   : datetime 벡터 (가능하면), 없으면 NaT
%   - Values : 숫자 행렬 [N x C]
%   - Labels : 채널 라벨 셀배열(가능하면), 없으면 {'Ch1',...}
%   - Path   : 실제 로드한 파일 경로
%
% 주: plottemperature2.m의 로더를 간소화/비파괴 형태로 재구성

ip = inputParser;
ip.addParameter('Pattern', 'Temp.csv', @(s)ischar(s)||isstring(s));
ip.parse(varargin{:});
pat = char(ip.Results.Pattern);

T = struct('Time', datetime.empty(0,1), 'Values', [], 'Labels', {{}}, 'Path','');
if nargin < 1 || isempty(tempDir) || exist(tempDir,'dir') ~= 7
    error('load_temp_csv_basic:BadDir','유효한 Temp 폴더가 아닙니다.');
end

fpath = fullfile(tempDir, pat);
if exist(fpath,'file') ~= 2
    error('load_temp_csv_basic:NotFound','파일이 없습니다: %s', fpath);
end

opts = detectImportOptions(fpath, 'Delimiter', ',', 'TextType','string');
try, opts.ExtraColumnsRule = 'ignore'; catch, end
try, opts.EmptyLineRule   = 'read';   catch, end

% Time 열이 있으면 문자로 강제
vnames = opts.VariableNames;
if ismember('Time', vnames)
    opts = setvartype(opts, 'Time', 'char');
elseif ~isempty(vnames)
    % 첫 컬럼 이름을 dtime으로 치환
    try, opts.VariableNames{1} = 'dtime'; catch, end
    opts = setvartype(opts, 'dtime', 'char');
end

tbl = readtable(fpath, opts);
vn = tbl.Properties.VariableNames;

% 라벨 구성 (헤더에 Ch* 있으면 사용)
lab = {};
chCols = startsWith(vn, 'Ch');
if any(chCols)
    lab = cellstr(vn(chCols));
end

% 시간 파싱
t = NaT(height(tbl),1);
if ismember('Date', vn) && ismember('Time', vn)
    dateStr = string(tbl.Date);
    timeStr = string(tbl.Time);
    combined = strtrim(dateStr + " " + timeStr);
    combined = regexprep(combined, "\s+", " ");
    try, t = datetime(combined, 'InputFormat','yyyy-MM-dd HH:mm:ss'); catch, end
    try, bad = isnat(t); t(bad) = datetime(combined(bad), 'InputFormat','yyyy-MM-dd a hh:mm:ss', 'Locale','ko_KR'); catch, end
elseif ismember('Time', vn)
    t = i_parse_time_column(tbl.Time);
elseif ismember('dtime', vn)
    t = i_parse_time_column(tbl.dtime);
elseif width(tbl) >= 2 && strcmpi(vn{1},'Var1') && strcmpi(vn{2},'Var2')
    % (Var1=date, Var2='hh:mm:ss, v1, v2, ...') 패턴 처리
    dayPart = string(tbl.Var1);
    timeStr = extractBefore(string(tbl.Var2), ',');
    combined = strtrim(dayPart + " " + timeStr);
    try
        t = datetime(combined,'InputFormat','yyyy-MM-dd HH:mm:ss');
    catch
        t = datetime(combined,'Locale','ko_KR');
    end
end
if ~isempty(t)
    try, t.Format = 'yyyy-MM-dd HH:mm:ss'; catch, end
else
    t = NaT(height(tbl),1);
end

% 값 파싱
if any(chCols)
    vals = tbl{:, chCols};
else
    % 첫 열 시간, 나머지 수치로 가정
    vals = tbl{:, 2:end};
end
if iscell(vals)
    vals = cellfun(@str2double, vals);
elseif isstring(vals)
    vals = str2double(vals);
end

% 라벨 보강
if isempty(lab)
    nC = size(vals,2);
    lab = arrayfun(@(k)sprintf('Ch%d',k), 1:nC,'UniformOutput',false);
end

T.Time = t;
T.Values = vals;
T.Labels = lab;
T.Path = fpath;

end

function t = i_parse_time_column(col)
    if isdatetime(col)
        t = col;
        return;
    end
    if isnumeric(col)
        try
            t = datetime(col, 'ConvertFrom','excel');
        catch
            t = datetime(col, 'ConvertFrom','datenum');
        end
        return;
    end
    dstr = string(col);
    fmts = ["yyyy-MM-dd HH:mm:ss"; "yyyy/MM/dd HH:mm:ss"; "yyyy-MM-dd a hh:mm:ss"; "yyyy/MM/dd a hh:mm:ss"];
    t = NaT(size(dstr));
    for fi = 1:numel(fmts)
        try
            if contains(fmts(fi),'a')
                tt = datetime(dstr,'InputFormat',fmts(fi),'Locale','ko_KR');
            else
                tt = datetime(dstr,'InputFormat',fmts(fi));
            end
            bad = isnat(t) & ~isnat(tt);
            t(bad) = tt(bad);
        catch
        end
    end
    if any(isnat(t))
        try
            t(isnat(t)) = datetime(dstr(isnat(t)),'Locale','ko_KR');
        catch
        end
    end
end

