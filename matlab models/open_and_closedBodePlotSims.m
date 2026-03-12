
% current values:
% Motor TF: 0.257 / (1.22e-6*s^2 + 1.04e-3*s + 0.07)
% F/V pole: R = 122 kOhm, C = 0.1 uF
% PI gains: Kp = 1.33, Ki = 27.4
clear; clc; close all;
s = tf('s');

%% Motor transfer function
Gm = 0.257 / ((1.22e-6)*s^2 + (1.04e-3)*s + 0.07);

%% F/V converter transfer function

Rfv = 122e3;
Cfv = 0.1e-6;
Gfv = 1 / (1 + s*Rfv*Cfv);

%% Plant

P = Gm * Gfv;

%% PI controller params
Kp = 1.33;
Ki = 27.4;
Gc = Kp + Ki/s;

%% Open-loop and closed-loop
L = Gc * P;
T = feedback(L,1);   % T(s) = L / (1 + L)

%% Frequency range
f = logspace(-2, 3, 3000);   % 0.01 Hz to 1 kHz
w = 2*pi*f;

%% Closed-loop bode plot
figure;
bode(T, w);
grid on;
title('Closed-Loop Bode Plot: T(s) = V_{fb}(s) / V_{sp}(s)');

%% comparing plant, open-loop, and closed-loop
figure;
bode(P, L, T, w);
grid on;
legend('Plant P(s)', 'Open-loop L(s)', 'Closed-loop T(s)', 'Location', 'best');
title('Plant, Open-Loop, and Closed-Loop Bode Plots');

%% Poles / zeros
disp('Closed-loop poles (rad/s):');
disp(pole(T));

disp('Closed-loop poles (Hz):');
disp(abs(pole(T))/(2*pi));

disp('Closed-loop zeros (rad/s):');
disp(zero(T));

disp('Closed-loop zeros (Hz):');
disp(abs(zero(T))/(2*pi));