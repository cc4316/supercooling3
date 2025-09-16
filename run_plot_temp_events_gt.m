function run_plot_temp_events_gt()
% run_plot_temp_events_gt  5개 실험 폴더 × S11/S22 온도 GT 플롯 일괄 생성

addpath(pwd); addpath(fullfile(pwd,'functions_lowpass'));

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
            plot_temp_events_gt(expDir, 'Param', p, 'SaveFig', true);
            fprintf('OK: %s / %s\n', exps{i}, p);
        catch ME
            warning('FAIL: %s / %s → %s', exps{i}, p, ME.message);
        end
        try, close all force; catch, end
    end
end

end

