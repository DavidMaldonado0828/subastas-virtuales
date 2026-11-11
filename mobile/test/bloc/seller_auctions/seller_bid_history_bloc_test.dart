import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/bloc/seller_auctions/seller_bid_history_bloc.dart';
import 'package:movil/models/detail/auction_detail.dart';
import 'package:movil/models/detail/bid_history_item.dart';
import 'package:movil/models/home/auction.dart';
import 'package:movil/models/seller_auctions/seller_auction.dart';
import 'package:movil/models/seller_products/seller_product.dart';
import 'package:movil/repositories/detail/detail_repository.dart';
import 'package:movil/repositories/seller_auctions/seller_auctions_repository.dart';

class _Repo implements SellerAuctionsRepository {
  final requestedOffsets = <int>[];
  bool networkError = false;
  int countPerPage = 20;

  @override
  Future<SellerAuctionPage> fetch({
    required int limit,
    required int offset,
  }) async =>
      SellerAuctionPage(items: [], limit: limit, offset: offset, total: 0);
  @override
  Future<List<SellerAuction>> fetchAll() async => [];
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
  }) async {
    requestedOffsets.add(offset);
    if (networkError) {
      throw DioException(
        requestOptions: RequestOptions(path: '/auctions/7/bids'),
        type: DioExceptionType.connectionError,
      );
    }
    return SellerBidPage(
      items: List.generate(
        countPerPage,
        (index) => SellerBid(
          alias: 'postor-${offset + index}',
          amount: 50000 + offset + index,
          date: DateTime.utc(2030).add(Duration(minutes: offset + index)),
        ),
      ),
      limit: limit,
      offset: offset,
    );
  }
}

class _DetailRepo implements DetailRepository {
  String status = 'ACTIVA';
  LeaderBid? leader;
  AuctionWinner? winner;
  Object? error;
  int requests = 0;

  @override
  Future<AuctionDetail> fetchDetail(int auctionId) async {
    requests++;
    if (error != null) throw error!;
    return AuctionDetail(
      auction: Auction(
        id: auctionId,
        productName: 'Mesa',
        category: 'Hogar',
        basePrice: 100000,
        minimumIncrement: 5000,
        startDate: DateTime.utc(2030),
        endDate: DateTime.utc(2030, 2),
        status: status,
        sellerAlias: 'vendedor',
      ),
      remainingSeconds: 0,
      leaderBid: leader,
      winner: winner,
    );
  }

  @override
  Future<List<BidHistoryItem>> fetchBids(int auctionId) async => [];
  @override
  Future<void> placeBid(int auctionId, int amount) async {}
}

SellerAuction _initialAuction(String status) => SellerAuction(
  id: 7,
  productId: 1,
  productName: 'Mesa',
  category: 'Hogar',
  basePrice: 100000,
  minimumIncrement: 5000,
  startDate: DateTime.utc(2030),
  endDate: DateTime.utc(2030, 2),
  status: status,
  bidCount: 1,
  cancellationReason: status == 'CANCELADA' ? 'Motivo de prueba' : null,
  cancelledAt: status == 'CANCELADA' ? DateTime.utc(2030, 2) : null,
);

DioException _apiError(int status) => DioException(
  requestOptions: RequestOptions(path: '/auctions/7'),
  response: Response(
    requestOptions: RequestOptions(path: '/auctions/7'),
    statusCode: status,
  ),
);

void main() {
  late _Repo repo;
  late _DetailRepo details;
  setUp(() {
    repo = _Repo();
    details = _DetailRepo();
  });

  blocTest<SellerBidHistoryBloc, SellerBidHistoryState>(
    'muestra el ganador en una subasta cerrada',
    build: () {
      details
        ..status = 'CERRADA'
        ..winner = const AuctionWinner(alias: 'alias_ganador', amount: 125000);
      return SellerBidHistoryBloc(repo, details);
    },
    act: (bloc) => bloc.add(
      SellerBidHistoryLoadRequested(
        7,
        initialAuction: _initialAuction('CERRADA'),
      ),
    ),
    expect: () => [
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>()
          .having((s) => s.status, 'status', 'CERRADA')
          .having((s) => s.detail?.winner?.alias, 'winner', 'alias_ganador')
          .having((s) => s.items.length, 'bids', 20),
    ],
  );

  blocTest<SellerBidHistoryBloc, SellerBidHistoryState>(
    'carga resultado finalizado sin ganador',
    build: () {
      details.status = 'FINALIZADA_SIN_GANADOR';
      return SellerBidHistoryBloc(repo, details);
    },
    act: (bloc) => bloc.add(
      SellerBidHistoryLoadRequested(
        7,
        initialAuction: _initialAuction('FINALIZADA_SIN_GANADOR'),
      ),
    ),
    expect: () => [
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>().having(
        (s) => s.status,
        'status',
        'FINALIZADA_SIN_GANADOR',
      ),
    ],
  );

  blocTest<SellerBidHistoryBloc, SellerBidHistoryState>(
    'carga el líder de una subasta activa',
    build: () {
      details.leader = const LeaderBid(
        amount: 110000,
        bidderAlias: 'alias_lider',
      );
      return SellerBidHistoryBloc(repo, details);
    },
    act: (bloc) => bloc.add(
      SellerBidHistoryLoadRequested(
        7,
        initialAuction: _initialAuction('ACTIVA'),
      ),
    ),
    expect: () => [
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>().having(
        (s) => s.detail?.leaderBid?.bidderAlias,
        'leader',
        'alias_lider',
      ),
    ],
  );

  blocTest<SellerBidHistoryBloc, SellerBidHistoryState>(
    'carga el estado programado',
    build: () {
      details.status = 'PROGRAMADA';
      return SellerBidHistoryBloc(repo, details);
    },
    act: (bloc) => bloc.add(
      SellerBidHistoryLoadRequested(
        7,
        initialAuction: _initialAuction('PROGRAMADA'),
      ),
    ),
    expect: () => [
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>().having(
        (s) => s.status,
        'status',
        'PROGRAMADA',
      ),
    ],
  );

  blocTest<SellerBidHistoryBloc, SellerBidHistoryState>(
    'no solicita detalle para subastas canceladas',
    build: () => SellerBidHistoryBloc(repo, details),
    act: (bloc) => bloc.add(
      SellerBidHistoryLoadRequested(
        7,
        initialAuction: _initialAuction('CANCELADA'),
      ),
    ),
    expect: () => [
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>()
          .having((s) => s.status, 'status', 'CANCELADA')
          .having(
            (s) => s.initialAuction?.cancellationReason,
            'reason',
            'Motivo de prueba',
          ),
    ],
    verify: (_) => expect(details.requests, 0),
  );

  blocTest<SellerBidHistoryBloc, SellerBidHistoryState>(
    'un error en el detalle conserva las pujas y avisa del resumen',
    build: () {
      details.error = _apiError(500);
      return SellerBidHistoryBloc(repo, details);
    },
    act: (bloc) => bloc.add(
      SellerBidHistoryLoadRequested(
        7,
        initialAuction: _initialAuction('ACTIVA'),
      ),
    ),
    expect: () => [
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>()
          .having((s) => s.items.length, 'bids', 20)
          .having((s) => s.summaryUnavailable, 'summary unavailable', true)
          .having((s) => s.error, 'bids error', isNull),
    ],
  );

  blocTest<SellerBidHistoryBloc, SellerBidHistoryState>(
    'un 404 del detalle se omite sin marcar resumen fallido',
    build: () {
      details.error = _apiError(404);
      return SellerBidHistoryBloc(repo, details);
    },
    act: (bloc) => bloc.add(
      SellerBidHistoryLoadRequested(
        7,
        initialAuction: _initialAuction('ACTIVA'),
      ),
    ),
    expect: () => [
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>()
          .having((s) => s.items.length, 'bids', 20)
          .having((s) => s.summaryUnavailable, 'summary unavailable', false),
    ],
  );

  blocTest<SellerBidHistoryBloc, SellerBidHistoryState>(
    'refresca el resumen y el historial desde offset cero',
    build: () => SellerBidHistoryBloc(repo, details),
    act: (bloc) async {
      bloc.add(
        SellerBidHistoryLoadRequested(
          7,
          initialAuction: _initialAuction('ACTIVA'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(const SellerBidHistoryRefreshRequested());
    },
    expect: () => [
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>().having(
        (s) => s.refreshing,
        'refreshing',
        true,
      ),
      isA<SellerBidHistoryState>().having(
        (s) => s.refreshing,
        'refreshing',
        false,
      ),
    ],
    verify: (_) {
      expect(details.requests, 2);
      expect(repo.requestedOffsets, [0, 0]);
    },
  );

  blocTest<SellerBidHistoryBloc, SellerBidHistoryState>(
    'carga las pujas en páginas de 20 con offset',
    build: () => SellerBidHistoryBloc(repo, details),
    act: (bloc) async {
      bloc.add(
        SellerBidHistoryLoadRequested(
          7,
          initialAuction: _initialAuction('ACTIVA'),
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 20));
      bloc.add(const SellerBidHistoryLoadMoreRequested());
    },
    expect: () => [
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>().having((s) => s.items.length, 'page 1', 20),
      isA<SellerBidHistoryState>().having(
        (s) => s.loadingMore,
        'loading more',
        true,
      ),
      isA<SellerBidHistoryState>().having((s) => s.items.length, 'page 2', 40),
    ],
    verify: (_) => expect(repo.requestedOffsets, [0, 20]),
  );

  blocTest<SellerBidHistoryBloc, SellerBidHistoryState>(
    'muestra error de red al cargar pujas',
    build: () {
      repo.networkError = true;
      return SellerBidHistoryBloc(repo, details);
    },
    act: (bloc) => bloc.add(
      SellerBidHistoryLoadRequested(
        7,
        initialAuction: _initialAuction('ACTIVA'),
      ),
    ),
    expect: () => [
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>(),
      isA<SellerBidHistoryState>().having(
        (s) => s.error,
        'error',
        'No se pudo conectar con el servidor',
      ),
    ],
  );
}
