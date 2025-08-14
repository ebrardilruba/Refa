import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'level_up_overlay.dart';

class MemoryGamePage extends StatefulWidget {
  const MemoryGamePage({super.key});

  @override
  State<MemoryGamePage> createState() => _MemoryGamePageState();
}

class _MemoryGamePageState extends State<MemoryGamePage> {
  int level = 1;

  // güvenli başlangıç
  List<_CardModel> _deck = const [];

  int _firstIndex = -1;
  int _secondIndex = -1;
  bool _lock = false;

  static const _flipBackDelay = Duration(milliseconds: 320);
  static const _flipAnimMs = 140;

  static const List<String> _emojiPool = [
    '🍎','🍌','🍇','🍉','🍒','🍍','🥝','🥑','🍓','🍋',
    '🧩','🎈','⚽️','🏀','🏐','🎲','🎯','🎹','🎧','🎮',
    '🚗','🚕','🚌','🚑','🚒','✈️','🚀','⛵️','🚲','🏍️',
    '🐶','🐱','🐻','🐼','🦊','🦁','🐷','🐸','🐵','🦄',
  ];

  @override
  void initState() {
    super.initState();
    debugPrint('>>> MemoryGamePage V2 açıldı');
    _deck = _makeDeck(level);
  }

  List<_CardModel> _makeDeck(int lvl) {
    final pairCount = min(_emojiPool.length, lvl + 1); // L1=2 çift → 4 kart
    final pool = List.of(_emojiPool)..shuffle();
    final symbols = pool.take(pairCount).toList();

    final deck = <_CardModel>[];
    for (final s in symbols) {
      deck.add(_CardModel(symbol: s));
      deck.add(_CardModel(symbol: s));
    }
    deck.shuffle();
    return deck;
  }

  void _reseed(int lvl) {
    setState(() {
      _deck = _makeDeck(lvl);
      _firstIndex = -1;
      _secondIndex = -1;
      _lock = false;
    });
  }

  int _gridColumnsForCount(int n) {
    if (n <= 4) return 2;
    if (n <= 12) return 3;
    return 4;
  }

  bool get _isCompleted => _deck.every((c) => c.matched);

  void _onCardTap(int i) {
    if (_lock) return;
    final card = _deck[i];
    if (card.matched || card.faceUp) return;

    setState(() => card.faceUp = true);

    if (_firstIndex == -1) {
      _firstIndex = i;
      return;
    }
    if (_secondIndex == -1 && i != _firstIndex) {
      _secondIndex = i;
      _checkMatch();
    }
  }

  Future<void> _checkMatch() async {
    if (_firstIndex < 0 || _secondIndex < 0) return;

    final a = _deck[_firstIndex];
    final b = _deck[_secondIndex];

    if (a.symbol == b.symbol) {
      setState(() {
        a.matched = true;
        b.matched = true;
        _firstIndex = -1;
        _secondIndex = -1;
      });
      if (_isCompleted) {
        await Future.delayed(const Duration(milliseconds: 220));
        if (!mounted) return;
        await _showWinOverlay();
      }
    } else {
      _lock = true;
      await Future.delayed(_flipBackDelay);
      if (!mounted) return;
      setState(() {
        a.faceUp = false;
        b.faceUp = false;
        _firstIndex = -1;
        _secondIndex = -1;
        _lock = false;
      });
    }
  }

  void _resetSameLevel() => _reseed(level);
  void _nextLevel() { setState(() => level++); _reseed(level); }
  void _prevLevel() { if (level == 1) return; setState(() => level--); _reseed(level); }

  Future<void> _showWinOverlay() async {
    await LevelUpOverlay.show(
      context: context,
      level: level,
      onReplay: _resetSameLevel,
      onNext: _nextLevel,
    );
  }

  @override
  Widget build(BuildContext context) {
    final count = _deck.length;
    final cols = _gridColumnsForCount(count);

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
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _GlassHeader(level: level),
                  const SizedBox(height: 24),
                  const Text(
                    'Hafıza Oyunu',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Eşleştir ve ilerle • Seviye $level',
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.8),
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 24),

                  Expanded(
                    child: GridView.builder(
                      padding: EdgeInsets.zero,
                      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                        crossAxisCount: cols,
                        mainAxisSpacing: 14,
                        crossAxisSpacing: 14,
                      ),
                      itemCount: count,
                      itemBuilder: (context, i) => _MemoryCard(
                        model: _deck[i],
                        onTap: () => _onCardTap(i),
                        flipMs: _flipAnimMs,
                      ),
                    ),
                  ),

                  const SizedBox(height: 16),
                  _GlassControlPanel(
                    level: level,
                    onPrevLevel: level > 1 ? _prevLevel : null,
                    onResetLevel: _resetSameLevel,
                    onNextLevel: _nextLevel,
                  ),
                ],
              ),
            ),
          ),

          // home indicator fake
          Positioned(
            bottom: 8, left: 0, right: 0,
            child: Center(
              child: Container(
                width: 144, height: 4,
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

// =================== yardımcı widgetlar ===================

class _GlassHeader extends StatelessWidget {
  final int level;
  const _GlassHeader({required this.level});

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
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
          child: Row(
            children: [
              Container(
                width: 40, height: 40,
                decoration: BoxDecoration(
                  color: const Color(0xFF22C55E),
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 8, offset: Offset(0, 4))],
                ),
                child: const Icon(Icons.memory_rounded, color: Colors.white, size: 20),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Zihin Egzersizi',
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 16),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.20), borderRadius: BorderRadius.circular(12)),
                child: Text(
                  'Seviye $level',
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 12),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GlassControlPanel extends StatelessWidget {
  final int level;
  final VoidCallback? onPrevLevel;
  final VoidCallback onResetLevel;
  final VoidCallback onNextLevel;

  const _GlassControlPanel({
    required this.level,
    this.onPrevLevel,
    required this.onResetLevel,
    required this.onNextLevel,
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
            boxShadow: const [BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6))],
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _ControlButton(icon: Icons.chevron_left_rounded, onTap: onPrevLevel, enabled: onPrevLevel != null),
              _ControlButton(icon: Icons.refresh_rounded, onTap: onResetLevel, enabled: true),
              _ControlButton(icon: Icons.chevron_right_rounded, onTap: onNextLevel, enabled: true),
            ],
          ),
        ),
      ),
    );
  }
}

class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback? onTap;
  final bool enabled;

  const _ControlButton({required this.icon, this.onTap, required this.enabled});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        width: 48, height: 48,
        decoration: BoxDecoration(
          color: enabled ? Colors.white.withOpacity(0.20) : Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(icon, color: enabled ? Colors.white : Colors.white.withOpacity(0.3), size: 24),
      ),
    );
  }
}

class _MemoryCard extends StatelessWidget {
  final _CardModel model;
  final VoidCallback onTap;
  final int flipMs;

  const _MemoryCard({required this.model, required this.onTap, required this.flipMs});

  @override
  Widget build(BuildContext context) {
    final showingFront = model.faceUp || model.matched;

    return AnimatedContainer(
      duration: Duration(milliseconds: flipMs),
      curve: Curves.easeOut,
      decoration: BoxDecoration(
        color: showingFront ? Colors.white : const Color(0xFFE2E8F0),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: showingFront ? const Color(0xFF3B82F6).withOpacity(0.3) : const Color(0xFFE6E8F0),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(blurRadius: 18, spreadRadius: 0, offset: const Offset(0, 10), color: Colors.black.withOpacity(.08)),
        ],
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: onTap,
          child: Center(
            child: AnimatedScale(
              duration: Duration(milliseconds: flipMs),
              scale: showingFront ? 1.0 : .92,
              curve: Curves.easeOut,
              child: AnimatedOpacity(
                duration: Duration(milliseconds: flipMs),
                opacity: showingFront ? 1 : 0,
                child: Text(model.symbol, style: const TextStyle(fontSize: 36)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CardModel {
  final String symbol;
  bool faceUp;
  bool matched;

  _CardModel({required this.symbol, this.faceUp = false, this.matched = false});
}
