%% Input ==================================================================
% 콘솔형 인터페이스로 폴더/옵션을 선택 (check_s2p_ports 스타일)
% 외부에서 주입되는 변수는 보존하면서 초기화
% (plottemperature2_run 등에서 전달된 설정 유지)
try
    clearvars -except frequencies_to_plot_GHz temp_y_lim sparam_y_lim sparam_S21_S12_y_lim refresh_sparam_cache dataDir
catch
    % older MATLAB compatibility
    clear variables;
end

% Ensure helper functions are on the MATLAB path
try
    here = fileparts(mfilename('fullpath'));
catch
    here = pwd; %#ok<NASGU>
end
if isfolder('functions')
    addpath('functions');
elseif exist('here','var') && isfolder(fullfile(here, 'functions'))
    addpath(fullfile(here, 'functions'));
end
% Add lowpass helpers (temperature/channel utilities)
if isfolder('functions_lowpass')
    addpath('functions_lowpass');
elseif exist('here','var') && isfolder(fullfile(here, 'functions_lowpass'))
    addpath(fullfile(here, 'functions_lowpass'));
end
% ===== Local helper functions (available in recent MATLAB versions) =====
function chs = local_select_channel_set(maxCh)
% 콘솔에서 채널 선택 옵션을 보여주고 채널 인덱스 배열을 반환합니다.
    defN = min(8, maxCh);
    fprintf('  채널 선택 옵션:\n');
    fprintf('    [Enter] 1:%d\n', defN);
    idxOpt = 2;
    if maxCh >= 16
        fprintf('    %d) 9:16\n', idxOpt); idxOpt = idxOpt+1;
    end
    fprintf('    %d) 1:4\n', idxOpt); o14 = idxOpt; idxOpt = idxOpt+1;
    if maxCh >= 8
        fprintf('    %d) 5:8\n', idxOpt); o58 = idxOpt; idxOpt = idxOpt+1;
    else
        o58 = NaN;
    end
    fprintf('    %d) 홀수 (1,3,5,...)\n', idxOpt); oOdd = idxOpt; idxOpt = idxOpt+1;
    fprintf('    %d) 짝수 (2,4,6,...)\n', idxOpt); oEven = idxOpt; idxOpt = idxOpt+1;
    fprintf('    %d) 전체 (1:%d)\n', idxOpt, maxCh); oAll = idxOpt; idxOpt = idxOpt+1;
    fprintf('    %d) 직접 입력 (예: 1,3,5,8)\n', idxOpt); oCustom = idxOpt;

    sel = input('    선택: ', 's'); sel = strtrim(sel);
    chs = 1:defN; % default
    if isempty(sel)
        return;
    end
    % 해석
    try
        v = str2double(sel);
        if ~isnan(v)
            vv = round(v);
        else
            vv = NaN;
        end
        % 동적 옵션 번호 재계산
        next = 2; opt_916 = NaN; if maxCh>=16, opt_916 = next; next=next+1; end
        opt_14 = next; next=next+1;
        opt_58 = NaN; if maxCh>=8, opt_58 = next; next=next+1; end
        opt_odd = next; next=next+1;
        opt_even = next; next=next+1;
        opt_all = next; next=next+1;
        opt_custom = next;

        if ~isnan(vv)
            if vv==opt_916
                chs = 9:min(16,maxCh);
                return;
            elseif vv==opt_14
                chs = 1:min(4,maxCh);
                return;
            elseif ~isnan(opt_58) && vv==opt_58
                chs = 5:min(8,maxCh);
                return;
            elseif vv==opt_odd
                chs = 1:2:maxCh;
                return;
            elseif vv==opt_even
                chs = 2:2:maxCh;
                return;
            elseif vv==opt_all
                chs = 1:maxCh;
                return;
            elseif vv==opt_custom
                % fall through to custom prompt below
            else
                % 알 수 없는 번호 -> 시도해볼 수: 바로 범위표현 입력
                tmp = eval(['[', sel, ']']); %#ok<EVLDIR>
                if isnumeric(tmp) && ~isempty(tmp)
                    chs = sanitize_channels(tmp, maxCh);
                    return;
                end
            end
        else
            % 숫자가 아니면 범위표현 시도
            tmp = eval(['[', sel, ']']); %#ok<EVLDIR>
            if isnumeric(tmp) && ~isempty(tmp)
                chs = sanitize_channels(tmp, maxCh);
                return;
            end
        end
    catch
        % 계속해서 custom 입력으로 처리
    end

    raw = input('    채널 직접 입력 (쉼표/공백): ', 's');
    parts = regexp(strtrim(raw), '[,\s]+', 'split');
    vals = str2double(parts);
    vals = vals(~isnan(vals));
    if ~isempty(vals)
        chs = sanitize_channels(vals, maxCh);
    end
end

function chs = sanitize_channels(v, maxCh)
% 유효 채널로 정리
    v = unique(v(:)');
    v = v(v>=1 & v<=maxCh);
    v = round(v);
    if isempty(v)
        chs = 1:min(8,maxCh);
    else
        chs = v;
    end
end

%% 데이터 경로 선택 (expdata 자동 탐색, 최신 수정 폴더를 기본값으로 제시)
% 이전 선택(dataDir)이 존재하면 Enter로 유지할 수 있게 함
dataDirChosen = false;
if exist('dataDir','var') && ~isempty(dataDir) && isfolder(dataDir)
    try
        fprintf('현재 데이터 폴더: %s\n', char(dataDir));
    catch
    end
    resp = input('데이터 폴더를 유지할까요? [Enter=유지 / n=변경]: ', 's');
    if isempty(resp) || any(lower(resp(1)) ~= 'n')
        dataDirChosen = true;
        dataDir = char(dataDir);
    end
end
if ~dataDirChosen
    dataDir = '';
end
% 데이터 루트 후보: 현재 작업 디렉터리/스크립트 디렉터리의 expdata, 그리고 Google Drive 경로
candRoots = string.empty(1,0);
tryRoot1 = fullfile(pwd, 'expdata');
if isfolder(tryRoot1), candRoots(end+1) = string(tryRoot1); end %#ok<AGROW>
try
    if exist('here','var') && ~isempty(here)
        tryRoot2 = fullfile(here, 'expdata');
        if isfolder(tryRoot2), candRoots(end+1) = string(tryRoot2); end %#ok<AGROW>
    end
end
% Google Drive 루트는 자동 후보에서 제외 (명시 dataDir 전달 시만 사용)
% 중복 제거
if ~isempty(candRoots)
    [~, iu] = unique(candRoots);
    candRoots = candRoots(sort(iu));
end

cands = string.empty(1,0);
candTimes = [];
for r = candRoots
    d1 = dir(fullfile(char(r),'*'));
    for k = 1:numel(d1)
        if d1(k).isdir && ~startsWith(d1(k).name, '.')
            p = fullfile(char(r), d1(k).name);
            s2pList = [dir(fullfile(p, '*.s2p')); dir(fullfile(p, 'sParam', '*.s2p'))];
            if ~isempty(s2pList)
                % 중복 후보 제거
                if ~any(cands == string(p))
                    cands(end+1) = string(p); %#ok<AGROW>
                    candTimes(end+1) = max([s2pList.datenum]); %#ok<AGROW>
                end
            end
        end
    end
end
if ~dataDirChosen
    if numel(cands) == 0
        tmp = uigetdir(pwd, '데이터 루트 폴더 선택');
        if isequal(tmp, 0), error('폴더가 선택되지 않았습니다.'); end
        dataDir = tmp;
    elseif numel(cands) == 1
        dataDir = char(cands);
        fprintf('자동 감지된 데이터 폴더: %s\n', dataDir);
    else
        % 최신 수정 폴더를 기본 선택으로 안내
        [~, defIdx] = max(candTimes);
        fprintf('여러 후보 폴더가 감지되었습니다. 번호를 선택하세요 (Enter=%d):\n', defIdx);
        for i = 1:numel(cands)
            tag = ''; if i==defIdx, tag=' (기본)'; end
            try
                [~, baseName] = fileparts(char(cands(i)));
            catch
                baseName = cands(i);
            end
            fprintf('  [%d] %s%s\n', i, baseName, tag);
        end
        idx = input('번호 입력 (Enter=기본 선택): ');
        if isempty(idx)
            idx = defIdx;
        end
        if ~isscalar(idx) || idx < 1 || idx > numel(cands)
            error('유효하지 않은 선택입니다.');
        end
        dataDir = char(cands(idx));
    end
end

%% 기본 옵션 질의 (콘솔 프롬프트)
s = input('S12/S21 전송 항 플롯 포함? [y/N]: ', 's');
is_transmit_plot = ~isempty(s) && any(lower(s(1)) == 'y'); % S12,21 plot 유무

% 스무딩은 기본 미사용
use_smoothing = false;
smoothing_window_size = 0;

%% 노이즈 제거 필터 설정
% use_smoothing: true로 설정하면 노이즈 제거 필터를 적용한 추가 그래프를 생성합니다.
% smoothing_window_size: 이동 평균 필터의 윈도우 크기. 클수록 더 부드러워집니다.
use_smoothing = false; 
smoothing_window_size = 7;

%% S-parameter 데이터 하위 폴더 설정
% 대체 S-parameter 데이터 하위 폴더명 설정 (dataDir에 없을 때 dataDir의 하위 폴더에서 찾음)
fallback_sparam_subfolder = 'sParam';  % dataDir의 하위 폴더명만 입력

% S-parameter 데이터가 있는 실제 경로 결정
sparam_data_dir = dataDir;  % 기본값
if exist('fallback_sparam_subfolder', 'var') && ~isempty(fallback_sparam_subfolder)
    subfolder_path = fullfile(dataDir, fallback_sparam_subfolder);
    s2p_files_in_subfolder = dir(fullfile(subfolder_path, '*.s2p'));
    s2p_files_in_datadir = dir(fullfile(dataDir, '*.s2p'));
    
    if ~isempty(s2p_files_in_subfolder)
        sparam_data_dir = subfolder_path;  % 하위 폴더 사용
        fprintf('S-parameter 데이터 경로: %s (하위 폴더)\n', sparam_data_dir);
    elseif ~isempty(s2p_files_in_datadir)
        sparam_data_dir = dataDir;  % dataDir 사용
        fprintf('S-parameter 데이터 경로: %s (메인 폴더)\n', sparam_data_dir);
    else
        fprintf('경고: .s2p 파일을 찾을 수 없습니다.\n');
    end
end

%% S-parameter 데이터 캐시 사용/업데이트 결정
% 기본: 기존 MAT 캐시가 있으면 그대로 사용, 없으면 생성
% 외부에서 refresh_sparam_cache=true 로 설정하면 강제 재생성
if ~exist('refresh_sparam_cache','var')
    refresh_sparam_cache = false; %#ok<NASGU>
end

[need_regen_auto, has_cache, reason] = needsSparamCacheRebuild(sparam_data_dir);
need_regen = refresh_sparam_cache || need_regen_auto;

if need_regen
    if refresh_sparam_cache
        fprintf('요청에 의해 S-parameter 캐시를 재생성합니다...\n');
    else
        switch string(reason)
            case "no_cache"
                fprintf('기존 캐시가 없어 S-parameter 캐시를 생성합니다...\n');
            case "no_list_in_cache"
                fprintf('S-parameter 캐시에 파일 목록 정보 없음 — 재생성합니다...\n');
            case "list_mismatch"
                fprintf('S-parameter 캐시와 s2p 목록 불일치 — 재생성합니다...\n');
            case "s2p_newer"
                fprintf('s2p 최신 수정 시간이 캐시보다 최신 — 재생성합니다...\n');
            otherwise
                if has_cache
                    fprintf('S-parameter 캐시가 최신이 아님 — 재생성합니다...\n');
                else
                    fprintf('기존 캐시가 없어 S-parameter 캐시를 생성합니다...\n');
                end
        end
    end
    try
        cachespara(sparam_data_dir); % 캐시 생성/갱신
        fprintf('캐시 파일 생성/업데이트가 완료되었습니다.\n');
    catch ME
        fprintf('cachespara.m 실행 중 오류가 발생했습니다: %s\n', ME.message);
        fprintf('업데이트를 건너뛰고 기존 데이터로 플로팅을 시도합니다.\n');
    end
else
    fprintf('기존 S-parameter 캐시를 사용합니다. (재생성 안 함)\n');
end



%% S-parameter 데이터 로드
% 캐시를 생성한 동일한 경로에서 로드
sparam_file_single = fullfile(sparam_data_dir, 'sparam_data.mat');
sparam_loaded = false;

% 청크 파일 탐색
chunk_files_struct = dir(fullfile(sparam_data_dir, 'sparam_data_part*.mat'));
[~, order] = sort({chunk_files_struct.name});
chunk_files_struct = chunk_files_struct(order);

% 안전장치: 단일/청크 캐시가 동시에 존재하면 최신 타임스탬프를 우선하여 선택
if ~isempty(chunk_files_struct) && exist(sparam_file_single, 'file')
    try
        latest_chunk_time = max([chunk_files_struct.datenum]);
    catch
        latest_chunk_time = -inf;
    end
    try
        single_info = dir(sparam_file_single);
        single_time = single_info.datenum;
    catch
        single_time = -inf;
    end
    if single_time >= latest_chunk_time
        fprintf('경고: 단일/청크 캐시가 모두 존재합니다. 더 최신인 단일 캐시를 사용합니다.\n');
        chunk_files_struct = [];
    else
        fprintf('경고: 단일/청크 캐시가 모두 존재합니다. 더 최신인 청크 캐시를 사용합니다.\n');
    end
end

if ~isempty(chunk_files_struct)
    fprintf('청크 S-parameter 데이터 파일 %d개를 감지했습니다. 병합 로드합니다.\n', numel(chunk_files_struct));
    combined = struct();
    filenames_all = strings(1,0);
    for i = 1:numel(chunk_files_struct)
        fpath = fullfile(chunk_files_struct(i).folder, chunk_files_struct(i).name);
        fprintf('  로드: %s\n', fpath);
        tmp = load(fpath);
        if ~isfield(tmp, 'data') || ~isfield(tmp.data, 'Timestamps')
            fprintf('  경고: 잘못된 청크 파일(필드 누락) 건너뜀: %s\n', fpath);
            continue;
        end
        d = tmp.data;
        if ~isfield(combined, 'Frequencies')
            combined = d;
        else
            % 주파수 그리드 일치 확인
            if ~isequal(combined.Frequencies, d.Frequencies)
                fprintf('  경고: 주파수 그리드가 일치하지 않습니다. 이 청크를 건너뜁니다: %s\n', fpath);
                continue;
            end
            combined.S11_dB   = [combined.S11_dB,   d.S11_dB];
            combined.S11_phase= [combined.S11_phase,d.S11_phase];
            combined.S21_dB   = [combined.S21_dB,   d.S21_dB];
            combined.S21_phase= [combined.S21_phase,d.S21_phase];
            combined.S12_dB   = [combined.S12_dB,   d.S12_dB];
            combined.S12_phase= [combined.S12_phase,d.S12_phase];
            combined.S22_dB   = [combined.S22_dB,   d.S22_dB];
            combined.S22_phase= [combined.S22_phase,d.S22_phase];
            combined.Timestamps = [combined.Timestamps, d.Timestamps];
        end
        if isfield(tmp, 'processed_filenames')
            filenames_all = [filenames_all, string(tmp.processed_filenames)]; %#ok<AGROW>
        end
    end

    if isfield(combined, 'Timestamps') && ~isempty(combined.Timestamps)
        % 전역 정렬
        [combined.Timestamps, sidx] = sort(combined.Timestamps);
        combined.S11_dB    = combined.S11_dB(:, sidx);
        combined.S11_phase = combined.S11_phase(:, sidx);
        combined.S21_dB    = combined.S21_dB(:, sidx);
        combined.S21_phase = combined.S21_phase(:, sidx);
        combined.S12_dB    = combined.S12_dB(:, sidx);
        combined.S12_phase = combined.S12_phase(:, sidx);
        combined.S22_dB    = combined.S22_dB(:, sidx);
        combined.S22_phase = combined.S22_phase(:, sidx);
        combined.TimeElapsed = combined.Timestamps - min(combined.Timestamps);
        sparam_data.data = combined;
        if ~isempty(filenames_all)
            sparam_data.processed_filenames = filenames_all;
        end
        sparam_loaded = true;
        abs_start_time = min(combined.Timestamps);
        fprintf('청크 데이터 병합 완료 (총 %d 샷).\n', numel(combined.Timestamps));
    else
        fprintf('경고: 청크 파일에서 유효한 데이터를 로드하지 못했습니다.\n');
    end
end

% 단일 파일 로드 (청크가 없을 때만)
if ~sparam_loaded && exist(sparam_file_single, 'file')
    fprintf('S-parameter 데이터 파일 로드: %s\n', sparam_file_single);
    sparam_data = load(sparam_file_single);
    if isfield(sparam_data, 'data') && isfield(sparam_data.data, 'Timestamps') && ~isempty(sparam_data.data.Timestamps)
        sparam_loaded = true;
        abs_start_time = min(sparam_data.data.Timestamps);
    else
        fprintf('S-parameter 데이터 파일이 유효하지 않습니다 (data 또는 Timestamps 필드 누락).\n');
    end
elseif ~sparam_loaded
    fprintf('S-parameter 데이터 파일을 찾을 수 없습니다. (단일/청크 모두 없음)\n');
end

%% 모니터링할 주파수 설정 (GHz)
% frequencies_to_plot_GHz = 9.6:0.02:9.66; % 사용자가 원하는 주파수로 변경 가능
% 외부에서 미리 설정되었으면 그대로 사용하고, 아니면 기본값을 설정합니다.
if ~exist('frequencies_to_plot_GHz','var') || isempty(frequencies_to_plot_GHz)
    frequencies_to_plot_GHz = 24:0.1:24.5;
end

% 주파수 포인트 선택(콘솔): Enter 누르면 기본/외부 설정 유지
try
    fprintf('\n주파수 포인트 선택 옵션:\n');
    fprintf('  [Enter] 그대로 사용 (현재: ');
    try
        if isscalar(frequencies_to_plot_GHz)
            fprintf('%.3f GHz', frequencies_to_plot_GHz);
        elseif numel(frequencies_to_plot_GHz) <= 8
            fprintf('%s', strjoin(string(round(frequencies_to_plot_GHz,3)), ', '));
        else
            fprintf('%.3f ... %.3f GHz (N=%d)', frequencies_to_plot_GHz(1), frequencies_to_plot_GHz(end), numel(frequencies_to_plot_GHz));
        end
    catch
    end
    fprintf(')\n');
    fprintf('  1) 단일 포인트 입력 (예: 24)\n');
    fprintf('  2) 범위+간격 입력 (예: 24:0.1:24.5)\n');
    fprintf('  3) 여러 포인트 수동 입력 (예: 23.9, 24.0, 24.25)\n');
    s = input('주파수 선택 (Enter=유지): ', 's');
    if ~isempty(s)
        s = strtrim(s);
        switch s
            case '1'
                v = input('GHz 값을 입력하세요 (예: 24): ');
                if isnumeric(v) && ~isempty(v)
                    frequencies_to_plot_GHz = v(:).';
                end
            case '2'
                r = input('start:step:end 형식으로 입력 (예: 24:0.1:24.5): ', 's');
                if ~isempty(r)
                    try
                        frequencies_to_plot_GHz = eval(['[', r, ']']); %#ok<EVLDIR>
                        frequencies_to_plot_GHz = frequencies_to_plot_GHz(:).';
                    catch
                        fprintf('형식을 해석할 수 없습니다. 기존 설정을 유지합니다.\n');
                    end
                end
            case '3'
                l = input('쉼표/공백 구분 리스트 (예: 23.9,24.0,24.25): ', 's');
                if ~isempty(l)
                    parts = regexp(l, '[,\s]+', 'split');
                    vv = str2double(parts);
                    vv = vv(~isnan(vv));
                    if ~isempty(vv)
                        frequencies_to_plot_GHz = vv(:).';
                    else
                        fprintf('유효한 숫자를 찾지 못했습니다. 기존 설정을 유지합니다.\n');
                    end
                end
            otherwise
                % 사용자가 바로 범위표현을 넣는 경우 지원 (예: 24:0.1:24.5)
                try
                    tmp = eval(['[', s, ']']); %#ok<EVLDIR>
                    if isnumeric(tmp) && ~isempty(tmp)
                        frequencies_to_plot_GHz = tmp(:).';
                    end
                catch
                    % 무시
                end
        end
    end
catch ME
    fprintf('주파수 선택 입력을 건너뜁니다: %s\n', ME.message);
end
%% 온도 채널 및 플롯 색상 기본 설정
% 기본은 양 포트 동일 채널, 1:8
channelGroups = {1:8, 1:8};
temp_plot_colors = {
    {'#D95319', '#16B8F1', '#EDB120', 'g', 'm', 'c', '#7E2F8E', 'r'}, ...
    {'#D95319', '#16B8F1', '#EDB120', 'g', 'm', 'c', '#7E2F8E', 'r'}  ...
};




%% X축 시간 표시 설정 및 기준시간 설정
use_elapsed_time_axis = false; % true로 설정하면 경과 시간(단위: 시간)으로 X축 표시
custom_start_time_str = '2025-08-13 22:00:00'; % 또는 '2025-06-05 10:00:00'  비워두면 데이터의 첫 번째 시간을 자동으로 사용합니다.


%% X축 플롯 범위 설정 (경과 시간 기준, 단위: 시간)
% 비워두면 [] 전체 데이터 범위를 자동으로 플롯합니다.
% 예: [2, 5] -> 2시간부터 5시간까지 플롯
% 예: [3] -> 3시간부터 끝까지 플롯
plot_time_range_hours = [0 5];

%% X축 플롯 범위 설정 (절대 시간 기준)
% use_elapsed_time_axis가 false일 때 사용됩니다.
% 비워두면 [] 전체 데이터 범위를 자동으로 플롯합니다.
% 예: {'2025-04-01 14:00:00', '2025-04-01 16:00:00'} -> 해당 시간 사이를 플롯
% 예: {'2025-04-01 14:00:00'} -> 14시부터 끝까지 플롯
plot_time_range_datetime = {}; % 'yyyy-MM-dd HH:mm:ss' 형식

%% 수동으로 날짜를 표시할 위치 설정
% use_elapsed_time_axis가 false일 때 적용됩니다.
% 비워두면 {} 날짜가 바뀔 때마다 자동으로 날짜를 표시합니다.
% 'yyyy-MM-dd HH:mm:ss' 형식의 문자열 셀 배열로 지정합니다.
% 예: {'2025-06-13 18:00:00', '2025-06-14 06:00:00'}
manual_datetick_locations = {};

%% 온도 데이터 시간 오프셋 설정 (단위: 초)
% S-parameter와 온도계 시간의 동기화가 맞지 않을 경우, 이 값을 조절하여 보정합니다.
% 예: 온도 데이터가 5분(300초) 늦게 기록된 경우, -300을 입력하여 시간을 앞으로 당깁니다.
temp_time_offset_seconds = 0;

%% 온도 채널별 보정값 설정 (단위: °C)
% 각 온도 채널에 더할 보정값을 배열로 지정합니다. 채널 순서대로 입력합니다.
% 예: 16채널일 경우 [0, 0, -0.5, 0, ... ] -> 3번 채널만 -0.5도 보정
% temp_channel_offsets = [0.967100000000000	0.914200000000000	0.944400000000000	0.799800000000000	0.843500000000000	0.865400000000000	0.810700000000000	0.925400000000000	1.19980000000000	1.27030000000000	1.06450000000000	1.09930000000000	1.01680000000000	0.877000000000000	0.976900000000000	0.884200000000000];
temp_channel_offsets = zeros(1,16);
temp_y_lim = 'auto';
sparam_y_lim = 'auto';
sparam_S21_S12_y_lim = 'auto'; % S21, S12 y-lim
%% 온도 데이터 로드 (CSV)
% Strictly load Temp.csv in the selected dataDir. Ignore backups like
% Temp.before_append*.csv or any other CSVs.
temp_csv_path = fullfile(dataDir, 'Temp.csv');
fileList = [];
if isfile(temp_csv_path)
    d = dir(temp_csv_path); fileList = d; %#ok<NASGU>
else
    % Fallback: search exact-name Temp.csv within dataDir (non-recursive)
    dd = dir(fullfile(dataDir, 'Temp.csv'));
    if ~isempty(dd), fileList = dd(1); end
end
temp_data_loaded = false;
fileName = 'N/A'; % 기본 파일 이름
data = [];
time_relative = []; % 온도 데이터의 시간 축 데이터

if isempty(fileList)
    fprintf('온도 데이터 csv가 없습니다.\n');
else
    % Use only the exact Temp.csv in dataDir
    fileName = 'Temp.csv';
    filePath = temp_csv_path;
    fprintf('온도 데이터 파일 로드: %s\n', filePath);

    try
        % CSV 파서 강제 설정: 쉼표 구분, 텍스트 유지
        opts = detectImportOptions(filePath, 'Delimiter', ',', 'TextType', 'string');
        % 불완전한 행/여분 컬럼이 있어도 무시
        try, opts.ExtraColumnsRule = 'ignore'; catch, end
        try, opts.EmptyLineRule = 'read'; catch, end
        % Time 열이 있으면 유지, 없으면 첫 열을 dtime으로 취급
        if ~ismember('Time', opts.VariableNames)
            try
                opts.VariableNames{1} = 'dtime';
            catch
            end
        end
        % 시간열은 문자로 읽고 이후 파싱
        if ismember('Time', opts.VariableNames)
            opts = setvartype(opts, 'Time', 'char');
            opts = setvaropts(opts, 'Time', 'WhitespaceRule', 'preserve', 'EmptyFieldRule', 'auto');
        elseif ismember('dtime', opts.VariableNames)
            opts = setvartype(opts, 'dtime', 'char');
            opts = setvaropts(opts, 'dtime', 'WhitespaceRule', 'preserve', 'EmptyLineRule', 'read');
        end
        % 필요한 컬럼만 선택 (Time + Ch1..Ch16)
        wanted = [{'Time'} arrayfun(@(k) sprintf('Ch%d',k), 1:16, 'UniformOutput', false)];
        present = intersect(wanted, opts.VariableNames, 'stable');
        if ~isempty(present)
            try, opts.SelectedVariableNames = present; catch, end
        end
        dataTable = readtable(filePath, opts);
        varNames = dataTable.Properties.VariableNames;

        if ismember('Date', varNames) && ismember('Time', varNames)
            fprintf('Date와 Time 열을 감지했습니다. datetime으로 결합합니다.\n');
            % 문자열 결합 후 한글 AM/PM 포함 포맷 우선 시도
            try
                dateStr = string(dataTable.Date);
                timeStr = string(dataTable.Time);
                combined = strtrim(dateStr + " " + timeStr);
                combined = replace(combined, char(160), ' '); % NBSP 제거
                combined = replace(combined, char(9), ' ');    % 탭 제거
                combined = regexprep(combined, "\\s+", " ");
                parsed = NaT(size(combined));
                try, parsed = datetime(combined, 'InputFormat','yyyy-MM-dd HH:mm:ss'); catch, end
                try, bad = isnat(parsed); parsed(bad) = datetime(combined(bad), 'InputFormat','yyyy-MM-dd a hh:mm:ss', 'Locale','ko_KR'); catch, end
                try, bad = isnat(parsed); parsed(bad) = datetime(combined(bad), 'InputFormat','yyyy-MM-dd hh:mm:ss a', 'Locale','en_US'); catch, end
                time_relative = parsed;
            catch
                % 실패 시 ISO 포맷으로 폴백
                try
                    datePart = datetime(dataTable.Date, 'InputFormat', 'yyyy-MM-dd');
                catch
                    datePart = datetime(string(dataTable.Date), 'InputFormat', 'yyyy-MM-dd');
                end
                % 시간 문자열에서 AM/PM(영문/한글) 제거 후 시:분:초만 파싱 시도
                timeStr = regexprep(string(dataTable.Time), '^(AM|PM|오전|오후)\s*', '', 'ignorecase');
                timePart = duration(timeStr, 'InputFormat', 'hh:mm:ss');
            time_relative = datePart + timePart;
            if isdatetime(time_relative)
                time_relative.Format = 'yyyy-MM-dd HH:mm:ss';
            end
            end
            % 온도 데이터는 3번째 열부터.
            data = dataTable{:, 3:end};
            if iscell(data)
                data = cellfun(@str2double, data);
            elseif isstring(data)
                data = str2double(data);
            end
            temp_data_loaded = true;
        elseif ismember('Time', varNames) || ismember('dtime', varNames) || (width(dataTable)==2 && strcmpi(varNames{1},'Var1') && strcmpi(varNames{2},'Var2'))
            % 단일 열 'dtime'에 절대시간이 들어있는 경우 처리 (강제 텍스트로 읽고 수동 파싱)
            if ismember('Time', varNames)
                dcol_raw = dataTable.Time;
            elseif ismember('dtime', varNames)
                dcol_raw = dataTable.dtime;
            else
                % Var1=날짜, Var2='hh:mm:ss, val1, val2, ...' 의 형태 처리
                dayPart = string(dataTable.Var1);
                tail = string(dataTable.Var2);
                % Var2에서 첫 콤마 전까지를 시간 문자열로 추출
                timeStr = extractBefore(tail, ',');
                % 시간 뒤의 값들만 다시 CSV로 읽듯 분할
                valuesStr = extractAfter(tail, ',');
                % 날짜+시간 결합 문자열 생성
                dcol_raw = strtrim(dayPart + " " + timeStr);
                % values 파싱 -> 숫자 행렬
                pieces = split(valuesStr, ',');
                pieces = strtrim(pieces);
                % 컬럼 개수
                maxCols = max(cellfun(@numel, num2cell(pieces,2)));
                % 문자열 배열을 숫자 행렬로 변환
                vals = NaN(height(dataTable), maxCols);
                for r = 1:height(dataTable)
                    row = split(valuesStr(r), ','); row = strtrim(row);
                    vals(r,1:numel(row)) = str2double(row)';
                end
                % dataTable을 대체하는 data 행렬 준비
                data = vals;
            end

            if isdatetime(dcol_raw)
                time_relative = dcol_raw;
            elseif isnumeric(dcol_raw)
                % 숫자이면 엑셀 직렬 날짜일 수 있음
                try
                    time_relative = datetime(dcol_raw, 'ConvertFrom','excel');
                catch
                    time_relative = datetime(dcol_raw, 'ConvertFrom','datenum');
                end
            else
                dstr = string(dcol_raw);
                % 여러 포맷 시도 (초 포함)
                fmts = [ ...
                    "yyyy-MM-dd HH:mm:ss"; 
                    "yyyy/MM/dd HH:mm:ss"; 
                    "yyyy-MM-dd a hh:mm:ss"; 
                    "yyyy/MM/dd a hh:mm:ss" 
                ];
                parsed = NaT(size(dstr));
                for fi = 1:numel(fmts)
                    try
                        if contains(fmts(fi), 'a')
                            parsed_try = datetime(dstr, 'InputFormat', fmts(fi), 'Locale','ko_KR');
                        else
                            parsed_try = datetime(dstr, 'InputFormat', fmts(fi));
                        end
                        bad = isnat(parsed) & ~isnat(parsed_try);
                        parsed(bad) = parsed_try(bad);
                    catch
                        % continue trying
                    end
                end
                % 최후의 수단: 자동 파싱
                if any(isnat(parsed))
                    try
                        parsed(isnat(parsed)) = datetime(dstr(isnat(parsed)), 'Locale','ko_KR');
                    catch
                    end
                end
                time_relative = parsed;
            end

            if isdatetime(time_relative)
                time_relative.Format = 'yyyy-MM-dd HH:mm:ss';
            end

            if ~exist('data','var') || isempty(data)
                data = dataTable{:, 2:end};
            end
            if iscell(data)
                data = cellfun(@str2double, data);
            elseif isstring(data)
                data = str2double(data);
            end
            temp_data_loaded = true;
        else
            % 기존 로직 개선: 첫 번째 열이 문자열 datetime(한글 AM/PM 포함)일 수 있음
            varNames2 = dataTable.Properties.VariableNames;
            firstCol = dataTable.(varNames2{1});
            if iscell(firstCol) || isstring(firstCol)
                firstStr = string(firstCol);
                try
                    % 한글 AM/PM 포함 포맷 우선
                    time_relative = datetime(firstStr, 'InputFormat', 'yyyy-MM-dd a hh:mm:ss', 'Locale', 'ko_KR');
                catch
                    % 다양한 구분자 폴백 시도
                    try
                        time_relative = datetime(firstStr, 'InputFormat', 'yyyy/MM/dd a hh:mm:ss', 'Locale', 'ko_KR');
                    catch
                        % 최후의 수단: 자동 파싱
                        time_relative = datetime(firstStr, 'Locale', 'ko_KR');
                    end
                end
            else
                time_relative = firstCol;
            end
            if isdatetime(time_relative)
                time_relative.Format = 'yyyy-MM-dd HH:mm:ss';
            end
            data = dataTable{:, 2:end};
            if iscell(data)
                data = cellfun(@str2double, data);
            elseif isstring(data)
                data = str2double(data);
            end
            temp_data_loaded = true;
        end
    catch ME
        fprintf('readtable으로 파일을 읽는 데 실패했습니다. readmatrix를 시도합니다.\n에러 메시지: %s\n', ME.message);
        try
            dataWithTime = readmatrix(filePath);
            time_relative = dataWithTime(:, 1);
            data = dataWithTime(:, 2:end);
            temp_data_loaded = true;
        catch ME2
            fprintf('readmatrix로도 파일을 읽는 데 실패했습니다.\n에러 메시지: %s\n', ME2.message);
            fprintf('온도 데이터 플로팅을 건너뜁니다.\n');
        end
    end
end

% 온도 채널별 보정값 적용
if temp_data_loaded && exist('temp_channel_offsets', 'var') && any(temp_channel_offsets(:) ~= 0)
    fprintf('온도 채널별 보정값을 적용합니다.\n');
    num_channels_data = size(data, 2);
    num_offsets = length(temp_channel_offsets);
    
    offsets_to_apply = temp_channel_offsets;
    
    if num_offsets < num_channels_data
        fprintf('  경고: 보정값 개수(%d)가 채널 수(%d)보다 적어 나머지는 0으로 채웁니다.\n', num_offsets, num_channels_data);
        offsets_to_apply(end+1:num_channels_data) = 0;
    elseif num_offsets > num_channels_data
        fprintf('  경고: 보정값 개수(%d)가 채널 수(%d)보다 많아 앞의 %d개만 사용합니다.\n', num_offsets, num_channels_data, num_channels_data);
        offsets_to_apply = offsets_to_apply(1:num_channels_data);
    end
    
    data = data + reshape(offsets_to_apply, 1, num_channels_data);
end

% 온도 데이터 시간 오프셋 적용
if temp_data_loaded && isdatetime(time_relative) && temp_time_offset_seconds ~= 0
    fprintf('%d초의 시간 오프셋을 온도 데이터에 적용합니다.\n', temp_time_offset_seconds);
    time_relative = time_relative + seconds(temp_time_offset_seconds);
end

%% 온도 채널 선택: 설정 CSV 자동 사용(없으면 프롬프트로 생성)
if temp_data_loaded
    try
        maxCh = size(data, 2);
        allTempLabels = arrayfun(@(k) sprintf('Ch%d',k), 1:maxCh, 'UniformOutput', false);
        cfg_common = fullfile(dataDir, 'TempChannelSelection.csv');
        if isfile(cfg_common)
            channelGroups{1} = resolve_temp_channels_port(allTempLabels, cfg_common, 'P1');
            channelGroups{2} = resolve_temp_channels_port(allTempLabels, cfg_common, 'P2');
            fprintf('단일 CSV에서 포트별 온도 채널 설정을 불러왔습니다.\n');
        elseif isfile(cfg_common)
            chs = resolve_temp_channels(allTempLabels, cfg_common);
            channelGroups = {chs, chs};
            fprintf('공통 온도 채널 설정을 CSV에서 불러왔습니다.\n');
        else
            fprintf('\n온도 채널 선택 모드:\n');
            fprintf('  [Enter] 양 포트 동일 채널 사용 (기본)\n');
            fprintf('  2) 포트별로 다른 채널 선택\n');
            modeSel = input('선택: ', 's');
            modeSel = strtrim(modeSel);
            if isempty(modeSel) || strcmp(modeSel, '1')
                chs = local_select_channel_set(maxCh);
                channelGroups = {chs, chs};
                try
                    T = table(string(allTempLabels(chs))', 'VariableNames', {'Label'});
                    writetable(T, cfg_common);
                    fprintf('공통 온도 채널 설정을 저장했습니다: %s\n', cfg_common);
                catch ME
                    fprintf('온도 채널 설정 저장 실패: %s\n', ME.message);
                end
            else
                fprintf('\n[Port 1] 채널 선택\n');
                ch1 = local_select_channel_set(maxCh);
                fprintf('\n[Port 2] 채널 선택\n');
                ch2 = local_select_channel_set(maxCh);
                channelGroups = {ch1, ch2};
                try
                    T = table();
                    maxLen = max(numel(ch1), numel(ch2));
                    T.Label_P1 = strings(maxLen,1);
                    T.Label_P2 = strings(maxLen,1);
                    lab1 = string(allTempLabels(ch1))';
                    lab2 = string(allTempLabels(ch2))';
                    T.Label_P1(1:numel(lab1)) = lab1;
                    T.Label_P2(1:numel(lab2)) = lab2;
                    writetable(T, cfg_common);
                    fprintf('포트별 온도 채널 설정을 단일 CSV로 저장했습니다: %s\n', cfg_common);
                catch ME
                    fprintf('온도 채널 설정 저장 실패: %s\n', ME.message);
                end
            end
        end

        % 색상 리스트 보정: 부족하면 lines()로 보충
        temp_plot_colors = cell(1,2);
        for pi = 1:2
            n = numel(channelGroups{pi});
            base = {'#D95319', '#16B8F1', '#EDB120', 'g', 'm', 'c', '#7E2F8E', 'r'};
            cols = base;
            if n > numel(base)
                extra = lines(n - numel(base));
                for ii = 1:size(extra,1)
                    cols{end+1} = extra(ii,:); %#ok<AGROW>
                end
            end
            temp_plot_colors{pi} = cols;
        end
    catch ME
        fprintf('채널 선택/설정 로드 단계에서 오류: %s\n', ME.message);
    end
end

%% 시간 축 데이터 설정
if ~sparam_loaded && ~temp_data_loaded
    error('플롯할 데이터가 없습니다. S-parameter 또는 온도 데이터 파일이 필요합니다.');
end

is_datetime_axis = (sparam_loaded && isdatetime(sparam_data.data.Timestamps)) || ... % S-parameter 데이터가 datetime 형식인지 확인
                   (temp_data_loaded && isdatetime(time_relative)); % 온도 데이터가 datetime 형식인지 확인

% 하나의 축 타입만 사용: datetime이 가능하면 모든 축을 datetime으로 통일
if is_datetime_axis
    use_elapsed_time_axis = false; % duration(경과시간) 모드는 비활성화
end

time_axis_label = 'Time'; % Default label

if use_elapsed_time_axis && is_datetime_axis
    % Determine start time
    start_time = [];
    if ~isempty(custom_start_time_str)
        try
            start_time = datetime(custom_start_time_str, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
        catch ME
            fprintf('사용자 지정 시작 시간 형식이 잘못되었습니다. 첫 데이터 시간을 사용합니다. 오류: %s\n', ME.message);
            % Fallback to auto-detection by leaving start_time empty
        end
    end

    if isempty(start_time)
        if sparam_loaded
            start_time = sparam_data.data.Timestamps(1);
        else % temp_data_loaded must be true
            start_time = time_relative(1);
        end
    end

    fprintf('X축 시작 시간 기준: %s\n', datestr(start_time, 'yyyy-mm-dd HH:MM:SS'));

    % Calculate elapsed time for all relevant time vectors
    if sparam_loaded
        sparam_time_axis = hours(sparam_data.data.Timestamps - start_time);
    end
    if temp_data_loaded
        if isdatetime(time_relative)
            temp_time_axis = hours(time_relative - start_time);
        else
            % Temp data time is already relative, can't convert. Use as is.
            temp_time_axis = time_relative;
            time_axis_label = 'Time (Relative)';
            use_elapsed_time_axis = false; % Override, can't use elapsed time
            fprintf('온도 데이터의 시간 축이 datetime이 아니므로 경과 시간 표시를 비활성화합니다.\n');
        end
    end

    if use_elapsed_time_axis
         time_axis_label = 'Time (hours)';
    end

else % Not using elapsed time or not datetime axis
    if sparam_loaded
        sparam_time_axis = sparam_data.data.Timestamps;
    end
    if temp_data_loaded
        temp_time_axis = time_relative;
        if ~isdatetime(time_relative)
             time_axis_label = 'Time (Relative)';
        end
    end
end

% Plotting 시 사용할 x축 데이터 설정
% 온도 데이터가 있으면 온도 시간축을 우선 사용, 없으면 S-param 시간축 사용
if temp_data_loaded
    plot_time_axis = temp_time_axis;
else
    plot_time_axis = sparam_time_axis;
end

% 전체 플롯 데이터의 최대 시간 계산
plot_max_time = [];
if use_elapsed_time_axis
    max_times = [];
    if sparam_loaded && exist('sparam_time_axis', 'var') && ~isempty(sparam_time_axis)
        max_times(end+1) = max(sparam_time_axis);
    end
    if temp_data_loaded && exist('temp_time_axis', 'var') && ~isempty(temp_time_axis) && isdatetime(time_relative)
        % temp_time_axis가 경과시간으로 변환된 경우에만 포함
        max_times(end+1) = max(temp_time_axis);
    end
    
    if ~isempty(max_times)
        plot_max_time = max(max_times);
    end
end

% 전체 플롯 데이터의 최대 datetime 계산
plot_max_datetime = [];
if is_datetime_axis
    max_datetimes = [];
    if sparam_loaded && isdatetime(sparam_data.data.Timestamps) && ~isempty(sparam_data.data.Timestamps)
        max_datetimes = [max_datetimes, max(sparam_data.data.Timestamps)];
    end
    if temp_data_loaded && isdatetime(time_relative) && ~isempty(time_relative)
        max_datetimes = [max_datetimes, max(time_relative)];
    end

    if ~isempty(max_datetimes)
        plot_max_datetime = max(max_datetimes);
    end
end


%% S-parameter 데이터 스무딩 (노이즈 제거)
if sparam_loaded && use_smoothing
    fprintf('S-parameter 데이터에 이동 평균 필터를 적용합니다 (윈도우 크기: %d)\n', smoothing_window_size);
    sparam_data_smoothed = sparam_data; % 원본 데이터 구조 복사
    
    fields_to_smooth = {'S11_dB', 'S22_dB', 'S11_phase', 'S22_phase', ...
                        'S21_dB', 'S12_dB', 'S21_phase', 'S12_phase'};
    
    for i = 1:length(fields_to_smooth)
        field = fields_to_smooth{i};
        if isfield(sparam_data_smoothed.data, field)
            % smoothdata는 2번째 차원(시간)을 따라 각 주파수에 대해 이동 평균을 적용합니다.
            sparam_data_smoothed.data.(field) = smoothdata(sparam_data.data.(field), 2, 'movmean', smoothing_window_size);
        end
    end
end

%% 각 포트별 크기/위상 그래프 그리기
[~, plot_title_dir] = fileparts(dataDir); % for plot title

% 디버그 출력
fprintf('\n=== 플롯 시작 ===\n');
fprintf('sparam_loaded: %d\n', sparam_loaded);
fprintf('temp_data_loaded: %d\n', temp_data_loaded);
if sparam_loaded
    fprintf('sparam_time_axis 크기: %d\n', length(sparam_time_axis));
    if isfield(sparam_data.data, 'S11_dB')
        fprintf('S11_dB 크기: [%d, %d]\n', size(sparam_data.data.S11_dB));
    else
        fprintf('경고: S11_dB 필드가 없습니다!\n');
    end
end
if temp_data_loaded
    fprintf('plot_time_axis 크기: %d\n', length(plot_time_axis));
end

port_params = {'S11', 'S22'};
port_data_magnitude = {'S11_dB', 'S22_dB'};
port_data_phase = {'S11_phase', 'S22_phase'};

% 통합된 Figure 생성
fig1 = figure('Name', 'S-parameter Magnitude & Phase', ...
       'NumberTitle', 'off', 'Position', [100, 100, 1200, 900]);

% tiledlayout 사용으로 정확한 정렬 (figure 핸들 명시)
t = tiledlayout(fig1, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
title(t, ['S-parameter Data from ' strrep(plot_title_dir, '_', '\_')], 'FontSize', 14);

% x축 링크를 위한 축 핸들 수집
ax_temp_list = [];
ax_mag_list = [];
ax_phase_list = [];

for port_idx = 1:2
    current_port = port_params{port_idx};
    
    channelsToPlot = channelGroups{port_idx};
    current_temp_colors = temp_plot_colors{port_idx};

    % --- Top row: Temperature (separate) ---
    ax_temp_list(port_idx) = nexttile(t, port_idx);
    temp_plots_top = [];
    temp_legends_top = {};
    if temp_data_loaded
        hold on;
        num_channels_to_plot = length(channelsToPlot);
        num_predefined_colors = length(current_temp_colors);
        all_temp_colors = current_temp_colors;
        if num_channels_to_plot > num_predefined_colors
            additional_colors = lines(num_channels_to_plot - num_predefined_colors);
            for i = 1:(num_channels_to_plot - num_predefined_colors)
                all_temp_colors{num_predefined_colors + i} = additional_colors(i, :);
            end
        end
        for j = 1:length(channelsToPlot)
            channelIndex = channelsToPlot(j);
            if channelIndex <= size(data, 2)
                 x = plot_time_axis; y = data(:, channelIndex);
                 if iscell(y)
                     y = cellfun(@str2double, y);
                 elseif isstring(y)
                     y = str2double(y);
                 elseif iscategorical(y)
                     y = double(y);
                 end
                 common_len = min(numel(x), numel(y));
                 x = x(1:common_len); y = y(1:common_len);
                 col = all_temp_colors{j};
                 if isstring(col) || ischar(col)
                     cs = char(col);
                     if ~isempty(cs) && cs(1) == '#' && numel(cs) >= 7
                         col = [hex2dec(cs(2:3)) hex2dec(cs(4:5)) hex2dec(cs(6:7))]/255;
                     elseif numel(cs) == 1
                         switch cs
                             case 'r', col = [1 0 0];
                             case 'g', col = [0 1 0];
                             case 'b', col = [0 0 1];
                             case 'c', col = [0 1 1];
                             case 'm', col = [1 0 1];
                             case 'y', col = [1 1 0];
                             case 'k', col = [0 0 0];
                             case 'w', col = [1 1 1];
                             otherwise, col = [0 0 0];
                         end
                     else
                         col = [0 0 0];
                     end
                 end
                 p = plot(x, y, 'LineStyle', '-', 'Color', col, 'Marker','none','LineWidth', 1.5);
                 temp_plots_top = [temp_plots_top, p];
                 temp_legends_top{end+1} = ['Ch ' num2str(channelIndex)];
             end
        end
        hold off;
        ylabel('Temperature (°C)');
        ylim(temp_y_lim);
        if ~isempty(temp_plots_top)
            legend(temp_plots_top, temp_legends_top, 'Location', 'best');
        end
    end
    title([current_port ' Temperature']);
    xlabel(time_axis_label);
    grid on;
    % X축 플롯 범위 설정 (온도 서브플롯)
    if use_elapsed_time_axis
        if ~isempty(plot_time_range_hours)
            range = plot_time_range_hours;
            if length(range) == 1
                if ~isempty(plot_max_time)
                    xlim([range(1), plot_max_time]);
                else
                    xlim([range(1), max(plot_time_axis)]);
                end
            elseif length(range) == 2
                xlim(range);
            end
        else
            if ~isempty(plot_max_time)
                xlim([0, plot_max_time]);
            end
        end
    else % Absolute datetime axis
        if ~isempty(plot_time_range_datetime)
            try
                start_range = datetime(plot_time_range_datetime{1}, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
                if length(plot_time_range_datetime) == 2
                    end_range = datetime(plot_time_range_datetime{2}, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
                    xlim([start_range, end_range]);
                else
                    if ~isempty(plot_max_datetime)
                        xlim([start_range, plot_max_datetime]);
                    end
                end
            catch ME
                fprintf('datetime 범위 형식이 잘못되었습니다: %s. 전체 범위를 플롯합니다.\n', ME.message);
            end
        end
    end

    % --- Middle row: Magnitude ---
    ax_mag_list(port_idx) = nexttile(t, port_idx + 2);
    
    all_plots_mag = [];
    all_legends_mag = {};
    
    % 데이터 유무에 따라 플로팅 로직 분기
    if sparam_loaded % S-parameter만 플롯 (온도는 상단 서브플롯)
        fprintf('  Port %d Magnitude 플롯 중...\n', port_idx);
        colors = get(gca, 'ColorOrder');
        hold on;
        sparam_plots_mag = [];
        sparam_legends_mag = {};
        num_freqs = length(frequencies_to_plot_GHz);
        for k = 1:num_freqs
            current_freq_GHz = frequencies_to_plot_GHz(k);
            [~, freq_idx] = min(abs(sparam_data.data.Frequencies/1e9 - current_freq_GHz));
            actual_freq = sparam_data.data.Frequencies(freq_idx)/1e9;
            s_param_to_plot = sparam_data.data.(port_data_magnitude{port_idx})(freq_idx, :);
            fprintf('    - %.2f GHz: 데이터 포인트 %d개\n', actual_freq, length(s_param_to_plot));
            s_param_legend_name = sprintf('%s Mag @ %.2f GHz', current_port, actual_freq);
                ci = mod(k-1, size(colors,1)) + 1;
                p = plot(sparam_time_axis, s_param_to_plot, 'Color', colors(ci,:), 'LineStyle', '-', 'Marker','none', 'LineWidth', 1.5);
            sparam_plots_mag = [sparam_plots_mag, p];
            sparam_legends_mag{end+1} = s_param_legend_name;
        end
        hold off;
        ylabel('S-parameter (dB)');
        if ischar(sparam_y_lim) || isstring(sparam_y_lim)
            ylim(sparam_y_lim);
        else
            ylim(sparam_y_lim);
        end
        ax = gca;
        ax.YColor = 'k';
        all_plots_mag = sparam_plots_mag;
        all_legends_mag = sparam_legends_mag;
    end

    title([current_port ' Magnitude']);
    xlabel(time_axis_label);
    grid on;
    % X축 플롯 범위 설정
    if use_elapsed_time_axis
        if ~isempty(plot_time_range_hours)
            range = plot_time_range_hours;
            if length(range) == 1
                if ~isempty(plot_max_time)
                    xlim([range(1), plot_max_time]);
                else % Fallback for safety
                    xlim([range(1), max(plot_time_axis)]);
                end
            elseif length(range) == 2
                xlim(range);
            end
        else % plot_time_range_hours가 비어있을 때, 0부터 시작하도록 xlim 설정
            if ~isempty(plot_max_time)
                xlim([0, plot_max_time]);
            end
        end
    else % Absolute datetime axis
        if ~isempty(plot_time_range_datetime)
            try
                start_range = datetime(plot_time_range_datetime{1}, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
                if length(plot_time_range_datetime) == 2
                    end_range = datetime(plot_time_range_datetime{2}, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
                    xlim([start_range, end_range]);
                else
                    if ~isempty(plot_max_datetime)
                        xlim([start_range, plot_max_datetime]);
                    end
                end
            catch ME
                fprintf('datetime 범위 형식이 잘못되었습니다: %s. 전체 범위를 플롯합니다.\n', ME.message);
            end
        end
    end
    if ~use_elapsed_time_axis && is_datetime_axis
        ax = gca;
        
        % 1시간 단위로 기본 눈금 설정 (축 타입 안전 처리)
        t_limits = ax.XLim;
        hourly_ticks = [];
        if isdatetime(t_limits)
            t_start = dateshift(t_limits(1), 'start', 'hour');
            if t_start < t_limits(1)
                t_start = t_start + hours(1);
            end
            hourly_ticks = t_start:hours(1):t_limits(2);
        elseif isduration(t_limits)
            % duration 축은 커스텀 틱 설정을 생략 (기본 유지)
            hourly_ticks = [];
        else
            % numeric 축(대부분 datenum): datetime으로 변환 후 계산
            try
                t_limits_dt = datetime(t_limits, 'ConvertFrom', 'datenum');
                t_start = dateshift(t_limits_dt(1), 'start', 'hour');
                if t_start < t_limits_dt(1)
                    t_start = t_start + hours(1);
                end
                hourly_ticks_dt = t_start:hours(1):t_limits_dt(2);
                hourly_ticks = datenum(hourly_ticks_dt);
            catch
                hourly_ticks = [];
            end
        end
        
        final_ticks = hourly_ticks;
        
        % 사용자가 수동으로 날짜 표시 위치를 지정한 경우
        if ~isempty(manual_datetick_locations)
            try
                manual_ticks = datetime(manual_datetick_locations, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
                % 기존 눈금과 수동 눈금을 합치고 정렬한 뒤 중복 제거
                final_ticks = sort(union(final_ticks, manual_ticks));
                % 플롯 범위 밖의 눈금 제거
                final_ticks(final_ticks < t_limits(1) | final_ticks > t_limits(2)) = [];
            catch ME
                fprintf('수동 날짜 표시 위치 형식이 잘못되었습니다: %s\n', ME.message);
            end
        end
        
        if ~isempty(final_ticks)
            if isdatetime(t_limits)
                ax.XTick = final_ticks;
            elseif isduration(t_limits)
                ax.XTick = final_ticks; % 그대로 유지
            else
                % numeric (datenum) 축
                ax.XTick = datenum(final_ticks);
            end
        end
        
        % 눈금 라벨: datetime 축은 시간만 보이도록 자동 포맷으로 설정
        try
            ax.XAxis.TickLabelFormat = 'HH:mm';
            ax.XTickLabelMode = 'auto';
        catch
        end
        ax.XTickLabelRotation = 30; % 레이블 겹침 방지
    end
    if ~isempty(all_plots_mag)
        legend(all_plots_mag, all_legends_mag, 'Location', 'best');
    end


    % --- Bottom row: Phase ---
    ax_phase_list(port_idx) = nexttile(t, port_idx + 4);
    
    all_plots_phase = [];
    all_legends_phase = {};
    
    % 데이터 유무에 따라 플로팅 로직 분기
    if sparam_loaded % S-parameter만 플롯 (온도는 상단 서브플롯)
        colors = get(gca, 'ColorOrder');
        hold on;
        sparam_plots_phase = [];
        sparam_legends_phase = {};
        num_freqs = length(frequencies_to_plot_GHz);
        for k = 1:num_freqs
            current_freq_GHz = frequencies_to_plot_GHz(k);
            [~, freq_idx] = min(abs(sparam_data.data.Frequencies/1e9 - current_freq_GHz));
            actual_freq = sparam_data.data.Frequencies(freq_idx)/1e9;
            s_param_phase_raw = sparam_data.data.(port_data_phase{port_idx})(freq_idx, :);
            s_param_to_plot = unwrap(deg2rad(s_param_phase_raw));
            s_param_to_plot = rad2deg(s_param_to_plot);
            s_param_legend_name = sprintf('%s Phase @ %.2f GHz', current_port, actual_freq);
            ci = mod(k-1, size(colors,1)) + 1;
            p = plot(sparam_time_axis, s_param_to_plot, 'Color', colors(ci,:), 'LineStyle', '-', 'Marker','none', 'LineWidth', 1.5);
            sparam_plots_phase = [sparam_plots_phase, p];
            sparam_legends_phase{end+1} = s_param_legend_name;
        end
        hold off;
        ylabel('S-parameter Phase (deg)');
        ax = gca;
        ax.YColor = 'k';
        all_plots_phase = sparam_plots_phase;
        all_legends_phase = sparam_legends_phase;
    end

    title([current_port ' Phase']);
    xlabel(time_axis_label);
    grid on;
    % X축 플롯 범위 설정
    if use_elapsed_time_axis
        if ~isempty(plot_time_range_hours)
            range = plot_time_range_hours;
            if length(range) == 1
                if ~isempty(plot_max_time)
                    xlim([range(1), plot_max_time]);
                else % Fallback for safety
                    xlim([range(1), max(plot_time_axis)]);
                end
            elseif length(range) == 2
                xlim(range);
            end
        else % plot_time_range_hours가 비어있을 때, 0부터 시작하도록 xlim 설정
            if ~isempty(plot_max_time)
                xlim([0, plot_max_time]);
            end
        end
    else % Absolute datetime axis
        if ~isempty(plot_time_range_datetime)
            try
                start_range = datetime(plot_time_range_datetime{1}, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
                if length(plot_time_range_datetime) == 2
                    end_range = datetime(plot_time_range_datetime{2}, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
                    xlim([start_range, end_range]);
                else
                    if ~isempty(plot_max_datetime)
                        xlim([start_range, plot_max_datetime]);
                    end
                end
            catch ME
                fprintf('datetime 범위 형식이 잘못되었습니다: %s. 전체 범위를 플롯합니다.\n', ME.message);
            end
        end
    end
    if ~use_elapsed_time_axis && is_datetime_axis
        ax = gca;
        
        % 1시간 단위로 기본 눈금 설정 (축 타입 안전 처리)
        t_limits = ax.XLim;
        hourly_ticks = [];
        if isdatetime(t_limits)
            t_start = dateshift(t_limits(1), 'start', 'hour');
            if t_start < t_limits(1)
                t_start = t_start + hours(1);
            end
            hourly_ticks = t_start:hours(1):t_limits(2);
        elseif isduration(t_limits)
            hourly_ticks = [];
        else
            try
                t_limits_dt = datetime(t_limits, 'ConvertFrom', 'datenum');
                t_start = dateshift(t_limits_dt(1), 'start', 'hour');
                if t_start < t_limits_dt(1)
                    t_start = t_start + hours(1);
                end
                hourly_ticks_dt = t_start:hours(1):t_limits_dt(2);
                hourly_ticks = datenum(hourly_ticks_dt);
            catch
                hourly_ticks = [];
            end
        end
        
        final_ticks = hourly_ticks;
        
        % 사용자가 수동으로 날짜 표시 위치를 지정한 경우
        if ~isempty(manual_datetick_locations)
            try
                manual_ticks = datetime(manual_datetick_locations, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
                % 기존 눈금과 수동 눈금을 합치고 정렬한 뒤 중복 제거
                final_ticks = sort(union(final_ticks, manual_ticks));
                % 플롯 범위 밖의 눈금 제거
                final_ticks(final_ticks < t_limits(1) | final_ticks > t_limits(2)) = [];
            catch ME
                fprintf('수동 날짜 표시 위치 형식이 잘못되었습니다: %s\n', ME.message);
            end
        end
        
        if ~isempty(final_ticks)
            if isdatetime(t_limits)
                ax.XTick = final_ticks;
            elseif isnumeric(t_limits)
                ax.XTick = datenum(final_ticks);
            else
                ax.XTick = final_ticks;
            end
        end
        
        % 눈금 라벨: datetime 축은 시간만 보이도록 자동 포맷으로 설정
        try
            ax.XAxis.TickLabelFormat = 'HH:mm';
            ax.XTickLabelMode = 'auto';
        catch
        end
        ax.XTickLabelRotation = 30; % 레이블 겹침 방지
    end
    if ~isempty(all_plots_phase)
        legend(all_plots_phase, all_legends_phase, 'Location', 'best');
    end

end

% 첫 번째 Figure x축 링크 (축 타입별로 분리하여 링크)
all_axes_fig1 = [ax_temp_list, ax_mag_list, ax_phase_list];
numeric_axes = [];
datetime_axes = [];
duration_axes = [];
for axh = all_axes_fig1
    try
        xl = get(axh, 'XLim');
        if isa(xl, 'datetime')
            datetime_axes(end+1) = axh; %#ok<AGROW>
        elseif isa(xl, 'duration')
            duration_axes(end+1) = axh; %#ok<AGROW>
        else
            numeric_axes(end+1) = axh; %#ok<AGROW>
        end
    catch
        % skip invalid axes
    end
end
if numel(numeric_axes) > 1, linkaxes(numeric_axes, 'x'); end
if numel(datetime_axes) > 1, linkaxes(datetime_axes, 'x'); end
if numel(duration_axes) > 1, linkaxes(duration_axes, 'x'); end

% 첫 번째 Figure: 각 열에 대해 1행(온도) 축의 XTick/XTickLabel을
% 2행(크기), 3행(위상) 축에도 동일하게 적용하여 시간축 틱/라벨을 통일
try
    ncols = numel(ax_temp_list);
    for ci = 1:ncols
        topAx = ax_temp_list(ci);
        if ~ishandle(topAx), continue; end
        % 상단 축의 틱/라벨/회전 각도 가져오기
        try
            ticksTop  = get(topAx, 'XTick');
            labelsTop = get(topAx, 'XTickLabel');
            rotTop    = get(topAx, 'XTickLabelRotation');
        catch
            continue;
        end
        % 같은 열의 2,3행 축에 적용
        if ci <= numel(ax_mag_list) && ishghandle(ax_mag_list(ci))
            set(ax_mag_list(ci), 'XTick', ticksTop, 'XTickLabel', labelsTop, 'XTickLabelRotation', rotTop);
        end
        if ci <= numel(ax_phase_list) && ishghandle(ax_phase_list(ci))
            set(ax_phase_list(ci), 'XTick', ticksTop, 'XTickLabel', labelsTop, 'XTickLabelRotation', rotTop);
        end
    end
catch
    % fail-safe: 틱 통일 실패 시 무시
end

% 확대/축소/창 크기 변경 시에도 틱/라벨이 항상 동기화되도록 콜백 설치
try
    install_timeaxis_tick_sync(fig1, ax_temp_list, ax_mag_list, ax_phase_list);
    % Datetime 축 사용 시, 틱 포맷과 위치를 통일
    unify_datetime_axis(fig1, ax_temp_list, ax_mag_list, ax_phase_list);
    % 글꼴 크기 2배 (figure title 제외: tiledlayout/sgtitle에 직접 지정된 폰트는 유지)
    scale_plot_fonts(fig1, 2.0);
catch
    % 콜백 설치 실패 시 무시(초기 정렬은 위에서 수행됨)
end

if is_transmit_plot == 1
    %% S21, S12 플롯 추가
    port_params_trans = {'S21', 'S12'};
    port_data_magnitude_trans = {'S21_dB', 'S12_dB'};
    port_data_phase_trans = {'S21_phase', 'S12_phase'};
    % S21은 Port2 온도 채널(channelGroups{2})과, S12는 Port1 온도 채널(channelGroups{1})과 매칭
    channelGroups_trans_map = [2, 1]; 
    
    % S21/S12 데이터가 있는지 확인
    has_trans_data = false;
    if sparam_loaded
        if isfield(sparam_data.data, 'S21_dB') || isfield(sparam_data.data, 'S12_dB')
            has_trans_data = true;
        end
    end
    
    % S21/S12 데이터가 있을 때만 Figure 생성
    if has_trans_data || temp_data_loaded
        % 새로운 Figure 생성
        fig2 = figure('Name', 'S-parameter Transmission (S21, S12)', ...
               'NumberTitle', 'off', 'Position', [80, 80, 1200, 900]);
    
        % tiledlayout 사용으로 정확한 정렬 (figure 핸들 명시)
        t2 = tiledlayout(fig2, 3, 2, 'TileSpacing', 'compact', 'Padding', 'compact');
        title(t2, ['S-parameter Transmission Data from ' strrep(plot_title_dir, '_', '\_')], 'FontSize', 14);
    
        % x축 링크를 위한 축 핸들 수집
        ax_temp_list_tr = [];
        ax_mag_list_tr = [];
        ax_phase_list_tr = [];
    
        for port_idx = 1:2
        current_port = port_params_trans{port_idx};
        
        % 현재 포트에 맞는 온도 채널 그룹 선택
        temp_channel_group_idx = channelGroups_trans_map(port_idx);
        channelsToPlot = channelGroups{temp_channel_group_idx};
        current_temp_colors = temp_plot_colors{temp_channel_group_idx};
    
        % --- Top row: Temperature (separate) ---
        ax_temp_list_tr(port_idx) = nexttile(t2, port_idx);
        temp_plots_top_tr = [];
        temp_legends_top_tr = {};
        if temp_data_loaded
            hold on;
            num_channels_to_plot = length(channelsToPlot);
            num_predefined_colors = length(current_temp_colors);
            all_temp_colors = current_temp_colors;
            if num_channels_to_plot > num_predefined_colors
                additional_colors = lines(num_channels_to_plot - num_predefined_colors);
                for i = 1:(num_channels_to_plot - num_predefined_colors)
                    all_temp_colors{num_predefined_colors + i} = additional_colors(i, :);
                end
            end
            for j = 1:length(channelsToPlot)
                channelIndex = channelsToPlot(j);
                if channelIndex <= size(data, 2)
                     x = plot_time_axis; y = data(:, channelIndex);
                     if iscell(y)
                         y = cellfun(@str2double, y);
                     elseif isstring(y)
                         y = str2double(y);
                     elseif iscategorical(y)
                         y = double(y);
                     end
                     common_len = min(numel(x), numel(y));
                     x = x(1:common_len); y = y(1:common_len);
                     col = all_temp_colors{j};
                     if isstring(col) || ischar(col)
                         cs = char(col);
                         if ~isempty(cs) && cs(1) == '#' && numel(cs) >= 7
                             col = [hex2dec(cs(2:3)) hex2dec(cs(4:5)) hex2dec(cs(6:7))]/255;
                         elseif numel(cs) == 1
                             switch cs
                                 case 'r', col = [1 0 0];
                                 case 'g', col = [0 1 0];
                                 case 'b', col = [0 0 1];
                                 case 'c', col = [0 1 1];
                                 case 'm', col = [1 0 1];
                                 case 'y', col = [1 1 0];
                                 case 'k', col = [0 0 0];
                                 case 'w', col = [1 1 1];
                                 otherwise, col = [0 0 0];
                             end
                         else
                             col = [0 0 0];
                         end
                     end
                     p = plot(x, y, 'LineStyle', '-', 'Color', col, 'Marker','none','LineWidth', 1.5);
                     temp_plots_top_tr = [temp_plots_top_tr, p];
                     temp_legends_top_tr{end+1} = ['Ch ' num2str(channelIndex)];
                 end
            end
            hold off;
            ylabel('Temperature (°C)');
            ylim(temp_y_lim);
            if ~isempty(temp_plots_top_tr)
                legend(temp_plots_top_tr, temp_legends_top_tr, 'Location', 'best');
            end
        end
        title([current_port ' Temperature']);
        xlabel(time_axis_label);
        grid on;
        % X축 플롯 범위 설정 (온도 서브플롯)
        if use_elapsed_time_axis
            if ~isempty(plot_time_range_hours)
                range = plot_time_range_hours;
                if length(range) == 1
                    if ~isempty(plot_max_time)
                        xlim([range(1), plot_max_time]);
                    else
                        xlim([range(1), max(plot_time_axis)]);
                    end
                elseif length(range) == 2
                    xlim(range);
                end
            else
                if ~isempty(plot_max_time)
                    xlim([0, plot_max_time]);
                end
            end
        else % Absolute datetime axis
            if ~isempty(plot_time_range_datetime)
                try
                    start_range = datetime(plot_time_range_datetime{1}, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
                    if length(plot_time_range_datetime) == 2
                        end_range = datetime(plot_time_range_datetime{2}, 'InputFormat', 'yyyy-MM-dd HH:mm:ss');
                        xlim([start_range, end_range]);
                    else
                        if ~isempty(plot_max_datetime)
                            xlim([start_range, plot_max_datetime]);
                        end
                    end
                catch ME
                    fprintf('datetime 범위 형식이 잘못되었습니다: %s. 전체 범위를 플롯합니다.\n', ME.message);
                end
            end
        end
    
        % --- Middle row: Magnitude (S21 or S12) ---
        ax_mag_list_tr(port_idx) = nexttile(t2, port_idx + 2);
        all_plots_mag = [];
        all_legends_mag = {};
        if sparam_loaded
            colors = get(gca, 'ColorOrder');
            hold on;
            sparam_plots_mag = [];
            sparam_legends_mag = {};
            for k = 1:length(frequencies_to_plot_GHz)
                current_freq_GHz = frequencies_to_plot_GHz(k);
                [~, freq_idx] = min(abs(sparam_data.data.Frequencies/1e9 - current_freq_GHz));
                actual_freq = sparam_data.data.Frequencies(freq_idx)/1e9;
                s_param_to_plot = sparam_data.data.(port_data_magnitude_trans{port_idx})(freq_idx, :);
                s_param_legend_name = sprintf('%s Mag @ %.2f GHz', current_port, actual_freq);
                ci = mod(k-1, size(colors,1)) + 1;
                p = plot(sparam_time_axis, s_param_to_plot, 'Color', colors(ci,:), 'LineStyle', '-', 'Marker','none', 'LineWidth', 1.5);
                sparam_plots_mag = [sparam_plots_mag, p];
                sparam_legends_mag{end+1} = s_param_legend_name;
            end
            hold off;
            ylabel('S-parameter (dB)');
            if ischar(sparam_S21_S12_y_lim) || isstring(sparam_S21_S12_y_lim)
                ylim(sparam_S21_S12_y_lim);
            else
                ylim(sparam_S21_S12_y_lim);
            end
            ax = gca; %#ok<NASGU>
            all_plots_mag = sparam_plots_mag;
            all_legends_mag = sparam_legends_mag;
        end
        title([current_port ' Magnitude']);
        xlabel(time_axis_label);
        grid on;
        if use_elapsed_time_axis
            if ~isempty(plot_time_range_hours)
                xlim(plot_time_range_hours);
            end
        end
        if ~isempty(all_plots_mag)
            legend(all_plots_mag, all_legends_mag, 'Location', 'best');
        end
    
        % --- Bottom row: Phase (S21 or S12) ---
        ax_phase_list_tr(port_idx) = nexttile(t2, port_idx + 4);
        all_plots_phase = [];
        all_legends_phase = {};
        if sparam_loaded
            colors = get(gca, 'ColorOrder');
            hold on;
            sparam_plots_phase = [];
            sparam_legends_phase = {};
            for k = 1:length(frequencies_to_plot_GHz)
                current_freq_GHz = frequencies_to_plot_GHz(k);
                [~, freq_idx] = min(abs(sparam_data.data.Frequencies/1e9 - current_freq_GHz));
                actual_freq = sparam_data.data.Frequencies(freq_idx)/1e9;
                s_param_phase_raw = sparam_data.data.(port_data_phase_trans{port_idx})(freq_idx, :);
                s_param_to_plot = unwrap(deg2rad(s_param_phase_raw));
                s_param_to_plot = rad2deg(s_param_to_plot);
                s_param_legend_name = sprintf('%s Phase @ %.2f GHz', current_port, actual_freq);
            ci = mod(k-1, size(colors,1)) + 1;
            p = plot(sparam_time_axis, s_param_to_plot, 'Color', colors(ci,:), 'LineStyle', '-', 'Marker','none', 'LineWidth', 1.5);
                sparam_plots_phase = [sparam_plots_phase, p];
                sparam_legends_phase{end+1} = s_param_legend_name;
            end
            hold off;
            ylabel('S-parameter Phase (deg)');
            ax = gca; %#ok<NASGU>
            all_plots_phase = sparam_plots_phase;
            all_legends_phase = sparam_legends_phase;
        end
        title([current_port ' Phase']);
        xlabel(time_axis_label);
        grid on;
        if use_elapsed_time_axis
            if ~isempty(plot_time_range_hours)
                xlim(plot_time_range_hours);
            end
        end
        if ~isempty(all_plots_phase)
            legend(all_plots_phase, all_legends_phase, 'Location', 'best');
        end
    end
    
        % 두 번째 Figure x축 링크 (축 타입별로 분리하여 링크)
        all_axes_fig2 = [ax_temp_list_tr, ax_mag_list_tr, ax_phase_list_tr];
        numeric_axes = [];
        datetime_axes = [];
        duration_axes = [];
        for axh = all_axes_fig2
            try
                xl = get(axh, 'XLim');
                if isa(xl, 'datetime')
                    datetime_axes(end+1) = axh; %#ok<AGROW>
                elseif isa(xl, 'duration')
                    duration_axes(end+1) = axh; %#ok<AGROW>
                else
                    numeric_axes(end+1) = axh; %#ok<AGROW>
                end
            catch
            end
        end
        if numel(numeric_axes) > 1, linkaxes(numeric_axes, 'x'); end
        if numel(datetime_axes) > 1, linkaxes(datetime_axes, 'x'); end
        if numel(duration_axes) > 1, linkaxes(duration_axes, 'x'); end
        % Transmission figure 폰트 2배
        try, scale_plot_fonts(fig2, 2.0); catch, end
    end % S21/S12 Figure 조건문 종료
end

% ---------- Local helpers for tick synchronization ----------
function adjust_axes_width(fig, scale)
    % Shrink axes width by `scale` (e.g., 0.7) and center horizontally
    if nargin < 2, scale = 0.7; end
    axs = findall(fig, 'Type','axes');
    for ax = axs.'
        try
            pos = get(ax,'Position'); % [x y w h]
            w0 = pos(3);
            w1 = w0 * scale;
            dx = (w0 - w1)/2;
            pos(1) = pos(1) + dx;
            pos(3) = w1;
            set(ax,'Position', pos);
        catch
        end
    end
end

function scale_plot_fonts(fig, factor)
    if nargin < 2, factor = 2.0; end
    if ~ishandle(fig), return; end
    % Axes font (ticks, axis labels via multipliers)
    axs = findall(fig, 'Type','axes');
    for ax = axs.'
        try
            fs = get(ax,'FontSize');
            if isnumeric(fs) && isfinite(fs)
                set(ax,'FontSize', fs*factor);
            end
        catch, end
    end
    % Explicitly restore legend fonts to baseline (pre-scale) defaults
    try
        lgs = findall(fig, 'Type','legend');
        % Determine baseline default legend font size
        base = get(groot, 'defaultLegendFontSize');
        if isempty(base) || ~isnumeric(base)
            base = get(groot, 'factoryLegendFontSize');
        end
        % Fallback if still empty
        if isempty(base) || ~isnumeric(base)
            base = 9; % reasonable default
        end
        for lg = lgs.'
            try, set(lg, 'FontSize', base); catch, end
        end
    catch
    end
    % Note: Figure-level titles (sgtitle/title(tiledlayout)) have explicit sizes; left untouched.
end

function install_timeaxis_tick_sync(fig, ax_top, ax_mid, ax_bot)
    S = struct();
    % 열 수는 각 리스트의 최소 길이에 맞춤
    ncol = min([numel(ax_top), numel(ax_mid), numel(ax_bot)]);
    S.ax_top = ax_top(1:ncol);
    S.ax_mid = ax_mid(1:ncol);
    S.ax_bot = ax_bot(1:ncol);
    setappdata(fig, 'plot_temp_tick_sync', S);

    % 초기 동기화 1회 수행
    local_sync_ticks(fig);

    % 확대/축소, 팬 이후에도 동기화되도록 콜백 연결
    try
        z = zoom(fig); z.ActionPostCallback   = @(~,~) local_sync_ticks(fig);
    catch, end
    try
        p = pan(fig);  p.ActionPostCallback   = @(~,~) local_sync_ticks(fig);
    catch, end
    try
        fig.SizeChangedFcn = @(~,~) local_sync_ticks(fig);
    catch, end
end

function local_sync_ticks(fig)
    if ~ishandle(fig), return; end
    S = getappdata(fig, 'plot_temp_tick_sync');
    if isempty(S), return; end
    ncol = numel(S.ax_top);
    for i = 1:ncol
        topAx = S.ax_top(i);
        if ~ishandle(topAx), continue; end
        % 상단 축에서 현재 틱/라벨/회전값 읽기
        try
            ticksTop  = get(topAx, 'XTick');
            labelsTop = get(topAx, 'XTickLabel');
            rotTop    = get(topAx, 'XTickLabelRotation');
        catch
            continue;
        end
        % 동일 열의 하단 축들에 복사(수동 틱 모드), 축 타입 변환을 고려
        % 상단 축 타입 파악
        topXL = get(topAx, 'XLim');
        topIsDatetime = isa(topXL, 'datetime');
        topIsDuration = isa(topXL, 'duration');

        dests = [];
        if i <= numel(S.ax_mid) && ishghandle(S.ax_mid(i)), dests = [dests, S.ax_mid(i)]; end
        if i <= numel(S.ax_bot) && ishghandle(S.ax_bot(i)), dests = [dests, S.ax_bot(i)]; end
        for d = dests
            try
                dXL = get(d, 'XLim');
                dIsDatetime = isa(dXL, 'datetime');
                dIsDuration = isa(dXL, 'duration');

                tConv = ticksTop;
                if topIsDatetime && ~dIsDatetime
                    % 상단은 datetime, 대상은 숫자 또는 duration
                    if dIsDuration
                        % duration 축: 상대시간(초)로 변환 (원점 차이 존재 가능)
                        t0 = ticksTop(1);
                        tConv = seconds(ticksTop - t0);
                    else
                        % 숫자 축(대개 datenum)
                        try
                            tConv = datenum(ticksTop);
                        catch
                            % 실패 시 포기
                        end
                    end
                elseif ~topIsDatetime && dIsDatetime
                    % 상단은 숫자/지속시간, 대상은 datetime
                    try
                        % 숫자를 datenum으로 가정하여 datetime으로 변환
                        tConv = datetime(ticksTop, 'ConvertFrom', 'datenum');
                    catch
                        % 변환 실패 시 그대로 둠
                    end
                end

                set(d, 'XTickMode','manual', 'XTick', tConv, 'XTickLabelMode','auto', 'XTickLabelRotation', rotTop);
            catch
                % 타입 불일치 등은 건너뜀
            end
        end
    end
end

function unify_datetime_axis(fig, ax_top, ax_mid, ax_bot)
    % 각 열에 대해 datetime 축이면 시간 포맷을 'HH:mm'으로 통일하고
    % 상단 축의 틱 위치를 2,3행에도 적용하여 완전 일치시키는 헬퍼
    ncol = min([numel(ax_top), numel(ax_mid), numel(ax_bot)]);
    for ci = 1:ncol
        topAx = ax_top(ci);
        if ~ishandle(topAx), continue; end
        try
            xl = get(topAx,'XLim');
        catch
            continue;
        end
        if ~isa(xl,'datetime'), continue; end
        % 상단 포맷: 시간만 표시
        try
            topAx.XAxis.TickLabelFormat = 'HH:mm';
            topAx.XAxis.SecondaryLabel.Visible = 'on';
        catch, end
        % 상단 틱 가져와 하단 복제
        try, ticksTop = get(topAx,'XTick'); catch, ticksTop = []; end
        dests = [];
        if ci <= numel(ax_mid) && ishghandle(ax_mid(ci)), dests = [dests, ax_mid(ci)]; end
        if ci <= numel(ax_bot) && ishghandle(ax_bot(ci)), dests = [dests, ax_bot(ci)]; end
        for d = dests
            try
                d.XAxis.TickLabelFormat = 'HH:mm';
                d.XAxis.SecondaryLabel.Visible = 'on';
                if ~isempty(ticksTop)
                    set(d,'XTickMode','manual','XTick',ticksTop,'XTickLabelMode','auto');
                else
                    set(d,'XTickLabelMode','auto');
                end
            catch
            end
        end
    end
end

