import 'dart:math';
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
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late AnimationController _controller;
  late AnimationController _rotationController;
  late Float32List _currentBands;
  late Float32List _targetBands;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _currentBands = Float32List(widget.bandCount);
    _targetBands = Float32List(widget.bandCount);
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 1),
    )..repeat();

    _rotationController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 12),
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
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _controller.stop();
      _rotationController.stop();
    } else if (state == AppLifecycleState.resumed) {
      _controller.repeat();
      _rotationController.repeat();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller.removeListener(_onTick);
    _controller.dispose();
    _rotationController.dispose();
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
    for (var i = count; i < _targetBands.length; i++) {
      _targetBands[i] = 0.0;
    }
  }

  void _onTick() {
    for (var i = 0; i < _currentBands.length; i++) {
      _currentBands[i] = lerpDouble(_currentBands[i], _targetBands[i], 0.3)!;
    }
  }

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _CircularPainter(
          _currentBands,
          _controller,
          _rotationController,
          widget.maxHeightFraction,
        ),
        isComplex: true,
        size: Size.infinite,
      ),
    );
  }
}

class _CircularPainter extends CustomPainter {
  final Float32List bands;
  final Animation<double> rotation;
  final double maxHeightFraction;

  _CircularPainter(
    this.bands,
    Listenable repaint,
    this.rotation,
    this.maxHeightFraction,
  ) : super(repaint: Listenable.merge([repaint, rotation]));

  @override
  void paint(Canvas canvas, Size size) {
    if (bands.isEmpty) return;

    final center = Offset(size.width / 2, size.height / 2);
    final side = min(size.width, size.height);
    final innerRadius = side * 0.28;
    final maxBarLength = side * 0.22 * maxHeightFraction;
    final barWidth = (2 * pi * innerRadius) / (bands.length * 2) * 0.55;
    final angleStep = pi / (bands.length - 1); // half circle per side
    final rotationAngle = rotation.value * 2 * pi;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round;

    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.rotate(rotationAngle);

    // Draw each band twice: mirrored left↔right around the vertical axis.
    // Band 0 sits at the top, band N-1 sits at the bottom.
    // Right side: angle = +step*i from top (clockwise).
    // Left side:  angle = -step*i from top (counter-clockwise) = mirror.
    // Hue ping-pongs cyan→pink→cyan from top→bottom so both sides share the same color.
    for (var i = 0; i < bands.length; i++) {
      final amplitude = bands[i].clamp(0.0, 1.0);
      final barHeight = amplitude * maxBarLength + side * 0.01;

      // t goes 0→1 from top to bottom along either side
      final t = i / (bands.length - 1);
      final hue = 340 - t * 160; // pink (340) at top → cyan (180) at bottom
      paint.color = HSLColor.fromAHSL(1.0, hue, 0.8, 0.6).toColor();
      paint.strokeWidth = barWidth;

      // Right side (clockwise from top)
      final angleR = angleStep * i - pi / 2;
      canvas.drawLine(
        Offset(innerRadius * cos(angleR), innerRadius * sin(angleR)),
        Offset(
          (innerRadius + barHeight) * cos(angleR),
          (innerRadius + barHeight) * sin(angleR),
        ),
        paint,
      );

      // Left side (counter-clockwise from top = mirror)
      final angleL = -angleStep * i - pi / 2;
      canvas.drawLine(
        Offset(innerRadius * cos(angleL), innerRadius * sin(angleL)),
        Offset(
          (innerRadius + barHeight) * cos(angleL),
          (innerRadius + barHeight) * sin(angleL),
        ),
        paint,
      );
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CircularPainter oldDelegate) => false;
}
