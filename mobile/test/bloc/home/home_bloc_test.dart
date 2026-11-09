import 'package:bloc_test/bloc_test.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:movil/bloc/home/home_bloc.dart';
import 'package:movil/models/home/auction.dart';
import 'package:movil/repositories/home/auction_repository.dart';

class FakeAuctionRepository implements AuctionRepository {
  final requests = <({int limit, int offset, bool closed})>[];
  final myAuctionRequests = <({int limit, int offset})>[];
  Future<AuctionPage> Function(int offset, bool closed) fetchCall = (_, _) async => page([]);
  Future<MyAuctionPage> Function(int limit, int offset) fetchMyCall = (_, _) async => myPage([]);

  @override
  Future<AuctionPage> fetch({required int limit, required int offset, bool closed = false}) {
    requests.add((limit: limit, offset: offset, closed: closed));
    return fetchCall(offset, closed);
  }

  @override
  Future<MyAuctionPage> fetchMyAuctions({required int limit, required int offset}) {
    myAuctionRequests.add((limit: limit, offset: offset));
    return fetchMyCall(limit, offset);
  }
}

Auction item(int id) => Auction(
  id: id,
  productName: 'Producto $id',
  category: 'Categoría',
  basePrice: 1200000,
  minimumIncrement: 10000,
  startDate: DateTime.utc(2026),
  endDate: DateTime.utc(2027),
  status: 'ACTIVA',
  sellerAlias: 'vendedor',
);

AuctionPage page(List<Auction> items) => AuctionPage(items: items, limit: 10, offset: 0);
MyAuctionPage myPage(List<MyAuctionParticipation> items) => MyAuctionPage(items: items);

void main() {
  late FakeAuctionRepository repository;
  late Completer<AuctionPage> closedResponse;
  setUp(() => repository = FakeAuctionRepository());

  test('parsea montos decimales que la API entrega como texto', () {
    final auction = Auction.fromJson({
      'id': 1,
      'product': {
        'product_id': 2,
        'name': 'Producto',
        'brand': null,
        'image_url': null,
        'category': 'Categoría',
      },
      'base_price': '1200000.00',
      'minimum_increment': '10000.00',
      'start_date': '2026-01-01T00:00:00Z',
      'end_date': '2027-01-01T00:00:00Z',
      'status': 'CERRADA',
      'current_leader_amount': '1250000.00',
      'seller_alias': 'vendedor',
    });
    expect(auction.basePrice, 1200000);
    expect(auction.minimumIncrement, 10000);
    expect(auction.currentLeaderAmount, 1250000);
  });

  blocTest<HomeBloc, HomeState>(
    'carga inicial solicita diez subastas sin status',
    build: () {
      repository.fetchCall = (_, _) async => page([item(1)]);
      return HomeBloc(repository);
    },
    act: (bloc) => bloc.add(const HomeLoadRequested()),
    expect: () => [
      isA<HomeLoading>(),
      isA<HomeSuccess>().having((state) => state.items.length, 'cantidad', 1),
    ],
    verify: (_) => expect(repository.requests.single, (limit: 10, offset: 0, closed: false)),
  );

  blocTest<HomeBloc, HomeState>(
    'carga participaciones del POSTOR en bloques de 100 y las vincula por auction_id',
    build: () {
      repository.fetchCall = (_, _) async => page([item(2)]);
      repository.fetchMyCall = (limit, offset) async => offset == 0
          ? myPage(List.generate(100, (i) => MyAuctionParticipation(
              auctionId: i + 1, status: 'ACTIVA', isLeader: i == 1)))
          : myPage([const MyAuctionParticipation(auctionId: 150, status: 'CERRADA', isLeader: true)]);
      return HomeBloc(repository, loadParticipation: true);
    },
    act: (bloc) => bloc.add(const HomeLoadRequested()),
    verify: (bloc) {
      expect(repository.myAuctionRequests, [(limit: 100, offset: 0), (limit: 100, offset: 100)]);
      expect(bloc.state.participation[2], const AuctionParticipation(status: 'ACTIVA', isLeader: true));
      expect(bloc.state.participation[150], const AuctionParticipation(status: 'CERRADA', isLeader: true));
    },
  );

  blocTest<HomeBloc, HomeState>(
    'una respuesta tardía de Cerradas se guarda sin reemplazar la lista activa de Disponibles',
    build: () {
      closedResponse = Completer<AuctionPage>();
      repository.fetchCall = (offset, closed) {
        if (closed) return closedResponse.future;
        return Future.value(page([item(1)]));
      };
      return HomeBloc(repository);
    },
    act: (bloc) async {
      bloc.add(const HomeLoadRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const HomeTabChanged(HomeTab.closed));
      await Future<void>.delayed(Duration.zero);
      bloc.add(const HomeTabChanged(HomeTab.available));
      await Future<void>.delayed(Duration.zero);
      closedResponse.complete(page([item(99)]));
      await bloc.stream.firstWhere((state) => state.itemsByTab[HomeTab.closed]?.isNotEmpty == true);
    },
    expect: () => [
      isA<HomeLoading>().having((state) => state.tab, 'pestaña inicial', HomeTab.available),
      isA<HomeSuccess>().having((state) => state.items.single.id, 'lista disponibles', 1),
      isA<HomeLoading>().having((state) => state.tab, 'carga cerradas', HomeTab.closed),
      isA<HomeSuccess>().having((state) => state.tab, 'regresa a disponibles', HomeTab.available),
      isA<HomeSuccess>()
          .having((state) => state.items.single.id, 'se mantiene disponibles', 1)
          .having((state) => state.itemsByTab[HomeTab.closed]!.single.id, 'guarda cerradas', 99),
    ],
    verify: (bloc) {
      expect(bloc.state.tab, HomeTab.available);
      expect(bloc.state.items.single.id, 1);
      expect(bloc.state.itemsByTab[HomeTab.closed]!.single.id, 99);
    },
  );

  blocTest<HomeBloc, HomeState>(
    'carga la página siguiente y conserva los resultados anteriores',
    build: () {
      repository.fetchCall = (offset, _) async => offset == 0
          ? page(List.generate(10, (index) => item(index)))
          : page([item(10)]);
      return HomeBloc(repository);
    },
    act: (bloc) async {
      bloc.add(const HomeLoadRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const HomeLoadMoreRequested());
    },
    expect: () => [
      isA<HomeLoading>(),
      isA<HomeSuccess>().having((state) => state.items.length, 'primera página', 10),
      isA<HomeLoading>(),
      isA<HomeSuccess>().having((state) => state.items.length, 'páginas combinadas', 11),
    ],
    verify: (_) => expect(repository.requests.last.offset, 10),
  );

  blocTest<HomeBloc, HomeState>(
    'detiene la paginación cuando recibe menos de diez elementos',
    build: () {
      repository.fetchCall = (_, _) async => page([item(1)]);
      return HomeBloc(repository);
    },
    act: (bloc) async {
      bloc.add(const HomeLoadRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const HomeLoadMoreRequested());
    },
    expect: () => [isA<HomeLoading>(), isA<HomeSuccess>()],
    verify: (_) => expect(repository.requests, hasLength(1)),
  );

  blocTest<HomeBloc, HomeState>(
    'emite vacío cuando no hay subastas',
    build: () => HomeBloc(repository),
    act: (bloc) => bloc.add(const HomeLoadRequested()),
    expect: () => [isA<HomeLoading>(), isA<HomeEmpty>()],
  );

  blocTest<HomeBloc, HomeState>(
    'emite error al fallar la carga inicial',
    build: () {
      repository.fetchCall = (_, _) async => throw Exception('falló');
      return HomeBloc(repository);
    },
    act: (bloc) => bloc.add(const HomeLoadRequested()),
    expect: () => [isA<HomeLoading>(), isA<HomeError>()],
  );

  blocTest<HomeBloc, HomeState>(
    'refresca reiniciando offset y resultados',
    build: () {
      repository.fetchCall = (offset, _) async => page([item(offset == 0 ? 1 : 2)]);
      return HomeBloc(repository);
    },
    act: (bloc) async {
      bloc.add(const HomeLoadRequested());
      await Future<void>.delayed(Duration.zero);
      bloc.add(const HomeRefreshRequested());
    },
    expect: () => [
      isA<HomeLoading>(), isA<HomeSuccess>(),
      isA<HomeLoading>(),
      isA<HomeSuccess>().having((state) => state.items.single.id, 'ID refrescado', 1),
    ],
    verify: (_) => expect(repository.requests.last.offset, 0),
  );
}
