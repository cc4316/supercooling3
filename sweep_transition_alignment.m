function summary = sweep_transition_alignment(varargin)
% sweep_transition_alignment  정합율/오탐율 기준 필터/임계 스윕 및 추천 설정 산출(수동 이벤트 전용)
%
% 옵션(Name-Value)
%   'Exps'        : 실험 폴더 목록
%   'FreqGHz'     : 분석 주파수(들) [기본 24]
%   'AlignWindow' : [0 5]
%   'AlphaFP'     : 점수 가중치(오탐 1/min 당 차감, 기본 0.02)
%   'Params'      : {'S11','S22'}
%   'FilterTypes' : {'lowpass'| 'bandstop'}
%   'CutoffHzList': [0.01 0.05 ...] (lowpass일 때)
%   'Bandstops'   : {[f1 f2], ...} (bandstop일 때)
%   'FilterOrders': [2 3 4]
%   'FilterDesigns': {'bessel','elliptic','butter','notch'}
%   'FilterModes' : {'causal','centered'}
%   'EventKs'     : [15 20]
%
ip = inputParser;
ip.addParameter('Exps', load_default_experiments());
ip.addParameter('FreqGHz', 24);
ip.addParameter('AlignWindow', [0 5]);
ip.addParameter('AlphaFP', 0.02);
ip.addParameter('Params', {'S11','S22'});
ip.addParameter('FilterTypes', {'lowpass'});
ip.addParameter('CutoffHzList', 0.002:0.002:0.008);
ip.addParameter('Bandstops', {[0.01 0.06]});
ip.addParameter('FilterOrders', [2]);
ip.addParameter('FilterDesigns', {'bessel'});
ip.addParameter('FilterModes', {'causal'});
ip.addParameter('EventKs', 20:4:40);
ip.parse(varargin{:});
optTop = ip.Results;

Params = cellstr(optTop.Params);
FilterTypes = cellstr(optTop.FilterTypes);
CutoffHzList = optTop.CutoffHzList;
Bandstops = optTop.Bandstops;
FilterOrders = optTop.FilterOrders;
FilterDesigns = cellstr(optTop.FilterDesigns);
FilterModes = cellstr(optTop.FilterModes);
EventKs = optTop.EventKs;

rows = {};

for ipar = 1:numel(Params)
  for ift = 1:numel(FilterTypes)
    ftype = FilterTypes{ift};
    if strcmpi(ftype,'lowpass')
      for ic = 1:numel(CutoffHzList)
        for io = 1:numel(FilterOrders)
          for id = 1:numel(FilterDesigns)
            for im = 1:numel(FilterModes)
              for ik = 1:numel(EventKs)
                args = {'Exps', optTop.Exps, 'FreqGHz', optTop.FreqGHz, ...
                        'Param', Params{ipar}, 'FilterType', ftype, 'CutoffHz', CutoffHzList(ic), ...
                        'FilterOrder', FilterOrders(io), 'FilterDesign', FilterDesigns{id}, 'FilterMode', FilterModes{im}, ...
                        'EventK', EventKs(ik), 'AlignWindow', optTop.AlignWindow, ...
                        'Save', true, 'WriteTempEvents', false, 'UseManualTempEvents', true};
                try
                  [R, detail] = evaluate_transition_alignment(args{:});
                catch ME
                  warning(ME.identifier, '%s', ME.message); continue;
                end
                % 성공률(세부) = per-(event×freq) 기준
                succ_detailed = mean(R.success);
                % 성공률(이벤트) = 온도 이벤트 당 어느 한 주파수라도 hit
                [succ, dmag, dph, fp_mag, fp_ph] = i_metrics(R, detail, optTop.AlignWindow);
                score = succ - optTop.AlphaFP * mean([fp_mag fp_ph], 'omitnan');
                rows(end+1,1) = { { Params{ipar}, ftype, CutoffHzList(ic), NaN, FilterOrders(io), FilterDesigns{id}, FilterModes{im}, EventKs(ik), succ, succ_detailed, dmag, dph, fp_mag, fp_ph, score } }; %#ok<AGROW>
              end
            end
          end
        end
      end
    else
      for ib = 1:numel(Bandstops)
        for io = 1:numel(FilterOrders)
          for id = 1:numel(FilterDesigns)
            for im = 1:numel(FilterModes)
              for ik = 1:numel(EventKs)
                args = {'Exps', optTop.Exps, 'FreqGHz', optTop.FreqGHz, ...
                        'Param', Params{ipar}, 'FilterType', ftype, 'BandstopHz', Bandstops{ib}, ...
                        'FilterOrder', FilterOrders(io), 'FilterDesign', FilterDesigns{id}, 'FilterMode', FilterModes{im}, ...
                        'EventK', EventKs(ik), 'AlignWindow', optTop.AlignWindow, ...
                        'Save', true, 'WriteTempEvents', false, 'UseManualTempEvents', true};
                try
                  [R, detail] = evaluate_transition_alignment(args{:});
                catch ME
                  warning(ME.identifier, '%s', ME.message); continue;
                end
                succ_detailed = mean(R.success);
                [succ, dmag, dph, fp_mag, fp_ph] = i_metrics(R, detail, optTop.AlignWindow);
                score = succ - optTop.AlphaFP * mean([fp_mag fp_ph], 'omitnan');
                rows(end+1,1) = { { Params{ipar}, ftype, NaN, Bandstops{ib}, FilterOrders(io), FilterDesigns{id}, FilterModes{im}, EventKs(ik), succ, succ_detailed, dmag, dph, fp_mag, fp_ph, score } }; %#ok<AGROW>
              end
            end
          end
        end
      end
    end
  end
end

vars = {'Param','FilterType','CutoffHz','BandstopHz','FilterOrder','FilterDesign','FilterMode','EventK','success_rate','success_rate_detailed','mean_delta_mag_s','mean_delta_phase_s','fp_mag_count','fp_phase_count','score'};
if isempty(rows)
  summary = cell2table(cell(0,numel(vars)), 'VariableNames', vars);
else
  summary = cell2table(vertcat(rows{:}), 'VariableNames', vars);
end

% 저장 및 베스트 출력
outCsv = fullfile(pwd, 'expdata', 'alignment_sweep_summary.csv');
try, writetable(summary, outCsv); catch, end
if ~isempty(summary)
  [~, bestIdx] = max(summary.score);
  best = summary(bestIdx,:);
  fprintf('추천 설정(점수 기준)\n');
  disp(best);
else
  fprintf('스윕 결과가 비어 있습니다.\n');
end
end

function [succ, dmag, dph, fp_mag, fp_ph] = i_metrics(R, detail, win)
% 성공률
if isempty(R)
    succ = NaN; dmag = NaN; dph = NaN; fp_mag = NaN; fp_ph = NaN; return; 
end
succ = mean(R.success);
dmag = mean(R.delta_mag_s, 'omitnan');
dph  = mean(R.delta_phase_s, 'omitnan');

% 오탐: detail에서 재계산 (총 개수)
fp_mag = NaN; fp_ph = NaN;
cntFPm = []; cntFPp = [];
for i = 1:numel(detail)
    Et = detail(i).temp; Es = detail(i).sparam;
    if isempty(Et) || isempty(Es), continue; end
    if isempty(Et.t)
        cntFPm(end+1) = 0; %#ok<AGROW>
        cntFPp(end+1) = 0; %#ok<AGROW>
        continue;
    end
    t_s = Es.time_s(:);
    for c = 1:numel(Es.idx_mag)
        dm = Es.idx_mag{c};
        tMag = t_s(dm);
        good = false(size(tMag));
        for k = 1:numel(Et.idx)
            dt = tMag - (Et.t(k) - Et.t(1));
            good = good | (dt >= win(1) & dt <= win(2));
        end
        cntFPm(end+1) = sum(~good); %#ok<AGROW>
    end
    for c = 1:numel(Es.idx_phase)
        dp = Es.idx_phase{c};
        tPh = t_s(dp);
        good = false(size(tPh));
        for k = 1:numel(Et.idx)
            dt = tPh - (Et.t(k) - Et.t(1));
            good = good | (dt >= win(1) & dt <= win(2));
        end
        cntFPp(end+1) = sum(~good); %#ok<AGROW>
    end
end
if isempty(cntFPm) && isempty(cntFPp)
    fp_mag = NaN; fp_ph = NaN; return;
end
fp_mag = sum(cntFPm);
fp_ph  = sum(cntFPp);
end
