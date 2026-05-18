import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;
import 'dart:ui';
import 'package:loansense_ai/ui/widgets/auth/auth_glass_card.dart';
import 'package:loansense_ai/ui/widgets/auth/auth_button.dart';
import 'package:loansense_ai/ui/widgets/auth/google_logo.dart';
import 'package:loansense_ai/ui/widgets/auth/security_divider.dart';
import 'package:loansense_ai/ui/widgets/auth/trust_capsule.dart';

/// Authentication screen for LoanSense AI.
///
/// Matches the reference design pixel-for-pixel:
/// - Futuristic dark background (#131314) with atmospheric gradient orbs
/// - Background abstract image at 20% opacity
/// - Header: account_balance icon (40px) + "LoanSense AI" (32px Space Grotesk bold)
/// - Subtitle: "Welcome to LoanSense AI" (18px Inter)
/// - Glassmorphism card: "Secure Access" heading + auth buttons
/// - Google sign-in button with multicolor logo
/// - Phone sign-in button with phone_iphone icon
/// - "SECURED BY AI" futuristic divider
/// - Trust capsule with verified_user icon
/// - Footer: lock icon + "END-TO-END ENCRYPTION" + privacy text
/// - Bottom gradient overlay
///
/// Layout: vertically centered content, px-margin (40px) horizontal padding
/// Card: w-full max-w-md, p-lg (48px), rounded-[2rem] (32px)
class AuthScreen extends StatefulWidget {
  final VoidCallback? onGoogleSignIn;
  final VoidCallback? onPhoneSignIn;

  const AuthScreen({
    super.key,
    this.onGoogleSignIn,
    this.onPhoneSignIn,
  });

  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen>
    with TickerProviderStateMixin {
  // Atmospheric pulse for ambient glow
  late AnimationController _pulseController;
  // Fade-in for content entrance
  late AnimationController _fadeController;
  // Staggered entrance for card content
  late AnimationController _staggerController;
  // Subtle floating effect for the logo
  late AnimationController _floatController;

  @override
  void initState() {
    super.initState();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..forward();

    _staggerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..forward();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _fadeController.dispose();
    _staggerController.dispose();
    _floatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      body: Stack(
        children: [
          // Layer 0: Background atmospheric gradients
          RepaintBoundary(child: _buildBackgroundGradients(size)),

          // Layer 1: Background abstract image
          _buildBackgroundImage(size),

          // Layer 2: Main scrollable content
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 40),
                  child: FadeTransition(
                    opacity: _fadeController,
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Header Section
                        _buildHeader(),

                        const SizedBox(height: 48), // mb-lg

                        // Glassmorphism Login Card
                        _buildLoginCard(),

                        const SizedBox(height: 48), // mt-lg

                        // Footer Section
                        _buildFooter(),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Layer 3: Bottom gradient overlay
          _buildBottomGradient(),
        ],
      ),
    );
  }

  // ─── BACKGROUND GRADIENTS ──────────────────────────────────────────
  Widget _buildBackgroundGradients(Size size) {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, child) {
        final pulseVal = _pulseController.value;
        return Stack(
          children: [
            // Top-left primary glow orb
            Positioned(
              top: -size.height * 0.1,
              left: -size.width * 0.1,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 120, sigmaY: 120),
                child: Container(
                  width: size.width * 0.5,
                  height: size.height * 0.5,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFC3C6D7).withValues(
                      alpha: 0.10 + 0.03 * pulseVal,
                    ),
                  ),
                ),
              ),
            ),
            // Bottom-right tertiary glow orb
            Positioned(
              bottom: -size.height * 0.1,
              right: -size.width * 0.1,
              child: ImageFiltered(
                imageFilter: ImageFilter.blur(sigmaX: 100, sigmaY: 100),
                child: Container(
                  width: size.width * 0.4,
                  height: size.height * 0.4,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: const Color(0xFFDBC3A8).withValues(
                      alpha: 0.05 + 0.02 * pulseVal,
                    ),
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  // ─── BACKGROUND IMAGE ──────────────────────────────────────────────
  Widget _buildBackgroundImage(Size size) {
    return Positioned.fill(
      child: RepaintBoundary(
        child: Opacity(
          opacity: 0.20,
        child: Image.network(
          'https://lh3.googleusercontent.com/aida-public/AB6AXuCTPJoMHW5y-BwbjowyxOk8fCSvzi8QVXp3u_ZQ2nloqEvYZ24qzDsHFSkRG0Gj3RuNPgYt21yMTghgNzXcc3-QCWOZZn_rTbj5ZuUmFMG0fWCB29PxTJpuEX6qdFP2zZg-PhVhEiozke_nOavLVWDDL_qPqz5sNNvvZ2g9Fnw9SI8tMtk1MAoA9Sgxc9guVeApc7d-QCHeXpRT2bOcg7AO8FN4xFPhsWGcKs47PQc6RVyy9rERbXQA5pW2h7NkuHG8afqlE3yxPw',
          fit: BoxFit.cover,
          width: size.width,
          height: size.height,
          errorBuilder: (context, error, stackTrace) {
            // Fallback: subtle gradient if image fails to load
            return Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    const Color(0xFF0A0E1A).withValues(alpha: 0.3),
                    const Color(0xFF131314),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    ),
  );
  }

  // ─── HEADER SECTION ────────────────────────────────────────────────
  Widget _buildHeader() {
    return AnimatedBuilder(
      animation: _floatController,
      builder: (context, child) {
        return Transform.translate(
          offset: Offset(
            0,
            -4 * math.sin(_floatController.value * math.pi),
          ),
          child: child,
        );
      },
      child: Column(
        children: [
          // Logo + Title row
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Account balance icon matching reference (40px, primary color)
              const Icon(
                Icons.account_balance_outlined,
                size: 40,
                color: Color(0xFFC3C6D7),
              ),
              const SizedBox(width: 8), // gap-base
              // "LoanSense AI" title: Space Grotesk, 32px, bold, primary, tight tracking
              Text(
                'LoanSense AI',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 32,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFC3C6D7),
                  letterSpacing: -0.8,
                  height: 1.2,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12), // mb-sm
          // Subtitle: Inter, 18px, on-surface-variant
          Text(
            'Welcome to LoanSense AI',
            style: GoogleFonts.inter(
              fontSize: 18,
              fontWeight: FontWeight.w400,
              color: const Color(0xFFC7C6CC),
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }

  // ─── LOGIN CARD ────────────────────────────────────────────────────
  Widget _buildLoginCard() {
    // Staggered entrance intervals
    final cardSlide = Tween<Offset>(
      begin: const Offset(0, 0.05),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _staggerController,
      curve: const Interval(0.0, 0.5, curve: Curves.easeOutCubic),
    ));

    final cardOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );

    return SlideTransition(
      position: cardSlide,
      child: FadeTransition(
        opacity: cardOpacity,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 448), // max-w-md
          child: AuthGlassCard(
            borderRadius: 32, // rounded-[2rem]
            child: Padding(
              padding: const EdgeInsets.all(48), // p-lg
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // ── Card header ──
                  _buildCardHeader(),
                  const SizedBox(height: 32), // gap-md (24) + mb-base (8) = 32

                  // ── Auth Buttons ──
                  _buildAuthButtons(),
                  const SizedBox(height: 24), // gap-md

                  // ── Security Divider ──
                  const SecurityDivider(),
                  const SizedBox(height: 24), // gap-md

                  // ── Trust Capsule ──
                  const TrustCapsule(),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildCardHeader() {
    return Column(
      children: [
        // "Secure Access": Space Grotesk, 24px, 500, on-surface
        Text(
          'Secure Access',
          textAlign: TextAlign.center,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 24,
            fontWeight: FontWeight.w500,
            color: const Color(0xFFE5E2E3),
            height: 1.3,
          ),
        ),
        const SizedBox(height: 4), // mb-xs
        // "IDENTIFY YOURSELF TO CONTINUE": Inter, 12px, 600, uppercase, widest tracking
        Text(
          'IDENTIFY YOURSELF TO CONTINUE',
          textAlign: TextAlign.center,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFC7C6CC),
            letterSpacing: 1.2,
            height: 1.0,
          ),
        ),
      ],
    );
  }

  Widget _buildAuthButtons() {
    // Staggered button entrance
    final btn1Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.3, 0.7, curve: Curves.easeOut),
      ),
    );
    final btn2Opacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.5, 0.9, curve: Curves.easeOut),
      ),
    );

    return Column(
      children: [
        // Google Sign-In Button
        FadeTransition(
          opacity: btn1Opacity,
          child: AuthButton(
            icon: const GoogleLogo(size: 20),
            label: 'Continue with Google',
            onTap: widget.onGoogleSignIn,
          ),
        ),
        const SizedBox(height: 12), // gap-sm
        // Phone Sign-In Button
        FadeTransition(
          opacity: btn2Opacity,
          child: AuthButton(
            iconBuilder: (isPressed) => Icon(
              Icons.phone_iphone,
              color: isPressed 
                  ? const Color(0xFFC3C6D7) 
                  : const Color(0xFFC7C6CC),
              size: 24,
            ),
            label: 'Continue with Phone Number',
            onTap: widget.onPhoneSignIn,
          ),
        ),
      ],
    );
  }

  // ─── FOOTER SECTION ────────────────────────────────────────────────
  Widget _buildFooter() {
    final footerOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _staggerController,
        curve: const Interval(0.7, 1.0, curve: Curves.easeOut),
      ),
    );

    return FadeTransition(
      opacity: footerOpacity,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 320), // max-w-xs
        child: Column(
          children: [
            // Lock icon + "END-TO-END ENCRYPTION"
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.lock,
                  size: 14,
                  color: const Color(0xFFC3C6D7).withValues(alpha: 0.60),
                ),
                const SizedBox(width: 4), // gap-xs
                Text(
                  'END-TO-END ENCRYPTION',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFC3C6D7).withValues(alpha: 0.60),
                    letterSpacing: -0.6,
                    height: 1.0,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 4), // mb-xs
            // Privacy text
            Text(
              'Your loan documents are encrypted and private.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: FontWeight.w400,
                color: const Color(0xFFC7C6CC).withValues(alpha: 0.60),
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── BOTTOM GRADIENT OVERLAY ───────────────────────────────────────
  Widget _buildBottomGradient() {
    return Positioned(
      bottom: 0,
      left: 0,
      right: 0,
      child: RepaintBoundary(
        child: IgnorePointer(
          child: Container(
          height: 128, // h-32 (8 * 16px = 128)
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.bottomCenter,
              end: Alignment.topCenter,
              colors: [
                const Color(0xFF131314),
                const Color(0xFF131314).withValues(alpha: 0.0),
              ],
            ),
          ),
        ),
      ),
    ),
  );
  }
}
