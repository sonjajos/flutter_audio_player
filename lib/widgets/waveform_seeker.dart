import 'dart:math' as math;
import 'package:flutter/material.dart';

/// Waveform seeker widget — renders normalized RMS peaks as vertical bars,
/// split into played (active) and remaining (inactive) sections based on
/// [progress]. Matches the visual design of the React Native WaveformSeeker.
class WaveformSeeker extends StatefulWidget {
  /// Normalized peaks in [0.0, 1.0]. Null or empty triggers loading state.
  final List<double>? peaks;

  /// Playback progress in [0.0, 1.0].
  final double progress;

  final int currentPositionMs;
  final int durationMs;
  final bool isPlaying;

  const WaveformSeeker({
    super.key,
    required this.peaks,
    required this.progress,
    required this.currentPositionMs,
    required this.durationMs,
    this.isPlaying = false,
  });

  @override
  State<WaveformSeeker> createState() => _WaveformSeekerState();
}

class _WaveformSeekerState extends State<WaveformSeeker>
    with SingleTickerProviderStateMixin {
  late AnimationController _progressController;
  late Animation<double> _animatedProgress;

  @override
  void initState() {
    super.initState();
    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 120),
    );
    _animatedProgress = Tween<double>(begin: 0, end: 0).animate(
      CurvedAnimation(parent: _progressController, curve: Curves.linear),
    );
  }

  @override
  void didUpdateWidget(WaveformSeeker old) {
    super.didUpdateWidget(old);
    final target = widget.progress.clamp(0.0, 1.0);
    if (widget.isPlaying) {
      _animatedProgress =
          Tween<double>(begin: _animatedProgress.value, end: target).animate(
            CurvedAnimation(parent: _progressController, curve: Curves.linear),
          );
      _progressController
        ..reset()
        ..forward();
    } else {
      _progressController.stop();
      _animatedProgress = AlwaysStoppedAnimation(target);
    }
  }

  @override
  void dispose() {
    _progressController.dispose();
    super.dispose();
  }

  String _formatMs(int ms) {
    final totalSec = ms ~/ 1000;
    final m = totalSec ~/ 60;
    final s = totalSec % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: const Color(0x364EF2C1), width: 1),
              bottom: BorderSide(color: const Color(0x364EF2C1), width: 1),
              left: BorderSide(color: const Color(0xFF4EF2C1), width: 3),
              right: BorderSide(color: const Color(0xFF4EF2C1), width: 3),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: AnimatedBuilder(
            animation: _animatedProgress,
            builder: (context, _) {
              return CustomPaint(
                size: const Size(double.infinity, 50),
                painter: _WaveformPainter(
                  peaks: widget.peaks,
                  progress: _animatedProgress.value,
                ),
                isComplex: true,
              );
            },
          ),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                _formatMs(widget.currentPositionMs),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
              Text(
                _formatMs(widget.durationMs),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 11,
                  fontFeatures: [FontFeature.tabularFigures()],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WaveformPainter extends CustomPainter {
  final List<double>? peaks;
  final double progress;

  static const _barActive = Color(0xFF00E5FF);
  static const _barInactive = Color(0x2200E5FF);
  static const _barTip = Color(0x59FFFFFF); // ~35% white
  static const _lineColor = Color(0x3300E5FF);
  static const _tickColor = Color(0x5500E5FF);

  // Cached paints — allocated once, not per frame
  static final _inactivePaint = Paint()
    ..color = _barInactive
    ..style = PaintingStyle.fill;
  static final _activePaint = Paint()
    ..color = _barActive
    ..style = PaintingStyle.fill;
  static final _tipPaint = Paint()
    ..color = _barTip
    ..style = PaintingStyle.fill;
  static final _linePaint = Paint()
    ..color = _lineColor
    ..strokeWidth = 1.0
    ..style = PaintingStyle.stroke;
  static final _tickPaint = Paint()
    ..color = _tickColor
    ..strokeWidth = 1.5
    ..style = PaintingStyle.stroke;

  const _WaveformPainter({required this.peaks, required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final cw = size.width;
    final midY = size.height / 2;
    final progressX = progress.clamp(0.0, 1.0) * cw;

    final isLoading = peaks == null || peaks!.isEmpty;

    if (isLoading) {
      _drawPlaceholder(canvas, size, cw, midY);
      return;
    }

    _drawBars(canvas, cw, midY, progressX);
  }

  void _drawPlaceholder(Canvas canvas, Size size, double cw, double midY) {
    canvas.drawLine(Offset(0, midY), Offset(cw, midY), _linePaint);

    const tickCount = 60;
    for (int i = 0; i < tickCount; i++) {
      final x = (i / (tickCount - 1)) * cw;
      final envelope = 0.18 + 0.22 * math.sin(i * 0.53).abs();
      final tickH = envelope * midY;
      canvas.drawLine(
        Offset(x, midY - tickH),
        Offset(x, midY + tickH),
        _tickPaint,
      );
    }
  }

  void _drawBars(Canvas canvas, double cw, double midY, double progressX) {
    final barCount = peaks!.length;
    final barW = cw / barCount;
    final gap = math.max(1.0, barW * 0.25);
    final bW = math.max(1.0, barW - gap);
    final radius = bW / 2;

    for (int i = 0; i < barCount; i++) {
      final peak = peaks![i].clamp(0.0, 1.0);
      final barH = math.max(3.0, peak * midY * 0.85);
      final x = i * barW + gap / 2;
      final barCenter = x + bW / 2;

      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, midY - barH, bW, barH * 2),
        Radius.circular(radius),
      );

      if (barCenter <= progressX) {
        canvas.drawRRect(rrect, _activePaint);
        // White tip on top of active bars
        final tipH = math.max(2.0, barH * 0.2);
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(x, midY - barH, bW, tipH * 2),
            Radius.circular(bW / 2),
          ),
          _tipPaint,
        );
      } else {
        canvas.drawRRect(rrect, _inactivePaint);
      }
    }
  }

  @override
  bool shouldRepaint(_WaveformPainter old) =>
      old.progress != progress || old.peaks != peaks;
}
