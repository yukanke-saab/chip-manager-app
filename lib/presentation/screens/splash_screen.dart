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
    _initSession();
  }

  Future<void> _initSession() async {
    // スプラッシュ画面を少し表示するためのディレイ
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    try {
      // 匿名セッションを確保
      await _authRepository.getOrCreateAnonymousSession();
      
      if (!mounted) return;
      
      // グループ一覧画面へ移動
      context.go('/groups');
    } catch (e) {
      print('匿名セッション作成エラー: $e');
      
      if (!mounted) return;
      
      // エラーがあっても移動（UIで対応）
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
