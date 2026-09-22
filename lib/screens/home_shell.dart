import 'package:flutter/material.dart';
import 'package:local_auth/local_auth.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/settings_store.dart';
import 'add_edit_screen.dart';
import 'dashboard_screen.dart';
import 'settings_screen.dart';
import 'stats_screen.dart';
import 'transactions_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  int _index = 0;
  bool _locked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final state = context.read<AppState>();
    if (state.settings.lockEnabled) {
      _locked = true;
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    final state = context.read<AppState>();
    if (s == AppLifecycleState.resumed) {
      if (state.settings.lockEnabled) {
        setState(() => _locked = true);
      }
    }
  }

  Future<void> _unlock() async {
    setState(() => _locked = false);
  }

  void _openQuickAdd() {
    showQuickAdd(context);
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AppState>().strings;
    final t = Theme.of(context);
    final pages = [
      const DashboardScreen(),
      const TransactionsScreen(),
      const SizedBox.shrink(),
      const StatsScreen(),
      const SettingsScreen(),
    ];

    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(index: _index, children: pages),
          bottomNavigationBar: NavigationBar(
            selectedIndex: _index,
            onDestinationSelected: (i) {
              if (i == 2) {
                _openQuickAdd();
                return;
              }
              setState(() => _index = i);
            },
            destinations: [
              NavigationDestination(
                icon: Icon(_index == 0 ? Icons.home_rounded : Icons.home_outlined),
                label: strings.tr('home'),
              ),
              NavigationDestination(
                icon: Icon(_index == 1 ? Icons.receipt_long_rounded : Icons.receipt_long_outlined),
                label: strings.tr('transactions'),
              ),
              NavigationDestination(
                icon: Container(
                  width: 46,
                  height: 46,
                  decoration: BoxDecoration(
                    color: t.colorScheme.primary,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Icon(Icons.add_rounded, color: t.colorScheme.onPrimary, size: 30),
                ),
                label: '',
              ),
              NavigationDestination(
                icon: Icon(_index == 3 ? Icons.pie_chart_rounded : Icons.pie_chart_outline_rounded),
                label: strings.tr('statistics'),
              ),
              NavigationDestination(
                icon: Icon(_index == 4 ? Icons.settings_rounded : Icons.settings_outlined),
                label: strings.tr('settings'),
              ),
            ],
          ),
        ),
        if (_locked)
          _LockOverlay(onUnlock: _unlock),
      ],
    );
  }
}

class _LockOverlay extends StatefulWidget {
  final VoidCallback onUnlock;
  const _LockOverlay({required this.onUnlock});

  @override
  State<_LockOverlay> createState() => _LockOverlayState();
}

class _LockOverlayState extends State<_LockOverlay> {
  String _entered = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeBiometrics());
  }

  Future<void> _maybeBiometrics() async {
    final state = context.read<AppState>();
    if (!state.settings.lockEnabled || !state.settings.useBiometrics || state.settings.pinHash == null) {
      return;
    }
    final auth = LocalAuthentication();
    final available = await auth.isDeviceSupported();
    if (!available) return;
    try {
      final ok = await auth.authenticate(
        localizedReason: state.strings.tr('use_biometrics'),
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (ok && mounted) widget.onUnlock();
    } catch (_) {}
  }

  void _onDigit(String d) {
    final state = context.read<AppState>();
    if (_entered.length >= 4) return;
    final next = _entered + d;
    setState(() {
      _entered = next;
      _error = null;
    });
    if (next.length == 4) {
      if (state.settings.pinHash != null) {
        final expected = sha256Hex(next);
        if (expected == state.settings.pinHash) {
          widget.onUnlock();
        } else {
          setState(() {
            _error = state.strings.tr('wrong_pin');
            _entered = '';
          });
        }
      }
    }
  }

  void _delete() {
    if (_entered.isEmpty) return;
    setState(() => _entered = _entered.substring(0, _entered.length - 1));
  }

  @override
  Widget build(BuildContext context) {
    final strings = context.watch<AppState>().strings;
    final t = Theme.of(context);
    return Scaffold(
      backgroundColor: t.scaffoldBackgroundColor,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: t.colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(24),
                ),
                child: Icon(Icons.lock_rounded, size: 40, color: t.colorScheme.primary),
              ),
              const SizedBox(height: 20),
              Text(strings.tr('app_name'),
                  style: t.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w800)),
              const SizedBox(height: 8),
              Text(strings.tr('enter_pin'), style: t.textTheme.bodyMedium),
              const SizedBox(height: 28),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(4, (i) {
                  final filled = i < _entered.length;
                  return AnimatedContainer(
                    duration: const Duration(milliseconds: 120),
                    width: 18,
                    height: 18,
                    margin: const EdgeInsets.symmetric(horizontal: 8),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: filled ? t.colorScheme.primary : t.colorScheme.outlineVariant,
                    ),
                  );
                }),
              ),
              if (_error != null) ...[
                const SizedBox(height: 12),
                Text(_error!,
                    style: t.textTheme.bodySmall?.copyWith(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 32),
              _NumPad(onDigit: _onDigit, onDelete: _delete),
              if (context.watch<AppState>().settings.useBiometrics) ...[
                const SizedBox(height: 16),
                IconButton(
                  onPressed: _maybeBiometrics,
                  icon: Icon(Icons.fingerprint_rounded, size: 34, color: t.colorScheme.primary),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _NumPad extends StatelessWidget {
  final ValueChanged<String> onDigit;
  final VoidCallback onDelete;
  const _NumPad({required this.onDigit, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final keys = ['1', '2', '3', '4', '5', '6', '7', '8', '9', '', '0', 'del'];
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var row = 0; row < 4; row++) ...[
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              for (var col = 0; col < 3; col++)
                _numKey(context, keys[row * 3 + col]),
            ],
          ),
          const SizedBox(height: 10),
        ],
      ],
    );
  }

  Widget _numKey(BuildContext context, String k) {
    final t = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 6),
      child: Material(
        color: t.colorScheme.surfaceContainerHighest.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () {
            if (k == 'del') {
              onDelete();
            } else if (k.isNotEmpty) {
              onDigit(k);
            }
          },
          child: SizedBox(
            width: 74,
            height: 60,
            child: Center(
              child: k == 'del'
                  ? const Icon(Icons.backspace_outlined)
                  : Text(k,
                      style: t.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
            ),
          ),
        ),
      ),
    );
  }
}