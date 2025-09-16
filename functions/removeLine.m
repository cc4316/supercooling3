function removeLine(f, n)
% delets the nth line from a text file

f = string(f);
for zz = 1:numel(f)                     % for all files
    temp = f(zz);
    fid = fopen(temp,'r');              % opens file
    LL = 1;
    while ~feof(fid)                    % while not the end of the file
        line{LL} = fgetl(fid);          % reads all files line by line
        LL =LL+1;
    end
    fclose(fid);                        % closes the file

    line (n) = [];                      % removes the nth line

    fid = fopen(temp, "w+");            % overwrites the original file
    fprintf(fid, '%s\n', line{:});      
    fclose(fid);
end