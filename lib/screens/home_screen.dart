import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/budget_row.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/entry_tile.dart';
import 'add_entry_screen.dart';
import 'budgets_screen.dart';
import 'category_entries_screen.dart';
import 'search_screen.dart';
import 'settings_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  DateTime _month = monthStart(DateTime.now());

  bool get _isCurrentMonth {
    final now = DateTime.now();
    return _month.year == now.year && _month.month == now.month;
  }

  void _shift(int delta) => setState(() => _month = addMonths(_month, delta));

  void _openAdd() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const AddEntryScreen()),
    );
  }

  void _openSearch() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SearchScreen()),
    );
  }

  void _openBudgets() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const BudgetsScreen()),
    );
  }

  void _openSettings() {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pocketwell'),
        actions: [
          IconButton(
            tooltip: 'Search',
            icon: const Icon(Icons.search_rounded),
            onPressed: _openSearch,
          ),
          IconButton(
            tooltip: 'Settings',
            icon: const Icon(Icons.settings_outlined),
            onPressed: _openSettings,
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _openAdd,
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('Add'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final monthTxns = store.txnsInMonth(_month);
          final totalIn = store.totalIn(_month);
          final totalOut = store.totalOut(_month);
          final prevOut = store.totalOut(addMonths(_month, -1));
          final byCategory = store.spendingByCategory(_month);

          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              _monthRow(c),
              const SizedBox(height: 8),
              _summaryCard(c, totalIn, totalOut),
              _comparison(c, totalOut, prevOut),
              const SizedBox(height: 12),
              _budgetCard(c),
              const SizedBox(height: 12),
              if (byCategory.isNotEmpty) ...[
                _spendingCard(c, byCategory, totalOut),
                const SizedBox(height: 12),
                _dailyCard(c),
                const SizedBox(height: 12),
              ],
              _entries(c, monthTxns),
            ],
          );
        },
      ),
    );
  }

  Widget _monthRow(AppColors c) {
    return Row(
      children: [
        IconButton(
          icon: const Icon(Icons.chevron_left_rounded),
          onPressed: () => _shift(-1),
        ),
        Expanded(
          child: Text(
            '${kMonthNames[_month.month - 1]} ${_month.year}',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
        ),
        IconButton(
          icon: const Icon(Icons.chevron_right_rounded),
          onPressed: _isCurrentMonth ? null : () => _shift(1),
        ),
      ],
    );
  }

  Widget _summaryCard(AppColors c, int totalIn, int totalOut) {
    final left = totalIn - totalOut;
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Left this month',
            style: TextStyle(fontSize: 13, color: c.subtext),
          ),
          const SizedBox(height: 4),
          Text(
            store.fmt(left),
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w800,
              color: left < 0 ? c.moneyOut : c.text,
            ),
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: _miniStat(
                  c,
                  'Money in',
                  totalIn == 0 ? store.fmt(0) : '+${store.fmt(totalIn)}',
                  c.moneyIn,
                ),
              ),
              Expanded(
                child: _miniStat(
                  c,
                  'Money out',
                  totalOut == 0 ? store.fmt(0) : '-${store.fmt(totalOut)}',
                  c.moneyOut,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _miniStat(AppColors c, String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: TextStyle(fontSize: 13, color: c.subtext)),
        const SizedBox(height: 2),
        Text(
          value,
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: color,
          ),
        ),
      ],
    );
  }

  Widget _comparison(AppColors c, int totalOut, int prevOut) {
    if (prevOut == 0) return const SizedBox.shrink();
    final prevName = kMonthNames[addMonths(_month, -1).month - 1];
    final diff = totalOut - prevOut;
    final String text;
    Color color = c.subtext;
    if (diff == 0) {
      text = 'Same spending as $prevName.';
    } else if (diff < 0) {
      text = 'You spent ${store.fmt(-diff)} less than $prevName.';
      color = c.moneyIn;
    } else {
      text = 'You spent ${store.fmt(diff)} more than $prevName.';
      color = c.moneyOut;
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 12, 4, 0),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }

  /// Budget progress for the month on screen. Without any budgets it is a
  /// small prompt to set one.
  Widget _budgetCard(AppColors c) {
    final items = <(Category, Budget, int)>[];
    for (final b in store.budgets) {
      final cat = store.categoryById(b.categoryId);
      if (cat == null) continue;
      items.add((cat, b, store.spentIn(_month, b.categoryId)));
    }

    if (items.isEmpty) {
      return SurfaceCard(
        onTap: _openBudgets,
        child: Row(
          children: [
            const Text('🎯', style: TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Set a monthly budget',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                      color: c.text,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    'Pick a limit for food, fuel or anything else. You get a warning at 80%.',
                    style: TextStyle(fontSize: 13, height: 1.4, color: c.subtext),
                  ),
                ],
              ),
            ),
            Icon(Icons.chevron_right_rounded, color: c.subtext),
          ],
        ),
      );
    }

    items.sort((a, b) {
      final ra = a.$3 / a.$2.limitMinor;
      final rb = b.$3 / b.$2.limitMinor;
      return rb.compareTo(ra);
    });
    final over = items
        .where((i) => budgetLevel(i.$3, i.$2.limitMinor) == BudgetLevel.over)
        .length;
    final close = items
        .where((i) => budgetLevel(i.$3, i.$2.limitMinor) == BudgetLevel.close)
        .length;
    final shown = items.take(4).toList();

    String? status;
    Color statusColor = c.subtext;
    if (over > 0) {
      status = over == 1 ? '1 over budget' : '$over over budget';
      statusColor = c.moneyOut;
    } else if (close > 0) {
      status = close == 1 ? '1 close to its limit' : '$close close to their limit';
      statusColor = c.warn;
    }

    return SurfaceCard(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Budgets',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
              ),
              if (status != null)
                Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: Text(
                    status,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      color: statusColor,
                    ),
                  ),
                ),
              TextButton(onPressed: _openBudgets, child: const Text('Manage')),
            ],
          ),
          for (final i in shown)
            BudgetRow(
              category: i.$1,
              limitMinor: i.$2.limitMinor,
              spentMinor: i.$3,
              onTap: _openBudgets,
            ),
          if (items.length > shown.length)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Text(
                '+${items.length - shown.length} more',
                style: TextStyle(fontSize: 13, color: c.subtext),
              ),
            ),
        ],
      ),
    );
  }

  Widget _spendingCard(AppColors c, List<CategoryTotal> cats, int totalOut) {
    final values = cats.map((e) => e.total.toDouble()).toList();
    final colors = List<Color>.generate(
      cats.length,
      (i) => kChartColors[i % kChartColors.length],
    );
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Where it went',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(height: 16),
          Center(
            child: SizedBox(
              width: 190,
              height: 190,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  CustomPaint(
                    size: const Size(190, 190),
                    painter: DonutPainter(
                      values: values,
                      colors: colors,
                      trackColor: c.border,
                    ),
                  ),
                  SizedBox(
                    width: 110,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Spent',
                          style: TextStyle(fontSize: 13, color: c.subtext),
                        ),
                        FittedBox(
                          fit: BoxFit.scaleDown,
                          child: Text(
                            store.fmt(totalOut),
                            style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w800,
                              color: c.text,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),
          for (var i = 0; i < cats.length; i++)
            _legendRow(c, cats[i], colors[i], totalOut),
        ],
      ),
    );
  }

  Widget _legendRow(AppColors c, CategoryTotal item, Color color, int totalOut) {
    final category = store.categoryById(item.categoryId);
    final emoji = category?.emoji ?? '🧾';
    final name = category?.name ?? 'Other';
    final percent = totalOut == 0 ? 0 : (item.total / totalOut * 100).round();
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute<void>(
            builder: (_) => CategoryEntriesScreen(
              month: _month,
              categoryId: item.categoryId,
            ),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
        child: Row(
          children: [
            Container(
              width: 10,
              height: 10,
              decoration: BoxDecoration(color: color, shape: BoxShape.circle),
            ),
            const SizedBox(width: 10),
            Text(emoji, style: const TextStyle(fontSize: 18)),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                name,
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: c.text,
                ),
              ),
            ),
            Text(
              store.fmt(item.total),
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
            SizedBox(
              width: 44,
              child: Text(
                '$percent%',
                textAlign: TextAlign.right,
                style: TextStyle(fontSize: 13, color: c.subtext),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _dailyCard(AppColors c) {
    final days = store.dailySpending(_month);
    return SurfaceCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Day by day',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
          const SizedBox(height: 16),
          DailyBars(
            days: days,
            barColor: c.accent,
            emptyColor: c.border,
          ),
          const SizedBox(height: 6),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('1', style: TextStyle(fontSize: 12, color: c.subtext)),
              Text(
                '${days.length}',
                style: TextStyle(fontSize: 12, color: c.subtext),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _entries(AppColors c, List<Txn> txns) {
    if (txns.isEmpty) {
      return const EmptyState(
        emoji: '🌱',
        title: 'Nothing logged yet',
        message: 'Tap Add to record your first expense or income for this month.',
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
          child: Text(
            'Entries',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: c.text,
            ),
          ),
        ),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < txns.length; i++) ...[
                if (i > 0) Divider(height: 1, color: c.border),
                EntryTile(txn: txns[i]),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
