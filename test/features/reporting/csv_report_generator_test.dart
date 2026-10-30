import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/features/keywords/domain/entities/keyword.dart';
import 'package:rankscope/features/reporting/data/generators/csv_report_generator.dart';
import 'package:rankscope/features/websites/domain/entities/website.dart';

void main() {
  group('CsvReportGenerator', () {
    test('generates valid RFC 4180 CSV bytes', () {
      final now = DateTime.now();
      final website = Website(
        id: 1,
        domain: 'example.com',
        label: 'My Brand',
        createdAt: now,
        updatedAt: now,
      );

      final keywords = [
        Keyword(
          id: 1,
          websiteId: 1,
          keywordText: 'best flutter developer',
          latestPosition: 2,
          previousPosition: 5,
          positionDelta: 3,
          createdAt: now,
        ),
      ];

      final bytes = CsvReportGenerator.generateKeywordsCsv(
        website: website,
        keywords: keywords,
      );

      final csvText = utf8.decode(bytes);
      expect(csvText, contains('example.com'));
      expect(csvText, contains('best flutter developer'));
      expect(csvText, contains('+3'));
    });
  });
}
