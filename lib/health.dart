/* lib/health.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:google_fonts/google_fonts.dart';

class LabProfile {
  bool diabetes;        // Diyabet/şeker
  bool highCholesterol; // Yüksek kolesterol
  bool kidneyDisease;   // Böbrek problemi
  bool anemia;          // Kansızlık/demir düşük
  bool vitaminDLow;     // D vitamini düşük

  LabProfile({
    this.diabetes = false,
    this.highCholesterol = false,
    this.kidneyDisease = false,
    this.anemia = false,
    this.vitaminDLow = false,
  });

  Map<String, dynamic> toMap() => {
        'diabetes': diabetes,
        'highCholesterol': highCholesterol,
        'kidneyDisease': kidneyDisease,
        'anemia': anemia,
        'vitaminDLow': vitaminDLow,
      };

  static LabProfile fromMap(Map<String, dynamic> m) => LabProfile(
        diabetes: m['diabetes'] == true,
        highCholesterol: m['highCholesterol'] == true,
        kidneyDisease: m['kidneyDisease'] == true,
        anemia: m['anemia'] == true,
        vitaminDLow: m['vitaminDLow'] == true,
      );

  @override
  String toString() {
    final flags = <String>[];
    if (diabetes) flags.add('Diyabet');
    if (highCholesterol) flags.add('Yüksek kolesterol');
    if (kidneyDisease) flags.add('Böbrek');
    if (anemia) flags.add('Anemi');
    if (vitaminDLow) flags.add('D vitamini düşük');
    return flags.isEmpty ? 'Profil temiz görünüyor.' : flags.join(', ');
  }
}

class HealthStore {
  static const _key = 'health_profile_v1';
  static LabProfile profile = LabProfile();

  static Future<void> load() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    if (raw == null) return;
    try {
      profile = LabProfile.fromMap(jsonDecode(raw));
    } catch (_) {}
  }

  static Future<void> save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(profile.toMap()));
  }
}

/// Basit düzenleme sayfası
class HealthPage extends StatefulWidget {
  const HealthPage({super.key});
  @override
  State<HealthPage> createState() => _HealthPageState();
}

class _HealthPageState extends State<HealthPage> {
  late LabProfile p;

  @override
  void initState() {
    super.initState();
    p = LabProfile(
      diabetes: HealthStore.profile.diabetes,
      highCholesterol: HealthStore.profile.highCholesterol,
      kidneyDisease: HealthStore.profile.kidneyDisease,
      anemia: HealthStore.profile.anemia,
      vitaminDLow: HealthStore.profile.vitaminDLow,
    );
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient background
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
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      _GlassButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Sağlık Profili',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Header Icon & Description
                        Center(
                          child: Column(
                            children: [
                              Container(
                                width: 80,
                                height: 80,
                                decoration: BoxDecoration(
                                  color: const Color(0xFF22C55E),
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: const [
                                    BoxShadow(
                                      color: Colors.black26,
                                      blurRadius: 16,
                                      offset: Offset(0, 6),
                                    ),
                                  ],
                                ),
                                child: const Icon(
                                  Icons.health_and_safety,
                                  size: 40,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Sağlık durumunu belirt',
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.9),
                                  fontSize: 16,
                                  height: 1.4,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 32),

                        // Özet kartı
                        _GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Row(
                                  children: [
                                    Icon(Icons.summarize, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Durum Özeti',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 12),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: _chipsForProfile(p),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Sağlık Durumları Kartı
                        _GlassCard(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Padding(
                                padding: EdgeInsets.fromLTRB(20, 20, 20, 12),
                                child: Row(
                                  children: [
                                    Icon(Icons.medical_services, color: Colors.white, size: 20),
                                    SizedBox(width: 8),
                                    Text(
                                      'Sağlık Durumları',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              _healthSwitch(
                                title: 'Diyabet (şeker)',
                                value: p.diabetes,
                                onChanged: (v) => setState(() => p.diabetes = v),
                                icon: Icons.bloodtype_rounded,
                                color: Colors.pink,
                                isFirst: true,
                              ),
                              _healthSwitch(
                                title: 'Yüksek kolesterol',
                                value: p.highCholesterol,
                                onChanged: (v) => setState(() => p.highCholesterol = v),
                                icon: Icons.opacity_rounded,
                                color: Colors.amber,
                              ),
                              _healthSwitch(
                                title: 'Böbrek hastalığı',
                                value: p.kidneyDisease,
                                onChanged: (v) => setState(() => p.kidneyDisease = v),
                                icon: Icons.local_hospital_rounded,
                                color: Colors.teal,
                              ),
                              _healthSwitch(
                                title: 'Anemi (kansızlık)',
                                value: p.anemia,
                                onChanged: (v) => setState(() => p.anemia = v),
                                icon: Icons.favorite_rounded,
                                color: Colors.redAccent,
                              ),
                              _healthSwitch(
                                title: 'D vitamini düşük',
                                value: p.vitaminDLow,
                                onChanged: (v) => setState(() => p.vitaminDLow = v),
                                icon: Icons.wb_sunny_rounded,
                                color: Colors.orange,
                                isLast: true,
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // Save Button
                        SizedBox(
                          width: double.infinity,
                          child: _GlassButton(
                            onPressed: () async {
                              HealthStore.profile = p;
                              await HealthStore.save();
                              if (!mounted) return;
                              _showSnackBar('Profil kaydedildi.');
                              Navigator.pop(context);
                            },
                            isPrimary: true,
                            child: const Padding(
                              padding: EdgeInsets.symmetric(vertical: 16),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.save, color: Colors.white),
                                  SizedBox(width: 12),
                                  Text(
                                    'Kaydet',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 16),

                        // Warning
                        _GlassCard(
                          color: Colors.orange.withOpacity(0.1),
                          borderColor: Colors.orange.withOpacity(0.3),
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Row(
                              children: [
                                const Icon(
                                  Icons.warning_amber_rounded,
                                  color: Colors.orange,
                                  size: 20,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Text(
                                    'Uyarı: Bu uygulama tıbbi tanı koymaz. Bu bilgiler sadece genel öneri içindir.',
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.9),
                                      fontSize: 12,
                                      height: 1.3,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),

                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // --- UI helpers

  List<Widget> _chipsForProfile(LabProfile p) {
    final chips = <String>[];
    if (p.diabetes) chips.add('Diyabet');
    if (p.highCholesterol) chips.add('Yüksek kolesterol');
    if (p.kidneyDisease) chips.add('Böbrek');
    if (p.anemia) chips.add('Anemi');
    if (p.vitaminDLow) chips.add('D vitamini düşük');
    
    if (chips.isEmpty) {
      return [
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.green.withOpacity(0.2),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.green.withOpacity(0.3)),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.check_circle, color: Colors.green, size: 16),
              SizedBox(width: 6),
              Text(
                'Profil temiz',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
      ];
    }
    
    return chips.map((t) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.2)),
      ),
      child: Text(
        t,
        style: const TextStyle(
          color: Colors.white,
          fontSize: 12,
          fontWeight: FontWeight.bold,
        ),
      ),
    )).toList();
  }

  Widget _healthSwitch({
    required String title,
    required bool value,
    required ValueChanged<bool> onChanged,
    required IconData icon,
    required Color color,
    bool isFirst = false,
    bool isLast = false,
  }) {
    return Container(
      decoration: BoxDecoration(
        border: Border(
          top: isFirst ? BorderSide.none : BorderSide(color: Colors.white.withOpacity(0.1)),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: color.withOpacity(0.2),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, color: color, size: 20),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Text(
                title,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            Transform.scale(
              scale: 0.9,
              child: Switch(
                value: value,
                onChanged: onChanged,
                activeColor: Colors.white,
                activeTrackColor: color,
                inactiveThumbColor: Colors.white.withOpacity(0.7),
                inactiveTrackColor: Colors.white.withOpacity(0.2),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==================== CUSTOM WIDGETS ====================

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? borderColor;

  const _GlassCard({
    required this.child,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.2),
              width: 1,
            ),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          child: child,
        ),
      ),
    );
  }
}

class _GlassButton extends StatelessWidget {
  final Widget child;
  final VoidCallback? onPressed;
  final bool isPrimary;

  const _GlassButton({
    required this.child,
    this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isPrimary 
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary 
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.2),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}*/