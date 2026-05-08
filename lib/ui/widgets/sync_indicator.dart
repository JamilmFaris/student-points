import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../bloc/sync_cubit.dart';

/// AppBar action that shows the current sync state and lets the user trigger
/// a manual delta sync.
class SyncIndicator extends StatelessWidget {
  const SyncIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SyncCubit, SyncState>(
      builder: (context, state) {
        final cubit = context.read<SyncCubit>();
        switch (state.status) {
          case SyncStatus.syncing:
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: SizedBox(
                width: 20,
                height: 20,
                child: Center(
                  child: SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  ),
                ),
              ),
            );
          case SyncStatus.error:
            return IconButton(
              tooltip: state.errorMessage ?? 'فشل المزامنة',
              icon: const Icon(Icons.sync_problem, color: Colors.amberAccent),
              onPressed: () => cubit.performDeltaSync(),
            );
          case SyncStatus.idle:
          case SyncStatus.success:
            return IconButton(
              tooltip: 'مزامنة',
              icon: const Icon(Icons.sync),
              onPressed: () => cubit.performDeltaSync(),
            );
        }
      },
    );
  }
}
