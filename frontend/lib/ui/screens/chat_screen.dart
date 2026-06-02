import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loansense_ai/ui/screens/loan_assistant_screen.dart';
import 'package:loansense_ai/presentation/providers/loan_providers.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final String loanId;
  const ChatScreen({super.key, required this.loanId});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> with SingleTickerProviderStateMixin {
  late final AnimationController _glowController;

  @override
  void initState() {
    super.initState();
    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final analysisAsync = ref.watch(analysisProvider(widget.loanId));

    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      body: Stack(
        children: [
          // 1. Cinematic Background Glow
          _buildBackgroundGradients(),

          // 2. Main Content
          SafeArea(
            child: analysisAsync.when(
              data: (report) {
                // Check for empty state
                if (report.lenderName == 'Unknown lender' && report.metrics.isEmpty) {
                  return _buildEmptyState();
                }
                return LoanAssistantScreen(report: report);
              },
              loading: () => _buildLoadingState(),
              error: (err, stack) => _buildErrorState(err.toString()),
            ),
          ),

          // 3. Subtle holographic noise overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.02,
                child: CustomPaint(painter: _NoiseOverlayPainter()),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBackgroundGradients() {
    return AnimatedBuilder(
      animation: _glowController,
      builder: (context, _) {
        final glowVal = _glowController.value;
        return Stack(
          children: [
            Positioned(
              top: -80,
              left: -80,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFFC3C6D7).withValues(alpha: 0.08 + glowVal * 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -100,
              right: -100,
              child: Container(
                width: 380,
                height: 380,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      const Color(0xFF6A728A).withValues(alpha: 0.04 + glowVal * 0.02),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildLoadingState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                AnimatedBuilder(
                  animation: _glowController,
                  builder: (context, child) {
                    return Container(
                      width: 120,
                      height: 120,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: const Color(0xFFC3C6D7).withValues(alpha: 0.12),
                          width: 1.5,
                        ),
                      ),
                      child: const CircularProgressIndicator(
                        strokeWidth: 3,
                        valueColor: AlwaysStoppedAnimation<Color>(Color(0xFFC3C6D7)),
                        backgroundColor: Colors.transparent,
                      ),
                    );
                  },
                ),
                const Icon(
                  Icons.smart_toy_outlined,
                  color: Color(0xFFC3C6D7),
                  size: 44,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'RETRIEVING AUDIT DATA',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: const Color(0xFFE5E2E3),
                letterSpacing: 2.0,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Extracting safety scoring & RAG citations from database...',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: const Color(0xFFC7C6CC),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(String errorMessage) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: _GlassCard(
          borderColor: const Color(0xFFFFB4AB).withValues(alpha: 0.3),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.error_outline_rounded, color: Color(0xFFFFB4AB), size: 32),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Audit Load Failed',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: const Color(0xFFFFB4AB),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                errorMessage,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFFE5E2E3),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () {
                    ref.invalidate(analysisProvider(widget.loanId));
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFB4AB),
                    foregroundColor: const Color(0xFF131314),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    elevation: 0,
                  ),
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(
                    'Retry Connection',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.5,
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

  Widget _buildEmptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: _GlassCard(
          borderColor: const Color(0xFFC3C6D7).withValues(alpha: 0.2),
          padding: const EdgeInsets.all(28),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.folder_open_rounded, color: Color(0xFFC3C6D7), size: 48),
              const SizedBox(height: 16),
              Text(
                'No Audit Found',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: const Color(0xFFE5E2E3),
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'This loan analysis contains no data or could not be found. Please return to the dashboard and upload again.',
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 14,
                  color: const Color(0xFFC7C6CC),
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                  },
                  style: OutlinedButton.styleFrom(
                    foregroundColor: const Color(0xFFE5E2E3),
                    side: BorderSide(color: const Color(0xFFC3C6D7).withValues(alpha: 0.3)),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Return to Dashboard',
                    style: GoogleFonts.inter(
                      fontWeight: FontWeight.w600,
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
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(16);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: const Color(0xFF201F20).withValues(alpha: 0.6),
            borderRadius: radius,
            border: Border.all(
              color: borderColor ?? Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _NoiseOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final random = Random(42);
    for (var i = 0; i < 180; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final s = random.nextDouble() * 1.2;
      paint.color = Colors.white.withValues(alpha: random.nextDouble() * 0.03);
      canvas.drawRect(Rect.fromLTWH(x, y, s, s), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoiseOverlayPainter oldDelegate) => false;
}

