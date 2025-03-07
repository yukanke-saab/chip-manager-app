import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:google_mobile_ads/google_mobile_ads.dart';

/// 広告サービス
/// シングルトンパターンで実装し、アプリ全体で広告を管理する
class AdService {
  // シングルトンインスタンス
  static final AdService _instance = AdService._internal();
  
  factory AdService() => _instance;
  
  AdService._internal();
  
  // 初期化フラグ
  bool _initialized = false;
  
  // リワード広告
  RewardedAd? _rewardedAd;
  
  // 初期化メソッド
  Future<void> initialize() async {
    if (_initialized) return;
    
    // モバイル広告SDKを初期化
    await MobileAds.instance.initialize();
    
    _initialized = true;
    debugPrint('AdService: 広告SDKが初期化されました');
  }
  
  // テスト用広告ID
  String get _rewardedAdUnitId {
    // 本番環境ではここを書き換える
    if (Platform.isAndroid) {
      return 'ca-app-pub-3940256099942544/5224354917';
    } else if (Platform.isIOS) {
      return 'ca-app-pub-3940256099942544/1712485313';
    } else {
      throw UnsupportedError('このプラットフォームは広告に対応していません');
    }
  }
  
  // リワード広告を事前にロード
  Future<void> preloadRewardedAd() async {
    if (!_initialized) await initialize();
    
    await RewardedAd.load(
      adUnitId: _rewardedAdUnitId,
      request: const AdRequest(),
      rewardedAdLoadCallback: RewardedAdLoadCallback(
        onAdLoaded: (ad) {
          _rewardedAd = ad;
          debugPrint('AdService: リワード広告がロードされました');
        },
        onAdFailedToLoad: (error) {
          debugPrint('AdService: リワード広告のロードに失敗しました - ${error.message}');
          _rewardedAd = null;
        },
      ),
    );
  }
  
  // リワード広告を表示
  Future<bool> showRewardedAd({
    Function? onRewarded,
    Function? onAdClosed,
    Function? onAdFailedToShow,
  }) async {
    if (!_initialized) await initialize();
    
    if (_rewardedAd == null) {
      await preloadRewardedAd();
      if (_rewardedAd == null) {
        // 広告のロードに失敗したら新しくロードを試みる
        debugPrint('AdService: 広告の表示に失敗しました - 広告がロードされていません');
        if (onAdFailedToShow != null) onAdFailedToShow();
        return false;
      }
    }
    
    // フルスクリーン表示コールバック
    _rewardedAd!.fullScreenContentCallback = FullScreenContentCallback(
      onAdDismissedFullScreenContent: (ad) {
        debugPrint('AdService: 広告が閉じられました');
        ad.dispose();
        _rewardedAd = null;
        // 次回の広告を事前にロード
        preloadRewardedAd();
        if (onAdClosed != null) onAdClosed();
      },
      onAdFailedToShowFullScreenContent: (ad, error) {
        debugPrint('AdService: 広告の表示に失敗しました - ${error.message}');
        ad.dispose();
        _rewardedAd = null;
        if (onAdFailedToShow != null) onAdFailedToShow();
      },
    );
    
    // 報酬付与コールバック
    _rewardedAd!.setImmersiveMode(true);
    _rewardedAd!.show(
      onUserEarnedReward: (ad, reward) {
        debugPrint('AdService: 報酬が付与されました ${reward.amount} ${reward.type}');
        if (onRewarded != null) onRewarded(reward);
      },
    );
    
    return true;
  }
  
  // リソースの破棄
  void dispose() {
    _rewardedAd?.dispose();
    _rewardedAd = null;
  }
}
