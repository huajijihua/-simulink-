function y = pemfc_life_core_v01(V_cell, j_A_cm2, RH, T_C, duration_h, P, djdt_A_cm2_s)
%PEMFC_LIFE_CORE_V01 Core equations for relative PEMFC life degradation.
%
% Inputs can be scalars or column vectors. The model estimates relative
% voltage degradation rate, not an absolute warranted lifetime.

if nargin < 6 || isempty(P)
    P = pemfc_life_params_v01();
end
if nargin < 7 || isempty(djdt_A_cm2_s)
    djdt_A_cm2_s = zeros(size(V_cell));
end

V_cell = col(V_cell);
j_A_cm2 = col(j_A_cm2);
RH = col(RH);
T_C = col(T_C);
duration_h = col(duration_h);
djdt_A_cm2_s = col(djdt_A_cm2_s);

n = max([numel(V_cell), numel(j_A_cm2), numel(RH), numel(T_C), numel(duration_h), numel(djdt_A_cm2_s)]);
V_cell = expandTo(V_cell, n);
j_A_cm2 = expandTo(j_A_cm2, n);
RH = expandTo(RH, n);
T_C = expandTo(T_C, n);
duration_h = expandTo(duration_h, n);
djdt_A_cm2_s = expandTo(djdt_A_cm2_s, n);

RH = min(max(RH, 0), 1.2);
T_K = T_C + 273.15;
T_K = max(T_K, 250);

voltageBase = exp(P.k_potential_exp .* (V_cell - P.V_ref));
voltageBase = min(max(voltageBase, P.min_voltage_factor), P.max_voltage_factor);
overHigh = max((V_cell - P.V_high) ./ P.V_scale_high, 0);
underLow = max((P.V_low - V_cell) ./ P.V_scale_low, 0);
voltageFactor = voltageBase .* (1 + P.k_over_high .* overHigh.^2) + P.k_low_voltage .* underLow.^2;
voltageFactor = min(max(voltageFactor, P.min_voltage_factor), P.max_voltage_factor);

dryness = max((P.RH_min - RH) ./ max(P.RH_min, eps), 0);
humidityFactor = 1 + P.k_dry .* dryness.^2;
humidityFactor = min(max(humidityFactor, 1), P.max_humidity_factor);

temperatureFactor = exp((P.Ea_J_mol ./ P.R_gas) .* (1 ./ P.T_ref_K - 1 ./ T_K));
temperatureFactor = min(max(temperatureFactor, P.min_temperature_factor), P.max_temperature_factor);

lowCurrent = max((P.j_low - j_A_cm2) ./ max(P.j_low, eps), 0);
highCurrent = max((j_A_cm2 - P.j_high) ./ max(P.j_high, eps), 0);
currentFactor = 1 + P.k_j_low .* lowCurrent.^2 + P.k_j_high .* highCurrent.^2;
currentFactor = min(max(currentFactor, 1), P.max_current_factor);

cyclingFactor = 1 + P.k_djdt .* abs(djdt_A_cm2_s) ./ max(P.djdt_ref, eps);
cyclingFactor = min(max(cyclingFactor, 1), P.max_cycling_factor);

rate_mV_h = P.base_decay_mV_h .* voltageFactor .* humidityFactor .* temperatureFactor .* currentFactor .* cyclingFactor;
rate_mV_h = min(max(rate_mV_h, P.rate_floor_mV_h), P.rate_cap_mV_h);
delta_mV = rate_mV_h .* duration_h;
damageIndex = delta_mV ./ P.allowable_decay_mV;
projectedLife_h = P.allowable_decay_mV ./ max(rate_mV_h, P.rate_floor_mV_h);
ecsaRatioProxy = 1 - (1 - P.ECSA_EOL_ratio) .* min(max(damageIndex, 0), 1);

y = struct();
y.voltage_factor = voltageFactor;
y.humidity_factor = humidityFactor;
y.temperature_factor = temperatureFactor;
y.current_factor = currentFactor;
y.cycling_factor = cyclingFactor;
y.life_damage_rate_mV_h = rate_mV_h;
y.delta_V_deg_mV = delta_mV;
y.life_damage_index = damageIndex;
y.projected_life_to_EOL_h = projectedLife_h;
y.ECSA_ratio_proxy = ecsaRatioProxy;
y.high_potential_exposure_V_h = max(V_cell - P.V_high, 0) .* duration_h;
y.dry_exposure_h = max(P.RH_min - RH, 0) .* duration_h;
y.high_potential_margin_mV = (V_cell - P.V_high) .* 1000;
end

function x = col(x)
x = x(:);
end

function x = expandTo(x, n)
if numel(x) == n
    return;
end
if isscalar(x)
    x = repmat(x, n, 1);
else
    error('pemfc_life_core_v01:SizeMismatch', 'Input lengths must match or be scalar.');
end
end
