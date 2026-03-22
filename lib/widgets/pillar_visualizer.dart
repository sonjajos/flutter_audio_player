import 'dart:typed_data';
import 'dart:ui';
import 'package:flutter/material.dart';

class PillarVisualizer extends StatefulWidget {
  final int bandCount;
  final double maxHeightFraction;

  const PillarVisualizer({
    super.key,
    this.bandCount = 32,
    this.maxHeightFraction = 1.0,
  });

  @override
  State<PillarVisualizer> createState() => PillarVisualizerState();
}

class PillarVisualizerState extends State<PillarVisualizer>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Float32List _currentBands;
  late Float32List _targetBands;

  @override
  void initState() {
    super.initState();
    _currentBands = Float32List(widget.bandCount);
    _targetBands = Float32List(widget.bandCount);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1), // runs indefinitely via repeat
    )..repeat();

    _controller.addListener(_onTick);
  }

  @override
  void didUpdateWidget(PillarVisualizer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.bandCount != widget.bandCount) {
      _currentBands = Float32List(widget.bandCount);
      _targetBands = Float32List(widget.bandCount);
    }
  }

  @override
  void dispose() {
    _controller.removeListener(_onTick);
    _controller.dispose();
    super.dispose();
  }

  /// Called by the parent to push new FFT band data.
  void updateBands(List<double> bands) {
    final count = bands.length < _targetBands.length
        ? bands.length
        : _targetBands.length;
    for (var i = 0; i < count; i++) {
      _targetBands[i] = bands[i];
    }
    // Zero out remaining bands if input is shorter
    for (var i = count; i < _targetBands.length; i++) {
      _targetBands[i] = 0.0;
    }
  }

  void _onTick() {
    // Lerp current towards target for smooth animation
    for (var i = 0; i < _currentBands.length; i++) {
      _currentBands[i] = lerpDouble(
        _currentBands[i],
        _targetBands[i],
        0.3,
      )!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _PillarPainter(_currentBands, _controller, widget.maxHeightFraction),
        isComplex: true,
        size: Size.infinite,
      ),
    );
  }
}

class _PillarPainter extends CustomPainter {
  final Float32List bands;
  final double maxHeightFraction;

  _PillarPainter(this.bands, Listenable repaint, this.maxHeightFraction) : super(repaint: repaint);

  @override
  void paint(Canvas canvas, Size size) {
    if (bands.isEmpty) return;

    final pillarWidth = size.width / bands.length;
    final gap = pillarWidth * 0.2;
    final paint = Paint()..style = PaintingStyle.fill;

    for (var i = 0; i < bands.length; i++) {
      final height = bands[i].clamp(0.0, 1.0) * size.height * maxHeightFraction;
      final rect = Rect.fromLTWH(
        i * pillarWidth + gap / 2,
        size.height - height,
        pillarWidth - gap,
        height,
      );

      // Hue range: 180 (cyan) to 340 (pink), clamped to valid [0, 360]
      final hue = ((i / bands.length) * 160 + 180) % 360;
      paint.color = HSLColor.fromAHSL(
        1.0,
        hue,
        0.8,
        0.6,
      ).toColor();

      canvas.drawRRect(
        RRect.fromRectAndRadius(rect, const Radius.circular(4)),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _PillarPainter oldDelegate) => false;
}
