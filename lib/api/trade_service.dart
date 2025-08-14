// lib/api/trade_service.dart
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'api_client.dart';
import 'package:dio/dio.dart' show Options;
import '../common/report_type.dart';


class DailyAiReport {
  final String markdown;
  final String reportDate;
  final String ticker;
  DailyAiReport({
    required this.markdown,
    required this.reportDate,
    required this.ticker,
  });

  factory DailyAiReport.fromJson(Map<String, dynamic> json) {
    return DailyAiReport(
      markdown: (json['markdown'] ?? '') as String,
      reportDate: (json['report_date'] ?? '') as String,
      ticker: (json['ticker'] ?? '') as String,
    );
  }
}

class CreatedReport {
  final int id;
  final int userId;
  final String periodType;
  final String reportDate;
  final String content;
  final Map<String, dynamic>? meta;
  final DateTime createdAt;
  final DateTime? updatedAt;

  CreatedReport({
    required this.id,
    required this.userId,
    required this.periodType,
    required this.reportDate,
    required this.content,
    required this.meta,
    required this.createdAt,
    required this.updatedAt,
  });

  factory CreatedReport.fromWrappedJson(Map<String, dynamic> json) {
    final d = (json['data'] as Map<String, dynamic>);
    return CreatedReport(
      id: d['id'] as int,
      userId: d['userId'] as int,
      periodType: d['periodType'] as String,
      reportDate: d['reportDate'] as String,
      content: d['content'] as String,
      meta: d['meta'] == null ? null : Map<String, dynamic>.from(d['meta'] as Map),
      createdAt: DateTime.parse(d['createdAt'] as String),
      updatedAt: d['updatedAt'] == null ? null : DateTime.parse(d['updatedAt'] as String),
    );
  }
}

class TradeItem {
  final int id;
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

// ───────────────────────────────────────────────────────────────────────────
// (D) TradeService 본체 + 리포트 생성/저장 메소드 추가
// ───────────────────────────────────────────────────────────────────────────
class TradeService {
  final ApiClient _api = ApiClient();

  // ---------- 기존 거래 조회 ----------
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
          ? (totalElements + pageSize - 1) ~/ pageSize
          : 1;

      return TradeResult(items: items, totalPages: totalPages);
    } on DioException {
      return TradeResult(items: const [], totalPages: 0);
    }
  }

  // ---------- (신규) 1) AI 일별 리포트 생성 ----------
  //
  // ANDROID 에뮬레이터: 기본값 http://10.0.2.2:8000
  // iOS 시뮬레이터/데스크톱: http://localhost:8000 또는 머신 IP 사용
  // 실행 시 --dart-define=REPORT_GEN_BASE_URL=http://<호스트>:8000 로 오버라이드 가능
  final Dio _gen = Dio(BaseOptions(
    baseUrl: String.fromEnvironment('REPORT_GEN_BASE_URL', defaultValue: 'http://10.0.2.2:8000'),
    connectTimeout: const Duration(seconds: 15),
    receiveTimeout: const Duration(seconds: 60),
  ));

  String _fmtDate(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<DailyAiReport> generateDailyReport({
    required DateTime date,
    int userId = 2,
    String tickerName = '현대차',
    String tickerCode = '005380',
  }) async {
    final resp = await _gen.post('/reports/daily', data: {
      'date': _fmtDate(date),
      'user_id': userId,
      'ticker_name': tickerName,
      'ticker_code': tickerCode,
    });
    return DailyAiReport.fromJson(resp.data as Map<String, dynamic>);
  }

  String _periodTypeString(ReportType t) {
    switch (t) {
      case ReportType.day:
        return 'DAILY';
      case ReportType.month:
        return 'MONTHLY';
      case ReportType.year:
        return 'YEARLY';
    }
  }

  Future<CreatedReport> saveReport({
    required int userId,
    required ReportType periodType,
    required DateTime reportDate,
    required String content,
    Map<String, dynamic>? meta,
  }) async {
    final resp = await _api.client.post(
      '/api/report',
      data: {
        'periodType': _periodTypeString(periodType),
        'reportDate': _fmtDate(reportDate),
        'content': content,
        if (meta != null) 'meta': meta,
      },
      options: Options(headers: {'X-User-id': userId}),
    );
    return CreatedReport.fromWrappedJson(resp.data as Map<String, dynamic>);
  }
}
