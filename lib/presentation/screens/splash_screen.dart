import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:go_router/go_router.dart';
import '../../core/themes/app_colors.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({Key? key}) : super(key: key);

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _navigateToHome();
  }

  Future<void> _navigateToHome() async {
    // スプラッシュ画面を少し表示するためのディレイ
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // 認証状態に関わらずグループ一覧画面へ遷移
    context.go('/groups');
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
