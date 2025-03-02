import 'package:flutter/material.dart';

class AppColors {
  // プライベートコンストラクタでインスタンス化を防止
  AppColors._();
  
  // ブランドカラー
  static const primary = Color(0xFF2563EB); // メインカラー（濃い青）
  static const primaryLight = Color(0xFF60A5FA); // 明るい青
  static const secondary = Color(0xFF10B981); // 緑
  static const accent = Color(0xFFF59E0B); // 黄色/オレンジ
  
  // テキストカラー
  static const textDark = Color(0xFF1F2937); // 暗めのテキスト
  static const textLight = Color(0xFF6B7280); // 薄めのテキスト
  
  // 背景色
  static const backgroundLight = Color(0xFFF9FAFB); // ライトモードの背景
  static const backgroundDark = Color(0xFF111827); // ダークモードの背景
  
  // 状態カラー
  static const success = Color(0xFF10B981); // 成功
  static const error = Color(0xFFEF4444); // エラー
  static const warning = Color(0xFFF59E0B); // 警告
  static const info = Color(0xFF3B82F6); // 情報
  
  // チップ関連カラー
  static const positiveChip = Color(0xFF10B981); // プラスのチップ
  static const negativeChip = Color(0xFFEF4444); // マイナスのチップ
}
