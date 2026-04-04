import 'dart:math' as math;

import 'package:logging/logging.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';

class ReceiptScanResult {
  const ReceiptScanResult({
    required this.rawText,
    this.amount,
    this.note,
    this.amountCandidates = const [],
  });

  final String rawText;
  final double? amount;
  final String? note;
  final List<ReceiptAmountCandidate> amountCandidates;
}

class ReceiptAmountCandidate {
  const ReceiptAmountCandidate({
    required this.amount,
    required this.line,
    required this.score,
    required this.reason,
  });

  final double amount;
  final String line;
  final int score;
  final String reason;
}

class ReceiptOcrService {
  ReceiptOcrService({ImagePicker? imagePicker})
    : _imagePicker = imagePicker ?? ImagePicker();

  final ImagePicker _imagePicker;

  Future<ReceiptScanResult?> scanReceiptFromSource(
    ImageSource source, {
    Logger? logger,
  }) async {
    logger?.info('receipt_ocr_pick_started source=$source');

    final picked = await _imagePicker.pickImage(
      source: source,
      imageQuality: 85,
    );
    if (picked == null) {
      logger?.info('receipt_ocr_pick_cancelled source=$source');
      return null;
    }

    logger?.info(
      'receipt_ocr_pick_succeeded source=$source path=${picked.path} name=${picked.name}',
    );

    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(picked.path);
      logger?.info('receipt_ocr_recognition_started path=${picked.path}');
      final recognized = await recognizer.processImage(inputImage);
      final rawText = recognized.text.trim();
      if (rawText.isEmpty) {
        logger?.warning('receipt_ocr_recognition_empty path=${picked.path}');
        return const ReceiptScanResult(rawText: '');
      }

      final lines = recognized.blocks
          .expand((block) => block.lines)
          .map((line) => line.text.trim())
          .where((line) => line.isNotEmpty)
          .toList(growable: false);

      final amountCandidates = _extractAmountCandidates(lines);
      final amountResult = amountCandidates.isEmpty
          ? null
          : amountCandidates.first;
      logger?.info(
        'receipt_ocr_amount_selected amount=${amountResult == null ? 'none' : amountResult.amount.toStringAsFixed(2)} line=${amountResult?.line ?? 'none'} reason=${amountResult?.reason ?? 'none'}',
      );

      return ReceiptScanResult(
        rawText: rawText,
        amount: amountResult?.amount,
        note: _extractNote(lines),
        amountCandidates: amountCandidates,
      );
    } catch (error, stack) {
      logger?.severe('receipt_ocr_failed path=${picked.path}', error, stack);
      rethrow;
    } finally {
      await recognizer.close();
    }
  }

  List<ReceiptAmountCandidate> _extractAmountCandidates(List<String> lines) {
    final candidates = <ReceiptAmountCandidate>[];

    for (var index = 0; index < lines.length; index++) {
      final line = lines[index];
      final parsed = _lineCandidate(line, index);
      if (parsed != null) {
        candidates.add(parsed);
      }
    }

    if (candidates.isEmpty) {
      return const [];
    }

    candidates.sort((a, b) {
      final byScore = b.score.compareTo(a.score);
      if (byScore != 0) return byScore;
      return b.amount.compareTo(a.amount);
    });

    return candidates;
  }

  ReceiptAmountCandidate? _lineCandidate(String line, int index) {
    final normalized = line.toLowerCase();
    if (_isReferenceLine(normalized)) {
      return null;
    }

    final amounts = _amountsInLine(line);
    if (amounts.isEmpty) {
      return null;
    }

    final keywordScore = _keywordScore(normalized);
    final symbolScore =
        RegExp(
          r'[\$€£₹₨]|\b(?:usd|lkr|eur|rs\.?|r[ss]\.?|s\$|l\$)\b',
          caseSensitive: false,
        ).hasMatch(line)
        ? 18
        : 0;
    final decimalScore = line.contains('.') || line.contains(',') ? 8 : 0;
    final positionScore = math.max(0, 12 - index);
    final phonePenalty = _looksLikePhoneNumber(line) ? -80 : 0;
    final amount = _chooseLineAmount(line, amounts);

    if (amount == null) {
      return null;
    }

    var score =
        keywordScore +
        symbolScore +
        decimalScore +
        positionScore +
        phonePenalty;
    if (score <= 0 && amount > 9999 && !_looksLikeCurrencyAmount(line)) {
      return null;
    }

    if (normalized.contains('total')) {
      score += 30;
    }
    if (normalized.contains('grand total')) {
      score += 20;
    }
    if (normalized.contains('amount due') ||
        normalized.contains('balance due')) {
      score += 18;
    }

    return ReceiptAmountCandidate(
      amount: amount,
      line: line,
      score: score,
      reason: _candidateReason(normalized, score),
    );
  }

  List<double> _amountsInLine(String line) {
    final regex = RegExp(
      r'(?<!\d)(?:[\$€£₹₨]\s*)?(?:\d{1,3}(?:[,\s]\d{3})+|\d+)(?:[.,]\d{2})?(?!\d)',
    );
    final values = <double>[];
    for (final match in regex.allMatches(line)) {
      final raw = match.group(0);
      if (raw == null) continue;
      final normalized = raw
          .replaceAll(RegExp(r'[\$€£₹₨\s]'), '')
          .replaceAll(',', '');
      final parsed = double.tryParse(normalized);
      if (parsed != null) {
        values.add(parsed);
      }
    }
    return values;
  }

  double? _chooseLineAmount(String line, List<double> amounts) {
    if (amounts.isEmpty) return null;

    final normalized = line.toLowerCase();
    if (normalized.contains('total') ||
        normalized.contains('amount due') ||
        normalized.contains('balance due') ||
        normalized.contains('grand total') ||
        normalized.contains('payable')) {
      return amounts.last;
    }

    if (_looksLikeCurrencyAmount(line)) {
      return amounts.last;
    }

    if (amounts.length == 1) {
      return amounts.first;
    }

    // Prefer the last value on a line since receipt totals are commonly right-aligned.
    return amounts.last;
  }

  bool _looksLikeCurrencyAmount(String line) {
    return RegExp(
      r'[\$€£₹₨]|\b(?:usd|lkr|eur|rs\.?|r[ss]\.?|s\$|l\$)\b',
      caseSensitive: false,
    ).hasMatch(line);
  }

  bool _looksLikePhoneNumber(String line) {
    final digits = RegExp(r'\d').allMatches(line).length;
    return digits >= 8 &&
        !line.contains('.') &&
        !line.contains(',') &&
        !line.toLowerCase().contains('total') &&
        !line.toLowerCase().contains('amount') &&
        !line.toLowerCase().contains('due') &&
        !line.toLowerCase().contains('balance') &&
        !line.toLowerCase().contains('grand') &&
        !line.toLowerCase().contains('payable');
  }

  bool _isReferenceLine(String normalized) {
    final referenceKeywords = [
      'phone',
      'telephone',
      'mobile',
      'fax',
      'contact',
      'bill no',
      'bill number',
      'invoice no',
      'invoice number',
      'reference',
      'ref no',
      'ref number',
      'account no',
      'customer id',
      'vat no',
      'order no',
      'transaction id',
    ];
    return referenceKeywords.any(normalized.contains);
  }

  int _keywordScore(String normalized) {
    if (normalized.contains('grand total')) return 45;
    if (normalized.contains('amount due') ||
        normalized.contains('balance due')) {
      return 40;
    }
    if (normalized.contains('amount payable') ||
        normalized.contains('payable')) {
      return 38;
    }
    if (normalized.contains('net total')) return 35;
    if (normalized.contains('sub total') || normalized.contains('subtotal')) {
      return 30;
    }
    if (normalized.contains('total')) return 28;
    if (normalized.contains('amount')) return 22;
    if (normalized.contains('due')) return 18;
    if (normalized.contains('balance')) return 16;
    return 0;
  }

  String _candidateReason(String normalized, int score) {
    if (score >= 60) return 'strong-keyword';
    if (normalized.contains('total')) return 'total-line';
    if (_looksLikeCurrencyAmount(normalized)) return 'currency-line';
    return 'fallback-line';
  }

  String? _extractNote(List<String> lines) {
    for (final line in lines) {
      if (RegExp(r'[A-Za-z]').hasMatch(line) &&
          !line.toLowerCase().contains('total') &&
          !line.toLowerCase().contains('tax') &&
          !line.toLowerCase().contains('change')) {
        return line;
      }
    }
    return null;
  }
}
