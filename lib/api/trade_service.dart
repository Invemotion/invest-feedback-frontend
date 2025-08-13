import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'api_client.dart';

class TradeItem {
  final int id;                // trade PK
  final String title;
  final DateTime completedTime;
  final bool hasJournal;
  final int? journalId;

  TradeItem({
    required this.id,
    required this.title,
    required this.completedTime,
    required this.hasJournal,
    required this.journalId,
  });

  factory TradeItem.fromJson(Map<String, dynamic> json) {
    final raw = json['completedTime'] as String?;
    final dt = raw == null
        ? DateTime.now()
        : DateFormat('yyyy-MM-dd HH:mm:ss').parse(raw);

    final qty = json['quantity'];
    final act = json['actionType'] ?? '';
    final name = json['stockName'] ?? '';

    return TradeItem(
      id: (json['id'] as num).toInt(),
      title: '$name $act ${qty ?? ''}주',
      completedTime: dt,
      hasJournal: (json['hasJournal'] as bool?) ?? false,
      journalId: (json['journalId'] as num?)?.toInt(),
    );
  }
}

class TradeResult {
  final List<TradeItem> items;
  final int totalPages;
  TradeResult({required this.items, required this.totalPages});
}

class TradeService {
  final ApiClient _api = ApiClient();

  Future<TradeResult> fetchTrades({
    required String month,
    required int page,
    required int size,
  }) async {
    try {
      final res = await _api.client.get(
        '/api/trades',
        queryParameters: {
          'month': month, // ex) 2025-08
          'page': page,   // 0-base
          'size': size,   // page size
        },
      );

      // 성공 응답 스펙: data.trades.content / page / size / totalElements / last
      final data = res.data;
      final trades = data['data']?['trades'];
      final List content = (trades?['content'] as List?) ?? const [];

      final int totalElements = trades?['totalElements'] is int
          ? trades['totalElements'] as int
          : int.tryParse('${trades?['totalElements']}') ?? content.length;

      final int pageSize = trades?['size'] is int
          ? trades['size'] as int
          : int.tryParse('${trades?['size']}') ?? size;

      final items = content
          .map((e) => TradeItem.fromJson(e as Map<String, dynamic>))
          .toList();

      final totalPages = pageSize > 0
          ? (totalElements + pageSize - 1) ~/ pageSize // 올림 나눗셈
          : 1;

      return TradeResult(items: items, totalPages: totalPages);
    } on DioException catch (e) {
      // 실패 시 UI가 죽지 않도록 빈 결과 반환
      return TradeResult(items: const [], totalPages: 0);
    }
  }
}
