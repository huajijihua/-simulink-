function P = pemfc_life_params_v01(overrides)
%PEMFC_LIFE_PARAMS_V01 Calibration set for the first PEMFC life model.
%
% The values are intentionally conservative defaults for relative
% comparison. Absolute life prediction requires stack-specific aging data.

if nargin < 1
    overrides = struct();
end

P = struct();
P.version = "pemfc_life_v01";

% Voltage stress model.
P.V_ref = 0.75;              % V, reference low-risk voltage
P.V_high = 0.80;             % V, high-potential reporting threshold
P.V_low = 0.60;              % V, low-voltage stress threshold
P.V_scale_high = 0.05;       % V, normalization above V_high
P.V_scale_low = 0.10;        % V, normalization below V_low
P.k_potential_exp = 7.5;     % 1/V, smooth high-potential sensitivity
P.k_over_high = 4.0;         % extra penalty above V_high
P.k_low_voltage = 1.0;       % low-voltage / starvation proxy penalty
P.min_voltage_factor = 0.25;
P.max_voltage_factor = 20.0;

% Humidity stress model. Current project uses this as membrane-dryness
% protection, not as a Pt dissolution law.
P.RH_ref = 0.80;
P.RH_min = 0.70;
P.k_dry = 3.0;
P.max_humidity_factor = 8.0;

% Temperature acceleration using Arrhenius form.
P.T_ref_K = 333.15;          % 60 degC
P.Ea_J_mol = 25000;          % effective activation energy
P.R_gas = 8.314462618;
P.min_temperature_factor = 0.25;
P.max_temperature_factor = 5.0;

% Current-density operating envelope.
P.j_ref = 0.50;              % A/cm2, reference from literature fitting
P.j_low = 0.05;              % A/cm2, idle/near-OCV proxy
P.j_high = 1.00;             % A/cm2, high-load proxy
P.k_j_low = 0.50;
P.k_j_high = 1.00;
P.max_current_factor = 8.0;

% Dynamic cycling proxy. Used only when time-series data are provided.
P.djdt_ref = 0.10;           % A/cm2/s
P.k_djdt = 0.20;
P.max_cycling_factor = 6.0;

% Aging scale. Default is for relative comparison; tune with durability data.
P.base_decay_mV_h = 0.012;   % mV/h at reference condition
P.allowable_decay_mV = 75.0; % 10% of a 0.75 V rated single-cell voltage
P.duration_h = 1.0;          % default equivalent exposure for steady rows
P.rate_floor_mV_h = 1e-6;
P.rate_cap_mV_h = 10.0;
P.ECSA_EOL_ratio = 0.60;     % proxy ECSA ratio at voltage EOL

if ~isempty(overrides)
    names = fieldnames(overrides);
    for k = 1:numel(names)
        P.(names{k}) = overrides.(names{k});
    end
end
end
