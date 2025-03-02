import 'package:flutter/material.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../data/models/group_model.dart';
import '../../../../data/repositories/group_repository.dart';
import '../../../../data/repositories/auth_repository.dart';

class GroupDetailScreen extends StatefulWidget {
  final String groupId;
  
  const GroupDetailScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  State<GroupDetailScreen> createState() => _GroupDetailScreenState();
}

class _GroupDetailScreenState extends State<GroupDetailScreen> with SingleTickerProviderStateMixin {
  final _groupRepository = GroupRepository();
  final _authRepository = AuthRepository();
  
  late TabController _tabController;
  bool _isLoading = true;
  GroupModel? _group;
  String? _errorMessage;
  List<dynamic> _members = [];
  bool _isOwner = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _loadGroupDetails();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupDetails() async {
    try {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });

      // グループ詳細を取得
      final group = await _groupRepository.getGroupDetails(widget.groupId);
      if (group == null) {
        throw Exception('グループが見つかりません');
      }

      // グループメンバーを取得
      final members = await _groupRepository.getGroupMembers(widget.groupId);
      
      // 自分が所有者かチェック
      final currentUser = _authRepository.currentUser;
      bool isOwner = false;
      
      if (currentUser != null) {
        final ownerId = group.ownerId;
        isOwner = ownerId == currentUser.id;
        
        // メンバーロールでも確認
        for (final member in members) {
          if (member.userId == currentUser.id && member.isOwner) {
            isOwner = true;
            break;
          }
        }
      }
      
      setState(() {
        _group = group;
        _members = members;
        _isOwner = isOwner;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _isLoading
            ? const Text('グループ詳細')
            : Text(_group?.name ?? 'グループ詳細'),
        actions: [
          // リロードボタン
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadGroupDetails,
            tooltip: '再読み込み',
          ),
          // オーナーの場合は編集ボタンを表示
          if (_isOwner && !_isLoading)
            IconButton(
              icon: const Icon(Icons.edit),
              onPressed: () {
                // TODO: グループ編集画面へ遷移
              },
              tooltip: 'グループを編集',
            ),
        ],
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '概要'),
            Tab(text: 'メンバー'),
            Tab(text: '取引履歴'),
          ],
        ),
      ),
      body: _buildBody(),
      floatingActionButton: _buildFloatingActionButton(),
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
              onPressed: _loadGroupDetails,
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    if (_group == null) {
      return const Center(
        child: Text('グループ情報がありません'),
      );
    }

    return TabBarView(
      controller: _tabController,
      children: [
        _buildSummaryTab(),
        _buildMembersTab(),
        _buildTransactionsTab(),
      ],
    );
  }

  Widget _buildSummaryTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // グループ情報カード
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'グループ情報',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildInfoRow('名前', _group!.name),
                  const SizedBox(height: 8),
                  _buildInfoRow('説明', _group!.description.isNotEmpty
                      ? _group!.description
                      : '(説明はありません)'),
                  const SizedBox(height: 8),
                  _buildInfoRow('チップ単位', _group!.chipUnit),
                  const SizedBox(height: 8),
                  _buildInfoRow('招待コード', _group!.inviteCode),
                  const SizedBox(height: 8),
                  _buildInfoRow('作成日', _formatDate(_group!.createdAt)),
                ],
              ),
            ),
          ),
          
          // グループ統計カード
          Card(
            margin: const EdgeInsets.only(bottom: 16),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '統計情報',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(),
                  const SizedBox(height: 8),
                  _buildInfoRow('メンバー数', '${_members.length}人'),
                  // TODO: 取引数や合計チップ数などの統計を追加
                ],
              ),
            ),
          ),
          
          // 招待リンク共有カード
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'メンバーを招待',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const Divider(),
                  const SizedBox(height: 16),
                  const Text('招待コードを共有してメンバーを招待しましょう。'),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          _group!.inviteCode,
                          style: const TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                            letterSpacing: 2,
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.copy),
                        onPressed: () {
                          // TODO: クリップボードにコピー
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('招待コードをコピーしました')),
                          );
                        },
                        tooltip: 'コピー',
                      ),
                      IconButton(
                        icon: const Icon(Icons.share),
                        onPressed: () {
                          // TODO: 共有機能
                        },
                        tooltip: '共有',
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMembersTab() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _members.length,
      itemBuilder: (context, index) {
        final member = _members[index];
        final profile = member.profile;
        final isCurrentUser = member.userId == _authRepository.currentUser?.id;
        
        return Card(
          margin: const EdgeInsets.only(bottom: 16),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary,
              child: Text(
                profile.displayName[0].toUpperCase(),
                style: const TextStyle(color: Colors.white),
              ),
            ),
            title: Row(
              children: [
                Expanded(
                  child: Text(
                    profile.displayName,
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ),
                if (isCurrentUser)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.primaryLight,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'あなた',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.white,
                      ),
                    ),
                  ),
              ],
            ),
            subtitle: Text(
              _getRoleText(member.role),
              style: TextStyle(
                color: _getRoleColor(member.role),
              ),
            ),
            trailing: _isOwner && !isCurrentUser
                ? IconButton(
                    icon: const Icon(Icons.more_vert),
                    onPressed: () {
                      // TODO: メンバー管理メニュー
                    },
                  )
                : null,
          ),
        );
      },
    );
  }

  Widget _buildTransactionsTab() {
    // TODO: 取引履歴の実装
    return const Center(
      child: Text('取引履歴はまだありません'),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 100,
          child: Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.bold,
              color: AppColors.textLight,
            ),
          ),
        ),
        Expanded(
          child: Text(value),
        ),
      ],
    );
  }

  Widget? _buildFloatingActionButton() {
    if (_isLoading) return null;
    
    return FloatingActionButton(
      onPressed: () {
        // 現在のタブに応じたアクション
        switch (_tabController.index) {
          case 0: // 概要タブ
            // TODO: QRコード生成画面へ遷移
            break;
          case 1: // メンバータブ
            if (_isOwner) {
              // TODO: メンバー追加画面へ遷移
            }
            break;
          case 2: // 取引履歴タブ
            // TODO: チップ取引画面へ遷移
            break;
        }
      },
      tooltip: _getFloatingActionButtonTooltip(),
      child: Icon(_getFloatingActionButtonIcon()),
    );
  }

  String _getFloatingActionButtonTooltip() {
    switch (_tabController.index) {
      case 0:
        return 'QRコードを表示';
      case 1:
        return _isOwner ? 'メンバーを追加' : '詳細を表示';
      case 2:
        return 'チップを追加';
      default:
        return '';
    }
  }

  IconData _getFloatingActionButtonIcon() {
    switch (_tabController.index) {
      case 0:
        return Icons.qr_code;
      case 1:
        return _isOwner ? Icons.person_add : Icons.info;
      case 2:
        return Icons.add;
      default:
        return Icons.add;
    }
  }

  String _getRoleText(String role) {
    switch (role) {
      case 'owner':
        return 'オーナー';
      case 'temporary_owner':
        return '一時オーナー';
      case 'member':
        return 'メンバー';
      default:
        return role;
    }
  }

  Color _getRoleColor(String role) {
    switch (role) {
      case 'owner':
        return Colors.red;
      case 'temporary_owner':
        return Colors.orange;
      case 'member':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.year}/${date.month}/${date.day} ${date.hour}:${date.minute.toString().padLeft(2, '0')}';
  }
}
