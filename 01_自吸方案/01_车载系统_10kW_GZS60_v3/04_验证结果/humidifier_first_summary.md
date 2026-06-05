# Humidifier-First No-EGR Summary

Date: 2026-06-05

## Scope

- Bench stack-inlet humidity is treated as a free bench boundary, not a vehicle humidifier target.
- Vehicle stack cathode inlet humidity is the humidifier dry-side outlet.
- No EGR cases are run in this review.

## Humidifier Four-Port Replay

- Four-port points: 25.
- Dry gain direction pass: 25/25.
- Wet loss direction pass: 25/25.
- Transfer limit pass: 25/25.
- Dry outlet omega RMSE: 24.14 g/kg.
- Wet outlet omega RMSE: 16.43 g/kg.
- Dry outlet RH RMSE: 36.62 pct.
- Dry outlet dewpoint RMSE: 7.49 C.
- Water transfer RMSE: 2.54 g/s.
- Dry/wet dp RMSE: 2.93 / 3.67 kPa.

## GZS60 Spec Check

- Dry outlet dewpoint: 62.61 C, spec 59.81 C, pass: true.
- Dry pressure drop: 9.61 kPa, spec 13.00 kPa, pass: true.
- Wet pressure drop: 12.78 kPa, spec 20.00 kPa, pass: true.

## Humidifier-First Candidate

- Selected candidate source: current_stageB.
- Candidate dry outlet dewpoint: 62.61 C, spec 59.81 C, pass: true.
- Candidate dry outlet omega RMSE: 24.14 g/kg.
- Candidate dry outlet dewpoint RMSE: 7.49 C.
- Candidate water transfer RMSE: 2.54 g/s.
- Candidate parameters are applied to `00_输入参数/标定参数/humidity_stageB_params.csv` for `current` mode.

## Vehicle No-EGR System Diagnostic

- Points: 13.
- Steady points: 13/13.
- Pressure-order pass: 13/13.
- T_stack RMSE: 0.588 C.
- V_cell RMSE: 0.0760 V/cell.
- Q_cool RMSE: 629.9 W.
- Vehicle-vs-bench RH RMSE: 0.122.
- Vehicle-vs-bench pH2O RMSE: 10.509 kPa.
- Minimum lambda_O2_actual: 1.788.

## Voltage State Audit

- Current vehicle-state V_cell RMSE: 0.0760 V/cell.
- Current vehicle-state V_cell max abs: 0.1553 V/cell.
- High-current points: 6.
- High-current V_cell bias: -0.1036 V/cell.
- High-current V_cell RMSE: 0.1104 V/cell.
- Voltage reconstruction max abs error: 0 V/cell.
- Stage2 internal-state fit available: true.
- Stage2 internal-state fit RMSE: 0.0036 V/cell.
- Stage2 internal-state fit scope: stage2_internal_state_no_egr.

## Decision

- Keep the humidifier-first order: four-port/spec acceptance -> vehicle stack-inlet boundary -> voltage state audit.
- Do not use bench stack-inlet RH as a hard vehicle humidifier target.
- Do not start EGR analysis until this no-EGR vehicle boundary is accepted.

## Output Files

- `04_验证结果/humidifier_first_four_port_replay.csv`
- `04_验证结果/humidifier_first_gzs60_spec_check.csv`
- `00_输入参数/标定参数/humidifier_first_params.csv`
- `00_输入参数/标定参数/humidity_stageB_params.csv`
- `04_验证结果/humidifier_first_no_egr_system_diagnostic.csv`
- `04_验证结果/humidifier_first_voltage_state_audit.csv`
