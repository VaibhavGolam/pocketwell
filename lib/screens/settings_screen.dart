import 'package:flutter/material.dart';

import '../data/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import 'manage_categories_screen.dart';

const List<(String, String)> kCurrencies = [
  ('₹', 'Indian rupee'),
  ('\$', 'US dollar'),
  ('€', 'Euro'),
  ('£', 'British pound'),
  ('¥', 'Yen or yuan'),
  ('AED', 'UAE dirham'),
];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  Future<void> _erase(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Erase all data?',
      message:
          'Every entry, person and goal on this phone will be deleted. Categories go back to the defaults. This cannot be undone.',
      confirmLabel: 'Erase',
    );
    if (!ok) return;
    await store.resetAll();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);

    Widget sectionLabel(String text) => Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            text,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.subtext,
            ),
          ),
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          sectionLabel('APPEARANCE'),
          SurfaceCard(
            child: ValueListenableBuilder<ThemeMode>(
              valueListenable: store.themeMode,
              builder: (context, mode, _) {
                return SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<ThemeMode>(
                    segments: const [
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.system,
                        label: Text('System'),
                        icon: Icon(Icons.brightness_auto_rounded),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.light,
                        label: Text('Light'),
                        icon: Icon(Icons.light_mode_rounded),
                      ),
                      ButtonSegment<ThemeMode>(
                        value: ThemeMode.dark,
                        label: Text('Dark'),
                        icon: Icon(Icons.dark_mode_rounded),
                      ),
                    ],
                    selected: {mode},
                    showSelectedIcon: false,
                    onSelectionChanged: (s) => store.setThemeMode(s.first),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 4, 0),
            child: Text(
              'System follows your phone, including when it switches to dark at night.',
              style: TextStyle(fontSize: 12, height: 1.4, color: c.subtext),
            ),
          ),
          sectionLabel('MONEY'),
          SurfaceCard(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
            child: ListenableBuilder(
              listenable: store,
              builder: (context, _) {
                return DropdownButton<String>(
                  value: store.currencySymbol,
                  isExpanded: true,
                  underline: const SizedBox.shrink(),
                  items: [
                    for (final cur in kCurrencies)
                      DropdownMenuItem<String>(
                        value: cur.$1,
                        child: Text('${cur.$1}   ${cur.$2}'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) store.setCurrency(v);
                  },
                );
              },
            ),
          ),
          const SizedBox(height: 10),
          SurfaceCard(
            padding: EdgeInsets.zero,
            onTap: () {
              Navigator.of(context).push(
                MaterialPageRoute<void>(
                  builder: (_) => const ManageCategoriesScreen(),
                ),
              );
            },
            child: const ListTile(
              leading: Icon(Icons.category_outlined),
              title: Text('Categories'),
              subtitle: Text('Rename, add or remove'),
              trailing: Icon(Icons.chevron_right_rounded),
            ),
          ),
          sectionLabel('YOUR DATA'),
          SurfaceCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Everything stays on this phone. Pocketwell has no account and sends nothing to a server.',
                  style: TextStyle(fontSize: 14, height: 1.4, color: c.text),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _erase(context),
                  icon: Icon(Icons.delete_outline_rounded, color: c.moneyOut),
                  label: Text('Erase all data', style: TextStyle(color: c.moneyOut)),
                ),
              ],
            ),
          ),
          sectionLabel('ABOUT'),
          SurfaceCard(
            child: Text(
              'Pocketwell 1.0.0\nMade by ST Media',
              style: TextStyle(fontSize: 14, height: 1.5, color: c.subtext),
            ),
          ),
        ],
      ),
    );
  }
}
