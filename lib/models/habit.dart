class Habit {
  final int? id;
  final String name;
  final String description;
  final int color;
  final String icon;
  final int targetPerDay;
  final String createdAt;

  Habit({
    this.id,
    required this.name,
    this.description = '',
    this.color = 0xFF6C63FF,
    this.icon = '📋',
    this.targetPerDay = 1,
    String? createdAt,
  }) : createdAt = createdAt ?? DateTime.now().toIso8601String();

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'description': description,
      'color': color,
      'icon': icon,
      'target_per_day': targetPerDay,
      'created_at': createdAt,
    };
  }

  factory Habit.fromMap(Map<String, dynamic> map) {
    return Habit(
      id: map['id'] as int?,
      name: map['name'] as String,
      description: map['description'] as String? ?? '',
      color: map['color'] as int? ?? 0xFF6C63FF,
      icon: map['icon'] as String? ?? '📋',
      targetPerDay: map['target_per_day'] as int? ?? 1,
      createdAt: map['created_at'] as String?,
    );
  }

  Habit copyWith({
    int? id,
    String? name,
    String? description,
    int? color,
    String? icon,
    int? targetPerDay,
    String? createdAt,
  }) {
    return Habit(
      id: id ?? this.id,
      name: name ?? this.name,
      description: description ?? this.description,
      color: color ?? this.color,
      icon: icon ?? this.icon,
      targetPerDay: targetPerDay ?? this.targetPerDay,
      createdAt: createdAt ?? this.createdAt,
    );
  }
}
