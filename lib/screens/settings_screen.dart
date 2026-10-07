import 'package:flutter/material.dart';

import '../data/backup.dart';
import '../data/store.dart';
import '../services/files.dart';
import '../theme.dart';
import '../util/format.dart';
import '../widgets/common.dart';
import 'budgets_screen.dart';
import 'lock_screen.dart';
import 'manage_categories_screen.dart';
import 'recurring_screen.dart';

const List<(String, String)> kCurrencies = [
  ('₹', 'Indian rupee'),
  ('\$', 'US dollar'),
  ('€', 'Euro'),
  ('£', 'British pound'),
  ('¥', 'Yen or yuan'),
  ('AED', 'UAE dirham'),
];

const List<(int, String)> kLockDelays = [
  (0, 'Right away'),
  (30, '30 seconds'),
  (60, '1 minute'),
  (300, '5 minutes'),
];

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  void _push(BuildContext context, Widget screen) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => screen));
  }

  // ------------------------------------------------------------------- lock

  Future<void> _toggleLock(BuildContext context, bool on) async {
    if (on) {
      final done = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const PinSetupScreen(flow: PinFlow.create),
        ),
      );
      if (done == true && context.mounted) {
        showSnack(context, 'App lock is on');
      }
    } else {
      final ok = await Navigator.of(context).push<bool>(
        MaterialPageRoute<bool>(
          builder: (_) => const PinSetupScreen(flow: PinFlow.verify),
        ),
      );
      if (ok == true) {
        await store.disableLock();
        if (context.mounted) showSnack(context, 'App lock is off');
      }
    }
  }

  Future<void> _changePin(BuildContext context) async {
    final done = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (_) => const PinSetupScreen(flow: PinFlow.change),
      ),
    );
    if (done == true && context.mounted) showSnack(context, 'PIN changed');
  }

  // ------------------------------------------------------- backup and export

  Future<void> _backup(BuildContext context) async {
    try {
      final json = await store.exportBackupJson();
      if (!context.mounted) return;
      await FileService.shareText(
        context,
        fileName: 'pocketwell-backup-${isoDate(DateTime.now())}.json',
        content: json,
        mimeType: 'application/json',
        subject: 'Pocketwell backup',
      );
      await store.markBackupDone();
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not create the backup');
    }
  }

  Future<void> _restore(BuildContext context) async {
    String? text;
    try {
      text = await FileService.pickText();
    } on FormatException {
      if (context.mounted) {
        showSnack(context, 'That file could not be read as a backup');
      }
      return;
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not open that file');
      return;
    }
    if (text == null) return;

    BackupData data;
    try {
      data = Backup.parse(text);
    } on FormatException catch (e) {
      if (context.mounted) showSnack(context, e.message);
      return;
    }
    if (!context.mounted) return;

    final when = data.exported == null
        ? ''
        : ' from ${formatDayYear(data.exported!)}';
    final ok = await confirmDialog(
      context,
      title: 'Replace everything with this backup?',
      message:
          'The backup$when has ${data.count('txns')} entries, ${data.count('people')} people and ${data.count('goals')} goals. Everything now in the app will be replaced. Back up first if you are not sure.',
      confirmLabel: 'Restore',
    );
    if (!ok) return;

    try {
      await store.importBackup(data);
    } catch (_) {
      if (context.mounted) {
        showSnack(context, 'Restore failed. Your current data was not changed.');
      }
      return;
    }
    if (context.mounted) showSnack(context, 'Backup restored');
  }

  Future<void> _exportCsv(
    BuildContext context, {
    required String name,
    required String Function() build,
  }) async {
    try {
      await FileService.shareText(
        context,
        fileName: '$name-${isoDate(DateTime.now())}.csv',
        content: build(),
        mimeType: 'text/csv',
        subject: 'Pocketwell $name',
      );
    } catch (_) {
      if (context.mounted) showSnack(context, 'Could not create the file');
    }
  }

  Future<void> _erase(BuildContext context) async {
    final ok = await confirmDialog(
      context,
      title: 'Erase all data?',
      message:
          'Every entry, person, goal, budget and repeating entry on this phone will be deleted. Categories go back to the defaults. This cannot be undone.',
      confirmLabel: 'Erase',
    );
    if (!ok) return;
    await store.resetAll();
    if (!context.mounted) return;
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  // ------------------------------------------------------------------ build

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

    Widget navTile({
      required IconData icon,
      required String title,
      required String subtitle,
      required VoidCallback onTap,
    }) =>
        ListTile(
          leading: Icon(icon),
          title: Text(title),
          subtitle: Text(subtitle),
          trailing: const Icon(Icons.chevron_right_rounded),
          onTap: onTap,
        );

    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final last = store.lastBackup;
          return ListView(
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
                child: DropdownButton<String>(
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
                ),
              ),
              const SizedBox(height: 10),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    navTile(
                      icon: Icons.track_changes_rounded,
                      title: 'Budgets',
                      subtitle: store.budgets.isEmpty
                          ? 'Set a monthly limit per category'
                          : '${store.budgets.length} with a limit',
                      onTap: () => _push(context, const BudgetsScreen()),
                    ),
                    Divider(height: 1, color: c.border),
                    navTile(
                      icon: Icons.repeat_rounded,
                      title: 'Repeating entries',
                      subtitle: store.recurring.isEmpty
                          ? 'Rent, salary, subscriptions'
                          : '${store.recurring.length} set up',
                      onTap: () => _push(context, const RecurringScreen()),
                    ),
                    Divider(height: 1, color: c.border),
                    navTile(
                      icon: Icons.category_outlined,
                      title: 'Categories',
                      subtitle: 'Rename, add or remove',
                      onTap: () =>
                          _push(context, const ManageCategoriesScreen()),
                    ),
                  ],
                ),
              ),
              sectionLabel('SECURITY'),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    SwitchListTile(
                      secondary: const Icon(Icons.lock_outline_rounded),
                      title: const Text('App lock'),
                      subtitle: const Text(
                        'Ask for a PIN or fingerprint to open the app',
                      ),
                      value: store.lockEnabled,
                      onChanged: (v) => _toggleLock(context, v),
                    ),
                    if (store.lockEnabled) ...[
                      Divider(height: 1, color: c.border),
                      ListTile(
                        leading: const Icon(Icons.pin_outlined),
                        title: const Text('Change PIN'),
                        trailing: const Icon(Icons.chevron_right_rounded),
                        onTap: () => _changePin(context),
                      ),
                      Divider(height: 1, color: c.border),
                      ListTile(
                        leading: const Icon(Icons.timer_outlined),
                        title: const Text('Lock after'),
                        subtitle: const Text('Time away from the app'),
                        trailing: DropdownButton<int>(
                          value: kLockDelays.any(
                                  (d) => d.$1 == store.lockDelaySeconds)
                              ? store.lockDelaySeconds
                              : 60,
                          underline: const SizedBox.shrink(),
                          items: [
                            for (final d in kLockDelays)
                              DropdownMenuItem<int>(
                                value: d.$1,
                                child: Text(d.$2),
                              ),
                          ],
                          onChanged: (v) {
                            if (v != null) store.setLockDelay(v);
                          },
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              sectionLabel('YOUR DATA'),
              SurfaceCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    navTile(
                      icon: Icons.upload_file_rounded,
                      title: 'Back up',
                      subtitle: last == null
                          ? 'Save a copy to Drive, Files or WhatsApp'
                          : 'Last exported ${formatDayYear(last)}',
                      onTap: () => _backup(context),
                    ),
                    Divider(height: 1, color: c.border),
                    navTile(
                      icon: Icons.download_rounded,
                      title: 'Restore from a backup',
                      subtitle: 'Replaces what is in the app now',
                      onTap: () => _restore(context),
                    ),
                    Divider(height: 1, color: c.border),
                    navTile(
                      icon: Icons.table_chart_outlined,
                      title: 'Export entries as CSV',
                      subtitle: 'For Excel or Google Sheets',
                      onTap: () => _exportCsv(
                        context,
                        name: 'pocketwell-entries',
                        build: store.entriesCsv,
                      ),
                    ),
                    Divider(height: 1, color: c.border),
                    navTile(
                      icon: Icons.people_outline_rounded,
                      title: 'Export udhaar as CSV',
                      subtitle: 'Every line for every person',
                      onTap: () => _exportCsv(
                        context,
                        name: 'pocketwell-udhaar',
                        build: store.udhaarCsv,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SurfaceCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Everything stays on this phone. Pocketwell has no account and sends nothing to a server. If you lose or reset the phone, a backup is the only way to get your data back.',
                      style: TextStyle(fontSize: 14, height: 1.4, color: c.text),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: () => _erase(context),
                      icon: Icon(Icons.delete_outline_rounded, color: c.moneyOut),
                      label: Text(
                        'Erase all data',
                        style: TextStyle(color: c.moneyOut),
                      ),
                    ),
                  ],
                ),
              ),
              sectionLabel('ABOUT'),
              SurfaceCard(
                child: Text(
                  'Pocketwell 1.1.0\nMade by ST Media',
                  style: TextStyle(fontSize: 14, height: 1.5, color: c.subtext),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
