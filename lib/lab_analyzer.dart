// lib/enabiz.dart
import 'dart:io';
import 'dart:math' show min;
import 'dart:typed_data';
import 'dart:ui';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:pdfx/pdfx.dart' as pdfx;

// ÖNEMLİ: bu dosya projende zaten var
import 'lab_analyzer.dart' as la;

class EnabizPage extends StatefulWidget {
  const EnabizPage({super.key});
  @override
  State<EnabizPage> createState() => _EnabizPageState();
}

class _EnabizPageState extends State<EnabizPage> {
  // ---- TTS hızları ----
  static const double _rateGeneral = 0.85; // genel
  static const double _rateSummary = 0.80; // özet
  static const double _rateDetails = 0.72; // bulgular (yavaş)

  // ---- State ----
  String? _fileName;
  Uint8List? _pdfBytes;
  bool _busy = false;
  double _progress = 0;
  String _rawText = '';
  la.LabReport? _report;
  List<la.LabTest> _tests = [];

  // ---- TTS ----
  final _tts = FlutterTts();
  bool _speaking = false;

  // ---- Cache'ler ----
  String? _cachedSummaryText;
  String? _cachedDetailsText;

  @override
  void initState() {
    super.initState();
    _initTts();
  }

  @override
  void didUpdateWidget(covariant EnabizPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Testler değiştiğinde cache'leri temizle
    _cachedSummaryText = null;
    _cachedDetailsText = null;
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage("tr-TR");
      await _tts.setSpeechRate(_rateGeneral);
      await _tts.setPitch(1.0);
      await _tts.awaitSpeakCompletion(true);
      _tts.setStartHandler(() => setState(() => _speaking = true));
      _tts.setCompletionHandler(() => setState(() => _speaking = false));
      _tts.setCancelHandler(() => setState(() => _speaking = false));
    } catch (e) {
      debugPrint('TTS init hatası: $e');
    }
  }

  Future<void> _stopTts() async {
    try {
      await _tts.stop();
      if (mounted) setState(() => _speaking = false);
    } catch (e) {
      debugPrint('TTS stop hatası: $e');
    }
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
        _tests = [];
        _report = null;
        _progress = 0;
        _cachedSummaryText = null;
        _cachedDetailsText = null;
      });

      _snack('PDF seçildi: ${f.name}');
    } catch (e) {
      _snack('PDF seçilemedi: $e', err: true);
    }
  }

  // ---- OCR + PARSE (LabAnalyzer ile) ----
  Future<void> _runOcr() async {
    if (_pdfBytes == null) return;

    setState(() {
      _busy = true;
      _rawText = '';
      _tests = [];
      _report = null;
      _progress = 0;
      _cachedSummaryText = null;
      _cachedDetailsText = null;
    });

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    pdfx.PdfDocument? doc;

    try {
      doc = await pdfx.PdfDocument.openData(_pdfBytes!);
      final pageCount = min(3, doc.pagesCount); // ilk 3 sayfa genelde yeter
      final buf = StringBuffer();

      for (var i = 1; i <= pageCount; i++) {
        if (!mounted) break; // Widget dispose olmuşsa işlemi durdur

        final page = await doc.getPage(i);
        try {
          final img = await page.render(
            width: page.width * 1.9,
            height: page.height * 1.9,
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

            // Geçici dosyayı temizle
            await tmp.delete();
          }
        } finally {
          await page.close();
          if (mounted) setState(() => _progress = i / pageCount);
        }
      }

      if (!mounted) return; // Widget dispose olmuşsa devam etme

      final raw = _normalize(buf.toString());

      // 1) Tablo dene
      final tableReport = la.EnabizTableParser.parseTable(raw);
      // 2) Olmazsa serbest metin
      final report = (tableReport.tests.isNotEmpty)
          ? tableReport
          : la.LabAnalyzer.parse(raw);

      setState(() {
        _rawText = raw;
        _report = report;
        _tests = report.tests;
      });

      if (_tests.isEmpty) {
        _snack('OCR tamam ama test/parsing başarısız. PDF düzeni farklı olabilir.', err: true);
      } else {
        _snack('OCR + analiz tamam: ${_tests.length} test.');
      }
    } catch (e) {
      if (mounted) _snack('OCR hata: $e', err: true);
    } finally {
      await recognizer.close();
      await doc?.close();
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---- Yardımcılar (format/normalize) ----
  static String _normalize(String raw) {
    // Önce tüm özel karakterleri normalize et
    final replacements = {
      '\u00A0': ' ',
      '\u2212': '-',
      '–': '-',
      '—': '-',
      '·': ' ',
      '•': ' ',
      '\r': ' ',
      '\t': ' ',
      'µ': 'u',
      'μ': 'u',
      'ı': 'i',
      'İ': 'I',
      'ş': 's',
      'Ş': 'S',
      'ğ': 'g',
      'Ğ': 'G',
      'ç': 'c',
      'Ç': 'C',
      'ö': 'o',
      'Ö': 'O',
      'ü': 'u',
      'Ü': 'U'
    };

    String result = raw;
    replacements.forEach((key, value) {
      result = result.replaceAll(key, value);
    });

    // Fazla boşlukları temizle
    result = result.replaceAll(RegExp('[ ]{2,}'), ' ').trim();

    // Virgülleri noktaya çevir (ondalık sayılar için)
    result = result.replaceAllMapped(RegExp(r'(\d),(\d)'), (m) => '${m[1]}.${m[2]}');

    return result;
  }

  String _valueStr(la.LabTest t) {
    final op = (t.op ?? '').trim();
    final v = t.value?.toString() ?? '';
    if (op.isEmpty && v.isEmpty) return '';
    return op.isEmpty ? v : '$op $v';
  }

  String _refStr(la.LabTest t) {
    final lo = t.refLow, hi = t.refHigh;
    final unit = (t.unit ?? '').isNotEmpty ? ' ${t.unit}' : '';
    if (lo != null && hi != null && lo.isNotEmpty && hi.isNotEmpty) {
      return '$lo – $hi$unit';
    }
    if (hi != null && hi.isNotEmpty) return '≤ $hi$unit';
    if (lo != null && lo.isNotEmpty) return '≥ $lo$unit';
    return '—';
  }

  // ---- TTS metinleri (cache'li) ----
  String _summaryText() {
    if (_cachedSummaryText != null) return _cachedSummaryText!;
    
    if (_report == null || _tests.isEmpty) return 'Herhangi bir test okunamadı.';

    final r = _report!;
    final highs = r.highs;
    final lows = r.lows;
    final normals = r.total - highs - lows - r.positives - r.tests.where((t) => t.flag == la.LabFlag.borderline).length;

    final buf = StringBuffer();
    buf.write('Toplam ${r.total} test var. ');
    buf.write('$highs yüksek, $lows düşük, $normals normal. ');

    // Referans dışı: high + low + positive + borderline
    final out = r.tests.where((t) =>
      t.flag == la.LabFlag.high ||
      t.flag == la.LabFlag.low ||
      t.flag == la.LabFlag.positive ||
      t.flag == la.LabFlag.borderline).toList();

    if (out.isNotEmpty) {
      buf.write('Referans dışı ${out.length} sonuç: ');
      buf.write(out.take(5).map((t) {
        final val = _valueStr(t);
        final unit = (t.unit ?? '').isNotEmpty ? ' ${t.unit}' : '';
        final ref = _refStr(t);
        final status = _flagLabel(t.flag);
        return '${t.name}: $val$unit ($status, referans $ref)';
      }).join(', '));
      if (out.length > 5) buf.write(', ve ${out.length - 5} sonuç daha.');
    }

    _cachedSummaryText = buf.toString().trim();
    return _cachedSummaryText!;
  }

  String _detailsText() {
    if (_cachedDetailsText != null) return _cachedDetailsText!;
    
    if (_tests.isEmpty) return 'Detay yok.';
    
    String line(la.LabTest t) {
      final val = _valueStr(t);
      final unit = (t.unit ?? '').isNotEmpty ? ' ${t.unit}' : '';
      final ref = _refStr(t);
      final status = _flagLabel(t.flag);
      return '${t.name}: $val$unit. Durum: $status. Referans: $ref.';
    }

    final buf = StringBuffer();

    final highs = _tests.where((e) => e.flag == la.LabFlag.high).toList();
    final lows  = _tests.where((e) => e.flag == la.LabFlag.low).toList();
    final pos   = _tests.where((e) => e.flag == la.LabFlag.positive).toList();
    final bor   = _tests.where((e) => e.flag == la.LabFlag.borderline).toList();
    final norms = _tests.where((e) => e.flag == la.LabFlag.normal).toList();

    if (pos.isNotEmpty) {
      buf.writeln('Pozitif olanlar:');
      for (final e in pos) buf.writeln(line(e));
      buf.writeln();
    }
    if (bor.isNotEmpty) {
      buf.writeln('Sınırda olanlar:');
      for (final e in bor) buf.writeln(line(e));
      buf.writeln();
    }
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

    _cachedDetailsText = buf.toString().trim();
    return _cachedDetailsText!;
  }

  Future<void> _speakSummary() async {
    if (_tests.isEmpty) return;
    try {
      await _tts.setSpeechRate(_rateSummary);
      await _tts.speak(_summaryText());
    } catch (e) {
      _snack('Seslendirme hatası: $e', err: true);
    }
  }

  Future<void> _speakDetails() async {
    if (_tests.isEmpty) return;
    try {
      await _tts.setSpeechRate(_rateDetails);
      await _tts.speak(_detailsText());
    } catch (e) {
      _snack('Seslendirme hatası: $e', err: true);
    }
  }

  void _snack(String msg, {bool err = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        backgroundColor: err ? Colors.red.shade600 : Colors.green.shade700,
        duration: const Duration(seconds: 3),
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
                _buildAppBar(),
                
                // İçerik
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          // Dosya seç + OCR başlat
                          _buildFileSection(),
                          
                          if (_tests.isNotEmpty) ...[
                            const SizedBox(height: 16),
                            _buildSummarySection(),
                            const SizedBox(height: 12),
                            _buildTestListSection(),
                          ],
                          
                          if (_rawText.isNotEmpty) ...[
                            const SizedBox(height: 12),
                            _buildRawTextSection(),
                          ],
                          
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

  // ---- UI Bileşenleri ----
  Widget _buildAppBar() {
    return Padding(
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
    );
  }

  Widget _buildFileSection() {
    return _GlassCard(
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
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
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
              child: const Row(
                children: [
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
              child: const Row(
                children: [
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
    );
  }

  Widget _buildSummarySection() {
    return _GlassCard(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              _summaryText(),
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                _GlassButton(
                  isPrimary: true,
                  onPressed: _speakSummary,
                  child: const Row(
                    children: [
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
    );
  }

  Widget _buildTestListSection() {
    return _GlassCard(
      child: Container(
        padding: const EdgeInsets.all(8),
        constraints: const BoxConstraints(minHeight: 140),
        child: ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: _tests.length,
          separatorBuilder: (_, __) => Divider(
            height: 8,
            color: Colors.white.withOpacity(0.08),
          ),
          itemBuilder: (_, i) => _buildTestItem(_tests[i]),
        ),
      ),
    );
  }

  Widget _buildTestItem(la.LabTest test) {
    final value = _valueStr(test);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 8,
          height: 8,
          margin: const EdgeInsets.only(top: 6),
          decoration: BoxDecoration(
            color: _flagColor(test.flag),
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(test.name,
                  style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold)),
              const SizedBox(height: 4),
              Wrap(
                spacing: 12,
                runSpacing: 4,
                children: [
                  Text(
                    'Değer: ${value.isEmpty ? '—' : value} ${(test.unit ?? '')}'.trim(),
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.9), fontSize: 12),
                  ),
                  Text(
                    'Referans: ${_refStr(test)}',
                    style: TextStyle(
                        color: Colors.white.withOpacity(0.8), fontSize: 12),
                  ),
                  Text(
                    'Durum: ${_flagLabel(test.flag)}',
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
  }

  Widget _buildRawTextSection() {
    return _GlassCard(
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
    );
  }

  // ---- UI helpers ----
  Color _flagColor(la.LabFlag f) {
    switch (f) {
      case la.LabFlag.high:
        return Colors.redAccent;
      case la.LabFlag.low:
        return Colors.orange;
      case la.LabFlag.normal:
        return Colors.greenAccent;
      case la.LabFlag.positive:
        return Colors.purpleAccent;
      case la.LabFlag.borderline:
        return Colors.pinkAccent;
      case la.LabFlag.unknown:
      default:
        return Colors.grey;
    }
  }

  String _flagLabel(la.LabFlag f) {
    switch (f) {
      case la.LabFlag.high:
        return 'Yüksek';
      case la.LabFlag.low:
        return 'Düşük';
      case la.LabFlag.normal:
        return 'Normal';
      case la.LabFlag.positive:
        return 'Pozitif';
      case la.LabFlag.borderline:
        return 'Sınırda';
      case la.LabFlag.unknown:
      default:
        return 'Bilinmiyor';
    }
  }
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