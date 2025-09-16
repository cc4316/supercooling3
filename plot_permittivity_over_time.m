function out = plot_permittivity_over_time(sampleDir, freqHz, varargin)
% PLOT_PERMITTIVITY_OVER_TIME Plot e' and e'' vs time from sequential files.
%
% Usage
%   plot_permittivity_over_time(sampleDir, freqHz)
%   plot_permittivity_over_time(sampleDir, freqHz, Name, Value, ...)
%
% Required
%   sampleDir : Folder containing sequential dielectric files (.csv or .prn)
%   freqHz    : Target frequency in Hz to extract (nearest row used)
%
% Name-Value options
%   'UseCSV'          (true)  Prefer CSVs if present, else PRN
%   'FreqToleranceHz' (Inf)   Max distance to pick row; warn if exceeded
%   'UseFileTime'     (true)  Use file modification time for time axis
%   'TempCsv'         ('')    Path to Temp.csv to overlay as right axis
%   'TempChannel'     (1)     Column index in Temp.csv (2..17), or 'mean'
%   'SmoothN'         (0)     Moving average window (samples); 0 = no smooth
%   'SaveFig'         ('')    Path to save the figure (png, fig, etc.)
%   'Title'           ('')    Custom title; default is auto-generated
%   'TempYMax'        (5)     Max of right y-axis (temperature). Empty [] = auto
%
% Returns
%   out: struct with fields times (datetime), e_real, e_imag, freqUsed,
%        files (string array), tempTimes/tempVals (if TempCsv provided)

ip = inputParser;
ip.addParameter('UseCSV', true, @(x)islogical(x)&&isscalar(x));
ip.addParameter('FreqToleranceHz', inf, @(x)isnumeric(x)&&isscalar(x));
ip.addParameter('UseFileTime', true, @(x)islogical(x)&&isscalar(x));
ip.addParameter('TempCsv', '', @(x)ischar(x)||isstring(x));
ip.addParameter('TempChannel', 9:12, @(x)(isnumeric(x)&&isvector(x)) || (ischar(x)||isstring(x)) );
ip.addParameter('SmoothN', 0, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
ip.addParameter('SaveFig', '', @(x)ischar(x)||isstring(x));
ip.addParameter('Title', '', @(x)ischar(x)||isstring(x));
ip.addParameter('TempYMax', 5, @(x)(isnumeric(x)&&isscalar(x)) || isempty(x));
ip.parse(varargin{:});
opt = ip.Results;

if nargin < 2
    error('Provide sampleDir and freqHz.');
end
sampleDir = string(sampleDir);
if ~isfolder(sampleDir)
    error('Sample directory not found: %s', sampleDir);
end

% Pick file set: CSVs preferred then PRNs
csvList = dir(fullfile(sampleDir, '*.csv'));
prnList = dir(fullfile(sampleDir, '*.prn'));
useCsv = opt.UseCSV && ~isempty(csvList);
files = csvList;
if ~useCsv
    files = prnList;
end
if isempty(files)
    error('No input files (.csv or .prn) found in %s', sampleDir);
end

% Sort by numeric suffix in filename if present, else by datenum
names = string({files.name});
suffixNum = nan(size(names));
for i = 1:numel(names)
    m = regexp(names(i), '_(\d+)\.(csv|prn)$', 'tokens', 'once');
    if ~isempty(m)
        suffixNum(i) = str2double(m{1});
    end
end
if any(~isnan(suffixNum))
    [~, ord] = sort(suffixNum);
else
    [~, ord] = sort([files.datenum]);
end
files = files(ord);

% Time axis
if opt.UseFileTime
    times = datetime({files.date});
else
    % Use simple index if not using file time
    times = datetime(0,0,0) + seconds(0:numel(files)-1);
end

e_real = nan(numel(files),1);
e_imag = nan(numel(files),1);
freqUsed = nan(numel(files),1);
selIdx = nan(numel(files),1);

for k = 1:numel(files)
    p = fullfile(files(k).folder, files(k).name);
    try
        if useCsv
            T = readtable(p, 'VariableNamingRule','preserve');
            f = T{:,1};
            er = T{:,2};
            ei = T{:,3};
        else
            % PRN: tab-delimited with header
            opts = detectImportOptions(p, 'FileType','text');
            opts.Delimiter = {'\t'};
            try
                opts.VariableNamingRule = 'preserve';
            catch
            end
            U = readtable(p, opts);
            f = U{:,1};
            er = U{:,2};
            ei = U{:,3};
        end
        [dmin, idx] = min(abs(f - freqHz));
        if dmin > opt.FreqToleranceHz
            warning('File %s: nearest freq off by %.3g Hz (> tol %.3g).', files(k).name, dmin, opt.FreqToleranceHz);
        end
        e_real(k) = er(idx);
        e_imag(k) = ei(idx);
        freqUsed(k) = f(idx);
        selIdx(k) = idx;
    catch ME
        warning('Read failed for %s (%s)', p, ME.message);
    end
end

% Optional smoothing
if opt.SmoothN > 1
    e_real = movmean(e_real, opt.SmoothN, 'omitnan');
    e_imag = movmean(e_imag, opt.SmoothN, 'omitnan');
end

% Prepare temperature overlay if provided
tempTimes = [];
tempVals = [];
tempLabels = strings(0,1);
if ~isempty(opt.TempCsv)
    tpath = string(opt.TempCsv);
    if isfile(tpath)
        try
            TT = readtable(tpath, 'VariableNamingRule','preserve');
            % Expect Time column then channels
            tcol = TT{:,1};
            if iscellstr(tcol) || isstring(tcol)
                tempTimes = datetime(string(tcol));
            elseif isdatetime(tcol)
                tempTimes = tcol;
            else
                % numeric epoch? assume datenum
                tempTimes = datetime(tcol, 'ConvertFrom','datenum');
            end
            if ischar(opt.TempChannel) || isstring(opt.TempChannel)
                if strcmpi(string(opt.TempChannel),'mean')
                    tempVals = mean(TT{:,2:end}, 2, 'omitnan');
                    tempLabels = "Temp-mean";
                else
                    % try match header name
                    colName = string(opt.TempChannel);
                    if any(strcmp(TT.Properties.VariableNames, colName))
                        tempVals = TT.(colName);
                        tempLabels = colName;
                    else
                        warning('Temp channel name not found. Using Ch1.');
                        tempVals = TT{:,2};
                        tempLabels = "Ch1";
                    end
                end
            else
                chs = opt.TempChannel(:)';
                ncols = size(TT,2);
                idxs = max(2, min(ncols, 1 + chs));
                tmp = zeros(height(TT), numel(idxs));
                for j = 1:numel(idxs)
                    tmp(:,j) = TT{:, idxs(j)};
                end
                tempVals = tmp;
                tempLabels = arrayfun(@(c)sprintf('Ch%d', c), chs, 'UniformOutput', false);
                tempLabels = string(tempLabels);
            end
        catch ME
            warning('Failed reading Temp.csv: %s', ME.message);
        end
    else
        warning('TempCsv not found: %s', tpath);
    end
end

% Plot
figure('Color','w');
hold on;
% markers every 100 samples
mi_main = 1:max(1,round(numel(times)/ceil(numel(times)/100))):numel(times);
h1 = plot(times, e_real, '-o', 'DisplayName','e'' (real)', 'LineWidth', 1.6);
set(h1, 'MarkerIndices', mi_main);
h2 = plot(times, e_imag, '-s', 'DisplayName','e'''' (imag)', 'LineWidth', 1.6);
set(h2, 'MarkerIndices', mi_main);
hx = xlabel('Time'); hyL = ylabel('Permittivity'); grid on;

if ~isempty(tempTimes) && ~isempty(tempVals)
    yyaxis right; hold on;
    mi_temp = 1:max(1,round(numel(tempTimes)/ceil(numel(tempTimes)/100))):numel(tempTimes);
    if isvector(tempVals)
        ht = plot(tempTimes, tempVals, '-', 'DisplayName', tempLabels, 'LineWidth', 1.4, 'Marker','o');
        set(ht, 'MarkerIndices', mi_temp);
    else
        nCh = size(tempVals,2);
        cols = lines(nCh);
        lineStyles = {'-','--',':','-.'};
        markers = {'o','s','d','^','v','>','<','p','h','x','+'};
        for j = 1:nCh
            ls = lineStyles{mod(j-1, numel(lineStyles)) + 1};
            mk = markers{mod(j-1, numel(markers)) + 1};
            ht = plot(tempTimes, tempVals(:,j), 'LineStyle', ls, 'Marker', mk, ...
                'Color', cols(j,:), 'DisplayName', tempLabels(j), 'LineWidth', 1.4);
            set(ht, 'MarkerIndices', mi_temp);
        end
    end
    hyR = ylabel('Temperature');
    % Apply temperature y-axis maximum if requested
    if ~isempty(opt.TempYMax)
        yl = ylim;
        newMax = opt.TempYMax;
        newMin = yl(1);
        if newMin >= newMax
            newMin = 0;
        end
        ylim([newMin newMax]);
    end
end

% Title and legend
if strlength(string(opt.Title)) == 0
    [~, lastFolder] = fileparts(sampleDir);
    ttl = sprintf('%s — e''/e'''' vs Time @ %.2f GHz', lastFolder, freqHz/1e9);
else
    ttl = string(opt.Title);
end
% Restrict x-axis to the time span where dielectric data exists
validMask = ~isnan(e_real) | ~isnan(e_imag);
if any(validMask)
    tmin = min(times(validMask));
    tmax = max(times(validMask));
    try
        xlim([tmin tmax]);
    catch
        % In case older MATLAB has issues, ignore and keep auto
    end
end

ttlH = title(ttl);
LG = legend('Location','best');

% Scale all font sizes by 3x
ax = gca; baseFS = ax.FontSize; newFS = max(12, round(3*baseFS));
ax.FontSize = newFS;
set(hx, 'FontSize', newFS);
set(hyL, 'FontSize', newFS);
if exist('hyR','var'); set(hyR, 'FontSize', newFS); end
set(ttlH, 'FontSize', newFS*1.1);
set(LG, 'FontSize', max(10, round(newFS*0.9)));

% Save figure if requested
if ~isempty(opt.SaveFig)
    try
        exportgraphics(gcf, string(opt.SaveFig));
    catch
        try
            saveas(gcf, string(opt.SaveFig));
        catch ME
            warning('Failed to save figure: %s', ME.message);
        end
    end
end

% Output
out = struct('times', times(:), 'e_real', e_real(:), 'e_imag', e_imag(:), ...
             'freqUsed', freqUsed(:), 'files', string(fullfile({files.folder},{files.name}))');
if ~isempty(tempTimes)
    out.tempTimes = tempTimes(:);
    out.tempVals = tempVals(:);
end

end
