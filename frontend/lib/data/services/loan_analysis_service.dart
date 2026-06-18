/// Service to manage loan analysis data from real-time sources
/// Replaces hardcoded mock data with actual backend API calls

import 'dart:developer' as developer;
import 'package:loansense_ai/data/repositories/loan_repository.dart';
import 'package:loansense_ai/data/models/loan_analysis_report.dart';
import 'package:loansense_ai/core/config/app_config.dart';

class LoanAnalysisService {
  final LoanRepository _loanRepository;
  
  LoanAnalysisService({LoanRepository? loanRepository}) 
    : _loanRepository = loanRepository ?? LoanRepository();

  /// Fetch real loan analysis from backend API
  /// This replaces all .mock() calls with actual data
  Future<LoanAnalysisReport> getAnalysis(String loanId) async {
    if (BuildConfig.isDevelopment) {
      developer.log('📊 Fetching real analysis for loan: $loanId');
    }
    
    try {
      return await _loanRepository.fetchAnalysis(loanId);
    } catch (e) {
      if (BuildConfig.isDevelopment) {
        developer.log('⚠️ Failed to fetch analysis: $e');
      }
      rethrow;
    }
  }

  /// Fetch with automatic polling (waits for backend processing)
  /// Backend analysis takes time, so this polls until complete
  Future<LoanAnalysisReport> getAnalysisWithPolling({
    required String loanId,
    int intervalSeconds = 2,
    int maxAttempts = 150, // 5 minutes max
  }) async {
    return await _loanRepository.fetchAnalysis(
      loanId,
      intervalSeconds: intervalSeconds,
      maxAttempts: maxAttempts,
    );
  }

  /// Get mock data ONLY for development/testing when backend is unavailable
  /// Use this sparingly - prefer real data when possible
  @Deprecated('Only use for testing when backend is down')
  LoanAnalysisReport getMockAnalysis(String loanId, {String? fileName, double fileSizeMb = 2.4}) {
    if (!BuildConfig.isDevelopment) {
      throw Exception('Mock data is only available in development mode');
    }
    
    return LoanAnalysisReport.generateMockReport(
      fileName: fileName ?? "variable_term_loan_agreement.pdf",
      fileSizeMb: fileSizeMb,
      loanId: loanId,
    );
  }
}
