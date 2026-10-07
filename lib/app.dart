import 'package:flutter/material.dart';

import 'data/store.dart';
import 'screens/shell.dart';
import 'theme.dart';

class PocketwellApp extends StatelessWidget {
  const PocketwellApp({super.key});

  @override
  Widget build(BuildContext context) {
    // ThemeMode.system follows the phone automatically, including the switch
    // at sunset. Picking Light or Dark in Settings overrides it, and picking
    // System hands control back to the phone.
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: store.themeMode,
      builder: (context, mode, _) {
        return MaterialApp(
          title: 'Pocketwell',
          debugShowCheckedModeBanner: false,
          theme: lightTheme,
          darkTheme: darkTheme,
          themeMode: mode,
          home: const Shell(),
        );
      },
    );
  }
}
