function [out, diag] = dq60_map_apply_v01(in, paramVector)
%DQ60_MAP_APPLY_V01 Apply the first-pass DQ60 pressure-rise map to a gas node.
%
% Node convention: [mO2; mN2; mH2Ov; mH2Ol; T_C; p_kPa; liquidFlag].

[R, M_O2, M_N2, M_H2O, gamma, cp, eta, speedGrid, flowGrid, dpGrid, speedRpm] = unpackParam(paramVector);

out = in;
T_K = max(in(5) + 273.15, 150);
p_kPa = max(in(6), 1);
nDot = max(in(1), 0) / M_O2 + max(in(2), 0) / M_N2 + max(in(3), 0) / M_H2O;
mDot = max(sum(in(1:3)), 0);
flowLpm = nDot * R * T_K / (p_kPa * 1000) * 60000;
dpKPa = interpMap(flowLpm, speedRpm, speedGrid, flowGrid, dpGrid);
pOutKPa = p_kPa + max(dpKPa, 0);
pressureRatio = max(pOutKPa / p_kPa, 1.0);
dT_K = T_K / max(eta, 0.05) * (pressureRatio ^ ((gamma - 1) / gamma) - 1);
powerW = mDot * cp * dT_K;

out(5) = T_K + dT_K - 273.15;
out(6) = pOutKPa;
out(7) = double(out(4) > 1e-12);

diag = struct();
diag.speed_rpm = speedRpm;
diag.flow_lpm = flowLpm;
diag.dp_kPa = dpKPa;
diag.pressure_ratio = pressureRatio;
diag.power_W = powerW;
diag.T_out_C = out(5);
diag.p_out_kPa = out(6);
diag.map_flow_clamped = double(flowLpm < min(flowGrid(:)) || flowLpm > max(flowGrid(:)));
end

function [R, M_O2, M_N2, M_H2O, gamma, cp, eta, speedGrid, flowGrid, dpGrid, speedRpm] = unpackParam(p)
R = p(1);
M_O2 = p(2);
M_N2 = p(3);
M_H2O = p(4);
gamma = p(5);
cp = p(6);
eta = p(7);
speedRpm = p(8);
speedGrid = p(9:14).';
flowGrid = reshape(p(15:50), 6, 6);
dpGrid = reshape(p(51:86), 6, 6);
end

function dp = interpMap(flowLpm, speedRpm, speedGrid, flowGrid, dpGrid)
dpBySpeed = zeros(numel(speedGrid), 1);
for i = 1:numel(speedGrid)
    q = flowGrid(i, :);
    d = dpGrid(i, :);
    if flowLpm <= q(1)
        dpBySpeed(i) = d(1);
    elseif flowLpm >= q(end)
        dpBySpeed(i) = d(end);
    else
        dpBySpeed(i) = interp1(q, d, flowLpm, 'linear');
    end
end
speed = min(max(speedRpm, speedGrid(1)), speedGrid(end));
dp = interp1(speedGrid, dpBySpeed, speed, 'linear');
end
