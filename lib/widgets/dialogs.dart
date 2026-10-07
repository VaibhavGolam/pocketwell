import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../util/format.dart';
import 'common.dart';

// ------------------------------------------------------------------ category

/// Create or edit a category. Returns the id of the category that was created
/// or edited, or null if the dialog was cancelled or the category deleted.
Future<int?> showCategoryDialog(
  BuildContext context, {
  Category? edit,
  bool isIncome = false,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _CategoryDialog(edit: edit, isIncome: isIncome),
  );
}

class _CategoryDialog extends StatefulWidget {
  const _CategoryDialog({required this.edit, required this.isIncome});

  final Category? edit;
  final bool isIncome;

  @override
  State<_CategoryDialog> createState() => _CategoryDialogState();
}

class _CategoryDialogState extends State<_CategoryDialog> {
  late final TextEditingController _name;
  late String _emoji;
  late bool _income;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    _name = TextEditingController(text: e?.name ?? '');
    _emoji = e?.emoji ?? '🧾';
    _income = e?.isIncome ?? widget.isIncome;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showSnack(context, 'Give the category a name');
      return;
    }
    final e = widget.edit;
    final int id;
    if (e == null) {
      id = await store.addCategory(name: name, emoji: _emoji, isIncome: _income);
    } else {
      await store.updateCategory(e.id, name, _emoji);
      id = e.id;
    }
    if (!mounted) return;
    Navigator.of(context).pop(id);
  }

  Future<void> _delete() async {
    final e = widget.edit;
    if (e == null) return;
    final ok = await confirmDialog(
      context,
      title: 'Delete ${e.name}?',
      message: 'Entries in this category are kept and shown as Other.',
    );
    if (!ok) return;
    await store.deleteCategory(e.id);
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.edit != null;
    return AlertDialog(
      title: Text(editing ? 'Edit category' : 'New category'),
      content: SizedBox(
        width: double.maxFinite,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (!editing) ...[
                SegmentedButton<bool>(
                  segments: const [
                    ButtonSegment<bool>(value: false, label: Text('Expense')),
                    ButtonSegment<bool>(value: true, label: Text('Income')),
                  ],
                  selected: {_income},
                  onSelectionChanged: (s) => setState(() => _income = s.first),
                ),
                const SizedBox(height: 14),
              ],
              TextField(
                controller: _name,
                autofocus: !editing,
                maxLength: 24,
                textCapitalization: TextCapitalization.words,
                decoration: pwInput(context, label: 'Name'),
              ),
              const SizedBox(height: 8),
              const Text('Emoji'),
              const SizedBox(height: 8),
              EmojiPicker(
                selected: _emoji,
                onChanged: (e) => setState(() => _emoji = e),
              ),
            ],
          ),
        ),
      ),
      actions: [
        if (editing)
          TextButton(onPressed: _delete, child: const Text('Delete')),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

// -------------------------------------------------------------------- person

/// Create or edit a person. Returns the person's id, or null if cancelled.
Future<int?> showPersonDialog(BuildContext context, {Person? edit}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _PersonDialog(edit: edit),
  );
}

class _PersonDialog extends StatefulWidget {
  const _PersonDialog({required this.edit});

  final Person? edit;

  @override
  State<_PersonDialog> createState() => _PersonDialogState();
}

class _PersonDialogState extends State<_PersonDialog> {
  late final TextEditingController _name;
  late final TextEditingController _phone;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.edit?.name ?? '');
    _phone = TextEditingController(text: widget.edit?.phone ?? '');
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty) {
      showSnack(context, 'Enter a name');
      return;
    }
    final phone = _phone.text.trim();
    final e = widget.edit;
    final int id;
    if (e == null) {
      id = await store.addPerson(name, phone);
    } else {
      await store.updatePerson(e.id, name, phone);
      id = e.id;
    }
    if (!mounted) return;
    Navigator.of(context).pop(id);
  }

  @override
  Widget build(BuildContext context) {
    final editing = widget.edit != null;
    return AlertDialog(
      title: Text(editing ? 'Edit details' : 'Add person'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _name,
              autofocus: !editing,
              textCapitalization: TextCapitalization.words,
              decoration: pwInput(context, label: 'Name'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phone,
              keyboardType: TextInputType.phone,
              inputFormatters: [
                FilteringTextInputFormatter.allow(RegExp(r'[0-9+ ]')),
              ],
              decoration: pwInput(
                context,
                label: 'Phone (optional)',
                hint: 'Used for WhatsApp reminders',
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _save, child: const Text('Save')),
      ],
    );
  }
}

// -------------------------------------------------------------------- amount

/// Asks for a single amount. Returns minor units, or null if cancelled.
Future<int?> askAmount(
  BuildContext context, {
  required String title,
  String? hint,
}) {
  return showDialog<int>(
    context: context,
    builder: (_) => _AmountDialog(title: title, hint: hint),
  );
}

class _AmountDialog extends StatefulWidget {
  const _AmountDialog({required this.title, this.hint});

  final String title;
  final String? hint;

  @override
  State<_AmountDialog> createState() => _AmountDialogState();
}

class _AmountDialogState extends State<_AmountDialog> {
  final TextEditingController _controller = TextEditingController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final minor = parseAmountMinor(_controller.text);
    if (minor == null) {
      showSnack(context, 'Enter an amount');
      return;
    }
    Navigator.of(context).pop(minor);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
        decoration: pwInput(
          context,
          hint: widget.hint ?? 'Amount',
          prefixText: '${store.currencySymbol} ',
        ),
        onSubmitted: (_) => _submit(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _submit, child: const Text('Add')),
      ],
    );
  }
}
