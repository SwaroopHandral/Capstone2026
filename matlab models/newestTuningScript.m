clc; close all; clear;
s = tf('s');

%% ========== SYSTEM FREQUENCIES ==========
f_crossover = 10;     % Target crossover frequency (Hz)
f_lag = 0.3;          % Controller lag pole (Hz)

w_crossover = 2*pi*f_crossover;
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

% Find motor poles
motor_poles = roots([1.22e-6, 1.04e-3, 0.07]);

% Select the SLOWER pole (mechanical) for cancellation
[~, idx_slow] = min(abs(motor_poles));
w_motor_mech = abs(motor_poles(idx_slow));
f_motor_mech = w_motor_mech / (2*pi);

% The other pole is electrical
[~, idx_fast] = max(abs(motor_poles));
w_motor_elec = abs(motor_poles(idx_fast));
f_motor_elec = w_motor_elec / (2*pi);

% F/V pole
f_fv = 1/(2*pi*Rfv*Cfv);

fprintf('=== PLANT POLES ===\n');
fprintf('Motor pole 1 (mechanical): %.2f Hz\n', f_motor_mech);
fprintf('Motor pole 2 (electrical): %.2f Hz\n', f_motor_elec);
fprintf('F/V pole:                  %.2f Hz\n', f_fv);
fprintf('Plant DC gain:             %.4f\n', dcgain(P));

%% ========== DESIGN PI CONTROLLER ==========
% Strategy: Place PI zero at mechanical motor pole for cancellation
% Then set Kp to achieve target crossover frequency

% Step 1: Place PI zero at mechanical motor pole
w_z = w_motor_mech;

% Step 2: Find plant magnitude at target crossover
[mag_P_wc, ~] = bode(P, w_crossover);

% Step 3: Required controller magnitude for |L(jwc)| = 1
mag_Gc_needed = 1 / mag_P_wc;

% Step 4: Controller magnitude formula
% |Gc(jw)| = Kp * |jw + w_z| / |jw + w_lag|
%          = Kp * sqrt(w^2 + w_z^2) / sqrt(w^2 + w_lag^2)
mag_ratio = sqrt(w_crossover^2 + w_z^2) / sqrt(w_crossover^2 + w_lag^2);

% Step 5: Solve for Kp
Kp_proj = mag_Gc_needed / mag_ratio;

% Step 6: Ki from zero location
Ki_proj = Kp_proj * w_z;

%% ========== BUILD PROJECTED SYSTEM ==========
Gc_proj = Kp_proj + tf(Ki_proj, [1 w_lag]);
L_proj = Gc_proj * P;
T_proj = feedback(L_proj, 1);

%% ========== DISPLAY DERIVED GAINS ==========
fprintf('\n=== DERIVED CONTROLLER GAINS ===\n');
fprintf('Design method: Pole-zero cancellation at mechanical motor pole\n');
fprintf('Target crossover: %.2f Hz\n', f_crossover);
fprintf('PI zero placed at: %.2f Hz\n', w_z/(2*pi));
fprintf('\nDerived gains:\n');
fprintf('  Kp = %.4f\n', Kp_proj);
fprintf('  Ki = %.4f rad/s\n', Ki_proj);
fprintf('  Ki/Kp = %.2f rad/s (%.2f Hz)\n', Ki_proj/Kp_proj, (Ki_proj/Kp_proj)/(2*pi));

%% ========== PROJECTED PERFORMANCE ==========
fprintf('\n=== PROJECTED PERFORMANCE ===\n');

[Gm_proj, Pm_proj, Wcg_proj, Wcp_proj] = margin(L_proj);
info_proj = stepinfo(T_proj);
ess_proj = 100 * (1 - dcgain(T_proj));

fprintf('Phase margin:      %.2f deg\n', Pm_proj);
fprintf('Gain margin:       %.2f dB\n', 20*log10(Gm_proj));
fprintf('Gain crossover:    %.2f Hz\n', Wcp_proj/(2*pi));
fprintf('Phase crossover:   %.2f Hz\n', Wcg_proj/(2*pi));
fprintf('Rise time:         %.4f s\n', info_proj.RiseTime);
fprintf('Settling time:     %.4f s\n', info_proj.SettlingTime);
fprintf('Overshoot:         %.2f %%\n', info_proj.Overshoot);
fprintf('SS error:          %.2f %%\n', ess_proj);

%% ========== PLOTTING ==========
figure('Name', 'Projected Step Response');
step(T_proj, 0.5);
grid on;
title('Projected Closed-Loop Step Response');
xlabel('Time (s)');
ylabel('Amplitude');

figure('Name', 'Projected Open-Loop Bode');
margin(L_proj);
grid on;
title('Projected Open-Loop Bode Plot');

%% ========== SUMMARY ==========
fprintf('\n========================================\n');
fprintf('DESIGN SUMMARY\n');
fprintf('========================================\n');
fprintf('1. Plant poles: %.2f Hz, %.2f Hz, %.2f Hz\n', f_motor_mech, f_motor_elec, f_fv);
fprintf('2. Target crossover: %.1f Hz\n', f_crossover);
fprintf('3. PI zero at mechanical pole: %.2f Hz\n', f_motor_mech);
fprintf('4. Derived Kp = %.4f, Ki = %.2f rad/s\n', Kp_proj, Ki_proj);
fprintf('5. Achieved crossover: %.2f Hz\n', Wcp_proj/(2*pi));
fprintf('6. Phase margin: %.2f deg\n', Pm_proj);
fprintf('7. Gain margin: %.2f dB\n', 20*log10(Gm_proj));
fprintf('========================================\n');