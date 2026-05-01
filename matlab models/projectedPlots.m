clear; clc; close all;
s = tf('s');
%% ================= USER INPUTS =================
% Motor transfer function
Gm = 0.257 / ((1.22e-6)*s^2 + (1.04e-3)*s + 0.07);
% F/V transfer function
Rfv = 122000;
Cfv = 0.1e-6;
Gfv = 1 / (1 + s*Rfv*Cfv);
% PI gains
Kp = 1.33;
Ki = 27.52;
%% ================= BUILD SYSTEM =================
P = Gm * Gfv;          % plant
C = Kp + Ki/s;         % PI controller
L = C * P;             % open-loop transfer function
T = feedback(L,1);     % closed-loop transfer function
%% ================= KEY PARAMETERS =================
% PI zero
wz = Ki / Kp;          % rad/s
fz = wz / (2*pi);      % Hz
% Margins
[GM, PM, Wcg, Wcp] = margin(L);
% Wcp is the gain crossover frequency
fc = Wcp / (2*pi);
fprintf('\n=========== KEY RESULTS ===========\n');
fprintf('PI zero frequency      = %.4f Hz\n', fz);
fprintf('PI zero location       = %.4f rad/s\n', wz);
if ~isnan(Wcp) && Wcp > 0
    fprintf('Crossover frequency    = %.4f Hz\n', fc);
    fprintf('Crossover frequency    = %.4f rad/s\n', Wcp);
else
    fprintf('Crossover frequency    = not found\n');
end
fprintf('Phase margin           = %.2f deg\n', PM);
%% ================= STEP RESPONSE METRICS =================
info = stepinfo(T);
% DC gain and step steady-state error
dcT = dcgain(T);
ess_step = abs(1 - dcT);   % for unit-step input
fprintf('\n====== PROJECTED CLOSED-LOOP RESPONSE ======\n');
fprintf('Overshoot              = %.3f %%\n', info.Overshoot);
fprintf('Settling time          = %.6f s\n', info.SettlingTime);
fprintf('Rise time              = %.6f s\n', info.RiseTime);
fprintf('Peak time              = %.6f s\n', info.PeakTime);
fprintf('Projected SS error     = %.6f (unit-step)\n', ess_step);
fprintf('Closed-loop DC gain    = %.6f\n', dcT);
%% ================= CLOSED-LOOP BODE ANALYSIS =================
[mag, phase, w] = bode(T);
mag = squeeze(mag);
phase = squeeze(phase);
% DC gain (at lowest frequency)
mag_dc_dB = 20*log10(mag(1));
% -3 dB bandwidth (frequency where gain drops 3 dB below DC)
mag_dB = 20*log10(mag);
idx_bw = find(mag_dB < mag_dc_dB - 3, 1, 'first');
if ~isempty(idx_bw)
    wBW = w(idx_bw);
    fBW = wBW / (2*pi);
else
    wBW = NaN;
    fBW = NaN;
end
% Resonant peak
[mag_peak, idx_peak] = max(mag);
mag_peak_dB = 20*log10(mag_peak);
Mr_dB = mag_peak_dB - mag_dc_dB;  % peak above DC level
wPeak = w(idx_peak);
fPeak = wPeak / (2*pi);
phase_at_peak = phase(idx_peak);
% Phase at bandwidth
if ~isnan(wBW)
    phase_at_bw = interp1(w, phase, wBW);
else
    phase_at_bw = NaN;
end
fprintf('\n====== CLOSED-LOOP BODE ANALYSIS ======\n');
fprintf('DC gain                = %.4f dB\n', mag_dc_dB);
fprintf('-3 dB bandwidth        = %.4f Hz  (%.4f rad/s)\n', fBW, wBW);
fprintf('Resonant peak (Mr)     = %.4f dB above DC\n', Mr_dB);
fprintf('Peak magnitude         = %.4f dB\n', mag_peak_dB);
fprintf('Peak frequency         = %.4f Hz  (%.4f rad/s)\n', fPeak, wPeak);
fprintf('Phase at peak          = %.2f deg\n', phase_at_peak);
fprintf('Phase at bandwidth     = %.2f deg\n', phase_at_bw);
%% ================= PLOTS =================
figure;
bode(L);
grid on;
title('Projected Open-Loop Bode Plot');
figure;
bode(T);
grid on;
title('Projected Closed-Loop Bode Plot');
figure;
step(T);
grid on;
title('Projected Closed-Loop Step Response');
