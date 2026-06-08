function results = run_testbench_10kw_v01_condition_study(runMode)
%RUN_TESTBENCH_10KW_V01_CONDITION_STUDY Bench EGR condition studies.
%
% Routes:
% 1) Constant current: j = 0.10/0.20/0.30 A/cm2, fixed compressor flow
%    referenced to the corresponding no-EGR bench point.
% 2) Constant voltage: V = 0.800/0.775/0.750 V/cell. For each voltage target,
%    the no-EGR solved current selects one bench supply boundary; all EGR
%    points then keep that external supply boundary fixed.
% 3) Constant inlet pO2: j = 0.10/0.20/0.30 A/cm2, pO2_ca_in target equals
%    same-current no-EGR pO2_ca_in; compressor flow is solved by air_flow_scale.

if nargin < 1 || strlength(string(runMode)) == 0
    runMode = "all";
else
    runMode = string(runMode);
end

P0 = init_testbench_10kw_v01(1, 0.0);
open_system(P0.modelFile);
originalInitFcn = get_param(P0.modelName, 'InitFcn');
cleanupInitFcn = onCleanup(@() set_param(P0.modelName, 'InitFcn', originalInitFcn));
set_param(P0.modelName, 'InitFcn', '');

if ~exist(P0.resultDir, 'dir')
    mkdir(P0.resultDir);
end
if ~exist(P0.docDir, 'dir')
    mkdir(P0.docDir);
end

egrGrid = 0:0.05:0.50;
currentDensityTargets = [0.10 0.20 0.30];
voltageTargets = [0.800 0.775 0.750];

ccFile = fullfile(P0.resultDir, 'condition_study_constant_current_egr_scan.csv');
cvFile = fullfile(P0.resultDir, 'condition_study_constant_voltage_solved.csv');
po2File = fullfile(P0.resultDir, 'condition_study_constant_pO2_inlet_solved.csv');
criteriaFile = fullfile(P0.resultDir, 'condition_study_unified_criteria.csv');
summaryFile = fullfile(P0.resultDir, 'condition_study_summary.md');
docFile = fullfile(P0.docDir, '下一阶段EGR工况研究计划.md');

switch runMode
    case "all"
        cc = runConstantCurrentStudy(currentDensityTargets, egrGrid);
        cv = runConstantVoltageStudy(voltageTargets, egrGrid);
        po2 = runConstantPO2InletStudy(currentDensityTargets, egrGrid);
    case "summarize_existing"
        cc = readExistingTable(ccFile);
        cv = readExistingTable(cvFile);
        po2 = readExistingTable(po2File);
    case "constant_current"
        cc = runConstantCurrentStudy(currentDensityTargets, egrGrid);
        cv = table();
        po2 = table();
    case "constant_voltage"
        cc = table();
        cv = runConstantVoltageStudy(voltageTargets, egrGrid);
        po2 = table();
    case "constant_pO2_inlet"
        cc = table();
        cv = table();
        po2 = runConstantPO2InletStudy(currentDensityTargets, egrGrid);
    otherwise
        error('Unknown runMode "%s". Use all, summarize_existing, constant_current, constant_voltage, or constant_pO2_inlet.', runMode);
end

cc = addUnifiedCriteria(cc, "constant_current_fixed_flow");
cv = addUnifiedCriteria(cv, "constant_voltage_fixed_noEGR_boundary");
po2 = addUnifiedCriteria(po2, "constant_pO2_inlet_variable_flow");
criteria = combineCriteriaTables(cc, cv, po2);

if ~isempty(cc)
    writetable(cc, ccFile);
end
if ~isempty(cv)
    writetable(cv, cvFile);
end
if ~isempty(po2)
    writetable(po2, po2File);
end
writetable(criteria, criteriaFile);
writeSummary(summaryFile, cc, cv, po2, criteria, currentDensityTargets, voltageTargets, egrGrid);
writePlanDoc(docFile, currentDensityTargets, voltageTargets, egrGrid);

results = struct();
results.constant_current = cc;
results.constant_voltage = cv;
results.constant_pO2_inlet = po2;
results.criteria = criteria;

fprintf('Condition study complete: %s\n', summaryFile);
end

function T = runConstantCurrentStudy(currentDensityTargets, egrGrid)
rows = {};
for jTarget = currentDensityTargets
    caseIndex = caseIndexFromCurrentDensity(jTarget);
    for egr = egrGrid
        P = init_testbench_10kw_v01(caseIndex, egr);
        P.current_density_command_A_cm2 = jTarget;
        P.air_flow_scale = 1.0;
        P = rebuildScaledFlow(P, 1.0);
        row = runCase(P, "constant_current_fixed_flow", caseIndex, egr);
        row.current_density_target_A_cm2 = jTarget;
        row.air_flow_control = "fixed_noEGR_reference";
        rows{end + 1, 1} = struct2table(row); %#ok<AGROW>
    end
end
T = vertcat(rows{:});
end

function T = runConstantVoltageStudy(voltageTargets, egrGrid)
rows = {};
for vTarget = voltageTargets(:).'
    [~, rowNoEGRProbe] = solveCurrentForVoltage(vTarget, 0.0);
    fixedCaseIndex = rowNoEGRProbe.boundary_case_index;
    Pboundary = init_testbench_10kw_v01(fixedCaseIndex, 0.0);
    fixedBoundaryCurrentA = Pboundary.I_stack_default_A;
    fixedBoundaryCurrentDensity = Pboundary.current_density_A_cm2;
    for egr = egrGrid
        [Pbest, rowBest] = solveCurrentForVoltage(vTarget, egr, fixedCaseIndex);
        rowBest.condition_target = "V_cell";
        rowBest.V_cell_target = vTarget;
        rowBest.V_cell_target_error = rowBest.V_cell_sim - vTarget;
        rowBest.current_density_solved_A_cm2 = round(Pbest.current_density_command_A_cm2, 3);
        rowBest.fixed_noEGR_boundary_case_index = fixedCaseIndex;
        rowBest.fixed_noEGR_boundary_current_A = fixedBoundaryCurrentA;
        rowBest.fixed_noEGR_boundary_current_density_A_cm2 = fixedBoundaryCurrentDensity;
        rowBest.fixed_noEGR_boundary_source = "EGR0_voltage_solution_nearest_bench";
        rowBest.air_flow_control = "fixed_noEGR_boundary_selected_at_EGR0";
        rowBest.lookup_quality = lookupQuality(abs(rowBest.V_cell_target_error), 0.003, 0.008);
        rows{end + 1, 1} = struct2table(rowBest); %#ok<AGROW>
    end
end
T = vertcat(rows{:});
end

function T = runConstantPO2InletStudy(currentDensityTargets, egrGrid)
rows = {};
for jTarget = currentDensityTargets
    caseIndex = caseIndexFromCurrentDensity(jTarget);
    Pbase = init_testbench_10kw_v01(caseIndex, 0.0);
    Pbase = rebuildScaledFlow(Pbase, 1.0);
    baseRow = runCase(Pbase, "pO2_baseline_noEGR", caseIndex, 0.0);
    pO2Target = baseRow.pO2_ca_in_kPa;

    for egr = egrGrid
        if abs(egr) < 1e-12
            P = Pbase;
            row = baseRow;
            row.condition = "constant_pO2_inlet_variable_flow";
        else
            [P, row] = solveAirFlowForPO2(caseIndex, egr, pO2Target);
        end
        row.condition_target = "pO2_ca_in";
        row.current_density_target_A_cm2 = jTarget;
        row.pO2_ca_in_noEGR_kPa = pO2Target;
        row.pO2_ca_in_target_kPa = pO2Target;
        row.pO2_ca_in_target_error_kPa = row.pO2_ca_in_kPa - pO2Target;
        row.air_flow_scale = P.air_flow_scale;
        row.air_flow_control = "solved_for_pO2_ca_in";
        if ~isfield(row, 'solve_status')
            row.solve_status = "solved";
        end
        row.lookup_quality = lookupQuality(abs(row.pO2_ca_in_target_error_kPa), 0.10, 0.30);
        rows{end + 1, 1} = struct2table(row); %#ok<AGROW>
    end
end
T = vertcat(rows{:});
end

function [Pbest, rowBest] = solveCurrentForVoltage(vTarget, egr, fixedCaseIndex)
if nargin < 3
    fixedCaseIndex = [];
end
jLo = 0.05;
jHi = 0.60;
candidates = unique(round([jLo, jHi, linspace(jLo, jHi, 12)], 3));
rows = cell(numel(candidates), 1);
for k = 1:numel(candidates)
    rows{k} = struct2table(runVoltageCandidate(candidates(k), egr, fixedCaseIndex));
end
T = vertcat(rows{:});

for iter = 1:10
    T = sortrows(T, "current_density_command_A_cm2");
    err = T.V_cell_sim - vTarget;
    crossIdx = find(err(1:end-1) .* err(2:end) <= 0, 1);
    if isempty(crossIdx)
        break;
    end
    jl = T.current_density_command_A_cm2(crossIdx);
    jh = T.current_density_command_A_cm2(crossIdx + 1);
    jNew = round(0.5 * (jl + jh), 3);
    if any(abs(T.current_density_command_A_cm2 - jNew) < 1e-12)
        break;
    end
    T = [T; struct2table(runVoltageCandidate(jNew, egr, fixedCaseIndex))]; %#ok<AGROW>
end

T = sortrows(T, "current_density_command_A_cm2");
[~, idxBest] = min(abs(T.V_cell_sim - vTarget));
rowBest = table2struct(T(idxBest, :));
caseIndex = rowBest.boundary_case_index;
Pbest = init_testbench_10kw_v01(caseIndex, egr);
Pbest = applyCurrentDensity(Pbest, rowBest.current_density_command_A_cm2);
Pbest.air_flow_scale = 1.0;
end

function row = runVoltageCandidate(jCommand, egr, fixedCaseIndex)
if nargin < 3
    fixedCaseIndex = [];
end
jRounded = round(jCommand, 3);
if isempty(fixedCaseIndex)
    caseIndex = nearestCaseIndexForCurrentDensity(jRounded);
    condition = "constant_voltage_boundary_probe";
else
    caseIndex = fixedCaseIndex;
    condition = "constant_voltage_fixed_noEGR_boundary";
end
P = init_testbench_10kw_v01(caseIndex, egr);
P = applyCurrentDensity(P, jRounded);
P = rebuildScaledFlow(P, 1.0);
row = runCase(P, condition, caseIndex, egr);
row.current_density_command_A_cm2 = jRounded;
end

function T = readExistingTable(path)
if isfile(path)
    T = readtable(path, 'TextType', 'string');
else
    T = table();
end
end

function [Pbest, rowBest] = solveAirFlowForPO2(caseIndex, egr, pO2Target)
scaleLo = 1.0;
scaleHi = 3.0;
Plo = init_testbench_10kw_v01(caseIndex, egr);
Plo = rebuildScaledFlow(Plo, scaleLo);
rowLo = runCase(Plo, "constant_pO2_inlet_variable_flow", caseIndex, egr);
Phi = init_testbench_10kw_v01(caseIndex, egr);
Phi = rebuildScaledFlow(Phi, scaleHi);
rowHi = runCase(Phi, "constant_pO2_inlet_variable_flow", caseIndex, egr);

if rowLo.pO2_ca_in_kPa >= pO2Target
    Pbest = Plo;
    rowBest = rowLo;
    rowBest.solve_status = "fixed_flow_already_meets_target";
    return;
end

maxScale = 6.0;
while rowHi.pO2_ca_in_kPa < pO2Target && scaleHi < maxScale
    scaleHi = scaleHi * 1.5;
    Phi = init_testbench_10kw_v01(caseIndex, egr);
    Phi = rebuildScaledFlow(Phi, scaleHi);
    rowHi = runCase(Phi, "constant_pO2_inlet_variable_flow", caseIndex, egr);
end

if rowHi.pO2_ca_in_kPa < pO2Target
    Pbest = Phi;
    rowBest = rowHi;
    rowBest.solve_status = "unreachable_with_current_DQ60_map";
    return;
end

Pbest = Phi;
rowBest = rowHi;
bestErr = abs(rowHi.pO2_ca_in_kPa - pO2Target);
for iter = 1:7
    scaleMid = 0.5 * (scaleLo + scaleHi);
    Pmid = init_testbench_10kw_v01(caseIndex, egr);
    Pmid = rebuildScaledFlow(Pmid, scaleMid);
    rowMid = runCase(Pmid, "constant_pO2_inlet_variable_flow", caseIndex, egr);
    errMid = rowMid.pO2_ca_in_kPa - pO2Target;
    if abs(errMid) < bestErr
        Pbest = Pmid;
        rowBest = rowMid;
        bestErr = abs(errMid);
    end
    if errMid >= 0
        scaleHi = scaleMid;
    else
        scaleLo = scaleMid;
    end
end
rowBest.solve_status = "solved";
end

function row = runCase(P, condition, boundaryCaseIndex, egr)
P = ensureBoundaryFields(P);
assignRunWorkspace(P);
simOut = sim(P.modelName, 'StopTime', num2str(P.stopTime_s), 'ReturnWorkspaceOutputs', 'on');
row = extractFinalRow(P, simOut, condition, boundaryCaseIndex, egr);
end

function P = ensureBoundaryFields(P)
if ~isfield(P, 'current_A_boundary')
    P.current_A_boundary = P.I_stack_default_A;
end
if ~isfield(P, 'current_density_boundary_A_cm2')
    P.current_density_boundary_A_cm2 = P.current_density_A_cm2;
end
if ~isfield(P, 'air_flow_scale')
    P.air_flow_scale = 1.0;
end
end

function row = extractFinalRow(P, simOut, condition, boundaryCaseIndex, egr)
summary = finalValue(simOut, 'summary_vector');
fresh = finalValue(simOut, 'bench_air_in_node');
egrNode = finalValue(simOut, 'egr_return_node');
benchOut = finalValue(simOut, 'bench_out_node');
mixed = finalValue(simOut, 'mixer_node');
compressorOut = finalValue(simOut, 'compressor_node');
conditioned = finalValue(simOut, 'bench_conditioned_node');
separatorGas = finalValue(simOut, 'separator_gas_node');
stackCaOut = finalValue(simOut, 'stack_ca_out_node');
[~, dq60Diag] = dq60_map_apply_v01(mixed, P.CompressorParam);

row = struct();
row.condition = string(condition);
row.case_id = string(P.case_id);
row.boundary_case_index = boundaryCaseIndex;
row.boundary_current_A = P.current_A_boundary;
row.boundary_current_density_A_cm2 = P.current_density_boundary_A_cm2;
row.current_A = P.I_stack_default_A;
row.current_density_command_A_cm2 = round(P.I_stack_default_A / P.A_cell_cm2, 3);
row.egr_fraction_cmd = egr;
row.air_flow_scale = P.air_flow_scale;
row.cathode_flow_nlpm_cmd = P.cathode_flow_nlpm;
row.V_cell_sim = summary(2);
row.P_stack_sim_W = summary(3);
row.pO2_stack_kPa = summary(4);
row.p_stack_internal_kPa = summary(5);
row.T_stack_C = summary(9);
row.Q_net_stack_W = summary(22);
row.Q_gen_W = summary(32);
row.Q_cool_W = summary(33);
row.Q_amb_W = summary(34);
row.Q_gas_W = summary(35);
row.lambda_O2_actual = summary(40);
row.m_bench_air_in_kg_s = sum(fresh(1:3));
row.m_egr_return_kg_s = sum(egrNode(1:3));
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
row.h_cool_effective_W_K = row.Q_cool_W / max(row.T_stack_C - P.T_cool_C, 1e-9);
end

function P = applyCurrentDensity(P, jCommand)
P.current_density_command_A_cm2 = round(jCommand, 3);
P.current_A_boundary = P.I_stack_default_A;
P.current_density_boundary_A_cm2 = P.current_density_A_cm2;
P.I_stack_default_A = P.current_density_command_A_cm2 * P.A_cell_cm2;
P.case_id = sprintf('j%0.3f_boundary_%03dA', P.current_density_command_A_cm2, round(P.current_A_boundary));
end

function idx = caseIndexFromCurrentDensity(jTarget)
idx = round(jTarget / 0.1);
idx = min(max(idx, 1), 13);
end

function idx = nearestCaseIndexForCurrentDensity(jTarget)
benchJ = [0.10 0.20 0.30 0.40 0.60 0.70 0.90 1.10 1.30 1.50 1.70 1.80 1.90];
[~, idx] = min(abs(benchJ - jTarget));
end

function P = rebuildScaledFlow(P, flowScale)
P.air_flow_scale = flowScale;
P.cathode_flow_nlpm = P.cathode_flow_nlpm * flowScale;
P.cathode_flow_kg_s = P.cathode_flow_kg_s * flowScale;
P.K_ca_in_kg_s_kPa = P.K_ca_in_kg_s_kPa * flowScale;
P.BenchAirParam(12) = P.cathode_flow_kg_s;
P.StackParam(38) = P.K_ca_in_kg_s_kPa;
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

function quality = lookupQuality(absErr, goodLimit, reviewLimit)
if absErr <= goodLimit
    quality = "good";
elseif absErr <= reviewLimit
    quality = "review";
else
    quality = "coarse_grid";
end
end

function T = addUnifiedCriteria(T, studyType)
if isempty(T)
    return;
end
T.study_type = repmat(string(studyType), height(T), 1);
T.oxygen_ok = T.lambda_O2_actual >= 1.0 & T.pO2_ca_in_kPa >= 3.0;
T.thermal_ok = T.T_stack_C >= 45 & T.T_stack_C <= 90;
T.humidity_ok = T.RH_ca_in >= 0 & T.RH_ca_in <= 1.05;
T.pressure_order_ok = T.p_ca_in_kPa > T.p_stack_internal_kPa;
T.dq60_map_ok = T.dq60_map_flow_clamped == 0;
T.normal_operation_ok = T.oxygen_ok & T.thermal_ok & T.humidity_ok & T.pressure_order_ok;
T.risk_label = strings(height(T), 1);
for k = 1:height(T)
    if ~T.oxygen_ok(k)
        T.risk_label(k) = "oxygen_limit";
    elseif ~T.pressure_order_ok(k)
        T.risk_label(k) = "pressure_order";
    elseif ~T.thermal_ok(k)
        T.risk_label(k) = "thermal_limit";
    elseif ~T.humidity_ok(k)
        T.risk_label(k) = "humidity_limit";
    elseif ~T.dq60_map_ok(k)
        T.risk_label(k) = "dq60_map_extrapolation";
    else
        T.risk_label(k) = "ok";
    end
end
end

function C = selectCriteriaColumns(T)
if isempty(T)
    C = table();
    return;
end
vars = [
    "study_type"
    "condition"
    "case_id"
    "current_A"
    "current_density_command_A_cm2"
    "egr_fraction_cmd"
    "air_flow_scale"
    "V_cell_sim"
    "V_cell_target"
    "V_cell_target_error"
    "pO2_ca_in_target_kPa"
    "pO2_ca_in_kPa"
    "pO2_ca_in_target_error_kPa"
    "lambda_O2_actual"
    "RH_ca_in"
    "T_stack_C"
    "solve_status"
    "normal_operation_ok"
    "oxygen_ok"
    "thermal_ok"
    "humidity_ok"
    "pressure_order_ok"
    "dq60_map_ok"
    "risk_label"
    ];
C = table();
for k = 1:numel(vars)
    varName = vars(k);
    if ismember(varName, string(T.Properties.VariableNames))
        C.(varName) = T.(varName);
    else
        C.(varName) = missingColumn(varName, height(T));
    end
end
end

function x = missingColumn(varName, n)
logicalVars = ["normal_operation_ok", "oxygen_ok", "thermal_ok", "humidity_ok", "pressure_order_ok", "dq60_map_ok"];
numericVars = ["current_A", "current_density_command_A_cm2", "egr_fraction_cmd", "air_flow_scale", "V_cell_sim", "V_cell_target", "V_cell_target_error", "pO2_ca_in_target_kPa", "pO2_ca_in_kPa", "pO2_ca_in_target_error_kPa", "lambda_O2_actual", "RH_ca_in", "T_stack_C"];
if ismember(varName, logicalVars)
    x = false(n, 1);
elseif ismember(varName, numericVars)
    x = NaN(n, 1);
else
    x = strings(n, 1);
end
end

function C = combineCriteriaTables(varargin)
C = table();
for k = 1:nargin
    Tk = selectCriteriaColumns(varargin{k});
    if isempty(Tk)
        continue;
    end
    if isempty(C)
        C = Tk;
    else
        C = vertcat(C, Tk); %#ok<AGROW>
    end
end
end

function writeSummary(path, cc, cv, po2, criteria, currentDensityTargets, voltageTargets, egrGrid)
lines = [
    "# Testbench EGR Condition Study Summary"
    ""
    "Date: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))
    ""
    "## Scope"
    ""
    "- Constant-current studies keep compressor flow fixed to the no-EGR bench reference for the selected current-density point."
    "- Constant-voltage studies first solve the no-EGR current for each voltage target, select the nearest no-EGR bench supply boundary once, and keep that external boundary fixed during the EGR scan."
    "- Constant-pO2-inlet study uses `pO2_ca_in` as target and solves air-flow scale after EGR is enabled."
    ""
    "## Inputs"
    ""
    sprintf("- Constant-current j targets: %s A/cm2.", mat2str(currentDensityTargets))
    sprintf("- Constant-voltage targets: %s V/cell.", mat2str(voltageTargets))
    sprintf("- EGR grid: %s.", mat2str(egrGrid))
    ""
    "## Results"
    ""
    sprintf("- Constant-current rows: %d.", height(cc))
    sprintf("- Constant-voltage solved rows: %d.", height(cv))
    sprintf("- Constant-pO2-inlet solved rows: %d.", height(po2))
    sprintf("- Unified criteria rows: %d.", height(criteria))
    sprintf("- Normal-operation points: %d/%d.", nnz(criteria.normal_operation_ok), height(criteria))
    sprintf("- Oxygen-limit points: %d.", nnz(criteria.risk_label == "oxygen_limit"))
    sprintf("- DQ60-map-extrapolation points: %d.", nnz(criteria.risk_label == "dq60_map_extrapolation"))
    ""
    "## Output Files"
    ""
    "- `04_验证结果/condition_study_constant_current_egr_scan.csv`"
    "- `04_验证结果/condition_study_constant_voltage_solved.csv`"
    "- `04_验证结果/condition_study_constant_pO2_inlet_solved.csv`"
    "- `04_验证结果/condition_study_unified_criteria.csv`"
    ];
writeText(path, lines);
end

function writePlanDoc(path, currentDensityTargets, voltageTargets, egrGrid)
lines = [
    "# 下一阶段EGR工况研究计划"
    ""
    "## 已确认口径"
    ""
    "- EGR 定义为 `m_EGR_return_gas / m_stack_cathode_out_gas`，脚本中使用 `egr_fraction_cmd`。"
    "- 恒电流和恒电压工况固定空气机流量，流量设定值以无循环时的台架流量为基准。"
    "- 恒入口氧分压工况不固定空气机流量，而是开启 EGR 后反求所需 `air_flow_scale`，使 `pO2_ca_in` 回到无 EGR 基准。"
    ""
    "## 工况"
    ""
    sprintf("- 恒电流：`j = %s A/cm2`，`EGR = %s`。", mat2str(currentDensityTargets), mat2str(egrGrid))
    sprintf("- 恒电压：`V_cell = %s V`，每个 EGR 下反求电流密度并保留三位小数。", mat2str(voltageTargets))
    "- 恒入口氧分压：在 0.10/0.20/0.30 A/cm2 下，以无 EGR `pO2_ca_in` 为目标，反求空气机流量倍率。"
    ""
    "## 说明"
    ""
    "- 恒电压反求得到的电流密度保留三位小数；压力、温度、湿度和冷却边界取最近台架测试点。"
    "- 当前 DQ60 map 低流量仍可能触发钳位，`dq60_map_ok=false` 作为警告保留。"
    ];
writeText(path, lines);
end

function writeText(path, lines)
fid = fopen(path, 'w', 'n', 'UTF-8');
if fid < 0
    error('Failed to write %s.', path);
end
cleanup = onCleanup(@() fclose(fid));
for k = 1:numel(lines)
    fprintf(fid, '%s\n', lines(k));
end
end
