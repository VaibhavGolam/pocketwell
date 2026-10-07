import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/search.dart';
import '../data/store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import '../widgets/entry_tile.dart';

enum _Range { all, thisMonth, lastMonth, last3Months, thisYear, custom }

/// Find entries by note, category, type, date or amount.
class SearchScreen extends StatefulWidget {
  const SearchScreen({super.key});

  @override
  State<SearchScreen> createState() => _SearchScreenState();
}

class _SearchScreenState extends State<SearchScreen> {
  final TextEditingController _query = TextEditingController();

  EntryKind _kind = EntryKind.all;
  int? _categoryId;
  _Range _range = _Range.all;
  DateTime? _from;
  DateTime? _to;
  int? _min;
  int? _max;

  @override
  void dispose() {
    _query.dispose();
    super.dispose();
  }

  TxnFilter get _filter => TxnFilter(
        query: _query.text,
        kind: _kind,
        categoryId: _categoryId,
        from: _from,
        to: _to,
        minMinor: _min,
        maxMinor: _max,
      );

  void _clearAll() {
    setState(() {
      _query.clear();
      _kind = EntryKind.all;
      _categoryId = null;
      _range = _Range.all;
      _from = null;
      _to = null;
      _min = null;
      _max = null;
    });
  }

  // ---------------------------------------------------------------- pickers

  Future<T?> _sheet<T>(
    String title,
    List<(String, T)> options,
    T? current,
  ) {
    final c = AppColors.of(context);
    return showModalBottomSheet<T>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.sizeOf(ctx).height * 0.7,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
              Flexible(
                child: ListView(
                  shrinkWrap: true,
                  children: [
                    for (final o in options)
                      ListTile(
                        title: Text(o.$1),
                        trailing: o.$2 == current
                            ? Icon(Icons.check_rounded, color: c.accent)
                            : null,
                        onTap: () => Navigator.of(ctx).pop(o.$2),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickKind() async {
    final picked = await _sheet<EntryKind>(
      'Type',
      const [
        ('Expenses and income', EntryKind.all),
        ('Expenses only', EntryKind.expense),
        ('Income only', EntryKind.income),
      ],
      _kind,
    );
    if (picked == null) return;
    setState(() {
      _kind = picked;
      // A category from the other side can no longer match.
      final cat = store.categoryById(_categoryId);
      if (cat != null &&
          ((picked == EntryKind.expense && cat.isIncome) ||
              (picked == EntryKind.income && !cat.isIncome))) {
        _categoryId = null;
      }
    });
  }

  static const int _anyCategory = -2;

  Future<void> _pickCategory() async {
    final cats = store.categories.where((x) {
      if (_kind == EntryKind.expense) return !x.isIncome;
      if (_kind == EntryKind.income) return x.isIncome;
      return true;
    }).toList();
    final picked = await _sheet<int>(
      'Category',
      [
        ('Any category', _anyCategory),
        for (final cat in cats)
          (
            '${cat.emoji}  ${cat.name}${_kind == EntryKind.all && cat.isIncome ? ' (income)' : ''}',
            cat.id,
          ),
        ('🧾  No category', kNoCategory),
      ],
      _categoryId ?? _anyCategory,
    );
    if (picked == null) return;
    setState(() => _categoryId = picked == _anyCategory ? null : picked);
  }

  Future<void> _pickRange() async {
    final picked = await _sheet<_Range>(
      'Date',
      const [
        ('Any time', _Range.all),
        ('This month', _Range.thisMonth),
        ('Last month', _Range.lastMonth),
        ('Last 3 months', _Range.last3Months),
        ('This year', _Range.thisYear),
        ('Pick dates...', _Range.custom),
      ],
      _range,
    );
    if (picked == null) return;

    final now = DateTime.now();
    final today = dateOnly(now);
    switch (picked) {
      case _Range.all:
        setState(() {
          _range = picked;
          _from = null;
          _to = null;
        });
      case _Range.thisMonth:
        setState(() {
          _range = picked;
          _from = monthStart(now);
          _to = today;
        });
      case _Range.lastMonth:
        final start = addMonths(monthStart(now), -1);
        setState(() {
          _range = picked;
          _from = start;
          _to = DateTime(start.year, start.month + 1, 0);
        });
      case _Range.last3Months:
        setState(() {
          _range = picked;
          _from = addMonths(monthStart(now), -2);
          _to = today;
        });
      case _Range.thisYear:
        setState(() {
          _range = picked;
          _from = DateTime(now.year);
          _to = today;
        });
      case _Range.custom:
        final result = await showDateRangePicker(
          context: context,
          firstDate: DateTime(2000),
          lastDate: today,
          initialDateRange: (_from != null && _to != null)
              ? DateTimeRange(start: _from!, end: _to!)
              : null,
        );
        if (result == null) return;
        setState(() {
          _range = picked;
          _from = dateOnly(result.start);
          _to = dateOnly(result.end);
        });
    }
  }

  Future<void> _pickAmount() async {
    final result = await showDialog<(int?, int?)>(
      context: context,
      builder: (_) => _AmountRangeDialog(min: _min, max: _max),
    );
    if (result == null) return;
    setState(() {
      _min = result.$1;
      _max = result.$2;
    });
  }

  // ------------------------------------------------------------------ labels

  String get _kindLabel {
    switch (_kind) {
      case EntryKind.all:
        return 'Type';
      case EntryKind.expense:
        return 'Expenses';
      case EntryKind.income:
        return 'Income';
    }
  }

  String get _categoryLabel {
    final id = _categoryId;
    if (id == null) return 'Category';
    if (id == kNoCategory) return 'No category';
    final cat = store.categoryById(id);
    return cat == null ? 'Category' : '${cat.emoji} ${cat.name}';
  }

  String get _rangeLabel {
    switch (_range) {
      case _Range.all:
        return 'Date';
      case _Range.thisMonth:
        return 'This month';
      case _Range.lastMonth:
        return 'Last month';
      case _Range.last3Months:
        return 'Last 3 months';
      case _Range.thisYear:
        return 'This year';
      case _Range.custom:
        final f = _from;
        final t = _to;
        if (f == null || t == null) return 'Date';
        return '${formatDay(f)} to ${formatDay(t)}';
    }
  }

  String get _amountLabel {
    final lo = _min;
    final hi = _max;
    if (lo == null && hi == null) return 'Amount';
    if (lo != null && hi != null) {
      return '${store.fmt(lo)} to ${store.fmt(hi)}';
    }
    if (lo != null) return 'Over ${store.fmt(lo)}';
    return 'Under ${store.fmt(hi!)}';
  }

  // ------------------------------------------------------------------- build

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Search')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final filter = _filter;
          final results = filter.isActive
              ? store.txns
                  .where(
                    (t) => filter.matches(
                      t,
                      store.categoryById(t.categoryId)?.name ?? 'Other',
                    ),
                  )
                  .toList()
              : <Txn>[];
          var out = 0;
          var inn = 0;
          for (final t in results) {
            if (t.isIncome) {
              inn += t.amountMinor;
            } else {
              out += t.amountMinor;
            }
          }

          return Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: _query,
                  autofocus: true,
                  textInputAction: TextInputAction.search,
                  onChanged: (_) => setState(() {}),
                  decoration: pwInput(
                    context,
                    hint: 'Search notes and categories',
                    prefixIcon: const Icon(Icons.search_rounded),
                  ).copyWith(
                    suffixIcon: _query.text.isEmpty
                        ? null
                        : IconButton(
                            icon: const Icon(Icons.close_rounded),
                            onPressed: () => setState(_query.clear),
                          ),
                  ),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    _FilterChip(
                      label: _kindLabel,
                      active: _kind != EntryKind.all,
                      onTap: _pickKind,
                      onClear: () => setState(() => _kind = EntryKind.all),
                    ),
                    _FilterChip(
                      label: _categoryLabel,
                      active: _categoryId != null,
                      onTap: _pickCategory,
                      onClear: () => setState(() => _categoryId = null),
                    ),
                    _FilterChip(
                      label: _rangeLabel,
                      active: _range != _Range.all,
                      onTap: _pickRange,
                      onClear: () => setState(() {
                        _range = _Range.all;
                        _from = null;
                        _to = null;
                      }),
                    ),
                    _FilterChip(
                      label: _amountLabel,
                      active: _min != null || _max != null,
                      onTap: _pickAmount,
                      onClear: () => setState(() {
                        _min = null;
                        _max = null;
                      }),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        filter.isActive
                            ? _summary(results.length, out, inn)
                            : 'Type something or pick a filter.',
                        style: TextStyle(fontSize: 13, color: c.subtext),
                      ),
                    ),
                    if (filter.isActive)
                      TextButton(
                        onPressed: _clearAll,
                        child: const Text('Clear all'),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: !filter.isActive
                    ? const SizedBox.shrink()
                    : results.isEmpty
                        ? const SingleChildScrollView(
                            child: EmptyState(
                              emoji: '🔎',
                              title: 'No matches',
                              message:
                                  'Try a shorter word, or remove a filter.',
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.only(bottom: 24),
                            itemCount: results.length,
                            separatorBuilder: (_, __) =>
                                Divider(height: 1, color: c.border),
                            itemBuilder: (_, i) => EntryTile(txn: results[i]),
                          ),
              ),
            ],
          );
        },
      ),
    );
  }

  String _summary(int count, int out, int inn) {
    final parts = <String>[count == 1 ? '1 entry' : '$count entries'];
    if (out > 0) parts.add('out ${store.fmt(out)}');
    if (inn > 0) parts.add('in ${store.fmt(inn)}');
    return parts.join(' · ');
  }
}

class _FilterChip extends StatelessWidget {
  const _FilterChip({
    required this.label,
    required this.active,
    required this.onTap,
    required this.onClear,
  });

  final String label;
  final bool active;
  final VoidCallback onTap;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: Container(
          padding: EdgeInsets.fromLTRB(14, 0, active ? 6 : 10, 0),
          decoration: BoxDecoration(
            color: active ? c.accent.withValues(alpha: 0.16) : c.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: active ? c.accent : c.border),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: active ? FontWeight.w700 : FontWeight.w500,
                  color: c.text,
                ),
              ),
              const SizedBox(width: 4),
              if (active)
                InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: onClear,
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Icon(Icons.close_rounded, size: 16, color: c.text),
                  ),
                )
              else
                Icon(Icons.expand_more_rounded, size: 18, color: c.subtext),
            ],
          ),
        ),
      ),
    );
  }
}

/// Two optional amounts. Leave one empty for "at least" or "at most".
class _AmountRangeDialog extends StatefulWidget {
  const _AmountRangeDialog({required this.min, required this.max});

  final int? min;
  final int? max;

  @override
  State<_AmountRangeDialog> createState() => _AmountRangeDialogState();
}

class _AmountRangeDialogState extends State<_AmountRangeDialog> {
  late final TextEditingController _lo;
  late final TextEditingController _hi;

  @override
  void initState() {
    super.initState();
    _lo = TextEditingController(
      text: widget.min == null ? '' : plainAmount(widget.min!),
    );
    _hi = TextEditingController(
      text: widget.max == null ? '' : plainAmount(widget.max!),
    );
  }

  @override
  void dispose() {
    _lo.dispose();
    _hi.dispose();
    super.dispose();
  }

  void _apply() {
    final lo = parseAmountMinor(_lo.text);
    final hi = parseAmountMinor(_hi.text);
    if (lo != null && hi != null && lo > hi) {
      showSnack(context, 'The first amount should be the smaller one');
      return;
    }
    Navigator.of(context).pop((lo, hi));
  }

  Widget _field(TextEditingController controller, String label) {
    return TextField(
      controller: controller,
      keyboardType: const TextInputType.numberWithOptions(decimal: true),
      inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]'))],
      decoration: pwInput(
        context,
        label: label,
        prefixText: '${store.currencySymbol} ',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Amount'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _field(_lo, 'At least'),
          const SizedBox(height: 12),
          _field(_hi, 'At most'),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(onPressed: _apply, child: const Text('Apply')),
      ],
    );
  }
}
