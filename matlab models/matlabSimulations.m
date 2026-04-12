clc; close all; clear;
s = tf('s');

%% Step Inputs Configuration
% [amplitude, enabled]
step_inputs = [
    2, true;    % 2V step
    4, true;    % 4V step
    6, true;    % 6V step
];

%% Plant Components
% Motor
Gm = 0.257 / ((1.22e-6)*s^2 + (1.04e-3)*s + 0.07);

% F/V Converter
Rfv = 122e3;
Cfv = 0.1e-6;
Gfv = 1 / (1 + s*Rfv*Cfv);

% Total Plant
P = Gm * Gfv;

%% Controller Parameters
Kp = 1.33;
Ki = 27.52;
R_bleed = 1e6;
C_int = 0.47e-6;

% Lag pole from R_BLEED || C_int
wp = 1 / (R_bleed * C_int);
fp = wp / (2*pi);

%% Controller Breakdown (Hp and Hi)
% As defined in your presentation
Hp = tf(Kp, 1);             % Proportional part
Hi = tf(Ki, [1 wp]);        % Integral/Lag part
Gc = Hp + Hi;               % Total Controller Gc

%% Open-loop and Closed-loop
L = Gc * P;
T = feedback(L, 1);

%% --- Display Section ---
fprintf('=== CONTROLLER COMPONENTS ===\n');
fprintf('Proportional Transfer (Hp):\n');
disp(Hp);
fprintf('Integral/Lag Transfer (Hi):\n');
disp(Hi);
fprintf('Total Controller Gc (Hp + Hi):\n');
disp(Gc);

fprintf('\n=== SYSTEM TRANSFER FUNCTIONS ===\n');
fprintf('Open-Loop L(s):\n');
disp(L);
fprintf('Closed-Loop T(s):\n');
disp(T);

% Stability Margins
[Gm_margin, Pm, Wcg, Wcp] = margin(L);
fprintf('\n=== FREQUENCIES & MARGINS ===\n');
fprintf('PI zero: %.4f Hz\n', (Ki/Kp)/(2*pi));
fprintf('Lag pole: %.4f Hz\n', fp);
fprintf('Crossover frequency: %.4f Hz\n', Wcp/(2*pi));
fprintf('Gain margin: %.2f dB\n', 20*log10(Gm_margin));
fprintf('Phase margin: %.2f deg\n', Pm);

% Step Response Info
info = stepinfo(T);
fprintf('\n=== STEP RESPONSE CHARACTERISTICS ===\n');
fprintf('Rise time: %.4f s\n', info.RiseTime);
fprintf('Settling time (2%%): %.4f s\n', info.SettlingTime);
fprintf('Overshoot: %.2f %%\n', info.Overshoot);

%% --- Plotting ---
% Bode Plot
figure;
margin(L);
grid on;

% Step Response
figure;
[y, t] = step(T);
hold on;
colors = ['b', 'r', 'k'];
color_idx = 1;
for i = 1:size(step_inputs, 1)
    if step_inputs(i, 2)
        A = step_inputs(i, 1);
        plot(t, A*y, colors(color_idx), 'LineWidth', 1.5);
        plot(t, A*ones(size(t)), [colors(color_idx), '--'], 'LineWidth', 1);
        color_idx = mod(color_idx, 3) + 1;
    end
end
grid on;
xlabel('Time (s)');
ylabel('Response');
title('Closed-Loop Multi-Step Response');