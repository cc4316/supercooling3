function cachespara(sparadir)
% cachespara builds S-parameter cache MAT files.
% - If the number of .s2p files > 5000, it saves chunked files with 4999
%   entries each as sparam_data_part###.mat.
% - Otherwise it saves a single file sparam_data.mat.

    save_filename_single = fullfile(sparadir, 'sparam_data.mat');
    chunk_pattern = 'sparam_data_part%03d.mat';
    chunk_size = 4999; % per user request

    % Gather file list
    all_filenames = getFiles(sparadir, 's2p');
    if isempty(all_filenames)
        fprintf('처리할 .s2p 파일이 없습니다.\n');
        return;
    end

    N = numel(all_filenames);
    fprintf('총 %d개 .s2p 파일을 감지했습니다.\n', N);

    if N > 5000
        % Chunked processing
        num_chunks = ceil(N / chunk_size);
        fprintf('파일이 5000개를 초과합니다. %d개 청크(각 %d개)로 저장합니다.\n', num_chunks, chunk_size);

        % 혼선을 방지하기 위해 기존 단일 캐시가 있으면 삭제
        if isfile(save_filename_single)
            try
                delete(save_filename_single);
                fprintf('기존 단일 캐시를 삭제했습니다: %s\n', save_filename_single);
            catch ME
                fprintf('[경고] 기존 단일 캐시 삭제 실패: %s\n', ME.message);
            end
        end

        for c = 1:num_chunks
            sIdx = (c-1)*chunk_size + 1;
            eIdx = min(c*chunk_size, N);
            chunk_files = all_filenames(sIdx:eIdx);

            [data, processed_filenames] = process_chunk(chunk_files);
            if isempty(fieldnames(data))
                fprintf('[경고] 청크 %d: 유효한 2포트 데이터가 없어 건너뜁니다.\n', c);
                continue;
            end

            chunk_file = fullfile(sparadir, sprintf(chunk_pattern, c));
            save(chunk_file, 'data', 'processed_filenames', '-v7.3');
            fprintf('청크 %d 저장 완료: %s (%d개)\n', c, chunk_file, numel(processed_filenames));
        end
    else
        % Single file processing (legacy behavior)
        % 혼선을 방지하기 위해 기존 청크 캐시가 있으면 먼저 삭제
        old_chunks = dir(fullfile(sparadir, sprintf('sparam_data_part*.mat')));
        if ~isempty(old_chunks)
            fprintf('기존 청크 캐시 %d개를 삭제합니다...\n', numel(old_chunks));
            for k = 1:numel(old_chunks)
                try
                    delete(fullfile(old_chunks(k).folder, old_chunks(k).name));
                catch ME
                    fprintf('[경고] 청크 삭제 실패: %s (%s)\n', old_chunks(k).name, ME.message);
                end
            end
        end
        [data, processed_filenames] = process_chunk(all_filenames);
        if isempty(fieldnames(data))
            fprintf('[경고] 유효한 2포트 데이터가 없습니다. 저장하지 않습니다.\n');
            return;
        end
        save(save_filename_single, 'data', 'processed_filenames', '-v7.3');
        fprintf('타임스탬프를 포함한 S-파라미터 데이터를 %s 에 저장했습니다.\n', save_filename_single);
    end
end

function [data, processed_filenames] = process_chunk(file_list)
% Helper: builds data struct for a subset of files, filters non-2-port

    data = struct();
    processed_filenames = strings(1,0);

    if isempty(file_list)
        return;
    end

    % Build sparameters for the chunk
    try
        sparams = getSparameters(file_list, 1, numel(file_list));
    catch ME
        fprintf('[오류] S-parameter 객체 생성 중 오류: %s\n', ME.message);
        rethrow(ME);
    end

    % Filter to 2-port only to avoid index errors
    try
        ports = arrayfun(@(s) size(s.Parameters,1), sparams);
    catch
        % Fallback if sparams is empty
        ports = zeros(1,0);
    end
    valid_idx = find(ports >= 2);
    if numel(valid_idx) < numel(file_list)
        fprintf('  경고: %d개 파일이 2포트가 아니어서 제외됩니다.\n', numel(file_list) - numel(valid_idx));
    end
    if isempty(valid_idx)
        return;
    end

    sparams = sparams(valid_idx);
    file_list = file_list(valid_idx);

    % Extract data
    data.Frequencies = sparams(1).Frequencies;
    [data.S11_dB, data.S11_phase] = getData(sparams, 1, 1);
    [data.S21_dB, data.S21_phase] = getData(sparams, 2, 1);
    [data.S12_dB, data.S12_phase] = getData(sparams, 1, 2);
    [data.S22_dB, data.S22_phase] = getData(sparams, 2, 2);
    [TS, ~] = getTimeStampFromFilename(file_list);

    % Sort by timestamps
    [TS_sorted, sort_idx] = sort(TS);
    data.S11_dB = data.S11_dB(:, sort_idx);
    data.S11_phase = data.S11_phase(:, sort_idx);
    data.S21_dB = data.S21_dB(:, sort_idx);
    data.S21_phase = data.S21_phase(:, sort_idx);
    data.S12_dB = data.S12_dB(:, sort_idx);
    data.S12_phase = data.S12_phase(:, sort_idx);
    data.S22_dB = data.S22_dB(:, sort_idx);
    data.S22_phase = data.S22_phase(:, sort_idx);
    data.Timestamps = TS_sorted;
    if ~isempty(TS_sorted)
        data.TimeElapsed = TS_sorted - min(TS_sorted);
    else
        data.TimeElapsed = TS_sorted;
    end
    processed_filenames = file_list(sort_idx);
end
