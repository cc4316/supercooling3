%% Ice complex permittivity (Matsuoka et al., 1996) plotter
% eps*(f,T) = eps'(T) - j*eps''(f,T)
% eps''(f,T) = A(T)/f + B(T)*f.^C(T)  with f in GHz
% Valid range: 190–265 K, 5–39 GHz

clear; clc;

% Ensure helper functions are on path
if isfolder('functions')
    addpath('functions');
end

% ---------- User settings ----------
T_list = [200 230 258 265];     % K, choose any within [190, 265]
fGHz   = linspace(5,39,400);    % GHz

opts = struct();
opts.useMinorRelaxation = false;  % false: use A_D, B_D, C_D (recommended up to ~263 K)
                                  % true : use A_JC, B_JC, C_JC (MHz minor relaxation considered; only valid >=248 K)
opts.ASource            = 'table'; % 'table' (Table I) or 'model' (A_Matsuoka1996)
opts.epsRealModel       = 'constant'; % 'constant' | 'manual' | 'affine' | 'table'
opts.epsRealConst       = 3.154;      % reference eps' (at Tref for 'affine')
opts.epsRealTref        = 258;        % K, reference T for 'affine'
opts.epsRealSlope       = 0.0;        % per-K slope for 'affine' model (set non-zero to see dependence)
% If you have your own eps'(T), set model='manual' and provide a function handle below:
opts.epsRealManualFcn   = @(T) 3.154 + 0.*T;  % example placeholder
% If you have tabulated eps'(T), set model='table' and provide grid+values:
opts.epsReal_Tgrid      = [];          % e.g., [190 220 258 265]
opts.epsReal_vals       = [];          % e.g., [3.18 3.17 3.154 3.13]
opts.showT0Figure       = false;      % if true, open a second figure for T0 details
opts.combineSingleFigure = false;     % if true, combine real/imag into one figure (tiled 2x1)
opts.SaveFig = false;                 % 자동 저장 여부
opts.FigFormats = {'png'};            % 저장 형식
opts.OutDir = fullfile(pwd,'figures');% 저장 폴더

% If requested, draw a single combined figure and exit early
if opts.combineSingleFigure
    fig = figure('Name','Ice permittivity (Matsuoka 1996)','Color','w');
    tiledlayout(fig, 2, 1, 'Padding','compact', 'TileSpacing','compact');

    % Top: epsilon''(f) for multiple temperatures
    nexttile; hold on; grid on; box on;
    for k = 1:numel(T_list)
        T = T_list(k);
        [A,B,C] = matsuoka1996_params(T, opts.useMinorRelaxation);
        if strcmpi(opts.ASource, 'model')
            A = A_Matsuoka1996(T);
        end
        eps2 = A./fGHz + B.*(fGHz.^C);
        plot(fGHz, eps2, 'LineWidth', 1.8, 'DisplayName', sprintf('T = %g K',T));
    end
    xlabel('Frequency f (GHz)');
    ylabel('\epsilon''''(f, T)');
    title('Imaginary permittivity: \epsilon''''(f,T) = A/f + B f^{C}');
    legend('Location','northwest');

    % Bottom: epsilon'(T) curve
    nexttile; hold on; grid on; box on;
    Tplot = linspace(190,265,200);
    eps1_vs_T = local_epsReal_of_T(Tplot, opts);
    plot(Tplot, eps1_vs_T, 'LineWidth', 1.8, 'DisplayName', "eps'(T)");
    if ~isempty(T_list)
        plot(T_list, local_epsReal_of_T(T_list, opts), 'ko', 'MarkerFaceColor',[.1 .1 .1], 'DisplayName','T list');
    end
    xlabel('Temperature T (K)'); ylabel('\epsilon''(T)');
    title('Real permittivity vs temperature');
    legend('Location','best');

    % Optional autosave
    if opts.SaveFig
        try
            if exist(opts.OutDir,'dir') ~= 7, mkdir(opts.OutDir); end
            base = fullfile(opts.OutDir, 'ice_permittivity_combined');
            fmts = cellstr(opts.FigFormats);
            for iFmt = 1:numel(fmts)
                fmt = lower(fmts{iFmt});
                switch fmt
                    case 'fig', savefig(fig, [base '.fig']);
                    case 'png', saveas(fig, [base '.png']);
                    case 'jpg', saveas(fig, [base '.jpg']);
                    case 'pdf', saveas(fig, [base '.pdf']);
                end
            end
        catch ME
            warning('그림 자동 저장 실패: %s', ME.message);
        end
    end

    return;
end

% ---------- Two subplots over frequency: top eps'(f), bottom eps''(f) ----------
fig2 = figure('Name','Ice permittivity vs frequency','Color','w');
tiledlayout(fig2, 2, 1, 'Padding','compact', 'TileSpacing','compact');

% Top: eps'(f) for multiple T (frequency-independent in this model)
nexttile; hold on; grid on; box on;
f_mark_GHz = 24; [~, f_mark_idx] = min(abs(fGHz - f_mark_GHz));
leg_handles_top = gobjects(0);
leg_labels_top = strings(0);
for k = 1:numel(T_list)
    T = T_list(k);
    eps1_T = local_epsReal_of_T(T, opts);
    h = plot(fGHz, eps1_T + 0.*fGHz, 'LineWidth', 1.8);
    leg_handles_top(end+1) = h; %#ok<AGROW>
    leg_labels_top(end+1) = sprintf('T = %g K  (%.3f)', T, eps1_T); %#ok<AGROW>
end
xline(f_mark_GHz, 'k--', 'HandleVisibility','off');
xlabel('Frequency f (GHz)'); ylabel('\epsilon''(f, T)');
title('Real part vs frequency');
legend(leg_handles_top, leg_labels_top, 'Location','northwest');

% Bottom: eps''(f) for multiple T (display as positive loss)
nexttile; hold on; grid on; box on;
leg_handles_bot = gobjects(0);
leg_labels_bot = strings(0);
for k = 1:numel(T_list)
    T = T_list(k);
    [A,B,C] = matsuoka1996_params(T, opts.useMinorRelaxation);
    if strcmpi(opts.ASource, 'model')
        A = A_Matsuoka1996(T);
    end
    eps2 = A./fGHz + B.*(fGHz.^C); % epsilon'' >= 0
    h = plot(fGHz, eps2, 'LineWidth', 1.8);
    val24 = eps2(f_mark_idx);
    leg_handles_bot(end+1) = h; %#ok<AGROW>
    leg_labels_bot(end+1) = sprintf('T = %g K  (%.3f)', T, val24); %#ok<AGROW>
end
xline(f_mark_GHz, 'k--', 'HandleVisibility','off');
xlabel('Frequency f (GHz)'); ylabel('\epsilon''''(f, T)');
title('Imaginary part vs frequency: \epsilon''''(f,T) = A/f + B f^{C}');
legend(leg_handles_bot, leg_labels_bot, 'Location','northeast');

% Optional autosave
if opts.SaveFig
    try
        if exist(opts.OutDir,'dir') ~= 7, mkdir(opts.OutDir); end
        base = fullfile(opts.OutDir, 'ice_permittivity_frequency');
        fmts = cellstr(opts.FigFormats);
        for iFmt = 1:numel(fmts)
            fmt = lower(fmts{iFmt});
            switch fmt
                case 'fig', savefig(fig2, [base '.fig']);
                case 'png', saveas(fig2, [base '.png']);
                case 'jpg', saveas(fig2, [base '.jpg']);
                case 'pdf', saveas(fig2, [base '.pdf']);
            end
        end
    catch ME
        warning('그림 자동 저장 실패: %s', ME.message);
    end
end

% ---------- Example: complex epsilon* at a chosen T ----------
T0 = 258;  % K
[A0,B0,C0] = matsuoka1996_params(T0, opts.useMinorRelaxation);
if strcmpi(opts.ASource, 'model')
    A0 = A_Matsuoka1996(T0);
end
eps2_T0 = A0./fGHz + B0.*(fGHz.^C0);

eps1_T0 = local_epsReal_of_T(T0, opts) * ones(size(fGHz));

eps_complex_T0 = eps1_T0 - 1j*eps2_T0;

% Plot real/imag at T0 for quick look (optional)
if opts.showT0Figure
    figure('Name',sprintf('Ice \\epsilon^* at T=%g K',T0),'Color','w');
    tiledlayout(2,1,'Padding','compact','TileSpacing','compact');
    nexttile; plot(fGHz, real(eps_complex_T0), 'LineWidth', 1.8); grid on; box on;
    ylabel('\\epsilon'''); title(sprintf('Real part at T = %g K', T0));
    nexttile; plot(fGHz, imag(-eps_complex_T0), 'LineWidth', 1.8); grid on; box on;
    xlabel('Frequency f (GHz)'); ylabel('\\epsilon'''''); title(sprintf('Imag part at T = %g K', T0));
end

% ======================== Helpers ===========================
function eps1 = local_epsReal_of_T(T, opts)
    model = lower(string(opts.epsRealModel));
    switch model
        case "constant"
            eps1 = opts.epsRealConst + 0.*T;
        case "manual"
            eps1 = opts.epsRealManualFcn(T);
        case "affine"
            % eps'(T) = eps0 + slope*(T - Tref)
            eps1 = opts.epsRealConst + opts.epsRealSlope.*(T - opts.epsRealTref);
        case "table"
            if isempty(opts.epsReal_Tgrid) || isempty(opts.epsReal_vals)
                error('epsRealModel=table requires epsReal_Tgrid and epsReal_vals.');
            end
            eps1 = interp1(opts.epsReal_Tgrid(:), opts.epsReal_vals(:), T, 'linear', 'extrap');
        otherwise
            error('Unknown epsRealModel. Use ''constant'', ''manual'', ''affine'', or ''table''.');
    end
end

% ======================== Helper: parameters ===========================
function [A,B,C] = matsuoka1996_params(T, useMinor)
% Returns A, B, C at temperature T (K) by linear interpolation of Table I & II
% Units:
%   A is tabulated as (A * 1e4);  actual A = (value)*1e-4
%   B is tabulated as (B * 1e5);  actual B = (value)*1e-5
%   C is unitless
% Valid T range: 190–265 K
% useMinor=false -> use AD/BD/CD (main Debye only)
% useMinor=true  -> for T>=248 K, use AJC/BJC/CJC (MHz minor relaxation from Johari & Charette);
%                   below 248 K falls back to AD/BD/CD.

    % Temperature grid for Table I (A coefficients) in K
    % Matches Table II grid used for B,C interpolation
    TgridA = [190 200 220 240 248 253 258 263 265];

    % ---- Table I: A coefficients (x1e-4) aligned with TgridA ----
    AD_x1e4  = [0.005 0.010 0.031 0.268 0.635 1.059 1.728 2.769 3.326];
    AJC_x1e4 = [NaN   NaN   NaN   NaN   1.870 2.222 3.091 4.591 5.693];

    % B,C are sourced via external matsuoka1996_BC(T,useMinor)

    % Clamp T to valid bounds with a warning (to avoid extrapolation drift)
    if T < 190
        warning('T=%.1f K below 190 K; clamped to 190 K.', T);
        T = 190;
    elseif T > 265
        warning('T=%.1f K above 265 K; clamped to 265 K.', T);
        T = 265;
    end

    % Helper for linear interpolation ignoring NaNs
    lin = @(x,y,Ti) interp1(x(~isnan(y)), y(~isnan(y)), Ti, 'linear');

    % Choose main vs minor-relaxation for A only (Table I). B,C via matsuoka1996_BC
    if useMinor && T >= 248
        A  = 1e-4 * lin(TgridA, AJC_x1e4,  T);
        if isnan(A)
            A  = 1e-4 * lin(TgridA, AD_x1e4,  T);
        end
    else
        A  = 1e-4 * lin(TgridA, AD_x1e4,  T);
    end

    % Get B(T), C(T) from external function (Table II)
    [B, C] = matsuoka1996_BC(T, useMinor);
end
