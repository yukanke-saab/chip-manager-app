import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'data/repositories/auth_repository.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/auth/forgot_password_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/groups/groups_screen.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();
  
  // 認証リポジトリ
  static final _authRepository = AuthRepository();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    navigatorKey: _rootNavigatorKey,
    debugLogDiagnostics: true,
    
    // リダイレクト処理
    redirect: (BuildContext context, GoRouterState state) async {
      // スプラッシュ画面はリダイレクトしない
      if (state.matchedLocation == '/') {
        return null;
      }
      
      // 認証関連のページへは自由にアクセス可能
      final isAuthPage = state.matchedLocation == '/login' || 
                         state.matchedLocation == '/register' ||
                         state.matchedLocation == '/forgot-password';
      
      if (isAuthPage) {
        return null;
      }
      
      // それ以外の場合はリダイレクトなし（匿名セッションが自動的に作成されるため）
      return null;
    },
    
    routes: [
      // スプラッシュ画面
      GoRoute(
        path: '/',
        builder: (context, state) => const SplashScreen(),
      ),
      
      // 認証関連のルート
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginScreen(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterScreen(),
      ),
      GoRoute(
        path: '/forgot-password',
        builder: (context, state) => const ForgotPasswordScreen(),
      ),
      
      // グループ一覧画面
      GoRoute(
        path: '/groups',
        builder: (context, state) => const GroupsScreen(),
      ),
      
      // TODO: 以下のルートは今後実装予定
      // グループ詳細画面
      // GoRoute(
      //   path: '/groups/:id',
      //   builder: (context, state) {
      //     final groupId = state.pathParameters['id']!;
      //     return GroupDetailScreen(groupId: groupId);
      //   },
      // ),
      
      // プロフィール画面
      // GoRoute(
      //   path: '/profile',
      //   builder: (context, state) => const ProfileScreen(),
      // ),
    ],
    
    // エラーページ
    errorBuilder: (context, state) => Scaffold(
      body: Center(
        child: Text('エラーが発生しました: ${state.error}'),
      ),
    ),
  );
}
