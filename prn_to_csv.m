function prn_to_csv(rootDir, outDir, overwrite, quiet)
% PRN_TO_CSV Convert dielectric .prn files to .csv recursively.
%
% Usage
%   prn_to_csv                 % search under ./expdata and convert in-place
%   prn_to_csv(rootDir)        % search under rootDir and convert in-place
%   prn_to_csv(rootDir, outDir)% mirror folder tree into outDir and write CSVs
%   prn_to_csv(rootDir, outDir, overwrite) % overwrite existing CSVs if true
%
% Notes
% - Expects tab-delimited .prn with header: frequency, e', e''
% - Writes CSV with header: frequency,e_real,e_imag
% - Keeps folder structure; prints a concise progress log.
%
% Example
%   prn_to_csv(fullfile(pwd,'expdata','2025-08-29 - dielectric const'))

if nargin < 1 || isempty(rootDir)
    % Default to expdata if present, else current folder
    cand = fullfile(pwd, 'expdata');
    if isfolder(cand)
        rootDir = cand;
    else
        rootDir = pwd;
    end
end
if nargin < 2
    outDir = '';
end
if nargin < 3 || isempty(overwrite)
    overwrite = false;
end
if nargin < 4 || isempty(quiet)
    quiet = false; % when true, do not emit warnings with backtraces
end

if ~isfolder(rootDir)
    error('Root directory does not exist: %s', rootDir);
end

prnFiles = dir(fullfile(rootDir, '**', '*.prn'));
fprintf('Found %d PRN files under: %s\n', numel(prnFiles), rootDir);

for k = 1:numel(prnFiles)
    inPath = fullfile(prnFiles(k).folder, prnFiles(k).name);

    % Determine CSV output path
    if isempty(outDir)
        outFolder = prnFiles(k).folder;
    else
        % Mirror relative path under outDir
        relFolder = erase(prnFiles(k).folder, [rootDir filesep]);
        if startsWith(relFolder, filesep)
            relFolder = relFolder(2:end);
        end
        outFolder = fullfile(outDir, relFolder);
        if ~isfolder(outFolder)
            mkdir(outFolder);
        end
    end
    [~, base, ~] = fileparts(prnFiles(k).name);
    outPath = fullfile(outFolder, [base '.csv']);

    if exist(outPath, 'file') && ~overwrite
        fprintf('[%4d/%4d] Skip existing: %s\n', k, numel(prnFiles), outPath);
        continue;
    end

    % Read PRN as tab-delimited text, standardize variable names
    try
        opts = detectImportOptions(inPath, 'FileType','text');
        opts.Delimiter = {'\t'};
        try
            opts.VariableNamingRule = 'preserve';
        catch
            % older MATLAB versions may not support VariableNamingRule
        end
        opts = setvaropts(opts, opts.VariableNames, 'WhitespaceRule','preserve');
        T = readtable(inPath, opts);
    catch ME
        if quiet
            fprintf('[%4d/%4d] Skip unreadable PRN: %s (%s)\n', k, numel(prnFiles), inPath, ME.message);
        else
            warning('Failed to read PRN: %s (%s)', inPath, ME.message);
        end
        continue;
    end

    % Coerce to expected 3 columns, rename to friendly headers
    if width(T) < 3
        if quiet
            fprintf('[%4d/%4d] Skip PRN (unexpected <3 cols): %s\n', k, numel(prnFiles), inPath);
        else
            warning('Unexpected column count (<3): %s', inPath);
        end
        continue;
    end
    T = T(:,1:3);
    T.Properties.VariableNames = {'frequency','e_real','e_imag'};

    % Write CSV
    try
        writetable(T, outPath);
        fprintf('[%4d/%4d] Wrote: %s\n', k, numel(prnFiles), outPath);
    catch ME
        if quiet
            fprintf('[%4d/%4d] Failed to write CSV: %s (%s)\n', k, numel(prnFiles), outPath, ME.message);
        else
            warning('Failed to write CSV: %s (%s)', outPath, ME.message);
        end
    end
end

fprintf('Done.\n');
