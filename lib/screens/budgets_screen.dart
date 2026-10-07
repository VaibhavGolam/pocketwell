import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/budget_row.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

/// Monthly limits per expense category, with this month's progress.
class BudgetsScreen extends StatelessWidget {
  const BudgetsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final month = monthStart(DateTime.now());
          final expense = store.categories.where((x) => !x.isIncome).toList();
          final withLimit = expense
              .where((x) => store.budgetFor(x.id) != null)
              .toList()
            ..sort((a, b) {
              final ra = store.spentIn(month, a.id) /
                  store.budgetFor(a.id)!.limitMinor;
              final rb = store.spentIn(month, b.id) /
                  store.budgetFor(b.id)!.limitMinor;
              return rb.compareTo(ra);
            });
          final without =
              expense.where((x) => store.budgetFor(x.id) == null).toList();

          var totalLimit = 0;
          var totalSpent = 0;
          for (final cat in withLimit) {
            totalLimit += store.budgetFor(cat.id)!.limitMinor;
            totalSpent += store.spentIn(month, cat.id);
          }

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
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
                    if (withLimit.isEmpty)
                      Text(
                        'Tap a category below and set a monthly limit. The bar fills as you spend, and turns amber at 80%.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.4,
                          color: c.text,
                        ),
                      )
                    else ...[
                      Text(
                        '${store.fmt(totalSpent)} of ${store.fmt(totalLimit)}',
                        style: TextStyle(
                          fontSize: 24,
                          fontWeight: FontWeight.w800,
                          color: c.text,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Spent on the categories that have a limit. Limits repeat every month.',
                        style: TextStyle(
                          fontSize: 13,
                          height: 1.4,
                          color: c.subtext,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (withLimit.isNotEmpty) ...[
                _label(c, 'WITH A LIMIT'),
                SurfaceCard(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 4,
                  ),
                  child: Column(
                    children: [
                      for (var i = 0; i < withLimit.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: c.border),
                        BudgetRow(
                          category: withLimit[i],
                          limitMinor: store.budgetFor(withLimit[i].id)!.limitMinor,
                          spentMinor: store.spentIn(month, withLimit[i].id),
                          onTap: () => showBudgetDialog(context, withLimit[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
              if (without.isNotEmpty) ...[
                _label(c, 'NO LIMIT YET'),
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < without.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: c.border),
                        ListTile(
                          leading: EmojiBadge(without[i].emoji, size: 38),
                          title: Text(without[i].name),
                          subtitle: Text(
                            '${store.fmt(store.spentIn(month, without[i].id))} spent this month',
                          ),
                          trailing: const Icon(Icons.add_rounded),
                          onTap: () => showBudgetDialog(context, without[i]),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _label(AppColors c, String text) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 8),
        child: Text(
          text,
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w700,
            color: c.subtext,
          ),
        ),
      );
}
