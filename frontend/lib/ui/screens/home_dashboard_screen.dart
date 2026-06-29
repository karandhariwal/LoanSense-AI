import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:loansense_ai/data/models/loan_analysis_report.dart';
import 'package:loansense_ai/data/models/loan_history_item.dart';
import 'package:loansense_ai/presentation/providers/active_loan_provider.dart';
import 'package:loansense_ai/presentation/providers/loan_providers.dart';
import 'package:loansense_ai/presentation/providers/profile_providers.dart';
import 'package:loansense_ai/ui/screens/analysis_report_screen.dart';
import 'package:loansense_ai/ui/screens/upload_ai_scan_screen.dart';
import 'package:loansense_ai/ui/screens/clause_intelligence_screen.dart';
import 'package:loansense_ai/ui/screens/loan_comparison_screen.dart';
import 'package:loansense_ai/ui/screens/profile_settings_screen.dart';
import 'package:loansense_ai/ui/screens/scan_screen.dart';

class HomeDashboardScreen extends ConsumerStatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  ConsumerState<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends ConsumerState<HomeDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;
  late TextEditingController _searchController;
  Timer? _searchDebounce;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
    _searchController = TextEditingController();
  }

  /// Shows a themed snackbar prompting the user to upload a loan document
  /// before accessing AI-gated features.
  void _showNoLoanSnackbar(BuildContext context, String feature) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF201F20).withValues(alpha: 0.90),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: const Color(0xFFDBC3A8).withValues(alpha: 0.4),
                ),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFDBC3A8).withValues(alpha: 0.12),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: Row(
                children: [
                  const Icon(
                    Icons.upload_file_outlined,
                    color: Color(0xFFDBC3A8),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Upload a loan document first to use $feature.',
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE5E2E3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  void dispose() {
    _scanController.dispose();
    _searchDebounce?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _pickAndUploadPDF() async {
    try {
      // 1. Pick PDF File using real FilePicker API compatible with the local version
      final result = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );

      // Guard use of BuildContext across async gap!
      if (!mounted) return;

      // 2. Handle cancellation properly
      if (result == null || result.files.isEmpty) {
        _showFintechToast(
          context: context,
          message: "Upload cancelled: No document selected.",
          isError: true,
        );
        return;
      }

      final PlatformFile file = result.files.first;

      // 3. Validate file extension
      final extension = file.extension?.toLowerCase();
      if (extension != 'pdf') {
        _showFintechToast(
          context: context,
          message: "Invalid file type: Only PDF loan agreements are supported.",
          isError: true,
        );
        return;
      }

      // 4. Validate file size (limit to 15 MB for realism)
      final double sizeMb = file.size / (1024 * 1024);
      if (sizeMb > 15.0) {
        _showFintechToast(
          context: context,
          message: "File too large: Maximum supported size is 15 MB.",
          isError: true,
        );
        return;
      }

      // 5. Success - Show dynamic feedback
      _showFintechToast(
        context: context,
        message: "Secured PDF verified. Initializing AI Engine...",
        isError: false,
      );

      // 6. Navigate to UploadAiScanScreen with selected file info
      if (mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => UploadAiScanScreen(
              fileName: file.name,
              fileSizeMb: sizeMb,
              filePath: file.path,
            ),
          ),
        );
      }
    } catch (e) {
      _showFintechToast(
        context: context,
        message: "Secure upload error: ${e.toString()}",
        isError: true,
      );
    }
  }

  void _showFintechToast({
    required BuildContext context,
    required String message,
    required bool isError,
  }) {
    ScaffoldMessenger.of(context).clearSnackBars();
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        margin: const EdgeInsets.all(16),
        content: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                color: const Color(0xFF201F20).withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isError
                      ? const Color(0xFFFFB4AB).withValues(alpha: 0.3)
                      : const Color(0xFFC3C6D7).withValues(alpha: 0.3),
                ),
                boxShadow: [
                  BoxShadow(
                    color: isError
                        ? const Color(0xFFFFB4AB).withValues(alpha: 0.1)
                        : const Color(0xFFC3C6D7).withValues(alpha: 0.1),
                    blurRadius: 15,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Icon(
                    isError
                        ? Icons.error_outline_rounded
                        : Icons.verified_user_outlined,
                    color: isError
                        ? const Color(0xFFFFB4AB)
                        : const Color(0xFFC3C6D7),
                    size: 20,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      message,
                      style: GoogleFonts.inter(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: const Color(0xFFE5E2E3),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final activeLoan = ref.watch(activeLoanProvider);
    final hasLoan = activeLoan != null;

    return Scaffold(
      backgroundColor: const Color(0xFF131314),
      body: Stack(
        children: [
          // Ambient Background Glow
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: const Color(0xFFC3C6D7).withValues(alpha: 0.05),
                boxShadow: [
                  BoxShadow(
                    color: const Color(0xFFC3C6D7).withValues(alpha: 0.05),
                    blurRadius: 100,
                    spreadRadius: 100,
                  ),
                ],
              ),
            ),
          ),

          // Main Scrollable Content
          SafeArea(
            child: ListView(
              padding: const EdgeInsets.only(
                left: 40,
                right: 40,
                top: 100, // Space for top app bar
                bottom: 120, // Space for bottom nav bar
              ),
              children: [
                _buildGreetingSection(),
                const SizedBox(height: 80),
                hasLoan
                    ? _buildHeroAICard()
                    : _buildEmptyState(activeLoan),
                const SizedBox(height: 80),
                _buildQuickActionGrid(activeLoan),
                const SizedBox(height: 80),
                _buildIntelligenceHistory(),
              ],
            ),
          ),

          // Fixed Top App Bar
          const Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _TopAppBar(),
          ),

          // Fixed Bottom Nav Bar
          Positioned(
            bottom: 32,
            left: 0,
            right: 0,
            child: _BottomNavBar(
              onAnalyseTap: _pickAndUploadPDF,
              activeLoan: activeLoan,
              onNoLoan: (feature) => _showNoLoanSnackbar(context, feature),
            ),
          ),
        ],
      ),
    );
  }

  /// Returns a time-appropriate greeting word based on current local hour.
  String _greetingWord() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  Widget _buildGreetingSection() {
    // Read user's display name from the profile provider (fallback to empty).
    final profileAsync = ref.watch(profileSettingsProvider);
    final displayName = profileAsync.whenOrNull(
      data: (state) => state.profile.displayName,
    ) ?? '';
    final greeting = displayName.isNotEmpty
        ? '${_greetingWord()}, ${displayName.split(' ').first}'
        : _greetingWord();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'EXECUTIVE DASHBOARD',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFC3C6D7),
            letterSpacing: 2.4, // 0.2em
          ),
        ),
        const SizedBox(height: 8),
        Text(
          greeting,
          style: GoogleFonts.spaceGrotesk(
            fontSize: 48,
            fontWeight: FontWeight.w700,
            color: const Color(0xFFE5E2E3),
            letterSpacing: -0.96, // -0.02em
            height: 1.1,
          ),
        ),
      ],
    );
  }

  Widget _buildHeroAICard() {
    return RepaintBoundary(
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          color: Colors.white.withValues(alpha: 0.03),
          boxShadow: [
            BoxShadow(
              color: const Color(0xFFC3C6D7).withValues(alpha: 0.1),
              blurRadius: 20,
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: LayoutBuilder(builder: (context, constraints) {
                    bool isWide = constraints.maxWidth > 600;
                    return Flex(
                      direction: isWide ? Axis.horizontal : Axis.vertical,
                      children: [
                        Expanded(
                          flex: isWide ? 1 : 0,
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Upload a loan agreement. We’ll reveal what’s hidden inside.',
                                style: GoogleFonts.spaceGrotesk(
                                  fontSize: 32,
                                  fontWeight: FontWeight.w600,
                                  color: const Color(0xFFE5E2E3),
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Text(
                                'Our advanced neural networks detect hidden clauses, predatory interest shifts, and liability traps in seconds.',
                                style: GoogleFonts.inter(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                  color: const Color(0xFFC7C6CC),
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 24),
                              Wrap(
                                spacing: 16,
                                runSpacing: 16,
                                children: [
                                  _PrimaryButton(
                                    icon: Icons.upload_file_outlined,
                                    label: 'Upload PDF',
                                    onPressed: _pickAndUploadPDF,
                                  ),
                                  _SecondaryButton(
                                    label: 'Scan Document',
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (_) => const ScanScreen(),
                                        ),
                                      );
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                        if (isWide) const SizedBox(width: 48),
                        if (isWide)
                          Expanded(
                            child: Container(
                              height: 200,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(
                                    color:
                                        Colors.white.withValues(alpha: 0.12)),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      'https://lh3.googleusercontent.com/aida-public/AB6AXuCw6J8pc6QX4wqooZmuOzg3QS_2YUx2Ta4oSq9-2lsE4SFDB-9S_txwIIkmombcC4qK-J_pQMw70itAMH0NbI_RL5gi_U1DI7HLQmNBW_hx6Uh2WQObO1TBCFYfeYQuf7bXHJEPTZPw0ySSFlhLUP2T8WL1qrZ2ZqcRDlQTbr-aGa_A69QZN9Ldd5vMBE0FPCmRxjO47e2D3zNy701pLLwAWtbj_z_NFCvpthA9B2Bh22qdSKlcCd6EnAt1LHvHdiWETrgMynKykA',
                                      fit: BoxFit.cover,
                                      color:
                                          Colors.black.withValues(alpha: 0.4),
                                      colorBlendMode: BlendMode.darken,
                                    ),
                                  ),
                                  Container(
                                    decoration: const BoxDecoration(
                                      gradient: LinearGradient(
                                        begin: Alignment.bottomCenter,
                                        end: Alignment.topCenter,
                                        colors: [
                                          Color(0xFF131314),
                                          Colors.transparent,
                                        ],
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                      ],
                    );
                  }),
                ),
                // Scanning Line Animation
                AnimatedBuilder(
                  animation: _scanController,
                  builder: (context, child) {
                    return Positioned(
                      top: _scanController.value * 350, // Approximate height
                      left: 0,
                      right: 0,
                      child: Container(
                        height: 2,
                        decoration: BoxDecoration(
                          color: const Color(0xFFC3C6D7).withValues(alpha: 0.4),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFC3C6D7)
                                  .withValues(alpha: 0.8),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// ─── Empty State (shown when no loan is loaded) ───
  Widget _buildEmptyState(LoanAnalysisReport? _) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
        color: Colors.white.withValues(alpha: 0.03),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC3C6D7).withValues(alpha: 0.08),
            blurRadius: 20,
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 40),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                // Icon with ambient glow ring
                AnimatedBuilder(
                  animation: _scanController,
                  builder: (context, _) {
                    return Container(
                      width: 88,
                      height: 88,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: const Color(0xFFC3C6D7).withValues(alpha: 0.08),
                        boxShadow: [
                          BoxShadow(
                            color: const Color(0xFFC3C6D7).withValues(
                                alpha: 0.15 + _scanController.value * 0.12),
                            blurRadius: 28 + _scanController.value * 12,
                            spreadRadius: 2,
                          ),
                        ],
                        border: Border.all(
                            color: const Color(0xFFC3C6D7)
                                .withValues(alpha: 0.2)),
                      ),
                      child: const Icon(
                        Icons.upload_file_outlined,
                        size: 40,
                        color: Color(0xFFC3C6D7),
                      ),
                    );
                  },
                ),
                const SizedBox(height: 28),
                Text(
                  'No Loan Document',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.spaceGrotesk(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFE5E2E3),
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Upload a PDF loan agreement to unlock AI-powered analysis, clause intelligence, and risk detection.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.inter(
                    fontSize: 15,
                    fontWeight: FontWeight.w400,
                    color: const Color(0xFFC7C6CC),
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 12),
                // Feature pills
                const Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 8,
                  children: [
                    _FeaturePill(label: 'AI Risk Analysis'),
                    _FeaturePill(label: 'Clause Intelligence'),
                    _FeaturePill(label: 'AI Assistant'),
                    _FeaturePill(label: 'Loan Comparison'),
                  ],
                ),
                const SizedBox(height: 32),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  alignment: WrapAlignment.center,
                  children: [
                    _PrimaryButton(
                      icon: Icons.upload_file_outlined,
                      label: 'Upload PDF',
                      onPressed: _pickAndUploadPDF,
                    ),
                    _SecondaryButton(
                      label: 'Scan Document',
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const ScanScreen(),
                          ),
                        );
                      },
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildQuickActionGrid(LoanAnalysisReport? activeLoan) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'PRECISION TOOLS',
          style: GoogleFonts.inter(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: const Color(0xFFC7C6CC),
            letterSpacing: 1.2, // 0.1em
          ),
        ),
        const SizedBox(height: 24),
        LayoutBuilder(builder: (context, constraints) {
          int columns = constraints.maxWidth > 800
              ? 4
              : (constraints.maxWidth > 400 ? 2 : 1);
          return GridView.count(
            crossAxisCount: columns,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            mainAxisSpacing: 16,
            crossAxisSpacing: 16,
            childAspectRatio: 1.5,
            children: [
              _ActionCard(
                icon: Icons.compare_arrows,
                title: 'Compare Loans',
                subtitle: 'Side-by-side technical audit.',
                onTap: activeLoan == null
                    ? () => _showNoLoanSnackbar(context, 'Loan Comparison')
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const LoanComparisonScreen(),
                        ),
                      ),
              ),
              const _ActionCard(
                icon: Icons.calculate_outlined,
                title: 'EMI Calculator',
                subtitle: 'Amortization & volatility test.',
              ),
              _ActionCard(
                icon: Icons.smart_toy_outlined,
                title: 'Ask AI',
                subtitle: 'Direct query on loan terms.',
                isActive: activeLoan != null,
                onTap: activeLoan == null
                    ? () => _showNoLoanSnackbar(context, 'AI Assistant')
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ClauseIntelligenceScreen(
                            report: activeLoan,
                            loanId: activeLoan.loanId,
                          ),
                        ),
                      ),
              ),
              _ActionCard(
                icon: Icons.security_outlined,
                title: 'Risk Report',
                subtitle: 'Compliance & fraud check.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => LoanAnalysisReportScreen(
                        report: activeLoan,
                        loanId: activeLoan?.loanId,
                      ),
                    ),
                  );
                },
              ),
            ],
          );
        }),
      ],
    );
  }

  Future<void> _confirmBulkDelete(BuildContext context, Set<String> selectedIds) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF201F20),
        title: Text(
          'Delete Selected Documents?',
          style: GoogleFonts.spaceGrotesk(
            color: const Color(0xFFE5E2E3),
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Are you sure you want to permanently delete the ${selectedIds.length} selected loan document(s)? This action cannot be undone.',
          style: GoogleFonts.inter(color: const Color(0xFFC7C6CC)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text(
              'Cancel',
              style: GoogleFonts.inter(color: const Color(0xFFC3C6D7)),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text(
              'Delete',
              style: GoogleFonts.inter(color: const Color(0xFFFFB4AB), fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      try {
        _showFintechToast(
          context: context,
          message: 'Deleting selected documents...',
          isError: false,
        );
        final repo = ref.read(loanRepositoryProvider);
        await repo.deleteLoansBulk(selectedIds.toList());
        
        // Invalidate history to trigger refresh
        ref.invalidate(loanHistoryProvider);
        
        // Reset selection state
        ref.read(loanHistorySelectionProvider.notifier).state = {};
        ref.read(loanHistorySelectionModeProvider.notifier).state = false;
        
        if (context.mounted) {
          _showFintechToast(
            context: context,
            message: 'Documents deleted successfully.',
            isError: false,
          );
        }
      } catch (e) {
        if (context.mounted) {
          _showFintechToast(
            context: context,
            message: 'Failed to delete documents: ${e.toString()}',
            isError: true,
          );
        }
      }
    }
  }

  Widget _buildRiskChip(String label, String? value, bool isSelected, LoanHistoryFilters filters) {
    return ChoiceChip(
      label: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 12,
          fontWeight: FontWeight.w600,
          color: isSelected ? const Color(0xFF131314) : const Color(0xFFC3C6D7),
        ),
      ),
      selected: isSelected,
      selectedColor: const Color(0xFFC3C6D7),
      backgroundColor: Colors.white.withValues(alpha: 0.03),
      checkmarkColor: const Color(0xFF131314),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(9999),
        side: BorderSide(
          color: isSelected ? const Color(0xFFC3C6D7) : Colors.white.withValues(alpha: 0.12),
        ),
      ),
      onSelected: (selected) {
        if (selected) {
          ref.read(loanHistoryFiltersProvider.notifier).update(
            (s) => s.copyWith(riskLevel: value, clearRiskLevel: value == null),
          );
        }
      },
    );
  }

  Widget _buildFiltersPanel(LoanHistoryFilters filters) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Search Input
        Container(
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: TextField(
            controller: _searchController,
            style: GoogleFonts.inter(color: const Color(0xFFE5E2E3), fontSize: 14),
            decoration: InputDecoration(
              hintText: 'Search by lender or document name...',
              hintStyle: GoogleFonts.inter(color: Colors.white30, fontSize: 14),
              prefixIcon: const Icon(Icons.search, color: Colors.white30, size: 20),
              suffixIcon: filters.search.isNotEmpty
                  ? IconButton(
                      icon: const Icon(Icons.clear, color: Colors.white54, size: 16),
                      onPressed: () {
                        _searchController.clear();
                        _searchDebounce?.cancel();
                        ref.read(loanHistoryFiltersProvider.notifier).update(
                          (s) => s.copyWith(search: ''),
                        );
                      },
                    )
                  : null,
              border: InputBorder.none,
              contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            ),
            onChanged: (val) {
              _searchDebounce?.cancel();
              _searchDebounce = Timer(const Duration(milliseconds: 350), () {
                ref.read(loanHistoryFiltersProvider.notifier).update(
                  (s) => s.copyWith(search: val),
                );
              });
            },
          ),
        ),
        const SizedBox(height: 12),

        // Risk filters chips row
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              _buildRiskChip('All', null, filters.riskLevel == null, filters),
              const SizedBox(width: 8),
              _buildRiskChip('Safe 🟢', 'safe', filters.riskLevel == 'safe', filters),
              const SizedBox(width: 8),
              _buildRiskChip('Moderate 🟡', 'moderate', filters.riskLevel == 'moderate', filters),
              const SizedBox(width: 8),
              _buildRiskChip('Dangerous 🔴', 'dangerous', filters.riskLevel == 'dangerous', filters),
            ],
          ),
        ),
        const SizedBox(height: 12),

        // Date Picker & Sort controls
        Row(
          children: [
            Expanded(
              child: InkWell(
                onTap: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                    initialDateRange: filters.startDate != null && filters.endDate != null
                        ? DateTimeRange(start: filters.startDate!, end: filters.endDate!)
                        : null,
                    builder: (context, child) {
                      return Theme(
                        data: ThemeData.dark().copyWith(
                          colorScheme: const ColorScheme.dark(
                            primary: Color(0xFFC3C6D7),
                            onPrimary: Color(0xFF131314),
                            surface: Color(0xFF201F20),
                            onSurface: Color(0xFFE5E2E3),
                          ),
                        ),
                        child: child!,
                      );
                    },
                  );
                  if (picked != null) {
                    ref.read(loanHistoryFiltersProvider.notifier).update(
                      (s) => s.copyWith(startDate: picked.start, endDate: picked.end),
                    );
                  }
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.03),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.date_range, color: Color(0xFFC3C6D7), size: 16),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          filters.startDate == null
                              ? 'Select Dates'
                              : "${filters.startDate!.month}/${filters.startDate!.day} - ${filters.endDate!.month}/${filters.endDate!.day}",
                          style: GoogleFonts.inter(color: const Color(0xFFC3C6D7), fontSize: 12, fontWeight: FontWeight.w600),
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (filters.startDate != null)
                        GestureDetector(
                          onTap: () {
                            ref.read(loanHistoryFiltersProvider.notifier).update(
                              (s) => s.copyWith(clearStartDate: true, clearEndDate: true),
                            );
                          },
                          child: const Icon(Icons.close, color: Colors.white54, size: 14),
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            PopupMenuButton<String>(
              onSelected: (value) {
                ref.read(loanHistoryFiltersProvider.notifier).update(
                  (s) => s.copyWith(sortBy: value),
                );
              },
              itemBuilder: (context) => [
                const PopupMenuItem(value: 'upload_date', child: Text('Sort by Upload Date')),
                const PopupMenuItem(value: 'risk_score', child: Text('Sort by Risk Score')),
                const PopupMenuItem(value: 'lender_name', child: Text('Sort by Lender Name')),
              ],
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.03),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.sort, color: Color(0xFFC3C6D7), size: 16),
                    const SizedBox(width: 8),
                    Text(
                      filters.sortBy == 'risk_score'
                          ? 'Risk Score'
                          : filters.sortBy == 'lender_name'
                              ? 'Lender'
                              : 'Upload Date',
                      style: GoogleFonts.inter(color: const Color(0xFFC3C6D7), fontSize: 12, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton(
              icon: Icon(
                filters.order == 'asc' ? Icons.arrow_upward : Icons.arrow_downward,
                color: const Color(0xFFC3C6D7),
                size: 18,
              ),
              onPressed: () {
                ref.read(loanHistoryFiltersProvider.notifier).update(
                  (s) => s.copyWith(order: filters.order == 'asc' ? 'desc' : 'asc'),
                );
              },
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildBulkActionsBar(Set<String> selectedIds) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFFFB4AB).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFFB4AB).withValues(alpha: 0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Row(
            children: [
              const Icon(Icons.check_circle_outline, color: Color(0xFFFFB4AB), size: 18),
              const SizedBox(width: 8),
              Text(
                '${selectedIds.length} selected',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFFFB4AB),
                ),
              ),
            ],
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: () => _confirmBulkDelete(context, selectedIds),
                icon: const Icon(Icons.delete_forever, color: Color(0xFFFFB4AB), size: 16),
                label: Text(
                  'Delete',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: const Color(0xFFFFB4AB),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  ref.read(loanHistorySelectionProvider.notifier).state = {};
                },
                child: Text(
                  'Deselect All',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFC3C6D7),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildIntelligenceHistory() {
    final historyAsync = ref.watch(loanHistoryProvider);
    final filters = ref.watch(loanHistoryFiltersProvider);
    final isSelectionMode = ref.watch(loanHistorySelectionModeProvider);
    final selectedIds = ref.watch(loanHistorySelectionProvider);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'INTELLIGENCE HISTORY',
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFC7C6CC),
                letterSpacing: 1.2,
              ),
            ),
            TextButton.icon(
              onPressed: () {
                ref.read(loanHistorySelectionModeProvider.notifier).state = !isSelectionMode;
                ref.read(loanHistorySelectionProvider.notifier).state = {};
              },
              icon: Icon(
                isSelectionMode ? Icons.close : Icons.select_all,
                color: const Color(0xFFC3C6D7),
                size: 16,
              ),
              label: Text(
                isSelectionMode ? 'Cancel' : 'Select',
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFC3C6D7),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildFiltersPanel(filters),
        const SizedBox(height: 16),
        if (isSelectionMode && selectedIds.isNotEmpty) ...[
          _buildBulkActionsBar(selectedIds),
          const SizedBox(height: 16),
        ],
        historyAsync.when(
          loading: () => const SizedBox(
            height: 135,
            child: Center(
              child: CircularProgressIndicator(
                color: Color(0xFFC3C6D7),
                strokeWidth: 2,
              ),
            ),
          ),
          error: (err, _) => SizedBox(
            height: 80,
            child: Center(
              child: Text(
                'Could not load history.',
                style: GoogleFonts.inter(
                  fontSize: 13,
                  color: const Color(0xFFC7C6CC).withValues(alpha: 0.6),
                ),
              ),
            ),
          ),
          data: (items) {
            if (items.isEmpty) {
              return SizedBox(
                height: 80,
                child: Center(
                  child: Text(
                    'No documents matching filters found.',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.inter(
                      fontSize: 13,
                      color: const Color(0xFFC7C6CC).withValues(alpha: 0.6),
                    ),
                  ),
                ),
              );
            }
            return ListView.separated(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              itemCount: items.length,
              separatorBuilder: (_, __) => const SizedBox(height: 16),
              itemBuilder: (context, index) {
                final item = items[index];
                final isSelected = selectedIds.contains(item.loanId);

                return Row(
                  children: [
                    if (isSelectionMode) ...[
                      Checkbox(
                        value: isSelected,
                        activeColor: const Color(0xFFC3C6D7),
                        checkColor: const Color(0xFF131314),
                        side: const BorderSide(color: Colors.white30, width: 1.5),
                        onChanged: (val) {
                          final current = Set<String>.from(selectedIds);
                          if (val == true) {
                            current.add(item.loanId);
                          } else {
                            current.remove(item.loanId);
                          }
                          ref.read(loanHistorySelectionProvider.notifier).state = current;
                        },
                      ),
                      const SizedBox(width: 8),
                    ],
                    Expanded(
                      child: InkWell(
                        onTap: isSelectionMode
                            ? () {
                                final current = Set<String>.from(selectedIds);
                                if (current.contains(item.loanId)) {
                                  current.remove(item.loanId);
                                } else {
                                  current.add(item.loanId);
                                }
                                ref.read(loanHistorySelectionProvider.notifier).state = current;
                              }
                            : () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => LoanAnalysisReportScreen(
                                      report: null,
                                      loanId: item.loanId,
                                    ),
                                  ),
                                );
                              },
                        child: _HistoryCardFromItem(item: item),
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
      ],
    );
  }
}

class _TopAppBar extends StatelessWidget {
  const _TopAppBar();

  @override
  Widget build(BuildContext context) {
    final topPadding = MediaQuery.of(context).padding.top;
    return ClipRRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: EdgeInsets.only(
            left: 20,
            right: 20,
            top: topPadding + 12,
            bottom: 12,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFF131314).withValues(alpha: 0.8),
            border: Border(
              bottom: BorderSide(color: Colors.white.withValues(alpha: 0.12)),
            ),
            boxShadow: [
              BoxShadow(
                color: const Color(0xFFC3C6D7).withValues(alpha: 0.1),
                blurRadius: 15,
              ),
            ],
          ),
          child: Row(
            children: [
              // Initials avatar — no external image dependency
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFFC3C6D7).withValues(alpha: 0.15),
                  border: Border.all(color: const Color(0xFFC3C6D7).withValues(alpha: 0.35)),
                ),
                child: const Center(
                  child: Icon(
                    Icons.person_outline,
                    color: Color(0xFFC3C6D7),
                    size: 20,
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
                        color: const Color(0xFFE5E2E3),
                        letterSpacing: -0.3,
                        height: 1.2,
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
                            color: Color(0xFFC3C6D7),
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Color(0xFFC3C6D7),
                                blurRadius: 6,
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'AI READY',
                          style: GoogleFonts.inter(
                            fontSize: 10,
                            fontWeight: FontWeight.w600,
                            color: const Color(0xFFC7C6CC),
                            letterSpacing: 1.2,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              const Icon(
                Icons.sensors,
                color: Color(0xFFC3C6D7),
                size: 22,
              ),
              const SizedBox(width: 16),
              const Icon(
                Icons.notifications_none,
                color: Color(0xFFC7C6CC),
                size: 22,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomNavBar extends StatelessWidget {
  final VoidCallback? onAnalyseTap;
  final LoanAnalysisReport? activeLoan;
  final void Function(String feature)? onNoLoan;

  const _BottomNavBar({
    this.onAnalyseTap,
    this.activeLoan,
    this.onNoLoan,
  });

  @override
  Widget build(BuildContext context) {
    final hasLoan = activeLoan != null;

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
                const _NavBarItem(
                    icon: Icons.home_filled, label: 'Home', isSelected: true),
                GestureDetector(
                  onTap: onAnalyseTap,
                  child: const _NavBarItem(
                      icon: Icons.analytics_outlined, label: 'Analyse'),
                ),
                // AI Assistant — guarded: requires an active loan
                GestureDetector(
                  onTap: () {
                    if (!hasLoan) {
                      onNoLoan?.call('AI Assistant');
                      return;
                    }
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClauseIntelligenceScreen(
                          report: activeLoan,
                          loanId: activeLoan!.loanId,
                        ),
                      ),
                    );
                  },
                  child: _NavBarItem(
                    icon: Icons.smart_toy_outlined,
                    label: 'AI Assistant',
                    isDisabled: !hasLoan,
                  ),
                ),
                // Compare — allow freely; the screen has its own upload flow
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const LoanComparisonScreen(),
                      ),
                    );
                  },
                  child: const _NavBarItem(
                      icon: Icons.compare_arrows, label: 'Compare'),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const ProfileSettingsScreen(),
                      ),
                    );
                  },
                  child: const _NavBarItem(
                      icon: Icons.person_outline, label: 'Profile'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _NavBarItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool isSelected;
  final bool isDisabled;

  const _NavBarItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
    this.isDisabled = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? const Color(0xFFC3C6D7)
        : isDisabled
            ? const Color(0xFFC7C6CC).withValues(alpha: 0.3)
            : const Color(0xFFC7C6CC).withValues(alpha: 0.7);

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
                    color: const Color(0xFFC3C6D7).withValues(alpha: 0.8),
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

class _PrimaryButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;

  const _PrimaryButton({
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9999),
        gradient: const LinearGradient(
          colors: [Color(0xFFC3C6D7), Color(0xFFC6C6CD)],
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFC3C6D7).withValues(alpha: 0.3),
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
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  icon,
                  color: const Color(0xFF2C303D), // on-primary
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  label,
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFF2C303D),
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

class _SecondaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;

  const _SecondaryButton({
    required this.label,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(9999),
          hoverColor: Colors.white.withValues(alpha: 0.05),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            child: Text(
              label,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: const Color(0xFFE5E2E3),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ActionCard extends StatefulWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isActive;
  final VoidCallback? onTap;

  const _ActionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    this.isActive = false,
    this.onTap,
  });

  @override
  State<_ActionCard> createState() => _ActionCardState();
}

class _ActionCardState extends State<_ActionCard> {
  bool _isHovered = false;

  @override
  Widget build(BuildContext context) {
    return MouseRegion(
      onEnter: (_) => setState(() => _isHovered = true),
      onExit: (_) => setState(() => _isHovered = false),
      child: GestureDetector(
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          transform: Matrix4.translationValues(0, _isHovered ? -4 : 0, 0),
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.03),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: widget.isActive
                  ? const Color(0xFFC3C6D7).withValues(alpha: 0.3)
                  : Colors.white.withValues(alpha: 0.12),
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: widget.isActive
                      ? const Color(0xFFC3C6D7).withValues(alpha: 0.2)
                      : _isHovered
                          ? const Color(0xFFC3C6D7)
                          : const Color(0xFFC3C6D7).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(
                  widget.icon,
                  color: _isHovered && !widget.isActive
                      ? const Color(0xFF131314)
                      : const Color(0xFFC3C6D7),
                  size: 24,
                ),
              ),
              const SizedBox(height: 24),
              Text(
                widget.title,
                style: GoogleFonts.spaceGrotesk(
                  fontSize: 24,
                  fontWeight: FontWeight.w500,
                  color: const Color(0xFFE5E2E3),
                  height: 1.3,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                widget.subtitle,
                style: GoogleFonts.inter(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: const Color(0xFFC7C6CC),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _HistoryCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String riskScore;
  final String date;
  final String status;
  final IconData statusIcon;
  final Color color;

  const _HistoryCard({
    required this.title,
    required this.subtitle,
    required this.riskScore,
    required this.date,
    required this.status,
    required this.statusIcon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.03),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            // Left indicator strip
            Positioned(
              left: 0,
              top: 0,
              bottom: 0,
              width: 4,
              child: Container(color: color),
            ),
            // Card contents
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              style: GoogleFonts.spaceGrotesk(
                                fontSize: 24,
                                fontWeight: FontWeight.w500,
                                color: const Color(0xFFE5E2E3),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                            const SizedBox(height: 4),
                            Text(
                              subtitle,
                              style: GoogleFonts.inter(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: const Color(0xFFC7C6CC),
                              ),
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          'RISK: $riskScore',
                          style: GoogleFonts.spaceGrotesk(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: color,
                            letterSpacing: 0.7, // 0.05em
                          ),
                        ),
                      ),
                    ],
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        date,
                        style: GoogleFonts.inter(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: const Color(0xFFC7C6CC),
                        ),
                      ),
                      Row(
                        children: [
                          Icon(
                            statusIcon,
                            size: 16,
                            color: const Color(0xFFC7C6CC),
                          ),
                          const SizedBox(width: 4),
                          Text(
                            status,
                            style: GoogleFonts.inter(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: const Color(0xFFC7C6CC),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
/// Builds a _HistoryCard from a real [LoanHistoryItem] returned by the backend.
class _HistoryCardFromItem extends StatelessWidget {
  final LoanHistoryItem item;
  const _HistoryCardFromItem({required this.item});

  @override
  Widget build(BuildContext context) {
    final status = item.status.toUpperCase();
    final riskScore = item.riskScore; // 0–100 risk percentage from backend

    // Pick card accent color based on risk percentage (0=safest, 100=riskiest)
    Color accentColor;
    if (status == 'FAILED') {
      accentColor = const Color(0xFFFFB4AB);
    } else if (riskScore != null && riskScore <= 30) {
      accentColor = const Color(0xFFC3C6D7); // safe (low risk %)
    } else if (riskScore != null && riskScore <= 60) {
      accentColor = const Color(0xFFDBC3A8); // moderate
    } else if (riskScore != null) {
      accentColor = const Color(0xFFFFB4AB); // high risk
    } else {
      accentColor = const Color(0xFFC7C6CC); // unknown
    }

    // Status display
    final (statusLabel, statusIcon) = switch (status) {
      'COMPLETED' => ('Analyzed', Icons.check_circle_outline),
      'FAILED' => ('Failed', Icons.error_outline_rounded),
      'PROCESSING' => ('Processing', Icons.sync),
      'PENDING' => ('Pending', Icons.hourglass_empty),
      _ => ('Unknown', Icons.help_outline),
    };

    // Risk badge text (backend already returns 0–100 risk %)
    final riskLabel = riskScore != null
        ? '${riskScore.round()}%'
        : status == 'COMPLETED' ? 'N/A' : '---';

    // Date formatting
    final d = item.uploadDate;
    final months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];
    final dateStr = '${months[d.month - 1]} ${d.day}, ${d.year}';

    return _HistoryCard(
      title: item.lenderName.isNotEmpty ? item.lenderName : 'Unknown Lender',
      subtitle: item.status == 'COMPLETED' ? 'Loan Agreement' : item.status.toLowerCase(),
      riskScore: riskLabel,
      date: dateStr,
      status: statusLabel,
      statusIcon: statusIcon,
      color: accentColor,
    );
  }
}

class _FeaturePill extends StatelessWidget {
  final String label;
  const _FeaturePill({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(9999),
        border: Border.all(
          color: const Color(0xFFC3C6D7).withValues(alpha: 0.2),
        ),
        color: const Color(0xFFC3C6D7).withValues(alpha: 0.06),
      ),
      child: Text(
        label,
        style: GoogleFonts.inter(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: const Color(0xFFC3C6D7).withValues(alpha: 0.8),
          letterSpacing: 0.3,
        ),
      ),
    );
  }
}
