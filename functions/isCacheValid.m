function ok = isCacheValid(cacheFile, fileList)
    % 캐시가 있고, 캐시 안에 기록된 fileList와 동일하면 true
    if ~isfile(cacheFile), ok = false; return; end

    try
        info = matfile(cacheFile, 'Writable', false);
        cachedList = info.fileList;             % 저장해 둔 목록을 읽음
    catch
        ok = false; return;                     % 구조가 달라 깨진 경우
    end
    ok = isequal(cachedList, fileList);         % 파일 목록이 같아야 유효
end
