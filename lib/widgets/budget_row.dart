import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import 'common.dart';

Color budgetColor(AppColors c, BudgetLevel level) {
  switch (level) {
    case BudgetLevel.ok:
      return c.accent;
    case BudgetLevel.close:
      return c.warn;
    case BudgetLevel.over:
      return c.moneyOut;
  }
}

/// One budget: category, "spent of limit", and a bar that fills as you spend.
class BudgetRow extends StatelessWidget {
  const BudgetRow({
    super.key,
    required this.category,
    required this.limitMinor,
    required this.spentMinor,
    this.onTap,
  });

  final Category category;
  final int limitMinor;
  final int spentMinor;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final level = budgetLevel(spentMinor, limitMinor);
    final color = budgetColor(c, level);
    final percent = limitMinor == 0 ? 0 : spentMinor * 100 ~/ limitMinor;
    final over = spentMinor > limitMinor;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text(category.emoji, style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    category.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                ),
                Text(
                  '$percent%',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: level == BudgetLevel.ok ? c.subtext : color,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ProgressBar(
              value: limitMinor == 0 ? 0 : spentMinor / limitMinor,
              color: color,
            ),
            const SizedBox(height: 6),
            Text(
              over
                  ? '${store.fmt(spentMinor)} of ${store.fmt(limitMinor)}, '
                      '${store.fmt(spentMinor - limitMinor)} over'
                  : '${store.fmt(spentMinor)} of ${store.fmt(limitMinor)}, '
                      '${store.fmt(limitMinor - spentMinor)} left',
              style: TextStyle(fontSize: 12, color: c.subtext),
            ),
          ],
        ),
      ),
    );
  }
}
