import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/gta_colors.dart';

class GtaLogo extends StatefulWidget {
  final double size;
  final bool showText;
  final bool animate;

  const GtaLogo({
    super.key,
    this.size = 64,
    this.showText = true,
    this.animate = true,
  });

  @override
  State<GtaLogo> createState() => _GtaLogoState();
}

class _GtaLogoState extends State<GtaLogo> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 8),
    );
    if (widget.animate) {
      _controller.repeat();
    }
  }

  @override
  void didUpdateWidget(covariant GtaLogo oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) {
      _controller.repeat();
    } else if (!widget.animate && _controller.isAnimating) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final iconWidget = AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return CustomPaint(
          size: Size(widget.size, widget.size),
          painter: _GtaLogoPainter(
            rotation: _controller.value * 2 * math.pi,
          ),
        );
      },
    );

    if (!widget.showText) {
      return iconWidget;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        iconWidget,
        const SizedBox(width: 12),
        Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            ShaderMask(
              shaderCallback: (bounds) => GtaColors.viceSunsetGradient.createShader(bounds),
              child: Text(
                'b-cam',
                style: GoogleFonts.orbitron(
                  fontSize: widget.size * 0.45,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 2.0,
                  color: Colors.white,
                  shadows: [
                    Shadow(
                      color: GtaColors.neonPink.withOpacity(0.6),
                      blurRadius: 15,
                    ),
                  ],
                ),
              ),
            ),
            Text(
              'SURVEILLANCE RADAR',
              style: GoogleFonts.rajdhani(
                fontSize: widget.size * 0.18,
                fontWeight: FontWeight.w700,
                letterSpacing: 2.5,
                color: GtaColors.electricCyan,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GtaLogoPainter extends CustomPainter {
  final double rotation;

  _GtaLogoPainter({required this.rotation});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2;

    // 1. Outer Glow halo
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          GtaColors.neonPink.withOpacity(0.4),
          GtaColors.electricCyan.withOpacity(0.15),
          Colors.transparent,
        ],
        stops: const [0.4, 0.75, 1.0],
      ).createShader(Rect.fromCircle(center: center, radius: radius * 1.15));
    canvas.drawCircle(center, radius * 1.15, glowPaint);

    // 2. Dark circular lens backdrop
    final bgPaint = Paint()
      ..color = const Color(0xFF0E0C1F)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.88, bgPaint);

    // 3. Rotating Tech Reticle / Crosshair tick marks
    final tickPaint = Paint()
      ..color = GtaColors.electricCyan.withOpacity(0.7)
      ..strokeWidth = 1.5
      ..style = PaintingStyle.stroke;

    const tickCount = 12;
    for (int i = 0; i < tickCount; i++) {
      final angle = rotation + (i * 2 * math.pi / tickCount);
      final rInner = radius * 0.78;
      final rOuter = (i % 3 == 0) ? radius * 0.92 : radius * 0.84;
      final p1 = Offset(center.dx + rInner * math.cos(angle), center.dy + rInner * math.sin(angle));
      final p2 = Offset(center.dx + rOuter * math.cos(angle), center.dy + rOuter * math.sin(angle));
      canvas.drawLine(p1, p2, tickPaint);
    }

    // 4. Outer Neon Ring with Sunset Gradient
    final ringPaint = Paint()
      ..shader = SweepGradient(
        colors: const [
          GtaColors.neonPink,
          GtaColors.sunsetOrange,
          GtaColors.sunsetYellow,
          GtaColors.electricCyan,
          GtaColors.neonPink,
        ],
        transform: GradientRotation(rotation * 0.5),
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.88))
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.055;
    canvas.drawCircle(center, radius * 0.88, ringPaint);

    // 5. Stylized 'b' aperture symbol in center
    // The vertical stalk of 'b' on left and the round camera lens loop on right
    final bPaint = Paint()
      ..shader = const LinearGradient(
        colors: [GtaColors.neonPink, GtaColors.sunsetOrange],
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
      ).createShader(Rect.fromCircle(center: center, radius: radius * 0.6))
      ..style = PaintingStyle.fill;

    final stalkLeft = center.dx - radius * 0.35;
    final stalkTop = center.dy - radius * 0.55;
    final stalkWidth = radius * 0.16;
    final stalkHeight = radius * 1.05;

    // Stalk rounded rect
    final stalkRect = RRect.fromRectAndRadius(
      Rect.fromLTWH(stalkLeft, stalkTop, stalkWidth, stalkHeight),
      Radius.circular(stalkWidth / 2),
    );
    canvas.drawRRect(stalkRect, bPaint);

    // Camera lens circle (bowl of the 'b')
    final lensCenter = Offset(center.dx + radius * 0.08, center.dy + radius * 0.12);
    final lensRadius = radius * 0.38;

    final lensRingPaint = Paint()
      ..shader = const LinearGradient(
        colors: [GtaColors.sunsetOrange, GtaColors.neonPink],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ).createShader(Rect.fromCircle(center: lensCenter, radius: lensRadius))
      ..style = PaintingStyle.stroke
      ..strokeWidth = radius * 0.16;
    canvas.drawCircle(lensCenter, lensRadius, lensRingPaint);

    // Inner Iris lens aperture (Electric Cyan center pupil)
    final irisPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          GtaColors.electricCyan,
          GtaColors.electricCyan.withOpacity(0.3),
          Colors.transparent,
        ],
      ).createShader(Rect.fromCircle(center: lensCenter, radius: lensRadius * 0.65))
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lensCenter, lensRadius * 0.55, irisPaint);

    // Center recording red/pink blink dot
    final dotPaint = Paint()
      ..color = const Color(0xFFFF0055)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(lensCenter, lensRadius * 0.22, dotPaint);

    // Lens reflection glare
    final glarePaint = Paint()
      ..color = Colors.white.withOpacity(0.7)
      ..style = PaintingStyle.fill;
    canvas.drawCircle(
      Offset(lensCenter.dx - lensRadius * 0.22, lensCenter.dy - lensRadius * 0.22),
      lensRadius * 0.1,
      glarePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _GtaLogoPainter oldDelegate) {
    return oldDelegate.rotation != rotation;
  }
}
