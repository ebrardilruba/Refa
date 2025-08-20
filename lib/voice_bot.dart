// lib/voice_bot.dart
import 'dart:async';
import 'package:flutter/material.dart';

import 'tts_service.dart';
import 'profile.dart';                 // Profil & HealthStore
import 'brain/assistant_brain.dart';   // LLM mantığı

class VoiceBotPage extends StatefulWidget {
  const VoiceBotPage({super.key});

  @override
  State<VoiceBotPage> createState() => _VoiceBotPageState();
}

class ChatMessage {
  final String role; // 'user' | 'bot'
  final String text;
  final DateTime timestamp;
  ChatMessage(this.role, this.text) : timestamp = DateTime.now();
}

class _VoiceBotPageState extends State<VoiceBotPage>
    with WidgetsBindingObserver {
  final _inputController = TextEditingController();
  final _scrollController = ScrollController();
  final _messages = <ChatMessage>[];

  final VoiceService _voiceService = VoiceService.instance;
  String _recognizedText = '';

  StreamSubscription<String>? _recognitionSubscription;
  StreamSubscription<bool>? _listeningSubscription;
  StreamSubscription<bool>? _speakingSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    _initServices();
    _seedWelcome();
    _setupStreams();
  }

  Future<void> _initServices() async {
    await _voiceService.init(); // idempotent olmalı
  }

  void _seedWelcome() {
    final p = HealthStore.profile;
    _pushBot(
      'Merhaba ${p.name}! Ben Refa. Yaz, ben konuşayım — Türkçe akıllı anlama ile yanındayım.',
      speak: false,
    );
    _pushBot(
      'Merhaba! Ben Refa. Bana şöyle şeyler yazabilir/konuşabilirsiniz:\n'
      '• “Bugün ne var?” veya “bugün program”\n'
      '• “Saat kaç / tarih ne?”\n'
      '• “14:30’da Parol ekle” ya da “Parol için saat 14:30”\n'
      '• “Hatırlatıcı ekle” (eksik bilgiyi sorarım)\n'
      '• “Kendimi yorgun hissediyorum, ne yesem?”\n'
      '• “Tahlillerime bak”\n\n'
      'Yazım hatalarını anlayabilirim, Türkçe karakterleri doğru algılarım!',
      speak: false,
    );
  }

  void _setupStreams() {
    // CANLI YAZMA: mic açıkken parçalı sonuçları anlık TextField’a düşür
    _recognitionSubscription = _voiceService.onRecognition.listen((text) {
      if (!mounted) return;
      setState(() {
        _recognizedText = text;
        _inputController.text = text;
        _inputController.selection = TextSelection.fromPosition(
          TextPosition(offset: _inputController.text.length),
        );
      });
    });

    _listeningSubscription =
        _voiceService.onListeningChange.listen((_) {
      if (mounted) setState(() {});
    });

    _speakingSubscription =
        _voiceService.onSpeakingChange.listen((_) {
      if (mounted) setState(() {});
    });
  }

  void _pushUser(String text) {
    setState(() => _messages.add(ChatMessage('user', text)));
    _scrollBottom();
  }

  void _pushBot(String text, {bool speak = true}) async {
    setState(() => _messages.add(ChatMessage('bot', text)));
    _scrollBottom();
    if (speak && !_voiceService.isListening) {
      await _voiceService.speak(text);
    }
  }

  void _scrollBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _toggleListening() async {
    if (_voiceService.isListening) {
      await _voiceService.stopListening();
      // canlı yazma zaten inputu dolduruyor; ekstra kopyalama yok
    } else {
      _recognizedText = '';
      _inputController.clear();
      await _voiceService.startListening();
    }
  }

  Future<void> _handleSend() async {
    final text = _inputController.text.trim();
    if (text.isEmpty) return;

    _inputController.clear();
    _pushUser(text);

    final reply = await BrainProcessor.respond(text, HealthStore.profile);
    _pushBot(reply);
  }

  void _openMenu() {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
      ),
      builder: (ctx) {
        final listening = _voiceService.isListening;
        final speaking = _voiceService.isSpeaking;
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(height: 8),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(99),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.person),
                title: const Text('Profili Gör'),
                subtitle: const Text('Kişisel bilgiler ve acil iletişim'),
                onTap: () {
                  Navigator.pop(ctx);
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const ProfilePage()),
                  );
                },
              ),
              ListTile(
                leading: Icon(listening ? Icons.mic_off : Icons.mic),
                title: Text(listening ? 'Dinlemeyi Durdur' : 'Dinlemeyi Başlat'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _toggleListening();
                },
              ),
              ListTile(
                enabled: speaking,
                leading: const Icon(Icons.volume_off),
                title: const Text('Konuşmayı Durdur'),
                onTap: () async {
                  Navigator.pop(ctx);
                  await _voiceService.stopSpeaking();
                },
              ),
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('Sohbeti Temizle'),
                onTap: () {
                  Navigator.pop(ctx);
                  setState(() => _messages.clear());
                },
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  // ---------- Yaşam döngüsü: sayfadan gidip dönünce sağlam kalması ----------
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Bazı cihazlarda STT motoru yeniden bağlanmak istiyor
      _voiceService.init();
    } else if (state == AppLifecycleState.paused) {
      _voiceService.stopListening();
      _voiceService.stopSpeaking();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);

    // ÖNEMLİ: Servisi YOK ETME! Sadece durdur.
    _voiceService.stopListening();
    _voiceService.stopSpeaking();
    // _voiceService.dispose();  // <-- KULLANMAYIN (geri dönünce çalışmamasının sebebi)

    _recognitionSubscription?.cancel();
    _listeningSubscription?.cancel();
    _speakingSubscription?.cancel();
    _inputController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<HealthProfile>(
      valueListenable: HealthStore.profileNotifier,
      builder: (context, profile, _) {
        return Scaffold(
          body: Stack(
            children: [
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
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          _GlassBadge(
                            icon: Icons.mic,
                            label: 'Akıllı Sesli Bot',
                            trailing: 'STT+TTS',
                          ),
                          const Spacer(),
                          Material(
                            color: Colors.white,
                            shape: const CircleBorder(),
                            child: InkWell(
                              customBorder: const CircleBorder(),
                              onTap: _openMenu,
                              child: const SizedBox(
                                width: 36,
                                height: 36,
                                child:
                                    Icon(Icons.more_horiz, color: Colors.black87),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'Sesli Bot',
                        style: TextStyle(
                            color: Colors.white,
                            fontSize: 26,
                            fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Yaz, ben konuşayım • Türkçe akıllı anlama',
                        style: TextStyle(color: Colors.white.withOpacity(0.9)),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: _GlassContainer(
                          child: ListView.builder(
                            controller: _scrollController,
                            padding: const EdgeInsets.all(12),
                            itemCount: _messages.length,
                            itemBuilder: (context, index) {
                              final m = _messages[index];
                              final isUser = m.role == 'user';
                              return Align(
                                alignment: isUser
                                    ? Alignment.centerRight
                                    : Alignment.centerLeft,
                                child: Container(
                                  margin:
                                      const EdgeInsets.symmetric(vertical: 6),
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 14, vertical: 10),
                                  constraints: BoxConstraints(
                                    maxWidth:
                                        MediaQuery.of(context).size.width * 0.72,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isUser
                                        ? const Color(0xFF60A5FA)
                                            .withOpacity(0.25)
                                        : Colors.white.withOpacity(0.12),
                                    border: Border.all(
                                      color: Colors.white.withOpacity(0.28),
                                    ),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        m.text,
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 14.5,
                                          height: 1.32,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        '${m.timestamp.hour.toString().padLeft(2, '0')}:${m.timestamp.minute.toString().padLeft(2, '0')}',
                                        style: TextStyle(
                                          color:
                                              Colors.white.withOpacity(0.72),
                                          fontSize: 10,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _Composer(
                        controller: _inputController,
                        isListening: _voiceService.isListening,
                        onMic: _toggleListening,
                        onSend: _handleSend,
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

/* ---------------- UI yardımcıları ---------------- */

class _GlassBadge extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? trailing;
  const _GlassBadge({
    required this.icon,
    required this.label,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white.withOpacity(0.30)),
      ),
      child: Row(
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: const Color(0xFF8B5CF6),
              borderRadius: BorderRadius.circular(10),
              boxShadow: const [
                BoxShadow(
                    color: Colors.black26, blurRadius: 8, offset: Offset(0, 4)),
              ],
            ),
            child: Icon(icon, color: Colors.white, size: 16),
          ),
          const SizedBox(width: 10),
          Text(label,
              style: const TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.w700,
                  fontSize: 13)),
          if (trailing != null) ...[
            const SizedBox(width: 10),
            Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.18),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: Colors.white.withOpacity(0.28)),
              ),
              child: Text(trailing!,
                  style:
                      const TextStyle(color: Colors.white, fontSize: 10)),
            ),
          ],
        ],
      ),
    );
  }
}

class _GlassContainer extends StatelessWidget {
  final Widget child;
  const _GlassContainer({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.10),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withOpacity(0.22)),
      ),
      child: child,
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool isListening;
  final VoidCallback onMic;
  final VoidCallback onSend;

  const _Composer({
    required this.controller,
    required this.isListening,
    required this.onMic,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return _GlassContainer(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        child: Row(
          children: [
            Material(
              color: isListening
                  ? Colors.red.withOpacity(0.9)
                  : Colors.white.withOpacity(0.14),
              shape: const CircleBorder(),
              child: InkWell(
                customBorder: const CircleBorder(),
                onTap: onMic,
                child: SizedBox(
                  width: 40,
                  height: 40,
                  child: Icon(
                    isListening ? Icons.mic_off : Icons.mic,
                    color: Colors.white,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: TextField(
                controller: controller,
                style: const TextStyle(color: Colors.white),
                decoration: InputDecoration(
                  hintText: isListening
                      ? 'Dinleniyor… konuşurken metin yazılıyor'
                      : 'Yazım hatasıyla bile yazabilirsin…',
                  hintStyle:
                      TextStyle(color: Colors.white.withOpacity(0.80)),
                  border: InputBorder.none,
                  isCollapsed: true,
                ),
                minLines: 1,
                maxLines: 3,
                onSubmitted: (_) => onSend(),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF3B82F6),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                    horizontal: 14, vertical: 12),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12)),
              ),
              onPressed: onSend,
              child: const Text('Gönder'),
            ),
          ],
        ),
      ),
    );
  }
}
