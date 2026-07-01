import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:loansense_ai/core/navigation/app_routes.dart';
import 'package:loansense_ai/core/theme.dart';
import 'package:loansense_ai/ui/screens/auth_screen.dart';
import 'package:loansense_ai/ui/screens/home_dashboard_screen.dart';
import 'package:loansense_ai/ui/screens/onboarding_screen.dart';
import 'package:loansense_ai/ui/screens/onboarding_ai_screen.dart';
import 'package:loansense_ai/ui/screens/onboarding_trust_screen.dart';
import 'package:loansense_ai/ui/screens/loan_comparison_screen.dart';
import 'package:loansense_ai/ui/screens/profile_settings_screen.dart';
import 'package:loansense_ai/ui/screens/upload_ai_scan_screen.dart';
import 'package:loansense_ai/ui/screens/splash_screen.dart';
import 'package:loansense_ai/ui/screens/scan_screen.dart';

const _kOnboardingKey = 'hasCompletedOnboarding';

void main() {
  runApp(
    const ProviderScope(
      child: LoanSenseApp(),
    ),
  );
}

class LoanSenseApp extends StatefulWidget {
  const LoanSenseApp({super.key});

  @override
  State<LoanSenseApp> createState() => _LoanSenseAppState();
}

class _LoanSenseAppState extends State<LoanSenseApp> {
  /// null  → splash still running
  /// true  → returning user, skip onboarding
  /// false → first-time user, show onboarding
  bool? _hasCompletedOnboarding;

  /// Only used during first-time flow
  int _onboardingStep = 0; // 0–2: onboarding pages, 3: auth screen

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoanSense AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      routes: {
        AppRoutes.home: (_) => const HomeDashboardScreen(),
        AppRoutes.compare: (_) => const LoanComparisonScreen(),
        AppRoutes.profile: (_) => const ProfileSettingsScreen(),
        AppRoutes.scan: (_) => const ScanScreen(),
      },
      home: _buildRoot(),
    );
  }

  Widget _buildRoot() {
    // Show splash while we haven't checked prefs yet
    if (_hasCompletedOnboarding == null) {
      return SplashScreen(
        onInitializationComplete: _onSplashDone,
      );
    }

    // Returning user → go straight to dashboard
    if (_hasCompletedOnboarding == true) {
      return const HomeDashboardScreen();
    }

    // First-time user → onboarding + auth flow
    return _buildOnboardingFlow();
  }

  /// Called when the splash animation finishes.
  /// Reads SharedPreferences and updates state.
  Future<void> _onSplashDone() async {
    final prefs = await SharedPreferences.getInstance();
    final completed = prefs.getBool(_kOnboardingKey) ?? false;
    if (mounted) {
      setState(() {
        _hasCompletedOnboarding = completed;
      });
    }
  }

  /// Persists the onboarding-complete flag and navigates to dashboard.
  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_kOnboardingKey, true);
    if (mounted) {
      setState(() {
        _hasCompletedOnboarding = true;
      });
    }
  }

  Widget _buildOnboardingFlow() {
    switch (_onboardingStep) {
      case 0:
        return OnboardingScreen(
          onNext: () => setState(() => _onboardingStep = 1),
        );
      case 1:
        return OnboardingAIScreen(
          onNext: () => setState(() => _onboardingStep = 2),
        );
      case 2:
        return OnboardingTrustScreen(
          onNext: () => setState(() => _onboardingStep = 3),
        );
      case 3:
        return AuthScreen(
          onGoogleSignIn: _completeOnboarding,
          onPhoneSignIn: _completeOnboarding,
        );
      default:
        return const UploadAiScanScreen(
          fileName: 'variable_term_loan_agreement.pdf',
          fileSizeMb: 2.4,
        );
    }
  }
}
