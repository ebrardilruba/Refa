// lib/phone_auth.dart
import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:firebase_auth/firebase_auth.dart';

class PhoneAuthPage extends StatefulWidget {
  const PhoneAuthPage({super.key});

  @override
  State<PhoneAuthPage> createState() => _PhoneAuthPageState();
}

class _PhoneAuthPageState extends State<PhoneAuthPage> {
  // Başlangıçta boş bırakıyoruz; + işareti gerekmiyor (normalize fonksiyonu ekler)
  final _phoneCtrl = TextEditingController(text: '');
  final _codeCtrl = TextEditingController();
  final _auth = FirebaseAuth.instance;

  String? _verificationId;
  int? _resendToken;
  bool _sending = false;
  bool _verifying = false;
  String? _error;

  Timer? _timer;
  int _secLeft = 0;

  @override
  void initState() {
    super.initState();
    _auth.setLanguageCode('tr');
  }

  @override
  void dispose() {
    _timer?.cancel();
    _phoneCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  void _startCountdown([int s = 60]) {
    _timer?.cancel();
    setState(() => _secLeft = s);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_secLeft <= 1) {
        t.cancel();
        setState(() => _secLeft = 0);
      } else {
        setState(() => _secLeft--);
      }
    });
  }

  /// E.164’e çevirir. Hatalıysa null döner.
  /// Kabul edilen örnekler: 905551112233 | 05551112233 | 5551112233 | +905551112233
  String? _normalizePhone(String input) {
    // Sadece + ve rakamlar kalsın
    var raw = input.replaceAll(RegExp(r'[^0-9+]'), '').trim();
    if (raw.isEmpty) return null;

    // + ile gelmişse: +[digits] ve 8..15 arası olsun
    if (raw.startsWith('+')) {
      final digits = raw.substring(1).replaceAll(RegExp(r'\D'), '');
      if (digits.length < 8 || digits.length > 15) return null;
      return '+$digits';
    }

    // + yoksa TR varsayılanı: baştaki 0/90'ı at, 10 hane bekle, +90 ekle
    raw = raw.replaceFirst(RegExp(r'^0'), '');
    if (raw.startsWith('90')) raw = raw.substring(2);
    if (!RegExp(r'^\d{10}$').hasMatch(raw)) return null;
    return '+90$raw';
  }

  Future<void> _sendCode() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _sending = true;
    });

    final number = _normalizePhone(_phoneCtrl.text);
    if (number == null) {
      setState(() {
        _sending = false;
        _error =
            'Telefon numarası geçersiz.\nÖrnek: 5551112233 / 05551112233 / 905551112233';
      });
      return;
    }

    try {
      await _auth.verifyPhoneNumber(
        phoneNumber: number,
        forceResendingToken: _resendToken,
        timeout: const Duration(seconds: 60),
        verificationCompleted: (cred) async {
          try {
            await _auth.signInWithCredential(cred);
            if (!mounted) return;
            _onSignedIn();
          } catch (e) {
            if (!mounted) return;
            setState(() => _error = e.toString());
          }
        },
        verificationFailed: (e) {
          setState(() => _error = e.message ?? e.code);
        },
        codeSent: (verificationId, resendToken) {
          setState(() {
            _verificationId = verificationId;
            _resendToken = resendToken;
          });
          _startCountdown(60);
        },
        codeAutoRetrievalTimeout: (verificationId) {
          setState(() => _verificationId = verificationId);
        },
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _verifyCode() async {
    FocusScope.of(context).unfocus();
    if (_verificationId == null) {
      setState(() => _error = 'Önce “Kodu Gönder”e bas.');
      return;
    }
    final sms = _codeCtrl.text.trim();
    if (sms.length < 4) {
      setState(() => _error = 'Geçerli bir kod gir.');
      return;
    }
    setState(() {
      _error = null;
      _verifying = true;
    });

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: sms,
      );
      await _auth.signInWithCredential(cred);
      if (!mounted) return;
      _onSignedIn();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = '[${e.code}] ${e.message ?? ''}');
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _verifying = false);
    }
  }

  void _onSignedIn() {
    // Login → Welcome (hoş geldiniz). Geri yığını temizle.
    Navigator.of(context).pushNamedAndRemoveUntil('/welcome', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    // DIŞ KATMAN → mavi gradyan (Scaffold transparan)
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF334155), Color(0xFF1E3A8A), Color(0xFF1E40AF)],
        ),
      ),
      child: Scaffold(
        backgroundColor: Colors.transparent,
        body: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // ÜSTTE DAİRE LOGO
                  Container(
                    width: 96,
                    height: 96,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: const Color(0xFF132542),
                      boxShadow: const [
                        BoxShadow(
                            color: Colors.black54,
                            blurRadius: 18,
                            offset: Offset(0, 10)),
                      ],
                      border: Border.all(
                          color: Colors.white.withOpacity(0.12), width: 1.2),
                    ),
                    padding: const EdgeInsets.all(14),
                    child: Image.asset('assets/icons/icon_fg.png',
                        fit: BoxFit.contain),
                  ),
                  const SizedBox(height: 16),

                  // GLASS PANEL
                  _GlassPanel(
                    child: Padding(
                      padding: const EdgeInsets.all(22),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text(
                            'Telefonla Giriş',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white,
                                fontSize: 22,
                                fontWeight: FontWeight.w800),
                          ),
                          const SizedBox(height: 18),

                          // TELEFON
                          _LabeledField(
                            label: 'Telefon',
                            child: TextField(
                              controller: _phoneCtrl,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.send,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(
                                    12), // 90xxxxxxxxxx max (10–12 kabul)
                              ],
                              maxLength: 12,
                              maxLengthEnforcement:
                                  MaxLengthEnforcement.enforced,
                              buildCounter: (_, {required currentLength, maxLength, required isFocused}) =>
                                  const SizedBox.shrink(),
                              onSubmitted: (_) {
                                if (!_sending && _secLeft == 0) _sendCode();
                              },
                              style: const TextStyle(color: Colors.white),
                              decoration: _inputDecoration(
                                  'örn: 5551112233 / 0555… / 90555…'),
                            ),
                          ),
                          const SizedBox(height: 10),

                          FilledButton(
                            onPressed:
                                (_sending || _secLeft > 0) ? null : _sendCode,
                            style: _primaryButtonStyle(),
                            child: Text(_secLeft > 0
                                ? 'Kodu Gönder ($_secLeft)'
                                : 'Kodu Gönder'),
                          ),
                          const SizedBox(height: 16),

                          // SMS KODU
                          _LabeledField(
                            label: 'SMS Kodu',
                            child: TextField(
                              controller: _codeCtrl,
                              keyboardType: TextInputType.number,
                              textInputAction: TextInputAction.done,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(6),
                              ],
                              maxLength: 6,
                              maxLengthEnforcement:
                                  MaxLengthEnforcement.enforced,
                              buildCounter: (_, {required currentLength, maxLength, required isFocused}) =>
                                  const SizedBox.shrink(),
                              onSubmitted: (_) {
                                if (!_verifying) _verifyCode();
                              },
                              style: const TextStyle(color: Colors.white),
                              obscureText: true,
                              obscuringCharacter: '•',
                              enableSuggestions: false,
                              autocorrect: false,
                              decoration: _inputDecoration('******'),
                            ),
                          ),
                          const SizedBox(height: 10),

                          FilledButton(
                            onPressed:
                                _verifying ? null : _verifyCode,
                            style: _primaryButtonStyle(),
                            child: _verifying
                                ? const SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                        strokeWidth: 2, color: Colors.white),
                                  )
                                : const Text('Giriş Yap'),
                          ),

                          if (_error != null) ...[
                            const SizedBox(height: 14),
                            Text(
                              _error!,
                              textAlign: TextAlign.center,
                              style:
                                  const TextStyle(color: Color(0xFFFFB4A9)),
                            ),
                          ],

                          const SizedBox(height: 10),
                          Text(
                            'Başarılı girişten sonra oturum cihazda kalıcıdır.',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                                color: Colors.white.withOpacity(.8),
                                fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  InputDecoration _inputDecoration(String hint) => InputDecoration(
        hintText: hint,
        hintStyle: TextStyle(color: Colors.white.withOpacity(.6)),
        filled: true,
        fillColor: Colors.white.withOpacity(0.10),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: Colors.white.withOpacity(.25)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide:
              BorderSide(color: Colors.white.withOpacity(0.6), width: 1.2),
        ),
      );

  ButtonStyle _primaryButtonStyle() => FilledButton.styleFrom(
        backgroundColor: const Color(0xFF3D63DD), // mavi
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(vertical: 14),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        disabledBackgroundColor: Colors.white.withOpacity(0.20),
        disabledForegroundColor: Colors.white.withOpacity(0.8),
      );
}

/* ------- yardımcı bileşenler ------- */

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.12),
                  border: Border.all(
                      color: Colors.white.withOpacity(0.30), width: 1),
                  borderRadius: BorderRadius.circular(22),
                  boxShadow: const [
                    BoxShadow(
                        color: Colors.black26,
                        blurRadius: 14,
                        offset: Offset(0, 8)),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;
  const _LabeledField({required this.label, required this.child});
//sadasd
//sdsdsd
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: TextStyle(
                color: Colors.white.withOpacity(.9),
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 6),
        child,
      ],
    );
  }
}
