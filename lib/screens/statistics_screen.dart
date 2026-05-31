import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:fl_chart/fl_chart.dart';
import '../models/habit.dart';
import '../providers/habit_provider.dart';
import '../providers/mood_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/mood_chart.dart';
import '../widgets/error_state.dart';

class StatisticsScreen extends StatefulWidget {
  const StatisticsScreen({super.key});
  @override
  State<StatisticsScreen> createState() => _StatisticsScreenState();
}

class _StatisticsScreenState extends State<StatisticsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<HabitProvider>().loadHabits();
      context.read<MoodProvider>().loadMoodEntries();
    });
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final cardColor = isDark ? AppTheme.darkCardColor : Colors.white;

    return Scaffold(
      appBar: AppBar(title: const Text('Statistics')),
      body: Consumer2<HabitProvider, MoodProvider>(
        builder: (context, habitProv, moodProv, _) {
          if (habitProv.errorMessage != null || moodProv.errorMessage != null) {
            final errorMsg = habitProv.errorMessage ?? moodProv.errorMessage ?? 'Could not load data.';
            return ErrorStateWidget(
              message: errorMsg,
              onRetry: () {
                habitProv.loadHabits();
                moodProv.loadMoodEntries();
              },
              isLoading: habitProv.isLoading || moodProv.isLoading,
            );
          }
          if (habitProv.isLoading || moodProv.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Mood Trend Chart
                _buildCard(
                  cardColor: cardColor,
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mood Trend',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 220,
                        child: moodProv.moodEntries.isEmpty
                            ? Center(
                                child: Text(
                                  'No mood data yet',
                                  style: TextStyle(color: textSecondary),
                                ),
                              )
                            : MoodChart(entries: moodProv.moodEntries),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Mood Distribution
                _buildCard(
                  cardColor: cardColor,
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Mood Distribution',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: textPrimary,
                        ),
                      ),
                      const SizedBox(height: 16),
                      SizedBox(
                        height: 200,
                        child: moodProv.moodEntries.isEmpty
                            ? Center(
                                child: Text(
                                  'No mood data yet',
                                  style: TextStyle(color: textSecondary),
                                ),
                              )
                            : _buildMoodDistribution(moodProv.moodEntries),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                // Habit Overview
                _buildCard(
                  cardColor: cardColor,
                  isDark: isDark,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(children: [
                        const Icon(
                          Icons.check_circle_outline,
                          color: AppTheme.primaryColor,
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Habit Overview',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 16),
                      if (habitProv.habits.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(24),
                          child: Center(
                            child: Text(
                              'No habits created yet',
                              style: TextStyle(color: textSecondary),
                            ),
                          ),
                        )
                      else
                        ...habitProv.habits.map(
                          (habit) => _HabitStreakTile(
                            habit: habit,
                            habitProv: habitProv,
                            textPrimary: textPrimary,
                            textSecondary: textSecondary,
                          ),
                        ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildCard({
    required Color cardColor,
    required bool isDark,
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: isDark ? 0.3 : 0.05),
            blurRadius: 20,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: child,
    );
  }

  Widget _buildMoodDistribution(List entries) {
    final moodCounts = <int, int>{};
    for (final entry in entries) {
      moodCounts[entry.moodScore] = (moodCounts[entry.moodScore] ?? 0) + 1;
    }
    return PieChart(
      PieChartData(
        sections: List.generate(5, (index) {
          final score = index + 1;
          final count = moodCounts[score] ?? 0;
          final total = entries.length;
          final percentage = total > 0 ? (count / total * 100) : 0.0;
          return PieChartSectionData(
            value: percentage,
            title: percentage > 0 ? '${percentage.toInt()}%' : '',
            color: AppTheme.moodColors[index],
            radius: 40,
            titleStyle: const TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          );
        }),
        sectionsSpace: 2,
        centerSpaceRadius: 40,
      ),
    );
  }
}

class _HabitStreakTile extends StatefulWidget {
  final Habit habit;
  final HabitProvider habitProv;
  final Color textPrimary;
  final Color textSecondary;

  const _HabitStreakTile({
    required this.habit,
    required this.habitProv,
    required this.textPrimary,
    required this.textSecondary,
  });

  @override
  State<_HabitStreakTile> createState() => _HabitStreakTileState();
}

class _HabitStreakTileState extends State<_HabitStreakTile> {
  late Future<int> _streakFuture;

  @override
  void initState() {
    super.initState();
    _streakFuture = widget.habitProv.getStreak(widget.habit.id!);
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<int>(
      future: _streakFuture,
      builder: (context, snapshot) {
        final streak = snapshot.data ?? 0;
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Text(widget.habit.icon, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      widget.habit.name,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: widget.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Streak: $streak days',
                      style: TextStyle(
                        fontSize: 12,
                        color: widget.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Color(widget.habit.color).withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${streak}d',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: Color(widget.habit.color),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
