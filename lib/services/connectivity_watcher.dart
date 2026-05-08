import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';

import '../bloc/auth_cubit.dart';
import '../bloc/sync_cubit.dart';

/// Listens to connectivity transitions and fires a delta sync when the device
/// reconnects (only if a user is authenticated). Debounced so a flapping
/// connection doesn't spam the server.
class ConnectivityWatcher {
  ConnectivityWatcher({
    required this.authCubit,
    required this.syncCubit,
    Connectivity? connectivity,
    Duration cooldown = const Duration(seconds: 30),
  })  : _connectivity = connectivity ?? Connectivity(),
        _cooldown = cooldown;

  final AuthCubit authCubit;
  final SyncCubit syncCubit;
  final Connectivity _connectivity;
  final Duration _cooldown;

  StreamSubscription<List<ConnectivityResult>>? _sub;
  bool _wasOnline = false;
  DateTime? _lastTrigger;

  Future<void> start() async {
    _wasOnline = _isOnline(await _connectivity.checkConnectivity());
    _sub = _connectivity.onConnectivityChanged.listen((results) {
      final online = _isOnline(results);
      if (online && !_wasOnline) _maybeTriggerSync();
      _wasOnline = online;
    });
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
  }

  void _maybeTriggerSync() {
    if (authCubit.state.status != AuthStatus.authenticated) return;
    final now = DateTime.now();
    if (_lastTrigger != null && now.difference(_lastTrigger!) < _cooldown) {
      return;
    }
    _lastTrigger = now;
    syncCubit.performDeltaSync();
  }

  bool _isOnline(List<ConnectivityResult> results) =>
      results.any((r) => r != ConnectivityResult.none);
}
