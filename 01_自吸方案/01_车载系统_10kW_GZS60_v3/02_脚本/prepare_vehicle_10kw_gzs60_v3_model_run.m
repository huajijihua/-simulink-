function P = prepare_vehicle_10kw_gzs60_v3_model_run(modelName)
%PREPARE_VEHICLE_10KW_GZS60_V3_MODEL_RUN Initialize model workspace for UI Run.
%
% Simulink direct Run resolves variables from the model workspace before the
% base workspace. This helper refreshes the model workspace so saved stale
% parameter vectors do not shadow the current calibrated vectors.

if nargin < 1 || strlength(string(modelName)) == 0
    modelName = bdroot;
else
    modelName = char(modelName);
end

scriptDir = fileparts(mfilename('fullpath'));
if ~contains(path, scriptDir)
    addpath(scriptDir);
end

P = init_vehicle_10kw_gzs60_v3("current");
mw = get_param(modelName, 'ModelWorkspace');
clearObsoleteModelWorkspaceSymbols(mw);

assignin(mw, 'P_v2', P);
assignin(mw, 'EnvParam_v2', P.EnvParam);
assignin(mw, 'CompressorParam_v2', P.CompressorParam);
assignin(mw, 'IntercoolerParam_v2', P.IntercoolerParam);
assignin(mw, 'HumidifierParam_v2', P.HumidifierParam);
assignin(mw, 'StackParam_v2', P.StackParam);
assignin(mw, 'I_stack_cmd_A', P.I_stack_default_A);
assignin(mw, 'egr_fraction_cmd', 0.0);
assignin(mw, 'EGRInitialNode_v2', P.egr_initial_node);
assignin(mw, 'WetInitialNode_v2', P.wet_initial_node);
assignin(mw, 'StackInitialState_v2', P.stack_initial_state);
assignin(mw, 'StackInitialStateAudit_v3', P.stack_initial_state_audit);

fprintf('Prepared %s model workspace for direct Run. StackParam_v2 length = %d.\n', ...
    modelName, numel(P.StackParam));
end

function clearObsoleteModelWorkspaceSymbols(mw)
obsolete = [
    "SeparatorParam_v2"
    "TailGasParam_v2"
    "EGRValveParam_v2"
    "BackPressureValveParam_v2"
    "EGRReturnPipeParam_v2"
    "CathodeOutletManifoldParam_v3"
    "AnodeOutletManifoldParam_v3"
    "CathodeOutletManifoldInitialState_v3"
    "AnodeOutletManifoldInitialState_v3"
    "TailGasManifoldInitialState_v3"
    "AnodeTailDownstreamPressure_v3"
    ];
for k = 1:numel(obsolete)
    if hasVariable(mw, obsolete(k))
        clear(mw, obsolete(k));
    end
end
end
