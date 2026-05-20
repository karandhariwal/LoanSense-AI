import 'dart:async';
import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:loansense_ai/data/models/loan_analysis_report.dart';
import 'package:loansense_ai/ui/screens/home_dashboard_screen.dart';
import 'package:loansense_ai/ui/screens/chat_screen.dart';

// ─── Design Tokens & Color Palettes (Aligned with code.html & analysis_report_screen.dart) ───
class _ConsoleColors {
  static const background = Color(0xFF131314);
  static const surfaceContainer = Color(0xFF201F20);
  static const surfaceContainerLow = Color(0xFF1C1B1C);
  static const primary = Color(0xFFC3C6D7); // Cyan-grey glow
  static const tertiary = Color(0xFFDBC3A8); // Amber
  static const error = Color(0xFFFFB4AB); // Red
  static const onSurface = Color(0xFFE5E2E3);
  static const onSurfaceVariant = Color(0xFFC7C6CC);
  static const accentCyan = Color(0xFF00E5FF);
  static const glowCyan = Color(0xFFC3C6D7);

  // Dynamic severity-based selectors
  static Color severityColor(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'high':
        return error;
      case 'medium':
      case 'warning':
        return tertiary;
      case 'verified':
      case 'safe':
      case 'low':
      default:
        return primary;
    }
  }

  static Color severityBg(String severity) {
    switch (severity.toLowerCase()) {
      case 'critical':
      case 'high':
        return const Color(0xFF93000A).withValues(alpha: 0.2);
      case 'medium':
      case 'warning':
        return const Color(0xFF170C01).withValues(alpha: 0.4);
      case 'verified':
      case 'safe':
      case 'low':
      default:
        return const Color(0xFF0A0E1A).withValues(alpha: 0.4);
    }
  }
}

// ─── Model for Clause Intelligence Items ───
class ClauseIntelligenceItem {
  final String id;
  final String section;
  final String title;
  final String originalText;
  final String severity; // 'Critical', 'Medium', 'Verified'
  final String aiExplanation;
  final String realWorldImpact;
  final String simpleExplanation;
  final String page;
  final String category;
  final Color accent;

  const ClauseIntelligenceItem({
    required this.id,
    required this.section,
    required this.title,
    required this.originalText,
    required this.severity,
    required this.aiExplanation,
    required this.realWorldImpact,
    required this.simpleExplanation,
    required this.page,
    required this.category,
    required this.accent,
  });

  factory ClauseIntelligenceItem.fromAlert(
    RiskAlertData alert,
    String category, {
    String? realWorldImpact,
    String? simpleExplanation,
  }) {
    return ClauseIntelligenceItem(
      id: alert.id,
      section: alert.clause.contains('Clause')
          ? alert.clause.replaceFirst('Clause ', 'Section ')
          : alert.clause,
      title: alert.title,
      originalText: alert.body,
      severity: alert.severity,
      aiExplanation: alert.explanation,
      realWorldImpact: realWorldImpact ??
          "Potential monthly impact or financial reset depending on inflation cycles.",
      simpleExplanation: simpleExplanation ??
          "This clause gives the bank more power over your loan terms. Make sure you understand the reset trigger conditions.",
      page: alert.page,
      category: category,
      accent: alert.accent,
    );
  }
}

// ─── Controller / State Management (Clean Business Logic) ───
class ClauseIntelligenceController extends ChangeNotifier {
  final LoanAnalysisReport report;

  // Entire Dataset
  List<ClauseIntelligenceItem> allClauses = [];

  // Filtered & Searched Dataset
  List<ClauseIntelligenceItem> filteredClauses = [];

  // Interactive UI State
  String searchQuery = '';
  String selectedSeverityFilter =
      'All'; // 'All', 'Critical', 'Medium', 'Verified'
  String? selectedClauseId;

  // Secondary dynamic states
  final Set<String> bookmarkedIds = {};
  final Set<String> simpleExplanationIds = {};
  bool isScanning = true;
  double scanProgress = 0.0;

  // Simple explanation dynamic typing state
  bool isTypingExplanation = false;
  String typedExplanation = '';
  Timer? _typingTimer;

  ClauseIntelligenceController({required this.report}) {
    _initializeDataset();
  }

  void _initializeDataset() {
    // We populate the detailed Clause console from the loan report alerts.
    // If the report doesn't have alerts, we generate deterministic high-fidelity clauses.
    if (report.alerts.isNotEmpty) {
      allClauses = report.alerts.map((alert) {
        String cat = "Financial";
        String rwi =
            "Historical adjustments suggest monthly outflow volatility.";
        String simple =
            "This is legal jargon. In plain English, the lender controls the terms under standard index rules.";

        // Deterministic high-quality contents for report alerts
        if (alert.title.toLowerCase().contains('pre-payment') ||
            alert.title.toLowerCase().contains('foreclosure')) {
          cat = "Exit Charges";
          rwi =
              "Closing this loan early to switch to a cheaper lender will cost a flat penalty on principal.";
          simple =
              "If you try to pay off this loan early or switch to another bank, they will charge you a fee. It makes early payment expensive.";
        } else if (alert.title.toLowerCase().contains('interest') ||
            alert.title.toLowerCase().contains('rate')) {
          cat = "Interest Terms";
          rwi =
              "Based on market index fluctuations, your EMI could spike without warning.";
          simple =
              "The bank can change your interest rate based on their internal rules, making your monthly bills go up suddenly.";
        } else if (alert.title.toLowerCase().contains('fees') ||
            alert.title.toLowerCase().contains('hidden')) {
          cat = "Administrative";
          rwi =
              "Processing charges and service taxes compound quiet liabilities.";
          simple =
              "There are extra administrative fees quietly added to your account quarterly. Make sure they are waived.";
        } else if (alert.title.toLowerCase().contains('insurance')) {
          cat = "Mandates";
          rwi =
              "Mandates an insurance premium which adds directly to principal capitalization.";
          simple =
              "You must maintain a life insurance policy listing the bank as the payout recipient to cover the debt if you pass away.";
        }

        return ClauseIntelligenceItem.fromAlert(
          alert,
          cat,
          realWorldImpact: rwi,
          simpleExplanation: simple,
        );
      }).toList();
    } else {
      // Fallback premium mock dataset aligned with HTML/PNG
      allClauses = [
        const ClauseIntelligenceItem(
          id: 'clause-rate',
          section: 'Section 4.2',
          title: 'Rate Fluctuation',
          originalText:
              '4.2. Interest Adjustment: The Lender reserves the absolute right to unilaterally adjust the Base Rate and Margin at any interval based on internal liquidity assessments. Borrowers shall be notified post-facto through electronic channels.',
          severity: 'Critical',
          aiExplanation:
              'This clause allows the lender to increase your EMI later without your prior consent. It creates an unpredictable repayment schedule.',
          realWorldImpact:
              'Based on historic index shifts, your monthly payment could increase by up to \$145/month with zero warning.',
          simpleExplanation:
              'The bank can raise your interest rate whenever they want, and they will only tell you after they\'ve done it. This means your monthly payment could go up suddenly.',
          page: 'Page 4',
          category: 'Interest Terms',
          accent: _ConsoleColors.error,
        ),
        const ClauseIntelligenceItem(
          id: 'clause-prepay',
          section: 'Section 9.1',
          title: 'Prepayment Penalty',
          originalText:
              '9.1. Prepayment Penalties: Any partial or full prepayment of the outstanding principal prior to the 24th installment will incur a flat fee of 3.5% of the total loan amount.',
          severity: 'Medium',
          aiExplanation:
              'A prepayment penalty locks you into this loan for 24 months. Refinancing or paying early is heavily penalized.',
          realWorldImpact:
              'Closing this loan early to switch to a cheaper lender will cost you an extra \$3,500 in penalty fees.',
          simpleExplanation:
              'If you try to pay off this loan early or switch to a cheaper bank in the first two years, you have to pay a big fee (3.5% of your loan). It traps you from saving money.',
          page: 'Page 11',
          category: 'Exit Charges',
          accent: _ConsoleColors.tertiary,
        ),
        const ClauseIntelligenceItem(
          id: 'clause-insurance',
          section: 'Section 12.5',
          title: 'Insurance Mandate',
          originalText:
              '12.5. Insurance Requirement: Borrowers must maintain Credit Life insurance for the duration of the term, with the Lender listed as the primary beneficiary.',
          severity: 'Verified',
          aiExplanation:
              'Standard protective clause. Credit Life insurance protects your family from debt liabilities in unforeseen circumstances.',
          realWorldImpact:
              'Ensures your outstanding debt is completely paid off by the insurer in case of death, protecting family wealth.',
          simpleExplanation:
              'You must keep life insurance so that if anything happens to you, the insurance company will pay off the loan instead of leaving the debt to your family.',
          page: 'Page 14',
          category: 'Mandates',
          accent: _ConsoleColors.primary,
        ),
        const ClauseIntelligenceItem(
          id: 'clause-jurisdiction',
          section: 'Section 7.8',
          title: 'Out-Of-State Court Venue',
          originalText:
              '7.8. Jurisdiction: Any disputes arising out of this agreement shall be subject to the exclusive jurisdiction of courts located in the Lender\'s home state, regardless of the borrower\'s location.',
          severity: 'Medium',
          aiExplanation:
              'Requires legal actions to take place far from home. Increases the cost and complexity of defending your rights.',
          realWorldImpact:
              'If you need to sue the lender, you must travel to their headquarters state, costing upwards of \$5,000 in travel and out-of-state legal counsel.',
          simpleExplanation:
              'If you have a disagreement, you have to go to court in the bank\'s home city, even if it\'s thousands of miles away. It makes it hard and expensive to fight back.',
          page: 'Page 8',
          category: 'Legal Terms',
          accent: _ConsoleColors.tertiary,
        ),
        const ClauseIntelligenceItem(
          id: 'clause-waiver',
          section: 'Section 14.1',
          title: 'Processing Fee Waiver',
          originalText:
              '14.1. Promotional Waiver: Processing fees are waived in full for borrowers demonstrating a Tier 1 credit bureau score (exceeding 800) at sanction.',
          severity: 'Verified',
          aiExplanation:
              'Favorable tier benefit. Saves money upfront on loan initiation charges.',
          realWorldImpact:
              'Saves an immediate upfront expense of \$450 in administrative and documentation fees.',
          simpleExplanation:
              'Since you have excellent credit, the bank is giving you a special deal: you don\'t have to pay any signup or processing fees. You save \$450 immediately.',
          page: 'Page 2',
          category: 'Administrative',
          accent: _ConsoleColors.primary,
        ),
      ];
    }

    if (allClauses.isNotEmpty) {
      selectedClauseId = allClauses.first.id;
    }

    // Simulate initial premium neural scanning
    _simulateScanning();
  }

  void _simulateScanning() {
    isScanning = true;
    scanProgress = 0.0;
    notifyListeners();

    Timer.periodic(const Duration(milliseconds: 40), (timer) {
      scanProgress += 0.025;
      if (scanProgress >= 1.0) {
        scanProgress = 1.0;
        isScanning = false;
        timer.cancel();
        _applyFilters();
      }
      notifyListeners();
    });
  }

  void _applyFilters() {
    filteredClauses = allClauses.where((clause) {
      final matchesSearch = clause.title
              .toLowerCase()
              .contains(searchQuery.toLowerCase()) ||
          clause.section.toLowerCase().contains(searchQuery.toLowerCase()) ||
          clause.originalText
              .toLowerCase()
              .contains(searchQuery.toLowerCase()) ||
          clause.category.toLowerCase().contains(searchQuery.toLowerCase());

      final matchesSeverity = selectedSeverityFilter == 'All' ||
          clause.severity.toLowerCase() == selectedSeverityFilter.toLowerCase();

      return matchesSearch && matchesSeverity;
    }).toList();

    // Reset selection to the first available item if previous selection is filtered out
    if (filteredClauses.isNotEmpty) {
      if (selectedClauseId == null ||
          !filteredClauses.any((c) => c.id == selectedClauseId)) {
        selectedClauseId = filteredClauses.first.id;
      }
    } else {
      selectedClauseId = null;
    }
    notifyListeners();
  }

  void selectClause(String id) {
    if (selectedClauseId == id) return;
    selectedClauseId = id;

    // Clear typing states
    _typingTimer?.cancel();
    isTypingExplanation = false;
    typedExplanation = '';

    notifyListeners();
  }

  void updateSearch(String query) {
    searchQuery = query;
    _applyFilters();
  }

  void updateSeverityFilter(String severity) {
    selectedSeverityFilter = severity;
    _applyFilters();
  }

  void toggleBookmark(String id) {
    if (bookmarkedIds.contains(id)) {
      bookmarkedIds.remove(id);
    } else {
      bookmarkedIds.add(id);
    }
    notifyListeners();
  }

  void toggleSimpleExplanation(String id) {
    if (simpleExplanationIds.contains(id)) {
      simpleExplanationIds.remove(id);
      isTypingExplanation = false;
      typedExplanation = '';
      _typingTimer?.cancel();
      notifyListeners();
    } else {
      simpleExplanationIds.add(id);
      _triggerTypingExplanation(id);
    }
  }

  void _triggerTypingExplanation(String id) {
    _typingTimer?.cancel();
    isTypingExplanation = true;
    typedExplanation = '';
    notifyListeners();

    final item = allClauses.firstWhere((c) => c.id == id);
    final text = item.simpleExplanation;
    int index = 0;

    _typingTimer = Timer.periodic(const Duration(milliseconds: 15), (timer) {
      if (index < text.length) {
        // Increment by a few characters to make it look smooth and intelligent
        final step = min(3, text.length - index);
        typedExplanation += text.substring(index, index + step);
        index += step;
        notifyListeners();
      } else {
        isTypingExplanation = false;
        timer.cancel();
        notifyListeners();
      }
    });
  }

  @override
  void dispose() {
    _typingTimer?.cancel();
    super.dispose();
  }
}

// ─── Main Clause Intelligence Console Screen ───
class ClauseIntelligenceScreen extends StatefulWidget {
  final LoanAnalysisReport report;
  final String?
      targetClauseId; // Can jump to a specific clause (e.g. from report)

  const ClauseIntelligenceScreen({
    super.key,
    required this.report,
    this.targetClauseId,
  });

  @override
  State<ClauseIntelligenceScreen> createState() =>
      _ClauseIntelligenceScreenState();
}

class _ClauseIntelligenceScreenState extends State<ClauseIntelligenceScreen>
    with TickerProviderStateMixin {
  late final ClauseIntelligenceController _controller;
  late final AnimationController _scanlineController;
  late final AnimationController _ambientGlowController;
  late final ScrollController _docScrollController;
  final TextEditingController _searchFieldController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _controller = ClauseIntelligenceController(report: widget.report);

    if (widget.targetClauseId != null) {
      _controller.selectClause(widget.targetClauseId!);
    }

    _scanlineController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 4),
    )..repeat();

    _ambientGlowController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 6),
    )..repeat(reverse: true);

    _docScrollController = ScrollController();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scanlineController.dispose();
    _ambientGlowController.dispose();
    _docScrollController.dispose();
    _searchFieldController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_controller, _ambientGlowController]),
      builder: (context, _) {
        final activeClause = _controller.selectedClauseId != null
            ? _controller.allClauses
                .firstWhere((c) => c.id == _controller.selectedClauseId)
            : null;
        final glowColor = activeClause != null
            ? _ConsoleColors.severityColor(activeClause.severity)
            : _ConsoleColors.primary;

        return Scaffold(
          backgroundColor: _ConsoleColors.background,
          body: Stack(
            children: [
              // 1. Cinematic Ambient Glow Blobs
              _buildCinematicGradients(glowColor),

              // 2. Main Page Content (Header + Body + Floating elements)
              SafeArea(
                child: Column(
                  children: [
                    // Top Custom Header
                    _buildTopAppBar(context),

                    // Main Grid/Content Area
                    Expanded(
                      child: _controller.isScanning
                          ? _buildNeuralScanningScreen()
                          : LayoutBuilder(
                              builder: (context, constraints) {
                                final isWide = constraints.maxWidth > 800;
                                return isWide
                                    ? _buildSplitDesktopLayout(activeClause)
                                    : _buildVerticalMobileLayout(activeClause);
                              },
                            ),
                    ),

                    // Bottom Spacer to avoid navbar overlap
                    const SizedBox(height: 104),
                  ],
                ),
              ),

              // 3. Floating Bottom Nav Bar (Matches Home Dashboard perfectly)
              Positioned(
                bottom: 32,
                left: 0,
                right: 0,
                child: _buildBottomNavBar(context),
              ),

              // 4. Subtle holographic film grain/noise overlay
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
      },
    );
  }

  // ─── Background Ambient Light ───
  Widget _buildCinematicGradients(Color activeColor) {
    return RepaintBoundary(
      child: Stack(
        children: [
          // Slow breathing cyan/violet radial gradient
          Positioned(
            top: -120 + 20 * sin(_ambientGlowController.value * 2 * pi),
            right: -80 + 30 * cos(_ambientGlowController.value * 2 * pi),
            child: Container(
              width: 500,
              height: 500,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    _ConsoleColors.glowCyan.withValues(
                      alpha: 0.05 + _ambientGlowController.value * 0.03,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // Bottom glowing blob responding to ACTIVE Risk Severity Color!
          Positioned(
            bottom: -150 + 25 * cos(_ambientGlowController.value * 2 * pi),
            left: -100 + 15 * sin(_ambientGlowController.value * 2 * pi),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 800),
              width: 450,
              height: 450,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    activeColor.withValues(
                      alpha: 0.04 + _ambientGlowController.value * 0.03,
                    ),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Custom Floating Top App Bar ───
  Widget _buildTopAppBar(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
      decoration: BoxDecoration(
        color: _ConsoleColors.background.withValues(alpha: 0.8),
        border: Border(
          bottom: BorderSide(
            color: Colors.white.withValues(alpha: 0.08),
            width: 0.8,
          ),
        ),
      ),
      child: Row(
        children: [
          // Prof Image + Label
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(
                color: _ConsoleColors.primary.withValues(alpha: 0.3),
                width: 1,
              ),
              image: const DecorationImage(
                image: NetworkImage(
                  'https://lh3.googleusercontent.com/aida-public/AB6AXuBfnJsdiMldJmTK6pAguTq4FLLkDG_BxEwYAtRUqr0SMcNKJB4uKOrtWF0OtzLa8oLn35zTpos7Ls5mMDPxQOTrN4VQpzW-3X8vknnjqmv5yqh8VoE6m0QyjrMfE9Vl-7491Emb0XArbN0_3gh6IhIUz8XBzUpx6RxwLcIgBZ7C137vianH5vgXi5CqSskZrNlIiCTDsjWPu_g6KEpmVbo3UAGsFlFC-IeFVFpyiypcX8TjySC2_PMWq6AF-cAWWS8gEUSDQQkAUQ',
                ),
                fit: BoxFit.cover,
              ),
            ),
          ),
          const SizedBox(width: 16),

          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'LoanSense AI',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: _ConsoleColors.primary,
                    letterSpacing: -0.4,
                  ),
                ),
                Text(
                  'Clause Intelligence Console',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: _ConsoleColors.onSurfaceVariant,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),

          // Live status sensors
          Row(
            children: [
              Container(
                width: 6,
                height: 6,
                decoration: const BoxDecoration(
                  color: _ConsoleColors.accentCyan,
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: _ConsoleColors.accentCyan,
                      blurRadius: 8,
                    ),
                  ],
                ),
              ),
              if (MediaQuery.of(context).size.width > 480) ...[
                const SizedBox(width: 8),
                Text(
                  'NEURAL ACTIVE',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    color: _ConsoleColors.onSurfaceVariant,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
              const SizedBox(width: 16),
              IconButton(
                onPressed: () {
                  _controller._simulateScanning();
                },
                icon: const Icon(
                  Icons.sensors_rounded,
                  color: _ConsoleColors.primary,
                  size: 20,
                ),
                tooltip: 'Re-Analyze',
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ─── Neural Scanning View (Simulating dynamic scanning flow) ───
  Widget _buildNeuralScanningScreen() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Stack(
              alignment: Alignment.center,
              children: [
                // Pulsing Scan Ring
                Container(
                  width: 110,
                  height: 110,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: _ConsoleColors.primary.withValues(alpha: 0.3),
                      width: 1.5,
                    ),
                  ),
                  child: Center(
                    child: CircularProgressIndicator(
                      strokeWidth: 3,
                      value: _controller.scanProgress,
                      color: _ConsoleColors.primary,
                      backgroundColor: Colors.transparent,
                    ),
                  ),
                ),
                const Icon(
                  Icons.smart_toy_outlined,
                  color: _ConsoleColors.primary,
                  size: 40,
                ),
              ],
            ),
            const SizedBox(height: 32),
            Text(
              'PARSING RISKS & TRAPS',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: _ConsoleColors.onSurface,
                letterSpacing: 1.8,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'RAG-based vector search auditing pages against market caps...',
              style: GoogleFonts.inter(
                fontSize: 13,
                color: _ConsoleColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            ClipRRect(
              borderRadius: BorderRadius.circular(9999),
              child: Container(
                width: 240,
                height: 4,
                color: Colors.white.withValues(alpha: 0.05),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: FractionallySizedBox(
                    widthFactor: _controller.scanProgress,
                    child: Container(
                      decoration: const BoxDecoration(
                        gradient: LinearGradient(
                          colors: [
                            _ConsoleColors.primary,
                            _ConsoleColors.accentCyan
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ─── Responsive Layout 1: Split Screen for Wide Viewports (Tablet/Desktop) ───
  Widget _buildSplitDesktopLayout(ClauseIntelligenceItem? activeClause) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left Column (7/12 width): Search, Filters, and Interactive PDF Mockup Feed
          Expanded(
            flex: 7,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildSearchAndFilters(),
                const SizedBox(height: 16),
                Expanded(
                  child: _buildDocumentSection(activeClause),
                ),
              ],
            ),
          ),

          const SizedBox(width: 24),

          // Right Column (5/12 width): AI Analysis Focus Card & Secondary Actions
          Expanded(
            flex: 5,
            child: activeClause == null
                ? _buildEmptyFilteredState()
                : SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _buildAIInsightsHeader(),
                        const SizedBox(height: 16),
                        _buildFocusedClausePanel(activeClause),
                        const SizedBox(height: 16),
                        _buildSecondaryActions(),
                      ],
                    ),
                  ),
          ),
        ],
      ),
    );
  }

  // ─── Responsive Layout 2: Single Scroll for Mobile ───
  Widget _buildVerticalMobileLayout(ClauseIntelligenceItem? activeClause) {
    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSearchAndFilters(),
          const SizedBox(height: 16),

          // Interactive PDF Document Panel
          SizedBox(
            height: 480,
            child: _buildDocumentSection(activeClause),
          ),

          const SizedBox(height: 24),

          // AI Insights focused panel
          if (activeClause == null)
            _buildEmptyFilteredState()
          else ...[
            _buildAIInsightsHeader(),
            const SizedBox(height: 16),
            _buildFocusedClausePanel(activeClause),
            const SizedBox(height: 16),
            _buildSecondaryActions(),
          ],
        ],
      ),
    );
  }

  // ─── Helper: Search Bar and Severity Filters ───
  Widget _buildSearchAndFilters() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Premium Glass Search Bar
        _GlassCard(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 2),
          child: Row(
            children: [
              const Icon(
                Icons.search_rounded,
                color: _ConsoleColors.primary,
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _searchFieldController,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    color: _ConsoleColors.onSurface,
                  ),
                  decoration: InputDecoration(
                    hintText: 'Search risk terms or sections...',
                    hintStyle: GoogleFonts.inter(
                      fontSize: 14,
                      color: _ConsoleColors.onSurfaceVariant
                          .withValues(alpha: 0.6),
                    ),
                    border: InputBorder.none,
                    isDense: true,
                  ),
                  onChanged: (val) {
                    _controller.updateSearch(val);
                  },
                ),
              ),
              if (_searchFieldController.text.isNotEmpty)
                IconButton(
                  onPressed: () {
                    _searchFieldController.clear();
                    _controller.updateSearch('');
                  },
                  icon: const Icon(Icons.close,
                      size: 16, color: _ConsoleColors.onSurfaceVariant),
                ),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Horizontal Scroll Filter Chips
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          physics: const BouncingScrollPhysics(),
          child: Row(
            children: ['All', 'Critical', 'Medium', 'Verified'].map((filter) {
              final isSelected = _controller.selectedSeverityFilter == filter;
              Color chipColor = _ConsoleColors.primary;
              if (filter == 'Critical') chipColor = _ConsoleColors.error;
              if (filter == 'Medium') chipColor = _ConsoleColors.tertiary;

              return Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(
                    filter.toUpperCase(),
                    style: GoogleFonts.spaceGrotesk(
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? _ConsoleColors.background : chipColor,
                      letterSpacing: 0.8,
                    ),
                  ),
                  selected: isSelected,
                  selectedColor: chipColor,
                  backgroundColor:
                      _ConsoleColors.surfaceContainer.withValues(alpha: 0.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(9999),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : chipColor.withValues(alpha: 0.22),
                      width: 0.8,
                    ),
                  ),
                  checkmarkColor: _ConsoleColors.background,
                  showCheckmark: false,
                  onSelected: (selected) {
                    if (selected) {
                      _controller.updateSeverityFilter(filter);
                    }
                  },
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  // ─── Left Section: Document PDF Mockup Viewer ───
  Widget _buildDocumentSection(ClauseIntelligenceItem? activeClause) {
    return _GlassCard(
      padding: const EdgeInsets.all(20),
      hasScanline: true,
      ambientController: _scanlineController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // PDF Metadata Header
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Row(
                  children: [
                    const Icon(
                      Icons.description_outlined,
                      color: _ConsoleColors.primary,
                      size: 20,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Contract_v2.04_Final.pdf',
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: _ConsoleColors.onSurface,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),

              // Active Page Indicator Capsule
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: _ConsoleColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(9999),
                  border: Border.all(
                    color: _ConsoleColors.primary.withValues(alpha: 0.18),
                    width: 0.8,
                  ),
                ),
                child: Text(
                  activeClause != null
                      ? 'SCANNING ${activeClause.page.toUpperCase()}/12'
                      : 'SCANNING...',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 9,
                    fontWeight: FontWeight.w700,
                    color: _ConsoleColors.primary,
                    letterSpacing: 1.0,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),

          // PDF Body Feed
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                color:
                    _ConsoleColors.surfaceContainerLow.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
              ),
              child: _controller.filteredClauses.isEmpty
                  ? _buildEmptyFilteredState()
                  : ListView.builder(
                      controller: _docScrollController,
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.all(18),
                      itemCount: _controller.filteredClauses.length * 2 - 1,
                      itemBuilder: (context, index) {
                        if (index.isOdd) {
                          // Structural text block filler lines simulating PDF paragraphs
                          return Padding(
                            padding: const EdgeInsets.symmetric(vertical: 14),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  height: 10,
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Container(
                                  height: 10,
                                  width:
                                      MediaQuery.of(context).size.width * 0.45,
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.04),
                                    borderRadius: BorderRadius.circular(4),
                                  ),
                                ),
                              ],
                            ),
                          );
                        }

                        // Target Interactive Clause Card
                        final clauseIndex = index ~/ 2;
                        final item = _controller.filteredClauses[clauseIndex];
                        final isSelected =
                            _controller.selectedClauseId == item.id;

                        return _buildInteractiveClauseCard(item, isSelected);
                      },
                    ),
            ),
          ),
        ],
      ),
    );
  }

  // ─── Interactive Clause Card inside Document ───
  Widget _buildInteractiveClauseCard(
      ClauseIntelligenceItem item, bool isSelected) {
    return GestureDetector(
      onTap: () {
        _controller.selectClause(item.id);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        margin: const EdgeInsets.only(bottom: 4),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? item.accent.withValues(alpha: 0.12)
              : _ConsoleColors.severityBg(item.severity),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected
                ? item.accent.withValues(alpha: 0.5)
                : item.accent.withValues(alpha: 0.22),
            width: isSelected ? 1.5 : 0.8,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: item.accent.withValues(alpha: 0.15),
                    blurRadius: 16,
                    spreadRadius: -2,
                  ),
                ]
              : null,
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Glowing left tag bar matching severity
            Container(
              width: 3.5,
              height: 48,
              decoration: BoxDecoration(
                color: item.accent,
                borderRadius: BorderRadius.circular(9999),
                boxShadow: [
                  BoxShadow(
                    color: item.accent,
                    blurRadius: 6,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 14),

            // Text Block Content
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Text(
                          '${item.section}: ${item.title}',
                          overflow: TextOverflow.ellipsis,
                          maxLines: 1,
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            color: item.accent,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),

                      // Page Tag
                      Text(
                        item.page.toUpperCase(),
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 9,
                          fontWeight: FontWeight.w600,
                          color: _ConsoleColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),

                  // Original Text
                  RichText(
                    text: TextSpan(
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        height: 1.45,
                        color: _ConsoleColors.onSurface,
                      ),
                      children: [
                        TextSpan(
                          text: '${item.section}. ',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        TextSpan(
                          text: item.originalText
                              .replaceFirst(
                                  RegExp(r'^.*?\.\s*Interest Adjustment:\s*'),
                                  '')
                              .replaceFirst(
                                  RegExp(r'^.*?\.\s*Prepayment Penalties:\s*'),
                                  '')
                              .replaceFirst(
                                  RegExp(r'^.*?\.\s*Insurance Requirement:\s*'),
                                  '')
                              .replaceFirst(
                                  RegExp(r'^.*?\.\s*Jurisdiction:\s*'), '')
                              .replaceFirst(
                                  RegExp(r'^.*?\.\s*Promotional Waiver:\s*'),
                                  ''),
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
    );
  }

  // ─── Right Section: AI Insights Panel Header ───
  Widget _buildAIInsightsHeader() {
    return _GlassCard(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: _ConsoleColors.primary.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                color: _ConsoleColors.primary.withValues(alpha: 0.18),
                width: 0.8,
              ),
            ),
            child: const Icon(
              Icons.smart_toy_outlined,
              color: _ConsoleColors.primary,
              size: 18,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'AI Insights Engine v4.2',
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: _ConsoleColors.primary,
                  ),
                ),
                Text(
                  'Confidence index: 82% (Lender-Favored lean)',
                  style: GoogleFonts.inter(
                    fontSize: 11,
                    color: _ConsoleColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ─── Right Section: Focus Intelligence Console Card ───
  Widget _buildFocusedClausePanel(ClauseIntelligenceItem item) {
    final showSimpler = _controller.simpleExplanationIds.contains(item.id);
    final isBookmarked = _controller.bookmarkedIds.contains(item.id);

    return _GlassCard(
      padding: const EdgeInsets.all(24),
      borderColor: item.accent.withValues(alpha: 0.22),
      leftBorderColor: item.accent,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Severity Badge & Bookmarks
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _buildRiskBadge(item),

              // Icon Controls (Bookmark, Share)
              Row(
                children: [
                  IconButton(
                    onPressed: () {
                      _controller.toggleBookmark(item.id);
                      _showHolographicFeedback(
                        isBookmarked ? 'Bookmark Removed' : 'Clause Bookmarked',
                        isBookmarked ? Icons.bookmark_outline : Icons.bookmark,
                      );
                    },
                    icon: Icon(
                      isBookmarked ? Icons.bookmark : Icons.bookmark_outline,
                      color: isBookmarked
                          ? _ConsoleColors.accentCyan
                          : _ConsoleColors.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                  IconButton(
                    onPressed: () {
                      Clipboard.setData(ClipboardData(
                        text:
                            'Clause Audit [${item.section} - ${item.title}]:\nExplanation: ${item.aiExplanation}\nImpact: ${item.realWorldImpact}',
                      ));
                      _showHolographicFeedback(
                        'Audit details copied!',
                        Icons.copy_all,
                      );
                    },
                    icon: const Icon(
                      Icons.share_outlined,
                      color: _ConsoleColors.onSurfaceVariant,
                      size: 20,
                    ),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),

          // Section & Title
          Text(
            '${item.section}: ${item.title}',
            style: GoogleFonts.spaceGrotesk(
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _ConsoleColors.onSurface,
            ),
          ),
          const SizedBox(height: 18),

          // Intelligence Insights block
          Column(
            children: [
              // AI Legal Explanation
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.lightbulb_outline_rounded,
                      color: _ConsoleColors.tertiary,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI EXPLANATION',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _ConsoleColors.tertiary,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.aiExplanation,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.5,
                            color: _ConsoleColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Real-World Impact
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.only(top: 2),
                    child: Icon(
                      Icons.trending_up,
                      color: _ConsoleColors.error,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'REAL-WORLD FINANCIAL IMPACT',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w700,
                            color: _ConsoleColors.error,
                            letterSpacing: 1.0,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          item.realWorldImpact,
                          style: GoogleFonts.inter(
                            fontSize: 14,
                            height: 1.5,
                            color: _ConsoleColors.onSurface,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              // ─── ELI5 "Explain Simpler" Expandable Section ───
              AnimatedSize(
                duration: const Duration(milliseconds: 250),
                curve: Curves.easeOutCubic,
                child: showSimpler
                    ? Container(
                        margin: const EdgeInsets.only(top: 20),
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color:
                              _ConsoleColors.accentCyan.withValues(alpha: 0.05),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: _ConsoleColors.accentCyan
                                .withValues(alpha: 0.15),
                            width: 0.8,
                          ),
                        ),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Icon(
                              Icons.psychology_outlined,
                              color: _ConsoleColors.accentCyan,
                              size: 20,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        'SIMPLIFIED ANALYTICS (ELI5)',
                                        style: GoogleFonts.inter(
                                          fontSize: 10,
                                          fontWeight: FontWeight.w700,
                                          color: _ConsoleColors.accentCyan,
                                          letterSpacing: 1.0,
                                        ),
                                      ),
                                      if (_controller.isTypingExplanation)
                                        Container(
                                          width: 6,
                                          height: 6,
                                          decoration: const BoxDecoration(
                                            color: _ConsoleColors.accentCyan,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    _controller.isTypingExplanation
                                        ? _controller.typedExplanation
                                        : item.simpleExplanation,
                                    style: GoogleFonts.inter(
                                      fontSize: 13,
                                      height: 1.45,
                                      color: _ConsoleColors.onSurface,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      )
                    : const SizedBox.shrink(),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Explain Simpler AI Action Button
          DecoratedBox(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              gradient: LinearGradient(
                colors: [
                  _ConsoleColors.primary.withValues(alpha: 0.1),
                  _ConsoleColors.primary.withValues(alpha: 0.2),
                  _ConsoleColors.primary.withValues(alpha: 0.1),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: _ConsoleColors.primary.withValues(alpha: 0.05),
                  blurRadius: 15,
                ),
              ],
            ),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                onTap: () {
                  _controller.toggleSimpleExplanation(item.id);
                  if (!_controller.simpleExplanationIds.contains(item.id)) {
                    _showHolographicFeedback(
                        'Generating RAG analysis...', Icons.auto_awesome);
                  }
                },
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: _ConsoleColors.primary.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.auto_awesome,
                        color: _ConsoleColors.primary,
                        size: 16,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        showSimpler ? 'Show Technical' : 'Explain Simpler',
                        style: GoogleFonts.spaceGrotesk(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: _ConsoleColors.primary,
                        ),
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

  // ─── Focused Panel Risk Level Badge ───
  Widget _buildRiskBadge(ClauseIntelligenceItem item) {
    String badgeLabel = 'INFO';
    if (item.severity.toLowerCase() == 'critical' ||
        item.severity.toLowerCase() == 'high') {
      badgeLabel = 'CRITICAL RISK';
    } else if (item.severity.toLowerCase() == 'medium') {
      badgeLabel = 'EXPOSURE TRAP';
    } else if (item.severity.toLowerCase() == 'verified' ||
        item.severity.toLowerCase() == 'safe') {
      badgeLabel = 'VERIFIED SAFE';
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: item.accent.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: item.accent.withValues(alpha: 0.20),
          width: 0.8,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: item.accent,
              boxShadow: [
                BoxShadow(
                  color: item.accent,
                  blurRadius: 4,
                  spreadRadius: 1,
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(
            badgeLabel,
            style: GoogleFonts.spaceGrotesk(
              fontSize: 9,
              fontWeight: FontWeight.w700,
              color: item.accent,
              letterSpacing: 1.1,
            ),
          ),
        ],
      ),
    );
  }

  // ─── Right Section: Secondary Actions (Legal Advice, Benchmarks) ───
  Widget _buildSecondaryActions() {
    return Row(
      children: [
        // Legal advice button
        Expanded(
          child: GestureDetector(
            onTap: () {
              _showHolographicFeedback(
                  'Transitioning to AI Legal Bot...', Icons.gavel);
            },
            child: _GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  const Icon(
                    Icons.gavel,
                    color: _ConsoleColors.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Legal Advice',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _ConsoleColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),

        // Benchmarking button
        Expanded(
          child: GestureDetector(
            onTap: () {
              _showHolographicFeedback(
                  'Loading Market Indexes...', Icons.analytics_outlined);
            },
            child: _GlassCard(
              padding: const EdgeInsets.symmetric(vertical: 14),
              child: Column(
                children: [
                  const Icon(
                    Icons.compare_arrows_rounded,
                    color: _ConsoleColors.onSurfaceVariant,
                    size: 20,
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Benchmarking',
                    style: GoogleFonts.inter(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: _ConsoleColors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ─── Helper: Empty/Error filtered state ───
  Widget _buildEmptyFilteredState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.travel_explore,
              color: _ConsoleColors.onSurfaceVariant,
              size: 40,
            ),
            const SizedBox(height: 16),
            Text(
              'NO CLAUSES DETECTED',
              style: GoogleFonts.spaceGrotesk(
                fontSize: 14,
                fontWeight: FontWeight.w700,
                color: _ConsoleColors.onSurface,
                letterSpacing: 1.2,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'No items match your active filters or search terms.',
              style: GoogleFonts.inter(
                fontSize: 12,
                color: _ConsoleColors.onSurfaceVariant,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  // ─── Floating Toast Notification Feedback (Holographic Design) ───
  void _showHolographicFeedback(String msg, IconData icon) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.symmetric(horizontal: 40, vertical: 120),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: const Color(0xFF201F20).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _ConsoleColors.primary.withValues(alpha: 0.25),
                  width: 0.8,
                ),
                boxShadow: [
                  BoxShadow(
                    color: _ConsoleColors.primary.withValues(alpha: 0.1),
                    blurRadius: 16,
                  ),
                ],
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, color: _ConsoleColors.primary, size: 18),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      msg.toUpperCase(),
                      style: GoogleFonts.spaceGrotesk(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: _ConsoleColors.onSurface,
                        letterSpacing: 1.0,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  // ─── Custom Floating Bottom Navigation Bar (Visual parity with Home page) ───
  Widget _buildBottomNavBar(BuildContext context) {
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
              color: const Color(0xFF201F20).withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(9999),
              border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withValues(alpha: 0.05),
                  Colors.transparent,
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.8),
                  blurRadius: 32,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pushAndRemoveUntil(
                      MaterialPageRoute(
                          builder: (_) => const HomeDashboardScreen()),
                      (route) => false,
                    );
                  },
                  child: const _NavBarItem(
                      icon: Icons.home_outlined, label: 'Home'),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).pop();
                  },
                  child: const _NavBarItem(
                    icon: Icons.analytics,
                    label: 'Analyse',
                    isSelected:
                        true, // Mark active as we are in the analysis flow
                  ),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ChatScreen(
                          loanId: widget.report.loanId,
                        ),
                      ),
                    );
                  },
                  child: const _NavBarItem(
                      icon: Icons.smart_toy_outlined, label: 'AI Assistant'),
                ),
                const _NavBarItem(
                    icon: Icons.compare_arrows_outlined, label: 'Compare'),
                const _NavBarItem(icon: Icons.person_outline, label: 'Profile'),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Floating Nav Item ───
class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;

  const _NavBarItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? _ConsoleColors.primary
        : _ConsoleColors.onSurfaceVariant.withValues(alpha: 0.7);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(
          icon,
          color: color,
          size: 24,
          shadows: isSelected
              ? [
                  BoxShadow(
                    color: _ConsoleColors.primary.withValues(alpha: 0.8),
                    blurRadius: 8,
                  ),
                ]
              : null,
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color,
          ),
        ),
      ],
    );
  }
}

// ─── Reusable Glassmorphism Card ───
class _GlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final Color? borderColor;
  final Color? leftBorderColor;
  final AnimationController? ambientController;
  final bool hasScanline;

  const _GlassCard({
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.borderColor,
    this.leftBorderColor,
    this.ambientController,
    this.hasScanline = false,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(12);
    return ClipRRect(
      borderRadius: radius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Stack(
          children: [
            Container(
              decoration: BoxDecoration(
                color: _ConsoleColors.surfaceContainer.withValues(alpha: 0.58),
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: _ConsoleColors.primary.withValues(alpha: 0.03),
                    blurRadius: 20,
                    spreadRadius: -2,
                  ),
                ],
              ),
              child: Padding(
                padding: padding,
                child: child,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: CustomPaint(
                  painter: _GlassBorderPainter(
                    strokeWidth: 1.0,
                    radius: const Radius.circular(12),
                    borderColor: borderColor,
                    leftBorderColor: leftBorderColor,
                  ),
                ),
              ),
            ),
            if (hasScanline && ambientController != null)
              Positioned.fill(
                child: IgnorePointer(
                  child: AnimatedBuilder(
                    animation: ambientController!,
                    builder: (context, _) {
                      return CustomPaint(
                        painter: _ScanlineSweepPainter(
                          progress: ambientController!.value,
                        ),
                      );
                    },
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Custom Painter: Elegant Glass Borders ───
class _GlassBorderPainter extends CustomPainter {
  final double strokeWidth;
  final Radius radius;
  final Color? borderColor;
  final Color? leftBorderColor;

  _GlassBorderPainter({
    required this.strokeWidth,
    required this.radius,
    this.borderColor,
    this.leftBorderColor,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final rect = Offset.zero & size;
    final rrect = RRect.fromRectAndRadius(rect, radius);
    final outerRect = rrect.deflate(strokeWidth / 2);

    final paint = Paint()
      ..strokeWidth = strokeWidth
      ..style = PaintingStyle.stroke
      ..shader = LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [
          (borderColor ?? Colors.white)
              .withValues(alpha: borderColor != null ? 0.32 : 0.18),
          (borderColor ?? Colors.white)
              .withValues(alpha: borderColor != null ? 0.18 : 0.08),
          (borderColor ?? Colors.white)
              .withValues(alpha: borderColor != null ? 0.08 : 0.02),
        ],
        stops: const [0.0, 0.5, 1.0],
      ).createShader(rect);

    canvas.drawRRect(outerRect, paint);

    if (leftBorderColor != null) {
      final leftPaint = Paint()
        ..strokeWidth = 3.5
        ..color = leftBorderColor!
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round;

      final path = Path()
        ..moveTo(0, size.height - radius.y)
        ..lineTo(0, radius.y)
        ..arcToPoint(Offset(radius.x, 0), radius: radius, clockwise: true);

      canvas.drawPath(path, leftPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _GlassBorderPainter oldDelegate) => false;
}

// ─── Custom Painter: Holographic Scanline Sweep ───
class _ScanlineSweepPainter extends CustomPainter {
  final double progress;

  _ScanlineSweepPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final y = progress * size.height;
    final paint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          Colors.transparent,
          _ConsoleColors.primary.withValues(alpha: 0.04),
          _ConsoleColors.primary.withValues(alpha: 0.18),
          _ConsoleColors.primary.withValues(alpha: 0.04),
          Colors.transparent,
        ],
        stops: const [0.0, 0.4, 0.5, 0.6, 1.0],
      ).createShader(Rect.fromLTWH(0, y - 10, size.width, 20));

    canvas.drawRect(Rect.fromLTWH(0, y - 10, size.width, 20), paint);

    final linePaint = Paint()
      ..shader = LinearGradient(
        colors: [
          Colors.transparent,
          Colors.white.withValues(alpha: 0.50),
          Colors.transparent,
        ],
      ).createShader(Rect.fromLTWH(0, y - 0.75, size.width, 1.5));
    canvas.drawRect(Rect.fromLTWH(0, y - 0.75, size.width, 1.5), linePaint);
  }

  @override
  bool shouldRepaint(covariant _ScanlineSweepPainter oldDelegate) =>
      oldDelegate.progress != progress;
}

// ─── Custom Painter: Subtle Film Grain / Noise Overlay ───
class _NoiseOverlayPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    final random = Random();

    // Draw micro particles for holographic texture
    for (int i = 0; i < 400; i++) {
      final x = random.nextDouble() * size.width;
      final y = random.nextDouble() * size.height;
      final sizePx = random.nextDouble() * 1.2;
      paint.color = Colors.white.withValues(alpha: random.nextDouble() * 0.15);
      canvas.drawRect(Rect.fromLTWH(x, y, sizePx, sizePx), paint);
    }
  }

  @override
  bool shouldRepaint(covariant _NoiseOverlayPainter oldDelegate) => true;
}
