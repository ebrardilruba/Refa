import 'dart:math';
import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:confetti/confetti.dart';

class LevelUpScreen extends StatefulWidget {
  final int level;
  final VoidCallback onNext;      // “Sonraki seviyeye geç” tıklanınca
  final VoidCallback? onClose;    // Kapatılırsa

  const LevelUpScreen({
    super.key,
    required this.level,
    required this.onNext,
    this.onClose,
  });

  @override
  State<LevelUpScreen> createState() => _LevelUpScreenState();
}

class _LevelUpScreenState extends State<LevelUpScreen> {
  late final ConfettiController _top;
  late final ConfettiController _bottom;
  late final ConfettiController _left;
  late final ConfettiController _right;
  late final ConfettiController _center;

  @override
  void initState() {
    super.initState();
    _top = ConfettiController(duration: const Duration(seconds: 6))..play();
    _bottom = ConfettiController(duration: const Duration(seconds: 6))..play();
    _left = ConfettiController(duration: const Duration(seconds: 6))..play();
    _right = ConfettiController(duration: const Duration(seconds: 6))..play();
    _center = ConfettiController(duration: const Duration(seconds: 3))
      ..play();
  }

  @override
  void dispose() {
    _top.dispose();
    _bottom.dispose();
    _left.dispose();
    _right.dispose();
    _center.dispose();
    super.dispose();
  }

  // Yıldız parçacığı şekli
  Path _starPath(Size size) {
    // Confetti, path’i kendi ölçekliyor; küçük bir yıldız yeterli.
    const n = 5;
    final path = Path();
    final extR = 10.0;
    final intR = 4.0;
    for (int i = 0; i < n * 2; i++) {
      final isEven = i.isEven;
      final r = isEven ? extR : intR;
      final a = pi * i / n - pi / 2;
      final x = r * cos(a);
      final y = r * sin(a);
      if (i == 0) {
        path.moveTo(x, y);
      } else {
        path.lineTo(x, y);
      }
    }
    path.close();
    return path;
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Stack(
      children: [
        // Arka planı hafif blur + karart
        Positioned.fill(
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 6, sigmaY: 6),
            child: Container(color: Colors.black.withOpacity(0.35)),
          ),
        ),

        // Konfetiler
        // Üstten ve alttan yağmur gibi
        Align(
          alignment: Alignment.topCenter,
          child: ConfettiWidget(
            confettiController: _top,
            blastDirection: pi / 2, // aşağı
            emissionFrequency: 0.08,
            numberOfParticles: 8,
            gravity: 0.15,
            colors: [cs.primary, cs.secondary, cs.tertiary, Colors.amber],
            createParticlePath: _starPath,
          ),
        ),
        Align(
          alignment: Alignment.bottomCenter,
          child: ConfettiWidget(
            confettiController: _bottom,
            blastDirection: -pi / 2, // yukarı
            emissionFrequency: 0.08,
            numberOfParticles: 8,
            gravity: 0.12,
            colors: [Colors.pinkAccent, Colors.lightBlue, Colors.greenAccent],
            createParticlePath: _starPath,
          ),
        ),
        // Soldan & sağdan
        Align(
          alignment: Alignment.centerLeft,
          child: ConfettiWidget(
            confettiController: _left,
            blastDirection: 0, // sağa
            emissionFrequency: 0.04,
            numberOfParticles: 6,
            gravity: 0.05,
            createParticlePath: _starPath,
          ),
        ),
        Align(
          alignment: Alignment.centerRight,
          child: ConfettiWidget(
            confettiController: _right,
            blastDirection: pi, // sola
            emissionFrequency: 0.04,
            numberOfParticles: 6,
            gravity: 0.05,
            createParticlePath: _starPath,
          ),
        ),
        // Ortada bir patlama
        Align(
          alignment: Alignment.center,
          child: ConfettiWidget(
            confettiController: _center,
            blastDirectionality: BlastDirectionality.explosive,
            shouldLoop: false,
            numberOfParticles: 30,
            gravity: 0.2,
            minimumSize: const Size(6, 6),
            maximumSize: const Size(12, 12),
            createParticlePath: _starPath,
          ),
        ),

        // Kart
        Center(
          child: Container(
            padding: const EdgeInsets.all(20),
            constraints: const BoxConstraints(maxWidth: 360),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.9),
              borderRadius: BorderRadius.circular(24),
              boxShadow: const [
                BoxShadow(blurRadius: 24, offset: Offset(0, 12), color: Colors.black26),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('TEBRİKLER!', style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontSize: 24, fontWeight: FontWeight.w900, color: cs.primary,
                )),
                const SizedBox(height: 8),
                Text('Seviye atladın', style: Theme.of(context).textTheme.bodyLarge),
                const SizedBox(height: 14),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
                  decoration: BoxDecoration(
                    color: cs.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Text(
                    'Seviye ${widget.level}',
                    style: TextStyle(
                      fontSize: 36,
                      fontWeight: FontWeight.w900,
                      color: cs.primary,
                      letterSpacing: 0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Expanded(
                      child: FilledButton(
                        onPressed: () {
                          Navigator.of(context).pop();    // ekranı kapat
                          widget.onNext();                 // sonraki seviyeye geç
                        },
                        child: const Text('Sonraki seviyeye geç'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    widget.onClose?.call();
                  },
                  child: const Text('Kapat'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
