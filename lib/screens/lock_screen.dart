import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../data/store.dart';
import '../services/app_lock.dart';
import '../theme.dart';

const int kPinLength = 4;

/// Four dots that fill in as digits are typed.
class PinDots extends StatelessWidget {
  const PinDots({super.key, required this.filled, this.error = false});

  final int filled;
  final bool error;

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < kPinLength; i++)
          Container(
            width: 16,
            height: 16,
            margin: const EdgeInsets.symmetric(horizontal: 9),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: i < filled
                  ? (error ? c.moneyOut : c.accent)
                  : Colors.transparent,
              border: Border.all(
                color: error ? c.moneyOut : (i < filled ? c.accent : c.subtext),
                width: 2,
              ),
            ),
          ),
      ],
    );
  }
}

/// A number pad. The screen that uses it keeps track of what was typed.
class PinPad extends StatelessWidget {
  const PinPad({
    super.key,
    required this.onDigit,
    required this.onBackspace,
    this.enabled = true,
  });

  final ValueChanged<String> onDigit;
  final VoidCallback onBackspace;
  final bool enabled;

  Widget _key(BuildContext context, Widget child, VoidCallback? onTap) {
    final c = AppColors.of(context);
    return Padding(
      padding: const EdgeInsets.all(6),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Material(
          color: onTap == null ? Colors.transparent : c.card,
          shape: CircleBorder(
            side: BorderSide(color: onTap == null ? Colors.transparent : c.border),
          ),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: enabled ? onTap : null,
            child: Center(child: child),
          ),
        ),
      ),
    );
  }

  Widget _digit(BuildContext context, String d) {
    final c = AppColors.of(context);
    return _key(
      context,
      Text(
        d,
        style: TextStyle(
          fontSize: 26,
          fontWeight: FontWeight.w600,
          color: enabled ? c.text : c.subtext,
        ),
      ),
      () => onDigit(d),
    );
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    Widget row(List<Widget> children) => Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: children,
        );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        row([for (final d in ['1', '2', '3']) _digit(context, d)]),
        row([for (final d in ['4', '5', '6']) _digit(context, d)]),
        row([for (final d in ['7', '8', '9']) _digit(context, d)]),
        row([
          _key(context, const SizedBox.shrink(), null),
          _digit(context, '0'),
          _key(
            context,
            Icon(Icons.backspace_outlined, color: c.text),
            onBackspace,
          ),
        ]),
      ],
    );
  }
}

// ---------------------------------------------------------------- lock screen

/// Shown over the whole app while it is locked.
class LockScreen extends StatefulWidget {
  const LockScreen({
    super.key,
    required this.onUnlocked,
    required this.onDeviceAuth,
  });

  final VoidCallback onUnlocked;

  /// Asks the phone for fingerprint (true) or its screen lock too (false).
  final Future<void> Function({required bool biometricOnly}) onDeviceAuth;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  String _pin = '';
  bool _wrong = false;
  int _wrongCount = 0;
  DateTime? _blockedUntil;
  Timer? _timer;
  bool _hasBiometrics = false;
  bool _deviceSupported = false;

  @override
  void initState() {
    super.initState();
    AppLock.hasBiometrics().then((v) {
      if (mounted) setState(() => _hasBiometrics = v);
    });
    AppLock.isDeviceSupported().then((v) {
      if (mounted) setState(() => _deviceSupported = v);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool get _blocked {
    final until = _blockedUntil;
    return until != null && DateTime.now().isBefore(until);
  }

  int get _secondsLeft {
    final until = _blockedUntil;
    if (until == null) return 0;
    final ms = until.difference(DateTime.now()).inMilliseconds;
    return ms <= 0 ? 0 : (ms / 1000).ceil();
  }

  void _digit(String d) {
    if (_blocked || _pin.length >= kPinLength) return;
    setState(() {
      _pin += d;
      _wrong = false;
    });
    if (_pin.length == kPinLength) _check();
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _wrong = false;
    });
  }

  Future<void> _check() async {
    if (store.checkPin(_pin)) {
      widget.onUnlocked();
      return;
    }
    HapticFeedback.heavyImpact();
    setState(() {
      _wrong = true;
      _wrongCount++;
    });
    if (_wrongCount >= 5) {
      _blockedUntil = DateTime.now().add(const Duration(seconds: 30));
      _timer?.cancel();
      _timer = Timer.periodic(const Duration(seconds: 1), (t) {
        if (!mounted) return;
        if (!_blocked) {
          t.cancel();
          setState(() {
            _wrongCount = 0;
            _wrong = false;
          });
        } else {
          setState(() {});
        }
      });
    }
    await Future<void>.delayed(const Duration(milliseconds: 450));
    if (!mounted) return;
    setState(() => _pin = '');
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final String message;
    if (_blocked) {
      message = 'Too many tries. Wait $_secondsLeft s.';
    } else if (_wrong) {
      message = 'Wrong PIN';
    } else {
      message = 'Enter your PIN';
    }

    return Scaffold(
      backgroundColor: c.bg,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('🔒', style: TextStyle(fontSize: 40)),
                const SizedBox(height: 10),
                Text(
                  'Pocketwell',
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  message,
                  style: TextStyle(
                    fontSize: 14,
                    color: (_wrong || _blocked) ? c.moneyOut : c.subtext,
                  ),
                ),
                const SizedBox(height: 22),
                PinDots(filled: _pin.length, error: _wrong),
                const SizedBox(height: 26),
                PinPad(
                  onDigit: _digit,
                  onBackspace: _backspace,
                  enabled: !_blocked,
                ),
                const SizedBox(height: 10),
                if (_hasBiometrics)
                  TextButton.icon(
                    onPressed: () => widget.onDeviceAuth(biometricOnly: true),
                    icon: const Icon(Icons.fingerprint_rounded),
                    label: const Text('Use fingerprint'),
                  ),
                if (_deviceSupported)
                  TextButton(
                    onPressed: () => widget.onDeviceAuth(biometricOnly: false),
                    child: const Text('Forgot PIN? Use phone lock'),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------ PIN setup

enum PinFlow {
  /// Choose a PIN for the first time.
  create,

  /// Check the current PIN, then choose a new one.
  change,

  /// Only check the current PIN (used before turning the lock off).
  verify,
}

/// Pops with true when the flow finished.
class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key, required this.flow});

  final PinFlow flow;

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

enum _Stage { current, choose, confirm }

class _PinSetupScreenState extends State<PinSetupScreen> {
  late _Stage _stage;
  String _pin = '';
  String _first = '';
  String? _error;
  bool _deviceSupported = true;

  @override
  void initState() {
    super.initState();
    _stage = widget.flow == PinFlow.create ? _Stage.choose : _Stage.current;
    AppLock.isDeviceSupported().then((v) {
      if (mounted) setState(() => _deviceSupported = v);
    });
  }

  String get _title {
    switch (_stage) {
      case _Stage.current:
        return 'Enter your current PIN';
      case _Stage.choose:
        return 'Choose a $kPinLength digit PIN';
      case _Stage.confirm:
        return 'Enter it again';
    }
  }

  void _digit(String d) {
    if (_pin.length >= kPinLength) return;
    setState(() {
      _pin += d;
      _error = null;
    });
    if (_pin.length == kPinLength) _complete();
  }

  void _backspace() {
    if (_pin.isEmpty) return;
    setState(() {
      _pin = _pin.substring(0, _pin.length - 1);
      _error = null;
    });
  }

  Future<void> _complete() async {
    final entered = _pin;
    await Future<void>.delayed(const Duration(milliseconds: 150));
    if (!mounted) return;

    switch (_stage) {
      case _Stage.current:
        if (!store.checkPin(entered)) {
          HapticFeedback.heavyImpact();
          setState(() {
            _pin = '';
            _error = 'Wrong PIN. Try again.';
          });
        } else if (widget.flow == PinFlow.verify) {
          Navigator.of(context).pop(true);
        } else {
          setState(() {
            _pin = '';
            _stage = _Stage.choose;
          });
        }
      case _Stage.choose:
        setState(() {
          _first = entered;
          _pin = '';
          _stage = _Stage.confirm;
        });
      case _Stage.confirm:
        if (entered != _first) {
          HapticFeedback.heavyImpact();
          setState(() {
            _pin = '';
            _first = '';
            _stage = _Stage.choose;
            _error = 'The two PINs did not match. Start again.';
          });
        } else {
          await store.enableLock(entered);
          if (!mounted) return;
          Navigator.of(context).pop(true);
        }
    }
  }

  @override
  Widget build(BuildContext context) {
    final c = AppColors.of(context);
    final choosing = _stage == _Stage.choose || _stage == _Stage.confirm;

    return Scaffold(
      appBar: AppBar(
        title: Text(
          widget.flow == PinFlow.verify
              ? 'Turn off app lock'
              : (widget.flow == PinFlow.change ? 'Change PIN' : 'Set a PIN'),
        ),
      ),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _title,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: c.text,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 36,
                  child: Text(
                    _error ?? '',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 13, color: c.moneyOut),
                  ),
                ),
                PinDots(filled: _pin.length, error: _error != null),
                const SizedBox(height: 22),
                PinPad(onDigit: _digit, onBackspace: _backspace),
                if (choosing) ...[
                  const SizedBox(height: 14),
                  Text(
                    _deviceSupported
                        ? 'If you forget the PIN, the lock screen has a button that uses your phone\'s own screen lock to let you back in.'
                        : 'Your phone has no screen lock set up, so there is no way back in if you forget this PIN. Make a backup first (Settings, Your data).',
                    textAlign: TextAlign.center,
                    style: TextStyle(fontSize: 12, height: 1.4, color: c.subtext),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}
