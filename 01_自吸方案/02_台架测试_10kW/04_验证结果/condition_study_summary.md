# Testbench EGR Condition Study Summary

Date: 2026-06-08 12:42:51

## Scope

- Constant-current studies keep compressor flow fixed to the no-EGR bench reference for the selected current-density point.
- Constant-voltage studies first solve the no-EGR current for each voltage target, select the nearest no-EGR bench supply boundary once, and keep that external boundary fixed during the EGR scan.
- Constant-pO2-inlet study uses `pO2_ca_in` as target and solves air-flow scale after EGR is enabled.

## Inputs

- Constant-current j targets: [0.1 0.2 0.3] A/cm2.
- Constant-voltage targets: [0.8 0.775 0.75] V/cell.
- EGR grid: [0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5].

## Results

- Constant-current rows: 33.
- Constant-voltage solved rows: 33.
- Constant-pO2-inlet solved rows: 33.
- Unified criteria rows: 99.
- Normal-operation points: 69/99.
- Oxygen-limit points: 30.
- DQ60-map-extrapolation points: 46.

## Output Files

- `04_验证结果/condition_study_constant_current_egr_scan.csv`
- `04_验证结果/condition_study_constant_voltage_solved.csv`
- `04_验证结果/condition_study_constant_pO2_inlet_solved.csv`
- `04_验证结果/condition_study_unified_criteria.csv`
