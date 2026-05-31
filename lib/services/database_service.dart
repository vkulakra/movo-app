import 'package:flutter/foundation.dart';
import 'package:sembast/sembast.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'db_factory.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../models/mood_entry.dart';

class DatabaseService {
  static Database? _database;
  static final DatabaseService instance = DatabaseService._();

  DatabaseService._();

  /// Inject a test database. Only intended for testing.
  @visibleForTesting
  static void setTestDatabase(Database db) {
    _database = db;
  }

  // Store references
  final StoreRef<int, Map<String, Object?>> _habitStore =
      intMapStoreFactory.store('habits');
  final StoreRef<int, Map<String, Object?>> _completionStore =
      intMapStoreFactory.store('habit_completions');
  final StoreRef<int, Map<String, Object?>> _moodStore =
      intMapStoreFactory.store('mood_entries');

  Future<Database> get database async {
    if (_database != null) return _database!;
    _database = await _initDatabase();
    return _database!;
  }

  /// Reset the cached database for testing.
  @visibleForTesting
  static void resetTestDatabase() {
    _database = null;
  }

  Future<Database> _initDatabase() async {
    final dir = await getApplicationDocumentsDirectory();
    final dbPath = p.join(dir.path, 'habit_mood_journal.db');
    final db = await databaseFactory.openDatabase(dbPath);
    return db;
  }

  // ---- Habits ----

  Future<List<Habit>> getHabits() async {
    final db = await database;
    final records = await _habitStore.find(
      db,
      finder: Finder(sortOrders: [SortOrder('created_at', false)]),
    );
    return records.map((record) {
      final map = Map<String, dynamic>.from(record.value);
      map['id'] = record.key;
      return Habit.fromMap(map);
    }).toList();
  }

  Future<Habit> addHabit(Habit habit) async {
    final db = await database;
    var data = habit.toMap();
    data.remove('id'); // Let sembast auto-generate the key
    final id = await _habitStore.add(db, data);
    return habit.copyWith(id: id);
  }

  Future<void> updateHabit(Habit habit) async {
    final db = await database;
    final id = habit.id;
    if (id == null) return;
    final data = habit.toMap();
    data.remove('id');
    await _habitStore.update(
      db,
      data,
      finder: Finder(filter: Filter.byKey(id)),
    );
  }

  Future<void> deleteHabit(int id) async {
    final db = await database;
    await _habitStore.delete(
      db,
      finder: Finder(filter: Filter.byKey(id)),
    );
    // Also delete related completions
    await _completionStore.delete(
      db,
      finder: Finder(filter: Filter.equals('habit_id', id)),
    );
  }

  // ---- Habit Completions ----

  Future<List<HabitCompletion>> getCompletionsForDate(String date) async {
    final db = await database;
    final records = await _completionStore.find(
      db,
      finder: Finder(filter: Filter.equals('date', date)),
    );
    return records.map((record) {
      final map = Map<String, dynamic>.from(record.value);
      map['id'] = record.key;
      return HabitCompletion.fromMap(map);
    }).toList();
  }

  Future<List<HabitCompletion>> getCompletionsForHabit(int habitId) async {
    final db = await database;
    final records = await _completionStore.find(
      db,
      finder: Finder(
        filter: Filter.equals('habit_id', habitId),
        sortOrders: [SortOrder('date', false)],
      ),
    );
    return records.map((record) {
      final map = Map<String, dynamic>.from(record.value);
      map['id'] = record.key;
      return HabitCompletion.fromMap(map);
    }).toList();
  }

  Future<void> addCompletion(int habitId, String date) async {
    final db = await database;
    await _completionStore.add(db, {
      'habit_id': habitId,
      'date': date,
      'count': 1,
    });
  }

  Future<void> removeCompletion(int habitId, String date) async {
    final db = await database;
    await _completionStore.delete(
      db,
      finder: Finder(filter: Filter.and([
        Filter.equals('habit_id', habitId),
        Filter.equals('date', date),
      ])),
    );
  }

  Future<int> getCompletionsCountForHabitOnDate(
      int habitId, String date) async {
    final db = await database;
    final records = await _completionStore.find(
      db,
      finder: Finder(filter: Filter.and([
        Filter.equals('habit_id', habitId),
        Filter.equals('date', date),
      ])),
    );
    return records.length;
  }

  Future<int> getStreak(int habitId) async {
    final db = await database;
    final records = await _completionStore.find(
      db,
      finder: Finder(
        filter: Filter.equals('habit_id', habitId),
        sortOrders: [SortOrder('date', false)],
      ),
    );
    if (records.isEmpty) return 0;

    final dates = records
        .map((r) => r.value['date'] as String)
        .toSet()
        .toList();
    dates.sort((a, b) => b.compareTo(a));

    final dateSet = dates.toSet();
    int streak = 0;
    final now = DateTime.now();
    for (int i = 0; i < 365; i++) {
      final checkDate = now.subtract(Duration(days: i));
      final dateStr =
          '${checkDate.year}-${checkDate.month.toString().padLeft(2, '0')}-${checkDate.day.toString().padLeft(2, '0')}';
      if (dateSet.contains(dateStr)) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  Future<void> toggleHabitCompletion(int habitId, String date) async {
    final existing = await getCompletionsCountForHabitOnDate(habitId, date);
    if (existing > 0) {
      await removeCompletion(habitId, date);
    } else {
      await addCompletion(habitId, date);
    }
  }

  Future<bool> isHabitCompletedOnDate(int habitId, String date) async {
    final count = await getCompletionsCountForHabitOnDate(habitId, date);
    return count > 0;
  }

  Future<Map<String, int>> getCompletionStats(int habitId) async {
    final db = await database;
    final records = await _completionStore.find(
      db,
      finder: Finder(filter: Filter.equals('habit_id', habitId)),
    );
    final total = records.length;
    final streak = await getStreak(habitId);
    return {'total': total, 'streak': streak};
  }

  Future<int> getCompletionCountForDateRange(
      int habitId, String start, String end) async {
    final db = await database;
    final records = await _completionStore.find(
      db,
      finder: Finder(filter: Filter.and([
        Filter.equals('habit_id', habitId),
        Filter.greaterThanOrEquals('date', start),
        Filter.lessThanOrEquals('date', end),
      ])),
    );
    return records.length;
  }

  // ---- Mood Entries ----

  Future<List<MoodEntry>> getMoodEntries({int limit = 30}) async {
    final db = await database;
    final records = await _moodStore.find(
      db,
      finder: Finder(
        sortOrders: [SortOrder('date', false)],
        limit: limit,
      ),
    );
    return records.map((record) {
      final map = Map<String, dynamic>.from(record.value);
      map['id'] = record.key;
      return MoodEntry.fromMap(map);
    }).toList();
  }

  Future<MoodEntry?> getMoodEntryForDate(String date) async {
    final db = await database;
    final records = await _moodStore.find(
      db,
      finder: Finder(
        filter: Filter.equals('date', date),
        limit: 1,
      ),
    );
    if (records.isEmpty) return null;
    final map = Map<String, dynamic>.from(records.first.value);
    map['id'] = records.first.key;
    return MoodEntry.fromMap(map);
  }

  Future<MoodEntry> addMoodEntry(MoodEntry entry) async {
    final db = await database;
    // Remove existing entry for same date
    await _moodStore.delete(
      db,
      finder: Finder(filter: Filter.equals('date', entry.date)),
    );
    var data = entry.toMap();
    data.remove('id');
    final id = await _moodStore.add(db, data);
    return entry.copyWith(id: id);
  }

  Future<List<MoodEntry>> getMoodEntriesForRange(
      String startDate, String endDate) async {
    final db = await database;
    final records = await _moodStore.find(
      db,
      finder: Finder(
        filter: Filter.and([
          Filter.greaterThanOrEquals('date', startDate),
          Filter.lessThanOrEquals('date', endDate),
        ]),
        sortOrders: [SortOrder('date', true)],
      ),
    );
    return records.map((record) {
      final map = Map<String, dynamic>.from(record.value);
      map['id'] = record.key;
      return MoodEntry.fromMap(map);
    }).toList();
  }

  Future<double> getAverageMoodForDateRange(
      String startDate, String endDate) async {
    final db = await database;
    final records = await _moodStore.find(
      db,
      finder: Finder(
        filter: Filter.and([
          Filter.greaterThanOrEquals('date', startDate),
          Filter.lessThanOrEquals('date', endDate),
        ]),
      ),
    );
    if (records.isEmpty) return 0.0;
    final sum = records.fold<double>(
      0,
      (sum, r) => sum + (r.value['mood_score'] as num).toDouble(),
    );
    return sum / records.length;
  }
}
