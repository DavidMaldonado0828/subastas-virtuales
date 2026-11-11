import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/bloc/seller_auctions/seller_auction_form_bloc.dart';
import 'package:movil/models/seller_auctions/seller_auction.dart';
import 'package:movil/models/seller_products/seller_product.dart';
import 'package:movil/repositories/seller_auctions/seller_auctions_repository.dart';

class _Repo implements SellerAuctionsRepository {
  List<SellerAuction> auctions = [_auction(0)];
  List<SellerProduct> availableProducts = [
    const SellerProduct(
      id: 1,
      categoryId: 1,
      categoryName: 'Hogar',
      status: 'ACTIVO',
      name: 'Mesa',
      description: 'Desc',
    ),
    const SellerProduct(
      id: 2,
      categoryId: 1,
      categoryName: 'Hogar',
      status: 'DESACTIVADO',
      name: 'Silla',
      description: 'Desc',
    ),
  ];
  Map<String, dynamic>? created, patched;
  DioException? failure;
  @override
  Future<SellerAuctionPage> fetch({
    required int limit,
    required int offset,
  }) async => SellerAuctionPage(
    items: auctions,
    limit: limit,
    offset: offset,
    total: auctions.length,
  );
  @override
  Future<List<SellerAuction>> fetchAll() async => auctions;
  @override
  Future<List<SellerProduct>> products() async => availableProducts;
  @override
  Future<void> create(Map<String, dynamic> payload) async {
    if (failure != null) throw failure!;
    created = payload;
  }

  @override
  Future<void> update(int id, Map<String, dynamic> payload) async {
    if (failure != null) throw failure!;
    patched = payload;
  }

  @override
  Future<SellerBidPage> bids({
    required int id,
    required int limit,
    required int offset,
  }) async => const SellerBidPage(items: [], limit: 20, offset: 0);
}

SellerAuction _auction(int bids, {String status = 'PROGRAMADA'}) =>
    SellerAuction(
      id: 7,
      productId: 1,
      productName: 'Mesa',
      category: 'Hogar',
      basePrice: 100000,
      minimumIncrement: 5000,
      startDate: DateTime.utc(2030),
      endDate: DateTime.utc(2030, 2),
      status: status,
      bidCount: bids,
    );
DioException _apiError(int status, dynamic detail) {
  final request = RequestOptions(
    path: '/auctions',
    extra: {'apiDetail': detail is String ? detail : null},
  );
  return DioException(
    requestOptions: request,
    response: Response(
      requestOptions: request,
      statusCode: status,
      data: {'detail': detail},
    ),
  );
}

void main() {
  late _Repo repo;
  setUp(() => repo = _Repo());
  blocTest<SellerAuctionFormBloc, SellerAuctionFormState>(
    'carga solo productos activos al crear',
    build: () => SellerAuctionFormBloc(repo),
    act: (bloc) => bloc.add(const SellerAuctionFormLoadRequested(null)),
    expect: () => [
      isA<SellerAuctionFormState>().having(
        (s) => s.products.map((p) => p.id).toList(),
        'active products',
        [1],
      ),
    ],
  );
  blocTest<SellerAuctionFormBloc, SellerAuctionFormState>(
    'crea y envía montos enteros y fechas UTC con zona',
    build: () => SellerAuctionFormBloc(repo),
    seed: () => const SellerAuctionFormState(
      view: SellerAuctionFormView.ready,
      products: [
        SellerProduct(
          id: 1,
          categoryId: 1,
          categoryName: 'Hogar',
          status: 'ACTIVO',
          name: 'Mesa',
          description: 'Desc',
        ),
      ],
    ),
    act: (bloc) => bloc.add(
      SellerAuctionFormSaveRequested(
        id: null,
        productId: 1,
        basePrice: 100000,
        minimumIncrement: 5000,
        startDate: DateTime(2030),
        endDate: DateTime(2030, 2),
        original: null,
      ),
    ),
    expect: () => [
      isA<SellerAuctionFormState>(),
      isA<SellerAuctionFormState>().having((s) => s.saved, 'saved', true),
    ],
    verify: (_) {
      expect(repo.created?['base_price'], 100000);
      expect(repo.created?['minimum_increment'], 5000);
      expect((repo.created?['start_date'] as String).endsWith('Z'), isTrue);
    },
  );
  blocTest<SellerAuctionFormBloc, SellerAuctionFormState>(
    'edita con PATCH parcial',
    build: () => SellerAuctionFormBloc(repo),
    seed: () => SellerAuctionFormState(
      view: SellerAuctionFormView.ready,
      auction: _auction(0),
    ),
    act: (bloc) => bloc.add(
      SellerAuctionFormSaveRequested(
        id: 7,
        productId: 1,
        basePrice: 200000,
        minimumIncrement: 5000,
        startDate: DateTime.utc(2030),
        endDate: DateTime.utc(2030, 2),
        original: _auction(0),
      ),
    ),
    expect: () => [
      isA<SellerAuctionFormState>(),
      isA<SellerAuctionFormState>().having((s) => s.saved, 'saved', true),
    ],
    verify: (_) => expect(repo.patched, {'base_price': 200000}),
  );
  blocTest<SellerAuctionFormBloc, SellerAuctionFormState>(
    'muestra validación 422 bajo el campo',
    build: () {
      repo.failure = _apiError(422, [
        {
          'loc': ['body', 'start_date'],
          'msg': 'Fecha inválida.',
        },
      ]);
      return SellerAuctionFormBloc(repo);
    },
    seed: () => const SellerAuctionFormState(view: SellerAuctionFormView.ready),
    act: (bloc) => bloc.add(
      SellerAuctionFormSaveRequested(
        id: null,
        productId: 1,
        basePrice: 100000,
        minimumIncrement: 5000,
        startDate: DateTime(2030),
        endDate: DateTime(2030, 2),
        original: null,
      ),
    ),
    expect: () => [
      isA<SellerAuctionFormState>(),
      isA<SellerAuctionFormState>().having(
        (s) => s.fieldErrors['start_date'],
        'field error',
        'Fecha inválida.',
      ),
    ],
  );
  blocTest<SellerAuctionFormBloc, SellerAuctionFormState>(
    'muestra detail de conflicto 409',
    build: () {
      repo.failure = _apiError(
        409,
        'El producto ya tiene una subasta abierta.',
      );
      return SellerAuctionFormBloc(repo);
    },
    seed: () => const SellerAuctionFormState(view: SellerAuctionFormView.ready),
    act: (bloc) => bloc.add(
      SellerAuctionFormSaveRequested(
        id: null,
        productId: 1,
        basePrice: 100000,
        minimumIncrement: 5000,
        startDate: DateTime(2030),
        endDate: DateTime(2030, 2),
        original: null,
      ),
    ),
    expect: () => [
      isA<SellerAuctionFormState>(),
      isA<SellerAuctionFormState>().having(
        (s) => s.error,
        'detail',
        'El producto ya tiene una subasta abierta.',
      ),
    ],
  );
  blocTest<SellerAuctionFormBloc, SellerAuctionFormState>(
    'rechaza edición si la subasta ya tiene pujas',
    build: () {
      repo.auctions = [_auction(2, status: 'ACTIVA')];
      return SellerAuctionFormBloc(repo);
    },
    act: (bloc) => bloc.add(const SellerAuctionFormLoadRequested(7)),
    expect: () => [
      isA<SellerAuctionFormState>().having(
        (s) => s.error,
        'error',
        'Esta subasta no se puede editar.',
      ),
    ],
  );
  blocTest<SellerAuctionFormBloc, SellerAuctionFormState>(
    'conserva error de red estándar',
    build: () {
      final request = RequestOptions(path: '/auctions', extra: {});
      repo.failure = DioException(
        requestOptions: request,
        type: DioExceptionType.connectionError,
      );
      return SellerAuctionFormBloc(repo);
    },
    seed: () => const SellerAuctionFormState(view: SellerAuctionFormView.ready),
    act: (bloc) => bloc.add(
      SellerAuctionFormSaveRequested(
        id: null,
        productId: 1,
        basePrice: 100000,
        minimumIncrement: 5000,
        startDate: DateTime(2030),
        endDate: DateTime(2030, 2),
        original: null,
      ),
    ),
    expect: () => [
      isA<SellerAuctionFormState>(),
      isA<SellerAuctionFormState>().having(
        (s) => s.error,
        'network',
        'No se pudo conectar con el servidor',
      ),
    ],
  );
}
