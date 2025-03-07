import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:io' show Platform;
import '../../../core/themes/app_colors.dart';
import '../../../data/models/group_model.dart';
import '../../../data/repositories/auth_repository.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../core/utils/ui_utils/snackbar_utils.dart';
import '../../../data/repositories/ad_notification_repository.dart';
import '../../../core/utils/ui_utils/ad_dialog_utils.dart';
import '../../../data/models/ad_notification_model.dart';

class GroupsScreen extends StatefulWidget {
  const GroupsScreen({Key? key}) : super(key: key);

  @override
  State<GroupsScreen> createState() => _GroupsScreenState();
}

class _GroupsScreenState extends State<GroupsScreen> {
  final _authRepository = AuthRepository();
  final _groupRepository = GroupRepository();
  final _adNotificationRepository = AdNotificationRepository();
  
  bool _isLoading = true;
  List<GroupModel> _groups = [];
  String? _errorMessage;
  bool _isLoggedIn = false;
  bool _isAnonymous = true;
  
  // 広告通知関連
  List<AdNotificationModel> _adNotifications = [];
  Stream<List<AdNotificationModel>>? _notificationsStream;
  
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
    _loadGroups();
    _setupNotificationsListener();
    _checkPendingNotifications();
  }
  
  Future<void> _checkLoginStatus() async {
    final user = Supabase.instance.client.auth.currentUser;
    bool isAnonymous = false;
    
    if (user != null) {
      try {
        isAnonymous = await _authRepository.isAnonymousUser();
        
        if (mounted) {
          setState(() {
            _isAnonymous = isAnonymous;
          });
        }
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
  
  // 通知リスナーを設定
  void _setupNotificationsListener() {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        _notificationsStream = _adNotificationRepository.subscribeToNotifications();

        // ストリーム購読
        _notificationsStream?.listen((notifications) {
          if (mounted) {
            setState(() {
              _adNotifications = notifications;
            });
            
            // 新しい通知があればチェック
            if (notifications.isNotEmpty) {
              _handleNewNotifications(notifications);
            }
          }
        }, onError: (e) {
          print('通知リスナーエラー: $e');
        });
      } catch (e) {
        print('通知ストリーム設定エラー: $e');
      }
    }
  }
  
  // 既存の通知をチェック
  Future<void> _checkPendingNotifications() async {
    if (Platform.isAndroid || Platform.isIOS) {
      try {
        final notifications = await _adNotificationRepository.getUnshownNotifications();
        if (notifications.isNotEmpty && mounted) {
          setState(() {
            _adNotifications = notifications;
          });
          
          // クリックして広告を表示するように促す
          // 動画広告は自動再生できないため、ユーザーのアクションが必要
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (notifications.length == 1) {
              _showNotificationDialog(
                '広告表示があります',
                'チップ取引が完了しました。\n広告を視聴して取引を確定しますか？',
                notifications.first,
              );
            } else if (notifications.length > 1) {
              _showNotificationDialog(
                '複数の広告表示があります',
                '${notifications.length}件のチップ取引が完了しました。\n広告を視聴して取引を確定しますか？',
                notifications.first,
              );
            }
          });
        }
      } catch (e) {
        print('既存通知チェックエラー: $e');
      }
    }
  }
  
  // 新しい通知を処理
  void _handleNewNotifications(List<AdNotificationModel> notifications) {
    if (notifications.isEmpty) return;
    
    // 最新の通知を取得
    final latestNotification = notifications.first;
    
    // 通知ダイアログを表示
    _showNotificationDialog(
      '新しいチップ取引',
      'チップ取引が完了しました。\n広告を視聴して取引を確定しますか？',
      latestNotification,
    );
  }
  
  // 通知ダイアログを表示
  void _showNotificationDialog(String title, String message, AdNotificationModel notification) {
    if (!mounted) return;
    
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
            },
            child: const Text('後で視聴する'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              
              // 広告表示ダイアログを表示
              final adShown = await AdDialogUtils.showTransactionAdDialog(context);
              
              // 広告が表示されたら通知を表示済みに更新
              if (adShown) {
                await _adNotificationRepository.markAsShown(notification.id);
                
                // 通知リストから除外
                if (mounted) {
                  setState(() {
                    _adNotifications.removeWhere((n) => n.id == notification.id);
                  });
                }
              }
            },
            child: const Text('広告を視聴する'),
          ),
        ],
      ),
    );
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
      if (mounted) {
        SnackbarUtils.showErrorSnackBar(context, 'ログアウトに失敗しました: ${e.toString()}');
      }
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
          // 広告通知バッジ
          if (_adNotifications.isNotEmpty)
            Stack(
              alignment: Alignment.center,
              children: [
                IconButton(
                  icon: const Icon(Icons.notifications),
                  onPressed: () {
                    // 最新の通知を表示
                    if (_adNotifications.isNotEmpty) {
                      _showNotificationDialog(
                        '未視聴の広告',
                        'チップ取引が完了しています。広告を視聴して取引を確定しますか？',
                        _adNotifications.first,
                      );
                    }
                  },
                  tooltip: '広告通知',
                ),
                Positioned(
                  top: 8,
                  right: 8,
                  child: Container(
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      color: Colors.red,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    constraints: const BoxConstraints(
                      minWidth: 16,
                      minHeight: 16,
                    ),
                    child: Text(
                      _adNotifications.length > 9 ? '9+' : _adNotifications.length.toString(),
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                ),
              ],
            ),
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
    final _inviteCodeController = TextEditingController();
    final _nicknameController = TextEditingController();
    
    // 既存のニックネームを取得
    _authRepository.getUserProfile().then((profile) {
      if (profile != null && _nicknameController.text.isEmpty && profile.displayName != 'ゲストユーザー') {
        if (mounted) {
          setState(() {
            _nicknameController.text = profile.displayName;
          });
        }
      }
    });
    
    // スキャフォールドキーを保存（BuildContextを保持するため）
    final scaffoldContext = ScaffoldMessenger.of(context);
    final currentContext = context; // 現在のコンテキストを保存
    
    showDialog(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            title: const Text('グループに参加'),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // ニックネーム入力（匿名ユーザーかどうかに関わらず表示）
                  Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.only(bottom: 16),
                    decoration: BoxDecoration(
                      color: Colors.blue.shade50,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: const Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.blue),
                        SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            'このグループであなたが表示されるニックネームを入力してください。',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(
                      labelText: 'あなたのニックネーム',
                      hintText: '例: たろう',
                    ),
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 16),
                  const Text('招待コードを入力してください'),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _inviteCodeController,
                    decoration: const InputDecoration(
                      labelText: '招待コード',
                      hintText: '例: ABC123',
                    ),
                    textCapitalization: TextCapitalization.characters,
                  ),
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.pop(dialogContext);
                },
                child: const Text('キャンセル'),
              ),
              ElevatedButton(
                onPressed: () async {
                  final code = _inviteCodeController.text.trim().toUpperCase();
                  if (code.isEmpty) {
                    return;
                  }
                  
                  // ニックネームのバリデーション
                  if (_nicknameController.text.trim().isEmpty) {
                    ScaffoldMessenger.of(dialogContext).showSnackBar(
                      const SnackBar(content: Text('ニックネームを入力してください')),
                    );
                    return;
                  }
                  
                  Navigator.pop(dialogContext);
                  
                  try {
                    // ニックネームを更新（匿名ユーザー・登録ユーザー問わず）
                    final user = _authRepository.currentUser;
                    if (user != null && _nicknameController.text.trim().isNotEmpty) {
                      await _authRepository.updateUserProfile(
                        userId: user.id,
                        displayName: _nicknameController.text.trim(),
                      );
                    }
                    
                    // グループに参加
                    await _groupRepository.joinGroupByInviteCode(code);
                    
                    // 成功メッセージを表示（安全なスナックバー表示を使用）
                    if (currentContext.mounted) {
                      SnackbarUtils.showSuccessSnackBar(
                        currentContext, 
                        'グループに参加しました！'
                      );
                    }
                    
                    // グループ一覧を再読み込み
                    _loadGroups();
                  } catch (e) {
                    if (currentContext.mounted) {
                      SnackbarUtils.showErrorSnackBar(
                        currentContext,
                        '参加に失敗しました: ${e.toString()}'
                      );
                    }
                  }
                },
                child: const Text('参加'),
              ),
            ],
          );
        }
      ),
    );
  }
}
