import 'package:flutter_test/flutter_test.dart';
import 'package:rankscope/features/manual_tracking/domain/entities/manual_rank_record.dart';

void main() {
  group('ManualRankRecord & Bitmask', () {
    test('encodes and decodes SERP features correctly', () {
      final mask = ManualRankRecord.buildBitmask(
        featuredSnippet: true,
        localPack: false,
        peopleAlsoAsk: true,
        videoCarousel: false,
      );

      final record = ManualRankRecord(
        keywordId: 1,
        websiteId: 1,
        position: 3,
        serpFeaturesMask: mask,
        recordedAt: DateTime.now(),
      );

      expect(record.hasFeaturedSnippet, isTrue);
      expect(record.hasLocalPack, isFalse);
      expect(record.hasPeopleAlsoAsk, isTrue);
      expect(record.hasVideoCarousel, isFalse);
      expect(record.position, 3);
    });
  });
}
