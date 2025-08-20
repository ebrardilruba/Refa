import 'dart:ui';
import 'package:flutter/material.dart';
import 'tts_service.dart'; // VoiceService burada

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  double _rate = VoiceService.instance.rate;   // 0.2–0.9
  double _pitch = VoiceService.instance.pitch; // 0.7–1.3
  String _lang = VoiceService.instance.lang;   // 'tr-TR' varsayılan

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
                  // Glass Header
                  _GlassHeader(),
                  
                  const SizedBox(height: 24),
                  
                  // Title
                  const Text(
                    'Ayarlar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'Uygulama ayarları',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Settings Content
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 100),
                      children: [
                        // Speech Rate Setting
                        _GlassSettingCard(
                          title: 'Konuşma Hızı',
                          subtitle: _rate.toStringAsFixed(2),
                          icon: Icons.speed,
                          child: Slider(
                            value: _rate,
                            min: 0.2,
                            max: 0.9,
                            divisions: 14,
                            activeColor: Colors.white,
                            inactiveColor: Colors.white.withOpacity(0.3),
                            thumbColor: Colors.white,
                            onChanged: (v) => setState(() => _rate = v),
                            onChangeEnd: (v) async => await VoiceService.instance.setRate(v),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Speech Pitch Setting
                        _GlassSettingCard(
                          title: 'Perde (Ses Tizliği)',
                          subtitle: _pitch.toStringAsFixed(2),
                          icon: Icons.tune,
                          child: Slider(
                            value: _pitch,
                            min: 0.7,
                            max: 1.3,
                            divisions: 12,
                            activeColor: Colors.white,
                            inactiveColor: Colors.white.withOpacity(0.3),
                            thumbColor: Colors.white,
                            onChanged: (v) => setState(() => _pitch = v),
                            onChangeEnd: (v) async => await VoiceService.instance.setPitch(v),
                          ),
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Language Setting
                        _GlassSettingCard(
                          title: 'Dil',
                          subtitle: _lang == 'tr-TR' ? 'Türkçe' : 'English',
                          icon: Icons.language,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.15),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: Colors.white.withOpacity(0.30)),
                            ),
                            child: DropdownButton<String>(
                              value: _lang,
                              isExpanded: true,
                              underline: const SizedBox(),
                              dropdownColor: Colors.white,
                              style: const TextStyle(color: Colors.white),
                              items: const [
                                DropdownMenuItem(
                                  value: 'tr-TR',
                                  child: Text('Türkçe (tr-TR)', style: TextStyle(color: Colors.black)),
                                ),
                                DropdownMenuItem(
                                  value: 'en-US',
                                  child: Text('English (en-US)', style: TextStyle(color: Colors.black)),
                                ),
                              ],
                              onChanged: (v) async {
                                if (v == null) return;
                                setState(() => _lang = v);
                                await VoiceService.instance.setLanguage(v);
                              },
                            ),
                          ),
                        ),
                        
                        const SizedBox(height: 24),
                        
                        // Test Button
                        _GlassActionCard(
                          onPressed: () async {
                            await VoiceService.instance.speak(
                              'Bu bir deneme cümlesidir. Türkçe karakterler: Ç, Ğ, İ, Ö, Ş, Ü. '
                              'Hız ${_rate.toStringAsFixed(2)}, perde ${_pitch.toStringAsFixed(2)}.'
                            );
                          },
                        ),
                        
                        const SizedBox(height: 16),
                        
                        // Info Card
                        _GlassInfoCard(),
                      ],
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

class _GlassHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF6366F1),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 4),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.settings,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Uygulama Ayarları',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 16,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.20),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text(
                  'TTS',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
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

class _GlassSettingCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Widget child;

  const _GlassSettingCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.15),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.20),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      icon,
                      color: Colors.white,
                      size: 18,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  Text(
                    subtitle,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              child,
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassActionCard extends StatelessWidget {
  final VoidCallback onPressed;

  const _GlassActionCard({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.15),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: const Color(0xFF22C55E),
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: const [
                      BoxShadow(
                        color: Colors.black26,
                        blurRadius: 8,
                        offset: Offset(0, 4),
                      ),
                    ],
                  ),
                  child: const Icon(
                    Icons.volume_up,
                    color: Colors.white,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 16),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Sesi Test Et',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      SizedBox(height: 4),
                      Text(
                        'Sesli okuma ayarlarını dene',
                        style: TextStyle(
                          color: Colors.white70,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.play_arrow,
                  color: Colors.white.withOpacity(0.8),
                  size: 24,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _GlassInfoCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.10),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.20), width: 1),
            boxShadow: const [
              BoxShadow(
                color: Colors.black26,
                blurRadius: 12,
                offset: Offset(0, 6),
              ),
            ],
          ),
          padding: const EdgeInsets.all(20),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(
                Icons.info_outline,
                color: Colors.white.withOpacity(0.6),
                size: 20,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Not: Cihazda Google Metinden Konuşma ve Türkçe ses paketi kurulu olmalı. '
                  'Aksi halde telaffuz kalitesi değişebilir.',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 13,
                    height: 1.4,
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