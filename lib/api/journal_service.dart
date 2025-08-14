import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'api_client.dart';

class Journal {
  final int id;
  final int tradeId;
  final int userId;
  final String reason;
  final String emotion;   // EXPECTATION, CERTAINTY, ... (예: HEAD/ai_report 설명 결합)
  final String behavior;  // EMOTIONAL_ENTRY, CHASING_BUY, EARLY_SELL 등
  final DateTime createdAt;
  final DateTime? updatedAt; // nullable

  Journal({
    required this.id,
    required this.tradeId,
    required this.userId,
    required this.reason,
    required this.emotion,
    required this.behavior,
    required this.createdAt,
    required this.updatedAt,
  });

  factory Journal.fromJson(Map<String, dynamic> json) {
    DateTime? _parseNullable(dynamic v) {
      if (v == null) return null;
      final s = v.toString().trim();
      if (s.isEmpty) return null;
      try { return DateTime.parse(s).toLocal(); } catch (_) {}
      try { return DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSSSSS").parse(s, true).toLocal(); } catch (_) {}
      try { return DateFormat("yyyy-MM-dd'T'HH:mm:ss.SSS").parse(s, true).toLocal(); } catch (_) {}
      try { return DateFormat("yyyy-MM-dd'T'HH:mm:ss").parse(s, true).toLocal(); } catch (_) {}
      return null;
    }
    DateTime _parseRequired(dynamic v) => _parseNullable(v) ?? DateTime.now();

    return Journal(
      id: (json['id'] as num).toInt(),
      tradeId: (json['tradeId'] as num).toInt(),
      userId: (json['userId'] as num).toInt(),
      reason: json['reason'] as String? ?? '',
      emotion: json['emotion'] as String? ?? '',
      behavior: json['behavior'] as String? ?? '',
      createdAt: _parseRequired(json['createdAt']),
      updatedAt: _parseNullable(json['updatedAt']),
    );
  }
}

class JournalService {
  final ApiClient _api = ApiClient();

  /// ✅ 저널 단건 조회: GET /api/journals/{journalId}
  /// 404 등 응답 시 → 미작성/삭제로 간주
  Future<Journal?> getByJournalId(int journalId) async {
    try {
      final res = await _api.client.get('/api/journals/$journalId');
      final data = res.data?['data'];
      if (data is Map<String, dynamic> && data.isNotEmpty) {
        return Journal.fromJson(data);
      }
      return null;
    } on DioException catch (_) {
      return null;
    }
  }

  /// 생성: POST /api/trades/{tradeId}/journal
  Future<Journal> create({
    required int tradeId,
    required String reason,
    required String? emotion,
    required String? behavior,
  }) async {
    final body = {
      'reason': reason,
      'emotion': emotion,
      'behavior': behavior,
    };
    final res = await _api.client.post('/api/trades/$tradeId/journal', data: body);
    final data = res.data?['data'] as Map<String, dynamic>;
    return Journal.fromJson(data);
  }

  /// 수정: PUT /api/journals/{journalId}
  /// (서버 스펙 유지 — 일부 구간에서는 tradeId 기반 호출도 사용 가능)
  Future<Journal> update({
    required int journalId,
    required String reason,
    required String? emotion,
    required String? behavior,
  }) async {
    final res = await _api.client.put(
      '/api/journals/$journalId',
      data: {
        'reason': reason,
        'emotion': emotion,
        'behavior': behavior,
      },
    );
    final data = res.data?['data'] as Map<String, dynamic>;
    return Journal.fromJson(data);
  }
}
