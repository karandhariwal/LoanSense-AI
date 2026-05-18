import 'dart:async';
import 'dart:math';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loansense_ai/ui/screens/chat_screen.dart';
import 'package:loansense_ai/ui/screens/home_dashboard_screen.dart';

class LoanAnalysisReportScreen extends StatefulWidget {
  final LoanAnalysisReport? report;
  final String? loanId;

  const LoanAnalysisReportScreen({
    super.key,
    this.report,
    this.loanId,
  });

  @override
  State<LoanAnalysisReportScreen> createState() =>
      _LoanAnalysisReportScreenState();
}

class _LoanAnalysisReportScreenState extends State<LoanAnalysisReportScreen>
    with TickerProviderStateMixin {
  late final LoanAnalysisController _controller;
  late final AnimationController _ambientController;
  late final ScrollController _scrollController;

  @override
  void initState() {
    super.initState();
    _controller = LoanAnalysisController(
      report: widget.report ??
          LoanAnalysisReport.mock(
            loanId: widget.loanId ?? 'lns-demo-042',
          ),
    )..load();

    _ambientController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 5),
    )..repeat(reverse: true);

    _scrollController = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _ambientController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: _LensColors.background,
      body: AnimatedBuilder(
        animation: Listenable.merge([_controller, _ambientController]),
        builder: (context, _) {
          return Stack(
            children: [
              _AmbientBackdrop(controller: _ambientController),
              SafeArea(
                bottom: false,
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 104),
                  child: _controller.isLoading
                      ? _LoadingShell(controller: _ambientController)
                      : _ReportScrollView(
                          controller: _controller,
                          ambientController: _ambientController,
                          scrollController: _scrollController,
                          onOpenAssistant: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ChatScreen(
                                  loanId: _controller.report.loanId,
                                ),
                              ),
                            );
                          },
                          onGoHome: () {
                            Navigator.of(context).pushReplacement(
                              MaterialPageRoute(
                                builder: (_) => const HomeDashboardScreen(),
                              ),
                            );
                          },
                        ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class LoanAnalysisController extends ChangeNotifier {
  LoanAnalysisReport report;
  bool isLoading = true;
  bool showSimpleExplanation = false;
  bool showCostExpansion = false;
  final Set<String> expandedAlertIds = <String>{};

  LoanAnalysisController({required this.report});

  Future<void> load() async {
    await Future<void>.delayed(const Duration(milliseconds: 1150));
    isLoading = false;
    notifyListeners();
  }

  void toggleSimpleExplanation() {
    showSimpleExplanation = !showSimpleExplanation;
    notifyListeners();
  }

  void toggleCostExpansion() {
    showCostExpansion = !showCostExpansion;
    notifyListeners();
  }

  void toggleAlert(String id) {
    if (expandedAlertIds.contains(id)) {
      expandedAlertIds.remove(id);
    } else {
      expandedAlertIds.add(id);
    }
    notifyListeners();
  }
}

class LoanAnalysisReport {
  final String loanId;
  final String lenderName;
  final String productName;
  final double healthScore;
  final String healthSummary;
  final String detailedSummary;
  final String simpleSummary;
  final String recommendedAction;
  final String contractClarity;
  final List<MetricData> metrics;
  final List<RiskAlertData> alerts;
  final List<SourceReference> sources;
  final List<CostSlice> costSlices;
  final List<EmiPoint> emiSeries;
  final List<ClauseChip> clauseChips;
  final List<LoanExtraction> extractions;

  const LoanAnalysisReport({
    required this.loanId,
    required this.lenderName,
    required this.productName,
    required this.healthScore,
    required this.healthSummary,
    required this.detailedSummary,
    required this.simpleSummary,
    required this.recommendedAction,
    required this.contractClarity,
    required this.metrics,
    required this.alerts,
    required this.sources,
    required this.costSlices,
    required this.emiSeries,
    required this.clauseChips,
    required this.extractions,
  });

  factory LoanAnalysisReport.mock({required String loanId}) {
    return LoanAnalysisReport(
      loanId: loanId,
      lenderName: 'Northstar Finance',
      productName: 'Variable Term Loan',
      healthScore: 6.8,
      healthSummary:
          'Your loan profile shows moderate structural health with specific optimizations required.',
      detailedSummary:
          'This loan contains moderate financial risk due to high foreclosure penalties and an aggressive variable interest reset in Year 5. While the initial APR is competitive, the long-term compounding of hidden service fees adds approximately 3.2% to your effective cost.',
      simpleSummary:
          'The loan is usable, but there are several cost traps. The biggest issues are the pre-payment penalty, the rate reset in year 5, and fees that quietly raise your total cost.',
      recommendedAction: 'Refinance in 24 months',
      contractClarity: '92% Transparent',
      metrics: const [
        MetricData(
          id: 'rate',
          label: 'Interest Rate',
          value: '8.45%',
          valueSuffix: '↑ 0.2',
          accent: _LensColors.primary,
          icon: Icons.percent_rounded,
          secondaryLabel: 'APR is competitive, but resets later.',
          detailTitle: 'Interest Rate Exposure',
          detailBody:
              'The current rate is attractive, but the contract includes a variable reset in Year 5. If macro rates move higher, the payment curve changes quickly.',
        ),
        MetricData(
          id: 'hidden',
          label: 'Hidden Charges',
          value: '\$1,240',
          valueSuffix: 'Verify',
          accent: _LensColors.tertiary,
          icon: Icons.payments_outlined,
          secondaryLabel: 'Service fees are layered into the schedule.',
          detailTitle: 'Hidden Charges',
          detailBody:
              'The extraction engine found documentation, processing, and clause-linked service costs that do not appear in the headline APR.',
        ),
        MetricData(
          id: 'total',
          label: 'Total Repayment',
          value: '\$412,800',
          valueSuffix: 'Full term',
          accent: _LensColors.primary,
          icon: Icons.account_balance_wallet_outlined,
          secondaryLabel: 'Includes scheduled installments only.',
          detailTitle: 'Repayment Projection',
          detailBody:
              'The repayment projection assumes the current amortization schedule without early closure or refinancing.',
        ),
        MetricData(
          id: 'risk',
          label: 'Foreclosure Risk',
          value: 'High',
          valueSuffix: 'Alert',
          accent: _LensColors.error,
          icon: Icons.warning_amber_rounded,
          secondaryLabel: 'Penalty terms are above market average.',
          detailTitle: 'Foreclosure Exposure',
          detailBody:
              'Early closure penalties are 1.5% above the market benchmark, which makes voluntary exit materially expensive.',
          isRisk: true,
        ),
      ],
      alerts: const [
        RiskAlertData(
          id: 'penalty',
          title: 'Pre-payment Penalty',
          body:
              'A 4% penalty applies if loan is closed before month 36. This is 1.5% above market average.',
          severity: 'High',
          accent: _LensColors.error,
          page: 'Page 12',
          clause: 'Clause 8.4',
          explanation:
              'This clause increases exit cost and reduces refinance flexibility during the early amortization phase.',
        ),
        RiskAlertData(
          id: 'variable',
          title: 'Variable Rate Cap',
          body:
              'Interest cap is set at 12%, posing a risk if central bank rates continue trending upwards.',
          severity: 'Medium',
          accent: _LensColors.tertiary,
          page: 'Page 9',
          clause: 'Clause 5.1',
          explanation:
              'The cap protects against unlimited escalation, but it still leaves meaningful payment volatility.',
        ),
        RiskAlertData(
          id: 'docs',
          title: 'Documentation Fee',
          body:
              'Processing fees are waived for your current credit tier. Saving: \$450.',
          severity: 'Verified',
          accent: _LensColors.primary,
          page: 'Page 3',
          clause: 'Fee schedule',
          explanation:
              'This item is favorable. The parser marked it as waived, so it does not materially affect the loan price.',
        ),
        RiskAlertData(
          id: 'reset',
          title: 'Rate Reset Clause',
          body:
              'Year 5 reset is tied to a benchmark index with a 250 bps margin add-on.',
          severity: 'High',
          accent: Color(0xFFFFB8B0),
          page: 'Page 18',
          clause: 'Clause 11.2',
          explanation:
              'If the benchmark rises, the effective monthly installment can jump sharply after the reset date.',
        ),
      ],
      sources: const [
        SourceReference(
          page: 'Page 3',
          title: 'Fee Schedule',
          note: 'Documentation fee and waiver condition.',
        ),
        SourceReference(
          page: 'Page 9',
          title: 'Rate Adjustment',
          note: 'Variable cap and reset benchmark.',
        ),
        SourceReference(
          page: 'Page 12',
          title: 'Early Exit Terms',
          note: 'Pre-payment penalty mechanics.',
        ),
        SourceReference(
          page: 'Page 18',
          title: 'Reset Clause',
          note: 'Year 5 interest recalculation.',
        ),
      ],
      costSlices: const [
        CostSlice(label: 'Principal', value: 250000, ratio: 0.60, accent: _LensColors.primary),
        CostSlice(label: 'Interest', value: 162800, ratio: 0.35, accent: _LensColors.outline),
        CostSlice(label: 'Hidden Costs', value: 12400, ratio: 0.05, accent: _LensColors.error),
      ],
      emiSeries: const [
        EmiPoint(month: 1, principal: 14000, interest: 7800),
        EmiPoint(month: 2, principal: 14500, interest: 7300),
        EmiPoint(month: 3, principal: 15000, interest: 6900),
        EmiPoint(month: 4, principal: 15400, interest: 6500),
        EmiPoint(month: 5, principal: 15900, interest: 6100),
        EmiPoint(month: 6, principal: 16300, interest: 5700),
        EmiPoint(month: 7, principal: 16750, interest: 5300),
        EmiPoint(month: 8, principal: 17100, interest: 4900),
        EmiPoint(month: 9, principal: 17500, interest: 4500),
        EmiPoint(month: 10, principal: 17950, interest: 4100),
        EmiPoint(month: 11, principal: 18450, interest: 3700),
        EmiPoint(month: 12, principal: 18900, interest: 3300),
      ],
      clauseChips: const [
        ClauseChip(label: 'Rate reset in Year 5', accent: _LensColors.error),
        ClauseChip(label: 'Penalty 4% before month 36', accent: _LensColors.error),
        ClauseChip(label: 'APR baseline 8.45%', accent: _LensColors.primary),
      ],
      extractions: const [
        LoanExtraction(label: 'Sanction Amount', value: '\$250,000'),
        LoanExtraction(label: 'Reset Window', value: 'Year 5'),
        LoanExtraction(label: 'Penalty Window', value: 'Month 1-36'),
        LoanExtraction(label: 'Effective Cost Uplift', value: '+3.2%'),
      ],
    );
  }

  factory LoanAnalysisReport.fromJson(Map<String, dynamic> json) {
    return LoanAnalysisReport(
      loanId: json['loanId']?.toString() ?? 'loan-unknown',
      lenderName: json['lenderName']?.toString() ?? 'Unknown lender',
      productName: json['productName']?.toString() ?? 'Loan product',
      healthScore: (json['healthScore'] as num?)?.toDouble() ?? 0,
      healthSummary: json['healthSummary']?.toString() ?? '',
      detailedSummary: json['detailedSummary']?.toString() ?? '',
      simpleSummary: json['simpleSummary']?.toString() ?? '',
      recommendedAction: json['recommendedAction']?.toString() ?? '',
      contractClarity: json['contractClarity']?.toString() ?? '',
      metrics: const [],
      alerts: const [],
      sources: const [],
      costSlices: const [],
      emiSeries: const [],
      clauseChips: const [],
      extractions: const [],
    );
  }
}

class MetricData {
  final String id;
  final String label;
  final String value;
  final String valueSuffix;
  final Color accent;
  final IconData icon;
  final String secondaryLabel;
  final String detailTitle;
  final String detailBody;
  final bool isRisk;

  const MetricData({
    required this.id,
    required this.label,
    required this.value,
    required this.valueSuffix,
    required this.accent,
    required this.icon,
    required this.secondaryLabel,
    required this.detailTitle,
    required this.detailBody,
    this.isRisk = false,
  });
}

class RiskAlertData {
  final String id;
  final String title;
  final String body;
  final String severity;
  final Color accent;
  final String page;
  final String clause;
  final String explanation;

  const RiskAlertData({
    required this.id,
    required this.title,
    required this.body,
    required this.severity,
    required this.accent,
    required this.page,
    required this.clause,
    required this.explanation,
  });
}

class SourceReference {
  final String page;
  final String title;
  final String note;

  const SourceReference({
    required this.page,
    required this.title,
    required this.note,
  });
}

class CostSlice {
  final String label;
  final double value;
  final double ratio;
  final Color accent;

  const CostSlice({
    required this.label,
    required this.value,
    required this.ratio,
    required this.accent,
  });
}

class EmiPoint {
  final int month;
  final double principal;
  final double interest;

  const EmiPoint({
    required this.month,
    required this.principal,
    required this.interest,
  });
}

class ClauseChip {
  final String label;
  final Color accent;

  const ClauseChip({
    required this.label,
    required this.accent,
  });
}

class LoanExtraction {
  final String label;
  final String value;

  const LoanExtraction({
    required this.label,
    required this.value,
  });
}

class _LensColors {
  static const background = Color(0xFF131314);
  static const surface = Color(0xFF131314);
  static const surfaceContainer = Color(0xFF201F20);
  static const primary = Color(0xFFC3C6D7);
  static const secondary = Color(0xFFC6C6CD);
  static const tertiary = Color(0xFFDBC3A8);
  static const outline = Color(0xFF909096);
  static const onSurface = Color(0xFFE5E2E3);
  static const onSurfaceVariant = Color(0xFFC7C6CC);
  static const onPrimary = Color(0xFF2C303D);
  static const error = Color(0xFFFFB4AB);
}

class _ReportScrollView extends StatelessWidget {
  final LoanAnalysisController controller;
  final AnimationController ambientController;
  final ScrollController scrollController;
  final VoidCallback onOpenAssistant;
  final VoidCallback onGoHome;

  const _ReportScrollView({
    required this.controller,
    required this.ambientController,
    required this.scrollController,
    required this.onOpenAssistant,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    final report = controller.report;
    return CustomScrollView(
      controller: scrollController,
      physics: const BouncingScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: SizedBox(height: 76)),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          sliver: SliverList(
            delegate: SliverChildListDelegate.fixed([
              _TopAppBar(
                report: report,
                onOpenSources: () => _openSourcesSheet(context, report),
                onGoHome: onGoHome,
              ),
              const SizedBox(height: 20),
              _HeroScoreCard(
                report: report,
                controller: controller,
                onOpenSources: () => _openReportSheet(context, report),
              ),
              const SizedBox(height: 20),
              _MetricGrid(
                report: report,
                onMetricTap: (metric) =>
                    _openMetricSheet(context, report, metric),
              ),
              const SizedBox(height: 20),
              _InsightCard(
                report: report,
                controller: controller,
                onAskAssistant: onOpenAssistant,
              ),
              const SizedBox(height: 28),
              _AlertsSection(
                report: report,
                controller: controller,
                onOpenAlertReference: (alert) =>
                    _openAlertSheet(context, report, alert),
              ),
              const SizedBox(height: 28),
              _CostCard(
                report: report,
                controller: controller,
                ambientController: ambientController,
                onOpenActions: () => _openExportSheet(context, report),
              ),
              const SizedBox(height: 24),
              const _BottomSpacer(),
            ]),
          ),
        ),
      ],
    );
  }
}

class _TopAppBar extends StatelessWidget {
  final LoanAnalysisReport report;
  final VoidCallback onOpenSources;
  final VoidCallback onGoHome;

  const _TopAppBar({
    required this.report,
    required this.onOpenSources,
    required this.onGoHome,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            color: _LensColors.background.withValues(alpha: 0.78),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            boxShadow: [
              BoxShadow(
                color: _LensColors.primary.withValues(alpha: 0.10),
                blurRadius: 15,
              ),
            ],
          ),
          child: Row(
            children: [
              GestureDetector(
                onTap: onGoHome,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _LensColors.primary.withValues(alpha: 0.18),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: _LensColors.primary.withValues(alpha: 0.08),
                        blurRadius: 16,
                      ),
                    ],
                  ),
                  child: ClipOval(
                    child: Image.network(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuD-zGQQ_at1eS8nA9kwpdIGLq5H_dAvAHn4CsOkvw3pt5NF0GiLRX_z5ZZJSWhI2ClwyRw0h8eFk_4HHvYzkA_8946tZZ0KlglqQPW4Mbnv4rlwGro7u0oYH1A1qG1xCMK16IwzjnVg0tQ5BF_SRFoAFypFG3HfYksRzy9YBuRpEXnRiJgzcE_JuQU9L84E5PrXmFaE0THfYJkfLeqYTo_LMQEFmMy8EdPL8jyISj9Qymi6Qjcf6xzpEI6gTHbck94snxAh_YYSiQ',
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(
                        color: _LensColors.surface,
                        child: const Icon(Icons.person, color: _LensColors.primary),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'LoanSense AI',
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                        color: _LensColors.onSurface,
                        height: 1.1,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 2),
                    Row(
                      children: [
                        Container(
                          width: 6,
                          height: 6,
                          decoration: const BoxDecoration(
                            color: _LensColors.primary,
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: _LensColors.primary,
                                blurRadius: 8,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          report.productName.toUpperCase(),
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: _LensColors.onSurfaceVariant,
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onOpenSources,
                icon: const Icon(
                  Icons.sensors_outlined,
                  color: _LensColors.primary,
                  size: 22,
                ),
                tooltip: 'Source references',
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HeroScoreCard extends StatelessWidget {
  final LoanAnalysisReport report;
  final LoanAnalysisController controller;
  final VoidCallback onOpenSources;

  const _HeroScoreCard({
    required this.report,
    required this.controller,
    required this.onOpenSources,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      onTap: onOpenSources,
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: _PillLabel(
              label: 'AI ANALYSIS COMPLETE',
              accent: _LensColors.primary,
            ),
          ),
          const SizedBox(height: 10),
          TweenAnimationBuilder<double>(
            tween: Tween<double>(begin: 0, end: report.healthScore / 10),
            duration: const Duration(milliseconds: 1300),
            curve: Curves.easeOutCubic,
            builder: (context, progress, _) {
              return SizedBox(
                width: 178,
                height: 178,
                child: CustomPaint(
                  painter: _ScoreRingPainter(
                    progress: progress,
                    glow: 0.9,
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ShaderMask(
                          shaderCallback: (rect) => const LinearGradient(
                            begin: Alignment.topLeft,
                            end: Alignment.bottomRight,
                            colors: [
                              Color(0xFFE5E2E3),
                              Color(0xFFB7B9C6),
                            ],
                          ).createShader(rect),
                          child: Text(
                            report.healthScore.toStringAsFixed(1),
                            style: GoogleFonts.spaceGrotesk(
                              fontSize: 48,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                              height: 1.0,
                            ),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'HEALTH SCORE',
                          style: GoogleFonts.inter(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: _LensColors.onSurfaceVariant,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            },
          ),
          const SizedBox(height: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 240),
            child: Text(
              controller.showSimpleExplanation
                  ? report.simpleSummary
                  : report.healthSummary,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.55,
                color: _LensColors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Container(
            height: 1,
            width: double.infinity,
            color: Colors.white.withValues(alpha: 0.08),
          ),
          const SizedBox(height: 12),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: controller.toggleSimpleExplanation,
              style: TextButton.styleFrom(
                foregroundColor: _LensColors.primary,
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
              child: Text(
                controller.showSimpleExplanation
                    ? 'Show detail'
                    : 'Explain simpler',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.3,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MetricGrid extends StatelessWidget {
  final LoanAnalysisReport report;
  final ValueChanged<MetricData> onMetricTap;

  const _MetricGrid({
    required this.report,
    required this.onMetricTap,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      itemCount: report.metrics.length,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 14,
        crossAxisSpacing: 14,
        childAspectRatio: 0.94,
      ),
      itemBuilder: (context, index) {
        final metric = report.metrics[index];
        return _MetricCard(
          data: metric,
          onTap: () => onMetricTap(metric),
        );
      },
    );
  }
}

class _MetricCard extends StatelessWidget {
  final MetricData data;
  final VoidCallback onTap;

  const _MetricCard({
    required this.data,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = data.isRisk
        ? _LensColors.error.withValues(alpha: 0.22)
        : Colors.white.withValues(alpha: 0.12);

    return _GlassCard(
      onTap: onTap,
      borderColor: borderColor,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(
            data.icon,
            color: data.accent,
            size: 20,
          ),
          const SizedBox(height: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                data.label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color: _LensColors.onSurfaceVariant,
                  letterSpacing: 0.6,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.value,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color:
                      data.isRisk ? _LensColors.error : _LensColors.onSurface,
                  height: 1.0,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                data.valueSuffix,
                style: GoogleFonts.inter(
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                  color:
                      data.isRisk ? _LensColors.error : _LensColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          Text(
            data.secondaryLabel,
            style: GoogleFonts.inter(
              fontSize: 10,
              height: 1.2,
              color: _LensColors.onSurfaceVariant.withValues(alpha: 0.88),
            ),
          ),
        ],
      ),
    );
  }
}

class _InsightCard extends StatelessWidget {
  final LoanAnalysisReport report;
  final LoanAnalysisController controller;
  final VoidCallback onAskAssistant;

  const _InsightCard({
    required this.report,
    required this.controller,
    required this.onAskAssistant,
  });

  @override
  Widget build(BuildContext context) {
    final summary = controller.showSimpleExplanation
        ? report.simpleSummary
        : report.detailedSummary;

    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: Stack(
        children: [
          Positioned(
            top: 0,
            right: 0,
            child: IgnorePointer(
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _LensColors.primary.withValues(alpha: 0.10),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.smart_toy_outlined,
                    color: _LensColors.primary,
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'AI Logic Insight',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: _LensColors.onSurface,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              AnimatedSize(
                duration: const Duration(milliseconds: 240),
                curve: Curves.easeOutCubic,
                child: Text(
                  '“${summary}”',
                  style: GoogleFonts.inter(
                    fontSize: 16,
                    height: 1.65,
                    color: _LensColors.onSurface,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerLeft,
                child: TextButton(
                  onPressed: controller.toggleSimpleExplanation,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: _LensColors.primary,
                  ),
                  child: Text(
                    controller.showSimpleExplanation
                        ? 'Return to technical view'
                        : 'Explain simpler',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 12,
                runSpacing: 12,
                children: [
                  _PrimaryPillButton(
                    label: 'Ask AI Assistant',
                    icon: Icons.chat_bubble_outline,
                    onPressed: onAskAssistant,
                  ),
                  _SecondaryPillButton(
                    label: 'Compare Another Loan',
                    onPressed: () {
                      _openCompareSheet(context, report);
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: _TinyPanel(
                      title: 'Recommended Action',
                      value: report.recommendedAction,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _TinyPanel(
                      title: 'Contract Clarity',
                      value: report.contractClarity,
                      valueColor: _LensColors.tertiary,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _AlertsSection extends StatelessWidget {
  final LoanAnalysisReport report;
  final LoanAnalysisController controller;
  final ValueChanged<RiskAlertData> onOpenAlertReference;

  const _AlertsSection({
    required this.report,
    required this.controller,
    required this.onOpenAlertReference,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Critical Alerts',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: _LensColors.onSurface,
                height: 1.1,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              width: 7,
              height: 7,
              decoration: const BoxDecoration(
                color: _LensColors.error,
                shape: BoxShape.circle,
              ),
            ),
          ],
        ),
        const SizedBox(height: 14),
        ...report.alerts.map((alert) {
          final expanded = controller.expandedAlertIds.contains(alert.id);
          return Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _ExpandableAlertCard(
              data: alert,
              expanded: expanded,
              onTap: () => controller.toggleAlert(alert.id),
              onOpenReference: () => onOpenAlertReference(alert),
            ),
          );
        }),
      ],
    );
  }
}

class _ExpandableAlertCard extends StatelessWidget {
  final RiskAlertData data;
  final bool expanded;
  final VoidCallback onTap;
  final VoidCallback onOpenReference;

  const _ExpandableAlertCard({
    required this.data,
    required this.expanded,
    required this.onTap,
    required this.onOpenReference,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      onTap: onTap,
      borderColor: data.accent.withValues(alpha: 0.22),
      leftBorderColor: data.accent,
      padding: const EdgeInsets.all(16),
      child: AnimatedSize(
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOutCubic,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  data.severity == 'Verified'
                      ? Icons.verified_outlined
                      : data.severity == 'Medium'
                          ? Icons.info_outline
                          : Icons.error_outline,
                  color: data.accent,
                  size: 18,
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Expanded(
                            child: Text(
                              data.title.toUpperCase(),
                              style: GoogleFonts.inter(
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                                color: _LensColors.primary,
                                letterSpacing: 0.7,
                              ),
                            ),
                          ),
                          _SeverityTag(
                            label: data.severity,
                            color: data.accent,
                          ),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        data.body,
                        style: GoogleFonts.inter(
                          fontSize: 14,
                          height: 1.45,
                          color: _LensColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (expanded) ...[
              const SizedBox(height: 14),
              Container(
                height: 1,
                color: Colors.white.withValues(alpha: 0.08),
              ),
              const SizedBox(height: 12),
              Text(
                data.explanation,
                style: GoogleFonts.inter(
                  fontSize: 13,
                  height: 1.5,
                  color: _LensColors.onSurface,
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  _CompactChip(text: data.page, accent: data.accent),
                  const SizedBox(width: 8),
                  _CompactChip(text: data.clause, accent: _LensColors.primary),
                  const Spacer(),
                  TextButton(
                    onPressed: onOpenReference,
                    child: Text(
                      'Open reference',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: _LensColors.primary,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _CostCard extends StatelessWidget {
  final LoanAnalysisReport report;
  final LoanAnalysisController controller;
  final AnimationController ambientController;
  final VoidCallback onOpenActions;

  const _CostCard({
    required this.report,
    required this.controller,
    required this.ambientController,
    required this.onOpenActions,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: GestureDetector(
        onTap: controller.toggleCostExpansion,
        behavior: HitTestBehavior.opaque,
        child: AnimatedSize(
          duration: const Duration(milliseconds: 260),
          curve: Curves.easeOutCubic,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Cost Breakdown',
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 24,
                      fontWeight: FontWeight.w500,
                      color: _LensColors.onSurface,
                      height: 1.1,
                    ),
                  ),
                  IconButton(
                    onPressed: onOpenActions,
                    icon: const Icon(
                      Icons.download_outlined,
                      color: _LensColors.onSurfaceVariant,
                    ),
                    tooltip: 'Copy or share',
                  ),
                ],
              ),
              const SizedBox(height: 18),
              ...report.costSlices.map((slice) {
                return Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: _CostSliceRow(
                    slice: slice,
                    onTap: () {
                      if (slice.label == 'Hidden Costs') {
                        _openHiddenChargesSheet(context, report);
                      }
                    },
                  ),
                );
              }),
              const SizedBox(height: 18),
              Container(
                height: 1,
                width: double.infinity,
                color: Colors.white.withValues(alpha: 0.10),
              ),
              const SizedBox(height: 18),
              Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Projected Total',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: _LensColors.onSurfaceVariant,
                          letterSpacing: 0.9,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '\$425,200',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: _LensColors.onSurface,
                          height: 1.0,
                        ),
                      ),
                    ],
                  ),
                  SizedBox(
                    width: 62,
                    height: 62,
                    child: CustomPaint(
                      painter: _HoloSpherePainter(
                        progress: ambientController.value,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: controller.toggleCostExpansion,
                  style: TextButton.styleFrom(
                    padding: EdgeInsets.zero,
                    foregroundColor: _LensColors.primary,
                  ),
                  child: Text(
                    controller.showCostExpansion
                        ? 'Hide EMI details'
                        : 'View EMI details',
                    style: GoogleFonts.inter(
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              if (controller.showCostExpansion) ...[
                const SizedBox(height: 12),
                _EmiBreakdownChart(series: report.emiSeries),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: report.extractions
                      .map(
                        (item) => _CompactChip(
                          text: '${item.label}: ${item.value}',
                          accent: _LensColors.primary,
                        ),
                      )
                      .toList(),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CostSliceRow extends StatelessWidget {
  final CostSlice slice;
  final VoidCallback onTap;

  const _CostSliceRow({
    required this.slice,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final labelColor = slice.label == 'Hidden Costs'
        ? _LensColors.error
        : _LensColors.onSurfaceVariant;
    final valueColor =
        slice.label == 'Hidden Costs' ? _LensColors.error : _LensColors.onSurface;

    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                slice.label.toUpperCase(),
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: labelColor,
                  letterSpacing: 0.7,
                ),
              ),
              Text(
                '\$${slice.value.toStringAsFixed(0)}',
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                  color: valueColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(9999),
            child: Container(
              height: 8,
              decoration: BoxDecoration(
                color: Colors.white.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(9999),
              ),
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: slice.ratio,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(9999),
                    gradient: LinearGradient(
                      colors: [
                        slice.accent.withValues(alpha: 0.95),
                        slice.accent.withValues(alpha: 0.55),
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: slice.accent.withValues(alpha: 0.25),
                        blurRadius: 12,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmiBreakdownChart extends StatelessWidget {
  final List<EmiPoint> series;

  const _EmiBreakdownChart({required this.series});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EMI Breakdown',
          style: GoogleFonts.spaceGrotesk(
            fontSize: 18,
            fontWeight: FontWeight.w500,
            color: _LensColors.onSurface,
          ),
        ),
        const SizedBox(height: 10),
        AspectRatio(
          aspectRatio: 1.8,
          child: RepaintBoundary(
            child: CustomPaint(
              painter: _EmiChartPainter(series: series),
            ),
          ),
        ),
      ],
    );
  }
}

class _BottomSpacer extends StatelessWidget {
  const _BottomSpacer();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(height: 8);
  }
}

class _LoadingShell extends StatelessWidget {
  final AnimationController controller;

  const _LoadingShell({required this.controller});

  @override
  Widget build(BuildContext context) {
    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 76, 20, 120),
      children: [
        const _TopSkeleton(),
        const SizedBox(height: 20),
        _LoadingCard(height: 256, controller: controller),
        const SizedBox(height: 16),
        _LoadingGrid(),
        const SizedBox(height: 16),
        _LoadingCard(height: 380, controller: controller),
        const SizedBox(height: 16),
        _LoadingCard(height: 240, controller: controller),
      ],
    );
  }
}

class _TopSkeleton extends StatelessWidget {
  const _TopSkeleton();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const _SkeletonCircle(size: 40),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _SkeletonLine(widthFactor: 0.42, height: 18),
              SizedBox(height: 8),
              _SkeletonLine(widthFactor: 0.22, height: 10),
            ],
          ),
        ),
        const _SkeletonCircle(size: 22),
      ],
    );
  }
}

class _LoadingCard extends StatelessWidget {
  final double height;
  final AnimationController controller;

  const _LoadingCard({required this.height, required this.controller});

  @override
  Widget build(BuildContext context) {
    return _GlassCard(
      padding: const EdgeInsets.all(18),
      child: SizedBox(
        height: height,
        child: AnimatedBuilder(
          animation: controller,
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const _SkeletonLine(widthFactor: 0.36, height: 16),
                const SizedBox(height: 16),
                _SkeletonCircle(size: height > 300 ? 170 : 120),
                const SizedBox(height: 16),
                const _SkeletonLine(widthFactor: 0.88, height: 12),
                const SizedBox(height: 8),
                const _SkeletonLine(widthFactor: 0.72, height: 12),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _LoadingGrid extends StatelessWidget {
  const _LoadingGrid();

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 14,
      crossAxisSpacing: 14,
      childAspectRatio: 0.94,
      children: List.generate(
        4,
        (index) => _GlassCard(
          padding: const EdgeInsets.all(14),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: const [
              _SkeletonCircle(size: 20),
              _SkeletonLine(widthFactor: 0.55, height: 10),
              _SkeletonLine(widthFactor: 0.72, height: 24),
              _SkeletonLine(widthFactor: 0.64, height: 10),
            ],
          ),
        ),
      ),
    );
  }
}

class _SkeletonCircle extends StatelessWidget {
  final double size;

  const _SkeletonCircle({required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.white.withValues(alpha: 0.05),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
    );
  }
}

class _SkeletonLine extends StatelessWidget {
  final double widthFactor;
  final double height;

  const _SkeletonLine({
    required this.widthFactor,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width * widthFactor;
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9999),
        color: Colors.white.withValues(alpha: 0.06),
      ),
    );
  }
}

class _AmbientBackdrop extends StatelessWidget {
  final AnimationController controller;

  const _AmbientBackdrop({required this.controller});

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: controller,
      builder: (context, _) {
        final value = controller.value;
        return Stack(
          children: [
            Positioned(
              top: -120,
              left: -100,
              child: Container(
                width: 280,
                height: 280,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _LensColors.primary.withValues(alpha: 0.10 + value * 0.04),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              top: 120,
              right: -80,
              child: Container(
                width: 220,
                height: 220,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _LensColors.secondary.withValues(alpha: 0.08 + value * 0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Positioned(
              bottom: -140,
              right: -120,
              child: Container(
                width: 320,
                height: 320,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      _LensColors.tertiary.withValues(alpha: 0.06 + value * 0.03),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
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
        );
      },
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final VoidCallback? onTap;
  final Color? borderColor;
  final Color? leftBorderColor;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.borderColor,
    this.leftBorderColor,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return RepaintBoundary(
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 18, sigmaY: 18),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onTap,
              borderRadius: radius,
              child: Container(
                decoration: BoxDecoration(
                  color: _LensColors.surfaceContainer.withValues(alpha: 0.60),
                  borderRadius: radius,
                  border: Border(
                    top: BorderSide(
                      color:
                          borderColor ?? Colors.white.withValues(alpha: 0.12),
                    ),
                    right: BorderSide(
                      color:
                          borderColor ?? Colors.white.withValues(alpha: 0.12),
                    ),
                    bottom: BorderSide(
                      color:
                          borderColor ?? Colors.white.withValues(alpha: 0.12),
                    ),
                    left: BorderSide(
                      color: leftBorderColor ??
                          borderColor ??
                          Colors.white.withValues(alpha: 0.12),
                      width: leftBorderColor == null ? 1 : 4,
                    ),
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: _LensColors.primary.withValues(alpha: 0.04),
                      blurRadius: 18,
                    ),
                  ],
                ),
                child: Padding(
                  padding: padding,
                  child: child,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _PillLabel extends StatelessWidget {
  final String label;
  final Color accent;

  const _PillLabel({
    required this.label,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: accent,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _PrimaryPillButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onPressed;

  const _PrimaryPillButton({
    required this.label,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9999),
        gradient: const LinearGradient(
          colors: [_LensColors.primary, Color(0xFFD9DCE8)],
        ),
        boxShadow: [
          BoxShadow(
            color: _LensColors.primary.withValues(alpha: 0.28),
            blurRadius: 20,
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(9999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: _LensColors.onPrimary),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    color: _LensColors.onPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SecondaryPillButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SecondaryPillButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(9999),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w700,
                color: _LensColors.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _TinyPanel extends StatelessWidget {
  final String title;
  final String value;
  final Color? valueColor;

  const _TinyPanel({
    required this.title,
    required this.value,
    this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: _LensColors.surfaceContainer.withValues(alpha: 0.90),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title.toUpperCase(),
            style: GoogleFonts.inter(
              fontSize: 10,
              fontWeight: FontWeight.w600,
              color: _LensColors.onSurfaceVariant,
              letterSpacing: 0.7,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: valueColor ?? _LensColors.primary,
              height: 1.0,
            ),
          ),
        ],
      ),
    );
  }
}

class _SeverityTag extends StatelessWidget {
  final String label;
  final Color color;

  const _SeverityTag({
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(4),
      ),
      child: Text(
        label.toUpperCase(),
        style: GoogleFonts.spaceGrotesk(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: color,
          letterSpacing: 0.6,
        ),
      ),
    );
  }
}

class _CompactChip extends StatelessWidget {
  final String text;
  final Color accent;

  const _CompactChip({
    required this.text,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: accent.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: accent.withValues(alpha: 0.18)),
      ),
      child: Text(
        text,
        style: GoogleFonts.inter(
          fontSize: 10,
          fontWeight: FontWeight.w600,
          color: accent,
        ),
      ),
    );
  }
}

class _NoisePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.white;
    final random = Random(7);
    for (var i = 0; i < 120; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      canvas.drawRect(
        Rect.fromLTWH(x, y, 1, 1),
        paint..color = Colors.white.withValues(alpha: random.nextDouble() * 0.08),
      );
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _ScoreRingPainter extends CustomPainter {
  final double progress;
  final double glow;

  const _ScoreRingPainter({
    required this.progress,
    required this.glow,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = min(size.width, size.height) / 2 - 8;
    final rect = Rect.fromCircle(center: center, radius: radius);

    final trackPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..color = Colors.white.withValues(alpha: 0.08);
    canvas.drawArc(rect, 0, 2 * pi, false, trackPaint);

    final arcPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(
        colors: [
          _LensColors.primary,
          Color(0xFFF0F1F6),
        ],
      ).createShader(rect)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, 6 * glow);

    canvas.drawArc(
      rect,
      -pi / 2,
      max(0.001, 2 * pi * progress),
      false,
      arcPaint,
    );
  }

  @override
  bool shouldRepaint(covariant _ScoreRingPainter oldDelegate) {
    return oldDelegate.progress != progress || oldDelegate.glow != glow;
  }
}

class _HoloSpherePainter extends CustomPainter {
  final double progress;

  const _HoloSpherePainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final rect = Rect.fromCircle(center: center, radius: size.width / 2);
    final glowPaint = Paint()
      ..shader = RadialGradient(
        colors: [
          _LensColors.primary.withValues(alpha: 0.55),
          _LensColors.secondary.withValues(alpha: 0.18),
          Colors.transparent,
        ],
        stops: const [0.0, 0.45, 1.0],
      ).createShader(rect);
    canvas.drawCircle(center, size.width / 2, glowPaint);

    final orbitPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = _LensColors.primary.withValues(alpha: 0.32);
    canvas.drawCircle(center, size.width * 0.28, orbitPaint);
    canvas.drawCircle(center.translate(-4, 2), size.width * 0.18, orbitPaint);

    final pulsePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = _LensColors.primary.withValues(alpha: 0.65);
    final sweep = 1.5 * pi * (0.4 + progress * 0.2);
    canvas.drawArc(
      Rect.fromCircle(center: center, radius: size.width * 0.35),
      -pi / 2,
      sweep,
      false,
      pulsePaint,
    );
  }

  @override
  bool shouldRepaint(covariant _HoloSpherePainter oldDelegate) {
    return oldDelegate.progress != progress;
  }
}

class _EmiChartPainter extends CustomPainter {
  final List<EmiPoint> series;

  const _EmiChartPainter({required this.series});

  @override
  void paint(Canvas canvas, Size size) {
    if (series.isEmpty) return;

    final padding = 16.0;
    final plotWidth = size.width - padding * 2;
    final plotHeight = size.height - padding * 2;
    final baseY = size.height - padding;
    final stepX = plotWidth / max(1, series.length - 1);
    final maxValue = series
        .map((e) => max(e.principal, e.interest))
        .reduce(max)
        .toDouble();

    final gridPaint = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;
    for (var i = 0; i < 4; i++) {
      final y = padding + (plotHeight / 3) * i;
      canvas.drawLine(
        Offset(padding, y),
        Offset(size.width - padding, y),
        gridPaint,
      );
    }

    Offset pointFor(int index, double value) {
      final x = padding + stepX * index;
      final y = baseY - (value / maxValue) * plotHeight;
      return Offset(x, y);
    }

    final interestPath = Path();
    final principalPath = Path();
    final interestPoints = <Offset>[];
    final principalPoints = <Offset>[];

    for (var i = 0; i < series.length; i++) {
      final interestPoint = pointFor(i, series[i].interest);
      final principalPoint = pointFor(i, series[i].principal);
      interestPoints.add(interestPoint);
      principalPoints.add(principalPoint);

      if (i == 0) {
        interestPath.moveTo(interestPoint.dx, interestPoint.dy);
        principalPath.moveTo(principalPoint.dx, principalPoint.dy);
      } else {
        interestPath.lineTo(interestPoint.dx, interestPoint.dy);
        principalPath.lineTo(principalPoint.dx, principalPoint.dy);
      }
    }

    final areaPath = Path.from(interestPath)
      ..lineTo(size.width - padding, baseY)
      ..lineTo(padding, baseY)
      ..close();

    final areaPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          _LensColors.primary.withValues(alpha: 0.18),
          Colors.transparent,
        ],
      ).createShader(Offset.zero & size);
    canvas.drawPath(areaPath, areaPaint);

    final interestPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = _LensColors.primary;
    canvas.drawPath(interestPath, interestPaint);

    final principalPaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2.2
      ..strokeCap = StrokeCap.round
      ..color = _LensColors.tertiary;
    canvas.drawPath(principalPath, principalPaint);

    for (final point in interestPoints) {
      canvas.drawCircle(point, 3.5, Paint()..color = _LensColors.primary);
      canvas.drawCircle(point, 1.5, Paint()..color = Colors.white);
    }
    for (final point in principalPoints) {
      canvas.drawCircle(point, 3.5, Paint()..color = _LensColors.tertiary);
    }

    final textPainter = TextPainter(
      textDirection: TextDirection.ltr,
      textAlign: TextAlign.center,
    );

    for (var i = 0; i < series.length; i += 3) {
      final x = padding + stepX * i;
      textPainter.text = TextSpan(
        text: 'M${series[i].month}',
        style: GoogleFonts.inter(
          fontSize: 9,
          fontWeight: FontWeight.w600,
          color: _LensColors.onSurfaceVariant,
        ),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(x - textPainter.width / 2, size.height - 10));
    }
  }

  @override
  bool shouldRepaint(covariant _EmiChartPainter oldDelegate) {
    return oldDelegate.series != series;
  }
}

class _MiniTrendChart extends StatelessWidget {
  final Color accent;

  const _MiniTrendChart({required this.accent});

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      child: CustomPaint(
        painter: _MiniTrendPainter(accent: accent),
      ),
    );
  }
}

class _MiniTrendPainter extends CustomPainter {
  final Color accent;

  const _MiniTrendPainter({required this.accent});

  @override
  void paint(Canvas canvas, Size size) {
    final grid = Paint()
      ..color = Colors.white.withValues(alpha: 0.05)
      ..strokeWidth = 1;

    for (var i = 0; i < 3; i++) {
      final y = size.height * (0.25 + i * 0.25);
      canvas.drawLine(Offset(0, y), Offset(size.width, y), grid);
    }

    final points = [
      Offset(0, size.height * 0.82),
      Offset(size.width * 0.18, size.height * 0.72),
      Offset(size.width * 0.36, size.height * 0.61),
      Offset(size.width * 0.55, size.height * 0.47),
      Offset(size.width * 0.74, size.height * 0.36),
      Offset(size.width, size.height * 0.22),
    ];

    final path = Path()..moveTo(points.first.dx, points.first.dy);
    for (final point in points.skip(1)) {
      path.lineTo(point.dx, point.dy);
    }

    final area = Path.from(path)
      ..lineTo(size.width, size.height)
      ..lineTo(0, size.height)
      ..close();

    canvas.drawPath(
      area,
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0.25),
            Colors.transparent,
          ],
        ).createShader(Offset.zero & size),
    );

    canvas.drawPath(
      path,
      Paint()
        ..color = accent
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.2
        ..strokeCap = StrokeCap.round,
    );

    for (final point in points) {
      canvas.drawCircle(point, 3.4, Paint()..color = accent);
    }
  }

  @override
  bool shouldRepaint(covariant _MiniTrendPainter oldDelegate) {
    return oldDelegate.accent != accent;
  }
}

class _BottomSheetFrame extends StatelessWidget {
  final String title;
  final Widget child;

  const _BottomSheetFrame({
    required this.title,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        decoration: BoxDecoration(
          color: _LensColors.surfaceContainer,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          border: Border(
            top: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Container(
                  width: 42,
                  height: 4,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.2),
                    borderRadius: BorderRadius.circular(9999),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 22,
                  fontWeight: FontWeight.w500,
                  color: _LensColors.onSurface,
                ),
              ),
              const SizedBox(height: 14),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: _LensColors.primary),
      title: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: _LensColors.onSurface,
        ),
      ),
      trailing: const Icon(
        Icons.chevron_right_rounded,
        color: _LensColors.onSurfaceVariant,
      ),
    );
  }
}

class _ChartActionSheet extends StatelessWidget {
  final LoanAnalysisReport report;

  const _ChartActionSheet({required this.report});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SheetAction(
          icon: Icons.copy_rounded,
          label: 'Copy summary',
          onTap: () {
            Clipboard.setData(ClipboardData(text: report.detailedSummary));
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Summary copied to clipboard')),
            );
          },
        ),
        _SheetAction(
          icon: Icons.share_outlined,
          label: 'Share snapshot',
          onTap: () {
            Clipboard.setData(
              ClipboardData(
                text:
                    '${report.lenderName} | Score ${report.healthScore.toStringAsFixed(1)} | ${report.recommendedAction}',
              ),
            );
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Share payload copied')),
            );
          },
        ),
        _SheetAction(
          icon: Icons.data_object_outlined,
          label: 'Copy raw JSON payload',
          onTap: () {
            Clipboard.setData(ClipboardData(text: report.loanId));
            Navigator.pop(context);
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Payload copied')),
            );
          },
        ),
      ],
    );
  }
}

Future<void> _openMetricSheet(
  BuildContext context,
  LoanAnalysisReport report,
  MetricData metric,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return _BottomSheetFrame(
        title: metric.label,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              metric.detailTitle,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: _LensColors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              metric.detailBody,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.55,
                color: _LensColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            _CompactChip(text: report.sources.first.page, accent: metric.accent),
            const SizedBox(height: 14),
            SizedBox(
              height: 180,
              child: _MiniTrendChart(accent: metric.accent),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _openAlertSheet(
  BuildContext context,
  LoanAnalysisReport report,
  RiskAlertData alert,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return _BottomSheetFrame(
        title: 'Clause insight',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _SeverityTag(label: alert.severity, color: alert.accent),
            const SizedBox(height: 14),
            Text(
              alert.title,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: _LensColors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              alert.explanation,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.55,
                color: _LensColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 18),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _CompactChip(text: alert.page, accent: alert.accent),
                _CompactChip(text: alert.clause, accent: _LensColors.primary),
                _CompactChip(text: report.loanId, accent: _LensColors.tertiary),
              ],
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _openReportSheet(
  BuildContext context,
  LoanAnalysisReport report,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return _BottomSheetFrame(
        title: 'Loan intelligence',
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              report.productName,
              style: GoogleFonts.spaceGrotesk(
                fontSize: 22,
                fontWeight: FontWeight.w500,
                color: _LensColors.onSurface,
              ),
            ),
            const SizedBox(height: 10),
            Text(
              report.detailedSummary,
              style: GoogleFonts.inter(
                fontSize: 14,
                height: 1.55,
                color: _LensColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: report.clauseChips
                  .map(
                    (chip) => _CompactChip(
                      text: chip.label,
                      accent: chip.accent,
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: report.sources
                  .map(
                    (source) => _CompactChip(
                      text: '${source.page} • ${source.title}',
                      accent: _LensColors.primary,
                    ),
                  )
                  .toList(),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _openSourcesSheet(
  BuildContext context,
  LoanAnalysisReport report,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return _BottomSheetFrame(
        title: 'Source references',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Extracted clauses and supporting pages',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _LensColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            ...report.sources.map(
              (source) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _CompactChip(text: source.page, accent: _LensColors.primary),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              source.title,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: _LensColors.onSurface,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              source.note,
                              style: GoogleFonts.inter(
                                fontSize: 13,
                                height: 1.45,
                                color: _LensColors.onSurfaceVariant,
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
          ],
        ),
      );
    },
  );
}

Future<void> _openExportSheet(
  BuildContext context,
  LoanAnalysisReport report,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return _BottomSheetFrame(
        title: 'Export and share',
        child: _ChartActionSheet(report: report),
      );
    },
  );
}

Future<void> _openHiddenChargesSheet(
  BuildContext context,
  LoanAnalysisReport report,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return _BottomSheetFrame(
        title: 'Hidden charges',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'The parser found subtle cost items that are not part of the headline rate.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _LensColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 14),
            ...report.extractions.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _GlassCard(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        item.label,
                        style: GoogleFonts.inter(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: _LensColors.onSurface,
                        ),
                      ),
                      Text(
                        item.value,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          color: _LensColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}

Future<void> _openCompareSheet(
  BuildContext context,
  LoanAnalysisReport report,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) {
      return _BottomSheetFrame(
        title: 'Compare loan',
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Use the existing analysis as a baseline and swap the lender terms to compare exposure.',
              style: GoogleFonts.inter(
                fontSize: 14,
                color: _LensColors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 16),
            _GlassCard(
              padding: const EdgeInsets.all(14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    report.lenderName,
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: _LensColors.onSurface,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Score ${report.healthScore.toStringAsFixed(1)}  •  ${report.recommendedAction}',
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: _LensColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    },
  );
}
