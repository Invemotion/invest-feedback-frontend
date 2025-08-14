// lib/api/ai_report_facade.dart
import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';

import '../api/api_client.dart';

class AiReportResult {
  final bool ok;
  final String message;
  final int? httpStatus;

  const AiReportResult({required this.ok, required this.message, this.httpStatus});
}

/// LLM 기반 리포트 생성/저장 파사드
class AiReportFacade {
  // ─────────────────────────────────────────────────────────────────────────
  // OpenAI 설정
  // ─────────────────────────────────────────────────────────────────────────
  static const String _openAIBase = 'https://api.openai.com/v1';
  static const String _openAIModel = 'gpt-4.1'; // 정확도 우선(속도/비용은 gpt-4.1-mini)

  /// --dart-define=OPENAI_API_KEY=sk-xxxx
  static const String _openAIKey = String.fromEnvironment('OPENAI_API_KEY');

  /// 시스템 프롬프트
  static const String _systemPrompt =
      '너는 한국어 해요체를 사용하여 리포트를 작성하는 리서치 애널리스트다. '
      '수치·시간·근거 중심으로, 칭찬/과장/일반론을 배제하고 보고서 톤으로만 쓴다. '
      '단, 전반적인 말투는 해요체를 사용한다. 섹션 1은 간결/비해요체로 요약한다.';

  // ─────────────────────────────────────────────────────────────────────────
  // 라벨 매핑(영문 ENUM → 한글 라벨)
  // ─────────────────────────────────────────────────────────────────────────
  static const Map<String, String> _emoKo = {
    'EXPECTATION': '기대',
    'CERTAINTY': '확신',
    'ANXIETY': '불안',
    'JOY': '기쁨',
    'REMORSE': '후회',
    'NEUTRAL': '무감정',
    'REGRET': '아쉬움',
  };

  static const Map<String, String> _behKo = {
    'CHASING_BUY': '추격 매수',
    'DIVIDED_ENTRY': '분할 진입',
    'EMOTIONAL_ENTRY': '감정적 진입',
    'STRATEGIC_EXIT': '전략적 정리',
    'DIVIDED_SELL': '분할 매도',
    'EARLY_SELL': '조기 매도',
    'DELAYED_STOPLOSS': '손절 지연',
    'MARKET_FOLLOW': '시장 추종',
    'UNSTABLE_SELL': '불안정 매도',
  };

  // ─────────────────────────────────────────────────────────────────────────
  // 내부 클라이언트
  // ─────────────────────────────────────────────────────────────────────────
  final Dio _http = ApiClient().client; // 우리 백엔드 (13.124.208.84)
  final Dio _openai = Dio(
    BaseOptions(
      baseUrl: _openAIBase,
      connectTimeout: const Duration(seconds: 20),
      receiveTimeout: const Duration(seconds: 40),
    ),
  )..interceptors.add(InterceptorsWrapper(
    onRequest: (o, h) {
      if (_openAIKey.isEmpty) {
        debugPrint('⚠️ OPENAI_API_KEY 미설정');
      }
      o.headers[HttpHeaders.authorizationHeader] = 'Bearer $_openAIKey';
      o.headers[HttpHeaders.contentTypeHeader] = 'application/json';
      return h.next(o);
    },
  ));

  // ─────────────────────────────────────────────────────────────────────────
  // 외부 메서드
  // ─────────────────────────────────────────────────────────────────────────
  Future<AiReportResult> createAndSaveDaily({
    required DateTime date,
    required int userId,
  }) async {
    final dStr = DateFormat('yyyy-MM-dd').format(date);
    final month = DateFormat('yyyy-MM').format(date);

    try {
      // 1) 입력 데이터 수집 (트레이드/일지 from 서버) + 사용자 프로필 로드(NEW)
      final payload = await _buildPayloadForDate(date: dStr, userId: userId);

      // 2) 집계(facts) 계산 후 payload에 주입
      final facts = _deriveFacts(
        trades: (payload['trades'] as List).cast<Map<String, dynamic>>(),
        journals: (payload['journals'] as List).cast<Map<String, dynamic>>(),
      );
      payload['facts'] = facts;

      // 3) 프롬프트 생성
      final promptText = _promptForDaily(payload);

      // 4) OpenAI 호출
      final generated = await _requestDailyReport(promptText);
      if (generated == null || generated.trim().isEmpty) {
        return AiReportResult(ok: false, message: 'LLM 응답이 비었습니다.', httpStatus: null);
      }

      // 5) 저장 (POST → 409이면 PATCH)
      return await _saveReportOrPatch(
        userId: userId,
        month: month,
        date: dStr,
        content: generated.trim(),
      );
    } catch (e) {
      return AiReportResult(ok: false, message: '리포트 생성 오류: $e', httpStatus: null);
    }
  }

  // 저장 공통부
  Future<AiReportResult> _saveReportOrPatch({
    required int userId,
    required String month,
    required String date,
    required String content,
  }) async {
    final body = {
      'periodType': 'DAILY',
      'reportDate': date,
      'content': content,
      'meta': null,
    };

    try {
      final res = await _http.post(
        '/api/report',
        data: body,
        options: Options(headers: {'X-User-id': userId}),
      );
      final code = res.statusCode ?? 200;
      return AiReportResult(ok: true, message: '리포트가 생성되었습니다.', httpStatus: code);
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      final msg = (data is Map && data['message'] is String) ? data['message'] as String : null;

      if (status == 409 || (msg != null && msg.contains('이미 존재'))) {
        final reportId = await _findExistingReportId(month: month, date: date, userId: userId);
        if (reportId == null) {
          return AiReportResult(ok: false, message: '기존 리포트 ID를 찾지 못했습니다.', httpStatus: status);
        }
        final patched = await _http.patch(
          '/api/reports/$reportId',
          data: body,
          options: Options(headers: {'X-User-id': userId}),
        );
        return AiReportResult(
          ok: (patched.statusCode ?? 200) < 400,
          message: '리포트가 업데이트 되었습니다.',
          httpStatus: patched.statusCode,
        );
      }

      return AiReportResult(
        ok: false,
        message: '저장 실패: ${msg ?? e.message}',
        httpStatus: status,
      );
    }
  }

  // 리포트 id 찾기
  Future<int?> _findExistingReportId({
    required String month,
    required String date,
    required int userId,
  }) async {
    try {
      final res = await _http.get(
        '/api/reports',
        queryParameters: {'month': month, 'page': 0, 'size': 50},
        options: Options(headers: {'X-User-id': userId}),
      );
      final list = (res.data?['data']?['reports']?['content'] as List?) ?? const [];
      for (final m in list) {
        if (m is Map && m['reportDate'] == date) {
          final id = m['id'];
          if (id is int) return id;
          if (id is num) return id.toInt();
        }
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  Future<Map<String, dynamic>> _buildPayloadForDate({
    required String date, // yyyy-MM-dd
    required int userId,
  }) async {
    final month = date.substring(0, 7); // yyyy-MM

    // 트레이드(월) → 일자 필터
    final tradesAll = await _fetchTradesForMonth(month: month, userId: userId);
    final dayTradesRaw = tradesAll.where((t) {
      final ct = _parseKst(t['completedTime']);
      return ct != null && DateFormat('yyyy-MM-dd').format(ct) == date;
    }).toList();

    // 저널(있을 때) 병합
    final journals = <Map<String, dynamic>>[];
    for (final t in dayTradesRaw) {
      final jId = t['journalId'];
      if (jId == null) continue;
      final j = await _fetchJournalById(jId, userId);
      if (j != null) {
        journals.add({
          'trade_id': t['id'],
          'reason': j['reason'],
          'emotion': j['emotion'],
          'behavior': j['behavior'],
          'resultType': j['resultType'],
        });
      }
    }

    // 대표 티커
    final names = dayTradesRaw.map((e) => (e['stockName'] ?? '').toString()).where((s) => s.isNotEmpty).toSet();
    final codes = dayTradesRaw.map((e) => (e['stockCode'] ?? '').toString()).where((s) => s.isNotEmpty).toSet();
    final ticker = (names.length == 1 && codes.length == 1)
        ? {'name': names.first, 'code': codes.first}
        : {'name': names.isEmpty ? '종목미상' : '다수', 'code': codes.isEmpty ? '' : 'MIXED'};

    // 트레이드 변환
    final payloadTrades = dayTradesRaw.map((t) {
      final orderTime = _parseKst(t['orderTime']);
      final fillTime = _parseKst(t['completedTime']);

      double? _toDouble(v) {
        if (v == null) return null;
        if (v is num) return v.toDouble();
        return double.tryParse(v.toString());
      }

      int _toInt(v) {
        if (v == null) return 0;
        if (v is num) return v.toInt();
        return int.tryParse(v.toString()) ?? 0;
      }

      final fillPrice = t['pricePerSell'] ?? t['pricePerBuy'] ?? t['marketPriceAtOrder'];
      return {
        'trade_id': _toInt(t['id']),
        'ticker': (t['stockName'] ?? '').toString(),
        'code': (t['stockCode'] ?? '').toString(),
        'action': (t['actionType'] ?? '').toString(),
        'order_type': (t['orderType'] ?? '').toString(),
        'order_time': orderTime?.toIso8601String(),
        'fill_time': fillTime?.toIso8601String(),
        'fill_price': _toDouble(fillPrice),
        'qty': _toInt(t['quantity']),
        'total_amount': _toDouble(t['totalAmount']),
        'result': (t['resultType'] ?? '').toString().isEmpty ? null : t['resultType'],
      };
    }).toList();

    final userProfile = await _fetchAndNormalizeUserProfile(userId: userId);

    final payload = <String, dynamic>{
      'report_date': date,
      'ticker': ticker,
      'user_profile': userProfile,
      'trades': payloadTrades,
      'journals': journals,
      'market_snapshot': {'mode': 'unknown', 'windows': []},
      'news_hourly': <dynamic>[],
    };

    return payload;
  }

  Future<List<Map<String, dynamic>>> _fetchTradesForMonth({
    required String month,
    required int userId,
  }) async {
    final out = <Map<String, dynamic>>[];
    int page = 0;
    const size = 50;

    while (true) {
      final res = await _http.get(
        '/api/trades',
        queryParameters: {'month': month, 'page': page, 'size': size},
        options: Options(headers: {'X-User-id': userId}),
      );
      final tradesMap = res.data?['data']?['trades'] as Map<String, dynamic>?;
      final content = (tradesMap?['content'] as List?) ?? const [];
      final last = tradesMap?['last'] == true;

      for (final e in content) {
        if (e is Map<String, dynamic>) out.add(e);
      }
      if (last || content.isEmpty) break;
      page++;
    }
    return out;
  }

  Future<Map<String, dynamic>?> _fetchJournalById(dynamic journalId, int userId) async {
    try {
      final idStr = journalId.toString();
      if (idStr.isEmpty || idStr == '0') return null;
      final res = await _http.get(
        '/api/journals/$idStr',
        options: Options(headers: {'X-User-id': userId}),
      );
      final data = res.data?['data'];
      if (data is Map<String, dynamic>) return data;
      return null;
    } on DioException {
      return null;
    }
  }

  DateTime? _parseKst(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    if (s.isEmpty) return null;
    final candidates = <String>[
      "yyyy-MM-dd HH:mm:ss",
      "yyyy-MM-dd'T'HH:mm:ss",
      "yyyy-MM-dd'T'HH:mm:ss.SSS",
      "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
    ];
    for (final fmt in candidates) {
      try {
        final dt = DateFormat(fmt).parseUtc(s).toLocal();
        return dt;
      } catch (_) {}
      try {
        final dt = DateFormat(fmt).parse(s, true).toLocal();
        return dt;
      } catch (_) {}
    }
    try {
      return DateTime.parse(s).toLocal();
    } catch (_) {}
    return null;
  }

  Future<Map<String, dynamic>> _fetchAndNormalizeUserProfile({required int userId}) async {
    Map<String, dynamic>? raw;

    final endpoints = <String>[
      '/api/users/$userId',
      '/api/user/$userId',
      '/api/users/me',
      '/api/user/profile',
    ];

    for (final ep in endpoints) {
      try {
        final res = await _http.get(
          ep,
          options: Options(headers: {'X-User-id': userId}),
        );
        final d = res.data;
        if (d is Map<String, dynamic>) {
          if (d['data'] is Map<String, dynamic>) {
            final dd = d['data'] as Map<String, dynamic>;
            if (dd['user'] is Map<String, dynamic>) {
              raw = dd['user'] as Map<String, dynamic>;
            } else {
              raw = dd;
            }
          } else {
            raw = d;
          }
        }
      } catch (_) {
      }
      if (raw != null && raw!.isNotEmpty) break;
    }

    if (raw == null) {
      debugPrint('⚠️ 사용자 프로필 로드 실패 → null 채움');
      return {
        'risk_profile': null,
        'goal': null,
        'expected_return': null,
        'loss_tolerance': null,
        'financial_knowledge_level': null,
        'investment_experience': null,
        'income_stability': null,
        'age_group': null,
        'residency_country': null,
      };
    }

    // 유연 키 선택
    String? _pick(List<String> keys) {
      for (final k in keys) {
        if (!raw!.containsKey(k)) continue;
        final v = raw![k];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isEmpty || s == 'NaN' || s == 'null') continue;
        return s;
      }
      return null;
    }

    String? riskProfile = _pick(['risk_profile','investment_profile','profile','riskProfile','investmentProfile']);
    String? goal = _pick(['goal','usage_purpose','usagePurpose','investment_goal','investmentGoal']);
    String? expectedReturn = _pick(['expected_return','expectedReturn','target_return','targetReturn']);
    String? lossTolerance = _pick(['loss_tolerance','loss_tolerance_level','lossTolerance','lossToleranceLevel']);
    String? financialKnowledge = _pick(['financial_knowledge_level','financialKnowledgeLevel','knowledge_level','knowledgeLevel']);
    String? experience = _pick(['investment_experience','investmentExperience','experience']);
    String? incomeStability = _pick(['income_stability','incomeStability']);
    String? ageGroup = _pick(['age_group','ageGroup']);
    String? residencyCountry = _pick(['residency_country','residencyCountry','country']);

    String? _normUpper(String? s) => s?.trim().toUpperCase();

    final riskSet = {'CONSERVATIVE','CAUTIOUS','NEUTRAL','AGGRESSIVE','SPECULATIVE'};
    final lossSet = {'CAPITAL_PRESERVATION','MINIMAL_LOSS','PARTIAL_LOSS_ACCEPTABLE','HIGH_RISK_ACCEPTABLE'};
    final knowSet = {'NO_EXPERIENCE','BASIC_UNDERSTANDING','DEEP_UNDERSTANDING'};
    final resiSet = {'SOUTH_KOREA','UNITED_STATES','OTHER_FOR_TAX_PURPOSES'};

    String? _whitelist(String? s, Set<String> allow) {
      final u = _normUpper(s);
      if (u == null) return null;
      return allow.contains(u) ? u : null;
    }

    final profile = {
      'risk_profile': _whitelist(riskProfile, riskSet),
      'goal': goal, // 자유 텍스트일 수 있음
      'expected_return': expectedReturn, // 자유 텍스트/숫자 문자열
      'loss_tolerance': _whitelist(lossTolerance, lossSet),
      'financial_knowledge_level': _whitelist(financialKnowledge, knowSet),
      'investment_experience': experience, // 자유 텍스트
      'income_stability': incomeStability, // 자유 텍스트 or ENUM
      'age_group': ageGroup, // "20s"/"30s" 등 자유 텍스트
      'residency_country': _whitelist(residencyCountry, resiSet),
    };

    return profile;
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 2) 집계(facts)
  // ─────────────────────────────────────────────────────────────────────────
  Map<String, dynamic> _deriveFacts({
    required List<Map<String, dynamic>> trades,
    required List<Map<String, dynamic>> journals,
  }) {
    final n = trades.length;
    final buys = trades.where((t) => (t['action'] ?? '').contains('매수')).length;
    final sells = trades.where((t) => (t['action'] ?? '').contains('매도')).length;

    final closed = trades
        .where((t) => (t['result'] ?? '') != '' && (t['result'] ?? '') != 'NONE')
        .length;
    final holding = trades
        .where((t) => (t['result'] ?? '') == 'NONE' || (t['result'] ?? '') == '')
        .length;

    final wins = trades.where((t) => (t['result'] ?? '') == 'PROFIT').length;
    final losses = trades.where((t) => (t['result'] ?? '') == 'LOSS').length;
    final breakeven = trades.where((t) => (t['result'] ?? '') == 'BREAK_EVEN').length;
    final none = trades.where((t) => (t['result'] ?? '') == 'NONE' || (t['result'] ?? '') == '').length;

    Map<String, dynamic>? best;
    double bestAmt = -1;
    for (final t in trades) {
      final price = (t['fill_price'] as num?)?.toDouble() ?? 0;
      final qty = (t['qty'] as num?)?.toDouble() ?? 0;
      final amt = (price * qty).abs();
      if (amt > bestAmt) {
        bestAmt = amt;
        best = t;
      }
    }

    final Map<String, int> emoCount = {};
    final Map<String, int> behCount = {};
    for (final j in journals) {
      final emoKo = _emoKo[j['emotion']] ?? '';
      final behKo = _behKo[j['behavior']] ?? '';
      if (emoKo.isNotEmpty) emoCount[emoKo] = (emoCount[emoKo] ?? 0) + 1;
      if (behKo.isNotEmpty) behCount[behKo] = (behCount[behKo] ?? 0) + 1;
    }

    return {
      'n': n,
      'buys': buys,
      'sells': sells,
      'closed': closed,
      'holding': holding,
      'wins': wins,
      'losses': losses,
      'breakeven': breakeven,
      'none': none,
      'best': best, // null 가능
      'emoCount': emoCount,
      'behCount': behCount,
    };
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 3) 프롬프트(해요체, “오늘의 한 줄” 제거, 한글 라벨 강제)
  // ─────────────────────────────────────────────────────────────────────────
  String _promptForDaily(Map<String, dynamic> payload) {
    final f = (payload['facts'] ?? {}) as Map;
    String _pick(k) => (f[k] ?? '데이터 미제공').toString();

    String _top2(Map m) {
      final entries = (m.entries.toList()..sort((a, b) => (b.value as int).compareTo(a.value as int)));
      final top = entries.take(2).map((e) => '${e.key}(${e.value})').join(', ');
      return top.isEmpty ? '데이터 미제공' : top;
    }

    final n = _pick('n');
    final buys = _pick('buys');
    final sells = _pick('sells');
    final closed = _pick('closed');
    final holding = _pick('holding');
    final wins = _pick('wins');
    final losses = _pick('losses');
    final breakeven = _pick('breakeven');
    final none = _pick('none');
    final emoTop = _top2((f['emoCount'] ?? {}) as Map);
    final behTop = _top2((f['behCount'] ?? {}) as Map);

    final reportDate = (payload['report_date'] ?? '날짜미상').toString();
    final t = (payload['ticker'] ?? {}) as Map;
    final tickerName = (t['name'] ?? '종목미상').toString();

    const rules = '''
[작성 원칙 — 반드시 준수]
1) 수치 우선: 가격(원), 수량(주), 시간(시:분), 퍼센트(%)를 최대한 표기해요. 입력에 없으면 '데이터 미제공'이라고 말해요. 임의 추정 금지.
2) 근거 각주: 문장 끝에 [거래 HH:MM], [뉴스 HH:MM], [시세 ±30m] 형태로 짧게 붙여요.
3) 금지 표현: 칭찬/과장/일반론 및 과도한 확신 금지.
4) 문체: 기본은 한국어 해요체. 단, 섹션 **1) 오늘의 거래 요약**은 간결/비해요체로.
5) 섹션 제목·순서는 템플릿과 동일.
6) 감정/행동 태그는 **한글 라벨만** 사용(영문 ENUM 출력 금지).
   - 감정: 기대/확신/불안/기쁨/후회/무감정/아쉬움
   - 행동: 추격 매수/분할 진입/감정적 진입/전략적 정리/분할 매도/조기 매도/손절 지연/시장 추종/불안정 매도
7) 뉴스는 **시간대 묶음**으로 요약(개별 기사 나열 금지).
''';

    final template = '''
# $reportDate 일일 투자 리포트

## 1) 오늘의 거래 요약
- **총 $n건**: 매수 $buys, 매도 $sells
- **체결 상태**: 당일 청산 $closed, **보유 중 $holding**
- **실현 손익**: 이익 $wins건, 손실 $losses건, 본전 $breakeven건, 미확정 $none건(NONE)
- **대표 트레이드(필수 수치)**: 체결가·수량·체결시각·손익유형 1문장. 가능하면 진입/청산 변동률(%) 표기. [거래 근거]

(계획↔실행↔결과 2~3줄)
- 계획: 목표가/손절/시간 규율 존재 여부 및 기준. [일지/거래]
- 실행: 실제 체결가·수량·시간. 계획 대비 차이. [거래]
- 결과: 손익 유형 및 근거 수치. [거래/시세 윈도우]

---
## 2) 감정·행동 패턴
- 상위 감정 태그: $emoTop  /  상위 행동 태그: $behTop  [일지]
- 태그가 의사결정에 미친 경로 1~2문장. [일지/거래]
- 개선 가이드: 수치 포함 규칙 1~2개. [원칙]

---
## 3) 투자 성향 프로필 대비 점검
- 위험 성향/손실 허용/목표와 오늘 실행 간 합치·이탈 3~4줄. [프로필/거래]
- 포지션 사이징/시간 규율/테마 민감도 리스크 1~2줄. [거래/시세]

---
## 4) 시장 환경·뉴스
- 시세(일중/일봉): 레인지·변동률·거래량 특이. [시세 윈도우]
- $tickerName 관련 뉴스는 **시간대별 묶음**으로 주제·이슈군 요약. (예: "10~11시: 반도체 수요 회복 기사 다수")  
- 거시·섹터 영향이 있으면 간단히 덧붙여요.

---
## 5) 오늘의 키 인사이트 (재현 가능)
- '상황 → 행동 → 결과 → 교훈' 형식 3~5개, 각 1문장. 수치·트리거 포함. [각 근거]
''';

    return '''
당신은 한국어 해요체로 작성하는 리서치 애널리스트입니다. 아래 JSON(payload)을 바탕으로, **$tickerName 중심의 일일 리포트**를 작성하세요.

$rules

[템플릿 — 이 형식을 그대로 채울 것]
$template

[입력(JSON)]
${jsonEncode(payload)}
''';
  }

  // ─────────────────────────────────────────────────────────────────────────
  // 4) OpenAI 호출
  // ─────────────────────────────────────────────────────────────────────────
  Future<String?> _requestDailyReport(String promptText) async {
    if (_openAIKey.isEmpty) {
      throw StateError('OPENAI_API_KEY 가 설정되지 않았습니다. --dart-define=OPENAI_API_KEY=... 로 전달하세요.');
    }

    try {
      final res = await _openai.post(
        '/chat/completions',
        data: {
          'model': _openAIModel,
          'messages': [
            {'role': 'system', 'content': _systemPrompt},
            {'role': 'user', 'content': promptText},
          ],
          'temperature': 0.3,
          'max_tokens': 1800,
        },
      );
      final choices = res.data?['choices'] as List?;
      if (choices == null || choices.isEmpty) return null;
      final msg = (choices.first as Map)['message'] as Map?;
      final content = msg?['content']?.toString();
      return content;
    } on DioException catch (e) {
      final status = e.response?.statusCode;
      final data = e.response?.data;
      debugPrint('🔴 OpenAI 실패 status=$status data=$data');
      rethrow;
    }
  }
}
