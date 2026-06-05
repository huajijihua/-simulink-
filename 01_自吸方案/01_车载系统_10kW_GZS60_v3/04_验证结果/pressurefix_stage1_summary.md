# Pressurefix Stage-1 Calibration Summary

Date: 2026-06-05

## Scope

- `CEGR_Vehicle_10kW_GZS60_v03_stage1_pressurefix.slx` was used as the executable system model.
- Stack cathode/anode channel volumes are fixed at geometry-scale values.
- Cathode and anode outlet node pressures are boundary pressures; internal stack pressures remain diagnostics only.
- No-EGR full-current bench data were used for pressure/flow boundary fitting.
- Humidity, voltage, and heat parameters are reused from the previous fit and are checked by regression, not refitted here.

## No-EGR Metrics

- Candidate accepted: true.
- Base V_cell RMSE: 0.01715 V/cell; selected: 0.00564 V/cell; candidate: 0.00564 V/cell.
- Base p_ca_in RMSE: 0.007 kPa; selected: 0.011 kPa; candidate: 0.011 kPa.
- Candidate steady points: 5/13; candidate physical-ok points: 5/13.
- Base pressure-order failures: 0; candidate pressure-order failures: 0.
- pO2_in RMSE: 0.557 kPa; RH_in RMSE: 0.188; T_stack RMSE: 18.692 C.
- Steady points: 5/13; physical-ok points: 5/13.

## Important Boundary Note

- Bench cathode inlet pressure is used as a first-pass compressor pressure boundary.
- `cathode_flow_nlpm` is converted to an equivalent oxygen stoichiometry and compared with the table `cathode_stoich`.
- `p_stack_internal_kPa` is checked only as an internal pressure state, not as the bench inlet pressure.

## Output Files

- `04_验证结果/pressurefix_stage1_no_egr_diagnostic.csv`
- `00_输入参数/标定参数/pressurefix_stage1_boundary_params.csv`
- `01_模型/CEGR_Vehicle_10kW_GZS60_v03_stage1_pressurefix.slx`

## Parameter Candidates

- Optimized parameter count: 5.
- Local search enabled: false; max function evaluations: 14.
