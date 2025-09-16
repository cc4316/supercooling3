function compare_water_debye_models(varargin)
% COMPARE_WATER_DEBYE_MODELS Compare ANSYS vs literature double-Debye water models
%
% Overlays water_debye_model_ansys (ANSYS parameterization, double Debye) and
% water_debye_model_literature (literature polynomial parameterization, double Debye)
% on the same axes for selected temperatures and frequency range.
%
% Usage
%   compare_water_debye_models
%   compare_water_debye_models('FreqRangeGHz',[0.1 100],'TempsC',[-20 0 25], 'GridN', 800, 'MarkerEvery', 100)
%
ip = inputParser;
ip.addParameter('FreqRangeGHz', [0.1 100], @(x)isnumeric(x)&&numel(x)==2&&x(1)>0&&x(2)>x(1));
ip.addParameter('TempsC', [-20 0 25], @(x)isnumeric(x)&&isvector(x));
ip.addParameter('GridN', 800, @(x)isnumeric(x)&&isscalar(x)&&x>=100);
ip.addParameter('MarkerEvery', 100, @(x)isnumeric(x)&&isscalar(x)&&x>=1);
ip.parse(varargin{:});
opt = ip.Results;

fGHz = linspace(opt.FreqRangeGHz(1), opt.FreqRangeGHz(2), opt.GridN);
fHz  = fGHz*1e9;
temps = opt.TempsC(:).';

% Compute models
eps_ansys = water_debye_model_ansys(temps, fHz);          % NF x NT (ANSYS)
eps_liter = water_debye_model_literature(temps, fHz);     % NF x NT (literature)

% Plot
figure('Name','Water: Single vs Double Debye','Color','w');
tiledlayout(3,1,'Padding','compact','TileSpacing','compact');

mkEvery = max(1, round(opt.MarkerEvery));

% Real part
ax1 = nexttile; hold(ax1,'on'); grid(ax1,'on'); box(ax1,'on');
for k=1:numel(temps)
    mk = local_pick_marker(k);
    p1 = plot(ax1, fGHz, real(eps_ansys(:,k)), 'LineWidth',1.6, 'LineStyle','-', ...
        'Marker', mk, 'MarkerIndices', 1:mkEvery:numel(fGHz), 'MarkerSize', 5, ...
        'DisplayName', sprintf('ANSYS: T=%g°C', temps(k)));
    c = get(p1,'Color');
    plot(ax1, fGHz, real(eps_liter(:,k)), 'LineWidth',1.6, 'LineStyle','--', ...
        'Color', c, 'DisplayName', sprintf('Literature: T=%g°C', temps(k)));
end
xline(ax1,24,'k--','HandleVisibility','off'); local_setTicks(ax1, opt.FreqRangeGHz);
xlabel(ax1,'Frequency (GHz)'); ylabel(ax1,'Re{\epsilon_r}'); title(ax1,'Real permittivity'); local_legend_by_name(ax1);

% Imag part (-Im)
ax2 = nexttile; hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');
for k=1:numel(temps)
    mk = local_pick_marker(k);
    p1 = plot(ax2, fGHz, -imag(eps_ansys(:,k)), 'LineWidth',1.6, 'LineStyle','-', ...
        'Marker', mk, 'MarkerIndices', 1:mkEvery:numel(fGHz), 'MarkerSize', 5, ...
        'DisplayName', sprintf('ANSYS: T=%g°C', temps(k)));
    c = get(p1,'Color');
    plot(ax2, fGHz, -imag(eps_liter(:,k)), 'LineWidth',1.6, 'LineStyle','--', ...
        'Color', c, 'DisplayName', sprintf('Literature: T=%g°C', temps(k)));
end
xline(ax2,24,'k--','HandleVisibility','off'); local_setTicks(ax2, opt.FreqRangeGHz);
xlabel(ax2,'Frequency (GHz)'); ylabel(ax2,'-Im{\epsilon_r}'); title(ax2,'Imag part (plotted as -Im)'); local_legend_by_name(ax2);

% Loss tangent
ax3 = nexttile; hold(ax3,'on'); grid(ax3,'on'); box(ax3,'on');
tanS = -imag(eps_ansys)./real(eps_ansys); tanS(~isfinite(tanS)) = NaN;
tanD = -imag(eps_liter)./real(eps_liter); tanD(~isfinite(tanD)) = NaN;
for k=1:numel(temps)
    mk = local_pick_marker(k);
    p1 = plot(ax3, fGHz, tanS(:,k), 'LineWidth',1.6, 'LineStyle','-', ...
        'Marker', mk, 'MarkerIndices', 1:mkEvery:numel(fGHz), 'MarkerSize', 5, ...
        'DisplayName', sprintf('ANSYS: T=%g°C', temps(k)));
    c = get(p1,'Color');
    plot(ax3, fGHz, tanD(:,k), 'LineWidth',1.6, 'LineStyle','--', ...
        'Color', c, 'DisplayName', sprintf('Literature: T=%g°C', temps(k)));
end
xline(ax3,24,'k--','HandleVisibility','off'); local_setTicks(ax3, opt.FreqRangeGHz);
xlabel(ax3,'Frequency (GHz)'); ylabel(ax3,'tan\delta'); title(ax3,'Loss tangent'); local_legend_by_name(ax3);

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

function local_legend_by_name(ax)
    h = findobj(ax, 'Type','line');
    h = flipud(h(:));
    names = get(h, 'DisplayName'); if ischar(names), names = {names}; end
    keep = ~cellfun(@isempty, names); h = h(keep); names = names(keep);
    if isempty(h), return; end
    [un, ia] = unique(names, 'stable');
    legend(ax, h(ia), un, 'Location','best');
end

function mk = local_pick_marker(k)
    markers = {'o','s','d','^','v','>','<','p','h','x','+'};
    mk = markers{mod(k-1, numel(markers)) + 1};
end
