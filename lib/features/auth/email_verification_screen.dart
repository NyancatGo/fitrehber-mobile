import 'dart:async';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/hata_yardimcilari.dart';
import '../../shared/session_controller.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  static const _cooldownSeconds = 300;

  bool _isLoading = false;
  int _cooldown = _cooldownSeconds;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _startCooldown();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _startCooldown() {
    setState(() => _cooldown = _cooldownSeconds);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_cooldown > 0) {
        setState(() => _cooldown--);
      } else {
        timer.cancel();
      }
    });
  }

  Future<void> _resendEmail() async {
    if (_cooldown > 0) return;

    setState(() => _isLoading = true);
    try {
      final authService = ref.read(authServiceProvider);
      await authService.resendVerification(widget.email);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Doğrulama e-postası tekrar gönderildi.'),
          ),
        );
        _startCooldown();
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(kullaniciDostuHata(e)),
            backgroundColor: Colors.red,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('E-posta Doğrulama'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/giris'),
        ),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(
                Icons.mark_email_unread_outlined,
                size: 80,
                color: Color(0xFFF5A623),
              ),
              const SizedBox(height: 24),
              const Text(
                'E-postanı Doğrula',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              Text(
                'Hesabını aktifleştirmek için ${widget.email} adresine gönderdiğimiz doğrulama bağlantısına tıkla.',
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 16,
                  color: Colors.grey,
                  height: 1.5,
                ),
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
                  'Doğruladım, Giriş Yap',
                  style: TextStyle(fontSize: 16, color: Colors.white),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _cooldown > 0 || _isLoading ? null : _resendEmail,
                child: _isLoading
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : Text(
                        _cooldown > 0
                            ? 'Tekrar gönder ($_cooldown)'
                            : 'E-postayı Tekrar Gönder',
                        style: TextStyle(
                          color: _cooldown > 0
                              ? Colors.grey
                              : const Color(0xFFF5A623),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
