function paths = run_curate_temp_events(varargin)
% run_curate_temp_events  5개 폴더 × S11/S22 온도 이벤트 교정(_manual.csv) 일괄 생성
%
% 옵션(Name-Value)
%   'SnapWindowSec' : 각 이벤트를 ±윈도우 내 dT/dt 최대에 스냅(기본 5)
%   'MinSepSec'     : 최소 간격 미만 이벤트는 앞 이벤트만 유지(기본 30)
%   'ShiftSec'      : 전체 이벤트 시각 이동(초, 기본 0)
%   'KeepRange'     : 시간 범위 [t0 t1] 제한(기본 [])
%   'AddTimes'      : 추가 이벤트 시각 목록(기본 [])

addpath(pwd); addpath(fullfile(pwd,'functions_lowpass'));

ip = inputParser;
ip.addParameter('SnapWindowSec', 5, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
ip.addParameter('MinSepSec', 30, @(x)isnumeric(x)&&isscalar(x)&&x>=0);
ip.addParameter('ShiftSec', 0, @(x)isnumeric(x)&&isscalar(x));
ip.addParameter('KeepRange', []);
ip.addParameter('AddTimes', []);
ip.addParameter('UseCh12Mapping', true, @(x)islogical(x)&&isscalar(x));
ip.addParameter('DerivThresh', NaN, @(x)isnumeric(x)&&isscalar(x));
ip.parse(varargin{:});
opt = ip.Results;

exps = { ...
    '2025-09-09 - patch with plate and horn', ...
    '2025-09-10 - patch with plate and horn', ...
    '2025-09-10 - patch with plate and horn2', ...
    '2025-09-11 - beef patch with plate and horn', ...
    '2025-09-11 - beef patch with plate and horn2'};

logDir = fullfile(pwd,'logs'); if exist(logDir,'dir')~=7, mkdir(logDir); end
ts = datestr(now,'yyyymmdd_HHMMSS');
logPath = fullfile(logDir, ['curate_temp_events_' ts '.log']);
try, diary(logPath); diary on; fprintf('Start curate: %s\n', datestr(now)); catch, end

paths = struct('manualFiles', {{}}, 'log', logPath);
for p = ["S11","S22"]
    for i = 1:numel(exps)
        expDir = fullfile(pwd, 'expdata', exps{i});
        try
            args = {'Param', p, 'SnapWindowSec', opt.SnapWindowSec, 'MinSepSec', opt.MinSepSec, 'ShiftSec', opt.ShiftSec};
            if ~isempty(opt.KeepRange), args = [args, {'KeepRange', opt.KeepRange}]; end
            if ~isempty(opt.AddTimes),  args = [args, {'AddTimes',  opt.AddTimes}];  end
            if opt.UseCh12Mapping
                if p == "S11", args = [args, {'Channels', 1}]; else, args = [args, {'Channels', 2}]; end
            end
            if isfinite(opt.DerivThresh)
                args = [args, {'DerivThresh', opt.DerivThresh}];
            end
            outPath = curate_temp_events(expDir, args{:});
            fprintf('OK: %s / %s → %s\n', exps{i}, p, outPath);
            paths.manualFiles{end+1,1} = outPath; %#ok<AGROW>
        catch ME
            warning('FAIL: %s / %s → %s', exps{i}, p, ME.message);
        end
    end
end

try, fprintf('End curate: %s\n', datestr(now)); diary off; catch, end

end
