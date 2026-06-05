# CEGR_Vehicle_10kW_GZS60_v03 审计台账

审计对象：`01_模型/CEGR_Vehicle_10kW_GZS60_v03_audit.slx`

说明：本台账与审计版 Simulink 模型内 `[AUDIT-*]` 注释对应。原模型未作为审计注释承载文件。

| 编号 | 严重度 | 位置 | 问题摘要 | 建议 |
|---|---|---|---|---|
| AUDIT-H01 | 高 | CathodeSupplyLoop / EnvironmentFreshAir | 有 EGR 时，fresh 仍按目标氧耗分配全部目标 O2，混合后有效 OER/氧稀释定义不闭合。 | 按混合后 O2 摩尔流计算 stoich/OER，显式区分 fresh、EGR、effective OER。 |
| AUDIT-M01 | 中 | CathodeSupplyLoop / Compressor | 空压机仅固定升压、升温，无 MAP、效率、转速、功耗或压比-流量关系。 | 标为边界占位，后续接 DQ60 MAP 或压比-流量约束。 |
| AUDIT-M02 | 中 | CathodeSupplyLoop / Intercooler | 中冷器固定出口温度和压降，冷凝为饱和裁剪；资料显示 UA/压降仍为工程默认。 | 补 UA/冷却介质/压降数据，或明确为边界约束。 |
| AUDIT-M03 | 中 | CathodeSupplyLoop / HumidifierDry | GZS60 加湿器参数由手册和系列数据外推，wetAvailable 的 20% 饱和水保留项依据不足。 | 标注待标定，补 GZS60 低流量 RH/露点/压降数据。 |
| AUDIT-H02 | 高 | StackCore / PEMFCStack | 电堆框架有依据，但浓差极化不显式依赖 O2 分压或限流；膜水扩散厚度单位需复核；阳极 N2 交叉渗透为 0。 | 做单位推导和公式逐项绑定，贫氧/EGR 需氧浓度扫点验证。 |
| AUDIT-M04 | 中 | CathodeConditioningLoop / HumidifierWet | 湿侧降温和传水上限为简化经验写法，未闭合湿/干两侧能量守恒。 | 明确为简化占位，补膜面积、传质系数和热平衡依据。 |
| AUDIT-M05 | 中 | CathodeConditioningLoop / Separator | 分水器固定效率和幂律压降，缺实测效率、液水携带和温度依赖。 | 补分水器/冷凝器数据，标注回流水含量不确定性。 |
| AUDIT-M06 | 中 | CathodeConditioningLoop / CathodeBackPressure | pStackDownstream 由 tailgas 压力加湿侧/分离器压降闭合，物理测点需核对。 | 在接口图中明确电堆下游压力测点和管路顺序。 |
| AUDIT-M07 | 中 | CathodeConditioningLoop / CathodeOutletManifold | 阴极出口歧管为集总容积+线性 Kout*dp，参数来源未见 GZS60 管路标定。 | 核查等效容积、流量系数、压力动态标定依据。 |
| AUDIT-H03 | 高 | TailgasEGRLoop / TailGasManifold | init 默认 egr_fraction_cmd=0，验证脚本临时改值；正式模型默认 cEGR 实际关闭。 | 明确控制命令来源和默认工况，避免验证覆盖值误导。 |
| AUDIT-H04 | 高 | TailgasEGRLoop / EGRValve & BackPressureValve | 阀参数传入但基本未进入流量方程，阀件缺 Cv/Kv、开度-流量、可压缩流或压降关系。 | 接入阀参数或删除无效接口；补阀件特性/标定。 |
| AUDIT-M08 | 中 | TailgasEGRLoop / EGRReturnPipe | 回流管只做幂律压降并强制无液水回流，影响自加湿和入口湿度判断。 | 明确实际支路是否允许液滴夹带/冷凝。 |
| AUDIT-H05 | 高 | AnodeExhaustLoop / AnodeOutletManifold | 阳极尾排下游压力设为 85 kPa，低于环境压；函数又以环境压限幅，边界含义不清。 | 核对阳极排气/氢循环边界；若无负压设备，不应低于环境。 |
| AUDIT-L01 | 低 | DiagnosticsAndSummary / SystemSummary | 48 元 summary 依赖外部索引语义，后续扩展易混淆诊断量和物理状态。 | 后续改为 Bus 或枚举索引脚本。 |

## 本轮验证

- 已运行 `check_vehicle_10kw_gzs60_v3.m`，现有脚本检查项均为 PASS。
- 已运行 `run_vehicle_10kw_gzs60_v3_validation.m`，验证结果写入 `04_验证结果`。
- 上述 PASS 只说明当前脚本定义的运行和闭合检查通过，不抵消本台账中的物理依据、参数来源和接口语义问题。
