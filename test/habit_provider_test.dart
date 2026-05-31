import 'package:flutter_test/flutter_test.dart';
import 'package:sembast/sembast_memory.dart';

import 'package:habit_mood_journal/providers/habit_provider.dart';
import 'package:habit_mood_journal/services/database_service.dart';
import 'package:habit_mood_journal/models/habit.dart';

void main() {
  late Database db;
  int dbCounter = 0;

  setUp(() async {
    // Use unique name to avoid cross-test data leaks from in-memory database
    dbCounter++;
    db = await databaseFactoryMemory.openDatabase('test_$dbCounter.db');
    DatabaseService.setTestDatabase(db);
  });

  tearDown(() async {
    DatabaseService.resetTestDatabase();
    await db.close();
  });

  group('HabitProvider.bestStreak', () {
    test('is 0 when there are no habits', () async {
      final provider = HabitProvider();
      await provider.loadHabits();

      expect(provider.bestStreak, equals(0));
    });

    test('is 0 when habits have no completions', () async {
      final dbService = DatabaseService.instance;
      await dbService.addHabit(Habit(name: 'Exercise', icon: '💪', color: 0xFF0000));

      final provider = HabitProvider();
      await provider.loadHabits();

      expect(provider.bestStreak, equals(0));
    });

    test('matches the streak of a single habit', () async {
      final dbService = DatabaseService.instance;
      final habit = await dbService.addHabit(
        Habit(name: 'Read', icon: '📚', color: 0xFF0000),
      );

      final now = DateTime.now();
      // Create a streak of 3: today, yesterday, day before
      for (int i = 0; i < 3; i++) {
        final date = _dateStr(now.subtract(Duration(days: i)));
        await dbService.addCompletion(habit.id!, date);
      }

      final provider = HabitProvider();
      await provider.loadHabits();

      expect(provider.bestStreak, equals(3));
    });

    test('returns the max streak across multiple habits', () async {
      final dbService = DatabaseService.instance;
      final habit1 = await dbService.addHabit(
        Habit(name: 'Read', icon: '📚', color: 0xFF0000),
      );
      final habit2 = await dbService.addHabit(
        Habit(name: 'Run', icon: '🏃', color: 0x00FF00),
      );
      await dbService.addHabit(
        Habit(name: 'Journal', icon: '📝', color: 0x0000FF),
      );

      final now = DateTime.now();
      // habit1: streak of 2
      for (int i = 0; i < 2; i++) {
        await dbService.addCompletion(habit1.id!, _dateStr(now.subtract(Duration(days: i))));
      }
      // habit2: streak of 5 (should be the max)
      for (int i = 0; i < 5; i++) {
        await dbService.addCompletion(habit2.id!, _dateStr(now.subtract(Duration(days: i))));
      }
      // habit3: streak of 0 (no completions)

      final provider = HabitProvider();
      await provider.loadHabits();

      expect(provider.bestStreak, equals(5));
    });

    test('updates after addCompletion is called', () async {
      final dbService = DatabaseService.instance;
      final habit = await dbService.addHabit(
        Habit(name: 'Meditate', icon: '🧘', color: 0xFF0000),
      );

      final provider = HabitProvider();
      await provider.loadHabits();
      expect(provider.bestStreak, equals(0));

      // Add a completion for today
      await provider.addCompletion(habit.id!);
      expect(provider.bestStreak, equals(1));
    });

    test('updates after removeCompletion is called', () async {
      final dbService = DatabaseService.instance;
      final habit = await dbService.addHabit(
        Habit(name: 'Meditate', icon: '🧘', color: 0xFF0000),
      );

      // Pre-seed a completion for today
      await dbService.addCompletion(habit.id!, _dateStr(DateTime.now()));

      final provider = HabitProvider();
      await provider.loadHabits();
      expect(provider.bestStreak, equals(1));

      // Remove the completion
      await provider.removeCompletion(habit.id!);
      expect(provider.bestStreak, equals(0));
    });

    test('is 0 when the streak is broken (yesterday but not today)', () async {
      final dbService = DatabaseService.instance;
      final habit = await dbService.addHabit(
        Habit(name: 'Exercise', icon: '💪', color: 0xFF0000),
      );

      // Complete yesterday only — today is missing, so streak is broken
      final yesterday = _dateStr(DateTime.now().subtract(const Duration(days: 1)));
      await dbService.addCompletion(habit.id!, yesterday);

      final provider = HabitProvider();
      await provider.loadHabits();

      expect(provider.bestStreak, equals(0));
    });

    test('is recomputed correctly after loadHabits when data changes underneath', () async {
      final dbService = DatabaseService.instance;
      final habit = await dbService.addHabit(
        Habit(name: 'Code', icon: '💻', color: 0xFF0000),
      );

      final provider = HabitProvider();
      await provider.loadHabits();
      expect(provider.bestStreak, equals(0));

      // Add data directly via DB service
      await dbService.addCompletion(habit.id!, _dateStr(DateTime.now()));

      // Reload — streak should now be 1
      await provider.loadHabits();
      expect(provider.bestStreak, equals(1));
    });
  });
}

String _dateStr(DateTime date) {
  return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
}
