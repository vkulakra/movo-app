import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class HabitIconPicker extends StatefulWidget {
  final String selectedIcon;
  final ValueChanged<String> onIconChanged;

  const HabitIconPicker({
    super.key,
    required this.selectedIcon,
    required this.onIconChanged,
  });

  @override
  State<HabitIconPicker> createState() => _HabitIconPickerState();
}

class _HabitIconPickerState extends State<HabitIconPicker> {
  late String _selectedIcon;

  @override
  void initState() {
    super.initState();
    _selectedIcon = widget.selectedIcon;
  }

  @override
  void didUpdateWidget(HabitIconPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.selectedIcon != oldWidget.selectedIcon) {
      _selectedIcon = widget.selectedIcon;
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final itemBg = isDark ? AppTheme.darkSurfaceColor : Colors.grey[100]!;

    return SizedBox(
      height: 52,
      child: Scrollbar(
        thumbVisibility: true,
        thickness: 6,
        radius: const Radius.circular(3),
        child: ListView(
          scrollDirection: Axis.horizontal,
          children: AppTheme.habitIcons.map((emoji) {
            final isSelected = _selectedIcon == emoji;
            return GestureDetector(
              onTap: () {
                setState(() => _selectedIcon = emoji);
                widget.onIconChanged(emoji);
              },
              child: Container(
                width: 44,
                height: 44,
                margin: const EdgeInsets.only(right: 8),
                decoration: BoxDecoration(
                  color: isSelected
                      ? AppTheme.primaryColor.withValues(alpha: 0.15)
                      : itemBg,
                  borderRadius: BorderRadius.circular(12),
                  border: isSelected
                      ? Border.all(color: AppTheme.primaryColor, width: 2)
                      : Border.all(color: Colors.transparent, width: 2),
                ),
                child: Center(
                  child: Text(emoji, style: const TextStyle(fontSize: 22)),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}
