// TODO: 일지가 있다면 위에 AI 분석 리포트 받아보기 창이 뜨기
// TODO: 버튼 누르면, 팝업(?)으로 AI 분석 중.. 이런거 뜨고, 완료 되면 리포트가 맨 위에 뜸

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

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
  // ── data ────────────────────────────────────────────────────────────────
  late final List<TextEditingController> _controllers;

  final List<String> _emotions = [
    '기대', '확신', '불안', '기쁨', '후회', '무감정', '아쉬움'
  ];
  final List<String> _actions = [
    '추격매수', '분할진입', '감정적 진입',
    '전략적 정리', '분할매도', '조기매도',
    '손절지연', '시장 추종', '불안정 매도'
  ];

  /// **종목별** 선택 상태: schedules.length × chip.length
  late final List<List<bool>> _emotionsSelected;
  late final List<List<bool>> _actionsSelected;

  // ── lifecycle ───────────────────────────────────────────────────────────
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
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  // ── build ───────────────────────────────────────────────────────────────
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

  // ── small widgets ───────────────────────────────────────────────────────
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
          // ── 내용 영역: 최대 화면 60% 높이 + 내부 스크롤 ──
          ConstrainedBox(
            constraints: BoxConstraints(
              maxHeight: MediaQuery.of(context).size.height * 0.6,
            ),
            child: SingleChildScrollView(
              padding: EdgeInsets.zero,
              child: Column(
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

                  // ── 감정 칩 ──
                  _buildChipSection(
                    title: '감정',
                    items: _emotions,
                    selected: _emotionsSelected[i],
                    chipPadding:
                    const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    labelPadding:
                    const EdgeInsets.symmetric(horizontal: 8),
                    chipSpacing: 3,
                    chipRunSpacing: 2,
                    onTap: (chipIdx, sel) =>
                        setState(() => _emotionsSelected[i][chipIdx] = sel),
                  ),
                  const SizedBox(height: 12),

                  // ── 행동 칩 ──
                  _buildChipSection(
                    title: '행동',
                    items: _actions,
                    selected: _actionsSelected[i],
                    chipPadding:
                    const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                    labelPadding:
                    const EdgeInsets.symmetric(horizontal: 7),
                    onTap: (chipIdx, sel) =>
                        setState(() => _actionsSelected[i][chipIdx] = sel),
                  ),
                  const SizedBox(height: 16),

                  _buildDoneButton(),
                  const Divider(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDiaryField(int i) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 5, 0, 12),
    child: TextField(
      controller: _controllers[i],
      maxLines: null,
      maxLength: 100,                               // ← 100자 제한
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      buildCounter: (ctx,
          {required int currentLength,
            required bool isFocused,
            required int? maxLength}) {
        // 왼쪽 정렬 카운터
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


  // --- 재사용 Chip section --------------------------------------------------
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
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
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
        // TODO: 상태 저장 로직
        setState(() {});
      },
      child: const Text('완료'),
    ),
  );
}