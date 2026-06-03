import 'package:flutter/material.dart';

import '../theme/app_colors.dart';

class GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final BorderRadius borderRadius;
  final VoidCallback? onTap;

  const GlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderRadius = const BorderRadius.all(Radius.circular(16)),
    this.onTap,
  });

  static BoxDecoration decoration({BorderRadius borderRadius = const BorderRadius.all(Radius.circular(16))}) {
    return BoxDecoration(
      color: AppColors.surfaceCard.withValues(alpha: 0.88),
      gradient: const LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          Color(0x14FFFFFF),
          Color(0x04FFFFFF),
        ],
      ),
      borderRadius: borderRadius,
      border: Border.all(color: AppColors.borderSubtle, width: 0.5),
      boxShadow: const [
        BoxShadow(color: Color(0x66000000), blurRadius: 26, offset: Offset(0, 12)),
        BoxShadow(color: AppColors.primaryGlow, blurRadius: 28, spreadRadius: -16),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Container(
      padding: padding,
      decoration: decoration(borderRadius: borderRadius),
      child: child,
    );

    if (onTap == null) return content;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: borderRadius,
        splashColor: AppColors.primaryGlow,
        highlightColor: AppColors.primaryGlow.withValues(alpha: 0.08),
        child: content,
      ),
    );
  }
}

