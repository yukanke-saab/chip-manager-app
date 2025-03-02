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
  
  void _checkLoginStatus() {
    final user = Supabase.instance.client.auth.currentUser;
    setState(() {
      _isLoggedIn = user != null;
    });
  }
  
  Future<void> _loadGroups() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
      
      // ログインしている場合のみグループを読み込む
      if (_isLoggedIn) {
        final groups = await _groupRepository.getUserGroups();
        setState(() {
          _groups = groups;
        });
      } else {
        setState(() {
          _groups = [];
        });
      }
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
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
          // グループを作成するにはログインが必要
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
    
    if (!_isLoggedIn) {
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
              'Chip Managerへようこそ',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            const Text('ポーカーチップを簡単に管理できるアプリです'),
            const SizedBox(height: 32),
            const Text('アプリを利用するにはアカウントが必要です'),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton(
                  onPressed: _navigateToLogin,
                  child: const Text('ログイン'),
                ),
                const SizedBox(width: 16),
                ElevatedButton(
                  onPressed: _navigateToRegister,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.secondary,
                  ),
                  child: const Text('新規登録'),
                ),
              ],
            ),
          ],
        ),
      );
    }
    
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
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                ElevatedButton.icon(
                  onPressed: () {
                    // TODO: グループ作成画面へ遷移
                    // context.push('/groups/create');
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
          // TODO: グループ詳細画面へ遷移
          // context.push('/groups/${group.id}');
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
        title: const Text('アカウントが必要です'),
        content: const Text('この機能を利用するにはログインが必要です。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
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
