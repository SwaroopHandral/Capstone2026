%% Response plot script
%% - Plots each measurement in its own figure
%% - Overlays the three step responses in one figure
%% - Prints average steady-state error
clear; clc; close all;
%% File list
files = {
'2V_stepResponse.csv'
'4V_stepResponse.csv'
'6V_stepResponse.csv'
'reasonableLoad_27V.csv'
'reasonableLoad_42V.csv'
'reasonableLoad_6V.csv'
};
%% Plot titles
plotTitles = {
'2 V Setpoint -- Step Response'
'4 V Setpoint -- Step Response'
'6 V Setpoint -- Step Response'
'Reasonable Load -- 2.7 V Setpoint'
'Reasonable Load -- 4.2 V Setpoint'
'Reasonable Load -- 6.4 V Setpoint'
};
%% Flags for which files are step responses
isStepResponse = [true true true false false false];
%% Labels
feedbackLabel = 'Feedback';
setpointLabel = 'Setpoint';
%% Step-response legend values
stepVals = [2 4 6];
%% Overlay colors for the 3 step responses
stepColors = [
    0.0000    0.4470    0.7410
    0.8500    0.3250    0.0980
    0.9290    0.6940    0.1250
];
%% Steady-state settings
tStepStart = -1;
%% End-trim settings (step responses only)
nTrimEnd = 500;
%% Smoothing settings (plotting only)
useSmoothing = true;
smoothFrac   = 0.01;
minWindow    = 7;
%% Extra setpoint smoothing for 2.7 V reasonable load plot
sp27V_smoothFrac = 0.20;
%% Storage for overlay axis limits
overlayY = [];
overlayT = [];
%% Storage for reasonable load data
rlTimes        = {};
rlFBplot       = {};
rlSPplot       = {};
rlPctErrors    = {};
rlLabels       = {};
rlShortLabels  = {};
rlAvgEssV      = [];
rlAvgEssPctArr = [];
rlPeakT        = [];
rlPeakFB       = [];
rlPeakSP       = [];
rlPeakPct      = [];
%% Create overlay figure for step responses
overlayFig = figure('Name', 'Overlayed Step Responses', ...
'Position', [100 100 850 550]);
hold on; grid on; box on;
xlabel('Time (s)');
ylabel('Voltage (V)');
title('Overlayed Step Responses');
set(gca, 'FontSize', 12);
%% Main loop
stepIdx = 0;
for k = 1:numel(files)
    fileName  = files{k};
    plotTitle = plotTitles{k};
    data = readtable(fileName, 'VariableNamingRule', 'preserve');
    varNames = data.Properties.VariableNames;
    if ismember('Time (s)', varNames)
        t = data.('Time (s)');
    else
        error('Could not find "Time (s)" column in %s', fileName);
    end
    ch1 = getChannel(data, varNames, 'Channel 1 (V)', 'C1 DC (V)', fileName);
    ch2 = getChannel(data, varNames, 'Channel 2 (V)', 'C2 DC (V)', fileName);
    feedback = ch1;
    setpoint = ch2;

    if isStepResponse(k)
        t        = t(1:end-nTrimEnd);
        feedback = feedback(1:end-nTrimEnd);
        setpoint = setpoint(1:end-nTrimEnd);
    end
    fb_min  = min(feedback);
    fb_max  = max(feedback);
    fb_pp   = fb_max - fb_min;
    fb_mean = mean(feedback);
    sp_min  = min(setpoint);
    sp_max  = max(setpoint);
    sp_pp   = sp_max - sp_min;
    sp_mean = mean(setpoint);
    N = length(t);
    if isStepResponse(k)
        y0           = 0;
        yss_est      = mean(feedback(max(1, floor(0.9*N)) : N));
        target       = y0 + 0.632 * (yss_est - y0);
        idxAfterStep = find(t >= tStepStart);
        if yss_est > y0
            iRel = find(feedback(idxAfterStep) >= target, 1, 'first');
        else
            iRel = find(feedback(idxAfterStep) <= target, 1, 'first');
        end
        if isempty(iRel), iRel = 1; end
        idx_tau  = idxAfterStep(iRel);
        tau      = t(idx_tau) - tStepStart;
        t_settle = tStepStart + 5 * tau;
        idxSS    = find(t >= t_settle);
        if isempty(idxSS)
            warning('%s: 5-tau window not found, falling back to last 10%% of samples', fileName);
            idxSS = max(1, floor(0.9 * N)) : N;
        end
    else
        idxSS = 1:N;
        tau = NaN;
    end
    ess = setpoint(idxSS) - feedback(idxSS);
    avgEss = mean(ess);
    avgSetpointSS = mean(setpoint(idxSS));
    if abs(avgSetpointSS) > 1e-9
        avgEssPct = 100 * abs(avgEss) / abs(avgSetpointSS);
    else
        avgEssPct = NaN;
    end
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
        if k == 4
            spWindowPts = max(minWindow, round(sp27V_smoothFrac * N));
            if mod(spWindowPts, 2) == 0
                spWindowPts = spWindowPts + 1;
            end
            if spWindowPts >= N
                spWindowPts = N - 1;
                if mod(spWindowPts, 2) == 0
                    spWindowPts = spWindowPts - 1;
                end
            end
            setpoint_plot = smoothdata(setpoint, 'sgolay', spWindowPts);
        end
    else
        feedback_plot = feedback;
        setpoint_plot = setpoint;
    end

    if ~isStepResponse(k)
        rlTimes{end+1}        = t;
        rlFBplot{end+1}       = feedback_plot;
        rlSPplot{end+1}       = setpoint_plot;
        rlAvgEssV(end+1)      = avgEss;
        rlAvgEssPctArr(end+1) = avgEssPct;
        rlShortLabels{end+1}  = strrep(plotTitle, 'Reasonable Load -- ', '');
        rlLabels{end+1}       = plotTitle;
        pctError_plot = (setpoint_plot - feedback_plot) ./ abs(setpoint_plot) * 100;
        rlPctErrors{end+1} = pctError_plot;

        % Find worst-case (peak absolute) error point using smoothed signals
        errSigned = setpoint_plot - feedback_plot;
        errPct    = errSigned ./ abs(setpoint_plot) * 100;
        [~, iPk]  = max(abs(errPct));
        rlPeakT(end+1)   = t(iPk);
        rlPeakFB(end+1)  = feedback_plot(iPk);
        rlPeakSP(end+1)  = setpoint_plot(iPk);
        rlPeakPct(end+1) = errPct(iPk);
    else
        figure('Position', [100 100 750 525]);
        plot(t, feedback_plot, 'LineWidth', 1.8, 'DisplayName', feedbackLabel); hold on;
        plot(t, setpoint_plot, 'LineWidth', 1.8, 'DisplayName', setpointLabel);
        grid on; box on;
        xlabel('Time (s)');
        ylabel('Voltage (V)');
        title(plotTitle);
        legend('Location', 'best');
        set(gca, 'FontSize', 12);
        xlim([min(t), max(t)]);
        ymin = min([feedback_plot; setpoint_plot]);
        ymax = max([feedback_plot; setpoint_plot]);
        ypad = 0.05 * (ymax - ymin + eps);
        ylim([ymin - ypad, ymax + ypad]);
    end

    if isStepResponse(k)
        stepIdx = stepIdx + 1;
        figure(overlayFig);
        plot(t, feedback_plot, ...
            'LineWidth', 2.2, ...
            'Color', stepColors(stepIdx, :), ...
            'DisplayName', sprintf('Feedback: %d V step', stepVals(stepIdx)));
        plot(t, setpoint_plot, '--', ...
            'LineWidth', 1.4, ...
            'Color', stepColors(stepIdx, :), ...
            'HandleVisibility', 'off');
        overlayY = [overlayY; feedback_plot; setpoint_plot];
        overlayT = [overlayT; t];
    end

    fprintf('%s\n', plotTitle);
    fprintf('  %s mean = %.4f V\n', feedbackLabel, fb_mean);
    fprintf('  %s Vpp  = %.4f V\n', feedbackLabel, fb_pp);
    fprintf('  %s mean = %.4f V\n', setpointLabel, sp_mean);
    fprintf('  %s Vpp  = %.4f V\n', setpointLabel, sp_pp);
    if isStepResponse(k)
        fprintf('  Estimated tau = %.4f s  |  SS window start = %.4f s (5-tau)\n', tau, tStepStart + 5*tau);
        fprintf('  Avg steady-state error (Setpoint - Feedback, from 5-tau) = %.6f V\n', avgEss);
    else
        fprintf('  Avg steady-state error (Setpoint - Feedback, full record) = %.6f V\n', avgEss);
    end
    if ~isnan(avgEssPct)
        fprintf('  Avg steady-state error = %.3f %%\n\n', avgEssPct);
    else
        fprintf('  Avg steady-state error = undefined (steady-state setpoint near 0 V)\n\n');
    end
end

%% Final formatting for overlay figure
figure(overlayFig);
legend('Location', 'best');
if ~isempty(overlayT)
    xlim([min(overlayT), max(overlayT)]);
end
if ~isempty(overlayY)
    ymin = min(overlayY);
    ymax = max(overlayY);
    ypad = 0.05 * (ymax - ymin + eps);
    ylim([ymin - ypad, ymax + ypad]);
end

%% Combined reasonable load figure (single overlay plot)
if numel(rlTimes) == 3
    rlColors = [
        0.0000    0.4470    0.7410
        0.8500    0.3250    0.0980
        0.9290    0.6940    0.1250
    ];

    figure('Position', [100 100 850 550]);
    hold on; grid on; box on;

    hFB = plot(NaN, NaN, '-',  'Color', [0.3 0.3 0.3], 'LineWidth', 1.8, ...
        'DisplayName', feedbackLabel);
    hSP = plot(NaN, NaN, '--', 'Color', [0.3 0.3 0.3], 'LineWidth', 1.4, ...
        'DisplayName', setpointLabel);

    for j = 1:3
        plot(rlTimes{j}, rlFBplot{j}, '-', ...
            'LineWidth', 1.8, 'Color', rlColors(j, :), ...
            'HandleVisibility', 'off');
        plot(rlTimes{j}, rlSPplot{j}, '--', ...
            'LineWidth', 1.4, 'Color', rlColors(j, :), ...
            'HandleVisibility', 'off');
    end

    % Mark worst-case error points with labels
    for j = 1:3
        plot(rlPeakT(j), rlPeakFB(j), 'o', ...
            'MarkerSize', 7, 'LineWidth', 1.6, ...
            'MarkerEdgeColor', rlColors(j, :), ...
            'MarkerFaceColor', 'w', ...
            'HandleVisibility', 'off');
        text(rlPeakT(j) + 0.15, rlPeakFB(j) - 0.08, ...
            sprintf('%.2f%%', abs(rlPeakPct(j))), ...
            'FontSize', 9, 'Color', rlColors(j, :), ...
            'FontWeight', 'bold', ...
            'HorizontalAlignment', 'left', ...
            'VerticalAlignment', 'top');
    end

    xlabel('Time (s)');
    ylabel('Voltage (V)');
    title('Steady-State Error Under Reasonable Load');
    legend([hFB hSP], 'Location', 'east');
    set(gca, 'FontSize', 12);

    allV = [cat(1, rlFBplot{:}); cat(1, rlSPplot{:})];
    allT = cat(1, rlTimes{:});
    xlim([min(allT), max(allT)]);
    ymin_all = min(allV(:));
    ymax_all = max(allV(:));
    ypad_all = 0.08 * (ymax_all - ymin_all + eps);
    ylim([ymin_all - ypad_all, ymax_all + ypad_all]);

    % Annotate SS errors in the empty band between 4.2 V and 6.5 V traces
    annotLines = cell(3, 1);
    for j = 1:3
        annotLines{j} = sprintf('%s: %.4f V (%.2f%%)', ...
            rlShortLabels{j}, rlAvgEssV(j), rlAvgEssPctArr(j));
    end
    xL = xlim; yL = ylim;
    xAnnot = xL(1) + 0.02 * (xL(2) - xL(1));
    yAnnot = yL(1) + 0.72 * (yL(2) - yL(1));
    text(xAnnot, yAnnot, strjoin(annotLines, newline), ...
        'HorizontalAlignment', 'left', ...
        'VerticalAlignment', 'middle', 'FontSize', 10, ...
        'Color', [0.2 0.2 0.2], ...
        'BackgroundColor', [1 1 1 0.85], 'EdgeColor', [0.7 0.7 0.7]);
end

%% Averaged reasonable load percent error
if numel(rlTimes) > 0
    tMin = max(cellfun(@min, rlTimes));
    tMax = min(cellfun(@max, rlTimes));
    tCommon = linspace(tMin, tMax, 1000)';
    pctMat = zeros(1000, numel(rlTimes));
    for j = 1:numel(rlTimes)
        pctMat(:, j) = interp1(rlTimes{j}, rlPctErrors{j}, tCommon, 'linear');
    end
    avgPct = mean(pctMat, 2);
    stdPct = std(pctMat, 0, 2);
    figure('Position', [100 100 750 500]);
    patch([tCommon; flipud(tCommon)], ...
          [avgPct + stdPct; flipud(avgPct - stdPct)], ...
          [0.2 0.6 1.0], 'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
          'DisplayName', '\pm1 std dev');
    hold on;
    plot(tCommon, avgPct, 'b-', 'LineWidth', 2.0, 'DisplayName', 'Mean % error');
    yline(0, 'Color', [0.5 0.5 0.5], 'LineStyle', ':', 'LineWidth', 1.0, ...
        'HandleVisibility', 'off');
    grid on; box on;
    xlabel('Time (s)');
    ylabel('Error (%)');
    title('Reasonable Load -- Average Tracking Error (All Setpoints)', 'Interpreter', 'none');
    legend('Location', 'best');
    set(gca, 'FontSize', 12);
    xlim([tMin tMax]);
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