import 'dart:io';
import 'package:dio/dio.dart';
import 'package:path/path.dart';

class LoanRepository {
  final Dio _dio = Dio(BaseOptions(baseUrl: 'http://localhost:8000'));

  Future<Map<String, dynamic>> uploadLoan(File file) async {
    try {
      String fileName = basename(file.path);
      FormData formData = FormData.fromMap({
        "file": await MultipartFile.fromFile(file.path, filename: fileName),
      });

      Response response = await _dio.post("/upload", data: formData);
      return response.data;
    } catch (e) {
      throw Exception("Failed to upload loan: ${e.toString()}");
    }
  }

  Future<Map<String, dynamic>> chatWithLoan(String loanId, String query) async {
    try {
      Response response = await _dio.post(
        "/chat/$loanId",
        queryParameters: {"query": query},
      );
      return response.data;
    } catch (e) {
      throw Exception("Chat failed: ${e.toString()}");
    }
  }
}
