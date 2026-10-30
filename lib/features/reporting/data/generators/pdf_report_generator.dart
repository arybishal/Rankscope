import 'dart:typed_data';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:rankscope/core/utils/date_formatter.dart';
import 'package:rankscope/features/keywords/domain/entities/keyword.dart';
import 'package:rankscope/features/websites/domain/entities/website.dart';

/// Offline vector PDF report generator running purely in device memory.
class PdfReportGenerator {
  PdfReportGenerator._();

  static Future<Uint8List> generatePdfReport({
    required Website website,
    required List<Keyword> keywords,
  }) async {
    final pdf = pw.Document();

    // Calculate executive KPIs
    final totalKeywords = keywords.length;
    final rankedKeywords = keywords.where((k) => k.latestPosition != null).toList();
    final top3Count = keywords.where((k) => (k.latestPosition ?? 101) <= 3).length;
    final top10Count = keywords.where((k) => (k.latestPosition ?? 101) <= 10).length;

    double avgPos = 0.0;
    if (rankedKeywords.isNotEmpty) {
      final sum = rankedKeywords.fold<int>(0, (prev, k) => prev + k.latestPosition!);
      avgPos = sum / rankedKeywords.length;
    }

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(32),
        build: (pw.Context context) {
          return [
            // Header
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'RankScope',
                      style: pw.TextStyle(
                        fontSize: 22,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blueGrey900,
                      ),
                    ),
                    pw.Text(
                      'Executive Organic Search Performance Audit',
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.end,
                  children: [
                    pw.Text(
                      website.domain,
                      style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
                    ),
                    pw.Text(
                      DateFormatter.toMedium(DateTime.now()),
                      style: const pw.TextStyle(fontSize: 10, color: PdfColors.grey600),
                    ),
                  ],
                ),
              ],
            ),
            pw.Divider(thickness: 1, color: PdfColors.grey300),
            pw.SizedBox(height: 16),

            // KPI Grid
            pw.Row(
              children: [
                _buildKpiCard('Tracked Keywords', '$totalKeywords'),
                pw.SizedBox(width: 12),
                _buildKpiCard('Top 3 Positions', '$top3Count'),
                pw.SizedBox(width: 12),
                _buildKpiCard('Top 10 Positions', '$top10Count'),
                pw.SizedBox(width: 12),
                _buildKpiCard('Avg. Rank', avgPos > 0 ? avgPos.toStringAsFixed(1) : '—'),
              ],
            ),
            pw.SizedBox(height: 24),

            // Keyword Table
            pw.Text(
              'Keyword Audit Inventory',
              style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
            ),
            pw.SizedBox(height: 8),

            pw.TableHelper.fromTextArray(
              headers: ['Keyword', 'Rank', 'Delta', 'Location', 'Last Audited'],
              data: keywords.map((k) {
                final rankStr = k.latestPosition != null ? '#${k.latestPosition}' : '—';
                final deltaStr = k.positionDelta > 0
                    ? '+${k.positionDelta}'
                    : (k.positionDelta < 0 ? '${k.positionDelta}' : '0');
                final locStr = k.targetCity != null ? '${k.targetCity}, ${k.targetCountry}' : k.targetCountry;
                final dateStr = k.lastCheckedAt != null ? DateFormatter.toMedium(k.lastCheckedAt!) : 'Never';

                return [k.keywordText, rankStr, deltaStr, locStr, dateStr];
              }).toList(),
              headerStyle: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              cellStyle: const pw.TextStyle(fontSize: 9),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.grey100),
              rowDecoration: const pw.BoxDecoration(
                border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey200, width: 0.5)),
              ),
              cellAlignment: pw.Alignment.centerLeft,
            ),
            pw.SizedBox(height: 24),

            // Footer note
            pw.Text(
              'Generated completely on-device with zero server transmission. RankScope operates offline-first.',
              style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey500),
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _buildKpiCard(String title, String value) {
    return pw.Expanded(
      child: pw.Container(
        padding: const pw.EdgeInsets.all(12),
        decoration: pw.BoxDecoration(
          border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
          borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
          color: PdfColors.grey50,
        ),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              title.toUpperCase(),
              style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey600),
            ),
            pw.SizedBox(height: 4),
            pw.Text(
              value,
              style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
            ),
          ],
        ),
      ),
    );
  }
}
