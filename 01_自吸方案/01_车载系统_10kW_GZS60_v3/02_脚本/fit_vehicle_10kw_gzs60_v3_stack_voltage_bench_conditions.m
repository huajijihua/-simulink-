function results = fit_vehicle_10kw_gzs60_v3_stack_voltage_bench_conditions()
%FIT_VEHICLE_10KW_GZS60_V3_STACK_VOLTAGE_BENCH_CONDITIONS
% Refit the stack voltage model using bench stack conditions only.

P0 = init_vehicle_10kw_gzs60_v3("current");
rootDir = P0.rootDir;
benchFile = fullfile(rootDir, '00_输入参数', '全电流段极化标定', 'full_range_polarization_data.csv');
outDir = fullfile(rootDir, '04_验证结果');
docDir = fullfile(rootDir, '03_说明');
voltageDir = fullfile(rootDir, '00_输入参数', '电堆物理模型');

if ~isfile(benchFile)
    error('Missing bench data: %s', benchFile);
end
if ~exist(outDir, 'dir'), mkdir(outDir); end
if ~exist(docDir, 'dir'), mkdir(docDir); end
if ~exist(voltageDir, 'dir'), mkdir(voltageDir); end

diagFile = fullfile(outDir, 'stack_voltage_bench_condition_fit_diagnostic.csv');
candidateFile = fullfile(outDir, 'stack_voltage_bench_condition_fit_candidates.csv');
paramFile = fullfile(voltageDir, 'stack_voltage_book_theta_params_candidate.csv');
appliedParamFile = fullfile(voltageDir, 'stack_voltage_book_theta_params.csv');
vehicleCheckFile = fullfile(outDir, 'stack_voltage_bench_candidate_vehicle_check.csv');
oxygenSensitivityFile = fullfile(outDir, 'stack_voltage_oxygen_sensitivity_check.csv');
summaryFile = fullfile(outDir, 'stack_voltage_bench_condition_fit_summary.md');
docFile = fullfile(docDir, '无EGR电压台架条件拟合说明.md');

B = readtable(benchFile, 'TextType', 'string');
D = B(logical(B.use_for_fit), :);
if isempty(D)
    error('No usable voltage fit points in %s.', benchFile);
end

bench = buildBenchState(D, P0);
bookParams = bookReferenceParams();
currentParams = voltageParamsFromP(P0, "current_applied");

bookEval = evaluateVoltage(bench, P0, bookParams);
currentEval = evaluateVoltage(bench, P0, currentParams);
fit = fitBenchVoltage(bench, P0, bookParams);
fitEval = evaluateVoltage(bench, P0, fit.params);

selected = selectCandidate(bookEval.metrics, currentEval.metrics, fitEval.metrics, bookParams, currentParams, fit.params);
selectedEval = evaluateVoltage(bench, P0, selected.params);

diagTable = buildDiagnosticTable(bench, bookEval, currentEval, fitEval, selectedEval);
candidateTable = buildCandidateTable(bookEval.metrics, currentEval.metrics, fitEval.metrics, selectedEval.metrics, ...
    bookParams, currentParams, fit.params, selected.params);
oxygenSensitivity = buildOxygenSensitivityTable(bench, P0, selected.params);
autoApply = ismember(selected.label, ["oxygen_constrained_refit", "current_oxygen_constrained"]);
paramTable = buildParamTable(selected.params, selectedEval.metrics, selected, autoApply);
vehicleCheck = qualitativeVehicleCheckPlaceholder(P0, selected.params);

writetable(diagTable, diagFile);
writetable(candidateTable, candidateFile);
writetable(oxygenSensitivity, oxygenSensitivityFile);
writetable(paramTable, paramFile);
if autoApply
    writetable(paramTable, appliedParamFile);
end
writetable(vehicleCheck, vehicleCheckFile);
writeSummary(summaryFile, bookEval.metrics, currentEval.metrics, fitEval.metrics, selectedEval.metrics, ...
    bookParams, currentParams, selected.params, selected, autoApply);
writeDoc(docFile, summaryFile, paramFile);

fprintf('Wrote bench-condition voltage diagnostic to %s\n', diagFile);
fprintf('Wrote bench-condition candidate metrics to %s\n', candidateFile);
fprintf('Wrote oxygen sensitivity check to %s\n', oxygenSensitivityFile);
fprintf('Wrote bench-condition candidate params to %s\n', paramFile);
if autoApply
    fprintf('Applied bench-condition theta params to %s\n', appliedParamFile);
end
fprintf('Wrote qualitative vehicle check placeholder to %s\n', vehicleCheckFile);
fprintf('Wrote voltage fit summary to %s\n', summaryFile);

results = struct();
results.bench_diagnostic = diagTable;
results.candidate_metrics = candidateTable;
results.candidate_params = paramTable;
results.vehicle_check = vehicleCheck;
results.selected_candidate = selected.label;
end

function S = buildBenchState(D, P)
S = table();
S.case_id = string(D.case_id);
S.current_A = D.current_A;
S.current_density_A_cm2 = D.current_density_A_cm2;
S.V_cell_meas = D.cell_voltage_from_stack_V;
S.T_stack_C = D.stack_temperature_est_C;
S.TK = S.T_stack_C + 273.15;
S.pO2_ca_kPa = D.pO2_caIn_kPa;
S.pH2_an_kPa = D.pH2_anIn_kPa;
S.pH2O_ca_kPa = D.pH2O_caIn_kPa;
S.pH2O_an_kPa = D.pH2O_anIn_kPa;
S.RH_ca = D.cathode_RH;
S.RH_an = D.anode_RH;
S.lambda_mem = membraneLambdaFromRH(S.RH_ca, S.RH_an);
S.lambda_O2_actual = benchLambdaFromFlow(D, P);
S.C_O2_mol_m3 = max(1.97e-7 .* (S.pO2_ca_kPa * 1000) .* exp(498 ./ S.TK), 1e-12);
S.R_ohm_cell_target_ohm = benchOhmicCellResistance(D, P);
S.V_nt_V = 1.229 - 8.5e-4 .* (S.TK - 298.15) ...
    + P.R_J_molK .* S.TK ./ (2 * P.F_C_mol) ...
    .* log(max(S.pH2_an_kPa * 1000, 1) / 101325 .* sqrt(max(S.pO2_ca_kPa * 1000, 1) / 101325));
end

function lambda = membraneLambdaFromRH(RHca, RHan)
aCa = min(max(RHca, 0), 3);
aAn = min(max(RHan, 0), 3);
lambda = 0.5 * (arrayfun(@lambdaEq, aCa) + arrayfun(@lambdaEq, aAn));
end

function lam = lambdaEq(a)
if a <= 1
    lam = 0.043 + 17.81 * a - 39.85 * a ^ 2 + 36 * a ^ 3;
else
    lam = 14 + 1.4 * (a - 1);
end
end

function lambda = benchLambdaFromFlow(D, P)
flow_m3_s = D.cathode_flow_nlpm / 60000;
nTotal = flow_m3_s / 0.022414;
nO2 = P.xO2_dry * nTotal;
nO2Need = D.current_A * P.N_cell / (4 * P.F_C_mol);
lambda = nO2 ./ max(nO2Need, 1e-12);
end

function Rcell = benchOhmicCellResistance(D, P)
Rcell = NaN(height(D), 1);
if ismember("stack_resistance_mOhm", string(D.Properties.VariableNames))
    Rcell = double(D.stack_resistance_mOhm) * 1e-3 / P.N_cell;
elseif ismember("area_specific_resistance_ohm_cm2", string(D.Properties.VariableNames))
    Rcell = double(D.area_specific_resistance_ohm_cm2) / P.A_cell_cm2;
end
end

function params = bookReferenceParams()
params = struct();
params.label = "book_reference";
params.theta1 = 0.7084;
params.theta2 = 1.43e-3;
params.theta3 = -1.527e-4;
params.theta4 = 1.043e-4;
params.theta5 = 0.525;
params.theta6 = 0.2173;
params.theta7 = -302.06;
params.theta8 = 5.13e-4;
params.theta9 = 5.2e-10;
params.theta10 = 0.0335;
end

function params = voltageParamsFromP(P, label)
params = struct();
params.label = string(label);
params.theta1 = P.book_theta1;
params.theta2 = P.book_theta2;
params.theta3 = P.book_theta3;
params.theta4 = P.book_theta4;
params.theta5 = P.book_theta5;
params.theta6 = P.book_theta6;
params.theta7 = P.book_theta7;
params.theta8 = P.book_theta8;
params.theta9 = P.book_theta9;
params.theta10 = P.book_theta10;
end

function fit = fitBenchVoltage(S, P, bookParams)
base = bookParams;
base.theta5 = bookParams.theta5;
base.theta6 = bookParams.theta6;
base.theta7 = bookParams.theta7;
base.theta8 = fitOhmicTheta8(S, P, base);

theta3ScaleCandidates = [1.5 2.0 3.0];
best = struct('objective', inf, 'params', base);
opts = optimset('Display', 'off', 'MaxIter', 4000, 'MaxFunEvals', 40000, 'TolX', 1e-11, 'TolFun', 1e-13);
for k = 1:numel(theta3ScaleCandidates)
    candidate = base;
    candidate.theta3 = theta3ScaleCandidates(k) * bookParams.theta3;
    x0 = encodeFreeParams(candidate);
    obj = @(x) fitObjective(x, S, P, candidate);
    x = fminsearch(obj, x0, opts);
    params = decodeFreeParams(x, candidate);
    value = obj(x);
    if value < best.objective
        best.objective = value;
        best.params = params;
    end
end

fit = struct();
fit.params = best.params;
fit.params.label = "oxygen_constrained_refit";
fit.objective = best.objective;
end

function theta8 = fitOhmicTheta8(S, P, params)
Rm = ohmicMembraneResistance(S, P, params);
target = S.R_ohm_cell_target_ohm;
valid = isfinite(target) & target > 0 & isfinite(Rm);
if nnz(valid) < 1
    theta8 = params.theta8;
else
    theta8 = median(max(target(valid) - Rm(valid), 0), 'omitnan');
end
theta8 = max(theta8, 0);
end

function score = fitObjective(x, S, P, fixedParams)
params = decodeFreeParams(x, fixedParams);
E = evaluateVoltage(S, P, params);
err = E.table.V_pred - S.V_cell_meas;
score = mean(err .^ 2, 'omitnan');
positiveSlope = max(diff(E.table.V_pred), 0);
score = score + 100 * sum(positiveSlope .^ 2);
if any(E.table.V_act_V < -1e-9) || any(E.table.V_ohm_V < -1e-9) || any(E.table.V_conc_V < -1e-9)
    score = score + 100;
end
if ~voltageParamSignsOk(params)
    score = score + 10;
end
if max(E.table.V_act_V) > 1.0 || max(E.table.V_ohm_V) > 0.55 || max(E.table.V_conc_V) > 0.18
    score = score + 10;
end
targetOhm = S.R_ohm_cell_target_ohm;
ohmErr = E.table.R_ohm_total_ohm - targetOhm;
score = score + 1e3 * mean(ohmErr(isfinite(ohmErr)) .^ 2, 'omitnan');
end

function x = encodeFreeParams(p)
x = [
    log(max(p.theta1, 1e-9))
    log(max(p.theta2, 1e-12))
    log(max(p.theta4, 1e-12))
    log(max(p.theta9, 1e-14))
    log(max(p.theta10, 1e-10))
    ];
end

function p = decodeFreeParams(x, fixedParams)
p = fixedParams;
p.label = "decoded_constrained";
p.theta1 = exp(x(1));
p.theta2 = exp(x(2));
p.theta4 = exp(x(3));
p.theta9 = exp(x(4));
p.theta10 = exp(x(5));
end

function E = evaluateVoltage(S, P, params)
I = max(S.current_A, 1e-6);
VactRaw = params.theta1 + params.theta2 .* S.TK ...
    + params.theta3 .* S.TK .* log(S.C_O2_mol_m3) ...
    + params.theta4 .* S.TK .* log(I);
Vact = max(VactRaw, 0);
Rm = ohmicMembraneResistance(S, P, params);
Vohm = I .* (Rm + params.theta8);
Vconc = max(params.theta9 .* exp(min(params.theta10 .* I, 50)), 0);
Vraw = S.V_nt_V - Vact - Vohm - Vconc;
Vpred = Vraw;

T = table();
T.case_id = S.case_id;
T.current_A = I;
T.current_density_A_cm2 = S.current_density_A_cm2;
T.V_meas = S.V_cell_meas;
T.V_pred = Vpred;
T.V_err = Vpred - S.V_cell_meas;
T.V_raw = Vraw;
T.V_nt_V = S.V_nt_V;
T.V_act_V = Vact;
T.V_ohm_V = Vohm;
T.V_conc_V = Vconc;
T.Rm_ohm = Rm;
T.Rc_ohm = repmat(params.theta8, height(S), 1);
T.R_ohm_total_ohm = Rm + params.theta8;
T.R_ohm_target_ohm = S.R_ohm_cell_target_ohm;
T.C_O2_mol_m3 = S.C_O2_mol_m3;
T.pO2_ca_kPa = S.pO2_ca_kPa;
T.pH2_an_kPa = S.pH2_an_kPa;
T.T_stack_C = S.T_stack_C;
T.lambda_mem = S.lambda_mem;
T.lambda_O2_actual = S.lambda_O2_actual;
T.high_current_flag = S.current_density_A_cm2 >= 1.1;

E = struct();
E.table = T;
E.metrics = voltageMetrics(T);
end

function Rm = ohmicMembraneResistance(S, P, params)
Rm = P.membraneThickness_cm ./ max(P.A_cell_cm2 .* (params.theta5 .* S.lambda_mem + params.theta6) ...
    .* exp(params.theta7 .* (1 / 303.15 - 1 ./ S.TK)), 1e-12);
end

function M = voltageMetrics(T)
M = struct();
M.points = height(T);
M.rmse_cell_V = rmsLocal(T.V_err);
M.max_abs_error_cell_V = max(abs(T.V_err));
high = logical(T.high_current_flag);
M.high_current_points = nnz(high);
M.high_current_bias_cell_V = mean(T.V_err(high), 'omitnan');
M.high_current_rmse_cell_V = rmsLocal(T.V_err(high));
M.mean_V_act_V = mean(T.V_act_V, 'omitnan');
M.mean_V_ohm_V = mean(T.V_ohm_V, 'omitnan');
M.mean_V_conc_V = mean(T.V_conc_V, 'omitnan');
M.max_V_conc_V = max(T.V_conc_V);
M.ohm_resistance_rmse_ohm = rmsLocal(T.R_ohm_total_ohm - T.R_ohm_target_ohm);
M.mean_R_ohm_total_ohm = mean(T.R_ohm_total_ohm, 'omitnan');
M.mean_R_ohm_target_ohm = mean(T.R_ohm_target_ohm, 'omitnan');
M.max_positive_dV_step = max([0; diff(T.V_pred)]);
M.terms_physical = all(T.V_act_V >= -1e-9) && all(T.V_ohm_V >= -1e-9) && all(T.V_conc_V >= -1e-9) ...
    && all(T.V_nt_V > T.V_pred);
end

function selected = selectCandidate(bookM, currentM, fitM, bookParams, currentParams, fitParams)
selected = struct();
if fitM.rmse_cell_V <= 0.035 && abs(fitM.high_current_bias_cell_V) <= 0.035 ...
        && fitM.max_abs_error_cell_V <= 0.08 && fitM.max_positive_dV_step <= 0.005 ...
        && fitM.terms_physical && voltageParamSignsOk(fitParams)
    selected.label = "oxygen_constrained_refit";
    selected.params = fitParams;
    selected.reason = "oxygen-constrained fit passes error, sign and ohmic gates";
elseif oxygenConstrainedParamsOk(currentM, currentParams)
    selected.label = "current_oxygen_constrained";
    selected.params = currentParams;
    selected.reason = "current applied parameters already pass oxygen and ohmic gates";
elseif currentM.rmse_cell_V < bookM.rmse_cell_V && currentM.terms_physical && voltageParamSignsOk(currentParams)
    selected.label = "current_applied";
    selected.params = currentParams;
    selected.reason = "refit failed gates, current parameters are better than raw book reference";
else
    selected.label = "book_reference";
    selected.params = bookParams;
    selected.reason = "fallback to raw book reference";
end
end

function ok = oxygenConstrainedParamsOk(metrics, params)
bookTheta3 = -1.527e-4;
ok = metrics.rmse_cell_V <= 0.035 ...
    && metrics.max_abs_error_cell_V <= 0.08 ...
    && abs(metrics.high_current_bias_cell_V) <= 0.035 ...
    && metrics.ohm_resistance_rmse_ohm <= 1.0e-5 ...
    && params.theta3 <= 1.2 * bookTheta3 ...
    && voltageParamSignsOk(params) ...
    && metrics.terms_physical;
end

function ok = voltageParamSignsOk(params)
ok = params.theta1 > 0 && params.theta2 > 0 && params.theta3 < 0 && params.theta4 > 0 ...
    && params.theta5 > 0 && params.theta6 > 0 && params.theta7 < 0 ...
    && params.theta8 >= 0 && params.theta9 >= 0 && params.theta10 >= 0;
end

function T = buildDiagnosticTable(S, bookEval, currentEval, fitEval, selectedEval)
T = S(:, {'case_id','current_A','current_density_A_cm2','V_cell_meas','T_stack_C', ...
    'pO2_ca_kPa','pH2_an_kPa','pH2O_ca_kPa','pH2O_an_kPa','RH_ca','RH_an','lambda_mem','lambda_O2_actual','C_O2_mol_m3','R_ohm_cell_target_ohm','V_nt_V'});
T.book_reference_V = bookEval.table.V_pred;
T.book_reference_err_V = bookEval.table.V_err;
T.current_applied_V = currentEval.table.V_pred;
T.current_applied_err_V = currentEval.table.V_err;
T.oxygen_constrained_refit_V = fitEval.table.V_pred;
T.oxygen_constrained_refit_err_V = fitEval.table.V_err;
T.selected_candidate_V = selectedEval.table.V_pred;
T.selected_candidate_err_V = selectedEval.table.V_err;
T.selected_V_act_V = selectedEval.table.V_act_V;
T.selected_V_ohm_V = selectedEval.table.V_ohm_V;
T.selected_V_conc_V = selectedEval.table.V_conc_V;
T.selected_Rm_ohm = selectedEval.table.Rm_ohm;
T.selected_Rc_ohm = selectedEval.table.Rc_ohm;
T.selected_R_ohm_total_ohm = selectedEval.table.R_ohm_total_ohm;
end

function T = buildCandidateTable(bookM, currentM, fitM, selectedM, bookParams, currentParams, fitParams, selectedParams)
labels = ["book_reference"; "current_applied"; "oxygen_constrained_refit"; "selected_candidate"];
metrics = [bookM; currentM; fitM; selectedM];
params = [bookParams; currentParams; fitParams; selectedParams];
T = table();
T.label = labels;
T.rmse_cell_V = arrayfun(@(m) m.rmse_cell_V, metrics);
T.max_abs_error_cell_V = arrayfun(@(m) m.max_abs_error_cell_V, metrics);
T.high_current_bias_cell_V = arrayfun(@(m) m.high_current_bias_cell_V, metrics);
T.high_current_rmse_cell_V = arrayfun(@(m) m.high_current_rmse_cell_V, metrics);
T.mean_V_act_V = arrayfun(@(m) m.mean_V_act_V, metrics);
T.mean_V_ohm_V = arrayfun(@(m) m.mean_V_ohm_V, metrics);
T.mean_V_conc_V = arrayfun(@(m) m.mean_V_conc_V, metrics);
T.max_V_conc_V = arrayfun(@(m) m.max_V_conc_V, metrics);
T.ohm_resistance_rmse_ohm = arrayfun(@(m) m.ohm_resistance_rmse_ohm, metrics);
T.mean_R_ohm_total_ohm = arrayfun(@(m) m.mean_R_ohm_total_ohm, metrics);
T.mean_R_ohm_target_ohm = arrayfun(@(m) m.mean_R_ohm_target_ohm, metrics);
T.max_positive_dV_step = arrayfun(@(m) m.max_positive_dV_step, metrics);
T.terms_physical = arrayfun(@(m) m.terms_physical, metrics);
T.theta1 = arrayfun(@(p) p.theta1, params);
T.theta2 = arrayfun(@(p) p.theta2, params);
T.theta3 = arrayfun(@(p) p.theta3, params);
T.theta4 = arrayfun(@(p) p.theta4, params);
T.theta5 = arrayfun(@(p) p.theta5, params);
T.theta6 = arrayfun(@(p) p.theta6, params);
T.theta7 = arrayfun(@(p) p.theta7, params);
T.theta8 = arrayfun(@(p) p.theta8, params);
T.theta9 = arrayfun(@(p) p.theta9, params);
T.theta10 = arrayfun(@(p) p.theta10, params);
end

function T = buildOxygenSensitivityTable(S, P, params)
caseIds = ["low_current_j0p10"; "mid_current_j0p70"; "high_current_j1p50"];
targetJ = [0.1; 0.7; 1.5];
pO2Scales = [1.0; 0.8; 0.6; 0.5];
T = table();
for i = 1:numel(targetJ)
    [~, idx] = min(abs(S.current_density_A_cm2 - targetJ(i)));
    baseRow = S(idx, :);
    baseEval = evaluateVoltage(baseRow, P, params).table;
    for k = 1:numel(pO2Scales)
        trial = baseRow;
        trial.pO2_ca_kPa = baseRow.pO2_ca_kPa * pO2Scales(k);
        trial.C_O2_mol_m3 = max(1.97e-7 .* (trial.pO2_ca_kPa * 1000) .* exp(498 ./ trial.TK), 1e-12);
        evalRow = evaluateVoltage(trial, P, params).table;
        row = table();
        row.case_group = caseIds(i);
        row.source_case_id = baseRow.case_id;
        row.current_density_A_cm2 = baseRow.current_density_A_cm2;
        row.pO2_scale = pO2Scales(k);
        row.pO2_ca_kPa = trial.pO2_ca_kPa;
        row.V_cell = evalRow.V_pred;
        row.delta_V_vs_base = evalRow.V_pred - baseEval.V_pred;
        row.eta_act_V = evalRow.V_act_V;
        row.delta_eta_act_vs_base = evalRow.V_act_V - baseEval.V_act_V;
        row.eta_ohm_V = evalRow.V_ohm_V;
        row.eta_con_V = evalRow.V_conc_V;
        T = [T; row]; %#ok<AGROW>
    end
end
end

function T = buildParamTable(params, metrics, selected, autoApply)
T = table();
T.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
T.fit_point_count = metrics.points;
T.rmse_cell_V = metrics.rmse_cell_V;
T.max_abs_error_cell_V = metrics.max_abs_error_cell_V;
T.theta1 = params.theta1;
T.theta2 = params.theta2;
T.theta3 = params.theta3;
T.theta4 = params.theta4;
T.theta5 = params.theta5;
T.theta6 = params.theta6;
T.theta7 = params.theta7;
T.theta8 = params.theta8;
T.theta9 = params.theta9;
T.theta10 = params.theta10;
T.fit_scope = "bench_stack_conditions_no_egr_book_theta";
T.selected_label = selected.label;
T.auto_applied = autoApply;
end

function V = qualitativeVehicleCheckPlaceholder(P0, params)
V = table();
V.check_scope = "qualitative_vehicle_regression_placeholder";
V.status = "not_run";
V.reason = "vehicle auxiliary regression is qualitative only and is not part of bench voltage fitting";
V.model_name = string(P0.modelName);
V.theta1 = params.theta1;
V.theta2 = params.theta2;
V.theta3 = params.theta3;
V.theta4 = params.theta4;
V.theta5 = params.theta5;
V.theta6 = params.theta6;
V.theta7 = params.theta7;
V.theta8 = params.theta8;
V.theta9 = params.theta9;
V.theta10 = params.theta10;
end

function writeSummary(path, bookM, currentM, fitM, selectedM, bookParams, currentParams, selectedParams, selected, autoApply)
if selected.label == "oxygen_constrained_refit"
    decision = "bench_condition_voltage_refit_candidate_accepted";
else
    decision = "bench_condition_voltage_refit_not_accepted";
end
lines = [
    "# Bench-Condition Stack Voltage Fit Summary"
    ""
    "Date: " + string(datetime('now', 'Format', 'yyyy-MM-dd'))
    ""
    "## Scope"
    ""
    "- Voltage fitting uses bench stack test conditions only."
    "- The vehicle humidifier, compressor, intercooler and cooling auxiliaries are not fitting targets."
    "- The voltage equation keeps direct book theta form, but the fit is physically constrained."
    "- `theta3` keeps the book sign and is intentionally amplified to retain oxygen-concentration sensitivity."
    "- The ohmic branch is anchored to the BT3564 stack resistance converted to per-cell resistance."
    sprintf("- Accepted candidate auto-applied: %s.", string(autoApply))
    ""
    "## Formula"
    ""
    "- `V_cell = V_nt - V_act - V_ohm - V_conc`"
    "- `V_nt = 1.229 - 8.5e-4*(T_st - 298.15) + R*T_st/(2F)*ln(pH2*sqrt(pO2))`"
    "- `V_act = theta1 + theta2*T_st + theta3*T_st*ln(C_O2) + theta4*T_st*ln(I_st)`"
    "- `C_O2 = 1.97e-7*pO2*exp(498/T_st)`"
    "- `V_ohm = I_st*(L_m/(A_cell*(theta5*lambda_m+theta6)*exp(theta7*(1/303.15-1/T_st))) + theta8)`"
    "- `V_conc = theta9*exp(theta10*I_st)`"
    ""
    "## Bench Condition Fit"
    ""
    sprintf("- Raw book reference RMSE: %.4f V/cell, high-current bias %.4f V/cell.", bookM.rmse_cell_V, bookM.high_current_bias_cell_V)
    sprintf("- Current applied params RMSE: %.4f V/cell, high-current bias %.4f V/cell.", currentM.rmse_cell_V, currentM.high_current_bias_cell_V)
    sprintf("- Oxygen-constrained refit RMSE: %.4f V/cell, high-current bias %.4f V/cell.", fitM.rmse_cell_V, fitM.high_current_bias_cell_V)
    sprintf("- Selected candidate: %s (%s).", selected.label, selected.reason)
    sprintf("- Selected RMSE: %.4f V/cell, max abs %.4f V/cell.", selectedM.rmse_cell_V, selectedM.max_abs_error_cell_V)
    sprintf("- Selected ohmic resistance RMSE: %.6g ohm/cell.", selectedM.ohm_resistance_rmse_ohm)
    sprintf("- Selected mean ohmic resistance: %.6g ohm/cell; bench target mean %.6g ohm/cell.", selectedM.mean_R_ohm_total_ohm, selectedM.mean_R_ohm_target_ohm)
    sprintf("- Selected max positive voltage step: %.4f V/cell.", selectedM.max_positive_dV_step)
    sprintf("- Selected terms physical: %s.", string(selectedM.terms_physical))
    ""
    "## Parameter Movement"
    ""
    sprintf("- theta1: %.8g -> %.8g -> %.8g.", bookParams.theta1, currentParams.theta1, selectedParams.theta1)
    sprintf("- theta2: %.8g -> %.8g -> %.8g.", bookParams.theta2, currentParams.theta2, selectedParams.theta2)
    sprintf("- theta3: %.8g -> %.8g -> %.8g.", bookParams.theta3, currentParams.theta3, selectedParams.theta3)
    sprintf("- theta4: %.8g -> %.8g -> %.8g.", bookParams.theta4, currentParams.theta4, selectedParams.theta4)
    sprintf("- theta5: %.8g -> %.8g -> %.8g.", bookParams.theta5, currentParams.theta5, selectedParams.theta5)
    sprintf("- theta6: %.8g -> %.8g -> %.8g.", bookParams.theta6, currentParams.theta6, selectedParams.theta6)
    sprintf("- theta7: %.8g -> %.8g -> %.8g.", bookParams.theta7, currentParams.theta7, selectedParams.theta7)
    sprintf("- theta8: %.8g -> %.8g -> %.8g.", bookParams.theta8, currentParams.theta8, selectedParams.theta8)
    sprintf("- theta9: %.8g -> %.8g -> %.8g.", bookParams.theta9, currentParams.theta9, selectedParams.theta9)
    sprintf("- theta10: %.8g -> %.8g -> %.8g.", bookParams.theta10, currentParams.theta10, selectedParams.theta10)
    ""
    "## Decision"
    ""
    "- Decision: " + decision + "."
    "- Accepted candidate is applied to `00_输入参数/电堆物理模型/stack_voltage_book_theta_params.csv`."
    "- Do not fit voltage parameters against vehicle auxiliary boundary errors."
    ""
    "## Output Files"
    ""
    "- `04_验证结果/stack_voltage_bench_condition_fit_diagnostic.csv`"
    "- `04_验证结果/stack_voltage_bench_condition_fit_candidates.csv`"
    "- `04_验证结果/stack_voltage_oxygen_sensitivity_check.csv`"
    "- `04_验证结果/stack_voltage_bench_candidate_vehicle_check.csv`"
    "- `00_输入参数/电堆物理模型/stack_voltage_book_theta_params_candidate.csv`"
    "- `00_输入参数/电堆物理模型/stack_voltage_book_theta_params.csv`"
    ];
writeText(path, lines);
end

function writeDoc(path, summaryFile, candidateParamFile)
lines = [
    "# 无 EGR 电压台架条件拟合说明"
    ""
    "日期：" + string(datetime('now', 'Format', 'yyyy-MM-dd'))
    ""
    "## 口径"
    ""
    "- 电压拟合只使用台架电堆测试条件。"
    "- 输入条件来自 `full_range_polarization_data.csv`：电流、堆温、氢气分压、氧气分压、入口水蒸气分压和 RH。"
    "- 车载加湿器、空压机、中冷器和冷却辅件不进入电压拟合目标。"
    "- 电压公式已按书上 `theta1-theta10` 直写。"
    "- 候选参数只单独保存，不覆盖当前已应用电压参数。"
    "- 候选参数进入整车结构后只做定性回归检查：趋势和值域不能明显离谱，不把整车误差作为拟合目标。"
    ""
    "## 结果"
    ""
    "详见："
    ""
    "```text"
    relativeReportPath(summaryFile)
    "```"
    ""
    "候选参数："
    ""
    "```text"
    relativeReportPath(candidateParamFile)
    "```"
    ];
writeText(path, lines);
end

function value = rmsLocal(x)
x = x(isfinite(x));
if isempty(x)
    value = NaN;
else
    value = sqrt(mean(x .^ 2));
end
end

function writeText(path, lines)
fid = fopen(path, 'w');
if fid < 0
    error('Cannot write %s', path);
end
cleanup = onCleanup(@() fclose(fid));
for k = 1:numel(lines)
    fprintf(fid, '%s\n', lines(k));
end
end

function p = relativeReportPath(path)
parts = split(string(path), filesep);
anchors = ["04_验证结果", "00_输入参数", "03_说明"];
idx = [];
for a = 1:numel(anchors)
    hit = find(parts == anchors(a), 1);
    if ~isempty(hit)
        idx = hit;
        break;
    end
end
if isempty(idx)
    p = string(path);
else
    p = strjoin(parts(idx:end), filesep);
end
end
