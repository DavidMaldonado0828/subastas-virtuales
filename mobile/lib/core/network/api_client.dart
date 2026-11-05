import 'package:dio/dio.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../auth/auth_session.dart';

class ApiClient {
  ApiClient({
    required String baseUrl,
    required FlutterSecureStorage storage,
    required AuthSession session,
  }) : dio = Dio(BaseOptions(baseUrl: baseUrl)) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) async {
          final path = options.path;
          if (options.extra['publicRequest'] != true &&
              path != '/auth/login' && path != '/auth/register') {
            final token = await storage.read(key: AuthSession.tokenKey);
            if (token != null) {
              options.headers['Authorization'] = 'Bearer $token';
            }
          }
          handler.next(options);
        },
      ),
    );
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) async {
          final status = error.response?.statusCode;
          if (status == 401 &&
              error.requestOptions.extra['publicRequest'] != true &&
              error.requestOptions.headers.containsKey('Authorization')) {
            await session.clear();
          }
          final payload = error.response?.data;
          String? detail;
          if (payload is Map<String, dynamic> && payload['detail'] is String) {
            detail = payload['detail'] as String;
          }
          error.requestOptions.extra['apiStatus'] = status;
          error.requestOptions.extra['apiDetail'] = detail;
          handler.next(error);
        },
      ),
    );
  }

  final Dio dio;
}
