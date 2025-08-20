// lib/brain/emotion.dart
// Basit kelime tabanlı duygu tespiti + öneri cümlesi.

class EmotionResult {
  final String label; // 'korku', 'yalnızlık', ...
  final double score; // 0..1
  final Map<String, int> counters;
  const EmotionResult(this.label, this.score, this.counters);
}

class Emotion {
  static const _lexicon = <String, List<String>>{
    'korku': ['korku', 'korkuyorum', 'korktum', 'ürktüm', 'telaş', 'panik', 'endişe', 'kaygı', 'kaygılı'],
    'yalnızlık': ['yalnız', 'tek başıma', 'kimse yok', 'terk edildim', 'yapayalnız'],
    'kafa karışıklığı': ['neredeyim', 'kimim', 'unutuyorum', 'karıştı', 'şaşkınım', 'aklım gitti', 'bocaladım'],
    'üzgün': ['üzgün', 'mutsuz', 'moralim bozuk', 'ağlamak', 'kederli'],
    'sinirli': ['sinir', 'kızgınım', 'öfke', 'gergin', 'asabi'],
    'ağrı': ['ağrı', 'ağrım', 'sızım', 'acı', 'canım yanıyor', 'başım ağrı'],
    'sakin': ['sakinim', 'rahatım', 'iyi hissediyorum', 'huzurlu', 'iyiyim'],
    'mutlu': ['mutlu', 'harika', 'süper', 'çok iyi', 'keyifli', 'neşeli'],
  };

  static EmotionResult detect(String text) {
    final low = text.toLowerCase();
    final counts = <String, int>{ for (final k in _lexicon.keys) k: 0 };
    for (final entry in _lexicon.entries) {
      for (final w in entry.value) {
        if (low.contains(w)) counts[entry.key] = (counts[entry.key] ?? 0) + 1;
      }
    }
    // baskın duygu
    var best = 'nötr';
    var maxC = 0;
    _lexicon.keys.forEach((k) {
      final c = counts[k] ?? 0;
      if (c > maxC) { maxC = c; best = k; }
    });
    final score = (maxC / 3).clamp(0, 1).toDouble();
    return EmotionResult(best, score, counts);
  }

  static String sootheLine(String label) {
    switch (label) {
      case 'korku':
        return 'Korktuğunuzu anlıyorum, güvendesiniz. Derin nefes alıp verelim, buradayım.';
      case 'yalnızlık':
        return 'Yalnız değilsiniz, yanınızdayım. İsterseniz yakınınızı arayabiliriz.';
      case 'kafa karışıklığı':
        return 'Kafanızın karışması normal, birlikte sakin sakin ilerleyelim.';
      case 'üzgün':
        return 'Üzgün hissetmeniz çok normal. Birlikte sizi iyi hissettirecek küçük adımlar atalım.';
      case 'sinirli':
        return 'Gerginlik geçici. Birlikte nefes egzersizi yapabiliriz.';
      case 'ağrı':
        return 'Ağrınızı duydum. Gerekirse dinlenelim ve bir bardak su içelim.';
      case 'mutlu':
        return 'Bunu duymak harika! Böyle devam edelim.';
      case 'sakin':
        return 'Harika, böyle devam edelim. İstediğiniz bir şey var mı?';
      default:
        return 'Buradayım, size destek olmak için hazırım.';
    }
  }
}
