import '../../models/seller_products/seller_product.dart';

abstract interface class SellerProductsRepository {
  Future<List<SellerProduct>> list();
  Future<List<SellerCategory>> categories();
  Future<SellerProduct> get(int id);
  Future<SellerProduct> create(Map<String, dynamic> payload);
  Future<SellerProduct> update(int id, Map<String, dynamic> payload);
  Future<Map<String, dynamic>> delete(int id);
  Future<SellerProduct> reactivate(int id);
}
