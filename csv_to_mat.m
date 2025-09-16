function csv_to_mat(rootDir, varargin)
% CSV_TO_MAT Read converted CSVs and save MAT files.
%
% Usage
%   csv_to_mat                          % search under ./expdata, save per-folder combined.mat
%   csv_to_mat(rootDir)                 % search under rootDir, save per-folder combined.mat
%   csv_to_mat(rootDir, 'GroupByFolder', false, 'OutMat', 'all_data.mat')
%
% Parameters (Name-Value)
%   'GroupByFolder' (logical):
%       true  (default) -> save one MAT per folder containing CSVs as 'combined.mat'.
%       false           -> save a single MAT at 'OutMat'.
%   'OutMat' (string/char): Path to output MAT when GroupByFolder = false.
%
% Data format in MAT
%   Saves struct array 'data' with fields:
%       - filename: CSV file name
%       - folder:   CSV file folder
%       - f:        frequency (numeric column 1)
%       - e_real:   real part of permittivity (column 2)
%       - e_imag:   imaginary part (column 3)
%
% Example
%   csv_to_mat(fullfile(pwd,'expdata','2025-08-29 - dielectric const'))

if nargin < 1 || isempty(rootDir)
    cand = fullfile(pwd, 'expdata');
    if isfolder(cand)
        rootDir = cand;
    else
        rootDir = pwd;
    end
end

ip = inputParser;
ip.addParameter('GroupByFolder', true, @(x)islogical(x) && isscalar(x));
ip.addParameter('OutMat', fullfile(rootDir, 'dielectric_const_all.mat'), @(x)ischar(x) || isstring(x));
ip.parse(varargin{:});
groupBy = ip.Results.GroupByFolder;
outMat = string(ip.Results.OutMat);

if ~isfolder(rootDir)
    error('Root directory does not exist: %s', rootDir);
end

csvFiles = dir(fullfile(rootDir, '**', '*.csv'));
fprintf('Found %d CSV files under: %s\n', numel(csvFiles), rootDir);
if isempty(csvFiles)
    fprintf('No CSV files found. Did you run prn_to_csv first?\n');
    return;
end

if groupBy
    % Save one MAT per folder containing CSV files
    folders = unique(string({csvFiles.folder}))';
    for i = 1:numel(folders)
        thisFolder = folders(i);
        filesInFolder = csvFiles(strcmp(string({csvFiles.folder}), thisFolder));
        data = read_csv_group(filesInFolder);
        if isempty(data)
            continue;
        end
        outPath = fullfile(thisFolder, 'combined.mat');
        try
            save(outPath, 'data');
            fprintf('[%3d/%3d] Saved: %s (%d records)\n', i, numel(folders), outPath, numel(data));
        catch ME
            warning('Failed to save MAT: %s (%s)', outPath, ME.message);
        end
    end
else
    % Save a single MAT for all CSVs
    data = read_csv_group(csvFiles);
    try
        save(outMat, 'data');
        fprintf('Saved: %s (%d records)\n', outMat, numel(data));
    catch ME
        warning('Failed to save MAT: %s (%s)', outMat, ME.message);
    end
end

end % function csv_to_mat

function data = read_csv_group(files)
% Helper to read a list of CSV files into a struct array
data = struct('filename', {}, 'folder', {}, 'f', {}, 'e_real', {}, 'e_imag', {});
for k = 1:numel(files)
    p = fullfile(files(k).folder, files(k).name);
    try
        T = readtable(p, 'VariableNamingRule','preserve');
    catch ME
        warning('Failed to read CSV: %s (%s)', p, ME.message);
        continue;
    end
    if width(T) < 3
        warning('Unexpected column count (<3): %s', p);
        continue;
    end
    % Use first three columns as frequency, e_real, e_imag
    f = T{:,1};
    e_real = T{:,2};
    e_imag = T{:,3};
    % Ensure column vectors
    f = f(:); e_real = e_real(:); e_imag = e_imag(:);
    data(end+1) = struct( ...
        'filename', files(k).name, ...
        'folder',   files(k).folder, ...
        'f',        f, ...
        'e_real',   e_real, ...
        'e_imag',   e_imag); %#ok<AGROW>
end
end
