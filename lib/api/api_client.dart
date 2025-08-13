import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:pretty_dio_logger/pretty_dio_logger.dart';

class ApiClient {
  // TradeService 등에서 이 Dio 인스턴스를 사용합니다.
  final Dio client;

  static const String _base = 'http://13.124.208.84:8080';

  ApiClient()
      : client = Dio(BaseOptions(
    baseUrl: _base,
    connectTimeout: const Duration(seconds: 10),
    receiveTimeout: const Duration(seconds: 15),
    headers: {
      HttpHeaders.acceptHeader: 'application/json',
      // 서버 요구 헤더
      'X-User-id': '2',
      // GET에는 Content-Type가 굳이 필요 없어서 넣지 않음(일부 서버에서 거부하는 경우가 있어 생략)
    },
  )) {
    // 간단 로거
    client.interceptors.add(InterceptorsWrapper(
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
    ));

    if (kDebugMode) {
      client.interceptors.add(PrettyDioLogger(
        requestHeader: true,
        requestBody: true,
        responseBody: true,
        compact: true,
      ));
    }
  }
}
