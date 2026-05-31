import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/habit_provider.dart';
import '../providers/mood_provider.dart';
import '../providers/theme_provider.dart';
import '../providers/reminder_provider.dart';
import '../widgets/reminder_settings.dart';
import 'habits_screen.dart';
import '../theme/app_theme.dart';
import '../widgets/habit_tile.dart';
import '../widgets/mood_selector.dart';
import '../widgets/error_state.dart';
import '../models/mood_entry.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});
  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final habitProv = context.read<HabitProvider>();
      final remindProv = context.read<ReminderProvider>();
      final moodProv = context.read<MoodProvider>();

      // Wait for settings to load before attempting to reschedule
      await remindProv.settingsLoaded;

      await habitProv.loadHabits();
      await habitProv.loadTodayCompletions();
      moodProv.loadMoodEntries();

      // Reschedule the daily reminder with actual habit data
      await remindProv.rescheduleFromHabitProvider(habitProv);
    });
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good Morning';
    if (hour < 17) return 'Good Afternoon';
    return 'Good Evening';
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final textPrimary = isDark ? AppTheme.darkTextPrimary : AppTheme.textPrimary;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;
    final cardColor = isDark ? AppTheme.darkCardColor : Colors.white;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header row with dark mode toggle
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Consumer2<HabitProvider, MoodProvider>(
                    builder: (context, habitProv, moodProv, _) {
                      return Text(
                        _getGreeting(),
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      );
                    },
                  ),
                  Row(
                    children: [
                      Consumer<ReminderProvider>(
                        builder: (context, remindProv, _) {
                          return IconButton(
                            icon: Icon(
                              remindProv.isEnabled
                                  ? Icons.notifications_active_rounded
                                  : Icons.notifications_outlined,
                              color: remindProv.isEnabled
                                  ? AppTheme.primaryColor
                                  : textPrimary,
                            ),
                            onPressed: () => ReminderSettings.show(context),
                            tooltip: remindProv.isEnabled
                                ? 'Reminder at ${remindProv.timeDisplay} — tap to change'
                                : 'Set a daily reminder',
                          );
                        },
                      ),
                      Consumer<ThemeProvider>(
                        builder: (context, themeProv, _) {
                          return IconButton(
                            icon: AnimatedSwitcher(
                              duration: const Duration(milliseconds: 300),
                              child: Icon(
                                themeProv.followSystem
                                    ? Icons.brightness_auto_rounded
                                    : (isDark
                                        ? Icons.light_mode_rounded
                                        : Icons.dark_mode_rounded),
                                key: ValueKey(themeProv.followSystem
                                    ? 'auto'
                                    : isDark
                                        ? 'manual_dark'
                                        : 'manual_light'),
                                color: textPrimary,
                              ),
                            ),
                            onPressed: () => themeProv.toggleTheme(),
                            onLongPress: () => themeProv.enableFollowSystem(),
                            tooltip: themeProv.followSystem
                                ? 'Dark mode (auto)'
                                : 'Toggle dark mode — long-press for auto',
                          );
                        },
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Consumer<MoodProvider>(
                builder: (context, provider, _) {
                  if (provider.todayMood != null) {
                    return Text(
                      'Feeling ${provider.todayMood!.moodLabel}',
                      style: TextStyle(fontSize: 16, color: textSecondary),
                    );
                  }
                  return Text(
                    'How are you feeling today?',
                    style: TextStyle(fontSize: 16, color: textSecondary),
                  );
                },
              ),
              const SizedBox(height: 24),
              Consumer<MoodProvider>(
                builder: (context, provider, _) {
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppTheme.primaryColor, AppTheme.secondaryColor],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Mood Check-In',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 16),
                        MoodSelector(
                          selectedScore: provider.todayMood?.moodScore,
                          onSelected: (score) async {
                            final entry = MoodEntry(
                              moodScore: score,
                              note: '',
                              date: DateFormat('yyyy-MM-dd').format(DateTime.now()),
                            );
                            await provider.saveMoodEntry(entry);
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    "Today's Habits",
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: textPrimary,
                    ),
                  ),
                  Consumer2<HabitProvider, MoodProvider>(
                    builder: (context, habitProv, moodProv, _) {
                      final completed = habitProv.todayCompletions.length;
                      final total = habitProv.habits.length;
                      if (total == 0) return const SizedBox();
                      return Text(
                        '$completed/$total',
                        style: TextStyle(
                          fontSize: 14,
                          color: textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Consumer<HabitProvider>(
                builder: (context, provider, _) {
                  if (provider.errorMessage != null) {
                    return ErrorStateWidget(
                      message: provider.errorMessage!,
                      onRetry: () => provider.loadHabits(),
                      isLoading: provider.isLoading,
                    );
                  }
                  if (provider.isLoading) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (provider.habits.isEmpty) {
                    return Container(
                      padding: const EdgeInsets.all(32),
                      alignment: Alignment.center,
                      child: Column(children: [
                        const Text('📋', style: TextStyle(fontSize: 48)),
                        const SizedBox(height: 12),
                        Text(
                          'No habits yet!',
                          style: TextStyle(
                            fontSize: 16,
                            color: textSecondary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        TextButton(
                          onPressed: () {
                            final scaffold = Scaffold.maybeOf(context);
                            if (scaffold != null && context.mounted) {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const HabitsScreen(),
                                ),
                              );
                            }
                          },
                          child: const Text('Create your first habit'),
                        ),
                      ]),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: provider.habits.length,
                    itemBuilder: (context, index) {
                      final habit = provider.habits[index];
                      final isCompleted = provider.todayCompletions
                          .any((c) => c.habitId == habit.id);
                      return HabitTile(
                        habit: habit,
                        isCompleted: isCompleted,
                        onTap: () {
                          if (isCompleted) {
                            provider.removeCompletion(habit.id!).then((_) async {
                              if (context.mounted) {
                                await context.read<ReminderProvider>()
                                    .rescheduleFromHabitProvider(provider);
                              }
                            });
                          } else {
                            provider.addCompletion(habit.id!).then((_) async {
                              if (context.mounted) {
                                await context.read<ReminderProvider>()
                                    .rescheduleFromHabitProvider(provider);
                              }
                            });
                          }
                        },
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              Consumer<HabitProvider>(
                builder: (context, provider, _) {
                  if (provider.habits.isEmpty) return const SizedBox();
                  return Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: cardColor,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black
                              .withValues(alpha: isDark ? 0.3 : 0.05),
                          blurRadius: 20,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Quick Stats',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                            color: textPrimary,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Consumer2<HabitProvider, MoodProvider>(
                          builder: (context, habitProv, moodProv, _) {
                            final total = habitProv.habits.length;
                            final completed = habitProv.todayCompletions.length;
                            final streak = habitProv.bestStreak;
                            final hasMood = moodProv.todayMood != null;
                            return Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _buildStatItem('$completed/$total', 'Done', textPrimary),
                                _buildStatItem('$streak', 'Best Streak', textPrimary),
                                _buildStatItem(hasMood ? '✓' : '—', 'Mood', textPrimary),
                              ],
                            );
                          },
                        ),
                      ],
                    ),
                  );
                },
              ),
              const SizedBox(height: 32),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatItem(String value, String label, Color textPrimary) {
    final textSecondary = Theme.of(context).brightness == Brightness.dark
        ? AppTheme.darkTextSecondary
        : AppTheme.textSecondary;
    return Column(children: [
      Text(
        value,
        style: const TextStyle(
          fontSize: 24,
          fontWeight: FontWeight.bold,
          color: AppTheme.primaryColor,
        ),
      ),
      const SizedBox(height: 4),
      Text(
        label,
        style: TextStyle(fontSize: 13, color: textSecondary),
      ),
    ]);
  }
}
