%==================================================
%		VOICE SCRAMBLER CODE
%		Henrique Cremonese de Morais, Aug. 2026
%
%		Based on "Principles of Communication" slide examples
%
%		The system used for the follow algorithm is:
%		m(t) --> x[2cos(20k)] --> HPF --> x[2cos(25k)] --> LPF --> y(t)
%
%       HPF = High-Pass Filter, fc = 20 kHz
%       LPF = Low-Pass Filter,  fc = 20 kHz
%==================================================

clear;
close all;
clc;

pkg load signal;

% 0. FAST FOURIER TRANSFORM (FFT)

function [f, magnitude] = spectrum(signal, Fs)

    N = length(signal);

    X = fft(signal);

    % Only positive frequencies
    N_half = floor(N/2);

    f = (0:N_half-1)' * Fs/N;

    magnitude = abs(X(1:N_half)) / N * 2;

endfunction

% 1. CHOOSE AUDIO FILE
% UI feature to make it easier to find file

fprintf('VOICE SCRAMBLER\n');

while true

	% Ask user to insert the file directory
	fprintf('E.g.: /home/user/Desktop/Audiotest.wav\n');
	audio_file = input('Enter the audio file: ', 's');

    % Verify if the file really exists
    if isfile(audio_file)
        break;
    else
		fprintf('Error: File not found. Please try again.\n\n');
    end
end

% Get the directory containing the audio file
[directory, ~, ~] = fileparts(audio_file);

fprintf('Selected file:\n%s\n\n', audio_file);

% 2. READ AUDIO

[input_audio, Fs_original] = audioread(audio_file);

fprintf('Original sampling frequency: %.0f Hz\n', Fs_original);
fprintf('Original number of samples: %d\n', length(input_audio));
fprintf('Original duration: %.2f seconds\n', length(input_audio) / Fs_original);

% 3. CONVERT STEREO TO MONO

if size(input_audio, 2) > 1
    input_audio = mean(input_audio, 2);
    fprintf('Stereo audio converted to mono.\n');
endif

% 4. NORMALISE INPUT

input_audio = input_audio / max(abs(input_audio));

% 5. RESAMPLE

Fs = Fs_original*2;
fprintf('Sampling frequency (Fs = 2*Fs_original: %.0f Hz\n', Fs);

audio = resample(input_audio, Fs, Fs_original);

t = (0:length(audio)-1)' / Fs;

fprintf('Processing sampling frequency: %.0f Hz\n', Fs);
fprintf('New number of samples: %d\n\n', length(audio));

% 6 DETERMINE RELEVANT AUDIO BANDWIDTH
%
% Define the relevant bandwidth as the frequency containing 99% of the total spectral energy
% It should minimise the losses during the signal scrambling
% DEVELOPMENT NOTE: B fixes the second carrier (fc2 = fc1 + B), which is what makes the mirroring f -> B-f self-inverse
% B must therefore be IDENTICAL on the scrambling pass and the de-scrambling pass. The scrambled signal's spectral shape
% differed from the original's, so recomputing B adaptively gave me a different value. Therefore, here follows the fix:
% Fix: cache B next to the audio file and reuse it automatically when this same file is processed again

[in_dir, in_name, ~] = fileparts(audio_file);
B_file = fullfile(in_dir, [in_name '_B.mat']);

if isfile(B_file)

    load(B_file, 'B');
    fprintf('Found bandwidth used previously for this file (%.2f kHz).\n', B/1000);
    fprintf('Reusing it so the two mixers stay perfectly consistent.\n\n');

else

    [f_audio, mag_audio] = spectrum(audio, Fs);

    energy = mag_audio.^2;

    cumulative_energy = cumsum(energy);

    total_energy = cumulative_energy(end);

    index = find(cumulative_energy >= 0.99 * total_energy, 1);

    B = f_audio(index);

    fprintf('Relevant bandwidth (99%% spectral energy): %.2f Hz\n', B);
    fprintf('Relevant bandwidth: %.2f kHz\n\n', B/1000);

end

if B > Fs/8
    warning('Signal bandwidth too wide for this Fs, some aliasing is unavoidable.');
end

% 7. FIRST MIXER
%
% x1(t) = m(t) * 2cos(2*pi*20k*t)

fc1 = Fs/8;

carrier1 = 2*cos(2*pi*fc1*t);

x1 = audio .* carrier1;

% 8. FIRST FILTER - FPA
%
% High-pass filter
%
% Passes frequencies ABOVE 20 kHz

fc_fpa = fc1;

filter_order = 6;

[b_fpa, a_fpa] = butter(filter_order, fc_fpa/(Fs/2), 'high');

x2 = filtfilt(b_fpa, a_fpa, x1);

% 9. SECOND MIXER
%
% x3(t) = x2(t) * 2cos(2*pi*25k*t)

fc2 = fc1 + B;

carrier2 = 2*cos(2*pi*fc2*t);

x3 = x2 .* carrier2;

% 10. SECOND FILTER - FPB
%
% Low-pass filter
%
% Passes frequencies BELOW 20 kHz

fc_fpb = fc1;

[b_fpb, a_fpb] = butter(filter_order, fc_fpb/(Fs/2), 'low');

y = filtfilt(b_fpb, a_fpb, x3);

% 11. NORMALISE OUTPUT

y = y / max(abs(y));

% 12. SAVE SCRAMBLED AUDIO
%
% For a normal listenable WAV, we resample the final result
% back to the original sampling frequency.

y_listen = resample(y, Fs_original, Fs);

% Prevent tiny numerical overshoots
y_listen = y_listen / max(abs(y_listen));

output_file = fullfile(directory, 'scrambled.wav');

audiowrite(output_file, y_listen, Fs_original);

% Cache the bandwidth used for this run, so that running this same script on
[out_dir, out_name, ~] = fileparts(output_file);
save('-mat', fullfile(out_dir, [out_name '_B.mat']), 'B');

fprintf('Scrambled audio saved to:\n%s\n\n', output_file);

% 13. CALCULATE SPECTRUM

[f_audio, mag_audio] = spectrum(audio, Fs);
[f_x1,    mag_x1]    = spectrum(x1, Fs);
[f_x2,    mag_x2]    = spectrum(x2, Fs);
[f_x3,    mag_x3]    = spectrum(x3, Fs);
[f_y,     mag_y]     = spectrum(y, Fs);

% 14. TIME-DOMAIN PLOTS

% We don't need to display the entire recording because
% individual speech samples become impossible to see.
%
% Display the first 50 ms.

display_time = 0.05;

N_display = min(round(display_time * Fs), length(audio));


figure('Name', 'Voice Scrambler - Time Domain');


subplot(5,1,1);
plot(t(1:N_display), audio(1:N_display));
grid on;
xlabel('Time (s)');
ylabel('Amplitude');
title('Original audio m(t)');


subplot(5,1,2);
plot(t(1:N_display), x1(1:N_display));
grid on;
xlabel('Time (s)');
ylabel('Amplitude');
title('After first mixer x_1(t)');


subplot(5,1,3);
plot(t(1:N_display), x2(1:N_display));
grid on;
xlabel('Time (s)');
ylabel('Amplitude');
title('After FPA x_2(t)');


subplot(5,1,4);
plot(t(1:N_display), x3(1:N_display));
grid on;
xlabel('Time (s)');
ylabel('Amplitude');
title('After second mixer x_3(t)');


subplot(5,1,5);
plot(t(1:N_display), y(1:N_display));
grid on;
xlabel('Time (s)');
ylabel('Amplitude');
title('Final scrambled signal y(t)');

% 15. FREQUENCY-DOMAIN PLOTS

figure('Name', 'Voice Scrambler - Frequency Domain');


subplot(5,1,1);
plot(f_audio/1000, mag_audio);
grid on;
xlim([0 50]);
xlabel('Frequency (kHz)');
ylabel('|M(f)|');
title('Original spectrum');


subplot(5,1,2);
plot(f_x1/1000, mag_x1);
grid on;
xlim([0 60]);
xlabel('Frequency (kHz)');
ylabel('|X_1(f)|');
title('After first mixer');


subplot(5,1,3);
plot(f_x2/1000, mag_x2);
grid on;
xlim([0 60]);
xlabel('Frequency (kHz)');
ylabel('|X_2(f)|');
title('After FPA (20 kHz high-pass)');


subplot(5,1,4);
plot(f_x3/1000, mag_x3);
grid on;
xlim([0 80]);
xlabel('Frequency (kHz)');
ylabel('|X_3(f)|');
title('After second mixer');


subplot(5,1,5);
plot(f_y/1000, mag_y);
grid on;
xlim([0 30]);
xlabel('Frequency (kHz)');
ylabel('|Y(f)|');
title('Final scrambled spectrum');

% 16. SAVE TIME-DOMAIN FIGURE

time_plot_file = fullfile(directory, 'scrambler_time_domain.png');

print(time_plot_file, '-dpng', '-r150');

% 17. SAVE FREQUENCY-DOMAIN FIGURE

frequency_plot_file = fullfile(directory, 'scrambler_frequency_domain.png');

print(frequency_plot_file, '-dpng', '-r150');

% 18. OUTPUT MESSAGE

fprintf('SCRAMBLING FINISHED!\n');

fprintf('Input:\n');
fprintf('%s\n\n', audio_file);

fprintf('Output audio:\n');
fprintf('%s\n\n', output_file);

fprintf('Time-domain plot:\n');
fprintf('%s\n\n', time_plot_file);

fprintf('Frequency-domain plot:\n');
fprintf('%s\n\n', frequency_plot_file);

fprintf('Processing Fs: %.0f Hz\n', Fs);
fprintf('Output Fs: %.0f Hz\n', Fs_original);

fprintf('\nYou can now play scrambled.wav.\n');
