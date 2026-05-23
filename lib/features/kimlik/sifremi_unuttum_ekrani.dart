// ---------------------------------------------------------------------------
// ŞİFREMİ UNUTTUM EKRANI
// ---------------------------------------------------------------------------
// Kullanıcı, hesabına bağlı e-posta adresini girer; sunucu bu adrese parola
// sıfırlama bağlantısı gönderir. Güvenlik gereği, e-posta sistemde kayıtlı
// olsa da olmasa da aynı başarı mesajı gösterilir (hesap var/yok bilgisi
// sızdırılmaz).
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../shared/hata_yardimcilari.dart';
import '../../shared/oturum_denetleyici.dart';

/// Parola sıfırlama bağlantısının talep edildiği ekran.
class SifremiUnuttumEkrani extends ConsumerStatefulWidget {
  const SifremiUnuttumEkrani({super.key});

  @override
  ConsumerState<SifremiUnuttumEkrani> createState() =>
      _SifremiUnuttumEkraniDurumu();
}

class _SifremiUnuttumEkraniDurumu extends ConsumerState<SifremiUnuttumEkrani> {
  /// Form doğrulamasını yönetmek için kullanılan anahtar.
  final _formKey = GlobalKey<FormState>();

  /// E-posta giriş alanının denetleyicisi.
  final _emailController = TextEditingController();

  /// Sıfırlama isteği sürüyor mu?
  bool _isLoading = false;

  /// Ekranda gösterilecek hata mesajı (yoksa `null`).
  String? _hata;

  /// İstek başarıyla gönderildi mi? `true` ise başarı görünümü gösterilir.
  bool _success = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  /// E-posta adresini doğrulayıp parola sıfırlama isteğini sunucuya gönderir.
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
      _hata = null;
    });

    try {
      final kimlikServisi = ref.read(kimlikServisiProvider);
      await kimlikServisi.sifreSifirlamaIste(_emailController.text.trim());
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

  /// İstek gönderildikten sonra gösterilen başarı görünümünü oluşturur.
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

  /// E-posta giriş formunu oluşturur.
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
