clc; close all; clear;
s = tf('s');

%% ========== SYSTEM FREQUENCIES ==========
f_lag = 0.3;          % Controller lag pole (Hz)
w_lag = 2*pi*f_lag;

%% ========== FULL PLANT MODEL ==========
% Motor (2nd order - includes electrical pole)
Gm = 0.257 / ((1.22e-6)*s^2 + (1.04e-3)*s + 0.07);

% F/V Converter
Rfv = 122e3;
Cfv = 0.1e-6;
Gfv = 1 / (1 + s*Rfv*Cfv);

% Total Plant
P = Gm * Gfv;

% Display motor poles
motor_poles = roots([1.22e-6, 1.04e-3, 0.07]);
fprintf('=== PLANT POLES ===\n');
fprintf('Motor pole 1 (mechanical): %.2f Hz\n', abs(motor_poles(1))/(2*pi));
fprintf('Motor pole 2 (electrical): %.2f Hz\n', abs(motor_poles(2))/(2*pi));
fprintf('F/V pole:                  %.2f Hz\n', 1/(2*pi*Rfv*Cfv));

%% ========== ACTUAL CONTROLLER ==========
Kp = 1.33;
Ki = 27.52;

Gc = Kp + tf(Ki, [1 w_lag]);
L = Gc * P;
T = feedback(L, 1);

rlocus(L);

%% ========== PERFORMANCE ==========
[Gm_val, Pm_val, Wcg, Wcp] = margin(L);
info = stepinfo(T);
ess = 100 * (1 - dcgain(T));

fprintf('\n=== CONTROLLER ===\n');
fprintf('Kp = %.2f\n', Kp);
fprintf('Ki = %.2f rad/s\n', Ki);
fprintf('PI zero = %.2f Hz\n', (Ki/Kp)/(2*pi));
fprintf('Lag pole = %.2f Hz\n', f_lag);

fprintf('\n=== PROJECTED PERFORMANCE ===\n');
fprintf('Phase margin:   %.2f deg\n', Pm_val);
fprintf('Gain margin:    %.2f dB\n', 20*log10(Gm_val));
fprintf('Gain crossover: %.2f Hz\n', Wcp/(2*pi));
fprintf('Phase crossover: %.2f Hz\n', Wcg/(2*pi));
fprintf('Rise time:      %.4f s\n', info.RiseTime);
fprintf('Settling time:  %.4f s\n', info.SettlingTime);
fprintf('Overshoot:      %.2f %%\n', info.Overshoot);
fprintf('SS error:       %.2f %%\n', ess);

%% ========== STEP RESPONSE PLOT ==========
figure('Name', 'Projected Step Response');
step(T, 0.5);
grid on;
title('Adjusted Closed-Loop Step Response Projection');
xlabel('Time (s)');
ylabel('Amplitude');

%% ========== BODE PLOT ==========
figure('Name', 'Adjusted Open-Loop Bode Projection');
margin(L);
grid on;
title('Open-Loop Bode Analysis');