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
P = init_testbench_10kw_simplified_defaults();
P.rootDir = rootDir;
P.projectRoot = projectRoot;
P.modelName = 'CEGR_TestBench_10kW_SimplifiedEGR_v01';
P.modelFile = fullfile(rootDir, '01_模型', [P.modelName '.slx']);
addpath(fullfile(rootDir, '01_模型'));
P.stopTime_s = 120;
P.dt_s = 0.02;

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
P.I_stack_default_A = requireFinite(row, "current_A");
P.current_density_A_cm2 = requireFinite(row, "current_density_A_cm2");
P.cell_voltage_bench_V = requireFinite(row, "cell_voltage_V");
P.egr_fraction_cmd = min(max(requireFinite(row, "egr_fraction_model"), 0), 0.95);

P.stack_in_flow_SLPM = requireFinite(row, "stack_in_flow_meter_SLPM");
P.stack_in_flow_kg_s = slpmAirToKgS(P.stack_in_flow_SLPM);
P.fresh_supply_flow_SLPM = requireFinite(row, "bench_supply_flow_SLPM");
P.fresh_supply_flow_kg_s = slpmAirToKgS(P.fresh_supply_flow_SLPM);

P.bench_stack_in_T_C = requireFinite(row, "stack_in_T_C");
P.bench_stack_in_p_kPa = requireFinite(row, "stack_in_p_kPa");
P.bench_stack_in_RH = percentToFraction(requireFinite(row, "stack_in_RH_pct"));
P.bench_supply_gas_T_C = finiteOr(row.bench_supply_T_C, row.stack_in_T_C);
P.bench_supply_gas_p_kPa = finiteOr(row.bench_supply_p_actual_kPa, row.stack_in_p_kPa);
P.bench_supply_gas_RH = percentToFraction(finiteOr(row.bench_supply_RH_pct, row.stack_in_RH_pct));
[P.cathode_supply_wO2, P.cathode_supply_wN2, P.cathode_supply_wH2O] = ...
    humidAirMassFractions(P, P.bench_supply_gas_p_kPa + P.p_amb_kPa, ...
    P.bench_supply_gas_T_C, P.bench_supply_gas_RH);
P.stack_out_p_kPa = row.stack_out_p_kPa;
P.stack_out_T_C = row.stack_out_T_C;
P.cathode_dp_kPa = row.cathode_dp_kPa;
P.egr_return_T_C = row.egr_return_T_C;
P.egr_return_p_kPa = row.egr_return_p_kPa;
P.egr_return_RH = percentToFraction(row.egr_return_RH_pct);
if P.egr_fraction_cmd > 0
    P.separator_T_C = requireFinite(row, "egr_return_T_C");
    P.separator_p_kPa = requireFinite(row, "egr_return_p_kPa");
else
    P.separator_T_C = finiteOr(row.stack_out_T_C, row.bench_out_T_C);
    P.separator_p_kPa = finiteOr(row.stack_out_p_kPa, row.bench_out_p_kPa);
end

ref = interpNoEgr(noEgr, P.I_stack_default_A);
P.anode_stoich = requireFinite(row, "anode_stoich");
P.RH_an_in = percentToFraction(requireFinite(row, "anode_in_RH_pct"));
P.anode_in_T_C = requireFinite(row, "anode_in_T_C");
P.p_anode_in_kPa = requireFinite(row, "anode_in_p_kPa") + P.p_amb_kPa;
P.p_anode_back_kPa = requireFinite(row, "anode_out_p_kPa") + P.p_amb_kPa;
P.anode_H2_dry_flow_kg_s = P.anode_stoich * ...
    P.I_stack_default_A * P.N_cell / (2 * P.F_C_mol) * P.M_H2_kg_mol;
[P.anode_in_wH2, P.anode_in_wH2O, P.anode_in_flow_kg_s] = ...
    humidHydrogenMassFractions(P, P.anode_H2_dry_flow_kg_s, ...
    P.p_anode_in_kPa, P.anode_in_T_C, P.RH_an_in);
P.p_cathode_back_kPa = requireFinite(row, "stack_out_p_kPa") + P.p_amb_kPa;
P.T_cool_C = finiteOr(row.coolant_in_T_C, ref.coolant_in_T_C);
P.coolant_out_C = finiteOr(row.coolant_out_T_C, ref.coolant_out_T_C);
P.coolant_flow_L_min = requireFinite(row, "coolant_flow_L_min");

% Bench replay uses measured stack inlet mass flow as the inlet boundary.
end

function P = buildSimplifiedBenchParams(P)
P.egr_fraction_cmd_raw = P.egr_fraction_cmd;
if P.egr_fraction_cmd <= 0
    P.egr_fraction_cmd = 0.0;
end

P.PhysicalParam = buildPhysicalParam(P);
P.StackModelParam = buildStackModelParam(P);
P.CaseBoundaryParam = buildCaseBoundaryParam(P);
P.CoolingCurveParam = buildCoolingCurveParam(P);
P.dt_s_simplified = P.dt_s;
end

function param = buildPhysicalParam(P)
param = [
    P.R_J_molK
    P.F_C_mol
    P.M_O2_kg_mol
    P.M_N2_kg_mol
    P.M_H2O_kg_mol
    P.M_H2_kg_mol
    P.p_amb_kPa
    P.T_amb_C
    ];
end

function param = buildStackModelParam(P)
param = [
    P.N_cell
    P.A_cell_cm2
    P.V_ca_m3
    P.V_an_m3
    P.K_ca_out_kg_s_kPa
    P.K_an_out_kg_s_kPa
    P.C_stack_J_K
    P.h_cool_W_K
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
    P.book_theta5
    P.book_theta6
    P.book_theta7
    P.tau_mem_s
    ];
end

function param = buildCaseBoundaryParam(P)
param = [
    P.I_stack_default_A
    P.bench_stack_in_p_kPa + P.p_amb_kPa
    P.bench_stack_in_T_C
    P.stack_in_flow_kg_s
    P.cathode_supply_wO2
    P.cathode_supply_wN2
    P.cathode_supply_wH2O
    P.p_cathode_back_kPa
    P.separator_T_C
    P.separator_p_kPa + P.p_amb_kPa
    P.egr_fraction_cmd
    P.anode_in_flow_kg_s
    P.anode_in_wH2
    P.anode_in_wH2O
    P.p_anode_back_kPa
    P.T_cool_C
    P.coolant_flow_L_min
    ];
end

function param = buildCoolingCurveParam(P)
param = [
    P.cool_flow_curve_enabled
    P.cool_flow_curve_L_min(:)
    P.cool_flow_curve_h_W_K(:)
    ];
end

function P = readLocalCalibration(P)
P.tau_mem_s = 1.0;

paramDir = fullfile(P.rootDir, '00_输入参数', '标定参数');
stackFile = fullfile(paramDir, 'simplified_noegr_stack_params.csv');
if isfile(stackFile)
    T = readtable(stackFile, 'TextType', 'string');
    for k = 1:height(T)
        name = char(string(T.parameter(k)));
        value = double(T.value(k));
        if isfield(P, name)
            P.(name) = value;
        elseif ismember("stack_model_index", string(T.Properties.VariableNames)) && isfinite(T.stack_model_index(k))
            idx = round(T.stack_model_index(k));
            P = applyLocalStackModelIndex(P, idx, value);
        end
    end
end
end

function P = applyLocalStackModelIndex(P, idx, value)
switch idx
    case 12
        P.book_theta1 = value;
    case 14
        P.book_theta3 = value;
    case 15
        P.book_theta4 = value;
    case 17
        P.book_theta8 = value;
    case 18
        P.book_theta9 = value;
    case 19
        P.book_theta10 = value;
    case 24
        P.tau_mem_s = value;
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
    0
    ];
P.egr_initial_node = zeros(7, 1);
P.egr_initial_node(5) = P.separator_T_C;
P.egr_initial_node(6) = P.separator_p_kPa + P.p_amb_kPa;
end

function assignSimplifiedWorkspace(P)
assignin('base', 'P_simplified_egr', P);
assignin('base', 'PhysicalParam_simplified', P.PhysicalParam);
assignin('base', 'StackModelParam_simplified', P.StackModelParam);
assignin('base', 'CaseBoundaryParam_simplified', P.CaseBoundaryParam);
assignin('base', 'CoolingCurveParam_simplified', P.CoolingCurveParam);
assignin('base', 'dt_s_simplified', P.dt_s_simplified);
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

function [wO2, wN2, wH2O] = humidAirMassFractions(P, pAbsKPa, T_C, RH)
pH2O = min(max(RH, 0) * satKPa(T_C), 0.98 * pAbsKPa);
yH2O = min(max(pH2O / max(pAbsKPa, 1e-6), 0), 0.98);
yO2 = (1 - yH2O) * P.xO2_dry;
yN2 = (1 - yH2O) * P.xN2_dry;
mO2 = yO2 * P.M_O2_kg_mol;
mN2 = yN2 * P.M_N2_kg_mol;
mH2O = yH2O * P.M_H2O_kg_mol;
s = max(mO2 + mN2 + mH2O, 1e-12);
wO2 = mO2 / s;
wN2 = mN2 / s;
wH2O = mH2O / s;
end

function [wH2, wH2O, totalFlow] = humidHydrogenMassFractions(P, dryH2Flow, pAbsKPa, T_C, RH)
pH2O = min(max(RH, 0) * satKPa(T_C), 0.98 * pAbsKPa);
vaporRatio = max(pH2O, 0) / max(pAbsKPa - pH2O, 1e-6);
vaporFlow = dryH2Flow / P.M_H2_kg_mol * vaporRatio * P.M_H2O_kg_mol;
totalFlow = max(dryH2Flow + vaporFlow, 1e-12);
wH2 = dryH2Flow / totalFlow;
wH2O = vaporFlow / totalFlow;
end

function v = finiteOr(a, b)
if isfinite(a)
    v = a;
else
    v = b;
end
end

function v = requireFinite(row, name)
v = row.(name);
if ~isfinite(v)
    error('CEGR:SimplifiedBench:MissingRequiredValue', ...
        'Missing required numeric value "%s" for case %s.', ...
        name, string(row.case_id));
end
end

function m = slpmAirToKgS(slpm)
m = slpm * 1.293 / 60000;
end

function p = satKPa(T)
Tc = min(max(T, -40), 120);
p = 0.61121 * exp((18.678 - Tc / 234.5) * (Tc / (257.14 + Tc)));
end
