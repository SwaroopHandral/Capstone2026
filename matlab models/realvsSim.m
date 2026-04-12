clc; close all; clear;
s = tf('s');

%% ========== SYSTEM MODEL ==========
Gm = 0.257 / ((1.22e-6)*s^2 + (1.04e-3)*s + 0.07);
Rfv = 122e3;
Cfv = 0.1e-6;
Gfv = 1 / (1 + s*Rfv*Cfv);
P = Gm * Gfv;

Kp = 1.33;
Ki = 27.52;
w_lag = 2*pi*0.3;
Gc = Kp + tf(Ki, [1 w_lag]);

L = Gc * P;
T = feedback(L, 1);

%% ========== LOAD MEASURED DATA ==========
data = readtable('2V_stepResponse.csv', 'VariableNamingRule', 'preserve');
varNames = data.Properties.VariableNames;

t_meas = data.('Time (s)');

if ismember('Channel 1 (V)', varNames)
    feedback = data.('Channel 1 (V)');
    setpoint = data.('Channel 2 (V)');
else
    feedback = data.('C1 DC (V)');
    setpoint = data.('C2 DC (V)');
end

% Smooth
N = length(t_meas);
windowPts = max(7, round(0.01 * N));
if mod(windowPts, 2) == 0
    windowPts = windowPts + 1;
end
feedback_smooth = smoothdata(feedback, 'sgolay', windowPts);

% Find RISING step
sp_diff = diff(setpoint);
idx_start = find(sp_diff > 0.5, 1) + 1;
t_start = t_meas(idx_start);

% Find step end
idx_end = find(sp_diff < -0.5, 1);
if isempty(idx_end)
    idx_end = length(t_meas);
end

% Extract step-up portion
t_segment = t_meas(idx_start:idx_end);
fb_segment = feedback_smooth(idx_start:idx_end);
sp_segment = setpoint(idx_start:idx_end);

% Shift time
t_meas_shifted = t_segment - t_start;

%% ========== CALCULATE STEADY-STATE ERROR ==========
% Use last 10% of data for steady-state
ss_start_idx = round(0.9 * length(fb_segment));
fb_ss = mean(fb_segment(ss_start_idx:end));
sp_ss = mean(sp_segment(ss_start_idx:end));

ss_error_V = sp_ss - fb_ss;
ss_error_pct = 100 * abs(ss_error_V) / sp_ss;

fprintf('=== MEASURED STEADY-STATE ERROR ===\n');
fprintf('Setpoint (steady-state):  %.4f V\n', sp_ss);
fprintf('Feedback (steady-state):  %.4f V\n', fb_ss);
fprintf('Steady-state error:       %.4f V (%.2f%%)\n', ss_error_V, ss_error_pct);

%% ========== NORMALIZE BOTH TO SETPOINT ==========
% Normalize measured: 0 to 1 scale
fb_initial = fb_segment(1);
fb_normalized = (fb_segment - fb_initial) / (sp_ss - fb_initial);

%% ========== GET SIMULATED RESPONSE ==========
t_end = max(t_meas_shifted);
[y_sim, t_sim] = step(T, t_end);  % Unit step response (0 to 1)

%% ========== PLOT COMPARISON (NORMALIZED) ==========
figure('Name', 'Simulated vs Measured (Normalized)');
plot(t_sim, y_sim, 'b', 'LineWidth', 2, 'DisplayName', 'Simulated');
hold on;
plot(t_meas_shifted, fb_normalized, 'r', 'LineWidth', 1.5, 'DisplayName', 'Measured');
yline(1, 'k--', 'LineWidth', 1, 'HandleVisibility', 'off');
xlabel('Time (s)');
ylabel('Normalized Amplitude');
title('Simulated vs Measured Step Response (Normalized)');
legend('Location', 'southeast');
grid on;
xlim([0 min(2, t_end)]);
ylim([0 1.5]);

%% ========== PLOT COMPARISON (ACTUAL VOLTS) ==========
figure('Name', 'Simulated vs Measured (Volts)');
plot(t_sim, sp_ss * y_sim, 'b', 'LineWidth', 2, 'DisplayName', 'Simulated');
hold on;
plot(t_meas_shifted, fb_segment, 'r', 'LineWidth', 1.5, 'DisplayName', 'Measured');
yline(sp_ss, 'k--', 'Setpoint', 'LineWidth', 1);
xlabel('Time (s)');
ylabel('Voltage (V)');
title(sprintf('Step Response (Setpoint = %.2f V, SS Error = %.2f%%)', sp_ss, ss_error_pct));
legend('Location', 'southeast');
grid on;
xlim([0 min(2, t_end)]);