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

  /// Clears local data (optionally pushing pending rows first) then does a
  /// full pull from the server.
  Future<void> performRestoreFromServer({bool syncFirst = false}) async {
    if (_running) return;
    _running = true;
    emit(const SyncState.syncing());
    try {
      if (syncFirst) {
        await syncService.performDeltaSync();
      }
      await syncService.clearAllLocalData();
      final result = await syncService.performLoginSync();
      final pushFails = result.studentsPushFailed +
          result.studentsUpdateFailed +
          result.studentsDeleteFailed +
          result.habitsPushFailed +
          result.habitsUpdateFailed +
          result.habitsDeleteFailed +
          result.hifzPushFailed +
          result.hifzUpdateFailed +
          result.hifzDeleteFailed +
          result.lessonsPushFailed +
          result.lessonsUpdateFailed +
          result.lessonsDeleteFailed +
          result.attendancePushFailed +
          result.pointsBatchesFailed;
      final unmapped = result.pointsRowsSkipped;
      if (pushFails > 0) {
        final details = _buildFailureDetails(result);
        emit(SyncState.error('فشل رفع $pushFails عنصر إلى الخادم\n$details'));
      } else if (unmapped > 0) {
        emit(SyncState.error(
            '$unmapped سجل نقاط لم يُرفع — تحقّق من تطابق أسماء العادات مع الخادم'));
      } else {
        emit(SyncState.success(result));
      }
    } on ApiException catch (e) {
      emit(SyncState.error(e.message));
    } catch (e) {
      emit(SyncState.error(e.toString()));
    } finally {
      _running = false;
    }
  }

  Future<void> _run(Future<SyncResult> Function() op) async {
    if (_running) return;
    _running = true;
    emit(const SyncState.syncing());
    try {
      final result = await op();
      final pushFails = result.studentsPushFailed +
          result.studentsUpdateFailed +
          result.studentsDeleteFailed +
          result.habitsPushFailed +
          result.habitsUpdateFailed +
          result.habitsDeleteFailed +
          result.hifzPushFailed +
          result.hifzUpdateFailed +
          result.hifzDeleteFailed +
          result.lessonsPushFailed +
          result.lessonsUpdateFailed +
          result.lessonsDeleteFailed +
          result.attendancePushFailed +
          result.pointsBatchesFailed;
      final unmapped = result.pointsRowsSkipped;
      if (pushFails > 0) {
        final details = _buildFailureDetails(result);
        emit(SyncState.error('فشل رفع $pushFails عنصر إلى الخادم\n$details'));
      } else if (unmapped > 0) {
        emit(SyncState.error(
            '$unmapped سجل نقاط لم يُرفع — تحقّق من تطابق أسماء العادات مع الخادم'));
      } else {
        emit(SyncState.success(result));
      }
    } on ApiException catch (e) {
      emit(SyncState.error(e.message));
    } catch (e) {
      emit(SyncState.error(e.toString()));
    } finally {
      _running = false;
    }
  }

  String _buildFailureDetails(SyncResult result) {
    final details = <String>[];
    if (result.studentsPushFailed > 0) details.add('طلاب جدد: ${result.studentsPushFailed}');
    if (result.studentsUpdateFailed > 0) details.add('تحديث طلاب: ${result.studentsUpdateFailed}');
    if (result.studentsDeleteFailed > 0) details.add('حذف طلاب: ${result.studentsDeleteFailed}');
    if (result.habitsPushFailed > 0) details.add('عادات جديدة: ${result.habitsPushFailed}');
    if (result.habitsUpdateFailed > 0) details.add('تحديث عادات: ${result.habitsUpdateFailed}');
    if (result.habitsDeleteFailed > 0) details.add('حذف عادات: ${result.habitsDeleteFailed}');
    if (result.hifzPushFailed > 0) {
      details.add('حفظ جديد: ${result.hifzPushFailed}');
      if (result.failedHifzDetails.isNotEmpty) {
        for (final entry in result.failedHifzDetails.entries) {
          details.add('  • ID ${entry.key}: ${entry.value}');
        }
      }
    }
    if (result.hifzUpdateFailed > 0) details.add('تحديث حفظ: ${result.hifzUpdateFailed}');
    if (result.hifzDeleteFailed > 0) details.add('حذف حفظ: ${result.hifzDeleteFailed}');
    if (result.lessonsPushFailed > 0) details.add('دروس جديدة: ${result.lessonsPushFailed}');
    if (result.lessonsUpdateFailed > 0) details.add('تحديث دروس: ${result.lessonsUpdateFailed}');
    if (result.lessonsDeleteFailed > 0) details.add('حذف دروس: ${result.lessonsDeleteFailed}');
    if (result.attendancePushFailed > 0) details.add('الحضور: ${result.attendancePushFailed}');
    if (result.pointsBatchesFailed > 0) details.add('النقاط: ${result.pointsBatchesFailed}');
    return details.join('\n');
  }

  void reset() => emit(const SyncState.idle());
}
