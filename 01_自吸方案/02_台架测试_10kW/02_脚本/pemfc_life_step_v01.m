function [stateNext, out] = pemfc_life_step_v01(state, input, dt_s, P)
%PEMFC_LIFE_STEP_V01 Discrete aging-state update for Simulink integration.
%
% This function is intentionally struct-based for MATLAB prototyping. A
% later Simulink MATLAB Function block can map the same fields to buses.

if nargin < 4 || isempty(P)
    P = pemfc_life_params_v01();
end
if isempty(state)
    state = initialState();
end
if nargin < 3 || isempty(dt_s)
    dt_s = 1.0;
end

duration_h = max(dt_s, 0) / 3600;
V_cell = getField(input, 'V_cell', P.V_ref);
j = getField(input, 'current_density_A_cm2', P.j_ref);
RH = getField(input, 'RH_ca_in', P.RH_ref);
T_C = getField(input, 'T_stack_C', P.T_ref_K - 273.15);
djdt = getField(input, 'djdt_A_cm2_s', 0);

core = pemfc_life_core_v01(V_cell, j, RH, T_C, duration_h, P, djdt);

stateNext = state;
stateNext.age_h = state.age_h + duration_h;
stateNext.delta_V_deg_mV = state.delta_V_deg_mV + core.delta_V_deg_mV;
stateNext.damage_index = stateNext.delta_V_deg_mV / P.allowable_decay_mV;
stateNext.high_potential_exposure_V_h = state.high_potential_exposure_V_h + core.high_potential_exposure_V_h;
stateNext.dry_exposure_h = state.dry_exposure_h + core.dry_exposure_h;
stateNext.ECSA_ratio_proxy = 1 - (1 - P.ECSA_EOL_ratio) * min(max(stateNext.damage_index, 0), 1);
stateNext.ECSA_ratio_proxy = max(stateNext.ECSA_ratio_proxy, 0);

out = core;
out.age_h = stateNext.age_h;
out.delta_V_deg_mV_cumulative = stateNext.delta_V_deg_mV;
out.damage_index_cumulative = stateNext.damage_index;
out.ECSA_ratio_proxy_cumulative = stateNext.ECSA_ratio_proxy;
out.projected_remaining_life_h = max(P.allowable_decay_mV - stateNext.delta_V_deg_mV, 0) ./ ...
    max(core.life_damage_rate_mV_h, P.rate_floor_mV_h);
end

function state = initialState()
state = struct();
state.age_h = 0;
state.delta_V_deg_mV = 0;
state.damage_index = 0;
state.high_potential_exposure_V_h = 0;
state.dry_exposure_h = 0;
state.ECSA_ratio_proxy = 1;
end

function value = getField(s, name, defaultValue)
if isstruct(s) && isfield(s, name)
    value = s.(name);
else
    value = defaultValue;
end
end
