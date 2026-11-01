import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../domain/entities/cannibalization_finding.dart';
import '../../domain/entities/keyword.dart';
import '../../domain/entities/rank_observation.dart';
import '../../domain/entities/ranking_alert.dart';
import '../../domain/models/alert_settings.dart';

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

  /// Detects detailed keyword cannibalization diagnostics across tracked keywords and URL observations.
  List<CannibalizationFinding> detectCannibalization({
    required List<Keyword> keywords,
    required Map<int, List<RankObservation>> observationsByKeywordId,
    String dateRange = 'Last 30 Days',
  }) {
    final List<CannibalizationFinding> findings = [];

    for (final kw in keywords) {
      if (!kw.isActive || kw.id == null) continue;

      final obsList = observationsByKeywordId[kw.id!] ?? [];
      final validObs = obsList
          .where((o) => o.rankingUrl != null && o.rankingUrl!.trim().isNotEmpty)
          .toList();

      if (validObs.length < 2) continue;

      // Group observations by distinct URL
      final Map<String, List<RankObservation>> obsByUrl = {};
      for (final obs in validObs) {
        final url = obs.rankingUrl!.trim();
        obsByUrl.putIfAbsent(url, () => []).add(obs);
      }

      // Cannibalization requires at least 2 distinct URLs
      if (obsByUrl.keys.length < 2) continue;

      int totalImpressions = 0;
      final List<CannibalizationUrlMetric> urlMetrics = [];

      for (final entry in obsByUrl.entries) {
        final url = entry.key;
        final list = entry.value;

        int urlImp = 0;
        int urlClk = 0;
        double posSum = 0;
        int posCount = 0;
        DateTime? latestSeen;

        for (final o in list) {
          urlImp += o.impressions;
          urlClk += o.clicks;
          if (o.averagePosition != null && o.averagePosition! > 0) {
            posSum += o.averagePosition!;
            posCount++;
          } else if (o.position > 0) {
            posSum += o.position.toDouble();
            posCount++;
          }
          if (latestSeen == null || o.recordedAt.isAfter(latestSeen)) {
            latestSeen = o.recordedAt;
          }
        }

        totalImpressions += urlImp;

        urlMetrics.add(
          CannibalizationUrlMetric(
            url: url,
            impressions: urlImp,
            clicks: urlClk,
            averagePosition: posCount > 0 ? (posSum / posCount) : null,
            latestSeen: latestSeen,
          ),
        );
      }

      // Sort URLs by impressions descending, then clicks
      urlMetrics.sort((a, b) {
        final cmp = b.impressions.compareTo(a.impressions);
        if (cmp != 0) return cmp;
        return b.clicks.compareTo(a.clicks);
      });

      // Calculate confidence
      final primary = urlMetrics.first;
      final secondary = urlMetrics[1];
      final secondaryImpShare = totalImpressions > 0
          ? (secondary.impressions / totalImpressions)
          : 0.0;

      CannibalizationConfidence confidence;
      String evidence;
      String recommendation;

      if (totalImpressions > 0 && secondaryImpShare >= 0.20 && validObs.length >= 3) {
        confidence = CannibalizationConfidence.high;
        evidence =
            'Multiple URLs actively competing for impressions. Primary page received ${primary.impressions} impressions (${((primary.impressions / totalImpressions) * 100).toStringAsFixed(1)}%) while secondary page received ${secondary.impressions} impressions (${(secondaryImpShare * 100).toStringAsFixed(1)}%).';
        recommendation =
            'Consolidate duplicate topic content. Add a rel="canonical" tag from secondary pages to your primary intended landing page, or implement a 301 redirect if the secondary page is obsolete.';
      } else if (secondaryImpShare >= 0.05 || (obsByUrl.keys.length >= 2 && validObs.length >= 3)) {
        confidence = CannibalizationConfidence.medium;
        evidence =
            'Search engines observed alternating landing pages across reporting dates. Competing pages: ${urlMetrics.map((u) => u.url).take(3).join(', ')}.';
        recommendation =
            'Review search intent separation. Differentiate title tags, H1 headings, and internal link anchor text to make page topics distinct.';
      } else {
        confidence = CannibalizationConfidence.low;
        evidence =
            'Secondary URL appeared sporadically in search results with minor impressions (${secondary.impressions} of $totalImpressions total impressions).';
        recommendation =
            'Monitor upcoming sync checks. This may be temporary search engine algorithm testing rather than a persistent cannibalization conflict.';
      }

      findings.add(
        CannibalizationFinding(
          keywordId: kw.id!,
          websiteId: kw.websiteId,
          keywordText: kw.keywordText,
          searchEngine: kw.searchEngine,
          affectedUrls: urlMetrics,
          confidence: confidence,
          dateRange: dateRange,
          evidence: evidence,
          recommendation: recommendation,
        ),
      );
    }

    return findings;
  }

  /// Evaluates keyword metrics against user-configured AlertSettings to produce ranking alerts.
  List<RankingAlert> evaluateAlerts({
    required int websiteId,
    required List<Keyword> keywords,
    required Map<int, List<RankObservation>> observationsByKeywordId,
    required AlertSettings settings,
    DateTime? timestamp,
  }) {
    final now = timestamp ?? DateTime.now();
    final List<RankingAlert> alerts = [];

    for (final kw in keywords) {
      if (!kw.isActive || kw.id == null) continue;

      final observations = observationsByKeywordId[kw.id!] ?? [];

      // 1. Significant Ranking Improvement
      if (settings.rankGainEnabled) {
        // Compare Google positions if present
        if (kw.googlePosition != null && kw.googlePreviousPosition != null) {
          final gain = kw.googlePreviousPosition! - kw.googlePosition!;
          if (gain >= settings.rankGainThreshold) {
            alerts.add(
              RankingAlert(
                websiteId: websiteId,
                keywordId: kw.id,
                alertType: 'rank_gain',
                severity: 'info',
                title: 'Google Rank Gained (+$gain)',
                message:
                    '"${kw.keywordText}" climbed from #${kw.googlePreviousPosition} to #${kw.googlePosition} on Google.',
                searchEngine: 'Google',
                createdAt: now,
              ),
            );
          }
        }
        // Compare Bing positions if present
        if (kw.bingPosition != null && kw.bingPreviousPosition != null) {
          final gain = kw.bingPreviousPosition! - kw.bingPosition!;
          if (gain >= settings.rankGainThreshold) {
            alerts.add(
              RankingAlert(
                websiteId: websiteId,
                keywordId: kw.id,
                alertType: 'rank_gain',
                severity: 'info',
                title: 'Bing Rank Gained (+$gain)',
                message:
                    '"${kw.keywordText}" climbed from #${kw.bingPreviousPosition} to #${kw.bingPosition} on Bing.',
                searchEngine: 'Bing',
                createdAt: now,
              ),
            );
          }
        }
        // Compare Yandex positions if present
        if (kw.yandexPosition != null && kw.yandexPreviousPosition != null) {
          final gain = kw.yandexPreviousPosition! - kw.yandexPosition!;
          if (gain >= settings.rankGainThreshold) {
            alerts.add(
              RankingAlert(
                websiteId: websiteId,
                keywordId: kw.id,
                alertType: 'rank_gain',
                severity: 'info',
                title: 'Yandex Rank Gained (+$gain)',
                message:
                    '"${kw.keywordText}" climbed from #${kw.yandexPreviousPosition} to #${kw.yandexPosition} on Yandex.',
                searchEngine: 'Yandex',
                createdAt: now,
              ),
            );
          }
        }
      }

      // 2. Significant Ranking Decline
      if (settings.rankDropEnabled) {
        if (kw.googlePosition != null && kw.googlePreviousPosition != null) {
          final loss = kw.googlePosition! - kw.googlePreviousPosition!;
          if (loss >= settings.rankDropThreshold) {
            alerts.add(
              RankingAlert(
                websiteId: websiteId,
                keywordId: kw.id,
                alertType: 'rank_drop',
                severity: 'warning',
                title: 'Google Rank Declined (-$loss)',
                message:
                    '"${kw.keywordText}" slipped from #${kw.googlePreviousPosition} down to #${kw.googlePosition} on Google.',
                searchEngine: 'Google',
                createdAt: now,
              ),
            );
          }
        }
        if (kw.bingPosition != null && kw.bingPreviousPosition != null) {
          final loss = kw.bingPosition! - kw.bingPreviousPosition!;
          if (loss >= settings.rankDropThreshold) {
            alerts.add(
              RankingAlert(
                websiteId: websiteId,
                keywordId: kw.id,
                alertType: 'rank_drop',
                severity: 'warning',
                title: 'Bing Rank Declined (-$loss)',
                message:
                    '"${kw.keywordText}" slipped from #${kw.bingPreviousPosition} down to #${kw.bingPosition} on Bing.',
                searchEngine: 'Bing',
                createdAt: now,
              ),
            );
          }
        }
        if (kw.yandexPosition != null && kw.yandexPreviousPosition != null) {
          final loss = kw.yandexPosition! - kw.yandexPreviousPosition!;
          if (loss >= settings.rankDropThreshold) {
            alerts.add(
              RankingAlert(
                websiteId: websiteId,
                keywordId: kw.id,
                alertType: 'rank_drop',
                severity: 'warning',
                title: 'Yandex Rank Declined (-$loss)',
                message:
                    '"${kw.keywordText}" slipped from #${kw.yandexPreviousPosition} down to #${kw.yandexPosition} on Yandex.',
                searchEngine: 'Yandex',
                createdAt: now,
              ),
            );
          }
        }
      }

      // 3. Newly Appearing Search Query
      if (settings.newQueryEnabled && (kw.isNew || kw.statusEvent == 'new')) {
        alerts.add(
          RankingAlert(
            websiteId: websiteId,
            keywordId: kw.id,
            alertType: 'new_query',
            severity: 'info',
            title: 'New Search Query Ranking',
            message:
                '"${kw.keywordText}" recently entered search results at position #${kw.googlePosition ?? kw.latestPosition ?? "?"}.',
            searchEngine: kw.searchEngine,
            createdAt: now,
          ),
        );
      }

      // 4. Previously Available Data Becoming Unavailable (Lost Ranking)
      if (settings.lostQueryEnabled && (kw.isLost || kw.statusEvent == 'lost')) {
        alerts.add(
          RankingAlert(
            websiteId: websiteId,
            keywordId: kw.id,
            alertType: 'lost_query',
            severity: 'critical',
            title: 'Keyword Dropped Out of Rankings',
            message:
                '"${kw.keywordText}" previously ranked at #${kw.previousPosition ?? kw.googlePreviousPosition ?? "?"} but was not found in top 100 on latest check.',
            searchEngine: kw.searchEngine,
            createdAt: now,
          ),
        );
      }

      // 5. Changes in Ranking Landing Page URL
      if (settings.urlChangeEnabled && observations.length >= 2) {
        final urlObs = observations
            .where((o) => o.rankingUrl != null && o.rankingUrl!.isNotEmpty)
            .toList();
        if (urlObs.length >= 2) {
          final latestUrl = urlObs.first.rankingUrl!;
          final prevUrl = urlObs[1].rankingUrl!;
          if (latestUrl.toLowerCase() != prevUrl.toLowerCase()) {
            alerts.add(
              RankingAlert(
                websiteId: websiteId,
                keywordId: kw.id,
                alertType: 'url_change',
                severity: 'warning',
                title: 'Ranking Landing Page Changed',
                message:
                    'Search engine switched landing page for "${kw.keywordText}" from "$prevUrl" to "$latestUrl".',
                searchEngine: urlObs.first.searchEngine,
                createdAt: now,
              ),
            );
          }
        }
      }
    }

    // 6. Keyword Cannibalization Alert
    if (settings.cannibalizationEnabled) {
      final cannibalFindings = detectCannibalization(
        keywords: keywords,
        observationsByKeywordId: observationsByKeywordId,
      );
      for (final finding in cannibalFindings) {
        if (finding.confidence == CannibalizationConfidence.high ||
            finding.confidence == CannibalizationConfidence.medium) {
          alerts.add(
            RankingAlert(
              websiteId: websiteId,
              keywordId: finding.keywordId,
              alertType: 'cannibalization',
              severity: finding.confidence == CannibalizationConfidence.high
                  ? 'critical'
                  : 'warning',
              title: 'Keyword Cannibalization (${finding.confidenceLabel})',
              message:
                  '${finding.affectedUrls.length} landing pages competing for "${finding.keywordText}".',
              searchEngine: finding.searchEngine,
              createdAt: now,
            ),
          );
        }
      }
    }

    return alerts;
  }
}
