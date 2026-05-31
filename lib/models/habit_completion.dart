class HabitCompletion {
  final int? id;
  final int habitId;
  final String date;
  final int count;

  HabitCompletion({
    this.id,
    required this.habitId,
    required this.date,
    this.count = 1,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'habit_id': habitId,
      'date': date,
      'count': count,
    };
  }

  factory HabitCompletion.fromMap(Map<String, dynamic> map) {
    return HabitCompletion(
      id: map['id'] as int?,
      habitId: map['habit_id'] as int,
      date: map['date'] as String,
      count: map['count'] as int? ?? 1,
    );
  }
}
