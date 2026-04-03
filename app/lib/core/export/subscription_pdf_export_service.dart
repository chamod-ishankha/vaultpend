import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/subscription.dart';

class SubscriptionPdfExportService {
  const SubscriptionPdfExportService();

  Future<pw.Document> buildPdf({
    required List<Subscription> subscriptions,
  }) async {
    final doc = pw.Document();
    final themePrimary = PdfColor.fromInt(0xFF0F766E);
    final dateFmt = DateFormat('MMM d, yyyy h:mm a');
    final currencyFmt = NumberFormat.currency(symbol: '');
    final timestamp = DateFormat('MMM d, yyyy h:mm a').format(DateTime.now());

    final totalMonthlyBurn = subscriptions.fold<double>(
      0,
      (sum, s) => sum + _estimateMonthlyAmount(s.amount, s.cycle),
    );

    // Load logo asset
    final logoBytes = await rootBundle.load('assets/branding/logo.png');
    final logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());

    doc.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(16),
        build: (context) => [
          pw.Header(
            level: 0,
            child: pw.Container(
              padding: const pw.EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 12,
              ),
              decoration: pw.BoxDecoration(color: themePrimary),
              child: pw.Align(
                alignment: pw.Alignment.centerLeft,
                child: pw.Container(
                  height: 120,
                  width: 180,
                  child: pw.Image(logoImage, fit: pw.BoxFit.contain),
                ),
              ),
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Text(
            'Generated: $timestamp',
            style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
          ),
          pw.Divider(),
          pw.SizedBox(height: 12),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Active Subscriptions:',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.Text(
                    '${subscriptions.length}',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    'Est. Monthly Burn:',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.Text(
                    currencyFmt.format(totalMonthlyBurn).trim(),
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
          pw.SizedBox(height: 16),
          pw.TableHelper.fromTextArray(
            headers: [
              'Name',
              'Currency',
              'Amount',
              'Cycle',
              'Next Billing',
              'Trial',
            ],
            data: subscriptions.map((s) {
              return [
                s.name,
                s.currency,
                currencyFmt.format(s.amount).trim(),
                s.cycle,
                dateFmt.format(s.nextBillingDate),
                s.isTrial ? 'Yes' : 'No',
              ];
            }).toList(),
            headerStyle: pw.TextStyle(
              fontWeight: pw.FontWeight.bold,
              fontSize: 10,
              color: PdfColors.white,
            ),
            headerDecoration: pw.BoxDecoration(color: themePrimary),
            rowDecoration: pw.BoxDecoration(
              border: pw.Border.all(color: PdfColors.grey300),
            ),
            cellHeight: 20,
            cellAlignment: pw.Alignment.centerLeft,
            cellPadding: const pw.EdgeInsets.all(4),
          ),
        ],
      ),
    );

    return doc;
  }

  /// Estimate monthly amount from amount and cycle description.
  /// Cycles: monthly, annual, weekly, daily, bi-weekly, etc.
  double _estimateMonthlyAmount(double amount, String cycle) {
    final lower = cycle.toLowerCase();
    if (lower.contains('annual') || lower.contains('yearly')) {
      return amount / 12;
    }
    if (lower.contains('month')) {
      return amount;
    }
    if (lower.contains('week')) {
      return amount * 4.33;
    }
    if (lower.contains('day')) {
      return amount * 30;
    }
    if (lower.contains('bi-week') || lower.contains('biweek')) {
      return amount * 2.17;
    }
    return amount; // default to monthly
  }
}
