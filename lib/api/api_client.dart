import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

class ApiClient {
  final Dio client;
  static const String _base = 'http://13.124.208.84:8080';

  ApiClient()
      : client = Dio(
    BaseOptions(
      baseUrl: _base,
      connectTimeout: const Duration(seconds: 12),
      receiveTimeout: const Duration(seconds: 20),
      headers: {
        HttpHeaders.acceptHeader: 'application/json',
        // 기본 사용자. 개별 호출에서 Options(headers:{'X-User-id': userId})로 덮어쓸 수 있음
        'X-User-id': '1',
      },
    ),
  ) {
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          debugPrint('🔵 [REQ] ${o.method} ${o.uri}');
          return h.next(o);
        },
        onResponse: (r, h) {
          debugPrint('🟢 [RES] ${r.statusCode} ${r.requestOptions.path}');
          return h.next(r);
        },
        onError: (e, h) {
          debugPrint(
              '🔴 [ERR] ${e.requestOptions.method} ${e.requestOptions.path} '
                  'code=${e.response?.statusCode} data=${e.response?.data}');
          return h.next(e);
        },
      ),
    );

    if (kDebugMode) {
      client.interceptors.add(
        PrettyDioLogger(
          requestHeader: true,
          requestBody: true,
          responseBody: true,
          compact: true,
        ),
      );
    }
  }
}
