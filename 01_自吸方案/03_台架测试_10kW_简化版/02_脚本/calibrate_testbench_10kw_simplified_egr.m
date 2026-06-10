function result = calibrate_testbench_10kw_simplified_egr()
%CALIBRATE_TESTBENCH_10KW_SIMPLIFIED_EGR Refit simplified bench EGR model.
%
% Fits the no-EGR polarization curve on the same voltage equation used in
% PEMFCStackCore, then validates with Simulink. EGR voltage effects are kept
% on the physical gas/water/voltage chain, not on a direct EGR penalty term.

rootDir = fileparts(fileparts(mfilename('fullpath')));
paramDir = fullfile(rootDir, '00_输入参数', '标定参数');
if ~isfolder(paramDir)
    mkdir(paramDir);
end

stackFile = fullfile(paramDir, 'simplified_noegr_stack_params.csv');
if isfile(stackFile), delete(stackFile); end

P0 = init_testbench_10kw_simplified_egr(1, 'noegr', false);
noEgr = P0.noEgrTable;

fprintf('Stage 1: no-EGR voltage-equation fit using %d points.\n', height(noEgr));
baseNoEgr = evaluateNoEgr(noEgr);
stackFit = fitNoEgrVoltageEquation(baseNoEgr, P0);
writeStackParams(stackFile, stackFit.spec, stackFit.values, P0);
fitNoEgr = evaluateNoEgr(noEgr);
fprintf('Stage 1 done: RMSE %.5f V, max abs %.5f V.\n', ...
    rmse(fitNoEgr.err_V), max(abs(fitNoEgr.err_V)));

fitEgr = evaluateEgr(P0.egrTable(isfinite(P0.egrTable.cell_voltage_V), :));
fprintf('EGR replay done without direct voltage penalty: RMSE %.5f V, max abs %.5f V.\n', ...
    rmse(fitEgr.err_V), max(abs(fitEgr.err_V)));

fprintf('FINAL_NOEGR_RMSE=%.6f\n', rmse(fitNoEgr.err_V));
fprintf('FINAL_EGR_RMSE=%.6f\n', rmse(fitEgr.err_V));
fprintf('NOEGR_MAX_ABS=%.6f\n', max(abs(fitNoEgr.err_V)));
fprintf('EGR_MAX_ABS=%.6f\n', max(abs(fitEgr.err_V)));

plotCalibration(fitNoEgr, fitEgr);

result = struct();
result.noegr = fitNoEgr;
result.egr = fitEgr;
result.stack_params = readtable(stackFile, 'TextType', 'string');
end

function spec = baseVoltageSpec(P)
names = ["book_theta1"; "book_theta3"; "book_theta4"; "book_theta8"; "book_theta9"; "book_theta10"];
idx = [12; 14; 15; 17; 18; 19];
default = P.StackModelParam(idx);
lower = [-0.40; -1.20e-3; 0.0; 0.0; 0.0; 0.0];
upper = [0.80;  0.0; 8.0e-4; 5.0e-3; 0.35; 2.5e-2];
default = min(max(default, lower), upper);
spec = struct('names', names, 'stackModelIndex', idx, ...
    'default', default, 'lower', lower, 'upper', upper);
end

function fit = fitNoEgrVoltageEquation(simFit, P)
spec = baseVoltageSpec(P);
I = simFit.current_A;
TK = simFit.T_stack_C + 273.15;
E = simFit.E_Nernst_V;
CO2 = max(simFit.i0Scale, 1e-12);
etaOhmNoTheta8 = simFit.etaOhm_V - I .* P.StackModelParam(17);
Vexp = simFit.V_exp;
th2 = P.StackModelParam(13);

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

function fit = evaluateNoEgr(data)
n = height(data);
fit = table('Size', [n 17], 'VariableTypes', repmat("double", 1, 17), ...
    'VariableNames', {'case_index','current_A','egr_fraction','V_exp','V_sim','err_V', ...
    'xO2In','RHIn','lambdaO2','pCa_kPa','T_stack_C','E_Nernst_V','etaAct_V', ...
    'etaOhm_V','etaCon_V','i0Scale','max_gas_residual'});
for k = 1:n
    P = init_testbench_10kw_simplified_egr(data.case_index(k), 'all', false);
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
fit = table('Size', [n 15], 'VariableTypes', repmat("double", 1, 15), ...
    'VariableNames', {'case_index','current_A','egr_fraction_raw','egr_fraction_used','V_exp','V_sim','err_V', ...
    'xO2In','RHIn','lambdaO2','E_Nernst_V','etaAct_V','etaOhm_V','etaCon_V','max_gas_residual'});
for k = 1:n
    P = init_testbench_10kw_simplified_egr(data.case_index(k), 'all', false);
    out = simulateCase(P);
    s = lastVector(out.get('summary_vector'));
    fit.case_index(k) = data.case_index(k);
    fit.current_A(k) = P.I_stack_default_A;
    fit.egr_fraction_raw(k) = P.egr_fraction_cmd_raw;
    fit.egr_fraction_used(k) = P.egr_fraction_cmd;
    fit = fillCommonFit(fit, k, s, P);
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
in = in.setVariable('PhysicalParam_simplified', P.PhysicalParam);
in = in.setVariable('StackModelParam_simplified', P.StackModelParam);
in = in.setVariable('CaseBoundaryParam_simplified', P.CaseBoundaryParam);
in = in.setVariable('CoolingCurveParam_simplified', P.CoolingCurveParam);
in = in.setVariable('dt_s_simplified', P.dt_s_simplified);
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

function writeStackParams(filePath, spec, values, P)
folder = fileparts(filePath);
if ~isfolder(folder), mkdir(folder); end
T = table(spec.names(:), spec.stackModelIndex(:), values(:), ...
    'VariableNames', {'parameter', 'stack_model_index', 'value'});
if nargin >= 4 && isfield(P, 'tau_mem_s')
    T = [T; table("tau_mem_s", 24, P.tau_mem_s, ...
        'VariableNames', {'parameter', 'stack_model_index', 'value'})];
end
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
