class MoodEntry {
  final int? id;
  final int moodScore;
  final String note;
  final String date;
  final String createdAt;

  MoodEntry({
    this.id,
    required this.moodScore,
    this.note = '',
    required this.date,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'mood_score': moodScore,
      'note': note,
      'date': date,
      'created_at': createdAt,
    };
  }

  factory MoodEntry.fromMap(Map<String, dynamic> map) {
    return MoodEntry(
      id: map['id'] as int?,
      moodScore: map['mood_score'] as int,
      note: map['note'] as String? ?? '',
      date: map['date'] as String,
      createdAt: map['created_at'] as String?,
    );
  }

  MoodEntry copyWith({
    int? id,
    int? moodScore,
    String? note,
    String? date,
    String? createdAt,
  }) {
    return MoodEntry(
      id: id ?? this.id,
      moodScore: moodScore ?? this.moodScore,
      note: note ?? this.note,
      date: date ?? this.date,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get moodLabel {
    switch (moodScore) {
      case 1: return 'Terrible';
      case 2: return 'Bad';
      case 3: return 'Okay';
      case 4: return 'Good';
      case 5: return 'Amazing';
      default: return 'Unknown';
    }
  }

  String get moodEmoji {
    switch (moodScore) {
      case 1: return '😫';
      case 2: return '😔';
      case 3: return '😐';
      case 4: return '😊';
      case 5: return '🤩';
      default: return '❓';
    }
  }
}
