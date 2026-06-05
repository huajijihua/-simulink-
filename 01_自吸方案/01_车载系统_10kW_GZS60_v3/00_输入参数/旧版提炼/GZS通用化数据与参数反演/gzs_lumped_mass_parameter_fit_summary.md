# GZS Lumped-Mass加湿器参数反演

本结果以GZS80P六个转速四口实测点为主标定对象，用含湿量/水蒸气质量流作为传水主目标，RH仅作为温度换算后的验证量；不是GZS60直接实测标定。

## Parameter packs

- `best_fit`: NTU_ref 0.6968, n 0.5500, low-flow gain 0.0960 below 3500 slpm, dry epsilon_T 0.8226, wet epsilon_T 0.7408, latent cooling 62.21 C/(kg/kg), dry/wet dp ref 8.048/13.960 kPa, dry/wet dp exp 1.066/1.271.
- `conservative_low_humidification`: NTU_ref 0.5226, n 0.5500, low-flow gain 0.0720 below 3500 slpm, dry epsilon_T 0.6581, wet epsilon_T 0.7408, latent cooling 62.21 C/(kg/kg), dry/wet dp ref 8.048/13.960 kPa, dry/wet dp exp 1.066/1.271.
- `optimistic_high_humidification`: NTU_ref 0.8710, n 0.5500, low-flow gain 0.1201 below 3500 slpm, dry epsilon_T 0.9500, wet epsilon_T 0.7408, latent cooling 62.21 C/(kg/kg), dry/wet dp ref 8.048/13.960 kPa, dry/wet dp exp 1.066/1.271.
- `dry_priority`: NTU_ref 0.6968, n 0.5500, low-flow gain 0.0960 below 3500 slpm, dry epsilon_T 0.8226, wet epsilon_T 0.7408, latent cooling 62.21 C/(kg/kg), dry/wet dp ref 8.048/13.960 kPa, dry/wet dp exp 1.066/1.271.
- `wet_priority`: NTU_ref 0.6398, n 0.0500, low-flow gain 0.2892 below 3500 slpm, dry epsilon_T 0.7940, wet epsilon_T 0.6516, latent cooling 69.48 C/(kg/kg), dry/wet dp ref 8.048/13.960 kPa, dry/wet dp exp 1.066/1.271.
- `balanced_envelope`: NTU_ref 0.6558, n 0.3494, low-flow gain 0.2761 below 3500 slpm, dry epsilon_T 0.2500, wet epsilon_T 0.2500, latent cooling 0.00 C/(kg/kg), dry/wet dp ref 8.271/14.079 kPa, dry/wet dp exp 1.213/1.344.

## Replay errors

- `best_fit`: dry/wet humidity ratio 8.270/18.186 g/kg, dry RH 9.100 %RH, dry/wet dewpoint 1.596/3.326 C, dry/wet T 2.149/2.310 C, dry/wet transfer 0.4650/0.7093 g/s, dry/wet dp 0.436/0.386 kPa.
- `conservative_low_humidification`: dry/wet humidity ratio 17.801/10.876 g/kg, dry RH 16.571 %RH, dry/wet dewpoint 3.530/1.887 C, dry/wet T 2.591/2.755 C, dry/wet transfer 1.0235/0.6792 g/s, dry/wet dp 0.436/0.386 kPa.
- `optimistic_high_humidification`: dry/wet humidity ratio 7.365/27.252 g/kg, dry RH 4.563 %RH, dry/wet dewpoint 1.868/5.138 C, dry/wet T 1.834/2.107 C, dry/wet transfer 0.7593/1.2443 g/s, dry/wet dp 0.436/0.386 kPa.
- `dry_priority`: dry/wet humidity ratio 8.270/18.186 g/kg, dry RH 9.100 %RH, dry/wet dewpoint 1.596/3.326 C, dry/wet T 2.149/2.310 C, dry/wet transfer 0.4650/0.7093 g/s, dry/wet dp 0.436/0.386 kPa.
- `wet_priority`: dry/wet humidity ratio 20.278/3.817 g/kg, dry RH 17.216 %RH, dry/wet dewpoint 3.950/0.626 C, dry/wet T 2.099/2.135 C, dry/wet transfer 0.9535/0.1972 g/s, dry/wet dp 0.436/0.386 kPa.
- `balanced_envelope`: dry/wet humidity ratio 12.640/12.906 g/kg, dry RH 20.208 %RH, dry/wet dewpoint 2.369/2.266 C, dry/wet T 5.031/8.145 C, dry/wet transfer 0.6581/0.4823 g/s, dry/wet dp 0.371/0.389 kPa.

## Usage

- `best_fit` is retained as the backward-compatible alias for the dry-priority stack-inlet boundary pack.
- `conservative_low_humidification` and `optimistic_high_humidification` define RH bounds for 10 kW low-flow trend screening.
- `dry_priority` prioritizes dry outlet humidity and temperature, so it is the preferred pack for stack-inlet RH analysis.
- `wet_priority` prioritizes wet outlet humidity, so it is the preferred pack for separator and EGR tail-gas water-vapor boundary checks.
- `balanced_envelope` uses dual-side candidate points where possible; it is an uncertainty-envelope reference, not a final best-fit claim.
- Low-flow GZS60 conclusions remain trend-level until direct GZS60 four-port data are available.
