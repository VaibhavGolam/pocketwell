import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/recurrence.dart';
import '../widgets/common.dart';
import 'recurring_edit_screen.dart';

/// Entries that add themselves: rent, salary, subscriptions, EMIs.
class RecurringScreen extends StatelessWidget {
  const RecurringScreen({super.key});

  void _open(BuildContext context, [Recurring? edit]) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => RecurringEditScreen(edit: edit),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Repeating entries')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(context),
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final rules = store.recurring;
          if (rules.isEmpty) {
            return const Center(
              child: SingleChildScrollView(
                child: EmptyState(
                  emoji: '🔁',
                  title: 'Nothing repeats yet',
                  message:
                      'Add rent, salary, a subscription or an EMI once. Pocketwell adds it for you on the day, every time.',
                ),
              ),
            );
          }
          final now = DateTime.now();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (var i = 0; i < rules.length; i++) ...[
                      if (i > 0) Divider(height: 1, color: c.border),
                      _tile(context, c, rules[i], now),
                    ],
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
                child: Text(
                  'Entries are added when you open the app on or after the due date, and dated on the day they were due.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: c.subtext),
                ),
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _tile(BuildContext context, AppColors c, Recurring r, DateTime now) {
    final category = store.categoryById(r.categoryId);
    final title = r.note.isNotEmpty ? r.note : (category?.name ?? 'Other');
    final status = r.active
        ? 'Next: ${friendlyDate(r.nextDue, now)}'
        : 'Paused';
    final amount = r.isIncome
        ? '+${store.fmt(r.amountMinor)}'
        : '-${store.fmt(r.amountMinor)}';
    return InkWell(
      onTap: () => _open(context, r),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            Opacity(
              opacity: r.active ? 1 : 0.5,
              child: EmojiBadge(category?.emoji ?? '🧾'),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: r.active ? c.text : c.subtext,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${describeSchedule(r.frequency, r.anchor)} · $status',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.subtext),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Text(
              amount,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: r.isIncome ? c.moneyIn : c.moneyOut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
