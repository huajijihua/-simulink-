function P = init_testbench_10kw_simplified_egr(caseIndex, dataMode, verbose)
%INIT_TESTBENCH_10KW_SIMPLIFIED_EGR Init data and parameters for simplified bench EGR model.
%
% The Simulink model is the main artifact. This script only prepares
% workspace parameters for one steady bench point.

if nargin < 1 || isempty(caseIndex)
    caseIndex = 1;
end
if nargin < 2 || strlength(string(dataMode)) == 0
    dataMode = "egr";
else
    dataMode = lower(string(dataMode));
end
if nargin < 3 || isempty(verbose)
    verbose = true;
end

rootDir = fileparts(fileparts(mfilename('fullpath')));
projectRoot = fileparts(fileparts(rootDir));
vehicleRoot = fullfile(fileparts(rootDir), '01_车载系统_10kW_GZS60_v3');
vehicleScriptDir = fullfile(vehicleRoot, '02_脚本');
if ~isfolder(vehicleScriptDir)
    error('CEGR:SimplifiedBench:MissingVehicleScripts', ...
        'Cannot find vehicle scripts: %s', vehicleScriptDir);
end
addpath(vehicleScriptDir);

if verbose
    P = init_vehicle_10kw_gzs60_v3('current');
else
    [~, P] = evalc("init_vehicle_10kw_gzs60_v3('current')");
end
P.rootDir = rootDir;
P.projectRoot = projectRoot;
P.vehicleRoot = vehicleRoot;
P.modelName = 'CEGR_TestBench_10kW_SimplifiedEGR_v01';
P.modelFile = fullfile(rootDir, '01_模型', [P.modelName '.slx']);
addpath(fullfile(rootDir, '01_模型'));
P.stopTime_s = 120;
P.dt_s = 0.1;

[noEgr, egr] = readSimplifiedBenchData(projectRoot);
P.noEgrTable = noEgr;
P.egrTable = egr;
P.dataMode = dataMode;
assignin('base', 'NoEGRBenchData_simplified', noEgr);
assignin('base', 'EGRBenchData_simplified', egr);

if dataMode == "noegr"
    caseIndex = max(1, min(height(noEgr), round(caseIndex)));
    row = noEgr(caseIndex, :);
    P.caseIndex = caseIndex;
    P.case_id = sprintf('noegr_%02d_%03dA', caseIndex, round(row.current_A));
    P = configureFromNoEgrRow(P, row);
elseif dataMode == "egr"
    caseIndex = max(1, min(height(egr), round(caseIndex)));
    row = egr(caseIndex, :);
    P.caseIndex = caseIndex;
    P.case_id = sprintf('egr_%02d_%03dA', caseIndex, round(row.current_A));
    P = configureFromEgrRow(P, row, noEgr);
else
    error('CEGR:SimplifiedBench:BadMode', 'dataMode must be "noegr" or "egr".');
end
P = readLocalCalibration(P);
P = buildSimplifiedBenchParams(P);
P = buildSimplifiedInitialStates(P);
assignSimplifiedWorkspace(P);

if verbose
    fprintf('Initialized %s case %s, EGR %.4f.\n', ...
        P.modelName, P.case_id, P.egr_fraction_cmd);
end
end

function [noEgr, egr] = readSimplifiedBenchData(projectRoot)
dataDir = fullfile(projectRoot, '00_支撑材料', '实验数据-设备说明书');
noEgrFile = fullfile(dataDir, '10kw电堆台架稳态测试数据整理.xlsx');
egrFile = fullfile(dataDir, '10kw短堆阴极尾气循环测试_0.1Acm2加20A补充_整理版_修正.xlsx');
if ~isfile(noEgrFile)
    error('CEGR:SimplifiedBench:MissingData', 'Cannot find %s', noEgrFile);
end
if ~isfile(egrFile)
    error('CEGR:SimplifiedBench:MissingData', 'Cannot find %s', egrFile);
end

main = readcell(noEgrFile, 'Sheet', 'Sheet1');
cool = readcell(noEgrFile, 'Sheet', 'Sheet3');
flow = readcell(noEgrFile, 'Sheet', 'Sheet4');
nRows = size(main, 1) - 2;
vals = zeros(nRows, 18);
for k = 1:nRows
    r = k + 2;
    vals(k, :) = [
        num(main{r, 1}), num(main{r, 2}), num(main{r, 4}) / PcellCount(), ...
        num(main{r, 6}), num(main{r, 7}) / 100, num(main{r, 8}), num(main{r, 9}), num(main{r, 10}), ...
        num(main{r, 11}), num(main{r, 12}), num(main{r, 13}) / 100, num(main{r, 14}), num(main{r, 15}), ...
        num(flow{r, 2}), num(flow{r, 4}), num(cool{r, 2}), num(cool{r, 3}), num(cool{r, 8})];
end
noEgr = array2table(vals, 'VariableNames', { ...
    'current_A', 'current_density_A_cm2', 'cell_voltage_V', ...
    'anode_stoich', 'anode_RH', 'anode_in_T_C', 'anode_in_p_g_kPa', 'anode_out_p_g_kPa', ...
    'anode_out_T_C', 'cathode_stoich', 'cathode_RH', 'cathode_in_T_C', 'cathode_in_p_g_kPa', ...
    'anode_flow_SLPM', 'cathode_flow_SLPM', 'coolant_in_T_C', 'coolant_out_T_C', 'coolant_flow_L_min'});
noEgr.case_index = (1:height(noEgr)).';

raw = readtable(egrFile, 'Sheet', '整理数据', 'VariableNamingRule', 'preserve', 'TextType', 'string');
egr = table();
egr.current_density_A_cm2 = double(raw.("电密(A/cm2)"));
egr.current_A = double(raw.("电流(A)"));
egr.cell_voltage_V = double(raw.("单片电压(V)"));
egr.egr_valve_target_pct = double(raw.("EGR阀_目标开度(%)"));
egr.egr_valve_input_pct = double(raw.("EGR阀_输入值(%)"));
egr.egr_flow_SLPM = double(raw.("回流参数_回流流量"));
egr.egr_flow_cal_SLPM = double(raw.("回流参数_校准回流"));
egr.egr_rate_raw = percentToFraction(double(raw.("回流参数_EGR率")));
egr.egr_rate_cal = percentToFraction(double(raw.("回流参数_校准EGR率")));
egr.stack_in_flow_SLPM = double(raw.("回流参数_入堆流量流量计(SLPM)"));
egr.bench_supply_flow_SLPM = double(raw.("台架供给_给气流量(SLPM)"));
egr.bench_supply_p_kPa = double(raw.("台架供给_实际压力(kPa)"));
egr.bench_supply_T_C = double(raw.("台架供给_给气温度(℃)"));
egr.bench_supply_RH = percentToFraction(double(raw.("台架供给_给气湿度(%)")));
egr.stack_in_p_kPa = double(raw.("实际入堆_泵后压力(kPa)"));
egr.stack_in_T_C = double(raw.("实际入堆_泵后温度(℃)"));
egr.stack_in_RH = percentToFraction(double(raw.("实际入堆_泵后湿度(%)")));
egr.stack_out_p_kPa = double(raw.("实际出堆_压力(kPa)"));
egr.stack_out_T_C = double(raw.("实际出堆_温度(℃)"));
egr.stack_out_RH = percentToFraction(double(raw.("实际出堆_湿度(%)")));
egr.bench_out_p_kPa = double(raw.("台架出气_出气压力(kPa)"));
egr.bench_out_T_C = double(raw.("台架出气_出气温度(℃)"));
egr.coolant_in_T_C = double(raw.("台架水路_进水温度"));
egr.coolant_out_T_C = double(raw.("台架水路_出水温度"));
egr.coolant_flow_L_min = double(raw.("台架水路_水流量"));
egr.source = string(raw.("来源文件"));
egr.note = string(raw.("整理备注"));
egr.egr_fraction_model = deriveEgrFraction(egr);
egr.case_index = (1:height(egr)).';

extra20 = egr(egr.current_A == 20 & egr.egr_fraction_model == 0, :);
if ~isempty(extra20)
    extra = noEgr(1, :);
    extra.current_A = extra20.current_A(1);
    extra.current_density_A_cm2 = extra20.current_density_A_cm2(1);
    extra.cell_voltage_V = extra20.cell_voltage_V(1);
    extra.cathode_in_T_C = extra20.stack_in_T_C(1);
    extra.cathode_in_p_g_kPa = extra20.stack_in_p_kPa(1);
    extra.cathode_RH = extra20.stack_in_RH(1);
    extra.cathode_flow_SLPM = extra20.stack_in_flow_SLPM(1);
    extra.coolant_in_T_C = extra20.coolant_in_T_C(1);
    extra.coolant_out_T_C = extra20.coolant_out_T_C(1);
    noEgr = sortrows([extra; noEgr], 'current_A');
    noEgr.case_index = (1:height(noEgr)).';
end
end

function P = configureFromNoEgrRow(P, row)
P.I_stack_default_A = row.current_A;
P.current_density_A_cm2 = row.current_density_A_cm2;
P.cell_voltage_bench_V = row.cell_voltage_V;
P.egr_fraction_cmd = 0.0;
P.egr_valve_target_pct = 0.0;
P.egr_valve_input_pct = 0.0;

P.stack_in_flow_SLPM = row.cathode_flow_SLPM;
P.stack_in_flow_kg_s = slpmAirToKgS(P.stack_in_flow_SLPM);
P.fresh_supply_flow_SLPM = P.stack_in_flow_SLPM;
P.fresh_supply_flow_kg_s = P.stack_in_flow_kg_s;

P.bench_stack_in_T_C = row.cathode_in_T_C;
P.bench_stack_in_p_kPa = row.cathode_in_p_g_kPa;
P.bench_stack_in_RH = row.cathode_RH;
P.separator_T_C = row.coolant_out_T_C + 3.0;
P.separator_p_kPa = max(row.cathode_in_p_g_kPa - 5.0, 0.0);

P.anode_stoich = row.anode_stoich;
P.RH_an_in = row.anode_RH;
P.p_anode_in_kPa = row.anode_in_p_g_kPa + P.p_amb_kPa;
P.p_anode_back_kPa = row.anode_out_p_g_kPa + P.p_amb_kPa;
P.p_cathode_back_kPa = P.separator_p_kPa + P.p_amb_kPa;
P.T_cool_C = row.coolant_in_T_C;
P.coolant_out_C = row.coolant_out_T_C;
P.coolant_flow_L_min = row.coolant_flow_L_min;
P.K_ca_in_kg_s_kPa = max(P.stack_in_flow_kg_s / max(P.bench_stack_in_p_kPa + P.p_amb_kPa - P.p_cathode_back_kPa, 5), 1e-5);
end

function P = configureFromEgrRow(P, row, noEgr)
P.I_stack_default_A = row.current_A;
P.current_density_A_cm2 = row.current_density_A_cm2;
P.cell_voltage_bench_V = row.cell_voltage_V;
P.egr_fraction_cmd = min(max(row.egr_fraction_model, 0), 0.95);
P.egr_valve_target_pct = row.egr_valve_target_pct;
P.egr_valve_input_pct = row.egr_valve_input_pct;

P.stack_in_flow_SLPM = finiteOr(row.stack_in_flow_SLPM, row.bench_supply_flow_SLPM);
P.stack_in_flow_kg_s = slpmAirToKgS(P.stack_in_flow_SLPM);
P.fresh_supply_flow_SLPM = finiteOr(row.bench_supply_flow_SLPM, ...
    P.stack_in_flow_SLPM * (1 - P.egr_fraction_cmd));
P.fresh_supply_flow_kg_s = slpmAirToKgS(P.fresh_supply_flow_SLPM);

P.bench_stack_in_T_C = finiteOr(row.stack_in_T_C, row.bench_supply_T_C);
P.bench_stack_in_p_kPa = finiteOr(row.stack_in_p_kPa, row.bench_supply_p_kPa);
P.bench_stack_in_RH = finiteOr(row.stack_in_RH, row.bench_supply_RH);
P.separator_T_C = finiteOr(row.stack_out_T_C, row.bench_out_T_C);
P.separator_p_kPa = finiteOr(row.stack_out_p_kPa, row.bench_out_p_kPa);

ref = interpNoEgr(noEgr, P.I_stack_default_A);
P.anode_stoich = ref.anode_stoich;
P.RH_an_in = ref.anode_RH;
P.p_anode_in_kPa = ref.anode_in_p_g_kPa + P.p_amb_kPa;
P.p_anode_back_kPa = ref.anode_out_p_g_kPa + P.p_amb_kPa;
P.p_cathode_back_kPa = finiteOr(row.bench_out_p_kPa, row.stack_out_p_kPa);
if isfinite(P.p_cathode_back_kPa)
    P.p_cathode_back_kPa = P.p_cathode_back_kPa + P.p_amb_kPa;
else
    P.p_cathode_back_kPa = P.bench_stack_in_p_kPa + P.p_amb_kPa - 5;
end
P.T_cool_C = finiteOr(row.coolant_in_T_C, ref.coolant_in_T_C);
P.coolant_out_C = finiteOr(row.coolant_out_T_C, ref.coolant_out_T_C);
P.coolant_flow_L_min = finiteOr(row.coolant_flow_L_min, ref.coolant_flow_L_min);
P.K_ca_in_kg_s_kPa = max(P.stack_in_flow_kg_s / max(P.bench_stack_in_p_kPa + P.p_amb_kPa - P.p_cathode_back_kPa, 5), 1e-5);
end

function P = buildSimplifiedBenchParams(P)
P.egr_fraction_cmd_raw = P.egr_fraction_cmd;
if P.dataMode == "egr"
    P.egr_fraction_cmd = min(max(P.egr_fraction_cmd * P.egr_fraction_scale + P.egr_fraction_bias, 0), 0.95);
    P.separator_T_C = P.separator_T_C + P.separator_T_offset_C;
    P.separator_p_kPa = P.separator_p_kPa + P.separator_p_offset_kPa;
    P.stack_in_flow_kg_s = P.stack_in_flow_kg_s * P.stack_in_flow_scale;
    P.fresh_supply_flow_kg_s = P.fresh_supply_flow_kg_s * P.fresh_supply_flow_scale;
else
    P.egr_fraction_cmd = 0.0;
end
P.BenchBoundaryParam = [
    P.M_O2_kg_mol
    P.M_N2_kg_mol
    P.M_H2O_kg_mol
    P.bench_stack_in_p_kPa + P.p_amb_kPa
    P.bench_stack_in_T_C
    P.bench_stack_in_RH
    P.xO2_dry
    P.xN2_dry
    P.stack_in_flow_kg_s
    P.fresh_supply_flow_kg_s
    ];
P.EgrSplitParam = [
    P.egr_fraction_cmd
    P.separator_T_C
    P.separator_p_kPa + P.p_amb_kPa
    P.egr_valve_target_pct
    P.egr_valve_input_pct
    ];
P.StackParam(15) = P.p_cathode_back_kPa;
P.StackParam(16) = P.p_anode_back_kPa;
P.StackParam(20) = P.T_cool_C;
P.StackParam(33) = P.anode_stoich;
P.StackParam(34) = P.RH_an_in;
P.StackParam(37) = P.p_anode_in_kPa;
P.StackParam(38) = P.K_ca_in_kg_s_kPa;
P.StackParam(44) = P.coolant_flow_L_min;
if numel(P.StackParam) < 78
    P.StackParam(78) = 0;
end
P.StackParam(75) = P.egr_fraction_cmd;
P.StackParam(76) = P.egr_loss_k_V;
P.StackParam(77) = P.egr_loss_exp;
P.StackParam(78) = P.egr_loss_rh_V;
end

function P = readLocalCalibration(P)
P.egr_fraction_scale = 1.0;
P.egr_fraction_bias = 0.0;
P.separator_T_offset_C = 0.0;
P.separator_p_offset_kPa = 0.0;
P.stack_in_flow_scale = 1.0;
P.fresh_supply_flow_scale = 1.0;
P.egr_loss_k_V = 0.0;
P.egr_loss_exp = 1.0;
P.egr_loss_rh_V = 0.0;

paramDir = fullfile(P.rootDir, '00_输入参数', '标定参数');
stackFile = fullfile(paramDir, 'simplified_noegr_stack_params.csv');
egrFile = fullfile(paramDir, 'simplified_egr_boundary_params.csv');
if isfile(stackFile)
    T = readtable(stackFile, 'TextType', 'string');
    for k = 1:height(T)
        name = char(string(T.parameter(k)));
        value = double(T.value(k));
        if ismember("stack_index", string(T.Properties.VariableNames)) && isfinite(T.stack_index(k))
            idx = round(T.stack_index(k));
            if idx >= 1
                if idx > numel(P.StackParam)
                    P.StackParam(idx) = 0;
                end
                P.StackParam(idx) = value;
            end
        end
        if isfield(P, name)
            P.(name) = value;
        end
    end
end
if isfile(egrFile)
    T = readtable(egrFile, 'TextType', 'string');
    for k = 1:height(T)
        name = char(string(T.parameter(k)));
        value = double(T.value(k));
        if isfield(P, name)
            P.(name) = value;
        end
    end
end
end

function P = buildSimplifiedInitialStates(P)
T0_K = P.bench_stack_in_T_C + 273.15;
pDry = max(P.bench_stack_in_p_kPa + P.p_amb_kPa, P.p_amb_kPa);
pV = min(max(P.bench_stack_in_RH, 0) * satKPa(P.bench_stack_in_T_C), 0.98 * pDry);
pO2 = max((pDry - pV) * P.xO2_dry, 1e-6);
pN2 = max((pDry - pV) * P.xN2_dry, 1e-6);
pH2 = max(P.p_anode_in_kPa * 0.85, 1e-6);
pH2OvAn = min(P.RH_an_in * satKPa(P.bench_stack_in_T_C), 0.30 * P.p_anode_in_kPa);
P.stack_initial_state = [
    pO2 * 1000 * P.V_ca_m3 * P.M_O2_kg_mol / (P.R_J_molK * T0_K)
    pN2 * 1000 * P.V_ca_m3 * P.M_N2_kg_mol / (P.R_J_molK * T0_K)
    pV * 1000 * P.V_ca_m3 * P.M_H2O_kg_mol / (P.R_J_molK * T0_K)
    pH2 * 1000 * P.V_an_m3 * P.M_H2_kg_mol / (P.R_J_molK * T0_K)
    pH2OvAn * 1000 * P.V_an_m3 * P.M_H2O_kg_mol / (P.R_J_molK * T0_K)
    P.bench_stack_in_T_C
    ];
P.egr_initial_node = zeros(7, 1);
P.egr_initial_node(5) = P.separator_T_C;
P.egr_initial_node(6) = P.separator_p_kPa + P.p_amb_kPa;
end

function assignSimplifiedWorkspace(P)
assignin('base', 'P_simplified_egr', P);
assignin('base', 'BenchBoundaryParam_simplified', P.BenchBoundaryParam);
assignin('base', 'EgrSplitParam_simplified', P.EgrSplitParam);
assignin('base', 'StackParam_simplified', P.StackParam);
assignin('base', 'I_stack_cmd_A_simplified', P.I_stack_default_A);
assignin('base', 'StackInitialState_simplified', P.stack_initial_state);
assignin('base', 'EGRInitialNode_simplified', P.egr_initial_node);
end

function r = interpNoEgr(T, currentA)
vars = T.Properties.VariableNames;
r = T(1, :);
for k = 1:numel(vars)
    v = T.(vars{k});
    if isnumeric(v)
        r.(vars{k}) = interp1(T.current_A, v, currentA, 'linear', 'extrap');
    end
end
end

function frac = deriveEgrFraction(T)
frac = T.egr_rate_cal;
missing = ~isfinite(frac);
calc1 = T.egr_flow_cal_SLPM ./ max(T.stack_in_flow_SLPM, 1e-12);
frac(missing & isfinite(calc1)) = calc1(missing & isfinite(calc1));
missing = ~isfinite(frac);
calc2 = (T.stack_in_flow_SLPM - T.bench_supply_flow_SLPM) ./ max(T.stack_in_flow_SLPM, 1e-12);
frac(missing & isfinite(calc2)) = calc2(missing & isfinite(calc2));
missing = ~isfinite(frac);
frac(missing) = T.egr_rate_raw(missing);
frac(~isfinite(frac)) = 0;
frac = min(max(frac, 0), 0.95);
end

function f = percentToFraction(v)
f = v;
idx = isfinite(f) & abs(f) > 1;
f(idx) = f(idx) / 100;
end

function v = finiteOr(a, b)
if isfinite(a)
    v = a;
else
    v = b;
end
end

function m = slpmAirToKgS(slpm)
m = slpm * 1.293 / 60000;
end

function p = satKPa(T)
Tc = min(max(T, -40), 120);
p = 0.61121 * exp((18.678 - Tc / 234.5) * (Tc / (257.14 + Tc)));
end

function y = num(x)
if isnumeric(x) && isscalar(x)
    y = x;
else
    y = str2double(string(x));
end
end

function n = PcellCount()
n = 16;
end
