import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/mood_entry.dart';
import '../theme/app_theme.dart';

class MoodChart extends StatelessWidget {
  final List<MoodEntry> entries;

  const MoodChart({super.key, required this.entries});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final gridColor = isDark ? Colors.grey.withValues(alpha: 0.2) : Colors.grey.withValues(alpha: 0.1);

    if (entries.isEmpty) {
      return SizedBox(
        height: 200,
        child: Center(
          child: Text(
            'No mood data yet.\nStart logging your mood!',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary, fontSize: 14),
          ),
        ),
      );
    }

    final sorted = [...entries]..sort((a, b) => a.date.compareTo(b.date));
    return SizedBox(
      height: 200,
      child: LineChart(
        LineChartData(
          gridData: FlGridData(
            show: true,
            horizontalInterval: 1,
            getDrawingHorizontalLine: (value) {
              return FlLine(
                color: gridColor,
                strokeWidth: 1,
              );
            },
            drawVerticalLine: false,
          ),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 30,
                interval: 1,
                getTitlesWidget: (value, meta) {
                  final emojis = ['', '😫', '😔', '😐', '😊', '🤩'];
                  final index = value.toInt();
                  if (index >= 1 && index <= 5) {
                    return Text(
                      emojis[index],
                      style: const TextStyle(fontSize: 12),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                reservedSize: 22,
                interval: (sorted.length > 7) ? (sorted.length / 5).ceilToDouble() : 1,
                getTitlesWidget: (value, meta) {
                  final index = value.toInt();
                  if (index < 0 || index >= sorted.length) {
                    return const Text('');
                  }
                  final date = DateTime.parse(sorted[index].date);
                  return Text(
                    '${date.month}/${date.day}',
                    style: TextStyle(fontSize: 10, color: textSecondary),
                  );
                },
              ),
            ),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          borderData: FlBorderData(show: false),
          minY: 0.5,
          maxY: 5.5,
          lineBarsData: [
            LineChartBarData(
              spots: List.generate(sorted.length, (i) {
                return FlSpot(i.toDouble(), sorted[i].moodScore.toDouble());
              }),
              isCurved: true,
              color: AppTheme.primaryColor,
              barWidth: 3,
              isStrokeCapRound: true,
              dotData: FlDotData(
                show: true,
                getDotPainter: (spot, percent, barData, index) {
                  final moodColors = AppTheme.moodColors;
                  final score = spot.y.toInt() - 1;
                  return FlDotCirclePainter(
                    radius: 4,
                    color: score >= 0 && score < moodColors.length
                        ? moodColors[score]
                        : AppTheme.primaryColor,
                    strokeWidth: 2,
                    strokeColor: isDark ? AppTheme.darkCardColor : Colors.white,
                  );
                },
              ),
              belowBarData: BarAreaData(
                show: true,
                color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1),
              ),
            ),
          ],
          lineTouchData: LineTouchData(
            touchTooltipData: LineTouchTooltipData(
              getTooltipItems: (touchedSpots) {
                return touchedSpots.map((spot) {
                  final score = spot.y.toInt();
                  final labels = ['', 'Terrible', 'Bad', 'Okay', 'Good', 'Amazing'];
                  final label = score >= 1 && score <= 5 ? labels[score] : '';
                  return LineTooltipItem(
                    '$label\nMood: $score/5',
                    const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  );
                }).toList();
              },
            ),
          ),
        ),
      ),
    );
  }
}
