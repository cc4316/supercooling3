function run_dielectric_pipeline(rootDir, freqList, varargin)
% RUN_DIELECTRIC_PIPELINE Convert PRN→CSV, save MAT, and plot over time.
%
% Usage
%   run_dielectric_pipeline                                  % auto-detect folder, 24 GHz
%   run_dielectric_pipeline(rootDir)                         % default 24 GHz
%   run_dielectric_pipeline(rootDir, [8e9 10e9 24e9])        % multiple freqs
%   run_dielectric_pipeline(..., 'SaveFigs', true)           % save PNG + FIG in each sample
%   run_dielectric_pipeline(..., 'SmoothN', 5)               % smooth e'/e'' time series
%   run_dielectric_pipeline(..., 'TempChannel', 'mean')      % temp overlay is average
%   run_dielectric_pipeline(..., 'AskFreq', true)            % interactively choose freqs (GHz)
%
% Name-Value options
%   'SaveFigs'   (false)  Save figures to PNG and MATLAB FIG within each sample folder
%   'SmoothN'    (0)      Moving average window for e'/e''
%   'TempCsv'    ('')     Path to Temp.csv (auto-detects at root if empty)
%   'TempChannel'(1)      Channel idx (2..end) or 'mean' or header name
%   'UseCSV'     (true)   Prefer CSVs (will still work with PRNs if none)
%
if nargin < 1 || isempty(rootDir)
    cand = fullfile(pwd, 'expdata', '2025-08-29 - dielectric const');
    if isfolder(cand)
        rootDir = cand;
    else
        % fall back to expdata or pwd
        cand2 = fullfile(pwd, 'expdata');
        if isfolder(cand2)
            rootDir = cand2;
        else
            rootDir = pwd;
        end
    end
end
if nargin < 2 || isempty(freqList)
    freqList = 24e9; % default 24 GHz
end

ip = inputParser;
ip.addParameter('SaveFigs', false, @(x)islogical(x)&&isscalar(x));
ip.addParameter('SmoothN', 0, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
ip.addParameter('TempCsv', '', @(x)ischar(x)||isstring(x));
ip.addParameter('TempChannel', 9:12, @(x)(isnumeric(x)&&isvector(x)) || ischar(x) || isstring(x));
ip.addParameter('UseCSV', true, @(x)islogical(x)&&isscalar(x));
ip.addParameter('ForceConvert', false, @(x)islogical(x)&&isscalar(x));
ip.addParameter('TempYMax', [], @(x)(isnumeric(x)&&isscalar(x)) || isempty(x));
ip.addParameter('AskFreq', false, @(x)islogical(x)&&isscalar(x));
ip.parse(varargin{:});
opt = ip.Results;

% Optional interactive frequency selection (GHz prompt, stored in Hz)
if opt.AskFreq
    try
        curGHz = freqList(:)'/1e9;
        curGHz = curGHz(~isnan(curGHz) & isfinite(curGHz));
        if isempty(curGHz)
            curGHz = 24;
        end
        newGHz = local_select_freqs(curGHz);
        if ~isempty(newGHz)
            freqList = newGHz(:)' * 1e9;
        end
    catch ME
        fprintf('주파수 선택 입력을 건너뜁니다: %s\n', ME.message);
    end
end

rootDir = string(rootDir);
if ~isfolder(rootDir)
    error('Root directory not found: %s', rootDir);
end

% Step 1: will ensure PRN→CSV per sample below

% Auto-detect Temp.csv at root if not provided
tempCsv = string(opt.TempCsv);
if strlength(tempCsv)==0
    tpath = fullfile(rootDir, 'Temp.csv');
    if isfile(tpath)
        tempCsv = tpath;
    else
        tempCsv = '';
    end
end

% Find candidate sample subfolders (contain prn/csv files)
entries = dir(rootDir);
entries = entries([entries.isdir]);
sampleDirs = strings(0,1);
for i = 1:numel(entries)
    nm = entries(i).name;
    if any(strcmp(nm,{'.','..'})), continue; end
    sub = string(fullfile(entries(i).folder, nm));
    hasData = ~isempty(dir(fullfile(sub, '*.csv'))) || ~isempty(dir(fullfile(sub, '*.prn')));
    if hasData
        sampleDirs(end+1,1) = sub; %#ok<AGROW>
    end
end
if isempty(sampleDirs)
    % Maybe files are directly under rootDir
    if ~isempty(dir(fullfile(rootDir, '*.csv'))) || ~isempty(dir(fullfile(rootDir, '*.prn')))
        sampleDirs = string(rootDir);
    end
end

% Step 1: Ensure CSVs per sample (convert only where needed or forced)
fprintf('--- Step 1/3: Checking PRN → CSV per sample ---\n');
for s = 1:numel(sampleDirs)
    ensure_csv_for_sample(sampleDirs(s), opt.ForceConvert);
end

% Step 2: Save CSV → MAT after ensuring CSVs
fprintf('--- Step 2/3: Saving CSV → MAT ---\n');
try
    csv_to_mat(rootDir);
catch ME
    warning(ME.identifier, '%s', ME.message);
end

fprintf('--- Step 3/3: Plotting time series ---\n');
for s = 1:numel(sampleDirs)
    sd = sampleDirs(s);
    [~, sname] = fileparts(sd);
    for f = 1:numel(freqList)
        fHz = freqList(f);
        ttl = sprintf('%s - e''/e'''' vs Time @ %.2f GHz', sname, fHz/1e9);
        args = {'UseCSV', opt.UseCSV, 'SmoothN', opt.SmoothN, 'Title', ttl};
        if ~isempty(opt.TempYMax)
            args = [args, {'TempYMax', opt.TempYMax}]; %#ok<AGROW>
        end
        if strlength(tempCsv) > 0
            args = [args, {'TempCsv', tempCsv, 'TempChannel', opt.TempChannel}]; %#ok<AGROW>
        end
        try
            if opt.SaveFigs
                pngName = sprintf('%s_%gGHz.png', sname, fHz/1e9);
                pngPath = fullfile(sd, pngName);
                figSavePath = fullfile(sd, sprintf('%s_%gGHz.fig', sname, fHz/1e9));
                args = [args, {'SaveFig', pngPath}]; %#ok<AGROW>
            end
            plot_permittivity_over_time(sd, fHz, args{:});
            if opt.SaveFigs
                try
                    savefig(gcf, figSavePath);
                catch ME
                    warning(ME.identifier, '%s', ME.message);
                end
            end
            fprintf('Plotted %s at %.2f GHz\n', sname, fHz/1e9);
        catch ME
            warning(ME.identifier, 'Plot failed for %s @ %.2f GHz: %s', sname, fHz/1e9, ME.message);
        end
    end
end

fprintf('Pipeline completed.\n');

end

function ensure_csv_for_sample(sampleDir, forceConvert)
% Check PRN files under sampleDir and convert only if needed or forced.
% Rebuild criteria:
%  - Missing CSV for any PRN
%  - CSV older than its PRN (stale)
%  - forceConvert = true
sampleDir = string(sampleDir);
prnFiles = dir(fullfile(sampleDir, '**', '*.prn'));
if isempty(prnFiles)
    fprintf('  [%s] No PRN found.\n', sampleDir);
    return;
end

function ghz = local_select_freqs(curGHz)
% 콘솔에서 주파수 선택 옵션을 보여주고 GHz 벡터를 반환합니다.
    fprintf('\n주파수 포인트 선택 옵션 (GHz):\n');
    % 현재값 요약
    fprintf('  [Enter] 그대로 사용 (현재: ');
    try
        if isscalar(curGHz)
            fprintf('%.3f GHz', curGHz);
        elseif numel(curGHz) <= 8
            fprintf('%s', strjoin(string(round(curGHz,3)), ', '));
        else
            fprintf('%.3f ... %.3f GHz (N=%d)', curGHz(1), curGHz(end), numel(curGHz));
        end
    catch
    end
    fprintf(')\n');
    fprintf('  1) 단일 포인트 입력 (예: 24)\n');
    fprintf('  2) 범위+간격 입력 (예: 24:0.1:24.5)\n');
    fprintf('  3) 여러 포인트 수동 입력 (예: 23.9, 24.0, 24.25)\n');
    s = input('주파수 선택 (Enter=유지): ', 's');
    ghz = curGHz(:)';
    if isempty(s)
        return;
    end
    s = strtrim(s);
    switch s
        case '1'
            v = input('GHz 값을 입력하세요 (예: 24): ');
            if isnumeric(v) && ~isempty(v)
                ghz = v(:)';
            end
        case '2'
            r = input('start:step:end 형식으로 입력 (예: 24:0.1:24.5): ', 's');
            if ~isempty(r)
                try
                    tmp = eval(['[', r, ']']); %#ok<EVLDIR>
                    ghz = tmp(:)';
                catch
                    fprintf('형식을 해석할 수 없습니다. 기존 설정을 유지합니다.\n');
                end
            end
        case '3'
            l = input('쉼표/공백 구분 리스트 (예: 23.9,24.0,24.25): ', 's');
            if ~isempty(l)
                parts = regexp(l, '[,\s]+', 'split');
                vv = str2double(parts);
                vv = vv(~isnan(vv));
                if ~isempty(vv)
                    ghz = vv(:)';
                else
                    fprintf('유효한 숫자를 찾지 못했습니다. 기존 설정을 유지합니다.\n');
                end
            end
        otherwise
            % 사용자가 직접 범위표현 입력 시도
            try
                tmp = eval(['[', s, ']']); %#ok<EVLDIR>
                if isnumeric(tmp) && ~isempty(tmp)
                    ghz = tmp(:)';
                end
            catch
                % 무시하고 유지
            end
    end
end
need = false; doOverwrite = false;
if ~forceConvert
    for k = 1:numel(prnFiles)
        [~, base] = fileparts(prnFiles(k).name);
        outPath = fullfile(prnFiles(k).folder, [base '.csv']);
        if ~isfile(outPath)
            need = true; doOverwrite = false; break;
        else
            % Check freshness: PRN newer than CSV?
            csvInfo = dir(outPath);
            if isempty(csvInfo)
                need = true; doOverwrite = false; break;
            end
            if prnFiles(k).datenum > csvInfo.datenum
                need = true; doOverwrite = true; % must overwrite stale csv
                % do not break; still scan to see if any missing; prefer overwrite if any stale
            end
        end
    end
else
    need = true; doOverwrite = true;
end
if need
    if doOverwrite
        fprintf('  [%s] Converting PRN → CSV (overwrite stale) ...\n', sampleDir);
    else
        fprintf('  [%s] Converting PRN → CSV ...\n', sampleDir);
    end
    try
        if doOverwrite
            prn_to_csv(sampleDir, '', true, true); % quiet
        else
            prn_to_csv(sampleDir, '', false, true); % quiet
        end
    catch ME
        warning('  [%s] prn_to_csv failed: %s', sampleDir, ME.message);
    end
else
    fprintf('  [%s] CSV up to date.\n', sampleDir);
end
end
