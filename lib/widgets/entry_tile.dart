import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../screens/add_entry_screen.dart';
import '../theme.dart';
import '../util/format.dart';
import 'common.dart';

/// One row in an entries list. Tap to edit.
class EntryTile extends StatelessWidget {
  const EntryTile({super.key, required this.txn});

  final Txn txn;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final category = store.categoryById(txn.categoryId);
    final emoji = category?.emoji ?? '🧾';
    final name = category?.name ?? 'Other';

    final parts = <String>[];
    if (txn.note.isNotEmpty) parts.add(txn.note);
    parts.add(friendlyDay(txn.date, DateTime.now()));

    final amount = txn.isIncome
        ? '+${store.fmt(txn.amountMinor)}'
        : '-${store.fmt(txn.amountMinor)}';

    return InkWell(
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(builder: (_) => AddEntryScreen(edit: txn)),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            EmojiBadge(emoji),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: c.text,
                          ),
                        ),
                      ),
                      if (txn.recurringId != null)
                        Padding(
                          padding: const EdgeInsets.only(left: 6),
                          child: Icon(
                            Icons.repeat_rounded,
                            size: 14,
                            color: c.subtext,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    parts.join(' · '),
                    maxLines: 1,
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
                color: txn.isIncome ? c.moneyIn : c.moneyOut,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
