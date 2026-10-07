import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

/// Add or edit an expense or income.
/// Built to be quick: the amount field is focused on open, so the usual flow
/// is type the amount, tap a category, tap Save.
class AddEntryScreen extends StatefulWidget {
  const AddEntryScreen({super.key, this.edit});

  final Txn? edit;

  @override
  State<AddEntryScreen> createState() => _AddEntryScreenState();
}

class _AddEntryScreenState extends State<AddEntryScreen> {
  late bool _isIncome;
  late final TextEditingController _amount;
  late final TextEditingController _note;
  int? _categoryId;
  late DateTime _date;

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
    _date = e?.date ?? DateTime.now();
  }

  @override
  void dispose() {
    _amount.dispose();
    _note.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _date.isAfter(DateTime.now()) ? DateTime.now() : _date,
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
    if (e == null) {
      await store.addTxn(
        isIncome: _isIncome,
        amountMinor: minor,
        categoryId: _categoryId,
        note: note,
        date: _date,
      );
    } else {
      await store.updateTxn(
        e.id,
        isIncome: _isIncome,
        amountMinor: minor,
        categoryId: _categoryId,
        note: note,
        date: _date,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  Future<void> _delete() async {
    final e = widget.edit;
    if (e == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Delete this entry?',
      message: 'This cannot be undone.',
    );
    if (!ok) return;
    await store.deleteTxn(e.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final editing = widget.edit != null;

    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final cats =
            store.categories.where((x) => x.isIncome == _isIncome).toList();
        return Scaffold(
          appBar: AppBar(
            title: Text(editing ? 'Edit entry' : 'Add entry'),
            actions: [
              if (editing)
                IconButton(
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
                        Text(
                          'Category',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: c.subtext,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (final cat in cats)
                              _CategoryChip(
                                emoji: cat.emoji,
                                label: cat.name,
                                selected: _categoryId == cat.id,
                                onTap: () =>
                                    setState(() => _categoryId = cat.id),
                              ),
                            _CategoryChip(
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
                            hint: 'Add a note (optional)',
                            prefixIcon: const Icon(Icons.notes_rounded),
                          ),
                        ),
                        const SizedBox(height: 12),
                        OutlinedButton.icon(
                          onPressed: _pickDate,
                          icon: const Icon(
                            Icons.calendar_today_rounded,
                            size: 18,
                          ),
                          label: Text(friendlyDay(_date, DateTime.now())),
                        ),
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
}

class _CategoryChip extends StatelessWidget {
  const _CategoryChip({
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
