// lib/Calendar/daydetailpage.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:dio/dio.dart'; // ← 추가
import '../../Tools/Appbar/MyAppBar.dart';
import '../../Tools/Color/Colors.dart';
import 'package:flutter/services.dart';

class DayDetailPage extends StatefulWidget {
  const DayDetailPage({
    super.key,
    required this.date,
    required this.schedules,
  });

  final DateTime date;
  final List<Map<String, String>> schedules;

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  late final List<TextEditingController> _controllers;

  // 감정/행동 한글 라벨
  final List<String> _emotions = [
    '기대', '확신', '불안', '기쁨', '후회', '무감정', '아쉬움'
  ];
  final List<String> _actions = [
    '추격매수', '분할진입', '감정적 진입',
    '전략적 정리', '분할매도', '조기매도',
    '손절지연', '시장 추종', '불안정 매도'
  ];

  // 백엔드 ENUM → 한글 라벨 매핑
  final Map<String, String> emotionMap = {
    "EXPECTATION": "기대",
    "CERTAINTY": "확신",
    "ANXIETY": "불안",
    "JOY": "기쁨",
    "REMORSE": "후회",
    "NEUTRAL": "무감정",
    "REGRET": "아쉬움",
  };
  final Map<String, String> behaviorMap = {
    "CHASING_BUY": "추격매수",
    "DIVIDED_ENTRY": "분할진입",
    "EMOTIONAL_ENTRY": "감정적 진입",
    "STRATEGIC_EXIT": "전략적 정리",
    "DIVIDED_SELL": "분할매도",
    "EARLY_SELL": "조기매도",
    "DELAYED_STOP": "손절지연",
    "MARKET_FOLLOW": "시장 추종",
    "UNSTABLE_SELL": "불안정 매도",
  };

  late final List<List<bool>> _emotionsSelected;
  late final List<List<bool>> _actionsSelected;

  @override
  void initState() {
    super.initState();
    _controllers =
        List.generate(widget.schedules.length, (_) => TextEditingController());

    _emotionsSelected = List.generate(
      widget.schedules.length,
          (_) => List<bool>.filled(_emotions.length, false),
    );
    _actionsSelected = List.generate(
      widget.schedules.length,
          (_) => List<bool>.filled(_actions.length, false),
    );

    _loadJournals();
  }

  Future<void> _loadJournals() async {
    final dioClient = Dio();
    for (int i = 0; i < widget.schedules.length; i++) {
      final tradeId = widget.schedules[i]['tradeId'];
      if (tradeId == null) continue;

      final resp = await dioClient.get(
        'http://13.124.208.84:8080/api/journals/$tradeId',
        options: Options(headers: {'X-User-id': '2'}),
      );

      final data = resp.data['data'];
      if (data != null && data.isNotEmpty) {
        _controllers[i].text = data['reason'] ?? '';
        _setSelectedFromEnum(i, data['emotion'], data['behavior']);
      }
    }
    setState(() {}); // UI 반영
  }

  void _setSelectedFromEnum(int i, String? emotion, String? behavior) {
    if (emotion != null && emotionMap.containsKey(emotion)) {
      final label = emotionMap[emotion]!;
      final idx = _emotions.indexOf(label);
      if (idx != -1) _emotionsSelected[i][idx] = true;
    }
    if (behavior != null && behaviorMap.containsKey(behavior)) {
      final label = behaviorMap[behavior]!;
      final idx = _actions.indexOf(label);
      if (idx != -1) _actionsSelected[i][idx] = true;
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final title = DateFormat('yyyy년 M월 d일').format(widget.date);

    return Scaffold(
      appBar: MyAppBar(appBar: AppBar(), title: title),
      body: widget.schedules.isEmpty
          ? _buildEmpty()
          : ListView.builder(
        padding: const EdgeInsets.symmetric(vertical: 10),
        itemCount: widget.schedules.length,
        itemBuilder: (context, i) => _buildScheduleTile(i),
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: const [
        Icon(Icons.find_in_page_outlined, size: 64, color: Colors.black26),
        SizedBox(height: 16),
        Text(
          '조회 내역이 없습니다.',
          style: TextStyle(
            fontFamily: 'KBFGText',
            fontWeight: FontWeight.w500,
            fontSize: 18,
            color: MainColors.kbDarkGray,
          ),
        ),
      ],
    ),
  );

  Widget _buildScheduleTile(int i) {
    final s = widget.schedules[i];

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          s['title'] ?? '',
          style: const TextStyle(
            fontFamily: 'KBFGText',
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: MainColors.kbDarkGray,
          ),
        ),
        subtitle: Text(
          DateFormat('a h:mm', 'ko').format(DateTime.parse(s['start']!)),
          style: const TextStyle(
            fontFamily: 'KBFGText',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: MainColors.kbDarkGray,
          ),
        ),
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: _buildWriteJournal(i), // 작성 UI 유지, 불러온 값 반영됨
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWriteJournal(int i) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.only(left: 8, bottom: 0, top: 8),
          child: Text(
            '매매일지',
            style: TextStyle(
              fontFamily: 'KBFGText',
              fontWeight: FontWeight.w700,
              fontSize: 14,
              color: MainColors.kbDarkGray,
            ),
          ),
        ),
        _buildDiaryField(i),
        _buildChipSection(
          title: '감정',
          items: _emotions,
          selected: _emotionsSelected[i],
          chipPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          labelPadding: const EdgeInsets.symmetric(horizontal: 8),
          chipSpacing: 3,
          chipRunSpacing: 2,
          onTap: (chipIdx, sel) =>
              setState(() => _emotionsSelected[i][chipIdx] = sel),
        ),
        const SizedBox(height: 12),
        _buildChipSection(
          title: '행동',
          items: _actions,
          selected: _actionsSelected[i],
          chipPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          labelPadding: const EdgeInsets.symmetric(horizontal: 7),
          onTap: (chipIdx, sel) =>
              setState(() => _actionsSelected[i][chipIdx] = sel),
        ),
        const SizedBox(height: 16),
        _buildDoneButton(),
        const Divider(),
      ],
    );
  }

  Widget _buildDiaryField(int i) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 5, 0, 12),
    child: TextField(
      controller: _controllers[i],
      maxLines: null,
      maxLength: 100,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      buildCounter: (ctx,
          {required int currentLength,
            required bool isFocused,
            required int? maxLength}) {
        return Padding(
          padding: const EdgeInsets.only(left: 4, top: 2),
          child: Text(
            '$currentLength / $maxLength',
            style: const TextStyle(
              fontFamily: 'KBFGText',
              fontSize: 11,
              color: Colors.grey,
            ),
          ),
        );
      },
      decoration: InputDecoration(
        hintText: '객관적인 판단 이유를 작성해주세요',
        hintStyle: const TextStyle(
          fontFamily: 'KBFGText',
          color: Colors.grey,
          fontSize: 13,
        ),
        filled: true,
        fillColor: Colors.grey.shade100,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8),
          borderSide: BorderSide.none,
        ),
      ),
    ),
  );

  Widget _buildChipSection({
    required String title,
    required List<String> items,
    required List<bool> selected,
    required void Function(int chipIdx, bool sel) onTap,
    EdgeInsets chipPadding =
    const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
    EdgeInsets labelPadding = const EdgeInsets.only(left: 6, right: 4),
    double chipSpacing = 5,
    double chipRunSpacing = 3,
  }) =>
      Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontFamily: 'KBFGText',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: MainColors.kbDarkGray,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: chipSpacing,
              runSpacing: chipRunSpacing,
              children: List.generate(items.length, (idx) {
                return FilterChip(
                  label: Text(
                    items[idx],
                    style: const TextStyle(
                      fontFamily: 'KBFGText',
                      fontSize: 13,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  labelPadding: labelPadding,
                  padding: chipPadding,
                  selected: selected[idx],
                  showCheckmark: false,
                  backgroundColor: Colors.grey.shade200,
                  selectedColor: MainColors.sheet3mVt10891,
                  elevation: 0.5,
                  shadowColor: Colors.black12,
                  shape: const StadiumBorder(
                    side: BorderSide(color: Colors.transparent),
                  ),
                  onSelected: (sel) => onTap(idx, sel),
                );
              }),
            ),
          ],
        ),
      );

  Widget _buildDoneButton() => Center(
    child: ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: MainColors.sheet3mVt10891,
        elevation: 1,
        shadowColor: Colors.black26,
        minimumSize: const Size(96, 38),
        padding:
        const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
          side: BorderSide.none,
        ),
        textStyle: const TextStyle(
          fontFamily: 'KBFGText',
          fontWeight: FontWeight.w600,
          fontSize: 13,
        ),
      ),
      onPressed: () {
        setState(() {});
      },
      child: const Text('완료'),
    ),
  );
}
