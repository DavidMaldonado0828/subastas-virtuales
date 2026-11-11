import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/bloc/seller_products/seller_products_bloc.dart';
import 'package:movil/models/seller_products/seller_product.dart';
import 'package:movil/repositories/seller_products/seller_products_repository.dart';

class _Repo implements SellerProductsRepository {
  List<SellerProduct> products = [
    _p(1),
    _p(2, status: 'DESACTIVADO', name: 'Café'),
  ];
  String deleteResult = 'DELETED';
  DioException? failure;
  @override
  Future<List<SellerProduct>> list() async {
    if (failure != null) throw failure!;
    return products;
  }

  @override
  Future<List<SellerCategory>> categories() async => [];
  @override
  Future<SellerProduct> get(int id) async => _p(id);
  @override
  Future<SellerProduct> create(Map<String, dynamic> payload) async => _p(3);
  @override
  Future<SellerProduct> update(int id, Map<String, dynamic> payload) async =>
      _p(id);
  @override
  Future<Map<String, dynamic>> delete(int id) async {
    if (failure != null) throw failure!;
    return {
      'product_id': id,
      'result': deleteResult,
      'status': deleteResult == 'DELETED' ? null : 'DESACTIVADO',
    };
  }

  @override
  Future<SellerProduct> reactivate(int id) async => _p(id);
}

SellerProduct _p(int id, {String status = 'ACTIVO', String name = 'Zapato'}) =>
    SellerProduct(
      id: id,
      categoryId: 1,
      categoryName: 'Ropa',
      status: status,
      name: name,
      description: 'Desc',
    );
void main() {
  late _Repo repo;
  setUp(() => repo = _Repo());
  blocTest<SellerProductsBloc, SellerProductsState>(
    'carga lista',
    build: () => SellerProductsBloc(repo),
    act: (b) => b.add(const SellerProductsLoadRequested()),
    wait: const Duration(milliseconds: 20),
    expect: () => [
      isA<SellerProductsState>().having(
        (s) => s.view,
        'view',
        SellerProductsView.loading,
      ),
      isA<SellerProductsState>().having(
        (s) => s.products.length,
        'products',
        2,
      ),
    ],
  );
  blocTest<SellerProductsBloc, SellerProductsState>(
    'filtra por nombre ignorando tildes',
    build: () => SellerProductsBloc(repo),
    seed: () => SellerProductsState(
      view: SellerProductsView.success,
      products: repo.products,
    ),
    act: (b) => b.add(const SellerProductsNameChanged('cafe')),
    wait: const Duration(milliseconds: 350),
    expect: () => [
      isA<SellerProductsState>().having(
        (s) => s.visibleProducts.length,
        'visible',
        1,
      ),
    ],
  );
  blocTest<SellerProductsBloc, SellerProductsState>(
    'elimina cuando API borra físicamente',
    build: () => SellerProductsBloc(repo),
    seed: () => SellerProductsState(
      view: SellerProductsView.success,
      products: repo.products,
    ),
    act: (b) => b.add(const SellerProductDeleteRequested(1)),
    expect: () => [
      isA<SellerProductsState>().having((s) => s.busy, 'busy', true),
      isA<SellerProductsState>()
          .having((s) => s.products.length, 'remaining', 1)
          .having((s) => s.message, 'message', 'Producto eliminado.'),
    ],
  );
  blocTest<SellerProductsBloc, SellerProductsState>(
    'desactiva con historial',
    build: () {
      repo.deleteResult = 'DEACTIVATED';
      return SellerProductsBloc(repo);
    },
    seed: () => SellerProductsState(
      view: SellerProductsView.success,
      filter: SellerProductFilter.disabled,
      products: repo.products,
    ),
    act: (b) => b.add(const SellerProductDeleteRequested(1)),
    expect: () => [
      isA<SellerProductsState>(),
      isA<SellerProductsState>()
          .having(
            (s) => s.products.singleWhere((p) => p.id == 1).status,
            'product status',
            'DESACTIVADO',
          )
          .having(
            (s) => s.visibleProducts.any((p) => p.id == 1),
            'product remains visible in disabled filter',
            isTrue,
          )
          .having(
            (s) => s.message,
            'message',
            'Producto desactivado porque tiene historial',
          ),
    ],
  );
  blocTest<SellerProductsBloc, SellerProductsState>(
    'muestra detail de un 409',
    build: () {
      repo.failure = DioException(
        requestOptions: RequestOptions(
          path: '/products/1',
          extra: {'apiDetail': 'No se puede eliminar.'},
        ),
        response: Response(
          requestOptions: RequestOptions(path: '/products/1'),
          statusCode: 409,
          data: {'detail': 'No se puede eliminar.'},
        ),
      );
      return SellerProductsBloc(repo);
    },
    seed: () => SellerProductsState(
      view: SellerProductsView.success,
      products: repo.products,
    ),
    act: (b) => b.add(const SellerProductDeleteRequested(1)),
    expect: () => [
      isA<SellerProductsState>(),
      isA<SellerProductsState>().having(
        (s) => s.error,
        'error',
        'No se puede eliminar.',
      ),
    ],
  );
  blocTest<SellerProductsBloc, SellerProductsState>(
    'muestra mensaje estándar de red',
    build: () {
      repo.failure = DioException(
        requestOptions: RequestOptions(path: '/products'),
        type: DioExceptionType.connectionError,
      );
      return SellerProductsBloc(repo);
    },
    seed: () => SellerProductsState(
      view: SellerProductsView.success,
      products: repo.products,
    ),
    act: (b) => b.add(const SellerProductsRefreshRequested()),
    expect: () => [
      isA<SellerProductsState>(),
      isA<SellerProductsState>().having(
        (s) => s.error,
        'error',
        'No se pudo conectar con el servidor',
      ),
    ],
  );
  blocTest<SellerProductsBloc, SellerProductsState>(
    'reactiva producto',
    build: () => SellerProductsBloc(repo),
    seed: () => SellerProductsState(
      view: SellerProductsView.success,
      products: repo.products,
    ),
    act: (b) => b.add(const SellerProductReactivateRequested(2)),
    expect: () => [
      isA<SellerProductsState>(),
      isA<SellerProductsState>().having(
        (s) => s.message,
        'message',
        'Producto reactivado.',
      ),
    ],
  );
}
