# PEMFC寿命衰减估算器算法规格 v01

## 1. 目标和边界

本算法用于在不改动现有燃料电池系统模型的前提下，独立计算 PEMFC 寿命衰减趋势，并为后续与电堆性能模型耦合提供稳定接口。

第一版定位为相对寿命收益估算器：

- 能比较无 EGR、有 EGR、不同进气湿度、不同低负荷电压限制策略下的相对衰减强弱。
- 能输出长时老化累计指标，例如累计电压衰减、损伤指数、ECSA 代理量。
- 暂不承诺绝对寿命小时数，除非后续补充本项目电堆长期耐久标定数据。

## 2. 外部接口

### 2.1 输入信号

| 名称 | 单位 | 采样 | 来源 | 说明 |
|---|---:|---|---|---|
| `V_cell` / `V_cell_sim` | V | 快变量或稳态点 | 电堆电压模型 | 寿命模型最关键输入，高电位暴露由此计算。 |
| `current_density_A_cm2` | A/cm2 | 快变量或稳态点 | 工况/电堆模型 | 用于低电流、高电流和负载循环风险判断。 |
| `RH_ca_in` | 1 | 快变量或稳态点 | 阴极入口状态 | 用于膜干燥风险修正。 |
| `T_stack_C` | degC | 快变量或稳态点 | 热模型 | 用于温度加速因子。 |
| `pO2_ca_in_kPa` | kPa | 快变量或稳态点 | 阴极入口状态 | 第一版作为解释和诊断量；第二版可进入电位/氧分压修正。 |
| `egr_fraction_cmd` | 1 | 稳态/控制量 | EGR 控制 | 只用于分组和解释，不直接作为衰减因子。 |
| `normal_operation_ok` | bool | 稳态/诊断 | 工况风险判据 | 非正常点仅做趋势参考。 |
| `dt_s` / `duration_h` | s / h | 求解器 | 外部调度 | 用于老化状态积分。 |

### 2.2 输出信号

| 名称 | 单位 | 说明 |
|---|---:|---|
| `life_damage_rate_mV_h` | mV/h | 当前等效电压衰减率。 |
| `delta_V_deg_mV` | mV | 当前步或稳态等效电压衰减。 |
| `delta_V_deg_mV_cumulative` | mV | 长时累计电压衰减。 |
| `life_damage_index` | 1 | 当前步损伤占允许衰减量比例。 |
| `damage_index_cumulative` | 1 | 累计损伤指数，1 表示达到设定 EOL。 |
| `projected_life_to_EOL_h` | h | 当前条件下推算到 EOL 的等效小时数。 |
| `ECSA_ratio_proxy` | 1 | 归一化 ECSA 代理量，第一版仅用于趋势显示。 |
| `high_potential_exposure_V_h` | V*h | `max(V_cell - V_high, 0)` 的积分。 |
| `dry_exposure_h` | h | `max(RH_min - RH_ca_in, 0)` 的积分。 |
| `life_benefit_vs_noEGR_pct` | % | 与同组无 EGR 基准相比的衰减降低比例。 |

## 3. 控制方程

### 3.0 文献依据和取舍

第一版寿命模型不是逐项复现某一篇文献的完整机理方程，而是把文献中可用于系统级仿真的规律整理成低维、可标定、可接 Simulink 的等效损伤模型。

| 模型部分 | 主要参考 | 本模型采用方式 |
|---|---|---|
| 负载谱/电压衰减率 | `1.pdf`: Zhang et al., Load profile based empirical model for lifetime prediction, IJHE 2017 | 采用“负载特征值 -> 电压衰减率”的思想。文献中用电流频谱 `m_cur` 和电压直方图 `m_vol` 得到 `phi = m_cur * m_vol`，再用线性关系估算衰减率。本项目第一版稳态工况较多，因此先等效为电压、湿度、温度、电流因子乘积。 |
| 低负荷高电位控制 | `3.pdf`: Liu et al., High-potential control based on oxygen partial pressure regulation, IJHE 2022 | 采用“低负荷高电位是耐久性风险，阴极循环通过调节氧分压降低电压”的因果链。`pO2_ca_in_kPa` 作为解释量，不与 `V_cell` 重复计入损伤。 |
| 10 kW 级阴极循环实验 | `5.pdf`: Jiang et al., Experimental study on dual recirculation, IJHE 2017 | 采用“阴极循环降低低电流电压、自加湿、可能延寿”的实验依据。阈值 `V_high = 0.8 V` 与文献和本项目仿真要求一致。 |
| Pt/ECSA 机理 | `2.pdf`, `4.pdf`, `6.pdf`: Mayur 2018, Trägner 2023, Kovtunenko 2023 | 第一版只保留 `ECSA_ratio_proxy` 作为代理输出。完整 Pt 溶解、氧化、扩散、粒径分布模型留到第二版，避免在缺少 Pt 载量/ECSA 标定数据时过拟合。 |
| 长时求解 | `2.pdf` 的 time-upscaling 思路、`4.pdf` 的刚性/准平衡处理 | 采用短时性能仿真 + 老化等效外推，不直接把系统模型连续跑几千小时。 |

因此第一版公式可以理解为 `1.pdf` 的系统级经验寿命模型在本项目稳态 cEGR 扫描场景下的降阶实现：

```text
文献形式：v_deg_rate = a * phi + b,  phi = m_cur * m_vol
项目形式：v_deg_rate = base_rate * f_V * f_RH * f_T * f_j * f_cycle
```

### 3.1 电位衰减因子

第一版使用平滑指数项叠加高电位阈值惩罚：

```text
f_base_V = exp(k_potential_exp * (V_cell - V_ref))
over_high = max((V_cell - V_high) / V_scale_high, 0)
under_low = max((V_low - V_cell) / V_scale_low, 0)

f_V = sat(f_base_V * (1 + k_over_high * over_high^2)
          + k_low_voltage * under_low^2)
```

默认：

```text
V_ref = 0.75 V
V_high = 0.80 V
V_low = 0.60 V
```

解释：

- `V_cell > 0.8 V` 代表低负荷高电位风险区，主要关联 Pt 溶解和碳腐蚀。
- `V_cell < 0.6 V` 不是当前 cEGR 寿命收益主问题，但作为高负荷/传质风险代理保留。

### 3.2 湿度衰减因子

```text
dryness = max((RH_min - RH_ca_in) / RH_min, 0)
f_RH = sat(1 + k_dry * dryness^2)
```

默认：

```text
RH_min = 0.70
RH_ref = 0.80
```

解释：

- cEGR 增湿的寿命收益通过降低膜干燥风险体现。
- 第一版不把高湿/液水淹没作为寿命收益项；液水风险由系统模型 `normal_operation_ok` 和 `risk_label` 外部判定。

### 3.3 温度加速因子

```text
f_T = exp(Ea / R * (1 / T_ref - 1 / T_stack))
```

默认：

```text
T_ref = 333.15 K
Ea = 25000 J/mol
```

解释：

- 这是等效 Arrhenius 加速因子，用于长期趋势。
- 若当前工况温度标定可信度不足，可在后处理阶段将 `f_T` 限幅或临时设为 1。

### 3.4 电流和循环因子

```text
low_current = max((j_low - j) / j_low, 0)
high_current = max((j - j_high) / j_high, 0)
f_j = sat(1 + k_j_low * low_current^2 + k_j_high * high_current^2)

f_cycle = sat(1 + k_djdt * abs(dj/dt) / djdt_ref)
```

解释：

- 稳态扫描中 `f_cycle = 1`。
- 动态负载循环中，`f_cycle` 作为 `1.pdf` 负载频谱模型的轻量替代项。
- 后续若输入完整时间序列，可升级为电流频谱 `m_cur` 和电压直方图 `m_vol`。

### 3.5 总衰减率和状态积分

```text
life_damage_rate_mV_h = base_decay_mV_h * f_V * f_RH * f_T * f_j * f_cycle

delta_V_deg_mV(k+1) = delta_V_deg_mV(k)
                    + life_damage_rate_mV_h * dt_h

damage_index = delta_V_deg_mV / allowable_decay_mV

ECSA_ratio_proxy = 1 - (1 - ECSA_EOL_ratio) * sat01(damage_index)
```

默认：

```text
base_decay_mV_h = 0.012 mV/h
allowable_decay_mV = 75 mV
ECSA_EOL_ratio = 0.60
```

`base_decay_mV_h` 只用于建立数量级和相对比较，必须由耐久实验或客户指定衰减率重新标定后才能用于绝对寿命。

## 4. 参数表

| 参数 | 默认值 | 单位 | 类型 | 来源/说明 |
|---|---:|---:|---|---|
| `V_ref` | 0.75 | V | 可标定 | 文献低风险电压区间。 |
| `V_high` | 0.80 | V | 可标定 | 仿真要求和 cEGR 高电位限制目标。 |
| `V_low` | 0.60 | V | 可标定 | 低电压/传质风险边界。 |
| `RH_min` | 0.70 | 1 | 可标定 | 膜干燥风险阈值。 |
| `T_ref_K` | 333.15 | K | 固定/可标定 | 当前台架低负荷温度附近。 |
| `Ea_J_mol` | 25000 | J/mol | 可标定 | 等效老化加速能。 |
| `base_decay_mV_h` | 0.012 | mV/h | 必须标定 | 第一版相对比较默认值。 |
| `allowable_decay_mV` | 75 | mV | 可标定 | 约等于 0.75 V 单片电压的 10%。 |
| `ECSA_EOL_ratio` | 0.60 | 1 | 可标定 | ECSA 代理 EOL 映射。 |

## 5. 长时老化求解方法

### 5.1 推荐方法：双时间尺度单向耦合

燃料电池气-水-热-电响应是秒级或分钟级，寿命衰减是百小时到千小时级。第一版采用双时间尺度：

```text
短时系统模型：计算 V_cell、j、RH、T、pO2
    -> 寿命模型：计算等效衰减率
    -> 长时积分：按等效持续时间累计 delta_V_deg
```

对于稳态工况扫描，推荐使用等效持续时间 `duration_h` 直接积分，不需要把 Simulink 跑到几千小时。

### 5.2 加速策略

1. 稳态点：每个工况运行一次，寿命模型乘以工况持续时间。
2. 任务谱：按工况占比加权，累计每类工况的 `delta_V_deg_mV`。
3. 动态循环：对代表性循环提取 `f_cycle` 或 `m_cur * m_vol`，再按循环重复次数外推。
4. 机理模型阶段：若加入 Pt/ECSA 刚性方程，优先采用准稳态 Pt 离子浓度或查表降阶，而不是在整车系统模型中直接积分完整 PDE。

### 5.3 耦合阶段划分

| 阶段 | 耦合方式 | 说明 |
|---|---|---|
| A | 完全独立后处理 | 读取 CSV，输出寿命指标。当前已实现。 |
| B | Simulink 单向在线估算 | 电堆输出状态，寿命模块积分，但不反向影响电压。 |
| C | 慢变量弱耦合 | `delta_V_deg_mV` 或 `ECSA_ratio_proxy` 修正电压模型活化损失。 |
| D | 半机理强耦合 | ECSA、Pt 粒径/载量进入电化学方程，需要实验标定和数值稳定性审查。 |

## 6. 代码实现

当前独立 MATLAB 原型位于：

```text
01_自吸方案/02_台架测试_10kW/02_脚本/pemfc_life_params_v01.m
01_自吸方案/02_台架测试_10kW/02_脚本/pemfc_life_core_v01.m
01_自吸方案/02_台架测试_10kW/02_脚本/pemfc_life_step_v01.m
01_自吸方案/02_台架测试_10kW/02_脚本/pemfc_life_evaluate_table_v01.m
01_自吸方案/02_台架测试_10kW/02_脚本/run_testbench_life_degradation_v01.m
```

运行入口：

```matlab
results = run_testbench_life_degradation_v01();
```

输出：

```text
01_自吸方案/02_台架测试_10kW/04_验证结果/life_degradation_constant_current.csv
01_自吸方案/02_台架测试_10kW/04_验证结果/life_degradation_constant_voltage.csv
01_自吸方案/02_台架测试_10kW/04_验证结果/life_degradation_constant_pO2_inlet.csv
01_自吸方案/02_台架测试_10kW/04_验证结果/life_degradation_constant_pO2_two_point.csv
01_自吸方案/02_台架测试_10kW/04_验证结果/life_degradation_all_cases.csv
01_自吸方案/02_台架测试_10kW/04_验证结果/life_degradation_group_summary.csv
01_自吸方案/02_台架测试_10kW/03_说明/寿命衰减独立模型运行摘要_v01.md
```

## 7. 验证要求

最低验证集：

1. `V_cell` 从 0.75 V 升到 0.85 V 时，`life_damage_rate_mV_h` 必须显著增加。
2. `RH_ca_in` 从 0.8 降到 0.5 时，`humidity_factor` 必须增加。
3. 同一分组内无 EGR 点必须作为 `life_benefit_vs_noEGR_pct = 0` 的基准。
4. 非正常点必须标为 `trend_reference`，不得作为正式最优点。
5. 长时积分 `delta_V_deg_mV` 必须随 `dt_s` 单调累计。

## 8. 后续耦合注意事项

1. 第一阶段不要让寿命状态反向影响电压模型，否则会把经验衰减和电压标定耦合在一起，难以解释。
2. 若进入阶段 C，建议只通过一个慢变量修正电压：`V_cell_aged = V_cell_BOL - delta_V_deg_mV / 1000`，或通过 `ECSA_ratio_proxy` 修正交换电流密度，二者不要同时启用。
3. `pO2_ca_in_kPa` 目前用于解释 cEGR 低电压原因，不应再额外乘到衰减方程上，避免与 `V_cell` 影响重复计入。
4. 长时老化研究应采用工况谱外推，不应直接把当前系统 Simulink 模型连续跑几千小时。
