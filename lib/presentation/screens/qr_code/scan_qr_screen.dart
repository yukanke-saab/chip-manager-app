import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../../../core/themes/app_colors.dart';
import '../../../data/repositories/group_repository.dart';

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
  final MobileScannerController _scannerController = MobileScannerController();
  final _groupRepository = GroupRepository();
  
  bool _isScanning = true;
  bool _torchEnabled = false;
  bool _isProcessing = false;
  String? _errorMessage;
  
  @override
  void dispose() {
    _scannerController.dispose();
    super.dispose();
  }
  
  void _onDetect(BarcodeCapture capture) async {
    // 既に処理中なら無視
    if (!_isScanning || _isProcessing) {
      return;
    }
    
    // QRコードの内容を取得
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    setState(() {
      _isProcessing = true;
    });
    
    try {
      // QRコードの内容を取得
      final String qrData = barcodes.first.rawValue ?? '';
      if (qrData.isEmpty) {
        throw Exception('QRコードの読み取りに失敗しました');
      }
      
      // スキャンを一時停止
      _scannerController.stop();
      setState(() {
        _isScanning = false;
      });
      
      // QRコードのデータを解析
      await _processQRData(qrData);
    } catch (e) {
      // エラーメッセージを表示
      setState(() {
        _errorMessage = e.toString();
      });
      
      // エラーダイアログを表示
      _showErrorDialog();
    } finally {
      setState(() {
        _isProcessing = false;
      });
    }
  }
  
  Future<void> _processQRData(String qrData) async {
    try {
      // JSONをデコード
      final Map<String, dynamic> data = jsonDecode(qrData);
      
      // データの種類を確認
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
      
      // スキャンが成功したら取引画面へ遷移
      if (mounted) {
        // 取引画面へ遷移（ユーザーIDを引数として渡す）
        context.push('/groups/${widget.groupId}/transactions/add?memberId=$userId');
      }
    } catch (e) {
      print('QRコード処理エラー: $e');
      rethrow;
    }
  }
  
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
              // スキャンを再開
              _scannerController.start();
              setState(() {
                _isScanning = true;
                _errorMessage = null;
              });
            },
            child: const Text('やり直す'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              Navigator.of(context).pop(); // スキャン画面を閉じる
            },
            child: const Text('閉じる'),
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
            icon: Icon(
              _torchEnabled ? Icons.flash_on : Icons.flash_off,
            ),
            onPressed: () async {
              await _scannerController.toggleTorch();
              setState(() {
                _torchEnabled = !_torchEnabled;
              });
            },
          ),
          IconButton(
            icon: Icon(
              Platform.isIOS 
                  ? Icons.flip_camera_ios 
                  : Icons.flip_camera_android,
            ),
            onPressed: () => _scannerController.switchCamera(),
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
                  controller: _scannerController,
                  onDetect: _onDetect,
                ),
                
                // スキャン領域のオーバーレイ
                Container(
                  decoration: ShapeDecoration(
                    shape: QrScannerOverlayShape(
                      borderColor: AppColors.primary,
                      borderRadius: 10,
                      borderLength: 30,
                      borderWidth: 10,
                      cutOutSize: 250,
                    ),
                  ),
                ),
                
                // 処理中のインジケーター
                if (_isProcessing)
                  Container(
                    color: Colors.black.withOpacity(0.5),
                    child: const Center(
                      child: CircularProgressIndicator(),
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
                children: const [
                  Text(
                    'メンバーのQRコードをスキャンしてください',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    textAlign: TextAlign.center,
                  ),
                  SizedBox(height: 16),
                  Text(
                    'カメラをQRコードに向けると自動的に読み取ります。\n'
                    '読み取り後、チップの加減算画面に進みます。',
                    textAlign: TextAlign.center,
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

// スキャン領域のオーバーレイを定義するクラス
class QrScannerOverlayShape extends ShapeBorder {
  final Color borderColor;
  final double borderWidth;
  final Color overlayColor;
  final double borderRadius;
  final double borderLength;
  final double cutOutSize;

  const QrScannerOverlayShape({
    this.borderColor = Colors.red,
    this.borderWidth = 3.0,
    this.overlayColor = const Color(0x88000000),
    this.borderRadius = 10.0,
    this.borderLength = 30.0,
    this.cutOutSize = 250.0,
  });

  @override
  EdgeInsetsGeometry get dimensions => EdgeInsets.zero;

  @override
  Path getInnerPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: rect.center,
            width: cutOutSize,
            height: cutOutSize,
          ),
          Radius.circular(borderRadius),
        ),
      );
  }

  @override
  Path getOuterPath(Rect rect, {TextDirection? textDirection}) {
    return Path()
      ..fillType = PathFillType.evenOdd
      ..addRect(rect)
      ..addRRect(
        RRect.fromRectAndRadius(
          Rect.fromCenter(
            center: rect.center,
            width: cutOutSize,
            height: cutOutSize,
          ),
          Radius.circular(borderRadius),
        ),
      );
  }

  @override
  void paint(Canvas canvas, Rect rect, {TextDirection? textDirection}) {
    final Paint paint = Paint()
      ..color = overlayColor
      ..style = PaintingStyle.fill;

    final cutOutRect = Rect.fromCenter(
      center: rect.center,
      width: cutOutSize,
      height: cutOutSize,
    );

    canvas.drawPath(
      Path.combine(
        PathOperation.difference,
        Path()..addRect(rect),
        Path()
          ..addRRect(
            RRect.fromRectAndRadius(
              cutOutRect,
              Radius.circular(borderRadius),
            ),
          ),
      ),
      paint,
    );

    // Draw border
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth;

    // Top left corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left, cutOutRect.top + borderLength)
        ..lineTo(cutOutRect.left, cutOutRect.top)
        ..lineTo(cutOutRect.left + borderLength, cutOutRect.top),
      borderPaint,
    );

    // Top right corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right - borderLength, cutOutRect.top)
        ..lineTo(cutOutRect.right, cutOutRect.top)
        ..lineTo(cutOutRect.right, cutOutRect.top + borderLength),
      borderPaint,
    );

    // Bottom right corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.right, cutOutRect.bottom - borderLength)
        ..lineTo(cutOutRect.right, cutOutRect.bottom)
        ..lineTo(cutOutRect.right - borderLength, cutOutRect.bottom),
      borderPaint,
    );

    // Bottom left corner
    canvas.drawPath(
      Path()
        ..moveTo(cutOutRect.left + borderLength, cutOutRect.bottom)
        ..lineTo(cutOutRect.left, cutOutRect.bottom)
        ..lineTo(cutOutRect.left, cutOutRect.bottom - borderLength),
      borderPaint,
    );
  }

  @override
  ShapeBorder scale(double t) {
    return QrScannerOverlayShape(
      borderColor: borderColor,
      borderWidth: borderWidth * t,
      overlayColor: overlayColor,
      borderRadius: borderRadius * t,
      borderLength: borderLength * t,
      cutOutSize: cutOutSize * t,
    );
  }
}
