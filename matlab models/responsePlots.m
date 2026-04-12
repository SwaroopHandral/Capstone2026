%% Response plot script
%% - Overlays the three step responses in one figure
%% - Prints average steady-state error

clear; clc; close all;

%% File list
files = {
    '2V_stepResponse.csv'
    '4V_stepResponse.csv'
    '6V_stepResponse.csv'
};

%% Plot titles
plotTitles = {
    '2 V Setpoint -- Step Response'
    '4 V Setpoint -- Step Response'
    '6 V Setpoint -- Step Response'
};

%% Labels
feedbackLabel = 'Feedback';
setpointLabel = 'Setpoint';

%% Step-response legend values
stepVals = [2.15, 4.06, 6.25];

%% Overlay colors for the 3 step responses
stepColors = [
    0.0000    0.4470    0.7410   % blue
    0.8500    0.3250    0.0980   % orange
    0.9290    0.6940    0.1250   % yellow
];

%% Steady-state settings
ssFraction = 0.10;   % last 10% of samples used for SS error

%% Smoothing settings (plotting only)
useSmoothing = true;
smoothFrac   = 0.01; % 1% of total samples
minWindow    = 7;    % minimum smoothing window

%% Storage for overlay axis limits
overlayY = [];
overlayT = [];

%% Create overlay figure for step responses
overlayFig = figure('Name', 'Overlayed Step Responses', ...
    'Position', [100 100 850 550]);
hold on;
grid on;
box on;
xlabel('Time (s)');
ylabel('Voltage (V)');
title('Overlayed Step Responses');
set(gca, 'FontSize', 12);

%% Main loop
for k = 1:numel(files)
    fileName  = files{k};
    plotTitle = plotTitles{k};

    % Read CSV
    data = readtable(fileName, 'VariableNamingRule', 'preserve');
    varNames = data.Properties.VariableNames;

    % Time
    if ismember('Time (s)', varNames)
        t = data.('Time (s)');
    else
        error('Could not find "Time (s)" column in %s', fileName);
    end

    % Channels
    ch1 = getChannel(data, varNames, 'Channel 1 (V)', 'C1 DC (V)', fileName);
    ch2 = getChannel(data, varNames, 'Channel 2 (V)', 'C2 DC (V)', fileName);

    % Interpret channels
    feedback = ch1;
    setpoint = ch2;

    % Basic measurements from raw data
    fb_min  = min(feedback);
    fb_max  = max(feedback);
    fb_pp   = fb_max - fb_min;
    fb_mean = mean(feedback);

    sp_min  = min(setpoint);
    sp_max  = max(setpoint);
    sp_pp   = sp_max - sp_min;
    sp_mean = mean(setpoint);

    % Steady-state region = last ssFraction of samples
    N = length(t);
    idxSS = max(1, floor((1 - ssFraction) * N)) : N;

    % Steady-state error = setpoint - feedback
    ess = setpoint(idxSS) - feedback(idxSS);
    avgEss = mean(ess);

    % Average steady-state setpoint and percent error
    avgSetpointSS = mean(setpoint(idxSS));
    if abs(avgSetpointSS) > 1e-9
        avgEssPct = 100 * abs(avgEss) / abs(avgSetpointSS);
    else
        avgEssPct = NaN;
    end

    % Smoothing for plotting only
    if useSmoothing
        windowPts = max(minWindow, round(smoothFrac * N));

        if mod(windowPts, 2) == 0
            windowPts = windowPts + 1;
        end

        if windowPts >= N
            windowPts = N - 1;
            if mod(windowPts, 2) == 0
                windowPts = windowPts - 1;
            end
        end

        feedback_plot = smoothdata(feedback, 'sgolay', windowPts);
        setpoint_plot = smoothdata(setpoint, 'sgolay', windowPts);
    else
        feedback_plot = feedback;
        setpoint_plot = setpoint;
    end

    %% Plot on overlay figure
    plot(t, feedback_plot, ...
        'LineWidth', 2.2, ...
        'Color', stepColors(k, :), ...
        'DisplayName', sprintf('Feedback: %.2f V step', stepVals(k)));

    plot(t, setpoint_plot, '--', ...
        'LineWidth', 1.4, ...
        'Color', stepColors(k, :), ...
        'HandleVisibility', 'off');

    overlayY = [overlayY; feedback_plot; setpoint_plot];
    overlayT = [overlayT; t];

    %% Print results
    fprintf('%s\n', plotTitle);
    fprintf('  %s mean = %.4f V\n', feedbackLabel, fb_mean);
    fprintf('  %s Vpp  = %.4f V\n', feedbackLabel, fb_pp);
    fprintf('  %s mean = %.4f V\n', setpointLabel, sp_mean);
    fprintf('  %s Vpp  = %.4f V\n', setpointLabel, sp_pp);
    fprintf('  Avg steady-state error (Setpoint - Feedback, last %.0f%%) = %.6f V\n', ...
        ssFraction * 100, avgEss);

    if ~isnan(avgEssPct)
        fprintf('  Avg steady-state error = %.3f %%\n\n', avgEssPct);
    else
        fprintf('  Avg steady-state error = undefined (steady-state setpoint near 0 V)\n\n');
    end
end

%% Final formatting for overlay figure
legend('Location', 'best');

xlim([min(overlayT), 2]);

if ~isempty(overlayY)
    ymin = min(overlayY);
    ymax = max(overlayY);
    ypad = 0.05 * (ymax - ymin + eps);
    ylim([ymin - ypad, ymax + ypad]);
end

%% Local function for robust channel detection
function ch = getChannel(data, varNames, nameA, nameB, fileName)
    if ismember(nameA, varNames)
        ch = data.(nameA);
    elseif ismember(nameB, varNames)
        ch = data.(nameB);
    else
        error('Could not find "%s" or "%s" in %s', nameA, nameB, fileName);
    end
end