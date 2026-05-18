import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class OnboardingTrustScreen extends StatefulWidget {
  final VoidCallback onNext;

  const OnboardingTrustScreen({
    super.key,
    required this.onNext,
  });

  @override
  State<OnboardingTrustScreen> createState() => _OnboardingTrustScreenState();
}

class _OnboardingTrustScreenState extends State<OnboardingTrustScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late Animation<double> _scanAnimation;
  bool _isImageCached = false;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();
    _scanAnimation =
        Tween<double>(begin: 0.0, end: 1.0).animate(_scanController);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isImageCached) {
      precacheImage(
        const NetworkImage(
            'https://lh3.googleusercontent.com/aida-public/AB6AXuArMBt3zcAY_46y7O3KkbvSkkUK9np5ZHaKJ7odXPqnTMtO7BvUGCqRK-In-Cc_mWm8v60_6-fVQSCBxmkQcvN8vjC-C9ayQX-htgZpf0crWal_6QM7Qzkh-OGoaKXjZLEIYyOmltsFWfnza1k6N8t2X4DRHfwNqXCkiGz2n9xeICWa7DWH6DK6dCjRV-RjmblbHJsnhFUTcliMBzv8qykKLW6sc33HCJOC7m2-hm6A4PMx4RCBtJZixHXHCLGcb6qRD9_S69bzDQ'),
        context,
      );
      _isImageCached = true;
    }
  }

  @override
  void dispose() {
    _scanController.dispose();
    super.dispose();
  }

  // --- Design Tokens (from HTML reference) ---
  static const primaryColor = Color(0xFFC3C6D7);
  //static const secondaryColor = Color(0xFFE3E2E9);
  static const tertiaryColor = Color(0xFFDBC3A8);
  static const bgColor = Color(0xFF131314);
  static const onSurface = Color(0xFFE5E2E3);
  static const onSurfaceVariant = Color(0xFFC7C6CC);
  static const surfaceContainer = Color(0xFF201F20);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: bgColor,
      body: Stack(
        children: [
          // Background Ambient Glow (matches HTML bg-primary/5 and bg-tertiary/5 blurs)
          Positioned.fill(
            child: Stack(
              children: [
                Positioned(
                  top: -80,
                  left: -80,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          primaryColor.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: -80,
                  right: -80,
                  child: Container(
                    width: 400,
                    height: 400,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: RadialGradient(
                        colors: [
                          tertiaryColor.withValues(alpha: 0.05),
                          Colors.transparent,
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Main scrollable content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  // Hero Illustration Section
                  _buildHeroIllustration(),
                  const SizedBox(height: 32),
                  // Typography Content
                  _buildTypography(),
                  const SizedBox(height: 32),
                  // Feature Grid (Trust Indicators)
                  _buildFeatureGrid(),
                  const SizedBox(height: 48),
                  // CTA Section
                  _buildCTA(),
                  const SizedBox(height: 24),
                  // Language Toggle
                  _buildLanguageToggle(),
                  const SizedBox(height: 60),
                ],
              ),
            ),
          ),

          // Step Indicator (fixed at bottom, matches HTML)
          Positioned(
            bottom: 40,
            left: 0,
            right: 0,
            child: _buildStepIndicator(primaryColor),
          ),
        ],
      ),
    );
  }

  /// Hero illustration: Full-bleed image inside a glass card,
  /// matching the HTML's `object-cover opacity-80` approach.
  Widget _buildHeroIllustration() {
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 400),
        child: AspectRatio(
          aspectRatio: 1.05, // Slightly wider than tall for mobile
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withValues(alpha: 0.10),
              ),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.15),
                  blurRadius: 40,
                  spreadRadius: -5,
                ),
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.4),
                  blurRadius: 30,
                  offset: const Offset(0, 15),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(24),
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // 1. Glass background
                  BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Container(
                      color: surfaceContainer.withValues(alpha: 0.6),
                    ),
                  ),

                  // 2. Full-bleed image (matches HTML: w-full h-full object-cover opacity-80)
                  Opacity(
                    opacity: 0.80,
                    child: Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuArMBt3zcAY_46y7O3KkbvSkkUK9np5ZHaKJ7odXPqnTMtO7BvUGCqRK-In-Cc_mWm8v60_6-fVQSCBxmkQcvN8vjC-C9ayQX-htgZpf0crWal_6QM7Qzkh-OGoaKXjZLEIYyOmltsFWfnza1k6N8t2X4DRHfwNqXCkiGz2n9xeICWa7DWH6DK6dCjRV-RjmblbHJsnhFUTcliMBzv8qykKLW6sc33HCJOC7m2-hm6A4PMx4RCBtJZixHXHCLGcb6qRD9_S69bzDQ',
                      fit: BoxFit.cover,
                      filterQuality: FilterQuality.high,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Center(
                          child: CircularProgressIndicator(
                            color: primaryColor.withValues(alpha: 0.3),
                            strokeWidth: 2,
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) => Center(
                        child: Icon(
                          Icons.security,
                          size: 100,
                          color: primaryColor.withValues(alpha: 0.3),
                        ),
                      ),
                    ),
                  ),

                  // 3. Subtle scan-line animation (matches HTML .scan-line)
                  AnimatedBuilder(
                    animation: _scanAnimation,
                    builder: (context, child) {
                      return CustomPaint(
                        painter: _ScanLinePainter(
                          progress: _scanAnimation.value,
                          color: primaryColor,
                        ),
                      );
                    },
                  ),

                  // 4. Floating Insight Capsules (matches HTML .absolute.top-6.right-6)
                  Positioned(
                    top: 20,
                    right: 20,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        _buildCapsule(Icons.verified_user, 'ENCRYPTION ACTIVE',
                            primaryColor),
                        const SizedBox(height: 10),
                        _buildCapsule(
                            Icons.translate, 'BILINGUAL AI', tertiaryColor),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCapsule(IconData icon, String label, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withValues(alpha: 0.10),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: color.withValues(alpha: 0.40)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 6),
              Text(
                label,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: color,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTypography() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.spaceGrotesk(
              fontSize: 42,
              fontWeight: FontWeight.w700,
              color: onSurface,
              height: 1.15,
              letterSpacing: -0.02 * 42,
            ),
            children: const [
              TextSpan(text: 'Built for\nevery '),
              TextSpan(
                text: 'borrower',
                style: TextStyle(
                  color: primaryColor,
                  fontStyle: FontStyle.italic,
                ),
              ),
              TextSpan(text: '.'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.inter(
              fontSize: 16,
              color: onSurfaceVariant.withValues(alpha: 0.80),
              height: 1.6,
            ),
            children: const [
              TextSpan(text: 'Understand loans in simple '),
              TextSpan(
                text: 'English',
                style: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
              ),
              TextSpan(text: ' or '),
              TextSpan(
                text: 'Hindi',
                style: TextStyle(color: onSurface, fontWeight: FontWeight.w600),
              ),
              TextSpan(
                  text:
                      ' with AI-powered explanations. No jargon, just clarity.'),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildFeatureGrid() {
    return Column(
      children: [
        _buildFeatureCard(
          Icons.security_update_good,
          'Risk Shield',
          'We scan fine print to alert you of hidden fees and predatory terms before you sign.',
          primaryColor,
        ),
        const SizedBox(height: 16),
        _buildFeatureCard(
          Icons.psychology,
          'Smart Clarity',
          'AI simplifies complex bank terminology into actionable advice for your unique situation.',
          tertiaryColor,
        ),
      ],
    );
  }

  Widget _buildFeatureCard(
      IconData icon, String title, String description, Color color) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: surfaceContainer.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, color: color, size: 24),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w600,
                        color: color,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      description,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        height: 1.6,
                        color: onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCTA() {
    return Column(
      children: [
        // CTA Button
        InkWell(
          onTap: widget.onNext,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: primaryColor,
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: primaryColor.withValues(alpha: 0.40),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Start Analysing Loans',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1B21),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(Icons.arrow_forward_rounded,
                    color: Color(0xFF1A1B21), size: 24),
              ],
            ),
          ),
        ),
        const SizedBox(height: 20),
        // Security badge
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.lock,
                size: 14, color: onSurfaceVariant.withValues(alpha: 0.60)),
            const SizedBox(width: 8),
            Text(
              'BANK-GRADE 256-BIT PROTECTION',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                letterSpacing: 2.0,
                color: onSurfaceVariant.withValues(alpha: 0.60),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildLanguageToggle() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildLanguageButton('ENGLISH', true),
        const SizedBox(width: 12),
        _buildLanguageButton('हिन्दी', false),
      ],
    );
  }

  Widget _buildLanguageButton(String label, bool isSelected) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
      decoration: BoxDecoration(
        color: isSelected
            ? primaryColor.withValues(alpha: 0.05)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
            color: isSelected
                ? primaryColor
                : Colors.white.withValues(alpha: 0.12)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSelected ? primaryColor : onSurfaceVariant,
        ),
      ),
    );
  }

  Widget _buildStepIndicator(Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        _buildDot(false, color),
        const SizedBox(width: 6),
        _buildDot(false, color),
        const SizedBox(width: 6),
        _buildDot(true, color),
      ],
    );
  }

  Widget _buildDot(bool isActive, Color color) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 300),
      width: isActive ? 32 : 8,
      height: 8,
      decoration: BoxDecoration(
        color: isActive ? color : Colors.white.withValues(alpha: 0.20),
        borderRadius: BorderRadius.circular(999),
        boxShadow: isActive
            ? [BoxShadow(color: color.withValues(alpha: 0.60), blurRadius: 8)]
            : null,
      ),
    );
  }
}

/// Minimal scan-line painter matching the HTML .scan-line animation
class _ScanLinePainter extends CustomPainter {
  final double progress;
  final Color color;

  _ScanLinePainter({required this.progress, required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final double y = progress * size.height;

    // Fade in the middle, fade out at edges (matches CSS opacity keyframes)
    final double opacity =
        progress < 0.5 ? (progress / 0.5) * 0.5 : (1.0 - progress) / 0.5 * 0.5;

    final Paint linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          color.withValues(alpha: opacity),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, y - 1, size.width, 2));

    canvas.drawRect(Rect.fromLTWH(0, y - 0.5, size.width, 1), linePaint);
  }

  @override
  bool shouldRepaint(covariant _ScanLinePainter oldDelegate) =>
      oldDelegate.progress != progress;
}
