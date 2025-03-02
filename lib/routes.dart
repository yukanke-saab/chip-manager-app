import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'presentation/screens/auth/login_screen.dart';
import 'presentation/screens/auth/register_screen.dart';
import 'presentation/screens/auth/forgot_password_screen.dart';
import 'presentation/screens/splash_screen.dart';
import 'presentation/screens/groups/groups_screen.dart';
import 'presentation/screens/groups/create_group.dart';
import 'presentation/screens/groups/group_detail.dart';

class AppRouter {
  static final _rootNavigatorKey = GlobalKey<NavigatorState>();

  static final GoRouter router = GoRouter(
    initialLocation: '/',
    navigatorKey: _rootNavigatorKey,
    debugLogDiagnostics: true,
    
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
      
      // グループ作成画面
      GoRoute(
        path: '/groups/create',
        builder: (context, state) => const CreateGroupScreen(),
      ),
      
      // グループ詳細画面
      GoRoute(
        path: '/groups/:id',
        builder: (context, state) {
          final groupId = state.pathParameters['id']!;
          return GroupDetailScreen(groupId: groupId);
        },
      ),
      
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
