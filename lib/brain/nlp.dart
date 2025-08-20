// lib/brain/nlp.dart
// Türkçe odaklı NLP yardımcıları: normalizasyon, imla düzeltme,
// intent tespiti, varlık (saat/isim) çıkarımı.

import 'dart:math';

enum Intent {
  greet, today, time, date, add, list, delete, diet, profile, help, thanks, none
}

class IntentMatch {
  final Intent intent;
  final double score;
  const IntentMatch(this.intent, this.score);
}

class Entities {
  final String? time24;   // "HH:mm"
  final String? name;     // örn. "Parol"
  const Entities({this.time24, this.name});

  Entities copyWith({String? time24, String? name}) =>
      Entities(time24: time24 ?? this.time24, name: name ?? this.name);

  Map<String, String> toMap() =>
      {if (time24 != null) 'time': time24!, if (name != null) 'name': name!};
}

/// ------------------------------------------------------------
///  Normalizasyon + İmla düzeltme
/// ------------------------------------------------------------
class _Maps {
  // Karakter sadeleştirme (SADECE karşılaştırma için)
  static const Map<String, String> turkishToAscii = {
    'ç': 'c', 'ğ': 'g', 'ı': 'i', 'i̇': 'i', 'İ': 'i', 'I': 'i',
    'ö': 'o', 'ş': 's', 'ü': 'u', 'Ç': 'c', 'Ğ': 'g',
    'Ö': 'o', 'Ş': 's', 'Ü': 'u'
  };

  // Çok geniş kısaltma/argo + yazım hataları (DUPLICATE KEY YOK!)
  static const Map<String, String> corrections = <String, String>{
    // Selamlaşma / teşekkür / vedalaşma
    'mrb': 'merhaba',
    'slm': 'selam',
    'sa': 'selam',
    's.a': 'selam',
    'as': 'aleyküm selam',
    'a.s': 'aleyküm selam',
    'nbr': 'naber',
    'nbrs': 'naber',
    'nbr?': 'naber',
    'tmm': 'tamam',
    'tm': 'tamam',
    'okey': 'ok',
    'okeyy': 'ok',
    'oky': 'ok',
    'ok': 'tamam',
    'tsk': 'teşekkür',
    'tşk': 'teşekkür',
    'tesekur': 'teşekkür',
    'tesekkur': 'teşekkür',
    'tesekkür': 'teşekkür',
    'saol': 'sağ ol',
    'sagol': 'sağ ol',
    'sagolun': 'sağ olun',
    'sagolasin': 'sağ olasın',
    'eyw': 'eyvallah',
    'eywla': 'eyvallah',
    'gorusuruz': 'görüşürüz', // ← sadece bir kez

    // Duygu / durum kısa yazımları
    'iyiyim': 'iyiyim',
    'iyim': 'iyiyim',
    'iyyim': 'iyiyim',
    'ii': 'iyi',
    'kotu': 'kötü',
    'kötuyum': 'kötüyüm', // ← sadece bir kez
    'cok': 'çok',
    'coook': 'çok',
    'çoook': 'çok',
    'cooook': 'çok',
    'halsizim': 'halsizim',
    'yorgunum': 'yorgunum',

    // Zaman / komut kelimeleri
    'saatkac': 'saat kaç',
    'kackac': 'saat kaç',
    'tarihne': 'tarih ne',
    'hatirlatici': 'hatırlatıcı',
    'hatirlat': 'hatırlat',
    'eklee': 'ekle',
    'silin': 'sil',
    'sill': 'sil',
    'listele': 'liste',
    'goster': 'göster',
    'yemekne': 'yemek ne',
    'neyesem': 'ne yesem',
    'diyet': 'diyet',
    'beslenme': 'beslenme',

    // Harf atlamaları / ses benzerlikleri
    'meraba': 'merhaba',
    'gunaydin': 'günaydın',
    'yarin': 'yarın',
    'bugun': 'bugün',
    'oglen': 'öğlen',
    'aksam': 'akşam',
    'sabahleyin': 'sabah',
  };
}

class TextTools {
  /// Türkçe karakterleri KORUYARAK normalize et (karşılaştırma için)
  static String normalize(String input) {
    var s = input.toLowerCase().trim();
    s = s.replaceAll(RegExp(r'[^\w\sçğıöşüÇĞİÖŞÜ:]', unicode: true), ' ');
    s = s.replaceAll(RegExp(r'\s+'), ' ').trim();
    return s;
  }

  /// Karşılaştırma için ASCII’leştir (ç→c vb.)
  static String toAscii(String input) {
    var s = input;
    _Maps.turkishToAscii.forEach((k, v) => s = s.replaceAll(k, v));
    return s;
  }

  /// Fazla harf tekrarı → en fazla 2’ye indir (çoook → ço ok → çok)
  static String squeezeRepeats(String s) {
    if (s.length < 3) return s;
    final b = StringBuffer()..write(s[0]);
    int run = 1;
    for (var i = 1; i < s.length; i++) {
      if (s[i] == s[i - 1]) {
        run++;
        if (run <= 2) b.write(s[i]);
      } else {
        run = 1;
        b.write(s[i]);
      }
    }
    return b.toString().replaceAll('oo', 'o'); // min düzeltme
  }

  /// Geniş sözlük + tekrar sıkıştırma + küçük düzeltmeler
  static String correctSpelling(String text) {
    var s = squeezeRepeats(text.toLowerCase());
    final words = s.split(RegExp(r'\s+'));
    final out = <String>[];
    for (final w in words) {
      final clean = w.replaceAll(RegExp(r"[^\wçğıöşü]", unicode: true), '');
      if (clean.isEmpty) continue;
      out.add(_Maps.corrections[clean] ?? clean);
    }
    return out.join(' ');
  }

  /// Levenshtein
  static int levenshtein(String a, String b) {
    if (a == b) return 0;
    if (a.isEmpty) return b.length;
    if (b.isEmpty) return a.length;
    final dp = List.generate(a.length + 1, (_) => List.filled(b.length + 1, 0));
    for (var i = 0; i <= a.length; i++) dp[i][0] = i;
    for (var j = 0; j <= b.length; j++) dp[0][j] = j;
    for (var i = 1; i <= a.length; i++) {
      for (var j = 1; j <= b.length; j++) {
        final cost = a[i - 1] == b[j - 1] ? 0 : 1;
        dp[i][j] = min(
          min(dp[i - 1][j] + 1, dp[i][j - 1] + 1),
          dp[i - 1][j - 1] + cost,
        );
      }
    }
    return dp[a.length][b.length];
  }

  static double sim(String a, String b) {
    final A = toAscii(normalize(a));
    final B = toAscii(normalize(b));
    final d = levenshtein(A, B);
    final int m = max(A.length, B.length).clamp(1, 1 << 30) as int;
    return 1 - d / m;
  }
}

/// ------------------------------------------------------------
///  Intent tespiti + varlık çıkarımı
/// ------------------------------------------------------------
class TurkishNLP {
  // Intent anahtar kelimeleri (ASCII yedekleri de eşleşir)
  static final Map<Intent, List<String>> _keywords = {
    Intent.greet: [
      'merhaba', 'selam', 'günaydın', 'iyi akşamlar', 'iyi günler',
      'nasılsın', 'naber', 'sa', 'aleykum selam', 'selamun aleykum'
    ],
    Intent.thanks: [
      'teşekkür', 'sağ ol', 'sağ olun', 'eyvallah', 'var ol'
    ],
    Intent.today: ['bugün', 'program', 'plan', 'neler var', 'hatırlatıcı', 'ilaç'],
    Intent.time: ['saat kaç', 'şu an saat', 'zaman', 'kaç'],
    Intent.date: ['tarih', 'hangi gün', 'günlerden'],
    Intent.add: ['ekle', 'hatırlat', 'alarm kur', 'kur'],
    Intent.list: ['liste', 'göster', 'hepsi', 'neler'],
    Intent.delete: ['sil', 'kaldır', 'iptal'],
    Intent.diet: ['ne yesem', 'yemek', 'diyet', 'aciktim', 'açım', 'tokum', 'beslenme'],
    Intent.profile: ['profil', 'tahlil', 'sağlık', 'rapor'],
    Intent.help: ['yardım', 'ne yapabilirsin', 'komut', 'nasıl kullanırım'],
  };

  static final RegExp _reThanks = RegExp(
    r'\b(saol|sağ ol|sağol|t(e|e?ş)ekkür|eyvallah)\b',
    caseSensitive: false,
    unicode: true,
  );

  /// Ana analiz:
  /// - imla düzelt
  /// - niyet skoru
  /// - saat/isim çıkar
  static ({IntentMatch match, Entities entities, String corrected}) analyze(String input) {
    final corrected = TextTools.correctSpelling(input);
    final norm = TextTools.normalize(corrected);
    final ascii = TextTools.toAscii(norm);

    // Özel kalıplar (yüksek güven)
    final special = _detectSpecial(ascii);
    if (special != null) {
      final ents = _extractEntities(corrected);
      return (match: IntentMatch(special, 0.99), entities: ents, corrected: corrected);
    }

    // Genel anahtar kelime puanı
    final Map<Intent, double> scores = { for (final i in Intent.values) i: 0.0 };
    for (final intent in _keywords.keys) {
      for (final kw in _keywords[intent]!) {
        final akw = TextTools.toAscii(TextTools.normalize(kw));
        // tam kelime veya yüksek benzerlik
        if (RegExp(r'\b' + RegExp.escape(akw) + r'\b').hasMatch(ascii)) {
          scores[intent] = (scores[intent] ?? 0) + 1.0;
        } else if (TextTools.sim(ascii, akw) > 0.9) {
          scores[intent] = (scores[intent] ?? 0) + .7;
        }
      }
    }

    // Teşekkür özel kural
    if (_reThanks.hasMatch(norm)) {
      scores[Intent.thanks] = (scores[Intent.thanks] ?? 0) + 1.2;
    }

    // En iyi intent
    final best = scores.entries.reduce((a, b) => a.value >= b.value ? a : b);
    final ents = _extractEntities(corrected);

    return (match: IntentMatch(best.key, best.value), entities: ents, corrected: corrected);
  }

  /// HH:mm / HH.mm / “üç buçuk” / “akşam 7”
  static Entities _extractEntities(String text) {
    final norm = TextTools.normalize(text);

    // 1) HH:mm veya HH.mm
    final reClock = RegExp(r'(\d{1,2})[:\.](\d{2})');
    final m1 = reClock.firstMatch(norm);
    if (m1 != null) {
      final h = int.parse(m1.group(1)!);
      final mi = int.parse(m1.group(2)!);
      if (h >= 0 && h < 24 && mi >= 0 && mi < 60) {
        return Entities(
          time24: '${h.toString().padLeft(2, '0')}:${mi.toString().padLeft(2, '0')}',
          name: _extractName(norm),
        );
      }
    }

    // 2) “sabah/akşam/öğlen + sayı” ve “buçuk”
    final partOfDay = RegExp(r'\b(sabah|öğlen|ogle|akşam|gece)\b', unicode: true);
    final numberWord = RegExp(
      r'\b(bir|iki|üç|dört|beş|altı|yedi|sekiz|dokuz|on|on bir|on iki)\b',
      unicode: true,
    );
    final half = RegExp(r'\bbuçuk\b', unicode: true);

    final mPod = partOfDay.firstMatch(norm);
    final mNum = numberWord.firstMatch(norm);
    if (mNum != null) {
      final h = _numWordToHour(mNum.group(0)!.replaceAll(' ', ''));
      if (h != null) {
        int hour = h;
        if (mPod != null) {
          final p = mPod.group(0)!;
          if (p == 'akşam' || p == 'gece') hour = (hour % 12) + 12;
          if (p.startsWith('sabah')) hour = hour % 12;
          if (p.startsWith('öğlen') || p == 'ogle') hour = 12;
        }
        final minutes = half.hasMatch(norm) ? 30 : 0;
        return Entities(
          time24: '${hour.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}',
          name: _extractName(norm),
        );
      }
    }

    // 3) Sadece sayı (örn. "14'te", "7de")
    final reH = RegExp(r"\b(\d{1,2})\s*(?:'?(te|de))?\b");
    final mH = reH.firstMatch(norm);
    if (mH != null) {
      final hour = int.parse(mH.group(1)!);
      if (hour >= 0 && hour < 24) {
        return Entities(time24: '${hour.toString().padLeft(2, '0')}:00', name: _extractName(norm));
      }
    }

    return Entities(name: _extractName(norm));
  }

  static String? _extractName(String norm) {
    // saat/komut kelimelerini ayıkla, kalan kelimeleri "isim" say
    var t = norm;
    t = t.replaceAll(RegExp(r'(\d{1,2})[:\.](\d{2})'), ' ');
    t = t.replaceAll(RegExp(r"\b(buçuk|sabah|öğlen|ogle|akşam|gece)\b", unicode: true), ' ');
    t = t.replaceAll(RegExp(r"\b(ekle|hatırlat|hatırlatıcı|sil|liste|alarm|kur|saat|tarih)\b", unicode: true), ' ');
    t = t.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (t.isEmpty) return null;

    // ilk 2-3 kelimeyi baş harf büyükle yaz
    final parts = t.split(' ');
    final words = parts.take(3).map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.length > 1 ? w.substring(1) : ''}').toList();
    return words.join(' ').trim();
  }

  static Intent? _detectSpecial(String ascii) {
    // bugun ne var / saat kac / tarih ne vb.
    final specials = <Intent, List<RegExp>>{
      Intent.today: [
        RegExp(r'\bbugun\s+ne\s+var\b'),
        RegExp(r'\bbugun\b.*\b(program|plan|ilac|hatirlatici)\b'),
      ],
      Intent.time: [
        RegExp(r'\bsaat\s+kac\b'),
        RegExp(r'\b(kac\s+saat|simdi\b.*\bsaat)\b'),
      ],
      Intent.date: [
        RegExp(r'\btarih\s+ne\b'),
        RegExp(r'\bhangi\s+gun\b'),
      ],
    };
    for (final e in specials.entries) {
      for (final r in e.value) {
        if (r.hasMatch(ascii)) return e.key;
      }
    }
    return null;
  }

  static int? _numWordToHour(String w) {
    const map = {
      'bir': 1, 'iki': 2, 'üç': 3, 'uc': 3, 'dört': 4, 'dort': 4, 'beş': 5,
      'bes': 5, 'altı': 6, 'alti': 6, 'yedi': 7, 'sekiz': 8, 'dokuz': 9,
      'on': 10, 'onbir': 11, 'oniki': 12
    };
    return map[TextTools.toAscii(w)];
  }
}
