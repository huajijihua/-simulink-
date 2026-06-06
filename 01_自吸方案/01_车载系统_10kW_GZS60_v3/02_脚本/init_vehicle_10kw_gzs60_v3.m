function P = init_vehicle_10kw_gzs60_v3(calibrationMode)
%INIT_VEHICLE_10KW_GZS60_V3 Centralized parameters for the v3 Simulink model.
%
% This script is an auxiliary entry point. The Simulink model remains the
% authoritative system model; parameters are passed into module MATLAB
% Function blocks as small module-specific vectors.

if nargin < 1 || strlength(string(calibrationMode)) == 0
    calibrationMode = "current";
else
    calibrationMode = string(calibrationMode);
end

rootDir = fileparts(fileparts(mfilename('fullpath')));
inputDir = fullfile(rootDir, '00_输入参数');

P = struct();
P.rootDir = rootDir;
P.inputDir = inputDir;
P.modelName = 'CEGR_Vehicle_10kW_GZS60_v03_stage1_pressurefix';
P.modelFile = fullfile(rootDir, '01_模型', [P.modelName '.slx']);
P.calibration_baseline = "stage1_pressurefix_no_egr";
P.stopTime_s = 120;
P.dt_s = 0.1;

% Physical constants.
P.R_J_molK = 8.314462618;
P.F_C_mol = 96485.33212;
P.M_O2_kg_mol = 0.031998;
P.M_N2_kg_mol = 0.0280134;
P.M_H2O_kg_mol = 0.01801528;
P.M_H2_kg_mol = 0.00201588;

% Ambient boundary.
P.p_amb_kPa = 101.325;
P.T_amb_C = 25.0;
P.RH_amb = 0.50;
P.xO2_dry = 0.2095;
P.xN2_dry = 0.7905;

% Stack geometry and operating point. Values are engineering defaults unless
% overwritten by copied source data.
P.N_cell = 16;
P.A_cell_cm2 = 380.0;
P.I_stack_default_A = 120.0;
P.oxygen_stoich = 2.0;
P.anode_stoich = 1.35;
P.RH_an_in = 0.30;

% Cathode BOP simplified boundaries.
P.compressor_dp_kPa = 55.0;
P.compressor_dT_C = 35.0;
P.intercooler_T_C = 55.0;
P.intercooler_dp_kPa = 8.0;
P.p_cathode_back_kPa = 128.0;
P.p_anode_back_kPa = 85.0;
P.p_anode_in_kPa = 140.0;
P.K_ca_in_kg_s_kPa = 3.0e-3;

% Humidifier initial engineering parameters. GZS60 data copied into the v3
% input library constrains the device boundary; these are not final
% quantitative GZS60 calibration claims.
P.hum_NTU_ref = 0.48;
P.hum_m_ref_kg_s = 0.085;
P.hum_flow_exp = 0.38;
P.hum_heat_eff = 0.55;
P.hum_dry_dp_ref_kPa = 7.0;
P.hum_wet_dp_ref_kPa = 10.0;
P.hum_dp_exp = 0.70;
P.hum_mem_area_m2 = 8.0;
P.hum_mem_thickness_m = 5.0e-5;
P.hum_mem_D_eff_m2_s = 2.0e-10;
P.hum_beta_wet_m_s = 0.02;
P.hum_beta_dry_m_s = 0.02;
P.hum_UA_W_K = 80.0;

% Stack dynamic and calibration parameters.
% V_ca_m3 / V_an_m3 are the stack cathode/anode channel gas volumes used in
% pV=nRT. They are fixed from the 16-cell, 380 cm2 geometry estimate rather
% than fitted as equivalent manifold or pipe inventory.
P.V_ca_m3 = 2.0e-4;
P.V_an_m3 = 1.5e-4;
% Book outlet coefficients map to stack-level outlet boundaries only.
P.K_ca_out_kg_s_kPa = 1.2e-4;
P.K_an_out_kg_s_kPa = 6.67e-6;
P.K_liq_carry_1_s = 0.08;
P.C_stack_J_K = 4.5e4;
P.h_cool_W_K = 55.0;
P.T_cool_C = 62.0;
P.h_amb_W_K = 3.0;
P.coolant_flow_L_min = 6.0;
P.coolant_rho_kg_L = 1.0;
P.coolant_cp_J_kgK = 4180.0;
P.cool_flow_curve_enabled = 0.0;
P.cool_flow_curve_L_min = zeros(1, 13);
P.cool_flow_curve_h_W_K = zeros(1, 13);
P.k_mem_water_kg_s = 1.2e-4;

% Book voltage model parameters. Current code uses the book-form theta
% coefficients directly.
P.E_nernst_ref_V = 1.229;
P.E_nernst_temp_coeff_V_K = 8.5e-4;
P.book_theta1 = 0.7084;
P.book_theta2 = 1.43e-3;
P.book_theta3 = -1.527e-4;
P.book_theta4 = 1.043e-4;
P.book_theta5 = 0.525;
P.book_theta6 = 0.2173;
P.book_theta7 = -302.06;
P.book_theta8 = 5.13e-4;
P.book_theta9 = 5.2e-10;
P.book_theta10 = 0.0335;
P.membraneThickness_cm = 0.005;
P.thermoneutralVoltage_V = 1.254;
P.LHV_H2_J_mol = 241.8e3;
P.stack_m_act_O2 = 0.65;
P.stack_m_lim_O2 = 1.20;
P.stack_i_lim_ref_A_cm2 = 1.20;
P.stack_lambda_O2_half = 1.20;

% EGR is modeled as a lumped splitter/return feedback in the current SLX.
P.egr_fraction_default = 0.40;

P = readCopiedData(P, inputDir);
P = readVoltageFitParams(P, inputDir);
P = readCurrentCalibrationBaseline(P, inputDir, calibrationMode);
P = buildModuleParams(P);

% Initial feedback nodes and stack inventory.
P.egr_initial_node = [0 0 0 0 P.T_amb_C P.p_amb_kPa 0]';
P.wet_initial_node = [0 0 0 0 70.0 P.p_cathode_back_kPa 0]';

T0_K = 65.0 + 273.15;
pO2_0 = 25.0;
pN2_0 = 95.0;
pH2Ov_0 = min(25.0, saturationPressureKPa(65.0));
pH2_0 = 130.0;
pH2OvAn_0 = 0.30 * saturationPressureKPa(65.0);

P.stack_initial_state = [
    pO2_0 * 1000 * P.V_ca_m3 * P.M_O2_kg_mol / (P.R_J_molK * T0_K)
    pN2_0 * 1000 * P.V_ca_m3 * P.M_N2_kg_mol / (P.R_J_molK * T0_K)
    pH2Ov_0 * 1000 * P.V_ca_m3 * P.M_H2O_kg_mol / (P.R_J_molK * T0_K)
    0
    pH2_0 * 1000 * P.V_an_m3 * P.M_H2_kg_mol / (P.R_J_molK * T0_K)
    pH2OvAn_0 * 1000 * P.V_an_m3 * P.M_H2O_kg_mol / (P.R_J_molK * T0_K)
    0
    65.0
    ];

P.stack_initial_state_audit = [
    P.stack_initial_state(1)
    P.stack_initial_state(2)
    P.stack_initial_state(3)
    P.stack_initial_state(5)
    P.stack_initial_state(6)
    P.stack_initial_state(8)
    ];

clearObsoleteWorkspaceSymbols();

% Keep only the workspace symbols bound by the current compact v3 SLX.
assignin('base', 'P_v2', P);
assignin('base', 'EnvParam_v2', P.EnvParam);
assignin('base', 'CompressorParam_v2', P.CompressorParam);
assignin('base', 'IntercoolerParam_v2', P.IntercoolerParam);
assignin('base', 'HumidifierParam_v2', P.HumidifierParam);
assignin('base', 'StackParam_v2', P.StackParam);
assignin('base', 'I_stack_cmd_A', P.I_stack_default_A);
assignin('base', 'egr_fraction_cmd', 0.0);
assignin('base', 'EGRInitialNode_v2', P.egr_initial_node);
assignin('base', 'WetInitialNode_v2', P.wet_initial_node);
assignin('base', 'StackInitialState_v2', P.stack_initial_state);
assignin('base', 'StackInitialStateAudit_v3', P.stack_initial_state_audit);

fprintf('Initialized %s parameters (%s mode) in base workspace.\n', P.modelName, calibrationMode);
end

function P = readCopiedData(P, inputDir)
humCsv = fullfile(inputDir, '加湿器_GZS60', 'GZS60车载模型参数_v02.csv');
if isfile(humCsv)
    H = readtable(humCsv, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    if height(H) >= 1
        P.hum_NTU_ref = readField(H, "NTU_ref", P.hum_NTU_ref);
        P.hum_flow_exp = readField(H, "NTU_flow_exponent", P.hum_flow_exp);
        P.hum_heat_eff = readField(H, "heat_effectiveness", P.hum_heat_eff);
        P.hum_dry_dp_ref_kPa = readField(H, "dryDpRef_kPa", P.hum_dry_dp_ref_kPa);
        P.hum_wet_dp_ref_kPa = readField(H, "wetDpRef_kPa", P.hum_wet_dp_ref_kPa);
        P.hum_dp_exp = mean([ ...
            readField(H, "dryDpExponent", P.hum_dp_exp), ...
            readField(H, "wetDpExponent", P.hum_dp_exp)]);
        refSlpm = readField(H, "refFlow_slpm", 5000);
        P.hum_m_ref_kg_s = max(0.02, refSlpm / 60000 * 1.18);
    end
end

icCsv = fullfile(inputDir, '中冷器边界', 'gzs60_intercooler_requirement_points_v01.csv');
if isfile(icCsv)
    IC = readtable(icCsv, 'TextType', 'string', 'VariableNamingRule', 'preserve');
    names = string(IC.Properties.VariableNames);
    ToutCol = find(contains(lower(names), "out") & contains(lower(names), "temp"), 1);
    if ~isempty(ToutCol)
        vals = str2double(string(IC{:, ToutCol}));
        vals = vals(isfinite(vals));
        if ~isempty(vals)
            P.intercooler_T_C = median(vals);
        end
    end
end
end

function P = readVoltageFitParams(P, inputDir)
fitCsv = fullfile(inputDir, '电堆物理模型', 'stack_voltage_book_theta_params.csv');
if ~isfile(fitCsv)
    return;
end

T = readtable(fitCsv, 'TextType', 'string');
if height(T) < 1
    return;
end

fields = {
    "theta1", "book_theta1"
    "theta2", "book_theta2"
    "theta3", "book_theta3"
    "theta4", "book_theta4"
    "theta5", "book_theta5"
    "theta6", "book_theta6"
    "theta7", "book_theta7"
    "theta8", "book_theta8"
    "theta9", "book_theta9"
    "theta10", "book_theta10"
    };

for k = 1:size(fields, 1)
    csvName = fields{k, 1};
    dstName = fields{k, 2};
    if ismember(csvName, string(T.Properties.VariableNames))
        value = T{1, csvName};
        if isnumeric(value)
            parsed = value;
        else
            parsed = str2double(string(value));
        end
        if isfinite(parsed)
            P.(dstName) = parsed;
        end
    end
end
end

function P = readCurrentCalibrationBaseline(P, inputDir, calibrationMode)
if calibrationMode == "base"
    return;
end

paramDir = fullfile(inputDir, '标定参数');

stage1Csv = fullfile(paramDir, 'pressurefix_stage1_boundary_params.csv');
if ~isfile(stage1Csv)
    stage1Csv = fullfile(paramDir, 'stage1_boundary_calibrated_params.csv');
end
if ismember(calibrationMode, ["current", "stage1", "stageA", "stageB", "stage2", "stage3"]) && isfile(stage1Csv)
    T = readtable(stage1Csv, 'TextType', 'string');
    P = applyNameValueTable(P, T, "parameter", "value");
end

stageAThermalCsv = fullfile(paramDir, 'thermal_stageA_params.csv');
stage2ThermalCsv = fullfile(paramDir, 'stage2_thermal_humidity_calibrated_params.csv');
if ismember(calibrationMode, ["current", "stageA", "stageB", "stage2", "stage3"]) && isfile(stage2ThermalCsv)
    T = readtable(stage2ThermalCsv, 'TextType', 'string');
    P = applyNameValueTable(P, T, "parameter", "value");
end
if ismember(calibrationMode, ["current", "stageA", "stageB"]) && isfile(stageAThermalCsv)
    T = readtable(stageAThermalCsv, 'TextType', 'string');
    P = applyNameValueTable(P, T, "parameter", "value");
end

stageBHumidityCsv = fullfile(paramDir, 'humidity_stageB_params.csv');
if ismember(calibrationMode, ["current", "stageB"]) && isfile(stageBHumidityCsv)
    T = readtable(stageBHumidityCsv, 'TextType', 'string');
    P = applyNameValueTable(P, T, "parameter", "value");
end

stage2VoltageCsv = fullfile(inputDir, '电堆物理模型', 'stack_voltage_book_theta_params.csv');
if ismember(calibrationMode, ["current", "stageA", "stageB", "stage2", "stage3"]) && isfile(stage2VoltageCsv)
    T = readtable(stage2VoltageCsv, 'TextType', 'string');
    if height(T) >= 1
        fields = {
            "theta1", "book_theta1"
            "theta2", "book_theta2"
            "theta3", "book_theta3"
            "theta4", "book_theta4"
            "theta5", "book_theta5"
            "theta6", "book_theta6"
            "theta7", "book_theta7"
            "theta8", "book_theta8"
            "theta9", "book_theta9"
            "theta10", "book_theta10"
            };
        for k = 1:size(fields, 1)
            if ismember(fields{k, 1}, string(T.Properties.VariableNames))
                value = numericScalar(T{1, fields{k, 1}});
                if isfinite(value)
                    P.(fields{k, 2}) = value;
                end
            end
        end
    end
end

stageACoolingCsv = fullfile(paramDir, 'thermal_stageA_cooling_flow_curve.csv');
if ismember(calibrationMode, ["current", "stageA", "stageB"]) && isfile(stageACoolingCsv)
    T = readtable(stageACoolingCsv, 'TextType', 'string');
    if all(ismember(["coolant_flow_L_min", "h_cool_curve_W_K"], string(T.Properties.VariableNames)))
        flow = double(T.coolant_flow_L_min);
        h = double(T.h_cool_curve_W_K);
        valid = isfinite(flow) & isfinite(h) & flow > 0 & h > 0;
        if nnz(valid) >= 2
            P.cool_flow_curve_enabled = 1.0;
            P.cool_flow_curve_L_min = padCalibrationCurve(flow(valid));
            P.cool_flow_curve_h_W_K = padCalibrationCurve(h(valid));
        end
    end
end
end

function P = applyNameValueTable(P, T, nameColumn, valueColumn)
if ~all(ismember([nameColumn, valueColumn], string(T.Properties.VariableNames)))
    return;
end
for k = 1:height(T)
    name = char(T{k, nameColumn});
    if isfield(P, name)
        value = numericScalar(T{k, valueColumn});
        if isfinite(value)
            P.(name) = value;
        end
    end
end
end

function value = numericScalar(raw)
if isnumeric(raw)
    value = double(raw(1));
else
    value = str2double(string(raw(1)));
end
end

function padded = padCalibrationCurve(values)
padded = zeros(1, 13);
n = min(numel(values), 13);
padded(1:n) = reshape(values(1:n), 1, []);
end

function P = buildModuleParams(P)
% Keep each module parameter vector small and ordered by physical role.
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

function value = readField(T, name, defaultValue)
value = defaultValue;
if ismember(name, string(T.Properties.VariableNames))
    parsed = str2double(string(T{1, name}));
    if isfinite(parsed)
        value = parsed;
    end
end
end

function pws = saturationPressureKPa(T_C)
pws = 0.61121 * exp((18.678 - T_C / 234.5) * (T_C / (257.14 + T_C)));
end

function clearObsoleteWorkspaceSymbols()
obsolete = [
    "SeparatorParam_v2"
    "TailGasParam_v2"
    "EGRValveParam_v2"
    "BackPressureValveParam_v2"
    "EGRReturnPipeParam_v2"
    "CathodeOutletManifoldParam_v3"
    "AnodeOutletManifoldParam_v3"
    "CathodeOutletManifoldInitialState_v3"
    "AnodeOutletManifoldInitialState_v3"
    "TailGasManifoldInitialState_v3"
    "AnodeTailDownstreamPressure_v3"
    ];
for k = 1:numel(obsolete)
    evalin('base', sprintf("if exist('%s','var'), clear('%s'); end", obsolete(k), obsolete(k)));
end
end
