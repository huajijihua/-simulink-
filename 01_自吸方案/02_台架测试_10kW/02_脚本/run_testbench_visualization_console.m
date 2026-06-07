function results = run_testbench_visualization_console(options)
%RUN_TESTBENCH_VISUALIZATION_CONSOLE Open bench-study figures and write Excel.
%
% The console reads existing study CSV files. It does not export PNG files
% and does not run new simulations.

if nargin < 1
    options = struct();
end
if ~isfield(options, 'CloseExistingFigures')
    options.CloseExistingFigures = true;
end

C = testbench_viz_utils("context");
if options.CloseExistingFigures
    testbench_viz_utils("closeFigures");
end

constantCurrent = testbench_viz_utils("loadConstantCurrent", C);
constantVoltage = testbench_viz_utils("loadConstantVoltage", C);
[constantPO2, constantPO2Comparison] = testbench_viz_utils("loadConstantPO2TwoPoint", C);

figCurrentMain = testbench_viz_utils("plotEgrMain", constantCurrent, "constant_current");
figCurrentDiag = testbench_viz_utils("plotEgrDiagnostics", constantCurrent, "constant_current");
figVoltageMain = testbench_viz_utils("plotEgrMain", constantVoltage, "constant_voltage");
figVoltageDiag = testbench_viz_utils("plotEgrDiagnostics", constantVoltage, "constant_voltage");
figPO2TwoPoint = testbench_viz_utils("plotConstantPO2TwoPoint", constantPO2, constantPO2Comparison);

testbench_viz_utils("writeSheet", C, "constant_current", constantCurrent);
testbench_viz_utils("writeSheet", C, "constant_voltage", constantVoltage);
testbench_viz_utils("writeSheet", C, "constant_pO2_DQ60_two_point", constantPO2);
testbench_viz_utils("writeSheet", C, "constant_pO2_DQ60_comparison", constantPO2Comparison);

runInfo = testbench_viz_utils("makeRunInfo", C, "testbench_visualization_existing_results");
testbench_viz_utils("writeSheet", C, "run_info", runInfo);

results = struct();
results.constantCurrent = constantCurrent;
results.constantVoltage = constantVoltage;
results.constantPO2TwoPoint = constantPO2;
results.constantPO2Comparison = constantPO2Comparison;
results.figures = [figCurrentMain, figCurrentDiag, figVoltageMain, figVoltageDiag, figPO2TwoPoint];
results.workbookFile = C.workbookFile;

assignin('base', 'testbenchVisualizationConsoleResults', results);
fprintf('Testbench visualization console opened 5 figures. Data workbook updated: %s\n', C.workbookFile);
end
