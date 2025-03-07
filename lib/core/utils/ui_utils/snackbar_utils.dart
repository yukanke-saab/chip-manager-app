import 'package:flutter/material.dart';

/// 安全にスナックバーを表示するためのユーティリティクラス
class SnackbarUtils {
  /// 安全にスナックバーを表示する
  /// 
  /// このメソッドはコンテキストを保存し、Widgetのライフサイクルに関係なく
  /// スナックバーを表示できます。これにより、非同期操作後に安全にスナックバーを表示できます。
  static void showSnackBar(BuildContext context, String message, {Duration? duration}) {
    // まずBuildContextが有効かチェック
    if (!context.mounted) return;
    
    // 保存したScaffoldMessengerStateを使用
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    
    // 既存のスナックバーを閉じる
    scaffoldMessenger.hideCurrentSnackBar();
    
    // 新しいスナックバーを表示
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Text(message),
        duration: duration ?? const Duration(seconds: 3),
      ),
    );
  }
  
  /// エラーメッセージをスナックバーとして表示する
  static void showErrorSnackBar(BuildContext context, String message, {Duration? duration}) {
    if (!context.mounted) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.error_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.red,
        duration: duration ?? const Duration(seconds: 4),
      ),
    );
  }
  
  /// 成功メッセージをスナックバーとして表示する
  static void showSuccessSnackBar(BuildContext context, String message, {Duration? duration}) {
    if (!context.mounted) return;
    
    final scaffoldMessenger = ScaffoldMessenger.of(context);
    scaffoldMessenger.hideCurrentSnackBar();
    
    scaffoldMessenger.showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(child: Text(message)),
          ],
        ),
        backgroundColor: Colors.green,
        duration: duration ?? const Duration(seconds: 2),
      ),
    );
  }
}
