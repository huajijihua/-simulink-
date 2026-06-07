function prepare_testbench_10kw_v01_model_run(modelName)
%PREPARE_TESTBENCH_10KW_V01_MODEL_RUN Ensure bench model variables exist.
if nargin < 1 || isempty(modelName)
    modelName = bdroot;
end
if evalin('base', 'exist(''P_testbench_v1'', ''var'')') == 0
    init_testbench_10kw_v01(1, 0.0);
end
P = evalin('base', 'P_testbench_v1');
assignin('base', 'BenchAirParam_v1', P.BenchAirParam);
assignin('base', 'BenchConditionerParam_v1', P.BenchConditionerParam);
assignin('base', 'CompressorParam_v2', P.CompressorParam);
assignin('base', 'StackParam_v2', P.StackParam);
assignin('base', 'I_stack_cmd_A', P.I_stack_default_A);
assignin('base', 'egr_fraction_cmd', P.egr_fraction_cmd);
assignin('base', 'EGRInitialNode_v2', P.egr_initial_node);
assignin('base', 'StackInitialState_v2', P.stack_initial_state);
mw = get_param(modelName, 'ModelWorkspace');
assignin(mw, 'BenchAirParam_v1', P.BenchAirParam);
assignin(mw, 'BenchConditionerParam_v1', P.BenchConditionerParam);
assignin(mw, 'CompressorParam_v2', P.CompressorParam);
assignin(mw, 'StackParam_v2', P.StackParam);
assignin(mw, 'I_stack_cmd_A', P.I_stack_default_A);
assignin(mw, 'egr_fraction_cmd', P.egr_fraction_cmd);
assignin(mw, 'EGRInitialNode_v2', P.egr_initial_node);
assignin(mw, 'StackInitialState_v2', P.stack_initial_state);
fprintf('Prepared %s workspace for testbench run.\n', modelName);
end
