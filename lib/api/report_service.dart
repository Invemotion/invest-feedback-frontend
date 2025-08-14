import 'package:dio/dio.dart';
import 'api_client.dart';

class ReportItem {
  final int id;
  final DateTime reportDate;
  final String content;

  ReportItem({required this.id, required this.reportDate, required this.content});

  factory ReportItem.fromJson(Map<String, dynamic> j) {
    return ReportItem(
      id: j['id'] as int,
      reportDate: DateTime.parse(j['reportDate'] as String),
      content: (j['content'] ?? '') as String,
    );
  }
}

class ReportService {
  final Dio _http = ApiClient().client;
  final int _userId;

  ReportService({int userId = 1}) : _userId = userId;

  Future<List<ReportItem>> fetchReports({
    required String month, // 'yyyy-MM'
    int page = 0,
    int size = 50,
  }) async {
    final resp = await _http.get(
      '/api/reports',
      queryParameters: {'month': month, 'page': page, 'size': size},
      options: Options(headers: {'X-User-id': _userId}),
    );
    final data = resp.data['data'];
    if (data == null) return const [];
    final reports = data['reports'];
    if (reports == null) return const [];
    final content = reports['content'] as List<dynamic>? ?? const [];
    return content.map((e) => ReportItem.fromJson(e as Map<String, dynamic>)).toList();
  }
}
