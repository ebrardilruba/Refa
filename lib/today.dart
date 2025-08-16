// lib/today.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;
import 'package:shared_preferences/shared_preferences.dart';

import 'reminders.dart';

/// -------------------- RANDEVU MODEL / STORE --------------------

class Appointment {
  final int id;
  String title;   // örn: Dahiliye
  String date;    // YYYY-MM-DD
  String time;    // HH:mm
  bool notify;

  Appointment({
    required this.id,
    required this.title,
    required this.date,
    required this.time,
    this.notify = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'date': date,
        'time': time,
        'notify': notify,
      };

  static Appointment fromMap(Map<String, dynamic> m) => Appointment(
        id: m['id'] as int,
        title: m['title'] as String,
        date: m['date'] as String,
        time: m['time'] as String,
        notify: (m['notify'] as bool?) ?? true,
      );
}

class AppointmentStore {
  static const _key = 'appointments';
  static final List<Appointment> _items = [];
  static int _id = 1;

  static List<Appointment> all() => List.unmodifiable(_items);

  static Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    _items.clear();
    if (raw != null && raw.isNotEmpty) {
      final decoded = jsonDecode(raw);
      if (decoded is List) {
        for (final e in decoded) {
          if (e is Map) {
            _items.add(Appointment.fromMap(
              e.map((k, v) => MapEntry(k.toString(), v)),
            ));
          }
        }
      }
      _id = (_items.isEmpty
              ? 0
              : _items.map((e) => e.id).reduce((a, b) => a > b ? a : b)) +
          1;
    }
  }

  static Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(
      _key,
      jsonEncode(_items.map((e) => e.toMap()).toList()),
    );
  }

  static Future<Appointment> add(String title, String date, String time) async {
    final a = Appointment(id: _id++, title: title.trim(), date: date, time: time);
    _items.add(a);
    await _save();
    await _scheduleFor(a);
    return a;
  }

  static Future<void> update(Appointment a) async {
    final i = _items.indexWhere((e) => e.id == a.id);
    if (i >= 0) _items[i] = a;
    await _save();
    await _scheduleFor(a);
  }

  static Future<void> remove(int id) async {
    final idx = _items.indexWhere((e) => e.id == id);
    if (idx < 0) return;
    final a = _items[idx];
    await _cancelFor(a);
    _items.removeAt(idx);
    await _save();
  }

  // ----------------- Bildirim Planlama -----------------

  static final FlutterLocalNotificationsPlugin _notifs =
      FlutterLocalNotificationsPlugin();

  static bool _initialized = false;

  static Future<void> _ensureInit() async {
    if (_initialized) return;
    const initAndroid = AndroidInitializationSettings('@mipmap/ic_launcher');
    await _notifs.initialize(const InitializationSettings(android: initAndroid));
    tz.initializeTimeZones();
    try {
      tz.setLocalLocation(tz.getLocation('Europe/Istanbul'));
    } catch (_) {}
    _initialized = true;
  }

  static NotificationDetails _details() {
    const android = AndroidNotificationDetails(
      'appts',
      'Randevular',
      channelDescription: 'Randevu hatırlatmaları',
      importance: Importance.max,
      priority: Priority.high,
      playSound: true,
      category: AndroidNotificationCategory.reminder,
    );
    return const NotificationDetails(android: android);
  }

  static int _idDayBefore(Appointment a) => a.id * 1000 + 1;
  static int _idSameDay(Appointment a) => a.id * 1000 + 2;

  static Future<void> _cancelFor(Appointment a) async {
    await _ensureInit();
    await _notifs.cancel(_idDayBefore(a));
    await _notifs.cancel(_idSameDay(a));
  }

  static Future<void> _scheduleFor(Appointment a) async {
    await _ensureInit();
    await _cancelFor(a);
    if (!a.notify) return;

    final dParts = a.date.split('-'); // YYYY-MM-DD
    final tParts = a.time.split(':'); // HH:mm
    if (dParts.length != 3 || tParts.length != 2) return;
    final y = int.parse(dParts[0]),
        m = int.parse(dParts[1]),
        d = int.parse(dParts[2]);
    final hh = int.parse(tParts[0]),
        mm = int.parse(tParts[1]);

    final sameDay = tz.TZDateTime(tz.local, y, m, d, hh, mm);

    final dayStart = tz.TZDateTime(tz.local, y, m, d);
    final prev = dayStart.subtract(const Duration(days: 1));
    final dayBefore = tz.TZDateTime(tz.local, prev.year, prev.month, prev.day, 9, 0);

    await _notifs.zonedSchedule(
      _idDayBefore(a),
      'Yarın randevun var',
      '${a.title} – ${a.date} ${a.time}',
      dayBefore,
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );

    await _notifs.zonedSchedule(
      _idSameDay(a),
      'Randevu zamanı',
      '${a.title} – Bugün ${a.time}',
      sameDay,
      _details(),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      uiLocalNotificationDateInterpretation:
          UILocalNotificationDateInterpretation.absoluteTime,
      matchDateTimeComponents: null,
    );
  }
}

/// -------------------- GLASS CARD WIDGET --------------------

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? borderColor;
  final double borderRadius;

  const _GlassCard({
    super.key,
    required this.child,
    this.color,
    this.borderColor,
    this.borderRadius = 20,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: Stack(
        children: [
          Positioned.fill(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
              child: Container(
                decoration: BoxDecoration(
                  color: color ?? Colors.white.withOpacity(0.25),
                  borderRadius: BorderRadius.circular(borderRadius),
                  border: Border.all(
                    color: borderColor ?? Colors.white.withOpacity(0.4),
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
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// -------------------- BUGÜN SAYFASI --------------------

class TodayPage extends StatefulWidget {
  const TodayPage({super.key});

  @override
  State<TodayPage> createState() => _TodayPageState();
}

class _TodayPageState extends State<TodayPage> {
  late final FlutterTts _tts;
  bool _autoSpeak = true;
  bool _speaking = false;
  String? _lastSpoken;

  @override
  void initState() {
    super.initState();
    _tts = FlutterTts();
    _initTts();

    Future.microtask(() async {
      await AppointmentStore.init();
      if (mounted) setState(() {});
      await _speakTodayIfNeeded();
    });
  }

  Future<void> _initTts() async {
    if (kIsWeb) return;
    await _tts.setLanguage('tr-TR');
    await _tts.setSpeechRate(0.5);
    await _tts.setPitch(1.0);
    await _tts.setVolume(1.0);
    await _tts.awaitSpeakCompletion(true);
    _tts.setStartHandler(() => setState(() => _speaking = true));
    _tts.setCompletionHandler(() => setState(() => _speaking = false));
    _tts.setCancelHandler(() => setState(() => _speaking = false));

    final langs = await _tts.getLanguages;
    if (langs is List && !langs.contains('tr-TR') && langs.contains('tr_TR')) {
      await _tts.setLanguage('tr_TR');
    }
  }

  List<(String, String)> _medsToday() {
    final items = ReminderStore.all()
        .where((r) => r.active)
        .expand((r) => r.times.map((t) => (r.title, t)))
        .toList()
      ..sort((a, b) => a.$2.compareTo(b.$2));
    return items;
  }

  List<Appointment> _apptsToday() {
    final now = DateTime.now();
    final yyyy = now.year.toString().padLeft(4, '0');
    final mm = now.month.toString().padLeft(2, '0');
    final dd = now.day.toString().padLeft(2, '0');
    final key = '$yyyy-$mm-$dd';
    final list = AppointmentStore.all()
        .where((a) => a.date == key)
        .toList()
      ..sort((a, b) => a.time.compareTo(b.time));
    return list;
  }

  String _buildTodayText() {
    final meds = _medsToday();
    final appts = _apptsToday();

    if (meds.isEmpty && appts.isEmpty) return 'Bugün için kayıt bulunamadı.';

    final b = StringBuffer();
    if (meds.isNotEmpty) {
      b.write('Bugün almanız gereken ilaçlar: ');
      for (final (title, time) in meds) {
        b.write('$time saatinde $title. ');
      }
    }
    if (appts.isNotEmpty) {
      if (b.isNotEmpty) b.write(' ');
      b.write('Bugünkü randevular: ');
      for (final a in appts) {
        // APOSTROFU KAÇIR
        b.write("${a.time}'de ${a.title}. ");
      }
    }
    return b.toString();
  }

  Future<void> _speakTodayIfNeeded() async {
    if (!_autoSpeak || kIsWeb) return;
    final text = _buildTodayText();
    if (text == _lastSpoken) return;
    _lastSpoken = text;
    await _tts.speak(text);
  }

  Future<void> _speakNow() async {
    if (kIsWeb) return;
    final text = _buildTodayText();
    _lastSpoken = text;
    await _tts.speak(text);
  }

  @override
  void dispose() {
    _tts.stop();
    super.dispose();
  }

  Future<bool> _confirmDelete(Appointment a) async {
    return await showDialog<bool>(
          context: context,
          barrierColor: Colors.black54,
          builder: (_) => BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: AlertDialog(
              backgroundColor: Colors.white.withOpacity(0.9),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
              title: const Text('Randevuyu sil?'),
              content: Text('"${a.title}" (${a.date} • ${a.time}) silinsin mi?'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: Text('Vazgeç', style: TextStyle(color: Colors.grey.shade600)),
                ),
                Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFDC2626)],
                    ),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextButton(
                    onPressed: () => Navigator.pop(context, true),
                    style: TextButton.styleFrom(foregroundColor: Colors.white),
                    child: const Text('Sil'),
                  ),
                ),
              ],
            ),
          ),
        ) ??
        false;
  }

  Future<void> _addAppointmentSheet() async {
    final titleCtrl = TextEditingController();
    DateTime? date;
    TimeOfDay? time;

    final messenger = ScaffoldMessenger.of(context);

    final added = await showModalBottomSheet<Appointment>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        final inset = MediaQuery.of(sheetCtx).viewInsets.bottom;
        return Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF334155), Color(0xFF1E3A8A), Color(0xFF1E40AF)],
            ),
          ),
          child: SingleChildScrollView(
            padding: EdgeInsets.only(bottom: inset + 16, left: 16, right: 16, top: 16),
            child: StatefulBuilder(
              builder: (ctx, setS) => _GlassCard(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text(
                        'Randevu Ekle',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 20),
                      _GlassCard(
                        borderRadius: 12,
                        child: TextField(
                          controller: titleCtrl,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            labelText: 'Başlık (örn. Dahiliye)',
                            labelStyle: TextStyle(color: Colors.white70),
                            border: InputBorder.none,
                            contentPadding: EdgeInsets.all(16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Row(
                        children: [
                          Expanded(
                            child: _GlassCard(
                              borderRadius: 12,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final now = DateTime.now();
                                  final picked = await showDatePicker(
                                    context: ctx,
                                    firstDate: now,
                                    lastDate: DateTime(now.year + 3),
                                    initialDate: date ?? now,
                                  );
                                  if (picked != null) setS(() => date = picked);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.calendar_today, color: Colors.white70),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          date == null
                                              ? 'Tarih seç'
                                              : '${date!.day.toString().padLeft(2, '0')}.${date!.month.toString().padLeft(2, '0')}.${date!.year}',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _GlassCard(
                              borderRadius: 12,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () async {
                                  final picked = await showTimePicker(
                                    context: ctx,
                                    initialTime:
                                        time ?? TimeOfDay(hour: TimeOfDay.now().hour, minute: 0),
                                    builder: (c, child) => MediaQuery(
                                      data: MediaQuery.of(c).copyWith(alwaysUse24HourFormat: true),
                                      child: child!,
                                    ),
                                  );
                                  if (picked != null) setS(() => time = picked);
                                },
                                child: Container(
                                  padding: const EdgeInsets.all(16),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time, color: Colors.white70),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(
                                          time == null
                                              ? 'Saat seç'
                                              : '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}',
                                          style: const TextStyle(color: Colors.white),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 20),
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: const LinearGradient(
                            colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
                          ),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: TextButton.icon(
                          onPressed: () async {
                            final t = titleCtrl.text.trim();
                            if (t.isEmpty || date == null || time == null) {
                              messenger.showSnackBar(
                                const SnackBar(
                                  content: Text('Başlık, tarih ve saat gerekli.'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                              return;
                            }
                            final dateStr =
                                '${date!.year}-${date!.month.toString().padLeft(2, '0')}-${date!.day.toString().padLeft(2, '0')}';
                            final timeStr =
                                '${time!.hour.toString().padLeft(2, '0')}:${time!.minute.toString().padLeft(2, '0')}';
                            try {
                              final a = await AppointmentStore.add(t, dateStr, timeStr);
                              if (Navigator.of(sheetCtx).canPop()) {
                                Navigator.of(sheetCtx).pop(a);
                              }
                            } catch (e) {
                              messenger.showSnackBar(
                                SnackBar(
                                  content: Text('Kaydedilemedi: $e'),
                                  backgroundColor: Colors.redAccent,
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.save, color: Colors.white),
                          label: const Text('Kaydet', style: TextStyle(color: Colors.white, fontSize: 16)),
                          style: TextButton.styleFrom(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );

    if (added != null) {
      setState(() {});
      await _speakTodayIfNeeded();
    }
  }

  @override
  Widget build(BuildContext context) {
    final meds = _medsToday();
    final appts = _apptsToday();

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
                // Custom App Bar
                Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      const Text(
                        'Bugün',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const Spacer(),
                      _GlassCard(
                        borderRadius: 12,
                        child: IconButton(
                          tooltip: _autoSpeak ? 'Otomatik okuma: açık' : 'Otomatik okuma: kapalı',
                          icon: Icon(
                            _autoSpeak ? Icons.volume_up : Icons.volume_off,
                            color: Colors.white,
                          ),
                          onPressed: () {
                            setState(() => _autoSpeak = !_autoSpeak);
                            if (_autoSpeak) _speakTodayIfNeeded();
                          },
                        ),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    children: [
                      // Speak Button
                      _GlassCard(
                        child: Container(
                          width: double.infinity,
                          decoration: BoxDecoration(
                            gradient: _speaking
                                ? LinearGradient(colors: [Colors.grey.shade600, Colors.grey.shade700])
                                : const LinearGradient(colors: [Color(0xFF3B82F6), Color(0xFF2563EB)]),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: TextButton.icon(
                            onPressed: _speaking ? null : _speakNow,
                            icon: const Icon(Icons.play_arrow, color: Colors.white),
                            label: const Text(
                              'Bugünü Oku',
                              style: TextStyle(color: Colors.white, fontSize: 16),
                            ),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(vertical: 12),
                            ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 20),

                      // Randevular Bölümü
                      if (appts.isNotEmpty) ...[
                        _GlassCard(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: const Color(0xFF8B5CF6),
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: const Icon(Icons.event_note, color: Colors.white, size: 20),
                                    ),
                                    const SizedBox(width: 12),
                                    const Text(
                                      'Bugünkü Randevular',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                ...appts.map((a) => Container(
                                  margin: const EdgeInsets.only(bottom: 12),
                                  child: _GlassCard(
                                    borderRadius: 12,
                                    color: Colors.white.withOpacity(0.1),
                                    child: Dismissible(
                                      key: ValueKey(a.id),
                                      background: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        alignment: Alignment.centerLeft,
                                        padding: const EdgeInsets.only(left: 20),
                                        child: const Icon(Icons.delete, color: Colors.white),
                                      ),
                                      secondaryBackground: Container(
                                        decoration: BoxDecoration(
                                          color: Colors.red.withOpacity(0.8),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        alignment: Alignment.centerRight,
                                        padding: const EdgeInsets.only(right: 20),
                                        child: const Icon(Icons.delete, color: Colors.white),
                                      ),
                                      confirmDismiss: (_) => _confirmDelete(a),
                                      onDismissed: (_) async {
                                        await AppointmentStore.remove(a.id);
                                        if (!mounted) return;
                                        setState(() {});
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            content: Text('"${a.title}" silindi'),
                                            backgroundColor: Colors.green,
                                          ),
                                        );
                                      },
                                      child: ListTile(
                                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                                        title: Text(
                                          a.title,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        subtitle: Text(
                                          a.date,
                                          style: TextStyle(color: Colors.white.withOpacity(0.7)),
                                        ),
                                        trailing: Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFF22C55E),
                                                borderRadius: BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                a.time,
                                                style: const TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.w600,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(width: 8),
                                            IconButton(
                                              tooltip: 'Sil',
                                              icon: const Icon(Icons.delete_outline, color: Colors.white70),
                                              onPressed: () async {
                                                final ok = await _confirmDelete(a);
                                                if (!ok) return;
                                                await AppointmentStore.remove(a.id);
                                                if (!mounted) return;
                                                setState(() {});
                                                ScaffoldMessenger.of(context).showSnackBar(
                                                  SnackBar(
                                                    content: Text('"${a.title}" silindi'),
                                                    backgroundColor: Colors.green,
                                                  ),
                                                );
                                              },
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                )),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],

                      // İlaçlar Bölümü
                      _GlassCard(
                        child: Padding(
                          padding: const EdgeInsets.all(20),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.all(8),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF06B6D4),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Icon(Icons.medication_liquid, color: Colors.white, size: 20),
                                  ),
                                  const SizedBox(width: 12),
                                  const Text(
                                    'Bugünkü İlaçlar',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 18,
                                      fontWeight: FontWeight.bold, // ← tamamlandı
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // kayıt yoksa bilgi
                              if (meds.isEmpty)
                                Text(
                                  'Bugün için ilaç kaydı yok.',
                                  style: TextStyle(color: Colors.white.withOpacity(0.8)),
                                )
                              else
                                ...[
                                  for (final (title, time) in meds)
                                    Container(
                                      margin: const EdgeInsets.only(bottom: 12),
                                      child: _GlassCard(
                                        borderRadius: 12,
                                        color: Colors.white.withOpacity(0.08),
                                        child: ListTile(
                                          leading: const Icon(Icons.schedule, color: Colors.white70),
                                          title: Text(
                                            title,
                                            style: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          trailing: Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                            decoration: BoxDecoration(
                                              color: const Color(0xFF3B82F6),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: Text(
                                              time,
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                ],
                            ],
                          ),
                        ),
                      ),

                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
