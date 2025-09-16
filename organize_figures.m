function organize_figures(rootDir, varargin)
% ORGANIZE_FIGURES Collect image files into a single folder.
%
% Usage
%   organize_figures                      % use pwd, move common image files → ./figures
%   organize_figures(rootDir)             % organize images under rootDir → rootDir/figures
%   organize_figures(rootDir, 'OutDir', outDir, 'Mode','flat','Action','move')
%
% Name-Value options
%   'OutDir'     : Output folder (default: fullfile(rootDir,'figures'))
%   'Extensions' : Cell/str array of extensions (default: {'.png','.jpg','.jpeg','.tif','.tiff','.bmp','.gif','.fig'})
%   'Mode'       : 'flat' (all files directly under OutDir) or 'mirror' (preserve relative subfolders). Default 'flat'.
%   'Action'     : 'move' (default) or 'copy'
%   'Overwrite'  : true/false (default false). When false, auto-uniquify filenames.
%
% Notes
% - Searches recursively under rootDir.
% - Creates OutDir if missing.
% - When Mode='mirror', the subfolder tree relative to rootDir is recreated under OutDir.

if nargin < 1 || isempty(rootDir)
    rootDir = pwd;
end
ip = inputParser;
ip.addParameter('OutDir', fullfile(rootDir, 'figures'), @(x)ischar(x)||isstring(x));
ip.addParameter('Extensions', {'.png','.jpg','.jpeg','.tif','.tiff','.bmp','.gif','.fig'}, @(x)iscell(x)||isstring(x));
ip.addParameter('Mode','flat', @(x)ischar(x)||isstring(x));
ip.addParameter('Action','move', @(x)ischar(x)||isstring(x));
ip.addParameter('Overwrite', false, @(x)islogical(x)&&isscalar(x));
ip.parse(varargin{:});
opt = ip.Results;

rootDir = string(rootDir);
outDir  = string(opt.OutDir);
exts    = lower(string(opt.Extensions));
mode    = lower(string(opt.Mode));
action  = lower(string(opt.Action));

if ~isfolder(rootDir)
    error('Root directory not found: %s', rootDir);
end
if ~isfolder(outDir)
    mkdir(outDir);
end

% Build file list for all extensions
files = struct('folder',{},'name',{},'datenum',{});
for i = 1:numel(exts)
    li = dir(fullfile(rootDir, '**', strcat('*', exts(i))));
    % Filter out files that are already inside OutDir
    li = li(~startsWith(string(fullfile({li.folder},{li.name}))', outDir));
    files = [files; li]; %#ok<AGROW>
end

if isempty(files)
    fprintf('No image files found under: %s\n', rootDir);
    return;
end

fprintf('Found %d image files. Organizing into: %s\n', numel(files), outDir);

count = 0; skipped = 0;
for k = 1:numel(files)
    src = fullfile(files(k).folder, files(k).name);
    % Determine target folder
    if mode == "mirror"
        rel = erase(string(files(k).folder), [rootDir filesep]);
        if startsWith(rel, filesep)
            rel = extractAfter(rel, 1);
        end
        tgtFolder = fullfile(outDir, rel);
        if ~isfolder(tgtFolder)
            mkdir(tgtFolder);
        end
    else
        tgtFolder = outDir;
    end
    tgt = fullfile(tgtFolder, files(k).name);

    % Handle overwrite / unique naming
    if exist(tgt, 'file') && ~opt.Overwrite
        tgt = uniquify_name(tgt);
    end

    try
        if action == "copy"
            copyfile(src, tgt);
        else
            movefile(src, tgt);
        end
        count = count + 1;
    catch ME
        warning('Failed to %s %s -> %s (%s)', action, src, tgt, ME.message);
        skipped = skipped + 1;
    end
end

fprintf('Done. %d files processed, %d skipped.\n', count, skipped);

end

function outPath = uniquify_name(inPath)
% Append numeric suffix if a file exists: name (1).ext, name (2).ext, ...
[folder, base, ext] = fileparts(inPath);
outPath = inPath;
idx = 1;
while exist(outPath, 'file')
    outPath = fullfile(folder, sprintf('%s (%d)%s', base, idx, ext));
    idx = idx + 1;
    if idx > 10000
        error('Too many name collisions for %s', inPath);
    end
end
end

