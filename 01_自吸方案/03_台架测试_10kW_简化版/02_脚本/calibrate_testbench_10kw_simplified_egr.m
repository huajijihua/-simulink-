function result = calibrate_testbench_10kw_simplified_egr()
%CALIBRATE_TESTBENCH_10KW_SIMPLIFIED_EGR Refit simplified bench EGR model.
%
% Stage 1 fits the no-EGR polarization curve on the same voltage equation
% used in PEMFCStackCore, then validates with Simulink. Stage 2 keeps the
% no-EGR stack fit fixed and fits an EGR-only empirical mass-transfer loss.

rootDir = fileparts(fileparts(mfilename('fullpath')));
paramDir = fullfile(rootDir, '00_输入参数', '标定参数');
if ~isfolder(paramDir)
    mkdir(paramDir);
end

stackFile = fullfile(paramDir, 'simplified_noegr_stack_params.csv');
egrFile = fullfile(paramDir, 'simplified_egr_boundary_params.csv');
if isfile(stackFile), delete(stackFile); end
if isfile(egrFile), delete(egrFile); end

P0 = init_testbench_10kw_simplified_egr(1, 'noegr', false);
noEgr = P0.noEgrTable;
egr = P0.egrTable;
egrTrain = egr(isfinite(egr.cell_voltage_V), :);

fprintf('Stage 1: no-EGR voltage-equation fit using %d points.\n', height(noEgr));
baseNoEgr = evaluateNoEgr(noEgr);
stackFit = fitNoEgrVoltageEquation(baseNoEgr, P0);
writeStackParams(stackFile, stackFit.spec, stackFit.values);
writeEgrParams(egrFile, egrBoundaryDefaultSpec(), egrBoundaryDefaultSpec().default);
fitNoEgr = evaluateNoEgr(noEgr);
fprintf('Stage 1 done: RMSE %.5f V, max abs %.5f V.\n', ...
    rmse(fitNoEgr.err_V), max(abs(fitNoEgr.err_V)));

fprintf('Stage 2: EGR loss fit using %d finite voltage points.\n', height(egrTrain));
baseEgr = evaluateEgr(egrTrain);
egrLossFit = fitEgrLoss(baseEgr);
finalSpec = appendEgrLossSpec(stackFit.spec);
finalValues = [stackFit.values(:); egrLossFit.values(:)];
writeStackParams(stackFile, finalSpec, finalValues);
fitEgr = evaluateEgr(egrTrain);
fprintf('Stage 2 done: RMSE %.5f V, max abs %.5f V.\n', ...
    rmse(fitEgr.err_V), max(abs(fitEgr.err_V)));

fprintf('FINAL_NOEGR_RMSE=%.6f\n', rmse(fitNoEgr.err_V));
fprintf('FINAL_EGR_RMSE=%.6f\n', rmse(fitEgr.err_V));
fprintf('NOEGR_MAX_ABS=%.6f\n', max(abs(fitNoEgr.err_V)));
fprintf('EGR_MAX_ABS=%.6f\n', max(abs(fitEgr.err_V)));

plotCalibration(fitNoEgr, fitEgr);

result = struct();
result.noegr = fitNoEgr;
result.egr = fitEgr;
result.stack_params = table(finalSpec.names(:), finalSpec.stackIndex(:), finalValues(:), ...
    'VariableNames', {'parameter', 'stack_index', 'value'});
result.egr_boundary_params = readtable(egrFile, 'TextType', 'string');
end

function spec = baseVoltageSpec(P)
names = ["book_theta1"; "book_theta3"; "book_theta4"; "book_theta8"; "book_theta9"; "book_theta10"];
idx = [24; 26; 27; 29; 30; 31];
default = P.StackParam(idx);
lower = [-0.40; -1.20e-3; 0.0; 0.0; 0.0; 0.0];
upper = [0.80;  2.00e-4; 8.0e-4; 5.0e-3; 0.35; 2.5e-2];
default = min(max(default, lower), upper);
spec = struct('names', names, 'stackIndex', idx, ...
    'default', default, 'lower', lower, 'upper', upper);
end

function spec = appendEgrLossSpec(baseSpec)
extra = struct();
extra.names = ["egr_loss_k_V"; "egr_loss_exp"; "egr_loss_rh_V"];
extra.stackIndex = [76; 77; 78];
spec = struct();
spec.names = [baseSpec.names(:); extra.names(:)];
spec.stackIndex = [baseSpec.stackIndex(:); extra.stackIndex(:)];
end

function spec = egrBoundaryDefaultSpec()
names = ["egr_fraction_scale"; "egr_fraction_bias"; "separator_T_offset_C"; ...
    "separator_p_offset_kPa"; "stack_in_flow_scale"; "fresh_supply_flow_scale"];
default = [1.0; 0.0; 0.0; 0.0; 1.0; 1.0];
spec = struct('names', names, 'default', default);
end

function fit = fitNoEgrVoltageEquation(simFit, P)
spec = baseVoltageSpec(P);
I = simFit.current_A;
TK = simFit.T_stack_C + 273.15;
E = simFit.E_Nernst_V;
CO2 = max(simFit.i0Scale, 1e-12);
etaOhmNoTheta8 = simFit.etaOhm_V - I .* P.StackParam(29);
Vexp = simFit.V_exp;
th2 = P.StackParam(25);

    function V = predict(theta)
        theta = min(max(theta(:), spec.lower), spec.upper);
        etaAct = max(theta(1) + th2 .* TK + theta(2) .* TK .* log(CO2) + ...
            theta(3) .* TK .* log(max(I, 1e-6)), 0);
        etaOhm = etaOhmNoTheta8 + I .* theta(4);
        etaCon = max(theta(5) .* exp(min(theta(6) .* I, 50)), 0);
        V = E - etaAct - etaOhm - etaCon;
    end

    function f = objective(z)
        theta = boundedFromUnit(z, spec.lower, spec.upper);
        err = predict(theta) - Vexp;
        f = mean(err.^2) + 5e-4 * theta(6)^2;
    end

z0 = unitFromBounded(spec.default, spec.lower, spec.upper);
opts = optimset('Display', 'off', 'MaxIter', 3000, 'MaxFunEvals', 12000, ...
    'TolX', 1e-10, 'TolFun', 1e-12);
z = fminsearch(@objective, z0, opts);
values = boundedFromUnit(z, spec.lower, spec.upper);
fit = struct('spec', spec, 'values', values);
fprintf('Stage 1 analytic RMSE %.5f V before Simulink replay.\n', ...
    rmse(predict(values) - Vexp));
end

function fit = fitEgrLoss(simFit)
lossNeeded = simFit.V_sim - simFit.V_exp;
fEgr = max(simFit.egr_fraction_used, 0);
rhExcess = max(simFit.RHIn - 0.8, 0) .* fEgr;
X = [fEgr, rhExcess];
valid = all(isfinite(X), 2) & isfinite(lossNeeded) & lossNeeded > -0.03;
if nnz(valid) < 2 || max(fEgr(valid)) <= 0
    k = [0; 0];
else
    y = max(lossNeeded(valid), 0);
    Xv = X(valid, :);
    k = (Xv' * Xv + 1e-8 * eye(2)) \ (Xv' * y);
    k = max(k, 0);
end
fit.values = [min(k(1), 0.60); 1.0; min(k(2), 0.60)];
fprintf('Stage 2 fitted egr_loss_k_V %.5f, egr_loss_exp %.3f, egr_loss_rh_V %.5f.\n', ...
    fit.values(1), fit.values(2), fit.values(3));
end

function fit = evaluateNoEgr(data)
n = height(data);
fit = table('Size', [n 17], 'VariableTypes', repmat("double", 1, 17), ...
    'VariableNames', {'case_index','current_A','egr_fraction','V_exp','V_sim','err_V', ...
    'xO2In','RHIn','lambdaO2','pCa_kPa','T_stack_C','E_Nernst_V','etaAct_V', ...
    'etaOhm_V','etaCon_V','i0Scale','max_gas_residual'});
for k = 1:n
    P = init_testbench_10kw_simplified_egr(data.case_index(k), 'noegr', false);
    out = simulateCase(P);
    s = lastVector(out.get('summary_vector'));
    fit.case_index(k) = data.case_index(k);
    fit.current_A(k) = P.I_stack_default_A;
    fit.egr_fraction(k) = P.egr_fraction_cmd;
    fit = fillCommonFit(fit, k, s, P);
end
assert(any(abs(fit.V_exp) > 0) && any(abs(fit.V_sim) > 0), ...
    'CEGR:SimplifiedCalibration:InvalidNoEgrFit', 'No-EGR fit table was not populated.');
end

function fit = evaluateEgr(data)
n = height(data);
fit = table('Size', [n 19], 'VariableTypes', repmat("double", 1, 19), ...
    'VariableNames', {'case_index','current_A','egr_fraction_raw','egr_fraction_used','V_exp','V_sim','err_V', ...
    'xO2In','RHIn','lambdaO2','mIn_kg_s','mEgr_kg_s','mBenchOut_kg_s','sepDrain_kg_s', ...
    'E_Nernst_V','etaAct_V','etaOhm_V','etaCon_V','max_gas_residual'});
for k = 1:n
    P = init_testbench_10kw_simplified_egr(data.case_index(k), 'egr', false);
    out = simulateCase(P);
    s = lastVector(out.get('summary_vector'));
    fit.case_index(k) = data.case_index(k);
    fit.current_A(k) = P.I_stack_default_A;
    fit.egr_fraction_raw(k) = P.egr_fraction_cmd_raw;
    fit.egr_fraction_used(k) = P.egr_fraction_cmd;
    fit = fillCommonFit(fit, k, s, P);
    fit.mIn_kg_s(k) = s(50);
    fit.mEgr_kg_s(k) = s(51);
    fit.mBenchOut_kg_s(k) = s(52);
    fit.sepDrain_kg_s(k) = s(62);
end
assert(any(abs(fit.V_exp) > 0) && any(abs(fit.V_sim) > 0), ...
    'CEGR:SimplifiedCalibration:InvalidEgrFit', 'EGR fit table was not populated.');
end

function fit = fillCommonFit(fit, k, s, P)
fit.V_exp(k) = P.cell_voltage_bench_V;
fit.V_sim(k) = s(2);
fit.err_V(k) = s(2) - P.cell_voltage_bench_V;
fit.xO2In(k) = s(49);
fit.RHIn(k) = s(21);
fit.lambdaO2(k) = s(40);
fit.E_Nernst_V(k) = s(36);
fit.etaAct_V(k) = s(37);
fit.etaOhm_V(k) = s(38);
fit.etaCon_V(k) = s(39);
fit.max_gas_residual(k) = s(31);
if ismember('pCa_kPa', fit.Properties.VariableNames)
    fit.pCa_kPa(k) = s(5);
    fit.T_stack_C(k) = s(9);
    fit.i0Scale(k) = s(43);
end
end

function out = simulateCase(P)
in = Simulink.SimulationInput(P.modelName);
in = in.setModelParameter('StopTime', num2str(P.stopTime_s), ...
    'SolverType', 'Fixed-step', 'Solver', 'ode4', 'FixedStep', num2str(P.dt_s));
in = in.setVariable('BenchBoundaryParam_simplified', P.BenchBoundaryParam);
in = in.setVariable('EgrSplitParam_simplified', P.EgrSplitParam);
in = in.setVariable('StackParam_simplified', P.StackParam);
in = in.setVariable('I_stack_cmd_A_simplified', P.I_stack_default_A);
in = in.setVariable('StackInitialState_simplified', P.stack_initial_state);
in = in.setVariable('EGRInitialNode_simplified', P.egr_initial_node);
out = sim(in);
end

function z = unitFromBounded(x, lb, ub)
x = min(max(x(:), lb(:) + 1e-12), ub(:) - 1e-12);
r = (x - lb(:)) ./ max(ub(:) - lb(:), 1e-12);
z = log(r ./ max(1 - r, 1e-12));
end

function x = boundedFromUnit(z, lb, ub)
r = 1 ./ (1 + exp(-z(:)));
x = lb(:) + r .* (ub(:) - lb(:));
end

function v = lastVector(ts)
v = ts.signals.values(:, :, end);
v = v(:);
end

function writeStackParams(filePath, spec, values)
folder = fileparts(filePath);
if ~isfolder(folder), mkdir(folder); end
T = table(spec.names(:), spec.stackIndex(:), values(:), ...
    'VariableNames', {'parameter', 'stack_index', 'value'});
writetable(T, filePath);
end

function writeEgrParams(filePath, spec, values)
folder = fileparts(filePath);
if ~isfolder(folder), mkdir(folder); end
T = table(spec.names(:), values(:), 'VariableNames', {'parameter', 'value'});
writetable(T, filePath);
end

function y = rmse(x)
x = x(isfinite(x));
y = sqrt(mean(x.^2));
end

function plotCalibration(noEgrFit, egrFit)
figure('Name', 'Simplified bench calibration', 'NumberTitle', 'off');
tiledlayout(2, 2);

nexttile;
plot(noEgrFit.current_A, noEgrFit.V_exp, 'ko', noEgrFit.current_A, noEgrFit.V_sim, 'b.-');
grid on; xlabel('Current A'); ylabel('Cell voltage V'); title('No-EGR polarization');
legend('Experiment', 'Simulation', 'Location', 'best');

nexttile;
plot(noEgrFit.current_A, noEgrFit.err_V, 'r.-');
grid on; xlabel('Current A'); ylabel('Sim - Exp V'); title('No-EGR residual');

nexttile;
scatter(egrFit.egr_fraction_used, egrFit.V_exp, 36, egrFit.current_A, 'filled'); hold on;
scatter(egrFit.egr_fraction_used, egrFit.V_sim, 36, egrFit.current_A, 'x');
grid on; xlabel('EGR fraction'); ylabel('Cell voltage V'); title('EGR voltage');

nexttile;
plot(egrFit.egr_fraction_used, egrFit.xO2In, 'b.-'); hold on;
plot(egrFit.egr_fraction_used, egrFit.lambdaO2, 'm.-');
grid on; xlabel('EGR fraction'); title('Inlet oxygen diagnostics');
legend('xO2 inlet', 'lambda O2 actual', 'Location', 'best');
end
