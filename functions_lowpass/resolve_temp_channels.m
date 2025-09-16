function idxT = resolve_temp_channels(allLabels, cfgPath)
% resolve_temp_channels  온도 채널 선택 CSV를 로드/생성하여 인덱스 반환
%
% 사용법
%   idx = resolve_temp_channels(allLabels, cfgPath)
%
% 입력
%   allLabels : 채널 라벨(cellstr 또는 string 배열)
%   cfgPath   : 설정 CSV 경로(존재하지 않으면 프롬프트로 생성)
%
% CSV 포맷
%   - Label 열(권장): 라벨명으로 채널 지정(대소문자 무시)
%   - Index 열       : 1 기반 인덱스로 채널 지정
%
% 동작
%   - cfg가 유효하면 즉시 로드
%   - 없거나 유효치 않으면 사용자에게 채널을 물어보고 기본 1:min(8,N)
%     선택 후 Label 열 형식으로 cfg를 저장

    if isstring(allLabels), allLabels = cellstr(allLabels); end
    if ~iscell(allLabels), allLabels = cellstr(allLabels); end
    nL = numel(allLabels);
    if nL == 0
        idxT = 1:0; return;
    end

    cfgPath = char(cfgPath);
    % 1) 시도: 기존 설정 로드
    if isfile(cfgPath)
        try
            Tcfg = readtable(cfgPath);
            idxFromCfg = [];
            if any(strcmpi(Tcfg.Properties.VariableNames, 'Label'))
                labelsWanted = Tcfg.Label;
                if iscell(labelsWanted) || isstring(labelsWanted)
                    labelsWanted = cellstr(string(labelsWanted));
                    idxFromCfg = i_labels_to_indices(allLabels, labelsWanted);
                end
            end
            if isempty(idxFromCfg) && any(strcmpi(Tcfg.Properties.VariableNames, 'Index'))
                idxFromCfg = Tcfg.Index(:)';
            end
            idxFromCfg = unique(round(idxFromCfg));
            idxFromCfg = idxFromCfg(idxFromCfg>=1 & idxFromCfg<=nL);
            if ~isempty(idxFromCfg)
                idxT = idxFromCfg;
                return;
            else
                warning('resolve_temp_channels:EmptyCfg', '설정 CSV에 유효 채널이 없습니다. 새 선택을 진행합니다.');
            end
        catch ME
            warning('resolve_temp_channels:LoadFailed', '설정 CSV 로드 실패: %s. 새 선택을 진행합니다.', ME.message);
        end
    end

    % 2) 프롬프트로 선택 받아 저장
    fprintf('온도 플롯 채널 선택 — 사용 가능 %d개:\n', nL);
    for i = 1:nL, fprintf('  [%d] %s\n', i, allLabels{i}); end
    fprintf('입력 예) 1:4  |  1,3,5,8  |  Enter=기본(1:min(8,N))\n');
    raw = input('채널 선택: ', 's'); raw = strtrim(raw);
    if isempty(raw)
        idxT = 1:min(8, nL);
    else
        try
            tmp = eval(['[', raw, ']']); %#ok<EVLDIR>
            if ~isnumeric(tmp) || isempty(tmp), error('형식 오류'); end
            idxT = unique(round(tmp(:)'));
            idxT = idxT(idxT>=1 & idxT<=nL);
            if isempty(idxT), idxT = 1:min(8, nL); end
        catch
            idxT = 1:min(8, nL);
        end
    end

    % 저장(Label 기준)
    try
        out = table(string(allLabels(idxT))', 'VariableNames', {'Label'});
        writetable(out, cfgPath);
        fprintf('온도 채널 선택 저장: %s\n', cfgPath);
    catch ME
        warning('resolve_temp_channels:SaveFailed', '설정 저장 실패: %s', ME.message);
    end
end

function idx = i_labels_to_indices(allLabels, wantedLabels)
    idx = [];
    if isempty(wantedLabels), return; end
    lowAll = lower(string(allLabels));
    for k = 1:numel(wantedLabels)
        w = lower(string(wantedLabels{k}));
        hit = find(lowAll == w, 1, 'first');
        if ~isempty(hit), idx(end+1) = hit; end %#ok<AGROW>
    end
    idx = unique(idx);
end

