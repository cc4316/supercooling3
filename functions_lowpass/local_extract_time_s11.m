function [t, s] = local_extract_time_s11(S)
% .mat 로딩 결과 구조 S에서 time, s11 추출
t = [];
s = [];

fns = fieldnames(S);

% 1) 단일 테이블/구조 내부에 time/s11이 들어있는 경우 처리
if numel(fns) == 1 && (istable(S.(fns{1})) || isstruct(S.(fns{1})))
    X = S.(fns{1});
    [t, s] = local_pick_from_table_or_struct(X);
    if ~isempty(t) && ~isempty(s), return; end
end

% 2) 최상위 필드들에서 직접 탐색
% 시간 필드 후보
timeKeys = {'time','t','time_s','Time','T','timestamp','Timestamp','Time_s'};
s11Keys  = {'s11','S11','s_11','S_11','S11_complex','S11_dB','s11_mag','s11_lin'};

% time 찾기
for i = 1:numel(timeKeys)
    key = timeKeys{i};
    t = local_fetch_if_exist(S, key);
    if ~isempty(t), break; end
end

% s11 찾기 (우선 s11 문자열 포함 필드 스캔)
if isempty(s)
    % 이름에 s11 포함된 필드 우선
    s11_like = fns(contains(lower(fns), 's11'));
    if ~isempty(s11_like)
        s = S.(s11_like{1});
    end
end
if isempty(s)
    % 프리셋 키로 재시도
    for i = 1:numel(s11Keys)
        key = s11Keys{i};
        s = local_fetch_if_exist(S, key);
        if ~isempty(s), break; end
    end
end

% 2열 [Re Im] 형태 처리
if ~isempty(s) && isnumeric(s) && ndims(s) == 2 && size(s,2) == 2
    s = complex(s(:,1), s(:,2));
end

end

