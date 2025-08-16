import 'dart:async';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'app.dart' show RefaHomePage;

class WelcomeSplash extends StatefulWidget {
  const WelcomeSplash({super.key});
  @override
  State<WelcomeSplash> createState() => _WelcomeSplashState();
}

class _WelcomeSplashState extends State<WelcomeSplash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  late final Animation<double> _scale;
  late final Animation<double> _fade;
  final _tts = FlutterTts();

  Timer? _navTimer;
  bool _navigated = false;

  @override
  void initState() {
    super.initState();

    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scale = Tween<double>(begin: 0.85, end: 1.0)
        .chain(CurveTween(curve: Curves.easeOutCubic))
        .animate(_ctrl);
    _fade = Tween<double>(begin: 0, end: 1)
        .chain(CurveTween(curve: Curves.easeOut))
        .animate(_ctrl);
    _ctrl.forward();

    _speakWelcome();

    // 15 saniye sonra otomatik geç
    _navTimer = Timer(const Duration(seconds: 8), _goHome);
  }

  Future<void> _speakWelcome() async {
    try {
      await _tts.setLanguage('tr-TR');
      await _tts.setPitch(1.0);
      await _tts.setSpeechRate(0.48);
      await _tts.speak('Refa’ya hoş geldiniz');
    } catch (_) {}
  }

  void _goHome() {
    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const RefaHomePage(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _navTimer?.cancel();
    _tts.stop();
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const bgGradient = LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0F172A), Color(0xFF1E3A8A), Color(0xFF1E40AF)],
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const DecoratedBox(decoration: BoxDecoration(gradient: bgGradient)),
          BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: const SizedBox.expand(),
          ),
          SafeArea(
            child: Center(
              child: AnimatedBuilder(
                animation: _ctrl,
                builder: (context, _) {
                  return Opacity(
                    opacity: _fade.value,
                    child: Transform.scale(
                      scale: _scale.value,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Daire içi PNG (simetrik, kayma yok)
                          SizedBox(
                            width: 120,
                            height: 120,
                            child: ClipOval(
                              child: Image.asset(
                                'assets/icons/icon_fg.png',
                                fit: BoxFit.cover,
                                filterQuality: FilterQuality.high,
                              ),
                            ),
                          ),
                          const SizedBox(height: 20),

                          const Text(
                            'Refa’ya Hoş Geldiniz',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 24,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 0.2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Alzheimer ve demans için akıllı asistan',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white.withOpacity(0.85),
                              fontSize: 13.5,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 28),

                          // İnce yükleme çizgisi
                          Container(
                            width: 160,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.18),
                              borderRadius: BorderRadius.circular(999),
                            ),
                            alignment: Alignment.centerLeft,
                            clipBehavior: Clip.hardEdge,
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final double w = c.maxWidth;
                                final double barW =
                                    ((w * _fade.value).clamp(28.0, w)).toDouble();
                                return AnimatedContainer(
                                  duration: const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  width: barW,
                                  height: 5,
                                  decoration: BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                );
                              },
                            ),
                          ),
                          // “Geç” butonu kaldırıldı
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}
