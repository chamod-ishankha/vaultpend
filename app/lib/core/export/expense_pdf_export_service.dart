import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import '../../data/models/expense.dart';

class ExpensePdfExportService {
  const ExpensePdfExportService();

  Future<pw.Document> buildPdf({
    required List<Expense> expenses,
    required Map<int, String> categoryNames,
  }) async {
    final doc = pw.Document();
    final themePrimary = PdfColor.fromInt(0xFF0F766E);
    final dateFmt = DateFormat('MMM d, yyyy h:mm a');
    final currencyFmt = NumberFormat.currency(symbol: '');
    final timestamp = DateFormat('MMM d, yyyy h:mm a').format(DateTime.now());

    final totalAmount = expenses.fold<double>(0, (sum, e) => sum + e.amount);

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
                    'Total Records:',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.Text(
                    '${expenses.length}',
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
                    'Total Amount:',
                    style: const pw.TextStyle(fontSize: 11),
                  ),
                  pw.Text(
                    currencyFmt.format(totalAmount).trim(),
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
              'Date',
              'Category',
              'Currency',
              'Amount',
              'Recurring',
              'Note',
            ],
            data: expenses.map((e) {
              final category = e.categoryId == null
                  ? 'Uncategorized'
                  : categoryNames[e.categoryId!] ?? 'Unknown';
              return [
                dateFmt.format(e.occurredAt),
                category,
                e.currency,
                currencyFmt.format(e.amount).trim(),
                e.isRecurring ? 'Yes' : 'No',
                e.note ?? '',
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
}
