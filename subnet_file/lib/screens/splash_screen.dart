import 'dart:math';

import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../navigation/app_page_route.dart';
import '../theme/app_colors.dart';
import '../widgets/glow_buttons.dart';
import 'identity_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _enter() {
    Navigator.of(
      context,
    ).pushReplacement(AppPageRoute.slideUp(const IdentityScreen()));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.appBg,
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _AmbientBackground(),
          Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  AnimatedBuilder(
                    animation: _controller,
                    builder:
                        (context, _) => RepaintBoundary(
                          child: CustomPaint(
                            size: const Size(184, 184),
                            painter: _SubnetLogoPainter(_controller.value),
                          ),
                        ),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'subnet',
                    style: GoogleFonts.dmSans(
                      fontSize: 38,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                      letterSpacing: 8,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Hidden in your network.',
                    style: GoogleFonts.dmSans(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 72),
                  GlowButton(
                    label: 'Get Started',
                    onPressed: _enter,
                    width: double.infinity,
                  ),
                  const SizedBox(height: 18),
                  TextButton(
                    onPressed: _enter,
                    child: Text(
                      'Join a Space',
                      style: GoogleFonts.dmSans(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _AmbientBackground extends StatelessWidget {
  const _AmbientBackground();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.appBg,
        gradient: RadialGradient(
          center: const Alignment(0.45, -0.35),
          radius: 0.95,
          colors: [
            AppColors.primaryGlow.withValues(alpha: 0.28),
            AppColors.ghostGlow.withValues(alpha: 0.12),
            AppColors.appBg,
          ],
          stops: const [0, 0.36, 1],
        ),
      ),
    );
  }
}

class _SubnetLogoPainter extends CustomPainter {
  final double t;
  _SubnetLogoPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.width * 0.34;
    final pulse = 0.88 + 0.12 * sin(t * pi * 2);
    final orbitPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1
          ..color = AppColors.borderSubtle;
    final glowPaint =
        Paint()
          ..color = AppColors.primaryGlow.withValues(alpha: 0.8)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 26);
    final sweepPaint =
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..strokeCap = StrokeCap.round
          ..color = AppColors.primary.withValues(alpha: 0.65);

    canvas.drawCircle(center, radius * 1.18, orbitPaint);
    canvas.drawCircle(center, radius * 0.78, orbitPaint);
    canvas.drawCircle(
      center,
      radius * 1.42,
      orbitPaint..color = AppColors.ghostGlow.withValues(alpha: 0.22),
    );
    canvas.drawCircle(center, radius * 0.92 * pulse, glowPaint);

    final sweepAngle = 1.1;
    final startAngle = (t * pi * 2) - (sweepAngle / 2);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: radius * 1.12),
      startAngle,
      sweepAngle,
      false,
      sweepPaint,
    );

    for (var i = 0; i < 6; i++) {
      final angle = (pi * 2 * i / 6) + (t * pi * 0.5);
      final r = radius * (i.isEven ? 1.05 : 0.62);
      final p = center + Offset(cos(angle) * r, sin(angle) * r);
      canvas.drawCircle(p, 4, Paint()..color = AppColors.primary);
    }

    canvas.drawCircle(center, 14, Paint()..color = AppColors.primary);
    canvas.drawCircle(
      center,
      26,
      Paint()..color = AppColors.primaryGlow.withValues(alpha: 0.8),
    );
  }

  @override
  bool shouldRepaint(covariant _SubnetLogoPainter oldDelegate) =>
      oldDelegate.t != t;
}
