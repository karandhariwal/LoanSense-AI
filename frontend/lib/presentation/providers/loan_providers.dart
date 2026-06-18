import 'dart:io';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:loansense_ai/core/network/api_client.dart';
import 'package:loansense_ai/data/repositories/loan_repository.dart';
import 'package:loansense_ai/data/repositories/loan_assistant_repository.dart';
import 'package:loansense_ai/data/repositories/http_loan_assistant_repository.dart';
import 'package:loansense_ai/data/models/loan_analysis_report.dart';
import 'package:loansense_ai/data/models/loan_comparison_report.dart';
import 'package:loansense_ai/data/models/loan_history_item.dart';

// --- Base Networking & Repository Providers ---

final apiClientProvider = Provider<ApiClient>((ref) {
  return ApiClient();
});

final loanRepositoryProvider = Provider<LoanRepository>((ref) {
  final client = ref.watch(apiClientProvider);
  return LoanRepository(apiClient: client);
});

final loanAssistantRepositoryProvider =
    Provider<LoanAssistantRepository>((ref) {
  final repo = ref.watch(loanRepositoryProvider);
  return HttpLoanAssistantRepository(loanRepository: repo);
});

// --- Upload State & Provider ---

class UploadState {
  final bool isUploading;
  final String? loanId;
  final String? errorMessage;
  final double progress;

  UploadState({
    this.isUploading = false,
    this.loanId,
    this.errorMessage,
    this.progress = 0.0,
  });

  UploadState copyWith({
    bool? isUploading,
    String? loanId,
    String? errorMessage,
    double? progress,
  }) {
    return UploadState(
      isUploading: isUploading ?? this.isUploading,
      loanId: loanId ?? this.loanId,
      errorMessage: errorMessage ?? this.errorMessage,
      progress: progress ?? this.progress,
    );
  }
}

class UploadNotifier extends StateNotifier<UploadState> {
  final LoanRepository _repository;

  UploadNotifier(this._repository) : super(UploadState());

  void reset() {
    state = UploadState();
  }

  Future<String> upload(File file) async {
    state = UploadState(isUploading: true, progress: 0.1);
    try {
      final result = await _repository.uploadLoan(file);
      final id = result['loan_id']?.toString();
      if (id == null || id.isEmpty) {
        throw Exception('Server did not return a valid loan_id.');
      }
      state = UploadState(loanId: id, progress: 1.0);
      return id;
    } catch (e) {
      state = UploadState(errorMessage: e.toString());
      rethrow;
    }
  }
}

final uploadProvider =
    StateNotifierProvider<UploadNotifier, UploadState>((ref) {
  final repo = ref.watch(loanRepositoryProvider);
  return UploadNotifier(repo);
});

// --- Analysis Fetch Provider ---

final analysisProvider =
    FutureProvider.family<LoanAnalysisReport, String>((ref, loanId) async {
  final repo = ref.watch(loanRepositoryProvider);
  return repo.fetchAnalysis(loanId);
});

final loanHistoryProvider = FutureProvider<List<LoanHistoryItem>>((ref) async {
  final repo = ref.watch(loanRepositoryProvider);
  return repo.fetchLoanHistory();
});

// --- Comparison State & Provider ---

class ComparisonState {
  final bool isComparing;
  final LoanComparisonReport? report;
  final String? errorMessage;

  ComparisonState({
    this.isComparing = false,
    this.report,
    this.errorMessage,
  });
}

class ComparisonNotifier extends StateNotifier<ComparisonState> {
  final LoanRepository _repository;

  ComparisonNotifier(this._repository) : super(ComparisonState());

  void reset() {
    state = ComparisonState();
  }

  Future<LoanComparisonReport> compare(String idA, String idB) async {
    state = ComparisonState(isComparing: true);
    try {
      final resReport = await _repository.compareLoans(idA, idB);
      state = ComparisonState(report: resReport);
      return resReport;
    } catch (e) {
      state = ComparisonState(errorMessage: e.toString());
      rethrow;
    }
  }
}

final comparisonProvider =
    StateNotifierProvider<ComparisonNotifier, ComparisonState>((ref) {
  final repo = ref.watch(loanRepositoryProvider);
  return ComparisonNotifier(repo);
});
