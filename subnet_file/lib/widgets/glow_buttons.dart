import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

class GlowButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double width;
  final double height;

  const GlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width = 220,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.primary,
            borderRadius: BorderRadius.circular(28),
            boxShadow: const [
              BoxShadow(
                color: AppColors.primaryGlow,
                blurRadius: 20,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(28),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFF161A20),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class OutlineGlowButton extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final double width;
  final double height;

  const OutlineGlowButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.width = 260,
    this.height = 52,
  });

  @override
  Widget build(BuildContext context) {
    return _PressScale(
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.transparent,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppColors.primary, width: 1.5),
            boxShadow: const [
              BoxShadow(color: AppColors.primaryGlow, blurRadius: 12, spreadRadius: -2),
            ],
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(28),
              child: Center(
                child: Text(
                  label,
                  style: GoogleFonts.dmSans(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PressScale extends StatefulWidget {
  final Widget child;
  const _PressScale({required this.child});

  @override
  State<_PressScale> createState() => _PressScaleState();
}

class _PressScaleState extends State<_PressScale> with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _a;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 90));
    _a = Tween<double>(begin: 1, end: 0.96).animate(CurvedAnimation(parent: _c, curve: Curves.easeOut));
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => _c.forward(),
      onTapCancel: () => _c.reverse(),
      onTapUp: (_) => _c.reverse(),
      child: AnimatedBuilder(
        animation: _a,
        builder: (_, child) => Transform.scale(scale: _a.value, child: child),
        child: widget.child,
      ),
    );
  }
}

