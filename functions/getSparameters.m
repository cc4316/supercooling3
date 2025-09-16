function sParams = getSparameters(files, fileFrom, fileTo)

    files = convertCharsToStrings(files);                                       % formats input
    fileNum = numel(files);                                                     % gets number of files
    
    
    % the function breaks if there is korean in the file.
    % by default on of the lines is the directory. In computers where the OS is
    % set to Korean the file path contains "...\괄리자\...". 
    for ii = fileFrom:fileTo                                                           % for each file
        temp = files(ii);
        try                                                                     % try to read the SnP file
            sParams(ii) = sparameters(temp);
        catch ME
            if ME.identifier == "rf:thirdparty:invalidCharacter"                % if it failes due to unknown character
                removeLine(temp, 4);                                            % deletes line number 4 in the file 
                sParams(ii) = sparameters(temp);                                % trys again to read the file
            end
        end
    end
end