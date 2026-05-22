import 'dart:async';

import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
                    ElevatedButton.icon(
                      onPressed: _isBusy ? null : _googleIleGirisYap,
                      icon: _isGoogleLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Color(0xFFDB4437),
                              ),
                            )
                          : SvgPicture.string(
                              '''<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 48 48"><path fill="#EA4335" d="M24 9.5c3.54 0 6.71 1.22 9.21 3.6l6.85-6.85C35.9 2.38 30.47 0 24 0 14.62 0 6.51 5.38 2.56 13.22l7.98 6.19C12.43 13.7 17.74 9.5 24 9.5z"/><path fill="#4285F4" d="M46.98 24.55c0-1.57-.15-3.09-.38-4.55H24v9.02h12.94c-.58 2.96-2.26 5.48-4.78 7.18l7.73 6c4.51-4.18 7.09-10.36 7.09-17.65z"/><path fill="#FBBC05" d="M10.53 28.59c-.48-1.45-.76-2.99-.76-4.59s.27-3.14.76-4.59l-7.98-6.19C.92 16.46 0 20.12 0 24c0 3.88.92 7.54 2.56 10.78l7.97-6.19z"/><path fill="#34A853" d="M24 48c6.48 0 11.93-2.13 15.89-5.81l-7.73-6c-2.15 1.45-4.92 2.3-8.16 2.3-6.26 0-11.57-4.22-13.47-9.91l-7.98 6.19C6.51 42.62 14.62 48 24 48z"/><path fill="none" d="M0 0h48v48H0z"/></svg>''',
                              width: 24,
                              height: 24,
                            ),
                      label: const Text(
                        'Google ile Giriş Yap',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF3C4043),
                        ),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: const Color(0xFF3C4043),
                        surfaceTintColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        elevation: 2,
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
