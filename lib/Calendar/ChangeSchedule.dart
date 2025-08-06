import 'package:flutter/material.dart';
import '../../Tools/Appbar/MyAppBar.dart';
import '../../Tools/Color/Colors.dart';

class ChangeSchedule extends StatefulWidget {
  final Map<String, String> schedule;   // 전달받은 일정
  const ChangeSchedule({Key? key, required this.schedule}) : super(key: key);

  @override
  State<ChangeSchedule> createState() => _ChangeScheduleState();
}

class _ChangeScheduleState extends State<ChangeSchedule> {
  late TextEditingController _textCtl;

  // 드롭다운용 리스트
  final _years   = List.generate(10, (i) => '${2020 + i}년');
  final _months  = List.generate(12, (i) => '${i + 1}월');
  final _days    = List.generate(31, (i) => '${i + 1}일');
  final _hours   = List.generate(24, (i) => '$i시');
  final _minutes = List.generate(60, (i) => '$i분');

  // 선택 값 (null-safety)
  late String y, m, d, h, min, yE, mE, dE, hE, minE;

  @override
  void initState() {
    super.initState();
    _textCtl = TextEditingController(text: widget.schedule['title']);

    final start = DateTime.parse(widget.schedule['start']!);
    final end   = DateTime.parse(widget.schedule['end']!);

    y   = '${start.year}년'; m   = '${start.month}월'; d   = '${start.day}일';
    h   = '${start.hour}시'; min = '${start.minute}분';
    yE  = '${end.year}년';   mE  = '${end.month}월';   dE  = '${end.day}일';
    hE  = '${end.hour}시';   minE= '${end.minute}분';
  }

  // ▼ 선택 → DateTime → ISO string
  String _buildIso(String year,String month,String day,String hour,String minute){
    return DateTime(
      int.parse(year.replaceAll('년','')),
      int.parse(month.replaceAll('월','')),
      int.parse(day.replaceAll('일','')),
      int.parse(hour.replaceAll('시','')),
      int.parse(minute.replaceAll('분','')),
    ).toIso8601String();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: MyAppBar(appBar: AppBar(), title: '일정 수정'),
        body: Column(
          children: [
            // ─── 제목 입력 ───
            Container(
              margin: const EdgeInsets.fromLTRB(20,20,20,20),
              child: TextFormField(
                controller: _textCtl,
                decoration: InputDecoration(
                  hintText: '제목',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20,vertical: 18),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
              ),
            ),

            // ─── 날짜/시간 드롭다운 ───
            _dateSection('시작일',
                y,m,d,h,min,
                    (v)=>setState(()=>y=v!), (v)=>setState(()=>m=v!), (v)=>setState(()=>d=v!),
                    (v)=>setState(()=>h=v!), (v)=>setState(()=>min=v!)),
            _dateSection('마감일',
                yE,mE,dE,hE,minE,
                    (v)=>setState(()=>yE=v!), (v)=>setState(()=>mE=v!), (v)=>setState(()=>dE=v!),
                    (v)=>setState(()=>hE=v!), (v)=>setState(()=>minE=v!)),

            // ─── 수정 버튼 ───
            GestureDetector(
              onTap: () {
                final updated = {
                  'id'   : widget.schedule['id']!,
                  'title': _textCtl.text,
                  'start': _buildIso(y,m,d,h,min),
                  'end'  : _buildIso(yE,mE,dE,hE,minE),
                };
                Navigator.of(context).pop(updated);
              },
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: 55,
                margin: const EdgeInsets.fromLTRB(20,20,20,10),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                    color: MainColors.blue,
                    borderRadius: BorderRadius.circular(55)),
                child: const Text('수정',
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),

            // ─── 삭제 버튼 ───
            GestureDetector(
              onTap: () => Navigator.of(context).pop(<String,String>{}),
              child: const Text('일정 삭제',
                  style: TextStyle(fontSize: 12, color: Colors.red)),
            )
          ],
        ),
      ),
    );
  }

  /// 날짜 드롭다운 묶음 위젯
  Widget _dateSection(
      String label,
      String year,String month,String day,String hour,String minute,
      Function(String?) onY, Function(String?) onM, Function(String?) onD,
      Function(String?) onH, Function(String?) onMin,
      ){
    DropdownButtonHideUnderline _dd(List<String> items,String value,
        Function(String?) cb)=>DropdownButtonHideUnderline(
      child: DropdownButton<String>(
        value: value, isDense: true, onChanged: cb,
        items: items.map((e)=>DropdownMenuItem(value:e,child:Text(e))).toList(),
        style: const TextStyle(fontSize:12),
      ),
    );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal:30, vertical:5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:[
          Container(
            padding: const EdgeInsets.symmetric(horizontal:10,vertical:2),
            decoration: BoxDecoration(
                color: MainColors.blue, borderRadius: BorderRadius.circular(15)),
            child: Text(label, style: const TextStyle(
                color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height:5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children:[
              _dd(_years,   year,   onY),
              _dd(_months,  month,  onM),
              _dd(_days,    day,    onD),
              _dd(_hours,   hour,   onH),
              _dd(_minutes, minute, onMin),
            ],
          )
        ],
      ),
    );
  }
}
