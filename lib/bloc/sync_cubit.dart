import 'package:flutter_bloc/flutter_bloc.dart';

import '../api/services/_dio_error.dart';
import '../services/sync_service.dart';

enum SyncStatus { idle, syncing, success, error }

class SyncState {
  const SyncState({
    required this.status,
    this.errorMessage,
    this.lastResult,
  });

  final SyncStatus status;
  final String? errorMessage;
  final SyncResult? lastResult;

  const SyncState.idle() : this(status: SyncStatus.idle);
  const SyncState.syncing() : this(status: SyncStatus.syncing);
  SyncState.success(SyncResult result)
      : this(status: SyncStatus.success, lastResult: result);
  const SyncState.error(String msg)
      : this(status: SyncStatus.error, errorMessage: msg);
}

class SyncCubit extends Cubit<SyncState> {
  SyncCubit({required this.syncService}) : super(const SyncState.idle());

  final SyncService syncService;

  bool _running = false;

  Future<void> performLoginSync() => _run(syncService.performLoginSync);
  Future<void> performDeltaSync() => _run(syncService.performDeltaSync);

  Future<void> _run(Future<SyncResult> Function() op) async {
    if (_running) return;
    _running = true;
    emit(const SyncState.syncing());
    try {
      final result = await op();
      emit(SyncState.success(result));
    } on ApiException catch (e) {
      emit(SyncState.error(e.message));
    } catch (e) {
      emit(SyncState.error(e.toString()));
    } finally {
      _running = false;
    }
  }

  void reset() => emit(const SyncState.idle());
}
