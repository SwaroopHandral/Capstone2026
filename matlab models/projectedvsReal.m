%% Predicted vs. Measured Step Response Comparison (4.07 V setpoint)
% Left:  projected step response from the linear MATLAB model
% Right: measured hardware response from the 4 V step CSV
clear; clc; close all;

%% ============================================================
%% SETTINGS
%% ============================================================
measuredFile = '4V_stepResponse.csv';
setpoint     = 4.07;     % V
tWindow      = 1.5;      % seconds to display on each plot

% Smoothing for measured trace (cosmetic, Savitzky-Golay)
smoothFrac   = 0.015;
minWindow    = 21;

%% ============================================================
%% PROJECTED MODEL (from tuning script)
%% ============================================================
s = tf('s');

% PI compensator with lag pole (leaky integrator)
f_lag = 0.3;
w_lag = 2*pi*f_lag;
Kp    = 1.33;
Ki    = 27.52;
Gc    = Kp + tf(Ki, [1 w_lag]);

% Motor transfer function (as designed)
Gm = 0.257 / ((1.22e-6)*s^2 + (1.04e-3)*s + 0.07);

% F/V converter
Rfv = 122e3;
Cfv = 0.1e-6;
Gfv = 1 / (1 + s*Rfv*Cfv);

% Open-loop and closed-loop
P = Gm * Gfv;
T = feedback(Gc * P, 1);

% Simulate step response at the 4.07 V setpoint
t_pred = linspace(0, tWindow, 2000)';
y_pred = setpoint * step(T, t_pred);

info_pred = stepinfo(T);

%% ============================================================
%% MEASURED DATA
%% ============================================================
data = readmatrix(measuredFile);
t_raw    = data(:,1);
V_out    = data(:,2);
V_sp_raw = data(:,3);

% Find the rising edge of the setpoint
sp_diff = diff(V_sp_raw);
idx_start = find(sp_diff > 0.5, 1) + 1;

if isempty(idx_start)
    error('Could not locate step in %s', measuredFile);
end

% Trim to a window of tWindow seconds starting at the step
t_step_abs = t_raw(idx_start);
idx_end = find(t_raw >= t_step_abs + tWindow, 1, 'first');
if isempty(idx_end)
    idx_end = length(t_raw);
end

t_meas_seg = t_raw(idx_start:idx_end) - t_step_abs;
V_out_seg  = V_out(idx_start:idx_end);
N_seg      = length(t_meas_seg);

% Savitzky-Golay smoothing (cosmetic only)
windowPts = max(minWindow, round(smoothFrac * N_seg));
if mod(windowPts, 2) == 0
    windowPts = windowPts + 1;
end
if windowPts >= N_seg
    windowPts = N_seg - 1;
    if mod(windowPts, 2) == 0
        windowPts = windowPts - 1;
    end
end
V_out_smooth = smoothdata(V_out_seg, 'sgolay', windowPts);

% Measured response characteristics
[peakVal, ~] = max(V_out_smooth);
os_meas      = 100 * (peakVal - setpoint) / setpoint;
ssVal_meas   = mean(V_out_smooth(end - round(0.05*N_seg) : end));
ess_meas     = 100 * abs(setpoint - ssVal_meas) / setpoint;

%% ============================================================
%% PLOTTING
%% ============================================================
figure('Name', 'Predicted vs Measured Step Response', ...
       'Position', [100 100 1200 500]);

% Common y-limits so both plots read on the same scale
yMax = max([max(y_pred), max(V_out_smooth)]) * 1.10;
yMin = -0.1 * setpoint;

% ---------- LEFT: PROJECTED ----------
subplot(1, 2, 1);
plot(t_pred, y_pred, 'Color', [0.0 0.45 0.74], 'LineWidth', 2.2); hold on;
yline(setpoint, 'k:', 'LineWidth', 1.2, 'HandleVisibility', 'off');
yline(setpoint * 1.05, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
yline(setpoint * 0.95, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
grid on; box on;
xlim([0 tWindow]);
ylim([yMin yMax]);
xlabel('Time (s)');
ylabel('Voltage (V)');
title(sprintf('Projected Step Response (%.2f V setpoint)', setpoint));
set(gca, 'FontSize', 12);

% Annotation block for projected
txt_pred = sprintf('Overshoot: %.1f %%\nRise time: %.0f ms\nSettle time: %.2f s\nSS error: %.2f %%', ...
    info_pred.Overshoot, info_pred.RiseTime*1000, info_pred.SettlingTime, ...
    100 * abs(1 - dcgain(T)));
text(0.97, 0.05, txt_pred, 'Units', 'normalized', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
    'FontSize', 10, 'BackgroundColor', [1 1 1 0.85], ...
    'EdgeColor', [0.7 0.7 0.7]);

% ---------- RIGHT: MEASURED ----------
subplot(1, 2, 2);
plot(t_meas_seg, V_out_smooth, 'Color', [0.85 0.33 0.10], 'LineWidth', 2.2); hold on;
yline(setpoint, 'k:', 'LineWidth', 1.2, 'HandleVisibility', 'off');
yline(setpoint * 1.05, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
yline(setpoint * 0.95, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
grid on; box on;
xlim([0 tWindow]);
ylim([yMin yMax]);
xlabel('Time (s)');
ylabel('Voltage (V)');
title(sprintf('Measured Step Response (%.2f V setpoint)', setpoint));
set(gca, 'FontSize', 12);

% Annotation block for measured (uses hardcoded 1.3% ess)
txt_meas = sprintf('Overshoot: %.1f %%\nSS error: 1.30 %%', os_meas);
text(0.97, 0.05, txt_meas, 'Units', 'normalized', ...
    'HorizontalAlignment', 'right', 'VerticalAlignment', 'bottom', ...
    'FontSize', 10, 'BackgroundColor', [1 1 1 0.85], ...
    'EdgeColor', [0.7 0.7 0.7]);

sgtitle('Predicted vs. Measured Step Response', 'FontWeight', 'bold', 'FontSize', 13);

%% ============================================================
%% CONSOLE SUMMARY
%% ============================================================
fprintf('\n=== PROJECTED vs MEASURED (%.2f V setpoint) ===\n', setpoint);
fprintf('                   Projected      Measured\n');
fprintf('Overshoot:         %6.1f %%       %6.1f %%\n', info_pred.Overshoot, os_meas);
fprintf('Rise time:         %6.0f ms        (see plot)\n', info_pred.RiseTime*1000);
fprintf('Settling time:     %6.2f s         (see plot)\n', info_pred.SettlingTime);
fprintf('SS error:          %6.2f %%       1.30 %% (from extended capture)\n', ...
    100 * abs(1 - dcgain(T)));