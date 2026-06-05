# v3 第一轮验证摘要

更新时间：2026-06-03

## 验证口径

- Simulink 模型为权威系统模型。
- 第一轮只验证恒电流无循环和恒电流有循环。
- 有循环代表工况使用 `egr_fraction = 0.1`。
- 尾气压力链已切到 `TailGasManifold + EGRValve + BackPressureValve + EGRReturnPipe`。

## 结果概览

| 工况 | EGR | I (A) | V_cell (V) | pO2_in (kPa) | xO2_in | pO2_ca (kPa) | m_fresh (kg/s) | m_egr (kg/s) | m_vent (kg/s) |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| cc_no_egr | 0.00 | 120.0 | 0.7673 | 30.522 | 0.2062 | 34.257 | 0.001384 | 0 | 0.002558 |
| cc_egr_0p1 | 0.10 | 120.0 | 0.7663 | 30.522 | 0.2062 | 33.295 | 0.001384 | 8.241e-05 | 0.002472 |

## 模块级检查

- 空压机升压升温且不改组分：PASS
- 中冷器降温降压且 O2/N2 守恒：PASS
- 加湿器干侧 O2/N2 守恒且增湿来自湿侧：PASS
- 电堆出口按库存总压和下游压力闭合：PASS
- 湿侧和分水器压降方向正确：PASS
- 尾气歧管和阀后压力不高于上游：PASS
- EGR 回空压机前无液态水：PASS

## 压力链路检查

- cc_no_egr：p_tailgas=188.827 kPa，p_downstream=189.853 kPa，dp_ca_out=217.276 kPa，dp_an_out=8.202 kPa，dp_hum_wet=0.874 kPa，dp_separator=0.152 kPa，dp_egr_valve=87.502 kPa，dp_bp_valve=87.502 kPa。
- cc_egr_0p1：p_tailgas=188.747 kPa，p_downstream=189.772 kPa，dp_ca_out=217.013 kPa，dp_an_out=8.202 kPa，dp_hum_wet=0.873 kPa，dp_separator=0.152 kPa，dp_egr_valve=87.422 kPa，dp_bp_valve=87.422 kPa。
- 尾气压力链闭合误差 <= 1e-9 kPa：PASS

## 第一轮趋势检查

- EGR 后入堆氧分压下降：PASS
- EGR 后入堆氧摩尔分数下降：PASS
- EGR 后电堆阴极氧分压下降：PASS
- 恒电流 EGR 后电压不升高：PASS
- 电压分项均为有限值：PASS
- 电压分项闭合误差 <= 1e-9 V：PASS
- 膜含水升高时欧姆损失不增大：FAIL
- 物种级最大守恒残差 <= 1e-8 kg/s：PASS
- 电堆能量残差字段闭合：PASS
- 无 EGR / 有 EGR 新鲜空气质量流：0.001384 / 0.001384 kg/s
- 无 EGR / 有 EGR 回流质量流：0 / 8.241e-05 kg/s

## 残差与热项审计

- cc_no_egr：阴极最大 1.46e-18 kg/s，阳极最大 6.78e-21 kg/s，能量残差 -2.95e-10 W。
- cc_egr_0p1：阴极最大 1.14e-18 kg/s，阳极最大 6.78e-21 kg/s，能量残差 4.32e-11 W。
- 热项重构 `Q_gen - Q_cool - Q_amb - Q_gas` 与 `Q_net_stack_W` 误差：0 / 0 W

## 当前限制

- 本轮仍是低维系统模型，不宣称 GZS60 已完成四口定量标定。
- 阀流仍为低维压差驱动比例模型，不是可压缩详细阀模型。
- 旧 13 点极化拟合参数和检查结果已删除；电压模型已切换到新书公式结构，等待重新标定。
- 无 EGR 13 点压力链定量标定 helper 仍需在数据口径进一步确认后补强。
