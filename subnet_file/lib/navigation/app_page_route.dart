import 'package:flutter/material.dart';

class AppPageRoute {
  static PageRoute<T> slideRight<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }

  static PageRoute<T> slideUp<T>(Widget page) {
    return PageRouteBuilder<T>(
      transitionDuration: const Duration(milliseconds: 250),
      reverseTransitionDuration: const Duration(milliseconds: 250),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, animation, __, child) {
        final curved = CurvedAnimation(parent: animation, curve: Curves.easeInOut);
        return SlideTransition(
          position: Tween<Offset>(begin: const Offset(0, 0.08), end: Offset.zero).animate(curved),
          child: FadeTransition(opacity: Tween<double>(begin: 0.0, end: 1.0).animate(curved), child: child),
        );
      },
    );
  }
}

