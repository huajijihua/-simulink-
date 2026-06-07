function results = run_testbench_life_degradation_v01()
%RUN_TESTBENCH_LIFE_DEGRADATION_V01 Evaluate life metrics from existing CSVs.

scriptDir = fileparts(mfilename('fullpath'));
rootDir = fileparts(scriptDir);
resultDir = fullfile(rootDir, '04_验证结果');
docDir = fullfile(rootDir, '03_说明');
addpath(scriptDir);

P = pemfc_life_params_v01();
inputs = {
    'condition_study_constant_current_egr_scan.csv', 'life_degradation_constant_current.csv';
    'condition_study_constant_voltage_solved.csv', 'life_degradation_constant_voltage.csv';
    'condition_study_constant_pO2_inlet_solved.csv', 'life_degradation_constant_pO2_inlet.csv';
    'condition_study_constant_pO2_DQ60_two_point_j0p10_egr0p25_comparison.csv', 'life_degradation_constant_pO2_two_point.csv';
    };

combined = table();
combinedSummary = table();
processed = strings(0, 1);

for k = 1:size(inputs, 1)
    inFile = fullfile(resultDir, inputs{k, 1});
    outFile = fullfile(resultDir, inputs{k, 2});
    if ~isfile(inFile)
        continue;
    end
    T = readtable(inFile, 'TextType', 'string');
    [lifeT, summary] = pemfc_life_evaluate_table_v01(T, P);
    lifeT.life_source_file = repmat(string(inputs{k, 1}), height(lifeT), 1);
    writetable(lifeT, outFile);
    processed(end + 1, 1) = string(inputs{k, 1}); %#ok<AGROW>
    combined = [combined; makeSlimCaseTable(lifeT, string(inputs{k, 1}))]; %#ok<AGROW>
    if ~isempty(summary)
        summary.life_source_file = repmat(string(inputs{k, 1}), height(summary), 1);
        combinedSummary = [combinedSummary; summary]; %#ok<AGROW>
    end
end

allFile = fullfile(resultDir, 'life_degradation_all_cases.csv');
summaryFile = fullfile(resultDir, 'life_degradation_group_summary.csv');
if ~isempty(combined)
    writetable(combined, allFile);
end
if ~isempty(combinedSummary)
    writetable(combinedSummary, summaryFile);
end

mdFile = fullfile(docDir, '寿命衰减独立模型运行摘要_v01.md');
writeMarkdownSummary(mdFile, P, processed, allFile, summaryFile, combinedSummary);

results = struct();
results.params = P;
results.processed = processed;
results.all_cases = combined;
results.group_summary = combinedSummary;
results.all_cases_file = allFile;
results.group_summary_file = summaryFile;
results.markdown_summary_file = mdFile;

fprintf('Life degradation evaluation complete: %s\n', mdFile);
end

function S = makeSlimCaseTable(T, sourceFile)
n = height(T);
S = table();
S.life_source_file = repmat(sourceFile, n, 1);
S.life_group_key = getStringCol(T, 'life_group_key', repmat("all", n, 1));
S.study_type = getStringCol(T, 'study_type', getStringCol(T, 'condition', repmat("study", n, 1)));
S.case_id = getStringCol(T, 'case_id', getStringCol(T, 'case_label', repmat("", n, 1)));
S.egr_fraction_cmd = getNumericCol(T, ["egr_fraction_cmd", "EGR", "egr"], NaN(n, 1));
S.current_density_A_cm2 = getNumericCol(T, ["current_density_command_A_cm2", "current_density_target_A_cm2", ...
    "current_density_A_cm2", "current_density_solved_A_cm2"], NaN(n, 1));
S.V_cell_sim = getNumericCol(T, ["V_cell_sim", "V_cell"], NaN(n, 1));
S.pO2_ca_in_kPa = getNumericCol(T, ["pO2_ca_in_kPa", "pO2_stack_kPa"], NaN(n, 1));
S.RH_ca_in = getNumericCol(T, ["RH_ca_in", "RH"], NaN(n, 1));
S.T_stack_C = getNumericCol(T, ["T_stack_C", "T_C"], NaN(n, 1));
S.normal_operation_ok = getNumericCol(T, "normal_operation_ok", NaN(n, 1));
S.risk_label = getStringCol(T, 'risk_label', repmat("", n, 1));
S.life_damage_rate_mV_h = T.life_damage_rate_mV_h;
S.life_delta_V_deg_mV = T.life_delta_V_deg_mV;
S.life_damage_index = T.life_damage_index;
S.life_projected_to_EOL_h = T.life_projected_to_EOL_h;
S.life_ECSA_ratio_proxy = T.life_ECSA_ratio_proxy;
S.life_high_potential_exposure_V_h = T.life_high_potential_exposure_V_h;
S.life_rate_ratio_to_noEGR = T.life_rate_ratio_to_noEGR;
S.life_benefit_vs_noEGR_pct = T.life_benefit_vs_noEGR_pct;
S.life_interpretation_status = T.life_interpretation_status;
end

function x = getNumericCol(T, names, defaultValue)
names = string(names);
x = defaultValue;
for i = 1:numel(names)
    name = char(names(i));
    if ismember(name, T.Properties.VariableNames)
        x = T.(name);
        if iscell(x) || isstring(x) || ischar(x)
            x = str2double(string(x));
        end
        x = double(x(:));
        return;
    end
end
end

function x = getStringCol(T, name, defaultValue)
x = defaultValue;
if ismember(name, T.Properties.VariableNames)
    x = string(T.(name));
    x = x(:);
end
end

function writeMarkdownSummary(mdFile, P, processed, allFile, summaryFile, summary)
fid = fopen(mdFile, 'w', 'n', 'UTF-8');
if fid < 0
    error('run_testbench_life_degradation_v01:OpenFailed', 'Cannot write %s.', mdFile);
end
cleanup = onCleanup(@() fclose(fid));

fprintf(fid, '# 寿命衰减独立模型运行摘要 v01\n\n');
fprintf(fid, '## 模型定位\n\n');
fprintf(fid, '本次运行使用独立 MATLAB 寿命模型，不调用 Simulink 电堆模型。模型输出用于相对寿命收益排序，暂不作为绝对寿命承诺。\n\n');
fprintf(fid, '## 已处理输入\n\n');
if isempty(processed)
    fprintf(fid, '- 未找到可处理的输入 CSV。\n');
else
    for k = 1:numel(processed)
        fprintf(fid, '- `%s`\n', processed(k));
    end
end
fprintf(fid, '\n## 关键参数\n\n');
fprintf(fid, '- `V_ref = %.3f V`\n', P.V_ref);
fprintf(fid, '- `V_high = %.3f V`\n', P.V_high);
fprintf(fid, '- `RH_min = %.2f`\n', P.RH_min);
fprintf(fid, '- `base_decay_mV_h = %.4f mV/h`\n', P.base_decay_mV_h);
fprintf(fid, '- `allowable_decay_mV = %.1f mV`\n', P.allowable_decay_mV);
fprintf(fid, '\n## 输出文件\n\n');
fprintf(fid, '- `%s`\n', allFile);
fprintf(fid, '- `%s`\n', summaryFile);
fprintf(fid, '\n## 分组最优结果\n\n');
if isempty(summary)
    fprintf(fid, '暂无可比较的无 EGR 基准分组。\n');
else
    fprintf(fid, '| 分组 | 基准衰减率 mV/h | 最低衰减率 mV/h | 相对收益 %% | 最优EGR |\n');
    fprintf(fid, '|---|---:|---:|---:|---:|\n');
    for i = 1:height(summary)
        fprintf(fid, '| `%s` | %.6f | %.6f | %.2f | %.3f |\n', ...
            summary.life_group_key(i), summary.baseline_rate_mV_h(i), ...
            summary.best_rate_mV_h(i), summary.best_benefit_vs_noEGR_pct(i), ...
            summary.best_egr_fraction_cmd(i));
    end
end
fprintf(fid, '\n## 后续耦合口径\n\n');
fprintf(fid, '寿命模型与电堆模型的推荐耦合方式是单向慢变量耦合：电堆输出 `V_cell_sim`、`current_density_A_cm2`、`RH_ca_in`、`T_stack_C`，寿命模型输出 `delta_V_deg_mV`、`life_damage_rate_mV_h`、`ECSA_ratio_proxy`。第一阶段不让寿命状态反向修正电压，第二阶段再通过 ECSA 或活化损失参数回馈。\n');
end
