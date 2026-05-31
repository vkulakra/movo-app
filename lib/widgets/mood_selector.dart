import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class MoodSelector extends StatelessWidget {
  final int? selectedScore;
  final ValueChanged<int> onSelected;

  const MoodSelector({
    super.key,
    this.selectedScore,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final textSecondary = isDark ? AppTheme.darkTextSecondary : AppTheme.textSecondary;

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: List.generate(5, (index) {
        final score = index + 1;
        final isSelected = selectedScore == score;
        final moodData = _moodData[score]!;
        final moodColor = moodData['color'] as Color;

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Tappable emoji circle only
            GestureDetector(
              onTap: () => onSelected(score),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected
                      ? moodColor
                      : (isDark ? AppTheme.darkSurfaceColor : Colors.grey.withValues(alpha: 0.1)),
                  border: Border.all(
                    color: isSelected
                        ? moodColor
                        : Colors.grey.withValues(alpha: isDark ? 0.3 : 0.2),
                    width: 2.5,
                  ),
                  boxShadow: isSelected
                      ? [
                          BoxShadow(
                            color: moodColor.withValues(alpha: 0.3),
                            blurRadius: 8,
                            offset: const Offset(0, 2),
                          ),
                        ]
                      : null,
                ),
                child: Center(
                  child: AnimatedScale(
                    scale: isSelected ? 1.15 : 1.0,
                    duration: const Duration(milliseconds: 200),
                    child: Text(
                      moodData['emoji'] as String,
                      style: const TextStyle(fontSize: 26),
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 6),
            // Always visible label below the circle
            Text(
              moodData['label'] as String,
              style: TextStyle(
                fontSize: 11,
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                color: isSelected ? moodColor : textSecondary,
              ),
            ),
          ],
        );
      }),
    );
  }

  static const Map<int, Map<String, dynamic>> _moodData = {
    1: {'emoji': '😫', 'label': 'Terrible', 'color': Color(0xFFE53935)},
    2: {'emoji': '😔', 'label': 'Bad', 'color': Color(0xFFFF7043)},
    3: {'emoji': '😐', 'label': 'Okay', 'color': Color(0xFFFFC107)},
    4: {'emoji': '😊', 'label': 'Good', 'color': Color(0xFF66BB6A)},
    5: {'emoji': '🤩', 'label': 'Amazing', 'color': Color(0xFF26A69A)},
  };
}
