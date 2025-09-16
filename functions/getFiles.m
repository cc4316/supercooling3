function fName = getFiles(folder, ext)
% returns all files in a folder having and extention EXT

folder = string(folder);                                    % formats input
ext = string(ext);

assert(isfolder(folder));                                   % make sure the folder actually exist
files = dir(folder);                                        % reads all files in the folder
fNum = numel(files);                                        % gets number of total files 

pattern = "." + alphanumericsPattern;                       % search pattern ".EXT"
if ~matches(ext, pattern)                                   % if doesnt match assume missing dot
    ext = "." + ext;                                        % is missing add the dot
end

fName = strings(1,fNum);                                    % prelocates variables
temp  = strings(1,fNum);        

for ii = 1: numel(files)                                    % for all files
    fName(ii) = fullfile(folder, string(files(ii).name));   % assemble full path
    [~, ~, temp(ii)] = fileparts(fName(ii));                % extract the file extention
end
index = ~matches(temp,ext,"IgnoreCase",true);               % matches the file extention to the pattern ".EXT"

fName(index) = [];                                          % if no match delte that entry