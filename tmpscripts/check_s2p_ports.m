function report = check_s2p_ports(sparadir)
% CHECK_S2P_PORTS Inspect .s2p files for port count and read errors.
%
% Usage:
%   report = check_s2p_ports;                 % 폴더 선택 대화상자/자동 탐색
%   report = check_s2p_ports('/path/to/sParam');
%
% Output struct fields:
%   folder     - 검사한 폴더 경로
%   files      - 파일 경로 string 배열
%   ok         - 논리 배열 (true=성공적으로 읽음)
%   numPorts   - 각 파일의 포트 수 (읽기 실패 시 NaN)
%   errors     - 읽기 실패 시 에러 메시지(string), 성공 시 ""
%
% 본 스크립트는 RF Toolbox의 sparameters 함수를 사용합니다.

    % functions 폴더가 있으면 path 추가
    if isfolder('functions')
        addpath('functions');
    end

    % 폴더 인자 처리/자동 탐색
    if nargin < 1 || isempty(sparadir)
        % expdata 하위의 sParam 폴더를 자동 탐색
        cands = string.empty(1,0);
        if isfolder('expdata')
            d1 = dir(fullfile('expdata','*'));
            for k = 1:numel(d1)
                if d1(k).isdir && ~startsWith(d1(k).name, '.')
                    p = fullfile('expdata', d1(k).name, 'sParam');
                    if isfolder(p)
                        cands(end+1) = string(p); %#ok<AGROW>
                    end
                end
            end
        end
        if numel(cands) == 1
            sparadir = char(cands);
            fprintf('자동 감지된 sParam 폴더: %s\n', sparadir);
        elseif numel(cands) > 1
            fprintf('여러 sParam 폴더가 감지되었습니다. 목록에서 선택하세요:\n');
            for i = 1:numel(cands)
                fprintf('  [%d] %s\n', i, cands(i));
            end
            idx = input('번호 입력 (취소는 Enter): ');
            if isempty(idx) || ~isscalar(idx) || idx < 1 || idx > numel(cands)
                sparadir = uigetdir(pwd, 's2p 파일 폴더 선택');
            else
                sparadir = char(cands(idx));
            end
        else
            sparadir = uigetdir(pwd, 's2p 파일 폴더 선택');
        end
        if isequal(sparadir, 0)
            error('폴더가 선택되지 않았습니다.');
        end
    end

    sparadir = char(sparadir);
    assert(isfolder(sparadir), '폴더가 존재하지 않습니다: %s', sparadir);

    % 파일 나열
    try
        files = functions.getFiles(sparadir, 's2p'); %#ok<NAMESPACE>
    catch
        % fallback: dir 사용
        d = dir(fullfile(sparadir, '*.s2p'));
        files = strings(1, numel(d));
        for i = 1:numel(d)
            files(i) = string(fullfile(sparadir, d(i).name));
        end
    end

    if isempty(files)
        fprintf('경고: .s2p 파일을 찾을 수 없습니다. 폴더: %s\n', sparadir);
        report = struct('folder', sparadir, 'files', strings(1,0), 'ok', false(1,0), ...
                        'numPorts', nan(1,0), 'errors', strings(1,0));
        return;
    end

    n = numel(files);
    ok       = false(1,n);
    numPorts = NaN(1,n);
    errors   = strings(1,n);

    fprintf('총 %d개 .s2p 파일 검사 시작: %s\n', n, sparadir);

    % 큰 폴더 출력을 줄이기 위한 진행 표시
    t0 = tic;
    for i = 1:n
        f = files(i);
        try
            sp = sparameters(f);
            ok(i) = true;
            % 포트 수 측정
            if isprop(sp, 'NumPorts')
                numPorts(i) = sp.NumPorts;
            else
                numPorts(i) = size(sp.Parameters, 1);
            end
        catch ME
            ok(i) = false;
            numPorts(i) = NaN;
            errors(i) = string(ME.message);
        end

        % 500개마다 진행상황 표시
        if mod(i, 500) == 0
            fprintf('  진행: %d/%d (%.1fs)\n', i, n, toc(t0));
        end
    end

    % 요약
    num_ok = nnz(ok);
    num_err = n - num_ok;
    num_2p = nnz(ok & numPorts == 2);
    num_1p = nnz(ok & numPorts == 1);
    num_other = nnz(ok & ~ismember(numPorts, [1 2]));

    fprintf('\n검사 요약\n');
    fprintf('  총 파일 수      : %d\n', n);
    fprintf('  읽기 성공       : %d\n', num_ok);
    fprintf('  읽기 실패       : %d\n', num_err);
    fprintf('  2포트 파일      : %d\n', num_2p);
    fprintf('  1포트 파일      : %d\n', num_1p);
    fprintf('  기타 포트 수    : %d\n', num_other);

    % 문제 파일 목록 출력
    if num_1p > 0
        idx = find(ok & numPorts == 1);
        fprintf('\n[1포트 파일 목록] (%d개)\n', numel(idx));
        for k = 1:numel(idx)
            fprintf('  %5d | %s\n', idx(k), files(idx(k)));
        end
    end
    if num_other > 0
        idx = find(ok & ~ismember(numPorts, [1 2]));
        fprintf('\n[기타 포트 수 파일 목록] (%d개)\n', numel(idx));
        for k = 1:numel(idx)
            fprintf('  %5d | %s | NumPorts=%g\n', idx(k), files(idx(k)), numPorts(idx(k)));
        end
    end
    if num_err > 0
        idx = find(~ok);
        fprintf('\n[읽기 실패 파일 목록] (%d개)\n', numel(idx));
        for k = 1:numel(idx)
            fprintf('  %5d | %s\n       └ 에러: %s\n', idx(k), files(idx(k)), errors(idx(k)));
        end
    end

    % 리포트 반환
    report = struct('folder', sparadir, 'files', files, 'ok', ok, ...
                    'numPorts', numPorts, 'errors', errors);
end

