#import "WaveformCppBridge.h"

// Unity-build: include the C++ implementation directly so it is compiled as
// part of this .mm translation unit. All files are co-located in ios/Runner/.
#include "waveform_peaks.cpp"

@implementation WaveformCppBridge

+ (nullable NSArray<NSNumber *> *)generatePeaksFromBuffer:(const float *)pcmBuffer
                                               frameCount:(uint64_t)frameCount
                                               sampleRate:(double)sampleRate
                                                 barCount:(uint32_t)barCount
                                                    error:(NSError **)error {
    if (!pcmBuffer || frameCount == 0 || barCount == 0) {
        if (error) {
            *error = [NSError errorWithDomain:@"AudioEngine"
                                         code:100
                                     userInfo:@{NSLocalizedDescriptionKey: @"Invalid arguments for waveform generation"}];
        }
        return nil;
    }

    std::vector<float> peaks(barCount, 0.0f);
    uint32_t peaksCount = barCount;

    int ok = generate_waveform_peaks(pcmBuffer, frameCount, sampleRate, barCount,
                                     peaks.data(), &peaksCount);

    if (!ok) {
        if (error) {
            *error = [NSError errorWithDomain:@"AudioEngine"
                                         code:101
                                     userInfo:@{NSLocalizedDescriptionKey: @"C++ generate_waveform_peaks returned error"}];
        }
        return nil;
    }

    NSMutableArray<NSNumber *> *result = [NSMutableArray arrayWithCapacity:peaksCount];
    for (uint32_t i = 0; i < peaksCount; ++i) {
        [result addObject:@(peaks[i])];
    }
    return [result copy];
}

@end
