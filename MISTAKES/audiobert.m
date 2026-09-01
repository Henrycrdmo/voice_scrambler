clear;
close all;
clc;

pkg load signal;

[file_name, file_path] = uigetfile({'*.wav;*.mp3;*.flac;*.ogg', 'Audio files'; '*.*', 'All files'}, 'Select your voice recording');

if isequal(file_name, 0)
    error('No audio selected.');
endif

input_file = fullfile(file_path, file_name);

fprintf('\nInput file:\n%s\n', input_file);

[x, Fs_original] = audioread(input_file);

fprintf('Original Fs: %.0f Hz\n', Fs_original);

if size(x, 2) > 1
    x = mean(x, 2);
    fprintf('Stereo -> mono\n');
endif

x = x - mean(x);
x = x / max(abs(x));
Fs = 48000;
x = resample(x, Fs, Fs_original);
N = length(x);

fprintf('Processing Fs: %.0f Hz\n', Fs);
fprintf('Samples: %d\n', N);
fprintf('Duration: %.2f s\n', N/Fs);

voice_bandwidth = 5000;

[b_voice, a_voice] = butter(6,voice_bandwidth/(Fs/2),'low');

voice = filtfilt(b_voice, a_voice, x);

voice = voice / max(abs(voice));
X = fft(voice);

f = (0:N-1)' * Fs/N;
f(f >= Fs/2) = f(f >= Fs/2) - Fs;

split_frequency = 2500;
Y = X;

positive = find(f >= 0 & f <= voice_bandwidth);

low_positive = positive(  f(positive) < split_frequency);

high_positive = positive(f(positive) >= split_frequency & f(positive) <= voice_bandwidth);

Nswap = min(length(low_positive), length(high_positive));

low_positive = low_positive(1:Nswap);
high_positive = high_positive(1:Nswap);

temp = X(low_positive);

Y(low_positive) = X(high_positive);
Y(high_positive) = temp;

negative = find(f < 0 & f >= -voice_bandwidth);

low_negative = negative(f(negative) > -split_frequency);

high_negative = negative(f(negative) <= -split_frequency &f(negative) >= -voice_bandwidth);


Nswap_negative = min(length(low_negative), length(high_negative));


low_negative = low_negative(end-Nswap_negative+1:end);
high_negative = high_negative(end-Nswap_negative+1:end);
temp = X(low_negative);
Y(low_negative) = X(high_negative);
Y(high_negative) = temp;

scrambled = real(ifft(Y));

scrambled = scrambled / max(abs(scrambled));
S = fft(scrambled);

recovered_spectrum = S;
temp = S(low_positive);

recovered_spectrum(low_positive) = S(high_positive);

recovered_spectrum(high_positive) = temp;

temp = S(low_negative);

recovered_spectrum(low_negative) =S(high_negative);
recovered_spectrum(high_negative) = temp;

recovered = real(ifft(recovered_spectrum));
recovered = recovered / max(abs(recovered));

error_signal = voice - recovered;
MSE = mean(error_signal.^2)
maximum_error = max(abs(error_signal))

scrambled_file = fullfile(file_path, 'scrambled_two_band.wav')
recovered_file = fullfile(file_path, 'recovered_two_band.wav')


audiowrite(scrambled_file, scrambled, Fs);

audiowrite(recovered_file,  recovered, Fs);

function [freq, magnitude] = spectrum(signal, Fs)
    N = length(signal);
    X = fft(signal);
    X = fftshift(X);
    freq = (-N/2:N/2-1)' * Fs/N;
    magnitude = abs(X) / N;
endfunction

[f_original, M_original] = spectrum(voice, Fs);

[f_scrambled, M_scrambled] = spectrum(scrambled, Fs);

[f_recovered, M_recovered] = spectrum(recovered, Fs);


display_time = 0.05;

N_display = min(round(display_time * Fs), N);

t = (0:N-1)' / Fs;


figure('Name', 'Two-Band Scrambler - Time Domain');


subplot(3,1,1);

plot(t(1:N_display), voice(1:N_display));

grid on;

xlabel('Time (s)');
ylabel('Amplitude');

title('Original voice');


subplot(3,1,2);

plot(t(1:N_display), scrambled(1:N_display));

grid on;
xlabel('Time (s)');
ylabel('Amplitude');
title('Scrambled voice');
subplot(3,1,3);
plot(t(1:N_display), recovered(1:N_display));
grid on;
xlabel('Time (s)');
ylabel('Amplitude');
title('Recovered voice');

figure('Name', 'Two-Band Scrambler Frequency Domain');
subplot(3,1,1);

plot(f_original/1000, M_original);
grid on;
xlim([-7 7]);
xlabel('Frequency (kHz)');
ylabel('|M(f)|');
title('Original spectrum');
subplot(3,1,2);

plot(f_scrambled/1000, ...
     M_scrambled);

grid on;

xlim([-7 7]);

xlabel('Frequency (kHz)');
ylabel('|S(f)|');

title('Scrambled spectrum');


subplot(3,1,3);

plot(f_recovered/1000, ...
     M_recovered);

grid on;

xlim([-7 7]);

xlabel('Frequency (kHz)');
ylabel('|R(f)|');

title('Recovered spectrum');


%% ============================================================
% 16. COMPARE ORIGINAL AND RECOVERED
%% ============================================================

figure('Name', 'Original vs Recovered');

plot(t(1:N_display), ...
     voice(1:N_display), 'b');

hold on;

plot(t(1:N_display), ...
     recovered(1:N_display), 'r--');

grid on;

xlabel('Time (s)');
ylabel('Amplitude');

title('Original vs recovered');

legend('Original', 'Recovered');


fprintf('\n========================================\n');
fprintf('              FINISHED\n');
fprintf('========================================\n');

fprintf('\nListen to:\n');
fprintf('  scrambled_two_band.wav\n');
fprintf('  recovered_two_band.wav\n\n');

fprintf('If the scrambled voice is sufficiently unintelligible,\n');
fprintf('we can implement this same transformation using\n');
fprintf('mixers + Butterworth filters instead of direct FFT\n');
fprintf('manipulation.\n');