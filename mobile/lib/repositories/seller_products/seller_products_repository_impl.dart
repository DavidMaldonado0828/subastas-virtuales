import '../../models/seller_products/seller_product.dart';
import '../../services/seller_products/seller_products_service.dart';
import 'seller_products_repository.dart';

class SellerProductsRepositoryImpl implements SellerProductsRepository {
  SellerProductsRepositoryImpl(this.service);
  final SellerProductsService service;
  @override
  Future<List<SellerProduct>> list() => service.list();
  @override
  Future<List<SellerCategory>> categories() => service.categories();
  @override
  Future<SellerProduct> get(int id) => service.get(id);
  @override
  Future<SellerProduct> create(Map<String, dynamic> payload) =>
      service.create(payload);
  @override
  Future<SellerProduct> update(int id, Map<String, dynamic> payload) =>
      service.update(id, payload);
  @override
  Future<Map<String, dynamic>> delete(int id) => service.delete(id);
  @override
  Future<SellerProduct> reactivate(int id) => service.reactivate(id);
}
