import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/mood_provider.dart';
import '../theme/app_theme.dart';
import '../models/mood_entry.dart';
import '../widgets/error_state.dart';

class MoodJournalScreen extends StatefulWidget {
  const MoodJournalScreen({super.key});

  @override
  State<MoodJournalScreen> createState() => _MoodJournalScreenState();
}

class _MoodJournalScreenState extends State<MoodJournalScreen> {
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final cardColor = isDark ? AppTheme.darkCardColor : Colors.white;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mood Journal'),
      ),
      body: Consumer<MoodProvider>(
        builder: (context, provider, _) {
          if (provider.errorMessage != null) {
            return ErrorStateWidget(
              message: provider.errorMessage!,
              onRetry: () => provider.loadMoodEntries(),
              isLoading: provider.isLoading,
            );
          }
          if (provider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          return RefreshIndicator(
            onRefresh: () => provider.loadMoodEntries(),
            child: provider.moodEntries.isEmpty
                ? _buildEmptyState(textPrimary, textSecondary)
                : ListView.builder(
                    padding: const EdgeInsets.all(16),
                    itemCount: provider.moodEntries.length + 1,
                    itemBuilder: (context, index) {
                      if (index == 0) {
                        return _buildMoodAverageCard(provider, textPrimary, textSecondary);
                      }
                      final entry = provider.moodEntries[index - 1];
                      return _buildMoodEntryCard(entry, textPrimary, textSecondary, cardColor);
                    },
                  ),
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(Color textPrimary, Color textSecondary) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Text('📝', style: TextStyle(fontSize: 64)),
          const SizedBox(height: 16),
          Text(
            'No mood entries yet',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w600,
              color: textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Log your mood on the home page\nto start tracking!',
            textAlign: TextAlign.center,
            style: TextStyle(color: textSecondary),
          ),
        ],
      ),
    );
  }

  Widget _buildMoodAverageCard(
    MoodProvider provider,
    Color textPrimary,
    Color textSecondary,
  ) {
    if (provider.moodEntries.isEmpty) return const SizedBox.shrink();

    final avg = provider.moodEntries
            .map((e) => e.moodScore)
            .reduce((a, b) => a + b) /
        provider.moodEntries.length;
    final recentMood = provider.moodEntries.first;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.moodColors[recentMood.moodScore - 1].withValues(alpha: 0.1),
            AppTheme.moodColors[recentMood.moodScore - 1].withValues(alpha: 0.05),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.moodColors[recentMood.moodScore - 1].withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Average Mood',
                  style: TextStyle(
                    fontSize: 14,
                    color: textSecondary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  avg.toStringAsFixed(1),
                  style: TextStyle(
                    fontSize: 36,
                    fontWeight: FontWeight.bold,
                    color: textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'out of 5',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                recentMood.moodEmoji,
                style: const TextStyle(fontSize: 48),
              ),
              Text(
                'Recent: ${recentMood.moodLabel}',
                style: TextStyle(
                  fontSize: 12,
                  color: AppTheme.moodColors[recentMood.moodScore - 1],
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildMoodEntryCard(
    MoodEntry entry,
    Color textPrimary,
    Color textSecondary,
    Color cardColor,
  ) {
    final date = DateTime.parse(entry.date);
    final formatter = DateFormat('MMM d, yyyy');
    final dayName = DateFormat('EEEE').format(date);
    final moodColor = AppTheme.moodColors[entry.moodScore - 1];

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: moodColor.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // Mood indicator
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: moodColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Center(
              child: Text(
                entry.moodEmoji,
                style: const TextStyle(fontSize: 24),
              ),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      entry.moodLabel,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: moodColor,
                      ),
                    ),
                    const Spacer(),
                    Text(
                      '${entry.moodScore}/5',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: moodColor,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  '$dayName • ${formatter.format(date)}',
                  style: TextStyle(
                    fontSize: 12,
                    color: textSecondary,
                  ),
                ),
                if (entry.note.isNotEmpty) ...[
                  const SizedBox(height: 6),
                  Text(
                    entry.note,
                    style: TextStyle(
                      fontSize: 13,
                      color: textPrimary,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
