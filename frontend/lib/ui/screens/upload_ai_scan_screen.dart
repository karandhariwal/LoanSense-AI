import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:math';
import 'dart:ui';
import 'package:loansense_ai/ui/screens/analysis_report_screen.dart';
import 'package:loansense_ai/presentation/providers/loan_providers.dart';
import 'package:loansense_ai/presentation/providers/active_loan_provider.dart';
import 'package:loansense_ai/core/error/exceptions.dart';

// ─── Color Palette (from reference design tokens) ───
class _ScanColors {
  static const background = Color(0xFF131314);
  // ignore: unused_field
  static const surface = Color(0xFF131314);
  static const surfaceContainer = Color(0xFF201F20);
  static const surfaceContainerHighest = Color(0xFF353436);
  static const primary = Color(0xFFC3C6D7);
  static const secondary = Color(0xFFC6C6CD);
  static const onSurface = Color(0xFFE5E2E3);
  static const onSurfaceVariant = Color(0xFFC7C6CC);
  static const onPrimaryContainer = Color(0xFF777B8A);
}

// ─── Analysis Step Model ───
enum StepStatus { complete, processing, pending }

class _AnalysisStep {
  final String label;
  final StepStatus status;
  const _AnalysisStep({required this.label, required this.status});
}

// ─── Main Screen ───
class UploadAiScanScreen extends ConsumerStatefulWidget {
  final String fileName;
  final double fileSizeMb;
  final String? filePath;

  const UploadAiScanScreen({
    super.key,
    required this.fileName,
    required this.fileSizeMb,
    this.filePath,
  });

  @override
  ConsumerState<UploadAiScanScreen> createState() => _UploadAiScanScreenState();
}

class _UploadAiScanScreenState extends ConsumerState<UploadAiScanScreen>
    with TickerProviderStateMixin {
  late final AnimationController _scanlineController;
  late final AnimationController _pulseController;
  late final AnimationController _progressController;
  late final AnimationController _floatController;
  late final AnimationController _glowController;

  late List<_AnalysisStep> _steps;
  String? _errorMessage;
  bool _isNavigating = false;
  String _pollingMessage = 'AI is identifying 14 critical nodes in your loan agreement.';

  @override
  void initState() {
    super.initState();

    _steps = [
      const _AnalysisStep(
          label: 'Uploading document...', status: StepStatus.pending),
      const _AnalysisStep(
          label: 'Extracting loan terms...', status: StepStatus.pending),
      const _AnalysisStep(
          label: 'Analysing hidden clauses...', status: StepStatus.pending),
      const _AnalysisStep(
          label: 'Generating AI insights...', status: StepStatus.pending),
    ];

    _scanlineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    )..repeat();

    _progressController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );

    _floatController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat(reverse: true);

    _glowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startBackendProcessing();
    });
  }

  Future<void> _startBackendProcessing() async {
    setState(() {
      _errorMessage = null;
      _steps = [
        const _AnalysisStep(
            label: 'Uploading document...', status: StepStatus.processing),
        const _AnalysisStep(
            label: 'Extracting loan terms...', status: StepStatus.pending),
        const _AnalysisStep(
            label: 'Analysing hidden clauses...', status: StepStatus.pending),
        const _AnalysisStep(
            label: 'Generating AI insights...', status: StepStatus.pending),
      ];
    });

    _progressController.value = 0.0;
    _progressController.animateTo(0.20,
        duration: const Duration(milliseconds: 800));

    try {
      if (widget.filePath == null) {
        throw Exception(
            "Local file path is missing. Please select a valid PDF agreement.");
      }

      final file = File(widget.filePath!);
      if (!await file.exists()) {
        throw Exception("Selected file was not found on device.");
      }

      // Step 1: Upload
      final loanRepo = ref.read(loanRepositoryProvider);
      final uploadRes = await loanRepo.uploadLoan(file);
      final loanId = uploadRes['loan_id']?.toString();

      if (loanId == null || loanId.isEmpty) {
        throw Exception("Server did not return a valid loan_id.");
      }

      setState(() {
        _steps[0] = const _AnalysisStep(
            label: 'Uploading document...', status: StepStatus.complete);
        _steps[1] = const _AnalysisStep(
            label: 'Extracting loan terms...', status: StepStatus.processing);
        _pollingMessage = 'AI engine is warming up — this takes 1–3 minutes...';
      });
      await _progressController.animateTo(0.35,
          duration: const Duration(milliseconds: 800));

      // Step 2: Poll until backend COMPLETED or FAILED
      // fetchAnalysis() already handles polling internally (every 5s, max 6 min)
      final report = await loanRepo.fetchAnalysis(loanId);

      setState(() {
        _steps[1] = const _AnalysisStep(
            label: 'Extracting loan terms...', status: StepStatus.complete);
        _steps[2] = const _AnalysisStep(
            label: 'Analysing hidden clauses...',
            status: StepStatus.processing);
        _pollingMessage = 'Risk clauses identified. Finalizing report...';
      });
      await _progressController.animateTo(0.75,
          duration: const Duration(milliseconds: 600));

      setState(() {
        _steps[2] = const _AnalysisStep(
            label: 'Analysing hidden clauses...', status: StepStatus.complete);
        _steps[3] = const _AnalysisStep(
            label: 'Generating AI insights...', status: StepStatus.processing);
        _pollingMessage = 'Building your personalized loan report...';
      });
      await _progressController.animateTo(0.95,
          duration: const Duration(milliseconds: 600));

      setState(() {
        _steps[3] = const _AnalysisStep(
            label: 'Generating AI insights...', status: StepStatus.complete);
        _pollingMessage = 'Complete!';
      });
      await _progressController.animateTo(1.0,
          duration: const Duration(milliseconds: 400));

      if (mounted && !_isNavigating) {
        _isNavigating = true;
        // Publish the freshly analysed report so the entire app knows a valid
        // loan is now active (prevents hardcoded fallback IDs being used).
        ref.read(activeLoanProvider.notifier).state = report;
        await Future.delayed(const Duration(milliseconds: 500));
        if (mounted) {
          Navigator.pushReplacement(
            context,
            PageRouteBuilder(
              pageBuilder: (context, animation, secondaryAnimation) =>
                  LoanAnalysisReportScreen(report: report),
              transitionsBuilder:
                  (context, animation, secondaryAnimation, child) {
                return FadeTransition(
                  opacity: animation,
                  child: child,
                );
              },
              transitionDuration: const Duration(milliseconds: 650),
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e is ApiException
              ? e.message
              : e is NetworkException
                  ? e.message
                  : e.toString();
          _pollingMessage = 'AI is identifying 14 critical nodes in your loan agreement.';
        });
      }
    }
  }


  @override
  void dispose() {
    _scanlineController.dispose();
    _pulseController.dispose();
    _progressController.dispose();
    _floatController.dispose();
    _glowController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ScanColors.background,
      body: Stack(
        children: [
          // Background ambient gradients
          _buildBackgroundGradients(),
          // Main scrollable content
          SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 40),
              child: Column(
                children: [
                  const SizedBox(height: 32),
                  _buildHeader(),
                  const SizedBox(height: 24),
                  _buildDocumentPreviewSection(),
                  const SizedBox(height: 32),
                  if (_errorMessage != null)
                    _buildErrorSection()
                  else ...[
                    _buildProcessSteps(),
                    const SizedBox(height: 24),
                    _buildProgressSection(),
                    const SizedBox(height: 16),
                    _buildContextBar(),
                  ],
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ),
          // Subtle noise overlay
          Positioned.fill(
            child: IgnorePointer(
              child: Opacity(
                opacity: 0.03,
                child: CustomPaint(
                  painter: _NoisePainter(),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorSection() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB4AB).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(16),
        border:
            Border.all(color: const Color(0xFFFFB4AB).withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: Color(0xFFFFB4AB), size: 28),
              const SizedBox(width: 12),
              Text(
                'Analysis Failed',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 20,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFFB4AB),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            _errorMessage ?? 'An error occurred during scanning.',
            style: GoogleFonts.inter(
              fontSize: 14,
              color: _ScanColors.onSurface,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _startBackendProcessing,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFFFB4AB),
                foregroundColor: const Color(0xFF131314),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: const Icon(Icons.refresh_rounded),
              label: Text(
                'Retry Scan',
                style: GoogleFonts.inter(fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Background Gradients ───
  Widget _buildBackgroundGradients() {
    return RepaintBoundary(
      child: AnimatedBuilder(
        animation: _glowController,
        builder: (context, _) {
          final glowVal = _glowController.value;
          return Stack(
            children: [
              Positioned(
                top: -80,
                left: -80,
                child: Container(
                  width: 280,
                  height: 280,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _ScanColors.primary
                            .withValues(alpha: 0.08 + glowVal * 0.04),
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
                  width: 350,
                  height: 350,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: RadialGradient(
                      colors: [
                        _ScanColors.onPrimaryContainer
                            .withValues(alpha: 0.04 + glowVal * 0.02),
                        Colors.transparent,
                      ],
                    ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  // ─── Header ───
  Widget _buildHeader() {
    return Column(
      children: [
        Text(
          'Analyzing Document',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 32,
            fontWeight: FontWeight.w600,
            color: _ScanColors.primary,
            height: 1.2,
          ),
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          'LOANSENSE AI ENGINE V4.2',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: _ScanColors.onSurfaceVariant,
            letterSpacing: 2.4,
          ),
          textAlign: TextAlign.center,
        ),
      ],
    );
  }

  // ─── Document Preview with Scanline & Overlays ───
  Widget _buildDocumentPreviewSection() {
    return SizedBox(
      height: 360,
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          // Glass document card
          Center(
            child: _GlassCard(
              width: 256,
              height: 320,
              borderRadius: 12,
              child: Stack(
                children: [
                  // Dynamic Document Preview Card
                  Positioned.fill(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: Container(
                        padding: const EdgeInsets.all(24),
                        color: _ScanColors.surfaceContainer,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.picture_as_pdf_outlined,
                              size: 72,
                              color: Color(0xFFC3C6D7),
                            ),
                            const SizedBox(height: 20),
                            Text(
                              widget.fileName,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.w600,
                                color: _ScanColors.onSurface,
                              ),
                              textAlign: TextAlign.center,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              "${widget.fileSizeMb.toStringAsFixed(2)} MB",
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                fontWeight: FontWeight.w500,
                                color: _ScanColors.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Scanline animation
                  AnimatedBuilder(
                    animation: _scanlineController,
                    builder: (context, _) {
                      return Positioned(
                        top: _scanlineController.value * 320 - 50,
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
                                _ScanColors.primary.withValues(alpha: 0.3),
                                Colors.transparent,
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
                  // Center scanning icon with pulse ring
                  Center(
                    child: RepaintBoundary(
                      child: AnimatedBuilder(
                        animation: _pulseController,
                        builder: (context, child) {
                          final pulse = _pulseController.value;
                          return Container(
                            width: 80,
                            height: 80,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(
                                color:
                                    _ScanColors.primary.withValues(alpha: 0.4),
                                width: 2,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: _ScanColors.primary
                                      .withValues(alpha: 0.4 * (1 - pulse)),
                                  blurRadius: pulse * 20,
                                  spreadRadius: pulse * 20,
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.document_scanner_outlined,
                              color: _ScanColors.primary,
                              size: 36,
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // OCR ACTIVE floating label (top right)
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Positioned(
                right: 0,
                top: 20 + _floatController.value * 4,
                child: child!,
              );
            },
            child: const _FloatingStatusLabel(
              icon: null,
              dotColor: _ScanColors.primary,
              label: 'OCR ACTIVE',
              showDot: true,
            ),
          ),

          // ENCRYPTED floating label (bottom left)
          AnimatedBuilder(
            animation: _floatController,
            builder: (context, child) {
              return Positioned(
                left: 0,
                bottom: 40 - _floatController.value * 4,
                child: child!,
              );
            },
            child: const _FloatingStatusLabel(
              icon: Icons.lock_outline,
              label: 'ENCRYPTED',
              showDot: false,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Process Steps List ───
  Widget _buildProcessSteps() {
    return Column(
      children: _steps.map((step) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: _ProcessStepRow(
            step: step,
            pulseController: _pulseController,
          ),
        );
      }).toList(),
    );
  }

  // ─── Progress Bar Section ───
  Widget _buildProgressSection() {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              'SCAN PROGRESS',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: _ScanColors.onSurfaceVariant,
                letterSpacing: 0.6,
              ),
            ),
            AnimatedBuilder(
              animation: _progressController,
              builder: (context, _) {
                final percent =
                    (100 * _progressController.value).round().toString();
                return Text(
                  '$percent%',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 24,
                    fontWeight: FontWeight.w500,
                    color: _ScanColors.primary,
                    height: 1.3,
                  ),
                );
              },
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 6,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9999),
            color: _ScanColors.surfaceContainerHighest,
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: AnimatedBuilder(
            animation: _progressController,
            builder: (context, _) {
              return FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: _progressController.value,
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9999),
                    gradient: const LinearGradient(
                      colors: [_ScanColors.primary, _ScanColors.secondary],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _ScanColors.primary.withValues(alpha: 0.4),
                        blurRadius: 15,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  // ─── Context Bar ───
  Widget _buildContextBar() {
    return Center(
      child: _GlassCard(
        borderRadius: 9999,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.info_outline,
              color: _ScanColors.onSurfaceVariant,
              size: 16,
            ),
            const SizedBox(width: 12),
            Flexible(
              child: Text(
                _pollingMessage,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: _ScanColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─── Process Step Row Widget ───
class _ProcessStepRow extends StatelessWidget {
  final _AnalysisStep step;
  final AnimationController pulseController;

  const _ProcessStepRow({
    required this.step,
    required this.pulseController,
  });

  @override
  Widget build(BuildContext context) {
    final isComplete = step.status == StepStatus.complete;
    final isProcessing = step.status == StepStatus.processing;
    final isPending = step.status == StepStatus.pending;
    final opacity = isPending ? 0.4 : 1.0;

    return Opacity(
      opacity: opacity,
      child: Row(
        children: [
          // Status icon
          SizedBox(
            width: 28,
            height: 28,
            child: Center(
              child: isComplete
                  ? const Icon(Icons.check_circle,
                      color: _ScanColors.primary, size: 24)
                  : isProcessing
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _ScanColors.primary,
                            backgroundColor: Colors.transparent,
                          ),
                        )
                      : const Icon(Icons.radio_button_unchecked,
                          color: _ScanColors.onSurfaceVariant, size: 24),
            ),
          ),
          const SizedBox(width: 16),
          // Label
          Expanded(
            child: Text(
              step.label,
              style: GoogleFonts.inter(
                fontSize: 16,
                fontWeight: isProcessing ? FontWeight.w600 : FontWeight.w400,
                color: isPending
                    ? _ScanColors.onSurfaceVariant
                    : _ScanColors.onSurface,
                height: 1.6,
              ),
            ),
          ),
          // Status text
          isProcessing
              ? AnimatedBuilder(
                  animation: pulseController,
                  builder: (context, child) {
                    final t = sin(pulseController.value * 2 * pi) * 0.5 + 0.5;
                    return Opacity(
                      opacity: 0.4 + 0.6 * t,
                      child: child,
                    );
                  },
                  child: Text(
                    'PROCESSING',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: _ScanColors.onSurfaceVariant,
                      letterSpacing: 0.7,
                    ),
                  ),
                )
              : Text(
                  isComplete ? 'COMPLETE' : 'PENDING',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    color: isComplete
                        ? _ScanColors.primary
                        : _ScanColors.onSurfaceVariant,
                    letterSpacing: 0.7,
                  ),
                ),
        ],
      ),
    );
  }
}

// ─── Floating Status Label ───
class _FloatingStatusLabel extends StatelessWidget {
  final IconData? icon;
  final Color? dotColor;
  final String label;
  final bool showDot;

  const _FloatingStatusLabel({
    this.icon,
    this.dotColor,
    required this.label,
    required this.showDot,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(9999),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(9999),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 16,
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(icon, color: _ScanColors.secondary, size: 14),
                const SizedBox(width: 8),
              ],
              if (showDot && dotColor != null) ...[
                _PulsingDot(color: dotColor!),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _ScanColors.primary,
                  letterSpacing: 0.7,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ─── Pulsing Dot ───
class _PulsingDot extends StatefulWidget {
  final Color color;
  const _PulsingDot({required this.color});

  @override
  State<_PulsingDot> createState() => _PulsingDotState();
}

class _PulsingDotState extends State<_PulsingDot>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
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
      builder: (context, _) {
        return Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(
            color: widget.color,
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: widget.color.withValues(alpha: 0.6 * _controller.value),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Reusable Glass Card ───
class _GlassCard extends StatelessWidget {
  final double? width;
  final double? height;
  final double borderRadius;
  final EdgeInsetsGeometry? padding;
  final Widget child;

  const _GlassCard({
    this.width,
    this.height,
    this.borderRadius = 12,
    this.padding,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          width: width,
          height: height,
          padding: padding ?? const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(borderRadius),
            border: Border.all(
              color: Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ─── Noise Overlay Painter ───
class _NoisePainter extends CustomPainter {
  final _random = Random(42);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white.withValues(alpha: 0.15);
    for (int i = 0; i < 800; i++) {
      final x = _random.nextDouble() * size.width;
      final y = _random.nextDouble() * size.height;
      canvas.drawCircle(Offset(x, y), 0.5, paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
