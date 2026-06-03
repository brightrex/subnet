import 'package:flutter/material.dart';

class CrtWrapper extends StatefulWidget {
  final Widget child;

  const CrtWrapper({super.key, required this.child});

  @override
  State<CrtWrapper> createState() => _CrtWrapperState();
}

class _CrtWrapperState extends State<CrtWrapper> with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _opacity;

  @override
  void initState() {
    super.initState();
    // 4s loop as mentioned in the design system, but for flicker, a fast one is better.
    // We'll use a fast random-like flicker or a steady 100ms pulse.
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 80),
    )..repeat(reverse: true);

    _opacity = Tween<double>(begin: 0.96, end: 1.0).animate(
      CurvedAnimation(parent: _controller, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _opacity,
      builder: (context, child) {
        return Opacity(
          opacity: _opacity.value,
          child: Stack(
            fit: StackFit.expand,
            children: [
              widget.child,
              // Subtle scanline overlay
              IgnorePointer(
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.black.withValues(alpha: 0.0),
                        Colors.black.withValues(alpha: 0.03),
                        Colors.black.withValues(alpha: 0.0),
                      ],
                      stops: const [0.0, 0.5, 1.0],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      },
      child: widget.child,
    );
  }
}
