function outputs = run_testbench_life_visualization_v01()
%RUN_TESTBENCH_LIFE_VISUALIZATION_V01 Plot PEMFC life-degradation results.

scriptDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(scriptDir);
resultDir = fullfile(rootDir, '04_验证结果');
figureDir = fullfile(resultDir, 'life_degradation_figures');
docDir = fullfile(rootDir, '03_说明');
addpath(scriptDir);

if ~exist(figureDir, 'dir')
    mkdir(figureDir);
end

ensureLifeResults(scriptDir, resultDir);

cc = readtable(fullfile(resultDir, 'life_degradation_constant_current.csv'), 'TextType', 'string');
cv = readtable(fullfile(resultDir, 'life_degradation_constant_voltage.csv'), 'TextType', 'string');
allCases = readtable(fullfile(resultDir, 'life_degradation_all_cases.csv'), 'TextType', 'string');
summary = readtable(fullfile(resultDir, 'life_degradation_group_summary.csv'), 'TextType', 'string');

figs = gobjects(0);
files = strings(0, 1);

[figs(end+1), files(end+1)] = saveFigure(plotConstantCurrentLife(cc), figureDir, 'life_01_constant_current_egr.png');
[figs(end+1), files(end+1)] = saveFigure(plotConstantVoltageLife(cv), figureDir, 'life_02_constant_voltage_egr.png');
[figs(end+1), files(end+1)] = saveFigure(plotFactorBreakdown(cc), figureDir, 'life_03_factor_breakdown.png');
[figs(end+1), files(end+1)] = saveFigure(plotSummaryAndInterface(summary, allCases), figureDir, 'life_04_summary_interface.png');

close(figs(ishandle(figs)));
writeLifeFigureSummary(fullfile(docDir, '寿命衰减可视化结果_v01.md'), files, summary);

outputs = struct();
outputs.figure_files = files;
outputs.figure_dir = figureDir;
outputs.summary_file = fullfile(docDir, '寿命衰减可视化结果_v01.md');
fprintf('Life visualization complete: %s\n', outputs.summary_file);
end

function ensureLifeResults(scriptDir, resultDir)
required = fullfile(resultDir, 'life_degradation_all_cases.csv');
if ~isfile(required)
    cwd = pwd;
    cleanup = onCleanup(@() cd(cwd));
    cd(scriptDir);
    run_testbench_life_degradation_v01();
end
end

function fig = plotConstantCurrentLife(T)
fig = newFigure('Life 01 Constant Current EGR');
tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

groups = unique(T.current_density_command_A_cm2, 'stable');
colors = lines(numel(groups));

nexttile; plotGrouped(T, groups, colors, 'V_cell_sim', 'V_{cell} (V)'); yline(0.8, '--', '0.8 V', 'HandleVisibility', 'off'); title('单片电压');
nexttile; plotGrouped(T, groups, colors, 'pO2_ca_in_kPa', 'pO_2,in (kPa)'); title('阴极入口氧分压');
nexttile; plotGrouped(T, groups, colors, 'RH_ca_in', 'RH_{ca,in} (-)'); title('阴极入口湿度');
nexttile; plotGrouped(T, groups, colors, 'life_damage_rate_mV_h', 'mV/h'); title('等效衰减率');
nexttile; plotGrouped(T, groups, colors, 'life_benefit_vs_noEGR_pct', 'Benefit (%)'); yline(0, '-', 'HandleVisibility', 'off'); title('相对无EGR寿命收益');
nexttile; plotGrouped(T, groups, colors, 'life_projected_to_EOL_h', 'h'); title('等效到EOL小时数');

sgtitle('寿命模型：恒电流固定流量 EGR 扫描', 'FontWeight', 'bold');
end

function fig = plotConstantVoltageLife(T)
fig = newFigure('Life 02 Constant Voltage EGR');
tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

groups = unique(T.V_cell_target, 'stable');
colors = lines(numel(groups));

nexttile; plotGroupedBy(T, groups, colors, 'V_cell_target', 'current_density_solved_A_cm2', 'j solved (A/cm2)'); title('恒电压反求电流密度');
nexttile; plotGroupedBy(T, groups, colors, 'V_cell_target', 'V_cell_sim', 'V_{cell} (V)'); title('目标电压保持');
nexttile; plotGroupedBy(T, groups, colors, 'V_cell_target', 'RH_ca_in', 'RH_{ca,in} (-)'); title('阴极入口湿度');
nexttile; plotGroupedBy(T, groups, colors, 'V_cell_target', 'life_damage_rate_mV_h', 'mV/h'); title('等效衰减率');
nexttile; plotGroupedBy(T, groups, colors, 'V_cell_target', 'life_benefit_vs_noEGR_pct', 'Benefit (%)'); yline(0, '-', 'HandleVisibility', 'off'); title('相对无EGR寿命收益');
nexttile; plotGroupedBy(T, groups, colors, 'V_cell_target', 'life_voltage_factor', 'factor'); title('电位衰减因子');

sgtitle('寿命模型：恒单片电压 EGR 扫描', 'FontWeight', 'bold');
end

function fig = plotFactorBreakdown(T)
fig = newFigure('Life 03 Factor Breakdown');
tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
groups = unique(T.current_density_command_A_cm2, 'stable');
colors = lines(numel(groups));

nexttile; plotGrouped(T, groups, colors, 'life_voltage_factor', 'factor'); title('电位因子 f_V');
nexttile; plotGrouped(T, groups, colors, 'life_humidity_factor', 'factor'); title('湿度因子 f_RH');
nexttile; plotGrouped(T, groups, colors, 'life_temperature_factor', 'factor'); title('温度因子 f_T');
nexttile; plotGrouped(T, groups, colors, 'life_current_factor', 'factor'); title('电流因子 f_j');
nexttile; plotGrouped(T, groups, colors, 'life_high_potential_margin_mV', 'mV'); yline(0, '--', '0.8 V threshold', 'HandleVisibility', 'off'); title('高电位裕度');
nexttile; plotGrouped(T, groups, colors, 'life_ECSA_ratio_proxy', 'ratio'); title('ECSA代理量');

sgtitle('寿命模型：衰减因子分解', 'FontWeight', 'bold');
end

function fig = plotSummaryAndInterface(summary, allCases)
fig = newFigure('Life 04 Summary Interface');
tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
bar(summary.best_benefit_vs_noEGR_pct, 'FaceColor', [0.16 0.45 0.70]);
grid on;
ylabel('Benefit (%)');
title('各分组最优相对收益');
set(gca, 'XTick', 1:height(summary), 'XTickLabel', shortLabels(summary.life_group_key), 'XTickLabelRotation', 25);

nexttile;
scatter(allCases.V_cell_sim, allCases.life_damage_rate_mV_h, 42, allCases.RH_ca_in, 'filled');
grid on;
xline(0.8, '--', '0.8 V', 'HandleVisibility', 'off');
xlabel('V_{cell} (V)');
ylabel('Damage rate (mV/h)');
title('电压-衰减率关系，颜色=RH');
cb = colorbar;
cb.Label.String = 'RH_{ca,in}';

nexttile;
scatter(allCases.pO2_ca_in_kPa, allCases.V_cell_sim, 42, allCases.egr_fraction_cmd, 'filled');
grid on;
yline(0.8, '--', '0.8 V', 'HandleVisibility', 'off');
xlabel('pO_2,in (kPa)');
ylabel('V_{cell} (V)');
title('氧分压-单片电压关系，颜色=EGR');
cb = colorbar;
cb.Label.String = 'EGR';

nexttile;
axis off;
text(0.02, 0.88, '耦合接口', 'FontWeight', 'bold', 'FontSize', 13);
text(0.02, 0.72, sprintf('电堆输出: V_cell, j, RH_ca_in, T_stack, pO2_ca_in'), 'FontSize', 10, 'Interpreter', 'none');
text(0.02, 0.56, sprintf('寿命输出: damage rate, DeltaV_deg, damage index, ECSA proxy'), 'FontSize', 10, 'Interpreter', 'none');
text(0.02, 0.40, sprintf('长时方法: 短时性能仿真 + 工况持续时间外推'), 'FontSize', 10);
text(0.02, 0.24, sprintf('第一阶段: 单向慢变量, 不反向修正电压'), 'FontSize', 10);
text(0.02, 0.08, sprintf('第二阶段: 用 DeltaV 或 ECSA 弱耦合电压模型'), 'FontSize', 10);
title('后续耦合口径');

sgtitle('寿命模型：总览与接口', 'FontWeight', 'bold');
end

function fig = newFigure(name)
fig = figure('Name', name, 'Color', 'w', 'Visible', 'off');
fig.Position(3:4) = [1320 760];
end

function plotGrouped(T, groups, colors, metric, yText)
plotGroupedBy(T, groups, colors, 'current_density_command_A_cm2', metric, yText);
end

function plotGroupedBy(T, groups, colors, groupVar, metric, yText)
hold on;
for i = 1:numel(groups)
    idx = T.(groupVar) == groups(i);
    D = sortrows(T(idx, :), 'egr_fraction_cmd');
    plot(D.egr_fraction_cmd, D.(metric), '-o', 'LineWidth', 1.45, 'Color', colors(i, :), ...
        'MarkerFaceColor', colors(i, :), 'DisplayName', groupName(groupVar, groups(i)));
end
grid on;
xlabel('EGR fraction');
ylabel(yText);
legend('Location', 'best', 'Interpreter', 'none');
end

function name = groupName(groupVar, value)
if string(groupVar) == "V_cell_target"
    name = sprintf('V=%.3f V', value);
else
    name = sprintf('j=%.2f A/cm2', value);
end
end

function labels = shortLabels(keys)
labels = strings(size(keys));
for i = 1:numel(keys)
    s = string(keys(i));
    s = erase(s, "constant_current_fixed_flow|");
    s = erase(s, "constant_voltage_fixed_flow|");
    s = erase(s, "constant_pO2_inlet_variable_flow|");
    s = erase(s, "study|");
    labels(i) = s;
end
end

function [fig, file] = saveFigure(fig, figureDir, fileName)
file = string(fullfile(figureDir, fileName));
exportgraphics(fig, file, 'Resolution', 180);
end

function writeLifeFigureSummary(mdFile, files, summary)
fid = fopen(mdFile, 'w', 'n', 'UTF-8');
if fid < 0
    error('run_testbench_life_visualization_v01:OpenFailed', 'Cannot write %s.', mdFile);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '# 寿命衰减可视化结果 v01\n\n');
fprintf(fid, '## 图件\n\n');
for i = 1:numel(files)
    fprintf(fid, '- `%s`\n', files(i));
end
fprintf(fid, '\n## 分组摘要\n\n');
fprintf(fid, '| 分组 | 基准衰减率 mV/h | 最低衰减率 mV/h | 相对收益 %% | 最优EGR |\n');
fprintf(fid, '|---|---:|---:|---:|---:|\n');
for i = 1:height(summary)
    fprintf(fid, '| `%s` | %.6f | %.6f | %.2f | %.3f |\n', ...
        summary.life_group_key(i), summary.baseline_rate_mV_h(i), summary.best_rate_mV_h(i), ...
        summary.best_benefit_vs_noEGR_pct(i), summary.best_egr_fraction_cmd(i));
end
fprintf(fid, '\n## 解释\n\n');
fprintf(fid, '这些图基于独立寿命后处理模型生成，用于相对寿命收益排序。`base_decay_mV_h` 尚未用本项目长期耐久实验标定，因此图中的寿命小时数用于同一参数集下的相对比较，不作为绝对寿命承诺。\n');
end
