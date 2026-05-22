import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../shared/google_oauth_flow.dart';
import '../../shared/hata_yardimcilari.dart';
import '../../shared/session_controller.dart';
import '../../shared/widgets/session_loading.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _appLinks = AppLinks();

  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _sifreGizli = true;
  String? _hata;

  bool get _isBusy => _isLoading || _isGoogleLoading;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _girisYap() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _isLoading = true;
      _hata = null;
    });
    try {
      await ref
          .read(sessionControllerProvider.notifier)
          .login(_usernameController.text.trim(), _passwordController.text);
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

  Future<void> _googleIleGirisYap() async {
    final oauthRequest = GoogleOAuthFlow.createRequest();

    setState(() {
      _isGoogleLoading = true;
      _hata = null;
    });

    if (kIsWeb) {
      await _googleIleGirisYapWeb(oauthRequest);
      return;
    }

    StreamSubscription<Uri>? linkSubscription;
    final callbackCompleter = Completer<GoogleOAuthCallback>();

    try {
      linkSubscription = _appLinks.uriLinkStream.listen(
        (uri) {
          if (uri.scheme != GoogleOAuthFlow.callbackScheme ||
              callbackCompleter.isCompleted) {
            return;
          }

          try {
            callbackCompleter.complete(
              GoogleOAuthFlow.parseCallback(
                uri.toString(),
                expectedState: oauthRequest.state,
              ),
            );
          } catch (error, stackTrace) {
            callbackCompleter.completeError(error, stackTrace);
          }
        },
        onError: (Object error, StackTrace stackTrace) {
          if (!callbackCompleter.isCompleted) {
            callbackCompleter.completeError(error, stackTrace);
          }
        },
      );

      final opened = await launchUrl(
        oauthRequest.authorizationUrl,
        mode: LaunchMode.externalApplication,
      );

      if (!opened) {
        throw 'Google giriş sayfası açılamadı.';
      }

      final callback = await callbackCompleter.future.timeout(
        const Duration(minutes: 5),
        onTimeout: () {
          throw const GoogleOAuthException(
            'Google giriş süresi doldu. Lütfen tekrar dene.',
          );
        },
      );

      await ref
          .read(sessionControllerProvider.notifier)
          .loginWithGoogleCode(
            code: callback.code,
            stateToken: callback.state,
            codeVerifier: oauthRequest.codeVerifier,
          );
    } catch (e) {
      if (mounted) {
        setState(() {
          _hata = kullaniciDostuHata(e);
        });
      }
    } finally {
      await linkSubscription?.cancel();
      if (mounted) {
        setState(() {
          _isGoogleLoading = false;
        });
      }
    }
  }

  /// Web'de Google girişi: deep link yerine tüm sayfa Google'a yönlendirilir.
  /// state + code_verifier kalıcı depoya yazılır; dönüşte uygulama yeniden
  /// yüklenince SessionController.restore() token exchange'i tamamlar.
  Future<void> _googleIleGirisYapWeb(GoogleOAuthRequest oauthRequest) async {
    try {
      await ref
          .read(authServiceProvider)
          .saveGooglePending(
            state: oauthRequest.state,
            codeVerifier: oauthRequest.codeVerifier,
          );
      final opened = await launchUrl(
        oauthRequest.authorizationUrl,
        webOnlyWindowName: '_self',
      );
      if (!opened) {
        throw 'Google giriş sayfası açılamadı.';
      }
      // Başarılıysa sayfa yönleniyor; burada başka işlem yapılmaz.
    } catch (e) {
      if (mounted) {
        setState(() {
          _hata = kullaniciDostuHata(e);
          _isGoogleLoading = false;
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
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: 60),
                    const Icon(
                      Icons.fitness_center,
                      size: 64,
                      color: Color(0xFFF5A623),
                    ),
                    const SizedBox(height: 16),
                    const Text(
                      'FitRehber',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Text(
                      'Hesabına giriş yap',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey, fontSize: 16),
                    ),
                    const SizedBox(height: 48),
                    if (_hata != null)
                      Container(
                        padding: const EdgeInsets.all(12),
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: Colors.red.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color: Colors.red.withValues(alpha: 0.3),
                          ),
                        ),
                        child: Text(
                          _hata!,
                          style: const TextStyle(color: Colors.red),
                        ),
                      ),
                    TextFormField(
                      controller: _usernameController,
                      decoration: const InputDecoration(
                        labelText: 'Kullanıcı Adı',
                        prefixIcon: Icon(Icons.person_outline),
                        border: OutlineInputBorder(),
                      ),
                      validator: (v) => v == null || v.isEmpty
                          ? 'Kullanıcı adı gerekli'
                          : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _sifreGizli,
                      decoration: InputDecoration(
                        labelText: 'Şifre',
                        prefixIcon: const Icon(Icons.lock_outline),
                        border: const OutlineInputBorder(),
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
                      validator: (v) => v == null || v.length < 6
                          ? 'Şifre en az 6 karakter olmalı'
                          : null,
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: _isBusy ? null : _girisYap,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFF5A623),
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text(
                              'Giriş Yap',
                              style: TextStyle(
                                fontSize: 16,
                                color: Colors.white,
                              ),
                            ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isBusy ? null : _googleIleGirisYap,
                      icon: _isGoogleLoading
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text(
                              'G',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                      label: const Text('Google ile Giriş Yap'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: const Color(0xFF202124),
                        padding: const EdgeInsets.symmetric(vertical: 15),
                        side: BorderSide(color: Colors.grey.shade300),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(8),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Hesabın yok mu?'),
                        TextButton(
                          onPressed: () => context.go('/kayit'),
                          child: const Text(
                            'Kayıt Ol',
                            style: TextStyle(color: Color(0xFFF5A623)),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_isBusy)
            SessionLoadingOverlay(
              title: _isGoogleLoading
                  ? 'Google ile giriş yapılıyor'
                  : 'Giriş yapılıyor',
              subtitle: _isGoogleLoading
                  ? 'Güvenli oturum hazırlanıyor'
                  : 'Profilin hazırlanıyor',
            ),
        ],
      ),
    );
  }
}
