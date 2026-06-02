class NetworkException implements Exception {
  final String message;
  final dynamic originalError;

  const NetworkException(this.message, {this.originalError});

  @override
  String toString() => 'NetworkException: $message';
}

class ApiException implements Exception {
  final int? statusCode;
  final String message;
  final dynamic responseData;

  const ApiException({
    required this.message,
    this.statusCode,
    this.responseData,
  });

  @override
  String toString() => 'ApiException (status: $statusCode): $message';
}

class ParsingException implements Exception {
  final String message;
  final dynamic originalError;

  const ParsingException(this.message, {this.originalError});

  @override
  String toString() => 'ParsingException: $message';
}
