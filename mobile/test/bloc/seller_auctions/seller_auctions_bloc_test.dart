import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/bloc/seller_auctions/seller_auctions_bloc.dart';
import 'package:movil/models/seller_auctions/seller_auction.dart';
import 'package:movil/models/seller_products/seller_product.dart';
import 'package:movil/repositories/seller_auctions/seller_auctions_repository.dart';

class _Repo implements SellerAuctionsRepository {
  List<SellerAuction> auctions = [
    _auction(1, 'ACTIVA'),
    _auction(2, 'PROGRAMADA'),
    _auction(3, 'CERRADA'),
    _auction(4, 'FINALIZADA_SIN_GANADOR'),
    _auction(5, 'CANCELADA'),
  ];
  final requests = <(int, int)>[];
  @override
  Future<SellerAuctionPage> fetch({
    required int limit,
    required int offset,
  }) async {
    requests.add((limit, offset));
    final items = auctions.skip(offset).take(limit).toList();
    return SellerAuctionPage(
      items: items,
      limit: limit,
      offset: offset,
      total: auctions.length,
    );
  }

  @override
  Future<List<SellerAuction>> fetchAll() async => auctions;
  @override
  Future<List<SellerProduct>> products() async => [];
  @override
  Future<void> create(Map<String, dynamic> payload) async {}
  @override
  Future<void> update(int id, Map<String, dynamic> payload) async {}
  @override
  Future<SellerBidPage> bids({
    required int id,
    required int limit,
    required int offset,
  }) async => const SellerBidPage(items: [], limit: 20, offset: 0);
}

SellerAuction _auction(int id, String status) => SellerAuction(
  id: id,
  productId: id,
  productName: 'Producto $id',
  category: 'Hogar',
  basePrice: 100000,
  minimumIncrement: 5000,
  startDate: DateTime.utc(2030),
  endDate: DateTime.utc(2030, 2),
  status: status,
  bidCount: 0,
);
void main() {
  late _Repo repo;
  setUp(() => repo = _Repo());
  blocTest<SellerAuctionsBloc, SellerAuctionsState>(
    'carga en páginas de 100 y conserva todos los resultados',
    build: () {
      repo.auctions = List.generate(101, (i) => _auction(i + 1, 'ACTIVA'));
      return SellerAuctionsBloc(repo);
    },
    act: (bloc) => bloc.add(const SellerAuctionsLoadRequested()),
    expect: () => [
      isA<SellerAuctionsState>().having(
        (s) => s.view,
        'loading',
        SellerAuctionsView.loading,
      ),
      isA<SellerAuctionsState>().having(
        (s) => s.items.length,
        'total items',
        101,
      ),
    ],
    verify: (_) => expect(repo.requests, [(100, 0), (100, 100)]),
  );
  blocTest<SellerAuctionsBloc, SellerAuctionsState>(
    'filtra en memoria y cerrado incluye finalizada sin ganador',
    build: () => SellerAuctionsBloc(repo),
    act: (bloc) async {
      bloc.add(const SellerAuctionsLoadRequested());
      await Future<void>.delayed(const Duration(milliseconds: 30));
      bloc.add(const SellerAuctionsFilterChanged(SellerAuctionsFilter.closed));
    },
    expect: () => [
      isA<SellerAuctionsState>().having(
        (s) => s.view,
        'loading',
        SellerAuctionsView.loading,
      ),
      isA<SellerAuctionsState>().having((s) => s.items.length, 'all items', 5),
      isA<SellerAuctionsState>().having(
        (s) => s.visibleItems.map((a) => a.status).toList(),
        'closed items',
        ['CERRADA', 'FINALIZADA_SIN_GANADOR'],
      ),
    ],
    verify: (_) => expect(repo.requests, [(100, 0)]),
  );
}
