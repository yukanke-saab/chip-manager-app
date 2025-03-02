import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/themes/app_colors.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  bool _isLoading = false;
  List<Map<String, dynamic>> _groups = [];
  String? _errorMessage;
  bool _isLoggedIn = false;
  
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }
  
  void _checkLoginStatus() {
    final user = Supabase.instance.client.auth.currentUser;
    setState(() {
      _isLoggedIn = user != null;
    });
  }
  
  void _navigateToLogin() {
    context.push('/login');
  }
  
  void _navigateToRegister() {
    context.push('/register');
  }
  
  Future<void> _logout() async {
    setState(() {
      _isLoading = true;
    });
    
    try {
      await Supabase.instance.client.auth.signOut();
      
      setState(() {
        _isLoggedIn = false;
        _isLoading = false;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ログアウトに失敗しました: ${e.toString()}')),
      );
      
      setState(() {
        _isLoading = false;
      });
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('グループ一覧'),
        actions: [
          _isLoggedIn
              ? IconButton(
                  icon: const Icon(Icons.logout),
                  onPressed: _logout,
                  tooltip: 'ログアウト',
                )
              : TextButton(
                  onPressed: _navigateToLogin,
                  child: const Text('ログイン'),
                ),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // グループ作成 - 会員登録を促すダイアログ表示
          if (!_isLoggedIn) {
            _showLoginPromptDialog();
          } else {
            // TODO: グループ作成画面へ遷移
            // context.push('/groups/create');
          }
        },
        tooltip: '新しいグループを作成',
        child: const Icon(Icons.add),
      ),
    );
  }
  
  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }
    
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(
            Icons.group_outlined,
            size: 64,
            color: AppColors.textLight,
          ),
          const SizedBox(height: 16),
          Text(
            'ようこそ、Chip Managerへ',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          const Text('ポーカーチップを簡単に管理できるアプリです。'),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton.icon(
                onPressed: () {
                  if (!_isLoggedIn) {
                    _showLoginPromptDialog();
                  } else {
                    // TODO: グループ作成画面へ遷移
                  }
                },
                icon: const Icon(Icons.add),
                label: const Text('グループ作成'),
              ),
              const SizedBox(width: 16),
              OutlinedButton.icon(
                onPressed: () {
                  _showJoinGroupDialog();
                },
                icon: const Icon(Icons.group_add),
                label: const Text('グループ参加'),
              ),
            ],
          ),
          if (!_isLoggedIn) ...[
            const SizedBox(height: 32),
            const Text('会員登録すると以下の機能が使えます：'),
            const SizedBox(height: 8),
            Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                    const SizedBox(width: 8),
                    const Text('グループの作成と管理'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                    const SizedBox(width: 8),
                    const Text('端末間でのデータ同期'),
                  ],
                ),
                const SizedBox(height: 4),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.check_circle, color: AppColors.success, size: 16),
                    const SizedBox(width: 8),
                    const Text('履歴の閲覧と分析'),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _navigateToRegister,
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.secondary,
              ),
              child: const Text('会員登録する（無料）'),
            ),
          ],
        ],
      ),
    );
  }
  
  void _showLoginPromptDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('会員登録が必要です'),
        content: const Text('グループを作成するには会員登録が必要です。会員登録は無料です。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToRegister();
            },
            child: const Text('会員登録'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToLogin();
            },
            child: const Text('ログイン'),
          ),
        ],
      ),
    );
  }
  
  void _showJoinGroupDialog() {
    final TextEditingController controller = TextEditingController();
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('グループに参加'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('招待コードを入力してください'),
            const SizedBox(height: 16),
            TextField(
              controller: controller,
              decoration: const InputDecoration(
                labelText: '招待コード',
                hintText: '例: ABC123',
              ),
              textCapitalization: TextCapitalization.characters,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
            },
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              final code = controller.text.trim().toUpperCase();
              if (code.isEmpty) return;
              
              Navigator.pop(context);
              
              if (!_isLoggedIn) {
                _showLoginPromptDialog();
                return;
              }
              
              // TODO: グループ参加処理
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('この機能は現在実装中です')),
              );
            },
            child: const Text('参加'),
          ),
        ],
      ),
    );
  }
}
