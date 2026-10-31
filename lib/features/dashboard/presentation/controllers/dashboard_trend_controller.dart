import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/database_constants.dart';
import '../../../../core/database/app_database.dart';
import '../../../../shared/widgets/charts/trend_line_chart.dart';

class TrendQueryArgs {
  final int websiteId;
  final int days;
  final String engine; // 'All', 'Google', 'Bing', 'Yandex'

  const TrendQueryArgs({
    required this.websiteId,
    required this.days,
    required this.engine,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is TrendQueryArgs &&
          runtimeType == other.runtimeType &&
          websiteId == other.websiteId &&
          days == other.days &&
          engine == other.engine;

  @override
  int get hashCode => websiteId.hashCode ^ days.hashCode ^ engine.hashCode;
}

final dashboardTrendProvider =
    FutureProvider.family<List<ChartSeries>, TrendQueryArgs>((ref, args) async {
  final db = await AppDatabase.instance.database;
  final cutoffMs =
      DateTime.now().subtract(Duration(days: args.days)).millisecondsSinceEpoch;

  final List<String> whereClauses = [
    'website_id = ?',
    'recorded_at >= ?',
    'position > 0',
  ];
  final List<dynamic> whereArgs = [args.websiteId, cutoffMs];

  if (args.engine != 'All') {
    whereClauses.add('LOWER(search_engine) = ?');
    whereArgs.add(args.engine.toLowerCase());
  }

  final rows = await db.query(
    DatabaseConstants.tableRankObservations,
    where: whereClauses.join(' AND '),
    whereArgs: whereArgs,
    orderBy: 'recorded_at ASC',
  );

  if (rows.isEmpty) {
    return [];
  }

  // Group by Search Engine and Date (day)
  final Map<String, Map<String, List<double>>> engineDatePositions = {};

  for (final r in rows) {
    final eng = r['search_engine'] as String? ?? 'Google';
    final recordedAt = DateTime.fromMillisecondsSinceEpoch(r['recorded_at'] as int);
    final dateKey =
        "${recordedAt.year}-${recordedAt.month.toString().padLeft(2, '0')}-${recordedAt.day.toString().padLeft(2, '0')}";
    final pos = (r['average_position'] as num?)?.toDouble() ??
        (r['position'] as num?)?.toDouble() ??
        0.0;

    if (pos > 0) {
      engineDatePositions.putIfAbsent(eng, () => {});
      engineDatePositions[eng]!.putIfAbsent(dateKey, () => []).add(pos);
    }
  }

  final List<ChartSeries> seriesList = [];

  final colors = {
    'Google': const Color(0xFF2563EB),
    'Bing': const Color(0xFF0D9488),
    'Yandex': const Color(0xFFEA580C),
  };

  engineDatePositions.forEach((eng, dateMap) {
    final List<ChartDataPoint> points = [];
    final sortedDates = dateMap.keys.toList()..sort();

    for (final dKey in sortedDates) {
      final values = dateMap[dKey]!;
      final avg = values.reduce((a, b) => a + b) / values.length;
      final parsedDate = DateTime.parse(dKey);
      points.add(ChartDataPoint(date: parsedDate, value: avg));
    }

    if (points.length >= 2) {
      seriesList.add(
        ChartSeries(
          name: eng,
          points: points,
          color: colors[eng] ?? const Color(0xFF64748B),
        ),
      );
    }
  });

  return seriesList;
});
