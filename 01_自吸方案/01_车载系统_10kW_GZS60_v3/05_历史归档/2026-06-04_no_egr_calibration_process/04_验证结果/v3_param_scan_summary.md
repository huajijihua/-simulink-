# v3 Parameter Scan Summary

| Case | Vol | Flow | pass_ca | pass_an | pass_ca_man | p_tailgas_kPa | p_ca_manifold_kPa | V_cell | Recommended |
| --- | --- | --- | --- | --- | --- | ---: | ---: | ---: | --- |
| flow_small | mid | small | PASS | PASS | PASS | 184.232 | 329.888 | 0.80671 | FAIL |
| flow_mid | mid | mid | PASS | PASS | PASS | 184.232 | 329.888 | 0.80671 | FAIL |
| flow_large | mid | large | PASS | PASS | PASS | 184.232 | 329.888 | 0.80671 | FAIL |
| vol_small | small | mid | PASS | PASS | PASS | 141.637 | 253.370 | 0.88794 | PASS |
| vol_mid | mid | mid | PASS | PASS | PASS | 184.232 | 329.888 | 0.80671 | FAIL |
| vol_large | large | mid | PASS | PASS | PASS | 188.827 | 342.584 | 0.76726 | FAIL |

Recommended case: `vol_small`
- Rationale: all three flow-limit checks pass and tailgas pressure is the lowest among passing cases.
