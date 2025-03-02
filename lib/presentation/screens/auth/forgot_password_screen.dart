import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../../data/repositories/auth_repository.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({Key? key}) : super(key: key);

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _authRepository = AuthRepository();
  
  bool _isLoading = false;
  bool _emailSent = false;
  String? _errorMessage;
  
  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }
  
  Future<void> _sendPasswordResetEmail() async {
    if (!_formKey.currentState!.validate()) return;
    
    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });
    
    try {
      await _authRepository.sendPasswordResetEmail(_emailController.text.trim());
      
      if (!mounted) return;
      
      setState(() {
        _isLoading = false;
        _emailSent = true;
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
        title: const Text('パスワードリセット'),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: _emailSent ? _buildSuccessView() : _buildFormView(),
          ),
        ),
      ),
    );
  }
  
  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'パスワードをリセット',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),
          
          const Text(
            'アカウントに登録したメールアドレスを入力してください。パスワードリセットのリンクをお送りします。',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          
          // エラーメッセージ
          if (_errorMessage != null)
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.shade50,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                _errorMessage!,
                style: TextStyle(color: Colors.red.shade700),
              ),
            ),
          if (_errorMessage != null)
            const SizedBox(height: 16),
          
          // メールアドレス
          TextFormField(
            controller: _emailController,
            decoration: const InputDecoration(
              labelText: 'メールアドレス',
              prefixIcon: Icon(Icons.email_outlined),
            ),
            keyboardType: TextInputType.emailAddress,
            validator: (value) {
              if (value == null || value.isEmpty) {
                return 'メールアドレスを入力してください';
              }
              // 簡易的なメールアドレスの形式チェック
              final emailRegExp = RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$');
              if (!emailRegExp.hasMatch(value)) {
                return '有効なメールアドレスを入力してください';
              }
              return null;
            },
          ),
          const SizedBox(height: 24),
          
          // 送信ボタン
          ElevatedButton(
            onPressed: _isLoading ? null : _sendPasswordResetEmail,
            style: ElevatedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text('リセットリンクを送信'),
          ),
          const SizedBox(height: 16),
          
          // ログインへのリンク
          TextButton(
            onPressed: () {
              context.go('/login');
            },
            child: const Text('ログイン画面に戻る'),
          ),
        ],
      ),
    );
  }
  
  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(
          Icons.mark_email_read,
          size: 64,
          color: Colors.green,
        ),
        const SizedBox(height: 24),
        
        const Text(
          'リセットリンクを送信しました',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 16),
        
        Text(
          '${_emailController.text}宛にパスワードリセットのリンクをお送りしました。メールをご確認ください。',
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 24),
        
        ElevatedButton(
          onPressed: () {
            context.go('/login');
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('ログイン画面に戻る'),
        ),
      ],
    );
  }
}
