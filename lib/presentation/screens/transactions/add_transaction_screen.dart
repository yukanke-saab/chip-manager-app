import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../../core/themes/app_colors.dart';
import '../../../data/models/group_model.dart';
import '../../../data/repositories/group_repository.dart';

class AddTransactionScreen extends StatefulWidget {
  final String groupId;
  final String? memberId; // QRコードから取得したメンバーIDを受け取るオプションパラメータ

  const AddTransactionScreen({
    Key? key,
    required this.groupId,
    this.memberId,
  }) : super(key: key);

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();
  
  final _groupRepository = GroupRepository();
  
  GroupModel? _group;
  List<dynamic> _members = [];
  String? _selectedMemberId;
  bool _isAdding = true; // true: 追加、false: 減算
  bool _isLoading = true;
  bool _isSubmitting = false;
  String? _errorMessage;
  bool _isQrScanned = false; // QRコードによるメンバー選択かどうか

  @override
  void initState() {
    super.initState();
    _loadGroupData();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _loadGroupData() async {
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
      
      setState(() {
        _group = group;
        _members = members;
        _isLoading = false;
      });
      
      // QRコードからメンバーIDが指定されている場合はそのメンバーを選択
      if (widget.memberId != null) {
        bool foundMember = false;
        for (var member in members) {
          if (member.userId == widget.memberId) {
            setState(() {
              _selectedMemberId = widget.memberId;
              _isQrScanned = true;
            });
            foundMember = true;
            break;
          }
        }
        
        if (!foundMember && members.isNotEmpty) {
          // 指定されたメンバーIDが見つからない場合は最初のメンバーを選択
          setState(() {
            _selectedMemberId = members[0].userId;
          });
        }
      } else if (members.isNotEmpty) {
        // メンバーIDが指定されていない場合は最初のメンバーを選択
        setState(() {
          _selectedMemberId = members[0].userId;
        });
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }

  Future<void> _submitTransaction() async {
    if (!_formKey.currentState!.validate() || _selectedMemberId == null) {
      return;
    }

    try {
      setState(() {
        _isSubmitting = true;
        _errorMessage = null;
      });

      // 金額を取得（減算の場合はマイナスをつける）
      double amount = double.parse(_amountController.text);
      if (!_isAdding) {
        amount = -amount;
      }

      // 取引を追加
      await _groupRepository.addChipTransaction(
        groupId: widget.groupId,
        userId: _selectedMemberId!,
        amount: amount,
        note: _noteController.text.trim(),
      );

      if (mounted) {
        // 成功メッセージを表示
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('チップ取引を記録しました')),
        );

        // 前の画面に戻る
        Navigator.pop(context, true); // 更新があったことを伝える
      }
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isSubmitting = false;
      });
    } finally {
      if (mounted && _isSubmitting) {
        setState(() {
          _isSubmitting = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('チップ取引'),
        actions: [
          // QRコードスキャンボタン
          if (!_isQrScanned)
            IconButton(
              icon: const Icon(Icons.qr_code_scanner),
              onPressed: () {
                context.push('/groups/${widget.groupId}/scan-qr');
              },
              tooltip: 'QRコードをスキャン',
            ),
        ],
      ),
      body: _buildBody(),
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
            const Icon(
              Icons.error_outline,
              size: 48.0,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            Text(
              'エラーが発生しました',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(_errorMessage!),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadGroupData,
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16.0),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // グループ情報
            Text(
              '${_group!.name}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text(
              '基本単位: ${_group!.chipUnit} (数字のみ入力してください)',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.textLight,
              ),
            ),
            const SizedBox(height: 24),
            
            // QRコードによるメンバー選択時の表示
            if (_isQrScanned && _selectedMemberId != null)
              _buildSelectedMemberCard(),
            
            // 通常のメンバー選択
            if (!_isQrScanned)
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'メンバーを選択',
                    style: TextStyle(
                      fontWeight: FontWeight.bold,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  _buildMemberSelector(),
                  const SizedBox(height: 24),
                ],
              ),
            
            // 加算/減算の切り替え
            const Text(
              '操作を選択',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            _buildOperationToggle(),
            const SizedBox(height: 24),
            
            // 金額入力
            const Text(
              '金額',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _amountController,
              decoration: InputDecoration(
                hintText: 'チップ数を入力',
                suffixText: _group?.chipUnit ?? '1',
                border: const OutlineInputBorder(),
              ),
              keyboardType: TextInputType.number,
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'チップ数を入力してください';
                }
                int? chips = int.tryParse(value);
                if (chips == null || chips <= 0) {
                  return '正の整数を入力してください';
                }
                return null;
              },
            ),
            const SizedBox(height: 24),
            
            // メモ入力
            const Text(
              'メモ（任意）',
              style: TextStyle(
                fontWeight: FontWeight.bold,
                fontSize: 16,
              ),
            ),
            const SizedBox(height: 8),
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                hintText: '例: ゲーム勝利による獲得',
                border: OutlineInputBorder(),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 32),
            
            // 送信ボタン
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _isSubmitting ? null : _submitTransaction,
                style: ElevatedButton.styleFrom(
                  backgroundColor: _isAdding ? AppColors.primary : Colors.red,
                ),
                child: _isSubmitting
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        _isAdding ? 'チップを追加する' : 'チップを減らす',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // QRコードでスキャンしたメンバーの表示カード
  Widget _buildSelectedMemberCard() {
    // 型安全なメンバー検索 - firstWhereまたはnullを返す
    dynamic findMember() {
      for (var member in _members) {
        if (member.userId == _selectedMemberId) {
          return member;
        }
      }
      return null;
    }
    
    final selectedMember = findMember();
    
    if (selectedMember == null) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('選択されたメンバーが見つかりません'),
        ),
      );
    }
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'QRコードで読み取ったメンバー',
          style: TextStyle(
            fontWeight: FontWeight.bold,
            fontSize: 16,
          ),
        ),
        const SizedBox(height: 8),
        Card(
          color: AppColors.primaryLight.withOpacity(0.2),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: AppColors.primary,
                  radius: 24,
                  child: Text(
                    selectedMember.profile.displayName[0].toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        selectedMember.profile.displayName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        selectedMember.isOwner ? 'オーナー' : 'メンバー',
                        style: TextStyle(
                          color: selectedMember.isOwner ? Colors.red : Colors.blue,
                        ),
                      ),
                    ],
                  ),
                ),
                const Icon(Icons.qr_code, color: AppColors.primary),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _buildMemberSelector() {
    if (_members.isEmpty) {
      return const Card(
        child: Padding(
          padding: EdgeInsets.all(16),
          child: Text('メンバーがいません。まずメンバーを招待してください。'),
        ),
      );
    }

    // 一時的にメンバーがいない場合のダミーオーナー追加
    if (_selectedMemberId == null && _members.isNotEmpty) {
      setState(() {
        _selectedMemberId = _members[0].userId;
      });
    }

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: DropdownButtonHideUnderline(
          child: DropdownButton<String>(
            isExpanded: true,
            value: _selectedMemberId,
            hint: const Text('メンバーを選択'),
            onChanged: (String? newValue) {
              setState(() {
                _selectedMemberId = newValue;
              });
            },
            items: _members.map<DropdownMenuItem<String>>((member) {
              return DropdownMenuItem<String>(
                value: member.userId,
                child: Row(
                  children: [
                    CircleAvatar(
                      backgroundColor: AppColors.primary,
                      radius: 16,
                      child: Text(
                        member.profile.displayName[0].toUpperCase(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 14,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        member.profile.displayName,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      member.isOwner ? 'オーナー' : 'メンバー',
                      style: TextStyle(
                        fontSize: 12,
                        color: member.isOwner ? Colors.red : Colors.blue,
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildOperationToggle() {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: Row(
          children: [
            Expanded(
              child: ChoiceChip(
                label: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.add),
                    SizedBox(width: 8),
                    Text('追加'),
                  ],
                ),
                selected: _isAdding,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _isAdding = true;
                    });
                  }
                },
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: _isAdding ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: ChoiceChip(
                label: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: const [
                    Icon(Icons.remove),
                    SizedBox(width: 8),
                    Text('減算'),
                  ],
                ),
                selected: !_isAdding,
                onSelected: (selected) {
                  if (selected) {
                    setState(() {
                      _isAdding = false;
                    });
                  }
                },
                selectedColor: Colors.red,
                labelStyle: TextStyle(
                  color: !_isAdding ? Colors.white : Colors.black,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
