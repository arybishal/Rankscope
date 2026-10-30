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
      'Delta',
      'Google Avg Position',
      'Google Clicks',
      'Google Impressions',
      'Google Ranking URL',
      'Bing Avg Position',
      'Bing Clicks',
      'Bing Impressions',
      'Bing Ranking URL',
      'Target URL',
      'Target URL Match Status',
      'Manual Google SERP',
      'Manual Bing SERP',
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
        deltaStr,
        kw.googleAveragePosition?.toStringAsFixed(1) ?? '—',
        kw.googleClicks,
        kw.googleImpressions,
        kw.googleRankingUrl ?? '—',
        kw.bingAveragePosition?.toStringAsFixed(1) ?? '—',
        kw.bingClicks,
        kw.bingImpressions,
        kw.bingRankingUrl ?? '—',
        kw.targetUrl ?? '—',
        kw.urlMatchStatus,
        kw.googlePosition == null
            ? '—'
            : (kw.googlePosition == 0 ? 'Not Ranking (0)' : kw.googlePosition),
        kw.bingPosition == null
            ? '—'
            : (kw.bingPosition == 0 ? 'Not Ranking (0)' : kw.bingPosition),
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
