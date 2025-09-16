function partNum = local_get_part_num(fname)
% 파일명에서 'partNNN' 숫자 추출 (없으면 큰 값)
partNum = inf;
tok = regexp(fname, 'part(\d+)', 'tokens', 'ignorecase');
if ~isempty(tok)
    partNum = str2double(tok{1}{1});
end
end

