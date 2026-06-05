# GZS80P四口水量一致性审计

本审计逐点比较干侧增水量和湿侧失水量，用于决定加湿器标定时能否同时约束干/湿两侧。

## Summary

- Points: 6
- Max absolute water-balance residual: 1.422 g/s
- Max relative water-balance error: 39.1 %
- Dual-side fit candidate points: 3
- Dry-priority-only points: 3
- Trend-reference-only points: 0

## Per-point audit

- 1425 slpm: dry gain 3.213 g/s, wet loss 1.958 g/s, residual 1.256 g/s, relative 39.1 %, use `dry_priority_only`, issue `low_flow_and_water_balance_risk`.
- 2895 slpm: dry gain 4.583 g/s, wet loss 3.329 g/s, residual 1.254 g/s, relative 27.4 %, use `dry_priority_only`, issue `no_major_issue`.
- 3619 slpm: dry gain 4.929 g/s, wet loss 3.507 g/s, residual 1.422 g/s, relative 28.8 %, use `dry_priority_only`, issue `no_major_issue`.
- 4000 slpm: dry gain 6.345 g/s, wet loss 5.126 g/s, residual 1.219 g/s, relative 19.2 %, use `dual_side_fit_candidate`, issue `no_major_issue`.
- 5000 slpm: dry gain 6.102 g/s, wet loss 5.821 g/s, residual 0.280 g/s, relative 4.6 %, use `dual_side_fit_candidate`, issue `no_major_issue`.
- 6000 slpm: dry gain 5.542 g/s, wet loss 6.539 g/s, residual -0.998 g/s, relative 15.3 %, use `dual_side_fit_candidate`, issue `no_major_issue`.

## Modeling use

- `dual_side_fit_candidate`: may be used to constrain both dry outlet and wet outlet humidity.
- `dry_priority_only`: use dry outlet for stack-inlet RH calibration; wet outlet tail-gas result should be bounded.
- `trend_reference_only`: keep for trend review only; do not use as quantitative calibration anchor.
