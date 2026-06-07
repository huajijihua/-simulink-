function P = init_testbench_10kw_v01(caseIndex, egrFraction, useBenchThermalCalibration)
%INIT_TESTBENCH_10KW_V01 Parameters for the 10 kW cEGR bench model.

if nargin < 1 || isempty(caseIndex)
    caseIndex = 1;
end
if nargin < 2 || isempty(egrFraction)
    egrFraction = 0.0;
end
if nargin < 3 || isempty(useBenchThermalCalibration)
    useBenchThermalCalibration = true;
end

rootDir = fileparts(fileparts(mfilename('fullpath')));
vehicleRoot = fullfile(fileparts(rootDir), '01_车载系统_10kW_GZS60_v3');
vehicleScriptDir = fullfile(vehicleRoot, '02_脚本');
if ~isfolder(vehicleScriptDir)
    error('CEGR:MissingVehicleScripts', 'Cannot find vehicle scripts: %s', vehicleScriptDir);
end
addpath(vehicleScriptDir);

P = init_vehicle_10kw_gzs60_v3('current');
P.rootDir = rootDir;
P.vehicleRoot = vehicleRoot;
P.modelName = 'CEGR_TestBench_10kW_v01';
P.modelFile = fullfile(rootDir, '01_模型', [P.modelName '.slx']);
P.resultDir = fullfile(rootDir, '04_验证结果');
P.docDir = fullfile(rootDir, '03_说明');
P.stopTime_s = 120;
P.dt_s = 0.1;

B = readBenchTable();
caseIndex = max(1, min(height(B), round(caseIndex)));
row = B(caseIndex, :);
P.caseIndex = caseIndex;
P.case_id = sprintf('bench_%03dA', round(row.current_A));
P.egr_fraction_cmd = min(max(egrFraction, 0), 0.95);

P = configureFromBenchRow(P, row);
if useBenchThermalCalibration
    P = readBenchThermalCalibration(P);
end
P = buildBenchModuleParams(P);
P = buildBenchInitialStates(P);
assignBenchWorkspace(P);

fprintf('Initialized %s case %s, EGR %.3f.\n', P.modelName, P.case_id, P.egr_fraction_cmd);
end

function B = readBenchTable()
dataFile = fullfile(fileparts(fileparts(fileparts(fileparts(mfilename('fullpath'))))), ...
    '00_支撑材料', '实验数据-设备说明书', '10kw短堆稳态测试_阴极尾气循环系统模型数据.txt');
text = fileread(dataFile);
lines = splitlines(string(text));
headerIdx = find(startsWith(lines, '电流_A'), 1);
if isempty(headerIdx)
    error('CEGR:MissingBenchHeader', 'Cannot find bench table header in %s', dataFile);
end
dataLines = lines(headerIdx + 1:end);
dataLines = dataLines(strlength(strtrim(dataLines)) > 0);
values = zeros(numel(dataLines), 33);
for k = 1:numel(dataLines)
    parts = split(dataLines(k), sprintf('\t'));
    if numel(parts) ~= 33
        error('CEGR:BadBenchRow', 'Bench row %d has %d columns, expected 33.', k, numel(parts));
    end
    values(k, :) = str2double(parts).';
end
B = array2table(values, 'VariableNames', { ...
    'current_A', 'current_density_A_cm2', 'stack_power_kW', 'stack_voltage_V', 'cell_voltage_from_stack_V', ...
    'bt3564_resistance_mohm', 'anode_stoich', 'anode_RH_pct', 'anode_in_temp_C', 'anode_out_temp_C', ...
    'anode_in_pressure_g_kPa', 'anode_out_pressure_g_kPa', 'anode_dp_kPa', 'anode_flow_nlpm', ...
    'cathode_stoich', 'cathode_RH_pct', 'cathode_in_temp_C', 'cathode_out_temp_C', ...
    'cathode_in_pressure_g_kPa', 'cathode_out_pressure_g_kPa', 'cathode_dp_kPa', 'cathode_flow_nlpm', ...
    'cathode_dewpoint_C', 'coolant_in_temp_C', 'coolant_out_temp_C', 'coolant_deltaT_C', ...
    'coolant_in_pressure_g_kPa', 'coolant_out_pressure_g_kPa', 'coolant_flow_L_min', ...
    'cell_voltage_max_V', 'cell_voltage_min_V', 'cell_voltage_avg_V', 'cell_voltage_spread_mV'});
end

function P = configureFromBenchRow(P, row)
P.I_stack_default_A = row.current_A;
P.current_density_A_cm2 = row.current_density_A_cm2;
P.stack_power_bench_kW = row.stack_power_kW;
P.stack_voltage_bench_V = row.stack_voltage_V;
P.cell_voltage_bench_V = row.cell_voltage_from_stack_V;
P.anode_stoich = row.anode_stoich;
P.RH_an_in = row.anode_RH_pct / 100;
P.p_anode_in_kPa = row.anode_in_pressure_g_kPa + P.p_amb_kPa;
P.p_anode_back_kPa = row.anode_out_pressure_g_kPa + P.p_amb_kPa;
P.p_cathode_back_kPa = row.cathode_out_pressure_g_kPa + P.p_amb_kPa;
P.T_cool_C = row.coolant_in_temp_C;
P.coolant_out_C = row.coolant_out_temp_C;
P.coolant_deltaT_C = row.coolant_deltaT_C;
P.coolant_flow_L_min = row.coolant_flow_L_min;
P.bench_air_T_C = row.cathode_in_temp_C;
P.bench_air_RH = row.cathode_RH_pct / 100;
P.bench_conditioner_T_C = row.cathode_in_temp_C;
P.bench_conditioner_p_kPa = row.cathode_in_pressure_g_kPa + P.p_amb_kPa;
P.separator_T_C = row.cathode_out_temp_C;
P.cathode_flow_nlpm = row.cathode_flow_nlpm;
P.cathode_flow_kg_s = nlpmAirToKgS(P.cathode_flow_nlpm);
P.dq60_speed_cmd_rpm = 3000;
P.DQ60MapParam = dq60_map_param_v01(P.dq60_speed_cmd_rpm);
P.bench_air_p_kPa = estimateDq60InletPressure(P);
P.compressor_dp_kPa = max(P.bench_conditioner_p_kPa - P.bench_air_p_kPa, 0.0);
P.compressor_dT_C = NaN;
P.K_ca_in_kg_s_kPa = max(P.cathode_flow_kg_s / max(P.bench_conditioner_p_kPa - P.p_cathode_back_kPa, 5), 1e-5);
P.cool_flow_curve_enabled = 1.0;
end

function P = readBenchThermalCalibration(P)
paramDir = fullfile(P.rootDir, '00_输入参数', '标定参数');
paramFile = fullfile(paramDir, 'testbench_thermal_stageA_params.csv');
curveFile = fullfile(paramDir, 'testbench_thermal_stageA_cooling_flow_curve.csv');
if isfile(paramFile)
    T = readtable(paramFile, 'TextType', 'string');
    if all(ismember(["parameter", "value"], string(T.Properties.VariableNames)))
        for k = 1:height(T)
            name = char(T.parameter(k));
            if isfield(P, name)
                value = str2double(string(T.value(k)));
                if isfinite(value)
                    P.(name) = value;
                end
            end
        end
    end
end
if isfile(curveFile)
    C = readtable(curveFile, 'TextType', 'string');
    if all(ismember(["coolant_flow_L_min", "h_cool_curve_W_K"], string(C.Properties.VariableNames)))
        flow = double(C.coolant_flow_L_min);
        h = double(C.h_cool_curve_W_K);
        valid = isfinite(flow) & isfinite(h) & flow > 0 & h > 0;
        if nnz(valid) >= 2
            P.cool_flow_curve_enabled = 1.0;
            P.cool_flow_curve_L_min = padCalibrationCurve(flow(valid));
            P.cool_flow_curve_h_W_K = padCalibrationCurve(h(valid));
            P.h_cool_W_K = h(find(valid, 1, 'first'));
        end
    end
end
end

function m = nlpmAirToKgS(nlpm)
% Standard-liter flow at 0 C, 101.325 kPa, humidification handled by boundary composition.
m = nlpm * 1.293 / 60000;
end

function P = buildBenchModuleParams(P)
P.BenchAirParam = [
    P.F_C_mol
    P.M_O2_kg_mol
    P.M_N2_kg_mol
    P.M_H2O_kg_mol
    P.bench_air_p_kPa
    P.bench_air_T_C
    P.bench_air_RH
    P.xO2_dry
    P.xN2_dry
    P.N_cell
    P.oxygen_stoich
    P.cathode_flow_kg_s
    P.bench_conditioner_p_kPa
    P.bench_conditioner_T_C
    P.bench_air_RH
    ];
P.CompressorParam = P.DQ60MapParam.vector;
P.BenchConditionerParam = [
    P.M_O2_kg_mol
    P.M_N2_kg_mol
    P.M_H2O_kg_mol
    P.p_amb_kPa
    P.bench_conditioner_T_C
    P.bench_conditioner_p_kPa
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
    P.book_theta1
    P.book_theta2
    P.book_theta3
    P.book_theta4
    P.membraneThickness_cm
    P.book_theta8
    P.book_theta9
    P.book_theta10
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
    P.book_theta5
    P.book_theta6
    P.book_theta7
    ];
end

function P = buildBenchInitialStates(P)
T0 = P.bench_conditioner_T_C;
TK = T0 + 273.15;
pCa = max(P.bench_conditioner_p_kPa, P.p_amb_kPa + 1);
pO2 = 0.18 * pCa;
pN2 = 0.72 * pCa;
pV = min(P.bench_air_RH * saturationPressureKPa(T0), 0.98 * pCa);
pH2 = max(P.p_anode_in_kPa * 0.85, 1);
pVAn = min(P.RH_an_in * saturationPressureKPa(T0), 0.15 * P.p_anode_in_kPa);
P.egr_initial_node = [0; 0; 0; 0; P.separator_T_C; P.p_cathode_back_kPa; 0];
P.stack_initial_state = [
    pO2 * 1000 * P.V_ca_m3 * P.M_O2_kg_mol / (P.R_J_molK * TK)
    pN2 * 1000 * P.V_ca_m3 * P.M_N2_kg_mol / (P.R_J_molK * TK)
    pV * 1000 * P.V_ca_m3 * P.M_H2O_kg_mol / (P.R_J_molK * TK)
    pH2 * 1000 * P.V_an_m3 * P.M_H2_kg_mol / (P.R_J_molK * TK)
    pVAn * 1000 * P.V_an_m3 * P.M_H2O_kg_mol / (P.R_J_molK * TK)
    T0
    ];
end

function assignBenchWorkspace(P)
assignin('base', 'P_testbench_v1', P);
assignin('base', 'BenchAirParam_v1', P.BenchAirParam);
assignin('base', 'BenchConditionerParam_v1', P.BenchConditionerParam);
assignin('base', 'CompressorParam_v2', P.CompressorParam);
assignin('base', 'StackParam_v2', P.StackParam);
assignin('base', 'I_stack_cmd_A', P.I_stack_default_A);
assignin('base', 'egr_fraction_cmd', P.egr_fraction_cmd);
assignin('base', 'EGRInitialNode_v2', P.egr_initial_node);
assignin('base', 'StackInitialState_v2', P.stack_initial_state);
end

function pIn = estimateDq60InletPressure(P)
% Estimate the bench-side source pressure needed to reproduce the measured
% no-EGR cathode inlet pressure with the first-pass DQ60 map.
pTarget = P.bench_conditioner_p_kPa;
pIn = max(P.p_amb_kPa, pTarget - 10);
for k = 1:8
    node = benchFreshNode(P, pIn);
    [~, diag] = dq60_map_apply_v01(node, P.DQ60MapParam.vector);
    pIn = min(max(pTarget - diag.dp_kPa, P.p_amb_kPa), max(pTarget - 0.1, P.p_amb_kPa));
end
end

function node = benchFreshNode(P, p_kPa)
M_O2 = P.M_O2_kg_mol;
M_N2 = P.M_N2_kg_mol;
M_H2O = P.M_H2O_kg_mol;
pH2O = min(max(P.bench_air_RH, 0) * saturationPressureKPa(P.bench_conditioner_T_C), 0.98 * P.bench_conditioner_p_kPa);
yH2O = min(max(pH2O / max(P.bench_conditioner_p_kPa, 1e-6), 0), 0.98);
yO2 = (1 - yH2O) * P.xO2_dry;
yN2 = (1 - yH2O) * P.xN2_dry;
mO2 = yO2 * M_O2;
mN2 = yN2 * M_N2;
mV = yH2O * M_H2O;
scale = P.cathode_flow_kg_s / max(mO2 + mN2 + mV, 1e-12);
node = [scale * mO2; scale * mN2; scale * mV; 0; P.bench_air_T_C; p_kPa; 0];
end

function pws = saturationPressureKPa(T_C)
Tc = min(max(T_C, -40), 120);
pws = 0.61121 * exp((18.678 - Tc / 234.5) * (Tc / (257.14 + Tc)));
end

function padded = padCalibrationCurve(values)
padded = zeros(1, 13);
n = min(numel(values), 13);
padded(1:n) = reshape(values(1:n), 1, []);
end
