function results = calibrate_vehicle_10kw_gzs60_v3_humidity_stageB()
%CALIBRATE_VEHICLE_10KW_GZS60_V3_HUMIDITY_STAGEB
% Stage B of the second-round thermal/humidity route.
%
% This entry fits the stack-inlet water state under 13 no-EGR steady points
% while using humidifier four-port data as a secondary prior to keep dry/wet
% side exchange physically reasonable.
%
% This route is now a historical comparison. The current vehicle humidifier
% boundary is maintained by analyze_vehicle_10kw_gzs60_v3_humidifier_first.
% Set ALLOW_HISTORICAL_STAGEB=1 only when intentionally regenerating the old
% stack-inlet-humidity fit, because this script overwrites
% humidity_stageB_params.csv.

if ~strcmp(getenv('ALLOW_HISTORICAL_STAGEB'), '1')
    error(['calibrate_vehicle_10kw_gzs60_v3_humidity_stageB is historical. ', ...
        'Run analyze_vehicle_10kw_gzs60_v3_humidifier_first for the current ', ...
        'humidifier-first baseline, or set ALLOW_HISTORICAL_STAGEB=1 to regenerate ', ...
        'the old comparison route.']);
end

P0 = init_vehicle_10kw_gzs60_v3("stageA");
P0 = rebuildModuleParamsLocal(P0);

rootDir = P0.rootDir;
benchFile = fullfile(rootDir, '00_输入参数', '全电流段极化标定', 'full_range_polarization_data.csv');
priorFile = fullfile(rootDir, '00_输入参数', '旧版提炼', 'GZS通用化数据与参数反演', 'gzs_humidifier_standard_four_port_dataset.csv');
outDir = fullfile(rootDir, '04_验证结果');
paramDir = fullfile(rootDir, '00_输入参数', '标定参数');
diagFile = fullfile(outDir, 'humidity_stageB_no_egr_diagnostic.csv');
priorReplayFile = fullfile(outDir, 'humidity_stageB_hum_prior_replay.csv');
candidatePriorReplayFile = fullfile(outDir, 'humidity_stageB_candidate_hum_prior_replay.csv');
traceFile = fullfile(outDir, 'humidity_stageB_candidate_trace.csv');
summaryFile = fullfile(outDir, 'humidity_stageB_summary.md');
paramFile = fullfile(paramDir, 'humidity_stageB_params.csv');
model = 'CEGR_Vehicle_10kW_GZS60_v03_stage1_pressurefix';
modelFile = fullfile(rootDir, '01_模型', [model '.slx']);

if ~isfile(benchFile)
    error('Missing bench data: %s', benchFile);
end
if ~isfile(priorFile)
    error('Missing humidifier prior data: %s', priorFile);
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

B = readtable(benchFile, 'TextType', 'string');
benchMask = logical(B.use_for_fit) & isfinite(B.pH2O_caIn_kPa) & isfinite(B.xH2O_caIn);
D = B(benchMask, :);
if isempty(D)
    error('No usable no-EGR humidity points in %s.', benchFile);
end

H = readtable(priorFile, 'TextType', 'string');
priorMask = ismember(string(H.calibration_use_level), ["dual_side_fit_candidate", "dry_priority_only"]);
H = H(priorMask, :);
if isempty(H)
    error('No usable humidifier prior points in %s.', priorFile);
end

open_system(modelFile);

opts = humidityOptions();
spec = parameterSpec(P0);

fprintf('Humidity stage B calibration, %d no-EGR points, %d humidifier prior points.\n', height(D), height(H));

baseX = encodeParams(P0, spec);
[baseMetrics, baseDiag, basePriorReplay] = evaluateCandidate(baseX, P0, D, H, spec, model, opts);

bestX = baseX;
bestMetrics = baseMetrics;
bestDiag = baseDiag;
bestPriorReplay = basePriorReplay;
bestScore = scoreCandidate(baseMetrics, baseMetrics, opts);
traceRows = {metricsToTraceRow("base", 0, bestMetrics, bestScore)};

for pass = 1:opts.coordinatePasses
    improved = false;
    for k = 1:numel(spec)
        candidates = coordinateCandidates(bestX, spec, k);
        for c = 1:size(candidates, 1)
            [M, R, Rprior] = evaluateCandidate(candidates(c, :), P0, D, H, spec, model, opts);
            score = scoreCandidate(M, baseMetrics, opts);
            traceRows{end+1} = metricsToTraceRow(spec(k).name, pass, M, score); %#ok<AGROW>
            if score < bestScore
                bestScore = score;
                bestX = candidates(c, :);
                bestMetrics = M;
                bestDiag = R;
                bestPriorReplay = Rprior;
                improved = true;
                fprintf('  improved %-22s pass %d score %.4f\n', spec(k).name, pass, bestScore);
            end
        end
    end
    if ~improved
        break;
    end
end

candidateAccepted = acceptCandidate(baseMetrics, bestMetrics, opts);
if candidateAccepted
    Pbest = applyParams(P0, bestX, spec);
    finalDiag = bestDiag;
    finalPriorReplay = bestPriorReplay;
    finalMetrics = bestMetrics;
else
    Pbest = P0;
    finalDiag = baseDiag;
    finalPriorReplay = basePriorReplay;
    finalMetrics = baseMetrics;
end

Pbest = rebuildModuleParamsLocal(Pbest);
paramTable = buildParamTable(P0, Pbest, spec, candidateAccepted);
traceTable = vertcat(traceRows{:});

writetable(finalDiag, diagFile);
writetable(finalPriorReplay, priorReplayFile);
writetable(bestPriorReplay, candidatePriorReplayFile);
writetable(traceTable, traceFile);
writetable(paramTable, paramFile);
writeSummary(summaryFile, finalMetrics, baseMetrics, bestMetrics, candidateAccepted, paramTable, opts);

assignModelWorkspace(model, Pbest, 0.0);
save_system(model);

fprintf('\nWrote Stage-B humidity diagnostic to %s\n', diagFile);
fprintf('Wrote Stage-B humidifier prior replay to %s\n', priorReplayFile);
fprintf('Wrote Stage-B candidate trace to %s\n', traceFile);
fprintf('Wrote Stage-B parameter table to %s\n', paramFile);
printMetrics(finalMetrics);

results = struct();
results.parameters = paramTable;
results.diagnostic = finalDiag;
results.prior_replay = finalPriorReplay;
results.metrics = finalMetrics;
results.score = bestScore;
end

function opts = humidityOptions()
opts.stopTimeShort_s = 120;
opts.stopTimeLong_s = 300;
opts.coordinatePasses = 2;
opts.finalRun.adaptiveSteady = true;
opts.finalRun.verbose = false;
opts.maxTStackIncrease_C = 0.5;
opts.maxVCellIncrease_V = 0.03;
opts.maxQCoolIncrease_W = 1200.0;
opts.lambdaMin = 1.2;
opts.weight_pH2O = 1.0;
opts.weight_xH2O = 0.7;
opts.weight_RH = 0.2;
opts.weight_prior_dry = 0.35;
opts.weight_prior_wet = 0.15;
opts.weight_prior_trans = 0.15;
opts.pressurePenalty = 12.0;
opts.guardPenalty = 8.0;
end

function spec = parameterSpec(P0)
spec = [
    makeSpec("hum_NTU_ref", P0.hum_NTU_ref, 0.15, 1.50, "1", "B", "humidifier transfer intensity reference")
    makeSpec("hum_flow_exp", P0.hum_flow_exp, 0.00, 1.20, "1", "B", "humidifier transfer flow exponent")
    makeSpec("hum_mem_D_eff_m2_s", P0.hum_mem_D_eff_m2_s, 1.0e-11, 1.0e-8, "m2/s", "B", "humidifier membrane effective diffusion")
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

function P = applyParams(P, x, spec)
for k = 1:numel(spec)
    P.(spec(k).name) = min(max(x(k), spec(k).lb), spec(k).ub);
end
end

function candidates = coordinateCandidates(x, spec, idx)
candidates = [];
base = x(idx);
if contains(spec(idx).name, "D_eff")
    factors = [0.25, 0.50, 0.75, 1.25, 1.75, 2.50, 4.00];
elseif contains(spec(idx).name, "flow_exp")
    factors = [0.50, 0.75, 1.20, 1.50, 1.80];
else
    factors = [0.50, 0.75, 0.90, 1.10, 1.25, 1.50, 2.00];
end
for k = 1:numel(factors)
    xt = x;
    xt(idx) = min(max(base * factors(k), spec(idx).lb), spec(idx).ub);
    candidates = [candidates; xt]; %#ok<AGROW>
end
end

function [M, R, Rprior] = evaluateCandidate(x, P0, D, H, spec, model, opts)
P = applyParams(P0, x, spec);
P = rebuildModuleParamsLocal(P);
R = runBenchDataset(P, D, model, opts.finalRun);
Rprior = runHumidifierPriorReplay(P, H);
M = metricSummary(R, Rprior);
end

function score = scoreCandidate(M, Mbase, opts)
score = opts.weight_pH2O * ratioMetric(M.pH2O_caIn_RMSE_kPa, Mbase.pH2O_caIn_RMSE_kPa) ...
    + opts.weight_xH2O * ratioMetric(M.xH2O_caIn_RMSE, Mbase.xH2O_caIn_RMSE) ...
    + opts.weight_RH * ratioMetric(M.RH_ca_in_RMSE, Mbase.RH_ca_in_RMSE) ...
    + opts.weight_prior_dry * ratioMetric(M.prior_dry_omega_RMSE_gpkg, Mbase.prior_dry_omega_RMSE_gpkg) ...
    + opts.weight_prior_wet * ratioMetric(M.prior_wet_omega_RMSE_gpkg, Mbase.prior_wet_omega_RMSE_gpkg) ...
    + opts.weight_prior_trans * ratioMetric(M.prior_trans_RMSE_g_s, Mbase.prior_trans_RMSE_g_s);

score = score + opts.pressurePenalty * max(M.points - M.pressure_order_pass, 0);
if M.min_lambda_O2 < opts.lambdaMin
    score = score + opts.guardPenalty * (opts.lambdaMin - M.min_lambda_O2) / max(opts.lambdaMin, 1e-9);
end
if M.T_stack_RMSE_C > Mbase.T_stack_RMSE_C + opts.maxTStackIncrease_C
    score = score + opts.guardPenalty * (M.T_stack_RMSE_C - (Mbase.T_stack_RMSE_C + opts.maxTStackIncrease_C));
end
if M.V_cell_RMSE > Mbase.V_cell_RMSE + opts.maxVCellIncrease_V
    score = score + opts.guardPenalty * (M.V_cell_RMSE - (Mbase.V_cell_RMSE + opts.maxVCellIncrease_V)) / max(opts.maxVCellIncrease_V, 1e-9);
end
if M.Q_cool_RMSE_W > Mbase.Q_cool_RMSE_W + opts.maxQCoolIncrease_W
    score = score + opts.guardPenalty * (M.Q_cool_RMSE_W - (Mbase.Q_cool_RMSE_W + opts.maxQCoolIncrease_W)) / max(opts.maxQCoolIncrease_W, 1e-9);
end
end

function ok = acceptCandidate(baseM, candM, opts)
ok = candM.pressure_order_pass == candM.points ...
    && candM.min_lambda_O2 >= opts.lambdaMin ...
    && candM.T_stack_RMSE_C <= baseM.T_stack_RMSE_C + opts.maxTStackIncrease_C ...
    && candM.V_cell_RMSE <= baseM.V_cell_RMSE + opts.maxVCellIncrease_V ...
    && candM.Q_cool_RMSE_W <= baseM.Q_cool_RMSE_W + opts.maxQCoolIncrease_W ...
    && candM.pH2O_caIn_RMSE_kPa <= baseM.pH2O_caIn_RMSE_kPa;
end

function y = ratioMetric(value, reference)
ref = max(abs(reference), 1e-6);
y = value / ref;
end

function T = metricsToTraceRow(label, pass, M, score)
row = struct();
row.label = string(label);
row.pass = pass;
row.score = score;
row.pH2O_caIn_RMSE_kPa = M.pH2O_caIn_RMSE_kPa;
row.xH2O_caIn_RMSE = M.xH2O_caIn_RMSE;
row.RH_ca_in_RMSE = M.RH_ca_in_RMSE;
row.prior_dry_omega_RMSE_gpkg = M.prior_dry_omega_RMSE_gpkg;
row.prior_wet_omega_RMSE_gpkg = M.prior_wet_omega_RMSE_gpkg;
row.prior_trans_RMSE_g_s = M.prior_trans_RMSE_g_s;
row.T_stack_RMSE_C = M.T_stack_RMSE_C;
row.V_cell_RMSE = M.V_cell_RMSE;
row.pressure_order_pass = M.pressure_order_pass;
T = struct2table(row);
end

function R = runBenchDataset(Pbase, D, model, runOpts)
rows = cell(height(D), 1);
for k = 1:height(D)
    P = configureBenchCase(Pbase, D(k, :));
    rows{k} = runCase(P, D(k, :), model, runOpts);
end
R = vertcat(rows{:});
end

function P = configureBenchCase(P, row)
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
parsed.pH2O_caIn_meas_kPa = dataRow.pH2O_caIn_kPa;
parsed.pH2O_caIn_sim_kPa = dry.pH2O_kPa;
parsed.pH2O_caIn_err_kPa = parsed.pH2O_caIn_sim_kPa - parsed.pH2O_caIn_meas_kPa;
parsed.xH2O_caIn_meas = dataRow.xH2O_caIn;
parsed.xH2O_caIn_sim = dry.xH2O;
parsed.xH2O_caIn_err = parsed.xH2O_caIn_sim - parsed.xH2O_caIn_meas;
parsed.RH_ca_in_meas = dataRow.cathode_RH;
parsed.RH_ca_in_sim = sNow.RH_ca_in;
parsed.RH_ca_in_err = parsed.RH_ca_in_sim - parsed.RH_ca_in_meas;
parsed.omega_ca_in_meas_kgpkg = dryOmegaFromRow(dataRow);
parsed.omega_ca_in_sim_kgpkg = dry.omega_kgpkg;
parsed.omega_ca_in_err_kgpkg = parsed.omega_ca_in_sim_kgpkg - parsed.omega_ca_in_meas_kgpkg;
parsed.T_stack_meas_C = dataRow.stack_temperature_est_C;
parsed.T_stack_sim_C = sNow.T_stack_C;
parsed.T_stack_err_C = parsed.T_stack_sim_C - parsed.T_stack_meas_C;
parsed.V_cell_meas = dataRow.cell_voltage_from_stack_V;
parsed.V_cell_sim = sNow.V_cell;
parsed.V_cell_err = parsed.V_cell_sim - parsed.V_cell_meas;
parsed.Q_cool_sim_W = sNow.Q_cool_W;
parsed.Q_cool_bench_W = benchQCool(dataRow, P);
parsed.Q_cool_err_W = parsed.Q_cool_sim_W - parsed.Q_cool_bench_W;
parsed.p_ca_in_meas_kPa = dataRow.cathode_pressure_kPa_abs;
parsed.p_ca_in_sim_kPa = dry.p_kPa;
parsed.p_stack_internal_kPa = sNow.pCa_kPa;
parsed.p_ca_out_boundary_kPa = P.p_cathode_back_kPa;
parsed.pressure_order_ok = parsed.p_ca_in_sim_kPa > parsed.p_stack_internal_kPa && parsed.p_stack_internal_kPa > parsed.p_ca_out_boundary_kPa;
parsed.lambda_O2_actual = sNow.lambda_O2_actual;
parsed.hum_transfer_sim_kg_s = sNow.mH2O_hum_transfer_kg_s;
parsed.RH_hum_dry_out = sNow.RH_hum_dry_out;
parsed.RH_hum_wet_out = sNow.RH_hum_wet_out;
parsed.model_name = string(model);
end

function q = benchQCool(dataRow, P)
q = P.coolant_rho_kg_L * P.coolant_cp_J_kgK * (dataRow.coolant_flow_L_min / 60.0) ...
    * (dataRow.coolant_outlet_temp_C - dataRow.coolant_inlet_temp_C);
end

function omega = dryOmegaFromRow(row)
omega = row.xH2O_caIn / max(1 - row.xH2O_caIn, 1e-9) * (0.01801528 / (0.2095 * 0.031998 + 0.7905 * 0.0280134));
end

function R = runHumidifierPriorReplay(P, H)
rows = cell(height(H), 1);
massFrac = dryAirMassFractions(P);
for k = 1:height(H)
    rows{k} = priorReplayRow(P, H(k, :), massFrac);
end
R = vertcat(rows{:});
end

function T = priorReplayRow(P, row, massFrac)
[dryIn, wetIn] = buildHumidifierPriorNodes(row, massFrac);
[dryOut, wetOut, humSummary] = replayHumidifierBlock(dryIn, wetIn, P.HumidifierParam);
dryState = nodeStruct(dryOut, P);
wetState = nodeStruct(wetOut, P);
useLevel = string(row.calibration_use_level);
rowOut = struct();
rowOut.model = string(row.model);
rowOut.flow_slpm = row.flow_slpm;
rowOut.use_level = useLevel;
rowOut.dry_out_omega_meas_kgpkg = row.dry_out_omega_kgpkg;
rowOut.dry_out_omega_sim_kgpkg = dryState.omega_kgpkg;
rowOut.dry_out_omega_err_kgpkg = rowOut.dry_out_omega_sim_kgpkg - rowOut.dry_out_omega_meas_kgpkg;
rowOut.dry_out_pH2O_meas_kPa = row.dry_out_p_H2O_kPa;
rowOut.dry_out_pH2O_sim_kPa = dryState.pH2O_kPa;
rowOut.dry_out_pH2O_err_kPa = rowOut.dry_out_pH2O_sim_kPa - rowOut.dry_out_pH2O_meas_kPa;
rowOut.wet_out_omega_meas_kgpkg = row.wet_out_omega_kgpkg;
rowOut.wet_out_omega_sim_kgpkg = wetState.omega_kgpkg;
rowOut.wet_out_omega_err_kgpkg = rowOut.wet_out_omega_sim_kgpkg - rowOut.wet_out_omega_meas_kgpkg;
rowOut.wet_out_pH2O_meas_kPa = row.wet_out_p_H2O_kPa;
rowOut.wet_out_pH2O_sim_kPa = wetState.pH2O_kPa;
rowOut.wet_out_pH2O_err_kPa = rowOut.wet_out_pH2O_sim_kPa - rowOut.wet_out_pH2O_meas_kPa;
rowOut.water_transfer_meas_kg_s = row.water_transfer_meas_kg_s;
rowOut.water_transfer_sim_kg_s = humSummary(1);
rowOut.water_transfer_err_kg_s = rowOut.water_transfer_sim_kg_s - rowOut.water_transfer_meas_kg_s;
rowOut.dry_side_gain_meas_g_s = row.dry_side_gain_g_s;
rowOut.dry_side_gain_sim_g_s = 1000 * max(dryOut(3) - dryIn(3), 0);
rowOut.dry_side_gain_err_g_s = rowOut.dry_side_gain_sim_g_s - rowOut.dry_side_gain_meas_g_s;
rowOut.wet_side_loss_meas_g_s = row.wet_side_loss_g_s;
rowOut.wet_side_loss_sim_g_s = 1000 * max(wetIn(3) - wetOut(3), 0);
rowOut.wet_side_loss_err_g_s = rowOut.wet_side_loss_sim_g_s - rowOut.wet_side_loss_meas_g_s;
T = struct2table(rowOut);
end

function [dryIn, wetIn] = buildHumidifierPriorNodes(row, massFrac)
dryGas = row.dry_air_mass_flow_kg_s;
wetDryGas = row.wet_dry_gas_equiv_mass_flow_kg_s;
dryIn = [
    dryGas * massFrac(1)
    dryGas * massFrac(2)
    row.dry_in_H2O_vapor_kg_s
    0
    row.dry_in_T_C
    row.dry_in_p_kPa_abs
    0
    ];
wetIn = [
    wetDryGas * massFrac(1)
    wetDryGas * massFrac(2)
    row.wet_in_H2O_vapor_kg_s
    0
    row.wet_in_T_C
    row.wet_in_p_kPa_abs
    0
    ];
end

function mf = dryAirMassFractions(P)
n = [P.xO2_dry, P.xN2_dry];
m = [n(1) * P.M_O2_kg_mol, n(2) * P.M_N2_kg_mol];
mf = m / sum(m);
end

function [dryOut, wetOut, humSummary] = replayHumidifierBlock(dryIn, wetIn, hum)
M_O2=hum(1); M_N2=hum(2); M_H2O=hum(3); pamb=hum(4); NTUref=max(hum(6),1e-3); mRef=max(hum(7),1e-9); flowExp=hum(8);
A=hum(13); delta=max(hum(14),1e-9); Deff=max(hum(15),1e-12); betaW=max(hum(16),1e-6); betaD=max(hum(17),1e-6); UA=max(hum(18),0);
mDry=max(sum(dryIn(1:4)),1e-9); mWet=max(sum(wetIn(1:4)),1e-9);
pD=vapor_p(dryIn,M_O2,M_N2,M_H2O); pW=vapor_p(wetIn,M_O2,M_N2,M_H2O);
Rtot=1/betaW+delta/Deff+1/betaD;
j=max((pW-pD)*1000,0)/(8.314462618*max(dryIn(5)+273.15,250)*Rtot);
NTUgain=min(max(NTUref*(mRef/max(mDry,1e-9))^flowExp,0.05),5.0);
mTransRaw=j*A*M_H2O; mTransRaw=NTUgain*mTransRaw;
dryNeed=max(vapor_sat_mass(dryIn(1),dryIn(2),dryIn(5),dryIn(6),hum)-dryIn(3),0);
wetAvail=max(wetIn(3),0);
mTrans=min([mTransRaw,dryNeed,wetAvail]);
Cmin=max(min(mDry,mWet)*1050,1e-6); epsH=min(max(1-exp(-UA/Cmin),0),0.85); dTDry=min(max(epsH*(wetIn(5)-dryIn(5))*Cmin/(mDry*1050),-30),30);
dryOut=dryIn; dryOut(3)=dryIn(3)+mTrans; dryOut(5)=min(max(dryIn(5)+dTDry,-20),95);
dpDry=hum(10)*(mDry/mRef)^hum(12); dryOut(6)=max(dryIn(6)-dpDry,pamb);
[dryOut(3),dryOut(4)]=clip_vapor(dryOut(3),dryOut(4),dryOut(1),dryOut(2),dryOut(5),dryOut(6),hum); dryOut(7)=double(dryOut(4)>1e-12);
wetOut=wetIn; wetOut(3)=max(wetIn(3)-mTrans,0); wetOut(5)=min(max(wetIn(5)-dTDry,-20),95);
dpWet=hum(11)*(mWet/mRef)^hum(12); wetOut(6)=max(wetIn(6)-dpWet,pamb);
[wetOut(3),wetOut(4)]=clip_vapor(wetOut(3),wetOut(4),wetOut(1),wetOut(2),wetOut(5),wetOut(6),hum); wetOut(7)=double(wetOut(4)>1e-12);
humSummary=[mTrans; mTransRaw; pW-pD; dTDry; dpDry; dpWet; rel_hum(dryOut,M_O2,M_N2,M_H2O); rel_hum(wetOut,M_O2,M_N2,M_H2O)];
end

function p = vapor_p(node,M_O2,M_N2,M_H2O)
nV=max(node(3)/M_H2O,0); nt=max(node(1)/M_O2+node(2)/M_N2+nV,1e-12); p=node(6)*nV/nt;
end

function rh = rel_hum(node,M_O2,M_N2,M_H2O)
rh=vapor_p(node,M_O2,M_N2,M_H2O)/max(sat_kPa(node(5)),1e-6);
end

function mSat = vapor_sat_mass(mO2,mN2,T,p,hum)
M_O2=hum(1); M_N2=hum(2); M_H2O=hum(3); ps=min(sat_kPa(T),0.98*p); nDry=max(mO2/M_O2+mN2/M_N2,1e-12); mSat=ps*nDry/max(p-ps,1e-6)*M_H2O;
end

function [mv, ml] = clip_vapor(mv0, ml0, mO2, mN2, T, p, hum)
mSat=vapor_sat_mass(mO2,mN2,T,p,hum); if mv0>mSat, mv=mSat; ml=ml0+mv0-mSat; else, mv=mv0; ml=ml0; end
end

function p = sat_kPa(T)
Tc=min(max(T,-40),120); p=0.61121*exp((18.678-Tc/234.5)*(Tc/(257.14+Tc)));
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

function M = metricSummary(R, Rprior)
dualWet = strcmp(string(Rprior.use_level), "dual_side_fit_candidate");
M = struct();
M.points = height(R);
M.steady_points = nnz(R.is_steady);
M.pressure_order_pass = nnz(R.pressure_order_ok);
M.pH2O_caIn_RMSE_kPa = rmsLocal(R.pH2O_caIn_err_kPa);
M.xH2O_caIn_RMSE = rmsLocal(R.xH2O_caIn_err);
M.RH_ca_in_RMSE = rmsLocal(R.RH_ca_in_err);
M.omega_ca_in_RMSE_kgpkg = rmsLocal(R.omega_ca_in_err_kgpkg);
M.T_stack_RMSE_C = rmsLocal(R.T_stack_err_C);
M.V_cell_RMSE = rmsLocal(R.V_cell_err);
M.Q_cool_RMSE_W = rmsLocal(R.Q_cool_err_W);
M.min_lambda_O2 = min(R.lambda_O2_actual);
M.prior_dry_omega_RMSE_gpkg = 1000 * rmsLocal(Rprior.dry_out_omega_err_kgpkg);
M.prior_wet_omega_RMSE_gpkg = 1000 * rmsLocal(Rprior.wet_out_omega_err_kgpkg(dualWet));
M.prior_trans_RMSE_g_s = 1000 * rmsLocal(Rprior.water_transfer_err_kg_s);
end

function printMetrics(M)
fprintf('pH2O_caIn RMSE = %.3f kPa, xH2O RMSE = %.5f, RH RMSE = %.3f\n', ...
    M.pH2O_caIn_RMSE_kPa, M.xH2O_caIn_RMSE, M.RH_ca_in_RMSE);
fprintf('Prior dry/wet omega RMSE = %.2f / %.2f g/kg, transfer RMSE = %.2f g/s\n', ...
    M.prior_dry_omega_RMSE_gpkg, M.prior_wet_omega_RMSE_gpkg, M.prior_trans_RMSE_g_s);
fprintf('T_stack RMSE = %.3f C, V_cell RMSE = %.4f V/cell, pressure-order pass = %d/%d\n', ...
    M.T_stack_RMSE_C, M.V_cell_RMSE, M.pressure_order_pass, M.points);
end

function T = buildParamTable(P0, Pbest, spec, accepted)
rows = cell(numel(spec), 5);
for k = 1:numel(spec)
    rows{k, 1} = spec(k).name;
    rows{k, 2} = Pbest.(spec(k).name);
    rows{k, 3} = P0.(spec(k).name);
    rows{k, 4} = double(accepted);
    rows{k, 5} = spec(k).note;
end
T = cell2table(rows, 'VariableNames', {'parameter', 'value', 'initial_value', 'accepted', 'note'});
end

function writeSummary(path, ~, baseM, candM, accepted, paramTable, opts)
lines = [
    "# Humidity Stage-B Summary"
    ""
    "Date: " + string(datetime('now', 'Format', 'yyyy-MM-dd'))
    ""
    "## Scope"
    ""
    "- Executable model: `01_模型/CEGR_Vehicle_10kW_GZS60_v03_stage1_pressurefix.slx`."
    "- Stage B uses the pressurefix + thermal Stage-A baseline."
    "- Main fitting targets are stack-inlet `pH2O_caIn_kPa` and `xH2O_caIn` under 13 no-EGR steady points."
    "- Humidifier four-port data are used as secondary prior constraints, not equal-weight primary targets."
    "- First-round free parameters are `hum_NTU_ref`, `hum_flow_exp`, and `hum_mem_D_eff_m2_s`."
    ""
    "## Base Metrics"
    ""
    sprintf("- Base pH2O_caIn RMSE: %.3f kPa.", baseM.pH2O_caIn_RMSE_kPa)
    sprintf("- Base xH2O_caIn RMSE: %.5f.", baseM.xH2O_caIn_RMSE)
    sprintf("- Base RH_ca_in RMSE: %.3f.", baseM.RH_ca_in_RMSE)
    sprintf("- Base prior dry/wet omega RMSE: %.2f / %.2f g/kg.", baseM.prior_dry_omega_RMSE_gpkg, baseM.prior_wet_omega_RMSE_gpkg)
    ""
    "## Candidate Metrics"
    ""
    sprintf("- Candidate accepted: %s.", string(accepted))
    sprintf("- Candidate pH2O_caIn RMSE: %.3f kPa.", candM.pH2O_caIn_RMSE_kPa)
    sprintf("- Candidate xH2O_caIn RMSE: %.5f.", candM.xH2O_caIn_RMSE)
    sprintf("- Candidate RH_ca_in RMSE: %.3f.", candM.RH_ca_in_RMSE)
    sprintf("- Candidate prior dry/wet omega RMSE: %.2f / %.2f g/kg.", candM.prior_dry_omega_RMSE_gpkg, candM.prior_wet_omega_RMSE_gpkg)
    sprintf("- Candidate transfer RMSE: %.2f g/s.", candM.prior_trans_RMSE_g_s)
    sprintf("- Candidate T_stack RMSE: %.3f C.", candM.T_stack_RMSE_C)
    sprintf("- Candidate V_cell RMSE: %.4f V/cell.", candM.V_cell_RMSE)
    sprintf("- Candidate pressure-order pass: %d/%d.", candM.pressure_order_pass, candM.points)
    ""
    "## Acceptance Guards"
    ""
    sprintf("- T_stack allowed increase: %.3f C.", opts.maxTStackIncrease_C)
    sprintf("- V_cell allowed increase: %.3f V/cell.", opts.maxVCellIncrease_V)
    sprintf("- Q_cool allowed increase: %.1f W.", opts.maxQCoolIncrease_W)
    ""
    "## Output Files"
    ""
    "- `04_验证结果/humidity_stageB_no_egr_diagnostic.csv`"
    "- `04_验证结果/humidity_stageB_hum_prior_replay.csv`"
    "- `04_验证结果/humidity_stageB_candidate_trace.csv`"
    "- `00_输入参数/标定参数/humidity_stageB_params.csv`"
    ""
    "## Parameters"
    ""
    parameterLines(paramTable)
    ];
writeText(path, flattenLines(lines));
end

function lines = parameterLines(T)
lines = strings(height(T), 1);
for k = 1:height(T)
    lines(k) = sprintf("- `%s = %.6g` (initial %.6g).", T.parameter{k}, T.value(k), T.initial_value(k));
end
end

function out = flattenLines(lines)
out = strings(0, 1);
for k = 1:numel(lines)
    if isstring(lines(k)) || ischar(lines(k))
        out(end+1, 1) = string(lines(k)); %#ok<AGROW>
    else
        part = string(lines{k});
        out = [out; part(:)]; %#ok<AGROW>
    end
end
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
n.xH2O = calcXH2O(v, P);
n.pH2O_kPa = calcPH2O(v, P);
n.RH = calcRH(v, P);
n.omega_kgpkg = calcOmega(v);
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
nTot = totalMoles(v, P);
xO2 = (v(1) / P.M_O2_kg_mol) / nTot;
end

function xH2O = calcXH2O(v, P)
nTot = totalMoles(v, P);
xH2O = (v(3) / P.M_H2O_kg_mol) / nTot;
end

function pH2O = calcPH2O(v, P)
pH2O = v(6) * calcXH2O(v, P);
end

function RH = calcRH(v, P)
RH = calcPH2O(v, P) / max(saturationPressureKPa(v(5)), 1e-6);
end

function omega = calcOmega(v)
dryGas = max(v(1) + v(2), 1e-12);
omega = v(3) / dryGas;
end

function nTot = totalMoles(v, P)
nTot = max(v(1) / P.M_O2_kg_mol + v(2) / P.M_N2_kg_mol + v(3) / P.M_H2O_kg_mol, 1e-12);
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
