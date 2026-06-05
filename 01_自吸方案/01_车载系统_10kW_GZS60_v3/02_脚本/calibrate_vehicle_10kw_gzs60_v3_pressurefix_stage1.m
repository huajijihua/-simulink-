function results = calibrate_vehicle_10kw_gzs60_v3_pressurefix_stage1()
%CALIBRATE_VEHICLE_10KW_GZS60_V3_PRESSUREFIX_STAGE1
% Second-round pressure-chain calibration for the pressurefix baseline.
%
% The executable model is the pressurefix SLX. Stack channel volumes are kept
% at their geometry-scale values; only pressure/flow parameters are calibrated.

P0 = init_vehicle_10kw_gzs60_v3("base");
P0 = applySecondRoundPrior(P0);
P0 = rebuildModuleParamsLocal(P0);
rootDir = P0.rootDir;
dataFile = fullfile(rootDir, '00_输入参数', '全电流段极化标定', 'full_range_polarization_data.csv');
outDir = fullfile(rootDir, '04_验证结果');
paramDir = fullfile(rootDir, '00_输入参数', '标定参数');
diagFile = fullfile(outDir, 'pressurefix_stage1_no_egr_diagnostic.csv');
candidateDiagFile = fullfile(outDir, 'pressurefix_stage1_candidate_no_egr_diagnostic.csv');
paramFile = fullfile(paramDir, 'pressurefix_stage1_boundary_params.csv');
summaryFile = fullfile(outDir, 'pressurefix_stage1_summary.md');
model = 'CEGR_Vehicle_10kW_GZS60_v03_stage1_pressurefix';
modelFile = fullfile(rootDir, '01_模型', [model '.slx']);

if ~isfile(dataFile)
    error('Missing calibration data: %s', dataFile);
end
if ~isfile(modelFile)
    error('Missing pressurefix model: %s', modelFile);
end
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
if ~exist(paramDir, 'dir')
    mkdir(paramDir);
end

T = readtable(dataFile, 'TextType', 'string');
fitMask = logical(T.use_for_fit) & isfinite(T.cell_voltage_from_stack_V);
D = T(fitMask, :);
if isempty(D)
    error('No usable no-EGR steady points in %s.', dataFile);
end

open_system(modelFile);

opts = calibrationOptions();
spec = parameterSpec(P0);

fprintf('Pressurefix stage-1 calibration, %d no-EGR points.\n', height(D));
fprintf('Coarse coordinate pass: %d parameter groups.\n', numel(spec));

baseX = encodeParams(P0, spec);
[baseScore, baseDiag] = objectiveForX(baseX, P0, D, spec, model, opts);
bestX = baseX;
bestScore = baseScore;

for k = 1:numel(spec)
    candidates = coordinateCandidates(bestX, spec, k);
    for c = 1:size(candidates, 1)
        score = objectiveForX(candidates(c, :), P0, D, spec, model, opts);
        if score < bestScore
            bestScore = score;
            bestX = candidates(c, :);
            fprintf('  improved %-24s score %.5g\n', spec(k).name, bestScore);
        end
    end
end

if opts.runLocalSearch
    localOptions = optimset( ...
        'Display', 'iter', ...
        'MaxIter', opts.localMaxIter, ...
        'MaxFunEvals', opts.localMaxFunEvals, ...
        'TolX', 2e-2, ...
        'TolFun', 2e-2);
    z0 = toUnitSpace(bestX, spec);
    scoreFcn = @(z)objectiveForZ(z, P0, D, spec, model, opts);
    zBest = fminsearch(scoreFcn, z0, localOptions);
    xLocal = fromUnitSpace(zBest, spec);
    scoreLocal = objectiveForX(xLocal, P0, D, spec, model, opts);
    if scoreLocal < bestScore
        bestScore = scoreLocal;
        bestX = xLocal;
    end
end

Pbest = applyParams(P0, bestX, spec);
candidateDiag = runNoEgrDataset(Pbest, D, model, opts.finalRun);
candidateDiag = addWeightsAndErrors(candidateDiag, D);
candidateMetrics = metricSummary(candidateDiag);
baseMetrics = metricSummary(baseDiag);
candidateAccepted = acceptCandidate(baseMetrics, candidateMetrics);
if candidateAccepted
    bestDiag = candidateDiag;
    bestMetrics = candidateMetrics;
else
    Pbest = P0;
    bestDiag = baseDiag;
    bestMetrics = baseMetrics;
end

paramTable = buildParamTable(P0, Pbest, spec, candidateAccepted);

writetable(bestDiag, diagFile);
writetable(candidateDiag, candidateDiagFile);
writetable(paramTable, paramFile);
writeSummary(summaryFile, bestMetrics, baseMetrics, candidateMetrics, candidateAccepted, paramTable, opts);

assignModelWorkspace(model, Pbest, 0.0);
save_system(model);

fprintf('\nWrote pressurefix no-EGR diagnostic to %s\n', diagFile);
fprintf('Wrote pressurefix candidate diagnostic to %s\n', candidateDiagFile);
fprintf('Wrote pressurefix parameter table to %s\n', paramFile);
fprintf('Saved pressurefix model workspace to %s\n', modelFile);
printMetrics(bestMetrics);

results = struct();
results.parameters = paramTable;
results.no_egr_diagnostic = bestDiag;
results.metrics = bestMetrics;
results.score = bestScore;
end

function opts = calibrationOptions()
opts.stopTimeShort_s = 120;
opts.stopTimeLong_s = 300;
opts.steadyWindow_s = 30;
opts.runLocalSearch = false;
opts.localMaxIter = 8;
opts.localMaxFunEvals = 14;
opts.finalRun.adaptiveSteady = true;
opts.finalRun.verbose = false;
opts.objectiveRun.adaptiveSteady = true;
opts.objectiveRun.verbose = false;
opts.objectiveWeights = struct( ...
    'p_ca_in', 1.0, ...
    'pO2_in', 1.0, ...
    'pressurePenalty', 12.0, ...
    'lambdaPenalty', 8.0);
end

function P = applySecondRoundPrior(P)
% Explicit second-round priors from the previous no-EGR calibration baseline.
% These are used as starting assumptions, not silently read from output CSVs.
P.h_cool_W_K = 121;
P.h_amb_W_K = 9;
P.hum_mem_area_m2 = 40;
P.hum_mem_D_eff_m2_s = 1.0e-9;
P.hum_beta_wet_m_s = 0.02;
P.hum_beta_dry_m_s = 0.02;
P.hum_heat_eff = 0.5825;
P.book_xi1 = -1.18256193784984;
P.book_xi2 = 0.00294108739022835;
P.book_xi3 = 5.21269240295832e-05;
P.book_xi4 = -8.54349163446432e-05;
P.book_contact_resistance_ohm = 2.2204486714779e-14;
P.book_concentration_m_V = 3.97280101897563e-05;
P.book_concentration_n_1_A = 0.00982352283961081;
end

function spec = parameterSpec(P0)
spec = [
    makeSpec("K_ca_in_kg_s_kPa", P0.K_ca_in_kg_s_kPa, 5.0e-5, 5.0e-2, "kg/s/kPa", "C", "stack inlet pressure-flow coefficient")
    makeSpec("K_ca_out_kg_s_kPa", P0.K_ca_out_kg_s_kPa, 1.0e-5, 5.0e-2, "kg/s/kPa", "C", "stack cathode outlet pressure-flow coefficient")
    makeSpec("hum_dry_dp_ref_kPa", P0.hum_dry_dp_ref_kPa, 0.5, 25.0, "kPa", "B", "GZS60 dry-side pressure-drop equivalent")
    makeSpec("hum_wet_dp_ref_kPa", P0.hum_wet_dp_ref_kPa, 0.5, 35.0, "kPa", "B", "GZS60 wet-side pressure-drop equivalent")
    makeSpec("hum_dp_exp", P0.hum_dp_exp, 0.35, 1.25, "1", "C", "humidifier pressure-drop flow exponent")
    ];
end

function s = makeSpec(name, initial, lb, ub, unit, sourceLevel, note)
s = struct();
s.name = name;
s.initial = initial;
s.lb = lb;
s.ub = ub;
s.unit = unit;
s.source_level = sourceLevel;
s.note = note;
end

function x = encodeParams(P, spec)
x = zeros(1, numel(spec));
for k = 1:numel(spec)
    x(k) = P.(spec(k).name);
end
end

function z = toUnitSpace(x, spec)
z = zeros(size(x));
for k = 1:numel(x)
    lb = spec(k).lb;
    ub = spec(k).ub;
    y = min(max((x(k) - lb) / max(ub - lb, eps), 1e-6), 1 - 1e-6);
    z(k) = log(y / (1 - y));
end
end

function x = fromUnitSpace(z, spec)
x = zeros(size(z));
for k = 1:numel(z)
    y = 1 / (1 + exp(-z(k)));
    x(k) = spec(k).lb + y * (spec(k).ub - spec(k).lb);
end
end

function candidates = coordinateCandidates(x, spec, idx)
candidates = [];
base = x(idx);
if contains(spec(idx).name, "K_")
    factors = [0.10, 0.25, 0.45, 1.8, 4.0, 10.0, 25.0, 75.0];
elseif contains(spec(idx).name, "h_")
    factors = [0.55, 1.8];
elseif contains(spec(idx).name, "hum_dp_exp")
    factors = [0.8, 1.2];
else
    factors = [0.65, 1.35];
end
for k = 1:numel(factors)
    xt = x;
    xt(idx) = min(max(base * factors(k), spec(idx).lb), spec(idx).ub);
    candidates = [candidates; xt]; %#ok<AGROW>
end
end

function score = objectiveForZ(z, P0, D, spec, model, opts)
x = fromUnitSpace(z, spec);
score = objectiveForX(x, P0, D, spec, model, opts);
end

function [score, diag] = objectiveForX(x, P0, D, spec, model, opts)
P = applyParams(P0, x, spec);
diag = runNoEgrDataset(P, D, model, opts.objectiveRun);
diag = addWeightsAndErrors(diag, D);
score = scoreDiagnostic(diag, opts.objectiveWeights);
end

function P = applyParams(P, x, spec)
for k = 1:numel(spec)
    P.(spec(k).name) = min(max(x(k), spec(k).lb), spec(k).ub);
end
P = rebuildModuleParamsLocal(P);
P.stack_initial_state_audit = buildStackInitialAudit(P, P.p_cathode_back_kPa, P.p_anode_back_kPa, 65.0);
P.wet_initial_node = [0 0 0 0 70.0 P.p_cathode_back_kPa 0]';
end

function R = runNoEgrDataset(Pbase, D, model, runOpts)
rows = cell(height(D), 1);
for k = 1:height(D)
    P = configureNoEgrCase(Pbase, D(k, :));
    rows{k} = runCase(P, D(k, :), model, 0.0, runOpts, "no_egr");
end
R = vertcat(rows{:});
end

function P = configureNoEgrCase(P, row)
P.I_stack_default_A = row.current_A;
P.oxygen_stoich = flowDerivedLambda(row, P);
P.anode_stoich = row.anode_stoich;
P.RH_an_in = row.anode_RH;
P.p_anode_in_kPa = row.anode_pressure_kPa_abs;
P.p_anode_back_kPa = row.anode_outlet_pressure_kPa_g + P.p_amb_kPa;
P.p_cathode_back_kPa = row.cathode_outlet_pressure_kPa_g + P.p_amb_kPa;
P.T_cool_C = 0.5 * (row.coolant_inlet_temp_C + row.coolant_outlet_temp_C);
P.coolant_flow_L_min = row.coolant_flow_L_min;
P.intercooler_T_C = row.cathode_inlet_temp_C;
P.EnvParam(6) = max(row.cathode_inlet_temp_C - P.compressor_dT_C, -20);
P.EnvParam(11) = P.oxygen_stoich;
P.IntercoolerParam(5) = P.intercooler_T_C;

% Bench inlet pressure is treated as a calibration boundary for the first
% pass. The compressor pressure rise is set so humidifier dry-out pressure
% lands near the measured cathode inlet pressure for the current candidate.
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
lambda = max(lambda, 0.05);
end

function dryDp = estimateHumidifierDryDp(P, I)
Ptmp = P;
Ptmp.EnvParam(11) = max(P.oxygen_stoich, 0.05);
fresh = freshAirNode(Ptmp.EnvParam, I);
mDry = max(sum(fresh(1:4)), 1e-9);
dryDp = P.hum_dry_dp_ref_kPa * (mDry / max(P.hum_m_ref_kg_s, 1e-9)) ^ P.hum_dp_exp;
end

function node = freshAirNode(env, I)
F = env(1); M_O2 = env(2); M_N2 = env(3); M_H2O = env(4);
pamb = env(5); Tamb = env(6); RH = env(7); xO2 = env(8); xN2 = env(9);
N = env(10); stoich = env(11);
psat = saturationPressureKPa(Tamb);
pH2O = min(RH * psat, 0.98 * pamb);
pdry = max(pamb - pH2O, 1e-6);
pO2 = xO2 * pdry;
pN2 = xN2 * pdry;
nO2 = stoich * max(I, 0) * N / (4 * F);
mO2 = max(nO2 * M_O2, 1e-7);
scale = (mO2 / M_O2) / max(pO2, 1e-9);
node = [mO2; pN2 * scale * M_N2; pH2O * scale * M_H2O; 0; Tamb; pamb; 0];
end

function rowOut = runCase(P, dataRow, model, egrFraction, runOpts, caseMode)
out = runOneSim(P, model, egrFraction, 120);
parsed = parseCaseOutput(out, P, dataRow, model, egrFraction, caseMode, 120);
if runOpts.adaptiveSteady && ~parsed.is_steady
    out = runOneSim(P, model, egrFraction, 300);
    parsed = parseCaseOutput(out, P, dataRow, model, egrFraction, caseMode, 300);
end
rowOut = struct2table(parsed);
end

function out = runOneSim(P, model, egrFraction, stopTime)
in = Simulink.SimulationInput(model);
in = in.setModelParameter( ...
    'StopTime', num2str(stopTime), ...
    'SolverType', 'Fixed-step', ...
    'Solver', 'FixedStepDiscrete', ...
    'FixedStep', num2str(P.dt_s), ...
    'ReturnWorkspaceOutputs', 'on');
in = setModelVars(in, model, P, egrFraction);
out = sim(in);
end

function in = setModelVars(in, model, P, egrFraction)
in = in.setVariable('P_v2', P, 'Workspace', model);
in = in.setVariable('EnvParam_v2', P.EnvParam, 'Workspace', model);
in = in.setVariable('CompressorParam_v2', P.CompressorParam, 'Workspace', model);
in = in.setVariable('IntercoolerParam_v2', P.IntercoolerParam, 'Workspace', model);
in = in.setVariable('HumidifierParam_v2', P.HumidifierParam, 'Workspace', model);
in = in.setVariable('StackParam_v2', P.StackParam, 'Workspace', model);
in = in.setVariable('I_stack_cmd_A', P.I_stack_default_A, 'Workspace', model);
in = in.setVariable('egr_fraction_cmd', egrFraction, 'Workspace', model);
in = in.setVariable('EGRInitialNode_v2', P.egr_initial_node, 'Workspace', model);
in = in.setVariable('WetInitialNode_v2', P.wet_initial_node, 'Workspace', model);
in = in.setVariable('StackInitialStateAudit_v3', P.stack_initial_state_audit, 'Workspace', model);
end

function parsed = parseCaseOutput(out, P, dataRow, model, egrFraction, caseMode, stopTime)
fields = summaryFields();
sNow = summaryStruct(vectorAt(out.summary_vector, numel(fields), "final"), fields);
dry = nodeStruct(vectorAt(out.humidifier_dry_node, 7, "final"), P);
wet = nodeStruct(vectorAt(out.humidifier_wet_node, 7, "final"), P);
fresh = nodeStruct(vectorAt(out.fresh_node, 7, "final"), P);
egr = nodeStruct(vectorAt(out.egr_return_node, 7, "final"), P);
vent = nodeStruct(vectorAt(out.vent_node, 7, "final"), P);
steady = steadyCheck(out, P, stopTime);

parsed = struct();
parsed.case_id = string(dataRow.case_id);
parsed.case_mode = string(caseMode);
parsed.stop_time_s = stopTime;
parsed.is_steady = steady.is_steady;
parsed.dV_cell_30s = steady.dV_cell;
parsed.dp_ca_in_30s_kPa = steady.dp_ca_in;
parsed.dT_stack_30s_C = steady.dT_stack;
parsed.dRH_ca_in_30s = steady.dRH_ca_in;
parsed.egr_fraction_cmd = egrFraction;
parsed.current_A = dataRow.current_A;
parsed.current_density_A_cm2 = dataRow.current_density_A_cm2;
parsed.flow_lambda_from_nlpm = flowDerivedLambda(dataRow, P);
parsed.cathode_stoich_table = dataRow.cathode_stoich;
parsed.flow_lambda_minus_table = parsed.flow_lambda_from_nlpm - dataRow.cathode_stoich;

parsed.V_cell_meas = dataRow.cell_voltage_from_stack_V;
parsed.V_cell_sim = sNow.V_cell;
parsed.p_ca_in_meas_kPa = dataRow.cathode_pressure_kPa_abs;
parsed.p_ca_in_sim_kPa = dry.p_kPa;
parsed.p_stack_internal_kPa = sNow.pCa_kPa;
parsed.p_ca_out_meas_kPa = dataRow.cathode_outlet_pressure_kPa_g + P.p_amb_kPa;
parsed.p_ca_out_boundary_kPa = P.p_cathode_back_kPa;
parsed.p_ca_out_boundary_error_kPa = parsed.p_ca_out_boundary_kPa - parsed.p_ca_out_meas_kPa;
parsed.pO2_in_meas_kPa = dataRow.pO2_caIn_kPa;
parsed.pO2_in_sim_kPa = sNow.pO2_ca_in_kPa;
parsed.RH_ca_in_meas = dataRow.cathode_RH;
parsed.RH_ca_in_sim = sNow.RH_ca_in;
parsed.T_stack_meas_C = dataRow.stack_temperature_est_C;
parsed.T_stack_sim_C = sNow.T_stack_C;
parsed.lambda_O2_actual = sNow.lambda_O2_actual;
parsed.xO2_ca_in = sNow.xO2_ca_in;
parsed.eta_act_V = sNow.eta_act_V;
parsed.eta_ohm_V = sNow.eta_ohm_V;
parsed.eta_con_V = sNow.eta_con_V;
parsed.E_rev_V = sNow.E_rev_V;
parsed.RH_hum_dry_out = sNow.RH_hum_dry_out;
parsed.RH_hum_wet_out = sNow.RH_hum_wet_out;
parsed.m_fresh_basis_kg_s = sNow.m_fresh_in_kg_s;
parsed.m_fresh_actual_kg_s = max(sNow.m_fresh_in_kg_s - sNow.m_egr_return_kg_s, 0);
parsed.m_egr_used_kg_s = sNow.m_egr_return_kg_s;
parsed.m_comp_total_kg_s = parsed.m_fresh_actual_kg_s + parsed.m_egr_used_kg_s;
parsed.m_comp_total_error_kg_s = parsed.m_comp_total_kg_s - parsed.m_fresh_basis_kg_s;
parsed.r_EGR_actual = sNow.r_EGR_actual;
parsed.m_wet_out_kg_s = sNow.m_wet_out_kg_s;
parsed.m_vent_out_kg_s = sNow.m_vent_out_kg_s;
parsed.humidifier_dry_T_C = dry.T_C;
parsed.humidifier_wet_T_C = wet.T_C;
parsed.fresh_node_m_kg_s = sum([fresh.m_O2_kg_s, fresh.m_N2_kg_s, fresh.m_H2O_v_kg_s]);
parsed.egr_node_m_kg_s = sum([egr.m_O2_kg_s, egr.m_N2_kg_s, egr.m_H2O_v_kg_s]);
parsed.vent_node_m_kg_s = sum([vent.m_O2_kg_s, vent.m_N2_kg_s, vent.m_H2O_v_kg_s]);

parsed.V_cell_err = parsed.V_cell_sim - parsed.V_cell_meas;
parsed.p_ca_in_err_kPa = parsed.p_ca_in_sim_kPa - parsed.p_ca_in_meas_kPa;
parsed.p_stack_margin_in_kPa = parsed.p_ca_in_sim_kPa - parsed.p_stack_internal_kPa;
parsed.p_stack_margin_out_kPa = parsed.p_stack_internal_kPa - parsed.p_ca_out_boundary_kPa;
parsed.pO2_in_err_kPa = parsed.pO2_in_sim_kPa - parsed.pO2_in_meas_kPa;
parsed.RH_ca_in_err = parsed.RH_ca_in_sim - parsed.RH_ca_in_meas;
parsed.T_stack_err_C = parsed.T_stack_sim_C - parsed.T_stack_meas_C;
parsed.pressure_order_ok = parsed.p_ca_in_sim_kPa > parsed.p_stack_internal_kPa && parsed.p_stack_internal_kPa > parsed.p_ca_out_boundary_kPa;
parsed.lambda_safe_ok = parsed.lambda_O2_actual >= 1.2;
parsed.lambda_unacceptable = parsed.lambda_O2_actual < 1.0;
parsed.RH_ok = parsed.RH_ca_in_sim >= 0 && parsed.RH_ca_in_sim <= 1.2 && parsed.RH_hum_dry_out >= 0 && parsed.RH_hum_dry_out <= 1.2;
parsed.T_stack_ok = parsed.T_stack_sim_C >= 50 && parsed.T_stack_sim_C <= 90;
parsed.V_cell_ok = parsed.V_cell_sim >= 0.5 && parsed.V_cell_sim <= 0.9;
parsed.voltage_terms_ok = parsed.eta_act_V >= 0 && parsed.eta_ohm_V >= 0 && parsed.eta_con_V >= 0 && parsed.E_rev_V > parsed.V_cell_sim;
parsed.physical_ok = parsed.pressure_order_ok && parsed.lambda_safe_ok && parsed.RH_ok && parsed.T_stack_ok && parsed.V_cell_ok && parsed.voltage_terms_ok && parsed.is_steady;
parsed.model_name = string(model);
end

function steady = steadyCheck(out, P, stopTime)
fields = summaryFields();
n = numSamples(out.summary_vector, numel(fields));
windowN = max(2, min(n, round(30 / P.dt_s)));
idxStart = max(n - windowN + 1, 1);
vFirst = vectorAtIndex(out.summary_vector, numel(fields), idxStart);
vLast = vectorAtIndex(out.summary_vector, numel(fields), n);
dryFirst = nodeStruct(vectorAtIndex(out.humidifier_dry_node, 7, idxStart), P);
dryLast = nodeStruct(vectorAtIndex(out.humidifier_dry_node, 7, n), P);
steady = struct();
steady.dV_cell = abs(vLast(2) - vFirst(2));
steady.dp_ca_in = abs(dryLast.p_kPa - dryFirst.p_kPa);
steady.dT_stack = abs(vLast(9) - vFirst(9));
steady.dRH_ca_in = abs(vLast(21) - vFirst(21));
steady.is_steady = steady.dV_cell <= 0.002 ...
    && steady.dp_ca_in <= 1.0 ...
    && steady.dT_stack <= 0.5 ...
    && steady.dRH_ca_in <= 0.03;
if stopTime <= 120 && ~steady.is_steady
    steady.is_steady = false;
end
end

function R = addWeightsAndErrors(R, D)
R.stage_weight = ones(height(R), 1);
for k = 1:height(R)
    j = R.current_density_A_cm2(k);
    if j >= 0.1 && j <= 0.4
        R.stage_weight(k) = 1.5;
    else
        idx = find(D.case_id == R.case_id(k), 1);
        if ~isempty(idx) && ismember("weight", string(D.Properties.VariableNames))
            R.stage_weight(k) = D.weight(idx);
        end
    end
end
end

function score = scoreDiagnostic(R, w)
pressurePenalty = double(~R.pressure_order_ok);
lambdaPenalty = double(R.lambda_unacceptable);
res = [
    w.p_ca_in * R.p_ca_in_err_kPa / 10
    w.pO2_in * R.pO2_in_err_kPa / 4
    w.pressurePenalty * pressurePenalty
    w.lambdaPenalty * lambdaPenalty
    ];
weights = repmat(R.stage_weight, 4, 1);
score = sqrt(mean((res .* weights) .^ 2, 'omitnan'));
if ~isfinite(score)
    score = 1e9;
end
end

function M = metricSummary(R)
M = struct();
M.points = height(R);
M.steady_points = sum(R.is_steady);
M.physical_ok_points = sum(R.physical_ok);
M.V_cell_RMSE = rmsLocal(R.V_cell_err);
M.V_cell_max_abs = max(abs(R.V_cell_err));
M.p_ca_in_RMSE_kPa = rmsLocal(R.p_ca_in_err_kPa);
M.pO2_in_RMSE_kPa = rmsLocal(R.pO2_in_err_kPa);
M.RH_ca_in_RMSE = rmsLocal(R.RH_ca_in_err);
M.T_stack_RMSE_C = rmsLocal(R.T_stack_err_C);
M.pressure_order_failures = sum(~R.pressure_order_ok);
M.not_steady_points = sum(~R.is_steady);
end

function ok = acceptCandidate(baseM, candidateM)
pressureImproved = candidateM.pressure_order_failures < baseM.pressure_order_failures;
pressureMetricNotWorse = candidateM.p_ca_in_RMSE_kPa <= max(1.10 * baseM.p_ca_in_RMSE_kPa, baseM.p_ca_in_RMSE_kPa + 0.5);
oxygenMetricNotWorse = candidateM.pO2_in_RMSE_kPa <= max(1.25 * baseM.pO2_in_RMSE_kPa, baseM.pO2_in_RMSE_kPa + 1.0);
ok = (pressureImproved || candidateM.pressure_order_failures == 0) && pressureMetricNotWorse && oxygenMetricNotWorse;
end

function printMetrics(M)
fprintf('Points: %d, steady: %d, physical-ok: %d\n', M.points, M.steady_points, M.physical_ok_points);
fprintf('V_cell RMSE = %.5f V/cell, max abs = %.5f V/cell\n', M.V_cell_RMSE, M.V_cell_max_abs);
fprintf('p_ca_in RMSE = %.3f kPa, pO2_in RMSE = %.3f kPa, RH_in RMSE = %.3f, T_stack RMSE = %.3f C\n', ...
    M.p_ca_in_RMSE_kPa, M.pO2_in_RMSE_kPa, M.RH_ca_in_RMSE, M.T_stack_RMSE_C);
fprintf('Pressure-order failures: %d, not-steady points: %d\n', M.pressure_order_failures, M.not_steady_points);
end

function T = buildParamTable(P0, Pbest, spec, candidateAccepted)
rows = cell(numel(spec), 1);
for k = 1:numel(spec)
    row = table();
    row.parameter = string(spec(k).name);
    row.value = Pbest.(spec(k).name);
    row.unit = string(spec(k).unit);
    row.source_level = string(spec(k).source_level);
    row.source_note = string(spec(k).note);
    row.optimized_in_stage1 = candidateAccepted;
    row.lower_bound = spec(k).lb;
    row.upper_bound = spec(k).ub;
    if ~candidateAccepted
        status = "baseline_retained";
    elseif abs(Pbest.(spec(k).name) - spec(k).lb) <= 1e-9 || abs(Pbest.(spec(k).name) - spec(k).ub) <= 1e-9
        status = "at_bound_review";
    elseif abs(Pbest.(spec(k).name) - P0.(spec(k).name)) <= max(abs(P0.(spec(k).name)) * 1e-6, 1e-12)
        status = "unchanged";
    else
        status = "pressurefix_candidate";
    end
    row.calibration_status = status;
    if candidateAccepted
        row.notes = "Pressurefix model workspace saved with accepted pressure-chain candidate.";
    else
        row.notes = "Search candidate failed acceptance gate; baseline value retained.";
    end
    rows{k} = row;
end
T = vertcat(rows{:});
end

function writeSummary(path, M, baseM, candidateM, candidateAccepted, paramTable, opts)
lines = [
    "# Pressurefix Stage-1 Calibration Summary"
    ""
    sprintf("Date: %s", string(datetime('now', 'Format', 'yyyy-MM-dd')))
    ""
    "## Scope"
    ""
    "- `CEGR_Vehicle_10kW_GZS60_v03_stage1_pressurefix.slx` was used as the executable system model."
    "- Stack cathode/anode channel volumes are fixed at geometry-scale values."
    "- Cathode and anode outlet node pressures are boundary pressures; internal stack pressures remain diagnostics only."
    "- No-EGR full-current bench data were used for pressure/flow boundary fitting."
    "- Humidity, voltage, and heat parameters are reused from the previous fit and are checked by regression, not refitted here."
    ""
    "## No-EGR Metrics"
    ""
    sprintf("- Candidate accepted: %s.", string(candidateAccepted))
    sprintf("- Base V_cell RMSE: %.5f V/cell; selected: %.5f V/cell; candidate: %.5f V/cell.", baseM.V_cell_RMSE, M.V_cell_RMSE, candidateM.V_cell_RMSE)
    sprintf("- Base p_ca_in RMSE: %.3f kPa; selected: %.3f kPa; candidate: %.3f kPa.", baseM.p_ca_in_RMSE_kPa, M.p_ca_in_RMSE_kPa, candidateM.p_ca_in_RMSE_kPa)
    sprintf("- Candidate steady points: %d/%d; candidate physical-ok points: %d/%d.", candidateM.steady_points, candidateM.points, candidateM.physical_ok_points, candidateM.points)
    sprintf("- Base pressure-order failures: %d; candidate pressure-order failures: %d.", baseM.pressure_order_failures, candidateM.pressure_order_failures)
    sprintf("- pO2_in RMSE: %.3f kPa; RH_in RMSE: %.3f; T_stack RMSE: %.3f C.", M.pO2_in_RMSE_kPa, M.RH_ca_in_RMSE, M.T_stack_RMSE_C)
    sprintf("- Steady points: %d/%d; physical-ok points: %d/%d.", M.steady_points, M.points, M.physical_ok_points, M.points)
    ""
    "## Important Boundary Note"
    ""
    "- Bench cathode inlet pressure is used as a first-pass compressor pressure boundary."
    "- `cathode_flow_nlpm` is converted to an equivalent oxygen stoichiometry and compared with the table `cathode_stoich`."
    "- `p_stack_internal_kPa` is checked only as an internal pressure state, not as the bench inlet pressure."
    ""
    "## Output Files"
    ""
    "- `04_验证结果/pressurefix_stage1_no_egr_diagnostic.csv`"
    "- `00_输入参数/标定参数/pressurefix_stage1_boundary_params.csv`"
    "- `01_模型/CEGR_Vehicle_10kW_GZS60_v03_stage1_pressurefix.slx`"
    ""
    "## Parameter Candidates"
    ""
    sprintf("- Optimized parameter count: %d.", height(paramTable))
    sprintf("- Local search enabled: %s; max function evaluations: %d.", string(opts.runLocalSearch), opts.localMaxFunEvals)
    ];
writeText(path, lines);
end

function assignModelWorkspace(model, P, egrFraction)
mw = get_param(model, 'ModelWorkspace');
assignin(mw, 'P_v2', P);
assignin(mw, 'EnvParam_v2', P.EnvParam);
assignin(mw, 'CompressorParam_v2', P.CompressorParam);
assignin(mw, 'IntercoolerParam_v2', P.IntercoolerParam);
assignin(mw, 'HumidifierParam_v2', P.HumidifierParam);
assignin(mw, 'StackParam_v2', P.StackParam);
assignin(mw, 'I_stack_cmd_A', P.I_stack_default_A);
assignin(mw, 'egr_fraction_cmd', egrFraction);
assignin(mw, 'EGRInitialNode_v2', P.egr_initial_node);
assignin(mw, 'WetInitialNode_v2', P.wet_initial_node);
assignin(mw, 'StackInitialStateAudit_v3', P.stack_initial_state_audit);
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
P.CompressorParam = [P.compressor_dp_kPa; P.compressor_dT_C];
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
    getFieldDefault(P, 'coolant_flow_L_min', 6.0)
    getFieldDefault(P, 'cool_flow_curve_enabled', 0)
    getFieldDefault(P, 'cool_flow_curve_L_min', zeros(1, 13)).'
    getFieldDefault(P, 'cool_flow_curve_h_W_K', zeros(1, 13)).'
    ];
end

function value = getFieldDefault(S, fieldName, defaultValue)
if isfield(S, fieldName)
    value = S.(fieldName);
else
    value = defaultValue;
end
end

function x0 = buildStackInitialAudit(P, pCa_kPa, pAn_kPa, T_C)
TK = T_C + 273.15;
pSat = saturationPressureKPa(T_C);
pV = min(0.5 * pSat, 0.6 * pCa_kPa);
pDry = max(pCa_kPa - pV, 1e-6);
pO2 = 0.20 * pDry;
pN2 = 0.80 * pDry;
pVAn = min(P.RH_an_in * pSat, 0.6 * pAn_kPa);
pH2 = max(pAn_kPa - pVAn, 1e-6);
x0 = [
    pO2 * 1000 * P.V_ca_m3 * P.M_O2_kg_mol / (P.R_J_molK * TK)
    pN2 * 1000 * P.V_ca_m3 * P.M_N2_kg_mol / (P.R_J_molK * TK)
    pV * 1000 * P.V_ca_m3 * P.M_H2O_kg_mol / (P.R_J_molK * TK)
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
    v = arr(idx, :)';
else
    error('Unexpected signal dimensions for expected length %d.', expectedLength);
end
end

function n = numSamples(signal, expectedLength)
arr = squeeze(signal);
if isvector(arr)
    if numel(arr) == expectedLength
        n = 1;
    else
        n = floor(numel(arr) / expectedLength);
    end
    return;
end
if size(arr, 1) == expectedLength
    n = size(arr, 2);
elseif size(arr, 2) == expectedLength
    n = size(arr, 1);
else
    n = size(arr, ndims(arr));
end
end

function xO2 = calcXO2(v, P)
nO2 = max(v(1), 0) / P.M_O2_kg_mol;
nN2 = max(v(2), 0) / P.M_N2_kg_mol;
nV = max(v(3), 0) / P.M_H2O_kg_mol;
xO2 = nO2 / max(nO2 + nN2 + nV, 1e-12);
end

function RH = calcRH(v, P)
nO2 = max(v(1), 0) / P.M_O2_kg_mol;
nN2 = max(v(2), 0) / P.M_N2_kg_mol;
nV = max(v(3), 0) / P.M_H2O_kg_mol;
pH2O = v(6) * nV / max(nO2 + nN2 + nV, 1e-12);
RH = min(max(pH2O / max(saturationPressureKPa(v(5)), 1e-9), 0), 1.5);
end

function pws = saturationPressureKPa(T_C)
pws = 0.61121 * exp((18.678 - T_C / 234.5) * (T_C / (257.14 + T_C)));
end

function y = rmsLocal(x)
y = sqrt(mean(x .^ 2, 'omitnan'));
end

function writeText(path, lines)
text = strjoin(lines, newline);
fid = fopen(path, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '%s\n', text);
end
