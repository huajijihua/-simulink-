# Stage-1 Audit Calibration Summary

Date: 2026-06-04

## Scope

- Audit model was used as the executable system model.
- The audit SLX and init file were not overwritten.
- No-EGR full-current bench data were used for the first quantitative baseline.
- EGR outputs are fixed-total-flow low-load scans only, not quantitative EGR calibration.

## No-EGR Metrics

- Candidate accepted: true.
- Base V_cell RMSE: 0.09538 V/cell; selected: 0.10620 V/cell; candidate: 0.10620 V/cell.
- Base p_ca_in RMSE: 0.007 kPa; selected: 0.003 kPa; candidate: 0.003 kPa.
- pO2_in RMSE: 2.786 kPa; RH_in RMSE: 0.487; T_stack RMSE: 24.701 C.
- Steady points: 4/13; physical-ok points: 4/13.

## Important Boundary Note

- Bench cathode inlet pressure is used as a first-pass compressor pressure boundary.
- `cathode_flow_nlpm` is converted to an equivalent oxygen stoichiometry and compared with the table `cathode_stoich`.
- `p_stack_internal_kPa` is checked only as an internal pressure state, not as the bench inlet pressure.

## Output Files

- `04_验证结果/stage1_no_egr_calibration_diagnostic.csv`
- `00_输入参数/标定参数/stage1_boundary_calibrated_params.csv`
- `04_验证结果/stage1_egr_lowload_fixed_flow_scan.csv`
- `01_模型/CEGR_Vehicle_10kW_GZS60_v03_calibrated_stage1.slx`

## Parameter Candidates

- Optimized parameter count: 8.
- EGR scan rows: 25.
- Local search enabled: false; max function evaluations: 14.
