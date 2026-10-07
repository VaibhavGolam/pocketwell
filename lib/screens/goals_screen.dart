import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../data/tips.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/charts.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

/// Savings goals, plus today's tip.
class GoalsScreen extends StatelessWidget {
  const GoalsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Goals')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showGoalSheet(context),
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        icon: const Icon(Icons.flag_rounded),
        label: const Text('New goal'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final goals = store.goals;
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
            children: [
              TipCard(tip: Tips.forDay(DateTime.now())),
              const SizedBox(height: 16),
              if (goals.isEmpty)
                const EmptyState(
                  emoji: '🎯',
                  title: 'No goals yet',
                  message:
                      'Pick something to save for, set an amount and a date, and Pocketwell works out a daily amount for you.',
                )
              else
                for (final g in goals) _GoalCard(goal: g),
            ],
          );
        },
      ),
    );
  }
}

class TipCard extends StatelessWidget {
  const TipCard({super.key, required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return SurfaceCard(
      color: c.accent.withValues(alpha: 0.10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 26)),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tip of the day',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    color: c.accent,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  tip,
                  style: TextStyle(fontSize: 15, height: 1.4, color: c.text),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _GoalCard extends StatelessWidget {
  const _GoalCard({required this.goal});

  final Goal goal;

  /// How much to save each day to hit the deadline. Null with no deadline.
  int? _perDay() {
    final remaining = goal.targetMinor - goal.savedMinor;
    final deadline = goal.deadline;
    if (remaining <= 0 || deadline == null) return null;
    final days = daysBetween(DateTime.now(), deadline);
    if (days < 0) return null;
    return (remaining / (days + 1)).ceil();
  }

  String? _hint(int? perDay) {
    final remaining = goal.targetMinor - goal.savedMinor;
    if (remaining <= 0) return 'Goal reached 🎉';
    final deadline = goal.deadline;
    if (deadline == null) return '${store.fmt(remaining)} to go';
    if (daysBetween(DateTime.now(), deadline) < 0) {
      return 'Deadline passed, ${store.fmt(remaining)} to go';
    }
    return 'Save ${store.fmt(perDay ?? remaining)} a day to reach it by ${formatDay(deadline)}';
  }

  Future<void> _addSavings(BuildContext context) async {
    final minor = await askAmount(context, title: 'Add to ${goal.name}');
    if (minor == null) return;
    await store.addToGoal(goal.id, minor);
  }

  Future<void> _delete(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Delete ${goal.name}?',
      message: 'This removes the goal and its progress.',
    );
    if (!ok) return;
    await store.deleteGoal(goal.id);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final progress = goal.targetMinor <= 0
        ? 0.0
        : (goal.savedMinor / goal.targetMinor).clamp(0.0, 1.0).toDouble();
    final percent = (progress * 100).round();
    final perDay = _perDay();
    final hint = _hint(perDay);
    final reached = goal.savedMinor >= goal.targetMinor;

    return SurfaceCard(
      margin: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SizedBox(
                width: 76,
                height: 76,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    CustomPaint(
                      size: const Size(76, 76),
                      painter: RingPainter(
                        progress: progress,
                        color: reached ? c.moneyIn : c.accent,
                        trackColor: c.border,
                      ),
                    ),
                    Text(
                      '$percent%',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w800,
                        color: c.text,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${goal.emoji} ${goal.name}',
                      style: TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w700,
                        color: c.text,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${store.fmt(goal.savedMinor)} of ${store.fmt(goal.targetMinor)}',
                      style: TextStyle(fontSize: 14, color: c.subtext),
                    ),
                  ],
                ),
              ),
              PopupMenuButton<String>(
                onSelected: (v) async {
                  if (v == 'edit') {
                    await showGoalSheet(context, edit: goal);
                  } else if (v == 'delete') {
                    await _delete(context);
                  }
                },
                itemBuilder: (_) => const [
                  PopupMenuItem<String>(value: 'edit', child: Text('Edit goal')),
                  PopupMenuItem<String>(value: 'delete', child: Text('Delete goal')),
                ],
              ),
            ],
          ),
          if (hint != null) ...[
            const SizedBox(height: 12),
            Text(hint, style: TextStyle(fontSize: 14, height: 1.4, color: c.text)),
          ],
          if (!reached) ...[
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  onPressed: () => _addSavings(context),
                  icon: const Icon(Icons.add_rounded, size: 18),
                  label: const Text('Add savings'),
                ),
                if (perDay != null)
                  OutlinedButton(
                    onPressed: () => store.addToGoal(goal.id, perDay),
                    child: Text('Add ${store.fmt(perDay)} for today'),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- goal sheet

Future<void> showGoalSheet(BuildContext context, {Goal? edit}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _GoalSheet(edit: edit),
  );
}

class _GoalSheet extends StatefulWidget {
  const _GoalSheet({required this.edit});

  final Goal? edit;

  @override
  State<_GoalSheet> createState() => _GoalSheetState();
}

class _GoalSheetState extends State<_GoalSheet> {
  late final TextEditingController _name;
  late final TextEditingController _target;
  late final TextEditingController _saved;
  late String _emoji;
  DateTime? _deadline;

  @override
  void initState() {
    super.initState();
    final g = widget.edit;
    _name = TextEditingController(text: g?.name ?? '');
    _target = TextEditingController(
      text: g == null ? '' : plainAmount(g.targetMinor),
    );
    _saved = TextEditingController(
      text: (g == null || g.savedMinor == 0) ? '' : plainAmount(g.savedMinor),
    );
    _emoji = g?.emoji ?? '🎯';
    _deadline = g?.deadline;
  }

  @override
  void dispose() {
    _name.dispose();
    _target.dispose();
    _saved.dispose();
    super.dispose();
  }

  Future<void> _pickDeadline() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _deadline ?? today.add(const Duration(days: 30)),
      firstDate: DateTime(today.year, today.month, today.day),
      lastDate: DateTime(today.year + 20, 12, 31),
    );
    if (picked != null) setState(() => _deadline = picked);
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    final target = parseAmountMinor(_target.text);
    if (name.isEmpty) {
      showSnack(context, 'Give the goal a name');
      return;
    }
    if (target == null) {
      showSnack(context, 'Enter a target amount');
      return;
    }
    final saved = parseAmountMinor(_saved.text) ?? 0;
    final g = widget.edit;
    if (g == null) {
      await store.addGoal(
        name: name,
        emoji: _emoji,
        targetMinor: target,
        savedMinor: saved,
        deadline: _deadline,
      );
    } else {
      await store.updateGoal(
        g.id,
        name: name,
        emoji: _emoji,
        targetMinor: target,
        savedMinor: saved,
        deadline: _deadline,
      );
    }
    if (!mounted) return;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final editing = widget.edit != null;
    final amountFormatters = [
      FilteringTextInputFormatter.allow(RegExp(r'[0-9.,]')),
    ];

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
              editing ? 'Edit goal' : 'New goal',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: c.text,
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _name,
              autofocus: !editing,
              textCapitalization: TextCapitalization.sentences,
              decoration: pwInput(context, label: 'What are you saving for?'),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _target,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: amountFormatters,
              decoration: pwInput(
                context,
                label: 'Target amount',
                prefixText: '${store.currencySymbol} ',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _saved,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              inputFormatters: amountFormatters,
              decoration: pwInput(
                context,
                label: 'Already saved (optional)',
                prefixText: '${store.currencySymbol} ',
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                OutlinedButton.icon(
                  onPressed: _pickDeadline,
                  icon: const Icon(Icons.event_rounded, size: 18),
                  label: Text(
                    _deadline == null
                        ? 'Deadline (optional)'
                        : 'By ${formatDayYear(_deadline!)}',
                  ),
                ),
                if (_deadline != null)
                  IconButton(
                    tooltip: 'Clear deadline',
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => setState(() => _deadline = null),
                  ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              'Icon',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: c.subtext,
              ),
            ),
            const SizedBox(height: 8),
            EmojiPicker(
              selected: _emoji,
              onChanged: (e) => setState(() => _emoji = e),
            ),
            const SizedBox(height: 18),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(editing ? 'Save changes' : 'Create goal'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
