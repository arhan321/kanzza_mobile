class ApiResponse {
  final bool success;
  final String message;
  final dynamic data;
  final Map<String, dynamic>? errors;
  final int statusCode;

  const ApiResponse({
    required this.success,
    required this.message,
    required this.data,
    required this.statusCode,
    this.errors,
  });

  factory ApiResponse.fromJson(
    Map<String, dynamic> json, {
    required int statusCode,
  }) {
    return ApiResponse(
      success: json['success'] == true,
      message: json['message']?.toString() ?? '',
      data: json['data'],
      errors: _parseErrors(json['errors']),
      statusCode: statusCode,
    );
  }

  static Map<String, dynamic>? _parseErrors(dynamic value) {
    if (value is Map<String, dynamic>) {
      return value;
    }

    if (value is Map) {
      return Map<String, dynamic>.from(value);
    }

    return null;
  }

  Map<String, dynamic>? get dataAsMap {
    if (data is Map<String, dynamic>) {
      return data as Map<String, dynamic>;
    }

    if (data is Map) {
      return Map<String, dynamic>.from(data as Map);
    }

    return null;
  }

  List<dynamic> get dataAsList {
    if (data is List) {
      return data as List<dynamic>;
    }

    return const <dynamic>[];
  }
}
