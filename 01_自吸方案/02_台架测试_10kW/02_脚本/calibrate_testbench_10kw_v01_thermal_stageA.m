function results = calibrate_testbench_10kw_v01_thermal_stageA()
%CALIBRATE_TESTBENCH_10KW_V01_THERMAL_STAGEA Fit bench cooling curve.
%
% The bench thermal route uses the existing PEMFCStackCore lumped thermal
% model and derives a bench-specific coolant-flow to h_cool_eff curve from
% the 13 no-EGR steady bench points. The fit is intentionally offline:
% Q_cool comes from coolant flow and temperature rise, while T_stack is
% inferred from the accepted first-pass relation T_ca_out = T_stack + 3 C.

P0 = init_testbench_10kw_v01(1, 0.0, false);
if ~exist(P0.resultDir, 'dir')
    mkdir(P0.resultDir);
end
paramDir = fullfile(P0.rootDir, '00_输入参数', '标定参数');
if ~exist(paramDir, 'dir')
    mkdir(paramDir);
end

diagFile = fullfile(P0.resultDir, 'testbench_thermal_stageA_diagnostic.csv');
curveFile = fullfile(paramDir, 'testbench_thermal_stageA_cooling_flow_curve.csv');
paramFile = fullfile(paramDir, 'testbench_thermal_stageA_params.csv');
summaryFile = fullfile(P0.resultDir, 'testbench_thermal_stageA_summary.md');

rawRows = cell(13, 1);
for caseIndex = 1:13
    P = init_testbench_10kw_v01(caseIndex, 0.0, false);
    rawRows{caseIndex} = struct2table(extractThermalRow(P));
end
diag = vertcat(rawRows{:});

curve = buildCoolingCurve(diag);
paramTable = buildParamTable(P0, curve);

writetable(diag, diagFile);
writetable(curve, curveFile);
writetable(paramTable, paramFile);
writeSummary(summaryFile, diag, curve, P0);

results = struct();
results.diagnostic = diag;
results.cooling_curve = curve;
results.parameters = paramTable;

fprintf('Wrote bench thermal diagnostic: %s\n', diagFile);
fprintf('Wrote bench thermal cooling curve: %s\n', curveFile);
fprintf('Wrote bench thermal parameters: %s\n', paramFile);
end

function row = extractThermalRow(P)
qSigned = P.coolant_rho_kg_L * P.coolant_cp_J_kgK * ...
    (P.coolant_flow_L_min / 60.0) * (P.coolant_out_C - P.T_cool_C);
qFit = abs(qSigned);
TStackFit = P.separator_T_C - 3.0;
driveRaw = TStackFit - P.T_cool_C;
drive = max(driveRaw, 0.1);
hBench = qFit / drive;
hPrior = effectiveCoolingCoefficient(P, P.coolant_flow_L_min);
qPrior = hPrior * max(TStackFit - P.T_cool_C, 0);
qGenBench = P.I_stack_default_A * P.N_cell * ...
    (P.thermoneutralVoltage_V - P.cell_voltage_bench_V);

row = struct();
row.case_id = string(P.case_id);
row.case_index = P.caseIndex;
row.current_A = P.I_stack_default_A;
row.current_density_A_cm2 = P.current_density_A_cm2;
row.coolant_flow_L_min = P.coolant_flow_L_min;
row.coolant_inlet_temp_C = P.T_cool_C;
row.coolant_outlet_temp_C = P.coolant_out_C;
row.coolant_deltaT_C = P.coolant_deltaT_C;
row.Q_cool_bench_signed_W = qSigned;
row.Q_cool_bench_fit_W = qFit;
row.T_stack_fit_C = TStackFit;
row.T_cool_drive_C = driveRaw;
row.T_ca_out_relation_C = TStackFit + 3.0;
row.T_ca_out_bench_C = P.separator_T_C;
row.T_ca_out_relation_err_C = row.T_ca_out_relation_C - P.separator_T_C;
row.Q_gen_bench_W = qGenBench;
row.Q_cool_prior_W = qPrior;
row.Q_cool_prior_err_W = qPrior - qFit;
row.h_cool_prior_W_K = hPrior;
row.h_cool_bench_fit_W_K = hBench;
row.h_cool_fit_valid = qFit > 0 && driveRaw >= 2.5;
row.V_cell_bench = P.cell_voltage_bench_V;
row.model_name = string(P.modelName);
end

function h = effectiveCoolingCoefficient(P, flow)
h = P.h_cool_W_K;
if P.cool_flow_curve_enabled <= 0.5
    return;
end
bp = P.cool_flow_curve_L_min(:);
hv = P.cool_flow_curve_h_W_K(:);
valid = bp > 0 & hv > 0 & isfinite(bp) & isfinite(hv);
bp = bp(valid);
hv = hv(valid);
if numel(bp) < 2
    return;
end
h = interp1(bp, hv, flow, 'linear', 'extrap');
h = min(max(h, min(hv)), max(hv));
end

function curve = buildCoolingCurve(diag)
valid = logical(diag.h_cool_fit_valid);
flows = double(diag.coolant_flow_L_min(valid));
hVals = double(diag.h_cool_bench_fit_W_K(valid));
[uFlow, ~, groupIdx] = unique(flows);
hCurve = zeros(size(uFlow));
for k = 1:numel(uFlow)
    hCurve(k) = median(hVals(groupIdx == k), 'omitnan');
end
for k = 2:numel(hCurve)
    hCurve(k) = max(hCurve(k), hCurve(k - 1));
end
curve = table(uFlow, hCurve, 'VariableNames', {'coolant_flow_L_min', 'h_cool_curve_W_K'});
end

function T = buildParamTable(P0, curve)
rows = {
    "h_cool_W_K", curve.h_cool_curve_W_K(1), P0.h_cool_W_K, "bench fallback cooling coefficient from no-EGR coolant heat balance"
    "h_amb_W_K", P0.h_amb_W_K, P0.h_amb_W_K, "ambient heat-loss coefficient kept from current baseline"
    "C_stack_J_K", P0.C_stack_J_K, P0.C_stack_J_K, "thermal capacitance kept frozen in bench stage A"
    "coolant_rho_kg_L", P0.coolant_rho_kg_L, P0.coolant_rho_kg_L, "water-equivalent coolant density"
    "coolant_cp_J_kgK", P0.coolant_cp_J_kgK, P0.coolant_cp_J_kgK, "water-equivalent coolant heat capacity"
    };
T = cell2table(rows, 'VariableNames', {'parameter', 'value', 'initial_value', 'note'});
end

function writeSummary(path, diag, curve, P0)
qErr = diag.Q_cool_prior_err_W;
lines = [
    "# Testbench Thermal Stage-A Summary"
    ""
    "Date: " + string(datetime('now', 'Format', 'yyyy-MM-dd'))
    ""
    "## Scope"
    ""
    "- Executable model: `01_模型/CEGR_TestBench_10kW_v01.slx`."
    "- Uses the existing `PEMFCStackCore` lumped thermal model."
    "- Fits a bench-specific `coolant_flow_L_min -> h_cool_eff` curve from 13 no-EGR steady points."
    "- Coolant heat target uses `abs(rho * cp * flow * (T_cool_out - T_cool_in))`; the signed heat is retained in diagnostics."
    "- Stack temperature is inferred from the current engineering relation `T_ca_out = T_stack + 3 C`."
    "- Curve support excludes points with `T_stack_fit - T_cool_in < 2.5 C`; those points are retained only as diagnostics because small thermal drive amplifies h_cool noise."
    ""
    "## Metrics Before Applying Bench Curve"
    ""
    sprintf("- Prior Q_cool RMSE vs bench coolant heat: %.1f W.", rmsLocal(qErr))
    sprintf("- Prior Q_cool bias vs bench coolant heat: %.1f W.", mean(qErr, 'omitnan'))
    sprintf("- T_ca_out relation residual by construction: %.2f C.", rmsLocal(diag.T_ca_out_relation_err_C))
    sprintf("- Flow support count: %d.", height(curve))
    ""
    "## Accepted Parameters"
    ""
    sprintf("- Fallback h_cool_W_K: %.3f W/K.", curve.h_cool_curve_W_K(1))
    sprintf("- h_amb_W_K retained: %.3f W/K.", P0.h_amb_W_K)
    sprintf("- C_stack_J_K retained: %.3f J/K.", P0.C_stack_J_K)
    ""
    "## Output Files"
    ""
    "- `04_验证结果/testbench_thermal_stageA_diagnostic.csv`"
    "- `04_验证结果/testbench_thermal_stageA_summary.md`"
    "- `00_输入参数/标定参数/testbench_thermal_stageA_params.csv`"
    "- `00_输入参数/标定参数/testbench_thermal_stageA_cooling_flow_curve.csv`"
    ""
    "## Notes"
    ""
    "- Low-load coolant deltaT may be negative in the source data. Stage A uses heat-removal magnitude for the curve and keeps the signed value visible for review."
    "- This is a cooling-side calibration only. It does not claim the cathode outlet gas temperature relation is physically final."
    ];
writeText(path, lines);
end

function y = rmsLocal(x)
x = x(isfinite(x));
if isempty(x)
    y = NaN;
else
    y = sqrt(mean(x .^ 2));
end
end

function writeText(path, lines)
fid = fopen(path, 'w');
if fid < 0
    error('Failed to open %s for writing.', path);
end
cleaner = onCleanup(@() fclose(fid));
for k = 1:numel(lines)
    fprintf(fid, '%s\n', lines(k));
end
end
