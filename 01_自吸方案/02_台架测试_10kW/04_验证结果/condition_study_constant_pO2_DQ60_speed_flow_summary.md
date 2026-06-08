# DQ60 Constant-pO2 Study Summary

Date: 2026-06-08 10:19:50

## Scope

- Model: `CEGR_TestBench_10kW_v01_pO2_DQ60.slx`.
- Target: same-current no-EGR `pO2_ca_in_kPa`.
- Search variables: cathode flow scale and DQ60 speed, with DQ60 map retained.

## Inputs

- Current-density targets: [0.1 0.2 0.3] A/cm2.
- EGR grid: [0 0.05 0.1 0.15 0.2 0.25 0.3 0.35 0.4 0.45 0.5].

## Results

- Rows: 33.
- Solved within DQ60 map: 3.
- Near target / review: 8.
- Best-effort unreachable: 20.
- Normal-operation rows: 1/33.

## Output

- `04_验证结果/condition_study_constant_pO2_DQ60_speed_flow.csv`
