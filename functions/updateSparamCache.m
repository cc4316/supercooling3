function [S, fileInfo] = updateSparamCache(measDir, cacheFile, freqPick)
%--------------------------------------------------------------------------
%  S  : 2×2×P×N  (single or double)
%  fileInfo : table{FileName, FileTime}
%--------------------------------------------------------------------------

%% 1) 캐시 유효성 검사 및 로드
if isfile(cacheFile)
    rebuild = false;
    try
        cache = load(cacheFile, 'S', 'fileInfo', 'freqPick', 'cacheVersion');
        % (a) 주파수 목록이 다른 경우 재빌드
        if ~isequal(cache.freqPick, freqPick)
            rebuild = true; reason = "freqPick changed";
        % (b) S-파라미터가 복소수형이 아닌 경우 재빌드
        elseif isreal(cache.S)
            rebuild = true; reason = "S is not complex";
        end
    catch
        rebuild = true; reason = "corrupted cache";
    end

    if rebuild
        warning("updateSparamCache: %s — rebuilding cache.", reason);
    else
        S = cache.S;
        fileInfo = cache.fileInfo;
    end
else
    rebuild = true;
end

if rebuild
    P = numel(freqPick);
    dtype = 'single';
    S = complex(zeros(2, 2, P, 0, dtype));
    fileInfo = table('Size', [0 2], 'VariableTypes', {'string', 'double'}, ...
                     'VariableNames', {'FileName', 'FileTime'});
end

dtype = class(S);

%% 2) 폴더 검색 및 파일별 갱신
dirList = dir(fullfile(measDir, "*.s2p"));
if isempty(dirList)
    if ~rebuild, save(cacheFile, 'S', 'fileInfo', 'freqPick', 'cacheVersion', '-v7.3'); end
    return;
end
names = string({dirList.name});
times = [dirList.datenum]';

needsSave = false;
for k = 1:numel(names)
    f = names(k); t = times(k);
    idx = find(fileInfo.FileName == f, 1);

    if isempty(idx) || fileInfo.FileTime(idx) ~= t
        needsSave = true; % 변경사항 발생
        fp = fullfile(measDir, f);

        try
            net = sparameters(fp);
        catch ME
            if strcmp(ME.identifier, "rf:thirdparty:invalidCharacter")
                removeLine(fp, 4); net = sparameters(fp);
            else
                rethrow(ME);
            end
        end

        [~, idxF] = ismember(freqPick, net.Frequencies);
        if any(idxF == 0), warning("%s: 일부 주파수 없음, 건너뜀", f); continue; end
        
        tmp = net.Parameters(:,:,idxF);
        S_new = complex(cast(real(tmp), dtype), cast(imag(tmp), dtype));

        if isempty(idx) % 새 파일
            S(:, :, :, end+1) = S_new;
            fileInfo(end+1, :) = {f, t};
        else % 수정된 파일
            S(:, :, :, idx) = S_new;
            fileInfo.FileTime(idx) = t;
        end
    end
end

%% 3) 캐시 파일 저장 및 반환
if needsSave || rebuild
    cacheVersion = 5;
    save(cacheFile, 'S', 'fileInfo', 'freqPick', 'cacheVersion', '-v7.3');
end

end
