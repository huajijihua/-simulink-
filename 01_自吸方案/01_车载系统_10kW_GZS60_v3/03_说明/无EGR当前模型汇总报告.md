# 无 EGR 当前模型汇总报告

日期：2026-06-05

## 1. 报告目的

本报告用于在进入 EGR 机理趋势分析前，先把当前无 EGR 模型状态说清楚：

- 当前模型的物理边界和抽象层级；
- 模块链路、变量传递和主要状态量；
- 当前恒电流无 EGR 标定/验证结果；
- 当前模型已经可以支持的分析；
- 当前模型暂时不能支撑的结论；
- 后续无 EGR 热侧、湿侧、电压和恒电压工况分析的推荐顺序。

本报告不替代模型文件和标定脚本，数值结果以当前验证输出 CSV 和 summary 文件为准。

## 2. 当前工作基线

当前唯一工作模型为：

```text
01_模型/CEGR_Vehicle_10kW_GZS60_v03_stage1_pressurefix.slx
```

当前初始化和标定入口为：

```text
02_脚本/init_vehicle_10kw_gzs60_v3.m
02_脚本/calibrate_vehicle_10kw_gzs60_v3_pressurefix_stage1.m
02_脚本/calibrate_vehicle_10kw_gzs60_v3_thermal_stageA.m
02_脚本/calibrate_vehicle_10kw_gzs60_v3_humidity_stageB.m
```

当前默认 `current` 模式已接入：

```text
00_输入参数/标定参数/pressurefix_stage1_boundary_params.csv
00_输入参数/标定参数/thermal_stageA_params.csv
00_输入参数/标定参数/thermal_stageA_cooling_flow_curve.csv
00_输入参数/标定参数/humidity_stageB_params.csv
00_输入参数/电堆物理模型/stack_voltage_book_fit_params_stage2.csv
```

当前验证结果主要来自：

```text
04_验证结果/pressurefix_stage1_no_egr_diagnostic.csv
04_验证结果/thermal_stageA_diagnostic.csv
04_验证结果/humidity_stageB_no_egr_diagnostic.csv
```

## 3. 建模理念和边界

当前无 EGR 模型采用系统级低维物理模型，不追求三维场分布，也不把所有辅件都展开成详细机理模型。

当前建模口径如下：

- 抽象层级：稳态/准稳态系统分析，保留物质流、压力流、能量流在模块间的传递和变化。
- 电堆核心：不做黑箱简化，保留阴极 O2、阴极 N2、阴极 H2O、阳极 H2、阳极 H2O 五个气体质量状态，以及一个集总电堆热状态。
- 压力：电堆内部压力由理想气体库存计算；模块节点压力作为边界压力传递。
- 流量：当前无 EGR 标定阶段以空压机总供气流量/等效氧过量系数为主要空气侧边界。
- 电压：采用书籍形式的单片电压模型，结构为 `V_cell = E_rev - eta_act - eta_ohm - eta_con`。
- 加湿器：采用集总干湿侧膜传水/传热模型，用实验数据半定量约束。
- 辅件：空压机、中冷器、背压边界等采用系统级简化模型。
- 缺乏数据支撑的模块：只作为定性或半定量分析，不作为强定量预测依据。

当前输入数据为 13 个无 EGR 稳态恒电流点，电流范围为：

```text
I_stack = 38-722 A
j = 0.10-1.90 A/cm2
```

测试数据中单片平均电压范围为：

```text
V_cell_meas = 0.5789-0.8017 V
```

## 4. 当前顶层拓扑

当前主气路链路为：

```text
EnvironmentFreshAir
-> EGRMixer
-> Compressor
-> Intercooler
-> HumidifierDryWetLumped
-> PEMFCStackCore
-> EGRValve
-> BackPressureValveWithOutletManifold
-> ambient
```

虽然模型中保留 `EGRMixer` 和 `EGRValve`，但当前无 EGR 基线中：

```text
egr_fraction_cmd = 0
```

因此此阶段的结果只用于无 EGR 基线和后续 EGR 分析的参考边界，不代表 EGR 结果已经完成验证。

主流动节点采用 7 维接口：

```text
[m_O2_kg_s
 m_N2_kg_s
 m_H2O_v_kg_s
 m_H2O_l_kg_s
 T_C
 p_kPa
 liquid_present]
```

主要输出包括：

- `fresh_node`
- `mixer_node`
- `compressor_node`
- `intercooler_node`
- `humidifier_dry_node`
- `stack_ca_out_node`
- `humidifier_wet_node`
- `egr_return_node`
- `vent_node`
- `stack_an_out_node`
- `summary_vector`
- `state_vector`

## 5. 电堆核心状态和方程口径

当前 `PEMFCStackCore` 状态向量为：

```text
[m_O2_ca
 m_N2_ca
 m_H2O_v_ca
 m_H2_an
 m_H2O_v_an
 T_stack]
```

反应源项按 Faraday 关系处理：

```text
m_O2_react = I * N / (4F) * M_O2
m_H2_react = I * N / (2F) * M_H2
m_H2O_gen  = I * N / (2F) * M_H2O
```

电堆内部阴极压力由库存质量、温度和流道体积计算：

```text
pCa = pO2 + pN2 + pH2O_v
```

当前已冻结的压力语义为：

- `pCa_kPa` 是电堆内部代表压力，只作诊断；
- `caOut(6)` 是阴极出口/背压边界压力，不是堆内库存压力；
- 下游湿侧加湿器和尾排模块读取的是出口边界压力；
- 出口流量仍由堆内压力与背压边界的差值驱动。

压力顺序验收口径为：

```text
p_ca_in_sim_kPa > p_stack_internal_kPa > p_ca_out_boundary_kPa
```

## 6. 辅件模型口径

### 6.1 空气供给

`EnvironmentFreshAir` 按电流和目标氧计量比生成新鲜空气流量。在无 EGR 下，新鲜空气流量等于空压机总流量。

当前无 EGR 阶段，空压机流量主要由恒流标定点给定或反算，不引入真实空压机转速、效率岛、喘振边界和动态控制器。

### 6.2 空压机和中冷器

空压机采用简化升压升温：

```text
p_out = p_in + dp_compressor
T_out = T_in + dT_compressor
```

中冷器采用目标出口温度和固定压降，并对超饱和水蒸气进行裁剪。当前不建立中冷器详细换热动态。

### 6.3 加湿器

`HumidifierDryWetLumped` 采用集总干湿侧膜传水/传热模型。当前湿侧 Stage B 第一轮放开的主要参数为：

```text
hum_NTU_ref        = 0.215343
hum_flow_exp       = 0.37998
hum_mem_D_eff_m2_s = 1.25e-09
```

当前加湿器参数已经能改善堆入口水蒸气分压和含湿量，但 `RH_ca_in` 没有同步改善，四口先验也没有显著变好。因此湿侧结果只能定义为第一轮可接受修正，不能定义为最终收敛。

### 6.4 热侧

热侧 Stage A 当前采用：

```text
Q_gen  = I * N * (Vtn - V)
Q_cool = h_cool_eff(flow_coolant) * (T_stack - T_cool_in)
Q_amb  = h_amb * (T_stack - T_amb)
Q_gas  = m_gas_out * cp_gas * max(T_stack - T_ca_in, 0)

C_stack * dT_stack/dt = Q_gen - Q_cool - Q_amb - Q_gas
```

当前冷却增强用 `coolant_flow_L_min -> h_cool_eff` 等效曲线表示，不建立完整冷却回路、泵阀控制和散热器。

## 7. 当前无 EGR 验证结果

### 7.1 压力链

压力修正阶段结果：

```text
pressure_order_ok = 13/13
p_ca_in RMSE      = 0.010847 kPa
p_ca_in maxAbs    = 0.017712 kPa
```

同时当前结果满足：

```text
min(p_ca_in_sim - p_stack_internal) = 3.4265 kPa
min(p_stack_internal - p_ca_out_boundary) = 4.0733 kPa
```

判断：

- 当前压力传递语义已经基本理顺；
- 入口压力、堆内压力、出口背压之间的顺序正确；
- 压力链可作为后续无 EGR 工况分析和 EGR 趋势分析的基础。

### 7.2 热侧

热侧 Stage A 结果：

```text
T_stack RMSE = 0.570 C
Q_cool RMSE  = 635.2 W
Q_cool bias  = 25.0 W
steady       = 13/13
pressure_order_ok = 13/13
```

湿侧 Stage B 接入后，当前无 EGR 诊断中的热侧结果为：

```text
T_stack RMSE  = 0.585 C
T_stack maxAbs = 0.864 C
T_stack_sim range = 61.887-81.261 C
```

判断：

- 当前热侧温度回归已经可接受；
- 冷却带热量仍有约 616 W RMSE，说明 `Q_cool` 只能作为辅助约束；
- 低负荷点 `bench_j0p10` 存在冷却液出口温度低于入口温度的问题，不应作为强热平衡真值点。

### 7.3 湿侧

当前湿侧 Stage B 第一轮结果：

```text
pH2O_caIn RMSE  = 4.500 kPa
pH2O_caIn maxAbs = 8.185 kPa
xH2O_caIn RMSE  = 0.02171
RH_ca_in RMSE   = 0.166
RH_ca_in maxAbs = 0.247
RH_ca_in_sim range = 0.190-0.801
```

判断：

- 堆入口水蒸气分压和含湿量相对基线已有改善；
- 相对湿度没有同步改善，可能与温度换算口径、局部饱和假设、加湿器传热和传水耦合有关；
- 湿侧下一轮应优先复核 `RH_ca_in` 与 `pH2O_caIn` 不同步改善的原因，不应直接进入大范围参数自由拟合。

### 7.4 电压

当前湿侧 Stage B 接入后的电压结果：

```text
V_cell RMSE  = 0.0735 V/cell
V_cell maxAbs = 0.1508 V/cell
V_cell_sim range = 0.4280-0.8175 V
```

判断：

- 电压模型可以用于当前工况分析的趋势观察；
- 电压参数仍需在压力、热侧、湿侧边界稳定后复核；
- 不能用当前电压误差直接支持高精度功率预测或 EGR 定量收益结论。

### 7.5 供氧状态

当前无 EGR 结果中：

```text
pO2_ca_in_sim range = 25.988-48.900 kPa
min(lambda_O2_actual) = 1.788
```

判断：

- 当前无 EGR 基线没有出现明显供氧不足；
- `pO2_ca_in_kPa` 可以作为后续 EGR 恒入口氧分压分析的参考目标；
- EGR 进入后，应以同电流无 EGR 的 `pO2_ca_in_kPa` 作为参考表，而不是重新人为指定一组绝对氧分压扫描值。

## 8. 当前模型可以支持的分析

当前无 EGR 模型可以支持：

- 13 个恒电流无 EGR 工况的系统级状态复现；
- 无 EGR 恒流条件下的压力链、温度、湿度、电压趋势分析；
- 无 EGR 参考表建立：`I_stack_A -> pO2_ca_in_ref_kPa`；
- 在热侧、湿侧和电压复核完成后，开展恒电压工况分析：给定 `V_cell_target = 0.9-0.7 V/cell`，外层扫电流，选择最接近目标电压的稳态结果。

当前不应把上述能力理解为已经可以开展 EGR 工况研究。EGR 只属于后续远期待办，必须等无 EGR 基线收敛后再进入。

## 9. 当前模型暂时不能支持的结论

当前模型暂时不能严肃支持：

- EGR 工况的定量性能收益或最优回流比例；
- 空压机真实转速、效率、功耗和喘振裕度结论；
- 加湿器四口实验数据的高精度复现；
- 冷却回路动态、泵阀控制和散热器能力判断；
- 由当前电压结果直接推出高精度功率、效率或经济性指标；
- 贫氧/EGR 下电压模型的严格预测。

这些限制不是模型失败，而是当前数据和抽象层级决定的边界。

## 10. 后续无 EGR 优先任务

### 10.1 冻结当前无 EGR 临时检查点

当前压力链、热侧 Stage A、湿侧 Stage B 第一轮只能作为临时检查点，不等于最终无 EGR 基线已经完成。

建议先把当前结果明确标记为：

```text
pressurefix + thermal Stage A + humidity Stage B first round
```

该版本可用于问题定位和后续对比，但不作为进入 EGR 的最终门槛。

### 10.2 热侧复核

热侧 Stage A 的 `T_stack RMSE` 已较好，但 `Q_cool RMSE` 仍在约 600 W 量级，且低负荷点存在台架反算冷却热量为负的问题。

下一步应先确认：

- `Q_cool` 作为辅助约束是否已足够；
- 低负荷异常点是否继续保留为弱约束；
- 冷却流量到等效换热系数的曲线是否存在过拟合或外推风险；
- 热侧是否可以正式冻结，还是需要小范围复核。

### 10.3 湿侧 Stage B 第二轮复核

优先复核：

- `RH_ca_in` 与 `pH2O_caIn` 不同步改善的原因；
- 温度换算和饱和蒸气压口径；
- 加湿器传热和传水是否被当前参数分配得过于耦合；
- 是否有必要放开 `hum_beta_dry_m_s / hum_beta_wet_m_s`。

不建议在原因未查清前大范围释放更多湿侧参数。

### 10.4 电压复核

只有在以下条件满足后，再复核电压参数：

- 压力链保持冻结；
- 热侧已被接受或明确其残余误差边界；
- 湿侧 Stage B 第二轮或湿度边界复核完成；
- `V_cell` 仍存在明确系统偏差。

电压复核目标不是把所有误差都用电压参数吸收，而是确认活化、欧姆、浓差项是否仍有系统偏差。

### 10.5 汇总无 EGR 参考表

热侧、湿侧和电压口径复核后，再生成一张无 EGR 工况参考表，至少包含：

```text
case_id
I_stack_A
current_density_A_cm2
V_cell_sim
V_cell_meas
pO2_ca_in_kPa
lambda_O2_actual
p_ca_in_sim_kPa
p_stack_internal_kPa
p_ca_out_boundary_kPa
RH_ca_in_sim
pH2O_caIn_sim_kPa
T_stack_sim_C
Q_cool_sim_W
```

该表作为后续恒电压无 EGR 工况分析的查表基准。EGR 只在更后续阶段使用该表作为同电流参考。

### 10.6 恒电压无 EGR 工况分析

推荐定义：

```text
输入：V_cell_target
范围：0.9-0.7 V/cell
方法：扫新的 I_stack_cmd_A
边界：参考最接近的恒流实验点
输出：最接近目标电压的稳态结果和电压偏差
定位：工况分析，不作为标定基线
```

整堆电压按：

```text
V_stack = 16 * V_cell
```

当前默认 16 片电池每片电压相同，不单独建单片离散性。

## 11. 进入 EGR 前的推荐门槛

进入 EGR 机理趋势分析前，建议至少完成：

- 热侧误差边界明确，尤其是 `Q_cool` 残余误差的解释；
- 湿侧 `RH` 与 `pH2O` 口径复核；
- 电压参数完成必要复核；
- 无 EGR 参考表生成；
- 恒电压无 EGR 工况分析脚本完成；
- `pO2_ca_in_ref_kPa` 按同电流点整理清楚；
- 当前无 EGR 版本提交 Git 作为稳定检查点。

## 12. EGR 后续分析推荐框架

本节只作为远期框架，不是当前下一步任务。EGR 第一阶段只做机理趋势，不做定量预测承诺。

推荐顺序：

1. 同电流、自由供气 EGR 扫描：

```text
I_stack_A 固定
egr_fraction_cmd = 0, 0.05, 0.10, 0.15, 0.20
空压机流量按原边界
观察 pO2、RH、pH2O、T_stack、V_cell 自然变化
```

2. 同电流、恒入口氧分压 EGR 扫描：

```text
I_stack_A 固定
egr_fraction_cmd = 0.05-0.20
目标 pO2_ca_in_kPa = 同电流无 EGR 参考值
调节空压机新鲜空气流量
观察湿度、水热、电压、尾气含湿量变化
```

这样可以尽量分离两类效应：

- EGR 稀释导致的供氧变化；
- 在入口氧分压尽量一致时，EGR 对水热状态的影响。

## 13. 当前结论

当前无 EGR 模型已经完成了从“结构可运行”到“恒电流基线基本可用”的过渡：

- 压力链语义已理顺，13 点压力顺序全部通过；
- 热侧温度回归较好，`T_stack RMSE` 约 0.6 C；
- 湿侧第一轮能改善堆入口水蒸气分压，但 RH 仍需复核；
- 电压仍有约 0.0735 V/cell RMSE，不宜提前用于高精度性能结论；
- 当前模型适合支撑无 EGR 工况分析和 EGR 机理趋势分析的前处理，但不适合直接给出 EGR 定量优化结论。

因此，下一步不是进入 EGR，而是继续完成无 EGR 基线：先复核热侧残余误差，再推进湿侧 Stage B-2，随后做电压复核；这些完成后再生成无 EGR 参考表和恒电压分析脚本。EGR 同电流趋势分析必须放到上述门槛之后。
