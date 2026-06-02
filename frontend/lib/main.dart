import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loansense_ai/core/theme.dart';
import 'package:loansense_ai/ui/screens/auth_screen.dart';
import 'package:loansense_ai/ui/screens/onboarding_screen.dart';
import 'package:loansense_ai/ui/screens/onboarding_ai_screen.dart';
import 'package:loansense_ai/ui/screens/onboarding_trust_screen.dart';
import 'package:loansense_ai/ui/screens/home_dashboard_screen.dart';
import 'package:loansense_ai/ui/screens/upload_ai_scan_screen.dart';
import 'package:loansense_ai/ui/screens/splash_screen.dart';

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
  bool _isInitialized = false;
  int _onboardingStep = 0; // 0: Risk Discovery, 1: AI Analysis, 2: Trust & Security, 3: Complete

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'LoanSense AI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.darkTheme,
      home: !_isInitialized
          ? SplashScreen(
              onInitializationComplete: () {
                setState(() {
                  _isInitialized = true;
                });
              },
            )
          : _buildCurrentScreen(),
    );
  }

  Widget _buildCurrentScreen() {
    if (_onboardingStep == 0) {
      return OnboardingScreen(
        onNext: () {
          setState(() {
            _onboardingStep = 1;
          });
        },
      );
    } else if (_onboardingStep == 1) {
      return OnboardingAIScreen(
        onNext: () {
          setState(() {
            _onboardingStep = 2;
          });
        },
      );
    } else if (_onboardingStep == 2) {
      return OnboardingTrustScreen(
        onNext: () {
          setState(() {
            _onboardingStep = 3;
          });
        },
      );
    } else if (_onboardingStep == 3) {
      return AuthScreen(
        onGoogleSignIn: () {
          setState(() {
            _onboardingStep = 4;
          });
        },
        onPhoneSignIn: () {
          setState(() {
            _onboardingStep = 4;
          });
        },
      );
    } else if (_onboardingStep == 4) {
      return const HomeDashboardScreen();
    } else {
      return const UploadAiScanScreen(
        fileName: 'variable_term_loan_agreement.pdf',
        fileSizeMb: 2.4,
      );
    }
  }
}
