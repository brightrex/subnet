import 'dart:ui';

import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class FrostedPanel extends StatelessWidget {
  final Widget child;
  final BorderRadius borderRadius;
  final EdgeInsetsGeometry padding;

  const FrostedPanel({
    super.key,
    required this.child,
    this.borderRadius = const BorderRadius.vertical(top: Radius.circular(24)),
    this.padding = const EdgeInsets.fromLTRB(16, 12, 16, 24),
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xCC0E140E),
            borderRadius: borderRadius,
            border: const Border(
              top: BorderSide(color: Color(0x15FFFFFF), width: 0.5),
            ),
            boxShadow: const [
              BoxShadow(color: Color(0x88000000), blurRadius: 32, offset: Offset(0, -8)),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class FrostedBottomSheetHandle extends StatelessWidget {
  const FrostedBottomSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 40,
        height: 4,
        margin: const EdgeInsets.only(top: 8, bottom: 12),
        decoration: BoxDecoration(
          color: AppColors.muted,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}

