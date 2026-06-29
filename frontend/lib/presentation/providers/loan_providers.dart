import 'dart:io';
import 'dart:async';
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

class LoanHistoryFilters {
  final String search;
  final String? riskLevel; // 'safe', 'moderate', 'dangerous' or null
  final DateTime? startDate;
  final DateTime? endDate;
  final String sortBy; // 'upload_date', 'risk_score', 'lender_name'
  final String order; // 'asc', 'desc'

  const LoanHistoryFilters({
    this.search = '',
    this.riskLevel,
    this.startDate,
    this.endDate,
    this.sortBy = 'upload_date',
    this.order = 'desc',
  });

  LoanHistoryFilters copyWith({
    String? search,
    String? riskLevel,
    bool clearRiskLevel = false,
    DateTime? startDate,
    bool clearStartDate = false,
    DateTime? endDate,
    bool clearEndDate = false,
    String? sortBy,
    String? order,
  }) {
    return LoanHistoryFilters(
      search: search ?? this.search,
      riskLevel: clearRiskLevel ? null : (riskLevel ?? this.riskLevel),
      startDate: clearStartDate ? null : (startDate ?? this.startDate),
      endDate: clearEndDate ? null : (endDate ?? this.endDate),
      sortBy: sortBy ?? this.sortBy,
      order: order ?? this.order,
    );
  }
}

final loanHistoryFiltersProvider = StateProvider<LoanHistoryFilters>((ref) {
  return const LoanHistoryFilters();
});

final loanHistorySelectionModeProvider = StateProvider<bool>((ref) {
  return false;
});

final loanHistorySelectionProvider = StateProvider<Set<String>>((ref) {
  return {};
});

final loanHistoryProvider = FutureProvider<List<LoanHistoryItem>>((ref) async {
  final repo = ref.watch(loanRepositoryProvider);
  final filters = ref.watch(loanHistoryFiltersProvider);

  String? startDateStr;
  if (filters.startDate != null) {
    startDateStr = "${filters.startDate!.year}-${filters.startDate!.month.toString().padLeft(2, '0')}-${filters.startDate!.day.toString().padLeft(2, '0')}";
  }
  String? endDateStr;
  if (filters.endDate != null) {
    endDateStr = "${filters.endDate!.year}-${filters.endDate!.month.toString().padLeft(2, '0')}-${filters.endDate!.day.toString().padLeft(2, '0')}";
  }

  return repo.fetchLoanHistory(
    search: filters.search.isEmpty ? null : filters.search,
    riskLevel: filters.riskLevel,
    startDate: startDateStr,
    endDate: endDateStr,
    sortBy: filters.sortBy,
    order: filters.order,
  );
});

// --- Comparison State & Provider ---

class ComparisonState {
  final bool isComparing;
  final String? loadingMessage;
  final LoanComparisonReport? report;
  final String? errorMessage;

  ComparisonState({
    this.isComparing = false,
    this.loadingMessage,
    this.report,
    this.errorMessage,
  });
}

class ComparisonNotifier extends StateNotifier<ComparisonState> {
  final LoanRepository _repository;
  Timer? _loadingTimer;

  ComparisonNotifier(this._repository) : super(ComparisonState());

  void reset() {
    _loadingTimer?.cancel();
    state = ComparisonState();
  }

  @override
  void dispose() {
    _loadingTimer?.cancel();
    super.dispose();
  }

  Future<LoanComparisonReport> compare(String idA, String idB) async {
    _loadingTimer?.cancel();
    final messages = [
      "Uploading complete — processing documents...",
      "Waiting for Loan A analysis to complete...",
      "Waiting for Loan B analysis to complete...",
      "Both loans ready — comparing agreements...",
      "Analysing hidden clauses & penalty terms...",
      "Calculating total borrowing cost...",
      "Generating AI recommendation...",
    ];
    int messageIndex = 0;
    
    state = ComparisonState(
      isComparing: true,
      loadingMessage: messages[0],
    );

    _loadingTimer = Timer.periodic(const Duration(seconds: 5), (timer) {
      if (messageIndex < messages.length - 1) {
        messageIndex++;
        if (state.isComparing) {
          state = ComparisonState(
            isComparing: true,
            loadingMessage: messages[messageIndex],
          );
        }
      }
    });

    try {
      final resReport = await _repository.compareLoans(idA, idB);
      _loadingTimer?.cancel();
      state = ComparisonState(report: resReport);
      return resReport;
    } catch (e) {
      _loadingTimer?.cancel();
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

// --- Export State & Provider ---

class ExportState {
  final bool isExporting;
  final String? filePath;
  final String? errorMessage;

  const ExportState({
    this.isExporting = false,
    this.filePath,
    this.errorMessage,
  });

  ExportState copyWith({
    bool? isExporting,
    String? filePath,
    bool clearFilePath = false,
    String? errorMessage,
    bool clearError = false,
  }) {
    return ExportState(
      isExporting: isExporting ?? this.isExporting,
      filePath: clearFilePath ? null : (filePath ?? this.filePath),
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
    );
  }
}

class ExportNotifier extends StateNotifier<ExportState> {
  final LoanRepository _repository;

  ExportNotifier(this._repository) : super(const ExportState());

  void reset() => state = const ExportState();

  Future<String?> exportPdf(String loanId, {String? lenderName}) async {
    state = const ExportState(isExporting: true);
    try {
      final path = await _repository.exportLoanAsPdf(loanId, lenderName: lenderName);
      state = ExportState(filePath: path);
      return path;
    } catch (e) {
      state = ExportState(errorMessage: e.toString());
      return null;
    }
  }
}

final exportProvider =
    StateNotifierProvider.autoDispose<ExportNotifier, ExportState>((ref) {
  final repo = ref.watch(loanRepositoryProvider);
  return ExportNotifier(repo);
});

