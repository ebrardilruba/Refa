// lib/app.dart
import 'dart:ui';
import 'package:flutter/material.dart';

// Splash (sesli+yazılı hoş geldiniz)
import 'welcome_splash.dart';

// GERÇEK SAYFALAR – alias ile bağla
import 'today.dart' as today;        // today.TodayPage
import 'reminders.dart' as rem;      // rem.RemindersPage
import 'memory_game.dart' as game;   // game.MemoryGamePage
import 'settings.dart' as stg;       // stg.SettingsPage
import 'enabiz.dart' as enb;         // enb.EnabizPage (Tahliller/PDF)
import 'voice_bot.dart' as voice;    // voice.VoiceBotPage  ← SESLİ BOT GERÇEK SAYFA

class RefaApp extends StatelessWidget {
  const RefaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Refa',
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: const ColorScheme.light(
          primary: Color(0xFF3D63DD),
          onPrimary: Colors.white,
          primaryContainer: Color(0xFFE5EAFF),
          onPrimaryContainer: Color(0xFF0E1A44),
          secondary: Color(0xFF6E56CF),
          onSecondary: Colors.white,
          secondaryContainer: Color(0xFFEAE3FF),
          onSecondaryContainer: Color(0xFF1F1147),
          background: Color(0xFF0F172A),
          onBackground: Colors.white,
          surface: Colors.white,
          onSurface: Colors.black,
        ),
      ),
      // İlk açılışta Splash göster
      home: const WelcomeSplash(),
      routes: {
        '/home': (_) => const RefaHomePage(),
      },
    );
  }
}

class _MenuItem {
  final String id;
  final IconData icon;
  final String label;
  final String subtitle;
  final Color color;
  const _MenuItem(this.id, this.icon, this.label, this.subtitle, this.color);
}

class RefaHomePage extends StatefulWidget {
  const RefaHomePage({super.key});

  @override
  State<RefaHomePage> createState() => _RefaHomePageState();
}

class _RefaHomePageState extends State<RefaHomePage> {
  String? selectedId;

  final items = const <_MenuItem>[
    _MenuItem('reminders', Icons.notifications, 'Hatırlatıcılar', 'İlaç ve Randevu', Color(0xFF3B82F6)),
    _MenuItem('voice', Icons.mic, 'Sesli Bot', 'Ses Komutları', Color(0xFF8B5CF6)),
    _MenuItem('today', Icons.calendar_today, 'Bugün', 'Günlük Plan', Color(0xFF06B6D4)),
    _MenuItem('memory', Icons.sports_esports, 'Hafıza Oyunu', 'Zihin Egzersizi', Color(0xFF22C55E)),
    _MenuItem('reports', Icons.description, 'Tahliller (PDF)', 'Tıbbi Raporlar', Color(0xFFF59E0B)),
    _MenuItem('settings', Icons.settings, 'Ayarlar', 'Uygulama Ayarları', Color(0xFF6366F1)),
  ];

  void _tapCard(String id) {
    setState(() => selectedId = id);
    Future.delayed(const Duration(milliseconds: 140), () {
      if (!mounted) return;
      setState(() => selectedId = null);
      _open(id);
    });
  }

  void _open(String id) {
    final nav = Navigator.of(context);
    switch (id) {
      case 'today':
        nav.push(MaterialPageRoute(builder: (_) => const today.TodayPage()));
        break;
      case 'reminders':
        nav.push(MaterialPageRoute(builder: (_) => const rem.RemindersPage()));
        break;
      case 'reports':
        nav.push(MaterialPageRoute(builder: (_) => const enb.EnabizPage()));
        break;
      case 'voice':
        nav.push(MaterialPageRoute(builder: (_) => const voice.VoiceBotPage()));
        break;
      case 'memory':
        nav.push(MaterialPageRoute(builder: (_) => const game.MemoryGamePage()));
        break;
      case 'settings':
        nav.push(MaterialPageRoute(builder: (_) => const stg.SettingsPage()));
        break;
    }
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
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Fake status bar
                  const Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text('9:41', style: TextStyle(color: Colors.white, fontSize: 14)),
                      Row(
                        children: [
                          Text('••••', style: TextStyle(color: Colors.white, fontSize: 12)),
                          SizedBox(width: 6),
                          Text('📶', style: TextStyle(color: Colors.white, fontSize: 12)),
                          SizedBox(width: 2),
                          Text('📶', style: TextStyle(color: Colors.white, fontSize: 12)),
                          SizedBox(width: 6),
                          Text('100%', style: TextStyle(color: Colors.white, fontSize: 12)),
                        ],
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  const Text(
                    'Refa',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Cards Grid
                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: 2,
                        crossAxisSpacing: 16,
                        mainAxisSpacing: 16,
                        childAspectRatio: 0.85,
                      ),
                      itemCount: items.length,
                      itemBuilder: (context, index) {
                        final item = items[index];
                        final selected = selectedId == item.id;

                        final baseGlass = Colors.white.withOpacity(0.30);
                        final selGlass = Colors.white.withOpacity(0.36);
                        final baseBorder = Colors.white.withOpacity(0.50);
                        final selBorder = Colors.white.withOpacity(0.65);

                        return GestureDetector(
                          onTap: () => _tapCard(item.id),
                          child: _GlassCard(
                            color: selected ? selGlass : baseGlass,
                            borderColor: selected ? selBorder : baseBorder,
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Container(
                                    width: 48,
                                    height: 48,
                                    decoration: BoxDecoration(
                                      color: item.color,
                                      borderRadius: BorderRadius.circular(14),
                                      boxShadow: const [
                                        BoxShadow(
                                          color: Colors.black26,
                                          blurRadius: 8,
                                          offset: Offset(0, 4),
                                        ),
                                      ],
                                    ),
                                    child: Icon(item.icon, color: Colors.white, size: 24),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    item.label,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                      height: 1.1,
                                    ),
                                  ),
                                  const SizedBox(height: 3),
                                  Text(
                                    item.subtitle,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      color: Colors.white.withOpacity(0.8),
                                      fontSize: 11,
                                      height: 1.1,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        );
                      },
                    ),
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

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color color;
  final Color borderColor;

  const _GlassCard({
    super.key,
    required this.child,
    required this.color,
    required this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: Stack(
        children: [
          // DÜZELTİLDİ: Positioned.fill
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: color,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: borderColor, width: 1),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 12,
                      offset: Offset(0, 6),
                    ),
                  ],
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}  