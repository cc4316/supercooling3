function run_plot_temp_events_gt_review()
% run_plot_temp_events_gt_review  교정 검토용 GT 플롯을 화면에 연속 표시(저장 안 함)

addpath(pwd); addpath(fullfile(pwd,'functions_lowpass'));

% 화면 표시 보장
try, set(0,'DefaultFigureVisible','on'); catch, end

exps = { ...
    '2025-09-09 - patch with plate and horn', ...
    '2025-09-10 - patch with plate and horn', ...
    '2025-09-10 - patch with plate and horn2', ...
    '2025-09-11 - beef patch with plate and horn', ...
    '2025-09-11 - beef patch with plate and horn2'};

for p = ["S11","S22"]
    for i = 1:numel(exps)
        expDir = fullfile(pwd, 'expdata', exps{i});
        try
            plot_temp_events_gt(expDir, 'Param', p, 'UseManual', true, 'SaveFig', false, 'ShowDeriv', true);
            drawnow;
        catch ME
            warning('Plot FAIL: %s / %s → %s', exps{i}, p, ME.message);
        end
    end
end

end

