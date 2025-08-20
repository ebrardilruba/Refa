// lib/lab_analyzer.dart
import 'dart:math';
import 'dart:collection';

enum LabFlag { low, normal, high, positive, borderline, unknown }

class LabTest {
  final String name;
  final double? value;
  final String? refLow;
  final String? refHigh;
  final String? unit;
  final String? op; // '<', '>', '≥', '≤', veya null
  final LabFlag flag;
  final String raw;

  LabTest({
    required this.name,
    required this.value,
    required this.refLow,
    required this.refHigh,
    required this.unit,
    required this.op,
    required this.flag,
    required this.raw,
  });
}

class LabReport {
  final List<LabTest> tests;
  LabReport(this.tests);

  int get total => tests.length;
  int get highs => tests.where((t) => t.flag == LabFlag.high).length;
  int get lows => tests.where((t) => t.flag == LabFlag.low).length;
  int get positives => tests.where((t) => t.flag == LabFlag.positive).length;
  int get abnormals =>
      highs + lows + positives + tests.where((t) => t.flag == LabFlag.borderline).length;

  List<LabTest> get highTests => tests.where((t) => t.flag == LabFlag.high).toList();
  List<LabTest> get lowTests => tests.where((t) => t.flag == LabFlag.low).toList();
  List<LabTest> get posTests => tests.where((t) => t.flag == LabFlag.positive).toList();
}

class LabAnalyzer {
  // --- Ad/alias havuzu (genişletilebilir) ---
  static final Map<String, List<String>> _aliases = {
    'Hemoglobin': ['Hemoglobin', r'\bHGB\b', r'\bHb\b'],
    'Hematokrit': ['Hematokrit', r'\bHCT\b'],
    'WBC': [r'\bWBC\b', 'Lökosit'],
    'RBC': [r'\bRBC\b', 'Eritrosit'],
    'Trombosit': ['Trombosit', r'\bPLT\b'],
    'RDW-CV': [r'\bRDW(?:-CV)?\b', 'RDW CV'],
    'MPV': [r'\bMPV\b'],
    'MCV': [r'\bMCV\b'],
    'MCHC': [r'\bMCHC\b'],
    'MCH': [r'\bMCH\b'],
    'Glukoz': ['Glukoz', 'Açlık Kan Şekeri', 'Glucose', r'\bFBG\b'],
    'HbA1c': [r'\bHbA1c\b', 'Glike hemoglobin'],
    'ALT': [r'\bALT\b', 'ALAT', 'Alanin aminotransferaz'],
    'AST': [r'\bAST\b', 'ASAT', 'Aspartat transaminaz'],
    'ALP': [r'\bALP\b'],
    'GGT': [r'\bGGT\b', 'Gamma glutamil transferaz'],
    'Kreatinin': ['Kreatinin', 'Creatinine'],
    'Üre': ['Üre'],
    'Ürik asit': ['Ürik asit', 'Uric acid'],
    'Sodyum': ['Sodyum', r'\bNa\b'],
    'Potasyum': ['Potasyum', r'\bK\b'],
    'Kalsiyum': ['Kalsiyum', r'\bCa\b'],
    'Fosfor': ['Fosfor', r'\bP\b'],
    'TSH': [r'\bTSH\b'],
    'Serbest T4': [r'\bSerbest\s*T4\b', r'\bFT4\b'],
    'Serbest T3': [r'\bSerbest\s*T3\b', r'\bFT3\b'],
    'eGFR': [r'Glomer[üu]l Filtrasyon H[ıi]z[ıi]', r'\beGFR\b', r'CKD-EPI'],
    'CRP': [r'\bCRP\b', 'C reaktif protein'],
    'LDL': ['LDL kolesterol', r'\bLDL\b'],
    'HDL': ['HDL kolesterol', r'\bHDL\b'],
    'Trigliserid': ['Trigliserid', 'Triglycerid'],
    'Kolesterol': ['Kolesterol', 'Total Kolesterol'],
    'Vitamin B12': ['Vitamin B12', r'\bB12\b'],
    'Ferritin': ['Ferritin'],
    'Demir': ['Demir (serum)', r'\bDemir\b', r'\bFe\b'],
    'TDBK': ['Demir bağlama kapasitesi', r'\bTDBK\b'],
    // Seroloji
    'HBsAg': [r'\bHBsAg\b'],
    'Anti HBs': [r'Anti\s*HBs'],
    'Anti HCV': [r'Anti\s*HCV'],
    'Anti HIV': [r'Anti\s*HIV'],
  };

  // Hematoloji birimleri + sık varyantlar
  static final RegExp _unitRe = RegExp(
    r'(g/dL|mg/dL|mmol/L|m?IU/mL|µ?IU/mL|ng/dL|ng/L|µg/L|U/L|IU/L|mg/L|pg/mL|fL|%|mL/dk/1\.73|'
    r'(?:10\^?[36]|10e[36]|x?10[³⁶])/?[µuU]?L|COI|mmol/?L)',
    caseSensitive: false,
  );

  static String _norm(String s) => s
      .replaceAll('\u2212', '-') // minus
      .replaceAll('–', '-')
      .replaceAll('—', '-')
      .replaceAll(',', '.')
      .replaceAll('\t', ' ')
      .replaceAll(RegExp(' +'), ' ')
      .trim();

  static double? _toDouble(String? s) {
    if (s == null) return null;
    final t = s.replaceAll(' ', '').replaceAll(',', '.');
    return double.tryParse(t);
  }

  static String _canonicalName(String matched) {
    for (final entry in _aliases.entries) {
      for (final a in entry.value) {
        final re = RegExp(a, caseSensitive: false);
        if (re.hasMatch(matched)) return entry.key;
      }
    }
    return matched.trim();
  }

  static LabFlag _flagForNumeric({
    required double? value,
    required String? op,
    required double? low,
    required double? high,
  }) {
    if (value == null && op == null) return LabFlag.unknown;

    // Tek sınır (örn. "Ref < 37", "Ref > 10")
    if (low == null && high != null) {
      if (value != null && value > high) return LabFlag.high;
      if (op == '<' || op == '≤') return LabFlag.normal;
      return LabFlag.normal;
    }
    if (low != null && high == null) {
      if (value != null && value < low) return LabFlag.low;
      if (op == '>' || op == '≥') return LabFlag.normal;
      return LabFlag.normal;
    }

    // Aralık
    if (low != null && high != null && value != null) {
      if (value < low) return LabFlag.low;
      if (value > high) return LabFlag.high;
      return LabFlag.normal;
    }
    return LabFlag.unknown;
  }

  // -------- Seroloji / COI özel kuralları + dil varyantları --------
  static LabFlag _flagSerology(String name, String line, double? value) {
    final l = line.toLowerCase();

    final isNeg = l.contains('negatif') || l.contains('non-reaktif') || l.contains('nonreaktif');
    final isPos = l.contains('pozitif') || l.contains('reaktif');
    final isBorder = l.contains('borderline') || l.contains('şüpheli');
    final isNone = l.contains('saptanmadı') || l.contains('tespit edilemedi') || l.contains('non detected');

    // Cut-off / COI eşiği: "cut off", "cut-off", "cutoff"
    final cut = RegExp(r'cut[- ]?off[^0-9]*([0-9]+(?:[.,][0-9]+)?)', caseSensitive: false).firstMatch(line);
    final cutVal = _toDouble(cut?.group(1));

    bool coiPositive(double v) {
      final threshold = cutVal ?? 1.0;
      return v >= threshold;
    }

    if (RegExp(r'anti\s*hbs', caseSensitive: false).hasMatch(name)) {
      if (value != null && value > 10) return LabFlag.positive;
      if (isPos) return LabFlag.positive;
      if (isBorder) return LabFlag.borderline;
      if (isNeg || isNone) return LabFlag.normal;
    }

    if (RegExp(r'hbsag', caseSensitive: false).hasMatch(name)) {
      if (value != null && l.contains('coi') && coiPositive(value)) return LabFlag.positive;
      if (isPos) return LabFlag.positive;
      if (isBorder) return LabFlag.borderline;
      if (isNeg || isNone) return LabFlag.normal;
    }

    if (RegExp(r'anti\s*hcv', caseSensitive: false).hasMatch(name) ||
        RegExp(r'anti\s*hiv', caseSensitive: false).hasMatch(name)) {
      if (value != null && l.contains('coi') && coiPositive(value)) return LabFlag.positive;
      if (isPos) return LabFlag.positive;
      if (isBorder) return LabFlag.borderline;
      if (isNeg || isNone) return LabFlag.normal;
    }

    return LabFlag.unknown;
  }

  // --- Desenleri alias başına 1 kez derleyip önbelleğe alalım ---
  static final Map<String, List<RegExp>> _compiledPatterns = () {
    const valR = r'(?:(?<op>[<>]|≥|≤)\s*)?(?<val>\d+(?:[.,]\d+)?)';
    const numR = r'(\d+(?:[.,]\d+)?)';
    const rngR = '$numR\\s*[-]\\s*$numR';

    const refKW =
        r'(?:Ref(?:\.|erans)?(?:\s*(?:Değer(?:ler)?|Aral[ıi]k))?|Normal(?:\s*Aral[ıi]k)?|Aral[ıi]k|Min\s*-\s*Max|MinMax|Alt\s*-\s*Üst|Sınır(?:lar)?)';

    final unitR = '(${_unitRe.pattern})?';

    List<RegExp> make(String alias) => [
          RegExp('($alias)[^\\n]*?$valR\\s*$unitR[^\\n]*?$refKW\\s*[:\\-]?\\s*$rngR',
              caseSensitive: false),
          RegExp('($alias)[^\\n]*?$refKW\\s*[:\\-]?\\s*$rngR[^\\n]*?$valR\\s*$unitR',
              caseSensitive: false),
          RegExp('($alias)[^\\n]*?$valR\\s*$unitR[^\\n]*?\\(\\s*$rngR\\s*\\)',
              caseSensitive: false),
          RegExp('($alias)[^\\n]*?\\(\\s*$rngR\\s*\\)[^\\n]*?$valR\\s*$unitR',
              caseSensitive: false),
          RegExp('($alias)[^\\n]*?$valR\\s*$unitR[^\\n]*?(?:$refKW|<|>|≤|≥)\\s*[:\\-]?\\s*(?:[<>]|≥|≤)?\\s*$numR',
              caseSensitive: false),
          RegExp('($alias)[^\\n]*?$valR\\s*$unitR', caseSensitive: false),
        ];

    final map = <String, List<RegExp>>{};
    for (final aliases in _aliases.values) {
      for (final a in aliases) {
        map[a] = make(a);
      }
    }
    return map;
  }();

  static LabReport parse(String rawText) {
    final text = _norm(rawText);
    final lines = text
        .split(RegExp(r'\n+'))
        .map(_norm)
        .where((e) => e.isNotEmpty && e.length > 2);

    final found = <LabTest>[];

    for (final line in lines) {
      bool matchedAny = false;
      for (final aliases in _aliases.values) {
        for (final alias in aliases) {
          final pats = _compiledPatterns[alias]!;
          for (final p in pats) {
            final m = p.firstMatch(line);
            if (m == null) continue;

            final matchedName = m.group(1) ?? alias;
            final name = _canonicalName(matchedName);

            // Değer / op
            final op = m.namedGroup('op');
            final valStr = m.namedGroup('val');
            final val = _toDouble(valStr);

            // Birim
            final um = _unitRe.firstMatch(line);
            final unit = um?.group(0);

            // Referans: aralık veya tek sınır
            String? refLow, refHigh;
            final rng = RegExp(r'(\d+(?:[.,]\d+)?)\s*-\s*(\d+(?:[.,]\d+)?)').firstMatch(line);
            if (rng != null) {
              refLow = rng.group(1);
              refHigh = rng.group(2);
            } else {
              final one = RegExp(r'(<|>|≤|≥)\s*(\d+(?:[.,]\d+)?)').firstMatch(line);
              if (one != null) {
                final sym = (one.group(1) ?? '').trim();
                if (sym == '<' || sym == '≤') {
                  refHigh = one.group(2);
                } else {
                  refLow = one.group(2);
                }
              }
            }

            // Seroloji kontrolü
            var flag = _flagSerology(name, line, val);
            if (flag == LabFlag.unknown) {
              flag = _flagForNumeric(
                value: val,
                op: op,
                low: _toDouble(refLow),
                high: _toDouble(refHigh),
              );
            }

            found.add(LabTest(
              name: name,
              value: val,
              refLow: refLow,
              refHigh: refHigh,
              unit: unit,
              op: op,
              flag: flag,
              raw: line,
            ));

            matchedAny = true;
            break; // aynı satırda tekrar eşleşme yapma
          }
          if (matchedAny) break;
        }
        if (matchedAny) break;
      }
    }

    // Aynı isimden birden fazla varsa "daha zengin" olanı seç
    final byName = LinkedHashMap<String, LabTest>(); // ekleme sırasını koru
    for (final t in found) {
      final prev = byName[t.name];
      if (prev == null) {
        byName[t.name] = t;
      } else {
        final prevScore =
            (prev.refLow != null || prev.refHigh != null ? 2 : 0) + (prev.unit != null ? 1 : 0);
        final curScore =
            (t.refLow != null || t.refHigh != null ? 2 : 0) + (t.unit != null ? 1 : 0);
        if (curScore >= prevScore) byName[t.name] = t;
      }
    }

    return LabReport(byName.values.toList());
  }
}

// ========== e-NABIZ TABLO PARSERI ==========
/// e-Nabız'dan indirilen PDF'lerin TABLO formatını özel olarak parse eder.
/// "| Test Adı | Sonuç | Birim | Referans |" şeklindeki satırları arar.
class EnabizTableParser {
  static final RegExp _tableRowRegex = RegExp(
    r'^\s*\|?\s*(.*?)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*\|\s*([^|]*?)\s*(?:\|.*)?$',
    multiLine: false,
  );

  static LabReport parseTable(String rawText) {
    final text = LabAnalyzer._norm(rawText);
    final lines = text.split('\n').map((line) => line.trim()).where((line) => line.isNotEmpty);

    final foundTests = <LabTest>[];

    for (final line in lines) {
      // Satırın bir tablo satırı olup olmadığını kontrol et (| işaretleriyle ayrılmış mı)
      final match = _tableRowRegex.firstMatch(line);
      if (match == null) continue;

      final String testNameCell = match.group(1) ?? '';
      final String resultCell = match.group(2) ?? '';
      final String unitCell = match.group(3) ?? '';
      final String referenceCell = match.group(4) ?? '';

      // Hücrelerden gereksiz "|", "-", ve tekrarlayan boşlukları temizle
      String cleanName = testNameCell.replaceAll(RegExp(r'^\s*[-|]\s*'), '').trim();
      final cleanResult = resultCell.trim();
      final cleanUnit = unitCell.trim();
      String cleanReference = referenceCell.trim();

      // Test adı boşsa veya "Tarih", "Tahlil" gibi başlık satırıysa atla
      if (cleanName.isEmpty ||
          cleanName == 'Tarih' ||
          cleanName == 'Tahlil' ||
          cleanName.contains('Referans Değeri') ||
          cleanName.contains('Sonuç Birimi')) {
        continue;
      }

      // Test adındaki gereksiz tekrarları temizle (örn: "Hemoglobin (Hb) Hemoglobin (Hb)" -> "Hemoglobin (Hb)")
      cleanName = cleanName.replaceAllMapped(RegExp(r'(.+?)(?:\s+\1)+'), (match) => match.group(1) ?? '').trim();

      // Değeri sayıya çevirmeye çalış (12.1, <0.01, Negatif 2)
      double? numericValue;
      String? op;
      final numericMatch = RegExp(r'(?<op>[<>]?)\s*(?<val>\d+[.,]?\d*)').firstMatch(cleanResult);
      if (numericMatch != null) {
        op = numericMatch.namedGroup('op');
        if (op != null && op.isEmpty) op = null;
        final valStr = numericMatch.namedGroup('val')?.replaceAll(',', '.');
        numericValue = double.tryParse(valStr ?? '');
      }

      // Referans aralığını parçala (örn: "12.3 - 15.3", "<0.3", "0 - 10 - Negatif ...")
      String? refLow;
      String? refHigh;
      final rangeMatch = RegExp(r'([<>]?)\s*(\d+[.,]?\d*)\s*[-–]\s*([<>]?)\s*(\d+[.,]?\d*)').firstMatch(cleanReference);
      final singleRefMatch = RegExp(r'([<>]?)\s*(\d+[.,]?\d*)').firstMatch(cleanReference);

      if (rangeMatch != null) {
        refLow = (rangeMatch.group(1)?.isNotEmpty ?? false) ? '${rangeMatch.group(1)}${rangeMatch.group(2)}' : rangeMatch.group(2);
        refHigh = (rangeMatch.group(3)?.isNotEmpty ?? false) ? '${rangeMatch.group(3)}${rangeMatch.group(4)}' : rangeMatch.group(4);
      } else if (singleRefMatch != null) {
        // Tek sınırlı referans (örn: "<0.3")
        final singleOp = singleRefMatch.group(1);
        final singleVal = singleRefMatch.group(2);
        if (singleOp == '<' || singleOp == '≤') {
          refHigh = '$singleOp$singleVal';
        } else if (singleOp == '>' || singleOp == '≥') {
          refLow = '$singleOp$singleVal';
        }
      }

      // Seroloji ve özel durumlar için flag belirle
      LabFlag flag = LabFlag.unknown;
      final lowerResult = cleanResult.toLowerCase();
      final lowerRef = cleanReference.toLowerCase();

      if (lowerResult.contains('negatif') || lowerRef.contains('negatif')) {
        flag = LabFlag.normal;
      } else if (lowerResult.contains('pozitif') || lowerRef.contains('pozitif')) {
        flag = LabFlag.positive;
      } else if (lowerResult.contains('borderline') || lowerRef.contains('borderline') || lowerRef.contains('şüpheli')) {
        flag = LabFlag.borderline;
      } else {
        // Sayısal değerler için flag hesapla
        flag = LabAnalyzer._flagForNumeric(
          value: numericValue,
          op: op,
          low: LabAnalyzer._toDouble(refLow),
          high: LabAnalyzer._toDouble(refHigh),
        );
      }

      // Testi listeye ekle
      foundTests.add(LabTest(
        name: cleanName,
        value: numericValue,
        refLow: refLow,
        refHigh: refHigh,
        unit: cleanUnit.isNotEmpty ? cleanUnit : null,
        op: op,
        flag: flag,
        raw: line,
      ));
    }

    // Aynı isimdeki testleri birleştir (tabloda tekrarlanmış olabilir)
    final uniqueTests = <String, LabTest>{};
    for (final test in foundTests) {
      final existing = uniqueTests[test.name];
      if (existing == null || // İlk kez görülüyorsa ekle
          (test.value != null && existing.value == null) || // Yeni değer daha iyiyse
          (test.refLow != null && existing.refLow == null) || // Yeni referans daha iyiyse
          (test.refHigh != null && existing.refHigh == null)) {
        uniqueTests[test.name] = test;
      }
    }

    return LabReport(uniqueTests.values.toList());
  }
}