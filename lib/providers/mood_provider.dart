import 'package:flutter/material.dart';
import '../models/mood_entry.dart';
import '../services/database_service.dart';

class MoodProvider extends ChangeNotifier {
  final DatabaseService _db = DatabaseService.instance;
  List<MoodEntry> _moodEntries = [];
  MoodEntry? _todayMood;
  bool _isLoading = false;
  String? _errorMessage;

  List<MoodEntry> get moodEntries => _moodEntries;
  MoodEntry? get todayMood => _todayMood;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;

  Future<void> loadMoodEntries() async {
    _isLoading = true;
    // Keep _errorMessage visible during retry so the error widget stays on screen
    notifyListeners();
    try {
      _moodEntries = await _db.getMoodEntries(limit: 30);
      await loadTodayMood();
      _errorMessage = null; // clear error on success
    } catch (e) {
      _moodEntries = [];
      _todayMood = null;
      _errorMessage = 'Could not load mood entries. Please check that storage is available and try again.';
      debugPrint('Error loading mood entries: $e');
    }
    _isLoading = false;
    notifyListeners();
  }

  Future<void> loadTodayMood() async {
    final today = _formatDate(DateTime.now());
    _todayMood = await _db.getMoodEntryForDate(today);
    notifyListeners();
  }

  Future<MoodEntry> saveMoodEntry(MoodEntry entry) async {
    final saved = await _db.addMoodEntry(entry);
    _todayMood = saved;
    final existingIndex = _moodEntries.indexWhere((m) => m.date == entry.date);
    if (existingIndex != -1) {
      _moodEntries[existingIndex] = saved;
    } else {
      _moodEntries.insert(0, saved);
    }
    notifyListeners();
    return saved;
  }

  Future<MoodEntry?> getMoodForDate(DateTime date) async {
    return await _db.getMoodEntryForDate(_formatDate(date));
  }

  Future<List<MoodEntry>> getMoodEntriesForRange(DateTime start, DateTime end) async {
    return await _db.getMoodEntriesForRange(
      _formatDate(start),
      _formatDate(end),
    );
  }

  Future<double> getAverageMoodForDateRange(DateTime start, DateTime end) async {
    return await _db.getAverageMoodForDateRange(
      _formatDate(start),
      _formatDate(end),
    );
  }

  String _formatDate(DateTime date) {
    return '${date.year}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';
  }
}
