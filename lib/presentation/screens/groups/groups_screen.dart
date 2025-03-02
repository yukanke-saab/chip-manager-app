import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/themes/app_colors.dart';
import '../../../data/models/group_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/group_repository.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _authRepository = AuthRepository();
  final _groupRepository = GroupRepository();
  
  bool _isLoading = true;
  List<GroupModel> _groups = [];
  String? _errorMessage;
  bool _isLoggedIn = false;
  
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _loadGroups();
  }
  
  Future<void> _checkLoginStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    final authRepo = AuthRepository();
    bool isAnonymous = false;
    
    if (user != null) {
      try {
        isAnonymous = await authRepo.isAnonymousUser();
      } catch (e) {
        print('匿名ユーザーチェックエラー: $e');
        isAnonymous = true;
      }
    }
    
    if (mounted) {
      setState(() {
        // 匿名ユーザーでない認証済みユーザーのみtrueとする
        _isLoggedIn = user != null && !isAnonymous;
      });
    }
  }
  
  Future<void> _loadGroups() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      try {
        // グループを取得
        final groups = await _groupRepository.getUserGroups();
        if (mounted) {
          setState(() {
            _groups = groups;
            _isLoading = false;
          });
          print('グループ数: ${groups.length}');
        }
      } catch (e) {
        print('グループ取得エラー: $e');
        if (mounted) {
          setState(() {
            _groups = [];
            _isLoading = false;
          });
        }
      }
      
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = e.toString();
          _isLoading = false;
        });
      }
    }
  }
  
  Future<void> _logout() async {
    try {
      await _authRepository.signOut();
      
      setState(() {
        _isLoggedIn = false;
      });
      
      // グループ一覧を再読み込み
      _loadGroups();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('ログアウトに失敗しました: ${e.toString()}')),
      );
    }
  }
  
  void _navigateToLogin() {
    context.push('/login');
  }
  
  void _navigateToRegister() {
    context.push('/register');
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('グループ一覧'),
        actions: [
          // リロードボタン
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroups,
            tooltip: '再読み込み',
          ),
          // グループ作成ボタン
          IconButton(
            icon: const Icon(Icons.add),
            onPressed: () => context.push('/groups/create'),
            tooltip: 'グループを作成',
          ),
          // グループ参加ボタン
          IconButton(
            icon: const Icon(Icons.group_add),
            onPressed: _showJoinGroupDialog,
            tooltip: 'グループに参加',
          ),
          // ログイン/ログアウトボタン
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
          // 会員登録なしでもグループ作成可能
          // アカウント登録のメリットを説明するダイアログを表示
          if (!_isLoggedIn) {
            // 必須ではないが、メリットを説明
            _showLoginPromptDialog();
          }
          
          // グループ作成画面へ遷移
          context.push('/groups/create');
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
    
    if (_errorMessage != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              'エラーが発生しました',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGroups,
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }
    
    // 以前はここに未ログイン時の画面がありましたが、今回の変更で匿名ユーザーでもグループを表示するので削除します
    
    if (_groups.isEmpty) {
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
              'グループがありません',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('新しいグループを作成するか、招待コードで参加してください'),
            const SizedBox(height: 24),
            SizedBox(
              width: 280,
              height: 56,
              child: ElevatedButton.icon(
                onPressed: () {
                  // グループ作成画面へ遷移
                  context.push('/groups/create');
                },
                icon: const Icon(Icons.add, size: 28),
                label: const Text('グループを作成する', style: TextStyle(fontSize: 18)),
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 24),
                ),
              ),
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: () {
                _showJoinGroupDialog();
              },
              icon: const Icon(Icons.group_add),
              label: const Text('グループに参加する'),
            ),
          ],
        ),
      );
    }
    
    return RefreshIndicator(
      onRefresh: _loadGroups,
      child: ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _groups.length,
        itemBuilder: (context, index) {
          final group = _groups[index];
          return _buildGroupCard(group);
        },
      ),
    );
  }
  
  Widget _buildGroupCard(GroupModel group) {
    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      child: InkWell(
        onTap: () {
          // グループ詳細画面へ遷移
          context.push('/groups/${group.id}');
        },
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      group.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                  const Icon(Icons.chevron_right),
                ],
              ),
              if (group.description.isNotEmpty) ...[
                const SizedBox(height: 8),
                Text(
                  group.description,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              const SizedBox(height: 8),
              Row(
                children: [
                  const Icon(
                    Icons.monetization_on_outlined,
                    size: 16,
                    color: AppColors.textLight,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    'チップ単位: ${group.chipUnit}',
                    style: TextStyle(
                      color: AppColors.textLight,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _showLoginPromptDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('アカウント登録のメリット'),
        content: const Text('アカウントを登録すると、機種変更時やアプリ再インストール時にデータを引き継ぐことができます。登録は任意です。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('後で登録する'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToLogin();
            },
            child: const Text('ログイン'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              _navigateToRegister();
            },
            child: const Text('新規登録'),
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
            onPressed: () async {
              final code = controller.text.trim().toUpperCase();
              if (code.isEmpty) return;
              
              Navigator.pop(context);
              
              try {
                await _groupRepository.joinGroupByInviteCode(code);
                
                if (!mounted) return;
                
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('グループに参加しました！')),
                );
                
                _loadGroups(); // グループ一覧を再読み込み
              } catch (e) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('参加に失敗しました: ${e.toString()}')),
                );
              }
            },
            child: const Text('参加'),
          ),
        ],
      ),
    );
  }
}
