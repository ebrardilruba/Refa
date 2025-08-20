// lib/profile.dart
//
// ⚠️ Uygulama açılışında kayıtlı profili yüklemek için:
// void main() async {
//   WidgetsFlutterBinding.ensureInitialized();
//   await HealthStore.init();           // <- bir kere yeter
//   runApp(const MyApp());
// }

import 'dart:convert';
import 'dart:io' as io;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Basit cinsiyet enum'u (opsiyonel)
enum Gender { male, female, other }

/// Acil iletişim kişisi
class EmergencyContact {
  final String name;
  final String relation;   // Örn: "Kızı", "Oğlu", "Eşi"
  final String phone;      // Örn: "0532 123 45 67"
  final String? photoPath; // Lokal dosya yolu (isteğe bağlı)

  const EmergencyContact({
    required this.name,
    required this.relation,
    required this.phone,
    this.photoPath,
  });

  Map<String, dynamic> toMap() => {
        'name': name,
        'relation': relation,
        'phone': phone,
        'photoPath': photoPath,
      };

  factory EmergencyContact.fromMap(Map<String, dynamic> m) => EmergencyContact(
        name: m['name'] ?? '',
        relation: m['relation'] ?? '',
        phone: m['phone'] ?? '',
        photoPath: m['photoPath'],
      );

  EmergencyContact copyWith({
    String? name,
    String? relation,
    String? phone,
    String? photoPath,
  }) {
    return EmergencyContact(
      name: name ?? this.name,
      relation: relation ?? this.relation,
      phone: phone ?? this.phone,
      photoPath: photoPath ?? this.photoPath,
    );
  }

  @override
  String toString() => '$name ($relation) – $phone';
}

/// Kullanıcı sağlık profili (uygulama içinde tek kaynak)
class HealthProfile {
  final String name;
  final int age;
  final Gender? gender;

  /// Profil fotoğrafı (cihaz içi dosya yolu). Yoksa null.
  final String? photoPath;

  /// Kan grubu (örn: "A Rh(+)")
  final String? bloodType;

  /// cm / kg (opsiyonel) – BMI hesaplamak için.
  final double? heightCm;
  final double? weightKg;

  /// Kronik durum bayrakları – LLM önerilerinde kullanılabilir
  final bool diabetes;
  final bool highCholesterol;
  final bool kidneyDisease;
  final bool anemia;
  final bool vitaminDLow;

  /// Serbest metin listeleri
  final List<String> conditions;   // ek klinik durumlar
  final List<String> medications;  // düzenli ilaçlar
  final List<String> allergies;    // alerjiler

  /// Adres/iletişim
  final String? address;
  final String? city;

  /// Bakıcı/ilgili kişi
  final String? caregiverName;
  final String? caregiverPhone;

  /// Geriye uyumluluk için: voice_bot doğrudan gösteriyor
  final String emergencyContact;

  /// Birden fazla acil iletişim kişisi
  final List<EmergencyContact> emergencyContacts;

  const HealthProfile({
    required this.name,
    required this.age,
    required this.emergencyContact,
    this.gender,
    this.photoPath,
    this.bloodType,
    this.heightCm,
    this.weightKg,
    this.diabetes = false,
    this.highCholesterol = false,
    this.kidneyDisease = false,
    this.anemia = false,
    this.vitaminDLow = false,
    this.conditions = const [],
    this.medications = const [],
    this.allergies = const [],
    this.address,
    this.city,
    this.caregiverName,
    this.caregiverPhone,
    this.emergencyContacts = const [],
  });

  /// BMI (VKI) – varsa
  double? get bmi {
    if (heightCm == null || weightKg == null || heightCm == 0) return null;
    final h = heightCm! / 100.0;
    return weightKg! / (h * h);
  }

  HealthProfile copyWith({
    String? name,
    int? age,
    Gender? gender,
    String? photoPath,
    String? bloodType,
    double? heightCm,
    double? weightKg,
    bool? diabetes,
    bool? highCholesterol,
    bool? kidneyDisease,
    bool? anemia,
    bool? vitaminDLow,
    List<String>? conditions,
    List<String>? medications,
    List<String>? allergies,
    String? address,
    String? city,
    String? caregiverName,
    String? caregiverPhone,
    String? emergencyContact,
    List<EmergencyContact>? emergencyContacts,
  }) {
    return HealthProfile(
      name: name ?? this.name,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      photoPath: photoPath ?? this.photoPath,
      bloodType: bloodType ?? this.bloodType,
      heightCm: heightCm ?? this.heightCm,
      weightKg: weightKg ?? this.weightKg,
      diabetes: diabetes ?? this.diabetes,
      highCholesterol: highCholesterol ?? this.highCholesterol,
      kidneyDisease: kidneyDisease ?? this.kidneyDisease,
      anemia: anemia ?? this.anemia,
      vitaminDLow: vitaminDLow ?? this.vitaminDLow,
      conditions: conditions ?? this.conditions,
      medications: medications ?? this.medications,
      allergies: allergies ?? this.allergies,
      address: address ?? this.address,
      city: city ?? this.city,
      caregiverName: caregiverName ?? this.caregiverName,
      caregiverPhone: caregiverPhone ?? this.caregiverPhone,
      emergencyContact: emergencyContact ?? this.emergencyContact,
      emergencyContacts: emergencyContacts ?? this.emergencyContacts,
    );
  }

  Map<String, dynamic> toMap() => {
        'name': name,
        'age': age,
        'gender': gender?.index,
        'photoPath': photoPath,
        'bloodType': bloodType,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'diabetes': diabetes,
        'highCholesterol': highCholesterol,
        'kidneyDisease': kidneyDisease,
        'anemia': anemia,
        'vitaminDLow': vitaminDLow,
        'conditions': conditions,
        'medications': medications,
        'allergies': allergies,
        'address': address,
        'city': city,
        'caregiverName': caregiverName,
        'caregiverPhone': caregiverPhone,
        'emergencyContact': emergencyContact,
        'emergencyContacts': emergencyContacts.map((e) => e.toMap()).toList(),
      };

  factory HealthProfile.fromMap(Map<String, dynamic> m) => HealthProfile(
        name: m['name'] ?? 'Kullanıcı',
        age: (m['age'] ?? 0) is int ? (m['age'] ?? 0) : (m['age'] as num?)?.toInt() ?? 0,
        emergencyContact: m['emergencyContact'] ?? '',
        gender: m['gender'] == null ? null : Gender.values[m['gender']],
        photoPath: m['photoPath'],
        bloodType: m['bloodType'],
        heightCm: (m['heightCm'] as num?)?.toDouble(),
        weightKg: (m['weightKg'] as num?)?.toDouble(),
        diabetes: m['diabetes'] ?? false,
        highCholesterol: m['highCholesterol'] ?? false,
        kidneyDisease: m['kidneyDisease'] ?? false,
        anemia: m['anemia'] ?? false,
        vitaminDLow: m['vitaminDLow'] ?? false,
        conditions: List<String>.from(m['conditions'] ?? const []),
        medications: List<String>.from(m['medications'] ?? const []),
        allergies: List<String>.from(m['allergies'] ?? const []),
        address: m['address'],
        city: m['city'],
        caregiverName: m['caregiverName'],
        caregiverPhone: m['caregiverPhone'],
        emergencyContacts: (m['emergencyContacts'] as List<dynamic>? ?? const [])
            .map((e) => EmergencyContact.fromMap(Map<String, dynamic>.from(e)))
            .toList(),
      );

  @override
  String toString() {
    final flags = <String>[
      if (diabetes) 'Diyabet',
      if (highCholesterol) 'Yüksek Kolesterol',
      if (kidneyDisease) 'Böbrek',
      if (anemia) 'Anemi',
      if (vitaminDLow) 'D Vit. Düşük',
    ];
    final flagsText = flags.isEmpty ? 'Belirtilmemiş' : flags.join(', ');
    return 'Ad: $name • Yaş: $age'
        '${bloodType != null ? ' • Kan: $bloodType' : ''}\n'
        'Acil İletişim: $emergencyContact\n'
        'Durumlar: $flagsText';
  }
}

/// Kalıcı saklama + global erişim
class HealthStore {
  static const String _storageKey = 'health_profile_data_v2';

  // Varsayılan profil
  static final HealthProfile _default = HealthProfile(
    name: 'Ahmet Bey',
    age: 78,
    gender: Gender.male,
    photoPath: null,
    bloodType: 'A Rh(+)',
    heightCm: 172,
    weightKg: 74,
    diabetes: false,
    highCholesterol: true,
    kidneyDisease: false,
    anemia: false,
    vitaminDLow: true,
    conditions: const ['Hipertansiyon'],
    medications: const ['Parol (08:00, 20:00)', 'Tansiyon İlacı (12:00)'],
    allergies: const ['Penisilin'],
    address: 'Çiçek Sokak No:12',
    city: 'İstanbul',
    caregiverName: 'Ayşe Yılmaz',
    caregiverPhone: '0532 123 45 67',
    emergencyContact: '0532 123 45 67 - Ayşe (Kızı)',
    emergencyContacts: const [
      EmergencyContact(name: 'Ayşe Yılmaz', relation: 'Kızı', phone: '0532 123 45 67'),
      EmergencyContact(name: 'Mehmet Yılmaz', relation: 'Oğlu', phone: '0533 555 22 11'),
    ],
  );

  static final ValueNotifier<HealthProfile> profileNotifier =
      ValueNotifier<HealthProfile>(_default);

  static HealthProfile get profile => profileNotifier.value;
  static set profile(HealthProfile p) {
    profileNotifier.value = p;
    _saveProfileToDisk(p);
  }

  /// Açılışta çağır: yerelden yükle
  static Future<void> init() async {
    await _loadProfileFromDisk();
  }

  static void update(HealthProfile Function(HealthProfile current) fn) {
    profile = fn(profile);
  }

  static void setPhotoPath(String? path) {
    update((p) => p.copyWith(photoPath: path));
  }

  // --- SharedPreferences ---
  static Future<void> _loadProfileFromDisk() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonStr = prefs.getString(_storageKey);
      if (jsonStr == null) return;
      final map = jsonDecode(jsonStr) as Map<String, dynamic>;
      profileNotifier.value = HealthProfile.fromMap(map);
    } catch (e) {
      // ignore: avoid_print
      print('Profil yüklenemedi, varsayılan kullanılacak: $e');
      profileNotifier.value = _default;
    }
  }

  static Future<void> _saveProfileToDisk(HealthProfile p) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_storageKey, jsonEncode(p.toMap()));
    } catch (e) {
      // ignore: avoid_print
      print('Profil kaydedilemedi: $e');
    }
  }
}

/// ================= UI: Profil Sayfası (Sesli Bot sayfasıyla aynı stil) ================

class ProfilePage extends StatelessWidget {
  const ProfilePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Arka plan gradyanı
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
              padding: const EdgeInsets.all(20),
              child: ValueListenableBuilder<HealthProfile>(
                valueListenable: HealthStore.profileNotifier,
                builder: (context, profile, _) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _HeaderPill(
                            color: const Color(0xFF22C55E),
                            icon: Icons.person_rounded,
                            title: 'Profil',
                          ),
                          const Spacer(),
                          _TinyBadge(text: 'SAĞLIK'),
                        ],
                      ),
                      const SizedBox(height: 16),

                      const Text(
                        'Sağlık Profili',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                      Text(
                        'Kişisel bilgileriniz, ilaçlarınız ve acil iletişim bir arada.',
                        style: TextStyle(color: Colors.white.withOpacity(0.9)),
                      ),
                      const SizedBox(height: 16),

                      _GlassPanel(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                _Avatar(photoPath: profile.photoPath, name: profile.name),
                                const SizedBox(width: 14),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        profile.name,
                                        style: const TextStyle(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w800,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 6),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 6,
                                        children: [
                                          _Chip('Yaş: ${profile.age}'),
                                          if (profile.bloodType != null) _Chip('Kan: ${profile.bloodType}'),
                                          if (profile.heightCm != null) _Chip('Boy: ${profile.heightCm!.round()} cm'),
                                          if (profile.weightKg != null) _Chip('Kilo: ${profile.weightKg!.round()} kg'),
                                          if (profile.bmi != null) _Chip('BMI: ${profile.bmi!.toStringAsFixed(1)}'),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),

                            if (profile.address != null || profile.city != null) ...[
                              const SizedBox(height: 12),
                              _RowText(
                                '${profile.address ?? ''}'
                                '${profile.address != null && profile.city != null ? ', ' : ''}'
                                '${profile.city ?? ''}',
                              ),
                            ],
                          ],
                        ),
                      ),

                      const SizedBox(height: 12),

                      Expanded(
                        child: ListView(
                          padding: EdgeInsets.zero,
                          children: [
                            if (profile.conditions.isNotEmpty)
                              _SectionCard(
                                title: 'Klinik Durumlar',
                                icon: Icons.medical_services_rounded, // <-- düzeltildi
                                color: const Color(0xFF06B6D4),
                                child: Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: profile.conditions.map((c) => _Pill(c)).toList(),
                                ),
                              ),

                            if (profile.allergies.isNotEmpty)
                              _SectionCard(
                                title: 'Alerjiler',
                                icon: Icons.coronavirus_rounded,
                                color: const Color(0xFFF59E0B),
                                child: Wrap(
                                  spacing: 8, runSpacing: 8,
                                  children: profile.allergies.map((a) => _Pill(a)).toList(),
                                ),
                              ),

                            if (profile.medications.isNotEmpty)
                              _SectionCard(
                                title: 'Düzenli İlaçlar',
                                icon: Icons.medication_rounded,
                                color: const Color(0xFF3B82F6),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: profile.medications
                                      .map((m) => _RowText('💊 $m'))
                                      .toList(),
                                ),
                              ),

                            _SectionCard(
                              title: 'Durum Özeti',
                              icon: Icons.insights_rounded,
                              color: const Color(0xFF8B5CF6),
                              child: Wrap(
                                spacing: 8,
                                runSpacing: 8,
                                children: [
                                  if (profile.diabetes) _Pill('Diyabet'),
                                  if (profile.highCholesterol) _Pill('Yüksek Kolesterol'),
                                  if (profile.kidneyDisease) _Pill('Böbrek Hastalığı'),
                                  if (profile.anemia) _Pill('Anemi'),
                                  if (profile.vitaminDLow) _Pill('D Vit. Düşük'),
                                  if (!profile.diabetes &&
                                      !profile.highCholesterol &&
                                      !profile.kidneyDisease &&
                                      !profile.anemia &&
                                      !profile.vitaminDLow)
                                    _Pill('Belirtilmemiş'),
                                ],
                              ),
                            ),

                            if (profile.caregiverName != null || profile.caregiverPhone != null)
                              _SectionCard(
                                title: 'Bakıcı / Yakın',
                                icon: Icons.support_agent_rounded,
                                color: const Color(0xFF22C55E),
                                child: _RowText(
                                  '${profile.caregiverName ?? ''}'
                                  '${profile.caregiverName != null && profile.caregiverPhone != null ? ' – ' : ''}'
                                  '${profile.caregiverPhone ?? ''}',
                                ),
                              ),

                            _SectionCard(
                              title: 'Acil İletişim',
                              icon: Icons.sos_rounded, // mevcut sürümde varsa kullanılır
                              color: Colors.redAccent,
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  _RowText(profile.emergencyContact),
                                  const SizedBox(height: 8),
                                  if (profile.emergencyContacts.isNotEmpty) ...[
                                    const _RowText('Diğer Kişiler:'),
                                    const SizedBox(height: 6),
                                    ...profile.emergencyContacts.map(
                                      (c) => _RowText('• ${c.name} (${c.relation}) – ${c.phone}'),
                                    ),
                                  ],
                                ],
                              ),
                            ),

                            const SizedBox(height: 12),

                            SizedBox(
                              width: double.infinity,
                              child: _GlassButton(
                                isPrimary: true,
                                onPressed: () {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    const SnackBar(content: Text('Düzenleme sayfası yakında 🙂')),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 14),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(Icons.edit, color: Colors.white),
                                      SizedBox(width: 10),
                                      Text('Düzenle', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
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

/// ===================== ortak UI parçaları =====================

class _HeaderPill extends StatelessWidget {
  final Color color;
  final IconData icon;
  final String title;
  const _HeaderPill({required this.color, required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 8),
          Text(
            title,
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _TinyBadge extends StatelessWidget {
  final String text;
  const _TinyBadge({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w700)),
    );
  }
}

class _GlassPanel extends StatelessWidget {
  final Widget child;
  const _GlassPanel({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8, bottom: 6),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
        boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))],
      ),
      child: child,
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final IconData icon;
  final Color color;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.color,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassPanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(color: color.withOpacity(0.25), borderRadius: BorderRadius.circular(10)),
                child: Icon(icon, color: color, size: 18),
              ),
              const SizedBox(width: 8),
              Text(
                title,
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 16),
              ),
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const _GlassButton({required this.child, this.onPressed, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: Container(
        decoration: BoxDecoration(
          color: isPrimary ? Colors.white.withOpacity(0.22) : Colors.white.withOpacity(0.12),
          border: Border.all(color: isPrimary ? Colors.white.withOpacity(0.34) : Colors.white.withOpacity(0.26)),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onPressed,
            child: child,
          ),
        ),
      ),
    );
  }
}

class _Avatar extends StatelessWidget {
  final String? photoPath;
  final String name;
  const _Avatar({required this.photoPath, required this.name});

  @override
  Widget build(BuildContext context) {
    final fallback = CircleAvatar(
      radius: 34,
      backgroundColor: Colors.white.withOpacity(0.22),
      child: Text(
        _initials(name),
        style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );

    if (photoPath == null || photoPath!.isEmpty) return fallback;
    final file = io.File(photoPath!);
    if (!file.existsSync()) return fallback;

    return CircleAvatar(radius: 34, backgroundImage: FileImage(file));
  }

  String _initials(String n) {
    final parts = n.trim().split(RegExp(r'\s+'));
    if (parts.isEmpty) return '🙂';
    if (parts.length == 1) return parts.first.substring(0, 1).toUpperCase();
    return (parts.first.substring(0, 1) + parts.last.substring(0, 1)).toUpperCase();
  }
}

class _Pill extends StatelessWidget {
  final String text;
  const _Pill(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _Chip extends StatelessWidget {
  final String text;
  const _Chip(this.text);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.18),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: Colors.white.withOpacity(0.28)),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white)),
    );
  }
}

class _RowText extends StatelessWidget {
  final String text;
  const _RowText(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(text, style: const TextStyle(color: Colors.white, fontSize: 14, height: 1.3));
  }
}
