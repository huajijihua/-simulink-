function [variableAudit, interfaceAudit, mMemTrace] = run_core_fix_v01_detailed_audit(stopTime_s, window_s)
%RUN_CORE_FIX_V01_DETAILED_AUDIT Time-series audit for module values and links.

if nargin < 1 || isempty(stopTime_s)
    stopTime_s = 120;
end
if nargin < 2 || isempty(window_s)
    window_s = min(20, max(1, stopTime_s/5));
end

rootDir = fileparts(fileparts(mfilename('fullpath')));
modelDir = fullfile(rootDir, '01_模型');
resultDir = fullfile(rootDir, '04_验证结果');
if ~isfolder(resultDir)
    mkdir(resultDir);
end
addpath(modelDir);

P0 = init_testbench_10kw_simplified_egr(1, 'all', false);
cases = P0.allCaseTable;
model = P0.modelName;
load_system(model);

variableAudit = emptyVariableAudit();
interfaceAudit = emptyInterfaceAudit();
mMemTrace = emptyMmemTrace();

for caseIndex = 1:height(cases)
    P = init_testbench_10kw_simplified_egr(caseIndex, 'all', false);
    try
        out = simulateCase(P, stopTime_s, model);
        logs = collectLogs(out);
        variableAudit = [variableAudit; auditCaseVariables(P, logs, window_s)]; %#ok<AGROW>
        interfaceAudit = [interfaceAudit; auditCaseInterfaces(P, logs, window_s)]; %#ok<AGROW>
        mMemTrace = [mMemTrace; buildMmemTrace(P, logs)]; %#ok<AGROW>
    catch ME
        variableAudit = [variableAudit; errorVariableRow(P, ME)]; %#ok<AGROW>
        interfaceAudit = [interfaceAudit; errorInterfaceRow(P, ME)]; %#ok<AGROW>
    end
end

variableFile = fullfile(resultDir, 'core_fix_v01_detailed_variable_audit.csv');
interfaceFile = fullfile(resultDir, 'core_fix_v01_interface_consistency.csv');
mMemFile = fullfile(resultDir, 'core_fix_v01_mmem_timeseries.csv');
summaryFile = fullfile(resultDir, 'core_fix_v01_detailed_summary.md');
writetable(variableAudit, variableFile);
writetable(interfaceAudit, interfaceFile);
writetable(mMemTrace, mMemFile);
writeDetailedSummary(summaryFile, variableAudit, interfaceAudit, mMemTrace, stopTime_s, window_s);
fprintf('Wrote %s\n', variableFile);
fprintf('Wrote %s\n', interfaceFile);
fprintf('Wrote %s\n', mMemFile);
fprintf('Wrote %s\n', summaryFile);
end

function out = simulateCase(P, stopTime_s, model)
in = Simulink.SimulationInput(model);
in = in.setModelParameter('StopTime', num2str(stopTime_s), ...
    'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', num2str(P.dt_s));
in = in.setVariable('BenchBoundaryParam_simplified', P.BenchBoundaryParam);
in = in.setVariable('EgrSplitParam_simplified', P.EgrSplitParam);
in = in.setVariable('StackParam_simplified', P.StackParam);
in = in.setVariable('I_stack_cmd_A_simplified', P.I_stack_default_A);
in = in.setVariable('StackInitialState_simplified', P.stack_initial_state);
in = in.setVariable('EGRInitialNode_simplified', P.egr_initial_node);
out = sim(in);
end

function logs = collectLogs(out)
names = ["fresh_node", "mixer_node", "stack_in_node", "stack_ca_out_node", ...
    "egr_return_node", "bench_out_node", "state_vector", "summary_vector"];
for k = 1:numel(names)
    [t, x] = loggedMatrix(out, names(k));
    logs.(names(k)).time = t;
    logs.(names(k)).data = x;
end
end

function [t, x] = loggedMatrix(out, name)
s = out.(char(name));
t = s.time(:);
v = squeeze(s.signals.values);
if isvector(v)
    v = v(:);
end
if size(v, 2) == numel(t)
    x = v.';
elseif size(v, 1) == numel(t)
    x = v;
else
    error('DetailedAudit:LogShape', 'Unexpected log shape for %s.', name);
end
end

function audit = auditCaseVariables(P, logs, window_s)
audit = emptyVariableAudit();
nodeNames = ["fresh", "mixer", "stack_in", "stack_ca_out", "egr_return", "bench_out"];
nodeLogs = ["fresh_node", "mixer_node", "stack_in_node", "stack_ca_out_node", "egr_return_node", "bench_out_node"];
nodeVars = ["mO2_kg_s", "mN2_kg_s", "mH2Ov_kg_s", "mLiquid_kg_s", ...
    "T_C", "p_kPa_abs", "liquid_flag"];
nodeUnits = ["kg/s", "kg/s", "kg/s", "kg/s", "degC", "kPa", "1"];
for n = 1:numel(nodeNames)
    x = logs.(nodeLogs(n)).data;
    t = logs.(nodeLogs(n)).time;
    for j = 1:min(numel(nodeVars), size(x, 2))
        audit = [audit; statsRow(P, nodeNames(n), nodeVars(j), nodeUnits(j), t, x(:, j), window_s)]; %#ok<AGROW>
    end
end

stateVars = ["mO2_state_kg", "mN2_state_kg", "mH2Ov_ca_state_kg", ...
    "mH2_state_kg", "mH2Ov_an_state_kg", "T_state_C"];
stateUnits = ["kg", "kg", "kg", "kg", "kg", "degC"];
xState = logs.state_vector.data;
tState = logs.state_vector.time;
for j = 1:min(numel(stateVars), size(xState, 2))
    audit = [audit; statsRow(P, "stack_state", stateVars(j), stateUnits(j), tState, xState(:, j), window_s)]; %#ok<AGROW>
end

summaryNames = stackSummaryNames();
summaryUnits = stackSummaryUnits();
xSummary = logs.summary_vector.data;
tSummary = logs.summary_vector.time;
for j = 1:min(numel(summaryNames), size(xSummary, 2))
    audit = [audit; statsRow(P, "stack_summary", summaryNames(j), summaryUnits(j), tSummary, xSummary(:, j), window_s)]; %#ok<AGROW>
end
end

function audit = auditCaseInterfaces(P, logs, window_s)
audit = emptyInterfaceAudit();
t = logs.stack_in_node.time;
mixer = logs.mixer_node.data;
stackIn = logs.stack_in_node.data;
stackOut = logs.stack_ca_out_node.data;
egrReturn = logs.egr_return_node.data;
benchOut = logs.bench_out_node.data;
summary = logs.summary_vector.data;

audit = [audit; interfaceRow(P, "mixer_to_stack_in_mO2", "kg/s", t, stackIn(:, 1) - mixer(:, 1), 1e-10, window_s)]; %#ok<AGROW>
audit = [audit; interfaceRow(P, "mixer_to_stack_in_mN2", "kg/s", t, stackIn(:, 2) - mixer(:, 2), 1e-10, window_s)]; %#ok<AGROW>
audit = [audit; interfaceRow(P, "mixer_to_stack_in_mH2Ov_delta", "kg/s", t, stackIn(:, 3) - mixer(:, 3), 1e-10, window_s)]; %#ok<AGROW>
audit = [audit; interfaceRow(P, "inlet_condensed_liquid_balance", "kg/s", t, ...
    (stackIn(:, 4) - mixer(:, 4)) + (stackIn(:, 3) - mixer(:, 3)), 1e-10, window_s)]; %#ok<AGROW>
audit = [audit; interfaceRow(P, "stack_out_split_mO2", "kg/s", t, ...
    stackOut(:, 1) - benchOut(:, 1) - egrReturn(:, 1), 1e-10, window_s)]; %#ok<AGROW>
audit = [audit; interfaceRow(P, "stack_out_split_mN2", "kg/s", t, ...
    stackOut(:, 2) - benchOut(:, 2) - egrReturn(:, 2), 1e-10, window_s)]; %#ok<AGROW>

stackSummaryLen = 65;
splitSummaryStart = stackSummaryLen + 5;
audit = [audit; interfaceRow(P, "splitter_ratio_param_error", "1", t, ...
    summary(:, splitSummaryStart) - P.egr_fraction_cmd, 1e-9, window_s)]; %#ok<AGROW>

[pO2In, xO2In, rhIn] = inletGasDiagnostics(stackIn);
audit = [audit; interfaceRow(P, "summary_pO2In_vs_stack_in", "kPa", t, summary(:, 19) - pO2In, 1e-6, window_s)]; %#ok<AGROW>
audit = [audit; interfaceRow(P, "summary_xO2In_vs_stack_in", "1", t, summary(:, 20) - xO2In, 1e-9, window_s)]; %#ok<AGROW>
audit = [audit; interfaceRow(P, "summary_RHIn_vs_stack_in", "1", t, summary(:, 21) - rhIn, 1e-7, window_s)]; %#ok<AGROW>
actualInExcess = max(summary(:, 41) - sum(stackIn(:, 1:3), 2), 0);
audit = [audit; interfaceRow(P, "actual_mIn_excess_over_target", "kg/s", t, ...
    actualInExcess, 1e-10, window_s)]; %#ok<AGROW>
end

function trace = buildMmemTrace(P, logs)
t = logs.summary_vector.time;
s = logs.summary_vector.data;
n = numel(t);
trace = table(repmat(string(P.case_id), n, 1), repmat(string(P.source_dataset), n, 1), ...
    repmat(P.I_stack_default_A, n, 1), repmat(P.egr_fraction_cmd, n, 1), t, ...
    s(:, 12), s(:, 59), s(:, 60), s(:, 61), s(:, 62), s(:, 63), ...
    s(:, 64), s(:, 65), s(:, 49), s(:, 50), s(:, 8), s(:, 11), s(:, 9), s(:, 2), ...
    'VariableNames', {'case_id', 'source_dataset', 'current_A', 'egr_fraction', 'time_s', ...
    'mMem_kg_s', 'J_drag_mol_m2_s', 'J_diff_mol_m2_s', 'J_net_mol_m2_s', ...
    'mDrag_kg_s', 'mDiff_kg_s', 'mMem_raw_kg_s', 'mMem_limit_delta_kg_s', ...
    'lambda_ca', 'lambda_an', 'lambda_m', ...
    'RH_stack', 'T_stack_C', 'V_sim'});
end

function row = statsRow(P, module, variable, unit, t, y, window_s)
t = t(:);
y = y(:);
idx = t >= max(t(end) - window_s, t(1));
yw = y(idx);
tw = t(idx);
lastRange = max(yw) - min(yw);
lastMean = mean(yw, 'omitnan');
lastStd = std(yw, 'omitnan');
lastSlope = abs(yw(end) - yw(1)) / max(tw(end) - tw(1), eps);
tol = max(1e-9, 1e-3 * max(abs(lastMean), abs(y(end))));
signChangesTotal = signChangeCount(y);
signChangesWindow = signChangeCount(yw);
converged = isfinite(lastRange) && lastRange <= tol;
row = table(string(P.case_id), string(P.source_dataset), string(module), ...
    string(variable), string(unit), P.I_stack_default_A, P.egr_fraction_cmd, ...
    y(1), y(end), y(end) - y(1), lastMean, min(yw), max(yw), lastStd, ...
    lastRange, lastSlope, signChangesTotal, signChangesWindow, converged, ...
    "", ...
    'VariableNames', {'case_id', 'source_dataset', 'module', 'variable', 'unit', ...
    'current_A', 'egr_fraction', 'initial_value', 'final_value', 'delta_value', ...
    'last_window_mean', 'last_window_min', 'last_window_max', 'last_window_std', ...
    'last_window_range', 'last_window_abs_slope_per_s', 'sign_changes_total', ...
    'sign_changes_last_window', 'converged_by_range', 'message'});
end

function row = interfaceRow(P, checkName, unit, t, err, tol, window_s)
t = t(:);
err = err(:);
idx = t >= max(t(end) - window_s, t(1));
ew = err(idx);
pass = max(abs(ew), [], 'omitnan') <= tol;
row = table(string(P.case_id), string(P.source_dataset), string(checkName), ...
    string(unit), P.I_stack_default_A, P.egr_fraction_cmd, err(1), err(end), ...
    max(abs(err), [], 'omitnan'), mean(abs(err), 'omitnan'), ...
    max(abs(ew), [], 'omitnan'), tol, pass, "", ...
    'VariableNames', {'case_id', 'source_dataset', 'check_name', 'unit', ...
    'current_A', 'egr_fraction', 'initial_error', 'final_error', ...
    'max_abs_error', 'mean_abs_error', 'last_window_max_abs_error', ...
    'tolerance', 'pass', 'message'});
end

function n = signChangeCount(y)
y = y(:);
y = y(isfinite(y));
y(abs(y) < 1e-15) = 0;
s = sign(y);
s = s(s ~= 0);
if numel(s) < 2
    n = 0;
else
    n = sum(s(2:end) ~= s(1:end-1));
end
end

function [pO2, xO2, rh] = inletGasDiagnostics(node)
M_O2 = 0.031998;
M_N2 = 0.0280134;
M_H2O = 0.01801528;
nO2 = max(node(:, 1), 0) / M_O2;
nN2 = max(node(:, 2), 0) / M_N2;
nV = max(node(:, 3), 0) / M_H2O;
nt = max(nO2 + nN2 + nV, 1e-12);
xO2 = nO2 ./ nt;
pO2 = node(:, 6) .* xO2;
rh = node(:, 6) .* nV ./ nt ./ max(satKpa(node(:, 5)), 1e-6);
end

function p = satKpa(T)
Tc = min(max(T, -40), 120);
p = 0.61121 .* exp((18.678 - Tc ./ 234.5) .* (Tc ./ (257.14 + Tc)));
end

function names = stackSummaryNames()
names = ["I_A", "V_cell", "Pstack_kPa_abs", "pO2_stack_kPa", ...
    "pCa_stack_kPa_abs", "pH2_stack_kPa", "pAn_stack_kPa_abs", ...
    "lambda_m", "T_stack_C", "xO2_stack", "RH_stack", "mMem_kg_s", ...
    "mO2React_kg_s", "mH2React_kg_s", "mWaterGen_kg_s", "mCaOut_kg_s", ...
    "mAnOut_kg_s", "energy_residual_W", "pO2In_kPa", "xO2In", "RHIn", ...
    "Qnet_W", "resO2_kg_s", "resN2_kg_s", "resH2Oca_kg_s", ...
    "phaseCa_kg_s", "resH2_kg_s", "resH2Oan_kg_s", "phaseAn_kg_s", ...
    "phaseTotal_kg_s", "maxGasRes_kg_s", "Qgen_W", "Qcool_W", "Qamb_W", ...
    "Qgas_W", "E_Nernst_V", "etaAct_V", "etaOhm_V", "etaCon_V", ...
    "lambdaO2", "mIn_kg_s", "iLim_A_cm2", "i0Scale", "mVIn_kg_s", ...
    "mVOutCa_kg_s", "mVAnIn_kg_s", "mVOutAn_kg_s", "condensedTotal_kg", ...
    "lambda_ca", "lambda_an", "N_drag_mol_s", "N_diff_mol_s", ...
    "psatCa_next_kPa", "psatAn_next_kPa", "mV_ca_preclip_kg", ...
    "mV_an_preclip_kg", "condensedCa_kg", "condensedAn_kg", ...
    "J_drag_mol_m2_s", "J_diff_mol_m2_s", "J_net_mol_m2_s", ...
    "mDrag_kg_s", "mDiff_kg_s", "mMem_raw_kg_s", "mMem_limit_delta_kg_s"];
end

function units = stackSummaryUnits()
units = ["A", "V", "kPa", "kPa", "kPa", "kPa", "kPa", ...
    "1", "degC", "1", "1", "kg/s", "kg/s", "kg/s", "kg/s", ...
    "kg/s", "kg/s", "W", "kPa", "1", "1", "W", "kg/s", "kg/s", ...
    "kg/s", "kg/s", "kg/s", "kg/s", "kg/s", "kg/s", "kg/s", ...
    "W", "W", "W", "W", "V", "V", "V", "V", "1", "kg/s", ...
    "A/cm2", "1", "kg/s", "kg/s", "kg/s", "kg/s", "kg", ...
    "1", "1", "mol/s", "mol/s", "kPa", "kPa", "kg", "kg", ...
    "kg", "kg", "mol/(m2*s)", "mol/(m2*s)", "mol/(m2*s)", ...
    "kg/s", "kg/s", "kg/s", "kg/s"];
end

function t = emptyVariableAudit()
t = table('Size', [0, 20], ...
    'VariableTypes', {'string','string','string','string','string','double','double', ...
    'double','double','double','double','double','double','double','double','double', ...
    'double','double','logical','string'}, ...
    'VariableNames', {'case_id','source_dataset','module','variable','unit', ...
    'current_A','egr_fraction','initial_value','final_value','delta_value', ...
    'last_window_mean','last_window_min','last_window_max','last_window_std', ...
    'last_window_range','last_window_abs_slope_per_s','sign_changes_total', ...
    'sign_changes_last_window','converged_by_range','message'});
end

function t = emptyInterfaceAudit()
t = table('Size', [0, 14], ...
    'VariableTypes', {'string','string','string','string','double','double', ...
    'double','double','double','double','double','double','logical','string'}, ...
    'VariableNames', {'case_id','source_dataset','check_name','unit', ...
    'current_A','egr_fraction','initial_error','final_error','max_abs_error', ...
    'mean_abs_error','last_window_max_abs_error','tolerance','pass','message'});
end

function t = emptyMmemTrace()
t = table('Size', [0, 19], ...
    'VariableTypes', {'string','string','double','double','double','double','double', ...
    'double','double','double','double','double','double','double','double','double','double','double','double'}, ...
    'VariableNames', {'case_id','source_dataset','current_A','egr_fraction','time_s', ...
    'mMem_kg_s','J_drag_mol_m2_s','J_diff_mol_m2_s','J_net_mol_m2_s', ...
    'mDrag_kg_s','mDiff_kg_s','mMem_raw_kg_s','mMem_limit_delta_kg_s', ...
    'lambda_ca','lambda_an','lambda_m', ...
    'RH_stack','T_stack_C','V_sim'});
end

function row = errorVariableRow(P, ME)
row = emptyVariableAudit();
row(1, :) = {string(P.case_id), string(P.source_dataset), "simulation", "error", ...
    "", P.I_stack_default_A, P.egr_fraction_cmd, NaN, NaN, NaN, NaN, NaN, ...
    NaN, NaN, NaN, NaN, NaN, NaN, false, string(ME.identifier + ": " + ME.message)};
end

function row = errorInterfaceRow(P, ME)
row = emptyInterfaceAudit();
row(1, :) = {string(P.case_id), string(P.source_dataset), "simulation_error", "", ...
    P.I_stack_default_A, P.egr_fraction_cmd, NaN, NaN, NaN, NaN, NaN, NaN, ...
    false, string(ME.identifier + ": " + ME.message)};
end

function writeDetailedSummary(path, variableAudit, interfaceAudit, mMemTrace, stopTime_s, window_s)
fid = fopen(path, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Core Fix v01 Detailed Audit Summary\n\n');
fprintf(fid, '- Stop time: %.3g s\n', stopTime_s);
fprintf(fid, '- Last-window length: %.3g s\n', window_s);
fprintf(fid, '- Variable audit rows: %d\n', height(variableAudit));
fprintf(fid, '- Interface audit rows: %d\n', height(interfaceAudit));
fprintf(fid, '- mMem trace rows: %d\n\n', height(mMemTrace));

mMemRows = variableAudit(variableAudit.module == "stack_summary" & variableAudit.variable == "mMem_kg_s", :);
unstable = mMemRows(mMemRows.sign_changes_last_window > 0 | ...
    mMemRows.last_window_range > max(1e-7, 0.2 * abs(mMemRows.last_window_mean)), :);
fprintf(fid, '## Membrane Water Transfer\n\n');
fprintf(fid, '- Cases with mMem sign changes in last window: %d\n', sum(mMemRows.sign_changes_last_window > 0));
fprintf(fid, '- Cases flagged by sign/range criterion: %d\n', height(unstable));
if ~isempty(mMemRows)
    [~, idx] = max(mMemRows.last_window_range);
    fprintf(fid, '- Largest mMem last-window range: `%s`, %.6g kg/s\n', ...
        mMemRows.case_id(idx), mMemRows.last_window_range(idx));
end
fprintf(fid, '\n');

failedLinks = interfaceAudit(~interfaceAudit.pass, :);
fprintf(fid, '## Interface Consistency\n\n');
fprintf(fid, '- Failed interface checks: %d / %d\n', height(failedLinks), height(interfaceAudit));
if ~isempty(failedLinks)
    top = sortrows(failedLinks, 'last_window_max_abs_error', 'descend');
    n = min(10, height(top));
    for k = 1:n
        fprintf(fid, '- `%s` `%s`: last-window max abs error %.6g %s, tolerance %.6g\n', ...
            top.case_id(k), top.check_name(k), top.last_window_max_abs_error(k), ...
            top.unit(k), top.tolerance(k));
    end
end
end
