function [TS, time] = getTimeStamp2(f, n)
% GETTIMESTAMP2 gets the data stamp from the nth line of a file.

% Expected datetime formats
formats = {
    "M/d/yyyy h:mm:ss a",   % e.g., 4/23/2025 5:56:01 PM
    "M/d/yyyy HH:mm:ss"     % e.g., 4/23/2025 17:56:01
    };

f = string(f); % file names
TS = NaT(1, numel(f)); % Preallocate with Not-a-Time

for zz = 1:numel(f) % for each file
    temp = f(zz);
    fid = fopen(temp, 'r');
    if fid == -1
        warning('Cannot open file: %s', temp);
        continue;
    end
    
    line_cell = textscan(fid, '%s', 1, "HeaderLines", n - 1, 'Delimiter', '\n');
    fclose(fid);
    
    if isempty(line_cell{1})
        warning('Could not read line %d from file: %s', n, temp);
        continue;
    end
    
    line_str = line_cell{1}{1};
    
    % Clean up the line
    if startsWith(line_str, '!')
        line_str = strtrim(line_str(2:end));
    else
        line_str = strtrim(line_str);
    end
    
    % Try to parse the datetime using different formats
    parsed = false;
    for k = 1:length(formats)
        try
            dt = datetime(line_str, 'InputFormat', formats{k}, 'Locale', 'en_US');
            TS(zz) = dt;
            parsed = true;
            break;
        catch
            % Try next format
        end
    end
    
    if ~parsed
        warning('Failed to parse datetime from line: "%s" in file: %s', line_str, temp);
        % TS(zz) is already NaT
    end
end

if ~isempty(TS)
    % tStart = min(TS, 'omitnan'); % R2016b 이전 버전과 호환성 문제 발생 가능
    
    valid_TS = TS(~isnat(TS));
    if ~isempty(valid_TS)
        tStart = min(valid_TS);
    else
        tStart = NaT;
    end

    if ~isnat(tStart)
        time = TS - tStart;
    else
        time = duration(zeros(size(TS))); % Return zero duration if no valid times
    end
else
    time = [];
end

end 