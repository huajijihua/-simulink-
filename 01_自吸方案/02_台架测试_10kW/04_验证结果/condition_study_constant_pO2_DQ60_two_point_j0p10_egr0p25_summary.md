# DQ60 Constant-pO2 Two-Point Summary

Date: 2026-06-07 13:14:49

## Scope

- Model: `CEGR_TestBench_10kW_v01_pO2_DQ60.slx`.
- Study mode: no grid search; only two requested operating points are simulated.
- Baseline: 0.1 A/cm2, EGR = 0.
- Representative DQ60 point: 0.1 A/cm2, EGR = 0.25, flow scale = 4.0, speed = 4000 rpm.
- Target: compare EGR=0.25 against same-current no-EGR `pO2_ca_in_kPa`.

## Key Comparison

- Baseline pO2_ca_in: 26.4314 kPa.
- EGR=0.25 pO2_ca_in: 26.5117 kPa; delta: 0.0804 kPa.
- EGR=0.25 DQ60 operating point: 229.3 L/min at 4000 rpm; map-ok = 1.
- EGR=0.25 voltage delta vs baseline: -0.000419 V/cell.
- EGR=0.25 risk label: `oxygen_limit`; normal operation = 0.

## Outputs

- `04_验证结果/condition_study_constant_pO2_DQ60_two_point_j0p10_egr0p25.csv`
- `04_验证结果/condition_study_constant_pO2_DQ60_two_point_j0p10_egr0p25_comparison.csv`

- Full rows: 2.
