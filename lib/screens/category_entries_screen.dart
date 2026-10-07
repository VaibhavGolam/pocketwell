import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/entry_tile.dart';

/// Every expense in one category for one month.
class CategoryEntriesScreen extends StatelessWidget {
  const CategoryEntriesScreen({
    super.key,
    required this.month,
    required this.categoryId,
  });

  final DateTime month;
  final int? categoryId;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final category = store.categoryById(categoryId);
        final emoji = category?.emoji ?? '🧾';
        final name = category?.name ?? 'Other';
        final entries = store
            .txnsInMonth(month)
            .where((t) => !t.isIncome && t.categoryId == categoryId)
            .toList();
        final total = entries.fold<int>(0, (sum, t) => sum + t.amountMinor);

        return Scaffold(
          appBar: AppBar(title: Text('$emoji $name')),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${kMonthNames[month.month - 1]} ${month.year}',
                      style: TextStyle(fontSize: 13, color: c.subtext),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      store.fmt(total),
                      style: TextStyle(
                        fontSize: 30,
                        fontWeight: FontWeight.w800,
                        color: c.moneyOut,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              if (entries.isEmpty)
                const EmptyState(
                  emoji: '🌱',
                  title: 'No entries',
                  message: 'Nothing in this category for the month.',
                )
              else
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: c.border),
                        EntryTile(txn: entries[i]),
                      ],
                    ],
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
