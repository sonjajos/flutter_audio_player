import 'dart:ffi';
import 'dart:typed_data';
import 'package:ffi/ffi.dart';

// C function signature:
//   int generate_waveform_peaks(
//       const float *pcm_buffer,
//       uint64_t frame_count,
//       double sample_rate,
//       uint32_t bar_count,
//       float *peaks_out,
//       uint32_t *peaks_count_out
//   );
typedef _NativeGeneratePeaks = Int32 Function(
  Pointer<Float>, // pcm_buffer
  Uint64,         // frame_count
  Double,         // sample_rate
  Uint32,         // bar_count
  Pointer<Float>, // peaks_out
  Pointer<Uint32>, // peaks_count_out
);
typedef _GeneratePeaks = int Function(
  Pointer<Float>,
  int,
  double,
  int,
  Pointer<Float>,
  Pointer<Uint32>,
);

/// Calls the C++ waveform engine directly via dart:ffi.
///
/// The C++ symbol [generate_waveform_peaks] is compiled into the iOS app
/// binary (via WaveformCppBridge.mm unity build) and resolved at runtime
/// through [DynamicLibrary.process].
class WaveformFFI {
  static final _lib = DynamicLibrary.process();
  static final _generatePeaks = _lib.lookupFunction<_NativeGeneratePeaks, _GeneratePeaks>(
    'generate_waveform_peaks',
  );

  /// Generate [barCount] normalized RMS peaks from [pcm] float32 mono data.
  ///
  /// [sampleRate] is passed through to the C++ function (currently unused
  /// by the algorithm but kept for API parity with the RN implementation).
  ///
  /// Returns a list of [barCount] values in [0.0, 1.0], or an empty list
  /// on failure.
  static List<double> generatePeaks(
    Float32List pcm,
    int barCount, {
    double sampleRate = 44100.0,
  }) {
    if (pcm.isEmpty || barCount <= 0) return [];

    final inputPtr = calloc<Float>(pcm.length);
    final outputPtr = calloc<Float>(barCount);
    final countPtr = calloc<Uint32>();

    try {
      inputPtr.asTypedList(pcm.length).setAll(0, pcm);

      final ok = _generatePeaks(
        inputPtr,
        pcm.length,
        sampleRate,
        barCount,
        outputPtr,
        countPtr,
      );

      if (ok == 0) return [];

      return List<double>.from(outputPtr.asTypedList(barCount));
    } finally {
      calloc.free(inputPtr);
      calloc.free(outputPtr);
      calloc.free(countPtr);
    }
  }
}
