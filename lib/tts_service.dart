// lib/tts_service.dart
import 'dart:async';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart' show debugPrint;

class VoiceService {
  VoiceService._internal();
  static final VoiceService _instance = VoiceService._internal();
  static VoiceService get instance => _instance;

  // TTS
  final FlutterTts _tts = FlutterTts();
  bool _isTtsInitialized = false;
  bool _isSpeaking = false;

  // STT
  final stt.SpeechToText _stt = stt.SpeechToText();
  bool _isSttInitialized = false;
  bool _isListening = false;
  String _currentWords = '';

  // Yaşlı dostu varsayılanlar
  double _rate = 0.4;
  double _pitch = 1.0;
  String _lang = 'tr-TR';

  // Streams
  final _recognitionController = StreamController<String>.broadcast();
  final _listeningController = StreamController<bool>.broadcast();
  final _speakingController = StreamController<bool>.broadcast();

  Stream<String> get onRecognition => _recognitionController.stream;
  Stream<bool> get onListeningChange => _listeningController.stream;
  Stream<bool> get onSpeakingChange => _speakingController.stream;

  // Yazım/kısaltma düzeltmeleri (STT çıktısını iyileştirmek için)
  final Map<String, String> _commonFixes = const {
    // Selam / teşekkür / onay
    'meraba': 'merhaba', 'merba': 'merhaba', 'mrb': 'merhaba', 'slm': 'selam',
    'sg': 'sağ ol', 'sagol': 'sağ ol', 'sağol': 'sağ ol', 'sağolun': 'sağ olun',
    'eyw': 'teşekkür ederim', 'eyvallah': 'teşekkür ederim',
    'ok': 'tamam', 'okk': 'tamam', 'tmm': 'tamam',
    // Durum
    'iyim': 'iyiyim', 'iyyim': 'iyiyim', 'iyiym': 'iyiyim',
    'kotuyum': 'kötüyüm', 'kötuyum': 'kötüyüm',
    // Sık komutlar / kavramlar
    'ilac': 'ilaç', 'ilacc': 'ilaç',
    'unutuyom': 'unutuyorum', 'unuttum': 'unutuyorum',
    'nerdeyim': 'neredeyim', 'nerde': 'nerede',
    'korkuyom': 'korkuyorum', 'yalnizim': 'yalnızım',
    'saat kac': 'saat kaç',
    'ne var': 'bugün ne var',
    'yardim': 'yardım', 'imdat': 'yardım', 'acil': 'yardım',
  };

  // ---- Lifecycle ----
  Future<void> init() async {
    await _initTts();
    await _initStt();
  }

  Future<void> _initTts() async {
    if (_isTtsInitialized) return;
    try {
      await _tts.setLanguage(_lang);
      await _tts.setPitch(_pitch);
      await _tts.setSpeechRate(_rate);
      await _tts.setVolume(1.0);
      await _tts.awaitSpeakCompletion(true);

      _tts.setStartHandler(() {
        _isSpeaking = true;
        _speakingController.add(true);
      });

      _tts.setCompletionHandler(() {
        _isSpeaking = false;
        _speakingController.add(false);
      });

      _tts.setErrorHandler((msg) {
        _isSpeaking = false;
        _speakingController.add(false);
        debugPrint('TTS Hatası: $msg');
      });

      _isTtsInitialized = true;
    } catch (e) {
      debugPrint('TTS Başlatma Hatası: $e');
    }
  }

  Future<void> _initStt() async {
    if (_isSttInitialized) return;
    try {
      final status = await Permission.microphone.request();
      if (status.isDenied || status.isPermanentlyDenied) {
        debugPrint('Mikrofon izni reddedildi');
        return;
      }

      _isSttInitialized = await _stt.initialize(
        onStatus: (s) => debugPrint('STT Durumu: $s'),
        onError: (e) => debugPrint('STT Hatası: $e'),
      );
    } catch (e) {
      debugPrint('STT Başlatma Hatası: $e');
    }
  }

  // ---- TTS ----
  Future<void> speak(String text) async {
    if (text.isEmpty) return;
    await _initTts();

    if (_isListening) await stopListening();
    await _tts.speak(_cleanTextForElderly(text));
  }

  String _cleanTextForElderly(String text) {
    var cleaned = text;

    // daha akıcı okunuş için küçük sadeleştirmeler
    cleaned = cleaned.replaceAll('lütfen', '');
    cleaned = cleaned.replaceAll('rica ederim', '');
    cleaned = cleaned.replaceAll('yardımcı olabilirim', 'yardım ederim');

    cleaned = cleaned.replaceAll('.', '. ');
    cleaned = cleaned.replaceAll(',', ', ');
    cleaned = cleaned.replaceAll('!', '! ');
    cleaned = cleaned.replaceAll('?', '? ');

    cleaned = cleaned.replaceAll(RegExp(r'\s+'), ' ');
    return cleaned.trim();
  }

  Future<void> stopSpeaking() async {
    if (_isSpeaking) {
      await _tts.stop();
      _isSpeaking = false;
      _speakingController.add(false);
    }
  }

  // ---- STT ----
  Future<bool> startListening({
    Duration timeout = const Duration(seconds: 45),
    Duration pauseFor = const Duration(seconds: 8),
  }) async {
    await _initStt();
    if (!_isSttInitialized) return false;

    if (_isSpeaking) await stopSpeaking();
    await Future.delayed(const Duration(milliseconds: 300));

    _isListening = true;
    _listeningController.add(true);
    _currentWords = '';

    return await _stt.listen(
      onResult: (result) {
        _currentWords = result.recognizedWords;
        _recognitionController.add(_currentWords);

        if (result.finalResult) {
          final enhancedText = _enhanceRecognizedText(_currentWords);
          _recognitionController.add(enhancedText);
          _currentWords = enhancedText;
        }
      },
      listenFor: timeout,
      pauseFor: pauseFor,
      localeId: _lang,
      partialResults: true,
      listenMode: stt.ListenMode.dictation,
      onSoundLevelChange: (level) {},
      cancelOnError: true,
    );
  }

  String _enhanceRecognizedText(String text) {
    if (text.isEmpty) return text;

    var cleaned = text.toLowerCase();

    // Türkçe kelime sınırı için unicode:true kullanalım
    _commonFixes.forEach((wrong, correct) {
      cleaned = cleaned.replaceAll(
        RegExp(r'\b' + RegExp.escape(wrong) + r'\b', unicode: true, caseSensitive: false),
        correct,
      );
    });

    // Soru gibi cümleyse soru işareti ekle
    if (cleaned.contains(' mi ') || cleaned.contains(' mı ') ||
        cleaned.contains(' mu ') || cleaned.contains(' mü ') ||
        cleaned.contains('ne zaman') || cleaned.contains('nasıl') ||
        cleaned.startsWith('kim') || cleaned.startsWith('nerede') ||
        cleaned.startsWith('nerde')) {
      if (!cleaned.endsWith('?')) cleaned += '?';
    }

    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() + cleaned.substring(1);
    }
    return cleaned;
  }

  Future<void> stopListening() async {
    if (_isListening) {
      await _stt.stop();
      _isListening = false;
      _listeningController.add(false);
    }
  }

  // Ayarlar (SettingsPage ile uyumlu)
  Future<void> setRate(double rate) async {
    _rate = rate.clamp(0.2, 0.9);
    if (_isTtsInitialized) {
      await _tts.setSpeechRate(_rate);
    }
  }

  Future<void> setPitch(double pitch) async {
    _pitch = pitch.clamp(0.7, 1.3);
    if (_isTtsInitialized) {
      await _tts.setPitch(_pitch);
    }
  }

  Future<void> setLanguage(String languageCode) async {
    _lang = languageCode;
    if (_isTtsInitialized) {
      await _tts.setLanguage(_lang);
    }
  }

  void dispose() {
    _stt.stop();
    _tts.stop();
    _recognitionController.close();
    _listeningController.close();
    _speakingController.close();
  }

  // Getters
  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  String get currentWords => _currentWords;
  double get rate => _rate;
  double get pitch => _pitch;
  String get lang => _lang;
  String get language => _lang; // alias
}

// Eski kodlarla uyum için hafif adapter
class TtsService {
  TtsService._();
  static final TtsService instance = TtsService._();

  final _v = VoiceService.instance;

  Stream<String> get onRecognition => _v.onRecognition;
  Stream<bool> get onListeningChange => _v.onListeningChange;
  Stream<bool> get onSpeakingChange => _v.onSpeakingChange;

  Future<void> init() => _v.init();
  Future<void> speak(String t) => _v.speak(t);
  Future<void> stop() => _v.stopSpeaking();
  Future<void> stopSpeaking() => _v.stopSpeaking();
  Future<bool> startListening({
    Duration timeout = const Duration(seconds: 45),
    Duration pauseFor = const Duration(seconds: 8),
  }) =>
      _v.startListening(timeout: timeout, pauseFor: pauseFor);
  Future<void> stopListening() => _v.stopListening();
  Future<void> setRate(double r) => _v.setRate(r);
  Future<void> setPitch(double p) => _v.setPitch(p);
  Future<void> setLanguage(String l) => _v.setLanguage(l);

  bool get isListening => _v.isListening;
  bool get isSpeaking => _v.isSpeaking;
  String get currentWords => _v.currentWords;
  double get rate => _v.rate;
  double get pitch => _v.pitch;
  String get lang => _v.lang;
  String get language => _v.language;
}
