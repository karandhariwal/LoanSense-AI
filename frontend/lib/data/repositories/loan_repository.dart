import 'dart:io';
import 'dart:convert';
import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:path/path.dart';
import 'package:path_provider/path_provider.dart';
import 'package:loansense_ai/core/network/api_client.dart';
import 'package:loansense_ai/core/error/exceptions.dart';
import 'package:loansense_ai/data/models/loan_analysis_report.dart';
import 'package:loansense_ai/data/models/loan_comparison_report.dart';
import 'package:loansense_ai/data/models/loan_history_item.dart';
import 'package:loansense_ai/data/dto/analysis_dto.dart';
import 'package:loansense_ai/data/dto/compare_dto.dart';

class LoanRepository {
  final ApiClient _apiClient;

  LoanRepository({ApiClient? apiClient})
      : _apiClient = apiClient ?? ApiClient();

  Future<Map<String, dynamic>> uploadLoan(File file) async {
    try {
      String fileName = basename(file.path);
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(file.path, filename: fileName),
      });

      final response = await _apiClient.post<Map<String, dynamic>>(
        "/upload",
        data: formData,
      );

      if (response.data == null) {
        throw const ApiException(
            message: 'Upload response returned empty data.');
      }
      return response.data!;
    } catch (e) {
      if (e is ApiException || e is NetworkException) {
        rethrow;
      }
      throw ApiException(message: "Failed to upload loan: ${e.toString()}");
    }
  }

  Future<List<LoanHistoryItem>> fetchLoanHistory({
    String? search,
    String? riskLevel,
    String? startDate,
    String? endDate,
    String? sortBy,
    String? order,
  }) async {
    try {
      final Map<String, dynamic> queryParameters = {};
      if (search != null && search.isNotEmpty) queryParameters['search'] = search;
      if (riskLevel != null && riskLevel.isNotEmpty) queryParameters['risk_level'] = riskLevel;
      if (startDate != null && startDate.isNotEmpty) queryParameters['start_date'] = startDate;
      if (endDate != null && endDate.isNotEmpty) queryParameters['end_date'] = endDate;
      if (sortBy != null && sortBy.isNotEmpty) queryParameters['sort_by'] = sortBy;
      if (order != null && order.isNotEmpty) queryParameters['order'] = order;

      final response = await _apiClient.get<List<dynamic>>(
        "/loans",
        queryParameters: queryParameters,
      );
      final rawList = response.data;
      if (rawList == null) {
        throw const ApiException(
            message: 'Loan history response returned empty data.');
      }

      try {
        return rawList
            .map((item) => LoanHistoryItem.fromJson(
                Map<String, dynamic>.from(item as Map)))
            .toList(growable: false);
      } catch (e) {
        throw ParsingException('Failed to parse loan history response: $e',
            originalError: e);
      }
    } catch (e) {
      if (e is ApiException || e is NetworkException || e is ParsingException) {
        rethrow;
      }
      throw ApiException(
          message: "Failed to fetch loan history: ${e.toString()}");
    }
  }

  Future<void> deleteLoansBulk(List<String> loanIds) async {
    try {
      final response = await _apiClient.post<Map<String, dynamic>>(
        "/user/documents/bulk-delete",
        data: {
          "document_ids": loanIds,
        },
      );
      if (response.data == null) {
        throw const ApiException(message: "Bulk delete response returned empty data.");
      }
    } catch (e) {
      if (e is ApiException || e is NetworkException) {
        rethrow;
      }
      throw ApiException(message: "Failed to bulk delete loans: ${e.toString()}");
    }
  }

  /// Returns the raw DTO. `report` will be null while backend is still processing.
  Future<AnalysisResponseDto> fetchRawAnalysis(String loanId) async {
    try {
      final response =
          await _apiClient.get<Map<String, dynamic>>("/analysis/$loanId");
      if (response.data == null) {
        throw const ApiException(
            message: 'Analysis response returned empty data.');
      }
      try {
        return AnalysisResponseDto.fromJson(response.data!);
      } catch (e) {
        throw ParsingException('Failed to parse analysis response: $e',
            originalError: e);
      }
    } catch (e) {
      if (e is ApiException || e is NetworkException || e is ParsingException) {
        rethrow;
      }
      throw ApiException(message: "Failed to fetch analysis: ${e.toString()}");
    }
  }

  /// Polls GET /analysis/{loanId} every [intervalSeconds] until the backend
  /// reports COMPLETED or FAILED, then parses and returns the domain report.
  /// Throws [ApiException] on FAILED status or timeout.
  Future<LoanAnalysisReport> fetchAnalysis(
    String loanId, {
    int intervalSeconds = 5,
    int maxAttempts =
        90, // 90 × 5s = 7.5 minutes max (AI pipeline can take time)
  }) async {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final dto = await fetchRawAnalysis(loanId);

      // Compare case-insensitively: backend returns uppercase (COMPLETED, FAILED, PENDING)
      final statusUpper = dto.status.toUpperCase();

      if (statusUpper == 'COMPLETED') {
        if (dto.analysis == null) {
          throw const ApiException(
              message:
                  'Server marked analysis completed but returned no data.');
        }
        try {
          return dto.toDomain();
        } catch (e) {
          throw ParsingException('Failed to parse analysis report: $e',
              originalError: e);
        }
      }

      if (statusUpper == 'FAILED') {
        throw const ApiException(
            message:
                'The AI analysis pipeline failed on the server. Please retry.');
      }

      // Still PENDING / PROCESSING — wait before next poll
      await Future.delayed(Duration(seconds: intervalSeconds));
    }

    throw const ApiException(
        message:
            'Analysis timed out. The server is taking too long. Please retry later.');
  }

  /// Waits until both loan analyses are COMPLETED, then runs the comparison.
  /// Polls GET /analysis/{id} for each loan before calling POST /compare.
  Future<LoanComparisonReport> compareLoans(
    String idA,
    String idB, {
    int intervalSeconds = 5,
    int maxAttempts = 90, // 90 × 5s = 7.5 minutes max
  }) async {
    try {
      // Step 1: Wait for Loan A to complete analysis
      await _waitForAnalysisCompleted(idA,
          intervalSeconds: intervalSeconds, maxAttempts: maxAttempts);

      // Step 2: Wait for Loan B to complete analysis
      await _waitForAnalysisCompleted(idB,
          intervalSeconds: intervalSeconds, maxAttempts: maxAttempts);

      // Step 3: Both loans are ready — run comparison
      final response = await _apiClient.post<Map<String, dynamic>>(
        "/compare",
        data: {
          "loan_id_a": idA,
          "loan_id_b": idB,
        },
      );

      if (response.data == null) {
        throw const ApiException(
            message: 'Comparison response returned empty data.');
      }

      // Check HTTP status code — ApiClient accepts all codes, so check manually
      final statusCode = response.statusCode ?? 0;
      if (statusCode < 200 || statusCode >= 300) {
        final errData = response.data!;
        final detail = errData['detail']?.toString() ??
            errData['message']?.toString() ??
            'Comparison failed with status $statusCode';
        throw ApiException(statusCode: statusCode, message: detail);
      }

      try {
        final dto = CompareResponseDto.fromJson(response.data!);
        return dto.toDomain(idA, idB);
      } catch (e) {
        throw ParsingException('Failed to parse comparison report: $e',
            originalError: e);
      }
    } catch (e) {
      if (e is ApiException || e is NetworkException || e is ParsingException) {
        rethrow;
      }
      throw ApiException(message: "Failed to compare loans: ${e.toString()}");
    }
  }

  /// Polls GET /analysis/{loanId} until the status is COMPLETED.
  /// Throws [ApiException] if the status is FAILED or the polling times out.
  Future<void> _waitForAnalysisCompleted(
    String loanId, {
    int intervalSeconds = 5,
    int maxAttempts = 90,
  }) async {
    for (int attempt = 0; attempt < maxAttempts; attempt++) {
      final dto = await fetchRawAnalysis(loanId);
      final statusUpper = dto.status.toUpperCase();

      if (statusUpper == 'COMPLETED') return;

      if (statusUpper == 'FAILED') {
        throw ApiException(
            message:
                'The AI analysis pipeline failed for loan $loanId. Please re-upload the document and try again.');
      }

      // PENDING / PROCESSING — wait before polling again
      await Future.delayed(Duration(seconds: intervalSeconds));
    }

    throw const ApiException(
        message:
            'Analysis timed out waiting for documents to process. Please try again later.');
  }

  Future<Map<String, dynamic>> chatWithLoan(
    String loanId,
    String query, {
    List<Map<String, dynamic>>? history,
  }) async {
    try {
      // Send ChatRequest structure to the backend
      final response = await _apiClient.post<Map<String, dynamic>>(
        "/chat/$loanId",
        data: {
          "query": query,
          "history": history ?? [],
        },
      );
      if (response.data == null) {
        throw const ApiException(message: 'Chat response returned empty data.');
      }
      return response.data!;
    } catch (e) {
      if (e is ApiException || e is NetworkException) {
        rethrow;
      }
      throw ApiException(message: "Chat failed: ${e.toString()}");
    }
  }

  Future<List<dynamic>> fetchChatHistory(String loanId) async {
    try {
      final response = await _apiClient.get<List<dynamic>>("/chat/$loanId/history");
      if (response.data == null) {
        throw const ApiException(message: 'Chat history response returned empty data.');
      }
      return response.data!;
    } catch (e) {
      if (e is ApiException || e is NetworkException) {
        rethrow;
      }
      throw ApiException(message: "Failed to fetch chat history: ${e.toString()}");
    }
  }

  Stream<Map<String, dynamic>> chatWithLoanStream(
    String loanId,
    String query, {
    List<Map<String, dynamic>>? history,
  }) async* {
    try {
      final response = await _apiClient.dio.post<ResponseBody>(
        "/chat/$loanId/stream",
        data: {
          "query": query,
          "history": history ?? [],
        },
        options: Options(responseType: ResponseType.stream),
      );

      final stream = response.data?.stream;
      if (stream == null) {
        throw const ApiException(message: 'Chat stream returned empty data.');
      }

      final lineStream = stream
          .cast<List<int>>()
          .transform(utf8.decoder)
          .transform(const LineSplitter());

      await for (final line in lineStream) {
        final trimmed = line.trim();
        if (trimmed.isEmpty) continue;
        if (trimmed.startsWith("data: ")) {
          final jsonStr = trimmed.substring(6);
          try {
            final Map<String, dynamic> event = Map<String, dynamic>.from(json.decode(jsonStr) as Map);
            yield event;
          } catch (e) {
            developer.log("Failed to parse SSE event: $jsonStr, error: $e");
          }
        }
      }
    } catch (e) {
      if (e is ApiException || e is NetworkException) {
        rethrow;
      }
      throw ApiException(message: "Chat stream failed: ${e.toString()}");
    }
  }

  /// Exports a completed loan analysis as a PDF file.
  /// Downloads from GET /export/{loanId} and saves to the app's temp directory.
  /// Returns the absolute file path of the saved PDF.
  Future<String> exportLoanAsPdf(String loanId, {String? lenderName}) async {
    try {
      final response = await _apiClient.dio.get<List<int>>(
        "/export/$loanId",
        options: Options(responseType: ResponseType.bytes),
      );

      if (response.data == null || response.data!.isEmpty) {
        throw const ApiException(message: 'Export response returned empty data.');
      }

      // Save to app temp directory
      final dir = await getTemporaryDirectory();
      final slug = (lenderName ?? 'loan').replaceAll(RegExp(r'[^a-zA-Z0-9]'), '_');
      final filePath = '${dir.path}/LoanSense_${slug}_${loanId.substring(0, 8)}.pdf';
      final file = File(filePath);
      await file.writeAsBytes(response.data!);
      developer.log('PDF exported to $filePath');
      return filePath;
    } catch (e) {
      if (e is ApiException || e is NetworkException) rethrow;
      throw ApiException(message: "Export failed: ${e.toString()}");
    }
  }
}
