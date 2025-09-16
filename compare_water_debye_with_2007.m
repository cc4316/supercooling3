function compare_water_debye_with_2007(varargin)
% COMPARE_WATER_DEBYE_WITH_2007 Overlay retro-model data (2007 paper) with Debye model
%
% Reads expdata/water_permittivity_retro_model_2007.csv and plots:
%   1) Re{eps_r}(f) vs frequency
%   2) -Im{eps_r}(f) vs frequency (imag plotted positive)
%   3) Loss tangent tan(delta) = (-Im)/Re vs frequency
% Model curves (selected model) are drawn for each listed temperature,
% and measured points from the table are overlaid at the reported f_low / f_high.
%
% Usage
%   compare_water_debye_with_2007
%   compare_water_debye_with_2007('FreqRangeGHz',[0.5 3])
%
% Options (Name-Value)
%   'FreqRangeGHz'  : [fmin fmax] GHz for plotting (default [0.5 3])
%   'GridN'         : number of grid points for model curves (default 600)
%   'SaveFig'       : 자동 저장 여부 (기본 false)
%   'FigFormats'    : 저장 형식 셀배열 (기본 {'png'})
%   'OutDir'        : 저장 폴더(기본 './figures')

ip = inputParser;
ip.addParameter('FreqRangeGHz', [0.1 10], @(x)isnumeric(x)&&numel(x)==2&&x(1)>0&&x(2)>x(1));
ip.addParameter('GridN', 600, @(x)isnumeric(x)&&isscalar(x)&&x>10);
ip.addParameter('BertoniFreqGHz', 9.61, @(x)isnumeric(x)&&isscalar(x)&&x>0);
ip.addParameter('MarkerEvery', 100, @(x)isnumeric(x)&&isscalar(x)&&x>=1&&isfinite(x));
ip.addParameter('Model', 'literature', @(s)ischar(s)||isstring(s)); % 'ansys' or 'literature'
ip.addParameter('SaveFig', false, @(x)islogical(x)&&isscalar(x));
ip.addParameter('FigFormats', {'png'}, @(c) iscell(c) || isstring(c));
ip.addParameter('OutDir', fullfile(pwd,'figures'), @(s)ischar(s)||isstring(s));
ip.parse(varargin{:});
opt = ip.Results;

% Select theoretical model function
modelLower = lower(string(opt.Model));
switch modelLower
    case "ansys"
        modelFun = @water_debye_model_ansys;
        modelLabel = 'ANSYS';
    case "literature"
        modelFun = @water_debye_model_literature;
        modelLabel = 'Literature';
    otherwise
        error('Unknown Model option: %s (use ''ansys'' or ''literature'')', opt.Model);
end

csvPath = fullfile('expdata','water_permittivity_retro_model_2007.csv');
assert(isfile(csvPath), 'CSV not found: %s', csvPath);
T = readtable(csvPath, 'VariableNamingRule','preserve');
% Load Bertoni (1982) for temperature union and later overlays
B = table();
try
    B = readtable(fullfile('expdata','water_permittivity_bertoni_1982.csv'), 'VariableNamingRule','preserve');
catch
end

% Clean/normalize columns
reqCols = {'Temp_C','f_low_MHz','f_high_MHz','eps_low_real','eps_low_imag','eps_high_real','eps_high_imag'};
for i = 1:numel(reqCols)
    if ~ismember(reqCols{i}, T.Properties.VariableNames)
        T.(reqCols{i}) = NaN(height(T),1);
    end
end

% Prepare model frequencies and temperature list
tempsC = T.Temp_C(:).';
tempsC = tempsC(~isnan(tempsC));
if ~isempty(B) && ismember('Temp_C', B.Properties.VariableNames)
    tempsC = [tempsC, B.Temp_C(:).'];
end
tempsC = unique(tempsC, 'stable');
fGHz = linspace(opt.FreqRangeGHz(1), opt.FreqRangeGHz(2), opt.GridN);
fHz  = fGHz * 1e9;

% Compute model eps for all listed temperatures
try
    eps_model = modelFun(tempsC, fHz); % returns NF x NT
catch
    % Ensure function is on path
    addpath(pwd);
    eps_model = modelFun(tempsC, fHz);
end

% Track figures for optional saving
figs = gobjects(0);
fnames = strings(0);

% ================= Figure 1: 2007 retro-model vs Debye =================
f1 = figure('Name',sprintf('Water: 2007 retro-model vs Debye (%s)', modelLabel),'Color','w');
tiledlayout(3,1,'Padding','compact','TileSpacing','compact');

% Helper for ticks (plain numbers) and limits
setTicks = @(ax) local_setTicks(ax, opt.FreqRangeGHz);

% 1) Real part
ax1 = nexttile; hold(ax1,'on'); grid(ax1,'on'); box(ax1,'on');
lineH = gobjects(1,numel(tempsC));
mkEvery = max(1, round(opt.MarkerEvery)); % show marker every N samples
modelMS = 5;                % model line marker size
expMS   = 2.5 * modelMS;    % experimental data marker size (2.5x larger)
for k = 1:numel(tempsC)
    mk = local_pick_marker(k);
    lineH(k) = plot(ax1, fGHz, real(eps_model(:,k)), 'LineWidth', 1.6, 'LineStyle','-', ...
        'Marker', mk, 'MarkerIndices', 1:mkEvery:numel(fGHz), 'MarkerSize', modelMS, ...
        'DisplayName', sprintf('T = %g°C', tempsC(k)));
end
% overlay measured low/high points
for r = 1:height(T)
    Tc = T.Temp_C(r);
    if isnan(Tc), continue; end
    % color match with model line for the same temperature
    ci = find(abs(tempsC - Tc) < 1e-9, 1, 'first'); if isempty(ci), ci = 1; end
    ccol = get(lineH(ci), 'Color');
    % low
    if ~isnan(T.f_low_MHz(r)) && ~isnan(T.eps_low_real(r))
        plot(ax1, T.f_low_MHz(r)/1e3, T.eps_low_real(r), 'o', 'Color', ccol, 'MarkerFaceColor', ccol, 'MarkerSize', expMS, 'DisplayName','data-low');
    end
    % high
    if ~isnan(T.f_high_MHz(r)) && ~isnan(T.eps_high_real(r))
        plot(ax1, T.f_high_MHz(r)/1e3, T.eps_high_real(r), 's', 'Color', ccol, 'MarkerFaceColor', 'w', 'MarkerSize', expMS, 'DisplayName','data-high');
    end
end
xline(ax1, 24, 'k--', 'HandleVisibility','off');
setTicks(ax1); xlabel(ax1,'Frequency (GHz)'); ylabel(ax1,'Re\{\epsilon_r\}');
title(ax1,'Real permittivity vs frequency');
% make legend unique
local_legend_by_name(ax1);

% (Figure 1 contains only 2007 data and model)

% 2) Imag part plotted as -Im (positive)
ax2 = nexttile; hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');
for k = 1:numel(tempsC)
    mk = local_pick_marker(k);
    plot(ax2, fGHz, -imag(eps_model(:,k)), 'LineWidth', 1.6, 'LineStyle','-', ...
        'Marker', mk, 'MarkerIndices', 1:mkEvery:numel(fGHz), 'MarkerSize', modelMS, ...
        'DisplayName', sprintf('T = %g°C', tempsC(k)));
end
for r = 1:height(T)
    Tc = T.Temp_C(r);
    ci = find(abs(tempsC - Tc) < 1e-9, 1, 'first'); if isempty(ci), ci = 1; end
    ccol = get(lineH(ci), 'Color');
    % low
    if ~isnan(T.f_low_MHz(r)) && ~isnan(T.eps_low_imag(r))
        plot(ax2, T.f_low_MHz(r)/1e3, -T.eps_low_imag(r), 'o', 'Color', ccol, 'MarkerFaceColor', ccol, 'MarkerSize', expMS, 'DisplayName','data-low');
    end
    % high imag provided?
    if ~isnan(T.f_high_MHz(r)) && ~isnan(T.eps_high_imag(r))
        plot(ax2, T.f_high_MHz(r)/1e3, -T.eps_high_imag(r), 's', 'Color', ccol, 'MarkerFaceColor', 'w', 'MarkerSize', expMS, 'DisplayName','data-high');
    end
end
xline(ax2, 24, 'k--', 'HandleVisibility','off');
setTicks(ax2); xlabel(ax2,'Frequency (GHz)'); ylabel(ax2,'-Im\{\epsilon_r\}');
title(ax2,'Imaginary permittivity vs frequency (plotted as -Im)');
local_legend_by_name(ax2);

% Bertoni imag overlay at single frequency
% (Bertoni overlay removed from Figure 1)

% 3) Loss tangent tan(delta) = (-Im)/Re
ax3 = nexttile; hold(ax3,'on'); grid(ax3,'on'); box(ax3,'on');
tanloss = -imag(eps_model) ./ real(eps_model); tanloss(~isfinite(tanloss)) = NaN;
for k = 1:numel(tempsC)
    mk = local_pick_marker(k);
    plot(ax3, fGHz, tanloss(:,k), 'LineWidth', 1.6, 'LineStyle','-', ...
        'Marker', mk, 'MarkerIndices', 1:mkEvery:numel(fGHz), 'MarkerSize', modelMS, ...
        'DisplayName', sprintf('T = %g°C', tempsC(k)));
end
for r = 1:height(T)
    Tc = T.Temp_C(r);
    ci = find(abs(tempsC - Tc) < 1e-9, 1, 'first'); if isempty(ci), ci = 1; end
    col = get(lineH(ci), 'Color');
    % compute tanδ from available low point
    if ~isnan(T.f_low_MHz(r)) && ~isnan(T.eps_low_real(r)) && ~isnan(T.eps_low_imag(r))
        plot(ax3, T.f_low_MHz(r)/1e3, (-T.eps_low_imag(r))/T.eps_low_real(r), 'o', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', expMS, 'LineStyle','none', 'DisplayName','data-low');
    end
    if ~isnan(T.f_high_MHz(r)) && ~isnan(T.eps_high_real(r)) && ~isnan(T.eps_high_imag(r))
        plot(ax3, T.f_high_MHz(r)/1e3, (-T.eps_high_imag(r))/T.eps_high_real(r), 's', 'Color', col, 'MarkerFaceColor', 'w', 'MarkerSize', expMS, 'LineStyle','none', 'DisplayName','data-high');
    end
end
xline(ax3, 24, 'k--', 'HandleVisibility','off');
setTicks(ax3); xlabel(ax3,'Frequency (GHz)'); ylabel(ax3,'tan\delta');
title(ax3,'Loss tangent vs frequency (tan\delta = (-Im)/Re)');
local_legend_by_name(ax3);
figs(end+1) = f1; fnames(end+1) = "water_2007_vs_debye"; %#ok<AGROW>

% ================= Figure 2: Bertoni (1982) vs Debye =================
try
    csvB = fullfile('expdata','water_permittivity_bertoni_1982.csv');
    if exist(csvB, 'file')
        B2 = readtable(csvB, 'VariableNamingRule','preserve');
        tempsB = unique(B2.Temp_C(~isnan(B2.Temp_C)),'stable')';
        fGHzB = linspace(opt.FreqRangeGHz(1), opt.FreqRangeGHz(2), opt.GridN);
        fHzB  = fGHzB*1e9;
        epsB = modelFun(tempsB, fHzB);

        f2 = figure('Name',sprintf('Water: 1982 (Bertoni) vs Debye (%s)', modelLabel),'Color','w');
        tiledlayout(3,1,'Padding','compact','TileSpacing','compact');

        % Real
        ax1b = nexttile; hold(ax1b,'on'); grid(ax1b,'on'); box(ax1b,'on');
        lineHB = gobjects(1,numel(tempsB));
        mkEveryB = max(1, round(opt.MarkerEvery)); % show marker every N samples
        modelMSB = 5; expMSB = 2.5 * modelMSB;
        for k=1:numel(tempsB)
            mk = local_pick_marker(k);
            lineHB(k) = plot(ax1b, fGHzB, real(epsB(:,k)), 'LineWidth',1.6,'LineStyle','-', ...
                'Marker', mk, 'MarkerIndices', 1:mkEveryB:numel(fGHzB), 'MarkerSize', modelMSB, ...
                'DisplayName',sprintf('T = %g°C',tempsB(k)));
        end
        % overlay points at f_GHz (9.61)
        bx = B2.f_GHz; if ~ismember('f_GHz', B2.Properties.VariableNames), bx = repmat(opt.BertoniFreqGHz, height(B2),1); end
        for r=1:height(B2)
            Tc = B2.Temp_C(r); ci = find(abs(tempsB - Tc) < 1e-9, 1,'first'); if isempty(ci), ci=1; end
            col = get(lineHB(ci), 'Color');
            if ~isnan(B2.eps_real(r))
                if ismember('eps_real_err', B2.Properties.VariableNames) && ~isnan(B2.eps_real_err(r))
                    e = B2.eps_real_err(r); if isnan(e), e=0; end
                    errorbar(ax1b, bx(r), B2.eps_real(r), e, 'Color', col, 'LineStyle','none', 'DisplayName','data-real');
                end
                plot(ax1b, bx(r), B2.eps_real(r), 'v', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', expMSB, 'LineStyle','none', 'DisplayName','data-real');
            end
        end
        xline(ax1b, 24,'k--','HandleVisibility','off'); local_setTicks(ax1b, opt.FreqRangeGHz);
        xlabel(ax1b,'Frequency (GHz)'); ylabel(ax1b,'Re{\epsilon_r}'); title(ax1b,'Real permittivity vs frequency'); local_legend_by_name(ax1b);

        % Imag (-Im)
        ax2b = nexttile; hold(ax2b,'on'); grid(ax2b,'on'); box(ax2b,'on');
        for k=1:numel(tempsB)
            mk = local_pick_marker(k);
            plot(ax2b, fGHzB, -imag(epsB(:,k)), 'LineWidth',1.6,'LineStyle','-', ...
                'Marker', mk, 'MarkerIndices', 1:mkEveryB:numel(fGHzB), 'MarkerSize', modelMSB, ...
                'DisplayName',sprintf('T = %g°C',tempsB(k)));
        end
        for r=1:height(B2)
            Tc = B2.Temp_C(r); ci = find(abs(tempsB - Tc) < 1e-9, 1,'first'); if isempty(ci), ci=1; end
            col = get(lineHB(ci), 'Color');
            if ~isnan(B2.eps_imag(r))
                if ismember('eps_imag_err', B2.Properties.VariableNames) && ~isnan(B2.eps_imag_err(r))
                    e = B2.eps_imag_err(r); if isnan(e), e=0; end
                    errorbar(ax2b, bx(r), -B2.eps_imag(r), e, 'Color', col, 'LineStyle','none', 'DisplayName','data-imag');
                end
                plot(ax2b, bx(r), -B2.eps_imag(r), '^', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', expMSB, 'LineStyle','none', 'DisplayName','data-imag');
            end
        end
        xline(ax2b, 24,'k--','HandleVisibility','off'); local_setTicks(ax2b, opt.FreqRangeGHz);
        xlabel(ax2b,'Frequency (GHz)'); ylabel(ax2b,'-Im{\epsilon_r}'); title(ax2b,'Imag part vs frequency'); local_legend_by_name(ax2b);

        % Tan delta
        ax3b = nexttile; hold(ax3b,'on'); grid(ax3b,'on'); box(ax3b,'on');
        tanB = -imag(epsB) ./ real(epsB); tanB(~isfinite(tanB)) = NaN;
        for k=1:numel(tempsB)
            mk = local_pick_marker(k);
            plot(ax3b, fGHzB, tanB(:,k), 'LineWidth',1.6,'LineStyle','-', ...
                'Marker', mk, 'MarkerIndices', 1:mkEveryB:numel(fGHzB), 'MarkerSize', modelMSB, ...
                'DisplayName',sprintf('T = %g°C',tempsB(k)));
        end
        for r=1:height(B2)
            Tc = B2.Temp_C(r); ci = find(abs(tempsB - Tc) < 1e-9, 1,'first'); if isempty(ci), ci=1; end
            col = get(lineHB(ci), 'Color');
            if ~isnan(B2.eps_real(r)) && ~isnan(B2.eps_imag(r))
                val = (-B2.eps_imag(r))/B2.eps_real(r); if isfinite(val)
                    plot(ax3b, bx(r), val, 'p', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', expMSB, 'LineStyle','none', 'DisplayName','data-tan');
                end
            end
        end
        xline(ax3b, 24,'k--','HandleVisibility','off'); local_setTicks(ax3b, opt.FreqRangeGHz);
        xlabel(ax3b,'Frequency (GHz)'); ylabel(ax3b,'tan\delta'); title(ax3b,'Loss tangent vs frequency'); local_legend_by_name(ax3b);
        figs(end+1) = f2; fnames(end+1) = "water_1982_vs_debye"; %#ok<AGROW>
    end
catch ME
    fprintf('Bertoni(1982) figure 생성 실패: %s\n', ME.message);
end

% ================= Figure 3: 1991 dataset vs Debye =================
try
    csvC = fullfile('expdata','water_permittivity_1991.csv');
    if exist(csvC, 'file')
        C = readtable(csvC, 'VariableNamingRule','preserve');
        % Expected columns: f (GHz), T (°C), ε', ε''
        tempsC91 = unique(C.T(~isnan(C.T)),'stable')';
        fGHzC = linspace(opt.FreqRangeGHz(1), opt.FreqRangeGHz(2), opt.GridN);
        fHzC  = fGHzC*1e9;
        epsC = modelFun(tempsC91, fHzC);

        f3 = figure('Name',sprintf('Water: 1991 vs Debye (%s)', modelLabel),'Color','w');
        tiledlayout(3,1,'Padding','compact','TileSpacing','compact');

        % Real
        ax1c = nexttile; hold(ax1c,'on'); grid(ax1c,'on'); box(ax1c,'on');
        lineHC = gobjects(1,numel(tempsC91));
        mkEveryC = max(1, round(opt.MarkerEvery)); % show marker every N samples
        modelMSC = 5; expMSC = 2.5 * modelMSC;
        for k=1:numel(tempsC91)
            mk = local_pick_marker(k);
            lineHC(k) = plot(ax1c, fGHzC, real(epsC(:,k)), 'LineWidth',1.6,'LineStyle','-', ...
                'Marker', mk, 'MarkerIndices', 1:mkEveryC:numel(fGHzC), 'MarkerSize', modelMSC, ...
                'DisplayName',sprintf('T = %g°C',tempsC91(k)));
        end
        for r=1:height(C)
            Tc = C.T(r); ci = find(abs(tempsC91 - Tc) < 1e-9, 1,'first'); if isempty(ci), ci=1; end
            col = get(lineHC(ci), 'Color');
            plot(ax1c, C.f(r), C.("ε'")(r), 'o', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', expMSC, 'LineStyle','none', 'DisplayName','data-real');
        end
        xline(ax1c, 24,'k--','HandleVisibility','off'); local_setTicks(ax1c, opt.FreqRangeGHz);
        xlabel(ax1c,'Frequency (GHz)'); ylabel(ax1c,'Re{\epsilon_r}'); title(ax1c,'Real permittivity vs frequency'); local_legend_by_name(ax1c);

        % Imag (-Im)
        ax2c = nexttile; hold(ax2c,'on'); grid(ax2c,'on'); box(ax2c,'on');
        for k=1:numel(tempsC91)
            mk = local_pick_marker(k);
            plot(ax2c, fGHzC, -imag(epsC(:,k)), 'LineWidth',1.6,'LineStyle','-', ...
                'Marker', mk, 'MarkerIndices', 1:mkEveryC:numel(fGHzC), 'MarkerSize', modelMSC, ...
                'DisplayName',sprintf('T = %g°C',tempsC91(k)));
        end
        for r=1:height(C)
            Tc = C.T(r); ci = find(abs(tempsC91 - Tc) < 1e-9, 1,'first'); if isempty(ci), ci=1; end
            col = get(lineHC(ci), 'Color');
            plot(ax2c, C.f(r), -C.("ε''")(r), '^', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', expMSC, 'LineStyle','none', 'DisplayName','data-imag');
        end
        xline(ax2c, 24,'k--','HandleVisibility','off'); local_setTicks(ax2c, opt.FreqRangeGHz);
        xlabel(ax2c,'Frequency (GHz)'); ylabel(ax2c,'-Im{\epsilon_r}'); title(ax2c,'Imag part vs frequency'); local_legend_by_name(ax2c);

        % Tan delta
        ax3c = nexttile; hold(ax3c,'on'); grid(ax3c,'on'); box(ax3c,'on');
        tanC = -imag(epsC) ./ real(epsC); tanC(~isfinite(tanC)) = NaN;
        for k=1:numel(tempsC91)
            mk = local_pick_marker(k);
            plot(ax3c, fGHzC, tanC(:,k), 'LineWidth',1.6,'LineStyle','-', ...
                'Marker', mk, 'MarkerIndices', 1:mkEveryC:numel(fGHzC), 'MarkerSize', modelMSC, ...
                'DisplayName',sprintf('T = %g°C',tempsC91(k)));
        end
        for r=1:height(C)
            Tc = C.T(r); ci = find(abs(tempsC91 - Tc) < 1e-9, 1,'first'); if isempty(ci), ci=1; end
            col = get(lineHC(ci), 'Color');
            val = (-C.("ε''")(r)) / C.("ε'")(r); if isfinite(val)
                plot(ax3c, C.f(r), val, 'p', 'Color', col, 'MarkerFaceColor', col, 'MarkerSize', expMSC, 'LineStyle','none', 'DisplayName','data-tan');
        end
        end
        xline(ax3c, 24,'k--','HandleVisibility','off'); local_setTicks(ax3c, opt.FreqRangeGHz);
        xlabel(ax3c,'Frequency (GHz)'); ylabel(ax3c,'tan\delta'); title(ax3c,'Loss tangent vs frequency'); local_legend_by_name(ax3c);
        figs(end+1) = f3; fnames(end+1) = "water_1991_vs_debye"; %#ok<AGROW>
    end
catch ME
    fprintf('1991 figure 생성 실패: %s\n', ME.message);
end

% Optional autosave of all figures
if opt.SaveFig && ~isempty(fnames)
    try
        outDir = char(opt.OutDir);
        if exist(outDir,'dir') ~= 7, mkdir(outDir); end
        fmts = cellstr(opt.FigFormats);
        for i = 1:numel(fnames)
            if ~isgraphics(figs(i))
                continue; % safeguard
            end
            base = fullfile(outDir, char(fnames(i)));
            for j = 1:numel(fmts)
                fmt = lower(fmts{j});
                switch fmt
                    case 'fig', savefig(figs(i), [base '.fig']);
                    case 'png', saveas(figs(i), [base '.png']);
                    case 'jpg', saveas(figs(i), [base '.jpg']);
                    case 'pdf', saveas(figs(i), [base '.pdf']);
                end
            end
        end
    catch ME
        warning('그림 자동 저장 실패: %s', ME.message);
    end
end

end

function local_legend_by_name(ax)
% Build legend ordering by temperature (high → low) for model lines.
% Non-temperature entries (e.g., data-low/high) are appended in stable order.
    hAll = flipud(findobj(ax, 'Type','line'));
    namesAll = get(hAll, 'DisplayName');
    if ischar(namesAll), namesAll = {namesAll}; end
    keep = ~cellfun(@isempty, namesAll);
    hAll = hAll(keep); namesAll = namesAll(keep);
    if isempty(hAll), return; end

    % Identify temperature-labeled entries like 'T = 25°C'
    isTemp = false(size(namesAll));
    temps = nan(size(namesAll));
    for i=1:numel(namesAll)
        tok = regexp(namesAll{i}, 'T\s*=\s*([-+]?\d*\.?\d+)\s*°C', 'tokens', 'once');
        if ~isempty(tok)
            isTemp(i) = true; temps(i) = str2double(tok{1});
        end
    end

    % Sort temperature entries high→low, keep others stable
    hTemp = hAll(isTemp); nTemp = namesAll(isTemp); tvals = temps(isTemp);
    hOther = hAll(~isTemp); nOther = namesAll(~isTemp);

    if ~isempty(hTemp)
        [~, ord] = sort(tvals, 'descend', 'MissingPlacement', 'last');
        hTemp = hTemp(ord); nTemp = nTemp(ord);
        % unique by name preserving our order
        [nTempU, iaT] = unique(nTemp, 'stable'); hTempU = hTemp(iaT);
    else
        nTempU = {}; hTempU = gobjects(0,1);
    end

    if ~isempty(hOther)
        [nOtherU, iaO] = unique(nOther, 'stable'); hOtherU = hOther(iaO);
    else
        nOtherU = {}; hOtherU = gobjects(0,1);
    end

    hLeg = [hTempU; hOtherU]; nLeg = [nTempU; nOtherU];
    if ~isempty(hLeg)
        legend(ax, hLeg, nLeg, 'Location','best');
    end
end

function local_setTicks(ax, frange)
    set(ax,'XScale','log');
    ticksAll = [0.1 0.2 0.5 1 2 5 10 20 50 100];
    ticks = ticksAll(ticksAll >= frange(1) & ticksAll <= frange(2));
    if isempty(ticks)
        ticks = [frange(1) frange(2)];
    end
    set(ax,'XTick',ticks,'XTickLabel',compose('%g',ticks));
    try, xlim(ax, frange); catch, end
end

function mk = local_pick_marker(k)
% Cycle a set of distinct markers to help disambiguate when colors repeat
    markers = {'o','s','d','^','v','>','<','p','h','x','+'};
    mk = markers{mod(k-1, numel(markers)) + 1};
end
