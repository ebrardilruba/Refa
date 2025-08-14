// lib/voice_bot.dart — Düzeltilmiş sürüm

import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import 'tts_service.dart';
import 'reminders.dart';
import 'health.dart';

/// ------------------------------------------------------------
///  NLP ve Intent tanımları
/// ------------------------------------------------------------
enum Intent { greet, today, time, date, add, list, delete, diet, profile, help, none }

class IntentMatch {
  final Intent intent;
  final double score;
  const IntentMatch(this.intent, this.score);
}

/// ---------- Geliştirilmiş Türkçe NLP Yardımcı Sınıfı ----------
class TurkishNLP {
  // Türkçe karakter dönüşümü - SADECE normalizasyon için kullanılacak
  static const Map<String, String> _charMap = {
    'ç': 'c', 'ğ': 'g', 'ı': 'i', 'İ': 'i', 'I': 'i',
    'ö': 'o', 'ş': 's', 'ü': 'u', 'Ç': 'c', 'Ğ': 'g',
    'Ö': 'o', 'Ş': 's', 'Ü': 'u'
  };

  // Genişletilmiş yazım hataları sözlüğü
  static const Map<String, String> _commonErrors = {
    // Temel yazım hataları
    'iyyim': 'iyiyim', 'iyyyim': 'iyiyim', 'iyyyyim': 'iyiyim', 'iyim': 'iyiyim',
    'çookk': 'çok', 'çoook': 'çok', 'çooook': 'çok', 'cok': 'çok', 'cokk': 'çok',
    'teşekür': 'teşekkür', 'tesekur': 'teşekkür', 'tesekkur': 'teşekkür',
    'nasilsin': 'nasılsın', 'nasilsın': 'nasılsın',
    'merhabaa': 'merhaba', 'mrb': 'merhaba',
    'slm': 'selam', 'selamm': 'selam',
    'tmm': 'tamam', 'tamamm': 'tamam', 'tm': 'tamam',
    'iyii': 'iyi',
    'kotü': 'kötü', 'kötu': 'kötü', 'kötüü': 'kötü', 'kotu': 'kötü',
    'yorgum': 'yorgun', 'yorgunn': 'yorgun',
    'halsizz': 'halsiz', 'halsiiz': 'halsiz',
    'bugun': 'bugün', 'bügün': 'bugün',
    'yarin': 'yarın', 'yarinn': 'yarın',
    
    // Komut kelimeleri
    'eklee': 'ekle', 'ekl': 'ekle',
    'sill': 'sil', 'siil': 'sil',
    'listee': 'liste', 'list': 'liste',
    'yardim': 'yardım', 'yardiim': 'yardım',
    'saatt': 'saat', 'saaat': 'saat',
    'tarihh': 'tarih', 'tariih': 'tarih',
    'ilac': 'ilaç', 'ilacc': 'ilaç',
    
    // Soru kelimeleri
    'kac': 'kaç', 'kacc': 'kaç',
    'nee': 'ne', 'neee': 'ne',
    'varr': 'var', 'vaar': 'var',
    'nasil': 'nasıl', 'nasiil': 'nasıl',
    'nedenn': 'neden', 'needen': 'neden',
    'nediir': 'nedir', 'nedirr': 'nedir',
    
    // Yemek ve sağlık
    'yemekk': 'yemek', 'yeemek': 'yemek',
    'aclik': 'açlık', 'aclikk': 'açlık',
    'saglik': 'sağlık', 'saglık': 'sağlık',
    'profiil': 'profil', 'profihl': 'profil',
    'tahliil': 'tahlil', 'tahlill': 'tahlil',
    
    // Zaman ifadeleri
    'simdi': 'şimdi', 'simdii': 'şimdi',
    'gunaydin': 'günaydın',
    'aksam': 'akşam', 'akssam': 'akşam',
    'ogle': 'öğle', 'oglee': 'öğle',
  };

  // Intent anahtar kelimeleri - Türkçe karakterli orijinal hallerini kullan
  static const Map<Intent, List<String>> _intentKeywords = {
    Intent.greet: [
      'merhaba', 'selam', 'günaydın', 'gunaydin', 'iyi', 'akşam', 'aksam', 
      'sabah', 'öğle', 'ogle', 'iyiyim', 'iyyim', 'nasılsın', 'nasilsin'
    ],
    Intent.today: [
      'bugün', 'bugun', 'program', 'plan', 'ilaç', 'ilac', 'hatırlatıcı', 
      'hatirlatici', 'alarm', 'ne', 'var', 'olacak', 'neler'
    ],
    Intent.time: [
      'saat', 'zaman', 'kaç', 'kac', 'şimdi', 'simdi', 'şu', 'su', 'an',
      'saati', 'zamanı'
    ],
    Intent.date: [
      'tarih', 'gün', 'gun', 'ay', 'yıl', 'yil', 'günlerden', 'gunlerden',
      'tarihi', 'hangi'
    ],
    Intent.add: [
      'ekle', 'kaydet', 'hatırlatıcı', 'hatirlatici', 'alarm', 'kur', 
      'eklee', 'kayıt', 'kayit', 'için', 'icin'
    ],
    Intent.list: [
      'liste', 'listele', 'göster', 'goster', 'kayıt', 'kayit', 'hepsi', 
      'tümü', 'tumu', 'neler', 'hangi'
    ],
    Intent.delete: [
      'sil', 'kaldır', 'kaldir', 'iptal', 'çıkar', 'cikar'
    ],
    Intent.diet: [
      'yemek', 'ye', 'yiyecek', 'beslenme', 'diyet', 'açlık', 'aclik', 
      'tok', 'doydum', 'yesem', 'içsem', 'icsem', 'aç', 'ac'
    ],
    Intent.profile: [
      'profil', 'tahlil', 'sağlık', 'saglik', 'nabız', 'nabiz', 'rapor',
      'durum', 'profili', 'sağlığım', 'sagligim'
    ],
    Intent.help: [
      'yardım', 'yardim', 'help', 'nasıl', 'nasil', 'ne', 'yapabilir', 
      'öğren', 'ogren', 'komut', 'bilgi'
    ]
  };

  // Normalizasyon - sadece karşılaştırma için
  static String normalize(String text) {
    var result = text.toLowerCase().trim();
    // Türkçe karakterleri sadeleştir (sadece karşılaştırma için)
    _charMap.forEach((k, v) => result = result.replaceAll(k, v));
    // Noktalama ve özel karakterleri temizle
    result = result.replaceAll(RegExp(r'[^\w\s]'), ' ');
    // Çoklu boşlukları tek boşluğa çevir
    result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
    return result;
  }

  // Yazım hatası düzeltme - ORİJİNAL Türkçe karakterleri KORU
  static String correctSpelling(String text) {
    final words = text.toLowerCase().split(' ');
    final correctedWords = <String>[];
    
    for (String word in words) {
      // Noktalama işaretlerini temizle ama Türkçe karakterleri KORU
      String cleanWord = word.replaceAll(RegExp(r"[^\w\sçğıöşüÇĞİÖŞÜ]", unicode: true), '');
      if (cleanWord.isEmpty) continue;
      
      // Önce direkt sözlükte var mı bak
      if (_commonErrors.containsKey(cleanWord)) {
        correctedWords.add(_commonErrors[cleanWord]!);
        continue;
      }
      
      // Tekrarlı karakterleri azalt ve tekrar bak
      String simplified = _removeRepeatedChars(cleanWord);
      if (_commonErrors.containsKey(simplified)) {
        correctedWords.add(_commonErrors[simplified]!);
        continue;
      }
      
      // Benzer kelime bul
      String closest = _findClosestWord(cleanWord);
      correctedWords.add(closest.isNotEmpty ? closest : cleanWord);
    }
    
    return correctedWords.join(' ');
  }

  static String _removeRepeatedChars(String word) {
    if (word.length < 2) return word;
    
    StringBuffer result = StringBuffer();
    result.write(word[0]);
    int consecutiveCount = 1;
    
    for (int i = 1; i < word.length; i++) {
      if (word[i] == word[i - 1]) {
        consecutiveCount++;
        // En fazla 2 tane aynı karakter bırak
        if (consecutiveCount <= 2) {
          result.write(word[i]);
        }
      } else {
        result.write(word[i]);
        consecutiveCount = 1;
      }
    }
    
    return result.toString();
  }

  static String _findClosestWord(String word) {
    String bestMatch = '';
    int bestDistance = word.length;
    
    for (String dictWord in _commonErrors.keys) {
      int distance = _levenshteinDistance(word, dictWord);
      if (distance < bestDistance && distance <= 2) {
        bestDistance = distance;
        bestMatch = dictWord;
      }
    }
    
    return _commonErrors[bestMatch] ?? word;
  }

  static int _levenshteinDistance(String s1, String s2) {
    if (s1.isEmpty) return s2.length;
    if (s2.isEmpty) return s1.length;

    List<List<int>> matrix = List.generate(
      s1.length + 1,
      (i) => List<int>.filled(s2.length + 1, 0),
    );

    for (int i = 0; i <= s1.length; i++) matrix[i][0] = i;
    for (int j = 0; j <= s2.length; j++) matrix[0][j] = j;

    for (int i = 1; i <= s1.length; i++) {
      for (int j = 1; j <= s2.length; j++) {
        int cost = s1[i - 1] == s2[j - 1] ? 0 : 1;
        matrix[i][j] = [
          matrix[i - 1][j] + 1,      // deletion
          matrix[i][j - 1] + 1,      // insertion
          matrix[i - 1][j - 1] + cost // substitution
        ].reduce((a, b) => a < b ? a : b);
      }
    }

    return matrix[s1.length][s2.length];
  }

  // Güçlendirilmiş phrase detection
  static IntentMatch? _detectSpecialPhrases(String normalizedText) {
    // BUGÜN programı soruları
    final todayPatterns = [
      RegExp(r'\bbug[uü]n\s+ne\s+var\b', unicode: true),
      RegExp(r'\bbug[uü]n\s+(program|plan)\b', unicode: true),
      RegExp(r'\bbug[uü]n\b.*\b(ilac|ilaç|hat[iı]rlatici|hatırlatıcı)\b', unicode: true),
      RegExp(r'\bbug[uü]n\b.*\bneler\b', unicode: true),
      RegExp(r'\bbug[uü]n\b.*\bolacak\b', unicode: true),
    ];
    
    for (final pattern in todayPatterns) {
      if (pattern.hasMatch(normalizedText)) {
        return const IntentMatch(Intent.today, 1.0);
      }
    }

    // SAAT kaç soruları
    final timePatterns = [
      RegExp(r'\bsaat\s+ka[cç]\b', unicode: true),
      RegExp(r'\bka[cç]\s+saat\b', unicode: true),
      RegExp(r'\b([şs]imdi|[şs]u\s+an)\b.*\bsaat\b', unicode: true),
      RegExp(r'\bzaman\s+ka[cç]\b', unicode: true),
    ];
    
    for (final pattern in timePatterns) {
      if (pattern.hasMatch(normalizedText)) {
        return const IntentMatch(Intent.time, 1.0);
      }
    }

    // TARİH soruları
    final datePatterns = [
      RegExp(r'\btarih\s+ne\b', unicode: true),
      RegExp(r'\bhangi\s+(g[uü]n|tarih)\b', unicode: true),
      RegExp(r'\bbug[uü]n\s+hangi\b', unicode: true),
    ];
    
    for (final pattern in datePatterns) {
      if (pattern.hasMatch(normalizedText)) {
        return const IntentMatch(Intent.date, 1.0);
      }
    }

    return null;
  }

  // Geliştirilmiş intent matching
  static IntentMatch matchIntent(String text) {
    // 1. Yazım hatalarını düzelt ama Türkçe karakterleri koru
    final corrected = correctSpelling(text);
    
    // 2. Normalizasyon (sadece karşılaştırma için)
    final normalized = normalize(corrected);
    final words = normalized.split(' ');
    final wordSet = words.toSet();

    // 3. Özel ifadeleri kontrol et
    final specialMatch = _detectSpecialPhrases(corrected.toLowerCase());
    if (specialMatch != null) return specialMatch;

    // 4. Genel anahtar kelime puanlaması
    final scores = <Intent, double>{};
    
    for (final intent in Intent.values) {
      if (intent == Intent.none) continue;
      
      final keywords = _intentKeywords[intent] ?? [];
      double score = 0;
      
      for (final keyword in keywords) {
        final normalizedKeyword = normalize(keyword);
        
        // Tam kelime eşleşmesi
        if (RegExp(r'\b' + RegExp.escape(normalizedKeyword) + r'\b').hasMatch(normalized)) {
          score += 1.0;
          continue;
        }
        
        // Fuzzy matching
        for (final word in wordSet) {
          final distance = _levenshteinDistance(word, normalizedKeyword);
          if (distance <= 1) {
            score += 0.8;
            break;
          } else if (word.length >= 3 && normalizedKeyword.length >= 3) {
            if (word.contains(normalizedKeyword) || normalizedKeyword.contains(word)) {
              score += 0.6;
              break;
            }
          }
        }
      }
      
      // Intent-specific bonuses
      if (intent == Intent.today && (wordSet.contains('bugun') || wordSet.contains('bugün'))) {
        score += 0.5;
      }
      
      // Normalize score
      final keywordCount = keywords.length.toDouble();
      scores[intent] = keywordCount > 0 ? score / keywordCount : 0;
    }

    if (scores.isEmpty) return const IntentMatch(Intent.none, 0);
    
    final best = scores.entries.reduce((a, b) => a.value > b.value ? a : b);
    return IntentMatch(best.key, best.value);
  }

  static String detectMood(String text) {
    const moodWords = {
      'yorgun': ['yorgun', 'bitkin', 'halsiz', 'keyifsiz', 'uykusuz', 'bezgin'],
      'mide': ['mide', 'bulantı', 'bulanti', 'şişkinlik', 'gaz', 'ishal', 'kabız', 'karın', 'karin'],
      'istahsız': ['isteksiz', 'iştahsız', 'istahsız', 'istah', 'canım', 'canim'],
      'iyi': ['iyi', 'mutlu', 'harika', 'enerjik', 'güzel', 'süper', 'mükemmel', 'keyifli']
    };
    
    final corrected = correctSpelling(text);
    final normalized = normalize(corrected);
    final counts = <String, int>{for (final k in moodWords.keys) k: 0};
    
    for (final mood in moodWords.keys) {
      for (final word in moodWords[mood]!) {
        final normalizedWord = normalize(word);
        if (normalized.contains(normalizedWord)) {
          counts[mood] = counts[mood]! + 1;
        }
      }
    }
    
    if (counts.values.every((c) => c == 0)) return 'nötr';
    return counts.entries.reduce((a, b) => a.value > b.value ? a : b).key;
  }

  static double similarity(String a, String b) {
    if (a == b) return 1.0;
    
    final normalizedA = normalize(a);
    final normalizedB = normalize(b);
    
    if (normalizedA == normalizedB) return 0.9;
    
    final maxLength = a.length > b.length ? a.length : b.length;
    if (maxLength == 0) return 1.0;
    
    final distance = _levenshteinDistance(normalizedA, normalizedB);
    return 1.0 - (distance / maxLength);
  }
}

/// ------------------------------------------------------------
///  Mesaj modeli
/// ------------------------------------------------------------
class ChatMessage {
  final String role; // 'user' | 'bot'
  final String text;
  ChatMessage(this.role, this.text);
}

/// ------------------------------------------------------------
///  VoiceBotPage - Geri kalan kod aynı
/// ------------------------------------------------------------
class VoiceBotPage extends StatefulWidget {
  const VoiceBotPage({super.key});
  @override
  State<VoiceBotPage> createState() => _VoiceBotPageState();
}

class _VoiceBotPageState extends State<VoiceBotPage> {
  final _input = TextEditingController();
  final _scroll = ScrollController();
  final _messages = <ChatMessage>[];

  // Servis referansı
  EnhancedVoiceService? _voice;

  // UI durumları
  bool _isListening = false;
  String _pendingRecognized = '';

  // Adım adım ekleme durumu
  String? _pendingAddName;
  String? _pendingAddTime;

  // Stream subscription'ları
  StreamSubscription<bool>? _listeningSubscription;
  StreamSubscription<String>? _recognizedSubscription;

  // STT otomatik gönder kontrolü
  String _lastAutoSent = '';

  @override
  void initState() {
    super.initState();
    _initVoiceService();
  }

  Future<void> _initVoiceService() async {
    try {
      _voice = EnhancedVoiceService.instance;
      await _voice!.init();

      _listeningSubscription = _voice!.listeningStream.listen((isListening) {
        if (!mounted) return;
        setState(() => _isListening = isListening);
      });

      _recognizedSubscription = _voice!.recognizedWordsStream.listen((words) {
        if (!mounted) return;
        final w = words.trim();
        setState(() => _pendingRecognized = w);

        // input doluyken (kullanıcı yazarken) otomatik gönderME
        final isManualTyping = _input.text.trim().isNotEmpty;

        final canAutoSend = !(_voice?.isListening ?? false) &&
            w.isNotEmpty &&
            !isManualTyping &&
            w != _lastAutoSent;

        if (canAutoSend) {
          _lastAutoSent = w;
          _input.text = w;
          _input.selection = TextSelection.collapsed(offset: _input.text.length);
          _handleSend();
        }
      });

      _seedWelcome();
    } catch (e) {
      debugPrint('Voice service init hatası: $e');
      _seedWelcome();
    }
  }

  void _seedWelcome() {
    const help = '''Merhaba! Ben Refa. Bana şöyle şeyler yazabilirsin:
• "Bugün ne var?" veya "bugün program"
• "Saat kaç?" / "Tarih ne?"
• "14:30'da Parol ekle" ya da "Parol için saat 14.30"
• "Hatırlatıcı ekle" (eksik bilgiyi sorarım)
• "Kendimi yorgun hissediyorum, ne yesem?" veya "iyyym ne yesem?"
• "Tahlillerime bak"

Yazım hatalarını anlayabilirim ve Türkçe karakterleri doğru kullanırım!''';
    _pushBot(help, speak: false);
  }

  Future<void> _speak(String text) async {
    try { await _voice?.speak(text); } catch (e) { debugPrint('TTS hatası: $e'); }
  }

  void _pushUser(String text) {
    if (!mounted) return;
    setState(() => _messages.add(ChatMessage('user', text)));
    _autoScroll();
  }

  void _pushBot(String text, {bool speak = true}) async {
    if (!mounted) return;
    setState(() => _messages.add(ChatMessage('bot', text)));
    _autoScroll();
    if (speak && _voice != null && !_isListening) {
      try { await _speak(text); } catch (e) { debugPrint('Konuşma hatası: $e'); }
    }
  }

  void _autoScroll() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients && mounted) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  // ---------- Yardımcılar ----------
  String? _extractTime(String text) {
    final re = RegExp(r'(\d{1,2})[:\.](\d{2})');
    final m = re.firstMatch(text);
    if (m == null) return null;
    final h = int.parse(m.group(1)!);
    final mm = int.parse(m.group(2)!);
    if (h < 0 || h > 23 || mm < 0 || mm > 59) return null;
    return '${h.toString().padLeft(2, '0')}:${mm.toString().padLeft(2, '0')}';
  }

  String? _extractName(String text) {
    final corrected = TurkishNLP.correctSpelling(text);
    var t = TurkishNLP.normalize(corrected);
    t = t.replaceAll(RegExp(r'(\d{1,2})[:\.](\d{2})'), '');
    t = t.replaceAll(RegExp(r'(ekle|hatırlatıcı|hatirlat|ilac|ilaç|saat|kur)', unicode: true), '');
    t = t.replaceAll(RegExp(r"[^a-zA-Z0-9çğıöşüÇĞİÖŞÜ\s\-']"), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return null;
    return t
        .split(' ')
        .map((w) => w.isEmpty ? w : w[0].toUpperCase() + (w.length > 1 ? w.substring(1) : ''))
        .join(' ');
  }

  String _todayText() {
    final items = ReminderStore.all()
        .where((r) => r.active)
        .expand((r) => r.times.map((tm) => (r.title, tm)))
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    if (items.isEmpty) return 'Bugün için ilaç kaydı yok.';
    final b = StringBuffer('Bugün almanız gereken ilaçlar: ');
    for (final (title, time) in items) { b.write('$time saatinde $title. '); }
    return b.toString();
  }

  String _timeNow() {
    final now = DateTime.now();
    final hh = now.hour.toString().padLeft(2, '0');
    final mm = now.minute.toString().padLeft(2, '0');
    return '$hh:$mm';
  }

  List<String> _mealIdeas({required String mood}) {
    final p = HealthStore.profile;
    var ideas = <String>[
      'Tavuklu sebze çorbası + yoğurt',
      'Zeytinyağlı sebze (kabak/patlıcan) + bulgur pilavı',
      'Izgara balık + salata + ayran',
      'Mercimek köftesi + cacık',
      'Yulaf ezmesi + yoğurt + meyve',
      'Fırında sebzeli köfte (az tuzlu)',
      'Tavuk sote + haşlanmış brokoli',
      'Menemen (az yağ) + tam buğday ekmek',
      'Zeytinyağlı nohut + salata',
      'Sebzeli omlet + ayran',
    ];

    if (mood == 'mide') {
      ideas = [
        'Pirinç lapası + yoğurt',
        'Tavuk suyu çorba (hafif yağlı)',
        'Haşlanmış patates + ayran',
        'Yoğurt + galeta/kraker',
        'Muz + yoğurt (az miktar)',
      ];
    } else if (mood == 'istahsız') {
      ideas = [
        'Mercimek çorbası + yoğurt',
        'Menemen (az yağ) + tost ekmeği',
        'Sebzeli omlet + ayran',
        'Meyveli yoğurt + yulaf (küçük porsiyon)',
      ];
    } else if (mood == 'yorgun') {
      ideas.insertAll(0, [
        'Izgara hindi/tavuk + bulgur + salata',
        'Kuru fasulye (az yağ) + yoğurt',
        'Balık + tam buğday makarna (az) + salata',
        'Humus + kepekli pita + cacık',
      ]);
    }

    if (p.diabetes) {
      ideas = ideas.where((s) => !s.contains('pilav') && !s.contains('makarna') && !s.contains('lapası')).toList();
      ideas.add('Salata + lor peyniri + haşlanmış yumurta');
    }
    if (p.highCholesterol) {
      ideas = ideas.map((s) => s.replaceAll('köfte', 'ızgara köfte (yağsız)')).toList();
      ideas.removeWhere((s) => s.contains('kızartma'));
    }
    if (p.kidneyDisease) {
      ideas = ideas.where((s) => !s.contains('nohut') && !s.contains('fasulye')).toList();
      ideas = ideas.map((s) => s.replaceAll('salata', 'az tuzlu salata')).toList();
    }
    if (p.anemia) {
      ideas.insertAll(0, [
        'Kırmızı et sote (az yağ) + ıspanak',
        'Mercimek çorbası + maydanozlu salata',
        'Yumurtalı ıspanak + ayran',
      ]);
    }
    if (p.vitaminDLow) {
      ideas.insertAll(0, [
        'Somon/uskumru + salata',
        'Yumurta + yoğurt + tam buğday ekmek',
      ]);
    }

    final seen = <String>{};
    final out = <String>[];
    for (final s in ideas) { if (seen.add(s)) out.add(s); }
    if (out.length > 6) out.removeRange(6, out.length);
    return out;
  }

  // ---------- Mesaj işleme ----------
  Future<void> _handleSend() async {
    final raw = _input.text;
    final text = raw.trim();
    if (text.isEmpty) return;

    // Kullanıcı manuel gönderdi → bir sonraki STT otomatiğine izin ver
    _lastAutoSent = '';

    _input.clear();
    _pendingRecognized = '';
    _pushUser(text);

    try {
      // Debug: Girdi metnini göster
      debugPrint('Girdi metni: "$text"');
      
      final correctedText = TurkishNLP.correctSpelling(text);
      debugPrint('Düzeltilmiş metin: "$correctedText"');
      
      final intentMatch = TurkishNLP.matchIntent(correctedText);
      debugPrint('Intent: ${intentMatch.intent}, Score: ${intentMatch.score}');

      // Bekleyen ekleme akışı
      if (_pendingAddName != null && _pendingAddTime == null) {
        final time = _extractTime(correctedText);
        if (time == null) { 
          _pushBot('Saati HH:mm veya HH.mm biçiminde yazın. Örnek: 14:30 veya 14.30'); 
          return; 
        }
        _pendingAddTime = time;
        final r = await ReminderStore.add(_pendingAddName!, [_pendingAddTime!]);
        _pendingAddName = null; 
        _pendingAddTime = null;
        _pushBot('Tamam, "${r.title}" için $time saatine hatırlatıcı ekledim.');
        return;
      }
      
      if (_pendingAddName == null && _pendingAddTime != null) {
        final name = _extractName(correctedText) ?? correctedText.trim();
        if (name.isEmpty) { 
          _pushBot('İlaç adını yazın lütfen.'); 
          return; 
        }
        final r = await ReminderStore.add(name, [_pendingAddTime!]);
        _pendingAddName = null; 
        _pendingAddTime = null;
        _pushBot('Tamam, "$name" için ${r.times.first} saatine hatırlatıcı ekledim.');
        return;
      }

      // Intent tabanlı işleme (eşik düşürüldü)
      if (intentMatch.score >= 0.3) {
        await _handleIntent(intentMatch.intent, correctedText);
        return;
      }

      // Fallback
      await _handleFallback(correctedText);
    } catch (e) {
      debugPrint('Mesaj işleme hatası: $e');
      _pushBot('Bir hata oluştu. Lütfen tekrar deneyin.');
    }
  }

  Future<void> _handleIntent(Intent intent, String correctedText) async {
    switch (intent) {
      case Intent.greet:
        _pushBot('Merhaba! Nasıl yardımcı olabilirim? Size bugünkü programınızı okuyayım mı?');
        break;
        
      case Intent.today:
        _pushBot(_todayText());
        break;
        
      case Intent.time:
        final currentTime = _timeNow();
        _pushBot('Saat şu anda $currentTime');
        break;
        
      case Intent.date:
        final now = DateTime.now();
        const months = [
          'Ocak', 'Şubat', 'Mart', 'Nisan', 'Mayıs', 'Haziran',
          'Temmuz', 'Ağustos', 'Eylül', 'Ekim', 'Kasım', 'Aralık'
        ];
        const weekdays = [
          'Pazartesi', 'Salı', 'Çarşamba', 'Perşembe', 'Cuma', 'Cumartesi', 'Pazar'
        ];
        final weekday = weekdays[now.weekday - 1];
        _pushBot('Bugün $weekday, ${now.day} ${months[now.month - 1]} ${now.year}');
        break;
        
      case Intent.profile:
        final profileInfo = HealthStore.profile.toString();
        _pushBot('Kayıtlı sağlık profiliniz:\n$profileInfo\n\nGüncellemek için: Ayarlar → Sağlık Profili bölümünü kullanın.');
        break;
        
      case Intent.help:
        const helpText = '''Size şu konularda yardımcı olabilirim:

📋 "Bugün ne var?" - Günlük ilaç programınızı okurum
⏰ "Saat kaç?" - Şimdiki saati söylerim  
📅 "Tarih ne?" - Bugünün tarihini söylerim
➕ "14:30'da Parol ekle" - Yeni hatırlatıcı eklerim
📝 "Liste" - Tüm hatırlatıcıları gösteririm
🗑️ "Parol'u sil" - Hatırlatıcı silerim
🍽️ "Yorgunum ne yesem?" - Beslenme önerisi veririm
📊 "Tahlillerime bak" - Sağlık profilinizi gösteririm

Yazım hatalarını anlayabilirim ve Türkçe karakterleri doğru kullanırım!''';
        _pushBot(helpText);
        break;
        
      case Intent.diet:
        await _handleDietAdvice(correctedText);
        break;
        
      case Intent.add:
        await _handleAddReminder(correctedText);
        break;
        
      case Intent.list:
        await _handleListReminders();
        break;
        
      case Intent.delete:
        await _handleDeleteReminder(correctedText);
        break;
        
      case Intent.none:
        await _handleFallback(correctedText);
        break;
    }
  }

  Future<void> _handleDietAdvice(String correctedText) async {
    final mood = TurkishNLP.detectMood(correctedText);
    final ideas = _mealIdeas(mood: mood);
    final p = HealthStore.profile;
    
    final warnings = <String>[];
    if (p.diabetes) warnings.add('şeker hastalığı için basit karbonhidratları kısıtlayın');
    if (p.highCholesterol) warnings.add('kolesterol için doymuş yağ ve kızartmalardan kaçının');
    if (p.kidneyDisease) warnings.add('böbrek hastalığı için tuz ve potasyuma dikkat edin');
    if (p.anemia) warnings.add('anemi için demir açısından zengin besinleri tercih edin');
    if (p.vitaminDLow) warnings.add('D vitamini eksikliği için balık ve yumurta tüketin');
    
    final extraWarning = warnings.isEmpty ? '' : '\n\n⚠️ Sağlık durumunuz için notlar:\n${warnings.map((w) => '• $w').join('\n')}';

    final moodMessage = mood == 'nötr' 
        ? 'Size şu yemek önerilerini verebilirim:'
        : 'Kendinizi $mood hissediyorsunuz, size şu öneriler iyi gelir:';

    final response = StringBuffer()
      ..writeln(moodMessage)
      ..writeln()
      ..writeAll(ideas.map((idea) => '🍽️ $idea'), '\n')
      ..write(extraWarning)
      ..writeln('\n\n📋 Bu öneriler genel bilgi amaçlıdır, tıbbi tavsiye yerine geçmez.');
    
    _pushBot(response.toString());
  }

  Future<void> _handleAddReminder(String correctedText) async {
    final time = _extractTime(correctedText);
    final name = _extractName(correctedText);
    
    if (time != null && name != null) {
      final r = await ReminderStore.add(name, [time]);
      _pushBot('✅ Tamam! "$name" için $time saatine hatırlatıcı ekledim.');
    } else if (time != null && name == null) {
      _pendingAddTime = time; 
      _pendingAddName = null;
      _pushBot('⏰ $time saati için hangi ilacın hatırlatıcısını ekleyeyim?');
    } else if (time == null && name != null) {
      _pendingAddName = name; 
      _pendingAddTime = null;
      _pushBot('💊 "$name" için saat kaçta hatırlatıcı ekleyeyim? (Örnek: 14:30)');
    } else {
      _pendingAddName = null; 
      _pendingAddTime = null;
      _pushBot('📝 Hangi ilaç ve saat kaçta? Örnek: "14:30\'da Parol ekle" veya "Aspirin için 21.15"');
    }
  }

  Future<void> _handleListReminders() async {
    final reminders = ReminderStore.all();
    if (reminders.isEmpty) {
      _pushBot('📋 Henüz hiç hatırlatıcı kaydınız yok.');
    } else {
      final activeReminders = reminders.where((r) => r.active).toList();
      final inactiveReminders = reminders.where((r) => !r.active).toList();
      
      final response = StringBuffer('📋 Hatırlatıcı listesi:\n\n');
      
      if (activeReminders.isNotEmpty) {
        response.writeln('✅ Aktif hatırlatıcılar:');
        for (final r in activeReminders) {
          response.writeln('💊 ${r.title}: ${r.times.join(", ")}');
        }
      }
      
      if (inactiveReminders.isNotEmpty) {
        response.writeln('\n⏸️ Pasif hatırlatıcılar:');
        for (final r in inactiveReminders) {
          response.writeln('💊 ${r.title}: ${r.times.join(", ")}');
        }
      }
      
      _pushBot(response.toString());
    }
  }

  Future<void> _handleDeleteReminder(String correctedText) async {
    // "sil" kelimesinden sonrasını al
    var nameToDelete = correctedText;
    if (nameToDelete.contains('sil')) {
      final parts = nameToDelete.split('sil');
      if (parts.length > 1) {
        nameToDelete = parts.last.trim();
      }
    }
    
    final name = _extractName(nameToDelete) ?? nameToDelete.trim();
    if (name.isEmpty) {
      _pushBot('🗑️ Hangi hatırlatıcıyı silmek istiyorsunuz? Örnek: "Parol sil"');
      return;
    }
    
    final allReminders = ReminderStore.all();
    final matchingReminders = allReminders.where((r) =>
      TurkishNLP.similarity(r.title.toLowerCase(), name.toLowerCase()) > 0.6
    ).toList();

    if (matchingReminders.isEmpty) {
      _pushBot('❌ "$name" adında bir hatırlatıcı bulamadım. Listemi kontrol etmek ister misiniz?');
    } else if (matchingReminders.length == 1) {
      await ReminderStore.remove(matchingReminders.first.id);
      _pushBot('✅ "${matchingReminders.first.title}" hatırlatıcısını sildim.');
    } else {
      // Birden fazla benzer isim varsa
      final names = matchingReminders.map((r) => r.title).join(', ');
      _pushBot('🤔 Birden fazla benzer hatırlatıcı buldum: $names. Hangisini silmek istiyorsunuz?');
    }
  }

  Future<void> _handleFallback(String correctedText) async {
    final normalized = TurkishNLP.normalize(correctedText);
    
    // Yemek ile ilgili kelimeler varsa diet advice'a yönlendir
    if (normalized.contains('yemek') || normalized.contains('ye') ||
        normalized.contains('aclik') || normalized.contains('acım') ||
        normalized.contains('tok') || normalized.contains('yesem') ||
        normalized.contains('icsem')) {
      await _handleDietAdvice(correctedText);
      return;
    }

    // Zaman ile ilgili sorular
    if (normalized.contains('zaman') || normalized.contains('vakit')) {
      final currentTime = _timeNow();
      _pushBot('⏰ Şu anda saat $currentTime');
      return;
    }

    // Genel fallback
    final suggestions = [
      '💬 "Bugün ne var?" - bugünkü ilaç programınızı listeler',
      '⏰ "Saat kaç?" - şimdiki saati söyler',
      '➕ "14:30\'da Parol ekle" - yeni hatırlatıcı ekler',
      '🍽️ "Yorgunum ne yesem?" - beslenme önerisi verir',
      '📊 "Tahlillerime bak" - sağlık profilinizi gösterir',
      '❓ "Yardım" - tüm komutları listeler'
    ];
    
    final randomSuggestions = (suggestions..shuffle()).take(3).toList();
    
    _pushBot('''🤔 Bu komutu tam anlayamadım. Yazım hatası olabilir mi?

Şu komutları deneyebilirsiniz:
${randomSuggestions.map((s) => s).join('\n')}

"Yardım" yazarak tüm komutları görebilirsiniz.''');
  }

  @override
  void dispose() {
    _listeningSubscription?.cancel();
    _recognizedSubscription?.cancel();
    _input.dispose();
    _scroll.dispose();
    _voice?.stopListening();
    _voice?.stopSpeaking();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Arkaplan gradyanı
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft, 
                end: Alignment.bottomRight,
                colors: [Color(0xFF334155), Color(0xFF1E3A8A), Color(0xFF1E40AF)],
              ),
            ),
          ),
          
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const _GlassHeaderVoice(),
                  const SizedBox(height: 24),
                  
                  const Text(
                    'Sesli Bot',
                    style: TextStyle(
                      color: Colors.white, 
                      fontSize: 32, 
                      fontWeight: FontWeight.bold
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    _isListening 
                        ? '🎤 Dinliyorum… konuşabilirsiniz'
                        : '✨ Yazın, ben konuşayım • Türkçe akıllı anlama',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8), 
                      fontSize: 16
                    ),
                  ),
                  
                  const SizedBox(height: 16),

                  // Mesaj paneli (glass effect)
                  Expanded(
                    child: _GlassPanel(
                      child: ListView.builder(
                        controller: _scroll,
                        padding: const EdgeInsets.all(12),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final message = _messages[index];
                          final isUser = message.role == 'user';
                          final bubbleColor = isUser
                              ? Colors.white.withOpacity(0.14)
                              : Colors.white.withOpacity(0.10);

                          return Align(
                            alignment: isUser 
                                ? Alignment.centerRight 
                                : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.symmetric(vertical: 4),
                              padding: const EdgeInsets.symmetric(
                                vertical: 10, 
                                horizontal: 12
                              ),
                              decoration: BoxDecoration(
                                color: bubbleColor,
                                borderRadius: BorderRadius.circular(14),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.25)
                                ),
                              ),
                              constraints: const BoxConstraints(maxWidth: 320),
                              child: Text(
                                message.text,
                                style: const TextStyle(
                                  color: Colors.white, 
                                  fontSize: 15
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),

                  const SizedBox(height: 12),

                  // Girdi çubuğu
                  _InputBar(
                    controller: _input,
                    isListening: _isListening,
                    hint: _isListening && _pendingRecognized.isNotEmpty
                        ? _pendingRecognized
                        : 'Yazım hatasıyla bile yazabilirsiniz... (örn: iyyym, kac saat)',
                    onMicTap: () async {
                      try {
                        if (_isListening) {
                          await _voice?.stopListening();
                        } else {
                          await _voice?.startListening();
                        }
                      } catch (e) {
                        debugPrint('Mikrofon hatası: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(content: Text('Mikrofon hatası: $e')),
                          );
                        }
                      }
                    },
                    onStopTts: () async {
                      try {
                        await _voice?.stopSpeaking();
                      } catch (e) {
                        debugPrint('TTS durdurma hatası: $e');
                      }
                    },
                    onSend: _handleSend,
                  ),
                ],
              ),
            ),
          ),

          // Home indicator
          Positioned(
            bottom: 8, 
            left: 0, 
            right: 0,
            child: Center(
              child: Container(
                width: 144, 
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ------------------------------------------------------------
///  Glass Effect UI Bileşenleri
/// ------------------------------------------------------------
class _GlassHeaderVoice extends StatelessWidget {
  const _GlassHeaderVoice();

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: Colors.white.withOpacity(0.30), 
              width: 1
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26, 
                blurRadius: 12, 
                offset: Offset(0, 6)
              )
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40, 
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF8B5CF6),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26, 
                      blurRadius: 8, 
                      offset: Offset(0, 4)
                    )
                  ],
                ),
                child: const Icon(Icons.mic, color: Colors.white, size: 20),
              ),
              
              const SizedBox(width: 12),
              
              const Expanded(
                child: Text(
                  'Akıllı Sesli Bot',
                  style: TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.w700, 
                    fontSize: 16
                  ),
                ),
              ),
              
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20), 
                  borderRadius: BorderRadius.circular(12)
                ),
                child: const Text(
                  'STT+TTS',
                  style: TextStyle(
                    color: Colors.white, 
                    fontWeight: FontWeight.w700, 
                    fontSize: 12
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

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.12),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.25)),
          ),
          child: child,
        ),
      ),
    );
  }
}

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final String hint;
  final bool isListening;
  final VoidCallback onMicTap;
  final VoidCallback onStopTts;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.hint,
    required this.isListening,
    required this.onMicTap,
    required this.onStopTts,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.16),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(0.28)),
          ),
          child: Row(
            children: [
              IconButton(
                tooltip: isListening ? 'Dinlemeyi durdur' : 'Mikrofonu aç',
                icon: Icon(
                  isListening ? Icons.stop_circle : Icons.mic, 
                  color: Colors.white
                ),
                onPressed: onMicTap,
              ),
              
              const SizedBox(width: 6),
              
              Expanded(
                child: TextField(
                  controller: controller,
                  minLines: 1,
                  maxLines: 4,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: hint,
                    hintStyle: TextStyle(color: Colors.white.withOpacity(0.8)),
                    border: InputBorder.none,
                    prefixIcon: const Icon(Icons.smart_toy, color: Colors.white),
                  ),
                ),
              ),
              
              const SizedBox(width: 8),
              
              IconButton(
                tooltip: 'Konuşmayı durdur',
                icon: const Icon(Icons.volume_off, color: Colors.white),
                onPressed: onStopTts,
              ),
              
              const SizedBox(width: 4),
              
              FilledButton.icon(
                onPressed: onSend,
                icon: const Icon(Icons.send),
                label: const Text('Gönder'),
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFF8B5CF6),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}