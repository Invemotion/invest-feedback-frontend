// lib/api/journal_service.dart
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'api_client.dart';

class Journal {
  final int id;
  final int tradeId;
  final int userId;
  final String reason;
  final String emotion;   // 예: ANXIETY
  final String behavior;  // 예: EARLY_SELL
  final DateTime createdAt;
  final DateTime updatedAt;

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
    // createdAt / updatedAt 예: 2025-08-08T17:40:28.513149
    DateTime _parse(String s) =>
        DateFormat("yyyy-MM-ddTHH:mm:ss.SSSSSS").parse(s, true).toLocal();

    return Journal(
      id: json['id'] as int,
      tradeId: json['tradeId'] as int,
      userId: json['userId'] as int,
      reason: json['reason'] as String? ?? '',
      emotion: json['emotion'] as String? ?? '',
      behavior: json['behavior'] as String? ?? '',
      createdAt: _parse(json['createdAt'] as String),
      updatedAt: _parse(json['updatedAt'] as String),
    );
  }
}

class JournalService {
  final ApiClient _api = ApiClient();

  /// tradeId 기준 단건 조회
  Future<Journal?> getByTradeId(int tradeId) async {
    try {
      final res = await _api.client.get('/api/journals/$tradeId');
      final data = res.data?['data'];
      if (data is Map<String, dynamic>) {
        return Journal.fromJson(data);
      }
      // 데이터 없음 케이스(문서: data.tradeJournals=[]): null 반환
      return null;
    } on DioException catch (e) {
      // 400 등 실패 시 null
      return null;
    }
  }
}
