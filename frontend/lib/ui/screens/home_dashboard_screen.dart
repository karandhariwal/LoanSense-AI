import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:file_picker/file_picker.dart';
import 'package:loansense_ai/ui/screens/analysis_report_screen.dart';
import 'package:loansense_ai/ui/screens/upload_ai_scan_screen.dart';
import 'package:loansense_ai/ui/screens/clause_intelligence_screen.dart';
import 'package:loansense_ai/ui/screens/loan_comparison_screen.dart';
import 'package:loansense_ai/ui/screens/profile_settings_screen.dart';
import 'package:loansense_ai/ui/screens/scan_screen.dart';
import 'package:loansense_ai/data/models/loan_analysis_report.dart';

class HomeDashboardScreen extends StatefulWidget {
  const HomeDashboardScreen({super.key});

  @override
  State<HomeDashboardScreen> createState() => _HomeDashboardScreenState();
}

class _HomeDashboardScreenState extends State<HomeDashboardScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _scanController;

  @override
  void initState() {
    super.initState();
    _scanController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _scanController.dispose();
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
                    color: isError ? const Color(0xFFFFB4AB) : const Color(0xFFC3C6D7),
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
                _buildHeroAICard(),
                const SizedBox(height: 80),
                _buildQuickActionGrid(),
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
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildGreetingSection() {
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
          'Good Evening, Karan',
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
                                    color: Colors.white.withValues(alpha: 0.12)),
                              ),
                              child: Stack(
                                fit: StackFit.expand,
                                children: [
                                  ClipRRect(
                                    borderRadius: BorderRadius.circular(8),
                                    child: Image.network(
                                      'https://lh3.googleusercontent.com/aida-public/AB6AXuCw6J8pc6QX4wqooZmuOzg3QS_2YUx2Ta4oSq9-2lsE4SFDB-9S_txwIIkmombcC4qK-J_pQMw70itAMH0NbI_RL5gi_U1DI7HLQmNBW_hx6Uh2WQObO1TBCFYfeYQuf7bXHJEPTZPw0ySSFlhLUP2T8WL1qrZ2ZqcRDlQTbr-aGa_A69QZN9Ldd5vMBE0FPCmRxjO47e2D3zNy701pLLwAWtbj_z_NFCvpthA9B2Bh22qdSKlcCd6EnAt1LHvHdiWETrgMynKykA',
                                      fit: BoxFit.cover,
                                      color: Colors.black.withValues(alpha: 0.4),
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
                              color: const Color(0xFFC3C6D7).withValues(alpha: 0.8),
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

  Widget _buildQuickActionGrid() {
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
              const _ActionCard(
                icon: Icons.compare_arrows,
                title: 'Compare Loans',
                subtitle: 'Side-by-side technical audit.',
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
                isActive: true,
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => ClauseIntelligenceScreen(
                        report: LoanAnalysisReport.mock(
                          loanId: 'lns-demo-042',
                        ),
                      ),
                    ),
                  );
                },
              ),
              _ActionCard(
                icon: Icons.security_outlined,
                title: 'Risk Report',
                subtitle: 'Compliance & fraud check.',
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const LoanAnalysisReportScreen(),
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

  Widget _buildIntelligenceHistory() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          crossAxisAlignment: CrossAxisAlignment.end,
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
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: GestureDetector(
                onTap: () {},
                child: Text(
                  'View All Intelligence',
                  style: GoogleFonts.inter(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: const Color(0xFFC3C6D7),
                  ),
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 24),
        SizedBox(
          height: 135, // Adjust based on content
          child: ListView(
            scrollDirection: Axis.horizontal,
            clipBehavior: Clip.none,
            children: const [
              _HistoryCard(
                title: 'Global Horizon Trust',
                subtitle: 'Home Equity Loan',
                riskScore: '88%',
                date: 'Oct 24, 2023',
                status: 'Analyzed',
                statusIcon: Icons.check_circle_outline,
                color: Color(0xFFFFB4AB),
              ),
              SizedBox(width: 24),
              _HistoryCard(
                title: 'Apex FinTech Corp',
                subtitle: 'Business Expansion',
                riskScore: '12%',
                date: 'Oct 22, 2023',
                status: 'Analyzed',
                statusIcon: Icons.check_circle_outline,
                color: Color(0xFFC3C6D7),
              ),
              SizedBox(width: 24),
              _HistoryCard(
                title: 'Stellar Credit Union',
                subtitle: 'Personal Line',
                riskScore: '45%',
                date: 'Oct 19, 2023',
                status: 'Verifying',
                statusIcon: Icons.sync,
                color: Color(0xFFDBC3A8),
              ),
            ],
          ),
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
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
                  image: const DecorationImage(
                    image: NetworkImage(
                      'https://lh3.googleusercontent.com/aida-public/AB6AXuA61fGi0g5PlD1-3yeoANDNZzNKyOC8ji3lBH58C_NyHNcnpD1HXCCoriUKDuvjwUyNOGlhi4QvZllMJwFvrputZroFTtmyDkRmkviJD-Nff4ZZ7YKxJHEnBT9Y9DWnrZSkj48WoncEPiQUWOxnbfKrOK78PsUr-zFpazYDyEZznGc_c3bMsRk8VZ5tXs809bA9vxbDlePThlz6pcUnBMOB0DWP_j6iad-Pk3Kyj1b_iOzG84H7Gyemxnl7jkMsYewgIZeTg7vTgA',
                    ),
                    fit: BoxFit.cover,
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
  const _BottomNavBar({this.onAnalyseTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
        borderRadius: BorderRadius.circular(9999),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            width: MediaQuery.of(context).size.width * 0.9,
            constraints: const BoxConstraints(maxWidth: 512), // max-w-lg
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            decoration: BoxDecoration(
              color: const Color(0xFF201F20)
                  .withValues(alpha: 0.6), // surface-container/60
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
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ClauseIntelligenceScreen(
                          report: LoanAnalysisReport.mock(
                            loanId: 'lns-demo-042',
                          ),
                        ),
                      ),
                    );
                  },
                  child: const _NavBarItem(
                      icon: Icons.smart_toy_outlined, label: 'AI Assistant'),
                ),
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

  const _NavBarItem({
    required this.icon,
    required this.label,
    this.isSelected = false,
  });

  @override
  Widget build(BuildContext context) {
    final color = isSelected
        ? const Color(0xFFC3C6D7)
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
      width: 320,
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
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
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
