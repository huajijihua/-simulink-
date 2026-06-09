# Combined No-EGR and CEGR Fitting Dataset

Sources:

- Initial no-EGR steady bench workbook: `E:\Codex\agentwork_pemfc_cEGR_0519\00_支撑材料\实验数据-设备说明书\10kw电堆台架稳态测试数据整理.xlsx`
- CEGR 0608 text extraction: `E:\Codex\agentwork_pemfc_cEGR_0519\01_自吸方案\03_台架测试_10kW_简化版\00_输入参数\实验数据\cegr_0608_fit_points.csv`

Generated files:

- `noegr_initial_13_points.csv`: 13 original no-EGR direct bench-to-stack points.
- `combined_noegr_cegr_fit_points.csv`: union table for later fitting, with the 13 original no-EGR points plus 16 CEGR 0608 points.

Key pressure note:

- The original no-EGR workbook records both cathode inlet and cathode outlet pressure. Both are preserved as `stack_in_p_kPa` and `stack_out_p_kPa`.
- `cathode_dp_kPa = stack_in_p_kPa - stack_out_p_kPa` is added for all rows where both pressures exist.
- In the 13 original no-EGR points, cathode pressure drop rises from 7.5 kPa at low current to 55.3 kPa at 722 A / 1.9 A/cm2. This must be treated as a key boundary/validation value, especially at high current density.

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
