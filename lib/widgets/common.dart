import 'package:flutter/material.dart';

import '../theme.dart';

/// A white (or charcoal, in dark mode) rounded card with a soft border.
class SurfaceCard extends StatelessWidget {
  const SurfaceCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin = EdgeInsets.zero,
    this.onTap,
    this.color,
  });

  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry margin;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final radius = BorderRadius.circular(18);
    return Padding(
      padding: margin,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: color ?? c.card,
          borderRadius: radius,
          border: Border.all(color: c.border),
          boxShadow: c.shadow,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            borderRadius: radius,
            onTap: onTap,
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

/// An emoji inside a soft round badge.
class EmojiBadge extends StatelessWidget {
  const EmojiBadge(this.emoji, {super.key, this.size = 44});

  final String emoji;
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: c.accent.withValues(alpha: 0.12),
        shape: BoxShape.circle,
      ),
      child: Text(emoji, style: TextStyle(fontSize: size * 0.48)),
    );
  }
}

/// A thin bar that fills from the left. [value] is 0 to 1; anything above 1 is
/// shown as full.
class ProgressBar extends StatelessWidget {
  const ProgressBar({
    super.key,
    required this.value,
    required this.color,
    this.height = 8,
  });

  final double value;
  final Color color;
  final double height;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final fill = value.isNaN ? 0.0 : value.clamp(0.0, 1.0).toDouble();
    final radius = BorderRadius.circular(height / 2);
    return Container(
      height: height,
      decoration: BoxDecoration(color: c.border, borderRadius: radius),
      child: Align(
        alignment: Alignment.centerLeft,
        child: FractionallySizedBox(
          widthFactor: fill,
          heightFactor: 1,
          child: DecoratedBox(
            decoration: BoxDecoration(color: color, borderRadius: radius),
          ),
        ),
      ),
    );
  }
}

/// A rounded emoji and label, used to pick a category.
class CategoryChip extends StatelessWidget {
  const CategoryChip({
    super.key,
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? c.accent.withValues(alpha: 0.16) : c.card,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: selected ? c.accent : c.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                color: c.text,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({
    super.key,
    required this.emoji,
    required this.title,
    required this.message,
  });

  final String emoji;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40, horizontal: 24),
      child: Column(
        children: [
          Text(emoji, style: const TextStyle(fontSize: 44)),
          const SizedBox(height: 12),
          Text(
            title,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            message,
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 14, height: 1.4, color: c.subtext),
          ),
        ],
      ),
    );
  }
}

/// Input style used across the app.
InputDecoration pwInput(
  BuildContext context, {
  String? hint,
  String? label,
  Widget? prefixIcon,
  String? prefixText,
}) {
  final c = AppColors.of(context);
  OutlineInputBorder border(Color color) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: color),
      );
  return InputDecoration(
    hintText: hint,
    labelText: label,
    prefixIcon: prefixIcon,
    prefixText: prefixText,
    filled: true,
    fillColor: c.card,
    border: border(c.border),
    enabledBorder: border(c.border),
    focusedBorder: border(c.accent),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

Future<bool> confirmDialog(
  BuildContext context, {
  required String title,
  required String message,
  String confirmLabel = 'Delete',
}) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(ctx, false),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () => Navigator.pop(ctx, true),
          child: Text(confirmLabel),
        ),
      ],
    ),
  );
  return result ?? false;
}

void showSnack(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

const List<String> kEmojiChoices = [
  '🍔', '🍕', '🍜', '☕', '🛒', '🥦', '🚌', '🚕',
  '⛽', '🏍️', '🏠', '💡', '📱', '💻', '🎬', '🎮',
  '🛍️', '👕', '💊', '🏥', '📚', '🎓', '✈️', '🏖️',
  '🎁', '🎂', '🐾', '🧾', '💼', '🏪', '💰', '📈',
  '🔁', '➕', '💸', '🧴', '🔧', '🚗', '🍺', '🏋️',
  '💇', '🎵', '📦', '🙏', '👶', '🛡️', '💍', '🎯',
];

class EmojiPicker extends StatelessWidget {
  const EmojiPicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.choices = kEmojiChoices,
  });

  final String selected;
  final ValueChanged<String> onChanged;
  final List<String> choices;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      children: [
        for (final e in choices)
          GestureDetector(
            onTap: () => onChanged(e),
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: e == selected
                    ? c.accent.withValues(alpha: 0.18)
                    : Colors.transparent,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: e == selected ? c.accent : c.border),
              ),
              child: Text(e, style: const TextStyle(fontSize: 22)),
            ),
          ),
      ],
    );
  }
}
