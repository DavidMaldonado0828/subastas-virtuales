import 'package:bloc_test/bloc_test.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:movil/bloc/seller_products/seller_product_form_bloc.dart';
import 'package:movil/models/seller_products/seller_product.dart';
import 'package:movil/repositories/seller_products/seller_products_repository.dart';

class _Repo implements SellerProductsRepository {
  Map<String, dynamic>? lastPatch;
  DioException? failure;
  @override
  Future<List<SellerProduct>> list() async => [];
  @override
  Future<List<SellerCategory>> categories() async => [
    const SellerCategory(id: 1, name: 'Ropa'),
  ];
  @override
  Future<SellerProduct> get(int id) async => _p;
  @override
  Future<SellerProduct> create(Map<String, dynamic> payload) async {
    if (failure != null) throw failure!;
    return _p;
  }

  @override
  Future<SellerProduct> update(int id, Map<String, dynamic> payload) async {
    lastPatch = payload;
    if (failure != null) throw failure!;
    return _p;
  }

  @override
  Future<Map<String, dynamic>> delete(int id) async => {};
  @override
  Future<SellerProduct> reactivate(int id) async => _p;
}

const _p = SellerProduct(
  id: 7,
  categoryId: 1,
  categoryName: 'Ropa',
  status: 'ACTIVO',
  name: 'Zapato',
  description: 'Vieja',
);
void main() {
  late _Repo repo;
  setUp(() => repo = _Repo());
  blocTest<SellerProductFormBloc, SellerProductFormState>(
    'carga formulario',
    build: () => SellerProductFormBloc(repo),
    act: (b) => b.add(const SellerProductFormLoadRequested(null)),
    expect: () => [
      isA<SellerProductFormState>().having(
        (s) => s.categories.length,
        'categories',
        1,
      ),
    ],
  );
  blocTest<SellerProductFormBloc, SellerProductFormState>(
    'crea producto',
    build: () => SellerProductFormBloc(repo),
    seed: () => const SellerProductFormState(
      view: SellerProductFormView.ready,
      categories: [SellerCategory(id: 1, name: 'Ropa')],
    ),
    act: (b) => b.add(
      const SellerProductFormSaveRequested(
        id: null,
        name: ' Nuevo ',
        description: 'desc',
        categoryId: 1,
        brand: '',
        original: null,
      ),
    ),
    expect: () => [
      isA<SellerProductFormState>(),
      isA<SellerProductFormState>().having((s) => s.saved, 'saved', true),
    ],
  );
  blocTest<SellerProductFormBloc, SellerProductFormState>(
    'edita con PATCH parcial',
    build: () => SellerProductFormBloc(repo),
    seed: () => SellerProductFormState(
      view: SellerProductFormView.ready,
      categories: const [SellerCategory(id: 1, name: 'Ropa')],
      product: _p,
    ),
    act: (b) => b.add(
      SellerProductFormSaveRequested(
        id: 7,
        name: 'Zapato',
        description: 'Nueva',
        categoryId: 1,
        brand: '',
        original: _p,
      ),
    ),
    expect: () => [
      isA<SellerProductFormState>(),
      isA<SellerProductFormState>().having((s) => s.saved, 'saved', true),
    ],
    verify: (_) => expect(repo.lastPatch, {'description': 'Nueva'}),
  );
  blocTest<SellerProductFormBloc, SellerProductFormState>(
    'muestra error 422 en el campo indicado',
    build: () {
      final request = RequestOptions(path: '/products/7');
      repo.failure = DioException(
        requestOptions: request,
        response: Response(
          requestOptions: request,
          statusCode: 422,
          data: {
            'detail': [
              {
                'loc': ['body', 'description'],
                'msg': 'No editable.',
              },
            ],
          },
        ),
      );
      return SellerProductFormBloc(repo);
    },
    seed: () => const SellerProductFormState(
      view: SellerProductFormView.ready,
      categories: [SellerCategory(id: 1, name: 'Ropa')],
      product: _p,
    ),
    act: (b) => b.add(
      SellerProductFormSaveRequested(
        id: 7,
        name: 'Zapato',
        description: 'Nueva',
        categoryId: 1,
        brand: '',
        original: _p,
      ),
    ),
    expect: () => [
      isA<SellerProductFormState>(),
      isA<SellerProductFormState>().having(
        (s) => s.fieldErrors['description'],
        'description error',
        'No editable.',
      ),
    ],
  );
  blocTest<SellerProductFormBloc, SellerProductFormState>(
    'conserva error de red estandarizado',
    build: () {
      repo.failure = DioException(
        requestOptions: RequestOptions(path: '/products'),
        type: DioExceptionType.connectionError,
      );
      return SellerProductFormBloc(repo);
    },
    seed: () => const SellerProductFormState(
      view: SellerProductFormView.ready,
      categories: [SellerCategory(id: 1, name: 'Ropa')],
    ),
    act: (b) => b.add(
      const SellerProductFormSaveRequested(
        id: null,
        name: 'Nuevo',
        description: 'Descripción',
        categoryId: 1,
        brand: '',
        original: null,
      ),
    ),
    expect: () => [
      isA<SellerProductFormState>(),
      isA<SellerProductFormState>().having(
        (s) => s.error,
        'error',
        'No se pudo conectar con el servidor',
      ),
    ],
  );
}
