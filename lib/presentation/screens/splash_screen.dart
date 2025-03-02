import 'package:flutter/material.dart';
import 'package:flutter_spinkit/flutter_spinkit.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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
    _redirectUser();
  }

  Future<void> _redirectUser() async {
    await Future.delayed(const Duration(seconds: 2));
    
    if (!mounted) return;
    
    // 現在のユーザーを確認
    final user = Supabase.instance.client.auth.currentUser;
    
    if (user != null) {
      // ユーザーがログイン済みの場合はグループ一覧画面へ
      context.go('/groups');
    } else {
      // 未ログインの場合はログイン画面へ
      context.go('/login');
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
