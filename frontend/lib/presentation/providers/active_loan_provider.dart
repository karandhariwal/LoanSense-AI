import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loansense_ai/data/models/loan_analysis_report.dart';

/// Single source of truth for the currently active (analysed) loan.
///
/// Set to a non-null [LoanAnalysisReport] after a successful upload + analysis
/// pipeline completes in [UploadAiScanScreen]. Reset to null if the user
/// navigates away from any active loan context.
///
/// All AI-gated screens (AI Assistant, Clause Intelligence, Comparison) must
/// check this provider before navigating — if null, show an upload prompt
/// instead of proceeding with a fake loan ID.
final activeLoanProvider = StateProvider<LoanAnalysisReport?>((ref) => null);
