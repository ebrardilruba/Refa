// lib/tts_service.dart - Düzeltilmiş versiyon
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Projedeki eski kullanım için adapter:
class TtsService {
  static EnhancedVoiceService get instance => EnhancedVoiceService.instance;
}

class EnhancedVoiceService {
  EnhancedVoiceService._();
  static final instance = EnhancedVoiceService._();

  // ---------- TTS ----------
  FlutterTts? _tts;
  bool _ttsInited = false;
  bool _isSpeaking = false;

  // ---------- STT ----------
  SpeechToText? _stt;
  bool _sttInited = false;
  bool _isListening = false;
  String _currentWords = '';

  // ---------- Streams ----------
  final _recognizedWordsController = StreamController<String>.broadcast();
  final _listeningController = StreamController<bool>.broadcast();
  final _statusController = StreamController<String>.broadcast();

  Stream<String> get recognizedWordsStream => _recognizedWordsController.stream;
  Stream<bool> get listeningStream => _listeningController.stream;
  Stream<String> get statusStream => _statusController.stream;

  bool get isListening => _isListening;
  bool get isSpeaking => _isSpeaking;
  String get currentWords => _currentWords;

  // ---------- Settings ----------
  static const _kRateKey = 'tts_rate';
  static const _kPitchKey = 'tts_pitch';
  static const _kLangKey = 'tts_lang';

  double _rate = 0.45;
  double _pitch = 1.0;
  String _lang = 'tr-TR';

  double get rate => _rate;
  double get pitch => _pitch;
  String get lang => _lang;

  // ---------- STT Düzeltmeleri ----------
  final Map<String, String> _commonFixes = {
    'merhaba': 'merhaba', 'meraba': 'merhaba', 'merha ba': 'merhaba',
    'salam': 'selam', 'selam': 'selam', 'se lam': 'selam',
    'nasısın': 'nasılsın', 'nasilsin': 'nasılsın', 'nasıl sın': 'nasılsın',
    'iyiyim': 'iyiyim', 'iyi yim': 'iyiyim', 'iyyim': 'iyiyim',
    'kötüyüm': 'kötüyüm', 'kotu yum': 'kötüyüm', 'kötü yüm': 'kötüyüm',
    'yorgunum': 'yorgunum', 'yorgun um': 'yorgunum', 'yorgunu m': 'yorgunum',
    'bugün ne var': 'bugün ne var', 'bugun ne war': 'bugün ne var', 'bu gün ne var': 'bugün ne var',
    'saat kaç': 'saat kaç', 'sat kac': 'saat kaç', 'sa at kaç': 'saat kaç',
    'ilaç ekle': 'ilaç ekle', 'ilac ekle': 'ilaç ekle', 'i laç ekle': 'ilaç ekle',
    'hatırlatıcı ekle': 'hatırlatıcı ekle', 'hatirlat ci ekle': 'hatırlatıcı ekle',
    'liste': 'listele', 'listele': 'listele', 'lis te': 'listele',
    'sil': 'sil', 'silsilah': 'sil', 'si l': 'sil',
    'yardım': 'yardım', 'yarım': 'yardım', 'help': 'yardım', 'yar dım': 'yardım',
    'ne yesem': 'ne yesem', 'ne yiyem': 'ne yesem', 'ne ye sem': 'ne yesem',
    'halsizim': 'halsizim', 'hal sizim': 'halsizim', 'hal siz im': 'halsizim',
    'tahlil': 'tahlil', 'tahril': 'tahlil', 'tah lil': 'tahlil',
    'profil': 'profil', 'pro fil': 'profil', 'prof il': 'profil',
  };

  // Türkçe sayılar
  final Map<String, String> _numberWords = {
    'bir': '1', 'iki': '2', 'üç': '3', 'dört': '4', 'beş': '5', 'altı': '6',
    'yedi': '7', 'sekiz': '8', 'dokuz': '9', 'on': '10', 'onbir': '11', 'oniki': '12',
    'onüç': '13', 'ondört': '14', 'onbeş': '15', 'onaltı': '16', 'onyedi': '17',
    'onsekiz': '18', 'ondokuz': '19', 'yirmi': '20', 'otuz': '30', 'kırk': '40', 'elli': '50',
  };

  // ---------- Lifecycle ----------
  Future<void> init() async {
    try {
      await _initTts();
      await _initStt();
      _updateStatus('Servis hazır');
    } catch (e) {
      _updateStatus('Servis başlatma hatası: $e');
    }
  }

  void dispose() {
    _recognizedWordsController.close();
    _listeningController.close();
    _statusController.close();
    _tts?.stop();
    _stt?.stop();
  }

  // ---------- TTS İşlemleri ----------
  Future<void> _initTts() async {
    if (_ttsInited) return;

    try {
      _tts = FlutterTts();

      // Preferences'ları yükle
      final prefs = await SharedPreferences.getInstance();
      _rate = prefs.getDouble(_kRateKey) ?? _rate;
      _pitch = prefs.getDouble(_kPitchKey) ?? _pitch;
      _lang = prefs.getString(_kLangKey) ?? _lang;

      // TTS ayarları
      await _tts!.awaitSpeakCompletion(true);

      // iOS ayarları
      if (!kIsWeb) {
        try {
          await _tts!.setIosAudioCategory(
            IosTextToSpeechAudioCategory.playback,
            [
              IosTextToSpeechAudioCategoryOptions.allowBluetooth,
              IosTextToSpeechAudioCategoryOptions.defaultToSpeaker,
              IosTextToSpeechAudioCategoryOptions.mixWithOthers,
            ],
            IosTextToSpeechAudioMode.defaultMode,
          );
        } catch (e) {
          debugPrint('iOS TTS ayarları hatası: $e');
        }

        // Android TTS engine
        try {
          await _tts!.setEngine('com.google.android.tts');
        } catch (e) {
          debugPrint('Android TTS engine ayarı hatası: $e');
        }
      }

      // TTS event handler'ları
      _tts!.setStartHandler(() {
        _isSpeaking = true;
        _updateStatus('Konuşuyor...');
      });

      _tts!.setCompletionHandler(() {
        _isSpeaking = false;
        _updateStatus('TTS tamamlandı');
      });

      _tts!.setErrorHandler((msg) {
        _isSpeaking = false;
        _updateStatus('TTS hatası: $msg');
      });

      await _applyTtsSettings();
      _ttsInited = true;
      _updateStatus('TTS hazır');
    } catch (e) {
      _updateStatus('TTS başlatılamadı: $e');
      debugPrint('TTS init hatası: $e');
    }
  }

  Future<void> _applyTtsSettings() async {
    if (_tts == null) return;

    try {
      await _tts!.setLanguage(_lang);
      await _tts!.setSpeechRate(_rate);
      await _tts!.setPitch(_pitch);
    } catch (e) {
      debugPrint('TTS ayarları uygulanmadı: $e');
    }
  }

  Future<void> setRate(double v) async {
    try {
      _rate = v.clamp(0.2, 0.9);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kRateKey, _rate);
      if (_tts != null) await _tts!.setSpeechRate(_rate);
    } catch (e) {
      debugPrint('Rate ayarlama hatası: $e');
    }
  }

  Future<void> setPitch(double v) async {
    try {
      _pitch = v.clamp(0.7, 1.3);
      final prefs = await SharedPreferences.getInstance();
      await prefs.setDouble(_kPitchKey, _pitch);
      if (_tts != null) await _tts!.setPitch(_pitch);
    } catch (e) {
      debugPrint('Pitch ayarlama hatası: $e');
    }
  }

  Future<void> setLanguage(String code) async {
    try {
      _lang = code;
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kLangKey, _lang);
      if (_tts != null) await _tts!.setLanguage(_lang);
    } catch (e) {
      debugPrint('Dil ayarlama hatası: $e');
    }
  }

  Future<void> speak(String text) async {
    if (text.trim().isEmpty) return;

    try {
      await init();
      if (_tts == null) {
        _updateStatus('TTS başlatılamadı');
        return;
      }

      // STT dinliyorsa kapat
      if (_isListening) {
        await stopListening();
        await Future.delayed(const Duration(milliseconds: 100));
      }

      // Mevcut TTS'i durdur
      await stopSpeaking();
      await Future.delayed(const Duration(milliseconds: 50));

      await _applyTtsSettings();

      final cleanedText = _enhancedTextCleaning(text);
      if (cleanedText.trim().isEmpty) return;

      final parts = _chunkSmart(cleanedText, maxLen: 600);

      for (final part in parts) {
        final finalText = _lastMinuteCheck(part);
        if (finalText.trim().isNotEmpty) {
          // awaitSpeakCompletion(true) aktif olduğu için ek bekleme döngüsüne gerek yok
          await _tts!.speak(finalText);
        }
      }
    } catch (e) {
      _isSpeaking = false;
      _updateStatus('TTS konuşma hatası: $e');
      debugPrint('Speak hatası: $e');
    }
  }

  // Eski kod uyumluluğu için:
  Future<void> speakText(String text) => speak(text);
  Future<void> stop() => stopSpeaking();
  Future<void> stopTts() => stopSpeaking();

  Future<void> stopSpeaking() async {
    try {
      _isSpeaking = false;
      await _tts?.stop();
      _updateStatus('TTS durduruldu');
    } catch (e) {
      debugPrint('TTS durdurma hatası: $e');
    }
  }

  // ---------- STT İşlemleri ----------
  Future<void> _initStt() async {
    if (_sttInited) return;

    try {
      // Mikrofon izni kontrol et
      final permission = await Permission.microphone.status;
      if (permission.isDenied) {
        final result = await Permission.microphone.request();
        if (result.isDenied) {
          _updateStatus('Mikrofon izni reddedildi');
          return;
        }
      }

      _stt = SpeechToText();

      final available = await _stt!.initialize(
        onStatus: _onSttStatus,
        onError: _onSttError,
        debugLogging: kDebugMode,
      );

      if (available) {
        _sttInited = true;
        _updateStatus('STT hazır');

        // Türkçe locale kontrolü
        final locales = await _stt!.locales();
        final hasTr = locales.any((l) => l.localeId.startsWith('tr'));
        if (!hasTr) {
          _updateStatus('Türkçe STT bulunamadı, varsayılan kullanılacak');
        }
      } else {
        _updateStatus('STT başlatılamadı');
      }
    } catch (e) {
      _updateStatus('STT init hatası: $e');
      debugPrint('STT başlatma hatası: $e');
    }
  }

  void _onSttStatus(String status) {
    _updateStatus('STT: $status');

    if (status == 'listening') {
      _isListening = true;
    } else if (status == 'done' || status == 'notListening') {
      _isListening = false;
    }

    if (!_listeningController.isClosed) {
      _listeningController.add(_isListening);
    }
  }

  void _onSttError(dynamic error) {
    _updateStatus('STT Hatası: $error');
    _isListening = false;

    if (!_listeningController.isClosed) {
      _listeningController.add(false);
    }

    debugPrint('STT error: $error');
  }

  Future<void> startListening({
    Duration timeout = const Duration(seconds: 30),
    Duration pauseFor = const Duration(seconds: 3),
  }) async {
    try {
      if (!_sttInited) {
        await _initStt();
        if (!_sttInited || _stt == null) {
          _updateStatus('STT başlatılamadı');
          return;
        }
      }

      if (_isListening) {
        await stopListening();
        await Future.delayed(const Duration(milliseconds: 200));
      }

      // TTS'i sustur
      if (_isSpeaking) {
        await stopSpeaking();
        await Future.delayed(const Duration(milliseconds: 300));
      }

      _currentWords = '';
      if (!_recognizedWordsController.isClosed) {
        _recognizedWordsController.add('');
      }

      final started = await _stt!.listen(
        onResult: _onSttResult,
        listenFor: timeout,
        pauseFor: pauseFor,
        partialResults: true,
        localeId: 'tr-TR',
        cancelOnError: true,
        listenMode: ListenMode.confirmation,
      );

      if (started) {
        _isListening = true;
        if (!_listeningController.isClosed) {
          _listeningController.add(true);
        }
        _updateStatus('Dinliyor... Konuşabilirsiniz');
      } else {
        _updateStatus('Dinleme başlatılamadı');
      }
    } catch (e) {
      _updateStatus('Dinleme hatası: $e');
      _isListening = false;
      if (!_listeningController.isClosed) {
        _listeningController.add(false);
      }
      debugPrint('STT listen hatası: $e');
    }
  }

  void _onSttResult(SpeechRecognitionResult result) {
    try {
      if (result.recognizedWords.isNotEmpty) {
        _currentWords = result.recognizedWords;

        if (!_recognizedWordsController.isClosed) {
          _recognizedWordsController.add(_currentWords);
        }

        if (result.finalResult) {
          final cleaned = _enhanceRecognizedText(_currentWords);
          if (!_recognizedWordsController.isClosed) {
            _recognizedWordsController.add(cleaned);
          }
          _updateStatus('Tanınan: "$cleaned"');
        }
      }
    } catch (e) {
      debugPrint('STT result işleme hatası: $e');
    }
  }

  Future<void> stopListening() async {
    if (_isListening && _stt != null) {
      try {
        await _stt!.stop();
        _isListening = false;
        if (!_listeningController.isClosed) {
          _listeningController.add(false);
        }
        _updateStatus('Dinleme durduruldu');
      } catch (e) {
        _updateStatus('Dinleme durdurulamadı: $e');
        debugPrint('STT stop hatası: $e');
      }
    }
  }

  // ---------- TTS Metin Temizleme ----------
  String _enhancedTextCleaning(String text) {
    if (text.trim().isEmpty) return '';

    String cleaned = text
        .replaceAll('\r', ' ')
        .replaceAll('\t', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    cleaned = _cleanEmojisAndSpecialChars(cleaned);

    // URL'leri temizle
    cleaned = cleaned.replaceAll(
      RegExp(r'https?://[^\s]+|www\.[^\s]+', caseSensitive: false),
      'link',
    );

    // Email'leri temizle
    cleaned = cleaned.replaceAll(
      RegExp(r'[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}'),
      'email adresi',
    );

    // Sembol düzeltmeleri
    const symbolFixes = {
      '&': 've', '@': 'at işareti', '#': 'hashtag', '%': 'yüzde',
      '+': 'artı', '=': 'eşittir', '<': 'küçüktür', '>': 'büyüktür',
      '€': 'euro', r'$': 'dolar', '₺': 'türk lirası',
    };
    symbolFixes.forEach((symbol, replacement) {
      cleaned = cleaned.replaceAll(symbol, ' $replacement ');
    });

    cleaned = _processNumbers(cleaned);
    cleaned = _fixRepeatingChars(cleaned);
    cleaned = _fixPunctuation(cleaned);

    // Final temizlik
    cleaned = cleaned
        .replaceAll(RegExp(r'\s+'), ' ')
        .replaceAll(RegExp(r'\s+([.,!?;:])'), r'$1')
        .trim();

    return cleaned;
  }

  String _cleanEmojisAndSpecialChars(String text) {
    return text.replaceAll(
      RegExp(
        r'[\u{1f300}-\u{1f5ff}]|[\u{1f600}-\u{1f64f}]|[\u{1f680}-\u{1f6ff}]|'
        r'[\u{2600}-\u{26ff}]|[\u{2700}-\u{27bf}]',
        unicode: true,
      ),
      ' ',
    );
  }

  String _processNumbers(String text) {
    return text.replaceAllMapped(
      RegExp(r'(\d{1,2})\.(\d{1,2})\.(\d{4})'),
      (match) {
        final day = int.tryParse(match.group(1)!) ?? 0;
        final month = int.tryParse(match.group(2)!) ?? 0;
        final year = match.group(3)!;

        const months = [
          '', 'ocak', 'şubat', 'mart', 'nisan', 'mayıs', 'haziran',
          'temmuz', 'ağustos', 'eylül', 'ekim', 'kasım', 'aralık'
        ];

        if (month > 0 && month <= 12) {
          return '$day ${months[month]} $year';
        }
        return match.group(0)!;
      },
    );
  }

  String _fixRepeatingChars(String text) {
    return text.replaceAllMapped(
      RegExp(r'(\w)\1{2,}', caseSensitive: false),
      (match) {
        final char = match.group(1)!;
        return 'aeiouAEIOUüÜöÖıİ'.contains(char)
            ? '$char$char'  // Sesli harfler için max 2 tekrar
            : char;         // Sessiz harfler için tekil
      },
    );
  }

  String _fixPunctuation(String text) {
    return text
        .replaceAll(RegExp(r'[.,]{2,}'), '.')
        .replaceAll(RegExp(r'[!]{2,}'), '!')
        .replaceAll(RegExp(r'[?]{2,}'), '?')
        .replaceAll(RegExp(r'\s+([.,!?;:])'), r'$1');
  }

  String _lastMinuteCheck(String text) {
    if (text.length < 3) return '';

    // Sadece noktalama işareti varsa boş döndür
    if (RegExp(r'^[^\w\s]+$').hasMatch(text)) return '';

    // Çok fazla sayı varsa kısalt
    final digits = RegExp(r'\d').allMatches(text).length;
    final ratio = text.isEmpty ? 0.0 : digits / text.length;
    if (ratio > 0.7) return 'sayısal veri';

    return text;
  }

  List<String> _chunkSmart(String text, {int maxLen = 600}) {
    final cleanText = text
        .replaceAll('\r', ' ')
        .replaceAll(RegExp(r' {2,}'), ' ')
        .trim();

    if (cleanText.length <= maxLen) return [cleanText];

    final sentences = _splitSentences(cleanText);
    final chunks = <String>[];

    var buf = StringBuffer();
    var currLen = 0;

    void flush() {
      if (currLen > 0) {
        chunks.add(buf.toString().trim());
        buf = StringBuffer();
        currLen = 0;
      }
    }

    for (final sentence in sentences) {
      if (sentence.length > maxLen) {
        // Çok uzun cümleyi kelimelere böl
        final wordChunks = _chunkByWords(sentence, maxLen);
        for (final chunk in wordChunks) {
          if (currLen + chunk.length + 1 > maxLen) flush();
          buf.write(chunk);
          buf.write(' ');
          currLen += chunk.length + 1;
        }
        continue;
      }

      if (currLen + sentence.length + 1 > maxLen) flush();
      buf.write(sentence);
      if (!sentence.endsWith('\n')) {
        buf.write(' ');
        currLen += sentence.length + 1;
      } else {
        currLen += sentence.length;
      }
    }

    flush();
    return chunks.where((chunk) => chunk.trim().isNotEmpty).toList();
  }

  List<String> _splitSentences(String text) {
    final regex = RegExp(r'(.+?(?:[\.!\?…]|\n|$))', dotAll: true);
    final sentences = <String>[];

    for (final match in regex.allMatches(text)) {
      final sentence = match.group(0)?.trim();
      if (sentence != null && sentence.isNotEmpty) {
        sentences.add(sentence);
      }
    }

    return sentences;
  }

  List<String> _chunkByWords(String text, int maxLen) {
    final words = text.split(RegExp(r'\s+'));
    final chunks = <String>[];

    var buf = StringBuffer();
    var currLen = 0;

    void flush() {
      if (currLen > 0) {
        chunks.add(buf.toString().trim());
        buf = StringBuffer();
        currLen = 0;
      }
    }

    for (final word in words) {
      if (currLen + word.length + 1 > maxLen) flush();
      buf.write(word);
      buf.write(' ');
      currLen += word.length + 1;
    }

    flush();
    return chunks;
  }

  // ---------- STT Metin İyileştirme ----------
  String _enhanceRecognizedText(String text) {
    if (text.trim().isEmpty) return text;

    String cleaned = text.toLowerCase().trim();

    // Yaygın hataları düzelt
    _commonFixes.forEach((wrong, correct) {
      cleaned = cleaned.replaceAll(
        RegExp(r'\b' + RegExp.escape(wrong) + r'\b', caseSensitive: false),
        correct,
      );
    });

    // Sayı kelimelerini düzelt
    _numberWords.forEach((word, number) {
      cleaned = cleaned.replaceAll(
        RegExp(r'\b' + RegExp.escape(word) + r'\b', caseSensitive: false),
        number,
      );
    });

    cleaned = _fixTimeExpressions(cleaned);
    cleaned = _addBasicPunctuation(cleaned);

    // İlk harfi büyüt
    if (cleaned.isNotEmpty) {
      cleaned = cleaned[0].toUpperCase() +
          (cleaned.length > 1 ? cleaned.substring(1) : '');
    }

    return cleaned;
  }

  String _fixTimeExpressions(String text) {
    final regex = RegExp(r'(\d{1,2})\s+(otuz|on|yirmi|elli|kırk)', caseSensitive: false);
    return text.replaceAllMapped(regex, (match) {
      final hour = match.group(1)!;
      final minuteWord = match.group(2)!.toLowerCase();

      const minuteMap = {
        'otuz': '30', 'on': '10', 'yirmi': '20', 'kırk': '40', 'elli': '50'
      };

      final minute = minuteMap[minuteWord] ?? '00';
      return '$hour:$minute';
    });
  }

  String _addBasicPunctuation(String text) {
    if (RegExp(r'^(ne|nasıl|neden|nerede|kim|hangi|kaç)', caseSensitive: false)
        .hasMatch(text)) {
      if (!text.endsWith('?')) {
        text += '?';
      }
    }
    return text;
  }

  // ---------- Utilities ----------
  void _updateStatus(String status) {
    debugPrint('VoiceService: $status');
    if (!_statusController.isClosed) {
      _statusController.add(status);
    }
  }

  // ---------- Test Metodları ----------
  Future<bool> testTts() async {
    try {
      await speak('Test mesajı');
      return true;
    } catch (e) {
      debugPrint('TTS test hatası: $e');
      return false;
    }
  }

  Future<bool> testStt() async {
    try {
      await startListening(timeout: const Duration(seconds: 5));
      await Future.delayed(const Duration(seconds: 2));
      await stopListening();
      return true;
    } catch (e) {
      debugPrint('STT test hatası: $e');
      return false;
    }
  }
}
