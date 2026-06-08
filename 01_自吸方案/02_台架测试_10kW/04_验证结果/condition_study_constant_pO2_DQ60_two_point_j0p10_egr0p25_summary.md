# DQ60 Constant-pO2 Two-Point Summary

Date: 2026-06-08 09:57:07

## Scope

- Model: `CEGR_TestBench_10kW_v01_pO2_DQ60.slx`.
- Study mode: two-point comparison using the same DQ60 flow-compensation search logic as the grid study.
- Baseline: 0.1 A/cm2, EGR = 0.
- Representative point: 0.1 A/cm2, EGR = 0.25, solved for minimum stable DQ60 flow compensation.
- Target: compare EGR=0.25 against same-current no-EGR `pO2_ca_in_kPa`.

## Key Comparison

- Baseline pO2_ca_in: 26.4314 kPa.
- EGR=0.25 pO2_ca_in: 25.3307 kPa; delta: -1.1006 kPa.
- EGR=0.25 DQ60 operating point: 86.0 L/min at 3000 rpm; flow scale = 1.500; map-ok = 1.
- EGR=0.25 voltage delta vs baseline: 0.002666 V/cell.
- EGR=0.25 risk label: `pO2_target_miss`; normal operation = 0.

## Outputs

- `04_验证结果/condition_study_constant_pO2_DQ60_two_point_j0p10_egr0p25.csv`
- `04_验证结果/condition_study_constant_pO2_DQ60_two_point_j0p10_egr0p25_comparison.csv`

- Full rows: 2.
