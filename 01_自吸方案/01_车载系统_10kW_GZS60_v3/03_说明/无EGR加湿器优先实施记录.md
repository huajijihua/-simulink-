# 无 EGR 加湿器优先实施记录

日期：2026-06-05

## 本轮口径

- 台架堆入口湿度是外部自由控制边界，不作为车载膜加湿器出口硬拟合目标。
- 车载系统的电堆阴极入口湿度由 `HumidifierDryWetLumped` 干侧出口决定。
- 本轮只做无 EGR 加湿器优先诊断，不做 EGR 扫描。
- `humidity_stageB_params.csv` 已改为当前加湿器优先基线参数；旧 Stage B 第一轮视为历史对照。

## 新增入口

```text
02_脚本/analyze_vehicle_10kw_gzs60_v3_humidifier_first.m
```

## 结果摘要

详见：

```text
04_验证结果\humidifier_first_summary.md
```
