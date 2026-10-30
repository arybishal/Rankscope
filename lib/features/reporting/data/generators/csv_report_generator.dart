import 'dart:convert';

import 'package:csv/csv.dart';
import 'package:rankscope/features/keywords/domain/entities/keyword.dart';
import 'package:rankscope/features/websites/domain/entities/website.dart';

/// Offline RFC 4180 CSV report generator for keyword rankings and audit logs.
class CsvReportGenerator {
  CsvReportGenerator._();

  static List<int> generateKeywordsCsv({
    required Website website,
    required List<Keyword> keywords,
  }) {
    final List<List<dynamic>> rows = [];

    // Header metadata
    rows.add(['RankScope Executive SEO Ranking Audit']);
    rows.add(['Domain', website.domain]);
    rows.add(['Property Label', website.label]);
    rows.add(['Competitor Property', website.isCompetitor ? 'Yes' : 'No']);
    rows.add(['Export Timestamp', DateTime.now().toIso8601String()]);
    rows.add([]); // empty separator line

    // Column headers
    rows.add([
      'Keyword',
      'Latest Position',
      'Previous Position',
      'Delta',
      'Target Country',
      'Target City',
      'Target URL',
      'Tags',
      'Status',
      'Last Audited',
    ]);

    // Data rows
    for (final kw in keywords) {
      final deltaStr = kw.positionDelta > 0
          ? '+${kw.positionDelta}'
          : (kw.positionDelta < 0 ? '${kw.positionDelta}' : '0');

      rows.add([
        kw.keywordText,
        kw.latestPosition ?? 'Unranked',
        kw.previousPosition ?? '—',
        deltaStr,
        kw.targetCountry,
        kw.targetCity ?? '—',
        kw.targetUrl ?? '—',
        kw.tags.join('; '),
        kw.isActive ? 'Active' : 'Paused',
        kw.lastCheckedAt?.toIso8601String() ?? 'Never',
      ]);
    }

    final csvString = csv.encode(rows);
    return utf8.encode(csvString);
  }
}
