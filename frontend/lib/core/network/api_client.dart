import 'dart:developer' as developer;
import 'package:dio/dio.dart';
import 'package:loansense_ai/core/error/exceptions.dart';
import 'package:loansense_ai/core/config/app_config.dart';

class ApiClient {
  late final Dio _dio;
  late final List<String> _candidateBaseUrls;
  bool _baseUrlResolved = false;

  ApiClient({String? baseUrl, List<Interceptor>? interceptors}) {
    _candidateBaseUrls = List.unmodifiable(
      baseUrl != null ? [baseUrl] : BuildConfig.apiUrls,
    );
    final url = _candidateBaseUrls.first;
    
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

    developer.log('API base URL candidates: $_candidateBaseUrls');

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
      await _ensureReachableBaseUrl();
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
      await _ensureReachableBaseUrl();
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
      await _ensureReachableBaseUrl();
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
      await _ensureReachableBaseUrl();
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

  Future<void> _ensureReachableBaseUrl() async {
    if (_baseUrlResolved || _candidateBaseUrls.length <= 1) {
      _baseUrlResolved = true;
      return;
    }

    for (final candidate in _candidateBaseUrls) {
      final reachable = await _isBaseUrlReachable(candidate);
      if (!reachable) {
        continue;
      }

      if (_dio.options.baseUrl != candidate) {
        developer.log(
          'Switching API base URL from ${_dio.options.baseUrl} to $candidate',
        );
        _dio.options.baseUrl = candidate;
      }
      _baseUrlResolved = true;
      return;
    }

    // All probes failed — fall back to 127.0.0.1 (correct for adb reverse) and
    // mark resolved so we don't probe again on every subsequent request.
    // The actual request will surface a proper connection error to the user.
    const fallback = 'http://127.0.0.1:8000';
    developer.log(
      'All URL probes failed. Falling back to $fallback. '
      'If on a physical device, ensure adb reverse tcp:8000 tcp:8000 is active.',
    );
    _dio.options.baseUrl = fallback;
    _baseUrlResolved = true;
  }

  Future<bool> _isBaseUrlReachable(String baseUrl) async {
    final probe = Dio(
      BaseOptions(
        baseUrl: baseUrl,
        connectTimeout: const Duration(seconds: 4),
        receiveTimeout: const Duration(seconds: 4),
        sendTimeout: const Duration(seconds: 4),
        validateStatus: (status) => status != null && status < 500,
      ),
    );

    try {
      final response = await probe.get<dynamic>('/');
      return response.statusCode != null && response.statusCode! < 500;
    } on DioException catch (e) {
      developer.log('API probe failed for $baseUrl: ${e.message}');
      return false;
    } finally {
      probe.close(force: true);
    }
  }

  Exception _handleDioError(DioException e) {
    if (e.type == DioExceptionType.connectionTimeout ||
        e.type == DioExceptionType.sendTimeout ||
        e.type == DioExceptionType.receiveTimeout ||
        e.type == DioExceptionType.connectionError) {
      return NetworkException(
        'Connection timeout or network failure. Verify the backend is running. The app tried these local hosts: ${_candidateBaseUrls.join(', ')}. For a real Android device over USB, run adb reverse tcp:8000 tcp:8000. You can also set --dart-define=API_BASE_URL=http://YOUR_PC_LOCAL_IP:8000.',
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
