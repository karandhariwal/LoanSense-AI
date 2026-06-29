import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'dart:io';
import 'dart:developer' as developer;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loansense_ai/core/navigation/app_routes.dart';
import 'package:loansense_ai/data/models/loan_comparison_report.dart';
import 'package:loansense_ai/data/repositories/loan_comparison_repository.dart';
import 'package:loansense_ai/ui/screens/loan_assistant_screen.dart';
import 'package:loansense_ai/presentation/providers/loan_providers.dart';

class LoanComparisonScreen extends ConsumerStatefulWidget {
  const LoanComparisonScreen({super.key});

  @override
  ConsumerState<LoanComparisonScreen> createState() => _LoanComparisonScreenState();
}

class _LoanComparisonScreenState extends ConsumerState<LoanComparisonScreen>
    with TickerProviderStateMixin {
  late final LoanComparisonController _controller;
  late final AnimationController _ambientController;
  final Set<int> _expandedClauses = {};
  final Set<int> _expandedInsights = {};

  @override
  void initState() {
    super.initState();
    _controller = LoanComparisonController(
      repository: LoanComparisonRepository(),
      onUpdate: () => setState(() {}),
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
    final comparisonState = ref.watch(comparisonProvider);
    final isComparing = comparisonState.isComparing;
    final report = comparisonState.report;
    final errorMessage = comparisonState.errorMessage;
    final loadingMessage = comparisonState.loadingMessage;

    final hasBothLoans = _controller.loanA != null && _controller.loanB != null;

    return Scaffold(
      backgroundColor: _ComparePalette.background,
      body: AnimatedBuilder(
        animation: _ambientController,
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
                    padding: const EdgeInsets.fromLTRB(24, 18, 24, 28),
                    children: [
                      _TopAppBar(
                        glow: _ambientController.value,
                        onGoHome: () => AppNavigator.goHome(context),
                        onOpenProfile: () => AppNavigator.goToProfile(context),
                      ),
                      const SizedBox(height: 24),
                      
                      // Document Upload Cards
                      _UploadCards(
                        loanAFileName: _controller.loanA?.fileName,
                        loanBFileName: _controller.loanB?.fileName,
                        loadingSide: _controller.uploadingSide,
                        onPickA: () => _controller.pickLoan(context, LoanSide.loanA),
                        onPickB: () => _controller.pickLoan(context, LoanSide.loanB),
                      ),
                      const SizedBox(height: 20),

                      // Validation Message / Start Button
                      if (!hasBothLoans && !isComparing && report == null) ...[
                        _ValidationCard(),
                      ] else if (hasBothLoans && !isComparing && report == null) ...[
                        _StartComparisonButton(
                          onPressed: () => ref.read(comparisonProvider.notifier).compare(
                                _controller.loanA!.id,
                                _controller.loanB!.id,
                              ),
                        ),
                      ],

                      // Loading States
                      if (isComparing) ...[
                        const SizedBox(height: 20),
                        _CompareLoadingCard(message: loadingMessage),
                      ],

                      // Error Recovery UI
                      if (errorMessage != null && !isComparing) ...[
                        const SizedBox(height: 20),
                        _ErrorRecoveryCard(
                          errorMessage: errorMessage,
                          onRetry: () => ref.read(comparisonProvider.notifier).compare(
                                _controller.loanA!.id,
                                _controller.loanB!.id,
                              ),
                        ),
                      ],

                      // Success State - Render 9 Sections Dynamically
                      if (report != null && !isComparing) ...[
                        const SizedBox(height: 24),
                        
                        // SECTION 1: Winner Card
                        _SectionWinnerCard(recommended: report.recommendedLoan),
                        const SizedBox(height: 24),

                        // SECTION 2: Executive Summary
                        _SectionExecutiveSummary(summary: report.executiveSummary),
                        const SizedBox(height: 24),

                        // SECTION 3: Financial Breakdown Table
                        _SectionFinancialBreakdown(
                          breakdown: report.financialBreakdown,
                          lenderA: report.loanA.lenderLabel,
                          lenderB: report.loanB.lenderLabel,
                        ),
                        const SizedBox(height: 24),

                        // SECTION 4: Risk Category Comparison
                        _SectionRiskComparison(
                          risks: report.riskBreakdown,
                          lenderA: report.loanA.lenderLabel,
                          lenderB: report.loanB.lenderLabel,
                        ),
                        const SizedBox(height: 24),

                        // SECTION 5: AI Risk Scores
                        _SectionRiskScores(scores: report.loanScores),
                        const SizedBox(height: 24),

                        // SECTION 6: AI Insights (Expandable reasons)
                        _SectionAiInsights(
                          insights: report.recommendationReasonsList,
                          expandedIndices: _expandedInsights,
                          onToggle: (index) {
                            setState(() {
                              if (_expandedInsights.contains(index)) {
                                _expandedInsights.remove(index);
                              } else {
                                _expandedInsights.add(index);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 24),

                        // SECTION 7: Clause-by-Clause Comparison
                        _SectionClauseComparison(
                          clauses: report.clauseComparisonList,
                          lenderA: report.loanA.lenderLabel,
                          lenderB: report.loanB.lenderLabel,
                          expandedIndices: _expandedClauses,
                          onToggle: (index) {
                            setState(() {
                              if (_expandedClauses.contains(index)) {
                                _expandedClauses.remove(index);
                              } else {
                                _expandedClauses.add(index);
                              }
                            });
                          },
                        ),
                        const SizedBox(height: 24),

                        // SECTION 8: Charts
                        _SectionCharts(
                          charts: report.chartsData,
                          lenderA: report.loanA.lenderLabel,
                          lenderB: report.loanB.lenderLabel,
                        ),
                        const SizedBox(height: 24),

                        // SECTION 9: Final Decision Checklist
                        _SectionFinalDecision(decision: report.finalDecision),
                        const SizedBox(height: 28),

                        // Re-run and Q&A Row
                        Row(
                          children: [
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  ref.read(comparisonProvider.notifier).reset();
                                  _controller.bootstrap();
                                  setState(() {
                                    _expandedClauses.clear();
                                    _expandedInsights.clear();
                                  });
                                },
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: _ComparePalette.surfaceContainerHighest,
                                  foregroundColor: _ComparePalette.onSurface,
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: Colors.white.withValues(alpha: 0.1)),
                                  ),
                                ),
                                icon: const Icon(Icons.refresh, size: 18),
                                label: Text(
                                  'New Comparison',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: ElevatedButton.icon(
                                onPressed: () {
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
                                  foregroundColor: const Color(0xFF1E212A),
                                  padding: const EdgeInsets.symmetric(vertical: 14),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                icon: const Icon(Icons.smart_toy_outlined, size: 18),
                                label: Text(
                                  'Ask Loan A AI',
                                  style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
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

// Controller logic wrapper
class LoanComparisonController {
  final LoanComparisonRepository repository;
  final VoidCallback onUpdate;

  LoanDocumentSummary? loanA;
  LoanDocumentSummary? loanB;
  LoanSide? uploadingSide;

  LoanComparisonController({required this.repository, required this.onUpdate});

  void bootstrap() {
    loanA = null;
    loanB = null;
    uploadingSide = null;
    onUpdate();
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
    onUpdate();
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
        lenderLabel: lenderLabel.length > 20
            ? lenderLabel.substring(0, 20)
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
          SnackBar(
            backgroundColor: _ComparePalette.error,
            content: Text(
              'Upload failed: ${e.toString()}',
              style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold),
            ),
          ),
        );
      }
    } finally {
      uploadingSide = null;
      onUpdate();
    }
  }

  void dispose() {}
}

// ==========================================
// RENDER COMPONENT WIDGETS
// ==========================================

class _ValidationCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: _ComparePalette.error.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _ComparePalette.error.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded, color: _ComparePalette.error, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              'Please upload both loan documents before starting the comparison.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _ComparePalette.error,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StartComparisonButton extends StatelessWidget {
  final VoidCallback onPressed;
  const _StartComparisonButton({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        gradient: const LinearGradient(
          colors: [
            _ComparePalette.primary,
            Color(0xFFE5E7EB),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: _ComparePalette.primary.withValues(alpha: 0.3),
            blurRadius: 15,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ElevatedButton.icon(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          shadowColor: Colors.transparent,
          foregroundColor: const Color(0xFF1E212A),
          padding: const EdgeInsets.symmetric(vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
        icon: const Icon(Icons.compare_arrows_rounded, size: 22),
        label: Text(
          'Start Comparison',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 15,
            fontWeight: FontWeight.bold,
            letterSpacing: 0.5,
          ),
        ),
      ),
    );
  }
}

class _CompareLoadingCard extends StatelessWidget {
  final String? message;
  const _CompareLoadingCard({this.message});

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
              const SizedBox(
                width: 32,
                height: 32,
                child: CircularProgressIndicator(
                  strokeWidth: 3,
                  color: _ComparePalette.primary,
                ),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message ?? 'Comparing Loan Documents...',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                        color: _ComparePalette.primary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Analyzing legal provisions, financial structures & penalties.',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        color: _ComparePalette.onSurfaceVariant,
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

class _ErrorRecoveryCard extends StatelessWidget {
  final String errorMessage;
  final VoidCallback onRetry;
  const _ErrorRecoveryCard({required this.errorMessage, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: _ComparePalette.error.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ComparePalette.error.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, color: _ComparePalette.error, size: 24),
              const SizedBox(width: 10),
              Text(
                'Comparison Failed',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: _ComparePalette.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            errorMessage,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: _ComparePalette.onSurface.withValues(alpha: 0.8),
            ),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: onRetry,
            style: ElevatedButton.styleFrom(
              backgroundColor: _ComparePalette.error,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            ),
            icon: const Icon(Icons.refresh, size: 16),
            label: Text(
              'Retry Comparison',
              style: GoogleFonts.inter(fontWeight: FontWeight.bold, fontSize: 13),
            ),
          )
        ],
      ),
    );
  }
}

// SECTION 1: Winner Card
class _SectionWinnerCard extends StatelessWidget {
  final RecommendedLoan recommended;
  const _SectionWinnerCard({required this.recommended});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFFD4AF37).withValues(alpha: 0.15),
            Colors.white.withValues(alpha: 0.03),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: const Color(0xFFD4AF37).withValues(alpha: 0.4),
          width: 1.5,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4AF37).withValues(alpha: 0.08),
            blurRadius: 20,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: 16,
            top: 16,
            child: Icon(
              Icons.emoji_events_outlined,
              size: 72,
              color: const Color(0xFFD4AF37).withValues(alpha: 0.15),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: const Color(0xFFD4AF37),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.star, size: 14, color: Colors.black),
                          const SizedBox(width: 4),
                          Text(
                            'RECOMMENDED',
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              color: Colors.black,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
                      ),
                      child: Text(
                        '${(recommended.confidenceScore * 100).toStringAsFixed(0)}% Match Confidence',
                        style: GoogleFonts.inter(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: _ComparePalette.primary,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(
                  recommended.lenderName,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 26,
                    fontWeight: FontWeight.bold,
                    color: const Color(0xFFE2E5F3),
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Text(
                      'AI Safety Grade: ',
                      style: GoogleFonts.inter(fontSize: 12, color: _ComparePalette.onSurfaceVariant),
                    ),
                    Text(
                      '${recommended.recommendationScore.toStringAsFixed(1)} / 10',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: const Color(0xFFD4AF37),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  recommended.recommendationReason,
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    height: 1.5,
                    color: _ComparePalette.onSurface.withValues(alpha: 0.9),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// SECTION 2: Executive Summary
class _SectionExecutiveSummary extends StatelessWidget {
  final ExecutiveSummary summary;
  const _SectionExecutiveSummary({required this.summary});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.notes, color: _ComparePalette.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Executive Summary',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _ComparePalette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _SummaryBullet(title: 'Choice Verdict', body: summary.whyBetter),
          _SummaryBullet(title: 'Key Differences', body: summary.biggestDifferences),
          _SummaryBullet(title: 'Identified Risks', body: summary.mainRisks),
          _SummaryBullet(title: 'Strategic Advice', body: summary.overallRecommendation),
        ],
      ),
    );
  }
}

class _SummaryBullet extends StatelessWidget {
  final String title;
  final String body;
  const _SummaryBullet({required this.title, required this.body});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.spaceGrotesk(
              fontSize: 10,
              fontWeight: FontWeight.bold,
              color: _ComparePalette.primary.withValues(alpha: 0.7),
              letterSpacing: 1.0,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            body,
            style: GoogleFonts.inter(
              fontSize: 13,
              height: 1.5,
              color: _ComparePalette.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// SECTION 3: Financial Breakdown Table
class _SectionFinancialBreakdown extends StatelessWidget {
  final FinancialBreakdown breakdown;
  final String lenderA;
  final String lenderB;

  const _SectionFinancialBreakdown({
    required this.breakdown,
    required this.lenderA,
    required this.lenderB,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(24),
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet_outlined, color: _ComparePalette.primary, size: 20),
                const SizedBox(width: 10),
                Text(
                  'Financial Breakdown',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: _ComparePalette.primary,
                  ),
                ),
              ],
            ),
          ),
          Divider(color: Colors.white.withValues(alpha: 0.1), height: 1),
          _FinancialRow(label: 'Principal', item: breakdown.principalAmount, sideA: lenderA, sideB: lenderB),
          _FinancialRow(label: 'Interest Rate', item: breakdown.interestRate, sideA: lenderA, sideB: lenderB),
          _FinancialRow(label: 'Interest Type', item: breakdown.interestType, sideA: lenderA, sideB: lenderB),
          _FinancialRow(label: 'Tenure', item: breakdown.tenure, sideA: lenderA, sideB: lenderB),
          _FinancialRow(label: 'EMI', item: breakdown.emi, sideA: lenderA, sideB: lenderB),
          _FinancialRow(label: 'Processing Fee', item: breakdown.processingFee, sideA: lenderA, sideB: lenderB),
          _FinancialRow(label: 'Documentation Fee', item: breakdown.documentationFee, sideA: lenderA, sideB: lenderB),
          _FinancialRow(label: 'Insurance Cost', item: breakdown.insuranceCost, sideA: lenderA, sideB: lenderB),
          _FinancialRow(label: 'Total Interest', item: breakdown.totalInterest, sideA: lenderA, sideB: lenderB),
          _FinancialRow(label: 'Total Repayment', item: breakdown.totalRepayment, sideA: lenderA, sideB: lenderB),
          _FinancialRow(label: 'Effective APR', item: breakdown.effectiveApr, sideA: lenderA, sideB: lenderB, isLast: true),
        ],
      ),
    );
  }
}

class _FinancialRow extends StatelessWidget {
  final String label;
  final FinancialItem item;
  final String sideA;
  final String sideB;
  final bool isLast;

  const _FinancialRow({
    required this.label,
    required this.item,
    required this.sideA,
    required this.sideB,
    this.isLast = false,
  });

  Color _getCellColor(String side) {
    if (item.betterSide == 'none') return _ComparePalette.onSurface;
    if (item.betterSide == side) return const Color(0xFF81C784); // Green for winner
    return const Color(0xFFE57373); // Red for loser
  }

  FontWeight _getCellWeight(String side) {
    return item.betterSide == side ? FontWeight.bold : FontWeight.normal;
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        border: isLast ? null : Border(bottom: BorderSide(color: Colors.white.withValues(alpha: 0.05))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                flex: 4,
                child: Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: _ComparePalette.onSurfaceVariant,
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  item.valueA,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: _getCellWeight('loan_a'),
                    color: _getCellColor('loan_a'),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  item.valueB,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 12,
                    fontWeight: _getCellWeight('loan_b'),
                    color: _getCellColor('loan_b'),
                  ),
                ),
              ),
            ],
          ),
          if (item.explanation.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              item.explanation,
              style: GoogleFonts.inter(
                fontSize: 11,
                fontStyle: FontStyle.italic,
                color: _ComparePalette.onSurfaceVariant.withValues(alpha: 0.8),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// SECTION 4: Risk Category Comparison
class _SectionRiskComparison extends StatelessWidget {
  final RiskComparison risks;
  final String lenderA;
  final String lenderB;

  const _SectionRiskComparison({
    required this.risks,
    required this.lenderA,
    required this.lenderB,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.shield_outlined, color: _ComparePalette.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Legal & Penalty Comparison',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _ComparePalette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _RiskPanel(title: 'Hidden Admin Charges', item: risks.hiddenCharges, lenderA: lenderA, lenderB: lenderB),
          _RiskPanel(title: 'Foreclosure Penalties', item: risks.foreclosurePenalties, lenderA: lenderA, lenderB: lenderB),
          _RiskPanel(title: 'Prepayment Charges', item: risks.prepaymentCharges, lenderA: lenderA, lenderB: lenderB),
          _RiskPanel(title: 'Late Payment Fees', item: risks.latePaymentFees, lenderA: lenderA, lenderB: lenderB),
          _RiskPanel(title: 'Bounce Charges', item: risks.bounceCharges, lenderA: lenderA, lenderB: lenderB),
          _RiskPanel(title: 'Floating Rate Buffers', item: risks.floatingRateClauses, lenderA: lenderA, lenderB: lenderB),
          _RiskPanel(title: 'Lender Discretionary Clauses', item: risks.legalDiscretionClauses, lenderA: lenderA, lenderB: lenderB),
          _RiskPanel(title: 'Mandatory Insurance Bundling', item: risks.mandatoryInsurance, lenderA: lenderA, lenderB: lenderB, isLast: true),
        ],
      ),
    );
  }
}

class _RiskPanel extends StatelessWidget {
  final String title;
  final RiskItem item;
  final String lenderA;
  final String lenderB;
  final bool isLast;

  const _RiskPanel({
    required this.title,
    required this.item,
    required this.lenderA,
    required this.lenderB,
    this.isLast = false,
  });

  @override
  Widget build(BuildContext context) {
    final hasWinner = item.betterSide != 'none';
    final winnerLabel = item.betterSide == 'loan_a' ? lenderA : lenderB;

    return Container(
      margin: EdgeInsets.only(bottom: isLast ? 0 : 20),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.02),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(fontSize: 14, fontWeight: FontWeight.bold, color: _ComparePalette.primary),
              ),
              const Spacer(),
              if (hasWinner) ...[
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: const Color(0xFF81C784).withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(6),
                    border: Border.all(color: const Color(0xFF81C784).withValues(alpha: 0.3)),
                  ),
                  child: Text(
                    'Better: $winnerLabel',
                    style: GoogleFonts.inter(fontSize: 9, fontWeight: FontWeight.w800, color: const Color(0xFF81C784)),
                  ),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _RiskValueBox(label: lenderA, value: item.valueA, isBetter: item.betterSide == 'loan_a'),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _RiskValueBox(label: lenderB, value: item.valueB, isBetter: item.betterSide == 'loan_b'),
              ),
            ],
          ),
          if (item.explanation.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              item.explanation,
              style: GoogleFonts.inter(
                fontSize: 11,
                height: 1.45,
                color: _ComparePalette.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _RiskValueBox extends StatelessWidget {
  final String label;
  final String value;
  final bool isBetter;

  const _RiskValueBox({
    required this.label,
    required this.value,
    required this.isBetter,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: isBetter 
            ? const Color(0xFF81C784).withValues(alpha: 0.05) 
            : Colors.white.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(
          color: isBetter 
              ? const Color(0xFF81C784).withValues(alpha: 0.2) 
              : Colors.white.withValues(alpha: 0.05),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label.toUpperCase(),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: GoogleFonts.inter(
              fontSize: 9, 
              fontWeight: FontWeight.bold, 
              color: _ComparePalette.onSurfaceVariant.withValues(alpha: 0.7),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 12, 
              fontWeight: FontWeight.w700, 
              color: isBetter ? const Color(0xFF81C784) : _ComparePalette.onSurface,
            ),
          ),
        ],
      ),
    );
  }
}

// SECTION 5: AI Risk Scores
class _SectionRiskScores extends StatelessWidget {
  final LoanScores scores;
  const _SectionRiskScores({required this.scores});

  Color _getRatingColor(String rating) {
    switch (rating.toLowerCase()) {
      case 'low':
      case 'safe':
        return const Color(0xFF81C784);
      case 'medium':
      case 'moderate':
        return const Color(0xFFFFD54F);
      case 'high':
      case 'dangerous':
      default:
        return const Color(0xFFE57373);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.gavel_outlined, color: _ComparePalette.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'AI Safety Scores',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _ComparePalette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: _ScoreBox(
                  score: scores.loanA.score,
                  rating: scores.loanA.rating,
                  color: _getRatingColor(scores.loanA.rating),
                  explanation: scores.loanA.explanation,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: _ScoreBox(
                  score: scores.loanB.score,
                  rating: scores.loanB.rating,
                  color: _getRatingColor(scores.loanB.rating),
                  explanation: scores.loanB.explanation,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ScoreBox extends StatelessWidget {
  final double score;
  final String rating;
  final Color color;
  final String explanation;

  const _ScoreBox({
    required this.score,
    required this.rating,
    required this.color,
    required this.explanation,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: Column(
        children: [
          Text(
            score.toStringAsFixed(1),
            style: GoogleFonts.spaceGrotesk(fontSize: 36, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(
              '$rating Risk',
              style: GoogleFonts.inter(fontSize: 10, fontWeight: FontWeight.w900, color: color),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            explanation,
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(fontSize: 11, height: 1.45, color: _ComparePalette.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

// SECTION 6: AI Insights (Reasons)
class _SectionAiInsights extends StatelessWidget {
  final List<AIRecommendationReasonItem> insights;
  final Set<int> expandedIndices;
  final Function(int) onToggle;

  const _SectionAiInsights({
    required this.insights,
    required this.expandedIndices,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.auto_awesome, color: _ComparePalette.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'AI Analysis Insights',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _ComparePalette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          ...List.generate(insights.length, (index) {
            final insight = insights[index];
            final isExpanded = expandedIndices.contains(index);

            return InkWell(
              onTap: () => onToggle(index),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.01),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.04)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.check_circle_outline, color: Color(0xFF81C784), size: 18),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            insight.title,
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 13,
                              fontWeight: FontWeight.bold,
                              color: const Color(0xFFECEFF1),
                            ),
                          ),
                        ),
                        Icon(
                          isExpanded ? Icons.keyboard_arrow_up : Icons.keyboard_arrow_down,
                          color: _ComparePalette.onSurfaceVariant,
                          size: 18,
                        ),
                      ],
                    ),
                    if (isExpanded) ...[
                      const SizedBox(height: 10),
                      Padding(
                        padding: const EdgeInsets.only(left: 28),
                        child: Text(
                          insight.insight,
                          style: GoogleFonts.inter(
                            fontSize: 12,
                            height: 1.5,
                            color: _ComparePalette.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

// SECTION 7: Clause-by-Clause Comparison
class _SectionClauseComparison extends StatelessWidget {
  final List<ClauseComparisonItem> clauses;
  final String lenderA;
  final String lenderB;
  final Set<int> expandedIndices;
  final Function(int) onToggle;

  const _SectionClauseComparison({
    required this.clauses,
    required this.lenderA,
    required this.lenderB,
    required this.expandedIndices,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.library_books_outlined, color: _ComparePalette.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Clause-by-Clause Audit',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _ComparePalette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          if (clauses.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 20),
              child: Center(
                child: Text(
                  'No legal clause discrepancies detected.',
                  style: GoogleFonts.inter(fontSize: 12, color: _ComparePalette.onSurfaceVariant),
                ),
              ),
            )
          else
            ...List.generate(clauses.length, (index) {
              final item = clauses[index];
              final isExpanded = expandedIndices.contains(index);

              return Container(
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.02),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () => onToggle(index),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.clauseATitle,
                                    style: GoogleFonts.spaceGrotesk(
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                      color: _ComparePalette.primary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Confidence Match: ${(item.confidenceScore * 100).toStringAsFixed(0)}%',
                                    style: GoogleFonts.inter(fontSize: 10, color: _ComparePalette.onSurfaceVariant),
                                  ),
                                ],
                              ),
                            ),
                            Icon(
                              isExpanded ? Icons.expand_less : Icons.expand_more,
                              color: _ComparePalette.primary,
                              size: 20,
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (isExpanded) ...[
                      Divider(color: Colors.white.withValues(alpha: 0.06), height: 1),
                      Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Clause A
                            _ClauseExtractBox(
                              lender: lenderA,
                              title: item.clauseATitle,
                              text: item.clauseAText,
                              page: item.clauseAPage,
                            ),
                            const SizedBox(height: 12),
                            // Clause B
                            _ClauseExtractBox(
                              lender: lenderB,
                              title: item.clauseBTitle,
                              text: item.clauseBText,
                              page: item.clauseBPage,
                            ),
                            const SizedBox(height: 14),
                            // Comparison
                            Text(
                              'AI COMPARISON EXPLANATION',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 9, 
                                fontWeight: FontWeight.bold, 
                                color: _ComparePalette.primary.withValues(alpha: 0.7),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.aiExplanation,
                              style: GoogleFonts.inter(fontSize: 12, height: 1.45, color: _ComparePalette.onSurface),
                            ),
                            const SizedBox(height: 12),
                            // Risk Difference
                            Text(
                              'RISK DIFFERENCE',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 9, 
                                fontWeight: FontWeight.bold, 
                                color: _ComparePalette.primary.withValues(alpha: 0.7),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.riskDifference,
                              style: GoogleFonts.inter(fontSize: 12, height: 1.45, color: const Color(0xFFE57373)),
                            ),
                            const SizedBox(height: 12),
                            // Recommendation
                            Text(
                              'AI ACTION RECOMMENDATION',
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 9, 
                                fontWeight: FontWeight.bold, 
                                color: _ComparePalette.primary.withValues(alpha: 0.7),
                                letterSpacing: 0.8,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              item.recommendation,
                              style: GoogleFonts.inter(fontSize: 12, height: 1.45, color: const Color(0xFF81C784)),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              );
            }),
        ],
      ),
    );
  }
}

class _ClauseExtractBox extends StatelessWidget {
  final String lender;
  final String title;
  final String text;
  final int? page;

  const _ClauseExtractBox({
    required this.lender,
    required this.title,
    required this.text,
    required this.page,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.01),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                lender.toUpperCase(),
                style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: _ComparePalette.primary),
              ),
              const Spacer(),
              if (page != null)
                Text(
                  'Page $page',
                  style: GoogleFonts.inter(fontSize: 9, fontStyle: FontStyle.italic, color: _ComparePalette.onSurfaceVariant),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            text.isEmpty ? 'Clause not explicitly stated in agreement.' : '"$text"',
            style: GoogleFonts.inter(
              fontSize: 11, 
              height: 1.45, 
              fontStyle: text.isEmpty ? FontStyle.italic : null,
              color: text.isEmpty ? _ComparePalette.onSurfaceVariant : _ComparePalette.onSurface.withValues(alpha: 0.8),
            ),
          ),
        ],
      ),
    );
  }
}

// SECTION 8: Charts
class _SectionCharts extends StatelessWidget {
  final ChartsData charts;
  final String lenderA;
  final String lenderB;

  const _SectionCharts({
    required this.charts,
    required this.lenderA,
    required this.lenderB,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.bar_chart, color: _ComparePalette.primary, size: 20),
              const SizedBox(width: 10),
              Text(
                'Cost & Risk Visualizer',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _ComparePalette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),

          // Total Repayment Comparison Chart (Side-by-side bars)
          Text(
            'TOTAL REPAYMENT COST',
            style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: _ComparePalette.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          _CustomBarChart(
            valA: charts.totalRepaymentA,
            valB: charts.totalRepaymentB,
            labelA: lenderA,
            labelB: lenderB,
            formatter: (v) => 'INR ${(v / 100000).toStringAsFixed(1)}L',
          ),
          const SizedBox(height: 24),

          // Interest Comparison Chart
          Text(
            'TOTAL INTEREST PAYABLE',
            style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: _ComparePalette.onSurfaceVariant),
          ),
          const SizedBox(height: 10),
          _CustomBarChart(
            valA: charts.totalInterestA,
            valB: charts.totalInterestB,
            labelA: lenderA,
            labelB: lenderB,
            color: const Color(0xFFDBC3A8),
            formatter: (v) => 'INR ${(v / 100000).toStringAsFixed(1)}L',
          ),
          const SizedBox(height: 24),

          // Cost Breakdown Stacked Bars (Principal vs Interest vs Fees)
          Text(
            'COST BREAKDOWN DETAILS',
            style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: _ComparePalette.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _CostCompositionBar(label: lenderA, cost: charts.costBreakdownA),
          const SizedBox(height: 14),
          _CostCompositionBar(label: lenderB, cost: charts.costBreakdownB),
          const SizedBox(height: 8),
          // Legend
          const Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _LegendItem(color: _ComparePalette.primary, label: 'Principal'),
              SizedBox(width: 14),
              _LegendItem(color: Color(0xFFDBC3A8), label: 'Interest'),
              SizedBox(width: 14),
              _LegendItem(color: Color(0xFFE57373), label: 'Fees'),
            ],
          ),
          const SizedBox(height: 24),

          // Risk Distribution
          Text(
            'RISK DISTRIBUTION BY SEVERITY',
            style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: _ComparePalette.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          _RiskDistributionBar(lender: lenderA, severity: charts.riskA),
          const SizedBox(height: 12),
          _RiskDistributionBar(lender: lenderB, severity: charts.riskB),
        ],
      ),
    );
  }
}

class _CustomBarChart extends StatelessWidget {
  final double valA;
  final double valB;
  final String labelA;
  final String labelB;
  final Color color;
  final String Function(double) formatter;

  const _CustomBarChart({
    required this.valA,
    required this.valB,
    required this.labelA,
    required this.labelB,
    this.color = _ComparePalette.primary,
    required this.formatter,
  });

  @override
  Widget build(BuildContext context) {
    final maxVal = max(1.0, max(valA, valB));
    final widthA = (valA / maxVal).clamp(0.05, 1.0);
    final widthB = (valB / maxVal).clamp(0.05, 1.0);

    return Column(
      children: [
        _SingleBar(label: labelA, fraction: widthA, displayVal: formatter(valA), color: color),
        const SizedBox(height: 8),
        _SingleBar(label: labelB, fraction: widthB, displayVal: formatter(valB), color: color.withValues(alpha: 0.6)),
      ],
    );
  }
}

class _SingleBar extends StatelessWidget {
  final String label;
  final double fraction;
  final String displayVal;
  final Color color;

  const _SingleBar({
    required this.label,
    required this.fraction,
    required this.displayVal,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 11, color: _ComparePalette.onSurfaceVariant),
              ),
            ),
            Text(
              displayVal,
              style: GoogleFonts.spaceGrotesk(fontSize: 11, fontWeight: FontWeight.bold, color: _ComparePalette.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          height: 12,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.04),
            borderRadius: BorderRadius.circular(6),
          ),
          alignment: Alignment.centerLeft,
          child: FractionallySizedBox(
            widthFactor: fraction,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(6),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CostCompositionBar extends StatelessWidget {
  final String label;
  final CostBreakdownPoint cost;

  const _CostCompositionBar({required this.label, required this.cost});

  @override
  Widget build(BuildContext context) {
    final total = max(1.0, cost.principal + cost.interest + cost.fees);
    final pFraction = (cost.principal / total).clamp(0.0, 1.0);
    final iFraction = (cost.interest / total).clamp(0.0, 1.0);
    final fFraction = (cost.fees / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: GoogleFonts.inter(fontSize: 11, color: _ComparePalette.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          height: 14,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              if (pFraction > 0.01)
                Expanded(
                  flex: (pFraction * 1000).toInt(),
                  child: Container(color: _ComparePalette.primary),
                ),
              if (iFraction > 0.01)
                Expanded(
                  flex: (iFraction * 1000).toInt(),
                  child: Container(color: const Color(0xFFDBC3A8)),
                ),
              if (fFraction > 0.01)
                Expanded(
                  flex: (fFraction * 1000).toInt(),
                  child: Container(color: const Color(0xFFE57373)),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

class _LegendItem extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendItem({required this.color, required this.label});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(width: 8, height: 8, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
        const SizedBox(width: 6),
        Text(label, style: GoogleFonts.inter(fontSize: 10, color: _ComparePalette.onSurfaceVariant)),
      ],
    );
  }
}

class _RiskDistributionBar extends StatelessWidget {
  final String lender;
  final RiskSeverityCount severity;

  const _RiskDistributionBar({required this.lender, required this.severity});

  @override
  Widget build(BuildContext context) {
    final total = max(1.0, severity.high + severity.medium + severity.low + 0.0);
    final highF = (severity.high / total).clamp(0.0, 1.0);
    final medF = (severity.medium / total).clamp(0.0, 1.0);
    final lowF = (severity.low / total).clamp(0.0, 1.0);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                lender,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.inter(fontSize: 11, color: _ComparePalette.onSurfaceVariant),
              ),
            ),
            Text(
              'H:${severity.high}  M:${severity.medium}  L:${severity.low}',
              style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: _ComparePalette.onSurface),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Container(
          width: double.infinity,
          height: 10,
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(4),
          ),
          child: Row(
            children: [
              if (severity.high > 0)
                Expanded(
                  flex: (highF * 1000).toInt(),
                  child: Container(color: const Color(0xFFE57373)), // Red
                ),
              if (severity.medium > 0)
                Expanded(
                  flex: (medF * 1000).toInt(),
                  child: Container(color: const Color(0xFFFFD54F)), // Yellow
                ),
              if (severity.low > 0)
                Expanded(
                  flex: (lowF * 1000).toInt(),
                  child: Container(color: const Color(0xFF81C784)), // Green
                ),
              if (severity.high == 0 && severity.medium == 0 && severity.low == 0)
                Expanded(
                  child: Container(color: Colors.white.withValues(alpha: 0.04)),
                )
            ],
          ),
        ),
      ],
    );
  }
}

// SECTION 9: Final Decision Card
class _SectionFinalDecision extends StatelessWidget {
  final FinalDecisionCard decision;
  const _SectionFinalDecision({required this.decision});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _ComparePalette.primary.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _ComparePalette.primary.withValues(alpha: 0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.done_all, color: _ComparePalette.primary, size: 22),
              const SizedBox(width: 10),
              Text(
                'Final Decision Checklist',
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: _ComparePalette.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            'Recommended Option',
            style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: _ComparePalette.onSurfaceVariant),
          ),
          Text(
            decision.recommendedLoan,
            style: GoogleFonts.spaceGrotesk(fontSize: 20, fontWeight: FontWeight.bold, color: const Color(0xFFE2E5F3)),
          ),
          const SizedBox(height: 14),

          // Key Reasons
          Text(
            'KEY ADVANTAGES',
            style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFF81C784)),
          ),
          const SizedBox(height: 6),
          ...decision.keyReasons.map((reason) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(Icons.check, color: Color(0xFF81C784), size: 14),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        reason,
                        style: GoogleFonts.inter(fontSize: 12, color: _ComparePalette.onSurface),
                      ),
                    ),
                  ],
                ),
              )),
          const SizedBox(height: 14),

          // Potential Concerns
          if (decision.potentialConcerns.isNotEmpty) ...[
            Text(
              'POTENTIAL CONCERNS',
              style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: const Color(0xFFE57373)),
            ),
            const SizedBox(height: 6),
            ...decision.potentialConcerns.map((concern) => Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.close, color: Color(0xFFE57373), size: 14),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          concern,
                          style: GoogleFonts.inter(fontSize: 12, color: _ComparePalette.onSurface),
                        ),
                      ),
                    ],
                  ),
                )),
            const SizedBox(height: 14),
          ],

          // Action Recommendation
          Text(
            'RECOMMENDED ACTION STEPS',
            style: GoogleFonts.spaceGrotesk(fontSize: 10, fontWeight: FontWeight.bold, color: _ComparePalette.primary),
          ),
          const SizedBox(height: 6),
          Text(
            decision.actionRecommendation,
            style: GoogleFonts.inter(fontSize: 12, height: 1.45, color: _ComparePalette.onSurface),
          ),
        ],
      ),
    );
  }
}

// Background blur elements
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
                      fontSize: 22,
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
        const SizedBox(height: 16),
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 20),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.03),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _ComparePalette.primary.withValues(alpha: 0.10),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.upload_file,
                      color: _ComparePalette.primary, size: 24),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _ComparePalette.primary,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        fileName ?? 'Select PDF agreement',
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w500,
                          color: fileName != null ? const Color(0xFF81C784) : _ComparePalette.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                if (loading)
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(
                      strokeWidth: 2.5,
                      color: _ComparePalette.primary,
                    ),
                  )
                else if (fileName != null)
                  const Icon(Icons.check_circle, size: 20, color: Color(0xFF81C784))
                else
                  const Icon(Icons.arrow_forward_ios, size: 14, color: _ComparePalette.primary),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BottomDock extends StatelessWidget {
  final VoidCallback onHome;
  final VoidCallback onAnalyse;
  final VoidCallback? onAssistant;
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
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
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

class _ComparePalette {
  static const background = Color(0xFF131314);
  static const surfaceContainer = Color(0xFF201F20);
  static const surfaceContainerHighest = Color(0xFF353436);
  static const primary = Color(0xFFC3C6D7);
  static const tertiary = Color(0xFFDBC3A8);
  static const error = Color(0xFFFFB4AB);
  static const onSurface = Color(0xFFE5E2E3);
  static const onSurfaceVariant = Color(0xFFC7C6CC);
}
