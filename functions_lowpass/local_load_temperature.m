function Ttemp = local_load_temperature(tempDir, pattern)
% Temp*.csv 파일을 읽어 타임스탬프와 채널 값을 반환
files = dir(fullfile(tempDir, char(pattern)));
if isempty(files) && ~strcmpi(char(pattern), 'Temp.csv')
    % 강제 Temp.csv 우선
    files = dir(fullfile(tempDir, 'Temp.csv'));
end
if isempty(files)
    Ttemp = struct('Time', [], 'Values', [], 'Labels', {{} });
    return;
end

% 파일명 자연 정렬
[~, idx] = sort({files.name});
files = files(idx);

TimeAll = datetime.empty(0,1);
ValsAll = [];
Labels  = {};

for k = 1:numel(files)
    fp = fullfile(files(k).folder, files(k).name);
    opts = detectImportOptions(fp, 'NumHeaderLines', 0);
    opts.ExtraColumnsRule = 'ignore';
    opts.EmptyLineRule = 'read';
    T = readtable(fp, opts);

    % 시간 열 찾기
    tcol = find(contains(lower(T.Properties.VariableNames), 'time'), 1, 'first');
    if isempty(tcol)
        tcol = 1; % 첫 열 fallback
    end
    tval = T{:, tcol};
    if ~isdatetime(tval)
        % 문자열/셀/카테고리형 우선 처리
        if iscell(tval) || isstring(tval) || ischar(tval) || iscategorical(tval)
            try
                tval = datetime(string(tval), 'InputFormat','yyyy-MM-dd HH:mm:ss');
            catch
                try
                    tval = datetime(string(tval));
                catch
                    % 파싱 실패 시 NaT로 채움
                    tval = NaT(size(tval));
                end
            end
        elseif isnumeric(tval)
            % 숫자형: excel/datenum 직렬 날짜일 가능성
            try
                tval = datetime(tval, 'ConvertFrom','excel');
            catch
                try
                    tval = datetime(tval, 'ConvertFrom','datenum');
                catch
                    tval = NaT(size(tval));
                end
            end
        else
            tval = NaT(size(tval));
        end
    end

    % 값 열(숫자형) 선택: 시간 열 제외
    numCols = varfun(@isnumeric, T, 'OutputFormat','uniform');
    if tcol>=1 && tcol<=numel(numCols)
        numCols(tcol) = false;
    end
    valCols = find(numCols);
    if isempty(valCols)
        % 비숫자 열 중 temperature/degC/ch 같은 열 찾기
        cand = find(contains(lower(T.Properties.VariableNames), {'temp','deg','ch'}));
        cand = cand(cand ~= tcol);
        if ~isempty(cand)
            valCols = cand(:).';
        else
            % 유효한 값 열이 없으면 이 파일은 건너뜀
            warning('local_load_temperature:NoValueCols', '값 열을 찾지 못해 건너뜀: %s', fp);
            continue;
        end
    end
    V = T{:, valCols};
    if ~isnumeric(V)
        V = str2double(string(V));
    end
    if isvector(V), V = V(:); end

    % 라벨 생성
    labs = T.Properties.VariableNames(valCols);

    % 유니온 라벨 세트 업데이트 및 열 정렬
    oldLabels = Labels;
    Labels = union(Labels, labs, 'stable');
    if isempty(ValsAll)
        % 초기화: 현재 파일의 라벨 순서에 맞춰 생성
        Vrow = nan(size(V,1), numel(Labels));
        [~, loc] = ismember(labs, Labels);
        Vrow(:, loc) = V;
        ValsAll = Vrow;
    else
        % 기존 행렬을 새 라벨 수에 맞게 확장
        if numel(Labels) > numel(oldLabels)
            ValsAll(:, end+1:numel(Labels)) = NaN;
        end
        % 현재 파일 값을 라벨 위치에 매핑하여 행 추가
        Vrow = nan(size(V,1), numel(Labels));
        [~, loc] = ismember(labs, Labels);
        Vrow(:, loc) = V;
        ValsAll = [ValsAll; Vrow]; %#ok<AGROW>
    end
    TimeAll = [TimeAll; tval]; %#ok<AGROW>
end

% 정렬 및 중복 제거
[TimeAll, idxS] = sort(TimeAll, 'ascend');
ValsAll = ValsAll(idxS, :);
[TimeAll, idxU] = unique(TimeAll, 'stable');
ValsAll = ValsAll(idxU, :);

Ttemp = struct('Time', TimeAll, 'Values', ValsAll, 'Labels', {Labels});
end
