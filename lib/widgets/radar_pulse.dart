import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../models/scan_result.dart';
import '../theme/gta_colors.dart';

class RadarPulse extends StatefulWidget {
  final double size;
  final bool isScanning;
  final List<ScanResult> discoveredDevices;

  const RadarPulse({
    super.key,
    this.size = 220,
    required this.isScanning,
    this.discoveredDevices = const [],
  });

  @override
  State<RadarPulse> createState() => _RadarPulseState();
}

class _RadarPulseState extends State<RadarPulse> with SingleTickerProviderStateMixin {
  late AnimationController _sweepController;

  @override
  void initState() {
    super.initState();
    _sweepController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2400),
    );
    if (widget.isScanning) {
      _sweepController.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant RadarPulse oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isScanning && !_sweepController.isAnimating) {
      _sweepController.repeat();
    } else if (!widget.isScanning && _sweepController.isAnimating) {
      _sweepController.stop();
    }
  }

  @override
  void dispose() {
    _sweepController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _sweepController,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _RadarPainter(
            sweepAngle: _sweepController.value * 2 * math.pi,
            isScanning: widget.isScanning,
            deviceCount: widget.discoveredDevices.length,
          ),
        );
      },
    );
  }
}

class _RadarPainter extends CustomPainter {
  final double sweepAngle;
  final bool isScanning;
  final int deviceCount;

  _RadarPainter({
    required this.sweepAngle,
    required this.isScanning,
    required this.deviceCount,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Radar background
    final bgPaint = Paint()
      ..color = const Color(0xFF0C0A1C)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius, bgPaint);

    // 2. Concentric Rings
    final ringPaint = Paint()
      ..color = GtaColors.electricCyan.withOpacity(0.18)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.0;

    for (int i = 1; i <= 4; i++) {
      canvas.drawCircle(center, radius * (i / 4), ringPaint);
    }

    // 3. Cross lines
    final axisPaint = Paint()
      ..color = GtaColors.electricCyan.withOpacity(0.15)
      ..strokeWidth = 1.0;
    canvas.drawLine(Offset(center.dx, 0), Offset(center.dx, size.height), axisPaint);
    canvas.drawLine(Offset(0, center.dy), Offset(size.width, center.dy), axisPaint);

    // 4. Sweeping Sector (Gradient trailing sweep)
    if (isScanning) {
      final sweepPaint = Paint()
        ..shader = SweepGradient(
          center: Alignment.center,
          startAngle: 0.0,
          endAngle: math.pi / 2,
          colors: [
            Colors.transparent,
            GtaColors.neonPink.withOpacity(0.35),
          ],
          transform: GradientRotation(sweepAngle - (math.pi / 2)),
        ).createShader(Rect.fromCircle(center: center, radius: radius));

      canvas.drawCircle(center, radius, sweepPaint);

      // Leading beam line
      final beamPaint = Paint()
        ..color = GtaColors.neonPink
        ..strokeWidth = 2.0
        ..style = PaintingStyle.stroke;
      final beamTarget = Offset(
        center.dx + radius * math.cos(sweepAngle),
        center.dy + radius * math.sin(sweepAngle),
      );
      canvas.drawLine(center, beamTarget, beamPaint);
    }

    // 5. Blip dots for discovered cameras
    final blipPaint = Paint()..style = PaintingStyle.fill;
    for (int i = 0; i < deviceCount; i++) {
      // Deterministic angle & distance based on index
      final blipAngle = (i * 1.61803) % (2 * math.pi);
      final blipDistance = radius * (0.35 + ((i * 0.22) % 0.5));
      final blipPos = Offset(
        center.dx + blipDistance * math.cos(blipAngle),
        center.dy + blipDistance * math.sin(blipAngle),
      );

      // Glow halo
      blipPaint.color = GtaColors.statusOnline.withOpacity(0.35);
      canvas.drawCircle(blipPos, 8.0, blipPaint);

      // Dot center
      blipPaint.color = GtaColors.statusOnline;
      canvas.drawCircle(blipPos, 4.0, blipPaint);
    }

    // 6. Outer Border
    final borderPaint = Paint()
      ..color = GtaColors.neonPink.withOpacity(0.6)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.0;
    canvas.drawCircle(center, radius, borderPaint);
  }

  @override
  bool shouldRepaint(covariant _RadarPainter oldDelegate) {
    return oldDelegate.sweepAngle != sweepAngle ||
        oldDelegate.isScanning != isScanning ||
        oldDelegate.deviceCount != deviceCount;
  }
}
