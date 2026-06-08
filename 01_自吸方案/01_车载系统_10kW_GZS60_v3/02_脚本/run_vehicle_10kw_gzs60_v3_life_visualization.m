function outputs = run_vehicle_10kw_gzs60_v3_life_visualization()
%RUN_VEHICLE_10KW_GZS60_V3_LIFE_VISUALIZATION
% Plot the vehicle life-degradation results for the updated CEGR model.

P0 = init_vehicle_10kw_gzs60_v3("current");
rootDir = P0.rootDir;
resultDir = fullfile(rootDir, '04_验证结果');
docDir = fullfile(rootDir, '03_说明');
figureDir = fullfile(resultDir, 'life_degradation_figures_vehicle');
currentFile = fullfile(resultDir, 'life_degradation_vehicle_constant_current.csv');
summaryFile = fullfile(resultDir, 'life_degradation_vehicle_group_summary.csv');

if ~isfile(currentFile) || ~isfile(summaryFile)
    run_vehicle_10kw_gzs60_v3_life_degradation();
end

T = readtable(currentFile, 'TextType', 'string');
S = readtable(summaryFile, 'TextType', 'string');

fig1 = plotConstantCurrentLife(T);
fig2 = plotSummaryInterface(T, S);

outputs = struct();
outputs.figures = [fig1 fig2];
outputs.current_file = currentFile;
outputs.summary_file = summaryFile;

fprintf('Vehicle life visualization opened 2 figures.\n');
end

function fig = plotConstantCurrentLife(T)
fig = figure('Name', 'Vehicle Life 01 Constant Current EGR', 'Color', 'w');
fig.Position(3:4) = [1380 800];
tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

groups = unique(T.current_density_A_cm2, 'stable');
colors = lines(numel(groups));

nexttile; plotGrouped(T, groups, colors, 'V_cell_sim', 'V_{cell} (V)'); yline(0.8, '--', '0.8 V', 'HandleVisibility', 'off'); title('单片电压');
nexttile; plotGrouped(T, groups, colors, 'pO2_ca_in_kPa', 'pO_2,in (kPa)'); title('阴极入口氧分压');
nexttile; plotGrouped(T, groups, colors, 'RH_ca_in', 'RH_{ca,in} (-)'); title('阴极入口湿度');
nexttile; plotGrouped(T, groups, colors, 'life_damage_rate_mV_h', 'mV/h'); title('等效衰减率');
nexttile; plotGrouped(T, groups, colors, 'life_benefit_vs_noEGR_pct', 'Benefit (%)'); yline(0, '-', 'HandleVisibility', 'off'); title('相对无EGR寿命收益');
nexttile; plotGrouped(T, groups, colors, 'life_projected_to_EOL_h', 'h'); title('等效到EOL小时数');

sgtitle('车载寿命模型：恒电流 EGR 扫描', 'FontWeight', 'bold');
end

function fig = plotSummaryInterface(T, S)
fig = figure('Name', 'Vehicle Life 02 Summary Interface', 'Color', 'w');
fig.Position(3:4) = [1380 780];
tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
bar(S.best_benefit_vs_noEGR_pct, 'FaceColor', [0.16 0.45 0.70]);
grid on;
ylabel('Benefit (%)');
title('各工况最优寿命收益');
set(gca, 'XTick', 1:height(S), 'XTickLabel', shortLabels(S.life_group_key), 'XTickLabelRotation', 18);

nexttile;
scatter(T.V_cell_sim, T.life_damage_rate_mV_h, 45, T.egr_ratio_cmd, 'filled');
grid on;
xlabel('V_{cell} (V)');
ylabel('Damage rate (mV/h)');
title('电压-衰减率，颜色=EGR');
cb = colorbar;
cb.Label.String = 'EGR';

nexttile;
scatter(T.egr_ratio_cmd, T.life_projected_to_EOL_h, 45, T.current_density_A_cm2, 'filled');
grid on;
xlabel('EGR fraction');
ylabel('EOL hours');
title('EGR-寿命终点，颜色=j');
cb = colorbar;
cb.Label.String = 'j (A/cm^2)';

nexttile;
axis off;
text(0.02, 0.88, '耦合接口', 'FontWeight', 'bold', 'FontSize', 13);
text(0.02, 0.72, '车载电堆输出: V_cell_sim, RH_ca_in, T_stack_sim_C, pO2_ca_in_kPa', 'FontSize', 10, 'Interpreter', 'none');
text(0.02, 0.56, '寿命输出: life_damage_rate_mV_h, life_delta_V_deg_mV, life_projected_to_EOL_h', 'FontSize', 10, 'Interpreter', 'none');
text(0.02, 0.40, '当前口径: 恒电流工况下比较 EGR 对高电位暴露和寿命衰减的抑制', 'FontSize', 10);
text(0.02, 0.24, '说明: 结果为相对比较，不是绝对寿命承诺', 'FontSize', 10);
text(0.02, 0.08, '数据源: CEGR_visualization_results.xlsx -> egr_constant_current', 'FontSize', 10, 'Interpreter', 'none');

sgtitle('车载寿命模型：总览与接口', 'FontWeight', 'bold');
end

function plotGrouped(T, groups, colors, metric, yText)
hold on;
for i = 1:numel(groups)
    idx = T.current_density_A_cm2 == groups(i);
    D = sortrows(T(idx, :), 'egr_ratio_cmd');
    plot(D.egr_ratio_cmd, D.(metric), '-o', 'LineWidth', 1.45, 'Color', colors(i, :), ...
        'MarkerFaceColor', colors(i, :), 'DisplayName', sprintf('j=%.2f A/cm2', groups(i)));
end
grid on;
xlabel('EGR fraction');
ylabel(yText);
legend('Location', 'best', 'Interpreter', 'none');
end

function labels = shortLabels(keys)
labels = strings(size(keys));
for i = 1:numel(keys)
    s = string(keys(i));
    s = erase(s, "constant_current_fixed_flow|");
    labels(i) = s;
end
end
