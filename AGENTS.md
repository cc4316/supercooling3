# AGENTS Guide

This repository contains MATLAB tools for temperature/S‑parameter plotting, dielectric data pipelines, and physics‑based permittivity models and comparisons (water and ice).

## Overview
- Plot temperature logs and S‑parameters with robust file handling.
- Run a dielectric processing pipeline with optional interactive frequency selection.
- Model water (Debye) and ice (Matsuoka 1996) complex permittivity versus frequency and temperature.
- Compare models against curated experimental datasets (2007 retro model, Bertoni 1982, 1991 set).

## Repo Layout
- `plottemperature2.m`: Plot Temp.csv time series with S‑parameter context; merges multiple `Temp*.csv` in memory.
- `combine_sparam_lowpass.m`: sParam 파트(.mat) 병합 + 저역/밴드저지 필터 적용, 필터 응답/웨이블릿까지 연계.
- `run_dielectric_pipeline.m`: Orchestrates PRN→CSV (only when stale/missing), frequency selection (`AskFreq`), and downstream steps.
- `prn_to_csv.m`: Safe PRN→CSV converter with `quiet` mode; overwrite support.
- `water_debye_model_ansys.m`: ANSYS-parameterized double-Debye water model (+ no‑arg demo).
- `water_debye_model_literature.m`: Literature (Section III.A) double-Debye model with T-dependent polynomials (+ no‑arg demo).
- `compare_water_debye_models.m`: Overlays ANSYS vs literature double-Debye models across frequency and temperatures.
- `plot_ice_permittivity_matsuoka1996.m`: Ice ε*(f, T) using Matsuoka et al. (1996) with table/Arrhenius options.
- `compare_water_debye_with_2007.m`: Overlays Debye model with experimental datasets (2007, Bertoni 1982, 1991).
- `functions/needsSparamCacheRebuild.m`: Validates S‑parameter cache freshness vs `.s2p` list and timestamps.
- `expdata/`: CSV datasets for model comparisons.
 - Transition Alignment(정합) 파이프라인
   - `evaluate_transition_alignment.m`: 온도/스파라 이벤트 검출 및 Δt 기반 정합 평가(캐시 자동 생성, Temp 이벤트 CSV 기록).
   - `sweep_transition_alignment.m`: 필터/임계 파라미터 스윕, 성공률/오탐율/점수 계산, 추천 설정 산출.
   - `generate_alignment_report.m`: 평가/스윕 요약 리포트(Markdown + 히스토그램 이미지) 생성.
   - `run_alignment_pipeline.m`: 평가→스윕→리포트를 무플롯(headless)로 일괄 실행(+로그).

## Prerequisites
- MATLAB R2021a+ recommended (for tiledlayout and table import options).
- No external toolboxes required for core workflows.

## Quick Start
1. Place experimental CSVs under `expdata/` (see Datasets below).
2. Water model demo: run `water_debye_model_ansys` (no args) to plot Re, −Im, tanδ.
3. Compare with literature: run `compare_water_debye_with_2007`.
4. Ice model: run `plot_ice_permittivity_matsuoka1996`.
5. Dielectric pipeline: `run_dielectric_pipeline('AskFreq', true)` for interactive frequency selection.
6. Temperature + S‑params: run `plottemperature2` and follow prompts (channels/frequencies, reuse dataDir).
7. sParam 결합/필터 + 웨이블릿: `combine_sparam_lowpass(dataDir, 'Param','both', 'FilterType','bandstop', ...)`.
 8. Transition 정합 배치 실행(무플롯):
    - MATLAB: `addpath(pwd); clear functions; paths = run_alignment_pipeline;`
    - macOS 배치: `/Applications/MATLAB_R2024b.app/bin/matlab -batch "cd('$(pwd)'); addpath(pwd); clear functions; run_alignment_pipeline"`

## Datasets
- `expdata/water_permittivity_retro_model_2007.csv`: Columns include `Temp_C`, low/high MHz points and ε′/ε″ values.
- `expdata/water_permittivity_bertoni_1982.csv`: Single‑frequency points (`f_GHz` ~ 9.61), ε′, ε″, optional error columns.
- `expdata/water_permittivity_1991.csv`: Columns `f` (GHz), `T` (°C), `ε'`, `ε''` (Unicode names supported).

## Key Workflows
- Temperature plotting (`plottemperature2.m`)
  - Prompts to select temperature channels (by port or both) and frequency points.
  - Reuses selected `dataDir` by default; remembers previous frequency selection.
  - Loads `Temp.csv`; if multiple `Temp*.csv` exist, merges in memory (no file writes).
  - Robust table import: ignores extra columns, reads empty lines, parses `Time` resiliently.
  - Uses S‑parameter cache when valid; rebuilds only when missing/stale.

- Dielectric pipeline (`run_dielectric_pipeline.m`)
  - Converts PRN→CSV only when CSV is missing or older than PRN; `quiet` mode suppresses warnings.
  - `AskFreq` enables interactive frequency selection. Options parsed before use.

- Models and plots
  - `water_debye_model_ansys(Tlist_C, f_Hz)`: Returns complex εr (NF × NT). No‑arg call runs demo with 24 GHz markers and numeric log ticks (0.1 1 10 100).
  - `plot_ice_permittivity_matsuoka1996`: Implements Matsuoka (1996). `opts.ASource` = `table` or `model` (Arrhenius/Curie–Weiss); real‑part temperature options: constant/manual/affine/table. Two subplots: Re (top), −Im (bottom) with 24 GHz marker.
  - `compare_water_debye_with_2007`: Separate figures for 2007, Bertoni (1982), and 1991 datasets; overlays Debye curves; experimental markers color‑matched to model lines; also plots tanδ; log x‑axis with numeric ticks; curves extend to 10 GHz.

- Transition Alignment (evaluate/sweep/report)
  - `evaluate_transition_alignment`: 실험 폴더별로
    - s-파라 캐시 확인 후 자동 생성(`cachespara`) → 결합/필터(`combine_sparam_lowpass`) 호출
    - 온도 채널 구성 CSV가 없으면 자동 생성(1..min(8,N) 라벨) → 프롬프트 없음
    - 온도 이벤트(`temp_events_<Param>.csv`)를 각 실험 폴더에 저장
    - s‑파라/온도 이벤트 간 Δt 측정(온도 이후 0..5s 내 존재 여부) 및 성공률 계산
  - `sweep_transition_alignment`: Param/Filter/Cutoff/Order/Mode/K 값 그리드 스윕 → 성공률·오탐율(분당)·점수 계산 → 추천 설정 산출 → `expdata/alignment_sweep_summary.csv` 저장
  - `generate_alignment_report`: `reports/transition_alignment_report.md` 생성(추천 설정 1행, 요약, Δt 히스토그램 이미지 포함)
  - `run_alignment_pipeline`: 위 3단계를 무플롯(headless)로 연속 실행, 로그 기록

## Conventions
- MATLAB style: close all functions (including the main) with `end`. Use local helper functions at the bottom of the file.
- Axis: frequency in GHz on log scale with numeric tick labels; show 24 GHz as a reference line.
- Imaginary parts are plotted as −Im so values appear positive.
- Do not write merged temperature CSVs; merge in memory only.
- Keep changes minimal and focused; avoid unrelated refactors.
- Communication: 모든 사용자 응답은 기본적으로 한국어(한글)로 작성합니다. 간결하고 정중한 톤을 유지합니다.
- 수정 직후 최신 코드 실행: `clear <함수명>` 또는 `clear functions`(함수 캐시 초기화). `which 함수명 -all`로 경로 확인.

### Transition 정합: 무플롯/로그/프롬프트 방지
- 무플롯: `run_alignment_pipeline` 진입 시 `DefaultFigureVisible='off'`로 전역 비가시화(종료 시 원복). 내부 결합/필터 호출 시 `Plot=false, SaveFig=false, PlotFilterResponse=false, SaveFilterFig=false, RunWavelet=false` 전달. 필요 시 `close all force`로 잔여 figure 정리.
- 프롬프트 방지: `evaluate_transition_alignment`에서 `TempChannelSelection.csv`가 없으면 자동 생성(포트별 동일 기본 라벨). `combine_sparam_lowpass`에는 필수 인자를 모두 Name-Value로 전달해 메뉴 대화 미사용.
- 캐시 자동화: sParam 폴더에 캐시(`sparam_data_part*.mat` 또는 `sparam_data.mat`)가 없으면 `cachespara(spDir)` 호출.
- 로그: 러너 시작 시 `logs/alignment_run_YYYYMMDD_HHMMSS.log`에 `diary` 기록. 배치 표준출력은 `logs/matlab_batch_*.out`(또는 `matlab_nodisplay_*.out`).

## Caching
- S‑parameter cache is refreshed only when:
  - Cache missing; or
  - `.s2p` file list differs from cache; or
  - Any source `.s2p` is newer than the cache; or
- User requests `RefreshCache`.

추가: Transition 정합 파이프라인에서는 캐시가 없을 경우 자동으로 생성합니다(대기 시간 증가 가능). 캐시가 있으면 재사용하며, 결합/필터 파일(`sparam_combined_filtered_*.mat`)도 존재 시 재활용 패턴을 따릅니다.

## Troubleshooting
- Function termination error (“was closed with an `end`…”) → Ensure the main function also ends with `end` when local functions use `end`.
- Unicode column names (`ε'`, `ε''`) → Access via `T.("ε'")` and `T.("ε''")` syntax.
- Path issues → Add repo to path: `addpath(pwd);` before running scripts.
- 플롯 폰트가 갑자기 커진 경우 → `plottemperature2_run`가 `groot` 기본 폰트를 키웠을 수 있습니다. 아래로 복구:
  - `set(groot,'defaultAxesFontSize','remove','defaultTextFontSize','remove','defaultLegendFontSize','remove')`
  - 또는 MATLAB 재시작. 확대 원치 않으면 `plottemperature2_run('FontScale',1)` 사용.

- Transition 정합 관련
  - 테이블 대입 오류(예: "To assign to or create a variable in a table ...") → 평가 결과 테이블에 구조체를 넣지 않습니다. 옵션 스냅샷은 `expdata/transition_eval_details.mat`의 `info`로 확인하세요.
  - 배치가 중간에 종료/무응답 → 무플롯 모드와 프롬프트 방지 옵션이 적용되어야 합니다. `clear functions` 후 재실행. 진행은 `logs/`에서 확인.
  - 수행시간이 길다 → s2p가 수천 개인 폴더는 캐시/결합/필터에 시간이 오래 걸립니다. 배치 모드로 야간 실행 권장.

## Roadmap / TODOs
- Option to autosave figures (PNG/SVG) with a flag.
- Legend‑embedded values at reference frequencies to reduce annotations.
- Optional temperature subset filtering for clearer overlays.
- Deduplicate Temp timestamps when merging.
 - Transition 정합 파이프라인
   - 스윕 그리드 확장(bandstop/notch, 더 많은 Cutoff/Order/Design)
   - 추천 설정을 결합/웨이블릿 후처리에 자동 적용하는 상위 래퍼
   - 실험 분할 실행/재시작 체크포인트(오래 걸리는 폴더 순차 처리)

## Contribution
- Prefer small, surgical changes aligned with existing patterns.
- Update inline help sections (`help` text) when adding options.
- S‑parameter 결합/필터링 + 웨이블릿 (`combine_sparam_lowpass.m`)
  - 필터 유형/설계/차수
    - `FilterType`: `lowpass` | `bandstop` (기본 `lowpass`)
    - `FilterDesign`: `elliptic`(기본) | `butter` | `bessel` | `notch`
    - `FilterOrder`: 정수 차수(기본 4). `bessel`/`butter`는 저차(2~3) 권장(지연 체감 낮춤).
    - `FilterMode`: `causal`(기본) | `centered`(filtfilt, zero‑phase)
    - 밴드저지: `BandstopHz` = [f1 f2] (Hz), `NotchQ`(옵션, notch 사용 시)
  - 인터랙티브 선택
    - `FilterType` 미지정 시 콘솔 메뉴(1=lowpass, 2=bandstop)
    - 최근 입력값을 폴더별로 기억(`combine_sparam_prefs.mat`): 유형/차단/밴드저지 대역이 기본값으로 제안됨
    - expdata 폴더 선택도 최근 값을 기억(`expdata/.last_expdata_selection.mat`)
  - 필터 응답 플롯/저장
    - `PlotFilterResponse`(기본 true), `SaveFilterFig`(기본 SaveFig와 동일)
    - 제목에 필터 설계/차수/파라미터(예: Elliptic Rp/Rs, Notch f0/BW/Q) 표시
  - 웨이블릿 연계(`RunWavelet`)
    - `WaveletUseFiltered`(기본 false → 원신호), `WaveletAskWindow`(기본 false), `WaveletSaveFig`, `WaveletFigFormats`
    - 결합 호출의 `Freq`가 있으면 wavelet의 `FreqSelect`로 전파
  - 출력 메타(MAT)
    - `filterType_used`, `filterDesign_used`, `filtOrder_used`, `filterMode_used`, `bandstopHz_used`, `notchQ_used` 등 기록

## Wavelet 표시 개선 사항 (`wavelet_sparam_window.m`)
- 주파수 선택: `FreqSelect` = 스칼라/벡터/`'all'` 지원(2행 시계열 다중 곡선)
- CWT(3행): 선택 집합 중 첫 번째 주파수 기준, 타이틀에 `@ xx.xx GHz` 표기
- 시간축 통일/링크: 1·2·3행 모두 같은 X축(절대시간 있으면 datenum↔datetick), 전체 범위 표시
- 데이터팁: 3행은 타임스탬프 포맷(yyyy‑MM‑dd HH:mm:ss.SSS), 1·2행은 기본 데이터팁 유지
- 온도 채널 구성: `TempChanConfig`(기본 TempDir/TempChannelSelection.csv) 사용, S11/S22 포트별 해석
- 기본 CWT 창: 사용자가 `T0` 미지정 시, 전체 시간의 20% 지점부터
- 주파수 표기: 범례/타이틀 모두 소수점 둘째 자리(`%.2f GHz`)로 통일
- If adding datasets, normalize column names and document them here.

---
If anything is unclear or you want help with the next step (e.g., autosave flags or dataset normalization), open an issue or ask in chat.
