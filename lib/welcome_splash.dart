// lib/welcome_splash.dart
import 'dart:io' show Platform;
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';

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

    // Bazı cihazlarda initState içinde konuşma bağlanmıyor → post-frame.
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<void> _prepareTts() async {
    try {
      await _tts.awaitSpeakCompletion(true);

      if (!kIsWeb) {
        if (Platform.isAndroid) {
          try {
            await _tts.setEngine('com.google.android.tts');
            // Motor bağlansın diye minik bekleme:
            await Future.delayed(const Duration(milliseconds: 150));
          } catch (e) {
            debugPrint('TTS engine set error: $e');
          }
        } else if (Platform.isIOS) {
          try {
            await _tts.setSharedInstance(true);
            await _tts.setIosAudioCategory(
              IosTextToSpeechAudioCategory.playback,
              [
                IosTextToSpeechAudioCategoryOptions.allowBluetooth,
                IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
                IosTextToSpeechAudioCategoryOptions.mixWithOthers,
              ],
              IosTextToSpeechAudioMode.defaultMode,
            );
          } catch (e) {
            debugPrint('iOS audio category error: $e');
          }
        }
      }

      await _tts.setSpeechRate(0.45);
      await _tts.setPitch(1.0);
      await _tts.setVolume(1.0);

      // Dil fallback
      String lang = 'tr-TR';
      try {
        final langsDyn = await _tts.getLanguages;
        final langs = (langsDyn is Iterable)
            ? List<String>.from(langsDyn.map((e) => e.toString()))
            : const <String>[];
        if (!langs.contains(lang)) {
          if (langs.contains('tr_TR')) lang = 'tr_TR';
          else if (langs.contains('tr')) lang = 'tr';
        }
      } catch (_) {}
      await _tts.setLanguage(lang);

      // Voice seçimi → **Map<String,String>** ver
      try {
        final voicesDyn = await _tts.getVoices;
        if (voicesDyn is Iterable) {
          final voices =
              voicesDyn.map((v) => Map<String, dynamic>.from(v)).toList();
          Map<String, dynamic>? pick;
          for (final m in voices) {
            final loc =
                (m['locale'] ?? m['name'] ?? '').toString().toLowerCase();
            if (loc.startsWith('tr')) {
              pick = m;
              break;
            }
          }
          if (pick != null) {
            final name = (pick['name'] ?? '').toString();
            final locale = (pick['locale'] ?? '').toString();
            if (name.isNotEmpty && locale.isNotEmpty) {
              await _tts.setVoice(<String, String>{
                'name': name,
                'locale': locale,
              });
            }
          }
        }
      } catch (e) {
        debugPrint('Voice select error: $e');
      }

      _tts.setErrorHandler((msg) => debugPrint('TTS ERROR: $msg'));
      _tts.setStartHandler(() => debugPrint('TTS START'));
      _tts.setCompletionHandler(() => debugPrint('TTS DONE'));
    } catch (e) {
      debugPrint('TTS prepare error: $e');
    }
  }

  Future<void> _run() async {
    try {
      await _prepareTts();
      final speak = _tts.speak("Refa'ya hoş geldiniz");
      final minDelay = Future.delayed(const Duration(milliseconds: 1200));
      await Future.wait([speak, minDelay]);
    } catch (e) {
      debugPrint('Splash speak error: $e');
      await Future.delayed(const Duration(milliseconds: 800));
    }

    if (!mounted || _navigated) return;
    _navigated = true;
    Navigator.of(context).pushReplacementNamed('/home');
  }

  @override
  void dispose() {
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
                          const Text(
                            'Alzheimer ve demans için akıllı asistan',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              color: Colors.white70,
                              fontSize: 13.5,
                              height: 1.2,
                            ),
                          ),
                          const SizedBox(height: 28),
                          Container(
                            width: 160,
                            height: 5,
                            decoration: BoxDecoration(
                              color: Colors.white54,
                              borderRadius:
                                  const BorderRadius.all(Radius.circular(999)),
                            ),
                            alignment: Alignment.centerLeft,
                            clipBehavior: Clip.hardEdge,
                            child: LayoutBuilder(
                              builder: (context, c) {
                                final w = c.maxWidth;
                                final barW = ((w * _fade.value)
                                        .clamp(28.0, w))
                                    .toDouble();
                                return AnimatedContainer(
                                  duration:
                                      const Duration(milliseconds: 220),
                                  curve: Curves.easeOutCubic,
                                  width: barW,
                                  height: 5,
                                  decoration: const BoxDecoration(
                                    color: Colors.white,
                                    borderRadius: BorderRadius.all(
                                        Radius.circular(999)),
                                  ),
                                );
                              },
                            ),
                          ),
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
