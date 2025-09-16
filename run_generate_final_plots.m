function outs = run_generate_final_plots(varargin)
% run_generate_final_plots  최적 설정(포트별)로 s-파라 결합/필터 플롯 생성 및 저장(fig/png)
%
% 사용법
%   outs = run_generate_final_plots();

addpath(pwd); addpath(fullfile(pwd,'functions')); addpath(fullfile(pwd,'functions_lowpass'));

ip = inputParser;
ip.addParameter('Exps', {});
ip.addParameter('FreqGHz', 24:0.05:24.25);
ip.parse(varargin{:});
opt = ip.Results;

% Exps 미지정 시, 중앙 로더 사용
if isempty(opt.Exps)
    opt.Exps = load_default_experiments();
end

% 최적 설정 읽기: alignment_sweep_summary.csv는 쓰지 않고 best_settings만 사용
best = struct();
try
    jsonPath = fullfile(pwd,'expdata','best_settings.json');
    if exist(jsonPath,'file') == 2
        txt = fileread(jsonPath);
        J = jsondecode(txt);
        if isfield(J,'per_port') && ~isempty(J.per_port)
            tmp = struct();
            for k = 1:numel(J.per_port)
                rec = J.per_port(k);
                if isfield(rec,'Param')
                    tmp.(char(rec.Param)) = rec;
                end
            end
            best = tmp;
        elseif isfield(J,'overall') && ~isempty(J.overall) && isfield(J.overall,'Param')
            rec = J.overall;
            tmp = struct();
            tmp.(char(rec.Param)) = rec;
            best = tmp;
        end
    end
catch
end
% MAT fallback
if isempty(fieldnames(best))
    try
        matPath = fullfile(pwd,'expdata','best_settings.mat');
        if exist(matPath,'file') == 2
            data = load(matPath);
            if isfield(data,'best')
                J = data.best;
                if isfield(J,'per_port') && ~isempty(J.per_port)
                    tmp = struct();
                    for k = 1:numel(J.per_port)
                        rec = J.per_port(k);
                        if isfield(rec,'Param')
                            tmp.(char(rec.Param)) = rec;
                        end
                    end
                    best = tmp;
                elseif isfield(J,'overall') && ~isempty(J.overall) && isfield(J.overall,'Param')
                    rec = J.overall;
                    tmp = struct();
                    tmp.(char(rec.Param)) = rec;
                    best = tmp;
                end
            end
        end
    catch
    end
end
assert(~isempty(fieldnames(best)), 'best_settings.json(.mat)가 없습니다. 먼저 리포트를 생성하거나 스윕 후 리포트를 실행하세요.');

outs = struct('files', {{}});
baseExp = fullfile(pwd,'expdata');
exps = cellstr(opt.Exps);
for i = 1:numel(exps)
    expDir = fullfile(baseExp, exps{i});
    spDir = expDir; if exist(fullfile(expDir,'sParam'),'dir')==7, spDir = fullfile(expDir,'sParam'); end
    for p = fieldnames(best)'
        par = p{1}; B = best.(par);
        try
            args = {'Param', par, 'Freq', opt.FreqGHz, 'FreqUnit','GHz', ...
                    'FilterType', char(B.FilterType), 'FilterDesign', char(B.FilterDesign), 'FilterMode', char(B.FilterMode), ...
                    'FilterOrder', B.FilterOrder, ...
                    'Plot', true, 'SaveFig', true, 'FigFormats', {'fig','png'}, ...
                    'PlotFilterResponse', true, 'SaveFilterFig', true, ...
                    'RunWavelet', false, 'ShowEvents', true};
            % Cutoff/Bandstop/Notch 파라미터 전달
            if isfield(B,'FilterType') && strcmpi(char(B.FilterType),'bandstop')
                bs = [];
                if isfield(B,'BandstopHz'), bs = B.BandstopHz; end
                if iscell(bs), bs = bs{1}; end
                args = [args, {'BandstopHz', bs}];
                if isfield(B,'NotchQ') && ~isempty(B.NotchQ)
                    args = [args, {'NotchQ', B.NotchQ}];
                end
            else
                if isfield(B,'CutoffHz')
                    args = [args, {'CutoffHz', B.CutoffHz}];
                end
            end
            combine_sparam_lowpass(spDir, args{:});
            % 결과 폴더로 이동(expDir/results)
            resDir = fullfile(expDir, 'results'); if exist(resDir,'dir')~=7, mkdir(resDir); end
            if strcmpi(par,'S11'), baseName = 'sparam_combined_filtered_s11'; else, baseName = 'sparam_combined_filtered_s22'; end
            srcPng = fullfile(spDir, [baseName '.png']); srcFig = fullfile(spDir, [baseName '.fig']);
            if exist(srcPng,'file')==2, movefile(srcPng, fullfile(resDir, [baseName '.png']), 'f'); end
            if exist(srcFig,'file')==2, movefile(srcFig, fullfile(resDir, [baseName '.fig']), 'f'); end
            % 필터 응답도 이동
            try
                frType = 'lowpass';
                if isfield(B,'FilterType'), frType = lower(char(B.FilterType)); end
            catch
                frType = 'lowpass';
            end
            frBase = sprintf('filter_response_%s_%s', lower(par), frType);
            for ext = {'.png','.fig'}
                src = fullfile(spDir, [frBase ext{1}]);
                if exist(src,'file')==2, movefile(src, fullfile(resDir, [frBase ext{1}]), 'f'); end
            end
            outs.files{end+1,1} = fullfile(resDir, [baseName '.png']); %#ok<AGROW>
        catch ME
            warning('Final plot 실패: %s / %s → %s', exps{i}, par, ME.message);
        end
    end
end

end
