function audit = run_core_fix_v01_audit(stopTime_s)
%RUN_CORE_FIX_V01_AUDIT Replay all unified cases after core-fix v01 changes.

if nargin < 1 || isempty(stopTime_s)
    stopTime_s = 120;
end

rootDir = fileparts(fileparts(mfilename('fullpath')));
modelDir = fullfile(rootDir, '01_模型');
resultDir = fullfile(rootDir, '04_验证结果');
if ~isfolder(resultDir)
    mkdir(resultDir);
end
addpath(modelDir);

P0 = init_testbench_10kw_simplified_egr(1, 'all', false);
cases = P0.allCaseTable;
model = P0.modelName;
load_system(model);

varNames = auditVariableNames();
varTypes = repmat("double", 1, numel(varNames));
textVars = ["case_id", "source_dataset", "status", "message"];
for k = 1:numel(textVars)
    varTypes(varNames == textVars(k)) = "string";
end
audit = table('Size', [height(cases), numel(varNames)], ...
    'VariableTypes', cellstr(varTypes), 'VariableNames', cellstr(varNames));

for k = 1:height(cases)
    P = init_testbench_10kw_simplified_egr(k, 'all', false);
    audit.case_id(k) = string(P.case_id);
    audit.source_dataset(k) = string(P.source_dataset);
    audit.current_A(k) = P.I_stack_default_A;
    audit.current_density_A_cm2(k) = P.current_density_A_cm2;
    audit.egr_fraction(k) = P.egr_fraction_cmd;
    audit.V_exp(k) = P.cell_voltage_bench_V;
    audit.stack_in_flow_SLPM(k) = P.stack_in_flow_SLPM;
    audit.fresh_supply_flow_SLPM(k) = P.fresh_supply_flow_SLPM;
    audit.stack_in_p_kPa_g(k) = P.bench_stack_in_p_kPa;
    audit.stack_out_p_kPa_g(k) = P.stack_out_p_kPa;
    audit.cathode_dp_kPa(k) = P.cathode_dp_kPa;
    audit.stack_in_T_C(k) = P.bench_stack_in_T_C;
    audit.stack_in_RH(k) = P.bench_stack_in_RH;
    try
        out = simulateCase(P, stopTime_s, model);
        s = lastSummary(out);
        audit.status(k) = "ok";
        audit.V_sim(k) = s(2);
        audit.err_V(k) = s(2) - P.cell_voltage_bench_V;
        audit.pO2_stack_kPa(k) = s(4);
        audit.pCa_stack_kPa_abs(k) = s(5);
        audit.pCa_out_boundary_kPa_abs(k) = P.p_cathode_back_kPa;
        audit.pH2_stack_kPa(k) = s(6);
        audit.pAn_stack_kPa_abs(k) = s(7);
        audit.T_stack_C(k) = s(9);
        audit.xO2_stack(k) = s(10);
        audit.RH_stack(k) = s(11);
        audit.pO2_in_kPa(k) = s(19);
        audit.xO2_in(k) = s(20);
        audit.RH_in(k) = s(21);
        audit.lambda_m(k) = s(8);
        audit.lambda_ca(k) = s(49);
        audit.lambda_an(k) = s(50);
        audit.mMem_kg_s(k) = s(12);
        audit.N_drag_mol_s(k) = s(51);
        audit.N_diff_mol_s(k) = s(52);
        audit.J_drag_mol_m2_s(k) = s(59);
        audit.J_diff_mol_m2_s(k) = s(60);
        audit.J_net_mol_m2_s(k) = s(61);
        audit.mDrag_kg_s(k) = s(62);
        audit.mDiff_kg_s(k) = s(63);
        audit.mMem_raw_kg_s(k) = s(64);
        audit.mMem_limit_delta_kg_s(k) = s(65);
        audit.mCaOut_kg_s(k) = s(16);
        audit.mIn_kg_s(k) = s(41);
        audit.lambdaO2(k) = s(40);
        audit.phaseCa_kg_s(k) = s(26);
        audit.phaseAn_kg_s(k) = s(29);
        audit.condensedCa_kg(k) = s(57);
        audit.condensedAn_kg(k) = s(58);
        audit.psatCa_next_kPa(k) = s(53);
        audit.psatAn_next_kPa(k) = s(54);
        audit.mV_ca_preclip_kg(k) = s(55);
        audit.mV_an_preclip_kg(k) = s(56);
        audit.resO2_kg_s(k) = s(23);
        audit.resN2_kg_s(k) = s(24);
        audit.resH2Oca_kg_s(k) = s(25);
        audit.resH2_kg_s(k) = s(27);
        audit.resH2Oan_kg_s(k) = s(28);
        audit.maxGasRes_kg_s(k) = s(31);
        audit.Qnet_W(k) = s(22);
        audit.Qgen_W(k) = s(32);
        audit.Qcool_W(k) = s(33);
        audit.Qamb_W(k) = s(34);
        audit.Qgas_W(k) = s(35);
        audit.E_Nernst_V(k) = s(36);
        audit.etaAct_V(k) = s(37);
        audit.etaOhm_V(k) = s(38);
        audit.etaCon_V(k) = s(39);
        audit.message(k) = "";
    catch ME
        audit.status(k) = "error";
        audit.message(k) = string(ME.identifier + ": " + ME.message);
    end
end

auditFile = fullfile(resultDir, 'core_fix_v01_audit.csv');
summaryFile = fullfile(resultDir, 'core_fix_v01_summary.md');
writetable(audit, auditFile);
writeSummary(summaryFile, audit, stopTime_s);
fprintf('Wrote %s\n', auditFile);
fprintf('Wrote %s\n', summaryFile);
end

function out = simulateCase(P, stopTime_s, model)
in = Simulink.SimulationInput(model);
in = in.setModelParameter('StopTime', num2str(stopTime_s), ...
    'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', num2str(P.dt_s));
in = in.setVariable('BenchBoundaryParam_simplified', P.BenchBoundaryParam);
in = in.setVariable('EgrSplitParam_simplified', P.EgrSplitParam);
in = in.setVariable('StackParam_simplified', P.StackParam);
in = in.setVariable('I_stack_cmd_A_simplified', P.I_stack_default_A);
in = in.setVariable('StackInitialState_simplified', P.stack_initial_state);
in = in.setVariable('EGRInitialNode_simplified', P.egr_initial_node);
out = sim(in);
end

function s = lastSummary(out)
v = out.summary_vector.signals.values;
s = squeeze(v(:, 1, end));
end

function names = auditVariableNames()
names = ["case_id", "source_dataset", "status", "message", ...
    "current_A", "current_density_A_cm2", "egr_fraction", "V_exp", "V_sim", "err_V", ...
    "stack_in_flow_SLPM", "fresh_supply_flow_SLPM", "stack_in_p_kPa_g", ...
    "stack_out_p_kPa_g", "cathode_dp_kPa", "stack_in_T_C", "stack_in_RH", ...
    "pO2_stack_kPa", "pCa_stack_kPa_abs", "pCa_out_boundary_kPa_abs", ...
    "pH2_stack_kPa", "pAn_stack_kPa_abs", "T_stack_C", "xO2_stack", ...
    "RH_stack", "pO2_in_kPa", "xO2_in", "RH_in", "lambda_m", ...
    "lambda_ca", "lambda_an", "mMem_kg_s", "N_drag_mol_s", "N_diff_mol_s", ...
    "J_drag_mol_m2_s", "J_diff_mol_m2_s", "J_net_mol_m2_s", ...
    "mDrag_kg_s", "mDiff_kg_s", "mMem_raw_kg_s", "mMem_limit_delta_kg_s", ...
    "mCaOut_kg_s", "mIn_kg_s", "lambdaO2", "phaseCa_kg_s", "phaseAn_kg_s", ...
    "condensedCa_kg", "condensedAn_kg", "psatCa_next_kPa", "psatAn_next_kPa", ...
    "mV_ca_preclip_kg", "mV_an_preclip_kg", "resO2_kg_s", "resN2_kg_s", ...
    "resH2Oca_kg_s", "resH2_kg_s", "resH2Oan_kg_s", "maxGasRes_kg_s", ...
    "Qnet_W", "Qgen_W", "Qcool_W", "Qamb_W", "Qgas_W", ...
    "E_Nernst_V", "etaAct_V", "etaOhm_V", "etaCon_V"];
end

function writeSummary(path, audit, stopTime_s)
ok = audit(audit.status == "ok", :);
fid = fopen(path, 'w', 'n', 'UTF-8');
cleanup = onCleanup(@() fclose(fid));
fprintf(fid, '# Core Fix v01 Audit Summary\n\n');
fprintf(fid, '- Stop time: %.3g s\n', stopTime_s);
fprintf(fid, '- Total cases: %d\n', height(audit));
fprintf(fid, '- Successful cases: %d\n', height(ok));
fprintf(fid, '- Failed cases: %d\n\n', height(audit) - height(ok));
if ~isempty(ok)
    fprintf(fid, '## Key Metrics\n\n');
    fprintf(fid, '- Voltage RMSE, all successful cases: %.6f V\n', rmsLocal(ok.err_V));
    fprintf(fid, '- Max absolute voltage error: %.6f V\n', max(abs(ok.err_V)));
    fprintf(fid, '- Initial no-EGR cathode dp range in data: %.3f to %.3f kPa\n', ...
        min(ok.cathode_dp_kPa(ok.source_dataset == "initial_noegr_steady_xlsx")), ...
        max(ok.cathode_dp_kPa(ok.source_dataset == "initial_noegr_steady_xlsx")));
    fprintf(fid, '- Max gas residual: %.6g kg/s\n', max(ok.maxGasRes_kg_s));
    fprintf(fid, '- Max cathode condensation diagnostic: %.6g kg\n', max(ok.condensedCa_kg));
    fprintf(fid, '- EGR voltage penalty terms are frozen outside the core equation in this pass.\n\n');
end
if any(audit.status == "error")
    fprintf(fid, '## Failed Cases\n\n');
    bad = audit(audit.status == "error", :);
    for k = 1:height(bad)
        fprintf(fid, '- `%s`: %s\n', bad.case_id(k), bad.message(k));
    end
end
end

function r = rmsLocal(x)
x = x(isfinite(x));
if isempty(x)
    r = NaN;
else
    r = sqrt(mean(x.^2));
end
end
