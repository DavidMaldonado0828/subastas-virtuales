import '../../models/seller_auctions/seller_auction.dart';
import '../../models/seller_products/seller_product.dart';

abstract interface class SellerAuctionsRepository {
  Future<SellerAuctionPage> fetch({required int limit, required int offset});
  Future<List<SellerAuction>> fetchAll();
  Future<List<SellerProduct>> products();
  Future<void> create(Map<String, dynamic> payload);
  Future<void> update(int id, Map<String, dynamic> payload);
  Future<SellerBidPage> bids({
    required int id,
    required int limit,
    required int offset,
  });
}
