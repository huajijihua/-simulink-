function results = run_testbench_10kw_v01_constant_current(egrFractions, outFileName)
%RUN_TESTBENCH_10KW_V01_CONSTANT_CURRENT Run 13 bench current points over EGR ratios.
if nargin < 1 || isempty(egrFractions)
    egrFractions = [0 0.1 0.2 0.3 0.4];
end
if nargin < 2 || strlength(string(outFileName)) == 0
    outFileName = 'testbench_constant_current_egr_scan.csv';
end
P0 = init_testbench_10kw_v01(1, 0.0);
if ~exist(P0.resultDir, 'dir')
    mkdir(P0.resultDir);
end
open_system(P0.modelFile);
originalInitFcn = get_param(P0.modelName, 'InitFcn');
cleanupInitFcn = onCleanup(@() set_param(P0.modelName, 'InitFcn', originalInitFcn));
set_param(P0.modelName, 'InitFcn', '');
rows = {};
for caseIndex = 1:13
    for j = 1:numel(egrFractions)
        P = init_testbench_10kw_v01(caseIndex, egrFractions(j));
        assignRunWorkspace(P);
        simOut = sim(P.modelName, 'StopTime', num2str(P.stopTime_s), 'ReturnWorkspaceOutputs', 'on');
        row = extractFinalRow(P, simOut);
        rows{end + 1, 1} = struct2table(row); %#ok<AGROW>
    end
end
results = vertcat(rows{:});
outFile = fullfile(P0.resultDir, char(outFileName));
writetable(results, outFile);
assignin('base', 'testbenchConstantCurrentResults', results);
fprintf('Testbench constant-current EGR scan complete: %s\n', outFile);
end

function assignRunWorkspace(P)
assignin('base', 'P_testbench_v1', P);
assignin('base', 'BenchAirParam_v1', P.BenchAirParam);
assignin('base', 'BenchConditionerParam_v1', P.BenchConditionerParam);
assignin('base', 'CompressorParam_v2', P.CompressorParam);
assignin('base', 'StackParam_v2', P.StackParam);
assignin('base', 'I_stack_cmd_A', P.I_stack_default_A);
assignin('base', 'egr_fraction_cmd', P.egr_fraction_cmd);
assignin('base', 'EGRInitialNode_v2', P.egr_initial_node);
assignin('base', 'StackInitialState_v2', P.stack_initial_state);

mw = get_param(P.modelName, 'ModelWorkspace');
assignin(mw, 'BenchAirParam_v1', P.BenchAirParam);
assignin(mw, 'BenchConditionerParam_v1', P.BenchConditionerParam);
assignin(mw, 'CompressorParam_v2', P.CompressorParam);
assignin(mw, 'StackParam_v2', P.StackParam);
assignin(mw, 'I_stack_cmd_A', P.I_stack_default_A);
assignin(mw, 'egr_fraction_cmd', P.egr_fraction_cmd);
assignin(mw, 'EGRInitialNode_v2', P.egr_initial_node);
assignin(mw, 'StackInitialState_v2', P.stack_initial_state);
end

function row = extractFinalRow(P, simOut)
summary = finalValue(simOut, 'summary_vector');
fresh = finalValue(simOut, 'bench_air_in_node');
egr = finalValue(simOut, 'egr_return_node');
benchOut = finalValue(simOut, 'bench_out_node');
mixed = finalValue(simOut, 'mixer_node');
compressorOut = finalValue(simOut, 'compressor_node');
conditioned = finalValue(simOut, 'bench_conditioned_node');
separatorGas = finalValue(simOut, 'separator_gas_node');
stackCaOut = finalValue(simOut, 'stack_ca_out_node');
[~, dq60Diag] = dq60_map_apply_v01(mixed, P.CompressorParam);
row = struct();
row.case_id = string(P.case_id);
row.case_index = P.caseIndex;
row.current_A = P.I_stack_default_A;
row.current_density_A_cm2 = P.current_density_A_cm2;
row.egr_fraction_cmd = P.egr_fraction_cmd;
row.V_cell_sim = summary(2);
row.P_stack_sim_W = summary(3);
row.pO2_stack_kPa = summary(4);
row.p_stack_internal_kPa = summary(5);
row.pH2_stack_kPa = summary(6);
row.p_an_internal_kPa = summary(7);
row.T_stack_C = summary(9);
row.lambda_membrane = summary(8);
row.xO2_stack = summary(10);
row.RH_stack = summary(11);
row.Q_net_stack_W = summary(22);
row.Q_gen_W = summary(32);
row.Q_cool_W = summary(33);
row.Q_amb_W = summary(34);
row.Q_gas_W = summary(35);
row.E_nernst_V = summary(36);
row.eta_act_V = summary(37);
row.eta_ohm_V = summary(38);
row.eta_con_V = summary(39);
row.lambda_O2_actual = summary(40);
row.pO2_core_in_kPa = summary(19);
row.CO2_voltage_mol_m3 = summary(43);
row.m_bench_air_in_kg_s = sum(fresh(1:3));
row.m_egr_return_kg_s = sum(egr(1:3));
row.m_bench_out_kg_s = sum(benchOut(1:3));
row.m_separator_gas_kg_s = sum(separatorGas(1:3));
row.alpha_EGR_actual = row.m_egr_return_kg_s / max(sum(stackCaOut(1:3)), 1e-12);
row.dq60_speed_rpm = dq60Diag.speed_rpm;
row.dq60_flow_lpm = dq60Diag.flow_lpm;
row.dq60_dp_kPa = compressorOut(6) - mixed(6);
row.dq60_pressure_ratio = dq60Diag.pressure_ratio;
row.dq60_power_W = dq60Diag.power_W;
row.dq60_map_flow_clamped = dq60Diag.map_flow_clamped;
row.p_dq60_in_kPa = mixed(6);
row.T_dq60_in_C = mixed(5);
row.p_dq60_out_kPa = compressorOut(6);
row.T_dq60_out_C = compressorOut(5);
row.T_ca_in_C = conditioned(5);
row.p_ca_in_kPa = conditioned(6);
[row.xO2_ca_in, row.pO2_ca_in_kPa, row.RH_ca_in] = gasDiagnostics(conditioned, P);
row.T_separator_C = stackCaOut(5);
row.liquid_drain_separator_kg_s = max(summary(60), 0);
row.coolant_flow_L_min = P.coolant_flow_L_min;
row.coolant_inlet_temp_C = P.T_cool_C;
row.coolant_outlet_temp_C = P.coolant_out_C;
row.Q_cool_bench_signed_W = P.coolant_rho_kg_L * P.coolant_cp_J_kgK * ...
    (P.coolant_flow_L_min / 60.0) * (P.coolant_out_C - P.T_cool_C);
row.h_cool_effective_W_K = row.Q_cool_W / max(row.T_stack_C - P.T_cool_C, 1e-9);
row.V_cell_bench = P.cell_voltage_bench_V;
row.V_cell_error = row.V_cell_sim - P.cell_voltage_bench_V;
end

function value = finalValue(simOut, name)
raw = simOut.get(name);
if isa(raw, 'timeseries')
    data = raw.Data;
elseif isstruct(raw) && isfield(raw, 'signals')
    data = raw.signals.values;
else
    data = raw;
end
if ndims(data) == 3
    value = data(:, :, end);
elseif ismatrix(data) && size(data, 1) > 1 && size(data, 2) > 1
    value = data(end, :)';
else
    value = data(:);
end
end

function [xO2, pO2, RH] = gasDiagnostics(node, P)
nO2 = node(1) / P.M_O2_kg_mol;
nN2 = node(2) / P.M_N2_kg_mol;
nV = node(3) / P.M_H2O_kg_mol;
total = max(nO2 + nN2 + nV, 1e-12);
xO2 = nO2 / total;
pO2 = node(6) * xO2;
RH = node(6) * nV / total / max(saturationPressureKPa(node(5)), 1e-6);
end

function pws = saturationPressureKPa(T_C)
Tc = min(max(T_C, -40), 120);
pws = 0.61121 * exp((18.678 - Tc / 234.5) * (Tc / (257.14 + Tc)));
end
