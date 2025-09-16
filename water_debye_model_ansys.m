function eps_r = water_debye_model_ansys(TempC, FreqHz, varargin)
% Water Debye model (function + demo when called with no args)
% Two-term Debye model with temperature-dependent parameters:
%
%   eps_r(T, f) = (EpsS1(T) - EpsS2(T)) / (1 + j*2*pi*f*tau1(T)) ...
%                + (EpsS2(T) - EpsInf(T)) / (1 + j*2*pi*f*tau2(T)) ...
%                + EpsInf(T)
%
% where (T in Kelvin):
%   T   = TempC + 273.15
%   EpsS1  = -0.37*T + 188.75
%   EpsS2  = 10.9 - 0.015*T
%   EpsInf = -2.35 + 0.023*T
%   tau1   = 6.4971e-15*T^2 - 4.0853e-12*T + 6.4875e-10   [s]
%   tau2   = (-2.4 + 0.012*T) * 1e-12                      [s]
%
% Usage:
%   eps = water_debye_model_ansys(TempC_degC, Freq_Hz)
%   water_debye_model_ansys()                       % demo plot (0.1–100 GHz)
%   water_debye_model_ansys('SaveFig',true, ...)    % demo + autosave options
%
% Demo-only options (Name-Value):
%   'SaveFig'    : 논문/리포트용 그림 자동 저장 (기본 false)
%   'FigFormats' : 저장 형식 셀배열(예: {'png','pdf'}; 기본 {'png'})
%   'OutDir'     : 저장 폴더(기본 './figures')

    if nargin == 0 || (nargin >= 1 && (ischar(TempC) || isstring(TempC)))
        % Parse demo NV options if provided in varargin or as first arg
        p = inputParser;
        addParameter(p, 'SaveFig', false, @(x)islogical(x)&&isscalar(x));
        addParameter(p, 'FigFormats', {'png'}, @(c) iscell(c) || isstring(c));
        addParameter(p, 'OutDir', fullfile(pwd,'figures'), @(s)ischar(s)||isstring(s));
        % Support calling like water_debye_model_ansys('SaveFig',true)
        if nargin >= 1 && (ischar(TempC) || isstring(TempC))
            varargin = [{TempC, FreqHz}, varargin]; %#ok<AGROW>
        end
        parse(p, varargin{:});
        optDemo = p.Results;

        % Demo mode
        TempC_list = [-10 -5 0 10 23 24 25];          % degC
        FreqGHz    = logspace(log10(0.1), log10(100), 800); % 0.1–100 GHz
        FreqHz     = FreqGHz * 1e9;

        eps_demo = water_debye_model_ansys(TempC_list, FreqHz);

        f = figure('Name','Water Debye model: eps vs frequency','Color','w');
        tiledlayout(3,1,'Padding','compact','TileSpacing','compact');

        % 24 GHz marker index
        f_mark_GHz = 24; [~, idx24] = min(abs(FreqGHz - f_mark_GHz));

        % Top: real(eps)
        nexttile; hold on; grid on; box on;
        for k = 1:numel(TempC_list)
            p = plot(FreqGHz, real(eps_demo(:,k)), 'LineWidth', 1.6, 'DisplayName', sprintf('T = %g°C', TempC_list(k)), ...
                'Marker','o','MarkerIndices', idx24);
            yk = real(eps_demo(idx24,k));
            try, col = get(p,'Color'); catch, col = [0 0 0]; end
            dy = 0.02*max(1,abs(yk));
            text(f_mark_GHz, yk+dy, sprintf('%.3f', yk), 'Color', col, 'FontSize', 10, 'HorizontalAlignment','center');
        end
        xline(f_mark_GHz, 'k--');
        set(gca,'XScale','log');
        % Use plain tick labels (0.1 1 10 100) instead of 10^x
        ticks = [0.1 1 10 100];
        set(gca,'XTick',ticks,'XTickLabel',{'0.1','1','10','100'});
        xlabel('Frequency (GHz)'); ylabel('Re{\epsilon_r}');
        title('Real part vs frequency'); legend('Location','best');
        % Rebuild legend with values at 24 GHz, remove markers/texts
        axTop = gca;
        delete(findobj(axTop,'Type','text'));
        lnTop = flipud(findall(axTop,'Type','line'));
        set(lnTop,'Marker','none');
        labelsTop = arrayfun(@(k) sprintf('T = %g°C  (%.3f)', TempC_list(k), real(eps_demo(idx24,k))), 1:numel(TempC_list), 'UniformOutput', false);
        legend(lnTop(1:numel(TempC_list)), labelsTop, 'Location','best');

        % Bottom: -imag(eps) to show epsilon'' as positive quantity
        nexttile; hold on; grid on; box on;
        for k = 1:numel(TempC_list)
            plot(FreqGHz, -imag(eps_demo(:,k)), 'LineWidth', 1.6);
        end
        xline(f_mark_GHz, 'k--', 'HandleVisibility','off');
        set(gca,'XScale','log');
        ticks = [0.1 1 10 100];
        set(gca,'XTick',ticks,'XTickLabel',{'0.1','1','10','100'});
        xlabel('Frequency (GHz)'); ylabel('-Im{\epsilon_r}');
        title('Imaginary part vs frequency (plotted as -Im)'); legend('Location','best');
        % Rebuild legend with values at 24 GHz, remove markers/texts
        axBot = gca;
        delete(findobj(axBot,'Type','text'));
        lnBot = flipud(findall(axBot,'Type','line'));
        set(lnBot,'Marker','none');
        labelsBot = arrayfun(@(k) sprintf('T = %g°C  (%.3f)', TempC_list(k), -imag(eps_demo(idx24,k))), 1:numel(TempC_list), 'UniformOutput', false);
        legend(lnBot(1:numel(TempC_list)), labelsBot, 'Location','best');
        % Third row: loss tangent tanδ = (-Im)/Re
        nexttile; hold on; grid on; box on;
        tanloss = -imag(eps_demo) ./ real(eps_demo);
        % protect against divide-by-zero
        tanloss(~isfinite(tanloss)) = NaN;
        for k = 1:numel(TempC_list)
            plot(FreqGHz, tanloss(:,k), 'LineWidth', 1.6);
        end
        xline(f_mark_GHz, 'k--', 'HandleVisibility','off');
        set(gca,'XScale','log');
        ticks = [0.1 1 10 100];
        set(gca,'XTick',ticks,'XTickLabel',{'0.1','1','10','100'});
        xlabel('Frequency (GHz)'); ylabel('tan\delta');
        title('Loss tangent vs frequency (tan\delta = (-Im)/Re)'); legend('Location','best');
        % Legend with values at 24 GHz
        axTan = gca;
        lnTan = flipud(findall(axTan,'Type','line'));
        labelsTan = arrayfun(@(k) sprintf('T = %g°C  (%.3f)', TempC_list(k), tanloss(idx24,k)), 1:numel(TempC_list), 'UniformOutput', false);
        legend(lnTan(1:numel(TempC_list)), labelsTan, 'Location','best');

        % Optional autosave
        if optDemo.SaveFig
            try
                outDir = char(optDemo.OutDir);
                if exist(outDir,'dir') ~= 7, mkdir(outDir); end
                base = fullfile(outDir, 'water_debye_model_demo');
                fmts = cellstr(optDemo.FigFormats);
                for i = 1:numel(fmts)
                    fmt = lower(fmts{i});
                    switch fmt
                        case 'fig', savefig(f, [base '.fig']);
                        case 'png', saveas(f, [base '.png']);
                        case 'jpg', saveas(f, [base '.jpg']);
                        case 'pdf', saveas(f, [base '.pdf']);
                    end
                end
            catch ME
                warning('자동 저장 실패: %s', ME.message);
            end
        end

        if nargout > 0, eps_r = []; end
        return;
    end

    % Shapes: return eps_r as [numFreq x numTemp]
    T = TempC(:).' + 273.15;         % 1 x NT (K)
    f = FreqHz(:);                   % NF x 1 (Hz)
    [F, TT] = ndgrid(f, T);          % NF x NT grids
    w = 2*pi*F;

    % Temperature-dependent parameters
    EpsS1  = -0.37.*TT + 188.75;
    EpsS2  = 10.9 - 0.015.*TT;
    EpsInf = -2.35 + 0.023.*TT;

    tau1 = 6.4971e-15.*TT.^2 - 4.0853e-12.*TT + 6.4875e-10;      % s
    tau2 = (-2.4 + 0.012.*TT) * 1e-12;                            % s

    % Two-term Debye model
    term1 = (EpsS1 - EpsS2) ./ (1 + 1i*w.*tau1);
    term2 = (EpsS2 - EpsInf) ./ (1 + 1i*w.*tau2);
    eps_r = term1 + term2 + EpsInf;
end
