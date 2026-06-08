function results = run_testbench_10kw_v01_pO2_DQ60_study(runMode)
%RUN_TESTBENCH_10KW_V01_PO2_DQ60_STUDY Constant inlet-pO2 study with DQ60 map.
%
% This study keeps the DQ60 map active and searches compressor flow scale
% plus DQ60 speed for each current/EGR point. It uses a copied model so that
% the fixed-flow constant-current and constant-voltage studies remain intact.

if nargin < 1 || strlength(string(runMode)) == 0
    runMode = "sample";
else
    runMode = string(runMode);
end

baseModel = "CEGR_TestBench_10kW_v01";
studyModel = "CEGR_TestBench_10kW_v01_pO2_DQ60";

P0 = init_testbench_10kw_v01(1, 0.0);
baseFile = fullfile(P0.rootDir, '01_模型', baseModel + ".slx");
studyFile = fullfile(P0.rootDir, '01_模型', studyModel + ".slx");
ensureStudyModel(baseModel, baseFile, studyModel, studyFile);

P0.modelName = char(studyModel);
P0.modelFile = char(studyFile);
P0.resultDir = fullfile(P0.rootDir, '04_验证结果');
P0.docDir = fullfile(P0.rootDir, '03_说明');

open_system(P0.modelFile);
originalInitFcn = get_param(P0.modelName, 'InitFcn');
cleanupInitFcn = onCleanup(@() set_param(P0.modelName, 'InitFcn', originalInitFcn));
set_param(P0.modelName, 'InitFcn', '');

if ~exist(P0.resultDir, 'dir')
    mkdir(P0.resultDir);
end

switch runMode
    case "sample"
        currentDensityTargets = 0.10;
        egrGrid = [0 0.05 0.25 0.50];
    case "two_point_j0p10_egr0p25"
        results = runTwoPointRepresentativeStudy(P0, studyModel, studyFile);
        return;
    case {"point_j0p10_egr0p00", "point_j0p10_egr0p05", "point_j0p10_egr0p10", "point_j0p10_egr0p15", "point_j0p10_egr0p20", "point_j0p10_egr0p25", "point_j0p10_egr0p30", "point_j0p10_egr0p35", "point_j0p10_egr0p40", "point_j0p10_egr0p45", "point_j0p10_egr0p50", ...
            "point_j0p20_egr0p00", "point_j0p20_egr0p05", "point_j0p20_egr0p10", "point_j0p20_egr0p15", "point_j0p20_egr0p20", "point_j0p20_egr0p25", "point_j0p20_egr0p30", "point_j0p20_egr0p35", "point_j0p20_egr0p40", "point_j0p20_egr0p45", "point_j0p20_egr0p50", ...
            "point_j0p30_egr0p00", "point_j0p30_egr0p05", "point_j0p30_egr0p10", "point_j0p30_egr0p15", "point_j0p30_egr0p20", "point_j0p30_egr0p25", "point_j0p30_egr0p30", "point_j0p30_egr0p35", "point_j0p30_egr0p40", "point_j0p30_egr0p45", "point_j0p30_egr0p50"}
        [jPoint, egrPoint] = parsePointMode(runMode);
        currentDensityTargets = jPoint;
        egrGrid = egrPoint;
    case "j0p10"
        currentDensityTargets = 0.10;
        egrGrid = 0:0.05:0.50;
    case "j0p20"
        currentDensityTargets = 0.20;
        egrGrid = 0:0.05:0.50;
    case "j0p30"
        currentDensityTargets = 0.30;
        egrGrid = 0:0.05:0.50;
    case "merge_existing"
        results = mergeExistingResults(P0.resultDir);
        return;
    case "all"
        currentDensityTargets = [0.10 0.20 0.30];
        egrGrid = 0:0.05:0.50;
    otherwise
        error('Unknown runMode "%s". Use sample, point_j0p10_egr0p05, j0p10, j0p20, j0p30, merge_existing, or all.', runMode);
end

rows = {};
for jTarget = currentDensityTargets
    caseIndex = caseIndexFromCurrentDensity(jTarget);
    Pbase = configureStudyCase(caseIndex, 0.0, jTarget, 1.0, 3000, studyModel, studyFile);
    baseRow = runCase(Pbase, "pO2_DQ60_noEGR_reference", caseIndex, 0.0);
    pO2Target = baseRow.pO2_ca_in_kPa;

    for egr = egrGrid
        if abs(egr) < 1e-12
            row = baseRow;
            row.condition = "constant_pO2_DQ60_speed_flow";
            row.solve_status = "no_egr_reference";
            row.pO2_ca_in_target_kPa = pO2Target;
            row.pO2_ca_in_target_error_kPa = row.pO2_ca_in_kPa - pO2Target;
            row.abs_pO2_error_kPa = abs(row.pO2_ca_in_target_error_kPa);
            row.pressure_order_ok = row.p_ca_in_kPa > row.p_stack_internal_kPa;
            [row.dq60_speed_min_flow_lpm, row.dq60_speed_max_flow_lpm, row.dq60_speed_flow_in_grid] = speedFlowEnvelope(row.dq60_speed_rpm, row.dq60_flow_lpm);
        else
            row = solveSpeedFlowForPO2(caseIndex, jTarget, egr, pO2Target, studyModel, studyFile);
        end
        row.condition_target = "pO2_ca_in";
        row.current_density_target_A_cm2 = jTarget;
        row.pO2_ca_in_noEGR_kPa = pO2Target;
        row.pO2_ca_in_target_kPa = pO2Target;
        row.pO2_ca_in_target_error_kPa = row.pO2_ca_in_kPa - pO2Target;
        row.air_flow_control = "solved_flow_and_DQ60_speed";
        row.lookup_quality = lookupQuality(abs(row.pO2_ca_in_target_error_kPa), 0.10, 0.30);
        rows{end + 1, 1} = row; %#ok<AGROW>
    end
end

rows = alignStructFields(rows);
T = structRowsToTable(rows);
T = addStudyCriteria(T);

suffix = char(runMode);
outFile = fullfile(P0.resultDir, sprintf('condition_study_constant_pO2_DQ60_speed_flow_%s.csv', suffix));
summaryFile = fullfile(P0.resultDir, sprintf('condition_study_constant_pO2_DQ60_speed_flow_%s_summary.md', suffix));
writetable(T, outFile);
writeSummary(summaryFile, T, currentDensityTargets, egrGrid);

results = struct();
results.table = T;
results.outputFile = outFile;
results.summaryFile = summaryFile;

fprintf('DQ60 constant-pO2 study complete: %s\n', outFile);
end

function ensureStudyModel(baseModel, baseFile, studyModel, studyFile)
if ~isfile(studyFile)
    open_system(baseFile);
    save_system(baseModel, studyFile);
end
open_system(studyFile);
if ~bdIsLoaded(studyModel)
    open_system(studyFile);
end
end

function [jTarget, egrTarget] = parsePointMode(runMode)
tokens = regexp(char(runMode), '^point_j(\d)p(\d+)_egr(\d)p(\d+)$', 'tokens', 'once');
if isempty(tokens)
    error('Bad point mode: %s.', runMode);
end
jTarget = str2double(tokens{1} + "." + tokens{2});
egrTarget = str2double(tokens{3} + "." + tokens{4});
end

function results = mergeExistingResults(resultDir)
files = string([
    fullfile(resultDir, 'condition_study_constant_pO2_DQ60_speed_flow_j0p10.csv')
    fullfile(resultDir, 'condition_study_constant_pO2_DQ60_speed_flow_j0p20.csv')
    fullfile(resultDir, 'condition_study_constant_pO2_DQ60_speed_flow_j0p30.csv')
    ]);
pointFiles = dir(fullfile(resultDir, 'condition_study_constant_pO2_DQ60_speed_flow_point_j*_egr*.csv'));
for k = 1:numel(pointFiles)
    files(end + 1, 1) = string(fullfile(pointFiles(k).folder, pointFiles(k).name)); %#ok<AGROW>
end
tables = {};
for k = 1:numel(files)
    if isfile(files(k))
        tables{end + 1, 1} = readtable(files(k), 'TextType', 'string'); %#ok<AGROW>
    end
end
if isempty(tables)
    T = table();
else
    T = alignTables(tables);
    T = deduplicateMergedGrid(T);
end
outFile = fullfile(resultDir, 'condition_study_constant_pO2_DQ60_speed_flow.csv');
summaryFile = fullfile(resultDir, 'condition_study_constant_pO2_DQ60_speed_flow_summary.md');
if ~isempty(T)
    writetable(T, outFile);
    writeSummary(summaryFile, T, unique(T.current_density_target_A_cm2).', unique(T.egr_fraction_cmd).');
end
results = struct();
results.table = T;
results.outputFile = outFile;
results.summaryFile = summaryFile;
fprintf('Merged DQ60 constant-pO2 results: %s\n', outFile);
end

function T = deduplicateMergedGrid(T)
if isempty(T) || ~all(ismember(["current_density_target_A_cm2", "egr_fraction_cmd"], string(T.Properties.VariableNames)))
    return;
end
key = compose('%.6g|%.6g', T.current_density_target_A_cm2, T.egr_fraction_cmd);
[~, keep] = unique(key, 'stable');
T = T(keep, :);
end

function results = runTwoPointRepresentativeStudy(P0, studyModel, studyFile)
jTarget = 0.10;
egrTarget = 0.25;
caseIndex = caseIndexFromCurrentDensity(jTarget);

Pbase = configureStudyCase(caseIndex, 0.0, jTarget, 1.0, 3000, studyModel, studyFile);
baseRow = runCase(Pbase, "constant_pO2_DQ60_two_point", caseIndex, 0.0);
pO2Target = baseRow.pO2_ca_in_kPa;
baseRow.case_label = "baseline_j0p10_EGR0";
baseRow.solve_status = "no_egr_reference";

repRow = solveSpeedFlowForPO2(caseIndex, jTarget, egrTarget, pO2Target, studyModel, studyFile);
repRow.condition = "constant_pO2_DQ60_two_point";
repRow.case_label = "representative_j0p10_EGR0p25_DQ60_solved_min_stable_flow";

rows = {baseRow; repRow};
for k = 1:numel(rows)
    rows{k}.condition_target = "pO2_ca_in";
    rows{k}.current_density_target_A_cm2 = jTarget;
    rows{k}.pO2_ca_in_noEGR_kPa = pO2Target;
    rows{k}.pO2_ca_in_target_kPa = pO2Target;
    rows{k}.pO2_ca_in_target_error_kPa = rows{k}.pO2_ca_in_kPa - pO2Target;
    rows{k}.abs_pO2_error_kPa = abs(rows{k}.pO2_ca_in_target_error_kPa);
    rows{k}.pressure_order_ok = rows{k}.p_ca_in_kPa > rows{k}.p_stack_internal_kPa;
    [rows{k}.dq60_speed_min_flow_lpm, rows{k}.dq60_speed_max_flow_lpm, rows{k}.dq60_speed_flow_in_grid] = speedFlowEnvelope(rows{k}.dq60_speed_rpm, rows{k}.dq60_flow_lpm);
    rows{k}.air_flow_control = "two_point_solved_min_stable_DQ60_flow";
    rows{k}.lookup_quality = lookupQuality(rows{k}.abs_pO2_error_kPa, 0.10, 0.30);
end

rows = alignStructFields(rows);
T = structRowsToTable(rows);
T = addStudyCriteria(T);
comparison = buildTwoPointComparison(T);

outFile = fullfile(P0.resultDir, 'condition_study_constant_pO2_DQ60_two_point_j0p10_egr0p25.csv');
comparisonFile = fullfile(P0.resultDir, 'condition_study_constant_pO2_DQ60_two_point_j0p10_egr0p25_comparison.csv');
summaryFile = fullfile(P0.resultDir, 'condition_study_constant_pO2_DQ60_two_point_j0p10_egr0p25_summary.md');
writetable(T, outFile);
writetable(comparison, comparisonFile);
writeTwoPointSummary(summaryFile, T, comparison);

results = struct();
results.table = T;
results.comparison = comparison;
results.outputFile = outFile;
results.comparisonFile = comparisonFile;
results.summaryFile = summaryFile;

fprintf('Two-point DQ60 constant-pO2 study complete: %s\n', comparisonFile);
end

function comparison = buildTwoPointComparison(T)
base = T(T.egr_fraction_cmd == 0, :);
if height(base) ~= 1
    error('Expected exactly one no-EGR baseline row.');
end
comparison = table();
comparison.case_label = T.case_label;
comparison.current_density_A_cm2 = T.current_density_command_A_cm2;
comparison.EGR = T.egr_fraction_cmd;
comparison.air_flow_scale = T.air_flow_scale;
comparison.cathode_flow_nlpm = T.cathode_flow_nlpm_cmd;
comparison.dq60_speed_rpm = T.dq60_speed_rpm;
comparison.dq60_flow_lpm = T.dq60_flow_lpm;
comparison.dq60_dp_kPa = T.dq60_dp_kPa;
comparison.dq60_power_W = T.dq60_power_W;
comparison.dq60_operating_map_ok = T.dq60_operating_map_ok;
comparison.xO2_ca_in = T.xO2_ca_in;
comparison.pO2_ca_in_kPa = T.pO2_ca_in_kPa;
comparison.delta_pO2_ca_in_kPa = T.pO2_ca_in_kPa - base.pO2_ca_in_kPa;
comparison.V_cell_sim = T.V_cell_sim;
comparison.delta_V_cell_sim = T.V_cell_sim - base.V_cell_sim;
comparison.P_stack_sim_W = T.P_stack_sim_W;
comparison.delta_P_stack_sim_W = T.P_stack_sim_W - base.P_stack_sim_W;
comparison.lambda_O2_actual = T.lambda_O2_actual;
comparison.RH_ca_in = T.RH_ca_in;
comparison.T_stack_C = T.T_stack_C;
comparison.risk_label = T.risk_label;
comparison.normal_operation_ok = T.normal_operation_ok;
end

function rowBest = solveSpeedFlowForPO2(caseIndex, jTarget, egr, pO2Target, studyModel, studyFile)
speedGrid = [3000 4000 5000 6000 7000 8000];
baseP = configureStudyCase(caseIndex, egr, jTarget, 1.0, 3000, studyModel, studyFile);
maxScale = min(24.0, max(1.0, 1200.0 / max(baseP.cathode_flow_nlpm, 1e-6)));
flowGrid = unique([1.0 1.2 1.5 1.8 2.0 2.5 3.0 4.0 5.0 6.0 8.0 12.0 16.0]);
flowGrid = flowGrid(flowGrid <= maxScale + 1e-12);

trials = runTrialGrid(caseIndex, jTarget, egr, pO2Target, speedGrid, flowGrid, studyModel, studyFile);
best = selectBestTrial(trials);

refineSpeeds = unique(min(max([best.dq60_speed_rpm - 500, best.dq60_speed_rpm, best.dq60_speed_rpm + 500], 3000), 8000));
refineScaleLo = max(1.0, best.air_flow_scale * 0.85);
refineScaleHi = min(maxScale, best.air_flow_scale * 1.15);
refineFlows = unique(linspace(refineScaleLo, refineScaleHi, 3));
refineTrials = runTrialGrid(caseIndex, jTarget, egr, pO2Target, refineSpeeds, refineFlows, studyModel, studyFile);

allTrials = [trials; refineTrials];
rowBest = selectBestTrial(allTrials);
rowBest.condition = "constant_pO2_DQ60_speed_flow";
rowBest.solve_status = solveStatus(rowBest);
end

function T = runTrialGrid(caseIndex, jTarget, egr, pO2Target, speedGrid, flowGrid, studyModel, studyFile)
rows = {};
for speed = speedGrid
    for scale = flowGrid
        P = configureStudyCase(caseIndex, egr, jTarget, scale, speed, studyModel, studyFile);
        row = runCase(P, "pO2_DQ60_search_trial", caseIndex, egr);
        row.pO2_ca_in_target_kPa = pO2Target;
        row.pO2_ca_in_target_error_kPa = row.pO2_ca_in_kPa - pO2Target;
        [row.dq60_speed_min_flow_lpm, row.dq60_speed_max_flow_lpm, row.dq60_speed_flow_in_grid] = speedFlowEnvelope(row.dq60_speed_rpm, row.dq60_flow_lpm);
        row.solve_status = "trial";
        rows{end + 1, 1} = row; %#ok<AGROW>
    end
end
rows = alignStructFields(rows);
T = structRowsToTable(rows);
end

function row = selectBestTrial(T)
T.abs_pO2_error_kPa = abs(T.pO2_ca_in_target_error_kPa);
T.pressure_order_ok = T.p_ca_in_kPa > T.p_stack_internal_kPa;
if ~ismember("is_dynamic_stable", string(T.Properties.VariableNames))
    T.is_dynamic_stable = true(height(T), 1);
end
if ~ismember("thermal_ok", string(T.Properties.VariableNames))
    T.thermal_ok = T.T_stack_C >= 45 & T.T_stack_C <= 90;
end
if ~ismember("humidity_ok", string(T.Properties.VariableNames))
    T.humidity_ok = T.RH_ca_in >= 0 & T.RH_ca_in <= 1.05;
end
T.pO2_target_ok = T.abs_pO2_error_kPa <= 0.10;
T.oxygen_ok = T.lambda_O2_actual >= 1.0 & T.pO2_ca_in_kPa >= 3.0;
T.dq60_operating_map_ok = T.dq60_speed_flow_in_grid & T.dq60_map_flow_clamped == 0;
usable = T.pO2_target_ok & T.oxygen_ok & T.thermal_ok & T.humidity_ok ...
    & T.pressure_order_ok & T.dq60_operating_map_ok & T.is_dynamic_stable;
if any(usable)
    candidates = T(usable, :);
    candidates = sortrows(candidates, ["air_flow_scale", "abs_pO2_error_kPa", "dq60_speed_rpm"]);
elseif any(T.dq60_operating_map_ok & T.pressure_order_ok & T.is_dynamic_stable)
    candidates = T(T.dq60_operating_map_ok & T.pressure_order_ok & T.is_dynamic_stable, :);
    candidates.selection_score = candidates.abs_pO2_error_kPa + 0.02 * candidates.air_flow_scale;
    candidates = sortrows(candidates, ["selection_score", "air_flow_scale", "dq60_speed_rpm"]);
elseif any(T.dq60_operating_map_ok & T.pressure_order_ok)
    candidates = T(T.dq60_operating_map_ok & T.pressure_order_ok, :);
    candidates.selection_score = candidates.abs_pO2_error_kPa + 0.05 * candidates.air_flow_scale + 10 * ~candidates.is_dynamic_stable;
    candidates = sortrows(candidates, ["selection_score", "air_flow_scale", "dq60_speed_rpm"]);
else
    candidates = T;
    candidates.selection_score = candidates.abs_pO2_error_kPa + 0.05 * candidates.air_flow_scale;
    candidates = sortrows(candidates, ["selection_score", "air_flow_scale", "dq60_speed_rpm"]);
end
row = table2struct(candidates(1, :));
end

function rows = alignStructFields(rows)
allFields = strings(0, 1);
for k = 1:numel(rows)
    allFields = union(allFields, string(fieldnames(rows{k})), 'stable');
end
for k = 1:numel(rows)
    missing = setdiff(allFields, string(fieldnames(rows{k})), 'stable');
    for f = missing.'
        rows{k}.(char(f)) = missingValueForField(char(f));
    end
    rows{k} = orderfields(rows{k}, cellstr(allFields));
end
end

function T = structRowsToTable(rows)
tables = cell(numel(rows), 1);
for k = 1:numel(rows)
    tables{k} = struct2table(rows{k});
end
T = vertcat(tables{:});
end

function T = alignTables(tables)
allNames = strings(0, 1);
for k = 1:numel(tables)
    allNames = union(allNames, string(tables{k}.Properties.VariableNames), 'stable');
end
for k = 1:numel(tables)
    missing = setdiff(allNames, string(tables{k}.Properties.VariableNames), 'stable');
    for name = missing.'
        tables{k}.(char(name)) = tableMissingColumn(char(name), height(tables{k}), tables);
    end
    tables{k} = tables{k}(:, cellstr(allNames));
end
T = vertcat(tables{:});
end

function col = tableMissingColumn(name, n, tables)
template = [];
for k = 1:numel(tables)
    if ismember(name, tables{k}.Properties.VariableNames)
        template = tables{k}.(name);
        break;
    end
end
if isstring(template)
    col = strings(n, 1);
elseif iscellstr(template)
    col = repmat({''}, n, 1);
elseif iscategorical(template)
    col = categorical(repmat(missing, n, 1), categories(template));
elseif islogical(template)
    col = false(n, 1);
elseif isnumeric(template)
    col = NaN(n, 1, 'like', template);
else
    col = repmat(missingValueForField(name), n, 1);
end
end

function value = missingValueForField(fieldName)
if endsWith(fieldName, "_ok") || startsWith(fieldName, "is_") || startsWith(fieldName, "dq60_") && endsWith(fieldName, "_in_grid")
    value = false;
elseif contains(fieldName, "status") || contains(fieldName, "label") || contains(fieldName, "quality") || contains(fieldName, "control") || fieldName == "condition" || fieldName == "case_id"
    value = "";
else
    value = NaN;
end
end

function status = solveStatus(row)
if isfield(row, 'is_dynamic_stable') && ~row.is_dynamic_stable
    status = "dynamic_oscillation";
elseif abs(row.pO2_ca_in_target_error_kPa) <= 0.10 && row.dq60_speed_flow_in_grid && row.pressure_order_ok && row.dq60_map_flow_clamped == 0 && row.lambda_O2_actual >= 1.0
    status = "solved_within_DQ60_map";
elseif abs(row.pO2_ca_in_target_error_kPa) <= 0.10 && row.dq60_speed_flow_in_grid && row.pressure_order_ok && row.dq60_map_flow_clamped == 0
    status = "pO2_solved_but_stack_oxygen_limited";
elseif abs(row.pO2_ca_in_target_error_kPa) <= 0.30
    status = "near_target_review_DQ60_boundary";
else
    status = "best_effort_unreachable_with_DQ60_map";
end
end

function P = configureStudyCase(caseIndex, egr, jTarget, flowScale, speedRpm, studyModel, studyFile)
P = init_testbench_10kw_v01(caseIndex, egr);
P.modelName = char(studyModel);
P.modelFile = char(studyFile);
P = applyCurrentDensity(P, jTarget);
P = rebuildScaledFlow(P, flowScale);
P = applyDQ60Speed(P, speedRpm);
end

function P = applyDQ60Speed(P, speedRpm)
P.dq60_speed_cmd_rpm = min(max(speedRpm, 3000), 8000);
P.DQ60MapParam = dq60_map_param_v01(P.dq60_speed_cmd_rpm);
P.CompressorParam = P.DQ60MapParam.vector;
end

function row = runCase(P, condition, boundaryCaseIndex, egr)
assignRunWorkspace(P);
simOut = sim(P.modelName, 'StopTime', num2str(P.stopTime_s), 'ReturnWorkspaceOutputs', 'on');
row = extractFinalRow(P, simOut, condition, boundaryCaseIndex, egr);
end

function row = extractFinalRow(P, simOut, condition, boundaryCaseIndex, egr)
summaryFinal = finalValue(simOut, 'summary_vector');
summaryWindow = signalWindow(simOut, 'summary_vector', P, 30);
summary = mean(summaryWindow, 2, 'omitnan');
fresh = windowMeanValue(simOut, 'bench_air_in_node', P, 30);
egrNode = windowMeanValue(simOut, 'egr_return_node', P, 30);
benchOut = windowMeanValue(simOut, 'bench_out_node', P, 30);
mixed = windowMeanValue(simOut, 'mixer_node', P, 30);
compressorOut = windowMeanValue(simOut, 'compressor_node', P, 30);
conditioned = windowMeanValue(simOut, 'bench_conditioned_node', P, 30);
separatorGas = windowMeanValue(simOut, 'separator_gas_node', P, 30);
stackCaOut = windowMeanValue(simOut, 'stack_ca_out_node', P, 30);
[~, dq60Diag] = dq60_map_apply_v01(mixed, P.CompressorParam);
lambdaWindow = summaryWindow(40, :);
mInWindow = summaryWindow(41, :);
pStackWindow = summaryWindow(5, :);
vCellWindow = summaryWindow(2, :);

row = struct();
row.condition = string(condition);
row.case_id = string(P.case_id);
row.boundary_case_index = boundaryCaseIndex;
row.boundary_current_A = P.current_A_boundary;
row.boundary_current_density_A_cm2 = P.current_density_boundary_A_cm2;
row.current_A = P.I_stack_default_A;
row.current_density_command_A_cm2 = round(P.I_stack_default_A / P.A_cell_cm2, 2);
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
row.lambda_O2_final_sample = summaryFinal(40);
row.lambda_O2_window_min = min(lambdaWindow, [], 'omitnan');
row.lambda_O2_window_max = max(lambdaWindow, [], 'omitnan');
row.lambda_O2_window_range = row.lambda_O2_window_max - row.lambda_O2_window_min;
row.m_ca_in_actual_kg_s = summary(41);
row.m_ca_in_final_sample_kg_s = summaryFinal(41);
row.ca_in_flowing_fraction_30s = mean(mInWindow > 1e-9, 'omitnan');
row.dV_cell_30s = max(vCellWindow, [], 'omitnan') - min(vCellWindow, [], 'omitnan');
row.dp_stack_internal_30s_kPa = max(pStackWindow, [], 'omitnan') - min(pStackWindow, [], 'omitnan');
row.is_dynamic_stable = row.dV_cell_30s <= 0.01 ...
    && row.dp_stack_internal_30s_kPa <= 1.0 ...
    && row.lambda_O2_window_range <= 0.5 ...
    && row.ca_in_flowing_fraction_30s >= 0.95;
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
P.current_density_command_A_cm2 = round(jCommand, 2);
P.current_A_boundary = P.I_stack_default_A;
P.current_density_boundary_A_cm2 = P.current_density_A_cm2;
P.I_stack_default_A = P.current_density_command_A_cm2 * P.A_cell_cm2;
P.case_id = sprintf('j%0.2f_boundary_%03dA', P.current_density_command_A_cm2, round(P.current_A_boundary));
end

function idx = caseIndexFromCurrentDensity(jTarget)
idx = round(jTarget / 0.1);
idx = min(max(idx, 1), 13);
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
data = signalMatrix(simOut, name);
value = data(:, end);
end

function value = windowMeanValue(simOut, name, P, window_s)
data = signalWindow(simOut, name, P, window_s);
value = mean(data, 2, 'omitnan');
end

function data = signalWindow(simOut, name, P, window_s)
data = signalMatrix(simOut, name);
if size(data, 2) <= 1
    return;
end
windowN = max(1, min(size(data, 2), round(window_s / max(P.dt_s, eps)) + 1));
idxStart = size(data, 2) - windowN + 1;
data = data(:, idxStart:end);
end

function data = signalMatrix(simOut, name)
raw = simOut.get(name);
if isa(raw, 'timeseries')
    data = raw.Data;
elseif isstruct(raw) && isfield(raw, 'signals')
    data = raw.signals.values;
else
    data = raw;
end
if ndims(data) == 3
    data = squeeze(data);
    if size(data, 2) <= 100 && size(data, 1) > 100
        data = data.';
    end
elseif ismatrix(data)
    % Simulink To Workspace may be signal-by-time or time-by-signal.
    if size(data, 2) <= 100 && size(data, 1) > 100
        data = data.';
    end
else
    data = data(:);
end
if isvector(data)
    data = data(:);
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

function [minFlow, maxFlow, inGrid] = speedFlowEnvelope(speedRpm, flowLpm)
param = dq60_map_param_v01(speedRpm);
speedGrid = param.speed_grid_rpm(:);
minBySpeed = min(param.flow_grid_lpm, [], 2);
maxBySpeed = max(param.flow_grid_lpm, [], 2);
minFlow = interp1(speedGrid, minBySpeed, speedRpm, 'linear', 'extrap');
maxFlow = interp1(speedGrid, maxBySpeed, speedRpm, 'linear', 'extrap');
inGrid = flowLpm >= minFlow - 1e-9 && flowLpm <= maxFlow + 1e-9;
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

function T = addStudyCriteria(T)
T.study_type = repmat("constant_pO2_DQ60_speed_flow", height(T), 1);
T.pO2_target_ok = abs(T.pO2_ca_in_target_error_kPa) <= 0.10 | T.solve_status == "no_egr_reference";
T.oxygen_ok = T.lambda_O2_actual >= 1.0 & T.pO2_ca_in_kPa >= 3.0;
T.thermal_ok = T.T_stack_C >= 45 & T.T_stack_C <= 90;
T.humidity_ok = T.RH_ca_in >= 0 & T.RH_ca_in <= 1.05;
T.pressure_order_ok = T.p_ca_in_kPa > T.p_stack_internal_kPa;
if ~ismember("is_dynamic_stable", string(T.Properties.VariableNames))
    T.is_dynamic_stable = true(height(T), 1);
end
T.dq60_global_map_ok = T.dq60_map_flow_clamped == 0;
T.dq60_operating_map_ok = T.dq60_global_map_ok & T.dq60_speed_flow_in_grid;
T.normal_operation_ok = T.pO2_target_ok & T.oxygen_ok & T.thermal_ok & T.humidity_ok & T.pressure_order_ok & T.dq60_operating_map_ok & T.is_dynamic_stable;
T.risk_label = strings(height(T), 1);
for k = 1:height(T)
    if ~T.is_dynamic_stable(k)
        T.risk_label(k) = "dynamic_oscillation";
    elseif ~T.pO2_target_ok(k)
        T.risk_label(k) = "pO2_target_miss";
    elseif ~T.oxygen_ok(k)
        T.risk_label(k) = "oxygen_limit";
    elseif ~T.pressure_order_ok(k)
        T.risk_label(k) = "pressure_order";
    elseif ~T.dq60_operating_map_ok(k)
        T.risk_label(k) = "dq60_map_boundary";
    elseif ~T.thermal_ok(k)
        T.risk_label(k) = "thermal_limit";
    elseif ~T.humidity_ok(k)
        T.risk_label(k) = "humidity_limit";
    else
        T.risk_label(k) = "ok";
    end
end
end

function writeSummary(path, T, currentDensityTargets, egrGrid)
lines = [
    "# DQ60 Constant-pO2 Study Summary"
    ""
    "Date: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))
    ""
    "## Scope"
    ""
    "- Model: `CEGR_TestBench_10kW_v01_pO2_DQ60.slx`."
    "- Target: same-current no-EGR `pO2_ca_in_kPa`."
    "- Search variables: cathode flow scale and DQ60 speed, with DQ60 map retained."
    ""
    "## Inputs"
    ""
    sprintf("- Current-density targets: %s A/cm2.", mat2str(currentDensityTargets))
    sprintf("- EGR grid: %s.", mat2str(egrGrid))
    ""
    "## Results"
    ""
    sprintf("- Rows: %d.", height(T))
    sprintf("- Solved within DQ60 map: %d.", nnz(T.solve_status == "solved_within_DQ60_map" | T.solve_status == "no_egr_reference"))
    sprintf("- Near target / review: %d.", nnz(T.solve_status == "near_target_review_DQ60_boundary"))
    sprintf("- Best-effort unreachable: %d.", nnz(T.solve_status == "best_effort_unreachable_with_DQ60_map"))
    sprintf("- Normal-operation rows: %d/%d.", nnz(T.normal_operation_ok), height(T))
    ""
    "## Output"
    ""
    "- `04_验证结果/condition_study_constant_pO2_DQ60_speed_flow.csv`"
    ];
writeText(path, lines);
end

function writeTwoPointSummary(path, T, comparison)
base = comparison(comparison.EGR == 0, :);
rep = comparison(comparison.EGR > 0, :);
lines = [
    "# DQ60 Constant-pO2 Two-Point Summary"
    ""
    "Date: " + string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'))
    ""
    "## Scope"
    ""
    "- Model: `CEGR_TestBench_10kW_v01_pO2_DQ60.slx`."
    "- Study mode: two-point comparison using the same DQ60 flow-compensation search logic as the grid study."
    "- Baseline: 0.1 A/cm2, EGR = 0."
    "- Representative point: 0.1 A/cm2, EGR = 0.25, solved for minimum stable DQ60 flow compensation."
    "- Target: compare EGR=0.25 against same-current no-EGR `pO2_ca_in_kPa`."
    ""
    "## Key Comparison"
    ""
    sprintf("- Baseline pO2_ca_in: %.4f kPa.", base.pO2_ca_in_kPa)
    sprintf("- EGR=0.25 pO2_ca_in: %.4f kPa; delta: %.4f kPa.", rep.pO2_ca_in_kPa, rep.delta_pO2_ca_in_kPa)
    sprintf("- EGR=0.25 DQ60 operating point: %.1f L/min at %.0f rpm; flow scale = %.3f; map-ok = %d.", rep.dq60_flow_lpm, rep.dq60_speed_rpm, rep.air_flow_scale, rep.dq60_operating_map_ok)
    sprintf("- EGR=0.25 voltage delta vs baseline: %.6f V/cell.", rep.delta_V_cell_sim)
    sprintf("- EGR=0.25 risk label: `%s`; normal operation = %d.", rep.risk_label, rep.normal_operation_ok)
    ""
    "## Outputs"
    ""
    "- `04_验证结果/condition_study_constant_pO2_DQ60_two_point_j0p10_egr0p25.csv`"
    "- `04_验证结果/condition_study_constant_pO2_DQ60_two_point_j0p10_egr0p25_comparison.csv`"
    ""
    sprintf("- Full rows: %d.", height(T))
    ];
writeText(path, lines);
end

function writeText(path, lines)
fid = fopen(path, 'w', 'n', 'UTF-8');
if fid < 0
    error('Cannot write %s.', path);
end
cleanup = onCleanup(@() fclose(fid));
for k = 1:numel(lines)
    fprintf(fid, '%s\n', lines(k));
end
end
