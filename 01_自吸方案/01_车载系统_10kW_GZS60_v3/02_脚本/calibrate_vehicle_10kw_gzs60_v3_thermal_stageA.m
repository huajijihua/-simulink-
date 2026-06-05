function results = calibrate_vehicle_10kw_gzs60_v3_thermal_stageA()
%CALIBRATE_VEHICLE_10KW_GZS60_V3_THERMAL_STAGEA
% Stage A of the second-round thermal/humidity route.
%
% This entry updates the current pressurefix baseline with a coolant-flow-
% driven effective cooling relationship. It fits the thermal side first and
% keeps humidity-side parameters frozen.

P0 = init_vehicle_10kw_gzs60_v3("base");
P0 = applyThermalPrior(P0);
P0 = rebuildModuleParamsLocal(P0);

rootDir = P0.rootDir;
dataFile = fullfile(rootDir, '00_输入参数', '全电流段极化标定', 'full_range_polarization_data.csv');
outDir = fullfile(rootDir, '04_验证结果');
paramDir = fullfile(rootDir, '00_输入参数', '标定参数');
diagFile = fullfile(outDir, 'thermal_stageA_diagnostic.csv');
gridFile = fullfile(outDir, 'thermal_stageA_candidate_grid.csv');
summaryFile = fullfile(outDir, 'thermal_stageA_summary.md');
paramFile = fullfile(paramDir, 'thermal_stageA_params.csv');
curveFile = fullfile(paramDir, 'thermal_stageA_cooling_flow_curve.csv');
model = 'CEGR_Vehicle_10kW_GZS60_v03_stage1_pressurefix';
modelFile = fullfile(rootDir, '01_模型', [model '.slx']);

if ~isfile(dataFile)
    error('Missing thermal calibration data: %s', dataFile);
end
if ~isfile(modelFile)
    error('Missing model file: %s', modelFile);
end
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
if ~exist(paramDir, 'dir')
    mkdir(paramDir);
end

T = readtable(dataFile, 'TextType', 'string');
fitMask = logical(T.use_for_fit) & isfinite(T.stack_temperature_est_C) & isfinite(T.coolant_flow_L_min);
D = T(fitMask, :);
if isempty(D)
    error('No usable thermal steady points in %s.', dataFile);
end
D = addBenchCoolingColumns(D, P0);

open_system(modelFile);

baseCurve = benchCoolingCurve(D);
baseParams = thermalParamsFromCurve(P0, baseCurve);
opts = thermalOptions();

fprintf('Thermal stage A calibration, %d no-EGR points.\n', height(D));
fprintf('Cooling-flow curve support points: %d.\n', height(baseCurve));

grid = candidateGrid();
gridRows = cell(size(grid, 1), 1);
bestScore = inf;
bestDiag = table();
bestMetrics = struct();
bestP = P0;
bestCurve = baseCurve;

for k = 1:size(grid, 1)
    P = baseParams;
    P.h_amb_W_K = grid(k, 1);
    P.h_cool_W_K = baseCurve.h_cool_curve_W_K(1) * grid(k, 2);
    P.cool_flow_curve_enabled = 1.0;
    P.cool_flow_curve_L_min = padCalibrationCurve(baseCurve.coolant_flow_L_min);
    P.cool_flow_curve_h_W_K = padCalibrationCurve(baseCurve.h_cool_curve_W_K * grid(k, 2));
    P = rebuildModuleParamsLocal(P);

    R = runThermalDataset(P, D, model, opts.finalRun);
    M = metricSummary(R);
    score = thermalScore(M, opts);

    row = struct();
    row.h_amb_W_K = P.h_amb_W_K;
    row.h_scale = grid(k, 2);
    row.h_cool_fallback_W_K = P.h_cool_W_K;
    row.T_stack_RMSE_C = M.T_stack_RMSE_C;
    row.Q_cool_RMSE_W = M.Q_cool_RMSE_W;
    row.Q_cool_bias_W = M.Q_cool_bias_W;
    row.steady_points = M.steady_points;
    row.pressure_order_pass = M.pressure_order_pass;
    row.score = score;
    gridRows{k} = struct2table(row);

    if score < bestScore
        bestScore = score;
        bestDiag = R;
        bestMetrics = M;
        bestP = P;
        bestCurve = baseCurve;
        bestCurve.h_cool_curve_W_K = baseCurve.h_cool_curve_W_K * grid(k, 2);
    end
end

gridTable = vertcat(gridRows{:});
paramTable = buildParamTable(P0, bestP);

writetable(bestDiag, diagFile);
writetable(gridTable, gridFile);
writetable(paramTable, paramFile);
writetable(bestCurve, curveFile);
writeSummary(summaryFile, bestMetrics, bestCurve, bestP, opts);

assignModelWorkspace(model, bestP, 0.0);
save_system(model);

fprintf('\nWrote thermal stage-A diagnostic to %s\n', diagFile);
fprintf('Wrote thermal stage-A grid summary to %s\n', gridFile);
fprintf('Wrote thermal stage-A parameter table to %s\n', paramFile);
fprintf('Wrote thermal stage-A cooling curve to %s\n', curveFile);
printMetrics(bestMetrics);

results = struct();
results.parameters = paramTable;
results.cooling_curve = bestCurve;
results.diagnostic = bestDiag;
results.grid = gridTable;
results.metrics = bestMetrics;
results.score = bestScore;
end

function opts = thermalOptions()
opts.stopTimeShort_s = 120;
opts.stopTimeLong_s = 300;
opts.steadyWindow_s = 30;
opts.finalRun.adaptiveSteady = true;
opts.finalRun.verbose = false;
opts.score_w_Q = 0.0020;
opts.score_w_bias = 0.0006;
opts.score_w_steady = 0.75;
end

function P = applyThermalPrior(P)
P.h_cool_W_K = 121;
P.h_amb_W_K = 9;
P.hum_mem_area_m2 = 40;
P.hum_mem_D_eff_m2_s = 1.0e-9;
P.hum_beta_wet_m_s = 0.06;
P.hum_beta_dry_m_s = 0.06;
P.hum_heat_eff = 0.5825;
P.book_xi1 = -1.18256193784984;
P.book_xi2 = 0.00294108739022835;
P.book_xi3 = 5.21269240295832e-05;
P.book_xi4 = -8.54349163446432e-05;
P.book_contact_resistance_ohm = 2.2204486714779e-14;
P.book_concentration_m_V = 3.97280101897563e-05;
P.book_concentration_n_1_A = 0.00982352283961081;
end

function D = addBenchCoolingColumns(D, P)
flow = double(D.coolant_flow_L_min);
Tin = double(D.coolant_inlet_temp_C);
Tout = double(D.coolant_outlet_temp_C);
Tstack = double(D.stack_temperature_est_C);
qCool = P.coolant_rho_kg_L * P.coolant_cp_J_kgK * (flow / 60.0) .* (Tout - Tin);
drive = Tstack - Tin;
hEst = nan(size(qCool));
valid = qCool > 0 & drive > 0.25;
hEst(valid) = qCool(valid) ./ drive(valid);
D.Q_cool_bench_W = qCool;
D.T_cool_drive_inlet_C = drive;
D.h_cool_bench_est_W_K = hEst;
D.q_cool_bench_valid = valid;
end

function curve = benchCoolingCurve(D)
valid = logical(D.q_cool_bench_valid);
flows = double(D.coolant_flow_L_min(valid));
hVals = double(D.h_cool_bench_est_W_K(valid));
[uFlow, ~, groupIdx] = unique(flows);
hCurve = zeros(size(uFlow));
for k = 1:numel(uFlow)
    hCurve(k) = median(hVals(groupIdx == k), 'omitnan');
end
if any(~valid)
    minFlow = min(double(D.coolant_flow_L_min));
    if minFlow < uFlow(1)
        uFlow = [minFlow; uFlow];
        hCurve = [hCurve(1); hCurve];
    end
end
for k = 2:numel(hCurve)
    hCurve(k) = max(hCurve(k), hCurve(k - 1));
end
curve = table(uFlow, hCurve, 'VariableNames', {'coolant_flow_L_min', 'h_cool_curve_W_K'});
end

function P = thermalParamsFromCurve(P, curve)
P.cool_flow_curve_enabled = 1.0;
P.cool_flow_curve_L_min = padCalibrationCurve(curve.coolant_flow_L_min);
P.cool_flow_curve_h_W_K = padCalibrationCurve(curve.h_cool_curve_W_K);
P.h_cool_W_K = curve.h_cool_curve_W_K(1);
end

function grid = candidateGrid()
hAmb = [0, 3, 6, 9, 12];
hScale = [0.90, 1.00, 1.10, 1.20];
[A, S] = ndgrid(hAmb, hScale);
grid = [A(:), S(:)];
end

function R = runThermalDataset(Pbase, D, model, runOpts)
rows = cell(height(D), 1);
for k = 1:height(D)
    P = configureThermalCase(Pbase, D(k, :));
    rows{k} = runCase(P, D(k, :), model, runOpts);
end
R = vertcat(rows{:});
end

function P = configureThermalCase(P, row)
P.I_stack_default_A = row.current_A;
P.oxygen_stoich = flowDerivedLambda(row, P);
P.anode_stoich = row.anode_stoich;
P.RH_an_in = row.anode_RH;
P.p_anode_in_kPa = row.anode_pressure_kPa_abs;
P.p_anode_back_kPa = row.anode_outlet_pressure_kPa_g + P.p_amb_kPa;
P.p_cathode_back_kPa = row.cathode_outlet_pressure_kPa_g + P.p_amb_kPa;
P.T_cool_C = row.coolant_inlet_temp_C;
P.coolant_flow_L_min = row.coolant_flow_L_min;
P.intercooler_T_C = row.cathode_inlet_temp_C;
P.EnvParam(6) = max(row.cathode_inlet_temp_C - P.compressor_dT_C, -20);
P.EnvParam(11) = P.oxygen_stoich;
P.IntercoolerParam(5) = P.intercooler_T_C;

dryDp = estimateHumidifierDryDp(P, row.current_A);
P.compressor_dp_kPa = max(row.cathode_pressure_kPa_abs - P.p_amb_kPa + P.intercooler_dp_kPa + dryDp, 1.0);
P.CompressorParam(1) = P.compressor_dp_kPa;

P = rebuildModuleParamsLocal(P);
P.stack_initial_state_audit = buildStackInitialAudit(P, row.cathode_pressure_kPa_abs, P.p_anode_back_kPa, row.stack_temperature_est_C);
P.wet_initial_node = [0 0 0 0 row.cathode_outlet_temp_C P.p_cathode_back_kPa 0]';
end

function lambda = flowDerivedLambda(row, P)
flow_m3_s = row.cathode_flow_nlpm / 60000;
nTotal = flow_m3_s / 0.022414;
nO2 = P.xO2_dry * nTotal;
nO2Need = row.current_A * P.N_cell / (4 * P.F_C_mol);
lambda = nO2 / max(nO2Need, 1e-12);
end

function dryDp = estimateHumidifierDryDp(P, I)
scale = max(I / max(P.I_stack_default_A, 1.0), 0.2);
dryDp = P.hum_dry_dp_ref_kPa * scale ^ P.hum_dp_exp;
end

function rowOut = runCase(P, dataRow, model, runOpts)
out = runOneSim(P, model, 120);
parsed = parseCaseOutput(out, P, dataRow, model, 120);
if runOpts.adaptiveSteady && ~parsed.is_steady
    out = runOneSim(P, model, 300);
    parsed = parseCaseOutput(out, P, dataRow, model, 300);
end
rowOut = struct2table(parsed);
end

function out = runOneSim(P, model, stopTime)
in = Simulink.SimulationInput(model);
in = setModelVars(in, model, P, stopTime);
simOut = sim(in);
out = struct();
out.summary_vector = simOut.summary_vector;
out.humidifier_dry_node = simOut.humidifier_dry_node;
out.humidifier_wet_node = simOut.humidifier_wet_node;
out.fresh_node = simOut.fresh_node;
out.egr_return_node = simOut.egr_return_node;
out.vent_node = simOut.vent_node;
end

function in = setModelVars(in, model, P, stopTime)
assignin('base', 'EnvParam_v2', P.EnvParam);
assignin('base', 'CompressorParam_v2', P.CompressorParam);
assignin('base', 'IntercoolerParam_v2', P.IntercoolerParam);
assignin('base', 'HumidifierParam_v2', P.HumidifierParam);
assignin('base', 'StackParam_v2', P.StackParam);
assignin('base', 'I_stack_cmd_A', P.I_stack_default_A);
assignin('base', 'egr_fraction_cmd', 0.0);
assignin('base', 'stack_initial_state_audit', P.stack_initial_state_audit);
assignin('base', 'egr_initial_node', P.egr_initial_node);
assignin('base', 'wet_initial_node', P.wet_initial_node);
in = in.setModelParameter('StopTime', num2str(stopTime));
in = in.setVariable('EnvParam_v2', P.EnvParam, 'Workspace', model);
in = in.setVariable('CompressorParam_v2', P.CompressorParam, 'Workspace', model);
in = in.setVariable('IntercoolerParam_v2', P.IntercoolerParam, 'Workspace', model);
in = in.setVariable('HumidifierParam_v2', P.HumidifierParam, 'Workspace', model);
in = in.setVariable('StackParam_v2', P.StackParam, 'Workspace', model);
in = in.setVariable('I_stack_cmd_A', P.I_stack_default_A, 'Workspace', model);
in = in.setVariable('egr_fraction_cmd', 0.0, 'Workspace', model);
in = in.setVariable('stack_initial_state_audit', P.stack_initial_state_audit, 'Workspace', model);
in = in.setVariable('egr_initial_node', P.egr_initial_node, 'Workspace', model);
in = in.setVariable('wet_initial_node', P.wet_initial_node, 'Workspace', model);
end

function parsed = parseCaseOutput(out, P, dataRow, model, stopTime)
fields = summaryFields();
sNow = summaryStruct(vectorAt(out.summary_vector, numel(fields), "final"), fields);
dry = nodeStruct(vectorAt(out.humidifier_dry_node, 7, "final"), P);
steady = steadyCheck(out, P, stopTime);

parsed = struct();
parsed.case_id = string(dataRow.case_id);
parsed.stop_time_s = stopTime;
parsed.is_steady = steady.is_steady;
parsed.dV_cell_30s = steady.dV_cell;
parsed.dp_ca_in_30s_kPa = steady.dp_ca_in;
parsed.dT_stack_30s_C = steady.dT_stack;
parsed.dRH_ca_in_30s = steady.dRH_ca_in;
parsed.current_A = dataRow.current_A;
parsed.current_density_A_cm2 = dataRow.current_density_A_cm2;
parsed.coolant_flow_L_min = dataRow.coolant_flow_L_min;
parsed.coolant_inlet_temp_C = dataRow.coolant_inlet_temp_C;
parsed.coolant_outlet_temp_C = dataRow.coolant_outlet_temp_C;
parsed.Q_cool_bench_W = dataRow.Q_cool_bench_W;
parsed.h_cool_bench_est_W_K = dataRow.h_cool_bench_est_W_K;
parsed.T_stack_meas_C = dataRow.stack_temperature_est_C;
parsed.T_stack_sim_C = sNow.T_stack_C;
parsed.T_stack_err_C = parsed.T_stack_sim_C - parsed.T_stack_meas_C;
parsed.Q_cool_sim_W = sNow.Q_cool_W;
parsed.Q_cool_err_W = parsed.Q_cool_sim_W - parsed.Q_cool_bench_W;
parsed.p_ca_in_meas_kPa = dataRow.cathode_pressure_kPa_abs;
parsed.p_ca_in_sim_kPa = dry.p_kPa;
parsed.p_stack_internal_kPa = sNow.pCa_kPa;
parsed.p_ca_out_boundary_kPa = P.p_cathode_back_kPa;
parsed.pressure_order_ok = parsed.p_ca_in_sim_kPa > parsed.p_stack_internal_kPa && parsed.p_stack_internal_kPa > parsed.p_ca_out_boundary_kPa;
parsed.RH_ca_in_meas = dataRow.cathode_RH;
parsed.RH_ca_in_sim = sNow.RH_ca_in;
parsed.RH_ca_in_err = parsed.RH_ca_in_sim - parsed.RH_ca_in_meas;
parsed.V_cell_meas = dataRow.cell_voltage_from_stack_V;
parsed.V_cell_sim = sNow.V_cell;
parsed.V_cell_err = parsed.V_cell_sim - parsed.V_cell_meas;
parsed.h_cool_fallback_W_K = P.h_cool_W_K;
parsed.h_amb_W_K = P.h_amb_W_K;
parsed.T_cool_boundary_C = P.T_cool_C;
parsed.Q_gen_W = sNow.Q_gen_W;
parsed.Q_amb_W = sNow.Q_amb_W;
parsed.Q_gas_W = sNow.Q_gas_W;
parsed.lambda_O2_actual = sNow.lambda_O2_actual;
parsed.model_name = string(model);
end

function steady = steadyCheck(out, P, stopTime)
steady = struct('dV_cell', inf, 'dp_ca_in', inf, 'dT_stack', inf, 'dRH_ca_in', inf, 'is_steady', false);
if stopTime < 60
    return;
end
idxStart = max(floor((stopTime - 30) / P.dt_s), 1);
n = numSamples(out.summary_vector, numel(summaryFields()));
idxStart = min(idxStart, max(n - 1, 1));
vFirst = vectorAtIndex(out.summary_vector, numel(summaryFields()), idxStart);
vLast = vectorAtIndex(out.summary_vector, numel(summaryFields()), n);
dryFirst = nodeStruct(vectorAtIndex(out.humidifier_dry_node, 7, idxStart), P);
dryLast = nodeStruct(vectorAtIndex(out.humidifier_dry_node, 7, n), P);
steady.dV_cell = abs(vLast(2) - vFirst(2));
steady.dp_ca_in = abs(dryLast.p_kPa - dryFirst.p_kPa);
steady.dT_stack = abs(vLast(9) - vFirst(9));
steady.dRH_ca_in = abs(vLast(21) - vFirst(21));
steady.is_steady = steady.dV_cell <= 0.01 ...
    && steady.dp_ca_in <= 0.5 ...
    && steady.dT_stack <= 0.5 ...
    && steady.dRH_ca_in <= 0.03;
end

function M = metricSummary(R)
qValid = isfinite(R.Q_cool_bench_W) & R.Q_cool_bench_W > 0;
M = struct();
M.points = height(R);
M.steady_points = nnz(R.is_steady);
M.pressure_order_pass = nnz(R.pressure_order_ok);
M.T_stack_RMSE_C = rmsLocal(R.T_stack_err_C);
M.Q_cool_RMSE_W = rmsLocal(R.Q_cool_err_W(qValid));
M.Q_cool_bias_W = mean(R.Q_cool_err_W(qValid), 'omitnan');
M.RH_ca_in_RMSE = rmsLocal(R.RH_ca_in_err);
M.V_cell_RMSE = rmsLocal(R.V_cell_err);
M.min_lambda_O2 = min(R.lambda_O2_actual);
end

function score = thermalScore(M, opts)
steadyPenalty = opts.score_w_steady * (M.points - M.steady_points);
score = M.T_stack_RMSE_C ...
    + opts.score_w_Q * M.Q_cool_RMSE_W ...
    + opts.score_w_bias * abs(M.Q_cool_bias_W) ...
    + steadyPenalty;
end

function printMetrics(M)
fprintf('T_stack RMSE = %.3f C, Q_cool RMSE = %.1f W, Q_cool bias = %.1f W\n', ...
    M.T_stack_RMSE_C, M.Q_cool_RMSE_W, M.Q_cool_bias_W);
fprintf('Steady points = %d/%d, pressure-order pass = %d, min lambda_O2 = %.3f\n', ...
    M.steady_points, M.points, M.pressure_order_pass, M.min_lambda_O2);
end

function T = buildParamTable(P0, Pbest)
rows = {
    "h_cool_W_K", Pbest.h_cool_W_K, P0.h_cool_W_K, "fallback cooling coefficient for off-curve conditions"
    "h_amb_W_K", Pbest.h_amb_W_K, P0.h_amb_W_K, "ambient heat-loss coefficient after thermal stage A"
    "coolant_rho_kg_L", Pbest.coolant_rho_kg_L, P0.coolant_rho_kg_L, "water-equivalent coolant density used for bench heat reconstruction"
    "coolant_cp_J_kgK", Pbest.coolant_cp_J_kgK, P0.coolant_cp_J_kgK, "water-equivalent coolant cp used for bench heat reconstruction"
    "C_stack_J_K", Pbest.C_stack_J_K, P0.C_stack_J_K, "frozen thermal capacitance in stage A"
    "hum_heat_eff", Pbest.hum_heat_eff, P0.hum_heat_eff, "frozen humidifier heat-effectiveness in stage A"
    };
T = cell2table(rows, 'VariableNames', {'parameter', 'value', 'initial_value', 'note'});
end

function writeSummary(path, M, curve, P, ~)
lines = [
    "# Thermal Stage-A Summary"
    ""
    "Date: " + string(datetime('now', 'Format', 'yyyy-MM-dd'))
    ""
    "## Scope"
    ""
    "- Executable model: `01_模型/CEGR_Vehicle_10kW_GZS60_v03_stage1_pressurefix.slx`."
    "- Stage A fits the thermal side first and keeps humidity-side transfer parameters frozen."
    "- Cooling enhancement is modeled as `coolant_flow_L_min -> h_cool_eff`."
    "- Bench coolant heat removal is reconstructed with water-equivalent properties (`rho = 1.0 kg/L`, `cp = 4180 J/kg/K`)."
    "- `C_stack_J_K` stays frozen in stage A."
    ""
    "## Metrics"
    ""
    sprintf("- T_stack RMSE: %.3f C.", M.T_stack_RMSE_C)
    sprintf("- Q_cool RMSE: %.1f W.", M.Q_cool_RMSE_W)
    sprintf("- Q_cool bias: %.1f W.", M.Q_cool_bias_W)
    sprintf("- Steady points: %d/%d.", M.steady_points, M.points)
    sprintf("- Pressure-order pass: %d/%d.", M.pressure_order_pass, M.points)
    sprintf("- RH_ca_in RMSE (regression only): %.3f.", M.RH_ca_in_RMSE)
    sprintf("- V_cell RMSE (regression only): %.4f V/cell.", M.V_cell_RMSE)
    sprintf("- Minimum lambda_O2_actual: %.3f.", M.min_lambda_O2)
    ""
    "## Cooling Curve"
    ""
    sprintf("- Flow support count: %d.", height(curve))
    sprintf("- Ambient heat-loss coefficient: %.3f W/K.", P.h_amb_W_K)
    sprintf("- Fallback cooling coefficient: %.3f W/K.", P.h_cool_W_K)
    ""
    "## Notes"
    ""
    "- Low-load point `bench_j0p10` gives negative bench coolant heat because `coolant_outlet_temp_C < coolant_inlet_temp_C`; it is retained for temperature regression but should not be treated as a hard heat-balance truth point."
    "- Stage B humidity fitting should start only after this thermal baseline is accepted."
    ""
    "## Output Files"
    ""
    "- `04_验证结果/thermal_stageA_diagnostic.csv`"
    "- `04_验证结果/thermal_stageA_candidate_grid.csv`"
    "- `00_输入参数/标定参数/thermal_stageA_params.csv`"
    "- `00_输入参数/标定参数/thermal_stageA_cooling_flow_curve.csv`"
    ];
writeText(path, lines);
end

function assignModelWorkspace(model, P, egrFraction)
ws = get_param(model, 'ModelWorkspace');
vars = {
    'EnvParam_v2', P.EnvParam
    'CompressorParam_v2', P.CompressorParam
    'IntercoolerParam_v2', P.IntercoolerParam
    'HumidifierParam_v2', P.HumidifierParam
    'StackParam_v2', P.StackParam
    'I_stack_cmd_A', P.I_stack_default_A
    'egr_fraction_cmd', egrFraction
    'stack_initial_state_audit', P.stack_initial_state_audit
    'egr_initial_node', P.egr_initial_node
    'wet_initial_node', P.wet_initial_node
    };
for k = 1:size(vars, 1)
    assignin(ws, vars{k, 1}, vars{k, 2});
end
end

function P = rebuildModuleParamsLocal(P)
P.EnvParam = [
    P.F_C_mol
    P.M_O2_kg_mol
    P.M_N2_kg_mol
    P.M_H2O_kg_mol
    P.p_amb_kPa
    P.T_amb_C
    P.RH_amb
    P.xO2_dry
    P.xN2_dry
    P.N_cell
    P.oxygen_stoich
    ];

P.CompressorParam = [
    P.compressor_dp_kPa
    P.compressor_dT_C
    ];

P.IntercoolerParam = [
    P.M_O2_kg_mol
    P.M_N2_kg_mol
    P.M_H2O_kg_mol
    P.p_amb_kPa
    P.intercooler_T_C
    P.intercooler_dp_kPa
    ];

P.HumidifierParam = [
    P.M_O2_kg_mol
    P.M_N2_kg_mol
    P.M_H2O_kg_mol
    P.p_amb_kPa
    P.intercooler_T_C
    P.hum_NTU_ref
    P.hum_m_ref_kg_s
    P.hum_flow_exp
    P.hum_heat_eff
    P.hum_dry_dp_ref_kPa
    P.hum_wet_dp_ref_kPa
    P.hum_dp_exp
    P.hum_mem_area_m2
    P.hum_mem_thickness_m
    P.hum_mem_D_eff_m2_s
    P.hum_beta_wet_m_s
    P.hum_beta_dry_m_s
    P.hum_UA_W_K
    ];

P.StackParam = [
    P.R_J_molK
    P.F_C_mol
    P.M_O2_kg_mol
    P.M_N2_kg_mol
    P.M_H2O_kg_mol
    P.M_H2_kg_mol
    P.p_amb_kPa
    P.T_amb_C
    P.N_cell
    P.A_cell_cm2
    P.V_ca_m3
    P.V_an_m3
    P.K_ca_out_kg_s_kPa
    P.K_an_out_kg_s_kPa
    P.p_cathode_back_kPa
    P.p_anode_back_kPa
    P.K_liq_carry_1_s
    P.C_stack_J_K
    P.h_cool_W_K
    P.T_cool_C
    P.h_amb_W_K
    P.E_nernst_ref_V
    P.E_nernst_temp_coeff_V_K
    P.book_xi1
    P.book_xi2
    P.book_xi3
    P.book_xi4
    P.membraneThickness_cm
    P.book_contact_resistance_ohm
    P.book_concentration_m_V
    P.book_concentration_n_1_A
    P.thermoneutralVoltage_V
    P.anode_stoich
    P.RH_an_in
    P.dt_s
    P.k_mem_water_kg_s
    P.p_anode_in_kPa
    P.K_ca_in_kg_s_kPa
    P.stack_m_act_O2
    P.stack_m_lim_O2
    P.stack_i_lim_ref_A_cm2
    P.stack_lambda_O2_half
    P.LHV_H2_J_mol
    P.coolant_flow_L_min
    P.cool_flow_curve_enabled
    P.cool_flow_curve_L_min(:)
    P.cool_flow_curve_h_W_K(:)
    ];
end

function x0 = buildStackInitialAudit(P, pCa_kPa, pAn_kPa, T_C)
TK = T_C + 273.15;
pSat = saturationPressureKPa(T_C);
pVca = min(0.85 * pSat, 0.95 * pCa_kPa);
pDryCa = max(pCa_kPa - pVca, 1e-3);
pO2 = max(P.xO2_dry * pDryCa, 1e-3);
pN2 = max((1 - P.xO2_dry) * pDryCa, 1e-3);
pVAn = min(P.RH_an_in * pSat, 0.6 * pAn_kPa);
pH2 = max(pAn_kPa - pVAn, 1e-3);
x0 = [
    pO2 * 1000 * P.V_ca_m3 * P.M_O2_kg_mol / (P.R_J_molK * TK)
    pN2 * 1000 * P.V_ca_m3 * P.M_N2_kg_mol / (P.R_J_molK * TK)
    pVca * 1000 * P.V_ca_m3 * P.M_H2O_kg_mol / (P.R_J_molK * TK)
    pH2 * 1000 * P.V_an_m3 * P.M_H2_kg_mol / (P.R_J_molK * TK)
    pVAn * 1000 * P.V_an_m3 * P.M_H2O_kg_mol / (P.R_J_molK * TK)
    T_C
    ];
end

function fields = summaryFields()
fields = [
    "I_stack_A"
    "V_cell"
    "P_stack_W"
    "pO2_ca_kPa"
    "pCa_kPa"
    "pH2_an_kPa"
    "pAn_kPa"
    "lambda_mem"
    "T_stack_C"
    "xO2_ca"
    "RH_ca"
    "m_membrane_water_kg_s"
    "mO2_react_kg_s"
    "mH2_react_kg_s"
    "mH2O_prod_kg_s"
    "m_ca_out_kg_s"
    "m_an_out_kg_s"
    "energy_residual_W"
    "pO2_ca_in_kPa"
    "xO2_ca_in"
    "RH_ca_in"
    "Q_net_stack_W"
    "res_O2_ca_kg_s"
    "res_N2_ca_kg_s"
    "res_H2Ov_ca_kg_s"
    "res_H2Ol_ca_kg_s"
    "res_H2_an_kg_s"
    "res_H2Ov_an_kg_s"
    "res_H2Ol_an_kg_s"
    "res_membrane_water_pair_kg_s"
    "max_species_residual_kg_s"
    "Q_gen_W"
    "Q_cool_W"
    "Q_amb_W"
    "Q_gas_W"
    "E_rev_V"
    "eta_act_V"
    "eta_ohm_V"
    "eta_con_V"
    "lambda_O2_actual"
    "m_ca_in_actual_kg_s"
    "i_lim_eff_A_cm2"
    "i0_O2_scale"
    "mH2O_ca_in_kg_s"
    "mH2O_ca_out_kg_s"
    "mH2O_an_in_kg_s"
    "mH2O_an_out_kg_s"
    "m_liquid_diag_kg"
    "m_fresh_in_kg_s"
    "m_egr_return_kg_s"
    "m_vent_out_kg_s"
    "p_wet_out_kPa"
    "r_EGR_actual"
    "mH2O_hum_transfer_kg_s"
    "RH_hum_dry_out"
    "RH_hum_wet_out"
    "dp_bp_valve_kPa"
    "dp_hum_dry_kPa"
    "dp_hum_wet_kPa"
    "m_wet_out_kg_s"
    "m_egr_cmd_kg_s"
    "m_vent_cmd_kg_s"
    "p_vent_out_kPa"
    ];
end

function s = summaryStruct(v, fields)
s = struct();
for k = 1:numel(fields)
    s.(fields(k)) = v(k);
end
end

function n = nodeStruct(v, P)
n = struct();
n.m_O2_kg_s = v(1);
n.m_N2_kg_s = v(2);
n.m_H2O_v_kg_s = v(3);
n.m_H2O_l_kg_s = v(4);
n.T_C = v(5);
n.p_kPa = v(6);
n.liquid_present = v(7);
n.xO2 = calcXO2(v, P);
n.RH = calcRH(v, P);
end

function v = vectorAt(signal, expectedLength, which)
n = numSamples(signal, expectedLength);
if which == "previous"
    idx = max(n - 1, 1);
else
    idx = n;
end
v = vectorAtIndex(signal, expectedLength, idx);
end

function v = vectorAtIndex(signal, expectedLength, idx)
arr = squeeze(signal);
if isvector(arr)
    arr = arr(:);
    if numel(arr) == expectedLength
        v = arr;
    else
        idx = min(max(idx, 1), floor(numel(arr) / expectedLength));
        startIdx = (idx - 1) * expectedLength + 1;
        v = arr(startIdx:startIdx + expectedLength - 1);
    end
    return;
end
if size(arr, 1) == expectedLength
    idx = min(max(idx, 1), size(arr, 2));
    v = arr(:, idx);
elseif size(arr, 2) == expectedLength
    idx = min(max(idx, 1), size(arr, 1));
    v = arr(idx, :).';
else
    error('Signal length mismatch.');
end
end

function n = numSamples(signal, expectedLength)
arr = squeeze(signal);
if isvector(arr)
    n = max(floor(numel(arr) / expectedLength), 1);
elseif size(arr, 1) == expectedLength
    n = size(arr, 2);
elseif size(arr, 2) == expectedLength
    n = size(arr, 1);
else
    error('Signal length mismatch.');
end
end

function xO2 = calcXO2(v, P)
nTot = max(v(1) / P.M_O2_kg_mol + v(2) / P.M_N2_kg_mol + v(3) / P.M_H2O_kg_mol, 1e-12);
xO2 = (v(1) / P.M_O2_kg_mol) / nTot;
end

function RH = calcRH(v, P)
nTot = max(v(1) / P.M_O2_kg_mol + v(2) / P.M_N2_kg_mol + v(3) / P.M_H2O_kg_mol, 1e-12);
pH2O = v(6) * (v(3) / P.M_H2O_kg_mol) / nTot;
RH = pH2O / max(saturationPressureKPa(v(5)), 1e-6);
end

function pws = saturationPressureKPa(T_C)
Tc = min(max(T_C, -40), 120);
pws = 0.61121 * exp((18.678 - Tc / 234.5) * (Tc / (257.14 + Tc)));
end

function y = rmsLocal(x)
x = x(isfinite(x));
if isempty(x)
    y = NaN;
else
    y = sqrt(mean(x .^ 2));
end
end

function padded = padCalibrationCurve(values)
padded = zeros(1, 13);
n = min(numel(values), 13);
padded(1:n) = reshape(values(1:n), 1, []);
end

function writeText(path, lines)
fid = fopen(path, 'w');
if fid < 0
    error('Failed to open %s for writing.', path);
end
cleaner = onCleanup(@() fclose(fid));
for k = 1:numel(lines)
    fprintf(fid, '%s\n', lines(k));
end
end
