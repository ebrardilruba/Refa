// lib/enabiz.dart
import 'dart:async' show unawaited;
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/foundation.dart'; // compute()
import 'package:flutter/material.dart';
import 'package:file_selector/file_selector.dart';

import 'package:syncfusion_flutter_pdf/pdf.dart';
import 'package:pdfx/pdfx.dart' as pdfx; // OCR rasterize
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart'; // OCR

import 'tts_service.dart';
import 'settings.dart';
import 'lab_analyzer.dart';
import 'package:refa/tts_service.dart'; // ya da: import 'tts_service.dart';
import 'dart:async'; // unawaited kullanıyorsan gerekli

// ===================== ISOLATE FONKSİYONLARI =====================

// 1) Syncfusion: tüm sayfalardan metin (isolate)
Future<String> _extractTextInIsolate(Uint8List bytes) async {
  final doc = PdfDocument(inputBytes: bytes);
  final extractor = PdfTextExtractor(doc);
  final sb = StringBuffer();
  for (var i = 0; i < doc.pages.count; i++) {
    sb.writeln(extractor.extractText(startPageIndex: i, endPageIndex: i));
  }
  doc.dispose();
  return _normalize(sb.toString());
}

// 2) OCR: ilk N sayfayı PNG'e render edip ML Kit'le oku (fallback)
Future<String> _ocrFirstPages(Uint8List bytes, {int pages = 2}) async {
  final doc = await pdfx.PdfDocument.openData(bytes);
  final pageCount = doc.pagesCount;
  final limit = pages < pageCount ? pages : pageCount;

  final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
  final sb = StringBuffer();

  try {
    for (var i = 1; i <= limit; i++) {
      final page = await doc.getPage(i);
      try {
        final img = await page.render(
          width: page.width.toDouble() / 2,
          height: page.height.toDouble() / 2,
          format: pdfx.PdfPageImageFormat.png,
        );
        if (img == null) continue;

        final pngFile =
            await File('${Directory.systemTemp.path}/refa_ocr_$i.png').create();
        await pngFile.writeAsBytes(img.bytes, flush: true);

        final input = InputImage.fromFilePath(pngFile.path);
        final result = await recognizer.processImage(input);
        sb.writeln(result.text);

        unawaited(pngFile.delete());
      } finally {
        await page.close();
      }
    }
  } finally {
    await recognizer.close();
    await doc.close();
  }

  return _normalize(sb.toString());
}

// 3) Parse — isolate
Future<List<Map<String, dynamic>>> _parseInIsolate(String text) async {
  final report = LabAnalyzer.parse(text);
  return report.tests.map((t) {
    String flag;
    switch (t.flag) {
      case LabFlag.high:
        flag = 'high';
        break;
      case LabFlag.low:
        flag = 'low';
        break;
      case LabFlag.normal:
        flag = 'normal';
        break;
      case LabFlag.positive:
        flag = 'positive';
        break;
      case LabFlag.borderline:
        flag = 'borderline';
        break;
      default:
        flag = 'unknown';
    }
    return {
      'name': t.name,
      'value': t.value,
      'unit': t.unit,
      'refLow': t.refLow,
      'refHigh': t.refHigh,
      'flag': flag,
    };
  }).toList();
}

// Metin normalizasyonu
String _normalize(String raw) => raw
    .replaceAll('\u00A0', ' ') // NBSP
    .replaceAll('\u2212', '-') // minus
    .replaceAll('–', '-')
    .replaceAll('—', '-')
    .replaceAll('\r', ' ')
    .replaceAll('\t', ' ')
    .replaceAll(RegExp('[ ]{2,}'), ' ')
    .trim();

// ======================== WIDGET ========================

class EnabizPage extends StatefulWidget {
  const EnabizPage({super.key});

  @override
  State<EnabizPage> createState() => _EnabizPageState();
}

class _EnabizPageState extends State<EnabizPage> {
  String? _fileName;
  int? _pageCount;
  Uint8List? _pdfBytes;
  bool _analyzing = false;

  Future<void> _pickPdf() async {
    try {
      final group = const XTypeGroup(label: 'PDF', extensions: ['pdf']);
      final XFile? file = await openFile(acceptedTypeGroups: [group]);
      if (file == null) return;

      final bytes = await file.readAsBytes();
      final tmpDoc = PdfDocument(inputBytes: bytes);
      final pages = tmpDoc.pages.count;
      tmpDoc.dispose();

      setState(() {
        _fileName = file.name;
        _pageCount = pages;
        _pdfBytes = bytes;
      });

      if (mounted) {
        _showSnackBar('PDF yüklendi: ${file.name} ($pages sayfa)');
      }
    } catch (e) {
      if (!mounted) return;
      _showSnackBar('PDF yüklenemedi: $e', isError: true);
    }
  }

  void _showSnackBar(String message, {bool isError = false}) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message, style: const TextStyle(color: Colors.white)),
        backgroundColor: isError ? Colors.red.shade600 : Colors.green.shade600,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(16),
      ),
    );
  }

  Future<void> _analyzeAndSpeak() async {
    if (_pdfBytes == null) return;
    setState(() => _analyzing = true);
    try {
      unawaited(TtsService.instance.speak('Analiz başlatıldı.'));

      // --- A) Syncfusion ile metin
      String text = '';
      try {
        text = await compute(_extractTextInIsolate, _pdfBytes!);
      } catch (_) {}

      // --- B) OCR fallback (ilk 2 sayfa)
      if (text.isEmpty) {
        try {
          text = await _ocrFirstPages(_pdfBytes!, pages: 2);
          if (mounted && text.isNotEmpty) {
            _showSnackBar('OCR ile metin çıkarıldı.');
          }
        } catch (_) {}
      }

      if (text.isEmpty) {
        // *** ÖNEMLİ: Çift tırnak kullan ***
        await TtsService.instance.speak("Bu PDF'den metin çıkaramadım.");
        if (!mounted) return;
        _showSnackBar('Metin bulunamadı (muhtemelen görüntü tabanlı PDF).', isError: true);
        return;
      }

      // Özet için dilim
      final summarySlice = text.length > 3000 ? text.substring(0, 3000) : text;
      var parsedSummary = await compute(_parseInIsolate, summarySlice);

      // Özet boşsa tüm metni parse et
      if (parsedSummary.isEmpty) {
        parsedSummary = await compute(_parseInIsolate, text);
      }

      final counts = _counts(parsedSummary);
      final summary = _summarySentence(counts, parsedSummary);

      if (mounted) {
        _showSnackBar('Özet için ${parsedSummary.length} test bulundu.');
      }

      await TtsService.instance
          .speak('Özet: $summary Detayları okumamı ister misiniz?');

      if (!mounted) return;
      final wantDetails = await _showAnalysisDialog(summary, parsedSummary);

      if (wantDetails == true) {
        final parsedFull = (parsedSummary.length > 5)
            ? parsedSummary
            : await compute(_parseInIsolate, text);
        if (parsedFull.isNotEmpty) {
          final details = _buildDetailsNarration(parsedFull);
          await TtsService.instance.speak(details);
        } else {
          await TtsService.instance.speak('Detay çıkarılamadı.');
        }
      }

      if (!mounted) return;
      _showSnackBar('Analiz tamamlandı.');
    } catch (e) {
      await TtsService.instance.speak('Analiz sırasında bir hata oluştu.');
      if (!mounted) return;
      _showSnackBar('Analiz hatası: $e', isError: true);
    } finally {
      if (mounted) setState(() => _analyzing = false);
    }
  }

  Future<bool?> _showAnalysisDialog(String summary, List<Map<String, dynamic>> parsed) {
    return showDialog<bool>(
      context: context,
      builder: (ctx) => Dialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Container(
          constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(24),
            gradient: const LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [Color(0xFF334155), Color(0xFF1E3A8A)],
            ),
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(24),
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(color: Colors.white.withOpacity(0.2)),
                ),
                padding: const EdgeInsets.all(24),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Analiz Sonucu',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 24,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 16),
                    Flexible(
                      child: SingleChildScrollView(
                        child: _AnalysisPreview(summary: summary, parsed: parsed),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        _GlassButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Hayır', style: TextStyle(color: Colors.white)),
                        ),
                        _GlassButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          isPrimary: true,
                          child: const Text(
                            'Evet, Detayları Oku',
                            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    TtsService.instance.stop();
    super.dispose();
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
            child: Column(
              children: [
                // Custom AppBar
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Row(
                    children: [
                      _GlassButton(
                        onPressed: () => Navigator.pop(context),
                        child: const Icon(Icons.arrow_back, color: Colors.white),
                      ),
                      const SizedBox(width: 16),
                      const Expanded(
                        child: Text(
                          'Tahliller (PDF)',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      _GlassButton(
                        onPressed: () => TtsService.instance.stop(),
                        child: const Icon(Icons.stop_circle_outlined, color: Colors.white),
                      ),
                      const SizedBox(width: 8),
                      _GlassButton(
                        onPressed: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const SettingsPage()),
                          );
                        },
                        child: const Icon(Icons.settings, color: Colors.white),
                      ),
                    ],
                  ),
                ),

                // Content
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24),
                    child: Center(
                      child: SingleChildScrollView(
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            // Main Icon
                            Container(
                              width: 120,
                              height: 120,
                              decoration: BoxDecoration(
                                color: const Color(0xFFF59E0B),
                                borderRadius: BorderRadius.circular(32),
                                boxShadow: const [
                                  BoxShadow(
                                    color: Colors.black26,
                                    blurRadius: 20,
                                    offset: Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: const Icon(
                                Icons.picture_as_pdf_rounded,
                                size: 64,
                                color: Colors.white,
                              ),
                            ),

                            const SizedBox(height: 24),

                            // Description
                            const Text(
                              'e-Nabız PDF\'ini yükle',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 24,
                                fontWeight: FontWeight.bold,
                              ),
                            ),

                            const SizedBox(height: 8),

                            Text(
                              'Önce özet çıkarır, onaylarsan detayları sesli anlatırım.',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 16,
                                height: 1.4,
                              ),
                            ),

                            const SizedBox(height: 32),

                            // Upload Button
                            _GlassButton(
                              onPressed: _pickPdf,
                              isPrimary: true,
                              child: const Padding(
                                padding: EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                                child: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Icon(Icons.upload_file, color: Colors.white),
                                    SizedBox(width: 12),
                                    Text(
                                      'PDF Ekle',
                                      style: TextStyle(
                                        color: Colors.white,
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            const SizedBox(height: 24),

                            // File Info Card
                            if (_fileName != null)
                              _GlassCard(
                                child: Padding(
                                  padding: const EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      Row(
                                        children: [
                                          Container(
                                            width: 48,
                                            height: 48,
                                            decoration: BoxDecoration(
                                              color: const Color(0xFFF59E0B),
                                              borderRadius: BorderRadius.circular(12),
                                            ),
                                            child: const Icon(
                                              Icons.description,
                                              color: Colors.white,
                                              size: 24,
                                            ),
                                          ),
                                          const SizedBox(width: 16),
                                          Expanded(
                                            child: Column(
                                              crossAxisAlignment: CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  _fileName!,
                                                  style: const TextStyle(
                                                    color: Colors.white,
                                                    fontSize: 16,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                                const SizedBox(height: 4),
                                                Text(
                                                  '${_pageCount ?? 0} sayfa',
                                                  style: TextStyle(
                                                    color: Colors.white.withOpacity(0.7),
                                                    fontSize: 14,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 20),
                                      SizedBox(
                                        width: double.infinity,
                                        child: _GlassButton(
                                          onPressed: _analyzing ? null : _analyzeAndSpeak,
                                          isPrimary: true,
                                          child: _analyzing
                                              ? const Padding(
                                                  padding: EdgeInsets.all(16),
                                                  child: SizedBox(
                                                    height: 20,
                                                    width: 20,
                                                    child: CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                                    ),
                                                  ),
                                                )
                                              : const Padding(
                                                  padding: EdgeInsets.all(16),
                                                  child: Text(
                                                    'Analiz Et ve Oku',
                                                    style: TextStyle(
                                                      color: Colors.white,
                                                      fontSize: 16,
                                                      fontWeight: FontWeight.bold,
                                                    ),
                                                  ),
                                                ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),

                            if (_analyzing) ...[
                              const SizedBox(height: 24),
                              _GlassCard(
                                child: const Padding(
                                  padding: EdgeInsets.all(20),
                                  child: Column(
                                    children: [
                                      LinearProgressIndicator(
                                        backgroundColor: Colors.white24,
                                        valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                                      ),
                                      SizedBox(height: 12),
                                      Text(
                                        'PDF analiz ediliyor...',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontSize: 14,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],

                            const SizedBox(height: 32),
                          ],
                        ),
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

  // ---- Yardımcılar ----

  Map<String, int> _counts(List<Map<String, dynamic>> parsed) {
    final highs = parsed.where((m) => m['flag'] == 'high').length;
    final lows = parsed.where((m) => m['flag'] == 'low').length;
    final pos = parsed.where((m) => m['flag'] == 'positive').length;
    final border = parsed.where((m) => m['flag'] == 'borderline').length;
    final total = parsed.length;
    return {'highs': highs, 'lows': lows, 'pos': pos, 'border': border, 'total': total};
  }

  String _summarySentence(Map<String, int> c, List<Map<String, dynamic>> parsed) {
    final abn = c['highs']! + c['lows']! + c['pos']! + c['border']!;
    String summary = 'Toplam ${c['total']} test bulundu. '
        'Referans dışı $abn sonuç var: ${c['highs']} yüksek, ${c['lows']} düşük'
        '${c['pos']! > 0 ? ', ${c['pos']} pozitif' : ''}'
        '${c['border']! > 0 ? ', ${c['border']} sınırda' : ''}.';

    final topHigh = parsed
        .where((m) => m['flag'] == 'high')
        .take(2)
        .map((m) => '${m['name']} ${_fmt(m['value'])} ${m['unit'] ?? ''}')
        .toList();
    final topLow = parsed
        .where((m) => m['flag'] == 'low')
        .take(2 - topHigh.length)
        .map((m) => '${m['name']} ${_fmt(m['value'])} ${m['unit'] ?? ''}')
        .toList();
    final topPos = parsed
        .where((m) => m['flag'] == 'positive')
        .take(2 - (topHigh.length + topLow.length))
        .map((m) => '${m['name']} pozitif')
        .toList();

    final top = [...topHigh, ...topLow, ...topPos]
        .where((e) => e.trim().isNotEmpty)
        .toList();
    if (top.isNotEmpty) {
      summary += ' Öne çıkanlar: ${top.join(', ')}.';
    }
    return summary;
  }

  String _fmt(dynamic v) {
    if (v == null) return '';
    final d = (v is num) ? v.toDouble() : double.tryParse('$v');
    if (d == null) return '$v';
    return d % 1 == 0 ? d.toStringAsFixed(0) : d.toString();
  }

  String _rng(dynamic a, dynamic b) {
    final lo = (a is num) ? a.toDouble() : double.tryParse('$a');
    final hi = (b is num) ? b.toDouble() : double.tryParse('$b');
    if (lo == null || hi == null) return '';
    final l = lo % 1 == 0 ? lo.toStringAsFixed(0) : lo.toString();
    final h = hi % 1 == 0 ? hi.toStringAsFixed(0) : hi.toString();
    return '$l – $h';
  }

  String _buildDetailsNarration(List<Map<String, dynamic>> parsed) {
    final pos = parsed.where((m) => m['flag'] == 'positive').toList();
    final highs = parsed.where((m) => m['flag'] == 'high').toList();
    final lows = parsed.where((m) => m['flag'] == 'low').toList();
    final normals = parsed.where((m) => m['flag'] == 'normal').take(5).toList();

    final buf = StringBuffer();
    if (pos.isNotEmpty) {
      buf.writeln('Pozitif saptanan testler:');
      for (final t in pos) {
        buf.writeln('${t['name']}: ${_fmt(t['value'])} ${t['unit'] ?? ''}.');
      }
    }
    if (highs.isNotEmpty) {
      buf.writeln('Yüksek değerler:');
      for (final t in highs) {
        buf.writeln('${t['name']}: ${_fmt(t['value'])} ${t['unit'] ?? ''}. '
            'Referans aralığı ${_rng(t['refLow'], t['refHigh'])} ${t['unit'] ?? ''}.');
      }
    }
    if (lows.isNotEmpty) {
      buf.writeln('Düşük değerler:');
      for (final t in lows) {
        buf.writeln('${t['name']}: ${_fmt(t['value'])} ${t['unit'] ?? ''}. '
            'Referans aralığı ${_rng(t['refLow'], t['refHigh'])} ${t['unit'] ?? ''}.');
      }
    }
    if (pos.isEmpty && highs.isEmpty && lows.isEmpty) {
      buf.writeln('Tüm testler referans aralığında.');
    }
    if (normals.isNotEmpty) {
      buf.writeln('Örnek normal değerler:');
      for (final t in normals) {
        buf.writeln('${t['name']}: ${_fmt(t['value'])} ${t['unit'] ?? ''}. '
            'Referans ${_rng(t['refLow'], t['refHigh'])} ${t['unit'] ?? ''}.');
      }
    }
    return buf.toString();
  }
}

// ==================== CUSTOM WIDGETS ====================

class _GlassCard extends StatelessWidget {
  final Widget child;
  final Color? color;
  final Color? borderColor;

  const _GlassCard({
    required this.child,
    this.color,
    this.borderColor,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(20),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: Container(
          decoration: BoxDecoration(
            color: color ?? Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: borderColor ?? Colors.white.withOpacity(0.2),
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

  const _GlassButton({
    required this.child,
    this.onPressed,
    this.isPrimary = false,
  });

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          decoration: BoxDecoration(
            color: isPrimary
                ? Colors.white.withOpacity(0.2)
                : Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isPrimary
                  ? Colors.white.withOpacity(0.3)
                  : Colors.white.withOpacity(0.2),
            ),
          ),
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: onPressed,
              borderRadius: BorderRadius.circular(16),
              child: Container(
                padding: const EdgeInsets.all(12),
                child: child,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------- Debug: Analiz önizleme ----------
class _AnalysisPreview extends StatelessWidget {
  final String summary;
  final List<Map<String, dynamic>> parsed;

  const _AnalysisPreview({
    required this.summary,
    required this.parsed,
  });

  Color _flagColor(String f) {
    switch (f) {
      case 'high':
        return Colors.redAccent;
      case 'low':
        return Colors.orange;
      case 'positive':
        return Colors.purple;
      case 'borderline':
        return Colors.pink;
      case 'normal':
        return Colors.greenAccent;
      default:
        return Colors.grey;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: Colors.white.withOpacity(0.2)),
          ),
          child: Text(
            summary,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 16,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(height: 16),
        if (parsed.isNotEmpty) ...[
          const Text(
            'Test Detayları:',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            constraints: const BoxConstraints(maxHeight: 200),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.05),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white.withOpacity(0.1)),
            ),
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: parsed.length,
              itemBuilder: (_, i) {
                final m = parsed[i];
                return Container(
                  margin: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: _flagColor(m['flag'] as String),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              m['name'] as String,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              [
                                if (m['value'] != null) 'Değer: ${m['value']} ${m['unit'] ?? ''}',
                                if (m['refLow'] != null && m['refHigh'] != null)
                                  'Ref: ${m['refLow']}–${m['refHigh']} ${m['unit'] ?? ''}',
                              ].join(' • '),
                              style: TextStyle(
                                color: Colors.white.withOpacity(0.8),
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
          ),
        ],
      ],
    );
  }
<<<<<<< HEAD

  
=======
>>>>>>> db84bb4 (İlk yükleme)
}
