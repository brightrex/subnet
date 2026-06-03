import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'name_selection_screen.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> with SingleTickerProviderStateMixin {
  bool _showText = false;
  Timer? _tick;
  double _t = 0;

  @override
  void initState() {
    super.initState();
    // Reduce lag by repainting ~12 FPS instead of every frame.
    _tick = Timer.periodic(const Duration(milliseconds: 80), (_) {
      setState(() {
        _t = (_t + 0.02) % 1.0;
      });
    });
    
    Future.delayed(const Duration(milliseconds: 2500), () {
      if (mounted) {
        setState(() {
          _showText = true;
        });
      }
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Matrix Background
          RepaintBoundary(
            child: CustomPaint(
              painter: MatrixPainter(_t),
            ),
          ),
          
          if (_showText)
            Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'subnet',
                    // Use the same font as the rest of the UI.
                    style: GoogleFonts.jetBrainsMono(
                      fontSize: 48,
                      color: const Color(0xFF00FF41),
                      fontWeight: FontWeight.bold,
                      shadows: [
                        const Shadow(
                          color: Color(0xFF00FF41),
                          blurRadius: 10,
                        )
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'no logs. no servers. just signal.',
                    style: GoogleFonts.jetBrainsMono(
                      color: const Color(0xFF00FF41).withValues(alpha: 0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 60),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.transparent,
                      side: const BorderSide(color: Color(0xFF00FF41), width: 2),
                      padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(4),
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushReplacement(
                        context,
                        MaterialPageRoute(builder: (context) => const NameSelectionScreen()),
                      );
                    },
                    child: Text(
                      'ENTER THE NETWORK',
                      style: GoogleFonts.jetBrainsMono(
                        color: const Color(0xFF00FF41),
                        fontWeight: FontWeight.bold,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class MatrixPainter extends CustomPainter {
  final double animationValue;
  const MatrixPainter(this.animationValue);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), paint);
    
    final textPainter = TextPainter(textDirection: TextDirection.ltr);
    final random = Random(42); 
    
    for (int col = 0; col < 30; col++) {
      final x = (size.width / 30) * col;
      final speed = 0.5 + random.nextDouble(); 
      final yOffset = ((animationValue * speed * 2000) % size.height);
      
      for (int row = 0; col % 2 == 0 ? row < 20 : row < 12; row++) {
        final y = (yOffset - (row * 20)) % size.height;
        final alpha = 255 - (row * 10);
        if (alpha < 0) continue;
        
        final charCode = 33 + random.nextInt(90);
        
        textPainter.text = TextSpan(
          text: String.fromCharCode(charCode),
          style: GoogleFonts.jetBrainsMono(
            color: const Color(0xFF00FF41).withValues(alpha: alpha / 255.0),
            fontSize: 16,
          ),
        );
        textPainter.layout();
        textPainter.paint(canvas, Offset(x, y));
      }
    }
  }

  @override
  bool shouldRepaint(covariant MatrixPainter oldDelegate) {
    return oldDelegate.animationValue != animationValue;
  }
}
