import 'dart:io';

import 'package:mindpilot/export.dart';

abstract class BaseService {
  late final Dio _dio;

  BaseService() {
    _init();
  }

  void _init() {
    final apiKey = dotenv.env['Twezi_API_KEY'];

    _dio = Dio(
      BaseOptions(
        baseUrl: 'https://rest.twezi.io/v3',
        connectTimeout: const Duration(seconds: 30),
        receiveTimeout: const Duration(seconds: 30),
        headers: {
          HttpHeaders.acceptHeader: 'application/json',
          HttpHeaders.contentTypeHeader: 'application/json',

          if (apiKey != null) HttpHeaders.authorizationHeader: 'Bearer $apiKey',
        },
      ),
    );

    _dio.interceptors.add(
      PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        error: true,
      ),
    );
  }

  Future<Response> get(String path) async {
    return await _dio.get(path);
  }
}
