function plottemperature2_run(varargin)
% PLOTTEMPERATURE2_RUN Wrapper to run plottemperature2.m with arguments.
%
% Usage
%   plottemperature2_run
%   plottemperature2_run('FreqGHz', 24)
%   plottemperature2_run('FreqGHz', 23.8:0.05:24.2, 'TempYLim', [0 5])
%   plottemperature2_run('SParamYLim', [-30 10], 'SParamTransYLim', [-80 0])
%   plottemperature2_run('FontScale', 3)
%   plottemperature2_run('RefreshCache', true)
%
% Parameters (Name-Value)
%   'FreqGHz'          : Scalar or vector of GHz frequencies to plot (overrides script default)
%   'TempYLim'         : [ymin ymax] for temperature y-axis, or 'auto'
%   'SParamYLim'       : [ymin ymax] for S11/S22 magnitude axis, or 'auto'
%   'SParamTransYLim'  : [ymin ymax] for S21/S12 magnitude axis, or 'auto'
%   'FontScale'        : Multiplier for default axes/text/legend font sizes (default 3)
%
% Notes
% - Runs plottemperature2.m in this function workspace so variables we set
%   here (e.g., frequencies_to_plot_GHz, temp_y_lim, etc.) are visible.
% - FontScale is applied via groot defaults and restored after run.

ip = inputParser;
ip.addParameter('FreqGHz', [], @(x)isnumeric(x)&&~isempty(x));
ip.addParameter('TempYLim', 'auto', @(x)(ischar(x)||isstring(x)) || (isnumeric(x)&&numel(x)==2));
ip.addParameter('SParamYLim', 'auto', @(x)(ischar(x)||isstring(x)) || (isnumeric(x)&&numel(x)==2));
ip.addParameter('SParamTransYLim', 'auto', @(x)(ischar(x)||isstring(x)) || (isnumeric(x)&&numel(x)==2));
ip.addParameter('FontScale', 3, @(x)isnumeric(x)&&isscalar(x)&&x>0);
ip.addParameter('RefreshCache', false, @(x)islogical(x)||ismember(x,[0 1]));
ip.parse(varargin{:});
opt = ip.Results;

% Inject variables expected by plottemperature2.m
if ~isempty(opt.FreqGHz)
    frequencies_to_plot_GHz = opt.FreqGHz; %#ok<NASGU>
end
temp_y_lim = opt.TempYLim; %#ok<NASGU>
sparam_y_lim = opt.SParamYLim; %#ok<NASGU>
sparam_S21_S12_y_lim = opt.SParamTransYLim; %#ok<NASGU>
refresh_sparam_cache = logical(opt.RefreshCache); %#ok<NASGU>

% Prepare font scaling (global defaults)
gr = groot;
prevAxesFS = get(gr, 'defaultAxesFontSize');
prevTextFS = get(gr, 'defaultTextFontSize');
prevLegendFS = get(gr, 'defaultLegendFontSize');
try
    base = 10;
    if ~isempty(prevAxesFS) && isnumeric(prevAxesFS), base = prevAxesFS; end
    newFS = max(12, round(base * opt.FontScale));
    set(gr, 'defaultAxesFontSize', newFS);
    set(gr, 'defaultTextFontSize', newFS);
    set(gr, 'defaultLegendFontSize', max(10, round(newFS*0.9)));
catch
end

try
    run('plottemperature2.m');
catch ME
    % Restore defaults before rethrow
    try
        set(gr, 'defaultAxesFontSize', prevAxesFS);
        set(gr, 'defaultTextFontSize', prevTextFS);
        set(gr, 'defaultLegendFontSize', prevLegendFS);
    catch
    end
    rethrow(ME);
end

% Restore defaults after run
try
    set(gr, 'defaultAxesFontSize', prevAxesFS);
    set(gr, 'defaultTextFontSize', prevTextFS);
    set(gr, 'defaultLegendFontSize', prevLegendFS);
catch
end

end
