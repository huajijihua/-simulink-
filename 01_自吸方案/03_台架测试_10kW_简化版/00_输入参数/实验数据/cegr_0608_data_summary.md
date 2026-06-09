# CEGR 0608 Extracted Test Points

Source: `E:\Codex\agentwork_pemfc_cEGR_0519\00_支撑材料\实验数据-设备说明书\PEMFCCEGR0608.txt`

Generated files:

- `cegr_0608_points_raw_clean.csv`: cleaned table preserving the extracted source fields.
- `cegr_0608_fit_points.csv`: reduced fitting table with unified EGR fraction and key model boundary fields.

Counts:

- Total points: 16
- No-EGR points: 4
- EGR points: 12

Nominal stoich groups:

```json
{
  "5.0": {
    "total": 7,
    "no_egr": 1,
    "egr": 6
  },
  "4.0": {
    "total": 5,
    "no_egr": 1,
    "egr": 4
  },
  "3.0": {
    "total": 2,
    "no_egr": 1,
    "egr": 1
  },
  "blank": {
    "total": 2,
    "no_egr": 1,
    "egr": 1
  }
}
```

Parsing policy:

- `egr_fraction_model` priority: calibrated EGR percent, raw EGR percent, return flow / stack inlet flow, then (stack inlet flow - bench supply flow) / stack inlet flow.
- `cell_voltage_V` is kept as the fitting voltage target. `total_voltage_V` is preserved but should be audited before use.
- Non-numeric cells such as duplicated decimal points are left blank and recorded in `parse_notes`.
- Pressure units follow the source table labels. No gauge/absolute conversion is applied in these CSVs.


20 A supplement stoich check:

- `cegr0608_015` EGR point: stack inlet flow 28.4 SLPM gives `lambda_from_stack_in_flow = 5.34858`. Bench fresh supply flow is 16.3 SLPM and is retained as a boundary flow magnitude only; its derived lambda is reference-only and should not be used as the mixed-gas oxygen stoich for fitting. The point is assigned to nominal stoich group 5 for pairing with the 20 A no-EGR point.
- `cegr0608_016` no-EGR point: stack inlet flow 26.4 SLPM gives `lambda_from_stack_in_flow = 4.97192`, so the point is nominal stoich group 5.

Added derived columns to both CSV tables:

- `lambda_from_stack_in_flow`
- `lambda_from_bench_supply_flow` (reference only; do not use as mixed-gas oxygen stoich for fitting)
- `nominal_cathode_stoich_group_filled`
- `stoich_basis_note`


Fitting note: fresh-air-flow lambda is not a fitting target. For EGR cases, effective oxygen supply should come from model-simulated mixed gas composition plus measured stack inlet total flow; bench fresh supply flow is only a boundary magnitude entering the mixer.
