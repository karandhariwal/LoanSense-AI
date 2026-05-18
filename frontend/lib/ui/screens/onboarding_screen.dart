import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class OnboardingScreen extends StatefulWidget {
  final VoidCallback onNext;

  const OnboardingScreen({
    super.key,
    required this.onNext,
  });

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _pulseController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..forward();
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      body: Stack(
        children: [
          // Background Ambient Gradients
          _buildBackgroundGradients(size),

          // Main Content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  const SizedBox(height: 40),
                  // Hero Illustration Container
                  _buildHeroIllustration(size),
                  const SizedBox(height: 48),
                  // Text Content Section
                  _buildTextContent(),
                  const SizedBox(height: 80),
                  // Navigation Section
                  _buildNavigationSection(),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),

          // Footer decoration
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildBackgroundGradients(Size size) {
    return Stack(
      children: [
        Positioned(
          top: -size.height * 0.1,
          left: -size.width * 0.1,
          child: Container(
            width: size.width * 0.5,
            height: size.width * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFC3C6D7).withValues(alpha: 0.05),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
        Positioned(
          bottom: -size.height * 0.1,
          right: -size.width * 0.1,
          child: Container(
            width: size.width * 0.5,
            height: size.width * 0.5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFC6C6CD).withValues(alpha: 0.05),
            ),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
              child: Container(color: Colors.transparent),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildHeroIllustration(Size size) {
    return Center(
      child: Container(
        constraints: const BoxConstraints(maxWidth: 512),
        child: AspectRatio(
          aspectRatio: 4 / 3,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              // Glow Effect behind the card
              AnimatedBuilder(
                animation: _pulseController,
                builder: (context, child) {
                  return Positioned(
                    top: -16,
                    left: -16,
                    right: -16,
                    bottom: -16,
                    child: Container(
                      decoration: BoxDecoration(
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFFFB4AB).withValues(
                                alpha: 0.15 + (0.1 * _pulseController.value)),
                            blurRadius: 48,
                            spreadRadius: 8,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              // Main Glass Card
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.12),
                  ),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(24),
                  child: BackdropFilter(
                    filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(16),
                        child: Stack(
                          children: [
                            // Background Image
                            Opacity(
                              opacity: 0.6,
                              child: Image.network(
                                'https://lh3.googleusercontent.com/aida-public/AB6AXuDfgWS1s31SYcLEFTKuq1H1mBheNIY4mH1GjVAK2UHbJBjFxPbcQwtFigIXSG5-DUf177qaXlADNgthq8PDkZ5WGrdDdlG4RwYsEEf5_Bdzi8j0Q6_uKYsUTwWhojs1_9h1-QtahTamFz2_OpAiPQcV4qHtDBZ-qSWa7828hOPIERycysbItOd0Bynre0pFl7Imqv3NpMlClsrtZO3e9q05MqSwnFqvJCyH7Aue-ZCpwENzxvKiyB9021aEq8N14VIKTkWanqLo-w',
                                fit: BoxFit.cover,
                                width: double.infinity,
                                height: double.infinity,
                              ),
                            ),

                            // Animated Scan Line
                            AnimatedBuilder(
                              animation: _scanController,
                              builder: (context, child) {
                                return Positioned(
                                  top: _scanController.value * 400, // Relative to card height
                                  left: 0,
                                  right: 0,
                                  child: Opacity(
                                    opacity: 0.5,
                                    child: Container(
                                      height: 1,
                                      decoration: const BoxDecoration(
                                        gradient: LinearGradient(
                                          colors: [
                                            Colors.transparent,
                                            Color(0xFFC3C6D7),
                                            Colors.transparent,
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                );
                              },
                            ),

                            // Risk Insight Capsules - Positioned relatively
                            Align(
                              alignment: const Alignment(-0.5, -0.5),
                              child: _buildRiskCapsule(
                                icon: Icons.warning_amber_rounded,
                                label: 'Floating Interest Trap',
                              ),
                            ),
                            Align(
                              alignment: const Alignment(0.5, 0.33),
                              child: _buildRiskCapsule(
                                icon: Icons.priority_high_rounded,
                                label: 'Hidden Service Fees',
                              ),
                            ),

                            // AI Analysis UI elements
                            Positioned(
                              top: 24,
                              right: 24,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFC3C6D7).withValues(alpha: 0.4),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Container(
                                    width: 32,
                                    height: 4,
                                    decoration: BoxDecoration(
                                      color: const Color(0xFFC3C6D7).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(99),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRiskCapsule({
    required IconData icon,
    required String label,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(
          color: const Color(0xFFFFB4AB).withValues(alpha: 0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFFFB4AB).withValues(alpha: 0.4),
            blurRadius: 15,
            spreadRadius: 0,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                color: const Color(0xFFFFB4AB),
                size: 16,
              ),
              const SizedBox(width: 4),
              Text(
                label,
                style: GoogleFonts.inter(
                  color: const Color(0xFFFFB4AB),
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextContent() {
    return Column(
      children: [
        RichText(
          textAlign: TextAlign.center,
          text: TextSpan(
            style: GoogleFonts.spaceGrotesk(
              fontSize: 48,
              height: 1.1,
              letterSpacing: -0.02 * 48,
              fontWeight: FontWeight.w700,
              color: const Color(0xFFE5E2E3),
            ),
            children: [
              const TextSpan(text: 'Banks explain EMIs. \n'),
              TextSpan(
                text: 'Not the hidden risks.',
                style: TextStyle(
                  color: const Color(0xFFC3C6D7).withValues(alpha: 0.9),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        Text(
          'LoanSense AI scans agreements and reveals hidden charges, risky clauses, and real repayment costs.',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 18,
            height: 1.6,
            color: const Color(0xFFC7C6CC),
            fontWeight: FontWeight.w400,
          ),
        ),
      ],
    );
  }

  Widget _buildNavigationSection() {
    return Column(
      children: [
        InkWell(
          onTap: widget.onNext,
          borderRadius: BorderRadius.circular(999),
          child: Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 20),
            decoration: BoxDecoration(
              color: const Color(0xFFC3C6D7),
              borderRadius: BorderRadius.circular(999),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFC3C6D7).withValues(alpha: 0.40),
                  blurRadius: 20,
                  spreadRadius: 0,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Next',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF1A1B21),
                  ),
                ),
                const SizedBox(width: 10),
                const Icon(
                  Icons.arrow_forward_rounded,
                  color: Color(0xFF1A1B21),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 48),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 32,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFFC3C6D7),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF353436),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 8,
              height: 4,
              decoration: BoxDecoration(
                color: const Color(0xFF353436),
                borderRadius: BorderRadius.circular(99),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildFooter() {
    return Positioned(
      bottom: 40,
      left: 0,
      right: 0,
      child: Center(
        child: Opacity(
          opacity: 0.2,
          child: Text(
            'L-SENSE // UNIT 01 ANALYSIS',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              fontWeight: FontWeight.w500,
              letterSpacing: 0.3 * 14,
              color: const Color(0xFFC7C6CC),
            ),
          ),
        ),
      ),
    );
  }
}
