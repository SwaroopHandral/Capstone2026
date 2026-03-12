clear; close all;

s = tf('s');

%% Transfer functions

% motor
Gm = 0.257 / ((1.22e-6)*s^2 + (1.04e-3)*s + 0.07);

% fv converter
Rfv = 122e3;
Cfv = 0.1e-6;
Gfv = 1 / (1 + s*Rfv*Cfv);

% plant
P = Gm * Gfv;

%% choose PI zero and crossover target
fz = 11.7;
fc = 10;

wz = 2*pi*fz;
wc = 2*pi*fc;

%% Evaluate plant magnitude at crossover

magP = abs(squeeze(freqresp(P, wc)));

%% Estimate Kp and Ki

Gc_factor = sqrt(1 + (wz/wc)^2);

Kp = 1 / (magP * Gc_factor);
Ki = wz * Kp;

fprintf('Chosen PI zero: %.2f Hz\n', fz);
fprintf('Chosen crossover target: %.2f Hz\n', fc);
fprintf('Plant magnitude at crossover: %.6g\n', magP);
fprintf('Estimated Kp: %.6g\n', Kp);
fprintf('Estimated Ki: %.6g\n', Ki);
fprintf('Resulting PI zero: %.4f Hz\n', Ki/(2*pi*Kp));

%% Build controller and loop
Gc = Kp + Ki/s;
L = Gc * P;
T = feedback(L,1);

%% Plot open loop bode estimate
figure;
margin(L);
grid on;
title('Open-Loop Bode Plot with Estimated PI Controller');

%% Plot closed loop step response estimate
figure;
step(T);
grid on;
title('Closed-Loop Step Response with Estimated PI Controller');

%% Give margins
[Gm_margin, Pm, Wcg, Wcp] = margin(L);

fprintf('\nGain margin (absolute): %.4g\n', Gm_margin);
fprintf('Phase margin (deg): %.2f\n', Pm);
fprintf('Gain crossover frequency: %.4f rad/s = %.4f Hz\n', Wcg, Wcg/(2*pi));
fprintf('Phase crossover frequency: %.4f rad/s = %.4f Hz\n', Wcp, Wcp/(2*pi));

%% dipslay poles
disp('Motor poles (Hz):');
disp(abs(pole(Gm))/(2*pi));

disp('F/V pole (Hz):');
disp(abs(pole(Gfv))/(2*pi));

disp('Open-loop poles (Hz):');
disp(abs(pole(L))/(2*pi));