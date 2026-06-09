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

[noEgr, egr, allCases] = readSimplifiedBenchData(rootDir, projectRoot);
P.noEgrTable = noEgr;
P.egrTable = egr;
P.allCaseTable = allCases;
P.dataMode = dataMode;
assignin('base', 'NoEGRBenchData_simplified', noEgr);
assignin('base', 'EGRBenchData_simplified', egr);
assignin('base', 'AllBenchData_simplified', allCases);

if dataMode == "all" || dataMode == "combined"
    cases = allCases;
elseif dataMode == "initial_noegr"
    cases = allCases(string(allCases.source_dataset) == "initial_noegr_steady_xlsx", :);
elseif dataMode == "cegr0608"
    cases = allCases(string(allCases.source_dataset) == "cegr_0608_txt", :);
elseif dataMode == "noegr"
    cases = noEgr;
elseif dataMode == "egr"
    cases = egr;
else
    error('CEGR:SimplifiedBench:BadMode', ...
        'dataMode must be "all", "initial_noegr", "cegr0608", "noegr", or "egr".');
end
if isempty(cases)
    error('CEGR:SimplifiedBench:NoCases', 'No cases available for dataMode "%s".', dataMode);
end
caseIndex = max(1, min(height(cases), round(caseIndex)));
row = cases(caseIndex, :);
P.caseIndex = caseIndex;
P.case_id = char(string(row.case_id));
P.source_dataset = char(string(row.source_dataset));
P = configureFromUnifiedRow(P, row, noEgr);
P = readLocalCalibration(P);
P = buildSimplifiedBenchParams(P);
P = buildSimplifiedInitialStates(P);
assignSimplifiedWorkspace(P);

if verbose
    fprintf('Initialized %s case %s, EGR %.4f.\n', ...
        P.modelName, P.case_id, P.egr_fraction_cmd);
end
end

function [noEgr, egr, allCases] = readSimplifiedBenchData(rootDir, ~)
dataFile = fullfile(rootDir, '00_输入参数', '实验数据', 'combined_noegr_cegr_fit_points.csv');
if ~isfile(dataFile)
    error('CEGR:SimplifiedBench:MissingData', 'Cannot find %s', dataFile);
end
allCases = readtable(dataFile, 'TextType', 'string');
allCases.case_index = (1:height(allCases)).';
allCases = normalizeUnifiedTable(allCases);
noEgr = allCases(allCases.is_no_egr == 1, :);
egr = allCases(allCases.is_no_egr == 0, :);
end

function T = normalizeUnifiedTable(T)
stringVars = ["case_id", "source_dataset", "source_file", "section", "date_label", ...
    "condition_note", "egr_fraction_source", "fresh_flow_lambda_use_note", ...
    "stoich_basis_note", "parse_notes"];
for k = 1:numel(stringVars)
    if ismember(stringVars(k), string(T.Properties.VariableNames))
        T.(stringVars(k)) = string(T.(stringVars(k)));
    end
end
numericVars = setdiff(string(T.Properties.VariableNames), stringVars);
for k = 1:numel(numericVars)
    name = numericVars(k);
    if iscell(T.(name)) || isstring(T.(name)) || ischar(T.(name))
        T.(name) = str2double(string(T.(name)));
    end
end
required = ["case_id", "source_dataset", "current_A", "current_density_A_cm2", ...
    "cell_voltage_V", "egr_fraction_model", "is_no_egr", ...
    "stack_in_flow_meter_SLPM", "stack_in_p_kPa", "stack_out_p_kPa"];
missing = setdiff(required, string(T.Properties.VariableNames));
if ~isempty(missing)
    error('CEGR:SimplifiedBench:BadDataTable', ...
        'Combined fitting table is missing required columns: %s', strjoin(missing, ', '));
end
end

function P = configureFromUnifiedRow(P, row, noEgr)
P.I_stack_default_A = row.current_A;
P.current_density_A_cm2 = row.current_density_A_cm2;
P.cell_voltage_bench_V = row.cell_voltage_V;
P.egr_fraction_cmd = min(max(finiteOr(row.egr_fraction_model, 0.0), 0), 0.95);
P.egr_valve_target_pct = finiteOr(row.egr_valve_target_pct, 0.0);
P.egr_valve_input_pct = finiteOr(row.egr_valve_input_pct, 0.0);

P.stack_in_flow_SLPM = finiteOr(row.stack_in_flow_meter_SLPM, row.bench_supply_flow_SLPM);
P.stack_in_flow_kg_s = slpmAirToKgS(P.stack_in_flow_SLPM);
P.fresh_supply_flow_SLPM = finiteOr(row.bench_supply_flow_SLPM, ...
    P.stack_in_flow_SLPM * (1 - P.egr_fraction_cmd));
P.fresh_supply_flow_kg_s = slpmAirToKgS(P.fresh_supply_flow_SLPM);

P.bench_stack_in_T_C = finiteOr(row.stack_in_T_C, row.bench_supply_T_C);
P.bench_stack_in_p_kPa = finiteOr(row.stack_in_p_kPa, row.bench_supply_p_actual_kPa);
P.bench_stack_in_RH = percentToFraction(finiteOr(row.stack_in_RH_pct, row.bench_supply_RH_pct));
P.stack_out_p_kPa = row.stack_out_p_kPa;
P.stack_out_T_C = row.stack_out_T_C;
P.cathode_dp_kPa = row.cathode_dp_kPa;
P.separator_T_C = finiteOr(row.stack_out_T_C, row.bench_out_T_C);
P.separator_p_kPa = finiteOr(row.stack_out_p_kPa, row.bench_out_p_kPa);

ref = interpNoEgr(noEgr, P.I_stack_default_A);
P.anode_stoich = finiteOr(row.anode_stoich, ref.anode_stoich);
P.RH_an_in = percentToFraction(finiteOr(row.anode_in_RH_pct, ref.anode_in_RH_pct));
P.p_anode_in_kPa = finiteOr(row.anode_in_p_kPa, ref.anode_in_p_kPa) + P.p_amb_kPa;
P.p_anode_back_kPa = finiteOr(row.anode_out_p_kPa, ref.anode_out_p_kPa) + P.p_amb_kPa;
P.p_cathode_back_kPa = finiteOr(row.stack_out_p_kPa, row.bench_out_p_kPa) + P.p_amb_kPa;
P.T_cool_C = finiteOr(row.coolant_in_T_C, ref.coolant_in_T_C);
P.coolant_out_C = finiteOr(row.coolant_out_T_C, ref.coolant_out_T_C);
P.coolant_flow_L_min = finiteOr(row.coolant_flow_L_min, ref.coolant_flow_L_min);

% First core-fix pass: measured stack inlet flow is the inlet mass boundary.
% Keep the inlet coefficient diagnostic-only instead of back-fitting it per point.
P.K_ca_in_kg_s_kPa = 1.0e6;
end

function P = buildSimplifiedBenchParams(P)
P.egr_fraction_cmd_raw = P.egr_fraction_cmd;
if P.egr_fraction_cmd > 0
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
% First core-fix pass: do not use direct EGR voltage penalty terms.
P.egr_loss_k_V = 0.0;
P.egr_loss_exp = 1.0;
P.egr_loss_rh_V = 0.0;
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
T = T(string(T.source_dataset) == "initial_noegr_steady_xlsx", :);
if isempty(T)
    error('CEGR:SimplifiedBench:MissingReferenceNoEgr', ...
        'No initial no-EGR rows are available for anode/coolant fallback interpolation.');
end
r = T(1, :);
for k = 1:numel(vars)
    v = T.(vars{k});
    if isnumeric(v)
        valid = isfinite(T.current_A) & isfinite(v);
        if nnz(valid) >= 2
            r.(vars{k}) = interp1(T.current_A(valid), v(valid), currentA, 'linear', 'extrap');
        elseif nnz(valid) == 1
            r.(vars{k}) = v(find(valid, 1, 'first'));
        else
            r.(vars{k}) = NaN;
        end
    end
end
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
