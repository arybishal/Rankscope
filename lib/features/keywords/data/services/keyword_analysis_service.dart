import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/keyword.dart';
import '../../domain/entities/rank_observation.dart';

enum InsightType {
  improving,
  declining,
  ctrOpportunity,
  newKeyword,
  lostKeyword,
  rankingUrlChange,
  cannibalization,
}

/// Transparent, rules-based insight explaining its data basis, timeframe, and limitations.
class KeywordInsight {
  final InsightType type;
  final String title;
  final String description;
  final String dataBasis;
  final String dateRange;
  final String limitation;
  final Keyword keyword;
  final String searchEngine;
  final IconData icon;
  final Color color;
  final int severity; // 1 = info, 2 = warning, 3 = critical

  const KeywordInsight({
    required this.type,
    required this.title,
    required this.description,
    required this.dataBasis,
    required this.dateRange,
    required this.limitation,
    required this.keyword,
    required this.searchEngine,
    required this.icon,
    required this.color,
    this.severity = 1,
  });
}

/// Rules-based analysis engine for SEO keyword intelligence.
class KeywordAnalysisService {
  const KeywordAnalysisService();

  /// Evaluates keywords and their observation history to generate transparent insights.
  List<KeywordInsight> generateInsights({
    required List<Keyword> keywords,
    required Map<int, List<RankObservation>> observationsByKeywordId,
    String timeFrameLabel = 'Last 30 Days',
  }) {
    final List<KeywordInsight> insights = [];

    for (final kw in keywords) {
      if (!kw.isActive) continue;

      final observations = observationsByKeywordId[kw.id] ?? [];

      // 1. High Impressions & Low CTR Opportunity
      _checkCtrOpportunity(kw, insights, timeFrameLabel);

      // 2. Ranking Movement (Improving / Declining)
      _checkRankingMovement(kw, insights, timeFrameLabel);

      // 3. Ranking URL Changes
      _checkUrlChanges(kw, observations, insights, timeFrameLabel);

      // 4. Cannibalization Detection
      _checkCannibalization(kw, observations, insights, timeFrameLabel);

      // 5. New or Lost Keyword Events
      _checkNewOrLost(kw, observations, insights, timeFrameLabel);
    }

    // Sort by severity (critical first) then alphabetically by keyword
    insights.sort((a, b) {
      final s = b.severity.compareTo(a.severity);
      if (s != 0) return s;
      return a.keyword.keywordText.compareTo(b.keyword.keywordText);
    });

    return insights;
  }

  void _checkCtrOpportunity(
    Keyword kw,
    List<KeywordInsight> insights,
    String timeFrame,
  ) {
    // Check Google
    if (kw.googleImpressions >= 50 &&
        kw.googleCtr < 0.025 &&
        (kw.googleAveragePosition != null && kw.googleAveragePosition! <= 20)) {
      insights.add(
        KeywordInsight(
          type: InsightType.ctrOpportunity,
          title: 'CTR Optimization Opportunity',
          description:
              '"${kw.keywordText}" has strong search visibility on Google (Avg #${kw.googleAveragePosition!.toStringAsFixed(1)}) but low click-through rate (${(kw.googleCtr * 100).toStringAsFixed(1)}%).',
          dataBasis:
              'Google Search Console: ${kw.googleImpressions} impressions, ${kw.googleClicks} clicks, CTR ${(kw.googleCtr * 100).toStringAsFixed(1)}% at average position ${kw.googleAveragePosition!.toStringAsFixed(1)}.',
          dateRange: timeFrame,
          limitation:
              'Informational queries or rich snippets can depress CTR naturally. Verify title tag and meta description relevance.',
          keyword: kw,
          searchEngine: 'Google',
          icon: Icons.lightbulb_outline,
          color: const Color(0xFFD97706),
          severity: 1,
        ),
      );
    }

    // Check Bing
    if (kw.bingImpressions >= 40 &&
        kw.bingCtr < 0.025 &&
        (kw.bingAveragePosition != null && kw.bingAveragePosition! <= 20)) {
      insights.add(
        KeywordInsight(
          type: InsightType.ctrOpportunity,
          title: 'Bing CTR Opportunity',
          description:
              '"${kw.keywordText}" has ${kw.bingImpressions} Bing impressions but low clicks (${kw.bingClicks}).',
          dataBasis:
              'Bing Webmaster Tools: ${kw.bingImpressions} impressions, ${kw.bingClicks} clicks, CTR ${(kw.bingCtr * 100).toStringAsFixed(1)}%.',
          dateRange: timeFrame,
          limitation:
              'Bing search volume may be region-specific. Review desktop vs mobile snippet preview.',
          keyword: kw,
          searchEngine: 'Bing',
          icon: Icons.lightbulb_outline,
          color: const Color(0xFF0284C7),
          severity: 1,
        ),
      );
    }

    // Check Yandex
    if (kw.yandexImpressions >= 40 &&
        kw.yandexCtr < 0.025 &&
        (kw.yandexAveragePosition != null && kw.yandexAveragePosition! <= 20)) {
      insights.add(
        KeywordInsight(
          type: InsightType.ctrOpportunity,
          title: 'Yandex CTR Opportunity',
          description:
              '"${kw.keywordText}" has ${kw.yandexImpressions} shows on Yandex with low CTR (${(kw.yandexCtr * 100).toStringAsFixed(1)}%).',
          dataBasis:
              'Yandex Webmaster: ${kw.yandexImpressions} shows, ${kw.yandexClicks} clicks, AVG_SHOW_POSITION ${kw.yandexAveragePosition!.toStringAsFixed(1)}.',
          dateRange: timeFrame,
          limitation:
              'Yandex SERP snippet formatting and regional targeting affect click-through.',
          keyword: kw,
          searchEngine: 'Yandex',
          icon: Icons.lightbulb_outline,
          color: const Color(0xFFEA580C),
          severity: 1,
        ),
      );
    }
  }

  void _checkRankingMovement(
    Keyword kw,
    List<KeywordInsight> insights,
    String timeFrame,
  ) {
    // In search ranking: negative delta means position number decreased (e.g. 5 -> 3, which is an improvement)
    if (kw.googleDelta < 0 && kw.googlePosition != null && kw.googlePreviousPosition != null) {
      final gain = kw.googleDelta.abs();
      if (gain >= 2) {
        insights.add(
          KeywordInsight(
            type: InsightType.improving,
            title: 'Google Rank Gained (+$gain)',
            description:
                '"${kw.keywordText}" climbed from #${kw.googlePreviousPosition} to #${kw.googlePosition} on Google.',
            dataBasis:
                'Observed Google position comparison: previous #${kw.googlePreviousPosition} vs current #${kw.googlePosition}.',
            dateRange: timeFrame,
            limitation:
                'Discrete SERP checks may fluctuate by data center, browser language, or personalization.',
            keyword: kw,
            searchEngine: 'Google',
            icon: Icons.trending_up,
            color: AppColors.rankGain,
            severity: 1,
          ),
        );
      }
    } else if (kw.googleDelta > 0 && kw.googlePosition != null && kw.googlePreviousPosition != null) {
      final loss = kw.googleDelta;
      if (loss >= 2) {
        insights.add(
          KeywordInsight(
            type: InsightType.declining,
            title: 'Google Rank Declined (-$loss)',
            description:
                '"${kw.keywordText}" slipped from #${kw.googlePreviousPosition} down to #${kw.googlePosition} on Google.',
            dataBasis:
                'Observed Google position comparison: previous #${kw.googlePreviousPosition} vs current #${kw.googlePosition}.',
            dateRange: timeFrame,
            limitation:
                'Check competitor changes, page indexing status, or recent algorithm rollouts.',
            keyword: kw,
            searchEngine: 'Google',
            icon: Icons.trending_down,
            color: AppColors.rankDrop,
            severity: 2,
          ),
        );
      }
    }
  }

  void _checkUrlChanges(
    Keyword kw,
    List<RankObservation> observations,
    List<KeywordInsight> insights,
    String timeFrame,
  ) {
    if (observations.length < 2) return;

    final urlObservations = observations.where((o) => o.rankingUrl != null && o.rankingUrl!.isNotEmpty).toList();
    if (urlObservations.length < 2) return;

    final latestUrl = urlObservations.first.rankingUrl!;
    final previousUrl = urlObservations[1].rankingUrl;

    if (previousUrl != null && previousUrl.isNotEmpty && latestUrl != previousUrl) {
      insights.add(
        KeywordInsight(
          type: InsightType.rankingUrlChange,
          title: 'Ranking URL Changed',
          description:
              'Search engines changed the active ranking landing page for "${kw.keywordText}".',
          dataBasis:
              'Observed transition: previous "$previousUrl" replaced by "$latestUrl".',
          dateRange: timeFrame,
          limitation:
              'Occurs when search engines re-evaluate page relevance or canonical signals across multiple pages.',
          keyword: kw,
          searchEngine: urlObservations.first.searchEngine,
          icon: Icons.swap_horiz,
          color: const Color(0xFF7C3AED),
          severity: 2,
        ),
      );
    }
  }

  void _checkCannibalization(
    Keyword kw,
    List<RankObservation> observations,
    List<KeywordInsight> insights,
    String timeFrame,
  ) {
    final distinctUrls = observations
        .map((o) => o.rankingUrl)
        .whereType<String>()
        .where((u) => u.isNotEmpty)
        .toSet()
        .toList();

    // Cannibalization requires at least 3 observations and 2+ distinct URLs
    if (distinctUrls.length >= 2 && observations.length >= 3) {
      insights.add(
        KeywordInsight(
          type: InsightType.cannibalization,
          title: 'Potential Keyword Cannibalization',
          description:
              'Multiple distinct URLs (${distinctUrls.length}) are competing for "${kw.keywordText}".',
          dataBasis:
              'Distinct observed URLs in history: ${distinctUrls.take(3).join(', ')}.',
          dateRange: timeFrame,
          limitation:
              'Valid only when observations come from comparable search environments. Review internal linking and canonical tags.',
          keyword: kw,
          searchEngine: kw.searchEngine,
          icon: Icons.warning_amber_rounded,
          color: const Color(0xFFDC2626),
          severity: 3,
        ),
      );
    }
  }

  void _checkNewOrLost(
    Keyword kw,
    List<RankObservation> observations,
    List<KeywordInsight> insights,
    String timeFrame,
  ) {
    if (observations.length < 2) return;

    if (kw.isNew) {
      insights.add(
        KeywordInsight(
          type: InsightType.newKeyword,
          title: 'New Ranking Query',
          description:
              '"${kw.keywordText}" has recently entered the search rankings.',
          dataBasis:
              'First observed ranking on ${kw.firstRankedAt != null ? kw.firstRankedAt!.toIso8601String().substring(0, 10) : "recent check"}.',
          dateRange: timeFrame,
          limitation:
              'Requires sustained ranking across multiple checks to confirm stability.',
          keyword: kw,
          searchEngine: kw.searchEngine,
          icon: Icons.fiber_new,
          color: const Color(0xFF16A34A),
          severity: 1,
        ),
      );
    } else if (kw.isLost) {
      insights.add(
        KeywordInsight(
          type: InsightType.lostKeyword,
          title: 'Lost Ranking Query',
          description:
              '"${kw.keywordText}" dropped out of the tracked top 100 search positions.',
          dataBasis:
              'Previous position was recorded at #${kw.previousPosition ?? kw.googlePreviousPosition ?? "?"}; latest check found no ranking in top 100.',
          dateRange: timeFrame,
          limitation:
              'Check if the target URL returns 404, has a noindex tag, or was temporarily deindexed.',
          keyword: kw,
          searchEngine: kw.searchEngine,
          icon: Icons.cancel_outlined,
          color: AppColors.rankDrop,
          severity: 3,
        ),
      );
    }
  }
}
