# CEGR_Vehicle_10kW_GZS60_v03 审计版模型新架构实施计划

## 1. 总目标

本轮重构目标不是建立复杂整车 BOP 机理模型，而是聚焦阴极尾气循环对燃料电池性能的影响路径：

```text
阴极尾气循环 -> 电堆入口组分/流量/压力/湿度/温度 -> 电堆电压/热/水合/性能
```

BOP 模块只保留对质量流、能量流、压力流的本质作用。电堆和加湿器是重点模块，需保留明确控制方程、参数含义、文献或工程依据及可标定参数。

## 2. 电堆核心状态

电堆模型采用低阶动态加代数闭合：

```text
5 个组分质量 ODE + 1 个集总热 ODE
```

状态变量为：

```text
m_O2_ca
m_N2_ca
m_H2O_ca
m_H2_an
m_H2O_an
T_fc
```

其余变量，包括压力、分压、相对湿度、水活度、膜水合度、电压、过电势、实际氧计量比等，均作为代数表达式处理。

## 3. 电堆质量守恒

阴极侧：

```text
dm_O2_ca/dt  = m_O2_in - m_O2_out - m_O2_consumed
dm_N2_ca/dt  = m_N2_in - m_N2_out
dm_H2O_ca/dt = m_H2O_in - m_H2O_out + m_H2O_gen + m_H2O_mem
```

阳极侧：

```text
dm_H2_an/dt  = m_H2_in - m_H2_out - m_H2_consumed
dm_H2O_an/dt = m_H2O_in - m_H2O_out - m_H2O_mem
```

阳极侧只保留支持电化学反应和膜水迁移所需的最小边界，不建阳极循环、排氮、排水等复杂 BOP 策略。

## 4. 电堆集总热模型

电堆温度作为第 6 个动态状态，采用书籍资料中的集总能量守恒形式：

```text
C_fc*dT_fc/dt =
    N_cell*I_fc*A_cell*LHV_H2/(2F)
    - P_fc
    - Phi_cool
    - Phi_loss
    - Phi_g
```

变量含义：

```text
C_fc      电堆等效热容
LHV_H2    氢气低热值
P_fc      电堆电功率
Phi_cool  冷却液带走热量
Phi_loss  电堆向环境散热
Phi_g     气体吸收或带走的净热量
```

实施约束：

```text
如果 I_fc 表示电流密度，则功率和反应热项需要乘 A_cell；
如果 I_stack 表示总电流，则不能重复乘 A_cell。
```

## 5. 电压模型

Nernst 方程不做经验修改。电压结构采用：

```text
V_cell = E_Nernst - eta_act - eta_ohm - eta_con
```

氧浓度影响通过活化过电势和浓差过电势体现。

活化过电势：

```text
i0_c_eff = i0_c_ref
         * (pO2_ca/pO2_ref)^m_act_O2
         * f_lambda(lambda_mem)
         * f_T(T_fc)
```

浓差过电势：

```text
i_lim_eff = i_lim_ref
          * (pO2_ca/pO2_ref)^m_lim_O2
          * f_flow(lambda_O2_ca_actual)
```

建议初始参数范围：

```text
m_act_O2 = 0.5 ~ 0.8
m_lim_O2 = 1.0 ~ 1.5
```

关键约束：

```text
lambda_O2_ca_actual = 实际进入电堆的 O2 摩尔流 / 电化学耗氧摩尔流
```

`lambda_O2_ca_actual` 必须由电堆入口实际氧气质量流和当前耗氧量实时计算，不允许用初始设定空气计量比或目标计量比代替。

## 6. 膜水合模型

膜水合采用准静态模型，不把 `lambda_mem` 作为 ODE 状态。

核心水通量：

```text
N_H2O_mem = N_drag - N_backdiff
```

其中：

```text
N_drag = n_drag(lambda_mem) * I_stack*N_cell/F

N_backdiff =
    D_lambda(lambda_mem,T_fc) * A_mem/t_mem
    * (cH2O_ca_eq - cH2O_an_eq)
```

膜水合度由两侧水活度代数求得：

```text
lambda_an_eq = f(a_H2O_an)
lambda_ca_eq = f(a_H2O_ca)
lambda_mem   = weighted_mean(lambda_an_eq, lambda_ca_eq)
```

膜水通量进入阴极和阳极水质量源项，用于闭合电堆水管理。

## 7. 歧管与流量边界处理

本重构版不物理舍弃入口歧管、出口歧管、尾气歧管或阳极尾气边界，而是按系统级建模目标整合进相邻模块，以减少非必要变量传递。

阴极入口歧管整合进加湿器干侧出口：

```text
m_ca_in = K_ca_in * max(p_hum_dry_out - p_ca, 0)
```

电堆阴极入口组分直接来自加湿器干侧出口：

```text
yO2_ca_in
yN2_ca_in
yH2O_ca_in
RH_ca_in
T_ca_in
p_ca_in
```

阴极出口歧管整合进背压阀：

```text
m_ca_out = K_ca_out * max(p_ca - p_bpv_downstream, 0)
```

阳极侧采用同类线性压差边界：

```text
m_an_in  = K_an_in  * max(p_H2_supply - p_an, 0)
m_an_out = K_an_out * max(p_an - p_an_downstream, 0)
```

## 8. 加湿器模型

加湿器是本系统中仅次于电堆的重要模块。采用系统级集总模型，同时保留明确的文献依据和参数标定空间。

参考材料：

```text
A Lumped-Mass Model of Membrane Humidifier for PEMFC
Modeling mass and heat transfer in membrane humidifiers for polymer electrolyte membrane fuel cells
```

模型形式：

```text
水传递：总传质阻力模型
热传递：NTU/UA 或等效 UA 准稳态热交换
出口湿度：由水蒸气质量、温度、压力计算，并做饱和/冷凝限制
```

核心水传递表达：

```text
m_H2O_transfer = j_H2O * A_mem
j_H2O = Delta_p_H2O / R_total
R_total = R_bl_wet + R_mem + R_bl_dry
```

阻力组成：

```text
R_bl_wet  湿侧气相边界层传质阻力
R_mem     膜内传质阻力
R_bl_dry  干侧气相边界层传质阻力
```

出口湿度计算需使用水蒸气分压、饱和蒸气压和总压：

```text
RH = p_H2O / p_sat(T)
```

保留可标定参数：

```text
A_hum_mem
delta_hum_mem
D_H2O_mem_scale
beta_wet_scale
beta_dry_scale
UA_hum
dp_hum_dry
dp_hum_wet
```

## 9. EGR 比例定义与阀门处理

EGR 目标比例采用技术参数中的循环比定义：

```text
r_EGR_target = m_egr / m_humidifier_wet_out
```

EGR 阀对加湿器湿侧出口尾气进行分流：

```text
m_egr  = r_EGR_target * m_wet_out
m_vent = (1 - r_EGR_target) * m_wet_out
```

阀开度作为诊断或执行结果保留：

```text
opening_egr = clamp(r_EGR_target, 0, 1)
```

在当前稳态/低阶动态系统模型中，阀开度不反向主导主流量闭合。

## 10. BOP 模块边界

重构后保留模块：

```text
EnvironmentFreshAir
EGRMixer
Compressor
Intercooler
HumidifierDryWetLumped
PEMFCStackCore
EGRValve
BackPressureValveWithOutletManifold
SystemSummary
```

整合关系：

```text
HumidifierDry + HumidifierWet -> HumidifierDryWetLumped
CathodeOutletManifold -> BackPressureValveWithOutletManifold
TailGasManifold -> EGRValve
CathodeBackPressure -> 背压阀/系统边界
AnodeOutletManifold -> 电堆阳极侧边界
```

外围注释需明确：这些结构不是被物理删除，而是将其阻力、分流、混合或边界作用整合进相邻功能模块。

## 11. BOP 简化原则

空压机：

```text
接收外界空气和回流尾气混合物；
增压升温；
不改变组分；
不改变总质量流量。
```

中冷器：

```text
降低气体温度；
给出压降；
不改变组分；
水冷凝如暂不考虑，需明确注释。
```

EGR 阀：

```text
接收加湿器湿侧出口尾气；
按目标循环比分流为回流和排出；
输出诊断阀开度。
```

背压阀：

```text
整合阴极出口歧管；
通过线性压差关系决定电堆阴极出口流量；
提供阴极出口压力边界。
```

## 12. 关键输出与检查项

重构后的最小关键输出：

```text
V_cell
P_fc
T_fc
pO2_ca
pH2_an
lambda_mem
lambda_O2_ca_actual
RH_ca_in
RH_ca_out
r_EGR_actual
opening_egr
m_ca_in
m_ca_out
```

最小验证要求：

```text
模型能编译/仿真；
EGR 比例升高时，电堆入口 O2 摩尔分数下降；
lambda_O2_ca_actual 使用实际入口氧气流量计算；
低氧浓度时 eta_act 和 eta_con 均有合理增加；
加湿器干侧出口 RH 不超过饱和限制；
水传递方向符合湿侧到干侧的水蒸气分压差；
质量守恒无明显符号错误。
```

## 13. 实施交付

后续实施范围：

```text
只修改审计版模型，不动原始模型；
重构模块边界和 MATLAB Function 方程；
在模块旁添加注释，说明方程来源、工程假设、整合关系、待标定参数；
做最小可运行检查；
输出简洁修改说明和关键接口清单。
```
