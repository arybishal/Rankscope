import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:intl/intl.dart' hide TextDirection;

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

/// Single data point for a trend series.
class ChartDataPoint {
  final DateTime date;
  final double value;
  final String? label;

  const ChartDataPoint({
    required this.date,
    required this.value,
    this.label,
  });
}

/// A named series plotted on the trend chart.
class ChartSeries {
  final String name;
  final List<ChartDataPoint> points;
  final Color color;
  final bool isDashed;

  const ChartSeries({
    required this.name,
    required this.points,
    required this.color,
    this.isDashed = false,
  });
}

/// Mobile-first accessible trend line chart with interactive touch tooltips,
/// axis labels, and light/dark theme adaptation.
class TrendLineChart extends StatefulWidget {
  final List<ChartSeries> series;
  final double height;
  final bool invertYAxis; // Set true for SERP rank (1 is top)
  final String? yAxisSuffix;
  final String? emptyMessage;

  const TrendLineChart({
    super.key,
    required this.series,
    this.height = 200,
    this.invertYAxis = false,
    this.yAxisSuffix,
    this.emptyMessage,
  });

  @override
  State<TrendLineChart> createState() => _TrendLineChartState();
}

class _TrendLineChartState extends State<TrendLineChart> {
  int? _selectedPointIndex;
  ChartSeries? _selectedSeries;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // Filter series that have data
    final activeSeries = widget.series.where((s) => s.points.isNotEmpty).toList();

    if (activeSeries.isEmpty || activeSeries.every((s) => s.points.length < 2)) {
      return Container(
        height: widget.height,
        alignment: Alignment.center,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isDark ? AppColors.darkSurfaceSecondary : AppColors.surfaceSecondary,
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isDark ? AppColors.darkBorderSubtle : AppColors.borderSubtle,
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.show_chart, size: 28, color: AppColors.textTertiary),
            const SizedBox(height: 6),
            Text(
              widget.emptyMessage ?? 'Insufficient data points to display trend curve.',
              style: AppTextStyles.bodySmall.copyWith(
                color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    // Determine min/max values across all series
    double globalMin = double.infinity;
    double globalMax = -double.infinity;
    DateTime minDate = DateTime(2100);
    DateTime maxDate = DateTime(1970);

    for (final s in activeSeries) {
      for (final p in s.points) {
        if (p.value < globalMin) globalMin = p.value;
        if (p.value > globalMax) globalMax = p.value;
        if (p.date.isBefore(minDate)) minDate = p.date;
        if (p.date.isAfter(maxDate)) maxDate = p.date;
      }
    }

    // Padding for visual balance
    if (globalMin == globalMax) {
      globalMin -= 1;
      globalMax += 1;
    }
    final range = globalMax - globalMin;
    final yMin = math.max(0.0, globalMin - (range * 0.1));
    final yMax = globalMax + (range * 0.1);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Legend
        if (activeSeries.length > 1)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Wrap(
              spacing: 12,
              runSpacing: 4,
              children: activeSeries.map((s) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 10,
                      height: 10,
                      decoration: BoxDecoration(
                        color: s.color,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      s.name,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextSecondary : AppColors.textSecondary,
                      ),
                    ),
                  ],
                );
              }).toList(),
            ),
          ),

        // Chart Canvas Area
        SizedBox(
          height: widget.height,
          child: LayoutBuilder(
            builder: (context, constraints) {
              return GestureDetector(
                onPanDown: (details) => _handleTouch(details.localPosition, constraints.maxWidth, activeSeries),
                onPanUpdate: (details) => _handleTouch(details.localPosition, constraints.maxWidth, activeSeries),
                onPanEnd: (_) => setState(() {
                  _selectedPointIndex = null;
                  _selectedSeries = null;
                }),
                child: RepaintBoundary(
                  child: CustomPaint(
                    size: Size(constraints.maxWidth, widget.height),
                    painter: _ChartPainter(
                      seriesList: activeSeries,
                      yMin: yMin,
                      yMax: yMax,
                      minDate: minDate,
                      maxDate: maxDate,
                      invertYAxis: widget.invertYAxis,
                      isDark: isDark,
                      selectedIndex: _selectedPointIndex,
                      selectedSeries: _selectedSeries,
                      yAxisSuffix: widget.yAxisSuffix ?? '',
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  void _handleTouch(Offset localPos, double width, List<ChartSeries> series) {
    if (series.isEmpty || series.first.points.isEmpty) return;
    const paddingLeft = 40.0;
    const paddingRight = 16.0;
    final chartWidth = width - paddingLeft - paddingRight;
    if (chartWidth <= 0) return;

    final x = (localPos.dx - paddingLeft).clamp(0.0, chartWidth);
    final count = series.first.points.length;
    final index = ((x / chartWidth) * (count - 1)).round().clamp(0, count - 1);

    setState(() {
      _selectedPointIndex = index;
      _selectedSeries = series.first;
    });
  }
}

class _ChartPainter extends CustomPainter {
  final List<ChartSeries> seriesList;
  final double yMin;
  final double yMax;
  final DateTime minDate;
  final DateTime maxDate;
  final bool invertYAxis;
  final bool isDark;
  final int? selectedIndex;
  final ChartSeries? selectedSeries;
  final String yAxisSuffix;

  _ChartPainter({
    required this.seriesList,
    required this.yMin,
    required this.yMax,
    required this.minDate,
    required this.maxDate,
    required this.invertYAxis,
    required this.isDark,
    this.selectedIndex,
    this.selectedSeries,
    required this.yAxisSuffix,
  });

  @override
  void paint(Canvas canvas, Size size) {
    const double paddingLeft = 36.0;
    const double paddingRight = 12.0;
    const double paddingTop = 14.0;
    const double paddingBottom = 22.0;

    final double width = size.width - paddingLeft - paddingRight;
    final double height = size.height - paddingTop - paddingBottom;
    if (width <= 0 || height <= 0) return;

    final gridPaint = Paint()
      ..color = isDark ? const Color(0xFF1F2937) : const Color(0xFFE2E8F0)
      ..strokeWidth = 1.0;

    final textStyle = TextStyle(
      fontSize: 10,
      color: isDark ? const Color(0xFF6B7280) : const Color(0xFF94A3B8),
      fontWeight: FontWeight.w500,
    );

    // Draw horizontal grid lines (3 steps)
    const int ySteps = 3;
    for (int i = 0; i <= ySteps; i++) {
      final double y = paddingTop + (height / ySteps) * i;
      canvas.drawLine(
        Offset(paddingLeft, y),
        Offset(size.width - paddingRight, y),
        gridPaint,
      );

      final double valRatio = invertYAxis ? (i / ySteps) : (1.0 - (i / ySteps));
      final double val = yMin + valRatio * (yMax - yMin);
      final textSpan = TextSpan(
        text: '${val.toStringAsFixed(val < 10 ? 1 : 0)}$yAxisSuffix',
        style: textStyle,
      );
      final textPainter = TextPainter(
        text: textSpan,
        textDirection: TextDirection.ltr,
      )..layout();
      textPainter.paint(
        canvas,
        Offset(paddingLeft - textPainter.width - 4, y - textPainter.height / 2),
      );
    }

    // Plot each series
    for (final series in seriesList) {
      if (series.points.length < 2) continue;

      final path = Path();
      final fillPath = Path();

      final points = series.points;
      for (int i = 0; i < points.length; i++) {
        final p = points[i];
        final double xRatio = points.length == 1 ? 0.5 : (i / (points.length - 1));
        final double x = paddingLeft + (xRatio * width);

        double valRatio = (p.value - yMin) / (yMax - yMin == 0 ? 1 : (yMax - yMin));
        if (invertYAxis) valRatio = 1.0 - valRatio;
        final double y = paddingTop + (height * (1.0 - valRatio));

        if (i == 0) {
          path.moveTo(x, y);
          fillPath.moveTo(x, paddingTop + height);
          fillPath.lineTo(x, y);
        } else {
          // Smooth curve using cubic bezier control points
          final prevP = points[i - 1];
          final double prevXRatio = (i - 1) / (points.length - 1);
          final double prevX = paddingLeft + (prevXRatio * width);
          double prevValRatio = (prevP.value - yMin) / (yMax - yMin == 0 ? 1 : (yMax - yMin));
          if (invertYAxis) prevValRatio = 1.0 - prevValRatio;
          final double prevY = paddingTop + (height * (1.0 - prevValRatio));

          final double controlX1 = prevX + (x - prevX) / 2;
          final double controlY1 = prevY;
          final double controlX2 = prevX + (x - prevX) / 2;
          final double controlY2 = y;

          path.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
          fillPath.cubicTo(controlX1, controlY1, controlX2, controlY2, x, y);
        }

        if (i == points.length - 1) {
          fillPath.lineTo(x, paddingTop + height);
          fillPath.close();
        }
      }

      // Draw subtle gradient under line
      final gradientPaint = Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            series.color.withValues(alpha: 0.18),
            series.color.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromLTWH(paddingLeft, paddingTop, width, height));
      canvas.drawPath(fillPath, gradientPaint);

      // Draw stroke
      final strokePaint = Paint()
        ..color = series.color
        ..strokeWidth = 2.2
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round;
      canvas.drawPath(path, strokePaint);
    }

    // X-Axis date labels
    if (seriesList.isNotEmpty && seriesList.first.points.length >= 2) {
      final points = seriesList.first.points;
      final startLabel = DateFormat('MMM d').format(points.first.date);
      final endLabel = DateFormat('MMM d').format(points.last.date);

      final startPainter = TextPainter(
        text: TextSpan(text: startLabel, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      startPainter.paint(canvas, Offset(paddingLeft, size.height - paddingBottom + 4));

      final endPainter = TextPainter(
        text: TextSpan(text: endLabel, style: textStyle),
        textDirection: TextDirection.ltr,
      )..layout();
      endPainter.paint(
        canvas,
        Offset(size.width - paddingRight - endPainter.width, size.height - paddingBottom + 4),
      );
    }

    // Draw active touch indicator & tooltip if selected
    if (selectedIndex != null && selectedSeries != null && selectedIndex! < selectedSeries!.points.length) {
      final point = selectedSeries!.points[selectedIndex!];
      final double xRatio = selectedIndex! / (selectedSeries!.points.length - 1);
      final double x = paddingLeft + (xRatio * width);

      double valRatio = (point.value - yMin) / (yMax - yMin == 0 ? 1 : (yMax - yMin));
      if (invertYAxis) valRatio = 1.0 - valRatio;
      final double y = paddingTop + (height * (1.0 - valRatio));

      // Vertical cursor line
      final cursorPaint = Paint()
        ..color = isDark ? Colors.white38 : Colors.black26
        ..strokeWidth = 1.0;
      canvas.drawLine(
        Offset(x, paddingTop),
        Offset(x, paddingTop + height),
        cursorPaint,
      );

      // Point circle
      final dotBgPaint = Paint()
        ..color = isDark ? AppColors.darkCard : Colors.white;
      final dotPaint = Paint()
        ..color = selectedSeries!.color
        ..strokeWidth = 2.5
        ..style = PaintingStyle.stroke;
      canvas.drawCircle(Offset(x, y), 5.0, dotBgPaint);
      canvas.drawCircle(Offset(x, y), 5.0, dotPaint);

      // Tooltip pill
      final formattedDate = DateFormat('MMM d').format(point.date);
      final valueText = '${selectedSeries!.name}: ${point.value.toStringAsFixed(point.value < 10 ? 1 : 0)}$yAxisSuffix';
      final tooltipText = '$formattedDate\n$valueText';

      final tooltipPainter = TextPainter(
        text: TextSpan(
          text: tooltipText,
          style: const TextStyle(
            fontSize: 10,
            fontWeight: FontWeight.bold,
            color: Colors.white,
            height: 1.2,
          ),
        ),
        textAlign: TextAlign.center,
        textDirection: TextDirection.ltr,
      )..layout();

      final tooltipWidth = tooltipPainter.width + 12;
      final tooltipHeight = tooltipPainter.height + 8;
      double tooltipX = x - (tooltipWidth / 2);
      if (tooltipX < paddingLeft) tooltipX = paddingLeft;
      if (tooltipX + tooltipWidth > size.width - paddingRight) {
        tooltipX = size.width - paddingRight - tooltipWidth;
      }
      double tooltipY = y - tooltipHeight - 8;
      if (tooltipY < 0) tooltipY = y + 8;

      final tooltipRect = RRect.fromRectAndRadius(
        Rect.fromLTWH(tooltipX, tooltipY, tooltipWidth, tooltipHeight),
        const Radius.circular(6),
      );
      final tooltipBgPaint = Paint()..color = const Color(0xFF0F172A);
      canvas.drawRRect(tooltipRect, tooltipBgPaint);
      tooltipPainter.paint(canvas, Offset(tooltipX + 6, tooltipY + 4));
    }
  }

  @override
  bool shouldRepaint(covariant _ChartPainter oldDelegate) {
    return oldDelegate.seriesList != seriesList ||
        oldDelegate.selectedIndex != selectedIndex ||
        oldDelegate.isDark != isDark;
  }
}
