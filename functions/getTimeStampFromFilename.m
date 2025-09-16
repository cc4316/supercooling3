function [TS, time] = getTimeStampFromFilename(f)
% GETTIMESTAMPFROMFILENAME extracts timestamps from filenames with format:
% YYYY-MM-DD HH-MM-SS.s2p
%
% Input:
%   f - cell array of file paths or string array of file paths
%
% Output:
%   TS - datetime array of timestamps
%   time - duration array of elapsed times from the earliest timestamp

% Convert to string array if needed
f = string(f);

% Preallocate timestamp array
TS = NaT(1, numel(f));

% Define the format for parsing
filename_format = 'yyyy-MM-dd HH-mm-ss';

for i = 1:numel(f)
    % Extract the filename without extension
    [~, name, ~] = fileparts(f(i));
    
    try
        % Parse the datetime from the filename
        TS(i) = datetime(name, 'InputFormat', filename_format);
    catch
        warning('Could not parse timestamp from filename: %s', f(i));
        TS(i) = NaT;
    end
end

% Calculate elapsed time
if ~isempty(TS)
    valid_TS = TS(~isnat(TS));
    if ~isempty(valid_TS)
        tStart = min(valid_TS);
        time = TS - tStart;
    else
        time = duration(zeros(size(TS)));
    end
else
    time = [];
end

end