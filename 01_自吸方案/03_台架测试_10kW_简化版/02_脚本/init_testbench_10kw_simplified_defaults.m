function P = init_testbench_10kw_simplified_defaults()
%INIT_TESTBENCH_10KW_SIMPLIFIED_DEFAULTS Defaults for the simplified bench model.
%
% This file is scoped to CEGR_TestBench_10kW_SimplifiedEGR_v01 only. It does
% not call or inherit from the vehicle v3 initialization scripts.

P = struct();

% Physical constants and ambient boundary.
P.R_J_molK = 8.314462618;
P.F_C_mol = 96485.33212;
P.M_O2_kg_mol = 0.031998;
P.M_N2_kg_mol = 0.0280134;
P.M_H2O_kg_mol = 0.01801528;
P.M_H2_kg_mol = 0.00201588;
P.p_amb_kPa = 101.325;
P.T_amb_C = 25.0;
P.xO2_dry = 0.2095;
P.xN2_dry = 0.7905;

% Stack geometry and flow/thermal closure used by the simplified bench SLX.
P.N_cell = 16;
P.A_cell_cm2 = 380.0;
P.V_ca_m3 = 2.0e-4;
P.V_an_m3 = 1.5e-4;
P.K_ca_out_kg_s_kPa = 1.2e-4;
P.K_an_out_kg_s_kPa = 6.67e-6;
P.C_stack_J_K = 4.5e4;
P.h_cool_W_K = 836.0;
P.h_amb_W_K = 9.0;

% Voltage and membrane-water model defaults for the simplified bench fit.
P.E_nernst_ref_V = 1.229;
P.E_nernst_temp_coeff_V_K = 8.5e-4;
P.book_theta1 = 0.313798014570513;
P.book_theta2 = 0.0;
P.book_theta3 = -2.16840434497101e-18;
P.book_theta4 = 6.22923762412631e-5;
P.membraneThickness_cm = 0.005;
P.book_theta8 = 2.04593457740055e-4;
P.book_theta9 = 2.28206062923902e-157;
P.book_theta10 = 0.025;
P.thermoneutralVoltage_V = 1.254;
P.book_theta5 = 0.525;
P.book_theta6 = 0.2173;
P.book_theta7 = -302.06;
P.tau_mem_s = 1.0;

% Cooling curve used by the simplified stack heat balance.
P.cool_flow_curve_enabled = 1.0;
P.cool_flow_curve_L_min = [5.5 6.0 6.5 7.5 9.1 10.0 11.1 11.5];
P.cool_flow_curve_h_W_K = [836.0 836.0 905.666666666667 1045.0 ...
    1267.93333333334 1393.33333333333 1546.6 1602.33333333333];

% Case-level defaults overwritten by the measured bench case table.
P.I_stack_default_A = 38.0;
P.current_density_A_cm2 = NaN;
P.cell_voltage_bench_V = NaN;
P.egr_fraction_cmd = 0.0;
P.stack_in_flow_SLPM = NaN;
P.stack_in_flow_kg_s = NaN;
P.fresh_supply_flow_SLPM = NaN;
P.fresh_supply_flow_kg_s = NaN;
P.bench_stack_in_T_C = NaN;
P.bench_stack_in_p_kPa = NaN;
P.bench_stack_in_RH = NaN;
P.stack_out_p_kPa = NaN;
P.stack_out_T_C = NaN;
P.cathode_dp_kPa = NaN;
P.separator_T_C = NaN;
P.separator_p_kPa = NaN;
P.anode_stoich = NaN;
P.RH_an_in = NaN;
P.p_anode_in_kPa = NaN;
P.p_anode_back_kPa = NaN;
P.p_cathode_back_kPa = NaN;
P.T_cool_C = NaN;
P.coolant_out_C = NaN;
P.coolant_flow_L_min = NaN;
end
