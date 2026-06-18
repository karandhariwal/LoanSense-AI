import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loansense_ai/core/navigation/app_routes.dart';
import 'package:loansense_ai/data/models/loan_comparison_report.dart';
import 'package:loansense_ai/data/repositories/loan_comparison_repository.dart';
import 'package:loansense_ai/ui/screens/loan_assistant_screen.dart';

class LoanComparisonScreen extends StatefulWidget {
  const LoanComparisonScreen({super.key});

  @override
  State<LoanComparisonScreen> createState() => _LoanComparisonScreenState();
}

class _LoanComparisonScreenState extends State<LoanComparisonScreen>
    with TickerProviderStateMixin {
  late final LoanComparisonController _controller;
  late final AnimationController _ambientController;

  @override
  void initState() {
    super.initState();
    _controller = LoanComparisonController(
      repository: LoanComparisonRepository(),
    )..bootstrap();
    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 7),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    _ambientController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _ComparePalette.background,
      body: AnimatedBuilder(
        animation: Listenable.merge([_controller, _ambientController]),
        builder: (context, _) {
          return Stack(
            children: [
              const Positioned.fill(child: _AmbientBackdrop()),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 104),
                  child: ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(40, 18, 40, 28),
                    children: [
                      _TopAppBar(
                        glow: _ambientController.value,
                        onGoHome: () => AppNavigator.goHome(context),
                        onOpenProfile: () => AppNavigator.goToProfile(context),
                      ),
                      const SizedBox(height: 28),
                      _UploadCards(
                        loanAFileName: _controller.loanA?.fileName,
                        loanBFileName: _controller.loanB?.fileName,
                        loadingSide: _controller.uploadingSide,
                        onPickA: () =>
                            _controller.pickLoan(context, LoanSide.loanA),
                        onPickB: () =>
                            _controller.pickLoan(context, LoanSide.loanB),
                      ),
                      const SizedBox(height: 28),
                      if (_controller.isComparing) const _CompareLoadingCard(),
                      if (_controller.report != null &&
                          !_controller.isComparing) ...[
                        const SizedBox(height: 28),
                        _MatrixCard(report: _controller.report!),
                        const SizedBox(height: 28),
                        _RecommendationCard(
                          report: _controller.report!,
                          whyExpanded: _controller.whyExpanded,
                          onToggleWhy: _controller.toggleWhy,
                          onCopy: () => _controller.copySummary(context),
                          onShare: () => _controller.shareSummary(context),
                        ),
                        const SizedBox(height: 28),
                        _VerdictCard(verdict: _controller.report!.verdict),
                        const SizedBox(height: 28),
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _controller.recompare,
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _ComparePalette.primary,
                                  foregroundColor: const Color(0xFF2C303D),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.refresh),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Re-Run Comparison',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: _controller.loanA == null
                                    ? null
                                    : () {
                                        Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => LoanAssistantScreen(
                                              loanId: _controller.loanA!.id,
                                            ),
                                          ),
                                        );
                                      },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _ComparePalette.primary,
                                  foregroundColor: const Color(0xFF2C303D),
                                  disabledBackgroundColor: _ComparePalette.primary.withValues(alpha: 0.3),
                                  disabledForegroundColor: const Color(0xFF2C303D).withValues(alpha: 0.5),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 8, vertical: 12),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.smart_toy_outlined),
                                label: FittedBox(
                                  fit: BoxFit.scaleDown,
                                  child: Text(
                                    'Ask AI',
                                    style: GoogleFonts.inter(
                                        fontWeight: FontWeight.w800),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: _BottomDock(
                  onHome: () => AppNavigator.goHome(context),
                  onAnalyse: () => AppNavigator.goToScan(context),
                  onAssistant: _controller.loanA == null
                      ? null
                      : () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => LoanAssistantScreen(
                                loanId: _controller.loanA!.id,
                              ),
                            ),
                          );
                        },
                  onProfile: () => AppNavigator.goToProfile(context),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class LoanComparisonController extends ChangeNotifier {
  final LoanComparisonRepository repository;

  LoanDocumentSummary? loanA;
  LoanDocumentSummary? loanB;
  LoanComparisonReport? report;

  bool isComparing = false;
  LoanSide? uploadingSide;
  bool whyExpanded = false;

  LoanComparisonController({required this.repository});

  void bootstrap() {
    // Start with empty/null documents and let the user select files to compare
    loanA = null;
    loanB = null;
    report = null;
  }

  Future<void> pickLoan(BuildContext context, LoanSide side) async {
    final result = await FilePicker.pickFiles(
        type: FileType.custom, allowedExtensions: const ['pdf']);
    if (result == null ||
        result.files.isEmpty ||
        result.files.first.path == null) {
      return;
    }
    uploadingSide = side;
    notifyListeners();
    try {
      final file = File(result.files.first.path!);
      final uploadRes = await repository.uploadLoan(file);
      final loanId = uploadRes['loan_id']?.toString();
      if (loanId == null || loanId.isEmpty) {
        throw Exception("Server did not return a valid loan_id.");
      }

      final fileName = file.path.split(Platform.pathSeparator).last;
      final lenderLabel = fileName.split('.').first;
      final summary = LoanDocumentSummary(
        id: loanId,
        lenderLabel: lenderLabel.length > 15
            ? lenderLabel.substring(0, 15)
            : lenderLabel,
        fileName: fileName,
      );

      if (side == LoanSide.loanA) {
        loanA = summary;
      } else {
        loanB = summary;
      }
    } catch (e) {
      developer.log("Upload failed: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Upload failed: ${e.toString()}')),
        );
      }
    } finally {
      uploadingSide = null;
      notifyListeners();
    }
    await compareIfReady();
  }

  Future<void> compareIfReady() async {
    if (loanA == null || loanB == null) return;
    isComparing = true;
    report = null;
    whyExpanded = false;
    notifyListeners();
    try {
      report = await repository.compare(loanA: loanA!, loanB: loanB!);
    } catch (e) {
      developer.log("Comparison failed: $e");
    } finally {
      isComparing = false;
      notifyListeners();
    }
  }

  void recompare() => unawaited(compareIfReady());

  void toggleWhy() {
    whyExpanded = !whyExpanded;
    notifyListeners();
  }

  Future<void> copySummary(BuildContext context) async {
    final data = report;
    if (data == null) return;
    await Clipboard.setData(
      ClipboardData(
          text:
              'Verdict: ${data.verdict.safetyIndex.toStringAsFixed(1)} • ${data.verdict.recommendedLabel}'),
    );
  }

  Future<void> shareSummary(BuildContext context) async {
    await copySummary(context);
  }
}

class _ComparePalette {
  static const background = Color(0xFF131314);
  static const surfaceContainer = Color(0xFF201F20);
  static const surfaceContainerLow = Color(0xFF1C1B1C);
  static const surfaceContainerHighest = Color(0xFF353436);
  static const primary = Color(0xFFC3C6D7);
  static const tertiary = Color(0xFFDBC3A8);
  static const error = Color(0xFFFFB4AB);
  static const onSurface = Color(0xFFE5E2E3);
  static const onSurfaceVariant = Color(0xFFC7C6CC);
}

class _AmbientBackdrop extends StatelessWidget {
  const _AmbientBackdrop();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Container(color: _ComparePalette.background),
        Positioned(
          top: -120,
          right: -120,
          child: Container(
            width: 320,
            height: 320,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _ComparePalette.primary.withValues(alpha: 0.04),
              boxShadow: [
                BoxShadow(
                  color: _ComparePalette.primary.withValues(alpha: 0.06),
                  blurRadius: 120,
                  spreadRadius: 110,
                ),
              ],
            ),
          ),
        ),
        Positioned(
          bottom: -140,
          left: -120,
          child: Container(
            width: 340,
            height: 340,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: _ComparePalette.tertiary.withValues(alpha: 0.02),
              boxShadow: [
                BoxShadow(
                  color: _ComparePalette.tertiary.withValues(alpha: 0.05),
                  blurRadius: 140,
                  spreadRadius: 120,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _TopAppBar extends StatelessWidget {
  final double glow;
  final VoidCallback onGoHome;
  final VoidCallback onOpenProfile;

  const _TopAppBar({
    required this.glow,
    required this.onGoHome,
    required this.onOpenProfile,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.fromLTRB(0, 0, 0, 14),
          decoration: BoxDecoration(
            border: Border(
                bottom:
                    BorderSide(color: Colors.white.withValues(alpha: 0.12))),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onGoHome();
                },
                child: Text(
                  'LoanSense AI',
                  style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.w600,
                      color: _ComparePalette.primary),
                ),
              ),
              Row(
                children: [
                  Icon(Icons.sensors,
                      color: _ComparePalette.primary.withValues(alpha: 0.95),
                      size: 20),
                  const SizedBox(width: 16),
                  Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: _ComparePalette.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(9999),
                      border: Border.all(
                          color: Colors.white.withValues(alpha: 0.12)),
                    ),
                    child: IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        onOpenProfile();
                      },
                      icon: const Icon(
                        Icons.person,
                        size: 18,
                        color: _ComparePalette.primary,
                      ),
                      splashRadius: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UploadCards extends StatelessWidget {
  final String? loanAFileName;
  final String? loanBFileName;
  final LoanSide? loadingSide;
  final VoidCallback onPickA;
  final VoidCallback onPickB;

  const _UploadCards({
    required this.loanAFileName,
    required this.loanBFileName,
    required this.loadingSide,
    required this.onPickA,
    required this.onPickB,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _UploadCard(
          title: 'Upload Loan A',
          fileName: loanAFileName,
          loading: loadingSide == LoanSide.loanA,
          onTap: onPickA,
        ),
        const SizedBox(height: 24),
        _UploadCard(
          title: 'Upload Loan B',
          fileName: loanBFileName,
          loading: loadingSide == LoanSide.loanB,
          onTap: onPickB,
        ),
      ],
    );
  }
}

class _UploadCard extends StatelessWidget {
  final String title;
  final String? fileName;
  final bool loading;
  final VoidCallback onTap;

  const _UploadCard({
    required this.title,
    required this.fileName,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: InkWell(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: CustomPaint(
              painter: _DashedRRectPainter(
                color: _ComparePalette.primary.withValues(alpha: 0.28),
                dashLength: 8,
                gapLength: 7,
                strokeWidth: 1.8,
                radius: 14,
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 14),
                child: Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: _ComparePalette.primary.withValues(alpha: 0.10),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.upload_file,
                          color: _ComparePalette.primary, size: 32),
                    ),
                    const SizedBox(height: 14),
                    Text(
                      title,
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 20,
                        fontWeight: FontWeight.w500,
                        color: _ComparePalette.primary,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      'Drop PDF or Scan Document',
                      style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: _ComparePalette.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _ComparePalette.surfaceContainerHighest
                            .withValues(alpha: 0.92),
                        borderRadius: BorderRadius.circular(9999),
                        border: Border.all(
                            color: Colors.white.withValues(alpha: 0.12)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (loading)
                            SizedBox(
                              width: 12,
                              height: 12,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: _ComparePalette.primary,
                                backgroundColor:
                                    Colors.white.withValues(alpha: 0.10),
                              ),
                            )
                          else
                            const Icon(Icons.check_circle,
                                size: 14, color: _ComparePalette.primary),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              fileName ?? 'Select PDF',
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _ComparePalette.primary,
                              ),
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
    );
  }
}

class _DashedRRectPainter extends CustomPainter {
  final Color color;
  final double dashLength;
  final double gapLength;
  final double strokeWidth;
  final double radius;

  const _DashedRRectPainter({
    required this.color,
    required this.dashLength,
    required this.gapLength,
    required this.strokeWidth,
    required this.radius,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Rect.fromLTWH(0, 0, size.width, size.height);
    final rrect = RRect.fromRectAndRadius(
        rect.deflate(strokeWidth / 2), Radius.circular(radius));

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..color = color;

    final path = Path()..addRRect(rrect);
    for (final metric in path.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = min(distance + dashLength, metric.length);
        final extract = metric.extractPath(distance, next);
        canvas.drawPath(extract, paint);
        distance = next + gapLength;
      }
    }
  }

  @override
  bool shouldRepaint(covariant _DashedRRectPainter oldDelegate) {
    return color != oldDelegate.color ||
        dashLength != oldDelegate.dashLength ||
        gapLength != oldDelegate.gapLength ||
        strokeWidth != oldDelegate.strokeWidth ||
        radius != oldDelegate.radius;
  }
}

class _CompareLoadingCard extends StatelessWidget {
  const _CompareLoadingCard();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: _ComparePalette.primary.withValues(alpha: 0.10),
                  borderRadius: BorderRadius.circular(12),
                ),
                child:
                    const Icon(Icons.smart_toy, color: _ComparePalette.primary),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Running AI comparison…',
                        style: GoogleFonts.spaceGrotesk(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: _ComparePalette.primary)),
                    const SizedBox(height: 6),
                    Text(
                        'Parsing clauses, fees, exit penalties and rate buffers.',
                        style: GoogleFonts.inter(
                            fontSize: 13,
                            height: 1.5,
                            color: _ComparePalette.onSurfaceVariant)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(9999),
                      child: LinearProgressIndicator(
                        minHeight: 6,
                        valueColor: const AlwaysStoppedAnimation<Color>(
                            _ComparePalette.primary),
                        backgroundColor: Colors.white.withValues(alpha: 0.06),
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
}

class _MatrixCard extends StatelessWidget {
  final LoanComparisonReport report;
  const _MatrixCard({required this.report});

  Color _signalColor(ComparisonValue v) {
    final signal = v.badge?.signal;
    return switch (signal) {
      ComparisonSignal.negative => _ComparePalette.error,
      ComparisonSignal.warning => _ComparePalette.tertiary,
      ComparisonSignal.positive => _ComparePalette.primary,
      _ => _ComparePalette.onSurface,
    };
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                padding: const EdgeInsets.all(24),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.05),
                  border: Border(
                      bottom: BorderSide(
                          color: Colors.white.withValues(alpha: 0.12))),
                ),
                child: Text('Comparison Matrix',
                    style: GoogleFonts.spaceGrotesk(
                        fontSize: 32,
                        height: 1.05,
                        fontWeight: FontWeight.w600,
                        color: _ComparePalette.primary)),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Theme(
                  data: Theme.of(context).copyWith(
                    dividerColor: Colors.white.withValues(alpha: 0.07),
                    dividerTheme: const DividerThemeData(
                      thickness: 0.3,
                      space: 0.3,
                    ),
                  ),
                  child: DataTable(
                    headingRowColor: WidgetStatePropertyAll(_ComparePalette
                        .surfaceContainerLow
                        .withValues(alpha: 0.98)),
                    dataRowMinHeight: 52,
                    dataRowMaxHeight: 80,
                    headingRowHeight: 44,
                    columnSpacing: 24,
                    horizontalMargin: 16,
                    columns: [
                      DataColumn(
                        label: Text(
                          'METRICS',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _ComparePalette.onSurfaceVariant,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'LOAN A  (HDFC)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _ComparePalette.primary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                      DataColumn(
                        label: Text(
                          'LOAN B  (SBI)',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _ComparePalette.primary,
                            letterSpacing: 1.0,
                          ),
                        ),
                      ),
                    ],
                    rows: report.metrics
                        .map(
                          (m) => DataRow(
                            cells: [
                              DataCell(
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 120),
                                  child: Text(
                                    m.label,
                                    style: GoogleFonts.inter(
                                        fontSize: 13,
                                        color: _ComparePalette.onSurface),
                                    softWrap: true,
                                  ),
                                ),
                              ),
                              DataCell(
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 140),
                                  child: Text(
                                    m.loanA.badge?.label ?? m.loanA.value,
                                    style: GoogleFonts.spaceGrotesk(
                                        fontSize: 13,
                                        color: _signalColor(m.loanA)),
                                    softWrap: true,
                                  ),
                                ),
                              ),
                              DataCell(
                                ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(maxWidth: 140),
                                  child: Text(
                                    m.loanB.badge?.label ?? m.loanB.value,
                                    style: GoogleFonts.spaceGrotesk(
                                        fontSize: 13,
                                        color: _signalColor(m.loanB)),
                                    softWrap: true,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        )
                        .toList(),
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

class _RecommendationCard extends StatelessWidget {
  final LoanComparisonReport report;
  final bool whyExpanded;
  final VoidCallback onToggleWhy;
  final VoidCallback onCopy;
  final VoidCallback onShare;

  const _RecommendationCard({
    required this.report,
    required this.whyExpanded,
    required this.onToggleWhy,
    required this.onCopy,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final rec = report.recommendation;
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 0,
                bottom: 0,
                child: Container(
                  width: 4,
                  decoration: const BoxDecoration(
                    color: _ComparePalette.primary,
                    borderRadius: BorderRadius.only(
                      topLeft: Radius.circular(16),
                      bottomLeft: Radius.circular(16),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                _ComparePalette.primary.withValues(alpha: 0.10),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: const Icon(Icons.smart_toy,
                              color: _ComparePalette.primary, size: 26),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                rec.headline,
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 20,
                                  fontWeight: FontWeight.w600,
                                  color: _ComparePalette.primary,
                                  height: 1.3,
                                ),
                                softWrap: true,
                              ),
                              const SizedBox(height: 8),
                              Text(
                                rec.summary,
                                style: GoogleFonts.inter(
                                  fontSize: 13,
                                  height: 1.55,
                                  color: _ComparePalette.onSurfaceVariant,
                                ),
                                softWrap: true,
                              ),
                            ],
                          ),
                        ),
                        Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              onPressed: onCopy,
                              icon: const Icon(Icons.copy_all_outlined,
                                  color: _ComparePalette.primary, size: 20),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                            ),
                            IconButton(
                              onPressed: onShare,
                              icon: const Icon(Icons.ios_share_outlined,
                                  color: _ComparePalette.primary, size: 20),
                              padding: const EdgeInsets.all(6),
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ...rec.reasons.map(
                      (r) => Padding(
                        padding: const EdgeInsets.only(bottom: 14),
                        child: RichText(
                          text: TextSpan(
                            children: [
                              TextSpan(
                                  text: '${r.title}: ',
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w700,
                                      color: _ComparePalette.primary)),
                              TextSpan(
                                  text: r.body,
                                  style: GoogleFonts.inter(
                                      fontSize: 14,
                                      height: 1.55,
                                      color: _ComparePalette.onSurface)),
                            ],
                          ),
                        ),
                      ),
                    ),
                    TextButton.icon(
                      onPressed: onToggleWhy,
                      icon: Icon(
                          whyExpanded ? Icons.expand_less : Icons.expand_more,
                          color: _ComparePalette.primary),
                      label: Text('Why this recommendation?',
                          style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                              color: _ComparePalette.primary)),
                    ),
                    AnimatedSize(
                      duration: const Duration(milliseconds: 240),
                      curve: Curves.easeOutCubic,
                      child: whyExpanded
                          ? Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Text(rec.why,
                                  style: GoogleFonts.inter(
                                      fontSize: 13,
                                      height: 1.6,
                                      color: _ComparePalette.onSurface)),
                            )
                          : const SizedBox.shrink(),
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
}

class _VerdictCard extends StatelessWidget {
  final LoanComparisonVerdict verdict;
  const _VerdictCard({required this.verdict});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: Column(
            children: [
              Text('LoanSense AI Verdict',
                  style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 2.2,
                      color: _ComparePalette.onSurfaceVariant)),
              const SizedBox(height: 18),
              SizedBox(
                width: 160,
                height: 160,
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: CircularProgressIndicator(
                        value: (verdict.safetyIndex / 10).clamp(0, 1),
                        strokeWidth: 12,
                        color: _ComparePalette.primary,
                        backgroundColor: Colors.white.withValues(alpha: 0.05),
                      ),
                    ),
                    Positioned.fill(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(verdict.safetyIndex.toStringAsFixed(1),
                              style: GoogleFonts.spaceGrotesk(
                                  fontSize: 48,
                                  fontWeight: FontWeight.w700,
                                  color: _ComparePalette.primary,
                                  height: 1.0)),
                          const SizedBox(height: 2),
                          Text('Safety Index',
                              style: GoogleFonts.inter(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w600,
                                  color: _ComparePalette.onSurfaceVariant)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                decoration: BoxDecoration(
                    color: _ComparePalette.primary,
                    borderRadius: BorderRadius.circular(9999)),
                child: Text(verdict.recommendedLabel,
                    style: GoogleFonts.inter(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: const Color(0xFF2C303D))),
              ),
              const SizedBox(height: 8),
              Text(verdict.confidenceLabel,
                  style: GoogleFonts.inter(
                      fontSize: 10,
                      fontStyle: FontStyle.italic,
                      color: _ComparePalette.onSurfaceVariant)),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomDock extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onAnalyse;
  final VoidCallback? onAssistant; // nullable: null when no loan is loaded
  final VoidCallback onProfile;

  const _BottomDock({
    required this.onHome,
    required this.onAnalyse,
    this.onAssistant,
    required this.onProfile,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 512),
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: _ComparePalette.surfaceContainer.withValues(alpha: 0.60),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.8),
                    blurRadius: 32,
                    offset: const Offset(0, 8)),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                GestureDetector(
                    onTap: onHome,
                    child: const _DockItem(
                        icon: Icons.home_outlined, label: 'Home')),
                GestureDetector(
                    onTap: onAnalyse,
                    child: const _DockItem(
                        icon: Icons.analytics_outlined, label: 'Analyse')),
                GestureDetector(
                    onTap: onAssistant,
                    child: _DockItem(
                        icon: Icons.smart_toy_outlined,
                        label: 'AI Assistant',
                        disabled: onAssistant == null)),
                const _DockItem(
                    icon: Icons.compare_arrows,
                    label: 'Compare',
                    selected: true),
                GestureDetector(
                    onTap: onProfile,
                    child:
                        const _DockItem(icon: Icons.person_outline, label: 'Profile')),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DockItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool selected;
  final bool disabled;
  const _DockItem(
      {required this.icon,
      required this.label,
      this.selected = false,
      this.disabled = false});

  @override
  Widget build(BuildContext context) {
    final color = selected
        ? _ComparePalette.primary
        : disabled
            ? _ComparePalette.onSurfaceVariant.withValues(alpha: 0.3)
            : _ComparePalette.onSurfaceVariant.withValues(alpha: 0.7);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 22, color: color),
        const SizedBox(height: 4),
        Text(label,
            style: GoogleFonts.inter(
                fontSize: 10,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: color)),
      ],
    );
  }
}
