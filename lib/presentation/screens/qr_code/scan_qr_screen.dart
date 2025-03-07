import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:intl/intl.dart';
import '../../../core/themes/app_colors.dart';
import '../../../data/repositories/group_repository.dart';
import '../../../core/utils/ui_utils/snackbar_utils.dart';
import '../../../data/models/group_member_model.dart';

class ScanQRScreen extends StatefulWidget {
  final String groupId;

  const ScanQRScreen({
    Key? key,
    required this.groupId,
  }) : super(key: key);

  @override
  State<ScanQRScreen> createState() => _ScanQRScreenState();
}

class _ScanQRScreenState extends State<ScanQRScreen> with WidgetsBindingObserver {
  MobileScannerController? _scannerController;
  final _groupRepository = GroupRepository();
  
  bool _isScanning = true;
  bool _torchEnabled = false;
  bool _isProcessing = false;
  String? _errorMessage;
  bool _isCameraPermissionGranted = false;
  bool _isCameraInitialized = false;
  
  final TextEditingController _manualCodeController = TextEditingController();
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // iOS実機でのクラッシュを避けるためにややディレイを入れて初期化
    Future.delayed(const Duration(milliseconds: 500), () {
      _initializeScanner();
    });
  }
  
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // アプリのライフサイクルを適切に処理
    if (state == AppLifecycleState.resumed) {
      if (mounted) {
        // 安全に初期化するためのディレイ
        Future.delayed(const Duration(milliseconds: 500), () {
          _initializeScanner();
        });
      }
    } else if (state == AppLifecycleState.paused || 
               state == AppLifecycleState.inactive) {
      // カメラを停止
      _scannerController?.stop();
    } else if (state == AppLifecycleState.detached) {
      // カメラを安全に停止して破棄
      _disposeScanner();
    }
  }
  
  void _initializeScanner() {
    // 既存のコントローラが存在する場合は先に破棄
    _disposeScanner();
    
    // スキャナーを安全に初期化
    try {
      _scannerController = MobileScannerController(
        facing: CameraFacing.back,
        torchEnabled: false,
        // より激しくスキャンするように設定変更
        detectionSpeed: DetectionSpeed.normal,
        // フォーマットを明示的に指定し、QRコードを優先
        formats: const [
          BarcodeFormat.qrCode,
        ],
      );
      
      // 3.5.7ではonScannerStartedは存在しないため、別の方法でエラーをハンドリング
      try {
        _scannerController?.start();
      } catch (e) {
        if (mounted) {
          setState(() {
            _errorMessage = 'カメラの初期化に失敗しました: $e';
            _isCameraPermissionGranted = false;
            _isCameraInitialized = false;
          });
        }
        print('カメラエラー: $e');
      }
      
      if (mounted) {
        setState(() {
          _isCameraPermissionGranted = true;
          _isCameraInitialized = true;
          _isScanning = true;
          _errorMessage = null;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'カメラの初期化に失敗しました: $e';
          _isCameraPermissionGranted = false;
          _isCameraInitialized = false;
        });
      }
      print('カメラ初期化エラー: $e');
    }
  }
  
  // コントローラを安全に破棄するヘルパーメソッド
  void _disposeScanner() {
    try {
      _scannerController?.stop();
      _scannerController?.dispose();
      _scannerController = null;
    } catch (e) {
      print('スキャナー破棄エラー: $e');
    }
  }
  
  @override
  void dispose() {
    // コントローラーを安全に破棄
    WidgetsBinding.instance.removeObserver(this);
    _disposeScanner();
    _manualCodeController.dispose();
    super.dispose();
  }
  
  void _onDetect(BarcodeCapture capture) async {
    // 既に処理中なら無視
    if (!_isScanning || _isProcessing) {
      return;
    }
    
    print('バーコードが検出されました!');
    
    // QRコードの内容を取得
    final List<Barcode> barcodes = capture.barcodes;
    if (barcodes.isEmpty) return;
    
    print('バーコード内容: ${barcodes.first.rawValue}');
    
    // SIGABRTを避けるために、まずスキャンを停止してからデータ処理
    _scannerController?.stop();
    
    setState(() {
      _isProcessing = true;
      _isScanning = false;
    });
    
    try {
      // QRコードの内容を取得
      final String qrData = barcodes.first.rawValue ?? '';
      if (qrData.isEmpty) {
        throw Exception('QRコードの読み取りに失敗しました');
      }
      
      // QRコードのデータを解析
      await _processQRData(qrData);
    } catch (e) {
      print('QRコード処理エラー: $e');
      // エラーメッセージを表示
      setState(() {
        _errorMessage = e.toString();
      });
      
      // エラーダイアログを表示
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
    if (!mounted) return;
    
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
              if (_isCameraInitialized) {
                _scannerController?.start();
                setState(() {
                  _isScanning = true;
                  _errorMessage = null;
                });
              } else {
                _initializeScanner();
              }
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
  
  // 手動でQRコードを入力するダイアログを表示
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
          // 手動入力ボタン - 最初に配置してアクセシビリティを高める
          IconButton(
            icon: const Icon(Icons.keyboard),
            onPressed: _showManualEntryDialog,
            tooltip: '手動入力',
          ),
          // カメラ関連のアクション
          if (_isCameraPermissionGranted && _isCameraInitialized)
            IconButton(
              icon: Icon(
                _torchEnabled ? Icons.flash_on : Icons.flash_off,
              ),
              onPressed: () async {
                try {
                  await _scannerController?.toggleTorch();
                  setState(() {
                    _torchEnabled = !_torchEnabled;
                  });
                } catch (e) {
                  print('ライト切替エラー: $e');
                }
              },
            ),
          if (_isCameraPermissionGranted && _isCameraInitialized)
            IconButton(
              icon: Icon(
                Platform.isIOS 
                    ? Icons.flip_camera_ios 
                    : Icons.flip_camera_android,
              ),
              onPressed: () {
                try {
                  _scannerController?.switchCamera();
                } catch (e) {
                  print('カメラ切替エラー: $e');
                }
              },
            ),
        ],
      ),
      body: _buildBody(),
    );
  }
  
  Widget _buildBody() {
    // カメラ使用不可の場合 - 手動入力モードを強調表示
    if (!_isCameraPermissionGranted || !_isCameraInitialized || _errorMessage != null) {
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
              'カメラにアクセスできません',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                _errorMessage ?? 'カメラへのアクセス権限がないか、デバイスのカメラを利用できません。\nQRコードを手動入力して続行できます。',
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 24),
            // 手動入力ボタンを強調表示
            ElevatedButton.icon(
              onPressed: _showManualEntryDialog,
              icon: const Icon(Icons.keyboard),
              label: const Text('QRコードを手動入力'),
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              ),
            ),
            const SizedBox(height: 16),
            // カメラを再試行するボタン
            OutlinedButton.icon(
              onPressed: _initializeScanner,
              icon: const Icon(Icons.refresh),
              label: const Text('カメラを再試行'),
            ),
          ],
        ),
      );
    }

    return Column(
      children: [
        Expanded(
          flex: 5,
          child: Stack(
            children: [
              // スキャナービュー
              _scannerController != null ? MobileScanner(
                controller: _scannerController!,
                onDetect: _onDetect,
                // スキャンウィンドウを少し大きくする
                scanWindow: Rect.fromCenter(
                  center: Offset(
                    MediaQuery.of(context).size.width / 2,
                    MediaQuery.of(context).size.height / 2,
                  ),
                  width: 300,  // 幅を広げる
                  height: 300, // 高さを広げる
                ),
                // カメラが見えるように透過度を調整
                overlayBuilder: (p0, p1) => Container(),
                errorBuilder: (context, error, child) {
                  print('カメラエラー発生: $error');
                  return Center(
                    child: Text('カメラエラー: ${error.toString()}'),
                  );
                },
              ) : const Center(
                child: Text('カメラを初期化中...'),
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
