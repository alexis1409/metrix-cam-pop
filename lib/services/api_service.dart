import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';
import '../config/api_config.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, {this.statusCode});

  @override
  String toString() => message;

  /// Returns true if this is an authentication error (401 or 403)
  bool get isAuthError => statusCode == 401 || statusCode == 403;
}

/// Specific exception for authentication errors
class AuthenticationException extends ApiException {
  AuthenticationException([String message = 'Sesión expirada. Inicia sesión de nuevo.'])
      : super(message, statusCode: 401);
}

class ApiService {
  String? _token;

  void setToken(String? token) {
    _token = token;
    debugPrint('🔑 [ApiService] Token ${token != null ? "establecido" : "eliminado"}');
  }

  /// Returns true if a token is set
  bool get hasToken => _token != null && _token!.isNotEmpty;

  Map<String, String> get _headers {
    final headers = {
      'Content-Type': 'application/json',
    };
    if (_token != null) {
      headers['Authorization'] = 'Bearer $_token';
    }
    return headers;
  }

  Future<Map<String, dynamic>> post(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.post(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: _headers,
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexión: $e');
    }
  }

  Future<Map<String, dynamic>> get(String endpoint) async {
    try {
      final response = await http.get(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: _headers,
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexión: $e');
    }
  }

  Future<List<dynamic>> getList(String endpoint) async {
    try {
      final url = '${ApiConfig.baseUrl}$endpoint';
      debugPrint('📡 [ApiService] GET List: $url');
      debugPrint('📡 [ApiService] Headers: ${_headers.keys.join(', ')}');

      final response = await http.get(
        Uri.parse(url),
        headers: _headers,
      );

      debugPrint('📡 [ApiService] Response status: ${response.statusCode}');

      final body = jsonDecode(response.body);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        final result = body is List ? body : (body['data'] ?? []);
        debugPrint('📡 [ApiService] Success: ${result.length} items');
        return result;
      }

      final message = body['message'] ?? 'Error desconocido';
      debugPrint('❌ [ApiService] Error ${response.statusCode}: $message');

      // Check for authentication errors
      if (response.statusCode == 401 || response.statusCode == 403) {
        throw AuthenticationException();
      }

      throw ApiException(
        message is List ? message.join(', ') : message.toString(),
        statusCode: response.statusCode,
      );
    } catch (e) {
      if (e is ApiException) rethrow;
      debugPrint('❌ [ApiService] Connection error: $e');
      throw ApiException('Error de conexión: $e');
    }
  }

  Future<Map<String, dynamic>> patch(
    String endpoint,
    Map<String, dynamic> body,
  ) async {
    try {
      final response = await http.patch(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: _headers,
        body: jsonEncode(body),
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexión: $e');
    }
  }

  Future<Map<String, dynamic>> delete(String endpoint) async {
    try {
      final response = await http.delete(
        Uri.parse('${ApiConfig.baseUrl}$endpoint'),
        headers: _headers,
      );

      return _handleResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexión: $e');
    }
  }

  Future<Map<String, dynamic>> uploadMultipleFiles(
    String endpoint,
    List<File> files, {
    String fieldName = 'files',
  }) async {
    try {
      final uri = Uri.parse('${ApiConfig.baseUrl}$endpoint');
      final request = http.MultipartRequest('POST', uri);

      if (_token != null) {
        request.headers['Authorization'] = 'Bearer $_token';
      }

      for (final file in files) {
        final fileName = file.path.split('/').last;
        final extension = fileName.split('.').last.toLowerCase();

        // Determine content type based on file extension
        MediaType? contentType;
        switch (extension) {
          case 'jpg':
          case 'jpeg':
            contentType = MediaType('image', 'jpeg');
            break;
          case 'png':
            contentType = MediaType('image', 'png');
            break;
          case 'gif':
            contentType = MediaType('image', 'gif');
            break;
          case 'webp':
            contentType = MediaType('image', 'webp');
            break;
          default:
            contentType = MediaType('image', 'jpeg'); // Default to JPEG
        }

        debugPrint('📤 [ApiService] Uploading file: $fileName with contentType: $contentType');

        final multipartFile = await http.MultipartFile.fromPath(
          fieldName,
          file.path,
          filename: fileName,
          contentType: contentType,
        );
        request.files.add(multipartFile);
      }

      debugPrint('📤 [ApiService] Sending request to: $uri');
      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);
      debugPrint('📤 [ApiService] Response status: ${response.statusCode}');
      debugPrint('📤 [ApiService] Response body: ${response.body}');

      return _handleResponse(response);
    } catch (e) {
      debugPrint('❌ [ApiService] Upload error: $e');
      if (e is ApiException) rethrow;
      throw ApiException('Error al subir archivos: $e');
    }
  }

  Map<String, dynamic> _handleResponse(http.Response response) {
    final body = jsonDecode(response.body);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return body is Map<String, dynamic> ? body : {'data': body};
    }

    // Check for authentication errors
    if (response.statusCode == 401 || response.statusCode == 403) {
      debugPrint('⚠️ [ApiService] Authentication error detected');
      throw AuthenticationException();
    }

    final message = body['message'] ?? 'Error desconocido';
    throw ApiException(
      message is List ? message.join(', ') : message.toString(),
      statusCode: response.statusCode,
    );
  }
}
