// ---------------------------------------------------------------------------
// KAYIT (HESAP OLUŞTURMA) EKRANI
// ---------------------------------------------------------------------------
// Yeni kullanıcının hesap oluşturduğu ekran. Kullanıcı adı, e-posta, parola ve
// parola tekrarı alınır. Tüm alanlar `validator` ile doğrulanır:
//   * E-posta biçim kontrolü,
//   * Parola en az 8 karakter (sunucu kuralıyla uyumlu),
//   * İki parolanın birebir eşleşmesi.
// Kayıt başarılı olunca kullanıcı e-posta doğrulama ekranına yönlendirilir.
// ---------------------------------------------------------------------------

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/uygulama_temasi.dart';
import '../../shared/hata_yardimcilari.dart';
import 'kimlik_markasi.dart';
import '../../shared/oturum_denetleyici.dart';
import '../../shared/widgets/oturum_yukleme.dart';

/// Yeni kullanıcı kaydının yapıldığı ekran.
class KayitEkrani extends ConsumerStatefulWidget {
  const KayitEkrani({super.key});

  @override
  ConsumerState<KayitEkrani> createState() => _KayitEkraniDurumu();
}

class _KayitEkraniDurumu extends ConsumerState<KayitEkrani> {
  /// Form doğrulamasını yönetmek için kullanılan anahtar.
  final _formKey = GlobalKey<FormState>();

  /// Kullanıcı adı giriş alanının denetleyicisi.
  final _usernameController = TextEditingController();

  /// E-posta giriş alanının denetleyicisi.
  final _emailController = TextEditingController();

  /// Parola giriş alanının denetleyicisi.
  final _passwordController = TextEditingController();

  /// Parola tekrarı giriş alanının denetleyicisi.
  final _passwordConfirmController = TextEditingController();

  /// Kayıt isteği sürüyor mu?
  bool _isLoading = false;

  /// Parola alanı maskeli (gizli) mi gösteriliyor?
  bool _sifreGizli = true;

  /// Parola tekrarı alanı maskeli (gizli) mi gösteriliyor?
  bool _sifreTekrarGizli = true;

  /// Ekranda gösterilecek hata mesajı (yoksa `null`).
  String? _hata;

  @override
  void dispose() {
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _passwordConfirmController.dispose();
    super.dispose();
  }

  /// Form bilgilerini doğrulayıp yeni hesap oluşturur.
  ///
  /// Başarılı olursa kullanıcı, e-postasını doğrulaması için doğrulama
  /// ekranına yönlendirilir.
  Future<void> _kayitOl() async {
    // Form alanları geçerli değilse kayıt isteğini hiç göndermeyelim.
    if (!_formKey.currentState!.validate()) return;

    final email = _emailController.text.trim();

    setState(() {
      _isLoading = true;
      _hata = null;
    });
    try {
      await ref
          .read(oturumDenetleyiciProvider.notifier)
          .kayitOl(
            _usernameController.text.trim(),
            _passwordController.text,
            email,
            _passwordConfirmController.text,
          );

      if (mounted) {
        context.go('/email-dogrulama?email=${Uri.encodeComponent(email)}');
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
      body: Stack(
        children: [
          SafeArea(
            child: Center(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 32,
                ),
                child: Form(
                  key: _formKey,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 400),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 8),
                        const KimlikMarkasi(),
                        const SizedBox(height: 16),
                        Text(
                          'FitRehber',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineMedium,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Yeni hesap oluştur',
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        if (_hata != null)
                          Container(
                            padding: const EdgeInsets.all(14),
                            margin: const EdgeInsets.only(bottom: 16),
                            decoration: BoxDecoration(
                              color: UygulamaTemasi.hata.withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: UygulamaTemasi.hata.withValues(
                                  alpha: 0.35,
                                ),
                              ),
                            ),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.error_outline_rounded,
                                  color: UygulamaTemasi.hata,
                                  size: 20,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Text(
                                    _hata!,
                                    style: const TextStyle(
                                      color: UygulamaTemasi.hata,
                                      fontSize: 13.5,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        TextFormField(
                          controller: _usernameController,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'Kullanıcı Adı',
                            prefixIcon: Icon(Icons.person_outline),
                          ),
                          validator: (v) => v == null || v.isEmpty
                              ? 'Kullanıcı adı gerekli'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          textInputAction: TextInputAction.next,
                          decoration: const InputDecoration(
                            labelText: 'E-posta',
                            prefixIcon: Icon(Icons.email_outlined),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'E-posta gerekli';
                            }
                            if (!v.contains('@')) {
                              return 'Geçerli bir e-posta girin';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordController,
                          obscureText: _sifreGizli,
                          textInputAction: TextInputAction.next,
                          decoration: InputDecoration(
                            labelText: 'Şifre',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _sifreGizli
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () =>
                                  setState(() => _sifreGizli = !_sifreGizli),
                            ),
                          ),
                          // WEB tarafindaki Django MinimumLengthValidator 8
                          // karakter zorunlu kilar; istemci dogrulamasi da ayni
                          // esikte olmali — aksi halde sunucu reddedince UX bozulur.
                          validator: (v) => v == null || v.length < 8
                              ? 'Şifre en az 8 karakter olmalı'
                              : null,
                        ),
                        const SizedBox(height: 16),
                        TextFormField(
                          controller: _passwordConfirmController,
                          obscureText: _sifreTekrarGizli,
                          textInputAction: TextInputAction.done,
                          onFieldSubmitted: (_) {
                            if (!_isLoading) _kayitOl();
                          },
                          decoration: InputDecoration(
                            labelText: 'Şifre Tekrar',
                            prefixIcon: const Icon(Icons.lock_outline),
                            suffixIcon: IconButton(
                              icon: Icon(
                                _sifreTekrarGizli
                                    ? Icons.visibility
                                    : Icons.visibility_off,
                              ),
                              onPressed: () => setState(
                                () => _sifreTekrarGizli = !_sifreTekrarGizli,
                              ),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) {
                              return 'Şifreni tekrar gir';
                            }
                            if (v != _passwordController.text) {
                              return 'Şifreler eşleşmiyor';
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 24),
                        FilledButton(
                          onPressed: _isLoading ? null : _kayitOl,
                          child: _isLoading
                              ? const SizedBox(
                                  width: 22,
                                  height: 22,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                    color: UygulamaTemasi.anaUstune,
                                  ),
                                )
                              : const Text('Kayıt ol'),
                        ),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              'Zaten hesabın var mı?',
                              style: TextStyle(
                                color: UygulamaTemasi.ikincilMetin,
                              ),
                            ),
                            TextButton(
                              onPressed: () => context.go('/giris'),
                              child: const Text('Giriş yap'),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (_isLoading)
            const OturumYuklemeKatmani(
              title: 'Hesabın oluşturuluyor',
              subtitle: 'FitRehber profilin hazırlanıyor',
            ),
        ],
      ),
    );
  }
}
