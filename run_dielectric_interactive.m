function run_dielectric_interactive
% RUN_DIELECTRIC_INTERACTIVE Console-style prompts (like check_s2p_ports).
%
% - 폴더 자동탐색/목록 선택/수동 선택(uigetdir)
% - 주파수(기본 24 GHz), 온도 채널(기본 9:12), 저장 여부, 스무딩, 온도 y-최대값 질의
% - run_dielectric_pipeline을 호출

    % 1) 루트 폴더 선택 (expdata 하위 자동탐색 후 목록 선택)
    cands = string.empty(1,0);
    if isfolder('expdata')
        d1 = dir(fullfile('expdata','*'));
        for k = 1:numel(d1)
            if d1(k).isdir && ~startsWith(d1(k).name, '.')
                p = fullfile('expdata', d1(k).name);
                % 후보 기준: 폴더명에 'dielectric' 포함 or PRN/CSV 포함
                hasData = ~isempty(dir(fullfile(p, '**', '*.prn'))) || ~isempty(dir(fullfile(p, '**', '*.csv')));
                if contains(lower(d1(k).name), 'dielectric') || hasData
                    cands(end+1) = string(p); %#ok<AGROW>
                end
            end
        end
    end
    if numel(cands) == 1
        rootDir = char(cands);
        fprintf('자동 감지된 루트 폴더: %s\n', rootDir);
    elseif numel(cands) > 1
        fprintf('여러 후보 폴더가 감지되었습니다. 번호를 선택하세요:\n');
        for i = 1:numel(cands)
            fprintf('  [%d] %s\n', i, cands(i));
        end
        idx = input('번호 입력 (기타/취소는 Enter): ');
        if isempty(idx) || ~isscalar(idx) || idx < 1 || idx > numel(cands)
            rootDir = uigetdir(pwd, '유전율 데이터 루트 폴더 선택');
        else
            rootDir = char(cands(idx));
        end
    else
        rootDir = uigetdir(pwd, '유전율 데이터 루트 폴더 선택');
    end
    if isequal(rootDir, 0)
        error('폴더가 선택되지 않았습니다.');
    end

    % 2) 주파수 입력 (GHz)
    s = input('플롯 주파수 (GHz, 쉼표/공백 구분, 기본 24): ', 's');
    if isempty(strtrim(s))
        ghz_list = 24;
    else
        ghz_list = str2num(s); %#ok<ST2NM>
        if isempty(ghz_list)
            error('주파수 입력 형식이 잘못되었습니다. 예: 8,10,24');
        end
    end
    freqList = ghz_list * 1e9;

    % 3) 온도 채널 입력
    s = input('온도 채널 (예: 9:12, 1,2,3, mean, Ch10) [기본 9:12]: ', 's');
    if isempty(strtrim(s))
        tempChannels = 9:12;
    else
        if strcmpi(strtrim(s), 'mean')
            tempChannels = 'mean';
        elseif startsWith(lower(strtrim(s)), 'ch')
            tempChannels = ['Ch' extractAfter(strtrim(s), 2)];
        else
            try
                tempChannels = eval(s); % 9:12 또는 [1 2 3]
            catch
                error('온도 채널 입력 형식이 잘못되었습니다. 예: 9:12 또는 1,2,3 또는 mean');
            end
        end
    end

    % 4) PNG/FIG 저장 여부 (y 선택 시 PNG와 FIG 동시 저장)
    s = input('플롯을 PNG/FIG로 저장? [y/N]: ', 's');
    saveFigs = ~isempty(s) && any(lower(s(1)) == 'y');

    % 5) 스무딩 윈도우 (0=없음)
    s = input('스무딩 윈도우 크기 (0=없음, 기본 0): ', 's');
    if isempty(strtrim(s)), smoothN = 0; else, smoothN = str2double(s); end
    if isnan(smoothN) || smoothN < 0
        error('스무딩 값이 올바르지 않습니다.');
    end

    % 6) 온도 y축 최대값 (빈칸=자동, 기본 5)
    s = input('온도 y축 최대값 (빈칸=자동, 기본 5): ', 's');
    if isempty(strtrim(s))
        tempYMax = 5;
    else
        tempYMax = str2double(s);
        if isnan(tempYMax)
            error('숫자를 입력하세요. 예: 5');
        end
    end

    % 7) 실행
    args = {'TempChannel', tempChannels, 'SaveFigs', saveFigs, 'SmoothN', smoothN};
    if ~isempty(tempYMax)
        args = [args, {'TempYMax', tempYMax}]; %#ok<AGROW>
    end
    run_dielectric_pipeline(rootDir, freqList, args{:});
end
