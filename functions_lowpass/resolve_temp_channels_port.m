function idxT = resolve_temp_channels_port(allLabels, cfgPath, portTag)
% resolve_temp_channels_port  단일 CSV에서 포트별 채널 선택을 로드/생성
% - CSV 컬럼 규칙(우선순위):
%   1) Label_P1/Label_P2 (또는 Index_P1/Index_P2)
%   2) Label (또는 Index) — 두 포트 공통
% - 포트 태그: 'P1'|'P2'|'S11'|'S22'|'1'|'2' (대소문자 무시)
% - 파일이 없거나 해당 포트 컬럼이 없으면 사용자에게 입력을 받아 저장(라벨 기준)

    if isstring(allLabels), allLabels = cellstr(allLabels); end
    if ~iscell(allLabels), allLabels = cellstr(allLabels); end
    nL = numel(allLabels);
    if nL == 0
        idxT = 1:0; return;
    end
    portTag = upper(string(portTag));
    if portTag == "S11" || portTag == "1"
        portKey = "P1";
    elseif portTag == "S22" || portTag == "2"
        portKey = "P2";
    elseif portTag == "P1" || portTag == "P2"
        portKey = portTag;
    else
        portKey = "P1";
    end

    cfgPath = char(cfgPath);
    if isfile(cfgPath)
        try
            Tcfg = readtable(cfgPath);
            labCol = sprintf('Label_%s', portKey);
            idxCol = sprintf('Index_%s', portKey);
            idxFromCfg = [];
            if any(strcmpi(Tcfg.Properties.VariableNames, labCol))
                labelsWanted = Tcfg.(labCol);
                idxFromCfg = i_labels_to_indices(allLabels, labelsWanted);
            elseif any(strcmpi(Tcfg.Properties.VariableNames, idxCol))
                idxFromCfg = Tcfg.(idxCol)(:).';
            elseif any(strcmpi(Tcfg.Properties.VariableNames, 'Label'))
                labelsWanted = Tcfg.('Label');
                idxFromCfg = i_labels_to_indices(allLabels, labelsWanted);
            elseif any(strcmpi(Tcfg.Properties.VariableNames, 'Index'))
                idxFromCfg = Tcfg.('Index')(:).';
            end
            idxFromCfg = unique(round(idxFromCfg));
            idxFromCfg = idxFromCfg(idxFromCfg>=1 & idxFromCfg<=nL);
            if ~isempty(idxFromCfg)
                idxT = idxFromCfg;
                return;
            end
        catch ME
            warning('resolve_temp_channels_port:LoadFailed', '채널 설정 CSV 로드 실패: %s', ME.message);
        end
    end

    % Prompt user and save to combined CSV
    fprintf('온도 플롯 채널 선택 (%s) — 사용 가능 %d개:\n', portKey, nL);
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

    % Write back preserving other port if present
    try
        if isfile(cfgPath)
            Tcfg = readtable(cfgPath);
        else
            Tcfg = table();
        end
        labCol = sprintf('Label_%s', portKey);
        labels = string(allLabels(idxT))';
        Hold = height(Tcfg);
        Hnew = max(Hold, numel(labels));
        if Hold < Hnew && width(Tcfg) > 0
            addN = Hnew - Hold;
            S2 = struct();
            for vi = 1:width(Tcfg)
                vn = Tcfg.Properties.VariableNames{vi};
                v = Tcfg.(vn);
                if iscell(v)
                    v(end+1:Hnew,1) = {''};
                elseif isstring(v)
                    v(end+1:Hnew,1) = strings(addN,1);
                elseif isnumeric(v)
                    v(end+1:Hnew,1) = NaN(addN,1);
                elseif isdatetime(v)
                    v(end+1:Hnew,1) = NaT(addN,1);
                else
                    v = string(v);
                    v(end+1:Hnew,1) = strings(addN,1);
                end
                S2.(vn) = v;
            end
            Tcfg = struct2table(S2);
        end
        col = strings(Hnew,1);
        col(1:numel(labels)) = labels;
        Tcfg.(labCol) = col;
        writetable(Tcfg, cfgPath);
        fprintf('온도 채널(%s) 선택 저장: %s\n', portKey, cfgPath);
    catch ME
        warning('resolve_temp_channels_port:SaveFailed', '설정 저장 실패: %s', ME.message);
    end
end

function idx = i_labels_to_indices(allLabels, labelsWanted)
    if isstring(labelsWanted), labelsWanted = cellstr(labelsWanted); end
    if ischar(labelsWanted), labelsWanted = {labelsWanted}; end
    idx = [];
    lowAll = lower(string(allLabels));
    for k = 1:numel(labelsWanted)
        w = lower(string(labelsWanted{k}));
        hit = find(lowAll == w, 1, 'first');
        if ~isempty(hit), idx(end+1) = hit; end %#ok<AGROW>
    end
    idx = unique(idx);
end

