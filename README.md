# Voice Scrambler

A frequency-inversion voice scrambler implemented in GNU Octave as a Communications Systems project.

The project implements a mixer–filter–mixer–filter system based on the frequency-inversion scrambler presented in the course material. The implementation analyses the input audio, determines its relevant spectral bandwidth, and adapts the carrier frequencies accordingly.

## System

The implemented system is:

m(t) -> × 2cos(2π*f_c1*t) -> HPF -> × 2cos(2π*f(c2)*t) -> LPF -> y(t)

in which:

- m(t) is the original voice signal;
- f_c1 is the first carrier frequency;
- f_c2 is the second carrier frequency;
- B is the relevant bandwidth of the input signal;
- y(t) is the scrambled signal.

The second carrier is defined as:

f_c2 = f_c1 + B

This relationship produces the required spectral inversion.

## Features

- .WAV audio input
- Simple stereo-mono conversion
- Sampling-frequency adaptation
- Spectral analysis using the FFT
- Estimation of the magnitude relevant bandwidth
- Butterworth high-pass and low-pass filtering
- Frequency-domain voice scrambling
- Scrambled WAV output
- Time and frequency-domain visualisation
- Reproducible scrambling/descrambling parameters

## Bandwidth Estimation

The relevant bandwidth is estimated from the input signal using the cumulative spectral energy.

The implementation defines the relevant bandwidth as the frequency below which 99% of the signal's spectral energy is contained.

This value is then used to determine the second carrier frequency, and this approach avoids assuming a fixed voice bandwidth and allows the system to adapt to different recordings.

## Sampling Frequency

The processing sampling frequency is set to twice the original sampling frequency, according to Nyquist criterion:

Fs = 2Fs_original

## Scrambling Process

I.   The input voice is first multiplied by a cosine carrier. The resulting spectrum contains shifted replicas of the original spectrum.

II.  A high-pass Butterworth filter then selects the required spectral component.

III. The filtered signal is multiplied by a second carrier whose frequency depends on the measured bandwidth. A final low-pass filter selects the resulting component.

IV.  The resulting signal has an inverted spectral distribution and is therefore significantly less intelligible when reproduced directly.

## Parameter Consistency

An important issue encountered during development was the need to use exactly the same bandwidth parameter during scrambling and descrambling. Initially, the bandwidth was independently estimated each time the program was executed. Since the spectral shape of the scrambled signal differs from that of the original signal, the estimated bandwidth could change slightly. This caused the descrambled signal to experience a frequency shift. To solve this problem, the bandwidth used during scrambling is stored alongside the generated audio file and reused during subsequent processing. This guarantees that both processes use the same carrier frequencies and preserves the self-inverse property of the frequency transformation.

## Results

The project analyses the signal at each stage of the system in both the time and frequency domains.

The generated results include:

- Original voice signal
- Signal after the first mixer
- Signal after the high-pass filter
- Signal after the second mixer
- Final scrambled signal
- Spectra of all intermediate signals

The scrambled audio can be compared directly with the original and recovered signals to evaluate the effectiveness of the system.

## Requirements

- GNU Octave
- Octave Signal package

```octave
pkg load signal
