function [Tout, summary] = pemfc_life_evaluate_table_v01(Tin, P, options)
%PEMFC_LIFE_EVALUATE_TABLE_V01 Apply life model to a result table.

if nargin < 2 || isempty(P)
    P = pemfc_life_params_v01();
end
if nargin < 3
    options = struct();
end
if ~isfield(options, 'duration_h')
    options.duration_h = P.duration_h;
end

Tout = Tin;
n = height(Tout);

V = getNumeric(Tout, ["V_cell_sim", "V_cell", "cell_voltage_V"], NaN(n, 1));
j = getNumeric(Tout, ["current_density_command_A_cm2", "current_density_target_A_cm2", ...
    "current_density_A_cm2", "current_density_solved_A_cm2"], P.j_ref .* ones(n, 1));
RH = getNumeric(Tout, ["RH_ca_in", "cathode_RH", "RH"], P.RH_ref .* ones(n, 1));
T_C = getNumeric(Tout, ["T_stack_sim_C", "T_stack_C", "stack_temperature_C", "T_C"], (P.T_ref_K - 273.15) .* ones(n, 1));
duration_h = getNumeric(Tout, ["duration_h", "equivalent_duration_h"], options.duration_h .* ones(n, 1));
normalOk = getLogicalAny(Tout, ["normal_operation_ok", "scan_usable", "pressure_order_ok"], true(n, 1));
if ~ismember('normal_operation_ok', Tout.Properties.VariableNames) && ismember('interpretation_status', Tout.Properties.VariableNames)
    status = lower(string(Tout.interpretation_status));
    normalOk = normalOk & (status == "normal" | status == "usable");
end

if any(isnan(V))
    error('pemfc_life_evaluate_table_v01:MissingVoltage', 'Input table must include V_cell_sim or equivalent.');
end

djdt = zeros(n, 1);
if ismember('time_s', Tout.Properties.VariableNames)
    time_s = Tout.time_s;
    if n > 1
        djdt = gradient(j) ./ max(gradient(time_s), eps);
    end
end

core = pemfc_life_core_v01(V, j, RH, T_C, duration_h, P, djdt);

Tout.life_model_version = repmat(P.version, n, 1);
Tout.life_equivalent_duration_h = duration_h;
Tout.life_voltage_factor = core.voltage_factor;
Tout.life_humidity_factor = core.humidity_factor;
Tout.life_temperature_factor = core.temperature_factor;
Tout.life_current_factor = core.current_factor;
Tout.life_cycling_factor = core.cycling_factor;
Tout.life_damage_rate_mV_h = core.life_damage_rate_mV_h;
Tout.life_delta_V_deg_mV = core.delta_V_deg_mV;
Tout.life_damage_index = core.life_damage_index;
Tout.life_projected_to_EOL_h = core.projected_life_to_EOL_h;
Tout.life_ECSA_ratio_proxy = core.ECSA_ratio_proxy;
Tout.life_high_potential_exposure_V_h = core.high_potential_exposure_V_h;
Tout.life_dry_exposure_h = core.dry_exposure_h;
Tout.life_high_potential_margin_mV = core.high_potential_margin_mV;
Tout.life_interpretation_status = repmat("usable", n, 1);
Tout.life_interpretation_status(~normalOk) = "trend_reference";
if ismember('egr_ratio_cmd', Tout.Properties.VariableNames) && ~ismember('egr_fraction_cmd', Tout.Properties.VariableNames)
    Tout.egr_fraction_cmd = Tout.egr_ratio_cmd;
end

[Tout, summary] = addBaselineComparison(Tout, normalOk);
end

function x = getNumeric(T, names, defaultValue)
names = string(names);
x = defaultValue;
for k = 1:numel(names)
    name = char(names(k));
    if ismember(name, T.Properties.VariableNames)
        x = T.(name);
        if iscell(x) || isstring(x) || ischar(x)
            x = str2double(string(x));
        end
        x = double(x(:));
        return;
    end
end
end

function x = getLogical(T, name, defaultValue)
x = defaultValue;
if ismember(name, T.Properties.VariableNames)
    raw = T.(name);
    if islogical(raw)
        x = raw(:);
    elseif isnumeric(raw)
        x = raw(:) ~= 0;
    else
        x = lower(string(raw(:))) == "true" | string(raw(:)) == "1";
    end
end
end

function x = getLogicalAny(T, names, defaultValue)
names = string(names);
x = defaultValue;
for k = 1:numel(names)
    name = char(names(k));
    if ismember(name, T.Properties.VariableNames)
        raw = T.(name);
        if islogical(raw)
            x = raw(:);
        elseif isnumeric(raw)
            x = raw(:) ~= 0;
        else
            x = lower(string(raw(:))) == "true" | string(raw(:)) == "1";
        end
        return;
    end
    end
end

function [T, summary] = addBaselineComparison(T, normalOk)
n = height(T);
keys = makeGroupKey(T);
egr = getNumeric(T, ["egr_fraction_cmd", "egr_ratio_cmd", "EGR", "egr"], NaN(n, 1));
T.life_group_key = keys;
T.life_rate_ratio_to_noEGR = NaN(n, 1);
T.life_benefit_vs_noEGR_pct = NaN(n, 1);

uniqueKeys = unique(keys, 'stable');
summaryRows = table();
for k = 1:numel(uniqueKeys)
    key = uniqueKeys(k);
    idx = keys == key;
    baseIdx = idx & abs(egr) < 1e-12;
    if ~any(baseIdx)
        continue;
    end
    baseRate = mean(T.life_damage_rate_mV_h(baseIdx), 'omitnan');
    T.life_rate_ratio_to_noEGR(idx) = T.life_damage_rate_mV_h(idx) ./ baseRate;
    T.life_benefit_vs_noEGR_pct(idx) = (1 - T.life_rate_ratio_to_noEGR(idx)) .* 100;

    candidateIdx = idx & normalOk;
    if ~any(candidateIdx)
        candidateIdx = idx;
    end
    local = T(candidateIdx, :);
    [bestRate, bestLocal] = min(local.life_damage_rate_mV_h);
    bestRow = local(bestLocal, :);

    row = table();
    row.life_group_key = key;
    row.baseline_rate_mV_h = baseRate;
    row.best_rate_mV_h = bestRate;
    row.best_benefit_vs_noEGR_pct = (1 - bestRate ./ baseRate) .* 100;
    if ismember('egr_fraction_cmd', bestRow.Properties.VariableNames)
        row.best_egr_fraction_cmd = bestRow.egr_fraction_cmd(1);
    elseif ismember('egr_ratio_cmd', bestRow.Properties.VariableNames)
        row.best_egr_fraction_cmd = bestRow.egr_ratio_cmd(1);
    elseif ismember('EGR', bestRow.Properties.VariableNames)
        row.best_egr_fraction_cmd = bestRow.EGR(1);
    else
        row.best_egr_fraction_cmd = NaN;
    end
    summaryRows = [summaryRows; row]; %#ok<AGROW>
end

summary = summaryRows;
end

function keys = makeGroupKey(T)
n = height(T);
keys = strings(n, 1);
study = repmat("study", n, 1);
if ismember('study_type', T.Properties.VariableNames)
    study = string(T.study_type);
elseif ismember('condition', T.Properties.VariableNames)
    study = string(T.condition);
end

if ismember('V_cell_target', T.Properties.VariableNames) && any(study == "constant_voltage_fixed_flow")
    target = "V=" + string(round(T.V_cell_target, 4));
elseif ismember('current_density_target_A_cm2', T.Properties.VariableNames)
    target = "j=" + string(round(T.current_density_target_A_cm2, 4));
elseif ismember('current_density_command_A_cm2', T.Properties.VariableNames)
    target = "j=" + string(round(T.current_density_command_A_cm2, 4));
elseif ismember('current_density_A_cm2', T.Properties.VariableNames)
    target = "j=" + string(round(T.current_density_A_cm2, 4));
elseif ismember('V_cell_target', T.Properties.VariableNames)
    target = "V=" + string(round(T.V_cell_target, 4));
elseif ismember('case_label', T.Properties.VariableNames)
    target = string(T.case_label);
else
    target = repmat("all", n, 1);
end
for i = 1:n
    keys(i) = study(i) + "|" + target(i);
end
end
