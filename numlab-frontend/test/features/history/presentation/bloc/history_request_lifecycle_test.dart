import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:fpdart/fpdart.dart';
import 'package:numlab_frontend/core/error/failures.dart';
import 'package:numlab_frontend/features/history/domain/entities/entities.dart';
import 'package:numlab_frontend/features/history/domain/usecases/usecases.dart';
import 'package:numlab_frontend/features/history/presentation/bloc/bloc.dart';

class _Pages extends Fake implements GetHistoryRunsUseCase {
  final pending = <Completer<Either<Failure, PaginatedHistory>>>[];
  final offsets = <int>[];
  @override
  Future<Either<Failure, PaginatedHistory>> call({
    int limit = 20,
    int offset = 0,
  }) {
    offsets.add(offset);
    final request = Completer<Either<Failure, PaginatedHistory>>();
    pending.add(request);
    return request.future;
  }
}

class _Runs extends Fake implements GetHistoryRunByIdUseCase {
  final pending = <Completer<Either<Failure, HistoryRun>>>[];
  final ids = <String>[];
  @override
  Future<Either<Failure, HistoryRun>> call(String id) {
    ids.add(id);
    final request = Completer<Either<Failure, HistoryRun>>();
    pending.add(request);
    return request.future;
  }
}

HistoryRun _run(String id) =>
    HistoryRun(id: id, method: 'root/bisection', createdAt: DateTime(2026));
PaginatedHistory _page(String id, {int offset = 0}) => PaginatedHistory(
  runs: [_run(id)],
  pagination: Pagination(total: 100, limit: 20, offset: offset, hasMore: true),
);
Future<void> _flush() => Future<void>.delayed(Duration.zero);

void main() {
  late _Pages pages;
  late _Runs runs;
  late HistoryBloc bloc;
  setUp(() {
    pages = _Pages();
    runs = _Runs();
    bloc = HistoryBloc(
      getHistoryRunsUseCase: pages,
      getHistoryRunByIdUseCase: runs,
    );
  });
  tearDown(() async => bloc.close());

  test(
    'old page cannot replace a newer page after refresh supersedes it',
    () async {
      bloc.add(const HistoryLoadRequested());
      await _flush();
      pages.pending[0].complete(Right(_page('original')));
      await _flush();
      bloc.add(const HistoryLoadMoreRequested());
      await _flush();
      bloc.add(const HistoryRefreshRequested());
      await _flush();
      pages.pending[2].complete(Right(_page('refreshed')));
      await _flush();
      bloc.add(const HistoryLoadMoreRequested());
      await _flush();
      pages.pending[1].complete(Right(_page('stale', offset: 20)));
      await _flush();
      expect(bloc.state, isA<HistoryLoadingMore>());
      expect(bloc.state.currentRuns.single.id, 'refreshed');
      pages.pending[3].complete(Right(_page('current', offset: 20)));
      await _flush();
      expect(bloc.state.currentRuns.map((r) => r.id), ['refreshed', 'current']);
      expect(pages.offsets, [0, 20, 0, 20]);
    },
  );

  test('late page failure cannot replace an active newer page', () async {
    bloc.add(const HistoryLoadRequested());
    await _flush();
    pages.pending[0].complete(Right(_page('original')));
    await _flush();
    bloc.add(const HistoryLoadMoreRequested());
    await _flush();
    bloc.add(const HistoryRefreshRequested());
    await _flush();
    pages.pending[2].complete(Right(_page('fresh')));
    await _flush();
    bloc.add(const HistoryLoadMoreRequested());
    await _flush();
    pages.pending[1].complete(
      const Left(NetworkFailure(message: 'stale failure')),
    );
    await _flush();
    expect(bloc.state, isA<HistoryLoadingMore>());
    pages.pending[3].complete(Right(_page('new', offset: 20)));
    await _flush();
    expect(bloc.state, isA<HistoryLoaded>());
    expect(bloc.state.currentRuns.map((r) => r.id), ['fresh', 'new']);
  });

  test(
    'A to B to A rejects the earlier A response despite matching ID',
    () async {
      for (final id in ['A', 'B', 'A']) {
        bloc.add(HistoryRunRequested(id));
        await _flush();
      }
      runs.pending[0].complete(Right(_run('A')));
      await _flush();
      expect(bloc.state, isA<HistoryDetailLoading>());
      runs.pending[1].complete(Right(_run('B')));
      await _flush();
      expect(bloc.state, isA<HistoryDetailLoading>());
      runs.pending[2].complete(Right(_run('A')));
      await _flush();
      expect((bloc.state as HistoryDetailLoaded).run.id, 'A');
      expect(runs.ids, ['A', 'B', 'A']);
    },
  );

  test(
    'repeated detail taps deduplicate while pending, manual retry still works',
    () async {
      bloc
        ..add(const HistoryRunRequested('A'))
        ..add(const HistoryRunRequested('A'));
      await _flush();
      expect(runs.ids, ['A']);
      runs.pending.single.complete(
        const Left(NetworkFailure(message: 'offline')),
      );
      await _flush();
      expect(bloc.state, isA<HistoryError>());
      bloc.add(const HistoryRunRequested('A'));
      await _flush();
      runs.pending.last.complete(Right(_run('A')));
      await _flush();
      expect(runs.ids, ['A', 'A']);
      expect(bloc.state, isA<HistoryDetailLoaded>());
    },
  );

  test('disposed BLoC ignores pending page and detail responses', () async {
    bloc.add(const HistoryLoadRequested());
    await _flush();
    bloc.add(const HistoryRunRequested('A'));
    await _flush();
    final closed = bloc.close();
    pages.pending.single.complete(Right(_page('late')));
    runs.pending.single.complete(Right(_run('A')));
    await closed;
    expect(bloc.isClosed, isTrue);
  });
}
