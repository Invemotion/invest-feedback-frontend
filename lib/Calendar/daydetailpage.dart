// import 'package:flutter/material.dart';
// import 'package:intl/intl.dart';
// import 'package:flutter/services.dart';
// import 'package:dio/dio.dart';
//
// import '../../Tools/Appbar/MyAppBar.dart';
// import '../../Tools/Color/Colors.dart';
// import '../../api/api_client.dart';
// import '../../api/ai_report_facade.dart';
//
// class DayDetailPage extends StatefulWidget {
//   const DayDetailPage({
//     super.key,
//     required this.date,
//     required this.schedules, // [{title,start,end,tradeId,hasJournal,journalId}]
//   });
//
//   final DateTime date;
//   final List<Map<String, String>> schedules;
//
//   @override
//   State<DayDetailPage> createState() => _DayDetailPageState();
// }
//
// class _DayDetailPageState extends State<DayDetailPage> {
//   final Dio _api = ApiClient().client;
//   final AiReportFacade _facade = AiReportFacade();
//   final int _userId = 1; // 필요 시 로그인 연동
//
//   late final List<TextEditingController> _controllers;
//
//   // 칩 라벨 (디자인 유지)
//   final List<String> _emotions = ['기대','확신','불안','기쁨','후회','무감정','아쉬움'];
//   final List<String> _actions  = ['추격매수','분할진입','감정적 진입','전략적 정리','분할매도','조기매도','손절지연','시장 추종','불안정 매도'];
//
//   // 한글 → 서버 ENUM
//   final Map<String,String> _emotionToEnum = {
//     '기대':'EXPECTATION','확신':'CERTAINTY','불안':'ANXIETY','기쁨':'JOY','후회':'REMORSE','무감정':'NEUTRAL','아쉬움':'REGRET',
//   };
//   final Map<String,String> _behaviorToEnum = {
//     '추격매수':'CHASING_BUY','분할진입':'DIVIDED_ENTRY','감정적 진입':'EMOTIONAL_ENTRY','전략적 정리':'STRATEGIC_EXIT',
//     '분할매도':'DIVIDED_SELL','조기매도':'EARLY_SELL','손절지연':'DELAYED_STOP','시장 추종':'MARKET_FOLLOW','불안정 매도':'UNSTABLE_SELL',
//   };
//
//   // 서버 ENUM → 한글 (불러오기용)
//   final Map<String,String> _emotionFromEnum = {
//     'EXPECTATION':'기대','CERTAINTY':'확신','ANXIETY':'불안','JOY':'기쁨','REMORSE':'후회','NEUTRAL':'무감정','REGRET':'아쉬움',
//   };
//   final Map<String,String> _behaviorFromEnum = {
//     'CHASING_BUY':'추격매수','DIVIDED_ENTRY':'분할진입','EMOTIONAL_ENTRY':'감정적 진입','STRATEGIC_EXIT':'전략적 정리',
//     'DIVIDED_SELL':'분할매도','EARLY_SELL':'조기매도','DELAYED_STOP':'손절지연','MARKET_FOLLOW':'시장 추종','UNSTABLE_SELL':'불안정 매도',
//   };
//
//   late final List<List<bool>> _emotionsSelected;
//   late final List<List<bool>> _actionsSelected;
//
//   final Map<String,String?> _origReason = {};
//   final Map<String,String?> _origEmotion = {};
//   final Map<String,String?> _origBehavior = {};
//
//   bool _hasAnyJournal = false;
//   bool _creating = false;
//
//   @override
//   void initState() {
//     super.initState();
//     _controllers = List.generate(widget.schedules.length, (_) => TextEditingController());
//
//     _emotionsSelected = List.generate(widget.schedules.length, (_) => List<bool>.filled(_emotions.length, false));
//     _actionsSelected  = List.generate(widget.schedules.length, (_) => List<bool>.filled(_actions.length,  false));
//
//     _hasAnyJournal = widget.schedules.any((e) => (e['hasJournal'] ?? '').toLowerCase() == 'true');
//     _loadJournals();
//   }
//
//   Future<void> _loadJournals() async {
//     for (int i = 0; i < widget.schedules.length; i++) {
//       final tradeId = widget.schedules[i]['tradeId'];
//       if (tradeId == null || tradeId.isEmpty) continue;
//
//       try {
//         final resp = await _api.get('/api/journals/$tradeId', options: Options(headers: {'X-User-id': _userId}));
//         final data = resp.data['data'];
//         if (data is Map) {
//           final reason = data['reason']?.toString();
//           final emo    = data['emotion']?.toString();
//           final beh    = data['behavior']?.toString();
//
//           _origReason[tradeId]  = reason;
//           _origEmotion[tradeId] = emo;
//           _origBehavior[tradeId]= beh;
//
//           _controllers[i].text = reason ?? '';
//
//           if (emo != null && _emotionFromEnum.containsKey(emo)) {
//             final idx = _emotions.indexOf(_emotionFromEnum[emo]!);
//             if (idx >= 0) _emotionsSelected[i][idx] = true;
//           }
//           if (beh != null && _behaviorFromEnum.containsKey(beh)) {
//             final idx = _actions.indexOf(_behaviorFromEnum[beh]!);
//             if (idx >= 0) _actionsSelected[i][idx] = true;
//           }
//           _hasAnyJournal = true;
//         }
//       } catch (_) {}
//     }
//     if (mounted) setState(() {});
//   }
//
//   String? _pickedEmotionEnum(int i) {
//     final idx = _emotionsSelected[i].indexWhere((v) => v);
//     if (idx < 0) return null;
//     return _emotionToEnum[_emotions[idx]];
//   }
//   String? _pickedBehaviorEnum(int i) {
//     final idx = _actionsSelected[i].indexWhere((v) => v);
//     if (idx < 0) return null;
//     return _behaviorToEnum[_actions[idx]];
//   }
//
//   Future<void> _saveAllJournalsIfDirty() async {
//     for (int i = 0; i < widget.schedules.length; i++) {
//       final tradeId = widget.schedules[i]['tradeId'];
//       if (tradeId == null || tradeId.isEmpty) continue;
//
//       final newReason = _controllers[i].text.trim();
//       final newEmo = _pickedEmotionEnum(i);
//       final newBeh = _pickedBehaviorEnum(i);
//
//       final wasReason = _origReason[tradeId] ?? '';
//       final wasEmo = _origEmotion[tradeId];
//       final wasBeh = _origBehavior[tradeId];
//
//       final dirty = (newReason != wasReason) || (newEmo != wasEmo) || (newBeh != wasBeh);
//       if (!dirty) continue;
//
//       try {
//         await _api.put(
//           '/api/journals/$tradeId',
//           data: {
//             'reason': newReason.isEmpty ? null : newReason,
//             'emotion': newEmo,
//             'behavior': newBeh,
//           },
//           options: Options(headers: {'X-User-id': _userId}),
//         );
//         _origReason[tradeId] = newReason;
//         _origEmotion[tradeId] = newEmo;
//         _origBehavior[tradeId] = newBeh;
//       } catch (_) {
//         if (mounted) {
//           ScaffoldMessenger.of(context).showSnackBar(
//             const SnackBar(content: Text('일지 일부 저장 실패가 발생했습니다.')),
//           );
//         }
//       }
//     }
//   }
//
//   Future<void> _createDailyReport() async {
//     if (_creating) return;
//     setState(() => _creating = true);
//     try {
//       // 1) 일지 먼저 저장
//       await _saveAllJournalsIfDirty();
//       // 2) (선택) 최신값 재적용
//       await _loadJournals();
//       // 3) LLM → 리포트 저장(POST or PATCH)
//       final r = await _facade.createAndSaveDaily(
//         date: widget.date,
//         userId: _userId,
//       );
//
//       if (!mounted) return;
//       if (r.ok) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(r.message)));
//         Navigator.pop(context, true);
//       } else {
//         ScaffoldMessenger.of(context).showSnackBar(
//           SnackBar(content: Text('리포트 생성 실패: ${r.message} (HTTP ${r.httpStatus ?? '-'})')),
//         );
//       }
//     } catch (e) {
//       if (mounted) {
//         ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('리포트 생성 오류: $e')));
//       }
//     } finally {
//       if (mounted) setState(() => _creating = false);
//     }
//   }
//
//   @override
//   void dispose() {
//     for (final c in _controllers) {
//       c.dispose();
//     }
//     super.dispose();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     final title = DateFormat('yyyy년 M월 d일').format(widget.date);
//     return Scaffold(
//       appBar: MyAppBar(appBar: AppBar(), title: title),
//       body: widget.schedules.isEmpty
//           ? _buildEmpty()
//           : ListView.builder(
//         padding: const EdgeInsets.symmetric(vertical: 10),
//         itemCount: widget.schedules.length + (_hasAnyJournal ? 1 : 0),
//         itemBuilder: (context, i) {
//           if (_hasAnyJournal && i == widget.schedules.length) {
//             return _buildAiReportCta();
//           }
//           return _buildScheduleTile(i);
//         },
//       ),
//     );
//   }
//
//   Widget _buildEmpty() => Center(
//     child: Column(
//       mainAxisSize: MainAxisSize.min,
//       children: const [
//         Icon(Icons.find_in_page_outlined, size: 64, color: Colors.black26),
//         SizedBox(height: 16),
//         Text(
//           '조회 내역이 없습니다.',
//           style: TextStyle(
//             fontFamily: 'KBFGText',
//             fontWeight: FontWeight.w500,
//             fontSize: 18,
//             color: MainColors.kbDarkGray,
//           ),
//         ),
//       ],
//     ),
//   );
//
//   Widget _buildScheduleTile(int i) {
//     final s = widget.schedules[i];
//     return Padding(
//       padding: const EdgeInsets.symmetric(horizontal: 16),
//       child: ExpansionTile(
//         tilePadding: EdgeInsets.zero,
//         title: Text(
//           s['title'] ?? '',
//           style: const TextStyle(
//             fontFamily: 'KBFGText',
//             fontWeight: FontWeight.w500,
//             fontSize: 16,
//             color: MainColors.kbDarkGray,
//           ),
//         ),
//         subtitle: Text(
//           (s['start'] ?? '').isNotEmpty
//               ? DateFormat('a h:mm', 'ko').format(DateTime.parse(s['start']!))
//               : '',
//           style: const TextStyle(
//             fontFamily: 'KBFGText',
//             fontWeight: FontWeight.w400,
//             fontSize: 14,
//             color: MainColors.kbDarkGray,
//           ),
//         ),
//         children: [
//           ConstrainedBox(
//             constraints: BoxConstraints(maxHeight: MediaQuery.of(context).size.height * 0.6),
//             child: SingleChildScrollView(
//               padding: EdgeInsets.zero,
//               child: _buildWriteJournal(i),
//             ),
//           ),
//         ],
//       ),
//     );
//   }
//
//   Widget _buildWriteJournal(int i) {
//     return Column(
//       crossAxisAlignment: CrossAxisAlignment.start,
//       children: [
//         const Padding(
//           padding: EdgeInsets.only(left: 8, bottom: 0, top: 8),
//           child: Text(
//             '매매일지',
//             style: TextStyle(
//               fontFamily: 'KBFGText',
//               fontWeight: FontWeight.w700,
//               fontSize: 14,
//               color: MainColors.kbDarkGray,
//             ),
//           ),
//         ),
//         _buildDiaryField(i),
//         _buildChipSection(
//           title: '감정',
//           items: _emotions,
//           selected: _emotionsSelected[i],
//           chipPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
//           labelPadding: const EdgeInsets.symmetric(horizontal: 8),
//           chipSpacing: 3,
//           chipRunSpacing: 2,
//           onTap: (chipIdx, sel) => setState(() => _emotionsSelected[i][chipIdx] = sel),
//         ),
//         const SizedBox(height: 12),
//         _buildChipSection(
//           title: '행동',
//           items: _actions,
//           selected: _actionsSelected[i],
//           chipPadding: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
//           labelPadding: const EdgeInsets.symmetric(horizontal: 7),
//           onTap: (chipIdx, sel) => setState(() => _actionsSelected[i][chipIdx] = sel),
//         ),
//         const SizedBox(height: 16),
//         _buildDoneButton(),
//         const Divider(),
//       ],
//     );
//   }
//
//   Widget _buildDiaryField(int i) => Padding(
//     padding: const EdgeInsets.fromLTRB(0, 5, 0, 12),
//     child: TextField(
//       controller: _controllers[i],
//       maxLines: null,
//       maxLength: 100,
//       maxLengthEnforcement: MaxLengthEnforcement.enforced,
//       buildCounter: (ctx, {required int currentLength, required bool isFocused, required int? maxLength}) {
//         return Padding(
//           padding: const EdgeInsets.only(left: 4, top: 2),
//           child: Text(
//             '$currentLength / $maxLength',
//             style: const TextStyle(fontFamily: 'KBFGText', fontSize: 11, color: Colors.grey),
//           ),
//         );
//       },
//       decoration: InputDecoration(
//         hintText: '객관적인 판단 이유를 작성해주세요',
//         hintStyle: const TextStyle(fontFamily: 'KBFGText', color: Colors.grey, fontSize: 13),
//         filled: true,
//         fillColor: Colors.grey.shade100,
//         border: OutlineInputBorder(
//           borderRadius: BorderRadius.circular(8),
//           borderSide: BorderSide.none,
//         ),
//       ),
//     ),
//   );
//
//   Widget _buildChipSection({
//     required String title,
//     required List<String> items,
//     required List<bool> selected,
//     required void Function(int chipIdx, bool sel) onTap,
//     EdgeInsets chipPadding = const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
//     EdgeInsets labelPadding = const EdgeInsets.only(left: 6, right: 4),
//     double chipSpacing = 5,
//     double chipRunSpacing = 3,
//   }) =>
//       Padding(
//         padding: const EdgeInsets.only(left: 8),
//         child: Column(
//           crossAxisAlignment: CrossAxisAlignment.start,
//           children: [
//             Text(
//               title,
//               style: const TextStyle(
//                 fontFamily: 'KBFGText',
//                 fontWeight: FontWeight.w600,
//                 fontSize: 14,
//                 color: MainColors.kbDarkGray,
//               ),
//             ),
//             const SizedBox(height: 4),
//             Wrap(
//               spacing: chipSpacing,
//               runSpacing: chipRunSpacing,
//               children: List.generate(items.length, (idx) {
//                 return FilterChip(
//                   label: Text(
//                     items[idx],
//                     style: const TextStyle(fontFamily: 'KBFGText', fontSize: 13, fontWeight: FontWeight.w400),
//                   ),
//                   labelPadding: labelPadding,
//                   padding: chipPadding,
//                   selected: selected[idx],
//                   showCheckmark: false,
//                   backgroundColor: Colors.grey.shade200,
//                   selectedColor: MainColors.sheet3mVt10891,
//                   elevation: 0.5,
//                   shadowColor: Colors.black12,
//                   shape: const StadiumBorder(side: BorderSide(color: Colors.transparent)),
//                   onSelected: (sel) => onTap(idx, sel),
//                 );
//               }),
//             ),
//           ],
//         ),
//       );
//
//   Widget _buildDoneButton() => Center(
//     child: ElevatedButton(
//       style: ElevatedButton.styleFrom(
//         backgroundColor: MainColors.sheet3mVt10891,
//         elevation: 1,
//         shadowColor: Colors.black26,
//         minimumSize: const Size(96, 38),
//         padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
//         shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide.none),
//         textStyle: const TextStyle(fontFamily: 'KBFGText', fontWeight: FontWeight.w600, fontSize: 13),
//       ),
//       onPressed: () => setState(() {}),
//       child: const Text('완료'),
//     ),
//   );
//
//   Widget _buildAiReportCta() => Padding(
//     padding: const EdgeInsets.fromLTRB(30, 8, 20, 30),
//     child: Column(
//       crossAxisAlignment: CrossAxisAlignment.stretch,
//       children: [
//         const SizedBox(height: 8),
//         ElevatedButton.icon(
//           icon: _creating
//               ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
//               : const Icon(Icons.auto_awesome),
//           label: Text(_creating ? '리포트 생성 중...' : 'AI 리포트 생성'),
//           style: ElevatedButton.styleFrom(
//             backgroundColor: MainColors.sheet3mVt10891,
//             minimumSize: const Size.fromHeight(44),
//             textStyle: const TextStyle(fontFamily: 'KBFGText', fontWeight: FontWeight.w600, fontSize: 14),
//           ),
//           onPressed: _creating ? null : _createDailyReport,
//         ),
//       ],
//     ),
//   );
// }

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

  final List<String> _emotions = ['기대','확신','불안','기쁨','후회','무감정','아쉬움'];
  final List<String> _actions = [
    '추격매수','분할진입','감정적 진입',
    '전략적 정리','분할매도','조기매도',
    '손절지연','시장 추종','불안정 매도'
  ];

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

    reverseEmotionMap.addEntries(emotionMap.entries.map((e) => MapEntry(e.value, e.key)));
    reverseBehaviorMap.addEntries(behaviorMap.entries.map((e) => MapEntry(e.value, e.key)));

    _controllers = List.generate(widget.schedules.length, (_) => TextEditingController());
    _emotionsSelected = List.generate(widget.schedules.length, (_) => List<bool>.filled(_emotions.length, false));
    _actionsSelected  = List.generate(widget.schedules.length, (_) => List<bool>.filled(_actions.length, false));
    _existing = List.filled(widget.schedules.length, null);

    _loadJournals();
  }

  /// ✅ 조회는 항상 journalId 로만 한다.
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

    // 선택값(단일선택 유지)
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

      // 최신화
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

  Future<void> _createDailyReport() async {
    if (_creatingReport) return;
    setState(() => _creatingReport = true);
    try {
      // 1) 일지 먼저 저장(후자여야 한다고 했던 부분)
      await _saveAllJournals();

      // 2) LLM 생성 + 서버 저장/갱신
      final r = await _facade.createAndSaveDaily(date: widget.date, userId: _userIdForReport);

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
    for (final c in _controllers) { c.dispose(); }
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
    final created = _existing[i] != null;

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
          (s['start'] ?? '').isNotEmpty
              ? DateFormat('a h:mm', 'ko').format(DateTime.parse(s['start']!))
              : '',
          style: const TextStyle(
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
          Padding(
            padding: const EdgeInsets.only(left: 8, bottom: 0, top: 8),
            child: Row(
              children: [
                const Text(
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
          _buildDiaryField(i),
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
              style: const TextStyle(
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
    final bgColor   = created ? MainColors.sheet3mVt10891.withOpacity(0.18)
        : Colors.grey.shade200;
    final borderCol = created ? MainColors.sheet3mVt10891
        : Colors.grey.shade400;
    final label     = created ? '생성됨' : '미작성';

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
          fontFamily: 'KBFGText',
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
              ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.auto_awesome),
          label: Text(_creatingReport ? '리포트 생성 중...' : 'AI 리포트 생성'),
          style: ElevatedButton.styleFrom(
            backgroundColor: MainColors.sheet3mVt10891,
            minimumSize: const Size.fromHeight(44),
            textStyle: const TextStyle(
                fontFamily: 'KBFGText', fontWeight: FontWeight.w600, fontSize: 14),
          ),
          onPressed: _creatingReport ? null : _createDailyReport,
        ),
      ],
    ),
  );
}

