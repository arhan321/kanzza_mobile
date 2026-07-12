import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../config/app_config.dart';
import '../storage/auth_storage.dart';
import 'api_exception.dart';
import 'api_response.dart';

class ApiClient {
  ApiClient._({
    http.Client? client,
    AuthStorage? authStorage,
  })  : _client = client ?? http.Client(),
        _authStorage = authStorage ?? AuthStorage.instance;

  static final ApiClient instance = ApiClient._();

  final http.Client _client;
  final AuthStorage _authStorage;

  Future<ApiResponse> get(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return _send(
      method: 'GET',
      endpoint: endpoint,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  Future<ApiResponse> post(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return _send(
      method: 'POST',
      endpoint: endpoint,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  Future<ApiResponse> put(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return _send(
      method: 'PUT',
      endpoint: endpoint,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  Future<ApiResponse> patch(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return _send(
      method: 'PATCH',
      endpoint: endpoint,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  Future<ApiResponse> delete(
    String endpoint, {
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    bool requiresAuth = true,
  }) {
    return _send(
      method: 'DELETE',
      endpoint: endpoint,
      body: body,
      queryParameters: queryParameters,
      requiresAuth: requiresAuth,
    );
  }

  Future<ApiResponse> postMultipart(
    String endpoint, {
    required Map<String, dynamic> fields,
    Map<String, String>? filePaths,
    bool requiresAuth = true,
  }) async {
    final uri = _buildUri(endpoint);

    try {
      final request = http.MultipartRequest('POST', uri);
      request.headers.addAll(
        await _buildHeaders(
          requiresAuth: requiresAuth,
          includeContentType: false,
        ),
      );

      for (final entry in fields.entries) {
        final value = entry.value;

        if (value == null) {
          continue;
        }

        request.fields[entry.key] = _stringifyMultipartValue(value);
      }

      if (filePaths != null) {
        for (final entry in filePaths.entries) {
          final path = entry.value.trim();

          if (path.isEmpty) {
            continue;
          }

          request.files.add(
            await http.MultipartFile.fromPath(
              entry.key,
              path,
            ),
          );
        }
      }

      _debugRequest('POST MULTIPART', uri);

      final streamedResponse = await request.send().timeout(
            AppConfig.receiveTimeout,
          );

      final response = await http.Response.fromStream(streamedResponse);

      _debugResponse(
        method: 'POST MULTIPART',
        uri: uri,
        statusCode: response.statusCode,
      );

      return _parseResponse(response);
    } on TimeoutException {
      throw const ApiException(
        message: 'Koneksi ke server terlalu lama. Silakan coba lagi.',
      );
    } on SocketException {
      throw const ApiException(
        message: 'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    } on http.ClientException {
      throw const ApiException(
        message: 'Terjadi gangguan ketika menghubungi server.',
      );
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(
        message: 'Terjadi kesalahan: $error',
      );
    }
  }

  Future<ApiResponse> _send({
    required String method,
    required String endpoint,
    Map<String, dynamic>? body,
    Map<String, dynamic>? queryParameters,
    required bool requiresAuth,
  }) async {
    final uri = _buildUri(
      endpoint,
      queryParameters: queryParameters,
    );

    try {
      final headers = await _buildHeaders(
        requiresAuth: requiresAuth,
      );

      final encodedBody = body == null ? null : jsonEncode(body);

      _debugRequest(method, uri);

      late final http.Response response;

      switch (method) {
        case 'GET':
          response = await _client
              .get(
                uri,
                headers: headers,
              )
              .timeout(AppConfig.receiveTimeout);
          break;

        case 'POST':
          response = await _client
              .post(
                uri,
                headers: headers,
                body: encodedBody,
              )
              .timeout(AppConfig.receiveTimeout);
          break;

        case 'PUT':
          response = await _client
              .put(
                uri,
                headers: headers,
                body: encodedBody,
              )
              .timeout(AppConfig.receiveTimeout);
          break;

        case 'PATCH':
          response = await _client
              .patch(
                uri,
                headers: headers,
                body: encodedBody,
              )
              .timeout(AppConfig.receiveTimeout);
          break;

        case 'DELETE':
          response = await _client
              .delete(
                uri,
                headers: headers,
                body: encodedBody,
              )
              .timeout(AppConfig.receiveTimeout);
          break;

        default:
          throw ApiException(
            message: 'HTTP method $method belum didukung.',
          );
      }

      _debugResponse(
        method: method,
        uri: uri,
        statusCode: response.statusCode,
      );

      return _parseResponse(response);
    } on TimeoutException {
      throw const ApiException(
        message: 'Koneksi ke server terlalu lama. Silakan coba lagi.',
      );
    } on SocketException {
      throw const ApiException(
        message: 'Tidak dapat terhubung ke server. Periksa koneksi internet.',
      );
    } on FormatException {
      throw const ApiException(
        message: 'Respons server tidak dapat dibaca.',
      );
    } on http.ClientException {
      throw const ApiException(
        message: 'Terjadi gangguan ketika menghubungi server.',
      );
    } on ApiException {
      rethrow;
    } catch (error) {
      throw ApiException(
        message: 'Terjadi kesalahan: $error',
      );
    }
  }

  Uri _buildUri(
    String endpoint, {
    Map<String, dynamic>? queryParameters,
  }) {
    final normalizedBaseUrl = AppConfig.baseUrl.endsWith('/')
        ? AppConfig.baseUrl.substring(0, AppConfig.baseUrl.length - 1)
        : AppConfig.baseUrl;

    final normalizedEndpoint = endpoint.startsWith('/')
        ? endpoint
        : '/$endpoint';

    final uri = Uri.parse('$normalizedBaseUrl$normalizedEndpoint');

    if (queryParameters == null || queryParameters.isEmpty) {
      return uri;
    }

    final cleanedQuery = <String, String>{};

    for (final entry in queryParameters.entries) {
      final value = entry.value;

      if (value == null) {
        continue;
      }

      final stringValue = value.toString();

      if (stringValue.trim().isEmpty) {
        continue;
      }

      cleanedQuery[entry.key] = stringValue;
    }

    return uri.replace(
      queryParameters: cleanedQuery.isEmpty ? null : cleanedQuery,
    );
  }

  Future<Map<String, String>> _buildHeaders({
    required bool requiresAuth,
    bool includeContentType = true,
  }) async {
    final headers = <String, String>{
      'Accept': 'application/json',
    };

    if (includeContentType) {
      headers['Content-Type'] = 'application/json';
    }

    if (requiresAuth) {
      final token = await _authStorage.getToken();

      if (token != null && token.trim().isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  ApiResponse _parseResponse(http.Response response) {
    Map<String, dynamic> responseBody = <String, dynamic>{};

    if (response.body.trim().isNotEmpty) {
      final decoded = jsonDecode(response.body);

      if (decoded is Map<String, dynamic>) {
        responseBody = decoded;
      } else if (decoded is Map) {
        responseBody = Map<String, dynamic>.from(decoded);
      } else {
        responseBody = <String, dynamic>{
          'success': response.statusCode >= 200 && response.statusCode < 300,
          'message': '',
          'data': decoded,
        };
      }
    }

    final apiResponse = ApiResponse.fromJson(
      responseBody,
      statusCode: response.statusCode,
    );

    final isSuccessStatus =
        response.statusCode >= 200 && response.statusCode < 300;

    if (isSuccessStatus) {
      return apiResponse;
    }

    throw ApiException(
      message: apiResponse.message.isNotEmpty
          ? apiResponse.message
          : _defaultErrorMessage(response.statusCode),
      statusCode: response.statusCode,
      errors: apiResponse.errors,
    );
  }

  String _defaultErrorMessage(int statusCode) {
    switch (statusCode) {
      case 400:
        return 'Permintaan tidak valid.';
      case 401:
        return 'Sesi login tidak valid atau telah berakhir.';
      case 403:
        return 'Anda tidak memiliki akses untuk tindakan ini.';
      case 404:
        return 'Data atau endpoint tidak ditemukan.';
      case 409:
        return 'Data mengalami konflik dengan data yang sudah ada.';
      case 422:
        return 'Data yang dikirim belum valid.';
      case 429:
        return 'Terlalu banyak permintaan. Silakan tunggu sebentar.';
      case 500:
        return 'Terjadi kesalahan pada server.';
      case 502:
      case 503:
      case 504:
        return 'Server sedang tidak tersedia. Silakan coba lagi.';
      default:
        return 'Permintaan gagal dengan status $statusCode.';
    }
  }

  String _stringifyMultipartValue(dynamic value) {
    if (value is bool) {
      return value ? '1' : '0';
    }

    if (value is List || value is Map) {
      return jsonEncode(value);
    }

    return value.toString();
  }

  void _debugRequest(String method, Uri uri) {
    if (kDebugMode) {
      debugPrint('[API] $method $uri');
    }
  }

  void _debugResponse({
    required String method,
    required Uri uri,
    required int statusCode,
  }) {
    if (kDebugMode) {
      debugPrint('[API] $method $uri -> $statusCode');
    }
  }

  void close() {
    _client.close();
  }
}
