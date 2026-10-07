import 'package:flutter/material.dart';

import '../data/models.dart';
import '../data/store.dart';
import '../theme.dart';
import '../widgets/common.dart';
import '../widgets/dialogs.dart';

class ManageCategoriesScreen extends StatelessWidget {
  const ManageCategoriesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Categories')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showCategoryDialog(context),
        backgroundColor: c.accent,
        foregroundColor: c.onAccent,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New category'),
      ),
      body: ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          final expense = store.categories.where((x) => !x.isIncome).toList();
          final income = store.categories.where((x) => x.isIncome).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 100),
            children: [
              _section(context, c, 'EXPENSE', expense),
              _section(context, c, 'INCOME', income),
            ],
          );
        },
      ),
    );
  }

  Widget _section(
    BuildContext context,
    AppColors c,
    String title,
    List<Category> items,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
          child: Text(
            title,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: c.subtext,
            ),
          ),
        ),
        SurfaceCard(
          padding: EdgeInsets.zero,
          child: Column(
            children: [
              for (var i = 0; i < items.length; i++) ...[
                if (i > 0) Divider(height: 1, color: c.border),
                ListTile(
                  leading: EmojiBadge(items[i].emoji, size: 38),
                  title: Text(items[i].name),
                  trailing: const Icon(Icons.edit_outlined, size: 20),
                  onTap: () => showCategoryDialog(context, edit: items[i]),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}
