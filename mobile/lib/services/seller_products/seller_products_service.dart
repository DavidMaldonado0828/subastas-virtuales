import '../../../core/network/api_client.dart';
import '../../models/seller_products/seller_product.dart';

class SellerProductsService {
  SellerProductsService({required this.client});
  final ApiClient client;
  Future<List<SellerProduct>> list() async {
    final response = await client.dio.get<List<dynamic>>('/products');
    return (response.data ?? [])
        .map((e) => SellerProduct.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<List<SellerCategory>> categories() async {
    final response = await client.dio.get<List<dynamic>>('/categories');
    return (response.data ?? [])
        .map(
          (e) => SellerCategory.fromJson(Map<String, dynamic>.from(e as Map)),
        )
        .toList();
  }

  Future<SellerProduct> get(int id) async {
    final response = await client.dio.get<Map<String, dynamic>>(
      '/products/$id',
    );
    return SellerProduct.fromJson(Map<String, dynamic>.from(response.data!));
  }

  Future<SellerProduct> create(Map<String, dynamic> payload) async {
    final response = await client.dio.post<Map<String, dynamic>>(
      '/products',
      data: payload,
    );
    return SellerProduct.fromJson(Map<String, dynamic>.from(response.data!));
  }

  Future<SellerProduct> update(int id, Map<String, dynamic> payload) async {
    final response = await client.dio.patch<Map<String, dynamic>>(
      '/products/$id',
      data: payload,
    );
    return SellerProduct.fromJson(Map<String, dynamic>.from(response.data!));
  }

  Future<Map<String, dynamic>> delete(int id) async {
    final response = await client.dio.delete<Map<String, dynamic>>(
      '/products/$id',
    );
    return Map<String, dynamic>.from(response.data!);
  }

  Future<SellerProduct> reactivate(int id) async {
    final response = await client.dio.post<Map<String, dynamic>>(
      '/products/$id/reactivate',
    );
    return SellerProduct.fromJson(Map<String, dynamic>.from(response.data!));
  }
}
