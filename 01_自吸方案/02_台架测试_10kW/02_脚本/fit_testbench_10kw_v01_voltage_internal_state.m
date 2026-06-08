function results = fit_testbench_10kw_v01_voltage_internal_state(options)
%FIT_TESTBENCH_10KW_V01_VOLTAGE_INTERNAL_STATE
% Refit stack voltage parameters using the internal states consumed by the
% Simulink PEMFCStackCore voltage equations.

if nargin < 1
    options = struct();
end
if ~isfield(options, 'RegenerateSource')
    options.RegenerateSource = false;
end
if ~isfield(options, 'ApplyParams')
    options.ApplyParams = true;
end

P = init_testbench_10kw_v01(1, 0.0);
sourceFile = fullfile(P.resultDir, 'testbench_constant_current_no_egr_internal_state_refit_source.csv');
diagFile = fullfile(P.resultDir, 'stack_voltage_internal_state_fit_diagnostic.csv');
candidateFile = fullfile(P.resultDir, 'stack_voltage_internal_state_fit_candidates.csv');
paramFile = fullfile(P.vehicleRoot, '00_输入参数', '电堆物理模型', 'stack_voltage_book_theta_params.csv');
candidateParamFile = fullfile(P.vehicleRoot, '00_输入参数', '电堆物理模型', 'stack_voltage_book_theta_params_internal_state_candidate.csv');
summaryFile = fullfile(P.resultDir, 'stack_voltage_internal_state_fit_summary.md');

if options.RegenerateSource || ~isfile(sourceFile)
    run_testbench_10kw_v01_constant_current(0, 'testbench_constant_current_no_egr_internal_state_refit_source.csv');
end

S = readInternalStateSource(sourceFile, P);
bookParams = bookReferenceParams();
currentParams = voltageParamsFromP(P, "current_applied");
fit = fitInternalStateVoltage(S, P, currentParams);

bookEval = evaluateVoltage(S, P, bookParams);
currentEval = evaluateVoltage(S, P, currentParams);
fitEval = evaluateVoltage(S, P, fit.params);

diag = buildDiagnosticTable(S, bookEval, currentEval, fitEval);
candidates = buildCandidateTable(bookEval.metrics, currentEval.metrics, fitEval.metrics, ...
    bookParams, currentParams, fit.params);
paramTable = buildParamTable(fit.params, fitEval.metrics, options.ApplyParams);

writetable(diag, diagFile);
writetable(candidates, candidateFile);
writetable(paramTable, candidateParamFile);
if options.ApplyParams
    writetable(paramTable, paramFile);
end
writeSummary(summaryFile, bookEval.metrics, currentEval.metrics, fitEval.metrics, ...
    bookParams, currentParams, fit.params, options.ApplyParams);

fprintf('Wrote internal-state voltage diagnostic to %s\n', diagFile);
fprintf('Wrote internal-state candidate metrics to %s\n', candidateFile);
fprintf('Wrote internal-state candidate params to %s\n', candidateParamFile);
if options.ApplyParams
    fprintf('Applied internal-state theta params to %s\n', paramFile);
end
fprintf('Wrote internal-state voltage fit summary to %s\n', summaryFile);

results = struct();
results.source = S;
results.diagnostic = diag;
results.candidates = candidates;
results.params = paramTable;
results.summaryFile = summaryFile;
end

function S = readInternalStateSource(sourceFile, P)
T = readtable(sourceFile, 'TextType', 'string');
required = ["case_id", "current_A", "current_density_A_cm2", "V_cell_bench", ...
    "E_nernst_V", "CO2_voltage_mol_m3", "lambda_membrane", "T_stack_C"];
missing = setdiff(required, string(T.Properties.VariableNames));
if ~isempty(missing)
    error('CEGR:InternalVoltageSourceMissingColumns', ...
        'Internal-state voltage source is missing columns: %s', strjoin(missing, ', '));
end

S = table();
S.case_id = string(T.case_id);
S.current_A = T.current_A;
S.current_density_A_cm2 = T.current_density_A_cm2;
S.V_cell_meas = T.V_cell_bench;
S.E_nernst_V = T.E_nernst_V;
S.C_O2_mol_m3 = max(T.CO2_voltage_mol_m3, 1e-12);
S.lambda_mem = T.lambda_membrane;
S.T_stack_C = T.T_stack_C;
S.TK = S.T_stack_C + 273.15;
S.pO2_core_in_kPa = optionalColumn(T, "pO2_core_in_kPa");
S.pO2_stack_kPa = optionalColumn(T, "pO2_stack_kPa");
S.pH2_stack_kPa = optionalColumn(T, "pH2_stack_kPa");
S.RH_stack = optionalColumn(T, "RH_stack");
S.lambda_O2_actual = optionalColumn(T, "lambda_O2_actual");
S.fit_weight = voltageFitWeights(S.current_density_A_cm2);
S.Rm_current_ohm = membraneResistance(S, P, voltageParamsFromP(P, "current_applied"));
end

function values = optionalColumn(T, name)
if ismember(string(name), string(T.Properties.VariableNames))
    values = T.(char(name));
else
    values = nan(height(T), 1);
end
end

function w = voltageFitWeights(j)
w = ones(size(j));
w(j <= 0.3) = 4;
w(j > 0.3 & j <= 0.7) = 2;
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

function fit = fitInternalStateVoltage(S, P, currentParams)
starts = repmat(currentParams, 4, 1);
starts(2) = bookReferenceParams();
starts(3).theta1 = 1e-3;
starts(3).theta2 = 1e-4;
starts(3).theta3 = -1.5e-4;
starts(3).theta4 = 1e-5;
starts(3).theta8 = currentParams.theta8;
starts(4).theta1 = 0.1;
starts(4).theta2 = 1e-4;
starts(4).theta3 = -1e-4;
starts(4).theta4 = 1e-5;
starts(4).theta8 = currentParams.theta8;

opts = optimset('Display', 'off', 'MaxIter', 10000, 'MaxFunEvals', 100000, ...
    'TolX', 1e-12, 'TolFun', 1e-13);
bestScore = inf;
bestParams = currentParams;
for k = 1:numel(starts)
    x0 = encodeFreeParams(starts(k));
    obj = @(x) fitObjective(x, S, P, currentParams);
    [x, score] = fminsearch(obj, x0, opts);
    params = decodeFreeParams(x, currentParams);
    if score < bestScore
        bestScore = score;
        bestParams = params;
    end
end
bestParams.label = "internal_state_weighted_refit";
fit = struct();
fit.params = bestParams;
fit.score = bestScore;
end

function x = encodeFreeParams(params)
x = [
    log(max(params.theta1, 1e-12))
    log(max(params.theta2, 1e-12))
    log(max(-params.theta3, 1e-12))
    log(max(params.theta4, 1e-14))
    log(max(params.theta8, 1e-12))
    ];
end

function params = decodeFreeParams(x, fixedParams)
params = fixedParams;
params.label = "decoded_internal_state";
params.theta1 = exp(x(1));
params.theta2 = exp(x(2));
params.theta3 = -exp(x(3));
params.theta4 = exp(x(4));
params.theta8 = exp(x(5));
end

function score = fitObjective(x, S, P, currentParams)
params = decodeFreeParams(x, currentParams);
E = evaluateVoltage(S, P, params);
err = E.table.V_err;
w = S.fit_weight;
score = sum(w .* err .^ 2, 'omitnan') / sum(w(isfinite(err)), 'omitnan');

positiveSlope = max(diff(E.table.V_pred), 0);
score = score + 200 * sum(positiveSlope .^ 2);

low = S.current_density_A_cm2 <= 0.3;
score = score + 0.5 * mean(err(low) .^ 2, 'omitnan');

if any(E.table.V_act_V < -1e-9) || any(E.table.V_ohm_V < -1e-9) || any(E.table.V_conc_V < -1e-9)
    score = score + 100;
end
if max(E.table.V_act_V) > 0.8 || max(E.table.V_ohm_V) > 0.35
    score = score + 10;
end
theta3Ratio = abs(params.theta3 / -1.527e-4);
if theta3Ratio < 0.2 || theta3Ratio > 3.0
    score = score + 0.1 * (max(0, 0.2 - theta3Ratio) ^ 2 + max(0, theta3Ratio - 3.0) ^ 2);
end
score = score + 1e4 * (params.theta8 - currentParams.theta8) ^ 2;
end

function E = evaluateVoltage(S, P, params)
I = max(S.current_A, 1e-6);
VactRaw = params.theta1 + params.theta2 .* S.TK ...
    + params.theta3 .* S.TK .* log(S.C_O2_mol_m3) ...
    + params.theta4 .* S.TK .* log(I);
Vact = max(VactRaw, 0);
Rm = membraneResistance(S, P, params);
Vohm = I .* (Rm + params.theta8);
Vconc = max(params.theta9 .* exp(min(params.theta10 .* I, 50)), 0);
Vpred = S.E_nernst_V - Vact - Vohm - Vconc;

T = table();
T.case_id = S.case_id;
T.current_A = I;
T.current_density_A_cm2 = S.current_density_A_cm2;
T.fit_weight = S.fit_weight;
T.V_meas = S.V_cell_meas;
T.V_pred = Vpred;
T.V_err = Vpred - S.V_cell_meas;
T.E_nernst_V = S.E_nernst_V;
T.V_act_V = Vact;
T.V_ohm_V = Vohm;
T.V_conc_V = Vconc;
T.Rm_ohm = Rm;
T.Rc_ohm = repmat(params.theta8, height(S), 1);
T.R_ohm_total_ohm = Rm + params.theta8;
T.pO2_core_in_kPa = S.pO2_core_in_kPa;
T.pO2_stack_kPa = S.pO2_stack_kPa;
T.pH2_stack_kPa = S.pH2_stack_kPa;
T.CO2_voltage_mol_m3 = S.C_O2_mol_m3;
T.lambda_mem = S.lambda_mem;
T.RH_stack = S.RH_stack;
T.lambda_O2_actual = S.lambda_O2_actual;

E = struct();
E.table = T;
E.metrics = voltageMetrics(T);
end

function Rm = membraneResistance(S, P, params)
Rm = P.membraneThickness_cm ./ max(P.A_cell_cm2 .* (params.theta5 .* S.lambda_mem + params.theta6) ...
    .* exp(params.theta7 .* (1 / 303.15 - 1 ./ S.TK)), 1e-12);
end

function M = voltageMetrics(T)
M = struct();
M.points = height(T);
M.weighted_rmse_cell_V = sqrt(sum(T.fit_weight .* T.V_err .^ 2, 'omitnan') / sum(T.fit_weight(isfinite(T.V_err)), 'omitnan'));
M.rmse_cell_V = rmsLocal(T.V_err);
M.max_abs_error_cell_V = max(abs(T.V_err));
low = T.current_density_A_cm2 <= 0.3;
mid = T.current_density_A_cm2 > 0.3 & T.current_density_A_cm2 <= 0.7;
high = T.current_density_A_cm2 >= 1.1;
M.low_current_points = nnz(low);
M.low_current_rmse_cell_V = rmsLocal(T.V_err(low));
M.low_current_max_abs_error_cell_V = max(abs(T.V_err(low)));
M.mid_current_rmse_cell_V = rmsLocal(T.V_err(mid));
M.high_current_points = nnz(high);
M.high_current_bias_cell_V = mean(T.V_err(high), 'omitnan');
M.high_current_rmse_cell_V = rmsLocal(T.V_err(high));
M.mean_V_act_V = mean(T.V_act_V, 'omitnan');
M.mean_V_ohm_V = mean(T.V_ohm_V, 'omitnan');
M.mean_V_conc_V = mean(T.V_conc_V, 'omitnan');
M.max_positive_dV_step = max([0; diff(T.V_pred)]);
M.terms_physical = all(T.V_act_V >= -1e-9) && all(T.V_ohm_V >= -1e-9) && all(T.V_conc_V >= -1e-9) ...
    && all(T.E_nernst_V > T.V_pred);
end

function T = buildDiagnosticTable(S, bookEval, currentEval, fitEval)
T = S(:, {'case_id','current_A','current_density_A_cm2','fit_weight','V_cell_meas', ...
    'E_nernst_V','C_O2_mol_m3','pO2_core_in_kPa','pO2_stack_kPa','pH2_stack_kPa', ...
    'lambda_mem','RH_stack','lambda_O2_actual'});
T.book_reference_V = bookEval.table.V_pred;
T.book_reference_err_V = bookEval.table.V_err;
T.current_applied_V = currentEval.table.V_pred;
T.current_applied_err_V = currentEval.table.V_err;
T.internal_state_weighted_refit_V = fitEval.table.V_pred;
T.internal_state_weighted_refit_err_V = fitEval.table.V_err;
T.selected_candidate_V = fitEval.table.V_pred;
T.selected_candidate_err_V = fitEval.table.V_err;
T.selected_V_act_V = fitEval.table.V_act_V;
T.selected_V_ohm_V = fitEval.table.V_ohm_V;
T.selected_V_conc_V = fitEval.table.V_conc_V;
T.selected_Rm_ohm = fitEval.table.Rm_ohm;
T.selected_Rc_ohm = fitEval.table.Rc_ohm;
T.selected_R_ohm_total_ohm = fitEval.table.R_ohm_total_ohm;
end

function T = buildCandidateTable(bookM, currentM, fitM, bookParams, currentParams, fitParams)
labels = ["book_reference"; "current_applied"; "internal_state_weighted_refit"];
metrics = [bookM; currentM; fitM];
params = [bookParams; currentParams; fitParams];
T = table();
T.label = labels;
T.weighted_rmse_cell_V = arrayfun(@(m) m.weighted_rmse_cell_V, metrics);
T.rmse_cell_V = arrayfun(@(m) m.rmse_cell_V, metrics);
T.max_abs_error_cell_V = arrayfun(@(m) m.max_abs_error_cell_V, metrics);
T.low_current_rmse_cell_V = arrayfun(@(m) m.low_current_rmse_cell_V, metrics);
T.low_current_max_abs_error_cell_V = arrayfun(@(m) m.low_current_max_abs_error_cell_V, metrics);
T.high_current_bias_cell_V = arrayfun(@(m) m.high_current_bias_cell_V, metrics);
T.high_current_rmse_cell_V = arrayfun(@(m) m.high_current_rmse_cell_V, metrics);
T.mean_V_act_V = arrayfun(@(m) m.mean_V_act_V, metrics);
T.mean_V_ohm_V = arrayfun(@(m) m.mean_V_ohm_V, metrics);
T.mean_V_conc_V = arrayfun(@(m) m.mean_V_conc_V, metrics);
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

function T = buildParamTable(params, metrics, autoApply)
T = table();
T.timestamp = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
T.fit_point_count = metrics.points;
T.weighted_rmse_cell_V = metrics.weighted_rmse_cell_V;
T.rmse_cell_V = metrics.rmse_cell_V;
T.max_abs_error_cell_V = metrics.max_abs_error_cell_V;
T.low_current_rmse_cell_V = metrics.low_current_rmse_cell_V;
T.low_current_max_abs_error_cell_V = metrics.low_current_max_abs_error_cell_V;
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
T.fit_scope = "testbench_internal_state_no_egr_weighted_low_current";
T.selected_label = params.label;
T.auto_applied = autoApply;
end

function writeSummary(path, bookM, currentM, fitM, bookParams, currentParams, fitParams, autoApply)
lines = [
    "# Internal-State Stack Voltage Fit Summary"
    ""
    "Date: " + string(datetime('now', 'Format', 'yyyy-MM-dd'))
    ""
    "## Scope"
    ""
    "- Voltage fitting uses the same internal states consumed by the Simulink PEMFCStackCore voltage equations."
    "- Low-current points are deliberately up-weighted: j <= 0.3 A/cm2 weight 4, 0.3 < j <= 0.7 weight 2, higher current weight 1."
    "- theta5/theta6/theta7 and theta9/theta10 are kept from the current applied parameter set."
    sprintf("- Accepted candidate auto-applied: %s.", string(autoApply))
    ""
    "## Metrics"
    ""
    sprintf("- Book reference weighted RMSE: %.4f V/cell; unweighted RMSE %.4f V/cell.", bookM.weighted_rmse_cell_V, bookM.rmse_cell_V)
    sprintf("- Current applied weighted RMSE: %.4f V/cell; unweighted RMSE %.4f V/cell.", currentM.weighted_rmse_cell_V, currentM.rmse_cell_V)
    sprintf("- Internal-state weighted refit weighted RMSE: %.4f V/cell; unweighted RMSE %.4f V/cell.", fitM.weighted_rmse_cell_V, fitM.rmse_cell_V)
    sprintf("- Internal-state low-current RMSE: %.4f V/cell; low-current max abs %.4f V/cell.", fitM.low_current_rmse_cell_V, fitM.low_current_max_abs_error_cell_V)
    sprintf("- Internal-state high-current bias: %.4f V/cell; high-current RMSE %.4f V/cell.", fitM.high_current_bias_cell_V, fitM.high_current_rmse_cell_V)
    sprintf("- Internal-state max abs error: %.4f V/cell.", fitM.max_abs_error_cell_V)
    sprintf("- Internal-state max positive voltage step: %.4f V/cell.", fitM.max_positive_dV_step)
    sprintf("- Internal-state terms physical: %s.", string(fitM.terms_physical))
    ""
    "## Parameter Movement"
    ""
    sprintf("- theta1: %.8g -> %.8g -> %.8g.", bookParams.theta1, currentParams.theta1, fitParams.theta1)
    sprintf("- theta2: %.8g -> %.8g -> %.8g.", bookParams.theta2, currentParams.theta2, fitParams.theta2)
    sprintf("- theta3: %.8g -> %.8g -> %.8g.", bookParams.theta3, currentParams.theta3, fitParams.theta3)
    sprintf("- theta4: %.8g -> %.8g -> %.8g.", bookParams.theta4, currentParams.theta4, fitParams.theta4)
    sprintf("- theta5: %.8g -> %.8g -> %.8g.", bookParams.theta5, currentParams.theta5, fitParams.theta5)
    sprintf("- theta6: %.8g -> %.8g -> %.8g.", bookParams.theta6, currentParams.theta6, fitParams.theta6)
    sprintf("- theta7: %.8g -> %.8g -> %.8g.", bookParams.theta7, currentParams.theta7, fitParams.theta7)
    sprintf("- theta8: %.8g -> %.8g -> %.8g.", bookParams.theta8, currentParams.theta8, fitParams.theta8)
    sprintf("- theta9: %.8g -> %.8g -> %.8g.", bookParams.theta9, currentParams.theta9, fitParams.theta9)
    sprintf("- theta10: %.8g -> %.8g -> %.8g.", bookParams.theta10, currentParams.theta10, fitParams.theta10)
    ""
    "## Output Files"
    ""
    "- `04_验证结果/stack_voltage_internal_state_fit_diagnostic.csv`"
    "- `04_验证结果/stack_voltage_internal_state_fit_candidates.csv`"
    "- `04_验证结果/stack_voltage_internal_state_fit_summary.md`"
    "- `00_输入参数/电堆物理模型/stack_voltage_book_theta_params_internal_state_candidate.csv`"
    "- `00_输入参数/电堆物理模型/stack_voltage_book_theta_params.csv`"
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
