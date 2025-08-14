import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'api_client.dart';

class TradeSummary {
  final int id;
  final String title;
  final DateTime completedTime;
  final bool hasJournal;
  final int? journalId;
  final String? stockName;
  final String? stockCode;
  final String? actionType;
  final String? orderType;
  final num? pricePerSell;
  final num? pricePerBuy;
  final num? marketPriceAtOrder;
  final num? totalAmount;
  final num? quantity;
  final String? orderTime;
  final String? resultType;

  TradeSummary({
    required this.id,
    required this.title,
    required this.completedTime,
    required this.hasJournal,
    required this.journalId,
    this.stockName,
    this.stockCode,
    this.actionType,
    this.orderType,
    this.pricePerSell,
    this.pricePerBuy,
    this.marketPriceAtOrder,
    this.totalAmount,
    this.quantity,
    this.orderTime,
    this.resultType,
  });

  factory TradeSummary.fromJson(Map<String, dynamic> json) {
    DateTime _parseDate(dynamic v) {
      final s = v?.toString();
      if (s == null || s.isEmpty) return DateTime.now();
      for (final fmt in [
        "yyyy-MM-dd'T'HH:mm:ss.SSSSSS",
        "yyyy-MM-dd'T'HH:mm:ss.SSS",
        "yyyy-MM-dd'T'HH:mm:ss",
        "yyyy-MM-dd HH:mm:ss",
      ]) {
        try { return DateFormat(fmt).parseUtc(s).toLocal(); } catch (_) {}
        try { return DateFormat(fmt).parse(s, true).toLocal(); } catch (_) {}
      }
      try { return DateTime.parse(s).toLocal(); } catch (_) {}
      return DateTime.now();
    }

    return TradeSummary(
      id: (json['id'] as num).toInt(),
      title: json['title']?.toString() ?? (json['stockName']?.toString() ?? '거래'),
      completedTime: _parseDate(json['completedTime'] ?? json['completionTime']),
      hasJournal: (json['hasJournal'] == true) || (json['journalId'] != null),
      journalId: (json['journalId'] is num)
          ? (json['journalId'] as num).toInt()
          : int.tryParse('${json['journalId'] ?? ''}'),
      stockName: json['stockName']?.toString(),
      stockCode: json['stockCode']?.toString(),
      actionType: json['actionType']?.toString(),
      orderType: json['orderType']?.toString(),
      pricePerSell: json['pricePerSell'] as num?,
      pricePerBuy: json['pricePerBuy'] as num?,
      marketPriceAtOrder: json['marketPriceAtOrder'] as num?,
      totalAmount: json['totalAmount'] as num?,
      quantity: json['quantity'] as num?,
      orderTime: json['orderTime']?.toString(),
      resultType: json['resultType']?.toString(),
    );
  }
}

class TradePage {
  final List<TradeSummary> items;
  final int totalPages;
  final bool last;

  TradePage({required this.items, required this.totalPages, required this.last});
}

class TradeService {
  final ApiClient _api = ApiClient();

  Future<TradePage> fetchTrades({
    required String month, // yyyy-MM
    int page = 0,
    int size = 20,
  }) async {
    final res = await _api.client.get(
      '/api/trades',
      queryParameters: {
        'month': month,
        'page': page,
        'size': size,
      },
    );

    final data = res.data?['data']?['trades'] as Map<String, dynamic>?;
    final content = (data?['content'] as List?) ?? const [];
    final totalPages = (data?['totalPages'] as num?)?.toInt()
        ?? ((data?['last'] == true) ? page + 1 : page + 1);
    final last = data?['last'] == true;

    final items = <TradeSummary>[];
    for (final e in content) {
      if (e is Map<String, dynamic>) items.add(TradeSummary.fromJson(e));
    }

    return TradePage(items: items, totalPages: totalPages, last: last);
  }
}
