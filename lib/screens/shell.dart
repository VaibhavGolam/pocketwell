import 'package:flutter/material.dart';

import '../data/store.dart';
import '../data/tips.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'goals_screen.dart';
import 'home_screen.dart';
import 'people_screen.dart';

/// Three tabs: Home, People, Goals.
class Shell extends StatefulWidget {
  const Shell({super.key});

  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> with WidgetsBindingObserver {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _showRecurringNotice();
      _maybeShowTip();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Repeating entries that came due while the app was closed, or while it
  /// sat in the background past midnight, are added when the app comes back.
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      store.processRecurring().then((_) => _showRecurringNotice());
    }
  }

  void _showRecurringNotice() {
    final message = store.takeRecurringNotice();
    if (message != null && mounted) showSnack(context, message);
  }

  /// Shows the tip of the day once per calendar day, on the first open.
  Future<void> _maybeShowTip() async {
    if (!mounted || !store.shouldShowTipToday) return;
    await store.markTipShown();
    if (!mounted) return;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (_) => _TipSheet(tip: Tips.forDay(DateTime.now())),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: const [
          HomeScreen(),
          PeopleScreen(),
          GoalsScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.people_outline_rounded),
            selectedIcon: Icon(Icons.people_alt_rounded),
            label: 'People',
          ),
          NavigationDestination(
            icon: Icon(Icons.flag_outlined),
            selectedIcon: Icon(Icons.flag_rounded),
            label: 'Goals',
          ),
        ],
      ),
    );
  }
}

class _TipSheet extends StatelessWidget {
  const _TipSheet({required this.tip});

  final String tip;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('💡', style: TextStyle(fontSize: 32)),
          const SizedBox(height: 8),
          Text(
            'Tip of the day',
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.accent,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            tip,
            style: TextStyle(
              fontSize: 18,
              height: 1.4,
              fontWeight: FontWeight.w600,
              color: c.text,
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Got it'),
            ),
          ),
        ],
      ),
    );
  }
}
