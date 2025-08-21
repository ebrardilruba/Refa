
import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

class EnabizPage extends StatefulWidget {
  const EnabizPage({super.key});

  @override
  State<EnabizPage> createState() => _EnabizPageState();
}

class _EnabizPageState extends State<EnabizPage> {
  // ---- TTS hızları ----
  static const double _rateGeneral = 0.85; // genel
  static const double _rateSummary = 0.80; // özet
  static const double _rateDetails = 0.72; // bulgular (daha yavaş)

  // ---- State ----
  String? _fileName;
  Uint8List? _pdfBytes;
  bool _busy = false;
  double _progress = 0;
  String _rawText = '';
  List<LabItem> _items = [];

  // ---- TTS ----
  final _tts = FlutterTts();
  bool _speaking = false;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  Future<void> _initTts() async {
    await _tts.setLanguage("tr-TR");
    await _tts.setSpeechRate(_rateGeneral);
    await _tts.setPitch(1.0);
    await _tts.awaitSpeakCompletion(true);
    _tts.setStartHandler(() => setState(() => _speaking = true));
    _tts.setCompletionHandler(() => setState(() => _speaking = false));
    _tts.setCancelHandler(() => setState(() => _speaking = false));
  }

  Future<void> _stopTts() async {
    await _tts.stop();
    if (mounted) setState(() => _speaking = false);
  }

  // ---- File pick ----
  Future<void> _pickPdf() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: const ['pdf'],
        withData: true,
      );
      if (res == null || res.files.isEmpty) return;

      final f = res.files.single;
      Uint8List? bytes = f.bytes;
      if (bytes == null && f.path != null) {
        bytes = await File(f.path!).readAsBytes();
      }
      if (bytes == null) {
        _snack('Dosya okunamadı.', err: true);
        return;
      }

      setState(() {
        _fileName = f.name;
        _pdfBytes = bytes;
        _rawText = '';
        _items = [];
        _progress = 0;
      });

      _snack('PDF seçildi: ${f.name}');
    } catch (e) {
      _snack('PDF seçilemedi: $e', err: true);
    }
  }

  // ---- OCR ----
  Future<void> _runOcr() async {
    if (_pdfBytes == null) return;

    setState(() {
      _busy = true;
      _rawText = '';
      _items = [];
      _progress = 0;
    });

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    pdfx.PdfDocument? doc;

    try {
      doc = await pdfx.PdfDocument.openData(_pdfBytes!);
      final pageCount = min(3, doc.pagesCount); // ilk 3 sayfa genelde yetiyor
      final buf = StringBuffer();

      for (var i = 1; i <= pageCount; i++) {
        final page = await doc.getPage(i);
        try {
          final img = await page.render(
            width: page.width * 1.9,   // double; toInt YOK
            height: page.height * 1.9, // double; toInt YOK
            format: pdfx.PdfPageImageFormat.png,
          );

          if (img != null) {
            final tmp = await File('${Directory.systemTemp.path}/enabiz_ocr_$i.png').create();
            await tmp.writeAsBytes(img.bytes, flush: true);

            final input = InputImage.fromFilePath(tmp.path);
            final result = await recognizer.processImage(input);

            if (result.text.isNotEmpty) {
              buf.writeln('=== SAYFA $i ===');
              buf.writeln(result.text);
              buf.writeln();
            }
          }
        } finally {
          await page.close();
          if (mounted) setState(() => _progress = i / pageCount);
        }
      }

      final raw = _normalize(buf.toString());
      final parsed = _parseLabs(raw);

      setState(() {
        _rawText = raw;
        _items = parsed;
      });

      if (_items.isEmpty) {
        _snack('OCR tamam ama test/parsing zayıf. PDF düzeni tablo değil veya kalite düşük olabilir.',
            err: true);
      } else {
        _snack('OCR + analiz tamam: ${_items.length} öğe.');
      }
    } catch (e) {
      _snack('OCR hata: $e', err: true);
    } finally {
      await recognizer.close();
      await doc?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- Parsing ----
  List<LabItem> _parseLabs(String text) {
    final lines = text
        .split('\n')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toList();

    final items = <LabItem>[];

    // Yaygın test adları
    final testNameRegexes = <RegExp>[
      RegExp(r'^(TSH)\b', caseSensitive: false),
      RegExp(r'^(Serbest\s*T4|Free\s*T4|FT4)\b', caseSensitive: false),
      RegExp(r'^(Serbest\s*T3|Free\s*T3|FT3)\b', caseSensitive: false),
      RegExp(r'^(Anti.*TPO|Tiro(peroksidaz|id) ?(antikor|ab)|TPO\s*Ab)\b', caseSensitive: false),
      RegExp(r'^(Anti.*T(g|iroglobulin)|Tg\s*Ab|Anti\s*Tg)\b', caseSensitive: false),
      // Fallback: alfabetik satırlar (başlık gibi)
      RegExp(r'^[A-Za-zĞÜŞİÖÇğüşiöç\(\)\/\.\-\s]{3,}$'),
    ];

    // Değer (tek sayı ya da < / > ile) + opsiyonel birim
    final valueRe = RegExp(
        r'^(?<sign>[<>≤≥]?)\s*(?<val>\d+(?:[.,]\d+)?)\s*(?<unit>[A-Za-zµμ%\/\^\-\*\·]+)?$');

    // Referans aralığı (etiketli)
    final refTags =
        RegExp(r'(ref|referans|aralık|normal|range)', caseSensitive: false);
    final rangeRe = RegExp(
        r'(?<lo>\d+(?:[.,]\d+)?)\s*[-–—]\s*(?<hi>\d+(?:[.,]\d+)?)\s*(?<unit>[A-Za-zµμ%\/\^\-\*\·]+)?');

    LabItem? cur;

    String? pickUnit(String? a, String? b) {
      String norm(String s) => s.replaceAll(RegExp(r'[^A-Za-zµμ%\/]'), '');
      if ((a ?? '').isEmpty) return b;
      if ((b ?? '').isEmpty) return a;
      return norm(a!) == norm(b!) ? a : a; // çakışırsa ilkini koru
    }

    for (var i = 0; i < lines.length; i++) {
      final ln = lines[i];

      // 1) Test adı mı?
      final isName = testNameRegexes.any((re) => re.hasMatch(ln));
      if (isName) {
        if (cur != null) items.add(cur);
        cur = LabItem(name: ln);
        continue;
      }

      if (cur == null) continue;

      // 2) Etiketli referans satırı
      if (refTags.hasMatch(ln)) {
        final m = rangeRe.firstMatch(ln);
        if (m != null) {
          cur.refLow = _num(m.namedGroup('lo'));
          cur.refHigh = _num(m.namedGroup('hi'));
          cur.unit = pickUnit(cur.unit, m.namedGroup('unit'));
        }
        continue;
      }

      // 3) Etiketsiz "lo–hi" aralığı
      final rm = rangeRe.firstMatch(ln);
      if (rm != null && (cur.refLow == null || cur.refHigh == null)) {
        cur.refLow = _num(rm.namedGroup('lo'));
        cur.refHigh = _num(rm.namedGroup('hi'));
        cur.unit = pickUnit(cur.unit, rm.namedGroup('unit'));
        continue;
      }

      // 4) Tek değer (örn 7.84, <0.008)
      final vm = valueRe.firstMatch(ln);
      if (vm != null) {
        final sign = (vm.namedGroup('sign') ?? '').trim();
        final v = _num(vm.namedGroup('val'));
        cur.value = v;
        cur.valueStr = (sign.isNotEmpty ? '$sign ' : '') + (v?.toString() ?? '');
        cur.unit = pickUnit(cur.unit, vm.namedGroup('unit'));
        continue;
      }

      // 5) "Sonuç" ipucu → bir sonraki satır değer olabilir
      if (ln.toLowerCase().contains('sonuç') && i + 1 < lines.length) {
        final next = lines[i + 1];
        final nm = valueRe.firstMatch(next);
        if (nm != null) {
          final sign = (nm.namedGroup('sign') ?? '').trim();
          final v = _num(nm.namedGroup('val'));
          cur.value = v;
          cur.valueStr = (sign.isNotEmpty ? '$sign ' : '') + (v?.toString() ?? '');
          cur.unit = pickUnit(cur.unit, nm.namedGroup('unit'));
        }
        i++;
        continue;
      }
    }

    if (cur != null) items.add(cur);

    // Flag hesapla
    for (final it in items) {
      it.flag = _flag(it);
    }

    return items
        .where((e) => e.name.trim().length >= 3 && (e.value != null || e.valueStr != null))
        .toList();
  }

  static double? _num(String? s) {
    if (s == null) return null;
    final t = s.replaceAll(',', '.');
    return double.tryParse(t);
  }

  static String _normalize(String raw) {
    var s = raw
        .replaceAll('\u00A0', ' ')
        .replaceAll('\u2212', '-')
        .replaceAll('–', '-')
        .replaceAll('—', '-')
        .replaceAll('·', ' ')
        .replaceAll('•', ' ')
        .replaceAll('\r', ' ')
        .replaceAll('\t', ' ')
        .replaceAll(RegExp('[ ]{2,}'), ' ')
        .trim();

    s = s
        .replaceAll('µ', 'u')
        .replaceAll('μ', 'u')
        .replaceAll('ı', 'i')
        .replaceAll('İ', 'I')
        .replaceAll('ş', 's')
        .replaceAll('Ş', 'S')
        .replaceAll('ğ', 'g')
        .replaceAll('Ğ', 'G')
        .replaceAll('ç', 'c')
        .replaceAll('Ç', 'C')
        .replaceAll('ö', 'o')
        .replaceAll('Ö', 'O')
        .replaceAll('ü', 'u')
        .replaceAll('Ü', 'U');

    // 12,34 -> 12.34
    s = s.replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}.${m[2]}');
    return s;
  }

  static LabFlag _flag(LabItem it) {
    if (it.refLow == null || it.refHigh == null || it.value == null) {
      return LabFlag.unknown;
    }
    if (it.value! < it.refLow!) return LabFlag.low;
    if (it.value! > it.refHigh!) return LabFlag.high;
    return LabFlag.normal;
  }

  // ---- TTS metinleri ----
  String _summaryText(List<LabItem> list) {
    if (list.isEmpty) return 'Herhangi bir test okunamadı.';

    final highs = list.where((e) => e.flag == LabFlag.high).toList();
    final lows = list.where((e) => e.flag == LabFlag.low).toList();
    final normals = list.where((e) => e.flag == LabFlag.normal).toList();
    final outOfRef = [...highs, ...lows];

    final buf = StringBuffer();
    buf.write('Toplam ${list.length} test var. ');
    buf.write('${highs.length} yüksek, ${lows.length} düşük, ${normals.length} normal. ');

    if (outOfRef.isNotEmpty) {
      buf.write('Referans dışı ${outOfRef.length} sonuç: ');
      final maxList = outOfRef.take(5).map((e) {
        final v = e.valueStr ?? (e.value?.toString() ?? '?');
        final unit = (e.unit != null && e.unit!.isNotEmpty) ? ' ${e.unit}' : '';
        final ref = (e.refLow != null && e.refHigh != null)
            ? ' (referans ${_fmt(e.refLow)} - ${_fmt(e.refHigh)}$unit)'
            : '';
        return '${e.name}: $v$unit$ref';
      }).join(', ');
      buf.write(maxList);
      if (outOfRef.length > 5) {
        buf.write(', ve ${outOfRef.length - 5} sonuç daha.');
      }
    }

    return buf.toString().trim();
  }

  String _detailsText(List<LabItem> list) {
    if (list.isEmpty) return 'Detay yok.';

    String line(LabItem e) {
      final v = e.valueStr ?? (e.value?.toString() ?? '?');
      final unit = (e.unit != null && e.unit!.isNotEmpty) ? ' ${e.unit}' : '';
      final ref = (e.refLow != null && e.refHigh != null)
          ? ' Referans: ${_fmt(e.refLow)} - ${_fmt(e.refHigh)}$unit.'
          : '';
      return '${e.name}: $v$unit. Durum: ${_flagLabel(e.flag)}.$ref';
    }

    final buf = StringBuffer();

    final highs = list.where((e) => e.flag == LabFlag.high).toList();
    final lows  = list.where((e) => e.flag == LabFlag.low).toList();
    final norms = list.where((e) => e.flag == LabFlag.normal).toList();

    if (highs.isNotEmpty) {
      buf.writeln('Yüksek olanlar:');
      for (final e in highs) buf.writeln(line(e));
      buf.writeln();
    }
    if (lows.isNotEmpty) {
      buf.writeln('Düşük olanlar:');
      for (final e in lows) buf.writeln(line(e));
      buf.writeln();
    }
    if (norms.isNotEmpty) {
      buf.writeln('Normal olanlardan örnekler:');
      for (final e in norms.take(5)) buf.writeln(line(e));
    }

    return buf.toString().trim();
  }

  static String _fmt(num? v) {
    if (v == null) return '';
    return (v % 1 == 0) ? v.toStringAsFixed(0) : v.toStringAsFixed(2);
  }

  Future<void> _speakSummary() async {
    if (_items.isEmpty) return;
    await _tts.setSpeechRate(_rateSummary);
    await _tts.speak(_summaryText(_items));
  }

  Future<void> _speakDetails() async {
    if (_items.isEmpty) return;
    await _tts.setSpeechRate(_rateDetails);
    await _tts.speak(_detailsText(_items));
  }

  void _snack(String msg, {bool err = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: err ? Colors.red.shade600 : Colors.green.shade700,
      ),
    );
  }

  @override
  void dispose() {
    _stopTts();
    super.dispose();
  }

  // ---- UI ----
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          // Gradient arka plan
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
                // Üst bar
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      _GlassButton(
                        onPressed: () {
                          _stopTts();
                          Navigator.of(context).maybePop();
                        },
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Tahliller (PDF → OCR)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 22,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _GlassButton(
                        onPressed: _speaking ? _stopTts : null,
                        child: const Icon(Icons.stop_circle_outlined, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // İçerik
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Dosya seç + OCR başlat
                          _GlassCard(
                            child: Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          _fileName ?? 'PDF seçilmedi',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w600,
                                          ),
                                        ),
                                        if (_busy) ...[
                                          const SizedBox(height: 8),
                                          LinearProgressIndicator(
                                            backgroundColor: Colors.white24,
                                            value: _progress == 0 ? null : _progress,
                                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _GlassButton(
                                    isPrimary: true,
                                    onPressed: _busy ? null : _pickPdf,
                                    child: Row(
                                      children: const [
                                        Icon(Icons.upload_file, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text('PDF Seç',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _GlassButton(
                                    isPrimary: true,
                                    onPressed: (_busy || _pdfBytes == null) ? null : _runOcr,
                                    child: Row(
                                      children: const [
                                        Icon(Icons.text_snippet_outlined, color: Colors.white),
                                        SizedBox(width: 8),
                                        Text('OCR Başlat',
                                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),

                          const SizedBox(height: 16),

                          // Özet + TTS
                          if (_items.isNotEmpty)
                            _GlassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(16),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _summaryText(_items),
                                      style: const TextStyle(color: Colors.white),
                                    ),
                                    const SizedBox(height: 12),
                                    Row(
                                      children: [
                                        _GlassButton(
                                          isPrimary: true,
                                          onPressed: _speakSummary,
                                          child: Row(
                                            children: const [
                                              Icon(Icons.volume_up_outlined, color: Colors.white),
                                              SizedBox(width: 8),
                                              Text('Özet Oku',
                                                  style: TextStyle(
                                                      color: Colors.white, fontWeight: FontWeight.bold)),
                                            ],
                                          ),
                                        ),
                                        const SizedBox(width: 8),
                                        _GlassButton(
                                          onPressed: _speakDetails,
                                          child: const Text('Detayları Oku',
                                              style: TextStyle(color: Colors.white)),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 12),

                          // Test listesi
                          if (_items.isNotEmpty)
                            _GlassCard(
                              child: Container(
                                padding: const EdgeInsets.all(8),
                                constraints: const BoxConstraints(minHeight: 140),
                                child: ListView.separated(
                                  shrinkWrap: true,
                                  physics: const NeverScrollableScrollPhysics(),
                                  itemCount: _items.length,
                                  separatorBuilder: (_, __) => Divider(
                                    height: 8,
                                    color: Colors.white.withOpacity(0.08),
                                  ),
                                  itemBuilder: (_, i) {
                                    final it = _items[i];
                                    return Row(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          width: 8,
                                          height: 8,
                                          margin: const EdgeInsets.only(top: 6),
                                          decoration: BoxDecoration(
                                            color: _flagColor(it.flag),
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(it.name,
                                                  style: const TextStyle(
                                                      color: Colors.white,
                                                      fontWeight: FontWeight.bold)),
                                              const SizedBox(height: 4),
                                              Wrap(
                                                spacing: 12,
                                                runSpacing: 4,
                                                children: [
                                                  Text(
                                                    'Değer: ${it.valueStr ?? (it.value?.toString() ?? '?')} ${it.unit ?? ''}'.trim(),
                                                    style: TextStyle(
                                                        color: Colors.white.withOpacity(0.9), fontSize: 12),
                                                  ),
                                                  Text(
                                                    'Referans: ${it.refLow != null && it.refHigh != null ? '${_fmt(it.refLow)}–${_fmt(it.refHigh)} ${it.unit ?? ''}' : '—'}',
                                                    style: TextStyle(
                                                        color: Colors.white.withOpacity(0.8), fontSize: 12),
                                                  ),
                                                  Text(
                                                    'Durum: ${_flagLabel(it.flag)}',
                                                    style: TextStyle(
                                                        color: Colors.white.withOpacity(0.8), fontSize: 12),
                                                  ),
                                                ],
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

                          const SizedBox(height: 12),

                          // Ham metin (debug)
                          if (_rawText.isNotEmpty)
                            _GlassCard(
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Ham OCR Metni',
                                        style: TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 8),
                                    SelectableText(
                                      _rawText.length > 6000
                                          ? _rawText.substring(0, 6000) + '…'
                                          : _rawText,
                                      style: const TextStyle(
                                        color: Colors.white,
                                        fontSize: 11,
                                        height: 1.25,
                                        fontFamily: 'monospace',
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                          const SizedBox(height: 24),
                        ],
                      ),
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

  // ---- UI helpers ----
  Color _flagColor(LabFlag f) {
    switch (f) {
      case LabFlag.high:
        return Colors.redAccent;
      case LabFlag.low:
        return Colors.orange;
      case LabFlag.normal:
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }

  String _flagLabel(LabFlag f) {
    switch (f) {
      case LabFlag.high:
        return 'Yüksek';
      case LabFlag.low:
        return 'Düşük';
      case LabFlag.normal:
        return 'Normal';
      case LabFlag.unknown:
      default:
        return 'Bilinmiyor';
    }
  }
}

// ====== Model ======
enum LabFlag { high, low, normal, unknown }

class LabItem {
  LabItem({
    required this.name,
    this.valueStr,
    this.value,
    this.unit,
    this.refLow,
    this.refHigh,
    this.flag = LabFlag.unknown,
  });

  String name;
  String? valueStr; // "< 0.008" gibi
  double? value;
  String? unit;
  double? refLow;
  double? refHigh;
  LabFlag flag;
}

// ====== Glass UI parçaları ======
class _GlassCard extends StatelessWidget {
  final Widget child;
  const _GlassCard({required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          margin: const EdgeInsets.symmetric(vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.08),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.22), width: 1),
            boxShadow: const [
              BoxShadow(color: Colors.black26, blurRadius: 12, offset: Offset(0, 6)),
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

  const _GlassButton({required this.child, this.onPressed, this.isPrimary = false});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Material(
          color: (isPrimary ? Colors.white.withOpacity(0.22) : Colors.white.withOpacity(0.12)),
          child: InkWell(
            onTap: onPressed,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: isPrimary ? Colors.white.withOpacity(0.35) : Colors.white.withOpacity(0.25),
                ),
              ),
              child: child,
            ),
          ),
        ),
      ),
    );
  }
}