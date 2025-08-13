// TODO: 현재는 매매 기록이 있으면 점이 뜨는데, 일지 기록이 있으면 점이 뜨게 바꿔야 함.
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';

import '../../Tools/Appbar/MyAppBar.dart';
import '../../Tools/Color/Colors.dart';
import 'daydetailpage.dart';

enum ReportType { day, month, year }

class Calendar extends StatefulWidget {
  const Calendar({Key? key}) : super(key: key);

  @override
  State<Calendar> createState() => _CalendarState();
}

class _CalendarState extends State<Calendar> {
  DateTime _focusedDay = DateTime.now();
  ReportType _reportType = ReportType.day;

  // ── 더미 거래 내역 (날짜별) ──────────────────────────────────────────────────
  final Map<String, List<Map<String, String>>> _dummyByDate = {
    // 오늘
    DateFormat('yyyy-MM-dd').format(DateTime.now()): [
      {
        'title': 'AAPL 매수 100주',
        'start':
        '${DateFormat('yyyy-MM-dd').format(DateTime.now())} 10:05:00.000',
        'end':
        '${DateFormat('yyyy-MM-dd').format(DateTime.now())} 10:05:00.000',
      },
      {
        'title': 'GOOGL 매도 50주',
        'start':
        '${DateFormat('yyyy-MM-dd').format(DateTime.now())} 12:30:00.000',
        'end':
        '${DateFormat('yyyy-MM-dd').format(DateTime.now())} 12:30:00.000',
      },
      {
        'title': 'TSLA 매수 20주',
        'start':
        '${DateFormat('yyyy-MM-dd').format(DateTime.now())} 15:45:00.000',
        'end':
        '${DateFormat('yyyy-MM-dd').format(DateTime.now())} 15:45:00.000',
      },
    ],

    // 2025-08-04
    '2025-08-04': [
      {
        'title': 'MSFT 매수 30주',
        'start': '2025-08-04 11:15:00.000',
        'end': '2025-08-04 11:15:00.000',
      },
      {
        'title': 'NFLX 매도 10주',
        'start': '2025-08-04 14:20:00.000',
        'end': '2025-08-04 14:20:00.000',
      },
    ],
  };

  // ── 헬퍼 ──────────────────────────────────────────────────────────────────
  String _key(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  bool _hasEvents(DateTime day) => _dummyByDate.containsKey(_key(day));

  List<String> _getEventsForDay(DateTime day) =>
      _hasEvents(day) ? ['거래 내역'] : [];

  // ── build ───────────────────────────────────────────────────────────────
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
                    BoxShadow(color: Colors.grey, blurRadius: 8, spreadRadius: -4)
                  ],
                ),
                child: TableCalendar(
                  firstDay: DateTime.utc(2020, 1, 1),
                  lastDay: DateTime.utc(2029, 12, 31),
                  focusedDay: _focusedDay,

                  // 스타일
                  calendarStyle: CalendarStyle(
                    todayDecoration: BoxDecoration(
                      color: MainColors.sheet3mVt10891,
                      shape: BoxShape.circle,
                    ),
                    selectedDecoration: const BoxDecoration(),
                    markerDecoration: const BoxDecoration(
                      color: MainColors.sheet3mVt10891,
                      shape: BoxShape.circle,
                    ),
                    markerSize: 5,
                    markerMargin: const EdgeInsets.only(top: 6, left: 2, right: 2),
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
                    leftChevronIcon: Icon(Icons.chevron_left,
                        color: MainColors.kbDarkGray),
                    rightChevronIcon: Icon(Icons.chevron_right,
                        color: MainColors.kbDarkGray),
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

                    final toShow = _dummyByDate[_key(sel)] ?? <Map<String, String>>[];
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) =>
                            DayDetailPage(date: sel, schedules: toShow),
                      ),
                    );
                  },
                ),
              ),

              // ── 리포트 드롭다운 ──
              Container(
                padding: const EdgeInsets.only(left: 30),
                alignment: Alignment.centerLeft,
                child: DropdownButton<ReportType>(
                  value: _reportType,
                  underline: const SizedBox.shrink(),
                  icon: const Icon(Icons.keyboard_arrow_down,
                      color: MainColors.kbDarkGray),
                  dropdownColor: Colors.white,
                  borderRadius: BorderRadius.circular(25),
                  items: const [
                    DropdownMenuItem(
                      value: ReportType.day,
                      child: Text(
                        '일별 리포트',
                        style: TextStyle(
                          fontFamily: 'KBFGText',
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: MainColors.kbDarkGray,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: ReportType.month,
                      child: Text(
                        '월별 리포트',
                        style: TextStyle(
                          fontFamily: 'KBFGText',
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: MainColors.kbDarkGray,
                        ),
                      ),
                    ),
                    DropdownMenuItem(
                      value: ReportType.year,
                      child: Text(
                        '연간 리포트',
                        style: TextStyle(
                          fontFamily: 'KBFGText',
                          fontWeight: FontWeight.w500,
                          fontSize: 15,
                          color: MainColors.kbDarkGray,
                        ),
                      ),
                    ),
                  ],
                  onChanged: (t) => setState(() => _reportType = t!),
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
                    BoxShadow(color: Colors.grey, blurRadius: 8, spreadRadius: -4)
                  ],
                ),
                child: Text(
                  _reportType == ReportType.day
                      ? '일별 리포트 내용\n입니다'
                      : _reportType == ReportType.month
                      ? '월별 리포트 내용\n월별 리포트 내용\n월별 리포트 내용\n월별 리포트 내용\n월별 리포트 내용\n월별 리포트 내용\n월별 리포트 내용\n월별 리포트 내용\n'
                      : '연간 리포트 내용',
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
