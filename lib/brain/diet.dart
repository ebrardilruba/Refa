// lib/brain/diet.dart
// Basit diyet motoru: duygu + sağlık kısıtlarına göre öneriler.

class DietConstraints {
  final bool diabetes;
  final bool highCholesterol;
  final bool kidneyDisease;
  final bool anemia;
  final bool vitaminDLow;

  const DietConstraints({
    this.diabetes = false,
    this.highCholesterol = false,
    this.kidneyDisease = false,
    this.anemia = false,
    this.vitaminDLow = false,
  });
}

class DietEngine {
  /// mood: 'yorgun', 'mide', 'istahsız', 'iyi' ... ya da 'nötr'
  static List<String> suggestions({String mood = 'nötr', DietConstraints constraints = const DietConstraints(), String? mealTime}) {
    // Temel havuz
    var ideas = <String>[
      'Tavuklu sebze çorbası + yoğurt',
      'Zeytinyağlı sebze (kabak/patlıcan) + az bulgur',
      'Izgara balık + salata + ayran',
      'Mercimek köftesi + cacık',
      'Yulaf + yoğurt + meyve',
      'Fırında sebzeli köfte (az yağlı)',
      'Tavuk sote + haşlanmış brokoli',
      'Menemen (az yağ) + tam buğday ekmek',
      'Zeytinyağlı nohut + salata',
      'Sebzeli omlet + ayran',
    ];

    // Duygu modları
    if (mood == 'mide') {
      ideas = [
        'Pirinç lapası + yoğurt',
        'Tavuk suyu çorbası (hafif yağlı)',
        'Haşlanmış patates + ayran',
        'Yoğurt + kraker',
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
        'Izgara hindi/tavuk + az bulgur + salata',
        'Kuru fasulye (az yağ) + yoğurt',
        'Balık + az tam buğday makarna + salata',
        'Humus + kepekli pita + cacık',
      ]);
    }

    // Öğün filtresi (opsiyonel)
    if (mealTime != null) {
      if (mealTime.contains('sabah')) {
        ideas = ideas.where((i) => i.contains('omlet') || i.contains('yulaf') || i.contains('menemen') || i.contains('yoğurt')).toList();
      } else if (mealTime.contains('öğle') || mealTime.contains('ogle')) {
        ideas = ideas.where((i) => i.contains('çorba') || i.contains('tavuk') || i.contains('nohut') || i.contains('omlet')).toList();
      } else if (mealTime.contains('akşam')) {
        ideas = ideas.where((i) => i.contains('balık') || i.contains('köfte') || i.contains('sote') || i.contains('zeytinyağlı')).toList();
      }
      if (ideas.isEmpty) ideas = suggestions(mood: mood, constraints: constraints);
    }

    // Sağlık kısıtları
    if (constraints.diabetes) {
      ideas = ideas.where((s) => !s.contains('makarna') && !s.contains('pilav') && !s.contains('lapası')).toList();
      ideas.add('Salata + lor peyniri + haşlanmış yumurta');
    }
    if (constraints.highCholesterol) {
      ideas = ideas.map((s) => s.replaceAll('köfte', 'ızgara köfte (yağsız)')).toList();
      ideas.removeWhere((s) => s.contains('kızartma'));
    }
    if (constraints.kidneyDisease) {
      ideas = ideas.where((s) => !s.contains('nohut') && !s.contains('fasulye')).toList();
      ideas = ideas.map((s) => s.replaceAll('salata', 'az tuzlu salata')).toList();
    }
    if (constraints.anemia) {
      ideas.insertAll(0, [
        'Kırmızı et sote (az yağ) + ıspanak',
        'Mercimek çorbası + maydanozlu salata',
        'Yumurtalı ıspanak + ayran',
      ]);
    }
    if (constraints.vitaminDLow) {
      ideas.insertAll(0, [
        'Somon/uskumru + salata',
        'Yumurta + yoğurt + tam buğday ekmek',
      ]);
    }

    // 6 öneriye düşür + tekilleştir
    final seen = <String>{};
    final out = <String>[];
    for (final i in ideas) { if (seen.add(i)) out.add(i); }
    if (out.length > 6) out.removeRange(6, out.length);
    return out;
  }

  static String disclaimer() =>
      '📋 Bu öneriler genel bilgi amaçlıdır; kişisel tıbbi tavsiye yerine geçmez.';
}
