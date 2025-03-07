import 'package:flutter/material.dart';
import '../../../services/ad_service.dart';

/// 広告表示用ダイアログユーティリティ
class AdDialogUtils {
  // プライベートコンストラクタ
  AdDialogUtils._();
  
  /// チップ取引後の広告表示ダイアログ
  static Future<bool> showTransactionAdDialog(BuildContext context) async {
    // 広告サービスのインスタンスを取得
    final adService = AdService();
    
    // 広告を事前にロード
    await adService.preloadRewardedAd();
    
    // 広告表示の結果を格納する変数
    bool adWasShown = false;
    
    // 広告表示ダイアログを表示
    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('チップ取引が成立しました'),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle, color: Colors.green, size: 64),
            SizedBox(height: 16),
            Text(
              '取引が正常に処理されました。\n'
              '続行するには、広告を視聴してください。',
              textAlign: TextAlign.center,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () async {
              // 広告を表示
              adWasShown = await adService.showRewardedAd(
                onRewarded: (_) {
                  // 報酬付与時の処理（必要に応じて実装）
                },
                onAdClosed: () {
                  // 広告が閉じられたらダイアログも閉じる
                  Navigator.of(context).pop();
                },
                onAdFailedToShow: () {
                  // 広告表示に失敗したらメッセージを表示
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('広告の読み込みに失敗しました。しばらく経ってからもう一度お試しください。'),
                      duration: Duration(seconds: 3),
                    ),
                  );
                  Navigator.of(context).pop();
                },
              );
              
              // 広告が表示されなかった場合はダイアログを閉じる
              if (!adWasShown) {
                Navigator.of(context).pop();
              }
            },
            child: const Text('広告を視聴する'),
          ),
        ],
      ),
    );
    
    return adWasShown;
  }
}
