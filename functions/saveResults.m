function saveResults(resultsTable, savePath)
% saveResults - 결과를 CSV 파일로 저장하는 함수
%
% Syntax: saveResults(resultsTable, savePath)
%
% Inputs:
%   resultsTable - 저장할 데이터가 담긴 table형 변수
%   savePath - 파일을 저장할 전체 경로 (파일 이름 포함)

try
    writetable(resultsTable, savePath);
    fprintf('결과가 다음 위치에 저장되었습니다: %s\n', savePath);
catch ME
    warning('결과를 저장하는 중 오류가 발생했습니다: %s\n', ME.message);
end

end
