#include "waveform_peaks.h"
#include <cmath>
#include <cstdint>
#include <cstdio>
#include <vector>
#include <algorithm>

extern "C" int generate_waveform_peaks(
    const float *pcm_buffer,
    uint64_t frame_count,
    double sample_rate, // unused (uniform time chunks)
    uint32_t bar_count,
    float *peaks_out,
    uint32_t *peaks_count_out)
{
    if (!pcm_buffer || frame_count == 0 || bar_count == 0 || !peaks_out || !peaks_count_out)
    {
        return 0;
    }

    const uint64_t chunk_frames = frame_count / bar_count;
    if (chunk_frames == 0)
    {
        return 0;
    }

    // Pass 1: Compute RMS per chunk, find global max
    float global_max_rms = 0.0f;
    std::vector<float> rms_values(bar_count, 0.0f);

    for (uint32_t i = 0; i < bar_count; ++i)
    {
        const uint64_t chunk_start_idx = static_cast<uint64_t>(i) * chunk_frames;
        const uint64_t chunk_end_idx = std::min(chunk_start_idx + chunk_frames, frame_count);
        const uint64_t chunk_len = chunk_end_idx - chunk_start_idx;
        const float *chunk_start = pcm_buffer + chunk_start_idx;

        // RMS: sqrt(mean(sample^2))
        double sum_squares = 0.0;
        for (uint64_t j = 0; j < chunk_len; ++j)
        {
            const double s = static_cast<double>(chunk_start[j]);
            sum_squares += s * s;
        }
        const float rms = static_cast<float>(std::sqrt(sum_squares / static_cast<double>(chunk_len)));
        rms_values[i] = rms;
        if (rms > global_max_rms)
            global_max_rms = rms;
    }

    // Pass 2: Normalize 0-1
    *peaks_count_out = bar_count;
    if (global_max_rms > 0.0f)
    {
        for (uint32_t i = 0; i < bar_count; ++i)
        {
            peaks_out[i] = rms_values[i] / global_max_rms;
        }
    }
    else
    {
        for (uint32_t i = 0; i < bar_count; ++i)
        {
            peaks_out[i] = 0.0f;
        }
    }

    printf("WaveformPeaks: %llu frames -> %u bars, max_rms=%.4f\n",
           (unsigned long long)frame_count, (unsigned)bar_count, global_max_rms);

    return 1;
}
