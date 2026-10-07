import 'package:flutter/material.dart';

import '../data/store.dart';
import '../screens/lock_screen.dart';
import '../services/app_lock.dart';

/// Wraps the whole app. While the lock is on, the app is hidden behind the
/// PIN screen: at launch, and after the app has been out of sight for longer
/// than the delay chosen in Settings.
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  late bool _locked = store.lockEnabled;
  DateTime? _leftAt;
  bool _authenticating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.addListener(_onStoreChanged);
    if (_locked) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _authenticate());
    }
  }

  @override
  void dispose() {
    store.removeListener(_onStoreChanged);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _onStoreChanged() {
    // The lock was turned off in Settings.
    if (_locked && !store.lockEnabled && mounted) {
      setState(() => _locked = false);
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _leftAt ??= DateTime.now();
      case AppLifecycleState.resumed:
        _onResume();
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _onResume() {
    final left = _leftAt;
    _leftAt = null;
    if (left == null || _locked || !store.lockEnabled) return;
    // The share sheet and the file picker take the app off screen on purpose.
    if (AppLock.consumeAwayAllowance()) return;
    final away = DateTime.now().difference(left).inSeconds;
    if (away >= store.lockDelaySeconds) {
      FocusManager.instance.primaryFocus?.unfocus();
      setState(() => _locked = true);
      _authenticate();
    }
  }

  Future<void> _authenticate({bool biometricOnly = true}) async {
    if (_authenticating || !_locked) return;
    _authenticating = true;
    final ok = await AppLock.authenticate(biometricOnly: biometricOnly);
    _authenticating = false;
    if (ok && mounted) setState(() => _locked = false);
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(offstage: _locked, child: widget.child),
        if (_locked)
          Positioned.fill(
            child: LockScreen(
              onUnlocked: () => setState(() => _locked = false),
              onDeviceAuth: ({required bool biometricOnly}) =>
                  _authenticate(biometricOnly: biometricOnly),
            ),
          ),
      ],
    );
  }
}
