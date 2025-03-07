import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/themes/app_colors.dart';
import '../../../../data/repositories/group_repository.dart';
import '../../../../data/repositories/auth_repository.dart';

class CreateGroupScreen extends StatefulWidget {
  const CreateGroupScreen({Key? key}) : super(key: key);

  @override
  State<CreateGroupScreen> createState() => _CreateGroupScreenState();
}

class _CreateGroupScreenState extends State<CreateGroupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nameController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _chipUnitController = TextEditingController(text: '1');
  final _nicknameController = TextEditingController(); // ニックネーム入力用
  
  final _groupRepository = GroupRepository();
  final _authRepository = AuthRepository();
  
  bool _isCreating = false;
  String? _errorMessage;
  bool _isAnonymous = true;
  
  @override
  void initState() {
    super.initState();
    _checkUserStatus();
  }
  
  Future<void> _checkUserStatus() async {
    try {
      final isAnon = await _authRepository.isAnonymousUser();
      if (mounted) {
        setState(() {
          _isAnonymous = isAnon;
        });
      }
      
      // 既存のニックネームを取得（匿名ユーザーでも）
      final profile = await _authRepository.getUserProfile();
      if (profile != null && mounted) {
        // 「ゲストユーザー」という名前でない場合のみ設定
        if (profile.displayName != 'ゲストユーザー') {
          setState(() {
            _nicknameController.text = profile.displayName;
          });
        }
      }
    } catch (e) {
      // エラーが発生しても続行（デフォルトで匿名ユーザーとして扱う）
      print('ユーザーステータス確認エラー: $e');
    }
  }
  
  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    _chipUnitController.dispose();
    _nicknameController.dispose();
    super.dispose();
  }
  
  Future<void> _createGroup() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    
    setState(() {
      _isCreating = true;
      _errorMessage = null;
    });
    
    try {
      // ニックネームを設定（匿名ユーザー・登録ユーザー問わず）
      if (_nicknameController.text.trim().isNotEmpty) {
        final user = _authRepository.currentUser;
        if (user != null) {
          await _authRepository.updateUserProfile(
            userId: user.id,
            displayName: _nicknameController.text.trim(),
          );
        }
      }
      
      final groupId = await _groupRepository.createGroup(
        name: _nameController.text.trim(),
        description: _descriptionController.text.trim(),
        chipUnit: _chipUnitController.text.trim().isEmpty 
            ? '1' : _chipUnitController.text.trim(),
      );
      
      if (!mounted) return;
      
      // 成功メッセージを表示
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('グループを作成しました！')),
      );
      
      // グループ一覧画面に戻る
      context.pop();
      
      // 作成したグループの詳細画面に遷移
      context.push('/groups/$groupId');
      
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
      });
    } finally {
      if (mounted) {
        setState(() {
          _isCreating = false;
        });
      }
    }
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('グループを作成'),
      ),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // エラーメッセージ（あれば表示）
              if (_errorMessage != null)
                Container(
                  padding: const EdgeInsets.all(8),
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: Colors.red.shade100,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.error_outline, color: Colors.red),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _errorMessage!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    ],
                  ),
                ),
              
              // ニックネーム入力フィールド（すべてのユーザーに表示）
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
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
                            'このグループであなたが表示されるニックネームを設定してください。',
                            style: TextStyle(color: Colors.blue),
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextFormField(
                    controller: _nicknameController,
                    decoration: const InputDecoration(
                      labelText: 'あなたのニックネーム',
                      hintText: '例: たろう',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.trim().isEmpty) {
                        return 'ニックネームを入力してください';
                      }
                      if (value.length > 30) {
                        return 'ニックネームは30文字以内で入力してください';
                      }
                      return null;
                    },
                    textInputAction: TextInputAction.next,
                  ),
                  const SizedBox(height: 24),
                ],
              ),
              
              // グループ名
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(
                  labelText: 'グループ名 *',
                  hintText: '例: ポーカーチーム',
                  border: OutlineInputBorder(),
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'グループ名は必須です';
                  }
                  if (value.length > 50) {
                    return 'グループ名は50文字以内で入力してください';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              
              // 説明
              TextFormField(
                controller: _descriptionController,
                decoration: const InputDecoration(
                  labelText: '説明',
                  hintText: '例: 毎週金曜日に集まるポーカーグループ',
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
                validator: (value) {
                  if (value != null && value.length > 200) {
                    return '説明は200文字以内で入力してください';
                  }
                  return null;
                },
                textInputAction: TextInputAction.next,
              ),
              const SizedBox(height: 16),
              
              // チップ単位
              TextFormField(
                controller: _chipUnitController,
                decoration: const InputDecoration(
                  labelText: 'チップの基本単位',
                  hintText: '例: 1, 5, 10, 100 など',
                  helperText: 'チップの基本単位を設定します。空欄の場合は1が設定されます。',
                  border: OutlineInputBorder(),
                ),
                keyboardType: TextInputType.number,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                ],
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return null; // 空欄の場合はデフォルト値（1）が使用される
                  }
                  int? number = int.tryParse(value);
                  if (number == null || number <= 0) {
                    return '正の整数を入力してください';
                  }
                  if (number > 10000) {
                    return '10000以下の値を入力してください';
                  }
                  return null;
                },
              ),
              
              const SizedBox(height: 32),
              
              // 作成ボタン
              ElevatedButton(
                onPressed: _isCreating ? null : _createGroup,
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isCreating
                    ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('グループを作成'),
              ),
              
              const SizedBox(height: 16),
              
              // 戻るボタン
              OutlinedButton(
                onPressed: () => Navigator.pop(context),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: const Text('キャンセル'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
