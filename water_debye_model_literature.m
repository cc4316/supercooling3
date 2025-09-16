function eps_r = water_debye_model_literature(T_C, f_Hz)
% WATER_DEBYE_MODEL_LITERATURE Complex relative permittivity of pure water via double Debye fit
%
% Implements a two-Debye relaxation model for pure water (S=0, sigma=0) with
% temperature-dependent parameters as described in the provided spec.
%
% Usage
%   eps_r = water_debye_model_literature(T_C, f_Hz)
%     - T_C  : temperature(s) in deg C (scalar or vector)
%     - f_Hz : frequency grid in Hz (vector)
%     - returns NF x NT complex matrix (frequency varies along rows)
%
%   water_debye_model_literature
%     - No-arg demo: plots Re, -Im, and tan(delta) across frequency for a
%       set of temperatures, with 24 GHz markers and numeric log ticks.
%
% Model form (pure water, sigma=0):
%   eps*(nu,T) = eps_inf(T)
%              + (eps_s(T) - eps_1(T)) / (1 + i*nu/nu1(T))
%              + (eps_1(T) - eps_inf(T)) / (1 + i*nu/nu2(T))
%   where nu = f [GHz] and the imaginary part is negative by convention.

if nargin == 0
    % Demo
    fGHz = logspace(-1, 2, 600); % 0.1..100 GHz
    fHz  = fGHz*1e9;
    Tlist = [-20 0 25];
    eps_demo = water_debye_model_literature(Tlist, fHz); % NF x NT
    figure('Name','Water double-Debye demo','Color','w');
    tiledlayout(3,1,'Padding','compact','TileSpacing','compact');
    % Re
    ax1 = nexttile; hold(ax1,'on'); grid(ax1,'on'); box(ax1,'on');
    for k=1:numel(Tlist)
        plot(ax1, fGHz, real(eps_demo(:,k)), 'LineWidth',1.6, 'DisplayName',sprintf('T = %g°C',Tlist(k)));
    end
    xline(ax1,24,'k--','HandleVisibility','off');
    local_setTicks(ax1, [min(fGHz) max(fGHz)]);
    xlabel(ax1,'Frequency (GHz)'); ylabel(ax1,'Re{\epsilon_r}'); title(ax1,'Real permittivity'); legend(ax1,'Location','best');
    % -Im
    ax2 = nexttile; hold(ax2,'on'); grid(ax2,'on'); box(ax2,'on');
    for k=1:numel(Tlist)
        plot(ax2, fGHz, -imag(eps_demo(:,k)), 'LineWidth',1.6, 'DisplayName',sprintf('T = %g°C',Tlist(k)));
    end
    xline(ax2,24,'k--','HandleVisibility','off');
    local_setTicks(ax2, [min(fGHz) max(fGHz)]);
    xlabel(ax2,'Frequency (GHz)'); ylabel(ax2,'-Im{\epsilon_r}'); title(ax2,'Imag part (plotted as -Im)'); legend(ax2,'Location','best');
    % tan delta
    ax3 = nexttile; hold(ax3,'on'); grid(ax3,'on'); box(ax3,'on');
    tanloss = -imag(eps_demo)./real(eps_demo); tanloss(~isfinite(tanloss)) = NaN;
    for k=1:numel(Tlist)
        plot(ax3, fGHz, tanloss(:,k), 'LineWidth',1.6, 'DisplayName',sprintf('T = %g°C',Tlist(k)));
    end
    xline(ax3,24,'k--','HandleVisibility','off');
    local_setTicks(ax3, [min(fGHz) max(fGHz)]);
    xlabel(ax3,'Frequency (GHz)'); ylabel(ax3,'tan\delta'); title(ax3,'Loss tangent'); legend(ax3,'Location','best');
    return;
end

% Validate inputs
if isempty(T_C) || isempty(f_Hz)
    eps_r = complex([]);
    return;
end
T_C   = T_C(:).';   % 1 x NT
nu_GHz = (f_Hz(:)/1e9); % NF x 1

% Static dielectric constant (Eq. 7)
%   eps_s(T) = (A - B*T) / (C + T)
% Coefficients from the provided text: 3.70886e4, 8.2168e1, 4.21854e2
A = 3.70886e4; B = 8.2168e1; C = 4.21854e2;
eps_s = (A - B.*T_C) ./ (C + T_C); % 1 x NT

% Temperature dependence of parameters (Eq. 8)
% Using 11 coefficients a0..a10 (from provided table)
a = [ 5.7230e0,  2.2379e-2, -7.1237e-4, ...  % a0..a2
      5.0478e0, -7.0315e-2,  6.0059e-4, ...  % a3..a5
      3.6143e0,  2.8841e-2, ...              % a6..a7
      1.3652e-1, 1.4825e-3,  2.4166e-4 ];    % a8..a10

eps_1   = a(1) + a(2)*T_C + a(3)*T_C.^2;                    % 1 x NT
nu1     = (45 + T_C) ./ (a(4) + a(5)*T_C + a(6)*T_C.^2);    % GHz, 1 x NT
eps_inf = a(7) + a(8)*T_C;                                   % 1 x NT
nu2     = (45 + T_C) ./ (a(9) + a(10)*T_C + a(11)*T_C.^2);  % GHz, 1 x NT

% Guard against nonpositive relaxation frequencies
nu1(nu1<=0) = NaN; nu2(nu2<=0) = NaN;

% Broadcast to NF x NT
NF = numel(nu_GHz); NT = numel(T_C);
nu_mat  = repmat(nu_GHz, 1, NT);     % NF x NT
nu1_mat = repmat(nu1,    NF, 1);     % NF x NT
nu2_mat = repmat(nu2,    NF, 1);     % NF x NT
eps_s_mat   = repmat(eps_s,   NF, 1);
eps_1_mat   = repmat(eps_1,   NF, 1);
eps_inf_mat = repmat(eps_inf, NF, 1);

% Double-Debye formula (negative imaginary convention)
term1 = (eps_s_mat - eps_1_mat) ./ (1 + 1i*(nu_mat ./ nu1_mat));
term2 = (eps_1_mat - eps_inf_mat) ./ (1 + 1i*(nu_mat ./ nu2_mat));
eps_r = eps_inf_mat + term1 + term2;

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
