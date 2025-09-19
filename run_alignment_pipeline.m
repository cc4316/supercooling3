function paths = run_alignment_pipeline(varargin)
% run_alignment_pipeline  평가→스윕→리포트 일괄 실행 러너
% 사용법
%   paths = run_alignment_pipeline();
%   paths = run_alignment_pipeline('Param','S11','FreqGHz',24);
%
% 산출물
%   - expdata/transition_eval_results.csv
%   - expdata/transition_eval_details.mat
%   - expdata/alignment_sweep_summary.csv
%   - reports/transition_alignment_report.md (+그림들)

addpath(pwd);
addpath(fullfile(pwd,'functions'));
addpath(fullfile(pwd,'functions_lowpass'));

% 전역적으로 figure 표시 끄기(배치/장시간 실행 안정화)
try
    prevFigVis = get(0,'DefaultFigureVisible');
catch
    prevFigVis = 'on';
end
set(0,'DefaultFigureVisible','off');
cleanupObj = onCleanup(@() set(0,'DefaultFigureVisible', prevFigVis));

% 로그 폴더/디아리 설정
logDir = fullfile(pwd,'logs');
if exist(logDir,'dir') ~= 7, mkdir(logDir); end
ts = datestr(now,'yyyymmdd_HHMMSS');
logPath = fullfile(logDir, ['alignment_run_' ts '.log']);
try
    diary(logPath); diary on;
    fprintf('run_alignment_pipeline 시작: %s\n', datestr(now));
catch
end

ip = inputParser;
ip.addParameter('Exps', load_default_experiments());
ip.addParameter('Param','S11');
ip.addParameter('FreqGHz', 24:0.05:24.25);
ip.addParameter('AlignWindow',[0 10]);
ip.addParameter('GenerateFinalPlots', true, @(x)islogical(x)&&isscalar(x));
ip.parse(varargin{:});
opt = ip.Results;

% 1) 기본 평가 (온도 이벤트 CSV 포함)
[R, detail] = evaluate_transition_alignment('Exps', opt.Exps, 'Param', opt.Param, ...
    'FreqGHz', opt.FreqGHz, 'AlignWindow', opt.AlignWindow, 'WriteTempEvents', false, 'UseManualTempEvents', true);

% 2) 스윕 및 추천 설정
summary = sweep_transition_alignment('Exps', opt.Exps, 'FreqGHz', opt.FreqGHz, 'AlignWindow', opt.AlignWindow);

% 3) 리포트 생성 (평가/스윕과 동일 주파수 전달)
repPath = generate_alignment_report('Results', R, 'Summary', summary, 'Detail', detail, ...
    'Freq', opt.FreqGHz, 'FreqUnit', 'GHz');

% 4) (옵션) 스윕 결과의 추천 설정으로 최종 플롯 생성
if isfield(opt,'GenerateFinalPlots') && opt.GenerateFinalPlots
    try
        % 최적화된 필터 적용(플롯 생성/저장) 직전에 기본 가시성 복구
        set(groot, 'DefaultFigureVisible', 'on');
    catch
        set(0, 'DefaultFigureVisible', 'on');
    end
    try
        run_generate_final_plots('Exps', opt.Exps, 'FreqGHz', opt.FreqGHz);
    catch ME
        warning('run_generate_final_plots 실패: %s', ME.message);
    end
end

paths = struct();
paths.resultsCsv = fullfile(pwd,'expdata','transition_eval_results.csv');
paths.summaryCsv = fullfile(pwd,'expdata','alignment_sweep_summary.csv');
paths.report = repPath;

fprintf('완료: %s\n', repPath);

% 로그 종료
try, fprintf('종료: %s\n', datestr(now)); diary off; catch, end

end
