import 'package:flutter/material.dart';
import 'dart:ui';

/// A reusable glassmorphism card widget that matches the reference design.
/// Features:
/// - Semi-transparent background with backdrop blur
/// - Subtle white border with low opacity
/// - Animated scan-line decorative element
/// - 2rem (32px) rounded corners
class AuthGlassCard extends StatelessWidget {
  final Widget child;
  final double borderRadius;
  final double blurSigma;
  final double backgroundOpacity;
  final double borderOpacity;

  const AuthGlassCard({
    super.key,
    required this.child,
    this.borderRadius = 32.0,
    this.blurSigma = 20.0,
    this.backgroundOpacity = 0.03,
    this.borderOpacity = 0.12,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(borderRadius),
        border: Border.all(
          color: Colors.white.withValues(alpha: borderOpacity),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.25),
            blurRadius: 50,
            spreadRadius: -12,
            offset: const Offset(0, 25),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(borderRadius),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: blurSigma, sigmaY: blurSigma),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: backgroundOpacity),
              borderRadius: BorderRadius.circular(borderRadius),
            ),
            child: Stack(
              children: [
                // Scan line at top
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  child: Container(
                    height: 1,
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          const Color(0xFFC3C6D7).withValues(alpha: 0),
                          const Color(0xFFC3C6D7).withValues(alpha: 0.3),
                          const Color(0xFFC3C6D7).withValues(alpha: 0),
                        ],
                      ),
                    ),
                  ),
                ),
                // Content
                child,
              ],
            ),
          ),
        ),
      ),
    );
  }
}
