// lib/level_up_overlay.dart
import 'dart:math';
import 'dart:ui' as ui; // ui.ImageFilter, ui.lerpDouble
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class LevelUpOverlay {
  static Future<void> show({
    required BuildContext context,
    required int level,
    VoidCallback? onReplay,
    VoidCallback? onNext,
  }) async {
    await showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'level_up',
      barrierColor: Colors.black.withOpacity(.35),
      transitionDuration: const Duration(milliseconds: 420),
      pageBuilder: (_, __, ___) {
        return _LevelUpContent(level: level, onReplay: onReplay, onNext: onNext);
      },
      transitionBuilder: (ctx, anim, _, child) {
        final curved = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: .96, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }
}

class _LevelUpContent extends StatefulWidget {
  final int level;
  final VoidCallback? onReplay;
  final VoidCallback? onNext;

  const _LevelUpContent({required this.level, this.onReplay, this.onNext});

  @override
  State<_LevelUpContent> createState() => _LevelUpContentState();
}

class _LevelUpContentState extends State<_LevelUpContent>
    with TickerProviderStateMixin {
  late final AnimationController _confettiCtrl;
  late final AnimationController _fireworksCtrl;

  @override
  void initState() {
    super.initState();
    _confettiCtrl =
        AnimationController(vsync: this, duration: const Duration(seconds: 2))
          ..forward();
    _fireworksCtrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1600),
    )..repeat();
  }

  @override
  void dispose() {
    _confettiCtrl.dispose();
    _fireworksCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Center(
      child: Stack(
        alignment: Alignment.center,
        children: [
          // Havai fişekler (arka plan)
          IgnorePointer(
            child: SizedBox.expand(
              child: AnimatedBuilder(
                animation: _fireworksCtrl,
                builder: (_, __) =>
                    CustomPaint(painter: _FireworksPainter(_fireworksCtrl.value)),
              ),
            ),
          ),

          // Konfetiler — YANLARDAN İÇERİ
          IgnorePointer(
            child: SizedBox.expand(
              child: AnimatedBuilder(
                animation: _confettiCtrl,
                builder: (_, __) =>
                    CustomPaint(painter: _SideConfettiPainter(_confettiCtrl.value)),
              ),
            ),
          ),

          // Okunabilir kart
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: _GlassCard(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  _TrophyWithLevel(level: widget.level), // ← kupa içinde seviye
                  const SizedBox(height: 12),

                  // Başlık — underline kesin kapalı
                  DefaultTextStyle.merge(
                    style: const TextStyle(
                      decoration: TextDecoration.none,
                      decorationColor: Colors.transparent,
                    ),
                    child: Text(
                      'Tebrikler! Seviye Geçildi 🎉',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.nunito(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.black,
                        height: 1.1,
                        decoration: TextDecoration.none,
                      ),
                    ),
                  ),

                  // Alt metin kaldırıldı
                  const SizedBox(height: 16),

                  // Buton — dinamik seviye
                  FilledButton.tonal(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onNext?.call();
                    },
                    style: FilledButton.styleFrom(
                      minimumSize: const Size.fromHeight(46),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 12),
                      textStyle: GoogleFonts.nunito(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        decoration: TextDecoration.none,
                      ),
                    ),
                    child: Text('${widget.level + 1}. seviyeye geç'),
                  ),

                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      widget.onReplay?.call();
                    },
                    style: TextButton.styleFrom(
                      textStyle: GoogleFonts.nunito(
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                        decoration: TextDecoration.none,
                      ),
                      foregroundColor: cs.primary,
                    ),
                    child: const Text('Tekrar oyna'),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Kupa ikonu + ortasında biten seviye numarası
class _TrophyWithLevel extends StatelessWidget {
  final int level;
  const _TrophyWithLevel({required this.level});

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        const Icon(Icons.emoji_events_rounded, size: 64, color: Colors.amber),
        // Seviye numarası — küçük gölge ile okunaklı
        Text(
          '$level',
          style: GoogleFonts.nunito(
            fontSize: 22,
            fontWeight: FontWeight.w900,
            color: Colors.black87,
            height: 1,
            decoration: TextDecoration.none,
            shadows: const [
              Shadow(blurRadius: 2, color: Colors.white, offset: Offset(0, 0)),
            ],
          ),
        ),
      ],
    );
  }
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    // Daha az şeffaf: beyaz %90 opak, blur hafif (okunabilirlik için)
    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: BackdropFilter(
        filter: ui.ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(.9),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: Colors.white.withOpacity(.95)),
          ),
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );
  }
}

/// YAN KONFETİ: soldan ve sağdan merkeze doğru akar, hafif dalgalı.
class _SideConfettiPainter extends CustomPainter {
  final double t; // 0..1
  _SideConfettiPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    const count = 160;
    final paint = Paint()..style = PaintingStyle.fill;

    for (int i = 0; i < count; i++) {
      // Deterministic seeds
      final rx = ((i * 37) % 101) / 100.0;
      final ry = ((i * 73) % 101) / 100.0;

      final fromLeft = i.isEven; // yarısı soldan, yarısı sağdan
      final startX = fromLeft ? -40.0 - rx * 80 : size.width + 40.0 + rx * 80;
      final targetX = size.width * (.1 + .8 * rx); // ekran içine rastgele hedef
      final x = ui.lerpDouble(startX, targetX, t)!;

      // Y’de hafif sinüs dalgası + rastgele dağılım
      final baseY = ry * size.height;
      final wobble = sin((rx * 8 + t * 12) * pi) * 10;
      final y = baseY + wobble;

      // Renk ve şekil
      final hue = (i * 11) % 360;
      paint.color =
          HSLColor.fromAHSL(1, hue.toDouble(), .75, .55).toColor().withOpacity(.9);

      final kind = i % 3;
      final s = 6.0 + (i % 7);

      if (kind == 0) {
        canvas.save();
        canvas.translate(x, y);
        canvas.rotate(((i % 360) + t * 14) * pi / 180);
        canvas.drawRect(Rect.fromCenter(center: Offset.zero, width: s, height: s), paint);
        canvas.restore();
      } else if (kind == 1) {
        canvas.drawCircle(Offset(x, y), s * .5, paint);
      } else {
        final path = Path()
          ..moveTo(x, y - s / 2)
          ..lineTo(x - s / 2, y + s / 2)
          ..lineTo(x + s / 2, y + s / 2)
          ..close();
        canvas.drawPath(path, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SideConfettiPainter old) => old.t != t;
}

/// Basit havai fişek efekti (yanlarda konfeti ile birlikte)
class _FireworksPainter extends CustomPainter {
  final double t; // 0..1 loop
  _FireworksPainter(this.t);

  @override
  void paint(Canvas canvas, Size size) {
    final centers = [
      Offset(size.width * .25, size.height * .30),
      Offset(size.width * .75, size.height * .28),
      Offset(size.width * .20, size.height * .55),
      Offset(size.width * .80, size.height * .58),
      Offset(size.width * .50, size.height * .35),
    ];

    for (int i = 0; i < 4; i++) {
      _drawBurst(canvas, centers[i], i);
    }
  }

  void _drawBurst(Canvas canvas, Offset center, int seed) {
    final localT = (t + (seed * .2)) % 1.0;
    final progress = Curves.easeOut.transform(localT);

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeWidth = ui.lerpDouble(2, .3, progress)!;

    final hue = (seed * 80 + progress * 360) % 360;
    paint.color = HSLColor.fromAHSL(1, hue.toDouble(), .8, .6).toColor();

    const rays = 28;
    final radius = ui.lerpDouble(0, 80 + (seed + 1) * 10.0, progress)!;

    for (int i = 0; i < rays; i++) {
      final a = (i / rays) * 2 * pi;
      final dir = Offset(cos(a), sin(a));
      final p1 = center + dir * (radius * .25);
      final p2 = center + dir * radius;
      canvas.drawLine(p1, p2, paint);
    }

    final dotPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = paint.color.withOpacity(.9);

    for (int i = 0; i < 24; i++) {
      final a = (i / 24) * 2 * pi + seed * .2;
      final r = radius * (.3 + (i % 7) / 10);
      final p = center + Offset(cos(a), sin(a)) * r;
      canvas.drawCircle(p, 1.5, dotPaint);
    }
  }

  @override
  bool shouldRepaint(covariant _FireworksPainter old) => old.t != t;
}
