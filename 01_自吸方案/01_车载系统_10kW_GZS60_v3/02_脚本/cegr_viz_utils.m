function varargout = cegr_viz_utils(action, varargin)
%CEGR_VIZ_UTILS Shared helpers for CEGR visualization scripts.

switch string(action)
    case "context"
        varargout{1} = makeContext();
    case "loadBench"
        varargout{1} = loadBench(varargin{:});
    case "loadOrRunBaseline"
        varargout{1} = loadOrRunBaseline(varargin{:});
    case "makeNoEgrValidation"
        [varargout{1:nargout}] = makeNoEgrValidation(varargin{:});
    case "runEgrConstantCurrent"
        [varargout{1:nargout}] = runEgrConstantCurrent(varargin{:});
    case "runEgrConstantVoltage"
        [varargout{1:nargout}] = runEgrConstantVoltage(varargin{:});
    case "runEgrConstantPO2"
        [varargout{1:nargout}] = runEgrConstantPO2(varargin{:});
    case "runSingleCase"
        [varargout{1:nargout}] = runSingleCase(varargin{:});
    case "plotNoEgrValidation"
        varargout{1} = plotNoEgrValidation(varargin{:});
    case "plotEgrMain"
        varargout{1} = plotEgrMain(varargin{:});
    case "plotEgrDiagnostics"
        varargout{1} = plotEgrDiagnostics(varargin{:});
    case "plotTopology"
        varargout{1} = plotTopology(varargin{:});
    case "closeFigures"
        closeFigures(varargin{:});
    case "writeSheet"
        writeResultSheet(varargin{:});
    otherwise
        error('CEGR:UnknownVizAction', 'Unknown visualization action: %s', action);
end
end

function C = makeContext()
P0 = init_vehicle_10kw_gzs60_v3("current");
C = struct();
C.P0 = P0;
C.rootDir = P0.rootDir;
C.model = P0.modelName;
C.modelFile = P0.modelFile;
C.benchFile = fullfile(C.rootDir, '00_输入参数', '全电流段极化标定', 'full_range_polarization_data.csv');
C.resultDir = fullfile(C.rootDir, '04_验证结果');
C.baselineFile = fullfile(C.resultDir, 'no_egr_frozen_baseline_reference.csv');
C.workbookFile = fullfile(C.resultDir, 'CEGR_visualization_results.xlsx');
if ~exist(C.resultDir, 'dir')
    mkdir(C.resultDir);
end
if ~isfile(C.modelFile)
    error('CEGR:MissingModel', 'Missing Simulink model: %s', C.modelFile);
end
if ~isfile(C.benchFile)
    error('CEGR:MissingBenchData', 'Missing bench data: %s', C.benchFile);
end
open_system(C.modelFile);
end

function B = loadBench(C)
B = readtable(C.benchFile, 'TextType', 'string');
if ismember("use_for_fit", string(B.Properties.VariableNames))
    B = B(logical(B.use_for_fit), :);
end
B = sortrows(B, "current_density_A_cm2");
end

function baseline = loadOrRunBaseline(C)
if isfile(C.baselineFile)
    baseline = readtable(C.baselineFile, 'TextType', 'string');
else
    results = run_vehicle_10kw_gzs60_v3_condition_extension("baseline");
    baseline = results.baseline;
end
baseline = sortrows(baseline, "current_density_A_cm2");
end

function [T, stats] = makeNoEgrValidation(C)
B = loadBench(C);
S = loadOrRunBaseline(C);
T = innerjoin(B, S, 'Keys', "case_id", ...
    'LeftVariables', ["case_id","current_A","current_density_A_cm2","cell_voltage_from_stack_V", ...
    "stack_temperature_est_C","pO2_caIn_kPa","pH2O_caIn_kPa","xO2_caIn","xH2O_caIn", ...
    "cathode_pressure_kPa_abs"], ...
    'RightVariables', ["V_cell_sim","T_stack_sim_C","pO2_ca_in_kPa","pH2O_caIn_kPa", ...
    "RH_ca_in","p_ca_in_sim_kPa","lambda_O2_actual","pressure_order_ok","oxygen_stoich_cmd"]);

T.Properties.VariableNames(strcmp(T.Properties.VariableNames, "cell_voltage_from_stack_V")) = "V_cell_meas";
T.Properties.VariableNames(strcmp(T.Properties.VariableNames, "stack_temperature_est_C")) = "T_stack_meas_C";
T.Properties.VariableNames(strcmp(T.Properties.VariableNames, "pO2_caIn_kPa")) = "pO2_ca_in_meas_kPa";
T.Properties.VariableNames(strcmp(T.Properties.VariableNames, "pH2O_caIn_kPa_B")) = "pH2O_ca_in_meas_kPa";
T.Properties.VariableNames(strcmp(T.Properties.VariableNames, "pH2O_caIn_kPa_S")) = "pH2O_ca_in_sim_kPa";
T.Properties.VariableNames(strcmp(T.Properties.VariableNames, "pO2_ca_in_kPa")) = "pO2_ca_in_sim_kPa";

T.omega_ca_in_meas_g_per_kg_dry_air = omegaFromMoleFractions(T.xO2_caIn, T.xH2O_caIn);
T.omega_ca_in_sim_g_per_kg_dry_air = omegaFromPressures(T.pO2_ca_in_sim_kPa, ...
    T.pH2O_ca_in_sim_kPa, T.p_ca_in_sim_kPa);
T.V_cell_err = T.V_cell_sim - T.V_cell_meas;
T.T_stack_err_C = T.T_stack_sim_C - T.T_stack_meas_C;
T.pO2_err_kPa = T.pO2_ca_in_sim_kPa - T.pO2_ca_in_meas_kPa;
T.omega_err_g_per_kg_dry_air = T.omega_ca_in_sim_g_per_kg_dry_air - T.omega_ca_in_meas_g_per_kg_dry_air;
T = sortrows(T, "current_density_A_cm2");

stats = table();
stats.metric = ["V_cell"; "T_stack_C"; "pO2_ca_in_kPa"; "omega_ca_in_g_per_kg_dry_air"];
stats.rmse = [rmse(T.V_cell_err); rmse(T.T_stack_err_C); rmse(T.pO2_err_kPa); rmse(T.omega_err_g_per_kg_dry_air)];
stats.max_abs_error = [max(abs(T.V_cell_err)); max(abs(T.T_stack_err_C)); max(abs(T.pO2_err_kPa)); max(abs(T.omega_err_g_per_kg_dry_air))];
stats.point_count = repmat(height(T), height(stats), 1);
end

function [T, runInfo] = runEgrConstantCurrent(C, options)
arguments
    C (1,1) struct
    options.CurrentDensity double = [0.1 0.2 0.3]
    options.OxygenStoich double = [5.0 3.5 3.0]
    options.InitialMaxEgr double = 0.5
    options.ExtendedMaxEgr double = 0.7
    options.BaseStep double = 0.05
    options.ExtendStep double = 0.1
    options.StopLambda double = 1.05
    options.ExtendLambda double = 1.20
end

if numel(options.CurrentDensity) ~= numel(options.OxygenStoich)
    error('CEGR:BadScanConfig', 'CurrentDensity and OxygenStoich must have the same length.');
end

B = loadBench(C);
rows = {};
for k = 1:numel(options.CurrentDensity)
    j = options.CurrentDensity(k);
    stoich = options.OxygenStoich(k);
    ratios = 0:options.BaseStep:options.InitialMaxEgr;
    ratioIdx = 1;
    while ratioIdx <= numel(ratios)
        r = ratios(ratioIdx);
        P = configureConstantCurrentCase(C.P0, B, j, stoich);
        [row, ~] = runOperatingCase(C, P, r, "constant_current_egr_fixed_total_compressor_flow");
        row.case_id = "j" + replace(string(sprintf('%.2f', j)), ".", "p") + "_egr" + replace(string(sprintf('%.2f', r)), ".", "p");
        row.current_density_A_cm2 = j;
        row.current_A = P.I_stack_default_A;
        row.oxygen_stoich_cmd = stoich;
        row.egr_ratio_cmd = r;
        row.fixed_total_compressor_flow = true;
        row.interpretation_status = interpretationStatus(row);
        rows{end + 1, 1} = struct2table(row); %#ok<AGROW>
        lastLambda = row.lambda_O2_actual;
        if lastLambda < options.StopLambda
            break;
        end
        if ratioIdx == numel(ratios) && ratios(end) < options.ExtendedMaxEgr && lastLambda >= options.ExtendLambda
            ratios = [ratios, ratios(end) + options.ExtendStep]; %#ok<AGROW>
        end
        ratioIdx = ratioIdx + 1;
    end
end
T = vertcat(rows{:});
T = movevars(T, ["case_id","condition","current_density_A_cm2","current_A","oxygen_stoich_cmd","egr_ratio_cmd", ...
    "interpretation_status","is_steady","oxygen_warning","severe_oxygen_starvation","pressure_order_ok"], 'Before', 1);
runInfo = makeRunInfo(C, "egr_constant_current");
end

function [T, runInfo, targets] = runEgrConstantVoltage(C, options)
arguments
    C (1,1) struct
    options.TargetVoltage double = [0.80 0.775 0.75]
    options.InitialMaxEgr double = 0.5
    options.ExtendedMaxEgr double = 0.7
    options.BaseStep double = 0.05
    options.ExtendStep double = 0.1
    options.StopLambda double = 1.05
    options.ExtendLambda double = 1.20
end

B = loadBench(C);
targets = makeVoltageTargets(C, B, options.TargetVoltage);
rows = {};
for k = 1:height(targets)
    target = targets(k, :);
    fixedBoundaryRow = nearestBenchRow(B, target.fixed_noEGR_boundary_current_density_A_cm2);
    ratios = buildInitialRatios(options.InitialMaxEgr, options.BaseStep);
    ratioIdx = 1;
    while ratioIdx <= numel(ratios)
        r = ratios(ratioIdx);
        [row, Pbest] = tuneCurrentForVoltage(C, B, target, r, fixedBoundaryRow);
        row.case_id = "v" + replace(string(sprintf('%.3f', target.V_cell_target)), ".", "p") ...
            + "_egr" + replace(string(sprintf('%.2f', r)), ".", "p");
        row.condition = "constant_voltage_egr_fixed_noEGR_supply_boundary";
        row.V_cell_target = target.V_cell_target;
        row.target_error_V = row.V_cell_sim - target.V_cell_target;
        row.reference_case_id = string(target.reference_case_id);
        row.reference_current_A = target.reference_current_A;
        row.reference_current_density_A_cm2 = target.reference_current_density_A_cm2;
        row.reference_V_cell = target.reference_V_cell;
        row.base_oxygen_stoich_cmd = target.base_oxygen_stoich_cmd;
        row.base_fresh_O2_flow_kg_s = target.base_fresh_O2_flow_kg_s;
        row.oxygen_stoich_cmd = Pbest.oxygen_stoich;
        row.fixed_noEGR_boundary_case_id = string(fixedBoundaryRow.case_id);
        row.fixed_noEGR_boundary_current_A = target.fixed_noEGR_boundary_current_A;
        row.fixed_noEGR_boundary_current_density_A_cm2 = target.fixed_noEGR_boundary_current_density_A_cm2;
        row.fixed_noEGR_boundary_source = "EGR0_voltage_solution_nearest_bench";
        row.egr_ratio_cmd = r;
        row.fixed_total_compressor_flow = true;
        row.interpretation_status = interpretationStatus(row);
        rows{end + 1, 1} = struct2table(row); %#ok<AGROW>
        lastLambda = row.lambda_O2_actual;
        if lastLambda < options.StopLambda
            break;
        end
        if ratioIdx == numel(ratios) && ratios(end) < options.ExtendedMaxEgr && lastLambda >= options.ExtendLambda
            ratios = [ratios, ratios(end) + options.ExtendStep]; %#ok<AGROW>
        end
        ratioIdx = ratioIdx + 1;
    end
end
T = vertcat(rows{:});
T = movevars(T, ["case_id","condition","V_cell_target","target_error_V","current_density_A_cm2", ...
    "current_A","oxygen_stoich_cmd","base_oxygen_stoich_cmd","egr_ratio_cmd", ...
    "interpretation_status","is_steady","oxygen_warning","severe_oxygen_starvation","pressure_order_ok"], 'Before', 1);
runInfo = makeRunInfo(C, "egr_constant_voltage");
end

function [T, runInfo] = runEgrConstantPO2(C, options)
arguments
    C (1,1) struct
    options.CurrentDensity double = [0.1 0.2 0.3]
    options.OxygenStoich double = [5.0 3.5 3.0]
    options.InitialMaxEgr double = 0.5
    options.ExtendedMaxEgr double = 0.7
    options.BaseStep double = 0.05
    options.ExtendStep double = 0.1
    options.StopLambda double = 1.05
    options.ExtendLambda double = 1.20
end

if numel(options.CurrentDensity) ~= numel(options.OxygenStoich)
    error('CEGR:BadScanConfig', 'CurrentDensity and OxygenStoich must have the same length.');
end

B = loadBench(C);
rows = {};
for k = 1:numel(options.CurrentDensity)
    j = options.CurrentDensity(k);
    baseStoich = options.OxygenStoich(k);
    Pbase = configureConstantCurrentCase(C.P0, B, j, baseStoich);
    [baseRow, ~] = runOperatingCase(C, Pbase, 0.0, "constant_pO2_no_egr_reference");
    targetPO2 = baseRow.pO2_ca_in_kPa;
    ratios = buildInitialRatios(options.InitialMaxEgr, options.BaseStep);
    ratioIdx = 1;
    while ratioIdx <= numel(ratios)
        r = ratios(ratioIdx);
        [row, Pbest] = tuneStoichForPO2(C, B, j, baseStoich, r, targetPO2);
        row.case_id = "po2_j" + replace(string(sprintf('%.2f', j)), ".", "p") ...
            + "_egr" + replace(string(sprintf('%.2f', r)), ".", "p");
        row.condition = "constant_pO2_egr_adjusted_compressor_flow";
        row.current_density_A_cm2 = j;
        row.current_A = Pbest.I_stack_default_A;
        row.pO2_target_kPa = targetPO2;
        row.pO2_error_kPa = row.pO2_ca_in_kPa - targetPO2;
        row.base_oxygen_stoich_cmd = baseStoich;
        row.oxygen_stoich_cmd = Pbest.oxygen_stoich;
        row.egr_ratio_cmd = r;
        row.fixed_total_compressor_flow = false;
        row.interpretation_status = interpretationStatus(row);
        row.scan_usable = row.pressure_order_ok;
        row.scan_stop_reason = "";
        if ~row.pressure_order_ok
            row.scan_stop_reason = "pressure_order_failed";
        end
        rows{end + 1, 1} = struct2table(row); %#ok<AGROW>
        lastLambda = row.lambda_O2_actual;
        if ~row.pressure_order_ok || lastLambda < options.StopLambda
            break;
        end
        if ratioIdx == numel(ratios) && ratios(end) < options.ExtendedMaxEgr && lastLambda >= options.ExtendLambda
            ratios = [ratios, ratios(end) + options.ExtendStep]; %#ok<AGROW>
        end
        ratioIdx = ratioIdx + 1;
    end
end
T = vertcat(rows{:});
T = movevars(T, ["case_id","condition","current_density_A_cm2","current_A","pO2_target_kPa", ...
    "pO2_error_kPa","oxygen_stoich_cmd","base_oxygen_stoich_cmd","egr_ratio_cmd", ...
    "interpretation_status","scan_usable","scan_stop_reason","is_steady","oxygen_warning", ...
    "severe_oxygen_starvation","pressure_order_ok"], 'Before', 1);
runInfo = makeRunInfo(C, "egr_constant_pO2");
end

function [row, detail] = runSingleCase(C, caseConfig)
caseConfig = normalizeCaseConfig(C.P0, caseConfig);
B = loadBench(C);
P = configureConstantCurrentCase(C.P0, B, caseConfig.current_density_A_cm2, caseConfig.oxygen_stoich);
P.I_stack_default_A = caseConfig.current_A;
P = updateModuleParamVectors(P);
[row, detail] = runOperatingCase(C, P, caseConfig.egr_ratio, "single_case_topology");
row.case_id = "single_case";
row.current_density_A_cm2 = caseConfig.current_density_A_cm2;
row.current_A = caseConfig.current_A;
row.oxygen_stoich_cmd = caseConfig.oxygen_stoich;
row.egr_ratio_cmd = caseConfig.egr_ratio;
row.fixed_total_compressor_flow = true;
row.interpretation_status = interpretationStatus(row);
end

function fig = plotNoEgrValidation(T, stats)
fig = figure('Name', 'CEGR 02 No-EGR Validation', 'Color', 'w');
tiledlayout(fig, 2, 2, 'Padding', 'compact', 'TileSpacing', 'compact');
j = T.current_density_A_cm2;

nexttile;
plotCompare(j, T.V_cell_meas, T.V_cell_sim, 'V_{cell} (V)');
title(sprintf('Cell voltage  RMSE %.4f V', stats.rmse(stats.metric=="V_cell")));

nexttile;
plotCompare(j, T.T_stack_meas_C, T.T_stack_sim_C, 'T_{stack} (degC)');
title(sprintf('Stack temperature  RMSE %.2f degC', stats.rmse(stats.metric=="T_stack_C")));

nexttile;
plotCompare(j, T.pO2_ca_in_meas_kPa, T.pO2_ca_in_sim_kPa, 'pO_2 cathode in (kPa)');
title(sprintf('Cathode inlet pO2  RMSE %.2f kPa', stats.rmse(stats.metric=="pO2_ca_in_kPa")));

nexttile;
plotCompare(j, T.omega_ca_in_meas_g_per_kg_dry_air, T.omega_ca_in_sim_g_per_kg_dry_air, ...
    'omega cathode in (g/kg dry gas)');
title(sprintf('Cathode inlet humidity ratio  RMSE %.2f g/kg', stats.rmse(stats.metric=="omega_ca_in_g_per_kg_dry_air")));

sgtitle('No-EGR validation against bench data');
end

function fig = plotEgrMain(T)
[groupVar, groupLabel, titlePrefix, fixedFlowText] = plotContext(T);
fig = figure('Name', figureNameFor(T, "Main"), 'Color', 'w');
tiledlayout(fig, 2, 3, 'Padding', 'compact', 'TileSpacing', 'compact');
if groupVar == "V_cell_target"
    metrics = {
        "current_A", "Current (A)", "Current response"
        "current_density_A_cm2", "Current density (A/cm^2)", "Current density response"
        "mH2_react_kg_s", "H_2 consumption (kg/s)", "Hydrogen consumption"
        "P_stack_W", "Stack power (W)", "Stack power"
        "lambda_O2_actual", "Actual O_2 stoich (-)", "Oxygen stoich"
        "omega_ca_in_g_per_kg_dry_air", "omega cathode in (g/kg dry gas)", "Humidification"
        };
elseif contains(string(T.condition(1)), "constant_pO2")
    metrics = {
        "V_cell_sim", "V_{cell} (V)", "Cell voltage"
        "pO2_ca_in_kPa", "pO_2 cathode in (kPa)", "Oxygen dilution"
        "lambda_O2_actual", "Actual O_2 stoich (-)", "Oxygen stoich"
        "flow_breakdown", "kg/s", "Compressor inlet mass flow"
        "pH2O_caIn_kPa", "pH_2O cathode in (kPa)", "Water vapor pressure"
        "p_ca_in_sim_kPa", "Cathode inlet pressure (kPa abs)", "Cathode inlet pressure"
        };
else
    metrics = {
        "V_cell_sim", "V_{cell} (V)", "Cell voltage"
        "pO2_ca_in_kPa", "pO_2 cathode in (kPa)", "Oxygen dilution"
        "lambda_O2_actual", "Actual O_2 stoich (-)", "Oxygen stoich"
        "omega_ca_in_g_per_kg_dry_air", "omega cathode in (g/kg dry gas)", "Humidification"
        "pH2O_caIn_kPa", "pH_2O cathode in (kPa)", "Water vapor pressure"
        "T_stack_sim_C", "T_{stack} (degC)", "Stack temperature"
        };
end
for k = 1:size(metrics, 1)
    nexttile;
    if metrics{k,1} == "flow_breakdown"
        Tplot = T;
        if ismember("scan_usable", string(Tplot.Properties.VariableNames))
            Tplot = Tplot(logical(Tplot.scan_usable), :);
        end
        plotMultiByGroup(Tplot, groupVar, groupLabel, ...
            ["m_fresh_actual_kg_s","m_egr_return_kg_s","m_compressor_in_kg_s"], ...
            ["fresh actual","EGR","compressor in"]);
        ylabel(metrics{k,2});
    else
        plotByGroup(T, groupVar, groupLabel, metrics{k,1}, metrics{k,2});
    end
    title(metrics{k,3});
    if metrics{k,1} == "lambda_O2_actual"
        yline(1.05, '--', 'warning', 'HandleVisibility', 'off');
        yline(1.00, ':', 'severe', 'HandleVisibility', 'off');
    end
end
sgtitle(titlePrefix + ": " + fixedFlowText);
end

function fig = plotEgrDiagnostics(T)
[groupVar, groupLabel, titlePrefix] = plotContext(T);
fig = figure('Name', figureNameFor(T, "Diagnostics"), 'Color', 'w');
tiledlayout(fig, 3, 3, 'Padding', 'compact', 'TileSpacing', 'compact');

nexttile;
plotPressureChain(T, groupVar, groupLabel);
title('Cathode pressure chain');
ylabel('kPa');

nexttile;
plotMultiByGroup(T, groupVar, groupLabel, ["dp_hum_dry_kPa","dp_hum_wet_kPa","dp_bp_valve_kPa"], ...
    ["hum dry","hum wet","bp"]);
title('Pressure drops');
ylabel('kPa');

nexttile;
plotByGroup(T, groupVar, groupLabel, "omega_ca_in_g_per_kg_dry_air", "omega cathode in (g/kg dry gas)");
title('Humidification');

nexttile;
plotMultiByGroup(T, groupVar, groupLabel, ["mH2O_ca_in_kg_s","mH2O_ca_out_kg_s","mH2O_hum_transfer_kg_s"], ...
    ["ca in","ca out","humidifier transfer"]);
title('Water flows');
ylabel('kg/s');

nexttile;
plotMultiByGroup(T, groupVar, groupLabel, ["mO2_react_kg_s","mH2_react_kg_s","mH2O_prod_kg_s"], ...
    ["O2 react","H2 react","H2O prod"]);
title('Reaction source terms');
ylabel('kg/s');

nexttile;
plotMultiByGroup(T, groupVar, groupLabel, ["Q_gen_W","Q_cool_W","Q_amb_W","Q_gas_W"], ...
    ["gen","cool","amb","gas"]);
title('Stack heat terms');
ylabel('W');

nexttile;
plotMultiByGroup(T, groupVar, groupLabel, ["T_ca_in_C","T_stack_sim_C","T_hum_wet_out_C"], ...
    ["ca in","stack","hum wet out"]);
title('Temperatures');
ylabel('degC');

nexttile;
semilogyByGroup(T, groupVar, groupLabel, "max_species_residual_kg_s", 'max species residual (kg/s)');
title('Species residual');

nexttile;
plotStatusMap(T, groupVar, groupLabel);
title('Interpretation status');

sgtitle(titlePrefix + " diagnostics");
end

function fig = plotTopology(row, detail)
fig = figure('Name', 'CEGR 01 Single Case Topology', 'Color', 'w');
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
drawPanel(ax, [0.018 0.035 0.964 0.095], '运行诊断', [0.96 0.98 0.96], egrColor);
drawPanel(ax, [0.025 0.565 0.950 0.285], '阴极空气供给链路', [0.965 0.982 0.995], airColor);
drawPanel(ax, [0.025 0.210 0.950 0.320], '电堆反应与尾气循环', [0.985 0.978 0.968], stackColor);

boxes = {
    "环境入口", [0.035 0.625 0.175 0.200], sprintf('温度 %.1f ℃\n压力 %.1f kPa\n相对湿度 %.2f\n新鲜空气 %.5f kg/s', ...
        detail.env.T_C, detail.env.p_kPa, detail.env.RH, row.m_fresh_cmd_kg_s), airColor, [0.91 0.96 1.00]
    "EGR混合器", [0.245 0.625 0.165 0.200], sprintf('循环比 %.2f\n新鲜空气 %.5f\n循环气 %.5f\n混合xO2 %.3f\n含湿量 %.1f g/kg', ...
        row.egr_ratio_cmd, row.m_fresh_actual_kg_s, row.m_egr_return_kg_s, detail.mixer.xO2, detail.mixer.omega_g_per_kg), egrColor, [0.92 0.98 0.94]
    "空压机", [0.430 0.630 0.150 0.190], sprintf('入口流量 %.4f kg/s\n出口压力 %.1f kPa\n出口温度 %.1f ℃', ...
        row.m_compressor_in_kg_s, detail.compressor.p_kPa, detail.compressor.T_C), airColor, [0.92 0.96 1.00]
    "中冷器", [0.595 0.630 0.140 0.190], sprintf('出口温度 %.1f ℃\n出口压力 %.1f kPa', ...
        detail.intercooler.T_C, detail.intercooler.p_kPa), airColor, [0.92 0.96 1.00]
    "增湿器干侧", [0.775 0.630 0.150 0.190], sprintf('出口 -> 电堆\nT %.1f ℃\npO2 %.1f kPa\npH2O %.1f kPa\nω %.1f g/kg', ...
        detail.dry.T_C, row.pO2_ca_in_kPa, row.pH2O_caIn_kPa, row.omega_ca_in_g_per_kg_dry_air), airColor, [0.92 0.96 1.00]
    "EGR阀 / 排气", [0.255 0.255 0.220 0.255], sprintf('湿侧出口 %.5f\n循环气 %.5f\n排气 %.5f\n出口压力 %.1f kPa\n排气边界 %.1f kPa', ...
        row.m_wet_out_kg_s, row.m_egr_return_kg_s, row.m_vent_out_kg_s, row.p_wet_out_kPa, row.p_vent_out_kPa), egrColor, [0.94 0.98 0.94]
    "增湿器湿侧", [0.525 0.255 0.175 0.255], sprintf('电堆尾气入口\n湿侧出口 %.5f\n湿侧压力 %.1f kPa\n膜传水 %.2g kg/s', ...
        row.m_wet_out_kg_s, row.p_wet_out_kPa, row.mH2O_hum_transfer_kg_s), exhaustColor, [0.96 0.97 0.98]
    "PEMFC电堆", [0.735 0.260 0.240 0.245], sprintf('电流密度 %.2f A/cm2\n电流 %.2f A\n单电池电压 %.3f V  功率 %.0f W\n温度 %.1f ℃  氧计量比 %.2f\n入堆压力 %.1f kPa\n堆内压力 %.1f kPa', ...
        row.current_density_A_cm2, row.current_A, row.V_cell_sim, row.P_stack_W, row.T_stack_sim_C, row.lambda_O2_actual, row.p_ca_in_sim_kPa, row.p_stack_internal_kPa), stackColor, [1.00 0.94 0.92]
    };

boxTextHandles = gobjects(size(boxes, 1), 2);
for k = 1:size(boxes, 1)
    boxTextHandles(k, :) = drawBox(ax, boxes{k,2}, boxes{k,1}, boxes{k,3}, boxes{k,4}, boxes{k,5});
end

drawArrow(ax, [0.210 0.725], [0.245 0.725], airColor, 2.2, '-');
drawArrow(ax, [0.410 0.725], [0.430 0.725], airColor, 2.2, '-');
drawArrow(ax, [0.580 0.725], [0.595 0.725], airColor, 2.2, '-');
drawArrow(ax, [0.735 0.725], [0.775 0.725], airColor, 2.2, '-');
drawPolylineArrow(ax, [0.850 0.630; 0.850 0.545; 0.855 0.505], airColor, 2.0, '-');
drawArrow(ax, [0.735 0.383], [0.700 0.383], exhaustColor, 2.0, '-');
drawArrow(ax, [0.525 0.383], [0.475 0.383], exhaustColor, 2.0, '-');
drawPolylineArrow(ax, [0.370 0.510; 0.330 0.600; 0.315 0.625], egrColor, 2.4, '--');
drawArrow(ax, [0.255 0.383], [0.055 0.383], exhaustColor, 2.0, '-');

text(ax, 0.050, 0.560, '空气主流', 'FontSize', 9, 'FontWeight', 'bold', 'Color', airColor);
text(ax, 0.300, 0.545, 'EGR回流支路', 'FontSize', 9, 'FontWeight', 'bold', 'Color', egrColor);
text(ax, 0.070, 0.355, '排气', 'FontSize', 9, 'FontWeight', 'bold', 'Color', exhaustColor);

conditionText = sprintf(['单工况计算   电流密度 %.2f A/cm2   电流 %.2f A   EGR %.2f   ', ...
    '氧计量比命令 %.2f   固定空压机入口流量 %d'], ...
    row.current_density_A_cm2, row.current_A, row.egr_ratio_cmd, row.oxygen_stoich_cmd, row.fixed_total_compressor_flow);
text(ax, 0.050, 0.918, conditionText, 'FontSize', 12, 'FontWeight', 'bold', 'Interpreter', 'none', 'Color', [0.10 0.12 0.14]);

massText = sprintf('质量闭合: 空压机入口 - 实际新鲜空气 - EGR = %.2e kg/s', row.mass_closure_compressor_kg_s);
statusText = sprintf('状态 %s   稳态 %d   压力顺序 %d   缺氧预警 %d   %s', ...
    row.interpretation_status, row.is_steady, row.pressure_order_ok, row.oxygen_warning, massText);
text(ax, 0.050, 0.068, statusText, 'FontSize', 11, 'FontWeight', 'bold', 'Interpreter', 'none', 'Color', [0.10 0.14 0.12]);
title(ax, '10 kW车载燃料电池cEGR系统单工况仿真控制台', 'FontWeight', 'bold');
assignin('base', 'cegrTopologyBoxLayout', boxes);
assignin('base', 'cegrTopologyTextHandles', boxTextHandles);
end

function targets = makeVoltageTargets(C, B, targetVoltages)
targets = table();
for k = 1:numel(targetVoltages)
    targetV = targetVoltages(k);
    [~, idx] = min(abs(B.cell_voltage_from_stack_V - targetV));
    ref = B(idx, :);
    baseStoich = round(cathodeStoichFromBench(ref, C.P0), 1);
    baseStoich = max(baseStoich, 0.5);
    [probeRow, Pprobe] = tuneNoEgrVoltageBaseFixedStoich(C, B, targetV, ref.current_A, baseStoich);
    fixedBoundary = nearestBenchRow(B, Pprobe.I_stack_default_A / C.P0.A_cell_cm2);
    fixedBoundaryStoich = round(cathodeStoichFromBench(fixedBoundary, C.P0), 1);
    fixedBoundaryStoich = max(fixedBoundaryStoich, 0.5);
    baseO2Flow = freshO2FlowFromCurrent(C.P0, fixedBoundary.current_A, fixedBoundaryStoich);
    [baseRow, Pbase] = tuneCurrentForVoltageFlow(C, B, targetV, baseO2Flow, 0.0, Pprobe.I_stack_default_A, fixedBoundary);
    row = table();
    row.V_cell_target = targetV;
    row.reference_case_id = string(ref.case_id);
    row.nearest_bench_current_A = ref.current_A;
    row.nearest_bench_current_density_A_cm2 = ref.current_density_A_cm2;
    row.nearest_bench_V_cell = ref.cell_voltage_from_stack_V;
    row.boundary_probe_current_A = Pprobe.I_stack_default_A;
    row.boundary_probe_current_density_A_cm2 = Pprobe.I_stack_default_A / C.P0.A_cell_cm2;
    row.boundary_probe_V_cell = probeRow.V_cell_sim;
    row.fixed_noEGR_boundary_case_id = string(fixedBoundary.case_id);
    row.fixed_noEGR_boundary_current_A = fixedBoundary.current_A;
    row.fixed_noEGR_boundary_current_density_A_cm2 = fixedBoundary.current_density_A_cm2;
    row.fixed_noEGR_boundary_oxygen_stoich_cmd = fixedBoundaryStoich;
    row.reference_current_A = Pbase.I_stack_default_A;
    row.reference_current_density_A_cm2 = Pbase.I_stack_default_A / C.P0.A_cell_cm2;
    row.reference_V_cell = baseRow.V_cell_sim;
    row.reference_voltage_error_V = baseRow.V_cell_sim - targetV;
    row.base_oxygen_stoich_cmd = Pbase.oxygen_stoich;
    row.base_fresh_O2_flow_kg_s = baseO2Flow;
    targets = [targets; row]; %#ok<AGROW>
end
end

function [bestRow, Pbest] = tuneNoEgrVoltageBaseFixedStoich(C, B, targetV, refCurrent, oxygenStoich)
maxCurrent = 0.98 * C.P0.A_cell_cm2 * 2.0;
low = 0.5;
high = min(maxCurrent, max(refCurrent * 1.25, low + 1));
[lowRow, lowP] = runVoltageAtCurrentFixedStoich(C, B, targetV, oxygenStoich, 0.0, low);
[highRow, highP] = runVoltageAtCurrentFixedStoich(C, B, targetV, oxygenStoich, 0.0, high);
while highRow.V_cell_sim > targetV && high < maxCurrent
    low = high;
    lowRow = highRow;
    lowP = highP;
    high = min(maxCurrent, high * 1.8);
    [highRow, highP] = runVoltageAtCurrentFixedStoich(C, B, targetV, oxygenStoich, 0.0, high);
end
while lowRow.V_cell_sim < targetV && low > 0.5
    high = low;
    highRow = lowRow;
    highP = lowP;
    low = max(0.5, low * 0.5);
    [lowRow, lowP] = runVoltageAtCurrentFixedStoich(C, B, targetV, oxygenStoich, 0.0, low);
end

candidates = {lowRow, highRow};
candidateP = {lowP, highP};
if lowRow.V_cell_sim >= targetV && highRow.V_cell_sim <= targetV
    for iter = 1:8
        mid = 0.5 * (low + high);
        [midRow, midP] = runVoltageAtCurrentFixedStoich(C, B, targetV, oxygenStoich, 0.0, mid);
        candidates{end + 1} = midRow; %#ok<AGROW>
        candidateP{end + 1} = midP; %#ok<AGROW>
        if midRow.V_cell_sim >= targetV
            low = mid;
        else
            high = mid;
        end
    end
end

bestIdx = closestVoltageCandidate(candidates, targetV);
bestRow = candidates{bestIdx};
Pbest = candidateP{bestIdx};
roundedCurrent = round(Pbest.I_stack_default_A, 2);
if abs(roundedCurrent - Pbest.I_stack_default_A) > 1e-9
    [bestRow, Pbest] = runVoltageAtCurrentFixedStoich(C, B, targetV, oxygenStoich, 0.0, roundedCurrent);
end
end

function [row, Pbest] = tuneCurrentForVoltage(C, B, target, egrRatio, fixedBoundaryRow)
refCurrent = max(target.reference_current_A, 0.5);
[row, Pbest] = tuneCurrentForVoltageFlow(C, B, target.V_cell_target, target.base_fresh_O2_flow_kg_s, egrRatio, refCurrent, fixedBoundaryRow);
row.voltage_search_abs_error_V = abs(row.V_cell_sim - target.V_cell_target);
end

function [bestRow, Pbest] = tuneCurrentForVoltageFlow(C, B, targetV, fixedO2Flow, egrRatio, refCurrent, fixedBoundaryRow)
maxCurrent = min(0.98 * C.P0.A_cell_cm2 * 2.0, max(10, stoichLimitedCurrent(C.P0, fixedO2Flow, 0.22)));
low = max(0.5, min(refCurrent * 0.02, maxCurrent));
high = min(maxCurrent, max(refCurrent * 1.25, low + 1));
[lowRow, lowP] = runVoltageAtCurrent(C, B, targetV, fixedO2Flow, egrRatio, low, fixedBoundaryRow);
[highRow, highP] = runVoltageAtCurrent(C, B, targetV, fixedO2Flow, egrRatio, high, fixedBoundaryRow);
while highRow.V_cell_sim > targetV && high < maxCurrent
    low = high;
    lowRow = highRow;
    lowP = highP;
    high = min(maxCurrent, high * 1.8);
    [highRow, highP] = runVoltageAtCurrent(C, B, targetV, fixedO2Flow, egrRatio, high, fixedBoundaryRow);
end
while lowRow.V_cell_sim < targetV && low > 0.5
    high = low;
    highRow = lowRow;
    highP = lowP;
    low = max(0.5, low * 0.5);
    [lowRow, lowP] = runVoltageAtCurrent(C, B, targetV, fixedO2Flow, egrRatio, low, fixedBoundaryRow);
end

candidates = {lowRow, highRow};
candidateP = {lowP, highP};
if lowRow.V_cell_sim >= targetV && highRow.V_cell_sim <= targetV
    for iter = 1:8
        mid = 0.5 * (low + high);
        [midRow, midP] = runVoltageAtCurrent(C, B, targetV, fixedO2Flow, egrRatio, mid, fixedBoundaryRow);
        candidates{end + 1} = midRow; %#ok<AGROW>
        candidateP{end + 1} = midP; %#ok<AGROW>
        if midRow.V_cell_sim >= targetV
            low = mid;
        else
            high = mid;
        end
    end
end

bestIdx = closestVoltageCandidate(candidates, targetV);
bestRow = candidates{bestIdx};
Pbest = candidateP{bestIdx};
roundedCurrent = round(Pbest.I_stack_default_A, 2);
if abs(roundedCurrent - Pbest.I_stack_default_A) > 1e-9
    [bestRow, Pbest] = runVoltageAtCurrent(C, B, targetV, fixedO2Flow, egrRatio, roundedCurrent, fixedBoundaryRow);
end
end

function [row, P] = runVoltageAtCurrent(C, B, targetV, fixedO2Flow, egrRatio, currentA, fixedBoundaryRow)
stoich = stoichForFixedO2Flow(C.P0, fixedO2Flow, currentA);
if nargin >= 7 && ~isempty(fixedBoundaryRow)
    P = configureFixedBoundaryCurrentCase(C.P0, fixedBoundaryRow, currentA, stoich);
else
    P = configureInterpolatedCurrentCase(C.P0, B, currentA, stoich);
end
[row, ~] = runOperatingCase(C, P, egrRatio, "constant_voltage_trial");
row.V_cell_target = targetV;
row.target_error_V = row.V_cell_sim - targetV;
end

function [row, P] = runVoltageAtCurrentFixedStoich(C, B, targetV, oxygenStoich, egrRatio, currentA)
P = configureInterpolatedCurrentCase(C.P0, B, currentA, oxygenStoich);
[row, ~] = runOperatingCase(C, P, egrRatio, "constant_voltage_base_trial");
row.V_cell_target = targetV;
row.target_error_V = row.V_cell_sim - targetV;
end

function bestIdx = closestVoltageCandidate(candidates, targetV)
bestIdx = 1;
bestErr = inf;
for k = 1:numel(candidates)
    row = candidates{k};
    err = abs(row.V_cell_sim - targetV);
    if err < bestErr
        bestErr = err;
        bestIdx = k;
    end
end
end

function currentA = stoichLimitedCurrent(P, mO2, minStoich)
nO2 = max(mO2, 1e-7) / P.M_O2_kg_mol;
currentA = nO2 * 4 * P.F_C_mol / max(minStoich * P.N_cell, 1e-9);
end

function [row, Pbest] = tuneStoichForPO2(C, B, currentDensity, baseStoich, egrRatio, targetPO2)
lambdaGrid = unique(max(0.2, [0.8 0.9 1.0 1.2 1.6 2.2 3.0 4.0] * baseStoich));
bestRow = [];
Pbest = C.P0;
bestScore = inf;
for k = 1:numel(lambdaGrid)
    stoich = max(lambdaGrid(k), 0.2);
    P = configureConstantCurrentCase(C.P0, B, currentDensity, stoich);
    [trial, ~] = runOperatingCase(C, P, egrRatio, "constant_pO2_trial");
    err = abs(trial.pO2_ca_in_kPa - targetPO2);
    if err < bestScore
        bestScore = err;
        bestRow = trial;
        Pbest = P;
    end
end
if bestScore > 0.25
    span = max(0.4, 0.20 * Pbest.oxygen_stoich);
    refined = unique(max(0.2, linspace(Pbest.oxygen_stoich - span, Pbest.oxygen_stoich + span, 5)));
    for k = 1:numel(refined)
        P = configureConstantCurrentCase(C.P0, B, currentDensity, refined(k));
        [trial, ~] = runOperatingCase(C, P, egrRatio, "constant_pO2_trial");
        err = abs(trial.pO2_ca_in_kPa - targetPO2);
        if err < bestScore
            bestScore = err;
            bestRow = trial;
            Pbest = P;
        end
    end
end
row = bestRow;
end

function P = configureConstantCurrentCase(P, B, currentDensity, oxygenStoich)
[~, idx] = min(abs(B.current_density_A_cm2 - currentDensity));
row = B(idx, :);
currentA = currentDensity * P.A_cell_cm2;
row.current_A = currentA;
row.current_density_A_cm2 = currentDensity;
P = configureCaseFromBenchRow(P, row, currentA, oxygenStoich);
end

function P = configureInterpolatedCurrentCase(P, B, currentA, oxygenStoich)
currentDensity = currentA / P.A_cell_cm2;
row = nearestBenchRow(B, currentDensity);
row.current_A = currentA;
row.current_density_A_cm2 = currentDensity;
P = configureCaseFromBenchRow(P, row, currentA, oxygenStoich);
end

function P = configureFixedBoundaryCurrentCase(P, boundaryRow, currentA, oxygenStoich)
currentDensity = currentA / P.A_cell_cm2;
row = boundaryRow;
row.current_A = currentA;
row.current_density_A_cm2 = currentDensity;
P = configureCaseFromBenchRow(P, row, currentA, oxygenStoich);
end

function P = configureCaseFromBenchRow(P, row, currentA, oxygenStoich)
P.I_stack_default_A = currentA;
P.oxygen_stoich = oxygenStoich;
P.anode_stoich = row.anode_stoich;
P.RH_an_in = row.anode_RH;
P.p_anode_in_kPa = row.anode_pressure_kPa_abs;
P.p_anode_back_kPa = row.anode_outlet_pressure_kPa_g + P.p_amb_kPa;
P.p_cathode_back_kPa = row.cathode_outlet_pressure_kPa_g + P.p_amb_kPa;
P.T_cool_C = row.coolant_inlet_temp_C;
P.coolant_flow_L_min = row.coolant_flow_L_min;
P.intercooler_T_C = row.cathode_inlet_temp_C;
P.EnvParam(6) = max(row.cathode_inlet_temp_C - P.compressor_dT_C, -20);
P.EnvParam(11) = P.oxygen_stoich;
P.IntercoolerParam(5) = P.intercooler_T_C;
dryDp = estimateHumidifierDryDp(P, currentA, P.oxygen_stoich);
P.compressor_dp_kPa = max(row.cathode_pressure_kPa_abs - P.p_amb_kPa + P.intercooler_dp_kPa + dryDp, 1.0);
P = updateModuleParamVectors(P);
P.stack_initial_state_audit = buildStackInitialAudit(P, row.cathode_pressure_kPa_abs, P.p_anode_back_kPa, row.stack_temperature_est_C);
P.wet_initial_node = [0 0 0 0 row.cathode_outlet_temp_C P.p_cathode_back_kPa 0]';
end

function row = nearestBenchRow(B, currentDensity)
[~, idx] = min(abs(B.current_density_A_cm2 - currentDensity));
row = B(idx, :);
end

function lambda = cathodeStoichFromBench(row, P)
if ismember("cathode_stoich", string(row.Properties.VariableNames)) && isfinite(row.cathode_stoich)
    lambda = row.cathode_stoich;
    return;
end
flow_m3_s = row.cathode_flow_nlpm / 60000;
nTotal = flow_m3_s / 0.022414;
nO2 = P.xO2_dry * nTotal;
nO2Need = row.current_A * P.N_cell / (4 * P.F_C_mol);
lambda = nO2 / max(nO2Need, 1e-12);
end

function mO2 = freshO2FlowFromCurrent(P, currentA, oxygenStoich)
nO2 = oxygenStoich * max(currentA, 0) * P.N_cell / (4 * P.F_C_mol);
mO2 = max(nO2 * P.M_O2_kg_mol, 1e-7);
end

function stoich = stoichForFixedO2Flow(P, mO2, currentA)
nO2 = max(mO2, 1e-7) / P.M_O2_kg_mol;
stoich = nO2 * 4 * P.F_C_mol / max(currentA * P.N_cell, 1e-9);
stoich = max(stoich, 0.2);
end

function ratios = buildInitialRatios(initialMax, step)
ratios = 0:step:initialMax;
ratios(abs(ratios) < 1e-12) = 0;
end

function [row, detail] = runOperatingCase(C, P, egrRatio, condition)
stopTime = 120;
out = runOneSim(C, P, stopTime, egrRatio);
[row, detail] = parseOutput(out, P, C.model, stopTime, egrRatio, condition);
if ~row.is_steady
    stopTime = 300;
    out = runOneSim(C, P, stopTime, egrRatio);
    [row, detail] = parseOutput(out, P, C.model, stopTime, egrRatio, condition);
end
end

function out = runOneSim(C, P, stopTime, egrRatio)
in = Simulink.SimulationInput(C.model);
in = in.setModelParameter('StopTime', num2str(stopTime));
in = in.setVariable('EnvParam_v2', P.EnvParam, 'Workspace', C.model);
in = in.setVariable('CompressorParam_v2', P.CompressorParam, 'Workspace', C.model);
in = in.setVariable('IntercoolerParam_v2', P.IntercoolerParam, 'Workspace', C.model);
in = in.setVariable('HumidifierParam_v2', P.HumidifierParam, 'Workspace', C.model);
in = in.setVariable('StackParam_v2', P.StackParam, 'Workspace', C.model);
in = in.setVariable('I_stack_cmd_A', P.I_stack_default_A, 'Workspace', C.model);
in = in.setVariable('egr_fraction_cmd', egrRatio, 'Workspace', C.model);
in = in.setVariable('StackInitialStateAudit_v3', P.stack_initial_state_audit, 'Workspace', C.model);
in = in.setVariable('EGRInitialNode_v2', P.egr_initial_node, 'Workspace', C.model);
in = in.setVariable('WetInitialNode_v2', P.wet_initial_node, 'Workspace', C.model);
simOut = sim(in);
names = ["summary_vector","fresh_node","mixer_node","compressor_node","intercooler_node", ...
    "humidifier_dry_node","humidifier_wet_node","stack_ca_out_node","stack_an_out_node", ...
    "egr_return_node","vent_node","state_vector"];
for k = 1:numel(names)
    out.(names(k)) = simOut.(names(k));
end
end

function [row, detail] = parseOutput(out, P, model, stopTime, egrRatio, condition)
fields = summaryFields();
s = summaryStruct(vectorAt(out.summary_vector, numel(fields), "final"), fields);
fresh = nodeStruct(vectorAt(out.fresh_node, 7, "final"));
mixer = nodeStruct(vectorAt(out.mixer_node, 7, "final"));
compressor = nodeStruct(vectorAt(out.compressor_node, 7, "final"));
intercooler = nodeStruct(vectorAt(out.intercooler_node, 7, "final"));
dry = nodeStruct(vectorAt(out.humidifier_dry_node, 7, "final"));
wet = nodeStruct(vectorAt(out.humidifier_wet_node, 7, "final"));
caOut = nodeStruct(vectorAt(out.stack_ca_out_node, 7, "final"));
egr = nodeStruct(vectorAt(out.egr_return_node, 7, "final"));
vent = nodeStruct(vectorAt(out.vent_node, 7, "final"));
steady = steadyCheck(out, stopTime);

row = struct();
row.case_id = "";
row.condition = string(condition);
row.stop_time_s = stopTime;
row.is_steady = steady.is_steady;
row.egr_ratio_cmd = egrRatio;
row.current_A = P.I_stack_default_A;
row.current_density_A_cm2 = P.I_stack_default_A / P.A_cell_cm2;
row.V_cell_sim = s.V_cell;
row.V_stack_sim = P.N_cell * s.V_cell;
row.P_stack_W = s.P_stack_W;
row.pO2_ca_in_kPa = s.pO2_ca_in_kPa;
row.pH2O_caIn_kPa = dry.pH2O_kPa;
row.omega_ca_in_g_per_kg_dry_air = dry.omega_g_per_kg;
row.RH_ca_in = dry.RH;
row.xO2_ca_in = s.xO2_ca_in;
row.T_ca_in_C = dry.T_C;
row.T_stack_sim_C = s.T_stack_C;
row.T_hum_wet_out_C = wet.T_C;
row.lambda_O2_actual = s.lambda_O2_actual;
row.pressure_order_ok = dry.p_kPa > s.pCa_kPa && s.pCa_kPa > P.p_cathode_back_kPa;
row.p_ca_in_sim_kPa = dry.p_kPa;
row.p_stack_internal_kPa = s.pCa_kPa;
row.p_ca_out_boundary_kPa = P.p_cathode_back_kPa;
row.p_wet_out_kPa = s.p_wet_out_kPa;
row.p_vent_out_kPa = s.p_vent_out_kPa;
row.dp_hum_dry_kPa = s.dp_hum_dry_kPa;
row.dp_hum_wet_kPa = s.dp_hum_wet_kPa;
row.dp_bp_valve_kPa = s.dp_bp_valve_kPa;
freshCmdMass = s.m_fresh_in_kg_s;
egrMass = s.m_egr_return_kg_s;
compressorInMass = mixer.m_gas_kg_s;
actualFreshMass = max(compressorInMass - egrMass, 0);
row.m_fresh_cmd_kg_s = freshCmdMass;
row.m_fresh_actual_kg_s = actualFreshMass;
row.m_compressor_in_kg_s = compressorInMass;
row.m_fresh_in_kg_s = actualFreshMass;
row.m_egr_return_kg_s = s.m_egr_return_kg_s;
row.m_vent_out_kg_s = s.m_vent_out_kg_s;
row.m_wet_out_kg_s = s.m_wet_out_kg_s;
row.mass_closure_compressor_kg_s = compressorInMass - actualFreshMass - egrMass;
row.m_ca_in_actual_kg_s = s.m_ca_in_actual_kg_s;
row.m_ca_out_kg_s = s.m_ca_out_kg_s;
row.mH2O_ca_in_kg_s = s.mH2O_ca_in_kg_s;
row.mH2O_ca_out_kg_s = s.mH2O_ca_out_kg_s;
row.mH2O_hum_transfer_kg_s = s.mH2O_hum_transfer_kg_s;
row.mO2_react_kg_s = s.mO2_react_kg_s;
row.mH2_react_kg_s = s.mH2_react_kg_s;
row.mH2O_prod_kg_s = s.mH2O_prod_kg_s;
row.Q_gen_W = s.Q_gen_W;
row.Q_cool_W = s.Q_cool_W;
row.Q_amb_W = s.Q_amb_W;
row.Q_gas_W = s.Q_gas_W;
row.Q_net_stack_W = s.Q_net_stack_W;
row.energy_residual_W = s.energy_residual_W;
row.max_species_residual_kg_s = s.max_species_residual_kg_s;
row.oxygen_stoich_cmd = P.oxygen_stoich;
row.oxygen_warning = s.lambda_O2_actual < 1.05;
row.severe_oxygen_starvation = s.lambda_O2_actual < 1.0;
row.dV_cell_30s = steady.dV_cell;
row.dT_stack_30s_C = steady.dT_stack;
row.dRH_ca_in_30s = steady.dRH_ca_in;
row.model_name = string(model);

detail = struct();
detail.env = struct('T_C', P.T_amb_C, 'p_kPa', P.p_amb_kPa, 'RH', P.RH_amb);
detail.fresh = fresh;
detail.mixer = mixer;
detail.compressor = compressor;
detail.intercooler = intercooler;
detail.dry = dry;
detail.wet = wet;
detail.caOut = caOut;
detail.egr = egr;
detail.vent = vent;
detail.summary = s;
end

function config = normalizeCaseConfig(P0, config)
if nargin < 2 || isempty(config)
    config = struct();
end
if ~isfield(config, 'current_density_A_cm2')
    config.current_density_A_cm2 = 0.1;
end
if ~isfield(config, 'current_A')
    config.current_A = config.current_density_A_cm2 * P0.A_cell_cm2;
end
if ~isfield(config, 'oxygen_stoich')
    if abs(config.current_density_A_cm2 - 0.1) < 1e-9
        config.oxygen_stoich = 5.0;
    elseif abs(config.current_density_A_cm2 - 0.2) < 1e-9
        config.oxygen_stoich = 3.5;
    else
        config.oxygen_stoich = 3.0;
    end
end
if ~isfield(config, 'egr_ratio')
    config.egr_ratio = 0.3;
end
end

function status = interpretationStatus(row)
if ~row.is_steady
    status = "not_steady";
elseif ~row.pressure_order_ok
    status = "pressure_order_failed";
elseif row.severe_oxygen_starvation
    status = "severe_oxygen_starvation";
elseif row.oxygen_warning
    status = "oxygen_warning";
else
    status = "normal";
end
end

function writeResultSheet(C, sheetName, T)
if isempty(T)
    return;
end
writetable(T, C.workbookFile, 'Sheet', char(sheetName), 'WriteMode', 'overwritesheet');
end

function closeFigures(names)
if nargin < 1 || isempty(names)
    names = [
        "CEGR 01 Single Case Topology"
        "CEGR 02 No-EGR Validation"
        "CEGR 03 Constant Current Main"
        "CEGR 04 Constant Current Diagnostics"
        "CEGR 05 Constant Voltage Main"
        "CEGR 06 Constant Voltage Diagnostics"
        "CEGR 07 Constant pO2 Main"
        "CEGR 08 Constant pO2 Diagnostics"
        ];
end
for k = 1:numel(names)
    figs = findall(0, 'Type', 'figure', 'Name', char(names(k)));
    if ~isempty(figs)
        close(figs);
    end
end
end

function info = makeRunInfo(C, runType)
info = table();
info.run_time = string(datetime('now', 'Format', 'yyyy-MM-dd HH:mm:ss'));
info.run_type = string(runType);
info.model_name = string(C.model);
info.model_file = string(C.modelFile);
info.workbook_file = string(C.workbookFile);
end

function P = updateModuleParamVectors(P)
P.EnvParam(11) = P.oxygen_stoich;
P.CompressorParam(1) = P.compressor_dp_kPa;
P.CompressorParam(2) = P.compressor_dT_C;
P.IntercoolerParam(5) = P.intercooler_T_C;
P.IntercoolerParam(6) = P.intercooler_dp_kPa;
P.HumidifierParam(5) = P.intercooler_T_C;
P.StackParam(15) = P.p_cathode_back_kPa;
P.StackParam(16) = P.p_anode_back_kPa;
P.StackParam(20) = P.T_cool_C;
P.StackParam(33) = P.anode_stoich;
P.StackParam(34) = P.RH_an_in;
P.StackParam(37) = P.p_anode_in_kPa;
P.StackParam(44) = P.coolant_flow_L_min;
end

function x0 = buildStackInitialAudit(P, pCaKPa, pAnKPa, T_C)
TK = T_C + 273.15;
pSat = saturationPressureKPa(T_C);
pH2Oca = min(0.60 * pSat, pCaKPa - 1e-6);
pDryCa = max(pCaKPa - pH2Oca, 1e-6);
pO2 = 0.21 * pDryCa;
pN2 = 0.79 * pDryCa;
pH2Oan = min(P.RH_an_in * pSat, pAnKPa - 1e-6);
pH2 = max(pAnKPa - pH2Oan, 1e-6);
x0 = [
    pO2 * 1000 * P.V_ca_m3 * P.M_O2_kg_mol / (P.R_J_molK * TK)
    pN2 * 1000 * P.V_ca_m3 * P.M_N2_kg_mol / (P.R_J_molK * TK)
    pH2Oca * 1000 * P.V_ca_m3 * P.M_H2O_kg_mol / (P.R_J_molK * TK)
    pH2 * 1000 * P.V_an_m3 * P.M_H2_kg_mol / (P.R_J_molK * TK)
    pH2Oan * 1000 * P.V_an_m3 * P.M_H2O_kg_mol / (P.R_J_molK * TK)
    T_C
    ];
end

function dryDp = estimateHumidifierDryDp(P, I, oxygenStoich)
if nargin < 3
    oxygenStoich = P.oxygen_stoich;
end
flowScale = max(I * oxygenStoich / max(P.I_stack_default_A * P.oxygen_stoich, 1.0), 0.2);
scale = flowScale;
dryDp = P.hum_dry_dp_ref_kPa * scale ^ P.hum_dp_exp;
end

function fields = summaryFields()
fields = [
    "I_stack_A"
    "V_cell"
    "P_stack_W"
    "pO2_ca_kPa"
    "pCa_kPa"
    "pH2_an_kPa"
    "pAn_kPa"
    "lambda_mem"
    "T_stack_C"
    "xO2_ca"
    "RH_ca"
    "m_membrane_water_kg_s"
    "mO2_react_kg_s"
    "mH2_react_kg_s"
    "mH2O_prod_kg_s"
    "m_ca_out_kg_s"
    "m_an_out_kg_s"
    "energy_residual_W"
    "pO2_ca_in_kPa"
    "xO2_ca_in"
    "RH_ca_in"
    "Q_net_stack_W"
    "res_O2_ca_kg_s"
    "res_N2_ca_kg_s"
    "res_H2Ov_ca_kg_s"
    "res_H2Ol_ca_kg_s"
    "res_H2_an_kg_s"
    "res_H2Ov_an_kg_s"
    "res_H2Ol_an_kg_s"
    "res_membrane_water_pair_kg_s"
    "max_species_residual_kg_s"
    "Q_gen_W"
    "Q_cool_W"
    "Q_amb_W"
    "Q_gas_W"
    "E_rev_V"
    "eta_act_V"
    "eta_ohm_V"
    "eta_con_V"
    "lambda_O2_actual"
    "m_ca_in_actual_kg_s"
    "i_lim_eff_A_cm2"
    "i0_O2_scale"
    "mH2O_ca_in_kg_s"
    "mH2O_ca_out_kg_s"
    "mH2O_an_in_kg_s"
    "mH2O_an_out_kg_s"
    "m_liquid_diag_kg"
    "m_fresh_in_kg_s"
    "m_egr_return_kg_s"
    "m_vent_out_kg_s"
    "p_wet_out_kPa"
    "r_EGR_actual"
    "mH2O_hum_transfer_kg_s"
    "RH_hum_dry_out"
    "RH_hum_wet_out"
    "dp_bp_valve_kPa"
    "dp_hum_dry_kPa"
    "dp_hum_wet_kPa"
    "m_wet_out_kg_s"
    "m_egr_cmd_kg_s"
    "m_vent_cmd_kg_s"
    "p_vent_out_kPa"
    ];
end

function s = summaryStruct(v, fields)
s = struct();
for k = 1:numel(fields)
    s.(fields(k)) = v(k);
end
end

function v = vectorAt(ts, width, mode)
if mode == "final"
    idx = numSamples(ts, width);
else
    idx = 1;
end
v = vectorAtIndex(ts, width, idx);
end

function v = vectorAtIndex(ts, width, idx)
arr = squeeze(signalData(ts));
if isvector(arr)
    arr = arr(:);
    if numel(arr) == width
        v = arr;
    else
        idx = min(max(idx, 1), floor(numel(arr) / width));
        startIdx = (idx - 1) * width + 1;
        v = arr(startIdx:startIdx + width - 1);
    end
    return;
end
if size(arr, 1) == width
    idx = min(max(idx, 1), size(arr, 2));
    v = arr(:, idx);
elseif size(arr, 2) == width
    idx = min(max(idx, 1), size(arr, 1));
    v = arr(idx, :).';
elseif size(arr, 2) == width + 1
    idx = min(max(idx, 1), size(arr, 1));
    v = arr(idx, 2:end).';
else
    error('CEGR:SignalSizeMismatch', 'Expected width %d, got size [%s].', width, num2str(size(arr)));
end
end

function n = numSamples(ts, width)
arr = squeeze(signalData(ts));
if isvector(arr)
    n = max(floor(numel(arr) / width), 1);
elseif size(arr, 1) == width
    n = size(arr, 2);
elseif size(arr, 2) == width
    n = size(arr, 1);
elseif size(arr, 2) == width + 1
    n = size(arr, 1);
else
    error('CEGR:SignalSizeMismatch', 'Expected width %d, got size [%s].', width, num2str(size(arr)));
end
end

function data = signalData(sig)
if isa(sig, 'timeseries')
    data = sig.Data;
elseif isstruct(sig) && isfield(sig, 'signals') && isfield(sig.signals, 'values')
    data = sig.signals.values;
elseif isstruct(sig) && isfield(sig, 'Data')
    data = sig.Data;
else
    data = sig;
end
end

function steady = steadyCheck(out, stopTime)
fields = summaryFields();
n = numSamples(out.summary_vector, numel(fields));
idxStart = max(1, n - round(30 / max(stopTime / max(n - 1, 1), 0.1)));
vFirst = vectorAtIndex(out.summary_vector, numel(fields), idxStart);
vLast = vectorAtIndex(out.summary_vector, numel(fields), n);
sFirst = summaryStruct(vFirst, fields);
sLast = summaryStruct(vLast, fields);
dryFirst = nodeStruct(vectorAtIndex(out.humidifier_dry_node, 7, idxStart));
dryLast = nodeStruct(vectorAtIndex(out.humidifier_dry_node, 7, n));
steady.dV_cell = abs(sLast.V_cell - sFirst.V_cell);
steady.dT_stack = abs(sLast.T_stack_C - sFirst.T_stack_C);
steady.dRH_ca_in = abs(dryLast.RH - dryFirst.RH);
steady.is_steady = steady.dV_cell < 0.002 && steady.dT_stack < 0.5 && steady.dRH_ca_in < 0.02;
end

function st = nodeStruct(node)
mO2 = max(node(1), 0);
mN2 = max(node(2), 0);
mWv = max(node(3), 0);
mDry = max(mO2 + mN2, 1e-12);
T_C = node(5);
p_kPa = max(node(6), 1e-6);
nO2 = mO2 / 0.031998;
nN2 = mN2 / 0.0280134;
nW = mWv / 0.01801528;
nTot = max(nO2 + nN2 + nW, 1e-12);
st.m_O2_kg_s = mO2;
st.m_N2_kg_s = mN2;
st.m_H2O_v_kg_s = mWv;
st.m_gas_kg_s = max(sum(node(1:3)), 0);
st.T_C = T_C;
st.p_kPa = p_kPa;
st.xO2 = nO2 / nTot;
st.xH2O = nW / nTot;
st.pO2_kPa = st.xO2 * p_kPa;
st.pH2O_kPa = st.xH2O * p_kPa;
st.RH = min(max(st.pH2O_kPa / max(saturationPressureKPa(T_C), 1e-6), 0), 2);
st.omega_g_per_kg = 1000 * mWv / mDry;
end

function omega = omegaFromMoleFractions(xO2, xH2O)
xN2 = max(1 - xO2 - xH2O, 1e-12);
omega = 1000 * xH2O * 0.01801528 ./ max(xO2 * 0.031998 + xN2 * 0.0280134, 1e-12);
end

function omega = omegaFromPressures(pO2, pH2O, pTotal)
pN2 = max(pTotal - pO2 - pH2O, 1e-12);
omega = 1000 * pH2O * 0.01801528 ./ max(pO2 * 0.031998 + pN2 * 0.0280134, 1e-12);
end

function p = saturationPressureKPa(T_C)
p = 0.61078 * exp(17.2694 * T_C / (T_C + 237.29));
end

function value = rmse(x)
value = sqrt(mean(x .^ 2, 'omitnan'));
end

function plotCompare(x, yMeasured, ySim, yLabelText)
plot(x, yMeasured, 'o-', 'LineWidth', 1.4, 'DisplayName', 'bench');
hold on;
plot(x, ySim, 's--', 'LineWidth', 1.4, 'DisplayName', 'simulation');
grid on;
xlabel('Current density (A/cm^2)');
ylabel(yLabelText);
legend('Location', 'best');
end

function [groupVar, groupLabel, titlePrefix, fixedFlowText] = plotContext(T)
condition = "";
if ismember("condition", string(T.Properties.VariableNames)) && height(T) > 0
    condition = string(T.condition(1));
end
if contains(condition, "constant_voltage")
    groupVar = "V_cell_target";
    groupLabel = "V";
    titlePrefix = "Constant Voltage";
    fixedFlowText = "fixed no-EGR supply boundary selected at EGR=0";
elseif contains(condition, "constant_pO2")
    groupVar = "current_density_A_cm2";
    groupLabel = "A/cm2";
    titlePrefix = "Constant pO2";
    fixedFlowText = "compressor flow adjusted to hold cathode-inlet pO2";
else
    groupVar = "current_density_A_cm2";
    groupLabel = "A/cm2";
    titlePrefix = "Constant Current";
    fixedFlowText = "fixed total compressor inlet mass flow";
end
end

function name = figureNameFor(T, kind)
condition = "";
if ismember("condition", string(T.Properties.VariableNames)) && height(T) > 0
    condition = string(T.condition(1));
end
if contains(condition, "constant_voltage")
    idx = 5 + double(kind == "Diagnostics");
    label = "Constant Voltage";
elseif contains(condition, "constant_pO2")
    idx = 7 + double(kind == "Diagnostics");
    label = "Constant pO2";
else
    idx = 3 + double(kind == "Diagnostics");
    label = "Constant Current";
end
name = sprintf('CEGR %02d %s %s', idx, label, kind);
end

function plotByGroup(T, groupVar, groupLabel, metric, yLabelText)
if ismember("scan_usable", string(T.Properties.VariableNames))
    T = T(logical(T.scan_usable), :);
end
groups = unique(T.(groupVar));
colors = lines(numel(groups));
hold on;
for k = 1:numel(groups)
    d = groups(k);
    mask = T.(groupVar) == d;
    D = sortrows(T(mask, :), "egr_ratio_cmd");
    plot(D.egr_ratio_cmd, D.(metric), '-o', 'LineWidth', 1.4, 'Color', colors(k,:), ...
        'DisplayName', groupLegend(d, groupLabel));
    warn = logical(D.oxygen_warning) | logical(D.severe_oxygen_starvation);
    if any(warn)
        plot(D.egr_ratio_cmd(warn), D.(metric)(warn), 'x', 'LineWidth', 1.6, ...
            'MarkerSize', 8, 'Color', colors(k,:), 'HandleVisibility', 'off');
    end
end
grid on;
xlabel('EGR ratio (-)');
ylabel(yLabelText);
legend('Location', 'best');
end

function plotPressureChain(T, groupVar, groupLabel)
groups = unique(T.(groupVar));
colors = lines(numel(groups));
hold on;
for k = 1:numel(groups)
    d = groups(k);
    D = sortrows(T(T.(groupVar) == d, :), "egr_ratio_cmd");
    plot(D.egr_ratio_cmd, D.p_ca_in_sim_kPa, '-', 'LineWidth', 1.3, 'Color', colors(k,:), ...
        'DisplayName', "in " + groupLegend(d, groupLabel));
    plot(D.egr_ratio_cmd, D.p_stack_internal_kPa, '--', 'LineWidth', 1.3, 'Color', colors(k,:), ...
        'DisplayName', "stack " + groupLegend(d, groupLabel));
    plot(D.egr_ratio_cmd, D.p_ca_out_boundary_kPa, ':', 'LineWidth', 1.6, 'Color', colors(k,:), ...
        'DisplayName', "out " + groupLegend(d, groupLabel));
end
grid on;
xlabel('EGR ratio (-)');
legend('Location', 'best');
end

function plotMultiByGroup(T, groupVar, groupLabel, metrics, labels)
colors = lines(numel(metrics));
D = sortrows(T, [groupVar,"egr_ratio_cmd"]);
hold on;
for m = 1:numel(metrics)
    for d = unique(D.(groupVar)).'
        mask = D.(groupVar) == d;
        plot(D.egr_ratio_cmd(mask), D.(metrics(m))(mask), '-', 'LineWidth', 1.2, ...
            'Color', colors(m,:), 'DisplayName', labels(m) + " " + groupLegend(d, groupLabel));
    end
end
grid on;
xlabel('EGR ratio (-)');
legend('Location', 'best');
end

function semilogyByGroup(T, groupVar, groupLabel, metric, yLabelText)
groups = unique(T.(groupVar));
colors = lines(numel(groups));
hold on;
for k = 1:numel(groups)
    D = sortrows(T(T.(groupVar) == groups(k), :), "egr_ratio_cmd");
    semilogy(D.egr_ratio_cmd, max(abs(D.(metric)), 1e-14), '-o', 'LineWidth', 1.3, ...
        'Color', colors(k,:), 'DisplayName', groupLegend(groups(k), groupLabel));
end
grid on;
xlabel('EGR ratio (-)');
ylabel(yLabelText);
legend('Location', 'best');
end

function plotStatusMap(T, groupVar, groupLabel)
statusNames = ["normal","oxygen_warning","severe_oxygen_starvation","pressure_order_failed","not_steady"];
groups = unique(T.(groupVar));
colors = lines(numel(groups));
hold on;
for k = 1:numel(groups)
    D = sortrows(T(T.(groupVar) == groups(k), :), "egr_ratio_cmd");
    y = zeros(height(D), 1);
    for i = 1:height(D)
        y(i) = find(statusNames == string(D.interpretation_status(i)), 1);
    end
    plot(D.egr_ratio_cmd, y, '-o', 'LineWidth', 1.3, 'Color', colors(k,:), ...
        'DisplayName', groupLegend(groups(k), groupLabel));
end
yticks(1:numel(statusNames));
yticklabels(statusNames);
grid on;
xlabel('EGR ratio (-)');
legend('Location', 'best');
end

function textOut = groupLegend(value, groupLabel)
if groupLabel == "V"
    textOut = sprintf('%.3f V', value);
elseif groupLabel == "A/cm2"
    textOut = sprintf('%.1f A/cm2', value);
else
    textOut = sprintf('%.3g %s', value, groupLabel);
end
end

function drawPanel(ax, pos, labelText, faceColor, edgeColor)
if nargin < 4
    faceColor = [0.985 0.988 0.992];
end
if nargin < 5
    edgeColor = [0.70 0.74 0.78];
end
rectangle(ax, 'Position', pos, 'Curvature', 0.025, 'FaceColor', faceColor, ...
    'EdgeColor', edgeColor, 'LineWidth', 0.9);
text(ax, pos(1) + 0.012, pos(2) + pos(4) - 0.028, labelText, 'FontWeight', 'bold', ...
    'FontSize', 9, 'Color', edgeColor, 'Interpreter', 'none');
end

function h = drawBox(ax, pos, titleText, bodyText, edgeColor, faceColor)
if nargin < 5
    edgeColor = [0.20 0.27 0.35];
end
if nargin < 6
    faceColor = [0.96 0.97 0.98];
end
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
if nargin < 4
    color = [0.15 0.20 0.25];
end
if nargin < 5
    lineWidth = 1.2;
end
if nargin < 6
    lineStyle = '-';
end
quiver(ax, p1(1), p1(2), p2(1) - p1(1), p2(2) - p1(2), 0, ...
    'MaxHeadSize', 0.28, 'Color', color, 'LineWidth', lineWidth, 'LineStyle', lineStyle);
end

function drawPolylineArrow(ax, points, color, lineWidth, lineStyle)
if size(points, 1) < 2
    return;
end
for k = 1:size(points, 1)-2
    plot(ax, points(k:k+1,1), points(k:k+1,2), 'Color', color, 'LineWidth', lineWidth, 'LineStyle', lineStyle);
end
drawArrow(ax, points(end-1,:), points(end,:), color, lineWidth, lineStyle);
end
