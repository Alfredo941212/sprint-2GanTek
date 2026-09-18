import 'dart:convert';

import 'package:http/http.dart' as http;

import '../session/session_manager.dart';
import 'api_config.dart';

class ApiClient {
  ApiClient._();

  static final ApiClient instance = ApiClient._();

  Future<http.Response> get(
    String endpoint, {
    String? token,
  }) async {
    final Uri uri = Uri.parse(
      '${ApiConfig.baseUrl}$endpoint',
    );

    final String? resolvedToken =
        token ?? await SessionManager.instance.getStoredApiToken();

    print('=== API GET ===');
    print('Endpoint: $endpoint');
    print(
      'Tiene token: ${resolvedToken != null && resolvedToken.isNotEmpty}',
    );
    print(
      'Longitud token: ${resolvedToken?.length ?? 0}',
    );
    print('===============');

    final http.Response response = await http
        .get(
          uri,
          headers: _headers(resolvedToken),
        )
        .timeout(ApiConfig.timeout);

    print('=== API RESPONSE ===');
    print('Endpoint: $endpoint');
    print('Status: ${response.statusCode}');
    print('====================');

    return response;
  }

  Future<http.Response> post(
    String endpoint, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final Uri uri = Uri.parse(
      '${ApiConfig.baseUrl}$endpoint',
    );

    final String? resolvedToken =
        token ?? await SessionManager.instance.getStoredApiToken();

    return http
        .post(
          uri,
          headers: _headers(resolvedToken),
          body: jsonEncode(
            body ?? {},
          ),
        )
        .timeout(ApiConfig.timeout);
  }

  Future<http.Response> put(
    String endpoint, {
    String? token,
    Map<String, dynamic>? body,
  }) async {
    final Uri uri = Uri.parse(
      '${ApiConfig.baseUrl}$endpoint',
    );

    final String? resolvedToken =
        token ?? await SessionManager.instance.getStoredApiToken();

    return http
        .put(
          uri,
          headers: _headers(resolvedToken),
          body: jsonEncode(
            body ?? {},
          ),
        )
        .timeout(ApiConfig.timeout);
  }

  Future<http.Response> delete(
    String endpoint, {
    String? token,
  }) async {
    final Uri uri = Uri.parse(
      '${ApiConfig.baseUrl}$endpoint',
    );

    final String? resolvedToken =
        token ?? await SessionManager.instance.getStoredApiToken();

    return http
        .delete(
          uri,
          headers: _headers(resolvedToken),
        )
        .timeout(ApiConfig.timeout);
  }

  Map<String, String> _headers(
    String? token,
  ) {
    return {
      'Accept': 'application/json',
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }
}
