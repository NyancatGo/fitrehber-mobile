import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/hata_yardimcilari.dart';
import '../../shared/session_controller.dart';

class ForgotPasswordScreen extends ConsumerStatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  ConsumerState<ForgotPasswordScreen> createState() =>
      _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends ConsumerState<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  bool _isLoading = false;
  String? _hata;
  bool _success = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _hata = null;
    });

    try {
      final authService = ref.read(authServiceProvider);
      await authService.passwordResetRequest(_emailController.text.trim());
      if (mounted) {
        setState(() {
          _success = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _hata = kullaniciDostuHata(e);
        });
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Şifremi Unuttum'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.pop(),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _success ? _buildSuccessView() : _buildFormView(),
        ),
      ),
    );
  }

  Widget _buildSuccessView() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.check_circle_outline, size: 80, color: Colors.green),
        const SizedBox(height: 24),
        const Text(
          'Bağlantı Gönderildi',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
        ),
        const SizedBox(height: 16),
        const Text(
          'Eğer girdiğiniz e-posta adresi sistemimizde kayıtlıysa, şifre sıfırlama bağlantısı gönderildi. Lütfen e-posta kutunuzu kontrol edin.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 16, color: Colors.grey, height: 1.5),
        ),
        const SizedBox(height: 48),
        ElevatedButton(
          onPressed: () => context.go('/giris'),
          style: ElevatedButton.styleFrom(
            backgroundColor: const Color(0xFFF5A623),
            padding: const EdgeInsets.symmetric(vertical: 16),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
          child: const Text(
            'Giriş Ekranına Dön',
            style: TextStyle(fontSize: 16, color: Colors.white),
          ),
        ),
      ],
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 20),
          const Icon(Icons.lock_reset, size: 64, color: Color(0xFFF5A623)),
          const SizedBox(height: 24),
          const Text(
            'Şifreni mi unuttun?',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          const Text(
            'Hesabına bağlı e-posta adresini gir. Sana şifreni sıfırlayabileceğin bir bağlantı göndereceğiz.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey, fontSize: 16, height: 1.5),
          ),
          const SizedBox(height: 32),
          if (_hata != null)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.red.withValues(alpha: 0.3)),
              ),
              child: Text(_hata!, style: const TextStyle(color: Colors.red)),
            ),
          TextFormField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: 'E-posta Adresi',
              prefixIcon: Icon(Icons.email_outlined),
              border: OutlineInputBorder(),
            ),
            validator: (v) {
              if (v == null || v.isEmpty) return 'E-posta gerekli';
              if (!v.contains('@')) return 'Geçerli bir e-posta girin';
              return null;
            },
          ),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: _isLoading ? null : _submit,
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFF5A623),
              padding: const EdgeInsets.symmetric(vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(8),
              ),
            ),
            child: _isLoading
                ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Text(
                    'Sıfırlama Bağlantısı Gönder',
                    style: TextStyle(fontSize: 16, color: Colors.white),
                  ),
          ),
        ],
      ),
    );
  }
}
