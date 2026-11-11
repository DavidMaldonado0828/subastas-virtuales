import '../../models/seller_auctions/seller_auction.dart';
import '../../models/seller_products/seller_product.dart';
import '../../services/seller_auctions/seller_auctions_service.dart';
import 'seller_auctions_repository.dart';

class SellerAuctionsRepositoryImpl implements SellerAuctionsRepository {
  SellerAuctionsRepositoryImpl(this.service);
  final SellerAuctionsService service;
  @override
  Future<SellerAuctionPage> fetch({required int limit, required int offset}) =>
      service.fetch(limit: limit, offset: offset);
  @override
  Future<List<SellerAuction>> fetchAll() => service.fetchAll();
  @override
  Future<List<SellerProduct>> products() => service.products();
  @override
  Future<void> create(Map<String, dynamic> payload) => service.create(payload);
  @override
  Future<void> update(int id, Map<String, dynamic> payload) =>
      service.update(id, payload);
  @override
  Future<SellerBidPage> bids({
    required int id,
    required int limit,
    required int offset,
  }) => service.bids(id: id, limit: limit, offset: offset);
}
