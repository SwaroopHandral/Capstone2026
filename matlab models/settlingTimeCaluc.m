% Settling Time Analysis for Real-World Step Response Data
clear; clc; close all;

% Filenames
files = {'2V_stepResponse.csv', '4V_stepResponse.csv', '6V_stepResponse.csv'};

%% Line colors (blue, red, yellow)
lineColors = [
    0.0000    0.4470    0.7410   % blue
    0.8500    0.3250    0.0980   % red
    0.9290    0.6940    0.1250   % yellow
];

%% Settling targets for each file
final_vals = [2.16, 4.07, 6.25];

%% Smoothing settings
smoothFrac = 0.10;
minWindow  = 101;

figure('Name', 'Step Response Analysis');
hold on; grid on;

for i = 1:length(files)
    try
        % 1. Load Data
        data = readmatrix(files{i});
        
        t = data(:,1); t = t(:);
        V_out = data(:,2); V_out = V_out(:);
        V_sp = data(:,3); V_sp = V_sp(:);
        
        N = length(t);
        final_val = final_vals(i);
        
        % Estimate sample rate
        dt = mean(diff(t));
        sample_rate = 1/dt;
        
        % 2. Find step on RAW setpoint data first
        sp_diff = diff(V_sp);
        idx_start = find(sp_diff > 0.5, 1) + 1;
        idx_end = find(sp_diff < -0.5, 1);
        
        if isempty(idx_start)
            warning('Could not find rising step in %s', files{i});
            continue;
        end
        if isempty(idx_end)
            idx_end = N;
        end
        
        % 3. Extract step-up portion
        t_seg = t(idx_start:idx_end) - t(idx_start);
        V_out_seg = V_out(idx_start:idx_end);
        V_sp_seg = V_sp(idx_start:idx_end);
        N_seg = length(t_seg);
        
        % 4. Now smooth the extracted segment
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
        V_sp_smooth = smoothdata(V_sp_seg, 'sgolay', windowPts);
        
        % 5. Initial value and settling band
        initial_val = V_out(idx_start - 1);
        step_size = final_val - initial_val;
        
        error_band = 0.05 * abs(step_size);
        upper_limit = final_val + error_band;
        lower_limit = final_val - error_band;
        
        % 6. Calculate Settling Time (BACKWARDS search - find last exit from band)
        is_outside_band = (V_out_smooth > upper_limit) | (V_out_smooth < lower_limit);
        
        % Find the LAST time the signal was outside the band
        last_outside_idx = find(is_outside_band, 1, 'last');
        
        if isempty(last_outside_idx)
            settling_time = 0;
            idx_settle = 1;
        else
            idx_settle = last_outside_idx + 1;
            if idx_settle > N_seg
                idx_settle = N_seg;
            end
            settling_time = t_seg(idx_settle);
        end
        
        % 7. Calculate Steady-State Error (textbook: final value)
        V_out_ss = V_out_smooth(end);
        ss_error_V = final_val - V_out_ss;
        ss_error_pct = 100 * abs(ss_error_V) / final_val;
        
        % 8. Plotting (smoothed only)
        plot(t_seg, V_out_smooth, 'Color', lineColors(i,:), 'LineWidth', 2, ...
            'DisplayName', sprintf('%.2f V (e_{ss} = %.2f%%)', final_val, ss_error_pct));
        
        % Small black dot at settling point
        plot(t_seg(idx_settle), V_out_smooth(idx_settle), 'o', ...
            'MarkerEdgeColor', 'k', 'MarkerFaceColor', 'k', ...
            'MarkerSize', 5, 'HandleVisibility', 'off');
        
        fprintf('File: %-20s | Settling Time: %.3f s | SS Error: %.2f%%\n', ...
            files{i}, settling_time, ss_error_pct);
        
    catch ME
        fprintf('Error processing %s: %s\n', files{i}, ME.message);
    end
end

% Settling bands
yline(2.16 * 1.05, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
yline(2.16 * 0.95, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
yline(4.07 * 1.05, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
yline(4.07 * 0.95, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
yline(6.25 * 1.05, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');
yline(6.25 * 0.95, '--', 'Color', [0.5 0.5 0.5], 'HandleVisibility', 'off');

% Setpoint lines (dotted, matching colors)
yline(2.16, ':', 'Color', lineColors(1,:), 'LineWidth', 1.5, 'HandleVisibility', 'off');
yline(4.07, ':', 'Color', lineColors(2,:), 'LineWidth', 1.5, 'HandleVisibility', 'off');
yline(6.25, ':', 'Color', lineColors(3,:), 'LineWidth', 1.5, 'HandleVisibility', 'off');

xlabel('Time (s)');
ylabel('Response (V)');
title('Measured Closed-Loop Response');
legend('Location', 'best');
set(gca, 'FontSize', 11);
xlim([0 3.5]);
hold off;