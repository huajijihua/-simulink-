# Testbench Thermal Stage-A Summary

Date: 2026-06-08

## Scope

- Executable model: `01_模型/CEGR_TestBench_10kW_v01.slx`.
- Uses the existing `PEMFCStackCore` lumped thermal model.
- Fits a bench-specific `coolant_flow_L_min -> h_cool_eff` curve from 13 no-EGR steady points.
- Coolant heat target uses `abs(rho * cp * flow * (T_cool_out - T_cool_in))`; the signed heat is retained in diagnostics.
- Stack temperature is inferred from the current engineering relation `T_ca_out = T_stack + 3 C`.
- Curve support excludes points with `T_stack_fit - T_cool_in < 2.5 C`; those points are retained only as diagnostics because small thermal drive amplifies h_cool noise.

## Metrics Before Applying Bench Curve

- Prior Q_cool RMSE vs bench coolant heat: 1000.8 W.
- Prior Q_cool bias vs bench coolant heat: -861.1 W.
- T_ca_out relation residual by construction: 0.00 C.
- Flow support count: 7.

## Accepted Parameters

- Fallback h_cool_W_K: 1156.467 W/K.
- h_amb_W_K retained: 9.000 W/K.
- C_stack_J_K retained: 45000.000 J/K.

## Output Files

- `04_验证结果/testbench_thermal_stageA_diagnostic.csv`
- `04_验证结果/testbench_thermal_stageA_summary.md`
- `00_输入参数/标定参数/testbench_thermal_stageA_params.csv`
- `00_输入参数/标定参数/testbench_thermal_stageA_cooling_flow_curve.csv`

## Notes

- Low-load coolant deltaT may be negative in the source data. Stage A uses heat-removal magnitude for the curve and keeps the signed value visible for review.
- This is a cooling-side calibration only. It does not claim the cathode outlet gas temperature relation is physically final.
