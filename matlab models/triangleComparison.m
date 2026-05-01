%% Compare pre-boost and post-boost triangle waveforms
clear; clc; close all;

% File names
filePre  = 'triangleWavea-preBoost.csv';
filePost = 'triangleWave_postBoost.csv';

% Read CSVs
pre  = readtable(filePre,  'VariableNamingRule','preserve');
post = readtable(filePost, 'VariableNamingRule','preserve');

% Extract time and waveform data
tPre   = pre.('Time (s)');
vPre   = pre.('Channel 1 (V)');

tPost  = post.('Time (s)');
vPost  = post.('Channel 1 (V)');

%% Basic measurements
pre_min  = min(vPre);
pre_max  = max(vPre);
pre_pp   = pre_max - pre_min;
pre_mean = mean(vPre);

post_min  = min(vPost);
post_max  = max(vPost);
post_pp   = post_max - post_min;
post_mean = mean(vPost);

fprintf('Pre-boost waveform:\n');
fprintf('  Min   = %.4f V\n', pre_min);
fprintf('  Max   = %.4f V\n', pre_max);
fprintf('  Vpp   = %.4f V\n', pre_pp);
fprintf('  Mean  = %.4f V\n\n', pre_mean);

fprintf('Post-boost waveform:\n');
fprintf('  Min   = %.4f V\n', post_min);
fprintf('  Max   = %.4f V\n', post_max);
fprintf('  Vpp   = %.4f V\n', post_pp);
fprintf('  Mean  = %.4f V\n\n', post_mean);

fprintf('Change from pre to post:\n');
fprintf('  Gain in Vpp   = %.4f x\n', post_pp / pre_pp);
fprintf('  DC shift      = %.4f V\n\n', post_mean - pre_mean);

%% Overlay plot only
figure('Position',[100 100 1400 500]);
plot(tPre, vPre); hold on;
plot(tPost, vPost);
grid on; box on;
xlabel('Time (s)');
ylabel('Voltage (V)');
title('Pre-Boost vs Post-Boost Triangle Waveforms');
legend('Pre-Boost','Post-Boost','Location','best');
set(gca,'FontSize',12);

% Zoom in so the waveform shapes are easier to see
tWindow = 0.0003;   % adjust as needed
xlim([tPre(1), tPre(1) + tWindow]);

% Keep full DC offset so boosted waveform appears larger and higher
ymin = min([vPre; vPost]);
ymax = max([vPre; vPost]);
ylim([ymin - 0.2, ymax + 0.2]);