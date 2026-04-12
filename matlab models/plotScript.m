clear; clc; close all;
s = tf('s');
%% ================= MOTOR MODEL & CONTROLLER =================
% Motor transfer function
Gm = 0.257 / ((1.22e-6)*s^2 + (1.04e-3)*s + 0.07);
% F/V transfer function
Rfv = 122000;
Cfv = 0.1e-6;
Gfv = 1 / (1 + s*Rfv*Cfv);
% PI gains
Kp = 1.33;
Ki = 27.52;
%% ================= BUILD SYSTEM =================
P = Gm * Gfv;          % plant
C = Kp + Ki/s;         % PI controller
L = C * P;             % open-loop transfer function
T = feedback(L,1);     % closed-loop transfer function
%% ================= KEY PARAMETERS =================
wz = Ki / Kp;          % PI zero (rad/s)
fz = wz / (2*pi);      % PI zero (Hz)
[GM, PM, Wcg, Wcp] = margin(L);
fc = Wcp / (2*pi);
fprintf('\n=========== KEY RESULTS ===========\n');
fprintf('PI zero frequency      = %.4f Hz\n', fz);
fprintf('PI zero location       = %.4f rad/s\n', wz);
if ~isnan(Wcp) && Wcp > 0
    fprintf('Crossover frequency    = %.4f Hz\n', fc);
    fprintf('Crossover frequency    = %.4f rad/s\n', Wcp);
else
    fprintf('Crossover frequency    = not found\n');
end
fprintf('Phase margin           = %.2f deg\n', PM);
%% ================= STEP RESPONSE METRICS =================
info     = stepinfo(T);
dcT      = dcgain(T);
ess_step = abs(1 - dcT);
fprintf('\n====== PROJECTED CLOSED-LOOP RESPONSE ======\n');
fprintf('Overshoot              = %.3f %%\n',   info.Overshoot);
fprintf('Settling time          = %.6f s\n',    info.SettlingTime);
fprintf('Rise time              = %.6f s\n',    info.RiseTime);
fprintf('Peak time              = %.6f s\n',    info.PeakTime);
fprintf('Projected SS error     = %.6f (unit-step)\n', ess_step);
fprintf('Closed-loop DC gain    = %.6f\n',      dcT);
%% ================= PROJECTED STEP RESPONSE DATA =================
[y_proj, t_proj] = step(T);
y_proj_norm = y_proj / dcT;
t_proj_settle = info.SettlingTime;
t_proj_normed = t_proj / t_proj_settle;
%% ================= RESPONSE PROCESSING SETTINGS =================
files = {
'2V_stepResponse.csv'
'4V_stepResponse.csv'
'6V_stepResponse.csv'
'reasonableLoad_27V.csv'
'reasonableLoad_42V.csv'
'reasonableLoad_6V.csv'
};
plotTitles = {
'2 V Setpoint -- Step Response'
'4 V Setpoint -- Step Response'
'6 V Setpoint -- Step Response'
'Reasonable Load -- 2.7 V Setpoint'
'Reasonable Load -- 4.2 V Setpoint'
'Reasonable Load -- 6.5 V Setpoint'
};
isStepResponse = [true true true false false false];
feedbackLabel = 'Feedback';
setpointLabel = 'Setpoint';
stepVals   = [2 4 6];
stepColors = [
    0.0000    0.4470    0.7410   % blue
    0.8500    0.3250    0.0980   % orange
    0.9290    0.6940    0.1250   % yellow
];
ssFraction       = 0.10;   % last 10% of samples for SS error (reasonable load only)
nTrimEnd         = 50;     % samples to drop from the end to remove capture artifacts
useSmoothing     = true;
smoothFrac       = 0.01;   % 1% of total samples
minWindow        = 7;      % minimum smoothing window
sp27V_smoothFrac = 0.20;   % extra setpoint smoothing for 2.7 V reasonable load
%% ================= STORAGE =================
rlTimes        = {};
rlFBplot       = {};
rlSPplot       = {};
rlPctErrors    = {};
rlLabels       = {};
rlShortLabels  = {};
rlAvgEssV      = [];
rlAvgEssPctArr = [];
%% ================= PROJECTED vs. ACTUAL OVERLAY FIGURE =================
overlayFig = figure('Name', 'Projected vs. Actual Step Responses', ...
'Position', [100 100 850 550]);
hold on; grid on; box on;
xlabel('Normalized Time (t / t_{settling})');
ylabel('Normalized Response (fraction of setpoint)');
title('Projected vs. Actual Closed-Loop Step Responses (Time-Normalized)');
set(gca, 'FontSize', 12);
% Plot projected response (black dashed)
plot(t_proj_normed, y_proj_norm, 'k--', 'LineWidth', 2.5, ...
'DisplayName', sprintf('Projected (t_s = %.4f s)', t_proj_settle));
%% ================= MAIN LOOP =================
stepIdx = 0;
for k = 1:numel(files)
    fileName  = files{k};
    plotTitle = plotTitles{k};
% Read CSV
    data     = readtable(fileName, 'VariableNamingRule', 'preserve');
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
    feedback = ch1;
    setpoint = ch2;
% Trim end artifacts (step responses only)
if isStepResponse(k)
        t        = t(1:end-nTrimEnd);
        feedback = feedback(1:end-nTrimEnd);
        setpoint = setpoint(1:end-nTrimEnd);
end
% Basic measurements from raw data
    fb_min  = min(feedback);
    fb_max  = max(feedback);
    fb_pp   = fb_max - fb_min;
    fb_mean = mean(feedback);
    sp_min  = min(setpoint);
    sp_max  = max(setpoint);
    sp_pp   = sp_max - sp_min;
    sp_mean = mean(setpoint);
    N = length(t);
% ── Detect step-on region for step responses ──
if isStepResponse(k)
        sp_peak  = max(setpoint);
        sp_thresh = 0.5 * sp_peak;
        idxOn    = find(setpoint > sp_thresh);
        tStepOn  = t(idxOn(1));      % step onset time
        tStepOff = t(idxOn(end));    % step offset time
% Baseline = mean feedback before step onset
        idxBefore = find(t < tStepOn);
if isempty(idxBefore)
            baseline = 0;
else
            baseline = mean(feedback(idxBefore));
end
% Steady-state region = last 50% of the on-period
        tSSstart = tStepOn + 0.5 * (tStepOff - tStepOn);
        idxSS    = find(t >= tSSstart & t <= tStepOff);
else
        idxSS = max(1, floor((1 - ssFraction) * N)) : N;
end
% Steady-state error = setpoint - feedback
    ess           = setpoint(idxSS) - feedback(idxSS);
    avgEss        = mean(ess);
    avgSetpointSS = mean(setpoint(idxSS));
if abs(avgSetpointSS) > 1e-9
        avgEssPct = 100 * abs(avgEss) / abs(avgSetpointSS);
else
        avgEssPct = NaN;
end
% Smoothing for plotting only
if useSmoothing
        windowPts = max(minWindow, round(smoothFrac * N));
if mod(windowPts, 2) == 0, windowPts = windowPts + 1; end
if windowPts >= N
            windowPts = N - 1;
if mod(windowPts, 2) == 0, windowPts = windowPts - 1; end
end
        feedback_plot = smoothdata(feedback, 'sgolay', windowPts);
        setpoint_plot = smoothdata(setpoint, 'sgolay', windowPts);
if k == 4   % extra setpoint smoothing for 2.7 V reasonable load
            spWindowPts = max(minWindow, round(sp27V_smoothFrac * N));
if mod(spWindowPts, 2) == 0, spWindowPts = spWindowPts + 1; end
if spWindowPts >= N
                spWindowPts = N - 1;
if mod(spWindowPts, 2) == 0, spWindowPts = spWindowPts - 1; end
end
            setpoint_plot = smoothdata(setpoint, 'sgolay', spWindowPts);
end
else
        feedback_plot = feedback;
        setpoint_plot = setpoint;
end
% ── Reasonable load: store for combined figure ──
if ~isStepResponse(k)
        rlTimes{end+1}        = t;
        rlFBplot{end+1}       = feedback_plot;
        rlSPplot{end+1}       = setpoint_plot;
        rlAvgEssV(end+1)      = avgEss;
        rlAvgEssPctArr(end+1) = avgEssPct;
        rlShortLabels{end+1}  = strrep(plotTitle, 'Reasonable Load -- ', '');
        rlLabels{end+1}       = plotTitle;
        pctError_plot         = (setpoint_plot - feedback_plot) ./ abs(setpoint_plot) * 100;
        rlPctErrors{end+1}    = pctError_plot;
end
% ── Normalize actual step responses and add to overlay ──
if isStepResponse(k)
        stepIdx = stepIdx + 1;
% Steady-state setpoint (denominator for normalization)
        sp_ss_val = mean(setpoint_plot(idxSS));
% Normalize amplitude: 0 = pre-step baseline, 1 = setpoint level
if abs(sp_ss_val - baseline) > 1e-9
            fb_norm = (feedback_plot - baseline) / (sp_ss_val - baseline);
else
            fb_norm = feedback_plot;
end
% Shift time so step onset is at t = 0
        t_shifted = t - tStepOn;
% Only plot the on-period
        idxPlot = t_shifted >= 0 & t <= tStepOff;
% Compute settling time for this actual response (2% band)
        fb_norm_on = fb_norm(idxPlot);
        t_shift_on = t_shifted(idxPlot);
        settled = abs(fb_norm_on - 1.0) < 0.02;
        iSettle = find(settled, 1, 'first');
% Walk forward to make sure it stays settled
if ~isempty(iSettle)
            for ii = iSettle:length(settled)
if ~settled(ii)
                    iSettle = [];
break;
end
end
end
if isempty(iSettle)
            t_actual_settle = t_shift_on(end) * 0.5;
else
            t_actual_settle = t_shift_on(iSettle);
end
% Normalize time by settling time
        t_normed = t_shifted / t_actual_settle;
        figure(overlayFig);
        plot(t_normed(idxPlot), fb_norm(idxPlot), ...
'LineWidth', 2.0, ...
'Color',     stepColors(stepIdx, :), ...
'DisplayName', sprintf('Actual: %d V step (t_s = %.2f s)', stepVals(stepIdx), t_actual_settle));
end
% ── Print results ──
    fprintf('%s\n', plotTitle);
    fprintf('  %s mean = %.4f V\n', feedbackLabel, fb_mean);
    fprintf('  %s Vpp  = %.4f V\n', feedbackLabel, fb_pp);
    fprintf('  %s mean = %.4f V\n', setpointLabel, sp_mean);
    fprintf('  %s Vpp  = %.4f V\n', setpointLabel, sp_pp);
if isStepResponse(k)
        fprintf('  Step on  = %.4f s  |  Step off = %.4f s\n', tStepOn, tStepOff);
        fprintf('  Avg steady-state error (from second half of on-period) = %.6f V\n', avgEss);
else
        fprintf('  Avg steady-state error (Setpoint - Feedback, last %.0f%%) = %.6f V\n', ...
            ssFraction * 100, avgEss);
end
if ~isnan(avgEssPct)
        fprintf('  Avg steady-state error = %.3f %%\n\n', avgEssPct);
else
        fprintf('  Avg steady-state error = undefined (steady-state setpoint near 0 V)\n\n');
end
end
%% ================= OVERLAY FIGURE FORMATTING =================
figure(overlayFig);
yline(1.0, ':', 'Color', [0.4 0.4 0.4], 'LineWidth', 1.2, 'HandleVisibility', 'off');
legend('Location', 'northeast');
xlim([0, 3]);
%% ================= COMBINED REASONABLE LOAD FIGURE (commented out) =================
% if numel(rlTimes) == 3
%     allV     = [cat(1, rlFBplot{:}); cat(1, rlSPplot{:})];
%     ymin_all = min(allV(:));
%     ymax_all = max(allV(:));
%     ypad_all = 0.12 * (ymax_all - ymin_all + eps);
%     figure('Position', [100 100 800 700]);
%     axRL = gobjects(3, 1);
%     for j = 1:3
%         axRL(j) = subplot(3, 1, j);
%         plot(rlTimes{j}, rlFBplot{j}, 'b-',  'LineWidth', 1.8, 'DisplayName', feedbackLabel); hold on;
%         plot(rlTimes{j}, rlSPplot{j}, 'r--', 'LineWidth', 1.8, 'DisplayName', setpointLabel);
%         grid on; box on;
%         ylabel('Voltage (V)');
%         title(rlShortLabels{j}, 'Interpreter', 'none');
%         set(axRL(j), 'FontSize', 12);
%         xlim([min(rlTimes{j}), max(rlTimes{j})]);
%         ylim([ymin_all - ypad_all, ymax_all + ypad_all]);
%         text(0.98, 0.95, sprintf('SS error: %.4f V (%.2f%%)', rlAvgEssV(j), rlAvgEssPctArr(j)), ...
%             'Units', 'normalized', 'HorizontalAlignment', 'right', ...
%             'VerticalAlignment', 'top', 'FontSize', 10, 'Color', [0.2 0.2 0.2]);
%         if j == 1, legend('Location', 'southeast'); end
%         if j < 3,  set(axRL(j), 'XTickLabel', {}); end
%     end
%     xlabel('Time (s)');
%     linkaxes(axRL, 'x');
%     sgtitle('Reasonable Load -- Tracking Performance', 'FontSize', 13, 'FontWeight', 'bold');
% end
%% ================= AVERAGED REASONABLE LOAD ERROR (commented out) =================
% if numel(rlTimes) > 0
%     tMin    = max(cellfun(@min, rlTimes));
%     tMax    = min(cellfun(@max, rlTimes));
%     tCommon = linspace(tMin, tMax, 1000)';
%     pctMat  = zeros(1000, numel(rlTimes));
%     for j = 1:numel(rlTimes)
%         pctMat(:, j) = interp1(rlTimes{j}, rlPctErrors{j}, tCommon, 'linear');
%     end
%     avgPct = mean(pctMat, 2);
%     stdPct = std(pctMat, 0, 2);
%     figure('Position', [100 100 750 500]);
%     patch([tCommon; flipud(tCommon)], ...
%           [avgPct + stdPct; flipud(avgPct - stdPct)], ...
%           [0.2 0.6 1.0], 'FaceAlpha', 0.2, 'EdgeColor', 'none', ...
%           'DisplayName', '\pm1 std dev');
%     hold on;
%     plot(tCommon, avgPct, 'b-', 'LineWidth', 2.0, 'DisplayName', 'Mean % error');
%     yline(0, 'Color', [0.5 0.5 0.5], 'LineStyle', ':', 'LineWidth', 1.0, ...
%         'HandleVisibility', 'off');
%     grid on; box on;
%     xlabel('Time (s)'); ylabel('Error (%)');
%     title('Reasonable Load -- Average Tracking Error (All Setpoints)', 'Interpreter', 'none');
%     legend('Location', 'best');
%     set(gca, 'FontSize', 12);
%     xlim([tMin tMax]);
% end
%% ================= LOCAL FUNCTIONS =================
function ch = getChannel(data, varNames, nameA, nameB, fileName)
if ismember(nameA, varNames)
        ch = data.(nameA);
elseif ismember(nameB, varNames)
        ch = data.(nameB);
else
        error('Could not find "%s" or "%s" in %s', nameA, nameB, fileName);
end
end
