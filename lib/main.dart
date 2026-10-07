import 'package:flutter/material.dart';

import 'app.dart';
import 'data/store.dart';
import 'services/notifier.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Notifier.init();
  await store.init();
  runApp(const PocketwellApp());
}
