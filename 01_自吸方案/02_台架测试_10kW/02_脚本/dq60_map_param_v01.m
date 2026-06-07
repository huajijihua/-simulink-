function param = dq60_map_param_v01(speedRpm)
%DQ60_MAP_PARAM_V01 First-pass DQ60 air-medium map parameters.
%
% The map points are digitized approximately from the supplier DQ60 PDF,
% flow characteristic page at inlet pressure 150 kPa, air medium. The
% implementation intentionally keeps this as a transparent first-pass table
% until exact supplier data are available.

if nargin < 1 || isempty(speedRpm)
    speedRpm = 3000;
end

param = struct();
param.R_J_molK = 8.314462618;
param.M_O2_kg_mol = 0.031998;
param.M_N2_kg_mol = 0.0280134;
param.M_H2O_kg_mol = 0.01801528;
param.gamma = 1.40;
param.cp_J_kgK = 1005.0;
param.eta = 0.62;
param.speed_rpm = min(max(speedRpm, 3000), 8000);
param.speed_grid_rpm = [3000 4000 5000 6000 7000 8000];
param.flow_grid_lpm = [
     80  120  160  210  300  450
    170  220  300  380  500  590
    420  500  580  660  720  760
    590  650  690  760  820  880
    780  830  890  940  990 1040
    960 1030 1070 1120 1160 1200
    ];
param.dp_grid_kPa = [
    29.0 25.0 22.0 16.0  9.0 2.5
    39.5 33.0 27.0 18.5  9.0 4.0
    36.5 26.0 16.0 10.5  6.0 3.0
    40.0 33.0 27.5 19.5 13.0 8.0
    44.5 35.0 28.0 20.5 15.0 7.0
    43.5 32.0 25.0 18.0 15.0 6.5
    ];

param.vector = [
    param.R_J_molK
    param.M_O2_kg_mol
    param.M_N2_kg_mol
    param.M_H2O_kg_mol
    param.gamma
    param.cp_J_kgK
    param.eta
    param.speed_rpm
    param.speed_grid_rpm(:)
    param.flow_grid_lpm(:)
    param.dp_grid_kPa(:)
    ];
end
