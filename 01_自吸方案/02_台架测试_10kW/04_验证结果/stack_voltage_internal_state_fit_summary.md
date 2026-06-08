# Internal-State Stack Voltage Fit Summary

Date: 2026-06-08

## Scope

- Voltage fitting uses the same internal states consumed by the Simulink PEMFCStackCore voltage equations.
- Low-current points are deliberately up-weighted: j <= 0.3 A/cm2 weight 4, 0.3 < j <= 0.7 weight 2, higher current weight 1.
- theta5/theta6/theta7 and theta9/theta10 are kept from the current applied parameter set.
- Accepted candidate auto-applied: true.

## Metrics

- Book reference weighted RMSE: 4.0076 V/cell; unweighted RMSE 5.4414 V/cell.
- Current applied weighted RMSE: 0.0269 V/cell; unweighted RMSE 0.0277 V/cell.
- Internal-state weighted refit weighted RMSE: 0.0068 V/cell; unweighted RMSE 0.0063 V/cell.
- Internal-state low-current RMSE: 0.0076 V/cell; low-current max abs 0.0097 V/cell.
- Internal-state high-current bias: -0.0059 V/cell; high-current RMSE 0.0061 V/cell.
- Internal-state max abs error: 0.0097 V/cell.
- Internal-state max positive voltage step: 0.0000 V/cell.
- Internal-state terms physical: true.

## Parameter Movement

- theta1: 0.7084 -> 0.0002875354 -> 0.074471341.
- theta2: 0.00143 -> 0.00036268845 -> 0.
- theta3: -0.0001527 -> -0.00022905 -> -0.00020282872.
- theta4: 0.0001043 -> 4.9406565e-324 -> 4.2016611e-05.
- theta5: 0.525 -> 0.525 -> 0.525.
- theta6: 0.2173 -> 0.2173 -> 0.2173.
- theta7: -302.06 -> -302.06 -> -302.06.
- theta8: 0.000513 -> 0.00029762048 -> 0.00024301954.
- theta9: 5.2e-10 -> 7.8008974e-05 -> 7.8008974e-05.
- theta10: 0.0335 -> 3.1576485e-20 -> 3.1576485e-20.

## Output Files

- `04_验证结果/stack_voltage_internal_state_fit_diagnostic.csv`
- `04_验证结果/stack_voltage_internal_state_fit_candidates.csv`
- `04_验证结果/stack_voltage_internal_state_fit_summary.md`
- `00_输入参数/电堆物理模型/stack_voltage_book_theta_params_internal_state_candidate.csv`
- `00_输入参数/电堆物理模型/stack_voltage_book_theta_params.csv`
