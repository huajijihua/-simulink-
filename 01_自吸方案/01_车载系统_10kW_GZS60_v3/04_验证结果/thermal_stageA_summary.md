# Thermal Stage-A Summary

Date: 2026-06-05

## Scope

- Executable model: `01_模型/CEGR_Vehicle_10kW_GZS60_v03_stage1_pressurefix.slx`.
- Stage A fits the thermal side first and keeps humidity-side transfer parameters frozen.
- Cooling enhancement is modeled as `coolant_flow_L_min -> h_cool_eff`.
- Bench coolant heat removal is reconstructed with water-equivalent properties (`rho = 1.0 kg/L`, `cp = 4180 J/kg/K`).
- `C_stack_J_K` stays frozen in stage A.

## Metrics

- T_stack RMSE: 0.570 C.
- Q_cool RMSE: 635.2 W.
- Q_cool bias: 25.0 W.
- Steady points: 13/13.
- Pressure-order pass: 13/13.
- RH_ca_in RMSE (regression only): 0.133.
- V_cell RMSE (regression only): 0.0804 V/cell.
- Minimum lambda_O2_actual: 1.788.

## Cooling Curve

- Flow support count: 8.
- Ambient heat-loss coefficient: 9.000 W/K.
- Fallback cooling coefficient: 836.000 W/K.

## Notes

- Low-load point `bench_j0p10` gives negative bench coolant heat because `coolant_outlet_temp_C < coolant_inlet_temp_C`; it is retained for temperature regression but should not be treated as a hard heat-balance truth point.
- Stage B humidity fitting should start only after this thermal baseline is accepted.

## Output Files

- `04_验证结果/thermal_stageA_diagnostic.csv`
- `04_验证结果/thermal_stageA_candidate_grid.csv`
- `00_输入参数/标定参数/thermal_stageA_params.csv`
- `00_输入参数/标定参数/thermal_stageA_cooling_flow_curve.csv`
