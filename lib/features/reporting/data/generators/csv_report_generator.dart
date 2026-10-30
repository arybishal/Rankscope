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
      'Search Engine',
      'Current Position',
      'Previous Position',
      'Delta',
      'Google Position',
      'Bing Position',
      'Ranking URL',
      'Target URL',
      'Country',
      'City',
      'Language',
      'Device',
      'Tracking Status',
      'Cannibalization Alert',
      'Status Event',
      'Last Checked',
    ]);

    // Data rows
    for (final kw in keywords) {
      final deltaStr = kw.positionDelta > 0
          ? '+${kw.positionDelta}'
          : (kw.positionDelta < 0 ? '${kw.positionDelta}' : '0');

      rows.add([
        kw.keywordText,
        kw.searchEngine,
        kw.latestPosition == null
            ? 'Pending'
            : (kw.latestPosition == 0 ? 'Not Ranking (0)' : kw.latestPosition),
        kw.previousPosition ?? '—',
        deltaStr,
        kw.googlePosition == null
            ? '—'
            : (kw.googlePosition == 0 ? 'Not Ranking (0)' : kw.googlePosition),
        kw.bingPosition == null
            ? '—'
            : (kw.bingPosition == 0 ? 'Not Ranking (0)' : kw.bingPosition),
        kw.rankingUrl ?? '—',
        kw.targetUrl ?? '—',
        kw.targetCountry,
        kw.targetCity ?? '—',
        kw.language,
        kw.device,
        kw.isActive ? 'Active' : 'Paused',
        kw.cannibalizationStatus,
        kw.statusEvent,
        kw.lastCheckedAt?.toIso8601String() ?? 'Never',
      ]);
    }

    final csvString = csv.encode(rows);
    return utf8.encode(csvString);
  }
}
