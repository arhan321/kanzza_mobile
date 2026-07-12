class ApiException implements Exception {
  final String message;
  final int? statusCode;
  final Map<String, dynamic>? errors;

  const ApiException({
    required this.message,
    this.statusCode,
    this.errors,
  });

  String get firstValidationError {
    final validationErrors = errors;

    if (validationErrors == null || validationErrors.isEmpty) {
      return message;
    }

    for (final value in validationErrors.values) {
      if (value is List && value.isNotEmpty) {
        return value.first.toString();
      }

      if (value != null && value.toString().trim().isNotEmpty) {
        return value.toString();
      }
    }

    return message;
  }

  bool get isUnauthorized => statusCode == 401;

  bool get isForbidden => statusCode == 403;

  bool get isNotFound => statusCode == 404;

  bool get isValidationError => statusCode == 422;

  @override
  String toString() {
    return 'ApiException('
        'message: $message, '
        'statusCode: $statusCode, '
        'errors: $errors'
        ')';
  }
}
