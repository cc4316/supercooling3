function [need_regen, has_cache, reason] = needsSparamCacheRebuild(sparam_data_dir)
% need_regen, has_cache, reason = needsSparamCacheRebuild(dir)
% - Checks whether S-parameter cache (.mat) should be rebuilt.
% - Compares current .s2p list with cached processed_filenames and timestamps.
% - Supports both single cache file and chunked cache files.
%
% reason codes:
%   'no_cache'         : No cache files present
%   'no_list_in_cache' : Cache lacks processed_filenames
%   'list_mismatch'    : File list differs between s2p and cache
%   's2p_newer'        : Latest s2p mtime is newer than cache file(s)
%   'cache_ok'         : Cache appears up-to-date

    arguments
        sparam_data_dir (1,:) char
    end

    sparam_file_single = fullfile(sparam_data_dir, 'sparam_data.mat');
    chunk_files_struct = dir(fullfile(sparam_data_dir, 'sparam_data_part*.mat'));
    has_cache = isfile(sparam_file_single) || ~isempty(chunk_files_struct);

    if ~has_cache
        need_regen = true; reason = 'no_cache';
        return;
    end

    % Build s2p file list
    try
        s2p_list = getFiles(sparam_data_dir, 's2p');
    catch
        dtmp = dir(fullfile(sparam_data_dir, '*.s2p'));
        s2p_list = strings(1, numel(dtmp));
        for ii = 1:numel(dtmp)
            s2p_list(ii) = string(fullfile(dtmp(ii).folder, dtmp(ii).name));
        end
    end
    s2p_list = sort(s2p_list);

    % Read cached processed_filenames
    cached_list = strings(1,0);
    if ~isempty(chunk_files_struct)
        [~, order] = sort({chunk_files_struct.name});
        chunk_files_struct = chunk_files_struct(order);
        for ci = 1:numel(chunk_files_struct)
            cf = fullfile(chunk_files_struct(ci).folder, chunk_files_struct(ci).name);
            try
                S = load(cf, 'processed_filenames');
                if isfield(S, 'processed_filenames')
                    cached_list = [cached_list, string(S.processed_filenames)]; %#ok<AGROW>
                end
            catch
                % skip broken chunk
            end
        end
    elseif isfile(sparam_file_single)
        try
            S = load(sparam_file_single, 'processed_filenames');
            if isfield(S, 'processed_filenames')
                cached_list = string(S.processed_filenames);
            end
        catch
            % ignore
        end
    end

    cached_list = sort(unique(cached_list));

    if isempty(cached_list)
        need_regen = true; reason = 'no_list_in_cache';
        return;
    end

    if numel(cached_list) ~= numel(s2p_list) || any(cached_list ~= s2p_list)
        need_regen = true; reason = 'list_mismatch';
        return;
    end

    % Compare mtimes
    s2p_dirlist = dir(fullfile(sparam_data_dir, '*.s2p'));
    if ~isempty(s2p_dirlist)
        latest_s2p = max([s2p_dirlist.datenum]);
    else
        latest_s2p = -inf;
    end

    cache_files = chunk_files_struct;
    if isempty(cache_files) && isfile(sparam_file_single)
        cache_files = dir(sparam_file_single);
    end
    if ~isempty(cache_files)
        if numel(cache_files) > 1
            latest_cache = max([cache_files.datenum]);
        else
            latest_cache = cache_files.datenum;
        end
    else
        latest_cache = -inf;
    end

    if latest_s2p > latest_cache
        need_regen = true; reason = 's2p_newer';
    else
        need_regen = false; reason = 'cache_ok';
    end
end

