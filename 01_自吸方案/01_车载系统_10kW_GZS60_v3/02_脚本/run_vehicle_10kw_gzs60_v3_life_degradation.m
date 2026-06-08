function results = run_vehicle_10kw_gzs60_v3_life_degradation()
%RUN_VEHICLE_10KW_GZS60_V3_LIFE_DEGRADATION
% Recalculate the life model from the vehicle CEGR workbook using the
% updated stack voltage outputs already produced by the CEGR vehicle model.

P0 = init_vehicle_10kw_gzs60_v3("current");
rootDir = P0.rootDir;
resultDir = fullfile(rootDir, '04_验证结果');
docDir = fullfile(rootDir, '03_说明');
workbookFile = fullfile(resultDir, 'CEGR_visualization_results.xlsx');
currentFile = fullfile(resultDir, 'life_degradation_vehicle_constant_current.csv');
summaryFile = fullfile(resultDir, 'life_degradation_vehicle_group_summary.csv');
mdFile = fullfile(docDir, '车载寿命衰减独立模型运行摘要_v01.md');

if ~isfile(workbookFile)
    error('Missing CEGR workbook: %s', workbookFile);
end
if ~exist(resultDir, 'dir')
    mkdir(resultDir);
end
if ~exist(docDir, 'dir')
    mkdir(docDir);
end

P = pemfc_life_params_v01();
T = readtable(workbookFile, 'Sheet', 'egr_constant_current', 'TextType', 'string');
T.study_type = repmat("constant_current_fixed_flow", height(T), 1);
T.current_density_command_A_cm2 = T.current_density_A_cm2;
if ismember('pressure_order_ok', T.Properties.VariableNames)
    if ~ismember('normal_operation_ok', T.Properties.VariableNames)
        T.normal_operation_ok = logical(T.pressure_order_ok) & T.interpretation_status == "normal";
    end
else
    T.normal_operation_ok = repmat(true(height(T),1), 1);
end

[lifeT, summary] = pemfc_life_evaluate_table_v01(T, P, struct('duration_h', 1.0));
lifeT.life_source_file = repmat("CEGR_visualization_results.xlsx::egr_constant_current", height(lifeT), 1);
writetable(lifeT, currentFile);
if ~isempty(summary)
    summary.life_source_file = repmat("CEGR_visualization_results.xlsx::egr_constant_current", height(summary), 1);
    writetable(summary, summaryFile);
end
writeSummaryMd(mdFile, P, lifeT, summary, workbookFile, currentFile, summaryFile);

results = struct();
results.workbook_file = workbookFile;
results.current_file = currentFile;
results.summary_file = summaryFile;
results.markdown_summary_file = mdFile;
results.table = lifeT;
results.summary = summary;

fprintf('Vehicle life degradation evaluation complete: %s\n', mdFile);
end

function writeSummaryMd(mdFile, P, T, summary, workbookFile, currentFile, summaryFile)
fid = fopen(mdFile, 'w', 'n', 'UTF-8');
if fid < 0
    error('run_vehicle_10kw_gzs60_v3_life_degradation:OpenFailed', 'Cannot write %s.', mdFile);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '# 车载寿命衰减独立模型运行摘要 v01\n\n');
fprintf(fid, '## 模型定位\n\n');
fprintf(fid, '本次计算直接读取车载 CEGR 模型工作簿中的 `egr_constant_current` 结果，使用更新后的电堆电压输出 `V_cell_sim` 作为寿命模块输入，研究恒电流下 EGR 通过降低单片电压来减缓寿命衰减的趋势。\n\n');
fprintf(fid, '## 数据链路\n\n');
fprintf(fid, '- 电堆/CEGR 输出: `CEGR_visualization_results.xlsx::egr_constant_current`\n');
fprintf(fid, '- 寿命输入: `V_cell_sim`, `current_density_A_cm2`, `RH_ca_in`, `T_stack_sim_C`, `egr_ratio_cmd`\n');
fprintf(fid, '- 寿命输出: `life_damage_rate_mV_h`, `life_delta_V_deg_mV`, `life_projected_to_EOL_h`, `life_ECSA_ratio_proxy`\n\n');
fprintf(fid, '## 关键参数\n\n');
fprintf(fid, '- `V_ref = %.3f V`\n', P.V_ref);
fprintf(fid, '- `V_high = %.3f V`\n', P.V_high);
fprintf(fid, '- `RH_min = %.2f`\n', P.RH_min);
fprintf(fid, '- `base_decay_mV_h = %.4f mV/h`\n', P.base_decay_mV_h);
fprintf(fid, '- `allowable_decay_mV = %.1f mV`\n', P.allowable_decay_mV);
fprintf(fid, '\n## 输出文件\n\n');
fprintf(fid, '- `%s`\n', currentFile);
fprintf(fid, '- `%s`\n', summaryFile);
fprintf(fid, '\n## 分组结果\n\n');
fprintf(fid, '| 分组 | 基准衰减率 mV/h | 最低衰减率 mV/h | 相对收益 %% | 最优EGR |\n');
fprintf(fid, '|---|---:|---:|---:|---:|\n');
for i = 1:height(summary)
    fprintf(fid, '| `%s` | %.6f | %.6f | %.2f | %.3f |\n', ...
        summary.life_group_key(i), summary.baseline_rate_mV_h(i), ...
        summary.best_rate_mV_h(i), summary.best_benefit_vs_noEGR_pct(i), ...
        summary.best_egr_fraction_cmd(i));
end
fprintf(fid, '\n## 解释\n\n');
fprintf(fid, '这里的寿命结果是相对比较，不是绝对寿命承诺。`V_cell_sim` 已经来自更新后的车载电堆电压公式，因此本次重算反映的是“新电压口径 + CEGR 工况”对寿命的影响。\n');
end
