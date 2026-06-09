# Core Fix v02 Execution Summary

## 修改范围

- `01_模型/CEGR_TestBench_10kW_SimplifiedEGR_v01.slx`
- `02_脚本/init_testbench_10kw_simplified_egr.m`
- `02_脚本/run_core_fix_v01_audit.m`
- `02_脚本/run_core_fix_v01_detailed_audit.m`

模型备份：

- `01_模型/CEGR_TestBench_10kW_SimplifiedEGR_v01_before_membrane_v02.slx`

## 已执行修正

1. 电堆状态由 6 维扩展到 7 维：

```text
[mO2; mN2; mV_ca; mH2; mV_an; T; a_memb]
```

2. `a_memb` 固定为零维等效膜水活度滞后状态，不作为严格膜水库存。
3. `lambda_m = lambda_eq(a_memb)`，并继续进入 `n_d`、`D_w` 和 `etaOhm`。
4. 参与膜水计算的 `a_ca/a_an/a_memb` 限幅到 `[0,1]`，同时保留 raw 水活度审计。
5. 跨膜水通量保留 `J_drag - J_diff` 结构，`J_diff` 源项继续使用 `lambda_ca - lambda_an`。
6. 新增 `k_mem_eff`，只缩放跨膜水通量尺度，不改变方向。
7. 不新增液态水动态状态，不调整电压拟合参数，不改变求解器结构。
8. summary 新增 raw/limited 水活度、`a_memb`、半膜候选通量、等效膜水库存变化、`tau_memb_s`、`k_mem_eff` 等诊断。

## 参数扫描结果

先固定 `k_mem_eff = 0.1` 扫描 `tau_memb_s`：

| tau_memb_s | 29 点末段 mMem 符号切换总数 | 最大 mMem 末段范围 kg/s | 平均 abs(mMem)/产水量 |
|---:|---:|---:|---:|
| 10 | 3196 | 4.3116e-4 | 0.98992 |
| 30 | 3194 | 4.3571e-4 | 1.5326 |
| 60 | 3400 | 4.8821e-4 | 2.4170 |
| 105 | 3402 | 5.0629e-4 | 2.4548 |

再固定 `tau_memb_s = 10` 扫描 `k_mem_eff`：

| k_mem_eff | 29 点末段 mMem 符号切换总数 | 最大 mMem 末段范围 kg/s | 平均 abs(mMem)/产水量 |
|---:|---:|---:|---:|
| 1.0 | 5800 | 2.4956e-3 | 3.3568 |
| 0.5 | 5800 | 2.4032e-3 | 3.3381 |
| 0.2 | 4200 | 8.5980e-4 | 2.9332 |
| 0.1 | 3196 | 4.3116e-4 | 0.98992 |
| 0.05 | 0 | 2.8366e-5 | 0.19507 |

因此默认值更新为：

```text
tau_memb_s = 10
k_mem_eff = 0.05
```

## 最终 120 s 审计结果

基础审计：

- 成功工况：29 / 29
- 失败工况：0
- `tau_memb_s`：10 s
- `k_mem_eff`：0.05
- 电压 RMSE：0.0112792 V

详细审计：

- 接口一致性失败：0 / 319
- 末段 `mMem` 符号切换工况：0 / 29
- 最大 `mMem` 末段范围：2.8366e-5 kg/s
- 最大 `lambda_m` 末段范围：0.707673
- 最大 `a_memb` 末段范围：0.0230094
- `mMem` 时序行数：29000

步长敏感性：

- 代表工况：低电流无 EGR、高电流无 EGR、高回流 CEGR。
- `dt = 0.1 s` 与 `dt = 0.05 s` 下均无末段 `mMem` 符号切换。
- `mMem` 末段范围变化很小，未观察到明显步长敏感性。

## 生成文件

- `core_fix_v02_audit.csv`
- `core_fix_v02_summary.md`
- `core_fix_v02_detailed_variable_audit.csv`
- `core_fix_v02_interface_consistency.csv`
- `core_fix_v02_mmem_timeseries.csv`
- `core_fix_v02_detailed_summary.md`
- `core_fix_v02_tau_scan.csv`
- `core_fix_v02_tau_scan_summary.csv`
- `core_fix_v02_k_scan.csv`
- `core_fix_v02_k_scan_summary.csv`
- `core_fix_v02_dt_sensitivity.csv`

## 结论

v02 已按计划执行完成。当前默认参数下，膜水净传输质量流量末段正负波动问题已消除，跨膜水通量量级从 v01 的过强状态显著降低，同时 29 个无 EGR 与 CEGR 工况的接口一致性全部通过。
