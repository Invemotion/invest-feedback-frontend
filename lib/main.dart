// lib/main.dart
import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';  // 로케일 데이터 초기화용
import 'Calendar/calendar.dart';
import 'Tools/Color/Colors.dart';

Future<void> main() async {
  // 엔진 바인딩 초기화
  WidgetsFlutterBinding.ensureInitialized();
  // 한국어 로케일 데이터 초기화
  await initializeDateFormatting('ko');
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'InvestMotion',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'NotoSansKR',
        scaffoldBackgroundColor: MainColors.background,
      ),
      // SafeArea + 하단 고정 바까지 포함
      builder: (context, child) {
        return Scaffold(
          backgroundColor: MainColors.background,
          body: SafeArea(child: child!),
          bottomNavigationBar: Padding(
            padding: const EdgeInsets.fromLTRB(0, 0, 0, 25),
            child: Container(
              height: 56,
              color: const Color(0xFF555555),
              child: Row(
                children: [
                  // ─ 메뉴 ─
                  Expanded(
                    child: Container(
                      color: const Color(0xFF444444),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: const [
                          Icon(Icons.menu, color: Colors.white, size: 20),
                          SizedBox(height: 2),
                          Text(
                            '메뉴',
                            style: TextStyle(
                              color: Colors.white,
                              fontFamily: 'KBFGText',
                              fontWeight: FontWeight.w400,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  // ─ 구분선 ─
                  SizedBox(
                    width: 1,
                    child: Center(
                      child: Container(
                        width: 1,
                        height: 30,
                        color: Colors.black12,
                      ),
                    ),
                  ),
                  // ─ 홈 ─
                  const Expanded(
                    child: Center(
                      child: Text(
                        '홈',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'KBFGText',
                          fontWeight: FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 1,
                    child: Center(
                      child: Container(
                        width: 1,
                        height: 30,
                        color: Colors.black12,
                      ),
                    ),
                  ),
                  // ─ 통합검색 ─
                  const Expanded(
                    child: Center(
                      child: Text(
                        '통합\n검색',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'KBFGText',
                          fontWeight: FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 1,
                    child: Center(
                      child: Container(
                        width: 1,
                        height: 30,
                        color: Colors.black12,
                      ),
                    ),
                  ),
                  // ─ 관심종목 ─
                  const Expanded(
                    child: Center(
                      child: Text(
                        '관심\n종목',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'KBFGText',
                          fontWeight: FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 1,
                    child: Center(
                      child: Container(
                        width: 1,
                        height: 30,
                        color: Colors.black12,
                      ),
                    ),
                  ),
                  // ─ 주식현재가 ─
                  const Expanded(
                    child: Center(
                      child: Text(
                        '주식\n현재가',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'KBFGText',
                          fontWeight: FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 1,
                    child: Center(
                      child: Container(
                        width: 1,
                        height: 30,
                        color: Colors.black12,
                      ),
                    ),
                  ),
                  // ─ 국내주식 일반주문 ─
                  const Expanded(
                    child: Center(
                      child: Text(
                        '국내주식\n일반주문',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white,
                          fontFamily: 'KBFGText',
                          fontWeight: FontWeight.w400,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 1,
                    child: Center(
                      child: Container(
                        width: 1,
                        height: 30,
                        color: Colors.black12,
                      ),
                    ),
                  ),
                  // ─ 설정 아이콘 ─
                  const Expanded(
                    child: Center(
                      child: Icon(
                        Icons.settings,
                        color: Colors.white,
                        size: 24,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
      home: const Calendar(),
    );
  }
}
