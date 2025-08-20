// lib/brain/assistant_brain.dart

import '../reminders.dart';
import '../profile.dart'; // HealthProfile burada
import 'nlp.dart';

class BrainProcessor {
  /// Kullanıcı girdisine yanıt üretir.
  static Future<String> respond(String input, HealthProfile profile) async {
    final analysis = TurkishNLP.analyze(input);
    final intent = analysis.match.intent;
    final ents = analysis.entities;
    final corrected = analysis.corrected;

    switch (intent) {
      case Intent.greet:
        return 'Merhaba ${profile.name.split(" ").first}! Nasıl yardımcı olabilirim?';
      case Intent.thanks:
        return 'Rica ederim. Başka ne yapabilirim?';
      case Intent.time:
        final now = DateTime.now();
        final hh = now.hour.toString().padLeft(2, '0');
        final mm = now.minute.toString().padLeft(2, '0');
        return 'Şu an saat $hh:$mm.';
      case Intent.date:
        final now = DateTime.now();
        const days = [
          'Pazartesi','Salı','Çarşamba','Perşembe','Cuma','Cumartesi','Pazar'
        ];
        const months = [
          'Ocak','Şubat','Mart','Nisan','Mayıs','Haziran',
          'Temmuz','Ağustos','Eylül','Ekim','Kasım','Aralık'
        ];
        return 'Bugün ${days[now.weekday - 1]}, ${now.day} ${months[now.month - 1]} ${now.year}.';
      case Intent.today:
        return _todayScheduleText();
      case Intent.add:
        return _handleAddReminder(ents, corrected);
      case Intent.list:
        return _handleListReminders();
      case Intent.delete:
        return _handleDeleteReminder(ents, corrected);
      case Intent.profile:
        return _profileText(profile); // toReadableString yerine
      case Intent.diet:
        return _dietAdvice(profile, corrected);
      case Intent.help:
        return _helpText();
      case Intent.none:
      default:
        return _fallback();
    }
  }

  // ---------- Helpers ----------

  static String _todayScheduleText() {
    final reminders = ReminderStore.all().where((r) => r.active).toList();
    if (reminders.isEmpty) {
      return 'Bugün için kayıtlı ilaç/hatırlatıcı yok. İsterseniz ekleyebilirim.';
    }
    final items = reminders
        .expand((r) => r.times.map((t) => (t, r.title)))
        .toList()
      ..sort((a, b) => a.$1.compareTo(b.$1));

    final b = StringBuffer('Bugünkü hatırlatmalarınız:\n');
    for (final (time, name) in items) {
      b.writeln('• $time — $name');
    }
    return b.toString().trim();
  }

  static String _handleAddReminder(Entities ents, String corrected) {
    final time = ents.time24;
    final name = ents.name;
    if (time != null && name != null) {
      ReminderStore.add(name, [time]);
      return 'Tamam! “$name” için $time saatine hatırlatıcı ekledim.';
    }
    if (time != null && name == null) {
      return 'Saat $time için hangi ilacın/işin hatırlatıcısını ekleyeyim?';
    }
    if (time == null && name != null) {
      return '“$name” için saat kaçta hatırlatayım? (Örn: 14:30)';
    }
    return 'Hangi hatırlatmayı, saat kaçta ekleyeyim? Örnek: “14:30\'da Parol ekle”.';
  }

  static String _handleListReminders() {
    final all = ReminderStore.all();
    if (all.isEmpty) return 'Henüz hiç hatırlatıcı yok.';
    final active = all.where((r) => r.active).toList();
    final inactive = all.where((r) => !r.active).toList();

    final b = StringBuffer('Hatırlatıcılar:\n');
    if (active.isNotEmpty) {
      b.writeln('• Aktif:');
      for (final r in active) {
        b.writeln('  - ${r.title}: ${r.times.join(", ")}');
      }
    }
    if (inactive.isNotEmpty) {
      b.writeln('• Pasif:');
      for (final r in inactive) {
        b.writeln('  - ${r.title}: ${r.times.join(", ")}');
      }
    }
    return b.toString().trim();
  }

  static String _handleDeleteReminder(Entities ents, String corrected) {
    final nameCandidate = ents.name ??
        corrected.replaceAll(RegExp(r'\b(sil|kaldır|iptal)\b', caseSensitive: false), '').trim();
    if (nameCandidate.isEmpty) {
      return 'Hangi hatırlatıcıyı silmek istiyorsunuz? Örn: “Parol sil”.';
    }

    final all = ReminderStore.all();
    if (all.isEmpty) return 'Silinecek kayıt yok. Listem boş.';

    double bestScore = 0;
    var best = all.first;
    for (final r in all) {
      final s = TextTools.sim(r.title, nameCandidate);
      if (s > bestScore) {
        bestScore = s;
        best = r;
      }
    }

    if (bestScore < 0.55) {
      return '“$nameCandidate” adına benzer bir kayıt bulamadım. “Liste” diyerek göz atabilirsiniz.';
    }

    ReminderStore.remove(best.id);
    return '“${best.title}” hatırlatıcısını sildim.';
  }

  static String _dietAdvice(HealthProfile p, String corrected) {
    var ideas = <String>[
      'Tavuklu sebze çorbası + yoğurt',
      'Zeytinyağlı sebze + bulgur pilavı',
      'Izgara balık + salata + ayran',
      'Mercimek çorbası + cacık',
      'Yulaf + yoğurt + meyve',
      'Sebzeli omlet + tam buğday ekmek',
    ];

    if (p.diabetes) {
      ideas = ideas.where((s) => !s.contains('pilav') && !s.contains('yulaf')).toList();
      ideas.add('Salata + lor peyniri + haşlanmış yumurta');
    }
    if (p.highCholesterol) {
      ideas = ideas.map((s) => s.replaceAll('omlet', 'az yağlı omlet')).toList();
    }
    if (p.kidneyDisease) {
      ideas = ideas.where((s) => !s.contains('mercimek')).toList();
    }
    if (p.anemia) {
      ideas.insert(0, 'Az yağlı kırmızı et sote + ıspanak');
    }
    if (p.vitaminDLow) {
      ideas.insert(0, 'Somon/uskumru + salata');
    }

    final b = StringBuffer('Size şu yemek önerileri uygun olabilir:\n');
    for (final i in ideas.take(6)) {
      b.writeln('• $i');
    }
    b.writeln('\nNot: Bunlar genel önerilerdir; doktorunuzun önerileri önceliklidir.');
    return b.toString();
  }

  static String _profileText(HealthProfile p) {
    final flags = <String>[
      if (p.diabetes) 'Diyabet',
      if (p.highCholesterol) 'Yüksek kolesterol',
      if (p.kidneyDisease) 'Böbrek',
      if (p.anemia) 'Anemi',
      if (p.vitaminDLow) 'D vitamini düşük',
    ];
    final b = StringBuffer()
      ..writeln('Ad: ${p.name}')
      ..writeln('Yaş: ${p.age}${p.bloodType != null ? ' • Kan: ${p.bloodType}' : ''}');
    if (p.heightCm != null && p.weightKg != null) {
      b.writeln('Boy/Kilo: ${p.heightCm!.round()} cm / ${p.weightKg!.round()} kg'
          '${p.bmi != null ? ' • BMI: ${p.bmi!.toStringAsFixed(1)}' : ''}');
    }
    if (flags.isNotEmpty) b.writeln('Durumlar: ${flags.join(', ')}');
    if (p.conditions.isNotEmpty) b.writeln('Klinik: ${p.conditions.join(', ')}');
    if (p.allergies.isNotEmpty) b.writeln('Alerjiler: ${p.allergies.join(', ')}');
    if (p.medications.isNotEmpty) b.writeln('İlaçlar: ${p.medications.join('; ')}');
    b.writeln('Acil İletişim: ${p.emergencyContact}');
    return b.toString().trim();
  }

  static String _helpText() => '''
Şunları yapabilirim:
• “Bugün ne var?” — Günlük hatırlatmalarınız
• “Saat kaç?” / “Tarih ne?”
• “14:30'da Parol ekle” — Hatırlatıcı eklerim
• “Liste” — Tüm hatırlatıcıları gösteririm
• “Parol'u sil” — Hatırlatıcı silerim
• “Ne yesem?” — Basit, güvenli yemek önerileri
• “Profil” — Kayıtlı sağlık bilginizi okurum
''';

  static String _fallback() => '''
Tam anlayamadım. Örnekler:
• “Bugün ne var?”
• “Saat kaç?”
• “14:30'da Parol ekle”
• “Ne yesem?”
• “Yardım”
''';
}
