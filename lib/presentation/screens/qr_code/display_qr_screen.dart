import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../../core/themes/app_colors.dart';
import '../../../data/models/group_model.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../data/repositories/auth_repository.dart';

class DisplayQRScreen extends StatefulWidget {
  final String groupId;

  const DisplayQRScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  State<DisplayQRScreen> createState() => _DisplayQRScreenState();
}

class _DisplayQRScreenState extends State<DisplayQRScreen> {
  final _groupRepository = GroupRepository();
  final _authRepository = AuthRepository();
  
  bool _isLoading = true;
  GroupModel? _group;
  String? _errorMessage;
  String? _qrData;
  Timer? _qrExpiryTimer;
  int _timeRemaining = 300; // 5分 = 300秒
  
  @override
  void initState() {
    super.initState();
    _loadGroupAndGenerateQR();
  }
  
  @override
  void dispose() {
    _qrExpiryTimer?.cancel();
    super.dispose();
  }
  
  Future<void> _loadGroupAndGenerateQR() async {
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
      
      // 現在のユーザー情報を取得
      final currentUser = _authRepository.currentUser;
      if (currentUser == null) {
        throw Exception('ログインされていません');
      }
      
      // QRコードに埋め込むデータを生成
      final qrData = _generateQRData(currentUser.id, group.id);
      
      // タイマーをセットアップ
      _setupExpiryTimer();
      
      setState(() {
        _group = group;
        _qrData = qrData;
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _errorMessage = e.toString();
        _isLoading = false;
      });
    }
  }
  
  String _generateQRData(String userId, String groupId) {
    // 現在のタイムスタンプ（有効期限計算用）
    final now = DateTime.now();
    final expiry = now.add(const Duration(minutes: 5));
    
    // QRコードに埋め込むデータ
    final Map<String, dynamic> data = {
      'type': 'chip_transaction',
      'user_id': userId,
      'group_id': groupId,
      'timestamp': now.millisecondsSinceEpoch,
      'expiry': expiry.millisecondsSinceEpoch,
    };
    
    // JSONにエンコードして返す
    return jsonEncode(data);
  }
  
  void _setupExpiryTimer() {
    // 既存のタイマーをキャンセル
    _qrExpiryTimer?.cancel();
    
    // 5分の初期値
    setState(() {
      _timeRemaining = 300;
    });
    
    // 1秒ごとにカウントダウンするタイマーを設定
    _qrExpiryTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_timeRemaining > 0) {
          _timeRemaining--;
        } else {
          // タイムアウトしたらQRコードを再生成
          _qrExpiryTimer?.cancel();
          _loadGroupAndGenerateQR();
        }
      });
    });
  }
  
  // 残り時間を分:秒形式で表示
  String _formatTimeRemaining() {
    final minutes = (_timeRemaining / 60).floor();
    final seconds = _timeRemaining % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('チップ取引用QRコード'),
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
              onPressed: _loadGroupAndGenerateQR,
              child: const Text('再試行'),
            ),
          ],
        ),
      );
    }
    
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // グループ情報
          Text(
            _group!.name,
            style: Theme.of(context).textTheme.headlineSmall,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 8),
          Text(
            '基本単位: ${_group!.chipUnit}',
            style: Theme.of(context).textTheme.bodyMedium,
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // QRコード表示
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16.0),
              boxShadow: [
                BoxShadow(
                  color: Colors.grey.withOpacity(0.3),
                  spreadRadius: 1,
                  blurRadius: 4,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Column(
              children: [
                QrImageView(
                  data: _qrData!,
                  version: QrVersions.auto,
                  size: 250,
                  backgroundColor: Colors.white,
                  errorCorrectionLevel: QrErrorCorrectLevel.H,
                ),
                const SizedBox(height: 16),
                
                // 残り時間表示
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(
                      Icons.timer,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      '有効期限: ${_formatTimeRemaining()}',
                      style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          
          const SizedBox(height: 40),
          
          // 説明テキスト
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  Text(
                    '使い方',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  SizedBox(height: 8),
                  Text(
                    '1. このQRコードをオーナーに見せてください\n'
                    '2. オーナーがQRコードをスキャンします\n'
                    '3. オーナーがチップの加減算を行います\n\n'
                    '※ QRコードは5分間有効です。期限が切れると自動で更新されます。'
                  ),
                ],
              ),
            ),
          ),
          
          const SizedBox(height: 24),
          
          // 再生成ボタン
          ElevatedButton.icon(
            onPressed: _loadGroupAndGenerateQR,
            icon: const Icon(Icons.refresh),
            label: const Text('QRコードを再生成'),
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
            ),
          ),
        ],
      ),
    );
  }
}
