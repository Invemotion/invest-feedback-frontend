// lib/Calendar/daydetailpage.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../Tools/Appbar/MyAppBar.dart';
import '../../Tools/Color/Colors.dart';
import 'package:flutter/services.dart';

import '../../api/journal_service.dart';
import '../../api/ai_report_facade.dart';

class DayDetailPage extends StatefulWidget {
  const DayDetailPage({
    super.key,
    required this.date,
    required this.schedules,
  });

  final DateTime date;
  /// 반드시 포함: title, start, end, tradeId(String)
  /// 권장 포함: hasJournal, journalId(String)  ← 조회 키에 사용됨
  final List<Map<String, String>> schedules;

  @override
  State<DayDetailPage> createState() => _DayDetailPageState();
}

class _DayDetailPageState extends State<DayDetailPage> {
  late final List<TextEditingController> _controllers;
  late final JournalService _journalApi;
  final AiReportFacade _facade = AiReportFacade();
  final int _userIdForReport = 1; // 리포트 저장 시 일관성 유지(캘린더와 동일)

  /// 서버 기준 최신 Journal 캐시 (인덱스별)
  late final List<Journal?> _existing;

  // 라벨(한글)
  final List<String> _emotions = ['기대','확신','불안','기쁨','후회','무감정','아쉬움'];
  final List<String> _actions = [
    '추격매수','분할진입','감정적 진입',
    '전략적 정리','분할매도','조기매도',
    '손절지연','시장 추종','불안정 매도'
  ];

  // 서버 ENUM ↔ 한글 라벨 매핑
  final Map<String, String> emotionMap = {
    "EXPECTATION":"기대","CERTAINTY":"확신","ANXIETY":"불안",
    "JOY":"기쁨","REMORSE":"후회","NEUTRAL":"무감정","REGRET":"아쉬움",
  };
  final Map<String, String> behaviorMap = {
    "CHASING_BUY":"추격매수","DIVIDED_ENTRY":"분할진입","EMOTIONAL_ENTRY":"감정적 진입",
    "STRATEGIC_EXIT":"전략적 정리","DIVIDED_SELL":"분할매도","EARLY_SELL":"조기매도",
    "DELAYED_STOPLOSS":"손절지연","MARKET_FOLLOW":"시장 추종","UNSTABLE_SELL":"불안정 매도",
  };

  final Map<String, String> reverseEmotionMap = {};
  final Map<String, String> reverseBehaviorMap = {};

  late final List<List<bool>> _emotionsSelected;
  late final List<List<bool>> _actionsSelected;

  bool _creatingReport = false;

  @override
  void initState() {
    super.initState();
    _journalApi = JournalService();

    // 역매핑 구축
    reverseEmotionMap.addEntries(
      emotionMap.entries.map((e) => MapEntry(e.value, e.key)),
    );
    reverseBehaviorMap.addEntries(
      behaviorMap.entries.map((e) => MapEntry(e.value, e.key)),
    );

    _controllers = List.generate(
      widget.schedules.length,
          (_) => TextEditingController(),
    );
    _emotionsSelected = List.generate(
      widget.schedules.length,
          (_) => List<bool>.filled(_emotions.length, false),
    );
    _actionsSelected = List.generate(
      widget.schedules.length,
          (_) => List<bool>.filled(_actions.length, false),
    );
    _existing = List.filled(widget.schedules.length, null);

    _loadJournals();
  }

  /// ✅ 조회는 항상 journalId 로만 한다.
  /// - journalId가 없으면(빈 문자열/0/null) → 미생성으로 간주
  /// - 404 응답 → 미작성/삭제로 간주
  Future<void> _loadJournals() async {
    for (int i = 0; i < widget.schedules.length; i++) {
      final journalIdStr = widget.schedules[i]['journalId']?.trim();
      final jId = int.tryParse(journalIdStr ?? '');

      if (jId == null || jId <= 0) {
        _existing[i] = null;
        widget.schedules[i]['hasJournal'] = 'false';
        continue;
      }

      final j = await _journalApi.getByJournalId(jId);
      _existing[i] = j;

      if (j != null) {
        _controllers[i].text = j.reason;
        _setSelectedFromEnum(i, j.emotion, j.behavior);
        widget.schedules[i]['hasJournal'] = 'true';
        // 서버가 새 id로 교체한 경우 최신화
        widget.schedules[i]['journalId'] = j.id.toString();
      } else {
        widget.schedules[i]['hasJournal'] = 'false';
        widget.schedules[i]['journalId'] = '';
      }
    }
    if (mounted) setState(() {});
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

  Future<void> _saveJournal(int i) async {
    final tradeIdStr = widget.schedules[i]['tradeId'];
    final tradeId = int.tryParse(tradeIdStr ?? '');
    if (tradeId == null) return;

    // 단일선택 강제
    final emoIdx = _emotionsSelected[i].indexWhere((e) => e);
    final behIdx = _actionsSelected[i].indexWhere((e) => e);
    for (int j = 0; j < _emotionsSelected[i].length; j++) {
      if (j != emoIdx) _emotionsSelected[i][j] = false;
    }
    for (int j = 0; j < _actionsSelected[i].length; j++) {
      if (j != behIdx) _actionsSelected[i][j] = false;
    }

    final emotionEnum = (emoIdx != -1) ? reverseEmotionMap[_emotions[emoIdx]] : null;
    final behaviorEnum = (behIdx != -1) ? reverseBehaviorMap[_actions[behIdx]] : null;

    final reason = _controllers[i].text.trim();

    try {
      Journal result;
      if (_existing[i] == null) {
        // 생성
        result = await _journalApi.create(
          tradeId: tradeId,
          reason: reason,
          emotion: emotionEnum,
          behavior: behaviorEnum,
        );
        _existing[i] = result;
        widget.schedules[i]['journalId'] = result.id.toString();
        widget.schedules[i]['hasJournal'] = 'true';
        _showSnack('매매일지가 생성되었습니다.', success: true);
      } else {
        // 수정
        final jId = _existing[i]!.id;
        result = await _journalApi.update(
          journalId: jId,
          reason: reason,
          emotion: emotionEnum,
          behavior: behaviorEnum,
        );
        _existing[i] = result;
        widget.schedules[i]['journalId'] = result.id.toString();
        widget.schedules[i]['hasJournal'] = 'true';
        _showSnack('매매일지가 수정되었습니다.', success: true);
      }

      // 최신 상태 재확인
      final fresh = await _journalApi.getByJournalId(_existing[i]!.id);
      _existing[i] = fresh ?? _existing[i];
      if (fresh != null) {
        widget.schedules[i]['journalId'] = fresh.id.toString();
        widget.schedules[i]['hasJournal'] = 'true';
      }

      if (mounted) setState(() {});
    } catch (_) {
      _showSnack('매매일지 저장에 실패했습니다.', success: false);
    }
  }

  Future<void> _saveAllJournals() async {
    for (int i = 0; i < widget.schedules.length; i++) {
      await _saveJournal(i);
    }
  }

  /// AI 일일 리포트 생성(저널 저장 후 실행)
  Future<void> _createDailyReport() async {
    if (_creatingReport) return;
    setState(() => _creatingReport = true);
    try {
      // 1) 일지 먼저 저장
      await _saveAllJournals();

      // 2) LLM 생성 + 서버 저장/갱신
      final r = await _facade.createAndSaveDaily(
        date: widget.date,
        userId: _userIdForReport,
      );

      if (!mounted) return;
      if (r.ok) {
        _showSnack(r.message, success: true);
        Navigator.pop(context, true); // Calendar로 true 반환 → 갱신 트리거
      } else {
        _showSnack('리포트 생성 실패: ${r.message}', success: false);
      }
    } catch (e) {
      if (mounted) _showSnack('리포트 생성 오류: $e', success: false);
    } finally {
      if (mounted) setState(() => _creatingReport = false);
    }
  }

  void _showSnack(String msg, {required bool success}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: success ? Colors.green : Colors.red,
        duration: const Duration(seconds: 2),
      ),
    );
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
        itemCount: widget.schedules.length + 1, // 맨 아래 AI 버튼 추가
        itemBuilder: (context, i) {
          if (i == widget.schedules.length) {
            return _buildAiReportCta();
          }
          return _buildScheduleTile(i);
        },
      ),
    );
  }

  Widget _buildEmpty() => Center(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Icon(Icons.find_in_page_outlined, size: 64, color: Colors.black26),
        const SizedBox(height: 16),
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
    final created = _existing[i] != null;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(
          s['title'] ?? '',
          style: TextStyle(
            fontFamily: 'KBFGText',
            fontWeight: FontWeight.w500,
            fontSize: 16,
            color: MainColors.kbDarkGray,
          ),
        ),
        subtitle: Text(
          (s['start'] ?? '').isNotEmpty
              ? DateFormat('a h:mm', 'ko').format(DateTime.parse(s['start']!))
              : '',
          style: TextStyle(
            fontFamily: 'KBFGText',
            fontWeight: FontWeight.w400,
            fontSize: 14,
            color: MainColors.kbDarkGray,
          ),
        ),
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.zero,
            child: _buildWriteJournal(i, created: created),
          ),
        ],
      ),
    );
  }

  Widget _buildWriteJournal(int i, {required bool created}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 헤더 + 상태 뱃지
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 0, top: 8),
            child: Row(
              children: [
                Text(
                  '매매일지',
                  style: TextStyle(
                    fontFamily: 'KBFGText',
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                    color: MainColors.kbDarkGray,
                  ),
                ),
                const SizedBox(width: 8),
                _buildStatusBadge(created),
              ],
            ),
          ),
          // 텍스트 필드
          _buildDiaryField(i),
          // 감정
          _buildChipSection(
            title: '감정',
            items: _emotions,
            selected: _emotionsSelected[i],
            singleSelect: true,
            onTap: (chipIdx, sel) {
              setState(() {
                for (int j = 0; j < _emotionsSelected[i].length; j++) {
                  _emotionsSelected[i][j] = false;
                }
                _emotionsSelected[i][chipIdx] = sel;
              });
            },
          ),
          const SizedBox(height: 12),
          // 행동
          _buildChipSection(
            title: '행동',
            items: _actions,
            selected: _actionsSelected[i],
            singleSelect: true,
            onTap: (chipIdx, sel) {
              setState(() {
                for (int j = 0; j < _actionsSelected[i].length; j++) {
                  _actionsSelected[i][j] = false;
                }
                _actionsSelected[i][chipIdx] = sel;
              });
            },
          ),
          const SizedBox(height: 16),
          // 저장 버튼
          _buildDoneButton(i),
          const Divider(),
        ],
      ),
    );
  }

  Widget _buildDiaryField(int i) => Padding(
    padding: const EdgeInsets.fromLTRB(0, 5, 0, 12),
    child: TextField(
      controller: _controllers[i],
      maxLines: null,
      maxLength: 100,
      maxLengthEnforcement: MaxLengthEnforcement.enforced,
      buildCounter: (ctx, {required int currentLength, required bool isFocused, required int? maxLength}) {
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
    bool singleSelect = false,
  }) =>
      Padding(
        padding: const EdgeInsets.only(left: 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: TextStyle(
                fontFamily: 'KBFGText',
                fontWeight: FontWeight.w600,
                fontSize: 14,
                color: MainColors.kbDarkGray,
              ),
            ),
            const SizedBox(height: 4),
            Wrap(
              spacing: 3,
              runSpacing: 2,
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
                  labelPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 0),
                  padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
                  selected: selected[idx],
                  showCheckmark: false,
                  backgroundColor: Colors.grey.shade200,
                  selectedColor: MainColors.sheet3mVt10891,
                  elevation: 0.5,
                  shadowColor: Colors.black12,
                  shape: const StadiumBorder(side: BorderSide(color: Colors.transparent)),
                  onSelected: (sel) {
                    if (singleSelect) {
                      for (int j = 0; j < selected.length; j++) {
                        selected[j] = false;
                      }
                    }
                    onTap(idx, sel);
                  },
                );
              }),
            ),
          ],
        ),
      );

  Widget _buildDoneButton(int i) => Center(
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
      onPressed: () => _saveJournal(i),
      child: const Text('완료'),
    ),
  );

  Widget _buildStatusBadge(bool created) {
    final bgColor = created ? MainColors.sheet3mVt10891.withOpacity(0.18) : Colors.grey.shade200;
    final borderCol = created ? MainColors.sheet3mVt10891 : Colors.grey.shade400;
    final label = created ? '생성됨' : '미작성';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: borderCol),
      ),
      child: Text(
        label,
        style: const TextStyle(
          fontFamily: 'KBFGText', // KB 글씨체
          fontWeight: FontWeight.w600,
          fontSize: 12,
          color: MainColors.kbDarkGray,
        ),
      ),
    );
  }

  Widget _buildAiReportCta() => Padding(
    padding: const EdgeInsets.fromLTRB(30, 8, 20, 30),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 8),
        ElevatedButton.icon(
          icon: _creatingReport
              ? const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
              : const Icon(Icons.auto_awesome),
          label: Text(_creatingReport ? '리포트를 생성 중이에요' : 'AI 리포트 생성'),
          style: ElevatedButton.styleFrom(
            backgroundColor: MainColors.sheet3mVt10891,
            minimumSize: const Size.fromHeight(44),
            textStyle: const TextStyle(
              fontFamily: 'KBFGText',
              fontWeight: FontWeight.w600,
              fontSize: 14,
            ),
          ),
          onPressed: _creatingReport ? null : _createDailyReport,
        ),
      ],
    ),
  );
}
