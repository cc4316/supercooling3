function yt = local_logticks(fmin, fmax)
% local_logticks  로그 스케일 축용 촘촘한 tick 생성 (1,2,3,5 시퀀스)
% 입력은 양수(Hz). 출력은 [fmin,fmax] 범위 내의 tick 벡터.

fmin = max(realmin, double(fmin));
fmax = max(fmin*1.0001, double(fmax));

emin = floor(log10(fmin));
emax = ceil(log10(fmax));
bases = [1 2 3 5];
yt = [];
for e = emin:emax
    vals = bases .* (10.^e);
    yt = [yt vals]; %#ok<AGROW>
end
% 경계 내로 제한 및 정렬/유일화
yt = yt(yt >= fmin & yt <= fmax);
yt = unique(yt);

% 너무 많으면 일부 샘플링 (최대 20개)
maxN = 20;
if numel(yt) > maxN
    idx = round(linspace(1, numel(yt), maxN));
    yt = yt(idx);
end
end

