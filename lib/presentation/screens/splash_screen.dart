import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import '../../core/themes/app_colors.dart';
import '../../data/repositories/auth_repository.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final _authRepository = AuthRepository();
  
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // スプラッシュ画面を少し表示するためのディレイ
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // 匿名セッションを試行する
    try {
      final user = await _authRepository.getOrCreateAnonymousSession();
      print('セッション状態: ' + (user != null ? '成功' : '失敗だが続行'));
    } catch (e) {
      print('匿名セッション作成エラー: $e');
      // エラーを無視して続行
    }
    
    if (!mounted) return;
    
    // 認証の成功・失敗に関わらず、グループ一覧画面へ移動
    context.go('/groups');
  }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // TODO: ロゴ画像を追加
            const Text(
              'Chip Manager',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 20),
            const SpinKitDoubleBounce(
              color: AppColors.primary,
              size: 50.0,
            ),
          ],
        ),
      ),
    );
  }
}
