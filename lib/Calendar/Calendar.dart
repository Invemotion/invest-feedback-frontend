// lib/Calendar/Calendar.dart
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:dio/dio.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

import '../../Tools/Appbar/MyAppBar.dart';
import '../../Tools/Color/Colors.dart';
import 'daydetailpage.dart';

import '../../api/api_client.dart';
import '../../api/trade_service.dart';
import '../../common/report_type.dart';

class Calendar extends StatefulWidget {
  const Calendar({Key? key}) : super(key: key);

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  // 캘린더 상태
  DateTime _focusedDay = DateTime.now();

  // 리포트 상태
  ReportType _reportType = ReportType.day;
  DateTime _reportDate = DateTime.now();

  // API
  late final TradeService _tradeApi;
  final Dio _http = ApiClient().client;
  final int _userId = 1;

  // 날짜별 이벤트(매매/저널)
  final Map<String, List<Map<String, Object?>>> _byDate = {};

  // 리포트 뷰어
  bool _loadingReport = false;
  String? _reportContent;

  // ──────────────────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tradeApi = TradeService();
    _loadMonth(_focusedDay);
    _loadReportForSelection();
  }

  // 유틸
  String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  int _daysInMonth(int year, int month) {
    final first = DateTime(year, month, 1);
    final nextFirst = DateTime(year, month + 1, 1);
    return nextFirst.subtract(const Duration(days: 1)).day;
  }

  String _reportTypeKo() {
    switch (_reportType) {
      case ReportType.day:
        return '일별';
      case ReportType.month:
        return '주간';
      case ReportType.year:
        return '월간';
    }
  }

  // 타입 변경시 날짜 정규화 + 리포트 로드
  void _setReportType(ReportType t) {
    setState(() {
      _reportType = t;
      if (_reportType == ReportType.year) {
        _reportDate = DateTime(_reportDate.year, 1, 1);
      } else if (_reportType == ReportType.month) {
        _reportDate = DateTime(_reportDate.year, _reportDate.month, 1);
      } else {
        final lastDay = _daysInMonth(_reportDate.year, _reportDate.month);
        final safeDay = (_reportDate.day <= lastDay) ? _reportDate.day : lastDay;
        _reportDate = DateTime(_reportDate.year, _reportDate.month, safeDay);
      }
    });
    _loadReportForSelection();
  }

  // 월 데이터 로드(매매/저널 점)
  Future<void> _loadMonth(DateTime focus) async {
    final month = DateFormat('yyyy-MM').format(focus);
    int page = 0;
    const size = 20;

    _byDate.clear();

    while (true) {
      final result = await _tradeApi.fetchTrades(month: month, page: page, size: size);

      for (final t in result.items) {
        final key = DateFormat('yyyy-MM-dd').format(t.completedTime);
        final item = {
          'title': t.title,
          'start': DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(t.completedTime),
          'end': DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(t.completedTime),
          'tradeId': t.id,
          'hasJournal': t.hasJournal,
          'journalId': t.journalId,
        };
        (_byDate[key] ??= []).add(item);
      }

      if (page + 1 >= result.totalPages || result.items.isEmpty) break;
      page++;
    }

    if (mounted) setState(() {});
  }

  // 선택 시점 리포트 로드(현재는 일별만)
  Future<void> _loadReportForSelection() async {
    setState(() {
      _loadingReport = true;
      _reportContent = null;
    });

    try {
      final month = DateFormat('yyyy-MM').format(_reportDate);
      final resp = await _http.get(
        '/api/reports',
        queryParameters: {'month': month, 'page': 0, 'size': 50},
        options: Options(headers: {'X-User-id': _userId}),
      );

      final list = (resp.data?['data']?['reports']?['content'] as List?) ?? const [];

      String? content;
      if (_reportType == ReportType.day) {
        final dStr = DateFormat('yyyy-MM-dd').format(_reportDate);
        for (final m in list) {
          if (m is Map && m['reportDate'] == dStr) {
            content = (m['content'] ?? '') as String;
            break;
          }
        }
      } else {
        content = null; // 월/연은 추후 확장
      }

      if (mounted) setState(() => _reportContent = content);
    } catch (e) {
      debugPrint('GET /api/reports error: $e');
      if (mounted) setState(() => _reportContent = null);
    } finally {
      if (mounted) setState(() => _loadingReport = false);
    }
  }

  // 캘린더 이벤트 로더(점)
  List<String> _getEventsForDay(DateTime day) {
    final key = _key(day);
    final list = _byDate[key];
    if (list == null || list.isEmpty) return const [];
    final hasTrade = true;
    final hasJournal = list.any((e) => (e['hasJournal'] as bool?) == true);
    final events = <String>[];
    if (hasTrade) events.add('trade');
    if (hasJournal) events.add('journal');
    return events;
  }

  // ───────────── 날짜 라벨 & 한국어 휠 선택 ─────────────
  String _dateLabel() {
    switch (_reportType) {
      case ReportType.day:
        return DateFormat('yyyy년 M월 d일').format(_reportDate);
      case ReportType.month:
        return DateFormat('yyyy년 M월').format(_reportDate);
      case ReportType.year:
        return DateFormat('yyyy년').format(_reportDate);
    }
  }

  Future<void> _openDateWheelPicker() async {
    DateTime temp = _reportDate;

    await showCupertinoModalPopup(
      context: context,
      builder: (_) {
        return Localizations.override(
          context: context,
          locale: const Locale('ko', 'KR'),
          child: Material(
            color: Colors.black54,
            child: Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                height: 320,
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
                ),
                child: Column(
                  children: [
                    SizedBox(
                      height: 48,
                      child: Row(
                        children: [
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: const Text('취소', style: TextStyle(color: Colors.black87)),
                            onPressed: () => Navigator.pop(context),
                          ),
                          const Spacer(),
                          CupertinoButton(
                            padding: const EdgeInsets.symmetric(horizontal: 16),
                            child: const Text('완료', style: TextStyle(color: Colors.black87, fontWeight: FontWeight.bold)),
                            onPressed: () {
                              setState(() {
                                if (_reportType == ReportType.year) {
                                  _reportDate = DateTime(temp.year, 1, 1);
                                } else if (_reportType == ReportType.month) {
                                  _reportDate = DateTime(temp.year, temp.month, 1);
                                } else {
                                  _reportDate = DateTime(temp.year, temp.month, temp.day);
                                }
                              });
                              _loadReportForSelection();
                              Navigator.pop(context);
                            },
                          ),
                        ],
                      ),
                    ),
                    const Divider(height: 1),
                    Expanded(
                      child: CupertinoTheme(
                        data: const CupertinoThemeData(
                          primaryColor: Colors.black87,
                          textTheme: CupertinoTextThemeData(
                            dateTimePickerTextStyle: TextStyle(
                              color: Colors.black87,
                              fontSize: 20,
                            ),
                          ),
                        ),
                        child: CupertinoDatePicker(
                          mode: CupertinoDatePickerMode.date,
                          initialDateTime: _reportDate,
                          minimumYear: 2020,
                          maximumYear: 2030,
                          onDateTimeChanged: (d) => temp = d,
                          use24hFormat: true,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  // ───────────── 드롭다운 pill (중앙정렬, 흰색, 둥근) ─────────────
  Widget _typeDropdownPill({double width = 128, double height = 48}) {
    return SizedBox(
      width: width,
      height: height,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: -4)],
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<ReportType>(
            dropdownColor: Colors.white,
            value: _reportType,
            isDense: true,
            isExpanded: true,
            borderRadius: BorderRadius.circular(30),
            icon: const Icon(Icons.expand_more, size: 18, color: MainColors.kbDarkGray),
            style: const TextStyle(fontFamily: 'KBFGText', fontSize: 15, color: MainColors.kbDarkGray),
            items: const [
              DropdownMenuItem(value: ReportType.day,   child: Center(child: Text('일별 리포트'))),
              DropdownMenuItem(value: ReportType.month, child: Center(child: Text('월별 리포트'))),
              DropdownMenuItem(value: ReportType.year,  child: Center(child: Text('연간 리포트'))),
            ],
            onChanged: (t) => _setReportType(t!),
          ),
        ),
      ),
    );
  }

  // ───────────── 마크다운 스타일 & 뷰어 ─────────────
  MarkdownStyleSheet _mdStyle(BuildContext context) {
    return MarkdownStyleSheet(
      p: const TextStyle(
        fontFamily: 'KBFGText',
        fontSize: 15,
        height: 1.6,
        color: MainColors.kbDarkGray,
        fontWeight: FontWeight.w400,
      ),
      h1: const TextStyle(
        fontFamily: 'KBFGText',
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: MainColors.kbDarkGray,
      ),
      h2: const TextStyle(
        fontFamily: 'KBFGText',
        fontSize: 18,
        fontWeight: FontWeight.w700,
        color: MainColors.kbDarkGray,
      ),
      h3: const TextStyle(
        fontFamily: 'KBFGText',
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: MainColors.kbDarkGray,
      ),
      listBullet: const TextStyle(
        fontFamily: 'KBFGText',
        fontSize: 16,
        color: MainColors.kbDarkGray,
      ),
      blockSpacing: 10,
      listIndent: 22,
      unorderedListAlign: WrapAlignment.start,
      horizontalRuleDecoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade300, width: 1),
        ),
      ),
      blockquoteDecoration: BoxDecoration(
        color: Colors.grey.shade50,
        border: Border(left: BorderSide(color: Colors.grey.shade300, width: 3)),
      ),
      codeblockPadding: const EdgeInsets.all(10),
      codeblockDecoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }

  Widget _reportMarkdown(String md) {
    final cleaned = md.trim();
    return MarkdownBody(
      data: cleaned,
      selectable: true,
      softLineBreak: true,
      styleSheet: _mdStyle(context),
      onTapLink: (text, href, title) {},
    );
  }

  // ──────────────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mediaW = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: MyAppBar(appBar: AppBar(), title: '주식 일지'),
      body: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SafeArea(
          child: Column(
            children: [
              // ── 캘린더 카드 ──
              Container(
                margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [BoxShadow(color: Colors.grey, blurRadius: 8, spreadRadius: -4)],
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2029, 12, 31),
                  focusedDay: _focusedDay,
                  calendarFormat: CalendarFormat.month,
                  availableGestures: AvailableGestures.all,
                  rowHeight: 60,
                  daysOfWeekHeight: 60,
                  calendarStyle: const CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: MainColors.sheet3mVt10891,
                      shape: BoxShape.circle,
                    ),
                    markersAlignment: Alignment.bottomCenter,
                  ),
                  headerStyle: const HeaderStyle(
                    formatButtonVisible: false,
                    titleCentered: true,
                    titleTextStyle: TextStyle(
                      fontFamily: 'KBFGText',
                      fontWeight: FontWeight.w700,
                      fontSize: 18,
                      color: MainColors.kbDarkGray,
                    ),
                    leftChevronIcon: Icon(Icons.chevron_left, color: MainColors.kbDarkGray),
                    rightChevronIcon: Icon(Icons.chevron_right, color: MainColors.kbDarkGray),
                  ),
                  daysOfWeekStyle: const DaysOfWeekStyle(
                    weekdayStyle: TextStyle(
                      fontFamily: 'KBFGText',
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: MainColors.kbDarkGray,
                    ),
                    weekendStyle: TextStyle(
                      fontFamily: 'KBFGText',
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: MainColors.kbSilver,
                    ),
                  ),
                  eventLoader: _getEventsForDay,
                  selectedDayPredicate: (_) => false,
                  onDaySelected: (sel, foc) async {
                    setState(() => _focusedDay = foc);

                    final raw = _byDate[_key(sel)] ?? <Map<String, Object?>>[];
                    final toShow = raw
                        .map((e) => {
                      'title': (e['title'] ?? '') as String,
                      'start': (e['start'] ?? '') as String,
                      'end': (e['end'] ?? '') as String,
                      'tradeId': e['tradeId'].toString(),
                      'hasJournal': ((e['hasJournal'] as bool?) == true).toString(),
                      'journalId': (e['journalId'] ?? '').toString(),
                    })
                        .toList();

                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DayDetailPage(date: sel, schedules: toShow),
                      ),
                    );
                    await _loadMonth(_focusedDay); // 돌아오면 점 상태 갱신
                  },
                  onPageChanged: (foc) {
                    _focusedDay = foc;
                    _loadMonth(foc);
                  },
                  calendarBuilders: CalendarBuilders(
                    markerBuilder: (context, day, events) {
                      if (events.isEmpty) return const SizedBox.shrink();
                      final hasTrade = events.contains('trade');
                      final hasJournal = events.contains('journal');
                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.only(bottom: 6),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              if (hasTrade)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: const BoxDecoration(
                                    color: MainColors.sheet3mVt10891, // 노란색(매매)
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (hasJournal)
                                Container(
                                  width: 6,
                                  height: 6,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: const BoxDecoration(
                                    color: Colors.black87, // 검정색(저널)
                                    shape: BoxShape.circle,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                ),
              ),

              // ── 리포트 타입(좌) + 날짜 휠(우) ──
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                child: LayoutBuilder(
                  builder: (context, c) {
                    final maxW = c.maxWidth;
                    const spacing = 16.0;
                    const reportW = 128.0;
                    const pillH = 48.0;
                    const minDateW = 180.0;

                    final twoFit = (reportW + spacing + minDateW) <= maxW;

                    if (twoFit) {
                      // 한 줄: 왼쪽 드롭다운, 오른쪽 날짜
                      return Row(
                        children: [
                          _typeDropdownPill(width: reportW, height: pillH),
                          const SizedBox(width: spacing),
                          // 날짜 pill (오른쪽), 너무 넓지 않게 내부 정중앙
                          Expanded(
                            child: SizedBox(
                              height: pillH,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(16),
                                onTap: _openDateWheelPicker,
                                child: Container(
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(16),
                                    boxShadow: const [
                                      BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: -4),
                                    ],
                                  ),
                                  padding: const EdgeInsets.symmetric(horizontal: 16),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Flexible(
                                        child: Text(
                                          _dateLabel(),
                                          overflow: TextOverflow.ellipsis,
                                          textAlign: TextAlign.center,
                                          style: const TextStyle(
                                            fontFamily: 'KBFGText',
                                            fontSize: 15,
                                            color: MainColors.kbDarkGray,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 6),
                                      const Icon(Icons.expand_more, size: 18, color: MainColors.kbDarkGray),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      );
                    }

                    // 작은 화면: 두 줄 배치(넘침 방지)
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _typeDropdownPill(width: reportW, height: pillH),
                        ),
                        const SizedBox(height: 8),
                        SizedBox(
                          height: pillH,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: _openDateWheelPicker,
                            child: Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                boxShadow: const [
                                  BoxShadow(color: Colors.black12, blurRadius: 10, spreadRadius: -4),
                                ],
                              ),
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Flexible(
                                    child: Text(
                                      _dateLabel(),
                                      overflow: TextOverflow.ellipsis,
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(
                                        fontFamily: 'KBFGText',
                                        fontSize: 15,
                                        color: MainColors.kbDarkGray,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  const Icon(Icons.expand_more, size: 18, color: MainColors.kbDarkGray),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),

              // ── 리포트 내용 카드(마크다운) ──
              AnimatedSize(
                duration: const Duration(milliseconds: 200),
                curve: Curves.easeOut,
                child: Container(
                  width: mediaW,
                  margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: const [
                      BoxShadow(color: Colors.grey, blurRadius: 8, spreadRadius: -4),
                    ],
                  ),
                  child: _loadingReport
                      ? const Center(child: CircularProgressIndicator(strokeWidth: 2))
                      : (_reportContent == null || _reportContent!.isEmpty)
                      ? Text(
                    '# ${DateFormat('yyyy-MM-dd').format(_reportDate)} ${_reportTypeKo()} 리포트',
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontFamily: 'KBFGText',
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                      color: MainColors.kbDarkGray,
                    ),
                  )
                      : _reportMarkdown(_reportContent!),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
