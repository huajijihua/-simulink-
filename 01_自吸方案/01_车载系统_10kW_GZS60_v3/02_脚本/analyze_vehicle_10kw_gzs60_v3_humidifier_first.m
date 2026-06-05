function results = analyze_vehicle_10kw_gzs60_v3_humidifier_first()
%ANALYZE_VEHICLE_10KW_GZS60_V3_HUMIDIFIER_FIRST
% Reorders the no-EGR baseline review around the vehicle humidifier.
%
% The bench stack-inlet humidity is treated as a free bench boundary. In the
% vehicle model, the stack cathode inlet humidity must come from the GZS
% membrane humidifier dry outlet.

P0 = init_vehicle_10kw_gzs60_v3("current");
P0 = rebuildModuleParamsLocal(P0);
PstageA = init_vehicle_10kw_gzs60_v3("stageA");
PstageA = rebuildModuleParamsLocal(PstageA);

rootDir = P0.rootDir;
benchFile = fullfile(rootDir, '00_输入参数', '全电流段极化标定', 'full_range_polarization_data.csv');
priorFile = fullfile(rootDir, '00_输入参数', '旧版提炼', 'GZS通用化数据与参数反演', 'gzs_humidifier_standard_four_port_dataset.csv');
gzsParamFile = fullfile(rootDir, '00_输入参数', '加湿器_GZS60', 'GZS60车载模型参数_v02.csv');
voltageFitFile = fullfile(rootDir, '00_输入参数', '电堆物理模型', 'stack_voltage_book_fit_params_stage2.csv');
outDir = fullfile(rootDir, '04_验证结果');
docDir = fullfile(rootDir, '03_说明');

model = P0.modelName;
modelFile = P0.modelFile;

if ~isfile(benchFile)
    error('Missing bench data: %s', benchFile);
end
if ~isfile(priorFile)
    error('Missing humidifier prior data: %s', priorFile);
end
if ~isfile(modelFile)
    error('Missing Simulink model: %s', modelFile);
end
if ~exist(outDir, 'dir')
    mkdir(outDir);
end
if ~exist(docDir, 'dir')
    mkdir(docDir);
end

fourPortFile = fullfile(outDir, 'humidifier_first_four_port_replay.csv');
specFile = fullfile(outDir, 'humidifier_first_gzs60_spec_check.csv');
systemFile = fullfile(outDir, 'humidifier_first_no_egr_system_diagnostic.csv');
voltageFile = fullfile(outDir, 'humidifier_first_voltage_state_audit.csv');
paramDir = paramDirFromRoot(rootDir);
candidateFile = fullfile(paramDir, 'humidifier_first_params.csv');
appliedParamFile = fullfile(paramDir, 'humidity_stageB_params.csv');
summaryFile = fullfile(outDir, 'humidifier_first_summary.md');
docFile = fullfile(docDir, '无EGR加湿器优先实施记录.md');

B = readtable(benchFile, 'TextType', 'string');
benchMask = logical(B.use_for_fit);
D = B(benchMask, :);

H = readtable(priorFile, 'TextType', 'string');
priorMask = ismember(string(H.calibration_use_level), ["dual_side_fit_candidate", "dry_priority_only"]);
H = H(priorMask, :);

fprintf('Humidifier-first no-EGR review: %d bench points, %d humidifier four-port points.\n', height(D), height(H));

fourPortReplay = runHumidifierPriorReplay(P0, H);
fourPortMetrics = humidifierMetrics(fourPortReplay);

specCheck = runGZS60SpecCheck(P0, gzsParamFile);
specMetrics = specCheckMetrics(specCheck);

candidate = selectHumidifierFirstCandidate(P0, PstageA, H, gzsParamFile);
candidateMetrics = candidate.metrics;
candidateParams = buildHumidifierFirstParamTable(P0, candidate.P, candidate.label);

open_system(modelFile);
runOpts = struct('adaptiveSteady', true);
systemDiag = runBenchDataset(P0, D, model, runOpts);
systemMetrics = systemMetricSummary(systemDiag);

voltageAudit = buildVoltageAudit(systemDiag);
voltageMetrics = voltageMetricSummary(voltageAudit);
voltageFitInfo = readVoltageFitInfo(voltageFitFile);

writetable(fourPortReplay, fourPortFile);
writetable(specCheck, specFile);
writetable(candidateParams, candidateFile);
writetable(candidateParams, appliedParamFile);
writetable(systemDiag, systemFile);
writetable(voltageAudit, voltageFile);
writeSummary(summaryFile, fourPortMetrics, specMetrics, candidateMetrics, systemMetrics, voltageMetrics, voltageFitInfo);
writeImplementationDoc(docFile, summaryFile);

fprintf('Wrote humidifier four-port replay to %s\n', fourPortFile);
fprintf('Wrote GZS60 spec check to %s\n', specFile);
fprintf('Wrote humidifier-first candidate params to %s\n', candidateFile);
fprintf('Applied humidifier-first params to %s\n', appliedParamFile);
fprintf('Wrote no-EGR system diagnostic to %s\n', systemFile);
fprintf('Wrote voltage state audit to %s\n', voltageFile);
fprintf('Wrote humidifier-first summary to %s\n', summaryFile);

results = struct();
results.four_port = fourPortReplay;
results.spec_check = specCheck;
results.candidate_params = candidateParams;
results.system_diagnostic = systemDiag;
results.voltage_audit = voltageAudit;
results.four_port_metrics = fourPortMetrics;
results.spec_metrics = specMetrics;
results.candidate_metrics = candidateMetrics;
results.system_metrics = systemMetrics;
results.voltage_metrics = voltageMetrics;
end

function R = runHumidifierPriorReplay(P, H)
rows = cell(height(H), 1);
massFrac = dryAirMassFractions(P);
for k = 1:height(H)
    rows{k} = fourPortReplayRow(P, H(k, :), massFrac);
end
R = vertcat(rows{:});
end

function T = fourPortReplayRow(P, row, massFrac)
[dryIn, wetIn] = buildHumidifierPriorNodes(row, massFrac);
[dryOut, wetOut, humSummary] = replayHumidifierBlock(dryIn, wetIn, P.HumidifierParam);
dryState = nodeStruct(dryOut, P);
wetState = nodeStruct(wetOut, P);

rowOut = struct();
rowOut.model = string(row.model);
rowOut.flow_slpm = row.flow_slpm;
rowOut.use_level = string(row.calibration_use_level);
rowOut.quality_label = string(row.quality_label);
rowOut.dry_gain_direction_ok = dryOut(3) >= dryIn(3);
rowOut.wet_loss_direction_ok = wetOut(3) <= wetIn(3);
rowOut.transfer_limited_by_need_or_supply = humSummary(1) <= humSummary(2) + 1e-12;
rowOut.dry_out_omega_meas_kgpkg = row.dry_out_omega_kgpkg;
rowOut.dry_out_omega_sim_kgpkg = dryState.omega_kgpkg;
rowOut.dry_out_omega_err_kgpkg = rowOut.dry_out_omega_sim_kgpkg - rowOut.dry_out_omega_meas_kgpkg;
rowOut.dry_out_RH_meas = row.dry_out_RH;
rowOut.dry_out_RH_sim = dryState.RH;
rowOut.dry_out_RH_err = rowOut.dry_out_RH_sim - rowOut.dry_out_RH_meas;
rowOut.dry_out_dewpoint_meas_C = row.dry_out_dewpoint_C;
rowOut.dry_out_dewpoint_sim_C = dewPointC(dryState.pH2O_kPa);
rowOut.dry_out_dewpoint_err_C = rowOut.dry_out_dewpoint_sim_C - rowOut.dry_out_dewpoint_meas_C;
rowOut.wet_out_omega_meas_kgpkg = row.wet_out_omega_kgpkg;
rowOut.wet_out_omega_sim_kgpkg = wetState.omega_kgpkg;
rowOut.wet_out_omega_err_kgpkg = rowOut.wet_out_omega_sim_kgpkg - rowOut.wet_out_omega_meas_kgpkg;
rowOut.wet_out_RH_meas = row.wet_out_RH;
rowOut.wet_out_RH_sim = wetState.RH;
rowOut.wet_out_RH_err = rowOut.wet_out_RH_sim - rowOut.wet_out_RH_meas;
rowOut.wet_out_dewpoint_meas_C = row.wet_out_dewpoint_C;
rowOut.wet_out_dewpoint_sim_C = dewPointC(wetState.pH2O_kPa);
rowOut.wet_out_dewpoint_err_C = rowOut.wet_out_dewpoint_sim_C - rowOut.wet_out_dewpoint_meas_C;
rowOut.water_transfer_meas_kg_s = row.water_transfer_meas_kg_s;
rowOut.water_transfer_sim_kg_s = humSummary(1);
rowOut.water_transfer_err_kg_s = rowOut.water_transfer_sim_kg_s - rowOut.water_transfer_meas_kg_s;
rowOut.dry_side_gain_meas_g_s = row.dry_side_gain_g_s;
rowOut.dry_side_gain_sim_g_s = 1000 * max(dryOut(3) - dryIn(3), 0);
rowOut.wet_side_loss_meas_g_s = row.wet_side_loss_g_s;
rowOut.wet_side_loss_sim_g_s = 1000 * max(wetIn(3) - wetOut(3), 0);
rowOut.dry_dp_meas_kPa = row.dry_dp_kPa;
rowOut.dry_dp_sim_kPa = humSummary(5);
rowOut.dry_dp_err_kPa = rowOut.dry_dp_sim_kPa - rowOut.dry_dp_meas_kPa;
rowOut.wet_dp_meas_kPa = row.wet_dp_kPa;
rowOut.wet_dp_sim_kPa = humSummary(6);
rowOut.wet_dp_err_kPa = rowOut.wet_dp_sim_kPa - rowOut.wet_dp_meas_kPa;
rowOut.dry_sensible_heat_W = sensibleHeat(dryIn, dryOut);
rowOut.wet_sensible_heat_W = sensibleHeat(wetIn, wetOut);
rowOut.latent_heat_W = humSummary(1) * 2.43e6;
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

function T = runGZS60SpecCheck(P, gzsParamFile)
if isfile(gzsParamFile)
    G = readtable(gzsParamFile, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    refFlow = numericOrDefault(G.refFlow_slpm(1), 5000);
    dewSpec = numericOrDefault(G.dry_out_dewpoint_spec_C_at_ref(1), 59.81);
    dryDpSpec = numericOrDefault(G.dryDpSpec_kPa_at_ref(1), 13);
    wetDpSpec = numericOrDefault(G.wetDpSpec_kPa_at_ref(1), 20);
else
    refFlow = 5000;
    dewSpec = 59.81;
    dryDpSpec = 13;
    wetDpSpec = 20;
end

dryGas = refFlow / 60000 * 1.18;
massFrac = dryAirMassFractions(P);
pAbs = P.p_amb_kPa + 80;
dryIn = makeAirNode(P, dryGas, massFrac, 80, 0.10, pAbs);
wetIn = makeAirNode(P, dryGas, massFrac, 80, 0.95, pAbs);
[dryOut, wetOut, humSummary] = replayHumidifierBlock(dryIn, wetIn, P.HumidifierParam);
dryState = nodeStruct(dryOut, P);
wetState = nodeStruct(wetOut, P);

row = struct();
row.model = "GZS60";
row.flow_slpm = refFlow;
row.dry_in_T_C = dryIn(5);
row.dry_in_RH = calcRH(dryIn, P);
row.wet_in_T_C = wetIn(5);
row.wet_in_RH = calcRH(wetIn, P);
row.dry_out_T_C = dryOut(5);
row.dry_out_RH = dryState.RH;
row.dry_out_dewpoint_sim_C = dewPointC(dryState.pH2O_kPa);
row.dry_out_dewpoint_spec_C = dewSpec;
row.dry_dewpoint_spec_ok = row.dry_out_dewpoint_sim_C >= dewSpec;
row.dry_dp_sim_kPa = humSummary(5);
row.dry_dp_spec_kPa = dryDpSpec;
row.dry_dp_spec_ok = row.dry_dp_sim_kPa <= dryDpSpec;
row.wet_out_T_C = wetOut(5);
row.wet_out_RH = wetState.RH;
row.wet_dp_sim_kPa = humSummary(6);
row.wet_dp_spec_kPa = wetDpSpec;
row.wet_dp_spec_ok = row.wet_dp_sim_kPa <= wetDpSpec;
row.water_transfer_sim_kg_s = humSummary(1);
row.dry_gain_direction_ok = dryOut(3) >= dryIn(3);
row.wet_loss_direction_ok = wetOut(3) <= wetIn(3);
row.vehicle_oversized_note = "GZS60 manual range is 40-70 kW; 10 kW use is an oversized provisional boundary.";
T = struct2table(row);
end

function candidate = selectHumidifierFirstCandidate(Pcurrent, PstageA, H, gzsParamFile)
candidates = [
    makeCandidate("current_stageB", Pcurrent, H, gzsParamFile)
    makeCandidate("stageA_gzs60_prior", PstageA, H, gzsParamFile)
    ];
score = zeros(numel(candidates), 1);
for k = 1:numel(candidates)
    M = candidates(k).metrics;
    score(k) = 1000 * double(~M.spec.dry_dewpoint_spec_ok) ...
        + 100 * double(~M.spec.dry_dp_spec_ok) ...
        + 100 * double(~M.spec.wet_dp_spec_ok) ...
        + M.four_port.dry_out_dewpoint_RMSE_C ...
        + 0.02 * M.four_port.dry_out_omega_RMSE_gpkg ...
        + 0.01 * M.four_port.water_transfer_RMSE_g_s;
end
[~, idx] = min(score);
candidate = candidates(idx);
candidate.score = score(idx);
end

function c = makeCandidate(label, P, H, gzsParamFile)
R = runHumidifierPriorReplay(P, H);
S = runGZS60SpecCheck(P, gzsParamFile);
c = struct();
c.label = string(label);
c.P = P;
c.metrics = struct();
c.metrics.label = string(label);
c.metrics.four_port = humidifierMetrics(R);
c.metrics.spec = specCheckMetrics(S);
end

function T = buildHumidifierFirstParamTable(Pold, Pnew, label)
names = [
    "hum_NTU_ref"
    "hum_flow_exp"
    "hum_mem_D_eff_m2_s"
    "hum_beta_dry_m_s"
    "hum_beta_wet_m_s"
    "hum_UA_W_K"
    "hum_heat_eff"
    "hum_dry_dp_ref_kPa"
    "hum_wet_dp_ref_kPa"
    "hum_dp_exp"
    ];
rows = cell(numel(names), 6);
for k = 1:numel(names)
    name = names(k);
    rows{k, 1} = char(name);
    rows{k, 2} = Pnew.(name);
    rows{k, 3} = Pold.(name);
    rows{k, 4} = char(label);
    rows{k, 5} = double(Pnew.(name) ~= Pold.(name));
    rows{k, 6} = 'humidifier-first baseline applied to current mode through humidity_stageB_params.csv';
end
T = cell2table(rows, 'VariableNames', {'parameter','value','current_value','candidate_source','changed_from_current','note'});
end

function paramDir = paramDirFromRoot(rootDir)
paramDir = fullfile(rootDir, '00_输入参数', '标定参数');
if ~exist(paramDir, 'dir')
    mkdir(paramDir);
end
end

function node = makeAirNode(P, dryGas, massFrac, T_C, RH, p_kPa)
pws = saturationPressureKPa(T_C);
pH2O = min(max(RH, 0) * pws, 0.98 * p_kPa);
nDry = dryGas * massFrac(1) / P.M_O2_kg_mol + dryGas * massFrac(2) / P.M_N2_kg_mol;
mH2O = pH2O * nDry / max(p_kPa - pH2O, 1e-6) * P.M_H2O_kg_mol;
node = [
    dryGas * massFrac(1)
    dryGas * massFrac(2)
    mH2O
    0
    T_C
    p_kPa
    0
    ];
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
end

function in = setModelVars(in, model, P, stopTime)
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
wet = nodeStruct(vectorAt(out.humidifier_wet_node, 7, "final"), P);
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
parsed.vehicle_boundary_note = "humidifier dry outlet drives stack cathode inlet; bench inlet humidity is comparison only";
parsed.pH2O_caIn_bench_kPa = dataRow.pH2O_caIn_kPa;
parsed.pH2O_caIn_vehicle_kPa = dry.pH2O_kPa;
parsed.pH2O_caIn_vehicle_minus_bench_kPa = parsed.pH2O_caIn_vehicle_kPa - parsed.pH2O_caIn_bench_kPa;
parsed.xH2O_caIn_bench = dataRow.xH2O_caIn;
parsed.xH2O_caIn_vehicle = dry.xH2O;
parsed.xH2O_caIn_vehicle_minus_bench = parsed.xH2O_caIn_vehicle - parsed.xH2O_caIn_bench;
parsed.RH_ca_in_bench = dataRow.cathode_RH;
parsed.RH_ca_in_vehicle = dry.RH;
parsed.RH_ca_in_vehicle_minus_bench = parsed.RH_ca_in_vehicle - parsed.RH_ca_in_bench;
parsed.omega_ca_in_bench_kgpkg = dryOmegaFromRow(dataRow);
parsed.omega_ca_in_vehicle_kgpkg = dry.omega_kgpkg;
parsed.omega_ca_in_vehicle_minus_bench_kgpkg = parsed.omega_ca_in_vehicle_kgpkg - parsed.omega_ca_in_bench_kgpkg;
parsed.T_ca_in_bench_C = dataRow.cathode_inlet_temp_C;
parsed.T_ca_in_vehicle_C = dry.T_C;
parsed.T_stack_meas_C = dataRow.stack_temperature_est_C;
parsed.T_stack_sim_C = sNow.T_stack_C;
parsed.T_stack_err_C = parsed.T_stack_sim_C - parsed.T_stack_meas_C;
parsed.V_cell_meas = dataRow.cell_voltage_from_stack_V;
parsed.V_cell_sim = sNow.V_cell;
parsed.V_cell_err = parsed.V_cell_sim - parsed.V_cell_meas;
parsed.E_rev_V = sNow.E_rev_V;
parsed.eta_act_V = sNow.eta_act_V;
parsed.eta_ohm_V = sNow.eta_ohm_V;
parsed.eta_con_V = sNow.eta_con_V;
parsed.pO2_ca_in_kPa = sNow.pO2_ca_in_kPa;
parsed.lambda_O2_actual = sNow.lambda_O2_actual;
parsed.Q_gen_W = sNow.Q_gen_W;
parsed.Q_cool_W = sNow.Q_cool_W;
parsed.Q_amb_W = sNow.Q_amb_W;
parsed.Q_gas_W = sNow.Q_gas_W;
parsed.Q_cool_bench_W = benchQCool(dataRow, P);
parsed.Q_cool_err_W = parsed.Q_cool_W - parsed.Q_cool_bench_W;
parsed.p_ca_in_sim_kPa = dry.p_kPa;
parsed.p_stack_internal_kPa = sNow.pCa_kPa;
parsed.p_ca_out_boundary_kPa = P.p_cathode_back_kPa;
parsed.pressure_order_ok = parsed.p_ca_in_sim_kPa > parsed.p_stack_internal_kPa && parsed.p_stack_internal_kPa > parsed.p_ca_out_boundary_kPa;
parsed.hum_transfer_sim_kg_s = sNow.mH2O_hum_transfer_kg_s;
parsed.RH_hum_dry_out = sNow.RH_hum_dry_out;
parsed.RH_hum_wet_out = sNow.RH_hum_wet_out;
parsed.hum_wet_out_omega_kgpkg = wet.omega_kgpkg;
parsed.model_name = string(model);
end

function q = benchQCool(dataRow, P)
q = P.coolant_rho_kg_L * P.coolant_cp_J_kgK * (dataRow.coolant_flow_L_min / 60.0) ...
    * (dataRow.coolant_outlet_temp_C - dataRow.coolant_inlet_temp_C);
end

function omega = dryOmegaFromRow(row)
omega = row.xH2O_caIn / max(1 - row.xH2O_caIn, 1e-9) * (0.01801528 / (0.2095 * 0.031998 + 0.7905 * 0.0280134));
end

function T = buildVoltageAudit(R)
T = R(:, {'case_id','current_A','current_density_A_cm2','V_cell_meas','V_cell_sim','V_cell_err', ...
    'E_rev_V','eta_act_V','eta_ohm_V','eta_con_V','pO2_ca_in_kPa','lambda_O2_actual', ...
    'T_stack_sim_C','RH_ca_in_vehicle','pH2O_caIn_vehicle_kPa','xH2O_caIn_vehicle'});
T.voltage_reconstructed_V = T.E_rev_V - T.eta_act_V - T.eta_ohm_V - T.eta_con_V;
T.voltage_reconstruction_error_V = T.voltage_reconstructed_V - T.V_cell_sim;
T.high_current_flag = T.current_density_A_cm2 >= 1.1;
end

function M = humidifierMetrics(R)
dualWet = strcmp(string(R.use_level), "dual_side_fit_candidate");
M = struct();
M.points = height(R);
M.dry_gain_pass = nnz(R.dry_gain_direction_ok);
M.wet_loss_pass = nnz(R.wet_loss_direction_ok);
M.transfer_limit_pass = nnz(R.transfer_limited_by_need_or_supply);
M.dry_out_omega_RMSE_gpkg = 1000 * rmsLocal(R.dry_out_omega_err_kgpkg);
M.wet_out_omega_RMSE_gpkg = 1000 * rmsLocal(R.wet_out_omega_err_kgpkg(dualWet));
M.dry_out_RH_RMSE_pct = 100 * rmsLocal(R.dry_out_RH_err);
M.dry_out_dewpoint_RMSE_C = rmsLocal(R.dry_out_dewpoint_err_C);
M.wet_out_dewpoint_RMSE_C = rmsLocal(R.wet_out_dewpoint_err_C(dualWet));
M.water_transfer_RMSE_g_s = 1000 * rmsLocal(R.water_transfer_err_kg_s);
M.dry_dp_RMSE_kPa = rmsLocal(R.dry_dp_err_kPa);
M.wet_dp_RMSE_kPa = rmsLocal(R.wet_dp_err_kPa);
end

function M = specCheckMetrics(T)
M = struct();
M.dry_dewpoint_spec_ok = logical(T.dry_dewpoint_spec_ok(1));
M.dry_dp_spec_ok = logical(T.dry_dp_spec_ok(1));
M.wet_dp_spec_ok = logical(T.wet_dp_spec_ok(1));
M.dry_out_dewpoint_sim_C = T.dry_out_dewpoint_sim_C(1);
M.dry_out_dewpoint_spec_C = T.dry_out_dewpoint_spec_C(1);
M.dry_dp_sim_kPa = T.dry_dp_sim_kPa(1);
M.dry_dp_spec_kPa = T.dry_dp_spec_kPa(1);
M.wet_dp_sim_kPa = T.wet_dp_sim_kPa(1);
M.wet_dp_spec_kPa = T.wet_dp_spec_kPa(1);
end

function M = systemMetricSummary(R)
M = struct();
M.points = height(R);
M.steady_points = nnz(R.is_steady);
M.pressure_order_pass = nnz(R.pressure_order_ok);
M.T_stack_RMSE_C = rmsLocal(R.T_stack_err_C);
M.V_cell_RMSE = rmsLocal(R.V_cell_err);
M.Q_cool_RMSE_W = rmsLocal(R.Q_cool_err_W);
M.RH_vehicle_vs_bench_RMSE = rmsLocal(R.RH_ca_in_vehicle_minus_bench);
M.pH2O_vehicle_vs_bench_RMSE_kPa = rmsLocal(R.pH2O_caIn_vehicle_minus_bench_kPa);
M.min_lambda_O2 = min(R.lambda_O2_actual);
end

function M = voltageMetricSummary(R)
M = struct();
M.points = height(R);
M.V_cell_RMSE = rmsLocal(R.V_cell_err);
M.V_cell_max_abs = max(abs(R.V_cell_err));
high = logical(R.high_current_flag);
M.high_current_points = nnz(high);
M.high_current_bias = mean(R.V_cell_err(high), 'omitnan');
M.high_current_RMSE = rmsLocal(R.V_cell_err(high));
M.reconstruction_max_abs = max(abs(R.voltage_reconstruction_error_V));
end

function info = readVoltageFitInfo(path)
info = struct('available', false, 'rmse_cell_V', NaN, 'max_abs_error_cell_V', NaN, 'fit_scope', "");
if ~isfile(path)
    return;
end
T = readtable(path, 'TextType', 'string');
if isempty(T)
    return;
end
info.available = true;
info.rmse_cell_V = numericOrDefault(T.rmse_cell_V(1), NaN);
info.max_abs_error_cell_V = numericOrDefault(T.max_abs_error_cell_V(1), NaN);
info.fit_scope = string(T.fit_scope(1));
end

function writeSummary(path, H, S, C, Sys, V, Vfit)
lines = [
    "# Humidifier-First No-EGR Summary"
    ""
    "Date: " + string(datetime('now', 'Format', 'yyyy-MM-dd'))
    ""
    "## Scope"
    ""
    "- Bench stack-inlet humidity is treated as a free bench boundary, not a vehicle humidifier target."
    "- Vehicle stack cathode inlet humidity is the humidifier dry-side outlet."
    "- No EGR cases are run in this review."
    ""
    "## Humidifier Four-Port Replay"
    ""
    sprintf("- Four-port points: %d.", H.points)
    sprintf("- Dry gain direction pass: %d/%d.", H.dry_gain_pass, H.points)
    sprintf("- Wet loss direction pass: %d/%d.", H.wet_loss_pass, H.points)
    sprintf("- Transfer limit pass: %d/%d.", H.transfer_limit_pass, H.points)
    sprintf("- Dry outlet omega RMSE: %.2f g/kg.", H.dry_out_omega_RMSE_gpkg)
    sprintf("- Wet outlet omega RMSE: %.2f g/kg.", H.wet_out_omega_RMSE_gpkg)
    sprintf("- Dry outlet RH RMSE: %.2f pct.", H.dry_out_RH_RMSE_pct)
    sprintf("- Dry outlet dewpoint RMSE: %.2f C.", H.dry_out_dewpoint_RMSE_C)
    sprintf("- Water transfer RMSE: %.2f g/s.", H.water_transfer_RMSE_g_s)
    sprintf("- Dry/wet dp RMSE: %.2f / %.2f kPa.", H.dry_dp_RMSE_kPa, H.wet_dp_RMSE_kPa)
    ""
    "## GZS60 Spec Check"
    ""
    sprintf("- Dry outlet dewpoint: %.2f C, spec %.2f C, pass: %s.", S.dry_out_dewpoint_sim_C, S.dry_out_dewpoint_spec_C, string(S.dry_dewpoint_spec_ok))
    sprintf("- Dry pressure drop: %.2f kPa, spec %.2f kPa, pass: %s.", S.dry_dp_sim_kPa, S.dry_dp_spec_kPa, string(S.dry_dp_spec_ok))
    sprintf("- Wet pressure drop: %.2f kPa, spec %.2f kPa, pass: %s.", S.wet_dp_sim_kPa, S.wet_dp_spec_kPa, string(S.wet_dp_spec_ok))
    ""
    "## Humidifier-First Candidate"
    ""
    sprintf("- Selected candidate source: %s.", C.label)
    sprintf("- Candidate dry outlet dewpoint: %.2f C, spec %.2f C, pass: %s.", C.spec.dry_out_dewpoint_sim_C, C.spec.dry_out_dewpoint_spec_C, string(C.spec.dry_dewpoint_spec_ok))
    sprintf("- Candidate dry outlet omega RMSE: %.2f g/kg.", C.four_port.dry_out_omega_RMSE_gpkg)
    sprintf("- Candidate dry outlet dewpoint RMSE: %.2f C.", C.four_port.dry_out_dewpoint_RMSE_C)
    sprintf("- Candidate water transfer RMSE: %.2f g/s.", C.four_port.water_transfer_RMSE_g_s)
    "- Candidate parameters are applied to `00_输入参数/标定参数/humidity_stageB_params.csv` for `current` mode."
    ""
    "## Vehicle No-EGR System Diagnostic"
    ""
    sprintf("- Points: %d.", Sys.points)
    sprintf("- Steady points: %d/%d.", Sys.steady_points, Sys.points)
    sprintf("- Pressure-order pass: %d/%d.", Sys.pressure_order_pass, Sys.points)
    sprintf("- T_stack RMSE: %.3f C.", Sys.T_stack_RMSE_C)
    sprintf("- V_cell RMSE: %.4f V/cell.", Sys.V_cell_RMSE)
    sprintf("- Q_cool RMSE: %.1f W.", Sys.Q_cool_RMSE_W)
    sprintf("- Vehicle-vs-bench RH RMSE: %.3f.", Sys.RH_vehicle_vs_bench_RMSE)
    sprintf("- Vehicle-vs-bench pH2O RMSE: %.3f kPa.", Sys.pH2O_vehicle_vs_bench_RMSE_kPa)
    sprintf("- Minimum lambda_O2_actual: %.3f.", Sys.min_lambda_O2)
    ""
    "## Voltage State Audit"
    ""
    sprintf("- Current vehicle-state V_cell RMSE: %.4f V/cell.", V.V_cell_RMSE)
    sprintf("- Current vehicle-state V_cell max abs: %.4f V/cell.", V.V_cell_max_abs)
    sprintf("- High-current points: %d.", V.high_current_points)
    sprintf("- High-current V_cell bias: %.4f V/cell.", V.high_current_bias)
    sprintf("- High-current V_cell RMSE: %.4f V/cell.", V.high_current_RMSE)
    sprintf("- Voltage reconstruction max abs error: %.3g V/cell.", V.reconstruction_max_abs)
    sprintf("- Stage2 internal-state fit available: %s.", string(Vfit.available))
    sprintf("- Stage2 internal-state fit RMSE: %.4f V/cell.", Vfit.rmse_cell_V)
    sprintf("- Stage2 internal-state fit scope: %s.", Vfit.fit_scope)
    ""
    "## Decision"
    ""
    "- Keep the humidifier-first order: four-port/spec acceptance -> vehicle stack-inlet boundary -> voltage state audit."
    "- Do not use bench stack-inlet RH as a hard vehicle humidifier target."
    "- Do not start EGR analysis until this no-EGR vehicle boundary is accepted."
    ""
    "## Output Files"
    ""
    "- `04_验证结果/humidifier_first_four_port_replay.csv`"
    "- `04_验证结果/humidifier_first_gzs60_spec_check.csv`"
    "- `00_输入参数/标定参数/humidifier_first_params.csv`"
    "- `00_输入参数/标定参数/humidity_stageB_params.csv`"
    "- `04_验证结果/humidifier_first_no_egr_system_diagnostic.csv`"
    "- `04_验证结果/humidifier_first_voltage_state_audit.csv`"
    ];
writeText(path, lines);
end

function writeImplementationDoc(path, summaryFile)
lines = [
    "# 无 EGR 加湿器优先实施记录"
    ""
    "日期：" + string(datetime('now', 'Format', 'yyyy-MM-dd'))
    ""
    "## 本轮口径"
    ""
    "- 台架堆入口湿度是外部自由控制边界，不作为车载膜加湿器出口硬拟合目标。"
    "- 车载系统的电堆阴极入口湿度由 `HumidifierDryWetLumped` 干侧出口决定。"
    "- 本轮只做无 EGR 加湿器优先诊断，不做 EGR 扫描。"
    "- `humidity_stageB_params.csv` 已改为当前加湿器优先基线参数；旧 Stage B 第一轮视为历史对照。"
    ""
    "## 新增入口"
    ""
    "```text"
    "02_脚本/analyze_vehicle_10kw_gzs60_v3_humidifier_first.m"
    "```"
    ""
    "## 结果摘要"
    ""
    "详见："
    ""
    "```text"
    relativeReportPath(summaryFile)
    "```"
    ];
writeText(path, lines);
end

function p = relativeReportPath(path)
parts = split(string(path), filesep);
idx = find(parts == "04_验证结果", 1);
if isempty(idx)
    p = string(path);
else
    p = strjoin(parts(idx:end), filesep);
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

function mf = dryAirMassFractions(P)
n = [P.xO2_dry, P.xN2_dry];
m = [n(1) * P.M_O2_kg_mol, n(2) * P.M_N2_kg_mol];
mf = m / sum(m);
end

function [dryOut, wetOut, humSummary] = replayHumidifierBlock(dryIn, wetIn, hum)
M_O2=hum(1); M_N2=hum(2); M_H2O=hum(3); pamb=hum(4); NTUref=max(hum(6),1e-3); mRef=max(hum(7),1e-9); flowExp=hum(8);
UA=max(hum(18),0);
mDry=max(sum(dryIn(1:4)),1e-9); mWet=max(sum(wetIn(1:4)),1e-9);
pD=vapor_p(dryIn,M_O2,M_N2,M_H2O); pW=vapor_p(wetIn,M_O2,M_N2,M_H2O);
NTUgain=min(max(NTUref*(mRef/max(mDry,1e-9))^flowExp,0.05),5.0);
epsM=min(max(1-exp(-NTUgain),0),0.995);
dryNeed=max(vapor_sat_mass(dryIn(1),dryIn(2),dryIn(5),dryIn(6),hum)-dryIn(3),0);
wetAvail=max(wetIn(3),0);
mTransRaw=epsM*min(dryNeed,wetAvail);
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

function p = sat_kPa(T)
p = saturationPressureKPa(T);
end

function Tdp = dewPointC(pH2O_kPa)
p = max(pH2O_kPa, 1e-6);
lo = -40;
hi = 120;
for k = 1:60
    mid = 0.5 * (lo + hi);
    if saturationPressureKPa(mid) < p
        lo = mid;
    else
        hi = mid;
    end
end
Tdp = 0.5 * (lo + hi);
end

function q = sensibleHeat(inNode, outNode)
q = sum(outNode(1:3)) * 1050 * (outNode(5) - inNode(5));
end

function y = rmsLocal(x)
x = x(isfinite(x));
if isempty(x)
    y = NaN;
else
    y = sqrt(mean(x .^ 2));
end
end

function y = numericOrDefault(x, defaultValue)
if isnumeric(x)
    y = double(x);
else
    y = str2double(string(x));
end
if ~isfinite(y)
    y = defaultValue;
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
