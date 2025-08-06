import 'package:flutter/material.dart';
import '../Color/Colors.dart';

class MyAppBar extends StatelessWidget implements PreferredSizeWidget {
  /// 단순 제목 + 뒤로가기 아이콘만 있는 공통 AppBar
  const MyAppBar({
    super.key,
    required this.appBar,
    required this.title,
    this.fontFamily = 'KBFGText',
    this.fontWeight = FontWeight.w700,
    this.iconSize = 17.0,
    this.leadingWidth = 30.0,
    this.titleSpacing = 10.0,
    this.leadingPaddingStart = 20.0,
  });

  final AppBar appBar;   // 높이 계산용
  final String title;
  final String fontFamily;
  final FontWeight fontWeight;
  final double iconSize;
  final double leadingWidth;
  final double titleSpacing;
  final double leadingPaddingStart;


  @override
  Widget build(BuildContext context) {
    return AppBar(
      backgroundColor: MainColors.background,
      shadowColor: Colors.transparent,
      centerTitle: false,
      leadingWidth: leadingWidth,
      titleSpacing: titleSpacing,
      // leading: Navigator.of(context).canPop()
      //     ? IconButton(
      //   splashRadius: 0.1,
      //   icon: const Icon(Icons.arrow_back_ios),
      //   onPressed: () => Navigator.of(context).maybePop(),
      // )
      //     : null,                           // root 화면이면 back-button 제거
      leading: IconButton(
        padding: EdgeInsetsDirectional.only(
          start: leadingPaddingStart, // 버튼 안쪽 왼쪽 여백
          end: 8.0,                    // 버튼 안쪽 오른쪽 여백
        ),
        iconSize: iconSize,
        splashRadius: 0.01,
        icon: const Icon(Icons.arrow_back_ios),
        onPressed: () => Navigator.of(context).maybePop(),
        color: MainColors.kbDarkGray,
      ),
      title: Text(
        title,

        style: TextStyle(
          color: MainColors.kbDarkGray, //MainColors.blue,
          fontWeight: FontWeight.w700,
          fontFamily: fontFamily,
          fontSize: 18,
        ),
      ),
      iconTheme: const IconThemeData(color: MainColors.blue),
    );
  }

  @override
  Size get preferredSize => Size.fromHeight(appBar.preferredSize.height);
}
