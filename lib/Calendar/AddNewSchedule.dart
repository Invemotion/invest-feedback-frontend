import 'package:flutter/material.dart';
import '../../Tools/Appbar/MyAppBar.dart';
import '../../Tools/Color/Colors.dart';

class AddNewSchedule extends StatefulWidget {
  const AddNewSchedule({Key? key}) : super(key: key);

  @override
  State<AddNewSchedule> createState() => _AddNewScheduleState();
}

class _AddNewScheduleState extends State<AddNewSchedule> {
  final _titleCtl = TextEditingController();

  final _years   = List.generate(10, (i) => '${2020 + i}년');
  final _months  = List.generate(12, (i) => '${i + 1}월');
  final _days    = List.generate(31, (i) => '${i + 1}일');
  final _hours   = List.generate(24, (i) => '$i시');
  final _minutes = List.generate(60, (i) => '$i분');

  String? y, m, d, h, min, yE, mE, dE, hE, minE;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    y = yE = '${now.year}년';
    m = mE = '${now.month}월';
    d = dE = '${now.day}일';
    h = hE = '0시';
    min = minE = '0분';
  }

  String _iso(String yr,String mo,String dy,String ho,String mi){
    return DateTime(
      int.parse(yr.replaceAll('년','')),
      int.parse(mo.replaceAll('월','')),
      int.parse(dy.replaceAll('일','')),
      int.parse(ho.replaceAll('시','')),
      int.parse(mi.replaceAll('분','')),
    ).toIso8601String();
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        appBar: MyAppBar(appBar: AppBar(), title: '일정 추가'),
        body: Column(
          children: [
            // 제목
            Container(
              margin: const EdgeInsets.fromLTRB(20, 20, 20, 20),
              child: TextFormField(
                controller: _titleCtl,
                decoration: InputDecoration(
                  hintText: '제목',
                  filled: true,
                  fillColor: Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 18),
                  enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
                ),
              ),
            ),
            _dateSection('시작일', y, m, d, h, min, (v)=>setState(()=>y=v!), (v)=>setState(()=>m=v!), (v)=>setState(()=>d=v!),
                    (v)=>setState(()=>h=v!), (v)=>setState(()=>min=v!)),
            _dateSection('마감일', yE, mE, dE, hE, minE, (v)=>setState(()=>yE=v!), (v)=>setState(()=>mE=v!), (v)=>setState(()=>dE=v!),
                    (v)=>setState(()=>hE=v!), (v)=>setState(()=>minE=v!)),
            GestureDetector(
              onTap: () {
                if (_titleCtl.text.isEmpty) return;
                final data = {
                  'id'   : DateTime.now().millisecondsSinceEpoch.toString(),
                  'title': _titleCtl.text,
                  'start': _iso(y!, m!, d!, h!, min!),
                  'end'  : _iso(yE!, mE!, dE!, hE!, minE!),
                };
                Navigator.of(context).pop(data);
              },
              child: Container(
                width: MediaQuery.of(context).size.width,
                height: 55,
                margin: const EdgeInsets.fromLTRB(20, 20, 20, 30),
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: _titleCtl.text.isNotEmpty ? MainColors.blue : Colors.grey,
                  borderRadius: BorderRadius.circular(55),
                ),
                child: const Text('추가', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // 드롭다운 묶음
  Widget _dateSection(
      String label, String? yr,String? mo,String? dy,String? hr,String? mi,
      Function(String?) onY,Function(String?) onM,Function(String?) onD,Function(String?) onH,Function(String?) onMin,
      ){
    DropdownButtonHideUnderline _dd(List<String> items,String? val,Function(String?) cb)=>
        DropdownButtonHideUnderline(
          child: DropdownButton<String>(value: val,isDense: true,onChanged: cb,
              items: items.map((e)=>DropdownMenuItem(value:e,child:Text(e,style:const TextStyle(fontSize:12)))).toList()),
        );

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
            decoration: BoxDecoration(color: MainColors.blue, borderRadius: BorderRadius.circular(15)),
            child: Text(label, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w600)),
          ),
          const SizedBox(height: 5),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _dd(_years,   yr, onY),
              _dd(_months,  mo, onM),
              _dd(_days,    dy, onD),
              _dd(_hours,   hr, onH),
              _dd(_minutes, mi, onMin),
            ],
          ),
        ],
      ),
    );
  }
}