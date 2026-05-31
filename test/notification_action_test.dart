import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:habit_mood_journal/providers/habit_provider.dart';
import 'package:habit_mood_journal/services/database_service.dart';
import 'package:habit_mood_journal/models/habit.dart';

/// Simulates the 'Task Done' action handler from main.dart's
/// _setupNotificationHandler. This is the same logic applied when the
/// user taps the 'Task Done' button on a notification.
///
/// Returns the number of habits that were marked as done.
Future<int> executeTaskDoneAction(HabitProvider habitProv) async {
  final uncompleted = habitProv.habits.where((h) =>
      h.id != null &&
      !habitProv.todayCompletions.any((c) => c.habitId == h.id)).toList();

  for (final habit in uncompleted) {
    await habitProv.addCompletion(habit.id!);
  }
  return uncompleted.length;
}

/// Simulates the 'Not Done' action handler — the notification is simply
/// dismissed and no habits are modified.
Future<void> executeNotDoneAction() async {
  // No-op: notification auto-dismisses via cancelNotification: true
}

/// Helper to create a date string for today
String _todayStr() {
  final now = DateTime.now();
  return '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';
}

/// Helper to create a date string for [date]
String _dateStr(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}

void main() {
  late Database db;
  int dbCounter = 0;

  setUp(() async {
    dbCounter++;
    db = await databaseFactoryMemory.openDatabase('test_notif_$dbCounter.db');
    DatabaseService.setTestDatabase(db);
  });

  tearDown(() async {
    DatabaseService.resetTestDatabase();
    await db.close();
  });

  group('Task Done notification action', () {
    test('marks all uncompleted habits as completed for today', () async {
      final dbService = DatabaseService.instance;
      await dbService.addHabit(
        Habit(name: 'Exercise', icon: '💪', color: 0xFF0000),
      );
      final habit2 = await dbService.addHabit(
        Habit(name: 'Read', icon: '📚', color: 0x00FF00),
      );
      await dbService.addHabit(
        Habit(name: 'Meditate', icon: '🧘', color: 0x0000FF),
      );

      // Pre-complete habit2 for today
      await dbService.addCompletion(habit2.id!, _todayStr());

      final provider = HabitProvider();
      await provider.loadHabits();
      await provider.loadTodayCompletions();

      expect(provider.habits.length, 3);
      expect(provider.todayCompletions.length, 1);

      final markedCount = await executeTaskDoneAction(provider);

      expect(markedCount, 2); // 2 habits were uncompleted
      await provider.loadTodayCompletions();
      expect(provider.todayCompletions.length, 3);

      expect(
        provider.todayCompletions.any((c) => c.habitId == habit2.id),
        isTrue,
      );
    });

    test('completes all when all are uncompleted', () async {
      final dbService = DatabaseService.instance;
      await dbService.addHabit(
        Habit(name: 'Run', icon: '🏃', color: 0xFF0000),
      );
      await dbService.addHabit(
        Habit(name: 'Journal', icon: '📝', color: 0x00FF00),
      );

      final provider = HabitProvider();
      await provider.loadHabits();
      await provider.loadTodayCompletions();

      expect(provider.todayCompletions.length, 0);

      final markedCount = await executeTaskDoneAction(provider);
      expect(markedCount, 2);

      await provider.loadTodayCompletions();
      expect(provider.todayCompletions.length, 2);
    });

    test('is a no-op when all habits are already completed', () async {
      final dbService = DatabaseService.instance;
      final habit = await dbService.addHabit(
        Habit(name: 'Exercise', icon: '💪', color: 0xFF0000),
      );
      await dbService.addCompletion(habit.id!, _todayStr());

      final provider = HabitProvider();
      await provider.loadHabits();
      await provider.loadTodayCompletions();

      expect(provider.todayCompletions.length, 1);

      final markedCount = await executeTaskDoneAction(provider);
      expect(markedCount, 0);

      await provider.loadTodayCompletions();
      expect(provider.todayCompletions.length, 1);
    });

    test('is a no-op when there are no habits', () async {
      final provider = HabitProvider();
      await provider.loadHabits();

      final markedCount = await executeTaskDoneAction(provider);
      expect(markedCount, 0);
      expect(provider.todayCompletions.length, 0);
    });

    test('completes only today, not affecting past completions', () async {
      final dbService = DatabaseService.instance;
      final habit = await dbService.addHabit(
        Habit(name: 'Exercise', icon: '💪', color: 0xFF0000),
      );
      final yesterday = DateTime.now().subtract(const Duration(days: 1));
      await dbService.addCompletion(habit.id!, _dateStr(yesterday));

      final provider = HabitProvider();
      await provider.loadHabits();
      await provider.loadTodayCompletions();

      expect(provider.todayCompletions.length, 0);

      final yesterdayCompletions = await dbService.getCompletionsForDate(
        _dateStr(yesterday),
      );
      expect(yesterdayCompletions.length, 1);

      final markedCount = await executeTaskDoneAction(provider);
      expect(markedCount, 1);

      await provider.loadTodayCompletions();
      expect(provider.todayCompletions.length, 1);

      final yesterdayCompletionsAfter = await dbService.getCompletionsForDate(
        _dateStr(yesterday),
      );
      expect(yesterdayCompletionsAfter.length, 1);
    });

    test('works correctly with a mix of states across multiple days', () async {
      final dbService = DatabaseService.instance;
      final habit1 = await dbService.addHabit(
        Habit(name: 'Exercise', icon: '💪', color: 0xFF0000),
      );
      final habit2 = await dbService.addHabit(
        Habit(name: 'Read', icon: '📚', color: 0x00FF00),
      );
      await dbService.addHabit(
        Habit(name: 'Code', icon: '💻', color: 0x0000FF),
      );

      // habit1: completed today and yesterday
      await dbService.addCompletion(habit1.id!, _todayStr());
      await dbService.addCompletion(
        habit1.id!,
        _dateStr(DateTime.now().subtract(const Duration(days: 1))),
      );
      // habit2: completed yesterday only (not today)
      await dbService.addCompletion(
        habit2.id!,
        _dateStr(DateTime.now().subtract(const Duration(days: 1))),
      );
      // habit3: never completed

      final provider = HabitProvider();
      await provider.loadHabits();
      await provider.loadTodayCompletions();

      expect(provider.todayCompletions.length, 1);
      expect(
        provider.todayCompletions.any((c) => c.habitId == habit1.id),
        isTrue,
      );

      final markedCount = await executeTaskDoneAction(provider);
      expect(markedCount, 2); // habit2 and habit3 get completed

      await provider.loadTodayCompletions();
      expect(provider.todayCompletions.length, 3);
    });
  });

  group('Not Done notification action', () {
    test('does not modify any completions', () async {
      final dbService = DatabaseService.instance;
      await dbService.addHabit(
        Habit(name: 'Exercise', icon: '💪', color: 0xFF0000),
      );

      final provider = HabitProvider();
      await provider.loadHabits();
      await provider.loadTodayCompletions();

      expect(provider.todayCompletions.length, 0);
      expect(provider.habits.length, 1);

      await executeNotDoneAction();

      await provider.loadTodayCompletions();
      expect(provider.todayCompletions.length, 0);
    });
  });

  group('rescheduleFromHabitProvider (used after actions)', () {
    test('correctly identifies uncompleted habits', () async {
      final dbService = DatabaseService.instance;
      final habit1 = await dbService.addHabit(
        Habit(name: 'Exercise', icon: '💪', color: 0xFF0000),
      );
      await dbService.addHabit(
        Habit(name: 'Read', icon: '📚', color: 0x00FF00),
      );

      await dbService.addCompletion(habit1.id!, _todayStr());

      final provider = HabitProvider();
      await provider.loadHabits();
      await provider.loadTodayCompletions();

      final uncompletedNames = provider.habits
          .where((h) =>
              !provider.todayCompletions.any((c) => c.habitId == h.id))
          .map((h) => h.name)
          .toList();

      expect(uncompletedNames, ['Read']);
      expect(uncompletedNames.length, 1);
      expect(uncompletedNames.contains('Exercise'), isFalse);
    });

    test('returns empty list when all habits are completed', () async {
      final dbService = DatabaseService.instance;
      final habit = await dbService.addHabit(
        Habit(name: 'Exercise', icon: '💪', color: 0xFF0000),
      );
      await dbService.addCompletion(habit.id!, _todayStr());

      final provider = HabitProvider();
      await provider.loadHabits();
      await provider.loadTodayCompletions();

      final uncompletedNames = provider.habits
          .where((h) =>
              !provider.todayCompletions.any((c) => c.habitId == h.id))
          .map((h) => h.name)
          .toList();

      expect(uncompletedNames, isEmpty);
    });
  });
}
