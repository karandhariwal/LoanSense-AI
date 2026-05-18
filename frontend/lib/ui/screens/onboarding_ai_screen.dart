import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class OnboardingAIScreen extends StatefulWidget {
  final VoidCallback onNext;

  const OnboardingAIScreen({
    super.key,
    required this.onNext,
  });

  @override
  State<OnboardingAIScreen> createState() => _OnboardingAIScreenState();
}

class _OnboardingAIScreenState extends State<OnboardingAIScreen>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _pulseController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      body: Stack(
        children: [
          // Background Decorative Elements
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 500,
              height: 500,
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
            bottom: -100,
            left: -100,
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFDBC3A8).withValues(alpha: 0.05),
              ),
              child: BackdropFilter(
                filter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(color: Colors.transparent),
              ),
            ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                // Progress Indicator
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 24),
                  child: Row(
                    children: [
                      Expanded(child: _buildProgressSegment(true)),
                      const SizedBox(width: 4),
                      Expanded(child: _buildProgressSegment(true, hasShadow: true)),
                      const SizedBox(width: 4),
                      Expanded(child: _buildProgressSegment(false)),
                    ],
                  ),
                ),

                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // AI Scanning Illustration
                        Center(
                          child: _buildScanningIllustration(),
                        ),
                        const SizedBox(height: 32),

                        // Badge
                        _buildBadge(),
                        const SizedBox(height: 16),

                        // Title
                        RichText(
                          text: TextSpan(
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 40,
                              fontWeight: FontWeight.w700,
                              height: 1.1,
                              color: const Color(0xFFE5E2E3),
                            ),
                            children: [
                              const TextSpan(text: 'AI that reads the '),
                              TextSpan(
                                text: 'fine print',
                                style: GoogleFonts.spaceGrotesk(
                                  fontStyle: FontStyle.italic,
                                  color: const Color(0xFFC3C6D7),
                                ),
                              ),
                              const TextSpan(text: ' for you.'),
                            ],
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Subtitle
                        Text(
                          'Our advanced algorithms analyze loan documents in milliseconds, uncovering hidden risks and complex legal jargon that traditional checks miss.',
                          style: GoogleFonts.inter(
                            fontSize: 16,
                            height: 1.6,
                            color: const Color(0xFFC7C6CC),
                          ),
                        ),
                        const SizedBox(height: 32),

                        // Feature Grid
                        _buildFeatureGrid(),
                        const SizedBox(height: 100), // Space for fixed button
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),

          // Bottom Navigation Action
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildBottomAction(),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressSegment(bool isActive, {bool hasShadow = false}) {
    return Container(
      height: 4,
      decoration: BoxDecoration(
        color: isActive ? const Color(0xFFC3C6D7) : const Color(0xFF353436),
        borderRadius: BorderRadius.circular(99),
        boxShadow: hasShadow
            ? [
                BoxShadow(
                  color: const Color(0xFFC3C6D7).withValues(alpha: 0.6),
                  blurRadius: 10,
                  spreadRadius: 0,
                )
              ]
            : null,
      ),
    );
  }

  Widget _buildBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFC3C6D7).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: const Color(0xFFC3C6D7).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.auto_awesome, size: 14, color: Color(0xFFC3C6D7)),
          const SizedBox(width: 8),
          Text(
            'NEURAL SCAN ACTIVE',
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              letterSpacing: 1.2,
              color: const Color(0xFFC3C6D7),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildScanningIllustration() {
    return Container(
      width: double.infinity,
      height: 280,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Stack(
            children: [
              // Background Image/Illustration
              Opacity(
                opacity: 0.4,
                child: Image.network(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuAUcvXub55cfuCSFYG-GyJI0sea60t_g8JdEJLo6evO8jY5VbftA3RhbGPoG1UoeIV9gvmEHZak7DhQR6FsPorpezQRPuI6Hkph0dGnD_4kVeMQeVH0mDQspRB1cJgs63PDFJAvmWT0BUOQtDMAbndNIA8NKGNQWbZTmL2pQFuL6EYjz-qYt3w0k9qGJW51BZhnTmu26IssWpZohWAfUd_bqvuEtb2XSrfHZWbaRDilHKF-nm27AEhqGZf6qmhzDSNizVPnxiFQ9w',
                  fit: BoxFit.cover,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),

              // UI Overlay
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    // Header Bar
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: const Color(0xFF201F20).withValues(alpha: 0.8),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Row(
                            children: [
                              const Icon(Icons.description, size: 18, color: Color(0xFFC3C6D7)),
                              const SizedBox(width: 8),
                              Text(
                                'LOAN_AGREEMENT_V4.PDF',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w500,
                                  color: const Color(0xFFE5E2E3),
                                ),
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              AnimatedBuilder(
                                animation: _pulseController,
                                builder: (context, child) {
                                  return Container(
                                    width: 6,
                                    height: 6,
                                    decoration: BoxDecoration(
                                      shape: BoxShape.circle,
                                      color: const Color(0xFFC3C6D7).withValues(alpha: _pulseController.value),
                                    ),
                                  );
                                },
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'SCANNING...',
                                style: GoogleFonts.inter(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFC3C6D7),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // Floating Insight Capsules
                    Expanded(
                      child: Stack(
                        children: [
                          // Scanning Line
                          AnimatedBuilder(
                            animation: _scanController,
                            builder: (context, child) {
                              return Positioned(
                                top: _scanController.value * 160,
                                left: 0,
                                right: 0,
                                child: Container(
                                  height: 2,
                                  decoration: BoxDecoration(
                                    gradient: LinearGradient(
                                      colors: [
                                        Colors.transparent,
                                        const Color(0xFFC3C6D7).withValues(alpha: 0.8),
                                        Colors.transparent,
                                      ],
                                    ),
                                    boxShadow: [
                                      BoxShadow(
                                        color: const Color(0xFFC3C6D7).withValues(alpha: 0.5),
                                        blurRadius: 10,
                                      )
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                          Positioned(
                            top: 10,
                            right: 0,
                            child: _buildInsightCapsule(
                              icon: Icons.warning,
                              text: 'Hidden Pre-payment Penalty Detected',
                              color: const Color(0xFFFFB4AB),
                            ),
                          ),
                          Positioned(
                            top: 60,
                            left: 0,
                            child: _buildInsightCapsule(
                              icon: Icons.priority_high,
                              text: 'Variable Interest Rate Trigger',
                              color: const Color(0xFFDBC3A8),
                            ),
                          ),
                          Positioned(
                            top: 110,
                            left: 40,
                            child: _buildInsightCapsule(
                              icon: Icons.check_circle,
                              text: 'Standard Processing Fees Verified',
                              color: const Color(0xFFC3C6D7),
                            ),
                          ),
                        ],
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

  Widget _buildInsightCapsule({
    required IconData icon,
    required String text,
    required Color color,
  }) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(99),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(99),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 14, color: color),
              const SizedBox(width: 8),
              Text(
                text,
                style: GoogleFonts.inter(
                  fontSize: 10,
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

  Widget _buildFeatureGrid() {
    return Column(
      children: [
        _buildFeatureCard(
          icon: Icons.search_outlined,
          title: 'Hidden fee detection',
          subtitle: 'AI unmasks buried service charges and administrative costs hidden in footnotes.',
          iconColor: const Color(0xFFC3C6D7),
        ),
        const SizedBox(height: 16),
        _buildFeatureCard(
          icon: Icons.gavel_outlined,
          title: 'Trap clause alerts',
          subtitle: 'Immediate warnings for restrictive covenants and aggressive recovery terms.',
          iconColor: const Color(0xFFDBC3A8),
        ),
        const SizedBox(height: 16),
        _buildFeatureCard(
          icon: Icons.compare_outlined,
          title: 'AI loan comparison',
          subtitle: 'Cross-reference terms against market standards for total transparency.',
          iconColor: const Color(0xFFC3C6D7),
        ),
        const SizedBox(height: 16),
        _buildFeatureCard(
          icon: Icons.translate_outlined,
          title: 'Hindi explanations',
          subtitle: 'Simplifying complex legal English into clear, conversational Hindi insights.',
          iconColor: const Color(0xFFC6C6CD),
        ),
      ],
    );
  }

  Widget _buildFeatureCard({
    required IconData icon,
    required String title,
    required String subtitle,
    required Color iconColor,
  }) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: iconColor.withValues(alpha: 0.2)),
            ),
            child: Icon(icon, size: 20, color: iconColor),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFE5E2E3),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            subtitle,
            style: GoogleFonts.inter(
              fontSize: 12,
              height: 1.4,
              color: const Color(0xFFC7C6CC),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBottomAction() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.bottomCenter,
          end: Alignment.topCenter,
          colors: [
            const Color(0xFF131314),
            const Color(0xFF131314).withValues(alpha: 0.9),
            Colors.transparent,
          ],
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: InkWell(
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
                const Icon(Icons.arrow_forward_rounded,
                    color: Color(0xFF1A1B21), size: 24),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
