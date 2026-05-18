import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math' as math;

class SplashScreen extends StatefulWidget {
  final VoidCallback onInitializationComplete;

  const SplashScreen({
    super.key,
    required this.onInitializationComplete,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late AnimationController _scanController;
  late AnimationController _floatController;
  late AnimationController _loadingController;
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();

    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..forward();

    // Simulate initialization
    Future.delayed(const Duration(seconds: 5), () {
      widget.onInitializationComplete();
    });
  }

  @override
  void dispose() {
    _scanController.dispose();
    _floatController.dispose();
    _loadingController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: const Color(0xFF0E0E0F),
      body: Stack(
        children: [
          // Background Layers
          _buildBackground(size),

          // Animated Scanline
          _buildScanline(size),

          // Soft Particles
          ..._buildParticles(size),

          // Decorative Corner Gradients
          _buildCornerGradients(size),

          // Main Content
          _buildMainContent(size),

          // Footer Loading
          _buildFooter(size),
        ],
      ),
    );
  }

  Widget _buildBackground(Size size) {
    return Stack(
      children: [
        Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                Color(0xFF0A0E1A),
                Color(0xFF0E0E0F),
                Color(0xFF0E0E0F),
              ],
            ),
          ),
        ),
        // Background Atmospheric Image (Using the URL from the HTML)
        Opacity(
          opacity: 0.2,
          child: Image.network(
            'https://lh3.googleusercontent.com/aida-public/AB6AXuAEl6KnDFeSsjfDTRd-xBoRfE9N35GGJYEhUAClzPd_L5vsfB9E3Q5NImJ5VyHWA5wogE8xB-othJvOnlOYOUoNtuLsLqZYrclQsKWCVqAoJdHCZdNGa5aMqgO6mLHjbZcUK6wS6foIJvLwg3Y8ONsp405M3ILsxHbgLb57jCr0G-ehJkdGN21F9nHZ8naOk3u3Uri_brlQQ0IF2Ex6HoXcgl5IZEwzyKlmVnn5VDEx-UENcfqlSPe4Rl1R_-ZcyPnLeYKm1tf_TA',
            width: size.width,
            height: size.height,
            fit: BoxFit.cover,
            colorBlendMode: BlendMode.overlay,
          ),
        ),
      ],
    );
  }

  Widget _buildScanline(Size size) {
    return AnimatedBuilder(
      animation: _scanController,
      builder: (context, child) {
        return Positioned(
          top: (_scanController.value * (size.height + 100)) - 100,
          left: 0,
          right: 0,
          child: Container(
            height: 100,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  const Color(0xFFC3C6D7).withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  List<Widget> _buildParticles(Size size) {
    return [
      const _Particle(
        top: 0.1,
        left: 0.2,
        size: 4,
        delay: 0,
      ),
      const _Particle(
        top: 0.4,
        left: 0.8,
        size: 8,
        delay: 1000,
      ),
      const _Particle(
        top: 0.7,
        left: 0.15,
        size: 4,
        delay: 2000,
      ),
      const _Particle(
        top: 0.85,
        left: 0.6,
        size: 12,
        delay: 1500,
      ),
      const _Particle(
        top: 0.3,
        left: 0.45,
        size: 4,
        delay: 500,
      ),
    ];
  }

  Widget _buildCornerGradients(Size size) {
    return Stack(
      children: [
        Positioned(
          top: -250,
          right: -250,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFC3C6D7).withValues(alpha: 0.05),
            ),
            child: const DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
              ),
            ),
          ),
        ),
        Positioned(
          bottom: -250,
          left: -250,
          child: Container(
            width: 500,
            height: 500,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: const Color(0xFFDBC3A8).withValues(alpha: 0.05),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMainContent(Size size) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Logo Section
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Transform.translate(
                offset: Offset(0, -20 * math.sin(_floatController.value * 2 * math.pi)),
                child: child,
              );
            },
            child: _buildLogo(),
          ),
          const SizedBox(height: 32),
          // Typography
          FadeTransition(
            opacity: _fadeController,
            child: Column(
              children: [
                RichText(
                  text: TextSpan(
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 32,
                      fontWeight: FontWeight.w600,
                      color: const Color(0xFFE5E2E3),
                      letterSpacing: -0.5,
                    ),
                    children: const [
                      TextSpan(text: 'LoanSense '),
                      TextSpan(
                        text: 'AI',
                        style: TextStyle(
                          color: Color(0xFFC3C6D7),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Understand loans before signing them.',
                  style: GoogleFonts.inter(
                    fontSize: 18,
                    color: const Color(0xFFE5E2E3).withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 48),
          // Risk Insight Capsule
          _buildCapsule(),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    return Container(
      width: 160,
      height: 160,
      decoration: BoxDecoration(
        color: const Color(0xFF201F20).withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC3C6D7).withValues(alpha: 0.2),
            blurRadius: 40,
            spreadRadius: 0,
          ),
          BoxShadow(
            color: const Color(0xFFC3C6D7).withValues(alpha: 0.1),
            blurRadius: 80,
            spreadRadius: 0,
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Center(
            child: ShaderMask(
              shaderCallback: (bounds) => const LinearGradient(
                colors: [Color(0xFFC3C6D7), Color(0xFF777B8A), Color(0xFFDBC3A8)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ).createShader(bounds),
              child: const Icon(
                Icons.sensors,
                size: 80,
                color: Colors.white,
              ),
            ),
          ),
          // Internal scan-line effect
          AnimatedBuilder(
            animation: _loadingController,
            builder: (context, child) {
              return Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                height: 80 * _loadingController.value,
                child: Container(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.bottomCenter,
                      end: Alignment.topCenter,
                      colors: [
                        const Color(0xFFC3C6D7).withValues(alpha: 0.1),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildCapsule() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFC3C6D7).withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: const Color(0xFFC3C6D7).withValues(alpha: 0.2)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.verified_user,
            color: Color(0xFFC3C6D7),
            size: 18,
          ),
          const SizedBox(width: 12),
          Text(
            'FINANCIAL INTELLIGENCE ACTIVE',
            style: GoogleFonts.inter(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: const Color(0xFFC3C6D7),
              letterSpacing: 2,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFooter(Size size) {
    return Positioned(
      bottom: 80,
      left: 0,
      right: 0,
      child: Column(
        children: [
          // Progress Bar
          Container(
            width: 256,
            height: 1,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(1),
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              children: [
                AnimatedBuilder(
                  animation: _loadingController,
                  builder: (context, child) {
                    return Positioned(
                      left: (size.width * _loadingController.value) - (size.width / 2),
                      width: 256,
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
                    );
                  },
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Text(
            'ANALYSING FINANCIAL TRANSPARENCY...',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 14,
              color: const Color(0xFFE5E2E3).withValues(alpha: 0.6),
              fontWeight: FontWeight.w500,
              letterSpacing: 2.8,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(3, (index) => _BounceDot(delay: index * 200)),
          ),
        ],
      ),
    );
  }
}

class _Particle extends StatefulWidget {
  final double top;
  final double left;
  final double size;
  final int delay;

  const _Particle({
    required this.top,
    required this.left,
    required this.size,
    required this.delay,
  });

  @override
  State<_Particle> createState() => _ParticleState();
}

class _ParticleState extends State<_Particle> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    return Positioned(
      top: size.height * widget.top,
      left: size.width * widget.left,
      child: FadeTransition(
        opacity: Tween<double>(begin: 0.3, end: 0.8).animate(_controller),
        child: Container(
          width: widget.size,
          height: widget.size,
          decoration: const BoxDecoration(
            color: Color(0xFFC3C6D7),
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }
}

class _BounceDot extends StatefulWidget {
  final int delay;
  const _BounceDot({required this.delay});

  @override
  State<_BounceDot> createState() => _BounceDotState();
}

class _BounceDotState extends State<_BounceDot> with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    Future.delayed(Duration(milliseconds: widget.delay), () {
      if (mounted) _controller.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) {
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 4),
          width: 4,
          height: 4,
          transform: Matrix4.translationValues(0, -4 * _controller.value, 0),
          decoration: const BoxDecoration(
            color: Color(0xFFC3C6D7),
            shape: BoxShape.circle,
          ),
        );
      },
    );
  }
}
