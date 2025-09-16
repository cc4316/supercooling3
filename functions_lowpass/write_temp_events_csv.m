function outPath = write_temp_events_csv(expDir, Et, varargin)
% write_temp_events_csv  온도 이벤트를 CSV로 저장(데이터셋화)
% 사용법
%   outPath = write_temp_events_csv(expDir, Et)
%   outPath = write_temp_events_csv(expDir, Et, 'Param','S11')
%
% 입력
%   expDir : 실험 루트 폴더 (Temp.csv가 있는 폴더)
%   Et     : detect_temp_events 반환 구조체
%
% 옵션(Name-Value)
%   'Param' : 'S11'|'S22' 등, 파일명 접미에 사용 (기본 'P')
%
% 출력
%   outPath : 작성된 CSV 경로

ip = inputParser;
ip.addParameter('Param','P', @(s)ischar(s)||isstring(s));
ip.parse(varargin{:});
param = upper(string(ip.Results.Param));

if isempty(Et) || ~isfield(Et,'t')
    error('write_temp_events_csv:BadInput','Et 구조체가 비었습니다.');
end

% 테이블 구성
n = numel(Et.idx);
T = table((1:n).', Et.idx(:), Et.t(:), Et.dT_dt(Et.idx(:)), Et.Tsel(Et.idx(:)), ...
    'VariableNames', {'event_idx','row_idx','t','dT_dt','Tsel'});

% 경로/파일명
tag = regexprep(char(param),'[^A-Za-z0-9]','');
fname = sprintf('temp_events_%s.csv', tag);
outPath = fullfile(expDir, fname);

% 저장
writetable(T, outPath);
fprintf('온도 이벤트 CSV 저장: %s (N=%d)\n', outPath, height(T));

end

