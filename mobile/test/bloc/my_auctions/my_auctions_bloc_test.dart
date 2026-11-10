import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/bloc/my_auctions/my_auctions_bloc.dart';
import 'package:movil/models/my_auctions/my_auction.dart';
import 'package:movil/repositories/my_auctions/my_auctions_repository.dart';

class FakeMyAuctionsRepository implements MyAuctionsRepository {
  final requests = <({int limit, int offset, String? status})>[];
  Future<MyAuctionsPage> Function(int offset, String? status) call = (
    _,
    _,
  ) async => page([]);
  @override
  Future<MyAuctionsPage> fetch({
    required int limit,
    required int offset,
    String? status,
  }) {
    requests.add((limit: limit, offset: offset, status: status));
    return call(offset, status);
  }
}

MyAuction item(int id, {String status = 'ACTIVA'}) => MyAuction(
  auctionId: id,
  productName: 'Producto $id',
  status: status,
  myHighestBid: 100,
  leaderAmount: 120,
  isLeader: false,
  cancelledByAdmin: false,
);
MyAuctionsPage page(List<MyAuction> items) =>
    MyAuctionsPage(items: items, limit: 10, offset: 0);

void main() {
  late FakeMyAuctionsRepository repo;
  late Completer<MyAuctionsPage> activeResponse;
  setUp(() => repo = FakeMyAuctionsRepository());
  blocTest<MyAuctionsBloc, MyAuctionsState>(
    'carga inicial consulta todas con limit 10',
    build: () {
      repo.call = (_, _) async => page([item(1)]);
      return MyAuctionsBloc(repo);
    },
    act: (b) => b.add(const MyAuctionsLoadRequested()),
    expect: () => [
      isA<MyAuctionsState>().having(
        (s) => s.view,
        'cargando',
        MyAuctionsView.loading,
      ),
      isA<MyAuctionsState>().having(
        (s) => s.items.single.auctionId,
        'resultado',
        1,
      ),
    ],
    verify: (_) =>
        expect(repo.requests.single, (limit: 10, offset: 0, status: null)),
  );
  blocTest<MyAuctionsBloc, MyAuctionsState>(
    'carga la página siguiente y conserva resultados',
    build: () {
      repo.call = (offset, _) async =>
          page(offset == 0 ? List.generate(10, (i) => item(i)) : [item(10)]);
      return MyAuctionsBloc(repo);
    },
    act: (b) async {
      b.add(const MyAuctionsLoadRequested());
      await Future<void>.delayed(Duration.zero);
      b.add(const MyAuctionsLoadMoreRequested());
    },
    expect: () => [
      isA<MyAuctionsState>(),
      isA<MyAuctionsState>().having(
        (s) => s.items.length,
        'primera página',
        10,
      ),
      isA<MyAuctionsState>().having((s) => s.loadingMore, 'cargando más', true),
      isA<MyAuctionsState>().having((s) => s.items.length, 'combinadas', 11),
    ],
    verify: (_) => expect(repo.requests.last.offset, 10),
  );
  blocTest<MyAuctionsBloc, MyAuctionsState>(
    'detiene paginación tras menos de diez resultados',
    build: () {
      repo.call = (_, _) async => page([item(1)]);
      return MyAuctionsBloc(repo);
    },
    act: (b) async {
      b.add(const MyAuctionsLoadRequested());
      await Future<void>.delayed(Duration.zero);
      b.add(const MyAuctionsLoadMoreRequested());
    },
    expect: () => [isA<MyAuctionsState>(), isA<MyAuctionsState>()],
    verify: (_) => expect(repo.requests, hasLength(1)),
  );
  blocTest<MyAuctionsBloc, MyAuctionsState>(
    'emite vacío cuando no hay resultados',
    build: () => MyAuctionsBloc(repo),
    act: (b) => b.add(const MyAuctionsLoadRequested()),
    expect: () => [
      isA<MyAuctionsState>(),
      isA<MyAuctionsState>().having(
        (s) => s.view,
        'vacío',
        MyAuctionsView.empty,
      ),
    ],
  );
  blocTest<MyAuctionsBloc, MyAuctionsState>(
    'emite error al fallar carga inicial',
    build: () {
      repo.call = (_, _) async => throw Exception('falló');
      return MyAuctionsBloc(repo);
    },
    act: (b) => b.add(const MyAuctionsLoadRequested()),
    expect: () => [
      isA<MyAuctionsState>(),
      isA<MyAuctionsState>().having(
        (s) => s.view,
        'error',
        MyAuctionsView.error,
      ),
    ],
  );
  blocTest<MyAuctionsBloc, MyAuctionsState>(
    'una respuesta tardía de otro filtro no reemplaza la lista visible',
    build: () {
      activeResponse = Completer<MyAuctionsPage>();
      repo.call = (_, status) => status == 'ACTIVA'
          ? activeResponse.future
          : Future.value(page([item(1)]));
      return MyAuctionsBloc(repo);
    },
    act: (b) async {
      b.add(const MyAuctionsLoadRequested());
      await Future<void>.delayed(Duration.zero);
      b.add(const MyAuctionsFilterChanged(MyAuctionsFilter.active));
      await Future<void>.delayed(Duration.zero);
      b.add(const MyAuctionsFilterChanged(MyAuctionsFilter.all));
      await Future<void>.delayed(Duration.zero);
      activeResponse.complete(page([item(7)]));
      await b.stream.firstWhere(
        (s) => s.loadedFilters.contains(MyAuctionsFilter.active),
      );
    },
    expect: () => [
      isA<MyAuctionsState>(),
      isA<MyAuctionsState>(),
      isA<MyAuctionsState>(),
      isA<MyAuctionsState>(),
      isA<MyAuctionsState>()
          .having((s) => s.filter, 'filtro visible', MyAuctionsFilter.all)
          .having((s) => s.items.single.auctionId, 'lista visible', 1)
          .having(
            (s) => s.lists[MyAuctionsFilter.active]!.single.auctionId,
            'lista almacenada',
            7,
          ),
    ],
  );
  blocTest<MyAuctionsBloc, MyAuctionsState>(
    'refresca desde offset cero y reemplaza los datos',
    build: () {
      repo.call = (offset, _) async =>
          page([item(offset == 0 ? repo.requests.length : 99)]);
      return MyAuctionsBloc(repo);
    },
    act: (b) async {
      b.add(const MyAuctionsLoadRequested());
      await Future<void>.delayed(Duration.zero);
      b.add(const MyAuctionsRefreshRequested());
    },
    expect: () => [
      isA<MyAuctionsState>(),
      isA<MyAuctionsState>(),
      isA<MyAuctionsState>(),
      isA<MyAuctionsState>(),
    ],
    verify: (_) => expect(repo.requests.last.offset, 0),
  );
}
