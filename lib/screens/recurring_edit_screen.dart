import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../util/recurrence.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

/// Create or edit a repeating entry.
class RecurringEditScreen extends StatefulWidget {
  const RecurringEditScreen({super.key, this.edit});

  final Recurring? edit;

  @override
  State<RecurringEditScreen> createState() => _RecurringEditScreenState();
}

class _RecurringEditScreenState extends State<RecurringEditScreen> {
  late bool _isIncome;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  int? _categoryId;
  late Frequency _frequency;
  late DateTime _date;
  late bool _active;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _isIncome = e?.isIncome ?? false;
    _amount = TextEditingController(
      text: e == null ? '' : plainAmount(e.amountMinor),
    );
    _note = TextEditingController(text: e?.note ?? '');
    _categoryId = e?.categoryId;
    _frequency = e?.frequency ?? Frequency.monthly;
    _date = e?.nextDue ?? dateOnly(DateTime.now());
    _active = e?.active ?? true;
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  DateTime get _today => dateOnly(DateTime.now());

  Future<void> _pickDate() async {
    final today = _today;
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isBefore(today) ? today : _date,
      firstDate: today,
      lastDate: DateTime(today.year + 5, today.month, today.day),
    );
    if (picked == null) return;
    setState(() => _date = dateOnly(picked));
  }

  Future<void> _newCategory() async {
    final id = await showCategoryDialog(context, isIncome: _isIncome);
    if (id != null && mounted) setState(() => _categoryId = id);
  }

  Future<void> _save() async {
    final minor = parseAmountMinor(_amount.text);
    if (minor == null) {
      showSnack(context, 'Enter an amount');
      return;
    }
    final note = _note.text.trim();
    final e = widget.edit;
    final date = _date.isBefore(_today) ? _today : _date;

    if (e == null) {
      await store.addRecurring(
        isIncome: _isIncome,
        amountMinor: minor,
        categoryId: _categoryId,
        note: note,
        frequency: _frequency,
        anchor: date,
        nextDue: date,
      );
    } else {
      // A new first date or a new frequency starts the schedule again.
      final changed = _frequency != e.frequency || !sameDay(date, e.nextDue);
      await store.updateRecurring(
        e.id,
        isIncome: _isIncome,
        amountMinor: minor,
        categoryId: _categoryId,
        note: note,
        frequency: _frequency,
        anchor: changed ? date : e.anchor,
        nextDue: changed ? date : e.nextDue,
        active: _active,
      );
    }
    await store.processRecurring();
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = widget.edit;
    if (e == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Stop this repeating entry?',
      message: 'Entries it already added are kept. No new ones will be added.',
      confirmLabel: 'Stop',
    );
    if (!ok) return;
    await store.deleteRecurring(e.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final editing = widget.edit != null;
    final now = DateTime.now();

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cats =
            store.categories.where((x) => x.isIncome == _isIncome).toList();
        final date = _date.isBefore(_today) ? _today : _date;
        // Describe the schedule that will really be saved: untouched edits keep
        // their original anchor (a rule set for the 31st stays on the 31st).
        final e = widget.edit;
        final unchanged =
            e != null && _frequency == e.frequency && sameDay(date, e.nextDue);
        final shownAnchor = (e != null && unchanged) ? e.anchor : date;
        final first = sameDay(date, _today)
            ? 'The first entry is added today.'
            : 'The first entry is added on ${friendlyDate(date, now)}.';

        return Scaffold(
          appBar: AppBar(
            title: Text(editing ? 'Edit repeating entry' : 'New repeating entry'),
            actions: [
              if (editing)
                IconButton(
                  tooltip: 'Stop repeating',
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: _delete,
                ),
            ],
          ),
          body: SafeArea(
            child: Column(
              children: [
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        SegmentedButton<bool>(
                          segments: const [
                            ButtonSegment<bool>(
                              value: false,
                              label: Text('Expense'),
                              icon: Icon(Icons.north_east_rounded),
                            ),
                            ButtonSegment<bool>(
                              value: true,
                              label: Text('Income'),
                              icon: Icon(Icons.south_west_rounded),
                            ),
                          ],
                          selected: {_isIncome},
                          showSelectedIcon: false,
                          onSelectionChanged: (s) => setState(() {
                            _isIncome = s.first;
                            _categoryId = null;
                          }),
                        ),
                        const SizedBox(height: 16),
                        TextField(
                          controller: _amount,
                          autofocus: !editing,
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          inputFormatters: [
                            FilteringTextInputFormatter.allow(
                              RegExp(r'[0-9.,]'),
                            ),
                          ],
                          style: TextStyle(
                            fontSize: 40,
                            fontWeight: FontWeight.w800,
                            color: _isIncome ? c.moneyIn : c.moneyOut,
                          ),
                          decoration: InputDecoration(
                            prefixText: '${store.currencySymbol} ',
                            prefixStyle: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: c.subtext,
                            ),
                            hintText: '0',
                            hintStyle: TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: c.border,
                            ),
                            border: InputBorder.none,
                          ),
                        ),
                        const SizedBox(height: 8),
                        _label(c, 'Category'),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final cat in cats)
                              CategoryChip(
                                emoji: cat.emoji,
                                label: cat.name,
                                selected: _categoryId == cat.id,
                                onTap: () =>
                                    setState(() => _categoryId = cat.id),
                              ),
                            CategoryChip(
                              emoji: '➕',
                              label: 'New',
                              selected: false,
                              onTap: _newCategory,
                            ),
                          ],
                        ),
                        const SizedBox(height: 20),
                        TextField(
                          controller: _note,
                          textCapitalization: TextCapitalization.sentences,
                          decoration: pwInput(
                            context,
                            hint: 'Note, like "House rent" (optional)',
                            prefixIcon: const Icon(Icons.notes_rounded),
                          ),
                        ),
                        const SizedBox(height: 20),
                        _label(c, 'Repeats'),
                        const SizedBox(height: 10),
                        SizedBox(
                          width: double.infinity,
                          child: SegmentedButton<Frequency>(
                            segments: [
                              for (final f in Frequency.values)
                                ButtonSegment<Frequency>(
                                  value: f,
                                  label: Text(frequencyLabel(f)),
                                ),
                            ],
                            selected: {_frequency},
                            showSelectedIcon: false,
                            onSelectionChanged: (s) =>
                                setState(() => _frequency = s.first),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                          ),
                          label: Text(
                            editing
                                ? 'Next on ${friendlyDate(date, now)}'
                                : 'Starts ${friendlyDate(date, now)}',
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          '${describeSchedule(_frequency, shownAnchor)}. $first',
                          style: TextStyle(
                            fontSize: 13,
                            height: 1.4,
                            color: c.subtext,
                          ),
                        ),
                        if (editing) ...[
                          const SizedBox(height: 8),
                          SwitchListTile(
                            contentPadding: EdgeInsets.zero,
                            title: const Text('Active'),
                            subtitle: const Text(
                              'Turn off to pause without deleting.',
                            ),
                            value: _active,
                            onChanged: (v) => setState(() => _active = v),
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: _save,
                      child: Text(editing ? 'Save changes' : 'Save'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _label(AppColors c, String text) => Text(
        text,
        style: TextStyle(
          fontSize: 13,
          fontWeight: FontWeight.w600,
          color: c.subtext,
        ),
      );
}
