// lib/common/report_type.dart
enum ReportType { day, month, year }

extension ReportTypeApi on ReportType {
  String get apiValue {
    switch (this) {
      case ReportType.day:
        return 'DAILY';
      case ReportType.month:
        return 'MONTHLY';
      case ReportType.year:
        return 'YEARLY';
    }
  }

  String get labelKo {
    switch (this) {
      case ReportType.day:
        return '일별 리포트';
      case ReportType.month:
        return '월별 리포트';
      case ReportType.year:
        return '연간 리포트';
    }
  }
}
