#ifndef WAVEFORM_PEAKS_H
#define WAVEFORM_PEAKS_H

#include <stdint.h>

#ifdef __cplusplus
extern "C"
{
#endif

    /**
     * Generate normalized waveform peaks from PCM float32 mono buffer.
     *
     * Algorithm:
     * 1. chunk_frames = frame_count / bar_count
     * 2. per chunk: rms = sqrt(mean(sample^2))
     * 3. peaks[i] = rms_i / global_max_rms (0-1 normalized)
     *
     * Args:
     *   pcm_buffer: Input PCM float32 mono [-1,1]
     *   frame_count: Total samples
     *   sample_rate: Hz (unused, time-uniform chunks)
     *   bar_count: Output peaks length
     *   peaks_out: Caller-allocated float[bar_count]
     *   peaks_count_out: Actual written count
     *
     * Returns: 1 success, 0 error (log via NSLog/printf)
     */
    int generate_waveform_peaks(
        const float *pcm_buffer,
        uint64_t frame_count,
        double sample_rate,
        uint32_t bar_count,
        float *peaks_out,
        uint32_t *peaks_count_out);

#ifdef __cplusplus
}
#endif

#endif // WAVEFORM_PEAKS_H
