function varargout = testbench_viz_utils(action, varargin)
%TESTBENCH_VIZ_UTILS Shared helpers for bench visualization scripts.

switch string(action)
    case "context"
        varargout{1} = makeContext();
    case "loadConstantCurrent"
        varargout{1} = loadConstantCurrent(varargin{:});
    case "loadConstantVoltage"
        varargout{1} = loadConstantVoltage(varargin{:});
    case "loadConstantPO2TwoPoint"
        [varargout{1:nargout}] = loadConstantPO2TwoPoint(varargin{:});
    case "loadNoEgrValidation"
        [varargout{1:nargout}] = loadNoEgrValidation(varargin{:});
    case "selectTopologyCase"
        varargout{1} = selectTopologyCase(varargin{:});
    case "plotBenchTopology"
        varargout{1} = plotBenchTopology(varargin{:});
    case "plotEgrMain"
        varargout{1} = plotEgrMain(varargin{:});
    case "plotEgrDiagnostics"
        varargout{1} = plotEgrDiagnostics(varargin{:});
    case "plotConstantPO2TwoPoint"
        varargout{1} = plotConstantPO2TwoPoint(varargin{:});
    case "plotNoEgrValidation"
        varargout{1} = plotNoEgrValidation(varargin{:});
    case "writeSheet"
        writeResultSheet(varargin{:});
    case "makeRunInfo"
        varargout{1} = makeRunInfo(varargin{:});
    case "closeFigures"
        closeFigures(varargin{:});
    otherwise
        error('CEGR:UnknownBenchVizAction', 'Unknown bench visualization action: %s', action);
end
end

function C = makeContext()
scriptDir = fileparts(mfilename('fullpath'));
C = struct();
C.rootDir = fileparts(scriptDir);
C.scriptDir = scriptDir;
C.model = 'CEGR_TestBench_10kW_v01';
C.modelFile = fullfile(C.rootDir, '01_模型', [C.model '.slx']);
C.resultDir = fullfile(C.rootDir, '04_验证结果');
C.workbookFile = fullfile(C.resultDir, 'CEGR_testbench_visualization_results.xlsx');
C.constantCurrentFile = fullfile(C.resultDir, 'condition_study_constant_current_egr_scan.csv');
C.constantVoltageFile = fullfile(C.resultDir, 'condition_study_constant_voltage_solved.csv');
C.constantPO2DQ60J0p10File = fullfile(C.resultDir, 'condition_study_constant_pO2_DQ60_speed_flow_j0p10.csv');
C.constantPO2TwoPointFile = fullfile(C.resultDir, 'condition_study_constant_pO2_DQ60_two_point_j0p10_egr0p25.csv');
C.constantPO2ComparisonFile = fullfile(C.resultDir, 'condition_study_constant_pO2_DQ60_two_point_j0p10_egr0p25_comparison.csv');
C.noEgrScanFile = fullfile(C.resultDir, 'testbench_constant_current_egr_scan.csv');
C.thermalDiagnosticFile = fullfile(C.resultDir, 'testbench_thermal_stageA_diagnostic.csv');
C.voltageFitDiagnosticFile = fullfile(C.resultDir, 'stack_voltage_internal_state_fit_diagnostic.csv');
C.benchConditionVoltageFitDiagnosticFile = fullfile(fileparts(C.rootDir), '01_车载系统_10kW_GZS60_v3', '04_验证结果', 'stack_voltage_bench_condition_fit_diagnostic.csv');
C.benchDataFile = fullfile(fileparts(fileparts(C.rootDir)), '00_支撑材料', '实验数据-设备说明书', '10kw短堆稳态测试_阴极尾气循环系统模型数据.txt');
if ~exist(C.resultDir, 'dir')
    mkdir(C.resultDir);
end
addpath(C.scriptDir);
end

function T = loadConstantCurrent(C)
T = readRequiredTable(C.constantCurrentFile);
T = ensureColumn(T, "current_density_target_A_cm2", T.current_density_command_A_cm2);
T = ensureColumn(T, "study_type", repmat("constant_current_fixed_flow", height(T), 1));
T = addInterpretationStatus(T);
T = sortrows(T, ["current_density_target_A_cm2", "egr_fraction_cmd"]);
end

function T = loadConstantVoltage(C)
T = readRequiredTable(C.constantVoltageFile);
T = ensureColumn(T, "study_type", repmat("constant_voltage_fixed_flow", height(T), 1));
T = addInterpretationStatus(T);
T = sortrows(T, ["V_cell_target", "egr_fraction_cmd"]);
end

function [T, comparison] = loadConstantPO2TwoPoint(C)
if isfile(C.constantPO2DQ60J0p10File)
    T = readRequiredTable(C.constantPO2DQ60J0p10File);
    T = T(abs(T.egr_fraction_cmd) < 1e-12 | abs(T.egr_fraction_cmd - 0.25) < 1e-12, :);
else
    T = readRequiredTable(C.constantPO2TwoPointFile);
end
T = addInterpretationStatus(T);
T = sortrows(T, "egr_fraction_cmd");
if isfile(C.constantPO2DQ60J0p10File)
    comparison = buildPO2Comparison(T);
elseif isfile(C.constantPO2ComparisonFile)
    comparison = readtable(C.constantPO2ComparisonFile, 'TextType', 'string');
else
    comparison = buildPO2Comparison(T);
end
end

function [T, stats] = loadNoEgrValidation(C)
scan = readRequiredTable(C.noEgrScanFile);
scan = scan(abs(scan.egr_fraction_cmd) < 1e-12, :);
scan = sortrows(scan, "case_index");

thermal = readRequiredTable(C.thermalDiagnosticFile);
thermal = sortrows(thermal, "case_index");

bench = readBenchTable(C.benchDataFile);
bench = sortrows(bench, "case_index");

if height(scan) ~= height(thermal) || height(scan) ~= height(bench) || ...
        any(scan.case_index ~= thermal.case_index) || any(scan.case_index ~= bench.case_index)
    error('CEGR:ValidationTableMismatch', 'No-EGR scan, thermal diagnostic, and bench data case indexes do not align.');
end

T = table();
T.case_index = scan.case_index;
T.case_id = scan.case_id;
T.current_A = scan.current_A;
T.current_density_A_cm2 = bench.current_density_A_cm2;
T.V_cell_bench = thermal.V_cell_bench;
T.V_cell_sim = scan.V_cell_sim;
T.T_stack_fit_C = thermal.T_stack_fit_C;
T.T_stack_C = scan.T_stack_C;
T.cathode_in_pressure_abs_kPa = bench.cathode_in_pressure_abs_kPa;
T.p_ca_in_kPa = scan.p_ca_in_kPa;
T.cathode_RH = bench.cathode_RH;
T.RH_ca_in = scan.RH_ca_in;
T.V_cell_err = T.V_cell_sim - T.V_cell_bench;
T.T_stack_err_C = T.T_stack_C - T.T_stack_fit_C;
T.p_ca_in_err_kPa = T.p_ca_in_kPa - T.cathode_in_pressure_abs_kPa;
T.RH_ca_in_err = T.RH_ca_in - T.cathode_RH;
T = addVoltageFitReplay(T, C.voltageFitDiagnosticFile);
T = sortrows(T, "current_density_A_cm2");

stats = table();
stats.metric = ["V_cell"; "V_cell_formula_fit"; "T_stack_C"; "p_ca_in_kPa"; "RH_ca_in"];
stats.rmse = [localRmse(T.V_cell_err); localRmse(T.V_cell_formula_fit_err); localRmse(T.T_stack_err_C); localRmse(T.p_ca_in_err_kPa); localRmse(T.RH_ca_in_err)];
stats.max_abs_error = [max(abs(T.V_cell_err)); max(abs(T.V_cell_formula_fit_err)); max(abs(T.T_stack_err_C)); max(abs(T.p_ca_in_err_kPa)); max(abs(T.RH_ca_in_err))];
stats.point_count = repmat(height(T), height(stats), 1);
end

function T = addVoltageFitReplay(T, diagnosticFile)
T.V_cell_formula_fit = nan(height(T), 1);
T.V_cell_formula_fit_err = nan(height(T), 1);
if ~isfile(diagnosticFile)
    diagnosticFile = '';
end
if strlength(string(diagnosticFile)) == 0 || ~isfile(diagnosticFile)
    return;
end
F = readtable(diagnosticFile, 'TextType', 'string');
vars = string(F.Properties.VariableNames);
candidateCol = "selected_candidate_V";
if ismember("internal_state_weighted_refit_V", vars)
    candidateCol = "internal_state_weighted_refit_V";
end
if ~all(ismember(["current_density_A_cm2", candidateCol], vars))
    return;
end
for k = 1:height(T)
    [deltaJ, idx] = min(abs(F.current_density_A_cm2 - T.current_density_A_cm2(k)));
    if deltaJ < 1e-9
        T.V_cell_formula_fit(k) = F.(char(candidateCol))(idx);
    end
end
T.V_cell_formula_fit_err = T.V_cell_formula_fit - T.V_cell_bench;
end

function B = readBenchTable(path)
if ~isfile(path)
    error('CEGR:MissingBenchData', 'Missing bench data file: %s', path);
end
lines = splitlines(string(fileread(path)));
headerIdx = find(startsWith(lines, '电流_A'), 1);
if isempty(headerIdx)
    error('CEGR:MissingBenchHeader', 'Cannot find bench table header in %s', path);
end
dataLines = lines(headerIdx + 1:end);
dataLines = dataLines(strlength(strtrim(dataLines)) > 0);
values = zeros(numel(dataLines), 33);
for k = 1:numel(dataLines)
    parts = split(dataLines(k), sprintf('\t'));
    values(k, :) = str2double(parts).';
end
B = table();
B.case_index = (1:size(values, 1)).';
B.current_A = values(:, 1);
B.current_density_A_cm2 = values(:, 2);
B.cathode_in_pressure_abs_kPa = values(:, 19) + 101.325;
B.cathode_RH = values(:, 16) / 100;
end

function T = readRequiredTable(path)
if ~isfile(path)
    error('CEGR:MissingBenchVizData', 'Missing visualization input table: %s', path);
end
T = readtable(path, 'TextType', 'string');
end

function T = ensureColumn(T, name, values)
if ~ismember(name, string(T.Properties.VariableNames))
    T.(char(name)) = values;
end
end

function T = addInterpretationStatus(T)
if ismember("interpretation_status", string(T.Properties.VariableNames))
    return;
end
status = strings(height(T), 1);
for k = 1:height(T)
    if ismember("risk_label", string(T.Properties.VariableNames)) && strlength(string(T.risk_label(k))) > 0
        status(k) = string(T.risk_label(k));
    elseif ismember("normal_operation_ok", string(T.Properties.VariableNames)) && logical(T.normal_operation_ok(k))
        status(k) = "ok";
    else
        status(k) = "review";
    end
end
T.interpretation_status = status;
end

function row = selectTopologyCase(T)
mask = abs(T.current_density_target_A_cm2 - 0.10) < 1e-9 & abs(T.egr_fraction_cmd - 0.30) < 1e-9;
if ~any(mask)
    mask = abs(T.current_density_target_A_cm2 - 0.10) < 1e-9;
end
if ~any(mask)
    mask = true(height(T), 1);
end
row = T(find(mask, 1, 'first'), :);
end

function fig = plotBenchTopology(rowTable)
row = table2struct(rowTable(1, :));
fig = figure('Name', 'Testbench 00 Bench Topology', 'Color', 'w');
ax = axes(fig);
axis(ax, [0 1 0 1]);
axis(ax, 'off');
hold(ax, 'on');

fig.Position(3:4) = [1260 720];
airColor = [0.10 0.38 0.67];
egrColor = [0.12 0.50 0.28];
stackColor = [0.70 0.18 0.14];
exhaustColor = [0.42 0.46 0.50];

drawPanel(ax, [0.018 0.875 0.964 0.095], '当前工况', [0.93 0.96 0.99], airColor);
drawPanel(ax, [0.025 0.565 0.950 0.285], '台架空气供给链路', [0.965 0.982 0.995], airColor);
drawPanel(ax, [0.025 0.200 0.950 0.315], '电堆反应与尾气循环', [0.985 0.978 0.968], stackColor);

boxes = {
    "台架空气入口", [0.035 0.625 0.170 0.200], sprintf('入口压力 %.1f kPa\n入口温度 %.1f C\n新鲜空气 %.5f kg/s\n固定流量倍率 %.2f', ...
        row.p_dq60_in_kPa, row.T_dq60_in_C, row.m_bench_air_in_kg_s, row.air_flow_scale), airColor, [0.91 0.96 1.00]
    "EGR混合器", [0.245 0.625 0.165 0.200], sprintf('循环比命令 %.2f\n实际循环比 %.2f\n新鲜空气 %.5f\n循环气 %.5f\n混合xO2 %.3f', ...
        row.egr_fraction_cmd, row.alpha_EGR_actual, row.m_bench_air_in_kg_s, row.m_egr_return_kg_s, row.xO2_ca_in), egrColor, [0.92 0.98 0.94]
    "DQ60空气机", [0.450 0.625 0.155 0.200], sprintf('转速 %.0f rpm\n流量 %.1f L/min\n压升 %.1f kPa\n功率 %.1f W', ...
        row.dq60_speed_rpm, row.dq60_flow_lpm, row.dq60_dp_kPa, row.dq60_power_W), airColor, [0.92 0.96 1.00]
    "阴极条件调节", [0.645 0.625 0.160 0.200], sprintf('入堆温度 %.1f C\n入堆压力 %.1f kPa\npO2 %.1f kPa\nRH %.2f', ...
        row.T_ca_in_C, row.p_ca_in_kPa, row.pO2_ca_in_kPa, row.RH_ca_in), airColor, [0.92 0.96 1.00]
    "PEMFC电堆", [0.720 0.260 0.250 0.230], sprintf('电流密度 %.2f A/cm2\n电流 %.2f A\n单电池电压 %.3f V  功率 %.0f W\n温度 %.1f C  氧计量比 %.2f\n入堆压力 %.1f kPa\n堆内压力 %.1f kPa', ...
        row.current_density_command_A_cm2, row.current_A, row.V_cell_sim, row.P_stack_sim_W, row.T_stack_C, row.lambda_O2_actual, row.p_ca_in_kPa, row.p_stack_internal_kPa), stackColor, [1.00 0.94 0.92]
    "气水分离器", [0.455 0.260 0.175 0.230], sprintf('分离气 %.5f kg/s\n液水排出 %.2g kg/s\n出口温度 %.1f C\n出口压力 %.1f kPa', ...
        row.m_separator_gas_kg_s, row.liquid_drain_separator_kg_s, row.T_separator_C, row.p_stack_internal_kPa), exhaustColor, [0.96 0.97 0.98]
    "EGR阀 / 排气", [0.180 0.260 0.220 0.230], sprintf('循环气 %.5f kg/s\n排气 %.5f kg/s\n实际EGR %.2f\n排气温度 %.1f C\n排气压力 %.1f kPa', ...
        row.m_egr_return_kg_s, row.m_bench_out_kg_s, row.alpha_EGR_actual, row.T_separator_C, row.p_stack_internal_kPa), egrColor, [0.94 0.98 0.94]
    };

for k = 1:size(boxes, 1)
    drawBox(ax, boxes{k, 2}, boxes{k, 1}, boxes{k, 3}, boxes{k, 4}, boxes{k, 5});
end

drawArrow(ax, [0.205 0.725], [0.245 0.725], airColor, 2.2, '-');
drawArrow(ax, [0.410 0.725], [0.450 0.725], airColor, 2.2, '-');
drawArrow(ax, [0.605 0.725], [0.645 0.725], airColor, 2.2, '-');
drawPolylineArrow(ax, [0.725 0.625; 0.800 0.545; 0.830 0.490], airColor, 2.0, '-');
drawArrow(ax, [0.720 0.375], [0.630 0.375], exhaustColor, 2.0, '-');
drawArrow(ax, [0.455 0.375], [0.400 0.375], exhaustColor, 2.0, '-');
drawArrow(ax, [0.180 0.375], [0.055 0.375], exhaustColor, 2.0, '-');
drawPolylineArrow(ax, [0.290 0.490; 0.345 0.560; 0.330 0.625], egrColor, 2.4, '--');

text(ax, 0.055, 0.560, '空气主流', 'FontSize', 9, 'FontWeight', 'bold', 'Color', airColor);
text(ax, 0.305, 0.545, 'EGR回流支路', 'FontSize', 9, 'FontWeight', 'bold', 'Color', egrColor);
text(ax, 0.070, 0.350, '排气', 'FontSize', 9, 'FontWeight', 'bold', 'Color', exhaustColor);

conditionText = sprintf(['单工况计算   电流密度 %.2f A/cm2   电流 %.2f A   EGR %.2f   ', ...
    '固定台架空气入口流量 %.2f   DQ60转速 %.0f rpm'], ...
    row.current_density_command_A_cm2, row.current_A, row.egr_fraction_cmd, row.air_flow_scale, row.dq60_speed_rpm);
text(ax, 0.050, 0.918, conditionText, 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none', 'Color', [0.10 0.12 0.14]);
title(ax, '10 kW短堆台架cEGR测试结构单工况仿真控制台', 'FontWeight', 'bold');
assignin('base', 'testbenchTopologyLayout', boxes);
end

function fig = plotEgrMain(T, studyType)
[groupVar, groupLabel, titlePrefix, fixedFlowText, metrics] = plotMainContext(T, studyType);
fig = figure('Name', figureNameFor(studyType, "Main"), 'Color', 'w');
tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
for k = 1:size(metrics, 1)
    nexttile;
    plotByGroup(T, groupVar, groupLabel, metrics{k, 1}, metrics{k, 2});
    title(metrics{k, 3});
    if string(metrics{k, 1}) == "lambda_O2_actual"
        yline(1.05, '--', 'warning', 'HandleVisibility', 'off');
        yline(1.00, ':', 'severe', 'HandleVisibility', 'off');
    end
end
sgtitle(titlePrefix + ": " + fixedFlowText);
end

function fig = plotEgrDiagnostics(T, studyType)
[groupVar, groupLabel, titlePrefix] = plotDiagnosticContext(studyType);
fig = figure('Name', figureNameFor(studyType, "Diagnostics"), 'Color', 'w');
tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
plotPressureChain(T, groupVar, groupLabel);
title('Bench pressure chain');
ylabel('kPa');

nexttile;
plotMultiByGroup(T, groupVar, groupLabel, ["dq60_flow_lpm", "dq60_dp_kPa"], ["DQ60 flow L/min", "DQ60 dp kPa"]);
title('DQ60 flow and pressure rise');
ylabel('value');

nexttile;
plotByGroup(T, groupVar, groupLabel, "dq60_power_W", "DQ60 power (W)");
title('DQ60 power');

nexttile;
plotMultiByGroup(T, groupVar, groupLabel, ["m_bench_air_in_kg_s", "m_egr_return_kg_s", "m_bench_out_kg_s"], ...
    ["fresh air", "EGR return", "bench out"]);
title('Bench mass flows');
ylabel('kg/s');

nexttile;
plotMultiByGroup(T, groupVar, groupLabel, ["Q_gen_W", "Q_cool_W", "Q_amb_W", "Q_gas_W"], ...
    ["gen", "cool", "amb", "gas"]);
title('Stack heat terms');
ylabel('W');

nexttile;
plotStatusMap(T, groupVar, groupLabel);
title('Risk label');

sgtitle(titlePrefix + " diagnostics");
end

function fig = plotConstantPO2TwoPoint(T, comparison)
fig = figure('Name', 'Testbench 05 Constant pO2 DQ60 Two Point', 'Color', 'w');
tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
x = 1:height(T);
labels = shortPO2Labels(T);

nexttile;
bar(x, T.pO2_ca_in_kPa);
hold on;
yline(T.pO2_ca_in_target_kPa(1), '--', 'target', 'HandleVisibility', 'off');
formatPO2Axis(x, labels);
ylabel('pO2 cathode in (kPa)');
title('Constant inlet pO2 target');
grid on;

nexttile;
yyaxis left;
plot(x, T.V_cell_sim, '-o', 'LineWidth', 1.4);
ylabel('V_{cell} (V)');
yyaxis right;
plot(x, T.P_stack_sim_W, '-s', 'LineWidth', 1.4);
ylabel('Stack power (W)');
formatPO2Axis(x, labels);
title('Voltage and power');
grid on;

nexttile;
bar(x, T.lambda_O2_actual);
hold on;
yline(1.05, '--', 'warning', 'HandleVisibility', 'off');
yline(1.00, ':', 'severe', 'HandleVisibility', 'off');
formatPO2Axis(x, labels);
ylabel('Actual O2 stoich (-)');
title('Oxygen stoich');
grid on;

nexttile;
yyaxis left;
plot(x, T.dq60_flow_lpm, '-o', 'LineWidth', 1.4);
ylabel('DQ60 flow (L/min)');
yyaxis right;
plot(x, T.dq60_speed_rpm, '-s', 'LineWidth', 1.4);
ylabel('DQ60 speed (rpm)');
formatPO2Axis(x, labels);
title('DQ60 operating point');
grid on;

nexttile;
yyaxis left;
bar(x, T.air_flow_scale);
ylabel('Air flow scale (-)');
yyaxis right;
plot(x, T.cathode_flow_nlpm_cmd, '-o', 'LineWidth', 1.4);
ylabel('Cathode flow command (NLPM)');
formatPO2Axis(x, labels);
title('Air supply command');
grid on;

nexttile;
plot(x, T.p_ca_in_kPa, '-o', 'LineWidth', 1.4, 'DisplayName', 'cathode inlet');
formatPO2Axis(x, labels);
ylabel('Cathode inlet pressure (kPa abs)');
title('Cathode inlet pressure');
grid on;

sgtitle('Constant pO2: 0.1 A/cm2 EGR=0 baseline vs EGR=0.25 DQ60 representative point');

if nargin >= 2 && ~isempty(comparison)
    assignin('base', 'testbenchConstantPO2TwoPointComparison', comparison);
end
end

function fig = plotNoEgrValidation(T, stats)
fig = figure('Name', 'Testbench 06 No-EGR Validation', 'Color', 'w');
tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
j = T.current_density_A_cm2;

nexttile;
plotVoltageCompare(j, T, stats);

nexttile;
plotCompare(j, T.T_stack_fit_C, T.T_stack_C, 'T_{stack} (degC)');
title(sprintf('Stack temperature  RMSE %.2f degC', metricRmse(stats, "T_stack_C")));

nexttile;
plotCompare(j, T.cathode_in_pressure_abs_kPa, T.p_ca_in_kPa, 'Cathode inlet pressure (kPa abs)');
title(sprintf('Cathode inlet pressure  RMSE %.2f kPa', metricRmse(stats, "p_ca_in_kPa")));

nexttile;
plotCompare(j, T.cathode_RH, T.RH_ca_in, 'Cathode inlet RH (-)');
title(sprintf('Cathode inlet humidity  RMSE %.3f RH', metricRmse(stats, "RH_ca_in")));

sgtitle('Testbench no-EGR validation against bench data');
end

function [groupVar, groupLabel, titlePrefix, fixedFlowText, metrics] = plotMainContext(~, studyType)
studyType = string(studyType);
if studyType == "constant_voltage"
    groupVar = "V_cell_target";
    groupLabel = "V";
    titlePrefix = "Testbench Constant Voltage";
    fixedFlowText = "fixed no-EGR supply boundary selected at EGR=0";
    metrics = {
        "current_A", "Current (A)", "Current response"
        "current_density_command_A_cm2", "Current density (A/cm^2)", "Current density response"
        "P_stack_sim_W", "Stack power (W)", "Stack power"
        "pO2_ca_in_kPa", "pO2 cathode in (kPa)", "Oxygen dilution"
        "lambda_O2_actual", "Actual O2 stoich (-)", "Oxygen stoich"
        "T_stack_C", "T_{stack} (degC)", "Stack temperature"
        };
else
    groupVar = "current_density_target_A_cm2";
    groupLabel = "A/cm2";
    titlePrefix = "Testbench Constant Current";
    fixedFlowText = "fixed no-EGR bench compressor flow";
    metrics = {
        "V_cell_sim", "V_{cell} (V)", "Cell voltage"
        "P_stack_sim_W", "Stack power (W)", "Stack power"
        "pO2_ca_in_kPa", "pO2 cathode in (kPa)", "Oxygen dilution"
        "lambda_O2_actual", "Actual O2 stoich (-)", "Oxygen stoich"
        "RH_ca_in", "RH cathode in (-)", "Humidification"
        "T_stack_C", "T_{stack} (degC)", "Stack temperature"
        };
end
end

function [groupVar, groupLabel, titlePrefix] = plotDiagnosticContext(studyType)
if string(studyType) == "constant_voltage"
    groupVar = "V_cell_target";
    groupLabel = "V";
    titlePrefix = "Testbench Constant Voltage";
else
    groupVar = "current_density_target_A_cm2";
    groupLabel = "A/cm2";
    titlePrefix = "Testbench Constant Current";
end
end

function name = figureNameFor(studyType, kind)
studyType = string(studyType);
if studyType == "constant_voltage"
    idx = 3 + double(string(kind) == "Diagnostics");
    label = "Constant Voltage";
else
    idx = 1 + double(string(kind) == "Diagnostics");
    label = "Constant Current";
end
name = sprintf('Testbench %02d %s %s', idx, label, kind);
end

function plotByGroup(T, groupVar, groupLabel, metric, yLabelText)
vars = string(T.Properties.VariableNames);
if ~ismember(metric, vars)
    text(0.1, 0.5, "Missing metric: " + string(metric), 'Interpreter', 'none');
    axis off;
    return;
end
groups = unique(T.(char(groupVar)));
colors = lines(numel(groups));
hold on;
for k = 1:numel(groups)
    d = groups(k);
    D = sortrows(T(T.(char(groupVar)) == d, :), "egr_fraction_cmd");
    y = D.(char(metric));
    plot(D.egr_fraction_cmd, y, '-o', 'LineWidth', 1.4, 'Color', colors(k, :), ...
        'DisplayName', groupLegend(d, groupLabel));
    warn = warningMask(D);
    if any(warn)
        plot(D.egr_fraction_cmd(warn), y(warn), 'x', 'LineWidth', 1.6, ...
            'MarkerSize', 8, 'Color', colors(k, :), 'HandleVisibility', 'off');
    end
end
grid on;
xlabel('EGR fraction (-)');
ylabel(yLabelText);
legend('Location', 'best');
end

function plotPressureChain(T, groupVar, groupLabel)
groups = unique(T.(char(groupVar)));
colors = lines(numel(groups));
hold on;
for k = 1:numel(groups)
    d = groups(k);
    D = sortrows(T(T.(char(groupVar)) == d, :), "egr_fraction_cmd");
    plot(D.egr_fraction_cmd, D.p_dq60_in_kPa, '-', 'LineWidth', 1.2, 'Color', colors(k, :), ...
        'DisplayName', "DQ60 in " + groupLegend(d, groupLabel));
    plot(D.egr_fraction_cmd, D.p_dq60_out_kPa, '--', 'LineWidth', 1.2, 'Color', colors(k, :), ...
        'DisplayName', "DQ60 out " + groupLegend(d, groupLabel));
    plot(D.egr_fraction_cmd, D.p_ca_in_kPa, '-.', 'LineWidth', 1.2, 'Color', colors(k, :), ...
        'DisplayName', "ca in " + groupLegend(d, groupLabel));
    plot(D.egr_fraction_cmd, D.p_stack_internal_kPa, ':', 'LineWidth', 1.5, 'Color', colors(k, :), ...
        'DisplayName', "stack " + groupLegend(d, groupLabel));
end
grid on;
xlabel('EGR fraction (-)');
legend('Location', 'best');
end

function plotMultiByGroup(T, groupVar, groupLabel, metrics, labels)
vars = string(T.Properties.VariableNames);
metrics = string(metrics);
labels = string(labels);
metrics = metrics(ismember(metrics, vars));
labels = labels(1:numel(metrics));
if isempty(metrics)
    text(0.1, 0.5, 'Missing metrics', 'Interpreter', 'none');
    axis off;
    return;
end
colors = lines(numel(metrics));
Dall = sortrows(T, [groupVar, "egr_fraction_cmd"]);
hold on;
for m = 1:numel(metrics)
    groups = unique(Dall.(char(groupVar)));
    for k = 1:numel(groups)
        d = groups(k);
        D = Dall(Dall.(char(groupVar)) == d, :);
        plot(D.egr_fraction_cmd, D.(char(metrics(m))), '-', 'LineWidth', 1.2, ...
            'Color', colors(m, :), 'DisplayName', labels(m) + " " + groupLegend(d, groupLabel));
    end
end
grid on;
xlabel('EGR fraction (-)');
legend('Location', 'best');
end

function plotStatusMap(T, groupVar, groupLabel)
statuses = unique(string(T.interpretation_status), 'stable');
groups = unique(T.(char(groupVar)));
colors = lines(numel(groups));
hold on;
for k = 1:numel(groups)
    d = groups(k);
    D = sortrows(T(T.(char(groupVar)) == d, :), "egr_fraction_cmd");
    y = statusIndex(string(D.interpretation_status), statuses);
    plot(D.egr_fraction_cmd, y, '-o', 'LineWidth', 1.3, 'Color', colors(k, :), ...
        'DisplayName', groupLegend(d, groupLabel));
end
yticks(1:numel(statuses));
yticklabels(statuses);
grid on;
xlabel('EGR fraction (-)');
legend('Location', 'best');
end

function plotCompare(x, yBench, ySim, yLabelText)
plot(x, yBench, 'o-', 'LineWidth', 1.4, 'DisplayName', 'bench');
hold on;
plot(x, ySim, 's--', 'LineWidth', 1.4, 'DisplayName', 'simulation');
grid on;
xlabel('Current density (A/cm^2)');
ylabel(yLabelText);
legend('Location', 'best');
end

function plotVoltageCompare(j, T, stats)
plot(j, T.V_cell_bench, 'o-', 'LineWidth', 1.4, 'DisplayName', 'bench');
hold on;
plot(j, T.V_cell_sim, 's--', 'LineWidth', 1.4, 'DisplayName', 'Simulink system');
if ismember("V_cell_formula_fit", string(T.Properties.VariableNames)) && any(isfinite(T.V_cell_formula_fit))
    plot(j, T.V_cell_formula_fit, 'd:', 'LineWidth', 1.4, 'DisplayName', 'internal-state fit replay');
end
grid on;
xlabel('Current density (A/cm^2)');
ylabel('V_{cell} (V)');
legend('Location', 'best');

simRmse = metricRmse(stats, "V_cell");
fitRmse = metricRmse(stats, "V_cell_formula_fit");
if ~isempty(fitRmse) && isfinite(fitRmse)
    title(sprintf('Cell voltage RMSE: Simulink %.4f V / formula %.4f V', simRmse, fitRmse));
else
    title(sprintf('Cell voltage RMSE: Simulink %.4f V', simRmse));
end
end

function value = metricRmse(stats, metric)
value = stats.rmse(stats.metric == string(metric));
end

function value = localRmse(x)
value = sqrt(mean(x .^ 2, 'omitnan'));
end

function idx = statusIndex(values, statuses)
idx = zeros(numel(values), 1);
for k = 1:numel(values)
    hit = find(statuses == values(k), 1);
    if isempty(hit)
        hit = numel(statuses) + 1;
    end
    idx(k) = hit;
end
end

function warn = warningMask(T)
vars = string(T.Properties.VariableNames);
warn = false(height(T), 1);
if ismember("risk_label", vars)
    warn = string(T.risk_label) ~= "ok";
elseif ismember("normal_operation_ok", vars)
    warn = ~logical(T.normal_operation_ok);
end
end

function labels = shortPO2Labels(T)
labels = strings(height(T), 1);
for k = 1:height(T)
    if T.egr_fraction_cmd(k) == 0
        labels(k) = "EGR 0";
    else
        labels(k) = sprintf('EGR %.2f / DQ60 %.0f rpm', T.egr_fraction_cmd(k), T.dq60_speed_rpm(k));
    end
end
end

function formatPO2Axis(x, labels)
xticks(x);
xticklabels(labels);
xtickangle(18);
xlim([min(x) - 0.5, max(x) + 0.5]);
end

function textOut = groupLegend(value, groupLabel)
if string(groupLabel) == "V"
    textOut = sprintf('%.3f V', value);
elseif string(groupLabel) == "A/cm2"
    textOut = sprintf('%.2f A/cm2', value);
else
    textOut = sprintf('%.3g %s', value, groupLabel);
end
end

function comparison = buildPO2Comparison(T)
base = T(T.egr_fraction_cmd == 0, :);
if height(base) ~= 1
    error('CEGR:BadPO2TwoPointData', 'Expected exactly one EGR=0 row for pO2 comparison.');
end
comparison = table();
if ismember("case_label", string(T.Properties.VariableNames))
    comparison.case_label = T.case_label;
else
    comparison.case_label = strings(height(T), 1);
    for k = 1:height(T)
        if abs(T.egr_fraction_cmd(k)) < 1e-12
            comparison.case_label(k) = "j0p10_EGR0_baseline";
        else
            comparison.case_label(k) = sprintf('j0p10_EGR%.2f_DQ60', T.egr_fraction_cmd(k));
        end
    end
end
comparison.current_density_A_cm2 = T.current_density_command_A_cm2;
comparison.EGR = T.egr_fraction_cmd;
comparison.air_flow_scale = T.air_flow_scale;
comparison.cathode_flow_nlpm = T.cathode_flow_nlpm_cmd;
comparison.dq60_speed_rpm = T.dq60_speed_rpm;
comparison.dq60_flow_lpm = T.dq60_flow_lpm;
comparison.dq60_dp_kPa = T.dq60_dp_kPa;
comparison.dq60_power_W = T.dq60_power_W;
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
comparison.normal_operation_ok = logical(T.normal_operation_ok);
end

function writeResultSheet(C, sheetName, T)
if isempty(T)
    return;
end
writetable(T, C.workbookFile, 'Sheet', char(sheetName), 'WriteMode', 'overwritesheet');
end

function info = makeRunInfo(C, runType)
info = table();
info.run_time = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
info.run_type = string(runType);
info.model_name = string(C.model);
info.model_file = string(C.modelFile);
info.workbook_file = string(C.workbookFile);
end

function closeFigures(names)
if nargin < 1 || isempty(names)
    names = [
        "Testbench 01 Constant Current Main"
        "Testbench 02 Constant Current Diagnostics"
        "Testbench 03 Constant Voltage Main"
        "Testbench 04 Constant Voltage Diagnostics"
        "Testbench 05 Constant pO2 DQ60 Two Point"
        "Testbench 06 No-EGR Validation"
        "Testbench 00 Bench Topology"
        ];
end
for k = 1:numel(names)
    figs = findall(0, 'Type', 'figure', 'Name', char(names(k)));
    if ~isempty(figs)
        close(figs);
    end
end
end

function drawPanel(ax, pos, labelText, faceColor, edgeColor)
rectangle(ax, 'Position', pos, 'Curvature', 0.025, 'FaceColor', faceColor, ...
    'EdgeColor', edgeColor, 'LineWidth', 0.9);
text(ax, pos(1) + 0.012, pos(2) + pos(4) - 0.028, labelText, 'FontWeight', 'bold', ...
    'FontSize', 9, 'Color', edgeColor, 'Interpreter', 'none');
end

function h = drawBox(ax, pos, titleText, bodyText, edgeColor, faceColor)
rectangle(ax, 'Position', pos + [0.006 -0.006 0 0], 'Curvature', 0.045, 'FaceColor', [0.84 0.87 0.90], ...
    'EdgeColor', 'none', 'FaceAlpha', 0.35);
rectangle(ax, 'Position', pos, 'Curvature', 0.04, 'FaceColor', faceColor, ...
    'EdgeColor', edgeColor, 'LineWidth', 1.6);
rectangle(ax, 'Position', [pos(1), pos(2)+pos(4)-0.052, pos(3), 0.052], ...
    'Curvature', 0.04, 'FaceColor', edgeColor, 'EdgeColor', edgeColor, 'LineWidth', 0.8);
hTitle = text(ax, pos(1) + 0.01, pos(2) + pos(4) - 0.035, titleText, 'FontWeight', 'bold', ...
    'FontSize', 10.5, 'Interpreter', 'none', 'Color', 'w');
hBody = text(ax, pos(1) + 0.012, pos(2) + pos(4) - 0.070, bodyText, 'FontSize', 8.1, ...
    'VerticalAlignment', 'top', 'Interpreter', 'none', 'Color', [0.10 0.12 0.14]);
h = [hTitle, hBody];
end

function drawArrow(ax, p1, p2, color, lineWidth, lineStyle)
quiver(ax, p1(1), p1(2), p2(1) - p1(1), p2(2) - p1(2), 0, ...
    'MaxHeadSize', 0.28, 'Color', color, 'LineWidth', lineWidth, 'LineStyle', lineStyle);
end

function drawPolylineArrow(ax, points, color, lineWidth, lineStyle)
if size(points, 1) < 2
    return;
end
for k = 1:size(points, 1)-2
    plot(ax, points(k:k+1, 1), points(k:k+1, 2), 'Color', color, 'LineWidth', lineWidth, 'LineStyle', lineStyle);
end
drawArrow(ax, points(end-1, :), points(end, :), color, lineWidth, lineStyle);
end
