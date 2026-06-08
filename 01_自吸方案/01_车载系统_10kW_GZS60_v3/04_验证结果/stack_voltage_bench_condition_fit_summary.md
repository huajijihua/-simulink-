# Bench-Condition Stack Voltage Fit Summary

Date: 2026-06-08

## Scope

- Voltage fitting uses bench stack test conditions only.
- The vehicle humidifier, compressor, intercooler and cooling auxiliaries are not fitting targets.
- The voltage equation keeps direct book theta form, but the fit is physically constrained.
- `theta3` keeps the book sign and is intentionally amplified to retain oxygen-concentration sensitivity.
- The ohmic branch is anchored to the BT3564 stack resistance converted to per-cell resistance.
- Accepted candidate auto-applied: true.

## Formula

- `V_cell = V_nt - V_act - V_ohm - V_conc`
- `V_nt = 1.229 - 8.5e-4*(T_st - 298.15) + R*T_st/(2F)*ln(pH2*sqrt(pO2))`
- `V_act = theta1 + theta2*T_st + theta3*T_st*ln(C_O2) + theta4*T_st*ln(I_st)`
- `C_O2 = 1.97e-7*pO2*exp(498/T_st)`
- `V_ohm = I_st*(L_m/(A_cell*(theta5*lambda_m+theta6)*exp(theta7*(1/303.15-1/T_st))) + theta8)`
- `V_conc = theta9*exp(theta10*I_st)`

## Bench Condition Fit

- Raw book reference RMSE: 5.4302 V/cell, high-current bias -5.1359 V/cell.
- Current applied params RMSE: 0.0093 V/cell, high-current bias 0.0015 V/cell.
- Oxygen-constrained refit RMSE: 0.0093 V/cell, high-current bias 0.0015 V/cell.
- Selected candidate: oxygen_constrained_refit (oxygen-constrained fit passes error, sign and ohmic gates).
- Selected RMSE: 0.0093 V/cell, max abs 0.0295 V/cell.
- Selected ohmic resistance RMSE: 3.02934e-06 ohm/cell.
- Selected mean ohmic resistance: 0.000305205 ohm/cell; bench target mean 0.000304327 ohm/cell.
- Selected max positive voltage step: 0.0000 V/cell.
- Selected terms physical: true.

## Parameter Movement

- theta1: 0.7084 -> 0.0002875354 -> 0.0002875354.
- theta2: 0.00143 -> 0.00036268845 -> 0.00036268845.
- theta3: -0.0001527 -> -0.00022905 -> -0.00022905.
- theta4: 0.0001043 -> 4.9406565e-324 -> 4.9406565e-324.
- theta5: 0.525 -> 0.525 -> 0.525.
- theta6: 0.2173 -> 0.2173 -> 0.2173.
- theta7: -302.06 -> -302.06 -> -302.06.
- theta8: 0.000513 -> 0.00029762048 -> 0.00029762048.
- theta9: 5.2e-10 -> 7.8008974e-05 -> 7.8008974e-05.
- theta10: 0.0335 -> 3.1576485e-20 -> 3.1576485e-20.

## Decision

- Decision: bench_condition_voltage_refit_candidate_accepted.
- Accepted candidate is applied to `00_输入参数/电堆物理模型/stack_voltage_book_theta_params.csv`.
- Do not fit voltage parameters against vehicle auxiliary boundary errors.

## Output Files

- `04_验证结果/stack_voltage_bench_condition_fit_diagnostic.csv`
- `04_验证结果/stack_voltage_bench_condition_fit_candidates.csv`
- `04_验证结果/stack_voltage_oxygen_sensitivity_check.csv`
- `04_验证结果/stack_voltage_bench_candidate_vehicle_check.csv`
- `00_输入参数/电堆物理模型/stack_voltage_book_theta_params_candidate.csv`
- `00_输入参数/电堆物理模型/stack_voltage_book_theta_params.csv`
