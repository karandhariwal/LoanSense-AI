import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart';
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

  Future<List<LoanHistoryItem>> fetchLoanHistory() async {
    try {
      final response = await _apiClient.get<List<dynamic>>("/loans");
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

  Future<LoanComparisonReport> compareLoans(String idA, String idB) async {
    try {
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
}
