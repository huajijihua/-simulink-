# CEGR_Vehicle_10kW_GZS60_v03 当前标定准备说明

更新时间：2026-06-08

## 1. 当前对象

车载结构当前主模型：

```text
01_模型/CEGR_Vehicle_10kW_GZS60_v03_stage1_pressurefix.slx
```

车载结构当前压力标定脚本：

```text
02_脚本/init_vehicle_10kw_gzs60_v3.m
02_脚本/calibrate_vehicle_10kw_gzs60_v3_pressurefix_stage1.m
```

早期工作模型和对应脚本不作为当前主线依据。后续判断以当前 `pressurefix` 车载基线、台架主模型和项目收尾检查说明为准。

## 2. 二周目目标

二周目不是复刻一周目的完整三阶段拟合流程。当前目标是：

```text
先修正电堆模块压力传递语义，再只重拟合压力/流量链参数。
```

已确认边界：

- 阴/阳极流道体积按几何量级固定，不再用稳态误差反向调大。
- `p_stack_internal_kPa` 只作为电堆内部库存压力诊断。
- 阴极出口节点压力 `caOut(6)` 为出口背压边界 `pcBack`。
- 阳极出口节点压力 `anOut(6)` 为出口背压边界 `panBack`。
- 湿度、电压、热量参数先沿用一周目结论做回归检查，不主动重拟合。

## 3. 压力验收口径

主拟合对象：

```text
p_ca_in_meas_kPa 对 p_ca_in_sim_kPa = humidifier_dry_node(6)
```

硬约束：

```text
p_ca_in_sim_kPa > p_stack_internal_kPa > p_ca_out_boundary_kPa
```

边界核对：

```text
p_ca_out_boundary_kPa = 台架阴极出口压力绝对值
```

辅助检查：

- 出口边界误差应为 0 或接近 0；
- 阴极压降随负荷应保持合理方向；
- `lambda_O2_actual` 不得低于不可接受线；
- 湿度、电压、温度只做回归风险标记。

## 4. 当前结果

当前输出文件：

```text
04_验证结果/pressurefix_stage1_no_egr_diagnostic.csv
04_验证结果/pressurefix_stage1_candidate_no_egr_diagnostic.csv
04_验证结果/pressurefix_stage1_summary.md
00_输入参数/标定参数/pressurefix_stage1_boundary_params.csv
```

当前压力验收：

- 13 点无 EGR 压力顺序：13/13
- `p_ca_in` RMSE：0.010847 kPa
- 出口边界最大误差：0 kPa
- `min(p_ca_in_sim - p_stack_internal) = 3.4265 kPa`
- `min(p_stack_internal - p_ca_out_boundary) = 4.0733 kPa`
- `min(lambda_O2_actual) = 1.2999`

当前回归风险：

- `V_cell RMSE = 0.005644 V/cell`
- `RH_ca_in RMSE = 0.188`
- `T_stack RMSE = 18.692 C`
- 原严格稳态窗口通过 5/13，高负荷热动态仍需后续单独复核。

## 5. 后续标定路线

建议路线：

1. 固定 `stage1_pressurefix` 的压力语义和压力链参数；
2. 先复核热动态稳态窗口与仿真时长；
3. 如热湿偏差不可接受，只局部修正热湿参数；
4. 电压参数在压力、氧分压和温度输入稳定后再复核；
5. 有 EGR 情况仍缺少定量台架数据，不进入定量标定，只能做敏感性或趋势分析。
