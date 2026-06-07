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
    case "plotEgrMain"
        varargout{1} = plotEgrMain(varargin{:});
    case "plotEgrDiagnostics"
        varargout{1} = plotEgrDiagnostics(varargin{:});
    case "plotConstantPO2TwoPoint"
        varargout{1} = plotConstantPO2TwoPoint(varargin{:});
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
C.constantPO2TwoPointFile = fullfile(C.resultDir, 'condition_study_constant_pO2_DQ60_two_point_j0p10_egr0p25.csv');
C.constantPO2ComparisonFile = fullfile(C.resultDir, 'condition_study_constant_pO2_DQ60_two_point_j0p10_egr0p25_comparison.csv');
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
T = readRequiredTable(C.constantPO2TwoPointFile);
T = addInterpretationStatus(T);
T = sortrows(T, "egr_fraction_cmd");
if isfile(C.constantPO2ComparisonFile)
    comparison = readtable(C.constantPO2ComparisonFile, 'TextType', 'string');
else
    comparison = buildPO2Comparison(T);
end
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
plotStatusMapPO2(T, x, labels);
title('Risk label');

sgtitle('Constant pO2: 0.1 A/cm2 EGR=0 baseline vs EGR=0.25 DQ60 representative point');

if nargin >= 2 && ~isempty(comparison)
    assignin('base', 'testbenchConstantPO2TwoPointComparison', comparison);
end
end

function [groupVar, groupLabel, titlePrefix, fixedFlowText, metrics] = plotMainContext(~, studyType)
studyType = string(studyType);
if studyType == "constant_voltage"
    groupVar = "V_cell_target";
    groupLabel = "V";
    titlePrefix = "Testbench Constant Voltage";
    fixedFlowText = "fixed nearest no-EGR bench compressor flow";
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

function plotStatusMapPO2(T, x, labels)
statuses = unique(string(T.interpretation_status), 'stable');
y = statusIndex(string(T.interpretation_status), statuses);
plot(x, y, 'o', 'MarkerSize', 8, 'LineWidth', 1.5);
hold on;
for k = 1:numel(x)
    text(x(k) + 0.05, y(k), string(T.interpretation_status(k)), 'Interpreter', 'none');
end
yticks(1:numel(statuses));
yticklabels(statuses);
formatPO2Axis(x, labels);
grid on;
ylim([0.5, max(numel(statuses) + 0.5, 1.5)]);
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
comparison.case_label = T.case_label;
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
comparison.normal_operation_ok = T.normal_operation_ok;
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
        ];
end
for k = 1:numel(names)
    figs = findall(0, 'Type', 'figure', 'Name', char(names(k)));
    if ~isempty(figs)
        close(figs);
    end
end
end
