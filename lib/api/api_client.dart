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
      connectTimeout: const Duration(seconds: 12), // 긴 쪽 채택
      receiveTimeout: const Duration(seconds: 20), // 긴 쪽 채택
      headers: {
        HttpHeaders.acceptHeader: 'application/json',
        // 기본 사용자. 개별 호출에서 Options(headers:{'X-User-id': userId})로 덮어쓸 수 있음
        'X-User-id': '2',
        // GET에는 Content-Type가 굳이 필요 없어서 넣지 않음(일부 서버에서 거부하는 경우가 있어 생략)
      },
    ),
  ) {
    // 간단 로거 + 응답/에러 로깅
    client.interceptors.add(
      InterceptorsWrapper(
        onRequest: (o, h) {
          debugPrint('🔵 [REQ] ${o.method} ${o.uri}');
          debugPrint('     headers=${o.headers}  q=${o.queryParameters}');
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

    // 디버그 모드 Pretty Logger
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
