#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// Objective-C wrapper around the C++ waveform peaks library.
/// Swift cannot call C++ directly, so this .h/.mm pair bridges the boundary.
@interface WaveformCppBridge : NSObject

/// Generate normalized RMS waveform peaks from a PCM float32 mono buffer.
///
/// @param pcmBuffer  Pointer to float32 mono samples in the range [-1, 1].
/// @param frameCount Number of samples in pcmBuffer.
/// @param sampleRate Audio sample rate in Hz (reserved for future use).
/// @param barCount   Number of output bars (e.g. 300).
/// @param error      On failure, set to a descriptive NSError.
/// @return           Array of NSNumber<float> values in [0, 1], or nil on error.
+ (nullable NSArray<NSNumber *> *)generatePeaksFromBuffer:(const float *)pcmBuffer
                                               frameCount:(uint64_t)frameCount
                                               sampleRate:(double)sampleRate
                                                 barCount:(uint32_t)barCount
                                                    error:(NSError **)error;

@end

NS_ASSUME_NONNULL_END
