import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/themes/app_colors.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../core/utils/ui_utils/snackbar_utils.dart';

class ScanQRScreen extends StatefulWidget {
  final String groupId;

  const ScanQRScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> {
  // スキャナーコントローラー
  late MobileScannerController _controller;
  // ローディング状態
  bool _isProcessing = false;
  // フラッシュライト状態
  bool _isTorchOn = false;
  // 手動入力コントローラー
  final TextEditingController _manualCodeController = TextEditingController();
  // グループリポジトリ
  final _groupRepository = GroupRepository();
  // エラーメッセージ
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // カメラコントローラーを初期化
    _controller = MobileScannerController(
      detectionSpeed: DetectionSpeed.normal,
      facing: CameraFacing.back,
      torchEnabled: false,
      formats: [BarcodeFormat.qrCode],
      // 初期化エラーは後で処理
    );
    
    // カメラを起動
    _startScanning();
  }

  void _startScanning() async {
    try {
      setState(() {
        _errorMessage = null;
      });
      await _controller.start();
    } catch (e) {
      setState(() {
        _errorMessage = 'カメラの起動に失敗しました: $e';
      });
      print('カメラエラー: $e');
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _manualCodeController.dispose();
    super.dispose();
  }

  // QRコードが検出された時の処理
  void _onDetect(BarcodeCapture capture) async {
    // 既に処理中なら無視
    if (_isProcessing) return;

    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    print('QRコード検出: ${barcodes.first.rawValue}');
    
    // 処理を開始
    setState(() {
      _isProcessing = true;
    });
    
    try {
      final String qrData = barcodes.first.rawValue ?? '';
      if (qrData.isEmpty) {
        throw Exception('QRコードを読み取れませんでした');
      }
      
      await _processQRData(qrData);
    } catch (e) {
      print('QRコード処理エラー: $e');
      setState(() {
        _errorMessage = e.toString();
      });
      
      if (mounted) {
        _showErrorDialog();
      }
    } finally {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    }
  }
  
  // QRコードデータの処理
  Future<void> _processQRData(String qrData) async {
    try {
      final Map<String, dynamic> data = jsonDecode(qrData);
      
      // データ検証
      final String type = data['type'] as String? ?? '';
      if (type != 'chip_transaction') {
        throw Exception('無効なQRコードです: 取引用QRコードではありません');
      }
      
      // グループIDを確認
      final String groupId = data['group_id'] as String? ?? '';
      if (groupId != widget.groupId) {
        throw Exception('このQRコードは別のグループのものです');
      }
      
      // 有効期限を確認
      final int expiryTimestamp = data['expiry'] as int? ?? 0;
      final DateTime expiry = DateTime.fromMillisecondsSinceEpoch(expiryTimestamp);
      if (expiry.isBefore(DateTime.now())) {
        throw Exception('このQRコードは期限切れです');
      }
      
      // ユーザーIDを取得
      final String userId = data['user_id'] as String? ?? '';
      if (userId.isEmpty) {
        throw Exception('ユーザー情報が見つかりません');
      }
      
      // 取引画面へ遷移
      if (mounted) {
        context.push('/groups/${widget.groupId}/transactions/add?memberId=$userId');
      }
    } catch (e) {
      print('QRコード処理エラー: $e');
      rethrow;
    }
  }
  
  // エラーダイアログの表示
  void _showErrorDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QRコードの読み取りエラー'),
        content: Text(_errorMessage ?? '無効なQRコードです'),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _startScanning();
            },
            child: const Text('やり直す'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop();
            },
            child: const Text('閉じる'),
          ),
        ],
      ),
    );
  }
  
  // 手動入力ダイアログの表示
  void _showManualEntryDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('QRコードを手動入力'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('カメラが使用できない場合は、メンバーがQRコードを生成画面で表示しているデータを入力してください。'),
            const SizedBox(height: 4),
            const Text('チップ取引を安全に行うため、有効なQRコードデータが必要です。',
              style: TextStyle(fontWeight: FontWeight.bold, color: Colors.red)),
            const SizedBox(height: 16),
            TextField(
              controller: _manualCodeController,
              decoration: const InputDecoration(
                labelText: 'QRコードテキスト',
                border: OutlineInputBorder(),
                hintText: '{"type":"chip_transaction","group_id":"xxx",...}',
              ),
              maxLines: 5,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(context).pop();
              if (_manualCodeController.text.isNotEmpty) {
                try {
                  _processQRData(_manualCodeController.text);
                } catch (e) {
                  if (mounted) {
                    SnackbarUtils.showErrorSnackBar(
                      context, 
                      '無効なQRコードデータです: ${e.toString()}'
                    );
                  }
                }
              }
            },
            child: const Text('確認'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('QRコードをスキャン'),
        actions: [
          IconButton(
            icon: const Icon(Icons.keyboard),
            onPressed: _showManualEntryDialog,
            tooltip: '手動入力',
          ),
          IconButton(
            icon: Icon(_isTorchOn ? Icons.flash_on : Icons.flash_off),
            onPressed: () {
              _controller.toggleTorch();
              setState(() {
                _isTorchOn = !_isTorchOn;
              });
            },
          ),
          IconButton(
            icon: Icon(Platform.isIOS ? Icons.flip_camera_ios : Icons.flip_camera_android),
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            flex: 5,
            child: Stack(
              children: [
                // スキャナービュー
                MobileScanner(
                  controller: _controller,
                  onDetect: _onDetect,
                  errorBuilder: (context, error, child) {
                    print('スキャナーエラー: $error');
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.error, color: Colors.red, size: 48),
                          const SizedBox(height: 12),
                          Text('カメラエラー: ${error.toString()}'),
                          const SizedBox(height: 16),
                          ElevatedButton(
                            onPressed: _startScanning,
                            child: const Text('カメラを再試行'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                
                // スキャン枠オーバーレイ
                Center(
                  child: Container(
                    width: 250,
                    height: 250,
                    decoration: BoxDecoration(
                      border: Border.all(
                        color: AppColors.primary,
                        width: 3.0,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                
                // スキャンガイド (角のマーク)
                Center(
                  child: SizedBox(
                    width: 250,
                    height: 250,
                    child: CustomPaint(
                      painter: CornersPainter(color: AppColors.primary),
                    ),
                  ),
                ),
                
                // 処理中インジケーター
                if (_isProcessing)
                  Container(
                    color: Colors.black54,
                    child: const Center(
                      child: CircularProgressIndicator(),
                    ),
                  ),
                
                // エラー表示
                if (_errorMessage != null)
                  Container(
                    color: Colors.black54,
                    padding: const EdgeInsets.all(16),
                    child: Center(
                      child: Card(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.error_outline, color: Colors.red, size: 48),
                              const SizedBox(height: 16),
                              Text(
                                _errorMessage!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(fontWeight: FontWeight.bold),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton(
                                onPressed: _startScanning,
                                child: const Text('再試行'),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          
          // 説明テキスト
          Expanded(
            flex: 2,
            child: Container(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'メンバーのQRコードをスキャンしてください',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'カメラをQRコードに向けると自動的に読み取ります。\n'
                    '読み取り後、チップの加減算画面に進みます。',
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 16),
                  OutlinedButton.icon(
                    onPressed: _showManualEntryDialog,
                    icon: const Icon(Icons.keyboard),
                    label: const Text('QRコードを手動入力'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// コーナーマーカーペインター (スキャン枠の四隅を描画)
class CornersPainter extends CustomPainter {
  final Color color;
  final double length;
  final double thickness;

  CornersPainter({
    required this.color,
    this.length = 24,
    this.thickness = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = thickness
      ..strokeCap = StrokeCap.square;

    const radius = 0.0;

    // 左上
    canvas.drawPath(
      Path()
        ..moveTo(0, length)
        ..lineTo(0, radius)
        ..lineTo(length, 0),
      paint,
    );

    // 右上
    canvas.drawPath(
      Path()
        ..moveTo(size.width - length, 0)
        ..lineTo(size.width - radius, 0)
        ..lineTo(size.width, length),
      paint,
    );

    // 右下
    canvas.drawPath(
      Path()
        ..moveTo(size.width, size.height - length)
        ..lineTo(size.width, size.height - radius)
        ..lineTo(size.width - length, size.height),
      paint,
    );

    // 左下
    canvas.drawPath(
      Path()
        ..moveTo(length, size.height)
        ..lineTo(radius, size.height)
        ..lineTo(0, size.height - length),
      paint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
