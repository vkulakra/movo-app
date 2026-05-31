import 'package:flutter/material.dart';
import '../models/habit.dart';
import '../models/habit_completion.dart';
import '../services/database_service.dart';

class HabitProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  List<Habit> _habits = [];
  List<HabitCompletion> _todayCompletions = [];
  bool _isLoading = false;
  String? _errorMessage;
  int _bestStreak = 0;

  List<Habit> get habits => _habits;
  List<HabitCompletion> get todayCompletions => _todayCompletions;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  int get bestStreak => _bestStreak;

  Future<void> loadHabits() async {
    _isLoading = true;
    // Keep _errorMessage visible during retry so the error widget stays on screen
    notifyListeners();
    try {
      _habits = await _db.getHabits();
      _errorMessage = null; // clear error on success
    } catch (e) {
      _habits = [];
      _errorMessage = 'Could not load habits. Please check that storage is available and try again.';
      debugPrint('Error loading habits: $e');
    }
    // Compute best streak across all habits
    _bestStreak = await _computeBestStreak();
    _isLoading = false;
    notifyListeners();
  }

  /// Compute the maximum streak across all habits.
  Future<int> _computeBestStreak() async {
    int maxStreak = 0;
    for (final habit in _habits) {
      if (habit.id != null) {
        try {
          final streak = await _db.getStreak(habit.id!);
          if (streak > maxStreak) {
            maxStreak = streak;
          }
        } catch (_) {
          // Skip habits that fail to load
        }
      }
    }
    return maxStreak;
  }

  Future<void> loadTodayCompletions() async {
    final today = _formatDate(DateTime.now());
    _todayCompletions = await _db.getCompletionsForDate(today);
    notifyListeners();
  }

  Future<Habit> addHabit(Habit habit) async {
    final newHabit = await _db.addHabit(habit);
    _habits.insert(0, newHabit);
    notifyListeners();
    return newHabit;
  }

  Future<void> updateHabit(Habit habit) async {
    await _db.updateHabit(habit);
    final index = _habits.indexWhere((h) => h.id == habit.id);
    if (index != -1) {
      _habits[index] = habit;
    }
    notifyListeners();
  }

  Future<void> deleteHabit(int id) async {
    await _db.deleteHabit(id);
    _habits.removeWhere((h) => h.id == id);
    _todayCompletions.removeWhere((c) => c.habitId == id);
    notifyListeners();
  }

  Future<void> addCompletion(int habitId) async {
    final today = _formatDate(DateTime.now());
    await _db.addCompletion(habitId, today);
    await loadTodayCompletions();
    _bestStreak = await _computeBestStreak();
    notifyListeners();
  }

  Future<void> removeCompletion(int habitId) async {
    final today = _formatDate(DateTime.now());
    await _db.removeCompletion(habitId, today);
    await loadTodayCompletions();
    _bestStreak = await _computeBestStreak();
    notifyListeners();
  }

  Future<int> getStreak(int habitId) async {
    return await _db.getStreak(habitId);
  }

  bool isCompletedToday(int habitId) {
    final today = _formatDate(DateTime.now());
    return _todayCompletions.any((c) => c.habitId == habitId && c.date == today);
  }

  Future<bool> isCompletedOnDate(int habitId, DateTime date) async {
    final dateStr = _formatDate(date);
    return await _db.isHabitCompletedOnDate(habitId, dateStr);
  }

  Future<Map<String, int>> getHabitStats(int habitId) async {
    return await _db.getCompletionStats(habitId);
  }

  Future<int> getCompletionCountForDateRange(int habitId, String start, String end) async {
    return await _db.getCompletionCountForDateRange(habitId, start, end);
  }

  List<Habit> get completedHabits {
    return _habits.where((h) => isCompletedToday(h.id!)).toList();
  }

  List<Habit> get uncompletedHabits {
    return _habits.where((h) => !isCompletedToday(h.id!)).toList();
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
