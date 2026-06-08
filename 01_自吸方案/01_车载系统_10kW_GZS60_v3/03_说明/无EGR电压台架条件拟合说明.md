# 无 EGR 电压台架条件拟合说明

日期：2026-06-08

## 口径

- 电压拟合只使用台架电堆测试条件。
- 输入条件来自 `full_range_polarization_data.csv`：电流、堆温、氢气分压、氧气分压、入口水蒸气分压和 RH。
- 车载加湿器、空压机、中冷器和冷却辅件不进入电压拟合目标。
- 电压公式已按书上 `theta1-theta10` 直写。
- 候选参数只单独保存，不覆盖当前已应用电压参数。
- 候选参数进入整车结构后只做定性回归检查：趋势和值域不能明显离谱，不把整车误差作为拟合目标。

## 结果

详见：

```text
04_验证结果\stack_voltage_bench_condition_fit_summary.md
```

候选参数：

```text
00_输入参数\电堆物理模型\stack_voltage_book_theta_params_candidate.csv
```
