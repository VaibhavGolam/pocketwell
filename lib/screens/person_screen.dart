import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

/// One person's running balance and history.
///
/// "I gave" = money left my pocket (I lent, or I paid back).
/// "I got"  = money came to me (I borrowed, or they paid me back).
class PersonScreen extends StatelessWidget {
  const PersonScreen({super.key, required this.personId});

  final int personId;

  Future<void> _pickDue(BuildContext context, Person p) async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: p.dueDate ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 5, 12, 31),
    );
    if (picked == null) return;
    await store.setPersonDue(p.id, picked);
  }

  Future<void> _remind(BuildContext context, Person p, int balance) async {
    final amount = store.fmt(balance);
    final text =
        'Hi ${p.name}, a friendly reminder about the $amount you owe me. '
        'Please send it over when you get a chance. Thanks!';
    var number = p.phone.replaceAll(RegExp(r'[^0-9]'), '');
    // A bare 10 digit number is assumed to be Indian when the currency is rupees.
    if (number.length == 10 && store.currencySymbol == '₹') {
      number = '91$number';
    }
    final encoded = Uri.encodeComponent(text);
    final uri = number.isEmpty
        ? Uri.parse('https://wa.me/?text=$encoded')
        : Uri.parse('https://wa.me/$number?text=$encoded');
    var opened = false;
    try {
      opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (_) {
      opened = false;
    }
    if (!opened && context.mounted) {
      showSnack(context, 'Could not open WhatsApp');
    }
  }

  Future<void> _deleteEntry(BuildContext context, LedgerEntry e) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete this entry?',
      message: '${store.fmt(e.amountMinor)} on ${formatDayYear(e.date)} will be removed.',
    );
    if (!ok) return;
    await store.deleteLedger(e.id, e.personId);
  }

  Future<void> _deletePerson(BuildContext context, Person p) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${p.name}?',
      message: 'This removes ${p.name} and every entry with them.',
    );
    if (!ok) return;
    await store.deletePerson(p.id);
    if (!context.mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = store.personById(personId);
        if (p == null) return const Scaffold(body: SizedBox.shrink());

        final balance = store.balanceOf(p.id);
        final entries = store.entriesFor(p.id);
        final today = DateTime.now();

        final String headline;
        final Color headlineColor;
        if (balance > 0) {
          headline = '${p.name} owes you';
          headlineColor = c.moneyIn;
        } else if (balance < 0) {
          headline = 'You owe ${p.name}';
          headlineColor = c.moneyOut;
        } else {
          headline = 'All settled';
          headlineColor = c.subtext;
        }

        final due = p.dueDate;
        String dueLabel = 'Set due date';
        if (due != null) {
          final daysLate = daysBetween(due, today);
          if (daysLate > 0) {
            dueLabel = 'Overdue since ${formatDay(due)}';
          } else if (daysLate == 0) {
            dueLabel = 'Due today';
          } else {
            dueLabel = 'Due ${formatDayYear(due)}';
          }
        }

        return Scaffold(
          appBar: AppBar(
            title: Text(p.name),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    await showPersonDialog(context, edit: p);
                  } else if (v == 'delete') {
                    await _deletePerson(context, p);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem<String>(value: 'edit', child: Text('Edit details')),
                  PopupMenuItem<String>(value: 'delete', child: Text('Delete person')),
                ],
              ),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
            children: [
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(headline, style: TextStyle(fontSize: 14, color: c.subtext)),
                    const SizedBox(height: 4),
                    Text(
                      store.fmt(balance.abs()),
                      style: TextStyle(
                        fontSize: 34,
                        fontWeight: FontWeight.w800,
                        color: headlineColor,
                      ),
                    ),
                    if (balance != 0) ...[
                      const SizedBox(height: 14),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            onPressed: () => _pickDue(context, p),
                            icon: const Icon(Icons.event_rounded, size: 18),
                            label: Text(dueLabel),
                          ),
                          if (due != null)
                            IconButton(
                              tooltip: 'Clear due date',
                              icon: const Icon(Icons.close_rounded),
                              onPressed: () => store.setPersonDue(p.id, null),
                            ),
                          if (balance > 0)
                            FilledButton.tonalIcon(
                              onPressed: () => _remind(context, p, balance),
                              icon: const Icon(Icons.chat_rounded, size: 18),
                              label: const Text('Remind on WhatsApp'),
                            ),
                        ],
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => showLedgerSheet(
                        context,
                        personId: p.id,
                        gave: true,
                      ),
                      icon: const Icon(Icons.north_east_rounded),
                      label: const Text('I gave'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => showLedgerSheet(
                        context,
                        personId: p.id,
                        gave: false,
                      ),
                      icon: const Icon(Icons.south_west_rounded),
                      label: const Text('I got'),
                    ),
                  ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 10, 4, 0),
                child: Text(
                  'Use I gave when you lend money or pay someone back. '
                  'Use I got when you borrow money or get paid back.',
                  style: TextStyle(fontSize: 12, height: 1.4, color: c.subtext),
                ),
              ),
              const SizedBox(height: 20),
              Padding(
                padding: const EdgeInsets.fromLTRB(4, 0, 4, 8),
                child: Text(
                  'History',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
              if (entries.isEmpty)
                const EmptyState(
                  emoji: '📒',
                  title: 'No entries yet',
                  message: 'Tap I gave or I got to add the first one.',
                )
              else
                SurfaceCard(
                  padding: EdgeInsets.zero,
                  child: Column(
                    children: [
                      for (var i = 0; i < entries.length; i++) ...[
                        if (i > 0) Divider(height: 1, color: c.border),
                        _entryRow(context, c, entries[i], today),
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

  Widget _entryRow(
    BuildContext context,
    AppColors c,
    LedgerEntry e,
    DateTime today,
  ) {
    final parts = <String>[];
    if (e.note.isNotEmpty) parts.add(e.note);
    parts.add(friendlyDay(e.date, today));
    final color = e.gave ? c.moneyOut : c.moneyIn;
    return InkWell(
      onTap: () => _deleteEntry(context, e),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: color.withValues(alpha: 0.14),
              child: Icon(
                e.gave ? Icons.north_east_rounded : Icons.south_west_rounded,
                size: 18,
                color: color,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    e.gave ? 'I gave' : 'I got',
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: c.text,
                    ),
                  ),
                  Text(
                    parts.join(' · '),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 13, color: c.subtext),
                  ),
                ],
              ),
            ),
            Text(
              store.fmt(e.amountMinor),
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: color,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// --------------------------------------------------------------- entry sheet

Future<void> showLedgerSheet(
  BuildContext context, {
  required int personId,
  required bool gave,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _LedgerSheet(personId: personId, gave: gave),
  );
}

class _LedgerSheet extends StatefulWidget {
  const _LedgerSheet({required this.personId, required this.gave});

  final int personId;
  final bool gave;

  @override
  State<_LedgerSheet> createState() => _LedgerSheetState();
}

class _LedgerSheetState extends State<_LedgerSheet> {
  final TextEditingController _amount = TextEditingController();
  final TextEditingController _note = TextEditingController();
  DateTime _date = DateTime.now();
  DateTime? _due;

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() {
      _date = DateTime(
        picked.year,
        picked.month,
        picked.day,
        _date.hour,
        _date.minute,
      );
    });
  }

  Future<void> _pickDue() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _due ?? today,
      firstDate: DateTime(2000),
      lastDate: DateTime(today.year + 5, 12, 31),
    );
    if (picked != null) setState(() => _due = picked);
  }

  Future<void> _save() async {
    final minor = parseAmountMinor(_amount.text);
    if (minor == null) {
      showSnack(context, 'Enter an amount');
      return;
    }
    await store.addLedger(
      personId: widget.personId,
      gave: widget.gave,
      amountMinor: minor,
      note: _note.text.trim(),
      date: _date,
      dueDate: _due,
    );
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final person = store.personById(widget.personId);
    final name = person?.name ?? '';
    final color = widget.gave ? c.moneyOut : c.moneyIn;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        20,
        0,
        20,
        20 + MediaQuery.of(context).viewInsets.bottom,
      ),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              widget.gave ? 'I gave $name' : 'I got from $name',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _amount,
              autofocus: true,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
              ],
              style: TextStyle(
                fontSize: 34,
                fontWeight: FontWeight.w800,
                color: color,
              ),
              decoration: InputDecoration(
                prefixText: '${store.currencySymbol} ',
                prefixStyle: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: c.subtext,
                ),
                hintText: '0',
                hintStyle: TextStyle(
                  fontSize: 34,
                  fontWeight: FontWeight.w800,
                  color: c.border,
                ),
                border: InputBorder.none,
              ),
            ),
            TextField(
              controller: _note,
              textCapitalization: TextCapitalization.sentences,
              decoration: pwInput(
                context,
                hint: 'Note (optional)',
                prefixIcon: const Icon(Icons.notes_rounded),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDate,
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  label: Text(friendlyDay(_date, DateTime.now())),
                ),
                OutlinedButton.icon(
                  onPressed: _pickDue,
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(
                    _due == null
                        ? 'Due date (optional)'
                        : 'Due ${formatDayYear(_due!)}',
                  ),
                ),
                if (_due != null)
                  IconButton(
                    tooltip: 'Clear due date',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _due = null),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(onPressed: _save, child: const Text('Save')),
            ),
          ],
        ),
      ),
    );
  }
}
