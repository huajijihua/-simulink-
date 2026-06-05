# GZS80P四口实测回放

## 数据和口径
- 数据源：GZS80P实测数据.xlsx，四口温湿压数据。
- 模型：GZS80P六点反演参数包 + Lumped-Mass反流有效度方程。
- 该回放只用于系列趋势校核，不作为GZS60直接标定真值。

## 误差摘要
- 干/湿出含湿量 RMSE: 8.270/18.186 g/kg
- 干出RH RMSE: 9.100 %RH
- 干出温度 RMSE: 2.149 C
- 湿出温度 RMSE: 2.310 C
- 干侧压降 RMSE: 0.436 kPa
- 湿侧压降 RMSE: 0.386 kPa
- 最大热残差诊断: 14308.228 W
- 低流量修正触发点: 2 / 6

## 结论
- 若误差较大，优先说明GZS60参数来自系列外推，不能用GZS80P直接替换。
- 后续可用该脚本比较simple_NTU与counterflow_effectiveness模式。
