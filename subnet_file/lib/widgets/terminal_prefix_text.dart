import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../theme/app_colors.dart';

class TerminalPrefixText extends StatelessWidget {
  final String text;
  final TextStyle? style;
  final bool blinkCaret;
  final Color? textColor;

  const TerminalPrefixText(
    this.text, {
    super.key,
    this.style,
    this.blinkCaret = false,
    this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    final baseStyle = style ??
        GoogleFonts.jetBrainsMono(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: textColor ?? AppColors.textPrimary,
        );

    final caret = TextSpan(
      text: '> ',
      style: baseStyle.copyWith(color: AppColors.primary),
    );

    final rest = TextSpan(
      text: text,
      style: baseStyle.copyWith(color: textColor ?? AppColors.textPrimary),
    );

    if (!blinkCaret) {
      return RichText(text: TextSpan(children: [caret, rest]));
    }

    return _BlinkingCaretRichText(caret: caret, rest: rest);
  }
}

class _BlinkingCaretRichText extends StatefulWidget {
  final TextSpan caret;
  final TextSpan rest;

  const _BlinkingCaretRichText({required this.caret, required this.rest});

  @override
  State<_BlinkingCaretRichText> createState() => _BlinkingCaretRichTextState();
}

class _BlinkingCaretRichTextState extends State<_BlinkingCaretRichText>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(vsync: this, duration: const Duration(milliseconds: 600))
      ..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        final caretOpacity = _c.value < 0.5 ? 1.0 : 0.0;
        return RichText(
          text: TextSpan(
            children: [
              TextSpan(
                text: widget.caret.text,
                style: widget.caret.style?.copyWith(
                  color: (widget.caret.style?.color ?? AppColors.primary)
                      .withValues(alpha: caretOpacity),
                ),
              ),
              widget.rest,
            ],
          ),
        );
      },
    );
  }
}

