import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';
import 'person_screen.dart';

/// Who owes me, and who I owe.
class PeopleScreen extends StatelessWidget {
  const PeopleScreen({super.key});

  Future<void> _addPerson(BuildContext context) async {
    final id = await showPersonDialog(context);
    if (id == null || !context.mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => PersonScreen(personId: id)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('People')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addPerson(context),
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        icon: const Icon(Icons.person_add_alt_1_rounded),
        label: const Text('Add person'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final balances = store.balances;
          var willGet = 0;
          var willPay = 0;
          for (final b in balances.values) {
            if (b > 0) willGet += b;
            if (b < 0) willPay += -b;
          }

          final today = DateTime.now();
          final people = List<Person>.of(store.people);
          bool overdue(Person p) {
            final due = p.dueDate;
            return due != null &&
                (balances[p.id] ?? 0) != 0 &&
                daysBetween(due, today) > 0;
          }

          people.sort((a, b) {
            final oa = overdue(a);
            final ob = overdue(b);
            if (oa != ob) return oa ? -1 : 1;
            return store.lastActivity(b).compareTo(store.lastActivity(a));
          });

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              SurfaceCard(
                child: Row(
                  children: [
                    Expanded(
                      child: _total(c, 'You will get', willGet, c.moneyIn),
                    ),
                    Container(width: 1, height: 44, color: c.border),
                    const SizedBox(width: 16),
                    Expanded(
                      child: _total(c, 'You will pay', willPay, c.moneyOut),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 16),
              if (people.isEmpty)
                const EmptyState(
                  emoji: '🤝',
                  title: 'No one here yet',
                  message:
                      'Add someone you lend to or borrow from. You will see one running balance per person.',
                )
              else
                for (final p in people)
                  _personCard(context, c, p, balances[p.id] ?? 0, today),
            ],
          );
        },
      ),
    );
  }

  Widget _total(AppColors c, String label, int minor, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: c.subtext)),
        const SizedBox(height: 4),
        FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text(
            store.fmt(minor),
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ),
      ],
    );
  }

  Widget _personCard(
    BuildContext context,
    AppColors c,
    Person p,
    int balance,
    DateTime today,
  ) {
    final due = p.dueDate;
    Widget subtitle;
    if (balance == 0) {
      subtitle = Text('Settled', style: TextStyle(fontSize: 13, color: c.subtext));
    } else if (due == null) {
      subtitle = Text('No due date', style: TextStyle(fontSize: 13, color: c.subtext));
    } else {
      final daysLate = daysBetween(due, today);
      if (daysLate > 0) {
        subtitle = Text(
          'Overdue by $daysLate ${daysLate == 1 ? 'day' : 'days'}',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: c.moneyOut,
          ),
        );
      } else if (daysLate == 0) {
        subtitle = Text(
          'Due today',
          style: TextStyle(
            fontSize: 13,
            fontWeight: FontWeight.w600,
            color: c.accent,
          ),
        );
      } else {
        subtitle = Text(
          'Due ${formatDay(due)}',
          style: TextStyle(fontSize: 13, color: c.subtext),
        );
      }
    }

    final initial = p.name.isEmpty ? '?' : p.name.substring(0, 1).toUpperCase();
    final amountColor = balance > 0 ? c.moneyIn : (balance < 0 ? c.moneyOut : c.subtext);
    final amountLabel = balance > 0
        ? "you'll get"
        : (balance < 0 ? "you'll pay" : '');

    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => PersonScreen(personId: p.id)),
        );
      },
      child: Row(
        children: [
          CircleAvatar(
            radius: 22,
            backgroundColor: c.accent.withValues(alpha: 0.14),
            child: Text(
              initial,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: c.accent,
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 2),
                subtitle,
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                store.fmt(balance.abs()),
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: amountColor,
                ),
              ),
              if (amountLabel.isNotEmpty)
                Text(
                  amountLabel,
                  style: TextStyle(fontSize: 12, color: c.subtext),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
