# Humidity Stage-B Summary

Date: 2026-06-05

## Scope

- Executable model: `01_模型/CEGR_Vehicle_10kW_GZS60_v03_stage1_pressurefix.slx`.
- Stage B uses the pressurefix + thermal Stage-A baseline.
- Main fitting targets are stack-inlet `pH2O_caIn_kPa` and `xH2O_caIn` under 13 no-EGR steady points.
- Humidifier four-port data are used as secondary prior constraints, not equal-weight primary targets.
- First-round free parameters are `hum_NTU_ref`, `hum_flow_exp`, and `hum_mem_D_eff_m2_s`.

## Base Metrics

- Base pH2O_caIn RMSE: 7.894 kPa.
- Base xH2O_caIn RMSE: 0.03640.
- Base RH_ca_in RMSE: 0.133.
- Base prior dry/wet omega RMSE: 71.39 / 56.24 g/kg.

## Candidate Metrics

- Candidate accepted: true.
- Candidate pH2O_caIn RMSE: 4.500 kPa.
- Candidate xH2O_caIn RMSE: 0.02171.
- Candidate RH_ca_in RMSE: 0.166.
- Candidate prior dry/wet omega RMSE: 71.92 / 56.52 g/kg.
- Candidate transfer RMSE: 7.97 g/s.
- Candidate T_stack RMSE: 0.585 C.
- Candidate V_cell RMSE: 0.0735 V/cell.
- Candidate pressure-order pass: 13/13.

## Acceptance Guards

- T_stack allowed increase: 0.500 C.
- V_cell allowed increase: 0.030 V/cell.
- Q_cool allowed increase: 1200.0 W.

## Output Files

- `04_验证结果/humidity_stageB_no_egr_diagnostic.csv`
- `04_验证结果/humidity_stageB_hum_prior_replay.csv`
- `04_验证结果/humidity_stageB_candidate_trace.csv`
- `00_输入参数/标定参数/humidity_stageB_params.csv`

## Parameters

- `hum_NTU_ref = 0.215343` (initial 0.47854).
- `hum_flow_exp = 0.37998` (initial 0.37998).
- `hum_mem_D_eff_m2_s = 1.25e-09` (initial 1e-09).
