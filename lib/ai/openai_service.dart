// lib/ai/openai_service.dart
import 'package:dio/dio.dart';

class OpenAIService {
  final Dio _dio;
  final String _apiKey;

  OpenAIService({Dio? dio, String? apiKey})
      : _dio = dio ?? Dio(),
        _apiKey = apiKey ?? const String.fromEnvironment('OPENAI_API_KEY');

  Future<String> chat({
    required String prompt,
    String model = 'gpt-4o-mini',
    int maxTokens = 1800,
    double temperature = 0.3,
  }) async {
    if (_apiKey.isEmpty) {
      throw 'OPENAI_API_KEY 미설정 (flutter run --dart-define=OPENAI_API_KEY=...)';
    }

    final res = await _dio.post(
      'https://api.openai.com/v1/chat/completions',
      options: Options(headers: {
        'Authorization': 'Bearer $_apiKey',
        'Content-Type': 'application/json',
      }),
      data: {
        'model': model,
        'temperature': temperature,
        'max_tokens': maxTokens,
        'messages': [
          {
            'role': 'system',
            'content':
            '너는 한국어 리서치 애널리스트다. 수치·시간·근거 중심 보고서 톤. 각 주장 뒤엔 근거 표기(예: [거래 10:22], [뉴스 05:00], [시세 ±30m 윈도우]).'
          },
          {'role': 'user', 'content': prompt},
        ],
      },
    );

    final choices = res.data['choices'] as List?;
    final content =
    (choices != null && choices.isNotEmpty) ? (choices.first['message']?['content'] ?? '') : '';
    return (content is String) ? content : content.toString();
  }
}
