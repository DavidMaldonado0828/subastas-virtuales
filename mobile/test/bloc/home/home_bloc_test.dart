import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/bloc/home/home_bloc.dart';
import 'package:movil/models/home/auction.dart';
import 'package:movil/repositories/home/auction_repository.dart';

class FakeAuctionRepository implements AuctionRepository {
  final requests = <({int limit, int offset, bool closed})>[];
  Future<AuctionPage> Function(int offset, bool closed) fetchCall = (_, _) async => page([]);

  @override
  Future<AuctionPage> fetch({required int limit, required int offset, bool closed = false}) {
    requests.add((limit: limit, offset: offset, closed: closed));
    return fetchCall(offset, closed);
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

void main() {
  late FakeAuctionRepository repository;
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
