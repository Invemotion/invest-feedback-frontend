import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import '../api/trade_service.dart';
import '../api/journal_service.dart';

class AiService {
  // flutter run --dart-define=OPENAI_API_KEY=sk-...
  final String? _openAiKey = const String.fromEnvironment('OPENAI_API_KEY');

  final Dio _dio = Dio(BaseOptions(
    baseUrl: 'https://api.openai.com/v1',
    connectTimeout: const Duration(seconds: 20),
    receiveTimeout: const Duration(seconds: 60),
  ));

  Future<String> generateDailyMarkdown({
    required DateTime date,
    required String tickerName,
    required String tickerCode,
    required List<TradeItem> trades,
    required List<Journal?> journals, // ← 너의 JournalService 모델
    String model = 'gpt-4o-mini',
    int maxTokens = 1400,
  }) async {
    final prompt = _buildPrompt(
      date: date,
      tickerName: tickerName,
      tickerCode: tickerCode,
      trades: trades,
      journals: journals,
    );

    if ((_openAiKey ?? '').isEmpty) {
      return _fallback(date, trades.length);
    }

    final res = await _dio.post(
      '/chat/completions',
      options: Options(
        headers: {
          'Authorization': 'Bearer $_openAiKey',
          'Content-Type': 'application/json',
        },
        validateStatus: (_) => true,
      ),
      data: {
        'model': model,
        'temperature': 0.3,
        'max_tokens': maxTokens,
        'messages': [
          {
            'role': 'system',
            'content':
            '너는 한국어 리서치 애널리스트다. 수치·시간·근거 중심 문체. 각 문장 끝에 [근거] 표기.'
          },
          {'role': 'user', 'content': prompt},
        ],
      },
    );

    if (res.statusCode != 200) return _fallback(date, trades.length);

    final content = res.data?['choices']?[0]?['message']?['content'];
    return (content is String && content.trim().isNotEmpty)
        ? content.trim()
        : _fallback(date, trades.length);
  }

  String _buildPrompt({
    required DateTime date,
    required String tickerName,
    required String tickerCode,
    required List<TradeItem> trades,
    required List<Journal?> journals,
  }) {
    final yyyyMmDd = DateFormat('yyyy-MM-dd').format(date);

    // tradeId로 1:1 매칭 (동일 인덱스 기준)
    final items = <Map<String, Object?>>[];
    for (var i = 0; i < trades.length; i++) {
      final t = trades[i];
      final j = i < journals.length ? journals[i] : null;
      items.add({
        'tradeId': t.id,
        'time': DateFormat('HH:mm').format(t.completedTime),
        'title': t.title,
        'hasJournal': t.hasJournal,
        'journal': j == null
            ? null
            : {
          'reason': j.reason,
          'emotion': j.emotion,
          'behavior': j.behavior,
        },
      });
    }

    final rules = '''
[작성 원칙]
1) 체결가/수량/시간 등 구체 수치 우선(없으면 "데이터 미제공").
2) 각 문장 말미에 근거 각주: [거래 HH:mm], [일지 tradeId=n].
3) (계획→실행→결과→개선) 구조로 간결한 불릿.
4) 과장/칭찬/확신 금지. 보고서 톤.
''';

    final template = '''
# $yyyyMmDd 일일 리포트 — $tickerName($tickerCode)

## 0) 오늘의 한 줄
- 핵심 요약 1~2문장. [근거]

## 1) 거래 요약
- 총 n건 요약 / 대표 1건 상세(체결가/수량/시간/손익유형). [거래 근거]

## 2) 감정·행동 패턴
- 상위 감정/행동 태그 및 의사결정 영향. [일지 근거]
- 개선 가이드 1~2개(수치 포함). [근거]

## 3) 키 인사이트(재현 가능)
- 3~5개 불릿: '상황→행동→결과→교훈'. [근거]
''';

    final payload = jsonEncode({
      'date': yyyyMmDd,
      'ticker': {'name': tickerName, 'code': tickerCode},
      'items': items,
    });

    return '''
당신은 한국어 리서치 애널리스트입니다.
아래 JSON을 바탕으로 템플릿을 그대로 채워주세요.

$rules

[템플릿]
$template

[입력(JSON)]
$payload
''';
  }

  String _fallback(DateTime d, int n) {
    final s = DateFormat('yyyy-MM-dd').format(d);
    return '# $s 일일 리포트\n\n'
        '- 자동 생성 실패로 기본 초안을 저장합니다.\n'
        '- 거래 건수: $n건\n';
  }
}
