function dataDir = local_select_expdata_dir(baseExp)
% local_select_expdata_dir  expdata 하위 폴더 중 sParam/sparam_data*.mat 보유 폴더 선택
% 반환값 dataDir는 sParam 폴더 경로입니다.

S = dir(baseExp);
S = S([S.isdir]);
names = {S.name};
names = names(~ismember(names, {'.','..'}));

candidates = {};
for i = 1:numel(names)
    sess = names{i};
    sparamDir = fullfile(baseExp, sess, 'sParam');
    if exist(sparamDir, 'dir') == 7
        hasParts = ~isempty(dir(fullfile(sparamDir, 'sparam_data_part*.mat')));
        hasSingle = ~isempty(dir(fullfile(sparamDir, 'sparam_data.mat')));
        if hasParts || hasSingle
            candidates{end+1} = sparamDir; %#ok<AGROW>
        end
    end
end

if isempty(candidates)
    error('combine_sparam_lowpass:NoCandidates', 'expdata 하위에 sParam 데이터가 있는 폴더가 없습니다: %s', baseExp);
end

fprintf('\n[combine_sparam_lowpass] expdata 후보 목록:\n');
for i = 1:numel(candidates)
    rel = erase(candidates{i}, [baseExp filesep]);
    fprintf('  %2d) %s\n', i, rel);
end

% 이전 선택 기억/적용
defaultIdx = 1;
try
    prefPath = fullfile(baseExp, '.last_expdata_selection.mat');
    if exist(prefPath, 'file') == 2
        S = load(prefPath);
        if isfield(S, 'lastSparamDir') && ischar(S.lastSparamDir)
            lastDir = S.lastSparamDir;
            for j = 1:numel(candidates)
                if strcmp(candidates{j}, lastDir)
                    defaultIdx = j; break;
                end
            end
        end
    end
catch
end

idx = [];
prompt = sprintf('선택 번호 입력 (기본 %d): ', defaultIdx);
while isempty(idx)
    in = input(prompt, 's');
    if isempty(in)
        idx = defaultIdx;
    else
        vi = str2double(in);
        if isfinite(vi) && vi>=1 && vi<=numel(candidates) && vi==round(vi)
            idx = vi;
        else
            fprintf('유효한 번호를 입력하세요 (1..%d).\n', numel(candidates));
        end
    end
end

dataDir = candidates{idx};
fprintf('선택: %s\n\n', dataDir);

% 선택값 저장
try
    prefPath = fullfile(baseExp, '.last_expdata_selection.mat');
    lastSparamDir = dataDir; %#ok<NASGU>
    save(prefPath, 'lastSparamDir');
catch
end
end
