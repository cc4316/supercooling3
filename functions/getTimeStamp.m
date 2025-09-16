% function [TS, time] = getTimeStamp(f,n)
% % gets the data stamp from the file
% 
% format = "M/d/yyyy h:mm:ss a";                                              % extected datetime format
% f = string(f);                                                              % file names
% for zz = 1:numel(f)                                                         % for each file
%     temp = f(zz);
%     fid = fopen(temp,'r');                                                  % reads the file
%     line = textscan(fid,'%s',1,"HeaderLines", n - 1, 'Delimiter', '\n');    % reads the nth line of the file
%     fclose(fid);                                                            % closes the file
%     line =  line{1}{1}(3:end);                                              % formats the input
%     TS(zz) = datetime(line, InputFormat=format);                            % converts to datetime
% end
% 
% tStart = min(TS);                                                           % gets the start time
% time = TS - tStart;                                                         % calculates the time increment

function [TS, time] = getTimeStamp(f,n)
    format = "M/d/yyyy hh:mm:ss a"; % Change h -> hh
    f = string(f);
    for zz = 1:numel(f)
        temp = f(zz);
        fid = fopen(temp,'r');
        line = textscan(fid,'%s',1,"HeaderLines", n - 1, 'Delimiter', '\n');
        fclose(fid);
        line = strtrim(line{1}{1}(3:end)); % Trim whitespace

        try
            TS(zz) = datetime(line, 'InputFormat', format, 'Locale', 'en_US');
        catch
            warning("Failed to parse datetime: %s", line);
            TS(zz) = NaT; % Assign NaT (Not-a-Time) if parsing fails
        end
    end

    tStart = min(TS);
    time = TS - tStart;
end
