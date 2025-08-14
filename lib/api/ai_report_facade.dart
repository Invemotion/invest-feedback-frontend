// import 'dart:convert';
// import 'package:dio/dio.dart';
// import 'package:intl/intl.dart';
//
// import 'api_client.dart';
//
// class AiReportResult {
//   final bool ok;
//   final String message;
//   final int? httpStatus;
//   AiReportResult({required this.ok, required this.message, this.httpStatus});
// }
//
// class AiReportFacade {
//   final Dio _http = ApiClient().client;
//
//   // Android Studio 실행 시 --dart-define=OPENAI_API_KEY=... 로 주입
//   static const _openaiKey = String.fromEnvironment('OPENAI_API_KEY');
//
//   // ──────────────────────────────────────────────────────────────────────
//   // 공개 메서드: 일간 리포트 생성 & 저장(POST, 있으면 PATCH)
//   // ──────────────────────────────────────────────────────────────────────
//   Future<AiReportResult> createAndSaveDaily({
//     required DateTime date,
//     required int userId,
//   }) async {
//     try {
//       final reportDate = DateFormat('yyyy-MM-dd').format(date);
//       final month = DateFormat('yyyy-MM').format(date);
//
//       // 1) DB에서 일자 데이터 수집 (트레이드 + 저널)
//       final day = await _collectDayData(date, userId);
//
//       // 2) 프롬프트 구성
//       final prompt = _buildPrompt(day);
//
//       // 3) OpenAI 호출 (폴백 없음: 실패 시 그대로 에러 리턴)
//       final content = await _callOpenAI(prompt);
//       if (content == null || content.trim().isEmpty) {
//         return AiReportResult(ok: false, message: 'LLM 응답이 비었습니다.', httpStatus: null);
//       }
//
//       // 4) 저장 시도: POST (이미 있으면 409) → 그 경우 id 찾아 PATCH
//       try {
//         final postRes = await _http.post(
//           '/api/report',
//           data: {
//             'periodType': 'DAILY',
//             'reportDate': reportDate,
//             'content': content,
//             'meta': null,
//           },
//           options: Options(headers: {'X-User-id': userId}),
//         );
//         final code = postRes.statusCode ?? 200;
//         return AiReportResult(ok: true, message: '리포트가 생성되었습니다. (HTTP $code)', httpStatus: code);
//       } on DioException catch (e) {
//         final st = e.response?.statusCode ?? 0;
//         // 409: 이미 존재 → 해당 날짜 리포트 id 조회 후 PATCH
//         if (st == 409) {
//           final id = await _findReportIdByDate(month: month, date: reportDate, userId: userId);
//           if (id == null) {
//             return AiReportResult(ok: false, message: '기존 리포트 ID를 찾지 못했습니다.', httpStatus: 409);
//           }
//           final patchRes = await _http.patch(
//             '/api/reports/$id', // ✅ 문서에 따르면 복수형 엔드포인트
//             data: {
//               'content': content,
//               'meta': null,
//             },
//             options: Options(headers: {'X-User-id': userId}),
//           );
//           final code = patchRes.statusCode ?? 200;
//           return AiReportResult(ok: true, message: '리포트를 덮어썼습니다. (HTTP $code)', httpStatus: code);
//         }
//         // 기타 에러 그대로 전달
//         final msg = e.response?.data is Map ? (e.response?.data['message']?.toString() ?? '오류') : e.message;
//         return AiReportResult(ok: false, message: 'Facade 오류: $msg', httpStatus: st == 0 ? null : st);
//       }
//     } catch (e) {
//       return AiReportResult(ok: false, message: 'Facade 오류: $e', httpStatus: null);
//     }
//   }
//
//   // ──────────────────────────────────────────────────────────────────────
//   // DB 수집
//   // ──────────────────────────────────────────────────────────────────────
//   Future<_DayBundle> _collectDayData(DateTime date, int userId) async {
//     final month = DateFormat('yyyy-MM').format(date);
//     final dayKey = DateFormat('yyyy-MM-dd').format(date);
//
//     // trades (월단위 → 필터)
//     final tradesRes = await _http.get(
//       '/api/trades',
//       queryParameters: {'month': month, 'page': 0, 'size': 200},
//       options: Options(headers: {'X-User-id': userId}),
//     );
//     final content = (tradesRes.data['data']?['trades']?['content'] as List?) ?? const [];
//
//     final List<_Trade> trades = [];
//     for (final raw in content) {
//       final completed = (raw['completedTime']?.toString() ?? '').trim(); // "yyyy-MM-dd HH:mm:ss"
//       if (completed.isEmpty) continue;
//       if (!completed.startsWith(dayKey)) continue;
//
//       trades.add(_Trade(
//         id: raw['id'],
//         tradeId: raw['tradeId']?.toString(),
//         stockName: raw['stockName']?.toString(),
//         stockCode: raw['stockCode']?.toString(),
//         actionType: raw['actionType']?.toString(),
//         orderType: raw['orderType']?.toString(),
//         orderTime: raw['orderTime']?.toString(),
//         completionTime: raw['completedTime']?.toString(),
//         marketPriceAtOrder: raw['marketPriceAtOrder'],
//         pricePerBuy: raw['pricePerBuy'],
//         pricePerSell: raw['pricePerSell'],
//         quantity: raw['quantity'],
//         totalAmount: raw['totalAmount'],
//         resultType: raw['resultType']?.toString(),
//         hasJournal: raw['hasJournal'] == true,
//         journalId: raw['journalId'],
//       ));
//     }
//
//     // journals (개별 tradeId)
//     final List<_Journal> journals = [];
//     for (final t in trades) {
//       try {
//         final jr = await _http.get('/api/journals/${t.tradeId}', options: Options(headers: {'X-User-id': userId}));
//         final d = jr.data['data'];
//         if (d is Map) {
//           journals.add(_Journal(
//             tradeId: t.tradeId,
//             reason: d['reason']?.toString(),
//             emotion: d['emotion']?.toString(),
//             behavior: d['behavior']?.toString(),
//             resultType: d['resultType']?.toString(),
//           ));
//         }
//       } catch (_) {
//         // 저널이 없거나 통신 실패 → 무시
//       }
//     }
//
//     return _DayBundle(reportDate: dayKey, trades: trades, journals: journals);
//   }
//
//   // ──────────────────────────────────────────────────────────────────────
//   // 프롬프트
//   // ──────────────────────────────────────────────────────────────────────
//   String _buildPrompt(_DayBundle b) {
//     // 간결 버전: 수집된 JSON을 그대로 투입 + 작성 규칙
//     final payload = {
//       'report_date': b.reportDate,
//       'trades': b.trades.map((t) => t.toJson()).toList(),
//       'journals': b.journals.map((j) => j.toJson()).toList(),
//     };
//
//     final rules = '''
// [작성 원칙]
// - 수치/시간/근거를 명시(가격 원, 수량 주, 시간 HH:mm, % 등). 입력 없으면 "데이터 미제공".
// - 문장 끝에 근거 표기: [거래 HH:mm], [일지 tradeId=...].
// - (계획→실행→결과→원인/대안) 순서 핵심 요약. 감정·행동 태그는 원인/대안에 연결.
// - 칭찬·수사 금지, 분석 톤.
// - 템플릿 섹션/제목은 그대로 유지.
// ''';
//
//     final template = '''
// # ${b.reportDate} 일일 투자 리포트
//
// ## 0) 오늘의 한 줄
// - 포트 수익률/지수/초과수익: **데이터 미제공**
// - 대표 트레이드 한 문장 요약(가격/수량/시간/손익 + 근거)
//
// ---
// ## 1) 오늘의 거래 요약
// - 총 n건(매수 x, 매도 y) / 당일 청산 a, 보유 b
// - 실현손익(원/건수), 미확정 손익(원/건수)
// - 대표 트레이드 1건 상세(체결가/수량/시간/손익) [근거]
//
// (계획↔실행↔결과)
// - 계획:
// - 실행:
// - 결과:
//
// ---
// ## 2) 감정·행동 패턴
// - 상위 감정/행동 태그와 건수
// - 의사결정 경로 1~2문장
// - 개선 가이드 1~2개(수치 포함)
//
// ---
// ## 3) 투자 성향 프로필 대비 점검
// - 데이터 미제공이면 그렇게 명시
//
// ---
// ## 4) 시장 환경·뉴스
// - 데이터 미제공이면 그렇게 명시
//
// ---
// ## 5) 오늘의 키 인사이트(재현 가능)
// - 불릿 3~5개: '상황 → 행동 → 결과 → 교훈' 형식, 각 1문장
//
// ---
// ## 6) 투자 원칙(요지) — 오늘 케이스 검토
// - 매수/손절/익절/시간손절/사이징/레짐/이벤트/분산 각 1줄 내
// ''';
//
//     return '''
// 너는 한국어로 작성하는 리서치 애널리스트다. 아래 JSON을 바탕으로 템플릿을 충실히 채워라.
//
// $rules
//
// [템플릿]
// $template
//
// [입력(JSON)]
// ${const JsonEncoder.withIndent('  ').convert(payload)}
// ''';
//   }
//
//   // ──────────────────────────────────────────────────────────────────────
//   // OpenAI 호출
//   // ──────────────────────────────────────────────────────────────────────
//   Future<String?> _callOpenAI(String prompt) async {
//     if (_openaiKey.isEmpty) {
//       throw StateError('OPENAI_API_KEY가 설정되어 있지 않습니다. (--dart-define=OPENAI_API_KEY=...)');
//     }
//     final dio = Dio(BaseOptions(
//       baseUrl: 'https://api.openai.com/v1',
//       headers: {
//         'Authorization': 'Bearer $_openaiKey',
//         'Content-Type': 'application/json',
//       },
//       connectTimeout: const Duration(seconds: 20),
//       receiveTimeout: const Duration(seconds: 60),
//     ));
//
//     final resp = await dio.post('/chat/completions', data: {
//       'model': 'gpt-4o-mini',
//       'temperature': 0.3,
//       'max_tokens': 1800,
//       'messages': [
//         {
//           'role': 'system',
//           'content':
//           '너는 한국어 리서치 애널리스트다. 수치·시간·근거 중심으로 간결하게 작성하고, 문장 끝에 근거 표기를 붙인다.'
//         },
//         {'role': 'user', 'content': prompt},
//       ]
//     });
//
//     final choices = resp.data['choices'] as List?;
//     if (choices == null || choices.isEmpty) return null;
//     final content = choices.first['message']?['content']?.toString();
//     return content;
//   }
//
//   // ──────────────────────────────────────────────────────────────────────
//   // 해당 날짜 리포트 ID 조회
//   // ──────────────────────────────────────────────────────────────────────
//   Future<int?> _findReportIdByDate({
//     required String month,
//     required String date,
//     required int userId,
//   }) async {
//     final r = await _http.get(
//       '/api/reports',
//       queryParameters: {'month': month, 'page': 0, 'size': 200},
//       options: Options(headers: {'X-User-id': userId}),
//     );
//     final list = (r.data['data']?['reports']?['content'] as List?) ?? const [];
//     for (final m in list) {
//       if ((m['reportDate']?.toString() ?? '') == date) {
//         return m['id'] as int?;
//       }
//     }
//     return null;
//   }
// }
//
// // ────────────── 내부 모델 ──────────────
// class _DayBundle {
//   final String reportDate;
//   final List<_Trade> trades;
//   final List<_Journal> journals;
//   _DayBundle({required this.reportDate, required this.trades, required this.journals});
// }
//
// class _Trade {
//   final int? id;
//   final String? tradeId;
//   final String? stockName;
//   final String? stockCode;
//   final String? actionType;
//   final String? orderType;
//   final String? orderTime;
//   final String? completionTime;
//   final num? marketPriceAtOrder;
//   final num? pricePerBuy;
//   final num? pricePerSell;
//   final int? quantity;
//   final num? totalAmount;
//   final String? resultType;
//   final bool hasJournal;
//   final int? journalId;
//
//   _Trade({
//     required this.id,
//     required this.tradeId,
//     required this.stockName,
//     required this.stockCode,
//     required this.actionType,
//     required this.orderType,
//     required this.orderTime,
//     required this.completionTime,
//     required this.marketPriceAtOrder,
//     required this.pricePerBuy,
//     required this.pricePerSell,
//     required this.quantity,
//     required this.totalAmount,
//     required this.resultType,
//     required this.hasJournal,
//     required this.journalId,
//   });
//
//   Map<String, dynamic> toJson() => {
//     'id': id,
//     'tradeId': tradeId,
//     'stockName': stockName,
//     'stockCode': stockCode,
//     'actionType': actionType,
//     'orderType': orderType,
//     'orderTime': orderTime,
//     'completionTime': completionTime,
//     'marketPriceAtOrder': marketPriceAtOrder,
//     'pricePerBuy': pricePerBuy,
//     'pricePerSell': pricePerSell,
//     'quantity': quantity,
//     'totalAmount': totalAmount,
//     'resultType': resultType,
//     'hasJournal': hasJournal,
//     'journalId': journalId,
//   };
// }
//
// class _Journal {
//   final String? tradeId;
//   final String? reason;
//   final String? emotion;  // 서버 ENUM
//   final String? behavior; // 서버 ENUM
//   final String? resultType;
//   _Journal({this.tradeId, this.reason, this.emotion, this.behavior, this.resultType});
//
//   Map<String, dynamic> toJson() => {
//     'tradeId': tradeId,
//     'reason': reason,
//     'emotion': emotion,
//     'behavior': behavior,
//     'resultType': resultType,
//   };
// }

import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';

import 'api_client.dart';
import 'trade_service.dart';
import 'journal_service.dart';

class AiReportResult {
  final bool ok;
  final String message;
  final int? httpStatus;
  AiReportResult({required this.ok, required this.message, this.httpStatus});
}

class AiReportFacade {
  final ApiClient _api = ApiClient();
  final TradeService _trades = TradeService();
  final JournalService _journals = JournalService();

  // flutter run --dart-define=OPENAI_API_KEY=sk-xxx 로 주입
  static const String _openaiKey = String.fromEnvironment('OPENAI_API_KEY');
  static const String _openaiUrl = 'https://api.openai.com/v1/chat/completions';
  static const String _openaiModel = 'gpt-4o-mini';

  /// 일별 LLM 리포트 생성 → 서버 저장(POST) → 이미 있으면 해당 id로 PATCH
  Future<AiReportResult> createAndSaveDaily({
    required DateTime date,
    required int userId,
  }) async {
    final dStr = DateFormat('yyyy-MM-dd').format(date);
    final monthStr = DateFormat('yyyy-MM').format(date);

    try {
      // 1) 해당 날짜의 트레이드 + 저널 적재
      final month = await _trades.fetchTrades(month: monthStr, page: 0, size: 200);
      final dayTrades = month.items.where((t) =>
      DateFormat('yyyy-MM-dd').format(t.completedTime) == dStr).toList();

      final entries = <Map<String, dynamic>>[];
      for (final t in dayTrades) {
        Map<String, dynamic>? journalMap;
        final jId = t.journalId;
        if (jId != null && jId > 0) {
          final j = await _journals.getByJournalId(jId);
          if (j != null) {
            journalMap = {
              'id': j.id,
              'reason': j.reason,
              'emotion': j.emotion,
              'behavior': j.behavior,
            };
          }
        }
        entries.add({
          'id': t.id,
          'title': t.title,
          'time': DateFormat('HH:mm').format(t.completedTime),
          'hasJournal': journalMap != null,
          'journal': journalMap,
        });
      }

      // 2) LLM 호출(컨텐츠 생성) — 폴백 없음
      final content = await _generateWithLLM(
        date: dStr,
        entries: entries,
      );

      // 3) 서버 저장: POST /api/report
      try {
        await _api.client.post(
          '/api/report',
          data: {
            'periodType': 'DAILY',
            'reportDate': dStr,
            'content': content,
            'meta': null,
          },
          options: Options(headers: {'X-User-id': '$userId'}),
        );
        return AiReportResult(ok: true, message: '리포트가 생성되었습니다.');
      } on DioException catch (e) {
        // 이미 존재: 409 → 해당 id 찾아 PATCH /api/reports/{id}
        if (e.response?.statusCode == 409 ||
            (e.response?.data is Map && (e.response?.data['status'] == 40701))) {
          final id = await _findReportIdByDate(monthStr, dStr, userId);
          if (id == null) {
            return AiReportResult(ok: false, message: '리포트 ID 탐색 실패', httpStatus: e.response?.statusCode);
          }
          final r = await _api.client.patch(
            '/api/reports/$id',
            data: {
              'periodType': 'DAILY',
              'reportDate': dStr,
              'content': content,
              'meta': null,
            },
            options: Options(headers: {'X-User-id': '$userId'}),
          );
          return AiReportResult(ok: r.statusCode == 200, message: '리포트가 갱신되었습니다.', httpStatus: r.statusCode);
        }
        rethrow;
      }
    } catch (e) {
      return AiReportResult(ok: false, message: '생성/저장 중 오류: $e');
    }
  }

  Future<int?> _findReportIdByDate(String month, String dStr, int userId) async {
    final resp = await _api.client.get(
      '/api/reports',
      queryParameters: {'month': month, 'page': 0, 'size': 50},
      options: Options(headers: {'X-User-id': '$userId'}),
    );
    final list = (resp.data?['data']?['reports']?['content'] as List?) ?? const [];
    for (final m in list) {
      if (m is Map && m['reportDate'] == dStr) {
        return (m['id'] as num).toInt();
      }
    }
    return null;
  }

  Future<String> _generateWithLLM({
    required String date,
    required List<Map<String, dynamic>> entries,
  }) async {
    if (_openaiKey.isEmpty) {
      throw Exception('OPENAI_API_KEY 미설정: --dart-define=OPENAI_API_KEY=... 로 키를 주입하세요.');
    }
    final dio = Dio(BaseOptions(
      baseUrl: _openaiUrl,
      headers: {
        'Authorization': 'Bearer $_openaiKey',
        'Content-Type': 'application/json',
      },
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 30),
    ));

    final system = '''
너는 한국어 투자 리포트 작성 비서야. 마크다운으로 간결하고 구조화된 "일간 리포트"를 작성해.
섹션: 0) 한 줄, 1) 거래 요약, 2) 감정·행동, 3) 성향 점검(가능하면), 4) 시장/뉴스(없으면 생략 문구), 5) 키 인사이트, 6) 원칙 점검.
숫자는 천단위 구분, 시간은 HH:mm.
'''.trim();

    final user = jsonEncode({
      'date': date,
      'entries': entries,
    });

    final body = {
      'model': _openaiModel,
      'temperature': 0.3,
      'messages': [
        {'role': 'system', 'content': system},
        {'role': 'user', 'content': user},
      ],
    };

    final res = await dio.post('', data: body);
    final choices = res.data['choices'] as List;
    final content = choices.first['message']['content'] as String? ?? '# $date 일일 투자 리포트\n(내용 생성 실패)';
    return content;
  }
}
