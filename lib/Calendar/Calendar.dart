// lib/Calendar/Calendar.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../Tools/Appbar/MyAppBar.dart';
import '../../Tools/Color/Colors.dart';
import 'daydetailpage.dart';

import '../../api/api_client.dart';
import '../../api/trade_service.dart';
import 'package:dio/dio.dart' show DioException; // ← 추가


enum ReportType { day, month, year }

class Calendar extends StatefulWidget {
  const Calendar({Key? key}) : super(key: key);

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  DateTime _focusedDay = DateTime.now();
  ReportType _reportType = ReportType.day;
  DateTime _reportDate = DateTime.now();

  late final TradeService _tradeApi;
  final Map<String, List<Map<String, Object?>>> _byDate = {};

  // 연/월/일 리스트
  final List<int> _years = List.generate(10, (i) => DateTime.now().year - i);
  final List<int> _months = List.generate(12, (i) => i + 1);
  final List<int> _days = List.generate(31, (i) => i + 1);

  // ── 날짜 유틸 ─────────────────────────────────────────────────────────────
  int _daysInMonth(int year, int month) {
    final first = DateTime(year, month, 1);
    final nextFirst = DateTime(year, month + 1, 1);
    return nextFirst.subtract(const Duration(days: 1)).day;
  }

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
  }

  void _setReportYear(int year) {
    setState(() {
      final month = _reportDate.month;
      final dayMax = _daysInMonth(year, month);
      final day = _reportDate.day.clamp(1, dayMax);
      _reportDate = DateTime(year, month, day);
    });
  }

  void _setReportMonth(int month) {
    setState(() {
      final year = _reportDate.year;
      final dayMax = _daysInMonth(year, month);
      final day = _reportDate.day.clamp(1, dayMax);
      _reportDate = DateTime(year, month, day);
    });
  }

  void _setReportDay(int day) {
    setState(() {
      _reportDate = DateTime(_reportDate.year, _reportDate.month, day);
    });
  }

  // ── API 연동 ─────────────────────────────────────────────────────────────
  @override
  void initState() {
    super.initState();
    _tradeApi = TradeService();
    _loadMonth(_focusedDay);
  }


  Future<void> _loadMonth(DateTime focus) async {
    final month = DateFormat('yyyy-MM').format(focus);
    int page = 0;
    const size = 20;

    _byDate.clear();
    print("🟡 [_loadMonth] start month=$month");

    while (true) {
      final result = await _tradeApi.fetchTrades(month: month, page: page, size: size);

      for (final t in result.items) {
        final key = DateFormat('yyyy-MM-dd').format(t.completedTime);
        final item = {
          'title': t.title,
          'start': DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(t.completedTime),
          'end': DateFormat('yyyy-MM-dd HH:mm:ss.SSS').format(t.completedTime),
          'tradeId': t.id,
          'hasJournal': t.hasJournal,   // ← 이게 꼭 들어가야 함
          'journalId': t.journalId,
        };
        (_byDate[key] ??= []).add(item);
        print("✅ loaded $key");
      }

      if (page + 1 >= result.totalPages || result.items.isEmpty) break;
      page++;
    }
    setState(() {});
  }

  bool _hasEvents(DateTime day) => _byDate.containsKey(_key(day));
  // 날짜를 'yyyy-MM-dd' 문자열로
  String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);


// 이벤트 로더: 매매=trade, 저널=journal
  List<String> _getEventsForDay(DateTime day) {
    final key = _key(day);
    final list = _byDate[key];
    if (list == null || list.isEmpty) return const [];

    final hasTrade = true; // _byDate에 기록이 있으면 매매 있음
    final hasJournal = list.any((e) => (e['hasJournal'] as bool?) == true);

    final events = <String>[];
    if (hasTrade) events.add('trade');       // 노란 점
    if (hasJournal) events.add('journal');   // 검정 점
    return events;
  }


  // ── build ────────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    final mediaW = MediaQuery.of(context).size.width;

    return Scaffold(
      appBar: MyAppBar(appBar: AppBar(), title: '주식 일지'),
      body: SingleChildScrollView(
        child: SafeArea(
          child: Column(
            children: [
              // ── 캘린더 ──
              Container(
                margin:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.grey, blurRadius: 8, spreadRadius: -4),
                  ],
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2029, 12, 31),
                  focusedDay: _focusedDay,

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
                    leftChevronIcon:
                    Icon(Icons.chevron_left, color: MainColors.kbDarkGray),
                    rightChevronIcon:
                    Icon(Icons.chevron_right, color: MainColors.kbDarkGray),
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

                  calendarFormat: CalendarFormat.month,
                  availableGestures: AvailableGestures.all,
                  rowHeight: 60,
                  daysOfWeekHeight: 60,

                  eventLoader: _getEventsForDay,
                  selectedDayPredicate: (_) => false,
                  onDaySelected: (sel, foc) {
                    setState(() => _focusedDay = foc);

                    final raw = _byDate[_key(sel)] ?? <Map<String, Object?>>[];
                    final toShow = raw.map((e) => {
                      'title': (e['title'] ?? '') as String,
                      'start': (e['start'] ?? '') as String,
                      'end'  : (e['end']   ?? '') as String,
                      'tradeId': e['tradeId'].toString(),
                    }).toList();

                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => DayDetailPage(date: sel, schedules: toShow),
                      ),
                    );
                  },



                  // 월 넘길 때 서버 재호출
                  onPageChanged: (foc) {
                    _focusedDay = foc;
                    _loadMonth(foc);
                  },

                  // 커스텀 마커: 하단 점
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
                                  width: 6, height: 6,
                                  margin: const EdgeInsets.symmetric(horizontal: 2),
                                  decoration: const BoxDecoration(
                                    color: MainColors.sheet3mVt10891, // 노란색(매매)
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              if (hasJournal)
                                Container(
                                  width: 6, height: 6,
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

              // ── 리포트 타입 + 날짜 선택(오른쪽 정렬) ──
              Padding(
                padding:
                const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                child: Row(
                  children: [
                    DropdownButton<ReportType>(
                      value: _reportType,
                      underline: const SizedBox.shrink(),
                      items: const [
                        DropdownMenuItem(
                          value: ReportType.day,
                          child: Text('일별 리포트',
                              style: TextStyle(
                                  fontFamily: 'KBFGText', fontSize: 15)),
                        ),
                        DropdownMenuItem(
                          value: ReportType.month,
                          child: Text('월별 리포트',
                              style: TextStyle(
                                  fontFamily: 'KBFGText', fontSize: 15)),
                        ),
                        DropdownMenuItem(
                          value: ReportType.year,
                          child: Text('연간 리포트',
                              style: TextStyle(
                                  fontFamily: 'KBFGText', fontSize: 15)),
                        ),
                      ],
                      onChanged: (t) => _setReportType(t!),
                    ),

                    const Spacer(),

                    DropdownButton<int>(
                      value: _reportDate.year,
                      underline: const SizedBox.shrink(),
                      items: _years
                          .map((y) => DropdownMenuItem(
                        value: y,
                        child: Text('$y년',
                            style: const TextStyle(
                                fontFamily: 'KBFGText')),
                      ))
                          .toList(),
                      onChanged: (y) => _setReportYear(y!),
                    ),

                    if (_reportType != ReportType.year) ...[
                      const SizedBox(width: 6),
                      DropdownButton<int>(
                        value: _reportDate.month,
                        underline: const SizedBox.shrink(),
                        items: _months
                            .map((m) => DropdownMenuItem(
                          value: m,
                          child: Text('$m월',
                              style: const TextStyle(
                                  fontFamily: 'KBFGText')),
                        ))
                            .toList(),
                        onChanged: (m) => _setReportMonth(m!),
                      ),
                    ],

                    if (_reportType == ReportType.day) ...[
                      const SizedBox(width: 6),
                      DropdownButton<int>(
                        value: _reportDate.day.clamp(
                          1,
                          _daysInMonth(
                              _reportDate.year, _reportDate.month),
                        ),
                        underline: const SizedBox.shrink(),
                        items: List<int>.generate(
                          _daysInMonth(
                              _reportDate.year, _reportDate.month),
                              (i) => i + 1,
                        )
                            .map((d) => DropdownMenuItem(
                          value: d,
                          child: Text('$d일',
                              style: const TextStyle(
                                  fontFamily: 'KBFGText')),
                        ))
                            .toList(),
                        onChanged: (d) => _setReportDay(d!),
                      ),
                    ],
                  ],
                ),
              ),

              // ── 리포트 내용 ──
              Container(
                width: mediaW,
                margin: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.grey, blurRadius: 8, spreadRadius: -4),
                  ],
                ),
                child: Text(
                  '${DateFormat('yyyy-MM-dd').format(_reportDate)}의 ${_reportType.name} 리포트 내용',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontFamily: 'KBFGText',
                    fontWeight: FontWeight.w400,
                    fontSize: 15,
                    color: MainColors.kbDarkGray,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
