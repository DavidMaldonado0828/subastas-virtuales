import 'package:dio/dio.dart';

class ApiClient {
  ApiClient({required String baseUrl})
    : dio = Dio(BaseOptions(baseUrl: baseUrl)) {
    dio.interceptors.add(
      InterceptorsWrapper(
        onError: (error, handler) {
          final status = error.response?.statusCode;
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
