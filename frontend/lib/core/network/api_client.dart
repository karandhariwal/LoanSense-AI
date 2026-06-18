import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:loansense_ai/core/error/exceptions.dart';
import 'package:loansense_ai/core/config/app_config.dart';

class ApiClient {
  late final Dio _dio;

  ApiClient({String? baseUrl, List<Interceptor>? interceptors}) {
    // Use provided baseUrl, or fall back to BuildConfig API URL
    final url = baseUrl ?? BuildConfig.apiUrl;
    
    _dio = Dio(
      BaseOptions(
        baseUrl: url,
        connectTimeout: const Duration(seconds: AppConfig.connectTimeout),
        receiveTimeout: const Duration(seconds: AppConfig.receiveTimeout),
        sendTimeout: const Duration(seconds: AppConfig.sendTimeout),
        headers: {
          'Accept': 'application/json',
          'Content-Type': 'application/json',
        },
        validateStatus: (status) {
          // Accept all status codes and handle them in the app
          return true;
        },
      ),
    );

    // Add logging interceptor by default (only in development)
    if (AppConfig.enableApiLogging || BuildConfig.isDevelopment) {
      _dio.interceptors.add(
        InterceptorsWrapper(
          onRequest: (options, handler) {
            developer.log('API Request: [${options.method}] ${options.path}');
            if (options.queryParameters.isNotEmpty) {
              developer.log('Query Params: ${options.queryParameters}');
            }
            if (options.data != null) {
              if (options.data is FormData) {
                developer.log('Form Data Fields: ${(options.data as FormData).fields}');
              } else {
                developer.log('Request Body: ${options.data}');
              }
            }
            return handler.next(options);
          },
          onResponse: (response, handler) {
            developer.log('API Response: [${response.statusCode}] ${response.requestOptions.path}');
            return handler.next(response);
          },
          onError: (DioException e, handler) {
            developer.log('API Error: [${e.response?.statusCode}] ${e.message}');
            return handler.next(e);
          },
        ),
      );
    }

    if (interceptors != null) {
      _dio.interceptors.addAll(interceptors);
    }
  }

  Dio get dio => _dio;

  Future<Response<T>> get<T>(
    String path, {
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.get<T>(
        path,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'An unexpected error occurred: $e');
    }
  }

  Future<Response<T>> post<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
    void Function(int, int)? onSendProgress,
  }) async {
    try {
      return await _dio.post<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
        onSendProgress: onSendProgress,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'An unexpected error occurred: $e');
    }
  }

  Future<Response<T>> patch<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.patch<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'An unexpected error occurred: $e');
    }
  }

  Future<Response<T>> delete<T>(
    String path, {
    dynamic data,
    Map<String, dynamic>? queryParameters,
    Options? options,
    CancelToken? cancelToken,
  }) async {
    try {
      return await _dio.delete<T>(
        path,
        data: data,
        queryParameters: queryParameters,
        options: options,
        cancelToken: cancelToken,
      );
    } on DioException catch (e) {
      throw _handleDioError(e);
    } catch (e) {
      throw ApiException(message: 'An unexpected error occurred: $e');
    }
  }

  Exception _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return NetworkException(
        'Connection timeout or network failure. Verify the backend is running and the app is using the correct host. For a real Android device over USB, run adb reverse tcp:8000 tcp:8000. For an Android emulator, use 10.0.2.2:8000.',
        originalError: e,
      );
    }

    final response = e.response;
    if (response != null) {
      final statusCode = response.statusCode;
      String message = 'Server error occurred.';
      
      if (response.data is Map<String, dynamic>) {
        final data = response.data as Map<String, dynamic>;
        message = data['detail']?.toString() ?? data['message']?.toString() ?? message;
      } else if (response.data is String) {
        message = response.data as String;
      }

      return ApiException(
        statusCode: statusCode,
        message: message,
        responseData: response.data,
      );
    }

    return ApiException(message: e.message ?? 'Unknown API error');
  }
}
