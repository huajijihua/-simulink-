# Combined No-EGR and CEGR Fitting Dataset

Active runtime table:

- `00_输入参数/实验数据/combined_noegr_cegr_fit_points.csv`: the only active case table for fitting, replay, and audit.
- The table contains 13 initial no-EGR points and 16 CEGR 0608 points.

Key pressure note:

- Cathode inlet pressure is read directly from `stack_in_p_kPa`.
- Cathode outlet pressure is read directly from `stack_out_p_kPa`.
- `cegr0608_015` and `cegr0608_016` originally lacked `stack_out_p_kPa`; they are completed from similar CEGR rows using `bench_out_p_kPa + 0.65 kPa`, giving 28.95 kPa and 29.25 kPa.
- `cathode_dp_kPa = stack_in_p_kPa - stack_out_p_kPa` is added for all rows where both pressures exist.
- In the 13 original no-EGR points, cathode pressure drop rises from 7.5 kPa at low current to 55.3 kPa at 722 A / 1.9 A/cm2. This must be treated as a key boundary/validation value, especially at high current density.

Boundary completion note:

- CEGR 0608 rows use the same anode-side conditions as the no-EGR point at the matching current density when the source row has no anode measurements.
- CEGR 0608 rows use the same coolant flow as the no-EGR point at the matching current density when the source row has no coolant-flow measurement.
- The 20 A / 0.05 A/cm2 supplement has no exact initial no-EGR current-density pair in this active table, so it uses the nearest low-load no-EGR point (`initial_noegr_01`, 0.1 A/cm2) for anode-side and coolant-flow completion.
- EGR rows require return-branch temperature and pressure for the separator node. Missing return measurements are completed from similar CEGR points: `cegr0608_002` from the nearest same-series low-EGR point, `cegr0608_010` by interpolation between neighboring low-stoich CEGR points, and `cegr0608_014` from the nearest low-EGR 38 A / 2000 rpm point. `cegr0608_007` return RH is filled as saturated. No-EGR rows do not require return-branch temperature, pressure, or RH.
- No-EGR cases do not pass through the separator. Separator temperature and pressure retained by the initializer for no-EGR rows are initialization placeholders only, not active gas-path boundaries.

Stoichiometry note:

- `nominal_cathode_stoich_group` and `nominal_cathode_stoich_group_filled` are design/group labels, not model runtime boundaries.
- `actual_cathode_stoich_noegr` is calculated only for no-EGR rows from measured stack inlet flow, inlet pressure, inlet temperature, inlet RH, current, and dry-air composition.
- EGR rows leave `actual_cathode_stoich_noegr` blank because the inlet oxygen fraction must be calculated by the model from mixed fresh and recirculated gas.
- Runtime setup uses stack inlet mass flow, stack inlet temperature, stack inlet pressure, cathode supply mass fractions, anode inlet mass flow and mass fractions, and EGR fraction; it does not use cathode stoichiometry as an input boundary.
- For EGR cases, runtime separator boundaries use `egr_return_T_C` and `egr_return_p_kPa`; `egr_return_RH_pct` is not passed into the Simulink parameter interface because separator humidity is derived from the return gas composition.
- `egr_valve_target_pct`, `egr_valve_input_pct`, return RH, source labels, parse notes, and raw valve diagnostics remain outside the Simulink runtime parameter interface.

Voltage note:

- For the initial no-EGR workbook, `cell_voltage_V` is computed as total stack voltage divided by 16 cells to stay consistent with the existing initialization script. The workbook's bar-chart average cell voltage is retained as `cell_voltage_bar_avg_V` for audit.

Summary:

```json
{
  "initial_noegr_points": 13,
  "cegr_0608_points": 16,
  "combined_points": 29,
  "initial_noegr_cathode_dp_kPa_min": 7.5,
  "initial_noegr_cathode_dp_kPa_max": 55.3,
  "max_dp_case": "initial_noegr_13",
  "max_dp_current_A": "722",
  "max_dp_current_density_A_cm2": "1.9"
}
```
