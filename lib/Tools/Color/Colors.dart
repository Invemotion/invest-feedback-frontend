// import 'package:flutter/material.dart';
//
// class MainColors {
//   static const Color background = Color(0xfff2f2f2);
//   static const Color blue = Color(0xff4169e1);
// }

import 'package:flutter/material.dart';

/// 브랜드 컬러 및 시트 컬러 정의
class MainColors {
  // 배경/기본 텍스트 색
  static const Color background = Color(0xfffafafa);
  static const Color blue       =  Color(0xff4169e1);

  // ────────── Main Color ──────────
  /// KB Yellow Positive
  /// Pantone 130 C / C0 M35 Y100 K0 / RGB(255,188,0)
  static const Color kbYellowPositive = Color(0xffffbc00);

  /// KB Yellow Negative
  /// Pantone 1235 C / C0 M27 Y100 K0 / RGB(255,204,0)
  static const Color kbYellowNegative = Color(0xffffcc00);

  /// KB Gray
  /// Pantone 404 C / C0 M10 Y20 K65 / RGB(96,88,76)
  static const Color kbGray = Color(0xff60584c);

  // ────────── Sub Color ──────────
  /// KB Dark Gray
  /// Pantone 411 C / C70 M65 Y75 K25 / RGB(84,80,69)
  static const Color kbDarkGray = Color(0xff545045);

  /// KB Gold
  /// Pantone 872 C / (sheet: 3M Gold Metallic 3660-121)
  /// RGB 대략(176,138,58)
  static const Color kbGold = Color(0xffb08a3a);

  /// KB Silver
  /// Pantone 877 C / (sheet: 3M Silver 3630-121)
  /// RGB 대략(139,143,148)
  static const Color kbSilver = Color(0xff8b8f94);

  // ────────── Sheet Colors (Main) ──────────
  /// 3M VT 10891 (Yellow Positive)
  static const Color sheet3mVt10891 = Color(0xffffbc00);

  /// 3M VT 10801 (Yellow Negative)
  static const Color sheet3mVt10801 = Color(0xffffcc00);

  /// 3M VTB 11148 / 11107 (KB Gray, 윈도우 데칼용)
  static const Color sheet3mVtb11148 = Color(0xff60584c);

  // ────────── Sheet Colors (Sub) ──────────
  /// LG하우시스 LB9706KB (Dark Gray)
  static const Color sheetLgLb9706kb = Color(0xff545045);

  /// 3M Gold Metallic 3660-121
  static const Color sheet3mGoldMetallic = Color(0xffdab66f);

  /// 3M Silver 3630-121
  static const Color sheet3mSilver3630 = Color(0xffc0c4c8);
}
