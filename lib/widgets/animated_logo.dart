import 'dart:math' as math;
import 'package:flutter/material.dart';
import '../theme/aegis_theme.dart';

/// The Aegis logo with a gentle "breathing" fade in / fade out and soft wave
/// rings rippling outward from behind it.
///
/// Takes the same footprint as [size] + [padding] on each side, so swapping it
/// in does not move anything else on the screen. The waves draw outside that
/// box without affecting layout. Honours the system "reduce motion" setting.
class AnimatedAegisLogo extends StatefulWidget {
  const AnimatedAegisLogo({
    super.key,
    this.size = 64,
    this.padding = AegisSpacing.xl,
    this.waveColor = AegisColors.textPrimary,
    this.waveCount = 3,
    this.period = const Duration(milliseconds: 2800),
  });

  /// Width and height of the logo image.
  final double size;

  /// Empty space kept around the logo (matches the old frame).
  final double padding;

  /// Colour of the wave rings.
  final Color waveColor;

  /// Number of rings visible at once.
  final int waveCount;

  /// Length of one fade-in / fade-out cycle.
  final Duration period;

  @override
  State<AnimatedAegisLogo> createState() => _AnimatedAegisLogoState();
}

class _AnimatedAegisLogoState extends State<AnimatedAegisLogo> with TickerProviderStateMixin {
  late final AnimationController _intro;
  late final AnimationController _loop;

  @override
  void initState() {
    super.initState();
    // One-off entrance: fade the logo in from nothing.
    _intro = AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..forward();
    // Repeating cycle that drives the breathing fade and the waves.
    _loop = AnimationController(vsync: this, duration: widget.period)..repeat();
  }

  @override
  void dispose() {
    _intro.dispose();
    _loop.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final reduceMotion = MediaQuery.maybeOf(context)?.disableAnimations ?? false;
    final box = widget.size + widget.padding * 2;

    final logo = Image.asset(
      'assets/logo/aegis_logo.png',
      width: widget.size,
      height: widget.size,
      semanticLabel: 'Aegis logo',
    );

    if (reduceMotion) {
      return SizedBox(width: box, height: box, child: Center(child: logo));
    }

    return SizedBox(
      width: box,
      height: box,
      child: AnimatedBuilder(
        animation: Listenable.merge([_intro, _loop]),
        builder: (context, child) {
          final intro = Curves.easeOut.transform(_intro.value);
          // Breathing: opacity glides between 0.35 and 1.0 and back each cycle.
          final breath = 0.5 + 0.5 * math.cos(2 * math.pi * _loop.value);
          final opacity = intro * (0.35 + 0.65 * breath);

          return Stack(
            clipBehavior: Clip.none,
            alignment: Alignment.center,
            children: [
              Positioned.fill(
                child: CustomPaint(
                  painter: _WavePainter(
                    progress: _loop.value,
                    count: widget.waveCount,
                    color: widget.waveColor,
                    startRadius: widget.size * 0.45,
                    endRadius: box * 0.85,
                    strength: intro,
                  ),
                ),
              ),
              Opacity(opacity: opacity, child: child),
            ],
          );
        },
        child: logo,
      ),
    );
  }
}

/// Concentric rings that grow outward and fade as they expand.
class _WavePainter extends CustomPainter {
  _WavePainter({
    required this.progress,
    required this.count,
    required this.color,
    required this.startRadius,
    required this.endRadius,
    required this.strength,
  });

  final double progress;
  final int count;
  final Color color;
  final double startRadius;
  final double endRadius;
  final double strength;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    for (var i = 0; i < count; i++) {
      // Stagger each ring evenly through the cycle.
      final t = (progress + i / count) % 1.0;
      final eased = Curves.easeOut.transform(t);
      final radius = startRadius + (endRadius - startRadius) * eased;
      final alpha = (1 - t) * 0.35 * strength;
      if (alpha <= 0.01) continue;

      final paint = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2 * (1 - t) + 0.5
        ..color = color.withValues(alpha: alpha);
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(covariant _WavePainter old) =>
      old.progress != progress || old.strength != strength || old.color != color;
}
