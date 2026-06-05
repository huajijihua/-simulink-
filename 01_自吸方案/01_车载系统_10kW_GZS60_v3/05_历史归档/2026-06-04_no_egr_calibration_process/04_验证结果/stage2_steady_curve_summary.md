# Stage-2 Steady Curve Fit Summary

Date: 2026-06-04

## Scope

- Stage-1 pressure/flow coefficients are fixed.
- Voltage parameters are fitted against simulated internal stack states.
- Thermal and humidity parameters are scanned after voltage fitting.

## Metrics

- V_cell RMSE: base 0.10222, post-voltage 0.00725, final 0.01852 V/cell.
- T_stack RMSE: base 28.894, post-voltage 23.965, final 17.904 C.
- RH_ca_in RMSE: base 0.491, post-voltage 0.490, final 0.137.
- Final steady points: 5/13.
- Final pressure-order pass: 13/13.

## Outputs

- `E:\agentwork_pemfc_cEGR_0519\01_自吸方案\01_车载系统_10kW_GZS60_v3\04_验证结果\stage2_no_egr_steady_curve_diagnostic.csv`
- `E:\agentwork_pemfc_cEGR_0519\01_自吸方案\01_车载系统_10kW_GZS60_v3\00_输入参数\电堆物理模型\stack_voltage_book_fit_params_stage2.csv`
- `E:\agentwork_pemfc_cEGR_0519\01_自吸方案\01_车载系统_10kW_GZS60_v3\00_输入参数\标定参数\stage2_thermal_humidity_calibrated_params.csv`
