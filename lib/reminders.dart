// lib/reminders.dart
import 'dart:convert';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// ====== Model ======
class MedReminder {
  final int id;
  String title;
  List<String> times; // "HH:mm"
  bool active;

  MedReminder({
    required this.id,
    required this.title,
    required this.times,
    this.active = true,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'times': times,
        'active': active,
      };

  static MedReminder fromMap(Map<String, dynamic> m) => MedReminder(
        id: m['id'] as int,
        title: m['title'] as String,
        times: (m['times'] as List).cast<String>(),
        active: (m['active'] as bool?) ?? true,
      );
}

/// ====== Depo (kalıcı) ======
class ReminderStore {
  static const _key = 'reminders';
  static final List<MedReminder> _items = [];
  static int _id = 1;

  static List<MedReminder> all() => List.unmodifiable(_items);

  static Future<void> init() async {
    final sp = await SharedPreferences.getInstance();
    final raw = sp.getString(_key);
    _items.clear();
    if (raw != null && raw.isNotEmpty) {
      final list = (jsonDecode(raw) as List).cast<Map<String, dynamic>>();
      _items.addAll(list.map(MedReminder.fromMap));
      _id = (_items.isEmpty ? 0 : _items.map((e) => e.id).reduce((a, b) => a > b ? a : b)) + 1;
    }
  }

  static Future<void> _save() async {
    final sp = await SharedPreferences.getInstance();
    await sp.setString(_key, jsonEncode(_items.map((e) => e.toMap()).toList()));
  }

  static Future<MedReminder> add(String title, List<String> times) async {
    final r = MedReminder(id: _id++, title: title, times: List<String>.from(times));
    _items.add(r);
    await _save();
    return r;
  }

  static Future<void> update(MedReminder r) async {
    final i = _items.indexWhere((e) => e.id == r.id);
    if (i >= 0) _items[i] = r;
    await _save();
  }

  static Future<void> toggle(int id, bool active) async {
    final i = _items.indexWhere((e) => e.id == id);
    if (i >= 0) _items[i].active = active;
    await _save();
  }

  static Future<void> remove(int id) async {
    _items.removeWhere((e) => e.id == id);
    await _save();
  }
}

/// ====== UI ======
class RemindersPage extends StatefulWidget {
  const RemindersPage({super.key});
  @override
  State<RemindersPage> createState() => _RemindersPageState();
}

class _RemindersPageState extends State<RemindersPage> {
  List<MedReminder> get _list => ReminderStore.all();

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
                  _GlassHeader(reminderCount: _list.length),
                  
                  const SizedBox(height: 24),
                  
                  // Title
                  const Text(
                    'Hatırlatıcılar',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  
                  const SizedBox(height: 8),
                  
                  Text(
                    'İlaç ve randevu hatırlatmaları',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                  
                  const SizedBox(height: 24),
                  
                  // Content
                  Expanded(
                    child: _list.isEmpty ? _EmptyState() : _RemindersList(list: _list, onUpdate: () => setState(() {})),
                  ),
                ],
              ),
            ),
          ),

          // Glass FAB
          Positioned(
            bottom: 34,
            right: 24,
            child: _GlassFAB(
              onPressed: () async {
                final added = await showModalBottomSheet<MedReminder>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const AddEditReminderSheet(),
                );
                if (added != null && mounted) setState(() {});
              },
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
  final int reminderCount;
  
  const _GlassHeader({required this.reminderCount});

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
                  color: const Color(0xFF3B82F6),
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
                  Icons.notifications,
                  color: Colors.white,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'İlaç ve Randevu',
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
                child: Text(
                  reminderCount == 0 ? 'Boş' : '$reminderCount adet',
                  style: const TextStyle(
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

class _GlassFAB extends StatelessWidget {
  final VoidCallback onPressed;

  const _GlassFAB({required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: GestureDetector(
          onTap: onPressed,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.20),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withOpacity(0.30), width: 1),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 12,
                  offset: Offset(0, 6),
                ),
              ],
            ),
            child: const Icon(
              Icons.add,
              color: Colors.white,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: ClipRRect(
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
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.alarm_off,
                  size: 48,
                  color: Colors.white.withOpacity(0.6),
                ),
                const SizedBox(height: 16),
                Text(
                  'Henüz hatırlatıcı yok',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Sağ alttaki "+" butonuyla\nilk hatırlatıcını oluştur',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 14,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RemindersList extends StatelessWidget {
  final List<MedReminder> list;
  final VoidCallback onUpdate;

  const _RemindersList({required this.list, required this.onUpdate});

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 100),
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 16),
      itemBuilder: (context, index) {
        final reminder = list[index];
        return _GlassReminderCard(
          reminder: reminder,
          onToggle: (v) async {
            await ReminderStore.toggle(reminder.id, v);
            onUpdate();
          },
          onEdit: () async {
            final updated = await showModalBottomSheet<MedReminder>(
              context: context,
              isScrollControlled: true,
              useSafeArea: true,
              backgroundColor: Colors.transparent,
              builder: (_) => AddEditReminderSheet(existing: reminder),
            );
            if (updated != null) onUpdate();
          },
          onDelete: () async {
            await ReminderStore.remove(reminder.id);
            onUpdate();
          },
        );
      },
    );
  }
}

class _GlassReminderCard extends StatelessWidget {
  final MedReminder reminder;
  final ValueChanged<bool> onToggle;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _GlassReminderCard({
    required this.reminder,
    required this.onToggle,
    required this.onEdit,
    required this.onDelete,
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
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Status indicator
              Container(
                width: 4,
                height: 40,
                decoration: BoxDecoration(
                  color: reminder.active 
                    ? Colors.greenAccent 
                    : Colors.white.withOpacity(0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      reminder.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      runSpacing: 4,
                      children: reminder.times.map((time) {
                        return Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.20),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            time,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        );
                      }).toList(),
                    ),
                  ],
                ),
              ),
              // Controls
              Column(
                children: [
                  Switch(
                    value: reminder.active,
                    onChanged: onToggle,
                    activeColor: Colors.greenAccent,
                    inactiveThumbColor: Colors.white.withOpacity(0.6),
                    inactiveTrackColor: Colors.white.withOpacity(0.2),
                  ),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'edit') onEdit();
                      if (v == 'delete') onDelete();
                    },
                    icon: Icon(
                      Icons.more_vert,
                      color: Colors.white.withOpacity(0.8),
                    ),
                    color: Colors.white,
                    itemBuilder: (_) => const [
                      PopupMenuItem(value: 'edit', child: Text('Düzenle')),
                      PopupMenuItem(value: 'delete', child: Text('Sil')),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// ====== Add / Edit Sheet ======
class AddEditReminderSheet extends StatefulWidget {
  final MedReminder? existing;
  const AddEditReminderSheet({super.key, this.existing});

  @override
  State<AddEditReminderSheet> createState() => _AddEditReminderSheetState();
}

class _AddEditReminderSheetState extends State<AddEditReminderSheet> {
  final _form = GlobalKey<FormState>();
  late TextEditingController _title;
  late List<String> _times;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.existing?.title ?? '');
    _times = List<String>.from(widget.existing?.times ?? ['08:00']);
  }

  @override
  void dispose() {
    _title.dispose();
    super.dispose();
  }

  Future<void> _pickTime(int index) async {
    final parts = _times[index].split(':');
    final initial = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );
    if (picked != null) {
      setState(() => _times[index] = _fmt(picked));
    }
  }

  String _fmt(TimeOfDay t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.of(context).viewInsets.bottom;

    return Container(
      padding: EdgeInsets.only(bottom: bottom),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.95),
              borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
              border: Border.all(color: Colors.white.withOpacity(0.50), width: 1),
            ),
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Handle
                  Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.grey.withOpacity(0.3),
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Title
                  Text(
                    widget.existing == null ? 'Hatırlatıcı Ekle' : 'Hatırlatıcıyı Düzenle',
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 24),
                  // Medicine name
                  TextFormField(
                    controller: _title,
                    decoration: InputDecoration(
                      labelText: 'İlaç adı',
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      filled: true,
                      fillColor: Colors.white.withOpacity(0.8),
                    ),
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Lütfen bir ad yazın' : null,
                  ),
                  const SizedBox(height: 20),
                  // Times
                  ListView.separated(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: _times.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 12),
                    itemBuilder: (context, i) {
                      return Container(
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey.withOpacity(0.2)),
                        ),
                        padding: const EdgeInsets.all(8),
                        child: Row(
                          children: [
                            Expanded(
                              child: GestureDetector(
                                onTap: () => _pickTime(i),
                                child: Container(
                                  padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withOpacity(0.8),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(Icons.access_time, size: 20),
                                      const SizedBox(width: 12),
                                      Text(
                                        _times[i],
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            IconButton(
                              onPressed: _times.length > 1 ? () => setState(() => _times.removeAt(i)) : null,
                              icon: Icon(
                                Icons.delete_outline,
                                color: _times.length > 1 ? Colors.red : Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 16),
                  // Add time button
                  Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: () => setState(() => _times.add('08:00')),
                      icon: const Icon(Icons.add),
                      label: const Text('Saat ekle'),
                      style: TextButton.styleFrom(
                        backgroundColor: Colors.blue.withOpacity(0.1),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Save button
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: FilledButton(
                      onPressed: () async {
                        FocusScope.of(context).unfocus();
                        if (!_form.currentState!.validate()) return;

                        final title = _title.text.trim();
                        final times = List<String>.from(_times);

                        if (widget.existing == null) {
                          final r = await ReminderStore.add(title, times);
                          if (!context.mounted) return;
                          Navigator.of(context, rootNavigator: true).pop(r);
                        } else {
                          widget.existing!
                            ..title = title
                            ..times = times;
                          await ReminderStore.update(widget.existing!);
                          if (!context.mounted) return;
                          Navigator.of(context, rootNavigator: true).pop(widget.existing);
                        }
                      },
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF3B82F6),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      ),
                      child: const Text(
                        'Kaydet',
                        style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
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
  }
}